import 'package:dcomic/generated/l10n.dart';
import 'package:dcomic/providers/comic_veiwer_config_provider.dart';
import 'package:dcomic/providers/config_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class ViewerSettingList extends StatelessWidget {
  const ViewerSettingList({super.key});

  static const List<(ReadDirectionType, IconData)

  >

  readDirectionOptions

  =

  [

  (ReadDirectionType.left, Icons.align_horizontal_left)

  ,

  (ReadDirectionType.right, Icons.align_horizontal_right)

  ,

  (ReadDirectionType.vertical, Icons.align_vertical_top)

  ];

  @override
  Widget build(BuildContext context) {
    var list = _buildSettingList(context);
    return ListView.builder(
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      itemCount: list.length,
      itemBuilder: (context, index) {
        return list[index];
      },
    );
  }

  List<Widget> _buildSettingList(BuildContext context) {
    return [
      ListTile(
        leading: const Icon(Icons.align_horizontal_left),
        title: Text(S
            .of(context)
            .ViewerSettingAlign),
        subtitle: SegmentedButton<ReadDirectionType>(
          segments: readDirectionOptions
              .map<ButtonSegment<ReadDirectionType>>((
              (ReadDirectionType, IconData) item) {
            return ButtonSegment<ReadDirectionType>(
                value: item.$1, label: Icon(item.$2));
          }).toList(),
          selected: <ReadDirectionType>{Provider
              .of<ConfigProvider>(context)
              .readDirection},
          onSelectionChanged: (output) {
            Provider
                .of<ConfigProvider>(context, listen: false)
                .readDirection = output.first;
          },
        ),
      ),
      ListTile(
        leading: const Icon(Icons.bug_report_outlined),
        title: Text(S
            .of(context)
            .ViewerSettingAlign),
        trailing: Switch(
          value: Provider
              .of<ComicViewerConfigProvider>(context)
              .drawDebugWidget,
          onChanged: (bool value) {
            Provider
                .of<ComicViewerConfigProvider>(context, listen: false)
                .drawDebugWidget = !Provider
                .of<ComicViewerConfigProvider>(context, listen: false)
                .drawDebugWidget;
          },
        ),
      ),
    ];
  }

}