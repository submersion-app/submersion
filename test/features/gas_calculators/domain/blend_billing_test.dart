import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    show GasMix;
import 'package:submersion/features/gas_calculators/domain/blending/blend_billing.dart';
import 'package:submersion/features/gas_calculators/domain/gas_blender.dart';

const _o2 = GasMix(o2: 100);
const _he = GasMix(o2: 0, he: 100);
const _air = GasMix(o2: 21);

BlendStep _step(GasMix? gas, double addedBar, {int? slot}) => BlendStep(
  fillGas: gas,
  fillGasIndex: gas == null ? null : slot,
  pressureBar: 0,
  addedBar: addedBar,
  resultingMix: _air,
  addedVolumePerLiter: gas == null ? null : addedBar,
);

BlendResult _blend(List<BlendStep> steps) =>
    BlendResult(steps: steps, settledPressureBar: 200);

void main() {
  group('computeBlendCost', () {
    test('reproduces the worked example from issue #936', () {
      final result = computeBlendCost(
        blend: _blend([
          _step(null, 0),
          _step(_o2, 7.3, slot: 0),
          _step(_he, 19.8, slot: 1),
          _step(_air, 48.1, slot: 2),
        ]),
        waterLiters: 3,
        pricesPer100: [2.00, 10.00, 0.10],
      );

      expect(result.lines, hasLength(3));
      expect(result.lines[0].cost, closeTo(0.438, 0.0005));
      expect(result.lines[1].cost, closeTo(5.94, 0.0005));
      expect(result.lines[2].cost, closeTo(0.1443, 0.0005));
      expect(result.total, closeTo(6.5223, 0.0005));
    });

    test('reproduces the helium example from issue #1100', () {
      final result = computeBlendCost(
        blend: _blend([_step(null, 0), _step(_he, 50, slot: 0)]),
        waterLiters: 3,
        pricesPer100: [7.99],
      );

      expect(result.lines.single.freeGasLiters, closeTo(150, 1e-9));
      expect(result.lines.single.cost, closeTo(11.985, 0.0005));
      expect(result.total, closeTo(11.985, 0.0005));
    });

    test('free gas is water volume times bar delivered', () {
      final result = computeBlendCost(
        blend: _blend([_step(null, 0), _step(_air, 48.1, slot: 0)]),
        waterLiters: 12,
        pricesPer100: [null],
      );
      expect(result.lines.single.freeGasLiters, closeTo(577.2, 1e-9));
      expect(result.lines.single.addedBar, closeTo(48.1, 1e-9));
    });

    test('the start step is not a billable line', () {
      final result = computeBlendCost(
        blend: _blend([_step(null, 0), _step(_o2, 10, slot: 0)]),
        waterLiters: 3,
        pricesPer100: [1.0],
      );
      expect(result.lines, hasLength(1));
      expect(result.lines.single.gas, _o2);
    });

    test('a missing price yields a null cost and a null total', () {
      final result = computeBlendCost(
        blend: _blend([
          _step(null, 0),
          _step(_o2, 10, slot: 0),
          _step(_air, 20, slot: 1),
        ]),
        waterLiters: 3,
        pricesPer100: [2.0, null],
      );
      expect(result.lines[0].cost, closeTo(0.6, 1e-9));
      expect(result.lines[1].cost, isNull);
      expect(result.total, isNull);
    });

    test('a price list shorter than the step list prices what it can', () {
      final result = computeBlendCost(
        blend: _blend([
          _step(null, 0),
          _step(_o2, 10, slot: 0),
          _step(_air, 20, slot: 1),
        ]),
        waterLiters: 3,
        pricesPer100: [2.0],
      );
      expect(result.lines[1].unitPricePer100, isNull);
      expect(result.total, isNull);
    });

    test('a cylinder with no volume yet is unpriced, not free', () {
      // Raised in review on PR #1215: reporting 0.00 rendered a
      // finished-looking bill for a cylinder the diver had not entered, the
      // same shape of failure as a blank mix box meaning 0% oxygen.
      final result = computeBlendCost(
        blend: _blend([_step(null, 0), _step(_o2, 10, slot: 0)]),
        waterLiters: 0,
        pricesPer100: [2.0],
      );
      expect(result.lines.single.freeGasLiters, 0);
      expect(result.lines.single.cost, isNull);
      expect(result.total, isNull);
    });
    test('a skipped bank does not slide the prices along', () {
      // Raised in review on PR #1215. A helium-free target skips the helium
      // bank, so the SECOND step is the THIRD bank. Pricing by step order
      // charged air at helium's rate.
      final result = computeBlendCost(
        blend: _blend([
          _step(null, 0),
          _step(_o2, 10, slot: 0),
          _step(_air, 20, slot: 2),
        ]),
        waterLiters: 10,
        // O2 at 2.00, helium at 50.00, air at 0.10 per 100 L.
        pricesPer100: [2.0, 50.0, 0.10],
      );

      expect(result.lines[1].gas, _air);
      expect(result.lines[1].unitPricePer100, 0.10);
      // 10 L x 20 bar / 100 x 0.10 = 0.20, not the 100.00 helium would cost.
      expect(result.lines[1].cost, closeTo(0.20, 1e-9));
      expect(result.total, closeTo(2.0 + 0.20, 1e-9));
    });
    test('a billable step with no bank trips the guard in debug', () {
      // Raised in review on PR #1215. BlendStep says a billable step always
      // names its bank, but defaulting a missing one to 0 would charge
      // oxygen's rate for whatever the gas actually is. Debug builds fail
      // loudly rather than mis-bill.
      expect(
        () => computeBlendCost(
          blend: _blend([_step(null, 0), _step(_he, 50)]),
          waterLiters: 10,
          pricesPer100: [2.0, 50.0, 0.10],
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('every step from a real blend names its bank', () {
      // The invariant the assert protects, exercised through the solver rather
      // than through hand-built steps.
      final blend = computeBlend(
        const GasBlenderInputs(
          startPressureBar: 0,
          start: GasMix(o2: 21),
          targetPressureBar: 200,
          target: GasMix(o2: 32),
          fillGas1: _o2,
          fillGas2: GasMix(o2: 0, he: 100),
          fillGas3: _air,
        ),
      );
      for (final step in blend.steps) {
        expect(step.fillGasIndex == null, step.fillGas == null);
      }
      final result = computeBlendCost(
        blend: blend,
        waterLiters: 12,
        pricesPer100: [2.0, 50.0, 0.10],
      );
      // O2 came from bank 0 and air from bank 2, the helium bank untouched.
      expect(result.lines.map((l) => l.gasIndex).toList(), [0, 2]);
      expect(result.total, isNotNull);
    });
  });
}
