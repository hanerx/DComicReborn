import 'dart:io';

import 'package:dcomic/database/database_instance.dart';
import 'package:dcomic/generated/l10n.dart';
import 'package:dcomic/providers/config_provider.dart';
import 'package:dcomic/providers/models/comic_source_model.dart';
import 'package:dcomic/providers/navigator_provider.dart';
import 'package:dcomic/providers/page_controllers/comic_detail_page_controller.dart';
import 'package:dcomic/providers/page_controllers/comic_viewer_page_controller.dart';
import 'package:dcomic/providers/source_provider.dart';
import 'package:dcomic/utils/image_utils.dart';
import 'package:dcomic/view/comic_pages/comic_detail_page.dart';
import 'package:dcomic/view/comic_viewer/comic_viewer_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _Config extends ConfigProvider {
  @override
  Future<void> init() async {}

  @override
  bool get resumeLastReadPage => true;
}

class _Sources extends ComicSourceProvider {
  _Sources(BaseComicSourceModel source) {
    sources = [source];
  }
  @override
  Future<void> init() async {}
}

class _Source extends BaseComicSourceModel {
  late _Detail detail;
  int detailRequests = 0;
  @override
  Future<void> init() async {}
  @override
  ComicSourceEntity get type =>
      ComicSourceEntity('Return smoke', 'reader-return');
  @override
  Future<BaseComicDetailModel?> getComicDetail(
    String comicId,
    String title,
  ) async {
    detailRequests++;
    return detail;
  }

  @override
  Future<List<ComicListItemEntity>> searchComicDetail(
    String keyword, {
    int page = 0,
  }) async => [];
}

class _Chapter extends BaseComicChapterDetailModel {
  _Chapter(this.chapterId);
  @override
  final String chapterId;
  @override
  String get title => chapterId;
  @override
  final pages = List.generate(
    12,
    (_) => ImageEntity(ImageType.asset, 'assets/sources/copymanga.png'),
  );
  @override
  Future<List<ChapterCommentEntity>> getChapterComments() async => [];
}

class _Detail extends BaseComicDetailModel {
  _Detail(this.parent);
  @override
  final BaseComicSourceModel parent;
  @override
  String get comicId => 'reader-return-book';
  @override
  String get title => 'Return Book';
  @override
  ImageEntity get cover =>
      ImageEntity(ImageType.asset, 'assets/sources/copymanga.png');
  @override
  DateTime get lastUpdate => DateTime(2026);
  @override
  final chapters = {
    'Main': List<BaseComicChapterEntityModel>.generate(
      30,
      (i) =>
          DefaultComicChapterEntityModel('第 ${i + 1} 话', '$i', DateTime(2026)),
    ),
  };
  @override
  String get description =>
      'A description that must remain on the detail page.';
  @override
  String get status => 'ongoing';
  @override
  List<CategoryEntity> get authors => [];
  @override
  List<CategoryEntity> get categories => [];
  @override
  Future<BaseComicChapterDetailModel?> getChapter(String chapterId) async =>
      _Chapter(chapterId);
  @override
  Future<List<ComicCommentEntity>> getComments({int page = 0}) async => [];
}

