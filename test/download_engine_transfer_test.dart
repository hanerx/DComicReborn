import 'dart:io';

import 'package:dcomic/downloads/download_engine_transfer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parallel representation preflight', () {
    test('requires a strong validator when no digest is available', () async {
      final preflight = DownloadEnginePreflight(
        _FakeProbe(
          headResponse: const EngineHttpResponse(
            statusCode: 200,
            headers: {'content-length': '8', 'etag': 'W/"version-1"'},
          ),
          rangeResponse: const EngineHttpResponse(
            statusCode: 206,
            headers: {'content-range': 'bytes 0-0/8', 'etag': 'W/"version-1"'},
          ),
        ),
      );

      await expectLater(
        preflight.parallel(
          Uri.parse('https://example.invalid/file'),
          const {},
          hasExpectedDigest: false,
        ),
        throwsA(isA<ParallelDownloadCapabilityException>()),
      );
    });

    test('allows digest-backed ranges without an entity validator', () async {
      final preflight = DownloadEnginePreflight(
        _FakeProbe(
          headResponse: const EngineHttpResponse(
            statusCode: 200,
            headers: {'content-length': '8'},
          ),
          rangeResponse: const EngineHttpResponse(
            statusCode: 206,
            headers: {'content-range': 'bytes 0-0/8'},
          ),
        ),
      );

      final result = await preflight.parallel(
        Uri.parse('https://example.invalid/file'),
        const {},
        hasExpectedDigest: true,
      );

      expect(result.expectedLength, 8);
      expect(result.strongETag, isNull);
    });

    test('pins every native range to the preflight representation', () async {
      final probe = _FakeProbe(
        headResponse: const EngineHttpResponse(
          statusCode: 200,
          headers: {'content-length': '8', 'etag': '"version-1"'},
        ),
        rangeResponse: const EngineHttpResponse(
          statusCode: 206,
          headers: {'content-range': 'bytes 0-0/8', 'etag': '"version-1"'},
        ),
      );
      final result = await DownloadEnginePreflight(probe).parallel(
        Uri.parse('https://example.invalid/file'),
        const {'Authorization': 'credential'},
        hasExpectedDigest: false,
      );

      expect(result.strongETag, '"version-1"');
      expect(probe.lastRangeHeaders, containsPair('Range', 'bytes=0-0'));
      expect(probe.lastRangeHeaders, containsPair('If-Match', '"version-1"'));
      expect(
        probe.lastRangeHeaders,
        containsPair('Accept-Encoding', 'identity'),
      );
      expect(
        probe.lastRangeHeaders,
        containsPair('Authorization', 'credential'),
      );
    });

    test(
      'rejects a probe whose Content-Range does not match the request',
      () async {
        final preflight = DownloadEnginePreflight(
          _FakeProbe(
            headResponse: const EngineHttpResponse(
              statusCode: 200,
              headers: {'content-length': '8', 'etag': '"version-1"'},
            ),
            rangeResponse: const EngineHttpResponse(
              statusCode: 206,
              headers: {'content-range': 'bytes 1-1/8', 'etag': '"version-1"'},
            ),
          ),
        );

        await expectLater(
          preflight.parallel(
            Uri.parse('https://example.invalid/file'),
            const {},
            hasExpectedDigest: false,
          ),
          throwsA(isA<ParallelDownloadCapabilityException>()),
        );
      },
    );
  });

  test('range partition covers every byte exactly once', () {
    expect(splitDownloadRanges(10, 3), const [
      DownloadByteRange(0, 3),
      DownloadByteRange(4, 7),
      DownloadByteRange(8, 9),
    ]);
  });

  test(
    'chunk validation requires exact status, range, validator, and length',
    () {
      const range = DownloadByteRange(4, 7);
      expect(
        () => validateRangeResponse(
          statusCode: 206,
          headers: const {
            'content-range': 'bytes 4-7/10',
            'etag': '"version-1"',
          },
          range: range,
          expectedLength: 10,
          strongETag: '"version-1"',
          actualFileLength: 4,
        ),
        returnsNormally,
      );
      expect(
        () => validateRangeResponse(
          statusCode: 200,
          headers: const {
            'content-range': 'bytes 4-7/10',
            'etag': '"version-1"',
          },
          range: range,
          expectedLength: 10,
          strongETag: '"version-1"',
          actualFileLength: 4,
        ),
        throwsFormatException,
      );
      expect(
        () => validateRangeResponse(
          statusCode: 206,
          headers: const {
            'content-range': 'bytes 4-7/10',
            'etag': '"version-2"',
          },
          range: range,
          expectedLength: 10,
          strongETag: '"version-1"',
          actualFileLength: 4,
        ),
        throwsFormatException,
      );
      expect(
        () => validateRangeResponse(
          statusCode: 206,
          headers: const {
            'content-range': 'bytes 4-7/10',
            'etag': '"version-1"',
          },
          range: range,
          expectedLength: 10,
          strongETag: '"version-1"',
          actualFileLength: 3,
        ),
        throwsFormatException,
      );
    },
  );

  test('parallel pause retains only fully validated chunks', () {
    final paused = childrenForSafeParallelPause(const [
      DurableTransferChild(
        taskId: 'complete',
        index: 0,
        start: 0,
        end: 4,
        path: 'chunk-0',
        state: DurableChildState.complete,
      ),
      DurableTransferChild(
        taskId: 'running',
        index: 1,
        start: 5,
        end: 9,
        path: 'chunk-1',
        state: DurableChildState.running,
      ),
    ]);

    expect(paused[0].state, DurableChildState.complete);
    expect(paused[1].state, DurableChildState.pending);
  });

  test('external native resume is inferred only from a paused single', () {
    final pausedSingle = _descriptor(
      state: DurableTransferState.paused,
      kind: DurableTransferKind.single,
    );

    expect(
      shouldCaptureExternalResume(
        pausedSingle,
        nativeActive: true,
        nativeCompleted: false,
        nativeRunnable: true,
      ),
      isTrue,
    );
    expect(
      shouldCaptureExternalResume(
        pausedSingle,
        nativeActive: false,
        nativeCompleted: true,
        nativeRunnable: false,
      ),
      isTrue,
    );
    expect(
      shouldCaptureExternalResume(
        pausedSingle.copyWith(state: DurableTransferState.canceled),
        nativeActive: true,
        nativeCompleted: false,
        nativeRunnable: true,
      ),
      isFalse,
    );
  });

  test('terminal native progress sentinels never imply resume intent', () {
    expect(isNativeTransferProgress(0.25), isTrue);
    expect(isNativeTransferProgress(-1), isFalse);
    expect(isNativeTransferProgress(-2), isFalse);
  });

  test('native cancellation replays only for a real paused notification', () {
    final paused = _descriptor(
      state: DurableTransferState.paused,
      kind: DurableTransferKind.single,
    );

    expect(
      shouldReplayNativeCancellation(paused, nativeCanceled: true),
      isTrue,
    );
    expect(
      shouldReplayNativeCancellation(
        paused.copyWith(restartRequired: true),
        nativeCanceled: true,
      ),
      isFalse,
    );
  });

  test('removing a complete transfer lets native terminal cleanup finish', () {
    expect(
      shouldCancelNativeTasksOnRemoval(DurableTransferState.running),
      isTrue,
    );
    expect(
      shouldCancelNativeTasksOnRemoval(DurableTransferState.complete),
      isFalse,
    );
  });

  test('comic notification batch id is deterministic and opaque', () {
    const group = 'comic:source-id:comic-id:chapter-id';

    final first = comicNotificationGroupId(group);

    expect(first, comicNotificationGroupId(group));
    expect(first, startsWith('dcomic-comic-'));
    expect(first, isNot(contains('source-id')));
    expect(comicNotificationGroupId('app-update'), isNull);
  });

  test('legacy descriptor defaults new durable intent fields safely', () {
    final json =
        _descriptor(
            state: DurableTransferState.paused,
            kind: DurableTransferKind.single,
          ).toJson()
          ..remove('businessGroup')
          ..remove('externalResumeRequested');

    final recovered = DurableTransferDescriptor.fromJson(json);

    expect(recovered.businessGroup, isNull);
    expect(recovered.externalResumeRequested, isFalse);
  });

  test('external resume intent can be cleared after scheduler admission', () {
    final pending = _descriptor(
      state: DurableTransferState.paused,
      kind: DurableTransferKind.single,
    ).copyWith(externalResumeRequested: true, resuming: true);

    final admitted = pending.copyWith(
      externalResumeRequested: false,
      resuming: false,
    );

    expect(admitted.externalResumeRequested, isFalse);
    expect(admitted.resuming, isFalse);
  });

  test('single resume validates the suffix response against the full file', () {
    expect(
      validateSingleResponse(
        statusCode: 206,
        headers: const {'content-range': 'bytes 4-9/10', 'etag': '"version-1"'},
        expectedLength: 10,
        strongETag: '"version-1"',
        actualFileLength: 10,
        resuming: true,
      ),
      10,
    );
    expect(
      () => validateSingleResponse(
        statusCode: 206,
        headers: const {'content-range': 'bytes 4-9/11', 'etag': '"version-1"'},
        expectedLength: 10,
        strongETag: '"version-1"',
        actualFileLength: 10,
        resuming: true,
      ),
      throwsFormatException,
    );
  });

  test(
    'descriptor survives an atomic round trip with ownership and ranges',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'engine-descriptor-',
      );
      final stagingDirectory = Directory(
        '${directory.path}${Platform.pathSeparator}.staging',
      );
      await stagingDirectory.create();
      addTearDown(() => directory.delete(recursive: true));
      final stagingPath =
          '${stagingDirectory.path}${Platform.pathSeparator}payload.part';
      final store = DownloadEngineDescriptorStore();
      final descriptor = DurableTransferDescriptor(
        businessId: 'business',
        generation: 3,
        parentTaskId: 'parent',
        stagingPath: stagingPath,
        url: 'https://example.invalid/file',
        headers: const {'Authorization': 'secret'},
        businessGroup: 'comic:source:comic:chapter',
        displayName: 'payload',
        kind: DurableTransferKind.parallel,
        state: DurableTransferState.preparing,
        expectedLength: 10,
        strongETag: '"version-1"',
        hasExpectedDigest: false,
        externalResumeRequested: true,
        children: const [
          DurableTransferChild(
            taskId: 'child-0',
            index: 0,
            start: 0,
            end: 4,
            path: 'chunk-0',
          ),
          DurableTransferChild(
            taskId: 'child-1',
            index: 1,
            start: 5,
            end: 9,
            path: 'chunk-1',
          ),
        ],
      );

      await store.write(descriptor);
      await store.write(
        descriptor.copyWith(state: DurableTransferState.running),
      );
      final recovered = await store.readForStaging(stagingPath);

      expect(recovered?.businessId, 'business');
      expect(recovered?.generation, 3);
      expect(recovered?.strongETag, '"version-1"');
      expect(recovered?.businessGroup, 'comic:source:comic:chapter');
      expect(recovered?.externalResumeRequested, isTrue);
      expect(recovered?.children.map((child) => child.taskId), [
        'child-0',
        'child-1',
      ]);
      expect(await File(store.pathFor(stagingPath)).exists(), isTrue);
    },
  );

  test('descriptor accepts a managed root with a trailing separator', () async {
    final root = await Directory.systemTemp.createTemp('engine-trailing-root-');
    addTearDown(() => root.delete(recursive: true));
    await Directory('${root.path}${Platform.pathSeparator}.staging').create();
    final stagingPath =
        '${root.path}${Platform.pathSeparator}${Platform.pathSeparator}'
        '.staging${Platform.pathSeparator}payload.part';
    final descriptor = DurableTransferDescriptor(
      businessId: 'business',
      generation: 1,
      parentTaskId: 'parent',
      stagingPath: stagingPath,
      url: 'https://example.invalid/file',
      headers: const {},
      displayName: 'payload',
      kind: DurableTransferKind.single,
      state: DurableTransferState.preparing,
      expectedLength: null,
      strongETag: null,
      hasExpectedDigest: false,
    );
    final store = DownloadEngineDescriptorStore();

    await store.write(descriptor);

    expect((await store.readForStaging(stagingPath))?.businessId, 'business');
  });

  test(
    'descriptor temporary file cannot follow a link outside staging',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'engine-sidecar-root-',
      );
      final outside = await Directory.systemTemp.createTemp(
        'engine-sidecar-out-',
      );
      addTearDown(() => root.delete(recursive: true));
      addTearDown(() => outside.delete(recursive: true));
      final stagingDirectory = Directory(
        '${root.path}${Platform.pathSeparator}.staging',
      );
      await stagingDirectory.create();
      final stagingPath =
          '${stagingDirectory.path}${Platform.pathSeparator}payload.part';
      final victim = File('${outside.path}${Platform.pathSeparator}victim');
      await victim.writeAsString('outside', flush: true);
      final store = DownloadEngineDescriptorStore();
      try {
        await Link('${store.pathFor(stagingPath)}.tmp').create(victim.path);
      } on FileSystemException {
        markTestSkipped('platform cannot create file links');
        return;
      }
      final descriptor = DurableTransferDescriptor(
        businessId: 'business',
        generation: 1,
        parentTaskId: 'parent',
        stagingPath: stagingPath,
        url: 'https://example.invalid/file',
        headers: const {},
        displayName: 'payload',
        kind: DurableTransferKind.single,
        state: DurableTransferState.preparing,
        expectedLength: null,
        strongETag: null,
        hasExpectedDigest: false,
      );

      await expectLater(
        store.write(descriptor),
        throwsA(isA<FileSystemException>()),
      );
      expect(await victim.readAsString(), 'outside');
    },
  );
}

