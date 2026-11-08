import 'dart:async';
import 'package:background_downloader/background_downloader.dart';

import 'package:dcomic/downloads/comic_download_models.dart';
import 'package:dcomic/downloads/comic_download_service.dart';
import 'package:dcomic/downloads/download_models.dart';
import 'package:dcomic/providers/config_provider.dart';
import 'package:dcomic/providers/download_provider.dart';
import 'package:dcomic/providers/navigator_provider.dart';
import 'package:dcomic/providers/source_provider.dart';
import 'package:dcomic/view/downloads/offline_comic_page.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class DownloadTaskActionRouter {
  const DownloadTaskActionRouter({
    required this.chapterForTask,
    required this.resumeChapter,
    required this.resumeGeneric,
  });

  final Future<ChapterKey?> Function(String taskId) chapterForTask;
  final Future<void> Function(ChapterKey key) resumeChapter;
  final Future<void> Function(String taskId) resumeGeneric;

  Future<void> resume(String taskId) async {
    final chapter = await chapterForTask(taskId);
    if (chapter != null) {
      await resumeChapter(chapter);
    } else {
      await resumeGeneric(taskId);
    }
  }
}

class DownloadPage extends StatelessWidget {
  const DownloadPage({super.key});

  String _tr(BuildContext context, String zh, String en) =>
      Localizations.localeOf(context).languageCode == 'zh' ? zh : en;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(_tr(context, '下载管理', 'Downloads')),
          bottom: TabBar(
            tabs: [
              Tab(icon: const Icon(Icons.downloading_rounded), text: _tr(context, '任务', 'Tasks')),
              Tab(icon: const Icon(Icons.offline_pin_outlined), text: _tr(context, '已下载漫画', 'Offline comics')),
            ],
          ),
        ),
        body: const TabBarView(
          children: [_DownloadTaskList(), _OfflineLibrary()],
        ),
      ),
    );
  }
}

class _DownloadTaskList extends StatefulWidget {
  const _DownloadTaskList();

  @override
  State<_DownloadTaskList> createState() => _DownloadTaskListState();
}

class _DownloadTaskListState extends State<_DownloadTaskList> {
  final Set<String> _busy = <String>{};
  final ComicDownloadService _comicDownloads = ComicDownloadService.instance;
  final Set<ChapterKey> _busyChapters = <ChapterKey>{};
  late final DownloadTaskActionRouter _actionRouter;
  StreamSubscription<void>? _comicChanges;
  Timer? _chapterReloadDebounce;
  List<OfflineChapterTask> _chapterTasks = const [];
  Object? _chapterTaskError;
  bool _chapterTasksLoading = true;
  int _chapterLoadGeneration = 0;

  @override
  void initState() {
    super.initState();
    final generic = context.read<DownloadProvider>().service;
    _actionRouter = DownloadTaskActionRouter(
      chapterForTask: _comicDownloads.chapterForTask,
      resumeChapter: _comicDownloads.resumeChapter,
      resumeGeneric: generic.resume,
    );
    _comicChanges = _comicDownloads.changes.listen((_) {
      _chapterReloadDebounce?.cancel();
      _chapterReloadDebounce = Timer(
        const Duration(milliseconds: 250),
        () => unawaited(_loadChapterTasks()),
      );
    }, onError: (Object error, StackTrace stack) {
      _chapterReloadDebounce?.cancel();
      _chapterLoadGeneration++;
      if (!mounted) return;
      setState(() {
        _chapterTaskError = error;
        _chapterTasksLoading = false;
      });
    });
    unawaited(_loadChapterTasks());
  }

  @override
  void dispose() {
    _chapterLoadGeneration++;
    _comicChanges?.cancel();
    _chapterReloadDebounce?.cancel();
    super.dispose();
  }

  Future<void> _loadChapterTasks() async {
    final generation = ++_chapterLoadGeneration;
    try {
      await _comicDownloads.initialize();
      final tasks = await _comicDownloads.listIncompleteChapterTasks();
      if (!mounted || generation != _chapterLoadGeneration) return;
      setState(() {
        _chapterTasks = tasks;
        _chapterTaskError = null;
        _chapterTasksLoading = false;
      });
    } catch (error) {
      if (!mounted || generation != _chapterLoadGeneration) return;
      setState(() {
        _chapterTaskError = error;
        _chapterTasksLoading = false;
      });
    }
  }


