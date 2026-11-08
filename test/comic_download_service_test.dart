import 'dart:async';

import 'dart:io';

import 'package:dcomic/database/database_common.dart';
import 'package:dcomic/database/database_instance.dart';
import 'package:dcomic/downloads/comic_download_models.dart';
import 'package:dcomic/downloads/comic_download_service.dart';
import 'package:dcomic/downloads/download_models.dart';
import 'package:dcomic/downloads/offline_comic_store.dart';
import 'package:dcomic/providers/models/comic_source_model.dart';
import 'package:dcomic/providers/models/chapter_metadata.dart';
import 'package:dcomic/utils/image_utils.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late DComicDatabase database;
  late _Gateway transfers;
  late OfflineComicStore store;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('comic_download_');
    database = await $FloorDComicDatabase
        .databaseBuilder('${directory.path}/offline.db')
        .addMigrations(DatabaseInstance.migrations)
        .addCallback(DatabaseInstance.databaseCallback)
        .build();
    transfers = _Gateway(Directory('${directory.path}/downloads')..createSync());
    store = OfflineComicStore(dao: database.offlineComicDao, transfers: transfers);
  });

  tearDown(() async {
    await database.close();
    await directory.delete(recursive: true);
  });

  test('selected chapter persists ordered page intents before core submission', () async {
    final source = _Source('source');
    final detail = _Detail(source, const [
      _RemoteChapter('chapter', [
        ('https://images/second', {'Referer': 'reader'}),
        ('https://images/first', null),
      ]),
    ]);
    final service = ComicDownloadService(store: store, transfers: transfers);

    await service.downloadChapters(detail, const ['chapter']);

    final manifest = await store.loadManifest(
      (sourceId: 'source', comicId: 'comic', chapterId: 'chapter'),
    );
    expect(manifest, isNotNull);
    expect(manifest!.chapter.pages.map((page) => page.index), [0, 1]);
    expect(manifest.chapter.pages.map((page) => page.resourceUrl), [
      'https://images/second',
      'https://images/first',
    ]);
    expect(transfers.requests, hasLength(2));
    expect(transfers.requests.first.strategy, TransferStrategy.single);
    expect(transfers.requests.first.headers, {'Referer': 'reader'});
    expect(
      transfers.requests.first.cacheKey,
      imageCacheIdentity(
        'https://images/second',
        const {'Referer': 'reader'},
      ),
    );
  });

  test('remote parse failure remains a retryable failed intent and never readable', () async {
    final source = _Source('source');
    final detail = _Detail(source, const [], chapterError: StateError('expired'));
    final service = ComicDownloadService(store: store, transfers: transfers);

    await expectLater(
      service.downloadChapters(detail, const ['chapter']),
      throwsStateError,
    );

    final manifest = await store.loadManifest(
      (sourceId: 'source', comicId: 'comic', chapterId: 'chapter'),
    );
    expect(manifest, isNotNull);
    expect(manifest!.chapter.state, OfflineChapterState.failed);
    expect(manifest.chapter.pages, isEmpty);
    expect(await store.listReadableChapters(
      (sourceId: 'source', comicId: 'comic')),
      isEmpty,
    );
  });

  test('resume refreshes changed signed URLs as a new generation', () async {
    final source = _Source('source');
    final first = _Detail(source, const [
      _RemoteChapter('chapter', [('https://images/old-token', null)]),
    ]);
    final refreshed = _Detail(source, const [
      _RemoteChapter('chapter', [('https://images/new-token', null)]),
    ]);
    source.detail = refreshed;
    final service = ComicDownloadService(
      store: store,
      transfers: transfers,
      sourceLookup: (sourceId) async => sourceId == 'source' ? source : null,
    );
    await service.downloadChapters(first, const ['chapter']);
    final before = await store.loadManifest(
      (sourceId: 'source', comicId: 'comic', chapterId: 'chapter'),
    );

    await service.resumeChapter(
      (sourceId: 'source', comicId: 'comic', chapterId: 'chapter'),
    );

    final after = await store.loadManifest(
      (sourceId: 'source', comicId: 'comic', chapterId: 'chapter'),
    );
    expect(after!.chapter.manifestGeneration,
        before!.chapter.manifestGeneration + 1);
    expect(after.chapter.pages.single.resourceUrl, 'https://images/new-token');
    expect(transfers.canceled, contains(before.chapter.pages.single.taskId));
    expect(
      after.chapter.pages.single.taskId,
      isNot(before.chapter.pages.single.taskId),
    );
  });
  test('manifest refresh retains downloaded chapter attribution', () async {
    const groups = [ScanlationGroup('actual-group', 'Actual Group')];
    final source = _Source('source');
    final initial = _Detail(
      source,
      const [
        _RemoteChapter('chapter', [('https://images/stable', null)]),
      ],
      chapterLanguage: 'zh',
      scanlationGroups: groups,
    );
    final refreshed = _Detail(
      source,
      const [
        _RemoteChapter('chapter', [('https://images/refreshed', null)]),
      ],
    );
    source.detail = refreshed;
    final service = ComicDownloadService(
      store: store,
      transfers: transfers,
      sourceLookup: (_) async => source,
    );
    const key = (
      sourceId: 'source',
      comicId: 'comic',
      chapterId: 'chapter',
    );
    await service.downloadChapters(initial, const ['chapter']);
    await service.pauseChapter(key);

    await service.resumeChapter(key);

    final chapter = (await store.loadManifest(key))!.chapter;
    expect(chapter.language, 'zh');
    expect(
      chapter.scanlationGroups.map((group) => (group.id, group.name)),
      [('actual-group', 'Actual Group')],
    );
  });
  test('resume finds a downloaded UUID in the full source catalog', () async {
    const groups = [ScanlationGroup('old-group', 'Old Group')];
    final source = _Source('source');
    final initial = _Detail(
      source,
      const [
        _RemoteChapter('old-uuid', [('https://images/old-version', null)]),
      ],
      visibleChapterId: 'old-uuid',
      catalogChapterIds: const ['old-uuid'],
      chapterLanguage: 'zh',
      scanlationGroups: groups,
    );
    final refreshed = _Detail(
      source,
      const [
        _RemoteChapter('old-uuid', [('https://images/old-version', null)]),
      ],
      visibleChapterId: 'new-uuid',
      catalogChapterIds: const ['old-uuid', 'new-uuid'],
    );
    source.detail = refreshed;
    final service = ComicDownloadService(
      store: store,
      transfers: transfers,
      sourceLookup: (_) async => source,
    );
    const key = (
      sourceId: 'source',
      comicId: 'comic',
      chapterId: 'old-uuid',
    );
    await service.downloadChapters(initial, const ['old-uuid']);
    await service.pauseChapter(key);

    await service.resumeChapter(key);

    final chapter = (await store.loadManifest(key))!.chapter;
    expect(chapter.key.chapterId, 'old-uuid');
    expect(chapter.language, 'zh');
    expect(chapter.scanlationGroups.map((group) => group.id), ['old-group']);
  });
  test('unchanged transport resumes native bytes without replacing the task',
      () async {
    final source = _Source('source');
    final initial = _Detail(source, const [
      _RemoteChapter('chapter', [
        ('https://images/stable-1', null),
        ('https://images/stable-2', null),
      ]),
    ]);
    source.detail = _Detail(source, const [
      _RemoteChapter('chapter', [
        ('https://images/stable-1', null),
        ('https://images/stable-2', null),
      ]),
    ]);
    final service = ComicDownloadService(
      store: store,
      transfers: transfers,
      sourceLookup: (_) async => source,
    );
    const key = (
      sourceId: 'source',
      comicId: 'comic',
      chapterId: 'chapter',
    );
    await service.downloadChapters(initial, const ['chapter']);
    final taskIds = transfers.requests.map((request) => request.id).toList();
    await service.pauseChapter(key);
    transfers
      ..keepPausedOnResume = true
      ..onChanged = service.reconcile;

    await service.resumeChapter(key);
    expect(
      (await store.loadManifest(key))!.chapter.state,
      OfflineChapterState.downloading,
    );

    expect(transfers.requests, hasLength(2));
    expect(transfers.removed, isEmpty);
    expect(transfers.resumed, containsAll(taskIds));
  });
  test('in-flight reconciliation cannot apply pre-handoff transfer state',
      () async {
    final source = _Source('source');
    final initial = _Detail(source, const [
      _RemoteChapter('chapter', [('https://images/stable', null)]),
    ]);
    source.detail = _Detail(source, const [
      _RemoteChapter('chapter', [('https://images/stable', null)]),
    ]);
    final service = ComicDownloadService(
      store: store,
      transfers: transfers,
      sourceLookup: (_) async => source,
    );
    const key = (
      sourceId: 'source',
      comicId: 'comic',
      chapterId: 'chapter',
    );
    await service.downloadChapters(initial, const ['chapter']);
    await service.pauseChapter(key);
    transfers
      ..keepPausedOnResume = true
      ..blockNextGet = true
      ..getGate = Completer<void>()
      ..getEntered = Completer<void>();

    final reconciliation = service.reconcile();
    await transfers.getEntered!.future;
    await service.resumeChapter(key);
    transfers.getGate!.complete();
    await reconciliation;

    expect(
      (await store.loadManifest(key))!.chapter.state,
      OfflineChapterState.downloading,
    );
  });









  test('cancel during remote resolution fences late manifest publication',
      () async {
    final source = _Source('source');
    final detail = _Detail(source, const [
      _RemoteChapter('chapter', [('https://images/late', null)]),
    ])..chapterGate = Completer<void>();
    final service = ComicDownloadService(store: store, transfers: transfers);
    final key = (
      sourceId: 'source',
      comicId: 'comic',
      chapterId: 'chapter',
    );

    final downloading = service.downloadChapters(detail, const ['chapter']);
    while (await store.loadManifest(key) == null) {
      await Future<void>.delayed(Duration.zero);
    }
    await service.cancelChapter(key);
    detail.chapterGate!.complete();
    await downloading;

    expect((await store.loadManifest(key))!.chapter.state,
        OfflineChapterState.canceled);
    expect(transfers.requests, isEmpty);
  });

  test('retry recreates a completed transfer whose durable file disappeared',
      () async {
    final source = _Source('source');
    final detail = _Detail(source, const [
      _RemoteChapter('chapter', [('https://images/stable', null)]),
    ]);
    source.detail = detail;
    final service = ComicDownloadService(
      store: store,
      transfers: transfers,
      sourceLookup: (_) async => source,
    );
    const key = (
      sourceId: 'source',
      comicId: 'comic',
      chapterId: 'chapter',
    );
    await service.downloadChapters(detail, const ['chapter']);
    final request = transfers.requests.single;
    await transfers.complete(request);
    expect(await store.commitIfComplete(key, generation: 1), isTrue);
    await File('${transfers.root.path}/${request.relativePath}').delete();
    expect(await store.listReadableChapters(
      (sourceId: 'source', comicId: 'comic')), isEmpty);

    await service.resumeChapter(key);

    expect(transfers.requests.where((item) => item.id == request.id), hasLength(2));
  });

  test('task queries retain zero-page failures and map page task ownership',
      () async {
    final service = ComicDownloadService(store: store, transfers: transfers);
    const key = (
      sourceId: 'source',
      comicId: 'comic',
      chapterId: 'chapter',
    );
    const comic = OfflineComicSnapshot(
      key: (sourceId: 'source', comicId: 'comic'),
      rawTitle: 'Comic',
      isLongComic: false,
    );
    await store.saveManifest(
      OfflineManifest(
        comic: comic,
        chapter: OfflineChapterSnapshot(
          key: key,
          rawTitle: 'Chapter',
          groupName: 'Main',
          sortIndex: 0,
          manifestGeneration: 1,
          manifestSignature: '',
          state: OfflineChapterState.failed,
          error: 'manifest refresh required',
        ),
      ),
    );
    final tasks = await service.listIncompleteChapterTasks();
    expect(tasks.single.chapter.key, key);
    expect(tasks.single.progress.totalPages, 0);
    expect(tasks.single.progress.error, 'manifest refresh required');

    await store.saveManifest(
      OfflineManifest(
        comic: comic,
        chapter: OfflineChapterSnapshot(
          key: key,
          rawTitle: 'Chapter',
          groupName: 'Main',
          sortIndex: 0,
          manifestGeneration: 2,
          manifestSignature: 'page',
          state: OfflineChapterState.downloading,
          pages: [
            OfflinePage(
              index: 0,
              taskId: 'owned-task',
              relativePath: 'comic/owned.jpg',
              resourceUrl: 'https://images/owned',
              submitted: true,
            ),
          ],
        ),
      ),
    );
    expect(await service.chapterForTask('owned-task'), key);
    expect(await service.chapterForTask('unknown'), isNull);
    transfers.snapshots['owned-task'] = const OfflineTransferSnapshot(
      id: 'owned-task',
      state: DownloadState.canceled,
      resourceUrl: 'https://images/owned',
    );
    await service.reconcile();
    expect(
      (await store.loadManifest(key))!.chapter.state,
      OfflineChapterState.canceled,
    );
  });
  test('cache-fast completion is preserved during post-submit reconciliation',
      () async {
    final source = _Source('source');
    final detail = _Detail(source, const [
      _RemoteChapter('chapter', [('https://images/cached', null)]),
    ]);
    final service = ComicDownloadService(store: store, transfers: transfers);
    transfers
      ..completeOnSubmit = true
      ..onChanged = service.reconcile;

    await service.downloadChapters(detail, const ['chapter']);

    expect(
      await store.listReadableChapters(
        (sourceId: 'source', comicId: 'comic'),
      ),
      hasLength(1),
    );
    expect(transfers.removed, isEmpty);
  });

  test('unrelated transfer reconciliation does not abort a resolving refresh',
      () async {
    final source = _Source('source');
    final initial = _Detail(source, const [
      _RemoteChapter('chapter', [('https://images/original', null)]),
    ]);
    final service = ComicDownloadService(
      store: store,
      transfers: transfers,
      sourceLookup: (_) async => source,
    );
    final key = (sourceId: 'source', comicId: 'comic', chapterId: 'chapter');
    await service.downloadChapters(initial, const ['chapter']);
    await service.pauseChapter(key);

    final refreshed = _Detail(source, const [
      _RemoteChapter('chapter', [('https://images/original', null)]),
    ])..chapterGate = Completer<void>();
    source.detail = refreshed;
    final resume = service.resumeChapter(key);
    await refreshed.chapterEntered.future;

    await service.reconcile();
    expect(
      (await store.loadManifest(key))!.chapter.state,
      OfflineChapterState.resolving,
    );

    refreshed.chapterGate!.complete();
    await resume;
    expect(
      (await store.loadManifest(key))!.chapter.state,
      OfflineChapterState.downloading,
    );
  });

  test('missing-file repair remove event does not self-cancel replacement',
      () async {
    final source = _Source('source');
    final detail = _Detail(source, const [
      _RemoteChapter('chapter', [('https://images/repair', null)]),
    ]);
    source.detail = detail;
    final service = ComicDownloadService(
      store: store,
      transfers: transfers,
      sourceLookup: (_) async => source,
    );
    final key = (sourceId: 'source', comicId: 'comic', chapterId: 'chapter');
    await service.downloadChapters(detail, const ['chapter']);
    final manifest = (await store.loadManifest(key))!;
    await store.setChapterState(
      key,
      generation: manifest.chapter.manifestGeneration,
      state: OfflineChapterState.failed,
      error: 'retry',
    );
    final taskId = manifest.chapter.pages.single.taskId;
    transfers.snapshots[taskId] = OfflineTransferSnapshot(
      id: taskId,
      state: DownloadState.completed,
      bytesReceived: 3,
      totalBytes: 3,
      resourceUrl: 'https://images/repair',
    );
    transfers.onChanged = service.reconcile;

    await service.resumeChapter(key);

    expect(
      (await store.loadManifest(key))!.chapter.state,
      OfflineChapterState.downloading,
    );
    expect(transfers.requests, hasLength(2));
  });

  test('deleted pending request cannot publish into recreated chapter', () async {
    final source = _Source('source');
    final service = ComicDownloadService(store: store, transfers: transfers);
    final key = (sourceId: 'source', comicId: 'comic', chapterId: 'chapter');
    final oldDetail = _Detail(source, const [
      _RemoteChapter('chapter', [('https://images/old', null)]),
    ])..chapterGate = Completer<void>();
    final oldDownload = service.downloadChapters(oldDetail, const ['chapter']);
    await oldDetail.chapterEntered.future;
    final oldOperation =
        (await store.loadManifest(key))!.chapter.operationGeneration;
    await service.removeChapter(key);

    final newDetail = _Detail(source, const [
      _RemoteChapter('chapter', [('https://images/new', null)]),
    ])..chapterGate = Completer<void>();
    final newDownload = service.downloadChapters(newDetail, const ['chapter']);
    await newDetail.chapterEntered.future;
    final newOperation =
        (await store.loadManifest(key))!.chapter.operationGeneration;
    expect(newOperation, isNot(oldOperation));

    oldDetail.chapterGate!.complete();
    await oldDownload;
    expect(
      (await store.loadManifest(key))!.chapter.operationGeneration,
      newOperation,
    );

    newDetail.chapterGate!.complete();
    await newDownload;
    expect(
      (await store.loadManifest(key))!.chapter.pages.single.resourceUrl,
      'https://images/new',
    );
  });

  test('submitting the same manifest twice reuses stable core task ids', () async {
    final source = _Source('source');
    final detail = _Detail(source, const [
      _RemoteChapter('chapter', [('https://images/stable', null)]),
    ]);
    final service = ComicDownloadService(store: store, transfers: transfers);

    await service.downloadChapters(detail, const ['chapter']);
    final firstId = transfers.requests.single.id;
    await service.downloadChapters(detail, const ['chapter']);

    expect(transfers.requests.map((request) => request.id).toSet(), {firstId});
  });
}

