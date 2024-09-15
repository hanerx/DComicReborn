

import 'package:dcomic/providers/models/comic_source_model.dart';
import 'package:dcomic/requests/base_request.dart';
import 'package:dcomic/utils/image_utils.dart';
import 'package:flutter/material.dart';

class ZaiManHuaSourceModel extends BaseComicSourceModel {
  @override
  ComicSourceEntity get type => ComicSourceEntity("再漫画", "zaimanhua",
      hasHomepage: false, hasAccountSupport: false, hasComment: false);

  @override
  Future<BaseComicDetailModel?> getComicDetail(
      String comicId, String title) async {
    var response =
        await RequestHandlers.zaiManHuaRequestHandler.getComicDetail(comicId);
    try {
      if ((response.statusCode == 200 || response.statusCode == 304)) {
        return ZaiManHuaComicDetailModel(response.data['data'], comicId, this);
      }
    } catch (e, s) {
      logger.e('$e', error: e, stackTrace: s);
    }
    return null;
  }

  @override
  Future<List<ComicListItemEntity>> searchComicDetail(String keyword,
      {int page = 0}) async {
    List<ComicListItemEntity> data = [];
    var response = await RequestHandlers.zaiManHuaRequestHandler
        .search(keyword, page: page);
    try {
      if ((response.statusCode == 200 || response.statusCode == 304)) {
        var searchList = response.data['data']['list'];
        for (var item in searchList) {
          data.add(ComicListItemEntity(
              item['title'],
              ImageEntity(ImageType.network, item['cover']),
              {
                Icons.supervisor_account_rounded: item['authors'],
                Icons.apps: item['types'],
                Icons.history_edu: item['last_name']
              },
              (context) {},
              item['comic_py']));
        }
      }
    } catch (e, s) {
      logger.e('$e', error: e, stackTrace: s);
    }
    return data;
  }
}

class ZaiManHuaComicDetailModel extends BaseComicDetailModel {
  final Map rawData;
  final String comicPinYin;
  final ZaiManHuaSourceModel sourceModel;

  ZaiManHuaComicDetailModel(this.rawData, this.comicPinYin, this.sourceModel);

  @override
  List<CategoryEntity> get authors => [
        CategoryEntity(rawData['comicInfo']['authorInfo']['authorName'],
            rawData['comicInfo']['authorInfo']['uid'], (context) {})
      ];

  @override
  List<CategoryEntity> get categories => [
    CategoryEntity(rawData['comicInfo']['types'], '', (context) { })
  ];

  @override
  Map<String, List<BaseComicChapterEntityModel>> get chapters {
    Map<String, List<BaseComicChapterEntityModel>> result = {};
    for (var item in rawData['chapterList']) {
      result[item['title']] = item['data']
          .map<BaseComicChapterEntityModel>((e) =>
          DefaultComicChapterEntityModel(
              e['chapter_title'], e['chapter_id'], DateTime.fromMillisecondsSinceEpoch(e['updatetime'])))
          .toList()
          .reversed
          .toList();
    }
    return result;
  }

  @override
  String get comicId => comicPinYin;

  @override
  ImageEntity get cover => ImageEntity(ImageType.network, rawData['cover']);

  @override
  String get description => rawData['description'];

  @override
  Future<BaseComicChapterDetailModel?> getChapter(String chapterId) async{
    try {
      var response = await RequestHandlers.zaiManHuaRequestHandler
          .getComicChapterDetail(numberComicId, chapterId);
      if ((response.statusCode == 200 || response.statusCode == 304)) {
        var rawData = response.data['data']['chapterInfo'];
        return ZaiManHuaComicChapterDetailModel(rawData);
      }
    } catch (e, s) {
      logger.e('$e', error: e, stackTrace: s);
      rethrow;
    }
    return null;
  }

  @override
  Future<List<ComicCommentEntity>> getComments({int page = 0}) {
    // TODO: implement getComments
    throw UnimplementedError();
  }

  @override
  DateTime get lastUpdate => DateTime.fromMillisecondsSinceEpoch(rawData['lastUpdateTime']);

  @override
  BaseComicSourceModel get parent => sourceModel;

  @override
  String get status => rawData['status'];

  @override
  String get title => rawData['title'];

  int get numberComicId => rawData['id'];
}

class ZaiManHuaComicChapterDetailModel extends BaseComicChapterDetailModel{
  final Map rawData;

  ZaiManHuaComicChapterDetailModel(this.rawData);


  @override
  String get chapterId => rawData['chapter_id'].toString();

  @override
  Future<List<ChapterCommentEntity>> getChapterComments() {
    // TODO: implement getChapterComments
    throw UnimplementedError();
  }

  @override
  List<ImageEntity> get pages => rawData['page_url_hd'].map<ImageEntity>((e)=>ImageEntity(ImageType.network, e)).toList();

  @override
  String get title => rawData['title'];
}