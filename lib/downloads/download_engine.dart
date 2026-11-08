import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:background_downloader/background_downloader.dart';
import 'package:crypto/crypto.dart';
import 'package:dcomic/downloads/download_engine_transfer.dart';
import 'package:dcomic/downloads/download_models.dart';

export 'package:dcomic/downloads/download_engine_transfer.dart'
    show ParallelDownloadCapabilityException;

enum DownloadEngineState { queued, running, paused, complete, failed, canceled }

class DownloadEngineSnapshot {
  final String businessId;
  final int generation;
  final String engineTaskId;
  final DownloadEngineState state;
  final int bytesReceived;
  final int? totalBytes;
  final String stagingPath;
  final String? error;
  final bool resumeRequested;

  const DownloadEngineSnapshot({
    required this.businessId,
    required this.generation,
    required this.engineTaskId,
    required this.state,
    required this.bytesReceived,
    this.totalBytes,
    required this.stagingPath,
    this.error,
    this.resumeRequested = false,
  });
}

class DownloadEngineUpdate extends DownloadEngineSnapshot {
  const DownloadEngineUpdate({
    required super.businessId,
    required super.generation,
    required super.engineTaskId,
    required super.state,
    required super.bytesReceived,
    super.totalBytes,
    required super.stagingPath,
    super.error,
    super.resumeRequested,
  });

  DownloadEngineSnapshot get snapshot => DownloadEngineSnapshot(
    businessId: businessId,
    generation: generation,
    engineTaskId: engineTaskId,
    state: state,
    bytesReceived: bytesReceived,
    totalBytes: totalBytes,
    stagingPath: stagingPath,
    error: error,
    resumeRequested: resumeRequested,
  );
}

abstract class DownloadEngine {
  Stream<DownloadEngineUpdate> get updates;
  String? get notificationWarning => null;
  Future<void> initialize();
  Future<String> enqueue(
    DownloadRequest request,
    String stagingPath,
    int generation,
  );
  Future<bool> pause(String engineTaskId);
  Future<bool> resume(String engineTaskId);
  Future<bool> cancel(String engineTaskId);
  Future<List<DownloadEngineSnapshot>> snapshot();
  Future<void> dispose();
}

class BackgroundDownloadEngine extends DownloadEngine {
  static const _pluginGroup = 'dcomic-downloads';
  static const _metadataSchema = 2;

  final FileDownloader _downloader;
  final DownloadEnginePreflight _preflight;
  final DownloadEngineDescriptorStore _descriptors;
  final StreamController<DownloadEngineUpdate> _updates =
      StreamController<DownloadEngineUpdate>.broadcast();
  final Map<String, Future<void>> _parentOperations = {};
  final Map<String, String> _descriptorPaths = {};
  StreamSubscription<TaskUpdate>? _pluginSubscription;
  Future<void> _updateTail = Future<void>.value();
  bool _initialized = false;
  String? _notificationWarning;

  BackgroundDownloadEngine({
    FileDownloader? downloader,
    DownloadHttpProbe? httpProbe,
    DownloadEngineDescriptorStore descriptors =
        const DownloadEngineDescriptorStore(),
  }) : _downloader = downloader ?? FileDownloader(),
       _preflight = DownloadEnginePreflight(httpProbe),
       _descriptors = descriptors;

  @override
  Stream<DownloadEngineUpdate> get updates => _updates.stream;

  @override
  String? get notificationWarning => _notificationWarning;

  @override
  Future<void> initialize() async {
    if (_initialized) return;
    _pluginSubscription = _downloader.updates.listen(
      _queuePluginUpdate,
      onError: (Object _, StackTrace __) {
        // The durable descriptor and native inventory are reconciled by
        // snapshot(), so a stream-level error is never guessed onto a task.
      },
    );
    try {
      await _downloader.ready;
      await _configureNotificationsPermission();
      _configureNotifications();
      await _downloader.configure(
        globalConfig: (Config.holdingQueue, Config.never),
        androidConfig: [
          (Config.runInForeground, true),
          (Config.useCacheDir, Config.never),
        ],
      );
      await _downloader.start(
        markDownloadedComplete: false,
        doRescheduleKilledTasks: false,
        autoCleanDatabase: false,
      );
      await Future<void>.delayed(Duration.zero);
      await _updateTail;
      _initialized = true;
    } on Object {
      await _pluginSubscription?.cancel();
      _pluginSubscription = null;
      rethrow;
    }
  }

  Future<void> _configureNotificationsPermission() async {
    if (!Platform.isAndroid && !Platform.isIOS) return;
    try {
      const type = PermissionType.notifications;
      var status = await _downloader.permissions.status(type);
      if (status != PermissionStatus.granted) {
        status = await _downloader.permissions.request(type);
      }
      if (status != PermissionStatus.granted) {
        _notificationWarning =
            'Notification permission denied; background download '
            'notifications are unavailable.';
      }
    } on Object catch (error) {
      _notificationWarning =
          'Notification permission could not be checked '
          '(${error.runtimeType}); background download notifications are '
          'unavailable.';
    }
  }

  @override
  Future<String> enqueue(
    DownloadRequest request,
    String stagingPath,
    int generation,
  ) async {
    if (!_initialized) throw StateError('DownloadEngine is not initialized');
    final parentId = _engineTaskId(request.id, generation);
    return _runForParent(parentId, () async {
      final existing = await _descriptors.readForStaging(stagingPath);
      if (existing != null &&
          existing.parentTaskId == parentId &&
          existing.businessId == request.id &&
          existing.generation == generation &&
          existing.state != DurableTransferState.canceled &&
          existing.state != DurableTransferState.failed) {
        _descriptorPaths[parentId] = _descriptors.pathFor(stagingPath);
        await _recoverMissingTasks(existing);
        return parentId;
      }
      if (existing != null &&
          (existing.state == DurableTransferState.canceled ||
              existing.state == DurableTransferState.failed)) {
        final obsoleteIds = existing.kind == DurableTransferKind.single
            ? [existing.parentTaskId]
            : existing.children.map((child) => child.taskId).toList();
        if (obsoleteIds.isNotEmpty) {
          await _downloader.cancelTasksWithIds(obsoleteIds);
        }
        await _deleteTransferFiles(existing, deleteStaging: false);
        await _descriptors.delete(existing);
      }
      return switch (request.strategy) {
        TransferStrategy.single => _enqueueSingle(
          request,
          stagingPath,
          generation,
          parentId,
        ),
        TransferStrategy.parallel => _enqueueParallel(
          request,
          stagingPath,
          generation,
          parentId,
        ),
      };
    });
  }

  Future<String> _enqueueSingle(
    DownloadRequest request,
    String stagingPath,
    int generation,
    String parentId,
  ) async {
    final representation = await _preflight.single(
      request.url,
      request.headers,
    );
    final expectedLength =
        representation.expectedLength ?? request.integrity.expectedBytes;
    var descriptor = DurableTransferDescriptor(
      businessId: request.id,
      generation: generation,
      parentTaskId: parentId,
      stagingPath: stagingPath,
      url: request.url.toString(),
      headers: request.headers,
      businessGroup: request.group,
      displayName:
          request.displayName ?? File(stagingPath).uri.pathSegments.last,
      kind: DurableTransferKind.single,
      state: DurableTransferState.preparing,
      expectedLength: expectedLength,
      strongETag: representation.strongETag,
      hasExpectedDigest: request.integrity.normalizedSha256 != null,
    );
    await _persist(descriptor);
    final task = _singleTask(descriptor);
    if (!await _downloader.enqueue(task)) {
      descriptor = descriptor.copyWith(
        state: DurableTransferState.failed,
        error: 'Native downloader rejected the single transfer',
      );
      await _persist(descriptor);
      throw StateError('Native downloader rejected the task');
    }
    descriptor = descriptor.copyWith(state: DurableTransferState.running);
    await _persist(descriptor);
    return parentId;
  }

