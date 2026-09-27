import 'dart:async';

import 'package:dcomic/utils/performance_monitor.dart';
import 'package:firebase_performance/firebase_performance.dart';
import 'package:flutter_test/flutter_test.dart';

class _Trace implements Trace {
  final startGate = Completer<void>();
  final attributes = <String, String>{};
  final metrics = <String, int>{};
  int stops = 0;

  @override
  Future<void> start() => startGate.future;
  @override
  Future<void> stop() async {
    stops++;
  }

  @override
  void putAttribute(String name, String value) => attributes[name] = value;
  @override
  void setMetric(String name, int value) => metrics[name] = value;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test(
    'completion before SDK startup preserves first outcome and stops once',
    () async {
      final native = _Trace();
      final monitor = PerformanceMonitor(traceFactory: (_) => native);
      final trace = monitor.startTrace('page_open');
      final first = trace.stop(outcome: 'cancelled', metrics: {'items': 3});
      final second = trace.stop(outcome: 'success');
      expect(native.stops, 0);
      native.startGate.complete();
      await Future.wait([first, second]);
      expect(native.stops, 1);
      expect(native.attributes['outcome'], 'cancelled');
      expect(native.metrics['items'], 3);
    },
  );

  test('a failed SDK trace does not poison subsequent traces', () async {
    final native = _Trace()..startGate.complete();
    var attempts = 0;
    final monitor = PerformanceMonitor(
      traceFactory: (_) {
        if (attempts++ == 0) throw StateError('SDK missing');
        return native;
      },
    );
    await monitor.startTrace('first').stop();
    await monitor.startTrace('second').stop(outcome: 'cancelled');
    expect(native.stops, 1);
    expect(native.attributes['outcome'], 'cancelled');
  });
}
