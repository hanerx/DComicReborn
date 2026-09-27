import 'dart:async';
import 'dart:ui';

import 'package:dcomic/utils/performance_monitor.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

/// The infrastructure-facing contract used by the root input and route hooks.
abstract interface class FrameActivitySampler {
  void updateContext({required String? screen, required double refreshRateHz});

  void setActive(bool active);

  void recordActivity();

  void dispose();
}

/// A frame reduced to the timestamps and independent pipeline-stage durations
/// needed by route activity telemetry.
@immutable
class FramePerformanceSample {
  const FramePerformanceSample({
    required this.vsyncStartUs,
    required this.buildUs,
    required this.rasterUs,
  });

  final int vsyncStartUs;
  final int buildUs;
  final int rasterUs;
}

/// The bounded aggregate emitted for one contiguous period of route activity.
@immutable
class FramePerformanceReport {
  const FramePerformanceReport({
    required this.generation,
    required this.frameCount,
    required this.overBudgetFrames,
    required this.maxBuildUs,
    required this.maxRasterUs,
    required this.activeDurationUs,
  });

  final int generation;
  final int frameCount;
  final int overBudgetFrames;
  final int maxBuildUs;
  final int maxRasterUs;

  /// Sampled span from the first to last reported vsync. Quiet tail time used
  /// only to classify late frames is deliberately excluded.
  final int activeDurationUs;

  /// Frames per second multiplied by 1000, based on observed frame intervals.
  /// Fewer than two distinct timestamps have no meaningful sampled FPS.
  int? get fpsMilli => frameCount < 2 || activeDurationUs <= 0
      ? null
      : ((frameCount - 1) * 1000000000) ~/ activeDurationUs;

  Map<String, int> get metrics {
    final fps = fpsMilli;
    return {
      'frame_count': frameCount,
      'over_budget_frames': overBudgetFrames,
      'max_build_us': maxBuildUs,
      'max_raster_us': maxRasterUs,
      'active_duration_us': activeDurationUs,
      if (fps != null) 'fps_milli': fps,
    };
  }
}

typedef FramePerformanceTraceStop = void Function(
  FramePerformanceReport report,
  String outcome,
);
typedef FramePerformanceTraceStart = FramePerformanceTraceStop Function(
  Map<String, String> attributes,
);

/// Samples Flutter frame timings during short, input-driven windows on an
/// active named route.
///
/// These are route-activity metrics. They include any UI rendered inside that
/// route and do not claim content readiness, image-only work, or reading mode.
/// Input and scrolling open a short window; subsequent activity extends it.
/// Late engine timing batches are matched by vsync timestamp. FPS is derived
/// only from observed frame intervals, never route dwell or the quiet tail.
class FramePerformanceSampler implements FrameActivitySampler {
  FramePerformanceSampler({
    PerformanceMonitor? monitor,
    Duration activityTail = const Duration(milliseconds: 600),
    Duration lateTimingGrace = const Duration(milliseconds: 1500),
    Duration maximumBurst = const Duration(seconds: 15),
    int Function()? clock,
    FramePerformanceTraceStart? startTrace,
    bool subscribeToScheduler = true,
    bool scheduleTimers = true,
  }) : _monitor = monitor ?? PerformanceMonitor.instance,
       _activityTailUs = activityTail.inMicroseconds,
       _lateTimingGraceUs = lateTimingGrace.inMicroseconds,
       _maximumBurstUs = maximumBurst.inMicroseconds,
       _clock = clock ?? _timelineNow,
       _injectedStartTrace = startTrace,
       _subscribed = subscribeToScheduler,
       _scheduleTimers = scheduleTimers {
    assert(_activityTailUs > 0);
    assert(_lateTimingGraceUs >= 0);
    assert(_maximumBurstUs >= _activityTailUs);
    if (_subscribed) SchedulerBinding.instance.addTimingsCallback(_onTimings);
  }

  final PerformanceMonitor _monitor;
  final int _activityTailUs;
  final int _lateTimingGraceUs;
  final int _maximumBurstUs;
  final int Function() _clock;
  final FramePerformanceTraceStart? _injectedStartTrace;
  final bool _scheduleTimers;
  final List<_FrameBurst> _bursts = [];

