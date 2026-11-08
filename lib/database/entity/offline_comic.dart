import 'package:floor_community/floor.dart';

@Entity(primaryKeys: ['sourceId', 'comicId'])
class OfflineComicEntity {
  final String sourceId;
  final String comicId;
  final String rawTitle;
  final String catalogJson;
  final String? coverRelativePath;
  final String? remoteCoverUrl;
  final bool isLongComic;

  const OfflineComicEntity(
    this.sourceId,
    this.comicId,
    this.rawTitle,
    this.catalogJson,
    this.coverRelativePath,
    this.remoteCoverUrl,
    this.isLongComic,
  );
}

@Entity(
  primaryKeys: ['sourceId', 'comicId', 'chapterId'],
  indices: [
    Index(value: ['state', 'completedAt']),
  ],
  foreignKeys: [
    ForeignKey(
      childColumns: ['sourceId', 'comicId'],
      parentColumns: ['sourceId', 'comicId'],
      entity: OfflineComicEntity,
      onDelete: ForeignKeyAction.cascade,
    ),
  ],
)
class OfflineChapterEntity {
  final String sourceId;
  final String comicId;
  final String chapterId;
  final String rawTitle;
  final String groupName;
  final int sortIndex;
  final int manifestGeneration;
  final int operationGeneration;
  final String manifestSignature;
  final String state;
  final String? error;
  final DateTime? completedAt;

  const OfflineChapterEntity(
    this.sourceId,
    this.comicId,
    this.chapterId,
    this.rawTitle,
    this.groupName,
    this.sortIndex,
    this.manifestGeneration,
    this.operationGeneration,
    this.manifestSignature,
    this.state,
    this.error,
    this.completedAt,
  );
}

@Entity(
  primaryKeys: [
    'sourceId',
    'comicId',
    'chapterId',
    'manifestGeneration',
    'pageIndex',
  ],
  indices: [
    Index(value: ['taskId'], unique: true),
    Index(
      value: [
        'sourceId',
        'comicId',
        'chapterId',
        'manifestGeneration',
      ],
    ),
  ],
  foreignKeys: [
    ForeignKey(
      childColumns: ['sourceId', 'comicId', 'chapterId'],
      parentColumns: ['sourceId', 'comicId', 'chapterId'],
      entity: OfflineChapterEntity,
      onDelete: ForeignKeyAction.cascade,
    ),
  ],
)
class OfflinePageEntity {
  final String sourceId;
  final String comicId;
  final String chapterId;
  final int manifestGeneration;
  final int pageIndex;
  final String taskId;
  final String relativePath;
  final String resourceUrl;
  final String headersJson;
  final String? cacheKey;
  final int? expectedBytes;
  final bool submitted;

  const OfflinePageEntity(
    this.sourceId,
    this.comicId,
    this.chapterId,
    this.manifestGeneration,
    this.pageIndex,
    this.taskId,
    this.relativePath,
    this.resourceUrl,
    this.headersJson,
    this.cacheKey,
    this.expectedBytes,
    this.submitted,
  );
}

@dao
abstract class OfflineComicDao {
  @Insert(onConflict: OnConflictStrategy.ignore)
  Future<void> insertComic(OfflineComicEntity comic);

  @Update(onConflict: OnConflictStrategy.abort)
  Future<void> updateComic(OfflineComicEntity comic);

  Future<void> saveComic(OfflineComicEntity comic) async {
    await insertComic(comic);
    await updateComic(comic);
  }

  @Insert(onConflict: OnConflictStrategy.replace)
  Future<void> upsertChapter(OfflineChapterEntity chapter);

  @Insert(onConflict: OnConflictStrategy.replace)
  Future<void> upsertPages(List<OfflinePageEntity> pages);

  @Query(
    'SELECT * FROM OfflineComicEntity '
    'WHERE sourceId = :sourceId AND comicId = :comicId',
  )
  Future<OfflineComicEntity?> getComic(String sourceId, String comicId);

  @Query('SELECT * FROM OfflineComicEntity ORDER BY rawTitle, sourceId, comicId')
  Future<List<OfflineComicEntity>> getAllComics();

  @Query(
    'SELECT * FROM OfflineChapterEntity '
    'WHERE sourceId = :sourceId AND comicId = :comicId AND chapterId = :chapterId',
  )
  Future<OfflineChapterEntity?> getChapter(
    String sourceId,
    String comicId,
    String chapterId,
  );

  @Query(
    'SELECT * FROM OfflineChapterEntity '
    'WHERE sourceId = :sourceId AND comicId = :comicId '
    'ORDER BY groupName, sortIndex, chapterId',
  )
  Future<List<OfflineChapterEntity>> getChapters(
    String sourceId,
    String comicId,
  );

