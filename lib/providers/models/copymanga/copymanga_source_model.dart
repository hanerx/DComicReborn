import 'dart:math';

import 'package:dcomic/database/database_instance.dart';
import 'package:dcomic/generated/l10n.dart';
import 'package:dcomic/providers/models/comic_source_model.dart';
import 'package:dcomic/providers/navigator_provider.dart';
import 'package:dcomic/requests/base_request.dart';
import 'package:dcomic/utils/image_utils.dart';
import 'package:dcomic/view/category_pages/comic_category_detail_page.dart';
import 'package:dcomic/view/comic_pages/comic_detail_page.dart';
import 'package:dio/src/response.dart';
import 'package:flutter/material.dart';
import 'package:fluttericon/font_awesome5_icons.dart';
import 'package:provider/provider.dart';

class CopyMangaComicSourceModel extends BaseComicSourceModel {
  final CopyMangaAccountModel _accountModel = CopyMangaAccountModel();

  @override
  ComicSourceEntity get type => ComicSourceEntity("拷贝漫画", "copymanga",
      hasAccountSupport: true, hasHomepage: true, hasComment: true);

  @override
  Future<BaseComicDetailModel?> getComicDetail(
      String comicId, String title) async {
    try {
      var response =
          await RequestHandlers.copyMangaRequestHandler.getComicDetail(comicId);
      if ((response.statusCode == 200 || response.statusCode == 304) &&
          response.data['code'] == 200) {
        var data = response.data['results']['comic'];
        var groups = response.data['results']['groups'];
        var groupsRawData = {};
        for (var item in groups.values) {
          var chapterResponse = await RequestHandlers.copyMangaRequestHandler
              .getChapters(comicId, item['path_word'], limit: item['count']);
          if ((chapterResponse.statusCode == 200 ||
                  chapterResponse.statusCode == 304) &&
              chapterResponse.data['code'] == 200) {
            groupsRawData[item] = chapterResponse.data['results']['list'];
          }
        }
        return CopyMangaComicDetailModel(data, this, groupsRawData);
      }
    } catch (e, s) {
      logger.e('$e', error: e, stackTrace: s);
      rethrow;
    }
    return null;
  }

  @override
  Future<List<ListItemEntity>> getComicHistory(ComicHistorySourceType sourceType, {int page=0}) async {
    if(sourceType == ComicHistorySourceType.local){
      return super.getComicHistory(sourceType, page: page);
    }else if(sourceType == ComicHistorySourceType.network){
      List<ListItemEntity> data = [];
      var response = await RequestHandlers.copyMangaRequestHandler
          .getHistory(page: page);
      if ((response.statusCode == 200 || response.statusCode == 304) &&
          response.data['code'] == 200) {
        var responseData = response.data['results']['list'];
        for (var item in responseData) {
          data.add(ListItemEntity(
              item['comic']['name'], ImageEntity(ImageType.network, item['comic']['cover']), {
            Icons.history: item['comic']['last_chapter_name'],
            Icons.history_edu: item['last_chapter_name']
          }, (context) {
            Provider.of<NavigatorProvider>(context, listen: false)
                .getNavigator(context, NavigatorType.defaultNavigator)
                ?.push(MaterialPageRoute(
                builder: (context) => ComicDetailPage(
                  title: item['comic']['name'],
                  comicId: item['comic']['path_word'],
                  comicSourceModel: this,
                ),
                settings: const RouteSettings(name: 'ComicDetailPage')));
          }));
        }
      }
      return data;
    }
    return [];
  }

  @override
  Future<List<ComicListItemEntity>> searchComicDetail(String keyword,
      {int page = 0}) async {
    List<ComicListItemEntity> data = [];
    var response = await RequestHandlers.copyMangaRequestHandler
        .search(keyword, page: page);
    if ((response.statusCode == 200 || response.statusCode == 304) &&
        response.data['code'] == 200) {
      var responseData = response.data['results']['list'];
      for (var item in responseData) {
        data.add(ComicListItemEntity(
            item['name'], ImageEntity(ImageType.network, item['cover']), {
          Icons.supervisor_account_rounded: item['author'].map((e) => e['name']).toList().join('/'),
          Icons.local_fire_department: item['popular'].toString()
        }, (context) {
          Provider.of<NavigatorProvider>(context, listen: false)
              .getNavigator(context, NavigatorType.defaultNavigator)
              ?.push(MaterialPageRoute(
                  builder: (context) => ComicDetailPage(
                        title: item['name'],
                        comicId: item['path_word'],
                        comicSourceModel: this,
                      ),
                  settings: const RouteSettings(name: 'ComicDetailPage')));
        }, item['path_word']));
      }
    }
    return data;
  }

