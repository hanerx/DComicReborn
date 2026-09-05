import 'dart:convert';
import 'dart:math';

import 'package:dcomic/database/database_instance.dart';
import 'package:dcomic/requests/base_request.dart';
import 'package:dio/dio.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';

// Protocol and routes verified against LittleSurvival/copymanga-copy20 v1.4.84.
enum CopyMangaApiDomain {
  international('api.mangacopy.com', false),
  copy20('mapi.copy20.com', false),
  copy2000('mapi.copy2000.site', false),
  copy2026('api.2026copy.com', false),
  copy3000('api.copy3000.com', false),
  copy4000('api.copy4000.com', false),
  hotSD('mapi.hotmangasd.com', true),
  hot2025('api.manga2025.com', true),
  hotSF('mapi.hotmangasf.com', true),
  hotSG('mapi.hotmangasg.com', true),
  hotLine5('mapi.elfgjfghkk.club', true),
  hotLine6('mapi.fgjfghkk.club', true),
  hotLine7('mapi.fgjfghkkcenter.club', true);

  const CopyMangaApiDomain(this.host, this.isHotManga);

  final String host;
  final bool isHotManga;
  static const defaultDomain = copy4000;

  String get accountSourceId => isHotManga ? 'hotmanga' : 'copymanga';

  static CopyMangaApiDomain fromHost(String? host) => values.firstWhere(
        (domain) => domain.host == host,
        orElse: () => defaultDomain,
      );
}

class CopyMangaRequestHandler extends RequestHandler {
  static const imageHeaders = {
    'user-agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:109.0) Gecko/20100101 Firefox/114.0',
  };

  CopyMangaRequestHandler()
      : super('https://api.copy4000.com/', useCookie: false);

  Future<CopyMangaApiDomain> _domain(String key) async {
    final dao = (await DatabaseInstance.instance).modelConfigDao;
    final config = await dao.getConfigByKeyAndModel(key, 'copymanga');
    return CopyMangaApiDomain.fromHost(config?.get<String>());
  }

  Future<CopyMangaApiDomain> get apiDomain => _domain('apiDomain');

  Future<String> get accountSourceId async => (await apiDomain).accountSourceId;

  Future<CopyMangaApiDomain> get _commentDomain async {
    final domain = await _domain('chapterCommentApiDomain');
    return domain.isHotManga ? CopyMangaApiDomain.defaultDomain : domain;
  }

  Future<Options> _options(CopyMangaApiDomain domain,
      {bool login = true}) async {
    final headers = <String, dynamic>{
      ...imageHeaders,
      'accept': 'application/json',
      'accept-language': 'en-US,en;q=0.9,zh-TW;q=0.8,zh;q=0.7',
      'origin': domain.isHotManga
          ? 'https://m.relamanhua.org'
          : 'https://2025copy.com',
      'version': domain.isHotManga ? '2025.11.21' : '2026.08.21',
      if (!domain.isHotManga) 'region': '0',
      'webp': domain.isHotManga ? '1' : '0',
      'platform': '1',
      'sec-fetch-dest': 'document',
      'sec-fetch-mode': 'navigate',
      'sec-fetch-site': 'same-origin',
      'sec-fetch-user': '?1',
      'upgrade-insecure-requests': '1',
    };
    if (login) {
      final dao = (await DatabaseInstance.instance).modelConfigDao;
      final state =
          await dao.getConfigByKeyAndModel('isLogin', domain.accountSourceId);
      if (state?.get<bool>() == true) {
        final token =
            (await dao.getConfigByKeyAndModel('token', domain.accountSourceId))
                ?.get<String>();
        if (token != null && token.isNotEmpty) {
          headers['authorization'] = 'Token $token';
        }
      }
    }
    return Options(headers: headers);
  }

  Future<Response> _get(String path,
      {Map<String, dynamic>? query,
      CopyMangaApiDomain? domain,
      bool retryAnonymous = false}) async {
    // Capture the target once: changing settings must not mix hosts and tokens.
    final target = domain ?? await apiDomain;
    final url = 'https://${target.host}/api/v3/$path';
    final response = await dio.get(url,
        queryParameters: query, options: await _options(target));
    if (retryAnonymous &&
        (response.statusCode == 210 ||
            (response.data is Map && response.data['code'] == 210))) {
      return dio.get(url,
          queryParameters: query,
          options: await _options(target, login: false));
    }
    return response;
  }

  Future<Response> _post(String path,
      {Object? data, CopyMangaApiDomain? domain, bool login = true}) async {
    final target = domain ?? await apiDomain;
    return dio.post('https://${target.host}/api/v3/$path',
        data: data, options: await _options(target, login: login));
  }

  Future<Response> getComicDetail(String comicId) =>
      _get('comic2/${Uri.encodeComponent(comicId)}', retryAnonymous: true);

  // The API's offset counts chapters, not pages; each response is capped at 100.
  Future<Response> getChapters(String comicId, String groupName,
          {int limit = 100, int page = 0}) =>
      _get(
          'comic/${Uri.encodeComponent(comicId)}/group/${Uri.encodeComponent(groupName)}/chapters',
          query: {'limit': min(limit, 100), 'offset': page, '_update': true});

