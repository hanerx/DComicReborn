import 'dart:convert';

import 'package:date_format/date_format.dart' as date_format;
import 'package:dcomic/database/database_instance.dart';
import 'package:dcomic/generated/l10n.dart';
import 'package:dcomic/protobuf/comic.pb.dart';
import 'package:dcomic/providers/models/comic_source_model.dart';
import 'package:dcomic/providers/navigator_provider.dart';
import 'package:dcomic/providers/page_controllers/comic_favorite_page_controller.dart';
import 'package:dcomic/requests/base_request.dart';
import 'package:dcomic/utils/image_utils.dart';
import 'package:dcomic/view/category_pages/comic_category_detail_page.dart';
import 'package:dcomic/view/comic_pages/comic_detail_page.dart';
import 'package:dcomic/view/drawer_page/favorite_page.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:fluttericon/font_awesome5_icons.dart';
import 'package:provider/provider.dart';

class DMZJComicSourceModel extends BaseComicSourceModel {
  final DMZJComicAccountModel _accountModel = DMZJComicAccountModel();

  @override
  ComicSourceEntity get type => ComicSourceEntity("大妈之家", "dmzj",
      hasHomepage: true, hasAccountSupport: true, hasComment: true);

  @override
  Future<BaseComicDetailModel?> getComicDetail(
      String comicId, String title) async {
    try {
      ComicDetailInfoResponse? rawData =
          await RequestHandlers.dmzjv4requestHandler.getComicDetail(comicId);
      if (rawData != null) {
        return DMZJV4ComicDetailModel(rawData, this);
      }
    } catch (e, s) {
      logger.e('$e', error: e, stackTrace: s);
      rethrow;
    }
    return null;
  }

  @override
  Future<List<ListItemEntity>> getComicHistory(
      ComicHistorySourceType sourceType,
      {int page = 0}) async {
    if (sourceType == ComicHistorySourceType.local) {
      return super.getComicHistory(sourceType, page: page);
    } else if (sourceType == ComicHistorySourceType.network) {
      if (accountModel == null || accountModel?.uid == null) {
        return [];
      }
      List<ListItemEntity> data = [];
      var response = await RequestHandlers.dmzjInterfaceRequestHandler
          .getHistory(accountModel!.uid!, page);
      try {
        if ((response.statusCode == 200 || response.statusCode == 304)) {
          var responseData = jsonDecode(response.data);
          for (var item in responseData) {
            data.add(ListItemEntity(
                item['comic_name'],
                ImageEntity(ImageType.network, item['cover'],
                    imageHeaders: {"referer": "https://i.dmzj.com"}),
                {
                  Icons.history: date_format.formatDate(
                      DateTime.fromMicrosecondsSinceEpoch(
                          item['viewing_time'] * 1000000),
                      [
                        date_format.yyyy,
                        '-',
                        date_format.mm,
                        '-',
                        date_format.dd
                      ]),
                  Icons.history_edu: item['chapter_name'] ?? '',
                }, (context) {
              Provider.of<NavigatorProvider>(context, listen: false)
                  .getNavigator(context, NavigatorType.defaultNavigator)
                  ?.push(MaterialPageRoute(
                      builder: (context) => ComicDetailPage(
                            title: item['comic_name'],
                            comicId: item['comic_id'].toString(),
                            comicSourceModel: this,
                          ),
                      settings: const RouteSettings(name: 'ComicDetailPage')));
            }));
          }
        }
      } catch (e, s) {
        logger.e('$e', error: e, stackTrace: s);
      }
      return data;
    }
    return [];
  }

