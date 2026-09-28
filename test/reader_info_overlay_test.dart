import 'package:dcomic/utils/reader_info_settings.dart';
import 'package:dcomic/view/components/reader_info_overlay.dart';
import 'package:flutter/material.dart';
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
    expect(find.byIcon(Icons.bolt), findsOneWidget);

    batteryLevel = 77;
    await tester.pump(const Duration(minutes: 1));
    await tester.pump();
    expect(find.text('77%'), findsOneWidget);
  });

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

  testWidgets(
    'unavailable or invalid battery readings are never shown as full',
    (tester) async {
      await tester.pumpWidget(
        _host(batteryFormat: ReaderBatteryFormat.iconAndNumber),
      );
      await tester.pump();
      expect(find.text('42%'), findsOneWidget);

      batteryLevelFails = true;
      await tester.pump(const Duration(minutes: 1));
      await tester.pump();
      expect(find.text('--%'), findsOneWidget);
      expect(find.text('100%'), findsNothing);

      batteryLevelFails = false;
      batteryLevel = 255;
      await _emitBatteryState('discharging');
      await tester.pump();
      expect(find.text('--%'), findsOneWidget);
      expect(find.text('100%'), findsNothing);
    },
  );

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
