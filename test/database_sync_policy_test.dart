import 'dart:io';

import 'package:dcomic/database/database_common.dart';
import 'package:dcomic/database/database_instance.dart';
import 'package:dcomic/database/entity/config.dart';
import 'package:dcomic/database/entity/model_config.dart';
import 'package:dcomic/database/sync/sync_models.dart';
import 'package:dcomic/database/sync/sync_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late DComicDatabase database;
  late Database raw;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('sync_policy_');
    database = await $FloorDComicDatabase
        .databaseBuilder('${directory.path}/test.db')
        .addMigrations(DatabaseInstance.migrations)
        .addCallback(DatabaseInstance.databaseCallback)
        .build();
    raw = database.database as Database;
  });
  tearDown(() async {
    await database.close();
    await directory.delete(recursive: true);
  });

  test('unregistered in-memory defaults fail at their definition site', () {
    expect(
      () => ConfigEntity.createConfigEntity('NewFeatureEnabled', true),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'setting name',
          contains('NewFeatureEnabled'),
        ),
      ),
    );
    expect(
      () => ModelConfigEntity.createConfigEntity('newSecret', '', 'source'),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'setting name',
          contains('newSecret'),
        ),
      ),
    );
  });

  test('unregistered table fails before synchronization starts', () async {
    await raw.execute('CREATE TABLE NewFeature (id INTEGER PRIMARY KEY)');
    await expectLater(
      SyncStore.installSchema(raw),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'missing policy',
          contains('NewFeature'),
        ),
      ),
    );
  });

  test(
    'unclassified field fails even on an otherwise registered table',
    () async {
      await raw.execute('ALTER TABLE ComicHistoryEntity ADD COLUMN extra TEXT');
      await expectLater(
        SyncStore.installSchema(raw),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'missing policy',
            contains('ComicHistoryEntity.extra'),
          ),
        ),
      );
    },
  );

  test(
    'unregistered setting write rolls back instead of silently staying local',
    () async {
      await expectLater(
        raw.insert('ConfigEntity', {'key': 'NewFeatureEnabled', 'value': '1'}),
        throwsA(isA<DatabaseException>()),
      );
      expect(
        await raw.query(
          'ConfigEntity',
          where: 'key = ?',
          whereArgs: ['NewFeatureEnabled'],
        ),
        isEmpty,
      );
    },
  );

  test('unregistered source key is not guessed to be a credential', () async {
    await expectLater(
      raw.insert('ModelConfigEntity', {
        'key': 'newSecret',
        'value': 'not-for-upload',
        'sourceModel': 'source',
      }),
      throwsA(isA<DatabaseException>()),
    );
    expect(await raw.query('ModelConfigEntity'), isEmpty);
  });

  test(
    'internal-looking tables and generated columns cannot bypass coverage',
    () async {
      await raw.execute('CREATE TABLE _dcomic_sync_future (value TEXT)');
      await raw.execute(
        "ALTER TABLE ConfigEntity ADD COLUMN derived TEXT GENERATED ALWAYS AS (key || '-copy') VIRTUAL",
      );
      await expectLater(
        SyncStore.installSchema(raw),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'all missing policies',
            allOf(
              contains('_dcomic_sync_future'),
              contains('ConfigEntity.derived'),
            ),
          ),
        ),
      );
    },
  );

  test(
    'renamed registered fields report both stale and missing declarations',
    () async {
      await raw.execute(
        'ALTER TABLE ComicHistoryEntity RENAME COLUMN title TO renamedTitle',
      );
      await expectLater(
        SyncStore.installSchema(raw),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'renamed field',
            allOf(
              contains('ComicHistoryEntity.title'),
              contains('ComicHistoryEntity.renamedTitle'),
            ),
          ),
        ),
      );
    },
  );

  test(
    'database open rejects legacy unregistered keys before transport exists',
    () async {
      final path = '${directory.path}/legacy.db';
      final legacy = await $FloorDComicDatabase.databaseBuilder(path).build();
      await legacy.database.insert('ConfigEntity', {
        'key': 'UndeclaredLegacySetting',
        'value': 'private',
      });
      await legacy.close();
      await expectLater(
        $FloorDComicDatabase
            .databaseBuilder(path)
            .addCallback(DatabaseInstance.databaseCallback)
            .build(),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'legacy key without value',
            allOf(
              contains('UndeclaredLegacySetting'),
              isNot(contains('private')),
            ),
          ),
        ),
      );
    },
  );

  test(
    'a batch with an unregistered key rolls back all earlier writes',
    () async {
      final batch = raw.batch()
        ..insert('ConfigEntity', {'key': 'ThemeColor', 'value': 'Blue'})
        ..insert('ConfigEntity', {
          'key': 'UnregisteredBatchSetting',
          'value': '1',
        });
      await expectLater(batch.commit(), throwsA(isA<DatabaseException>()));
      expect(await raw.query('ConfigEntity'), isEmpty);
    },
  );

  test(
    'renaming a synced setting to an explicit local key retires its remote key',
    () async {
      final store = await SyncStore.attach(database);
      addTearDown(store.close);
      await raw.insert('ConfigEntity', {'key': 'ThemeColor', 'value': 'Blue'});
      final first = (await store.pending({SyncCategory.settings})).single;
      await store.acknowledge(first, first);
      await raw.update(
        'ConfigEntity',
        {'key': 'SearchHistory', 'value': '[]'},
        where: 'key = ?',
        whereArgs: ['ThemeColor'],
      );
      final deletion = (await store.pending({SyncCategory.settings})).single;
      expect(deletion.key, 'ThemeColor');
      expect(deletion.deleted, isTrue);
      expect(deletion.value, isNull);
      await store.acknowledge(deletion, deletion);
      expect(await store.pending({SyncCategory.settings}), isEmpty);
      expect((await raw.query('ConfigEntity')).single['key'], 'SearchHistory');
      await expectLater(
        raw.update(
          'ConfigEntity',
          {'key': 'UndeclaredRename'},
          where: 'key = ?',
          whereArgs: ['SearchHistory'],
        ),
        throwsA(isA<DatabaseException>()),
      );
      expect((await raw.query('ConfigEntity')).single['key'], 'SearchHistory');
    },
  );

  test('explicit local keys stay local and credentials stay opt-in', () async {
    final store = await SyncStore.attach(database);
    addTearDown(store.close);
    await database.configDao.insertConfig(
      ConfigEntity.createConfigEntity('SearchHistory', '[]'),
    );
    await database.configDao.insertConfig(
      ConfigEntity.createConfigEntity(
        'AutomaticMappingAttempts:["a","b","c"]',
        2,
      ),
    );
    await database.configDao.insertConfig(
      ConfigEntity.createConfigEntity('ReaderPrecacheCount', 9),
    );
    await database.modelConfigDao.insertConfig(
      ModelConfigEntity.createConfigEntity('Token', 'private-token', 'source'),
    );
    final publicRecords = await store.pending(SyncCategory.defaults);
    expect(publicRecords.map((record) => record.key), ['ReaderPrecacheCount']);
    expect(publicRecords.single.value, {'value': '9'});
    final credentials = (await store.pending({SyncCategory.credentials}))
        .single;
    expect(credentials.value!['configs'], [
      {'sourceModel': 'source', 'key': 'Token', 'value': 'private-token'},
    ]);
  });
}
