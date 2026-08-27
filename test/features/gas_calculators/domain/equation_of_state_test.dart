// Reference values computed from the same virial coefficients and van der
// Waals constants the implementation uses, so these pin behaviour rather than
// re-deriving it. The van der Waals figures are deliberately kept even though
// they disagree with the measured compressibility: see the accuracy note in
// equation_of_state.dart.

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    show GasMix;
import 'package:submersion/features/gas_calculators/domain/blending/equation_of_state.dart';

const _air = GasMix(o2: 21);
const _o2 = GasMix(o2: 100);
const _he = GasMix(o2: 0, he: 100);
const _tx = GasMix(o2: 18, he: 45);

final _k20 = celsiusToKelvin(20);

void main() {
  group('celsiusToKelvin', () {
    test('converts the reference temperature', () {
      expect(celsiusToKelvin(20), closeTo(293.15, 1e-9));
      expect(celsiusToKelvin(0), closeTo(273.15, 1e-9));
    });
  });

  group('BlendGasModel.fromName', () {
    test('round-trips every value', () {
      for (final m in BlendGasModel.values) {
        expect(BlendGasModel.fromName(m.name), m);
      }
    });

    test('falls back to zFactor for unknown or missing input', () {
      expect(BlendGasModel.fromName(null), BlendGasModel.zFactor);
      expect(BlendGasModel.fromName('newtonian'), BlendGasModel.zFactor);
    });
  });

  group('zFactor', () {
    test('air is just under 1 at the surface and above 1 at fill pressure', () {
      expect(zFactor(1, _air), closeTo(0.99967, 1e-4));
      expect(zFactor(200, _air), closeTo(1.03577, 1e-4));
    });

    test('helium sits above 1, oxygen below', () {
      expect(zFactor(200, _he), closeTo(1.09436, 1e-4));
      expect(zFactor(200, _o2), closeTo(0.95710, 1e-4));
    });
  });

  group('ideal model', () {
    test('density follows the closed form', () {
      expect(
        molarDensity(BlendGasModel.ideal, 200, _air, _k20),
        closeTo(200 / (kGasConstant * _k20), 1e-9),
      );
    });

    test('is independent of the mix', () {
      expect(
        molarDensity(BlendGasModel.ideal, 200, _he, _k20),
        closeTo(molarDensity(BlendGasModel.ideal, 200, _air, _k20), 1e-9),
      );
    });

    test('scales inversely with temperature', () {
      final cold = molarDensity(
        BlendGasModel.ideal,
        200,
        _air,
        celsiusToKelvin(0),
      );
      final warm = molarDensity(
        BlendGasModel.ideal,
        200,
        _air,
        celsiusToKelvin(40),
      );
      expect(cold, greaterThan(warm));
      expect(
        cold / warm,
        closeTo(celsiusToKelvin(40) / celsiusToKelvin(0), 1e-9),
      );
    });
  });

  group('zFactor model', () {
    test('reproduces the compressibility-corrected density', () {
      expect(
        molarDensity(BlendGasModel.zFactor, 200, _tx, _k20),
        closeTo(200 / (zFactor(200, _tx) * kGasConstant * _k20), 1e-9),
      );
    });

    test('carries temperature through the ideal factor only', () {
      final cold = molarDensity(
        BlendGasModel.zFactor,
        200,
        _air,
        celsiusToKelvin(0),
      );
      final warm = molarDensity(
        BlendGasModel.zFactor,
        200,
        _air,
        celsiusToKelvin(40),
      );
      expect(
        cold / warm,
        closeTo(celsiusToKelvin(40) / celsiusToKelvin(0), 1e-9),
      );
    });
  });

  group('van der Waals model', () {
    test('overcorrects relative to the measured compressibility', () {
      // Van der Waals is qualitative at fill pressure. Air's true Z near
      // 200 bar is about 1.036 (the virial figure); van der Waals says 0.982.
      // This test pins the known disagreement so nobody "fixes" it into
      // agreement and silently changes which model the picker recommends.
      final rho = molarDensity(BlendGasModel.vanDerWaals, 200, _air, _k20);
      expect(200 / (rho * kGasConstant * _k20), closeTo(0.98169, 1e-4));
    });

    test('helium and oxygen land on opposite sides of ideal', () {
      double z(GasMix m) =>
          200 /
          (molarDensity(BlendGasModel.vanDerWaals, 200, m, _k20) *
              kGasConstant *
              _k20);
      expect(z(_he), closeTo(1.18709, 1e-4));
      expect(z(_o2), closeTo(0.89294, 1e-4));
    });

    test('pressure rises monotonically with density', () {
      var previous = 0.0;
      for (var rho = 0.5; rho < 12; rho += 0.5) {
        final p = pressureAt(BlendGasModel.vanDerWaals, rho, _air, _k20);
        expect(p, greaterThan(previous));
        previous = p;
      }
    });
  });

  group('round-trip', () {
    test('pressureAt inverts molarDensity for every model', () {
      for (final model in BlendGasModel.values) {
        for (final mix in [_air, _o2, _he, _tx]) {
          for (final p in [1.0, 50.0, 100.0, 200.0, 300.0]) {
            for (final t in [celsiusToKelvin(0), _k20, celsiusToKelvin(35)]) {
              final rho = molarDensity(model, p, mix, t);
              expect(
                pressureAt(model, rho, mix, t),
                closeTo(p, 0.001),
                reason: 'model=$model mix=${mix.o2}/${mix.he} p=$p t=$t',
              );
            }
          }
        }
      }
    });

    test('non-positive input yields zero', () {
      for (final model in BlendGasModel.values) {
        expect(molarDensity(model, 0, _air, _k20), 0);
        expect(molarDensity(model, -5, _air, _k20), 0);
        expect(pressureAt(model, 0, _air, _k20), 0);
        expect(pressureAt(model, -1, _air, _k20), 0);
      }
    });
  });
  group('beyond the fitted range', () {
    // The virial is a cubic fitted over cylinder pressures. Extrapolated far
    // past them its p^3 term takes Z negative, and the fixed-point iteration
    // in pressureAt then walks off to NaN rather than to an answer. Nothing
    // stops a diver typing 5000 bar as a target, so it is clamped, matching
    // what core/utils/gas_compressibility.dart has always done.
    test('Z stays positive and finite well past any cylinder', () {
      for (final p in [500.0, 1000.0, 5000.0, 50000.0]) {
        for (final mix in [_air, _o2, _he, _tx]) {
          final z = zFactor(p, mix);
          expect(z.isFinite, isTrue, reason: 'Z($p, ${mix.o2}/${mix.he})');
          expect(z, greaterThan(0), reason: 'Z($p, ${mix.o2}/${mix.he})');
        }
      }
    });

    test('Z is flat above the clamp rather than diverging', () {
      expect(zFactor(600, _air), zFactor(500, _air));
      expect(zFactor(5000, _air), zFactor(500, _air));
    });

    test('pressureAt never returns NaN, however dense', () {
      for (final model in BlendGasModel.values) {
        for (final rho in [1.0, 10.0, 25.0, 39.0]) {
          final p = pressureAt(model, rho, _air, _k20);
          expect(p.isNaN, isFalse, reason: 'model=$model rho=$rho');
        }
      }
    });

    test('an absurd target pressure still yields a finite density', () {
      for (final model in BlendGasModel.values) {
        final rho = molarDensity(model, 5000, _air, _k20);
        expect(rho.isFinite, isTrue, reason: '$model');
        expect(rho, greaterThan(0), reason: '$model');
      }
    });
  });
}
