import 'package:dcomic/providers/base_provider.dart';
import 'package:dcomic/providers/models/comic_source_model.dart';

class ComicSearchDialogController extends BaseProvider {
  String _pendingKeyword = "";
  String keyword = "";
  BaseComicSourceModel sourceModel;
  List<ComicListItemEntity> data = [];
  int page = 0;

  ComicSearchDialogController(this.sourceModel, this.keyword);

  Future<void> search() async {
    keyword = _pendingKeyword;
    await refresh();
  }

  Future<void> refresh() async {
    page = 0;
    data = await sourceModel.searchComicDetail(keyword, page: page);
    notifyListeners();
  }

  Future<void> load() async {
    page++;
    data += await sourceModel.searchComicDetail(keyword, page: page);
    notifyListeners();
  }

  set pendingKeyword(String value){
    _pendingKeyword = value;
    notifyListeners();
  }
}