  Future<String> _enqueueParallel(
    DownloadRequest request,
    String stagingPath,
    int generation,
    String parentId,
  ) async {
    final representation = await _preflight.parallel(
      request.url,
      request.headers,
      hasExpectedDigest: request.integrity.normalizedSha256 != null,
    );
    final expectedLength = representation.expectedLength;
    if (expectedLength == null || expectedLength <= 0) {
      throw const ParallelDownloadCapabilityException(
        'Range request did not provide a usable content length',
      );
    }
    final ranges = splitDownloadRanges(expectedLength, request.chunks);
    var descriptor = DurableTransferDescriptor(
      businessId: request.id,
      generation: generation,
      parentTaskId: parentId,
      stagingPath: stagingPath,
      url: request.url.toString(),
      headers: request.headers,
      businessGroup: request.group,
      displayName:
          request.displayName ?? File(stagingPath).uri.pathSegments.last,
      kind: DurableTransferKind.parallel,
      state: DurableTransferState.preparing,
      expectedLength: expectedLength,
      strongETag: representation.strongETag,
      hasExpectedDigest: request.integrity.normalizedSha256 != null,
      children: [
        for (final (index, range) in ranges.indexed)
          DurableTransferChild(
            taskId: _childTaskId(parentId, index, 0),
            index: index,
            start: range.start,
            end: range.end,
            path: '$stagingPath.dcomic-chunk-$index',
          ),
      ],
    );
    await _persist(descriptor);
    final results = await _downloader.enqueueAll(
      descriptor.children.map((child) => _chunkTask(descriptor, child)),
    );
    if (results.length != descriptor.children.length ||
        results.any((accepted) => !accepted)) {
      final acceptedIds = <String>[];
      for (
        var index = 0;
        index < math.min(results.length, descriptor.children.length);
        index++
      ) {
        if (results[index]) acceptedIds.add(descriptor.children[index].taskId);
      }
      if (acceptedIds.isNotEmpty) {
        await _downloader.cancelTasksWithIds(acceptedIds);
      }
      descriptor = descriptor.copyWith(
        state: DurableTransferState.failed,
        error: 'Native downloader rejected one or more Range tasks',
      );
      await _persist(descriptor);
      throw StateError('Native downloader rejected one or more Range tasks');
    }
    descriptor = descriptor.copyWith(state: DurableTransferState.running);
    await _persist(descriptor);
    return parentId;
  }

  DownloadTask _singleTask(DurableTransferDescriptor descriptor) {
    final output = _descriptors.stagingFile(descriptor.stagingPath);
    final task = DownloadTask(
      taskId: descriptor.parentTaskId,
      url: descriptor.url,
      filename: _filename(output),
      headers: identityRequestHeaders(
        descriptor.headers,
        strongETag: descriptor.strongETag,
      ),
      directory: output.parent.path,
      baseDirectory: BaseDirectory.root,
      group: _pluginGroup,
      updates: Updates.statusAndProgress,
      allowPause: descriptor.strongETag != null || descriptor.hasExpectedDigest,
      // Use WorkManager foreground transfers. In pinned 9.6.4, priority 0
      // selects Android UIDT whose DETACH policy can retain terminal progress.
      priority: 5,
      metaData: _metadata(descriptor, kind: 'single'),
      displayName: descriptor.displayName,
    );
    _configureSingleNotification(task, descriptor);
    return task;
  }

  void _configureSingleNotification(
    DownloadTask task,
    DurableTransferDescriptor descriptor,
  ) {
    final notificationGroupId = comicNotificationGroupId(
      descriptor.businessGroup,
    );
    if (notificationGroupId == null) return;
    // A batch notification cannot safely map Pause/Resume to every page;
    // retain only the aggregate controls supported by the plugin.
    _downloader.configureNotificationForTask(
      task,
      running: const TaskNotification(
        'Downloading chapter',
        '{numFinished} of {numTotal} pages',
      ),
      error: const TaskNotification(
        'Chapter download failed',
        '{numFailed} of {numTotal} pages failed',
      ),
      progressBar: true,
      tapOpensFile: false,
      groupNotificationId: notificationGroupId,
    );
  }

  DownloadTask _chunkTask(
    DurableTransferDescriptor descriptor,
    DurableTransferChild child,
  ) {
    final output = _descriptors.sidecarFile(descriptor.stagingPath, child.path);
    final task = DownloadTask(
      taskId: child.taskId,
      url: descriptor.url,
      filename: _filename(output),
      headers: identityRequestHeaders(
        descriptor.headers,
        range: child.range,
        strongETag: descriptor.strongETag,
      ),
      directory: output.parent.path,
      baseDirectory: BaseDirectory.root,
      group: _pluginGroup,
      updates: Updates.statusAndProgress,
      allowPause: false,
      priority: 5,
      metaData: _metadata(descriptor, kind: 'chunk', child: child),
      displayName: descriptor.displayName,
    );
    _downloader.configureNotificationForTask(
      task,
      running: const TaskNotification(
        'Downloading file',
        '{numFinished} of {numTotal} parts',
      ),
      error: const TaskNotification(
        'Download failed',
        '{numFailed} of {numTotal} parts failed',
      ),
      progressBar: true,
      tapOpensFile: false,
      groupNotificationId: descriptor.parentTaskId,
    );
    return task;
  }

  String _filename(File file) {
    final segments = file.uri.pathSegments;
    return segments.isEmpty ? file.path : segments.last;
  }

  String _metadata(
    DurableTransferDescriptor descriptor, {
    required String kind,
    DurableTransferChild? child,
  }) => jsonEncode({
    'schema': _metadataSchema,
    'kind': kind,
    'businessId': descriptor.businessId,
    'generation': descriptor.generation,
    'parentTaskId': descriptor.parentTaskId,
    'stagingPath': descriptor.stagingPath,
    'descriptorPath': _descriptors.pathFor(descriptor.stagingPath),
    if (child != null) ...{
      'childIndex': child.index,
      'rangeStart': child.start,
      'rangeEnd': child.end,
      'attempt': child.attempt,
    },
  });

  // Native notification Resume is reconciled into persisted business intent
  // before the transfer is admitted again by the service scheduler.
  void _configureNotifications() => _downloader.configureNotificationForGroup(
    _pluginGroup,
    running: const TaskNotification(
      'Downloading {displayName}',
      '{progress} · {networkSpeed}',
    ),
    error: const TaskNotification('Download failed', '{displayName}'),
    paused: const TaskNotification('Download paused', '{displayName}'),
    canceled: const TaskNotification('Download canceled', '{displayName}'),
    progressBar: true,
    tapOpensFile: false,
  );

  String _engineTaskId(String businessId, int generation) =>
      'dcomic-${sha256.convert(utf8.encode('$businessId\u0000$generation'))}';

  String _childTaskId(String parentId, int index, int attempt) =>
      'dcomic-${sha256.convert(utf8.encode('$parentId\u0000$index\u0000$attempt'))}';

  @override
  Future<bool> pause(String engineTaskId) =>
      _runForParent(engineTaskId, () async {
        final recovered = await _findDescriptor(engineTaskId);
        if (recovered == null) return false;
        var descriptor = recovered;
        if (descriptor.state == DurableTransferState.paused) {
          if (descriptor.externalResumeRequested) {
            await _persist(
              descriptor.copyWith(
                externalResumeRequested: false,
                resuming: false,
              ),
            );
          }
          return true;
        }
        if (descriptor.state == DurableTransferState.complete ||
            descriptor.state == DurableTransferState.failed ||
            descriptor.state == DurableTransferState.canceled) {
          return false;
        }
        descriptor = descriptor.copyWith(
          state: DurableTransferState.pauseRequested,
        );
        await _persist(descriptor);
        return descriptor.kind == DurableTransferKind.single
            ? _pauseSingle(descriptor)
            : _pauseParallel(descriptor);
      });

  Future<bool> _pauseSingle(DurableTransferDescriptor descriptor) async {
    final task = await _downloadTask(descriptor.parentTaskId);
    final tracked = await _downloader.database.recordForId(
      descriptor.parentTaskId,
    );
    if (tracked?.status.isFinalState == true) return false;
    final canSafelyAppend =
        descriptor.strongETag != null || descriptor.hasExpectedDigest;
    if (task != null && canSafelyAppend) {
      final resumable = await _downloader
          .taskCanResume(task)
          .timeout(const Duration(seconds: 10), onTimeout: () => false);
      if (resumable &&
          await _downloader.pause(task) &&
          await _waitForStatuses([task.taskId], const {TaskStatus.paused})) {
        await _persist(
          descriptor.copyWith(
            state: DurableTransferState.paused,
            resuming: false,
          ),
        );
        return true;
      }
    }
    final canceled =
        task == null ||
        await _downloader.cancelTaskWithId(descriptor.parentTaskId);
    final stopped =
        canceled &&
        await _waitForStatuses(
          [descriptor.parentTaskId],
          {TaskStatus.canceled, TaskStatus.failed, TaskStatus.notFound},
          missingIsAccepted: true,
        );
    if (!stopped) return false;
    await _persist(
      descriptor.copyWith(
        state: DurableTransferState.paused,
        restartRequired: true,
        resuming: false,
      ),
    );
    return true;
  }

