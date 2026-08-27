# Trimix Blender Optimisation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn the partial-pressure gas blender into a tool a fill station can
work from: readable precision, fill amounts in bar, reusable target-mix
templates, a fill temperature, a selectable equation of state, and gas costing.

**Architecture:** The solver's conserved quantity changes from a
temperature-free "normal volume" to molar density, which is what lets a fill
temperature exist at all. A new equation-of-state module sits underneath with
three models. Everything else (templates, prices, costing) is additive: a JSON
blob in the existing `settings` key-value table, and new cards in a decomposed
blender widget directory.

**Tech Stack:** Flutter, Riverpod (`StateProvider` / `Provider`), Drift,
`flutter gen-l10n`, `flutter_test`.

**Spec:** `docs/superpowers/specs/2026-08-20-trimix-blender-optimisation-design.md`

## Global Constraints

- **No em-dashes** (U+2014) in any output: code, comments, commit messages, ARB
  strings, docs. No en-dash or " - " used as prose punctuation either.
- **No emojis** in code, comments, or documentation.
- `dart format .` must produce no changes before any commit.
- `flutter analyze` must be clean. Infos are fatal in CI.
- Every user-facing string goes in `lib/l10n/arb/app_en.arb` **and** all ten
  locale ARBs (`ar de es fr he hu it nl pt zh`). Run `flutter gen-l10n` **last**,
  after all translations are in place.
- All pressures stored in bar, volumes in litres, temperatures in Celsius.
  Display converts through `UnitFormatter`.
- Files stay under 800 lines; 200-400 is typical.
- Never run two `flutter test` invocations concurrently in this repo.
- Do not pipe `flutter test` into `grep`; the exit code becomes grep's.

---

### Task 1: Equation of state module

Creates the three-model equation of state that everything downstream depends on.
Nothing else changes yet, so this task is entirely additive.

**Files:**
- Create: `lib/features/gas_calculators/domain/blending/equation_of_state.dart`
- Test: `test/features/gas_calculators/domain/equation_of_state_test.dart`

**Interfaces:**
- Consumes: `GasMix` from `lib/features/dive_log/domain/entities/dive.dart`.
- Produces:
  - `enum BlendGasModel { ideal, vanDerWaals, zFactor }` with
    `static BlendGasModel fromName(String? name)` falling back to `zFactor`.
  - `const double kGasConstant = 0.083144626;` (L bar / mol K)
  - `const double kReferenceTempC = 20.0;`
  - `double celsiusToKelvin(double celsius)`
  - `double zFactor(double p, GasMix m)`
  - `double molarDensity(BlendGasModel model, double bar, GasMix mix, double kelvin)`
  - `double pressureAt(BlendGasModel model, double density, GasMix mix, double kelvin)`

- [ ] **Step 1: Write the failing test**

Create `test/features/gas_calculators/domain/equation_of_state_test.dart`:

```dart
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
      final cold = molarDensity(BlendGasModel.ideal, 200, _air, celsiusToKelvin(0));
      final warm = molarDensity(BlendGasModel.ideal, 200, _air, celsiusToKelvin(40));
      expect(cold, greaterThan(warm));
      expect(cold / warm, closeTo(celsiusToKelvin(40) / celsiusToKelvin(0), 1e-9));
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
      final cold = molarDensity(BlendGasModel.zFactor, 200, _air, celsiusToKelvin(0));
      final warm = molarDensity(BlendGasModel.zFactor, 200, _air, celsiusToKelvin(40));
      expect(cold / warm, closeTo(celsiusToKelvin(40) / celsiusToKelvin(0), 1e-9));
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
          200 / (molarDensity(BlendGasModel.vanDerWaals, 200, m, _k20) *
              kGasConstant * _k20);
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
}
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
flutter test test/features/gas_calculators/domain/equation_of_state_test.dart
```

Expected: FAIL at compile, `Target of URI doesn't exist: '.../blending/equation_of_state.dart'`.

- [ ] **Step 3: Write the implementation**

Create `lib/features/gas_calculators/domain/blending/equation_of_state.dart`:

```dart
import 'dart:math' as math;

import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    show GasMix;

/// Which equation of state converts between cylinder pressure and amount of
/// gas while blending.
///
/// This is deliberately separate from the app-wide `GasModel` preference.
/// Blending is the one place a diver wants to match whatever software their
/// fill station runs, and [vanDerWaals] would be meaningless applied to a SAC
/// rate.
enum BlendGasModel {
  /// `p = rho R T`. Matches hand calculation and most published blending
  /// tables.
  ideal,

  /// Van der Waals with one-fluid mixing. The only model here whose constants
  /// carry a temperature dependence of their own, and the least accurate at
  /// fill pressure. See the accuracy note on [molarDensity].
  vanDerWaals,

  /// Virial compressibility factor. The most accurate of the three at
  /// cylinder pressures, and what the blender used unconditionally before the
  /// picker existed.
  zFactor;

  /// Parse a stored value, falling back to [zFactor] so an unreadable
  /// preference never silently changes a fill procedure.
  static BlendGasModel fromName(String? name) {
    for (final model in BlendGasModel.values) {
      if (model.name == name) return model;
    }
    return BlendGasModel.zFactor;
  }
}

/// Universal gas constant in L bar / (mol K).
const double kGasConstant = 0.083144626;

/// The temperature a cylinder pressure is quoted at when the diver has not
/// said otherwise. Also the temperature the virial coefficients below are fit
/// at.
const double kReferenceTempC = 20.0;

double celsiusToKelvin(double celsius) => celsius + 273.15;

// Virial coefficients (bar) for the compressibility factor of each component.
const List<double> _o2Coef = [
  -7.18092073703e-04,
  2.81852572808e-06,
  -1.50290620492e-09,
];
const List<double> _n2Coef = [
  -2.19260353292e-04,
  2.92844845532e-06,
  -2.07613482075e-09,
];
const List<double> _heCoef = [
  4.87320026468e-04,
  -8.83632921053e-08,
  5.33304543646e-11,
];

// Van der Waals constants, in L^2 bar / mol^2 and L / mol.
const double _aO2 = 1.382;
const double _bO2 = 0.03186;
const double _aN2 = 1.370;
const double _bN2 = 0.0387;
const double _aHe = 0.0346;
const double _bHe = 0.0238;

double _virial(double p, List<double> c) =>
    c[0] * p + c[1] * p * p + c[2] * p * p * p;

double _fO2(GasMix m) => m.o2 / 100;
double _fHe(GasMix m) => m.he / 100;
double _fN2(GasMix m) => (100 - m.o2 - m.he) / 100;

/// Real-gas compressibility factor Z of [m] at pressure [p] bar.
double zFactor(double p, GasMix m) =>
    1 +
    _fO2(m) * _virial(p, _o2Coef) +
    _fHe(m) * _virial(p, _heCoef) +
    _fN2(m) * _virial(p, _n2Coef);

/// One-fluid van der Waals mixing: `a_mix = (sum x_i sqrt(a_i))^2`.
double _aMix(GasMix m) {
  final root =
      _fO2(m) * math.sqrt(_aO2) +
      _fHe(m) * math.sqrt(_aHe) +
      _fN2(m) * math.sqrt(_aN2);
  return root * root;
}

/// One-fluid van der Waals mixing: `b_mix = sum x_i b_i`.
double _bMix(GasMix m) => _fO2(m) * _bO2 + _fHe(m) * _bHe + _fN2(m) * _bN2;

/// Moles of [mix] per litre of cylinder at [bar] and [kelvin].
///
/// Molar density is the quantity the blender conserves, because mixing adds
/// moles exactly while it adds neither pressure nor volume exactly.
///
/// Accuracy, worth knowing before choosing a model:
///
/// * [BlendGasModel.zFactor] is the most accurate here, but its virial
///   coefficients are a fit at roughly [kReferenceTempC]. It therefore treats
///   Z as a function of pressure and composition only, and carries temperature
///   solely through the ideal `R T` factor.
/// * [BlendGasModel.vanDerWaals] is the only model whose own constants carry
///   temperature, but it is quantitatively poor at fill pressure. At 200 bar
///   and 20 C it puts Z for air at 0.982 against a measured 1.036, and for
///   helium at 1.187 against 1.094. It does not sit between ideal and
///   accurate: it overshoots past accurate by roughly as much as ideal
///   undershoots.
/// * [BlendGasModel.ideal] is exact only as a limit and runs a few percent
///   off at cylinder pressures, but it is what most published blending tables
///   assume.
double molarDensity(
  BlendGasModel model,
  double bar,
  GasMix mix,
  double kelvin,
) {
  if (bar <= 0) return 0;
  switch (model) {
    case BlendGasModel.ideal:
      return bar / (kGasConstant * kelvin);
    case BlendGasModel.zFactor:
      return bar / (zFactor(bar, mix) * kGasConstant * kelvin);
    case BlendGasModel.vanDerWaals:
      // p(rho) is strictly increasing across the whole bracket at any
      // blending temperature: every component's critical temperature (O2
      // 154 K, N2 126 K, He 5.2 K) is far below freezing, so there is no van
      // der Waals loop to bracket around and a bisection is exact.
      var lo = 0.0;
      var hi = 0.95 / _bMix(mix);
      for (var i = 0; i < 80; i++) {
        final mid = (lo + hi) / 2;
        if (pressureAt(model, mid, mix, kelvin) > bar) {
          hi = mid;
        } else {
          lo = mid;
        }
      }
      return (lo + hi) / 2;
  }
}

/// The pressure at which [mix] holds [density] mol/L at [kelvin]. The inverse
/// of [molarDensity].
double pressureAt(
  BlendGasModel model,
  double density,
  GasMix mix,
  double kelvin,
) {
  if (density <= 0) return 0;
  switch (model) {
    case BlendGasModel.ideal:
      return density * kGasConstant * kelvin;
    case BlendGasModel.vanDerWaals:
      final a = _aMix(mix);
      final b = _bMix(mix);
      return density * kGasConstant * kelvin / (1 - b * density) -
          a * density * density;
    case BlendGasModel.zFactor:
      // Z depends on the pressure being sought, so iterate. Converges in a
      // handful of passes across the cylinder pressure range.
      var p = density * kGasConstant * kelvin;
      for (var i = 0; i < 100; i++) {
        final next = density * zFactor(p, mix) * kGasConstant * kelvin;
        if ((next - p).abs() < 0.0001) return next;
        p = next;
      }
      return p;
  }
}
```

- [ ] **Step 4: Run the test to verify it passes**

```bash
flutter test test/features/gas_calculators/domain/equation_of_state_test.dart
```

Expected: PASS, all tests.

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add lib/features/gas_calculators/domain/blending/equation_of_state.dart \
        test/features/gas_calculators/domain/equation_of_state_test.dart
git commit -m "feat(blender): three-model equation of state on molar density

Adds ideal, van der Waals and virial Z models behind a common
molarDensity/pressureAt pair. Molar density is the quantity a blend
conserves exactly, which is what lets a fill temperature exist.

Refs #1100"
```

---

### Task 2: Solve on molar density, with fill and settled temperatures

Rewrites the blender's conserved quantity and adds the temperature and model
inputs. The existing 394-line `gas_blender_test.dart` is the regression gate and
must pass **unmodified**.

**Files:**
- Modify: `lib/features/gas_calculators/domain/gas_blender.dart` (whole file)
- Modify: `lib/features/gas_calculators/presentation/providers/gas_calculators_providers.dart:186-206` (`blenderResultProvider`)
- Test: `test/features/gas_calculators/domain/gas_blender_test.dart` (append one new group; do not touch existing groups)

**Interfaces:**
- Consumes: `BlendGasModel`, `molarDensity`, `pressureAt`, `zFactor`,
  `celsiusToKelvin`, `kGasConstant`, `kReferenceTempC` from Task 1.
- Produces:
  - `GasBlenderInputs` with three new **optional** named parameters:
    `BlendGasModel model = BlendGasModel.zFactor`,
    `double fillTempC = kReferenceTempC`,
    `double settledTempC = kReferenceTempC`.
  - `BlendStep` with a new `final double addedBar` field (0 for the start step).
  - `BlendResult` with a new `final double settledPressureBar` field.
  - `gas_blender.dart` continues to export `zFactor`, `normalVolume` and
    `pressureForVolume` with today's signatures.

**Background the implementer needs:**

The old conserved quantity was `normalVolume(p, m) = p * zFactor(1, m) / zFactor(p, m)`,
which is moles multiplied by `R * T * zFactor(1, mix)`. That trailing
mix-dependent factor is an artifact of the reference implementation this was
ported from, and it makes mixing very slightly non-linear. Switching to true
moles removes it. The resulting shift is small enough to stay inside the
existing test's tolerances:

| Existing assertion | Old value | New value | Tolerance |
| --- | --- | --- | --- |
| EAN32 O2 step pressure | 26.716 | 26.700 | 0.05 |
| EAN32 O2 step volume | 27.164 | 27.174 | 0.05 |
| Tx 18/45 O2 step pressure | 15.319 | 15.308 | 0.05 |
| Tx 18/45 He step pressure | 104.231 | 104.263 | 0.05 |
| Tx 18/45 added volumes | 15.47 / 85.25 / 88.73 | 15.467 / 85.25 / 88.73 | 0.05 |

`addedVolumePerLiter` keeps its old meaning and units by being reported as
`molesAdded * kGasConstant * settledKelvin`, so it stays a surface-equivalent
volume and the three volume assertions above continue to match.

If any reference assertion lands just outside its tolerance, widen that one
tolerance to 0.1 and add a comment naming the mole-balance correction. Do
**not** change an expected value: those numbers are the cross-check against the
reference implementation.

- [ ] **Step 1: Write the failing test**

Append this group to `test/features/gas_calculators/domain/gas_blender_test.dart`,
inside `main()`, after the existing groups. Add
`import 'package:submersion/features/gas_calculators/domain/blending/equation_of_state.dart';`
to the imports.

```dart
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
        _inputs(targetBar: 200, target: const GasMix(o2: 18, he: 45),
            g2: _he, g3: _air),
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
        computeBlend(modelInputs(BlendGasModel.vanDerWaals)).steps[1].pressureBar,
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
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
flutter test test/features/gas_calculators/domain/gas_blender_test.dart
```

Expected: FAIL at compile, `No named parameter with the name 'model'`.

- [ ] **Step 3: Rewrite the solver**

Replace `lib/features/gas_calculators/domain/gas_blender.dart` with the
following. The linear algebra in `_solveTops` and the bisection in
`_largestFeasibleStartVolume` are byte-identical to today; only the conserved
quantity, the temperature boundaries, and the two new fields change.

```dart
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    show GasMix;
import 'package:submersion/features/gas_calculators/domain/blending/equation_of_state.dart';

export 'package:submersion/features/gas_calculators/domain/blending/equation_of_state.dart'
    show BlendGasModel, zFactor, kReferenceTempC, celsiusToKelvin;

/// Partial-pressure gas blending with a selectable equation of state.
///
/// Given a cylinder's starting fill (pressure + mix) and a desired end fill,
/// this computes the fill order and the intermediate pressures to top up to,
/// using up to three fill gases (e.g. oxygen, air, helium). Helium/nitrox are
/// handled by the same solver: a two-gas linear solve for nitrox targets and a
/// three-gas solve for trimix.
///
/// The conserved quantity is molar density, because mixing adds moles exactly
/// while it adds neither pressure nor volume exactly. That is also what makes
/// two temperatures expressible: the solve itself is temperature-free, and
/// temperature enters only when converting a gauge reading to moles and back.
///
/// All pressures are in bar and all temperatures in Celsius; callers convert
/// for display.

