import 'dart:io';

import 'package:dcomic/database/database_instance.dart';
import 'package:dcomic/database/entity/config.dart';
import 'package:dcomic/database/sync/sync_models.dart';
import 'package:dcomic/generated/l10n.dart';
import 'package:dcomic/providers/config_provider.dart';
import 'package:dcomic/providers/models/comic_source_model.dart';
import 'package:dcomic/providers/page_controllers/comic_viewer_page_controller.dart';
import 'package:dcomic/utils/reader_image_fit.dart';
import 'package:dcomic/view/components/viewer_setting_list.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _Config extends ConfigProvider {
  late Future<void> ready;

  @override
  Future<void> init() => ready = super.init();
}

class _MemoryConfig extends ConfigProvider {
  @override
  Future<void> init() async {}

  @override
  ReadDirectionType get readDirection => ReadDirectionType.right;

  ReaderImageFit _horizontalImageFit = ReaderImageFit.original;
  ReaderImageFit _verticalImageFit = ReaderImageFit.original;

  @override
  ReaderImageFit get horizontalImageFit => _horizontalImageFit;

  @override
  set horizontalImageFit(ReaderImageFit value) {
    _horizontalImageFit = value;
    notifyListeners();
  }

  @override
  ReaderImageFit get verticalImageFit => _verticalImageFit;

  @override
  set verticalImageFit(ReaderImageFit value) {
    _verticalImageFit = value;
    notifyListeners();
  }
}

class _LongComicViewer extends Fake implements ComicViewerPageController {
  @override
  final BaseComicDetailModel detailModel = _LongComicDetail();

  @override
  ReadDirectionType effectiveReadDirection(ReadDirectionType preference) =>
      detailModel.isLongComic ? ReadDirectionType.vertical : preference;
}

class _LongComicDetail extends Fake implements BaseComicDetailModel {
  @override
  bool get isLongComic => true;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;

  setUpAll(() async {
    directory = await Directory.systemTemp.createTemp('reader_image_fit_');
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    await databaseFactory.setDatabasesPath(directory.path);
  });

  tearDownAll(() async {
    await (await DatabaseInstance.instance).close();
    await directory.delete(recursive: true);
  });

  test(
    'horizontal and vertical image fits persist and reload independently',
    () async {
      final database = await DatabaseInstance.instance;
      final config = _Config();
      addTearDown(config.dispose);
      await config.ready;

      expect(config.horizontalImageFit, ReaderImageFit.original);
      expect(config.verticalImageFit, ReaderImageFit.original);

      config.horizontalImageFit = ReaderImageFit.cover;
      config.verticalImageFit = ReaderImageFit.fitWidth;

      final deadline = DateTime.now().add(const Duration(seconds: 5));
      ConfigEntity? horizontal;
      ConfigEntity? vertical;
      do {
        horizontal = await database.configDao.getConfigByKey(
          'HorizontalImageFit',
        );
        vertical = await database.configDao.getConfigByKey('VerticalImageFit');
        if (horizontal?.get<String>() == ReaderImageFit.cover.name &&
            vertical?.get<String>() == ReaderImageFit.fitWidth.name) {
          break;
        }
        await Future<void>.delayed(const Duration(milliseconds: 10));
      } while (DateTime.now().isBefore(deadline));

      expect(horizontal?.get<String>(), ReaderImageFit.cover.name);
      expect(vertical?.get<String>(), ReaderImageFit.fitWidth.name);
      final horizontalRecord = await DatabaseInstance.syncStore.pendingRecord(
        SyncCategory.settings,
        'HorizontalImageFit',
      );
      final verticalRecord = await DatabaseInstance.syncStore.pendingRecord(
        SyncCategory.settings,
        'VerticalImageFit',
      );
      expect(horizontalRecord?.value, {'value': ReaderImageFit.cover.name});
      expect(verticalRecord?.value, {'value': ReaderImageFit.fitWidth.name});

      final restored = _Config();
      addTearDown(restored.dispose);
      await restored.ready;
      expect(restored.horizontalImageFit, ReaderImageFit.cover);
      expect(restored.verticalImageFit, ReaderImageFit.fitWidth);
    },
  );

  test(
    'direction-specific invalid persisted fits fall back to original',
    () async {
      final database = await DatabaseInstance.instance;
      await database.configDao.setConfigByKey(
        'HorizontalImageFit',
        ReaderImageFit.fitWidth.name,
      );
      await database.configDao.setConfigByKey(
        'VerticalImageFit',
        ReaderImageFit.fitHeight.name,
      );

      final config = _Config();
      addTearDown(config.dispose);
      await config.ready;

      expect(config.horizontalImageFit, ReaderImageFit.original);
      expect(config.verticalImageFit, ReaderImageFit.original);
    },
  );

