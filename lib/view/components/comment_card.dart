import 'package:dcomic/providers/models/comic_source_model.dart';
import 'package:dcomic/utils/image_utils.dart';
import 'package:dcomic/view/components/dcomic_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:folding_cell/folding_cell.dart';

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
    if (subComments.isEmpty) {
      return Card(
          elevation: 0,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 65),
            child: ListTile(
              dense: true,
              leading: SizedBox(
                height: 50,
                width: 50,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(5),
                  child: DComicImage(
                    avatar,
                    errorMessageOverflow: TextOverflow.ellipsis,
                    showErrorMessage: false,
                    errorLogoSize: 48,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              title: Text(nickname),
              subtitle: CommentText(comment),
              isThreeLine: true,
            ),
          ));
    }
    return Card(
        elevation: 0,
        child: Column(
          children: [
            ListTile(
              dense: true,
              leading: SizedBox(
                height: 50,
                width: 50,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(5),
                  child: DComicImage(
                    avatar,
                    errorMessageOverflow: TextOverflow.ellipsis,
                    showErrorMessage: false,
                    errorLogoSize: 48,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              title: Text(nickname),
              subtitle: CommentText(comment),
              isThreeLine: true,
            ),
            ListTile(
              dense: true,
              title: Card(
                elevation: 0,
                margin: EdgeInsets.zero,
                color: Theme.of(context).colorScheme.primaryContainer,
                child: Column(
                  children: ListTile.divideTiles(
                          context: context,
                          tiles: subComments
                              .map<Widget>((e) => ConstrainedBox(
                                  constraints:
                                      const BoxConstraints(minHeight: 65),
                                  child: ListTile(
                                    dense: true,
                                    subtitle: CommentText(e.comment),
                                    title: Text(e.nickname),
                                    isThreeLine: true,
                                    leading: SizedBox(
                                      height: 50,
                                      width: 50,
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(5),
                                        child: DComicImage(
                                          e.avatar,
                                          errorMessageOverflow:
                                              TextOverflow.ellipsis,
                                          showErrorMessage: false,
                                          errorLogoSize: 48,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    ),
                                  )))
                              .toList())
                      .toList(),
                ),
              ),
            )
          ],
        ));
  }
}
