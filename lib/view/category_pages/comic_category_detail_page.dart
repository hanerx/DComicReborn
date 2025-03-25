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
          widget.sourceModel, widget.categoryId, categoryType:widget.categoryType),
      builder: (context, child) => Scaffold(
        appBar: AppBar(
          elevation: 0,
          title: Text(widget.categoryTitle),
          actions: [
            IconButton(onPressed: (){
              Clipboard.setData(ClipboardData(text: widget.categoryTitle)).then((value){
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(S.of(context).TitleCopied),
                  ));
                }
              });
            }, icon: Icon(Icons.copy))
          ],
        ),
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        body: Column(
          children: [
            Card(
              elevation: 0,
              margin: const EdgeInsets.only(bottom: 5),
              shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.only(
                      bottomRight: Radius.circular(10),
                      bottomLeft: Radius.circular(10))),
              child: ChipTheme(
                  data: ChipThemeData(
                      backgroundColor:
                          Theme.of(context).colorScheme.primaryContainer,
                      iconTheme: Theme.of(context).iconTheme),
                  child: Row(
                    children: _buildFilter(context),
                  )),
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
                    child: SizedBox.expand(
                      child: GridView.builder(
                        shrinkWrap: true,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 1, childAspectRatio: 3 / 1),
                        itemCount:
                            Provider.of<ComicCategoryDetailPageController>(
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
                      ),
                    )))
          ],
        ),
      ),
    );
  }

  List<Widget> _buildFilter(BuildContext context) {
    List<Widget> data = [];
    for (var item in Provider.of<ComicCategoryDetailPageController>(context)
        .homepageModel
        .categoryFilter) {
      data.add(Padding(
        padding: const EdgeInsets.fromLTRB(10, 1, 1, 1),
        child: PopupMenuButton(
          offset: const Offset(0, 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          itemBuilder: (context) => [
            for (var menuItem
                in item.getLocalizedMappingChoice(context).entries)
              PopupMenuItem(
                  height: 10,
                  value: menuItem.value,
                  child: Chip(
                    visualDensity: const VisualDensity(vertical: -4),
                    label: Text(menuItem.key),
                  ))
          ],
          child: Chip(
            side: BorderSide(color: Theme.of(context).colorScheme.surfaceTint),
            visualDensity: const VisualDensity(vertical: -3),
            avatar: CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: Icon(item.filterIcon),
            ),
            label: Row(
              children: [
                Text(item.getLocalizedStringByValue(
                    context,
                    Provider.of<ComicCategoryDetailPageController>(context)
                        .filter[item.filterName])),
                const Icon(Icons.arrow_drop_down)
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
