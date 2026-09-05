import 'package:dcomic/generated/l10n.dart';
import 'package:dcomic/providers/config_provider.dart';
import 'package:dcomic/providers/models/comic_source_model.dart';
import 'package:dcomic/utils/image_utils.dart';
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
    {List<ChapterCommentEntity>? nextComments}) async {
  tester.view.physicalSize = const Size(400, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(ChangeNotifierProvider<ConfigProvider>(
    create: (_) => _Config(direction),
    child: MaterialApp(
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
  for (final direction in ReadDirectionType.values) {
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
