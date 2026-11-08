import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:dcomic/database/database_instance.dart';
import 'package:dcomic/downloads/comic_download_models.dart';
import 'package:dcomic/downloads/download_models.dart';
import 'package:dcomic/downloads/download_service.dart';
import 'package:dcomic/downloads/offline_chapter_resolver.dart';
import 'package:dcomic/downloads/offline_comic_store.dart';
import 'package:dcomic/providers/models/comic_source_model.dart';
import 'package:dcomic/utils/comic_mapping_utils.dart';
import 'package:dcomic/utils/image_utils.dart';

typedef OfflineSourceLookup = Future<BaseComicSourceModel?> Function(
  String sourceId,
);

class ComicDownloadService {
  static final ComicDownloadService instance = ComicDownloadService._global();

  OfflineComicStore? _store;
  OfflineDownloadGateway? _transfers;
  OfflineChapterResolver? _resolver;
  OfflineSourceLookup? _sourceLookup;
  StreamSubscription<List<OfflineTransferSnapshot>>? _transferSubscription;
  final StreamController<void> _changes = StreamController<void>.broadcast();
  bool _initialized = false;
  Future<void>? _initializeFuture;
  bool _aggregateDownloads = false;
  bool _reuseAcrossSources = true;
  Future<void> _eventQueue = Future.value();
  static int _operationNonce = DateTime.now().microsecondsSinceEpoch;
  final Set<ChapterKey> _activeTransferHandoffs = {};
  final Map<ChapterKey, int> _transferHandoffRevisions = {};

  ComicDownloadService({
    required OfflineComicStore store,
    required OfflineDownloadGateway transfers,
    OfflineSourceLookup? sourceLookup,
  }) : _store = store,
       _transfers = transfers,
       _sourceLookup = sourceLookup;

  ComicDownloadService._global() {
    BaseComicDetailModel.installOfflineRuntimeInitializer(
      () => ComicDownloadService.instance.initialize(),
    );
  }

  OfflineComicStore get store =>
      _store ?? (throw StateError('ComicDownloadService is not initialized'));

  OfflineDownloadGateway get transfers =>
      _transfers ??
      (throw StateError('ComicDownloadService is not initialized'));

  OfflineChapterResolver get resolver =>
      _resolver ??
      (throw StateError('ComicDownloadService is not initialized'));

  Stream<void> get changes => _changes.stream;

  void configureSourceLookup(OfflineSourceLookup lookup) {
    _sourceLookup = lookup;
  }

  Future<void> initialize() {
    if (_initialized) return Future.value();
    final active = _initializeFuture;
    if (active != null) return active;
    final future = _initialize();
    _initializeFuture = future;
    return future.whenComplete(() {
      if (!_initialized && identical(_initializeFuture, future)) {
        _initializeFuture = null;
      }
    });
  }

  Future<void> _initialize() async {
    try {
      if (_store == null || _transfers == null) {
        final core = DownloadService.instance;
        await core.initialize();
        final database = await DatabaseInstance.instance;
        _transfers = CoreOfflineDownloadGateway(core);
        _store = OfflineComicStore(
          dao: database.offlineComicDao,
          transfers: _transfers!,
        );
      }
      final database = await DatabaseInstance.instance;
      await refreshSettings();
      _resolver = OfflineChapterResolver(
        store: store,
        mappingLoader: database.comicMappingDao.getAllComicMappingEntity,
        ruleLoader: database.chapterRuleDao.loadChapterRules,
        aggregateDownloads: () => _aggregateDownloads,
        reuseAcrossSources: () => _reuseAcrossSources,
        commentLoader: _loadActualComments,
      );
      BaseComicDetailModel.installOfflineResolver((detail, chapterId) async {
        await initialize();
        await refreshSettings();
        return resolver.resolve(detail, chapterId);
      });
      _transferSubscription = transfers.watch().listen(_enqueueTransferUpdate);
      await _recoverPersistedIntents();
      _initialized = true;
    } catch (_) {
      await _transferSubscription?.cancel();
      _transferSubscription = null;
      rethrow;
    }
  }

