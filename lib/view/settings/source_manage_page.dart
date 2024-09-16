import 'package:dcomic/generated/l10n.dart';
import 'package:dcomic/providers/navigator_provider.dart';
import 'package:dcomic/providers/source_provider.dart';
import 'package:dcomic/view/components/dcomic_image.dart';
import 'package:dcomic/view/settings/account_login_page.dart';
import 'package:easy_refresh/easy_refresh.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class SourceManagePage extends StatefulWidget {
  const SourceManagePage({super.key});

  @override
  State<StatefulWidget> createState() => _SourceManagePageState();
}

class _SourceManagePageState extends State<SourceManagePage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          elevation: 0,
          title: Text(S.of(context).SourceSettings),
        ),
        body: Container(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: EasyRefresh(
            onRefresh: () {
              Provider.of<ComicSourceProvider>(context, listen: false)
                  .callNotify();
            },
            child: ReorderableListView.builder(
              itemCount: Provider.of<ComicSourceProvider>(context)
                  .orderedSources
                  .length,
              itemBuilder: (context, index) {
                var sourceModel = Provider.of<ComicSourceProvider>(context)
                    .orderedSources[index];
                return Card(
                    key: ValueKey(sourceModel),
                    elevation: 0,
                    margin: const EdgeInsets.all(10),
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
                                borderRadius: BorderRadius.circular(5),
                                child: const FlutterLogo()
                            ),
                          ),
                          subtitle: Text(S.of(context).SourceProviderDesc(sourceModel.type.sourceId)),
                          trailing: const IconButton(
                            onPressed: null,
                            icon: Icon(Icons.unfold_more),
                          ),
                        ),
                        const Divider(height: 1,),
                        sourceModel.getSourceSettingWidget(context)
                      ],
                    ));
              },
              onReorder: (int oldIndex, int newIndex) {
                Provider.of<ComicSourceProvider>(context, listen: false).swapOrder(oldIndex, newIndex);
              },
            ),
          ),
        ));
  }
}
