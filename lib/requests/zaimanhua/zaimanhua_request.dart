import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:dcomic/requests/base_request.dart';
import 'package:dio/dio.dart';

import '../../database/database_instance.dart';

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
  ZaiManHuaMobileRequestHandler() : super('https://v4api.zaimanhua.com/app/v1');

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

  Future<Response> search(String keyword, {int page = 0, int limit = 20}) {
    return dio.get('/search/index?keyword=$keyword&page=$page&size=$limit');
  }

  Future<Response> getComments(String comicId,
      {int page = 0, int type = 4, int sort = 1, int limit = 30}) async {
    return dio.get(
        '/comment/list?type=$type&objId=$comicId&sort=$sort&page=$page&size=$limit',
        options: await setHeader());
  }

  Future<Response> getHomepageRecommend(int category) {
    return dio.get('/recommend/batchUpdate?category_id=$category');
  }

  Future<Response> getMainPageRecommend() {
    return dio.get('/comic/recommend/index');
  }

  Future<Response> getCategory() {
    return dio.get('/comic/filter/category');
  }

  Future<Response> getCategoryDetail(int tagId,
      {int page = 0, int type = 0, int limit = 20}) {
    return dio.get(
        '/comic/filter/list?tag_id=$tagId&status=0&by_time=$type&page=$page&size=$limit');
  }

  Future<Response> getRankList(
      {int page = 0, int byTime = 3, int rankType = 0, int tagId = 0}) {
    return dio.get(
        '/comic/rank/list?tag_id=$tagId&rank_type=$rankType&by_time=$byTime&page=${page + 1}');
  }

  Future<Response> getLatestList({int page = 0, int type = 0}) {
    return dio.get('/comic/update/list/$type/${page + 1}');
  }

  Future<Response> getSubscribe(
      {int status = 1,
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
}

class ZaiManHuaAccountRequestHandler extends RequestHandler {
  ZaiManHuaAccountRequestHandler()
      : super('https://account-api.zaimanhua.com/v1');

  Future<Response> login(String username, String password) {
    var pwd = md5.convert(utf8.encode(password)).toString().toLowerCase();
    Map<String, dynamic> data = {
      "username": Uri.encodeComponent(username),
      "passwd": pwd,
    };
    return dio.post('/login/passwd', data: data);
  }
}