  Future<bool> _pauseParallel(DurableTransferDescriptor descriptor) async {
    final unfinished = descriptor.children
        .where((child) => child.state != DurableChildState.complete)
        .toList(growable: false);
    for (final child in unfinished) {
      final tracked = await _downloader.database.recordForId(child.taskId);
      if (tracked?.status.isFinalState == true &&
          tracked?.status != TaskStatus.canceled) {
        return false;
      }
    }
    var allStopped = true;
    for (final child in unfinished) {
      final task = await _downloadTask(child.taskId);
      if (task != null) {
        await _downloader.cancelTaskWithId(child.taskId);
        allStopped =
            allStopped &&
            await _waitForStatuses(
              [child.taskId],
              {TaskStatus.canceled, TaskStatus.failed, TaskStatus.notFound},
              missingIsAccepted: true,
            );
      }
      final output = _descriptors.sidecarFile(
        descriptor.stagingPath,
        child.path,
      );
      if (await output.exists()) await output.delete();
    }
    if (!allStopped) return false;
    await _persist(
      descriptor.copyWith(
        state: DurableTransferState.paused,
        children: childrenForSafeParallelPause(descriptor.children),
        resuming: false,
      ),
    );
    return true;
  }

  @override
  Future<bool> resume(String engineTaskId) =>
      _runForParent(engineTaskId, () async {
        final recovered = await _findDescriptor(engineTaskId);
        if (recovered == null) return false;
        if (recovered.state == DurableTransferState.running &&
            recovered.resuming) {
          return true;
        }
        if (recovered.state != DurableTransferState.paused) return false;
        if (recovered.restartRequired) return false;
        final descriptor = recovered.copyWith(
          state: DurableTransferState.resumeRequested,
          resuming: true,
          externalResumeRequested: false,
        );
        await _persist(descriptor);
        return descriptor.kind == DurableTransferKind.single
            ? _resumeSingle(descriptor)
            : _resumeParallel(descriptor);
      });

  Future<bool> _resumeSingle(
    DurableTransferDescriptor descriptor, {
    _NativeFact? fact,
  }) async {
    if (fact != null &&
        fact.active &&
        (fact.status == null ||
            fact.status == TaskStatus.enqueued ||
            fact.status == TaskStatus.waitingToRetry ||
            fact.status == TaskStatus.running)) {
      if (fact.task is DownloadTask) {
        _configureSingleNotification(fact.task as DownloadTask, descriptor);
      }
      await _persist(descriptor.copyWith(state: DurableTransferState.running));
      return true;
    }
    final task = await _downloadTask(descriptor.parentTaskId);
    if (task != null) _configureSingleNotification(task, descriptor);
    if (task == null || !await _downloader.resume(task)) {
      await _persist(
        descriptor.copyWith(
          state: DurableTransferState.paused,
          restartRequired: true,
          resuming: false,
        ),
      );
      return false;
    }
    await _persist(descriptor.copyWith(state: DurableTransferState.running));
    return true;
  }

  Future<bool> _resumeParallel(
    DurableTransferDescriptor descriptor, {
    Map<String, _NativeFact>? facts,
  }) async {
    var children = descriptor.children.toList();
    for (final child in List<DurableTransferChild>.of(children)) {
      if (child.state == DurableChildState.complete) continue;
      final fact = facts?[child.taskId];
      if (fact != null &&
          fact.active &&
          (fact.status == null ||
              fact.status == TaskStatus.enqueued ||
              fact.status == TaskStatus.waitingToRetry ||
              fact.status == TaskStatus.running)) {
        children[child.index] = child.copyWith(
          state: DurableChildState.running,
        );
        continue;
      }
      if (fact?.status == TaskStatus.complete) {
        await _failDescriptor(
          descriptor.copyWith(children: children),
          'Completed Range task lacked durable Content-Range validation',
        );
        return false;
      }
      final replacement = child.copyWith(
        taskId: _childTaskId(
          descriptor.parentTaskId,
          child.index,
          child.attempt + 1,
        ),
        attempt: child.attempt + 1,
        state: DurableChildState.pending,
      );
      children[child.index] = replacement;
      descriptor = descriptor.copyWith(children: children);
      await _persist(descriptor);
      final staleOutput = _descriptors.sidecarFile(
        descriptor.stagingPath,
        replacement.path,
      );
      if (await staleOutput.exists()) await staleOutput.delete();
      if (!await _downloader.enqueue(_chunkTask(descriptor, replacement))) {
        final failed = await _failDescriptor(
          descriptor,
          'Native downloader rejected a resumed Range task',
        );
        await _cancelUnfinishedChildren(failed);
        return false;
      }
    }
    await _persist(
      descriptor.copyWith(
        state: DurableTransferState.running,
        children: children,
      ),
    );
    return true;
  }

  @override
  Future<bool> cancel(String engineTaskId) =>
      _runForParent(engineTaskId, () async {
        final descriptor = await _findDescriptor(engineTaskId);
        if (descriptor == null) {
          return _downloader.cancelTaskWithId(engineTaskId);
        }
        if (!shouldCancelNativeTasksOnRemoval(descriptor.state)) {
          await _deleteTransferFiles(descriptor, deleteStaging: false);
          await _descriptors.delete(descriptor);
          _descriptorPaths.remove(engineTaskId);
          return true;
        }
        final canceledDescriptor = descriptor.copyWith(
          state: DurableTransferState.canceled,
        );
        await _persist(canceledDescriptor);
        final ids = descriptor.kind == DurableTransferKind.single
            ? [descriptor.parentTaskId]
            : descriptor.children.map((child) => child.taskId).toList();
        if (ids.isNotEmpty) await _downloader.cancelTasksWithIds(ids);
        final stopped = await _waitForStatuses(ids, {
          TaskStatus.canceled,
          TaskStatus.failed,
          TaskStatus.notFound,
          TaskStatus.complete,
        }, missingIsAccepted: true);
        if (stopped) {
          await _deleteTransferFiles(canceledDescriptor, deleteStaging: false);
          await _descriptors.delete(canceledDescriptor);
          _descriptorPaths.remove(engineTaskId);
        }
        return stopped;
      });

  Future<DownloadTask?> _downloadTask(String taskId) async {
    for (final task in await _downloader.allTasks(allGroups: true)) {
      if (task.taskId == taskId && task is DownloadTask) return task;
    }
    return null;
  }

  Future<bool> _waitForStatuses(
    Iterable<String> taskIds,
    Set<TaskStatus> accepted, {
    bool missingIsAccepted = false,
  }) async {
    final ids = taskIds.toList(growable: false);
    if (ids.isEmpty) return true;
    final deadline = DateTime.now().add(const Duration(seconds: 10));
    do {
      var allAccepted = true;
      for (final id in ids) {
        final record = await _downloader.database.recordForId(id);
        if (record != null && accepted.contains(record.status)) continue;
        final active = await _downloadTask(id);
        if (active == null && missingIsAccepted) continue;
        allAccepted = false;
        break;
      }
      if (allAccepted) return true;
      await Future<void>.delayed(const Duration(milliseconds: 50));
    } while (DateTime.now().isBefore(deadline));
    return false;
  }

