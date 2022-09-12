import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypton/crypton.dart';
import 'package:dcomic/database/database_instance.dart';
import 'package:dcomic/protobuf/comic.pb.dart';
import 'package:dcomic/requests/base_request.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

class DMZJV3RequestHandler extends RequestHandler {
  DMZJV3RequestHandler() : super('https://nnv3api.muwai.com');

  // 获取用户中心数据
  Future<Response> getUserInfo(String uid) async {
    return dio.get('/UCenter/comics/$uid.json');
  }

  // 检查是否订阅
  Future<Response> getIfSubscribe(String comicId, String uid,
      {int type = 0}) async {
    return dio.get('/subscribe/$type/$uid/$comicId');
  }

  // 取消订阅
  Future<Response> cancelSubscribe(String comicId, String uid,
      {int type = 0}) async {
    return dio.get(
        '/subscribe/cancel?obj_ids=$comicId&uid=$uid&type=${type == 0 ? 'mh' : 'xs'}');
  }

  // 添加订阅
  Future<Response> addSubscribe(String comicId, String uid,
      {int type = 0}) async {
    FormData formData = FormData.fromMap(
        {"obj_ids": comicId, "uid": uid, 'type': type == 0 ? 'mh' : 'xs'});
    return dio.post('/subscribe/add', data: formData);
  }

  // 获取订阅
  Future<Response> getSubscribe(int uid, int page, {int type = 0}) {
    return dio.get(
        '/UCenter/subscribe?uid=$uid&sub_type=1&letter=all&page=$page&type=$type');
  }

  // 获取每章吐槽
  Future<Response> getViewpoint(String comicId, String chapterId) {
    return dio.get('/viewPoint/0/$comicId/$chapterId.json');
  }

  // 获取漫画详情
  Future<Response> getComicDetail(String comicId) {
    return dio.get('/comic/comic_$comicId.json');
  }

  // 获取漫画场景
  Future<Response> getComicChapterDetail(String comicId, String chapterId) {
    return dio.get('/chapter/$comicId/$chapterId.json');
  }

  // 搜索
  Future<Response> search(String keyword, int page, {int type = 0}) {
    return dio
        .get('/search/show/$type/${Uri.encodeComponent(keyword)}/$page.json');
  }

  // Unknown
  Future<Response> getSubjectList(String uid, {int page = 0}) {
    return dio.get('/subject_with_level/0/$page.json?uid=$uid');
  }

  // 获取分类目录
  Future<Response> getCategory({int type = 0}) {
    return dio.get('/$type/category.json');
  }

  // 获取主页推荐
  @Deprecated(
      'getMainPageRecommend is deprecated, use getMainPageRecommendNew instead.')
  Future<Response> getMainPageRecommend() {
    return dio.get('/recommend.json');
  }

  // 获取主页推荐(New)
  Future<Response> getMainPageRecommendNew() {
    return dio.get('/recommend_new.json');
  }

  // 获取小说主页推荐
  Future<Response> getNovelMainPageRecommend() {
    return dio.get('/novel/recommend.json');
  }

  // 获取主页订阅
  Future<Response> getMainPageSubscribe(String uid) {
    return dio.get('/recommend/batchUpdate?uid=$uid&category_id=49');
  }

  // 获取subject
  Future<Response> getSubjectDetail(String subjectId) {
    return dio.get('/subject/$subjectId.json');
  }

  // 获取分类详情
  Future<Response> getCategoryDetail(
      int categoryId, int date, int tag, int type, int page) {
    return dio.get('/classify/$categoryId-$date-$tag/$type/$page.json');
  }

  // 获取小说分类列表
  Future<Response> getNovelCategoryDetail(String categoryId,
      {int tag = 0, int type = 0, int page = 0}) {
    return dio.get('/novel/$categoryId/$tag/$type/$page.json');
  }

  // 获取作者详情
  Future<Response> getAuthorDetail(int authorId) {
    return dio.get('/UCenter/author/$authorId.json');
  }

  // 获取最近更新的小说列表
  Future<Response> getNovelLatestUpdateList({int page = 0}) {
    return dio.get('/novel/recentUpdate/$page.json');
  }

  // 获取小说排行
  Future<Response> getNovelRankingList(
      {int type = 0, int tag = 0, int page = 0}) {
    return dio.get('/novel/rank/$type/$tag/$page.json');
  }

  // 获取漫画排行
  @Deprecated("已无法使用")
  Future<Response> getRankingList({int type = 0, int tag = 0, int page = 0}) {
    return dio.get('/rank/$type/$tag/$page.json');
  }

  // 获取小说过滤标签
  Future<Response> getNovelFilterTags() {
    return dio.get('/novel/tag.json');
  }
}

class DMZJV4RequestHandler extends RequestHandler {
  DMZJV4RequestHandler() : super('https://nnv4api.muwai.com');

