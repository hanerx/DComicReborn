import 'package:dcomic/utils/image_utils.dart';
import 'package:dcomic/view/components/dcomic_image.dart';
import 'package:flutter/material.dart';

class GridCard extends StatelessWidget {
  final String title;
  final IconData? sideIcon;
  final void Function()? onSideIconPressed;
  final List<Widget> children;
  final int crossAxisCount;
  final double? childAspectRatio;

  const GridCard(this.title,
      {super.key,
      this.sideIcon,
      this.onSideIconPressed,
      this.children = const [],
      this.crossAxisCount = 3,
      this.childAspectRatio});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: Column(
        children: [
          Row(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 2, 2, 2),
                child: Text(
                  title,
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).textTheme.bodySmall?.color),
                ),
              ),
              const Expanded(
                  child: SizedBox(
                height: 0,
              )),
              SizedBox(
                height: 40,
                width: 40,
                child: TextButton(
                    style: const ButtonStyle(
                      minimumSize: MaterialStatePropertyAll(Size(30, 30)),
                    ),
                    onPressed: onSideIconPressed,
                    child: Icon(
                      sideIcon,
                      size: 20,
                      color: Theme.of(context).disabledColor,
                    )),
              )
            ],
          ),
          GridView(
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                childAspectRatio: _getRatio(context)),
            shrinkWrap: true,
            children: children,
          )
        ],
      ),
    );
  }

  double _getRatio(BuildContext context) {
    if (childAspectRatio != null) {
      return childAspectRatio!;
    }
    if (crossAxisCount % 3 == 0) {
      return 4 / 6;
    }
    if (crossAxisCount % 2 == 0) {
      return 2 / 1.5;
    }
    return 1;
  }
}

class GridCardItem extends StatelessWidget {
  final String? title;
  final String? subtitle;
  final ImageEntity image;
  final void Function()? onTap;

  const GridCardItem(
      {super.key, this.title, this.subtitle, required this.image, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(5),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(3),
          child: Column(
            children: _buildColumn(context),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildColumn(BuildContext context) {
    List<Widget> list = [
      Expanded(
          child: ClipRRect(
        borderRadius: BorderRadius.circular(5),
        child: DComicImage(
          image,
          errorMessageOverflow: TextOverflow.ellipsis,
          fit: BoxFit.fill,
        ),
      )),
    ];
    if (title != null) {
      list.add(Text(
        "$title",
        style: const TextStyle(overflow: TextOverflow.ellipsis),
      ));
    }
    if (subtitle != null && subtitle!.isNotEmpty) {
      list.add(Text.rich(
        TextSpan(
            text: "$subtitle",
            style: const TextStyle(overflow: TextOverflow.ellipsis)),
        style: Theme.of(context).textTheme.bodySmall,
        overflow: TextOverflow.ellipsis,
      ));
    }
    return list;
  }
}

class GridCardPlaceHolder extends StatelessWidget {
  const GridCardPlaceHolder({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: Column(
        children: [
          Row(
            children: [
              Padding(
                padding: const EdgeInsets.all(10),
                child: Container(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  width: 100,
                  height: 20,
                ),
              ),
            ],
          ),
          GridView(
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3, childAspectRatio: 4 / 6),
            shrinkWrap: true,
            children: [
              Card(
                elevation: 0,
                margin: const EdgeInsets.all(5),
                color: Theme.of(context).colorScheme.primaryContainer,
              ),
              Card(
                elevation: 0,
                margin: const EdgeInsets.all(5),
                color: Theme.of(context).colorScheme.primaryContainer,
              ),
              Card(
                elevation: 0,
                margin: const EdgeInsets.all(5),
                color: Theme.of(context).colorScheme.primaryContainer,
              ),
            ],
          )
        ],
      ),
    );
  }
}
