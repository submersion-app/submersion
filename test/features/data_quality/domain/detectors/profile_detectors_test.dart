import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/data_quality/domain/detectors/depth_spike_detector.dart';
import 'package:submersion/features/data_quality/domain/detectors/impossible_rate_detector.dart';
import 'package:submersion/features/data_quality/domain/detectors/sample_gap_detector.dart';
import 'package:submersion/features/data_quality/domain/entities/dive_quality_context.dart';
import 'package:submersion/features/data_quality/domain/entities/quality_finding.dart';

import '../../helpers/quality_test_helpers.dart';

void main() {
  group('SampleGapDetector', () {
    const det = SampleGapDetector();

    test('clean 10 s profile has no findings', () {
      final ctx = makeContext(dive: makeTestDive(), samples: flatProfile());
      expect(det.detect(ctx), isEmpty);
    });

    test('one 120 s hole in a 10 s profile is an info finding', () {
      // median interval 10 s -> threshold max(20, 30) = 30 s; a 120 s jump
      // is one gap. total 120 < 10% of 2400 -> info.
      final samples = [
        for (var t = 0; t <= 1000; t += 10) QualitySample(t: t, depth: 20),
        for (var t = 1120; t <= 2400; t += 10) QualitySample(t: t, depth: 20),
      ];
      final ctx = makeContext(dive: makeTestDive(), samples: samples);
      final out = det.detect(ctx);
      expect(out, hasLength(1));
      expect(out.single.severity, QualitySeverity.info);
      expect(out.single.params['gapCount'], 1);
      expect(out.single.params['longestGapSeconds'], 120);
    });

    test('gaps totalling >10% of runtime escalate to warning', () {
      // Three 120 s holes = 360 s > 10% of ~2400 s runtime.
      final samples = <QualitySample>[];
      var t = 0;
      for (final holeAt in [400, 1000, 1600]) {
        while (t < holeAt) {
          samples.add(QualitySample(t: t, depth: 20));
          t += 10;
        }
        t += 120;
      }
      while (t <= 2400) {
        samples.add(QualitySample(t: t, depth: 20));
        t += 10;
      }
      final ctx = makeContext(dive: makeTestDive(), samples: samples);
      final out = det.detect(ctx);
      expect(out.single.severity, QualitySeverity.warning);
      expect(out.single.params['gapCount'], 3);
    });
  });

  group('DepthSpikeDetector', () {
    const det = DepthSpikeDetector();

    test('single-sample 35 m excursion at 10 s interval is a spike', () {
      // 35 m in 10 s = 3.5 m/s > 3.0 both directions, opposite signs.
      final samples = [
        for (var t = 0; t <= 600; t += 10)
          QualitySample(t: t, depth: t == 300 ? 55.0 : 20.0),
      ];
      final ctx = makeContext(
        dive: makeTestDive(maxDepth: 20),
        samples: samples,
      );
      final out = det.detect(ctx);
      final spike = out.singleWhere(
        (f) => (f.params['atSeconds'] as int?) == 300,
      );
      expect(spike.params['impliedRateMetersPerSecond'], closeTo(3.5, 1e-9));
    });

    test('negative depth samples produce one finding', () {
      final samples = [
        const QualitySample(t: 0, depth: 5),
        const QualitySample(t: 10, depth: -1.2),
        const QualitySample(t: 20, depth: 5),
      ];
      // -1.2 m in 10 s is only 0.62 m/s each way -- not a spike, so exactly
      // one finding (the negative-depth one) fires.
      final ctx = makeContext(
        dive: makeTestDive(maxDepth: 5),
        samples: samples,
      );
      final out = det.detect(ctx);
      expect(out, hasLength(1));
      expect(out.single.params['minDepth'], -1.2);
    });

    test('stored maxDepth 40 vs profile max 30 mismatches (> 1.5 m tol)', () {
      // tol = max(0.5, 30 * 0.05) = 1.5; |40-30| = 10 > 1.5.
      final ctx = makeContext(
        dive: makeTestDive(maxDepth: 40),
        samples: flatProfile(depth: 30),
      );
      final out = det.detect(ctx);
      expect(out, hasLength(1));
      expect(out.single.params['storedMaxDepth'], 40);
      expect(out.single.params['profileMaxDepth'], 30);
    });
  });

  group('ImpossibleRateDetector', () {
    const det = ImpossibleRateDetector();

    test('36 m/min sustained 40 s is flagged', () {
      // 6 m per 10 s sample = 36 m/min for t in [100, 140].
      final samples = [
        for (var t = 0; t <= 100; t += 10) QualitySample(t: t, depth: 40),
        const QualitySample(t: 110, depth: 34),
        const QualitySample(t: 120, depth: 28),
        const QualitySample(t: 130, depth: 22),
        const QualitySample(t: 140, depth: 16),
        for (var t = 150; t <= 300; t += 10) QualitySample(t: t, depth: 16),
      ];
      final ctx = makeContext(dive: makeTestDive(), samples: samples);
      final out = det.detect(ctx);
      expect(out, hasLength(1));
      expect(out.single.params['durationSeconds'], 40);
      expect(out.single.params['maxRateMetersPerMinute'], closeTo(36.0, 1e-9));
    });

    test('a 20 s burst is below the 30 s sustain threshold', () {
      final samples = [
        for (var t = 0; t <= 100; t += 10) QualitySample(t: t, depth: 40),
        const QualitySample(t: 110, depth: 34),
        const QualitySample(t: 120, depth: 28),
        for (var t = 130; t <= 300; t += 10) QualitySample(t: t, depth: 28),
      ];
      final ctx = makeContext(dive: makeTestDive(), samples: samples);
      expect(det.detect(ctx), isEmpty);
    });

    test('normal 9 m/min ascent is clean', () {
      final samples = [
        for (var t = 0; t <= 200; t += 10)
          QualitySample(t: t, depth: 30 - t * (9.0 / 60 / 10) * 10),
      ];
      final ctx = makeContext(dive: makeTestDive(), samples: samples);
      expect(det.detect(ctx), isEmpty);
    });
  });
}
