import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dcomic/database/database_instance.dart';
import 'package:dcomic/providers/models/zaimanhua/zaimanhua_source_model.dart';
import 'package:dcomic/requests/base_request.dart';
import 'package:dio/dio.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'zaimanhua_api_test.dart' show ApiAdapter, TestPaths;

class _SignInAdapter extends ApiAdapter {
  _SignInAdapter(super.respond);

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? body,
      Future<void>? cancelFuture) async {
    if (options.method == 'POST') {
      expect(await utf8.decoder.bind(body!).join(), '_v=15');
    }
    return super.fetch(options, null, cancelFuture);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late final account = RequestHandlers.zaiManHuaAccountRequestHandler;
  late final tasks = RequestHandlers.zaiManHuaTaskRequestHandler;
  late Directory directory;
  late ZaiManHuaSourceModel source;
  late bool signedToday;
  late int signRequests;
  late int profileRequests;
  late Object? signFailure;
  late bool expired;
  late bool isMember;
  late int vipTaskStatus;
  late int taskRequests;
  late int rewardRequests;
  late Object? rewardFailure;
  late Object? taskFailure;

  Object respond(RequestOptions request) {
    if (request.uri.path == '/v1/login/passwd') {
      return {
        'errno': 0,
        'data': {
          'user': {'token': 'daily-token'}
        }
      };
    }
    if (request.uri.path == '/v1/u_center/personal/info/get') {
      profileRequests++;
      if (expired) {
        return {'errno': 401, 'errmsg': '登录已过期', 'data': {}};
      }
      return {
        'errno': 0,
        'data': {
          'personalInfo': {
            'uid': 123,
            'nickname': '签到读者',
            'photo': '',
            'is_sign': signedToday,
            'isMember': isMember,
          }
        }
      };
    }
    if (request.uri.path == '/lpi/v1/task/list' ||
        request.uri.path == '/lpi/v1/task/get_reward') {
      expect(request.method, 'GET');
      expect(request.headers['Authorization'], 'Bearer daily-token');
      expect(request.headers['Platform'], 'h5');
      expect(request.uri.queryParameters['_v'], '15');
      if (request.uri.path.endsWith('/list')) {
        taskRequests++;
        if (taskFailure is Exception) throw taskFailure!;
        if (taskFailure != null) return taskFailure!;
        return {
          'errno': 0,
          'data': {
            'task': {
              'dayTask': [
                {'id': 13, 'status': 2},
                {'id': 16, 'status': vipTaskStatus},
              ],
            },
          },
        };
      }
      expect(request.uri.queryParameters['task_id'], '16');
      rewardRequests++;
      if (rewardFailure is Exception) throw rewardFailure!;
      if (rewardFailure != null) return rewardFailure!;
      vipTaskStatus = 3;
      return {'errno': 0, 'errmsg': '', 'data': {}};
    }
    expect(
        request.uri.toString(), 'https://m.zaimanhua.com/lpi/v1/task/sign_in');
    expect(request.method, 'POST');
    expect(request.headers['Authorization'], 'Bearer daily-token');
    expect(request.headers['Platform'], 'h5');
    expect(request.contentType, Headers.formUrlEncodedContentType);
    signRequests++;
    if (signFailure is Exception) throw signFailure!;
    if (signFailure != null) return signFailure!;
    signedToday = true;
    return {'errno': 0, 'errmsg': '', 'data': {}};
  }

  setUpAll(() async {
    directory = await Directory.systemTemp.createTemp('zaimanhua_check_in_');
    PathProviderPlatform.instance = TestPaths(directory.path);
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    await databaseFactory.setDatabasesPath(directory.path);
    await RequestStatics.store;
    tasks.dio.interceptors.clear();
    tasks.dio.httpClientAdapter = _SignInAdapter(respond);
    account.dio.httpClientAdapter = ApiAdapter(respond);
  });

  setUp(() async {
    await (await DatabaseInstance.instance)
        .database
        .delete('ModelConfigEntity');
    source = ZaiManHuaSourceModel();
    final model = source.accountModel as ZaiManHuaAccountModel;
    model.parent = source;
    model.logger = Logger(output: ConsoleOutput());
    signedToday = false;
    signRequests = 0;
    profileRequests = 0;
    signFailure = null;
    expired = false;
    isMember = false;
    vipTaskStatus = 2;
    taskRequests = 0;
    rewardRequests = 0;
    rewardFailure = null;
    taskFailure = null;
    account.dio.interceptors.clear();
    account.dio.interceptors.add(DioCacheInterceptor(
        options: CacheOptions(
            store: MemCacheStore(), policy: CachePolicy.forceCache)));
    tasks.dio.interceptors.clear();
    tasks.dio.interceptors.add(DioCacheInterceptor(
        options: CacheOptions(
            store: MemCacheStore(), policy: CachePolicy.forceCache)));
  });

  tearDownAll(() async {
    account.dio.close(force: true);
    tasks.dio.close(force: true);
    await (await DatabaseInstance.instance).close();
    await (await RequestStatics.store).close();
    await directory.delete(recursive: true);
  });

  test('VIP daily reward is claimed even when ordinary check-in is complete',
      () async {
    isMember = true;
    signedToday = true;
    await source.accountModel!.loginWithToken('daily-token');
    expect(vipTaskStatus, 3);
    expect(rewardRequests, 1);
    expect(signRequests, 0);
    final model = source.accountModel as ZaiManHuaAccountModel;
    expect(model.isMember, isTrue);
    expect(model.vipRewardStatus, ZaiManHuaVipRewardStatus.claimed);
    await source.initModel();
    expect(rewardRequests, 1);
    // Neither the task list nor the mutating GET may reuse yesterday's cache.
    vipTaskStatus = 2;
    await source.initModel();
    expect(vipTaskStatus, 3);
    expect(rewardRequests, 2);
  });

  test('disabling auto check-in prevents both daily actions', () async {
    isMember = true;
    final dao = (await DatabaseInstance.instance).modelConfigDao;
    await dao.getOrCreateConfigByKey('autoSignInEnabled', 'zaimanhua',
        value: false);
    await source.accountModel!.loginWithToken('daily-token');
    expect(signRequests, 0);
    expect(rewardRequests, 0);
    expect(taskRequests, 1);
    expect((source.accountModel as ZaiManHuaAccountModel).vipRewardStatus,
        ZaiManHuaVipRewardStatus.claimable);
  });

  test('ordinary check-in failure does not block the independent VIP reward',
      () async {
    isMember = true;
    signFailure = {'errno': 500, 'errmsg': '服务繁忙', 'data': {}};
    await source.accountModel!.loginWithToken('daily-token');
    expect(vipTaskStatus, 3);
    expect(source.accountModel!.isLogin, isTrue);
  });

  test('non-members never query or claim the VIP task', () async {
    await source.accountModel!.loginWithToken('daily-token');
    expect(signedToday, isTrue);
    expect(taskRequests, 0);
    expect(rewardRequests, 0);
    final model = source.accountModel as ZaiManHuaAccountModel;
    expect(model.isMember, isFalse);
    expect(model.vipRewardStatus, ZaiManHuaVipRewardStatus.notMember);
  });

  test('VIP task that is not claimable is not claimed', () async {
    isMember = true;
    vipTaskStatus = 1;
    await source.accountModel!.loginWithToken('daily-token');
    expect(taskRequests, 1);
    expect(rewardRequests, 0);
  });

  test('VIP status refresh does not claim the next day reward', () async {
    isMember = true;
    vipTaskStatus = 3;
    await source.accountModel!.loginWithToken('daily-token');
    vipTaskStatus = 2;
    await (source.accountModel as ZaiManHuaAccountModel).refreshSignInStatus();
    expect(taskRequests, 2);
    expect(rewardRequests, 0);
    expect(vipTaskStatus, 2);
  });

  test('VIP reward failure preserves ordinary check-in and permits next login',
      () async {
    isMember = true;
    rewardFailure = {'errno': 500, 'errmsg': '服务繁忙', 'data': {}};
    await source.accountModel!.loginWithToken('daily-token');
    expect(rewardRequests, 1);
    expect(vipTaskStatus, 2);
    expect(signedToday, isTrue);
    expect(source.accountModel!.isLogin, isTrue);
    expect((source.accountModel as ZaiManHuaAccountModel).vipRewardStatus,
        ZaiManHuaVipRewardStatus.claimFailed);
    rewardFailure = null;
    await source.accountModel!.initAccount();
    expect(vipTaskStatus, 3);
  });

  test('VIP task lookup failure preserves ordinary check-in status', () async {
    isMember = true;
    taskFailure = const SocketException('offline');
    await source.accountModel!.loginWithToken('daily-token');
    final model = source.accountModel as ZaiManHuaAccountModel;
    expect(model.isLogin, isTrue);
    expect(model.signInStatus, ZaiManHuaSignInStatus.signedIn);
    expect(model.vipRewardStatus, ZaiManHuaVipRewardStatus.queryFailed);
    expect(rewardRequests, 0);
  });

  test('VIP reward state is cleared on logout', () async {
    isMember = true;
    await source.accountModel!.loginWithToken('daily-token');
    final model = source.accountModel as ZaiManHuaAccountModel;
    expect(model.vipRewardStatus, ZaiManHuaVipRewardStatus.claimed);
    await model.logout();
    expect(model.isMember, isNull);
    expect(model.vipRewardStatus, ZaiManHuaVipRewardStatus.notLoggedIn);
  });

  test('disabled auto check-in survives login and a restored session',
      () async {
    final dao = (await DatabaseInstance.instance).modelConfigDao;
    await dao.getOrCreateConfigByKey('autoSignInEnabled', 'zaimanhua',
        value: false);
    await source.accountModel!.loginWithToken('daily-token');
    expect(source.accountModel!.isLogin, isTrue);
    expect(signRequests, 0);
    final reopened = ZaiManHuaSourceModel();
    reopened.accountModel!.logger = Logger(output: ConsoleOutput());
    await reopened.initModel();
    expect(reopened.accountModel!.isLogin, isTrue);
    expect(signRequests, 0);
  });

  test('re-enabling check-in signs in and persists the new choice', () async {
    await source.initModel();
    final model = source.accountModel as ZaiManHuaAccountModel;
    await model.setAutoSignInEnabled(false);
    await model.loginWithToken('daily-token');
    expect(signRequests, 0);
    expect(model.signInStatus, ZaiManHuaSignInStatus.notSignedIn);
    await model.setAutoSignInEnabled(true);
    expect(signedToday, isTrue);
    expect(model.signInStatus, ZaiManHuaSignInStatus.signedIn);
    final reopened = ZaiManHuaSourceModel();
    await reopened.initModel();
    expect((reopened.accountModel as ZaiManHuaAccountModel).autoSignInEnabled,
        isTrue);
    expect(signRequests, 1);
  });

  test('status refresh sees a new day without performing automatic check-in',
      () async {
    final model = source.accountModel as ZaiManHuaAccountModel;
    await model.loginWithToken('daily-token');
    expect(model.signInStatus, ZaiManHuaSignInStatus.signedIn);
    signedToday = false;
    await model.refreshSignInStatus();
    expect(model.signInStatus, ZaiManHuaSignInStatus.notSignedIn);
    expect(signRequests, 1);
    signedToday = true;
    await model.refreshSignInStatus();
    expect(model.signInStatus, ZaiManHuaSignInStatus.signedIn);
    expect(signRequests, 1);
  });

  test('failed status refresh does not display a stale successful check-in',
      () async {
    final model = source.accountModel as ZaiManHuaAccountModel;
    await model.loginWithToken('daily-token');
    account.dio.httpClientAdapter =
        ApiAdapter((_) => throw const SocketException('offline'));
    try {
      await model.refreshSignInStatus();
      expect(model.signInStatus, ZaiManHuaSignInStatus.queryFailed);
      expect(model.isLogin, isTrue);
    } finally {
      account.dio.httpClientAdapter = ApiAdapter(respond);
    }
  });

  test('password login completes the daily check-in', () async {
    expect(await source.accountModel!.login('reader', 'password'), isTrue);
    expect(signedToday, isTrue);
    expect(signRequests, 1);
    expect(source.accountModel!.isLogin, isTrue);
  });

  test('restored session checks in next day without repeating today', () async {
    await source.accountModel!.loginWithToken('daily-token');
    expect(signedToday, isTrue);
    await source.initModel();
    expect(signRequests, 1);

    // The service day changes; the same persisted login is still valid.
    signedToday = false;
    final reopened = ZaiManHuaSourceModel();
    reopened.accountModel!.logger = Logger(output: ConsoleOutput());
    await reopened.initModel();
    expect(signedToday, isTrue);
    expect(signRequests, 2);
    expect(profileRequests, 3);
  });

  test('already signed-in profile skips the sign-in endpoint', () async {
    signedToday = true;
    await source.accountModel!.loginWithToken('daily-token');
    expect(source.accountModel!.isLogin, isTrue);
    expect(signRequests, 0);
  });

  test('sign-in rejection preserves login and permits a later attempt',
      () async {
    signFailure = {'errno': 500, 'errmsg': '服务繁忙', 'data': {}};
    await source.accountModel!.loginWithToken('daily-token');
    expect(signRequests, 1);
    expect(signedToday, isFalse);
    expect(source.accountModel!.isLogin, isTrue);
    expect(source.accountModel!.nickname, '签到读者');
    expect((source.accountModel as ZaiManHuaAccountModel).signInStatus,
        ZaiManHuaSignInStatus.signInFailed);
    signFailure = null;
    await source.accountModel!.initAccount();
    expect(signedToday, isTrue);
    expect(signRequests, 2);
  });

  test('sign-in network failure does not invalidate the account', () async {
    signFailure = const SocketException('offline');
    await source.accountModel!.loginWithToken('daily-token');
    expect(signRequests, 1);
    expect(source.accountModel!.isLogin, isTrue);
  });

  test('captured already-signed response preserves the account', () async {
    signFailure = {'errno': 1, 'errmsg': '今天已签到过~', 'data': {}};
    await source.accountModel!.loginWithToken('daily-token');
    expect(signRequests, 1);
    expect(source.accountModel!.isLogin, isTrue);
    expect((source.accountModel as ZaiManHuaAccountModel).signInStatus,
        ZaiManHuaSignInStatus.signedIn);
  });

  test('logout with a retained token performs no account or sign-in request',
      () async {
    signedToday = true;
    await source.accountModel!.loginWithToken('daily-token');
    profileRequests = 0;
    await source.accountModel!.logout();
    expect(source.accountModel!.isLogin, isFalse);
    expect(profileRequests, 0);
    expect(signRequests, 0);
    expect((source.accountModel as ZaiManHuaAccountModel).signInStatus,
        ZaiManHuaSignInStatus.notLoggedIn);
  });

  test('expired login never triggers check-in', () async {
    expired = true;
    await source.accountModel!.loginWithToken('daily-token');
    expect(source.accountModel!.isLogin, isFalse);
    expect(signRequests, 0);
  });
}
