import 'package:dcomic/providers/config_provider.dart';
import 'package:dcomic/utils/layout_utils.dart';
import 'package:dcomic/view/components/settings_widgets.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class DownloadSettingPage extends StatefulWidget {
  const DownloadSettingPage({super.key});

  @override
  State<DownloadSettingPage> createState() => _DownloadSettingPageState();
}

class _DownloadSettingPageState extends State<DownloadSettingPage> {
  bool _saving = false;

  String _locale(String zh, String en) =>
      Localizations.localeOf(context).languageCode == 'zh' ? zh : en;

  String _optionLabel(int value) {
    if (value == 0) return _locale('整章', 'Full chapter');
    return _locale(
      '后续 $value 页',
      value == 1 ? '1 following page' : '$value following pages',
    );
  }

  String _selectedLabel(int value) {
    if (value == 0) return _locale('当前：整章', 'Current: Full chapter');
    return _locale(
      '当前：后续 $value 页（不含当前页）',
      value == 1
          ? 'Current: 1 following page (excluding current)'
          : 'Current: $value following pages (excluding current)',
    );
  }

  Future<void> _choosePrecacheCount() async {
    final config = context.read<ConfigProvider>();
    final current = config.readerPrecacheCount;
    final selected = await showDialog<int>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        scrollable: true,
        title: Text(_locale('选择预缓存范围', 'Choose precache range')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var value = 0; value <= 9; value++)
              Semantics(
                selected: value == current,
                child: ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  selected: value == current,
                  title: Text(_optionLabel(value)),
                  trailing: value == current
                      ? const Icon(Icons.check_rounded)
                      : null,
                  onTap: () => Navigator.pop(dialogContext, value),
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(_locale('取消', 'Cancel')),
          ),
        ],
      ),
    );
    if (selected == null || selected == current || !mounted) return;

    setState(() => _saving = true);
    try {
      await config.setReaderPrecacheCount(selected);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _locale('保存失败，请重试。', 'Could not save. Please try again.'),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final count = context.select<ConfigProvider, int>(
      (config) => config.readerPrecacheCount,
    );
    return SettingsPage(
      title: Text(_locale('下载设置', 'Download Settings')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppLayout.formMaxWidth),
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              12,
              12,
              12,
              16 + MediaQuery.paddingOf(context).bottom,
            ),
            children: [
              SettingsNotice(
                child: Text(
                  _locale(
                    '页数指当前页之后的后续页面，不包含当前页；当前页始终可以加载。选择“整章”时，图片文件会按章节顺序下载到磁盘缓存，并不会一次性解码整章；屏幕上可见的图片仍按需加载和解码。',
                    'The count covers following pages after the current page and excludes the current page; the current page is always eligible. “Full chapter” downloads image files sequentially to the disk cache instead of decoding the entire chapter at once. Visible images still load and decode on demand.',
                  ),
                ),
              ),
              SettingsSection(title: _locale('阅读预缓存', 'Reading Precache')),
              SettingsGroup(
                children: [
                  SettingsTile(
                    leading: const Icon(Icons.download_for_offline_outlined),
                    title: Text(_locale('预缓存范围', 'Precache range')),
                    subtitle: Text(_selectedLabel(count)),
                    trailing: _saving
                        ? Semantics(
                            label: _locale('正在保存', 'Saving'),
                            child: const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : null,
                    onTap: _saving ? null : _choosePrecacheCount,
                    enabled: !_saving,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
