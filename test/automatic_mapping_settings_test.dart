import 'dart:async';
import 'dart:io';

import 'package:dcomic/database/database_instance.dart';
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
    directory = await Directory.systemTemp.createTemp('mapping_settings_');
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    await databaseFactory.setDatabasesPath(directory.path);
  });
  tearDownAll(() async {
    await (await DatabaseInstance.instance).close();
    await directory.delete(recursive: true);
  });

  testWidgets('numeric dialog can validate, save, and animate out safely', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    late _Config config;
    await tester.runAsync(() async {
      config = _Config();
      await config.ready;
      await config.setAggregateSubscribeBadges(true);
      await config.setAutoMapMissingComics(true);
    });
    addTearDown(config.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider<ConfigProvider>.value(
        value: config,
        child: const MaterialApp(home: ExperimentalFeaturesPage()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Search interval (seconds)'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '0');
    await tester.tap(find.text('Save'));
    await tester.pump();
    expect(find.text('Enter a whole number of at least 1'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '5');
    await tester.runAsync(() async {
      final saved = Completer<void>();
      void changed() {
        if (!saved.isCompleted) saved.complete();
      }

      config.addListener(changed);
      try {
        await tester.tap(find.text('Save'));
        final deadline = DateTime.now().add(const Duration(seconds: 5));
        // Real SQLite transactions can complete between fake-async frames.
        // Keep both zones moving until the provider publishes the saved value.
        while (!saved.isCompleted && DateTime.now().isBefore(deadline)) {
          await tester.pump();
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
        await saved.future.timeout(const Duration(milliseconds: 1));
      } finally {
        config.removeListener(changed);
      }
    });
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('5 s'), findsOneWidget);
    await tester.runAsync(() async {
      final reloaded = _Config();
      await reloaded.ready;
      expect(reloaded.autoMapIntervalSeconds, 5);
      reloaded.dispose();
    });
  });
}
