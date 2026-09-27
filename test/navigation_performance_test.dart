import 'package:dcomic/providers/navigator_provider.dart';
import 'package:dcomic/view/comic_pages/comic_browser_shell.dart';
import 'package:dcomic/utils/frame_performance.dart';
import 'package:dcomic/utils/navigation_performance.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class _TraceRecord {
  _TraceRecord(this.name, this.attributes);

  final String name;
  final Map<String, String> attributes;
  final List<String> outcomes = [];
}

class _TestRoute extends Route<void> {
  _TestRoute(String? name) : super(settings: RouteSettings(name: name));
}

class _TestTransitionRoute extends _TestRoute implements TransitionRoute<void> {
  _TestTransitionRoute(String name, this.testAnimation) : super(name);

  final Animation<double> testAnimation;

  @override
  Animation<double>? get animation => testAnimation;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ObservedNavigatorProvider extends NavigatorProvider {
  _ObservedNavigatorProvider(
    BuildContext context,
    this.browsePerformanceObserver,
  ) : super(context);

  @override
  final NavigationPerformanceObserver browsePerformanceObserver;
}

class _RecordingFrameSampler implements FrameActivitySampler {
  final List<({String? screen, double refreshRateHz})> contexts = [];
  final List<bool> activeStates = [];
  bool disposed = false;

  @override
  void updateContext({required String? screen, required double refreshRateHz}) {
    contexts.add((screen: screen, refreshRateHz: refreshRateHz));
  }

  @override
  void setActive(bool active) => activeStates.add(active);

  @override
  void recordActivity() {}

