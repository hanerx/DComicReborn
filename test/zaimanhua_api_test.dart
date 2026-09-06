import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dcomic/database/database_instance.dart';
import 'package:dcomic/providers/models/comic_source_model.dart';
import 'package:dcomic/providers/models/zaimanhua/zaimanhua_source_model.dart';
import 'package:dcomic/providers/page_controllers/comic_category_detail_page_controller.dart';
import 'package:dcomic/providers/page_controllers/comic_favorite_page_controller.dart';
import 'package:dcomic/requests/base_request.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class TestPaths extends PathProviderPlatform {
  final String path;
  TestPaths(this.path);

  @override
  Future<String?> getExternalStoragePath() async => path;

  @override
  Future<String?> getApplicationDocumentsPath() async => path;
}

class ApiAdapter implements HttpClientAdapter {
  final Object Function(RequestOptions) respond;
  final String contentType;

  ApiAdapter(this.respond, {this.contentType = 'application/json'});

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? body,
      Future<void>? cancelFuture) async {
    return ResponseBody.fromString(jsonEncode(respond(options)), 200, headers: {
      Headers.contentTypeHeader: [contentType]
    });
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory temporaryDirectory;
  late final mobile = RequestHandlers.zaiManHuaMobileRequestHandler;
  late final account = RequestHandlers.zaiManHuaAccountRequestHandler;
  final source = ZaiManHuaSourceModel();
  final quietLogger = Logger(output: ConsoleOutput());

  setUpAll(() async {
    temporaryDirectory =
        await Directory.systemTemp.createTemp('zaimanhua_api_');
    PathProviderPlatform.instance = TestPaths(temporaryDirectory.path);
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    await databaseFactory.setDatabasesPath(temporaryDirectory.path);
    await RequestStatics.store;
    mobile.dio.interceptors.clear();
    account.dio.interceptors.clear();
    source.accountModel!.logger = quietLogger;
    (source.accountModel as ZaiManHuaAccountModel).parent = source;
  });

  setUp(() async {
    final db = await DatabaseInstance.instance;
    await db.database.delete('ModelConfigEntity');
  });

  tearDownAll(() async {
    mobile.dio.close(force: true);
    account.dio.close(force: true);
    await (await DatabaseInstance.instance).close();
    await (await RequestStatics.store).close();
    await temporaryDirectory.delete(recursive: true);
  });

  test('client version prevents false missing-comic errors for reader APIs',
      () async {
    mobile.dio.httpClientAdapter = ApiAdapter((request) {
      if (request.uri.path.endsWith('/checkIsSub')) {
        return {
          'errno': 0,
          'data': {'isSub': false}
        };
      }
      if (request.uri.queryParameters['_v'] != '2.3.5') {
        return {'errno': 2, 'errmsg': '漫画不存在或已被删除', 'data': {}};
      }
      if (request.uri.path.contains('/comic/detail/')) {
        return {
          'errno': 0,
          'data': {
            'data': {'id': 64556, 'title': '示例漫画'}
          }
        };
      }
      return {
        'errno': 0,
        'data': {
          'data': {
            'chapter_id': 186872,
            'title': '第 2 话',
            'page_url_hd': ['https://example.com/page.jpg']
          }
        }
      };
    });
    final detail = await source.getComicDetail('64556', '');
    expect(detail, isNotNull);
    expect(detail!.title, '示例漫画');
    final chapter = await detail.getChapter('186872');
    expect(chapter!.chapterId, '186872');
    expect(chapter.pages.single.imageUrl, 'https://example.com/page.jpg');
  });

  test('search preserves reserved characters and advances beyond first page',
      () async {
    final pages = <String?>[];
    const keyword = '漫画 & # + ?';
    mobile.dio.httpClientAdapter = ApiAdapter((request) {
      expect(request.uri.queryParameters['keyword'], keyword);
      pages.add(request.uri.queryParameters['page']);
      return {
        'errno': 0,
        'data': {'list': []}
      };
    });
    await source.searchComicDetail(keyword);
    await source.searchComicDetail(keyword, page: 1);
    expect(pages, ['1', '2']);
  });

  test('category pagination and sorting follow captured API contract',
      () async {
    final pages = <String?>[];
    final sorts = <String?>[];
    mobile.dio.httpClientAdapter = ApiAdapter((request) {
      pages.add(request.uri.queryParameters['page']);
      sorts.add(request.uri.queryParameters['sortType']);
      return {
        'errno': 0,
        'data': {'comicList': []}
      };
    });
    final home = source.homepage!;
    await home.getCategoryDetailList(
        categoryId: '4518',
        categoryFilter: {'TimeOrRank': TimeOrRankEnum.ranking});
    await home.getCategoryDetailList(
        categoryId: '4518',
        page: 1,
        categoryFilter: {'TimeOrRank': TimeOrRankEnum.latestUpdate});
    expect(pages, ['1', '2']);
    expect(sorts, ['2', '1']);
  });

  test('category page uses the signed-in catalog and reverts after logout',
      () async {
    final dao = (await DatabaseInstance.instance).modelConfigDao;
    final loginState =
        await dao.getOrCreateConfigByKey('isLogin', 'zaimanhua', value: true);
    await dao.getOrCreateConfigByKey('token', 'zaimanhua',
        value: 'catalog-session');
    mobile.dio.httpClientAdapter = ApiAdapter((request) {
      final signedIn =
          request.headers['Authorization'] == 'Bearer catalog-session';
      return {
        'errno': 0,
        'data': {
          'totalNum': signedIn ? 518 : 4,
          'comicList': [
            {
              'id': 84304,
              'name': signedIn ? '完整分类新漫画' : '游客旧漫画',
              'authors': '作者',
              'types': 'TS',
              'cover': 'https://example.com/comic.jpg',
              'last_updatetime': 1778728889
            }
          ]
        }
      };
    });
    final controller =
        ComicCategoryDetailPageController(source, '4518', categoryType: 1);
    await controller.refresh();
    expect(controller.data.single.title, '完整分类新漫画');
    loginState.set(false);
    await dao.updateConfig(loginState);
    await controller.refresh();
    expect(controller.data.single.title, '游客旧漫画');
    controller.dispose();
  });

  for (final discovery in [
    (
      name: 'ranking',
      load: () async =>
          (await source.homepage!.getRankingList()).map((entry) => entry.title)
    ),
    (
      name: 'latest',
      load: () async =>
          (await source.homepage!.getLatestList()).map((entry) => entry.title)
    ),
    (
      name: 'search',
      load: () async =>
          (await source.searchComicDetail('TS')).map((entry) => entry.title)
    ),
    (
      name: 'categories',
      load: () async =>
          (await source.homepage!.getCategoryList()).map((entry) => entry.title)
    ),
  ]) {
    test('${discovery.name} preserves the signed-in catalog', () async {
      final dao = (await DatabaseInstance.instance).modelConfigDao;
      await dao.getOrCreateConfigByKey('isLogin', 'zaimanhua', value: true);
      await dao.getOrCreateConfigByKey('token', 'zaimanhua',
          value: 'catalog-session');
      mobile.dio.httpClientAdapter = ApiAdapter((request) {
        final visible =
            request.headers['Authorization'] == 'Bearer catalog-session';
        final comic = {
          'id': 84304,
          'comic_id': 84304,
          'title': '登录可见条目',
          'authors': '作者',
          'types': 'TS',
          'last_name': '第1话',
          'cover': 'https://example.com/comic.jpg',
          'last_updatetime': 1778728889
        };
        final list = visible ? [comic] : [];
        return {
          'errno': 0,
          'data': switch (discovery.name) {
            'search' => {'list': list},
            'categories' => {
                'cateList': visible
                    ? [
                        {
                          'tagId': 4518,
                          'tagType': 1,
                          'title': '登录可见条目',
                          'cover': 'https://example.com/category.jpg'
                        }
                      ]
                    : []
              },
            _ => list,
          }
        };
      });
      final entries = await discovery.load();
      expect(entries, ['登录可见条目']);
    });
  }

  test('categories request the comic source and parse the captured catalog',
      () async {
    mobile.dio.httpClientAdapter = ApiAdapter((request) {
      expect(request.uri.path, '/app/v1/comic/filter/category');
      expect(request.uri.queryParameters['source'], '1');
      return {
        'errno': 0,
        'data': {
          'cateList': [
            {
              'tagId': 2304,
              'title': '日本',
              'tagType': 4,
              'cover': 'https://example.com/japan.jpg'
            }
          ]
        }
      };
    });
    final home = source.homepage!;
    home.logger = quietLogger;
    final categories = await home.getCategoryList();
    expect(categories.single.title, '日本');
    expect(categories.single.cover.imageUrl, 'https://example.com/japan.jpg');
  });

  for (final category in [
    (type: 1, id: '4518', key: 'theme'),
    (type: 4, id: '2304', key: 'zone'),
    (type: 5, id: '2310', key: 'status'),
    (type: 6, id: '3262', key: 'cate'),
  ]) {
    test(
        'category type ${category.type} selects ${category.key} instead of theme',
        () async {
      mobile.dio.httpClientAdapter = ApiAdapter((request) {
        final query = request.uri.queryParameters;
        for (final key in ['theme', 'zone', 'status', 'cate']) {
          expect(query[key], key == category.key ? category.id : '0');
        }
        return {
          'errno': 0,
          'data': {
            'comicList': [
              {
                'id': 41088,
                'name': '分类结果',
                'authors': '作者',
                'types': '校园',
                'cover': 'https://example.com/comic.jpg',
                'last_updatetime': 1778766202
              }
            ]
          }
        };
      });
      final home = source.homepage!;
      home.logger = quietLogger;
      final comics = await home.getCategoryDetailList(
          categoryId: category.id,
          categoryType: category.type,
          categoryFilter: {'TimeOrRank': TimeOrRankEnum.ranking});
      expect(comics.single.title, '分类结果');
    });
  }

  test('ranking follows the captured time range and parses successive pages',
      () async {
    mobile.dio.httpClientAdapter = ApiAdapter((request) {
      expect(request.uri.path, '/app/v1/comic/rank/list');
      final query = request.uri.queryParameters;
      expect(query['by_time'], '0');
      expect(query['rank_type'], '0');
      expect(query['tag_id'], '0');
      final page = int.parse(query['page']!);
      return {
        'errno': 0,
        'data': [
          {
            'comic_id': 86400 + page,
            'title': '排行$page',
            'authors': '作者',
            'cover': 'https://example.com/rank$page.jpg',
            'types': '爱情',
            'last_updatetime': 1778523364
          }
        ]
      };
    });
    final home = source.homepage!;
    home.logger = quietLogger;
    final first = await home.getRankingList();
    final second = await home.getRankingList(page: 1);
    expect(first.single.title, '排行1');
    expect(second.single.title, '排行2');
  });

  test('comments use one-based pages and sortBy', () async {
    final pages = <String?>[];
    mobile.dio.httpClientAdapter = ApiAdapter((request) {
      if (request.uri.path.endsWith('/checkIsSub')) {
        return {
          'errno': 0,
          'data': {'isSub': false}
        };
      }
      expect(request.uri.queryParameters['sortBy'], '1');
      expect(request.uri.queryParameters.containsKey('sort'), isFalse);
      pages.add(request.uri.queryParameters['page']);
      return {
        'errno': 0,
        'data': {'commentIdList': [], 'commentList': {}}
      };
    });
    final detail = ZaiManHuaComicDetailModel({
      'data': {'id': 41088}
    }, source);
    await detail.getComments();
    await detail.getComments(page: 1);
    expect(pages, ['1', '2']);
  });

  test('subscriptions retain read comics on refresh and remove cancelled ones',
      () async {
    var read = false;
    var subscribed = true;
    mobile.dio.httpClientAdapter = ApiAdapter((request) {
      if (request.uri.path == '/app/v1/comic/sub/list') {
        return {
          'errno': 0,
          'data': {'subList': []}
        };
      }
      expect(request.uri.path, '/app/v1/bookshelf/updates/list');
      return {
        'errno': 0,
        'data': {
          'total': subscribed ? 1 : 0,
          'list': [
            if (subscribed)
              {
                'id': 'M_64556',
                'contentType': 'comic',
                'title': '示例漫画',
                'coverUrl': 'https://example.com/cover.jpg',
                'lastUpdateChapterId': 186872,
                'lastUpdateChapterName': '第16话',
                'lastUpdatedAt': '2026-05-14T03:14:58Z',
                'readingRecord': {'chapterId': read ? 186872 : 0}
              }
          ]
        }
      };
    });
    final controller = ComicFavoritePageController(source);
    addTearDown(controller.dispose);
    await controller.refresh();
    expect(
        controller.data
            .map((item) => (item as GridItemEntityWithStatus).comicId),
        ['64556']);
    read = true;
    await source.accountModel!.addSubscribeState('64556');
    await controller.refresh();
    final comic = controller.data.single as GridItemEntityWithStatus;
    expect(comic.comicId, '64556');
    expect(comic.subtitle, '第16话');
    expect(comic.lastUpdateTimestamp, DateTime.utc(2026, 5, 14, 3, 14, 58));
    subscribed = false;
    await controller.refresh();
    expect(controller.data, isEmpty);
  });

  test('subscriptions keep server pagination across a novel-only page',
      () async {
    mobile.dio.httpClientAdapter = ApiAdapter((request) {
      expect(request.uri.path, '/app/v1/bookshelf/updates/list');
      final page = int.parse(request.uri.queryParameters['page']!);
      expect(request.uri.queryParameters['pageSize'], '20');
      return {
        'errno': 0,
        'data': {
          'total': 41,
          'list': [
            for (var index = 0; index < (page < 3 ? 20 : 1); index++)
              {
                'id': page == 2 ? 'N_$index' : 'M_${page * 100 + index}',
                'contentType': page == 2 ? 'novel' : 'comic',
                'title': '条目 $index',
                'coverUrl': 'https://example.com/cover.jpg',
                'lastUpdateChapterName': '第1话',
                'lastUpdatedAt': '2026-05-14T03:14:58Z',
              }
          ]
        }
      };
    });
    final controller = ComicFavoritePageController(source);
    addTearDown(controller.dispose);
    await controller.refresh();
    await controller.load();
    await controller.load();
    expect(
        controller.data
            .map((item) => (item as GridItemEntityWithStatus).comicId),
        [for (var index = 0; index < 20; index++) '${100 + index}', '300']);
  });

  test('login preserves JSON username and restores personalInfo profile',
      () async {
    const username = '读者+test@example.com';
    account.dio.httpClientAdapter = ApiAdapter((request) {
      if (request.uri.path == '/v1/login/passwd') {
        expect(request.data['username'], username);
        return {
          'errno': 0,
          'data': {
            'user': {'token': 'test-token'}
          }
        };
      }
      expect(request.uri.path, '/v1/u_center/personal/info/get');
      expect(request.headers['Authorization'], 'Bearer test-token');
      return {
        'errno': 0,
        'data': {
          'personalInfo': {
            'uid': 123,
            'nickname': '测试读者',
            'photo': 'https://example.com/avatar.jpg'
          }
        }
      };
    });
    expect(await source.accountModel!.login(username, 'test-password'), isTrue);
    expect(source.accountModel!.isLogin, isTrue);
    expect(source.accountModel!.uid, '123');
    expect(source.accountModel!.nickname, '测试读者');
    expect(source.accountModel!.username, '123');
  });

  test('token login restores the captured personalInfo response', () async {
    account.dio.httpClientAdapter = ApiAdapter((request) {
      expect(request.uri.path, '/v1/u_center/personal/info/get');
      return {
        'errno': 0,
        'data': {
          'personalInfo': {
            'uid': 456,
            'nickname': '令牌读者',
            'photo': 'https://example.com/token.jpg'
          }
        }
      };
    });
    await source.accountModel!.loginWithToken('test-token');
    expect(source.accountModel!.isLogin, isTrue);
    expect(source.accountModel!.uid, '456');
    expect(source.accountModel!.nickname, '令牌读者');
  });

  test('login reports the API errmsg instead of throwing null', () async {
    account.dio.httpClientAdapter = ApiAdapter(
        (request) => {'errno': 1001, 'errmsg': '账号或密码错误', 'data': {}});
    await expectLater(source.accountModel!.login('reader', 'wrong-password'),
        throwsA('账号或密码错误'));
  });

  for (final contentType in ['application/json', 'text/plain']) {
    test('homepage reads recommendations served as $contentType', () async {
      mobile.dio.httpClientAdapter = ApiAdapter(
          (request) => [
                {
                  'category_id': 1,
                  'title': '推荐',
                  'data': [
                    {
                      'title': '示例漫画',
                      'sub_title': '更新',
                      'cover': 'https://example.com/cover.jpg',
                      'type': 1,
                      'obj_id': 64556
                    }
                  ]
                }
              ],
          contentType: contentType);
      final home = source.homepage!;
      home.logger = quietLogger;
      final cards = await home.getHomepageCard();
      final carousel = await home.getHomepageCarousel();
      expect(cards.map((card) => card.title), ['推荐']);
      expect(carousel.map((item) => item.title), ['示例漫画']);
    });
  }
}
