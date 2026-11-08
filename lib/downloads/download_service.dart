import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:dcomic/database/database_instance.dart';
import 'package:dcomic/downloads/download_cache.dart';
import 'package:dcomic/downloads/download_engine.dart';
import 'package:dcomic/downloads/download_files.dart';
import 'package:dcomic/downloads/download_models.dart';
import 'package:dcomic/downloads/download_store.dart';
import 'package:path_provider/path_provider.dart';

class DownloadService {
  static DownloadService? _globalInstance;

  static DownloadService get instance => _globalInstance ??= DownloadService();

  DownloadStore? _store;
  DownloadEngine? _engine;
  DownloadFiles? _files;
  DownloadCache? _cache;
  final Future<Directory> Function() _rootDirectoryProvider;
  Future<Directory>? _rootDirectoryFuture;
  Future<void>? _initializeFuture;
  StreamSubscription<DownloadEngineUpdate>? _engineSubscription;
  final StreamController<List<DownloadRecord>> _changes =
      StreamController<List<DownloadRecord>>.broadcast();
  final Map<String, Future<void>> _taskOperations = {};
  Future<void> _scheduleTail = Future<void>.value();
  final Set<String> _pendingCanceledGroups = <String>{};
  Future<void> _groupCancellationTail = Future<void>.value();
  static const int _maxConnections = 4;
  static const int _maxConnectionsPerHost = 2;
  bool _initialized = false;
  bool _disposed = false;
  Future<void>? _disposeFuture;

  DownloadService({
    DownloadStore? store,
    DownloadEngine? engine,
    DownloadFiles? files,
    DownloadCache? cache,
    Future<Directory> Function()? rootDirectoryProvider,
  }) : _store = store,
       _engine = engine,
       _files = files,
       _cache = cache,
       _rootDirectoryProvider = rootDirectoryProvider ?? _defaultRootDirectory {
    if (files != null) {
      _rootDirectoryFuture = Future<Directory>.value(files.root);
    }
  }

  DownloadEngine get engine =>
      _engine ?? (throw StateError('DownloadService is not initialized'));

  String? get notificationWarning => _engine?.notificationWarning;

  Future<Directory> get rootDirectory =>
      _rootDirectoryFuture ??= _rootDirectoryProvider();

  static Future<Directory> _defaultRootDirectory() async {
    final support = await getApplicationSupportDirectory();
    return Directory.fromUri(support.uri.resolve('downloads/'));
  }

  Future<void> initialize() {
    if (_disposed) {
      return Future<void>.error(StateError('DownloadService is disposed'));
    }
    return _initializeFuture ??= _initializeWithRetryReset();
  }

  Future<void> _initializeWithRetryReset() async {
    try {
      await _initialize();
    } on Object {
      _initialized = false;
      _initializeFuture = null;
      rethrow;
    }
  }

  Future<void> _initialize() async {
    if (_initialized) return;
    _ensureNotDisposed();
    final directory = await rootDirectory;
    _files ??= DownloadFiles(directory);
    _ensureNotDisposed();
    await _files!.initialize();
    if (_store == null) {
      final database = await DatabaseInstance.instance;
      _store = DownloadStore(database.downloadTaskDao);
    }
    _ensureNotDisposed();
    _cache ??= DownloadCache();
    _engine ??= BackgroundDownloadEngine();
    _engineSubscription ??= _engine!.updates.listen(
      (update) => _handleEngineUpdate(update),
      onError: (Object error, StackTrace stackTrace) {
        // Native records remain authoritative and are consumed by reconcile.
      },
    );
    await _engine!.initialize();
    _ensureNotDisposed();
    await _reconcileInternal(schedule: false);
    _ensureNotDisposed();
    await _scheduleQueued();
    await _emit();
    _initialized = true;
    await _scheduleQueued();
    _ensureNotDisposed();
  }