  @override
  Future<List<DownloadEngineSnapshot>> snapshot() async {
    await Future<void>.delayed(Duration.zero);
    await _updateTail;
    final activeTasks = await _downloader.allTasks(allGroups: true);
    final records = await _downloader.database.allRecords();
    final facts = <String, _NativeFact>{};
    for (final record in records) {
      final identity = _nativeIdentity(record.task);
      if (identity != null) {
        facts[record.taskId] = _NativeFact(
          task: record.task,
          status: record.status,
          progress: record.progress,
          expectedFileSize: record.expectedFileSize,
          exception: record.exception,
          active: false,
        );
      }
    }
    for (final task in activeTasks) {
      final identity = _nativeIdentity(task);
      if (identity != null) {
        final tracked = facts[task.taskId];
        facts[task.taskId] = _NativeFact(
          task: task,
          status: tracked?.status,
          progress: tracked?.progress ?? 0,
          expectedFileSize: tracked?.expectedFileSize ?? -1,
          exception: tracked?.exception,
          active: true,
        );
      }
    }

    final paths = <String>{..._descriptorPaths.values};
    for (final fact in facts.values) {
      final identity = _nativeIdentity(fact.task);
      if (identity != null) paths.add(identity.descriptorPath);
    }
    final descriptorsByParent = <String, DurableTransferDescriptor>{};
    for (final path in paths) {
      try {
        final descriptor = await _descriptors.read(path);
        if (descriptor != null) {
          descriptorsByParent[descriptor.parentTaskId] = descriptor;
          _descriptorPaths[descriptor.parentTaskId] = path;
          final fact = facts[descriptor.parentTaskId];
          if (descriptor.kind == DurableTransferKind.single &&
              fact?.active == true) {
            final task = fact!.task;
            if (task is DownloadTask) {
              _configureSingleNotification(task, descriptor);
            }
          }
        }
      } on FormatException {
        // An unparseable descriptor can never authorize merging. Owned native
        // tasks referencing it are canceled below.
      }
    }

    for (final fact in facts.values.where((fact) => fact.active)) {
      final identity = _nativeIdentity(fact.task);
      if (identity != null &&
          !descriptorsByParent.containsKey(identity.parentTaskId)) {
        await _downloader.cancelTaskWithId(fact.task.taskId);
      }
    }

    final result = <DownloadEngineSnapshot>[];
    for (final descriptor in descriptorsByParent.values) {
      final value = await _runForParent(
        descriptor.parentTaskId,
        () => _snapshotDescriptor(descriptor, facts),
      );
      if (value != null) result.add(value);
    }
    return result;
  }

  Future<DownloadEngineSnapshot?> _snapshotDescriptor(
    DurableTransferDescriptor initial,
    Map<String, _NativeFact> facts,
  ) async {
    var descriptor =
        await _descriptors.readForStaging(initial.stagingPath) ?? initial;
    if (descriptor.state == DurableTransferState.complete) {
      final staging = _descriptors.stagingFile(descriptor.stagingPath);
      if (!await staging.exists()) {
        await _deleteTransferFiles(descriptor, deleteStaging: false);
        await _descriptors.delete(descriptor);
        _descriptorPaths.remove(descriptor.parentTaskId);
        return null;
      }
      await _deleteChunkFiles(descriptor);
      return _snapshotFromDescriptor(
        descriptor,
        DownloadEngineState.complete,
        bytesReceived: await staging.length(),
      );
    }
    if (descriptor.state == DurableTransferState.canceled) {
      final ids = descriptor.kind == DurableTransferKind.single
          ? [descriptor.parentTaskId]
          : descriptor.children.map((child) => child.taskId).toList();
      final liveIds = ids.where((id) => facts[id]?.active == true).toList();
      if (liveIds.isNotEmpty) await _downloader.cancelTasksWithIds(liveIds);
      return _snapshotFromDescriptor(descriptor, DownloadEngineState.canceled);
    }
    if (descriptor.state == DurableTransferState.failed) {
      return _snapshotFromDescriptor(
        descriptor,
        DownloadEngineState.failed,
        error: descriptor.error,
        bytesReceived: await _receivedBytes(descriptor, facts),
      );
    }
    if (descriptor.kind == DurableTransferKind.single &&
        descriptor.state == DurableTransferState.paused) {
      final fact = facts[descriptor.parentTaskId];
      if (shouldReplayNativeCancellation(
        descriptor,
        nativeCanceled: fact?.status == TaskStatus.canceled,
      )) {
        descriptor = descriptor.copyWith(
          state: DurableTransferState.canceled,
          resuming: false,
          externalResumeRequested: false,
        );
        await _persist(descriptor);
        return _snapshotFromDescriptor(
          descriptor,
          DownloadEngineState.canceled,
          bytesReceived: await _singleFileLength(descriptor),
          error: 'Native transfer canceled',
        );
      }
      if (fact != null &&
          shouldCaptureExternalResume(
            descriptor,
            nativeActive: fact.active,
            nativeCompleted: fact.status == TaskStatus.complete,
            nativeRunnable: fact.canSignalExternalResume,
          )) {
        descriptor = descriptor.copyWith(
          state: fact.status == TaskStatus.complete
              ? DurableTransferState.paused
              : DurableTransferState.pauseRequested,
          resuming: true,
          externalResumeRequested: true,
        );
        await _persist(descriptor);
        if (fact.status == TaskStatus.complete) {
          descriptor = await _recoverCompletedSingle(descriptor, fact);
          return _snapshotFromDescriptor(
            descriptor,
            descriptor.state == DurableTransferState.complete
                ? DownloadEngineState.complete
                : DownloadEngineState.failed,
            bytesReceived: await _singleFileLength(descriptor),
            error: descriptor.error,
          );
        }
      }
    }
    if (descriptor.state == DurableTransferState.pauseRequested &&
        descriptor.externalResumeRequested &&
        descriptor.kind == DurableTransferKind.single) {
      final fact = facts[descriptor.parentTaskId];
      if (fact?.status == TaskStatus.complete) {
        descriptor = await _recoverCompletedSingle(descriptor, fact!);
        return _snapshotFromDescriptor(
          descriptor,
          descriptor.state == DurableTransferState.complete
              ? DownloadEngineState.complete
              : DownloadEngineState.failed,
          bytesReceived: await _singleFileLength(descriptor),
          error: descriptor.error,
        );
      }
      if (fact?.status == TaskStatus.paused) {
        descriptor = descriptor.copyWith(
          state: DurableTransferState.paused,
          resuming: false,
        );
        await _persist(descriptor);
        return _snapshotFromDescriptor(
          descriptor,
          DownloadEngineState.paused,
          bytesReceived: await _receivedBytes(descriptor, facts),
        );
      }
      if (fact?.status == TaskStatus.canceled ||
          fact?.status == TaskStatus.failed ||
          fact?.status == TaskStatus.notFound) {
        descriptor = descriptor.copyWith(
          state: DurableTransferState.paused,
          restartRequired: true,
          resuming: false,
        );
        await _persist(descriptor);
        return _snapshotFromDescriptor(
          descriptor,
          DownloadEngineState.paused,
          bytesReceived: await _receivedBytes(descriptor, facts),
        );
      }
    }
    if (descriptor.state == DurableTransferState.pauseRequested) {
      final confirmed = descriptor.kind == DurableTransferKind.single
          ? await _pauseSingle(descriptor)
          : await _pauseParallel(descriptor);
      descriptor =
          await _descriptors.readForStaging(descriptor.stagingPath) ??
          descriptor;
      if (!confirmed && descriptor.externalResumeRequested) return null;
      if (confirmed) {
        return _snapshotFromDescriptor(
          descriptor,
          DownloadEngineState.paused,
          bytesReceived: await _receivedBytes(descriptor, facts),
        );
      }
      descriptor = descriptor.copyWith(
        state: DurableTransferState.running,
        resuming: false,
      );
      await _persist(descriptor);
    }
    if (descriptor.state == DurableTransferState.resumeRequested) {
      final singleFact = facts[descriptor.parentTaskId];
      final completedSingle =
          descriptor.kind == DurableTransferKind.single &&
          singleFact?.status == TaskStatus.complete;
      final recovered = completedSingle
          ? true
          : descriptor.kind == DurableTransferKind.single
          ? await _resumeSingle(descriptor, fact: singleFact)
          : await _resumeParallel(descriptor, facts: facts);
      descriptor =
          await _descriptors.readForStaging(descriptor.stagingPath) ??
          descriptor;
      if (!recovered && descriptor.state == DurableTransferState.failed) {
        return _snapshotFromDescriptor(
          descriptor,
          DownloadEngineState.failed,
          bytesReceived: await _receivedBytes(descriptor, facts),
          error: descriptor.error,
        );
      }
      if (!recovered || descriptor.state == DurableTransferState.paused) {
        return _snapshotFromDescriptor(
          descriptor,
          DownloadEngineState.paused,
          bytesReceived: await _receivedBytes(descriptor, facts),
        );
      }
      if (completedSingle) {
        descriptor = descriptor.copyWith(state: DurableTransferState.running);
        await _persist(descriptor);
      }
    }
    if (descriptor.state == DurableTransferState.paused) {
      return _snapshotFromDescriptor(
        descriptor,
        DownloadEngineState.paused,
        bytesReceived: await _receivedBytes(descriptor, facts),
      );
    }
    if (descriptor.kind == DurableTransferKind.single) {
      final fact = facts[descriptor.parentTaskId];
      if (fact == null ||
          (!fact.active &&
              (fact.status == null || !fact.status!.isFinalState))) {
        await _recoverMissingTasks(descriptor, facts: facts);
        descriptor =
            await _descriptors.readForStaging(descriptor.stagingPath) ??
            descriptor;
        if (descriptor.state == DurableTransferState.failed) {
          return _snapshotFromDescriptor(
            descriptor,
            DownloadEngineState.failed,
            error: descriptor.error,
          );
        }
        return _snapshotFromDescriptor(descriptor, DownloadEngineState.running);
      }
      if (fact.status == TaskStatus.complete) {
        descriptor = await _recoverCompletedSingle(descriptor, fact);
        return _snapshotFromDescriptor(
          descriptor,
          descriptor.state == DurableTransferState.complete
              ? DownloadEngineState.complete
              : DownloadEngineState.failed,
          bytesReceived: await _singleFileLength(descriptor),
          error: descriptor.error,
        );
      }
      if (fact.status == TaskStatus.failed ||
          fact.status == TaskStatus.notFound) {
        descriptor = await _failDescriptor(
          descriptor,
          fact.exception?.toString() ?? 'Native single transfer failed',
        );
        return _snapshotFromDescriptor(
          descriptor,
          DownloadEngineState.failed,
          error: descriptor.error,
        );
      }
      if (fact.status == TaskStatus.canceled) {
        descriptor = descriptor.copyWith(
          state: DurableTransferState.canceled,
          resuming: false,
          externalResumeRequested: false,
        );
        await _persist(descriptor);
        return _snapshotFromDescriptor(
          descriptor,
          DownloadEngineState.canceled,
          bytesReceived: await _singleFileLength(descriptor),
          error: 'Native transfer canceled',
        );
      }
      if (fact.status == TaskStatus.paused) {
        descriptor = descriptor.copyWith(state: DurableTransferState.paused);
        await _persist(descriptor);
        return _snapshotFromDescriptor(
          descriptor,
          DownloadEngineState.paused,
          bytesReceived: _singleProgressBytes(descriptor, fact),
        );
      }
      return _snapshotFromDescriptor(
        descriptor,
        fact.status == TaskStatus.enqueued ||
                fact.status == TaskStatus.waitingToRetry
            ? DownloadEngineState.queued
            : DownloadEngineState.running,
        bytesReceived: _singleProgressBytes(descriptor, fact),
      );
    }

    var children = descriptor.children.toList();
    String? failure;
    for (final child in children) {
      if (child.state == DurableChildState.complete) continue;
      final fact = facts[child.taskId];
      if (fact == null) continue;
      if (fact.status == TaskStatus.complete) {
        failure =
            'Completed Range task lacked durable Content-Range validation';
        break;
      }
      if (fact.status == TaskStatus.failed ||
          fact.status == TaskStatus.notFound ||
          fact.status == TaskStatus.canceled) {
        failure =
            'Native Range request failed: '
            '${fact.exception?.toString() ?? 'unknown native failure'}';
        break;
      }
      if (fact.active && fact.status == TaskStatus.paused) {
        children[child.index] = child.copyWith(state: DurableChildState.paused);
      } else if (fact.active) {
        children[child.index] = child.copyWith(
          state: DurableChildState.running,
        );
      }
    }
    if (failure != null) {
      descriptor = await _failDescriptor(descriptor, failure);
      await _cancelUnfinishedChildren(descriptor);
      return _snapshotFromDescriptor(
        descriptor,
        DownloadEngineState.failed,
        bytesReceived: await _receivedBytes(descriptor, facts),
        error: descriptor.error,
      );
    }
    descriptor = descriptor.copyWith(
      state: DurableTransferState.running,
      children: children,
    );
    await _persist(descriptor);
    await _recoverMissingTasks(descriptor, facts: facts);
    descriptor =
        await _descriptors.readForStaging(descriptor.stagingPath) ?? descriptor;
    if (descriptor.state == DurableTransferState.failed) {
      return _snapshotFromDescriptor(
        descriptor,
        DownloadEngineState.failed,
        bytesReceived: await _receivedBytes(descriptor, facts),
        error: descriptor.error,
      );
    }
    if (descriptor.children.every(
      (child) => child.state == DurableChildState.complete,
    )) {
      descriptor = await _merge(descriptor);
      return _snapshotFromDescriptor(
        descriptor,
        descriptor.state == DurableTransferState.complete
            ? DownloadEngineState.complete
            : DownloadEngineState.failed,
        bytesReceived: descriptor.state == DurableTransferState.complete
            ? descriptor.expectedLength!
            : await _receivedBytes(descriptor, facts),
        error: descriptor.error,
      );
    }
    return _snapshotFromDescriptor(
      descriptor,
      DownloadEngineState.running,
      bytesReceived: await _receivedBytes(descriptor, facts),
    );
  }

