import 'dart:async';

import 'package:dcomic/generated/l10n.dart';
import 'package:dcomic/providers/models/comic_source_model.dart';
import 'package:dcomic/providers/models/comic_topic_model.dart';
import 'package:dcomic/providers/page_controllers/comic_topic_page_controller.dart';
import 'package:dcomic/providers/navigator_provider.dart';
import 'package:dcomic/utils/image_utils.dart';
import 'package:dcomic/view/comic_pages/comic_detail_page.dart';
import 'package:dcomic/view/topic_pages/comic_topic_detail_page.dart';
import 'package:dcomic/view/topic_pages/comic_topic_list_page.dart';
import 'package:dcomic/view/topic_pages/topic_page_widgets.dart';
import 'package:dcomic/view/components/grid_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';
import 'package:provider/provider.dart';

final _cover = ImageEntity(ImageType.unknown, '');

ComicTopic _topic(String id) => ComicTopic(
  id: id,
  title: 'topic-$id',
  cover: _cover,
  description: 'description-$id',
  date: 'date-$id',
);

TopicComic _comic(String id) => TopicComic(
  id: id,
  title: 'comic-$id',
  cover: _cover,
  description: '冒险\n一段完整的推荐理由：主角与伙伴们踏上新的旅程，探索未知世界，最终揭开隐藏的秘密。',
);

class _PageRequest<T> {
  _PageRequest(this.page);

  final int page;
  final result = Completer<TopicPage<T>>();
}

class _DetailRequest {
  _DetailRequest(this.id);

  final String id;
  final result = Completer<ComicTopicDetail>();
}

class _TopicModel extends BaseComicTopicModel {
  final topicRequests = <_PageRequest<ComicTopic>>[];
  final detailRequests = <_DetailRequest>[];
  final comicRequests = <({String id, _PageRequest<TopicComic> request})>[];

  @override
  Future<TopicPage<ComicTopic>> getTopics({int page = 0}) {
    final request = _PageRequest<ComicTopic>(page);
    topicRequests.add(request);
    return request.result.future;
  }

  @override
  Future<ComicTopicDetail> getDetail(String topicId) {
    final request = _DetailRequest(topicId);
    detailRequests.add(request);
    return request.result.future;
  }

  @override
  Future<TopicPage<TopicComic>> getComics(String topicId, {required int page}) {
    final request = _PageRequest<TopicComic>(page);
    comicRequests.add((id: topicId, request: request));
    return request.result.future;
  }
}

class _Source extends BaseComicSourceModel {
  _Source(this.topicModel);

  final BaseComicTopicModel topicModel;

  @override
  BaseComicTopicModel get topics => topicModel;

  @override
  Future<BaseComicDetailModel?> getComicDetail(
    String comicId,
    String title,
  ) async => null;

  @override
  Future<List<ComicListItemEntity>> searchComicDetail(
    String keyword, {
    int page = 0,
  }) async => [];
}

class _ImmediateTopicModel extends BaseComicTopicModel {
  String? lastDetailId;

  @override
  Future<TopicPage<ComicTopic>> getTopics({int page = 0}) async =>
      TopicPage([_topic('topic/raw')]);

  @override
  Future<ComicTopicDetail> getDetail(String topicId) async {
    lastDetailId = topicId;
    return ComicTopicDetail(
      topic: _topic(topicId),
      comics: TopicPage([_comic('comic/raw')]),
    );
  }

  @override
  Future<TopicPage<TopicComic>> getComics(
    String topicId, {
    required int page,
  }) async => const TopicPage<TopicComic>([]);
}

class _FilteredFirstPageTopicModel extends BaseComicTopicModel {
  final requestedPages = <int>[];

  @override
  Future<TopicPage<ComicTopic>> getTopics({int page = 0}) async {
    requestedPages.add(page);
    return page == 0
        ? const TopicPage<ComicTopic>([], nextPage: 9)
        : TopicPage([_topic('later')]);
  }

  @override
  Future<ComicTopicDetail> getDetail(String topicId) =>
      Future.error(UnsupportedError('Not used by this test'));

  @override
  Future<TopicPage<TopicComic>> getComics(
    String topicId, {
    required int page,
  }) => Future.error(UnsupportedError('Not used by this test'));
}

class _UiSource extends BaseComicSourceModel {
  _UiSource(this.topicModel);

