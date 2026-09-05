import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:dcomic/requests/base_request.dart';
import 'package:dio/dio.dart';

import '../../database/database_instance.dart';

void _configureAppClient(Dio dio) {
  const version = '2.3.5';
  const channel = '101_01_01_000';
  // Without _v, reader endpoints report existing comics as deleted.
  dio.options.queryParameters.addAll({
    '_v': version,
    '_c': channel,
    'platform': 'android',
  });
  dio.options.headers.addAll({
    'appversion': version,
    'channel': channel,
    'platform': 'android',
  });
}

class ZaiManHuaRequestHandler extends RequestHandler {
  ZaiManHuaRequestHandler() : super("https://manhua.zaimanhua.com");

  Future<Response> getComicDetail(String comicPinYin) {
    return dio.get(
        '/api/v1/comic1/comic/detail?channel=%20pc&app_name=zmh&version=1.0.0&timestamp=${DateTime.timestamp()}&uid=113119197&comic_py=$comicPinYin');
  }

  Future<Response> getComicChapterDetail(int comicId, String chapterId) {
    return dio.get(
        '/api/v1/comic1/chapter/detail?channel=pc&app_name=zmh&version=1.0.0&timestamp=1725890784556&comic_id=$comicId&chapter_id=$chapterId');
  }

  Future<Response> search(String keyword, {int page = 0, int limit = 20}) {
    return dio.get(
        '/app/v1/search/index?keyword=$keyword&source=0&page=${page + 1}&size=$limit');
  }
}

class ZaiManHuaMobileRequestHandler extends RequestHandler {
  ZaiManHuaMobileRequestHandler()
      : super('https://v4api.zaimanhua.com/app/v1') {
    _configureAppClient(dio);
  }

  Future<Options> setHeader([Map<String, dynamic>? headers]) async {
    headers ??= {};
    var databaseInstance = await DatabaseInstance.instance;
    var isLoginEntity = await databaseInstance.modelConfigDao
        .getConfigByKeyAndModel('isLogin', 'zaimanhua');
    if (isLoginEntity != null && isLoginEntity.get<bool>()) {
      String token = (await (await DatabaseInstance.instance)
                  .modelConfigDao
                  .getConfigByKeyAndModel('token', 'zaimanhua'))
              ?.value ??
          '';
      headers['Authorization'] = 'Bearer $token';
    }
    return Options(headers: headers);
  }

  Future<Response> getComicDetail(String comicId) async {
    return dio.get('/comic/detail/$comicId', options: await setHeader());
  }

  Future<Response> getComicChapterDetail(
      String comicId, String chapterId) async {
    return dio.get('/comic/chapter/$comicId/$chapterId',
        options: await setHeader());
  }

  Future<Response> search(String keyword,
      {int page = 0, int limit = 20}) async {
    return dio.get('/search/index',
        queryParameters: {
          'keyword': keyword,
          'page': page + 1,
          'size': limit,
        },
        options: await setHeader());
  }

  Future<Response> getComments(String comicId,
      {int page = 0, int type = 4, int sort = 1, int limit = 30}) async {
    return dio.get('/comment/list',
        queryParameters: {
          'type': type,
          'objId': comicId,
          'sortBy': sort,
          'page': page + 1,
          'size': limit,
        },
        options: await setHeader());
  }

  Future<Response> getHomepageRecommend(int category) {
    return dio.get('/recommend/batchUpdate?category_id=$category');
  }

  Future<Response> getMainPageRecommend() {
    return dio.get('/comic/recommend/index');
  }

  Future<Response> getCategory() async {
    return dio.get('/comic/filter/category',
        queryParameters: {'source': 1}, options: await setHeader());
  }

  Future<Response> getCategoryDetail(int tagId,
      {int page = 0,
      int type = 0,
      int limit = 20,
      int categoryType = 0}) async {
    final filterKey = switch (categoryType) {
      4 => 'zone',
      5 => 'status',
      6 => 'cate',
      _ => 'theme',
    };
    return dio.get('/comic/filter/list',
        queryParameters: {
          'status': 0,
          'theme': 0,
          'zone': 0,
          'sortType': 2 - type,
          'page': page + 1,
          'size': limit,
          'cate': 0,
          filterKey: tagId,
        },
        options: await setHeader());
  }

  Future<Response> getRankList(
      {int page = 0, int byTime = 0, int rankType = 0, int tagId = 0}) async {
    return dio.get('/comic/rank/list',
        queryParameters: {
          'tag_id': tagId,
          'rank_type': rankType,
          'by_time': byTime,
          'page': page + 1,
        },
        options: await setHeader());
  }

  Future<Response> getLatestList({int page = 0, int type = 0}) async {
    return dio.get('/comic/update/list/$type/${page + 1}',
        options: await setHeader());
  }

  Future<Response> getSubscribe(
      {int status = 0,
      String firstLetter = '',
      int page = 0,
      int limit = 20}) async {
    return dio.get(
        '/comic/sub/list?status=$status&firstLetter=$firstLetter&page=${page + 1}&size=$limit',
        options: await setHeader());
  }

  Future<Response> addComicSubScribe(String comicId) async {
    return dio.get('/comic/sub/add?comic_id=$comicId',
        options: await setHeader());
  }

  Future<Response> cancelComicSubScribe(String comicId) async {
    return dio.get('/comic/sub/del?comic_id=$comicId',
        options: await setHeader());
  }

  Future<Response> checkIfSubscribe(String comicId, {int type = 1}) async {
    return dio.get('/comic/sub/checkIsSub?objId=$comicId&source=$type',
        options: await setHeader());
  }

  Future<Response> getViewpoint(String comicId, String chapterId,
      {int type = 0, int page = 0}) async {
    if (page > 0) {
      return dio.get(
          '/viewpoint/list?type=$type&comicId=$comicId&chapterId=$chapterId&page=$page',
          options: await setHeader());
    }
    return dio.get(
        '/viewpoint/list?type=$type&comicId=$comicId&chapterId=$chapterId',
        options: await setHeader());
  }
}

class ZaiManHuaAccountRequestHandler extends RequestHandler {
  ZaiManHuaAccountRequestHandler()
      : super('https://account-api.zaimanhua.com/v1') {
    _configureAppClient(dio);
  }

  Future<Options> setHeader([Map<String, dynamic>? headers]) async {
    headers ??= {};
    var databaseInstance = await DatabaseInstance.instance;
    var isLoginEntity = await databaseInstance.modelConfigDao
        .getConfigByKeyAndModel('isLogin', 'zaimanhua');
    if (isLoginEntity != null && isLoginEntity.get<bool>()) {
      String token = (await (await DatabaseInstance.instance)
                  .modelConfigDao
                  .getConfigByKeyAndModel('token', 'zaimanhua'))
              ?.value ??
          '';
      headers['Authorization'] = 'Bearer $token';
    }
    return Options(headers: headers);
  }

  Future<Response> login(String username, String password) {
    var pwd = md5.convert(utf8.encode(password)).toString().toLowerCase();
    Map<String, dynamic> data = {
      "username": username,
      "passwd": pwd,
    };
    return dio.post('/login/passwd', data: data);
  }

  Future<Response> getUserData() async {
    return dio.get('/u_center/personal/info/get', options: await setHeader());
  }
}
