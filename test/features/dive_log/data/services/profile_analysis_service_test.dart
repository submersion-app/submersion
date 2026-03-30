import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/deco/buhlmann_algorithm.dart';
import 'package:submersion/core/deco/constants/buhlmann_coefficients.dart';
import 'package:submersion/features/dive_log/data/services/profile_analysis_service.dart';
import 'package:submersion/features/dive_log/domain/entities/profile_event.dart';

void main() {
  group('ProfileAnalysisService cumulative support', () {
    late ProfileAnalysisService service;

    setUp(() {
      service = ProfileAnalysisService(gfLow: 1.0, gfHigh: 1.0);
    });

    test(
      'analyze with startCompartments should produce shorter NDL than fresh',
      () {
        // Create pre-loaded compartments from a simulated first dive
        final preAlgorithm = BuhlmannAlgorithm(gfLow: 1.0, gfHigh: 1.0);
        preAlgorithm.calculateSegment(
          depthMeters: 30.0,
          durationSeconds: 20 * 60,
          fN2: airN2Fraction,
        );
        // 60 min surface interval
        preAlgorithm.calculateSegment(
          depthMeters: 0.0,
          durationSeconds: 60 * 60,
          fN2: airN2Fraction,
        );
        final residualCompartments = preAlgorithm.compartments;

        // Build a 30-min dive at 18m
        final depths = <double>[];
        final timestamps = <int>[];
        for (int t = 0; t <= 30 * 60; t += 60) {
          timestamps.add(t);
          depths.add(18.0);
        }

        // Analyze with residual loading
        final cumulative = service.analyze(
          diveId: 'test-cumulative',
          depths: depths,
          timestamps: timestamps,
          startCompartments: residualCompartments,
        );

        // Analyze fresh (no residual)
        final fresh = service.analyze(
          diveId: 'test-fresh',
          depths: depths,
          timestamps: timestamps,
        );

        // Last NDL value should be shorter for cumulative
        expect(
          cumulative.ndlCurve.last,
          lessThan(fresh.ndlCurve.last),
          reason: 'Cumulative tissue loading should reduce NDL',
        );
      },
    );

    test('analyze with startOtu should set otuStart on O2Exposure', () {
      final depths = <double>[];
      final timestamps = <int>[];
      for (int t = 0; t <= 30 * 60; t += 60) {
        timestamps.add(t);
        depths.add(18.0);
      }

      final result = service.analyze(
        diveId: 'test-otu',
        depths: depths,
        timestamps: timestamps,
        o2Fraction: 0.32, // EAN32 for meaningful OTU
        startOtu: 120.0,
      );

      expect(result.o2Exposure.otuStart, equals(120.0));
      expect(result.o2Exposure.otuDaily, equals(120.0 + result.o2Exposure.otu));
    });

    test(
      'analyze without startCompartments should use surface-saturated state',
      () {
        final depths = <double>[];
        final timestamps = <int>[];
        for (int t = 0; t <= 30 * 60; t += 60) {
          timestamps.add(t);
          depths.add(18.0);
        }

        // Two calls without startCompartments should produce identical results
        final result1 = service.analyze(
          diveId: 'test-1',
          depths: depths,
          timestamps: timestamps,
        );
        final result2 = service.analyze(
          diveId: 'test-2',
          depths: depths,
          timestamps: timestamps,
        );

        expect(result1.ndlCurve, equals(result2.ndlCurve));
      },
    );

    test(
      'analyze with wrong-length startCompartments throws ArgumentError',
      () {
        final depths = <double>[18.0, 18.0, 18.0];
        final timestamps = <int>[0, 60, 120];

        // Create a list with wrong number of compartments (5 instead of 16)
        final algorithm = BuhlmannAlgorithm(gfLow: 1.0, gfHigh: 1.0);
        final wrongCompartments = algorithm.compartments.sublist(0, 5);

        expect(
          () => service.analyze(
            diveId: 'test-wrong-length',
            depths: depths,
            timestamps: timestamps,
            startCompartments: wrongCompartments,
          ),
          throwsA(
            isA<ArgumentError>().having(
              (e) => e.message,
              'message',
              contains('$zhl16CompartmentCount'),
            ),
          ),
        );
      },
    );

    test('analyze with negative startOtu throws ArgumentError', () {
      final depths = <double>[18.0, 18.0, 18.0];
      final timestamps = <int>[0, 60, 120];

      expect(
        () => service.analyze(
          diveId: 'test-negative-otu',
          depths: depths,
          timestamps: timestamps,
          startOtu: -10.0,
        ),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('non-negative'),
          ),
        ),
      );
    });
  });

  group('Safety stop detection', () {
    late ProfileAnalysisService service;

    setUp(() {
      service = ProfileAnalysisService(gfLow: 1.0, gfHigh: 1.0);
    });

    /// Build a dive profile: descend to [maxDepth] over 2 min, hold for
    /// [bottomMinutes], ascend and pause at [stopDepth] for
    /// [stopMinutes], then surface over 1 min. 1-second sample interval.
    ({List<double> depths, List<int> timestamps}) buildDiveProfile({
      required double maxDepth,
      int bottomMinutes = 10,
      double stopDepth = 5.0,
      int stopMinutes = 3,
    }) {
      final depths = <double>[];
      final timestamps = <int>[];
      var t = 0;

      // Descent: 2 minutes to maxDepth
      for (var s = 0; s <= 120; s++) {
        timestamps.add(t);
        depths.add(maxDepth * s / 120.0);
        t++;
      }

      // Bottom time
      for (var s = 0; s < bottomMinutes * 60; s++) {
        timestamps.add(t);
        depths.add(maxDepth);
        t++;
      }

      // Ascent to stop depth: 1 minute
      for (var s = 0; s <= 60; s++) {
        timestamps.add(t);
        depths.add(maxDepth - (maxDepth - stopDepth) * s / 60.0);
        t++;
      }

      // Hold at stop depth
      for (var s = 0; s < stopMinutes * 60; s++) {
        timestamps.add(t);
        depths.add(stopDepth);
        t++;
      }

      // Surface: 1 minute
      for (var s = 0; s <= 60; s++) {
        timestamps.add(t);
        depths.add(stopDepth * (1 - s / 60.0));
        t++;
      }

      return (depths: depths, timestamps: timestamps);
    }

    List<ProfileEvent> safetyStopEvents(ProfileAnalysis result) {
      return result.events
          .where(
            (e) =>
                e.eventType == ProfileEventType.safetyStopStart ||
                e.eventType == ProfileEventType.safetyStopEnd,
          )
          .toList();
    }

    group('max depth gate', () {
      test('shallow dive at 5m produces no safety stop events', () {
        final profile = buildDiveProfile(maxDepth: 5.0, stopDepth: 4.0);
        final result = service.analyze(
          diveId: 'shallow',
          depths: profile.depths,
          timestamps: profile.timestamps,
        );
        expect(safetyStopEvents(result), isEmpty);
      });

      test('dive at exactly 10m with stop produces safety stop events', () {
        final profile = buildDiveProfile(maxDepth: 10.0);
        final result = service.analyze(
          diveId: 'threshold',
          depths: profile.depths,
          timestamps: profile.timestamps,
        );
        expect(safetyStopEvents(result), isNotEmpty);
      });

      test('dive at 9.9m produces no safety stop events', () {
        final profile = buildDiveProfile(maxDepth: 9.9);
        final result = service.analyze(
          diveId: 'below-threshold',
          depths: profile.depths,
          timestamps: profile.timestamps,
        );
        expect(safetyStopEvents(result), isEmpty);
      });
    });

    group('ascent-phase restriction', () {
      test('stop during descent is not detected', () {
        // Dive that descends through 3-6m slowly (>2min), then goes to 20m
        final depths = <double>[];
        final timestamps = <int>[];
        var t = 0;

        // Slow descent through safety stop zone: 3 minutes at 4-5m
        for (var s = 0; s <= 180; s++) {
          timestamps.add(t);
          depths.add(3.0 + 2.0 * s / 180.0); // 3m -> 5m over 3 min
          t++;
        }

        // Continue descent to 20m over 1 minute
        for (var s = 1; s <= 60; s++) {
          timestamps.add(t);
          depths.add(5.0 + 15.0 * s / 60.0);
          t++;
        }

        // Bottom at 20m for 10 minutes
        for (var s = 0; s < 600; s++) {
          timestamps.add(t);
          depths.add(20.0);
          t++;
        }

        // Fast ascent to surface (no safety stop), 2 minutes
        for (var s = 0; s <= 120; s++) {
          timestamps.add(t);
          depths.add(20.0 * (1 - s / 120.0));
          t++;
        }

        final result = service.analyze(
          diveId: 'descent-stop',
          depths: depths,
          timestamps: timestamps,
        );
        expect(safetyStopEvents(result), isEmpty);
      });

      test('stop during bottom phase is not detected', () {
        final depths = <double>[];
        final timestamps = <int>[];
        var t = 0;

        // Quick descent to 20m
        for (var s = 0; s <= 60; s++) {
          timestamps.add(t);
          depths.add(20.0 * s / 60.0);
          t++;
        }

        // Bottom at 20m for 5 minutes
        for (var s = 0; s < 300; s++) {
          timestamps.add(t);
          depths.add(20.0);
          t++;
        }

        // Rise to 5m for 3 minutes (simulating bottom excursion, before max depth)
        for (var s = 0; s <= 30; s++) {
          timestamps.add(t);
          depths.add(20.0 - 15.0 * s / 30.0);
          t++;
        }
        for (var s = 0; s < 180; s++) {
          timestamps.add(t);
          depths.add(5.0);
          t++;
        }

        // Go back to 20m (this makes 20m the max depth point later)
        for (var s = 0; s <= 30; s++) {
          timestamps.add(t);
          depths.add(5.0 + 15.0 * s / 30.0);
          t++;
        }
        // Stay at 20m for 5 more minutes (max depth point is here)
        for (var s = 0; s < 300; s++) {
          timestamps.add(t);
          depths.add(20.0);
          t++;
        }

        // Ascent to surface without stop, 2 minutes
        for (var s = 0; s <= 120; s++) {
          timestamps.add(t);
          depths.add(20.0 * (1 - s / 120.0));
          t++;
        }

        final result = service.analyze(
          diveId: 'bottom-stop',
          depths: depths,
          timestamps: timestamps,
        );
        expect(safetyStopEvents(result), isEmpty);
      });

      test('stop during ascent is detected', () {
        final profile = buildDiveProfile(maxDepth: 20.0, stopDepth: 5.0);
        final result = service.analyze(
          diveId: 'ascent-stop',
          depths: profile.depths,
          timestamps: profile.timestamps,
        );
        final stops = safetyStopEvents(result);
        expect(stops.length, equals(2)); // start + end
        expect(stops[0].eventType, ProfileEventType.safetyStopStart);
        expect(stops[1].eventType, ProfileEventType.safetyStopEnd);
      });
    });

    group('consolidation', () {
      /// Build a dive that descends to 20m, then ascends through the safety
      /// stop zone with [gaps] — brief excursions outside the 3-6m band.
      /// Each gap is (gapDurationSeconds, depthDuringGap).
      /// Between gaps, the diver holds at 5m for [segmentMinutes] each.
      ({List<double> depths, List<int> timestamps}) buildDiveWithGaps({
        required List<({int durationSeconds, double depth})> gaps,
        int segmentMinutes = 3,
      }) {
        final depths = <double>[];
        final timestamps = <int>[];
        var t = 0;

        // Descent to 20m: 2 minutes
        for (var s = 0; s <= 120; s++) {
          timestamps.add(t);
          depths.add(20.0 * s / 120.0);
          t++;
        }

        // Bottom at 20m: 10 minutes
        for (var s = 0; s < 600; s++) {
          timestamps.add(t);
          depths.add(20.0);
          t++;
        }

        // Ascent to 5m: 1 minute
        for (var s = 0; s <= 60; s++) {
          timestamps.add(t);
          depths.add(20.0 - 15.0 * s / 60.0);
          t++;
        }

        // First safety stop segment
        for (var s = 0; s < segmentMinutes * 60; s++) {
          timestamps.add(t);
          depths.add(5.0);
          t++;
        }

        // Gaps with stop segments between them
        for (final gap in gaps) {
          // Brief excursion outside the band
          for (var s = 0; s < gap.durationSeconds; s++) {
            timestamps.add(t);
            depths.add(gap.depth);
            t++;
          }

          // Return to safety stop depth
          for (var s = 0; s < segmentMinutes * 60; s++) {
            timestamps.add(t);
            depths.add(5.0);
            t++;
          }
        }

        // Surface: 1 minute
        for (var s = 0; s <= 60; s++) {
          timestamps.add(t);
          depths.add(5.0 * (1 - s / 60.0));
          t++;
        }

        return (depths: depths, timestamps: timestamps);
      }

      test('two stops separated by 10s gap are merged into one', () {
        final profile = buildDiveWithGaps(
          gaps: [(durationSeconds: 10, depth: 7.0)],
        );
        final result = service.analyze(
          diveId: 'merge-short-gap',
          depths: profile.depths,
          timestamps: profile.timestamps,
        );
        final stops = safetyStopEvents(result);
        expect(stops.length, equals(2)); // one start + one end
        expect(stops[0].eventType, ProfileEventType.safetyStopStart);
        expect(stops[1].eventType, ProfileEventType.safetyStopEnd);
      });

      test('two stops separated by 31s gap remain separate', () {
        final profile = buildDiveWithGaps(
          gaps: [(durationSeconds: 31, depth: 7.0)],
        );
        final result = service.analyze(
          diveId: 'keep-long-gap',
          depths: profile.depths,
          timestamps: profile.timestamps,
        );
        final stops = safetyStopEvents(result);
        expect(stops.length, equals(4)); // two starts + two ends
      });

      test('three consecutive stops with short gaps merge into one', () {
        final profile = buildDiveWithGaps(
          gaps: [
            (durationSeconds: 10, depth: 7.0),
            (durationSeconds: 15, depth: 2.0),
          ],
        );
        final result = service.analyze(
          diveId: 'merge-three',
          depths: profile.depths,
          timestamps: profile.timestamps,
        );
        final stops = safetyStopEvents(result);
        expect(stops.length, equals(2)); // all merged into one
      });

      test('single stop with no neighbors is unchanged', () {
        final profile = buildDiveProfile(maxDepth: 20.0, stopDepth: 5.0);
        final result = service.analyze(
          diveId: 'single-stop',
          depths: profile.depths,
          timestamps: profile.timestamps,
        );
        final stops = safetyStopEvents(result);
        expect(stops.length, equals(2)); // one start + one end
      });
    });

    group('integration', () {
      test('shallow dive hovering at safety stop depths produces no stops', () {
        // Simulate the reported issue: a Perdix AI dive that stays
        // entirely at 3-6m depth with brief oscillations above and below.
        final depths = <double>[];
        final timestamps = <int>[];
        var t = 0;

        // Descent to 5m: 30 seconds
        for (var s = 0; s <= 30; s++) {
          timestamps.add(t);
          depths.add(5.0 * s / 30.0);
          t++;
        }

        // Hover at 4-5m for 30 minutes with oscillation
        for (var s = 0; s < 30 * 60; s++) {
          timestamps.add(t);
          // Oscillate between 4.0m and 5.0m
          const base = 4.5;
          final oscillation =
              1.0 * (s % 120 < 60 ? (s % 60) / 60.0 : 1.0 - (s % 60) / 60.0);
          depths.add(base + oscillation - 0.5);
          t++;
        }

        // Surface: 30 seconds
        for (var s = 0; s <= 30; s++) {
          timestamps.add(t);
          depths.add(5.0 * (1 - s / 30.0));
          t++;
        }

        final result = service.analyze(
          diveId: 'shallow-oscillating',
          depths: depths,
          timestamps: timestamps,
        );
        expect(
          safetyStopEvents(result),
          isEmpty,
          reason:
              'Shallow dive at safety stop depths should not trigger '
              'safety stop detection (max depth gate: < 10m)',
        );
      });
    });
  });
}
