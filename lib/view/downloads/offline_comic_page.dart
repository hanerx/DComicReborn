import 'dart:async';

import 'package:dcomic/downloads/comic_download_models.dart';
import 'package:dcomic/downloads/comic_download_service.dart';
import 'package:dcomic/providers/models/offline_comic_model.dart';
import 'package:dcomic/providers/navigator_provider.dart';
import 'package:dcomic/providers/models/comic_source_model.dart';
import 'package:dcomic/providers/source_provider.dart';
import 'package:dcomic/view/comic_viewer/comic_viewer_page.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

List<T> offlineReaderChapterOrder<T>(List<T> sourceCatalogOrder) =>
    List<T>.unmodifiable(sourceCatalogOrder.reversed);

class OfflineComicPage extends StatefulWidget {
  const OfflineComicPage({super.key, required this.item, this.service});

  final OfflineComicListItem item;
  final ComicDownloadService? service;

  @override
  State<OfflineComicPage> createState() => _OfflineComicPageState();
}

class _OfflineComicPageState extends State<OfflineComicPage> {
  late final ComicDownloadService _service =
      widget.service ?? ComicDownloadService.instance;
  StreamSubscription<void>? _changes;
  Timer? _reloadDebounce;
  int _loadGeneration = 0;
  Map<ComicKey, List<OfflineChapterSnapshot>> _chapters = const {};
  Object? _error;
  bool _loading = true;
  final Set<ChapterKey> _busy = <ChapterKey>{};

  String _tr(String zh, String en) =>
      Localizations.localeOf(context).languageCode == 'zh' ? zh : en;

  @override
  void initState() {
    super.initState();
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
        _error = error;
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
    super.dispose();
  }

