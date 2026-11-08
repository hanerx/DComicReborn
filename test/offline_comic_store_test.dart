import 'dart:io';

import 'package:dcomic/database/database_common.dart';
import 'package:dcomic/database/database_instance.dart';
import 'package:dcomic/downloads/comic_download_models.dart';
import 'package:dcomic/downloads/download_models.dart';
import 'package:dcomic/downloads/offline_comic_store.dart';
import 'package:dcomic/providers/models/chapter_metadata.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late Directory downloads;
  late DComicDatabase database;
  late _TransferGateway transfers;
  late OfflineComicStore store;

  const comic = (sourceId: 'copymanga', comicId: 'book');
  const chapter = (
    sourceId: 'copymanga',
    comicId: 'book',
    chapterId: 'chapter-1',
  );

  OfflineManifest manifest(int generation, {List<String>? urls}) {
    final resources = urls ?? const ['https://img/0', 'https://img/1', 'https://img/2'];
    return OfflineManifest(
      comic: const OfflineComicSnapshot(
        key: comic,
        rawTitle: 'Book',
        remoteCoverUrl: 'https://img/cover',
        isLongComic: false,
      ),
      chapter: OfflineChapterSnapshot(
        key: chapter,
        rawTitle: 'Chapter 1',
        groupName: 'Main',
        sortIndex: 0,
        manifestGeneration: generation,
        manifestSignature: 'signature-$generation',
        state: OfflineChapterState.downloading,
        pages: [
          for (var index = 0; index < resources.length; index++)
            OfflinePage(
              index: index,
              taskId: 'page-$generation-$index',
              relativePath: 'comic/$generation/$index.jpg',
              resourceUrl: resources[index],
              headers: const {'Referer': 'https://reader/'},
              expectedBytes: 1,
            ),
        ],
      ),
    );
  }

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('offline_store_');
    downloads = Directory('${directory.path}/downloads')..createSync();
    database = await $FloorDComicDatabase
        .databaseBuilder('${directory.path}/offline.db')
        .addMigrations(DatabaseInstance.migrations)
        .addCallback(DatabaseInstance.databaseCallback)
        .build();
    transfers = _TransferGateway(downloads);
    store = OfflineComicStore(
      dao: database.offlineComicDao,
      transfers: transfers,
    );
  });

  tearDown(() async {
    await database.close();
    await directory.delete(recursive: true);
  });

  test('a chapter becomes readable only after every persisted page completes', () async {
    await store.saveManifest(manifest(1));
    await transfers.complete('page-1-0', 'comic/1/0.jpg');
    await transfers.complete('page-1-1', 'comic/1/1.jpg');

    expect(await store.commitIfComplete(chapter, generation: 1), isFalse);
    expect(await store.listReadableChapters(comic), isEmpty);

    await transfers.complete('page-1-2', 'comic/1/2.jpg');
    expect(await store.commitIfComplete(chapter, generation: 1), isTrue);
    expect((await store.listReadableChapters(comic)).single.key.chapterId, 'chapter-1');

    expect(await store.commitIfComplete(chapter, generation: 1), isTrue);
    expect(await store.listReadableChapters(comic), hasLength(1));
  });

  test('chapter attribution survives catalog persistence and snapshot copies',
      () async {
    const groups = [
      ScanlationGroup('group-a', 'Group A'),
      ScanlationGroup('group-b', 'Group B'),
    ];
    final attributed = manifest(1);
    await store.saveManifest(
      OfflineManifest(
        comic: OfflineComicSnapshot(
          key: attributed.comic.key,
          rawTitle: attributed.comic.rawTitle,
          remoteCoverUrl: attributed.comic.remoteCoverUrl,
          isLongComic: attributed.comic.isLongComic,
          catalog: const [
            OfflineCatalogChapter(
              chapterId: 'chapter-1',
              rawTitle: 'Chapter 1',
              groupName: 'Main',
              language: 'zh-hk',
              scanlationGroups: groups,
            ),
          ],
        ),
        chapter: OfflineChapterSnapshot(
          key: attributed.chapter.key,
          rawTitle: attributed.chapter.rawTitle,
          groupName: attributed.chapter.groupName,
          sortIndex: attributed.chapter.sortIndex,
          language: 'zh-hk',
          scanlationGroups: groups,
          manifestGeneration: attributed.chapter.manifestGeneration,
          manifestSignature: attributed.chapter.manifestSignature,
          state: attributed.chapter.state,
          pages: attributed.chapter.pages,
        ),
      ),
    );

    final loaded = (await store.loadManifest(chapter))!;

    expect(loaded.comic.catalog.single.language, 'zh-hk');
    expect(
      loaded.comic.catalog.single.scanlationGroups
          .map((group) => (group.id, group.name)),
      [('group-a', 'Group A'), ('group-b', 'Group B')],
    );
    expect(loaded.chapter.language, 'zh-hk');
    expect(
      loaded.chapter.scanlationGroups.map((group) => (group.id, group.name)),
      [('group-a', 'Group A'), ('group-b', 'Group B')],
    );
    final refreshed = loaded.chapter.copyWith(
      operationGeneration: 9,
      state: OfflineChapterState.downloading,
    );
    expect(refreshed.language, 'zh-hk');
    expect(
      refreshed.scanlationGroups.map((group) => (group.id, group.name)),
      [('group-a', 'Group A'), ('group-b', 'Group B')],
    );
  });
  test('later manifests retain attribution for downloaded UUIDs no longer live',
      () async {
    const retainedGroups = [
      ScanlationGroup('retained-group', 'Retained Group'),
    ];
    final first = manifest(1);
    await store.saveManifest(
      OfflineManifest(
        comic: OfflineComicSnapshot(
          key: first.comic.key,
          rawTitle: first.comic.rawTitle,
          isLongComic: first.comic.isLongComic,
          catalog: const [
            OfflineCatalogChapter(
              chapterId: 'chapter-1',
              rawTitle: 'Chapter 1',
              groupName: 'Main',
              language: 'zh',
              scanlationGroups: retainedGroups,
            ),
          ],
        ),
        chapter: OfflineChapterSnapshot(
          key: first.chapter.key,
          rawTitle: first.chapter.rawTitle,
          groupName: first.chapter.groupName,
          language: 'zh',
          scanlationGroups: retainedGroups,
          sortIndex: first.chapter.sortIndex,
          manifestGeneration: first.chapter.manifestGeneration,
          manifestSignature: first.chapter.manifestSignature,
          state: first.chapter.state,
          pages: first.chapter.pages,
        ),
      ),
    );
    const secondKey = (
      sourceId: 'copymanga',
      comicId: 'book',
      chapterId: 'chapter-2',
    );
    await store.saveManifest(
      OfflineManifest(
        comic: const OfflineComicSnapshot(
          key: comic,
          rawTitle: 'Book',
          isLongComic: false,
          catalog: [
            OfflineCatalogChapter(
              chapterId: 'chapter-2',
              rawTitle: 'Chapter 2',
              groupName: 'Main',
            ),
          ],
        ),
        chapter: OfflineChapterSnapshot(
          key: secondKey,
          rawTitle: 'Chapter 2',
          groupName: 'Main',
          sortIndex: 1,
          manifestGeneration: 1,
          manifestSignature: 'second',
          state: OfflineChapterState.downloading,
        ),
      ),
    );

    final retained = (await store.loadManifest(chapter))!;

    expect(retained.chapter.language, 'zh');
    expect(
      retained.chapter.scanlationGroups.map((group) => (group.id, group.name)),
      [('retained-group', 'Retained Group')],
    );
    expect(
      retained.comic.catalog.map((item) => item.chapterId),
      containsAll(['chapter-1', 'chapter-2']),
    );
  });


  test('legacy catalog JSON loads with empty attribution metadata', () async {
    final attributed = manifest(1);
    await store.saveManifest(attributed);
    await database.database.update(
      'OfflineComicEntity',
      {
        'catalogJson':
            '[{"chapterId":"chapter-1","rawTitle":"Chapter 1","groupName":"Main"}]',
      },
      where: 'sourceId = ? AND comicId = ?',
      whereArgs: [comic.sourceId, comic.comicId],
    );

    final loaded = (await store.loadManifest(chapter))!;

    expect(loaded.comic.catalog.single.language, isNull);
    expect(loaded.comic.catalog.single.scanlationGroups, isEmpty);
    expect(loaded.chapter.language, isNull);
    expect(loaded.chapter.scanlationGroups, isEmpty);
  });


  test('saving another chapter preserves existing manifests for the comic',
      () async {
    await store.saveManifest(manifest(1));
    const secondKey = (
      sourceId: 'copymanga',
      comicId: 'book',
      chapterId: 'chapter-2',
    );
    await store.saveManifest(
      OfflineManifest(
        comic: manifest(1).comic,
        chapter: OfflineChapterSnapshot(
          key: secondKey,
          rawTitle: 'Chapter 2',
          groupName: 'Main',
          sortIndex: 1,
          manifestGeneration: 1,
          manifestSignature: 'second',
          state: OfflineChapterState.downloading,
          pages: [
            OfflinePage(
              index: 0,
              taskId: 'second-page',
              relativePath: 'comic/second/0.jpg',
              resourceUrl: 'https://img/second',
            ),
          ],
        ),
      ),
    );

    expect(await store.loadManifest(chapter), isNotNull);
    expect(await store.loadManifest(secondKey), isNotNull);
    expect(await store.listManifests(comic), hasLength(2));
  });

  test('commit records actual page length for later corruption checks', () async {
    final withoutLength = manifest(1, urls: const ['https://img/0']);
    await store.saveManifest(
      OfflineManifest(
        comic: withoutLength.comic,
        chapter: withoutLength.chapter.copyWith(
          pages: [
            OfflinePage(
              index: 0,
              taskId: 'page-1-0',
              relativePath: 'comic/1/0.jpg',
              resourceUrl: 'https://img/0',
            ),
          ],
        ),
      ),
    );
    await transfers.complete('page-1-0', 'comic/1/0.jpg');
    expect(await store.commitIfComplete(chapter, generation: 1), isTrue);
    expect(
      (await store.loadManifest(chapter))!.chapter.pages.single.expectedBytes,
      1,
    );

    await File('${downloads.path}/comic/1/0.jpg').writeAsBytes([1, 2]);
    expect(await store.listReadableChapters(comic), isEmpty);
  });
  test('an old generation completion cannot publish a replaced manifest', () async {
    await store.saveManifest(manifest(1));
    await store.saveManifest(manifest(2, urls: const ['https://new/0']));
    for (var index = 0; index < 3; index++) {
      await transfers.complete('page-1-$index', 'comic/1/$index.jpg');
    }

    expect(await store.commitIfComplete(chapter, generation: 1), isFalse);
    expect(await store.listReadableChapters(comic), isEmpty);

    await transfers.complete('page-2-0', 'comic/2/0.jpg');
    expect(await store.commitIfComplete(chapter, generation: 2), isTrue);
    expect((await store.loadManifest(chapter))!.chapter.pages.single.resourceUrl,
        'https://new/0');
  });

  test('missing or length-mismatched files revoke completed readability', () async {
    await store.saveManifest(manifest(1, urls: const ['https://img/0']));
    await transfers.complete('page-1-0', 'comic/1/0.jpg');
    expect(await store.commitIfComplete(chapter, generation: 1), isTrue);

    File('${downloads.path}/comic/1/0.jpg').writeAsBytesSync([1, 2]);

    expect(await store.listReadableChapters(comic), isEmpty);
    expect((await store.loadManifest(chapter))!.chapter.state,
        OfflineChapterState.failed);
  });
}

class _TransferGateway implements OfflineDownloadGateway {
  _TransferGateway(this.root);

  final Directory root;
  final Map<String, OfflineTransferSnapshot> snapshots = {};

  Future<void> complete(String id, String relativePath) async {
    final file = File('${root.path}/$relativePath');
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
  Future<File?> completedFile(String id) async {
    final snapshot = snapshots[id];
    if (snapshot?.state != DownloadState.completed) return null;
    return null;
  }

  @override
  Stream<List<OfflineTransferSnapshot>> watch() => const Stream.empty();

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
