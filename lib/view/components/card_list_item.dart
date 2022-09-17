import 'package:dcomic/utils/image_utils.dart';
import 'package:dcomic/view/components/dcomic_image.dart';
import 'package:flutter/material.dart';

class CardListItem extends StatelessWidget {
  final String title;
  final Map<IconData, String> details;
  final void Function(BuildContext context)? onTap;
  final ImageEntity cover;

  const CardListItem(
      {super.key,
      required this.title,
      required this.details,
      this.onTap,
      required this.cover});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap == null
            ? null
            : () {
                onTap!(context);
              },
        child: Card(
          margin: EdgeInsets.only(left: 3,right: 3),
          color: Colors.transparent,
          elevation: 0,
          child: Row(
            children: [
              Expanded(
                  flex: 1,
                  child: Card(
                    elevation: 0,
                    child: ClipRRect(
                      borderRadius: const BorderRadius.all(Radius.circular(3)),
                      child: DComicImage(
                        cover,
                        fit: BoxFit.fill,
                      ),
                    ),
                  )),
              Expanded(
                  flex: 3,
                  child: Card(
                    elevation: 0,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(10, 3, 3, 3),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: _buildDetails(context),
                      ),
                    ),
                  ))
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildDetails(BuildContext context) {
    List<Widget> data = [
      Expanded(
          flex: 3,
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleSmall,
              overflow: TextOverflow.ellipsis,
            ),
          )),
      Divider(color: Theme.of(context).disabledColor,height: 1,),
    ];
    for (var tuple in details.entries) {
      data.add(Expanded(
          flex: 2,
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 5),
                child: Icon(
                  tuple.key,
                  color: Theme.of(context).textTheme.bodySmall?.color,
                ),
              ),
              Expanded(
                  child: Text(tuple.value,
                      style: Theme.of(context).textTheme.bodySmall,
                      overflow: TextOverflow.ellipsis))
            ],
          )));
    }
    return data;
  }
}
