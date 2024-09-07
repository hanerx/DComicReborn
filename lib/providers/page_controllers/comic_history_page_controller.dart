import 'package:dcomic/database/entity/comic_history.dart';
import 'package:dcomic/providers/base_provider.dart';
import 'package:dcomic/providers/models/comic_source_model.dart';

class ComicHistoryPageData extends Object{
  Map<ComicHistorySourceType, List<ListItemEntity>> data = {};
  int page = 0;

  ComicHistoryPageData(){
    for(var sourceType in ComicHistorySourceType.values){
      data[sourceType] = [];
    }
  }
}

class ComicHistoryPageController extends BaseProvider {
  List<BaseComicSourceModel> sourceModels;
  Map<BaseComicSourceModel, ComicHistoryPageData> data = {};
  ComicHistorySourceType sourceType = ComicHistorySourceType.local;

  ComicHistoryPageController(this.sourceModels){
    for(var sourceModel in sourceModels){
      data[sourceModel] = ComicHistoryPageData();
    }
  }

  Future<void> refreshAll() async{
    for(var source in sourceModels){
      await refresh(source);
    }
  }

  Future<void> refresh(BaseComicSourceModel sourceModel)async{
    data[sourceModel]?.page=0;
    data[sourceModel]?.data[sourceType]=await sourceModel.getComicHistory(sourceType);
    notifyListeners();
  }

  Future<void> load(BaseComicSourceModel sourceModel)async{
    data[sourceModel]?.page++;
    var dataList = data[sourceModel]?.data[sourceType];
    if(dataList!=null){
      dataList += await sourceModel.getComicHistory(sourceType, page: data[sourceModel]!.page);
    }
    notifyListeners();
  }

  Future<void> addSourceType() async{
    var index = ComicHistorySourceType.values.indexOf(sourceType);
    index += 1;
    if(index>=ComicHistorySourceType.values.length){
      index = 0;
    }
    sourceType = ComicHistorySourceType.values[index];
    await refreshAll();
    notifyListeners();
  }

}