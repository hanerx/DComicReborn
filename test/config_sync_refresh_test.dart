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

  test('reader end action survives reload and participates in settings sync', () async {
    final database = await DatabaseInstance.instance;
    final config = _Config();
    addTearDown(config.dispose);
    await config.ready;

    for (final action in [
      ReaderEndAction.nextChapter,
      ReaderEndAction.comments,
    ]) {
      config.readerEndAction = action;
      final deadline = DateTime.now().add(const Duration(seconds: 5));
      ConfigEntity? saved;
      do {
        saved = await database.configDao.getConfigByKey('ReaderEndAction');
        if (saved?.get<String>() == action.name) break;
        await Future<void>.delayed(const Duration(milliseconds: 10));
      } while (DateTime.now().isBefore(deadline));
      expect(saved?.get<String>(), action.name);

      final restored = _Config();
      addTearDown(restored.dispose);
      await restored.ready;
      expect(restored.readerEndAction, action);
      final record = await DatabaseInstance.syncStore.pendingRecord(
        SyncCategory.settings, 'ReaderEndAction',
      );
      expect(record?.value, {'value': action.name});
    }
  });

  test(
    'resume last-read page defaults off, persists independently, and refreshes',
    () async {
      final database = await DatabaseInstance.instance;
      await database.database.delete(
        'ConfigEntity',
        where: 'key = ?',
        whereArgs: ['ResumeLastReadPage'],
      );
      final config = _Config();
      addTearDown(config.dispose);
      await config.ready;

      expect(config.resumeLastReadPage, isFalse);
      expect(config.aggregateReadingProgress, isFalse);

      await config.setResumeLastReadPage(true);
      expect(config.resumeLastReadPage, isTrue);
      expect(config.aggregateReadingProgress, isFalse);
      final stored = await database.configDao.getConfigByKey(
        'ResumeLastReadPage',
      );
      expect(stored?.get<bool>(), isTrue);
      final record = await DatabaseInstance.syncStore.pendingRecord(
        SyncCategory.settings,
        'ResumeLastReadPage',
      );
      expect(record?.value, {'value': '1'});

      final restored = _Config();
      addTearDown(restored.dispose);
      await restored.ready;
      expect(restored.resumeLastReadPage, isTrue);
      expect(restored.aggregateReadingProgress, isFalse);

      stored!.set(false);
      await database.configDao.updateConfig(stored);
      await restored.init();
      expect(restored.resumeLastReadPage, isFalse);
    },
  );
}