  Future<void> _load() async {
    final generation = ++_loadGeneration;
    try {
      await _service.initialize();
      final chapters = <ComicKey, List<OfflineChapterSnapshot>>{};
      for (final version in widget.item.versions) {
        chapters[version.comic.key] =
            await _service.listReadableChapters(version.comic.key);
      }
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _chapters = chapters;
        _error = null;
        _loading = false;
      });
    } catch (error) {
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  String _sourceName(String sourceId) {
    final provider = context.read<ComicSourceProvider>();
    for (final source in provider.sources) {
      if (source.type.sourceId == sourceId) return source.type.sourceName;
    }
    return sourceId;
  }

  String _displayText(String sourceId, String text) {
    final provider = context.read<ComicSourceProvider>();
    for (final source in provider.sources) {
      if (source.type.sourceId == sourceId) {
        return source.formatDisplayText(text);
      }
    }
    return text;
  }

  Future<void> _open(
    OfflineComicVersion version,
    OfflineChapterSnapshot chapter,
  ) async {
    final readable = _chapters[version.comic.key] ?? const [];
    if (readable.isEmpty) {
      _showMessage(_tr('本地章节已不可用。', 'The local chapters are no longer available.'));
      return;
    }
    late final OfflineComicDetailModel detail;
    try {
      await _service.initialize();
      detail = await OfflineComicDetailModel.fromStore(
        store: _service.store,
        comicKey: version.comic.key,
      );
      await detail.init();
    } catch (error) {
      _showMessage(
        _tr('无法打开本地漫画：$error', 'Could not open local comic: $error'),
      );
      return;
    }
    if (!mounted) return;
    List<BaseComicChapterEntityModel> chapters = const [];
    for (final entry in detail.chapters.entries) {
      if (entry.value.any((item) => item.chapterId == chapter.key.chapterId)) {
        chapters = offlineReaderChapterOrder(entry.value);
        break;
      }
    }
    if (chapters.isEmpty) {
      _showMessage(_tr('本地章节清单已变化，请刷新。', 'The local chapter list changed. Refresh and try again.'));
      return;
    }
    context
        .read<NavigatorProvider>()
        .getNavigator(context, NavigatorType.root)
        ?.push(
          MaterialPageRoute(
            builder: (_) => ComicViewerPage(
              detailModel: detail,
              chapters: chapters,
              chapterId: chapter.key.chapterId,
            ),
            settings: const RouteSettings(name: 'ComicViewerPage'),
          ),
        );
  }

  Future<void> _remove(OfflineChapterSnapshot chapter) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(_tr('删除离线章节？', 'Delete offline chapter?')),
        content: Text(
          _tr(
            '将删除“${chapter.rawTitle}”的永久下载文件。阅读预缓存和其他来源版本不会被删除。',
            'This deletes the durable files for “${chapter.rawTitle}”. Reading cache and versions from other sources are kept.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(_tr('取消', 'Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(_tr('删除', 'Delete')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy.add(chapter.key));
    try {
      await _service.removeChapter(chapter.key);
      await _load();
    } catch (error) {
      _showMessage(_tr('删除失败：$error', 'Could not delete: $error'));
    } finally {
      if (mounted) setState(() => _busy.remove(chapter.key));
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _displayText(
            widget.item.versions.first.comic.key.sourceId,
            widget.item.title,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 96),
          Icon(Icons.error_outline, size: 48, color: Theme.of(context).colorScheme.error),
          const SizedBox(height: 12),
          Center(child: Text(_tr('无法读取离线目录：$_error', 'Could not load offline library: $_error'))),
          const SizedBox(height: 12),
          Center(child: FilledButton(onPressed: _load, child: Text(_tr('重试', 'Retry')))),
        ],
      );
    }
    final hasChapters = _chapters.values.any((chapters) => chapters.isNotEmpty);
    if (!hasChapters) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 112),
          const Icon(Icons.offline_pin_outlined, size: 52),
          const SizedBox(height: 12),
          Center(child: Text(_tr('没有完整可读的本地章节', 'No complete local chapters'))),
        ],
      );
    }
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
      children: [
        if (widget.item.aggregated)
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 12),
            child: Text(
              _tr(
                '此目录按漫画映射聚合。每个版本仍归属于标注的实际来源，请明确选择要阅读的版本。',
                'This library entry is grouped by comic mapping. Each version still belongs to its labeled source; choose the version to read explicitly.',
              ),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        for (final version in widget.item.versions)
          _versionCard(version, _chapters[version.comic.key] ?? const []),
      ],
    );
  }

  Widget _versionCard(
    OfflineComicVersion version,
    List<OfflineChapterSnapshot> chapters,
  ) {
    final source = _sourceName(version.comic.key.sourceId);
    final groups = <String, List<OfflineChapterSnapshot>>{};
    for (final chapter in chapters) {
      groups.putIfAbsent(chapter.groupName, () => []).add(chapter);
    }
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        initiallyExpanded: widget.item.versions.length == 1,
        leading: const Icon(Icons.storage_outlined),
        title: Text(source),
        subtitle: Text(_tr('${chapters.length} 个完整章节', '${chapters.length} complete chapters')),
        children: [
          if (chapters.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(_tr('此版本已没有完整章节', 'This version has no complete chapters')),
            ),
          for (final group in groups.entries) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _displayText(version.comic.key.sourceId, group.key),
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
            ),
            for (final chapter in group.value)
              ListTile(
                leading: const Icon(Icons.offline_pin_outlined),
                title: Text(
                  _displayText(
                    version.comic.key.sourceId,
                    chapter.rawTitle,
                  ),
                ),
                subtitle: Text(_tr('本地 · $source', 'Local · $source')),
                onTap: _busy.contains(chapter.key) ? null : () => _open(version, chapter),
                trailing: _busy.contains(chapter.key)
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : IconButton(
                        tooltip: _tr('删除下载', 'Delete download'),
                        onPressed: () => _remove(chapter),
                        icon: const Icon(Icons.delete_outline),
                      ),
              ),
          ],
        ],
      ),
    );
  }
}
