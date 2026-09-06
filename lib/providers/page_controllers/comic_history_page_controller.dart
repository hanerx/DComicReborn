import 'package:dcomic/providers/base_provider.dart';
import 'package:dcomic/providers/models/comic_source_model.dart';

class ComicHistoryPageData extends Object {
  Map<ComicHistorySourceType, List<ListItemEntity>> data = {};
  int page = 0;

  ComicHistoryPageData() {
    for (var sourceType in ComicHistorySourceType.values) {
      data[sourceType] = [];
    }
  }
}

class ComicHistoryPageController extends BaseProvider {
  List<BaseComicSourceModel> sourceModels;
  Map<BaseComicSourceModel, ComicHistoryPageData> data = {};
  ComicHistorySourceType sourceType = ComicHistorySourceType.local;

  ComicHistoryPageController(this.sourceModels) {
    for (var sourceModel in sourceModels) {
      data[sourceModel] = ComicHistoryPageData();
    }
  }

  Future<void> refreshAll() async {
    Object? failure;
    for (final source in sourceModels) {
      try {
        await refresh(source);
      } catch (error) {
        failure = error;
      }
    }
    if (failure != null) throw failure;
  }

  Future<void> refresh(BaseComicSourceModel sourceModel) async {
    final type = sourceType;
    final records = await sourceModel.getComicHistory(type);
    if (sourceType != type) return;
    data[sourceModel]?.page = 0;
    data[sourceModel]?.data[type] = records;
    notifyListeners();
  }

  Future<void> load(BaseComicSourceModel sourceModel) async {
    final type = sourceType;
    final state = data[sourceModel];
    if (state == null) return;
    final nextPage = state.page + 1;
    final records = await sourceModel.getComicHistory(type, page: nextPage);
    if (sourceType != type) return;
    state.data[type]?.addAll(records);
    state.page = nextPage;
    notifyListeners();
  }

  Future<void> addSourceType() async {
    var index = ComicHistorySourceType.values.indexOf(sourceType);
    index += 1;
    if (index >= ComicHistorySourceType.values.length) {
      index = 0;
    }
    sourceType = ComicHistorySourceType.values[index];
    notifyListeners();
    await refreshAll();
    notifyListeners();
  }
}
