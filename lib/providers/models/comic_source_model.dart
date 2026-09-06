import 'dart:async';

import 'package:badges/badges.dart';
import 'package:dcomic/database/database_instance.dart';
import 'package:dcomic/generated/l10n.dart';
import 'package:dcomic/providers/models/base_model.dart';
import 'package:dcomic/providers/navigator_provider.dart';
import 'package:dcomic/utils/image_utils.dart';
import 'package:dcomic/view/comic_pages/comic_detail_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:fluttericon/font_awesome5_icons.dart';
import 'package:date_format/date_format.dart' as date_format;
import 'package:pinyin/pinyin.dart';
import 'package:provider/provider.dart';

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

  @override
  String toString() {
    return 'ComicSourceEntity{sourceName: $sourceName, sourceId: $sourceId, hasHomepage: $hasHomepage, hasAccountSupport: $hasAccountSupport, hasComment: $hasComment}';
  }
}

enum ComicHistorySourceType { network, local }

abstract class BaseComicSourceModel extends BaseModel {
  BaseComicHomepageModel? get homepage => null;

  BaseComicAccountModel? get accountModel => null;

  ComicSourceEntity get type => ComicSourceEntity("初始漫画源", "BaseComicSource");

  Future<BaseComicDetailModel?> getComicDetail(String comicId, String title);

  Future<List<ComicListItemEntity>> searchComicDetail(String keyword,
      {int page = 0});

  Future<List<ListItemEntity>> getComicHistory(
      ComicHistorySourceType sourceType,
      {int page = 0}) async {
    if (sourceType == ComicHistorySourceType.local && page == 0) {
      try {
        List<ListItemEntity> data = [];
        var databaseInstance = await DatabaseInstance.instance;
        var comicHistoryEntityList = await databaseInstance.comicHistoryDao
            .getComicHistoryByProvider(type.sourceId);
        for (var entity in comicHistoryEntityList) {
          data.add(ListItemEntity(
              entity.title, ImageEntity(entity.coverType, entity.cover), {
            Icons.history: date_format.formatDate(entity.timestamp!,
                [date_format.yyyy, '-', date_format.mm, '-', date_format.dd]),
            Icons.history_edu: entity.lastChapterTitle
          }, (context) {
            Provider.of<NavigatorProvider>(context, listen: false)
                .getNavigator(context, NavigatorType.defaultNavigator)
                ?.push(MaterialPageRoute(
                    builder: (context) => ComicDetailPage(
                          title: entity.title,
                          comicId: entity.comicId,
                          comicSourceModel: this,
                        ),
                    settings: const RouteSettings(name: 'ComicDetailPage')));
          }));
        }
        return data;
      } catch (e, s) {
        logger.e('$e', error: e, stackTrace: s);
      }
    }
    return [];
  }

  Future<void> initModel() async {
    if (accountModel != null) {
      await accountModel!.initAccount();
    }
  }

