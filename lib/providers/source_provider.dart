import 'package:dcomic/providers/base_provider.dart';
import 'package:dcomic/providers/models/comic_source_model.dart';
import 'package:dcomic/providers/models/dmzj/dmzj_source_model.dart';

class ComicSourceProvider extends BaseProvider {
  List<BaseComicSourceModel> sources = [DMZJComicSourceModel()];

  @override
  Future<void> init() async {
    for (var sourceModel in sources) {
      logger.i('init source model: ${sourceModel.type}');
      sourceModel.init();
    }
  }

  void callNotify(){
    notifyListeners();
  }

  BaseComicSourceModel? _activeHomeModel;
  int? _activeHomeModelIndex;

  BaseComicSourceModel? _activeModel;
  int? _activeModelIndex;

  List<BaseComicSourceModel> get hasHomepageSources {
    List<BaseComicSourceModel> result = [];
    for (var element in sources) {
      if (element.type.hasHomepage) {
        result.add(element);
      }
    }
    return result;
  }

  List<BaseComicSourceModel> get hasAccountSettingSources {
    List<BaseComicSourceModel> result = [];
    for (var element in sources) {
      if (element.type.hasAccountSupport) {
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

  int get activeModelIndex =>
      _activeModelIndex == null ? 0 : _activeModelIndex!;

  set activeModelIndex(int index) {
    if (-1 < index && index < sources.length) {
      _activeModel = sources[index];
      _activeModelIndex = index;
      notifyListeners();
    }
  }

  BaseComicSourceModel get activeModel =>
      _activeModel == null ? sources.first : _activeModel!;

  set activeModel(BaseComicSourceModel baseComicSourceModel) {
    if (sources.contains(baseComicSourceModel)) {
      _activeModel = baseComicSourceModel;
      _activeModelIndex = sources.indexOf(baseComicSourceModel);
      notifyListeners();
    }
  }
}
