import 'package:dcomic/providers/base_provider.dart';
import 'package:dcomic/providers/models/comic_source_model.dart';

class ComicSearchDialogController extends BaseProvider {
  String _pendingKeyword;
  String keyword;
  BaseComicSourceModel sourceModel;
  List<ComicListItemEntity> data = [];
  int page = 0;
  bool hasError = false;
  int _generation = 0;
  bool _disposed = false;

  ComicSearchDialogController(this.sourceModel, this.keyword)
      : _pendingKeyword = keyword;

  Future<void> search() async {
    keyword = _pendingKeyword;
    await refresh();
  }

  Future<void> refresh() => _request(append: false);

  Future<void> load() => _request(append: true);

  Future<void> _request({required bool append}) async {
    if (_disposed) return;
    final generation = ++_generation;
    final query = keyword;
    final nextPage = append ? page + 1 : 0;
    if (!append) {
      data = [];
      page = 0;
    }
    hasError = false;
    notifyListeners();
    try {
      final results = query.isEmpty
          ? <ComicListItemEntity>[]
          : await sourceModel.searchComicDetail(query, page: nextPage);
      if (_disposed || generation != _generation) return;
      data = append ? [...data, ...results] : results;
      page = nextPage;
    } catch (error, stack) {
      if (_disposed || generation != _generation) return;
      hasError = true;
      logger.e('$error', error: error, stackTrace: stack);
    }
    notifyListeners();
  }

  set pendingKeyword(String value) {
    _pendingKeyword = value;
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    super.dispose();
  }
}
