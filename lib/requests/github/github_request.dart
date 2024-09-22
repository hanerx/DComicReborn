import 'package:dcomic/requests/base_request.dart';
import 'package:dio/dio.dart';

class GithubRequestHandler extends RequestHandler {
  GithubRequestHandler():super('https://api.github.com');

  Future<Response> getReleases() {
    return dio.get('/repos/hanerx/DComicReborn/releases');
  }

  Future<Response> getLatestRelease() {
    return dio.get('/repos/hanerx/DComicReborn/releases/latest');
  }
}