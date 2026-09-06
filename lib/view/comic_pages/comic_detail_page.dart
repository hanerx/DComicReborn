import 'dart:math' as math;

import 'package:date_format/date_format.dart' as formatdate;
import 'package:dcomic/generated/l10n.dart';
import 'package:dcomic/providers/models/comic_source_model.dart';
import 'package:dcomic/providers/navigator_provider.dart';
import 'package:dcomic/providers/page_controllers/comic_detail_page_controller.dart';
import 'package:dcomic/providers/source_provider.dart';
import 'package:dcomic/view/comic_viewer/comic_viewer_page.dart';
import 'package:dcomic/view/components/comment_card.dart';
import 'package:dcomic/view/components/dcomic_image.dart';
import 'package:dcomic/view/popup_pages/search_dialog.dart';
import 'package:dio/dio.dart';
import 'package:easy_refresh/easy_refresh.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttericon/font_awesome5_icons.dart';
import 'package:provider/provider.dart';

class ComicDetailPage extends StatefulWidget {
  final String title;
  final String comicId;
  final BaseComicSourceModel? comicSourceModel;

  const ComicDetailPage(
      {super.key,
      required this.title,
      required this.comicId,
      this.comicSourceModel});

  @override
  State<StatefulWidget> createState() => _ComicDetailPageState();
}

class _ComicDetailPageState extends State<ComicDetailPage> {
  final EasyRefreshController _easyRefreshController = EasyRefreshController();
  bool _descriptionExpanded = false;
  static const _compactCoverSize = Size(108, 162);

  bool _isZh(BuildContext context) =>
      Localizations.localeOf(context).languageCode == 'zh';

