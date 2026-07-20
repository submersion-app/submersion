import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/buoyancy/suit_compression.dart';

void main() {
  // Salt-water pressures computed with python3:
  // barPerMeter = 1025 * 9.80665 / 100000 = 0.1005181625
  const p5 = 1.5025908125; // 5 m salt, 1.0 bar surface
  const p30 = 4.015544875; // 30 m salt

  group('surfaceFromAnchor / buoyancyAtPressure', () {
    test('inverts a 5 m anchor to surface buoyancy (r=0.3)', () {
      final surface = SuitCompression.surfaceFromAnchor(
        anchorKg: 3.0,
        anchorPressureBar: p5,
        surfacePressureBar: 1.0,
      );
      expect(surface, closeTo(3.9171546552403744, 1e-9));
    });

    test('round-trips: curve at anchor pressure returns the anchor', () {
      final surface = SuitCompression.surfaceFromAnchor(
        anchorKg: 3.0,
        anchorPressureBar: p5,
        surfacePressureBar: 1.0,
      );
      final back = SuitCompression.buoyancyAtPressure(
        surfaceKg: surface,
        pressureBar: p5,
        surfacePressureBar: 1.0,
      );
      expect(back, closeTo(3.0, 1e-9));
    });

    test('compresses toward the residual at depth', () {
      final surface = SuitCompression.surfaceFromAnchor(
        anchorKg: 3.0,
        anchorPressureBar: p5,
        surfacePressureBar: 1.0,
      );
      expect(
        SuitCompression.buoyancyAtPressure(
          surfaceKg: surface,
          pressureBar: p30,
          surfacePressureBar: 1.0,
        ),
        closeTo(1.857994763113717, 1e-9),
      );
    });

    test('surface value equals full buoyancy at surface pressure', () {
      expect(
        SuitCompression.buoyancyAtPressure(
          surfaceKg: 4.0,
          pressureBar: 1.0,
          surfacePressureBar: 1.0,
        ),
        closeTo(4.0, 1e-12),
      );
    });

    test('clamps: inversion never exceeds 3x the anchor', () {
      final surface = SuitCompression.surfaceFromAnchor(
        anchorKg: 1.0,
        anchorPressureBar: 20.0, // absurd anchor pressure
        surfacePressureBar: 1.0,
      );
      expect(surface, lessThanOrEqualTo(3.0));
      expect(surface, greaterThanOrEqualTo(1.0));
    });

    test('non-positive anchor yields zero (caller falls back to prior)', () {
      expect(
        SuitCompression.surfaceFromAnchor(
          anchorKg: 0.0,
          anchorPressureBar: p5,
          surfacePressureBar: 1.0,
        ),
        0.0,
      );
    });
  });

  group('drysuit gas budget', () {
    test('sums loft times positive pressure deltas only', () {
      // python3: loft 12 L over 1.0 -> 3.0 -> 2.0 -> 2.5 bar = 30.0 L
      expect(
        SuitCompression.drysuitGasLiters(
          loftLiters: 12.0,
          pressuresBar: [1.0, 3.0, 2.0, 2.5],
        ),
        closeTo(30.0, 1e-9),
      );
    });

    test('loft from buoyancy divides by water density', () {
      expect(
        SuitCompression.loftLitersFromBuoyancy(
          suitTermKg: 10.25,
          waterDensityKgL: 1.025,
        ),
        closeTo(10.0, 1e-9),
      );
      expect(
        SuitCompression.loftLitersFromBuoyancy(
          suitTermKg: -1.0,
          waterDensityKgL: 1.025,
        ),
        0.0,
      );
    });
  });
}