  Future<String> submit(DownloadRequest request) async {
    await initialize();
    if (request.strategy == TransferStrategy.parallel &&
        request.chunks > _maxConnections) {
      throw ArgumentError.value(
        request.chunks,
        'request.chunks',
        'cannot exceed the $_maxConnections-connection budget',
      );
    }
    final id = await _runFor(request.id, () async {
      final existing = await _store!.get(request.id);
      if (existing != null) {
        if (!existing.request.sameContentAs(request)) {
          throw StateError(
            'Download id ${request.id} is already used by different content',
          );
        }
        return existing.id;
      }
      await _store!.insert(request);
      await _emit();
      return request.id;
    });
    await _scheduleQueued();
    return id;
  }

  Future<void> _startQueued(DownloadRecord record) async {
    var current = await _store!.get(record.id);
    if (current == null ||
        current.generation != record.generation ||
        current.state != DownloadState.queued) {
      return;
    }
    var staging = await _files!.prepareStaging(current.id, current.generation);
    if (await _cache!.copyValid(current.request, staging)) {
      final cacheLength = await staging.length();
      if (!await _store!.updateProgress(
        current.id,
        current.generation,
        cacheLength,
        cacheLength,
      )) {
        return;
      }
      current = await _requiredRecord(current.id);
      if (await _store!.transition(
        current.id,
        current.generation,
        DownloadState.queued,
        DownloadState.verifying,
      )) {
        await _emit();
        final completed = await _verifyAndCommit(
          current,
          staging,
          cacheFallback: true,
        );
        if (completed) return;
      } else {
        return;
      }
      current = await _requiredRecord(current.id);
      if (current.state != DownloadState.queued) return;
      staging = await _files!.prepareStaging(current.id, current.generation);
    }

    final engineRequest = current.effectiveStrategy == current.request.strategy
        ? current.request
        : current.request.copyWith(
            strategy: current.effectiveStrategy,
            chunks: current.effectiveStrategy == TransferStrategy.single
                ? 1
                : current.request.chunks,
          );
    final engineTaskId = await _engine!.enqueue(
      engineRequest,
      staging.path,
      current.generation,
    );
    if (!await _store!.bindEngine(
      current.id,
      current.generation,
      engineTaskId,
    )) {
      await _engine!.cancel(engineTaskId);
      return;
    }
    await _store!.transition(
      current.id,
      current.generation,
      DownloadState.queued,
      DownloadState.running,
      error: current.error,
    );
    await _emit();
  }

  Future<bool> _verifyAndCommit(
    DownloadRecord record,
    File staging, {
    bool cacheFallback = false,
  }) async {
    try {
      final current = await _store!.get(record.id);
      if (current == null ||
          current.generation != record.generation ||
          current.state != DownloadState.verifying) {
        return false;
      }
      final destination = _files!.resolve(current.request.relativePath);
      if (!await staging.exists() && await destination.exists()) {
        try {
          final integrity = _integrityFor(current);
          if (!integrity.hasExpectation) {
            throw const FormatException(
              'existing output has no durable verification identity',
            );
          }
          await _files!.verify(destination, integrity);
          if (await _store!.transition(
            current.id,
            current.generation,
            DownloadState.verifying,
            DownloadState.completed,
            completedAt: DateTime.now().toUtc(),
          )) {
            await _emit();
            return true;
          }
          return false;
        } on Object {
          await _files!.deleteFinal(current.request.relativePath);
        }
      }
      await _files!.verify(staging, _integrityFor(current));
      final beforeCommit = await _store!.get(current.id);
      if (beforeCommit == null ||
          beforeCommit.generation != current.generation ||
          beforeCommit.state != DownloadState.verifying) {
        return false;
      }
      await _files!.commit(staging, current.request.relativePath);
      final accepted = await _store!.transition(
        current.id,
        current.generation,
        DownloadState.verifying,
        DownloadState.completed,
        completedAt: DateTime.now().toUtc(),
      );
      if (accepted) await _emit();
      return accepted;
    } on Object catch (error) {
      await _files!.deleteStaging(record.id, record.generation);
      if (cacheFallback) {
        final reset = await _store!.restart(
          record.id,
          record.generation,
          DownloadState.verifying,
        );
        if (reset) await _emit();
        return false;
      }
      if (error is FormatException &&
          record.effectiveStrategy == TransferStrategy.parallel) {
        final fallback = await _store!.fallBackToSingleConnection(
          record.id,
          record.generation,
          'Parallel Range output was invalid; retrying with one connection',
        );
        if (fallback) {
          await _files!.deleteFinal(record.request.relativePath);
          await _emit();
          return false;
        }
      }
      final failed = await _store!.transition(
        record.id,
        record.generation,
        DownloadState.verifying,
        DownloadState.failed,
        error: _safeError(error, record.request),
      );
      if (failed) await _emit();
      return false;
    }
  }