  @override
  Future<List<ComicListItemEntity>> searchComicDetail(String keyword,
      {int page = 0}) async {
    List<ComicListItemEntity> data = [];
    var response =
        await RequestHandlers.dmzjv3requestHandler.search(keyword, page);
    try {
      if ((response.statusCode == 200 || response.statusCode == 304)) {
        var responseData = response.data;
        for (var item in responseData) {
          data.add(ComicListItemEntity(
              item['title'],
              ImageEntity(ImageType.network, item['cover'],
                  imageHeaders: {"referer": "https://i.dmzj.com"}),
              {
                Icons.supervisor_account_rounded: item['authors'],
                Icons.apps: item['types'],
                Icons.history_edu: item['last_name']
              }, (context) {
            Provider.of<NavigatorProvider>(context, listen: false)
                .getNavigator(context, NavigatorType.defaultNavigator)
                ?.push(MaterialPageRoute(
                    builder: (context) => ComicDetailPage(
                          title: item['title'],
                          comicId: item['id'].toString(),
                          comicSourceModel: this,
                        ),
                    settings: const RouteSettings(name: 'ComicDetailPage')));
          }, item['id'].toString()));
        }
      }
    } catch (e, s) {
      logger.e('$e', error: e, stackTrace: s);
    }
    return data;
  }

  @override
  Future<void> initModel() async {
    _accountModel.parent ??= this;
    await super.initModel();
  }

  @override
  BaseComicHomepageModel? get homepage => DMZJComicHomepageModel(this);

  @override
  BaseComicAccountModel? get accountModel => _accountModel;
}

class DMZJComicHomepageModel extends BaseComicHomepageModel {
  static List<int> blackList = [46];
  final DMZJComicSourceModel parent;

  DMZJComicHomepageModel(this.parent);

