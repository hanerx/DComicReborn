import 'dart:async';

import 'package:badges/badges.dart';
import 'package:dcomic/database/database_instance.dart';
import 'package:dcomic/generated/l10n.dart';
import 'package:dcomic/providers/comic_reading_progress.dart';
import 'package:dcomic/providers/models/base_model.dart';
import 'package:dcomic/providers/subscribe_badge_state.dart';
import 'package:dcomic/utils/image_utils.dart';
import 'package:dcomic/view/comic_pages/comic_detail_page.dart';
import 'package:dcomic/view/components/settings_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:fluttericon/font_awesome5_icons.dart';
import 'package:date_format/date_format.dart' as date_format;
import 'package:pinyin/pinyin.dart';

class ComicSourceEntity {
  final String sourceName;
  final String sourceId;
  final bool hasHomepage;
  final bool hasAccountSupport;
  final bool hasComment;

  ComicSourceEntity(
    this.sourceName,
    this.sourceId, {
    this.hasHomepage = false,
    this.hasAccountSupport = false,
    this.hasComment = false,
  });

  @override
  String toString() {
    return 'ComicSourceEntity{sourceName: $sourceName, sourceId: $sourceId, hasHomepage: $hasHomepage, hasAccountSupport: $hasAccountSupport, hasComment: $hasComment}';
  }
}

enum ComicHistorySourceType { network, local }

typedef ComicDisplayTextFormatter = String Function(String text);

abstract class BaseComicSourceModel extends BaseModel {
  BaseComicHomepageModel? get homepage => null;

  BaseComicAccountModel? get accountModel => null;

  ComicSourceEntity get type => ComicSourceEntity("初始漫画源", "BaseComicSource");

  /// Formats source-owned text at the display boundary.
  ///
  /// Domain models and persisted values must retain the source response.
  String formatDisplayText(String text) => text;

  Future<BaseComicDetailModel?> getComicDetail(String comicId, String title);

  Future<List<ComicListItemEntity>> searchComicDetail(
    String keyword, {
    int page = 0,
  });

