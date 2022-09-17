import 'package:flutter/material.dart';

class ListCard extends StatelessWidget {
  final List<Widget> children;
  final Color? color;

  const ListCard({super.key, this.color, required this.children});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(top: 16, left: 16, right: 16),
      color: color,
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: children,
      ),
    );
  }
}
