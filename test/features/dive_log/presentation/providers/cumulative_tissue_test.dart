import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/deco/buhlmann_algorithm.dart';
import 'package:submersion/core/deco/constants/buhlmann_coefficients.dart';

/// Tests for the Schreiner off-gassing math used in residual tissue computation.
///
/// The provider-level integration (recursive lookback via Riverpod) is tested
/// separately. These tests validate the core math in isolation.
void main() {
  group('Residual tissue state computation', () {
    test('off-gassing at surface should reduce tissue loading', () {
      final algorithm = BuhlmannAlgorithm(gfLow: 1.0, gfHigh: 1.0);

      // Load tissues at 30m for 20 min
      algorithm.calculateSegment(
        depthMeters: 30.0,
        durationSeconds: 20 * 60,
        fN2: airN2Fraction,
      );
      final loadedCompartments = algorithm.compartments;

      // Off-gas at surface for 60 min
      algorithm.calculateSegment(
        depthMeters: 0.0,
        durationSeconds: 60 * 60,
        fN2: airN2Fraction,
      );
      final recoveredCompartments = algorithm.compartments;

      // All compartments should have lower N2 tension after surface interval
      for (int i = 0; i < 16; i++) {
        expect(
          recoveredCompartments[i].currentPN2,
          lessThan(loadedCompartments[i].currentPN2),
          reason:
              'Compartment ${i + 1} N2 should decrease during surface interval',
        );
      }
    });

    test('repetitive dive should have shorter NDL than fresh dive', () {
      // Simulate: dive 1 (30m/20min) -> 60 min SI -> dive 2 (18m)
      final algorithm = BuhlmannAlgorithm(gfLow: 1.0, gfHigh: 1.0);

      // Dive 1
      algorithm.calculateSegment(
        depthMeters: 30.0,
        durationSeconds: 20 * 60,
        fN2: airN2Fraction,
      );

      // Surface interval 60 min
      algorithm.calculateSegment(
        depthMeters: 0.0,
        durationSeconds: 60 * 60,
        fN2: airN2Fraction,
      );
      final residualCompartments = algorithm.compartments;

      // Dive 2 with residual loading
      final dive2Algo = BuhlmannAlgorithm(gfLow: 1.0, gfHigh: 1.0);
      dive2Algo.setCompartments(residualCompartments);
      final ndlCumulative = dive2Algo.calculateNdl(
        depthMeters: 18.0,
        fN2: airN2Fraction,
      );

      // Fresh dive 2 (no residual)
      final freshAlgo = BuhlmannAlgorithm(gfLow: 1.0, gfHigh: 1.0);
      final ndlFresh = freshAlgo.calculateNdl(
        depthMeters: 18.0,
        fN2: airN2Fraction,
      );

      expect(
        ndlCumulative,
        lessThan(ndlFresh),
        reason: 'Repetitive dive NDL should be shorter than fresh dive',
      );
      expect(
        ndlCumulative,
        greaterThan(0),
        reason: 'After 60 min SI, 18m dive should still have positive NDL',
      );
    });

    test('48-hour cutoff: tissue state should be near surface-saturated', () {
      final algorithm = BuhlmannAlgorithm(gfLow: 1.0, gfHigh: 1.0);
      final surfaceN2 = calculateInspiredN2(surfacePressureBar, airN2Fraction);

      // Heavy dive: 40m for 25 min
      algorithm.calculateSegment(
        depthMeters: 40.0,
        durationSeconds: 25 * 60,
        fN2: airN2Fraction,
      );

      // 48 hours at surface
      algorithm.calculateSegment(
        depthMeters: 0.0,
        durationSeconds: 48 * 60 * 60,
        fN2: airN2Fraction,
      );

      // All compartments should be within 1% of surface-saturated
      for (int i = 0; i < 16; i++) {
        expect(
          algorithm.compartments[i].currentPN2,
          closeTo(surfaceN2, 0.008),
          reason: 'Compartment ${i + 1} should be near surface level after 48h',
        );
      }
    });
  });
}