  @override
  void dispose() => disposed = true;
}

void main() {
  test('every existing named route is tracked without a registry', () {
    final traces = <_TraceRecord>[];
    final observer = NavigationPerformanceObserver(
      navigatorName: 'root',
      schedulePostFrame: (_) {},
      startTrace: (name, attributes) {
        final record = _TraceRecord(name, Map.of(attributes));
        traces.add(record);
        return record.outcomes.add;
      },
    );
    addTearDown(observer.dispose);

    final named = _TestRoute('NewInfrastructureRoute');
    observer.didPush(named, null);
    expect(traces, hasLength(1));
    expect(
      traces.every(
        (trace) => trace.attributes['screen'] == 'NewInfrastructureRoute',
      ),
      isTrue,
    );

    observer.didPush(_TestRoute(null), named);
    expect(traces, hasLength(1));
    expect(observer.currentScreen.value, isNull);
  });

  test('independent framework coverage sources compose', () {
    final traces = <_TraceRecord>[];
    final observer = NavigationPerformanceObserver(
      navigatorName: 'browse',
      schedulePostFrame: (_) {},
      startTrace: (name, attributes) {
        final record = _TraceRecord(name, Map.of(attributes));
        traces.add(record);
        return record.outcomes.add;
      },
    );
    addTearDown(observer.dispose);

    observer.setCovered(NavigationCoverageSource.rootNavigator, true);
    observer.setCovered(NavigationCoverageSource.browserShell, true);
    observer.didPush(_TestRoute('CoveredByBoth'), null);
    observer.setCovered(NavigationCoverageSource.rootNavigator, false);
    observer.didPush(_TestRoute('StillOffstage'), null);
    expect(traces, isEmpty);

    observer.setCovered(NavigationCoverageSource.browserShell, false);
    observer.didPush(_TestRoute('VisibleAgain'), null);
    expect(traces.single.attributes['screen'], 'VisibleAgain');
  });

  test('push records next route frame and forward transition separately', () {
    final postFrameCallbacks = <FrameCallback>[];
    final traces = <_TraceRecord>[];
    final controller = AnimationController(vsync: const TestVSync());
    addTearDown(controller.dispose);
    final observer = NavigationPerformanceObserver(
      navigatorName: 'root',
      schedulePostFrame: postFrameCallbacks.add,
      startTrace: (name, attributes) {
        final record = _TraceRecord(name, Map.of(attributes));
        traces.add(record);
        return record.outcomes.add;
      },
    );
    addTearDown(observer.dispose);

    observer.didPush(_TestTransitionRoute('ComicViewerPage', controller), null);

    expect(traces.map((trace) => trace.name), [
      'navigation_next_route_frame',
      'navigation_forward_transition',
    ]);
    expect(traces.first.attributes, {
      'navigator': 'root',
      'screen': 'ComicViewerPage',
    });
    expect(traces[0].outcomes, isEmpty);
    expect(traces[1].outcomes, isEmpty);

    postFrameCallbacks.single(Duration.zero);
    expect(traces[0].outcomes, ['success']);
    expect(traces[1].outcomes, isEmpty);

    controller.value = 1;
    expect(traces[1].outcomes, ['success']);
  });

  test(
    'covered, replaced, backgrounded, and disposed routes cancel safely',
    () {
      final postFrameCallbacks = <FrameCallback>[];
      final traces = <_TraceRecord>[];
      final firstAnimation = AnimationController(vsync: const TestVSync());
      final secondAnimation = AnimationController(vsync: const TestVSync());
      addTearDown(firstAnimation.dispose);
      addTearDown(secondAnimation.dispose);
      final observer = NavigationPerformanceObserver(
        navigatorName: 'root',
        schedulePostFrame: postFrameCallbacks.add,
        startTrace: (name, attributes) {
          final record = _TraceRecord(name, Map.of(attributes));
          traces.add(record);
          return record.outcomes.add;
        },
      );

      final first = _TestTransitionRoute('ComicViewerPage', firstAnimation);
      final second = _TestTransitionRoute('SearchPage', secondAnimation);
      observer.didPush(first, null);
      observer.didReplace(newRoute: second, oldRoute: first);

      expect(
        traces.take(2).every((trace) => trace.outcomes.single == 'cancelled'),
        isTrue,
      );
      expect(observer.currentScreen.value, 'SearchPage');

      observer.setForeground(false);
      expect(
        traces.skip(2).every((trace) => trace.outcomes.single == 'cancelled'),
        isTrue,
      );
      observer.didPush(_TestRoute('ComicViewerPage'), second);
      expect(traces, hasLength(4));

      observer.setForeground(true);
      final last = _TestTransitionRoute('ComicViewerPage', firstAnimation);
      observer.didPush(last, second);
      observer.dispose();
      final countAfterDispose = traces.fold<int>(
        0,
        (count, trace) => count + trace.outcomes.length,
      );
      firstAnimation.value = 1;
      for (final callback in postFrameCallbacks) {
        callback(Duration.zero);
      }
      expect(
        traces.fold<int>(0, (count, trace) => count + trace.outcomes.length),
        countAfterDispose,
      );
      expect(traces.last.outcomes, ['cancelled']);
    },
  );

  test('pop race cancels both endpoints and restores prior current route', () {
    final callbacks = <FrameCallback>[];
    final traces = <_TraceRecord>[];
    final animation = AnimationController(vsync: const TestVSync());
    addTearDown(animation.dispose);
    final observer = NavigationPerformanceObserver(
      navigatorName: 'browse',
      schedulePostFrame: callbacks.add,
      startTrace: (name, attributes) {
        final record = _TraceRecord(name, Map.of(attributes));
        traces.add(record);
        return record.outcomes.add;
      },
    );
    addTearDown(observer.dispose);
    final browser = _TestRoute('ComicBrowser');
    final reader = _TestTransitionRoute('ComicViewerPage', animation);

    observer.didPush(browser, null);
    for (final callback in List<FrameCallback>.of(callbacks)) {
      callback(Duration.zero);
    }
    callbacks.clear();
    observer.didPush(reader, browser);
    observer.didPop(reader, browser);

    expect(observer.currentScreen.value, 'ComicBrowser');
    expect(
      traces.skip(1).every((trace) => trace.outcomes.single == 'cancelled'),
      isTrue,
    );
  });

  test('root and nested navigator measurements remain independent', () {
    final rootCallbacks = <FrameCallback>[];
    final browseCallbacks = <FrameCallback>[];
    final traces = <_TraceRecord>[];
    NavigationPerformanceObserver createObserver(
      String name,
      List<FrameCallback> callbacks,
    ) => NavigationPerformanceObserver(
      navigatorName: name,
      schedulePostFrame: callbacks.add,
      startTrace: (traceName, attributes) {
        final record = _TraceRecord(traceName, Map.of(attributes));
        traces.add(record);
        return record.outcomes.add;
      },
    );

    final root = createObserver('root', rootCallbacks);
    final browse = createObserver('browse', browseCallbacks);
    addTearDown(root.dispose);
    addTearDown(browse.dispose);
    final reader = _TestRoute('ComicViewerPage');
    final search = _TestRoute('SearchPage');

    root.didPush(reader, null);
    browse.didPush(search, null);
    root.didRemove(reader, null);
    browseCallbacks.single(Duration.zero);

    expect(
      traces
          .where((trace) => trace.attributes['navigator'] == 'root')
          .every((trace) => trace.outcomes.single == 'cancelled'),
      isTrue,
    );
    expect(
      traces
          .where((trace) => trace.attributes['navigator'] == 'browse')
          .every((trace) => trace.outcomes.single == 'success'),
      isTrue,
    );
  });

  test('custom route without animation reports only its next frame', () {
    final callbacks = <FrameCallback>[];
    final traces = <_TraceRecord>[];
    final observer = NavigationPerformanceObserver(
      navigatorName: 'detail',
      schedulePostFrame: callbacks.add,
      startTrace: (name, attributes) {
        final record = _TraceRecord(name, Map.of(attributes));
        traces.add(record);
        return record.outcomes.add;
      },
    );
    addTearDown(observer.dispose);

    observer.didPush(_TestRoute('ComicDetailPage'), null);
    expect(traces, hasLength(1));
    expect(traces.every((trace) => trace.outcomes.isEmpty), isTrue);
    callbacks.single(Duration.zero);
    expect(traces.every((trace) => trace.outcomes.single == 'success'), isTrue);
  });

  testWidgets(
    'detail link records browse navigation before the shell rebuilds',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(500, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final traces = <_TraceRecord>[];
      final observer = NavigationPerformanceObserver(
        navigatorName: 'browse',
        startTrace: (name, attributes) {
          final record = _TraceRecord(name, attributes);
          traces.add(record);
          return record.outcomes.add;
        },
      );
      late NavigatorProvider navigation;
      await tester.pumpWidget(
        Builder(
          builder: (context) {
            return ChangeNotifierProvider<NavigatorProvider>(
              create: (_) =>
                  navigation = _ObservedNavigatorProvider(context, observer),
              child: const MaterialApp(
                home: ComicBrowserShell(child: Scaffold(body: Text('library'))),
              ),
            );
          },
        ),
      );
      navigation.showDetail(
        identity: 'detail',
        builder: (detailContext, _) => Scaffold(
          body: ElevatedButton(
            onPressed: () => navigation
                .getNavigator(detailContext, NavigatorType.defaultNavigator)!
                .push(
                  MaterialPageRoute<void>(
                    settings: const RouteSettings(name: 'FutureAuthorPage'),
                    builder: (_) =>
                        const Scaffold(body: Text('author results')),
                  ),
                ),
            child: const Text('author'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      traces.clear();
      await tester.tap(find.text('author'));
      await tester.pumpAndSettle();
      expect(find.text('author results'), findsOneWidget);
      expect(traces.map((trace) => trace.name), [
        'navigation_next_route_frame',
        'navigation_forward_transition',
      ]);
      for (final trace in traces) {
        expect(trace.attributes['screen'], 'FutureAuthorPage');
        expect(trace.outcomes, ['success']);
      }
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('root listener selects only the uncovered foreground reader', (
    tester,
  ) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    final observer = NavigationPerformanceObserver(
      navigatorName: 'root',
      startTrace: (_, _) => (_) {},
    );
    final sampler = _RecordingFrameSampler();
    addTearDown(observer.dispose);

    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        navigatorObservers: [observer],
        builder: (context, child) => RouteFramePerformanceListener(
          rootObserver: observer,
          navigationObservers: [observer],
          sampler: sampler,
          child: child!,
        ),
        home: const Scaffold(body: SizedBox.expand()),
      ),
    );

    expect(sampler.activeStates.last, isFalse);
    navigatorKey.currentState!.push(
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: 'ComicViewerPage'),
        builder: (_) => const Scaffold(body: SizedBox.expand()),
      ),
    );
    await tester.pump();
    expect(sampler.contexts.last.screen, 'ComicViewerPage');
    expect(sampler.activeStates.last, isTrue);

    showDialog<void>(
      context: navigatorKey.currentContext!,
      builder: (_) => const AlertDialog(content: Text('cover')),
    );
    await tester.pump();
    expect(sampler.activeStates.last, isFalse);
    navigatorKey.currentState!.pop();
    await tester.pump();
    expect(sampler.activeStates.last, isTrue);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(sampler.activeStates.last, isFalse);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(sampler.activeStates.last, isTrue);

    await tester.pumpWidget(const SizedBox.shrink());
    expect(sampler.disposed, isFalse);
  });
}