Future<void> _waitFor(WidgetTester tester, bool Function() condition) async {
  for (var i = 0; i < 100 && !condition(); i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump(const Duration(milliseconds: 50));
  }
  expect(condition(), isTrue);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  setUpAll(() async {
    directory = await Directory.systemTemp.createTemp('reader_return_');
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    await databaseFactory.setDatabasesPath(directory.path);
  });
  setUp(() async {
    await (await DatabaseInstance.instance).database.delete(
      'ComicHistoryEntity',
    );
  });
  tearDownAll(() async {
    await (await DatabaseInstance.instance).close();
    await directory.delete(recursive: true);
  });

  for (final entry in ['grid', 'list', 'start', 'continue']) {
    testWidgets(
      '$entry returns with updated history without reloading details or losing scroll',
      (tester) async {
        tester.view.physicalSize = const Size(400, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        late _Source source;
        late _Detail detail;
        await tester.runAsync(() async {
          source = _Source();
          detail = source.detail = _Detail(source);
          addTearDown(detail.dispose);
          addTearDown(source.dispose);
          await detail.init();
          if (entry != 'start') {
            await detail.addComicHistory('8', '第 9 话', page: 6);
            await detail.loadComicHistory();
          }
        });
        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<ConfigProvider>(create: (_) => _Config()),
              ChangeNotifierProvider<ComicSourceProvider>(
                create: (_) => _Sources(source),
              ),
              ChangeNotifierProvider<NavigatorProvider>(
                create: (context) => NavigatorProvider(context),
              ),
            ],
            child: MaterialApp(
              locale: const Locale('zh'),
              supportedLocales: S.delegate.supportedLocales,
              localizationsDelegates: const [
                S.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              home: ComicDetailPage(
                title: detail.title,
                comicId: detail.comicId,
                comicSourceModel: source,
              ),
            ),
          ),
        );
        await tester.pump();
        final detailContext = tester.element(
          find.byType(CustomScrollView).first,
        );
        final controller = detailContext.read<ComicDetailPageController>();
        await _waitFor(
          tester,
          () => controller.loadState == ComicDetailLoadState.ready,
        );
        controller.reverse = false;
        controller.nest = entry != 'list';
        await tester.pumpAndSettle();
        final scrollFinder = find
            .descendant(
              of: find.byType(CustomScrollView).first,
              matching: find.byType(Scrollable),
            )
            .first;
        final scroll = tester.state<ScrollableState>(scrollFinder).position;
        await tester.ensureVisible(find.text('第 9 话'));
        await tester.pumpAndSettle();
        final offset = scroll.pixels;
        expect(offset, greaterThan(0));
        final states = <ComicDetailLoadState>[];
        controller.addListener(() => states.add(controller.loadState));
        await tester.tap(
          find.text(
            entry == 'start'
                ? '开始阅读'
                : entry == 'continue'
                ? '继续阅读'
                : '第 9 话',
          ),
        );
        await _waitFor(
          tester,
          () => find.byType(ComicViewerPage).evaluate().isNotEmpty,
        );
        expect(find.byType(ComicViewerPage), findsOneWidget);
        final reader = tester
            .element(find.byType(PageView))
            .read<ComicViewerPageController>();
        await _waitFor(tester, () => reader.chapterDetailModel != null);
        await tester.pumpAndSettle();
        if (entry != 'start') {
          expect(reader.currentPage, 5);
          expect(
            tester.widget<PageView>(find.byType(PageView)).controller!.page,
            5,
          );
        }
        var saved = false;
        reader
            .loadChapter(detail.chapters.values.single[10])
            .then((_) => reader.addComicHistory())
            .then((_) => saved = true);
        await _waitFor(tester, () => saved);
        await tester.binding.handlePopRoute();
        await tester.pump(const Duration(milliseconds: 500));
        await _waitFor(
          tester,
          () => controller.loadState == ComicDetailLoadState.ready,
        );
        expect(
          source.detailRequests,
          1,
          reason: 'Returning must not fetch the whole detail again.',
        );
        expect(states, isNot(contains(ComicDetailLoadState.loading)));
        expect(controller.detailModel, same(detail));
        await _waitFor(tester, () => controller.latestChapterId == '10');
        expect(scroll.pixels, closeTo(offset, 0.5));
        expect(find.text('继续阅读'), findsOneWidget);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  test('history reads wait for already queued chapter writes', () async {
    final source = _Source();
    final detail = _Detail(source);
    var writes = <Future<bool>>[];
    try {
      await detail.init();
      writes = [
        detail.addComicHistory('8', '第 9 话'),
        detail.addComicHistory('10', '第 11 话'),
      ];
      await detail.loadComicHistory();
      expect(detail.latestChapterId, '10');
    } finally {
      await Future.wait(writes);
      detail.dispose();
      source.dispose();
    }
  });
}