  String _tr(BuildContext context, String zh, String en) =>
      _isZh(context) ? zh : en;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) {
        var controller = ComicDetailPageController(widget.comicSourceModel);
        // 等待 Provider 挂载后再加载详情，避免在构建过程中通知监听者。
        Future.delayed(Duration.zero).then((_) {
          if (context.mounted) {
            controller.refresh(context, widget.comicId, widget.title);
          }
        });
        return controller;
      },
      builder: (context, child) {
        final media = MediaQuery.of(context);
        final theme = Theme.of(context);
        final titleStyle = theme.textTheme.titleMedium!;
        final statusStyle = theme.textTheme.bodySmall!;
        final detailsHeight =
            media.textScaler.scale(titleStyle.fontSize!) * 1.4 * 2 +
                media.textScaler.scale(statusStyle.fontSize!) *
                    (statusStyle.height ?? 1.4) +
                8 +
                16 +
                48;
        final compactExtent =
            math.max(_compactCoverSize.height, detailsHeight) + 24;
        final expandedExtent = math.max(
          compactExtent + 80,
          math.min(260, media.size.height * 0.4),
        );
        final controller = Provider.of<ComicDetailPageController>(context);
        final ready = controller.loadState == ComicDetailLoadState.ready;
        return Scaffold(
          backgroundColor: theme.colorScheme.surface,
          endDrawer: ready ? _buildEndDrawer(context) : null,
          bottomNavigationBar: ready ? _buildBottomBar(context) : null,
          body: EasyRefresh(
            controller: _easyRefreshController,
            header: const ClassicHeader(
              triggerOffset: 48,
              position: IndicatorPosition.locator,
              clamping: true,
              safeArea: false,
              showMessage: false,
              textStyle: TextStyle(fontSize: 12),
            ),
            onRefresh: () async {
              await Provider.of<ComicDetailPageController>(context,
                      listen: false)
                  .refresh(context, widget.comicId, widget.title);
            },
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                // 封面和工具栏属于同一个可收缩头部，展开时图片延伸到状态栏。
                if (ready)
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _DetailCoverHeaderDelegate(
                      minExtent: media.padding.top + kToolbarHeight,
                      compactExtent:
                          media.padding.top + kToolbarHeight + compactExtent,
                      maxExtent:
                          media.padding.top + kToolbarHeight + expandedExtent,
                      toolbarExtent: media.padding.top + kToolbarHeight,
                      title: controller.title,
                      compactCoverSize: _compactCoverSize,
                      cover: DComicImage(controller.cover, fit: BoxFit.cover),
                      details: _buildInfoDetails(context),
                    ),
                  )
                else
                  SliverAppBar(
                    pinned: true,
                    title: Text(widget.title,
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                const HeaderLocator.sliver(clearExtent: false),
                if (ready)
                  SliverPadding(
                    padding: const EdgeInsets.only(bottom: 24),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        _buildDescriptionSection(context),
                        _buildTagSection(
                          context,
                          Icons.person_outline,
                          _tr(context, '作者', 'Authors'),
                          controller.authors,
                        ),
                        _buildTagSection(
                          context,
                          Icons.category_outlined,
                          _tr(context, '分类', 'Categories'),
                          controller.categories,
                        ),
                        _buildBindingSection(context),
                        _buildChapterToolbar(context),
                        ..._buildChapters(context),
                      ]),
                    ),
                  )
                else
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _buildUnavailableDetails(context),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoDetails(BuildContext context) {
    final controller = Provider.of<ComicDetailPageController>(context);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          controller.title,
          style: theme.textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w600, height: 1.4),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(Icons.update, size: 14, color: colors.onSurfaceVariant),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                '${controller.status} · ${controller.lastUpdate}',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: colors.onSurfaceVariant),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        IconButton(
          onPressed: () {
            Provider.of<ComicDetailPageController>(context, listen: false)
                    .subscribe =
                !Provider.of<ComicDetailPageController>(context, listen: false)
                    .subscribe;
          },
          icon: Icon(
            controller.subscribe
                ? Icons.favorite_rounded
                : Icons.favorite_border_rounded,
            color:
                controller.subscribe ? colors.error : colors.onSurfaceVariant,
          ),
          tooltip: _tr(context, '收藏', 'Favorite'),
        ),
      ],
    );
  }

  Widget _buildSectionLabel(BuildContext context, IconData icon, String label) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: colors.onSurfaceVariant),
        const SizedBox(width: 6),
        Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: colors.onSurfaceVariant, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _buildDescriptionSection(BuildContext context) {
    var controller = Provider.of<ComicDetailPageController>(context);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    if (controller.description.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionLabel(
              context, Icons.subject, _tr(context, '简介', 'Description')),
          const SizedBox(height: 8),
          LayoutBuilder(builder: (context, constraints) {
            final style = theme.textTheme.bodyMedium!
                .copyWith(color: colors.onSurface, height: 1.6);
            const int collapsedLines = 4;
            final painter = TextPainter(
              text: TextSpan(text: controller.description, style: style),
              textDirection: Directionality.of(context),
              textScaler: MediaQuery.textScalerOf(context),
              locale: Localizations.localeOf(context),
              maxLines: collapsedLines,
            )..layout(maxWidth: constraints.maxWidth);
            final canCollapse = painter.didExceedMaxLines;
            painter.dispose();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  controller.description,
                  style: style,
                  maxLines: _descriptionExpanded ? null : collapsedLines,
                  overflow: _descriptionExpanded
                      ? TextOverflow.visible
                      : TextOverflow.ellipsis,
                ),
                if (canCollapse)
                  InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => setState(
                        () => _descriptionExpanded = !_descriptionExpanded),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: 15, horizontal: 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _descriptionExpanded
                                ? _tr(context, '收起', 'Show Less')
                                : _tr(context, '展开', 'Show More'),
                            style: theme.textTheme.bodySmall?.copyWith(
                                color: colors.primary,
                                fontWeight: FontWeight.w600),
                          ),
                          Icon(
                            _descriptionExpanded
                                ? Icons.keyboard_arrow_up
                                : Icons.keyboard_arrow_down,
                            size: 18,
                            color: colors.primary,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildTagSection(BuildContext context, IconData icon, String label,
      List<CategoryEntity> entities) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    if (entities.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionLabel(context, icon, label),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var item in entities)
                ActionChip(
                  onPressed: item.onTap == null
                      ? null
                      : () {
                          item.onTap!(context);
                        },
                  label: Text(
                    item.title,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: colors.onSurface),
                  ),
                  backgroundColor: colors.surfaceContainerHigh,
                  side: BorderSide(color: colors.outlineVariant),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUnavailableDetails(BuildContext context) {
    final controller = Provider.of<ComicDetailPageController>(context);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return SafeArea(
      top: false,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (controller.isLoading)
                  const SizedBox.square(
                    dimension: 40,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  Icon(Icons.error_outline_rounded,
                      size: 48, color: colors.onSurfaceVariant),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    controller.isLoading
                        ? _tr(context, '正在加载漫画', 'Loading Comic')
                        : _tr(context, '暂时无法显示漫画', 'Unable to Display Comic'),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                if (!controller.isLoading) ...[
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      _describeLoadError(context, controller.loadError),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: colors.onSurfaceVariant),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton.icon(
                    onPressed: () => controller.refresh(
                        context, widget.comicId, widget.title),
                    icon: const Icon(Icons.refresh_rounded, size: 20),
                    label: Text(_tr(context, '重试', 'Retry')),
                  ),
                ],
                const SizedBox(height: 16),
                _buildBindingSection(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBindingSection(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: ListTileTheme.merge(
        dense: true,
        minTileHeight: 48,
        minVerticalPadding: 6,
        minLeadingWidth: 24,
        horizontalTitleGap: 12,
        contentPadding: EdgeInsets.zero,
        titleTextStyle: theme.textTheme.bodyMedium,
        subtitleTextStyle:
            theme.textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
        child: _buildSourceController(context),
      ),
    );
  }

  String _describeLoadError(BuildContext context, Object? error) {
    Object? cause = error;
    for (var depth = 0; depth < 8 && cause is DioException; depth++) {
      if (cause.error == null) break;
      cause = cause.error;
    }
    if (cause is StateError) return cause.message.toString();
    if (cause is FormatException ||
        cause is TypeError ||
        cause is NoSuchMethodError) {
      return _tr(context, '漫画源数据解析失败，请重试或切换漫画源。',
          'The comic source returned invalid data. Retry or choose another source.');
    }
    if (error is DioException) {
      switch (error.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          return _tr(context, '漫画源请求超时，请重试或切换漫画源。',
              'The request timed out. Retry or choose another source.');
        case DioExceptionType.badResponse:
          return _tr(
              context,
              '漫画源请求失败（HTTP ${error.response?.statusCode}），请重试或切换漫画源。',
              'The source returned HTTP ${error.response?.statusCode}. Retry or choose another source.');
        default:
          return _tr(context, '无法连接漫画源，请检查网络后重试。',
              'Unable to connect to the source. Check your connection and retry.');
      }
    }
    return _tr(context, '漫画详情加载失败，请重试或切换漫画源。',
        'Unable to load comic details. Retry or choose another source.');
  }

  Future<void> _bindComic(BuildContext context) async {
    final controller =
        Provider.of<ComicDetailPageController>(context, listen: false);
    final source = controller.comicSourceModel;
    if (source == null) return;
    final comicId = await showDialog<String>(
      context: context,
      builder: (_) => SearchDialog(
        sourceModel: source,
        title: widget.title,
        comicId: widget.comicId,
      ),
    );
    if (!context.mounted ||
        comicId == null ||
        controller.comicSourceModel != source) {
      return;
    }
    await controller.bindComicId(widget.comicId, comicId);
  }

  Future<void> _confirmUnbind(BuildContext context) async {
    final controller =
        Provider.of<ComicDetailPageController>(context, listen: false);
    final source = controller.comicSourceModel;
    if (source == null || !controller.canUnbind) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final colors = Theme.of(dialogContext).colorScheme;
        return AlertDialog(
          scrollable: true,
          icon: Icon(Icons.link_off_rounded, color: colors.error),
          title: Text(_tr(context, '解除绑定？', 'Remove Binding?')),
          content: Text(_tr(
            context,
            '将解除这部漫画与「${source.type.sourceName}」的绑定，不会删除收藏或阅读记录。之后需要重新绑定才能从这个源阅读。',
            'Remove this comic’s binding to ${source.type.sourceName}? Favorites and reading history will be kept. Bind it again to read from this source.',
          )),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(_tr(context, '取消', 'Cancel')),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: colors.error,
                foregroundColor: colors.onError,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(_tr(context, '解除绑定', 'Remove Binding')),
            ),
          ],
        );
      },
    );
    if (!context.mounted ||
        confirmed != true ||
        controller.comicSourceModel != source) {
      return;
    }
    await controller.unbindComicId(widget.comicId);
  }

  Widget _buildSourceController(BuildContext context) {
    final controller = Provider.of<ComicDetailPageController>(context);
    final colors = Theme.of(context).colorScheme;
    final source = controller.comicSourceModel;
    final origin = controller.sourceModel;
    final canBind = !controller.isLoading &&
        source != null &&
        origin != null &&
        source.type.sourceId != origin.type.sourceId;
    return ListTile(
      leading: controller.isLoading
          ? SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                semanticsLabel: _tr(context, '正在加载', 'Loading'),
              ),
            )
          : Tooltip(
              message: controller.canUnbind
                  ? _tr(context, '已绑定', 'Bound')
                  : _tr(context, '未绑定', 'Not Bound'),
              child: Icon(
                controller.canUnbind
                    ? Icons.link_rounded
                    : Icons.link_off_rounded,
                size: 20,
                color: controller.canUnbind
                    ? colors.primary
                    : colors.onSurfaceVariant,
              ),
            ),
      title: Row(
        children: [
          Flexible(
            child: Text(
                source?.type.sourceName ?? _tr(context, '漫画源', 'Comic Source')),
          ),
          const SizedBox(width: 4),
          Icon(Icons.expand_more_rounded,
              size: 18, color: colors.onSurfaceVariant),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SelectableText(
              '${S.of(context).ComicDetailPageOriginalComicId}${widget.comicId}'),
          if (controller.boundComicId != null)
            SelectableText(
                '${S.of(context).ComicDetailPageBindComicId}${controller.boundComicId}'),
        ],
      ),
      trailing: canBind
          ? Tooltip(
              message: controller.canUnbind
                  ? _tr(context, '重新绑定；长按解除绑定',
                      'Rebind; long press to remove binding')
                  : _tr(context, '绑定漫画', 'Bind Comic'),
              triggerMode: TooltipTriggerMode.manual,
              child: GestureDetector(
                onLongPress:
                    controller.canUnbind ? () => _confirmUnbind(context) : null,
                child: IconButton(
                  onPressed: () => _bindComic(context),
                  icon: const Icon(Icons.edit_outlined, size: 20),
                ),
              ),
            )
          : null,
      onTap: () => _showSourceSheet(context),
    );
  }

  Future<void> _showSourceSheet(BuildContext context) async {
    final controller =
        Provider.of<ComicDetailPageController>(context, listen: false);
    final sources =
        Provider.of<ComicSourceProvider>(context, listen: false).orderedSources;
    final selected = await showModalBottomSheet<BaseComicSourceModel>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(
                  _tr(context, '选择漫画源', 'Choose Comic Source'),
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              for (final source in sources)
                ListTile(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  title: Text(source.type.sourceName),
                  selected: source == controller.comicSourceModel,
                  trailing: source == controller.comicSourceModel
                      ? Icon(Icons.check_rounded,
                          color: theme.colorScheme.primary)
                      : null,
                  onTap: () => Navigator.of(sheetContext).pop(source),
                ),
            ],
          ),
        );
      },
    );
    if (!context.mounted ||
        selected == null ||
        selected == controller.comicSourceModel) {
      return;
    }
    controller.comicSourceModel = selected;
    await controller.refresh(context, widget.comicId, widget.title);
  }

  Widget _buildChapterToolbar(BuildContext context) {
    var controller = Provider.of<ComicDetailPageController>(context);
    final colors = Theme.of(context).colorScheme;
    var chapterCount = controller.chapters.values
        .fold<int>(0, (sum, list) => sum + list.length);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 8, 0),
      child: Row(
        children: [
          Expanded(
            child: Text(
              chapterCount > 0
                  ? '${_tr(context, '章节', 'Chapters')} ($chapterCount)'
                  : _tr(context, '章节', 'Chapters'),
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.w600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          TextButton.icon(
            onPressed: () {
              Provider.of<ComicDetailPageController>(context, listen: false)
                  .nest = !Provider.of<ComicDetailPageController>(context,
                      listen: false)
                  .nest;
            },
            icon: Icon(
              controller.nest
                  ? Icons.grid_view_outlined
                  : Icons.view_list_outlined,
              size: 18,
            ),
            label: Text(controller.nest
                ? S.of(context).ComicDetailPageGridMode
                : S.of(context).ComicDetailPageListMode),
            style: TextButton.styleFrom(foregroundColor: colors.primary),
          ),
          TextButton.icon(
            onPressed: () {
              Provider.of<ComicDetailPageController>(context, listen: false)
                  .reverse = !Provider.of<ComicDetailPageController>(context,
                      listen: false)
                  .reverse;
            },
            icon: Icon(
              controller.reverse
                  ? FontAwesome5.sort_amount_down
                  : FontAwesome5.sort_amount_down_alt,
              size: 18,
            ),
            label: Text(controller.reverse
                ? S.of(context).ComicDetailPageReverseMode
                : S.of(context).ComicDetailPagePositiveMode),
            style: TextButton.styleFrom(foregroundColor: colors.primary),
          )
        ],
      ),
    );
  }

  List<Widget> _buildChapters(BuildContext context) {
    var controller = Provider.of<ComicDetailPageController>(context);
    final colors = Theme.of(context).colorScheme;
    List<Widget> chapters = [];
    for (var tuple in controller.chapters.entries) {
      var data =
          controller.reverse ? tuple.value : tuple.value.reversed.toList();
      chapters.add(Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 4),
              child: Text(
                tuple.key,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: colors.onSurfaceVariant,
                    fontWeight: FontWeight.w600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            _buildChapterList(context, data),
          ],
        ),
      ));
    }

    return chapters;
  }

  Widget _buildChapterList(
      BuildContext context, List<BaseComicChapterEntityModel> data) {
    var controller = Provider.of<ComicDetailPageController>(context);
    final colors = Theme.of(context).colorScheme;
    if (data.isEmpty) {
      return const SizedBox.shrink();
    }

    if (controller.nest) {
      return GridView.builder(
          padding: EdgeInsets.zero,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3, childAspectRatio: 2.0),
          itemCount: data.length,
          itemBuilder: (context, index) {
            var chapter = data[index];
            bool isCurrent = chapter.chapterId == controller.latestChapterId;
            // latestChapterId 来自本地阅读历史，即“读到此处”的那一话
            Widget label = Text(
              chapter.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            );
            Widget button;
            if (isCurrent) {
              button = FilledButton(
                onPressed: () => _openChapter(context, index, data,
                    writeHistory: true, refreshOnReturn: true),
                style: FilledButton.styleFrom(
                  backgroundColor: colors.primary,
                  foregroundColor: colors.onPrimary,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
                ),
                child: label,
              );
            } else {
              button = OutlinedButton(
                onPressed: () => _openChapter(context, index, data,
                    writeHistory: true, refreshOnReturn: true),
                style: OutlinedButton.styleFrom(
                  foregroundColor: colors.onSurface,
                  side: BorderSide(color: colors.outlineVariant),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
                ),
                child: label,
              );
            }
            return Padding(
              padding: const EdgeInsets.all(3),
              child: button,
            );
          });
    } else {
      return ListView.builder(
        padding: EdgeInsets.zero,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: data.length,
        itemBuilder: (context, index) {
          var chapter = data[index];
          bool isCurrent = chapter.chapterId == controller.latestChapterId;
          final trailing = isCurrent
              ? Icon(Icons.bookmark, size: 18, color: colors.primary)
              : null;
          return ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 4),
            title: Text(
              chapter.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: isCurrent
                  ? Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: colors.primary, fontWeight: FontWeight.w600)
                  : Theme.of(context).textTheme.titleSmall,
            ),
            subtitle: Text(
              S.of(context).ComicDetailPageChapterEntitySubtitle(
                  formatdate.formatDate(chapter.uploadTime, [
                    formatdate.yyyy,
                    '-',
                    formatdate.mm,
                    '-',
                    formatdate.dd
                  ]),
                  chapter.chapterId),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: colors.onSurfaceVariant),
            ),
            trailing: trailing,
            onTap: () => _openChapter(context, index, data),
          );
        },
      );
    }
  }

  void _openChapter(
      BuildContext context, int index, List<BaseComicChapterEntityModel> data,
      {bool writeHistory = false, bool refreshOnReturn = false}) {
    var chapter = data[index];
    var controller =
        Provider.of<ComicDetailPageController>(context, listen: false);
    var detailModel = controller.detailModel!;
    var chapters = controller.reverse ? data.reversed.toList() : data;
    if (writeHistory) {
      controller.addComicHistory(chapter.chapterId, chapter.title);
    }
    Provider.of<NavigatorProvider>(context, listen: false)
        .getNavigator(context, NavigatorType.defaultNavigator)
        ?.push(MaterialPageRoute(
            builder: (context) => ComicViewerPage(
                detailModel: detailModel,
                chapters: chapters,
                chapterId: chapter.chapterId),
            settings: const RouteSettings(name: 'ComicViewerPage')))
        .then((value) async {
      if (refreshOnReturn) {
        await Provider.of<ComicDetailPageController>(context, listen: false)
            .refresh(context, widget.comicId, widget.title);
      }
    });
  }

  void _startReading(BuildContext context) {
    var controller =
        Provider.of<ComicDetailPageController>(context, listen: false);
    if (controller.chapters.isEmpty) {
      return;
    }
    // 优先回到本地历史记录的最后一话，否则从第一组最新一话开始
    var resultChapters = controller.chapters.values.first;
    var resultChapter = resultChapters.reversed.toList().first;
    for (var data in controller.chapters.values) {
      for (var item in data) {
        if (item.chapterId == controller.latestChapterId) {
          resultChapter = item;
          resultChapters = data;
          break;
        }
      }
    }

    var detailModel = controller.detailModel!;
    var chapters =
        controller.reverse ? resultChapters.reversed.toList() : resultChapters;
    controller.addComicHistory(resultChapter.chapterId, resultChapter.title);
    Provider.of<NavigatorProvider>(context, listen: false)
        .getNavigator(context, NavigatorType.defaultNavigator)
        ?.push(MaterialPageRoute(
            builder: (context) => ComicViewerPage(
                detailModel: detailModel,
                chapters: chapters,
                chapterId: resultChapter.chapterId),
            settings: const RouteSettings(name: 'ComicViewerPage')))
        .then((value) async {
      await Provider.of<ComicDetailPageController>(context, listen: false)
          .refresh(context, widget.comicId, widget.title);
    });
  }

  Widget _buildBottomBar(BuildContext context) {
    var controller = Provider.of<ComicDetailPageController>(context);
    final colors = Theme.of(context).colorScheme;
    bool hasChapters = controller.chapters.isNotEmpty;
    bool isContinue = controller.latestChapterId != null;
    return BottomAppBar(
      color: colors.surface,
      elevation: 0,
      height: 72,
      padding: const EdgeInsets.fromLTRB(8, 12, 16, 12),
      child: Row(
        children: [
          Builder(
            builder: (context) => IconButton(
              onPressed: () {
                Scaffold.of(context).openEndDrawer();
              },
              icon: const Icon(Icons.mode_comment_outlined),
              color: colors.onSurfaceVariant,
              tooltip: S.of(context).ComicDetailPageComments,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: FilledButton.icon(
              onPressed: hasChapters ? () => _startReading(context) : null,
              icon: const Icon(Icons.play_arrow_rounded),
              label: Text(isContinue
                  ? _tr(context, '继续阅读', 'Continue Reading')
                  : _tr(context, '开始阅读', 'Start Reading')),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                backgroundColor: colors.primary,
                foregroundColor: colors.onPrimary,
                disabledBackgroundColor: colors.surfaceContainerHighest,
                disabledForegroundColor: colors.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEndDrawer(BuildContext context) {
    var controller = Provider.of<ComicDetailPageController>(context);
    final colors = Theme.of(context).colorScheme;
    return Drawer(
      width: MediaQuery.of(context).size.width * 0.9,
      backgroundColor: colors.surfaceContainerLow,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(left: Radius.circular(16)),
      ),
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: (colors.brightness == Brightness.dark
                ? SystemUiOverlayStyle.light
                : SystemUiOverlayStyle.dark)
            .copyWith(statusBarColor: Colors.transparent),
        child: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 4, 16, 0),
                child: Row(
                  children: [
                    const BackButton(),
                    Expanded(
                      child: Text(
                        S.of(context).ComicDetailPageComments,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
              Divider(
                height: 1,
                thickness: 1,
                color: colors.outlineVariant,
              ),
              Expanded(
                  child: EasyRefresh(
                      header: const ClassicHeader(
                        safeArea: false,
                        showMessage: false,
                        textStyle: TextStyle(fontSize: 12),
                      ),
                      refreshOnStart: true,
                      onRefresh: () async {
                        await Provider.of<ComicDetailPageController>(context,
                                listen: false)
                            .refreshComment();
                      },
                      onLoad: () async {
                        await Provider.of<ComicDetailPageController>(context,
                                listen: false)
                            .loadComment();
                      },
                      child: ListView.builder(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: controller.comments.length,
                          itemBuilder: (context, index) {
                            var item = controller.comments[index];
                            return CommentCard(
                              avatar: item.avatar,
                              nickname: item.nickname,
                              comment: item.comment,
                              subComments: item.subComments,
                            );
                          }))),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailCoverHeaderDelegate extends SliverPersistentHeaderDelegate {
  @override
  final double minExtent;
  @override
  final double maxExtent;
  final double toolbarExtent;
  final double compactExtent;
  final String title;
  final Size compactCoverSize;
  final Widget cover;
  final Widget details;

  _DetailCoverHeaderDelegate({
    required this.minExtent,
    required this.maxExtent,
    required this.toolbarExtent,
    required this.compactExtent,
    required this.title,
    required this.compactCoverSize,
    required this.cover,
    required this.details,
  });

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    final collapseDistance = maxExtent - compactExtent;
    final progress = (shrinkOffset / collapseDistance).clamp(0.0, 1.0);
    final contentScroll =
        (shrinkOffset - collapseDistance).clamp(0.0, compactExtent - minExtent);
    final contentHidden = contentScroll >= compactExtent - minExtent;
    final colors = Theme.of(context).colorScheme;
    final detailsOpacity =
        Curves.easeOut.transform(((progress - 0.85) / 0.15).clamp(0.0, 1.0));
    final toolbarProgress = ((progress - 0.55) / 0.45).clamp(0.0, 1.0);
    final background = colors.surface;
    return ClipRect(
      child: ColoredBox(
        color: background,
        child: LayoutBuilder(builder: (context, constraints) {
          final coverRect = Rect.lerp(
            Rect.fromLTWH(0, 0, constraints.maxWidth, maxExtent),
            Offset(16, toolbarExtent + 12) & compactCoverSize,
            progress,
          )!
              .shift(Offset(0, -contentScroll));
          final titleStyle = Theme.of(context).textTheme.titleLarge!;
          final titleFontSize = titleStyle.fontSize! + 4 * (1 - progress);
          final titleTextScaler =
              MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 2);
          final titleHeight = titleTextScaler.scale(titleFontSize) * 1.25;
          final expandedTitleTop = maxExtent - titleHeight - 20;
          final collapsedTitleTop =
              toolbarExtent - (kToolbarHeight + titleHeight) / 2;
          final titleTop = expandedTitleTop +
              (collapsedTitleTop - expandedTitleTop) * progress;
          final titleInset = 16 + 40 * progress;
          final useLightForeground = colors.brightness == Brightness.dark;
          return Stack(
            fit: StackFit.expand,
            children: [
              Positioned.fromRect(
                rect: coverRect,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10 * progress),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      cover,
                      if (progress < 1)
                        Opacity(
                          opacity: 1 - progress,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  colors.surface.withValues(alpha: 0),
                                  colors.surface.withValues(alpha: 0),
                                  colors.surface,
                                ],
                                stops: [0, 0.5, 1],
                              ),
                            ),
                          ),
                        ),
                      if (toolbarProgress < 1)
                        Positioned(
                          top: -coverRect.top,
                          left: 0,
                          right: 0,
                          height: toolbarExtent + 48,
                          child: IgnorePointer(
                            child: Opacity(
                              opacity: 1 - toolbarProgress,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      colors.surface.withValues(alpha: 0.75),
                                      colors.surface.withValues(alpha: 0.55),
                                      colors.surface.withValues(alpha: 0),
                                    ],
                                    stops: [
                                      0,
                                      toolbarExtent / (toolbarExtent + 48),
                                      1
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              if (detailsOpacity > 0)
                Positioned(
                  left: coverRect.right + 12,
                  right: 16,
                  top: math.max(
                          toolbarExtent + 12, titleTop + titleHeight + 12) -
                      contentScroll,
                  child: IgnorePointer(
                    ignoring: progress < 0.95 || contentHidden,
                    child: ExcludeSemantics(
                      excluding: progress < 0.95 || contentHidden,
                      child: Opacity(opacity: detailsOpacity, child: details),
                    ),
                  ),
                ),
              if (progress == 1)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: toolbarExtent,
                  child: ColoredBox(color: colors.surface),
                ),
              Positioned(
                top: titleTop,
                left: titleInset,
                right: titleInset,
                child: IgnorePointer(
                  child: Semantics(
                    header: true,
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textScaler: titleTextScaler,
                      style: titleStyle.copyWith(
                        fontSize: titleFontSize,
                        height: 1.25,
                        color: colors.onSurface,
                        shadows: progress < 1
                            ? [
                                Shadow(
                                  color: colors.surface,
                                  blurRadius: 6,
                                  offset: const Offset(0, 1),
                                ),
                              ]
                            : null,
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: toolbarExtent,
                child: AppBar(
                  backgroundColor: Colors.transparent,
                  forceMaterialTransparency: true,
                  foregroundColor: colors.onSurface,
                  leading: const BackButton(),
                  actions: const [EndDrawerButton()],
                  systemOverlayStyle: SystemUiOverlayStyle(
                    statusBarColor: Colors.transparent,
                    statusBarIconBrightness:
                        useLightForeground ? Brightness.light : Brightness.dark,
                    statusBarBrightness:
                        useLightForeground ? Brightness.dark : Brightness.light,
                  ),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _DetailCoverHeaderDelegate oldDelegate) =>
      minExtent != oldDelegate.minExtent ||
      maxExtent != oldDelegate.maxExtent ||
      toolbarExtent != oldDelegate.toolbarExtent ||
      compactExtent != oldDelegate.compactExtent ||
      title != oldDelegate.title ||
      compactCoverSize != oldDelegate.compactCoverSize ||
      cover != oldDelegate.cover ||
      details != oldDelegate.details;
}
