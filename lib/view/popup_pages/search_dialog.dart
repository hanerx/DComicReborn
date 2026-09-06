import 'package:dcomic/providers/models/comic_source_model.dart';
import 'package:dcomic/providers/page_controllers/comic_search_dialog_controller.dart';
import 'package:dcomic/view/components/card_list_item.dart';
import 'package:easy_refresh/easy_refresh.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class SearchDialog extends StatefulWidget {
  final BaseComicSourceModel sourceModel;
  final String title;
  final String comicId;

  const SearchDialog(
      {super.key,
      required this.sourceModel,
      required this.title,
      required this.comicId});

  @override
  State<StatefulWidget> createState() => _SearchDialogState();
}

class _SearchDialogState extends State<SearchDialog> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.title);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<ComicSearchDialogController>(
      create: (_) =>
          ComicSearchDialogController(widget.sourceModel, widget.title),
      builder: (context, child) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            AppBar(
              title: TextField(
                decoration: InputDecoration(
                  hintText: MaterialLocalizations.of(context).searchFieldLabel,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                controller: _controller,
                textInputAction: TextInputAction.search,
                onChanged: (text) {
                  Provider.of<ComicSearchDialogController>(context,
                          listen: false)
                      .pendingKeyword = text;
                },
                onSubmitted: (text) async {
                  Provider.of<ComicSearchDialogController>(context,
                          listen: false)
                      .pendingKeyword = text;
                  FocusScope.of(context).unfocus();
                  await Provider.of<ComicSearchDialogController>(context,
                          listen: false)
                      .search();
                },
              ),
              actions: [
                IconButton(
                    onPressed: () async {
                      FocusScope.of(context).unfocus();
                      await Provider.of<ComicSearchDialogController>(context,
                              listen: false)
                          .search();
                    },
                    icon: const Icon(Icons.search))
              ],
            ),
            Expanded(
                child: EasyRefresh(
                    onRefresh: () async {
                      await Provider.of<ComicSearchDialogController>(context,
                              listen: false)
                          .refresh();
                    },
                    onLoad: () async {
                      await Provider.of<ComicSearchDialogController>(context,
                              listen: false)
                          .load();
                    },
                    refreshOnStart: true,
                    child: ColoredBox(
                      color: Theme.of(context).colorScheme.surface,
                      child: ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.only(top: 4, bottom: 12),
                        itemCount: Provider.of<ComicSearchDialogController>(
                                    context)
                                .data
                                .length +
                            (Provider.of<ComicSearchDialogController>(context)
                                    .hasError
                                ? 1
                                : 0),
                        itemBuilder: (context, index) {
                          final controller =
                              Provider.of<ComicSearchDialogController>(context);
                          if (index == controller.data.length) {
                            final isZh =
                                Localizations.localeOf(context).languageCode ==
                                    'zh';
                            return ListTile(
                              leading: Icon(Icons.cloud_off_rounded,
                                  color: Theme.of(context).colorScheme.error),
                              title: Text(isZh
                                  ? '搜索失败，请重试'
                                  : 'Search failed. Try again.'),
                              trailing: IconButton(
                                tooltip: isZh ? '重试' : 'Retry',
                                icon: const Icon(Icons.refresh_rounded),
                                onPressed: () => controller.data.isEmpty
                                    ? controller.refresh()
                                    : controller.load(),
                              ),
                            );
                          }
                          final entity = controller.data[index];
                          return CardListItem(
                            cover: entity.cover,
                            title: entity.title,
                            details: entity.details,
                            onTap: (context) {
                              Navigator.of(context).pop(entity.comicId);
                            },
                          );
                        },
                      ),
                    )))
          ],
        ),
      ),
    );
  }
}
