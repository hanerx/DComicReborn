import 'package:date_format/date_format.dart';
import 'package:dcomic/database/entity/comic_history.dart';
import 'package:dcomic/protobuf/comic.pb.dart';
import 'package:dcomic/providers/models/comic_source_model.dart';
import 'package:dcomic/requests/base_request.dart';
import 'package:dcomic/utils/image_utils.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

class DMZJComicSourceModel extends BaseComicSourceModel {
  @override
  ComicSourceEntity get type =>
      ComicSourceEntity("大妈之家", "dmzj", hasHomepage: true);

  @override
  Future<BaseComicDetailModel?> getComicDetail(String comicId) {
    // TODO: implement getComicDetail
    throw UnimplementedError();
  }

  @override
  Future<List<ComicHistoryEntity>> getComicHistory() {
    // TODO: implement getComicHistory
    throw UnimplementedError();
  }

  @override
  Future<List<BaseComicDetailModel>> searchComicDetail(String keyword,
      {int page = 0}) {
    // TODO: implement searchComicDetail
    throw UnimplementedError();
  }

  @override
  BaseComicHomepageModel? get homepage => DMZJComicHomepageModel();
}

class DMZJComicHomepageModel extends BaseComicHomepageModel {
  static List<int> blackList = [46];

  @override
  Future<List<HomepageCardEntity>> getHomepageCard() async {
    List<HomepageCardEntity> data = [];
    Response response =
        await RequestHandlers.dmzjv3requestHandler.getMainPageRecommendNew();
    try {
      if ((response.statusCode == 200 || response.statusCode == 304)) {
        for (var rawData in response.data) {
          if (blackList.contains(rawData['category_id'])) {
            continue;
          }
          List<GridItemEntity> children = [];
          for (var rawItem in rawData['data']) {
            children.add(GridItemEntity(
                rawItem['title'],
                rawItem['sub_title'],
                ImageEntity(ImageType.network, rawItem['cover'],
                    imageHeaders: {"referer": "https://i.dmzj.com"}),
                (context) {}));
          }
          data.add(HomepageCardEntity(
              rawData['title'], null, (context) {}, children));
        }
      }
    } catch (e, s) {
      logger.e('$e', e, s);
    }
    return data;
  }

  @override
  Future<List<CarouselEntity>> getHomepageCarousel() async {
    List<CarouselEntity> data = [];
    Response response =
        await RequestHandlers.dmzjv3requestHandler.getMainPageRecommendNew();
    try {
      if ((response.statusCode == 200 || response.statusCode == 304)) {
        var rawData = response.data[0];
        for (var rawItem in rawData['data']) {
          data.add(CarouselEntity(
              ImageEntity(ImageType.network, rawItem['cover'],
                  imageHeaders: {"referer": "https://i.dmzj.com"}),
              rawItem['title'],
              (context) {}));
        }
      }
    } catch (e, s) {
      logger.e('$e', e, s);
    }
    return data;
  }

  @override
  Future<List<GridItemEntity>> getCategoryList() async {
    List<GridItemEntity> data = [];
    Response response =
        await RequestHandlers.dmzjv3requestHandler.getCategory();
    try {
      if ((response.statusCode == 200 || response.statusCode == 304)) {
        for (var rawData in response.data['data']) {
          data.add(GridItemEntity(
              rawData['title'],
              null,
              ImageEntity(ImageType.network, rawData['cover'],
                  imageHeaders: {"referer": "https://i.dmzj.com"}),
              (context) {}));
        }
      }
    } catch (e, s) {
      logger.e('$e', e, s);
    }
    return data;
  }

  @override
  Future<List<ListItemEntity>> getRankingList({int page = 0}) async {
    List<ListItemEntity> data = [];
    List<ComicRankListItemResponse> rawData =
        await RequestHandlers.dmzjv4requestHandler.getRankingList(page: page);
    for (var rawListItem in rawData) {
      data.add(ListItemEntity(
          rawListItem.title,
          ImageEntity(ImageType.network, rawListItem.cover,
              imageHeaders: {"referer": "https://i.dmzj.com"}),
          {
            Icons.supervisor_account_rounded: rawListItem.authors,
            Icons.apps: rawListItem.types,
            Icons.history_edu: formatDate(
                DateTime.fromMicrosecondsSinceEpoch(
                    rawListItem.lastUpdatetime.toInt() * 1000000),
                [yyyy, '-', mm, '-', dd])
          },
          (context) {}));
    }
    return data;
  }

  @override
  Future<List<ListItemEntity>> getLatestList({int page = 0}) async{
    List<ListItemEntity> data = [];
    List<ComicUpdateListItemResponse> rawData =
        await RequestHandlers.dmzjv4requestHandler.getUpdateList(page: page);
    for (var rawListItem in rawData) {
      data.add(ListItemEntity(
          rawListItem.title,
          ImageEntity(ImageType.network, rawListItem.cover,
              imageHeaders: {"referer": "https://i.dmzj.com"}),
          {
            Icons.supervisor_account_rounded: rawListItem.authors,
            Icons.apps: rawListItem.types,
            Icons.history_edu: formatDate(
                DateTime.fromMicrosecondsSinceEpoch(
                    rawListItem.lastUpdatetime.toInt() * 1000000),
                [yyyy, '-', mm, '-', dd])
          },
              (context) {}));
    }
    return data;
  }
}
