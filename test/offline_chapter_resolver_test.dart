import 'dart:io';

import 'package:dcomic/database/database_common.dart';
import 'package:dcomic/database/database_instance.dart';
import 'package:dcomic/database/entity/comic_mapping.dart';
import 'package:dcomic/downloads/comic_download_models.dart';
import 'package:dcomic/downloads/download_models.dart';
import 'package:dcomic/downloads/offline_chapter_resolver.dart';
import 'package:dcomic/downloads/offline_comic_store.dart';
import 'package:dcomic/providers/models/comic_source_model.dart';
import 'package:dcomic/providers/models/chapter_metadata.dart';
import 'package:dcomic/providers/models/offline_comic_model.dart';
import 'package:dcomic/utils/image_utils.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late Directory downloads;
  late DComicDatabase database;
  late _Gateway transfers;
  late OfflineComicStore store;
  var aggregate = true;
  var reuse = true;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('offline_resolver_');
    downloads = Directory('${directory.path}/downloads')..createSync();
    database = await $FloorDComicDatabase
        .databaseBuilder('${directory.path}/offline.db')
        .addMigrations(DatabaseInstance.migrations)
        .addCallback(DatabaseInstance.databaseCallback)
        .build();
    transfers = _Gateway(downloads);
    store = OfflineComicStore(dao: database.offlineComicDao, transfers: transfers);
    aggregate = true;
    reuse = true;
  });

  tearDown(() async {
    BaseComicDetailModel.clearOfflineResolverForTest();
    await database.close();
    await directory.delete(recursive: true);
  });

  OfflineChapterResolver resolver() => OfflineChapterResolver(
        store: store,
        mappingLoader: database.comicMappingDao.getAllComicMappingEntity,
        ruleLoader: database.chapterRuleDao.loadChapterRules,
        aggregateDownloads: () => aggregate,
        reuseAcrossSources: () => reuse,
      );

  Future<void> bind(String aSource, String aComic, String bSource, String bComic) =>
      database.comicMappingDao.insertComicMapping(
        ComicMappingEntity.between(aSource, aComic, bSource, bComic),
      );

  Future<void> complete({
    required String source,
    required String comic,
    required String chapter,
    required String title,
    int sort = 0,
    List<(String, String)>? catalog,
    String? language,
    List<ScanlationGroup> scanlationGroups = const [],
  }) async {
    final task = '$source-$comic-$chapter';
    final path = '$source/$comic/$chapter.jpg';
    await store.saveManifest(
      OfflineManifest(
        comic: OfflineComicSnapshot(
          key: (sourceId: source, comicId: comic),
          rawTitle: 'Book $source',
          remoteCoverUrl: 'https://cover/$source',
          isLongComic: false,
          catalog: [
            for (final item in catalog ?? [(chapter, title)])
              OfflineCatalogChapter(
                chapterId: item.$1,
                rawTitle: item.$2,
                groupName: 'Main',
                language: language,
                scanlationGroups: scanlationGroups,
              ),
          ],
        ),
        chapter: OfflineChapterSnapshot(
          key: (sourceId: source, comicId: comic, chapterId: chapter),
          rawTitle: title,
          groupName: 'Main',
          language: language,
          scanlationGroups: scanlationGroups,
          sortIndex: sort,
          manifestGeneration: 1,
          manifestSignature: task,
          state: OfflineChapterState.downloading,
          pages: [
            OfflinePage(
              index: 0,
              taskId: task,
              relativePath: path,
              resourceUrl: 'https://image/$task',
              expectedBytes: 1,
            ),
          ],
        ),
      ),
    );
    await transfers.complete(task, path);
    expect(
      await store.commitIfComplete(
        (sourceId: source, comicId: comic, chapterId: chapter),
        generation: 1,
      ),
      isTrue,
    );
  }

  test('own-source complete chapter always wins over mapped alternatives', () async {
    await bind('a', 'book-a', 'b', 'book-b');
    await complete(
      source: 'b', comic: 'book-b', chapter: 'b-1', title: 'Chapter 1');
    await complete(
      source: 'a', comic: 'book-a', chapter: 'a-1', title: '第1话');
    final detail = _Detail('a', 'book-a', 'a-1', '第1话');

    final resolved = await resolver().resolve(detail, 'a-1');

    expect(resolved, isNotNull);
    expect(resolved!.chapterId, 'a-1');
    expect(resolved.provenance!.requested,
        (sourceId: 'a', comicId: 'book-a', chapterId: 'a-1'));
    expect(resolved.provenance!.actual,
        (sourceId: 'a', comicId: 'book-a', chapterId: 'a-1'));
    expect(resolved.pages.single.imageType, ImageType.local);
  });
  test('own downloaded UUID remains resolvable from the full source catalog',
      () async {
    await complete(
      source: 'a',
      comic: 'book-a',
      chapter: 'old-uuid',
      title: '第1话',
    );
    final detail = _Detail(
      'a',
      'book-a',
      'old-uuid',
      '第1话',
      visibleChapterId: 'new-uuid',
      catalogChapterIds: const ['old-uuid', 'new-uuid'],
    );

    final resolved = await resolver().resolve(detail, 'old-uuid');

    expect(resolved, isNotNull);
    expect(resolved!.provenance!.actual.chapterId, 'old-uuid');
  });


  test('mapped alternatives require both settings and choose earliest completion', () async {
    await bind('a', 'book-a', 'b', 'book-b');
    await bind('a', 'book-a', 'c', 'book-c');
    await complete(
      source: 'b', comic: 'book-b', chapter: 'b-1', title: 'Chapter 001');
    await Future<void>.delayed(const Duration(milliseconds: 2));
    await complete(
      source: 'c', comic: 'book-c', chapter: 'c-1', title: '1话');
    final detail = _Detail('a', 'book-a', 'a-1', '第1话');

    final resolved = await resolver().resolve(detail, 'a-1');
    expect(resolved!.chapterId, 'a-1');
    expect(resolved.provenance!.actual.sourceId, 'b');

    reuse = false;
    expect(await resolver().resolve(detail, 'a-1'), isNull);
    reuse = true;
    aggregate = false;
    expect(await resolver().resolve(detail, 'a-1'), isNull);
  });

  test('mapped fallback exposes actual downloaded attribution', () async {
    const actualGroups = [
      ScanlationGroup('actual-group', 'Actual Scanlation'),
    ];
    const requestedGroups = [
      ScanlationGroup('requested-group', 'Requested Scanlation'),
    ];
    await bind('a', 'book-a', 'b', 'book-b');
    await complete(
      source: 'b',
      comic: 'book-b',
      chapter: 'b-1',
      title: 'Chapter 1',
      language: 'zh-hk',
      scanlationGroups: actualGroups,
    );
    final detail = _Detail(
      'a',
      'book-a',
      'a-1',
      '第1话',
      language: 'en',
      scanlationGroups: requestedGroups,
    );

    final resolved = (await resolver().resolve(detail, 'a-1'))!;

    expect(resolved.language, 'zh-hk');
    expect(
      resolved.scanlationGroups.map((group) => (group.id, group.name)),
      [('actual-group', 'Actual Scanlation')],
    );
    expect(
      resolved.scanlationGroups.map((group) => group.id),
      isNot(contains('requested-group')),
    );
    expect(resolved.provenance!.actual.sourceId, 'b');
    final offline = await OfflineComicDetailModel.fromStore(
      store: store,
      comicKey: (sourceId: 'b', comicId: 'book-b'),
    );
    final offlineChapter = offline.chapters.values.single.single;
    expect(offlineChapter.language, 'zh-hk');
    expect(
      offlineChapter.scanlationGroups.map((group) => (group.id, group.name)),
      [('actual-group', 'Actual Scanlation')],
    );
  });

  test('ambiguous matching in a mapped source never auto-reuses a version', () async {
    await bind('a', 'book-a', 'b', 'book-b');
    const catalog = [
      ('b-1', 'Chapter 1'),
      ('b-other', '1话'),
    ];
    await complete(
      source: 'b',
      comic: 'book-b',
      chapter: 'b-1',
      title: 'Chapter 1',
      catalog: catalog,
    );

    expect(
      await resolver().resolve(_Detail('a', 'book-a', 'a-1', '第1话'), 'a-1'),
      isNull,
    );
  });

  test('explicit offline detail stays pinned when its selected files disappear',
      () async {
    await bind('a', 'book-a', 'b', 'book-b');
    await complete(
      source: 'a', comic: 'book-a', chapter: 'a-1', title: '第1话');
    await complete(
      source: 'b', comic: 'book-b', chapter: 'b-1', title: 'Chapter 1');
    final detail = await OfflineComicDetailModel.fromStore(
      store: store,
      comicKey: (sourceId: 'b', comicId: 'book-b'),
    );
    await File('${downloads.path}/b/book-b/b-1.jpg').delete();

    expect(await resolver().resolve(detail, 'b-1'), isNull);
    await expectLater(
      detail.fetchRemoteChapter('b-1'),
      throwsA(isA<OfflineChapterMissingException>()),
    );
  });
}

