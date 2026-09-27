import 'dart:async';

import 'package:dcomic/utils/frame_performance.dart';
import 'package:dcomic/utils/performance_monitor.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

enum NavigationCoverageSource { rootNavigator, browserShell }

typedef NavigationPerformanceTraceStop = void Function(String outcome);
typedef NavigationPerformanceTraceStart =
    NavigationPerformanceTraceStop Function(
      String name,
      Map<String, String> attributes,
    );
typedef NavigationPostFrameScheduler = void Function(FrameCallback callback);

/// Measures navigation infrastructure without requiring page instrumentation.
///
/// Every named push or replacement is measured through its next framework
/// frame. A [TransitionRoute] separately records forward animation completion.
/// Route dwell is never awaited. Each instance belongs to one Navigator.
class NavigationPerformanceObserver extends NavigatorObserver {
  NavigationPerformanceObserver({
    required this.navigatorName,
    PerformanceMonitor? monitor,
    NavigationPerformanceTraceStart? startTrace,
    NavigationPostFrameScheduler? schedulePostFrame,
  }) : _monitor = monitor ?? PerformanceMonitor.instance,
       _injectedStartTrace = startTrace,
       _schedulePostFrame =
           schedulePostFrame ?? SchedulerBinding.instance.addPostFrameCallback;

  final String navigatorName;
  final PerformanceMonitor _monitor;
  final NavigationPerformanceTraceStart? _injectedStartTrace;
  final NavigationPostFrameScheduler _schedulePostFrame;
  final List<Route<dynamic>> _routes = [];
  final Map<Route<dynamic>, _RouteMeasurement> _measurements = {};

  /// The top route's existing settings name. It is null for unnamed routes,
  /// including overlays, so they genuinely cover an underlying reader route.
  final ValueNotifier<String?> currentScreen = ValueNotifier<String?>(null);

  /// True while a route above this Navigator's base route covers its content.
  final ValueNotifier<bool> hasCoveringRoute = ValueNotifier<bool>(false);

  bool _foreground = true;
  bool _disposed = false;
  final Set<Object> _coverageSources = <Object>{};

  /// Marks this Navigator as hidden by shared framework infrastructure.
  /// Multiple independent cover sources compose without overwriting each other.
  void setCovered(Object source, bool covered) {
    if (_disposed) return;
    final changed = covered
        ? _coverageSources.add(source)
        : _coverageSources.remove(source);
    if (changed && covered) _cancelAll();
  }

  void setForeground(bool foreground) {
    if (_disposed || _foreground == foreground) return;
    _foreground = foreground;
    if (!foreground) _cancelAll();
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    if (_disposed) return;
    if (previousRoute != null) _cancel(previousRoute);
    _removeRoute(route);
    _routes.add(route);
    _publishCurrentScreen();
    _start(route);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    if (_disposed) return;
    if (oldRoute != null) _cancel(oldRoute);
    final oldIndex = oldRoute == null ? -1 : _routes.indexOf(oldRoute);
    if (newRoute != null) _removeRoute(newRoute);
    if (oldIndex >= 0) {
      if (newRoute == null) {
        _routes.removeAt(oldIndex);
      } else {
        _routes[oldIndex] = newRoute;
      }
    } else {
      if (oldRoute != null) _routes.remove(oldRoute);
      if (newRoute != null) _routes.add(newRoute);
    }
    _publishCurrentScreen();
    if (newRoute != null &&
        _routes.isNotEmpty &&
        identical(_routes.last, newRoute)) {
      _start(newRoute);
    }
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    if (_disposed) return;
    _cancel(route);
    _routes.remove(route);
    if (previousRoute != null && !_routes.contains(previousRoute)) {
      _routes.add(previousRoute);
    }
    _publishCurrentScreen();
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didRemove(route, previousRoute);
    if (_disposed) return;
    _cancel(route);
    _routes.remove(route);
    _publishCurrentScreen();
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _cancelAll();
    _routes.clear();
    _coverageSources.clear();
    hasCoveringRoute.dispose();
    currentScreen.dispose();
  }

