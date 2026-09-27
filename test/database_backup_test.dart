import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dcomic/database/database_common.dart';
import 'package:dcomic/database/database_instance.dart';
import 'package:dcomic/database/entity/config.dart';
import 'package:dcomic/database/entity/cookie.dart';
import 'package:dcomic/database/sync/database_backup.dart';
import 'package:dcomic/database/sync/sync_models.dart';
import 'package:dcomic/database/sync/sync_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory directory;
  late DComicDatabase database;
  late SyncStore store;
  late DatabaseBackup backup;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('database_backup_');
    database = await $FloorDComicDatabase
        .databaseBuilder('${directory.path}/source.db')
        .addMigrations(DatabaseInstance.migrations)
        .build();
    store = await SyncStore.attach(database);
    backup = DatabaseBackup(store);
  });

  tearDown(() async {
    await store.close();
    await database.close();
    await directory.delete(recursive: true);
  });

  Future<({Directory directory, DComicDatabase database, SyncStore store})>
  openTarget() async {
    final targetDirectory = await Directory.systemTemp.createTemp(
      'database_restore_',
    );
    final targetDatabase = await $FloorDComicDatabase
        .databaseBuilder('${targetDirectory.path}/target.db')
        .addMigrations(DatabaseInstance.migrations)
        .build();
    final targetStore = await SyncStore.attach(targetDatabase);
    addTearDown(() async {
      await targetStore.close();
      await targetDatabase.close();
      await targetDirectory.delete(recursive: true);
    });
    return (
      directory: targetDirectory,
      database: targetDatabase,
      store: targetStore,
    );
  }

  test('credentials can only be exported in an encrypted envelope', () async {
    await database.cookieDao.insertCookie(CookieEntity.createNew('session', 'x'));

    await expectLater(
      backup.export({SyncCategory.credentials}),
      throwsA(isA<DatabaseBackupException>()),
    );

    final bytes = await backup.export(
      {SyncCategory.credentials},
      password: 'correct horse battery staple',
    );
    expect(
      await backup.inspect(bytes, password: 'correct horse battery staple'),
      {SyncCategory.credentials},
    );
    await expectLater(
      backup.inspect(bytes, password: 'wrong password'),
      throwsA(isA<DatabaseBackupException>()),
    );
  });

  test('wrong password never partially changes the target database', () async {
    await database.configDao.insertConfig(
      ConfigEntity.createConfigEntity('ThemeColor', 'Blue'),
    );
    final bytes = await backup.export(
      {SyncCategory.settings},
      password: 'correct password',
    );
    final target = await openTarget();
    await target.database.configDao.insertConfig(
      ConfigEntity.createConfigEntity('ThemeColor', 'Red'),
    );

    await expectLater(
      DatabaseBackup(target.store).importData(
        bytes,
        {SyncCategory.settings},
        password: 'wrong password',
      ),
      throwsA(isA<DatabaseBackupException>()),
    );
    expect(
      (await target.database.configDao.getConfigByKey('ThemeColor'))
          ?.get<String>(),
      'Red',
    );
  });

  test('damaged payload is rejected before any selected category is written',
      () async {
    await database.configDao.insertConfig(
      ConfigEntity.createConfigEntity('ThemeColor', 'Blue'),
    );
    final bytes = await backup.export(
      {SyncCategory.settings},
      password: 'password',
    );
    final damaged = Uint8List.fromList(bytes);
    damaged[damaged.length - 2] ^= 0x40;
    final target = await openTarget();
    await target.database.configDao.insertConfig(
      ConfigEntity.createConfigEntity('ThemeColor', 'Red'),
    );

    await expectLater(
      DatabaseBackup(target.store).importData(
        damaged,
        {SyncCategory.settings},
        password: 'password',
      ),
      throwsA(isA<DatabaseBackupException>()),
    );
    expect(
      (await target.database.configDao.getConfigByKey('ThemeColor'))
          ?.get<String>(),
      'Red',
    );
  });

  test('merge imports only selected categories and preserves original versions',
      () async {
    await store.calibrate(
      DateTime.now().millisecondsSinceEpoch,
      roundTrip: Duration.zero,
    );
    await database.configDao.insertConfig(
      ConfigEntity.createConfigEntity('ThemeColor', 'Blue'),
    );
    await database.configDao.insertConfig(
      ConfigEntity.createConfigEntity('ReadDirection', 1),
    );
    final exported = await store.snapshot({SyncCategory.settings});
    final bytes = await backup.export({SyncCategory.settings});
    final target = await openTarget();

    await DatabaseBackup(target.store).importData(
      bytes,
      {SyncCategory.settings},
    );

    final imported = await target.store.snapshot({SyncCategory.settings});
    expect(
      imported.map((record) => record.version).toSet(),
      exported.map((record) => record.version).toSet(),
    );
    expect(await target.store.pendingCount({SyncCategory.settings}), 2);
  });

  test('replace emits tombstones for selected records absent from the backup',
      () async {
    await database.configDao.insertConfig(
      ConfigEntity.createConfigEntity('ThemeColor', 'Blue'),
    );
    final bytes = await backup.export({SyncCategory.settings});
    final target = await openTarget();
    await target.store.calibrate(
      DateTime.now().millisecondsSinceEpoch,
      roundTrip: Duration.zero,
    );
    await target.database.configDao.insertConfig(
      ConfigEntity.createConfigEntity('ReadDirection', 1),
    );

    await DatabaseBackup(target.store).importData(
      bytes,
      {SyncCategory.settings},
      replace: true,
    );

    expect(
      await target.database.configDao.getConfigByKey('ReadDirection'),
      isNull,
    );
    final tombstone = (await target.store.pending({SyncCategory.settings}))
        .singleWhere((record) => record.key == 'ReadDirection');
    expect(tombstone.deleted, isTrue);
    expect(
      (await target.database.configDao.getConfigByKey('ThemeColor'))
          ?.get<String>(),
      'Blue',
    );
  });

  test('malformed setting payload rejects the whole backup before import',
      () async {
    await database.configDao.insertConfig(
      ConfigEntity.createConfigEntity('ThemeColor', 'Blue'),
    );
    const version = SyncVersion(wall: 100, logical: 0, device: 'backup');
    final bytes = Uint8List.fromList(
      utf8.encode(
        jsonEncode({
          'format': 'dcomic-logical-backup',
          'version': 1,
          'encrypted': false,
          'categories': ['settings'],
          'records': [
            SyncRecord(
              category: SyncCategory.settings,
              key: 'ThemeColor',
              value: const {'value': 'Red'},
              deleted: false,
              version: version,
              uncertain: false,
            ).toJson(),
            SyncRecord(
              category: SyncCategory.settings,
              key: 'ThemeMode',
              value: const {'value': '99'},
              deleted: false,
              version: version,
              uncertain: false,
            ).toJson(),
          ],
        }),
      ),
    );

    await expectLater(
      backup.importData(bytes, {SyncCategory.settings}),
      throwsA(isA<DatabaseBackupException>()),
    );
    expect(
      (await database.configDao.getConfigByKey('ThemeColor'))?.get<String>(),
      'Blue',
    );
  });
}
