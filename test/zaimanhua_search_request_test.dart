import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dcomic/database/database_instance.dart';
import 'package:dcomic/requests/base_request.dart';
import 'package:dcomic/requests/zaimanhua/zaimanhua_request.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _TestPaths extends PathProviderPlatform {
  _TestPaths(this.path);

  final String path;

  @override
  Future<String?> getExternalStoragePath() async => path;

  @override
  Future<String?> getApplicationDocumentsPath() async => path;
}

class _RecordingAdapter implements HttpClientAdapter {
  RequestOptions? request;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? body,
    Future<void>? cancelFuture,
  ) async {
    request = options;
    return ResponseBody.fromString(
      jsonEncode({
        'errno': 0,
        'data': {'list': []},
      }),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory temporaryDirectory;
  late PathProviderPlatform originalPaths;
  late ZaiManHuaRequestHandler website;
  late ZaiManHuaMobileRequestHandler app;

  setUpAll(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'zaimanhua_search_request_',
    );
    originalPaths = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _TestPaths(temporaryDirectory.path);
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    await databaseFactory.setDatabasesPath(temporaryDirectory.path);
    await RequestStatics.store;

    website = ZaiManHuaRequestHandler();
    app = ZaiManHuaMobileRequestHandler();
    await Future<void>.delayed(Duration.zero);
    website.dio.interceptors.clear();
    app.dio.interceptors.clear();
  });

  tearDownAll(() async {
    website.dio.close(force: true);
    app.dio.close(force: true);
    await (await DatabaseInstance.instance).close();
    await (await RequestStatics.store).close();
    PathProviderPlatform.instance = originalPaths;
    await temporaryDirectory.delete(recursive: true);
  });

  test(
    'website search simplifies only Chinese text at the request boundary',
    () async {
      const input = '  灌籃高手 漫画 & # + ? ABC/100%  ';
      const simplified = '  灌篮高手 漫画 & # + ? ABC/100%  ';
      final adapter = _RecordingAdapter();
      website.dio.httpClientAdapter = adapter;

      await website.search(input, page: 2, limit: 17);

      final uri = adapter.request!.uri;
      expect(uri.path, '/app/v1/search/index');
      expect(uri.queryParameters['keyword'], simplified);
      expect(uri.queryParameters['source'], '0');
      expect(uri.queryParameters['page'], '3');
      expect(uri.queryParameters['size'], '17');
      expect(uri.queryParametersAll['keyword'], [simplified]);
    },
  );

  test(
    'app search simplifies outgoing keyword without changing paging',
    () async {
      const input = '  龍與地下城 漫画 & # + ? ABC/100%  ';
      const simplified = '  龙与地下城 漫画 & # + ? ABC/100%  ';
      final adapter = _RecordingAdapter();
      app.dio.httpClientAdapter = adapter;

      await app.search(input, page: 3, limit: 9);

      final uri = adapter.request!.uri;
      expect(uri.path, '/app/v1/search/index');
      expect(uri.queryParameters['keyword'], simplified);
      expect(uri.queryParameters['page'], '4');
      expect(uri.queryParameters['size'], '9');
      expect(uri.queryParametersAll['keyword'], [simplified]);
    },
  );
}