  bool _subscribed;
  bool _active = false;
  bool _disposed = false;
  int _generation = 0;
  String? _screen;
  double _refreshRateHz = 0;
  _FrameBurst? _current;
  Timer? _timer;
  int? _timerDeadlineUs;

  static int _timelineNow() => FlutterTimeline.now;

  @override
  void updateContext({required String? screen, required double refreshRateHz}) {
    if (_disposed || (_screen == screen && _refreshRateHz == refreshRateHz)) {
      return;
    }
    final nowUs = _clock();
    final current = _current;
    final continueActivity =
        _active && screen != null && current != null && nowUs < current.endUs;
    _closeCurrent(nowUs);
    _screen = screen;
    _refreshRateHz = refreshRateHz;
    if (continueActivity) _current = _startBurst(nowUs);
    _emitDue(nowUs);
    _scheduleNext();
  }

  /// Starts or ends an active route generation. Deactivation clips an open
  /// activity window immediately while retaining it for late timing batches.
  @override
  void setActive(bool active) {
    final nextActive = active && _screen != null;
    if (_disposed || _active == nextActive) return;
    final nowUs = _clock();
    _active = nextActive;
    if (nextActive) {
      _generation++;
    } else {
      _closeCurrent(nowUs);
    }
    _emitDue(nowUs);
    _scheduleNext();
  }

  @override
  void recordActivity() {
    if (_disposed || !_active) return;
    final nowUs = _clock();
    _emitDue(nowUs);
    var burst = _current;
    final burstLimit = burst == null ? 0 : burst.startUs + _maximumBurstUs;
    if (burst == null ||
        burst.generation != _generation ||
        nowUs >= burst.endUs ||
        nowUs >= burstLimit) {
      burst = _startBurst(nowUs);
      _current = burst;
    } else {
      burst.endUs = (nowUs + _activityTailUs)
          .clamp(burst.endUs, burstLimit)
          .toInt();
    }
    _scheduleNext();
  }

  /// Accepts late batches by vsync timestamp. Half-open activity windows keep
  /// boundary frames from being attributed to two route generations.
  void recordFrames(Iterable<FramePerformanceSample> samples) {
    if (_disposed || _bursts.isEmpty) return;
    for (final sample in samples) {
      _recordFrame(sample.vsyncStartUs, sample.buildUs, sample.rasterUs);
    }
  }

  @visibleForTesting
  void flush() {
    _emitDue(_clock());
    _scheduleNext();
  }

  @override
  void dispose() {
    if (_disposed) return;
    final nowUs = _clock();
    _disposed = true;
    _active = false;
    _closeCurrent(nowUs);
    _timer?.cancel();
    _timer = null;
    _timerDeadlineUs = null;
    if (_subscribed) {
      SchedulerBinding.instance.removeTimingsCallback(_onTimings);
      _subscribed = false;
    }
    for (final burst in _bursts) {
      burst.stop(burst.report, 'success');
    }
    _bursts.clear();
  }

  _FrameBurst _startBurst(int nowUs) {
    final attributes = <String, String>{
      'screen': _screen!,
      'refresh_rate_bucket': refreshRateBucket(_refreshRateHz),
    };
    final stop =
        _injectedStartTrace?.call(attributes) ??
        _startFirebaseTrace(attributes);
    final measuredRefreshRate = _refreshRateHz.isFinite && _refreshRateHz > 0
        ? _refreshRateHz
        : 60.0;
    final burst = _FrameBurst(
      generation: _generation,
      startUs: nowUs,
      endUs: nowUs + _activityTailUs,
      refreshRateHz: measuredRefreshRate,
      stop: stop,
    );
    _bursts.add(burst);
    return burst;
  }

  FramePerformanceTraceStop _startFirebaseTrace(
    Map<String, String> attributes,
  ) {
    final trace = _monitor.startTrace(
      'route_active_frames',
      attributes: attributes,
    );
    return (report, outcome) {
      unawaited(trace.stop(outcome: outcome, metrics: report.metrics));
    };
  }

  void _closeCurrent(int atUs) {
    final burst = _current;
    _current = null;
    if (burst == null) return;
    if (atUs < burst.endUs) burst.endUs = atUs;
    if (burst.endUs > burst.startUs) return;
    _bursts.remove(burst);
    burst.stop(burst.report, 'cancelled');
  }

