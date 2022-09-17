import 'package:dcomic/providers/models/comic_source_model.dart';
import 'package:dcomic/providers/page_controllers/comic_viewer_page_controller.dart';
import 'package:dcomic/utils/image_utils.dart';
import 'package:dcomic/view/components/dcomic_image.dart';
import 'package:easy_refresh/easy_refresh.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:provider/provider.dart';

class ComicViewerPage extends StatefulWidget {
  final BaseComicDetailModel detailModel;
  final List<BaseComicChapterEntityModel> chapters;
  final String chapterId;

  const ComicViewerPage(
      {super.key,
      required this.detailModel,
      required this.chapterId,
      required this.chapters});

  @override
  State<StatefulWidget> createState() => _ComicViewerPageState();
}

class _ComicViewerPageState extends State<ComicViewerPage> {
  final PageController _pageController = PageController();

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<ComicViewerPageController>(
      create: (_) => ComicViewerPageController(
          widget.detailModel, widget.chapters, widget.chapterId),
      builder: (context, child) => Scaffold(
          body: EasyRefresh(
        noMoreRefresh:
            Provider.of<ComicViewerPageController>(context).preChapter == null,
        noMoreLoad:
            Provider.of<ComicViewerPageController>(context).nextChapter == null,
        header: BezierHeader(
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Theme.of(context).colorScheme.onPrimary,
            showBalls: true,
            spinWidget: SpinKitDualRing(
              size: 32,
              color: Theme.of(context).colorScheme.onPrimary,
            )),
        footer: BezierFooter(
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Theme.of(context).colorScheme.onPrimary,
            showBalls: true,
            spinWidget: SpinKitDualRing(
              size: 32,
              color: Theme.of(context).colorScheme.onPrimary,
            )),
        refreshOnStart: true,
        onRefresh: () async {
          await Provider.of<ComicViewerPageController>(context, listen: false)
              .refresh();
          _pageController.jumpToPage(0);
        },
        onLoad: () async {
          await Provider.of<ComicViewerPageController>(context, listen: false)
              .load();
          _pageController.jumpToPage(0);
        },
        child: _buildHorizontalViewer(context),
      )),
    );
  }

  Widget _buildHorizontalViewer(BuildContext context) {
    return PhotoViewGallery.builder(
      pageController: _pageController,
      itemCount:
          Provider.of<ComicViewerPageController>(context).chapterDetailModel !=
                  null
              ? Provider.of<ComicViewerPageController>(context)
                  .chapterDetailModel!
                  .pages
                  .length
              : 0,
      builder: (context, index) => PhotoViewGalleryPageOptions.customChild(
          initialScale: PhotoViewComputedScale.contained,
          minScale: PhotoViewComputedScale.contained,
          maxScale: PhotoViewComputedScale.covered * 4.1,
          child: DComicImage(Provider.of<ComicViewerPageController>(context)
              .chapterDetailModel!
              .pages[index])),
    );
  }
}
