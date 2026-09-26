import 'package:dcomic/generated/l10n.dart';
import 'package:dcomic/providers/source_provider.dart';
import 'package:dcomic/utils/layout_utils.dart';
import 'package:dcomic/view/components/settings_widgets.dart';
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
  final Set<String> _collapsedSourceIds = {};

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SettingsPage(
      title: Text(S.of(context).SourceSettings),
      body: EasyRefresh(
        onRefresh: () {
          Provider.of<ComicSourceProvider>(context, listen: false).callNotify();
        },
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: AppLayout.formMaxWidth),
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
                var sourceId = sourceModel.type.sourceId;
                var expanded = !_collapsedSourceIds.contains(sourceId);
                return SettingsCard(
                  key: ValueKey(sourceModel),
                  margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ListTile(
                        contentPadding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
                        onTap: () {
                          setState(() {
                            if (expanded) {
                              _collapsedSourceIds.add(sourceId);
                            } else {
                              _collapsedSourceIds.remove(sourceId);
                            }
                          });
                        },
                        title: Text(
                          sourceModel.type.sourceName,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        leading: SizedBox(
                          height: 48,
                          width: 48,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.asset(
                              'assets/sources/$sourceId.png',
                              fit: BoxFit.contain,
                              excludeFromSemantics: true,
                            ),
                          ),
                        ),
                        subtitle: Text(
                          S.of(context).SourceProviderDesc(sourceId),
                        ),
                        trailing: AnimatedRotation(
                          turns: expanded ? 0.5 : 0,
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeOutCubic,
                          child: const SettingsIcon(
                            child: Icon(Icons.expand_more),
                          ),
                        ),
                      ),
                      Visibility(
                        visible: expanded,
                        maintainState: true,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Divider(
                              height: 1,
                              color: colorScheme.outlineVariant.withValues(
                                alpha: 0.3,
                              ),
                            ),
                            sourceModel.getSourceSettingWidget(context),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
              onReorder: (int oldIndex, int newIndex) {
                Provider.of<ComicSourceProvider>(
                  context,
                  listen: false,
                ).swapOrder(oldIndex, newIndex);
              },
            ),
          ),
        ),
      ),
    );
  }
}
