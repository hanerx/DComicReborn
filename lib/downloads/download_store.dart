import 'dart:convert';

import 'package:dcomic/database/entity/download_task.dart';
import 'package:dcomic/downloads/download_models.dart';

class DownloadStore {
  final DownloadTaskDao _dao;
  final DateTime Function() _now;

  DownloadStore(this._dao, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  Future<void> insert(DownloadRequest request) => _dao.insertFreshDownloadTask(
    DownloadTaskEntity(
      id: request.id,
      url: request.url.toString(),
      headersJson: jsonEncode(request.headers),
      relativePath: request.relativePath,
      canonicalPath: canonicalRelativeDownloadPath(request.relativePath),
      taskGroup: request.group,
      expectedBytes: request.integrity.expectedBytes,
      sha256Hex: request.integrity.normalizedSha256,
      effectiveStrategy: request.strategy.name,
      strategy: request.strategy.name,
      chunks: request.chunks,
      cacheKey: request.cacheKey,
      displayName: request.displayName,
      state: DownloadState.queued.name,
      generation: 0,
      resumeRequested: false,
      bytesReceived: 0,
      createdAt: _now().toUtc().millisecondsSinceEpoch,
    ),
  );

  Future<DownloadRecord?> get(String id) async {
    final entity = await _dao.findDownloadTask(id);
    return entity == null ? null : _toRecord(entity);
  }

  Future<List<DownloadRecord>> list() async =>
      (await _dao.listDownloadTasks()).map(_toRecord).toList(growable: false);

  Future<bool> transition(
    String id,
    int generation,
    DownloadState from,
    DownloadState to, {
    String? error,
    DateTime? completedAt,
  }) => _dao.transitionDownloadTask(
    id,
    generation,
    from.name,
    to.name,
    error,
    completedAt?.toUtc().millisecondsSinceEpoch,
  );

  Future<bool> bindEngine(String id, int generation, String engineTaskId) =>
      _dao.bindDownloadEngine(id, generation, engineTaskId);

  Future<bool> updateProgress(
    String id,
    int generation,
    int bytesReceived,
    int? totalBytes,
  ) => _dao.updateDownloadProgress(id, generation, bytesReceived, totalBytes);

  Future<bool> requestResume(String id, int generation) =>
      _dao.requestDownloadResume(id, generation);

  Future<DownloadRecord?> cancel(String id) async =>
      _toRecord(await _dao.cancelDownloadTask(id));

  Future<List<DownloadRecord>> cancelGroup(String group) async =>
      (await _dao.cancelDownloadGroup(group))
          .map(_toRecord)
          .toList(growable: false);

  Future<bool> restart(
    String id,
    int generation,
    DownloadState from, {
    String? reason,
  }) => _dao.restartDownloadTask(id, generation, from.name, reason);

  Future<bool> fallBackToSingleConnection(
    String id,
    int generation,
    String reason,
  ) => _dao.fallBackToSingleConnection(id, generation, reason);

  Future<void> invalidate(String id, String reason) =>
      _dao.invalidateDownloadTask(id, reason);

  Future<bool> delete(String id, int generation) =>
      _dao.deleteDownloadTaskIfGeneration(id, generation);

  DownloadRecord _toRecord(DownloadTaskEntity entity) {
    final decodedHeaders = jsonDecode(entity.headersJson);
    if (decodedHeaders is! Map) {
      throw StateError('Invalid persisted headers for download ${entity.id}');
    }
    final headers = <String, String>{};
    for (final entry in decodedHeaders.entries) {
      if (entry.key is! String || entry.value is! String) {
        throw StateError('Invalid persisted headers for download ${entity.id}');
      }
      headers[entry.key as String] = entry.value as String;
    }
    return DownloadRecord(
      request: DownloadRequest(
        id: entity.id,
        url: Uri.parse(entity.url),
        headers: headers,
        relativePath: entity.relativePath,
        group: entity.taskGroup,
        integrity: DownloadIntegrity(
          expectedBytes: entity.expectedBytes,
          sha256Hex: entity.sha256Hex,
        ),
        strategy: TransferStrategy.values.byName(entity.strategy),
        chunks: entity.chunks,
        cacheKey: entity.cacheKey,
        displayName: entity.displayName,
      ),
      state: DownloadState.values.byName(entity.state),
      effectiveStrategy: TransferStrategy.values.byName(
        entity.effectiveStrategy,
      ),
      generation: entity.generation,
      engineTaskId: entity.engineTaskId,
      resumeRequested: entity.resumeRequested,
      bytesReceived: entity.bytesReceived,
      totalBytes: entity.totalBytes,
      error: entity.error,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        entity.createdAt,
        isUtc: true,
      ),
      completedAt: entity.completedAt == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(
              entity.completedAt!,
              isUtc: true,
            ),
    );
  }
}
