import 'dart:math';

import 'package:dcomic/generated/l10n.dart';
import 'package:dcomic/providers/config_provider.dart';
import 'package:dcomic/providers/page_controllers/comic_viewer_page_controller.dart';
import 'package:dcomic/utils/reader_image_fit.dart';
import 'package:dcomic/utils/reader_info_settings.dart';
import 'package:dcomic/utils/theme_utils.dart';
import 'package:dcomic/view/components/settings_widgets.dart';
import 'package:flutter/gestures.dart';
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

  static const horizontalImageFitOptions = <ReaderImageFit>[
    ReaderImageFit.original,
    ReaderImageFit.actualSize,
    ReaderImageFit.contain,
    ReaderImageFit.cover,
    ReaderImageFit.stretch,
    ReaderImageFit.fitHeight,
  ];

  static const verticalImageFitOptions = <ReaderImageFit>[
    ReaderImageFit.original,
    ReaderImageFit.actualSize,
    ReaderImageFit.contain,
    ReaderImageFit.cover,
    ReaderImageFit.stretch,
    ReaderImageFit.fitWidth,
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
            subtitle: _HorizontalSettingsStrip(
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
            leading: const Icon(Icons.last_page),
            title: Text(isChinese ? '末尾按钮行为' : 'End button action'),
            subtitle: _HorizontalSettingsStrip(
              child: SegmentedButton<ReaderEndAction>(
                segments: [
                  ButtonSegment(
                    value: ReaderEndAction.nextChapter,
                    label: Text(isChinese ? '下一章' : 'Next chapter'),
                  ),
                  ButtonSegment(
                    value: ReaderEndAction.comments,
                    label: Text(isChinese ? '吐槽页' : 'Comments page'),
                  ),
                ],
                selected: {config.readerEndAction},
                onSelectionChanged: (selection) {
                  config.readerEndAction = selection.first;
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
            enabled: direction != ReadDirectionType.vertical,
            leading: const Icon(Icons.fit_screen),
            title: Text(isChinese ? '横向图片填充' : 'Horizontal image fill'),
            subtitle: _imageFitSelector(
              isChinese: isChinese,
              enabled: direction != ReadDirectionType.vertical,
              disabledMessage: isChinese
                  ? '仅在横向阅读时可调整'
                  : 'Available only while reading horizontally',
              value: config.horizontalImageFit,
              options: horizontalImageFitOptions,
              onChanged: (value) => config.horizontalImageFit = value,
            ),
          ),
          SettingsTile(
            enabled: direction == ReadDirectionType.vertical,
            leading: const Icon(Icons.fit_screen_outlined),
            title: Text(isChinese ? '纵向图片填充' : 'Vertical image fill'),
            subtitle: _imageFitSelector(
              isChinese: isChinese,
              enabled: direction == ReadDirectionType.vertical,
              disabledMessage: isChinese
                  ? '仅在纵向阅读时可调整'
                  : 'Available only while reading vertically',
              value: config.verticalImageFit,
              options: verticalImageFitOptions,
              onChanged: (value) => config.verticalImageFit = value,
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
      SettingsSection(title: isChinese ? '阅读信息' : 'Reading information'),
      SettingsGroup(
        children: [
          SettingsTile(
            leading: const Icon(Icons.info_outline),
            title: Text(isChinese ? '显示阅读信息' : 'Show reading information'),
            trailing: Switch(
              value: config.readerInfoEnabled,
              onChanged: (value) => config.readerInfoEnabled = value,
            ),
          ),
          SettingsTile(
            enabled: config.readerInfoEnabled,
            leading: const Icon(Icons.picture_in_picture_alt_outlined),
            title: Text(isChinese ? '位置' : 'Position'),
            subtitle: _HorizontalSettingsStrip(
              child: SegmentedButton<ReaderInfoPosition>(
                showSelectedIcon: false,
                segments: [
                  for (final position in ReaderInfoPosition.values)
                    ButtonSegment(
                      value: position,
                      label: Text(_positionLabel(position, isChinese)),
                    ),
                ],
                selected: {config.readerInfoPosition},
                onSelectionChanged: config.readerInfoEnabled
                    ? (selection) {
                        config.readerInfoPosition = selection.first;
                      }
                    : null,
              ),
            ),
          ),
          SettingsTile(
            enabled: config.readerInfoEnabled,
            leading: const Icon(Icons.battery_std),
            title: Text(isChinese ? '电池显示' : 'Battery display'),
            subtitle: _HorizontalSettingsStrip(
              child: SegmentedButton<ReaderBatteryFormat>(
                showSelectedIcon: false,
                segments: [
                  for (final format in ReaderBatteryFormat.values)
                    ButtonSegment(
                      value: format,
                      label: Text(_batteryFormatLabel(format, isChinese)),
                    ),
                ],
                selected: {config.readerBatteryFormat},
                onSelectionChanged: config.readerInfoEnabled
                    ? (selection) {
                        config.readerBatteryFormat = selection.first;
                      }
                    : null,
              ),
            ),
          ),
          SettingsTile(
            enabled: config.readerInfoEnabled,
            leading: const Icon(Icons.menu_book_outlined),
            title: Text(isChinese ? '页码显示' : 'Page display'),
            subtitle: _HorizontalSettingsStrip(
              child: SegmentedButton<ReaderPageFormat>(
                showSelectedIcon: false,
                segments: [
                  for (final format in ReaderPageFormat.values)
                    ButtonSegment(
                      value: format,
                      label: Text(_pageFormatLabel(format, isChinese)),
                    ),
                ],
                selected: {config.readerPageFormat},
                onSelectionChanged: config.readerInfoEnabled
                    ? (selection) {
                        config.readerPageFormat = selection.first;
                      }
                    : null,
              ),
            ),
          ),
          SettingsTile(
            enabled: config.readerInfoEnabled,
            leading: const Icon(Icons.title),
            title: Text(isChinese ? '章节标题' : 'Chapter title'),
            trailing: Switch(
              value: config.readerInfoChapter,
              onChanged: config.readerInfoEnabled
                  ? (value) => config.readerInfoChapter = value
                  : null,
            ),
          ),
          SettingsTile(
            enabled: config.readerInfoEnabled,
            leading: const Icon(Icons.schedule),
            title: Text(isChinese ? '时间' : 'Time'),
            trailing: Switch(
              value: config.readerInfoTime,
              onChanged: config.readerInfoEnabled
                  ? (value) => config.readerInfoTime = value
                  : null,
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
            subtitle: _HorizontalSettingsStrip(
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
            subtitle: _HorizontalSettingsStrip(
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

  Widget _imageFitSelector({
    required bool isChinese,
    required bool enabled,
    required String disabledMessage,
    required ReaderImageFit value,
    required List<ReaderImageFit> options,
    required ValueChanged<ReaderImageFit> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!enabled) ...[Text(disabledMessage), const SizedBox(height: 4)],
        _HorizontalSettingsStrip(
          child: SegmentedButton<ReaderImageFit>(
            showSelectedIcon: false,
            segments: [
              for (final option in options)
                ButtonSegment(
                  value: option,
                  tooltip: _imageFitLabel(option, isChinese),
                  icon: Icon(switch (option) {
                    ReaderImageFit.original => Icons.image_outlined,
                    ReaderImageFit.actualSize => Icons.photo_size_select_actual,
                    ReaderImageFit.contain => Icons.fit_screen,
                    ReaderImageFit.cover => Icons.crop,
                    ReaderImageFit.stretch => Icons.open_in_full,
                    ReaderImageFit.fitWidth => Icons.swap_horiz,
                    ReaderImageFit.fitHeight => Icons.swap_vert,
                  }),
                ),
            ],
            selected: {value},
            onSelectionChanged: enabled
                ? (selection) => onChanged(selection.first)
                : null,
          ),
        ),
        const SizedBox(height: 4),
        Text(_imageFitLabel(value, isChinese)),
      ],
    );
  }

  String _imageFitLabel(ReaderImageFit fit, bool isChinese) {
    return switch (fit) {
      ReaderImageFit.original =>
        isChinese ? '原始大小（保持现有行为）' : 'Original (legacy behavior)',
      ReaderImageFit.actualSize =>
        isChinese ? '实际大小（不缩放）' : 'Actual size (no scaling)',
      ReaderImageFit.contain =>
        isChinese ? '适应屏幕（等比缩放）' : 'Fit screen (keep aspect ratio)',
      ReaderImageFit.cover => isChinese ? '铺满屏幕（等比裁切）' : 'Cover',
      ReaderImageFit.stretch => isChinese ? '拉伸填充' : 'Stretch',
      ReaderImageFit.fitWidth => isChinese ? '填充宽度' : 'Fit width',
      ReaderImageFit.fitHeight => isChinese ? '填充高度' : 'Fit height',
    };
  }

  String _positionLabel(ReaderInfoPosition position, bool isChinese) {
    return switch (position) {
      ReaderInfoPosition.bottomLeft => isChinese ? '左下' : 'Bottom left',
      ReaderInfoPosition.bottomRight => isChinese ? '右下' : 'Bottom right',
      ReaderInfoPosition.topLeft => isChinese ? '左上' : 'Top left',
      ReaderInfoPosition.topRight => isChinese ? '右上' : 'Top right',
    };
  }

  String _batteryFormatLabel(ReaderBatteryFormat format, bool isChinese) {
    return switch (format) {
      ReaderBatteryFormat.hidden => isChinese ? '隐藏' : 'Hidden',
      ReaderBatteryFormat.icon => isChinese ? '图标' : 'Icon',
      ReaderBatteryFormat.number => isChinese ? '数字' : 'Number',
      ReaderBatteryFormat.iconAndNumber =>
        isChinese ? '图标和数字' : 'Icon and number',
    };
  }

  String _pageFormatLabel(ReaderPageFormat format, bool isChinese) {
    return switch (format) {
      ReaderPageFormat.hidden => isChinese ? '隐藏' : 'Hidden',
      ReaderPageFormat.current => isChinese ? '当前页' : 'Current',
      ReaderPageFormat.currentAndTotal =>
        isChinese ? '当前页 / 总页数' : 'Current / total',
      ReaderPageFormat.percentage => isChinese ? '百分比' : 'Percentage',
    };
  }
}

/// Enables mouse dragging only inside horizontal reader-setting options.
class _HorizontalSettingsStrip extends StatelessWidget {
  const _HorizontalSettingsStrip({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final behavior = ScrollConfiguration.of(context);
    return ScrollConfiguration(
      behavior: behavior.copyWith(
        dragDevices: {...behavior.dragDevices, PointerDeviceKind.mouse},
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: child,
      ),
    );
  }
}
