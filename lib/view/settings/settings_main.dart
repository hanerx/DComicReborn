import 'package:dcomic/generated/l10n.dart';
import 'package:dcomic/providers/config_provider.dart';
import 'package:dcomic/providers/navigator_provider.dart';
import 'package:dcomic/utils/layout_utils.dart';
import 'package:dcomic/view/components/settings_widgets.dart';
import 'package:dcomic/view/settings/about_page.dart';
import 'package:dcomic/view/settings/account_manage_page.dart';
import 'package:dcomic/view/settings/debug_page.dart';
import 'package:dcomic/view/settings/database_sync_page.dart';
import 'package:dcomic/view/settings/download_setting_page.dart';
import 'package:dcomic/view/settings/experimental_features_page.dart';
import 'package:dcomic/view/settings/source_manage_page.dart';
import 'package:dcomic/view/settings/viewer_setting_page.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class MainSettingPage extends StatefulWidget {
  const MainSettingPage({super.key});

  @override
  State<StatefulWidget> createState() {
    return _MainSettingPageState();
  }
}

class _MainSettingPageState extends State<MainSettingPage> {
  @override
  Widget build(BuildContext context) {
    return SettingsPage(
      title: Text(S.of(context).DrawerSetting),
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
              SettingsSection(title: _locale(context, '阅读', 'Reading')),
              SettingsGroup(
                children: [
                  _settingTile(
                    icon: Icons.auto_stories_outlined,
                    title: S.of(context).ReaderSettings,
                    subtitle: S.of(context).ReaderSettingsDescription,
                    routeName: 'ViewerSettingPage',
                    builder: (context) => const ViewerSettingPage(),
                  ),
                  _settingTile(
                    icon: Icons.download_for_offline_outlined,
                    title: _locale(context, '下载设置', 'Download Settings'),
                    subtitle: _locale(
                      context,
                      '设置阅读时预缓存到磁盘的页面数量',
                      'Choose how many reading pages are precached to disk',
                    ),
                    routeName: 'DownloadSettingPage',
                    builder: (context) => const DownloadSettingPage(),
                  ),
                ],
              ),
              SettingsSection(
                title: _locale(context, '内容源', 'Content Sources'),
              ),
              SettingsGroup(
                children: [
                  _settingTile(
                    icon: Icons.apps_outlined,
                    title: S.of(context).SourceSettings,
                    subtitle: S.of(context).SourceSettingsDescription,
                    routeName: 'SourceManagePage',
                    builder: (context) => const SourceManagePage(),
                  ),
                ],
              ),
              SettingsSection(title: _locale(context, '账户', 'Account')),
              SettingsGroup(
                children: [
                  _settingTile(
                    icon: Icons.account_box_outlined,
                    title: S.of(context).AccountSettings,
                    subtitle: S.of(context).AccountSettingsDescription,
                    routeName: 'AccountManagePage',
                    builder: (context) => const AccountManagePage(),
                  ),
                  _settingTile(
                    icon: Icons.cloud_sync_outlined,
                    title: _locale(context, '数据库同步与备份', 'Database Sync & Backup'),
                    subtitle: _locale(
                      context,
                      '连接自托管账户，在设备间同步或导入导出加密备份',
                      'Connect a self-hosted account, sync devices, or import and export encrypted backups',
                    ),
                    routeName: 'DatabaseSyncPage',
                    builder: (context) => const DatabaseSyncPage(),
                  ),
                ],
              ),
              SettingsSection(
                title: _locale(context, '高级与关于', 'Advanced & About'),
              ),
              SettingsGroup(
                children: [
                  if (context.select<ConfigProvider, bool>(
                    (config) => config.advancedSettingsUnlocked,
                  )) ...[
                    _settingTile(
                      icon: Icons.science_outlined,
                      title: _locale(context, '实验性功能', 'Experimental Features'),
                      subtitle: _locale(
                        context,
                        '试用可能不稳定的功能，默认关闭',
                        'Try potentially unstable features, off by default',
                      ),
                      routeName: 'ExperimentalFeaturesPage',
                      builder: (context) => const ExperimentalFeaturesPage(),
                    ),
                    _settingTile(
                      icon: Icons.code,
                      title: S.of(context).DebugSettings,
                      subtitle: S.of(context).DebugSettingsDescription,
                      routeName: 'DebugPage',
                      builder: (context) => const DebugPage(),
                    ),
                  ],

                  _settingTile(
                    icon: Icons.info_outline,
                    title: S.of(context).AboutSettings,
                    subtitle: S.of(context).AboutSettingsDescription,
                    routeName: 'AboutPage',
                    builder: (context) => const AboutPage(),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _settingTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required String routeName,
    required WidgetBuilder builder,
  }) {
    return SettingsTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      onTap: () {
        Provider.of<NavigatorProvider>(context, listen: false)
            .getNavigator(context, NavigatorType.defaultNavigator)
            ?.push(
              MaterialPageRoute(
                builder: builder,
                settings: RouteSettings(name: routeName),
              ),
            );
      },
    );
  }

  String _locale(BuildContext context, String zh, String en) {
    return Localizations.localeOf(context).languageCode == 'zh' ? zh : en;
  }
}
