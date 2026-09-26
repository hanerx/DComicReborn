import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dcomic/database/database_common.dart';
import 'package:dcomic/database/database_instance.dart';
import 'package:dcomic/database/entity/config.dart';
import 'package:dcomic/providers/search_history_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory directory;
  late String databasePath;
  late DComicDatabase database;

  Future<DComicDatabase> openDatabase() => $FloorDComicDatabase
      .databaseBuilder(databasePath)
      .addMigrations(DatabaseInstance.migrations)
      .addCallback(DatabaseInstance.databaseCallback)
      .build();

  SearchHistoryStore store() =>
      SearchHistoryStore(daoLoader: () async => database.configDao);

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('search_history_');
    databasePath = '${directory.path}/history.db';
    database = await openDatabase();
  });

  tearDown(() async {
    await database.close();
    await directory.delete(recursive: true);
  });

  test(
    'records trimmed exact-match entries newest first with a limit of 20',
    () async {
      final history = store();

      expect(await history.record('  Alpha  '), ['Alpha']);
      expect(await history.record('beta'), ['beta', 'Alpha']);
      expect(await history.record('Alpha'), ['Alpha', 'beta']);
      expect(await history.record('alpha'), ['alpha', 'Alpha', 'beta']);
      expect(await history.record('   '), ['alpha', 'Alpha', 'beta']);

      for (var index = 0; index < 25; index++) {
        await history.record('query-$index');
      }

      final loaded = await history.load();
      expect(
        loaded,
        List<String>.generate(20, (index) => 'query-${24 - index}'),
      );

      try {
        loaded.add('must-not-affect-storage');
      } on UnsupportedError {
        // An immutable result is also a valid defensive return value.
      }
      expect(
        await history.load(),
        List<String>.generate(20, (index) => 'query-${24 - index}'),
      );
    },
  );

  test(
    'persists inserts and id-based updates across database reopen',
    () async {
      final firstStore = store();
      await firstStore.record('one');
      await firstStore.record('two');
      await firstStore.record('one');

      final rowsBeforeReopen = await database.configDao.getAllConfig();
      expect(rowsBeforeReopen, hasLength(1));
      expect(rowsBeforeReopen.single.id, isNotNull);
      expect(jsonDecode(rowsBeforeReopen.single.value!), ['one', 'two']);

      await database.close();
      database = await openDatabase();

      final reopenedStore = store();
      expect(await reopenedStore.load(), ['one', 'two']);
      expect(await reopenedStore.record('three'), ['three', 'one', 'two']);

      await database.close();
      database = await openDatabase();
      expect(await store().load(), ['three', 'one', 'two']);
      expect(await database.configDao.getAllConfig(), hasLength(1));
    },
  );

  test('remove and clear persist their returned snapshots', () async {
    final history = store();
    await history.record('one');
    await history.record('two');
    await history.record('three');

    expect(await history.remove('  two  '), ['three', 'one']);

    await database.close();
    database = await openDatabase();
    expect(await store().load(), ['three', 'one']);
    expect(await store().clear(), isEmpty);

    await database.close();
    database = await openDatabase();
    expect(await store().load(), isEmpty);
    expect(await database.configDao.getAllConfig(), hasLength(1));
  });

  test('serializes overlapping mutations across store instances', () async {
    await store().record('old');

    final blockingDao = _BlockingUpdateConfigDao(database.configDao);
    final firstStore = SearchHistoryStore(daoLoader: () async => blockingDao);
    var laterLoaderCalled = false;
    final secondStore = SearchHistoryStore(
      daoLoader: () async {
        laterLoaderCalled = true;
        return database.configDao;
      },
    );
    final thirdStore = SearchHistoryStore(
      daoLoader: () async => database.configDao,
    );

    final record = firstStore.record('new');
    await blockingDao.updateStarted.future;
    final remove = secondStore.remove('old');
    final clear = thirdStore.clear();

    await Future<void>.delayed(Duration.zero);
    expect(laterLoaderCalled, isFalse);

    blockingDao.allowUpdate.complete();
    expect(await record, ['new', 'old']);
    expect(await remove, ['new']);
    expect(await clear, isEmpty);
    expect(await store().load(), isEmpty);
  });

  test('surfaces corrupt JSON without overwriting it', () async {
    final history = store();
    await history.record('safe');
    final entity = (await database.configDao.getAllConfig()).single;
    entity.value = '{invalid json';
    await database.configDao.updateConfig(entity);

    await expectLater(history.load(), throwsA(isA<FormatException>()));
    await expectLater(
      history.record('replacement'),
      throwsA(isA<FormatException>()),
    );
    await expectLater(history.remove('safe'), throwsA(isA<FormatException>()));
    await expectLater(history.clear(), throwsA(isA<FormatException>()));

    expect(
      (await database.configDao.getAllConfig()).single.value,
      '{invalid json',
    );
  });
}

class _BlockingUpdateConfigDao extends ConfigDao {
  _BlockingUpdateConfigDao(this._delegate);

  final ConfigDao _delegate;
  final Completer<void> updateStarted = Completer<void>();
  final Completer<void> allowUpdate = Completer<void>();
  var _didBlock = false;

  @override
  Future<List<ConfigEntity>> getAllConfig() => _delegate.getAllConfig();

  @override
  Future<ConfigEntity?> getConfigByKey(String key) =>
      _delegate.getConfigByKey(key);

  @override
  Future<void> insertConfig(ConfigEntity configEntity) =>
      _delegate.insertConfig(configEntity);

  @override
  Future<void> updateConfig(ConfigEntity configEntity) async {
    if (!_didBlock) {
      _didBlock = true;
      updateStarted.complete();
      await allowUpdate.future;
    }
    await _delegate.updateConfig(configEntity);
  }
}
