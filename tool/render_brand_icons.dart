import 'dart:io';
import 'dart:ui' as ui;

import 'package:dcomic/utils/theme_utils.dart';
import 'package:dcomic/view/components/dcomic_mark.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

// Run through generate_brand_icons.py; this renders the actual app widget,
// rather than maintaining a separate drawing of the brand mark.
void main() {
  testWidgets('Export DComic brand artwork', (tester) async {
    await tester.runAsync(() async {
      final loader = FontLoader('MaterialIcons')
        ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
      await loader.load();
    });
    await tester.binding.setSurfaceSize(const Size(1024, 1024));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final theme = ThemeModel.buildTheme(brightness: Brightness.light);
    for (final adaptive in [false, true]) {
      final key = GlobalKey();
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Theme(
            data: theme,
            child: Center(
              child: RepaintBoundary(
                key: key,
                child: SizedBox.square(
                  dimension: 1024,
                  child: ColoredBox(
                    color: adaptive
                        ? Colors.transparent
                        : theme.colorScheme.surface,
                    child: Center(
                      // Adaptive foreground stays inside Android's safe circle.
                      child: DComicMark(size: adaptive ? 480 : 760),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final image = await boundary.toImage();
        try {
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final name = adaptive ? 'adaptive-foreground' : 'logo';
          final file = File('assets/branding/$name.png');
          await file.parent.create(recursive: true);
          await file.writeAsBytes(bytes!.buffer.asUint8List());
        } finally {
          image.dispose();
        }
      });
    }
  });
}
