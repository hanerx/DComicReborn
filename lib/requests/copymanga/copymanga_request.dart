import 'dart:convert';
import 'dart:math';

import 'package:date_format/date_format.dart' as date_format;
import 'package:dcomic/database/database_instance.dart';
import 'package:dcomic/requests/base_request.dart';
import 'package:dio/dio.dart';


class CopyMangaAPIRequestHandler extends RequestHandler {
  CopyMangaAPIRequestHandler()
      : super('https://api.copy-manga.com/', useCookie: false);

  Future<Response> getNetworkStatus() async {
    return dio.get('/api/v3/system/network2?platform=3',
        options: Options(headers: {
          'source': 'copyApp',
          'webp': '1',
          'dt': date_format.formatDate(DateTime.now(),
              [date_format.yyyy, '.', date_format.mm, '.', date_format.dd]),
          'platform': '3',
          'referer': 'com.copymanga.app-2.3.0',
          'version': '2.3.0',
          'region': '1',
          'umstring': 'b4c89ca4104ea9a97750314d791520ac'
        }));
  }
}

class CopyMangaRequestHandler extends RequestHandler {
  String dynamicBaseUrl = 'https://api.mangacopy.com/';

  CopyMangaRequestHandler()
      : super('https://api.mangacopy.com/', useCookie: false){
    CopyMangaAPIRequestHandler().getNetworkStatus().then((response){
      try {
        if ((response.statusCode == 200 || response.statusCode == 304) &&
            response.data['code'] == 200) {
          dynamicBaseUrl = 'https://${response.data['results']['api'][0][0]}';
          dio.options.baseUrl = dynamicBaseUrl;
        }
      } catch (e, s) {
        logger.e('$e', error: e, stackTrace: s);
      }
    });
  }

  Future<Options> setHeader({Map<String, dynamic>? headers, bool login=true}) async {
    headers ??= {};
    var databaseInstance = await DatabaseInstance.instance;
    var isLoginEntity = await databaseInstance.modelConfigDao
        .getConfigByKeyAndModel('isLogin', 'copymanga');
    if (isLoginEntity != null && isLoginEntity.get<bool>() && login) {
      String token = (await (await DatabaseInstance.instance)
                  .modelConfigDao
                  .getConfigByKeyAndModel('token', 'copymanga'))
              ?.value ??
          '';
      headers['authorization'] = 'Token $token';
    }else{
      headers['authorization'] = 'Token';
    }
    headers['user-agent'] = 'COPY/2.3.6';
    headers['source'] = 'copyApp';
    headers['deviceinfo'] = 'SM-S9280-e3q';
    headers['webp'] = '1';
    headers['dt'] = date_format.formatDate(DateTime.now(),
        [date_format.yyyy, '.', date_format.mm, '.', date_format.dd]);
    headers['platform'] = '3';
    headers['referer'] = 'com.copymanga.app-2.3.6';
    headers['accept'] = 'application/json';
    headers['version'] = '2.3.6';
    headers['region'] = '1';
    headers['device'] = 'V417IR';
    headers['umstring'] = 'b4c89ca4104ea9a97750314d791520ac';
    headers['host'] = Uri.parse(dynamicBaseUrl).host;
    return Options(headers: headers);
  }

  Future<Response> getComicDetail(String comicId) async{
    var response = await dio.get('/api/v3/comic2/$comicId?in_mainland=true&platform=3',
        options: await setHeader());
    if (response.statusCode == 210){
      return await dio.get('/api/v3/comic2/$comicId?in_mainland=true&platform=3',
          options: await setHeader(login: false));
    }
    return response;
  }

  Future<Response> getChapters(String comicId, String groupName,
      {int limit = 100, int page = 0}) async {
    return dio.get(
        '/api/v3/comic/$comicId/group/$groupName/chapters?limit=$limit&offset=$page&in_mainland=true&platform=3',
        options: await setHeader());
  }

