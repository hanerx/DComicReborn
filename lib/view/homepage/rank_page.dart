import 'package:dcomic/utils/image_utils.dart';
import 'package:dcomic/view/components/card_list_item.dart';
import 'package:dcomic/view/components/dcomic_image.dart';
import 'package:easy_refresh/easy_refresh.dart';
import 'package:flutter/material.dart';

class RankPage extends StatefulWidget {
  const RankPage({super.key});

  @override
  State<StatefulWidget> createState() => _RankPageState();
}

class _RankPageState extends State<RankPage> {
  @override
  Widget build(BuildContext context) {
    return EasyRefresh(
        child: Container(
      color: Theme.of(context).colorScheme.surfaceVariant,
      child: GridView(
        shrinkWrap: true,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 1, childAspectRatio: 3 / 1),
        children: [
          for(int i=0;i<10;i++)
            CardListItem(),
        ],
      ),
    ));
  }
}
