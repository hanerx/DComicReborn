import 'dart:io';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:dio_cache_interceptor_db_store/dio_cache_interceptor_db_store.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:firebase_performance/firebase_performance.dart';
import 'package:path_provider/path_provider.dart';

class CacheDatabase {
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

class PerformanceInterceptor extends DioCacheInterceptor {
  HttpMetric? metric;

  PerformanceInterceptor({required CacheOptions options})
      : super(options: options);

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    var method = HttpMethod.Get;
    switch (options.method.toUpperCase()) {
      case "GET":
        method = HttpMethod.Get;
        break;
      case "POST":
        method = HttpMethod.Post;
        break;
      case "PUT":
        method = HttpMethod.Put;
        break;
      case "DELETE":
        method = HttpMethod.Delete;
        break;
      case "OPTIONS":
        method=HttpMethod.Options;
        break;
    }
    metric = FirebasePerformance.instance
        .newHttpMetric(options.uri.toString(), method);
    metric?.start();
    super.onRequest(options, handler);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    super.onResponse(response, handler);
    metric?.responseContentType = response.headers['Content-Type'] as String?;
    metric?.httpResponseCode = response.statusCode;
    metric?.responsePayloadSize =
        response.headers.value('Content-Length') == null
            ? 0
            : int.tryParse(response.headers.value('Content-Length')!);
    metric?.stop();
  }

  @override
  void onError(DioError err, ErrorInterceptorHandler handler) {
    super.onError(err, handler);
    metric?.responsePayloadSize =
        err.response?.headers.value('Content-Length') == null
            ? 0
            : int.tryParse((err.response!).headers.value('Content-Length')!);
    metric?.responseContentType = err.response?.headers.value('Content-Type');
    metric?.httpResponseCode = err.response?.statusCode;
    metric?.stop();
  }
}

class RequestHandler {
  Dio dio = Dio();
  CookieJar cookieJar=PersistCookieJar();

  CacheOptions? options;
  final String baseUrl;

  RequestHandler(this.baseUrl, {CachePolicy policy: CachePolicy.request}) {
    dio.options.baseUrl = baseUrl;
    CacheDatabase.store.then((value) {
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
      dio.interceptors.add(PerformanceInterceptor(options: options!));
      dio.interceptors.add(CookieManager(cookieJar));
    });
  }

  Future<bool> clearCache() async {
    await (await CacheDatabase.store).clean();
    return true;
  }

  Future<bool> clearExpired() async {
    await (await CacheDatabase.store).clean(staleOnly: true);
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
