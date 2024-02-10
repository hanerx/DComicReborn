import 'dart:convert';
import 'dart:math';

import 'package:dcomic/database/database_instance.dart';
import 'package:dcomic/requests/base_request.dart';
import 'package:dio/dio.dart';

class CopyMangaRequestHandler extends RequestHandler{
  CopyMangaRequestHandler() : super('https://api.copymanga.site/',useCookie:false);

  Future<Options> setHeader([Map<String, dynamic>? headers]) async {
    headers ??= {};
    if ((await (await DatabaseInstance.instance).modelConfigDao.getConfigByKeyAndModel('isLogin', 'copymanga'))?.get<bool>()) {
      String token =
          (await (await DatabaseInstance.instance).modelConfigDao.getConfigByKeyAndModel('token', 'copymanga'))?.value ?? '';
      headers['authorization'] = 'Token $token';
    }
    headers['region']=(await (await DatabaseInstance.instance).modelConfigDao.getConfigByKeyAndModel('login', 'copymanga'))?.value ?? '0';
    headers['Platform'] = '1';
    return Options(headers: headers);
  }

  Future<Response> getComicDetail(String comicId) {
    return dio.get('/api/v3/comic2/$comicId?platform=1');
  }

  Future<Response> getChapters(String comicId, String groupName,
      {int limit = 100, int page = 0}) async{
    return dio.get(
        '/api/v3/comic/$comicId/group/$groupName/chapters?limit=$limit&offset=$page', options: await setHeader());
  }

  Future<Response> getComic(String comicId, String chapterId) async {
    return dio.get(
        '/api/v3/comic/$comicId/chapter/$chapterId?platform=1&_update=true',
        options: await setHeader({
          'User-Agent':
          'Mozilla/5.0 (Windows NT 6.1; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/43.0.2357.134 Safari/537.36'
        }));
  }

  Future<Response> search(String keyword, {int page = 0}) {
    return dio.get(
        '/api/v3/search/comic?platform=1&q=$keyword&limit=20&offset=$page&q_type=&_update=true');
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
        '/api/v3/member/collect/comics?free_type=1&limit=$limit&offset=${page * limit}&_update=true&ordering=-datetime_modifier',
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
        'https://api.copymanga.com/api/v3/topic/$subjectId/contents?limit=$limit&offset=${page * limit}');
  }

  Future<Response> getCategory() {
    return dio.get('/api/v3/h5/filterIndex/comic/tags?type=1');
  }
}