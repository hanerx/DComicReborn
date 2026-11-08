import 'package:floor_community/floor.dart';

@Entity(
  primaryKeys: ['id'],
  indices: [
    Index(value: ['state']),
    Index(value: ['engineTaskId'], unique: true),
    Index(value: ['canonicalPath'], unique: true),
  ],
)
class DownloadTaskEntity {
  final String id;
  final String url;
  final String headersJson;
  final String relativePath;
  final String canonicalPath;
  final String taskGroup;
  final int? expectedBytes;
  final String? sha256Hex;
  final String strategy;
  final String effectiveStrategy;
  final int chunks;
  final String? cacheKey;
  final String? displayName;
  final String state;
  final int generation;
  final String? engineTaskId;
  final bool resumeRequested;
  final int bytesReceived;
  final int? totalBytes;
  final String? error;
  final int createdAt;
  final int? completedAt;

  const DownloadTaskEntity({
    required this.id,
    required this.url,
    required this.headersJson,
    required this.relativePath,
    required this.canonicalPath,
    required this.taskGroup,
    this.expectedBytes,
    this.sha256Hex,
    required this.strategy,
    required this.effectiveStrategy,
    required this.chunks,
    this.cacheKey,
    this.displayName,
    required this.state,
    required this.generation,
    this.engineTaskId,
    required this.resumeRequested,
    required this.bytesReceived,
    this.totalBytes,
    this.error,
    required this.createdAt,
    this.completedAt,
  });

  DownloadTaskEntity copyWith({
    String? effectiveStrategy,
    String? state,
    int? generation,
    String? engineTaskId,
    bool? resumeRequested,
    bool clearEngineTaskId = false,
    int? bytesReceived,
    int? totalBytes,
    bool clearTotalBytes = false,
    String? error,
    bool clearError = false,
    int? completedAt,
    bool clearCompletedAt = false,
  }) => DownloadTaskEntity(
    id: id,
    url: url,
    headersJson: headersJson,
    relativePath: relativePath,
    canonicalPath: canonicalPath,
    taskGroup: taskGroup,
    expectedBytes: expectedBytes,
    sha256Hex: sha256Hex,
    strategy: strategy,
    effectiveStrategy: effectiveStrategy ?? this.effectiveStrategy,
    chunks: chunks,
    cacheKey: cacheKey,
    displayName: displayName,
    state: state ?? this.state,
    generation: generation ?? this.generation,
    engineTaskId: clearEngineTaskId ? null : engineTaskId ?? this.engineTaskId,
    resumeRequested: resumeRequested ?? this.resumeRequested,
    bytesReceived: bytesReceived ?? this.bytesReceived,
    totalBytes: clearTotalBytes ? null : totalBytes ?? this.totalBytes,
    error: clearError ? null : error ?? this.error,
    createdAt: createdAt,
    completedAt: clearCompletedAt ? null : completedAt ?? this.completedAt,
  );
}

@Entity(primaryKeys: ['id'])
class DownloadTaskEpochEntity {
  final String id;
  final int nextGeneration;

  const DownloadTaskEpochEntity(this.id, this.nextGeneration);
}

@dao
abstract class DownloadTaskDao {
  @Query('SELECT * FROM DownloadTaskEntity WHERE id = :id')
  Future<DownloadTaskEntity?> findDownloadTask(String id);
  @Query(
    'SELECT * FROM DownloadTaskEntity WHERE canonicalPath = :canonicalPath',
  )
  Future<DownloadTaskEntity?> findDownloadTaskByCanonicalPath(
    String canonicalPath,
  );

  @Query('SELECT * FROM DownloadTaskEpochEntity WHERE id = :id')
  Future<DownloadTaskEpochEntity?> findDownloadTaskEpoch(String id);

  @Query('SELECT * FROM DownloadTaskEntity ORDER BY createdAt DESC, id ASC')
  Future<List<DownloadTaskEntity>> listDownloadTasks();

  @Insert(onConflict: OnConflictStrategy.abort)
  Future<void> insertDownloadTaskRow(DownloadTaskEntity entity);

  @Insert(onConflict: OnConflictStrategy.replace)
  Future<void> upsertDownloadTaskEpoch(DownloadTaskEpochEntity entity);

  @Update(onConflict: OnConflictStrategy.abort)
  Future<int> updateDownloadTask(DownloadTaskEntity entity);

  @delete
  Future<int> deleteDownloadTask(DownloadTaskEntity entity);

  @transaction
  Future<void> insertFreshDownloadTask(DownloadTaskEntity entity) async {
    if (await findDownloadTask(entity.id) != null) {
      throw StateError('Download ${entity.id} already exists');
    }
    final owner = await findDownloadTaskByCanonicalPath(entity.canonicalPath);
    if (owner != null) {
      throw StateError(
        'Download destination ${entity.relativePath} is already owned by '
        '${owner.id}',
      );
    }
    final epoch = await findDownloadTaskEpoch(entity.id);
    final generation = epoch?.nextGeneration ?? 0;
    await insertDownloadTaskRow(
      entity.copyWith(generation: generation, resumeRequested: false),
    );
    await upsertDownloadTaskEpoch(
      DownloadTaskEpochEntity(entity.id, generation + 1),
    );
  }

  Future<void> _reserveDownloadTaskGeneration(String id, int generation) async {
    final epoch = await findDownloadTaskEpoch(id);
    if (epoch == null || epoch.nextGeneration <= generation) {
      await upsertDownloadTaskEpoch(
        DownloadTaskEpochEntity(id, generation + 1),
      );
    }
  }

