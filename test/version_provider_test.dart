import 'dart:io';

import 'package:dcomic/database/database_common.dart';
import 'package:dcomic/database/database_instance.dart';
import 'package:dcomic/database/entity/config.dart';
import 'package:dcomic/downloads/update_download.dart' as update_download;
import 'package:dcomic/downloads/update_download.dart'
    show ReleaseInfo, UpdateTargetPlatform, releaseInfoFromGithub;
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

Map<String, Object?> _releaseWithAssets(List<Map<String, Object?>> assets) => {
  'tag_name': 'v2.6.0',
  'body': 'Changes',
  'html_url': 'https://github.com/hanerx/dcomic/releases/tag/v2.6.0',
  'assets': assets,
};

Map<String, Object?> _asset(
  String name, {
  int size = 1024,
  String? digest =
      'sha256:0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
}) => {
  'name': name,
  'browser_download_url':
      'https://github.com/hanerx/dcomic/releases/download/v2.6.0/$name',
  'size': size,
  'digest': digest,
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('GitHub release asset selection', () {
    test('selects the Android APK and parses its integrity metadata', () {
      final info = releaseInfoFromGithub(
        _releaseWithAssets([
          _asset('DComic-windows-setup.exe'),
          _asset('DComic-android.apk', size: 2048),
        ]),
        UpdateTargetPlatform.android,
      );

      expect(info, isNotNull);
      expect(info!.fileName, 'DComic-android.apk');
      expect(info.updateUrl, endsWith('/DComic-android.apk'));
      expect(info.expectedBytes, 2048);
      expect(
        info.sha256Hex,
        '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
      );
    });

    test('selects a Windows setup executable instead of another executable', () {
      final info = releaseInfoFromGithub(
        _releaseWithAssets([
          _asset('DComic-portable.exe'),
          _asset('DComic-windows-setup.exe'),
        ]),
        UpdateTargetPlatform.windows,
      );

      expect(info!.fileName, 'DComic-windows-setup.exe');
    });

    test('selects the macOS universal DMG', () {
      final info = releaseInfoFromGithub(
        _releaseWithAssets([
          _asset('DComic-macos-arm64.dmg'),
          _asset('DComic-macos-universal.dmg'),
        ]),
        UpdateTargetPlatform.macos,
      );

      expect(info!.fileName, 'DComic-macos-universal.dmg');
    });

    test('selects the iOS IPA', () {
      final info = releaseInfoFromGithub(
        _releaseWithAssets([
          _asset('DComic-android.apk'),
          _asset('DComic-ios.ipa'),
        ]),
        UpdateTargetPlatform.ios,
      );

      expect(info!.fileName, 'DComic-ios.ipa');
    });

    test('does not trust a missing or malformed SHA-256 digest', () {
      final missing = releaseInfoFromGithub(
        _releaseWithAssets([_asset('DComic.apk', digest: null)]),
        UpdateTargetPlatform.android,
      );
      final malformed = releaseInfoFromGithub(
        _releaseWithAssets([
          _asset('DComic.apk', digest: 'sha256:1234'),
        ]),
        UpdateTargetPlatform.android,
      );
      final wrongAlgorithm = releaseInfoFromGithub(
        _releaseWithAssets([
          _asset(
            'DComic.apk',
            digest:
                'sha512:0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
          ),
        ]),
        UpdateTargetPlatform.android,
      );

      expect(missing!.sha256Hex, isNull);
      expect(malformed!.sha256Hex, isNull);
      expect(wrongAlgorithm!.sha256Hex, isNull);
    });
  });
  group('update download request', () {
    test('uses a stable version and platform identity with release integrity', () {
      const release = ReleaseInfo(
        'v2.6.0',
        'https://example.com/DComic.apk',
        '',
        'https://example.com/release',
        fileName: 'DComic.apk',
        expectedBytes: 2048,
        sha256Hex:
            '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
      );

      final request = update_download.buildUpdateDownloadRequest(
        release,
        UpdateTargetPlatform.android,
      );

      expect(request.id, 'app-update:android:v2.6.0');
      expect(
        request.relativePath,
        'updates/android/v2.6.0/DComic.apk',
      );
      expect(request.group, 'app-update');
      expect(request.displayName, 'DComic.apk');
      expect(request.integrity.expectedBytes, 2048);
      expect(request.integrity.sha256Hex, release.sha256Hex);
    });

    test('rejects a release without a trusted SHA-256 digest', () {
      const release = ReleaseInfo(
        'v2.6.0',
        'https://example.com/DComic.apk',
        '',
        'https://example.com/release',
        fileName: 'DComic.apk',
        expectedBytes: 2048,
      );

      expect(
        () => update_download.buildUpdateDownloadRequest(
          release,
          UpdateTargetPlatform.android,
        ),
        throwsStateError,
      );
    });
  });


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
