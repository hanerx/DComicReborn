import 'dart:io';

import 'package:dcomic/database/database_instance.dart';
import 'package:dcomic/providers/models/copymanga/copymanga_source_model.dart';
import 'package:dcomic/requests/base_request.dart';
import 'package:dcomic/providers/page_controllers/comic_homepage_controller.dart';
import 'package:dcomic/providers/source_provider.dart';
import 'package:dio/dio.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'zaimanhua_api_test.dart' show TestPaths, ApiAdapter;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late final handler = RequestHandlers.copyMangaRequestHandler;
  final source = CopyMangaComicSourceModel();

  Map<String, dynamic> homepageData(int revision,
      {bool hot = false, bool finishTheme = false}) {
    final comic = {
      'name': '漫画 $revision',
      'path_word': 'comic-$revision',
      'cover': 'https://example.com/$revision.jpg',
      'theme': [
        {'name': '日常'}
      ],
    };
    final section = {
      'list': [
        {'comic': comic}
      ]
    };
    return {
      'code': 200,
      'results': {
        'banners': [
          {'cover': comic['cover'], 'brief': '轮播 $revision'}
        ],
        'recComics': section,
        if (hot) ...{
          'rankWeeklyFreeComics': section,
          'rankWeeklyChargeComics': section,
          'updateWeeklyFreeComics': section,
          'updateWeeklyChargeComics': section,
        } else ...{
          'rankDayComics': section,
          'rankWeekComics': section,
          'rankMonthComics': section,
          'hotComics': [
            {'comic': comic}
          ],
          'newComics': [
            {'comic': comic}
          ],
          'finishComics': {
            'list': [
              {
                'name': '完结 $revision',
                'path_word': 'finished-$revision',
                'cover': comic['cover'],
                if (finishTheme) 'theme': [],
              }
            ]
          },
        },
      },
    };
  }

  Future<void> config(String key, Object value,
      {String model = 'copymanga'}) async {
    final dao = (await DatabaseInstance.instance).modelConfigDao;
    final entity = await dao.getOrCreateConfigByKey(key, model);
    entity.set(value);
    await dao.updateConfig(entity);
  }

  setUpAll(() async {
    directory = await Directory.systemTemp.createTemp('copymanga_api_');
    PathProviderPlatform.instance = TestPaths(directory.path);
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    await databaseFactory.setDatabasesPath(directory.path);
    await RequestStatics.store;
    handler.dio.interceptors.clear();
    source.logger = Logger(output: ConsoleOutput());
  });

  setUp(() async {
    handler.dio.interceptors.clear();
    await (await DatabaseInstance.instance)
        .database
        .delete('ModelConfigEntity');
  });

  tearDownAll(() async {
    handler.dio.close(force: true);
    await (await DatabaseInstance.instance).close();
    await (await RequestStatics.store).close();
    await directory.delete(recursive: true);
  });

  test('current web protocol loads comic details without old app rejection',
      () async {
    handler.dio.httpClientAdapter = ApiAdapter((request) {
      if (request.uri.host != 'api.copy4000.com' ||
          request.headers['version'] != '2026.08.21' ||
          request.headers['platform'] != '1' ||
          request.headers.containsKey('x-auth-signature')) {
        return {'code': 400, 'message': '请使用APP'};
      }
      return {
        'code': 200,
        'results': {
          'comic': {'path_word': 'sample', 'name': '示例漫画'},
          'groups': {},
        },
      };
    });
    final detail = await source.getComicDetail('sample', '');
    expect(detail?.title, '示例漫画');
  });

  test('hot manga pages and copy roasts use separate hosts and credentials',
      () async {
    await config('apiDomain', 'api.manga2025.com');
    await config('chapterCommentApiDomain', 'api.copy3000.com');
    await config('isLogin', true);
    await config('token', 'copy-token');
    await config('isLogin', true, model: 'hotmanga');
    await config('token', 'hot-token', model: 'hotmanga');
    handler.dio.httpClientAdapter = ApiAdapter((request) {
      if (request.uri.path.contains('/chapter/')) {
        expect(request.uri.host, 'api.manga2025.com');
        expect(request.headers['authorization'], 'Token hot-token');
        expect(request.headers['version'], '2025.11.21');
        return {
          'code': 200,
          'results': {
            'chapter': {
              'uuid': 'shared-uuid',
              'name': '第一话',
              'contents': [
                {'url': 'https://images.example/page.jpg'}
              ],
            },
          },
        };
      }
      if (request.uri.path.endsWith('/roasts')) {
        expect(request.uri.host, 'api.copy3000.com');
        expect(request.uri.queryParameters['chapter_id'], 'shared-uuid');
        expect(request.headers['authorization'], isNot('Token hot-token'));
        return {
          'code': 200,
          'results': {
            'list': [
              {'id': 1, 'comment': '拷贝吐槽', 'user_avatar': ''}
            ]
          },
        };
      }
      return {'code': 404, 'results': {}};
    });
    final detail =
        CopyMangaComicDetailModel({'path_word': 'sample'}, source, {});
    final chapter = await detail.getChapter('shared-uuid');
    expect(chapter?.pages.single.imageUrl, 'https://images.example/page.jpg');
    expect(await chapter!.getChapterComments(), hasLength(1));
  });

  test('chapter ordering sorts non-contiguous words without losing images', () {
    final chapter = CopyMangaComicChapterDetailModel({
      'words': [20, 5, 10],
      'contents': [
        {'url': 'https://example.com/third.jpg'},
        {'url': 'https://example.com/first.jpg'},
        {'url': 'https://example.com/second.jpg'},
      ],
    });
    expect(chapter.pages.map((page) => page.imageUrl), [
      'https://example.com/first.jpg',
      'https://example.com/second.jpg',
      'https://example.com/third.jpg',
    ]);
  });

  test('chapter groups fetch beyond server page cap', () async {
    handler.dio.httpClientAdapter = ApiAdapter((request) {
      if (request.uri.path.contains('/comic2/')) {
        return {
          'code': 200,
          'results': {
            'comic': {'path_word': 'sample', 'name': '示例漫画'},
            'groups': {
              'default': {'path_word': 'default', 'name': '章节', 'count': 101}
            },
          },
        };
      }
      final offset = int.parse(request.uri.queryParameters['offset']!);
      final count = offset == 0 ? 100 : 1;
      return {
        'code': 200,
        'results': {
          'total': 101,
          'limit': 100,
          'offset': offset,
          'list': List.generate(
              count,
              (i) => {
                    'uuid': '${offset + i}',
                    'name': '第${offset + i}话',
                    'datetime_created': '2026-01-01T00:00:00',
                  }),
        },
      };
    });
    final detail = await source.getComicDetail('sample', '');
    expect(detail!.chapters['章节']!.map((chapter) => chapter.chapterId),
        contains('100'));
  });

  test('search retains reserved characters', () async {
    const keyword = '漫画 & # + ?';
    handler.dio.httpClientAdapter = ApiAdapter((request) {
      return {
        'code': 200,
        'results': {'list': [], 'query': request.uri.queryParameters['q']},
      };
    });
    final result = await handler.search(keyword);
    expect(result.data['results']['query'], keyword);
  });

  test('switching accounts clears profile and restores each site token',
      () async {
    final account = source.accountModel!;
    account.logger = Logger(output: ConsoleOutput());
    await config('isLogin', true);
    await config('token', 'copy-token');
    handler.dio.httpClientAdapter = ApiAdapter((request) => {
          'code': 200,
          'results': {
            'user_id': 7,
            'username': 'copy-user',
            'nickname': 'Copy',
            'avatar': 'https://example.com/avatar.png',
          },
        });
    await account.initAccount();
    expect(account.token, 'copy-token');
    await config('apiDomain', 'api.manga2025.com');
    await account.initAccount();
    expect(account.isLogin, isFalse);
    expect(account.token, isNull);
    expect(account.nickname, isNull);
    await config('apiDomain', 'api.copy4000.com');
    await account.initAccount();
    expect(account.token, 'copy-token');
    expect(account.nickname, 'Copy');
  });

  test('logout persists only the selected site and leaves copy account intact',
      () async {
    await config('isLogin', true);
    await config('token', 'copy-token');
    await config('apiDomain', 'api.manga2025.com');
    await config('isLogin', true, model: 'hotmanga');
    await config('token', 'hot-token', model: 'hotmanga');
    handler.dio.httpClientAdapter =
        ApiAdapter((request) => {'code': 200, 'results': {}});
    await source.accountModel!.logout();
    final dao = (await DatabaseInstance.instance).modelConfigDao;
    expect(
        (await dao.getConfigByKeyAndModel('isLogin', 'hotmanga'))!.get<bool>(),
        isFalse);
    expect(
        (await dao.getConfigByKeyAndModel('token', 'hotmanga'))!.get<String>(),
        '');
    expect(
        (await dao.getConfigByKeyAndModel('token', 'copymanga'))!.get<String>(),
        'copy-token');
    await source.accountModel!.initAccount();
    expect(source.accountModel!.isLogin, isFalse);
  });

  test('rejected account no longer authenticates subsequent public requests',
      () async {
    await config('isLogin', true);
    await config('token', 'expired-token');
    handler.dio.httpClientAdapter = ApiAdapter((request) {
      if (request.uri.path.endsWith('/member/info')) {
        return {'code': 401, 'message': 'Invalid token', 'results': {}};
      }
      return {
        'code': 200,
        'results': {'authorization': request.headers['authorization']},
      };
    });
    await source.accountModel!.initAccount();
    final result = await handler.search('sample');
    expect(result.data['results']['authorization'], isNull);
  });

  test('copy homepage parses completed comics without theme', () async {
    handler.dio.httpClientAdapter = ApiAdapter((_) => homepageData(1));
    final cards = await source.homepage!.getHomepageCard();
    expect(cards.last.children.single.title, '完结 1');
    expect(cards.last.children.single.subtitle, '');
    expect(cards.first.children.single.subtitle, '日常');
  });

  test('hot homepage uses its weekly ranking and update sections', () async {
    await config('apiDomain', 'api.manga2025.com');
    handler.dio.httpClientAdapter =
        ApiAdapter((_) => homepageData(1, hot: true));
    final cards = await source.homepage!.getHomepageCard();
    expect(cards.map((card) => card.title),
        ['推荐漫画', '免费周榜', '付费周榜', '免费更新', '付费更新']);
    expect(cards.last.children.single.title, '漫画 1');
  });

  test('homepage refresh fetches new data despite a fresh five-minute cache',
      () async {
    final cache = MemCacheStore();
    addTearDown(cache.close);
    handler.dio.interceptors
        .add(InterceptorsWrapper(onResponse: (response, next) {
      response.headers.set('cache-control', 'max-age=300');
      next.next(response);
    }));
    handler.dio.interceptors
        .add(DioCacheInterceptor(options: CacheOptions(store: cache)));
    var revision = 1;
    handler.dio.httpClientAdapter = ApiAdapter((_) => homepageData(revision));
    await handler.getHomepage();
    revision = 2;
    final response = await handler.getHomepage();
    expect(response.data['results']['banners'][0]['brief'], '轮播 2');
  });

  test('homepage business failure is not reported as empty successful content',
      () async {
    handler.dio.httpClientAdapter = ApiAdapter((_) => {
          'code': 503,
          'message': '首页暂不可用',
          'results': {},
        });
    await expectLater(
        source.homepage!.getHomepageCard(), throwsA(isA<StateError>()));
  });

  testWidgets(
      'failed refresh preserves the whole homepage and a later refresh recovers',
      (tester) async {
    final controller = ComicHomepageController();
    final provider = ComicSourceProvider()..sources = [source];
    addTearDown(controller.dispose);
    addTearDown(provider.dispose);
    late BuildContext context;
    await tester.pumpWidget(ChangeNotifierProvider<ComicSourceProvider>.value(
      value: provider,
      child: Builder(builder: (value) {
        context = value;
        return const SizedBox();
      }),
    ));
    var revision = 1;
    var request = 0;
    var fail = false;
    handler.dio.httpClientAdapter = ApiAdapter((_) {
      request++;
      if (fail && request.isEven) throw StateError('Homepage offline');
      return homepageData(revision, finishTheme: true);
    });
    await tester.runAsync(() => controller.refresh(context));
    revision = 2;
    fail = true;
    await tester.runAsync(() =>
        expectLater(controller.refresh(context), throwsA(isA<DioException>())));
    expect(controller.homepageCarousels.single.title, '轮播 1');
    expect(controller.homepageCards.first.children.single.title, '漫画 1');
    fail = false;
    await tester.runAsync(() => controller.refresh(context));
    expect(controller.homepageCarousels.single.title, '轮播 2');
    expect(controller.homepageCards.first.children.single.title, '漫画 2');
  });
}
