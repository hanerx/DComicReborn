import 'package:dcomic/database/database_instance.dart';
import 'package:dcomic/database/entity/comic_history.dart';
import 'package:dcomic/generated/l10n.dart';
import 'package:dcomic/providers/models/comic_source_model.dart';
import 'package:dcomic/providers/navigator_provider.dart';
import 'package:dcomic/requests/base_request.dart';
import 'package:dcomic/utils/image_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/src/widgets/framework.dart';
import 'package:fluttericon/font_awesome5_icons.dart';
import 'package:provider/provider.dart';

class CopyMangaComicSourceModel extends BaseComicSourceModel {
  final CopyMangaAccountModel _accountModel = CopyMangaAccountModel();

  @override
  ComicSourceEntity get type =>
      ComicSourceEntity("拷贝漫画", "copymanga", hasAccountSupport: true);

  @override
  Future<BaseComicDetailModel?> getComicDetail(String comicId, String title) {
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
  Future<void> init() async {
    _accountModel.parent ??= this;
    return super.init();
  }

  @override
  BaseComicAccountModel? get accountModel => _accountModel;
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
  Future<bool> getIfSubscribed(String comicId) {
    // TODO: implement getIfSubscribed
    throw UnimplementedError();
  }

  @override
  Future<List<GridItemEntity>> getSubscribeComics({int page = 0}) {
    // TODO: implement getSubscribeComics
    throw UnimplementedError();
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
  Future<bool> logout()async {
    _isLogin=false;
    await RequestHandlers.copyMangaRequestHandler.logout();
    notifyListeners();
    return true;
  }

  @override
  String? get nickname => _nickname;

  @override
  Future<bool> subscribeComic(String comicId) {
    // TODO: implement subscribeComic
    throw UnimplementedError();
  }

  @override
  String? get uid => _uid;

  @override
  Future<bool> unsubscribeComic(String comicId) {
    // TODO: implement unsubscribeComic
    throw UnimplementedError();
  }

  @override
  String? get username => _username;

  @override
  Future<void> init() async{
    var databaseInstance = await DatabaseInstance.instance;
    var databaseIsLogin = (await databaseInstance.modelConfigDao
        .getOrCreateConfigByKey('isLogin', parent!.type.sourceId));
    _isLogin = databaseIsLogin.get<bool>() ?? false;
    if(_isLogin){
      var response=await RequestHandlers.copyMangaRequestHandler.getUserInfo();
      if(response.statusCode==200){
        var data=response.data['results'];
        _uid=data['user_id'];
        _nickname=data['nickname'];
        _username=data['username'];
        _avatar = ImageEntity(ImageType.network,
            data['avatar'],
            imageHeaders: {"Referer": "https://www.copymanga.site/"});
      }
    }
    _isLoading=false;
    notifyListeners();
  }

  @override
  bool get isLoading => _isLoading;

  @override
  bool get isLogin => _isLogin;
}
