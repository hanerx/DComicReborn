import 'dart:io';

import 'package:dcomic/database/database_instance.dart';
import 'package:dcomic/database/entity/config.dart';
import 'package:dcomic/database/sync/sync_models.dart';
import 'package:dcomic/providers/config_provider.dart';
import 'package:dcomic/utils/reader_info_settings.dart';
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

  setUpAll(() async {
    directory = await Directory.systemTemp.createTemp('reader_info_settings_');
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    await databaseFactory.setDatabasesPath(directory.path);
  });

  tearDownAll(() async {
    await (await DatabaseInstance.instance).close();
    await directory.delete(recursive: true);
  });

  test('reader information settings persist by enum name and reload', () async {
    final database = await DatabaseInstance.instance;
    final config = _Config();
    addTearDown(config.dispose);
    await config.ready;

    config.readerInfoEnabled = true;
    config.readerInfoPosition = ReaderInfoPosition.topLeft;
    config.readerBatteryFormat = ReaderBatteryFormat.number;
    config.readerPageFormat = ReaderPageFormat.percentage;
    config.readerInfoChapter = false;
    config.readerInfoTime = false;

    final expected = <String, String>{
      'ReaderInfoEnabled': '1',
      'ReaderInfoPosition': ReaderInfoPosition.topLeft.name,
      'ReaderBatteryFormat': ReaderBatteryFormat.number.name,
      'ReaderPageFormat': ReaderPageFormat.percentage.name,
      'ReaderInfoChapter': '0',
      'ReaderInfoTime': '0',
    };
    final deadline = DateTime.now().add(const Duration(seconds: 5));
    var saved = <String, ConfigEntity?>{};
    do {
      saved = {
        for (final key in expected.keys)
          key: await database.configDao.getConfigByKey(key),
      };
      if (expected.entries.every(
        (entry) => saved[entry.key]?.value == entry.value,
      )) {
        break;
      }
      await Future<void>.delayed(const Duration(milliseconds: 10));
    } while (DateTime.now().isBefore(deadline));
    for (final entry in expected.entries) {
      expect(saved[entry.key]?.value, entry.value, reason: entry.key);
      final record = await DatabaseInstance.syncStore.pendingRecord(
        SyncCategory.settings,
        entry.key,
      );
      expect(record?.value, {'value': entry.value}, reason: entry.key);
    }

    final restored = _Config();
    addTearDown(restored.dispose);
    await restored.ready;
    expect(restored.readerInfoEnabled, isTrue);
    expect(restored.readerInfoPosition, ReaderInfoPosition.topLeft);
    expect(restored.readerBatteryFormat, ReaderBatteryFormat.number);
    expect(restored.readerPageFormat, ReaderPageFormat.percentage);
    expect(restored.readerInfoChapter, isFalse);
    expect(restored.readerInfoTime, isFalse);
  });
}