  Future<void> pause(String id) async {
    await initialize();
    await _runFor(id, () async {
      final record = await _requiredRecord(id);
      if (record.state == DownloadState.paused) {
        if (record.resumeRequested) {
          if (record.engineTaskId != null &&
              !await _engine!.pause(record.engineTaskId!)) {
            throw StateError('The server or platform rejected pause for $id');
          }
          if (!await _store!.transition(
            id,
            record.generation,
            DownloadState.paused,
            DownloadState.paused,
          )) {
            throw StateError('Download $id changed while pausing');
          }
          await _emit();
        }
        return;
      }
      if (record.state != DownloadState.queued &&
          record.state != DownloadState.running) {
        throw StateError(
          'Download $id cannot be paused from ${record.state.name}',
        );
      }
      final engineTaskId = record.engineTaskId;
      if (engineTaskId != null && !await _engine!.pause(engineTaskId)) {
        throw StateError('The server or platform rejected pause for $id');
      }
      if (!await _store!.transition(
        id,
        record.generation,
        record.state,
        DownloadState.paused,
      )) {
        throw StateError('Download $id changed while pausing');
      }
      await _emit();
    });
    await _scheduleQueued();
  }

  Future<void> resume(String id) async {
    await initialize();
    await _runFor(id, () async {
      final record = await _requiredRecord(id);
      if (record.state != DownloadState.paused &&
          record.state != DownloadState.failed) {
        throw StateError(
          'Download $id cannot resume from ${record.state.name}',
        );
      }
      final engineTaskId = record.engineTaskId;
      if (record.state == DownloadState.paused && engineTaskId != null) {
        if (!await _store!.requestResume(id, record.generation)) {
          throw StateError('Download $id changed while requesting resume');
        }
        await _emit();
        return;
      }
      if (engineTaskId != null) {
        await _engine!.cancel(engineTaskId);
      }
      if (!await _store!.restart(
        id,
        record.generation,
        record.state,
        reason: 'Partial transfer unavailable; restarted from the beginning',
      )) {
        throw StateError('Download $id changed while restarting');
      }
      await _files!.deleteStaging(id, record.generation);
      await _emit();
    });
    await _scheduleQueued();
  }

  Future<void> cancel(String id) async {
    await initialize();
    await _runFor(id, () async {
      final record = await _requiredRecord(id);
      if (record.state == DownloadState.canceled) return;
      if (record.state == DownloadState.completed) {
        throw StateError('Use remove to delete a completed download');
      }
      final canceled = await _store!.cancel(id);
      if (canceled == null)
        throw StateError('Download $id changed while canceling');
      await _emit();
      Object? nativeError;
      if (record.engineTaskId != null) {
        try {
          if (!await _engine!.cancel(record.engineTaskId!)) {
            nativeError = StateError('Native downloader rejected cancellation');
          }
        } on Object catch (error) {
          nativeError = error;
        }
      }
      await _files!.deleteAllStaging(id);
      await _files!.deleteFinal(record.request.relativePath);
      if (nativeError != null) throw nativeError;
    });
    await _scheduleQueued();
  }

  Future<void> remove(String id) async {
    await initialize();
    await _runFor(id, () async {
      final record = await _requiredRecord(id);
      final canceled = await _store!.cancel(id);
      if (canceled == null)
        throw StateError('Download $id changed while removing');
      await _emit();
      if (record.engineTaskId != null) {
        try {
          await _engine!.cancel(record.engineTaskId!);
        } on Object {
          // Generation fencing is already durable. Reconcile will cancel any
          // orphan that remains in the native database.
        }
      }
      await _files!.deleteAllStaging(id);
      await _files!.deleteFinal(record.request.relativePath);
      if (!await _store!.delete(id, canceled.generation)) {
        throw StateError('Download $id changed while removing');
      }
      await _emit();
    });
    await _scheduleQueued();
  }