  void _onTimings(List<FrameTiming> timings) {
    if (_bursts.isEmpty) return;
    for (final timing in timings) {
      _recordFrame(
        timing.timestampInMicroseconds(FramePhase.vsyncStart),
        timing.buildDuration.inMicroseconds,
        timing.rasterDuration.inMicroseconds,
      );
    }
  }

  void _recordFrame(int vsyncStartUs, int buildUs, int rasterUs) {
    for (final burst in _bursts) {
      if (vsyncStartUs < burst.startUs || vsyncStartUs >= burst.endUs) continue;
      burst.add(vsyncStartUs, buildUs, rasterUs);
      break;
    }
  }

  void _emitDue(int nowUs) {
    var index = 0;
    while (index < _bursts.length) {
      final burst = _bursts[index];
      if (nowUs < burst.endUs + _lateTimingGraceUs) {
        index++;
        continue;
      }
      _bursts.removeAt(index);
      if (identical(_current, burst)) _current = null;
      burst.stop(burst.report, 'success');
    }
  }

  void _scheduleNext() {
    if (!_scheduleTimers) return;
    if (_bursts.isEmpty) {
      _timer?.cancel();
      _timer = null;
      _timerDeadlineUs = null;
      return;
    }
    var deadlineUs = _bursts.first.endUs + _lateTimingGraceUs;
    for (var index = 1; index < _bursts.length; index++) {
      final candidate = _bursts[index].endUs + _lateTimingGraceUs;
      if (candidate < deadlineUs) deadlineUs = candidate;
    }
    if (_timer != null && _timerDeadlineUs! <= deadlineUs) return;
    _timer?.cancel();
    _timerDeadlineUs = deadlineUs;
    final delayUs = deadlineUs - _clock();
    _timer = Timer(Duration(microseconds: delayUs > 0 ? delayUs : 0), () {
      _timer = null;
      _timerDeadlineUs = null;
      _emitDue(_clock());
      _scheduleNext();
    });
  }

  static String refreshRateBucket(double refreshRateHz) {
    if (!refreshRateHz.isFinite || refreshRateHz <= 0) return 'unknown';
    if (refreshRateHz < 75) return '60_hz';
    if (refreshRateHz < 105) return '90_hz';
    if (refreshRateHz < 132) return '120_hz';
    if (refreshRateHz < 155) return '144_hz';
    if (refreshRateHz < 182) return '165_hz';
    return 'high_hz';
  }
}

class _FrameBurst {
  _FrameBurst({
    required this.generation,
    required this.startUs,
    required this.endUs,
    required double refreshRateHz,
    required this.stop,
  }) : _frameBudgetUs = 1000000 / refreshRateHz;

  final int generation;
  final int startUs;
  int endUs;
  final double _frameBudgetUs;
  final FramePerformanceTraceStop stop;

  int frameCount = 0;
  int overBudgetFrames = 0;
  int maxBuildUs = 0;
  int maxRasterUs = 0;
  int? firstVsyncUs;
  int? lastVsyncUs;
  final Set<int> _vsyncTimestamps = <int>{};

  void add(int vsyncStartUs, int buildUs, int rasterUs) {
    if (!_vsyncTimestamps.add(vsyncStartUs)) return;
    frameCount++;
    final first = firstVsyncUs;
    if (first == null || vsyncStartUs < first) firstVsyncUs = vsyncStartUs;
    final last = lastVsyncUs;
    if (last == null || vsyncStartUs > last) lastVsyncUs = vsyncStartUs;
    if (buildUs > _frameBudgetUs || rasterUs > _frameBudgetUs) {
      overBudgetFrames++;
    }
    if (buildUs > maxBuildUs) maxBuildUs = buildUs;
    if (rasterUs > maxRasterUs) maxRasterUs = rasterUs;
  }

  FramePerformanceReport get report {
    final first = firstVsyncUs;
    final last = lastVsyncUs;
    return FramePerformanceReport(
      generation: generation,
      frameCount: frameCount,
      overBudgetFrames: overBudgetFrames,
      maxBuildUs: maxBuildUs,
      maxRasterUs: maxRasterUs,
      activeDurationUs: first == null || last == null ? 0 : last - first,
    );
  }
}