class _Detail extends Fake implements BaseComicDetailModel {
  _Detail(
    String source,
    this.comicId,
    String chapterId,
    String chapterTitle, {
    String? language,
    List<ScanlationGroup> scanlationGroups = const [],
    String? visibleChapterId,
    List<String>? catalogChapterIds,
  })  : parent = _Source(source),
        chapters = {
          'Main': [
            _chapter(
              visibleChapterId ?? chapterId,
              chapterTitle,
              language,
              scanlationGroups,
            ),
          ],
        },
        chapterCatalog = {
          'Main': [
            for (final catalogChapterId
                in catalogChapterIds ?? <String>[chapterId])
              _chapter(
                catalogChapterId,
                chapterTitle,
                language,
                scanlationGroups,
              ),
          ],
        };

  @override
  final String comicId;
  @override
  final BaseComicSourceModel parent;
  @override
  final Map<String, List<BaseComicChapterEntityModel>> chapters;
  @override
  final Map<String, List<BaseComicChapterEntityModel>> chapterCatalog;

  static BaseComicChapterEntityModel _chapter(
    String chapterId,
    String chapterTitle,
    String? language,
    List<ScanlationGroup> scanlationGroups,
  ) =>
      DefaultComicChapterEntityModel(
        chapterTitle,
        chapterId,
        DateTime(2026),
        language: language,
        scanlationGroups: scanlationGroups,
      );
}

