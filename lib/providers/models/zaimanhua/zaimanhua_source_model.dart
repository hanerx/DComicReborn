import 'dart:convert';

import 'package:dcomic/database/database_instance.dart';
import 'package:dcomic/generated/l10n.dart';
import 'package:dcomic/providers/models/comic_source_model.dart';
import 'package:dcomic/providers/navigator_provider.dart';
import 'package:dcomic/providers/page_controllers/comic_favorite_page_controller.dart';
import 'package:dcomic/requests/base_request.dart';
import 'package:dcomic/utils/image_utils.dart';
import 'package:dcomic/view/category_pages/comic_category_detail_page.dart';
import 'package:dcomic/view/comic_pages/comic_detail_page.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:fluttericon/font_awesome5_icons.dart';
import 'package:provider/provider.dart';
import 'package:date_format/date_format.dart' as date_format;

class ZaiManHuaSourceModel extends BaseComicSourceModel {
  final ZaiManHuaAccountModel _accountModel = ZaiManHuaAccountModel();

  @override
  ComicSourceEntity get type => ComicSourceEntity("再漫画", "zaimanhua",
      hasHomepage: true, hasAccountSupport: true, hasComment: true);

  @override
  Future<BaseComicDetailModel?> getComicDetail(
      String comicId, String title) async {
    var response = await RequestHandlers.zaiManHuaMobileRequestHandler
        .getComicDetail(comicId);
    try {
      if ((response.statusCode == 200 || response.statusCode == 304) &&
          response.data['errno'] == 0) {
        return ZaiManHuaComicDetailModel(response.data['data'], this);
      }
    } catch (e, s) {
      logger.e('$e', error: e, stackTrace: s);
      rethrow;
    }
    return null;
  }

  @override
  Future<List<ComicListItemEntity>> searchComicDetail(String keyword,
      {int page = 0}) async {
    List<ComicListItemEntity> data = [];
    var response = await RequestHandlers.zaiManHuaMobileRequestHandler
        .search(keyword, page: page);
    try {
      if ((response.statusCode == 200 || response.statusCode == 304)) {
        // errno 非零是业务失败（此时负载形状不同），必须作为加载错误抛出，
        // 不能落入下面的解析逻辑被误判为解析失败。
        var errno = response.data['errno'];
        if (errno != null && errno != 0) {
          throw StateError('ZaiManHua search failed: errno $errno');
        }
        var searchList = response.data['data']['list'];
        for (var item in searchList) {
          data.add(ComicListItemEntity(
              item['title'], ImageEntity(ImageType.network, item['cover']), {
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
        return data;
      }
    } catch (e, s) {
      logger.e('$e', error: e, stackTrace: s);
      rethrow;
    }
    throw StateError('ZaiManHua search failed: HTTP ${response.statusCode}');
  }

  @override
  BaseComicHomepageModel? get homepage => ZaiManHuaHomepageModel(this);

  @override
  Future<void> initModel() async {
    _accountModel.parent ??= this;
    return super.initModel();
  }

  @override
  BaseComicAccountModel? get accountModel => _accountModel;

  @override
  Widget getSourceSettingWidget(BuildContext context) =>
      _ZaiManHuaSourceSettings(account: _accountModel);
}

enum ZaiManHuaSignInStatus {
  checking,
  notLoggedIn,
  signedIn,
  notSignedIn,
  queryFailed,
  signInFailed,
}

enum ZaiManHuaVipRewardStatus {
  checking,
  notLoggedIn,
  notMember,
  unavailable,
  claimable,
  claimed,
  queryFailed,
  claimFailed,
}

class _ZaiManHuaSourceSettings extends StatefulWidget {
  const _ZaiManHuaSourceSettings({required this.account});

  final ZaiManHuaAccountModel account;

  @override
  State<_ZaiManHuaSourceSettings> createState() =>
      _ZaiManHuaSourceSettingsState();
}

class _ZaiManHuaSourceSettingsState extends State<_ZaiManHuaSourceSettings>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.account.refreshSignInStatus();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      widget.account.refreshSignInStatus();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: widget.account,
        builder: (context, _) {
          final account = widget.account;
          final strings = S.of(context);
          return Column(
            children: [
              SwitchListTile(
                secondary: const Icon(Icons.event_repeat),
                title: Text(strings.ZaiManHuaAutoSignIn),
                subtitle: Text(strings.ZaiManHuaAutoSignInHint),
                value: account.autoSignInEnabled,
                onChanged: account.isLoading || account.savingAutoSignIn
                    ? null
                    : (enabled) async {
                        try {
                          await account.setAutoSignInEnabled(enabled);
                        } catch (_) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                content:
                                    Text(strings.ZaiManHuaSaveSettingFailed)));
                          }
                        }
                      },
              ),
              ListTile(
                leading: Icon(
                    account.signInStatus == ZaiManHuaSignInStatus.signedIn
                        ? Icons.event_available
                        : Icons.event_note),
                title: Text(strings.ZaiManHuaTodaySignIn),
                subtitle: Text(
                    strings.ZaiManHuaSignInStatus(account.signInStatus.name)),
                trailing: IconButton(
                  tooltip: strings.ZaiManHuaRefreshSignInStatus,
                  onPressed: account.isLoading || account.savingAutoSignIn
                      ? null
                      : account.refreshSignInStatus,
                  icon: const Icon(Icons.refresh),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.workspace_premium_outlined),
                title: Text(strings.ZaiManHuaMembership),
                subtitle:
                    Text(strings.ZaiManHuaMembershipStatus(account.isLoading
                        ? 'checking'
                        : !account.isLogin
                            ? 'notLoggedIn'
                            : account.isMember?.toString() ?? 'unknown')),
              ),
              ListTile(
                leading: const Icon(Icons.card_giftcard),
                title: Text(strings.ZaiManHuaVipDailyReward),
                subtitle: Text(strings.ZaiManHuaVipRewardStatus(
                    account.vipRewardStatus.name)),
              ),
            ],
          );
        },
      );
}

