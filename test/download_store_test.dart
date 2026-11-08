import 'dart:io';

import 'package:dcomic/database/database_common.dart';
import 'package:dcomic/database/database_instance.dart';
import 'package:dcomic/downloads/download_models.dart';
import 'package:dcomic/downloads/download_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'support/download_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory directory;
  late String databasePath;
  DComicDatabase? database;

  Future<DownloadStore> openStore() async {
    database = await $FloorDComicDatabase
        .databaseBuilder(databasePath)
        .addMigrations(DatabaseInstance.migrations)
        .build();
    return DownloadStore(database!.downloadTaskDao);
  }

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('download_store_');
    databasePath = '${directory.path}/dcomic.db';
  });

  tearDown(() async {
    await database?.close();
    database = null;
    await directory.delete(recursive: true);
  });

  test('cancelled generation cannot be completed by a late event', () async {
    final store = await openStore();
    final request = sampleDownloadRequest();
    await store.insert(request);
    final before = await store.get(request.id);
    expect(
      await store.transition(
        request.id,
        before!.generation,
        DownloadState.queued,
        DownloadState.running,
      ),
      isTrue,
    );

    final canceled = await store.cancel(request.id);
    final accepted = await store.transition(
      request.id,
      before.generation,
      DownloadState.running,
      DownloadState.completed,
      completedAt: DateTime.now().toUtc(),
    );

    expect(canceled!.generation, before.generation + 1);
    expect(accepted, isFalse);
    expect((await store.get(request.id))!.state, DownloadState.canceled);
  });

  test('queued intent, request identity, and generation survive reopen', () async {
    var store = await openStore();
    final request = sampleDownloadRequest(
      integrity: const DownloadIntegrity(
        expectedBytes: 3,
        sha256Hex:
            'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
      ),
      strategy: TransferStrategy.parallel,
      chunks: 3,
      cacheKey: 'http://127.0.0.1/file',
    );
    await store.insert(request);
    await store.cancel(request.id);
    expect(
      await store.restart(
        request.id,
        1,
        DownloadState.canceled,
      ),
      isTrue,
    );
    expect(
      await store.transition(
        request.id,
        2,
        DownloadState.queued,
        DownloadState.paused,
      ),
      isTrue,
    );

    await database!.close();
    database = null;
    store = await openStore();
    final restored = await store.get(request.id);

    expect(restored, isNotNull);
    expect(restored!.state, DownloadState.paused);
    expect(restored.generation, 2);
    expect(restored.request.url, request.url);
    expect(restored.request.headers, request.headers);
    expect(restored.request.relativePath, request.relativePath);
    expect(restored.request.strategy, TransferStrategy.parallel);
    expect(restored.request.chunks, 3);
    expect(restored.request.cacheKey, request.cacheKey);
    expect(restored.request.displayName, request.displayName);
    expect(restored.request.integrity.expectedBytes, 3);
    expect(restored.request.integrity.sha256Hex, request.integrity.sha256Hex);
  });

  test('conditional transitions reject the wrong source state', () async {
    final store = await openStore();
    final request = sampleDownloadRequest();
    await store.insert(request);

    expect(
      await store.transition(
        request.id,
        0,
        DownloadState.running,
        DownloadState.completed,
      ),
      isFalse,
    );
    expect((await store.get(request.id))!.state, DownloadState.queued);
  });
  test('execution epoch survives row deletion and database reopen', () async {
    var store = await openStore();
    final request = sampleDownloadRequest();
    await store.insert(request);
    final first = (await store.get(request.id))!;
    final canceled = (await store.cancel(request.id))!;
    expect(await store.delete(request.id, canceled.generation), isTrue);

    await database!.close();
    database = null;
    store = await openStore();
    await store.insert(request);
    final replacement = (await store.get(request.id))!;

    expect(replacement.generation, greaterThan(first.generation));
  });

  test('canonical destination ownership is enforced transactionally', () async {
    final store = await openStore();
    await store.insert(
      sampleDownloadRequest(id: 'first', relativePath: 'files/shared.bin'),
    );

    await expectLater(
      store.insert(
        sampleDownloadRequest(
          id: 'second',
          relativePath: r'files\shared.bin',
        ),
      ),
      throwsStateError,
    );
    expect(await store.get('second'), isNull);
  });

  test('comic group cancellation is atomic and survives immediate reopen', () async {
    var store = await openStore();
    final runningRequest = sampleDownloadRequest(
      id: 'comic-running',
      relativePath: 'files/comic-running.bin',
    ).copyWith(group: 'comic:chapter');
    final queuedRequest = sampleDownloadRequest(
      id: 'comic-queued',
      relativePath: 'files/comic-queued.bin',
    ).copyWith(group: 'comic:chapter');
    final completedRequest = sampleDownloadRequest(
      id: 'comic-completed',
      relativePath: 'files/comic-completed.bin',
    ).copyWith(group: 'comic:chapter');
    await store.insert(runningRequest);
    await store.insert(queuedRequest);
    await store.insert(completedRequest);
    final running = (await store.get(runningRequest.id))!;
    final queued = (await store.get(queuedRequest.id))!;
    final completed = (await store.get(completedRequest.id))!;
    await store.transition(
      running.id,
      running.generation,
      DownloadState.queued,
      DownloadState.running,
    );
    await store.transition(
      completed.id,
      completed.generation,
      DownloadState.queued,
      DownloadState.completed,
      completedAt: DateTime.now().toUtc(),
    );

    final fenced = await store.cancelGroup('comic:chapter');
    expect(
      fenced.map((record) => record.id),
      containsAll([running.id, queued.id]),
    );

    await database!.close();
    database = null;
    store = await openStore();

    final restoredRunning = (await store.get(running.id))!;
    final restoredQueued = (await store.get(queued.id))!;
    final restoredCompleted = (await store.get(completed.id))!;
    expect(restoredRunning.state, DownloadState.canceled);
    expect(restoredRunning.generation, running.generation + 1);
    expect(restoredQueued.state, DownloadState.canceled);
    expect(restoredQueued.generation, queued.generation + 1);
    expect(restoredCompleted.state, DownloadState.completed);
    expect(restoredCompleted.generation, completed.generation);
  });

}