  @override
  Future<void> init() async {
    _accountModel.parent ??= this;
    return super.init();
  }

  @override
  BaseComicAccountModel? get accountModel => _accountModel;

  @override
  BaseComicHomepageModel? get homepage => CopyMangaComicHomepageModel(this);
}

class CopyMangaComicDetailModel extends BaseComicDetailModel {
  final Map rawData;
  @override
  final CopyMangaComicSourceModel parent;
  final Map groupsRawData;

  bool _isSubscribe = false;

  CopyMangaComicDetailModel(this.rawData, this.parent, this.groupsRawData);

  @override
  Future<void> init() async {
    super.init();
    _isSubscribe = await parent.accountModel!.getIfSubscribed(comicId);
  }

  @override
  List<CategoryEntity> get authors => rawData['author']
      .map<CategoryEntity>((e) =>
          CategoryEntity(e['name'], e['path_word'], (context) {
            Provider.of<NavigatorProvider>(context, listen: false)
                .getNavigator(context, NavigatorType.defaultNavigator)
                ?.push(MaterialPageRoute(
                    builder: (context) => ComicCategoryDetailPage(
                          categoryId: e['path_word'],
                          sourceModel: parent,
                          categoryTitle: e['name'],
                          categoryType: 1,
                        ),
                    settings:
                        const RouteSettings(name: 'ComicCategoryDetailPage')));
          }))
      .toList();

  @override
  List<CategoryEntity> get categories => rawData['theme']
      .map<CategoryEntity>((e) =>
          CategoryEntity(e['name'], e['path_word'], (context) {
            Provider.of<NavigatorProvider>(context, listen: false)
                .getNavigator(context, NavigatorType.defaultNavigator)
                ?.push(MaterialPageRoute(
                    builder: (context) => ComicCategoryDetailPage(
                          categoryId: e['path_word'],
                          sourceModel: parent,
                          categoryTitle: e['name'],
                        ),
                    settings:
                        const RouteSettings(name: 'ComicCategoryDetailPage')));
          }))
      .toList();

  @override
  Map<String, List<BaseComicChapterEntityModel>> get chapters {
    Map<String, List<BaseComicChapterEntityModel>> result = {};
    for (var item in groupsRawData.entries) {
      var key = item.key;
      var value = item.value;
      result[key['name']] = value
          .map<BaseComicChapterEntityModel>((e) =>
              DefaultComicChapterEntityModel(
                  e['name'], e['uuid'], DateTime.parse(e['datetime_created'])))
          .toList()
          .reversed
          .toList();
    }
    return result;
  }

  @override
  String get comicId => rawData['path_word'];

  @override
  ImageEntity get cover => ImageEntity(ImageType.network, rawData['cover']);

  @override
  String get description => rawData['brief'];

  @override
  Future<BaseComicChapterDetailModel?> getChapter(String chapterId) async {
    try {
      var response = await RequestHandlers.copyMangaRequestHandler
          .getComic(comicId, chapterId);
      if ((response.statusCode == 200 || response.statusCode == 304) &&
          response.data['code'] == 200) {
        var rawData = response.data['results']['chapter'];
        return CopyMangaComicChapterDetailModel(rawData);
      }
    } catch (e, s) {
      logger.e('$e', error: e, stackTrace: s);
      rethrow;
    }
    return null;
  }

  @override
  Future<List<ComicCommentEntity>> getComments({int page = 0}) async {
    List<ComicCommentEntity> result = [];
    try {
      var response = await RequestHandlers.copyMangaRequestHandler
          .getComments(rawData['uuid'], page: page);
      if ((response.statusCode == 200 || response.statusCode == 304) &&
          response.data['code'] == 200) {
        for (var item in response.data['results']['list']) {
          result.add(ComicCommentEntity(
              ImageEntity(ImageType.network, item['user_avatar']),
              item['comment'],
              item['id'].toString(),
              item['user_name'],
              item['count'], []));
        }
      }
    } catch (e, s) {
      logger.e('$e', error: e, stackTrace: s);
      rethrow;
    }
    return result;
  }

  @override
  DateTime get lastUpdate => DateTime.parse(rawData['datetime_updated']);

