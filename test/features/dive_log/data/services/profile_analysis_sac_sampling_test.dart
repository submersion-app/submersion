import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/data/services/profile_analysis_service.dart';

/// The same dive reads the same SAC however densely it was sampled: depth and
/// pressure are piecewise linear between samples, so a window or a segment
/// that starts or ends between two samples is read there (#3975).
void main() {
  late ProfileAnalysisService service;

  setUp(() {
    service = ProfileAnalysisService(gfLow: 1.0, gfHigh: 1.0);
  });

  ProfileAnalysis analyze(
    List<int> timestamps,
    List<double> depths,
    List<double> pressures,
  ) => service.analyze(
    diveId: 'sac-sampling',
    timestamps: timestamps,
    depths: depths,
    pressures: pressures,
  );

  group('rolling SAC window', () {
    test('reads pressure at both edges of the window, between samples', () {
      // The 60 s window around t = 100 runs from 70 to 130 s: P(70) = 193 and
      // P(130) = 178, so 15 bar in a minute at 3.0 bar ambient.
      final analysis = analyze(
        const [0, 100, 200],
        const [20.0, 20.0, 20.0],
        const [200.0, 190.0, 150.0],
      );

      expect(analysis.smoothedSacCurve![1], closeTo(5.0, 1e-9));
    });

    test('reads depth at both edges of the window, between samples', () {
      // The window runs from 70 to 130 s: D(70) = 17 m, D(100) = 20 m,
      // D(130) = 26 m, so the mean is 20.75 m. 6 bar/min at 3.075 bar ambient.
      final analysis = analyze(
        const [0, 100, 200],
        const [10.0, 20.0, 40.0],
        const [205.0, 195.0, 185.0],
      );

      expect(analysis.smoothedSacCurve![1], closeTo(6 / 3.075, 1e-9));
    });

    test('stops at the ends of the dive', () {
      // At t = 0 the window holds only its later half: 2 bar in 30 s.
      final analysis = analyze(
        const [0, 60, 120],
        const [20.0, 20.0, 20.0],
        const [200.0, 196.0, 192.0],
      );

      expect(analysis.smoothedSacCurve!.first, closeTo(4 / 3, 1e-9));
    });

    test('a burst of samples in a still stretch keeps the rolling curve', () {
      // 2 bar/min for 10 minutes, 6 bar/min for 10 more, then a minute of no
      // consumption logged every second. Most samples read zero, but only a
      // sliver of the dive's time does, so the rolling curve stands: 6 bar/min
      // at t = 660, where the 5-minute segments would interpolate to 4.8.
      final timestamps = [
        for (var t = 0; t < 1200; t += 60) t,
        for (var t = 1200; t <= 1260; t++) t,
      ];
      double pressure(int t) {
        if (t <= 600) return 200 - 2 * t / 60;
        if (t <= 1200) return 180 - 6 * (t - 600) / 60;
        return 120;
      }

      final analysis = analyze(
        timestamps,
        List<double>.filled(timestamps.length, 20.0),
        timestamps.map(pressure).toList(),
      );

      final sample = timestamps.indexOf(660);
      expect(analysis.smoothedSacCurve![sample], closeTo(2.0, 1e-9));
    });
  });

  group('SAC segments', () {
    test('read pressure at their boundaries, so no gas falls between', () {
      // The boundary at 300 s lies between samples: P(300) = 180, so both
      // segments burn 20 bar. Stopping at the samples either side would drop
      // the 20 bar between t = 200 and t = 400.
      final segments = analyze(
        const [0, 200, 400, 600],
        const [20.0, 20.0, 20.0, 20.0],
        const [200.0, 190.0, 170.0, 160.0],
      ).sacSegments!;

      expect(segments.map((s) => s.startTimestamp), [0, 300]);
      expect(segments.map((s) => s.endTimestamp), [300, 600]);
      expect(segments.map((s) => s.gasConsumed), [
        closeTo(20, 1e-9),
        closeTo(20, 1e-9),
      ]);
      expect(segments.first.sacRate, closeTo(4 / 3, 1e-9));
    });

    test('read depth at their boundaries', () {
      final segments = analyze(const [0, 600], const [10.0, 30.0], const [
        200.0,
        170.0,
      ]).sacSegments!;

      expect(segments.map((s) => s.minDepth), [
        closeTo(10, 1e-9),
        closeTo(20, 1e-9),
      ]);
      expect(segments.map((s) => s.maxDepth), [
        closeTo(20, 1e-9),
        closeTo(30, 1e-9),
      ]);
      expect(segments.map((s) => s.avgDepth), [
        closeTo(15, 1e-9),
        closeTo(25, 1e-9),
      ]);
    });
  });

  test('a dive resampled every second reads the same SAC', () {
    const knotTimes = [0, 45, 130, 200, 330, 420, 700, 905];
    const knotDepths = [5.0, 18.0, 30.0, 30.0, 12.0, 6.0, 6.0, 3.0];
    const knotPressures = [
      220.0,
      214.0,
      199.0,
      187.0,
      170.0,
      165.0,
      150.0,
      146.0,
    ];

    double at(List<double> series, int time) {
      final next = knotTimes.indexWhere((t) => t >= time);
      if (knotTimes[next] == time) return series[next];
      final from = next - 1;
      final progress =
          (time - knotTimes[from]) / (knotTimes[next] - knotTimes[from]);
      return series[from] + (series[next] - series[from]) * progress;
    }

    final sparse = analyze(knotTimes, knotDepths, knotPressures);
    final denseTimes = List<int>.generate(906, (i) => i);
    final dense = analyze(
      denseTimes,
      denseTimes.map((t) => at(knotDepths, t)).toList(),
      denseTimes.map((t) => at(knotPressures, t)).toList(),
    );

    for (var i = 0; i < knotTimes.length; i++) {
      expect(
        dense.smoothedSacCurve![knotTimes[i]],
        closeTo(sparse.smoothedSacCurve![i], 1e-9),
        reason: 't = ${knotTimes[i]}',
      );
    }
    expect(dense.sacSegments, hasLength(sparse.sacSegments!.length));
    for (var i = 0; i < sparse.sacSegments!.length; i++) {
      final expected = sparse.sacSegments![i];
      final actual = dense.sacSegments![i];
      expect(actual.startTimestamp, expected.startTimestamp);
      expect(actual.endTimestamp, expected.endTimestamp);
      expect(actual.sacRate, closeTo(expected.sacRate, 1e-9));
      expect(actual.gasConsumed, closeTo(expected.gasConsumed, 1e-9));
      expect(actual.avgDepth, closeTo(expected.avgDepth, 1e-9));
      expect(actual.minDepth, closeTo(expected.minDepth, 1e-9));
      expect(actual.maxDepth, closeTo(expected.maxDepth, 1e-9));
    }
  });
}
