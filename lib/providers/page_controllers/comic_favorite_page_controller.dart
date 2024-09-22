import 'package:dcomic/providers/base_provider.dart';
import 'package:dcomic/providers/models/comic_source_model.dart';

class ComicFavoritePageController extends BaseProvider{
  BaseComicSourceModel sourceModel;
  int _page=0;
  List<GridItemEntity> data=[];

  ComicFavoritePageController(this.sourceModel);

  Future<void> refresh()async{
    _page=0;
    data=await sourceModel.accountModel!.getSubscribeStateComics(page:_page);
    notifyListeners();
  }

  Future<void> load()async{
    _page++;
    data+=await sourceModel.accountModel!.getSubscribeStateComics(page:_page);
    notifyListeners();
  }
}