  Future<void> refreshSettings() async {
    final database = await DatabaseInstance.instance;
    final aggregate = await database.configDao.getConfigByKey(
      'AggregateDownloads',
    );
    final reuse = await database.configDao.getConfigByKey(
      'ReuseDownloadedChaptersAcrossSources',
    );
    final nextAggregate = aggregate?.get<bool>() ?? false;
    final nextReuse = reuse?.get<bool>() ?? true;
    final changed =
        nextAggregate != _aggregateDownloads ||
        nextReuse != _reuseAcrossSources;
    _aggregateDownloads = nextAggregate;
    _reuseAcrossSources = nextReuse;
    if (changed) _emitChange();
  }

  Future<void> downloadChapters(
    BaseComicDetailModel detail,
    List<String> chapterIds,
  ) async {
    final selected = chapterIds.toSet();
    if (selected.isEmpty) return;
    final catalog =
        <
          String,
          ({String group, int sort, BaseComicChapterEntityModel chapter})
        >{};
    for (final entry in detail.chapterCatalog.entries) {
      for (var index = 0; index < entry.value.length; index++) {
        final chapter = entry.value[index];
        if (catalog.containsKey(chapter.chapterId)) {
          throw StateError(
            'Duplicate chapter id in source catalog: ${chapter.chapterId}',
          );
        }
        catalog[chapter.chapterId] = (
          group: entry.key,
          sort: index,
          chapter: chapter,
        );
      }
    }
    Object? firstError;
    StackTrace? firstStack;
    for (final chapterId in selected) {
      final metadata = catalog[chapterId];
      if (metadata == null) {
        firstError ??= ArgumentError.value(
          chapterId,
          'chapterIds',
          'Chapter is not present in this detail catalog',
        );
        continue;
      }
      try {
        await _downloadOne(detail, metadata);
      } catch (error, stack) {
        firstError ??= error;
        firstStack ??= stack;
      }
    }
    if (firstError != null) {
      Error.throwWithStackTrace(firstError, firstStack ?? StackTrace.current);
    }
  }

  Future<void> pauseChapter(ChapterKey key) async {
    final manifest = await _requireManifest(key);
    for (final page in manifest.chapter.pages) {
      final transfer = await transfers.get(page.taskId);
      if (transfer != null &&
          (transfer.state == DownloadState.running ||
              transfer.state == DownloadState.queued)) {
        await transfers.pause(page.taskId);
      }
    }
    await store.setChapterState(
      key,
      generation: manifest.chapter.manifestGeneration,
      state: OfflineChapterState.paused,
    );
    _emitChange();
  }

  Future<void> resumeChapter(ChapterKey key) async {
    final manifest = await _requireManifest(key);
    final lookup = _sourceLookup;
    if (lookup != null) {
      final source = await lookup(key.sourceId);
      if (source == null) {
        throw StateError('Comic source is unavailable: ${key.sourceId}');
      }
      final detail = await source.getComicDetail(
        key.comicId,
        manifest.comic.rawTitle,
      );
      if (detail == null) {
        throw StateError('Comic detail could not be refreshed for $key');
      }
      try {
        final metadata = _chapterMetadata(detail, key.chapterId);
        await _downloadOne(detail, metadata, forceRefresh: true);
      } finally {
        detail.dispose();
      }
      return;
    }
    if (manifest.chapter.pages.isEmpty ||
        manifest.chapter.state == OfflineChapterState.canceled) {
      throw StateError('A source registry is required to refresh this chapter');
    }
    for (final page in manifest.chapter.pages) {
      final transfer = await transfers.get(page.taskId);
      if (transfer == null) {
        await transfers.submit(_request(manifest, page));
      } else if (transfer.state == DownloadState.paused ||
          transfer.state == DownloadState.failed) {
        await transfers.resume(page.taskId);
      }
    }
    await store.setChapterState(
      key,
      generation: manifest.chapter.manifestGeneration,
      state: OfflineChapterState.downloading,
    );
    _emitChange();
  }


  Future<void> cancelChapter(ChapterKey key) async {
    final manifest = await _requireManifest(key);
    for (final page in manifest.chapter.pages) {
      final transfer = await transfers.get(page.taskId);
      if (transfer != null &&
          transfer.state != DownloadState.canceled &&
          transfer.state != DownloadState.completed) {
        await transfers.cancel(page.taskId);
      }
    }
    await store.setChapterState(
      key,
      generation: manifest.chapter.manifestGeneration,
      state: OfflineChapterState.canceled,
    );
    _emitChange();
  }

