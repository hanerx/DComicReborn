import 'package:date_format/date_format.dart';
import 'package:dcomic/providers/base_provider.dart';
import 'package:dcomic/providers/models/comic_source_model.dart';
import 'package:dcomic/providers/source_provider.dart';
import 'package:dcomic/utils/image_utils.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';

class ComicDetailPageController extends BaseProvider {
  bool _isLoading = true;
  BaseComicDetailModel? detailModel;
  BaseComicSourceModel? comicSourceModel;

  bool _nest=true;
  bool _reverse=true;

  bool get isLoading => _isLoading;

  ComicDetailPageController(this.comicSourceModel);

  Future<void> refresh(
      BuildContext context, String comicId, String title) async {
    // 处理sourceModel问题
    if (comicSourceModel == null) {
      comicSourceModel =
          Provider.of<ComicSourceProvider>(context, listen: false).activeModel;
    } else {
      Provider.of<ComicSourceProvider>(context, listen: false).activeModel =
          comicSourceModel!;
    }
    detailModel = await comicSourceModel?.getComicDetail(comicId, title);
    await detailModel?.init();
    _isLoading = false;
    notifyListeners();
  }

  String get title => detailModel == null ? "" : detailModel!.title;

  ImageEntity get cover => detailModel == null
      ? ImageEntity(ImageType.unknown, "")
      : detailModel!.cover;

  String get description => detailModel == null ? "" : detailModel!.description;

  String get status => detailModel == null ? "" : detailModel!.status;

  String get lastUpdate => detailModel == null
      ? "1970-1-1"
      : formatDate(detailModel!.lastUpdate, [yyyy, '-', mm, '-', dd]);

  String get comicId => detailModel == null ? "" : detailModel!.comicId;

  List<CategoryEntity> get authors =>
      detailModel == null ? [] : detailModel!.authors;

  List<CategoryEntity> get categories =>
      detailModel == null ? [] : detailModel!.categories;

  Map<String, List<BaseComicChapterEntityModel>> get chapters=>detailModel==null?{}:detailModel!.chapters;

  bool get subscribe => detailModel==null?false:detailModel!.subscribe;

  set subscribe(bool subscribe){
    if(detailModel!=null){
      detailModel!.subscribe=subscribe;
      notifyListeners();
    }
  }

  bool get reverse => _reverse;

  set reverse(bool value) {
    _reverse = value;
    notifyListeners();
  }

  bool get nest => _nest;

  set nest(bool value) {
    _nest = value;
    notifyListeners();
  }
}
