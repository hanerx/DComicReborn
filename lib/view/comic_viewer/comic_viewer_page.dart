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
  static const _toolbarDuration = Duration(milliseconds: 300);
  static const _toolbarCurve = Curves.easeInOutCubic;
  static const double _appBarHeight = 70;
  static const double _toolBarHeight = 96;

  final PageController _pageController = PageController();
  final EasyRefreshController _easyRefreshController = EasyRefreshController();
  final ItemPositionsListener _itemPositionsListener =
      ItemPositionsListener.create();
  final ItemScrollController _itemScrollController = ItemScrollController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final GlobalKey _readerViewportKey = GlobalKey();
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

  Future<void> _turnPage(BuildContext context, {required bool forward}) async {
    final direction = context.read<ConfigProvider>().readDirection;
    final controller = context.read<ComicViewerPageController>();
    if (direction == ReadDirectionType.vertical) {
      final target = controller.currentPage + (forward ? 1 : -1);
      if (target >= 0 && target < _pageCount) {
        if (_itemScrollController.isAttached) {
          await _itemScrollController.scrollTo(
              index: target, duration: const Duration(milliseconds: 200));
        }
        return;
      }
    } else {
      final position = _pageController.position;
      final canTurn = forward
          ? position.pixels < position.maxScrollExtent
          : position.pixels > position.minScrollExtent;
      if (canTurn) {
        if (forward) {
          await _pageController.nextPage(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeIn);
        } else {
          await _pageController.previousPage(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeIn);
        }
        return;
      }
    }
    if (forward) {
      await _easyRefreshController.callLoad();
    } else {
      await _easyRefreshController.callRefresh();
    }
  }

  void _handleCommentsTap(BuildContext context, TapUpDetails details) {
    final config = context.read<ConfigProvider>();
    // Use viewport coordinates even when a vertical comments page is only
    // partially visible. Buttons inside the page win their own tap gestures.
    final viewport =
        _readerViewportKey.currentContext!.findRenderObject() as RenderBox;
    final position = viewport.globalToLocal(details.globalPosition);
    final vertical = config.readDirection == ReadDirectionType.vertical;
    final extent = vertical ? viewport.size.height : viewport.size.width;
    final offset = vertical ? position.dy : position.dx;
    final edgeSize = vertical
        ? config.verticalClickAreaSize
        : config.horizontalClickAreaSize;
    if (offset >= extent - edgeSize) {
      _turnPage(context,
          forward: config.readDirection != ReadDirectionType.right);
    } else if (offset < edgeSize) {
      _turnPage(context,
          forward: config.readDirection == ReadDirectionType.right);
    } else {
      final controller = context.read<ComicViewerPageController>();
      controller.showToolBar = !controller.showToolBar;
    }
  }

  Widget _buildCommentsPage(BuildContext context) {
    final controller = context.watch<ComicViewerPageController>();
    // Keep the page surface behind the rounded bars; only its content reflows.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapUp: (details) => _handleCommentsTap(context, details),
      child: ColoredBox(
        color: Theme.of(context).colorScheme.surface,
        child: AnimatedPadding(
          duration: _toolbarDuration,
          curve: _toolbarCurve,
          padding: EdgeInsets.only(
            top: controller.showToolBar ? _appBarHeight : 0,
            bottom: controller.showToolBar ? _toolBarHeight : 0,
          ),
          child: ChapterCommentsPage(
            key: ValueKey(controller.currentChapter?.chapterId),
            comments: controller.comments,
            onShowMore: () => _openDrawer(0),
            onShowToolbar: () =>
                controller.showToolBar = !controller.showToolBar,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final config = context.watch<ConfigProvider>();
    return Theme(
      data: config.readerTheme.resolve(
        Theme.of(context),
        seedColor: config.themeColor.color,
      ),
      child: ChangeNotifierProvider<ComicViewerPageController>(
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
                  key: _readerViewportKey,
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
      ),
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
            onTap: () => _turnPage(context, forward: false),
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
          onTap: () => _turnPage(context,
              forward: context.read<ConfigProvider>().readDirection ==
                  ReadDirectionType.right),
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
            onTap: () => _turnPage(context, forward: true),
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
          onTap: () => _turnPage(context,
              forward: context.read<ConfigProvider>().readDirection !=
                  ReadDirectionType.right),
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

  String _localeText(BuildContext context, String zh, String other) =>
      Localizations.localeOf(context).languageCode.startsWith('zh')
          ? zh
          : other;

  void _openViewerSettings(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: false,
      backgroundColor: Colors.transparent,
      elevation: 0,
      constraints:
          BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
      builder: (context) => Consumer<ConfigProvider>(
        builder: (context, config, child) {
          // Modal routes capture inherited themes. Resolve from the live app
          // context instead, including when switching back to the app theme.
          final theme = config.readerTheme.resolve(
            Theme.of(this.context),
            seedColor: config.themeColor.color,
          );
          return Theme(
            data: theme,
            child: Material(
              color: theme.colorScheme.surfaceContainerLow,
              shape: const RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(20))),
              clipBehavior: Clip.antiAlias,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Semantics(
                    label: MaterialLocalizations.of(context)
                        .modalBarrierDismissLabel,
                    button: true,
                    onTap: () => Navigator.of(context).pop(),
                    child: SizedBox(
                      height: 48,
                      child: Center(
                        child: Container(
                          width: 32,
                          height: 4,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.onSurfaceVariant,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Flexible(child: child!),
                ],
              ),
            ),
          );
        },
        child: const ViewerSettingList(),
      ),
    );
  }

  Widget _buildToolBar(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final controller = Provider.of<ComicViewerPageController>(context);
    final imageCount = _pageCount - 1;
    final pageLabel = imageCount > 0
        ? '${min(controller.currentPage, imageCount - 1) + 1}/$imageCount'
        : '';
    return AnimatedPositioned(
      duration: _toolbarDuration,
      curve: _toolbarCurve,
      left: 0,
      right: 0,
      bottom: controller.showToolBar ? 0 : -_toolBarHeight,
      child: SizedBox(
        height: _toolBarHeight,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.surfaceContainerLow,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            border: Border(top: BorderSide(color: colors.outlineVariant)),
          ),
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: Material(
              type: MaterialType.transparency,
              child: Column(
                children: [
                  SizedBox(
                    height: 48,
                    child: Row(
                      children: [
                        Expanded(child: _buildSlider(context)),
                        if (pageLabel.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Text(pageLabel,
                              style: Theme.of(context)
                                  .textTheme
                                  .labelMedium
                                  ?.copyWith(
                                      color: colors.onSurfaceVariant,
                                      fontFeatures: const [
                                    FontFeature.tabularFigures()
                                  ])),
                        ],
                        const SizedBox(width: 16),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Row(
                      children: [
                        ExpandCardButton(
                            onTap: () {
                              _easyRefreshController.callRefresh();
                            },
                            icon: Icons.keyboard_double_arrow_left,
                            tooltip: _localeText(
                                context, '上一章', 'Previous chapter')),
                        ExpandCardButton(
                            onTap: () {
                              _openDrawer(0);
                            },
                            icon: Icons.message_outlined,
                            tooltip: S.of(context).ComicViewerPageComments),
                        ExpandCardButton(
                            onTap: () {
                              _openDrawer(1);
                            },
                            icon: Icons.list_alt,
                            tooltip: S.of(context).ComicViewerPageDirectory),
                        ExpandCardButton(
                            onTap: () {
                              _openViewerSettings(context);
                            },
                            icon: Icons.settings,
                            tooltip: S.of(context).ReaderSettings),
                        ExpandCardButton(
                            onTap: () {
                              _easyRefreshController.callLoad();
                            },
                            icon: Icons.keyboard_double_arrow_right,
                            tooltip:
                                _localeText(context, '下一章', 'Next chapter')),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return AnimatedPositioned(
      duration: _toolbarDuration,
      curve: _toolbarCurve,
      left: 0,
      right: 0,
      top: Provider.of<ComicViewerPageController>(context).showToolBar
          ? 0
          : -_appBarHeight,
      child: SafeArea(
        child: SizedBox(
          height: _appBarHeight,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: colors.surfaceContainerLow,
              borderRadius:
                  const BorderRadius.vertical(bottom: Radius.circular(16)),
              border: Border(bottom: BorderSide(color: colors.outlineVariant)),
            ),
            child: ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(bottom: Radius.circular(16)),
              child: Material(
                type: MaterialType.transparency,
                child: Row(
                  children: [
                    BackButton(color: colors.onSurface),
                    Expanded(
                        child: Padding(
                      padding: const EdgeInsets.only(left: 8, right: 16),
                      child: Text(
                        Provider.of<ComicViewerPageController>(context).title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ))
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDrawer(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final controller = Provider.of<ComicViewerPageController>(context);
    final chapters = controller.chapters.reversed.toList();
    return Drawer(
      width: MediaQuery.of(context).size.width * 0.9,
      backgroundColor: colors.surfaceContainerLow,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.horizontal(left: Radius.circular(20))),
      child: SafeArea(
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
              labelColor: colors.primary,
              unselectedLabelColor: colors.onSurfaceVariant,
              indicatorColor: colors.primary,
              dividerColor: colors.outlineVariant,
            ),
            Expanded(
                child: TabBarView(
              controller: _drawerTabController,
              children: [
                SizedBox.expand(
                  child: EasyRefresh(
                      onRefresh: () async {
                        await controller.loadComment();
                      },
                      child: SizedBox.expand(
                        child: SingleChildScrollView(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                for (var item in controller.comments)
                                  Chip(
                                    avatar: CircleAvatar(
                                      child: item.avatar == null
                                          ? Text(
                                              '${controller.maxLikes > 100 ? (item.likes / controller.maxLikes * 100).toInt() : item.likes}',
                                              style:
                                                  const TextStyle(fontSize: 13),
                                            )
                                          : DComicImage(item.avatar!),
                                    ),
                                    label: TextScroll(
                                      item.comment,
                                      velocity: const Velocity(
                                          pixelsPerSecond: Offset(40, 0)),
                                      pauseBetween: const Duration(seconds: 3),
                                    ),
                                    backgroundColor: Color.lerp(
                                        colors.primaryContainer,
                                        colors.errorContainer,
                                        controller.maxLikes > 0
                                            ? item.likes / controller.maxLikes
                                            : 0),
                                    visualDensity:
                                        const VisualDensity(vertical: -1),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      )),
                ),
                SizedBox.expand(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: chapters.length,
                    itemBuilder: (context, index) => ListTile(
                      selected: controller.currentChapter == chapters[index],
                      title: Text(chapters[index].title),
                      subtitle: Text(S
                          .of(context)
                          .ComicDetailPageChapterEntitySubtitle(
                              formatdate.formatDate(
                                  chapters[index].uploadTime, [
                                formatdate.yyyy,
                                '-',
                                formatdate.mm,
                                '-',
                                formatdate.dd
                              ]),
                              chapters[index].chapterId)),
                      onTap: () {
                        controller.loadChapter(chapters[index]);
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
    );
  }
}