/// Surface-equivalent ("normal") gas volume for [p] bar of mix [m], per unit
/// cylinder volume, at [kReferenceTempC].
///
/// Retained for callers that predate the molar-density rewrite. Equal to
/// `molarDensity(zFactor, p, m, T20) * kGasConstant * T20 * zFactor(1, m)`.
double normalVolume(double p, GasMix m) => p * zFactor(1, m) / zFactor(p, m);

/// Inverse of [normalVolume]: the real pressure (bar) holding surface volume
/// [vol] of mix [m]. Fixed-point iteration (Z depends on the pressure sought).
double pressureForVolume(GasMix m, double vol) {
  var p = vol;
  for (var i = 0; i < 100; i++) {
    final pNew = vol * zFactor(p, m) / zFactor(1, m);
    if ((pNew - p).abs() < 0.0001) {
      p = pNew;
      break;
    }
    p = pNew;
  }
  return p;
}

/// Why a blend cannot be produced. Mapped to a localized message by the UI.
enum BlendError {
  targetPressureNotHigher,
  invalidMix,
  identicalNitroxGases,
  linearlyDependentGases,
  negativeAmountRequired,

  /// The cylinder already holds helium that the target mix does not allow.
  /// Topping up dilutes helium but can never remove it.
  cannotRemoveHelium,

  /// A helium-free target needs two helium-free fill gases to blend between.
  insufficientFillGases,

  /// The computed procedure does not land on the requested mix. A guard
  /// against a solver that reports a target it did not actually reach.
  targetNotReached,
}

class BlendException implements Exception {
  const BlendException(this.error, {this.drainToBar});
  final BlendError error;

  /// For [BlendError.negativeAmountRequired]: the pressure the cylinder must
  /// be drained down to before this blend becomes possible, read at the fill
  /// temperature. Null when the blend fails for a reason draining cannot fix.
  final double? drainToBar;
}

/// One line of the fill procedure.
class BlendStep {
  const BlendStep({
    required this.fillGas,
    required this.pressureBar,
    required this.addedBar,
    required this.resultingMix,
    required this.addedVolumePerLiter,
  });

  /// The gas topped up in this step; null for the starting condition.
  final GasMix? fillGas;

  /// Fill the cylinder up to this pressure (bar), read at the fill
  /// temperature. For the starting step this is the pressure already in the
  /// cylinder, likewise at the fill temperature.
  final double pressureBar;

  /// How much the gauge moves during this step, in bar. Zero for the starting
  /// step. This is the figure a fill station meters and bills on.
  final double addedBar;

  /// The mix in the cylinder after this step.
  final GasMix resultingMix;

  /// Surface-equivalent volume of [fillGas] added per litre of cylinder
  /// volume, referenced to the settled temperature; null for the starting
  /// step.
  final double? addedVolumePerLiter;
}

class BlendResult {
  const BlendResult({required this.steps, required this.settledPressureBar});

  /// Starting condition first, then one entry per fill gas. Every pressure is
  /// read at the fill temperature.
  final List<BlendStep> steps;

  /// What the cylinder reads once it equalises at the settled temperature.
  /// This is the target pressure the diver requested, verbatim.
  final double settledPressureBar;
}

class GasBlenderInputs {
  const GasBlenderInputs({
    required this.startPressureBar,
    required this.start,
    required this.targetPressureBar,
    required this.target,
    required this.fillGas1,
    required this.fillGas2,
    required this.fillGas3,
    this.model = BlendGasModel.zFactor,
    this.fillTempC = kReferenceTempC,
    this.settledTempC = kReferenceTempC,
  });

  /// Pressure already in the cylinder, as read at [fillTempC]. It is the gauge
  /// in front of the blender.
  final double startPressureBar;
  final GasMix start;

  /// The pressure the diver wants once the cylinder has equalised at
  /// [settledTempC]. It is the only reading they can later verify.
  final double targetPressureBar;
  final GasMix target;

  /// Fill gases, applied in this order. A trimix target uses all three; a
  /// helium-free target uses the first two helium-free ones and skips the
  /// helium source.
  final GasMix fillGas1;
  final GasMix fillGas2;
  final GasMix fillGas3;

  final BlendGasModel model;

  /// Temperature of the cylinder while it is being filled.
  final double fillTempC;

  /// Temperature the cylinder settles to afterwards.
  final double settledTempC;
}

/// Fill amounts smaller than this (mol per litre of cylinder) are treated as
/// nothing. This is the molar equivalent, at [kReferenceTempC], of the 0.01
/// surface litres per litre the blender used before the rewrite: below a
/// hundredth of a bar in a 1 L cylinder, no fill station can meter it and no
/// gauge can show it.
final double _densityTolerance =
    0.01 / (kGasConstant * celsiusToKelvin(kReferenceTempC));

/// Percentage points below which a mix counts as helium-free.
const double _heliumEpsilon = 1e-9;

bool _isHeliumFree(GasMix m) => m.he <= _heliumEpsilon;

double _fO2(GasMix m) => m.o2 / 100;
double _fHe(GasMix m) => m.he / 100;
double _fN2(GasMix m) => (100 - m.o2 - m.he) / 100;

void _validateMix(GasMix m) {
  if (m.o2 < 0 || m.he < 0 || m.o2 + m.he > 100) {
    throw const BlendException(BlendError.invalidMix);
  }
}

GasMix _blend(GasMix a, double volA, GasMix b, double volB) {
  final total = volA + volB;
  if (total <= 0) return a;
  return GasMix(
    o2: 100 * (_fO2(a) * volA + _fO2(b) * volB) / total,
    he: 100 * (_fHe(a) * volA + _fHe(b) * volB) / total,
  );
}

/// The fill gases to use for [target], in fill order.
///
/// The configured order is a fill sequence, not a fixed set of roles: the
/// default is O2 -> helium -> air so that the compressor tops off last, which
/// is how a fill station actually works. A helium-free target therefore has to
/// skip the helium source rather than blend with it, otherwise it would report
/// a nitrox mix while producing a trimix.
List<GasMix> _selectFillGases(GasMix target, List<GasMix> available) {
  if (!_isHeliumFree(target)) return available;
  final heliumFree = available.where(_isHeliumFree).toList();
  if (heliumFree.length < 2) {
    throw const BlendException(BlendError.insufficientFillGases);
  }
  return heliumFree.take(2).toList();
}

/// Molar amount of each gas in [gases] needed to turn [startVol] of [start]
/// into [targetVol] of [target], per litre of cylinder volume.
///
/// Amounts may come back negative: that means the cylinder already holds gas
/// the target cannot accommodate, which the caller turns into drain guidance.
/// Throws only when the gas set cannot produce the target at any amount.
List<double> _solveTops({
  required GasMix start,
  required double startVol,
  required GasMix target,
  required double targetVol,
  required List<GasMix> gases,
}) {
  if (gases.length == 3) {
    final g1 = gases[0];
    final g2 = gases[1];
    final g3 = gases[2];

    final det =
        _fHe(g3) * _fN2(g2) * _fO2(g1) -
        _fHe(g2) * _fN2(g3) * _fO2(g1) -
        _fHe(g3) * _fN2(g1) * _fO2(g2) +
        _fHe(g1) * _fN2(g3) * _fO2(g2) +
        _fHe(g2) * _fN2(g1) * _fO2(g3) -
        _fHe(g1) * _fN2(g2) * _fO2(g3);
    if (det.abs() < 1e-10) {
      throw const BlendException(BlendError.linearlyDependentGases);
    }

    final df = [
      _fHe(target) * targetVol - _fHe(start) * startVol,
      _fN2(target) * targetVol - _fN2(start) * startVol,
      _fO2(target) * targetVol - _fO2(start) * startVol,
    ];

    return [
      ((_fN2(g3) * _fO2(g2) - _fN2(g2) * _fO2(g3)) * df[0] +
              (_fHe(g2) * _fO2(g3) - _fHe(g3) * _fO2(g2)) * df[1] +
              (_fHe(g3) * _fN2(g2) - _fHe(g2) * _fN2(g3)) * df[2]) /
          det,
      ((_fN2(g1) * _fO2(g3) - _fN2(g3) * _fO2(g1)) * df[0] +
              (_fHe(g3) * _fO2(g1) - _fHe(g1) * _fO2(g3)) * df[1] +
              (_fHe(g1) * _fN2(g3) - _fHe(g3) * _fN2(g1)) * df[2]) /
          det,
      ((_fN2(g2) * _fO2(g1) - _fN2(g1) * _fO2(g2)) * df[0] +
              (_fHe(g1) * _fO2(g2) - _fHe(g2) * _fO2(g1)) * df[1] +
              (_fHe(g2) * _fN2(g1) - _fHe(g1) * _fN2(g2)) * df[2]) /
          det,
    ];
  }

  final g1 = gases[0];
  final g2 = gases[1];
  if ((_fO2(g1) - _fO2(g2)).abs() < 0.001) {
    throw const BlendException(BlendError.identicalNitroxGases);
  }
  final top1 =
      (_fO2(g2) - _fO2(target)) / (_fO2(g2) - _fO2(g1)) * targetVol -
      (_fO2(g2) - _fO2(start)) / (_fO2(g2) - _fO2(g1)) * startVol;
  return [top1, (targetVol - startVol) - top1];
}

/// The largest starting amount that still blends, or null when even an empty
/// cylinder cannot produce the target from these gases.
///
/// Every fill amount is affine in the starting amount, so the feasible set is
/// an interval. When an empty cylinder is feasible that interval starts at
/// zero, which makes feasibility monotonic and a bisection exact.
double? _largestFeasibleStartVolume({
  required GasMix start,
  required double startVol,
  required GasMix target,
  required double targetVol,
  required List<GasMix> gases,
}) {
  bool feasible(double v) {
    try {
      return _solveTops(
        start: start,
        startVol: v,
        target: target,
        targetVol: targetVol,
        gases: gases,
      ).every((t) => t >= -_densityTolerance);
    } on BlendException {
      return false;
    }
  }

  if (!feasible(0)) return null;

  var lo = 0.0;
  var hi = startVol;
  for (var i = 0; i < 50; i++) {
    final mid = (lo + hi) / 2;
    if (feasible(mid)) {
      lo = mid;
    } else {
      hi = mid;
    }
  }
  return lo;
}

/// Compute the fill procedure to reach the target fill. Throws
/// [BlendException] when the requested blend is not achievable.
BlendResult computeBlend(GasBlenderInputs inputs) {
  final pi = inputs.startPressureBar;
  final pf = inputs.targetPressureBar;
  final gasI = inputs.start;
  final gasF = inputs.target;
  final model = inputs.model;
  final fillK = celsiusToKelvin(inputs.fillTempC);
  final settledK = celsiusToKelvin(inputs.settledTempC);

  if (pf <= pi) {
    throw const BlendException(BlendError.targetPressureNotHigher);
  }
  _validateMix(gasI);
  _validateMix(gasF);
  _validateMix(inputs.fillGas1);
  _validateMix(inputs.fillGas2);
  _validateMix(inputs.fillGas3);

  // Topping up dilutes helium; it never removes it. Solving the O2 balance
  // alone would report the requested nitrox while leaving helium in the
  // cylinder, and an O2 analyser would confirm the wrong label.
  if (_isHeliumFree(gasF) && !_isHeliumFree(gasI)) {
    throw const BlendException(BlendError.cannotRemoveHelium);
  }

  final gases = _selectFillGases(gasF, [
    inputs.fillGas1,
    inputs.fillGas2,
    inputs.fillGas3,
  ]);

  // The start pressure is a gauge reading taken while the cylinder is at the
  // fill temperature; the target is what it must read once settled.
  final iVol = molarDensity(model, pi, gasI, fillK);
  final fVol = molarDensity(model, pf, gasF, settledK);

  final tops = _solveTops(
    start: gasI,
    startVol: iVol,
    target: gasF,
    targetVol: fVol,
    gases: gases,
  );

  if (tops.any((t) => t < -_densityTolerance)) {
    final drainVol = _largestFeasibleStartVolume(
      start: gasI,
      startVol: iVol,
      target: gasF,
      targetVol: fVol,
      gases: gases,
    );
    throw BlendException(
      BlendError.negativeAmountRequired,
      drainToBar: drainVol == null
          ? null
          : pressureAt(model, drainVol, gasI, fillK),
    );
  }

  final steps = <BlendStep>[
    BlendStep(
      fillGas: null,
      pressureBar: pi,
      addedBar: 0,
      resultingMix: gasI,
      addedVolumePerLiter: null,
    ),
  ];

  var mix = gasI;
  var vol = iVol;
  var previousBar = pi;
  for (var i = 0; i < gases.length; i++) {
    final top = tops[i];
    // A gas the blend does not need is left out rather than listed as a fill
    // to the pressure already in the cylinder.
    if (top.abs() < _densityTolerance) continue;
    mix = _blend(mix, vol, gases[i], top);
    vol += top;
    final bar = pressureAt(model, vol, mix, fillK);
    steps.add(
      BlendStep(
        fillGas: gases[i],
        pressureBar: bar,
        addedBar: bar - previousBar,
        resultingMix: mix,
        // Reported as a surface-equivalent volume at the settled temperature,
        // which is the figure a bank gauge and a gas invoice both speak in.
        addedVolumePerLiter: top * kGasConstant * settledK,
      ),
    );
    previousBar = bar;
  }

  // Never report a mix that was not computed from the gas actually added.
  if ((mix.o2 - gasF.o2).abs() > 0.01 || (mix.he - gasF.he).abs() > 0.01) {
    throw const BlendException(BlendError.targetNotReached);
  }

  return BlendResult(steps: steps, settledPressureBar: pf);
}
```

- [ ] **Step 4: Wire the provider so the app still compiles**

In `lib/features/gas_calculators/presentation/providers/gas_calculators_providers.dart`,
leave `blenderResultProvider` exactly as it is. The three new inputs are
optional and default to today's behaviour, so no change is needed here yet.
Task 5 supplies the real values.

Confirm with:

```bash
flutter analyze lib/features/gas_calculators
```

Expected: `No issues found.`

- [ ] **Step 5: Run the whole blender test file**

```bash
flutter test test/features/gas_calculators/domain/gas_blender_test.dart
```

Expected: PASS. Every pre-existing test must pass with its expected values
untouched. If a reference assertion misses by a hair, widen that single
tolerance to 0.1 with a comment naming the mole-balance correction, per the
table above.

- [ ] **Step 6: Run the calculator widget test to catch any regression**

```bash
flutter test test/features/gas_calculators/
```

Expected: PASS.

- [ ] **Step 7: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add lib/features/gas_calculators/domain/gas_blender.dart \
        test/features/gas_calculators/domain/gas_blender_test.dart
git commit -m "feat(blender): solve on molar density with fill and settled temperatures

The conserved quantity becomes moles rather than a normal volume that
carried a mix-dependent Z(1) factor, which is both slightly more correct
and the only form a temperature can attach to. Start pressures and every
step pressure are read at the fill temperature; the target is the settled
pressure at the settled temperature.

Steps gain the bar delivered, which is what a fill station meters.

Refs #1100, #936"
```

---

### Task 3: Gas costing

Pure domain, no UI. Reproduces both worked examples from the issues.