class _RemoteChapter {
  const _RemoteChapter(this.id, this.pages);
  final String id;
  final List<(String, Map<String, String>?)> pages;
}

class _ChapterDetail extends Fake implements BaseComicChapterDetailModel {
  _ChapterDetail(this.data);
  final _RemoteChapter data;
  @override
  ChapterProvenance? get provenance => null;
  @override
  String get chapterId => data.id;
  @override
  String get title => data.id;
  @override
  List<ImageEntity> get pages => [
        for (final page in data.pages)
          ImageEntity(ImageType.network, page.$1, imageHeaders: page.$2),
      ];
}

class _Detail extends Fake implements BaseComicDetailModel {
  _Detail(
    this.parent,
    this.remote, {
    this.chapterError,
    this.chapterLanguage,
    this.scanlationGroups = const [],
    this.visibleChapterId = 'chapter',
    this.catalogChapterIds,
  });
  final List<_RemoteChapter> remote;
  final Object? chapterError;
  final String? chapterLanguage;
  final List<ScanlationGroup> scanlationGroups;
  final String visibleChapterId;
  final List<String>? catalogChapterIds;
  bool disposed = false;
  Completer<void>? chapterGate;
  final Completer<void> chapterEntered = Completer<void>();
  @override
  final BaseComicSourceModel parent;
  @override
  String get comicId => 'comic';
  @override
  String get rawTitle => 'Comic';
  @override
  String get title => rawTitle;
  @override
  ImageEntity get cover => ImageEntity(ImageType.network, 'https://cover');
  @override
  bool get isLongComic => false;
  @override
  Map<String, List<BaseComicChapterEntityModel>> get chapters => {
        'Main': [_chapter(visibleChapterId)],
      };

