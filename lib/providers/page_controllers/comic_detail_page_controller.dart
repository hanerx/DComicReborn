import 'package:dcomic/providers/base_provider.dart';
import 'package:dcomic/providers/models/comic_source_model.dart';
import 'package:dcomic/providers/source_provider.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';

class ComicDetailPageController extends BaseProvider {
  bool _isLoading = true;
  BaseComicDetailModel? detailModel;
  BaseComicSourceModel? comicSourceModel;

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
    _isLoading = false;
    notifyListeners();
  }
}
