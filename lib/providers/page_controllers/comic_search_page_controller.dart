import 'package:dcomic/providers/base_provider.dart';
import 'package:dcomic/providers/models/comic_source_model.dart';

class ComicSearchPageData extends Object{
  List<ListItemEntity> data = [];
  int page = 0;
}

class ComicSearchPageController extends BaseProvider {
  String _pendingKeyword = "";
  String keyword = "";
  List<BaseComicSourceModel> sourceModels;
  Map<BaseComicSourceModel, ComicSearchPageData> data = {};

  ComicSearchPageController(this.sourceModels){
    for(var sourceModel in sourceModels){
      data[sourceModel] = ComicSearchPageData();
    }
  }

  Future<void> refreshAll() async{
    for(var source in sourceModels){
      await refresh(source);
    }
  }

  Future<void> refresh(BaseComicSourceModel sourceModel)async{
    data[sourceModel]?.page=0;
    if(keyword.isNotEmpty){
      data[sourceModel]?.data=await sourceModel.searchComicDetail(keyword);
    }
    notifyListeners();
  }

  Future<void> load(BaseComicSourceModel sourceModel)async{
    data[sourceModel]?.page++;
    if(keyword.isNotEmpty) {
      data[sourceModel]?.data += await sourceModel.searchComicDetail(keyword, page: data[sourceModel]!.page);
    }
    notifyListeners();
  }

  set pendingKeyword(String value) {
    _pendingKeyword = value;
  }

  Future<void> search()async {
    keyword = _pendingKeyword;
    await refreshAll();
    notifyListeners();
  }
}