  @override
  String get status => rawData['status']['display'];

  @override
  String get title => rawData['name'];

  @override
  bool get subscribe => _isSubscribe;

  @override
  set subscribe(bool subscribe) {
    if (subscribe) {
      parent.accountModel!.subscribeComic(rawData['uuid']);
    } else {
      parent.accountModel!.unsubscribeComic(rawData['uuid']);
    }
    _isSubscribe = subscribe;
    notifyListeners();
  }
}

class CopyMangaComicChapterDetailModel extends BaseComicChapterDetailModel {
  final Map rawData;

  CopyMangaComicChapterDetailModel(this.rawData);

  @override
  String get chapterId => rawData['uuid'];

  @override
  Future<List<ChapterCommentEntity>> getChapterComments() async {
    List<ChapterCommentEntity> data = [];
    try {
      var response = await RequestHandlers.copyMangaRequestHandler
          .getChapterComments(chapterId);
      if ((response.statusCode == 200 || response.statusCode == 304)) {
        for (var item in response.data['results']['list']) {
          data.add(
              ChapterCommentEntity(item['id'].toString(), item['comment'], 1, avatar: ImageEntity(ImageType.network, item['user_avatar'])));
        }
      }
    } catch (e, s) {
      logger.e('$e', error: e, stackTrace: s);
    }
    return data;
  }

  @override
  List<ImageEntity> get pages => rawData['contents']
      .map<ImageEntity>((e) => ImageEntity(ImageType.network, e['url']))
      .toList();

  @override
  String get title => rawData['name'];
}

class CopyMangaAccountModel extends BaseComicAccountModel {
  bool _isLoading = true;
  bool _isLogin = false;
  CopyMangaComicSourceModel? parent;

  String? _uid;
  String? _username;
  ImageEntity? _avatar;
  String? _nickname;

  @override
  ImageEntity? get avatar => _avatar;

