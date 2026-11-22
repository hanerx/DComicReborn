import 'package:dcomic/providers/automatic_mapping.dart';
import 'package:dcomic/generated/l10n.dart';
import 'package:dcomic/providers/navigator_provider.dart';
import 'package:dcomic/providers/models/comic_source_model.dart';
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
  String _text(String zh, String en) =>
      Localizations.localeOf(context).languageCode == 'zh' ? zh : en;

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
              for (var item in Provider.of<ComicSourceProvider>(
                context,
              ).hasAccountSettingSources)
                Tab(text: item.type.sourceName),
            ],
          ),
        ),
        backgroundColor: Theme.of(context).colorScheme.surface,
        body: TabBarView(
          children: [
            for (var item in Provider.of<ComicSourceProvider>(
              context,
            ).hasAccountSettingSources)
              ListenableBuilder(
                listenable: item.accountModel!,
                builder: (context, _) => item.accountModel!.isLogin
                    ? ChangeNotifierProvider(
                        create: (context) => ComicFavoritePageController(
                          item,
                          mappingQueue: context.read<AutomaticMappingQueue>(),
                        ),
                        builder: (context, child) => EasyRefresh(
                          onRefresh: () async {
                            await Provider.of<ComicFavoritePageController>(
                              context,
                              listen: false,
                            ).refresh();
                          },
                          onLoad: () async {
                            await Provider.of<ComicFavoritePageController>(
                              context,
                              listen: false,
                            ).load();
                          },
                          refreshOnStart: true,
                          child: ListenableBuilder(
                            listenable: item,
                            builder: (context, _) => LayoutBuilder(
                              builder: (context, constraints) {
                                var controller =
                                    Provider.of<ComicFavoritePageController>(
                                      context,
                                    );
                                var data = controller.data;
                                var installedSourceIds = context
                                    .read<ComicSourceProvider>()
                                    .sources
                                    .map((source) => source.type.sourceId)
                                    .toSet();
                                return GridView(
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    16,
                                    16,
                                    16,
                                  ),
                                  gridDelegate: GridCardItem.coverGridDelegate(
                                    context,
                                    gridWidth: constraints.maxWidth - 32,
                                    crossAxisCount: 3,
                                    hasSubtitle: data.any(
                                      (entity) =>
                                          (entity.subtitle ?? '').isNotEmpty,
                                    ),
                                  ),
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
                                        sourceIds: controller
                                            .sourceIdsFor(item)
                                            .where(installedSourceIds.contains)
                                            .toList(growable: false),
                                      ),
                                  ],
                                );
                              },
                            ),
                          ),
                        ),
                      )
                    : EmptyWidget(
                        title: switch (item.accountModel!.status) {
                          ComicAccountStatus.checking => _text(
                            '正在验证账户',
                            'Verifying account',
                          ),
                          ComicAccountStatus.unavailable => _text(
                            '账户暂时无法验证',
                            'Account temporarily unavailable',
                          ),
                          _ => S.of(context).RequireLogin,
                        },
                        children: [
                          if (item.accountModel!.status ==
                              ComicAccountStatus.checking)
                            const CircularProgressIndicator()
                          else if (item.accountModel!.hasCredentials)
                            TextButton.icon(
                              onPressed: item.accountModel!.initAccount,
                              icon: const Icon(Icons.refresh),
                              label: Text(_text('重试', 'Retry')),
                            )
                          else
                            TextButton(
                              onPressed: () async {
                                final navigator = context.read<NavigatorProvider>();
                                final sources = context.read<ComicSourceProvider>();
                                await navigator.getNavigator(
                                  context,
                                  NavigatorType.defaultNavigator,
                                )?.push(MaterialPageRoute(
                                  builder: (context) =>
                                      AccountLoginPage(sourceModel: item),
                                  settings: const RouteSettings(
                                    name: 'AccountLoginPage',
                                  ),
                                ));
                                if (context.mounted) sources.callNotify();
                              },
                              child: Text(S.of(context).JumpToLogin),
                            ),
                        ],
                      ),
              ),
          ],
        ),
      ),
    );
  }
}
