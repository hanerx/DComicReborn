import 'dart:io';

import 'package:dcomic/database/database_instance.dart';
import 'package:dcomic/database/entity/comic_mapping.dart';
import 'package:dcomic/providers/models/comic_source_model.dart';
import 'package:dcomic/utils/image_utils.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _Source extends BaseComicSourceModel {
  _Source(this.id);
  final String id;
  @override
  ComicSourceEntity get type => ComicSourceEntity(id, id);
  @override
  Future<BaseComicDetailModel?> getComicDetail(String comicId, String title) =>
      throw StateError('Progress aggregation must not fetch another source');
  @override
  Future<List<ComicListItemEntity>> searchComicDetail(
    String keyword, {
    int page = 0,
  }) => throw StateError('Progress aggregation must not search for bindings');
}

class _Detail extends BaseComicDetailModel {
  _Detail(this.parent, this.comicId, this.chapters);
  @override
  final BaseComicSourceModel parent;
  @override
  final String comicId;
  @override
  final Map<String, List<BaseComicChapterEntityModel>> chapters;
  @override
  String get title => 'Book';
  @override
  ImageEntity get cover => ImageEntity(ImageType.unknown, '');
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  final older = DateTime.utc(2026, 9, 10);
  final newer = DateTime.utc(2026, 9, 11);

  Future<void> enable(
    bool value, {
    String key = 'AggregateReadingProgress',
  }) async {
    final dao = (await DatabaseInstance.instance).configDao;
    final config = await dao.getOrCreateConfigByKey(key, value: false);
    config.set(value);
    await dao.updateConfig(config);
  }

  Future<void> history(
    String source,
    String comic,
    String chapter,
    String title,
    DateTime? time,
  ) async {
    final dao = (await DatabaseInstance.instance).comicHistoryDao;
    final row = await dao.getOrCreateConfigByComicId(comic, source);
    row.lastChapterId = chapter;
    row.lastChapterTitle = title;
    row.timestamp = time;
    await dao.updateComicHistory(row);
  }

  Future<void> bind(
    String source,
    String comic,
    String target,
    String targetComic,
  ) async {
    await (await DatabaseInstance.instance).comicMappingDao.insertComicMapping(
      ComicMappingEntity(null, comic, source, target, targetComic),
    );
  }

  Future<_Detail> detail({
    Map<String, List<(String, String)>>? catalog,
    String source = 'a',
    String comic = 'book-a',
  }) async {
    final parent = _Source(source);
    addTearDown(parent.dispose);
    final chapters = <String, List<BaseComicChapterEntityModel>>{};
    for (final entry
        in (catalog ??
                {
                  '正篇': [('a-10', '第10话'), ('a-20', '第20话')],
                })
            .entries) {
      chapters[entry.key] = [
        for (final (id, title) in entry.value)
          DefaultComicChapterEntityModel(title, id, older),
      ];
    }
    final model = _Detail(parent, comic, chapters);
    addTearDown(model.dispose);
    await model.init();
    return model;
  }

  setUpAll(() async {
    directory = await Directory.systemTemp.createTemp('reading_progress_');
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    await databaseFactory.setDatabasesPath(directory.path);
  });
  setUp(() async {
    final db = await DatabaseInstance.instance;
    for (final table in [
      'ComicHistoryEntity',
      'ComicMappingEntity',
      'ConfigEntity',
    ]) {
      await db.database.delete(table);
    }
    await bind('b', 'book-b', 'a', 'book-a');
    await history('a', 'book-a', 'a-20', '第20话', older);
    await history('b', 'book-b', 'b-10', ' 第　１０ 話 ', newer);
  });
  tearDownAll(() async {
    await (await DatabaseInstance.instance).close();
    await directory.delete(recursive: true);
  });

  test('independent opt in maps a unique normalized title to the current source id', () async {
    await enable(true, key: 'AggregateSubscribeBadges');
    final model = await detail();
    expect(model.latestChapterId, 'a-20');
    await enable(true);
    await model.loadComicHistory();
    expect(model.latestChapterId, 'a-10');
    final local = await (await DatabaseInstance.instance).comicHistoryDao
        .getComicHistoryByComicId('book-a', 'a');
    expect(local!.lastChapterId, 'a-20');
    expect(local.timestamp?.toUtc(), older);
    await enable(false);
    await model.loadComicHistory();
    expect(model.latestChapterId, 'a-20');
  });

  test('forward binding uses latest reading time rather than highest chapter number', () async {
    await enable(true);
    final model = await detail(
      source: 'b',
      comic: 'book-b',
      catalog: {
        '正篇': [('b-10', '第10话'), ('b-20', '第20话')],
      },
    );
    expect(model.latestChapterId, 'b-10');
    await history(
      'a',
      'book-a',
      'a-20',
      '第20话',
      newer.add(const Duration(hours: 1)),
    );
    await model.loadComicHistory();
    expect(model.latestChapterId, 'b-20');
  });

  test('same chapter numbers with different types or punctuation remain independent', () async {
    await enable(true);
    final model = await detail(
      catalog: {
        '正篇': [
          ('a-20', '第20话'),
          ('volume', '第10卷'),
          ('extra', '番外10'),
          ('split', '第10话(上)'),
        ],
      },
    );
    expect(model.latestChapterId, 'a-20');
  });

  test('duplicate chapter titles across groups are not guessed', () async {
    await enable(true);
    final model = await detail(
      catalog: {
        '连载': [('a-20', '第20话'), ('a-10', '第10话')],
        '单行本': [('volume-10', '第１０話')],
      },
    );
    expect(model.latestChapterId, 'a-20');
  });

  test('unbinding takes precedence over a reverse mapping', () async {
    await enable(true);
    await bind('a', 'book-a', 'b', '');
    expect((await detail()).latestChapterId, 'a-20');
  });

  test(
    'ambiguous comic mappings do not borrow another books history',
    () async {
      await enable(true);
      await bind('a', 'other-book', 'b', 'book-b');
      expect((await detail()).latestChapterId, 'a-20');
    },
  );

  test(
    'missing or tied foreign timestamps do not replace current source progress',
    () async {
      await enable(true);
      await history('b', 'book-b', 'b-10', '第10话', null);
      final model = await detail();
      expect(model.latestChapterId, 'a-20');
      await history('b', 'book-b', 'b-10', '第10话', older);
      await model.loadComicHistory();
      expect(model.latestChapterId, 'a-20');
    },
  );

  test(
    'a uniquely matched foreign record can resume a source never read locally',
    () async {
      await enable(true);
      await (await DatabaseInstance.instance).database.delete(
        'ComicHistoryEntity',
        where: 'providerName = ?',
        whereArgs: ['a'],
      );
      expect((await detail()).latestChapterId, 'a-10');
    },
  );
}
