import 'dart:io';

import 'package:dcomic/database/database_instance.dart';
import 'package:dcomic/providers/models/copymanga/copymanga_source_model.dart';
import 'package:dcomic/providers/models/zaimanhua/zaimanhua_source_model.dart';
import 'package:dcomic/providers/navigator_provider.dart';
import 'package:dcomic/requests/base_request.dart';
import 'package:dcomic/view/topic_pages/comic_topic_detail_page.dart';
import 'package:dcomic/view/topic_pages/comic_topic_list_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'zaimanhua_api_test.dart' show ApiAdapter, TestPaths;

class _Routes extends NavigatorObserver {
  Route<dynamic>? last;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    last = route;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  final copy = CopyMangaComicSourceModel();
  final zai = ZaiManHuaSourceModel();

  setUpAll(() async {
    directory = await Directory.systemTemp.createTemp('topic_navigation_');
    PathProviderPlatform.instance = TestPaths(directory.path);
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    await databaseFactory.setDatabasesPath(directory.path);
    await RequestStatics.store;
    RequestHandlers.copyMangaRequestHandler.dio.interceptors.clear();
    RequestHandlers.zaiManHuaMobileRequestHandler.dio.interceptors.clear();
  });

  tearDownAll(() async {
    RequestHandlers.copyMangaRequestHandler.dio.close(force: true);
    RequestHandlers.zaiManHuaMobileRequestHandler.dio.close(force: true);
    await (await DatabaseInstance.instance).close();
    await (await RequestStatics.store).close();
    await directory.delete(recursive: true);
  });

  Future<Widget> destination(
    WidgetTester tester,
    void Function(BuildContext)? action,
  ) async {
    final observer = _Routes();
    late BuildContext buttonContext;
    late NavigatorProvider navigation;
    await tester.pumpWidget(
      Builder(
        builder: (context) {
          navigation = NavigatorProvider(context);
          return ChangeNotifierProvider.value(
            value: navigation,
            child: MaterialApp(
              navigatorObservers: [observer],
              home: Builder(
                builder: (context) {
                  buttonContext = context;
                  return Scaffold(
                    body: TextButton(
                      onPressed: action == null ? null : () => action(context),
                      child: const Text('Open recommendation'),
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
    addTearDown(navigation.dispose);
    final original = observer.last;
    await tester.tap(find.text('Open recommendation'));
    expect(observer.last, isNot(same(original)));
    return (observer.last as MaterialPageRoute).builder(buttonContext);
  }

  testWidgets('Copy homepage topic uses path word and original source', (
    tester,
  ) async {
    RequestHandlers.copyMangaRequestHandler.dio.httpClientAdapter = ApiAdapter(
      (_) => {
        'code': 200,
        'results': {
          'topics': {
            'list': [
              {
                'path_word': 'summer-topic',
                'title': '夏季专题',
                'brief': '',
                'cover': 'https://example.com/topic.jpg',
              },
            ],
          },
        },
      },
    );
    final cards = (await tester.runAsync(
      () => copy.homepage!.getHomepageCard(),
    ))!;
    final page = await destination(tester, cards.single.children.single.onTap);
    expect(page, isA<ComicTopicDetailPage>());
    final detail = page as ComicTopicDetailPage;
    expect(detail.topicId, 'summer-topic');
    expect(detail.sourceModel, same(copy));
  });

  for (final carousel in [false, true]) {
    testWidgets(
      'Zai topic target opens detail from ${carousel ? 'carousel' : 'card'}',
      (tester) async {
        RequestHandlers.zaiManHuaMobileRequestHandler.dio.httpClientAdapter =
            ApiAdapter(
              (_) => [
                {
                  'category_id': 48,
                  'title': '火热专题',
                  'data': [
                    {
                      'type': 5,
                      'obj_id': 603,
                      'title': '新番专题',
                      'sub_title': '',
                      'cover': 'https://example.com/topic.jpg',
                    },
                  ],
                },
              ],
            );
        final void Function(BuildContext)? action;
        if (carousel) {
          final items = (await tester.runAsync(
            () => zai.homepage!.getHomepageCarousel(),
          ))!;
          action = items.single.onTap;
        } else {
          final cards = (await tester.runAsync(
            () => zai.homepage!.getHomepageCard(),
          ))!;
          action = cards.single.children.single.onTap;
        }
        final page = await destination(tester, action) as ComicTopicDetailPage;
        expect(page.topicId, '603');
        expect(page.sourceModel, same(zai));
      },
    );
  }

  testWidgets('Zai collection target with zero object ID opens topic list', (
    tester,
  ) async {
    RequestHandlers.zaiManHuaMobileRequestHandler.dio.httpClientAdapter =
        ApiAdapter(
          (_) => [
            {
              'category_id': 48,
              'title': '火热专题',
              'data': [
                {
                  'type': 18,
                  'obj_id': 0,
                  'title': '漫画专题大合集',
                  'sub_title': '',
                  'cover': 'https://example.com/topics.jpg',
                },
              ],
            },
          ],
        );
    final cards = (await tester.runAsync(
      () => zai.homepage!.getHomepageCard(),
    ))!;
    final page = await destination(tester, cards.single.children.single.onTap);
    expect(page, isA<ComicTopicListPage>());
    expect((page as ComicTopicListPage).sourceModel, same(zai));
  });
}