  @transaction
  Future<bool> transitionDownloadTask(
    String id,
    int generation,
    String fromState,
    String toState,
    String? error,
    int? completedAt,
  ) async {
    final current = await findDownloadTask(id);
    if (current == null ||
        current.generation != generation ||
        current.state != fromState) {
      return false;
    }
    return await updateDownloadTask(
          current.copyWith(
            state: toState,
            error: error,
            resumeRequested: false,
            clearError: error == null,
            completedAt: completedAt,
            clearCompletedAt: completedAt == null,
          ),
        ) ==
        1;
  }

  @transaction
  Future<bool> bindDownloadEngine(
    String id,
    int generation,
    String engineTaskId,
  ) async {
    final current = await findDownloadTask(id);
    if (current == null || current.generation != generation) return false;
    if (current.engineTaskId != null && current.engineTaskId != engineTaskId) {
      return false;
    }
    if (current.engineTaskId == engineTaskId) return true;
    return await updateDownloadTask(
          current.copyWith(engineTaskId: engineTaskId),
        ) ==
        1;
  }

  @transaction
  Future<bool> updateDownloadProgress(
    String id,
    int generation,
    int bytesReceived,
    int? totalBytes,
  ) async {
    final current = await findDownloadTask(id);
    if (current == null ||
        current.generation != generation ||
        current.state == 'canceled' ||
        current.state == 'completed') {
      return false;
    }
    final nextBytes = bytesReceived > current.bytesReceived
        ? bytesReceived
        : current.bytesReceived;
    final nextTotal = totalBytes != null && totalBytes >= 0
        ? totalBytes
        : current.totalBytes;
    if (nextBytes == current.bytesReceived && nextTotal == current.totalBytes) {
      return true;
    }
    return await updateDownloadTask(
          current.copyWith(bytesReceived: nextBytes, totalBytes: nextTotal),
        ) ==
        1;
  }

  @transaction
  Future<bool> requestDownloadResume(String id, int generation) async {
    final current = await findDownloadTask(id);
    if (current == null ||
        current.generation != generation ||
        current.state != 'paused') {
      return false;
    }
    if (current.resumeRequested) return true;
    return await updateDownloadTask(
          current.copyWith(resumeRequested: true, clearError: true),
        ) ==
        1;
  }

  @transaction
  Future<DownloadTaskEntity> cancelDownloadTask(String id) async {
    final current = await findDownloadTask(id);
    if (current == null) {
      throw StateError('Unknown download $id');
    }
    if (current.state == 'canceled') return current;
    final canceled = current.copyWith(
      state: 'canceled',
      generation: current.generation + 1,
      resumeRequested: false,
      clearError: true,
      clearCompletedAt: true,
    );
    if (await updateDownloadTask(canceled) != 1) {
      throw StateError('Download $id changed while canceling');
    }
    await _reserveDownloadTaskGeneration(id, canceled.generation);
    return canceled;
  }

  @transaction
  Future<List<DownloadTaskEntity>> cancelDownloadGroup(String taskGroup) async {
    final candidates = (await listDownloadTasks())
        .where(
          (task) =>
              task.taskGroup == taskGroup &&
              (task.state == 'queued' ||
                  task.state == 'running' ||
                  task.state == 'paused'),
        )
        .toList(growable: false);
    final canceled = <DownloadTaskEntity>[];
    for (final current in candidates) {
      final next = current.copyWith(
        state: 'canceled',
        generation: current.generation + 1,
        resumeRequested: false,
        clearError: true,
        clearCompletedAt: true,
      );
      if (await updateDownloadTask(next) != 1) {
        throw StateError(
          'Download ${current.id} changed while canceling group $taskGroup',
        );
      }
      await _reserveDownloadTaskGeneration(current.id, next.generation);
      canceled.add(next);
    }
    return canceled;
  }

  @transaction
  Future<bool> restartDownloadTask(
    String id,
    int generation,
    String fromState,
    String? reason,
  ) async {
    final current = await findDownloadTask(id);
    if (current == null ||
        current.generation != generation ||
        current.state != fromState) {
      return false;
    }
    final restarted = current.copyWith(
      state: 'queued',
      generation: generation + 1,
      clearEngineTaskId: true,
      resumeRequested: false,
      bytesReceived: 0,
      clearTotalBytes: true,
      error: reason,
      clearError: reason == null,
      clearCompletedAt: true,
    );
    if (await updateDownloadTask(restarted) != 1) return false;
    await _reserveDownloadTaskGeneration(id, restarted.generation);
    return true;
  }

  @transaction
  Future<bool> fallBackToSingleConnection(
    String id,
    int generation,
    String reason,
  ) async {
    final current = await findDownloadTask(id);
    if (current == null ||
        current.generation != generation ||
        current.effectiveStrategy != 'parallel' ||
        (current.state != 'queued' &&
            current.state != 'running' &&
            current.state != 'verifying')) {
      return false;
    }
    final fallback = current.copyWith(
      effectiveStrategy: 'single',
      state: 'queued',
      generation: generation + 1,
      clearEngineTaskId: true,
      resumeRequested: false,
      bytesReceived: 0,
      clearTotalBytes: true,
      error: reason,
      clearCompletedAt: true,
    );
    if (await updateDownloadTask(fallback) != 1) return false;
    await _reserveDownloadTaskGeneration(id, fallback.generation);
    return true;
  }

  @transaction
  Future<void> invalidateDownloadTask(String id, String reason) async {
    final current = await findDownloadTask(id);
    if (current == null) return;
    await updateDownloadTask(
      current.copyWith(
        state: 'failed',
        error: reason,
        clearCompletedAt: true,
        resumeRequested: false,
      ),
    );
  }

  @transaction
  Future<bool> deleteDownloadTaskIfGeneration(String id, int generation) async {
    final current = await findDownloadTask(id);
    if (current == null || current.generation != generation) return false;
    return await deleteDownloadTask(current) == 1;
  }
}
