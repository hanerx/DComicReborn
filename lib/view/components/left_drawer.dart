import 'package:dcomic/generated/l10n.dart';
import 'package:dcomic/providers/config_provider.dart';
import 'package:dcomic/providers/models/comic_source_model.dart';
import 'package:dcomic/providers/navigator_provider.dart';
import 'package:dcomic/providers/source_provider.dart';
import 'package:dcomic/view/drawer_page/favorite_page.dart';
import 'package:dcomic/view/drawer_page/history_page.dart';
import 'package:dcomic/view/settings/account_manage_page.dart';
import 'package:dcomic/view/settings/settings_main.dart';
import 'package:direct_select_flutter/direct_select_container.dart';
import 'package:direct_select_flutter/direct_select_item.dart';
import 'package:direct_select_flutter/direct_select_list.dart';
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
    List list = buildList(context);
    return Drawer(
      child: DirectSelectContainer(
        child: ListView.builder(
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          itemCount: list.length,
          itemBuilder: (context, index) {
            return list[index];
          },
        ),
      ),
    );
  }

  List<Widget> buildList(BuildContext context) {
    List<Widget> list = <Widget>[
      UserAccountsDrawerHeader(
        accountName: Text(S.of(context).AppName),
        accountEmail: Text(
          S.of(context).DrawerEmail,
        ),
        currentAccountPicture: const FlutterLogo(),
        otherAccountsPictures: <Widget>[
          TextButton(
            onPressed: () {
              var index = ThemeMode.values.indexOf(Provider.of<ConfigProvider>(context, listen: false).themeMode);
              index +=1;
              if(index >= ThemeMode.values.length){
                index = 0;
              }
              Provider.of<ConfigProvider>(context, listen: false).themeMode = ThemeMode.values[index];
            },
            style: ButtonStyle(
                shape: MaterialStateProperty.all(const CircleBorder()),
                padding: MaterialStateProperty.all(const EdgeInsets.all(3))),
            child: Icon(
              themeMode2Icon[Provider.of<ConfigProvider>(context).themeMode],
              color: Theme.of(context).primaryTextTheme.bodyLarge?.color,
            ),
          ),
          TextButton(
            onPressed: () {
              Provider.of<NavigatorProvider>(context, listen: false)
                  .getNavigator(context, NavigatorType.defaultNavigator)
                  ?.push(MaterialPageRoute(
                  builder: (context) => const AccountManagePage(),
                  settings: const RouteSettings(name: 'AccountManagePage')));
            },
            style: ButtonStyle(
                shape: MaterialStateProperty.all(const CircleBorder()),
                padding: MaterialStateProperty.all(const EdgeInsets.all(3))),
            child: Icon(
              Icons.manage_accounts,
              color: Theme.of(context).primaryTextTheme.bodyLarge?.color,
            ),
          )
        ],
      ),
      _buildSourceController(context),
      const Divider(),
      ListTile(
        leading: const Icon(Icons.favorite_border),
        title: Text(S.of(context).DrawerFavorite),
        onTap: () {
          Provider.of<NavigatorProvider>(context, listen: false)
              .getNavigator(context, NavigatorType.defaultNavigator)
              ?.push(MaterialPageRoute(
              builder: (context) => const FavoritePage(),
              settings: const RouteSettings(name: 'FavoritePage')));
        },
      ),
      ListTile(
        leading: const Icon(Icons.history_edu),
        title: Text(S.of(context).DrawerHistory),
        onTap: () {
          Provider.of<NavigatorProvider>(context, listen: false)
              .getNavigator(context, NavigatorType.defaultNavigator)
              ?.push(MaterialPageRoute(
              builder: (context) => const HistoryPage(),
              settings: const RouteSettings(name: 'HistoryPage')));
        },
      ),
      ListTile(
        leading: const Icon(Icons.file_download_outlined),
        title: Text(S.of(context).DrawerDownloads),
        onTap: () {},
      ),
      const Divider(),
      ListTile(
        leading: const Icon(Icons.settings),
        title: Text(S.of(context).DrawerSetting),
        onTap: () {
          Provider.of<NavigatorProvider>(context, listen: false)
              .getNavigator(context, NavigatorType.defaultNavigator)
              ?.push(MaterialPageRoute(
                  builder: (context) => const MainSettingPage(),
                  settings: const RouteSettings(name: 'MainSettingPage')));
        },
      )
    ];
    return list;
  }

  Widget _buildSourceController(BuildContext context) {
    return ListTile(
      leading: const Padding(
        padding: EdgeInsets.only(top: 5),
        child: Icon(Icons.apps),
      ),
      title: DirectSelectList<BaseComicSourceModel>(
        values: Provider.of<ComicSourceProvider>(context).hasHomepageSources,
        defaultItemIndex:
            Provider.of<ComicSourceProvider>(context).activeHomeModelIndex,
        itemBuilder: (BaseComicSourceModel value) =>
            DirectSelectItem<BaseComicSourceModel>(
                itemHeight: 50,
                value: value,
                itemBuilder: (context, value) {
                  return Text(
                    value.type.sourceName,
                    style: Theme.of(context).textTheme.titleSmall,
                  );
                }),
        onItemSelectedListener: (item, index, context) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(item.type.sourceName)));
          Provider.of<ComicSourceProvider>(context, listen: false)
              .activeHomeModel = item;
        },
        focusedItemDecoration: BoxDecoration(
          border: BorderDirectional(
            bottom: BorderSide(
                width: 1, color: Theme.of(context).colorScheme.primary),
            top: BorderSide(
                width: 1, color: Theme.of(context).colorScheme.primary),
          ),
        ),
      ),
      trailing: const Icon(Icons.unfold_more),
    );
  }
}
