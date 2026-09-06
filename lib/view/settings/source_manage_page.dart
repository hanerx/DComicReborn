import 'package:dcomic/generated/l10n.dart';
import 'package:dcomic/providers/source_provider.dart';
import 'package:easy_refresh/easy_refresh.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class SourceManagePage extends StatefulWidget {
  const SourceManagePage({super.key});

  @override
  State<StatefulWidget> createState() {
    return _SourceManagePageState();
  }
}

class _SourceManagePageState extends State<SourceManagePage> {
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(S.of(context).SourceSettings),
      ),
      body: ListTileTheme.merge(
          dense: true,
          minTileHeight: 48,
          minVerticalPadding: 6,
          minLeadingWidth: 24,
          horizontalTitleGap: 12,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          titleTextStyle: Theme.of(context).textTheme.bodyMedium,
          subtitleTextStyle: Theme.of(context).textTheme.bodySmall,
          child: EasyRefresh(
            onRefresh: () {
              Provider.of<ComicSourceProvider>(context, listen: false)
                  .callNotify();
            },
            child: ReorderableListView.builder(
              padding: EdgeInsets.only(
                top: 12,
                bottom: 16 + MediaQuery.paddingOf(context).bottom,
              ),
              itemCount: Provider.of<ComicSourceProvider>(context)
                  .orderedSources
                  .length,
              itemBuilder: (context, index) {
                var sourceModel = Provider.of<ComicSourceProvider>(context)
                    .orderedSources[index];
                return Container(
                  key: ValueKey(sourceModel),
                  margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: colorScheme.outlineVariant),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      ListTile(
                        title: Text(
                          sourceModel.type.sourceName,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        leading: SizedBox(
                          height: 50,
                          width: 50,
                          child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.asset(
                                'assets/sources/${sourceModel.type.sourceId}.png',
                                fit: BoxFit.contain,
                                excludeFromSemantics: true,
                              )),
                        ),
                        subtitle: Text(S
                            .of(context)
                            .SourceProviderDesc(sourceModel.type.sourceId)),
                        trailing: const IconButton(
                          onPressed: null,
                          icon: Icon(Icons.unfold_more),
                        ),
                      ),
                      Divider(height: 1, color: colorScheme.outlineVariant),
                      sourceModel.getSourceSettingWidget(context)
                    ],
                  ),
                );
              },
              onReorder: (int oldIndex, int newIndex) {
                Provider.of<ComicSourceProvider>(context, listen: false)
                    .swapOrder(oldIndex, newIndex);
              },
            ),
          )),
    );
  }
}
