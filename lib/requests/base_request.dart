import 'dart:io';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dcomic/requests/copymanga/copymanga_request.dart';
import 'package:dcomic/requests/dmzj/dmzj_request.dart';
import 'package:dcomic/utils/db_cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:dio_cache_interceptor_db_store/dio_cache_interceptor_db_store.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:path_provider/path_provider.dart';

class RequestStatics {
  static DbCacheStore? _store;

  static Future<DbCacheStore> get store async {
    if (_store == null) {
      Directory? value;

      if (Platform.isIOS) {
        value = await getApplicationDocumentsDirectory();
      } else {
        value = await getExternalStorageDirectory();
      }

      _store = DbCacheStore(databasePath: '${value?.path}/cache/dio');
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

  RequestHandler(this.baseUrl, {CachePolicy policy= CachePolicy.request,bool useCookie=true}) {
    dio.options.baseUrl = baseUrl;
    RequestStatics.store.then((value) {
      options = CacheOptions(
        store: value,
        // Required.
        policy: policy,
        // Default. Checks cache freshness, requests otherwise and caches response.
        hitCacheOnErrorExcept: [401, 403],
        // Optional. Returns a cached response on error if available but for statuses 401 & 403.
        priority: CachePriority.normal,
        // Optional. Default. Allows 3 cache sets and ease cleanup.
        maxStale: const Duration(days: 7),
        // Very optional. Overrides any HTTP directive to delete entry past this duration.
        keyBuilder: CacheOptions.defaultCacheKeyBuilder,
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

  Future<int> ping({String path: '/'}) async {
    DateTime now = DateTime.now();
    try {
      await dio.get(path);
      return DateTime.now().millisecondsSinceEpoch - now.millisecondsSinceEpoch;
    } catch (e) {}
    return -1;
  }
}

class RequestHandlers{
  static DMZJV3RequestHandler dmzjv3requestHandler=DMZJV3RequestHandler();
  static DMZJV4RequestHandler dmzjv4requestHandler=DMZJV4RequestHandler();
  static DMZJUserRequestHandler dmzjUserRequestHandler=DMZJUserRequestHandler();
  static DMZJCommentRequestHandler dmzjCommentRequestHandler=DMZJCommentRequestHandler();

  static CopyMangaRequestHandler copyMangaRequestHandler=CopyMangaRequestHandler();
}