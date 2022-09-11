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
import 'package:provider/provider.dart';

class DMZJComicSourceModel extends BaseComicSourceModel {
  final DMZJComicAccountModel _accountModel = DMZJComicAccountModel();

  @override
  ComicSourceEntity get type =>
      ComicSourceEntity("大妈之家", "dmzj", hasHomepage: true);

  @override
  Future<BaseComicDetailModel?> getComicDetail(
      String comicId, String title) async {
    try {
      ComicDetailInfoResponse? rawData =
          await RequestHandlers.dmzjv4requestHandler.getComicDetail(comicId);
      if (rawData != null) {
        return DMZJV4ComicDetailModel(rawData);
      }
    } catch (e, s) {
      logger.e('$e', e, s);
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

  DMZJV4ComicDetailModel(this.rawData);

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
  ImageEntity get cover => ImageEntity(ImageType.network, rawData.cover,
      imageHeaders: {"referer": "https://i.dmzj.com"});
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
    return Column(
      children: [
        Card(
          child: Column(
            children: [
              Form(key:formKey,child: Column(
                children: [
                  TextFormField(decoration: InputDecoration(
                    hintText: '用户名',
                  ),),
                  TextFormField(decoration: InputDecoration(
                    hintText: '密码',
                  ),)
                ],
              )),
              Row(
                children: [
                  Expanded(child: SizedBox(),),
                  ElevatedButton(onPressed: (){}, child: Text("登录"))
                ],
              )
            ],
          ),
        )
      ],
    );
  }

  @override
  Future<bool> login(String username, String password) {
    // TODO: implement login
    throw UnimplementedError();
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
}