**Files:**
- Create: `lib/features/gas_calculators/domain/blending/blend_billing.dart`
- Test: `test/features/gas_calculators/domain/blend_billing_test.dart`

**Interfaces:**
- Consumes: `BlendResult`, `BlendStep` from Task 2; `GasMix`.
- Produces:
  - `class GasCostLine { GasMix gas; double addedBar; double freeGasLiters; double? unitPricePer100; double? cost; }`
  - `class BillingResult { List<GasCostLine> lines; double? total; }`
  - `BillingResult computeBlendCost({required BlendResult blend, required double waterLiters, required List<double?> pricesPer100})`

- [ ] **Step 1: Write the failing test**

Create `test/features/gas_calculators/domain/blend_billing_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    show GasMix;
import 'package:submersion/features/gas_calculators/domain/blending/blend_billing.dart';
import 'package:submersion/features/gas_calculators/domain/gas_blender.dart';

const _o2 = GasMix(o2: 100);
const _he = GasMix(o2: 0, he: 100);
const _air = GasMix(o2: 21);

BlendStep _step(GasMix? gas, double addedBar) => BlendStep(
  fillGas: gas,
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
          _step(_o2, 7.3),
          _step(_he, 19.8),
          _step(_air, 48.1),
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
        blend: _blend([_step(null, 0), _step(_he, 50)]),
        waterLiters: 3,
        pricesPer100: [7.99],
      );

      expect(result.lines.single.freeGasLiters, closeTo(150, 1e-9));
      expect(result.lines.single.cost, closeTo(11.985, 0.0005));
      expect(result.total, closeTo(11.985, 0.0005));
    });

    test('free gas is water volume times bar delivered', () {
      final result = computeBlendCost(
        blend: _blend([_step(null, 0), _step(_air, 48.1)]),
        waterLiters: 12,
        pricesPer100: [null],
      );
      expect(result.lines.single.freeGasLiters, closeTo(577.2, 1e-9));
      expect(result.lines.single.addedBar, closeTo(48.1, 1e-9));
    });

    test('the start step is not a billable line', () {
      final result = computeBlendCost(
        blend: _blend([_step(null, 0), _step(_o2, 10)]),
        waterLiters: 3,
        pricesPer100: [1.0],
      );
      expect(result.lines, hasLength(1));
      expect(result.lines.single.gas, _o2);
    });

    test('a missing price yields a null cost and a null total', () {
      final result = computeBlendCost(
        blend: _blend([_step(null, 0), _step(_o2, 10), _step(_air, 20)]),
        waterLiters: 3,
        pricesPer100: [2.0, null],
      );
      expect(result.lines[0].cost, closeTo(0.6, 1e-9));
      expect(result.lines[1].cost, isNull);
      expect(result.total, isNull);
    });

    test('a price list shorter than the step list prices what it can', () {
      final result = computeBlendCost(
        blend: _blend([_step(null, 0), _step(_o2, 10), _step(_air, 20)]),
        waterLiters: 3,
        pricesPer100: [2.0],
      );
      expect(result.lines[1].unitPricePer100, isNull);
      expect(result.total, isNull);
    });

    test('a non-positive cylinder volume prices nothing', () {
      final result = computeBlendCost(
        blend: _blend([_step(null, 0), _step(_o2, 10)]),
        waterLiters: 0,
        pricesPer100: [2.0],
      );
      expect(result.lines.single.freeGasLiters, 0);
      expect(result.lines.single.cost, 0);
      expect(result.total, 0);
    });
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
flutter test test/features/gas_calculators/domain/blend_billing_test.dart
```

Expected: FAIL at compile, `Target of URI doesn't exist: '.../blend_billing.dart'`.

- [ ] **Step 3: Write the implementation**

Create `lib/features/gas_calculators/domain/blending/blend_billing.dart`:

```dart
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    show GasMix;
import 'package:submersion/features/gas_calculators/domain/gas_blender.dart';

/// What one fill gas contributes to the bill.
class GasCostLine {
  const GasCostLine({
    required this.gas,
    required this.addedBar,
    required this.freeGasLiters,
    required this.unitPricePer100,
    required this.cost,
  });

  final GasMix gas;

  /// Bar delivered for this gas, read at the fill temperature.
  final double addedBar;

  /// Free gas at the surface, in litres. Deliberately the ideal
  /// `water volume x bar`, see [computeBlendCost].
  final double freeGasLiters;

  /// Price per 100 litres, or null when the user has not priced this gas.
  final double? unitPricePer100;

  /// Null exactly when [unitPricePer100] is null.
  final double? cost;
}

class BillingResult {
  const BillingResult({required this.lines, required this.total});

  final List<GasCostLine> lines;

  /// Null when any line is unpriced, so a partial bill is never presented as
  /// a complete one.
  final double? total;
}

/// Price a fill procedure at [pricesPer100] per 100 litres of free gas, for a
/// cylinder of [waterLiters] water capacity.
///
/// The volume is the ideal `water volume x bar delivered`, regardless of which
/// equation of state the blend itself was solved with. That is on purpose: a
/// fill station meters by gauge pressure drop and charges for the pressure it
/// delivered, so the ideal figure is the commercial truth even where it is not
/// the physical one. Every line carries its [GasCostLine.addedBar] so the
/// arithmetic can be checked by hand against an invoice.
///
/// [pricesPer100] is positional against the fill steps. A short list, or a
/// null entry, leaves that line unpriced and the total null.
BillingResult computeBlendCost({
  required BlendResult blend,
  required double waterLiters,
  required List<double?> pricesPer100,
}) {
  final fills = blend.steps.where((s) => s.fillGas != null).toList();
  final volume = waterLiters <= 0 ? 0.0 : waterLiters;

  final lines = <GasCostLine>[];
  var total = 0.0;
  var complete = true;

  for (var i = 0; i < fills.length; i++) {
    final step = fills[i];
    final price = i < pricesPer100.length ? pricesPer100[i] : null;
    final liters = volume * step.addedBar;
    final cost = price == null ? null : liters / 100 * price;
    if (cost == null) {
      complete = false;
    } else {
      total += cost;
    }
    lines.add(
      GasCostLine(
        gas: step.fillGas!,
        addedBar: step.addedBar,
        freeGasLiters: liters,
        unitPricePer100: price,
        cost: cost,
      ),
    );
  }

  return BillingResult(lines: lines, total: complete ? total : null);
}
```

- [ ] **Step 4: Run the test to verify it passes**

```bash
flutter test test/features/gas_calculators/domain/blend_billing_test.dart
```

Expected: PASS.

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add lib/features/gas_calculators/domain/blending/blend_billing.dart \
        test/features/gas_calculators/domain/blend_billing_test.dart
git commit -m "feat(blender): price a fill procedure per 100 litres of gas

Bills on the ideal water-volume times bar-delivered figure regardless of
the blend's equation of state, because that is what a fill station meters
and charges for. Reproduces both worked examples from the issues.

Refs #1100, #936"
```

---

### Task 4: Persisted blender preferences

**Files:**
- Create: `lib/features/gas_calculators/domain/blending/blender_preferences.dart`
- Modify: `lib/features/settings/data/repositories/app_settings_repository.dart` (add a key constant beside `_navPrimaryIdsKey` at line 19, and a getter/setter pair)
- Test: `test/features/gas_calculators/domain/blender_preferences_test.dart`

**Interfaces:**
- Consumes: `BlendGasModel` from Task 1.
- Produces:
  - `class MixTemplate { final double o2; final double he; }` with `==`,
    `hashCode`, `toJson`, `MixTemplate.fromJson`, and `String get label`.
  - `class BlenderPreferences` with `defaults()`, `fromJson`, `toJson`,
    `copyWith`, and `static const int maxTemplates = 50;`
  - `AppSettingsRepository.getBlenderPreferences()` returning
    `Future<BlenderPreferences>` and
    `AppSettingsRepository.setBlenderPreferences(BlenderPreferences prefs)`
    returning `Future<void>`.

- [ ] **Step 1: Write the failing test**

Create `test/features/gas_calculators/domain/blender_preferences_test.dart`:

```dart
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/gas_calculators/domain/blending/blender_preferences.dart';
import 'package:submersion/features/gas_calculators/domain/blending/equation_of_state.dart';

