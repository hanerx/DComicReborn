import 'dart:async';
import 'dart:io';

import 'package:dcomic/downloads/download_cache.dart';
import 'package:dcomic/downloads/download_engine.dart';
import 'package:dcomic/downloads/download_models.dart';
import 'package:dcomic/downloads/download_store.dart';

DownloadRequest sampleDownloadRequest({
  String id = 'sample',
  String relativePath = 'files/sample.bin',
  DownloadIntegrity integrity = const DownloadIntegrity(),
  TransferStrategy strategy = TransferStrategy.single,
  int chunks = 1,
  String? cacheKey,
}) => DownloadRequest(
  id: id,
  url: Uri.parse('http://127.0.0.1/file'),
  headers: const {'Referer': 'http://127.0.0.1/'},
  relativePath: relativePath,
  group: 'files',
  integrity: integrity,
  strategy: strategy,
  chunks: chunks,
  cacheKey: cacheKey,
  displayName: 'Sample file',
);

class MemoryDownloadStore implements DownloadStore {
  final Map<String, DownloadRecord> records = {};
  final Map<String, int> nextGenerations = {};
  Future<void> Function(String id)? afterProgressUpdate;

  @override
  Future<void> insert(DownloadRequest request) async {
    if (records.containsKey(request.id)) {
      throw StateError('duplicate download id');
    }
    final canonical = canonicalRelativeDownloadPath(request.relativePath);
    if (records.values.any(
      (record) =>
          canonicalRelativeDownloadPath(record.request.relativePath) ==
          canonical,
    )) {
      throw StateError('duplicate download destination');
    }
    final generation = nextGenerations[request.id] ?? 0;
    nextGenerations[request.id] = generation + 1;
    records[request.id] = DownloadRecord(
      request: request,
      state: DownloadState.queued,
      generation: generation,
      bytesReceived: 0,
      createdAt: DateTime.now().toUtc(),
    );
  }

  @override
  Future<DownloadRecord?> get(String id) async => records[id];

  @override
  Future<List<DownloadRecord>> list() async {
    final result = records.values.toList();
    result.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return result;
  }

  @override
  Future<bool> transition(
    String id,
    int generation,
    DownloadState from,
    DownloadState to, {
    String? error,
    DateTime? completedAt,
  }) async {
    final current = records[id];
    if (current == null ||
        current.generation != generation ||
        current.state != from) {
      return false;
    }
    records[id] = current.copyWith(
      state: to,
      resumeRequested: false,
      error: error,
      clearError: error == null,
      completedAt: completedAt,
      clearCompletedAt: completedAt == null,
    );
    return true;
  }

  @override
  Future<bool> bindEngine(
    String id,
    int generation,
    String engineTaskId,
  ) async {
    final current = records[id];
    if (current == null || current.generation != generation) return false;
    final existing = current.engineTaskId;
    if (existing != null && existing != engineTaskId) return false;
    records[id] = current.copyWith(engineTaskId: engineTaskId);
    return true;
  }

  @override
  Future<bool> updateProgress(
    String id,
    int generation,
    int bytesReceived,
    int? totalBytes,
  ) async {
    final current = records[id];
    if (current == null ||
        current.generation != generation ||
        current.state == DownloadState.canceled ||
        current.state == DownloadState.completed) {
      return false;
    }
    records[id] = current.copyWith(
      bytesReceived: bytesReceived > current.bytesReceived
          ? bytesReceived
          : current.bytesReceived,
      totalBytes: totalBytes ?? current.totalBytes,
    );
    await afterProgressUpdate?.call(id);
    return true;
  }

  @override
  Future<bool> requestResume(String id, int generation) async {
    final current = records[id];
    if (current == null ||
        current.generation != generation ||
        current.state != DownloadState.paused) {
      return false;
    }
    records[id] = current.copyWith(
      resumeRequested: true,
      clearError: true,
    );
    return true;
  }

  @override
  Future<DownloadRecord?> cancel(String id) async {
    final current = records[id];
    if (current == null || current.state == DownloadState.canceled) {
      return current;
    }
    final canceled = current.copyWith(
      state: DownloadState.canceled,
      generation: current.generation + 1,
      resumeRequested: false,
      clearError: true,
      clearCompletedAt: true,
    );
    records[id] = canceled;
    nextGenerations[id] = canceled.generation + 1;
    return canceled;
  }