  Future<Response> getComic(String comicId, String chapterId) async {
    final domain = await apiDomain;
    final chapterPath = domain.isHotManga ? 'chapter' : 'chapter2';
    return _get(
        'comic/${Uri.encodeComponent(comicId)}/$chapterPath/${Uri.encodeComponent(chapterId)}',
        domain: domain,
        retryAnonymous: true);
  }

  Future<Response> search(String keyword, {int page = 0, int limit = 18}) =>
      _get('search/comic', query: {
        'limit': limit,
        'offset': page * limit,
        'q_type': '',
        'q': keyword,
      });

  Future<Response> login(String username, String password,
      {CopyMangaApiDomain? domain}) async {
    final target = domain ?? await apiDomain;
    final salt = Random.secure().nextInt(9000) + 1000;
    return _post('login',
        domain: target,
        login: false,
        data: FormData.fromMap({
          'username': username,
          'password': base64Encode(utf8.encode('$password-$salt')),
          'salt': salt,
          'source': target.isHotManga ? 'Offical' : 'freeSite',
          'version': target.isHotManga ? '2025.02.12' : '2025.05.09',
          'platform': 1,
        }));
  }

  Future<Response> logout({CopyMangaApiDomain? domain}) =>
      _post('logout', domain: domain);

  Future<Response> getSubscribe({int page = 0, int limit = 21}) =>
      _get('member/collect/comics', query: {
        'limit': limit,
        'offset': page * limit,
        'ordering': '-datetime_modifier',
      });

  Future<Response> getCategoryDetailList(
          {required String theme,
          int page = 0,
          int limit = 21,
          String order = '-datetime_modifier'}) =>
      _get('comics', query: {
        'free_type': 1,
        'theme': theme,
        'limit': limit,
        'offset': page * limit,
        '_update': true,
        'ordering': order,
      });

  Future<Response> getAuthorDetailList(
          {required String author,
          int page = 0,
          int limit = 21,
          String order = '-datetime_modifier'}) =>
      _get('comics', query: {
        'free_type': 1,
        'author': author,
        'limit': limit,
        'offset': page * limit,
        'ordering': order,
      });

  Future<Response> getRankList(
          {String dateType = 'day', int limit = 21, int page = 0}) =>
      _get('ranks', query: {
        'type': 1,
        'date_type': dateType,
        'limit': limit,
        'offset': page * limit,
      });

  Future<Response> getLatestList({int limit = 21, int page = 0}) =>
      _get('update/newest', query: {'limit': limit, 'offset': page * limit});

  Future<Response> getUserInfo({CopyMangaApiDomain? domain}) =>
      _get('member/info', domain: domain);

  Future<Response> getIfSubscribe(String comicId) =>
      _get('comic2/query/${Uri.encodeComponent(comicId)}');

  Future<Response> addSubscribe(String comicId, bool subscribe) =>
      _post('member/collect/comic',
          data: FormData.fromMap({
            'comic_id': comicId,
            'is_collect': subscribe ? 1 : 0,
          }));

  Future<Response> getHomepage() async {
    final target = await apiDomain;
    final requestOptions = await _options(target);
    // Pull-to-refresh must reach the server even during its five-minute TTL.
    // Do not turn a failed refresh into a successful stale-cache response.
    requestOptions.extra =
        const CacheOptions(store: null, policy: CachePolicy.refresh).toExtra();
    final response = await dio.get('https://${target.host}/api/v3/h5/homeIndex',
        options: requestOptions);
    if (response.data is! Map || response.data['code'] != 200) {
      throw StateError(response.data is Map
          ? '${response.data['message'] ?? 'Failed to refresh homepage'}'
          : 'Invalid homepage response');
    }
    return response;
  }

  Future<Response> getTagList(
          {bool popular = true,
          int page = 0,
          int limit = 21,
          String? categoryId,
          String? authorId}) =>
      _get('comics', query: {
        'free_type': 1,
        'limit': limit,
        'offset': page * limit,
        if (categoryId != null) 'theme': categoryId,
        if (authorId != null) 'author': authorId,
        'ordering': popular ? '-popular' : '-datetime_updated',
        '_update': true,
      });

  Future<Response> getSubjectList({int page = 0, int limit = 20}) =>
      _get('topics', query: {
        'type': 1,
        'limit': limit,
        'offset': page * limit,
        '_update': true,
      });

  Future<Response> getSubjectDetail(String subjectId) =>
      _get('topic/${Uri.encodeComponent(subjectId)}');

  Future<Response> getSubjectDetailContent(String subjectId,
          {int page = 0, int limit = 30}) =>
      _get('topic/${Uri.encodeComponent(subjectId)}/contents',
          query: {'limit': limit, 'offset': page * limit});

  Future<Response> getCategory() => _get('theme/comic/count', query: {
        'free_type': 1,
        'limit': 500,
        'offset': 0,
        '_update': true,
      });

  Future<Response> getChapterComments(String chapterId,
          {int limit = 50, int page = 0}) async =>
      _get('roasts', domain: await _commentDomain, query: {
        'chapter_id': chapterId,
        'limit': limit,
        'offset': page * limit,
      });

  Future<Response> getComments(String comicId,
          {int limit = 20, int page = 0}) async =>
      _get('comments', domain: await _commentDomain, query: {
        'comic_id': comicId,
        'limit': limit,
        'offset': page * limit,
      });

  Future<Response> getHistory({int limit = 12, int page = 0}) =>
      _get('member/browse/comics', query: {
        'limit': limit,
        'offset': page * limit,
      });
}
