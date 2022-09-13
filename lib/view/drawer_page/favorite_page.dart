import 'package:dcomic/generated/l10n.dart';
import 'package:easy_refresh/easy_refresh.dart';
import 'package:flutter/material.dart';

class FavoritePage extends StatefulWidget {
  const FavoritePage({super.key});

  @override
  State<StatefulWidget> createState() => _FavoritePageState();
}

class _FavoritePageState extends State<FavoritePage> {
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
        length: 1,
        child: Scaffold(
          appBar: AppBar(
            elevation: 0,
            title: Text(S.of(context).DrawerFavorite),
            bottom: TabBar(
              isScrollable: true,
              tabs: [
                Tab(
                  text: "DMZJ",
                )
              ],
            ),
          ),
          body: TabBarView(children: [
            EasyRefresh(
                child: Container(
              color: Theme.of(context).colorScheme.surfaceVariant,
            ))
          ]),
        ));
  }
}