class ZaiManHuaAccountModel extends BaseComicAccountModel {
  bool _isLoading = true;
  bool _isLogin = false;
  ZaiManHuaSourceModel? parent;

  String? _uid;
  String? _username;
  ImageEntity? _avatar;
  String? _nickname;
  String? _token;
  bool _autoSignInEnabled = true;
  bool _savingAutoSignIn = false;
  int _accountGeneration = 0;
  ZaiManHuaSignInStatus _signInStatus = ZaiManHuaSignInStatus.checking;
  bool? _isMember;
  ZaiManHuaVipRewardStatus _vipRewardStatus = ZaiManHuaVipRewardStatus.checking;

  bool get autoSignInEnabled => _autoSignInEnabled;
  bool get savingAutoSignIn => _savingAutoSignIn;
  ZaiManHuaSignInStatus get signInStatus => _signInStatus;
  bool? get isMember => _isMember;
  ZaiManHuaVipRewardStatus get vipRewardStatus => _vipRewardStatus;

  Future<void> setAutoSignInEnabled(bool enabled) async {
    if (_savingAutoSignIn || enabled == _autoSignInEnabled) return;
    _savingAutoSignIn = true;
    notifyListeners();
    try {
      final dao = (await DatabaseInstance.instance).modelConfigDao;
      final config = await dao.getOrCreateConfigByKey(
          'autoSignInEnabled', parent!.type.sourceId,
          value: true);
      config.set(enabled);
      await dao.updateConfig(config);
      _autoSignInEnabled = enabled;
      if (enabled) await initAccount();
    } finally {
      _savingAutoSignIn = false;
      notifyListeners();
    }
  }

  Future<void> refreshSignInStatus() async {
    if (_isLoading || _savingAutoSignIn) return;
    await _loadAccount(automaticallySignIn: false);
  }