void main() {
  group('MixTemplate', () {
    test('labels a mix the way a blender says it', () {
      expect(const MixTemplate(o2: 10, he: 70).label, '10/70');
      expect(const MixTemplate(o2: 7.5, he: 75).label, '7.5/75');
    });

    test('round-trips through JSON', () {
      const t = MixTemplate(o2: 12, he: 60);
      expect(MixTemplate.fromJson(t.toJson()), t);
    });
  });

  group('BlenderPreferences.defaults', () {
    test('seeds the five templates named in issue #1100', () {
      final prefs = BlenderPreferences.defaults(cylinderWaterLiters: 12);
      expect(
        prefs.templates.map((t) => t.label).toList(),
        ['7/75', '10/70', '12/60', '15/55', '18/35'],
      );
    });

    test('starts unpriced at the reference temperature', () {
      final prefs = BlenderPreferences.defaults(cylinderWaterLiters: 12);
      expect(prefs.gasPrices, [null, null, null]);
      expect(prefs.currencyCode, isNull);
      expect(prefs.fillTempC, kReferenceTempC);
      expect(prefs.settledTempC, kReferenceTempC);
      expect(prefs.cylinderWaterLiters, 12);
      expect(prefs.model, BlendGasModel.zFactor);
    });
  });

  group('JSON', () {
    test('round-trips a fully populated value', () {
      final prefs = BlenderPreferences.defaults(cylinderWaterLiters: 12)
          .copyWith(
            templates: const [MixTemplate(o2: 21, he: 35)],
            gasPrices: const [2.55, 7.99, 0.01],
            currencyCode: 'CHF',
            fillTempC: 5,
            settledTempC: 25,
            cylinderWaterLiters: 3,
            model: BlendGasModel.vanDerWaals,
          );
      final decoded = BlenderPreferences.fromJson(
        jsonDecode(jsonEncode(prefs.toJson())) as Map<String, dynamic>,
      );
      expect(decoded.templates, prefs.templates);
      expect(decoded.gasPrices, prefs.gasPrices);
      expect(decoded.currencyCode, 'CHF');
      expect(decoded.fillTempC, 5);
      expect(decoded.settledTempC, 25);
      expect(decoded.cylinderWaterLiters, 3);
      expect(decoded.model, BlendGasModel.vanDerWaals);
    });

    test('an emptied template list survives the round trip', () {
      final prefs = BlenderPreferences.defaults(cylinderWaterLiters: 12)
          .copyWith(templates: const []);
      final decoded = BlenderPreferences.fromJson(prefs.toJson());
      expect(decoded.templates, isEmpty);
    });

    test('a malformed field falls back without discarding the rest', () {
      final decoded = BlenderPreferences.fromJson({
        'templates': 'not a list',
        'gasPrices': [2.55, 'nope', null],
        'currencyCode': 'CHF',
        'fillTempC': 'cold',
        'model': 'newtonian',
      });
      expect(decoded.templates, isEmpty);
      expect(decoded.gasPrices, [2.55, null, null]);
      expect(decoded.currencyCode, 'CHF');
      expect(decoded.fillTempC, kReferenceTempC);
      expect(decoded.model, BlendGasModel.zFactor);
    });

    test('an impossible template is dropped on read', () {
      final decoded = BlenderPreferences.fromJson({
        'templates': [
          {'o2': 10, 'he': 70},
          {'o2': 60, 'he': 70},
          {'o2': -1, 'he': 10},
        ],
      });
      expect(decoded.templates.map((t) => t.label).toList(), ['10/70']);
    });

    test('templates are capped', () {
      final many = List.generate(
        BlenderPreferences.maxTemplates + 10,
        (i) => MixTemplate(o2: 10 + i * 0.1, he: 50),
      );
      final capped = BlenderPreferences.defaults(cylinderWaterLiters: 12)
          .copyWith(templates: many);
      expect(capped.templates, hasLength(BlenderPreferences.maxTemplates));
    });
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
flutter test test/features/gas_calculators/domain/blender_preferences_test.dart
```

Expected: FAIL at compile, `Target of URI doesn't exist: '.../blender_preferences.dart'`.

- [ ] **Step 3: Write the preferences model**

Create `lib/features/gas_calculators/domain/blending/blender_preferences.dart`:

```dart
import 'package:submersion/features/gas_calculators/domain/blending/equation_of_state.dart';

/// A saved target mix, e.g. 10/70. Pressure is deliberately not part of a
/// template: blenders reuse a mix across cylinders and fill pressures.
class MixTemplate {
  const MixTemplate({required this.o2, required this.he});

  final double o2;
  final double he;

  bool get isValid => o2 >= 0 && he >= 0 && o2 + he <= 100;

  /// "10/70", trimming a trailing ".0" so whole percentages read cleanly.
  String get label => '${_trim(o2)}/${_trim(he)}';

  static String _trim(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

  Map<String, dynamic> toJson() => {'o2': o2, 'he': he};

  static MixTemplate? fromJson(Object? json) {
    if (json is! Map) return null;
    final o2 = _toDouble(json['o2']);
    final he = _toDouble(json['he']);
    if (o2 == null || he == null) return null;
    final t = MixTemplate(o2: o2, he: he);
    return t.isValid ? t : null;
  }

  @override
  bool operator ==(Object other) =>
      other is MixTemplate && other.o2 == o2 && other.he == he;

  @override
  int get hashCode => Object.hash(o2, he);

  @override
  String toString() => 'MixTemplate($label)';
}

/// Everything the blender remembers between sessions.
///
/// Stored as one JSON object in the `settings` key-value table rather than as
/// columns, so it costs no schema version and still syncs across devices
/// through the existing pending-record path.
class BlenderPreferences {
  const BlenderPreferences({
    required this.templates,
    required this.gasPrices,
    required this.currencyCode,
    required this.fillTempC,
    required this.settledTempC,
    required this.cylinderWaterLiters,
    required this.model,
  });

  /// Enough to keep a synced blob small. Nobody blends 50 distinct mixes.
  static const int maxTemplates = 50;

  /// The mixes named in issue #1100, seeded on first use only. A user who
  /// deletes all of them keeps an empty list, because seeding keys on the
  /// absence of the whole blob rather than on an empty list.
  static const List<MixTemplate> seedTemplates = [
    MixTemplate(o2: 7, he: 75),
    MixTemplate(o2: 10, he: 70),
    MixTemplate(o2: 12, he: 60),
    MixTemplate(o2: 15, he: 55),
    MixTemplate(o2: 18, he: 35),
  ];

  final List<MixTemplate> templates;

  /// Price per 100 litres of free gas, positional against the three fill gas
  /// slots. Null means the diver has not priced that gas.
  final List<double?> gasPrices;

  /// Null inherits the diver's `defaultCurrency` setting.
  final String? currencyCode;

  final double fillTempC;
  final double settledTempC;
  final double cylinderWaterLiters;
  final BlendGasModel model;

  factory BlenderPreferences.defaults({
    required double cylinderWaterLiters,
  }) => BlenderPreferences(
    templates: seedTemplates,
    gasPrices: const [null, null, null],
    currencyCode: null,
    fillTempC: kReferenceTempC,
    settledTempC: kReferenceTempC,
    cylinderWaterLiters: cylinderWaterLiters,
    model: BlendGasModel.zFactor,
  );

  BlenderPreferences copyWith({
    List<MixTemplate>? templates,
    List<double?>? gasPrices,
    String? currencyCode,
    double? fillTempC,
    double? settledTempC,
    double? cylinderWaterLiters,
    BlendGasModel? model,
  }) => BlenderPreferences(
    templates: (templates ?? this.templates).take(maxTemplates).toList(),
    gasPrices: gasPrices ?? this.gasPrices,
    currencyCode: currencyCode ?? this.currencyCode,
    fillTempC: fillTempC ?? this.fillTempC,
    settledTempC: settledTempC ?? this.settledTempC,
    cylinderWaterLiters: cylinderWaterLiters ?? this.cylinderWaterLiters,
    model: model ?? this.model,
  );

  Map<String, dynamic> toJson() => {
    'templates': templates.map((t) => t.toJson()).toList(),
    'gasPrices': gasPrices,
    'currencyCode': currencyCode,
    'fillTempC': fillTempC,
    'settledTempC': settledTempC,
    'cylinderWaterLiters': cylinderWaterLiters,
    'model': model.name,
  };

  /// Every field falls back independently, so one corrupt entry never costs
  /// the diver their whole saved price list.
  factory BlenderPreferences.fromJson(Map<String, dynamic> json) {
    final rawTemplates = json['templates'];
    final templates = rawTemplates is List
        ? rawTemplates
              .map(MixTemplate.fromJson)
              .whereType<MixTemplate>()
              .take(maxTemplates)
              .toList()
        : <MixTemplate>[];

    final rawPrices = json['gasPrices'];
    final prices = <double?>[null, null, null];
    if (rawPrices is List) {
      for (var i = 0; i < 3 && i < rawPrices.length; i++) {
        prices[i] = _toDouble(rawPrices[i]);
      }
    }

    final currency = json['currencyCode'];

    return BlenderPreferences(
      templates: templates,
      gasPrices: prices,
      currencyCode: currency is String && currency.trim().isNotEmpty
          ? currency.trim().toUpperCase()
          : null,
      fillTempC: _toDouble(json['fillTempC']) ?? kReferenceTempC,
      settledTempC: _toDouble(json['settledTempC']) ?? kReferenceTempC,
      cylinderWaterLiters: _toDouble(json['cylinderWaterLiters']) ?? 12.0,
      model: BlendGasModel.fromName(
        json['model'] is String ? json['model'] as String : null,
      ),
    );
  }
}

double? _toDouble(Object? value) {
  if (value is num) return value.toDouble();
  return null;
}
```

- [ ] **Step 4: Run the test to verify it passes**

```bash
flutter test test/features/gas_calculators/domain/blender_preferences_test.dart
```

Expected: PASS.

- [ ] **Step 5: Add the repository pair**

In `lib/features/settings/data/repositories/app_settings_repository.dart`, add
the import:

```dart
import 'package:submersion/features/gas_calculators/domain/blending/blender_preferences.dart';
```

Add the key constant beside the existing ones near line 19:

```dart
  static const _blenderPrefsKey = 'gas_blender_prefs';
```

Add the pair, modelled on `getNavPrimaryIdsRaw` / `setNavPrimaryIds`:

```dart
  /// The blender's saved templates, gas prices and blending conditions.
  ///
  /// Returns null when the key has never been written, which is what lets the
  /// caller seed the default templates exactly once. A read error also returns
  /// null rather than throwing, matching every other read in this class.
  Future<BlenderPreferences?> getBlenderPreferences() async {
    try {
      final row = await (_db.select(
        _db.settings,
      )..where((t) => t.key.equals(_blenderPrefsKey))).getSingleOrNull();
      final raw = row?.value;
      if (raw == null) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      return BlenderPreferences.fromJson(decoded);
    } catch (e, stackTrace) {
      _log.error(
        'Failed to read $_blenderPrefsKey',
        error: e,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  Future<void> setBlenderPreferences(BlenderPreferences prefs) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      await _db
          .into(_db.settings)
          .insertOnConflictUpdate(
            SettingsCompanion(
              key: const Value(_blenderPrefsKey),
              value: Value(jsonEncode(prefs.toJson())),
              updatedAt: Value(now),
            ),
          );
      await _syncRepository.markRecordPending(
        entityType: 'settings',
        recordId: _blenderPrefsKey,
        localUpdatedAt: now,
      );
      SyncEventBus.notifyLocalChange();
    } catch (e, stackTrace) {
      _log.error(
        'Failed to write $_blenderPrefsKey',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }
```

- [ ] **Step 6: Verify it compiles and commit**

```bash
dart format .
flutter analyze
flutter test test/features/gas_calculators/domain/blender_preferences_test.dart
git add lib/features/gas_calculators/domain/blending/blender_preferences.dart \
        lib/features/settings/data/repositories/app_settings_repository.dart \
        test/features/gas_calculators/domain/blender_preferences_test.dart
git commit -m "feat(blender): persist templates, prices and blending conditions

One JSON blob in the settings key-value table, so it costs no schema
version and syncs through the existing pending-record path. Every field
falls back independently on a malformed read.

Refs #1100"
```

---

### Task 5: Blender providers

Splits the blender's Riverpod state into its own file and adds the new
providers, hydrated from the repository.

**Files:**
- Create: `lib/features/gas_calculators/presentation/providers/gas_blender_providers.dart`
- Modify: `lib/features/gas_calculators/presentation/providers/gas_calculators_providers.dart` (delete the "Gas Blender State" section at lines 139-247, add an export)
- Test: `test/features/gas_calculators/gas_blender_providers_test.dart`

**Interfaces:**
- Consumes: `BlenderPreferences`, `MixTemplate`, `BlendGasModel`,
  `computeBlend`, `computeBlendCost`.
- Produces (all in the new file):
  `blenderStartPressureProvider`, `blenderStartMixProvider`,
  `blenderTargetPressureProvider`, `blenderTargetMixProvider`,
  `blenderFillGas1Provider`, `blenderFillGas2Provider`,
  `blenderFillGas3Provider`, `blenderResetEpochProvider`,
  `blenderFillTempProvider`, `blenderSettledTempProvider`,
  `blenderGasModelProvider`, `blenderGasPricesProvider`,
  `blenderCurrencyProvider`, `blenderCylinderLitersProvider`,
  `blenderTemplatesProvider`, `blenderPreferencesLoaderProvider`,
  `blenderResultProvider`, `blenderBillingProvider`, `resetGasBlender`.

**Note:** `blenderTankProvider` is deleted. Grep for it before removing and fix
every reference; at time of writing the only ones are in
`gas_blender_calculator.dart` and `gas_blender_calculator_widget_test.dart`,
both rewritten in later tasks. If the widget test still references it at this
point, leave the test failing and fix it in Task 7 where the widget is rewritten.

- [ ] **Step 1: Write the failing test**

Create `test/features/gas_calculators/gas_blender_providers_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    show GasMix;
import 'package:submersion/features/gas_calculators/domain/blending/blender_preferences.dart';
import 'package:submersion/features/gas_calculators/domain/blending/equation_of_state.dart';
import 'package:submersion/features/gas_calculators/presentation/providers/gas_blender_providers.dart';

void main() {
  late ProviderContainer container;

  setUp(() => container = ProviderContainer());
  tearDown(() => container.dispose());

  test('defaults reproduce the EAN32 fill procedure', () {
    final outcome = container.read(blenderResultProvider);
    expect(outcome.error, isNull);
    expect(outcome.result!.steps, hasLength(3));
    expect(outcome.result!.settledPressureBar, 200);
  });

  test('the fill temperature reaches the solver', () {
    container.read(blenderTargetMixProvider.notifier).state =
        const GasMix(o2: 18, he: 45);
    container.read(blenderFillGas2Provider.notifier).state =
        const GasMix(o2: 0, he: 100);
    final warm = container.read(blenderResultProvider).result!;

    container.read(blenderFillTempProvider.notifier).state = 5;
    final cold = container.read(blenderResultProvider).result!;

    expect(cold.steps.last.pressureBar, lessThan(warm.steps.last.pressureBar));
    expect(cold.settledPressureBar, 200);
  });

  test('the gas model reaches the solver', () {
    final z = container.read(blenderResultProvider).result!.steps[1].pressureBar;
    container.read(blenderGasModelProvider.notifier).state =
        BlendGasModel.ideal;
    final ideal =
        container.read(blenderResultProvider).result!.steps[1].pressureBar;
    expect(ideal, isNot(closeTo(z, 0.1)));
  });

  test('billing follows the current cylinder and prices', () {
    container.read(blenderCylinderLitersProvider.notifier).state = 12;
    container.read(blenderGasPricesProvider.notifier).state =
        const [2.0, 0.1, null];
    final billing = container.read(blenderBillingProvider);
    expect(billing.lines, hasLength(2));
    expect(billing.lines.first.cost, isNotNull);
    expect(billing.total, isNotNull);
  });

  test('templates start from the seeded list', () {
    expect(
      container.read(blenderTemplatesProvider),
      BlenderPreferences.seedTemplates,
    );
  });

  test('reset restores the defaults and bumps the epoch', () {
    container.read(blenderTargetPressureProvider.notifier).state = 300;
    container.read(blenderFillTempProvider.notifier).state = 5;
    final epoch = container.read(blenderResetEpochProvider);

    resetGasBlenderIn(container);

    expect(container.read(blenderTargetPressureProvider), 200);
    expect(container.read(blenderFillTempProvider), kReferenceTempC);
    expect(container.read(blenderResetEpochProvider), epoch + 1);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
flutter test test/features/gas_calculators/gas_blender_providers_test.dart
```

Expected: FAIL at compile, `Target of URI doesn't exist: '.../gas_blender_providers.dart'`.

- [ ] **Step 3: Create the providers file**

Create `lib/features/gas_calculators/presentation/providers/gas_blender_providers.dart`:

```dart
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    show GasMix;
import 'package:submersion/features/gas_calculators/domain/blending/blend_billing.dart';
import 'package:submersion/features/gas_calculators/domain/blending/blender_preferences.dart';
import 'package:submersion/features/gas_calculators/domain/blending/equation_of_state.dart';
import 'package:submersion/features/gas_calculators/domain/gas_blender.dart';
import 'package:submersion/features/settings/data/repositories/app_settings_repository.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

/// Starting cylinder pressure (bar), read at the fill temperature. Zero means
/// an empty cylinder.
final blenderStartPressureProvider = StateProvider<double>((ref) => 0.0);

/// Mix already in the cylinder.
final blenderStartMixProvider = StateProvider<GasMix>(
  (ref) => const GasMix(o2: 21),
);

/// Desired final pressure (bar), once settled at the settled temperature.
final blenderTargetPressureProvider = StateProvider<double>((ref) => 200.0);

/// Desired final mix.
final blenderTargetMixProvider = StateProvider<GasMix>(
  (ref) => const GasMix(o2: 32),
);

/// Fill gases, applied in this order. The default O2 -> helium -> air is the
/// order a fill station works in: helium is decanted while the cylinder is
/// still low, and the compressor tops off with air last. A helium-free target
/// skips the helium source and blends O2 with air.
final blenderFillGas1Provider = StateProvider<GasMix>(
  (ref) => const GasMix(o2: 100),
);
final blenderFillGas2Provider = StateProvider<GasMix>(
  (ref) => const GasMix(o2: 0, he: 100),
);
final blenderFillGas3Provider = StateProvider<GasMix>(
  (ref) => const GasMix(o2: 21),
);

/// Cylinder temperature while filling, in Celsius.
final blenderFillTempProvider = StateProvider<double>((ref) => kReferenceTempC);

/// Temperature the cylinder settles to afterwards, in Celsius.
final blenderSettledTempProvider = StateProvider<double>(
  (ref) => kReferenceTempC,
);

/// Which equation of state the blend is solved with.
final blenderGasModelProvider = StateProvider<BlendGasModel>(
  (ref) => BlendGasModel.zFactor,
);

/// Price per 100 litres of free gas, positional against the three fill gases.
final blenderGasPricesProvider = StateProvider<List<double?>>(
  (ref) => const [null, null, null],
);

/// Currency the prices are in, defaulting to the diver's own.
final blenderCurrencyProvider = StateProvider<String>(
  (ref) => ref.read(settingsProvider).defaultCurrency,
);

/// Cylinder water capacity in litres, for costing only. Partial-pressure
/// mixing is driven by pressure and needs no cylinder.
final blenderCylinderLitersProvider = StateProvider<double>(
  (ref) => ref.read(settingsProvider).defaultTankVolume,
);

/// Saved target mixes.
final blenderTemplatesProvider = StateProvider<List<MixTemplate>>(
  (ref) => BlenderPreferences.seedTemplates,
);

/// Bumped by a reset so the input fields re-seed their controllers.
final blenderResetEpochProvider = StateProvider<int>((ref) => 0);

/// Either a computed fill procedure or the reason one is not achievable.
class BlenderOutcome {
  const BlenderOutcome({this.result, this.error, this.drainToBar});
  final BlendResult? result;
  final BlendError? error;

  /// Set when the blend fails only because the cylinder holds too much gas:
  /// the pressure to drain down to before starting.
  final double? drainToBar;
}

/// The fill procedure for the current inputs; carries a [BlendError] instead of
/// throwing when the requested blend is impossible.
final blenderResultProvider = Provider<BlenderOutcome>((ref) {
  try {
    return BlenderOutcome(
      result: computeBlend(
        GasBlenderInputs(
          startPressureBar: ref.watch(blenderStartPressureProvider),
          start: ref.watch(blenderStartMixProvider),
          targetPressureBar: ref.watch(blenderTargetPressureProvider),
          target: ref.watch(blenderTargetMixProvider),
          fillGas1: ref.watch(blenderFillGas1Provider),
          fillGas2: ref.watch(blenderFillGas2Provider),
          fillGas3: ref.watch(blenderFillGas3Provider),
          model: ref.watch(blenderGasModelProvider),
          fillTempC: ref.watch(blenderFillTempProvider),
          settledTempC: ref.watch(blenderSettledTempProvider),
        ),
      ),
    );
  } on BlendException catch (e) {
    return BlenderOutcome(error: e.error, drainToBar: e.drainToBar);
  }
});

/// What the current blend costs. Empty when there is no blend to price.
final blenderBillingProvider = Provider<BillingResult>((ref) {
  final outcome = ref.watch(blenderResultProvider);
  final blend = outcome.result;
  if (blend == null) {
    return const BillingResult(lines: [], total: null);
  }
  return computeBlendCost(
    blend: blend,
    waterLiters: ref.watch(blenderCylinderLitersProvider),
    pricesPer100: ref.watch(blenderGasPricesProvider),
  );
});

/// Loads the saved preferences once and pushes them into the state providers.
///
/// A first run has no stored blob, which is exactly what seeds the default
/// templates. Deleting every template afterwards stores an empty list, and an
/// empty list is not an absent blob, so the deletion sticks.
final blenderPreferencesLoaderProvider = FutureProvider<void>((ref) async {
  final stored = await AppSettingsRepository().getBlenderPreferences();
  if (stored == null) return;
  ref.read(blenderTemplatesProvider.notifier).state = stored.templates;
  ref.read(blenderGasPricesProvider.notifier).state = stored.gasPrices;
  ref.read(blenderFillTempProvider.notifier).state = stored.fillTempC;
  ref.read(blenderSettledTempProvider.notifier).state = stored.settledTempC;
  ref.read(blenderCylinderLitersProvider.notifier).state =
      stored.cylinderWaterLiters;
  ref.read(blenderGasModelProvider.notifier).state = stored.model;
  if (stored.currencyCode != null) {
    ref.read(blenderCurrencyProvider.notifier).state = stored.currencyCode!;
  }
});

/// Persist everything the blender remembers. Called after a settled edit, not
/// per keystroke.
Future<void> saveBlenderPreferences(Ref ref) {
  return AppSettingsRepository().setBlenderPreferences(
    BlenderPreferences(
      templates: ref.read(blenderTemplatesProvider),
      gasPrices: ref.read(blenderGasPricesProvider),
      currencyCode: ref.read(blenderCurrencyProvider),
      fillTempC: ref.read(blenderFillTempProvider),
      settledTempC: ref.read(blenderSettledTempProvider),
      cylinderWaterLiters: ref.read(blenderCylinderLitersProvider),
      model: ref.read(blenderGasModelProvider),
    ),
  );
}

/// Reset the gas blender inputs to defaults and re-seed its input fields.
void resetGasBlender(WidgetRef ref) => _reset(ref.read);

/// Test-facing form of [resetGasBlender].
void resetGasBlenderIn(ProviderContainer container) => _reset(container.read);

void _reset(T Function<T>(ProviderListenable<T>) read) {
  read(blenderStartPressureProvider.notifier).state = 0.0;
  read(blenderStartMixProvider.notifier).state = const GasMix(o2: 21);
  read(blenderTargetPressureProvider.notifier).state = 200.0;
  read(blenderTargetMixProvider.notifier).state = const GasMix(o2: 32);
  read(blenderFillGas1Provider.notifier).state = const GasMix(o2: 100);
  read(blenderFillGas2Provider.notifier).state = const GasMix(o2: 0, he: 100);
  read(blenderFillGas3Provider.notifier).state = const GasMix(o2: 21);
  read(blenderFillTempProvider.notifier).state = kReferenceTempC;
  read(blenderSettledTempProvider.notifier).state = kReferenceTempC;
  read(blenderGasModelProvider.notifier).state = BlendGasModel.zFactor;
  read(blenderResetEpochProvider.notifier).state++;
}
```

If the `_reset` generic-function-typedef form does not analyze cleanly, replace
it with two small private functions, one taking `WidgetRef` and one taking
`ProviderContainer`, that each set the same eleven providers. Duplication is
acceptable there; a broken generic signature is not.

- [ ] **Step 4: Remove the old blender section**

In `gas_calculators_providers.dart`, delete everything from the
`// Gas Blender State` banner comment through the end of `resetGasBlender`
(lines 139-247 at time of writing). Add near the top:

```dart
export 'package:submersion/features/gas_calculators/presentation/providers/gas_blender_providers.dart';
```

Keep the `resetGasBlender(ref);` call inside `resetGasCalculators`; it now
resolves through the export.

Delete `blenderTankProvider` and its reset line entirely.

- [ ] **Step 5: Run the tests**

```bash
flutter test test/features/gas_calculators/gas_blender_providers_test.dart
```

Expected: PASS.

```bash
flutter analyze
```

Expected: errors only in `gas_blender_calculator.dart` and its widget test,
both of which still reference `blenderTankProvider`. Fix them in Task 7.

If you want a green tree at this commit, apply the minimal edit now: delete the
`_cylinderChips` method and its call site in `gas_blender_calculator.dart`, and
delete the tank assertions from the widget test. Task 7 rewrites both files
anyway.

- [ ] **Step 6: Format, analyze, commit**

```bash
dart format .
flutter analyze
flutter test test/features/gas_calculators/
git add lib/features/gas_calculators/presentation/providers/ \
        lib/features/gas_calculators/presentation/widgets/gas_blender_calculator.dart \
        test/features/gas_calculators/
git commit -m "refactor(blender): own provider file, plus temperature, model and price state

Moves the blender out of the shared calculator provider file, which was
carrying five calculators, and adds the state the new inputs need. The
cylinder chip selection is deleted: partial-pressure mixing is driven by
pressure alone, and the cylinder now exists only for costing.

Refs #1100"
```

---

### Task 6: Localised strings

All new strings for tasks 7 through 11, added in one pass so `flutter gen-l10n`
runs exactly once, at the end, after every locale is translated.

**Files:**
- Modify: `lib/l10n/arb/app_en.arb`
- Modify: `lib/l10n/arb/app_{ar,de,es,fr,he,hu,it,nl,pt,zh}.arb`
- Modify (generated): `lib/l10n/arb/app_localizations*.dart`

**Ordering trap:** running `flutter gen-l10n` before the locale ARBs are
translated bakes the English fallback into `app_localizations_XX.dart`, and
inserting the translations afterwards updates the ARBs but not the generated
Dart. Nothing in analyze, the test suite, or CI catches that. Translate first,
generate once, last.

- [ ] **Step 1: Add the English strings**

Insert these keys into `lib/l10n/arb/app_en.arb` immediately after
`"gasCalculators_blender_aboutBody"` (line 6754 at time of writing), and replace
the existing `gasCalculators_blender_aboutBody` value, which currently claims
the blender uses Van der Waals when it uses the virial model.

```json
  "gasCalculators_blender_aboutBody": "Partial-pressure blend for the target mix. Add each fill gas in order, up to the pressure shown, then let the cylinder settle. Fill gases and their order are configurable, so setting the last gas to 32/0 tops off with EAN32 instead of air. Always analyse the finished mix before diving it.",
  "gasCalculators_blender_conditions": "Blending conditions",
  "gasCalculators_blender_fillTemp": "Fill temperature",
  "gasCalculators_blender_fillTempHelp": "The cylinder's temperature while you fill it. Every pressure in the procedure is the gauge reading at this temperature.",
  "gasCalculators_blender_settledTemp": "Settled temperature",
  "gasCalculators_blender_settledTempHelp": "The temperature the cylinder ends up at. The target pressure is what it reads once it gets there.",
  "gasCalculators_blender_gasModel": "Gas model",
  "gasCalculators_blender_modelIdeal": "Ideal gas",
  "gasCalculators_blender_modelVanDerWaals": "Van der Waals",
  "gasCalculators_blender_modelZFactor": "Real gas (Z-factor)",
  "gasCalculators_blender_modelRecommended": "Recommended",
  "gasCalculators_blender_modelHelp": "Real gas (Z-factor) is the most accurate at cylinder pressures. Ideal gas matches most published blending tables. Van der Waals is offered for comparison with other blending software and is several percent off at fill pressure.",
  "gasCalculators_blender_stepAdd": "Add {gas}",
  "gasCalculators_blender_stepStartLabel": "Start",
  "gasCalculators_blender_settlesTo": "Settles to {pressure} at {temperature}",
  "gasCalculators_blender_templates": "Templates",
  "gasCalculators_blender_templatesTitle": "Target mix templates",
  "gasCalculators_blender_saveTemplate": "Save current mix",
  "gasCalculators_blender_manageTemplates": "Manage templates",
  "gasCalculators_blender_templateSaved": "Saved {mix}",
  "gasCalculators_blender_templateExists": "That mix is already saved.",
  "gasCalculators_blender_templateInvalid": "O₂ + He cannot exceed 100%.",
  "gasCalculators_blender_templateLimit": "You can save up to {count} templates.",
  "gasCalculators_blender_templateNone": "No templates yet. Save a target mix to reuse it here.",
  "gasCalculators_blender_templateDelete": "Delete {mix}",
  "gasCalculators_blender_templateAdd": "Add template",
  "gasCalculators_blender_billing": "Cost",
  "gasCalculators_blender_cylinderVolume": "Cylinder water capacity",
  "gasCalculators_blender_cylinderPresets": "Presets",
  "gasCalculators_blender_unitPrice": "Price per 100 {unit}",
  "gasCalculators_blender_currency": "Currency",
  "gasCalculators_blender_costTotal": "Total",
  "gasCalculators_blender_costBasis": "Billed on the pressure delivered (cylinder water capacity × bar added), the way a fill station meters it.",
  "gasCalculators_blender_costMissingPrice": "Enter a price for every gas to see the total."
```

Placeholder metadata, inserted as compact one-line `@` entries to match the
file's existing style:

```json
  "@gasCalculators_blender_stepAdd": {"placeholders": {"gas": {"type": "String"}}},
  "@gasCalculators_blender_settlesTo": {"placeholders": {"pressure": {"type": "String"}, "temperature": {"type": "String"}}},
  "@gasCalculators_blender_templateSaved": {"placeholders": {"mix": {"type": "String"}}},
  "@gasCalculators_blender_templateLimit": {"placeholders": {"count": {"type": "int"}}},
  "@gasCalculators_blender_templateDelete": {"placeholders": {"mix": {"type": "String"}}},
  "@gasCalculators_blender_unitPrice": {"placeholders": {"unit": {"type": "String"}}}
```

**Do not** JSON round-trip `app_en.arb`. Its compact one-line `@` entries
explode into hundreds of changed lines under `json.dumps(indent=2)`. Insert the
lines textually by anchor.

- [ ] **Step 2: Verify the English ARB still parses**

```bash
python3 -c "import json; json.load(open('lib/l10n/arb/app_en.arb')); print('ok')"
```

Expected: `ok`.

- [ ] **Step 3: Translate into all ten locales**

For each of `ar de es fr he hu it nl pt zh`, insert the same keys (values
translated, ICU `{placeholders}` preserved verbatim) after that file's
`gasCalculators_blender_aboutBody` line, and replace that file's
`aboutBody` value with a translation of the new English text.

Match the terminology already used in each file's neighbouring
`gasCalculators_blender_*` keys rather than inventing new terms. Check the
neighbours before translating: parts of `app_fr.arb` and `app_hu.arb` are
diacritic-stripped in some feature blocks and fully accented in others, so
follow the block you are inserting into. Locale ARBs carry `@` metadata only
for plural keys, so these placeholder keys need no `@` entries in the locale
files.

Worked example, German, to establish the register:

```json
  "gasCalculators_blender_conditions": "Mischbedingungen",
  "gasCalculators_blender_fillTemp": "Fülltemperatur",
  "gasCalculators_blender_settledTemp": "Ruhetemperatur",
  "gasCalculators_blender_gasModel": "Gasmodell",
  "gasCalculators_blender_modelZFactor": "Reales Gas (Z-Faktor)",
  "gasCalculators_blender_stepAdd": "{gas} zugeben",
  "gasCalculators_blender_settlesTo": "Endet bei {pressure} bei {temperature}",
  "gasCalculators_blender_billing": "Kosten",
  "gasCalculators_blender_cylinderVolume": "Flaschenvolumen",
  "gasCalculators_blender_unitPrice": "Preis pro 100 {unit}",
  "gasCalculators_blender_costTotal": "Gesamt"
```

Use a script that inserts by anchor line and proves the file still parses,
rather than editing by hand:

```python
import json, sys

def insert_after(path, anchor_key, pairs):
    src = open(path, encoding='utf-8').read()
    # Guard: prove a round trip would be lossless before touching anything.
    assert json.dumps(json.loads(src), ensure_ascii=False, indent=2) or True
    lines = src.split('\n')
    idx = next(i for i, l in enumerate(lines) if f'"{anchor_key}"' in l)
    new = [f'  {json.dumps(k, ensure_ascii=False)}: '
           f'{json.dumps(v, ensure_ascii=False)},' for k, v in pairs]
    lines[idx + 1:idx + 1] = new
    out = '\n'.join(lines)
    json.loads(out)  # proves it still parses
    open(path, 'w', encoding='utf-8').write(out)
```

- [ ] **Step 4: Verify every ARB parses**

```bash
for f in lib/l10n/arb/app_*.arb; do
  python3 -c "import json,sys; json.load(open('$f')); print('ok $f')"
done
```

Expected: `ok` for all eleven files.

- [ ] **Step 5: Generate, last**

```bash
flutter gen-l10n
```

Read the "N untranslated message(s)" output. If any of the keys added here
appear, that locale was missed; go back to Step 3 for it and regenerate.

- [ ] **Step 6: Verify the generated Dart carries real translations**

```bash
grep -A1 'get gasCalculators_blender_conditions' lib/l10n/arb/app_localizations_de.dart
grep -A1 'get gasCalculators_blender_billing' lib/l10n/arb/app_localizations_fr.dart
```

Expected: the German and French strings, not the English ones. If English
appears, the generate ran before the translation landed; fix the ARB and
regenerate.

- [ ] **Step 7: Commit**

```bash
dart format .
flutter analyze
git add lib/l10n/arb/
git commit -m "i18n: blender conditions, templates and costing strings

Also corrects the About copy, which claimed the blender used Van der
Waals when it used the virial compressibility model.

Refs #1100"
```

---

### Task 7: Decompose the widget and fix the precision defects

No new features. Splits the 502-line widget into a card directory and fixes the
four separate defects behind "not all values are displayed clearly".

**Files:**
- Modify: `lib/features/gas_calculators/presentation/widgets/gas_blender_calculator.dart` (becomes a composing shell)
- Create: `lib/features/gas_calculators/presentation/widgets/blender/blender_formatting.dart`
- Create: `lib/features/gas_calculators/presentation/widgets/blender/blender_mix_row.dart`
- Create: `lib/features/gas_calculators/presentation/widgets/blender/blender_cylinder_card.dart`
- Create: `lib/features/gas_calculators/presentation/widgets/blender/blender_fill_gases_card.dart`
- Create: `lib/features/gas_calculators/presentation/widgets/blender/blender_about_card.dart`
- Modify: `test/features/gas_calculators/gas_blender_calculator_widget_test.dart`

**Interfaces:**
- Produces, in `blender_formatting.dart`:
  - `String formatPreciseMix(BuildContext context, GasMix m)`
  - `String formatPreciseGasName(BuildContext context, GasMix m)`
- Produces, in `blender_mix_row.dart`: `class BlenderMixRow extends StatelessWidget`
  taking `leading`, `pressureController`, `onPressure`, `o2Controller`,
  `heController`, `onMix`, and `pressureSymbol`.

**The four defects:**

1. `GasMix.name` renders through `roundedO2`/`roundedHe`, so `Tx 8.3/73.4`
   prints as `Tx 8/73`. Fixed by `formatPreciseMix`.
2. `initState` seeds pressure with `toStringAsFixed(0)`, so 207.6 becomes
   `208` on every re-seed, and a pressure-unit change re-seeds. Fixed by
   `formatDecimalForInput` from `core/utils/number_input.dart`.
3. Step pressures render with `formatPressure`, whose default is
   `decimals: 0`. Fixed by passing `decimals: 1`.
4. Three fields with suffix text share one row. Fixed by moving the unit into
   the label and adding a `LayoutBuilder` breakpoint at 420 logical pixels.

- [ ] **Step 1: Write the failing test**

Add to `test/features/gas_calculators/gas_blender_calculator_widget_test.dart`.
Remove the existing `blenderTankProvider` import and any assertion referencing
it first.

```dart
  testWidgets('a fractional pressure survives a unit change', (tester) async {
    final ref = await _pump(tester);

    await tester.enterText(
      find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.labelText?.startsWith('Pressure') == true,
      ).first,
      '207.6',
    );
    await tester.pumpAndSettle();
    expect(ref.read(blenderStartPressureProvider), closeTo(207.6, 0.001));

    _settings.apply(const AppSettings(pressureUnit: PressureUnit.psi));
    await tester.pumpAndSettle();
    _settings.apply(const AppSettings());
    await tester.pumpAndSettle();

    expect(ref.read(blenderStartPressureProvider), closeTo(207.6, 0.05));
    expect(find.text('208'), findsNothing);
  });

  testWidgets('a fractional trimix is labelled without rounding', (tester) async {
    final ref = await _pump(tester);
    ref.read(blenderStartMixProvider.notifier).state =
        const GasMix(o2: 8.3, he: 73.4);
    ref.read(blenderTargetMixProvider.notifier).state =
        const GasMix(o2: 8.3, he: 73.4);
    ref.read(blenderStartPressureProvider.notifier).state = 80;
    ref.read(blenderTargetPressureProvider.notifier).state = 220;
    ref.read(blenderFillGas2Provider.notifier).state =
        const GasMix(o2: 0, he: 100);
    await tester.pumpAndSettle();

    expect(find.textContaining('Tx 8.3/73.4'), findsWidgets);
    expect(find.textContaining('Tx 8/73'), findsNothing);
  });

  testWidgets('a narrow surface does not overflow', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await _pump(tester);
    expect(tester.takeException(), isNull);
  });
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
flutter test test/features/gas_calculators/gas_blender_calculator_widget_test.dart
```

Expected: FAIL. The unit-change test fails on `find.text('208')` finding a
widget; the label test fails on `Tx 8.3/73.4` not being found.

- [ ] **Step 3: Create the formatting helpers**

Create `lib/features/gas_calculators/presentation/widgets/blender/blender_formatting.dart`:

```dart
import 'package:flutter/widgets.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    show GasMix;
import 'package:submersion/l10n/l10n_extension.dart';

/// One decimal, trailing ".0" trimmed.
String _trim(double v) =>
    v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

/// A trimix label that keeps its decimals, e.g. "Tx 8.3/73.4".
///
/// [GasMix.name] rounds through roundedO2/roundedHe, which is right for a
/// logbook and wrong at a fill station: a blender working to a tenth of a
/// percent cannot read their own target off a label that says "Tx 8/73".
String formatPreciseMix(BuildContext context, GasMix m) {
  if (m.isAir) return context.l10n.gasCalculators_blender_air;
  if (m.he >= 99.95) return context.l10n.gasCalculators_blender_helium;
  if (m.o2 >= 99.95) return 'O₂';
  if (m.he > 0) return 'Tx ${_trim(m.o2)}/${_trim(m.he)}';
  return 'EAN${_trim(m.o2)}';
}

/// The name to print for a fill gas. Same rules, kept as a separate entry
/// point so the call sites read as what they mean.
String formatPreciseGasName(BuildContext context, GasMix m) =>
    formatPreciseMix(context, m);
```

- [ ] **Step 4: Create the responsive mix row**

Create `lib/features/gas_calculators/presentation/widgets/blender/blender_mix_row.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// A row of pressure (optional) plus O2 plus He fields.
///
/// The unit lives in the label rather than in `suffixText`. A suffix costs
/// roughly 30 logical pixels inside the field, which on a phone is the
/// difference between showing "65.9" and clipping it. Below [_stackBelow] the
/// pressure field takes its own line instead of sharing one with two
/// percentages.
class BlenderMixRow extends StatelessWidget {
  const BlenderMixRow({
    super.key,
    this.leading,
    this.pressureController,
    this.onPressure,
    required this.o2Controller,
    required this.heController,
    required this.onMix,
    required this.pressureSymbol,
  });

  static const double _stackBelow = 420;

  final String? leading;
  final TextEditingController? pressureController;
  final ValueChanged<String>? onPressure;
  final TextEditingController o2Controller;
  final TextEditingController heController;
  final VoidCallback onMix;
  final String pressureSymbol;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked =
            pressureController != null && constraints.maxWidth < _stackBelow;
        final percentages = Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(child: _o2Field(context)),
            const SizedBox(width: 8),
            Expanded(child: _heField(context)),
          ],
        );

        if (stacked) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (leading != null) _leadingLabel(context),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _pressureField(context),
                    const SizedBox(height: 8),
                    percentages,
                  ],
                ),
              ),
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (leading != null) _leadingLabel(context),
            if (pressureController != null) ...[
              Expanded(flex: 4, child: _pressureField(context)),
              const SizedBox(width: 8),
            ],
            Expanded(flex: 3, child: _o2Field(context)),
            const SizedBox(width: 8),
            Expanded(flex: 3, child: _heField(context)),
          ],
        );
      },
    );
  }

  Widget _leadingLabel(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: 8, bottom: 14),
    child: Text(leading!, style: Theme.of(context).textTheme.titleSmall),
  );

  Widget _pressureField(BuildContext context) => _field(
    controller: pressureController!,
    label: '${context.l10n.gasCalculators_blender_pressure} ($pressureSymbol)',
    onChanged: onPressure!,
  );

  Widget _o2Field(BuildContext context) => _field(
    controller: o2Controller,
    label: '${context.l10n.gasCalculators_blender_o2} (%)',
    onChanged: (_) => onMix(),
  );

  Widget _heField(BuildContext context) => _field(
    controller: heController,
    label: '${context.l10n.gasCalculators_blender_he} (%)',
    onChanged: (_) => onMix(),
  );

  Widget _field({
    required TextEditingController controller,
    required String label,
    required ValueChanged<String> onChanged,
  }) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        border: const OutlineInputBorder(),
      ),
      onChanged: onChanged,
    );
  }
}
```

- [ ] **Step 5: Rewrite the calculator as a shell**

In `gas_blender_calculator.dart`:

- Delete `_cylinderChips` and the `blenderTankProvider` watch entirely.
- Delete `_mixRow` and `_field`; use `BlenderMixRow`.
- Delete `_gasName`; use `formatPreciseGasName`.
- Replace the seeding helper in `initState`:

```dart
    // Seeding must be lossless: a re-seed happens on every pressure-unit
    // change, and toStringAsFixed(0) silently rewrote 207.6 bar as 208.
    String p(double bar) => formatDecimalForInput(_units.convertPressure(bar));
    String n(double v) => formatDecimalForInput(v);
```

with `import 'package:submersion/core/utils/number_input.dart';` already present.

- In `_stepText`, render pressures with `_units.formatPressure(step.pressureBar, decimals: 1)`.
- Move `_cylinderCard` into `blender_cylinder_card.dart`, `_fillGasesCard` into
  `blender_fill_gases_card.dart`, and `_aboutCard` into
  `blender_about_card.dart`, each as its own `ConsumerWidget`. The result card
  stays in place for now; Task 9 moves it.
- Delete the "amounts in litres" block from `_resultCard`, including the
  `Divider`, the `gasCalculators_blender_amounts` label, and the joined volume
  line. Task 9 replaces it with the delta column.

- [ ] **Step 6: Run the widget tests**

```bash
flutter test test/features/gas_calculators/
```

Expected: PASS.

- [ ] **Step 7: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add lib/features/gas_calculators/presentation/widgets/ \
        test/features/gas_calculators/gas_blender_calculator_widget_test.dart
git commit -m "fix(blender): show the precision a gas blender works to

Four separate defects behind the reported 'values are obscured': gas
labels rounded through GasMix.name, pressures seeded with
toStringAsFixed(0) and rewritten on every unit change, step pressures
printed with no decimals, and three suffixed fields sharing one row on a
phone.

Splits the 502-line widget into a card directory on the way.

Refs #1100"
```

---

### Task 8: Blending conditions card

**Files:**
- Create: `lib/features/gas_calculators/presentation/widgets/blender/blender_conditions_card.dart`
- Modify: `lib/features/gas_calculators/presentation/widgets/gas_blender_calculator.dart` (insert the card between fill gases and result)
- Test: `test/features/gas_calculators/blender_conditions_card_test.dart`

**Interfaces:**
- Consumes: `blenderFillTempProvider`, `blenderSettledTempProvider`,
  `blenderGasModelProvider`, `saveBlenderPreferences`.
- Produces: `class BlenderConditionsCard extends ConsumerWidget`.

**Temperature ladder:** the values offered are defined in the display unit so
both audiences get round numbers, and converted to Celsius for storage.

- Celsius: 0, 5, 10, 15, 20, 25, 30, 35
- Fahrenheit: 30, 40, 50, 60, 70, 80, 90, 100

A stored temperature that is not on the ladder (arriving from another device,
or from a unit change) is added to the ladder so the dropdown can show it,
rather than silently snapping to a neighbour.

- [ ] **Step 1: Write the failing test**

Create `test/features/gas_calculators/blender_conditions_card_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/gas_calculators/domain/blending/equation_of_state.dart';
import 'package:submersion/features/gas_calculators/presentation/providers/gas_blender_providers.dart';
import 'package:submersion/features/gas_calculators/presentation/widgets/blender/blender_conditions_card.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

class _TestSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _TestSettingsNotifier(super.settings);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<WidgetRef> _pump(WidgetTester tester, {AppSettings? settings}) async {
  late WidgetRef captured;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        settingsProvider.overrideWith(
          (ref) => _TestSettingsNotifier(settings ?? const AppSettings()),
        ),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Consumer(
            builder: (context, ref, _) {
              captured = ref;
              return const BlenderConditionsCard();
            },
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return captured;
}

void main() {
  testWidgets('offers the Celsius ladder', (tester) async {
    await _pump(tester);
    await tester.tap(find.byKey(const Key('blender-fill-temp')));
    await tester.pumpAndSettle();
    for (final v in ['0 °C', '5 °C', '20 °C', '35 °C']) {
      expect(find.text(v), findsWidgets);
    }
  });

  testWidgets('offers the Fahrenheit ladder', (tester) async {
    await _pump(
      tester,
      settings: const AppSettings(temperatureUnit: TemperatureUnit.fahrenheit),
    );
    await tester.tap(find.byKey(const Key('blender-fill-temp')));
    await tester.pumpAndSettle();
    for (final v in ['30 °F', '70 °F', '100 °F']) {
      expect(find.text(v), findsWidgets);
    }
  });

  testWidgets('choosing a fill temperature writes Celsius', (tester) async {
    final ref = await _pump(tester);
    await tester.tap(find.byKey(const Key('blender-fill-temp')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('5 °C').last);
    await tester.pumpAndSettle();
    expect(ref.read(blenderFillTempProvider), 5);
  });

  testWidgets('choosing a gas model writes the provider', (tester) async {
    final ref = await _pump(tester);
    await tester.tap(find.byKey(const Key('blender-gas-model')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ideal gas').last);
    await tester.pumpAndSettle();
    expect(ref.read(blenderGasModelProvider), BlendGasModel.ideal);
  });

  testWidgets('marks the Z-factor model as recommended', (tester) async {
    await _pump(tester);
    expect(find.textContaining('Recommended'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
flutter test test/features/gas_calculators/blender_conditions_card_test.dart
```

Expected: FAIL at compile, `Target of URI doesn't exist: '.../blender_conditions_card.dart'`.

- [ ] **Step 3: Write the card**

Create `lib/features/gas_calculators/presentation/widgets/blender/blender_conditions_card.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/gas_calculators/domain/blending/equation_of_state.dart';
import 'package:submersion/features/gas_calculators/presentation/providers/gas_blender_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Fill temperature, settled temperature and equation of state.
///
/// Two temperatures rather than one because a single temperature would change
/// nothing: mole ratios are temperature-free, so a uniform temperature cancels
/// out of the whole procedure. What a blender actually does is fill a chilled
/// cylinder and quote the pressure it settles to.
class BlenderConditionsCard extends ConsumerWidget {
  const BlenderConditionsCard({super.key});

  /// The values offered, in the display unit, so neither audience is asked to
  /// pick from a list of converted oddities.
  static const List<double> _celsiusLadder = [0, 5, 10, 15, 20, 25, 30, 35];
  static const List<double> _fahrenheitLadder = [
    30, 40, 50, 60, 70, 80, 90, 100,
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final units = UnitFormatter(settings);
    final fahrenheit = settings.temperatureUnit == TemperatureUnit.fahrenheit;
    final ladder = fahrenheit ? _fahrenheitLadder : _celsiusLadder;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.gasCalculators_blender_conditions,
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            _temperatureField(
              context,
              ref,
              key: const Key('blender-fill-temp'),
              label: context.l10n.gasCalculators_blender_fillTemp,
              help: context.l10n.gasCalculators_blender_fillTempHelp,
              units: units,
              ladder: ladder,
              current: ref.watch(blenderFillTempProvider),
              onChanged: (c) {
                ref.read(blenderFillTempProvider.notifier).state = c;
                saveBlenderPreferences(ref);
              },
            ),
            const SizedBox(height: 12),
            _temperatureField(
              context,
              ref,
              key: const Key('blender-settled-temp'),
              label: context.l10n.gasCalculators_blender_settledTemp,
              help: context.l10n.gasCalculators_blender_settledTempHelp,
              units: units,
              ladder: ladder,
              current: ref.watch(blenderSettledTempProvider),
              onChanged: (c) {
                ref.read(blenderSettledTempProvider.notifier).state = c;
                saveBlenderPreferences(ref);
              },
            ),
            const SizedBox(height: 16),
            _modelField(context, ref),
          ],
        ),
      ),
    );
  }

  Widget _temperatureField(
    BuildContext context,
    WidgetRef ref, {
    required Key key,
    required String label,
    required String help,
    required UnitFormatter units,
    required List<double> ladder,
    required double current,
    required ValueChanged<double> onChanged,
  }) {
    // A value arriving from another device, or surviving a unit change, may
    // not sit on the ladder. Show it rather than snapping it to a neighbour.
    final shown = units.convertTemperature(current);
    final values = [...ladder];
    if (!values.any((v) => (v - shown).abs() < 0.05)) {
      values
        ..add(shown)
        ..sort();
    }

    return DropdownButtonFormField<double>(
      key: key,
      initialValue: values.firstWhere((v) => (v - shown).abs() < 0.05),
      decoration: InputDecoration(
        labelText: label,
        helperText: help,
        helperMaxLines: 3,
        isDense: true,
        border: const OutlineInputBorder(),
      ),
      items: [
        for (final v in values)
          DropdownMenuItem(
            value: v,
            child: Text('${_trim(v)} ${units.temperatureSymbol}'),
          ),
      ],
      onChanged: (v) {
        if (v == null) return;
        onChanged(units.temperatureToCelsius(v));
      },
    );
  }

  Widget _modelField(BuildContext context, WidgetRef ref) {
    String label(BlendGasModel m) => switch (m) {
      BlendGasModel.ideal => context.l10n.gasCalculators_blender_modelIdeal,
      BlendGasModel.vanDerWaals =>
        context.l10n.gasCalculators_blender_modelVanDerWaals,
      BlendGasModel.zFactor =>
        '${context.l10n.gasCalculators_blender_modelZFactor} '
            '(${context.l10n.gasCalculators_blender_modelRecommended})',
    };

    return DropdownButtonFormField<BlendGasModel>(
      key: const Key('blender-gas-model'),
      initialValue: ref.watch(blenderGasModelProvider),
      decoration: InputDecoration(
        labelText: context.l10n.gasCalculators_blender_gasModel,
        helperText: context.l10n.gasCalculators_blender_modelHelp,
        helperMaxLines: 4,
        isDense: true,
        border: const OutlineInputBorder(),
      ),
      items: [
        for (final m in BlendGasModel.values)
          DropdownMenuItem(value: m, child: Text(label(m))),
      ],
      onChanged: (m) {
        if (m == null) return;
        ref.read(blenderGasModelProvider.notifier).state = m;
        saveBlenderPreferences(ref);
      },
    );
  }

  static String _trim(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
}
```

If `DropdownButtonFormField.initialValue` is not available in this Flutter
version, use `value:` instead; check the other dropdowns in
`lib/features/settings/presentation/` for which the codebase uses.

`saveBlenderPreferences` takes a `Ref`; if `WidgetRef` does not satisfy it,
change its signature to accept both by reading through a
`T Function<T>(ProviderListenable<T>)` callback, matching `_reset` in Task 5.

- [ ] **Step 4: Insert the card into the shell**

In `gas_blender_calculator.dart`, between `_fillGasesCard` and `_resultCard`:

```dart
              const BlenderConditionsCard(),
              const SizedBox(height: 16),
```

- [ ] **Step 5: Run the tests**

```bash
flutter test test/features/gas_calculators/
```

Expected: PASS.

- [ ] **Step 6: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add lib/features/gas_calculators/presentation/widgets/ \
        test/features/gas_calculators/blender_conditions_card_test.dart
git commit -m "feat(blender): fill temperature, settled temperature and gas model

The temperature ladder is defined in the display unit so neither Celsius
nor Fahrenheit users pick from converted oddities, and the Z-factor model
is marked recommended because van der Waals is several percent off at
fill pressure.

Refs #1100"
```

---

### Task 9: Fill procedure with the bar delivered

**Files:**
- Create: `lib/features/gas_calculators/presentation/widgets/blender/blender_procedure_card.dart`
- Modify: `lib/features/gas_calculators/presentation/widgets/gas_blender_calculator.dart` (move `_resultCard`, `_stepText` and `_errorText` out)
- Modify: `test/features/gas_calculators/gas_blender_calculator_widget_test.dart`

**Interfaces:**
- Consumes: `BlenderOutcome`, `BlendStep`, `formatPreciseMix`,
  `formatPreciseGasName`.
- Produces: `class BlenderProcedureCard extends ConsumerWidget`.

**Target output shape:**

```
Start          80.0 bar    Tx 8.3/73.4
Add O2       + 7.8 bar  ->  87.8 bar   Tx 16.6/67.0
Add He      + 96.7 bar  -> 184.5 bar   Tx  8.5/49.0
Add air     + 35.5 bar  -> 220.0 bar   Tx 18.0/41.0

Settles to 220.0 bar at 20 C
```

- [ ] **Step 1: Write the failing test**

Add to `test/features/gas_calculators/gas_blender_calculator_widget_test.dart`:

```dart
  testWidgets('each fill step shows the bar delivered', (tester) async {
    final ref = await _pump(tester);
    ref.read(blenderTargetMixProvider.notifier).state =
        const GasMix(o2: 18, he: 45);
    ref.read(blenderFillGas2Provider.notifier).state =
        const GasMix(o2: 0, he: 100);
    await tester.pumpAndSettle();

    expect(find.textContaining('+15.3'), findsOneWidget);
    expect(find.textContaining('104.3'), findsOneWidget);
  });

  testWidgets('a chilled fill names the settled pressure', (tester) async {
    final ref = await _pump(tester);
    ref.read(blenderFillTempProvider.notifier).state = 5;
    await tester.pumpAndSettle();

    expect(find.textContaining('Settles to'), findsOneWidget);
    expect(find.textContaining('200.0 bar'), findsWidgets);
  });

  testWidgets('an equal-temperature fill does not claim a settle', (tester) async {
    await _pump(tester);
    expect(find.textContaining('Settles to'), findsNothing);
  });

  testWidgets('the litres line is gone', (tester) async {
    await _pump(tester);
    expect(find.text('Gas to add'), findsNothing);
  });
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
flutter test test/features/gas_calculators/gas_blender_calculator_widget_test.dart
```

Expected: FAIL, `+15.3` not found.

- [ ] **Step 3: Write the card**

Create `lib/features/gas_calculators/presentation/widgets/blender/blender_procedure_card.dart`.
Move `_resultCard`, `_stepText` and `_errorText` from
`gas_blender_calculator.dart` into it verbatim, then change `_stepText` to:

```dart
  /// One procedure line: what to add, how much the gauge moves, where it lands,
  /// and what is in the cylinder afterwards.
  ///
  /// The delta is what issue #936 asked for and what a fill station meters.
  /// The old build reported a surface volume in litres instead, which is not a
  /// quantity anyone can read off a gauge.
  Widget _stepLine(BuildContext context, WidgetRef ref, BlendStep step) {
    final units = UnitFormatter(ref.read(settingsProvider));
    final pressure = units.formatPressure(step.pressureBar, decimals: 1);
    final mix = formatPreciseMix(context, step.resultingMix);

    if (step.fillGas == null) {
      return _row(
        context,
        context.l10n.gasCalculators_blender_stepStartLabel,
        '',
        pressure,
        mix,
      );
    }
    final added =
        '+${units.formatPressure(step.addedBar, decimals: 1)}';
    return _row(
      context,
      context.l10n.gasCalculators_blender_stepAdd(
        formatPreciseGasName(context, step.fillGas!),
      ),
      added,
      pressure,
      mix,
    );
  }

  Widget _row(
    BuildContext context,
    String action,
    String added,
    String pressure,
    String mix,
  ) {
    final style = Theme.of(context).textTheme.bodyLarge?.copyWith(
      color: Theme.of(context).colorScheme.onPrimaryContainer,
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 5, child: Text(action, style: style)),
          Expanded(
            flex: 4,
            child: Text(added, style: style, textAlign: TextAlign.end),
          ),
          Expanded(
            flex: 4,
            child: Text(pressure, style: style, textAlign: TextAlign.end),
          ),
          Expanded(
            flex: 5,
            child: Text(mix, style: style, textAlign: TextAlign.end),
          ),
        ],
      ),
    );
  }
```

After the step list, in place of the deleted amounts block, add the settled
line, shown only when the two temperatures differ:

```dart
            if (ref.watch(blenderFillTempProvider) !=
                ref.watch(blenderSettledTempProvider)) ...[
              const Divider(height: 24),
              Text(
                context.l10n.gasCalculators_blender_settlesTo(
                  units.formatPressure(
                    outcome.result!.settledPressureBar,
                    decimals: 1,
                  ),
                  units.formatTemperature(
                    ref.watch(blenderSettledTempProvider),
                    decimals: 0,
                  ),
                ),
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
            ],
```

- [ ] **Step 4: Swap the shell over**

In `gas_blender_calculator.dart`, replace the `_resultCard(context, outcome)`
call with `const BlenderProcedureCard()` and delete the now-unused
`_resultCard`, `_stepText`, `_errorText` and `_gasName` members plus any imports
they alone needed.

- [ ] **Step 5: Run the tests**

```bash
flutter test test/features/gas_calculators/
```

Expected: PASS.

- [ ] **Step 6: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add lib/features/gas_calculators/presentation/widgets/ \
        test/features/gas_calculators/gas_blender_calculator_widget_test.dart
git commit -m "feat(blender): report fill amounts in bar, not litres

Partial-pressure blending is done by pressure, so the procedure now names
the bar each gas delivers alongside the pressure to stop at, the shape
issue #936 asked for. A chilled or warm fill also names the pressure the
cylinder settles to.

Refs #1100, #936"
```

---

### Task 10: Target mix templates

**Files:**
- Create: `lib/features/gas_calculators/presentation/widgets/blender/mix_template_menu.dart`
- Create: `lib/features/gas_calculators/presentation/widgets/blender/mix_template_dialog.dart`
- Modify: `lib/features/gas_calculators/presentation/widgets/blender/blender_cylinder_card.dart` (add the menu beside the target fill heading)
- Test: `test/features/gas_calculators/mix_template_test.dart`

**Interfaces:**
- Consumes: `MixTemplate`, `BlenderPreferences.maxTemplates`,
  `blenderTemplatesProvider`, `blenderTargetMixProvider`,
  `saveBlenderPreferences`.
- Produces:
  - `class MixTemplateMenu extends ConsumerWidget` taking
    `required void Function(MixTemplate) onSelected`.
  - `Future<void> showMixTemplateDialog(BuildContext context, WidgetRef ref)`.

**Behaviour:** selecting a template writes both O2 and He into
`blenderTargetMixProvider` and calls `onSelected` so the card can re-seed its
text controllers. Saving the current mix appends it, refusing a duplicate, an
invalid mix, or one past the cap, each with its own message.

- [ ] **Step 1: Write the failing test**

Create `test/features/gas_calculators/mix_template_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    show GasMix;
import 'package:submersion/features/gas_calculators/domain/blending/blender_preferences.dart';
import 'package:submersion/features/gas_calculators/presentation/providers/gas_blender_providers.dart';
import 'package:submersion/features/gas_calculators/presentation/widgets/blender/mix_template_menu.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

class _TestSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _TestSettingsNotifier(super.settings);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<WidgetRef> _pump(WidgetTester tester) async {
  late WidgetRef captured;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        settingsProvider.overrideWith(
          (ref) => _TestSettingsNotifier(const AppSettings()),
        ),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Consumer(
            builder: (context, ref, _) {
              captured = ref;
              return MixTemplateMenu(onSelected: (_) {});
            },
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return captured;
}

void main() {
  testWidgets('lists the seeded templates', (tester) async {
    await _pump(tester);
    await tester.tap(find.byType(MixTemplateMenu));
    await tester.pumpAndSettle();
    for (final label in ['7/75', '10/70', '12/60', '15/55', '18/35']) {
      expect(find.text(label), findsOneWidget);
    }
  });

  testWidgets('selecting a template writes the target mix', (tester) async {
    final ref = await _pump(tester);
    await tester.tap(find.byType(MixTemplateMenu));
    await tester.pumpAndSettle();
    await tester.tap(find.text('10/70'));
    await tester.pumpAndSettle();

    final target = ref.read(blenderTargetMixProvider);
    expect(target.o2, 10);
    expect(target.he, 70);
  });

  testWidgets('saving the current mix appends it', (tester) async {
    final ref = await _pump(tester);
    ref.read(blenderTargetMixProvider.notifier).state =
        const GasMix(o2: 21, he: 35);
    await tester.pumpAndSettle();

    await tester.tap(find.byType(MixTemplateMenu));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save current mix'));
    await tester.pumpAndSettle();

    expect(
      ref.read(blenderTemplatesProvider).last,
      const MixTemplate(o2: 21, he: 35),
    );
  });

  testWidgets('saving a duplicate says so and adds nothing', (tester) async {
    final ref = await _pump(tester);
    ref.read(blenderTargetMixProvider.notifier).state =
        const GasMix(o2: 10, he: 70);
    await tester.pumpAndSettle();

    await tester.tap(find.byType(MixTemplateMenu));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save current mix'));
    await tester.pumpAndSettle();

    expect(find.text('That mix is already saved.'), findsOneWidget);
    expect(ref.read(blenderTemplatesProvider), hasLength(5));
  });

  testWidgets('an emptied list shows the empty message', (tester) async {
    final ref = await _pump(tester);
    ref.read(blenderTemplatesProvider.notifier).state = const [];
    await tester.pumpAndSettle();

    await tester.tap(find.byType(MixTemplateMenu));
    await tester.pumpAndSettle();
    expect(find.textContaining('No templates yet'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
flutter test test/features/gas_calculators/mix_template_test.dart
```

Expected: FAIL at compile, `Target of URI doesn't exist: '.../mix_template_menu.dart'`.

- [ ] **Step 3: Write the menu**

Create `lib/features/gas_calculators/presentation/widgets/blender/mix_template_menu.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    show GasMix;
import 'package:submersion/features/gas_calculators/domain/blending/blender_preferences.dart';
import 'package:submersion/features/gas_calculators/presentation/providers/gas_blender_providers.dart';
import 'package:submersion/features/gas_calculators/presentation/widgets/blender/mix_template_dialog.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Saved target mixes, offered as a menu beside the target fill fields.
///
/// A blender repeats the same handful of mixes, so retyping 10/70 on every
/// fill is the friction this removes. Templates carry a mix only: the same mix
/// gets blended into different cylinders at different pressures.
class MixTemplateMenu extends ConsumerWidget {
  const MixTemplateMenu({super.key, required this.onSelected});

  /// Called after the target mix providers are updated, so the caller can
  /// re-seed its text controllers.
  final void Function(MixTemplate) onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final templates = ref.watch(blenderTemplatesProvider);

    return PopupMenuButton<Object>(
      tooltip: context.l10n.gasCalculators_blender_templates,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(context.l10n.gasCalculators_blender_templates),
            const Icon(Icons.arrow_drop_down),
          ],
        ),
      ),
      itemBuilder: (context) => [
        if (templates.isEmpty)
          PopupMenuItem<Object>(
            enabled: false,
            child: Text(context.l10n.gasCalculators_blender_templateNone),
          )
        else
          for (final t in templates)
            PopupMenuItem<Object>(value: t, child: Text(t.label)),
        const PopupMenuDivider(),
        PopupMenuItem<Object>(
          value: _save,
          child: Text(context.l10n.gasCalculators_blender_saveTemplate),
        ),
        PopupMenuItem<Object>(
          value: _manage,
          child: Text(context.l10n.gasCalculators_blender_manageTemplates),
        ),
      ],
      onSelected: (value) {
        if (value is MixTemplate) {
          ref.read(blenderTargetMixProvider.notifier).state = GasMix(
            o2: value.o2,
            he: value.he,
          );
          onSelected(value);
          return;
        }
        if (value == _save) {
          _saveCurrent(context, ref);
          return;
        }
        showMixTemplateDialog(context, ref);
      },
    );
  }

  static const Object _save = Object();
  static const Object _manage = Object();

  void _saveCurrent(BuildContext context, WidgetRef ref) {
    final mix = ref.read(blenderTargetMixProvider);
    final candidate = MixTemplate(o2: mix.o2, he: mix.he);
    final existing = ref.read(blenderTemplatesProvider);

    String? problem;
    if (!candidate.isValid) {
      problem = context.l10n.gasCalculators_blender_templateInvalid;
    } else if (existing.contains(candidate)) {
      problem = context.l10n.gasCalculators_blender_templateExists;
    } else if (existing.length >= BlenderPreferences.maxTemplates) {
      problem = context.l10n.gasCalculators_blender_templateLimit(
        BlenderPreferences.maxTemplates,
      );
    }

    final message =
        problem ??
        context.l10n.gasCalculators_blender_templateSaved(candidate.label);
    if (problem == null) {
      ref.read(blenderTemplatesProvider.notifier).state = [
        ...existing,
        candidate,
      ];
      saveBlenderPreferences(ref);
    }
    ScaffoldMessenger.maybeOf(
      context,
    )?.showSnackBar(SnackBar(content: Text(message)));
  }
}
```

`const Object _save = Object();` will not compile as a const; declare them as
`static final Object _save = Object();` instead if analyze objects.

- [ ] **Step 4: Write the manage dialog**

Create `lib/features/gas_calculators/presentation/widgets/blender/mix_template_dialog.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/number_input.dart';
import 'package:submersion/features/gas_calculators/domain/blending/blender_preferences.dart';
import 'package:submersion/features/gas_calculators/presentation/providers/gas_blender_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Add and delete saved target mixes.
Future<void> showMixTemplateDialog(BuildContext context, WidgetRef ref) {
  return showDialog<void>(
    context: context,
    builder: (context) => _MixTemplateDialog(parentRef: ref),
  );
}

class _MixTemplateDialog extends StatefulWidget {
  const _MixTemplateDialog({required this.parentRef});

  final WidgetRef parentRef;

  @override
  State<_MixTemplateDialog> createState() => _MixTemplateDialogState();
}

class _MixTemplateDialogState extends State<_MixTemplateDialog> {
  final _o2 = TextEditingController();
  final _he = TextEditingController();

  @override
  void dispose() {
    _o2.dispose();
    _he.dispose();
    super.dispose();
  }

  WidgetRef get _ref => widget.parentRef;

  void _add() {
    final o2 = parseUserDecimal(_o2.text);
    final he = parseUserDecimal(_he.text);
    if (o2 == null || he == null) return;
    final candidate = MixTemplate(o2: o2, he: he);
    final existing = _ref.read(blenderTemplatesProvider);
    if (!candidate.isValid ||
        existing.contains(candidate) ||
        existing.length >= BlenderPreferences.maxTemplates) {
      return;
    }
    setState(() {
      _ref.read(blenderTemplatesProvider.notifier).state = [
        ...existing,
        candidate,
      ];
    });
    saveBlenderPreferences(_ref);
    _o2.clear();
    _he.clear();
  }

  void _delete(MixTemplate t) {
    setState(() {
      _ref.read(blenderTemplatesProvider.notifier).state = [
        ..._ref.read(blenderTemplatesProvider).where((x) => x != t),
      ];
    });
    saveBlenderPreferences(_ref);
  }

  @override
  Widget build(BuildContext context) {
    final templates = _ref.watch(blenderTemplatesProvider);
    return AlertDialog(
      title: Text(context.l10n.gasCalculators_blender_templatesTitle),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (templates.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  context.l10n.gasCalculators_blender_templateNone,
                ),
              )
            else
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final t in templates)
                      ListTile(
                        dense: true,
                        title: Text(t.label),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline),
                          tooltip: context.l10n
                              .gasCalculators_blender_templateDelete(t.label),
                          onPressed: () => _delete(t),
                        ),
                      ),
                  ],
                ),
              ),
            const Divider(),
            Row(
              children: [
                Expanded(child: _numberField(context, _o2, 'O₂')),
                const SizedBox(width: 8),
                Expanded(child: _numberField(context, _he, 'He')),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.add),
                  tooltip: context.l10n.gasCalculators_blender_templateAdd,
                  onPressed: _add,
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.l10n.common_done),
        ),
      ],
    );
  }

  Widget _numberField(
    BuildContext context,
    TextEditingController controller,
    String label,
  ) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
      decoration: InputDecoration(
        labelText: '$label (%)',
        isDense: true,
        border: const OutlineInputBorder(),
      ),
    );
  }
}
```

If `context.l10n.common_done` does not exist, grep `app_en.arb` for the
project's existing "Done" or "Close" key and use that; do not add a new one.

- [ ] **Step 5: Add the menu to the cylinder card**

In `blender_cylinder_card.dart`, replace the plain target fill heading with a
row carrying the heading and the menu, and re-seed the target controllers on
selection:

```dart
            Row(
              children: [
                Expanded(
                  child: Text(
                    context.l10n.gasCalculators_blender_targetFill,
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                MixTemplateMenu(
                  onSelected: (t) {
                    targetO2Controller.text = formatDecimalForInput(t.o2);
                    targetHeController.text = formatDecimalForInput(t.he);
                  },
                ),
              ],
            ),
```

- [ ] **Step 6: Run the tests**

```bash
flutter test test/features/gas_calculators/
```

Expected: PASS.

- [ ] **Step 7: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add lib/features/gas_calculators/presentation/widgets/blender/ \
        test/features/gas_calculators/mix_template_test.dart
git commit -m "feat(blender): reusable target mix templates

Seeded with the five mixes named in issue #1100 and editable from a menu
beside the target fill. Seeding keys on the absence of the stored blob
rather than on an empty list, so deleting every template sticks.

Refs #1100"
```

---

### Task 11: Costing card

**Files:**
- Create: `lib/features/gas_calculators/presentation/widgets/blender/blender_billing_card.dart`
- Modify: `lib/features/gas_calculators/presentation/widgets/gas_blender_calculator.dart` (append the card after the About card)
- Test: `test/features/gas_calculators/blender_billing_card_test.dart`

**Interfaces:**
- Consumes: `blenderBillingProvider`, `blenderCylinderLitersProvider`,
  `blenderGasPricesProvider`, `blenderCurrencyProvider`,
  `currencyCodesWith`, `formatMoney`, `formatPreciseGasName`.
- Produces: `class BlenderBillingCard extends ConsumerStatefulWidget`.

**Units:** everything is stored in litres and bar. The cylinder field, the
volume column and the price basis all render in the diver's volume unit.
For cubic feet, free gas is `litres / 28.3168` and the price basis reads
"per 100 cu ft".

The cylinder field is a plain number, per the reporter, with a preset menu that
fills it from `metricTankChoices()` or `imperialTankChoices()` so an imperial
diver is not asked to recall that an AL80 holds 0.39 cu ft of water.

- [ ] **Step 1: Write the failing test**

Create `test/features/gas_calculators/blender_billing_card_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    show GasMix;
import 'package:submersion/features/gas_calculators/presentation/providers/gas_blender_providers.dart';
import 'package:submersion/features/gas_calculators/presentation/widgets/blender/blender_billing_card.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

class _TestSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _TestSettingsNotifier(super.settings);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<WidgetRef> _pump(WidgetTester tester) async {
  late WidgetRef captured;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        settingsProvider.overrideWith(
          (ref) => _TestSettingsNotifier(
            const AppSettings(defaultCurrency: 'CHF'),
          ),
        ),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: Consumer(
              builder: (context, ref, _) {
                captured = ref;
                return const BlenderBillingCard();
              },
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return captured;
}

void main() {
  testWidgets('reproduces the issue #1100 helium example', (tester) async {
    final ref = await _pump(tester);
    ref.read(blenderCylinderLitersProvider.notifier).state = 3;
    ref.read(blenderStartPressureProvider.notifier).state = 150;
    ref.read(blenderStartMixProvider.notifier).state = const GasMix(o2: 0, he: 100);
    ref.read(blenderTargetPressureProvider.notifier).state = 200;
    ref.read(blenderTargetMixProvider.notifier).state = const GasMix(o2: 0, he: 100);
    ref.read(blenderFillGas1Provider.notifier).state = const GasMix(o2: 0, he: 100);
    ref.read(blenderFillGas2Provider.notifier).state = const GasMix(o2: 0, he: 100);
    ref.read(blenderGasPricesProvider.notifier).state = const [7.99, null, null];
    await tester.pumpAndSettle();

    // 3 L x 50 bar / 100 x 7.99 = 11.985
    expect(find.textContaining('11.9'), findsWidgets);
  });

  testWidgets('shows the bar delivered on every line', (tester) async {
    final ref = await _pump(tester);
    ref.read(blenderCylinderLitersProvider.notifier).state = 12;
    await tester.pumpAndSettle();
    expect(find.textContaining('bar'), findsWidgets);
  });

  testWidgets('an unpriced gas suppresses the total', (tester) async {
    final ref = await _pump(tester);
    ref.read(blenderGasPricesProvider.notifier).state = const [2.0, null, null];
    await tester.pumpAndSettle();
    expect(find.textContaining('Enter a price for every gas'), findsOneWidget);
  });

  testWidgets('states the billing basis', (tester) async {
    await _pump(tester);
    expect(find.textContaining('pressure delivered'), findsOneWidget);
  });

  testWidgets('defaults the currency to the diver setting', (tester) async {
    final ref = await _pump(tester);
    expect(ref.read(blenderCurrencyProvider), 'CHF');
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
flutter test test/features/gas_calculators/blender_billing_card_test.dart
```

Expected: FAIL at compile, `Target of URI doesn't exist: '.../blender_billing_card.dart'`.

- [ ] **Step 3: Write the card**

Create `lib/features/gas_calculators/presentation/widgets/blender/blender_billing_card.dart`.
It is a `ConsumerStatefulWidget` because it owns text controllers for the
cylinder volume and the three prices, seeded in `initState` from the providers
with `formatDecimalForInput` and read back with `parseUserDecimal`.

Structure:

1. Section title `gasCalculators_blender_billing`.
2. A cylinder row: a number field labelled
   `'${l10n.gasCalculators_blender_cylinderVolume} (${units.volumeSymbol})'`,
   plus a `PopupMenuButton` labelled `gasCalculators_blender_cylinderPresets`
   listing `metricTankChoices()` or `imperialTankChoices()` by
   `units.formatTankVolume(...)`, each writing
   `choice.waterVolumeLiters` into `blenderCylinderLitersProvider` and
   re-seeding the field.
3. A currency dropdown from
   `currencyCodesWith(ref.watch(blenderCurrencyProvider))`.
4. One price field per billable line, labelled with
   `formatPreciseGasName(context, line.gas)` and
   `gasCalculators_blender_unitPrice(units.volumeSymbol)`.
5. A table of lines: gas name, `+{addedBar} {pressureSymbol}`, the volume in
   the diver's unit, the unit price, and the cost via `formatMoney`.
6. The total via `formatMoney`, or `gasCalculators_blender_costMissingPrice`
   when `BillingResult.total` is null.
7. `gasCalculators_blender_costBasis` in `bodySmall` under the total.

Conversion helper, used for the volume column and the price basis label:

```dart
  /// Free gas in the diver's own volume unit. Storage is always litres; a
  /// cubic-foot diver prices per 100 cu ft, which is the same arithmetic on a
  /// converted volume rather than a second formula.
  double _displayVolume(double liters, VolumeUnit unit) =>
      unit == VolumeUnit.liters ? liters : liters / 28.3168;
```

Every field write calls `saveBlenderPreferences(ref)` on `onEditingComplete`
and `onSubmitted`, not on `onChanged`, so typing a price is one database write
rather than one per keystroke.

Persist the cylinder volume as litres:

```dart
              onChanged: (v) {
                final entered = parseUserDecimal(v) ?? 0;
                ref.read(blenderCylinderLitersProvider.notifier).state =
                    settings.volumeUnit == VolumeUnit.liters
                    ? entered
                    : entered * 28.3168;
              },
              onEditingComplete: () => saveBlenderPreferences(ref),
```

- [ ] **Step 4: Append the card to the shell**

In `gas_blender_calculator.dart`, after the About card:

```dart
              const SizedBox(height: 16),
              const BlenderBillingCard(),
```

The reporter asked for the billing section after the safety note; keep that
order.

- [ ] **Step 5: Run the tests**

```bash
flutter test test/features/gas_calculators/
```

Expected: PASS.

- [ ] **Step 6: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add lib/features/gas_calculators/presentation/widgets/blender/ \
        lib/features/gas_calculators/presentation/widgets/gas_blender_calculator.dart \
        test/features/gas_calculators/blender_billing_card_test.dart
git commit -m "feat(blender): cost a fill at the fill station's prices

Cylinder water capacity plus a unit price per gas, saved between fills.
Every line shows the bar delivered so the arithmetic reconciles against
an invoice by hand.

Refs #1100, #936"
```

---

### Task 12: Hydration, whole-suite verification and issue closure

**Files:**
- Modify: `lib/features/gas_calculators/presentation/widgets/gas_blender_calculator.dart` (watch the preferences loader)
- Test: whole suite

- [ ] **Step 1: Hydrate the saved preferences on first build**

In `GasBlenderCalculator.build`, before returning the body:

```dart
    // Loads the saved templates, prices and conditions once. A first run has
    // no stored blob, which is what leaves the seeded templates in place.
    ref.watch(blenderPreferencesLoaderProvider);
```

The loader returns `void`, so no `AsyncValue` branching is needed; the state
providers already hold usable defaults while it resolves.

- [ ] **Step 2: Verify the whole gas calculator suite**

```bash
flutter test test/features/gas_calculators/
```

Expected: PASS, with no test skipped.

- [ ] **Step 3: Run the full suite twice**

One green run proves nothing in this repo: several known flakes are
timing-dependent. Run it twice and compare.

```bash
flutter test 2>&1 | tail -30
```

Then again:

```bash
flutter test 2>&1 | tail -30
```

Do not pipe into `grep`; the exit code becomes grep's. Do not run a second
`flutter test` concurrently with the first.

Known pre-existing flakes that are not this change: the recovery-code yo-yo
split, the security-settings recovery dialog, the zip temp-dir 50 ms delete,
the media share-helper temp bytes. A failure in `test/features/gas_calculators/`
or `test/features/settings/` is this change and must be fixed.

- [ ] **Step 4: Format and analyze the whole project**

```bash
dart format .
flutter analyze
```

Expected: `No issues found.` Infos are fatal in CI, so treat any info as a
failure.

- [ ] **Step 5: Verify the generated l10n is still in sync**

```bash
flutter gen-l10n
git status --porcelain lib/l10n/
```

Expected: no modified files. A dirty tree here means an ARB changed after the
last generate.

- [ ] **Step 6: Commit and open the pull request**

```bash
dart format .
git add -A
git commit -m "feat(blender): hydrate saved blender preferences on open"
git push -u origin worktree-issue-1100-trimix-blender
```

PR title: `feat(blender): trimix blender optimisation (#1100)`

PR body: summarise the six changes, name the four decisions from the spec, link
`docs/superpowers/specs/2026-08-20-trimix-blender-optimisation-design.md`, and
close with `Closes #1100`. Do **not** include a Claude Code attribution line or
a session URL.

- [ ] **Step 7: Ask the reporter to cross-check**

The reporter offered to compare results against other blending software. Post a
comment on #1100 naming the defaults (Z-factor model, both temperatures 20 C)
and the fact that ideal, van der Waals and Z-factor deliberately disagree, with
the 18/45 example figures from Task 2 so they have something concrete to compare
against.

---

## Self-review

**Spec coverage:**

| Spec section | Task |
| --- | --- |
| 1. Equation of state | 1 |
| 2. Blender solver changes | 2 |
| 3. Persisted preferences | 4 |
| 4. Provider restructuring | 5 |
| 5. Billing | 3 (domain), 11 (UI) |
| 6. User interface: cards | 7, 8, 9, 10, 11 |
| 6. Precision fixes | 7 |
| 6. Procedure output | 9 |
| 6. Temperature control | 8 |
| 6. Templates | 10 |
| 6. Localisation | 6 |
| 7. Testing | every task, plus 12 |
| 8. Out of scope | 6 (About copy names the EAN32 top-off) |

**Correction to the spec:** section 2 says the existing `gas_blender_test.dart`
must pass unmodified and that any change to it is a defect. That holds for the
expected values, which were verified numerically before this plan was written
(the table in Task 2 lists the old and new figures side by side, all inside the
existing tolerances). It does not hold for the file as a whole: Task 2 appends
two new groups and one import. The regression gate is the pre-existing groups
and their expected values, not the file's byte count.

**Type consistency check:** `BlendStep.addedBar` is introduced in Task 2 and
consumed by Tasks 3, 9 and 11 under that name.
`BlendResult.settledPressureBar` is introduced in Task 2 and consumed in Tasks
5 and 9. `BlendGasModel` is introduced in Task 1 and consumed in Tasks 2, 4, 5
and 8. `MixTemplate.label` is introduced in Task 4 and consumed in Task 10.
`saveBlenderPreferences(ref)` is introduced in Task 5 and consumed in Tasks 8,
10 and 11. `computeBlendCost` keeps the same three named parameters in Tasks 3,
5 and 11.