  Future<void> reconcile() async {
    await initialize();
    await _reconcileInternal();
  }

  Future<void> _reconcileInternal({bool schedule = true}) async {
    final native = await _engine!.snapshot();
    final records = await _store!.list();
    final businessById = {for (final record in records) record.id: record};

    for (final task in native) {
      final business = businessById[task.businessId];
      if (business == null ||
          business.generation != task.generation ||
          business.state == DownloadState.canceled ||
          business.state == DownloadState.completed) {
        if (task.state != DownloadEngineState.complete &&
            task.state != DownloadEngineState.failed &&
            task.state != DownloadEngineState.canceled) {
          await _engine!.cancel(task.engineTaskId);
        }
      }
    }

    for (final record in records) {
      final matching = native
          .where(
            (task) =>
                task.businessId == record.id &&
                task.generation == record.generation,
          )
          .toList(growable: false);
      await _runFor(record.id, () => _reconcileRecord(record.id, matching));
    }
    await _drainCanceledGroups();
    if (schedule) await _scheduleQueued();
  }

  Future<void> _reconcileRecord(
    String id,
    List<DownloadEngineSnapshot> native,
  ) async {
    var record = await _store!.get(id);
    if (record == null) return;
    if (record.state == DownloadState.canceled) {
      for (final task in native) {
        await _engine!.cancel(task.engineTaskId);
      }
      await _files!.deleteAllStaging(id);
      await _files!.deleteFinal(record.request.relativePath);
      return;
    }
    if (record.state == DownloadState.completed) {
      await _completedFileInternal(record);
      return;
    }
    if (record.state == DownloadState.paused) {
      DownloadEngineSnapshot? selected;
      if (record.engineTaskId != null) {
        for (final task in native) {
          if (task.engineTaskId == record.engineTaskId) {
            selected = task;
            break;
          }
        }
      }
      selected ??= native.isEmpty ? null : native.first;
      if (selected == null && record.resumeRequested) {
        if (await _store!.restart(
          id,
          record.generation,
          DownloadState.paused,
          reason: 'Partial transfer unavailable; restarted from the beginning',
        )) {
          await _files!.deleteStaging(id, record.generation);
        }
        return;
      }
      if (selected == null) return;
      await _store!.bindEngine(id, record.generation, selected.engineTaskId);
      for (final duplicate in native) {
        if (duplicate.engineTaskId != selected.engineTaskId) {
          await _engine!.cancel(duplicate.engineTaskId);
        }
      }
      if (selected.state == DownloadEngineState.canceled) {
        await _applySnapshot(selected);
        return;
      }
      if (selected.resumeRequested && !record.resumeRequested) {
        if (await _store!.requestResume(id, record.generation)) {
          record = await _requiredRecord(id);
        }
      }
      if (record.resumeRequested) {
        if (selected.state == DownloadEngineState.complete) {
          await _applySnapshot(selected);
        }
        return;
      }
      if (selected.state == DownloadEngineState.queued ||
          selected.state == DownloadEngineState.running) {
        if (!await _engine!.pause(selected.engineTaskId)) {
          await _engine!.cancel(selected.engineTaskId);
        }
      }
      return;
    }
    if (record.state == DownloadState.failed) {
      if (native.isNotEmpty && record.engineTaskId == null) {
        await _store!.bindEngine(
          id,
          record.generation,
          native.first.engineTaskId,
        );
      }
      return;
    }
    if (record.state == DownloadState.verifying) {
      await _verifyAndCommit(
        record,
        _files!.staging(record.id, record.generation),
      );
      return;
    }

    DownloadEngineSnapshot? selected;
    if (record.engineTaskId != null) {
      for (final task in native) {
        if (task.engineTaskId == record.engineTaskId) {
          selected = task;
          break;
        }
      }
    }
    selected ??= native.isEmpty ? null : native.first;
    if (selected != null) {
      await _store!.bindEngine(id, record.generation, selected.engineTaskId);
      for (final duplicate in native) {
        if (duplicate.engineTaskId != selected.engineTaskId) {
          await _engine!.cancel(duplicate.engineTaskId);
        }
      }
      await _applySnapshot(selected);
      return;
    }

    if ((record.state == DownloadState.running ||
            (record.state == DownloadState.queued &&
                record.engineTaskId != null)) &&
        await _store!.restart(
          id,
          record.generation,
          record.state,
          reason: 'Native transfer was lost; restarted from the beginning',
        )) {
      await _files!.deleteStaging(id, record.generation);
    }
  }

