import 'package:dcomic/database/database_instance.dart';
import 'package:dcomic/database/entity/config.dart';
import 'package:dcomic/providers/base_provider.dart';
import 'package:dcomic/requests/base_request.dart';
import 'package:flutter/material.dart';
import 'package:flutter/src/widgets/framework.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher_string.dart' as url_string_launcher;
import 'package:version/version.dart';

import '../generated/l10n.dart';

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
  ConfigEntity? _lastTimeCheckVersion;
  bool _needShowUpdateDialog = false;
  bool isLoading = true;
  bool isUpdateDialogShown = false;

  @override
  Future<void> init() async {
    PackageInfo packageInfo = await PackageInfo.fromPlatform();
    _currentVersion = packageInfo.version;
    final database = await DatabaseInstance.instance;
    _channelEntity = (await database.configDao
        .getOrCreateConfigByKey('UpdateChannel', value: UpdateChannel.develop));
    _lastTimeCheckVersion = await database.configDao.getOrCreateConfigByKey('UpdateChannel', value: '');
    if(await checkUpdate()){
      ReleaseInfo? releaseInfo = await getLatestUpdateInfo();
      if(releaseInfo != null && _lastTimeCheckVersion != null) {
        if(releaseInfo.version != _lastTimeCheckVersion!.get<String>()) {
          _needShowUpdateDialog = true;
          _lastTimeCheckVersion?.set(releaseInfo.version);
          await database.configDao.updateConfig(_lastTimeCheckVersion!);
        } else {
          _needShowUpdateDialog = false;
        }
      }
    }
    isLoading = false;
    notifyListeners();
  }

  Future<bool> checkUpdate() async {
    var latestVersion = '';
    try {
      switch (channel) {
        case UpdateChannel.release:
          // 只选择最近的release（非pre-release）
          var response = await RequestHandlers.githubRequestHandler.getReleases();
          if (response.statusCode == 200 || response.statusCode == 304) {
            var releases = response.data.where((r) => r['prerelease'] == false).toList();
            if (releases.isNotEmpty) {
              latestVersion = releases.first['tag_name'];
            }
          }
          break;
        case UpdateChannel.develop:
          // release和pre-release都可选，优先选择版本号高的
          var response = await RequestHandlers.githubRequestHandler.getReleases();
          if (response.statusCode == 200 || response.statusCode == 304) {
            var releases = response.data;
            if (releases.isNotEmpty) {
              var release = releases.firstWhere((r) => r['prerelease'] == false, orElse: () => null);
              var preRelease = releases.firstWhere((r) => r['prerelease'] == true, orElse: () => null);
              Version? releaseVersion = release != null ? Version.parse(release['tag_name'].toString().replaceAll(RegExp(r'[^0-9\\.]'), '')) : null;
              Version? preReleaseVersion = preRelease != null ? Version.parse(preRelease['tag_name'].toString().replaceAll(RegExp(r'[^0-9\\.]'), '')) : null;
              if (releaseVersion != null && preReleaseVersion != null) {
                latestVersion = (releaseVersion > preReleaseVersion ? release : preRelease)['tag_name'];
              } else {
                latestVersion = (release ?? preRelease)?['tag_name'] ?? '';
              }
            }
          }
          break;
        case UpdateChannel.beta:
          // beta分支暂不处理，直接返回false
          return false;
      }
    } catch (e) {
      return false;
    }
    if (latestVersion.isEmpty) {
      return false;
    }
    _latestVersion = latestVersion;
    notifyListeners();
    Version latestVersionObject = Version.parse(latestVersion);
    Version currentVersionObject = Version.parse(currentVersion);
    return latestVersionObject > currentVersionObject;
  }

  Future<ReleaseInfo?> getLatestUpdateInfo() async {
    Map? data;
    try {
      switch (channel) {
        case UpdateChannel.release:
          // 只选择最近的release（非pre-release）
          var response = await RequestHandlers.githubRequestHandler.getReleases();
          if (response.statusCode == 200 || response.statusCode == 304) {
            var releases = response.data.where((r) => r['prerelease'] == false).toList();
            if (releases.isNotEmpty) {
              data = releases.first;
            }
          }
          break;
        case UpdateChannel.develop:
          // 不过滤pre-release，release和pre-release都可选，优先选择版本号高的
          var response = await RequestHandlers.githubRequestHandler.getReleases();
          if (response.statusCode == 200 || response.statusCode == 304) {
            var releases = response.data;
            if (releases.isNotEmpty) {
              // 找到最高版本的release和pre-release
              var release = releases.firstWhere((r) => r['prerelease'] == false, orElse: () => null);
              var preRelease = releases.firstWhere((r) => r['prerelease'] == true, orElse: () => null);
              Version? releaseVersion = release != null ? Version.parse(release['tag_name'].toString().replaceAll(RegExp(r'[^0-9\.]'), '')) : null;
              Version? preReleaseVersion = preRelease != null ? Version.parse(preRelease['tag_name'].toString().replaceAll(RegExp(r'[^0-9\.]'), '')) : null;
              if (releaseVersion != null && preReleaseVersion != null) {
                data = releaseVersion > preReleaseVersion ? release : preRelease;
              } else {
                data = release ?? preRelease;
              }
            }
          }
          break;
        case UpdateChannel.beta:
          // beta分支暂不处理，直接返回null
          return null;
      }
    } catch (e) {
      return null;
    }
    if (data == null) {
      return null;
    }
    return ReleaseInfo(
      data['tag_name'],
      data['assets'] != null && data['assets'].isNotEmpty ? data['assets'][0]['browser_download_url'] : '',
      data['body'] ?? '',
      data['html_url'] ?? '',
    );
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

  bool get needShowUpdateDialog => _needShowUpdateDialog;

  void tryShowUpdateDialog(BuildContext context) {
    if (isUpdateDialogShown) return;
    isUpdateDialogShown = true;
    notifyListeners();
    showReleaseInfo(context);
  }

  Future<void> showReleaseInfo(BuildContext context) async {
    ReleaseInfo? releaseInfo = await getLatestUpdateInfo();
    if (releaseInfo != null) {
      if (context.mounted) {
        showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title:
              Text(S.of(context).ReleaseInfoTitle(releaseInfo.version)),
              content: Text(releaseInfo.desc),
              actions: [
                TextButton(
                    onPressed: () async {
                      if (await url_string_launcher
                          .canLaunchUrlString(releaseInfo.releaseUrl)) {
                        if (context.mounted) {
                          url_string_launcher
                              .launchUrlString(releaseInfo.releaseUrl);
                        }
                      }
                    },
                    child: Text(S.of(context).AboutPageGithub)),
                TextButton(
                    onPressed: () async {
                      if (await url_string_launcher
                          .canLaunchUrlString(releaseInfo.updateUrl)) {
                        if (context.mounted) {
                          url_string_launcher
                              .launchUrlString(releaseInfo.updateUrl);
                        }
                      }
                    },
                    child: Text(S.of(context).ReleaseInfoDownload))
              ],
            ));
      }
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(S.of(context).SettingPageFailToGetReleaseInfo)));
      }
    }
  }
}

