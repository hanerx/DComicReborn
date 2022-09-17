import 'package:dcomic/providers/base_provider.dart';
import 'package:dcomic/providers/models/comic_source_model.dart';
import 'package:dcomic/providers/source_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class ComicCategoryPageController extends BaseProvider{
  List<GridItemEntity> categories=[];

  Future<void> refresh(BuildContext context)async{
    var homepageModel=Provider.of<ComicSourceProvider>(context,listen: false).activeHomeModel.homepage!;
    categories=await homepageModel.getCategoryList();
    notifyListeners();
  }
}