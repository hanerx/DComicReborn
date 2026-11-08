import 'package:dcomic/database/database_instance.dart';
import 'package:dcomic/database/entity/config.dart';
import 'package:dcomic/downloads/update_download.dart';
import 'package:dcomic/providers/base_provider.dart';
import 'package:dcomic/providers/navigator_provider.dart';
import 'package:dcomic/requests/base_request.dart';
import 'package:dcomic/view/drawer_page/download_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher_string.dart' as url_string_launcher;
import 'package:version/version.dart';

import '../generated/l10n.dart';


enum UpdateChannel { release, beta, develop }


class VersionProvider extends BaseProvider {
  String _currentVersion = '2.0.0';
  ConfigEntity? _channelEntity;
  String _latestVersion = '';
  ConfigEntity? _lastTimeCheckVersion;
  bool _needShowUpdateDialog = false;
  bool isUpdateDialogShown = false;

  @override
  Future<void> init() async {
    PackageInfo packageInfo = await PackageInfo.fromPlatform();
    _currentVersion = packageInfo.version;
    final database = await DatabaseInstance.instance;
    final channelEntity = await database.configDao.getOrCreateConfigByKey(
      'UpdateChannel',
      value: UpdateChannel.develop,
    );
    _lastTimeCheckVersion = await database.configDao.getOrCreateConfigByKey(
      'LastTimeCheckVersion',
      value: '',
    );
    // Older builds stored the last notified version under UpdateChannel too.
    final channelIndex = int.tryParse(channelEntity.value ?? '');
    if (channelIndex == null ||
        channelIndex < 0 ||
        channelIndex >= UpdateChannel.values.length) {
      if (_lastTimeCheckVersion!.value == '') {
        _lastTimeCheckVersion!.set(channelEntity.value ?? '');
        await database.configDao.updateConfig(_lastTimeCheckVersion!);
      }
      // The original channel was overwritten and cannot be recovered.
      channelEntity.set(UpdateChannel.release);
      await database.configDao.updateConfig(channelEntity);
    }
    _channelEntity = channelEntity;
    if (await checkUpdate()) {
      ReleaseInfo? releaseInfo = await getLatestUpdateInfo();
      if (releaseInfo != null && _lastTimeCheckVersion != null) {
        if (releaseInfo.version != _lastTimeCheckVersion!.get<String>()) {
          _needShowUpdateDialog = true;
          _lastTimeCheckVersion?.set(releaseInfo.version);
          await database.configDao.updateConfig(_lastTimeCheckVersion!);
        } else {
          _needShowUpdateDialog = false;
        }
      }
    }
    notifyListeners();
  }