  Future<void> removeChapter(ChapterKey key) async {
    await store.removeChapter(key);
    _emitChange();
  }

  Future<List<OfflineComicListItem>> listReadableComics({
    required bool aggregate,
  }) async {
    final versions = await store.listReadableComics();
    if (!aggregate) {
      return [
        for (final version in versions)
          OfflineComicListItem(
            title: version.comic.rawTitle,
            versions: [version],
            aggregated: false,
          ),
      ];
    }
    final database = await DatabaseInstance.instance;
    final groups = reliableComicGroups(
      await database.comicMappingDao.getAllComicMappingEntity(),
    ).toList();
    final byKey = <(String, String), OfflineComicVersion>{
      for (final version in versions)
        (version.comic.key.sourceId, version.comic.key.comicId): version,
    };
    final consumed = <(String, String)>{};
    final result = <OfflineComicListItem>[];
    for (final group in groups) {
      final grouped = <OfflineComicVersion>[];
      for (final key in group) {
        final version = byKey[key];
        if (version != null) {
          grouped.add(version);
          consumed.add(key);
        }
      }
      if (grouped.isEmpty) continue;
      grouped.sort(_compareComicVersions);
      result.add(
        OfflineComicListItem(
          title: grouped.first.comic.rawTitle,
          versions: grouped,
          aggregated: grouped.length > 1,
        ),
      );
    }
    for (final entry in byKey.entries) {
      if (consumed.contains(entry.key)) continue;
      result.add(
        OfflineComicListItem(
          title: entry.value.comic.rawTitle,
          versions: [entry.value],
          aggregated: false,
        ),
      );
    }
    result.sort((left, right) => left.title.compareTo(right.title));
    return result;
  }

  Future<List<OfflineChapterSnapshot>> listReadableChapters(ComicKey comic) =>
      store.listReadableChapters(comic);

  Future<OfflineChapterProgress?> chapterProgress(ChapterKey key) async {
    final manifest = await store.loadManifest(key);
    return manifest == null ? null : _progress(manifest);
  }

  Future<Map<ChapterKey, OfflineChapterProgress>> listChapterProgress(
    ComicKey comic,
  ) async {
    final result = <ChapterKey, OfflineChapterProgress>{};
    for (final manifest in await store.listManifests(comic)) {
      result[manifest.chapter.key] = await _progress(manifest);
    }
    return result;
  }

  Future<List<OfflineChapterTask>> listIncompleteChapterTasks() async {
    final result = <OfflineChapterTask>[];
    for (final manifest in await store.listIncompleteManifests()) {
      result.add(
        OfflineChapterTask(
          comic: manifest.comic,
          chapter: manifest.chapter,
          progress: await _progress(manifest),
        ),
      );
    }
    return result;
  }

  Future<ChapterKey?> chapterForTask(String taskId) =>
      store.chapterForTask(taskId);

  Future<void> reconcile() => _reconcileTransferUpdate();

  Future<OfflineChapterAvailability> chapterAvailability(
    BaseComicDetailModel detail,
    String requestedChapterId, {
    required bool includeMapped,
  }) => resolver.availability(
    detail,
    requestedChapterId,
    includeMapped: includeMapped,
  );

  Future<void> dispose() async {
    await _transferSubscription?.cancel();
    _transferSubscription = null;
    if (!_changes.isClosed) await _changes.close();
  }