  Future<void> _recoverMissingTasks(
    DurableTransferDescriptor descriptor, {
    Map<String, _NativeFact>? facts,
  }) async {
    if (descriptor.state == DurableTransferState.paused ||
        descriptor.state == DurableTransferState.pauseRequested ||
        descriptor.state == DurableTransferState.canceled ||
        descriptor.state == DurableTransferState.failed ||
        descriptor.state == DurableTransferState.complete) {
      return;
    }
    if (descriptor.kind == DurableTransferKind.single) {
      final knownFact = facts?[descriptor.parentTaskId];
      final nativeTask = facts == null
          ? await _downloadTask(descriptor.parentTaskId)
          : knownFact?.active == true
          ? knownFact!.task
          : null;
      if (nativeTask == null) {
        if (!await _downloader.enqueue(_singleTask(descriptor))) {
          await _failDescriptor(
            descriptor,
            'Native downloader rejected recovery of the single transfer',
          );
          return;
        }
      }
      await _persist(descriptor.copyWith(state: DurableTransferState.running));
      return;
    }
    final missing = <DurableTransferChild>[];
    for (final child in descriptor.children) {
      if (child.state == DurableChildState.complete) continue;
      final present = facts == null
          ? (await _downloadTask(child.taskId)) != null
          : facts[child.taskId]?.active == true;
      if (!present) missing.add(child);
    }
    if (missing.isEmpty) return;
    final results = await _downloader.enqueueAll(
      missing.map((child) => _chunkTask(descriptor, child)),
    );
    if (results.length != missing.length || results.any((value) => !value)) {
      await _failDescriptor(
        descriptor,
        'Native downloader rejected recovery of a Range request',
      );
      return;
    }
    await _persist(descriptor.copyWith(state: DurableTransferState.running));
  }

  Future<DurableTransferDescriptor> _recoverCompletedSingle(
    DurableTransferDescriptor descriptor,
    _NativeFact fact,
  ) async {
    final file = _descriptors.stagingFile(descriptor.stagingPath);
    if (!await file.exists()) {
      return _failDescriptor(
        descriptor,
        'TaskResumeException: native completion had no output; '
        'restarting from the beginning',
      );
    }
    if (!descriptor.hasExpectedDigest) {
      return _failDescriptor(
        descriptor,
        'TaskResumeException: native completion lacked durable HTTP '
        'response validation; restarting from the beginning',
      );
    }
    final actual = await file.length();
    final expected =
        descriptor.expectedLength ??
        (fact.expectedFileSize >= 0 ? fact.expectedFileSize : null);
    if (expected != null && actual != expected) {
      return _failDescriptor(
        descriptor,
        'TaskResumeException: recovered response length $actual did not '
        'match $expected; restarting from the beginning',
      );
    }
    final completed = descriptor.copyWith(
      state: DurableTransferState.complete,
      expectedLength: expected,
      clearError: true,
    );
    await _persist(completed);
    return completed;
  }

