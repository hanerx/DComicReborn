import 'package:dcomic/providers/base_provider.dart';
import 'package:dcomic/providers/models/comic_source_model.dart';

class ComicSearchPageData {
  // PageStorage must not retain the result list when a search is replaced.
  final Object scrollIdentity = Object();
  List<ListItemEntity> data = [];
  int page = 0;
  bool hasError = false;
  int generation = 0;
  bool isLoading = false;
  bool hasMore = false;
  bool hasSearched = false;
  bool failedToLoadMore = false;
  Future<void>? _request;
}

class ComicSearchPageController extends BaseProvider {
  String _pendingKeyword = "";
  String keyword = "";
  List<BaseComicSourceModel> sourceModels;
  Map<BaseComicSourceModel, ComicSearchPageData> data = {};
  bool _disposed = false;

  ComicSearchPageController(this.sourceModels) {
    for (var sourceModel in sourceModels) {
      data[sourceModel] = ComicSearchPageData();
    }
  }

  Future<void> refreshAll() => Future.wait(sourceModels.map(refresh));

  Future<void> refresh(BaseComicSourceModel sourceModel) =>
      _request(sourceModel, append: false);

  Future<void> load(BaseComicSourceModel sourceModel) =>
      _request(sourceModel, append: true);

  Future<void> _request(
    BaseComicSourceModel sourceModel, {
    required bool append,
  }) {
    if (_disposed || keyword.isEmpty) return Future.value();
    final state = data[sourceModel];
    if (state == null) return Future.value();
    if (state.isLoading) return state._request ?? Future.value();
    if (append && (!state.hasSearched || !state.hasMore || state.hasError)) {
      // Only a failed append may retry the next page. A failed refresh must
      // retry page zero, not silently continue an outdated result set.
      if (!state.failedToLoadMore) return Future.value();
    }
    final generation = ++state.generation;
    final query = keyword;
    final nextPage = append ? state.page + 1 : 0;
    state.isLoading = true;
    state.hasError = false;
    state.failedToLoadMore = false;
    final request = _performRequest(
      sourceModel,
      state,
      generation,
      query,
      nextPage,
      append,
    );
    state._request = request;
    notifyListeners();
    return request;
  }

  Future<void> _performRequest(
    BaseComicSourceModel sourceModel,
    ComicSearchPageData state,
    int generation,
    String query,
    int nextPage,
    bool append,
  ) async {
    try {
      final results = await sourceModel.searchComicDetail(
        query,
        page: nextPage,
      );
      if (_disposed || generation != state.generation || keyword != query) {
        return;
      }
      state.data = append ? [...state.data, ...results] : results;
      state.page = nextPage;
      state.hasMore = results.isNotEmpty;
    } catch (error, stack) {
      if (_disposed || generation != state.generation || keyword != query) {
        return;
      }
      state.hasError = true;
      state.failedToLoadMore = append;
      logger.e('$error', error: error, stackTrace: stack);
    } finally {
      if (!_disposed && generation == state.generation && keyword == query) {
        state.isLoading = false;
        state.hasSearched = true;
        state._request = null;
        notifyListeners();
      }
    }
  }

  set pendingKeyword(String value) {
    _pendingKeyword = value;
  }

  Future<void> search() async {
    if (_disposed) return;
    final query = _pendingKeyword.trim();
    if (query.isEmpty) {
      clear();
      return;
    }
    if (query == keyword) return;
    _resetResults();
    keyword = query;
    await refreshAll();
  }

  void clear() {
    if (_disposed) return;
    keyword = '';
    _pendingKeyword = '';
    _resetResults();
    notifyListeners();
  }

  void _resetResults() {
    for (final source in sourceModels) {
      // Invalidate old state as well as replacing it, including A → B → A.
      data[source]!.generation++;
      data[source] = ComicSearchPageData();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