  Future<void> _handleEngineUpdate(DownloadEngineUpdate update) async {
    await _runFor(update.businessId, () => _applySnapshot(update));
    await _drainCanceledGroups();
    if (_initialized) await _scheduleQueued();
  }

  bool _canApplyEngineUpdate(
    DownloadRecord record,
    DownloadEngineSnapshot update,
  ) =>
      record.generation == update.generation &&
      record.state != DownloadState.canceled &&
      record.state != DownloadState.completed;

  Future<void> _applySnapshot(DownloadEngineSnapshot update) async {
    var record = await _store!.get(update.businessId);

    if (record == null || record.generation != update.generation) {
      if (update.state != DownloadEngineState.complete &&
          update.state != DownloadEngineState.failed &&
          update.state != DownloadEngineState.canceled) {
        await _engine!.cancel(update.engineTaskId);
      }
      await _files!.deleteStaging(update.businessId, update.generation);
      return;
    }
    if (record.state == DownloadState.canceled ||
        record.state == DownloadState.completed) {
      return;
    }
    if (!await _store!.bindEngine(
      record.id,
      record.generation,
      update.engineTaskId,
    )) {
      await _engine!.cancel(update.engineTaskId);
      return;
    }
    await _store!.updateProgress(
      record.id,
      record.generation,
      update.bytesReceived,
      update.totalBytes,
    );
    record = await _requiredRecord(record.id);
    if (!_canApplyEngineUpdate(record, update)) return;
    if (update.resumeRequested && !record.resumeRequested) {
      if (update.state != DownloadEngineState.complete &&
          (record.state == DownloadState.queued ||
              record.state == DownloadState.running)) {
        await _store!.transition(
          record.id,
          record.generation,
          record.state,
          DownloadState.paused,
        );
        record = await _requiredRecord(record.id);
        if (!_canApplyEngineUpdate(record, update)) return;
      }
      if (record.state == DownloadState.paused &&
          await _store!.requestResume(record.id, record.generation)) {
        record = await _requiredRecord(record.id);
        if (!_canApplyEngineUpdate(record, update)) return;
      }
    }

    switch (update.state) {
      case DownloadEngineState.queued:
        if (record.state == DownloadState.queued) {
          await _store!.transition(
            record.id,
            record.generation,
            DownloadState.queued,
            DownloadState.running,
          );
        }
        break;
      case DownloadEngineState.running:
        if (record.state == DownloadState.queued) {
          await _store!.transition(
            record.id,
            record.generation,
            DownloadState.queued,
            DownloadState.running,
          );
        }
        break;
      case DownloadEngineState.paused:
        final newlyPaused = await _transitionFromEither(
          record,
          DownloadState.queued,
          DownloadState.running,
          DownloadState.paused,
        );
        if (newlyPaused && update.resumeRequested) {
          await _store!.requestResume(record.id, record.generation);
        }
        break;
      case DownloadEngineState.complete:
        final verifying =
            record.state == DownloadState.paused && record.resumeRequested
            ? await _store!.transition(
                record.id,
                record.generation,
                DownloadState.paused,
                DownloadState.verifying,
              )
            : record.state == DownloadState.paused
            ? false
            : await _transitionFromEither(
                record,
                DownloadState.queued,
                DownloadState.running,
                DownloadState.verifying,
              );
        if (verifying) {
          await _emit();
          await _verifyAndCommit(
            record,
            _files!.staging(record.id, record.generation),
          );
        }
        break;
      case DownloadEngineState.failed:
        final nativeError = _safeMessage(
          update.error ?? 'Native transfer failed',
          record.request,
        );
        if (nativeError.toLowerCase().contains('taskresumeexception') &&
            record.state == DownloadState.paused &&
            !record.resumeRequested) {
          await _store!.transition(
            record.id,
            record.generation,
            DownloadState.paused,
            DownloadState.paused,
            error:
                'Saved partial transfer was unavailable; resume will '
                'restart from the beginning',
          );
          await _files!.deleteStaging(record.id, record.generation);
          break;
        }
        if (nativeError.toLowerCase().contains('taskresumeexception') &&
            await _store!.restart(
              record.id,
              record.generation,
              record.state,
              reason:
                  'Saved partial transfer was unavailable; '
                  'restarted from the beginning',
            )) {
          await _files!.deleteStaging(record.id, record.generation);
          break;
        }
        if (record.effectiveStrategy == TransferStrategy.parallel &&
            _isParallelCapabilityFailure(nativeError) &&
            await _store!.fallBackToSingleConnection(
              record.id,
              record.generation,
              'Server cannot safely serve parallel Range requests; '
              'retrying with one connection',
            )) {
          await _files!.deleteStaging(record.id, record.generation);
          break;
        }
        await _transitionFromEither(
          record,
          DownloadState.queued,
          DownloadState.running,
          DownloadState.failed,
          error: nativeError,
        );
        break;
      case DownloadEngineState.canceled:
        if (record.state == DownloadState.queued ||
            record.state == DownloadState.running ||
            record.state == DownloadState.paused) {
          if (record.request.group.startsWith('comic:')) {
            final canceled = await _store!.cancelGroup(record.request.group);
            if (canceled.isNotEmpty) {
              _pendingCanceledGroups.add(record.request.group);
            }
          } else {
            final canceled = await _store!.cancel(record.id);
            if (canceled != null) {
              await _files!.deleteAllStaging(record.id);
              await _files!.deleteFinal(record.request.relativePath);
            }
          }
        }
        break;
    }
    await _emit();
  }

