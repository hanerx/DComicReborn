import 'dart:async';
import 'dart:io';

import 'package:dcomic/database/database_instance.dart';
import 'package:dcomic/generated/l10n.dart';
import 'package:dcomic/providers/config_provider.dart';
import 'package:dcomic/providers/navigator_provider.dart';
import 'package:dcomic/providers/version_provider.dart';
import 'package:dcomic/view/settings/settings_main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _Config extends ConfigProvider {
  late Future<void> ready;
  @override
  Future<void> init() => ready = super.init();
}

class _Version extends VersionProvider {
  late Future<void> ready;
  @override
  Future<void> init() => ready = super.init();
  @override
  Future<bool> checkUpdate() async => false;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;

  setUpAll(() async {
    directory = await Directory.systemTemp.createTemp('experimental_unlock_');
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    await databaseFactory.setDatabasesPath(directory.path);
    PackageInfo.setMockInitialValues(
      appName: 'DComic',
      packageName: 'top.hanerx.dcomic',
      version: '2.5.1',
      buildNumber: '2',
      buildSignature: '',
    );
  });
  tearDownAll(() async {
    await (await DatabaseInstance.instance).close();
    await directory.delete(recursive: true);
  });

  testWidgets(
    'advanced settings can be unlocked, hidden persistently, and unlocked again',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1100));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      late _Config config;
      late _Version version;
      await tester.runAsync(() async {
        config = _Config();
        await config.ready;
        version = _Version();
        await version.ready;
        // Existing feature choices must survive hiding and unlocking the entry.
        await config.setAggregateReadingProgress(true);
      });
      addTearDown(config.dispose);
      addTearDown(version.dispose);

      Future<void> pumpSettings(_Config settings) async {
        await tester.pumpWidget(
          MultiProvider(
            key: ObjectKey(settings),
            providers: [
              ChangeNotifierProvider<ConfigProvider>.value(value: settings),
              ChangeNotifierProvider<VersionProvider>.value(value: version),
              ChangeNotifierProvider(
                create: (context) => NavigatorProvider(context),
              ),
            ],
            child: MaterialApp(
              locale: const Locale('en'),
              supportedLocales: S.delegate.supportedLocales,
              localizationsDelegates: const [
                S.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              home: const MainSettingPage(),
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      Future<void> tapAndSave(Finder target, _Config settings) async {
        await tester.runAsync(() async {
          final saved = Completer<void>();
          void changed() {
            if (!saved.isCompleted) saved.complete();
          }

          settings.addListener(changed);
          try {
            await tester.tap(target);
            await saved.future.timeout(const Duration(seconds: 5));
          } finally {
            settings.removeListener(changed);
          }
        });
        await tester.pumpAndSettle();
      }

      await pumpSettings(config);
      expect(find.text('Experimental Features'), findsNothing);
      expect(find.text('Debug Settings'), findsNothing);
      await tester.ensureVisible(find.text('About'));
      await tester.tap(find.text('About'));
      await tester.pumpAndSettle();
      final versionButton = find.widgetWithText(TextButton, '2.5.1');
      expect(versionButton, findsOneWidget);
      for (var i = 0; i < 6; i++) {
        await tester.tap(versionButton);
        await tester.pump();
      }
      await tester.runAsync(() async {
        final flag = await (await DatabaseInstance.instance).configDao
            .getConfigByKey('ExperimentalFeaturesUnlocked');
        expect(flag?.get<bool>() == true, isFalse);
      });

      await tapAndSave(versionButton, config);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Experimental Features'), findsOneWidget);
      expect(find.text('Debug Settings'), findsOneWidget);
      expect(config.aggregateReadingProgress, isTrue);
      expect(config.aggregateSubscribeBadges, isFalse);

      await tester.pumpWidget(const SizedBox.shrink());
      late _Config restarted;
      await tester.runAsync(() async {
        restarted = _Config();
        await restarted.ready;
      });
      addTearDown(restarted.dispose);
      await pumpSettings(restarted);
      await tester.ensureVisible(find.text('Experimental Features'));
      expect(find.text('Experimental Features'), findsOneWidget);
      expect(find.text('Debug Settings'), findsOneWidget);
      expect(restarted.aggregateReadingProgress, isTrue);
      expect(restarted.aggregateSubscribeBadges, isFalse);

      await tester.ensureVisible(find.text('Debug Settings'));
      await tester.tap(find.text('Debug Settings'));
      await tester.pumpAndSettle();
      final hideButton = find.text('Hide Debug and Experimental Settings');
      await tester.ensureVisible(hideButton);
      await tapAndSave(hideButton, restarted);
      // Saving returns to Settings and removes both entry points.
      expect(find.byType(MainSettingPage), findsOneWidget);
      expect(find.text('Experimental Features'), findsNothing);
      expect(find.text('Debug Settings'), findsNothing);
      expect(restarted.aggregateReadingProgress, isTrue);
      expect(restarted.aggregateSubscribeBadges, isFalse);

      await tester.pumpWidget(const SizedBox.shrink());
      late _Config hidden;
      await tester.runAsync(() async {
        hidden = _Config();
        await hidden.ready;
      });
      addTearDown(hidden.dispose);
      await pumpSettings(hidden);
      expect(find.text('Experimental Features'), findsNothing);
      expect(find.text('Debug Settings'), findsNothing);
      await tester.ensureVisible(find.text('About'));
      await tester.tap(find.text('About'));
      await tester.pumpAndSettle();
      for (var i = 0; i < 6; i++) {
        await tester.tap(versionButton);
        await tester.pump();
      }
      await tester.runAsync(() async {
        final flag = await (await DatabaseInstance.instance).configDao
            .getConfigByKey('ExperimentalFeaturesUnlocked');
        expect(flag?.get<bool>() == true, isFalse);
      });
      await tapAndSave(versionButton, hidden);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Experimental Features'), findsOneWidget);
      expect(find.text('Debug Settings'), findsOneWidget);
      expect(hidden.aggregateReadingProgress, isTrue);
      expect(hidden.aggregateSubscribeBadges, isFalse);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
