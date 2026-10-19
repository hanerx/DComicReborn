import 'dart:io';

import 'package:dcomic/database/database_instance.dart';
import 'package:dcomic/providers/models/copymanga/copymanga_topic_model.dart';
import 'package:dcomic/providers/models/zaimanhua/zaimanhua_topic_model.dart';
import 'package:dcomic/requests/base_request.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'zaimanhua_api_test.dart' show ApiAdapter, TestPaths;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory temporaryDirectory;
  late final copyHandler = RequestHandlers.copyMangaRequestHandler;
  late final zaiHandler = RequestHandlers.zaiManHuaMobileRequestHandler;
  final copyTopics = CopyMangaTopicModel();
  final zaiTopics = ZaiManHuaTopicModel();

  setUpAll(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp('comic_topics_');
    PathProviderPlatform.instance = TestPaths(temporaryDirectory.path);
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    await databaseFactory.setDatabasesPath(temporaryDirectory.path);
    await RequestStatics.store;
    copyHandler.dio.interceptors.clear();
    zaiHandler.dio.interceptors.clear();
  });

  setUp(() async {
    copyHandler.dio.interceptors.clear();
    zaiHandler.dio.interceptors.clear();
    await (await DatabaseInstance.instance).database.delete(
      'ModelConfigEntity',
    );
  });

  tearDownAll(() async {
    copyHandler.dio.close(force: true);
    zaiHandler.dio.close(force: true);
    await (await DatabaseInstance.instance).close();
    await (await RequestStatics.store).close();
    await temporaryDirectory.delete(recursive: true);
  });

  test(
    'CopyManga topic pages preserve raw text and use raw API pagination',
    () async {
      final offsets = <String?>[];
      copyHandler.dio.httpClientAdapter = ApiAdapter((request) {
        expect(request.uri.path, '/api/v3/topics');
        expect(request.uri.queryParameters['limit'], '20');
        offsets.add(request.uri.queryParameters['offset']);
        final offset = int.parse(request.uri.queryParameters['offset']!);
        return {
          'code': 200,
          'results': {
            'list': offset == 0
                ? [
                    {
                      'title': '原始標題',
                      'cover': 'https://example.com/topic.jpg',
                      'brief': '原始簡介',
                      'path_word': 'topic/raw-id',
                      'datetime_created': '2026-10-01',
                    },
                    {
                      'title': '无标识专题',
                      'cover': 'https://example.com/missing.jpg',
                      'brief': '',
                      'path_word': '',
                      'datetime_created': '2026-10-02',
                    },
                  ]
                : const [],
            'total': 2,
            'limit': 20,
            'offset': offset,
          },
        };
      });

      final first = await copyTopics.getTopics();
      expect(first.items, hasLength(1));
      expect(first.items.single.id, 'topic/raw-id');
      expect(first.items.single.title, '原始標題');
      expect(first.items.single.description, '原始簡介');
      expect(first.items.single.date, '2026-10-01');
      expect(
        first.items.single.cover.imageUrl,
        'https://example.com/topic.jpg',
      );
      expect(
        first.nextPage,
        isNull,
        reason: 'Two raw records exhaust the server total despite filtering.',
      );

      final end = await copyTopics.getTopics(page: 1);
      expect(end.items, isEmpty);
      expect(end.nextPage, isNull);
      expect(offsets, ['0', '20']);
    },
  );

  test(
    'CopyManga detail combines metadata and first deduplicated comic page',
    () async {
      final requestedRoutes = <String>[];
      copyHandler.dio.httpClientAdapter = ApiAdapter((request) {
        expect(request.uri.pathSegments, contains('topic/raw-id'));
        requestedRoutes.add(request.uri.pathSegments.last);
        if (request.uri.pathSegments.last != 'contents') {
          return {
            'code': 200,
            'results': {
              'title': '專題原文',
              'cover': 'https://example.com/detail.jpg',
              'brief': '短介',
              'intro': '完整介紹',
              'path_word': 'topic/raw-id',
              'datetime_created': '2026-10-03',
            },
          };
        }
        expect(request.uri.pathSegments.last, 'contents');
        expect(request.uri.queryParameters['limit'], '30');
        expect(request.uri.queryParameters['offset'], '0');
        return {
          'code': 200,
          'results': {
            'list': [
              {
                'name': '漫畫原文',
                'path_word': 'comic/raw-id',
                'cover': 'https://example.com/comic.jpg',
                'theme': [
                  {'name': '奇幻'},
                ],
                'author': [
                  {'name': '作者甲'},
                ],
                'type': 1,
              },
              {
                'name': '重複漫畫',
                'path_word': 'comic/raw-id',
                'cover': 'https://example.com/duplicate.jpg',
                'theme': const [],
                'author': const [],
                'type': 1,
              },
              {
                'name': '缺失标识',
                'path_word': null,
                'cover': 'https://example.com/missing.jpg',
                'theme': const [],
                'author': const [],
                'type': 1,
              },
            ],
            'total': 31,
            'limit': 30,
            'offset': 0,
          },
        };
      });

      final detail = await copyTopics.getDetail('topic/raw-id');
      expect(requestedRoutes, containsAll(['topic/raw-id', 'contents']));
      expect(detail.topic.id, 'topic/raw-id');
      expect(detail.topic.title, '專題原文');
      expect(detail.topic.description, '完整介紹');
      expect(detail.comics.items, hasLength(1));
      expect(detail.comics.items.single.id, 'comic/raw-id');
      expect(detail.comics.items.single.title, '漫畫原文');
      expect(detail.comics.items.single.description, '作者甲 · 奇幻');
      expect(
        detail.comics.nextPage,
        1,
        reason: 'Continuation is based on raw response count, not filtering.',
      );
    },
  );

  test(
    'CopyManga comic pagination uses the requested raw page offset',
    () async {
      copyHandler.dio.httpClientAdapter = ApiAdapter((request) {
        expect(request.uri.path, '/api/v3/topic/topic-id/contents');
        expect(request.uri.queryParameters['limit'], '30');
        expect(request.uri.queryParameters['offset'], '30');
        return {
          'code': 200,
          'results': {'list': const [], 'total': 30, 'limit': 30, 'offset': 30},
        };
      });

      final page = await copyTopics.getComics('topic-id', page: 1);
      expect(page.items, isEmpty);
      expect(page.nextPage, isNull);
    },
  );

  test(
    'CopyManga rejects business errors and malformed successful payloads',
    () async {
      copyHandler.dio.httpClientAdapter = ApiAdapter(
        (_) => {'code': 503, 'message': '专题暂不可用'},
      );
      await expectLater(copyTopics.getTopics(), throwsStateError);

      copyHandler.dio.httpClientAdapter = ApiAdapter(
        (_) => {
          'code': 200,
          'results': {
            'list': 'not-a-list',
            'total': 0,
            'limit': 20,
            'offset': 0,
          },
        },
      );
      await expectLater(copyTopics.getTopics(), throwsStateError);
    },
  );

  test(
    'ZaiManHua topic pages use absolute h5 routes and raw metadata',
    () async {
      final pages = <String?>[];
      zaiHandler.dio.httpClientAdapter = ApiAdapter((request) {
        expect(request.uri.origin, 'https://v4api.zaimanhua.com');
        expect(request.uri.path, '/api/v1/zt/h5/list');
        expect(request.uri.queryParameters['size'], '24');
        pages.add(request.uri.queryParameters['page']);
        final page = int.parse(request.uri.queryParameters['page']!);
        return {
          'errno': 0,
          'errmsg': '',
          'data': {
            'currentPage': page,
            'size': 24,
            'total': 48,
            'subjectList': page == 1
                ? [
                    {
                      'id': 606,
                      'title': '原始专题',
                      'short_title': '原始短题',
                      'cover': 'https://example.com/zai-topic.jpg',
                      'create_time': '2026-10-04',
                      'redirectUrl': '',
                    },
                    {
                      'id': 607,
                      'title': '外部专题',
                      'short_title': '跳转',
                      'cover': 'https://example.com/external.jpg',
                      'create_time': '2026-10-05',
                      'redirectUrl': 'https://outside.example/topic',
                    },
                    {
                      'id': null,
                      'title': '缺失标识',
                      'short_title': '',
                      'cover': 'https://example.com/missing.jpg',
                      'create_time': '2026-10-05',
                      'redirectUrl': '',
                    },
                  ]
                : null,
          },
        };
      });

      final first = await zaiTopics.getTopics();
      expect(first.items, hasLength(1));
      expect(first.items.single.id, '606');
      expect(first.items.single.title, '原始专题');
      expect(first.items.single.description, '原始短题');
      expect(first.items.single.date, '2026-10-04');
      expect(
        first.nextPage,
        1,
        reason: 'External and invalid records do not change server paging.',
      );

      final end = await zaiTopics.getTopics(page: 1);
      expect(end.items, isEmpty);
      expect(end.nextPage, isNull);
      expect(pages, ['1', '2']);
    },
  );

  test(
    'ZaiManHua detail uses comic_id identity and returns all comics once',
    () async {
      final dao = (await DatabaseInstance.instance).modelConfigDao;
      await dao.getOrCreateConfigByKey('isLogin', 'zaimanhua', value: true);
      await dao.getOrCreateConfigByKey(
        'token',
        'zaimanhua',
        value: 'topic-session',
      );
      var requests = 0;
      zaiHandler.dio.httpClientAdapter = ApiAdapter((request) {
        requests++;
        expect(request.uri.origin, 'https://v4api.zaimanhua.com');
        expect(request.uri.path, '/api/v1/zt/h5/detail');
        expect(request.uri.queryParameters['id'], '603');
        expect(request.headers['Authorization'], 'Bearer topic-session');
        return {
          'errno': 0,
          'data': {
            'subject': {
              'id': 603,
              'title': '专题原文',
              'cover': 'https://example.com/subject.jpg',
              'summary': '未经转换的专题简介',
              'bannerCover': 'https://example.com/banner.jpg',
              'static_html': '',
            },
            'comicList': [
              {
                'id': 17660,
                'comic_id': 60911,
                'name': '漫画原文',
                'cover': 'https://example.com/zai-comic.jpg',
                'recommend_brief': '推荐简介',
                'recommend_reason': '推荐理由',
                'isSub': 0,
              },
              {
                'id': 17661,
                'comic_id': 60911,
                'name': '重复漫画',
                'cover': 'https://example.com/duplicate.jpg',
                'recommend_brief': '',
                'recommend_reason': '',
                'isSub': 0,
              },
              {
                'id': 17662,
                'comic_id': null,
                'name': '缺失导航标识',
                'cover': 'https://example.com/missing.jpg',
                'recommend_brief': '',
                'recommend_reason': '',
                'isSub': 0,
              },
              {
                'id': 17663,
                'comic_id': 60912,
                'name': null,
                'recommend_brief': '已下架',
                'recommend_reason': '已下架漫画不应中断整个专题',
                'isSub': 0,
              },
            ],
          },
        };
      });

      final detail = await zaiTopics.getDetail('603');
      expect(detail.topic.id, '603');
      expect(detail.topic.title, '专题原文');
      expect(detail.topic.description, '未经转换的专题简介');
      expect(detail.comics.items, hasLength(1));
      expect(
        detail.comics.items.single.id,
        '60911',
        reason: 'comic_id, not the topic row id, is the navigation identity.',
      );
      expect(detail.comics.items.single.description, '推荐简介\n推荐理由');
      expect(detail.comics.nextPage, isNull);

      final samePage = await zaiTopics.getComics('603', page: 0);
      expect(samePage.items.single.id, '60911');
      expect(samePage.nextPage, isNull);
      expect(requests, 2);
      await expectLater(zaiTopics.getComics('603', page: 1), throwsStateError);
      expect(
        requests,
        2,
        reason: 'Unsupported pages must fail before a request.',
      );
    },
  );

  test(
    'ZaiManHua rejects business errors and malformed successful payloads',
    () async {
      zaiHandler.dio.httpClientAdapter = ApiAdapter(
        (_) => {'errno': 401, 'errmsg': 'expired', 'data': {}},
      );
      await expectLater(zaiTopics.getTopics(), throwsStateError);

      zaiHandler.dio.httpClientAdapter = ApiAdapter(
        (_) => {
          'errno': 0,
          'data': {
            'currentPage': 1,
            'size': 24,
            'total': 1,
            'subjectList': {'id': 606},
          },
        },
      );
      await expectLater(zaiTopics.getTopics(), throwsStateError);

      zaiHandler.dio.httpClientAdapter = ApiAdapter(
        (_) => {
          'errno': 0,
          'data': {'subject': 'not-an-object', 'comicList': const []},
        },
      );
      await expectLater(zaiTopics.getDetail('603'), throwsStateError);
    },
  );
}
