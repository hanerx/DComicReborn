import 'package:dcomic/providers/models/comic_source_model.dart';
import 'package:dcomic/providers/navigator_provider.dart';
import 'package:dcomic/providers/page_controllers/comic_topic_page_controller.dart';
import 'package:dcomic/utils/layout_utils.dart';
import 'package:dcomic/view/comic_pages/comic_detail_page.dart';
import 'package:dcomic/view/topic_pages/topic_page_widgets.dart';
import 'package:easy_refresh/easy_refresh.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class ComicTopicDetailPage extends StatelessWidget {
  const ComicTopicDetailPage({
    super.key,
    required this.sourceModel,
    required this.topicId,
    this.title,
  });

  final BaseComicSourceModel sourceModel;
  final String topicId;
  final String? title;

  static Future<void> open(
    BuildContext context, {
    required BaseComicSourceModel sourceModel,
    required String topicId,
    String? title,
  }) async {
    final navigator = context.read<NavigatorProvider>().getNavigator(
      context,
      NavigatorType.defaultNavigator,
    );
    if (navigator == null) return;
    await navigator.push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ComicTopicDetailPage(
          sourceModel: sourceModel,
          topicId: topicId,
          title: title,
        ),
        settings: const RouteSettings(name: 'ComicTopicDetailPage'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) {
        final controller = ComicTopicDetailPageController(sourceModel, topicId);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          controller.refresh();
        });
        return controller;
      },
      child: ListenableBuilder(
        listenable: sourceModel,
        builder: (context, _) {
          return Consumer<ComicTopicDetailPageController>(
            builder: (context, controller, _) {
              final rawTitle = controller.topic?.title ?? title;
              return Scaffold(
                appBar: AppBar(
                  title: Text(
                    rawTitle == null || rawTitle.isEmpty
                        ? topicPageText(context, '专题详情', 'Topic details')
                        : sourceModel.formatDisplayText(rawTitle),
                  ),
                ),
                backgroundColor: Theme.of(context).colorScheme.surface,
                body: _TopicDetailBody(
                  sourceModel: sourceModel,
                  controller: controller,
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _TopicDetailBody extends StatelessWidget {
  const _TopicDetailBody({required this.sourceModel, required this.controller});

  final BaseComicSourceModel sourceModel;
  final ComicTopicDetailPageController controller;

  Future<IndicatorResult> _refresh(BuildContext context) async {
    await controller.refresh();
    if (!context.mounted) return IndicatorResult.fail;
    return controller.hasError && !controller.failedToLoadMore
        ? IndicatorResult.fail
        : IndicatorResult.success;
  }

  Future<IndicatorResult> _load(BuildContext context) async {
    await controller.loadMore();
    if (!context.mounted) return IndicatorResult.fail;
    return controller.failedToLoadMore
        ? IndicatorResult.fail
        : IndicatorResult.success;
  }

  @override
  Widget build(BuildContext context) {
    final topic = controller.topic;
    if (!controller.hasLoaded && topic == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (controller.hasError && topic == null) {
      return TopicPageMessage(
        icon: Icons.cloud_off_rounded,
        title: topicPageText(
          context,
          '专题详情加载失败',
          'Could not load topic details',
        ),
        message: topicPageText(
          context,
          '无法获取此专题，请重试。',
          'This topic could not be loaded. Please try again.',
        ),
        actionLabel: topicPageText(context, '重试', 'Retry'),
        onAction: controller.isLoading ? null : controller.refresh,
      );
    }
    if (topic == null) {
      return TopicPageMessage(
        icon: Icons.info_outline_rounded,
        title: topicPageText(context, '专题不可用', 'Topic unavailable'),
        message: topicPageText(
          context,
          '漫画源未返回此专题的详细信息。',
          'The source did not return details for this topic.',
        ),
        actionLabel: topicPageText(context, '重试', 'Retry'),
        onAction: controller.refresh,
      );
    }

    final hasNoComics = controller.comics.isEmpty;
    final footerIndex = controller.comics.length + 2 + (hasNoComics ? 1 : 0);
    final canLoad =
        controller.hasMore &&
        !controller.isLoading &&
        (!controller.hasError || controller.failedToLoadMore);
    return EasyRefresh(
      onRefresh: controller.isLoading ? null : () => _refresh(context),
      onLoad: canLoad ? () => _load(context) : null,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AppLayout.contentMaxWidth,
          ),
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            itemCount: footerIndex + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return ComicTopicHeader(topic: topic, sourceModel: sourceModel);
              }
              if (index == 1) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(4, 32, 4, 8),
                  child: Row(
                    children: [
                      Container(
                        width: 4,
                        height: 20,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          topicPageText(context, '推荐漫画', 'Recommended comics'),
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                );
              }
              if (hasNoComics && index == 2) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 28),
                  child: Column(
                    children: [
                      Icon(
                        Icons.menu_book_outlined,
                        size: 42,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        topicPageText(
                          context,
                          '此专题暂无推荐漫画',
                          'No comics are recommended yet',
                        ),
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ],
                  ),
                );
              }
              if (index == footerIndex) {
                return TopicPageFooter(
                  isLoading: controller.isLoading,
                  failedToLoadMore: controller.failedToLoadMore,
                  hasError: controller.hasError,
                  hasMore: controller.hasMore,
                  hasItems: controller.comics.isNotEmpty,
                  onRetryRefresh: controller.refresh,
                  onLoadMore: controller.loadMore,
                );
              }

              final comicIndex = index - 2;
              final comic = controller.comics[comicIndex];
              return Column(
                children: [
                  if (comicIndex > 0)
                    Divider(
                      height: 1,
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  TopicComicTile(
                    comic: comic,
                    sourceModel: sourceModel,
                    index: comicIndex,
                    onTap: () => ComicDetailPage.open(
                      context,
                      comicId: comic.id,
                      title: comic.title,
                      comicSourceModel: sourceModel,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
