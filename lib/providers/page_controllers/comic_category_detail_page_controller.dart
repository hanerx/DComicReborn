import 'package:dcomic/providers/base_provider.dart';
import 'package:dcomic/providers/models/comic_source_model.dart';

class ComicCategoryDetailPageController extends BaseProvider {
  final BaseComicSourceModel sourceModel;
  final String categoryId;
  final int categoryType;
  late final BaseComicHomepageModel homepageModel = sourceModel.homepage!;
  final Map<String, dynamic> _filter = {};

  int _page = 0;
  List<ListItemEntity> _data = [];

  Map<String, dynamic> get filter => _filter;

  List<ListItemEntity> get data => _data;

  void setFilterValue(String filterName, dynamic filterValue) {
    _filter[filterName] = filterValue;
    notifyListeners();
  }

  ComicCategoryDetailPageController(this.sourceModel, this.categoryId,
      {this.categoryType = 0}) {
    for (var item in homepageModel.categoryFilter) {
      _filter[item.filterName] = item.initValue;
    }
  }

  Future<void> refresh() async {
    _page = 0;
    _data = await homepageModel.getCategoryDetailList(
        categoryId: categoryId, categoryFilter: _filter, page: _page, categoryType: categoryType);
    notifyListeners();
  }

  Future<void> load() async {
    _page++;
    _data += await homepageModel.getCategoryDetailList(
        categoryId: categoryId, categoryFilter: _filter, page: _page, categoryType: categoryType);
    notifyListeners();
  }
}
