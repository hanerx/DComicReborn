import 'dart:io';

import 'package:dcomic/database/entity/entity_base.dart';
import 'package:dcomic/requests/base_request.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

class _DesktopPaths extends PathProviderPlatform {
  _DesktopPaths(this.path);
  final String path;

  @override
  Future<String?> getApplicationDocumentsPath() async => path;

  @override
  Future<String?> getExternalStoragePath() async =>
      throw UnsupportedError('External storage is Android-only');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'invalid stored values remain recoverable without Firebase on macOS',
    () {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      expect(EntityBase().convertValue<int>('invalid'), isNull);
      expect(EntityBase().convertValue<int>('42'), 42);
    },
  );

  test(
    'desktop cache persists responses without Android external storage',
    () async {
      final directory = await Directory.systemTemp.createTemp('desktop_cache_');
      final originalPaths = PathProviderPlatform.instance;
      PathProviderPlatform.instance = _DesktopPaths(directory.path);
      addTearDown(() async {
        PathProviderPlatform.instance = originalPaths;
        await directory.delete(recursive: true);
      });
      final store = await RequestStatics.store;
      try {
        final now = DateTime.now();
        await store.set(
          CacheResponse(
            statusCode: 200,
            key: 'desktop-response',
            url: 'https://example.com/comic',
            content: [1, 2, 3],
            headers: [],
            eTag: null,
            lastModified: null,
            cacheControl: CacheControl(),
            date: now,
            expires: now.add(const Duration(hours: 1)),
            maxStale: now.add(const Duration(days: 1)),
            priority: CachePriority.normal,
            requestDate: now,
            responseDate: now,
          ),
        );
        expect((await store.get('desktop-response'))!.content, [1, 2, 3]);
        await store.clean();
        expect(await store.get('desktop-response'), isNull);
      } finally {
        await store.close();
      }
    },
  );
}
