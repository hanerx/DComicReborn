import 'package:dcomic/providers/models/comic_source_model.dart';
import 'package:dcomic/providers/page_controllers/comic_search_dialog_controller.dart';
import 'package:dcomic/view/components/card_list_item.dart';
import 'package:easy_refresh/easy_refresh.dart';
import 'package:flutter/cupertino.dart';
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
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<ComicSearchDialogController>(
      create: (_) =>
          ComicSearchDialogController(widget.sourceModel, widget.title),
      builder: (context, child) => Dialog(
          child: ClipRRect(
        borderRadius: const BorderRadius.all(Radius.circular(5)),
        child: Column(
          children: [
            AppBar(
              title: TextField(
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
                    child: Container(
                      height: double.infinity,
                      color:
                          Theme.of(context).colorScheme.surfaceContainerHighest,
                      child: GridView.builder(
                        shrinkWrap: true,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 1, childAspectRatio: 3 / 1),
                        itemCount:
                            Provider.of<ComicSearchDialogController>(context)
                                .data
                                .length,
                        itemBuilder: (context, index) {
                          var entity =
                              Provider.of<ComicSearchDialogController>(context)
                                  .data[index];
                          return CardListItem(
                            cover: entity.cover,
                            title: entity.title,
                            details: entity.details,
                            onTap: (context) async {
                              Navigator.of(context).pop(entity.comicId);
                            },
                          );
                        },
                      ),
                    )))
          ],
        ),
      )),
    );
  }
}
