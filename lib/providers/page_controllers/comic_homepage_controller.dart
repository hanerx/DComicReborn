import 'package:dcomic/providers/base_provider.dart';
import 'package:dcomic/providers/models/comic_source_model.dart';
import 'package:dcomic/providers/source_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class ComicHomepageController extends BaseProvider{
  List<HomepageCardEntity> homepageCards=[];
  List<CarouselEntity> homepageCarousels=[];

  Future<void> refresh(BuildContext context)async{
    var homepageModel=Provider.of<ComicSourceProvider>(context,listen: false).activeHomeModel.homepage!;
    homepageCarousels=await homepageModel.getHomepageCarousel();
    homepageCards=await homepageModel.getHomepageCard();
    notifyListeners();
  }
}