import 'package:dcomic/generated/l10n.dart';
import 'package:dcomic/providers/config_provider.dart';
import 'package:dcomic/providers/models/comic_source_model.dart';
import 'package:dcomic/providers/navigator_provider.dart';
import 'package:dcomic/providers/source_provider.dart';
import 'package:dcomic/view/components/dcomic_mark.dart';
import 'package:dcomic/view/drawer_page/favorite_page.dart';
import 'package:dcomic/view/drawer_page/history_page.dart';
import 'package:dcomic/view/settings/account_manage_page.dart';
import 'package:dcomic/view/settings/settings_main.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class LeftDrawer extends StatefulWidget {
  @override
  State<StatefulWidget> createState() {
    return _LeftDrawerState();
  }
}

class _LeftDrawerState extends State<LeftDrawer> {
  final themeMode2Icon = {
    ThemeMode.system: Icons.brightness_4,
    ThemeMode.dark: Icons.dark_mode,
    ThemeMode.light: Icons.brightness_5
  };

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Drawer(
      backgroundColor: colorScheme.surface,
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(context),
            Divider(height: 1, color: colorScheme.outlineVariant),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  _buildSourceController(context),
                  _buildNavigationTile(
                    context: context,
                    icon: Icons.favorite_border_rounded,
                    title: S.of(context).DrawerFavorite,
                    routeName: 'FavoritePage',
                    builder: (context) => const FavoritePage(),
                  ),
                  _buildNavigationTile(
                    context: context,
                    icon: Icons.history_rounded,
                    title: S.of(context).DrawerHistory,
                    routeName: 'HistoryPage',
                    builder: (context) => const HistoryPage(),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: colorScheme.outlineVariant),
            SafeArea(
              top: false,
              child: _buildNavigationTile(
                context: context,
                icon: Icons.settings_rounded,
                title: S.of(context).DrawerSetting,
                routeName: 'MainSettingPage',
                builder: (context) => const MainSettingPage(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      child: Row(
        children: [
          const DComicMark(size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              S.of(context).AppName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700, color: colorScheme.onSurface),
            ),
          ),
          IconButton(
            tooltip: _locale(context, '切换主题', 'Toggle Theme'),
            onPressed: () => _cycleThemeMode(context),
            icon: Icon(
              themeMode2Icon[Provider.of<ConfigProvider>(context).themeMode],
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          IconButton(
            tooltip: _locale(context, '账户管理', 'Manage Accounts'),
            onPressed: () {
              Provider.of<NavigatorProvider>(context, listen: false)
                  .getNavigator(context, NavigatorType.defaultNavigator)
                  ?.push(MaterialPageRoute(
                      builder: (context) => const AccountManagePage(),
                      settings:
                          const RouteSettings(name: 'AccountManagePage')));
            },
            icon: Icon(
              Icons.manage_accounts_outlined,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  void _cycleThemeMode(BuildContext context) {
    var index = ThemeMode.values
        .indexOf(Provider.of<ConfigProvider>(context, listen: false).themeMode);
    index = (index + 1) % ThemeMode.values.length;
    Provider.of<ConfigProvider>(context, listen: false).themeMode =
        ThemeMode.values[index];
  }

  Widget _buildSourceController(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    var activeSource =
        Provider.of<ComicSourceProvider>(context).activeHomeModel;
    return ListTile(
      leading: Icon(Icons.apps_outlined, color: colorScheme.primary),
      title: Text(
        activeSource.type.sourceName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context)
            .textTheme
            .titleMedium
            ?.copyWith(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        _locale(context, '内容源', 'Comic Source'),
        style: TextStyle(color: colorScheme.onSurfaceVariant),
      ),
      trailing:
          Icon(Icons.unfold_more_rounded, color: colorScheme.onSurfaceVariant),
      onTap: () => _showSourceSheet(context),
    );
  }

  void _showSourceSheet(BuildContext context) {
    var provider = Provider.of<ComicSourceProvider>(context, listen: false);
    var sources = provider.hasHomepageSources;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        final colorScheme = Theme.of(sheetContext).colorScheme;
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(
                  _locale(context, '选择内容源', 'Choose Comic Source'),
                  style: Theme.of(sheetContext).textTheme.titleSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700),
                ),
              ),
              for (BaseComicSourceModel source in sources)
                ListTile(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  title: Text(source.type.sourceName),
                  selected: source == provider.activeHomeModel,
                  trailing: source == provider.activeHomeModel
                      ? Icon(Icons.check_rounded, color: colorScheme.primary)
                      : null,
                  onTap: () {
                    provider.activeHomeModel = source;
                    Navigator.of(sheetContext).pop();
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildNavigationTile(
      {required BuildContext context,
      required IconData icon,
      required String title,
      required String routeName,
      required WidgetBuilder builder}) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
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
