import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/deco/ascent/ascent_gas_plan.dart';
import 'package:submersion/core/deco/constants/buhlmann_coefficients.dart';

void main() {
  group('FixedAscentGas', () {
    test('returns the same gas at every depth', () {
      final plan = FixedAscentGas(fN2: 0.79, fHe: 0.0);
      expect(plan.gasForDepth(40).fN2, 0.79);
      expect(plan.gasForDepth(0).fN2, 0.79);
      expect(plan.gasForDepth(40).fHe, 0.0);
    });

    test('reports no switch depths', () {
      final plan = FixedAscentGas(fN2: airN2Fraction);
      expect(plan.switchDepthsBetween(40, 0), isEmpty);
    });
  });

  group('OptimalOcAscentGas', () {
    // Back gas air (fO2 0.21), EAN50 (fO2 0.50), O2 (fO2 1.0); ppO2 ceiling 1.6.
    // MOD(EAN50,1.6) = (1.6/0.5 - 1)*10 = 22.0 m. MOD(O2,1.6) = 6.0 m.
    final gases = <AvailableGas>[
      const AvailableGas(fN2: 0.79, fHe: 0.0, maxPpO2Mod: double.infinity),
      const AvailableGas(fN2: 0.50, fHe: 0.0, maxPpO2Mod: 22.0),
      const AvailableGas(fN2: 0.0, fHe: 0.0, maxPpO2Mod: 6.0),
    ];
    final plan = OptimalOcAscentGas(gases: gases, maxPpO2: 1.6);

    test('picks the richest eligible gas at depth', () {
      expect(plan.gasForDepth(40).fN2, 0.79); // only air is eligible at 40 m
      expect(
        plan.gasForDepth(21).fN2,
        0.50,
      ); // EAN50 eligible (<= 22 m), richest
      expect(plan.gasForDepth(6).fN2, 0.0); // O2 eligible at its MOD (6 m)
      expect(plan.gasForDepth(3).fN2, 0.0); // O2 still richest
    });

    test('is eligible exactly at a gas MOD', () {
      expect(plan.gasForDepth(22).fN2, 0.50); // EAN50 ppO2 == 1.6 at 22 m
    });

    test('enumerates switch depths descending within a leg', () {
      expect(plan.switchDepthsBetween(40, 0), [22.0, 6.0]);
      expect(plan.switchDepthsBetween(40, 12), [
        22.0,
      ]); // 6 m is outside (40,12)
      expect(plan.switchDepthsBetween(9, 6), isEmpty); // no MOD strictly inside
    });
  });
}
