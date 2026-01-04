import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/deco/buhlmann_algorithm.dart';
import 'package:submersion/core/deco/constants/buhlmann_coefficients.dart';

void main() {
  group('BuhlmannAlgorithm', () {
    late BuhlmannAlgorithm algorithm;

    setUp(() {
      algorithm = BuhlmannAlgorithm(
        gfLow: 1.0, // 100% - no conservatism for validation tests
        gfHigh: 1.0,
      );
    });

    group('initialization', () {
      test('should initialize with default gradient factors', () {
        final defaultAlgorithm = BuhlmannAlgorithm();
        expect(defaultAlgorithm, isNotNull);
      });

      test('should initialize with custom gradient factors', () {
        final customAlgorithm = BuhlmannAlgorithm(gfLow: 0.30, gfHigh: 0.70);
        expect(customAlgorithm, isNotNull);
      });

      test('should initialize tissues at surface', () {
        final status = algorithm.getDecoStatus(currentDepth: 0);
        expect(status.ceilingMeters, equals(0.0));
        expect(status.inDeco, isFalse);
      });

      test('should have 16 tissue compartments', () {
        expect(algorithm.compartments.length, equals(16));
      });
    });

    group('NDL calculations', () {
      test('should return reasonable NDL for shallow dive on air', () {
        // At 10m on air, NDL should be very long (near infinite)
        final ndl = algorithm.calculateNdl(
          depthMeters: 10.0,
          fN2: airN2Fraction,
          fHe: 0.0,
        );
        // NDL at 10m is typically unlimited (>200 min)
        expect(ndl, greaterThan(200 * 60));
      });

      test('should return shorter NDL for deeper dive', () {
        // At 30m on air, NDL is limited
        final ndl = algorithm.calculateNdl(
          depthMeters: 30.0,
          fN2: airN2Fraction,
          fHe: 0.0,
        );
        // NDL at 30m is approximately 20 minutes for ZH-L16C (varies by GF)
        expect(ndl, greaterThan(10 * 60));
        expect(ndl, lessThan(60 * 60));
      });

      test('should return very short NDL for very deep dive', () {
        // At 40m on air, NDL is very short
        final ndl = algorithm.calculateNdl(
          depthMeters: 40.0,
          fN2: airN2Fraction,
          fHe: 0.0,
        );
        // NDL at 40m is approximately 5-10 minutes
        expect(ndl, greaterThan(3 * 60));
        expect(ndl, lessThan(20 * 60));
      });

      test('should return longer NDL with nitrox 32', () {
        // Nitrox 32 (32% O2, 68% N2) should have longer NDL than air
        final ndlAir = algorithm.calculateNdl(
          depthMeters: 30.0,
          fN2: airN2Fraction,
          fHe: 0.0,
        );

        algorithm.reset();

        final ndlNitrox = algorithm.calculateNdl(
          depthMeters: 30.0,
          fN2: 0.68, // 32% O2
          fHe: 0.0,
        );

        expect(ndlNitrox, greaterThan(ndlAir));
      });
    });

    group('tissue loading', () {
      test('should load tissues at constant depth', () {
        final initialStatus = algorithm.getDecoStatus(currentDepth: 0);
        final initialLoading = initialStatus.leadingCompartmentLoading;

        // Descend and stay at 30m for 10 minutes
        algorithm.calculateSegment(
          depthMeters: 15, // Average depth during descent
          durationSeconds: 60, // 1 minute descent
          fN2: airN2Fraction,
          fHe: 0.0,
        );

        algorithm.calculateSegment(
          depthMeters: 30,
          durationSeconds: 10 * 60, // 10 minutes
          fN2: airN2Fraction,
          fHe: 0.0,
        );

        final finalStatus = algorithm.getDecoStatus(currentDepth: 30);
        expect(
          finalStatus.leadingCompartmentLoading,
          greaterThan(initialLoading),
        );
      });

      test('should offgas tissues at surface', () {
        // Load tissues at depth
        algorithm.calculateSegment(
          depthMeters: 30,
          durationSeconds: 20 * 60, // 20 minutes
          fN2: airN2Fraction,
          fHe: 0.0,
        );

        final loadedStatus = algorithm.getDecoStatus(currentDepth: 30);

        // Ascend to surface (using average depth)
        algorithm.calculateSegment(
          depthMeters: 15, // Average during ascent
          durationSeconds: 3 * 60, // 3 minute ascent
          fN2: airN2Fraction,
          fHe: 0.0,
        );

        // Wait at surface for offgassing
        algorithm.calculateSegment(
          depthMeters: 0,
          durationSeconds: 10 * 60, // 10 minutes
          fN2: airN2Fraction,
          fHe: 0.0,
        );

        final offgassedStatus = algorithm.getDecoStatus(currentDepth: 0);
        expect(
          offgassedStatus.leadingCompartmentLoading,
          lessThan(loadedStatus.leadingCompartmentLoading),
        );
      });
    });

    group('ceiling calculation', () {
      test('should have zero ceiling at surface', () {
        final ceiling = algorithm.calculateCeiling();
        expect(ceiling, equals(0.0));
      });

      test('should calculate ceiling after deep dive', () {
        // Deep dive that should create deco obligation
        algorithm.calculateSegment(
          depthMeters: 22.5, // Average during descent
          durationSeconds: 90,
          fN2: airN2Fraction,
          fHe: 0.0,
        );

        algorithm.calculateSegment(
          depthMeters: 45,
          durationSeconds: 25 * 60, // 25 minutes
          fN2: airN2Fraction,
          fHe: 0.0,
        );

        final ceiling = algorithm.calculateCeiling(currentDepth: 45);
        final status = algorithm.getDecoStatus(currentDepth: 45);

        // After 25 min at 45m, we should be in deco
        expect(status.inDeco, isTrue);
        expect(ceiling, greaterThan(0));
      });
    });

    group('gradient factors', () {
      test('should calculate more conservative ceiling with lower GF', () {
        final conservativeAlgorithm = BuhlmannAlgorithm(
          gfLow: 0.30,
          gfHigh: 0.70,
        );

        final liberalAlgorithm = BuhlmannAlgorithm(gfLow: 0.70, gfHigh: 0.90);

        // Same dive for both
        void doDive(BuhlmannAlgorithm algo) {
          algo.calculateSegment(
            depthMeters: 40,
            durationSeconds: 15 * 60,
            fN2: airN2Fraction,
            fHe: 0.0,
          );
        }

        doDive(conservativeAlgorithm);
        doDive(liberalAlgorithm);

        // Conservative should have higher ceiling (deeper deco stop)
        final conservativeCeiling = conservativeAlgorithm.calculateCeiling(
          currentDepth: 40,
        );
        final liberalCeiling = liberalAlgorithm.calculateCeiling(
          currentDepth: 40,
        );

        expect(conservativeCeiling, greaterThanOrEqualTo(liberalCeiling));
      });
    });

    group('processProfile', () {
      test('should process a simple dive profile', () {
        final depths = [
          0.0,
          5.0,
          10.0,
          15.0,
          20.0,
          20.0,
          20.0,
          15.0,
          10.0,
          5.0,
          0.0,
        ];
        final timestamps = [0, 30, 60, 90, 120, 300, 600, 660, 720, 780, 840];

        final statuses = algorithm.processProfile(
          depths: depths,
          timestamps: timestamps,
          fN2: airN2Fraction,
          fHe: 0.0,
        );

        expect(statuses.length, equals(depths.length));
        expect(statuses.first.ceilingMeters, equals(0.0));
      });

      test('should track NDL decreasing during descent', () {
        // Descend to 30m over 3 minutes, stay for 10 minutes
        final depths = <double>[];
        final timestamps = <int>[];

        // Descent
        for (int t = 0; t <= 180; t += 10) {
          timestamps.add(t);
          depths.add(t / 6.0); // 10m per minute
        }

        // Bottom time
        for (int t = 190; t <= 780; t += 10) {
          timestamps.add(t);
          depths.add(30.0);
        }

        final statuses = algorithm.processProfile(
          depths: depths,
          timestamps: timestamps,
          fN2: airN2Fraction,
          fHe: 0.0,
        );

        // NDL should decrease over time at depth
        final bottomStatuses = statuses.skip(19).toList();
        if (bottomStatuses.length >= 2) {
          final firstBottomNdl = bottomStatuses.first.ndlSeconds;
          final lastBottomNdl = bottomStatuses.last.ndlSeconds;
          expect(lastBottomNdl, lessThan(firstBottomNdl));
        }
      });
    });

    group('decompression schedule', () {
      test('should generate deco stops for saturated dive', () {
        // Do a dive that requires deco
        algorithm.calculateSegment(
          depthMeters: 45,
          durationSeconds: 30 * 60, // 30 minutes
          fN2: airN2Fraction,
          fHe: 0.0,
        );

        final stops = algorithm.calculateDecoSchedule(
          currentDepth: 45,
          fN2: airN2Fraction,
          fHe: 0.0,
        );

        expect(stops, isNotEmpty);
        // First stop should be deepest, last should be shallowest
        if (stops.length > 1) {
          expect(
            stops.first.depthMeters,
            greaterThanOrEqualTo(stops.last.depthMeters),
          );
        }
        // Last stop should typically be at 3-6m
        expect(stops.last.depthMeters, lessThanOrEqualTo(6.0));
      });

      test('should calculate TTS for deco dive', () {
        algorithm.calculateSegment(
          depthMeters: 45,
          durationSeconds: 30 * 60,
          fN2: airN2Fraction,
          fHe: 0.0,
        );

        final tts = algorithm.calculateTts(currentDepth: 45);

        // TTS should include ascent time + stop times
        expect(tts, greaterThan(0));
        // TTS should be at least enough for 45m ascent at 9m/min
        expect(tts, greaterThanOrEqualTo((45 / 9 * 60).round()));
      });
    });

    group('reset', () {
      test('should reset tissues to surface saturation', () {
        // Load tissues
        algorithm.calculateSegment(
          depthMeters: 30,
          durationSeconds: 30 * 60,
          fN2: airN2Fraction,
          fHe: 0.0,
        );

        final loadedStatus = algorithm.getDecoStatus(currentDepth: 30);
        expect(loadedStatus.leadingCompartmentLoading, greaterThan(50));

        // Reset
        algorithm.reset();

        // Should be back to surface saturation
        final resetStatus = algorithm.getDecoStatus(currentDepth: 0);
        expect(resetStatus.ceilingMeters, equals(0.0));
        expect(resetStatus.inDeco, isFalse);
      });
    });

    group('trimix support', () {
      test('should handle trimix gas', () {
        // Trimix 18/45 (18% O2, 45% He, 37% N2)
        const fN2 = 0.37;
        const fHe = 0.45;

        algorithm.calculateSegment(
          depthMeters: 60,
          durationSeconds: 20 * 60,
          fN2: fN2,
          fHe: fHe,
        );

        // Should have valid status with helium
        final status = algorithm.getDecoStatus(
          currentDepth: 60,
          fN2: fN2,
          fHe: fHe,
        );
        expect(status, isNotNull);
        expect(status.inDeco, isTrue);
      });
    });

    group('ZH-L16C coefficients', () {
      test('should have 16 compartments', () {
        expect(zhl16cN2HalfTimes.length, equals(16));
        expect(zhl16cHeHalfTimes.length, equals(16));
        expect(zhl16cN2A.length, equals(16));
        expect(zhl16cN2B.length, equals(16));
        expect(zhl16cHeA.length, equals(16));
        expect(zhl16cHeB.length, equals(16));
      });

      test('should have increasing half-times', () {
        for (int i = 1; i < zhl16cN2HalfTimes.length; i++) {
          expect(
            zhl16cN2HalfTimes[i],
            greaterThan(zhl16cN2HalfTimes[i - 1]),
            reason: 'N2 half-times should be in increasing order',
          );
        }
      });

      test('should have valid coefficient ranges', () {
        for (int i = 0; i < 16; i++) {
          expect(zhl16cN2HalfTimes[i], greaterThan(0));
          expect(zhl16cHeHalfTimes[i], greaterThan(0));
          expect(zhl16cN2A[i], greaterThan(0));
          expect(zhl16cN2B[i], greaterThan(0));
          expect(zhl16cN2B[i], lessThanOrEqualTo(1.0));
          expect(zhl16cHeA[i], greaterThan(0));
          expect(zhl16cHeB[i], greaterThan(0));
          expect(zhl16cHeB[i], lessThanOrEqualTo(1.0));
        }
      });

      test(
        'helium half-times should be approximately 2.65x faster than N2',
        () {
          for (int i = 0; i < 16; i++) {
            final ratio = zhl16cN2HalfTimes[i] / zhl16cHeHalfTimes[i];
            // Ratio should be approximately 2.65 (helium is ~2.65x faster)
            expect(ratio, closeTo(2.65, 0.1));
          }
        },
      );
    });

    group('helper functions', () {
      test('calculateAmbientPressure should be correct', () {
        expect(calculateAmbientPressure(0), equals(1.0));
        expect(calculateAmbientPressure(10), equals(2.0));
        expect(calculateAmbientPressure(20), equals(3.0));
        expect(calculateAmbientPressure(30), equals(4.0));
      });

      test('calculateDepthFromPressure should be inverse', () {
        expect(calculateDepthFromPressure(1.0), equals(0.0));
        expect(calculateDepthFromPressure(2.0), equals(10.0));
        expect(calculateDepthFromPressure(3.0), equals(20.0));
      });

      test('calculateInspiredN2 should account for water vapor', () {
        final inspiredN2 = calculateInspiredN2(1.0, airN2Fraction);
        // Should be less than straight ambient * fraction due to water vapor
        expect(inspiredN2, lessThan(airN2Fraction));
        expect(inspiredN2, greaterThan(0));
      });
    });
  });
}
