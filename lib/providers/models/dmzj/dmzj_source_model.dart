import 'package:dcomic/database/entity/comic_history.dart';
import 'package:dcomic/providers/models/comic_source_model.dart';

class DMZJComicSourceModel extends BaseComicSourceModel{

  @override
  ComicSourceEntity get type => ComicSourceEntity("大妈之家", "dmzj",hasHomepage: true);

  @override
  Future<BaseComicDetailModel?> getComicDetail(String comicId) {
    // TODO: implement getComicDetail
    throw UnimplementedError();
  }

  @override
  Future<List<ComicHistoryEntity>> getComicHistory() {
    // TODO: implement getComicHistory
    throw UnimplementedError();
  }

  @override
  Future<List<BaseComicDetailModel>> searchComicDetail(String keyword, {int page = 0}) {
    // TODO: implement searchComicDetail
    throw UnimplementedError();
  }

}