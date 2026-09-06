import 'package:dcomic/providers/models/comic_source_model.dart';
import 'package:dcomic/utils/image_utils.dart';
import 'package:dcomic/view/components/dcomic_image.dart';
import 'package:flutter/material.dart';

class CommentText extends StatefulWidget {
  final String text;

  const CommentText(this.text, {super.key});

  @override
  State<StatefulWidget> createState() => _CommentTextState();
}

class _CommentTextState extends State<CommentText> {
  bool expand = false;

  @override
  Widget build(BuildContext context) {
    if (widget.text.length > 20) {
      return GestureDetector(
          onTap: () {
            setState(() {
              expand = !expand;
            });
          },
          child: Text(
            widget.text,
            maxLines: expand ? null : 2,
            overflow: expand ? null : TextOverflow.ellipsis,
          ));
    } else {
      return Text(widget.text);
    }
  }
}

class _CommentEntry extends StatelessWidget {
  final ImageEntity avatar;
  final String nickname;
  final String comment;
  final double avatarSize;
  final double avatarRadius;
  final double errorLogoSize;
  final bool dense;

  const _CommentEntry(
      {required this.avatar,
      required this.nickname,
      required this.comment,
      required this.avatarSize,
      required this.avatarRadius,
      required this.errorLogoSize,
      this.dense = false});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: avatarSize,
          width: avatarSize,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(avatarRadius),
            child: DComicImage(
              avatar,
              errorMessageOverflow: TextOverflow.ellipsis,
              showErrorMessage: false,
              errorLogoSize: errorLogoSize,
              fit: BoxFit.cover,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(nickname,
                  style: (dense ? textTheme.labelMedium : textTheme.titleSmall)
                      ?.copyWith(
                          color: colors.onSurfaceVariant,
                          fontWeight: dense ? null : FontWeight.w600)),
              const SizedBox(height: 2),
              DefaultTextStyle(
                style: (dense ? textTheme.bodySmall : textTheme.bodyMedium)!
                    .copyWith(color: colors.onSurface),
                child: CommentText(comment),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class CommentCard extends StatelessWidget {
  final ImageEntity avatar;
  final String nickname;
  final String comment;
  final List<ComicCommentEntity> subComments;

  const CommentCard(
      {super.key,
      required this.avatar,
      required this.nickname,
      required this.comment,
      required this.subComments});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CommentEntry(
              avatar: avatar,
              nickname: nickname,
              comment: comment,
              avatarSize: 40,
              avatarRadius: 10,
              errorLogoSize: 36),
          if (subComments.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              margin: const EdgeInsets.only(left: 8),
              padding: const EdgeInsets.only(left: 12),
              decoration: BoxDecoration(
                  border: Border(
                      left:
                          BorderSide(color: colors.outlineVariant, width: 2))),
              child: Column(
                children: [
                  for (final reply in subComments)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: _CommentEntry(
                          avatar: reply.avatar,
                          nickname: reply.nickname,
                          comment: reply.comment,
                          avatarSize: 28,
                          avatarRadius: 8,
                          errorLogoSize: 24,
                          dense: true),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