  @Query(
    "SELECT * FROM OfflineChapterEntity WHERE state = 'completed' "
    'ORDER BY completedAt, sourceId, comicId, groupName, sortIndex, chapterId',
  )
  Future<List<OfflineChapterEntity>> getAllReadableChapters();

  @Query(
    "SELECT * FROM OfflineChapterEntity WHERE state != 'completed' "
    'ORDER BY sourceId, comicId, groupName, sortIndex, chapterId',
  )
  Future<List<OfflineChapterEntity>> getIncompleteChapters();

  @Query(
    'SELECT * FROM OfflinePageEntity '
    'WHERE sourceId = :sourceId AND comicId = :comicId '
    'AND chapterId = :chapterId AND manifestGeneration = :generation '
    'ORDER BY pageIndex',
  )
  Future<List<OfflinePageEntity>> getPages(
    String sourceId,
    String comicId,
    String chapterId,
    int generation,
  );

  @Query('SELECT * FROM OfflinePageEntity WHERE taskId = :taskId')
  Future<OfflinePageEntity?> getPageByTaskId(String taskId);

  @Query(
    'UPDATE OfflinePageEntity SET expectedBytes = :expectedBytes '
    'WHERE sourceId = :sourceId AND comicId = :comicId '
    'AND chapterId = :chapterId AND manifestGeneration = :generation '
    'AND pageIndex = :pageIndex',
  )
  Future<void> setPageExpectedBytes(
    String sourceId,
    String comicId,
    String chapterId,
    int generation,
    int pageIndex,
    int expectedBytes,
  );

  @Query(
    'UPDATE OfflinePageEntity SET submitted = 1 '
    'WHERE sourceId = :sourceId AND comicId = :comicId '
    'AND chapterId = :chapterId AND manifestGeneration = :generation '
    'AND pageIndex = :pageIndex',
  )
  Future<void> markPageSubmitted(
    String sourceId,
    String comicId,
    String chapterId,
    int generation,
    int pageIndex,
  );

  @Query(
    'UPDATE OfflinePageEntity SET submitted = 0 '
    'WHERE sourceId = :sourceId AND comicId = :comicId '
    'AND chapterId = :chapterId AND manifestGeneration = :generation '
    'AND pageIndex = :pageIndex',
  )
  Future<void> markPageUnsubmitted(
    String sourceId,
    String comicId,
    String chapterId,
    int generation,
    int pageIndex,
  );

  @Query(
    'UPDATE OfflineChapterEntity SET operationGeneration = :operationGeneration, '
    "state = 'resolving', error = NULL, completedAt = NULL "
    'WHERE sourceId = :sourceId AND comicId = :comicId AND chapterId = :chapterId',
  )
  Future<void> setResolutionOperation(
    String sourceId,
    String comicId,
    String chapterId,
    int operationGeneration,
  );

  @transaction
  Future<OfflineChapterEntity> beginResolution(
    String sourceId,
    String comicId,
    String chapterId,
    int operationGeneration,
  ) async {
    await setResolutionOperation(
      sourceId,
      comicId,
      chapterId,
      operationGeneration,
    );
    return await getChapter(sourceId, comicId, chapterId) ??
        (throw StateError('Offline chapter disappeared before resolution'));
  }

  @Query(
    'DELETE FROM OfflinePageEntity '
    'WHERE sourceId = :sourceId AND comicId = :comicId AND chapterId = :chapterId',
  )
  Future<void> deleteChapterPages(
    String sourceId,
    String comicId,
    String chapterId,
  );

  @Query(
    "UPDATE OfflineChapterEntity SET state = 'completed', error = NULL, "
    'completedAt = :completedAt '
    'WHERE sourceId = :sourceId AND comicId = :comicId '
    'AND chapterId = :chapterId AND manifestGeneration = :generation '
    "AND state IN ('downloading', 'completed')",
  )
  Future<void> markChapterCompletedForGeneration(
    String sourceId,
    String comicId,
    String chapterId,
    int generation,
    DateTime completedAt,
  );

  @Query(
    "UPDATE OfflineChapterEntity SET state = 'paused', error = NULL, completedAt = NULL "
    'WHERE sourceId = :sourceId AND comicId = :comicId '
    'AND chapterId = :chapterId AND operationGeneration = :operationGeneration '
    "AND state = 'downloading'",
  )
  Future<void> markChapterPausedForOperation(
    String sourceId,
    String comicId,
    String chapterId,
    int operationGeneration,
  );

  @Query(
    'UPDATE OfflineChapterEntity SET state = :state, error = :error, completedAt = NULL '
    'WHERE sourceId = :sourceId AND comicId = :comicId '
    'AND chapterId = :chapterId AND operationGeneration = :operationGeneration '
    "AND state IN ('resolving', 'downloading')",
  )
  Future<void> markChapterErrorForOperation(
    String sourceId,
    String comicId,
    String chapterId,
    int operationGeneration,
    String state,
    String error,
  );

