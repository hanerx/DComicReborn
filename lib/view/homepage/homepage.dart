import 'dart:math' as math;

import 'package:carousel_slider_plus/carousel_slider_plus.dart';
import 'package:dcomic/providers/page_controllers/comic_homepage_controller.dart';
import 'package:dcomic/utils/layout_utils.dart';
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
  static const double maxCarouselHeight = 280;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ComicHomepageController(),
      builder: (context, child) => EasyRefresh(
        onRefresh: () async {
          try {
            await Provider.of<ComicHomepageController>(
              context,
              listen: false,
            ).refresh(context);
            return IndicatorResult.success;
          } catch (_) {
            return IndicatorResult.fail;
          }
        },
        refreshOnStart: true,
        child: ColoredBox(
          color: Theme.of(context).colorScheme.surface,
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.only(top: 12, bottom: 24),
            children: _buildListView(context),
          ),
        ),
      ),
    );
  }

  Widget _buildCarousels(BuildContext context) {
    var carousels = Provider.of<ComicHomepageController>(context)
        .homepageCarousels;
    if (carousels.isEmpty) {
      return const SizedBox.shrink();
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        // Show neighbouring banners on wide panes instead of stretching one.
        var width = math.min(constraints.maxWidth, AppLayout.contentMaxWidth);
        final height = math.min(
          maxCarouselHeight,
          MediaQuery.sizeOf(context).height * 0.42,
        );
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppLayout.contentMaxWidth,
            ),
            child: CarouselSlider.builder(
              options: CarouselOptions(
                viewportFraction: width >= AppLayout.navigationBreakpoint
                    ? math.min(0.92, height * 2 / width)
                    : 0.92,
                enableInfiniteScroll: true,
                autoPlay: true,
                aspectRatio: math.max(2, width / height),
                enlargeCenterPage: true,
                enlargeStrategy: CenterPageEnlargeStrategy.height,
              ),
              itemCount: carousels.length,
              itemBuilder: (context, index, realIndex) {
                var entity = carousels[index];
                return CarouselItem(
                  title: entity.title,
                  cover: entity.cover,
                  onTap: entity.onTap,
                );
              },
            ),
          ),
        );
      },
    );
  }

  List<Widget> _buildListView(BuildContext context) {
    var controller = Provider.of<ComicHomepageController>(context);
    List<Widget> data = [];
    if (controller.homepageCarousels.isNotEmpty) {
      data.add(_buildCarousels(context));
      data.add(const SizedBox(height: 24));
    }
    if (controller.homepageCards.isEmpty) {
      for (int i = 0; i < 2; i++) {
        data.add(const GridCardPlaceHolder());
        data.add(const SizedBox(height: 16));
      }
    }
    for (var entity in controller.homepageCards) {
      data.add(
        GridCard(
          entity.title,
          sideIcon: entity.icon,
          crossAxisCount:
              entity.crossAxisCount ??
              (entity.children.length % 3 == 0 ? 3 : 2),
          coverAspectRatio: entity.coverAspectRatio,
          onSideIconPressed: entity.onTap == null
              ? null
              : () {
                  entity.onTap!(context);
                },
          reserveSubtitle: entity.children.any(
            (cards) => (cards.subtitle ?? '').isNotEmpty,
          ),
          children: [
            for (var cards in entity.children)
              GridCardItem(
                image: cards.cover,
                coverAspectRatio: entity.coverAspectRatio,
                onTap: cards.onTap == null
                    ? null
                    : () {
                        cards.onTap!(context);
                      },
                title: cards.title,
                subtitle: cards.subtitle,
              ),
          ],
        ),
      );
      data.add(const SizedBox(height: 16));
    }
    return data;
  }
}
