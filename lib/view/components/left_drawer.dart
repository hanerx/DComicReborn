import 'package:dcomic/generated/l10n.dart';
import 'package:dcomic/providers/models/comic_source_model.dart';
import 'package:dcomic/providers/navigator_provider.dart';
import 'package:dcomic/providers/source_provider.dart';
import 'package:dcomic/view/settings/settings_main.dart';
import 'package:direct_select_flutter/direct_select_container.dart';
import 'package:direct_select_flutter/direct_select_item.dart';
import 'package:direct_select_flutter/direct_select_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

class LeftDrawer extends StatefulWidget {
  @override
  State<StatefulWidget> createState() {
    return _LeftDrawerState();
  }
}

class _LeftDrawerState extends State<LeftDrawer> {
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
            onPressed: () {},
            style: ButtonStyle(
                shape: MaterialStateProperty.all(const CircleBorder()),
                padding: MaterialStateProperty.all(const EdgeInsets.all(3))),
            child: Icon(
              Icons.brightness_4,
              color: Theme.of(context).primaryTextTheme.bodyText1?.color,
            ),
          ),
          TextButton(
            onPressed: () {},
            style: ButtonStyle(
                shape: MaterialStateProperty.all(const CircleBorder()),
                padding: MaterialStateProperty.all(const EdgeInsets.all(3))),
            child: Icon(
              Icons.manage_accounts,
              color: Theme.of(context).primaryTextTheme.bodyText1?.color,
            ),
          )
        ],
      ),
      _buildSourceController(context),
      const Divider(),
      ListTile(
        leading: const Icon(Icons.favorite_border),
        title: Text(S.of(context).DrawerFavorite),
        onTap: () {},
      ),
      ListTile(
        leading: const Icon(Icons.history_edu),
        title: Text(S.of(context).DrawerHistory),
        onTap: () {},
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
                itemHeight: 56,
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
