import 'package:dcomic/generated/l10n.dart';
import 'package:dcomic/providers/models/comic_source_model.dart';
import 'package:dcomic/providers/page_controllers/comic_history_page_controller.dart';
import 'package:dcomic/providers/source_provider.dart';
import 'package:dcomic/view/components/card_list_item.dart';
import 'package:easy_refresh/easy_refresh.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<StatefulWidget> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  final Map<ComicHistorySourceType, IconData> _iconMap = {
    ComicHistorySourceType.network: Icons.network_cell,
    ComicHistorySourceType.local: Icons.sd_storage
  };

  Future<IndicatorResult> _loadHistory(
      BuildContext context, Future<void> Function() action) async {
    try {
      await action();
      return IndicatorResult.success;
    } catch (_) {
      if (context.mounted) {
        final isChinese = Localizations.localeOf(context).languageCode == 'zh';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(isChinese
                ? '历史记录加载失败，请检查网络和对应漫画源的登录状态后重试'
                : 'Could not load history. Check your connection and source login, then retry.')));
      }
      return IndicatorResult.fail;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
        create: (_) => ComicHistoryPageController(
            Provider.of<ComicSourceProvider>(context).orderedSources),
        builder: (context, child) => DefaultTabController(
            length:
                Provider.of<ComicSourceProvider>(context).orderedSources.length,
            child: Scaffold(
              appBar: AppBar(
                title: Text(S.of(context).DrawerHistory),
                actions: [
                  IconButton(
                      onPressed: () => _loadHistory(
                          context,
                          Provider.of<ComicHistoryPageController>(context,
                                  listen: false)
                              .addSourceType),
                      icon: Icon(_iconMap[
                          Provider.of<ComicHistoryPageController>(context)
                              .sourceType]))
                ],
                bottom: TabBar(
                  isScrollable: true,
                  tabs: [
                    for (var item in Provider.of<ComicSourceProvider>(context)
                        .hasAccountSettingSources)
                      Tab(
                        text: item.type.sourceName,
                      )
                  ],
                ),
              ),
              backgroundColor: Theme.of(context).colorScheme.surface,
              body: TabBarView(children: [
                for (var item
                    in Provider.of<ComicSourceProvider>(context).orderedSources)
                  Builder(builder: (context) {
                    final controller =
                        context.watch<ComicHistoryPageController>();
                    final records =
                        controller.data[item]?.data[controller.sourceType] ??
                            const <ListItemEntity>[];
                    return EasyRefresh(
                        onRefresh: () => _loadHistory(
                            context,
                            () => Provider.of<ComicHistoryPageController>(
                                    context,
                                    listen: false)
                                .refresh(item)),
                        onLoad: () => _loadHistory(
                            context,
                            () => Provider.of<ComicHistoryPageController>(
                                    context,
                                    listen: false)
                                .load(item)),
                        refreshOnStart: true,
                        child: ListView.builder(
                          padding: const EdgeInsets.only(top: 4, bottom: 12),
                          itemCount: records.length,
                          itemBuilder: (context, index) {
                            final entity = records[index];
                            return CardListItem(
                              cover: entity.cover,
                              title: entity.title,
                              details: entity.details,
                              onTap: entity.onTap,
                            );
                          },
                        ));
                  })
              ]),
            )));
  }
}
