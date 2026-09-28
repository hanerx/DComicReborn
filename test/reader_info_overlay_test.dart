import 'dart:ui' as ui;

import 'package:dcomic/utils/reader_info_settings.dart';
import 'package:dcomic/view/components/reader_info_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _panelKey = ValueKey('reader-info-panel');
const _batteryIconKey = ValueKey('reader-info-battery-icon');
const _batteryChannel = MethodChannel('dev.fluttercommunity.plus/battery');
const _chargingChannel = MethodChannel('dev.fluttercommunity.plus/charging');
const _channelCodec = StandardMethodCodec();

Future<void> _emitBatteryState(String state) async {
  final message = _channelCodec.encodeSuccessEnvelope(state);
  await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .handlePlatformMessage(_chargingChannel.name, message, (ByteData? _) {});
}

Widget _host({
  ReaderInfoPosition position = ReaderInfoPosition.bottomRight,
  ReaderBatteryFormat batteryFormat = ReaderBatteryFormat.hidden,
  ReaderPageFormat pageFormat = ReaderPageFormat.hidden,
  bool showChapter = false,
  bool showTime = false,
  int currentPage = 0,
  int totalPages = 0,
  String chapterName = '',
  VoidCallback? onBackgroundTap,
  TextScaler? textScaler,
}) {
  return MaterialApp(
    builder: textScaler == null
        ? null
        : (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: textScaler),
            child: child!,
          ),
    home: Scaffold(
      body: SafeArea(
        child: RepaintBoundary(
          key: const ValueKey('overlay-capture'),
          child: Stack(
            children: [
              if (onBackgroundTap != null)
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onBackgroundTap,
                  ),
                ),
              ReaderInfoOverlay(
                position: position,
                batteryFormat: batteryFormat,
                pageFormat: pageFormat,
                showChapter: showChapter,
                showTime: showTime,
                currentPage: currentPage,
                totalPages: totalPages,
                chapterName: chapterName,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  var batteryLevel = 42;
  var batteryLevelFails = false;
  var batteryLevelRequests = 0;

  setUp(() {
    batteryLevel = 42;
    batteryLevelFails = false;
    batteryLevelRequests = 0;
    TestWidgetsFlutterBinding.instance.handleAppLifecycleStateChanged(
      AppLifecycleState.resumed,
    );
    messenger.setMockMethodCallHandler(_batteryChannel, (call) async {
      if (call.method != 'getBatteryLevel') {
        return null;
      }
      batteryLevelRequests++;
      if (batteryLevelFails) {
        throw PlatformException(code: 'unavailable');
      }
      return batteryLevel;
    });
    messenger.setMockMethodCallHandler(_chargingChannel, (call) async => null);
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(_batteryChannel, null);
    messenger.setMockMethodCallHandler(_chargingChannel, null);
    TestWidgetsFlutterBinding.instance.handleAppLifecycleStateChanged(
      AppLifecycleState.resumed,
    );
  });

  testWidgets('does not build an empty panel when every item is hidden', (
    tester,
  ) async {
    await tester.pumpWidget(_host());

    expect(find.byKey(_panelKey), findsNothing);
  });

  testWidgets('uses zero percent when a chapter has no image pages', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(pageFormat: ReaderPageFormat.percentage, totalPages: 0),
    );

    expect(find.text('0%'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('clamps a terminal comments page to the final image page', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        pageFormat: ReaderPageFormat.currentAndTotal,
        currentPage: 3,
        totalPages: 3,
      ),
    );

    expect(find.text('3/3'), findsOneWidget);

    await tester.pumpWidget(
      _host(
        pageFormat: ReaderPageFormat.percentage,
        currentPage: 3,
        totalPages: 3,
      ),
    );
    expect(find.text('100%'), findsOneWidget);
  });

  testWidgets('panel ignores pointer input so the reader beneath receives it', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      _host(
        pageFormat: ReaderPageFormat.currentAndTotal,
        currentPage: 1,
        totalPages: 3,
        onBackgroundTap: () => taps++,
      ),
    );

    await tester.tapAt(tester.getCenter(find.byKey(_panelKey)));

    expect(taps, 1);
  });

  testWidgets('long chapter title stays bounded on a narrow viewport', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(120, 240);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const title = 'A very long chapter title that cannot fit this viewport';
    await tester.pumpWidget(_host(showChapter: true, chapterName: title));

    expect(tester.getSize(find.byKey(_panelKey)).width, lessThanOrEqualTo(104));
    final titleWidget = tester.widget<Text>(find.text(title));
    expect(titleWidget.maxLines, 1);
    expect(titleWidget.overflow, TextOverflow.ellipsis);
    expect(tester.takeException(), isNull);
  });

  testWidgets('battery formats show only the selected battery information', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(batteryFormat: ReaderBatteryFormat.iconAndNumber),
    );
    await tester.pump();
    expect(find.byKey(_batteryIconKey), findsOneWidget);
    expect(find.text('42%'), findsOneWidget);

    await tester.pumpWidget(_host(batteryFormat: ReaderBatteryFormat.icon));
    expect(find.byKey(_batteryIconKey), findsOneWidget);
    expect(find.text('42%'), findsNothing);

    await tester.pumpWidget(_host(batteryFormat: ReaderBatteryFormat.number));
    expect(find.byKey(_batteryIconKey), findsNothing);
    expect(find.text('42%'), findsOneWidget);

    final requestsBeforeHiding = batteryLevelRequests;
    await tester.pumpWidget(
      _host(
        batteryFormat: ReaderBatteryFormat.hidden,
        pageFormat: ReaderPageFormat.current,
        totalPages: 1,
      ),
    );
    await tester.pump(const Duration(minutes: 2));
    expect(find.byKey(_batteryIconKey), findsNothing);
    expect(find.text('42%'), findsNothing);
    expect(batteryLevelRequests, requestsBeforeHiding);
  });

  testWidgets('battery event and active timer refresh the platform level', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(batteryFormat: ReaderBatteryFormat.iconAndNumber),
    );
    await tester.pump();
    expect(find.text('42%'), findsOneWidget);

    batteryLevel = 64;
    await _emitBatteryState('charging');
    await tester.pump();
    expect(find.text('64%'), findsOneWidget);

    batteryLevel = 77;
    await tester.pump(const Duration(minutes: 1));
    await tester.pump();
    expect(find.text('77%'), findsOneWidget);

    await _emitBatteryState('discharging');
    await tester.pump();
    expect(find.byKey(_batteryIconKey), findsOneWidget);
    await _emitBatteryState('full');
    await tester.pump();
  });

  testWidgets(
    'charging bolt cuts through the fill and stays visible on an empty battery',
    (tester) async {
      tester.view.physicalSize = const Size(160, 80);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(_host(batteryFormat: ReaderBatteryFormat.icon));
      await tester.pump();

      Future<({Color center, Color outline, Color background})> pixels() async {
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(const ValueKey('overlay-capture')),
        );
        final battery = tester.renderObject<RenderBox>(
          find.byKey(_batteryIconKey),
        );
        final origin = boundary.globalToLocal(
          battery.localToGlobal(Offset.zero),
        );
        return (await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 4);
          final bytes = (await image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          ))!;
          Color sample(Offset local) {
            final point = (origin + local) * 4;
            final index =
                (point.dy.floor() * image.width + point.dx.floor()) * 4;
            return Color.fromARGB(
              bytes.getUint8(index + 3),
              bytes.getUint8(index),
              bytes.getUint8(index + 1),
              bytes.getUint8(index + 2),
            );
          }

          final result = (
            center: sample(const Offset(8, 5)),
            outline: sample(const Offset(6, 5)),
            background: sample(const Offset(-3, 5)),
          );
          image.dispose();
          return result;
        }))!;
      }

      for (final level in [0, 15, 67, 100]) {
        batteryLevel = level;
        await _emitBatteryState('charging');
        await tester.pump();
        final charging = await pixels();
        expect(
          charging.center,
          charging.background,
          reason: '$level% cutout must reveal the panel',
        );
        expect(
          charging.outline.r,
          greaterThan(.9),
          reason: '$level% bolt edge must remain visible',
        );
        expect(charging.outline.g, greaterThan(.9));
        expect(charging.outline.b, greaterThan(.9));

        // Unplugging must repaint even when the battery level has not changed.
        await _emitBatteryState('discharging');
        await tester.pump();
        final normal = await pixels();
        expect(normal.center, level >= 67 ? Colors.white : normal.background);
        if (level < 20) {
          expect(normal.outline, normal.background);
        }
      }
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('battery refresh pauses in background and resumes immediately', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(batteryFormat: ReaderBatteryFormat.iconAndNumber),
    );
    await tester.pump();

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    final requestsWhilePaused = batteryLevelRequests;
    batteryLevel = 81;
    await tester.pump(const Duration(minutes: 2));
    expect(batteryLevelRequests, requestsWhilePaused);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(find.text('81%'), findsOneWidget);
    expect(batteryLevelRequests, greaterThan(requestsWhilePaused));
  });

  for (final format in [
    ReaderBatteryFormat.icon,
    ReaderBatteryFormat.number,
    ReaderBatteryFormat.iconAndNumber,
  ]) {
    testWidgets(
      '$format: unavailable power shows a plug and recovers to battery',
      (tester) async {
        await tester.pumpWidget(_host(batteryFormat: format));
        await tester.pump();
        expect(find.byIcon(Icons.power), findsNothing);

        batteryLevelFails = true;
        await tester.pump(const Duration(minutes: 1));
        await tester.pump();
        expect(find.byIcon(Icons.power), findsOneWidget);
        expect(find.byKey(_batteryIconKey), findsNothing);
        expect(find.text('--%'), findsNothing);
        expect(find.text('42%'), findsNothing);

        batteryLevelFails = false;
        batteryLevel = 255;
        await _emitBatteryState('charging');
        await tester.pump();
        expect(find.byIcon(Icons.power), findsOneWidget);
        expect(find.text('100%'), findsNothing);

        // An empty battery is a valid reading, not an unavailable device.
        batteryLevel = 0;
        await _emitBatteryState('discharging');
        await tester.pump();
        expect(find.byIcon(Icons.power), findsNothing);
        expect(
          find.byKey(_batteryIconKey),
          format == ReaderBatteryFormat.number ? findsNothing : findsOneWidget,
        );
        expect(
          find.text('0%'),
          format == ReaderBatteryFormat.icon ? findsNothing : findsOneWidget,
        );
        await tester.pumpWidget(_host());
        expect(find.byIcon(Icons.power), findsNothing);
      },
    );
  }

  testWidgets('all info remains bounded with large text on a narrow viewport', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(240, 320);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _host(
        batteryFormat: ReaderBatteryFormat.iconAndNumber,
        pageFormat: ReaderPageFormat.currentAndTotal,
        showChapter: true,
        showTime: true,
        currentPage: 8,
        totalPages: 12,
        chapterName: 'A long chapter title for a narrow reader',
        textScaler: const TextScaler.linear(2.5),
      ),
    );
    await tester.pump();

    expect(tester.getSize(find.byKey(_panelKey)).width, lessThanOrEqualTo(224));
    expect(tester.takeException(), isNull);
  });
}
