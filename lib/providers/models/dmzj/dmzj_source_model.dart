import 'dart:convert';

import 'package:date_format/date_format.dart';
import 'package:dcomic/database/database_instance.dart';
import 'package:dcomic/database/entity/comic_history.dart';
import 'package:dcomic/protobuf/comic.pb.dart';
import 'package:dcomic/providers/models/comic_source_model.dart';
import 'package:dcomic/providers/navigator_provider.dart';
import 'package:dcomic/requests/base_request.dart';
import 'package:dcomic/utils/image_utils.dart';
import 'package:dcomic/view/comic_pages/comic_detail_page.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:fluttericon/font_awesome5_icons.dart';
import 'package:provider/provider.dart';

class DMZJComicSourceModel extends BaseComicSourceModel {
  final DMZJComicAccountModel _accountModel = DMZJComicAccountModel();

  @override
  ComicSourceEntity get type => ComicSourceEntity("大妈之家", "dmzj",
      hasHomepage: true, hasAccountSupport: true);

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
      logger.e('$e', e, s);
      rethrow;
    }
    return null;
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
  Future<void> init() async {
    _accountModel.parent ??= this;
    await super.init();
  }

  @override
  BaseComicHomepageModel? get homepage => DMZJComicHomepageModel(this);

  @override
  // TODO: implement accountModel
  BaseComicAccountModel? get accountModel => _accountModel;
}

class DMZJComicHomepageModel extends BaseComicHomepageModel {
  static List<int> blackList = [46];
  final DMZJComicSourceModel parent;

  DMZJComicHomepageModel(this.parent);

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
            Icons.history_edu: formatDate(
                DateTime.fromMicrosecondsSinceEpoch(
                    rawListItem.lastUpdatetime.toInt() * 1000000),
                [yyyy, '-', mm, '-', dd])
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
}

class DMZJV4ComicDetailModel extends BaseComicDetailModel {
  final ComicDetailInfoResponse rawData;
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
  Future<BaseComicChapterDetailModel?> getChapter(String chapterId) {
    // TODO: implement getChapter
    throw UnimplementedError();
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
      .map((e) => CategoryEntity(e.tagName, e.tagId.toString()))
      .toList();

  @override
  List<CategoryEntity> get categories => rawData.types
      .map((e) => CategoryEntity(e.tagName, e.tagId.toString()))
      .toList();
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
  // TODO: implement avatar
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
                          "DMZJ",
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
                                      border: OutlineInputBorder(gapPadding: 1),
                                      labelText: '用户名',
                                      prefixIcon: Icon(Icons.account_circle),
                                      hintText: '昵称/手机号/邮箱'),
                                ),
                              ),
                              Padding(
                                padding: EdgeInsets.only(bottom: 10),
                                child: TextFormField(
                                  controller: passwordController,
                                  obscureText: true,
                                  decoration: InputDecoration(
                                      isDense: true,
                                      border: OutlineInputBorder(gapPadding: 1),
                                      labelText: '密码',
                                      prefixIcon: Icon(Icons.lock),
                                      hintText: '大妈之家登录密码'),
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
                          logger.e(e, e, s);
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text('登录失败: $e'),
                          ));
                        }
                      },
                      icon: const Icon(FontAwesome5.arrow_right),
                      label: Text("登录"),
                      style: ButtonStyle(
                          shape:
                              MaterialStateProperty.all(RoundedRectangleBorder(
                                  borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(3),
                            bottomLeft: Radius.circular(3),
                          ))),
                          padding: MaterialStateProperty.all(
                              EdgeInsets.only(top: 10, left: 10, bottom: 10))),
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
                      label: Text("QQ登录"),
                      style: ButtonStyle(
                          backgroundColor:
                              MaterialStateProperty.all(Colors.cyan),
                          shape:
                              MaterialStateProperty.all(RoundedRectangleBorder(
                                  borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(3),
                            bottomLeft: Radius.circular(3),
                          ))),
                          padding: MaterialStateProperty.all(
                              EdgeInsets.only(top: 10, left: 10, bottom: 10))),
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
          await init();
          return true;
        } else {
          throw response.data['msg'];
        }
      }
    } catch (e, s) {
      logger.e(e, e, s);
      rethrow;
    }
    return false;
  }

  @override
  Future<bool> logout() {
    // TODO: implement logout
    throw UnimplementedError();
  }

  @override
  Future<void> init() async {
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
        logger.e(e, e, s);
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
      logger.e(e, e, s);
    }
    return false;
  }

  @override
  Future<bool> subscribeComic(String comicId) async{
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
      logger.e(e, e, s);
    }
    return false;
  }

  @override
  Future<bool> unsubscribeComic(String comicId) async{
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
      logger.e(e, e, s);
    }
    return false;
  }
}