  void _queuePluginUpdate(TaskUpdate update) {
    final identity = _nativeIdentity(update.task);
    if (identity == null) return;
    final queued = _runForParent(
      identity.parentTaskId,
      () => _handlePluginUpdate(update, identity),
    );
    _updateTail = _updateTail
        .catchError((Object _) {})
        .then((_) => queued)
        .catchError((Object _) {});
  }

  Future<void> _handlePluginUpdate(
    TaskUpdate update,
    _NativeIdentity identity,
  ) async {
    final descriptor = await _descriptors.read(identity.descriptorPath);
    if (descriptor == null ||
        descriptor.parentTaskId != identity.parentTaskId ||
        descriptor.businessId != identity.businessId ||
        descriptor.generation != identity.generation) {
      if (update is TaskStatusUpdate && !update.status.isFinalState) {
        await _downloader.cancelTaskWithId(update.task.taskId);
      }
      return;
    }
    if (descriptor.state == DurableTransferState.canceled) {
      if (update is TaskStatusUpdate && !update.status.isFinalState) {
        await _downloader.cancelTaskWithId(update.task.taskId);
      }
      return;
    }
    if (update is TaskProgressUpdate) {
      await _handleProgress(update, descriptor, identity);
    } else if (update is TaskStatusUpdate) {
      await _handleStatus(update, descriptor, identity);
    }
  }

  Future<void> _handleProgress(
    TaskProgressUpdate update,
    DurableTransferDescriptor descriptor,
    _NativeIdentity identity,
  ) async {
    if (identity.kind == 'single') {
      if (descriptor.state == DurableTransferState.paused) {
        if (isNativeTransferProgress(update.progress)) {
          await _captureExternalSingleResume(descriptor);
        }
        return;
      }
      if (descriptor.state == DurableTransferState.pauseRequested &&
          descriptor.externalResumeRequested) {
        return;
      }
      var current = descriptor;
      if (current.expectedLength == null && update.expectedFileSize >= 0) {
        current = current.copyWith(expectedLength: update.expectedFileSize);
        await _persist(current);
      }
      final expected = current.expectedLength;
      final bytes =
          expected != null && update.progress >= 0 && update.progress <= 1
          ? (expected * update.progress).round()
          : 0;
      _emit(
        _snapshotFromDescriptor(
          current,
          DownloadEngineState.running,
          bytesReceived: bytes,
        ),
      );
      return;
    }
    final child = descriptor.children
        .where((value) => value.taskId == update.task.taskId)
        .firstOrNull;
    if (child == null) return;
    final bytes = await _receivedBytes(descriptor, {
      update.task.taskId: _NativeFact(
        task: update.task,
        progress: update.progress,
        expectedFileSize: update.expectedFileSize,
        active: true,
      ),
    });
    _emit(
      _snapshotFromDescriptor(
        descriptor,
        DownloadEngineState.running,
        bytesReceived: bytes,
      ),
    );
  }

  Future<void> _handleStatus(
    TaskStatusUpdate update,
    DurableTransferDescriptor descriptor,
    _NativeIdentity identity,
  ) async {
    if (identity.kind == 'single') {
      await _handleSingleStatus(update, descriptor);
      return;
    }
    final child = descriptor.children
        .where((value) => value.taskId == update.task.taskId)
        .firstOrNull;
    if (child == null) return;
    var children = descriptor.children.toList();
    switch (update.status) {
      case TaskStatus.enqueued ||
          TaskStatus.waitingToRetry ||
          TaskStatus.running:
        children[child.index] = child.copyWith(
          state: DurableChildState.running,
        );
        final running = descriptor.copyWith(
          state: DurableTransferState.running,
          children: children,
        );
        await _persist(running);
        _emit(
          _snapshotFromDescriptor(
            running,
            update.status == TaskStatus.running
                ? DownloadEngineState.running
                : DownloadEngineState.queued,
            bytesReceived: await _receivedBytes(running, const {}),
          ),
        );
        return;
      case TaskStatus.paused:
        children[child.index] = child.copyWith(state: DurableChildState.paused);
        final paused = descriptor.copyWith(children: children);
        await _persist(paused);
        if (descriptor.state == DurableTransferState.pauseRequested &&
            children.every(
              (value) =>
                  value.state == DurableChildState.paused ||
                  value.state == DurableChildState.complete ||
                  value.state == DurableChildState.pending,
            )) {
          final confirmed = paused.copyWith(state: DurableTransferState.paused);
          await _persist(confirmed);
          _emit(
            _snapshotFromDescriptor(
              confirmed,
              DownloadEngineState.paused,
              bytesReceived: await _receivedBytes(confirmed, const {}),
            ),
          );
        }
        return;
      case TaskStatus.complete:
        final file = _descriptors.sidecarFile(
          descriptor.stagingPath,
          child.path,
        );
        try {
          if (!await file.exists()) {
            throw const FormatException(
              'Range request completed without an output file',
            );
          }
          validateRangeResponse(
            statusCode: update.responseStatusCode,
            headers: update.responseHeaders,
            range: child.range,
            expectedLength: descriptor.expectedLength!,
            strongETag: descriptor.strongETag,
            actualFileLength: await file.length(),
          );
        } on Object catch (error) {
          final failed = await _failDescriptor(
            descriptor,
            'Range request validation failed: $error',
          );
          await _cancelUnfinishedChildren(failed);
          _emit(
            _snapshotFromDescriptor(
              failed,
              DownloadEngineState.failed,
              bytesReceived: await _receivedBytes(failed, const {}),
              error: failed.error,
            ),
          );
          return;
        }
        children[child.index] = child.copyWith(
          state: DurableChildState.complete,
        );
        var completed = descriptor.copyWith(children: children);
        await _persist(completed);
        if (children.every(
          (value) => value.state == DurableChildState.complete,
        )) {
          completed = await _merge(completed);
          _emit(
            _snapshotFromDescriptor(
              completed,
              completed.state == DurableTransferState.complete
                  ? DownloadEngineState.complete
                  : DownloadEngineState.failed,
              bytesReceived: completed.state == DurableTransferState.complete
                  ? completed.expectedLength!
                  : await _receivedBytes(completed, const {}),
              error: completed.error,
            ),
          );
        } else {
          _emit(
            _snapshotFromDescriptor(
              completed,
              DownloadEngineState.running,
              bytesReceived: await _receivedBytes(completed, const {}),
            ),
          );
        }
        return;
      case TaskStatus.failed || TaskStatus.notFound:
        if (descriptor.state == DurableTransferState.pauseRequested ||
            descriptor.state == DurableTransferState.paused) {
          children[child.index] = child.copyWith(
            state: DurableChildState.pending,
          );
          await _persist(descriptor.copyWith(children: children));
          return;
        }
        final failed = await _failDescriptor(
          descriptor,
          'Native Range request failed: '
          '${update.exception?.toString() ?? 'unknown native failure'}',
        );
        await _cancelUnfinishedChildren(failed);
        _emit(
          _snapshotFromDescriptor(
            failed,
            DownloadEngineState.failed,
            bytesReceived: await _receivedBytes(failed, const {}),
            error: failed.error,
          ),
        );
        return;
      case TaskStatus.canceled:
        if (descriptor.state == DurableTransferState.pauseRequested ||
            descriptor.state == DurableTransferState.paused) {
          children[child.index] = child.copyWith(
            state: DurableChildState.pending,
          );
          await _persist(descriptor.copyWith(children: children));
          return;
        }
        final failed = await _failDescriptor(
          descriptor,
          'Native Range request was canceled unexpectedly',
        );
        await _cancelUnfinishedChildren(failed);
        _emit(
          _snapshotFromDescriptor(
            failed,
            DownloadEngineState.failed,
            bytesReceived: await _receivedBytes(failed, const {}),
            error: failed.error,
          ),
        );
        return;
    }
  }

