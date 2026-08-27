// Cross-checks the Dart real-gas blender against the reference JavaScript
// implementation (Blei-Log). The expected intermediate pressures and volumes
// were produced by running the original functions on the same inputs.

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    show GasMix;
import 'package:submersion/features/gas_calculators/domain/gas_blender.dart';

const _o2 = GasMix(o2: 100);
const _air = GasMix(o2: 21);
const _he = GasMix(o2: 0, he: 100);

GasBlenderInputs _inputs({
  double startBar = 0,
  GasMix start = _air,
  required double targetBar,
  required GasMix target,
  GasMix g1 = _o2,
  GasMix g2 = _air,
  GasMix g3 = _air,
}) => GasBlenderInputs(
  startPressureBar: startBar,
  start: start,
  targetPressureBar: targetBar,
  target: target,
  fillGas1: g1,
  fillGas2: g2,
  fillGas3: g3,
);

void main() {
  group('real-gas helpers', () {
    test(
      'Z of air at 1 bar is just under 1; helium at pressure is above 1',
      () {
        expect(zFactor(1, _air), closeTo(0.9997, 0.001));
        expect(zFactor(200, _he), greaterThan(1.0));
      },
    );

    test('pressureForVolume inverts normalVolume', () {
      const mix = GasMix(o2: 32);
      final v = normalVolume(200, mix);
      expect(pressureForVolume(mix, v), closeTo(200, 0.01));
    });
  });

  group('nitrox blend (empty -> EAN32 from O2 + air)', () {
    final result = computeBlend(
      _inputs(targetBar: 200, target: const GasMix(o2: 32)),
    );

    test('produces start + two fill steps', () {
      expect(result.steps, hasLength(3));
      expect(result.steps.first.fillGas, isNull);
      expect(result.steps.first.pressureBar, 0);
    });

    test('fills O2 to the reference intermediate pressure', () {
      final o2Step = result.steps[1];
      expect(o2Step.fillGas, _o2);
      expect(o2Step.pressureBar, closeTo(26.716, 0.05));
      expect(o2Step.addedVolumePerLiter, closeTo(27.164, 0.05));
    });

    test('tops with air to the target mix and pressure', () {
      final last = result.steps.last;
      expect(last.fillGas, _air);
      expect(last.pressureBar, 200);
      expect(last.resultingMix.o2, closeTo(32, 0.01));
      expect(last.resultingMix.he, closeTo(0, 0.01));
    });
  });

  group('trimix blend (empty -> 18/45 from O2 + He + air)', () {
    final result = computeBlend(
      _inputs(
        targetBar: 200,
        target: const GasMix(o2: 18, he: 45),
        g2: _he,
        g3: _air,
      ),
    );

    test('produces start + three fill steps', () {
      expect(result.steps, hasLength(4));
    });

    test('matches the reference O2 and He intermediate pressures', () {
      expect(result.steps[1].fillGas, _o2);
      expect(result.steps[1].pressureBar, closeTo(15.319, 0.05));
      expect(result.steps[2].fillGas, _he);
      expect(result.steps[2].pressureBar, closeTo(104.231, 0.05));
    });

    test('matches the reference fill volumes and reaches the target', () {
      expect(result.steps[1].addedVolumePerLiter, closeTo(15.47, 0.05));
      expect(result.steps[2].addedVolumePerLiter, closeTo(85.25, 0.05));
      expect(result.steps[3].addedVolumePerLiter, closeTo(88.73, 0.05));
      expect(result.steps.last.pressureBar, 200);
      expect(result.steps.last.resultingMix.o2, closeTo(18, 0.01));
      expect(result.steps.last.resultingMix.he, closeTo(45, 0.01));
    });

    test('intermediate pressures increase monotonically', () {
      final p = result.steps.map((s) => s.pressureBar).toList();
      for (var i = 1; i < p.length; i++) {
        expect(p[i], greaterThan(p[i - 1]));
      }
    });
  });

  group('errors', () {
    BlendError errorFrom(GasBlenderInputs i) {
      try {
        computeBlend(i);
      } on BlendException catch (e) {
        return e.error;
      }
      fail('expected a BlendException');
    }

    test('target pressure must exceed the start pressure', () {
      expect(
        errorFrom(
          _inputs(startBar: 200, targetBar: 200, target: const GasMix(o2: 32)),
        ),
        BlendError.targetPressureNotHigher,
      );
    });

    test('cannot dilute a rich start with only O2 and air', () {
      expect(
        errorFrom(
          _inputs(
            startBar: 100,
            start: const GasMix(o2: 40),
            targetBar: 200,
            target: const GasMix(o2: 21),
          ),
        ),
        BlendError.negativeAmountRequired,
      );
    });

    test('two identical nitrox fill gases cannot mix', () {
      expect(
        errorFrom(
          _inputs(
            targetBar: 200,
            target: const GasMix(o2: 32),
            g1: _air,
            g2: _air,
          ),
        ),
        BlendError.identicalNitroxGases,
      );
    });

    test('a trimix target needs a helium source', () {
      expect(
        errorFrom(
          _inputs(
            targetBar: 200,
            target: const GasMix(o2: 18, he: 45),
            g1: _o2,
            g2: _air,
            g3: const GasMix(o2: 50),
          ),
        ),
        BlendError.linearlyDependentGases,
      );
    });

    test('a mix over 100% is rejected', () {
      expect(
        errorFrom(
          _inputs(targetBar: 200, target: const GasMix(o2: 80, he: 40)),
        ),
        BlendError.invalidMix,
      );
    });
  });

  // Every reported mix must survive an independent mass balance: replay the
  // volumes the procedure says to add and recompute what is actually in the
  // cylinder. The solver must never assert a mix it did not compute.
  group('mass balance', () {
    ({double o2, double he}) actualEndMix(GasBlenderInputs i, BlendResult r) {
      var vO2 = 0.0, vHe = 0.0, vTotal = 0.0;
      final startVol = normalVolume(i.startPressureBar, i.start);
      vO2 += i.start.o2 / 100 * startVol;
      vHe += i.start.he / 100 * startVol;
      vTotal += startVol;
      for (final s in r.steps.where((s) => s.fillGas != null)) {
        final v = s.addedVolumePerLiter!;
        vO2 += s.fillGas!.o2 / 100 * v;
        vHe += s.fillGas!.he / 100 * v;
        vTotal += v;
      }
      return (o2: 100 * vO2 / vTotal, he: 100 * vHe / vTotal);
    }

    final cases = <String, GasBlenderInputs>{
      'empty -> EAN32': _inputs(targetBar: 200, target: const GasMix(o2: 32)),
      'partial EAN32 -> EAN32': _inputs(
        startBar: 60,
        start: const GasMix(o2: 32),
        targetBar: 200,
        target: const GasMix(o2: 32),
      ),
      'empty -> Tx 18/45': _inputs(
        targetBar: 200,
        target: const GasMix(o2: 18, he: 45),
        g2: _he,
        g3: _air,
      ),
      'Tx 21/35 -> Tx 18/45': _inputs(
        startBar: 80,
        start: const GasMix(o2: 21, he: 35),
        targetBar: 200,
        target: const GasMix(o2: 18, he: 45),
        g2: _he,
        g3: _air,
      ),
    };

    cases.forEach((name, inputs) {
      test('$name: the reported end mix matches the gas actually added', () {
        final result = computeBlend(inputs);
        final actual = actualEndMix(inputs, result);
        expect(result.steps.last.resultingMix.o2, closeTo(actual.o2, 0.01));
        expect(result.steps.last.resultingMix.he, closeTo(actual.he, 0.01));
        expect(
          result.steps.last.resultingMix.o2,
          closeTo(inputs.target.o2, 0.01),
        );
        expect(
          result.steps.last.resultingMix.he,
          closeTo(inputs.target.he, 0.01),
        );
      });
    });
  });

  group('helium the target does not want', () {
    test('a cylinder holding helium cannot reach a helium-free target', () {
      // Adding gas dilutes helium but never removes it. Reporting "EAN32"
      // here would hand the diver a trimix an O2 analyser cannot detect.
      try {
        computeBlend(
          _inputs(
            startBar: 50,
            start: const GasMix(o2: 18, he: 45),
            targetBar: 200,
            target: const GasMix(o2: 32),
          ),
        );
        fail('expected a BlendException');
      } on BlendException catch (e) {
        expect(e.error, BlendError.cannotRemoveHelium);
      }
    });

    test('a helium fill gas is skipped for a nitrox target', () {
      // The shipped fill order is O2 -> He -> air. A nitrox target must use
      // the helium-free gases in that order rather than blending with helium.
      final result = computeBlend(
        _inputs(
          targetBar: 200,
          target: const GasMix(o2: 32),
          g2: _he,
          g3: _air,
        ),
      );
      expect(result.steps.map((s) => s.fillGas), [null, _o2, _air]);
      expect(result.steps.last.resultingMix.he, closeTo(0, 0.001));
    });

    test('a nitrox target needs two helium-free fill gases', () {
      try {
        computeBlend(
          _inputs(
            targetBar: 200,
            target: const GasMix(o2: 32),
            g1: _he,
            g2: _he,
            g3: _he,
          ),
        );
        fail('expected a BlendException');
      } on BlendException catch (e) {
        expect(e.error, BlendError.insufficientFillGases);
      }
    });
  });

  group('degenerate fill amounts', () {
    test('topping an air cylinder with air is a valid blend', () {
      final result = computeBlend(
        _inputs(startBar: 50, start: _air, targetBar: 200, target: _air),
      );
      expect(result.steps.last.pressureBar, 200);
      expect(result.steps.last.resultingMix.o2, closeTo(21, 0.01));
    });

    test('an air-plus-helium target never yields NaN', () {
      // fO2 = 0.21 * (1 - fHe) needs exactly zero oxygen, which used to divide
      // zero volume by zero volume on an empty cylinder.
      final result = computeBlend(
        _inputs(
          targetBar: 200,
          target: const GasMix(o2: 12.6, he: 40),
          g2: _he,
          g3: _air,
        ),
      );
      for (final s in result.steps) {
        expect(s.pressureBar.isFinite, isTrue, reason: 'pressure is NaN');
        expect(s.resultingMix.o2.isFinite, isTrue, reason: 'O2 is NaN');
        expect(s.resultingMix.he.isFinite, isTrue, reason: 'He is NaN');
      }
      expect(result.steps.last.resultingMix.o2, closeTo(12.6, 0.01));
      expect(result.steps.last.resultingMix.he, closeTo(40, 0.01));
    });

    test(
      'a fill gas that contributes nothing is left out of the procedure',
      () {
        final result = computeBlend(
          _inputs(
            targetBar: 200,
            target: const GasMix(o2: 12.6, he: 40),
            g2: _he,
            g3: _air,
          ),
        );
        expect(result.steps.map((s) => s.fillGas), [null, _he, _air]);
      },
    );
  });

  group('drain guidance', () {
    test('an over-rich cylinder reports the pressure to drain to', () {
      double? drainTo;
      try {
        computeBlend(
          _inputs(
            startBar: 150,
            start: const GasMix(o2: 40),
            targetBar: 200,
            target: const GasMix(o2: 28),
          ),
        );
        fail('expected a BlendException');
      } on BlendException catch (e) {
        expect(e.error, BlendError.negativeAmountRequired);
        drainTo = e.drainToBar;
      }

      expect(drainTo, isNotNull);
      final drain = drainTo!;
      expect(drain, closeTo(70.5, 1.0));

      // The reported pressure is the boundary: it blends, a little more does not.
      GasBlenderInputs at(double bar) => _inputs(
        startBar: bar,
        start: const GasMix(o2: 40),
        targetBar: 200,
        target: const GasMix(o2: 28),
      );
      expect(computeBlend(at(drain)).steps.last.pressureBar, 200);
      expect(() => computeBlend(at(drain + 5)), throwsA(isA<BlendException>()));
    });

    test('a blend impossible at any starting pressure drains to empty', () {
      try {
        computeBlend(
          _inputs(
            startBar: 100,
            start: const GasMix(o2: 40),
            targetBar: 200,
            target: const GasMix(o2: 21),
          ),
        );
        fail('expected a BlendException');
      } on BlendException catch (e) {
        expect(e.error, BlendError.negativeAmountRequired);
        expect(e.drainToBar, closeTo(0, 0.5));
      }
    });
  });

  group('blending temperature', () {
    GasBlenderInputs tempInputs({
      required double fillC,
      required double settledC,
      BlendGasModel model = BlendGasModel.zFactor,
    }) => GasBlenderInputs(
      startPressureBar: 0,
      start: _air,
      targetPressureBar: 200,
      target: const GasMix(o2: 18, he: 45),
      fillGas1: _o2,
      fillGas2: _he,
      fillGas3: _air,
      model: model,
      fillTempC: fillC,
      settledTempC: settledC,
    );

    test('equal temperatures reproduce the untemperatured procedure', () {
      final plain = computeBlend(
        _inputs(
          targetBar: 200,
          target: const GasMix(o2: 18, he: 45),
          g2: _he,
          g3: _air,
        ),
      );
      final explicit = computeBlend(tempInputs(fillC: 20, settledC: 20));
      for (var i = 0; i < plain.steps.length; i++) {
        expect(
          explicit.steps[i].pressureBar,
          closeTo(plain.steps[i].pressureBar, 1e-6),
        );
      }
    });

    test('a cylinder filled cold stops at a lower gauge reading', () {
      final cold = computeBlend(tempInputs(fillC: 5, settledC: 20));
      expect(cold.steps[1].pressureBar, closeTo(14.532, 0.05));
      expect(cold.steps[2].pressureBar, closeTo(98.733, 0.05));
      expect(cold.steps[3].pressureBar, closeTo(188.763, 0.05));
      expect(cold.settledPressureBar, 200);
    });

    test('a cylinder filled warm has to overshoot', () {
      final warm = computeBlend(tempInputs(fillC: 35, settledC: 20));
      expect(warm.steps[1].pressureBar, closeTo(16.083, 0.05));
      expect(warm.steps[3].pressureBar, closeTo(211.411, 0.05));
      expect(warm.settledPressureBar, 200);
    });

    test('temperature does not change the mix reached', () {
      for (final fill in [0.0, 5.0, 20.0, 35.0]) {
        final r = computeBlend(tempInputs(fillC: fill, settledC: 20));
        expect(r.steps.last.resultingMix.o2, closeTo(18, 0.01));
        expect(r.steps.last.resultingMix.he, closeTo(45, 0.01));
      }
    });

    test('addedBar is the gauge difference between consecutive steps', () {
      final r = computeBlend(tempInputs(fillC: 5, settledC: 20));
      expect(r.steps.first.addedBar, 0);
      for (var i = 1; i < r.steps.length; i++) {
        expect(
          r.steps[i].addedBar,
          closeTo(r.steps[i].pressureBar - r.steps[i - 1].pressureBar, 1e-9),
        );
      }
    });
  });

  group('gas model selection', () {
    GasBlenderInputs modelInputs(BlendGasModel model) => GasBlenderInputs(
      startPressureBar: 0,
      start: _air,
      targetPressureBar: 200,
      target: const GasMix(o2: 18, he: 45),
      fillGas1: _o2,
      fillGas2: _he,
      fillGas3: _air,
      model: model,
    );

    test('each model gives its own O2 intermediate pressure', () {
      expect(
        computeBlend(modelInputs(BlendGasModel.zFactor)).steps[1].pressureBar,
        closeTo(15.308, 0.05),
      );
      expect(
        computeBlend(modelInputs(BlendGasModel.ideal)).steps[1].pressureBar,
        closeTo(16.329, 0.05),
      );
      expect(
        computeBlend(
          modelInputs(BlendGasModel.vanDerWaals),
        ).steps[1].pressureBar,
        closeTo(14.247, 0.05),
      );
    });

    test('every model reaches the requested mix and pressure', () {
      for (final model in BlendGasModel.values) {
        final r = computeBlend(modelInputs(model));
        expect(r.steps.last.resultingMix.o2, closeTo(18, 0.01));
        expect(r.steps.last.resultingMix.he, closeTo(45, 0.01));
        expect(r.steps.last.pressureBar, closeTo(200, 0.01));
      }
    });
  });
  group('implausible cylinder contents', () {
    // Reported on PR #1215: the blender produced a confident fill procedure
    // for a cylinder that held 0% O2 and 0% He, i.e. 40 bar of pure nitrogen.
    // Nobody stocks that gas, and the resulting procedure disagreed with three
    // other blending tools. The UI could reach that state by clearing a mix
    // field; this is the backstop for anything else that can.
    test('a pressurised cylinder cannot hold neither oxygen nor helium', () {
      try {
        computeBlend(
          _inputs(
            startBar: 40,
            start: const GasMix(o2: 0),
            targetBar: 200,
            target: const GasMix(o2: 15, he: 55),
            g2: _he,
            g3: _air,
          ),
        );
        fail('expected a BlendException');
      } on BlendException catch (e) {
        expect(e.error, BlendError.implausibleStartMix);
      }
    });

    test('an empty cylinder may hold nothing at all', () {
      // Zero bar of "nothing" is just an empty cylinder, which is the most
      // common starting point there is.
      final result = computeBlend(
        _inputs(
          startBar: 0,
          start: const GasMix(o2: 0),
          targetBar: 200,
          target: const GasMix(o2: 15, he: 55),
          g2: _he,
          g3: _air,
        ),
      );
      expect(result.steps.last.resultingMix.he, closeTo(55, 0.01));
    });

    test('pure helium in the cylinder is legitimate', () {
      final result = computeBlend(
        _inputs(
          startBar: 40,
          start: _he,
          targetBar: 200,
          target: const GasMix(o2: 15, he: 55),
          g2: _he,
          g3: _air,
        ),
      );
      expect(result.steps.last.resultingMix.o2, closeTo(15, 0.01));
    });

    test('the reporter cylinder blends and matches the other tools', () {
      // Start 40 bar of 14.5/57.2 to 200 bar of 15/55. Under the ideal model
      // this is 11.3 / 87.1 / 61.6, which is what Gasblender Toolkit reports
      // to the decimal, with Multideco and arcusblender alongside.
      final result = computeBlend(
        const GasBlenderInputs(
          startPressureBar: 40,
          start: GasMix(o2: 14.5, he: 57.2),
          targetPressureBar: 200,
          target: GasMix(o2: 15, he: 55),
          fillGas1: _o2,
          fillGas2: _he,
          fillGas3: _air,
          model: BlendGasModel.ideal,
        ),
      );
      final added = result.steps
          .where((s) => s.fillGas != null)
          .map((s) => s.addedBar)
          .toList();
      expect(added[0], closeTo(11.3, 0.05));
      expect(added[1], closeTo(87.1, 0.05));
      expect(added[2], closeTo(61.6, 0.05));
    });
  });
}
