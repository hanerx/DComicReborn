import 'package:dcomic/database/database_instance.dart';
import 'package:dcomic/generated/l10n.dart';
import 'package:dcomic/providers/models/comic_source_model.dart';
import 'package:dcomic/providers/navigator_provider.dart';
import 'package:dcomic/providers/page_controllers/comic_favorite_page_controller.dart';
import 'package:dcomic/requests/base_request.dart';
import 'package:dcomic/requests/copymanga/copymanga_request.dart';
import 'package:dcomic/utils/image_utils.dart';
import 'package:dcomic/view/category_pages/comic_category_detail_page.dart';
import 'package:dcomic/view/comic_pages/comic_detail_page.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:fluttericon/font_awesome5_icons.dart';
import 'package:provider/provider.dart';

class CopyMangaComicSourceModel extends BaseComicSourceModel {
  final CopyMangaAccountModel _accountModel = CopyMangaAccountModel();
  CopyMangaApiDomain _apiDomain = CopyMangaApiDomain.defaultDomain;
  CopyMangaApiDomain _chapterCommentDomain = CopyMangaApiDomain.defaultDomain;
  bool _changingDomain = false;

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
          final chapters = <dynamic>[];
          var total = item['count'] as int;
          while (chapters.length < total) {
            final chapterResponse = await RequestHandlers
                .copyMangaRequestHandler
                .getChapters(comicId, item['path_word'], page: chapters.length);
            if ((chapterResponse.statusCode != 200 &&
                    chapterResponse.statusCode != 304) ||
                chapterResponse.data['code'] != 200) {
              throw StateError(
                  'Failed to load chapter group ${item['path_word']}');
            }
            final result = chapterResponse.data['results'];
            final batch = result['list'] as List;
            total = (result['total'] as int?) ?? total;
            if (batch.isEmpty && chapters.length < total) {
              throw StateError('Incomplete chapter group ${item['path_word']}');
            }
            chapters.addAll(batch);
          }
          groupsRawData[item] = chapters;
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
  Future<List<ListItemEntity>> getComicHistory(
      ComicHistorySourceType sourceType,
      {int page = 0}) async {
    if (sourceType == ComicHistorySourceType.local) {
      return super.getComicHistory(sourceType, page: page);
    } else if (sourceType == ComicHistorySourceType.network) {
      List<ListItemEntity> data = [];
      var response =
          await RequestHandlers.copyMangaRequestHandler.getHistory(page: page);
      if ((response.statusCode == 200 || response.statusCode == 304) &&
          response.data['code'] == 200) {
        var responseData = response.data['results']['list'];
        for (var item in responseData) {
          data.add(ListItemEntity(item['comic']['name'],
              ImageEntity(ImageType.network, item['comic']['cover']), {
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
          Icons.supervisor_account_rounded:
              item['author'].map((e) => e['name']).toList().join('/'),
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
  Future<void> initModel() async {
    _accountModel.parent ??= this;
    _apiDomain = await RequestHandlers.copyMangaRequestHandler.apiDomain;
    final dao = (await DatabaseInstance.instance).modelConfigDao;
    final config = await dao.getConfigByKeyAndModel(
        'chapterCommentApiDomain', type.sourceId);
    final domain = CopyMangaApiDomain.fromHost(config?.get<String>());
    _chapterCommentDomain =
        domain.isHotManga ? CopyMangaApiDomain.defaultDomain : domain;
    await super.initModel();
    notifyListeners();
  }

  @override
  BaseComicAccountModel? get accountModel => _accountModel;

  @override
  BaseComicHomepageModel? get homepage => CopyMangaComicHomepageModel(this);

  @override
  Widget getSourceSettingWidget(BuildContext context) => ListenableBuilder(
      listenable: this, builder: (context, _) => _buildSourceSettings(context));

  Widget _buildSourceSettings(BuildContext context) {
    final strings = S.of(context);
    Widget selector(String label, CopyMangaApiDomain value,
        Iterable<CopyMangaApiDomain> domains, bool comments) {
      return ListTile(
        leading: Icon(comments ? Icons.comment_outlined : Icons.http),
        title: Text(label),
        subtitle: DropdownButton<CopyMangaApiDomain>(
          value: value,
          isExpanded: true,
          items: domains
              .map((domain) => DropdownMenuItem(
                    value: domain,
                    child: Text(
                        '${domain.isHotManga ? strings.HotMangaTitle : strings.CopyMangaTitle} · ${domain.host}'),
                  ))
              .toList(),
          onChanged: _changingDomain
              ? null
              : (domain) async {
                  if (domain == null || domain == value) return;
                  _changingDomain = true;
                  notifyListeners();
                  try {
                    final dao =
                        (await DatabaseInstance.instance).modelConfigDao;
                    final config = await dao.getOrCreateConfigByKey(
                        comments ? 'chapterCommentApiDomain' : 'apiDomain',
                        type.sourceId);
                    config.set(domain.host);
                    await dao.updateConfig(config);
                    if (comments) {
                      _chapterCommentDomain = domain;
                    } else {
                      _apiDomain = domain;
                      await _accountModel.initAccount();
                    }
                  } catch (e, s) {
                    logger.e('$e', error: e, stackTrace: s);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context)
                          .showSnackBar(SnackBar(content: Text('$e')));
                    }
                  } finally {
                    _changingDomain = false;
                    notifyListeners();
                  }
                },
        ),
      );
    }

    return Column(
      children: [
        selector(strings.CopyMangaApiDomain, _apiDomain,
            CopyMangaApiDomain.values, false),
        selector(
            strings.CopyMangaChapterCommentDomain,
            _chapterCommentDomain,
            CopyMangaApiDomain.values.where((domain) => !domain.isHotManga),
            true),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Text(strings.CopyMangaRoutingHint),
        ),
      ],
    );
  }
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
          data.add(ChapterCommentEntity(
              item['id'].toString(), item['comment'], 1,
              avatar: ImageEntity(ImageType.network, item['user_avatar'])));
        }
      }
    } catch (e, s) {
      logger.e('$e', error: e, stackTrace: s);
    }
    return data;
  }