  Future<bool> _transitionFromEither(
    DownloadRecord record,
    DownloadState first,
    DownloadState second,
    DownloadState to, {
    String? error,
  }) async {
    if (record.state == first) {
      return _store!.transition(
        record.id,
        record.generation,
        first,
        to,
        error: error,
      );
    }
    if (record.state == second) {
      return _store!.transition(
        record.id,
        record.generation,
        second,
        to,
        error: error,
      );
    }
    return false;
  }

  Future<void> _drainCanceledGroups() {
    final scheduled = _groupCancellationTail.then(
      (_) => _drainCanceledGroupsPass(),
    );
    _groupCancellationTail = scheduled.then<void>(
      (_) {},
      onError: (Object _, StackTrace __) {},
    );
    return scheduled;
  }

  Future<void> _drainCanceledGroupsPass() async {
    while (_pendingCanceledGroups.isNotEmpty) {
      final groups = Set<String>.of(_pendingCanceledGroups);
      _pendingCanceledGroups.clear();
      for (final group in groups) {
        await _cancelBusinessGroup(group);
      }
    }
  }

  Future<void> _cancelBusinessGroup(String group) async {
    final newlyCanceled = await _store!.cancelGroup(group);
    final records = await _store!.list();
    for (final snapshot in records.where(
      (record) =>
          record.request.group == group &&
          record.state == DownloadState.canceled,
    )) {
      await _runFor(snapshot.id, () async {
        final current = await _store!.get(snapshot.id);
        if (current == null ||
            current.request.group != group ||
            current.state != DownloadState.canceled) {
          return;
        }
        if (current.engineTaskId != null) {
          try {
            await _engine!.cancel(current.engineTaskId!);
          } on Object {
            // The durable generation fence already prevents late native
            // callbacks from reviving this group member.
          }
        }
        await _files!.deleteAllStaging(current.id);
        await _files!.deleteFinal(current.request.relativePath);
      });
    }
    if (newlyCanceled.isNotEmpty) await _emit();
  }

  Future<void> _scheduleQueued() {
    if (_disposed) return Future<void>.value();
    final scheduled = Future.wait([_scheduleTail, _groupCancellationTail])
        .then((_) => _schedulePass());
    _scheduleTail = scheduled.then<void>(
      (_) {},
      onError: (Object _, StackTrace __) {},
    );
    return scheduled;
  }

