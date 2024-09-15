import 'package:dcomic/database/database_instance.dart';
import 'package:dcomic/database/entity/config.dart';
import 'package:dcomic/providers/base_provider.dart';
import 'package:dcomic/providers/models/comic_source_model.dart';
import 'package:dcomic/providers/models/copymanga/copymanga_source_model.dart';
import 'package:dcomic/providers/models/dmzj/dmzj_source_model.dart';
import 'package:dcomic/providers/models/zaimanhua/zaimanhua_source_model.dart';

class ComicSourceProvider extends BaseProvider {
  List<BaseComicSourceModel> sources = [DMZJComicSourceModel(),CopyMangaComicSourceModel(),ZaiManHuaSourceModel()];
  ConfigEntity? _activeHomeModelIndexEntity;

  @override
  Future<void> init() async {
    final database = await DatabaseInstance.instance;
    _activeHomeModelIndexEntity = await database.configDao
        .getOrCreateConfigByKey('activeHomeModelIndex', value: 0);
    activeHomeModelIndex = _activeHomeModelIndexEntity?.get<int>();
    for (var sourceModel in sources) {
      logger.i('init source model: ${sourceModel.type}');
      sourceModel.init();
    }
    notifyListeners();
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
      if(_activeHomeModelIndexEntity!=null){
        _activeHomeModelIndexEntity!.set(index);
        DatabaseInstance.instance.then((value) => value.configDao.updateConfig(_activeHomeModelIndexEntity!));
      }
      notifyListeners();
    }
  }

  BaseComicSourceModel get activeHomeModel =>
      _activeHomeModel == null ? sources.first : _activeHomeModel!;

  set activeHomeModel(BaseComicSourceModel baseComicSourceModel) {
    if (hasHomepageSources.contains(baseComicSourceModel)) {
      _activeHomeModel = baseComicSourceModel;
      _activeHomeModelIndex = hasHomepageSources.indexOf(baseComicSourceModel);
      if(_activeHomeModelIndexEntity!=null){
        _activeHomeModelIndexEntity!.set(_activeHomeModelIndex);
        DatabaseInstance.instance.then((value) => value.configDao.updateConfig(_activeHomeModelIndexEntity!));
      }
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