  @override
  List<ImageEntity> get pages {
    final contents = rawData['contents'] as List;
    final words = rawData['words'] as List?;
    final indices = List<int>.generate(contents.length, (index) => index);
    if (words != null && words.isNotEmpty) {
      if (words.length != contents.length) {
        throw const FormatException(
            'Chapter page order does not match contents');
      }
      indices.sort((a, b) {
        final order = (words[a] as int).compareTo(words[b] as int);
        return order == 0 ? a.compareTo(b) : order;
      });
    }
    return indices
        .map((index) => ImageEntity(
              ImageType.network,
              contents[index]['url'] as String,
              imageHeaders: CopyMangaRequestHandler.imageHeaders,
            ))
        .toList();
  }

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
  String? _token;

  @override
  ImageEntity? get avatar => _avatar;

  @override
  String? get token => _token;

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
                          parent?._apiDomain.isHotManga == true
                              ? S.of(context).HotMangaTitle
                              : S.of(context).CopyMangaTitle,
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
                                      labelText: S.of(context).CopyMangaToken,
                                      prefixIcon:
                                          const Icon(Icons.token_outlined),
                                      hintText:
                                          S.of(context).CopyMangaTokenHint),
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
                      onPressed: () async {
                        try {
                          if (formKey.currentState!.validate()) {
                            if (await loginWithToken(tokenController.text)) {
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
                      icon: const Icon(Icons.generating_tokens_outlined),
                      label: Text(S.of(context).TokenLogin),
                      style: ButtonStyle(
                          backgroundColor: WidgetStateProperty.all(Colors.cyan),
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
          data.add(GridItemEntityWithStatus(
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
                    settings: const RouteSettings(name: 'ComicDetailPage')))
                .then((value) {
              if (context.mounted) {
                Provider.of<ComicFavoritePageController>(context, listen: false)
                    .refresh();
              }
            });
          }, DateTime.parse(rawData['datetime_updated']),
              rawData['path_word'].toString()));
        }
      }
    } catch (e, s) {
      logger.e(e, error: e, stackTrace: s);
    }
    return data;
  }

  @override
  Future<bool> login(String username, String password) async {
    final handler = RequestHandlers.copyMangaRequestHandler;
    final domain = await handler.apiDomain;
    final response = await handler.login(username, password, domain: domain);
    if ((response.statusCode == 200 || response.statusCode == 304) &&
        response.data['code'] == 200) {
      return _saveLogin(domain, response.data['results']['token'] as String);
    }
    throw StateError('${response.data['message'] ?? response.data['results']}');
  }

  Future<bool> _saveLogin(CopyMangaApiDomain domain, String token) async {
    if (token.trim().isEmpty) return false;
    final dao = (await DatabaseInstance.instance).modelConfigDao;
    final savedToken =
        await dao.getOrCreateConfigByKey('token', domain.accountSourceId);
    savedToken.set(token.trim());
    await dao.updateConfig(savedToken);
    final state =
        await dao.getOrCreateConfigByKey('isLogin', domain.accountSourceId);
    state.set(true);
    await dao.updateConfig(state);
    await initAccount();
    return _isLogin;
  }

  @override
  Future<bool> loginWithToken(String token) async {
    final domain = await RequestHandlers.copyMangaRequestHandler.apiDomain;
    return _saveLogin(domain, token);
  }

  @override
  Future<bool> logout() async {
    final handler = RequestHandlers.copyMangaRequestHandler;
    final domain = await handler.apiDomain;
    try {
      await handler.logout(domain: domain);
    } finally {
      await _clearCredentials(domain);
      await initAccount();
    }
    return true;
  }

  Future<void> _clearCredentials(CopyMangaApiDomain domain) async {
    final dao = (await DatabaseInstance.instance).modelConfigDao;
    final state =
        await dao.getOrCreateConfigByKey('isLogin', domain.accountSourceId);
    state.set(false);
    await dao.updateConfig(state);
    final token =
        await dao.getOrCreateConfigByKey('token', domain.accountSourceId);
    token.set('');
    await dao.updateConfig(token);
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
  Future<void> initAccount() async {
    final generation = ++_accountGeneration;
    _isLoading = true;
    _isLogin = false;
    _uid = null;
    _username = null;
    _nickname = null;
    _avatar = null;
    _token = null;
    notifyListeners();
    CopyMangaApiDomain? domain;
    try {
      final handler = RequestHandlers.copyMangaRequestHandler;
      domain = await handler.apiDomain;
      final dao = (await DatabaseInstance.instance).modelConfigDao;
      final state =
          await dao.getConfigByKeyAndModel('isLogin', domain.accountSourceId);
      if (state?.get<bool>() != true) return;
      final token =
          (await dao.getConfigByKeyAndModel('token', domain.accountSourceId))
              ?.get<String>();
      final response = await handler.getUserInfo(domain: domain);
      if (generation != _accountGeneration) return;
      if (response.statusCode == 200 && response.data['code'] == 200) {
        final data = response.data['results'];
        _uid = data['user_id'].toString();
        _nickname = data['nickname'];
        _username = data['username'];
        _avatar = ImageEntity(ImageType.network, data['avatar'],
            imageHeaders: CopyMangaRequestHandler.imageHeaders);
        _token = token;
        _isLogin = true;
      } else if (response.data['code'] == 401) {
        await _clearCredentials(domain);
      }
    } catch (e, s) {
      if (generation == _accountGeneration &&
          e is DioException &&
          e.response?.statusCode == 401 &&
          domain != null) {
        await _clearCredentials(domain);
      }
      logger.e('$e', error: e, stackTrace: s);
    } finally {
      if (generation == _accountGeneration) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  int _accountGeneration = 0;

  @override
  bool get isLoading => _isLoading;

  @override
  bool get isLogin => _isLogin;
}

class CopyMangaComicHomepageModel extends BaseComicHomepageModel {
  final CopyMangaComicSourceModel parent;

  CopyMangaComicHomepageModel(this.parent);

  // Fixed artwork keyed by API identity, never by translated name or list order.
  // Image origins and crop rectangles: assets/copymanga/credits.json.
  static const _categoryArtwork = <String, String>{
    'aiqing': 'aiqing',
    'huanlexiang': 'huanlexiang',
    'maoxian': 'maoxian',
    'qihuan': 'qihuan',
    'baihe': 'baihe',
    'xiaoyuan': 'xiaoyuan',
    'kehuan': 'kehuan',
    'dongfang': 'dongfang',
    'danmei': 'danmei',
    'shenghuo': 'shenghuo',
    'gedou': 'gedou',
    'qingxiaoshuo': 'qingxiaoshuo',
    'qita': 'default',
    'xuanyi': 'xuanyi',
    'teenslove': 'teenslove',
    'mengxi': 'mengxi',
    'shengui': 'shengui',
    'zhichang': 'zhichang',
    'zhiyu': 'zhiyu',
    'jiecao': 'jiecao',
    'sige': 'sige',
    'changtiao': 'changtiao',
    'jianniang': 'jianniang',
    'gaoxiao': 'gaoxiao',
    'jingji': 'jingji',
    'weiniang': 'weiniang',
    'mohuan': 'mohuan',
    'rexue': 'rexue',
    'xingzhuanhuan': 'xingzhuanhuan',
    'meishi': 'meishi',
    'lizhi': 'lizhi',
    'COLOR': 'COLOR',
    'hougong': 'hougong',
    'zhentan': 'zhentan',
    'jingsong': 'jingsong',
    'aa': 'aa',
    'yinyuewudao': 'yinyuewudao',
    'yishijie': 'yishijie',
    'zhanzheng': 'zhanzheng',
    'lishi': 'lishi',
    'jizhan': 'jizhan',
    'dushi': 'dushi',
    'chuanyue': 'chuanyue',
    'comiket102': 'comiket102',
    'chongsheng': 'chongsheng',
    'kongbu': 'kongbu',
    'comiket103': 'comiket103',
    'shengcun': 'shengcun',
    'comiket100': 'comiket100',
    'comiket104': 'comiket104',
    'comiket101': 'comiket101',
    'comiket99': 'comiket99',
    'comiket97': 'comiket97',
    'wuxia': 'wuxia',
    'zhaixi': 'zhaixi',
    'comiket96': 'comiket96',
    'comiket105': 'comiket105',
    'C98': 'C98',
    'comiket95': 'comiket95',
    'zhuansheng': 'zhuansheng',
    'fate': 'fate',
    'Uncensored': 'Uncensored',
    'xianxia': 'xianxia',
    'loveLive': 'loveLive',
    'zazhifuzengxiezhenji': 'zazhifuzengxiezhenji',
    'xuanhuan': 'xuanhuan',
    'yineng': 'yineng',
    'youxi': 'youxi',
    'zhenren': 'zazhifuzengxiezhenji',
  };

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
          final artwork = _categoryArtwork[item['path_word']] ?? 'default';
          data.add(GridItemEntity(
              item['name'],
              item['count'].toString(),
              ImageEntity(
                  ImageType.asset, 'assets/copymanga/categories/$artwork.png'),
              (context) {
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
        makeHomepageCardForComic(
            'finishComics', '完结漫画', Icons.check_box, result, data);
        makeHomepageCardForComic('rankWeeklyFreeComics', '免费周榜',
            Icons.calendar_view_week_outlined, result, data);
        makeHomepageCardForComic('rankWeeklyChargeComics', '付费周榜',
            Icons.calendar_view_week_outlined, result, data);
        makeHomepageCardForComic(
            'updateWeeklyFreeComics', '免费更新', Icons.new_label, result, data);
        makeHomepageCardForComic(
            'updateWeeklyChargeComics', '付费更新', Icons.new_label, result, data);
      }
    } catch (e, s) {
      logger.e('$e', error: e, stackTrace: s);
      rethrow;
    }
    return data;
  }

  void makeHomepageCardForComic(String cardName, String cardTitle,
      IconData? icon, Map result, List<HomepageCardEntity> data) {
    // Copy and HotManga expose different optional homepage sections.
    if (result[cardName] == null) return;
    List comicRawData;
    if (result[cardName] is List) {
      comicRawData = result[cardName];
    } else {
      comicRawData = result[cardName]['list'];
    }
    if (comicRawData.isEmpty) return;
    List<GridItemEntity> comicChildren = [];
    for (var item in comicRawData) {
      final comicRawData = item['comic'] ?? item;
      comicChildren.add(GridItemEntity(
          comicRawData['name'],
          (comicRawData['theme'] as List? ?? const [])
              .map((e) => e['name'])
              .join('/'),
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