  String _tr(String zh, String en) =>
      Localizations.localeOf(context).languageCode == 'zh' ? zh : en;

  String _bytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KiB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MiB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GiB';
  }

  String _stateLabel(DownloadState state) => switch (state) {
    DownloadState.queued => _tr('等待中', 'Queued'),
    DownloadState.running => _tr('下载中', 'Downloading'),
    DownloadState.paused => _tr('已暂停', 'Paused'),
    DownloadState.verifying => _tr('正在校验', 'Verifying'),
    DownloadState.completed => _tr('已完成并校验', 'Completed and verified'),
    DownloadState.failed => _tr('失败', 'Failed'),
    DownloadState.canceled => _tr('已取消', 'Canceled'),
  };

  String _chapterStateLabel(OfflineChapterState state) => switch (state) {
    OfflineChapterState.pending => _tr('等待中', 'Queued'),
    OfflineChapterState.resolving => _tr('正在获取章节清单', 'Resolving chapter'),
    OfflineChapterState.downloading => _tr('下载中', 'Downloading'),
    OfflineChapterState.paused => _tr('已暂停', 'Paused'),
    OfflineChapterState.completed => _tr('已完成', 'Completed'),
    OfflineChapterState.failed => _tr('失败', 'Failed'),
    OfflineChapterState.canceled => _tr('已取消', 'Canceled'),
  };

  String _sourceName(String sourceId) {
    for (final source in context.read<ComicSourceProvider>().sources) {
      if (source.type.sourceId == sourceId) return source.type.sourceName;
    }
    return sourceId;
  }

  String _sourceText(String sourceId, String text) {
    for (final source in context.read<ComicSourceProvider>().sources) {
      if (source.type.sourceId == sourceId) {
        return source.formatDisplayText(text);
      }
    }
    return text;
  }

  Future<void> _run(String id, Future<void> Function() action) async {
    if (!_busy.add(id)) return;
    setState(() {});
    try {
      await action();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(content: Text(_tr('操作失败：$error', 'Action failed: $error'))),
          );
      }
    } finally {
      if (mounted) setState(() => _busy.remove(id));
    }
  }

  Future<void> _runChapter(
    ChapterKey key,
    Future<void> Function() action,
  ) async {
    if (!_busyChapters.add(key)) return;
    setState(() {});
    try {
      await action();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(
                _tr('章节操作失败：$error', 'Chapter action failed: $error'),
              ),
            ),
          );
      }
    } finally {
      if (mounted) setState(() => _busyChapters.remove(key));
    }
  }

  Future<void> _confirmRemoveChapter(OfflineChapterTask task) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(_tr('移除章节下载？', 'Remove chapter download?')),
        content: Text(
          _tr(
            '将取消未完成传输并删除此来源章节的任务与永久文件。',
            'Unfinished transfers will be canceled and this source chapter task and durable files will be deleted.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(_tr('取消', 'Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(_tr('移除', 'Remove')),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await _runChapter(
        task.chapter.key,
        () => _comicDownloads.removeChapter(task.chapter.key),
      );
    }
  }

  Future<void> _open(DownloadProvider provider, DownloadRecord record) async {
    await _run(record.id, () async {
      final file = await provider.service.completedFile(record.id);
      if (file == null || !await file.exists()) {
        throw StateError(
          _tr('文件缺失或校验已失效', 'The file is missing or no longer valid'),
        );
      }
      final opened = await FileDownloader().openFile(filePath: file.path);
      if (!opened) {
        throw StateError(
          _tr('系统没有可打开此文件的应用', 'No application can open this file'),
        );
      }
    });
  }

  Future<void> _confirmRemove(
    DownloadProvider provider,
    DownloadRecord record,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(_tr('移除下载？', 'Remove download?')),
        content: Text(
          _tr(
            '任务记录、临时文件和已下载文件都会被删除。',
            'The task record, temporary files, and completed file will be deleted.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(_tr('取消', 'Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(_tr('移除', 'Remove')),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await _run(record.id, () => provider.service.remove(record.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DownloadProvider>();
    return FutureBuilder<void>(
      future: provider.ready,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final startupError = snapshot.error;
        if (startupError != null) {
          return _MessageList(
            icon: Icons.error_outline,
            message: _tr(
              '下载服务初始化失败：$startupError',
              'Download service failed to start: $startupError',
            ),
          );
        }
        final records = provider.records.toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        final itemCount = _chapterTasks.length + records.length;
        final Widget content = itemCount == 0 && _chapterTasksLoading
            ? const Center(child: CircularProgressIndicator())
            : itemCount == 0
            ? _MessageList(
                icon: Icons.download_done_outlined,
                message: _tr('还没有下载任务', 'No download tasks yet'),
              )
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                itemCount: itemCount,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  if (index < _chapterTasks.length) {
                    return _chapterTaskCard(_chapterTasks[index]);
                  }
                  return _taskCard(
                    provider,
                    records[index - _chapterTasks.length],
                  );
                },
              );
        final notices = <Object>[
          if (provider.error case final warning?) warning,
          if (_chapterTaskError case final error?) error,
        ];
        if (notices.isEmpty) return content;
        return Column(
          children: [
            for (final notice in notices)
              Material(
                color: Theme.of(context).colorScheme.tertiaryContainer,
                child: ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: Text(_tr('下载服务提示', 'Download service notice')),
                  subtitle: Text('$notice'),
                ),
              ),
            Expanded(child: content),
          ],
        );
      },
    );
  }

  Widget _chapterTaskCard(OfflineChapterTask task) {
    final colors = Theme.of(context).colorScheme;
    final chapter = task.chapter;
    final progress = task.progress;
    final key = chapter.key;
    final busy = _busyChapters.contains(key);
    final active = progress.state == OfflineChapterState.pending ||
        progress.state == OfflineChapterState.resolving ||
        progress.state == OfflineChapterState.downloading;
    final pageProgress = progress.totalPages > 0
        ? (progress.completedPages / progress.totalPages).clamp(0.0, 1.0)
        : null;
    final source = _sourceName(key.sourceId);
    final title = _sourceText(
      key.sourceId,
      '${task.comic.rawTitle} · ${chapter.rawTitle}',
    );
    final pageText = progress.totalPages == 0
        ? _tr('尚未生成文件任务', 'No file tasks created')
        : '${progress.completedPages}/${progress.totalPages}';
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  progress.state == OfflineChapterState.failed
                      ? Icons.error_outline
                      : Icons.menu_book_outlined,
                  color: progress.state == OfflineChapterState.failed
                      ? colors.error
                      : colors.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      Text(
                        '$source · ${_chapterStateLabel(progress.state)} · $pageText',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                if (busy)
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                else
                  _chapterTaskActions(task),
              ],
            ),
            if (active) ...[
              const SizedBox(height: 12),
              LinearProgressIndicator(value: pageProgress),
            ],
            if (progress.error case final error?) ...[
              const SizedBox(height: 8),
              Text(error, style: TextStyle(color: colors.error)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _chapterTaskActions(OfflineChapterTask task) {
    final state = task.progress.state;
    final key = task.chapter.key;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (state == OfflineChapterState.pending ||
            state == OfflineChapterState.resolving ||
            state == OfflineChapterState.downloading)
          IconButton(
            tooltip: _tr('暂停章节', 'Pause chapter'),
            onPressed: () => _runChapter(
              key,
              () => _comicDownloads.pauseChapter(key),
            ),
            icon: const Icon(Icons.pause_rounded),
          ),
        if (state == OfflineChapterState.paused ||
            state == OfflineChapterState.failed ||
            state == OfflineChapterState.canceled)
          IconButton(
            tooltip: state == OfflineChapterState.failed
                ? _tr('刷新清单并重试', 'Refresh manifest and retry')
                : _tr('继续章节', 'Resume chapter'),
            onPressed: () => _runChapter(
              key,
              () => _comicDownloads.resumeChapter(key),
            ),
            icon: const Icon(Icons.play_arrow_rounded),
          ),
        if (state == OfflineChapterState.pending ||
            state == OfflineChapterState.resolving ||
            state == OfflineChapterState.downloading ||
            state == OfflineChapterState.paused ||
            state == OfflineChapterState.failed)
          IconButton(
            tooltip: _tr('取消章节', 'Cancel chapter'),
            onPressed: () => _runChapter(
              key,
              () => _comicDownloads.cancelChapter(key),
            ),
            icon: const Icon(Icons.cancel_outlined),
          ),
        IconButton(
          tooltip: _tr('移除章节任务', 'Remove chapter task'),
          onPressed: () => _confirmRemoveChapter(task),
          icon: const Icon(Icons.delete_outline),
        ),
      ],
    );
  }

  Widget _taskCard(DownloadProvider provider, DownloadRecord record) {
    final colors = Theme.of(context).colorScheme;
    final total = record.totalBytes;
    final progress = total != null && total > 0
        ? (record.bytesReceived / total).clamp(0.0, 1.0)
        : null;
    final active = record.state == DownloadState.running ||
        record.state == DownloadState.verifying;
    final busy = _busy.contains(record.id);
    final subtitle = total == null || total <= 0
        ? '${_bytes(record.bytesReceived)} · ${_stateLabel(record.state)}'
        : '${_bytes(record.bytesReceived)} / ${_bytes(total)} · ${_stateLabel(record.state)}';
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  record.state == DownloadState.completed
                      ? Icons.verified_outlined
                      : record.state == DownloadState.failed
                          ? Icons.error_outline
                          : Icons.download_outlined,
                  color: record.state == DownloadState.failed ? colors.error : colors.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        record.request.displayName ?? record.id,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      Text(
                        '${record.request.group} · $subtitle',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                if (busy)
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                else
                  _actions(provider, record),
              ],
            ),
            if (active || record.state == DownloadState.queued) ...[
              const SizedBox(height: 12),
              LinearProgressIndicator(value: progress),
            ],
            if (record.error case final error?) ...[
              const SizedBox(height: 8),
              Text(error, style: TextStyle(color: colors.error)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _actions(DownloadProvider provider, DownloadRecord record) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (record.state == DownloadState.queued ||
            record.state == DownloadState.running)
          IconButton(
            tooltip: _tr('暂停', 'Pause'),
            onPressed: () => _run(record.id, () => provider.service.pause(record.id)),
            icon: const Icon(Icons.pause_rounded),
          ),
        if (record.state == DownloadState.paused ||
            record.state == DownloadState.failed)
          IconButton(
            tooltip: record.state == DownloadState.failed
                ? _tr('重试', 'Retry')
                : _tr('继续', 'Resume'),
            onPressed: () =>
                _run(record.id, () => _actionRouter.resume(record.id)),
            icon: const Icon(Icons.play_arrow_rounded),
          ),
        if (record.state == DownloadState.queued ||
            record.state == DownloadState.running ||
            record.state == DownloadState.paused ||
            record.state == DownloadState.verifying ||
            record.state == DownloadState.failed)
          IconButton(
            tooltip: _tr('取消', 'Cancel'),
            onPressed: () => _run(record.id, () => provider.service.cancel(record.id)),
            icon: const Icon(Icons.cancel_outlined),
          ),
        if (record.state == DownloadState.completed)
          IconButton(
            tooltip: _tr('校验并打开', 'Validate and open'),
            onPressed: () => _open(provider, record),
            icon: const Icon(Icons.open_in_new_rounded),
          ),
        if (record.state == DownloadState.completed ||
            record.state == DownloadState.failed ||
            record.state == DownloadState.canceled)
          IconButton(
            tooltip: _tr('移除', 'Remove'),
            onPressed: () => _confirmRemove(provider, record),
            icon: const Icon(Icons.delete_outline),
          ),
      ],
    );
  }
}

