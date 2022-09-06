import 'package:dcomic/requests/base_request.dart';
import 'package:dio/dio.dart';

class DMZJV3RequestHandler extends RequestHandler {
  DMZJV3RequestHandler() : super('https://nnv3api.muwai.com');

  // 获取用户中心数据
  Future<Response> getUserInfo(String uid) async {
    return dio.get('/UCenter/comics/$uid.json');
  }

  // 检查是否订阅
  Future<Response> getIfSubscribe(String comicId, String uid,
      {int type = 0}) async {
    return dio.get('$baseUrl/subscribe/$type/$uid/$comicId');
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
  @Deprecated('getMainPageRecommend is deprecated, use getMainPageRecommendNew instead.')
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
  Future<Response> getNovelRankingList({int type = 0, int tag = 0, int page = 0}) {
    return dio.get('/novel/rank/$type/$tag/$page.json');
  }

  // 获取小说过滤标签
  Future<Response> getNovelFilterTags() {
    return dio.get('/novel/tag.json');
  }
}