  /// 解析 origin 侧书目 ID（[comicId] 来自 [sourceModel]）在当前源上的绑定结果：
  /// - 已存在的映射（含同源显式覆盖）优先，空 [ComicMappingEntity.resultComicId]
  ///   表示用户显式解绑，直接返回 null，不再触发自动搜索；
  /// - 同源且无映射时直接返回原始 ID；
  /// - 跨源且无映射时按标题自动匹配（唯一结果或简体中文标题相等），
  ///   仅在匹配成功后才以事务方式写入（不覆盖显式绑定/解绑）。
  Future<String?> resolveComicId(
      String comicId, String title, BaseComicSourceModel sourceModel) async {
    var databaseInstance = await DatabaseInstance.instance;
    var comicMappingEntity = await databaseInstance.comicMappingDao
        .getComicMappingByComicId(
            comicId, sourceModel.type.sourceId, type.sourceId);
    if (comicMappingEntity != null) {
      if (comicMappingEntity.resultComicId.isEmpty) {
        return null;
      }
      return comicMappingEntity.resultComicId;
    }
    if (sourceModel.type.sourceId == type.sourceId) {
      return comicId;
    }
    var searchResultList = await searchComicDetail(title);
    String? matchedComicId;
    if (searchResultList.length == 1) {
      matchedComicId = searchResultList.first.comicId;
    } else {
      var targetTitle = ChineseHelper.convertToSimplifiedChinese(title);
      for (var item in searchResultList) {
        var sourceTitle = ChineseHelper.convertToSimplifiedChinese(item.title);
        if (sourceTitle == targetTitle) {
          matchedComicId = item.comicId;
          break;
        }
      }
    }
    if (matchedComicId == null) {
      // 未匹配成功时不持久化空结果；但搜索期间可能已有显式绑定/解绑
      // 落库，此时按显式结果返回。
      var existing = await databaseInstance.comicMappingDao
          .getComicMappingByComicId(
              comicId, sourceModel.type.sourceId, type.sourceId);
      if (existing != null) {
        return existing.resultComicId.isEmpty ? null : existing.resultComicId;
      }
      return null;
    }
    var entity = await databaseInstance.comicMappingDao
        .insertAutomaticMappingIfAbsent(
            comicId, sourceModel.type.sourceId, type.sourceId, matchedComicId);
    return entity.resultComicId.isEmpty ? null : entity.resultComicId;
  }

  Future<void> bindComicIdFromSourceModel(String comicId, String targetComicId,
      BaseComicSourceModel sourceModel) async {
    var databaseInstance = await DatabaseInstance.instance;
    var comicMappingEntity = await databaseInstance.comicMappingDao
        .getOrCreateConfigByComicId(
            comicId, sourceModel.type.sourceId, type.sourceId);
    comicMappingEntity.resultComicId = targetComicId;
    await databaseInstance.comicMappingDao
        .updateComicMapping(comicMappingEntity);
  }

  Widget getSourceSettingWidget(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.hourglass_empty),
      title: Text(S.of(context).SourceProviderSettingEmpty),
      dense: true,
    );
  }
}

class CategoryEntity {
  final String title;
  final String categoryId;
  final void Function(BuildContext context)? onTap;

  CategoryEntity(this.title, this.categoryId, this.onTap);
}

abstract class BaseComicDetailModel extends BaseModel {
  ImageEntity get cover;

  String get title;

  DateTime get lastUpdate;

  Map<String, List<BaseComicChapterEntityModel>> get chapters;

  String get description;

  String get status;

  String get comicId;

  bool get subscribe => false;

  set subscribe(bool subscribe) {}

  List<CategoryEntity> get authors;

  List<CategoryEntity> get categories;

  BaseComicSourceModel get parent;

  Future<BaseComicChapterDetailModel?> getChapter(String chapterId);

  Future<List<ComicCommentEntity>> getComments({int page = 0});

  Future<void>? _initFuture;

  @override
  Future<void> init() {
    // BaseProvider 的构造函数会虚调用 init()：缓存共享 Future，
    // 让控制器随后的 await 不会重复执行初始化，也能拿到构造期已抛出的错误。
    if (_initFuture == null) {
      var future = doInit();
      // 构造期的调用没有被 await，忽略其异步错误以避免泄漏为未处理异常；
      // 之后 await 同一 Future 的调用方仍会收到该错误。
      future.ignore();
      _initFuture = future;
    }
    return _initFuture!;
  }

  Future<void> doInit() async {
    await loadComicHistory();
  }

  Future<void> loadComicHistory() async {
    try {
      var databaseInstance = await DatabaseInstance.instance;
      var comicHistoryEntity = (await databaseInstance.comicHistoryDao
          .getComicHistoryByComicId(comicId, parent.type.sourceId));
      _latestChapterId = comicHistoryEntity?.lastChapterId;
    } catch (e, s) {
      logger.e('$e', error: e, stackTrace: s);
    }
  }

  Future<bool> _historyWrites = Future.value(true);

