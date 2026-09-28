import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dcomic/database/database_common.dart';
import 'package:dcomic/database/database_instance.dart';
import 'package:dcomic/database/entity/comic_history.dart';
import 'package:dcomic/database/entity/comic_mapping.dart';
import 'package:dcomic/database/entity/model_config.dart';
import 'package:dcomic/database/entity/config.dart';
import 'package:dcomic/database/sync/sync_models.dart';
import 'package:dcomic/database/sync/sync_store.dart';
import 'package:dcomic/utils/image_utils.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory directory;
  late DComicDatabase database;
  late SyncStore store;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('sync_store_');
    database = await $FloorDComicDatabase
        .databaseBuilder('${directory.path}/store.db')
        .addMigrations(DatabaseInstance.migrations)
        .addCallback(DatabaseInstance.databaseCallback)
        .build();
    store = await SyncStore.attach(database);
  });

  tearDown(() async {
    await store.close();
    await database.close();
    await directory.delete(recursive: true);
  });

  test('wire models preserve protocol fields and version ordering', () {
    const earlier = SyncVersion(wall: 10, logical: 2, device: 'a');
    const later = SyncVersion(wall: 10, logical: 2, device: 'b');
    final record = SyncRecord(
      category: SyncCategory.history,
      key: jsonEncode(['history', 'source', 'comic']),
      value: const {'title': 'Title'},
      deleted: false,
      version: later,
      uncertain: true,
      baseVersion: earlier,
    );

    expect(earlier.compareTo(later), lessThan(0));
    expect(SyncRecord.fromJson(record.toJson()), record);
    expect(SyncCategory.defaults, isNot(contains(SyncCategory.credentials)));
    expect(SyncCategory.credentials.sensitive, isTrue);
  });

  test('DAO writes are captured immediately under their natural key', () async {
    await store.calibrate(
      DateTime.now().millisecondsSinceEpoch,
      roundTrip: const Duration(milliseconds: 20),
    );
    await database.comicHistoryDao.insertComicHistory(
      ComicHistoryEntity.createComicHistoryEntity(
        'comic',
        title: 'Title',
        cover: 'cover',
        coverType: ImageType.network,
        lastChapterTitle: 'Chapter',
        lastChapterId: 'chapter-1',
        lastPage: 7,
        timestamp: DateTime.fromMillisecondsSinceEpoch(1234),
        providerName: 'source',
      ),
    );

    final pending = await store.pending({SyncCategory.history});
    final record = pending.singleWhere(
      (item) => item.key == jsonEncode(['history', 'source', 'comic']),
    );
    expect(record.uncertain, isFalse);
    expect(record.deleted, isFalse);
    expect(record.value, containsPair('lastChapterId', 'chapter-1'));
    expect(record.value, containsPair('lastPage', 7));

    final persisted = await database.comicHistoryDao
        .getComicHistoryByComicId('comic', 'source');
    expect(persisted?.lastPage, 7);
  });

  test('legacy sync history defaults its absent last page to one', () async {
    final legacy = SyncRecord(
      category: SyncCategory.history,
      key: jsonEncode(['history', 'legacy-source', 'legacy-comic']),
      value: const {
        'comicId': 'legacy-comic',
        'title': 'Legacy',
        'cover': '',
        'coverType': 0,
        'lastChapterTitle': 'Chapter',
        'lastChapterId': 'chapter-1',
        'timestamp': null,
        'providerName': 'legacy-source',
      },
      deleted: false,
      version: const SyncVersion(wall: 1, logical: 0, device: 'legacy'),
      uncertain: false,
    );

    await store.receive([legacy]);

    final persisted = await database.comicHistoryDao
        .getComicHistoryByComicId('legacy-comic', 'legacy-source');
    expect(persisted?.lastPage, 1);
    final exported = (await store.snapshot({SyncCategory.history})).single;
    expect(exported.value, containsPair('lastPage', 1));
  });

  test('sync history preserves a present last page on import', () async {
    final incoming = SyncRecord(
      category: SyncCategory.history,
      key: jsonEncode(['history', 'source', 'comic']),
      value: const {
        'comicId': 'comic',
        'title': 'Title',
        'cover': '',
        'coverType': 0,
        'lastChapterTitle': 'Chapter',
        'lastChapterId': 'chapter-1',
        'lastPage': 6,
        'timestamp': null,
        'providerName': 'source',
      },
      deleted: false,
      version: const SyncVersion(wall: 1, logical: 0, device: 'remote'),
      uncertain: false,
    );

    await store.receive([incoming]);

    final persisted = await database.comicHistoryDao
        .getComicHistoryByComicId('comic', 'source');
    expect(persisted?.lastPage, 6);
  });

  test('sync history rejects an invalid present last page', () {
    final invalid = SyncRecord(
      category: SyncCategory.history,
      key: jsonEncode(['history', 'source', 'comic']),
      value: const {
        'comicId': 'comic',
        'title': 'Title',
        'cover': '',
        'coverType': 0,
        'lastChapterTitle': 'Chapter',
        'lastChapterId': 'chapter-1',
        'lastPage': 0,
        'timestamp': null,
        'providerName': 'source',
      },
      deleted: false,
      version: const SyncVersion(wall: 1, logical: 0, device: 'remote'),
      uncertain: false,
    );

    expect(() => store.validateRecords([invalid]), throwsFormatException);
  });

  test('raw deletes create durable tombstones', () async {
    await database.configDao.insertConfig(
      ConfigEntity.createConfigEntity('ThemeColor', 'Blue'),
    );
    final row = (await database.database.query(
      'ConfigEntity',
      where: '`key` = ?',
      whereArgs: ['ThemeColor'],
    )).single;

    await database.database.delete(
      'ConfigEntity',
      where: '`id` = ?',
      whereArgs: [row['id']],
    );

    final record = (await store.pending({SyncCategory.settings})).singleWhere(
      (item) => item.key == 'ThemeColor',
    );
    expect(record.deleted, isTrue);
    expect(record.value, isNull);
  });

  test('calibration never rewrites an existing uncertain edit', () async {
    await database.configDao.insertConfig(
      ConfigEntity.createConfigEntity('ThemeMode', 1),
    );
    final before = (await store.pending({SyncCategory.settings})).singleWhere(
      (item) => item.key == 'ThemeMode',
    );
    expect(before.uncertain, isTrue);

    await store.calibrate(
      DateTime.now().millisecondsSinceEpoch,
      roundTrip: Duration.zero,
    );
    final after = (await store.pending({SyncCategory.settings})).singleWhere(
      (item) => item.key == 'ThemeMode',
    );
    expect(after.version, before.version);
    expect(after.uncertain, isTrue);
  });

  test('acknowledging an in-flight version preserves a newer edit', () async {
    await store.calibrate(
      DateTime.now().millisecondsSinceEpoch,
      roundTrip: Duration.zero,
    );
    final entity = ConfigEntity.createConfigEntity('ThemeColor', 'Blue');
    await database.configDao.insertConfig(entity);
    final sent = (await store.pending({SyncCategory.settings})).single;

    final stored = await database.configDao.getConfigByKey('ThemeColor');
    stored!.set('Red');
    await database.configDao.updateConfig(stored);
    await store.acknowledge(sent, sent);

    final remaining = (await store.pending({SyncCategory.settings})).single;
    expect(remaining.version, isNot(sent.version));
    expect(remaining.value, const {'value': 'Red'});
  });

  test('receive applies without echoing and round-trips between stores', () async {
    final secondDirectory = await Directory.systemTemp.createTemp('sync_peer_');
    final secondDatabase = await $FloorDComicDatabase
        .databaseBuilder('${secondDirectory.path}/peer.db')
        .addMigrations(DatabaseInstance.migrations)
        .build();
    final secondStore = await SyncStore.attach(secondDatabase);
    addTearDown(() async {
      await secondStore.close();
      await secondDatabase.close();
      await secondDirectory.delete(recursive: true);
    });

    await store.calibrate(
      DateTime.now().millisecondsSinceEpoch,
      roundTrip: Duration.zero,
    );
    await database.configDao.insertConfig(
      ConfigEntity.createConfigEntity('ThemeColor', 'Blue'),
    );
    final outgoing = await store.pending({SyncCategory.settings});

    await secondStore.receive(outgoing);

    expect(await secondStore.pendingCount(SyncCategory.values.toSet()), 0);
    expect(
      (await secondDatabase.configDao.getConfigByKey('ThemeColor'))?.get<String>(),
      'Blue',
    );
  });

  test('pending categories are filtered without discarding disabled edits', () async {
    await database.configDao.insertConfig(
      ConfigEntity.createConfigEntity('ThemeColor', 'Blue'),
    );
    await database.comicHistoryDao.insertComicHistory(
      ComicHistoryEntity.createComicHistoryEntity(
        'comic',
        providerName: 'source',
      ),
    );

    expect(await store.pendingCount({SyncCategory.history}), 1);
    expect(await store.pendingCount({SyncCategory.settings}), 1);
    expect(
      await store.pendingCount({SyncCategory.history, SyncCategory.settings}),
      2,
    );
  });

  test('binding aggregate rejects conflicting active endpoints atomically', () async {
    await database.comicMappingDao.insertComicMapping(
      ComicMappingEntity.between('a', 'one', 'b', 'original'),
    );
    final version = SyncVersion(
      wall: DateTime.now().millisecondsSinceEpoch,
      logical: 0,
      device: 'remote',
    );
    final malformed = SyncRecord(
      category: SyncCategory.bindings,
      key: 'graph',
      value: const {
        'edges': [
          {
            'providerA': 'a',
            'comicA': 'one',
            'providerB': 'b',
            'comicB': 'two',
            'blocked': false,
          },
          {
            'providerA': 'a',
            'comicA': 'one',
            'providerB': 'b',
            'comicB': 'three',
            'blocked': false,
          },
        ],
      },
      deleted: false,
      version: version,
      uncertain: false,
    );

    await expectLater(store.receive([malformed]), throwsFormatException);
    final rows = await database.comicMappingDao.getAllComicMappingEntity();
    expect(rows, hasLength(1));
    expect(rows.single.comicB, 'original');
  });

  test('preferences and pending metadata are isolated by account binding', () async {
    await store.bindAccount('https://one.example|user-1', migrateLocal: false);
    await store.writePreferences(const {'cursor': 12});
    await database.configDao.insertConfig(
      ConfigEntity.createConfigEntity('ThemeColor', 'Blue'),
    );
    expect(await store.pendingCount({SyncCategory.settings}), 1);

    await store.bindAccount('https://two.example|user-2', migrateLocal: false);
    expect(await store.readPreferences(), isEmpty);
    expect(await store.pendingCount({SyncCategory.settings}), 0);
    final secondAccountSetting =
        await database.configDao.getConfigByKey('ThemeColor');
    secondAccountSetting!.set('Red');
    await database.configDao.updateConfig(secondAccountSetting);
    expect(await store.pendingCount({SyncCategory.settings}), 1);

    await store.bindAccount('https://one.example|user-1', migrateLocal: false);
    expect(await store.readPreferences(), const {'cursor': 12});
    expect(await store.pendingCount({SyncCategory.settings}), 1);
    expect(
      (await database.configDao.getConfigByKey('ThemeColor'))?.get<String>(),
      'Blue',
    );
    expect(
      (await store.pending({SyncCategory.settings})).single.value,
      const {'value': 'Blue'},
    );

    await store.bindAccount('https://two.example|user-2', migrateLocal: false);
    expect(
      (await database.configDao.getConfigByKey('ThemeColor'))?.get<String>(),
      'Red',
    );
    expect(await store.pendingCount({SyncCategory.settings}), 1);
  });

  test('account baselines and migration preserve version provenance', () async {
    const firstAccount = 'https://one.example|user-1';
    const secondAccount = 'https://two.example|user-2';
    await store.bindAccount(firstAccount, migrateLocal: false);
    await store.calibrate(1000, roundTrip: Duration.zero);
    const remoteVersion = SyncVersion(
      wall: 900,
      logical: 0,
      device: 'remote',
    );
    await store.receive([
      SyncRecord(
        category: SyncCategory.settings,
        key: 'ThemeColor',
        value: const {'value': 'Red'},
        deleted: false,
        version: remoteVersion,
        uncertain: false,
      ),
    ]);
    final setting = await database.configDao.getConfigByKey('ThemeColor');
    setting!.set('Blue');
    await database.configDao.updateConfig(setting);
    final firstVersion =
        (await store.pending({SyncCategory.settings})).single;
    expect(firstVersion.baseVersion, remoteVersion);
    await store.acknowledge(firstVersion, firstVersion);

    await store.bindAccount(secondAccount, migrateLocal: false);
    final synthesizedBaseline = (await store.snapshot({
      SyncCategory.settings,
    })).singleWhere((record) => record.key == 'ThemeColor');
    expect(synthesizedBaseline.version, firstVersion.version);
    expect(synthesizedBaseline.uncertain, firstVersion.uncertain);

    await store.bindAccount(firstAccount, migrateLocal: true);

    final migrated = (await store.pending({SyncCategory.settings}))
        .singleWhere((record) => record.key == 'ThemeColor');
    expect(migrated.version, firstVersion.version);
    expect(migrated.uncertain, firstVersion.uncertain);
    expect(migrated.baseVersion, firstVersion.baseVersion);
    expect(migrated.value, const {'value': 'Blue'});
  });

  test('clock recalibration never moves later local versions backwards', () async {
    await store.calibrate(100000, roundTrip: Duration.zero);
    await database.configDao.insertConfig(
      ConfigEntity.createConfigEntity('ThemeColor', 'Blue'),
    );
    final first = (await store.pending({SyncCategory.settings})).single;

    await store.calibrate(10, roundTrip: Duration.zero);
    await database.configDao.insertConfig(
      ConfigEntity.createConfigEntity('ReadDirection', 1),
    );
    final second = (await store.pending({SyncCategory.settings}))
        .singleWhere((record) => record.key == 'ReadDirection');

    expect(second.version.compareTo(first.version), greaterThan(0));
    expect(second.uncertain, isFalse);
  });

  test('all incoming payloads validate before any remote write', () async {
    await store.calibrate(100, roundTrip: Duration.zero);
    await database.configDao.insertConfig(
      ConfigEntity.createConfigEntity('ThemeColor', 'Blue'),
    );
    const remoteVersion = SyncVersion(
      wall: 200,
      logical: 0,
      device: 'remote',
    );
    final valid = SyncRecord(
      category: SyncCategory.settings,
      key: 'ThemeColor',
      value: const {'value': 'Red'},
      deleted: false,
      version: remoteVersion,
      uncertain: false,
    );
    final invalid = SyncRecord(
      category: SyncCategory.settings,
      key: 'ThemeMode',
      value: const {'value': '99'},
      deleted: false,
      version: remoteVersion,
      uncertain: false,
    );

    await expectLater(store.receive([valid, invalid]), throwsFormatException);
    expect(
      (await database.configDao.getConfigByKey('ThemeColor'))?.get<String>(),
      'Blue',
    );
  });

  test('conflict resolutions use a dedicated durable outbox', () async {
    await database.configDao.insertConfig(
      ConfigEntity.createConfigEntity('ThemeColor', 'Blue'),
    );
    final local = (await store.pending({SyncCategory.settings})).single;
    final remote = SyncRecord(
      category: SyncCategory.settings,
      key: 'ThemeColor',
      value: const {'value': 'Red'},
      deleted: false,
      version: const SyncVersion(wall: 100, logical: 0, device: 'remote'),
      uncertain: true,
    );
    await store.addConflict(local, remote);
    final conflict = (await store.conflicts()).single;
    await store.calibrate(200, roundTrip: Duration.zero);

    await store.resolveConflict(conflict.id, useLocal: false);

    final resolution = await store.pendingResolution(conflict.id);
    expect(resolution, isNotNull);
    expect(resolution!.baseVersion, remote.version);
    expect(resolution.value, remote.value);
    expect(await store.pending({SyncCategory.settings}), isEmpty);
    expect(await store.conflicts(), hasLength(1));

    await store.acknowledge(resolution, resolution);
    expect(await store.pendingResolution(conflict.id), isNull);
    expect(await store.conflicts(), isEmpty);
  });

  test('uncertain pull preserves an unpushed local edit for server arbitration',
      () async {
    await database.configDao.insertConfig(
      ConfigEntity.createConfigEntity('ThemeColor', 'Blue'),
    );
    final local = (await store.pending({SyncCategory.settings})).single;
    final remote = SyncRecord(
      category: SyncCategory.settings,
      key: 'ThemeColor',
      value: const {'value': 'Red'},
      deleted: false,
      version: const SyncVersion(wall: 0, logical: 50, device: 'remote'),
      uncertain: true,
    );

    await store.receive([remote]);

    expect(await store.conflicts(), isEmpty);
    final stillPending = (await store.pending({SyncCategory.settings})).single;
    expect(stillPending.version, local.version);
    expect(stillPending.value, const {'value': 'Blue'});
  });

  test('source settings and credentials use conservative classification',
      () async {
    await database.modelConfigDao.insertConfig(
      ModelConfigEntity.createConfigEntity(
        'chineseDisplayLanguage',
        'simplified',
        'copymanga',
      ),
    );
    await database.modelConfigDao.insertConfig(
      ModelConfigEntity.createConfigEntity('token', 'secret', 'copymanga'),
    );
    await database.modelConfigDao.insertConfig(
      ModelConfigEntity.createConfigEntity(
        'debugToggle',
        'device-only',
        'copymanga',
      ),
    );
    await database.configDao.insertConfig(
      ConfigEntity.createConfigEntity(
        'AutomaticMappingAttempts:["a","b","c"]',
        2,
      ),
    );

    final source = await store.pending({SyncCategory.sourceSettings});
    expect(source, hasLength(1));
    expect(
      source.single.key,
      jsonEncode(['copymanga', 'chineseDisplayLanguage']),
    );
    final credentials = await store.pending({SyncCategory.credentials});
    expect(credentials, hasLength(1));
    expect(
      credentials.single.value!['configs'],
      contains(
        allOf(
          containsPair('sourceModel', 'copymanga'),
          containsPair('key', 'token'),
          containsPair('value', 'secret'),
        ),
      ),
    );
    expect(await store.pending({SyncCategory.settings}), isEmpty);
  });
  test('calibrated writes refresh their anchor at mutation time', () async {
    await store.calibrate(100000, roundTrip: Duration.zero);
    await Future<void>.delayed(const Duration(milliseconds: 50));

    await database.configDao.insertConfig(
      ConfigEntity.createConfigEntity('ThemeColor', 'Blue'),
    );

    final record = (await store.pending({SyncCategory.settings})).single;
    expect(record.version.wall, greaterThanOrEqualTo(100025));
    expect(record.uncertain, isFalse);
  });

  test('every business write replaces a poisoned SQL clock anchor', () async {
    await store.calibrate(100000, roundTrip: Duration.zero);
    await database.database.update(
      '_dcomic_sync_state',
      {'anchor_wall': 3700000},
      where: 'id = 1',
    );
    await database.configDao.insertConfig(
      ConfigEntity.createConfigEntity('ThemeColor', 'Blue'),
    );
    final afterFutureAnchor =
        (await store.pending({SyncCategory.settings})).single;
    expect(afterFutureAnchor.uncertain, isFalse);
    expect(afterFutureAnchor.version.wall, lessThan(200000));

    await database.database.update(
      '_dcomic_sync_state',
      {'anchor_wall': -3500000},
      where: 'id = 1',
    );
    await database.configDao.insertConfig(
      ConfigEntity.createConfigEntity('ReadDirection', 1),
    );
    final afterPastAnchor = (await store.pending({SyncCategory.settings}))
        .singleWhere((record) => record.key == 'ReadDirection');
    expect(
      afterPastAnchor.version.compareTo(afterFutureAnchor.version),
      greaterThan(0),
    );
    expect(afterPastAnchor.uncertain, isFalse);
  });

  test('raw batches preserve result shape and use a commit-time anchor',
      () async {
    await store.calibrate(100000, roundTrip: Duration.zero);
    final theme = ConfigEntity.createConfigEntity('ThemeColor', 'Blue');
    final direction = ConfigEntity.createConfigEntity('ReadDirection', 1);
    final batch = database.database.batch();
    batch.insert('ConfigEntity', {
      'key': theme.key,
      'value': theme.value,
    });
    batch.insert('ConfigEntity', {
      'key': direction.key,
      'value': direction.value,
    });

    final results = await batch.commit();

    expect(results, hasLength(2));
    final records = await store.pending({SyncCategory.settings});
    expect(records, hasLength(2));
    expect(records.every((record) => !record.uncertain), isTrue);
  });

  test('queued root batches sample the clock after acquiring the lock',
      () async {
    await store.calibrate(100000, roundTrip: Duration.zero);
    final entered = Completer<void>();
    final release = Completer<void>();
    final root = database.database as sqflite.Database;
    final blocker = root.transaction((transaction) async {
      await transaction.query('_dcomic_sync_state');
      entered.complete();
      await release.future;
    });
    await entered.future;
    final setting = ConfigEntity.createConfigEntity('ThemeColor', 'Blue');
    final batch = database.database.batch()
      ..insert('ConfigEntity', {
        'key': setting.key,
        'value': setting.value,
      });
    final committed = batch.commit();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    release.complete();
    await blocker;
    await committed;

    final record = (await store.pending({SyncCategory.settings})).single;
    expect(record.version.wall, greaterThanOrEqualTo(100025));
  });

  test('future imports never advance the calibrated shared clock', () async {
    await store.calibrate(1000, roundTrip: Duration.zero);
    final future = SyncRecord(
      category: SyncCategory.settings,
      key: 'ThemeColor',
      value: const {'value': 'Blue'},
      deleted: false,
      version: const SyncVersion(
        wall: 1000 + 10 * 60 * 1000,
        logical: 0,
        device: 'future',
      ),
      uncertain: false,
    );

    await expectLater(
      store.importRecords(
        [future],
        {SyncCategory.settings},
        replace: false,
      ),
      throwsFormatException,
    );
    await database.configDao.insertConfig(
      ConfigEntity.createConfigEntity('ReadDirection', 1),
    );
    final local = (await store.pending({SyncCategory.settings})).single;
    expect(local.version.wall, lessThan(future.version.wall));
  });

  test('offline imports quarantine future walls from the shared clock',
      () async {
    const futureWall = 4102444800000;
    final imported = SyncRecord(
      category: SyncCategory.settings,
      key: 'ThemeColor',
      value: const {'value': 'Blue'},
      deleted: false,
      version: const SyncVersion(
        wall: futureWall,
        logical: 0,
        device: 'future',
      ),
      uncertain: false,
    );
    await store.importRecords(
      [imported],
      {SyncCategory.settings},
      replace: false,
    );

    await database.configDao.insertConfig(
      ConfigEntity.createConfigEntity('ReadDirection', 1),
    );

    final local = (await store.pending({SyncCategory.settings}))
        .singleWhere((record) => record.key == 'ReadDirection');
    expect(local.uncertain, isTrue);
    expect(local.version.wall, lessThan(futureWall));
  });

  test('same-key edits advance beyond a normal offline import', () async {
    const base = SyncVersion(wall: 900, logical: 0, device: 'remote');
    final imported = SyncRecord(
      category: SyncCategory.settings,
      key: 'ThemeColor',
      value: const {'value': 'Blue'},
      deleted: false,
      version: const SyncVersion(wall: 1000, logical: 0, device: 'remote'),
      uncertain: false,
      baseVersion: base,
    );
    await store.importRecords(
      [imported],
      {SyncCategory.settings},
      replace: false,
    );
    final setting = await database.configDao.getConfigByKey('ThemeColor');
    setting!.set('Red');
    await database.configDao.updateConfig(setting);

    final edited = (await store.pending({SyncCategory.settings})).single;
    expect(edited.version.compareTo(imported.version), greaterThan(0));
    expect(edited.baseVersion, base);
    expect(edited.uncertain, isTrue);
  });

  test('offline replace advances beyond the replaced same-key version',
      () async {
    final original = SyncRecord(
      category: SyncCategory.settings,
      key: 'ThemeColor',
      value: const {'value': 'Blue'},
      deleted: false,
      version: const SyncVersion(wall: 1000, logical: 0, device: 'remote'),
      uncertain: false,
    );
    await store.importRecords(
      [original],
      {SyncCategory.settings},
      replace: false,
    );
    await store.importRecords(
      [
        SyncRecord(
          category: SyncCategory.settings,
          key: 'ThemeColor',
          value: const {'value': 'Red'},
          deleted: false,
          version: const SyncVersion(
            wall: 2000,
            logical: 0,
            device: 'backup',
          ),
          uncertain: false,
        ),
      ],
      {SyncCategory.settings},
      replace: true,
    );

    final replaced = (await store.pending({SyncCategory.settings})).single;
    expect(replaced.version.compareTo(original.version), greaterThan(0));
    expect(replaced.baseVersion, original.version);
    expect(replaced.uncertain, isTrue);
    expect(replaced.value, const {'value': 'Red'});
  });

  test('offline replace omission tombstone advances beyond its base', () async {
    final original = SyncRecord(
      category: SyncCategory.settings,
      key: 'ThemeColor',
      value: const {'value': 'Blue'},
      deleted: false,
      version: const SyncVersion(wall: 1000, logical: 0, device: 'remote'),
      uncertain: false,
    );
    await store.importRecords(
      [original],
      {SyncCategory.settings},
      replace: false,
    );

    await store.importRecords(
      const [],
      {SyncCategory.settings},
      replace: true,
    );

    final tombstone = (await store.pending({SyncCategory.settings})).single;
    expect(tombstone.deleted, isTrue);
    expect(tombstone.version.compareTo(original.version), greaterThan(0));
    expect(tombstone.baseVersion, original.version);
    expect(tombstone.uncertain, isTrue);
  });

  test('calibration cannot make a queued offline import observe a future wall',
      () async {
    const futureWall = 4102444800000;
    final entered = Completer<void>();
    final release = Completer<void>();
    final root = database.database as sqflite.Database;
    final blocker = root.transaction((transaction) async {
      await transaction.query('_dcomic_sync_state');
      entered.complete();
      await release.future;
    });
    await entered.future;
    final importFuture = store.importRecords(
      [
        SyncRecord(
          category: SyncCategory.settings,
          key: 'ThemeColor',
          value: const {'value': 'Blue'},
          deleted: false,
          version: const SyncVersion(
            wall: futureWall,
            logical: 0,
            device: 'future',
          ),
          uncertain: false,
        ),
      ],
      {SyncCategory.settings},
      replace: false,
    );
    await Future<void>.delayed(Duration.zero);
    final calibration = store.calibrate(1000, roundTrip: Duration.zero);
    release.complete();
    await blocker;
    await importFuture;
    await calibration;

    await database.configDao.insertConfig(
      ConfigEntity.createConfigEntity('ReadDirection', 1),
    );
    final local = (await store.pending({SyncCategory.settings}))
        .singleWhere((record) => record.key == 'ReadDirection');
    expect(local.version.wall, lessThan(futureWall));
  });

  test('duplicate chapter group names survive import and snapshot', () async {
    final record = SyncRecord(
      category: SyncCategory.chapterRules,
      key: 'rules',
      value: const {
        'groups': [
          {
            'name': 'Same',
            'patterns': [r'Chapter(\d+)'],
          },
          {
            'name': 'Same',
            'patterns': [r'Extra(\d+)'],
          },
        ],
      },
      deleted: false,
      version: const SyncVersion(wall: 0, logical: 1, device: 'device'),
      uncertain: true,
    );

    await store.importRecords(
      [record],
      {SyncCategory.chapterRules},
      replace: true,
    );
    final restored = await store.snapshot({SyncCategory.chapterRules});
    expect(restored.single.value, record.value);
  });

  test('timestamps outside the DateTime range are rejected', () {
    const invalidWall = 8640000000000001;
    expect(
      () => SyncVersion.fromJson(const {
        'wall': invalidWall,
        'logical': 0,
        'device': 'remote',
      }),
      throwsFormatException,
    );
    final history = SyncRecord(
      category: SyncCategory.history,
      key: jsonEncode(['history', 'source', 'comic']),
      value: const {
        'comicId': 'comic',
        'title': 'Title',
        'cover': '',
        'coverType': 0,
        'lastChapterTitle': '',
        'lastChapterId': '',
        'timestamp': invalidWall,
        'providerName': 'source',
      },
      deleted: false,
      version: const SyncVersion(wall: 0, logical: 1, device: 'remote'),
      uncertain: true,
    );
    expect(() => store.validateRecords([history]), throwsFormatException);
  });

  test('delete and reinsert updates existing metadata without a unique failure',
      () async {
    await database.configDao.insertConfig(
      ConfigEntity.createConfigEntity('ThemeMode', 0),
    );
    await database.database.delete(
      'ConfigEntity',
      where: '`key` = ?',
      whereArgs: ['ThemeMode'],
    );

    await database.configDao.insertConfig(
      ConfigEntity.createConfigEntity('ThemeMode', 0),
    );

    final record = (await store.pending({SyncCategory.settings}))
        .singleWhere((item) => item.key == 'ThemeMode');
    expect(record.deleted, isFalse);
    expect(record.value, const {'value': '0'});
  });

  test('pending aggregate clears are not mistaken for bootstrap state',
      () async {
    await database.comicMappingDao.insertComicMapping(
      ComicMappingEntity.between('a', 'one', 'b', 'two'),
    );
    await database.database.delete('ComicMappingEntity');
    final localClear = (await store.pending({SyncCategory.bindings})).single;
    expect(localClear.value, const {'edges': <Object?>[]});

    final incoming = SyncRecord(
      category: SyncCategory.bindings,
      key: 'graph',
      value: const {
        'edges': [
          {
            'providerA': 'a',
            'comicA': 'remote',
            'providerB': 'b',
            'comicB': 'remote',
            'blocked': false,
          },
        ],
      },
      deleted: false,
      version: const SyncVersion(wall: 0, logical: 100, device: 'remote'),
      uncertain: true,
    );

    await store.receive([incoming]);

    expect(await database.comicMappingDao.getAllComicMappingEntity(), isEmpty);
    final pending = (await store.pending({SyncCategory.bindings})).single;
    expect(pending.version, localClear.version);
    expect(pending.value, const {'edges': <Object?>[]});
  });

  test('same-provider mappings remain valid sync graph edges', () async {
    await database.comicMappingDao.insertComicMapping(
      ComicMappingEntity.between('source', 'one', 'source', 'two'),
    );

    final record = (await store.pending({SyncCategory.bindings})).single;
    expect(
      record.value,
      const {
        'edges': [
          {
            'providerA': 'source',
            'comicA': 'one',
            'providerB': 'source',
            'comicB': 'two',
            'blocked': false,
          },
        ],
      },
    );
  });

  test('resolution acknowledgement preserves a subsequent same-key edit',
      () async {
    await database.configDao.insertConfig(
      ConfigEntity.createConfigEntity('ThemeColor', 'Blue'),
    );
    final local = (await store.pending({SyncCategory.settings})).single;
    final remote = SyncRecord(
      category: SyncCategory.settings,
      key: 'ThemeColor',
      value: const {'value': 'Red'},
      deleted: false,
      version: const SyncVersion(wall: 0, logical: 100, device: 'remote'),
      uncertain: true,
    );
    await store.addConflict(local, remote);
    final conflict = (await store.conflicts()).single;
    await store.calibrate(1000, roundTrip: Duration.zero);
    await store.resolveConflict(conflict.id, useLocal: false);
    final resolution = (await store.pendingResolution(conflict.id))!;

    final setting = await database.configDao.getConfigByKey('ThemeColor');
    setting!.set('Green');
    await database.configDao.updateConfig(setting);

    expect(await store.pendingResolution(conflict.id), resolution);
    await store.acknowledge(resolution, resolution);

    expect(await store.conflicts(), isEmpty);
    expect(await store.pendingResolution(conflict.id), isNull);
    final current = (await store.pending({SyncCategory.settings})).single;
    expect(current.value, const {'value': 'Green'});
    expect(current.version, isNot(resolution.version));
  });
}
