import 'dart:convert';
import 'dart:math';

import 'package:dcomic/database/database_instance.dart';
import 'package:dcomic/requests/base_request.dart';
import 'package:dio/dio.dart';

class CopyMangaRequestHandler extends RequestHandler {
  CopyMangaRequestHandler()
      : super('https://api.mangacopy.com/', useCookie: false);

  Future<Options> setHeader([Map<String, dynamic>? headers]) async {
    headers ??= {};
    var databaseInstance = await DatabaseInstance.instance;
    var isLoginEntity = await databaseInstance.modelConfigDao
        .getConfigByKeyAndModel('isLogin', 'copymanga');
    if (isLoginEntity != null && isLoginEntity.get<bool>()) {
      String token = (await (await DatabaseInstance.instance)
                  .modelConfigDao
                  .getConfigByKeyAndModel('token', 'copymanga'))
              ?.value ??
          '';
      headers['authorization'] = 'Token $token';
    }
    headers['region'] = (await (await DatabaseInstance.instance)
                .modelConfigDao
                .getConfigByKeyAndModel('login', 'copymanga'))
            ?.value ??
        '0';
    return Options(headers: headers);
  }

  Future<Response> getComicDetail(String comicId) {
    return dio.get('/api/v3/comic2/$comicId?platform=1');
  }

  Future<Response> getChapters(String comicId, String groupName,
      {int limit = 100, int page = 0}) async {
    return dio.get(
        '/api/v3/comic/$comicId/group/$groupName/chapters?limit=$limit&offset=$page',
        options: await setHeader({'Platform': '1'}));
  }

  Future<Response> getComic(String comicId, String chapterId) async {
    return dio.get(
        '/api/v3/comic/$comicId/chapter/$chapterId?platform=1&_update=true',
        options: await setHeader({
          'User-Agent':
              'Mozilla/5.0 (Windows NT 6.1; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/43.0.2357.134 Safari/537.36'
        }));
  }

  Future<Response> search(String keyword,
      {int page = 0, int limit = 18}) async {
    return dio.get(
        '/api/v3/search/comic?limit=$limit&offset=${page * limit}&q_type=&q=$keyword&platform=3',
        options: Options(headers: {
          'platform': '3',
          'version': '2.2.6',
          'User-Agent': 'COPY/2.2.6'
        }));
  }

  Future<Response> login(String username, String password) async {
    int salt = Random().nextInt(9000) + 1000;
    var data = FormData.fromMap({
      'username': username,
      'password': base64Encode(utf8.encode('$password-$salt')),
      'salt': salt,
      'source': 'freeSite',
      'version': '2021.04.01',
      'platform': 1
    });
    return dio.post('/api/v3/login', data: data);
  }

  Future<Response> logout() async {
    return dio.post('/api/v3/logout', options: await setHeader());
  }

  Future<Response> getSubscribe({int page = 0, int limit = 21}) async {
    return dio.get(
        '/api/v3/member/collect/comics?free_type=1&limit=$limit&offset=${page * limit}&_update=true&ordering=-datetime_updated',
        options: await setHeader());
  }

  Future<Response> getCategoryDetailList(
      {required String theme,
      int page = 0,
      int limit = 21,
      String order = '-datetime_modifier'}) async {
    return dio.get(
        '/api/v3/comics?free_type=1&theme=$theme&limit=$limit&offset=${page * limit}&_update=true&ordering=$order');
  }

  Future<Response> getAuthorDetailList(
      {required String author,
      int page = 0,
      int limit = 21,
      String order = '-datetime_modifier'}) async {
    return dio.get(
        '/api/v3/comics?free_type=1&author=$author&limit=$limit&offset=${page * limit}&ordering=$order');
  }

  Future<Response> getRankList(
      {String dateType = 'day', int limit = 21, int page = 0}) {
    return dio.get(
        '/api/v3/ranks?type=1&date_type=$dateType&limit=$limit&offset=${limit * page}');
  }

  Future<Response> getLatestList({int limit = 21, int page = 0}) {
    return dio.get('/api/v3/update/newest?limit=$limit&offset=${limit * page}');
  }

  Future<Response> getUserInfo() async {
    return dio.get('/api/v3/member/info', options: await setHeader());
  }

  Future<Response> getIfSubscribe(String comicId) async {
    return dio.get('/api/v3/comic2/query/$comicId?platform=1',
        options: await setHeader());
  }

  Future<Response> addSubscribe(String comicId, bool subscribe) async {
    var data = FormData.fromMap(
        {'comic_id': comicId, 'is_collect': subscribe ? 1 : 0});
    return dio.post('/api/v3/member/collect/comic',
        data: data, options: await setHeader());
  }

  Future<Response> getHomepage() {
    return dio.get('/api/v3/h5/homeIndex');
  }

  Future<Response> getTagList(
      {bool popular = true,
      int page = 0,
      int limit = 21,
      String? categoryId,
      String? authorId}) {
    return dio.get(
        '/api/v3/comics?free_type=1&limit=$limit&offset=$page${categoryId == null ? '' : '&theme=$categoryId'}${authorId == null ? '' : '&author=$authorId'}&ordering=${popular ? '-popular' : '-datetime_updated'}&_update=true');
  }

  Future<Response> getSubjectList({int page = 0, int limit = 20}) {
    return dio
        .get('/api/v3/topics?type=1&limit=$limit&offset=$page&_update=true');
  }

  Future<Response> getSubjectDetail(String subjectId) {
    return dio.get('/api/v3/topic/$subjectId?limit=&offset=');
  }

  Future<Response> getSubjectDetailContent(String subjectId,
      {int page = 0, limit = 30}) {
    return dio.get(
        '/api/v3/topic/$subjectId/contents?limit=$limit&offset=${page * limit}');
  }

  Future<Response> getCategory() {
    return dio.get(
        '/api/v3/theme/comic/count?free_type=1&limit=500&offset=0&_update=true');
  }

  Future<Response> getChapterComments(String chapterId,
      {int limit = 50, int page = 0}) {
    return dio.get(
        '/api/v3/roasts?chapter_id=$chapterId&limit=$limit&offset=${page * limit}');
  }

  Future<Response> getComments(String comicId,
      {int limit = 20, int page = 0}) async {
    return dio.get(
        '/api/v3/comments?comic_id=$comicId&limit=$limit&offset=${limit * page}',
        options: await setHeader({'Platform': '1'}));
  }

  Future<Response> getHistory({int limit = 12, int page = 0}) async {
    return dio.get('/api/kb/web/browses?limit=$limit&offset=${limit * page}',
        options: await setHeader({'Platform': '1'}));
  }
}