  @override
  Future<List<HomepageCardEntity>> getHomepageCard() async {
    List<HomepageCardEntity> data = [];
    if (parent.accountModel!.isLogin) {
      var subscribeResponse = await RequestHandlers.dmzjv3requestHandler
          .getMainPageSubscribe(parent.accountModel!.uid!);
      try {
        if ((subscribeResponse.statusCode == 200 ||
            subscribeResponse.statusCode == 304)) {
          List<GridItemEntity> children = [];
          for (var rawItem in subscribeResponse.data['data']['data']) {
            children.add(GridItemEntity(
                rawItem['title'],
                rawItem['sub_title'],
                ImageEntity(ImageType.network, rawItem['cover'],
                    imageHeaders: {"referer": "https://i.dmzj.com"}),
                (context) {
              Provider.of<NavigatorProvider>(context, listen: false)
                  .getNavigator(context, NavigatorType.defaultNavigator)
                  ?.push(MaterialPageRoute(
                      builder: (context) => ComicDetailPage(
                            title: rawItem['title'],
                            comicId: rawItem['id'].toString(),
                            comicSourceModel: parent,
                          ),
                      settings: const RouteSettings(name: 'ComicDetailPage')));
            }));
          }
          data.add(HomepageCardEntity(
              subscribeResponse.data['data']['title'], Icons.arrow_forward_ios,
              (context) {
            Provider.of<NavigatorProvider>(context, listen: false)
                .getNavigator(context, NavigatorType.defaultNavigator)
                ?.push(MaterialPageRoute(
                    builder: (context) => const FavoritePage(),
                    settings: const RouteSettings(name: 'FavoritePage')));
          }, children));
        }
      } catch (e, s) {
        logger.e('$e', error: e, stackTrace: s);
      }
    }
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
                (context) {
              if (rawItem['type'] == 1) {
                Provider.of<NavigatorProvider>(context, listen: false)
                    .getNavigator(context, NavigatorType.defaultNavigator)
                    ?.push(MaterialPageRoute(
                        builder: (context) => ComicDetailPage(
                              title: rawItem['title'],
                              comicId: rawItem['obj_id'].toString(),
                              comicSourceModel: parent,
                            ),
                        settings:
                            const RouteSettings(name: 'ComicDetailPage')));
              }
            }));
          }
          data.add(HomepageCardEntity(
              rawData['title'], null, (context) {}, children));
        }
      }
    } catch (e, s) {
      logger.e('$e', error: e, stackTrace: s);
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
              rawItem['title'], (context) {
            if (rawItem['type'] == 1) {
              Provider.of<NavigatorProvider>(context, listen: false)
                  .getNavigator(context, NavigatorType.defaultNavigator)
                  ?.push(MaterialPageRoute(
                      builder: (context) => ComicDetailPage(
                            title: rawItem['title'],
                            comicId: rawItem['obj_id'].toString(),
                            comicSourceModel: parent,
                          ),
                      settings: const RouteSettings(name: 'ComicDetailPage')));
            }
          }));
        }
      }
    } catch (e, s) {
      logger.e('$e', error: e, stackTrace: s);
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
        List result = [];
        if (response.data is List) {
          result = response.data;
        } else {
          result = response.data['data'];
        }
        for (var rawData in result) {
          data.add(GridItemEntity(
              rawData['title'],
              null,
              ImageEntity(ImageType.network, rawData['cover'],
                  imageHeaders: {"referer": "https://i.dmzj.com"}), (context) {
            Provider.of<NavigatorProvider>(context, listen: false)
                .getNavigator(context, NavigatorType.defaultNavigator)
                ?.push(MaterialPageRoute(
                    builder: (context) => ComicCategoryDetailPage(
                          categoryId: rawData['tag_id'].toString(),
                          sourceModel: parent,
                          categoryTitle: rawData['title'],
                        ),
                    settings:
                        const RouteSettings(name: 'ComicCategoryDetailPage')));
          }));
        }
      }
    } catch (e, s) {
      logger.e('$e', error: e, stackTrace: s);
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
            Icons.history_edu: date_format.formatDate(
                DateTime.fromMicrosecondsSinceEpoch(
                    rawListItem.lastUpdatetime.toInt() * 1000000),
                [date_format.yyyy, '-', date_format.mm, '-', date_format.dd])
          }, (context) {
        Provider.of<NavigatorProvider>(context, listen: false)
            .getNavigator(context, NavigatorType.defaultNavigator)
            ?.push(MaterialPageRoute(
                builder: (context) => ComicDetailPage(
                      title: rawListItem.title,
                      comicId: rawListItem.comicId.toString(),
                      comicSourceModel: parent,
                    ),
                settings: const RouteSettings(name: 'ComicDetailPage')));
      }));
    }
    return data;
  }

  @override
  Future<List<ListItemEntity>> getLatestList({int page = 0}) async {
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
            Icons.history_edu: date_format.formatDate(
                DateTime.fromMicrosecondsSinceEpoch(
                    rawListItem.lastUpdatetime.toInt() * 1000000),
                [date_format.yyyy, '-', date_format.mm, '-', date_format.dd])
          }, (context) {
        Provider.of<NavigatorProvider>(context, listen: false)
            .getNavigator(context, NavigatorType.defaultNavigator)
            ?.push(MaterialPageRoute(
                builder: (context) => ComicDetailPage(
                      title: rawListItem.title,
                      comicId: rawListItem.comicId.toString(),
                      comicSourceModel: parent,
                    ),
                settings: const RouteSettings(name: 'ComicDetailPage')));
      }));
    }
    return data;
  }

  @override
  List<FilterEntity> get categoryFilter => [TimeOrRankFilterEntity()];

  @override
  Future<List<ListItemEntity>> getCategoryDetailList(
      {required String categoryId,
      required Map<String, dynamic> categoryFilter,
      int page = 0,
      int categoryType = 0}) async {
    List<ListItemEntity> data = [];
    try {
      Response response = await RequestHandlers.dmzjv3requestHandler
          .getCategoryDetail(int.parse(categoryId),
              page: page,
              type:
                  TimeOrRankEnum.values.indexOf(categoryFilter['TimeOrRank']));
      if ((response.statusCode == 200 || response.statusCode == 304)) {
        for (var rawItem in response.data) {
          data.add(ListItemEntity(
              rawItem['title'],
              ImageEntity(ImageType.network, rawItem['cover'],
                  imageHeaders: {"referer": "https://i.dmzj.com"}),
              {
                Icons.supervisor_account_rounded: rawItem['authors'],
                Icons.apps: rawItem['types'],
                Icons.history_edu: date_format.formatDate(
                    DateTime.fromMicrosecondsSinceEpoch(
                        rawItem['last_updatetime'] * 1000000),
                    [
                      date_format.yyyy,
                      '-',
                      date_format.mm,
                      '-',
                      date_format.dd
                    ])
              }, (context) {
            Provider.of<NavigatorProvider>(context, listen: false)
                .getNavigator(context, NavigatorType.defaultNavigator)
                ?.push(MaterialPageRoute(
                    builder: (context) => ComicDetailPage(
                          title: rawItem['title'],
                          comicId: rawItem['id'].toString(),
                          comicSourceModel: parent,
                        ),
                    settings: const RouteSettings(name: 'ComicDetailPage')));
          }));
        }
      }
    } catch (e, s) {
      logger.e('$e', error: e, stackTrace: s);
      rethrow;
    }
    return data;
  }
}

