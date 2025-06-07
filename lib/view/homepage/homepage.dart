import 'package:carousel_slider_plus/carousel_slider_plus.dart';
import 'package:dcomic/generated/l10n.dart';
import 'package:dcomic/providers/page_controllers/comic_homepage_controller.dart';
import 'package:dcomic/view/components/carousel_item.dart';
import 'package:dcomic/view/components/grid_card.dart';
import 'package:easy_refresh/easy_refresh.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<StatefulWidget> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ComicHomepageController(),
      builder: (context, child) => EasyRefresh(
          onRefresh: () async {
            await Provider.of<ComicHomepageController>(context, listen: false)
                .refresh(context);
          },
          refreshOnStart: true,
          child: Container(
            color: Theme.of(context).colorScheme.surfaceVariant,
            child: ListView(
              shrinkWrap: true,
              children: _buildListView(context),
            ),
          )),
    );
  }

  Widget _buildCarousels(BuildContext context) {
    return CarouselSlider.builder(
      options: CarouselOptions(
        viewportFraction: 0.95,
        enableInfiniteScroll: true,
        autoPlay: true,
        aspectRatio: 3,
        enlargeCenterPage: true,
        enlargeStrategy: CenterPageEnlargeStrategy.height,
      ),
      itemCount: Provider.of<ComicHomepageController>(context)
          .homepageCarousels
          .length,
      itemBuilder: (context, index, realIndex) {
        if (Provider.of<ComicHomepageController>(context)
            .homepageCarousels
            .isEmpty) {
          return Card(
            elevation: 0,
            child: Center(
              child: Text(
                S.of(context).Loading,
                style: TextStyle(color: Theme.of(context).disabledColor),
              ),
            ),
          );
        }
        var entity = Provider.of<ComicHomepageController>(context)
            .homepageCarousels[index];
        return CarouselItem(title:entity.title,cover:entity.cover,onTap: entity.onTap,);
      },
    );
  }

  List<Widget> _buildListView(BuildContext context) {
    List<Widget> data = [_buildCarousels(context)];
    if (Provider.of<ComicHomepageController>(context).homepageCards.isEmpty) {
      for (int i = 0; i < 5; i++) {
        data.add(const GridCardPlaceHolder());
      }
    }
    for (var entity
        in Provider.of<ComicHomepageController>(context).homepageCards) {
      List<Widget> gridCards = [];
      for (var cards in entity.children) {
        gridCards.add(GridCardItem(
          image: cards.cover,
          onTap: cards.onTap == null
              ? null
              : () {
                  cards.onTap!(context);
                },
          title: cards.title,
          subtitle: cards.subtitle,
        ));
      }
      data.add(GridCard(
        entity.title,
        sideIcon: entity.icon,
        crossAxisCount: gridCards.length % 3 == 0 ? 3 : 2,
        onSideIconPressed: entity.onTap == null
            ? null
            : () {
                entity.onTap!(context);
              },
        children: gridCards,
      ));
    }
    return data;
  }
}
