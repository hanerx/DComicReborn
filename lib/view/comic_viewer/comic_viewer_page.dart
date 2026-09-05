import 'dart:math';

import 'package:dcomic/generated/l10n.dart';
import 'package:dcomic/providers/config_provider.dart';
import 'package:dcomic/providers/models/comic_source_model.dart';
import 'package:dcomic/providers/page_controllers/comic_viewer_page_controller.dart';
import 'package:dcomic/view/components/dcomic_image.dart';
import 'package:dcomic/view/components/expand_card_button.dart';
import 'package:dcomic/view/components/viewer_setting_list.dart';
import 'package:dcomic/view/comic_viewer/chapter_comments_page.dart';
import 'package:easy_refresh/easy_refresh.dart';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:provider/provider.dart';
import 'package:date_format/date_format.dart' as formatdate;
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:text_scroll/text_scroll.dart';

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

class _ComicViewerPageState extends State<ComicViewerPage>
    with SingleTickerProviderStateMixin {
  final PageController _pageController = PageController();
  final EasyRefreshController _easyRefreshController = EasyRefreshController();
  final ItemPositionsListener _itemPositionsListener =
      ItemPositionsListener.create();
  final ItemScrollController _itemScrollController = ItemScrollController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late final TabController _drawerTabController;
  late ComicViewerPageController _viewerController;
  bool _verticalCommentsVisible = false;

  @override
  void initState() {
    super.initState();
    _drawerTabController = TabController(length: 2, vsync: this);
    _itemPositionsListener.itemPositions.addListener(_updateVisibleItems);
  }

  @override
  void dispose() {
    _itemPositionsListener.itemPositions.removeListener(_updateVisibleItems);
    _drawerTabController.dispose();
    _pageController.dispose();
    _easyRefreshController.dispose();
    super.dispose();
  }

  void _updateVisibleItems() {
    if (!mounted) return;
    final items = _itemPositionsListener.itemPositions.value.where((position) =>
        position.itemTrailingEdge > 0 && position.itemLeadingEdge < 1);
    if (items.isEmpty) return;
    final first = items.reduce((a, b) => a.index < b.index ? a : b);
    final imageCount = _viewerController.chapterDetailModel?.pages.length;
    final commentsVisible = imageCount != null &&
        items.any((position) => position.index == imageCount);
    if (_verticalCommentsVisible != commentsVisible) {
      setState(() => _verticalCommentsVisible = commentsVisible);
    }
    if (_viewerController.currentPage != first.index) {
      _viewerController.currentPage = first.index;
    }
  }

  int get _pageCount => _viewerController.chapterDetailModel == null
      ? 0
      : _viewerController.chapterDetailModel!.pages.length + 1;

  void _openDrawer(int tab) {
    _drawerTabController.index = tab;
    _scaffoldKey.currentState?.openEndDrawer();
  }

  void _resetPage() {
    // The lists must receive the new chapter's item count before jumping.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_pageController.hasClients) {
        _pageController.jumpToPage(0);
      }
      if (_itemScrollController.isAttached) {
        _itemScrollController.jumpTo(index: 0);
      }
    });
  }

  Widget _buildCommentsPage(BuildContext context) {
    final controller = context.watch<ComicViewerPageController>();
    return Padding(
      padding: EdgeInsets.only(
        top: controller.showToolBar ? 70 : 0,
        bottom: controller.showToolBar ? 90 : 0,
      ),
      child: ChapterCommentsPage(
        key: ValueKey(controller.currentChapter?.chapterId),
        comments: controller.comments,
        onShowMore: () => _openDrawer(0),
        onShowToolbar: () => controller.showToolBar = !controller.showToolBar,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<ComicViewerPageController>(
      lazy: false,
      create: (_) => _viewerController = ComicViewerPageController(
          widget.detailModel, widget.chapters, widget.chapterId),
      builder: (context, child) => Scaffold(
          key: _scaffoldKey,
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
                _resetPage();
              },
              onLoad: () async {
                await Provider.of<ComicViewerPageController>(context,
                        listen: false)
                    .load();
                _resetPage();
              },
              child: SafeArea(
                  child: Stack(
                children: [
                  _buildViewer(context),
                  if (!(context.watch<ConfigProvider>().readDirection ==
                          ReadDirectionType.vertical
                      ? _verticalCommentsVisible
                      : _pageCount > 0 &&
                          context
                                  .watch<ComicViewerPageController>()
                                  .currentPage ==
                              _pageCount - 1)) ...[
                    _buildPrePageButton(context),
                    _buildShowButton(context),
                    _buildNextPageButton(context),
                  ],
                  _buildAppBar(context),
                  _buildToolBar(context)
                ],
              )),
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
      itemCount: _pageCount,
      builder: (context, index) {
        if (index == _pageCount - 1) {
          return PhotoViewGalleryPageOptions.customChild(
            disableGestures: true,
            child: _buildCommentsPage(context),
          );
        }
        return PhotoViewGalleryPageOptions.customChild(
            initialScale: PhotoViewComputedScale.contained,
            minScale: PhotoViewComputedScale.contained,
            maxScale: PhotoViewComputedScale.covered * 4.1,
            child: DComicImage(
                _viewerController.chapterDetailModel!.pages[index]));
      },
    );
  }

  Widget _buildVerticalViewer(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => ScrollablePositionedList.builder(
        itemPositionsListener: _itemPositionsListener,
        itemScrollController: _itemScrollController,
        itemCount: _pageCount,
        itemBuilder: (context, index) => index == _pageCount - 1
            ? SizedBox(
                height: constraints.maxHeight,
                child: _buildCommentsPage(context),
              )
            : DComicImage(_viewerController.chapterDetailModel!.pages[index]),
      ),
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
          divisions: _pageCount > 1 ? _pageCount - 1 : null,
          min: 0,
          max: max(_pageCount - 1, 0).toDouble(),
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
    if (Provider.of<ConfigProvider>(context).readDirection ==
        ReadDirectionType.vertical) {
      return Positioned(
          left: 0,
          right: 0,
          top: 0,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () async {
              if (Provider.of<ComicViewerPageController>(context, listen: false)
                      .currentPage >
                  0) {
                if (_itemScrollController.isAttached) {
                  _itemScrollController.scrollTo(
                      index: Provider.of<ComicViewerPageController>(context,
                                  listen: false)
                              .currentPage -
                          1,
                      duration: const Duration(milliseconds: 200));
                }
              } else {
                await _easyRefreshController.callRefresh();
              }
            },
            child: SizedBox(
              height:
                  Provider.of<ConfigProvider>(context).verticalClickAreaSize,
              child: Provider.of<ConfigProvider>(context).drawDebugWidget
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
            if (Provider.of<ConfigProvider>(context, listen: false)
                    .readDirection ==
                ReadDirectionType.right) {
              if (_pageController.position.pixels !=
                  _pageController.position.maxScrollExtent) {
                _pageController.nextPage(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeIn);
              } else {
                _easyRefreshController.callLoad();
              }
            } else {
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
            width: Provider.of<ConfigProvider>(context).horizontalClickAreaSize,
            child: Provider.of<ConfigProvider>(context).drawDebugWidget
                ? Container(
                    color: Color.lerp(Theme.of(context).colorScheme.primary,
                        Colors.transparent, 0.5),
                  )
                : null,
          ),
        ));
  }

  Widget _buildNextPageButton(BuildContext context) {
    if (Provider.of<ConfigProvider>(context).readDirection ==
        ReadDirectionType.vertical) {
      return Positioned(
          right: 0,
          left: 0,
          bottom: 0,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () async {
              if (Provider.of<ComicViewerPageController>(context, listen: false)
                      .currentPage <
                  _pageCount - 1) {
                if (_itemScrollController.isAttached) {
                  _itemScrollController.scrollTo(
                      index: Provider.of<ComicViewerPageController>(context,
                                  listen: false)
                              .currentPage +
                          1,
                      duration: const Duration(milliseconds: 200));
                }
              } else {
                await _easyRefreshController.callLoad();
              }
            },
            child: SizedBox(
              height:
                  Provider.of<ConfigProvider>(context).verticalClickAreaSize,
              child: Provider.of<ConfigProvider>(context).drawDebugWidget
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
            if (Provider.of<ConfigProvider>(context, listen: false)
                    .readDirection ==
                ReadDirectionType.left) {
              if (_pageController.position.pixels !=
                  _pageController.position.maxScrollExtent) {
                _pageController.nextPage(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeIn);
              } else {
                _easyRefreshController.callLoad();
              }
            } else {
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
            width: Provider.of<ConfigProvider>(context).horizontalClickAreaSize,
            child: Provider.of<ConfigProvider>(context).drawDebugWidget
                ? Container(
                    color: Color.lerp(Theme.of(context).colorScheme.primary,
                        Colors.transparent, 0.5),
                  )
                : null,
          ),
        ));
  }

  Widget _buildShowButton(BuildContext context) {
    if (Provider.of<ConfigProvider>(context).readDirection ==
        ReadDirectionType.vertical) {
      return Positioned(
          right: 0,
          left: 0,
          top: Provider.of<ConfigProvider>(context).verticalClickAreaSize,
          bottom: Provider.of<ConfigProvider>(context).verticalClickAreaSize,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () {
              Provider.of<ComicViewerPageController>(context, listen: false)
                  .showToolBar = !Provider.of<ComicViewerPageController>(
                      context,
                      listen: false)
                  .showToolBar;
            },
            child: SizedBox(
              child: Provider.of<ConfigProvider>(context).drawDebugWidget
                  ? Container(
                      color: Color.lerp(Theme.of(context).colorScheme.tertiary,
                          Colors.transparent, 0.5),
                    )
                  : null,
            ),
          ));
    }
    return Positioned(
        right: Provider.of<ConfigProvider>(context).horizontalClickAreaSize,
        left: Provider.of<ConfigProvider>(context).horizontalClickAreaSize,
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
            child: Provider.of<ConfigProvider>(context).drawDebugWidget
                ? Container(
                    color: Color.lerp(Theme.of(context).colorScheme.tertiary,
                        Colors.transparent, 0.5),
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
                        _openDrawer(0);
                      },
                      icon: Icons.message_outlined),
                ),
                Builder(
                    builder: (context) => ExpandCardButton(
                        onTap: () {
                          _openDrawer(1);
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
            child: Column(
              children: [
                TabBar(
                  controller: _drawerTabController,
                  tabs: [
                    Tab(
                      child: Row(
                        children: [
                          const Icon(Icons.message_outlined),
                          Expanded(
                              child: Text(S.of(context).ComicViewerPageComments,
                                  textAlign: TextAlign.center))
                        ],
                      ),
                    ),
                    Tab(
                        child: Row(
                      children: [
                        const Icon(Icons.list_alt),
                        Expanded(
                            child: Text(S.of(context).ComicViewerPageDirectory,
                                textAlign: TextAlign.center))
                      ],
                    ))
                  ],
                  labelColor: Theme.of(context).colorScheme.primary,
                  indicatorColor: Theme.of(context).colorScheme.primary,
                ),
                Expanded(
                    child: TabBarView(
                  controller: _drawerTabController,
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
                                  for (var item
                                      in Provider.of<ComicViewerPageController>(
                                              context)
                                          .comments)
                                    Padding(
                                      padding: const EdgeInsets.only(left: 5),
                                      child: ActionChip(
                                          onPressed: () {},
                                          avatar: CircleAvatar(
                                            child: item.avatar == null
                                                ? Text(
                                                    "${Provider.of<ComicViewerPageController>(context).maxLikes > 100 ? (item.likes / Provider.of<ComicViewerPageController>(context).maxLikes * 100).toInt() : item.likes}",
                                                    style: const TextStyle(
                                                        fontSize: 13),
                                                  )
                                                : DComicImage(item.avatar!),
                                          ),
                                          label: TextScroll(
                                            item.comment,
                                            velocity: const Velocity(
                                                pixelsPerSecond: Offset(40, 0)),
                                            pauseBetween:
                                                const Duration(seconds: 3),
                                          ),
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
                            _easyRefreshController.callRefresh();
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
    );
  }
}
