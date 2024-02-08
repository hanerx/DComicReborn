import 'package:dcomic/providers/page_controllers/comic_latest_page_controller.dart';
import 'package:dcomic/view/components/card_list_item.dart';
import 'package:easy_refresh/easy_refresh.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class LatestPage extends StatefulWidget {
  const LatestPage({super.key});

  @override
  State<StatefulWidget> createState() => _LatestPageState();
}

class _LatestPageState extends State<LatestPage> {
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<ComicLatestPageController>(
      create: (_) => ComicLatestPageController(),
      builder: (context, child) => EasyRefresh(
          refreshOnStart: true,
          onRefresh: () async {
            await Provider.of<ComicLatestPageController>(context, listen: false)
                .refresh(context);
          },
          onLoad: () async {
            await Provider.of<ComicLatestPageController>(context, listen: false)
                .load(context);
          },
          // noMoreLoad: !Provider.of<ComicLatestPageController>(context).canLoad,
          child: Container(
            height: double.infinity,
            color: Theme.of(context).colorScheme.surfaceVariant,
            child: GridView.builder(
              shrinkWrap: true,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 1, childAspectRatio: 3 / 1),
              itemCount: Provider.of<ComicLatestPageController>(context)
                  .latestList
                  .length,
              itemBuilder: (context, index) {
                var entity = Provider.of<ComicLatestPageController>(context)
                    .latestList[index];
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