  Future<void> _captureExternalSingleResume(
    DurableTransferDescriptor descriptor,
  ) async {
    final tracked = await _downloader.database.recordForId(
      descriptor.parentTaskId,
    );
    if (tracked?.status == TaskStatus.paused) {
      _emit(
        _snapshotFromDescriptor(
          descriptor,
          DownloadEngineState.paused,
          bytesReceived: await _singleFileLength(descriptor),
        ),
      );
      return;
    }
    final active = await _downloadTask(descriptor.parentTaskId);
    if (active == null ||
        (tracked != null &&
            tracked.status != TaskStatus.enqueued &&
            tracked.status != TaskStatus.waitingToRetry &&
            tracked.status != TaskStatus.running)) {
      return;
    }
    var intent = descriptor.copyWith(
      state: DurableTransferState.pauseRequested,
      resuming: true,
      externalResumeRequested: true,
    );
    await _persist(intent);
    final confirmed = await _pauseSingle(intent);
    intent = await _descriptors.readForStaging(intent.stagingPath) ?? intent;
    if (confirmed) {
      _emit(
        _snapshotFromDescriptor(
          intent,
          DownloadEngineState.paused,
          bytesReceived: await _singleFileLength(intent),
        ),
      );
      return;
    }
    final finalRecord = await _downloader.database.recordForId(
      descriptor.parentTaskId,
    );
    if (finalRecord?.status == TaskStatus.canceled ||
        finalRecord?.status == TaskStatus.failed ||
        finalRecord?.status == TaskStatus.notFound) {
      intent = intent.copyWith(
        state: DurableTransferState.paused,
        restartRequired: true,
        resuming: false,
      );
      await _persist(intent);
      _emit(
        _snapshotFromDescriptor(
          intent,
          DownloadEngineState.paused,
          bytesReceived: await _singleFileLength(intent),
        ),
      );
    }
  }

  Future<void> _handleSingleStatus(
    TaskStatusUpdate update,
    DurableTransferDescriptor descriptor,
  ) async {
    if (descriptor.state == DurableTransferState.paused &&
        (update.status == TaskStatus.enqueued ||
            update.status == TaskStatus.waitingToRetry ||
            update.status == TaskStatus.running)) {
      await _captureExternalSingleResume(descriptor);
      return;
    }
    if (descriptor.state == DurableTransferState.paused &&
        update.status == TaskStatus.complete) {
      descriptor = descriptor.copyWith(
        resuming: true,
        externalResumeRequested: true,
      );
      await _persist(descriptor);
    }
    switch (update.status) {
      case TaskStatus.enqueued ||
          TaskStatus.waitingToRetry ||
          TaskStatus.running:
        final running = descriptor.copyWith(
          state: DurableTransferState.running,
        );
        await _persist(running);
        _emit(
          _snapshotFromDescriptor(
            running,
            update.status == TaskStatus.running
                ? DownloadEngineState.running
                : DownloadEngineState.queued,
          ),
        );
        return;
      case TaskStatus.paused:
        final paused = descriptor.copyWith(
          state: DurableTransferState.paused,
          resuming: false,
        );
        await _persist(paused);
        _emit(
          _snapshotFromDescriptor(
            paused,
            DownloadEngineState.paused,
            bytesReceived: await _singleFileLength(paused),
          ),
        );
        return;
      case TaskStatus.complete:
        final file = _descriptors.stagingFile(descriptor.stagingPath);
        try {
          if (!await file.exists()) {
            throw const FormatException(
              'Single request completed without an output file',
            );
          }
          final actualLength = await file.length();
          final expected = validateSingleResponse(
            statusCode: update.responseStatusCode,
            headers: update.responseHeaders,
            expectedLength: descriptor.expectedLength,
            strongETag: descriptor.strongETag,
            actualFileLength: actualLength,
            resuming: descriptor.resuming,
          );
          final completed = descriptor.copyWith(
            state: DurableTransferState.complete,
            expectedLength: expected,
            clearError: true,
          );
          await _persist(completed);
          _emit(
            _snapshotFromDescriptor(
              completed,
              DownloadEngineState.complete,
              bytesReceived: actualLength,
            ),
          );
        } on Object catch (error) {
          final failed = await _failDescriptor(
            descriptor,
            'Single response validation failed: $error',
          );
          _emit(
            _snapshotFromDescriptor(
              failed,
              DownloadEngineState.failed,
              error: failed.error,
            ),
          );
        }
        return;
      case TaskStatus.failed || TaskStatus.notFound:
        if (descriptor.state == DurableTransferState.pauseRequested) {
          if (descriptor.externalResumeRequested) {
            final paused = descriptor.copyWith(
              state: DurableTransferState.paused,
              restartRequired: true,
              resuming: false,
            );
            await _persist(paused);
            _emit(
              _snapshotFromDescriptor(
                paused,
                DownloadEngineState.paused,
                bytesReceived: await _singleFileLength(paused),
              ),
            );
          }
          return;
        }
        final statusCode = update.responseStatusCode ??
            (update.status == TaskStatus.notFound ? HttpStatus.notFound : null);
        final error = update.exception?.toString() ?? 'Native single transfer failed';
        final failed = await _failDescriptor(
          descriptor,
          statusCode == null ? error : 'HTTP $statusCode: $error',
        );
        _emit(
          _snapshotFromDescriptor(
            failed,
            DownloadEngineState.failed,
            error: failed.error,
          ),
        );
        return;
      case TaskStatus.canceled:
        if (descriptor.state == DurableTransferState.pauseRequested) {
          if (descriptor.externalResumeRequested) {
            final paused = descriptor.copyWith(
              state: DurableTransferState.paused,
              restartRequired: true,
              resuming: false,
            );
            await _persist(paused);
            _emit(
              _snapshotFromDescriptor(
                paused,
                DownloadEngineState.paused,
                bytesReceived: await _singleFileLength(paused),
              ),
            );
          }
          return;
        }
        if (descriptor.state == DurableTransferState.paused &&
            descriptor.restartRequired) {
          return;
        }
        final canceled = descriptor.copyWith(
          state: DurableTransferState.canceled,
          resuming: false,
          externalResumeRequested: false,
        );
        await _persist(canceled);
        _emit(
          _snapshotFromDescriptor(
            canceled,
            DownloadEngineState.canceled,
            error: 'Native transfer canceled',
          ),
        );
        return;
    }
  }


  Future<DurableTransferDescriptor> _merge(
    DurableTransferDescriptor descriptor,
  ) async {
    var merging = descriptor.copyWith(state: DurableTransferState.merging);
    await _persist(merging);
    final mergeFile = _descriptors.sidecarFile(
      descriptor.stagingPath,
      _descriptors.mergePathFor(descriptor.stagingPath),
    );
    IOSink? sink;
    try {
      if (await mergeFile.exists()) await mergeFile.delete();
      sink = mergeFile.openWrite(mode: FileMode.writeOnly);
      var mergedLength = 0;
      final ordered = [...descriptor.children]
        ..sort((left, right) => left.start.compareTo(right.start));
      var nextStart = 0;
      for (final child in ordered) {
        if (child.start != nextStart) {
          throw const FormatException(
            'Range chunks do not form a contiguous file',
          );
        }
        final source = _descriptors.sidecarFile(
          descriptor.stagingPath,
          child.path,
        );
        if (!await source.exists()) {
          throw FormatException(
            'Validated Range chunk ${child.index} is missing',
          );
        }
        final length = await source.length();
        if (length != child.range.length) {
          throw FormatException(
            'Validated Range chunk ${child.index} changed length',
          );
        }
        await sink.addStream(source.openRead());
        mergedLength += length;
        nextStart = child.end + 1;
      }
      await sink.flush();
      await sink.close();
      sink = null;
      if (mergedLength != descriptor.expectedLength ||
          await mergeFile.length() != descriptor.expectedLength) {
        throw FormatException(
          'Merged Range length did not match ${descriptor.expectedLength}',
        );
      }
      final staging = _descriptors.stagingFile(descriptor.stagingPath);
      if (await staging.exists()) await staging.delete();
      await mergeFile.rename(staging.path);
      merging = descriptor.copyWith(
        state: DurableTransferState.complete,
        clearError: true,
      );
      await _persist(merging);
      await _deleteChunkFiles(merging);
      return merging;
    } on Object catch (error) {
      await sink?.close();
      try {
        if (await mergeFile.exists()) await mergeFile.delete();
      } on FileSystemException {
        // The failed descriptor prevents publication even if cleanup is retried.
      }
      return _failDescriptor(merging, 'Range merge validation failed: $error');
    }
  }