  @override
  Map<String, List<BaseComicChapterEntityModel>> get chapterCatalog => {
        'Main': [
          for (final chapterId in catalogChapterIds ?? [visibleChapterId])
            _chapter(chapterId),
        ],
      };

  BaseComicChapterEntityModel _chapter(String chapterId) =>
      DefaultComicChapterEntityModel(
        'Chapter',
        chapterId,
        DateTime(2026),
        language: chapterLanguage,
        scanlationGroups: scanlationGroups,
      );

  @override
  void dispose() {
    disposed = true;
  }

  @override
  Future<BaseComicChapterDetailModel?> fetchRemoteChapter(String chapterId) async {
    if (!chapterEntered.isCompleted) chapterEntered.complete();
    await chapterGate?.future;
    if (chapterError case final error?) throw error;
    for (final chapter in remote) {
      if (chapter.id == chapterId) return _ChapterDetail(chapter);
    }
    return null;
  }
}

class _Source extends Fake implements BaseComicSourceModel {
  _Source(this.sourceId);
  final String sourceId;
  BaseComicDetailModel? detail;
  Completer<void>? detailGate;
  final Completer<void> detailEntered = Completer<void>();
  @override
  ComicSourceEntity get type => ComicSourceEntity(sourceId, sourceId);
  @override
  Future<BaseComicDetailModel?> getComicDetail(
    String comicId,
    String title,
  ) async {
    if (!detailEntered.isCompleted) detailEntered.complete();
    await detailGate?.future;
    return detail;
  }
}