  final BaseComicTopicModel topicModel;
  String _displayPrefix = 'display:';

  @override
  BaseComicTopicModel get topics => topicModel;

  @override
  String formatDisplayText(String text) => '$_displayPrefix$text';

  void changeDisplayLanguage() {
    _displayPrefix = 'alternate:';
    notifyListeners();
  }

  @override
  Future<BaseComicDetailModel?> getComicDetail(
    String comicId,
    String title,
  ) async => null;

  @override
  Future<List<ComicListItemEntity>> searchComicDetail(
    String keyword, {
    int page = 0,
  }) async => [];
}

Widget _topicApp(_UiSource source, {Widget? home}) {
  return ChangeNotifierProvider(
    create: (context) => NavigatorProvider(context),
    child: MaterialApp(
      locale: const Locale('en'),
      supportedLocales: S.delegate.supportedLocales,
      localizationsDelegates: const [
        S.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: home ?? ComicTopicListPage(sourceModel: source),
    ),
  );
}

void main() {
  late _TopicModel topicModel;
  late _Source source;

  setUp(() {
    topicModel = _TopicModel();
    source = _Source(topicModel);
  });

  tearDown(() {
    source.dispose();
  });

  group('ComicTopicListPageController', () {
    late ComicTopicListPageController controller;

    setUp(() {
      controller = ComicTopicListPageController(source)
        ..logger = Logger(output: ConsoleOutput());
    });

    tearDown(() {
      controller.dispose();
    });

    Future<void> loadFirstPage({int? nextPage = 4}) async {
      final refresh = controller.refresh();
      topicModel.topicRequests.single.result.complete(
        TopicPage([_topic('first')], nextPage: nextPage),
      );
      await refresh;
    }

    test('failed refresh retains the visible topic list', () async {
      await loadFirstPage();

      final refresh = controller.refresh();
      expect(controller.topics.map((item) => item.id), ['first']);
      topicModel.topicRequests.last.result.completeError(StateError('offline'));
      await refresh;

      expect(controller.topics.map((item) => item.id), ['first']);
      expect(controller.hasError, isTrue);
      expect(controller.failedToLoadMore, isFalse);
    });

    test(
      'failed page retries the same nextPage and removes duplicate ids',
      () async {
        await loadFirstPage(nextPage: 4);

        final failedLoad = controller.loadMore();
        expect(topicModel.topicRequests.last.page, 4);
        topicModel.topicRequests.last.result.completeError(
          StateError('temporarily unavailable'),
        );
        await failedLoad;

        final retry = controller.loadMore();
        expect(topicModel.topicRequests.last.page, 4);
        topicModel.topicRequests.last.result.complete(
          TopicPage([_topic('first'), _topic('second'), _topic('second')]),
        );
        await retry;

        expect(controller.topics.map((item) => item.id), ['first', 'second']);
        expect(controller.hasMore, isFalse);
      },
    );

    test('refresh supersedes an obsolete append response', () async {
      await loadFirstPage(nextPage: 2);

      final append = controller.loadMore();
      final refresh = controller.refresh();
      expect(topicModel.topicRequests.map((request) => request.page), [
        0,
        2,
        0,
      ]);
      topicModel.topicRequests.last.result.complete(
        TopicPage([_topic('replacement')]),
      );
      await refresh;
      topicModel.topicRequests[1].result.complete(TopicPage([_topic('stale')]));
      await append;

      expect(controller.topics.map((item) => item.id), ['replacement']);
    });

    test(
      'null nextPage is authoritative even when the page has items',
      () async {
        await loadFirstPage(nextPage: null);

        await controller.loadMore();

        expect(topicModel.topicRequests, hasLength(1));
        expect(controller.hasMore, isFalse);
      },
    );
  });

  group('ComicTopicDetailPageController', () {
    late ComicTopicDetailPageController controller;

    setUp(() {
      controller = ComicTopicDetailPageController(source, 'topic-id')
        ..logger = Logger(output: ConsoleOutput());
    });

    tearDown(() {
      controller.dispose();
    });

    Future<void> loadDetail({int? nextPage = 7}) async {
      final refresh = controller.refresh();
      topicModel.detailRequests.single.result.complete(
        ComicTopicDetail(
          topic: _topic('topic-id'),
          comics: TopicPage([_comic('first')], nextPage: nextPage),
        ),
      );
      await refresh;
    }

    test(
      'failed detail refresh retains metadata and comics atomically',
      () async {
        await loadDetail();

        final refresh = controller.refresh();
        topicModel.detailRequests.last.result.completeError(
          StateError('offline'),
        );
        await refresh;

        expect(controller.topic?.id, 'topic-id');
        expect(controller.comics.map((item) => item.id), ['first']);
        expect(controller.hasError, isTrue);
        expect(controller.failedToLoadMore, isFalse);
      },
    );

    test(
      'failed comic page retries the same page and deduplicates ids',
      () async {
        await loadDetail(nextPage: 7);

        final failedLoad = controller.loadMore();
        expect(topicModel.comicRequests.last.request.page, 7);
        topicModel.comicRequests.last.request.result.completeError(
          StateError('offline'),
        );
        await failedLoad;

        final retry = controller.loadMore();
        expect(topicModel.comicRequests.last.request.page, 7);
        topicModel.comicRequests.last.request.result.complete(
          TopicPage([_comic('first'), _comic('second'), _comic('second')]),
        );
        await retry;

        expect(controller.comics.map((item) => item.id), ['first', 'second']);
        expect(controller.hasMore, isFalse);
      },
    );

    test('detail refresh supersedes an obsolete comic append', () async {
      await loadDetail(nextPage: 3);

      final append = controller.loadMore();
      final refresh = controller.refresh();
      topicModel.detailRequests.last.result.complete(
        ComicTopicDetail(
          topic: _topic('replacement'),
          comics: TopicPage([_comic('replacement')]),
        ),
      );
      await refresh;
      topicModel.comicRequests.single.request.result.complete(
        TopicPage([_comic('stale')]),
      );
      await append;

      expect(controller.topic?.id, 'replacement');
      expect(controller.comics.map((item) => item.id), ['replacement']);
    });

    test('concurrent load-more calls share one request', () async {
      await loadDetail(nextPage: 5);

      final first = controller.loadMore();
      final duplicate = controller.loadMore();
      expect(topicModel.comicRequests, hasLength(1));
      topicModel.comicRequests.single.request.result.complete(
        TopicPage([_comic('second')]),
      );
      await Future.wait([first, duplicate]);

      expect(controller.comics.map((item) => item.id), ['first', 'second']);
    });
  });

  group('topic pages', () {
    late _ImmediateTopicModel uiTopics;
    late _UiSource uiSource;

    setUp(() {
      uiTopics = _ImmediateTopicModel();
      uiSource = _UiSource(uiTopics);
    });

    tearDown(() {
      uiSource.dispose();
    });

    testWidgets('topic card keeps its height after cover decoding', (
      tester,
    ) async {
      const asset = 'assets/sources/copymanga.png';
      await tester.pumpWidget(
        _topicApp(
          uiSource,
          home: Scaffold(
            body: UnconstrainedBox(
              constrainedAxis: Axis.horizontal,
              child: SizedBox(
                width: 350,
                child: ComicTopicBanner(
                  topic: ComicTopic(
                    id: 'cover',
                    title: 'Title',
                    cover: ImageEntity(ImageType.asset, asset),
                  ),
                  sourceModel: uiSource,
                  onTap: () {},
                ),
              ),
            ),
          ),
        ),
      );
      final before = tester.getSize(find.byType(ComicTopicBanner));
      await tester.runAsync(
        () => precacheImage(
          const AssetImage(asset),
          tester.element(find.byType(ComicTopicBanner)),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byType(ComicTopicBanner)), before);
    });

    testWidgets('long topic titles do not increase card height', (
      tester,
    ) async {
      Future<Size> render(String title) async {
        await tester.pumpWidget(
          _topicApp(
            uiSource,
            home: Scaffold(
              body: UnconstrainedBox(
                constrainedAxis: Axis.horizontal,
                child: SizedBox(
                  width: 350,
                  child: ComicTopicBanner(
                    topic: ComicTopic(id: 'title', title: title, cover: _cover),
                    sourceModel: uiSource,
                    onTap: () {},
                  ),
                ),
              ),
            ),
          ),
        );
        return tester.getSize(find.byType(ComicTopicBanner));
      }

      final short = await render('Short');
      final long = await render(
        'A very long topic title that cannot fit in one line on a phone',
      );
      expect(long.height, short.height);
    });

    testWidgets('four homepage banners form two balanced rows', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1000, 900);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        _topicApp(
          uiSource,
          home: Scaffold(
            body: SizedBox(
              width: 900,
              child: GridCard(
                'Topics',
                crossAxisCount: 2,
                coverAspectRatio: 5 / 2,
                children: List.generate(
                  4,
                  (index) => SizedBox(key: ValueKey('banner-$index')),
                ),
              ),
            ),
          ),
        ),
      );
      final positions = List.generate(
        4,
        (index) => tester.getTopLeft(find.byKey(ValueKey('banner-$index'))),
      );
      expect(positions[0].dy, positions[1].dy);
      expect(positions[2].dy, positions[3].dy);
      expect(positions[2].dy, greaterThan(positions[0].dy));
    });

    testWidgets(
      'topic and comic taps retain raw ids while rendering formatted text',
      (tester) async {
        await tester.pumpWidget(_topicApp(uiSource));
        await tester.pump();
        await tester.pump();

        expect(find.text('display:topic-topic/raw'), findsOneWidget);
        expect(find.text('display:description-topic/raw'), findsOneWidget);

        uiSource.changeDisplayLanguage();
        await tester.pump();
        expect(find.text('alternate:topic-topic/raw'), findsOneWidget);

        await tester.tap(find.text('alternate:topic-topic/raw'));
        await tester.pumpAndSettle();

        expect(uiTopics.lastDetailId, 'topic/raw');
        expect(find.byType(ComicTopicDetailPage), findsOneWidget);
        expect(find.text('alternate:comic-comic/raw'), findsOneWidget);

        final providerContext = tester.element(find.byType(MaterialApp));
        final navigation = providerContext.read<NavigatorProvider>();
        await tester.tap(find.text('alternate:comic-comic/raw'));
        await tester.pump();

        expect(navigation.detailIdentity, (uiSource, 'comic/raw'));
        final detail = navigation.detailBuilder!(
          providerContext,
          false,
        ) as ComicDetailPage;
        expect(detail.comicId, 'comic/raw');
        expect(detail.title, 'comic-comic/raw');
        expect(detail.comicSourceModel, same(uiSource));
      },
    );
    testWidgets('topic comic recommendation is not clipped to its genre line', (
      tester,
    ) async {
      await tester.pumpWidget(_topicApp(uiSource));
      await tester.pumpAndSettle();
      await tester.tap(find.text('display:topic-topic/raw'));
      await tester.pumpAndSettle();
      final description = 'display:${_comic('comic/raw').description}';
      final paragraph = tester.renderObject<RenderParagraph>(
        find.text(description),
      );
      final ending = paragraph.getBoxesForSelection(
        TextSelection(
          baseOffset: description.length - 3,
          extentOffset: description.length,
        ),
      );
      expect(ending, isNotEmpty);
    });

    testWidgets('empty filtered page can load its authoritative next page', (
      tester,
    ) async {
      final pagedModel = _FilteredFirstPageTopicModel();
      final pagedSource = _UiSource(pagedModel);
      addTearDown(pagedSource.dispose);

      await tester.pumpWidget(_topicApp(pagedSource));
      await tester.pump();
      await tester.pump();
      expect(find.text('Load more'), findsOneWidget);

      await tester.tap(find.text('Load more'));
      await tester.pumpAndSettle();

      expect(pagedModel.requestedPages, [0, 9]);
      expect(find.text('display:topic-later'), findsOneWidget);
    });
    testWidgets(
      'topic pages lay out without overflow on narrow and wide panes',
      (tester) async {
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        tester.view.devicePixelRatio = 1;

        for (final size in const [Size(360, 720), Size(1280, 800)]) {
          tester.view.physicalSize = size;
          await tester.pumpWidget(_topicApp(uiSource));
          await tester.pump();
          await tester.pump();
          expect(tester.takeException(), isNull);
          expect(find.text('display:topic-topic/raw'), findsOneWidget);

          await tester.tap(find.text('display:topic-topic/raw'));
          await tester.pumpAndSettle();
          expect(find.byType(ComicTopicDetailPage), findsOneWidget);
          expect(tester.takeException(), isNull);

          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump();
        }
      },
    );
  });
}
