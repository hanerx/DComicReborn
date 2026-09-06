import 'package:dcomic/providers/page_controllers/comic_category_page_controller.dart';
import 'package:dcomic/view/components/grid_card.dart';
import 'package:easy_refresh/easy_refresh.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class CategoryPage extends StatefulWidget {
  const CategoryPage({super.key});

  @override
  State<StatefulWidget> createState() => _CategoryPageState();
}

class _CategoryPageState extends State<CategoryPage> {
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<ComicCategoryPageController>(
      create: (_) => ComicCategoryPageController(),
      builder: (context, child) => EasyRefresh(
          refreshOnStart: true,
          onRefresh: () async {
            await Provider.of<ComicCategoryPageController>(context,
                    listen: false)
                .refresh(context);
          },
          child: LayoutBuilder(builder: (context, constraints) {
            var categories =
                Provider.of<ComicCategoryPageController>(context).categories;
            const coverAspectRatio = 1.0;
            return ColoredBox(
              color: Theme.of(context).colorScheme.surface,
              child: GridView.builder(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                gridDelegate: GridCardItem.coverGridDelegate(context,
                    gridWidth: constraints.maxWidth - 32,
                    crossAxisCount: 3,
                    coverAspectRatio: coverAspectRatio,
                    hasSubtitle: false),
                itemCount: categories.length,
                itemBuilder: (BuildContext context, int index) {
                  var entity = categories[index];
                  return GridCardItem(
                    image: entity.cover,
                    coverAspectRatio: coverAspectRatio,
                    onTap: entity.onTap == null
                        ? null
                        : () {
                            entity.onTap!(context);
                          },
                    title: entity.title,
                  );
                },
              ),
            );
          })),
    );
  }
}
