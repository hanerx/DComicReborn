import 'package:dcomic/generated/l10n.dart';
import 'package:dcomic/providers/models/comic_source_model.dart';
import 'package:dcomic/providers/page_controllers/comic_category_detail_page_controller.dart';
import 'package:dcomic/view/components/card_list_item.dart';
import 'package:easy_refresh/easy_refresh.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

class ComicCategoryDetailPage extends StatefulWidget {
  final String categoryId;
  final BaseComicSourceModel sourceModel;
  final String categoryTitle;
  final int categoryType;

  const ComicCategoryDetailPage(
      {super.key,
      required this.categoryId,
      required this.sourceModel,
      required this.categoryTitle,
      this.categoryType = 0});

  @override
  State<StatefulWidget> createState() => _ComicCategoryDetailPageState();
}

class _ComicCategoryDetailPageState extends State<ComicCategoryDetailPage> {
  final EasyRefreshController _controller = EasyRefreshController();

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ComicCategoryDetailPageController(
          widget.sourceModel, widget.categoryId,
          categoryType: widget.categoryType),
      builder: (context, child) => Scaffold(
        appBar: AppBar(
          title: Text(widget.categoryTitle),
          actions: [
            IconButton(
                tooltip: S.of(context).TitleCopied,
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: widget.categoryTitle))
                      .then((value) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(S.of(context).TitleCopied),
                      ));
                    }
                  });
                },
                icon: const Icon(Icons.copy))
          ],
        ),
        backgroundColor: Theme.of(context).colorScheme.surface,
        body: Column(
          children: [
            SizedBox(
              width: double.infinity,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: _buildFilter(context),
                ),
              ),
            ),
            Expanded(
                child: EasyRefresh(
                    controller: _controller,
                    onRefresh: () async {
                      await Provider.of<ComicCategoryDetailPageController>(
                              context,
                              listen: false)
                          .refresh();
                    },
                    onLoad: () async {
                      await Provider.of<ComicCategoryDetailPageController>(
                              context,
                              listen: false)
                          .load();
                    },
                    refreshOnStart: true,
                    child: ListView.builder(
                      padding: const EdgeInsets.only(top: 4, bottom: 12),
                      itemCount: Provider.of<ComicCategoryDetailPageController>(
                              context)
                          .data
                          .length,
                      itemBuilder: (context, index) {
                        var entity =
                            Provider.of<ComicCategoryDetailPageController>(
                                    context)
                                .data[index];
                        return CardListItem(
                          cover: entity.cover,
                          title: entity.title,
                          details: entity.details,
                          onTap: entity.onTap,
                        );
                      },
                    )))
          ],
        ),
      ),
    );
  }

  List<Widget> _buildFilter(BuildContext context) {
    var theme = Theme.of(context);
    var controller = Provider.of<ComicCategoryDetailPageController>(context);
    List<Widget> data = [];
    for (var item in controller.homepageModel.categoryFilter) {
      data.add(Padding(
        padding: const EdgeInsets.only(right: 8),
        child: PopupMenuButton(
          offset: const Offset(0, 6),
          position: PopupMenuPosition.under,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          itemBuilder: (context) => [
            for (var menuItem
                in item.getLocalizedMappingChoice(context).entries)
              PopupMenuItem(
                  value: menuItem.value,
                  child: Text(
                    menuItem.key,
                    style: theme.textTheme.bodyMedium,
                  ))
          ],
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            constraints: const BoxConstraints(minHeight: 48),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: theme.colorScheme.outlineVariant),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(item.filterIcon,
                    size: 16, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: 6),
                Text(
                  item.getLocalizedStringByValue(
                      context, controller.filter[item.filterName]),
                  style: theme.textTheme.bodyMedium,
                ),
                Icon(Icons.arrow_drop_down,
                    size: 18, color: theme.colorScheme.onSurfaceVariant),
              ],
            ),
          ),
          onSelected: (object) {
            Provider.of<ComicCategoryDetailPageController>(context,
                    listen: false)
                .setFilterValue(item.filterName, object);
            _controller.callRefresh();
          },
        ),
      ));
    }
    return data;
  }
}
