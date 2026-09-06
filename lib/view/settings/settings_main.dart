import 'package:dcomic/generated/l10n.dart';
import 'package:dcomic/providers/navigator_provider.dart';
import 'package:dcomic/view/settings/about_page.dart';
import 'package:dcomic/view/settings/account_manage_page.dart';
import 'package:dcomic/view/settings/debug_page.dart';
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
    return Scaffold(
      appBar: AppBar(
        title: Text(S.of(context).DrawerSetting),
      ),
      body: ListView(
        padding: EdgeInsets.only(
          top: 8,
          bottom: 8 + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          _sectionHeader(context, '阅读', 'Reading', top: 8),
          _settingTile(
            context,
            icon: Icons.auto_stories_outlined,
            title: S.of(context).ReaderSettings,
            subtitle: S.of(context).ReaderSettingsDescription,
            routeName: 'ViewerSettingPage',
            builder: (context) => const ViewerSettingPage(),
          ),
          _sectionHeader(context, '内容源', 'Content Sources'),
          _settingTile(
            context,
            icon: Icons.apps_outlined,
            title: S.of(context).SourceSettings,
            subtitle: S.of(context).SourceSettingsDescription,
            routeName: 'SourceManagePage',
            builder: (context) => const SourceManagePage(),
          ),
          _sectionHeader(context, '账户', 'Account'),
          _settingTile(
            context,
            icon: Icons.account_box_outlined,
            title: S.of(context).AccountSettings,
            subtitle: S.of(context).AccountSettingsDescription,
            routeName: 'AccountManagePage',
            builder: (context) => const AccountManagePage(),
          ),
          _sectionHeader(context, '高级与关于', 'Advanced & About'),
          _settingTile(
            context,
            icon: Icons.code,
            title: S.of(context).DebugSettings,
            subtitle: S.of(context).DebugSettingsDescription,
            routeName: 'DebugPage',
            builder: (context) => const DebugPage(),
          ),
          _settingTile(
            context,
            icon: Icons.info_outline,
            title: S.of(context).AboutSettings,
            subtitle: S.of(context).AboutSettingsDescription,
            routeName: 'AboutPage',
            builder: (context) => const AboutPage(),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(BuildContext context, String zh, String en,
      {double top = 24}) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, top, 16, 4),
      child: Text(
        _locale(context, zh, en),
        style: Theme.of(context)
            .textTheme
            .titleSmall
            ?.copyWith(color: colorScheme.primary, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _settingTile(BuildContext context,
      {required IconData icon,
      required String title,
      required String subtitle,
      required String routeName,
      required WidgetBuilder builder}) {
    final colorScheme = Theme.of(context).colorScheme;
    return ListTile(
      leading: Icon(icon, color: colorScheme.primary),
      title: Text(
        title,
        style: Theme.of(context)
            .textTheme
            .bodyLarge
            ?.copyWith(color: colorScheme.onSurface),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: colorScheme.onSurfaceVariant),
      ),
      onTap: () {
        Provider.of<NavigatorProvider>(context, listen: false)
            .getNavigator(context, NavigatorType.defaultNavigator)
            ?.push(MaterialPageRoute(
                builder: builder, settings: RouteSettings(name: routeName)));
      },
    );
  }

  String _locale(BuildContext context, String zh, String en) {
    return Localizations.localeOf(context).languageCode == 'zh' ? zh : en;
  }
}
