import 'package:dcomic/generated/l10n.dart';
import 'package:dcomic/providers/navigator_provider.dart';
import 'package:dcomic/providers/page_controllers/comic_favorite_page_controller.dart';
import 'package:dcomic/providers/source_provider.dart';
import 'package:dcomic/view/components/empty_widget.dart';
import 'package:dcomic/view/components/grid_card.dart';
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
          backgroundColor: Theme.of(context).colorScheme.surface,
          body: TabBarView(children: [
            for (var item in Provider.of<ComicSourceProvider>(context)
                .hasAccountSettingSources)
              item.accountModel!.isLogin
                  ? ChangeNotifierProvider(
                      create: (_) => ComicFavoritePageController(item),
                      builder: (context, child) => EasyRefresh(
                            onRefresh: () async {
                              await Provider.of<ComicFavoritePageController>(
                                      context,
                                      listen: false)
                                  .refresh();
                            },
                            onLoad: () async {
                              await Provider.of<ComicFavoritePageController>(
                                      context,
                                      listen: false)
                                  .load();
                            },
                            refreshOnStart: true,
                            child:
                                LayoutBuilder(builder: (context, constraints) {
                              var data =
                                  Provider.of<ComicFavoritePageController>(
                                          context)
                                      .data;
                              return GridView(
                                padding:
                                    const EdgeInsets.fromLTRB(16, 16, 16, 16),
                                gridDelegate: GridCardItem.coverGridDelegate(
                                    context,
                                    gridWidth: constraints.maxWidth - 32,
                                    crossAxisCount: 3,
                                    hasSubtitle: data.any((entity) =>
                                        (entity.subtitle ?? '').isNotEmpty)),
                                children: [
                                  for (var item in data)
                                    GridCardItem(
                                      image: item.cover,
                                      title: item.title,
                                      subtitle: item.subtitle,
                                      onTap: () {
                                        if (item.onTap != null) {
                                          item.onTap!(context);
                                        }
                                      },
                                      badgeMaps: item.badges,
                                    )
                                ],
                              );
                            }),
                          ))
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
                                      Provider.of<ComicSourceProvider>(context,
                                              listen: false)
                                          .callNotify());
                            },
                            child: Text(S.of(context).JumpToLogin))
                      ],
                    ),
          ]),
        ));
  }
}