  void _start(Route<dynamic> route) {
    if (!_foreground || _coverageSources.isNotEmpty) return;
    final screen = route.settings.name;
    if (screen == null) return;
    final attributes = {'navigator': navigatorName, 'screen': screen};
    final transitionRoute = route is TransitionRoute<dynamic> ? route : null;
    final animation = transitionRoute?.animation;
    final measurement = _RouteMeasurement(
      stopFrame: _startTrace('navigation_next_route_frame', attributes),
      stopTransition: animation == null
          ? null
          : _startTrace('navigation_forward_transition', attributes),
      animation: animation,
    );
    _measurements[route] = measurement;

    if (animation != null) {
      measurement.animationListener = (status) {
        if (!_isCurrent(route, measurement)) return;
        if (status == AnimationStatus.completed) {
          measurement.completeTransition();
          _removeIfComplete(route, measurement);
        } else if (status == AnimationStatus.reverse ||
            status == AnimationStatus.dismissed) {
          measurement.cancelTransition();
          _removeIfComplete(route, measurement);
        }
      };
      animation.addStatusListener(measurement.animationListener!);
      if (animation.status == AnimationStatus.completed) {
        measurement.completeTransition();
      }
    }

    _schedulePostFrame((_) {
      if (!_isCurrent(route, measurement)) return;
      measurement.completeFrame();
      // A non-TransitionRoute has no transition endpoint to report.
      _removeIfComplete(route, measurement);
    });
  }

  NavigationPerformanceTraceStop _startTrace(
    String name,
    Map<String, String> attributes,
  ) {
    final injected = _injectedStartTrace;
    if (injected != null) return injected(name, attributes);
    final trace = _monitor.startTrace(name, attributes: attributes);
    return (outcome) => unawaited(trace.stop(outcome: outcome));
  }

  bool _isCurrent(Route<dynamic> route, _RouteMeasurement measurement) =>
      !_disposed &&
      _foreground &&
      _coverageSources.isEmpty &&
      identical(_measurements[route], measurement);

  void _removeIfComplete(Route<dynamic> route, _RouteMeasurement measurement) {
    if (!measurement.complete ||
        !identical(_measurements[route], measurement)) {
      return;
    }
    _measurements.remove(route);
    measurement.detachAnimationListener();
  }

  void _cancel(Route<dynamic> route) {
    final measurement = _measurements.remove(route);
    if (measurement == null) return;
    measurement.cancel();
  }

  void _cancelAll() {
    for (final measurement in _measurements.values) {
      measurement.cancel();
    }
    _measurements.clear();
  }

  void _removeRoute(Route<dynamic> route) {
    _routes.remove(route);
  }

  void _publishCurrentScreen() {
    final screen = _routes.isEmpty ? null : _routes.last.settings.name;
    if (currentScreen.value != screen) currentScreen.value = screen;
    final covered = _routes.length > 1;
    if (hasCoveringRoute.value != covered) {
      hasCoveringRoute.value = covered;
    }
  }
}

class _RouteMeasurement {
  _RouteMeasurement({
    required this.stopFrame,
    required this.stopTransition,
    required this.animation,
  }) : _transitionStopped = stopTransition == null;

  final NavigationPerformanceTraceStop stopFrame;
  final NavigationPerformanceTraceStop? stopTransition;
  final Animation<double>? animation;
  AnimationStatusListener? animationListener;
  bool _frameStopped = false;
  bool _transitionStopped;

  bool get complete => _frameStopped && _transitionStopped;

  void completeFrame() {
    if (_frameStopped) return;
    _frameStopped = true;
    stopFrame('success');
  }

  void completeTransition() {
    if (_transitionStopped) return;
    _transitionStopped = true;
    stopTransition?.call('success');
  }

  void cancelTransition() {
    if (_transitionStopped) return;
    _transitionStopped = true;
    stopTransition?.call('cancelled');
  }

  void cancel() {
    if (!_frameStopped) {
      _frameStopped = true;
      stopFrame('cancelled');
    }
    cancelTransition();
    detachAnimationListener();
  }

  void detachAnimationListener() {
    final listener = animationListener;
    if (listener == null) return;
    animation?.removeStatusListener(listener);
    animationListener = null;
  }
}

/// Common app-root input, scrolling, lifecycle, route, and frame-timing hook.
///
/// Sampling is intentionally limited to an uncovered foreground reader route.
/// Its metric describes all route UI activity, including internal overlays;
/// it does not claim image-only work or content readiness.
class RouteFramePerformanceListener extends StatefulWidget {
  const RouteFramePerformanceListener({
    super.key,
    required this.rootObserver,
    required this.navigationObservers,
    required this.child,
    this.sampler,
  });

  final NavigationPerformanceObserver rootObserver;
  final List<NavigationPerformanceObserver> navigationObservers;
  final Widget child;

