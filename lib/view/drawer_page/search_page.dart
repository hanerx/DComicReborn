import 'dart:async';

import 'package:dcomic/providers/models/comic_source_model.dart';
import 'package:dcomic/providers/page_controllers/comic_search_page_controller.dart';
import 'package:dcomic/providers/search_history_store.dart';
import 'package:dcomic/providers/source_provider.dart';
import 'package:dcomic/utils/layout_utils.dart';
import 'package:dcomic/view/components/search_source_results.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _textController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final SearchHistoryStore _historyStore = SearchHistoryStore();

  ComicSearchPageController? _controller;
  List<BaseComicSourceModel> _sources = const [];
  List<String> _history = const [];
  bool _historyLoading = true;
  int _historyRevision = 0;

  bool get _isChinese => Localizations.localeOf(context).languageCode == 'zh';

  String _text(String zh, String en) => _isChinese ? zh : en;

  @override
  void initState() {
    super.initState();
    unawaited(_loadHistory());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller != null) return;
    // Keep one stable source snapshot for the lifetime of this search session.
    // Reordering sources elsewhere must not discard results or issue requests.
    _sources = List<BaseComicSourceModel>.unmodifiable(
      Provider.of<ComicSourceProvider>(context, listen: false).orderedSources,
    );
    _controller = ComicSearchPageController(_sources);
  }

  @override
  void dispose() {
    _historyRevision++;
    _controller?.dispose();
    _textController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    final revision = ++_historyRevision;
    try {
      final history = await _historyStore.load();
      if (!mounted) return;
      setState(() {
        _history = history;
        _historyLoading = false;
      });
    } catch (_) {
      if (!mounted || revision != _historyRevision) return;
      setState(() => _historyLoading = false);
      _showHistoryError();
    }
  }

  Future<void> _updateHistory(Future<List<String>> Function() operation) async {
    final revision = ++_historyRevision;
    try {
      final history = await operation();
      // The store completes operations in order. Keep every committed snapshot
      // visible even when a later queued mutation fails.
      if (!mounted) return;
      setState(() {
        _history = history;
        _historyLoading = false;
      });
    } catch (_) {
      if (!mounted || revision != _historyRevision) return;
      setState(() => _historyLoading = false);
      _showHistoryError();
    }
  }

  void _showHistoryError() {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            _text(
              '无法更新搜索历史，但仍可继续搜索。',
              'Search history could not be updated. You can still search.',
            ),
          ),
        ),
      );
  }

  Future<void> _submitSearch([String? value]) async {
    final query = (value ?? _textController.text).trim();
    if (_textController.text != query) {
      _textController.value = TextEditingValue(
        text: query,
        selection: TextSelection.collapsed(offset: query.length),
      );
      setState(() {});
    }
    final controller = _controller!;
    controller.pendingKeyword = query;
    _searchFocusNode.unfocus();
    if (query.isEmpty) {
      controller.clear();
      return;
    }

    final search = controller.search();
    unawaited(_updateHistory(() => _historyStore.record(query)));
    await search;
  }

  void _clearSearch() {
    _textController.clear();
    final controller = _controller!;
    controller.pendingKeyword = '';
    controller.clear();
    _searchFocusNode.requestFocus();
    setState(() {});
  }

  void _onDraftChanged(String value) {
    final controller = _controller!;
    controller.pendingKeyword = value;
    if (value.isEmpty) controller.clear();
    setState(() {});
  }

  Future<void> _confirmClearHistory() async {
    final shouldClear = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.delete_sweep_outlined),
        title: Text(_text('清空搜索历史？', 'Clear search history?')),
        content: Text(
          _text(
            '所有本地搜索记录都将被删除。',
            'All locally stored search queries will be removed.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(_text('取消', 'Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(_text('清空', 'Clear')),
          ),
        ],
      ),
    );
    if (mounted && shouldClear == true) {
      await _updateHistory(_historyStore.clear);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller!;
    final colors = Theme.of(context).colorScheme;
    return ChangeNotifierProvider<ComicSearchPageController>.value(
      value: controller,
      child: Scaffold(
        appBar: AppBar(
          toolbarHeight: 72,
          titleSpacing: 0,
          title: Padding(
            padding: const EdgeInsetsDirectional.only(end: 16),
            child: _buildSearchBar(context),
          ),
        ),
        backgroundColor: colors.surface,
        body: SafeArea(
          top: false,
          child: ListenableBuilder(
            listenable: controller,
            builder: (context, _) => _sources.isEmpty
                ? _buildNoSources(context)
                : controller.keyword.isEmpty
                ? _buildHistory(context)
                : _buildResults(context),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return SearchBar(
      controller: _textController,
      focusNode: _searchFocusNode,
      hintText: _text('输入漫画名称', 'Enter a comic title'),
      keyboardType: TextInputType.text,
      textInputAction: TextInputAction.search,
      constraints: const BoxConstraints(minHeight: 56, maxHeight: 56),
      textStyle: WidgetStatePropertyAll(theme.textTheme.bodyLarge),
      hintStyle: WidgetStatePropertyAll(
        theme.textTheme.bodyLarge?.copyWith(color: colors.onSurfaceVariant),
      ),
      elevation: const WidgetStatePropertyAll(0),
      backgroundColor: WidgetStatePropertyAll(colors.surfaceContainerHigh),
      side: WidgetStatePropertyAll(BorderSide(color: colors.outlineVariant)),
      padding: const WidgetStatePropertyAll(
        EdgeInsetsDirectional.only(start: 16, end: 4),
      ),
      trailing: [
        if (_textController.text.isNotEmpty)
          IconButton(
            tooltip: _text('清除搜索', 'Clear search'),
            onPressed: _clearSearch,
            icon: const Icon(Icons.close_rounded),
          ),
        IconButton.filledTonal(
          tooltip: _text('搜索', 'Search'),
          onPressed: () => _submitSearch(),
          icon: const Icon(Icons.search_rounded),
        ),
      ],
      onChanged: _onDraftChanged,
      onSubmitted: _submitSearch,
    );
  }

  Widget _buildHistory(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppLayout.formMaxWidth),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _text('最近搜索', 'Recent searches'),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (_history.isNotEmpty)
                  TextButton.icon(
                    onPressed: _confirmClearHistory,
                    icon: const Icon(Icons.delete_sweep_outlined),
                    label: Text(_text('清空', 'Clear all')),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (_historyLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(28),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_history.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 36),
                child: Column(
                  children: [
                    Icon(
                      Icons.history_toggle_off_rounded,
                      size: 52,
                      color: colors.onSurfaceVariant,
                    ),
                    const SizedBox(height: 14),
                    Text(
                      _text('还没有搜索记录', 'No recent searches'),
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _text(
                        '提交搜索后，关键词会保存在此设备上。',
                        'Submitted queries will appear here on this device.',
                      ),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final query in _history)
                    InputChip(
                      key: ValueKey(query),
                      label: Text(
                        query,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      avatar: const Icon(Icons.history_rounded, size: 18),
                      tooltip: _text('再次搜索', 'Search again'),
                      deleteIcon: const Icon(Icons.close_rounded, size: 18),
                      deleteButtonTooltipMessage: _text(
                        '删除此记录',
                        'Remove this query',
                      ),
                      onPressed: () => _submitSearch(query),
                      onDeleted: () =>
                          _updateHistory(() => _historyStore.remove(query)),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoSources(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.source_outlined,
                size: 56,
                color: colors.onSurfaceVariant,
              ),
              const SizedBox(height: 16),
              Text(
                _text('没有可用的漫画源', 'No sources available'),
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                _text(
                  '启用漫画源后即可在这里搜索。',
                  'Enable a comic source to start searching.',
                ),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResults(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return DefaultTabController(
      key: const ValueKey('search-source-tabs'),
      length: _sources.length,
      child: Column(
        children: [
          Material(
            color: colors.surface,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 2),
                  child: Text(
                    _text(
                      '“${_controller!.keyword}”的搜索结果',
                      'Results for “${_controller!.keyword}”',
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelLarge
                        ?.copyWith(color: colors.onSurfaceVariant),
                  ),
                ),
                SizedBox(
                  width: double.infinity,
                  child: TabBar(
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    dividerColor: colors.outlineVariant,
                    tabs: [
                      for (final source in _sources)
                        Tab(text: source.type.sourceName),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                for (final source in _sources)
                  ListenableBuilder(
                    key: ValueKey(source.type.sourceId),
                    listenable: source,
                    builder: (context, _) =>
                        SearchSourceResults(source: source),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
