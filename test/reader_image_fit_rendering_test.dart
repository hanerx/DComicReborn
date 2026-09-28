import 'package:dcomic/utils/reader_image_fit.dart';
import 'package:dcomic/view/components/reader_page_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _viewport = Size(200, 200);
const _wideImage = Size(400, 200);
const _imageKey = ValueKey('image');

Widget _host({
  required ReaderImageFit fit,
  required Axis readingAxis,
  Size imageSize = _wideImage,
}) {
  return MaterialApp(
    home: Align(
      alignment: Alignment.topLeft,
      child: ReaderPageImageLayout(
        viewportSize: _viewport,
        imageSize: imageSize,
        fit: fit,
        readingAxis: readingAxis,
        child: const ColoredBox(key: _imageKey, color: Colors.white),
      ),
    ),
  );
}

void main() {
  testWidgets(
    'vertical actual size keeps native height and exposes wide overflow',
    (tester) async {
      const nativeSize = Size(400, 300);
      await tester.pumpWidget(
        _host(
          fit: ReaderImageFit.actualSize,
          readingAxis: Axis.vertical,
          imageSize: nativeSize,
        ),
      );

      expect(tester.getSize(find.byKey(_imageKey)), nativeSize);
      expect(
        tester.getSize(find.byType(ReaderPageImageLayout)),
        const Size(200, 300),
      );
      final scrollable = tester.state<ScrollableState>(
        find.byType(Scrollable).first,
      );
      expect(scrollable.position.maxScrollExtent, 200);
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(-100, 0),
      );
      await tester.pump();
      expect(scrollable.position.pixels, greaterThan(0));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('contain letterboxes while cover fills and clips the viewport', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(fit: ReaderImageFit.contain, readingAxis: Axis.vertical),
    );
    expect(tester.getSize(find.byKey(_imageKey)), const Size(200, 100));
    expect(tester.getTopLeft(find.byKey(_imageKey)), const Offset(0, 50));

    await tester.pumpWidget(
      _host(fit: ReaderImageFit.cover, readingAxis: Axis.vertical),
    );
    expect(tester.getSize(find.byKey(_imageKey)), const Size(400, 200));
    expect(tester.getTopLeft(find.byKey(_imageKey)), const Offset(-100, 0));
    expect(find.byType(ClipRect), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('direction fits use the matching viewport dimension', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(fit: ReaderImageFit.fitWidth, readingAxis: Axis.vertical),
    );
    expect(tester.getSize(find.byKey(_imageKey)), const Size(200, 100));
    expect(
      tester.getSize(find.byType(ReaderPageImageLayout)),
      const Size(200, 100),
    );

    await tester.pumpWidget(
      _host(fit: ReaderImageFit.fitHeight, readingAxis: Axis.horizontal),
    );
    expect(tester.getSize(find.byKey(_imageKey)), const Size(400, 200));
    expect(tester.getSize(find.byType(ReaderPageImageLayout)), _viewport);
    expect(tester.takeException(), isNull);
  });
}