  static get privateKey =>
      "MIICeAIBADANBgkqhkiG9w0BAQEFAASCAmIwggJeAgEAAoGBAK8nNR1lTnIfIes6oRWJNj3mB6OssDGx0uGMpgpbVCpf6+VwnuI2stmhZNoQcM417Iz7WqlPzbUmu9R4dEKmLGEEqOhOdVaeh9Xk2IPPjqIu5TbkLZRxkY3dJM1htbz57d/roesJLkZXqssfG5EJauNc+RcABTfLb4IiFjSMlTsnAgMBAAECgYEAiz/pi2hKOJKlvcTL4jpHJGjn8+lL3wZX+LeAHkXDoTjHa47g0knYYQteCbv+YwMeAGupBWiLy5RyyhXFoGNKbbnvftMYK56hH+iqxjtDLnjSDKWnhcB7089sNKaEM9Ilil6uxWMrMMBH9v2PLdYsqMBHqPutKu/SigeGPeiB7VECQQDizVlNv67go99QAIv2n/ga4e0wLizVuaNBXE88AdOnaZ0LOTeniVEqvPtgUk63zbjl0P/pzQzyjitwe6HoCAIpAkEAxbOtnCm1uKEp5HsNaXEJTwE7WQf7PrLD4+BpGtNKkgja6f6F4ld4QZ2TQ6qvsCizSGJrjOpNdjVGJ7bgYMcczwJBALvJWPLmDi7ToFfGTB0EsNHZVKE66kZ/8Stx+ezueke4S556XplqOflQBjbnj2PigwBN/0afT+QZUOBOjWzoDJkCQClzo+oDQMvGVs9GEajS/32mJ3hiWQZrWvEzgzYRqSf3XVcEe7PaXSd8z3y3lACeeACsShqQoc8wGlaHXIJOHTcCQQCZw5127ZGs8ZDTSrogrH73Kw/HvX55wGAeirKYcv28eauveCG7iyFR0PFB/P/EDZnyb+ifvyEFlucPUI0+Y87F";

  static Uint8List decrypt(String text) {
    try {
      RSAKeypair rsaKeypair = RSAKeypair(RSAPrivateKey.fromString(privateKey));
      // print(rsaKeypair.privateKey.toPEM());
      var decrypted = rsaKeypair.privateKey.decryptData(base64.decode(text));
      return decrypted;
    } catch (e) {
      throw TypeError();
    }
  }

  Future<Map<String, dynamic>> getParam({bool login = false}) async {
    var data = {
      "channel": Platform.operatingSystem,
      "version": "3.0.0",
      "timestamp":
          (DateTime.now().millisecondsSinceEpoch / 1000).toStringAsFixed(0),
    };
    if (login) {
      var databaseInstance = await DatabaseInstance.instance;
      String uid = (await databaseInstance.modelConfigDao
              .getOrCreateConfigByKey('uid', 'dmzj'))
          .get<String>();
      if (uid.isNotEmpty) {
        data['uid'] = uid;
      }
    }
    return data;
  }

  // 获取漫画排行
  Future<List<ComicRankListItemResponse>> getRankingList(
      {int tagId = 0, int byTime = 0, int rankType = 0, int page = 0}) async {
    Map<String, dynamic> map = {
      'tag_id': tagId,
      'by_time': byTime,
      'rank_type': rankType,
      'page': page + 1
    };
    map.addAll(await getParam(login: true));
    var response = await dio.get('/comic/rank/list', queryParameters: map);
    if (response.statusCode == 200) {
      var data = ComicRankListResponse.fromBuffer(decrypt(response.data));
      if (data.errno != 0) {
        throw data.errmsg;
      }
      return data.data;
    }
    return [];
  }

  // 获取更新列表
  Future<List<ComicUpdateListItemResponse>> getUpdateList(
      {String type = '0', int page = 0}) async {
    var response = await dio.get('/comic/update/list/$type/$page',
        queryParameters: await getParam(login: true));
    if (response.statusCode == 200) {
      var data = ComicUpdateListResponse.fromBuffer(decrypt(response.data));
      if (data.errno != 0) {
        throw data.errmsg;
      }
      return data.data;
    }
    return [];
  }

  Future<ComicDetailInfoResponse?> getComicDetail(String comicId) async {
    var response = await dio.get('/comic/detail/$comicId',
        queryParameters: await getParam(login: true));
    if (response.statusCode == 200) {
      var data = ComicDetailResponse.fromBuffer(decrypt(response.data));
      if (data.errno != 0) {
        throw ErrorDescription(data.errmsg);
      }
      if (data.data.chapters.isEmpty) {
        throw ErrorDescription('解析错误');
      }
      return data.data;
    }
    return null;
  }
}

class DMZJUserRequestHandler extends RequestHandler{
  DMZJUserRequestHandler() : super('https://user.muwai.com');
  
  Future<Response> loginV2(String username,String password)async {
    return dio.post('/loginV2/m_confirm',data: FormData.fromMap({"passwd": password, "nickname": username}));
  }
}