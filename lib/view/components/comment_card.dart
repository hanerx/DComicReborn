import 'package:dcomic/utils/image_utils.dart';
import 'package:dcomic/view/components/dcomic_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class CommentCard extends StatelessWidget {
  final ImageEntity avatar;
  final String nickname;
  final String comment;

  const CommentCard(
      {super.key,
      required this.avatar,
      required this.nickname,
      required this.comment});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: ListTile(
        dense: true,
        leading: SizedBox(
          height: 50,
          width: 50,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: DComicImage(avatar,
                errorMessageOverflow: TextOverflow.ellipsis,showErrorMessage: false,errorLogoSize: 48,fit: BoxFit.cover,),
          ),
        ),
        title: Text(nickname),
        subtitle: Text(comment),
      ),
    );
  }
}
