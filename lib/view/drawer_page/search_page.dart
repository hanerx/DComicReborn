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
        create: (_) => ComicSearchPageController(Provider.of<ComicSourceProvider>(context)
            .sources),
    builder: (context, child) => DefaultTabController(
        length: Provider.of<ComicSourceProvider>(context)
            .sources
            .length,
        child: Scaffold(
          appBar: AppBar(
            elevation: 0,
            title: TextField(
                onChanged: (text){
                  Provider.of<ComicSearchPageController>(context,listen: false).pendingKeyword = text;
                },
            ),
            actions: [
              IconButton(
                  onPressed: () async {
                    await Provider.of<ComicSearchPageController>(
                        context,
                        listen: false)
                        .search();
                  },
                  icon: const Icon(Icons.search)
              )
            ],
            bottom: TabBar(
              isScrollable: true,
              tabs: [
                for (var item in Provider.of<ComicSourceProvider>(context)
                    .sources)
                  Tab(
                    text: item.type.sourceName,
                  )
              ],
            ),
          ),
          body: TabBarView(children: [
            for (var item in Provider.of<ComicSourceProvider>(context)
                .sources)
              EasyRefresh(
                  onRefresh: () async {
                    await Provider.of<ComicSearchPageController>(
                        context,
                        listen: false)
                        .refresh(item);
                  },
                  onLoad: () async {
                    await Provider.of<ComicSearchPageController>(
                        context,
                        listen: false)
                        .load(item);
                  },
                  refreshOnStart: true,
                  child: Container(
                    height: double.infinity,
                    color: Theme.of(context).colorScheme.surfaceVariant,
                    child: GridView.builder(
                      shrinkWrap: true,
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 1, childAspectRatio: 3 / 1),
                      itemCount: Provider.of<ComicSearchPageController>(context)
                          .data[item]?.data
                          .length,
                      itemBuilder: (context, index) {
                        var entity = Provider.of<ComicSearchPageController>(context)
                            .data[item]?.data[index];
                        return CardListItem(
                          cover: entity!.cover,
                          title: entity.title,
                          details: entity.details,
                          onTap: entity.onTap,
                        );
                      },
                    ),
                  ))
          ]),
        )));
  }
}