  Future<void> _downloadOne(
    BaseComicDetailModel detail,
    ({String group, int sort, BaseComicChapterEntityModel chapter}) metadata, {
    bool forceRefresh = false,
    int? expectedOperationGeneration,
  }) async {
    final key = (
      sourceId: detail.parent.type.sourceId,
      comicId: detail.comicId,
      chapterId: metadata.chapter.chapterId,
    );
    final previous = await store.loadManifest(key);
    if (expectedOperationGeneration != null &&
        (previous == null ||
            previous.chapter.operationGeneration !=
                expectedOperationGeneration ||
            previous.chapter.state != OfflineChapterState.downloading)) {
      return;
    }
    if (previous?.chapter.state == OfflineChapterState.completed) {
      _emitChange();
      return;
    }
    final operationGeneration = ++_operationNonce;
    if (previous == null) {
      await store.saveManifest(
        OfflineManifest(
          comic: _comicSnapshot(detail),
          chapter: OfflineChapterSnapshot(
            key: key,
            rawTitle: metadata.chapter.rawTitle,
            groupName: metadata.group,
            language: metadata.chapter.language,
            scanlationGroups: metadata.chapter.scanlationGroups,
            sortIndex: metadata.sort,
            manifestGeneration: 1,
            operationGeneration: operationGeneration,
            manifestSignature: '',
            state: OfflineChapterState.resolving,
          ),
        ),
      );
    } else if (expectedOperationGeneration == null) {
      await store.beginResolution(
        key,
        operationGeneration: operationGeneration,
      );
    } else if (!await store.beginResolutionIfCurrent(
      key,
      expectedOperationGeneration: expectedOperationGeneration,
      expectedState: OfflineChapterState.downloading,
      operationGeneration: operationGeneration,
    )) {
      return;
    }

    try {
      final remote = await detail.fetchRemoteChapter(key.chapterId);
      if (remote == null || remote.pages.isEmpty) {
        throw StateError('Source returned an empty chapter manifest for $key');
      }
      for (final page in remote.pages) {
        if (page.imageType != ImageType.network || page.imageUrl.isEmpty) {
          throw StateError('Source returned a non-network page for $key');
        }
      }
      if (!await store.operationIsCurrent(
        key,
        operationGeneration: operationGeneration,
        state: OfflineChapterState.resolving,
      )) {
        return;
      }
      final signature = _manifestSignature(remote.pages);
      final same =
          previous != null &&
          previous.chapter.state != OfflineChapterState.canceled &&
          previous.chapter.manifestSignature == signature &&
          previous.chapter.pages.length == remote.pages.length;
      final generation = same
          ? previous.chapter.manifestGeneration
          : (previous?.chapter.manifestGeneration ?? 0) + 1;
      if (!same && previous != null) {
        for (final page in previous.chapter.pages) {
          await store.markPageUnsubmitted(
            key,
            generation: previous.chapter.manifestGeneration,
            pageIndex: page.index,
          );
          final transfer = await transfers.get(page.taskId);
          if (transfer != null) {
            if (transfer.state != DownloadState.canceled &&
                transfer.state != DownloadState.completed) {
              await transfers.cancel(page.taskId);
            }
            await transfers.remove(page.taskId);
          }
        }
      }
      if (!await store.operationIsCurrent(
        key,
        operationGeneration: operationGeneration,
        state: OfflineChapterState.resolving,
      )) {
        return;
      }
      final manifest = same
          ? OfflineManifest(
              comic: previous.comic,
              chapter: previous.chapter.copyWith(
                operationGeneration: operationGeneration,
                state: OfflineChapterState.downloading,
                clearError: true,
                clearCompletedAt: true,
                pages: [
                  for (var index = 0;
                      index < previous.chapter.pages.length;
                      index++)
                    OfflinePage(
                      index: previous.chapter.pages[index].index,
                      taskId: previous.chapter.pages[index].taskId,
                      relativePath:
                          previous.chapter.pages[index].relativePath,
                      resourceUrl: remote.pages[index].imageUrl,
                      headers:
                          remote.pages[index].imageHeaders ?? const {},
                      cacheKey: imageCacheIdentity(
                        remote.pages[index].imageUrl,
                        remote.pages[index].imageHeaders,
                      ),
                      expectedBytes:
                          previous.chapter.pages[index].expectedBytes,
                      submitted: previous.chapter.pages[index].submitted,
                    ),
                ],
              ),
            )
          : _createManifest(
              detail,
              metadata,
              remote.pages,
              generation,
              operationGeneration,
              signature,
              previousChapter: previous?.chapter,
            );
      if (!await store.publishManifestIfCurrent(
        manifest,
        operationGeneration: operationGeneration,
      )) {
        return;
      }
      final handoffRevision = _beginTransferHandoff(key);
      try {
        for (final page in manifest.chapter.pages) {
          if (!await _ensurePageTransfer(
            manifest,
            page,
            operationGeneration: operationGeneration,
            forceRefresh: forceRefresh,
          )) {
            return;
          }
        }
      } finally {
        _endTransferHandoff(key, handoffRevision);
      }
      await store.commitIfComplete(key, generation: generation);
      _emitChange();
    } catch (error) {
      await store.markErrorForOperation(
        key,
        operationGeneration,
        state: OfflineChapterState.failed,
        error: error.toString(),
      );
      _emitChange();
      rethrow;
    }
  }

