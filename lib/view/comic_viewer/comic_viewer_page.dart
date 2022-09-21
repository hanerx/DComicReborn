import 'dart:math';

import 'package:dcomic/providers/comic_veiwer_config_provider.dart';
import 'package:dcomic/providers/models/comic_source_model.dart';
import 'package:dcomic/providers/page_controllers/comic_viewer_page_controller.dart';
import 'package:dcomic/view/components/dcomic_image.dart';
import 'package:dcomic/view/components/expand_card_button.dart';
import 'package:easy_refresh/easy_refresh.dart';
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
  final EasyRefreshController _easyRefreshController = EasyRefreshController();

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<ComicViewerPageController>(
      create: (_) => ComicViewerPageController(
          widget.detailModel, widget.chapters, widget.chapterId),
      builder: (context, child) => Scaffold(
          endDrawer: _buildDrawer(context),
          body: Container(
            color: Colors.black,
            child: EasyRefresh(
              controller: _easyRefreshController,
              // noMoreRefresh:
              //     Provider.of<ComicViewerPageController>(context).preChapter == null,
              // noMoreLoad:
              //     Provider.of<ComicViewerPageController>(context).nextChapter == null,
              header: BezierHeader(
                  triggerOffset: 50,
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  showBalls: true,
                  spinWidget: SpinKitDualRing(
                    size: 32,
                    color: Theme.of(context).colorScheme.onPrimary,
                  )),
              footer: BezierFooter(
                  triggerOffset: 50,
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  showBalls: true,
                  spinWidget: SpinKitDualRing(
                    size: 32,
                    color: Theme.of(context).colorScheme.onPrimary,
                  )),
              refreshOnStart: true,
              onRefresh: () async {
                await Provider.of<ComicViewerPageController>(context,
                        listen: false)
                    .refresh();
                _pageController.animateToPage(0,
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeIn);
              },
              onLoad: () async {
                await Provider.of<ComicViewerPageController>(context,
                        listen: false)
                    .load();
                _pageController.animateToPage(0,
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeIn);
              },
              child: Stack(
                children: [
                  _buildHorizontalViewer(context),
                  _buildPrePageButton(context),
                  _buildShowButton(context),
                  _buildNextPageButton(context),
                  _buildAppBar(context),
                  _buildToolBar(context)
                ],
              ),
            ),
          )),
    );
  }

  Widget _buildHorizontalViewer(BuildContext context) {
    return PhotoViewGallery.builder(
      onPageChanged: (index) {
        Provider.of<ComicViewerPageController>(context, listen: false)
            .currentPage = index;
      },
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

  Widget _buildSlider(BuildContext context) {
    return SliderTheme(
        data: const SliderThemeData(
          thumbShape: RoundSliderThumbShape(enabledThumbRadius: 8),
          overlayShape: RoundSliderOverlayShape(overlayRadius: 15.0),
        ),
        child: Slider(
          value: Provider.of<ComicViewerPageController>(context)
              .currentPage
              .toDouble(),
          divisions: Provider.of<ComicViewerPageController>(context)
                      .chapterDetailModel ==
                  null
              ? null
              : Provider.of<ComicViewerPageController>(context)
                      .chapterDetailModel!
                      .pages
                      .length -
                  1,
          min: 0,
          max: Provider.of<ComicViewerPageController>(context)
                      .chapterDetailModel ==
                  null
              ? 1
              : Provider.of<ComicViewerPageController>(context)
                      .chapterDetailModel!
                      .pages
                      .length
                      .toDouble() -
                  1,
          onChanged: (double value) {
            _pageController.jumpToPage(value.toInt());
            Provider.of<ComicViewerPageController>(context, listen: false)
                .currentPage = value.toInt();
          },
        ));
  }

  Widget _buildPrePageButton(BuildContext context) {
    return Positioned(
        left: 0,
        top: 0,
        bottom: 0,
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () {
            if (_pageController.position.pixels !=
                _pageController.position.minScrollExtent) {
              _pageController.previousPage(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeIn);
            } else {
              _easyRefreshController.callRefresh();
            }
          },
          child: SizedBox(
            width: 80,
            child:
                Provider.of<ComicViewerConfigProvider>(context).drawDebugWidget
                    ? Container(
                        color: Color.lerp(Theme.of(context).colorScheme.primary,
                            Colors.transparent, 0.5),
                      )
                    : null,
          ),
        ));
  }

  Widget _buildNextPageButton(BuildContext context) {
    return Positioned(
        right: 0,
        top: 0,
        bottom: 0,
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () {
            if (_pageController.position.pixels !=
                _pageController.position.maxScrollExtent) {
              _pageController.nextPage(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeIn);
            } else {
              _easyRefreshController.callLoad();
            }
          },
          child: SizedBox(
            width: 80,
            child:
                Provider.of<ComicViewerConfigProvider>(context).drawDebugWidget
                    ? Container(
                        color: Color.lerp(Theme.of(context).colorScheme.primary,
                            Colors.transparent, 0.5),
                      )
                    : null,
          ),
        ));
  }

  Widget _buildShowButton(BuildContext context) {
    return Positioned(
        right: 80,
        left: 80,
        top: 0,
        bottom: 0,
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () {
            Provider.of<ComicViewerPageController>(context, listen: false)
                    .showToolBar =
                !Provider.of<ComicViewerPageController>(context, listen: false)
                    .showToolBar;
          },
          child: SizedBox(
            width: 80,
            child:
                Provider.of<ComicViewerConfigProvider>(context).drawDebugWidget
                    ? Container(
                        color: Color.lerp(
                            Theme.of(context).colorScheme.tertiary,
                            Colors.transparent,
                            0.5),
                      )
                    : null,
          ),
        ));
  }

  Widget _buildToolBar(BuildContext context) {
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 300),
      left: 0,
      right: 0,
      bottom:
          Provider.of<ComicViewerPageController>(context).showToolBar ? 0 : -90,
      child: SizedBox(
        height: 90,
        child: Card(
            child: Column(
          children: [
            _buildSlider(context),
            Expanded(
                child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ExpandCardButton(
                    onTap: () {
                      _easyRefreshController.callRefresh();
                    },
                    icon: Icons.keyboard_double_arrow_left),
                Builder(
                  builder: (context) => ExpandCardButton(
                      onTap: () {
                        Provider.of<ComicViewerPageController>(context,
                                listen: false)
                            .endDrawerPage = 0;
                        Scaffold.of(context).openEndDrawer();
                      },
                      icon: Icons.message_outlined),
                ),
                Builder(
                    builder: (context) => ExpandCardButton(
                        onTap: () {
                          Provider.of<ComicViewerPageController>(context,
                                  listen: false)
                              .endDrawerPage = 1;
                          Scaffold.of(context).openEndDrawer();
                        },
                        icon: Icons.list_alt)),
                ExpandCardButton(
                    onTap: () {
                      showModalBottomSheet(
                          backgroundColor: Colors.transparent,
                          context: context,
                          builder: (context) => SizedBox(
                                height: 300,
                                child: Card(),
                              ));
                    },
                    icon: Icons.settings),
                ExpandCardButton(
                    onTap: () {
                      _easyRefreshController.callLoad();
                    },
                    icon: Icons.keyboard_double_arrow_right)
              ],
            ))
          ],
        )),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 300),
      left: 0,
      right: 0,
      top: Provider.of<ComicViewerPageController>(context).showToolBar
          ? 0
          : -100,
      child: SafeArea(
        child: SizedBox(
          height: 70,
          child: Card(
              child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              BackButton(
                color: Theme.of(context).colorScheme.primary,
              ),
              Expanded(
                  child: Padding(
                padding: const EdgeInsets.only(left: 10),
                child: Text(
                  Provider.of<ComicViewerPageController>(context).title,
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary),
                ),
              ))
            ],
          )),
        ),
      ),
    );
  }

  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      width: MediaQuery.of(context).size.width * 0.9,
      backgroundColor: Colors.transparent,
      child: SafeArea(
        child: Card(
          child: SizedBox.expand(
            child: DefaultTabController(
              initialIndex:
                  Provider.of<ComicViewerPageController>(context).endDrawerPage,
              length: 2,
              child: Column(
                children: [
                  TabBar(
                    tabs: [
                      Tab(
                        child: Row(
                          children: [
                            Icon(Icons.message_outlined),
                            Expanded(
                                child:
                                    Text("test", textAlign: TextAlign.center))
                          ],
                        ),
                      ),
                      Tab(
                          child: Row(
                        children: [
                          Icon(Icons.list_alt),
                          Expanded(
                              child: Text("test", textAlign: TextAlign.center))
                        ],
                      ))
                    ],
                    labelColor: Theme.of(context).colorScheme.primary,
                    indicatorColor: Theme.of(context).colorScheme.primary,
                  ),
                  Expanded(
                      child: TabBarView(
                    children: [
                      SizedBox.expand(
                        child: Wrap(
                          children: [
                            for (int i = 0; i < 10; i++)
                              Padding(
                                  padding: const EdgeInsets.only(left: 5),
                                  child: ActionChip(
                                    onPressed: (){},
                                    label: Text(" $i"),
                                    backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                                      visualDensity: const VisualDensity(vertical: -1)
                                  ),
                              )
                          ],
                        ),
                      ),
                      SizedBox.expand()
                    ],
                  ))
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
