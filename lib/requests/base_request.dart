import 'dart:io';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dcomic/requests/copymanga/copymanga_request.dart';
import 'package:dcomic/requests/dmzj/dmzj_request.dart';
import 'package:dcomic/requests/github/github_request.dart';
import 'package:dcomic/requests/zaimanhua/zaimanhua_request.dart';
import 'package:dcomic/utils/db_cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http_cache_drift_store/http_cache_drift_store.dart';

import '../utils/firbaselogoutput.dart';

class RequestStatics {
  static DriftCacheStore? _store;

  static Future<DriftCacheStore> get store async {
    if (_store == null) {
      Directory? value;

      if (Platform.isIOS) {
        value = await getApplicationDocumentsDirectory();
      } else {
        value = await getExternalStorageDirectory();
      }

      _store = DriftCacheStore(databasePath: '${value?.path}/cache/dio');
    }
    return _store!;
  }
}

class RequestHandler {
  Dio dio = Dio();
  CookieManager cookieManager=CookieManager(PersistCookieJar(
      ignoreExpires: true, storage: DatabaseCookieJarStorage()));

  CacheOptions? options;
  final String baseUrl;
  Logger logger = Logger(
      printer: PrettyPrinter(noBoxingByDefault: true,methodCount:2),
      filter: ProductionFilter(),
      output: CrashConsoleOutput());

  RequestHandler(this.baseUrl, {CachePolicy policy= CachePolicy.request,bool useCookie=true}) {
    dio.options.baseUrl = baseUrl;
    RequestStatics.store.then((value) {
      options = CacheOptions(
        store: value,
        // Required.
        policy: policy,
        // Default. Checks cache freshness, requests otherwise and caches response.
        hitCacheOnErrorCodes: [401, 403, 404],
        // Optional. Returns a cached response on error if available but for statuses 401 & 403.
        priority: CachePriority.normal,
        // Optional. Default. Allows 3 cache sets and ease cleanup.
        maxStale: const Duration(days: 7),
        // Very optional. Overrides any HTTP directive to delete entry past this duration.
        keyBuilder: CacheOptions.defaultCacheKeyBuilder,
        hitCacheOnNetworkFailure: true,
      );
      if(useCookie){
        dio.interceptors.add(cookieManager);
      }
      dio.interceptors.add(DioCacheInterceptor(options: options!));
    });
  }

  Future<bool> clearCache() async {
    await (await RequestStatics.store).clean();
    return true;
  }

  Future<bool> clearExpired() async {
    await (await RequestStatics.store).clean(staleOnly: true);
    return true;
  }

  Future<int> ping({String path = '/'}) async {
    DateTime now = DateTime.now();
    try {
      await dio.get(path);
      return DateTime.now().millisecondsSinceEpoch - now.millisecondsSinceEpoch;
    } catch (e) {
      rethrow;
    }
    return -1;
  }
}

class RequestHandlers{
  static DMZJV3RequestHandler dmzjv3requestHandler=DMZJV3RequestHandler();
  static DMZJV4RequestHandler dmzjv4requestHandler=DMZJV4RequestHandler();
  static DMZJUserRequestHandler dmzjUserRequestHandler=DMZJUserRequestHandler();
  static DMZJCommentRequestHandler dmzjCommentRequestHandler=DMZJCommentRequestHandler();
  static DMZJInterfaceRequestHandler dmzjInterfaceRequestHandler=DMZJInterfaceRequestHandler();

  static CopyMangaRequestHandler copyMangaRequestHandler=CopyMangaRequestHandler();

  static ZaiManHuaRequestHandler zaiManHuaRequestHandler=ZaiManHuaRequestHandler();
  static ZaiManHuaMobileRequestHandler zaiManHuaMobileRequestHandler=ZaiManHuaMobileRequestHandler();
  static ZaiManHuaAccountRequestHandler zaiManHuaAccountRequestHandler=ZaiManHuaAccountRequestHandler();

  static GithubRequestHandler githubRequestHandler=GithubRequestHandler();
}