  Future<bool> _ensurePageTransfer(
    OfflineManifest manifest,
    OfflinePage page, {
    required int operationGeneration,
    required bool forceRefresh,
  }) async {
    final key = manifest.chapter.key;
    if (!await store.operationIsCurrent(
      key,
      operationGeneration: operationGeneration,
      state: OfflineChapterState.downloading,
    )) {
      return false;
    }
    var transfer = await transfers.get(page.taskId);
    final invalidTransfer =
        (transfer?.state == DownloadState.completed &&
            !await store.pageFileIsValid(page)) ||
        transfer?.state == DownloadState.canceled;
    final transportChanged =
        transfer != null && _transferTransportChanged(transfer, page);
    final replaceForTransport =
        forceRefresh &&
        transportChanged &&
        transfer.state != DownloadState.completed;
    if (invalidTransfer || replaceForTransport) {
      await store.markPageUnsubmitted(
        key,
        generation: manifest.chapter.manifestGeneration,
        pageIndex: page.index,
      );
      await transfers.remove(page.taskId);
      transfer = null;
      await transfers.submit(_request(manifest, page));
    } else if (transfer == null) {
      await transfers.submit(_request(manifest, page));
    } else if (forceRefresh &&
        !transportChanged &&
        (transfer.state == DownloadState.paused ||
            transfer.state == DownloadState.failed)) {
      await transfers.resume(page.taskId);
    }
    if (await store.operationIsCurrent(
      key,
      operationGeneration: operationGeneration,
      state: OfflineChapterState.completed,
    )) {
      return true;
    }
    if (!await store.operationIsCurrent(
      key,
      operationGeneration: operationGeneration,
      state: OfflineChapterState.downloading,
    )) {
      final submitted = await transfers.get(page.taskId);
      if (submitted != null &&
          submitted.state != DownloadState.canceled &&
          submitted.state != DownloadState.completed) {
        await transfers.cancel(page.taskId);
      }
      if (submitted != null && submitted.state != DownloadState.completed) {
        await transfers.remove(page.taskId);
      }
      return false;
    }
    await store.markPageSubmitted(
      key,
      generation: manifest.chapter.manifestGeneration,
      pageIndex: page.index,
    );
    return true;
  }

  OfflineManifest _createManifest(
    BaseComicDetailModel detail,
    ({String group, int sort, BaseComicChapterEntityModel chapter}) metadata,
    List<ImageEntity> images,
    int generation,
    int operationGeneration,
    String signature, {
    OfflineChapterSnapshot? previousChapter,
  }) {
    final key = (
      sourceId: detail.parent.type.sourceId,
      comicId: detail.comicId,
      chapterId: metadata.chapter.chapterId,
    );
    final keyHashes = [
      key.sourceId,
      key.comicId,
      key.chapterId,
    ].map(_shortHash).toList(growable: false);
    return OfflineManifest(
      comic: _comicSnapshot(detail),
      chapter: OfflineChapterSnapshot(
        key: key,
        rawTitle: metadata.chapter.rawTitle,
        groupName: metadata.group,
        language: metadata.chapter.language ?? previousChapter?.language,
        scanlationGroups: metadata.chapter.scanlationGroups.isEmpty
            ? previousChapter?.scanlationGroups ?? const []
            : metadata.chapter.scanlationGroups,
        sortIndex: metadata.sort,
        manifestGeneration: generation,
        operationGeneration: operationGeneration,
        manifestSignature: signature,
        state: OfflineChapterState.downloading,
        pages: [
          for (var index = 0; index < images.length; index++)
            OfflinePage(
              index: index,
              taskId: _taskId(key, generation, index),
              relativePath:
                  'comics/${keyHashes[0]}/${keyHashes[1]}/${keyHashes[2]}/'
                  'g$generation/${index.toString().padLeft(5, '0')}'
                  '${_extension(images[index].imageUrl)}',
              resourceUrl: images[index].imageUrl,
              headers: images[index].imageHeaders ?? const {},
              cacheKey: imageCacheIdentity(
                images[index].imageUrl,
                images[index].imageHeaders,
              ),
            ),
        ],
      ),
    );
  }

