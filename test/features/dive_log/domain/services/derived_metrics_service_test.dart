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

    test('a tank with no volume still gives SAC, which is in bar/min', () {
      // Many imported cylinders never get a size; SAC as pressure per minute
      // does not need one, so the trend must not go empty without it.
      final m = run(
        tanks: [TankPressureSeries(tankId: 't1', points: steadyTank().points)],
      );
      expect(m.unsupportedReason, isNull);
      expect(m.hasSac, isTrue);
      expect(m.sacTrend, isNotNull);
    });
  });

  group('final stop', () {
    test('a steady safety stop is stable', () {
      final m = run(tanks: [steadyTank()]);
      expect(m.finalStopKind, FinalStopKind.safety);
      expect(m.finalStopDurationSeconds, greaterThanOrEqualTo(120));
      expect(m.finalStopDepthStdDevMeters, closeTo(0, 0.01));
      expect(m.finalStopMaxExcursionMeters, closeTo(0, 0.01));
      expect(m.finalStopState, FinalStopState.stable);
    });

    test('a deco-flagged stop is reported as deco', () {
      final m = run(
        samples: squareProfile(decoTypeAtStop: 2),
        tanks: [steadyTank()],
      );
      expect(m.finalStopKind, FinalStopKind.deco);
    });

    /// A real dive's end: 20 m bottom, an arrival at [stopDepth] at
    /// [arriveRate] m/min, a stop of [stopSeconds], an ascent to the surface
    /// at [ascentRate] m/min, then [surfaceSeconds] logged at the surface.
    /// One sample every 10 s, as a dive computer writes them.
    List<ProfileSample> realEnd({
      double stopDepth = 5,
      double arriveRate = 9,
      int stopSeconds = 180,
      double ascentRate = 9,
      int surfaceSeconds = 0,
    }) {
      final out = <ProfileSample>[];
      var t = 0;
      void at(double depth) {
        out.add(ProfileSample(timestamp: t, depth: depth));
        t += 10;
      }

      for (var i = 0; i < 90; i++) {
        at(20);
      }
      for (var d = 20 - arriveRate / 6; d > stopDepth; d -= arriveRate / 6) {
        at(d);
      }
      for (var i = 0; i < stopSeconds ~/ 10; i++) {
        at(stopDepth);
      }
      for (var d = stopDepth - ascentRate / 6; d > 0; d -= ascentRate / 6) {
        at(d);
      }
      for (var i = 0; i <= surfaceSeconds ~/ 10; i++) {
        at(0);
      }
      return out;
    }

    void expectTextbookStop(DiveDerivedMetrics m, {double depth = 5}) {
      expect(m.finalStopState, FinalStopState.stable);
      expect(m.finalStopDurationSeconds, inInclusiveRange(170, 240));
      expect(m.finalStopMaxExcursionMeters, lessThan(kFinalStopUnstableMeters));
      expect(m.finalStopKind, FinalStopKind.safety);
    }

    test('a stop followed by a normal ascent to the surface is stable', () {
      expectTextbookStop(run(samples: realEnd()));
    });

    test('a stop followed by a slow ascent is stable', () {
      expectTextbookStop(run(samples: realEnd(ascentRate: 3)));
    });

    test('a shallow 3 m stop is stable', () {
      expectTextbookStop(run(samples: realEnd(stopDepth: 3)), depth: 3);
    });

    test('a minute logged at the surface does not end the stop', () {
      expectTextbookStop(run(samples: realEnd(surfaceSeconds: 60)));
    });

    test('a transit sample on the way to the stop is not an excursion', () {
      // 10 m/min leaves one sample at 6.67 m between the bottom and 5 m.
      expectTextbookStop(run(samples: realEnd(arriveRate: 10, ascentRate: 10)));
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
      expect(m.finalStopState, FinalStopState.noStop);
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

    test('a stop that strays over a metre from its median is unstable', () {
      // 3.6 m and 6.4 m alternate: a spread of 2.8 m keeps it one level run,
      // and the median of 5.0 m puts every sample 1.4 m away.
      final samples = [
        for (var t = 0; t <= 1200; t += 10)
          ProfileSample(
            timestamp: t,
            depth: t < 900 ? 20 : ((t ~/ 10).isEven ? 3.6 : 6.4),
          ),
      ];
      final m = run(samples: samples);
      expect(
        m.finalStopMaxExcursionMeters,
        greaterThan(kFinalStopUnstableMeters),
      );
      expect(m.finalStopState, FinalStopState.unstable);
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
      expect(m.sacTrend, SacTrend.rising);
      expect(m.sacSlopeBarPerMinPerMin, greaterThan(0));
      expect(m.sacChangePercent, greaterThan(50));
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
      expect(m.sacChangePercent, isNull);
    });

    test('a short last slice at the surface is not a bucket', () {
      // 20 s logged at the surface after a 30 minute level dive: a slice
      // that short, at one atmosphere, would count as much as a whole five
      // minutes at depth and fake a rise.
      final level = [
        for (var t = 0; t <= 1800; t += 10)
          ProfileSample(timestamp: t, depth: 20),
        const ProfileSample(timestamp: 1810, depth: 0),
        const ProfileSample(timestamp: 1820, depth: 0),
      ];
      final m = run(samples: level, tanks: [steadyTank(end: 1820)]);
      expect(m.sacBuckets, hasLength(6));
      expect(m.sacChangePercent, closeTo(0, 1));
    });

    test('a steady tank at a steady depth does not change', () {
      final level = [
        for (var t = 0; t <= 1800; t += 10)
          ProfileSample(timestamp: t, depth: 20),
      ];
      final m = run(samples: level, tanks: [steadyTank(end: 1800)]);
      expect(m.sacChangePercent, closeTo(0, 1));
      expect(m.sacTrend, SacTrend.steady);
    });
  });

  test('isCurrent compares the engine version and the dive stamp', () {
    final m = run(tanks: [steadyTank()]);
    expect(DerivedMetricsService.isCurrent(m, 111), isTrue);
    expect(DerivedMetricsService.isCurrent(m, 112), isFalse);
  });

  test('a rebreather dive has no SAC but keeps its final stop', () {
    // A diluent or oxygen bottle's pressure drop is not open-circuit gas
    // consumption, so no SAC trend or change; the depth track still shows
    // the stop.
    for (final mode in [DiveMode.ccr, DiveMode.scr]) {
      final m = run(mode: mode, tanks: [steadyTank()]);
      expect(
        m.unsupportedReason,
        UnsupportedReason.rebreather,
        reason: '$mode',
      );
      expect(m.sacMeanBarPerMin, isNull, reason: '$mode');
      expect(m.sacTrend, isNull, reason: '$mode');
      expect(m.finalStopState, FinalStopState.stable, reason: '$mode');
    }
  });
}
