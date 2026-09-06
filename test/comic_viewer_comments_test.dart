import 'package:dcomic/generated/l10n.dart';
import 'package:dcomic/providers/config_provider.dart';
import 'package:dcomic/providers/models/comic_source_model.dart';
import 'package:dcomic/utils/image_utils.dart';
import 'package:dcomic/utils/theme_utils.dart';
import 'package:dcomic/view/components/viewer_setting_list.dart';
import 'package:dcomic/view/comic_viewer/comic_viewer_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class _Config extends ConfigProvider {
  _Config(this.direction);
  final ReadDirectionType direction;
  @override
  Future<void> init() async {}
  @override
  ReadDirectionType get readDirection => direction;
  ReaderTheme _readerTheme = ReaderTheme.app;
  @override
  ReaderTheme get readerTheme => _readerTheme;
  @override
  set readerTheme(ReaderTheme value) {
    _readerTheme = value;
    notifyListeners();
  }
}

class _Chapter extends Fake implements BaseComicChapterEntityModel {
  _Chapter([this.chapterId = 'chapter']);
  @override
  final String chapterId;
  @override
  String get title => 'Chapter';
  @override
  DateTime get uploadTime => DateTime(2026);
}

class _ChapterDetail extends Fake implements BaseComicChapterDetailModel {
  _ChapterDetail(this.comments);
  final List<ChapterCommentEntity> comments;
  @override
  String get title => 'Chapter';
  @override
  List<ImageEntity> get pages => [
        ImageEntity(ImageType.asset, 'assets/sources/copymanga.png'),
      ];
  @override
  Future<List<ChapterCommentEntity>> getChapterComments() async => comments;
  @override
  Future<List<FileInfo>> downloadPages() async => [];
}

class _Detail extends Fake implements BaseComicDetailModel {
  _Detail(this.chapter, this.nextComments);
  final _ChapterDetail chapter;
  final List<ChapterCommentEntity>? nextComments;
  @override
  Future<BaseComicChapterDetailModel> getChapter(String chapterId) async =>
      chapterId == 'next' ? _ChapterDetail(nextComments!) : chapter;
  @override
  Future<bool> addComicHistory(String chapterId, String title) async => true;
}

