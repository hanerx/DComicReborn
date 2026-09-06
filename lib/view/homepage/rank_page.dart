import 'package:dcomic/providers/page_controllers/comic_rank_page_controller.dart';
import 'package:dcomic/view/components/card_list_item.dart';
import 'package:easy_refresh/easy_refresh.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class RankPage extends StatefulWidget {
  const RankPage({super.key});

  @override
  State<StatefulWidget> createState() => _RankPageState();
}

class _RankPageState extends State<RankPage> {
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<ComicRankPageController>(
      create: (_) => ComicRankPageController(),
      builder: (context, child) => EasyRefresh(
          refreshOnStart: true,
          onRefresh: () async {
            await Provider.of<ComicRankPageController>(context, listen: false)
                .refresh(context);
          },
          onLoad: () async {
            await Provider.of<ComicRankPageController>(context, listen: false)
                .load(context);
          },
          child: ColoredBox(
            color: Theme.of(context).colorScheme.surface,
            child: ListView.builder(
              padding: const EdgeInsets.only(top: 4, bottom: 12),
              itemCount: Provider.of<ComicRankPageController>(context)
                  .rankingList
                  .length,
              itemBuilder: (context, index) {
                var entity = Provider.of<ComicRankPageController>(context)
                    .rankingList[index];
                return CardListItem(
                  cover: entity.cover,
                  title: entity.title,
                  details: entity.details,
                  onTap: entity.onTap,
                );
              },
            ),
          )),
    );
  }
}
