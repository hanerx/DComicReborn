import 'package:dcomic/providers/base_provider.dart';
import 'package:dcomic/providers/models/comic_source_model.dart';
import 'package:dcomic/providers/models/dmzj/dmzj_source_model.dart';

class ComicSourceProvider extends BaseProvider {
  List<BaseComicSourceModel> sources = [
    DMZJComicSourceModel()
  ];

  BaseComicSourceModel? _activeHomeModel;
  int? _activeHomeModelIndex;

  List<BaseComicSourceModel> get hasHomepageSources {
    List<BaseComicSourceModel> result = [];
    for (var element in sources) {
      if (element.type.hasHomepage) {
        result.add(element);
      }
    }
    return result;
  }

  int get activeHomeModelIndex =>
      _activeHomeModelIndex == null ? 0 : _activeHomeModelIndex!;

  set activeHomeModelIndex(int index) {
    if (-1 < index && index < hasHomepageSources.length) {
      _activeHomeModel = hasHomepageSources[index];
      _activeHomeModelIndex = index;
      notifyListeners();
    }
  }

  BaseComicSourceModel get activeHomeModel =>
      _activeHomeModel == null ? sources.first : _activeHomeModel!;

  set activeHomeModel(BaseComicSourceModel baseComicSourceModel) {
    if (hasHomepageSources.contains(baseComicSourceModel)) {
      _activeHomeModel = baseComicSourceModel;
      _activeHomeModelIndex = hasHomepageSources.indexOf(baseComicSourceModel);
      notifyListeners();
    }
  }
}
