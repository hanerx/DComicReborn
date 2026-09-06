import 'package:dcomic/providers/page_controllers/comic_search_page_controller.dart';
import 'package:dcomic/providers/source_provider.dart';
import 'package:dcomic/view/components/card_list_item.dart';
import 'package:easy_refresh/easy_refresh.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<StatefulWidget> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
        create: (_) => ComicSearchPageController(
            Provider.of<ComicSourceProvider>(context).orderedSources),
        builder: (context, child) => DefaultTabController(
            length:
                Provider.of<ComicSourceProvider>(context).orderedSources.length,
            child: Scaffold(
              appBar: AppBar(
                title: TextField(
                  decoration: InputDecoration(
                    hintText:
                        MaterialLocalizations.of(context).searchFieldLabel,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                  ),
                  textInputAction: TextInputAction.search,
                  onChanged: (text) {
                    Provider.of<ComicSearchPageController>(context,
                            listen: false)
                        .pendingKeyword = text;
                  },
                  onSubmitted: (text) async {
                    Provider.of<ComicSearchPageController>(context,
                            listen: false)
                        .pendingKeyword = text;
                    FocusScope.of(context).unfocus();
                    await Provider.of<ComicSearchPageController>(context,
                            listen: false)
                        .search();
                  },
                ),
                actions: [
                  IconButton(
                      onPressed: () async {
                        FocusScope.of(context).unfocus();
                        await Provider.of<ComicSearchPageController>(context,
                                listen: false)
                            .search();
                      },
                      icon: const Icon(Icons.search))
                ],
                bottom: TabBar(
                  isScrollable: true,
                  tabs: [
                    for (var item in Provider.of<ComicSourceProvider>(context)
                        .orderedSources)
                      Tab(
                        text: item.type.sourceName,
                      )
                  ],
                ),
              ),
              backgroundColor: Theme.of(context).colorScheme.surface,
              body: TabBarView(children: [
                for (var item
                    in Provider.of<ComicSourceProvider>(context).orderedSources)
                  EasyRefresh(
                      onRefresh: () async {
                        await Provider.of<ComicSearchPageController>(context,
                                listen: false)
                            .refresh(item);
                      },
                      onLoad: () async {
                        await Provider.of<ComicSearchPageController>(context,
                                listen: false)
                            .load(item);
                      },
                      refreshOnStart: true,
                      child: ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.only(top: 4, bottom: 12),
                        itemCount:
                            Provider.of<ComicSearchPageController>(context)
                                    .data[item]!
                                    .data
                                    .length +
                                (Provider.of<ComicSearchPageController>(context)
                                        .data[item]!
                                        .hasError
                                    ? 1
                                    : 0),
                        itemBuilder: (context, index) {
                          final controller =
                              Provider.of<ComicSearchPageController>(context);
                          final state = controller.data[item]!;
                          if (index == state.data.length) {
                            final isZh =
                                Localizations.localeOf(context).languageCode ==
                                    'zh';
                            return ListTile(
                              leading: Icon(Icons.cloud_off_rounded,
                                  color: Theme.of(context).colorScheme.error),
                              title: Text(isZh
                                  ? '搜索失败，请重试'
                                  : 'Search failed. Try again.'),
                              trailing: IconButton(
                                tooltip: isZh ? '重试' : 'Retry',
                                icon: const Icon(Icons.refresh_rounded),
                                onPressed: () => state.data.isEmpty
                                    ? controller.refresh(item)
                                    : controller.load(item),
                              ),
                            );
                          }
                          final entity = state.data[index];
                          return CardListItem(
                            cover: entity.cover,
                            title: entity.title,
                            details: entity.details,
                            onTap: entity.onTap,
                          );
                        },
                      ))
              ]),
            )));
  }
}
