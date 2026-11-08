import 'dart:collection';
import 'dart:async';

import 'package:dcomic/downloads/comic_download_models.dart';
import 'package:dcomic/downloads/comic_download_service.dart';
import 'package:dcomic/providers/config_provider.dart';
import 'package:dcomic/providers/models/comic_source_model.dart';
import 'package:dcomic/providers/source_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class ChapterDownloadSelection extends ChangeNotifier {
  ChapterDownloadSelection(Iterable<String> chapterIds)
    : _availableIds = Set<String>.unmodifiable(chapterIds);

  final Set<String> _availableIds;
  final Set<String> _selectedIds = <String>{};

  late final Set<String> _selectedView =
      UnmodifiableSetView<String>(_selectedIds);
  Set<String> get selectedIds => _selectedView;
  int get availableCount => _availableIds.length;
  bool canSelect(String chapterId) => _availableIds.contains(chapterId);
  bool isSelected(String chapterId) => _selectedIds.contains(chapterId);

  void toggle(String chapterId) {
    if (!canSelect(chapterId)) return;
    if (!_selectedIds.add(chapterId)) _selectedIds.remove(chapterId);
    notifyListeners();
  }

  void selectAll() {
    _selectedIds
      ..clear()
      ..addAll(_availableIds);
    notifyListeners();
  }

  void clear() {
    if (_selectedIds.isEmpty) return;
    _selectedIds.clear();
    notifyListeners();
  }
}

class ChapterDownloadIndicators {
  const ChapterDownloadIndicators({
    required this.ownComplete,
    required this.alternateComplete,
    required this.isPartial,
    required this.isActive,
    required this.isPaused,
    required this.isFailed,
  });

  factory ChapterDownloadIndicators.from({
    OfflineChapterProgress? progress,
    required bool ownComplete,
    required bool alternateComplete,
  }) {
    final completedPages = progress?.completedPages ?? 0;
    final totalPages = progress?.totalPages ?? 0;
    final state = progress?.state;
    return ChapterDownloadIndicators(
      ownComplete: ownComplete,
      alternateComplete: alternateComplete,
      isPartial: !ownComplete &&
          totalPages > 0 &&
          completedPages > 0 &&
          completedPages < totalPages,
      isActive: state == OfflineChapterState.pending ||
          state == OfflineChapterState.resolving ||
          state == OfflineChapterState.downloading,
      isPaused: state == OfflineChapterState.paused,
      isFailed: state == OfflineChapterState.failed,
    );
  }

  final bool ownComplete;
  final bool alternateComplete;
  final bool isPartial;
  final bool isActive;
  final bool isPaused;
  final bool isFailed;

  bool get isComplete => ownComplete || alternateComplete;
}

enum _ChapterAction { pause, resume, cancel, remove }

class ChapterDownloadSheet extends StatefulWidget {
  const ChapterDownloadSheet({
    super.key,
    required this.detail,
    required this.chapters,
    this.service,
  });

  final BaseComicDetailModel detail;
  final Map<String, List<BaseComicChapterEntityModel>> chapters;
  final ComicDownloadService? service;

  static Future<void> show(
    BuildContext context, {
    required BaseComicDetailModel detail,
    required Map<String, List<BaseComicChapterEntityModel>> chapters,
  }) => showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => FractionallySizedBox(
      heightFactor: 0.88,
      child: ChapterDownloadSheet(detail: detail, chapters: chapters),
    ),
  );

  @override
  State<ChapterDownloadSheet> createState() => _ChapterDownloadSheetState();
}

class _ChapterDownloadSheetState extends State<ChapterDownloadSheet> {
  late final ComicDownloadService _service =
      widget.service ?? ComicDownloadService.instance;
  late final ChapterDownloadSelection _selection = ChapterDownloadSelection(
    widget.chapters.values.expand((chapters) => chapters).map((c) => c.chapterId),
  );
  StreamSubscription<void>? _changes;
  Timer? _reloadDebounce;
  int _loadGeneration = 0;
  Map<ChapterKey, OfflineChapterProgress> _progress = const {};
  Map<String, OfflineChapterAvailability> _availability = const {};
  Object? _loadError;
  bool _loading = true;
  bool _submitting = false;
  final Set<ChapterKey> _busyChapters = <ChapterKey>{};

  ComicKey get _comicKey => (
    sourceId: widget.detail.parent.type.sourceId,
    comicId: widget.detail.comicId,
  );

  String _tr(BuildContext context, String zh, String en) =>
      Localizations.localeOf(context).languageCode == 'zh' ? zh : en;

