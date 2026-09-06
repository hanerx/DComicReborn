import 'dart:io';

import 'package:dcomic/database/database_common.dart';
import 'package:dcomic/database/database_instance.dart';
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
        final config = await database.configDao.getConfigByKey('theme');
        expect(config?.value, 'dark');
        final history = await database.comicHistoryDao.getComicHistoryByComicId(
          'book',
          'copymanga',
        );
        expect(history?.title, '保留阅读记录');
        expect(history?.lastChapterId, 'chapter-10');
        expect(history?.timestamp?.millisecondsSinceEpoch, 1700000000000);
        final mapping = await database.comicMappingDao.getComicMappingByComicId(
          'book',
          'copymanga',
          'zaimanhua',
        );
        expect(mapping, isNotNull);
        expect(mapping!.resultComicId, '');
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
        expect(await database.database.getVersion(), 5);
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
}
