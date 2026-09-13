import 'dart:io';

import 'package:dcomic/database/database_common.dart';
import 'package:dcomic/database/database_instance.dart';
import 'package:dcomic/database/entity/config.dart';
import 'package:dcomic/generated/l10n.dart';
import 'package:dcomic/providers/version_provider.dart';
import 'package:dcomic/view/settings/about_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _AvailableUpdateProvider extends VersionProvider {
  late Future<void> ready;

  @override
  Future<void> init() => ready = super.init();

  @override
  Future<bool> checkUpdate() async => true;

  @override
  Future<ReleaseInfo?> getLatestUpdateInfo() async =>
      ReleaseInfo('2.6.0', '', '', '');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late DComicDatabase database;

  setUpAll(() async {
    directory = await Directory.systemTemp.createTemp('version_provider_');
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    await databaseFactory.setDatabasesPath(directory.path);
    database = await DatabaseInstance.instance;
    PackageInfo.setMockInitialValues(
      appName: 'DComic',
      packageName: 'top.hanerx.dcomic',
      version: '2.5.0',
      buildNumber: '1',
      buildSignature: '',
    );
  });

  setUp(() async {
    await database.database.delete('ConfigEntity');
  });

  tearDownAll(() async {
    await database.close();
    await directory.delete(recursive: true);
  });

  test(
    'update notification preserves the selected channel across restarts',
    () async {
      await database.configDao.insertConfig(
        ConfigEntity.createConfigEntity('UpdateChannel', UpdateChannel.develop),
      );
      final first = _AvailableUpdateProvider();
      await first.ready;
      expect(first.needShowUpdateDialog, isTrue);
      expect(
        (await database.configDao.getConfigByKey('UpdateChannel'))!.value,
        UpdateChannel.develop.index.toString(),
      );
      first.dispose();

      final restarted = _AvailableUpdateProvider();
      await restarted.ready;
      expect(restarted.channel, UpdateChannel.develop);
      expect(restarted.needShowUpdateDialog, isFalse);
      restarted.dispose();
    },
  );

  testWidgets(
    'about page opens after recovering a channel overwritten by a version',
    (tester) async {
      late _AvailableUpdateProvider version;
      await tester.runAsync(() async {
        await database.configDao.insertConfig(
          ConfigEntity(null, 'UpdateChannel', '2.6.0'),
        );
        version = _AvailableUpdateProvider();
        await version.ready;
        addTearDown(version.dispose);
        expect(
          (await database.configDao.getConfigByKey('UpdateChannel'))!.value,
          '0',
        );
        expect(version.channel, UpdateChannel.release);
        expect(version.needShowUpdateDialog, isFalse);
      });

      await tester.pumpWidget(
        ChangeNotifierProvider<VersionProvider>.value(
          value: version,
          child: MaterialApp(
            locale: const Locale('en'),
            supportedLocales: S.delegate.supportedLocales,
            localizationsDelegates: const [
              S.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: const AboutPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Update Channel'), findsOneWidget);
      expect(find.text('Release'), findsOneWidget);
      await tester.runAsync(() async {
        await tester.tap(find.text('Update Channel'));
        await database.configDao.getAllConfig();
      });
      await tester.pumpAndSettle();
      expect(find.text('Beta'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
