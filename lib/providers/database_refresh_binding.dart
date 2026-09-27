import 'dart:async';

import 'package:dcomic/database/database_instance.dart';
import 'package:dcomic/database/sync/sync_models.dart';
import 'package:dcomic/providers/chapter_rule_store.dart';
import 'package:dcomic/providers/config_provider.dart';
import 'package:dcomic/providers/source_provider.dart';
import 'package:dcomic/providers/subscribe_badge_state.dart';
import 'package:dcomic/requests/base_request.dart';

/// Adapts committed external database changes to existing cache notifications.
/// Business providers continue to read the database, never the sync transport.
class DatabaseRefreshBinding {
  DatabaseRefreshBinding(this.config, this.sources) {
    unawaited(_attach());
  }

  final ConfigProvider config;
  final ComicSourceProvider sources;
  StreamSubscription<Set<SyncCategory>>? _subscription;
  Future<void> _refresh = Future.value();
  bool _disposed = false;

  Future<void> _attach() async {
    try {
      await DatabaseInstance.instance;
      final store = DatabaseInstance.syncStore;
      if (_disposed) return;
      _subscription = store.changes.listen((categories) {
        _refresh = _refresh.then((_) => _reload(categories)).catchError(
          (Object error, StackTrace stack) {
            config.logger.e('Database cache refresh failed',
                error: error, stackTrace: stack);
          },
        );
      });
    } catch (error, stack) {
      config.logger.e('Database change listener failed',
          error: error, stackTrace: stack);
    }
  }

  Future<void> _reload(Set<SyncCategory> categories) async {
    if (_disposed) return;
    if (categories.contains(SyncCategory.settings)) {
      await config.init();
      if (_disposed) return;
      await sources.reloadStoredSettings();
    }
    if (_disposed) return;
    if (categories.any({
      SyncCategory.history,
      SyncCategory.bindings,
      SyncCategory.chapterRules,
      SyncCategory.settings,
    }.contains)) {
      // ComicReadingProgress shares this notifier with chapter matching rules.
      ChapterRuleStore.changes.value++;
      SubscribeBadgeState.changes.value++;
    }
    if (categories.contains(SyncCategory.credentials)) {
      for (final handler in [
        RequestHandlers.copyMangaRequestHandler,
        RequestHandlers.zaiManHuaRequestHandler,
        RequestHandlers.zaiManHuaMobileRequestHandler,
        RequestHandlers.zaiManHuaAccountRequestHandler,
        RequestHandlers.zaiManHuaTaskRequestHandler,
      ]) {
        handler.reloadPersistedCookies();
      }
      // A cached account response must not survive a change of credentials.
      await (await RequestStatics.store).clean();
    }
    if (_disposed) return;
    if (categories.contains(SyncCategory.credentials) ||
        categories.contains(SyncCategory.sourceSettings)) {
      for (final source in sources.sources) {
        if (_disposed) return;
        await source.initModel();
      }
      if (!_disposed) sources.callNotify();
    }
  }

  void dispose() {
    _disposed = true;
    unawaited(_subscription?.cancel());
  }
}
