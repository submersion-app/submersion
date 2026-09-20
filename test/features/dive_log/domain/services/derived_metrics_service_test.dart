import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_sample.dart';
import 'package:submersion/features/dive_log/domain/entities/derived_metrics.dart';
import 'package:submersion/features/dive_log/domain/services/derived_metrics_service.dart';

void main() {
  /// A square profile: descend, hold [bottomDepth] to [bottomEnd], ascend to
  /// [stopDepth] and hold it until [end], one sample every 10 s.
  List<ProfileSample> squareProfile({
    double bottomDepth = 30,
    int bottomEnd = 1800,
    double stopDepth = 5,
    int end = 2100,
    int? decoTypeAtStop,
  }) {
    final out = <ProfileSample>[];
    for (var t = 0; t <= end; t += 10) {
      double depth;
      if (t < 60) {
        depth = bottomDepth * (t / 60);
      } else if (t <= bottomEnd) {
        depth = bottomDepth;
      } else if (t <= bottomEnd + 120) {
        final f = (t - bottomEnd) / 120;
        depth = bottomDepth + (stopDepth - bottomDepth) * f;
      } else {
        depth = stopDepth;
      }
      out.add(
        ProfileSample(
          timestamp: t,
          depth: depth,
          decoType: t > bottomEnd + 120 ? decoTypeAtStop : null,
        ),
      );
    }
    return out;
  }

  /// A tank draining at a constant [barPerMin] of stored pressure.
  TankPressureSeries steadyTank({
    double start = 200,
    double barPerMin = 2,
    int end = 2100,
    double volume = 12,
  }) => TankPressureSeries(
    tankId: 't1',
    volumeLiters: volume,
    points: [
      for (var t = 0; t <= end; t += 10)
        (timestamp: t, bar: start - barPerMin * (t / 60)),
    ],
  );

  DiveDerivedMetrics run({
    List<ProfileSample>? samples,
    List<TankPressureSeries> tanks = const [],
    DiveMode mode = DiveMode.oc,
  }) => DerivedMetricsService.compute(
    diveId: 'd1',
    samples: samples ?? squareProfile(),
    tanks: tanks,
    diveMode: mode,
    sourceUpdatedAt: 111,
    computedAtMs: 222,
  );

  group('unsupported dives', () {
    test('a gauge dive derives nothing', () {
      final m = run(tanks: [steadyTank()], mode: DiveMode.gauge);
      expect(m.unsupportedReason, UnsupportedReason.gaugeMode);
      expect(m.hasSac, isFalse);
      expect(m.hasFinalStop, isFalse);
      expect(m.engineVersion, DerivedMetricsService.version);
      expect(m.sourceUpdatedAt, 111);
    });

    test('a profile with under two samples is too short', () {
      final m = run(samples: [const ProfileSample(timestamp: 0, depth: 0)]);
      expect(m.unsupportedReason, UnsupportedReason.tooShort);
    });

    test('gauge mode wins over a short profile', () {
      final m = run(
        samples: [const ProfileSample(timestamp: 0, depth: 0)],
        mode: DiveMode.gauge,
      );
      expect(m.unsupportedReason, UnsupportedReason.gaugeMode);
    });

    test('no usable tank means no SAC, but the final stop still lands', () {
      final m = run();
      expect(m.unsupportedReason, UnsupportedReason.noPressureSeries);
      expect(m.hasSac, isFalse);
      expect(m.finalStopKind, FinalStopKind.safety);
    });

    test('a tank with no volume is not usable', () {
      final m = run(
        tanks: [
          const TankPressureSeries(
            tankId: 't1',
            points: [(timestamp: 0, bar: 200), (timestamp: 600, bar: 180)],
          ),
        ],
      );
      expect(m.unsupportedReason, UnsupportedReason.noPressureSeries);
    });
  });

  group('final stop', () {
    test('a steady safety stop is stable', () {
      final m = run(tanks: [steadyTank()]);
      expect(m.finalStopKind, FinalStopKind.safety);
      expect(m.finalStopDurationSeconds, greaterThanOrEqualTo(120));
      expect(m.finalStopDepthStdDevMeters, closeTo(0, 0.01));
      expect(m.finalStopMaxExcursionMeters, closeTo(0, 0.01));
    });

    test('a deco-flagged stop is reported as deco', () {
      final m = run(
        samples: squareProfile(decoTypeAtStop: 2),
        tanks: [steadyTank()],
      );
      expect(m.finalStopKind, FinalStopKind.deco);
    });

    test('a wandering stop reports its excursion', () {
      // The diver porpoises between 3.5 m and 6.5 m around a 5 m median.
      final samples = squareProfile();
      final wandering = [
        for (final s in samples)
          if (s.timestamp <= 1920)
            s
          else
            ProfileSample(
              timestamp: s.timestamp,
              depth: 5 + ((s.timestamp ~/ 10) % 2 == 0 ? 1.5 : -1.5),
            ),
      ];
      final m = run(samples: wandering, tanks: [steadyTank()]);
      expect(m.finalStopKind, FinalStopKind.safety);
      expect(m.finalStopMaxExcursionMeters, closeTo(1.5, 0.2));
      expect(m.finalStopDepthStdDevMeters, greaterThan(1.0));
    });

    test('a dive that surfaces straight from depth has no final stop', () {
      final straight = [
        for (var t = 0; t <= 600; t += 10)
          ProfileSample(timestamp: t, depth: t < 540 ? 30 : 30 - (t - 540) / 2),
      ];
      final m = run(samples: straight, tanks: [steadyTank(end: 600)]);
      expect(m.finalStopKind, FinalStopKind.none);
      expect(m.finalStopDurationSeconds, isNull);
    });

    test('a stop shorter than a minute does not count', () {
      final brief = [
        for (var t = 0; t <= 640; t += 10)
          ProfileSample(
            timestamp: t,
            depth: t < 560 ? 30 : (t < 600 ? 30 - (t - 560) / 1.6 : 5),
          ),
      ];
      final m = run(samples: brief, tanks: [steadyTank(end: 640)]);
      expect(m.finalStopKind, FinalStopKind.none);
    });
  });

  group('SAC', () {
    test('a steady tank on a square profile gives flat buckets', () {
      final m = run(tanks: [steadyTank()]);
      expect(m.hasSac, isTrue);
      expect(m.unsupportedReason, isNull);
      expect(m.sacBuckets.length, greaterThanOrEqualTo(6));
      expect(m.sacBuckets.first.index, 0);
      // Bottom buckets sit at 30 m (4 ata): 2 bar/min of stored pressure is
      // 0.5 bar/min at surface.
      expect(m.sacBuckets[2].sacBarPerMin, closeTo(0.5, 0.05));
      expect(m.sacMeanBarPerMin, greaterThan(0));
      expect(m.sacSlopeBarPerMinPerMin, isNotNull);
    });

    test('a rising consumption gives a positive slope', () {
      // Drop accelerates: 1 bar/min for the first half, 4 for the second.
      final points = <({int timestamp, double bar})>[];
      var bar = 220.0;
      for (var t = 0; t <= 1800; t += 10) {
        points.add((timestamp: t, bar: bar));
        bar -= (t < 900 ? 1.0 : 4.0) / 6;
      }
      final m = run(
        samples: squareProfile(bottomEnd: 1500, end: 1800),
        tanks: [
          TankPressureSeries(tankId: 't1', volumeLiters: 12, points: points),
        ],
      );
      expect(m.trend(), SacTrend.rising);
      expect(m.sacSlopeBarPerMinPerMin, greaterThan(0));
    });

    test('the tank with the largest drop wins', () {
      final m = run(
        tanks: [
          const TankPressureSeries(
            tankId: 'stage',
            volumeLiters: 11,
            points: [(timestamp: 0, bar: 200), (timestamp: 1800, bar: 195)],
          ),
          steadyTank(),
        ],
      );
      expect(m.hasSac, isTrue);
      // The steady tank drops 70 bar over the dive and is the reference.
      expect(m.sacMeanBarPerMin, greaterThan(0.2));
    });

    test('a bucket where pressure rises is skipped, not recorded as zero', () {
      final points = <({int timestamp, double bar})>[
        for (var t = 0; t <= 600; t += 10) (timestamp: t, bar: 200 - t / 60),
        // A tank swap puts the pressure back up.
        for (var t = 610; t <= 1200; t += 10) (timestamp: t, bar: 230 - t / 60),
      ];
      final m = run(
        samples: squareProfile(bottomEnd: 900, end: 1200),
        tanks: [
          TankPressureSeries(tankId: 't1', volumeLiters: 12, points: points),
        ],
      );
      expect(m.sacBuckets.every((b) => b.sacBarPerMin > 0), isTrue);
      expect(m.sacBuckets.map((b) => b.index), isNot(contains(2)));
    });

    test('a single bucket yields a mean but no slope', () {
      final m = run(
        samples: squareProfile(bottomEnd: 120, end: 240),
        tanks: [steadyTank(end: 240)],
      );
      expect(m.sacMeanBarPerMin, isNotNull);
      expect(m.sacSlopeBarPerMinPerMin, isNull);
    });
  });

  test('isCurrent compares the engine version and the dive stamp', () {
    final m = run(tanks: [steadyTank()]);
    expect(DerivedMetricsService.isCurrent(m, 111), isTrue);
    expect(DerivedMetricsService.isCurrent(m, 112), isFalse);
  });
}
