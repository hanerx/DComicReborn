import 'dart:async';

import 'dart:io';

import 'package:dcomic/downloads/download_files.dart';
import 'package:dcomic/downloads/download_engine.dart';
import 'package:dcomic/downloads/download_models.dart';
import 'package:dcomic/downloads/download_service.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/download_harness.dart';

void main() {
  late Directory root;
  late MemoryDownloadStore store;
  late FakeDownloadEngine engine;
  late FakeDownloadCache cache;
  late DownloadFiles files;
  DownloadService? service;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('download_service_');
    store = MemoryDownloadStore();
    engine = FakeDownloadEngine();
    cache = FakeDownloadCache();
    files = DownloadFiles(root);
  });

  tearDown(() async {
    await service?.dispose();
    await root.delete(recursive: true);
  });

  DownloadService createService() => service = DownloadService(
    store: store,
    engine: engine,
    files: files,
    cache: cache,
  );

  test('business intent is durable before a native task is enqueued', () async {
    final download = createService();
    await download.initialize();
    engine.beforeEnqueue = (request) async {
      final persisted = await store.get(request.id);
      expect(persisted, isNotNull);
      expect(persisted!.state, DownloadState.queued);
      expect(persisted.engineTaskId, isNull);
    };

    final id = await download.submit(sampleDownloadRequest());

    expect(id, 'sample');
    expect(engine.enqueueCount, 1);
    expect((await download.get(id))!.engineTaskId, 'engine-sample-0');
  });

  test('valid cache bytes use the same verify and commit gate without network', () async {
    final download = createService();
    await download.initialize();
    cache
      ..hit = true
      ..bytes = 'abc'.codeUnits;
    final request = sampleDownloadRequest(
      cacheKey: 'http://127.0.0.1/file',
      integrity: const DownloadIntegrity(
        expectedBytes: 3,
        sha256Hex:
            'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
      ),
    );

    await download.submit(request);

    expect(engine.enqueueCount, 0);
    expect((await download.get(request.id))!.state, DownloadState.completed);
    expect(
      await (await download.completedFile(request.id))!.readAsString(),
      'abc',
    );
  });

  test('plugin completion with a bad digest fails and is never openable', () async {
    final download = createService();
    await download.initialize();
    final request = sampleDownloadRequest(
      integrity: const DownloadIntegrity(
        expectedBytes: 3,
        sha256Hex:
            'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
      ),
    );
    await download.submit(request);
    final running = (await download.get(request.id))!;
    final staging = files.staging(request.id, running.generation);
    await staging.parent.create(recursive: true);
    await staging.writeAsString('abd', flush: true);

    engine.emit(
      DownloadEngineUpdate(
        businessId: request.id,
        generation: running.generation,
        engineTaskId: running.engineTaskId!,
        state: DownloadEngineState.complete,
        bytesReceived: 3,
        totalBytes: 3,
        stagingPath: staging.path,
      ),
    );
    final failed = await download
        .watch()
        .map((records) => records.single)
        .firstWhere((record) => record.state == DownloadState.failed);

    expect(failed.error, isNotEmpty);
    expect(await download.completedFile(request.id), isNull);
    expect(await files.resolve(request.relativePath).exists(), isFalse);
  });

  test(
    'native content length is enforced when request length is unknown',
    () async {
      final download = createService();
      await download.initialize();
      final request = sampleDownloadRequest();
      await download.submit(request);
      final running = (await download.get(request.id))!;
      final staging = files.staging(request.id, running.generation);
      await staging.parent.create(recursive: true);
      await staging.writeAsString('abc', flush: true);

      engine.emit(
        DownloadEngineUpdate(
          businessId: request.id,
          generation: running.generation,
          engineTaskId: running.engineTaskId!,
          state: DownloadEngineState.complete,
          bytesReceived: 3,
          totalBytes: 4,
          stagingPath: staging.path,
        ),
      );
      final failed = await download
          .watch()
          .map((records) => records.single)
          .firstWhere((record) => record.state == DownloadState.failed);

      expect(failed.error, isNotEmpty);
      expect(await files.resolve(request.relativePath).exists(), isFalse);
    },
  );

  test('cancel generation fences a late successful native callback', () async {
    final download = createService();
    await download.initialize();
    final request = sampleDownloadRequest();
    await download.submit(request);
    final old = (await download.get(request.id))!;
    await download.cancel(request.id);
    final staging = files.staging(request.id, old.generation);
    await staging.parent.create(recursive: true);
    await staging.writeAsString('late bytes', flush: true);

    engine.emit(
      DownloadEngineUpdate(
        businessId: request.id,
        generation: old.generation,
        engineTaskId: old.engineTaskId!,
        state: DownloadEngineState.complete,
        bytesReceived: 10,
        totalBytes: 10,
        stagingPath: staging.path,
      ),
    );
    await download.reconcile();

    final record = await download.get(request.id);
    expect(record!.state, DownloadState.canceled);
    expect(record.generation, old.generation + 1);
    expect(await download.completedFile(request.id), isNull);
    expect(await files.resolve(request.relativePath).exists(), isFalse);
  });

  test('reconcile repairs final-file committed before DB completion', () async {
    const integrity = DownloadIntegrity(
      expectedBytes: 3,
      sha256Hex:
          'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
    );
    final request = sampleDownloadRequest(integrity: integrity);
    await store.insert(request);
    expect(
      await store.transition(
        request.id,
        0,
        DownloadState.queued,
        DownloadState.verifying,
      ),
      isTrue,
    );
    final finalFile = files.resolve(request.relativePath);
    await finalFile.parent.create(recursive: true);
    await finalFile.writeAsString('abc', flush: true);

    final download = createService();
    await download.initialize();

    expect((await download.get(request.id))!.state, DownloadState.completed);
    expect(await download.completedFile(request.id), isNotNull);
    expect(engine.enqueueCount, 0);
  });

  test(
    'reconcile attaches enqueue-window native task instead of duplicating it',
    () async {
      final request = sampleDownloadRequest();
      await store.insert(request);
      final staging = files.staging(request.id, 0);
      engine.nativeTasks['native-existing'] = DownloadEngineSnapshot(
        businessId: request.id,
        generation: 0,
        engineTaskId: 'native-existing',
        state: DownloadEngineState.queued,
        bytesReceived: 0,
        stagingPath: staging.path,
      );

      final download = createService();
      await download.initialize();

      expect(engine.enqueueCount, 0);
      expect((await download.get(request.id))!.engineTaskId, 'native-existing');
    },
  );

  test('explicitly paused intent is not restarted during initialize', () async {
    final request = sampleDownloadRequest();
    await store.insert(request);
    expect(
      await store.transition(
        request.id,
        0,
        DownloadState.queued,
        DownloadState.paused,
      ),
      isTrue,
    );

    final download = createService();
    await download.initialize();

    expect((await download.get(request.id))!.state, DownloadState.paused);
    expect(engine.enqueueCount, 0);
  });

  test(
    'duplicate complete events commit once and retain one completion',
    () async {
      final download = createService();
      await download.initialize();
      final request = sampleDownloadRequest(
        integrity: const DownloadIntegrity(expectedBytes: 3),
      );
      await download.submit(request);
      final record = (await download.get(request.id))!;
      final staging = files.staging(request.id, record.generation);
      await staging.parent.create(recursive: true);
      await staging.writeAsString('abc', flush: true);
      final complete = DownloadEngineUpdate(
        businessId: request.id,
        generation: record.generation,
        engineTaskId: record.engineTaskId!,
        state: DownloadEngineState.complete,
        bytesReceived: 3,
        totalBytes: 3,
        stagingPath: staging.path,
      );

      engine.emit(complete);
      final completed = await download
          .watch()
          .map((records) => records.single)
          .firstWhere((item) => item.state == DownloadState.completed);
      engine.emit(complete);
      await download.reconcile();

      final after = (await download.get(request.id))!;
      expect(after.state, DownloadState.completed);
      expect(after.completedAt, completed.completedAt);
      expect(await files.resolve(request.relativePath).readAsString(), 'abc');
    },
  );

  test(
    'parallel Range capability failure retries once with a single connection',
    () async {
      final download = createService();
      await download.initialize();
      final request = sampleDownloadRequest(
        strategy: TransferStrategy.parallel,
        chunks: 3,
      );
      await download.submit(request);
      final parallel = (await download.get(request.id))!;

      engine.emit(
        DownloadEngineUpdate(
          businessId: request.id,
          generation: parallel.generation,
          engineTaskId: parallel.engineTaskId!,
          state: DownloadEngineState.failed,
          bytesReceived: 0,
          stagingPath: files.staging(request.id, parallel.generation).path,
          error: 'Server does not accept ranges',
        ),
      );
      final restarted = await download
          .watch()
          .map((records) => records.single)
          .firstWhere(
            (record) =>
                record.generation == 1 && record.state == DownloadState.running,
          );

      expect(restarted.request.strategy, TransferStrategy.parallel);
      expect(restarted.effectiveStrategy, TransferStrategy.single);
      expect(restarted.error, contains('one connection'));
      expect(engine.enqueueCount, 2);
      expect(engine.enqueuedRequests.last.strategy, TransferStrategy.single);
    },
  );

  test('invalid merged Range bytes are discarded and retried as single', () async {
    final download = createService();
    await download.initialize();
    final request = sampleDownloadRequest(
      strategy: TransferStrategy.parallel,
      chunks: 4,
      integrity: const DownloadIntegrity(
        sha256Hex:
            'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
      ),
    );
    await download.submit(request);
    final parallel = (await download.get(request.id))!;
    final staging = files.staging(request.id, parallel.generation);
    await staging.parent.create(recursive: true);
    await staging.writeAsString('abd', flush: true);

    engine.emit(
      DownloadEngineUpdate(
        businessId: request.id,
        generation: parallel.generation,
        engineTaskId: parallel.engineTaskId!,
        state: DownloadEngineState.complete,
        bytesReceived: 3,
        totalBytes: 3,
        stagingPath: staging.path,
      ),
    );
    final restarted = await download
        .watch()
        .map((records) => records.single)
        .firstWhere(
          (record) =>
              record.generation == 1 && record.state == DownloadState.running,
        );

    expect(restarted.effectiveStrategy, TransferStrategy.single);
    expect(engine.enqueuedRequests.last.strategy, TransferStrategy.single);
    expect(await files.resolve(request.relativePath).exists(), isFalse);
    expect(await staging.exists(), isFalse);
  });

  test(
    'parallel parent runs exclusively so chunk workers retain capacity',
    () async {
      final download = createService();
      await download.initialize();
      final first = sampleDownloadRequest(
        id: 'parallel-a',
        relativePath: 'files/a.bin',
        strategy: TransferStrategy.parallel,
        chunks: 4,
      );
      final second = sampleDownloadRequest(
        id: 'parallel-b',
        relativePath: 'files/b.bin',
        strategy: TransferStrategy.parallel,
        chunks: 4,
      );
      await download.submit(first);
      await download.submit(second);

      expect(engine.enqueueCount, 1);
      expect((await download.get(second.id))!.state, DownloadState.queued);
      final active = (await download.get(first.id))!;
      final staging = files.staging(first.id, active.generation);
      await staging.parent.create(recursive: true);
      await staging.writeAsString('done', flush: true);
      engine.emit(
        DownloadEngineUpdate(
          businessId: first.id,
          generation: active.generation,
          engineTaskId: active.engineTaskId!,
          state: DownloadEngineState.complete,
          bytesReceived: 4,
          totalBytes: 4,
          stagingPath: staging.path,
        ),
      );
      await download
          .watch()
          .map(
            (records) => records.firstWhere((record) => record.id == second.id),
          )
          .firstWhere((record) => record.state == DownloadState.running);

      expect(engine.enqueueCount, 2);
    },
  );

  test(
    'remove revokes readability before deleting the record and file',
    () async {
      final download = createService();
      await download.initialize();
      cache
        ..hit = true
        ..bytes = 'abc'.codeUnits;
      final request = sampleDownloadRequest(
        cacheKey: 'http://127.0.0.1/file',
        integrity: const DownloadIntegrity(expectedBytes: 3),
      );
      await download.submit(request);
      final completed = await download.completedFile(request.id);
      expect(completed, isNotNull);

      await download.remove(request.id);

      expect(await download.get(request.id), isNull);
      expect(await completed!.exists(), isFalse);
    },
  );
  test(
    'remove and resubmit keeps late callbacks fenced by a fresh epoch',
    () async {
      final download = createService();
      await download.initialize();
      final request = sampleDownloadRequest();
      await download.submit(request);
      final old = (await download.get(request.id))!;
      await download.remove(request.id);
      await download.submit(request);
      final fresh = (await download.get(request.id))!;
      expect(fresh.generation, greaterThan(old.generation));

      final oldStaging = files.staging(request.id, old.generation);
      await oldStaging.parent.create(recursive: true);
      await oldStaging.writeAsString('late', flush: true);
      engine.emit(
        DownloadEngineUpdate(
          businessId: request.id,
          generation: old.generation,
          engineTaskId: old.engineTaskId!,
          state: DownloadEngineState.complete,
          bytesReceived: 4,
          totalBytes: 4,
          stagingPath: oldStaging.path,
        ),
      );
      await Future<void>.delayed(Duration.zero);
      await download.reconcile();

      expect((await download.get(request.id))!.generation, fresh.generation);
      expect((await download.get(request.id))!.state, DownloadState.running);
      expect(await oldStaging.exists(), isFalse);
    },
  );

  test('canonical destination can only be owned by one task', () async {
    final download = createService();
    await download.initialize();
    await download.submit(
      sampleDownloadRequest(id: 'first', relativePath: 'files/shared.bin'),
    );

    await expectLater(
      download.submit(
        sampleDownloadRequest(id: 'second', relativePath: r'files\shared.bin'),
      ),
      throwsStateError,
    );
    expect(await download.get('first'), isNotNull);
    expect(await download.get('second'), isNull);
  });

  test(
    'pause inability remains paused until the user explicitly resumes',
    () async {
      final download = createService();
      await download.initialize();
      final request = sampleDownloadRequest();
      await download.submit(request);
      await download.pause(request.id);
      final paused = (await download.get(request.id))!;

      engine.emit(
        DownloadEngineUpdate(
          businessId: request.id,
          generation: paused.generation,
          engineTaskId: paused.engineTaskId!,
          state: DownloadEngineState.failed,
          bytesReceived: 1,
          stagingPath: files.staging(request.id, paused.generation).path,
          error: 'TaskResumeException: Task was paused but cannot resume',
        ),
      );
      final retained = await download
          .watch()
          .map((records) => records.single)
          .firstWhere((record) => record.error != null);

      expect(retained.state, DownloadState.paused);
      expect(retained.resumeRequested, isFalse);
      expect(engine.enqueueCount, 1);
    },
  );

  test(
    'requested resume waits for the same parallel admission budget',
    () async {
      final download = createService();
      await download.initialize();
      final first = sampleDownloadRequest(
        id: 'parallel-a',
        relativePath: 'files/a.bin',
        strategy: TransferStrategy.parallel,
        chunks: 4,
      );
      final second = sampleDownloadRequest(
        id: 'parallel-b',
        relativePath: 'files/b.bin',
        strategy: TransferStrategy.parallel,
        chunks: 4,
      );
      await download.submit(first);
      await download.submit(second);
      await download.pause(first.id);
      expect((await download.get(second.id))!.state, DownloadState.running);

      await download.resume(first.id);

      final waiting = (await download.get(first.id))!;
      expect(waiting.state, DownloadState.paused);
      expect(waiting.resumeRequested, isTrue);
      expect(engine.resumeCount, 0);
    },
  );

  test('bound queued intent restarts when its native task is lost', () async {
    final request = sampleDownloadRequest();
    await store.insert(request);
    final queued = (await store.get(request.id))!;
    await store.bindEngine(request.id, queued.generation, 'native-lost');

    final download = createService();
    await download.initialize();

    final restarted = (await download.get(request.id))!;
    expect(restarted.generation, queued.generation + 1);
    expect(restarted.state, DownloadState.running);
    expect(restarted.engineTaskId, isNot('native-lost'));
  });

  test('cache copy length remains a durable verification identity', () async {
    final download = createService();
    await download.initialize();
    cache
      ..hit = true
      ..bytes = 'abc'.codeUnits;
    final request = sampleDownloadRequest(cacheKey: 'http://127.0.0.1/file');
    await download.submit(request);
    final record = (await download.get(request.id))!;
    expect(record.state, DownloadState.completed);
    expect(record.totalBytes, 3);
    final completed = (await download.completedFile(request.id))!;
    await completed.writeAsString('a', flush: true);

    expect(await download.completedFile(request.id), isNull);
    expect((await download.get(request.id))!.state, DownloadState.failed);
  });

  test('dispose waits for and aborts delayed initialization', () async {
    final rootReady = Completer<Directory>();
    service = DownloadService(
      store: store,
      engine: engine,
      cache: cache,
      rootDirectoryProvider: () => rootReady.future,
    );
    final initialization = service!.initialize();
    await Future<void>.delayed(Duration.zero);
    final disposal = service!.dispose();
    rootReady.complete(root);

    await expectLater(initialization, throwsStateError);
    await disposal;

    expect(engine.disposeCount, 1);
    await expectLater(service!.initialize(), throwsStateError);
  });

  test(
    'notification resume intent is persisted before scheduler admission',
    () async {
      final download = createService();
      await download.initialize();
      final request = sampleDownloadRequest();
      await download.submit(request);
      await download.pause(request.id);
      final paused = (await download.get(request.id))!;

      engine.emit(
        DownloadEngineUpdate(
          businessId: request.id,
          generation: paused.generation,
          engineTaskId: paused.engineTaskId!,
          state: DownloadEngineState.paused,
          bytesReceived: paused.bytesReceived,
          totalBytes: paused.totalBytes,
          stagingPath: files.staging(request.id, paused.generation).path,
          resumeRequested: true,
        ),
      );
      final running = await download
          .watch()
          .map((records) => records.single)
          .firstWhere((record) => record.state == DownloadState.running);

      expect(running.resumeRequested, isFalse);
      expect(engine.resumeCount, 1);
    },
  );

  test(
    'notification resume obeys an active parallel admission barrier',
    () async {
      final download = createService();
      await download.initialize();
      final first = sampleDownloadRequest(
        id: 'external-resume',
        relativePath: 'files/external.bin',
        strategy: TransferStrategy.parallel,
        chunks: 4,
      );
      final second = sampleDownloadRequest(
        id: 'active-parallel',
        relativePath: 'files/active.bin',
        strategy: TransferStrategy.parallel,
        chunks: 4,
      );
      await download.submit(first);
      await download.submit(second);
      await download.pause(first.id);
      expect((await download.get(second.id))!.state, DownloadState.running);
      final paused = (await download.get(first.id))!;

      engine.emit(
        DownloadEngineUpdate(
          businessId: first.id,
          generation: paused.generation,
          engineTaskId: paused.engineTaskId!,
          state: DownloadEngineState.paused,
          bytesReceived: paused.bytesReceived,
          totalBytes: paused.totalBytes,
          stagingPath: files.staging(first.id, paused.generation).path,
          resumeRequested: true,
        ),
      );
      final waiting = await download
          .watch()
          .map(
            (records) => records.firstWhere((record) => record.id == first.id),
          )
          .firstWhere((record) => record.resumeRequested);

      expect(waiting.state, DownloadState.paused);
      expect(engine.resumeCount, 0);
      await download.pause(first.id);
      expect((await download.get(first.id))!.resumeRequested, isFalse);
      expect(engine.pauseCount, 2);
    },
  );

  test('notification resume completion still passes verification', () async {
    final download = createService();
    await download.initialize();
    final request = sampleDownloadRequest(
      integrity: const DownloadIntegrity(expectedBytes: 3),
    );
    await download.submit(request);
    await download.pause(request.id);
    final paused = (await download.get(request.id))!;
    final staging = files.staging(request.id, paused.generation);
    await staging.parent.create(recursive: true);
    await staging.writeAsString('abc', flush: true);

    engine.emit(
      DownloadEngineUpdate(
        businessId: request.id,
        generation: paused.generation,
        engineTaskId: paused.engineTaskId!,
        state: DownloadEngineState.complete,
        bytesReceived: 3,
        totalBytes: 3,
        stagingPath: staging.path,
        resumeRequested: true,
      ),
    );
    final completed = await download
        .watch()
        .map((records) => records.single)
        .firstWhere((record) => record.state == DownloadState.completed);

    expect(completed.resumeRequested, isFalse);
    expect(await download.completedFile(request.id), isNotNull);
  });

  for (final checkpointState in [DownloadState.queued, DownloadState.running]) {
    test('startup checkpoint from ${checkpointState.name} retains notification '
        'resume intent', () async {
      final request = sampleDownloadRequest();
      await store.insert(request);
      var persisted = (await store.get(request.id))!;
      if (checkpointState == DownloadState.running) {
        await store.transition(
          request.id,
          persisted.generation,
          DownloadState.queued,
          DownloadState.running,
        );
        persisted = (await store.get(request.id))!;
      }
      await store.bindEngine(
        request.id,
        persisted.generation,
        'native-checkpoint',
      );
      engine.nativeTasks['native-checkpoint'] = DownloadEngineSnapshot(
        businessId: request.id,
        generation: persisted.generation,
        engineTaskId: 'native-checkpoint',
        state: DownloadEngineState.paused,
        bytesReceived: 1,
        stagingPath: files.staging(request.id, persisted.generation).path,
        resumeRequested: true,
      );

      final download = createService();
      await download.initialize();

      final running = (await download.get(request.id))!;
      expect(running.state, DownloadState.running);
      expect(running.resumeRequested, isFalse);
      expect(engine.resumeCount, 1);
    });
  }

  test(
    'startup restores notification resume intent from native snapshot',
    () async {
      final request = sampleDownloadRequest();
      await store.insert(request);
      final inserted = (await store.get(request.id))!;
      await store.transition(
        request.id,
        inserted.generation,
        DownloadState.queued,
        DownloadState.paused,
      );
      await store.bindEngine(request.id, inserted.generation, 'native-paused');
      engine.nativeTasks['native-paused'] = DownloadEngineSnapshot(
        businessId: request.id,
        generation: inserted.generation,
        engineTaskId: 'native-paused',
        state: DownloadEngineState.paused,
        bytesReceived: 1,
        stagingPath: files.staging(request.id, inserted.generation).path,
        resumeRequested: true,
      );

      final download = createService();
      await download.initialize();

      final running = (await download.get(request.id))!;
      expect(running.state, DownloadState.running);
      expect(running.resumeRequested, isFalse);
      expect(engine.resumeCount, 1);
    },
  );

  test('notification resume cannot revive a canceled generation', () async {
    final download = createService();
    await download.initialize();
    final request = sampleDownloadRequest();
    await download.submit(request);
    await download.pause(request.id);
    final old = (await download.get(request.id))!;
    await download.cancel(request.id);

    engine.emit(
      DownloadEngineUpdate(
        businessId: request.id,
        generation: old.generation,
        engineTaskId: old.engineTaskId!,
        state: DownloadEngineState.paused,
        bytesReceived: old.bytesReceived,
        stagingPath: files.staging(request.id, old.generation).path,
        resumeRequested: true,
      ),
    );
    await Future<void>.delayed(Duration.zero);
    await download.reconcile();

    final canceled = (await download.get(request.id))!;
    expect(canceled.state, DownloadState.canceled);
    expect(canceled.resumeRequested, isFalse);
    expect(engine.resumeCount, 0);
  });

  test(
    'native notification cancel durably cancels paused business intent',
    () async {
      final download = createService();
      await download.initialize();
      final request = sampleDownloadRequest();
      await download.submit(request);
      await download.pause(request.id);
      final paused = (await download.get(request.id))!;
      final staging = files.staging(request.id, paused.generation);
      await staging.parent.create(recursive: true);
      await staging.writeAsString('partial', flush: true);

      engine.emit(
        DownloadEngineUpdate(
          businessId: request.id,
          generation: paused.generation,
          engineTaskId: paused.engineTaskId!,
          state: DownloadEngineState.canceled,
          bytesReceived: 7,
          stagingPath: staging.path,
          resumeRequested: false,
        ),
      );
      final canceled = await download
          .watch()
          .map((records) => records.single)
          .firstWhere((record) => record.state == DownloadState.canceled);

      expect(canceled.generation, paused.generation + 1);
      expect(canceled.resumeRequested, isFalse);
      expect(await staging.exists(), isFalse);
    },
  );

  test('failed notification resume clean-restarts after admission', () async {
    final download = createService();
    await download.initialize();
    final request = sampleDownloadRequest();
    await download.submit(request);
    await download.pause(request.id);
    final paused = (await download.get(request.id))!;
    engine.resumeResult = false;

    engine.emit(
      DownloadEngineUpdate(
        businessId: request.id,
        generation: paused.generation,
        engineTaskId: paused.engineTaskId!,
        state: DownloadEngineState.failed,
        bytesReceived: paused.bytesReceived,
        stagingPath: files.staging(request.id, paused.generation).path,
        error: 'External notification resume failed',
        resumeRequested: true,
      ),
    );
    final restarted = await download
        .watch()
        .map((records) => records.single)
        .firstWhere(
          (record) =>
              record.generation == paused.generation + 1 &&
              record.state == DownloadState.running,
        );

    expect(restarted.resumeRequested, isFalse);
    expect(engine.resumeCount, 1);
    expect(engine.enqueueCount, 2);
  });

  test(
    'notification cancel fences queued and running group siblings',
    () async {
      final download = createService();
      await download.initialize();
      final requests =
          [
                sampleDownloadRequest(
                  id: 'group-first',
                  relativePath: 'files/group-first.bin',
                ),
                sampleDownloadRequest(
                  id: 'group-second',
                  relativePath: 'files/group-second.bin',
                ),
                sampleDownloadRequest(
                  id: 'group-queued',
                  relativePath: 'files/group-queued.bin',
                ),
              ]
              .map((request) => request.copyWith(group: 'comic:live-cancel'))
              .toList(growable: false);
      for (final request in requests) {
        await download.submit(request);
      }
      final first = (await download.get(requests.first.id))!;
      expect(
        (await download.get(requests.last.id))!.state,
        DownloadState.queued,
      );

      engine.emit(
        DownloadEngineUpdate(
          businessId: first.id,
          generation: first.generation,
          engineTaskId: first.engineTaskId!,
          state: DownloadEngineState.canceled,
          bytesReceived: first.bytesReceived,
          stagingPath: files.staging(first.id, first.generation).path,
        ),
      );
      final canceled = await download.watch().firstWhere(
        (records) =>
            records.length == requests.length &&
            records.every((record) => record.state == DownloadState.canceled),
      );

      expect(
        canceled.map((record) => record.id),
        containsAll(requests.map((request) => request.id)),
      );
      expect(engine.enqueueCount, 2);
    },
  );

  test('native cancel on a non-comic group leaves siblings running', () async {
    final download = createService();
    await download.initialize();
    final firstRequest = sampleDownloadRequest(
      id: 'noncomic-canceled',
      relativePath: 'files/noncomic-canceled.bin',
    );
    final siblingRequest = sampleDownloadRequest(
      id: 'noncomic-sibling',
      relativePath: 'files/noncomic-sibling.bin',
    );
    await download.submit(firstRequest);
    await download.submit(siblingRequest);
    final first = (await download.get(firstRequest.id))!;

    engine.emit(
      DownloadEngineUpdate(
        businessId: first.id,
        generation: first.generation,
        engineTaskId: first.engineTaskId!,
        state: DownloadEngineState.canceled,
        bytesReceived: first.bytesReceived,
        stagingPath: files.staging(first.id, first.generation).path,
      ),
    );
    await download
        .watch()
        .map(
          (records) =>
              records.firstWhere((record) => record.id == firstRequest.id),
        )
        .firstWhere((record) => record.state == DownloadState.canceled);

    expect(
      (await download.get(siblingRequest.id))!.state,
      DownloadState.running,
    );
  });

  test('stale in-app cancel callback cannot cancel group siblings', () async {
    final download = createService();
    await download.initialize();
    final firstRequest = sampleDownloadRequest(
      id: 'single-cancel',
      relativePath: 'files/single-cancel.bin',
    );
    final siblingRequest = sampleDownloadRequest(
      id: 'single-sibling',
      relativePath: 'files/single-sibling.bin',
    );
    await download.submit(firstRequest);
    await download.submit(siblingRequest);
    final old = (await download.get(firstRequest.id))!;
    await download.cancel(firstRequest.id);

    engine.emit(
      DownloadEngineUpdate(
        businessId: firstRequest.id,
        generation: old.generation,
        engineTaskId: old.engineTaskId!,
        state: DownloadEngineState.canceled,
        bytesReceived: old.bytesReceived,
        stagingPath: files.staging(firstRequest.id, old.generation).path,
      ),
    );
    await Future<void>.delayed(Duration.zero);
    await download.reconcile();

    expect(
      (await download.get(firstRequest.id))!.state,
      DownloadState.canceled,
    );
    expect(
      (await download.get(siblingRequest.id))!.state,
      DownloadState.running,
    );
  });

  test(
    'startup canceled snapshot fences all queued and active group siblings',
    () async {
      final requests =
          [
                sampleDownloadRequest(
                  id: 'startup-canceled',
                  relativePath: 'files/startup-canceled.bin',
                ),
                sampleDownloadRequest(
                  id: 'startup-active',
                  relativePath: 'files/startup-active.bin',
                ),
                sampleDownloadRequest(
                  id: 'startup-queued',
                  relativePath: 'files/startup-queued.bin',
                ),
              ]
              .map((request) => request.copyWith(group: 'comic:startup-cancel'))
              .toList(growable: false);
      for (final request in requests) {
        await store.insert(request);
      }
      final canceled = (await store.get(requests[0].id))!;
      await store.transition(
        canceled.id,
        canceled.generation,
        DownloadState.queued,
        DownloadState.paused,
      );
      await store.bindEngine(
        canceled.id,
        canceled.generation,
        'native-canceled',
      );
      final active = (await store.get(requests[1].id))!;
      await store.transition(
        active.id,
        active.generation,
        DownloadState.queued,
        DownloadState.running,
      );
      await store.bindEngine(active.id, active.generation, 'native-active');
      engine.nativeTasks['native-canceled'] = DownloadEngineSnapshot(
        businessId: canceled.id,
        generation: canceled.generation,
        engineTaskId: 'native-canceled',
        state: DownloadEngineState.canceled,
        bytesReceived: 0,
        stagingPath: files.staging(canceled.id, canceled.generation).path,
      );
      engine.nativeTasks['native-active'] = DownloadEngineSnapshot(
        businessId: active.id,
        generation: active.generation,
        engineTaskId: 'native-active',
        state: DownloadEngineState.running,
        bytesReceived: 1,
        stagingPath: files.staging(active.id, active.generation).path,
      );

      final download = createService();
      await download.initialize();

      final records = await download.list();
      expect(
        records.every((record) => record.state == DownloadState.canceled),
        isTrue,
      );
      expect(engine.enqueueCount, 0);
    },
  );
  test(
    'atomic comic fence defeats an old callback crossing group cancellation',
    () async {
      final download = createService();
      await download.initialize();
      final originRequest = sampleDownloadRequest(
        id: 'race-origin',
        relativePath: 'files/race-origin.bin',
      ).copyWith(group: 'comic:race');
      final siblingRequest = sampleDownloadRequest(
        id: 'race-sibling',
        relativePath: 'files/race-sibling.bin',
      ).copyWith(group: 'comic:race');
      await download.submit(originRequest);
      await download.submit(siblingRequest);
      final origin = (await download.get(originRequest.id))!;
      final sibling = (await download.get(siblingRequest.id))!;
      final progressStored = Completer<void>();
      final releaseProgress = Completer<void>();
      store.afterProgressUpdate = (id) async {
        if (id != sibling.id) return;
        if (!progressStored.isCompleted) progressStored.complete();
        await releaseProgress.future;
      };

      engine.emit(
        DownloadEngineUpdate(
          businessId: sibling.id,
          generation: sibling.generation,
          engineTaskId: sibling.engineTaskId!,
          state: DownloadEngineState.failed,
          bytesReceived: 1,
          stagingPath: files.staging(sibling.id, sibling.generation).path,
          error: 'TaskResumeException: stale callback',
        ),
      );
      await progressStored.future;
      engine.emit(
        DownloadEngineUpdate(
          businessId: origin.id,
          generation: origin.generation,
          engineTaskId: origin.engineTaskId!,
          state: DownloadEngineState.canceled,
          bytesReceived: origin.bytesReceived,
          stagingPath: files.staging(origin.id, origin.generation).path,
        ),
      );
      await download.watch().firstWhere(
        (records) =>
            records.length == 2 &&
            records.every((record) => record.state == DownloadState.canceled),
      );
      releaseProgress.complete();
      await Future<void>.delayed(Duration.zero);
      await download.reconcile();

      final fencedSibling = (await download.get(sibling.id))!;
      expect(fencedSibling.state, DownloadState.canceled);
      expect(fencedSibling.generation, sibling.generation + 1);
      expect(engine.enqueueCount, 2);
    },
  );
}
