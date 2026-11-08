import 'dart:async';

import 'package:dcomic/downloads/comic_download_service.dart';
import 'package:dcomic/providers/config_provider.dart';
import 'package:dcomic/providers/source_provider.dart';

/// Keeps persisted downloads independent of routes and source selection.
class DownloadRuntimeBinding {
  DownloadRuntimeBinding(this.config, this.sources) {
    final service = ComicDownloadService.instance;
    service.configureSourceLookup((sourceId) async {
      for (final source in sources.sources) {
        if (source.type.sourceId == sourceId) return source;
      }
      return null;
    });
    config.addListener(_settingsChanged);
    unawaited(_initialize());
  }

  final ConfigProvider config;
  final ComicSourceProvider sources;
  bool _disposed = false;
  bool? _aggregate;
  bool? _reuse;

  Future<void> _initialize() async {
    try {
      await ComicDownloadService.instance.initialize();
      if (!_disposed) _settingsChanged();
    } catch (error, stack) {
      // Download pages await initialize too and display initialization failures.
      config.logger.e('Download initialization failed', error: error, stackTrace: stack);
    }
  }

  void _settingsChanged() {
    if (_disposed) return;
    final aggregate = config.aggregateDownloads;
    final reuse = config.reuseDownloadedChaptersAcrossSources;
    if (_aggregate == aggregate && _reuse == reuse) return;
    _aggregate = aggregate;
    _reuse = reuse;
    unawaited(ComicDownloadService.instance.refreshSettings().catchError(
      (Object error, StackTrace stack) {
        config.logger.e('Download settings refresh failed', error: error, stackTrace: stack);
      },
    ));
  }

  void dispose() {
    _disposed = true;
    config.removeListener(_settingsChanged);
  }
}
