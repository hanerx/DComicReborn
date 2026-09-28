import 'dart:io';

import 'package:dcomic/database/database_common.dart';
import 'package:dcomic/database/database_instance.dart';
import 'package:dcomic/utils/chapter_matching_rules.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

// Schema shipped by Floor 1.5.0. Keep this independent of the new generator.
const _legacySchema = [
  'CREATE TABLE ConfigEntity (id INTEGER PRIMARY KEY AUTOINCREMENT, key TEXT NOT NULL, value TEXT)',
  'CREATE TABLE ComicHistoryEntity (id INTEGER PRIMARY KEY AUTOINCREMENT, comicId TEXT NOT NULL, title TEXT NOT NULL, cover TEXT NOT NULL, coverType INTEGER NOT NULL, lastChapterTitle TEXT NOT NULL, lastChapterId TEXT NOT NULL, timestamp INTEGER, providerName TEXT NOT NULL)',
  'CREATE TABLE CookieEntity (id INTEGER PRIMARY KEY AUTOINCREMENT, key TEXT NOT NULL, value TEXT NOT NULL)',
  'CREATE TABLE ModelConfigEntity (id INTEGER PRIMARY KEY AUTOINCREMENT, key TEXT NOT NULL, value TEXT, sourceModel TEXT)',
  'CREATE TABLE ComicMappingEntity (id INTEGER PRIMARY KEY AUTOINCREMENT, comicId TEXT NOT NULL, sourceProviderName TEXT NOT NULL, targetProviderName TEXT NOT NULL, resultComicId TEXT NOT NULL)',
  'CREATE TABLE ComicSubscribeStateEntity (id INTEGER PRIMARY KEY AUTOINCREMENT, comicId TEXT NOT NULL, timestamp INTEGER, providerName TEXT NOT NULL)',
];