  Future<List<ListItemEntity>> getComicHistory(
    ComicHistorySourceType sourceType, {
    int page = 0,
  }) async {
    if (sourceType == ComicHistorySourceType.local && page == 0) {
      try {
        List<ListItemEntity> data = [];
        var databaseInstance = await DatabaseInstance.instance;
        var comicHistoryEntityList = await databaseInstance.comicHistoryDao
            .getComicHistoryByProvider(type.sourceId);
        for (var entity in comicHistoryEntityList) {
          data.add(
            ListItemEntity(
              entity.title,
              ImageEntity(entity.coverType, entity.cover),
              {
                Icons.history: date_format.formatDate(entity.timestamp!, [
                  date_format.yyyy,
                  '-',
                  date_format.mm,
                  '-',
                  date_format.dd,
                ]),
                Icons.history_edu: entity.lastChapterTitle,
              },
              (context) {
                ComicDetailPage.open(
                  context,
                  title: entity.title,
                  comicId: entity.comicId,
                  comicSourceModel: this,
                );
              },
              titleFormatter: formatDisplayText,
              detailFormatter: formatDisplayText,
              formattedDetailKeys: const [Icons.history_edu],
            ),
          );
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

  /// Resolves [comicId] from [sourceModel] on this source.
  ///
  /// Stored bindings and suppression take precedence. Missing same-source
  /// bindings retain identity; missing cross-source bindings may be discovered
  /// by title and stored atomically.
  Future<String?> resolveComicId(
    String comicId,
    String title,
    BaseComicSourceModel sourceModel,
  ) async {
    final database = await DatabaseInstance.instance;
    final mapping = await database.comicMappingDao.lookupComicId(
      comicId,
      sourceModel.type.sourceId,
      type.sourceId,
    );
    if (mapping != null) return mapping.isEmpty ? null : mapping;
    if (sourceModel.type.sourceId == type.sourceId) return comicId;

    final searchResults = await searchComicDetail(title);
    String? matchedComicId;
    if (searchResults.length == 1 && searchResults.first.comicId.isNotEmpty) {
      matchedComicId = searchResults.first.comicId;
    } else {
      final targetTitle = ChineseHelper.convertToSimplifiedChinese(title);
      for (final item in searchResults) {
        if (item.comicId.isEmpty) continue;
        final sourceTitle = ChineseHelper.convertToSimplifiedChinese(
          item.rawTitle,
        );
        if (sourceTitle == targetTitle) {
          matchedComicId = item.comicId;
          break;
        }
      }
    }
    if (matchedComicId == null) {
      final existing = await database.comicMappingDao.lookupComicId(
        comicId,
        sourceModel.type.sourceId,
        type.sourceId,
      );
      return existing == null || existing.isEmpty ? null : existing;
    }
    final result = await database.comicMappingDao
        .insertAutomaticMappingIfAbsent(
          comicId,
          sourceModel.type.sourceId,
          type.sourceId,
          matchedComicId,
        );
    if (result == matchedComicId) {
      SubscribeBadgeState.changes.value++;
    }
    return result.isEmpty ? null : result;
  }

  Future<void> bindComicIdFromSourceModel(
    String comicId,
    String targetComicId,
    BaseComicSourceModel sourceModel,
  ) async {
    final database = await DatabaseInstance.instance;
    await database.comicMappingDao.bindComic(
      comicId,
      sourceModel.type.sourceId,
      type.sourceId,
      targetComicId,
    );
    SubscribeBadgeState.changes.value++;
  }

  Widget getSourceSettingWidget(BuildContext context) {
    return SettingsTile(
      leading: const Icon(Icons.hourglass_empty),
      title: Text(S.of(context).SourceProviderSettingEmpty),
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

  /// The source title used for persistence and identity matching.
  String get rawTitle => title;

  DateTime get lastUpdate;

  Map<String, List<BaseComicChapterEntityModel>> get chapters;

  String get description;

  String get status;

  String get comicId;

  bool get subscribe => false;

  set subscribe(bool subscribe) {}

  List<CategoryEntity> get authors;

  List<CategoryEntity> get categories;

  /// True only when the source explicitly marks this comic as a strip.
  bool get isLongComic => false;

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
      _latestChapterId = await ComicReadingProgress.resolve(
        sourceId: parent.type.sourceId,
        comicId: comicId,
        local: comicHistoryEntity,
        chapters: () => chapters.values
            .expand((group) => group)
            .map((chapter) => (chapter.chapterId, chapter.rawTitle)),
      );
    } catch (e, s) {
      logger.e('$e', error: e, stackTrace: s);
    }
  }

  Future<bool> _historyWrites = Future.value(true);

  Future<bool> addComicHistory(
    String chapterId,
    String chapterName, {
    int page = 1,
  }) {
    // Chapter entry and page changes may arrive before the first insert ends.
    return _historyWrites = _historyWrites.then(
      (_) => _saveComicHistory(chapterId, chapterName),
    );
  }

  Future<bool> _saveComicHistory(String chapterId, String chapterName) async {
    try {
      var databaseInstance = await DatabaseInstance.instance;
      var comicHistoryEntity = (await databaseInstance.comicHistoryDao
          .getOrCreateConfigByComicId(comicId, parent.type.sourceId));
      comicHistoryEntity.cover = cover.imageUrl;
      comicHistoryEntity.coverType = cover.imageType;
      comicHistoryEntity.title = rawTitle;
      comicHistoryEntity.lastChapterId = chapterId;
      comicHistoryEntity.lastChapterTitle = chapterName;
      comicHistoryEntity.timestamp = DateTime.now();
      await databaseInstance.comicHistoryDao.updateComicHistory(
        comicHistoryEntity,
      );
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

  /// The source chapter title used for persistence and matching.
  String get rawTitle => title;

  String get chapterId;

  DateTime get uploadTime;
}

class DefaultComicChapterEntityModel extends BaseComicChapterEntityModel {
  final String _title;
  final String _chapterId;
  final DateTime _uploadTime;
  final ComicDisplayTextFormatter? _titleFormatter;

  DefaultComicChapterEntityModel(
    this._title,
    this._chapterId,
    this._uploadTime, {
    ComicDisplayTextFormatter? titleFormatter,
  }) : _titleFormatter = titleFormatter;

  @override
  String get chapterId => _chapterId;

  @override
  String get rawTitle => _title;

  @override
  String get title => _titleFormatter?.call(_title) ?? _title;

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
        var cacheResult = await DefaultCacheManager().getFileFromCache(
          page.imageUrl,
        );
        cacheResult ??= await DefaultCacheManager().downloadFile(
          page.imageUrl,
          authHeaders: page.imageHeaders,
        );
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

  static final _newComicBadgePosition = BadgePosition.topEnd(top: 6, end: 6);

  /// Reconcile only the local read state; never fetch or reorder subscriptions.
  Future<bool> refreshSubscribeBadges(Iterable<GridItemEntity> items) async {
    final times = await SubscribeBadgeState.viewingTimes(parent!.type.sourceId);
    var changed = false;
    for (final item in items) {
      if (item is! GridItemEntityWithStatus) continue;
      final viewed = times[item.comicId];
      final isNew = viewed == null || viewed.isBefore(item.lastUpdateTimestamp);
      final hadBadge =
          item.badges?.containsKey(_newComicBadgePosition) ?? false;
      if (isNew == hadBadge) continue;
      if (isNew) {
        (item.badges ??= {})[_newComicBadgePosition] = (context) =>
            S.of(context).NewComicBadge;
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
    await databaseInstance.comicSubscribeStateDao.updateComicSubscribeState(
      comicSubscribeState,
    );
    SubscribeBadgeState.changes.value++;
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

  Future<List<ListItemEntity>> getCategoryDetailList({
    required String categoryId,
    required Map<String, dynamic> categoryFilter,
    int page = 0,
    int categoryType = 0,
  });
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
    return S
        .of(context)
        .TimeOrRankFilterEntityModes(
          TimeOrRankEnum.values[TimeOrRankEnum.values.indexOf(value)].name,
        );
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

  ComicCommentEntity(
    this.avatar,
    this.comment,
    this.commentId,
    this.nickname,
    this.likes,
    this.subComments,
  );
}

class CarouselEntity {
  final ImageEntity cover;
  final String _title;
  final void Function(BuildContext context)? onTap;
  final ComicDisplayTextFormatter? _titleFormatter;

  CarouselEntity(
    this.cover,
    String title,
    this.onTap, {
    ComicDisplayTextFormatter? titleFormatter,
  }) : _title = title,
       _titleFormatter = titleFormatter;

  String get title => _titleFormatter?.call(_title) ?? _title;
}

class HomepageCardEntity {
  final String title;
  final IconData? icon;
  final void Function(BuildContext context)? onTap;
  final List<GridItemEntity> children;
  final double coverAspectRatio;
  final int? crossAxisCount;

  HomepageCardEntity(
    this.title,
    this.icon,
    this.onTap,
    this.children, {
    this.coverAspectRatio = 2 / 3,
    this.crossAxisCount,
  });
}

class GridItemEntity {
  final String? _title;
  final String? _subtitle;
  final ImageEntity cover;
  final void Function(BuildContext context)? onTap;
  final ComicDisplayTextFormatter? _titleFormatter;
  final ComicDisplayTextFormatter? _subtitleFormatter;
  Map<BadgePosition, String Function(BuildContext context)>? badges;

  GridItemEntity(
    String? title,
    String? subtitle,
    this.cover,
    this.onTap, {
    this.badges,
    ComicDisplayTextFormatter? titleFormatter,
    ComicDisplayTextFormatter? subtitleFormatter,
  }) : _title = title,
       _subtitle = subtitle,
       _titleFormatter = titleFormatter,
       _subtitleFormatter = subtitleFormatter;

  String? get rawTitle => _title;

  String? get title =>
      _title == null ? null : _titleFormatter?.call(_title) ?? _title;

  String? get subtitle => _subtitle == null
      ? null
      : _subtitleFormatter?.call(_subtitle) ?? _subtitle;
}

class GridItemEntityWithStatus extends GridItemEntity {
  final String comicId;
  final DateTime lastUpdateTimestamp;

  GridItemEntityWithStatus(
    super.title,
    super.subtitle,
    super.cover,
    super.onTap,
    this.lastUpdateTimestamp,
    this.comicId, {
    super.badges,
    super.titleFormatter,
    super.subtitleFormatter,
  });
}

class ListItemEntity {
  final String _title;
  final ImageEntity cover;
  final Map<IconData, String> _details;
  final void Function(BuildContext context)? onTap;
  final ComicDisplayTextFormatter? _titleFormatter;
  final ComicDisplayTextFormatter? _detailFormatter;
  final List<IconData> _formattedDetailKeys;

  ListItemEntity(
    String title,
    this.cover,
    Map<IconData, String> details,
    this.onTap, {
    ComicDisplayTextFormatter? titleFormatter,
    ComicDisplayTextFormatter? detailFormatter,
    List<IconData> formattedDetailKeys = const [],
  }) : _title = title,
       _details = details,
       _titleFormatter = titleFormatter,
       _detailFormatter = detailFormatter,
       _formattedDetailKeys = formattedDetailKeys;

  String get rawTitle => _title;

  String get title => _titleFormatter?.call(_title) ?? _title;

  Map<IconData, String> get details {
    final formatter = _detailFormatter;
    if (formatter == null || _formattedDetailKeys.isEmpty) return _details;
    return _details.map(
      (key, value) => MapEntry(
        key,
        _formattedDetailKeys.contains(key) ? formatter(value) : value,
      ),
    );
  }
}

class ComicListItemEntity extends ListItemEntity {
  final String comicId;

  ComicListItemEntity(
    super.title,
    super.cover,
    super.details,
    super.onTap,
    this.comicId, {
    super.titleFormatter,
    super.detailFormatter,
    super.formattedDetailKeys,
  });
}