  Future<DurableTransferDescriptor> _failDescriptor(
    DurableTransferDescriptor descriptor,
    String error,
  ) async {
    final failed = descriptor.copyWith(
      state: DurableTransferState.failed,
      error: error,
    );
    await _persist(failed);
    return failed;
  }

  Future<void> _cancelUnfinishedChildren(
    DurableTransferDescriptor descriptor,
  ) async {
    final ids = descriptor.children
        .where((child) => child.state != DurableChildState.complete)
        .map((child) => child.taskId)
        .toList(growable: false);
    if (ids.isNotEmpty) await _downloader.cancelTasksWithIds(ids);
  }

  Future<int> _receivedBytes(
    DurableTransferDescriptor descriptor,
    Map<String, _NativeFact> facts,
  ) async {
    if (descriptor.kind == DurableTransferKind.single) {
      final fact = facts[descriptor.parentTaskId];
      if (fact == null) return _singleFileLength(descriptor);
      return _singleProgressBytes(descriptor, fact);
    }
    var total = 0;
    for (final child in descriptor.children) {
      if (child.state == DurableChildState.complete) {
        total += child.range.length;
        continue;
      }
      final fact = facts[child.taskId];
      if (fact != null && fact.progress >= 0 && fact.progress <= 1) {
        total += (child.range.length * fact.progress).round();
      }
    }
    return math.min(total, descriptor.expectedLength!);
  }

  int _singleProgressBytes(
    DurableTransferDescriptor descriptor,
    _NativeFact fact,
  ) {
    final expected =
        descriptor.expectedLength ??
        (fact.expectedFileSize >= 0 ? fact.expectedFileSize : null);
    if (expected == null || fact.progress < 0 || fact.progress > 1) return 0;
    return (expected * fact.progress).round();
  }

  Future<int> _singleFileLength(DurableTransferDescriptor descriptor) async {
    final file = _descriptors.stagingFile(descriptor.stagingPath);
    if (!await file.exists()) return 0;
    return file.length();
  }

  DownloadEngineSnapshot _snapshotFromDescriptor(
    DurableTransferDescriptor descriptor,
    DownloadEngineState state, {
    int bytesReceived = 0,
    String? error,
  }) => DownloadEngineSnapshot(
    businessId: descriptor.businessId,
    generation: descriptor.generation,
    engineTaskId: descriptor.parentTaskId,
    state: state,
    bytesReceived: bytesReceived,
    totalBytes: descriptor.expectedLength,
    resumeRequested: descriptor.externalResumeRequested,
    stagingPath: descriptor.stagingPath,
    error: error,
  );

  void _emit(DownloadEngineSnapshot snapshot) {
    if (_updates.isClosed) return;
    _updates.add(
      DownloadEngineUpdate(
        businessId: snapshot.businessId,
        generation: snapshot.generation,
        engineTaskId: snapshot.engineTaskId,
        state: snapshot.state,
        bytesReceived: snapshot.bytesReceived,
        totalBytes: snapshot.totalBytes,
        stagingPath: snapshot.stagingPath,
        resumeRequested: snapshot.resumeRequested,
        error: snapshot.error,
      ),
    );
  }

  Future<void> _persist(DurableTransferDescriptor descriptor) async {
    await _descriptors.write(descriptor);
    _descriptorPaths[descriptor.parentTaskId] = _descriptors.pathFor(
      descriptor.stagingPath,
    );
  }

  Future<DurableTransferDescriptor?> _findDescriptor(String parentId) async {
    final knownPath = _descriptorPaths[parentId];
    if (knownPath != null) {
      final known = await _descriptors.read(knownPath);
      if (known != null) return known;
    }
    final task = await _downloader.taskForId(parentId);
    final direct = task == null ? null : _nativeIdentity(task);
    if (direct != null) {
      final descriptor = await _descriptors.read(direct.descriptorPath);
      if (descriptor != null) {
        _descriptorPaths[parentId] = direct.descriptorPath;
        return descriptor;
      }
    }
    final active = await _downloader.allTasks(allGroups: true);
    for (final candidate in active) {
      final identity = _nativeIdentity(candidate);
      if (identity?.parentTaskId != parentId) continue;
      final descriptor = await _descriptors.read(identity!.descriptorPath);
      if (descriptor != null) {
        _descriptorPaths[parentId] = identity.descriptorPath;
        return descriptor;
      }
    }
    final records = await _downloader.database.allRecords();
    for (final record in records) {
      final identity = _nativeIdentity(record.task);
      if (identity?.parentTaskId != parentId) continue;
      final descriptor = await _descriptors.read(identity!.descriptorPath);
      if (descriptor != null) {
        _descriptorPaths[parentId] = identity.descriptorPath;
        return descriptor;
      }
    }
    return null;
  }

  _NativeIdentity? _nativeIdentity(Task task) {
    if (task.group != _pluginGroup) return null;
    try {
      final value = jsonDecode(task.metaData);
      if (value is! Map || value['schema'] != _metadataSchema) return null;
      final kind = value['kind'];
      final businessId = value['businessId'];
      final generation = value['generation'];
      final parentTaskId = value['parentTaskId'];
      final descriptorPath = value['descriptorPath'];
      if (kind is! String ||
          businessId is! String ||
          generation is! int ||
          parentTaskId is! String ||
          descriptorPath is! String ||
          (kind != 'single' && kind != 'chunk')) {
        return null;
      }
      return _NativeIdentity(
        kind: kind,
        businessId: businessId,
        generation: generation,
        parentTaskId: parentTaskId,
        descriptorPath: descriptorPath,
      );
    } on FormatException {
      return null;
    }
  }

  Future<void> _deleteChunkFiles(DurableTransferDescriptor descriptor) async {
    if (descriptor.kind != DurableTransferKind.parallel) return;
    for (final child in descriptor.children) {
      try {
        final file = _descriptors.sidecarFile(
          descriptor.stagingPath,
          child.path,
        );
        if (await file.exists()) await file.delete();
      } on FileSystemException {
        // A completed staging file is authoritative; stale chunks are retried
        // during later descriptor cleanup.
      }
    }
  }

  Future<void> _deleteTransferFiles(
    DurableTransferDescriptor descriptor, {
    required bool deleteStaging,
  }) async {
    await _deleteChunkFiles(descriptor);
    if (deleteStaging) {
      final staging = _descriptors.stagingFile(descriptor.stagingPath);
      if (await staging.exists()) await staging.delete();
    }
  }

  Future<T> _runForParent<T>(String parentId, Future<T> Function() operation) {
    final result = Completer<T>();
    final previous = _parentOperations[parentId] ?? Future<void>.value();
    late final Future<void> chain;
    chain = previous
        .catchError((Object _) {})
        .then((_) async {
          try {
            result.complete(await operation());
          } on Object catch (error, stackTrace) {
            result.completeError(error, stackTrace);
          }
        })
        .whenComplete(() {
          if (identical(_parentOperations[parentId], chain)) {
            _parentOperations.remove(parentId);
          }
        });
    _parentOperations[parentId] = chain;
    return result.future;
  }

  @override
  Future<void> dispose() async {
    await _updateTail;
    await _pluginSubscription?.cancel();
    _pluginSubscription = null;
    await _updates.close();
    _downloader.destroy();
    _initialized = false;
  }
}

class _NativeIdentity {
  final String kind;
  final String businessId;
  final int generation;
  final String parentTaskId;
  final String descriptorPath;

  const _NativeIdentity({
    required this.kind,
    required this.businessId,
    required this.generation,
    required this.parentTaskId,
    required this.descriptorPath,
  });
}

class _NativeFact {
  final Task task;
  final TaskStatus? status;
  final double progress;
  final int expectedFileSize;
  final TaskException? exception;
  final bool active;

  const _NativeFact({
    required this.task,
    this.status,
    this.progress = 0,
    this.expectedFileSize = -1,
    this.exception,
    this.active = false,
  });

  bool get canSignalExternalResume =>
      status == null ||
      status == TaskStatus.enqueued ||
      status == TaskStatus.waitingToRetry ||
      status == TaskStatus.running;
}
