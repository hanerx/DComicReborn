import 'package:dcomic/providers/page_controllers/comic_category_page_controller.dart';
import 'package:dcomic/utils/image_utils.dart';
import 'package:dcomic/view/components/dcomic_image.dart';
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
          child: Container(
            color: Theme.of(context).colorScheme.surfaceVariant,
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3, childAspectRatio: 1 / 1.2),
              itemCount: Provider.of<ComicCategoryPageController>(context)
                  .categories
                  .length,
              itemBuilder: (BuildContext context, int index) {
                var entity = Provider.of<ComicCategoryPageController>(context)
                    .categories[index];
                return GridCardItem(
                  image: entity.cover,
                  onTap: entity.onTap == null
                      ? null
                      : () {
                          entity.onTap!(context);
                        },
                  title: entity.title,
                );
              },
            ),
          )),
    );
  }
}
