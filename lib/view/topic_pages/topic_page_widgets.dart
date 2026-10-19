import 'package:dcomic/providers/models/comic_source_model.dart';
import 'package:dcomic/providers/models/comic_topic_model.dart';
import 'package:dcomic/view/components/dcomic_image.dart';
import 'package:flutter/material.dart';

String topicPageText(BuildContext context, String zh, String en) =>
    Localizations.localeOf(context).languageCode == 'zh' ? zh : en;

class ComicTopicBanner extends StatelessWidget {
  const ComicTopicBanner({
    super.key,
    required this.topic,
    required this.sourceModel,
    required this.onTap,
  });

  final ComicTopic topic;
  final BaseComicSourceModel sourceModel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final description = sourceModel.formatDisplayText(topic.description);
    return Material(
      color: colors.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: colors.outlineVariant.withValues(alpha: 0.5)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _TopicCover(topic: topic),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _TopicMetadata(topic: topic, sourceModel: sourceModel),
                  const SizedBox(height: 10),
                  Text(
                    sourceModel.formatDisplayText(topic.title),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      height: 1.4,
                    ),
                  ),
                  if (description.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colors.onSurfaceVariant,
                        height: 1.5,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Text(
                        topicPageText(context, '浏览书单', 'Explore collection'),
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: colors.primary,
                        ),
                      ),
                      const Spacer(),
                      Icon(
                        Icons.arrow_forward_rounded,
                        size: 19,
                        color: colors.primary,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ComicTopicHeader extends StatelessWidget {
  const ComicTopicHeader({
    super.key,
    required this.topic,
    required this.sourceModel,
  });

  final ComicTopic topic;
  final BaseComicSourceModel sourceModel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final description = sourceModel.formatDisplayText(topic.description);
    final cover = ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: _TopicCover(topic: topic),
    );
    final introduction = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _TopicMetadata(topic: topic, sourceModel: sourceModel),
        const SizedBox(height: 14),
        Text(
          sourceModel.formatDisplayText(topic.title),
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
            height: 1.35,
          ),
        ),
        if (description.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            description,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.75,
            ),
          ),
        ],
      ],
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 760) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 5, child: cover),
              const SizedBox(width: 28),
              Expanded(flex: 6, child: introduction),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [cover, const SizedBox(height: 24), introduction],
        );
      },
    );
  }
}

class TopicComicTile extends StatelessWidget {
  const TopicComicTile({
    super.key,
    required this.comic,
    required this.sourceModel,
    required this.index,
    required this.onTap,
  });

  final TopicComic comic;
  final BaseComicSourceModel sourceModel;
  final int index;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final description = sourceModel.formatDisplayText(comic.description);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 88,
                  height: 124,
                  child: DComicImage(
                    comic.cover,
                    fit: BoxFit.cover,
                    showErrorMessage: false,
                    errorLogoSize: 28,
                  ),
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          (index + 1).toString().padLeft(2, '0'),
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: colors.primary,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const Spacer(),
                        Icon(
                          Icons.arrow_outward_rounded,
                          size: 16,
                          color: colors.onSurfaceVariant,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      sourceModel.formatDisplayText(comic.title),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        height: 1.4,
                      ),
                    ),
                    if (description.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        description,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          height: 1.6,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopicCover extends StatelessWidget {
  const _TopicCover({required this.topic});
  final ComicTopic topic;

  @override
  Widget build(BuildContext context) => AspectRatio(
    aspectRatio: 5 / 2,
    child: DComicImage(
      topic.cover,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      showErrorMessage: false,
      errorLogoSize: 36,
    ),
  );
}

class _TopicMetadata extends StatelessWidget {
  const _TopicMetadata({required this.topic, required this.sourceModel});
  final ComicTopic topic;
  final BaseComicSourceModel sourceModel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Text(
              sourceModel.formatDisplayText(sourceModel.type.sourceName),
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        if (topic.date.isNotEmpty)
          Text(
            topic.date,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
      ],
    );
  }
}

class TopicPageMessage extends StatelessWidget {
  const TopicPageMessage({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

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

class TopicPageFooter extends StatelessWidget {
  const TopicPageFooter({
    super.key,
    required this.isLoading,
    required this.failedToLoadMore,
    required this.hasError,
    required this.hasMore,
    required this.hasItems,
    required this.onRetryRefresh,
    required this.onLoadMore,
  });

  final bool isLoading;
  final bool failedToLoadMore;
  final bool hasError;
  final bool hasMore;
  final bool hasItems;
  final VoidCallback onRetryRefresh;
  final VoidCallback onLoadMore;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
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
    if (failedToLoadMore) {
      return _TopicRetryFooter(
        icon: Icons.sync_problem_rounded,
        text: topicPageText(context, '加载更多失败', 'Could not load more'),
        buttonText: topicPageText(context, '重试', 'Retry'),
        onPressed: onLoadMore,
      );
    }
    if (hasError) {
      return _TopicRetryFooter(
        icon: Icons.info_outline_rounded,
        text: topicPageText(
          context,
          '刷新失败，已保留现有内容',
          'Refresh failed; existing content was kept',
        ),
        buttonText: topicPageText(context, '重试刷新', 'Retry refresh'),
        onPressed: onRetryRefresh,
      );
    }
    if (hasMore) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        child: Center(
          child: FilledButton.tonalIcon(
            onPressed: onLoadMore,
            icon: const Icon(Icons.expand_more_rounded),
            label: Text(topicPageText(context, '加载更多', 'Load more')),
          ),
        ),
      );
    }
    if (!hasItems) return const SizedBox(height: 12);

    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
      child: Row(
        children: [
          Expanded(child: Divider(color: colors.outlineVariant)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              topicPageText(context, '没有更多内容', 'No more items'),
              style: Theme.of(context).textTheme.labelMedium
                  ?.copyWith(color: colors.onSurfaceVariant),
            ),
          ),
          Expanded(child: Divider(color: colors.outlineVariant)),
        ],
      ),
    );
  }
}

class _TopicRetryFooter extends StatelessWidget {
  const _TopicRetryFooter({
    required this.icon,
    required this.text,
    required this.buttonText,
    required this.onPressed,
  });

  final IconData icon;
  final String text;
  final String buttonText;
  final VoidCallback onPressed;

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
