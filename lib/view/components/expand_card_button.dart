import 'package:flutter/material.dart';

class ExpandCardButton extends StatelessWidget {
  final void Function() onTap;
  final IconData icon;
  final String? tooltip;

  const ExpandCardButton(
      {super.key, required this.onTap, required this.icon, this.tooltip});

  @override
  Widget build(BuildContext context) {
    final ink = InkWell(
      onTap: onTap,
      child: SizedBox(
        height: double.infinity,
        child: Icon(
          icon,
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
    );
    return Expanded(
      child: tooltip == null ? ink : Tooltip(message: tooltip!, child: ink),
    );
  }
}