class DMZJV4ComicDetailModel extends BaseComicDetailModel {
  final ComicDetailInfoResponse rawData;
  @override
  final DMZJComicSourceModel parent;

  bool _isSubscribe = false;

  DMZJV4ComicDetailModel(this.rawData, this.parent);

  @override
  Future<void> init() async {
    super.init();
    _isSubscribe = await parent.accountModel!.getIfSubscribed(comicId);
  }

  @override
  Map<String, List<BaseComicChapterEntityModel>> get chapters {
    Map<String, List<BaseComicChapterEntityModel>> data = {};
    for (var item in rawData.chapters) {
      List<BaseComicChapterEntityModel> list = [];
      for (var chapter in item.data) {
        list.add(DefaultComicChapterEntityModel(
            chapter.chapterTitle,
            chapter.chapterId.toString(),
            DateTime.fromMicrosecondsSinceEpoch(
                chapter.updatetime.toInt() * 1000000)));
      }
      data[item.title] = list;
    }
    return data;
  }

  @override
  String get comicId => rawData.id.toString();

  @override
  String get description => rawData.description;

  @override
  Future<BaseComicChapterDetailModel?> getChapter(String chapterId) async {
    try {
      ComicChapterDetailInfoResponse? rawData = await RequestHandlers
          .dmzjv4requestHandler
          .getComicChapterDetail(comicId, chapterId);
      if (rawData != null) {
        return DMZJV4ComicChapterDetailModel(rawData, this);
      }
    } catch (e, s) {
      logger.e('$e', error: e, stackTrace: s);
      rethrow;
    }
    return null;
  }

  @override
  DateTime get lastUpdate => DateTime.fromMicrosecondsSinceEpoch(
      rawData.lastUpdatetime.toInt() * 1000000);

  @override
  String get status => rawData.status.map((e) => e.tagName).join("/");

  @override
  String get title => rawData.title;

  @override
  bool get subscribe => _isSubscribe;

  @override
  set subscribe(bool subscribe) {
    if (subscribe) {
      parent.accountModel!.subscribeComic(comicId);
    } else {
      parent.accountModel!.unsubscribeComic(comicId);
    }
    _isSubscribe = subscribe;
    notifyListeners();
  }

  @override
  ImageEntity get cover => ImageEntity(ImageType.network, rawData.cover,
      imageHeaders: {"referer": "https://i.dmzj.com"});

  @override
  List<CategoryEntity> get authors => rawData.authors
      .map((e) => CategoryEntity(e.tagName, e.tagId.toString(), (context) {
            Provider.of<NavigatorProvider>(context, listen: false)
                .getNavigator(context, NavigatorType.defaultNavigator)
                ?.push(MaterialPageRoute(
                    builder: (context) => ComicCategoryDetailPage(
                          categoryId: e.tagId.toString(),
                          sourceModel: parent,
                          categoryTitle: e.tagName,
                        ),
                    settings:
                        const RouteSettings(name: 'ComicCategoryDetailPage')));
          }))
      .toList();

  @override
  List<CategoryEntity> get categories => rawData.types
      .map((e) => CategoryEntity(e.tagName, e.tagId.toString(), (context) {
            Provider.of<NavigatorProvider>(context, listen: false)
                .getNavigator(context, NavigatorType.defaultNavigator)
                ?.push(MaterialPageRoute(
                    builder: (context) => ComicCategoryDetailPage(
                          categoryId: e.tagId.toString(),
                          sourceModel: parent,
                          categoryTitle: e.tagName,
                        ),
                    settings:
                        const RouteSettings(name: 'ComicCategoryDetailPage')));
          }))
      .toList();

