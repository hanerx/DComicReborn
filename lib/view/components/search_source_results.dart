import 'package:dcomic/providers/models/comic_source_model.dart';
import 'package:dcomic/providers/page_controllers/comic_search_page_controller.dart';
import 'package:dcomic/utils/layout_utils.dart';
import 'package:dcomic/view/components/card_list_item.dart';
import 'package:easy_refresh/easy_refresh.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Displays one source's independent search and pagination state.
class SearchSourceResults extends StatelessWidget {
  final BaseComicSourceModel source;

  const SearchSourceResults({super.key, required this.source});

  String _text(BuildContext context, String zh, String en) =>
      Localizations.localeOf(context).languageCode == 'zh' ? zh : en;

  Future<IndicatorResult> _refresh(
    BuildContext context,
    ComicSearchPageController controller,
  ) async {
    await controller.refresh(source);
    if (!context.mounted) return IndicatorResult.fail;
    final state = controller.data[source];
    return state == null || (state.hasError && !state.failedToLoadMore)
        ? IndicatorResult.fail
        : IndicatorResult.success;
  }

  Future<IndicatorResult> _load(
    BuildContext context,
    ComicSearchPageController controller,
  ) async {
    await controller.load(source);
    if (!context.mounted) return IndicatorResult.fail;
    final state = controller.data[source];
    return state == null || state.failedToLoadMore
        ? IndicatorResult.fail
        : IndicatorResult.success;
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ComicSearchPageController>();
    final state = controller.data[source];
    if (state == null) {
      return _MessageList(
        icon: Icons.source_outlined,
        title: _text(context, '漫画源已发生变化', 'The source list changed'),
        message: _text(
          context,
          '请返回后重新打开搜索页。',
          'Reopen search to use the updated sources.',
        ),
      );
    }

    if (state.isLoading && state.data.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.hasError && state.data.isEmpty) {
      return _MessageList(
        icon: Icons.cloud_off_rounded,
        title: _text(context, '搜索失败', 'Search failed'),
        message: _text(
          context,
          '无法从此漫画源获取结果，请重试。',
          'Results could not be loaded from this source.',
        ),
        actionLabel: _text(context, '重试', 'Retry'),
        onAction: state.isLoading ? null : () => controller.refresh(source),
      );
    }

    if (state.hasSearched && state.data.isEmpty) {
      return EasyRefresh(
        onRefresh: state.isLoading ? null : () => _refresh(context, controller),
        child: _MessageList(
          icon: Icons.search_off_rounded,
          title: _text(context, '没有找到结果', 'No results found'),
          message: _text(
            context,
            '试试其他关键词，或下拉刷新。',
            'Try another keyword or pull to refresh.',
          ),
        ),
      );
    }

    return EasyRefresh(
      onRefresh: state.hasSearched && !state.isLoading
          ? () => _refresh(context, controller)
          : null,
      onLoad: state.hasMore && !state.isLoading && !state.hasError
          ? () => _load(context, controller)
          : null,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AppLayout.contentMaxWidth,
          ),
          child: ListView.builder(
            key: PageStorageKey<Object>(state.scrollIdentity),
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(top: 4, bottom: 20),
            itemCount: state.data.length + 1,
            itemBuilder: (context, index) {
              if (index < state.data.length) {
                final entity = state.data[index];
                return CardListItem(
                  cover: entity.cover,
                  title: entity.title,
                  details: entity.details,
                  onTap: entity.onTap,
                );
              }
              return _ResultsFooter(
                state: state,
                onRetryRefresh: () => controller.refresh(source),
                onRetryLoad: () => controller.load(source),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ResultsFooter extends StatelessWidget {
  final ComicSearchPageData state;
  final VoidCallback onRetryRefresh;
  final VoidCallback onRetryLoad;

  const _ResultsFooter({
    required this.state,
    required this.onRetryRefresh,
    required this.onRetryLoad,
  });

  String _text(BuildContext context, String zh, String en) =>
      Localizations.localeOf(context).languageCode == 'zh' ? zh : en;

  @override
  Widget build(BuildContext context) {
    if (state.isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: SizedBox.square(
            dimension: 24,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
        ),
      );
    }

    if (state.failedToLoadMore) {
      return _RetryFooter(
        icon: Icons.sync_problem_rounded,
        text: _text(context, '加载更多失败', 'Could not load more'),
        buttonText: _text(context, '重试', 'Retry'),
        onPressed: onRetryLoad,
      );
    }

    if (state.hasError) {
      return _RetryFooter(
        icon: Icons.info_outline_rounded,
        text: _text(
          context,
          '刷新失败，已保留现有结果',
          'Refresh failed; existing results were kept',
        ),
        buttonText: _text(context, '重试刷新', 'Retry refresh'),
        onPressed: onRetryRefresh,
      );
    }

    if (!state.hasMore && state.data.isNotEmpty) {
      final colors = Theme.of(context).colorScheme;
      return Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
        child: Row(
          children: [
            Expanded(child: Divider(color: colors.outlineVariant)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                _text(context, '没有更多结果', 'No more results'),
                style: Theme.of(context).textTheme.labelMedium
                    ?.copyWith(color: colors.onSurfaceVariant),
              ),
            ),
            Expanded(child: Divider(color: colors.outlineVariant)),
          ],
        ),
      );
    }

    return const SizedBox(height: 12);
  }
}

class _RetryFooter extends StatelessWidget {
  final IconData icon;
  final String text;
  final String buttonText;
  final VoidCallback onPressed;

  const _RetryFooter({
    required this.icon,
    required this.text,
    required this.buttonText,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Material(
        color: colors.errorContainer,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Icon(icon, color: colors.onErrorContainer),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(color: colors.onErrorContainer),
                ),
              ),
              TextButton(onPressed: onPressed, child: Text(buttonText)),
            ],
          ),
        ),
      ),
    );
  }
}

class _MessageList extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _MessageList({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 52, color: colors.onSurfaceVariant),
                    const SizedBox(height: 16),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    if (actionLabel != null) ...[
                      const SizedBox(height: 20),
                      FilledButton.tonalIcon(
                        onPressed: onAction,
                        icon: const Icon(Icons.refresh_rounded),
                        label: Text(actionLabel!),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
