import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/deco/buhlmann_algorithm.dart';
import 'package:submersion/core/deco/constants/buhlmann_coefficients.dart';
import 'package:submersion/core/deco/entities/breathing_config.dart';
import 'package:submersion/core/deco/entities/deco_status.dart';

/// Issue #2593: a compartment gains or loses inert gas according to the
/// pressure the diver is BREATHING, not the ambient pressure. The tissue views
/// compared against ambient, so every compartment read "Ongassing" for the
/// whole of a deep dive, including deco stops where the loop's inspired inert
/// pressure is far below the tissue tension.
void main() {
  const loop = ClosedCircuit(setpoint: 1.3, diluentFO2: 0.21);

  group('DecoStatus inspired inert pressure', () {
    test('records the inspired N2/He the status was computed with', () {
      final algorithm = BuhlmannAlgorithm();
      final status = algorithm.getDecoStatus(currentDepth: 21, breathing: loop);
      final expected = loop.inspiredAt(status.ambientPressureBar);

      expect(status.inspiredN2Bar, closeTo(expected.pN2, 1e-9));
      expect(status.inspiredHeBar, closeTo(expected.pHe, 1e-9));
    });

    test('records open-circuit inspired pressure from the gas fractions', () {
      final algorithm = BuhlmannAlgorithm();
      final status = algorithm.getDecoStatus(
        currentDepth: 30,
        fN2: 0.5,
        fHe: 0.3,
      );
      final pAlv = status.ambientPressureBar - waterVaporPressure;

      expect(status.inspiredN2Bar, closeTo(pAlv * 0.5, 1e-9));
      expect(status.inspiredHeBar, closeTo(pAlv * 0.3, 1e-9));
    });

    test('is unknown on a status built without an inspired gas', () {
      final status = DecoStatus.surfaceSaturated(
        compartments: BuhlmannAlgorithm().compartments,
      );

      expect(status.inspiredN2Bar, isNull);
      expect(status.isOffgassing(status.compartments.first), isNull);
    });
  });

  group('DecoStatus.isOffgassing', () {
    test('a CCR deco stop off-gasses compartments still below ambient', () {
      final algorithm = BuhlmannAlgorithm();
      // 30 minutes at 40 m on a 1.3 loop, then arrive at a 21 m stop.
      algorithm.calculateSegment(
        depthMeters: 40,
        durationSeconds: 30 * 60,
        breathing: loop,
      );
      final status = algorithm.getDecoStatus(currentDepth: 21, breathing: loop);

      // Compartment 5 (27 min N2 half-time) sits between the inspired inert
      // pressure and ambient: the old ambient comparison called it on-gassing.
      final comp = status.compartments[4];
      final inspired = status.inspiredN2Bar! + status.inspiredHeBar!;
      expect(comp.totalInertGas, lessThan(status.ambientPressureBar));
      expect(comp.totalInertGas, greaterThan(inspired));

      expect(status.isOffgassing(comp), isTrue);
    });

    test('descending on open circuit on-gasses every compartment', () {
      final algorithm = BuhlmannAlgorithm();
      final status = algorithm.getDecoStatus(currentDepth: 30);

      for (final comp in status.compartments) {
        expect(
          status.isOffgassing(comp),
          isFalse,
          reason: 'compartment ${comp.compartmentNumber}',
        );
      }
    });

    test('nets N2 and He by their own rates (counter-diffusion)', () {
      final algorithm = BuhlmannAlgorithm();
      // Load He-free tissues, then breathe a helium-rich mix at the same depth:
      // N2 leaves while He arrives. Helium's faster half-time makes the net
      // flow inward in the fast compartments.
      algorithm.calculateSegment(depthMeters: 30, durationSeconds: 60 * 60);
      final status = algorithm.getDecoStatus(
        currentDepth: 30,
        fN2: 0.2,
        fHe: 0.6,
      );
      final fast = status.compartments.first;

      expect(fast.currentPN2, greaterThan(status.inspiredN2Bar!));
      expect(fast.currentPHe, lessThan(status.inspiredHeBar!));
      expect(status.isOffgassing(fast), isFalse);
    });
  });
}
