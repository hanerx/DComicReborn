import 'dart:async';

import 'package:dcomic/providers/base_provider.dart';
import 'package:dcomic/providers/models/comic_source_model.dart';
import 'package:dcomic/providers/subscribe_badge_state.dart';

class ComicFavoritePageController extends BaseProvider {
  BaseComicSourceModel sourceModel;
  int _page = 0;
  List<GridItemEntity> data = [];
  bool _disposed = false;

  ComicFavoritePageController(this.sourceModel) {
    SubscribeBadgeState.changes.addListener(_onBadgeStateChanged);
  }

  Future<void> _badgeRefresh = Future.value();

  void _onBadgeStateChanged() {
    unawaited(
      refreshBadges().catchError((Object error, StackTrace stack) {
        logger.e(
          'Failed to refresh subscription badges',
          error: error,
          stackTrace: stack,
        );
      }),
    );
  }

  Future<void> refresh() async {
    _page = 0;
    data = await sourceModel.accountModel!.getSubscribeStateComics(page: _page);
    notifyListeners();
  }

  Future<void> load() async {
    _page++;
    data += await sourceModel.accountModel!.getSubscribeStateComics(
      page: _page,
    );
    notifyListeners();
  }

  Future<void> refreshBadges() {
    // Serialize local reconciliation so a previous setting/read snapshot cannot
    // overwrite a newer one. Refresh all loaded items, including mapped books.
    final refresh = _badgeRefresh.then((_) async {
      if (_disposed || data.isEmpty) return;
      final changed = await sourceModel.accountModel!.refreshSubscribeBadges(
        data,
      );
      if (!_disposed && changed) notifyListeners();
    });
    _badgeRefresh = refresh.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return refresh;
  }

  @override
  void dispose() {
    _disposed = true;
    SubscribeBadgeState.changes.removeListener(_onBadgeStateChanged);
    super.dispose();
  }
}
