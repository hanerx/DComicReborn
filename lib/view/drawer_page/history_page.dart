import 'package:dcomic/generated/l10n.dart';
import 'package:dcomic/providers/models/comic_source_model.dart';
import 'package:dcomic/providers/page_controllers/comic_history_page_controller.dart';
import 'package:dcomic/providers/source_provider.dart';
import 'package:dcomic/utils/image_utils.dart';
import 'package:dcomic/view/components/card_list_item.dart';
import 'package:easy_refresh/easy_refresh.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class HistoryPage extends StatefulWidget{
  const HistoryPage({super.key});

  @override
  State<StatefulWidget> createState() => _HistoryPageState();

}

class _HistoryPageState extends State<HistoryPage>{

  final Map<ComicHistorySourceType, IconData> _iconMap = {
    ComicHistorySourceType.network: Icons.network_cell,
    ComicHistorySourceType.local: Icons.sd_storage
  };

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
        create: (_) => ComicHistoryPageController(Provider.of<ComicSourceProvider>(context)
            .orderedSources),
        builder: (context, child) => DefaultTabController(
            length: Provider.of<ComicSourceProvider>(context)
                .orderedSources
                .length,
            child: Scaffold(
              appBar: AppBar(
                elevation: 0,
                title: Text(S.of(context).DrawerHistory),
                actions: [
                  IconButton(
                      onPressed: () async {
                        await Provider.of<ComicHistoryPageController>(
                            context,
                            listen: false)
                            .addSourceType();
                      },
                      icon: Icon(_iconMap[Provider.of<ComicHistoryPageController>(context).sourceType])
                  )
                ],
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
                    .orderedSources)
                  EasyRefresh(
                      onRefresh: () async {
                        await Provider.of<ComicHistoryPageController>(
                            context,
                            listen: false)
                            .refresh(item);
                      },
                      onLoad: () async {
                        await Provider.of<ComicHistoryPageController>(
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
                          itemCount: Provider.of<ComicHistoryPageController>(context)
                              .data[item]?.data[Provider.of<ComicHistoryPageController>(context).sourceType]
                              ?.length,
                          itemBuilder: (context, index) {
                            var dataList = Provider.of<ComicHistoryPageController>(context).data[item]!.data[Provider.of<ComicHistoryPageController>(context).sourceType];
                            var entity = dataList![index];
                            return CardListItem(
                              cover: entity.cover,
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