  @override
  Future<List<ComicCommentEntity>> getComments({int page = 0}) async {
    List<ComicCommentEntity> data = [];
    var response = await RequestHandlers.dmzjCommentRequestHandler
        .getComments(comicId, page);
    try {
      if ((response.statusCode == 200 || response.statusCode == 304)) {
        for (String key in response.data['commentIds']) {
          ComicCommentEntity? parent;
          var commentKeyList = key.split(',');
          for (var commentKey in commentKeyList) {
            var item = response.data['comments'][commentKey];
            var entity = ComicCommentEntity(
                ImageEntity(ImageType.network, item['avatar_url'],
                    imageHeaders: {"referer": "https://i.dmzj.com"}),
                item['content'],
                item['id'].toString(),
                item['nickname'],
                int.parse(item['like_amount'].toString()),
                []);
            if (parent == null) {
              parent = entity;
            } else {
              parent.subComments.add(entity);
            }
          }
          data.add(parent!);
        }
      }
    } catch (e, s) {
      logger.e('$e', error: e, stackTrace: s);
      rethrow;
    }
    return data;
  }
}

class DMZJV4ComicChapterDetailModel extends BaseComicChapterDetailModel {
  final ComicChapterDetailInfoResponse rawData;
  final DMZJV4ComicDetailModel parent;

  DMZJV4ComicChapterDetailModel(this.rawData, this.parent);

  @override
  String get chapterId => rawData.chapterId.toString();

  @override
  List<ImageEntity> get pages => rawData.smallPages
      .map((e) => ImageEntity(ImageType.network, e,
          imageHeaders: {"referer": "https://i.dmzj.com"}))
      .toList();

  @override
  String get title => rawData.title;

  @override
  Future<List<ChapterCommentEntity>> getChapterComments() async {
    List<ChapterCommentEntity> data = [];
    try {
      var response = await RequestHandlers.dmzjv3requestHandler
          .getChapterComments(parent.comicId, chapterId);
      if ((response.statusCode == 200 || response.statusCode == 304)) {
        response.data
            .sort((a, b) => int.parse(b['num'].toString()).compareTo(a['num']));
        for (var item in response.data) {
          data.add(ChapterCommentEntity(
              item['id'].toString(), item['content'], item['num']));
        }
      }
    } catch (e, s) {
      logger.e('$e', error: e, stackTrace: s);
    }
    return data;
  }
}

class DMZJComicAccountModel extends BaseComicAccountModel {
  bool _isLoading = true;
  bool _isLogin = false;
  DMZJComicSourceModel? parent;

  String? _uid;
  String? _username;
  ImageEntity? _avatar;
  String? _nickname;

  DMZJComicAccountModel();

  @override
  ImageEntity? get avatar => _avatar;

