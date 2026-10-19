import 'package:dcomic/providers/models/comic_source_model.dart';
import 'package:dcomic/providers/navigator_provider.dart';
import 'package:dcomic/providers/page_controllers/comic_topic_page_controller.dart';
import 'package:dcomic/utils/layout_utils.dart';
import 'package:dcomic/view/topic_pages/comic_topic_detail_page.dart';
import 'package:dcomic/view/topic_pages/topic_page_widgets.dart';
import 'package:easy_refresh/easy_refresh.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class ComicTopicListPage extends StatelessWidget {
  const ComicTopicListPage({super.key, required this.sourceModel});

  final BaseComicSourceModel sourceModel;

  static Future<void> open(
    BuildContext context, {
    required BaseComicSourceModel sourceModel,
  }) async {
    final navigator = context.read<NavigatorProvider>().getNavigator(
      context,
      NavigatorType.defaultNavigator,
    );
    if (navigator == null) return;
    await navigator.push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ComicTopicListPage(sourceModel: sourceModel),
        settings: const RouteSettings(name: 'ComicTopicListPage'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) {
        final controller = ComicTopicListPageController(sourceModel);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          controller.refresh();
        });
        return controller;
      },
      child: ListenableBuilder(
        listenable: sourceModel,
        builder: (context, _) {
          return Scaffold(
            appBar: AppBar(title: Text(topicPageText(context, '专题', 'Topics'))),
            backgroundColor: Theme.of(context).colorScheme.surface,
            body: Consumer<ComicTopicListPageController>(
              builder: (context, controller, _) => _TopicListBody(
                sourceModel: sourceModel,
                controller: controller,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _TopicListBody extends StatelessWidget {
  const _TopicListBody({required this.sourceModel, required this.controller});

  final BaseComicSourceModel sourceModel;
  final ComicTopicListPageController controller;

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
    if (!controller.hasLoaded && controller.topics.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (controller.failedToLoadMore && controller.topics.isEmpty) {
      return EasyRefresh(
        onRefresh: controller.isLoading ? null : () => _refresh(context),
        onLoad: controller.isLoading ? null : () => _load(context),
        child: TopicPageMessage(
          icon: Icons.sync_problem_rounded,
          title: topicPageText(
            context,
            '加载更多专题失败',
            'Could not load more topics',
          ),
          message: topicPageText(
            context,
            '已保留当前分页位置，请重试加载。下拉刷新将从第一页重新开始。',
            'The current page is ready to retry. Pull down to start again.',
          ),
          actionLabel: topicPageText(context, '重试加载', 'Retry load'),
          onAction: controller.isLoading ? null : controller.loadMore,
        ),
      );
    }

    if (controller.hasError && controller.topics.isEmpty) {
      return TopicPageMessage(
        icon: Icons.cloud_off_rounded,
        title: topicPageText(context, '专题加载失败', 'Could not load topics'),
        message: topicPageText(
          context,
          '无法从此漫画源获取专题，请重试。',
          'Topics could not be loaded from this source.',
        ),
        actionLabel: topicPageText(context, '重试', 'Retry'),
        onAction: controller.isLoading ? null : controller.refresh,
      );
    }

    if (controller.topics.isEmpty) {
      final canLoad = controller.hasMore && !controller.isLoading;
      return EasyRefresh(
        onRefresh: controller.isLoading ? null : () => _refresh(context),
        onLoad: canLoad ? () => _load(context) : null,
        child: TopicPageMessage(
          icon: Icons.collections_bookmark_outlined,
          title: topicPageText(context, '本页暂无专题', 'No topics on this page'),
          message: controller.hasMore
              ? topicPageText(
                  context,
                  '可继续加载下一页，或下拉刷新。',
                  'Load the next page, or pull down to refresh.',
                )
              : topicPageText(
                  context,
                  '此漫画源目前没有可显示的专题，可下拉刷新。',
                  'This source has no topics to show. Pull down to refresh.',
                ),
          actionLabel: controller.hasMore
              ? topicPageText(context, '加载更多', 'Load more')
              : null,
          onAction: canLoad ? controller.loadMore : null,
        ),
      );
    }

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
          child: LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 760 ? 2 : 1;
              final rows = (controller.topics.length / columns).ceil();
              return ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                itemCount: rows + 1,
                itemBuilder: (context, row) {
                  if (row == rows) {
                    return TopicPageFooter(
                      isLoading: controller.isLoading,
                      failedToLoadMore: controller.failedToLoadMore,
                      hasError: controller.hasError,
                      hasMore: controller.hasMore,
                      hasItems: controller.topics.isNotEmpty,
                      onRetryRefresh: controller.refresh,
                      onLoadMore: controller.loadMore,
                    );
                  }
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (var column = 0; column < columns; column++) ...[
                          if (column > 0) const SizedBox(width: 20),
                          Expanded(
                            child:
                                row * columns + column >=
                                    controller.topics.length
                                ? const SizedBox.shrink()
                                : _buildTopic(context, row * columns + column),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildTopic(BuildContext context, int index) {
    final topic = controller.topics[index];
    return ComicTopicBanner(
      topic: topic,
      sourceModel: sourceModel,
      onTap: () => ComicTopicDetailPage.open(
        context,
        sourceModel: sourceModel,
        topicId: topic.id,
        title: topic.title,
      ),
    );
  }
}
