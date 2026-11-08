import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dcomic/database/entity/offline_comic.dart';
import 'package:dcomic/downloads/comic_download_models.dart';
import 'package:dcomic/downloads/download_models.dart';
import 'package:dcomic/downloads/download_service.dart';
import 'package:dcomic/providers/models/chapter_metadata.dart';

class OfflineTransferSnapshot {
  final String id;
  final DownloadState state;
  final int bytesReceived;
  final int? totalBytes;
  final String? error;
  final String resourceUrl;
  final Map<String, String> headers;
  final bool resumeRequested;

  const OfflineTransferSnapshot({
    required this.id,
    required this.state,
    required this.resourceUrl,
    this.bytesReceived = 0,
    this.totalBytes,
    this.headers = const {},
    this.resumeRequested = false,
    this.error,
  });
}

abstract interface class OfflineDownloadGateway {
  Future<Directory> get rootDirectory;
  Future<String> submit(DownloadRequest request);
  Future<OfflineTransferSnapshot?> get(String id);
  Stream<List<OfflineTransferSnapshot>> watch();
  Future<File?> completedFile(String id);
  Future<void> pause(String id);
  Future<void> resume(String id);
  Future<void> cancel(String id);
  Future<void> remove(String id);
}

class CoreOfflineDownloadGateway implements OfflineDownloadGateway {
  final DownloadService service;

  const CoreOfflineDownloadGateway(this.service);

  OfflineTransferSnapshot _snapshot(DownloadRecord record) =>
      OfflineTransferSnapshot(
        id: record.id,
        state: record.state,
        bytesReceived: record.bytesReceived,
        totalBytes: record.totalBytes,
        error: record.error,
        resourceUrl: record.request.url.toString(),
        headers: record.request.headers,
        resumeRequested: record.resumeRequested,
      );

  @override
  Future<Directory> get rootDirectory => service.rootDirectory;

  @override
  Future<String> submit(DownloadRequest request) => service.submit(request);

  @override
  Future<OfflineTransferSnapshot?> get(String id) async {
    final record = await service.get(id);
    return record == null ? null : _snapshot(record);
  }

  @override
  Stream<List<OfflineTransferSnapshot>> watch() => service.watch().map(
    (records) => records.map(_snapshot).toList(growable: false),
  );

  @override
  Future<File?> completedFile(String id) => service.completedFile(id);

  @override
  Future<void> pause(String id) => service.pause(id);

  @override
  Future<void> resume(String id) => service.resume(id);

  @override
  Future<void> cancel(String id) => service.cancel(id);

  @override
  Future<void> remove(String id) => service.remove(id);
}

class OfflineComicStore {
  final OfflineComicDao dao;
  final OfflineDownloadGateway transfers;
  final DateTime Function() _clock;
  Future<void> _manifestWrites = Future<void>.value();
  Future<void> _intentWrites = Future<void>.value();