class _OfflineLibrary extends StatefulWidget {
  const _OfflineLibrary();

  @override
  State<_OfflineLibrary> createState() => _OfflineLibraryState();
}

class _OfflineLibraryState extends State<_OfflineLibrary> {
  final ComicDownloadService _service = ComicDownloadService.instance;
  StreamSubscription<void>? _changes;
  Timer? _reloadDebounce;
  int _loadGeneration = 0;
  List<OfflineComicListItem> _items = const [];
  Object? _error;
  bool _loading = true;
  bool? _loadedAggregate;

  String _tr(String zh, String en) =>
      Localizations.localeOf(context).languageCode == 'zh' ? zh : en;

  @override
  void initState() {
    super.initState();
    _changes = _service.changes.listen((_) {
      _reloadDebounce?.cancel();
      _reloadDebounce = Timer(
        const Duration(milliseconds: 250),
        () => unawaited(_reload()),
      );
    }, onError: (Object error, StackTrace stack) {
      _reloadDebounce?.cancel();
      _loadGeneration++;
      if (!mounted) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final aggregate = context.watch<ConfigProvider>().aggregateDownloads;
    if (_loadedAggregate != aggregate) {
      _loadedAggregate = aggregate;
      unawaited(_reload());
    }
  }

  @override
  void dispose() {
    _changes?.cancel();
    _reloadDebounce?.cancel();
    _loadGeneration++;
    super.dispose();
  }

  Future<void> _reload() async {
    final generation = ++_loadGeneration;
    final aggregate = _loadedAggregate ?? context.read<ConfigProvider>().aggregateDownloads;
    try {
      await _service.initialize();
      final items = await _service.listReadableComics(aggregate: aggregate);
      if (!mounted ||
          generation != _loadGeneration ||
          aggregate != _loadedAggregate) {
        return;
      }
      setState(() {
        _items = items;
        _error = null;
        _loading = false;
      });
    } catch (error) {
      if (!mounted ||
          generation != _loadGeneration ||
          aggregate != _loadedAggregate) {
        return;
      }
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  String _sourceName(String sourceId) {
    for (final source in context.read<ComicSourceProvider>().sources) {
      if (source.type.sourceId == sourceId) return source.type.sourceName;
    }
    return sourceId;
  }
  String _displayTitle(OfflineComicListItem item) {
    final sourceId = item.versions.first.comic.key.sourceId;
    for (final source in context.read<ComicSourceProvider>().sources) {
      if (source.type.sourceId == sourceId) {
        return source.formatDisplayText(item.title);
      }
    }
    return item.title;
  }


  void _open(OfflineComicListItem item) {
    context
        .read<NavigatorProvider>()
        .getNavigator(context, NavigatorType.defaultNavigator)
        ?.push(
          MaterialPageRoute(
            builder: (_) => OfflineComicPage(item: item),
            settings: const RouteSettings(name: 'OfflineComicPage'),
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return RefreshIndicator(
        onRefresh: _reload,
        child: _MessageList(
          icon: Icons.error_outline,
          message: _tr('离线漫画加载失败：$_error', 'Could not load offline comics: $_error'),
        ),
      );
    }
    if (_items.isEmpty) {
      return RefreshIndicator(
        onRefresh: _reload,
        child: _MessageList(
          icon: Icons.offline_pin_outlined,
          message: _tr('没有完整下载的漫画章节', 'No fully downloaded comic chapters'),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _reload,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
        itemCount: _items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 6),
        itemBuilder: (context, index) {
          final item = _items[index];
          final sources = item.sourceIds.map(_sourceName).join(' · ');
          return Card(
            child: ListTile(
              leading: const CircleAvatar(child: Icon(Icons.menu_book_outlined)),
              title: Text(
                _displayTitle(item),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                _tr(
                  '$sources · ${item.readableChapterCount} 个完整章节',
                  '$sources · ${item.readableChapterCount} complete chapters',
                ),
              ),
              trailing: item.aggregated
                  ? Tooltip(
                      message: _tr('已按漫画映射聚合', 'Grouped by comic mapping'),
                      child: const Icon(Icons.hub_outlined),
                    )
                  : const Icon(Icons.chevron_right_rounded),
              onTap: () => _open(item),
            ),
          );
        },
      ),
    );
  }
}

class _MessageList extends StatelessWidget {
  const _MessageList({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 112),
        Icon(icon, size: 52, color: Theme.of(context).colorScheme.onSurfaceVariant),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(message, textAlign: TextAlign.center),
        ),
      ],
    );
  }
}
