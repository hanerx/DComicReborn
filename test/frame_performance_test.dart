import 'package:dcomic/utils/frame_performance.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late int nowUs;
  late List<FramePerformanceReport> reports;
  late List<Map<String, String>> attributes;

  FramePerformanceSampler createSampler({
    Duration activityTail = const Duration(milliseconds: 100),
    Duration lateTimingGrace = const Duration(milliseconds: 20),
  }) {
    nowUs = 0;
    reports = [];
    attributes = [];
    return FramePerformanceSampler(
      clock: () => nowUs,
      activityTail: activityTail,
      lateTimingGrace: lateTimingGrace,
      subscribeToScheduler: false,
      scheduleTimers: false,
      startTrace: (traceAttributes) {
        attributes.add(Map.of(traceAttributes));
        return (report, outcome) {
          expect(outcome, 'success');
          reports.add(report);
        };
      },
    );
  }

  test('uses per-stage refresh budget with the active route name', () {
    final sampler = createSampler();
    sampler.updateContext(screen: 'ComicViewerPage', refreshRateHz: 120);
    sampler.setActive(true);
    sampler.recordActivity();

    sampler.recordFrames(const [
      FramePerformanceSample(
        vsyncStartUs: 10_000,
        buildUs: 5_000,
        rasterUs: 5_000,
      ),
      FramePerformanceSample(
        vsyncStartUs: 20_000,
        buildUs: 8_334,
        rasterUs: 1_000,
      ),
    ]);
    nowUs = 120_000;
    sampler.flush();

    expect(reports, hasLength(1));
    expect(attributes.single, {
      'screen': 'ComicViewerPage',
      'refresh_rate_bucket': '120_hz',
    });
    expect(reports.single.metrics, {
      'frame_count': 2,
      'over_budget_frames': 1,
      'max_build_us': 8334,
      'max_raster_us': 5000,
      'active_duration_us': 10000,
      'fps_milli': 100000,
    });
  });

  test('idle gaps split bursts and never add idle time to FPS', () {
    final sampler = createSampler();
    sampler.updateContext(screen: 'ComicViewerPage', refreshRateHz: 59.94);
    sampler.setActive(true);
    sampler.recordActivity();
    sampler.recordFrames(const [
      FramePerformanceSample(
        vsyncStartUs: 50_000,
        buildUs: 1_000,
        rasterUs: 1_000,
      ),
    ]);

    nowUs = 300_000;
    sampler.recordActivity();
    sampler.recordFrames(const [
      FramePerformanceSample(
        vsyncStartUs: 200_000,
        buildUs: 1_000,
        rasterUs: 1_000,
      ),
      FramePerformanceSample(
        vsyncStartUs: 350_000,
        buildUs: 1_000,
        rasterUs: 1_000,
      ),
    ]);
    nowUs = 420_000;
    sampler.flush();

    expect(reports, hasLength(2));
    expect(reports.map((report) => report.frameCount), [1, 1]);
    expect(reports.map((report) => report.activeDurationUs), [0, 0]);
    expect(reports.map((report) => report.fpsMilli), [null, null]);
  });

  test(
    'late batches use vsync timestamps without crossing activity generations',
    () {
      final sampler = createSampler(
        lateTimingGrace: const Duration(milliseconds: 50),
      );
      sampler.updateContext(screen: 'ComicViewerPage', refreshRateHz: 60);
      sampler.setActive(true);
      sampler.recordActivity();

      nowUs = 50_000;
      sampler.setActive(false);
      nowUs = 60_000;
      sampler.setActive(true);
      sampler.recordActivity();
      nowUs = 90_000;
      sampler.recordFrames(const [
        FramePerformanceSample(
          vsyncStartUs: 40_000,
          buildUs: 1_000,
          rasterUs: 1_000,
        ),
        FramePerformanceSample(
          vsyncStartUs: 55_000,
          buildUs: 9_000,
          rasterUs: 9_000,
        ),
        FramePerformanceSample(
          vsyncStartUs: 70_000,
          buildUs: 2_000,
          rasterUs: 2_000,
        ),
      ]);
      nowUs = 100_000;
      sampler.dispose();

      expect(reports, hasLength(2));
      expect(reports[0].generation, isNot(reports[1].generation));
      expect(reports[0].frameCount, 1);
      expect(reports[1].frameCount, 1);
      expect(reports[1].metrics, isNot(contains('fps_milli')));
    },
  );

  test('FPS uses distinct observed frame intervals', () {
    final sampler = createSampler(
      activityTail: const Duration(milliseconds: 600),
    );
    sampler.updateContext(screen: 'ComicViewerPage', refreshRateHz: 60);
    sampler.setActive(true);
    sampler.recordActivity();
    sampler.recordFrames(const [
      FramePerformanceSample(
        vsyncStartUs: 10_000,
        buildUs: 1_000,
        rasterUs: 1_000,
      ),
      FramePerformanceSample(
        vsyncStartUs: 26_667,
        buildUs: 1_000,
        rasterUs: 1_000,
      ),
      FramePerformanceSample(
        vsyncStartUs: 43_334,
        buildUs: 1_000,
        rasterUs: 1_000,
      ),
      FramePerformanceSample(
        vsyncStartUs: 26_667,
        buildUs: 9_000,
        rasterUs: 9_000,
      ),
      FramePerformanceSample(
        vsyncStartUs: 60_001,
        buildUs: 1_000,
        rasterUs: 1_000,
      ),
    ]);
    nowUs = 620_000;
    sampler.flush();

    expect(reports.single.frameCount, 4);
    expect(reports.single.activeDurationUs, 50001);
    expect(reports.single.fpsMilli, closeTo(60000, 5));
  });

  test('screen or refresh changes split matching fixed attributes', () {
    final sampler = createSampler();
    sampler.updateContext(screen: 'ComicViewerPage', refreshRateHz: 60);
    sampler.setActive(true);
    sampler.recordActivity();
    nowUs = 40_000;
    sampler.updateContext(screen: 'SearchPage', refreshRateHz: 120);
    sampler.recordActivity();
    nowUs = 80_000;
    sampler.dispose();

    expect(attributes, [
      {'screen': 'ComicViewerPage', 'refresh_rate_bucket': '60_hz'},
      {'screen': 'SearchPage', 'refresh_rate_bucket': '120_hz'},
    ]);
  });

  test('inactive input is ignored and invalid refresh rate is unknown', () {
    final sampler = createSampler();
    sampler.updateContext(screen: 'ComicViewerPage', refreshRateHz: 0);
    sampler.recordActivity();
    nowUs = 200_000;
    sampler.flush();
    expect(reports, isEmpty);

    sampler.setActive(true);
    sampler.recordActivity();
    nowUs = 320_000;
    sampler.flush();
    expect(attributes.single['refresh_rate_bucket'], 'unknown');
    expect(reports.single.frameCount, 0);
  });
}