  @override
  Widget buildLoginWidget(BuildContext context) {
    GlobalKey<FormState> formKey = GlobalKey<FormState>();
    TextEditingController usernameController = TextEditingController();
    TextEditingController passwordController = TextEditingController();
    return Stack(
      children: [
        Container(
          color: Theme.of(context).colorScheme.primary,
          height: 100,
        ),
        Column(
          children: [
            Card(
                elevation: 0,
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    children: [
                      Center(
                        child: Text(
                          S.of(context).DMZJTitle,
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                      ),
                      Form(
                          key: formKey,
                          child: Column(
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: TextFormField(
                                  controller: usernameController,
                                  decoration: InputDecoration(
                                      isDense: true,
                                      border: const OutlineInputBorder(
                                          gapPadding: 1),
                                      labelText:
                                          S.of(context).DMZJLoginUsername,
                                      prefixIcon:
                                          const Icon(Icons.account_circle),
                                      hintText:
                                          S.of(context).DMZJLoginUsernameHint),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: TextFormField(
                                  controller: passwordController,
                                  obscureText: true,
                                  decoration: InputDecoration(
                                      isDense: true,
                                      border: const OutlineInputBorder(
                                          gapPadding: 1),
                                      labelText:
                                          S.of(context).DMZJLoginPassword,
                                      prefixIcon: const Icon(Icons.lock),
                                      hintText:
                                          S.of(context).DMZJLoginPasswordHint),
                                ),
                              )
                            ],
                          )),
                    ],
                  ),
                )),
            Row(
              children: [
                const Expanded(
                  child: SizedBox(),
                ),
                Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        try {
                          if (formKey.currentState!.validate()) {
                            if (await login(usernameController.text,
                                passwordController.text)) {
                              if (!context.mounted) {
                                return;
                              }
                              Provider.of<NavigatorProvider>(context,
                                      listen: false)
                                  .getNavigator(
                                      context, NavigatorType.defaultNavigator)
                                  ?.pop();
                            }
                          }
                        } catch (e, s) {
                          logger.e(e, error: e, stackTrace: s);
                          if (!context.mounted) {
                            return;
                          }
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content:
                                Text(S.of(context).CommonLoginLoginFailed(e)),
                          ));
                        }
                      },
                      icon: const Icon(FontAwesome5.arrow_right),
                      label: Text(S.of(context).CommonLoginLogin),
                      style: ButtonStyle(
                          shape: WidgetStateProperty.all(
                              const RoundedRectangleBorder(
                                  borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(3),
                            bottomLeft: Radius.circular(3),
                          ))),
                          padding: WidgetStateProperty.all(
                              const EdgeInsets.only(
                                  top: 10, left: 10, bottom: 10))),
                    ))
              ],
            ),
            Row(
              children: [
                const Expanded(
                  child: SizedBox(),
                ),
                Expanded(
                    flex: 1,
                    child: ElevatedButton.icon(
                      onPressed: () {},
                      icon: const Icon(FontAwesome5.qq),
                      label: Text(S.of(context).DMZJLoginQQLogin),
                      style: ButtonStyle(
                          backgroundColor:
                              WidgetStateProperty.all(Colors.cyan),
                          shape: WidgetStateProperty.all(
                              const RoundedRectangleBorder(
                                  borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(3),
                            bottomLeft: Radius.circular(3),
                          ))),
                          padding: WidgetStateProperty.all(
                              const EdgeInsets.only(
                                  top: 10, left: 10, bottom: 10))),
                    ))
              ],
            )
          ],
        )
      ],
    );
  }

  @override
  Future<bool> login(String username, String password) async {
    var response = await RequestHandlers.dmzjUserRequestHandler
        .loginV2(username, password);
    try {
      if ((response.statusCode == 200 || response.statusCode == 304)) {
        response.data = jsonDecode(response.data);
        if (response.data['result'] == 1) {
          var databaseInstance = await DatabaseInstance.instance;
          var databaseIsLogin = (await databaseInstance.modelConfigDao
              .getOrCreateConfigByKey('isLogin', parent!.type.sourceId));
          databaseIsLogin.set(true);
          await databaseInstance.modelConfigDao.updateConfig(databaseIsLogin);
          var databaseUId = (await databaseInstance.modelConfigDao
              .getOrCreateConfigByKey('uid', parent!.type.sourceId));
          databaseUId.set(response.data['data']['uid']);
          await databaseInstance.modelConfigDao.updateConfig(databaseUId);
          await initAccount();
          return true;
        } else {
          throw response.data['msg'];
        }
      }
    } catch (e, s) {
      logger.e(e, error: e, stackTrace: s);
      rethrow;
    }
    return false;
  }

  @override
  Future<bool> logout() async {
    var databaseInstance = await DatabaseInstance.instance;
    var databaseIsLogin = (await databaseInstance.modelConfigDao
        .getOrCreateConfigByKey('isLogin', parent!.type.sourceId));
    databaseIsLogin.set(false);
    await databaseInstance.modelConfigDao.updateConfig(databaseIsLogin);
    var databaseUId = (await databaseInstance.modelConfigDao
        .getOrCreateConfigByKey('uid', parent!.type.sourceId));
    databaseUId.set('');
    await databaseInstance.modelConfigDao.updateConfig(databaseUId);
    _avatar = null;
    _username = null;
    _nickname = null;
    await initAccount();
    return true;
  }

  @override
  Future<void> initAccount() async {
    var databaseInstance = await DatabaseInstance.instance;
    _isLogin = (await databaseInstance.modelConfigDao
            .getOrCreateConfigByKey('isLogin', parent!.type.sourceId))
        .get<bool>();
    _uid = (await databaseInstance.modelConfigDao
            .getOrCreateConfigByKey('uid', parent!.type.sourceId))
        .get<String>();
    if (_isLogin && _uid!.isNotEmpty) {
      var response =
          await RequestHandlers.dmzjv3requestHandler.getUserInfo(_uid!);
      try {
        _nickname = response.data['nickname'];
        _username = (await databaseInstance.modelConfigDao
                .getOrCreateConfigByKey('username', parent!.type.sourceId))
            .get<String>();
        _avatar = ImageEntity(ImageType.network, response.data['cover'],
            imageHeaders: {"referer": "https://i.dmzj.com"});
      } catch (e, s) {
        logger.e(e, error: e, stackTrace: s);
        _isLogin = false;
      }
    } else {
      _isLogin = false;
    }
    _isLoading = false;
  }

  @override
  String? get nickname => _nickname;

  @override
  String? get uid => _uid;

  @override
  String? get username => _username;

  @override
  bool get isLoading => _isLoading;

  @override
  bool get isLogin => _isLogin;

  @override
  Future<bool> getIfSubscribed(String comicId) async {
    if (!isLogin) {
      return false;
    }
    try {
      var response = await RequestHandlers.dmzjv3requestHandler
          .getIfSubscribe(comicId, uid!);
      if ((response.statusCode == 200 || response.statusCode == 304)) {
        return response.data['code'] == 0;
      }
    } catch (e, s) {
      logger.e(e, error: e, stackTrace: s);
    }
    return false;
  }

  @override
  Future<bool> subscribeComic(String comicId) async {
    if (!isLogin) {
      return false;
    }
    try {
      var response = await RequestHandlers.dmzjv3requestHandler
          .addSubscribe(comicId, uid!);
      if ((response.statusCode == 200 || response.statusCode == 304)) {
        return true;
      }
    } catch (e, s) {
      logger.e(e, error: e, stackTrace: s);
    }
    return false;
  }

  @override
  Future<bool> unsubscribeComic(String comicId) async {
    if (!isLogin) {
      return false;
    }
    try {
      var response = await RequestHandlers.dmzjv3requestHandler
          .cancelSubscribe(comicId, uid!);
      if ((response.statusCode == 200 || response.statusCode == 304)) {
        return true;
      }
    } catch (e, s) {
      logger.e(e, error: e, stackTrace: s);
    }
    return false;
  }

  @override
  Future<List<GridItemEntity>> getSubscribeComics({int page = 0}) async {
    List<GridItemEntity> data = [];
    try {
      var response = await RequestHandlers.dmzjv3requestHandler
          .getSubscribe(int.parse(uid!), page);
      if ((response.statusCode == 200 || response.statusCode == 304)) {
        for (var rawData in response.data) {
          data.add(GridItemEntityWithStatus(
              rawData['name'],
              rawData['sub_update'],
              ImageEntity(ImageType.network, rawData['sub_img'],
                  imageHeaders: {"referer": "https://i.dmzj.com"}), (context) {
            Provider.of<NavigatorProvider>(context, listen: false)
                .getNavigator(context, NavigatorType.defaultNavigator)
                ?.push(MaterialPageRoute(
                    builder: (context) => ComicDetailPage(
                          title: rawData['name'],
                          comicId: rawData['id'].toString(),
                          comicSourceModel: parent,
                        ),
                    settings: const RouteSettings(name: 'ComicDetailPage')))
                .then((value) {
                  if(context.mounted){
                    Provider.of<ComicFavoritePageController>(context, listen: false).refresh();
                  }
            });
          }, DateTime.fromMillisecondsSinceEpoch(rawData['sub_uptime'] * 1000),
              rawData['id'].toString()));
        }
      }
    } catch (e, s) {
      logger.e(e, error: e, stackTrace: s);
    }
    return data;
  }
}