  Future<bool> checkUpdate() async {
    var latestVersion = '';
    try {
      switch (channel) {
        case UpdateChannel.release:
          // 只选择最近的release（非pre-release）
          var response = await RequestHandlers.githubRequestHandler
              .getReleases();
          if (response.statusCode == 200 || response.statusCode == 304) {
            var releases = response.data
                .where((r) => r['prerelease'] == false)
                .toList();
            if (releases.isNotEmpty) {
              latestVersion = releases.first['tag_name'];
            }
          }
          break;
        case UpdateChannel.develop:
          // release和pre-release都可选，优先选择版本号高的
          var response = await RequestHandlers.githubRequestHandler
              .getReleases();
          if (response.statusCode == 200 || response.statusCode == 304) {
            var releases = response.data;
            if (releases.isNotEmpty) {
              var release = releases.firstWhere(
                (r) => r['prerelease'] == false,
                orElse: () => null,
              );
              var preRelease = releases.firstWhere(
                (r) => r['prerelease'] == true,
                orElse: () => null,
              );
              Version? releaseVersion = release != null
                  ? Version.parse(
                      release['tag_name'].toString().replaceAll(
                        RegExp(r'[^0-9\\.]'),
                        '',
                      ),
                    )
                  : null;
              Version? preReleaseVersion = preRelease != null
                  ? Version.parse(
                      preRelease['tag_name'].toString().replaceAll(
                        RegExp(r'[^0-9\\.]'),
                        '',
                      ),
                    )
                  : null;
              if (releaseVersion != null && preReleaseVersion != null) {
                latestVersion = (releaseVersion > preReleaseVersion
                    ? release
                    : preRelease)['tag_name'];
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
          var response = await RequestHandlers.githubRequestHandler
              .getReleases();
          if (response.statusCode == 200 || response.statusCode == 304) {
            var releases = response.data
                .where((r) => r['prerelease'] == false)
                .toList();
            if (releases.isNotEmpty) {
              data = releases.first;
            }
          }
          break;
        case UpdateChannel.develop:
          // 不过滤pre-release，release和pre-release都可选，优先选择版本号高的
          var response = await RequestHandlers.githubRequestHandler
              .getReleases();
          if (response.statusCode == 200 || response.statusCode == 304) {
            var releases = response.data;
            if (releases.isNotEmpty) {
              // 找到最高版本的release和pre-release
              var release = releases.firstWhere(
                (r) => r['prerelease'] == false,
                orElse: () => null,
              );
              var preRelease = releases.firstWhere(
                (r) => r['prerelease'] == true,
                orElse: () => null,
              );
              Version? releaseVersion = release != null
                  ? Version.parse(
                      release['tag_name'].toString().replaceAll(
                        RegExp(r'[^0-9\.]'),
                        '',
                      ),
                    )
                  : null;
              Version? preReleaseVersion = preRelease != null
                  ? Version.parse(
                      preRelease['tag_name'].toString().replaceAll(
                        RegExp(r'[^0-9\.]'),
                        '',
                      ),
                    )
                  : null;
              if (releaseVersion != null && preReleaseVersion != null) {
                data = releaseVersion > preReleaseVersion
                    ? release
                    : preRelease;
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
    return releaseInfoFromGithub(data, currentUpdateTargetPlatform);
  }

  String get currentVersion => _currentVersion;

  String get latestVersion =>
      _latestVersion.isEmpty ? currentVersion : _latestVersion;

  UpdateChannel get channel {
    if (_channelEntity == null) {
      return UpdateChannel.release;
    }
    return UpdateChannel.values[(_channelEntity?.get<int>()) as int];
  }

  set channel(UpdateChannel value) {
    if (_channelEntity != null) {
      _channelEntity?.set(value);
      DatabaseInstance.instance.then(
        (value) => value.configDao.updateConfig(_channelEntity!),
      );
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
    final releaseInfo = await getLatestUpdateInfo();
    if (!context.mounted) return;
    if (releaseInfo == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(S.of(context).SettingPageFailToGetReleaseInfo),
        ),
      );
      return;
    }

    final targetPlatform = currentUpdateTargetPlatform;
    final targetNavigator = context
        .read<NavigatorProvider>()
        .getNavigator(context, NavigatorType.defaultNavigator);
    final messenger = ScaffoldMessenger.of(context);
    final messages = _UpdateMessages(
      Localizations.localeOf(context).languageCode == 'zh',
    );
    final canDownload =
        releaseInfo.updateUrl.isNotEmpty &&
        targetPlatform != UpdateTargetPlatform.unsupported;
    final canVerify = releaseInfo.hasTrustedSha256;
    final warnings = <String>[
      if (!canDownload) messages.noPackage,
      if (canDownload && !canVerify) messages.unverified,
      if (canDownload && targetPlatform == UpdateTargetPlatform.ios)
        messages.unsignedIos,
    ];
    var submitStarted = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final dialogNavigator = Navigator.of(dialogContext);
        final dialogRoute = ModalRoute.of(dialogContext);
        return AlertDialog(
          scrollable: true,
          title: Text(S.of(dialogContext).ReleaseInfoTitle(releaseInfo.version)),
          content: SizedBox(
            width: 560,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                MarkdownBody(
                  data: releaseInfo.desc,
                  onTapLink: (text, href, title) {
                    if (href != null) {
                      _openExternalUrl(href);
                    }
                  },
                ),
                for (final warning in warnings) ...[
                  const SizedBox(height: 16),
                  Text(
                    warning,
                    style: TextStyle(
                      color: Theme.of(dialogContext).colorScheme.error,
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: releaseInfo.releaseUrl.isEmpty
                  ? null
                  : () => _openExternalUrl(releaseInfo.releaseUrl),
              child: Text(S.of(dialogContext).AboutPageGithub),
            ),
            TextButton(
              onPressed: () {
                if (!canDownload || !canVerify) {
                  dialogNavigator.pop();
                  _openExternalUrl(releaseInfo.releaseUrl);
                  return;
                }
                if (submitStarted) return;
                submitStarted = true;
                _submitAndOpenDownloads(
                  releaseInfo: releaseInfo,
                  platform: targetPlatform,
                  dialogNavigator: dialogNavigator,
                  dialogRoute: dialogRoute,
                  targetNavigator: targetNavigator,
                  messenger: messenger,
                  onSubmitFailed: () {
                    submitStarted = false;
                  },
                  messages: messages,
                );
              },
              child: Text(
                canDownload && canVerify
                    ? S.of(dialogContext).ReleaseInfoDownload
                    : messages.openReleasePage,
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _submitAndOpenDownloads({
    required ReleaseInfo releaseInfo,
    required UpdateTargetPlatform platform,
    required NavigatorState dialogNavigator,
    required NavigatorState? targetNavigator,
    required Route<dynamic>? dialogRoute,
    required ScaffoldMessengerState messenger,
    required VoidCallback onSubmitFailed,
    required _UpdateMessages messages,
  }) async {
    try {
      await submitUpdateDownload(releaseInfo, platform);
    } catch (_) {
      if (messenger.mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text(messages.downloadFailed)),
        );
      }
      onSubmitFailed();
      return;
    }

    if (dialogNavigator.mounted && dialogRoute?.isCurrent == true) {
      dialogNavigator.pop();
    }
    if (targetNavigator?.mounted == true) {
      await targetNavigator!.push<void>(
        MaterialPageRoute<void>(
          builder: (_) => const DownloadPage(),
          settings: const RouteSettings(name: 'DownloadPage'),
        ),
      );
    }
  }
}

Future<void> _openExternalUrl(String url) async {
  if (url.isEmpty) return;
  if (await url_string_launcher.canLaunchUrlString(url)) {
    await url_string_launcher.launchUrlString(
      url,
      mode: url_string_launcher.LaunchMode.externalApplication,
    );
  }
}

class _UpdateMessages {
  final bool zh;

  const _UpdateMessages(this.zh);

  String get noPackage => zh
      ? '当前平台没有可用的安装包。请在发布页查看可用文件。'
      : 'No installation package is available for this platform. Check the release page for available files.';

  String get unverified => zh
      ? '该安装包没有可信的 SHA-256 摘要，无法验证其完整性，因此不会提供下载后安装入口。请改从发布页查看。'
      : 'This package has no trusted SHA-256 digest, so its integrity cannot be verified and it will not be offered for installation. Check the release page instead.';

  String get unsignedIos => zh
      ? 'iOS 的 IPA 可能未签名，下载完成也不代表可直接安装；可能需要自行签名或使用受支持的安装方式。'
      : 'The iOS IPA may be unsigned. A completed download does not mean it can be installed directly; signing or another supported installation method may be required.';

  String get openReleasePage => zh ? '打开发布页' : 'Open release page';

  String get downloadFailed => zh ? '下载任务启动失败' : 'Failed to start download task';
}
