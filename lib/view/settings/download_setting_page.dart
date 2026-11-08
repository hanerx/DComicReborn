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
                    '这里控制的是阅读时的临时预缓存：文件可能被系统或缓存清理删除，也不会出现在“已下载漫画”中。需要长期离线阅读时，请在漫画详情中使用“下载章节”。页数指当前页之后的页面，不包含当前页；当前页始终可以加载。选择“整章”只会把图片依次写入临时磁盘缓存，不会一次性解码整章。',
                    'This controls temporary reading precache. Cached files may be removed by the system or cache cleanup and do not appear in “Downloaded comics”. For durable offline reading, use “Download chapters” from comic details. The count covers pages after the current page and excludes the current page; the current page is always eligible. “Full chapter” writes images to temporary disk cache in order and does not decode the whole chapter at once.',
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