  Future<Response> getComic(String comicId, String chapterId) async {
    var response = await dio.get(
        '/api/v3/comic/$comicId/chapter2/$chapterId?in_mainland=true&platform=3',
        options: await setHeader());
    if (response.statusCode == 210){
      return await dio.get(
          '/api/v3/comic/$comicId/chapter2/$chapterId?in_mainland=true&platform=3',
          options: await setHeader(login: false));
    }
    return response;
  }

  Future<Response> search(String keyword,
      {int page = 0, int limit = 18}) async {
    return dio.get(
        '/api/v3/search/comic?limit=$limit&offset=${page * limit}&q_type=&q=$keyword&platform=3',
        options: await setHeader());
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
    return dio.post('/api/v3/login', data: data, options: await setHeader());
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
        '/api/v3/comics?free_type=1&theme=$theme&limit=$limit&offset=${page * limit}&_update=true&ordering=$order',
        options: await setHeader());
  }

  Future<Response> getAuthorDetailList(
      {required String author,
      int page = 0,
      int limit = 21,
      String order = '-datetime_modifier'}) async {
    return dio.get(
        '/api/v3/comics?free_type=1&author=$author&limit=$limit&offset=${page * limit}&ordering=$order',
        options: await setHeader());
  }

  Future<Response> getRankList(
      {String dateType = 'day', int limit = 21, int page = 0}) async{
    return dio.get(
        '/api/v3/ranks?type=1&date_type=$dateType&limit=$limit&offset=${limit * page}',
        options: await setHeader());
  }

  Future<Response> getLatestList({int limit = 21, int page = 0}) async{
    return dio.get('/api/v3/update/newest?limit=$limit&offset=${limit * page}',
        options: await setHeader());
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

  Future<Response> getHomepage() async{
    return dio.get('/api/v3/h5/homeIndex', options: await setHeader());
  }

  Future<Response> getTagList(
      {bool popular = true,
      int page = 0,
      int limit = 21,
      String? categoryId,
      String? authorId}) async{
    return dio.get(
        '/api/v3/comics?free_type=1&limit=$limit&offset=$page${categoryId == null ? '' : '&theme=$categoryId'}${authorId == null ? '' : '&author=$authorId'}&ordering=${popular ? '-popular' : '-datetime_updated'}&_update=true',
        options: await setHeader());
  }

  Future<Response> getSubjectList({int page = 0, int limit = 20}) async{
    return dio
        .get('/api/v3/topics?type=1&limit=$limit&offset=$page&_update=true', options: await setHeader());
  }

  Future<Response> getSubjectDetail(String subjectId) async{
    return dio.get('/api/v3/topic/$subjectId?limit=&offset=', options: await setHeader());
  }

  Future<Response> getSubjectDetailContent(String subjectId,
      {int page = 0, limit = 30}) async{
    return dio.get(
        '/api/v3/topic/$subjectId/contents?limit=$limit&offset=${page * limit}', options: await setHeader());
  }

  Future<Response> getCategory() async{
    return dio.get(
        '/api/v3/theme/comic/count?free_type=1&limit=500&offset=0&_update=true', options: await setHeader());
  }

  Future<Response> getChapterComments(String chapterId,
      {int limit = 50, int page = 0}) async{
    return dio.get(
        '/api/v3/roasts?chapter_id=$chapterId&limit=$limit&offset=${page * limit}',
        options: await setHeader());
  }

  Future<Response> getComments(String comicId,
      {int limit = 20, int page = 0}) async {
    return dio.get(
        '/api/v3/comments?comic_id=$comicId&limit=$limit&offset=${limit * page}',
        options: await setHeader());
  }

  Future<Response> getHistory({int limit = 12, int page = 0}) async {
    return dio.get('/api/v3/member/browse/comics?limit=$limit&offset=${limit * page}&platform=3',
        options: await setHeader());
  }
}
