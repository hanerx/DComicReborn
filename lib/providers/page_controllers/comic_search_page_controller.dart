import 'package:dcomic/providers/base_provider.dart';
import 'package:dcomic/providers/models/comic_source_model.dart';

class ComicSearchPageData extends Object {
  List<ListItemEntity> data = [];
  int page = 0;
  bool hasError = false;
  int generation = 0;
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

  Future<void> refreshAll() async {
    final query = keyword;
    for (var source in sourceModels) {
      if (_disposed || keyword != query) return;
      await refresh(source);
    }
  }

  Future<void> refresh(BaseComicSourceModel sourceModel) =>
      _request(sourceModel, append: false);

  Future<void> load(BaseComicSourceModel sourceModel) =>
      _request(sourceModel, append: true);

  Future<void> _request(BaseComicSourceModel sourceModel,
      {required bool append}) async {
    if (_disposed) return;
    final state = data[sourceModel]!;
    final generation = ++state.generation;
    final query = keyword;
    final nextPage = append ? state.page + 1 : 0;
    if (!append) {
      state.data = [];
      state.page = 0;
    }
    state.hasError = false;
    notifyListeners();
    try {
      final results = query.isEmpty
          ? <ComicListItemEntity>[]
          : await sourceModel.searchComicDetail(query, page: nextPage);
      if (_disposed || generation != state.generation || keyword != query) {
        return;
      }
      state.data = append ? [...state.data, ...results] : results;
      state.page = nextPage;
    } catch (error, stack) {
      if (_disposed || generation != state.generation || keyword != query) {
        return;
      }
      state.hasError = true;
      logger.e('$error', error: error, stackTrace: stack);
    }
    notifyListeners();
  }

  set pendingKeyword(String value) {
    _pendingKeyword = value;
  }

  Future<void> search() async {
    keyword = _pendingKeyword;
    await refreshAll();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
