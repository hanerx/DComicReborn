import 'dart:io';

import 'package:dcomic/database/database_instance.dart';
import 'package:dcomic/database/setting_sync_contract.dart';
import 'package:dcomic/providers/config_provider.dart';
import 'package:dcomic/view/settings/experimental_features_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
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
    directory = await Directory.systemTemp.createTemp(
      'download_aggregation_settings_',
    );
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    await databaseFactory.setDatabasesPath(directory.path);
  });

  setUp(() async {
    final database = await DatabaseInstance.instance;
    await database.database.delete(
      'ConfigEntity',
      where: 'key IN (?, ?)',
      whereArgs: const [
        'AggregateDownloads',
        'ReuseDownloadedChaptersAcrossSources',
      ],
    );
  });

  tearDownAll(() async {
    await (await DatabaseInstance.instance).close();
    await directory.delete(recursive: true);
  });

  test(
    'download aggregation defaults persist independently and notify listeners',
    () async {
      final config = _Config();
      addTearDown(config.dispose);
      await config.ready;
      expect(config.aggregateDownloads, isFalse);
      expect(config.reuseDownloadedChaptersAcrossSources, isTrue);

      var notifications = 0;
      config.addListener(() => notifications++);
      await config.setReuseDownloadedChaptersAcrossSources(false);
      await config.setAggregateDownloads(true);
      expect(notifications, 2);

      final restored = _Config();
      addTearDown(restored.dispose);
      await restored.ready;
      expect(restored.aggregateDownloads, isTrue);
      expect(restored.reuseDownloadedChaptersAcrossSources, isFalse);

      final database = await DatabaseInstance.instance;
      expect(
        (await database.configDao.getConfigByKey('AggregateDownloads'))
            ?.get<bool>(),
        isTrue,
      );
      expect(
        (await database.configDao.getConfigByKey(
          'ReuseDownloadedChaptersAcrossSources',
        ))?.get<bool>(),
        isFalse,
      );
    },
  );

  test('download aggregation settings are explicitly device-local', () {
    for (final key in const [
      'AggregateDownloads',
      'ReuseDownloadedChaptersAcrossSources',
    ]) {
      final definition = appSettingDefinition(key);
      expect(definition.mode, SettingSyncMode.localOnly);
      expect(definition.localOnlyReason, isNotEmpty);
    }
  });

  testWidgets(
    'reuse switch is disabled while aggregation is off and preserves its value',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(900, 1800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      late _Config config;
      await tester.runAsync(() async {
        config = _Config();
        await config.ready;
      });
      addTearDown(config.dispose);
      expect(config.reuseDownloadedChaptersAcrossSources, isTrue);

      await tester.pumpWidget(
        ChangeNotifierProvider<ConfigProvider>.value(
          value: config,
          child: const MaterialApp(home: ExperimentalFeaturesPage()),
        ),
      );
      await tester.pumpAndSettle();

      final childSwitch = find.byKey(
        const ValueKey('reuseDownloadedChaptersAcrossSourcesSwitch'),
      );
      expect(tester.widget<Switch>(childSwitch).value, isTrue);
      expect(tester.widget<Switch>(childSwitch).onChanged, isNull);

      await tester.runAsync(() => config.setAggregateDownloads(true));
      await tester.pumpAndSettle();
      expect(config.reuseDownloadedChaptersAcrossSources, isTrue);
      expect(tester.widget<Switch>(childSwitch).onChanged, isNotNull);
    },
  );
}
