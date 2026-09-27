import 'dart:io';

import 'package:dcomic/database/database_instance.dart';
import 'package:dcomic/database/entity/config.dart';
import 'package:dcomic/database/sync/sync_models.dart';
import 'package:dcomic/providers/config_provider.dart';
import 'package:flutter/material.dart';
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
    directory = await Directory.systemTemp.createTemp('config_sync_refresh_');
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    await databaseFactory.setDatabasesPath(directory.path);
  });

  tearDownAll(() async {
    await (await DatabaseInstance.instance).close();
    await directory.delete(recursive: true);
  });

  test('refresh preserves deleted settings and explicit edits recreate them', () async {
    final database = await DatabaseInstance.instance;
    await database.configDao.insertConfig(
      ConfigEntity.createConfigEntity('ThemeMode', ThemeMode.dark),
    );
    final config = _Config();
    addTearDown(config.dispose);
    await config.ready;
    expect(config.themeMode, ThemeMode.dark);

    await database.database.delete(
      'ConfigEntity',
      where: 'key = ?',
      whereArgs: ['ThemeMode'],
    );
    await config.init();
    expect(config.themeMode, ThemeMode.system);
    expect(await database.configDao.getConfigByKey('ThemeMode'), isNull);
    final tombstone = await DatabaseInstance.syncStore.pendingRecord(
      SyncCategory.settings, 'ThemeMode',
    );
    expect(tombstone?.deleted, isTrue);

    config.themeMode = ThemeMode.light;
    final deadline = DateTime.now().add(const Duration(seconds: 5));
    ConfigEntity? restored;
    do {
      restored = await database.configDao.getConfigByKey('ThemeMode');
      if (restored?.get<int>() == ThemeMode.light.index) break;
      await Future<void>.delayed(const Duration(milliseconds: 10));
    } while (DateTime.now().isBefore(deadline));
    expect(restored?.get<int>(), ThemeMode.light.index);
  });
}
