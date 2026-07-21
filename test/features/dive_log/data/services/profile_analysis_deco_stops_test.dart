import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/deco/ascent_rate_calculator.dart';
import 'package:submersion/core/deco/entities/o2_exposure.dart';
import 'package:submersion/features/dive_log/data/services/profile_analysis_service.dart';

void main() {
  test(
    'ProfileAnalysis stores and returns the decoStopCurve constructor argument',
    () {
      const analysis = ProfileAnalysis(
        ascentRates: [],
        ascentRateStats: AscentRateStats(
          maxAscentRate: 0,
          maxDescentRate: 0,
          averageAscentRate: 0,
          averageDescentRate: 0,
          violationCount: 0,
          criticalViolationCount: 0,
          timeInViolation: 0,
        ),
        ascentRateViolations: [],
        events: [],
        ceilingCurve: [0.0, 4.2, 6.0, 0.0],
        ndlCurve: [],
        decoStatuses: [],
        o2Exposure: O2Exposure(otu: 0),
        ppO2Curve: [],
        decoStopCurve: [0.0, 6.0, 6.0, 0.0],
        maxDepth: 0,
        averageDepth: 0,
        maxDepthTimestamp: 0,
        durationSeconds: 0,
      );

      expect(analysis.decoStopCurve, [0.0, 6.0, 6.0, 0.0]);
    },
  );

  test('copyWith replaces decoStopCurve', () {
    const analysis = ProfileAnalysis(
      ascentRates: [],
      ascentRateStats: AscentRateStats(
        maxAscentRate: 0,
        maxDescentRate: 0,
        averageAscentRate: 0,
        averageDescentRate: 0,
        violationCount: 0,
        criticalViolationCount: 0,
        timeInViolation: 0,
      ),
      ascentRateViolations: [],
      events: [],
      ceilingCurve: [],
      ndlCurve: [],
      decoStatuses: [],
      o2Exposure: O2Exposure(otu: 0),
      ppO2Curve: [],
      decoStopCurve: [3.0],
      maxDepth: 0,
      averageDepth: 0,
      maxDepthTimestamp: 0,
      durationSeconds: 0,
    );

    expect(analysis.copyWith(decoStopCurve: [9.0]).decoStopCurve, [9.0]);
    expect(analysis.copyWith().decoStopCurve, [3.0]);
  });

  test('analyze quantizes the real ceiling curve using the configured stop '
      'increment', () {
    // Non-default increment: if analyze() ever reads the wrong source
    // (e.g. a hardcoded 3.0 instead of the service's configured value),
    // this test fails even though a default-increment test would not.
    const stopIncrement = 2.0;
    final service = ProfileAnalysisService(decoStopIncrement: stopIncrement);

    // Constant 45 m for 25 minutes puts the diver well into a
    // decompression obligation with the service's default gradient
    // factors, so the ceiling curve has real non-zero entries to quantize.
    final depths = <double>[];
    final timestamps = <int>[];
    for (int t = 0; t <= 25 * 60; t += 60) {
      timestamps.add(t);
      depths.add(45.0);
    }

    final analysis = service.analyze(
      diveId: 'deco-stop-quantization',
      depths: depths,
      timestamps: timestamps,
    );

    expect(
      analysis.hadDecoObligation,
      isTrue,
      reason:
          'profile must actually incur deco stops to exercise '
          'quantization',
    );
    expect(analysis.decoStopCurve.length, analysis.ceilingCurve.length);

    var sawNonZeroStop = false;
    for (var i = 0; i < analysis.ceilingCurve.length; i++) {
      final ceiling = analysis.ceilingCurve[i];
      final stop = analysis.decoStopCurve[i];

      if (stop != 0.0) sawNonZeroStop = true;

      // Every stop sits on a multiple of the configured increment.
      expect(
        stop % stopIncrement,
        closeTo(0.0, 1e-9),
        reason:
            'stop $stop at index $i is not a multiple of '
            '$stopIncrement',
      );
      // The stop is the ceiling rounded up to that increment: it must
      // cover the ceiling and never overshoot by more than one increment.
      expect(stop, greaterThanOrEqualTo(ceiling - 1e-9));
      expect(stop, lessThan(ceiling + stopIncrement + 1e-9));
    }

    expect(
      sawNonZeroStop,
      isTrue,
      reason: 'expected at least one quantized stop above zero',
    );
  });
}