  Future<bool> addComicHistory(String chapterId, String chapterName,
      {int page = 1}) {
    // Chapter entry and page changes may arrive before the first insert ends.
    return _historyWrites =
        _historyWrites.then((_) => _saveComicHistory(chapterId, chapterName));
  }

  Future<bool> _saveComicHistory(String chapterId, String chapterName) async {
    try {
      var databaseInstance = await DatabaseInstance.instance;
      var comicHistoryEntity = (await databaseInstance.comicHistoryDao
          .getOrCreateConfigByComicId(comicId, parent.type.sourceId));
      comicHistoryEntity.cover = cover.imageUrl;
      comicHistoryEntity.coverType = cover.imageType;
      comicHistoryEntity.title = title;
      comicHistoryEntity.lastChapterId = chapterId;
      comicHistoryEntity.lastChapterTitle = chapterName;
      comicHistoryEntity.timestamp = DateTime.now();
      await databaseInstance.comicHistoryDao
          .updateComicHistory(comicHistoryEntity);
      return true;
    } catch (e, s) {
      logger.e('$e', error: e, stackTrace: s);
    }
    return false;
  }

  String? _latestChapterId;

  String? get latestChapterId => _latestChapterId;
}

abstract class BaseComicChapterEntityModel extends BaseModel {
  String get title;

  String get chapterId;

  DateTime get uploadTime;
}

class DefaultComicChapterEntityModel extends BaseComicChapterEntityModel {
  final String _title;
  final String _chapterId;
  final DateTime _uploadTime;

  DefaultComicChapterEntityModel(
      this._title, this._chapterId, this._uploadTime);

  @override
  String get chapterId => _chapterId;

  @override
  String get title => _title;

  @override
  DateTime get uploadTime => _uploadTime;
}

abstract class BaseComicChapterDetailModel extends BaseModel {
  String get title;

  List<ImageEntity> get pages;

  String get chapterId;

  Future<List<ChapterCommentEntity>> getChapterComments();

  Future<List<FileInfo>> downloadPages() async {
    List<FileInfo> data = [];
    for (var page in pages) {
      if (page.imageType == ImageType.network) {
        var cacheResult =
            await DefaultCacheManager().getFileFromCache(page.imageUrl);
        cacheResult ??= await DefaultCacheManager()
            .downloadFile(page.imageUrl, authHeaders: page.imageHeaders);
        data.add(cacheResult);
      }
    }
    return data;
  }
}

abstract class BaseComicAccountModel extends BaseModel {
  bool get isLogin => false;

  bool get isLoading => false;

  String? get uid;

  ImageEntity? get avatar;

  String? get nickname;

  String? get username;

  BaseComicSourceModel? get parent;

  Future<void> initAccount();

  Future<bool> login(String username, String password);

  Future<bool> logout();

  Future<bool> loginWithToken(String token) {
    throw UnimplementedError();
  }

  String? get token => null;

  Widget buildLoginWidget(BuildContext context);

  Future<bool> getIfSubscribed(String comicId);

  Future<bool> subscribeComic(String comicId);

  Future<bool> unsubscribeComic(String comicId);

  Future<List<GridItemEntity>> getSubscribeComics({int page = 0});

  Future<List<GridItemEntity>> getSubscribeStateComics({int page = 0}) async {
    List<GridItemEntity> data = await getSubscribeComics(page: page);
    await refreshSubscribeBadges(data);
    return data;
  }

  static final _newComicBadgePosition = BadgePosition.topEnd(top: -5, end: -5);

