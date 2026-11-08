import 'dart:async';
import 'dart:io';

import 'package:dcomic/downloads/download_files.dart';
import 'package:dcomic/downloads/download_service.dart';
import 'package:dcomic/providers/download_provider.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/download_harness.dart';

void main() {
  late Directory root;
  late FakeDownloadEngine engine;
  DownloadService? service;
  DownloadProvider? provider;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('download_provider_');
    engine = FakeDownloadEngine();
  });

  tearDown(() async {
    provider?.dispose();
    await service?.dispose();
    await root.delete(recursive: true);
  });

  test('ready initializes once and facade follows service-owned records', () async {
    final store = MemoryDownloadStore();
    service = DownloadService(
      store: store,
      engine: engine,
      files: DownloadFiles(root),
      cache: FakeDownloadCache(),
    );
    provider = DownloadProvider(service: service!);
    final changed = Completer<void>();
    provider!.addListener(() {
      if (provider!.records.isNotEmpty && !changed.isCompleted) {
        changed.complete();
      }
    });

    await provider!.ready;
    await service!.submit(sampleDownloadRequest());
    await changed.future;

    expect(provider!.error, isNull);
    expect(provider!.service, same(service));
    expect(provider!.records.single.id, 'sample');
    expect(() => provider!.records.add(provider!.records.single), throwsUnsupportedError);
  });
}