  @override
  Widget buildLoginWidget(BuildContext context) {
    GlobalKey<FormState> formKey = GlobalKey<FormState>();
    TextEditingController usernameController = TextEditingController();
    TextEditingController passwordController = TextEditingController();
    TextEditingController tokenController = TextEditingController();
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
                          S.of(context).CopyMangaTitle,
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
                                      hintText: S
                                          .of(context)
                                          .CopyMangaLoginUsernameHint),
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
                                      hintText: S
                                          .of(context)
                                          .CopyMangaLoginPasswordHint),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: TextFormField(
                                  controller: tokenController,
                                  obscureText: true,
                                  decoration: InputDecoration(
                                      isDense: true,
                                      border: const OutlineInputBorder(
                                          gapPadding: 1),
                                      labelText:
                                      S.of(context).CopyMangaToken,
                                      prefixIcon: const Icon(Icons.token_outlined),
                                      hintText: S
                                          .of(context)
                                          .CopyMangaTokenHint),
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
                              Provider.of<NavigatorProvider>(context,
                                      listen: false)
                                  .getNavigator(
                                      context, NavigatorType.defaultNavigator)
                                  ?.pop();
                            }
                          }
                        } catch (e, s) {
                          logger.e(e, error: e, stackTrace: s);
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content:
                                Text(S.of(context).CommonLoginLoginFailed(e)),
                          ));
                        }
                      },
                      icon: const Icon(FontAwesome5.arrow_right),
                      label: Text(S.of(context).CommonLoginLogin),
                      style: ButtonStyle(
                          shape: MaterialStateProperty.all(
                              const RoundedRectangleBorder(
                                  borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(3),
                            bottomLeft: Radius.circular(3),
                          ))),
                          padding: MaterialStateProperty.all(
                              const EdgeInsets.only(
                                  top: 10, left: 10, bottom: 10))),
                    ))
              ],
            ),
          ],
        )
      ],
    );
  }

  @override
  Future<bool> getIfSubscribed(String comicId) async {
    if (!isLogin) {
      return false;
    }
    try {
      var response =
          await RequestHandlers.copyMangaRequestHandler.getIfSubscribe(comicId);
      if ((response.statusCode == 200 || response.statusCode == 304) &&
          response.data['code'] == 200) {
        return response.data['results']['collect'] != null;
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
      var response = await RequestHandlers.copyMangaRequestHandler
          .getSubscribe(page: page);
      if ((response.statusCode == 200 || response.statusCode == 304)) {
        List list = response.data['results']['list'];
        List comicRawList = list.map<Map>((e) => e['comic']).toList();
        for (var rawData in comicRawList) {
          data.add(GridItemEntity(
              rawData['name'],
              rawData['last_chapter_name'],
              ImageEntity(
                ImageType.network,
                rawData['cover'],
              ), (context) {
            Provider.of<NavigatorProvider>(context, listen: false)
                .getNavigator(context, NavigatorType.defaultNavigator)
                ?.push(MaterialPageRoute(
                    builder: (context) => ComicDetailPage(
                          title: rawData['name'],
                          comicId: rawData['path_word'].toString(),
                          comicSourceModel: parent,
                        ),
                    settings: const RouteSettings(name: 'ComicDetailPage')));
          }));
        }
      }
    } catch (e, s) {
      logger.e(e, error: e, stackTrace: s);
    }
    return data;
  }

  @override
  Future<bool> login(String username, String password) async {
    {
      var response = await RequestHandlers.copyMangaRequestHandler
          .login(username, password);
      if ((response.statusCode == 200 || response.statusCode == 304)) {
        if (response.data['code'] == 200) {
          var data = response.data['results'];
          _isLogin = true;
          var databaseInstance = await DatabaseInstance.instance;
          var databaseIsLogin = (await databaseInstance.modelConfigDao
              .getOrCreateConfigByKey('isLogin', parent!.type.sourceId));
          databaseIsLogin.set(true);
          await databaseInstance.modelConfigDao.updateConfig(databaseIsLogin);
          var databaseUId = (await databaseInstance.modelConfigDao
              .getOrCreateConfigByKey('token', parent!.type.sourceId));
          databaseUId.set(data['token']);
          await databaseInstance.modelConfigDao.updateConfig(databaseUId);
          await init();
          notifyListeners();
          return true;
        } else if (response.data['code'] == 210) {
          throw response.data['results'];
        }
      } else if (response.statusCode == 210) {
        throw response.data['results'];
      }
    }
    return false;
  }

  @override
  Future<bool> logout() async {
    _isLogin = false;
    await RequestHandlers.copyMangaRequestHandler.logout();
    notifyListeners();
    return true;
  }

  @override
  String? get nickname => _nickname;

  @override
  Future<bool> subscribeComic(String comicId) async {
    try {
      var response = await RequestHandlers.copyMangaRequestHandler
          .addSubscribe(comicId, true);
      return (response.statusCode == 200 || response.statusCode == 304) &&
          response.data['code'] == 200;
    } catch (e, s) {
      logger.e('$e', error: e, stackTrace: s);
    }
    return false;
  }

  @override
  String? get uid => _uid;

  @override
  Future<bool> unsubscribeComic(String comicId) async {
    try {
      var response = await RequestHandlers.copyMangaRequestHandler
          .addSubscribe(comicId, false);
      return (response.statusCode == 200 || response.statusCode == 304) &&
          response.data['code'] == 200;
    } catch (e, s) {
      logger.e('$e', error: e, stackTrace: s);
    }
    return false;
  }

  @override
  String? get username => _username;

  @override
  Future<void> init() async {
    var databaseInstance = await DatabaseInstance.instance;
    var databaseIsLogin = (await databaseInstance.modelConfigDao
        .getOrCreateConfigByKey('isLogin', parent!.type.sourceId));
    _isLogin = databaseIsLogin.get<bool>() ?? false;
    if (_isLogin) {
      try {
        var response =
            await RequestHandlers.copyMangaRequestHandler.getUserInfo();
        if (response.statusCode == 200) {
          var data = response.data['results'];
          _uid = data['user_id'];
          _nickname = data['nickname'];
          _username = data['username'];
          _avatar = ImageEntity(ImageType.network, data['avatar'],
              imageHeaders: {"Referer": "https://www.mangacopy.com/"});
        }
      } catch (e, s) {
        logger.e('$e', error: e, stackTrace: s);
        _isLogin = false;
      }
    }
    _isLoading = false;
    notifyListeners();
  }

  @override
  bool get isLoading => _isLoading;

  @override
  bool get isLogin => _isLogin;
}

class CopyMangaComicHomepageModel extends BaseComicHomepageModel {
  final CopyMangaComicSourceModel parent;