  @override
  Future<List<DownloadRecord>> cancelGroup(String group) async {
    final canceled = <DownloadRecord>[];
    for (final entry in records.entries.toList(growable: false)) {
      final current = entry.value;
      if (current.request.group != group ||
          (current.state != DownloadState.queued &&
              current.state != DownloadState.running &&
              current.state != DownloadState.paused)) {
        continue;
      }
      final next = current.copyWith(
        state: DownloadState.canceled,
        generation: current.generation + 1,
        resumeRequested: false,
        clearError: true,
        clearCompletedAt: true,
      );
      records[entry.key] = next;
      nextGenerations[entry.key] = next.generation + 1;
      canceled.add(next);
    }
    return canceled;
  }

  @override
  Future<bool> restart(
    String id,
    int generation,
    DownloadState from, {
    String? reason,
  }) async {
    final current = records[id];
    if (current == null ||
        current.generation != generation ||
        current.state != from) {
      return false;
    }
    records[id] = current.copyWith(
      state: DownloadState.queued,
      generation: generation + 1,
      clearEngineTaskId: true,
      resumeRequested: false,
      bytesReceived: 0,
      clearTotalBytes: true,
      error: reason,
      clearError: reason == null,
      clearCompletedAt: true,
    );
    nextGenerations[id] = generation + 2;
    return true;
  }

  @override
  Future<bool> fallBackToSingleConnection(
    String id,
    int generation,
    String reason,
  ) async {
    final current = records[id];
    if (current == null ||
        current.generation != generation ||
        current.effectiveStrategy != TransferStrategy.parallel ||
        (current.state != DownloadState.queued &&
            current.state != DownloadState.running &&
            current.state != DownloadState.verifying)) {
      return false;
    }
    records[id] = current.copyWith(
      effectiveStrategy: TransferStrategy.single,
      state: DownloadState.queued,
      generation: generation + 1,
      clearEngineTaskId: true,
      resumeRequested: false,
      bytesReceived: 0,
      clearTotalBytes: true,
      error: reason,
      clearCompletedAt: true,
    );
    nextGenerations[id] = generation + 2;
    return true;
  }

  @override
  Future<void> invalidate(String id, String reason) async {
    final current = records[id];
    if (current == null) return;
    records[id] = current.copyWith(
      state: DownloadState.failed,
      error: reason,
      resumeRequested: false,
      clearCompletedAt: true,
    );
  }

  @override
  Future<bool> delete(String id, int generation) async {
    final current = records[id];
    if (current == null || current.generation != generation) return false;
    records.remove(id);
    return true;
  }
}

class FakeDownloadEngine extends DownloadEngine {
  final StreamController<DownloadEngineUpdate> controller =
      StreamController<DownloadEngineUpdate>.broadcast();
  final Map<String, DownloadEngineSnapshot> nativeTasks = {};
  int enqueueCount = 0;
  final List<DownloadRequest> enqueuedRequests = [];
  int pauseCount = 0;
  int resumeCount = 0;
  int disposeCount = 0;
  bool pauseResult = true;
  bool resumeResult = true;
  bool cancelResult = true;
  Future<void> Function(DownloadRequest request)? beforeEnqueue;

  @override
  Stream<DownloadEngineUpdate> get updates => controller.stream;

  @override
  Future<void> initialize() async {}

  @override
  Future<String> enqueue(
    DownloadRequest request,
    String stagingPath,
    int generation,
  ) async {
    await beforeEnqueue?.call(request);
    enqueuedRequests.add(request);
    enqueueCount++;
    final engineId = 'engine-${request.id}-$generation';
    nativeTasks[engineId] = DownloadEngineSnapshot(
      businessId: request.id,
      generation: generation,
      engineTaskId: engineId,
      state: DownloadEngineState.queued,
      bytesReceived: 0,
      stagingPath: stagingPath,
    );
    return engineId;
  }

  @override
  Future<bool> pause(String engineTaskId) async {
    pauseCount++;
    return pauseResult;
  }

  @override
  Future<bool> resume(String engineTaskId) async {
    resumeCount++;
    return resumeResult;
  }

  @override
  Future<bool> cancel(String engineTaskId) async {
    if (cancelResult) nativeTasks.remove(engineTaskId);
    return cancelResult;
  }

  @override
  Future<List<DownloadEngineSnapshot>> snapshot() async =>
      nativeTasks.values.toList(growable: false);

  void emit(DownloadEngineUpdate update) {
    nativeTasks[update.engineTaskId] = update.snapshot;
    controller.add(update);
  }

  @override
  Future<void> dispose() async {
    disposeCount++;
    await controller.close();
  }
}

class FakeDownloadCache implements DownloadCache {
  bool hit = false;
  List<int> bytes = const [];

  @override
  Future<bool> copyValid(DownloadRequest request, File staging) async {
    if (!hit) return false;
    await staging.parent.create(recursive: true);
    await staging.writeAsBytes(bytes, flush: true);
    return true;
  }
}
