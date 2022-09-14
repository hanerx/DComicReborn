import 'package:dcomic/generated/l10n.dart';
import 'package:dcomic/providers/navigator_provider.dart';
import 'package:dcomic/providers/source_provider.dart';
import 'package:dcomic/view/components/empty_widget.dart';
import 'package:dcomic/view/settings/account_login_page.dart';
import 'package:easy_refresh/easy_refresh.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class FavoritePage extends StatefulWidget {
  const FavoritePage({super.key});

  @override
  State<StatefulWidget> createState() => _FavoritePageState();
}

class _FavoritePageState extends State<FavoritePage> {
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
        length: Provider.of<ComicSourceProvider>(context)
            .hasAccountSettingSources
            .length,
        child: Scaffold(
          appBar: AppBar(
            elevation: 0,
            title: Text(S.of(context).DrawerFavorite),
            bottom: TabBar(
              isScrollable: true,
              tabs: [
                for (var item in Provider.of<ComicSourceProvider>(context)
                    .hasAccountSettingSources)
                  Tab(
                    text: item.type.sourceName,
                  )
              ],
            ),
          ),
          body: TabBarView(children: [
            for (var item in Provider.of<ComicSourceProvider>(context)
                .hasAccountSettingSources)
              item.accountModel!.isLogin
                  ? EasyRefresh(
                      onRefresh: () {},
                      onLoad: () {},
                      refreshOnStart: true,
                      child: Container(
                          color: Theme.of(context).colorScheme.surfaceVariant,
                          child: ListView()))
                  : EmptyWidget(
                      title: S.of(context).RequireLogin,
                      children: [
                        TextButton(
                            onPressed: () {
                              Provider.of<NavigatorProvider>(context,
                                      listen: false)
                                  .getNavigator(
                                      context, NavigatorType.defaultNavigator)
                                  ?.push(MaterialPageRoute(
                                      builder: (context) => AccountLoginPage(
                                            sourceModel: item,
                                          ),
                                      settings: const RouteSettings(
                                          name: 'AccountLoginPage')))
                                  .then((value) =>
                                      Provider.of<ComicSourceProvider>(context)
                                          .callNotify());
                            },
                            child: Text(S.of(context).JumpToLogin))
                      ],
                    ),
          ]),
        ));
  }
}