  OfflineComicSnapshot _comicSnapshot(BaseComicDetailModel detail) =>
      OfflineComicSnapshot(
        key: (sourceId: detail.parent.type.sourceId, comicId: detail.comicId),
        rawTitle: detail.rawTitle,
        remoteCoverUrl: detail.cover.imageType == ImageType.network
            ? detail.cover.imageUrl
            : null,
        isLongComic: detail.isLongComic,
        catalog: [
          for (final entry in detail.chapterCatalog.entries)
            for (final chapter in entry.value)
              OfflineCatalogChapter(
                chapterId: chapter.chapterId,
                rawTitle: chapter.rawTitle,
                groupName: entry.key,
                language: chapter.language,
                scanlationGroups: chapter.scanlationGroups,
              ),
        ],
      );

  DownloadRequest _request(OfflineManifest manifest, OfflinePage page) =>
      DownloadRequest(
        id: page.taskId,
        url: Uri.parse(page.resourceUrl),
        relativePath: page.relativePath,
        group:
            'comic:${manifest.chapter.key.sourceId}:'
            '${manifest.chapter.key.comicId}:${manifest.chapter.key.chapterId}',
        headers: page.headers,
        integrity: DownloadIntegrity(expectedBytes: page.expectedBytes),
        strategy: TransferStrategy.single,
        chunks: 1,
        cacheKey: page.cacheKey,
        displayName:
            '${manifest.comic.rawTitle} · ${manifest.chapter.rawTitle}',
      );

  Future<OfflineChapterProgress> _progress(OfflineManifest manifest) async {
    var completed = 0;
    var bytes = 0;
    var knownTotal = 0;
    var allTotalsKnown = true;
    String? transferError;
    for (final page in manifest.chapter.pages) {
      final transfer = await transfers.get(page.taskId);
      if (transfer?.state == DownloadState.completed) completed++;
      bytes += transfer?.bytesReceived ?? 0;
      final total = transfer?.totalBytes ?? page.expectedBytes;
      if (total == null) {
        allTotalsKnown = false;
      } else {
        knownTotal += total;
      }
      transferError ??= transfer?.error;
    }
    return OfflineChapterProgress(
      key: manifest.chapter.key,
      state: manifest.chapter.state,
      completedPages: completed,
      totalPages: manifest.chapter.pages.length,
      bytesReceived: bytes,
      totalBytes: allTotalsKnown ? knownTotal : null,
      error: manifest.chapter.error ?? transferError,
    );
  }

  Future<OfflineManifest> _requireManifest(ChapterKey key) async =>
      await store.loadManifest(key) ??
      (throw StateError('Offline chapter intent does not exist: $key'));

  ({String group, int sort, BaseComicChapterEntityModel chapter})
  _chapterMetadata(BaseComicDetailModel detail, String chapterId) {
    ({String group, int sort, BaseComicChapterEntityModel chapter})? found;
    for (final entry in detail.chapterCatalog.entries) {
      for (var index = 0; index < entry.value.length; index++) {
        final chapter = entry.value[index];
        if (chapter.chapterId != chapterId) continue;
        if (found != null) {
          throw StateError('Duplicate refreshed chapter id: $chapterId');
        }
        found = (group: entry.key, sort: index, chapter: chapter);
      }
    }
    return found ??
        (throw StateError('Refreshed catalog no longer contains $chapterId'));
  }