  Future<void> _schedulePass() async {
    final records = await _store!.list();
    final active = records
        .where(
          (record) =>
              record.state == DownloadState.running &&
              record.engineTaskId != null,
        )
        .toList(growable: false);
    if (active.any(
      (record) => record.effectiveStrategy == TransferStrategy.parallel,
    )) {
      return;
    }
    var activeConnections = active.length;
    final activeByHost = <String, int>{};
    for (final record in active) {
      final host = record.request.url.host.toLowerCase();
      activeByHost[host] = (activeByHost[host] ?? 0) + 1;
    }

    final queued = records
        .where(
          (record) =>
              (record.state == DownloadState.queued &&
                  record.engineTaskId == null) ||
              (record.state == DownloadState.paused &&
                  record.resumeRequested &&
                  record.engineTaskId != null),
        )
        .toList(growable: false)
        .reversed;
    for (final candidate in queued) {
      if (candidate.effectiveStrategy == TransferStrategy.parallel) {
        // A parallel parent and its chunk children are all counted as native
        // work. Run it exclusively so parent workers cannot consume the slots
        // required by their own chunks.
        if (activeConnections != 0) return;
        await _runFor(candidate.id, () => _startScheduled(candidate));
        final after = await _store!.get(candidate.id);
        if (after?.state == DownloadState.running) return;
        continue;
      }
      if (activeConnections >= _maxConnections) return;
      final host = candidate.request.url.host.toLowerCase();
      final hostConnections = activeByHost[host] ?? 0;
      if (hostConnections >= _maxConnectionsPerHost) continue;
      await _runFor(candidate.id, () => _startScheduled(candidate));
      final after = await _store!.get(candidate.id);
      if (after?.state == DownloadState.running) {
        activeConnections++;
        activeByHost[host] = hostConnections + 1;
      }
    }
  }

  Future<void> _startScheduled(DownloadRecord candidate) async {
    try {
      if (candidate.state == DownloadState.paused &&
          candidate.resumeRequested) {
        await _resumeScheduled(candidate);
      } else {
        await _startQueued(candidate);
      }
    } on ParallelDownloadCapabilityException catch (error) {
      final current = await _store!.get(candidate.id);
      if (current != null &&
          current.effectiveStrategy == TransferStrategy.parallel &&
          await _store!.fallBackToSingleConnection(
            current.id,
            current.generation,
            _safeError(error, current.request),
          )) {
        await _files!.deleteStaging(current.id, current.generation);
        await _emit();
        final fallback = await _requiredRecord(current.id);
        await _startScheduled(fallback);
        return;
      }
      if (current != null && current.state == DownloadState.queued) {
        await _store!.transition(
          current.id,
          current.generation,
          DownloadState.queued,
          DownloadState.failed,
          error: _safeError(error, current.request),
        );
        await _emit();
      }
    } on Object catch (error) {
      final current = await _store!.get(candidate.id);
      if (current != null && current.state == DownloadState.queued) {
        await _store!.transition(
          current.id,
          current.generation,
          DownloadState.queued,
          DownloadState.failed,
          error: _safeError(error, current.request),
        );
        await _emit();
      }
    }
  }

  Future<void> _resumeScheduled(DownloadRecord candidate) async {
    var current = await _store!.get(candidate.id);
    if (current == null ||
        current.generation != candidate.generation ||
        current.state != DownloadState.paused ||
        !current.resumeRequested ||
        current.engineTaskId == null) {
      return;
    }
    var resumed = false;
    try {
      resumed = await _engine!.resume(current.engineTaskId!);
    } on Object {
      resumed = false;
    }
    if (resumed) {
      if (!await _store!.transition(
        current.id,
        current.generation,
        DownloadState.paused,
        DownloadState.running,
      )) {
        throw StateError('Download ${current.id} changed while resuming');
      }
      await _emit();
      return;
    }
    try {
      await _engine!.cancel(current.engineTaskId!);
    } on Object {
      // The native transfer is already unusable; the generation fence below
      // prevents any delayed update from reviving it.
    }
    if (!await _store!.restart(
      current.id,
      current.generation,
      DownloadState.paused,
      reason: 'Partial transfer unavailable; restarted from the beginning',
    )) {
      throw StateError('Download ${current.id} changed while restarting');
    }
    await _files!.deleteStaging(current.id, current.generation);
    current = await _requiredRecord(current.id);
    await _emit();
    await _startQueued(current);
  }

