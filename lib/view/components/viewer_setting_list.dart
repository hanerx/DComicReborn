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
      padding: EdgeInsets.only(
          top: 4, bottom: MediaQuery.paddingOf(context).bottom + 12),
      itemCount: list.length,
      itemBuilder: (context, index) {
        return list[index];
      },
    );
  }

  Widget _buildSectionHeader(BuildContext context, String zh, String other) {
    final isChinese =
        Localizations.localeOf(context).languageCode.startsWith('zh');
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Text(isChinese ? zh : other,
          style: Theme.of(context)
              .textTheme
              .titleSmall
              ?.copyWith(color: Theme.of(context).colorScheme.primary)),
    );
  }

  List<Widget> _buildSettingList(BuildContext context) {
    var config = Provider.of<ConfigProvider>(context);
    final textTheme = Theme.of(context).textTheme;
    final valueStyle = textTheme.labelMedium
        ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant);
    return [
      _buildSectionHeader(context, '阅读', 'Reading'),
      ListTile(
        leading: const Icon(Icons.align_horizontal_left),
        title: Text(S.of(context).ViewerSettingAlign),
        subtitle: SegmentedButton<ReadDirectionType>(
          segments: readDirectionOptions.map<ButtonSegment<ReadDirectionType>>(
              ((ReadDirectionType, IconData) item) {
            return ButtonSegment<ReadDirectionType>(
                value: item.$1, label: Icon(item.$2));
          }).toList(),
          selected: <ReadDirectionType>{config.readDirection},
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
          value: config.drawDebugWidget,
          onChanged: (bool value) {
            Provider.of<ConfigProvider>(context, listen: false)
                .drawDebugWidget = value;
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
              value: config.verticalClickAreaSize,
              label: config.verticalClickAreaSize.toStringAsFixed(2),
              onChanged: config.readDirection == ReadDirectionType.vertical
                  ? (double value) {
                      Provider.of<ConfigProvider>(context, listen: false)
                          .verticalClickAreaSize = value;
                    }
                  : null,
              min: 10,
              max: 300,
            ),
          ),
          trailing: Text(config.verticalClickAreaSize.toStringAsFixed(0),
              style: valueStyle)),
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
              value: config.horizontalClickAreaSize,
              label: config.horizontalClickAreaSize.toStringAsFixed(2),
              onChanged: config.readDirection != ReadDirectionType.vertical
                  ? (double value) {
                      Provider.of<ConfigProvider>(context, listen: false)
                          .horizontalClickAreaSize = value;
                    }
                  : null,
              min: 10,
              max: 200,
            ),
          ),
          trailing: Text(config.horizontalClickAreaSize.toStringAsFixed(0),
              style: valueStyle)),
      _buildSectionHeader(context, '外观', 'Appearance'),
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
                      Icons.circle,
                      color: e.color!,
                    )))
                .toList(),
            selected: <ThemeModel>{config.themeColor},
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
          value: config.useMaterial3Design,
          onChanged: (bool value) {
            Provider.of<ConfigProvider>(context, listen: false)
                .useMaterial3Design = value;
          },
        ),
      ),
    ];
  }
}
