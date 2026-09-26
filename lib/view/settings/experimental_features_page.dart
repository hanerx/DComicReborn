import 'package:dcomic/providers/chapter_rule_store.dart';
import 'package:dcomic/providers/config_provider.dart';
import 'package:dcomic/providers/navigator_provider.dart';
import 'package:dcomic/utils/layout_utils.dart';
import 'package:dcomic/view/components/settings_widgets.dart';
import 'package:dcomic/view/settings/chapter_rules_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

class ExperimentalFeaturesPage extends StatefulWidget {
  const ExperimentalFeaturesPage({super.key});

  @override
  State<ExperimentalFeaturesPage> createState() =>
      _ExperimentalFeaturesPageState();
}

class _ExperimentalFeaturesPageState extends State<ExperimentalFeaturesPage> {
  bool _saving = false;
  bool _badgesExpanded = true;
  bool _readingExpanded = true;
  int? _ruleGroupCount;
  bool _ruleCountFailed = false;

  String _locale(String zh, String en) =>
      Localizations.localeOf(context).languageCode == 'zh' ? zh : en;

  @override
  void initState() {
    super.initState();
    _loadRuleGroupCount();
    ChapterRuleStore.changes.addListener(_loadRuleGroupCount);
  }

  @override
  void dispose() {
    ChapterRuleStore.changes.removeListener(_loadRuleGroupCount);
    super.dispose();
  }

  void _loadRuleGroupCount() {
    ChapterRuleStore.load()
        .then((groups) {
          if (mounted) {
            setState(() {
              _ruleGroupCount = groups.length;
              _ruleCountFailed = false;
            });
          }
        })
        .catchError((_) {
          if (mounted) setState(() => _ruleCountFailed = true);
        });
  }

  String _ruleGroupCountText() {
    if (_ruleCountFailed) return _locale('读取失败', 'Unavailable');
    final count = _ruleGroupCount;
    if (count == null) {
      return _locale('加载中…', 'Loading…');
    }
    return _locale('$count 组', count == 1 ? '1 group' : '$count groups');
  }