class _Gateway implements OfflineDownloadGateway {
  _Gateway(this.root);
  final Directory root;
  final List<DownloadRequest> requests = [];
  final Set<String> canceled = {};
  final Map<String, OfflineTransferSnapshot> snapshots = {};
  final Set<String> removed = {};
  final Set<String> resumed = {};
  Future<void> Function()? onChanged;
  bool completeOnSubmit = false;
  bool emitCanceledBeforeRemove = false;
  bool keepPausedOnResume = false;
  bool blockNextGet = false;
  Completer<void>? getGate;
  Completer<void>? getEntered;

  Future<void> complete(DownloadRequest request) async {
    final file = File('${root.path}/${request.relativePath}');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(const [1, 2, 3]);
    snapshots[request.id] = OfflineTransferSnapshot(
      id: request.id,
      state: DownloadState.completed,
      bytesReceived: 3,
      totalBytes: 3,
      resourceUrl: request.url.toString(),
      headers: request.headers,
    );
  }

  @override
  Future<String> submit(DownloadRequest request) async {
    requests.add(request);
    snapshots.putIfAbsent(
      request.id,
      () => OfflineTransferSnapshot(
        id: request.id,
        state: DownloadState.queued,
        resourceUrl: request.url.toString(),
        headers: request.headers,
      ),
    );
    if (completeOnSubmit) {
      await complete(request);
    }
    await onChanged?.call();
    return request.id;
  }

