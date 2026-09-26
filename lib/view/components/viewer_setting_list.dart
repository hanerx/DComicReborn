import 'dart:math';

import 'package:dcomic/generated/l10n.dart';
import 'package:dcomic/providers/config_provider.dart';
import 'package:dcomic/providers/page_controllers/comic_viewer_page_controller.dart';
import 'package:dcomic/utils/theme_utils.dart';
import 'package:dcomic/view/components/settings_widgets.dart';
import 'package:flutter/material.dart';
import 'package:fluttericon/font_awesome5_icons.dart';
import 'package:provider/provider.dart';

/// Reader settings shared by the standalone settings page and the in-reader
/// bottom sheet. Reads the optional live viewer controller when opened inside
/// the reader (long comics keep their effective read direction) and falls back
/// to the global config otherwise.
class ViewerSettingList extends StatelessWidget {
  const ViewerSettingList({super.key});

  static const List<(ReadDirectionType, IconData)> readDirectionOptions = [
    (ReadDirectionType.left, Icons.align_horizontal_left),
    (ReadDirectionType.right, Icons.align_horizontal_right),
    (ReadDirectionType.vertical, Icons.align_vertical_top),
  ];

  @override
  Widget build(BuildContext context) {
    return ListView(
      shrinkWrap: true,
      padding: EdgeInsets.fromLTRB(
        12,
        12,
        12,
        MediaQuery.paddingOf(context).bottom + 16,
      ),
      children: _buildSettingList(context),
    );
  }

  List<Widget> _buildSettingList(BuildContext context) {
    var config = Provider.of<ConfigProvider>(context);
    final viewer = context.watch<ComicViewerPageController?>();
    final direction =
        viewer?.effectiveReadDirection(config.readDirection) ??
        config.readDirection;
    final textTheme = Theme.of(context).textTheme;
    final valueStyle = textTheme.labelMedium?.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );
    final isChinese = Localizations.localeOf(context).languageCode
        .startsWith('zh');
    return [
      SettingsSection(title: isChinese ? '阅读' : 'Reading'),
      SettingsGroup(
        children: [
          SettingsTile(
            leading: const Icon(Icons.align_horizontal_left),
            title: Text(S.of(context).ViewerSettingAlign),
            subtitle: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SegmentedButton<ReadDirectionType>(
                segments: readDirectionOptions
                    .map<ButtonSegment<ReadDirectionType>>((
                      (ReadDirectionType, IconData) item,
                    ) {
                      return ButtonSegment<ReadDirectionType>(
                        value: item.$1,
                        label: Icon(item.$2),
                      );
                    })
                    .toList(),
                selected: <ReadDirectionType>{direction},
                onSelectionChanged: (output) {
                  if (viewer?.detailModel.isLongComic == true) {
                    viewer!.readDirection = output.first;
                  } else {
                    config.readDirection = output.first;
                  }
                },
              ),
            ),
          ),
          SettingsTile(
            leading: const Icon(Icons.bug_report_outlined),
            title: Text(S.of(context).ViewerSettingDebugView),
            trailing: Switch(
              value: config.drawDebugWidget,
              onChanged: (bool value) {
                Provider.of<ConfigProvider>(
                  context,
                  listen: false,
                ).drawDebugWidget = value;
              },
            ),
          ),
          SettingsTile(
            leading: const Icon(Icons.expand),
            title: Text(S.of(context).ViewerSettingVerticalSize),
            subtitle: SliderTheme(
              data: const SliderThemeData(
                showValueIndicator: ShowValueIndicator.always,
              ),
              child: Slider(
                value: config.verticalClickAreaSize,
                label: config.verticalClickAreaSize.toStringAsFixed(2),
                onChanged: direction == ReadDirectionType.vertical
                    ? (double value) {
                        Provider.of<ConfigProvider>(
                          context,
                          listen: false,
                        ).verticalClickAreaSize = value;
                      }
                    : null,
                min: 10,
                max: 300,
              ),
            ),
            trailing: Text(
              config.verticalClickAreaSize.toStringAsFixed(0),
              style: valueStyle,
            ),
          ),
          SettingsTile(
            leading: Transform.rotate(
              angle: 90 * pi / 180,
              child: const Icon(Icons.expand),
            ),
            title: Text(S.of(context).ViewerSettingHorizontalSize),
            subtitle: SliderTheme(
              data: const SliderThemeData(
                showValueIndicator: ShowValueIndicator.always,
              ),
              child: Slider(
                value: config.horizontalClickAreaSize,
                label: config.horizontalClickAreaSize.toStringAsFixed(2),
                onChanged: direction != ReadDirectionType.vertical
                    ? (double value) {
                        Provider.of<ConfigProvider>(
                          context,
                          listen: false,
                        ).horizontalClickAreaSize = value;
                      }
                    : null,
                min: 10,
                max: 200,
              ),
            ),
            trailing: Text(
              config.horizontalClickAreaSize.toStringAsFixed(0),
              style: valueStyle,
            ),
          ),
        ],
      ),
      SettingsSection(title: isChinese ? '外观' : 'Appearance'),
      SettingsGroup(
        children: [
          SettingsTile(
            leading: const Icon(Icons.contrast),
            title: Text(isChinese ? '阅读面板配色' : 'Reader panel theme'),
            subtitle: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SegmentedButton<ReaderTheme>(
                showSelectedIcon: false,
                segments: [
                  for (final option in ReaderTheme.values)
                    ButtonSegment(
                      value: option,
                      tooltip: switch (option) {
                        ReaderTheme.app => isChinese ? '跟随应用' : 'App theme',
                        ReaderTheme.white => isChinese ? '纯白' : 'White',
                        ReaderTheme.light => isChinese ? '浅色' : 'Light',
                        ReaderTheme.dark => isChinese ? '深色' : 'Dark',
                        ReaderTheme.black => isChinese ? '纯黑' : 'Black',
                      },
                      icon: option == ReaderTheme.app
                          ? const Icon(Icons.brightness_auto_outlined)
                          : Container(
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Theme.of(context).colorScheme.outline,
                                ),
                                color: option.surfaceColor,
                              ),
                            ),
                    ),
                ],
                selected: <ReaderTheme>{config.readerTheme},
                onSelectionChanged: (output) {
                  config.readerTheme = output.first;
                },
              ),
            ),
          ),
          SettingsTile(
            leading: const Icon(Icons.color_lens),
            title: Text(S.of(context).ViewerSettingThemeColor),
            subtitle: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SegmentedButton<ThemeModel>(
                showSelectedIcon: false,
                segments: ThemeModel.themes.values
                    .map<ButtonSegment<ThemeModel>>(
                      (e) => ButtonSegment(
                        value: e,
                        icon: Icon(Icons.circle, color: e.color!),
                      ),
                    )
                    .toList(),
                selected: <ThemeModel>{config.themeColor},
                onSelectionChanged: (output) {
                  Provider.of<ConfigProvider>(
                    context,
                    listen: false,
                  ).themeColor = output.first;
                },
              ),
            ),
          ),
          SettingsTile(
            leading: const Icon(FontAwesome5.google),
            title: Text(S.of(context).ViewerSettingUseMaterial3Design),
            subtitle: Text(
              S.of(context).ViewerSettingUseMaterial3DesignSubTitle,
            ),
            trailing: Switch(
              value: config.useMaterial3Design,
              onChanged: (bool value) {
                Provider.of<ConfigProvider>(
                  context,
                  listen: false,
                ).useMaterial3Design = value;
              },
            ),
          ),
        ],
      ),
    ];
  }
}
