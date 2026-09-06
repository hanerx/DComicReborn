import 'dart:math' as math;

import 'package:flutter/material.dart';

/// DComic brand mark.
///
/// A small stack of comic pages with a speech bubble, drawn purely with
/// Flutter vector primitives so it stays crisp at any [size]. All colors are
/// derived from the ambient [Theme], so the mark adapts to light and dark
/// themes automatically.
class DComicMark extends StatelessWidget {
  final double size;

  const DComicMark({super.key, this.size = 40});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final outline = math.max(1.5, size * 0.05);
    final radius = size * 0.11;
    final pageWidth = size * 0.72;
    final pageHeight = size * 0.9;
    final angle = -math.pi / 22;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          // Back page peeking out behind the cover.
          Transform.translate(
            offset: Offset(size * 0.06, -size * 0.05),
            child: Transform.rotate(
              angle: angle,
              child: Container(
                width: pageWidth,
                height: pageHeight,
                decoration: BoxDecoration(
                  color: colorScheme.primary,
                  borderRadius: BorderRadius.circular(radius),
                ),
              ),
            ),
          ),
          // Front cover with the comic content.
          Transform.rotate(
            angle: angle,
            child: Container(
              width: pageWidth,
              height: pageHeight,
              padding: EdgeInsets.all(size * 0.075),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                border: Border.all(color: colorScheme.primary, width: outline),
                borderRadius: BorderRadius.circular(radius),
              ),
              child: _buildCoverContent(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCoverContent(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Speech bubble with a burst mark.
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              height: size * 0.26,
              decoration: BoxDecoration(
                color: colorScheme.primary,
                borderRadius: BorderRadius.circular(size * 0.055),
              ),
              alignment: Alignment.center,
              child: Icon(
                Icons.bolt_rounded,
                size: size * 0.18,
                color: colorScheme.onPrimary,
              ),
            ),
            Positioned(
              left: size * 0.05,
              bottom: -size * 0.03,
              child: Transform.rotate(
                angle: math.pi / 4,
                child: Container(
                  width: size * 0.06,
                  height: size * 0.06,
                  color: colorScheme.primary,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: size * 0.1),
        _textLine(context, 1),
        SizedBox(height: size * 0.05),
        _textLine(context, 0.6),
      ],
    );
  }

  Widget _textLine(BuildContext context, double widthFactor) {
    final colorScheme = Theme.of(context).colorScheme;
    return FractionallySizedBox(
      alignment: Alignment.centerLeft,
      widthFactor: widthFactor,
      child: Container(
        height: math.max(2.0, size * 0.05),
        decoration: BoxDecoration(
          color: colorScheme.outlineVariant,
          borderRadius: BorderRadius.circular(size * 0.03),
        ),
      ),
    );
  }
}