  OfflineComicStore({
    required this.dao,
    required this.transfers,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  Future<void> saveManifest(OfflineManifest manifest) {
    final comic = manifest.comic;
    final chapter = manifest.chapter;
    if (chapter.key.sourceId != comic.key.sourceId ||
        chapter.key.comicId != comic.key.comicId) {
      throw ArgumentError('Chapter and comic identities do not match');
    }
    _validatePages(chapter.pages);
    return _serializeManifestWrite(() async {
      final comicEntity = await _mergedComicEntity(comic, chapter);
      await dao.replaceManifest(comicEntity, _chapterEntity(chapter), [
        for (final page in chapter.pages) _pageEntity(chapter, page),
      ]);
    });
  }

  Future<bool> publishManifestIfCurrent(
    OfflineManifest manifest, {
    required int operationGeneration,
  }) {
    final comic = manifest.comic;
    final chapter = manifest.chapter;
    _validatePages(chapter.pages);
    return _serializeManifestWrite(() async {
      final comicEntity = await _mergedComicEntity(comic, chapter);
      return dao.replaceManifestIfCurrent(
        comicEntity,
        _chapterEntity(chapter),
        [for (final page in chapter.pages) _pageEntity(chapter, page)],
        operationGeneration,
      );
    });
  }

  Future<OfflineManifest?> loadManifest(ChapterKey key) async {
    final chapter = await dao.getChapter(
      key.sourceId,
      key.comicId,
      key.chapterId,
    );
    if (chapter == null) return null;
    final comic = await dao.getComic(key.sourceId, key.comicId);
    if (comic == null) {
      throw StateError('Offline chapter has no owning comic: $key');
    }
    final pages = await dao.getPages(
      key.sourceId,
      key.comicId,
      key.chapterId,
      chapter.manifestGeneration,
    );
    final comicSnapshot = _comicSnapshot(comic);
    return OfflineManifest(
      comic: comicSnapshot,
      chapter: _chapterSnapshot(
        chapter,
        pages,
        _catalogChapter(comicSnapshot.catalog, chapter.chapterId),
      ),
    );
  }

  Future<OfflineComicSnapshot?> loadComicSnapshot(ComicKey key) async {
    final row = await dao.getComic(key.sourceId, key.comicId);
    return row == null ? null : _comicSnapshot(row);
  }

  Future<int> beginResolution(
    ChapterKey key, {
    required int operationGeneration,
  }) => _serializeIntentWrite(() async {
    final row = await dao.beginResolution(
      key.sourceId,
      key.comicId,
      key.chapterId,
      operationGeneration,
    );
    return row.operationGeneration;
  });

  Future<bool> beginResolutionIfCurrent(
    ChapterKey key, {
    required int expectedOperationGeneration,
    required OfflineChapterState expectedState,
    required int operationGeneration,
  }) => _serializeIntentWrite(() async {
    final current = await dao.getChapter(
      key.sourceId,
      key.comicId,
      key.chapterId,
    );
    if (current == null ||
        current.operationGeneration != expectedOperationGeneration ||
        current.state != expectedState.name) {
      return false;
    }
    final started = await dao.beginResolution(
      key.sourceId,
      key.comicId,
      key.chapterId,
      operationGeneration,
    );
    return started.operationGeneration == operationGeneration &&
        started.state == OfflineChapterState.resolving.name;
  });

  Future<bool> operationIsCurrent(
    ChapterKey key, {
    required int operationGeneration,
    required OfflineChapterState state,
  }) async {
    final row = await dao.getChapter(key.sourceId, key.comicId, key.chapterId);
    return row != null &&
        row.operationGeneration == operationGeneration &&
        row.state == state.name;
  }

  Future<void> markPageSubmitted(
    ChapterKey key, {
    required int generation,
    required int pageIndex,
  }) => dao.markPageSubmitted(
    key.sourceId,
    key.comicId,
    key.chapterId,
    generation,
    pageIndex,
  );

  Future<void> markPageUnsubmitted(
    ChapterKey key, {
    required int generation,
    required int pageIndex,
  }) => dao.markPageUnsubmitted(
    key.sourceId,
    key.comicId,
    key.chapterId,
    generation,
    pageIndex,
  );

  Future<void> markPausedForOperation(
    ChapterKey key,
    int operationGeneration,
  ) => dao.markChapterPausedForOperation(
    key.sourceId,
    key.comicId,
    key.chapterId,
    operationGeneration,
  );

  Future<void> markErrorForOperation(
    ChapterKey key,
    int operationGeneration, {
    required OfflineChapterState state,
    required String error,
  }) => dao.markChapterErrorForOperation(
    key.sourceId,
    key.comicId,
    key.chapterId,
    operationGeneration,
    state.name,
    error,
  );

  Future<ChapterKey?> chapterForTask(String taskId) async {
    final page = await dao.getPageByTaskId(taskId);
    return page == null
        ? null
        : (
            sourceId: page.sourceId,
            comicId: page.comicId,
            chapterId: page.chapterId,
          );
  }

  Future<List<OfflineManifest>> listManifests(ComicKey comic) async {
    final result = <OfflineManifest>[];
    for (final row in await dao.getChapters(comic.sourceId, comic.comicId)) {
      final manifest = await loadManifest((
        sourceId: row.sourceId,
        comicId: row.comicId,
        chapterId: row.chapterId,
      ));
      if (manifest != null) result.add(manifest);
    }
    return result;
  }

  Future<List<OfflineChapterSnapshot>> listReadableChapters(
    ComicKey comic,
  ) async {
    final rows = await dao.getChapters(comic.sourceId, comic.comicId);
    final comicRow = await dao.getComic(comic.sourceId, comic.comicId);
    final catalog = comicRow == null
        ? const <OfflineCatalogChapter>[]
        : _comicSnapshot(comicRow).catalog;
    final metadataById = {
      for (final chapter in catalog) chapter.chapterId: chapter,
    };
    final result = <OfflineChapterSnapshot>[];
    for (final row in rows) {
      if (row.state != OfflineChapterState.completed.name) continue;
      final snapshot = await _validatedReadable(
        row,
        metadataById[row.chapterId],
      );
      if (snapshot != null) result.add(snapshot);
    }
    return result;
  }

  Future<List<OfflineComicVersion>> listReadableComics() async {
    final comics = await dao.getAllComics();
    final result = <OfflineComicVersion>[];
    for (final row in comics) {
      final chapters = await listReadableChapters((
        sourceId: row.sourceId,
        comicId: row.comicId,
      ));
      if (chapters.isEmpty) continue;
      DateTime? earliest;
      for (final chapter in chapters) {
        final completed = chapter.completedAt;
        if (completed != null &&
            (earliest == null || completed.isBefore(earliest))) {
          earliest = completed;
        }
      }
      result.add(
        OfflineComicVersion(
          comic: _comicSnapshot(row),
          readableChapterCount: chapters.length,
          earliestCompletedAt: earliest,
        ),
      );
    }
    return result;
  }

  Future<List<OfflineManifest>> listIncompleteManifests() async {
    final result = <OfflineManifest>[];
    for (final row in await dao.getIncompleteChapters()) {
      final manifest = await loadManifest((
        sourceId: row.sourceId,
        comicId: row.comicId,
        chapterId: row.chapterId,
      ));
      if (manifest != null) result.add(manifest);
    }
    return result;
  }

  Future<bool> commitIfComplete(
    ChapterKey key, {
    required int generation,
  }) async {
    final row = await dao.getChapter(key.sourceId, key.comicId, key.chapterId);
    if (row == null || row.manifestGeneration != generation) return false;
    if (row.state != OfflineChapterState.downloading.name &&
        row.state != OfflineChapterState.completed.name) {
      return false;
    }
    final pages = await dao.getPages(
      key.sourceId,
      key.comicId,
      key.chapterId,
      generation,
    );
    if (pages.isEmpty) return false;
    final root = await transfers.rootDirectory;
    for (final page in pages) {
      final transfer = await transfers.get(page.taskId);
      if (transfer?.state != DownloadState.completed) return false;
      final file = _resolveRelative(root, page.relativePath);
      if (!await file.exists()) {
        await invalidateChapter(
          key,
          reason: 'Downloaded page is missing or incomplete',
        );
        return false;
      }
      final length = await file.length();
      if (length <= 0 ||
          (page.expectedBytes != null && page.expectedBytes != length)) {
        await invalidateChapter(
          key,
          reason: 'Downloaded page is missing or incomplete',
        );
        return false;
      }
      if (page.expectedBytes == null) {
        await dao.setPageExpectedBytes(
          key.sourceId,
          key.comicId,
          key.chapterId,
          generation,
          page.pageIndex,
          length,
        );
      }
    }
    await dao.markChapterCompletedForGeneration(
      key.sourceId,
      key.comicId,
      key.chapterId,
      generation,
      row.completedAt ?? _clock(),
    );
    final committed = await dao.getChapter(
      key.sourceId,
      key.comicId,
      key.chapterId,
    );
    return committed?.state == OfflineChapterState.completed.name;
  }

  Future<void> setChapterState(
    ChapterKey key, {
    required int generation,
    required OfflineChapterState state,
    String? error,
  }) => _serializeIntentWrite(
    () => dao.setChapterStateForGeneration(
      key.sourceId,
      key.comicId,
      key.chapterId,
      generation,
      state.name,
      error,
      state == OfflineChapterState.completed ? _clock() : null,
    ),
  );

  Future<void> invalidateChapter(
    ChapterKey key, {
    required String reason,
  }) async {
    final row = await dao.getChapter(key.sourceId, key.comicId, key.chapterId);
    if (row == null) return;
    await dao.setChapterStateForGeneration(
      key.sourceId,
      key.comicId,
      key.chapterId,
      row.manifestGeneration,
      OfflineChapterState.failed.name,
      reason,
      null,
    );
  }

  Future<void> removeChapter(ChapterKey key) async {
    final manifest = await loadManifest(key);
    if (manifest == null) return;
    await setChapterState(
      key,
      generation: manifest.chapter.manifestGeneration,
      state: OfflineChapterState.canceled,
    );
    try {
      for (final page in manifest.chapter.pages) {
        final transfer = await transfers.get(page.taskId);
        if (transfer != null &&
            transfer.state != DownloadState.canceled &&
            transfer.state != DownloadState.completed) {
          await transfers.cancel(page.taskId);
        }
        await transfers.remove(page.taskId);
      }
      final root = await transfers.rootDirectory;
      for (final page in manifest.chapter.pages) {
        final file = _resolveRelative(root, page.relativePath);
        if (await file.exists()) await file.delete();
      }
      await dao.removeChapterAndOrphanedComic(
        key.sourceId,
        key.comicId,
        key.chapterId,
      );
    } catch (error) {
      await invalidateChapter(key, reason: 'Removal failed: $error');
      rethrow;
    }
  }

  Future<OfflineChapterSnapshot?> _validatedReadable(
    OfflineChapterEntity row,
    OfflineCatalogChapter? metadata,
  ) async {
    final pages = await dao.getPages(
      row.sourceId,
      row.comicId,
      row.chapterId,
      row.manifestGeneration,
    );
    if (pages.isEmpty) {
      await invalidateChapter((
        sourceId: row.sourceId,
        comicId: row.comicId,
        chapterId: row.chapterId,
      ), reason: 'Completed chapter has an empty manifest');
      return null;
    }
    final root = await transfers.rootDirectory;
    for (final page in pages) {
      if (!await _validPageFile(root, page)) {
        await invalidateChapter((
          sourceId: row.sourceId,
          comicId: row.comicId,
          chapterId: row.chapterId,
        ), reason: 'Downloaded page is missing or incomplete');
        return null;
      }
    }
    return _chapterSnapshot(row, pages, metadata);
  }

  Future<bool> _validPageFile(Directory root, OfflinePageEntity page) async {
    final file = _resolveRelative(root, page.relativePath);
    if (!await file.exists()) return false;
    final length = await file.length();
    if (length <= 0) return false;
    final expected = page.expectedBytes;
    return expected == null || length == expected;
  }

  Future<bool> pageFileIsValid(OfflinePage page) async {
    final root = await transfers.rootDirectory;
    final file = _resolveRelative(root, page.relativePath);
    if (!await file.exists()) return false;
    final length = await file.length();
    return length > 0 &&
        (page.expectedBytes == null || page.expectedBytes == length);
  }

  File _resolveRelative(Directory root, String relativePath) {
    final normalized = relativePath.replaceAll('\\', '/');
    if (normalized.startsWith('/') ||
        normalized.split('/').any((segment) => segment == '..')) {
      throw FormatException('Invalid offline relative path: $relativePath');
    }
    return File(
      '${root.path}${Platform.pathSeparator}${normalized.replaceAll('/', Platform.pathSeparator)}',
    );
  }

  static void _validatePages(List<OfflinePage> pages) {
    final indices = <int>{};
    final tasks = <String>{};
    for (final page in pages) {
      if (page.index < 0 || !indices.add(page.index)) {
        throw ArgumentError(
          'Offline page indices must be unique and non-negative',
        );
      }
      if (page.taskId.isEmpty || !tasks.add(page.taskId)) {
        throw ArgumentError(
          'Offline page task ids must be unique and non-empty',
        );
      }
      if (page.relativePath.isEmpty || page.resourceUrl.isEmpty) {
        throw ArgumentError('Offline pages require paths and resource URLs');
      }
    }
    final ordered = indices.toList()..sort();
    for (var index = 0; index < ordered.length; index++) {
      if (ordered[index] != index) {
        throw ArgumentError(
          'Offline page indices must be contiguous from zero',
        );
      }
    }
  }

  Future<T> _serializeIntentWrite<T>(Future<T> Function() write) {
    final result = _intentWrites.then((_) => write());
    _intentWrites = result.then<void>(
      (_) {},
      onError: (Object error, StackTrace stack) {},
    );
    return result;
  }

  Future<T> _serializeManifestWrite<T>(Future<T> Function() write) {
    final result = _manifestWrites.then((_) => write());
    _manifestWrites = result.then<void>(
      (_) {},
      onError: (Object error, StackTrace stack) {},
    );
    return result;
  }

  Future<OfflineComicEntity> _mergedComicEntity(
    OfflineComicSnapshot comic,
    OfflineChapterSnapshot current,
  ) async {
    final persistedRow = await dao.getComic(comic.key.sourceId, comic.key.comicId);
    final persistedCatalog = persistedRow == null
        ? const <OfflineCatalogChapter>[]
        : _comicSnapshot(persistedRow).catalog;
    final persistedById = {
      for (final chapter in persistedCatalog) chapter.chapterId: chapter,
    };
    final durableIds = {
      for (final chapter
          in await dao.getChapters(comic.key.sourceId, comic.key.comicId))
        chapter.chapterId,
      current.key.chapterId,
    };
    final currentMetadata = OfflineCatalogChapter(
      chapterId: current.key.chapterId,
      rawTitle: current.rawTitle,
      groupName: current.groupName,
      language: current.language,
      scanlationGroups: current.scanlationGroups,
    );
    final merged = <OfflineCatalogChapter>[];
    final seen = <String>{};
    for (final chapter in comic.catalog) {
      if (!seen.add(chapter.chapterId)) continue;
      if (chapter.chapterId == current.key.chapterId) {
        merged.add(currentMetadata);
      } else {
        merged.add(
          durableIds.contains(chapter.chapterId)
              ? persistedById[chapter.chapterId] ?? chapter
              : chapter,
        );
      }
    }
    for (final chapter in persistedCatalog) {
      if (durableIds.contains(chapter.chapterId) &&
          seen.add(chapter.chapterId)) {
        merged.add(chapter);
      }
    }
    if (seen.add(current.key.chapterId)) merged.add(currentMetadata);
    return _comicEntity(comic, merged);
  }

  OfflineComicEntity _comicEntity(
    OfflineComicSnapshot comic,
    List<OfflineCatalogChapter> catalog,
  ) => OfflineComicEntity(
        comic.key.sourceId,
        comic.key.comicId,
        comic.rawTitle,
        jsonEncode([
          for (final chapter in catalog)
            {
              'chapterId': chapter.chapterId,
              'rawTitle': chapter.rawTitle,
              'groupName': chapter.groupName,
              'language': chapter.language,
              'scanlationGroups': [
                for (final group in chapter.scanlationGroups) group.toJson(),
              ],
            },
        ]),
        comic.coverRelativePath,
        comic.remoteCoverUrl,
        comic.isLongComic,
      );

  OfflineComicSnapshot _comicSnapshot(OfflineComicEntity row) =>
      OfflineComicSnapshot(
        key: (sourceId: row.sourceId, comicId: row.comicId),
        rawTitle: row.rawTitle,
        catalog: [
          for (final value in jsonDecode(row.catalogJson) as List)
            OfflineCatalogChapter(
              chapterId: (value as Map)['chapterId'] as String,
              rawTitle: value['rawTitle'] as String,
              groupName: value['groupName'] as String,
              language: value['language'] as String?,
              scanlationGroups: [
                for (final group
                    in (value['scanlationGroups'] as List?) ?? const [])
                  ScanlationGroup.fromJson(group as Map<String, dynamic>),
              ],
            ),
        ],
        coverRelativePath: row.coverRelativePath,
        remoteCoverUrl: row.remoteCoverUrl,
        isLongComic: row.isLongComic,
      );

  OfflineChapterSnapshot _chapterSnapshot(
    OfflineChapterEntity row,
    List<OfflinePageEntity> pages,
    OfflineCatalogChapter? metadata,
  ) => OfflineChapterSnapshot(
    key: (
      sourceId: row.sourceId,
      comicId: row.comicId,
      chapterId: row.chapterId,
    ),
    rawTitle: row.rawTitle,
    groupName: row.groupName,
    language: metadata?.language,
    scanlationGroups: metadata?.scanlationGroups ?? const [],
    sortIndex: row.sortIndex,
    manifestGeneration: row.manifestGeneration,
    operationGeneration: row.operationGeneration,
    manifestSignature: row.manifestSignature,
    state: OfflineChapterState.values.byName(row.state),
    error: row.error,
    completedAt: row.completedAt,
    pages: [for (final page in pages) _pageSnapshot(page)],
  );

  OfflineChapterEntity _chapterEntity(OfflineChapterSnapshot chapter) =>
      OfflineChapterEntity(
        chapter.key.sourceId,
        chapter.key.comicId,
        chapter.key.chapterId,
        chapter.rawTitle,
        chapter.groupName,
        chapter.sortIndex,
        chapter.manifestGeneration,
        chapter.operationGeneration,
        chapter.manifestSignature,
        chapter.state.name,
        chapter.error,
        chapter.completedAt,
      );

  OfflineCatalogChapter? _catalogChapter(
    List<OfflineCatalogChapter> catalog,
    String chapterId,
  ) {
    for (final chapter in catalog) {
      if (chapter.chapterId == chapterId) return chapter;
    }
    return null;
  }

  OfflinePageEntity _pageEntity(
    OfflineChapterSnapshot chapter,
    OfflinePage page,
  ) => OfflinePageEntity(
    chapter.key.sourceId,
    chapter.key.comicId,
    chapter.key.chapterId,
    chapter.manifestGeneration,
    page.index,
    page.taskId,
    page.relativePath,
    page.resourceUrl,
    jsonEncode(page.headers),
    page.cacheKey,
    page.expectedBytes,
    page.submitted,
  );

  OfflinePage _pageSnapshot(OfflinePageEntity row) => OfflinePage(
    index: row.pageIndex,
    taskId: row.taskId,
    relativePath: row.relativePath,
    resourceUrl: row.resourceUrl,
    headers: Map<String, String>.from(jsonDecode(row.headersJson) as Map),
    cacheKey: row.cacheKey,
    expectedBytes: row.expectedBytes,
    submitted: row.submitted,
  );
}
