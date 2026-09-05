import 'dart:io';

import 'package:dcomic/requests/base_request.dart';
import 'package:dcomic/requests/github/github_request.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

class _TestPaths extends PathProviderPlatform {
  final String path;
  _TestPaths(this.path);

  @override
  Future<String?> getExternalStoragePath() async => path;

  @override
  Future<String?> getApplicationDocumentsPath() async => path;
}

void main() {
  test('update request times out when the server never sends a response',
      () async {
    final directory = await Directory.systemTemp.createTemp('github_timeout_');
    final originalPaths = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _TestPaths(directory.path);
    final store = await RequestStatics.store;
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final subscription = server.listen((request) {
      // Accept the request, but never send response headers.
    });
    final handler = GithubRequestHandler();
    await Future<void>.delayed(Duration.zero);
    handler.dio.interceptors.clear();
    handler.dio.options.baseUrl = 'http://127.0.0.1:${server.port}';

    try {
      await expectLater(
        handler.getReleases().timeout(const Duration(seconds: 7)),
        throwsA(isA<DioException>().having(
          (error) => error.type,
          'type',
          DioExceptionType.receiveTimeout,
        )),
      );
    } finally {
      handler.dio.close(force: true);
      await subscription.cancel();
      await server.close(force: true);
      await store.close();
      PathProviderPlatform.instance = originalPaths;
      await directory.delete(recursive: true);
    }
  });
}
