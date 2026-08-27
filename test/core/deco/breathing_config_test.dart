import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/deco/constants/buhlmann_coefficients.dart';
import 'package:submersion/core/deco/entities/breathing_config.dart';

void main() {
  group('OpenCircuit', () {
    test('matches the legacy inspired-gas helpers', () {
      const oc = OpenCircuit(fO2: 0.2098, fHe: 0.0);
      final inspired = oc.inspiredAt(4.0); // 30 m standard
      // python3: (4.0 - 0.0627) * 0.7902 = 3.11125446
      expect(inspired.pN2, closeTo(calculateInspiredN2(4.0, oc.fN2), 1e-12));
      expect(inspired.pN2, closeTo(3.11125446, 1e-6));
      expect(inspired.pHe, 0.0);
    });

    test('trimix splits inert pressures by fraction', () {
      const oc = OpenCircuit(fO2: 0.18, fHe: 0.45);
      final inspired = oc.inspiredAt(7.0); // 60 m standard
      expect(inspired.pHe, closeTo((7.0 - waterVaporPressure) * 0.45, 1e-12));
      expect(inspired.pN2, closeTo((7.0 - waterVaporPressure) * 0.37, 1e-9));
    });
  });

  group('ClosedCircuit', () {
    test('constant ppO2 at depth: inert = alveolar minus setpoint', () {
      const ccr = ClosedCircuit(
        setpoint: 1.3,
        diluentFO2: 0.18,
        diluentFHe: 0.45,
      );
      final inspired = ccr.inspiredAt(5.0); // 40 m standard
      expect(inspired.pO2, closeTo(1.3, 1e-12));
      // python3 values (Task 4 Step 1):
      expect(inspired.pN2, closeTo(1.6412207317073169, 1e-9));
      expect(inspired.pHe, closeTo(1.996079268292683, 1e-9));
    });

    test('shallow clamp: loop goes pure O2 when setpoint >= alveolar', () {
      const ccr = ClosedCircuit(
        setpoint: 1.3,
        diluentFO2: 0.18,
        diluentFHe: 0.45,
      );
      final inspired = ccr.inspiredAt(1.3); // 3 m standard
      expect(inspired.pO2, closeTo(1.3 - waterVaporPressure, 1e-12));
      expect(inspired.pN2, 0.0);
      expect(inspired.pHe, 0.0);
    });

    test('CCR loads less inert gas than OC on the diluent at depth', () {
      const ccr = ClosedCircuit(
        setpoint: 1.3,
        diluentFO2: 0.18,
        diluentFHe: 0.45,
      );
      const oc = OpenCircuit(fO2: 0.18, fHe: 0.45);
      const ambient = 5.0;
      final ccrInert =
          ccr.inspiredAt(ambient).pN2 + ccr.inspiredAt(ambient).pHe;
      final ocInert = oc.inspiredAt(ambient).pN2 + oc.inspiredAt(ambient).pHe;
      expect(ccrInert, lessThan(ocInert));
    });
  });

  group('Scr', () {
    test('steady-state loop is leaner than the supply gas', () {
      final scr = Scr(supplyFO2: 0.32, injectionRateLpm: 10.0, vo2: 1.3);
      final inspired = scr.inspiredAt(3.0); // 20 m standard
      final supply = const OpenCircuit(fO2: 0.32).inspiredAt(3.0);
      expect(inspired.pO2, lessThan(supply.pO2));
      expect(inspired.pN2, greaterThan(supply.pN2));
    });

    test('preserves the supply He:N2 ratio in the loop', () {
      final scr = Scr(supplyFO2: 0.30, supplyFHe: 0.30, injectionRateLpm: 10.0);
      final inspired = scr.inspiredAt(4.0);
      // Supply inert split is 30 He / 40 N2 -> He share 30/70 of inert.
      expect(
        inspired.pHe / (inspired.pHe + inspired.pN2),
        closeTo(0.30 / 0.70, 1e-9),
      );
    });
  });
}
