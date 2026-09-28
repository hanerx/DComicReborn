import 'dart:io';

import 'package:dcomic/database/database_instance.dart';
import 'package:dcomic/database/sync/sync_models.dart';
import 'package:dcomic/providers/config_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _Config extends ConfigProvider {
  late Future<void> ready;
  @override
  Future<void> init() => ready = super.init();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  const horizontal = 'HorizontalClickAreaPercent';
  const vertical = 'VerticalClickAreaPercent';
  setUpAll(() async {
    directory = await Directory.systemTemp.createTemp('reader_tap_area_');
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    await databaseFactory.setDatabasesPath(directory.path);
  });
  setUp(() async {
    final database = await DatabaseInstance.instance;
    await database.database.delete('ConfigEntity');
  });
  tearDownAll(() async {
    await (await DatabaseInstance.instance).close();
    await directory.delete(recursive: true);
  });

  test(
    'pixel preferences migrate once without replacing explicit percentages',
    () async {
      final database = await DatabaseInstance.instance;
      await database.configDao.setConfigByKey('HorizontalClickAreaSize', '120');
      await database.configDao.setConfigByKey('VerticalClickAreaSize', '300');
      await database.configDao.setConfigByKey(vertical, '25');
      final config = _Config();
      addTearDown(config.dispose);
      await config.ready;
      expect(config.horizontalClickAreaPercent, 30);
      expect(config.verticalClickAreaPercent, 25);
      expect(
        await database.configDao.getConfigByKey('HorizontalClickAreaSize'),
        isNull,
      );
      expect(
        await database.configDao.getConfigByKey('VerticalClickAreaSize'),
        isNull,
      );
      expect(
        (await database.configDao.getConfigByKey(horizontal))?.value,
        '30.0',
      );

      // A later remote deletion must not resurrect the migrated setting.
      await database.database.delete(
        'ConfigEntity',
        where: 'key = ?',
        whereArgs: [horizontal],
      );
      await config.init();
      expect(config.horizontalClickAreaPercent, 20);
      expect(await database.configDao.getConfigByKey(horizontal), isNull);
    },
  );

  test(
    'legacy sizes are bounded so the central menu remains reachable',
    () async {
      final database = await DatabaseInstance.instance;
      await database.configDao.setConfigByKey(
        'HorizontalClickAreaSize',
        '1000',
      );
      await database.configDao.setConfigByKey('VerticalClickAreaSize', '1');
      final config = _Config();
      addTearDown(config.dispose);
      await config.ready;
      expect(config.horizontalClickAreaPercent, 40);
      expect(config.verticalClickAreaPercent, 5);
    },
  );

  test('percentages persist independently and enter settings sync', () async {
    final database = await DatabaseInstance.instance;
    final config = _Config();
    addTearDown(config.dispose);
    await config.ready;
    config.horizontalClickAreaPercent = 40;
    config.verticalClickAreaPercent = 15;
    final deadline = DateTime.now().add(const Duration(seconds: 5));
    while (DateTime.now().isBefore(deadline)) {
      if ((await database.configDao.getConfigByKey(horizontal))?.value ==
              '40.0' &&
          (await database.configDao.getConfigByKey(vertical))?.value ==
              '15.0') {
        break;
      }
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    final restored = _Config();
    addTearDown(restored.dispose);
    await restored.ready;
    expect(restored.horizontalClickAreaPercent, 40);
    expect(restored.verticalClickAreaPercent, 15);
    final store = DatabaseInstance.syncStore;
    expect(
      (await store.pendingRecord(SyncCategory.settings, horizontal))?.value,
      {'value': '40.0'},
    );
    expect(
      (await store.pendingRecord(SyncCategory.settings, vertical))?.value,
      {'value': '15.0'},
    );
  });

  test(
    'invalid percentages cannot overlap the menu through settings or sync',
    () async {
      final database = await DatabaseInstance.instance;
      await database.configDao.setConfigByKey(horizontal, '80');
      await database.configDao.setConfigByKey(vertical, 'NaN');
      final config = _Config();
      addTearDown(config.dispose);
      await config.ready;
      expect(config.horizontalClickAreaPercent, 20);
      expect(config.verticalClickAreaPercent, 20);
      final store = DatabaseInstance.syncStore;
      for (final value in [4.0, 40.1, 80.0, double.nan, double.infinity]) {
        expect(
          () => config.horizontalClickAreaPercent = value,
          throwsArgumentError,
        );
        expect(
          () => config.verticalClickAreaPercent = value,
          throwsArgumentError,
        );
        for (final key in [horizontal, vertical]) {
          expect(
            () => store.validateRecords([
              SyncRecord(
                category: SyncCategory.settings,
                key: key,
                value: {'value': '$value'},
                deleted: false,
                version: const SyncVersion(
                  wall: 1,
                  logical: 0,
                  device: 'remote',
                ),
                uncertain: false,
              ),
            ]),
            throwsFormatException,
          );
        }
      }
      await store.calibrate(
        DateTime.now().millisecondsSinceEpoch,
        roundTrip: Duration.zero,
      );
      for (final key in [horizontal, vertical]) {
        await database.configDao.setConfigByKey(key, '20');
        final pending = await store.pendingRecord(SyncCategory.settings, key);
        await store.acknowledge(pending!, pending);
      }
      var wall = DateTime.now().millisecondsSinceEpoch + 1000;
      for (final value in [5, 20, 40]) {
        await store.receive([
          for (final key in [horizontal, vertical])
            SyncRecord(
              category: SyncCategory.settings,
              key: key,
              value: {'value': '$value'},
              deleted: false,
              version: SyncVersion(wall: wall++, logical: 0, device: 'remote'),
              uncertain: false,
            ),
        ]);
        await config.init();
        expect(config.horizontalClickAreaPercent, value);
        expect(config.verticalClickAreaPercent, value);
      }
    },
  );
}
