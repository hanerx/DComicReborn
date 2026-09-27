import 'package:firebase_performance/firebase_performance.dart';
import 'package:flutter/foundation.dart';

/// All callers use fixed names and non-identifying attributes. Telemetry must
/// never hold up a user operation or replace its result/exception.
class PerformanceMonitor {
  PerformanceMonitor({Trace Function(String)? traceFactory})
    : _traceFactory = traceFactory;

  static final instance = PerformanceMonitor();
  static final _disabledTrace = PerformanceTrace._(null, '', const {});
  Trace Function(String)? _traceFactory;

  Future<void> initialize() async {
    if (kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.android &&
            defaultTargetPlatform != TargetPlatform.iOS)) {
      return;
    }
    const enabled = bool.fromEnvironment(
      'DCOMIC_PERFORMANCE',
      defaultValue: !kDebugMode,
    );
    try {
      final performance = FirebasePerformance.instance;
      await performance.setPerformanceCollectionEnabled(enabled);
      _traceFactory = enabled ? performance.newTrace : null;
    } catch (error) {
      // Firebase availability must not prevent application startup.
      debugPrint('Performance Monitoring initialization failed: $error');
    }
  }

  PerformanceTrace startTrace(
    String name, {
    Map<String, String> attributes = const {},
  }) => _traceFactory == null
      ? _disabledTrace
      : PerformanceTrace._(_traceFactory, name, attributes);
}

class PerformanceTrace {
  PerformanceTrace._(
    Trace Function(String)? factory,
    String name,
    Map<String, String> attributes,
  ) : _clock = factory == null ? null : (Stopwatch()..start()) {
    _started = factory == null
        ? Future<Trace?>.value()
        : _start(factory, name, attributes);
  }

  final Stopwatch? _clock;
  late final Future<Trace?> _started;
  Future<void>? _stopped;

  static Future<Trace?> _start(
    Trace Function(String) factory,
    String name,
    Map<String, String> attributes,
  ) async {
    try {
      final native = factory(name);
      for (final attribute in attributes.entries) {
        native.putAttribute(attribute.key, attribute.value);
      }
      await native.start();
      return native;
    } catch (error) {
      debugPrint('Performance trace start failed: $error');
      return null;
    }
  }

  /// Freeze elapsed time at the caller's endpoint, not after native startup.
  /// Repeated cancellation/completion races retain the first outcome.
  Future<void> stop({
    String outcome = 'success',
    Map<String, int> metrics = const {},
  }) {
    if (_stopped case final stopped?) return stopped;
    _clock?.stop();
    return _stopped = _finish(outcome, metrics);
  }

  Future<void> _finish(String outcome, Map<String, int> metrics) async {
    final native = await _started;
    if (native == null) return;
    try {
      native.putAttribute('outcome', outcome);
      native.setMetric('elapsed_us', _clock!.elapsedMicroseconds);
      for (final metric in metrics.entries) {
        native.setMetric(metric.key, metric.value);
      }
    } catch (error) {
      debugPrint('Performance trace metrics failed: $error');
    } finally {
      try {
        await native.stop();
      } catch (error) {
        debugPrint('Performance trace stop failed: $error');
      }
    }
  }
}