Future<void> _openReader(WidgetTester tester, ReadDirectionType direction,
    List<ChapterCommentEntity> comments,
    {List<ChapterCommentEntity>? nextComments, ThemeData? theme}) async {
  tester.view.physicalSize = const Size(400, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(ChangeNotifierProvider<ConfigProvider>(
    create: (_) => _Config(direction),
    child: MaterialApp(
      theme: theme,
      locale: const Locale('zh'),
      supportedLocales: S.delegate.supportedLocales,
      localizationsDelegates: const [
        S.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: ComicViewerPage(
        detailModel: _Detail(_ChapterDetail(comments), nextComments),
        chapterId: 'chapter',
        chapters: [_Chapter(), if (nextComments != null) _Chapter('next')],
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('open reader settings refresh their entire theme in place',
      (tester) async {
    await _openReader(tester, ReadDirectionType.left, [],
        theme: ThemeModel.light);
    await tester.dragFrom(const Offset(200, 400), const Offset(-350, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.settings));
    await tester.pumpAndSettle();
    final settings = find.byType(ViewerSettingList);
    final scrollPosition = tester
        .state<ScrollableState>(find
            .descendant(of: settings, matching: find.byType(Scrollable))
            .first)
        .position;
    scrollPosition.jumpTo(scrollPosition.maxScrollExtent);
    await tester.pumpAndSettle();
    final savedOffset = scrollPosition.pixels;
    final sheet = find.byType(BottomSheet).first;

    for (final (label, brightness, background) in [
      ('深色', Brightness.dark, const Color(0xFF2E3947)),
      ('纯白', Brightness.light, Colors.white),
      ('跟随应用', Brightness.light, null),
    ]) {
      await tester.tap(find.byTooltip(label));
      await tester.pumpAndSettle();
      expect(settings, findsOneWidget);
      final theme = Theme.of(tester.element(settings));
      expect(theme.brightness, brightness);
      final expectedBackground = background ??
          Theme.of(tester.element(find.byType(ComicViewerPage)))
              .colorScheme
              .surfaceContainerLow;
      final materials = tester.widgetList<Material>(
          find.descendant(of: sheet, matching: find.byType(Material)));
      expect(materials.any((material) => material.color == expectedBackground),
          isTrue);
      expect(scrollPosition.pixels, closeTo(savedOffset, 0.1));
      expect(tester.takeException(), isNull);
    }
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final direction in ReadDirectionType.values) {
    testWidgets('${direction.name}: comments use reader page tap regions',
        (tester) async {
      await _openReader(tester, direction, [],
          nextComments: [ChapterCommentEntity('next', '下一章的吐槽', 1)]);
      final forward = switch (direction) {
        ReadDirectionType.left => const Offset(380, 400),
        ReadDirectionType.right => const Offset(20, 400),
        ReadDirectionType.vertical => const Offset(200, 700),
      };
      final backward = switch (direction) {
        ReadDirectionType.left => const Offset(20, 400),
        ReadDirectionType.right => const Offset(380, 400),
        ReadDirectionType.vertical => const Offset(200, 100),
      };
      // Image pages wait for PhotoView's double-tap recognition timeout.
      const tapInterval = Duration(milliseconds: 350);
      await tester.tapAt(forward);
      await tester.pumpAndSettle(tapInterval);
      expect(find.byIcon(Icons.menu).hitTestable(), findsOneWidget);
      final commentsTop = tester.getTopLeft(find.text('本章吐槽')).dy;

      await tester.tapAt(const Offset(200, 400));
      await tester.pumpAndSettle(tapInterval);
      expect(find.byType(BackButton).hitTestable(), findsOneWidget);
      await tester.tapAt(const Offset(200, 400));
      await tester.pumpAndSettle(tapInterval);
      expect(find.byType(BackButton).hitTestable(), findsNothing);

      await tester.tapAt(backward);
      await tester.pumpAndSettle(tapInterval);
      if (direction == ReadDirectionType.vertical) {
        // A short image can leave the next page's heading visible below it.
        expect(
            tester.getTopLeft(find.text('本章吐槽')).dy, greaterThan(commentsTop));
      } else {
        expect(find.byIcon(Icons.menu).hitTestable(), findsNothing);
      }
      await tester.tapAt(forward);
      await tester.pumpAndSettle(tapInterval);
      expect(find.byIcon(Icons.menu).hitTestable(), findsOneWidget);
      await tester.tapAt(forward);
      await tester.pumpAndSettle(tapInterval);
      // The forward edge at chapter end loads the next chapter's first image.
      if (direction == ReadDirectionType.vertical) {
        expect(
            tester.getTopLeft(find.text('本章吐槽')).dy, greaterThan(commentsTop));
      } else {
        expect(find.byIcon(Icons.menu).hitTestable(), findsNothing);
      }
      await tester.tapAt(forward);
      await tester.pumpAndSettle(tapInterval);
      expect(find.text('下一章的吐槽').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets(
        '${direction.name}: last image leads to bounded comments and drawer',
        (tester) async {
      await _openReader(
          tester,
          direction,
          List.generate(
              40,
              (index) => ChapterCommentEntity(
                  '$index', '吐槽 $index：这一章很好看。', 40 - index)),
          nextComments: [ChapterCommentEntity('next', '下一章的吐槽', 1)]);
      final offset = switch (direction) {
        ReadDirectionType.left => const Offset(-350, 0),
        ReadDirectionType.right => const Offset(350, 0),
        ReadDirectionType.vertical => const Offset(0, -500),
      };
      await tester.dragFrom(const Offset(200, 400), offset);
      await tester.pumpAndSettle();
      expect(find.text('显示更多').hitTestable(), findsOneWidget);
      await tester.tap(find.text('显示更多'));
      await tester.pumpAndSettle();
      expect(tester.state<ScaffoldState>(find.byType(Scaffold)).isEndDrawerOpen,
          isTrue);
      expect(find.text('吐槽 0：这一章很好看。').hitTestable(), findsOneWidget);
      tester.state<ScaffoldState>(find.byType(Scaffold)).closeEndDrawer();
      await tester.pumpAndSettle();
      expect(find.byType(BackButton).hitTestable(), findsNothing);
      await tester.tapAt(const Offset(200, 400));
      await tester.pumpAndSettle();
      expect(find.byType(BackButton).hitTestable(), findsOneWidget);
      await tester.tapAt(const Offset(200, 400));
      await tester.pumpAndSettle();
      expect(find.byType(BackButton).hitTestable(), findsNothing);
      await tester.dragFrom(const Offset(200, 400), offset);
      await tester.pumpAndSettle();
      // Loading the next chapter returns to its first image.
      await tester.dragFrom(const Offset(200, 400), offset);
      await tester.pumpAndSettle();
      expect(find.text('下一章的吐槽').hitTestable(), findsOneWidget);
      expect(find.text('显示更多'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('comments never zoom on double tap or pinch', (tester) async {
    await _openReader(tester, ReadDirectionType.left, []);
    await tester.dragFrom(const Offset(200, 400), const Offset(-350, 0));
    await tester.pumpAndSettle();
    final heading = find.text('本章吐槽');
    final original = tester.getRect(heading);
    await tester.tapAt(const Offset(200, 400));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tapAt(const Offset(200, 400));
    await tester.pumpAndSettle(const Duration(milliseconds: 350));
    expect(tester.getRect(heading), original);

    final leftFinger =
        await tester.startGesture(const Offset(180, 400), pointer: 1);
    final rightFinger =
        await tester.startGesture(const Offset(220, 400), pointer: 2);
    await leftFinger.moveTo(const Offset(100, 400));
    await rightFinger.moveTo(const Offset(300, 400));
    await tester.pump();
    await leftFinger.up();
    await rightFinger.up();
    await tester.pumpAndSettle();
    expect(tester.getRect(heading), original);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('comments follow toolbar motion without jumping on reversal',
      (tester) async {
    await _openReader(tester, ReadDirectionType.left, []);
    await tester.dragFrom(const Offset(200, 400), const Offset(-350, 0));
    await tester.pumpAndSettle();
    final heading = find.text('本章吐槽');
    final initialTop = tester.getTopLeft(heading).dy;

    final initialToolbarBottom =
        tester.getBottomLeft(find.byType(BackButton)).dy;
    await tester.tap(find.byIcon(Icons.menu));
    await tester.pump();
    expect(tester.getTopLeft(heading).dy, closeTo(initialTop, 0.1));
    await tester.pump(const Duration(milliseconds: 150));
    final middleTop = tester.getTopLeft(heading).dy;
    expect(middleTop, greaterThan(initialTop));
    expect(middleTop, lessThan(initialTop + 70));
    final toolbarBottom = tester.getBottomLeft(find.byType(BackButton)).dy;
    expect(middleTop - initialTop,
        closeTo(toolbarBottom - initialToolbarBottom, 0.1));
    await tester.tapAt(const Offset(200, 300));
    await tester.pump();
    expect(tester.getTopLeft(heading).dy, closeTo(middleTop, 0.1));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(heading).dy, closeTo(initialTop, 0.1));
    await tester.tapAt(const Offset(200, 300));
    await tester.pumpAndSettle();
    expect(find.byType(BackButton).hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('one long comment is clipped, and resizing updates overflow',
      (tester) async {
    await _openReader(tester, ReadDirectionType.left,
        [ChapterCommentEntity('long', '这是一条很长的吐槽。' * 300, 1)]);
    await tester.dragFrom(const Offset(200, 400), const Offset(-350, 0));
    await tester.pumpAndSettle();
    expect(find.text('显示更多').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);

    tester.view.physicalSize = const Size(1600, 1600);
    await tester.pumpAndSettle();
    expect(find.text('显示更多'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('show more selects comments after the directory was used',
      (tester) async {
    await _openReader(
        tester,
        ReadDirectionType.left,
        List.generate(
            40, (index) => ChapterCommentEntity('$index', '吐槽 $index', 1)));
    await tester.dragFrom(const Offset(200, 400), const Offset(-350, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.list_alt));
    await tester.pumpAndSettle();
    expect(find.text('Chapter').hitTestable(), findsOneWidget);
    tester.state<ScaffoldState>(find.byType(Scaffold)).closeEndDrawer();
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();
    await tester.tap(find.text('显示更多'));
    await tester.pumpAndSettle();
    expect(find.text('吐槽 0').hitTestable(), findsOneWidget);
    expect(find.text('Chapter').hitTestable(), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