  @override
  String? get token => _token;

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
                          S.of(context).ZaiManHuaTitle,
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
                                      hintText: S
                                          .of(context)
                                          .ZaiManHuaLoginPasswordHint),
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
    try {
      var response = await RequestHandlers.zaiManHuaMobileRequestHandler
          .checkIfSubscribe(comicId);
      if ((response.statusCode == 200 || response.statusCode == 304)) {
        return response.data['data']['isSub'];
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
      var response = await RequestHandlers.zaiManHuaMobileRequestHandler
          .getSubscribe(page: page);
      if ((response.statusCode != 200 && response.statusCode != 304) ||
          response.data['errno'] != 0) {
        return data;
      }
      var subList = response.data['data']['list'];
      if (subList.isNotEmpty) {
        for (var rawData in subList) {
          if (rawData['contentType'] != 'comic') continue;
          final comicId = (rawData['id'] as String).substring(2);
          data.add(GridItemEntityWithStatus(
              rawData['title'],
              rawData['lastUpdateChapterName'],
              ImageEntity(
                ImageType.network,
                rawData['coverUrl'],
              ), (context) {
            Provider.of<NavigatorProvider>(context, listen: false)
                .getNavigator(context, NavigatorType.defaultNavigator)
                ?.push(MaterialPageRoute(
                    builder: (context) => ComicDetailPage(
                          title: rawData['title'],
                          comicId: comicId,
                          comicSourceModel: parent,
                        ),
                    settings: const RouteSettings(name: 'ComicDetailPage')))
                .then((value) {
              if (context.mounted) {
                Provider.of<ComicFavoritePageController>(context, listen: false)
                    .refresh();
              }
            });
          },
              DateTime.parse(rawData['lastUpdatedAt']),
              comicId));
        }
      }
    } catch (e, s) {
      logger.e(e, error: e, stackTrace: s);
    }
    return data;
  }

  @override
  Future<bool> login(String username, String password) async {
    var response = await RequestHandlers.zaiManHuaAccountRequestHandler
        .login(username, password);
    try {
      if ((response.statusCode == 200 || response.statusCode == 304)) {
        if (response.data['errno'] == 0) {
          var databaseInstance = await DatabaseInstance.instance;
          var databaseIsLogin = await databaseInstance.modelConfigDao
              .getOrCreateConfigByKey('isLogin', parent!.type.sourceId);
          databaseIsLogin.set(true);
          await databaseInstance.modelConfigDao.updateConfig(databaseIsLogin);
          var databaseToken = await databaseInstance.modelConfigDao
              .getOrCreateConfigByKey('token', parent!.type.sourceId);
          databaseToken.set(response.data['data']['user']['token']);
          await databaseInstance.modelConfigDao.updateConfig(databaseToken);
          await initAccount();
          return true;
        } else {
          throw response.data['errmsg'];
        }
      }
    } catch (e, s) {
      logger.e(e, error: e, stackTrace: s);
      rethrow;
    }
    return false;
  }

  @override
  Future<bool> loginWithToken(String token) async {
    try {
      var databaseInstance = await DatabaseInstance.instance;
      var databaseIsLogin = await databaseInstance.modelConfigDao
          .getOrCreateConfigByKey('isLogin', parent!.type.sourceId);
      databaseIsLogin.set(true);
      await databaseInstance.modelConfigDao.updateConfig(databaseIsLogin);
      var databaseToken = await databaseInstance.modelConfigDao
          .getOrCreateConfigByKey('token', parent!.type.sourceId);
      databaseToken.set(token);
      await databaseInstance.modelConfigDao.updateConfig(databaseToken);
      await initAccount();
      return true;
    } catch (e, s) {
      logger.e(e, error: e, stackTrace: s);
      rethrow;
    }
    return false;
  }

  @override
  Future<bool> logout() async {
    var databaseInstance = await DatabaseInstance.instance;
    var databaseIsLogin = await databaseInstance.modelConfigDao
        .getOrCreateConfigByKey('isLogin', parent!.type.sourceId);
    databaseIsLogin.set(false);
    await databaseInstance.modelConfigDao.updateConfig(databaseIsLogin);
    var databaseUId = await databaseInstance.modelConfigDao
        .getOrCreateConfigByKey('uid', parent!.type.sourceId);
    databaseUId.set('');
    await databaseInstance.modelConfigDao.updateConfig(databaseUId);
    _avatar = null;
    _username = null;
    _nickname = null;
    await initAccount();
    return true;
  }

  @override
  String? get nickname => _nickname;

  @override
  Future<bool> subscribeComic(String comicId) async {
    try {
      var response = await RequestHandlers.zaiManHuaMobileRequestHandler
          .addComicSubScribe(comicId);
      if ((response.statusCode == 200 || response.statusCode == 304)) {
        return response.data['errno'] == 0;
      }
    } catch (e, s) {
      logger.e(e, error: e, stackTrace: s);
    }
    return false;
  }

  @override
  String? get uid => _uid;

  @override
  Future<bool> unsubscribeComic(String comicId) async {
    try {
      var response = await RequestHandlers.zaiManHuaMobileRequestHandler
          .cancelComicSubScribe(comicId);
      if ((response.statusCode == 200 || response.statusCode == 304)) {
        return response.data['errno'] == 0;
      }
    } catch (e, s) {
      logger.e(e, error: e, stackTrace: s);
    }
    return false;
  }

  @override
  String? get username => _username;

  @override
  bool get isLoading => _isLoading;

  @override
  bool get isLogin => _isLogin;

  @override
  Future<void> initAccount() => _loadAccount(automaticallySignIn: true);

  Future<void> _loadAccount({required bool automaticallySignIn}) async {
    final generation = ++_accountGeneration;
    _isLoading = true;
    _signInStatus = ZaiManHuaSignInStatus.checking;
    _isMember = null;
    _vipRewardStatus = ZaiManHuaVipRewardStatus.checking;
    notifyListeners();
    try {
      final dao = (await DatabaseInstance.instance).modelConfigDao;
      final enabled = (await dao.getOrCreateConfigByKey(
              'autoSignInEnabled', parent!.type.sourceId,
              value: true))
          .get<bool>();
      final loggedIn =
          (await dao.getOrCreateConfigByKey('isLogin', parent!.type.sourceId))
              .get<bool>();
      final token =
          (await dao.getOrCreateConfigByKey('token', parent!.type.sourceId))
              .get<String>();
      if (generation != _accountGeneration) return;
      _autoSignInEnabled = enabled;
      _token = token;
      _isLogin = loggedIn && token.isNotEmpty;
      if (!_isLogin) {
        _signInStatus = ZaiManHuaSignInStatus.notLoggedIn;
        _vipRewardStatus = ZaiManHuaVipRewardStatus.notLoggedIn;
        return;
      }
      final response =
          await RequestHandlers.zaiManHuaAccountRequestHandler.getUserData();
      if (generation != _accountGeneration) return;
      if (response.statusCode != 200 && response.statusCode != 304) {
        _signInStatus = ZaiManHuaSignInStatus.queryFailed;
        _vipRewardStatus = ZaiManHuaVipRewardStatus.queryFailed;
        return;
      }
      if (response.data['errno'] != 0) {
        _isLogin = false;
        _signInStatus = ZaiManHuaSignInStatus.notLoggedIn;
        _vipRewardStatus = ZaiManHuaVipRewardStatus.notLoggedIn;
        return;
      }
      final personalInfo = response.data['data']['personalInfo'];
      _uid = personalInfo['uid'].toString();
      _username = _uid;
      _avatar = ImageEntity(ImageType.network, personalInfo['photo']);
      _nickname = personalInfo['nickname'];
      _isMember = personalInfo['isMember'] as bool?;
      _signInStatus = switch (personalInfo['is_sign']) {
        true => ZaiManHuaSignInStatus.signedIn,
        false => ZaiManHuaSignInStatus.notSignedIn,
        _ => ZaiManHuaSignInStatus.queryFailed,
      };
      if (automaticallySignIn &&
          _autoSignInEnabled &&
          _signInStatus == ZaiManHuaSignInStatus.notSignedIn) {
        final signedIn = await _signIn(token);
        if (generation != _accountGeneration) return;
        _signInStatus = signedIn
            ? ZaiManHuaSignInStatus.signedIn
            : ZaiManHuaSignInStatus.signInFailed;
      }
      if (_isMember == true) {
        await _loadVipReward(token, generation,
            claim: automaticallySignIn && _autoSignInEnabled);
      } else {
        _vipRewardStatus = _isMember == false
            ? ZaiManHuaVipRewardStatus.notMember
            : ZaiManHuaVipRewardStatus.queryFailed;
      }
    } catch (_) {
      if (generation == _accountGeneration) {
        _signInStatus = ZaiManHuaSignInStatus.queryFailed;
        _vipRewardStatus = ZaiManHuaVipRewardStatus.queryFailed;
      }
    } finally {
      if (generation == _accountGeneration) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<void> _loadVipReward(String token, int generation,
      {required bool claim}) async {
    try {
      final handler = RequestHandlers.zaiManHuaTaskRequestHandler;
      final response = await handler.getTasks(token);
      if (generation != _accountGeneration) return;
      if (response.statusCode != 200 || response.data['errno'] != 0) {
        _vipRewardStatus = ZaiManHuaVipRewardStatus.queryFailed;
        return;
      }
      final tasks = response.data['data']['task']['dayTask'] as List;
      int? status;
      for (final task in tasks) {
        if (task['id'] == 16) {
          status = task['status'] as int?;
          break;
        }
      }
      _vipRewardStatus = switch (status) {
        2 => ZaiManHuaVipRewardStatus.claimable,
        3 => ZaiManHuaVipRewardStatus.claimed,
        1 || null => ZaiManHuaVipRewardStatus.unavailable,
        _ => ZaiManHuaVipRewardStatus.queryFailed,
      };
      if (!claim || status != 2) return;
      try {
        final reward = await handler.claimVipReward(token);
        if (generation != _accountGeneration) return;
        _vipRewardStatus = reward.statusCode == 200 && reward.data['errno'] == 0
            ? ZaiManHuaVipRewardStatus.claimed
            : ZaiManHuaVipRewardStatus.claimFailed;
      } catch (_) {
        if (generation == _accountGeneration) {
          _vipRewardStatus = ZaiManHuaVipRewardStatus.claimFailed;
        }
      }
    } catch (_) {
      // VIP task errors must not overwrite the ordinary check-in result.
      if (generation == _accountGeneration) {
        _vipRewardStatus = ZaiManHuaVipRewardStatus.queryFailed;
      }
    }
  }

  Future<bool> _signIn(String token) async {
    try {
      final response =
          await RequestHandlers.zaiManHuaTaskRequestHandler.signIn(token);
      final data = response.data;
      // Another client may have signed in since the profile was fetched.
      if (response.statusCode == 200 &&
          (data['errno'] == 0 ||
              (data['errno'] == 1 && data['errmsg'] == '今天已签到过~'))) {
        return true;
      }
      logger.w('再漫画自动签到未成功，保留登录状态');
    } catch (_) {
      // A failed optional task must not turn a valid session into a logout.
      // Do not log the request exception: it can contain the bearer token.
      logger.w('再漫画自动签到请求失败，保留登录状态');
    }
    return false;
  }
}

class ZaiManHuaHomepageModel extends BaseComicHomepageModel {
  static List<int> blackList = [95];
  final ZaiManHuaSourceModel parent;

  ZaiManHuaHomepageModel(this.parent);

  @override
  Future<List<HomepageCardEntity>> getHomepageCard() async {
    List<HomepageCardEntity> data = [];
    Response response = await RequestHandlers.zaiManHuaMobileRequestHandler
        .getMainPageRecommend();
    try {
      if ((response.statusCode == 200 || response.statusCode == 304)) {
        final recommendations =
            response.data is String ? jsonDecode(response.data) : response.data;
        for (var rawData in recommendations) {
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
    Response response = await RequestHandlers.zaiManHuaMobileRequestHandler
        .getMainPageRecommend();
    try {
      if ((response.statusCode == 200 || response.statusCode == 304)) {
        final recommendations =
            response.data is String ? jsonDecode(response.data) : response.data;
        if (recommendations.isEmpty) {
          return data;
        }
        var rawData = recommendations[0];
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
        await RequestHandlers.zaiManHuaMobileRequestHandler.getCategory();
    try {
      if ((response.statusCode == 200 || response.statusCode == 304)) {
        List result = [];
        result = response.data['data']['cateList'];
        for (var rawData in result) {
          data.add(GridItemEntity(rawData['title'], null,
              ImageEntity(ImageType.network, rawData['cover']), (context) {
            Provider.of<NavigatorProvider>(context, listen: false)
                .getNavigator(context, NavigatorType.defaultNavigator)
                ?.push(MaterialPageRoute(
                    builder: (context) => ComicCategoryDetailPage(
                          categoryId: rawData['tagId'].toString(),
                          categoryType: rawData['tagType'],
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
    try {
      var response = await RequestHandlers.zaiManHuaMobileRequestHandler
          .getRankList(page: page);
      if ((response.statusCode == 200 || response.statusCode == 304)) {
        for (var rawItem in response.data['data']) {
          data.add(ListItemEntity(rawItem['title'],
              ImageEntity(ImageType.network, rawItem['cover']), {
            Icons.supervisor_account_rounded: rawItem['authors'] ?? '未知',
            Icons.apps: rawItem['types'],
            Icons.history_edu: date_format.formatDate(
                DateTime.fromMicrosecondsSinceEpoch(
                    rawItem['last_updatetime'] * 1000000),
                [date_format.yyyy, '-', date_format.mm, '-', date_format.dd])
          }, (context) {
            Provider.of<NavigatorProvider>(context, listen: false)
                .getNavigator(context, NavigatorType.defaultNavigator)
                ?.push(MaterialPageRoute(
                    builder: (context) => ComicDetailPage(
                          title: rawItem['title'],
                          comicId: rawItem['comic_id'].toString(),
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
  Future<List<ListItemEntity>> getLatestList({int page = 0}) async {
    List<ListItemEntity> data = [];
    try {
      var response = await RequestHandlers.zaiManHuaMobileRequestHandler
          .getLatestList(page: page);
      if ((response.statusCode == 200 || response.statusCode == 304)) {
        for (var rawItem in response.data['data']) {
          data.add(ListItemEntity(rawItem['title'],
              ImageEntity(ImageType.network, rawItem['cover']), {
            Icons.supervisor_account_rounded: rawItem['authors'],
            Icons.apps: rawItem['types'],
            Icons.history_edu: date_format.formatDate(
                DateTime.fromMicrosecondsSinceEpoch(
                    rawItem['last_updatetime'] * 1000000),
                [date_format.yyyy, '-', date_format.mm, '-', date_format.dd])
          }, (context) {
            Provider.of<NavigatorProvider>(context, listen: false)
                .getNavigator(context, NavigatorType.defaultNavigator)
                ?.push(MaterialPageRoute(
                    builder: (context) => ComicDetailPage(
                          title: rawItem['title'],
                          comicId: rawItem['comic_id'].toString(),
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
  List<FilterEntity> get categoryFilter => [TimeOrRankFilterEntity()];

  @override
  Future<List<ListItemEntity>> getCategoryDetailList(
      {required String categoryId,
      required Map<String, dynamic> categoryFilter,
      int page = 0,
      int categoryType = 0}) async {
    List<ListItemEntity> data = [];
    try {
      var response = await RequestHandlers.zaiManHuaMobileRequestHandler
          .getCategoryDetail(int.parse(categoryId),
              page: page,
              categoryType: categoryType,
              type:
                  TimeOrRankEnum.values.indexOf(categoryFilter['TimeOrRank']));
      if ((response.statusCode == 200 || response.statusCode == 304)) {
        for (var rawItem in response.data['data']['comicList']) {
          data.add(ListItemEntity(rawItem['name'],
              ImageEntity(ImageType.network, rawItem['cover']), {
            Icons.supervisor_account_rounded: rawItem['authors'],
            Icons.apps: rawItem['types'],
            Icons.history_edu: date_format.formatDate(
                DateTime.fromMicrosecondsSinceEpoch(
                    rawItem['last_updatetime'] * 1000000),
                [date_format.yyyy, '-', date_format.mm, '-', date_format.dd])
          }, (context) {
            Provider.of<NavigatorProvider>(context, listen: false)
                .getNavigator(context, NavigatorType.defaultNavigator)
                ?.push(MaterialPageRoute(
                    builder: (context) => ComicDetailPage(
                          title: rawItem['name'],
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

class ZaiManHuaComicDetailModel extends BaseComicDetailModel {
  final Map rawData;
  final ZaiManHuaSourceModel sourceModel;

  bool _isSubscribe = false;

  ZaiManHuaComicDetailModel(this.rawData, this.sourceModel);

  @override
  Future<void> doInit() async {
    await super.doInit();
    _isSubscribe = await parent.accountModel!.getIfSubscribed(comicId);
  }

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
  List<CategoryEntity> get authors => rawData['data']['authors']
      .map<CategoryEntity>((e) =>
          CategoryEntity(e['tag_name'], e['tag_id'].toString(), (context) {
            Provider.of<NavigatorProvider>(context, listen: false)
                .getNavigator(context, NavigatorType.defaultNavigator)
                ?.push(MaterialPageRoute(
                    builder: (context) => ComicCategoryDetailPage(
                          categoryId: e['tag_id'].toString(),
                          sourceModel: parent,
                          categoryTitle: e['tag_name'],
                        ),
                    settings:
                        const RouteSettings(name: 'ComicCategoryDetailPage')));
          }))
      .toList();

  @override
  List<CategoryEntity> get categories => rawData['data']['types']
      .map<CategoryEntity>((e) =>
          CategoryEntity(e['tag_name'], e['tag_id'].toString(), (context) {
            Provider.of<NavigatorProvider>(context, listen: false)
                .getNavigator(context, NavigatorType.defaultNavigator)
                ?.push(MaterialPageRoute(
                    builder: (context) => ComicCategoryDetailPage(
                          categoryId: e['tag_id'].toString(),
                          sourceModel: parent,
                          categoryTitle: e['tag_name'],
                        ),
                    settings:
                        const RouteSettings(name: 'ComicCategoryDetailPage')));
          }))
      .toList();

  @override
  Map<String, List<BaseComicChapterEntityModel>> get chapters {
    Map<String, List<BaseComicChapterEntityModel>> result = {};
    for (var item in rawData['data']['chapters']) {
      result[item['title']] = item['data']
          .map<BaseComicChapterEntityModel>((e) =>
              DefaultComicChapterEntityModel(
                  e['chapter_title'],
                  e['chapter_id'].toString(),
                  DateTime.fromMillisecondsSinceEpoch(
                      e['updatetime'] != null ? e['updatetime'] * 1000 : 0)))
          .toList()
          .toList();
    }
    return result;
  }

  @override
  String get comicId => rawData['data']['id'].toString();

  @override
  ImageEntity get cover =>
      ImageEntity(ImageType.network, rawData['data']['cover']);

  @override
  String get description => rawData['data']['description'];

  @override
  Future<BaseComicChapterDetailModel?> getChapter(String chapterId) async {
    try {
      var response = await RequestHandlers.zaiManHuaMobileRequestHandler
          .getComicChapterDetail(comicId, chapterId);
      if ((response.statusCode == 200 || response.statusCode == 304)) {
        var rawData = response.data['data']['data'];
        return ZaiManHuaComicChapterDetailModel(rawData, this);
      }
    } catch (e, s) {
      logger.e('$e', error: e, stackTrace: s);
      rethrow;
    }
    return null;
  }

  @override
  Future<List<ComicCommentEntity>> getComments({int page = 0}) async {
    List<ComicCommentEntity> data = [];
    var response = await RequestHandlers.zaiManHuaMobileRequestHandler
        .getComments(comicId, page: page);
    try {
      if ((response.statusCode == 200 || response.statusCode == 304)) {
        for (String key in response.data['data']['commentIdList'] ?? []) {
          ComicCommentEntity? parent;
          var commentKeyList = key.split(',');
          for (var commentKey in commentKeyList) {
            var item = response.data['data']['commentList'][commentKey];
            var entity = ComicCommentEntity(
                ImageEntity(
                    item['photo'].toString().isNotEmpty
                        ? ImageType.network
                        : ImageType.unknown,
                    item['photo']),
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

  @override
  DateTime get lastUpdate => DateTime.fromMillisecondsSinceEpoch(
      rawData['data']['last_updatetime'] * 1000);

  @override
  BaseComicSourceModel get parent => sourceModel;

  @override
  String get status =>
      rawData['data']['status'].map((e) => e['tag_name']).join("/");

  @override
  String get title => rawData['data']['title'];
}

class ZaiManHuaComicChapterDetailModel extends BaseComicChapterDetailModel {
  final Map rawData;
  final ZaiManHuaComicDetailModel parent;

  ZaiManHuaComicChapterDetailModel(this.rawData, this.parent);

  @override
  String get chapterId => rawData['chapter_id'].toString();

  @override
  Future<List<ChapterCommentEntity>> getChapterComments() async {
    List<ChapterCommentEntity> data = [];
    try {
      var response = await RequestHandlers.zaiManHuaMobileRequestHandler
          .getViewpoint(parent.comicId, chapterId);
      if ((response.statusCode == 200 || response.statusCode == 304)) {
        if (response.data['data']['list'] != null) {
          List<dynamic> rawData = response.data['data']['list'];
          rawData.sort((a, b) => int.parse(b[1].toString()).compareTo(a[1]));
          for (var item in rawData) {
            data.add(
                ChapterCommentEntity(item[6].toString(), item[7], item[1]));
          }
        }
      }
    } catch (e, s) {
      logger.e('$e', error: e, stackTrace: s);
    }
    return data;
  }

  @override
  List<ImageEntity> get pages => rawData['page_url_hd']
      .map<ImageEntity>((e) => ImageEntity(ImageType.network, e))
      .toList();

  @override
  String get title => rawData['title'];
}
