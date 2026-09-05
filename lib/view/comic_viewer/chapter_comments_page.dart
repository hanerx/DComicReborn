import 'package:dcomic/generated/l10n.dart';
import 'package:dcomic/providers/models/comic_source_model.dart';
import 'package:dcomic/view/components/dcomic_image.dart';
import 'package:flutter/material.dart';

/// A single reader page; scrolling continues through the reader, not the preview.
class ChapterCommentsPage extends StatefulWidget {
  const ChapterCommentsPage({
    super.key,
    required this.comments,
    required this.onShowMore,
    required this.onShowToolbar,
  });

  final List<ChapterCommentEntity> comments;
  final VoidCallback onShowMore;
  final VoidCallback onShowToolbar;

  @override
  State<ChapterCommentsPage> createState() => _ChapterCommentsPageState();
}

class _ChapterCommentsPageState extends State<ChapterCommentsPage> {
  bool _hasOverflow = false;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surface,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(S.of(context).ComicViewerPageChapterComments,
                      style: Theme.of(context).textTheme.titleMedium),
                ),
                IconButton(
                  iconSize: 20,
                  onPressed: widget.onShowToolbar,
                  tooltip: MaterialLocalizations.of(context).showMenuTooltip,
                  icon: const Icon(Icons.menu),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Expanded(
              child: widget.comments.isEmpty
                  ? Center(child: Text(S.of(context).ComicViewerPageNoComments))
                  : NotificationListener<ScrollMetricsNotification>(
                      onNotification: (notification) {
                        final overflow =
                            notification.metrics.maxScrollExtent > 0;
                        if (overflow != _hasOverflow) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (mounted && overflow != _hasOverflow) {
                              setState(() => _hasOverflow = overflow);
                            }
                          });
                        }
                        return false;
                      },
                      child: SingleChildScrollView(
                        primary: false,
                        physics: const NeverScrollableScrollPhysics(),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (final comment in widget.comments)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: colors.surfaceContainerHighest,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 6),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        if (comment.avatar != null) ...[
                                          CircleAvatar(
                                            radius: 12,
                                            child: ClipOval(
                                                child: DComicImage(
                                                    comment.avatar!)),
                                          ),
                                          const SizedBox(width: 6),
                                        ],
                                        Expanded(
                                          child: Text(comment.comment,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodySmall),
                                        ),
                                        const SizedBox(width: 6),
                                        Icon(Icons.thumb_up_outlined,
                                            size: 12,
                                            color: colors.onSurfaceVariant),
                                        const SizedBox(width: 4),
                                        Text('${comment.likes}',
                                            style: Theme.of(context)
                                                .textTheme
                                                .labelSmall),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
            ),
            // Keep this space stable so the button cannot cause its own overflow.
            if (widget.comments.isNotEmpty)
              SizedBox(
                height: 48,
                child: _hasOverflow
                    ? Center(
                        child: TextButton.icon(
                          onPressed: widget.onShowMore,
                          icon: const Icon(Icons.more_horiz),
                          label: Text(S.of(context).ComicViewerPageShowMore),
                        ),
                      )
                    : null,
              ),
          ],
        ),
      ),
    );
  }
}
