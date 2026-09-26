import 'package:dcomic/generated/l10n.dart';
import 'package:dcomic/providers/config_provider.dart';
import 'package:dcomic/providers/version_provider.dart';
import 'package:dcomic/utils/layout_utils.dart';
import 'package:dcomic/view/components/dcomic_mark.dart';
import 'package:dcomic/view/components/settings_widgets.dart';
import 'package:flutter/material.dart';
import 'package:fluttericon/font_awesome5_icons.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher_string.dart' as url_string_launcher;

class AboutPage extends StatefulWidget {
  const AboutPage({super.key});

  @override
  State<StatefulWidget> createState() {
    return _AboutPageState();
  }
}

class _AboutPageState extends State<AboutPage> {
  int _versionTapCount = 0;
  bool _unlocking = false;

  Future<void> _onVersionTap() async {
    final config = context.read<ConfigProvider>();
    if (_unlocking || config.advancedSettingsUnlocked) return;
    _versionTapCount++;
    if (_versionTapCount < 7) return;
    _unlocking = true;
    try {
      await config.setAdvancedSettingsUnlocked(true);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            Localizations.localeOf(context).languageCode == 'zh'
                ? '调试设置与实验性功能已解锁，可在设置中查看。'
                : 'Debug and experimental settings unlocked. Find them in Settings.',
          ),
        ),
      );
    } catch (_) {
      _versionTapCount = 6;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            Localizations.localeOf(context).languageCode == 'zh'
                ? '解锁失败，请点击版本号重试。'
                : 'Could not unlock. Tap the version to try again.',
          ),
        ),
      );
    } finally {
      _unlocking = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SettingsPage(
      title: Text(S.of(context).AboutSettings),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppLayout.formMaxWidth),
          child: ListView(
            padding: EdgeInsets.only(
              left: 12,
              top: 12,
              right: 12,
              bottom: 16 + MediaQuery.paddingOf(context).bottom,
            ),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Column(
                  children: [
                    const DComicMark(size: 80),
                    const SizedBox(height: 16),
                    Text(
                      S.of(context).AppName,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: colorScheme.onSurface,
                          ),
                    ),
                    const SizedBox(height: 4),
                    TextButton(
                      onPressed: _onVersionTap,
                      style: TextButton.styleFrom(
                        foregroundColor: colorScheme.onSurfaceVariant,
                        textStyle: Theme.of(context).textTheme.bodyMedium,
                      ),
                      child: Text(
                        Provider.of<VersionProvider>(context).currentVersion,
                      ),
                    ),
                  ],
                ),
              ),
              SettingsSection(title: _locale(context, '更新', 'Updates')),
              SettingsGroup(
                children: [
                  SettingsTile(
                    leading: const Icon(Icons.system_update),
                    title: Text(S.of(context).AboutPageCheckForUpdate),
                    subtitle: Text(
                      Provider.of<VersionProvider>(context).currentVersion,
                    ),
                    onTap: () async {
                      if (await Provider.of<VersionProvider>(
                        context,
                        listen: false,
                      ).checkUpdate()) {
                        if (context.mounted) {
                          await Provider.of<VersionProvider>(
                            context,
                            listen: false,
                          ).showReleaseInfo(context);
                        }
                      } else {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(S.of(context).CheckUpdateUpToDate),
                            ),
                          );
                        }
                      }
                    },
                  ),
                  SettingsTile(
                    leading: const Icon(FontAwesome5.git_alt),
                    title: Text(S.of(context).AboutPageUpdateChannel),
                    subtitle: Text(
                      S
                          .of(context)
                          .AboutPageUpdateChannelModes(
                            Provider.of<VersionProvider>(context).channel.name,
                          ),
                    ),
                    onTap: () {
                      var index = UpdateChannel.values.indexOf(
                        Provider.of<VersionProvider>(
                          context,
                          listen: false,
                        ).channel,
                      );
                      index++;
                      if (index >= UpdateChannel.values.length) {
                        index = 0;
                      }
                      Provider.of<VersionProvider>(
                        context,
                        listen: false,
                      ).channel = UpdateChannel.values[index];
                    },
                  ),
                  SettingsTile(
                    leading: const Icon(Icons.new_releases_outlined),
                    title: Text(S.of(context).SettingPageShowReleaseInfo),
                    subtitle: Text(
                      Provider.of<VersionProvider>(context).latestVersion,
                    ),
                    onTap: () async {
                      await Provider.of<VersionProvider>(
                        context,
                        listen: false,
                      ).showReleaseInfo(context);
                    },
                  ),
                ],
              ),
              SettingsSection(
                title: _locale(context, '链接与关于', 'Links & About'),
              ),
              SettingsGroup(
                children: [
                  SettingsTile(
                    leading: const Icon(FontAwesome5.github_alt),
                    title: Text(S.of(context).AboutPageGithub),
                    subtitle: Text(S.of(context).AboutPageGithubUrl),
                    onTap: () async {
                      if (await url_string_launcher.canLaunchUrlString(
                        S.of(context).AboutPageGithubUrl,
                      )) {
                        if (context.mounted) {
                          url_string_launcher.launchUrlString(
                            S.of(context).AboutPageGithubUrl,
                          );
                        }
                      }
                    },
                  ),
                  SettingsTile(
                    leading: const Icon(Icons.info_outline),
                    title: Text(S.of(context).AboutPageAbout),
                    subtitle: Text(S.of(context).AboutPageAboutSubtitle),
                    onTap: () {
                      showAboutDialog(
                        context: context,
                        applicationVersion: Provider.of<VersionProvider>(
                          context,
                          listen: false,
                        ).currentVersion,
                        children: [
                          Text(S.of(context).AboutPageAboutDialogueDescription),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _locale(BuildContext context, String zh, String en) {
    return Localizations.localeOf(context).languageCode == 'zh' ? zh : en;
  }
}