  Future<List<ChapterCommentEntity>> _loadActualComments(
    ChapterKey actual,
  ) async {
    final lookup = _sourceLookup;
    if (lookup == null) throw OfflineCommentsUnavailableException(actual);
    final source = await lookup(actual.sourceId);
    if (source == null) throw OfflineCommentsUnavailableException(actual);
    final manifest = await store.loadManifest(actual);
    if (manifest == null) throw OfflineCommentsUnavailableException(actual);
    final detail = await source.getComicDetail(
      actual.comicId,
      manifest.comic.rawTitle,
    );
    if (detail == null) throw OfflineCommentsUnavailableException(actual);
    try {
      final chapter = await detail.fetchRemoteChapter(actual.chapterId);
      if (chapter == null) throw OfflineCommentsUnavailableException(actual);
      try {
        return await chapter.getChapterComments();
      } finally {
        chapter.dispose();
      }
    } finally {
      detail.dispose();
    }
  }

  Future<void> _recoverPersistedIntents() async {
    for (final manifest in await store.listIncompleteManifests()) {
      final chapter = manifest.chapter;
      if (chapter.state == OfflineChapterState.paused ||
          chapter.state == OfflineChapterState.canceled ||
          chapter.state == OfflineChapterState.failed) {
        continue;
      }
      if (chapter.pages.isEmpty) {
        if (_sourceLookup != null) {
          try {
            await resumeChapter(chapter.key);
          } catch (error) {
            await store.setChapterState(
              chapter.key,
              generation: chapter.manifestGeneration,
              state: OfflineChapterState.failed,
              error: 'Chapter manifest refresh failed: $error',
            );
          }
        } else {
          await store.setChapterState(
            chapter.key,
            generation: chapter.manifestGeneration,
            state: OfflineChapterState.failed,
            error: 'Waiting for source runtime to refresh the chapter manifest',
          );
        }
        continue;
      }
      if (chapter.state == OfflineChapterState.resolving) {
        await store.setChapterState(
          chapter.key,
          generation: chapter.manifestGeneration,
          state: OfflineChapterState.downloading,
        );
      }
      var explicitlyRemoved = false;
      var explicitlyCanceled = false;
      for (final page in chapter.pages) {
        final transfer = await transfers.get(page.taskId);
        if (transfer?.state == DownloadState.canceled) {
          explicitlyCanceled = true;
          break;
        }
        if (transfer == null && page.submitted) {
          explicitlyRemoved = true;
          break;
        }
        if (transfer == null) {
          await transfers.submit(_request(manifest, page));
        }
        if (!page.submitted) {
          await store.markPageSubmitted(
            chapter.key,
            generation: chapter.manifestGeneration,
            pageIndex: page.index,
          );
        }
      }
      if (explicitlyCanceled) {
        await store.setChapterState(
          chapter.key,
          generation: chapter.manifestGeneration,
          state: OfflineChapterState.canceled,
          error: 'A page transfer was canceled',
        );
        continue;
      }
      if (explicitlyRemoved) {
        await store.setChapterState(
          chapter.key,
          generation: chapter.manifestGeneration,
          state: OfflineChapterState.canceled,
          error: 'A page transfer was explicitly removed',
        );
        continue;
      }
      await store.commitIfComplete(
        chapter.key,
        generation: chapter.manifestGeneration,
      );
    }
    _emitChange();
  }

  void _enqueueTransferUpdate(List<OfflineTransferSnapshot> _) {
    _eventQueue = _eventQueue
        .then((_) => _reconcileTransferUpdate())
        .catchError((Object error, StackTrace stack) {
          if (!_changes.isClosed) _changes.addError(error, stack);
        });
  }