const _legacyV6Schema = [
  ..._legacySchema,
  'CREATE TABLE ChapterRuleGroupEntity (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL)',
  'CREATE TABLE ChapterRulePatternEntity (id INTEGER PRIMARY KEY AUTOINCREMENT, groupId INTEGER NOT NULL, pattern TEXT NOT NULL, FOREIGN KEY (groupId) REFERENCES ChapterRuleGroupEntity (id) ON UPDATE NO ACTION ON DELETE CASCADE)',
  'CREATE INDEX index_ChapterRulePatternEntity_groupId ON ChapterRulePatternEntity (groupId)',
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'community Floor opens an installed v5 database without losing user data',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'database_upgrade_',
      );
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      DComicDatabase? database;
      try {
        final path = '${directory.path}/dcomic.db';
        final legacy = await databaseFactoryFfi.openDatabase(
          path,
          options: OpenDatabaseOptions(
            version: 5,
            onCreate: (db, _) async {
              for (final statement in _legacySchema) {
                await db.execute(statement);
              }
            },
          ),
        );
        await legacy.insert('ConfigEntity', {'key': 'theme', 'value': 'dark'});
        await legacy.insert('ComicHistoryEntity', {
          'comicId': 'book',
          'title': '保留阅读记录',
          'cover': 'https://example.com/cover.jpg',
          'coverType': 0,
          'lastChapterTitle': '第十话',
          'lastChapterId': 'chapter-10',
          'timestamp': 1700000000000,
          'providerName': 'copymanga',
        });
        await legacy.insert('CookieEntity', {
          'key': 'session',
          'value': 'existing',
        });
        await legacy.insert('ModelConfigEntity', {
          'key': 'account',
          'value': 'existing-user',
          'sourceModel': 'copymanga',
        });
        await legacy.insert('ComicMappingEntity', {
          'comicId': 'book',
          'sourceProviderName': 'copymanga',
          'targetProviderName': 'zaimanhua',
          'resultComicId': '',
        });
        await legacy.insert('ComicSubscribeStateEntity', {
          'comicId': 'book',
          'timestamp': null,
          'providerName': 'copymanga',
        });
        await legacy.close();

        database = await $FloorDComicDatabase
            .databaseBuilder(path)
            .addMigrations(DatabaseInstance.migrations)
            .build();
        final rules = ChapterRuleMatcher(
          await database.chapterRuleDao.loadChapterRules(),
        );
        final chapter = rules.match('第10话')!;
        final english = rules.match('Chapter 010')!;
        expect(
          (chapter.groupIndex, chapter.number),
          (english.groupIndex, english.number),
        );
        expect(rules.match('Vol. 10')!.groupIndex, isNot(chapter.groupIndex));
        final config = await database.configDao.getConfigByKey('theme');
        expect(config?.value, 'dark');
        final history = await database.comicHistoryDao.getComicHistoryByComicId(
          'book',
          'copymanga',
        );
        expect(history?.title, '保留阅读记录');
        expect(history?.lastChapterId, 'chapter-10');
        expect(history?.lastPage, 1);
        expect(history?.timestamp?.millisecondsSinceEpoch, 1700000000000);
        expect(
          await database.comicMappingDao.lookupComicId(
            'book',
            'copymanga',
            'zaimanhua',
          ),
          '',
        );
        final mapping =
            (await database.comicMappingDao.getAllComicMappingEntity()).single;
        expect(mapping.blocked, isTrue);
        expect(mapping.comicA == '' || mapping.comicB == '', isTrue);
        final subscription = await database.comicSubscribeStateDao
            .getComicSubscribeStateByComicId('book', 'copymanga');
        expect(subscription, isNotNull);
        expect(subscription!.timestamp, isNull);
        expect(
          (await database.database.query('CookieEntity')).single['value'],
          'existing',
        );
        expect(
          (await database.database.query('ModelConfigEntity')).single['value'],
          'existing-user',
        );

        config!.value = 'light';
        await database.configDao.updateConfig(config);
        history!.lastChapterId = 'chapter-11';
        await database.comicHistoryDao.updateComicHistory(history);
        await database.close();
        database = null;
        database = await $FloorDComicDatabase.databaseBuilder(path).build();
        expect(
          (await database.configDao.getConfigByKey('theme'))?.value,
          'light',
        );
        expect(
          (await database.comicHistoryDao.getComicHistoryByComicId(
            'book',
            'copymanga',
          ))?.lastChapterId,
          'chapter-11',
        );
        expect(
          (await database.database.rawQuery('PRAGMA integrity_check'))
              .single
              .values
              .single,
          'ok',
        );
      } finally {
        await database?.close();
        await directory.delete(recursive: true);
      }
    },
  );

  test(
    'v6 mapping migration canonicalizes reliable edges and blocks conflicts',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'mapping_upgrade_',
      );
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      DComicDatabase? database;
      try {
        final path = '${directory.path}/dcomic.db';
        final legacy = await databaseFactoryFfi.openDatabase(
          path,
          options: OpenDatabaseOptions(
            version: 6,
            onCreate: (db, _) async {
              for (final statement in _legacyV6Schema) {
                await db.execute(statement);
              }
            },
          ),
        );
        await legacy.insert('ConfigEntity', {
          'key': 'unrelated',
          'value': 'preserved',
        });
        final batch = legacy.batch();
        for (final row in [
          ('a', 'A', 'b', 'B'),
          ('b', 'B', 'a', 'A'),
          ('c', 'C', 'd', 'D'),
          ('e', 'E', '', 'F'),
          ('g1', 'G', 'h', 'H'),
          ('h', 'H', 'g2', 'G'),
          ('j', 'J', 'k', 'K'),
          ('k', 'K', '', 'J'),
          ('old', 'S', 'new', 'S'),
          ('t1', 'T', 't2', 'T'),
          ('t1', 'T', 't3', 'T'),
          ('u', 'U', 'v', 'V'),
          ('v', 'V', 'w', 'W'),
          ('u', 'U', '', 'W'),
          ('x', 'X', 'x', 'X'),
          ('x', 'X', '', 'X'),
        ]) {
          batch.insert('ComicMappingEntity', {
            'comicId': row.$1,
            'sourceProviderName': row.$2,
            'resultComicId': row.$3,
            'targetProviderName': row.$4,
          });
        }
        await batch.commit();
        await legacy.close();

        database = await $FloorDComicDatabase
            .databaseBuilder(path)
            .addMigrations(DatabaseInstance.migrations)
            .build();
        final dao = database.comicMappingDao;

        expect(await dao.lookupComicId('a', 'A', 'B'), 'b');
        expect(await dao.lookupComicId('b', 'B', 'A'), 'a');
        expect(await dao.lookupComicId('c', 'C', 'D'), 'd');
        expect(await dao.lookupComicId('e', 'E', 'F'), '');
        expect(await dao.lookupComicId('g1', 'G', 'H'), '');
        expect(await dao.lookupComicId('g2', 'G', 'H'), '');
        expect(await dao.lookupComicId('j', 'J', 'K'), '');
        expect(await dao.lookupComicId('k', 'K', 'J'), '');
        expect(await dao.lookupComicId('old', 'S', 'S'), 'new');
        expect(await dao.lookupComicId('new', 'S', 'S'), 'old');
        expect(await dao.lookupComicId('t1', 'T', 'T'), '');
        expect(await dao.lookupComicId('u', 'U', 'V'), '');
        expect(await dao.lookupComicId('w', 'W', 'V'), '');
        expect(await dao.lookupComicId('x', 'X', 'X'), '');

        final mappings = await dao.getAllComicMappingEntity();
        expect(mappings, hasLength(15));
        expect(mappings.where((row) => !row.blocked), hasLength(3));
        expect(mappings.where((row) => row.blocked), hasLength(12));
        expect(
          (await database.configDao.getConfigByKey('unrelated'))?.value,
          'preserved',
        );
        final columns =
            await database.database.rawQuery('PRAGMA table_info(ComicMappingEntity)');
        expect(
          columns.map((column) => column['name']),
          ['providerA', 'comicA', 'providerB', 'comicB', 'blocked'],
        );
        expect(
          columns.where((column) => (column['pk'] as int) > 0),
          hasLength(4),
        );
      } finally {
        await database?.close();
        await directory.delete(recursive: true);
      }
    },
  );
}