  @override
  Future<void> cancel(String id) async {
    canceled.add(id);
    final previous = snapshots[id]!;
    snapshots[id] = OfflineTransferSnapshot(
      id: id,
      state: DownloadState.canceled,
      resourceUrl: previous.resourceUrl,
      headers: previous.headers,
    );
    await onChanged?.call();
  }

  @override
  Future<Directory> get rootDirectory async => root;
  @override
  Future<OfflineTransferSnapshot?> get(String id) async {
    final snapshot = snapshots[id];
    if (blockNextGet) {
      blockNextGet = false;
      getEntered?.complete();
      await getGate?.future;
    }
    return snapshot;
  }
  @override
  Stream<List<OfflineTransferSnapshot>> watch() => const Stream.empty();
  @override
  Future<File?> completedFile(String id) async => null;
  @override
  Future<void> pause(String id) async {
    final previous = snapshots[id]!;
    snapshots[id] = OfflineTransferSnapshot(
      id: id,
      state: DownloadState.paused,
      resourceUrl: previous.resourceUrl,
      headers: previous.headers,
    );
    await onChanged?.call();
  }
  @override
  Future<void> resume(String id) async {
    resumed.add(id);
    final previous = snapshots[id]!;
    snapshots[id] = OfflineTransferSnapshot(
      id: id,
      state: keepPausedOnResume ? DownloadState.paused : DownloadState.queued,
      resourceUrl: previous.resourceUrl,
      headers: previous.headers,
      resumeRequested: keepPausedOnResume,
    );
    await onChanged?.call();
  }
  @override
  Future<void> remove(String id) async {
    removed.add(id);
    final previous = snapshots[id];
    if (emitCanceledBeforeRemove && previous != null) {
      snapshots[id] = OfflineTransferSnapshot(
        id: id,
        state: DownloadState.canceled,
        resourceUrl: previous.resourceUrl,
        headers: previous.headers,
      );
      await onChanged?.call();
    }
    snapshots.remove(id);
    await onChanged?.call();
  }
}