  CopyMangaComicHomepageModel(this.parent);

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
      var order = categoryFilter['TimeOrRank'] == TimeOrRankEnum.latestUpdate
          ? '-datetime_updated'
          : '-popular';
      Response response;
      if (categoryType == 0) {
        response = await RequestHandlers.copyMangaRequestHandler
            .getCategoryDetailList(theme: categoryId, page: page, order: order);
      } else {
        response = await RequestHandlers.copyMangaRequestHandler
            .getAuthorDetailList(author: categoryId, page: page, order: order);
      }
      if ((response.statusCode == 200 || response.statusCode == 304) &&
          response.data['code'] == 200) {
        for (var item in response.data['results']['list']) {
          data.add(ListItemEntity(
              item['name'], ImageEntity(ImageType.network, item['cover']), {
            Icons.supervisor_account_rounded:
                item['author'].map((e) => e['name']).toList().join('/'),
            FontAwesome5.fire: item['popular'].toString(),
            Icons.history_edu: item['datetime_updated']
          }, (context) {
            Provider.of<NavigatorProvider>(context, listen: false)
                .getNavigator(context, NavigatorType.defaultNavigator)
                ?.push(MaterialPageRoute(
                    builder: (context) => ComicDetailPage(
                          title: item['name'],
                          comicId: item['path_word'],
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

  @override
  Future<List<GridItemEntity>> getCategoryList() async {
    List<GridItemEntity> data = [];
    try {
      var response =
          await RequestHandlers.copyMangaRequestHandler.getCategory();
      if ((response.statusCode == 200 || response.statusCode == 304) &&
          response.data['code'] == 200) {
        for (var item in response.data['results']['list']) {
          var cover = item['logo'];
          var randomFallbackCover = [
            'https://cdn-icons-png.flaticon.com/512/3938/3938619.png',
            'https://cdn-icons-png.flaticon.com/512/2281/2281829.png',
            'https://cdn-icons-png.flaticon.com/512/5190/5190321.png',
            'https://cdn-icons-png.flaticon.com/512/9824/9824322.png'
          ];
          cover ??= randomFallbackCover[Random().nextInt(4)];
          data.add(GridItemEntity(item['name'], item['count'].toString(),
              ImageEntity(ImageType.network, cover), (context) {
            Provider.of<NavigatorProvider>(context, listen: false)
                .getNavigator(context, NavigatorType.defaultNavigator)
                ?.push(MaterialPageRoute(
                    builder: (context) => ComicCategoryDetailPage(
                          categoryId: item['path_word'],
                          sourceModel: parent,
                          categoryTitle: item['name'],
                        ),
                    settings:
                        const RouteSettings(name: 'ComicCategoryDetailPage')));
          }));
        }
      }
    } catch (e, s) {
      logger.e('$e', error: e, stackTrace: s);
      rethrow;
    }
    return data;
  }

  @override
  Future<List<HomepageCardEntity>> getHomepageCard() async {
    List<HomepageCardEntity> data = [];
    try {
      var response =
          await RequestHandlers.copyMangaRequestHandler.getHomepage();
      if ((response.statusCode == 200 || response.statusCode == 304) &&
          response.data['code'] == 200) {
        var result = response.data['results'];
        makeHomepageCardForComic(
            'recComics', '推荐漫画', Icons.recommend, result, data);
        makeHomepageCardForComic('rankDayComics', '每日推荐',
            Icons.calendar_today_outlined, result, data);
        makeHomepageCardForComic('rankWeekComics', '每周推荐',
            Icons.calendar_view_week_outlined, result, data);
        makeHomepageCardForComic('rankMonthComics', '每月推荐',
            Icons.calendar_month_outlined, result, data);
        makeHomepageCardForComic(
            'hotComics', '热门漫画', FontAwesome5.fire, result, data);
        makeHomepageCardForComic(
            'newComics', '上新漫画', Icons.new_label, result, data);
        List comicRawData = result['finishComics']['list'];
        List<GridItemEntity> comicChildren = [];
        for (var comicRawData in comicRawData) {
          comicChildren.add(GridItemEntity(
              comicRawData['name'],
              comicRawData['theme'].map((e) => e['name']).toList().join('/'),
              ImageEntity(ImageType.network, comicRawData['cover']), (context) {
            Provider.of<NavigatorProvider>(context, listen: false)
                .getNavigator(context, NavigatorType.defaultNavigator)
                ?.push(MaterialPageRoute(
                    builder: (context) => ComicDetailPage(
                          title: comicRawData['name'],
                          comicId: comicRawData['path_word'],
                          comicSourceModel: parent,
                        ),
                    settings: const RouteSettings(name: 'ComicDetailPage')));
          }));
        }
        data.add(HomepageCardEntity(
            '完结漫画', Icons.check_box, (context) {}, comicChildren));
      }
    } catch (e, s) {
      logger.e('$e', error: e, stackTrace: s);
      rethrow;
    }
    return data;
  }

  void makeHomepageCardForComic(String cardName, String cardTitle,
      IconData? icon, Map result, List<HomepageCardEntity> data) {
    List comicRawData;
    if (result[cardName] is List) {
      comicRawData = result[cardName];
    } else {
      comicRawData = result[cardName]['list'];
    }
    List<GridItemEntity> comicChildren = [];
    for (var item in comicRawData) {
      var comicRawData = item['comic'];
      comicChildren.add(GridItemEntity(
          comicRawData['name'],
          comicRawData['theme'].map((e) => e['name']).toList().join('/'),
          ImageEntity(ImageType.network, comicRawData['cover']), (context) {
        Provider.of<NavigatorProvider>(context, listen: false)
            .getNavigator(context, NavigatorType.defaultNavigator)
            ?.push(MaterialPageRoute(
                builder: (context) => ComicDetailPage(
                      title: comicRawData['name'],
                      comicId: comicRawData['path_word'],
                      comicSourceModel: parent,
                    ),
                settings: const RouteSettings(name: 'ComicDetailPage')));
      }));
    }
    data.add(HomepageCardEntity(cardTitle, icon, (context) {}, comicChildren));
  }

  @override
  Future<List<CarouselEntity>> getHomepageCarousel() async {
    List<CarouselEntity> data = [];
    try {
      var response =
          await RequestHandlers.copyMangaRequestHandler.getHomepage();
      if ((response.statusCode == 200 || response.statusCode == 304) &&
          response.data['code'] == 200) {
        var rawData = response.data['results']['banners'];
        for (var item in rawData) {
          data.add(CarouselEntity(ImageEntity(ImageType.network, item['cover']),
              item['brief'], (context) {}));
        }
      }
    } catch (e, s) {
      logger.e('$e', error: e, stackTrace: s);
      rethrow;
    }
    return data;
  }

  @override
  Future<List<ListItemEntity>> getLatestList({int page = 0}) async {
    List<ListItemEntity> data = [];
    try {
      Response response = await RequestHandlers.copyMangaRequestHandler
          .getLatestList(page: page);
      if ((response.statusCode == 200 || response.statusCode == 304) &&
          response.data['code'] == 200) {
        for (var item in response.data['results']['list']) {
          var comicRawData = item['comic'];
          data.add(ListItemEntity(comicRawData['name'],
              ImageEntity(ImageType.network, comicRawData['cover']), {
            Icons.supervisor_account_rounded:
                comicRawData['author'].map((e) => e['name']).toList().join('/'),
            Icons.book_outlined: comicRawData['last_chapter_name'],
            Icons.history_edu: comicRawData['datetime_updated']
          }, (context) {
            Provider.of<NavigatorProvider>(context, listen: false)
                .getNavigator(context, NavigatorType.defaultNavigator)
                ?.push(MaterialPageRoute(
                    builder: (context) => ComicDetailPage(
                          title: comicRawData['name'],
                          comicId: comicRawData['path_word'],
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

  @override
  Future<List<ListItemEntity>> getRankingList({int page = 0}) async {
    List<ListItemEntity> data = [];
    try {
      Response response =
          await RequestHandlers.copyMangaRequestHandler.getRankList(page: page);
      if ((response.statusCode == 200 || response.statusCode == 304) &&
          response.data['code'] == 200) {
        for (var item in response.data['results']['list']) {
          var comicRawData = item['comic'];
          data.add(ListItemEntity(comicRawData['name'],
              ImageEntity(ImageType.network, comicRawData['cover']), {
            Icons.supervisor_account_rounded:
                comicRawData['author'].map((e) => e['name']).toList().join('/'),
            FontAwesome5.fire: item['popular'].toString(),
            Icons.arrow_circle_up: item['rise_num'].toString()
          }, (context) {
            Provider.of<NavigatorProvider>(context, listen: false)
                .getNavigator(context, NavigatorType.defaultNavigator)
                ?.push(MaterialPageRoute(
                    builder: (context) => ComicDetailPage(
                          title: comicRawData['name'],
                          comicId: comicRawData['path_word'],
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