  @visibleForTesting
  final FrameActivitySampler? sampler;

  @override
  State<RouteFramePerformanceListener> createState() =>
      _RouteFramePerformanceListenerState();
}

class _RouteFramePerformanceListenerState
    extends State<RouteFramePerformanceListener>
    with WidgetsBindingObserver {
  late FrameActivitySampler _sampler;
  late bool _ownsSampler;
  late bool _foreground;
  String? _screen;
  double _refreshRateHz = 0;

  @override
  void initState() {
    super.initState();
    _installSampler(widget.sampler);
    final binding = WidgetsBinding.instance;
    _foreground =
        binding.lifecycleState == null ||
        binding.lifecycleState == AppLifecycleState.resumed;
    binding.addObserver(this);
    widget.rootObserver.currentScreen.addListener(_handleRouteChanged);
    widget.rootObserver.hasCoveringRoute.addListener(_handleRouteChanged);
    _screen = widget.rootObserver.currentScreen.value;
    _syncNavigationObservers();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _refreshRateHz = View.of(context).display.refreshRate;
    _syncSampler();
  }

  @override
  void didChangeMetrics() {
    if (!mounted) return;
    final refreshRateHz = View.of(context).display.refreshRate;
    if (_refreshRateHz == refreshRateHz) return;
    _refreshRateHz = refreshRateHz;
    _syncSampler();
  }

  @override
  void didUpdateWidget(RouteFramePerformanceListener oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.rootObserver, widget.rootObserver)) {
      oldWidget.rootObserver.currentScreen.removeListener(_handleRouteChanged);
      oldWidget.rootObserver.hasCoveringRoute.removeListener(
        _handleRouteChanged,
      );
      for (final observer in oldWidget.navigationObservers) {
        if (!identical(observer, oldWidget.rootObserver)) {
          observer.setCovered(NavigationCoverageSource.rootNavigator, false);
        }
      }
      widget.rootObserver.currentScreen.addListener(_handleRouteChanged);
      widget.rootObserver.hasCoveringRoute.addListener(_handleRouteChanged);
      _screen = widget.rootObserver.currentScreen.value;
    }
    if (!identical(oldWidget.sampler, widget.sampler)) {
      if (_ownsSampler) _sampler.dispose();
      _installSampler(widget.sampler);
    }
    _syncNavigationObservers();
    _syncSampler();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final foreground = state == AppLifecycleState.resumed;
    if (_foreground == foreground) return;
    _foreground = foreground;
    _syncNavigationObservers();
    _syncSampler();
  }

  void _installSampler(FrameActivitySampler? sampler) {
    _ownsSampler = sampler == null;
    _sampler = sampler ?? FramePerformanceSampler();
  }

  void _handleRouteChanged() {
    _screen = widget.rootObserver.currentScreen.value;
    _syncNavigationObservers();
    _syncSampler();
  }

  void _syncNavigationObservers() {
    final covered = widget.rootObserver.hasCoveringRoute.value;
    for (final observer in widget.navigationObservers) {
      observer.setForeground(_foreground);
      if (!identical(observer, widget.rootObserver)) {
        observer.setCovered(NavigationCoverageSource.rootNavigator, covered);
      }
    }
  }

  void _syncSampler() {
    final active = _foreground && _screen == 'ComicViewerPage';
    if (!active) _sampler.setActive(false);
    _sampler.updateContext(screen: _screen, refreshRateHz: _refreshRateHz);
    if (active) _sampler.setActive(true);
  }

  void _recordPointer(PointerEvent _) => _sampler.recordActivity();

  bool _recordScroll(ScrollNotification _) {
    _sampler.recordActivity();
    return false;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.rootObserver.currentScreen.removeListener(_handleRouteChanged);
    widget.rootObserver.hasCoveringRoute.removeListener(_handleRouteChanged);
    for (final observer in widget.navigationObservers) {
      if (!identical(observer, widget.rootObserver)) {
        observer.setCovered(NavigationCoverageSource.rootNavigator, false);
      }
    }
    if (_ownsSampler) _sampler.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      NotificationListener<ScrollNotification>(
        onNotification: _recordScroll,
        child: Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: _recordPointer,
          onPointerMove: _recordPointer,
          onPointerSignal: _recordPointer,
          onPointerPanZoomStart: _recordPointer,
          onPointerPanZoomUpdate: _recordPointer,
          child: widget.child,
        ),
      );
}
