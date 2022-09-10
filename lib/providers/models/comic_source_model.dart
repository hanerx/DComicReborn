import 'package:dcomic/database/entity/comic_history.dart';
import 'package:dcomic/providers/models/base_model.dart';
import 'package:dcomic/providers/models/comic_source_model.dart';
import 'package:dcomic/utils/image_utils.dart';
import 'package:flutter/material.dart';

class ComicSourceEntity {
  final String sourceName;
  final String sourceId;
  final bool hasHomepage;
  final bool hasAccountSupport;
  final bool hasComment;

  ComicSourceEntity(this.sourceName, this.sourceId,
      {this.hasHomepage = false,
      this.hasAccountSupport = false,
      this.hasComment = false});
}

abstract class BaseComicSourceModel extends BaseModel {
  BaseComicHomepageModel? get homepage => null;

  BaseComicAccountModel? get accountModel => null;

  ComicSourceEntity get type => ComicSourceEntity("初始漫画源", "BaseComicSource");

  Future<BaseComicDetailModel?> getComicDetail(String comicId);

  Future<List<BaseComicDetailModel>> searchComicDetail(String keyword,
      {int page = 0});

  Future<List<ComicHistoryEntity>> getComicHistory();
}

abstract class BaseComicDetailModel extends BaseModel {}

abstract class BaseComicChapterEntityModel extends BaseModel {}

abstract class BaseComicChapterDetailModel extends BaseModel {}

abstract class BaseComicAccountModel extends BaseModel {
  bool get isLogin => false;
}

abstract class BaseComicHomepageModel extends BaseModel {
  /// 获取首页轮播卡片数据
  Future<List<CarouselEntity>> getHomepageCarousel();

  /// 获取首页各个卡片数据
  Future<List<HomepageCardEntity>> getHomepageCard();

  /// 获取漫画分类目录
  Future<List<GridItemEntity>> getCategoryList();

  /// 获取排行榜数据
  Future<List<ListItemEntity>> getRankingList({int page = 0});

  /// 获取更新列表数据
  Future<List<ListItemEntity>> getLatestList({int page = 0});
}

class CarouselEntity {
  final ImageEntity cover;
  final String title;
  final void Function(BuildContext context)? onTap;

  CarouselEntity(this.cover, this.title, this.onTap);
}

class HomepageCardEntity {
  final String title;
  final IconData? icon;
  final void Function(BuildContext context)? onTap;
  final List<GridItemEntity> children;

  HomepageCardEntity(this.title, this.icon, this.onTap, this.children);
}

class GridItemEntity {
  final String? title;
  final String? subtitle;
  final ImageEntity cover;
  final void Function(BuildContext context)? onTap;

  GridItemEntity(this.title, this.subtitle, this.cover, this.onTap);
}

class ListItemEntity {
  final String title;
  final ImageEntity cover;
  final Map<IconData, String> details;
  final void Function(BuildContext context)? onTap;

  ListItemEntity(this.title, this.cover, this.details,this.onTap);
}
