import 'package:dcomic/providers/page_controllers/comic_rank_page_controller.dart';
import 'package:dcomic/utils/image_utils.dart';
import 'package:dcomic/view/components/card_list_item.dart';
import 'package:dcomic/view/components/dcomic_image.dart';
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
          noMoreLoad: !Provider.of<ComicRankPageController>(context).canLoad,
          child: Container(
            height: double.infinity,
            color: Theme.of(context).colorScheme.surfaceVariant,
            child: GridView.builder(
              shrinkWrap: true,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 1, childAspectRatio: 3 / 1),
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