DurableTransferDescriptor _descriptor({
  required DurableTransferState state,
  required DurableTransferKind kind,
}) => DurableTransferDescriptor(
  businessId: 'business',
  generation: 1,
  parentTaskId: 'parent',
  stagingPath: '.staging/payload.part',
  url: 'https://example.invalid/file',
  headers: const {},
  displayName: 'payload',
  kind: kind,
  state: state,
  expectedLength: kind == DurableTransferKind.parallel ? 1 : null,
  strongETag: '"version-1"',
  hasExpectedDigest: false,
  children: kind == DurableTransferKind.parallel
      ? const [
          DurableTransferChild(
            taskId: 'child',
            index: 0,
            start: 0,
            end: 0,
            path: '.staging/payload.part.chunk',
          ),
        ]
      : const [],
);

class _FakeProbe implements DownloadHttpProbe {
  final EngineHttpResponse headResponse;
  final EngineHttpResponse rangeResponse;
  Map<String, String>? lastRangeHeaders;

  _FakeProbe({required this.headResponse, required this.rangeResponse});

  @override
  Future<EngineHttpResponse> head(Uri url, Map<String, String> headers) async =>
      headResponse;

  @override
  Future<EngineHttpResponse> range(
    Uri url,
    Map<String, String> headers,
    DownloadByteRange range,
  ) async {
    lastRangeHeaders = Map<String, String>.of(headers);
    return rangeResponse;
  }
}
