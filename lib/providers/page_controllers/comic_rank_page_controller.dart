import 'package:dcomic/providers/base_provider.dart';
import 'package:dcomic/providers/models/comic_source_model.dart';
import 'package:dcomic/providers/source_provider.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';

class ComicRankPageController extends BaseProvider {
  List<ListItemEntity> rankingList = [];
  int _page = 0;
  bool _canLoad=true;

  bool get canLoad=>_canLoad;

  Future<void> refresh(BuildContext context) async {
    _page = 0;
    var homepageModel = Provider.of<ComicSourceProvider>(context, listen: false)
        .activeHomeModel
        .homepage!;
    rankingList = await homepageModel.getRankingList(page: _page);
    _canLoad=true;
    notifyListeners();
  }

  Future<void> load(BuildContext context) async {
    _page++;
    var homepageModel = Provider.of<ComicSourceProvider>(context, listen: false)
        .activeHomeModel
        .homepage!;
    var result=await homepageModel.getRankingList(page: _page);
    rankingList += result;
    _canLoad=result.isNotEmpty;
    notifyListeners();
  }
}