  String _sourceName(String sourceId) {
    for (final source in context.read<ComicSourceProvider>().sources) {
      if (source.type.sourceId == sourceId) return source.type.sourceName;
    }
    return sourceId;
  }

  @override
  void initState() {
    super.initState();
    _selection.addListener(_selectionChanged);
    _changes = _service.changes.listen((_) {
      _reloadDebounce?.cancel();
      _reloadDebounce = Timer(
        const Duration(milliseconds: 250),
        () => unawaited(_load()),
      );
    }, onError: (Object error, StackTrace stack) {
      _reloadDebounce?.cancel();
      _loadGeneration++;
      if (!mounted) return;
      setState(() {
        _loadError = error;
        _loading = false;
      });
    });
    unawaited(_load());
  }

  @override
  void dispose() {
    _changes?.cancel();
    _reloadDebounce?.cancel();
    _loadGeneration++;
    _selection
      ..removeListener(_selectionChanged)
      ..dispose();
    super.dispose();
  }

  void _selectionChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    final generation = ++_loadGeneration;
    try {
      await _service.initialize();
      if (!mounted || generation != _loadGeneration) return;
      final aggregate = context.read<ConfigProvider>().aggregateDownloads;
      final progress = await _service.listChapterProgress(_comicKey);
      final availability = <String, OfflineChapterAvailability>{};
      for (final chapter in widget.chapters.values.expand((value) => value)) {
        availability[chapter.chapterId] = await _service.chapterAvailability(
          widget.detail,
          chapter.chapterId,
          includeMapped: aggregate,
        );
      }
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _progress = progress;
        _availability = availability;
        _loadError = null;
        _loading = false;
      });
    } catch (error) {
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _loadError = error;
        _loading = false;
      });
    }
  }

  Future<void> _submit() async {
    if (_selection.selectedIds.isEmpty || _submitting) return;
    setState(() => _submitting = true);
    try {
      await _service.initialize();
      await _service.downloadChapters(
        widget.detail,
        _selection.selectedIds.toList(growable: false),
      );
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _tr(context, '无法开始下载：$error', 'Could not start download: $error'),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = _selection.availableCount;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 12, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _tr(context, '下载章节', 'Download chapters'),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              TextButton(
                onPressed: _selection.selectedIds.length == total
                    ? _selection.clear
                    : _selection.selectAll,
                child: Text(
                  _selection.selectedIds.length == total
                      ? _tr(context, '清空', 'Clear')
                      : _tr(context, '全选', 'Select all'),
                ),
              ),
            ],
          ),
        ),
        if (_loading) const LinearProgressIndicator(),
        if (_loadError != null)
          MaterialBanner(
            content: Text(
              _tr(context, '下载状态加载失败：$_loadError', 'Could not load download state: $_loadError'),
            ),
            actions: [
              TextButton(onPressed: _load, child: Text(_tr(context, '重试', 'Retry'))),
            ],
          ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            children: [
              for (final group in widget.chapters.entries) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 14, 12, 4),
                  child: Text(
                    widget.detail.parent.formatDisplayText(group.key),
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                for (final chapter in group.value) _chapterTile(chapter),
              ],
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: FilledButton.icon(
              onPressed: _selection.selectedIds.isEmpty || _submitting ? null : _submit,
              icon: _submitting
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.download_rounded),
              label: Text(
                _tr(
                  context,
                  '下载所选 (${_selection.selectedIds.length})',
                  'Download selected (${_selection.selectedIds.length})',
                ),
              ),
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _handleAction(
    ChapterKey key,
    _ChapterAction action,
  ) async {
    if (!_busyChapters.add(key)) return;
    setState(() {});
    try {
      await _service.initialize();
      switch (action) {
        case _ChapterAction.pause:
          await _service.pauseChapter(key);
        case _ChapterAction.resume:
          await _service.resumeChapter(key);
        case _ChapterAction.cancel:
          await _service.cancelChapter(key);
        case _ChapterAction.remove:
          if (!mounted) return;
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (dialogContext) => AlertDialog(
              title: Text(_tr(context, '删除章节下载？', 'Delete chapter download?')),
              content: Text(
                _tr(
                  context,
                  '将删除此来源章节的永久文件和未完成任务，不影响阅读预缓存或其他来源版本。',
                  'This deletes durable files and unfinished tasks for this source chapter. Reading cache and other source versions are kept.',
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: Text(_tr(context, '取消', 'Cancel')),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: Text(_tr(context, '删除', 'Delete')),
                ),
              ],
            ),
          );
          if (confirmed == true) await _service.removeChapter(key);
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _tr(context, '章节操作失败：$error', 'Chapter action failed: $error'),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busyChapters.remove(key));
    }
  }

  Widget? _chapterActions(
    ChapterKey key,
    OfflineChapterProgress? progress,
    bool ownComplete,
  ) {
    if (_busyChapters.contains(key)) {
      return const SizedBox.square(
        dimension: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    if (progress == null && !ownComplete) return null;
    final state = progress?.state;
    return PopupMenuButton<_ChapterAction>(
      tooltip: _tr(context, '下载操作', 'Download actions'),
      onSelected: (action) => _handleAction(key, action),
      itemBuilder: (context) => [
        if (state == OfflineChapterState.pending ||
            state == OfflineChapterState.resolving ||
            state == OfflineChapterState.downloading)
          PopupMenuItem(
            value: _ChapterAction.pause,
            child: ListTile(
              leading: const Icon(Icons.pause_rounded),
              title: Text(_tr(context, '暂停', 'Pause')),
            ),
          ),
        if (state == OfflineChapterState.paused ||
            state == OfflineChapterState.failed ||
            state == OfflineChapterState.canceled)
          PopupMenuItem(
            value: _ChapterAction.resume,
            child: ListTile(
              leading: const Icon(Icons.play_arrow_rounded),
              title: Text(_tr(context, '继续或重试', 'Resume or retry')),
            ),
          ),
        if (state == OfflineChapterState.pending ||
            state == OfflineChapterState.resolving ||
            state == OfflineChapterState.downloading ||
            state == OfflineChapterState.paused)
          PopupMenuItem(
            value: _ChapterAction.cancel,
            child: ListTile(
              leading: const Icon(Icons.cancel_outlined),
              title: Text(_tr(context, '取消', 'Cancel')),
            ),
          ),
        PopupMenuItem(
          value: _ChapterAction.remove,
          child: ListTile(
            leading: const Icon(Icons.delete_outline),
            title: Text(_tr(context, '删除', 'Delete')),
          ),
        ),
      ],
    );
  }

  Widget _chapterTile(BaseComicChapterEntityModel chapter) {
    final key = (
      sourceId: _comicKey.sourceId,
      comicId: _comicKey.comicId,
      chapterId: chapter.chapterId,
    );
    final progress = _progress[key];
    final availability = _availability[chapter.chapterId];
    final indicators = ChapterDownloadIndicators.from(
      progress: progress,
      ownComplete: availability?.ownCompleteAvailable ?? false,
      alternateComplete: availability?.alternateCompleteAvailable ?? false,
    );
    final alternateSources = availability?.alternateCompletes
        .map((item) => _sourceName(item.key.sourceId))
        .join(' / ');
    return CheckboxListTile(
      value: _selection.isSelected(chapter.chapterId),
      onChanged: (_) => _selection.toggle(chapter.chapterId),
      title: Text(
        widget.detail.parent.formatDisplayText(chapter.rawTitle),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Wrap(
        spacing: 6,
        runSpacing: 4,
        children: [
          if (indicators.ownComplete)
            _badge(Icons.offline_pin_outlined, _tr(context, '本源已下载', 'Downloaded here')),
          if (!indicators.ownComplete && indicators.alternateComplete)
            _badge(
              Icons.hub_outlined,
              _tr(
                context,
                '其他源：$alternateSources',
                'Other source: $alternateSources',
              ),
            ),
          if (indicators.isPartial)
            _badge(Icons.pie_chart_outline, _tr(context, '部分完成', 'Partial')),
          if (indicators.isActive)
            _badge(Icons.downloading_rounded, _tr(context, '下载中', 'Downloading')),
          if (indicators.isPaused)
            _badge(Icons.pause_circle_outline, _tr(context, '已暂停', 'Paused')),
          if (indicators.isFailed)
            _badge(Icons.error_outline, _tr(context, '失败', 'Failed')),
          if (progress != null && progress.totalPages > 0 && !indicators.ownComplete)
            Text('${progress.completedPages}/${progress.totalPages}'),
          if (indicators.isFailed && progress?.error != null)
            Text(
              progress!.error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
        ],
      ),
      secondary: _chapterActions(key, progress, indicators.ownComplete),
      controlAffinity: ListTileControlAffinity.leading,
    );
  }

  Widget _badge(IconData icon, String label) => Chip(
    visualDensity: VisualDensity.compact,
    avatar: Icon(icon, size: 16),
    label: Text(label),
  );
}
