import 'package:dcomic/providers/chapter_rule_store.dart';
import 'package:dcomic/utils/chapter_matching_rules.dart';
import 'package:dcomic/utils/layout_utils.dart';
import 'package:dcomic/view/components/settings_widgets.dart';
import 'package:flutter/material.dart';

/// Manage the chapter equivalence rule groups used by the experimental
/// cross-source reading-progress aggregation.
class ChapterRulesPage extends StatefulWidget {
  const ChapterRulesPage({super.key});

  @override
  State<ChapterRulesPage> createState() => _ChapterRulesPageState();
}

class _ChapterRulesPageState extends State<ChapterRulesPage> {
  final TextEditingController _tryController = TextEditingController();
  List<ChapterRuleGroup> _groups = [];
  ChapterRuleMatcher _matcher = ChapterRuleMatcher(const []);
  bool _loading = true;
  bool _loadFailed = false;
  bool _busy = false;
  bool _tryHasInput = false;
  ChapterRuleMatch? _tryMatch;
  int _loadGeneration = 0;

  String _locale(String zh, String en) =>
      Localizations.localeOf(context).languageCode == 'zh' ? zh : en;

  @override
  void initState() {
    super.initState();
    _tryController.addListener(_updateTryMatch);
    ChapterRuleStore.changes.addListener(_onRulesChanged);
    _reload(initial: true);
  }

  @override
  void dispose() {
    ChapterRuleStore.changes.removeListener(_onRulesChanged);
    _tryController.removeListener(_updateTryMatch);
    _tryController.dispose();
    super.dispose();
  }

  void _onRulesChanged() {
    if (!_busy) _reload(initial: _loading || _loadFailed);
  }

