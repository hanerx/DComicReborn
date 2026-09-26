import 'dart:async';

import 'package:dcomic/database/database_instance.dart';
import 'package:dcomic/providers/automatic_mapping.dart';
import 'package:dcomic/providers/base_provider.dart';
import 'package:dcomic/providers/models/comic_source_model.dart';
import 'package:dcomic/providers/subscribe_badge_state.dart';

class ComicFavoritePageController extends BaseProvider {
  BaseComicSourceModel sourceModel;
  int _page = 0;
  List<GridItemEntity> data = [];
  bool _disposed = false;
  final AutomaticMappingQueue? mappingQueue;
  Map<String, List<String>> _sourceIdsByComicId = const {};
  List<String>? _currentSourceOnly;

  ComicFavoritePageController(this.sourceModel, {this.mappingQueue}) {
    SubscribeBadgeState.changes.addListener(_onBadgeStateChanged);
    mappingQueue?.addListener(_enqueueMissingMappings);
  }

  List<String> sourceIdsFor(GridItemEntity item) {
    final currentSourceId = sourceModel.type.sourceId;
    final currentSourceOnly = _currentSourceOnly;
    final fallback =
        currentSourceOnly != null && currentSourceOnly.single == currentSourceId
        ? currentSourceOnly
        : _currentSourceOnly = List.unmodifiable([currentSourceId]);
    if (item is! GridItemEntityWithStatus) return fallback;
    return _sourceIdsByComicId[item.comicId] ?? fallback;
  }

  void _enqueueMissingMappings() {
    if (!_disposed) mappingQueue?.enqueue(sourceModel, data);
  }

  Future<void> _localRefresh = Future.value();

  void _onBadgeStateChanged() {
    unawaited(
      refreshBadges().catchError((Object error, StackTrace stack) {
        logger.e(
          'Failed to refresh favorite local state',
          error: error,
          stackTrace: stack,
        );
      }),
    );
  }

  Future<void> refresh() async {
    _page = 0;
    final refreshed = await sourceModel.accountModel!
        .getSubscribeStateComics(page: _page);
    if (_disposed) return;
    data = refreshed;
    try {
      await _reconcileLocalState(notifyAlways: true);
    } finally {
      _enqueueMissingMappings();
    }
  }

  Future<void> load() async {
    _page++;
    final page = await sourceModel.accountModel!.getSubscribeStateComics(
      page: _page,
    );
    if (_disposed) return;
    data += page;
    try {
      await _reconcileLocalState(notifyAlways: true);
    } finally {
      _enqueueMissingMappings();
    }
  }

  Future<void> refreshBadges() =>
      _reconcileLocalState(refreshBadges: true);

  Future<void> _reconcileLocalState({
    bool refreshBadges = false,
    bool notifyAlways = false,
  }) {
    // Initial loads, pagination, and live local changes share one queue so an
    // older mapping/read snapshot cannot overwrite a newer reconciliation.
    final reconciliation = _localRefresh.then((_) async {
      if (_disposed) return;
      var changed = false;
      try {
        changed = await _refreshBindingSources();
        if (!_disposed && refreshBadges && data.isNotEmpty) {
          changed =
              await sourceModel.accountModel!.refreshSubscribeBadges(data) ||
              changed;
        }
      } finally {
        if (!_disposed && (notifyAlways || changed)) notifyListeners();
      }
    });
    _localRefresh = reconciliation.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return reconciliation;
  }

  Future<bool> _refreshBindingSources() async {
    final currentSourceId = sourceModel.type.sourceId;
    final comicIds = <String>{
      for (final item in data)
        if (item is GridItemEntityWithStatus) item.comicId,
    };
    if (comicIds.isEmpty) {
      final changed = _sourceIdsByComicId.isNotEmpty;
      _sourceIdsByComicId = const {};
      return changed;
    }

    // A single table snapshot drives every loaded item in this reconciliation.
    final mappings =
        await (await DatabaseInstance.instance).comicMappingDao
            .getAllComicMappingEntity();
    final edges = <({
      String providerA,
      String comicA,
      String providerB,
      String comicB,
    })>[];
    final counterparts = <(String, String, String), Set<String>>{};
    for (final mapping in mappings) {
      if (mapping.blocked ||
          mapping.providerA.isEmpty ||
          mapping.comicA.isEmpty ||
          mapping.providerB.isEmpty ||
          mapping.comicB.isEmpty) {
        continue;
      }
      final edge = (
        providerA: mapping.providerA,
        comicA: mapping.comicA,
        providerB: mapping.providerB,
        comicB: mapping.comicB,
      );
      edges.add(edge);
      (counterparts[(edge.providerA, edge.comicA, edge.providerB)] ??=
              <String>{})
          .add(edge.comicB);
      (counterparts[(edge.providerB, edge.comicB, edge.providerA)] ??=
              <String>{})
          .add(edge.comicA);
    }

    final sourcesByEndpoint = <(String, String), Set<String>>{};
    for (final edge in edges) {
      if (counterparts[(edge.providerA, edge.comicA, edge.providerB)]!
                  .length !=
              1 ||
          counterparts[(edge.providerB, edge.comicB, edge.providerA)]!
                  .length !=
              1) {
        continue;
      }
      (sourcesByEndpoint[(edge.providerA, edge.comicA)] ??= <String>{})
          .add(edge.providerB);
      (sourcesByEndpoint[(edge.providerB, edge.comicB)] ??= <String>{})
          .add(edge.providerA);
    }

    final next = <String, List<String>>{};
    for (final comicId in comicIds) {
      final boundSources = [
        ...?sourcesByEndpoint[(currentSourceId, comicId)],
      ]..remove(currentSourceId);
      boundSources.sort();
      next[comicId] = List.unmodifiable([
        currentSourceId,
        ...boundSources,
      ]);
    }
    if (_disposed) return false;
    final changed = !_sameSourceIds(_sourceIdsByComicId, next);
    _sourceIdsByComicId = next;
    return changed;
  }

  static bool _sameSourceIds(
    Map<String, List<String>> current,
    Map<String, List<String>> next,
  ) {
    if (current.length != next.length) return false;
    for (final entry in current.entries) {
      final other = next[entry.key];
      if (other == null || other.length != entry.value.length) return false;
      for (var index = 0; index < other.length; index++) {
        if (entry.value[index] != other[index]) return false;
      }
    }
    return true;
  }

  @override
  void dispose() {
    _disposed = true;
    SubscribeBadgeState.changes.removeListener(_onBadgeStateChanged);
    mappingQueue?.removeListener(_enqueueMissingMappings);
    super.dispose();
  }
}