class _Source extends Fake implements BaseComicSourceModel {
  _Source(this.sourceId);
  final String sourceId;
  @override
  ComicSourceEntity get type => ComicSourceEntity(sourceId, sourceId);
}

class _Gateway implements OfflineDownloadGateway {
  _Gateway(this.root);
  final Directory root;
  final Map<String, OfflineTransferSnapshot> snapshots = {};

  Future<void> complete(String id, String path) async {
    final file = File('${root.path}/$path');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(const [1]);
    snapshots[id] = OfflineTransferSnapshot(
      id: id,
      state: DownloadState.completed,
      resourceUrl: 'https://offline.invalid/$id',
    );
  }

  @override
  Future<Directory> get rootDirectory async => root;
  @override
  Future<OfflineTransferSnapshot?> get(String id) async => snapshots[id];
  @override
  Stream<List<OfflineTransferSnapshot>> watch() => const Stream.empty();
  @override
  Future<File?> completedFile(String id) async => null;
  @override
  Future<String> submit(DownloadRequest request) => throw UnimplementedError();
  @override
  Future<void> pause(String id) => throw UnimplementedError();
  @override
  Future<void> resume(String id) => throw UnimplementedError();
  @override
  Future<void> cancel(String id) => throw UnimplementedError();
  @override
  Future<void> remove(String id) => throw UnimplementedError();
}