  test('remote image fits apply and refresh independently', () async {
    final database = await DatabaseInstance.instance;
    final store = DatabaseInstance.syncStore;
    await store.calibrate(
      DateTime.now().millisecondsSinceEpoch,
      roundTrip: Duration.zero,
    );
    await database.configDao.setConfigByKey(
      'HorizontalImageFit',
      ReaderImageFit.original.name,
    );
    await database.configDao.setConfigByKey(
      'VerticalImageFit',
      ReaderImageFit.original.name,
    );
    for (final key in ['HorizontalImageFit', 'VerticalImageFit']) {
      final local = await store.pendingRecord(SyncCategory.settings, key);
      await store.acknowledge(local!, local);
    }

    final wall = DateTime.now().millisecondsSinceEpoch + 1000;
    await store.receive([
      SyncRecord(
        category: SyncCategory.settings,
        key: 'HorizontalImageFit',
        value: {'value': ReaderImageFit.contain.name},
        deleted: false,
        version: SyncVersion(wall: wall, logical: 0, device: 'remote'),
        uncertain: false,
      ),
      SyncRecord(
        category: SyncCategory.settings,
        key: 'VerticalImageFit',
        value: {'value': ReaderImageFit.fitWidth.name},
        deleted: false,
        version: SyncVersion(wall: wall, logical: 0, device: 'remote'),
        uncertain: false,
      ),
    ]);

    final config = _Config();
    addTearDown(config.dispose);
    await config.ready;
    expect(config.horizontalImageFit, ReaderImageFit.contain);
    expect(config.verticalImageFit, ReaderImageFit.fitWidth);
  });

  testWidgets(
    'settings strips support mouse and touch drag without selecting',
    (tester) async {
      final config = _MemoryConfig();
      addTearDown(config.dispose);
      await tester.pumpWidget(
        ChangeNotifierProvider<ConfigProvider>.value(
          value: config,
          child: MaterialApp(
            locale: const Locale('en'),
            supportedLocales: S.delegate.supportedLocales,
            localizationsDelegates: const [
              S.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: const Scaffold(
              body: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(width: 260, child: ViewerSettingList()),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final bars = tester
          .widgetList<SingleChildScrollView>(
            find.byWidgetPredicate(
              (widget) =>
                  widget is SingleChildScrollView &&
                  widget.scrollDirection == Axis.horizontal,
            ),
          )
          .toList();
      for (final bar in bars) {
        final finder = find.byWidget(bar);
        await tester.ensureVisible(finder);
        await tester.pumpAndSettle();
        final position = tester
            .state<ScrollableState>(
              find
                  .descendant(of: finder, matching: find.byType(Scrollable))
                  .first,
            )
            .position;
        expect(position.maxScrollExtent, greaterThan(0));
        await tester.drag(
          finder,
          const Offset(-100, 0),
          kind: PointerDeviceKind.mouse,
        );
        await tester.pumpAndSettle();
        final mouseOffset = position.pixels;
        expect(mouseOffset, greaterThan(0));
        await tester.drag(
          finder,
          const Offset(80, 0),
          kind: PointerDeviceKind.touch,
        );
        await tester.pumpAndSettle();
        expect(position.pixels, lessThan(mouseOffset));
      }
      expect(config.horizontalImageFit, ReaderImageFit.original);
      expect(config.verticalImageFit, ReaderImageFit.original);
      final heightOption = find.byTooltip('Fit height');
      await tester.ensureVisible(heightOption);
      await tester.pumpAndSettle();
      await tester.tap(heightOption, kind: PointerDeviceKind.mouse);
      await tester.pumpAndSettle();
      expect(config.horizontalImageFit, ReaderImageFit.fitHeight);
      expect(config.verticalImageFit, ReaderImageFit.original);
    },
  );

  testWidgets('long comics enable only the effective vertical fit selector', (
    tester,
  ) async {
    final config = _MemoryConfig();
    final viewer = _LongComicViewer();
    addTearDown(config.dispose);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<ConfigProvider>.value(value: config),
          InheritedProvider<ComicViewerPageController>.value(value: viewer),
        ],
        child: MaterialApp(
          locale: Locale('en'),
          supportedLocales: S.delegate.supportedLocales,
          localizationsDelegates: [
            S.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: Scaffold(body: ViewerSettingList()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final horizontalCover = find.byTooltip('Cover').first;
    await tester.ensureVisible(horizontalCover);
    await tester.tap(horizontalCover);
    await tester.pumpAndSettle();
    expect(config.horizontalImageFit, ReaderImageFit.original);

    final verticalCover = find.byTooltip('Cover').last;
    await tester.ensureVisible(verticalCover);
    await tester.tap(verticalCover);
    await tester.pumpAndSettle();
    expect(config.verticalImageFit, ReaderImageFit.cover);
    expect(find.text('Cover'), findsOneWidget);

    config.verticalImageFit = ReaderImageFit.fitWidth;
    await tester.pumpAndSettle();
    expect(find.text('Fit width'), findsOneWidget);
    expect(find.text('Cover'), findsNothing);
  });
}
