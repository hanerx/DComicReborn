import 'dart:io';

import 'package:dcomic/database/database_instance.dart';
import 'package:dcomic/database/entity/config.dart';
import 'package:dcomic/providers/base_provider.dart';
import 'package:dcomic/providers/download_provider.dart';
import 'package:dcomic/requests/base_request.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher_string.dart' as url_string_launcher;
import 'package:version/version.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';

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
    // 根据平台选择合适的安装包
    String updateUrl = '';
    if (data['assets'] != null && data['assets'].isNotEmpty) {
      if (Platform.isAndroid) {
        var apk = data['assets'].firstWhere(
            (a) => a['name'] != null && a['name'].toString().endsWith('.apk'),
            orElse: () => null);
        updateUrl = apk != null ? apk['browser_download_url'] : '';
      } else if (Platform.isIOS) {
        var ipa = data['assets'].firstWhere(
            (a) => a['name'] != null && a['name'].toString().endsWith('.ipa'),
            orElse: () => null);
        updateUrl = ipa != null ? ipa['browser_download_url'] : '';
      }
    }
    return ReleaseInfo(
      data['tag_name'],
      updateUrl,
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
                      Navigator.of(context).pop();
                      if (releaseInfo.updateUrl.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(S.of(context).ReleaseInfoNoApkOrIpa)));
                        return;
                      }
                      // 初始化下载器
                      final dir = Platform.isAndroid
                          ? await getExternalStorageDirectory()
                          : await getApplicationDocumentsDirectory();
                      if (dir == null) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(S.of(context).ReleaseInfoDownloadFailed)));
                        }
                        return;
                      }
                      final filePath = '${dir.path}/app${Platform.isAndroid ? '.apk' : '.ipa'}';
                      if(await File(filePath).exists()) {
                        File(filePath).deleteSync();
                      }
                      final taskId = await FlutterDownloader.enqueue(
                        url: releaseInfo.updateUrl,
                        savedDir: dir.path,
                        showNotification: true,
                        openFileFromNotification: true,
                        fileName: 'app${Platform.isAndroid ? '.apk' : '.ipa'}',
                      );
                      if (taskId == null) {
                        if(context.mounted){
                          ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(S.of(context).ReleaseInfoDownloadFailed)));
                        }
                      }else{
                        if (context.mounted){
                          Provider.of<DownloadProvider>(context, listen: false)
                              .registerDownloadCallback(taskId,
                                  (id, status, progress) async {
                            if (status == DownloadTaskStatus.complete){
                              await FlutterDownloader.open(taskId: id);
                            }else if (status == DownloadTaskStatus.failed) {
                              if (context.mounted){
                                ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(S.of(context).ReleaseInfoDownloadFailed)));
                              }
                            }
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(S.of(context).ReleaseInfoDownloadStarted)));
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

