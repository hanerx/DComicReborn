import 'package:flutter/material.dart';

class ExpandCardButton extends StatelessWidget {
  final void Function() onTap;
  final IconData icon;

  const ExpandCardButton({super.key, required this.onTap, required this.icon});
  @override
  Widget build(BuildContext context) {
    return Expanded(
        child: InkWell(
      onTap: onTap,
      child: Card(
        elevation: 0,
        child: SizedBox(
          height: double.infinity,
          child: Icon(
            icon,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      ),
    ));
  }
}
