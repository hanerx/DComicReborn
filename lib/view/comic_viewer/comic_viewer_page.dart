import 'package:dcomic/generated/l10n.dart';
import 'package:dcomic/providers/comic_veiwer_config_provider.dart';
import 'package:dcomic/providers/config_provider.dart';
import 'package:dcomic/providers/models/comic_source_model.dart';
import 'package:dcomic/providers/page_controllers/comic_viewer_page_controller.dart';
import 'package:dcomic/view/components/dcomic_image.dart';
import 'package:dcomic/view/components/empty_widget.dart';
import 'package:dcomic/view/components/expand_card_button.dart';
import 'package:dcomic/view/components/viewer_setting_list.dart';
import 'package:easy_refresh/easy_refresh.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:provider/provider.dart';
import 'package:date_format/date_format.dart' as formatdate;
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

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
  final ItemPositionsListener _itemPositionsListener =
      ItemPositionsListener.create();
  final ItemScrollController _itemScrollController = ItemScrollController();

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
                  _buildViewer(context),
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

  Widget _buildViewer(BuildContext context) {
    if (Provider.of<ConfigProvider>(context).readDirection ==
        ReadDirectionType.vertical) {
      return _buildVerticalViewer(context);
    }
    return _buildHorizontalViewer(context);
  }

  Widget _buildHorizontalViewer(BuildContext context) {
    return PhotoViewGallery.builder(
      onPageChanged: (index) {
        Provider.of<ComicViewerPageController>(context, listen: false)
            .currentPage = index;
      },
      pageController: _pageController,
      reverse: Provider.of<ConfigProvider>(context).readDirection ==
          ReadDirectionType.right,
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

  Widget _buildVerticalViewer(BuildContext context) {
    _itemPositionsListener.itemPositions.addListener(() {
      var items = _itemPositionsListener.itemPositions.value;
      if (items.isEmpty) {
        return;
      }
      var index = items
          .where((ItemPosition position) => position.itemTrailingEdge > 0)
          .reduce((ItemPosition min, ItemPosition position) =>
      position.itemTrailingEdge < min.itemTrailingEdge ? position : min)
          .index;
      Provider.of<ComicViewerPageController>(context, listen: false)
          .currentPage = index;
    });
    return ScrollablePositionedList.builder(
        itemPositionsListener: _itemPositionsListener,
        itemScrollController: _itemScrollController,
        itemCount: Provider.of<ComicViewerPageController>(context)
                    .chapterDetailModel !=
                null
            ? Provider.of<ComicViewerPageController>(context)
                .chapterDetailModel!
                .pages
                .length
            : 0,
        itemBuilder: (BuildContext context, int index) => DComicImage(
            Provider.of<ComicViewerPageController>(context)
                .chapterDetailModel!
                .pages[index]));
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
            if (Provider.of<ConfigProvider>(context, listen: false)
                    .readDirection ==
                ReadDirectionType.vertical) {
              _itemScrollController.jumpTo(index: value.toInt());
            } else {
              _pageController.jumpToPage(value.toInt());
            }
            Provider.of<ComicViewerPageController>(context, listen: false)
                .currentPage = value.toInt();
          },
        ));
  }

  Widget _buildPrePageButton(BuildContext context) {
    if (Provider.of<ConfigProvider>(context)
        .readDirection ==
        ReadDirectionType.vertical){
      return Positioned(
          left: 0,
          right: 0,
          top: 0,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () {
              if (Provider.of<ComicViewerPageController>(context, listen: false)
                  .currentPage >
                  0) {
                _itemScrollController.scrollTo(
                    index: Provider.of<ComicViewerPageController>(context,
                        listen: false)
                        .currentPage -
                        1,
                    duration: const Duration(milliseconds: 200));
              } else {
                _easyRefreshController.callRefresh();
              }
            },
            child: SizedBox(
              height: 150,
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
    return Positioned(
        left: 0,
        top: 0,
        bottom: 0,
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () {
            if(Provider.of<ConfigProvider>(context, listen: false)
                .readDirection == ReadDirectionType.right){
              if (_pageController.position.pixels !=
                  _pageController.position.maxScrollExtent) {
                _pageController.nextPage(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeIn);
              } else {
                _easyRefreshController.callLoad();
              }
            }else{
              if (_pageController.position.pixels !=
                  _pageController.position.minScrollExtent) {
                _pageController.previousPage(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeIn);
              } else {
                _easyRefreshController.callRefresh();
              }
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
    if (Provider.of<ConfigProvider>(context)
        .readDirection ==
        ReadDirectionType.vertical){
      return Positioned(
          right: 0,
          left: 0,
          bottom: 0,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () {
              if (Provider.of<ComicViewerPageController>(context, listen: false)
                  .currentPage <
                  Provider.of<ComicViewerPageController>(context, listen: false)
                      .chapterDetailModel!
                      .pages
                      .length -
                      1) {
                _itemScrollController.scrollTo(
                    index: Provider.of<ComicViewerPageController>(context,
                        listen: false)
                        .currentPage +
                        1,
                    duration: const Duration(milliseconds: 200));
              } else {
                _easyRefreshController.callLoad();
              }
            },
            child: SizedBox(
              height: 150,
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
    return Positioned(
        right: 0,
        top: 0,
        bottom: 0,
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () {
            if(Provider.of<ConfigProvider>(context, listen: false)
                .readDirection == ReadDirectionType.left){
              if (_pageController.position.pixels !=
                  _pageController.position.maxScrollExtent) {
                _pageController.nextPage(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeIn);
              } else {
                _easyRefreshController.callLoad();
              }
            }else{
              if (_pageController.position.pixels !=
                  _pageController.position.minScrollExtent) {
                _pageController.previousPage(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeIn);
              } else {
                _easyRefreshController.callRefresh();
              }
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
    if (Provider.of<ConfigProvider>(context)
        .readDirection ==
        ReadDirectionType.vertical){
      return Positioned(
          right: 0,
          left: 0,
          top: 150,
          bottom: 150,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () {
              Provider.of<ComicViewerPageController>(context, listen: false)
                  .showToolBar =
              !Provider.of<ComicViewerPageController>(context, listen: false)
                  .showToolBar;
            },
            child: SizedBox(
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
                          builder: (context) => const SizedBox(
                                height: 300,
                                child: Card(
                                  child: ViewerSettingList(),
                                ),
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
                            const Icon(Icons.message_outlined),
                            Expanded(
                                child: Text(
                                    S.of(context).ComicViewerPageComments,
                                    textAlign: TextAlign.center))
                          ],
                        ),
                      ),
                      Tab(
                          child: Row(
                        children: [
                          const Icon(Icons.list_alt),
                          Expanded(
                              child: Text(
                                  S.of(context).ComicViewerPageDirectory,
                                  textAlign: TextAlign.center))
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
                        child: EasyRefresh(
                            onRefresh: () async {
                              await Provider.of<ComicViewerPageController>(
                                      context,
                                      listen: false)
                                  .loadComment();
                            },
                            child: SizedBox.expand(
                              child: SingleChildScrollView(
                                child: Wrap(
                                  children: [
                                    for (var item in Provider.of<
                                            ComicViewerPageController>(context)
                                        .comments)
                                      Padding(
                                        padding: const EdgeInsets.only(left: 5),
                                        child: ActionChip(
                                            onPressed: () {},
                                            avatar: CircleAvatar(
                                              child: Text(
                                                "${Provider.of<ComicViewerPageController>(context).maxLikes > 100 ? (item.likes / Provider.of<ComicViewerPageController>(context).maxLikes * 100).toInt() : item.likes}",
                                                style: const TextStyle(
                                                    fontSize: 13),
                                              ),
                                            ),
                                            label: Text(item.comment),
                                            backgroundColor: Color.lerp(
                                                Theme.of(context)
                                                    .colorScheme
                                                    .primaryContainer,
                                                Theme.of(context)
                                                    .colorScheme
                                                    .errorContainer,
                                                item.likes /
                                                    Provider.of<ComicViewerPageController>(
                                                            context)
                                                        .maxLikes),
                                            visualDensity: const VisualDensity(
                                                vertical: -1)),
                                      )
                                  ],
                                ),
                              ),
                            )),
                      ),
                      SizedBox.expand(
                        child: ListView.builder(
                          padding: EdgeInsets.zero,
                          itemCount:
                              Provider.of<ComicViewerPageController>(context)
                                  .chapters
                                  .reversed
                                  .toList()
                                  .length,
                          itemBuilder: (context, index) => ListTile(
                            selected: Provider.of<ComicViewerPageController>(
                                        context)
                                    .currentChapter ==
                                Provider.of<ComicViewerPageController>(context)
                                    .chapters
                                    .reversed
                                    .toList()[index],
                            title: Text(
                                Provider.of<ComicViewerPageController>(context)
                                    .chapters
                                    .reversed
                                    .toList()[index]
                                    .title),
                            subtitle: Text(S
                                .of(context)
                                .ComicDetailPageChapterEntitySubtitle(
                                    formatdate.formatDate(
                                        Provider.of<ComicViewerPageController>(
                                                context)
                                            .chapters
                                            .reversed
                                            .toList()[index]
                                            .uploadTime,
                                        [
                                          formatdate.yyyy,
                                          '-',
                                          formatdate.mm,
                                          '-',
                                          formatdate.dd
                                        ]),
                                    Provider.of<ComicViewerPageController>(
                                            context)
                                        .chapters
                                        .reversed
                                        .toList()[index]
                                        .chapterId)),
                            onTap: () {
                              Provider.of<ComicViewerPageController>(context,
                                      listen: false)
                                  .loadChapter(
                                      Provider.of<ComicViewerPageController>(
                                              context,
                                              listen: false)
                                          .chapters
                                          .reversed
                                          .toList()[index]);
                              Navigator.of(context).pop();
                            },
                          ),
                        ),
                      )
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