  void _openChapterRules() {
    Provider.of<NavigatorProvider>(context, listen: false)
        .getNavigator(context, NavigatorType.defaultNavigator)
        ?.push(
          MaterialPageRoute(
            builder: (context) => const ChapterRulesPage(),
            settings: const RouteSettings(name: 'ChapterRulesPage'),
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    final config = context.watch<ConfigProvider>();
    final colors = Theme.of(context).colorScheme;
    final badgeSharing = config.aggregateSubscribeBadges;
    final autoMapEnabled = badgeSharing && config.autoMapMissingComics;
    final canEditMapping = autoMapEnabled && !_saving;
    return SettingsPage(
      title: Text(_locale('实验性功能', 'Experimental Features')),
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
              _panel(
                color: colors.primaryContainer.withValues(alpha: 0.45),
                child: Row(
                  children: [
                    Icon(
                      Icons.science_outlined,
                      size: 30,
                      color: colors.primary,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _locale(
                              '这些功能可能不稳定，默认关闭。',
                              'Experimental features are off by default.',
                            ),
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 4),
                          _description(
                            _locale(
                              '按需谨慎开启，出现问题可随时关闭。',
                              'Enable with care. You can turn them off at any time.',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              _panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _settingRow(
                      icon: Icons.link_rounded,
                      accent: colors.primary,
                      title: _locale(
                        '跨源共享“新”角标状态',
                        'Share new-update badge state across sources',
                      ),
                      description: _badgesExpanded
                          ? _locale(
                              '通过已有绑定共享最近查看时间，查看任一源可清除关联源的更新角标，不同步阅读进度。\n两源章节进度不同，可能漏掉领先章节的更新；关闭后恢复独立判定。',
                              'Share the latest viewing time through existing bindings, without changing reading progress or viewing records.\nSources may have different chapters, so some updates may be hidden. Turning this off restores independent badges.',
                            )
                          : null,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Switch(
                            value: badgeSharing,
                            onChanged: _saving
                                ? null
                                : (value) => _save(
                                    () => config.setAggregateSubscribeBadges(
                                      value,
                                    ),
                                  ),
                          ),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            tooltip: _badgesExpanded
                                ? _locale('收起角标设置', 'Collapse badge settings')
                                : _locale('展开角标设置', 'Expand badge settings'),
                            onPressed: () => setState(
                              () => _badgesExpanded = !_badgesExpanded,
                            ),
                            icon: Icon(
                              _badgesExpanded
                                  ? Icons.expand_less
                                  : Icons.expand_more,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_badgesExpanded) ...[
                      const SizedBox(height: 16),
                      Material(
                        color: colors.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(14),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            children: [
                              _settingRow(
                                icon: Icons.add_link_rounded,
                                title: _locale(
                                  '自动匹配缺失绑定',
                                  'Auto-match missing bindings',
                                ),
                                description: _locale(
                                  '浏览收藏时异步匹配唯一同名漫画，不覆盖手动绑定或解绑。每本每次启动最多搜索一次，计数独立保存。',
                                  'Match unique titles in the background without replacing manual bindings or unbinds. Search once per comic per launch; counts are saved separately.',
                                ),
                                enabled: badgeSharing,
                                trailing: Switch(
                                  value: config.autoMapMissingComics,
                                  onChanged: badgeSharing && !_saving
                                      ? (value) => _save(
                                          () => config.setAutoMapMissingComics(
                                            value,
                                          ),
                                        )
                                      : null,
                                ),
                              ),
                              _divider(),
                              _numberRow(
                                icon: Icons.schedule_rounded,
                                title: _locale(
                                  '搜索间隔（秒）',
                                  'Search interval (seconds)',
                                ),
                                description: _locale(
                                  '上次搜索结束后等待。',
                                  'Wait after the previous search finishes.',
                                ),
                                value: _locale(
                                  '${config.autoMapIntervalSeconds} 秒',
                                  '${config.autoMapIntervalSeconds} s',
                                ),
                                onTap: canEditMapping
                                    ? () => _editInt(
                                        title: _locale(
                                          '搜索间隔（秒）',
                                          'Search interval (seconds)',
                                        ),
                                        value: config.autoMapIntervalSeconds,
                                        save: config.setAutoMapIntervalSeconds,
                                      )
                                    : null,
                              ),
                              _divider(),
                              _settingRow(
                                icon: Icons.refresh_rounded,
                                accent: colors.tertiary,
                                title: _locale('每次启动都重试', 'Retry every launch'),
                                description: _locale(
                                  '开启后每次启动重试未匹配的漫画；关闭后按每本累计次数上限停止。',
                                  'Retry unmatched comics each launch, or stop at each comic’s total attempt limit.',
                                ),
                                enabled: autoMapEnabled,
                                trailing: Switch(
                                  value: config.autoMapRetryEveryLaunch,
                                  onChanged: canEditMapping
                                      ? (value) => _save(
                                          () =>
                                              config.setAutoMapRetryEveryLaunch(
                                                value,
                                              ),
                                        )
                                      : null,
                                ),
                              ),
                              if (!config.autoMapRetryEveryLaunch) ...[
                                _divider(),
                                _numberRow(
                                  icon: Icons.repeat_one_rounded,
                                  title: _locale(
                                    '最多尝试次数',
                                    'Total attempt limit',
                                  ),
                                  description: _locale(
                                    '每本、每个目标源独立计数，含首次，重启不清零。',
                                    'Per comic and target source, including the first search. Kept across restarts.',
                                  ),
                                  value: _locale(
                                    '${config.autoMapMaxAttempts} 次',
                                    '${config.autoMapMaxAttempts}',
                                  ),
                                  onTap: canEditMapping
                                      ? () => _editInt(
                                          title: _locale(
                                            '最多尝试次数',
                                            'Total attempt limit',
                                          ),
                                          value: config.autoMapMaxAttempts,
                                          save: config.setAutoMapMaxAttempts,
                                        )
                                      : null,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              _panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _settingRow(
                      icon: Icons.auto_stories_outlined,
                      accent: colors.secondary,
                      title: _locale(
                        '跨源聚合上次阅读进度',
                        'Aggregate last-read chapters across sources',
                      ),
                      description: _readingExpanded
                          ? _locale(
                              '已绑定漫画的章节标题或分组规则能唯一对应时，使用最近阅读进度高亮章节和“继续阅读”。不覆盖原始历史，不同步页码；无法对应时保留本源进度。',
                              'Use the latest progress for highlighting and Continue Reading when linked chapter titles or grouped rules match uniquely. Original history and page positions stay unchanged; unmatched chapters keep local progress.',
                            )
                          : null,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Switch(
                            value: config.aggregateReadingProgress,
                            onChanged: _saving
                                ? null
                                : (value) => _save(
                                    () => config.setAggregateReadingProgress(
                                      value,
                                    ),
                                  ),
                          ),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            tooltip: _readingExpanded
                                ? _locale(
                                    '收起阅读进度设置',
                                    'Collapse reading progress settings',
                                  )
                                : _locale(
                                    '展开阅读进度设置',
                                    'Expand reading progress settings',
                                  ),
                            onPressed: () => setState(
                              () => _readingExpanded = !_readingExpanded,
                            ),
                            icon: Icon(
                              _readingExpanded
                                  ? Icons.expand_less
                                  : Icons.expand_more,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_readingExpanded) ...[
                      const SizedBox(height: 16),
                      Material(
                        color: colors.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(14),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: _numberRow(
                            icon: Icons.rule_rounded,
                            title: _locale(
                              '章节匹配规则分组',
                              'Chapter matching rule groups',
                            ),
                            description: _locale(
                              '按分组把“第 3 话”“Chapter 3”等视为同一章，用于跨源对应阅读进度；关闭聚合时不修改已保存的规则。',
                              'Group patterns like “第 3 话” and “Chapter 3” as the same chapter for cross-source progress. Saved rules are kept while aggregation is off.',
                            ),
                            value: _ruleGroupCountText(),
                            onTap: config.aggregateReadingProgress
                                ? _openChapterRules
                                : null,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              _panel(
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: _showRisks,
                  child: _settingRow(
                    icon: Icons.info_outline_rounded,
                    title: _locale('风险提示', 'Risks and details'),
                    description: _locale(
                      '了解跨源匹配、更新提示和重试计数规则。',
                      'About cross-source matching, update badges and retry counts.',
                    ),
                    trailing: const SizedBox(
                      width: 40,
                      height: 48,
                      child: Icon(Icons.chevron_right),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _panel({required Widget child, Color? color}) => SettingsCard(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(14),
    color: color,
    child: child,
  );

  Widget _description(String text, {bool enabled = true}) {
    final colors = Theme.of(context).colorScheme;
    return Text(
      text,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        fontSize: 13,
        height: 1.5,
        color: enabled
            ? colors.onSurfaceVariant
            : colors.onSurface.withValues(alpha: 0.38),
      ),
    );
  }

  Widget _settingRow({
    required IconData icon,
    required String title,
    String? description,
    Widget? trailing,
    Color? accent,
    bool enabled = true,
  }) {
    final colors = Theme.of(context).colorScheme;
    final iconColor = enabled
        ? accent ?? colors.onSurfaceVariant
        : colors.onSurface.withValues(alpha: 0.38);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            SettingsIcon(color: iconColor, child: Icon(icon)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: enabled
                      ? colors.onSurface
                      : colors.onSurface.withValues(alpha: 0.38),
                ),
              ),
            ),
            if (trailing != null) ...[const SizedBox(width: 4), trailing],
          ],
        ),
        if (description != null)
          Padding(
            padding: const EdgeInsets.only(left: 52, top: 4),
            child: _description(description, enabled: enabled),
          ),
      ],
    );
  }

  Widget _numberRow({
    required IconData icon,
    required String title,
    required String description,
    required String value,
    required VoidCallback? onTap,
  }) {
    final colors = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: _settingRow(
        icon: icon,
        title: title,
        description: description,
        enabled: onTap != null,
        trailing: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: colors.surfaceContainerHighest.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: onTap != null
                      ? colors.onSurface
                      : colors.onSurface.withValues(alpha: 0.38),
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right,
                size: 18,
                color: colors.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _divider() => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Divider(
      height: 1,
      color: Theme.of(context).colorScheme.outlineVariant
          .withValues(alpha: 0.5),
    ),
  );

  Future<void> _showRisks() => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(_locale('风险提示', 'Risks and details')),
      content: SingleChildScrollView(
        child: Text(
          _locale(
            '跨源角标表示“查看过这本漫画”，不表示所有最新章节均已读。查看进度落后的源，也可能清除领先源的更新提示。\n\n自动匹配仅接受简繁转换后标题一致且唯一的结果，但同名作品仍可能误匹配。已有绑定、显式解绑和不可靠的冲突关系不会被自动覆盖。\n\n搜索失败、无结果或匹配不唯一均计入尝试次数；未发起搜索不计次。不限次模式仍累计计数，切换开关和重启均不清零。\n\n阅读进度先按唯一对应的章节名称匹配，允许简繁体、空白及全半角差异；名称无法对应时，按自定义分组规则提取章节数字，把“第 3 话”“Chapter 3”等视为同一章。命中多个分组或提取不到数字时不猜测，保留本源进度；原始阅读历史不会被修改。发生异常时可关闭对应功能，恢复各源独立使用。',
            'Shared badges mean the comic was viewed, not that every latest chapter was read. Viewing a source with fewer chapters may clear updates on a source with more chapters.\n\nAutomatic matching requires a unique simplified-equivalent title, but different works may share a title. Existing bindings, explicit unbinds and conflicting relationships are not overwritten.\n\nFailed, empty and ambiguous searches count as attempts; unstarted searches do not. Unlimited retries still accumulate counts. Toggles and restarts do not reset them.\n\nReading progress first matches chapter titles uniquely, allowing Chinese variants, whitespace and full-width ASCII. When titles differ, chapter numbers are extracted by custom rule groups, so “第 3 话” and “Chapter 3” count as the same chapter. Ambiguous or missing matches are never guessed and keep local progress; the original reading history is never modified. Turn a feature off if it behaves unexpectedly.',
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(_locale('知道了', 'Got it')),
        ),
      ],
    ),
  );

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

  Future<void> _editInt({
    required String title,
    required int value,
    required Future<void> Function(int value) save,
  }) async {
    var input = value.toString();
    String? error;
    final result = await showDialog<int>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          void submit() {
            final parsed = int.tryParse(input.trim());
            if (parsed == null || parsed < 1) {
              setDialogState(
                () => error = _locale(
                  '请输入不小于 1 的整数',
                  'Enter a whole number of at least 1',
                ),
              );
              return;
            }
            Navigator.pop(dialogContext, parsed);
          }

          return AlertDialog(
            title: Text(title),
            content: TextFormField(
              initialValue: value.toString(),
              onChanged: (text) => input = text,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(labelText: title, errorText: error),
              onFieldSubmitted: (_) => submit(),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(_locale('取消', 'Cancel')),
              ),
              TextButton(onPressed: submit, child: Text(_locale('保存', 'Save'))),
            ],
          );
        },
      ),
    );
    if (result == null || !mounted) return;
    await _save(() => save(result));
  }
}
