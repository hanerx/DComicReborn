import 'package:dcomic/generated/l10n.dart';
import 'package:flutter/material.dart';

class EmptyWidget extends StatelessWidget {
  final String? title;
  final IconData? icon;
  final List<Widget>? children;

  const EmptyWidget({super.key, this.title, this.icon, this.children});

  @override
  Widget build(BuildContext context) {
    var color = Theme.of(context).colorScheme.onSurfaceVariant;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon ?? Icons.folder_off_outlined, size: 48, color: color),
            const SizedBox(height: 12),
            Text(
              title ?? S.of(context).Empty,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: color),
            ),
            if (children != null) ...[
              const SizedBox(height: 12),
              ...children!,
            ],
          ],
        ),
      ),
    );
  }
}

class AutoEmptyWidget extends EmptyWidget {
  final bool isEmpty;
  final Widget notEmptyChild;

  const AutoEmptyWidget(
      {required this.isEmpty,
      required this.notEmptyChild,
      super.key,
      super.title,
      super.children,
      super.icon});

  @override
  Widget build(BuildContext context) {
    if (isEmpty) {
      return LayoutBuilder(
          builder: (context, containers) => ListView(
                children: [
                  SizedBox(
                    height: containers.maxHeight,
                    child: super.build(context),
                  )
                ],
              ));
    }
    return notEmptyChild;
  }
}
