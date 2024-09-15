import 'package:dcomic/requests/base_request.dart';
import 'package:dio/dio.dart';

class ZaiManHuaRequestHandler extends RequestHandler{
  ZaiManHuaRequestHandler():super("https://manhua.zaimanhua.com");

  Future<Response> getComicDetail(String comicPinYin) {
    return dio.get('/api/v1/comic1/comic/detail?channel=%20pc&app_name=zmh&version=1.0.0&timestamp=${DateTime.timestamp()}&uid=113119197&comic_py=$comicPinYin');
  }

  Future<Response> getComicChapterDetail(int comicId, String chapterId){
    return dio.get('/api/v1/comic1/chapter/detail?channel=pc&app_name=zmh&version=1.0.0&timestamp=1725890784556&comic_id=$comicId&chapter_id=$chapterId');
  }

  Future<Response> search(String keyword, {int page=0, int limit=20}){
    return dio.get('/app/v1/search/index?keyword=$keyword&source=0&page=${page+1}&size=$limit');
  }
}