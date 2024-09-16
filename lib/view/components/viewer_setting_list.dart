import 'dart:math';

import 'package:dcomic/generated/l10n.dart';
import 'package:dcomic/providers/config_provider.dart';
import 'package:dcomic/utils/theme_utils.dart';
import 'package:flutter/material.dart';
import 'package:fluttericon/font_awesome5_icons.dart';
import 'package:provider/provider.dart';

class ViewerSettingList extends StatelessWidget {
  const ViewerSettingList({super.key});

  static const List<(ReadDirectionType, IconData)> readDirectionOptions = [
    (ReadDirectionType.left, Icons.align_horizontal_left),
    (ReadDirectionType.right, Icons.align_horizontal_right),
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
        title: Text(S.of(context).ViewerSettingAlign),
        subtitle: SegmentedButton<ReadDirectionType>(
          segments: readDirectionOptions.map<ButtonSegment<ReadDirectionType>>(
              ((ReadDirectionType, IconData) item) {
            return ButtonSegment<ReadDirectionType>(
                value: item.$1, label: Icon(item.$2));
          }).toList(),
          selected: <ReadDirectionType>{
            Provider.of<ConfigProvider>(context).readDirection
          },
          onSelectionChanged: (output) {
            Provider.of<ConfigProvider>(context, listen: false).readDirection =
                output.first;
          },
        ),
      ),
      ListTile(
        leading: const Icon(Icons.bug_report_outlined),
        title: Text(S.of(context).ViewerSettingDebugView),
        trailing: Switch(
          value: Provider.of<ConfigProvider>(context).drawDebugWidget,
          onChanged: (bool value) {
            Provider.of<ConfigProvider>(context, listen: false)
                    .drawDebugWidget =
                !Provider.of<ConfigProvider>(context, listen: false)
                    .drawDebugWidget;
          },
        ),
      ),
      ListTile(
          leading: const Icon(Icons.expand),
          title: Text(S.of(context).ViewerSettingVerticalSize),
          subtitle: SliderTheme(
            data: const SliderThemeData(
                showValueIndicator: ShowValueIndicator.always),
            child: Slider(
              value: Provider.of<ConfigProvider>(context).verticalClickAreaSize,
              label: Provider.of<ConfigProvider>(context)
                  .verticalClickAreaSize
                  .toStringAsFixed(2),
              onChanged: Provider.of<ConfigProvider>(context).readDirection ==
                      ReadDirectionType.vertical
                  ? (double value) {
                      Provider.of<ConfigProvider>(context, listen: false)
                          .verticalClickAreaSize = value;
                    }
                  : null,
              min: 10,
              max: 300,
            ),
          )),
      ListTile(
          leading: Transform.rotate(
            angle: 90 * pi / 180,
            child: const Icon(Icons.expand),
          ),
          title: Text(S.of(context).ViewerSettingHorizontalSize),
          subtitle: SliderTheme(
            data: const SliderThemeData(
                showValueIndicator: ShowValueIndicator.always),
            child: Slider(
              value:
                  Provider.of<ConfigProvider>(context).horizontalClickAreaSize,
              label: Provider.of<ConfigProvider>(context)
                  .horizontalClickAreaSize
                  .toStringAsFixed(2),
              onChanged: Provider.of<ConfigProvider>(context).readDirection !=
                      ReadDirectionType.vertical
                  ? (double value) {
                      Provider.of<ConfigProvider>(context, listen: false)
                          .horizontalClickAreaSize = value;
                    }
                  : null,
              min: 10,
              max: 200,
            ),
          )),
      const Divider(),
      ListTile(
        leading: const Icon(Icons.color_lens),
        title: Text(S.of(context).ViewerSettingThemeColor),
        subtitle: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SegmentedButton<ThemeModel>(
            showSelectedIcon: false,
            segments: ThemeModel.themes.values
                .map<ButtonSegment<ThemeModel>>((e) => ButtonSegment(
                    value: e,
                    icon: Icon(
                      Icons.photo,
                      color: e.color!,
                    )))
                .toList(),
            selected: <ThemeModel>{
              Provider.of<ConfigProvider>(context).themeColor
            },
            onSelectionChanged: (output) {
              Provider.of<ConfigProvider>(context, listen: false).themeColor =
                  output.first;
            },
          ),
        ),
      ),
      ListTile(
        leading: const Icon(FontAwesome5.google),
        title: Text(S.of(context).ViewerSettingUseMaterial3Design),
        subtitle: Text(S.of(context).ViewerSettingUseMaterial3DesignSubTitle),
        trailing: Switch(
          value: Provider.of<ConfigProvider>(context).useMaterial3Design,
          onChanged: (bool value) {
            Provider.of<ConfigProvider>(context, listen: false)
                .useMaterial3Design =
            !Provider.of<ConfigProvider>(context, listen: false)
                .useMaterial3Design;
          },
        ),
      ),
    ];
  }
}
