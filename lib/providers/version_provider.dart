import 'package:dcomic/database/database_instance.dart';
import 'package:dcomic/database/entity/config.dart';
import 'package:dcomic/providers/base_provider.dart';
import 'package:dcomic/requests/base_request.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:version/version.dart';

enum UpdateChannel { release, beta, develop }

class ReleaseInfo {
  final String version;
  final String updateUrl;
  final String desc;
  final String releaseUrl;

  ReleaseInfo(this.version, this.updateUrl, this.desc, this.releaseUrl);
}

class VersionProvider extends BaseProvider {
  String _currentVersion = '2.0.0';
  ConfigEntity? _channelEntity;
  String _latestVersion = '';

  @override
  Future<void> init() async {
    PackageInfo packageInfo = await PackageInfo.fromPlatform();
    _currentVersion = packageInfo.version;
    final database = await DatabaseInstance.instance;
    _channelEntity = (await database.configDao
        .getOrCreateConfigByKey('UpdateChannel', value: UpdateChannel.develop));
    await checkUpdate();
    notifyListeners();
  }

  Future<bool> checkUpdate() async {
    var latestVersion = '';
    try{
      switch (channel) {
        case UpdateChannel.release:
          var response =
          await RequestHandlers.githubRequestHandler.getLatestRelease();
          if (response.statusCode == 200 || response.statusCode == 304) {
            latestVersion = response.data['tag_name'];
          }
          break;
        case UpdateChannel.develop:
          var response = await RequestHandlers.githubRequestHandler.getReleases();
          if (response.statusCode == 200 || response.statusCode == 304) {
            for (var release in response.data) {
              if (release['tag_name'].toString().contains('develop')) {
                latestVersion = release['tag_name'];
                break;
              }
            }
            if(latestVersion.isEmpty){
              latestVersion = response.data.first['tag_name'];
            }
          }
          break;
        case UpdateChannel.beta:
          var response = await RequestHandlers.githubRequestHandler.getReleases();
          if (response.statusCode == 200 || response.statusCode == 304) {
            for (var release in response.data) {
              if (release['tag_name'].toString().contains('beta')) {
                latestVersion = release['tag_name'];
                break;
              }
            }
            if(latestVersion.isEmpty){
              latestVersion = response.data.first['tag_name'];
            }
          }
          break;
      }
    }catch(e){
      return false;
    }
    if(latestVersion.isEmpty){
      return false;
    }
    _latestVersion = latestVersion;
    notifyListeners();
    Version latestVersionObject = Version.parse(latestVersion);
    Version currentVersionObject = Version.parse(currentVersion);
    return latestVersionObject > currentVersionObject;
  }

  Future<ReleaseInfo?> getLatestUpdateInfo() async{
    Map? data;
    try{
      switch (channel) {
        case UpdateChannel.release:
          var response =
          await RequestHandlers.githubRequestHandler.getLatestRelease();
          if (response.statusCode == 200 || response.statusCode == 304) {
            data = response.data;
          }
          break;
        case UpdateChannel.develop:
          var response = await RequestHandlers.githubRequestHandler.getReleases();
          if (response.statusCode == 200 || response.statusCode == 304) {
            for (var release in response.data) {
              if (release['tag_name'].toString().contains('develop')) {
                data = release;
                break;
              }
            }
            data ??= response.data.first;
          }
          break;
        case UpdateChannel.beta:
          var response = await RequestHandlers.githubRequestHandler.getReleases();
          if (response.statusCode == 200 || response.statusCode == 304) {
            for (var release in response.data) {
              if (release['tag_name'].toString().contains('beta')) {
                data = release;
                break;
              }
            }
            data ??= response.data.first;
          }
          break;
      }
    }catch(e){
      return null;
    }
    if(data == null){
      return null;
    }
    return ReleaseInfo(data['tag_name'], data['assets'][0]['browser_download_url'], data['body'], data['html_url']);
  }

  String get currentVersion => _currentVersion;

  String get latestVersion => _latestVersion.isEmpty?currentVersion:_latestVersion;

  UpdateChannel get channel {
    if (_channelEntity == null) {
      return UpdateChannel.release;
    }
    return UpdateChannel.values[(_channelEntity?.get<int>()) as int];
  }

  set channel(UpdateChannel value) {
    if (_channelEntity != null) {
      _channelEntity?.set(value);
      DatabaseInstance.instance
          .then((value) => value.configDao.updateConfig(_channelEntity!));
    }
    notifyListeners();
  }
}