  /// Reconcile only the local read state; never fetch or reorder subscriptions.
  Future<bool> refreshSubscribeBadges(Iterable<GridItemEntity> items) async {
    final database = await DatabaseInstance.instance;
    var changed = false;
    for (final item in items) {
      if (item is! GridItemEntityWithStatus) continue;
      final state = await database.comicSubscribeStateDao
          .getComicSubscribeStateByComicId(item.comicId, parent!.type.sourceId);
      final isNew = state?.timestamp == null ||
          state!.timestamp!.isBefore(item.lastUpdateTimestamp);
      final hadBadge =
          item.badges?.containsKey(_newComicBadgePosition) ?? false;
      if (isNew == hadBadge) continue;
      if (isNew) {
        (item.badges ??= {})[_newComicBadgePosition] =
            (context) => S.of(context).NewComicBadge;
      } else {
        item.badges?.remove(_newComicBadgePosition);
      }
      changed = true;
    }
    return changed;
  }

  Future<void> addSubscribeState(String comicId) async {
    var databaseInstance = await DatabaseInstance.instance;
    var comicSubscribeState = await databaseInstance.comicSubscribeStateDao
        .getOrCreateConfigByComicId(comicId, parent!.type.sourceId);
    comicSubscribeState.timestamp = DateTime.now();
    await databaseInstance.comicSubscribeStateDao
        .updateComicSubscribeState(comicSubscribeState);
  }
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

  /// category的filter
  List<FilterEntity> get categoryFilter;

  Future<List<ListItemEntity>> getCategoryDetailList(
      {required String categoryId,
      required Map<String, dynamic> categoryFilter,
      int page = 0,
      int categoryType = 0});
}

abstract class FilterEntity {
  String getLocalizedFilterName(BuildContext context);

  IconData get filterIcon;

  String get filterName;

  dynamic get initValue;

  Map<String, dynamic> getLocalizedMappingChoice(BuildContext context);

  String getLocalizedStringByValue(BuildContext context, dynamic value);
}

enum TimeOrRankEnum { ranking, latestUpdate }

class TimeOrRankFilterEntity extends FilterEntity {
  @override
  String get filterName => 'TimeOrRank';

  @override
  String getLocalizedFilterName(BuildContext context) {
    return S.of(context).TimeOrRankFilterEntityName;
  }

  @override
  Map<String, dynamic> getLocalizedMappingChoice(BuildContext context) {
    Map<String, dynamic> data = {};
    for (var item in TimeOrRankEnum.values) {
      data[S.of(context).TimeOrRankFilterEntityModes(item.name)] = item;
    }
    return data;
  }

  @override
  get initValue => TimeOrRankEnum.ranking;

  @override
  String getLocalizedStringByValue(BuildContext context, value) {
    return S.of(context).TimeOrRankFilterEntityModes(
        TimeOrRankEnum.values[TimeOrRankEnum.values.indexOf(value)].name);
  }

  @override
  IconData get filterIcon => FontAwesome5.sort_amount_down;
}

class ChapterCommentEntity {
  final String comment;
  final int likes;
  final String commentId;
  final ImageEntity? avatar;

  ChapterCommentEntity(this.commentId, this.comment, this.likes, {this.avatar});
}

class ComicCommentEntity {
  final ImageEntity avatar;
  final String comment;
  final String commentId;
  final String nickname;
  final int likes;
  List<ComicCommentEntity> subComments = [];

  ComicCommentEntity(this.avatar, this.comment, this.commentId, this.nickname,
      this.likes, this.subComments);
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
  Map<BadgePosition, String Function(BuildContext context)>? badges;

  GridItemEntity(this.title, this.subtitle, this.cover, this.onTap,
      {this.badges});
}

class GridItemEntityWithStatus extends GridItemEntity {
  final String comicId;
  final DateTime lastUpdateTimestamp;

  GridItemEntityWithStatus(super.title, super.subtitle, super.cover,
      super.onTap, this.lastUpdateTimestamp, this.comicId);
}

class ListItemEntity {
  final String title;
  final ImageEntity cover;
  final Map<IconData, String> details;
  final void Function(BuildContext context)? onTap;

  ListItemEntity(this.title, this.cover, this.details, this.onTap);
}

class ComicListItemEntity extends ListItemEntity {
  final String comicId;

  ComicListItemEntity(
      super.title, super.cover, super.details, super.onTap, this.comicId);
}