  @Query(
    'UPDATE OfflineChapterEntity SET state = :state, error = NULL, '
    'completedAt = NULL '
    'WHERE sourceId = :sourceId AND comicId = :comicId '
    'AND chapterId = :chapterId AND manifestGeneration = :generation',
  )
  Future<void> setChapterStateClearedForGeneration(
    String sourceId,
    String comicId,
    String chapterId,
    int generation,
    String state,
  );

  @Query(
    'UPDATE OfflineChapterEntity SET state = :state, error = :error, '
    'completedAt = NULL '
    'WHERE sourceId = :sourceId AND comicId = :comicId '
    'AND chapterId = :chapterId AND manifestGeneration = :generation',
  )
  Future<void> setChapterStateErrorForGeneration(
    String sourceId,
    String comicId,
    String chapterId,
    int generation,
    String state,
    String error,
  );

  @Query(
    'UPDATE OfflineChapterEntity SET state = :state, error = NULL, '
    'completedAt = :completedAt '
    'WHERE sourceId = :sourceId AND comicId = :comicId '
    'AND chapterId = :chapterId AND manifestGeneration = :generation',
  )
  Future<void> setChapterStateCompletedForGeneration(
    String sourceId,
    String comicId,
    String chapterId,
    int generation,
    String state,
    DateTime completedAt,
  );

  @Query(
    'UPDATE OfflineChapterEntity SET state = :state, error = :error, '
    'completedAt = :completedAt '
    'WHERE sourceId = :sourceId AND comicId = :comicId '
    'AND chapterId = :chapterId AND manifestGeneration = :generation',
  )
  Future<void> setChapterStateErrorAndCompletedForGeneration(
    String sourceId,
    String comicId,
    String chapterId,
    int generation,
    String state,
    String error,
    DateTime completedAt,
  );

  Future<void> setChapterStateForGeneration(
    String sourceId,
    String comicId,
    String chapterId,
    int generation,
    String state,
    String? error,
    DateTime? completedAt,
  ) {
    if (error != null && completedAt != null) {
      return setChapterStateErrorAndCompletedForGeneration(
        sourceId,
        comicId,
        chapterId,
        generation,
        state,
        error,
        completedAt,
      );
    }
    if (error != null) {
      return setChapterStateErrorForGeneration(
        sourceId,
        comicId,
        chapterId,
        generation,
        state,
        error,
      );
    }
    if (completedAt != null) {
      return setChapterStateCompletedForGeneration(
        sourceId,
        comicId,
        chapterId,
        generation,
        state,
        completedAt,
      );
    }
    return setChapterStateClearedForGeneration(
      sourceId,
      comicId,
      chapterId,
      generation,
      state,
    );
  }

  @Query(
    'DELETE FROM OfflineChapterEntity '
    'WHERE sourceId = :sourceId AND comicId = :comicId AND chapterId = :chapterId',
  )
  Future<void> deleteChapter(
    String sourceId,
    String comicId,
    String chapterId,
  );

  @Query(
    'DELETE FROM OfflineComicEntity '
    'WHERE sourceId = :sourceId AND comicId = :comicId '
    'AND NOT EXISTS (SELECT 1 FROM OfflineChapterEntity '
    'WHERE sourceId = :sourceId AND comicId = :comicId)',
  )
  Future<void> deleteComicIfEmpty(String sourceId, String comicId);

  @transaction
  Future<bool> replaceManifestIfCurrent(
    OfflineComicEntity comic,
    OfflineChapterEntity chapter,
    List<OfflinePageEntity> pages,
    int operationGeneration,
  ) async {
    final current = await getChapter(
      chapter.sourceId,
      chapter.comicId,
      chapter.chapterId,
    );
    if (current == null ||
        current.operationGeneration != operationGeneration ||
        current.state != 'resolving') {
      return false;
    }
    await saveComic(comic);
    await deleteChapterPages(
      chapter.sourceId,
      chapter.comicId,
      chapter.chapterId,
    );
    await upsertChapter(chapter);
    if (pages.isNotEmpty) await upsertPages(pages);
    return true;
  }

  @transaction
  Future<void> replaceManifest(
    OfflineComicEntity comic,
    OfflineChapterEntity chapter,
    List<OfflinePageEntity> pages,
  ) async {
    await saveComic(comic);
    await deleteChapterPages(
      chapter.sourceId,
      chapter.comicId,
      chapter.chapterId,
    );
    await upsertChapter(chapter);
    if (pages.isNotEmpty) await upsertPages(pages);
  }

  @transaction
  Future<void> removeChapterAndOrphanedComic(
    String sourceId,
    String comicId,
    String chapterId,
  ) async {
    await deleteChapter(sourceId, comicId, chapterId);
    await deleteComicIfEmpty(sourceId, comicId);
  }
}
