import 'package:dcomic/providers/config_provider.dart';
import 'package:dcomic/utils/layout_utils.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class ExperimentalFeaturesPage extends StatefulWidget {
  const ExperimentalFeaturesPage({super.key});

  @override
  State<ExperimentalFeaturesPage> createState() =>
      _ExperimentalFeaturesPageState();
}

class _ExperimentalFeaturesPageState extends State<ExperimentalFeaturesPage> {
  bool _saving = false;

  String _locale(String zh, String en) =>
      Localizations.localeOf(context).languageCode == 'zh' ? zh : en;

  @override
  Widget build(BuildContext context) {
    final config = context.watch<ConfigProvider>();
    return Scaffold(
      appBar: AppBar(title: Text(_locale('实验性功能', 'Experimental Features'))),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppLayout.formMaxWidth),
          child: ListView(
            padding: EdgeInsets.only(
              top: 8,
              bottom: 8 + MediaQuery.paddingOf(context).bottom,
            ),
            children: [
              ListTile(
                leading: const Icon(Icons.science_outlined),
                title: Text(
                  _locale(
                    '这些功能可能不稳定，默认关闭。',
                    'These features may be unstable and are off by default.',
                  ),
                ),
              ),
              SwitchListTile(
                title: Text(
                  _locale(
                    '跨源共享“新”角标状态',
                    'Share new-update badge state across sources',
                  ),
                ),
                subtitle: Text(
                  _locale(
                    '通过已有绑定聚合最近查看时间。在任一源查看漫画后，可清除关联源已有的“新”角标，不会同步阅读进度或改写另一源的查看记录。\n两源章节进度可能不同，开启后可能漏掉另一源领先章节的更新提示。关闭后恢复各源独立判定。',
                    'Use existing bindings to share the latest viewing time. Viewing a comic on either source can clear existing new-update badges on linked sources, without syncing reading progress or overwriting their viewing records.\nSources may have different chapters available, so updates for chapters ahead on another source may be hidden. Turning this off restores independent badges.',
                  ),
                ),
                value: config.aggregateSubscribeBadges,
                onChanged: _saving
                    ? null
                    : (value) => _save(
                        () => config.setAggregateSubscribeBadges(value),
                      ),
              ),
              SwitchListTile(
                title: Text(
                  _locale(
                    '跨源聚合上次阅读进度',
                    'Aggregate last-read chapters across sources',
                  ),
                ),
                subtitle: Text(
                  _locale(
                    '通过已有绑定关联漫画，仅在章节名称能唯一对应时，按最后阅读时间选择最新进度，同时用于章节高亮和“继续阅读”。允许简繁体、空白和全半角差异，不按章节数字猜测。\n无法对应或存在歧义时，各源保留自己的进度。不覆盖原始历史，不同步页码；与角标共享开关独立，关闭后恢复本源进度。',
                    'Use existing comic bindings and uniquely matching chapter titles to choose the most recently read chapter for highlighting and Continue Reading. Traditional/simplified Chinese, whitespace and full-width ASCII differences are allowed; chapter numbers alone are not matched.\nUnmatched or ambiguous chapters keep each source’s own progress. Original history is preserved; page positions are not synced. Independent of badge sharing; turning this off restores local progress.',
                  ),
                ),
                value: config.aggregateReadingProgress,
                onChanged: _saving
                    ? null
                    : (value) => _save(
                        () => config.setAggregateReadingProgress(value),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save(Future<void> Function() save) async {
    setState(() => _saving = true);
    try {
      await save();
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
}