  Future<void> _reload({bool initial = false}) async {
    final generation = ++_loadGeneration;
    try {
      final groups = await ChapterRuleStore.load();
      final matcher = ChapterRuleMatcher(groups);
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _groups = groups;
        _matcher = matcher;
        if (initial) {
          _loading = false;
          _loadFailed = false;
        }
      });
      _updateTryMatch();
    } catch (_) {
      if (!mounted || generation != _loadGeneration) return;
      if (initial) {
        setState(() {
          _loading = false;
          _loadFailed = true;
        });
      } else {
        _snack(
          _locale(
            '刷新失败，显示的可能不是最新规则。',
            'Could not refresh; the shown rules may be stale.',
          ),
        );
      }
    }
  }

  void _updateTryMatch() {
    if (!mounted) return;
    final title = _tryController.text;
    final hasInput = title.trim().isNotEmpty;
    final match = hasInput ? _matcher.match(title) : null;
    setState(() {
      _tryHasInput = hasInput;
      _tryMatch = match;
    });
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    var saved = false;
    try {
      await action();
      saved = true;
    } catch (_) {
      if (mounted) {
        _snack(_locale('保存失败，请重试。', 'Could not save. Please try again.'));
      }
    }
    if (saved) {
      await _reload();
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SettingsPage(
      title: Text(_locale('章节匹配规则', 'Chapter Matching Rules')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppLayout.formMaxWidth),
          child: Column(
            children: [
              if (_busy) const LinearProgressIndicator(minHeight: 2),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _loadFailed
                    ? _buildLoadFailed(colors)
                    : _buildList(colors),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadFailed(ColorScheme colors) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.cloud_off_rounded,
            size: 40,
            color: colors.onSurfaceVariant,
          ),
          const SizedBox(height: 12),
          Text(
            _locale('规则加载失败。', 'Could not load the rules.'),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          FilledButton.tonal(
            onPressed: () => _reload(initial: true),
            child: Text(_locale('重试', 'Retry')),
          ),
        ],
      ),
    ),
  );

  Widget _buildList(ColorScheme colors) => ListView(
    padding: EdgeInsets.fromLTRB(
      12,
      12,
      12,
      16 + MediaQuery.paddingOf(context).bottom,
    ),
    children: [
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: SettingsNotice(
          icon: Icons.rule_outlined,
          child: Text(
            _locale(
              '每个分组用其中的正则规则从章节标题提取章节数字，数字相同即视为同一章（如“第 3 话”与“Chapter 3”）。第一个捕获组 () 用于提取数字；匹配前会忽略标题中的空白并转换简繁与全半角。命中多个分组或提取不到数字时不猜测，保留本源进度；原始阅读历史不会被修改。',
              'Each group uses its regular expressions to extract a chapter number from a title; equal numbers count as the same chapter (for example “第 3 话” and “Chapter 3”). The first capturing group () extracts the number; whitespace in titles is ignored and Chinese variants and full-width ASCII are folded before matching. Ambiguous or missing matches are never guessed and keep local progress; original reading history is never modified.',
            ),
          ),
        ),
      ),
      _buildTryPanel(colors),
      const SizedBox(height: 12),
      if (_groups.isEmpty) _buildEmptyState(colors),
      for (final group in _groups) _buildGroupCard(group),
      _buildActions(colors),
    ],
  );

  Widget _buildTryPanel(ColorScheme colors) => _panel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _locale('试用匹配', 'Try matching'),
          style: Theme.of(context).textTheme.titleSmall
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        _description(
          _locale(
            '输入章节标题，按当前分组实时查看匹配结果。',
            'Type a chapter title to see the live result with the current groups.',
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _tryController,
          decoration: InputDecoration(
            labelText: _locale('章节标题', 'Chapter title'),
            hintText: _locale('第 12.5 话', 'e.g. 第 12.5 话'),
            prefixIcon: const Icon(Icons.search_rounded),
            border: const OutlineInputBorder(),
          ),
        ),
        if (_tryHasInput) ...[
          const SizedBox(height: 10),
          _buildTryResult(colors),
        ],
      ],
    ),
  );

  Widget _buildTryResult(ColorScheme colors) {
    if (_groups.isEmpty) {
      return _tryResultRow(
        icon: Icons.info_outline_rounded,
        color: colors.onSurfaceVariant,
        text: _locale('暂无分组，无法匹配。', 'No groups yet, nothing to match.'),
      );
    }
    final match = _tryMatch;
    if (match == null) {
      return _tryResultRow(
        icon: Icons.warning_amber_rounded,
        color: colors.tertiary,
        text: _locale('无唯一匹配', 'No unique match'),
      );
    }
    final groupName = _groups[match.groupIndex].name;
    return _tryResultRow(
      icon: Icons.check_circle_outline_rounded,
      color: colors.primary,
      text: _locale(
        '「$groupName」· ${match.number}',
        '$groupName · ${match.number}',
      ),
    );
  }

  Widget _tryResultRow({
    required IconData icon,
    required Color color,
    required String text,
  }) => Row(
    children: [
      Icon(icon, size: 18, color: color),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          text,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: color),
        ),
      ),
    ],
  );

  Widget _buildEmptyState(ColorScheme colors) => _panel(
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Column(
        children: [
          Icon(Icons.rule_outlined, size: 40, color: colors.onSurfaceVariant),
          const SizedBox(height: 10),
          Text(
            _locale('暂无分组', 'No groups yet'),
            style: Theme.of(context).textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          _description(
            _locale(
              '当前没有任何分组，章节不会按数字等价匹配。可添加分组，或恢复默认规则。',
              'There are no groups, so chapters are not matched by number equivalence. Add a group or restore the default rules.',
            ),
          ),
        ],
      ),
    ),
  );

  Widget _buildGroupCard(ChapterRuleGroup group) {
    final colors = Theme.of(context).colorScheme;
    final canEdit = !_busy && group.id != null;
    return _panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SettingsIcon(
                color: colors.secondary,
                child: const Icon(Icons.label_outline_rounded),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  group.name,
                  style: Theme.of(context).textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              PopupMenuButton<String>(
                enabled: canEdit,
                tooltip: _locale('分组操作', 'Group actions'),
                icon: const Icon(Icons.more_vert_rounded),
                onSelected: (value) {
                  if (value == 'rename') {
                    _renameGroup(group);
                  } else if (value == 'delete') {
                    _deleteGroup(group);
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'rename',
                    child: Text(_locale('重命名分组', 'Rename group')),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Text(_locale('删除分组', 'Delete group')),
                  ),
                ],
              ),
            ],
          ),
          if (group.patterns.isEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 52, top: 4),
              child: _description(
                _locale(
                  '暂无规则，添加一条以匹配章节标题。',
                  'No patterns yet. Add one to match chapter titles.',
                ),
              ),
            )
          else
            for (var index = 0; index < group.patterns.length; index++)
              _buildPatternRow(group, index, canEdit),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: canEdit ? () => _showPatternDialog(group, null) : null,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text(_locale('添加规则', 'Add pattern')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPatternRow(ChapterRuleGroup group, int index, bool canEdit) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Icon(
              Icons.tag_rounded,
              size: 18,
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              group.patterns[index],
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(fontFamily: 'monospace', fontSize: 13),
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: _locale('编辑规则', 'Edit pattern'),
            onPressed: canEdit ? () => _showPatternDialog(group, index) : null,
            icon: const Icon(Icons.edit_outlined, size: 18),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: _locale('删除规则', 'Delete pattern'),
            onPressed: canEdit ? () => _deletePattern(group, index) : null,
            icon: const Icon(Icons.delete_outline_rounded, size: 18),
          ),
        ],
      ),
    );
  }

  Widget _buildActions(ColorScheme colors) => _panel(
    child: Column(
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: _busy ? null : _addGroup,
          child: _actionRow(
            icon: Icons.add_rounded,
            title: _locale('添加分组', 'Add group'),
            enabled: !_busy,
          ),
        ),
        _divider(),
        InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: _busy ? null : _resetDefaults,
          child: _actionRow(
            icon: Icons.restore_rounded,
            accent: colors.tertiary,
            title: _locale('恢复默认规则', 'Restore default rules'),
            description: _locale(
              '用内置默认分组覆盖当前全部分组。',
              'Overwrite all current groups with the built-in defaults.',
            ),
            enabled: !_busy,
          ),
        ),
      ],
    ),
  );

  Future<void> _addGroup() async {
    final name = await _showNameDialog(title: _locale('添加分组', 'Add group'));
    if (name == null || !mounted) return;
    await _run(
      () => ChapterRuleStore.save(
        ChapterRuleGroup(name: name, patterns: const []),
      ),
    );
  }

  Future<void> _renameGroup(ChapterRuleGroup group) async {
    final name = await _showNameDialog(
      title: _locale('重命名分组', 'Rename group'),
      initial: group.name,
    );
    if (name == null || !mounted || name == group.name) return;
    await _run(
      () => ChapterRuleStore.save(
        ChapterRuleGroup(id: group.id, name: name, patterns: group.patterns),
      ),
    );
  }

  Future<void> _deleteGroup(ChapterRuleGroup group) async {
    final id = group.id;
    if (id == null) return;
    final confirmed = await _confirm(
      title: _locale('删除分组？', 'Delete group?'),
      message: _locale(
        '将删除分组“${group.name}”及其全部规则。',
        'This deletes “${group.name}” and all of its patterns.',
      ),
      confirmLabel: _locale('删除', 'Delete'),
    );
    if (!confirmed || !mounted) return;
    await _run(() => ChapterRuleStore.delete(id));
  }

  Future<void> _showPatternDialog(ChapterRuleGroup group, int? index) async {
    final id = group.id;
    if (id == null) return;
    final emptyError = _locale('请输入正则表达式', 'Enter a regular expression');
    var input = index == null ? '' : group.patterns[index];
    String? error;

    String? validate(String value) {
      final message = validateChapterPattern(value.trim());
      if (message == null) return null;
      if (value.trim().isEmpty) return emptyError;
      return _locale(message, 'Invalid pattern: $message');
    }

    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          void submit() {
            final message = validate(input);
            if (message != null) {
              setDialogState(() => error = message);
              return;
            }
            Navigator.pop(dialogContext, input.trim());
          }

          return AlertDialog(
            title: Text(
              index == null
                  ? _locale('添加规则', 'Add pattern')
                  : _locale('编辑规则', 'Edit pattern'),
            ),
            content: TextFormField(
              initialValue: input,
              autofocus: true,
              onChanged: (text) {
                input = text;
                if (error != null) {
                  setDialogState(() => error = validate(text));
                }
              },
              decoration: InputDecoration(
                labelText: _locale('正则表达式', 'Regular expression'),
                hintText: r'第(\d+(?:\.\d+)?)话',
                helperText: _locale(
                  '第一个捕获组 () 用于提取章节数字；匹配前会忽略标题中的空白。',
                  'The first capturing group () extracts the chapter number; whitespace in titles is ignored.',
                ),
                helperMaxLines: 3,
                errorText: error,
                errorMaxLines: 3,
              ),
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
    if (index != null && result == group.patterns[index]) return;
    final patterns = [...group.patterns];
    if (index == null) {
      patterns.add(result);
    } else {
      patterns[index] = result;
    }
    await _run(
      () => ChapterRuleStore.save(
        ChapterRuleGroup(id: id, name: group.name, patterns: patterns),
      ),
    );
  }

  Future<void> _deletePattern(ChapterRuleGroup group, int index) async {
    final id = group.id;
    if (id == null) return;
    final pattern = group.patterns[index];
    final confirmed = await _confirm(
      title: _locale('删除规则？', 'Delete pattern?'),
      message: _locale('将删除规则：$pattern', 'Delete this pattern: $pattern'),
      confirmLabel: _locale('删除', 'Delete'),
    );
    if (!confirmed || !mounted) return;
    final patterns = [...group.patterns]..removeAt(index);
    await _run(
      () => ChapterRuleStore.save(
        ChapterRuleGroup(id: id, name: group.name, patterns: patterns),
      ),
    );
  }

  Future<void> _resetDefaults() async {
    final confirmed = await _confirm(
      title: _locale('恢复默认规则？', 'Restore default rules?'),
      message: _locale(
        '当前全部分组（含默认分组与自定义分组）都会被内置默认分组覆盖，此操作无法撤销。',
        'All current groups, including defaults and custom ones, will be overwritten by the built-in defaults. This cannot be undone.',
      ),
      confirmLabel: _locale('恢复默认', 'Restore'),
    );
    if (!confirmed || !mounted) return;
    await _run(ChapterRuleStore.reset);
  }

  Future<String?> _showNameDialog({required String title, String? initial}) {
    final emptyError = _locale('请输入分组名称', 'Enter a group name');
    var input = initial ?? '';
    String? error;
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          void submit() {
            final name = input.trim();
            if (name.isEmpty) {
              setDialogState(() => error = emptyError);
              return;
            }
            Navigator.pop(dialogContext, name);
          }

          return AlertDialog(
            title: Text(title),
            content: TextFormField(
              initialValue: initial ?? '',
              autofocus: true,
              onChanged: (text) {
                input = text;
                if (error != null) {
                  setDialogState(
                    () => error = text.trim().isEmpty ? emptyError : null,
                  );
                }
              },
              decoration: InputDecoration(
                labelText: _locale('分组名称', 'Group name'),
                errorText: error,
              ),
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
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    required String confirmLabel,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(_locale('取消', 'Cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(dialogContext).colorScheme.error,
            ),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return result == true;
  }

  Widget _panel({required Widget child}) => SettingsCard(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(14),
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

  Widget _actionRow({
    required IconData icon,
    required String title,
    String? description,
    Color? accent,
    bool enabled = true,
  }) {
    final colors = Theme.of(context).colorScheme;
    final color = enabled
        ? accent ?? colors.onSurfaceVariant
        : colors.onSurface.withValues(alpha: 0.38);
    return Row(
      children: [
        SettingsIcon(color: color, child: Icon(icon)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: enabled
                      ? colors.onSurface
                      : colors.onSurface.withValues(alpha: 0.38),
                ),
              ),
              if (description != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: _description(description, enabled: enabled),
                ),
            ],
          ),
        ),
      ],
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
}
