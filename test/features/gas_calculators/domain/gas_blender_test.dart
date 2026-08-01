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
}