  Future<List<DownloadRecord>> list() async {
    await initialize();
    return UnmodifiableListView(await _store!.list());
  }

  Future<DownloadRecord?> get(String id) async {
    await initialize();
    return _store!.get(id);
  }

  Stream<List<DownloadRecord>> watch() async* {
    await initialize();
    yield UnmodifiableListView(await _store!.list());
    yield* _changes.stream;
  }

  Future<File?> completedFile(String id) async {
    await initialize();
    return _runFor(id, () async {
      final record = await _store!.get(id);
      if (record == null || record.state != DownloadState.completed)
        return null;
      return _completedFileInternal(record);
    });
  }

  Future<File?> _completedFileInternal(DownloadRecord record) async {
    final file = _files!.resolve(record.request.relativePath);
    try {
      await _files!.verify(file, _integrityFor(record));
      return file;
    } on Object catch (error) {
      await _store!.invalidate(record.id, _safeError(error, record.request));
      await _emit();
      return null;
    }
  }

  Future<DownloadRecord> _requiredRecord(String id) async =>
      await _store!.get(id) ?? (throw StateError('Unknown download $id'));

  Future<void> _emit() async {
    if (_disposed || _changes.isClosed || _store == null) return;
    final records = UnmodifiableListView(await _store!.list());
    if (_disposed || _changes.isClosed) return;
    _changes.add(records);
  }

  Future<T> _runFor<T>(String id, Future<T> Function() action) {
    final predecessor = _taskOperations[id] ?? Future<void>.value();
    final result = Completer<T>();
    late Future<void> chain;
    chain = predecessor
        .then((_) async {
          try {
            result.complete(await action());
          } on Object catch (error, stackTrace) {
            result.completeError(error, stackTrace);
          }
        })
        .whenComplete(() {
          if (identical(_taskOperations[id], chain)) {
            _taskOperations.remove(id);
          }
        });
    _taskOperations[id] = chain;
    return result.future;
  }

  bool _isParallelCapabilityFailure(String error) {
    final normalized = error.toLowerCase();
    return normalized.contains('accept ranges') ||
        normalized.contains('accept-ranges') ||
        normalized.contains('content length') ||
        normalized.contains('content-range') ||
        normalized.contains('range request');
  }

  DownloadIntegrity _integrityFor(DownloadRecord record) {
    final requested = record.request.integrity;
    final nativeLength = record.totalBytes;
    if (requested.expectedBytes != null || nativeLength == null) {
      return requested;
    }
    return DownloadIntegrity(
      expectedBytes: nativeLength,
      sha256Hex: requested.sha256Hex,
    );
  }

  String _safeError(Object error, DownloadRequest request) =>
      _safeMessage(error.toString(), request);

  String _safeMessage(String message, DownloadRequest request) {
    var safe = message.replaceAll(request.url.toString(), '<url>');
    for (final value in request.headers.values) {
      if (value.isNotEmpty) safe = safe.replaceAll(value, '<redacted>');
    }
    return safe.length <= 500 ? safe : safe.substring(0, 500);
  }

  void _ensureNotDisposed() {
    if (_disposed) throw StateError('DownloadService is disposed');
  }

  Future<void> dispose() => _disposeFuture ??= _dispose();

  Future<void> _dispose() async {
    _disposed = true;
    final pendingInitialization = _initializeFuture;
    if (pendingInitialization != null) {
      try {
        await pendingInitialization;
      } on Object {
        // Initialization observes _disposed at every resource boundary and
        // exits; disposal still owns cleanup of anything created beforehand.
      }
    }
    await _engineSubscription?.cancel();
    _engineSubscription = null;
    await _groupCancellationTail;
    await _scheduleTail;
    while (_taskOperations.isNotEmpty) {
      await Future.wait(_taskOperations.values.toList(growable: false));
    }
    if (_engine != null) await _engine!.dispose();
    if (!_changes.isClosed) await _changes.close();
    _initialized = false;
    _initializeFuture = null;
  }
}
