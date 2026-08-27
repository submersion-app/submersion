import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/deco/buhlmann_algorithm.dart';
import 'package:submersion/core/deco/entities/dive_environment.dart';

void main() {
  group('BuhlmannAlgorithm with DiveEnvironment', () {
    test('default environment reproduces legacy results', () {
      final legacy = BuhlmannAlgorithm(gfLow: 0.5, gfHigh: 0.8);
      final explicit = BuhlmannAlgorithm(
        gfLow: 0.5,
        gfHigh: 0.8,
        environment: DiveEnvironment.standard,
      );
      for (final algo in [legacy, explicit]) {
        algo.calculateSegment(depthMeters: 30, durationSeconds: 25 * 60);
      }
      expect(
        legacy.calculateNdl(depthMeters: 30),
        explicit.calculateNdl(depthMeters: 30),
      );
      expect(legacy.compartments, explicit.compartments);
    });

    test('altitude shortens NDL for the same exposure', () {
      final seaLevel = BuhlmannAlgorithm(gfLow: 0.5, gfHigh: 0.8);
      final altitude = BuhlmannAlgorithm(
        gfLow: 0.5,
        gfHigh: 0.8,
        environment: DiveEnvironment.forConditions(altitudeMeters: 2000),
      );
      final ndlSea = seaLevel.calculateNdl(depthMeters: 25);
      final ndlAlt = altitude.calculateNdl(depthMeters: 25);
      expect(ndlAlt, lessThan(ndlSea));
    });

    test('altitude produces more deco for the same dive', () {
      int decoSeconds(DiveEnvironment env) {
        final algo = BuhlmannAlgorithm(
          gfLow: 0.5,
          gfHigh: 0.8,
          environment: env,
        );
        algo.calculateSegment(depthMeters: 40, durationSeconds: 25 * 60);
        return algo.calculateTts(currentDepth: 40);
      }

      expect(
        decoSeconds(DiveEnvironment.forConditions(altitudeMeters: 2500)),
        greaterThan(decoSeconds(DiveEnvironment.standard)),
      );
    });

    test('fresh water gives slightly longer NDL than salt at same depth', () {
      final salt = BuhlmannAlgorithm(
        gfLow: 0.5,
        gfHigh: 0.8,
        environment: const DiveEnvironment(
          waterDensityKgM3: DiveEnvironment.saltWaterDensity,
        ),
      );
      final fresh = BuhlmannAlgorithm(
        gfLow: 0.5,
        gfHigh: 0.8,
        environment: const DiveEnvironment(
          waterDensityKgM3: DiveEnvironment.freshWaterDensity,
        ),
      );
      expect(
        fresh.calculateNdl(depthMeters: 30),
        greaterThanOrEqualTo(salt.calculateNdl(depthMeters: 30)),
      );
    });

    test('surface saturation at altitude starts below sea-level tension', () {
      final altitude = BuhlmannAlgorithm(
        environment: DiveEnvironment.forConditions(altitudeMeters: 2000),
      );
      final seaLevel = BuhlmannAlgorithm();
      expect(
        altitude.compartments.first.currentPN2,
        lessThan(seaLevel.compartments.first.currentPN2),
      );
    });

    test('restoreState round-trips compartments and anchor', () {
      final algo = BuhlmannAlgorithm(gfLow: 0.5, gfHigh: 0.8);
      algo.calculateSegment(depthMeters: 40, durationSeconds: 20 * 60);
      final savedComps = algo.compartments;
      final savedAnchor = algo.gfLowCeilingAnchor;

      final other = BuhlmannAlgorithm(gfLow: 0.5, gfHigh: 0.8);
      other.restoreState(savedComps, gfLowCeilingAnchor: savedAnchor);
      expect(other.compartments, savedComps);
      expect(other.gfLowCeilingAnchor, savedAnchor);
      expect(
        other.calculateTts(currentDepth: 40),
        algo.calculateTts(currentDepth: 40),
      );
    });
  });
}