  Future<void> _reconcileTransferUpdate() async {
    for (final manifest in await store.listIncompleteManifests()) {
      final chapter = manifest.chapter;
      if (chapter.pages.isEmpty ||
          chapter.state == OfflineChapterState.canceled ||
          chapter.state == OfflineChapterState.resolving) {
        continue;
      }
      final handoffRevision = _transferHandoffRevisions[chapter.key] ?? 0;
      if (_activeTransferHandoffs.contains(chapter.key)) continue;
      final committed = await store.commitIfComplete(
        chapter.key,
        generation: chapter.manifestGeneration,
      );
      if (_transferHandoffChanged(chapter.key, handoffRevision)) continue;
      if (committed) continue;
      String? failure;
      var paused = false;
      var explicitlyRemoved = false;
      var explicitlyCanceled = false;
      for (final page in chapter.pages) {
        final transfer = await transfers.get(page.taskId);
        if (transfer == null && page.submitted) {
          explicitlyRemoved = true;
        } else if (transfer?.state == DownloadState.canceled) {
          explicitlyCanceled = true;
        } else if (transfer?.state == DownloadState.failed) {
          failure ??= transfer?.error ?? 'Page download failed';
        } else if (transfer?.state == DownloadState.paused &&
            !transfer!.resumeRequested) {
          paused = true;
        }
      }
      if (_transferHandoffChanged(chapter.key, handoffRevision)) continue;
      if (explicitlyCanceled) {
        await store.markErrorForOperation(
          chapter.key,
          chapter.operationGeneration,
          state: OfflineChapterState.canceled,
          error: 'A page transfer was canceled',
        );
        continue;
      }
      if (explicitlyRemoved) {
        await store.markErrorForOperation(
          chapter.key,
          chapter.operationGeneration,
          state: OfflineChapterState.canceled,
          error: 'A page transfer was explicitly removed',
        );
        continue;
      }
      if (failure != null) {
        await store.markErrorForOperation(
          chapter.key,
          chapter.operationGeneration,
          state: OfflineChapterState.failed,
          error: failure,
        );
      } else if (paused) {
        await store.markPausedForOperation(
          chapter.key,
          chapter.operationGeneration,
        );
      }
    }
    _emitChange();
  }

  void _emitChange() {
    if (!_changes.isClosed) _changes.add(null);
  }

  int _beginTransferHandoff(ChapterKey key) {
    final revision = (_transferHandoffRevisions[key] ?? 0) + 1;
    _transferHandoffRevisions[key] = revision;
    _activeTransferHandoffs.add(key);
    return revision;
  }

  void _endTransferHandoff(ChapterKey key, int revision) {
    if (_transferHandoffRevisions[key] == revision) {
      _activeTransferHandoffs.remove(key);
    }
  }

  bool _transferHandoffChanged(ChapterKey key, int revision) =>
      _activeTransferHandoffs.contains(key) ||
      (_transferHandoffRevisions[key] ?? 0) != revision;

  static bool _transferTransportChanged(
    OfflineTransferSnapshot transfer,
    OfflinePage page,
  ) {
    if (transfer.resourceUrl != page.resourceUrl ||
        transfer.headers.length != page.headers.length) {
      return true;
    }
    for (final entry in transfer.headers.entries) {
      if (page.headers[entry.key] != entry.value) return true;
    }
    return false;
  }


  static String _manifestSignature(List<ImageEntity> pages) => sha256
      .convert(
        utf8.encode(
          jsonEncode([
            for (final page in pages)
              imageCacheIdentity(page.imageUrl, page.imageHeaders),
          ]),
        ),
      )
      .toString();

  static String _taskId(ChapterKey key, int generation, int index) => sha256
      .convert(
        utf8.encode(
          jsonEncode({
            'sourceId': key.sourceId,
            'comicId': key.comicId,
            'chapterId': key.chapterId,
            'generation': generation,
            'page': index,
          }),
        ),
      )
      .toString();


  static String _shortHash(String value) =>
      sha256.convert(utf8.encode(value)).toString().substring(0, 24);

  static String _extension(String url) {
    final segments = Uri.tryParse(url)?.pathSegments ?? const <String>[];
    final segment = segments.isEmpty ? '' : segments.last;
    final dot = segment.lastIndexOf('.');
    if (dot < 0) return '.img';
    final extension = segment.substring(dot).toLowerCase();
    return RegExp(r'^\.[a-z0-9]{1,5}$').hasMatch(extension)
        ? extension
        : '.img';
  }

  static int _compareComicVersions(
    OfflineComicVersion left,
    OfflineComicVersion right,
  ) {
    final leftTime =
        left.earliestCompletedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    final rightTime =
        right.earliestCompletedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    final time = leftTime.compareTo(rightTime);
    if (time != 0) return time;
    final source = left.comic.key.sourceId.compareTo(right.comic.key.sourceId);
    if (source != 0) return source;
    return left.comic.key.comicId.compareTo(right.comic.key.comicId);
  }
}
