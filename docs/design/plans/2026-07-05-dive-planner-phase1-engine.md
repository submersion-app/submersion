# Dive Planner Phase 1: Deco Engine Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Upgrade the shared deco engine in `lib/core/deco/` with environment-aware pressure (altitude/salinity), CCR constant-ppO2 tissue loading, a schedule policy (gas-switch stops, air breaks), a `DecoModel` interface for future VPM-B, compressibility-correct gas consumption, and a golden-vector validation suite.

**Architecture:** Evolve `BuhlmannAlgorithm` in place (new `DiveEnvironment` + `BreathingConfig` parameters, default values preserve current behavior exactly), then wrap it in a `BuhlmannGf implements DecoModel` facade. A Python reference implementation generates golden vectors that pin the engine's numerics independently of the Dart code.

**Tech Stack:** Pure Dart (no Flutter imports in `lib/core/deco/`), flutter_test, python3 (vector generation only).

**Spec:** `docs/superpowers/specs/2026-07-05-dive-planner-redesign-design.md`

## Global Constraints

- `lib/core/deco/` stays pure Dart: no Flutter imports (importing `lib/core/constants/enums.dart` is fine — it is pure Dart).
- All engine math is metric and internal: meters, bar, liters, seconds.
- **Behavior preservation:** `DiveEnvironment.standard` must reproduce today's numbers exactly (surface 1.0 bar, exactly 0.1 bar per meter). All 14 existing test files in `test/core/deco/` must pass UNCHANGED after every task. If one fails, the change is wrong — do not edit those tests.
- Golden/test vector numbers must be computed with `python3` at implementation time — never from memory/recall. Steps that say "compute with python3" mean run the command and paste the actual output into the test.
- Run `dart format .` (whole repo) before every commit; commits must also pass `flutter analyze` with no new issues (run without piping through `tail`/`head`).
- Run specific test files (`flutter test test/core/deco/<file>.dart`), not broad directories, to avoid Bash timeouts. `test/core/deco/` as a whole is pure Dart and fast — it is the one directory-level run allowed.
- Commit after each task (plan-approved work pre-authorizes these commits). No Co-Authored-By lines in commit messages.
- Schema/database: NO changes in this phase.

---

### Task 1: DiveEnvironment entity

**Files:**
- Create: `lib/core/deco/entities/dive_environment.dart`
- Test: `test/core/deco/dive_environment_test.dart`

**Interfaces:**
- Consumes: `AltitudeCalculator.calculateBarometricPressure(double)` from `lib/core/deco/altitude_calculator.dart`; `WaterType` enum from `lib/core/constants/enums.dart`.
- Produces: `DiveEnvironment` with `surfacePressureBar`, `waterDensityKgM3`, `barPerMeter`, `pressureAtDepth(double)`, `depthAtPressure(double)`, `DiveEnvironment.standard`, `DiveEnvironment.forConditions({double? altitudeMeters, WaterType? waterType, double? surfacePressureBar})`. Every later task depends on these exact names.

- [ ] **Step 1: Compute expected test values with python3**

Run:
```bash
python3 -c "
g = 9.80665
for name, rho in [('fresh', 1000.0), ('brackish', 1010.0), ('en13319', 1019.716213), ('salt', 1025.0)]:
    bpm = rho * g / 100000.0
    print(name, 'barPerMeter =', repr(bpm), ' P@30m =', repr(1.0 + 30.0 * bpm))
p0, L, exp = 1.01325, 0.0000225577, 5.25588
print('surface@2000m =', repr(p0 * (1 - L * 2000.0) ** exp))
"
```
Record the printed values; they go into the test below (replace the `closeTo` targets with the exact printed numbers — the values shown below are what python3 should print, verify they match).

- [ ] **Step 2: Write the failing test**

Create `test/core/deco/dive_environment_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/deco/entities/dive_environment.dart';

void main() {
  group('DiveEnvironment', () {
    test('standard reproduces legacy 1 bar surface and 10 m/bar exactly', () {
      const env = DiveEnvironment.standard;
      expect(env.surfacePressureBar, 1.0);
      expect(env.barPerMeter, closeTo(0.1, 1e-9));
      expect(env.pressureAtDepth(30.0), closeTo(4.0, 1e-7));
      expect(env.depthAtPressure(4.0), closeTo(30.0, 1e-6));
    });

    test('salt water is denser than standard', () {
      const env = DiveEnvironment(
        waterDensityKgM3: DiveEnvironment.saltWaterDensity,
      );
      // python3: 1025 * 9.80665 / 100000 = 0.1005181625
      expect(env.barPerMeter, closeTo(0.1005181625, 1e-9));
      expect(env.pressureAtDepth(30.0), closeTo(4.015544875, 1e-7));
    });

    test('fresh water is lighter than standard', () {
      const env = DiveEnvironment(
        waterDensityKgM3: DiveEnvironment.freshWaterDensity,
      );
      // python3: 1000 * 9.80665 / 100000 = 0.0980665
      expect(env.barPerMeter, closeTo(0.0980665, 1e-9));
      expect(env.pressureAtDepth(30.0), closeTo(3.941995, 1e-6));
    });

    test('forConditions with altitude uses barometric pressure', () {
      final env = DiveEnvironment.forConditions(altitudeMeters: 2000.0);
      // python3 ISA: 1.01325 * (1 - 0.0000225577*2000)^5.25588
      expect(env.surfacePressureBar, closeTo(0.7950, 0.001));
      expect(env.surfacePressureBar, lessThan(1.0));
    });

    test('forConditions maps water types to densities', () {
      expect(
        DiveEnvironment.forConditions(waterType: WaterType.fresh)
            .waterDensityKgM3,
        DiveEnvironment.freshWaterDensity,
      );
      expect(
        DiveEnvironment.forConditions(waterType: WaterType.salt)
            .waterDensityKgM3,
        DiveEnvironment.saltWaterDensity,
      );
      expect(
        DiveEnvironment.forConditions(waterType: WaterType.brackish)
            .waterDensityKgM3,
        DiveEnvironment.brackishWaterDensity,
      );
      expect(
        DiveEnvironment.forConditions().waterDensityKgM3,
        DiveEnvironment.en13319Density,
      );
    });

    test('forConditions: explicit surface pressure wins over altitude', () {
      final env = DiveEnvironment.forConditions(
        altitudeMeters: 2000.0,
        surfacePressureBar: 0.9,
      );
      expect(env.surfacePressureBar, 0.9);
    });

    test('forConditions: null altitude keeps legacy 1.0 bar', () {
      expect(
        DiveEnvironment.forConditions().surfacePressureBar,
        1.0,
      );
    });
  });
}
```

- [ ] **Step 3: Run test to verify it fails**

Run: `flutter test test/core/deco/dive_environment_test.dart`
Expected: FAIL — `dive_environment.dart` does not exist.

- [ ] **Step 4: Write the implementation**

Create `lib/core/deco/entities/dive_environment.dart`:

```dart
import 'package:equatable/equatable.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/deco/altitude_calculator.dart';

/// Physical environment for decompression calculations.
///
/// Replaces the engine's historical hardcoded assumptions (1.0 bar surface,
/// exactly 10 m of water per bar). [standard] reproduces those assumptions
/// exactly so existing behavior is preserved wherever no environment is
/// supplied.
class DiveEnvironment extends Equatable {
  /// Atmospheric pressure at the dive site surface, in bar.
  final double surfacePressureBar;

  /// Water density in kg/m3.
  final double waterDensityKgM3;

  const DiveEnvironment({
    this.surfacePressureBar = 1.0,
    this.waterDensityKgM3 = en13319Density,
  });

  /// Fresh water density (kg/m3).
  static const double freshWaterDensity = 1000.0;

  /// Brackish water density (kg/m3).
  static const double brackishWaterDensity = 1010.0;

  /// EN13319 dive-computer standard density: exactly 1 bar per 10 m.
  static const double en13319Density = 1019.716213;

  /// Sea water density (kg/m3).
  static const double saltWaterDensity = 1025.0;

  /// Legacy-equivalent default: 1.0 bar surface, exactly 10 m/bar.
  static const DiveEnvironment standard = DiveEnvironment();

  /// Build an environment from dive conditions.
  ///
  /// An explicit [surfacePressureBar] wins over [altitudeMeters]. A null
  /// altitude keeps the legacy 1.0 bar surface so dives without altitude
  /// data are unchanged.
  factory DiveEnvironment.forConditions({
    double? altitudeMeters,
    WaterType? waterType,
    double? surfacePressureBar,
  }) {
    final surface =
        surfacePressureBar ??
        (altitudeMeters != null
            ? AltitudeCalculator.calculateBarometricPressure(altitudeMeters)
            : 1.0);
    final density = switch (waterType) {
      WaterType.fresh => freshWaterDensity,
      WaterType.brackish => brackishWaterDensity,
      WaterType.salt => saltWaterDensity,
      null => en13319Density,
    };
    return DiveEnvironment(
      surfacePressureBar: surface,
      waterDensityKgM3: density,
    );
  }

  static const double _gravity = 9.80665;

  /// Pressure increase per meter of depth, in bar.
  double get barPerMeter => waterDensityKgM3 * _gravity / 100000.0;

  /// Absolute ambient pressure at [depthMeters], in bar.
  double pressureAtDepth(double depthMeters) =>
      surfacePressureBar + depthMeters * barPerMeter;

  /// Depth in meters at absolute [pressureBar].
  double depthAtPressure(double pressureBar) =>
      (pressureBar - surfacePressureBar) / barPerMeter;

  @override
  List<Object?> get props => [surfacePressureBar, waterDensityKgM3];
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/core/deco/dive_environment_test.dart`
Expected: PASS (all tests).

- [ ] **Step 6: Commit**

```bash
dart format .
git add lib/core/deco/entities/dive_environment.dart test/core/deco/dive_environment_test.dart
git commit -m "feat(deco): add DiveEnvironment for altitude and salinity aware pressure"
```

---

### Task 2: Pressure-space ceiling on TissueCompartment; env-aware SurfGF on DecoStatus

**Files:**
- Modify: `lib/core/deco/entities/tissue_compartment.dart` (ceiling method, ~line 103-116)
- Modify: `lib/core/deco/entities/deco_status.dart` (surfGf, constructor, copyWith, props)
- Test: `test/core/deco/tissue_compartment_env_test.dart`

**Interfaces:**
- Produces: `TissueCompartment.ceilingPressureBar({double gf})` returning absolute pressure in bar (no depth conversion — the algorithm converts via `DiveEnvironment`). `DecoStatus.surfacePressureBar` field (default 1.0) used by `surfGf`.
- The legacy `TissueCompartment.ceiling({gf})` keeps its exact current behavior (1 bar surface, 10 m/bar) for existing widget consumers.

- [ ] **Step 1: Write the failing test**

Create `test/core/deco/tissue_compartment_env_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/deco/constants/buhlmann_coefficients.dart';
import 'package:submersion/core/deco/entities/deco_status.dart';
import 'package:submersion/core/deco/entities/tissue_compartment.dart';

TissueCompartment _comp1({double pN2 = 2.5, double pHe = 0.0}) {
  return TissueCompartment(
    compartmentNumber: 1,
    halfTimeN2: zhl16cN2HalfTimes[0],
    halfTimeHe: zhl16cHeHalfTimes[0],
    mValueAN2: zhl16cN2A[0],
    mValueBN2: zhl16cN2B[0],
    mValueAHe: zhl16cHeA[0],
    mValueBHe: zhl16cHeB[0],
    currentPN2: pN2,
    currentPHe: pHe,
  );
}

void main() {
  test('ceilingPressureBar is the pressure form of the legacy ceiling', () {
    final comp = _comp1();
    // Legacy: meters = (pBar - 1.0) * 10.0, clamped at 0.
    final pBar = comp.ceilingPressureBar(gf: 0.8);
    final legacyMeters = comp.ceiling(gf: 0.8);
    expect(legacyMeters, closeTo(((pBar - 1.0) * 10.0).clamp(0, 999), 1e-9));
  });

  test('ceilingPressureBar can be below 1 bar (clean tissue)', () {
    final comp = _comp1(pN2: inspiredSurfaceN2Bar);
    expect(comp.ceilingPressureBar(gf: 1.0), lessThan(1.0));
    expect(comp.ceiling(gf: 1.0), 0.0); // legacy clamps to 0
  });

  test('DecoStatus.surfGf evaluates at its surfacePressureBar', () {
    final comp = _comp1(pN2: 2.5);
    final atSeaLevel = DecoStatus(
      compartments: [comp],
      ndlSeconds: -1,
      ceilingMeters: 5,
      ttsSeconds: 600,
      gfLow: 0.3,
      gfHigh: 0.7,
      decoStops: const [],
      currentDepthMeters: 10,
      ambientPressureBar: 2.0,
    );
    final atAltitude = atSeaLevel.copyWith(surfacePressureBar: 0.795);
    // Lower surface pressure -> bigger supersaturation gradient at surface.
    expect(atAltitude.surfGf, greaterThan(atSeaLevel.surfGf));
    // Default (1.0 bar) matches the legacy surfaceGradientFactor path.
    expect(
      atSeaLevel.surfGf,
      closeTo((comp.surfaceGradientFactor * 100.0).clamp(0.0, 9999), 1e-9),
    );
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/deco/tissue_compartment_env_test.dart`
Expected: FAIL — `ceilingPressureBar` and `surfacePressureBar` are not defined.

- [ ] **Step 3: Implement**

In `lib/core/deco/entities/tissue_compartment.dart`, replace the existing `ceiling` method (lines 103-116) with:

```dart
  /// Ceiling as an absolute ambient pressure in bar for this compartment,
  /// with gradient factor [gf] applied. Depth conversion is the caller's
  /// job (via DiveEnvironment) so this stays environment-agnostic.
  double ceilingPressureBar({double gf = 1.0}) {
    final a = blendedA;
    final b = blendedB;
    return (totalInertGas - a * gf) / (gf / b + 1 - gf);
  }

  /// Calculate ceiling (minimum safe depth) in meters for this compartment
  /// using gradient factor to add conservatism.
  ///
  /// LEGACY: assumes 1.0 bar surface and 10 m/bar. The Buhlmann engine now
  /// converts [ceilingPressureBar] through its DiveEnvironment instead;
  /// this remains for display widgets that predate environments.
  double ceiling({double gf = 1.0}) {
    final ceilingMeters = (ceilingPressureBar(gf: gf) - 1.0) * 10.0;
    return ceilingMeters < 0 ? 0 : ceilingMeters;
  }
```

In `lib/core/deco/entities/deco_status.dart`:

1. Add the field after `ambientPressureBar` (line 43):

```dart
  /// Surface pressure in bar used for surface-referenced metrics (SurfGF).
  final double surfacePressureBar;
```

2. Add to the constructor (after `required this.ambientPressureBar,`):

```dart
    this.surfacePressureBar = 1.0,
```

3. Replace the `surfGf` getter body's use of `comp.surfaceGradientFactor`:

```dart
  double get surfGf {
    if (compartments.isEmpty) return 0.0;
    double maxGf = double.negativeInfinity;
    for (final comp in compartments) {
      final gf = comp.gradientFactor(surfacePressureBar);
      if (gf > maxGf) maxGf = gf;
    }
    // Clamp at 0: negative SurfGF means all tissues are below surface
    // equilibrium, which is not meaningful to display.
    return (maxGf * 100.0).clamp(0.0, double.infinity);
  }
```

4. Add `surfacePressureBar` to `copyWith` (parameter `double? surfacePressureBar` and `surfacePressureBar: surfacePressureBar ?? this.surfacePressureBar`) and to the `props` list.

Note: `comp.gradientFactor(1.0)` equals `comp.surfaceGradientFactor` by construction, so the default is behavior-identical.

- [ ] **Step 4: Run tests**

Run: `flutter test test/core/deco/tissue_compartment_env_test.dart test/core/deco/tissue_compartment_gf_test.dart test/core/deco/deco_status_gf_test.dart`
Expected: PASS (new and existing).

- [ ] **Step 5: Commit**

```bash
dart format .
git add lib/core/deco/entities/tissue_compartment.dart lib/core/deco/entities/deco_status.dart test/core/deco/tissue_compartment_env_test.dart
git commit -m "feat(deco): pressure-space compartment ceiling and env-aware SurfGF"
```

---

### Task 3: Thread DiveEnvironment through BuhlmannAlgorithm

**Files:**
- Modify: `lib/core/deco/buhlmann_algorithm.dart`
- Test: `test/core/deco/buhlmann_environment_test.dart`

**Interfaces:**
- Consumes: `DiveEnvironment` (Task 1), `ceilingPressureBar` (Task 2).
- Produces: `BuhlmannAlgorithm({..., DiveEnvironment environment = DiveEnvironment.standard})`; `algorithm.environment`; `algorithm.restoreState(List<TissueCompartment> compartments, {double gfLowCeilingAnchor = 0.0})`; `double get gfLowCeilingAnchor`. Tasks 5, 7, 9, 11 rely on these exact names.

- [ ] **Step 1: Write the failing test**

Create `test/core/deco/buhlmann_environment_test.dart`:

```dart
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/deco/buhlmann_environment_test.dart`
Expected: FAIL — no `environment` parameter, no `restoreState`, no `gfLowCeilingAnchor` getter.

- [ ] **Step 3: Implement in `lib/core/deco/buhlmann_algorithm.dart`**

1. Add import:

```dart
import 'package:submersion/core/deco/entities/dive_environment.dart';
```

2. Add field and constructor parameter; make the initial compartments environment-aware:

```dart
  /// Physical environment (surface pressure, water density).
  final DiveEnvironment environment;

  BuhlmannAlgorithm({
    this.gfLow = 0.30,
    this.gfHigh = 0.70,
    this.lastStopDepth = 3.0,
    this.stopIncrement = 3.0,
    this.ascentRate = 9.0,
    this.environment = DiveEnvironment.standard,
  }) : _compartments = _createSurfaceSaturatedCompartments(environment);
```

3. Change `_createSurfaceSaturatedCompartments` to take the environment:

```dart
  static List<TissueCompartment> _createSurfaceSaturatedCompartments(
    DiveEnvironment environment,
  ) {
    final compartments = <TissueCompartment>[];

    // Surface N2 tension = inspired N2 at the site's surface pressure.
    final surfaceN2 = calculateInspiredN2(
      environment.surfacePressureBar,
      airN2Fraction,
    );
    // ... rest identical, using surfaceN2 as before ...
```

Update `reset()` to call `_createSurfaceSaturatedCompartments(environment)`.

4. Add a single ceiling-conversion helper and use it in the three ceiling scans (`_updateGfAnchor`, `calculateCeiling`, `_calculateSurfaceTargetCeiling`), replacing every `comp.ceiling(gf: ...)` call inside this class:

```dart
  /// Compartment ceiling in meters under this algorithm's environment.
  double _ceilingMetersFor(TissueCompartment comp, double gf) {
    final meters = environment.depthAtPressure(
      comp.ceilingPressureBar(gf: gf),
    );
    return meters < 0 ? 0 : meters;
  }
```

Example — `_updateGfAnchor` becomes:

```dart
  void _updateGfAnchor() {
    double ceiling = 0;
    for (final comp in _compartments) {
      final c = _ceilingMetersFor(comp, gfLow);
      if (c > ceiling) ceiling = c;
    }
    if (ceiling > _gfLowCeilingAnchor) _gfLowCeilingAnchor = ceiling;
  }
```

Apply the same substitution in `calculateCeiling` (with the interpolated `gf`) and `_calculateSurfaceTargetCeiling` (with `gfHigh`).

5. In `calculateSegment`, replace the ambient-pressure line:

```dart
    final ambientPressure = environment.pressureAtDepth(depthMeters);
```

6. In `getDecoStatus`, replace the `ambientPressureBar` argument and pass the surface pressure:

```dart
      currentDepthMeters: currentDepth,
      ambientPressureBar: environment.pressureAtDepth(currentDepth),
      surfacePressureBar: environment.surfacePressureBar,
```

7. Add the state accessors after `setCompartments`:

```dart
  /// Deepest GF-low ceiling reached so far this dive (meters).
  double get gfLowCeilingAnchor => _gfLowCeilingAnchor;

  /// Restore a previously captured tissue state (compartments + GF anchor).
  /// Unlike [setCompartments], this does NOT re-derive the anchor: pass the
  /// anchor captured alongside the compartments so mid-dive state (e.g. the
  /// DecoModel facade) round-trips exactly.
  void restoreState(
    List<TissueCompartment> compartments, {
    double gfLowCeilingAnchor = 0.0,
  }) {
    if (compartments.length == zhl16CompartmentCount) {
      _compartments = List.from(compartments);
      _gfLowCeilingAnchor = gfLowCeilingAnchor;
    }
  }
```

- [ ] **Step 4: Run the new test AND the full existing deco suite**

Run: `flutter test test/core/deco/`
Expected: ALL PASS. The existing 14 files must pass unchanged (standard environment is numerically identical: surface 1.0 bar, 0.1 bar/m to within 1e-9).

- [ ] **Step 5: Commit**

```bash
dart format .
git add lib/core/deco/buhlmann_algorithm.dart test/core/deco/buhlmann_environment_test.dart
git commit -m "feat(deco): thread DiveEnvironment through the Buhlmann engine"
```

---

### Task 4: BreathingConfig (open circuit, CCR constant-ppO2, SCR)

**Files:**
- Create: `lib/core/deco/entities/breathing_config.dart`
- Test: `test/core/deco/breathing_config_test.dart`

**Interfaces:**
- Consumes: `waterVaporPressure` constant from `buhlmann_coefficients.dart`; `ScrCalculator.calculateCmfSteadyStateFo2` from `scr_calculator.dart`.
- Produces: `InspiredGas{pN2, pHe, pO2}`; `sealed class BreathingConfig` with `InspiredGas inspiredAt(double ambientPressureBar)`; `OpenCircuit({required double fO2, double fHe})`; `ClosedCircuit({required double setpoint, required double diluentFO2, double diluentFHe})`; `Scr({required double supplyFO2, double supplyFHe, required double injectionRateLpm, double vo2})`. Tasks 5, 7, 9 use these exact constructors.

- [ ] **Step 1: Compute CCR expected values with python3**

Run:
```bash
python3 -c "
wv = 0.0627
amb = 5.0                      # 40 m in standard env
p_alv = amb - wv
sp = 1.3
p_inert = p_alv - sp
f_n2, f_he = 0.37, 0.45        # Tx 18/45 diluent
share_n2 = f_n2 / (f_n2 + f_he)
print('pN2 =', repr(p_inert * share_n2))
print('pHe =', repr(p_inert * (1 - share_n2)))
# shallow clamp: 3 m, amb 1.3, setpoint 1.3 > p_alv
amb2 = 1.3
p_alv2 = amb2 - wv
print('shallow pO2 =', repr(min(1.3, p_alv2)), 'inert =', repr(max(p_alv2 - min(1.3, p_alv2), 0.0)))
# OC air at 30 m
print('oc pN2 @30m =', repr((4.0 - wv) * 0.7902))
"
```
Paste the exact printed values into the test expectations below (verify the ones shown match).

- [ ] **Step 2: Write the failing test**

Create `test/core/deco/breathing_config_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/deco/constants/buhlmann_coefficients.dart';
import 'package:submersion/core/deco/entities/breathing_config.dart';

void main() {
  group('OpenCircuit', () {
    test('matches the legacy inspired-gas helpers', () {
      const oc = OpenCircuit(fO2: 0.2098, fHe: 0.0);
      final inspired = oc.inspiredAt(4.0); // 30 m standard
      // python3: (4.0 - 0.0627) * 0.7902 = 3.11122446
      expect(inspired.pN2, closeTo(calculateInspiredN2(4.0, oc.fN2), 1e-12));
      expect(inspired.pN2, closeTo(3.11122446, 1e-6));
      expect(inspired.pHe, 0.0);
    });

    test('trimix splits inert pressures by fraction', () {
      const oc = OpenCircuit(fO2: 0.18, fHe: 0.45);
      final inspired = oc.inspiredAt(7.0); // 60 m standard
      expect(inspired.pHe, closeTo((7.0 - waterVaporPressure) * 0.45, 1e-12));
      expect(inspired.pN2, closeTo((7.0 - waterVaporPressure) * 0.37, 1e-12));
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
      // python3 values from Step 1:
      expect(inspired.pN2, closeTo(1.641243902439024, 1e-9));
      expect(inspired.pHe, closeTo(1.996056097560976, 1e-9));
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
      final ambient = 5.0;
      final ccrInert =
          ccr.inspiredAt(ambient).pN2 + ccr.inspiredAt(ambient).pHe;
      final ocInert = oc.inspiredAt(ambient).pN2 + oc.inspiredAt(ambient).pHe;
      expect(ccrInert, lessThan(ocInert));
    });
  });

  group('Scr', () {
    test('steady-state loop is leaner than the supply gas', () {
      final scr = Scr(
        supplyFO2: 0.32,
        injectionRateLpm: 10.0,
        vo2: 1.3,
      );
      final inspired = scr.inspiredAt(3.0); // 20 m standard
      final supply = const OpenCircuit(fO2: 0.32).inspiredAt(3.0);
      expect(inspired.pO2, lessThan(supply.pO2));
      expect(inspired.pN2, greaterThan(supply.pN2));
    });

    test('preserves the supply He:N2 ratio in the loop', () {
      final scr = Scr(
        supplyFO2: 0.30,
        supplyFHe: 0.30,
        injectionRateLpm: 10.0,
      );
      final inspired = scr.inspiredAt(4.0);
      // Supply inert split is 30 He / 40 N2 -> He share 0.4285714...
      expect(
        inspired.pHe / (inspired.pHe + inspired.pN2),
        closeTo(0.30 / 0.70, 1e-9),
      );
    });
  });
}
```

- [ ] **Step 3: Run test to verify it fails**

Run: `flutter test test/core/deco/breathing_config_test.dart`
Expected: FAIL — file does not exist.

- [ ] **Step 4: Write the implementation**

Create `lib/core/deco/entities/breathing_config.dart`:

```dart
import 'dart:math' as math;

import 'package:submersion/core/deco/constants/buhlmann_coefficients.dart';
import 'package:submersion/core/deco/scr_calculator.dart';

/// Partial pressures of the inspired gas at some ambient pressure.
class InspiredGas {
  const InspiredGas({
    required this.pN2,
    required this.pHe,
    required this.pO2,
  });

  final double pN2;
  final double pHe;
  final double pO2;
}

/// What the diver is breathing, independent of depth.
///
/// The engine asks a BreathingConfig for inspired partial pressures at an
/// ambient pressure; open circuit, constant-ppO2 CCR, and steady-state SCR
/// answer differently. All account for alveolar water vapor.
sealed class BreathingConfig {
  const BreathingConfig();

  /// Inspired partial pressures at [ambientPressureBar].
  InspiredGas inspiredAt(double ambientPressureBar);
}

/// Open circuit: fixed gas fractions at ambient pressure.
class OpenCircuit extends BreathingConfig {
  const OpenCircuit({required this.fO2, this.fHe = 0.0});

  final double fO2;
  final double fHe;

  double get fN2 => 1.0 - fO2 - fHe;

  @override
  InspiredGas inspiredAt(double ambientPressureBar) {
    final pAlv = math.max(ambientPressureBar - waterVaporPressure, 0.0);
    return InspiredGas(pN2: pAlv * fN2, pHe: pAlv * fHe, pO2: pAlv * fO2);
  }
}

/// Closed-circuit rebreather at a constant ppO2 setpoint.
///
/// Inspired inert pressure is what remains of the alveolar pressure after
/// the setpoint's O2, split by the diluent's N2:He ratio. Shallower than
/// the setpoint the loop is effectively pure O2 (the O2 pressure is capped
/// by the available alveolar pressure).
class ClosedCircuit extends BreathingConfig {
  const ClosedCircuit({
    required this.setpoint,
    required this.diluentFO2,
    this.diluentFHe = 0.0,
  });

  final double setpoint;
  final double diluentFO2;
  final double diluentFHe;

  double get diluentFN2 => 1.0 - diluentFO2 - diluentFHe;

  @override
  InspiredGas inspiredAt(double ambientPressureBar) {
    final pAlv = math.max(ambientPressureBar - waterVaporPressure, 0.0);
    final pO2 = math.min(setpoint, pAlv);
    final pInert = math.max(pAlv - pO2, 0.0);
    final inertFraction = diluentFN2 + diluentFHe;
    if (inertFraction <= 0) {
      return InspiredGas(pN2: 0, pHe: 0, pO2: pAlv);
    }
    final n2Share = diluentFN2 / inertFraction;
    return InspiredGas(
      pN2: pInert * n2Share,
      pHe: pInert * (1.0 - n2Share),
      pO2: pO2,
    );
  }
}

/// CMF semi-closed rebreather at steady state.
///
/// The loop behaves like open circuit on the steady-state loop mix derived
/// from the supply gas via [ScrCalculator.calculateCmfSteadyStateFo2]. The
/// supply's He:N2 ratio is preserved in the loop (metabolism only removes
/// O2). If the flow is insufficient (hypoxic), the supply mix is used and
/// callers surface that as a warning.
class Scr extends BreathingConfig {
  Scr({
    required this.supplyFO2,
    this.supplyFHe = 0.0,
    required this.injectionRateLpm,
    this.vo2 = ScrCalculator.defaultVo2,
  }) : _loop = _steadyStateLoop(supplyFO2, supplyFHe, injectionRateLpm, vo2);

  final double supplyFO2;
  final double supplyFHe;
  final double injectionRateLpm;
  final double vo2;
  final OpenCircuit _loop;

  static OpenCircuit _steadyStateLoop(
    double supplyFO2,
    double supplyFHe,
    double injectionRateLpm,
    double vo2,
  ) {
    final loopFO2 =
        ScrCalculator.calculateCmfSteadyStateFo2(
          injectionRateLpm: injectionRateLpm,
          supplyO2Percent: supplyFO2 * 100.0,
          vo2: vo2,
        ) ??
        supplyFO2;
    final supplyInert = 1.0 - supplyFO2;
    final heShare = supplyInert > 0 ? supplyFHe / supplyInert : 0.0;
    final loopInert = 1.0 - loopFO2;
    return OpenCircuit(fO2: loopFO2, fHe: loopInert * heShare);
  }

  @override
  InspiredGas inspiredAt(double ambientPressureBar) =>
      _loop.inspiredAt(ambientPressureBar);
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/core/deco/breathing_config_test.dart`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
dart format .
git add lib/core/deco/entities/breathing_config.dart test/core/deco/breathing_config_test.dart
git commit -m "feat(deco): BreathingConfig with OC, constant-ppO2 CCR, and SCR modes"
```

---

### Task 5: CCR tissue loading in the engine and profile processing

**Files:**
- Modify: `lib/core/deco/buhlmann_algorithm.dart` (`calculateSegment`, `calculateNdl`, `getDecoStatus`, `processProfileWithGasSegments`)
- Modify: `lib/core/deco/entities/profile_gas_segment.dart` (add `setpoint`)
- Test: `test/core/deco/buhlmann_ccr_test.dart`

**Interfaces:**
- Consumes: `BreathingConfig` (Task 4), environment threading (Task 3).
- Produces: `calculateSegment({..., BreathingConfig? breathing})`, `calculateNdl({..., BreathingConfig? breathing})`, `getDecoStatus({..., BreathingConfig? breathing})`, `ProfileGasSegment.setpoint` (`double?`, null = OC). Task 7 and 9 rely on the `breathing` parameter name; Task 11 relies on `ProfileGasSegment.setpoint`.
- Documented limitation (Phase 4 removes it): the deco SCHEDULE/TTS still breathes open-circuit via `AscentGasPlan` even when loading ran CCR — matching current behavior where ascent planning is OC.

- [ ] **Step 1: Read `lib/core/deco/entities/profile_gas_segment.dart`** to confirm its exact current shape (a small entity with `startTimestamp`, `fN2`, `fHe`), then add a nullable setpoint field, constructor parameter, and (if it is Equatable) props entry:

```dart
  /// CCR setpoint in bar for this segment; null means open circuit.
  final double? setpoint;
```

- [ ] **Step 2: Write the failing test**

Create `test/core/deco/buhlmann_ccr_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/deco/buhlmann_algorithm.dart';
import 'package:submersion/core/deco/entities/breathing_config.dart';
import 'package:submersion/core/deco/entities/profile_gas_segment.dart';

void main() {
  group('CCR tissue loading', () {
    test('CCR at setpoint loads less inert gas than OC diluent at 40 m', () {
      final oc = BuhlmannAlgorithm(gfLow: 0.5, gfHigh: 0.8);
      final ccr = BuhlmannAlgorithm(gfLow: 0.5, gfHigh: 0.8);

      oc.calculateSegment(
        depthMeters: 40,
        durationSeconds: 20 * 60,
        fN2: 0.37,
        fHe: 0.45,
      );
      ccr.calculateSegment(
        depthMeters: 40,
        durationSeconds: 20 * 60,
        breathing: const ClosedCircuit(
          setpoint: 1.3,
          diluentFO2: 0.18,
          diluentFHe: 0.45,
        ),
      );

      final ocInert = oc.compartments
          .map((c) => c.totalInertGas)
          .reduce((a, b) => a + b);
      final ccrInert = ccr.compartments
          .map((c) => c.totalInertGas)
          .reduce((a, b) => a + b);
      expect(ccrInert, lessThan(ocInert));
    });

    test('CCR NDL at setpoint is longer than OC NDL on the diluent', () {
      final algo = BuhlmannAlgorithm(gfLow: 0.5, gfHigh: 0.8);
      final ndlOc = algo.calculateNdl(
        depthMeters: 30,
        fN2: 0.7902,
        fHe: 0.0,
      );
      final ndlCcr = algo.calculateNdl(
        depthMeters: 30,
        breathing: const ClosedCircuit(setpoint: 1.3, diluentFO2: 0.21),
      );
      expect(ndlCcr, greaterThan(ndlOc));
    });

    test('breathing parameter takes precedence over fN2/fHe', () {
      final a = BuhlmannAlgorithm();
      final b = BuhlmannAlgorithm();
      a.calculateSegment(
        depthMeters: 30,
        durationSeconds: 600,
        fN2: 0.5,
        fHe: 0.4,
        breathing: const OpenCircuit(fO2: 0.2098),
      );
      b.calculateSegment(
        depthMeters: 30,
        durationSeconds: 600,
        fN2: 0.7902,
        fHe: 0.0,
      );
      expect(a.compartments, b.compartments);
    });

    test('processProfileWithGasSegments honors segment setpoints', () {
      final depths = [0.0, 30.0, 30.0, 30.0, 0.0];
      final times = [0, 120, 600, 1200, 1500];

      final ocStatuses = BuhlmannAlgorithm(gfLow: 0.5, gfHigh: 0.8)
          .processProfileWithGasSegments(
        depths: depths,
        timestamps: times,
        gasSegments: [
          ProfileGasSegment(startTimestamp: 0, fN2: 0.7902, fHe: 0.0),
        ],
      );
      final ccrStatuses = BuhlmannAlgorithm(gfLow: 0.5, gfHigh: 0.8)
          .processProfileWithGasSegments(
        depths: depths,
        timestamps: times,
        gasSegments: [
          ProfileGasSegment(
            startTimestamp: 0,
            fN2: 0.7902,
            fHe: 0.0,
            setpoint: 1.3,
          ),
        ],
      );

      // At the last bottom sample the CCR diver has less N2 loaded.
      final ocN2 = ocStatuses[3].compartments.first.currentPN2;
      final ccrN2 = ccrStatuses[3].compartments.first.currentPN2;
      expect(ccrN2, lessThan(ocN2));
    });
  });
}
```

- [ ] **Step 3: Run test to verify it fails**

Run: `flutter test test/core/deco/buhlmann_ccr_test.dart`
Expected: FAIL — no `breathing` parameter, no `setpoint` field.

- [ ] **Step 4: Implement**

In `buhlmann_algorithm.dart`:

1. Import `breathing_config.dart`.
2. `calculateSegment` gains `BreathingConfig? breathing`; the inspired-pressure block becomes:

```dart
  void calculateSegment({
    required double depthMeters,
    required int durationSeconds,
    double fN2 = airN2Fraction,
    double fHe = 0.0,
    BreathingConfig? breathing,
  }) {
    final ambientPressure = environment.pressureAtDepth(depthMeters);
    final double inspiredN2;
    final double inspiredHe;
    if (breathing != null) {
      final inspired = breathing.inspiredAt(ambientPressure);
      inspiredN2 = inspired.pN2;
      inspiredHe = inspired.pHe;
    } else {
      inspiredN2 = calculateInspiredN2(ambientPressure, fN2);
      inspiredHe = calculateInspiredHe(ambientPressure, fHe);
    }
    final durationMinutes = durationSeconds / 60.0;
    // ... rest of the method unchanged ...
```

3. `calculateNdl` gains `BreathingConfig? breathing` and forwards it to its internal `calculateSegment` simulation call.
4. `getDecoStatus` gains `BreathingConfig? breathing` and forwards it to `calculateNdl`. (Ceiling/schedule stay as they are: schedule ascent is OC via `AscentGasPlan` — documented Phase 1 limitation.)
5. In `processProfileWithGasSegments`, where the active gas drives loading (the `calculateSegment` call around line 663) and the status (around line 682), build the breathing config from the segment:

```dart
          final gas = _activeGasAtTimestamp(subIntervalStart, gasSegments);
          final breathing = gas.setpoint != null
              ? ClosedCircuit(
                  setpoint: gas.setpoint!,
                  diluentFO2: 1.0 - gas.fN2 - gas.fHe,
                  diluentFHe: gas.fHe,
                )
              : null;

          calculateSegment(
            depthMeters: avgDepth,
            durationSeconds: duration,
            fN2: gas.fN2,
            fHe: gas.fHe,
            breathing: breathing,
          );
```

and for the per-sample status, pass the same construction as `breathing:` to `getDecoStatus`.

- [ ] **Step 5: Run the new test AND the full deco suite**

Run: `flutter test test/core/deco/`
Expected: ALL PASS (no `setpoint` on existing call sites means null means OC — behavior unchanged).

- [ ] **Step 6: Commit**

```bash
dart format .
git add lib/core/deco/buhlmann_algorithm.dart lib/core/deco/entities/profile_gas_segment.dart test/core/deco/buhlmann_ccr_test.dart
git commit -m "feat(deco): constant-ppO2 CCR tissue loading"
```

---

### Task 6: SchedulePolicy — gas-switch stop time and O2 air breaks

**Files:**
- Create: `lib/core/deco/schedule_policy.dart`
- Modify: `lib/core/deco/buhlmann_algorithm.dart` (`calculateDecoSchedule`, `_calculateStopTime`, `_simulateAscent`, `_ascendLeg`, `calculateTts`)
- Modify: `lib/core/deco/entities/deco_status.dart` (`DecoStop.airBreakSeconds`)
- Modify: `lib/core/deco/ascent/ascent_gas_plan.dart` (`breakGasForDepth`)
- Test: `test/core/deco/schedule_policy_test.dart`

**Interfaces:**
- Produces: `SchedulePolicy({double stopIncrement = 3.0, double lastStopDepth = 3.0, double ascentRate = 9.0, int gasSwitchStopSeconds = 0, AirBreakPolicy? airBreaks})`; `AirBreakPolicy({int o2Seconds = 1200, int breakSeconds = 300})`; `DecoStop.airBreakSeconds` (int, default 0, INCLUDED in `durationSeconds`); `AscentGasPlan.breakGasForDepth(double)` returning `AscentGas?` (base returns null; `OptimalOcAscentGas` returns the best eligible gas with fO2 < 0.9, or null).
- `calculateDecoSchedule`, `calculateTts`, `getDecoStatus` gain `SchedulePolicy? policy`; null builds one from the algorithm's legacy fields (`stopIncrement`, `lastStopDepth`, `ascentRate`) — existing callers unchanged.

- [ ] **Step 1: Write the failing test**

Create `test/core/deco/schedule_policy_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/deco/ascent/ascent_gas_plan.dart';
import 'package:submersion/core/deco/buhlmann_algorithm.dart';
import 'package:submersion/core/deco/schedule_policy.dart';

/// Loads a deco-obligated dive: air, 45 m for 25 min.
BuhlmannAlgorithm _loadedAlgo() {
  final algo = BuhlmannAlgorithm(gfLow: 0.4, gfHigh: 0.8);
  algo.calculateSegment(depthMeters: 45, durationSeconds: 25 * 60);
  return algo;
}

AscentGasPlan _airPlusO2() => OptimalOcAscentGas(
      maxPpO2: 1.6,
      gases: const [
        AvailableGas(fN2: 0.7902, fHe: 0.0, maxPpO2Mod: 66.0),
        AvailableGas(fN2: 0.0, fHe: 0.0, maxPpO2Mod: 6.0), // pure O2
      ],
    );

void main() {
  test('null policy reproduces legacy schedule exactly', () {
    final a = _loadedAlgo();
    final b = _loadedAlgo();
    final legacy = a.calculateDecoSchedule(currentDepth: 45);
    final viaPolicy = b.calculateDecoSchedule(
      currentDepth: 45,
      policy: const SchedulePolicy(),
    );
    expect(viaPolicy.length, legacy.length);
    for (int i = 0; i < legacy.length; i++) {
      expect(viaPolicy[i].depthMeters, legacy[i].depthMeters);
      expect(viaPolicy[i].durationSeconds, legacy[i].durationSeconds);
    }
  });

  test('last stop at 6 m removes the 3 m stop', () {
    final algo = _loadedAlgo();
    final stops = algo.calculateDecoSchedule(
      currentDepth: 45,
      policy: const SchedulePolicy(lastStopDepth: 6.0),
    );
    expect(stops.every((s) => s.depthMeters >= 6.0), isTrue);
    expect(stops.last.depthMeters, 6.0);
  });

  test('gas-switch stop time enforces a minimum stop at the switch', () {
    final algo = _loadedAlgo();
    final plan = _airPlusO2();
    final stops = algo.calculateDecoSchedule(
      currentDepth: 45,
      ascentGas: plan,
      policy: const SchedulePolicy(gasSwitchStopSeconds: 120),
    );
    // The first stop at or above 6 m (the O2 switch) lasts >= 120 s.
    final switchStop = stops.firstWhere((s) => s.depthMeters <= 6.0);
    expect(switchStop.durationSeconds, greaterThanOrEqualTo(120));
  });

  test('air breaks lengthen O2 stops and are annotated', () {
    int totalDeco(SchedulePolicy policy) {
      final algo = BuhlmannAlgorithm(gfLow: 0.4, gfHigh: 0.8);
      algo.calculateSegment(depthMeters: 45, durationSeconds: 45 * 60);
      final stops = algo.calculateDecoSchedule(
        currentDepth: 45,
        ascentGas: _airPlusO2(),
        policy: policy,
      );
      return stops.fold(0, (sum, s) => sum + s.durationSeconds);
    }

    const withBreaks = SchedulePolicy(
      airBreaks: AirBreakPolicy(o2Seconds: 12 * 60, breakSeconds: 6 * 60),
    );
    final baseline = totalDeco(const SchedulePolicy());
    final broken = totalDeco(withBreaks);
    // Breathing back gas during breaks off-gasses slower -> longer deco.
    expect(broken, greaterThan(baseline));

    final algo = BuhlmannAlgorithm(gfLow: 0.4, gfHigh: 0.8);
    algo.calculateSegment(depthMeters: 45, durationSeconds: 45 * 60);
    final stops = algo.calculateDecoSchedule(
      currentDepth: 45,
      ascentGas: _airPlusO2(),
      policy: withBreaks,
    );
    final o2Stop = stops.firstWhere((s) => s.depthMeters <= 6.0);
    expect(o2Stop.airBreakSeconds, greaterThan(0));
    expect(o2Stop.airBreakSeconds, lessThan(o2Stop.durationSeconds));
  });

  test('breakGasForDepth: OptimalOcAscentGas offers a non-O2 gas', () {
    final plan = _airPlusO2();
    final atSix = plan.breakGasForDepth(6.0);
    expect(atSix, isNotNull);
    expect(atSix!.fN2, closeTo(0.7902, 1e-9));
    // FixedAscentGas has no alternative gas.
    expect(FixedAscentGas(fN2: 0.7902).breakGasForDepth(6.0), isNull);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/deco/schedule_policy_test.dart`
Expected: FAIL — `schedule_policy.dart` does not exist.

- [ ] **Step 3: Create `lib/core/deco/schedule_policy.dart`**

```dart
/// Air-break policy for long oxygen stops: after [o2Seconds] on a pure-O2
/// stop gas, breathe the break gas for [breakSeconds], then repeat.
class AirBreakPolicy {
  const AirBreakPolicy({this.o2Seconds = 20 * 60, this.breakSeconds = 5 * 60});

  final int o2Seconds;
  final int breakSeconds;
}

/// How a decompression schedule is generated, independent of the tissue
/// model. Defaults reproduce the engine's legacy behavior.
class SchedulePolicy {
  const SchedulePolicy({
    this.stopIncrement = 3.0,
    this.lastStopDepth = 3.0,
    this.ascentRate = 9.0,
    this.gasSwitchStopSeconds = 0,
    this.airBreaks,
  });

  /// Deco stop depth increment in meters.
  final double stopIncrement;

  /// Shallowest deco stop depth in meters (3 or 6).
  final double lastStopDepth;

  /// Ascent rate in meters per minute.
  final double ascentRate;

  /// Minimum time in seconds to hold at a stop where the breathed gas
  /// changes (0 = no minimum).
  final int gasSwitchStopSeconds;

  /// Optional O2 air-break policy; null = no air breaks.
  final AirBreakPolicy? airBreaks;
}
```

- [ ] **Step 4: Add `breakGasForDepth` to `lib/core/deco/ascent/ascent_gas_plan.dart`**

On the abstract class:

```dart
  /// Best gas to breathe during an air break at [depthMeters] — the highest
  /// O2 eligible gas that is NOT effectively pure O2. Null when the plan has
  /// no such alternative (no air breaks possible).
  AscentGas? breakGasForDepth(double depthMeters) => null;
```

(Change `abstract class AscentGasPlan` members accordingly — this one has a default body, so `FixedAscentGas` needs no change.)

On `OptimalOcAscentGas`, override:

```dart
  @override
  AscentGas? breakGasForDepth(double depthMeters) {
    AvailableGas? best;
    for (final g in _gases) {
      if (g.fO2 >= 0.9) continue; // skip O2 itself
      if (depthMeters <= g.maxPpO2Mod + 1e-9) {
        if (best == null || _prefer(g, best)) best = g;
      }
    }
    if (best == null) return null;
    return AscentGas(fN2: best.fN2, fHe: best.fHe);
  }
```

- [ ] **Step 5: Add `airBreakSeconds` to `DecoStop` in `deco_status.dart`**

```dart
  /// Seconds of this stop spent on the break gas (air breaks). Included in
  /// [durationSeconds]. Zero when no air breaks occurred.
  final int airBreakSeconds;
```

Add `this.airBreakSeconds = 0,` to the constructor and `airBreakSeconds` to `props`.

- [ ] **Step 6: Rework `calculateDecoSchedule` and `_calculateStopTime` in `buhlmann_algorithm.dart`**

Import `schedule_policy.dart`. Signature changes:

```dart
  List<DecoStop> calculateDecoSchedule({
    required double currentDepth,
    double fN2 = airN2Fraction,
    double fHe = 0.0,
    AscentGasPlan? ascentGas,
    SchedulePolicy? policy,
  }) {
    final p =
        policy ??
        SchedulePolicy(
          stopIncrement: stopIncrement,
          lastStopDepth: lastStopDepth,
          ascentRate: ascentRate,
        );
```

Inside, replace every use of `stopIncrement`/`lastStopDepth`/`ascentRate` with `p.stopIncrement`/`p.lastStopDepth`/`p.ascentRate` (thread `p` through `_simulateAscent`/`_ascendLeg` as a parameter). The stop loop becomes:

```dart
    AscentGas previousGas = plan.gasForDepth(currentDepth);
    while (currentStopDepth >= p.lastStopDepth) {
      final stopGas = plan.gasForDepth(currentStopDepth);
      final switched =
          stopGas.fN2 != previousGas.fN2 || stopGas.fHe != previousGas.fHe;

      final result = _calculateStopTime(currentStopDepth, plan, p);
      int stopTime = result.totalSeconds;
      if (switched && p.gasSwitchStopSeconds > 0) {
        stopTime = math.max(stopTime, p.gasSwitchStopSeconds);
      }

      if (stopTime > 0) {
        stops.add(
          DecoStop(
            depthMeters: currentStopDepth,
            durationSeconds: stopTime,
            isDeepStop: currentStopDepth > 9,
            airBreakSeconds: result.breakSeconds,
          ),
        );
        _loadStopMinutes(currentStopDepth, stopTime, plan, p);
      }
      previousGas = stopGas;

      final nextStop = currentStopDepth - p.stopIncrement;
      if (nextStop >= p.lastStopDepth) {
        _simulateAscent(currentStopDepth, nextStop, plan, p);
      }
      currentStopDepth = nextStop;
    }
```

`_calculateStopTime` returns a record and simulates minute-by-minute with air-break gas selection; `_loadStopMinutes` applies the stop's loading minute-by-minute with the SAME gas sequence (so search and application agree):

```dart
  /// Gas to breathe during minute [minuteIndex] of a stop at [stopDepth]:
  /// the plan's stop gas, interrupted by air breaks per policy when the
  /// stop gas is effectively pure O2 and the plan offers a break gas.
  AscentGas _gasForStopMinute(
    double stopDepth,
    int minuteIndex,
    AscentGasPlan plan,
    SchedulePolicy policy,
  ) {
    final primary = plan.gasForDepth(stopDepth);
    final breaks = policy.airBreaks;
    final isPureO2 = (primary.fN2 + primary.fHe) < 0.01;
    if (breaks == null || !isPureO2) return primary;
    final breakGas = plan.breakGasForDepth(stopDepth);
    if (breakGas == null) return primary;
    final cycle = breaks.o2Seconds + breaks.breakSeconds;
    final posInCycle = (minuteIndex * 60) % cycle;
    return posInCycle < breaks.o2Seconds ? primary : breakGas;
  }

  ({int totalSeconds, int breakSeconds}) _calculateStopTime(
    double stopDepth,
    AscentGasPlan ascentGas,
    SchedulePolicy policy,
  ) {
    final nextStopDepth = stopDepth <= policy.lastStopDepth
        ? 0.0
        : stopDepth - policy.stopIncrement;
    int stopTime = 0;
    int breakTime = 0;
    const maxStopTime = 120 * 60;

    final entryCompartments = List<TissueCompartment>.from(_compartments);
    final entryAnchor = _gfLowCeilingAnchor;

    while (stopTime < maxStopTime) {
      final minuteGas = _gasForStopMinute(
        stopDepth,
        stopTime ~/ 60,
        ascentGas,
        policy,
      );
      final primary = ascentGas.gasForDepth(stopDepth);
      final onBreak =
          minuteGas.fN2 != primary.fN2 || minuteGas.fHe != primary.fHe;

      final testCompartments = List<TissueCompartment>.from(_compartments);
      final testAnchor = _gfLowCeilingAnchor;

      calculateSegment(
        depthMeters: stopDepth,
        durationSeconds: 60,
        fN2: minuteGas.fN2,
        fHe: minuteGas.fHe,
      );
      final ceiling = calculateCeiling(currentDepth: nextStopDepth);
      _compartments = testCompartments;
      _gfLowCeilingAnchor = testAnchor;

      // Leaving mid-break is fine: the cleared check is gas-independent.
      if (ceiling <= nextStopDepth) break;

      calculateSegment(
        depthMeters: stopDepth,
        durationSeconds: 60,
        fN2: minuteGas.fN2,
        fHe: minuteGas.fHe,
      );
      stopTime += 60;
      if (onBreak) breakTime += 60;
    }

    _compartments = entryCompartments;
    _gfLowCeilingAnchor = entryAnchor;

    return (totalSeconds: stopTime, breakSeconds: breakTime);
  }

  /// Apply a stop's tissue loading using the same gas sequence the
  /// stop-time search used (air breaks included). When the gas cannot vary
  /// (no air breaks in play), load in ONE Schreiner call — bit-identical to
  /// the legacy single-segment application, so pinned TTS tests stay exact.
  void _loadStopMinutes(
    double stopDepth,
    int stopSeconds,
    AscentGasPlan plan,
    SchedulePolicy policy,
  ) {
    final primary = plan.gasForDepth(stopDepth);
    final canBreak = policy.airBreaks != null &&
        (primary.fN2 + primary.fHe) < 0.01 &&
        plan.breakGasForDepth(stopDepth) != null;
    if (!canBreak) {
      calculateSegment(
        depthMeters: stopDepth,
        durationSeconds: stopSeconds,
        fN2: primary.fN2,
        fHe: primary.fHe,
      );
      return;
    }
    for (int minute = 0; minute < stopSeconds ~/ 60; minute++) {
      final gas = _gasForStopMinute(stopDepth, minute, plan, policy);
      calculateSegment(
        depthMeters: stopDepth,
        durationSeconds: 60,
        fN2: gas.fN2,
        fHe: gas.fHe,
      );
    }
    final remainder = stopSeconds % 60;
    if (remainder > 0) {
      final gas = plan.gasForDepth(stopDepth);
      calculateSegment(
        depthMeters: stopDepth,
        durationSeconds: remainder,
        fN2: gas.fN2,
        fHe: gas.fHe,
      );
    }
  }
```

IMPORTANT: the old code applied the stop's loading with ONE `calculateSegment(stopTime)` call on the stop gas. With no air breaks and no switch minimum, `_loadStopMinutes` produces the same result (exponential composition is associative), so the "null policy reproduces legacy" test pins this.

`calculateTts` gains `SchedulePolicy? policy`, forwards it to `calculateDecoSchedule`, and uses `p.ascentRate` for its ascent legs. `getDecoStatus` gains and forwards `SchedulePolicy? policy` too.

- [ ] **Step 7: Run the new test AND the full deco suite**

Run: `flutter test test/core/deco/`
Expected: ALL PASS. Pay attention to `tts_cleanroom_cross_check_test.dart` and `tts_gas_switch_regression_test.dart` — they pin the legacy schedule numerics.

- [ ] **Step 8: Commit**

```bash
dart format .
git add lib/core/deco/schedule_policy.dart lib/core/deco/buhlmann_algorithm.dart lib/core/deco/entities/deco_status.dart lib/core/deco/ascent/ascent_gas_plan.dart test/core/deco/schedule_policy_test.dart
git commit -m "feat(deco): SchedulePolicy with gas-switch minimums and O2 air breaks"
```

---

### Task 7: DecoModel interface and BuhlmannGf facade

**Files:**
- Create: `lib/core/deco/deco_model.dart`
- Test: `test/core/deco/deco_model_test.dart`

**Interfaces:**
- Consumes: everything from Tasks 1-6.
- Produces (Phase 2's `PlanEngine` builds on exactly these):

```dart
abstract class TissueState
class BuhlmannState extends TissueState { List<TissueCompartment> compartments; double gfLowCeilingAnchor; }
class DecoSegment { double startDepth; double endDepth; int durationSeconds; }
class DecoSchedule { List<DecoStop> stops; int ttsSeconds; }
abstract class DecoModel {
  TissueState initial();
  TissueState applySegment(TissueState state, DecoSegment segment, BreathingConfig breathing);
  double ceilingMeters(TissueState state, {double currentDepth = 0});
  int ndlSeconds(TissueState state, {required double depthMeters, required BreathingConfig breathing});
  DecoSchedule schedule(TissueState state, {required double currentDepth, required AscentGasPlan gases});
}
class BuhlmannGf implements DecoModel  // ctor: ({double gfLow, double gfHigh, DiveEnvironment environment, SchedulePolicy policy})
```

- [ ] **Step 1: Write the failing test**

Create `test/core/deco/deco_model_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/deco/ascent/ascent_gas_plan.dart';
import 'package:submersion/core/deco/buhlmann_algorithm.dart';
import 'package:submersion/core/deco/deco_model.dart';
import 'package:submersion/core/deco/entities/breathing_config.dart';
import 'package:submersion/core/deco/schedule_policy.dart';

void main() {
  const air = OpenCircuit(fO2: 0.2098);

  group('BuhlmannGf', () {
    test('reproduces raw BuhlmannAlgorithm results', () {
      final model = BuhlmannGf(gfLow: 0.4, gfHigh: 0.8);
      var state = model.initial();
      state = model.applySegment(
        state,
        const DecoSegment(startDepth: 0, endDepth: 40, durationSeconds: 133),
        air,
      );
      state = model.applySegment(
        state,
        const DecoSegment(startDepth: 40, endDepth: 40, durationSeconds: 1500),
        air,
      );
      final schedule = model.schedule(
        state,
        currentDepth: 40,
        gases: FixedAscentGas(fN2: 0.7902),
      );

      // Same dive on the raw algorithm.
      final algo = BuhlmannAlgorithm(gfLow: 0.4, gfHigh: 0.8);
      algo.calculateSegment(depthMeters: 20, durationSeconds: 133); // avg
      algo.calculateSegment(depthMeters: 40, durationSeconds: 1500);
      final rawStops = algo.calculateDecoSchedule(currentDepth: 40);
      final rawTts = algo.calculateTts(currentDepth: 40);

      expect(schedule.stops.length, rawStops.length);
      for (int i = 0; i < rawStops.length; i++) {
        expect(schedule.stops[i].depthMeters, rawStops[i].depthMeters);
        expect(schedule.stops[i].durationSeconds, rawStops[i].durationSeconds);
      }
      expect(schedule.ttsSeconds, rawTts);
    });

    test('is pure: same state in, same result out, state unchanged', () {
      final model = BuhlmannGf(gfLow: 0.4, gfHigh: 0.8);
      var state = model.initial();
      state = model.applySegment(
        state,
        const DecoSegment(startDepth: 0, endDepth: 40, durationSeconds: 133),
        air,
      );
      final s = state as BuhlmannState;
      final compsBefore = List.of(s.compartments);

      final first = model.schedule(
        state,
        currentDepth: 40,
        gases: FixedAscentGas(fN2: 0.7902),
      );
      final second = model.schedule(
        state,
        currentDepth: 40,
        gases: FixedAscentGas(fN2: 0.7902),
      );
      expect(first.ttsSeconds, second.ttsSeconds);
      expect(s.compartments, compsBefore);
    });

    test('ndlSeconds supports CCR breathing', () {
      final model = BuhlmannGf(gfLow: 0.5, gfHigh: 0.8);
      final state = model.initial();
      final ndlOc = model.ndlSeconds(
        state,
        depthMeters: 30,
        breathing: air,
      );
      final ndlCcr = model.ndlSeconds(
        state,
        depthMeters: 30,
        breathing: const ClosedCircuit(setpoint: 1.3, diluentFO2: 0.21),
      );
      expect(ndlCcr, greaterThan(ndlOc));
    });

    test('ceilingMeters reports the loaded ceiling', () {
      final model = BuhlmannGf(gfLow: 0.4, gfHigh: 0.8);
      var state = model.initial();
      expect(model.ceilingMeters(state, currentDepth: 40), 0.0);
      state = model.applySegment(
        state,
        const DecoSegment(startDepth: 40, endDepth: 40, durationSeconds: 2400),
        air,
      );
      expect(model.ceilingMeters(state, currentDepth: 40), greaterThan(0));
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/deco/deco_model_test.dart`
Expected: FAIL — `deco_model.dart` does not exist.

- [ ] **Step 3: Write the implementation**

Create `lib/core/deco/deco_model.dart`:

```dart
import 'package:submersion/core/deco/ascent/ascent_gas_plan.dart';
import 'package:submersion/core/deco/buhlmann_algorithm.dart';
import 'package:submersion/core/deco/entities/breathing_config.dart';
import 'package:submersion/core/deco/entities/deco_status.dart';
import 'package:submersion/core/deco/entities/dive_environment.dart';
import 'package:submersion/core/deco/entities/tissue_compartment.dart';
import 'package:submersion/core/deco/schedule_policy.dart';

/// Model-opaque tissue state. Each [DecoModel] defines its own concrete
/// state (Buhlmann: compartment tensions; a future VPM-B: bubble
/// parameters). Callers treat it as a token: obtain it from the model,
/// hand it back to the model.
abstract class TissueState {
  const TissueState();
}

/// Buhlmann ZH-L16C state: 16 compartments plus the GF-low ceiling anchor.
class BuhlmannState extends TissueState {
  const BuhlmannState({
    required this.compartments,
    this.gfLowCeilingAnchor = 0.0,
  });

  final List<TissueCompartment> compartments;
  final double gfLowCeilingAnchor;
}

/// One constant-or-linear depth leg of a dive.
class DecoSegment {
  const DecoSegment({
    required this.startDepth,
    required this.endDepth,
    required this.durationSeconds,
  });

  final double startDepth;
  final double endDepth;
  final int durationSeconds;
}

/// A computed decompression schedule.
class DecoSchedule {
  const DecoSchedule({required this.stops, required this.ttsSeconds});

  final List<DecoStop> stops;
  final int ttsSeconds;
}

/// A decompression model: the seam where VPM-B slots in beside Buhlmann.
///
/// Implementations are PURE with respect to [TissueState]: methods never
/// mutate the state passed in; [applySegment] returns a new state.
abstract class DecoModel {
  /// Surface-equilibrated state for this model's environment.
  TissueState initial();

  /// State after breathing [breathing] over [segment].
  TissueState applySegment(
    TissueState state,
    DecoSegment segment,
    BreathingConfig breathing,
  );

  /// Current ceiling in meters (0 = clear to surface).
  double ceilingMeters(TissueState state, {double currentDepth = 0});

  /// No-deco limit in seconds at [depthMeters] on [breathing];
  /// -1 when already in deco.
  int ndlSeconds(
    TissueState state, {
    required double depthMeters,
    required BreathingConfig breathing,
  });

  /// Full deco schedule from [currentDepth] ascending on [gases].
  DecoSchedule schedule(
    TissueState state, {
    required double currentDepth,
    required AscentGasPlan gases,
  });
}

/// Buhlmann ZH-L16C with gradient factors, wrapping [BuhlmannAlgorithm].
class BuhlmannGf implements DecoModel {
  BuhlmannGf({
    double gfLow = 0.30,
    double gfHigh = 0.70,
    DiveEnvironment environment = DiveEnvironment.standard,
    this.policy = const SchedulePolicy(),
  }) : _algorithm = BuhlmannAlgorithm(
         gfLow: gfLow,
         gfHigh: gfHigh,
         lastStopDepth: policy.lastStopDepth,
         stopIncrement: policy.stopIncrement,
         ascentRate: policy.ascentRate,
         environment: environment,
       );

  final SchedulePolicy policy;
  final BuhlmannAlgorithm _algorithm;

  void _restore(TissueState state) {
    final s = state as BuhlmannState;
    _algorithm.restoreState(
      s.compartments,
      gfLowCeilingAnchor: s.gfLowCeilingAnchor,
    );
  }

  BuhlmannState _capture() => BuhlmannState(
        compartments: _algorithm.compartments,
        gfLowCeilingAnchor: _algorithm.gfLowCeilingAnchor,
      );

  @override
  TissueState initial() {
    _algorithm.reset();
    return _capture();
  }

  @override
  TissueState applySegment(
    TissueState state,
    DecoSegment segment,
    BreathingConfig breathing,
  ) {
    _restore(state);
    final avgDepth = (segment.startDepth + segment.endDepth) / 2.0;
    _algorithm.calculateSegment(
      depthMeters: avgDepth,
      durationSeconds: segment.durationSeconds,
      breathing: breathing,
    );
    return _capture();
  }

  @override
  double ceilingMeters(TissueState state, {double currentDepth = 0}) {
    _restore(state);
    return _algorithm.calculateCeiling(currentDepth: currentDepth);
  }

  @override
  int ndlSeconds(
    TissueState state, {
    required double depthMeters,
    required BreathingConfig breathing,
  }) {
    _restore(state);
    return _algorithm.calculateNdl(
      depthMeters: depthMeters,
      breathing: breathing,
    );
  }

  @override
  DecoSchedule schedule(
    TissueState state, {
    required double currentDepth,
    required AscentGasPlan gases,
  }) {
    _restore(state);
    final stops = _algorithm.calculateDecoSchedule(
      currentDepth: currentDepth,
      ascentGas: gases,
      policy: policy,
    );
    _restore(state);
    final tts = _algorithm.calculateTts(
      currentDepth: currentDepth,
      ascentGas: gases,
      policy: policy,
    );
    return DecoSchedule(stops: stops, ttsSeconds: tts);
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/deco/deco_model_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
dart format .
git add lib/core/deco/deco_model.dart test/core/deco/deco_model_test.dart
git commit -m "feat(deco): DecoModel interface with BuhlmannGf implementation"
```

---

### Task 8: Compressibility-correct gas consumption

**Files:**
- Modify: `lib/core/utils/gas_compressibility.dart` (add `pressureAfterConsuming`)
- Modify: `lib/features/dive_planner/data/services/plan_calculator_service.dart` (`_GasUsageTracker`, tracker initialization ~line 103)
- Test: `test/core/utils/gas_compressibility_test.dart` (extend or create), `test/features/dive_planner/plan_gas_consumption_test.dart`

**Interfaces:**
- Consumes: existing `gasVolume(...)` in `gas_compressibility.dart`.
- Produces: top-level `double pressureAfterConsuming({required double tankSizeLiters, required double startPressureBar, required double litersConsumed, required double o2Percent, double hePercent = 0})`. `_GasUsageTracker` gains `o2Percent`/`hePercent` fields; `remainingPressure`, `gasUsedBar`, `percentUsed` become compressibility-aware.

- [ ] **Step 1: Compute expected values with python3**

Run (this mirrors the Dart virial model exactly — coefficients from `gas_compressibility.dart`):

```bash
python3 -c "
o2c = [-7.18092073703e-04, 2.81852572808e-06, -1.50290620492e-09]
n2c = [-2.19260353292e-04, 2.92844845532e-06, -2.07613482075e-09]
hec = [4.87320026468e-04, -8.83632921053e-08, 5.33304543646e-11]
def z(o2, he, bar):
    p = min(max(bar, 0.0), 500.0)
    v = lambda c: p*c[0] + p*p*c[1] + p*p*p*c[2]
    n2 = 1.0 - o2/100.0 - he/100.0
    return 1.0 + v(o2c)*o2/100.0 + v(hec)*he/100.0 + v(n2c)*n2
def vol(size, bar, o2, he=0.0):
    return 0.0 if bar <= 0 else size * (bar/1.01325) / z(o2, he, bar)
start = vol(11.1, 207.0, 21.0)
print('AL80 air @207 bar =', repr(start), 'ideal =', repr(11.1*207/1.01325))
# consume 500 L: solve for end pressure by bisection
target = start - 500.0
lo, hi = 0.0, 207.0
for _ in range(80):
    mid = (lo+hi)/2
    if vol(11.1, mid, 21.0) > target: hi = mid
    else: lo = mid
print('after 500 L =', repr((lo+hi)/2), 'ideal =', repr(207.0 - 500.0/11.1*1.01325))
"
```

Note the ideal-gas convention: the existing tracker treats `volume * pressure_bar` as surface liters with 1 bar reference; `gasVolume` uses 1 atm. Pin whatever python prints — the test asserts against those exact numbers.

- [ ] **Step 2: Write the failing tests**

Create (or extend if it exists — check first with `ls test/core/utils/`) `test/core/utils/gas_compressibility_test.dart`; add:

```dart
  group('pressureAfterConsuming', () {
    test('consuming zero keeps start pressure', () {
      expect(
        pressureAfterConsuming(
          tankSizeLiters: 11.1,
          startPressureBar: 207,
          litersConsumed: 0,
          o2Percent: 21,
        ),
        closeTo(207.0, 0.01),
      );
    });

    test('matches python bisection for 500 L from an AL80', () {
      final end = pressureAfterConsuming(
        tankSizeLiters: 11.1,
        startPressureBar: 207,
        litersConsumed: 500,
        o2Percent: 21,
      );
      // Paste the exact python3 value from Step 1 here:
      expect(end, closeTo(/* python value */ 0, 0.05));
    });

    test('consuming everything returns 0', () {
      expect(
        pressureAfterConsuming(
          tankSizeLiters: 11.1,
          startPressureBar: 207,
          litersConsumed: 99999,
          o2Percent: 21,
        ),
        0.0,
      );
    });

    test('round-trips with gasVolume', () {
      const consumed = 800.0;
      final end = pressureAfterConsuming(
        tankSizeLiters: 12.0,
        startPressureBar: 232,
        litersConsumed: consumed,
        o2Percent: 18,
        hePercent: 45,
      );
      final startVol = gasVolume(
        tankSizeLiters: 12.0,
        pressureBar: 232,
        o2Percent: 18,
        hePercent: 45,
      );
      final endVol = gasVolume(
        tankSizeLiters: 12.0,
        pressureBar: end,
        o2Percent: 18,
        hePercent: 45,
      );
      expect(startVol - endVol, closeTo(consumed, 0.5));
    });
  });
```

(The `closeTo(/* python value */ 0, 0.05)` placeholder MUST be replaced with the number python printed in Step 1 before running.)

- [ ] **Step 3: Implement `pressureAfterConsuming`**

Append to `lib/core/utils/gas_compressibility.dart`:

```dart
/// Cylinder pressure remaining after consuming [litersConsumed] surface
/// liters, honoring compressibility. Solves
/// gasVolume(start) - gasVolume(end) == litersConsumed by bisection.
///
/// Returns 0 when the demand exceeds the cylinder's content.
double pressureAfterConsuming({
  required double tankSizeLiters,
  required double startPressureBar,
  required double litersConsumed,
  required double o2Percent,
  double hePercent = 0,
}) {
  if (startPressureBar <= 0 || tankSizeLiters <= 0) return 0;
  final startVolume = gasVolume(
    tankSizeLiters: tankSizeLiters,
    pressureBar: startPressureBar,
    o2Percent: o2Percent,
    hePercent: hePercent,
  );
  final target = startVolume - litersConsumed;
  if (target <= 0) return 0;

  double lo = 0.0;
  double hi = startPressureBar;
  for (int i = 0; i < 60; i++) {
    final mid = (lo + hi) / 2;
    final v = gasVolume(
      tankSizeLiters: tankSizeLiters,
      pressureBar: mid,
      o2Percent: o2Percent,
      hePercent: hePercent,
    );
    if (v > target) {
      hi = mid;
    } else {
      lo = mid;
    }
  }
  return (lo + hi) / 2;
}
```

Run: `flutter test test/core/utils/gas_compressibility_test.dart` — expected PASS.

- [ ] **Step 4: Wire the planner's `_GasUsageTracker`**

In `plan_calculator_service.dart`, import `package:submersion/core/utils/gas_compressibility.dart` and replace `_GasUsageTracker` (line ~604):

```dart
class _GasUsageTracker {
  final double? startPressure;
  final double volume;
  final double o2Percent;
  final double hePercent;
  double gasUsedLiters = 0;

  _GasUsageTracker({
    this.startPressure,
    required this.volume,
    this.o2Percent = 21.0,
    this.hePercent = 0.0,
  });

  void addGasUsed(double liters) {
    gasUsedLiters += liters;
  }

  /// Remaining pressure honoring gas compressibility.
  double? get remainingPressure {
    if (startPressure == null) return null;
    return pressureAfterConsuming(
      tankSizeLiters: volume,
      startPressureBar: startPressure!,
      litersConsumed: gasUsedLiters,
      o2Percent: o2Percent,
      hePercent: hePercent,
    );
  }

  /// Bar consumed (start minus compressibility-aware remaining).
  double get gasUsedBar {
    if (startPressure == null) {
      return volume > 0 ? gasUsedLiters / volume : 0;
    }
    return startPressure! - (remainingPressure ?? 0);
  }

  /// Percentage of the tank's content used.
  double get percentUsed {
    if (startPressure == null || startPressure == 0) return 0;
    return (gasUsedBar / startPressure!) * 100;
  }
}
```

Update the tracker initialization (~line 103) to pass the tank's gas:

```dart
    for (final tank in tanks) {
      gasUsageByTank[tank.id] = _GasUsageTracker(
        startPressure: tank.startPressure,
        volume: tank.volume ?? 11.0, // Default AL80 if not specified
        o2Percent: tank.gasMix.o2,
        hePercent: tank.gasMix.he,
      );
    }
```

(Verify the field access compiles — `DiveTank.gasMix` is a `GasMix` with `o2`/`he` as 0-100 percentages, defined in `lib/features/dive_log/domain/entities/dive.dart:1000`.)

- [ ] **Step 5: Write the planner-level test**

Create `test/features/dive_planner/plan_gas_consumption_test.dart` — check first whether a test for `PlanCalculatorService` already exists under `test/features/dive_planner/` and extend it instead if so:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_planner/data/services/plan_calculator_service.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_segment.dart';

void main() {
  test('remaining pressure accounts for compressibility', () {
    final service = PlanCalculatorService(gfLow: 50, gfHigh: 80);
    const gas = GasMix(o2: 21.0, he: 0.0);
    const tank = DiveTank(
      id: 'tank-1',
      volume: 11.1,
      workingPressure: 207.0,
      startPressure: 207.0,
      gasMix: gas,
    );
    final segments = [
      PlanSegment.descent(
        id: 'seg-1',
        targetDepth: 30.0,
        tankId: 'tank-1',
        gasMix: gas,
        order: 0,
      ),
      PlanSegment.bottom(
        id: 'seg-2',
        depth: 30.0,
        durationMinutes: 25,
        tankId: 'tank-1',
        gasMix: gas,
        order: 1,
      ),
      PlanSegment.ascent(
        id: 'seg-3',
        fromDepth: 30.0,
        toDepth: 0.0,
        tankId: 'tank-1',
        gasMix: gas,
        order: 2,
      ),
    ];

    final result = service.calculatePlan(
      segments: segments,
      tanks: const [tank],
      sacRate: 16.0,
    );

    final consumption = result.gasConsumptions.first;
    final litersUsed = consumption.gasUsedLiters;
    expect(litersUsed, greaterThan(0));

    // Ideal-gas remaining: start minus liters/volume. Compressibility means
    // the same surface liters cost MORE bar at high pressure, so the real
    // remaining pressure must be LOWER than the ideal figure.
    final idealRemaining = 207.0 - litersUsed / 11.1;
    expect(consumption.remainingPressure, isNotNull);
    expect(consumption.remainingPressure!, lessThan(idealRemaining + 0.01));
    expect(consumption.remainingPressure!, greaterThan(0));
  });
}
```

(Field names on the consumption result: check `GasConsumption` in `lib/features/dive_planner/domain/entities/plan_result.dart` — the fields are `gasUsedLiters` and `remainingPressure`; if the actual names differ, use the actual names.) `DiveTank.role` defaults to `TankRole.backGas`, so it can be omitted. Note for Phase 4: `TankRole.diluent` and `TankRole.oxygenSupply` already exist in `lib/core/constants/enums.dart:243`.

- [ ] **Step 6: Run tests**

Run: `flutter test test/core/utils/gas_compressibility_test.dart test/features/dive_planner/plan_gas_consumption_test.dart`
Expected: PASS. Also run any pre-existing `plan_calculator_service` tests under `test/features/dive_planner/` — consumption numbers there may legitimately shift; update ONLY assertions that pinned the old ideal-gas remaining pressure, and say so in the commit message.

- [ ] **Step 7: Commit**

```bash
dart format .
git add lib/core/utils/gas_compressibility.dart lib/features/dive_planner/data/services/plan_calculator_service.dart test/core/utils/gas_compressibility_test.dart test/features/dive_planner/plan_gas_consumption_test.dart
git commit -m "feat(planner): compressibility-correct gas consumption"
```

---

### Task 9: Golden-vector validation suite

**Files:**
- Create: `scripts/deco_golden/generate_vectors.py`
- Create: `scripts/deco_golden/README.md`
- Create: `test/core/deco/golden/vectors.json` (generated, committed)
- Test: `test/core/deco/golden/golden_vector_test.dart`

**Interfaces:**
- Consumes: the full engine API from Tasks 1-6.
- Produces: a committed `vectors.json` and a Dart test that replays every case. The Python script is an INDEPENDENT implementation of ZH-L16C + GF (same published coefficients, same pinned semantics) — agreement between the two implementations is the accuracy claim. Tolerances: each stop ±60 s, TTS ±90 s, tissue tensions ±5e-4 bar.

**Pinned semantics both implementations must share** (this is the contract — the Python script documents each):
1. Inspired inert gas: `(P_amb - 0.0627) * fraction`; surface saturation `(P_surface - 0.0627) * 0.7902`.
2. Depth-pressure: `P = P_surface + depth * rho * 9.80665 / 1e5`.
3. Schreiner constant-depth loading with `k = ln(2)/halfTime`.
4. GF-low anchor: running max of the GF-low ceiling (meters) after every applied loading step; GF at depth d interpolates `gfHigh - (gfHigh-gfLow) * d/anchor`, clamped to gfLow below the anchor, gfHigh at surface or when anchor is 0.
5. Compartment ceiling pressure: `(P_inert - a*gf) / (gf/b + 1 - gf)` with tension-blended a/b; meters via the environment, clamped >= 0.
6. First stop: `ceil(ceiling_at_current_gf / 3) * 3`.
7. Ascent legs: average depth, duration `round(delta_depth / rate * 60)` seconds, split at gas-switch (MOD) depths, gas chosen at the leg's deeper end.
8. Stop time search: minute-by-minute; leave when the ceiling evaluated at the NEXT stop's interpolated GF is <= the next stop depth; the checked trial minute is not counted; stop minutes are then applied to the tissues.
9. Gas selection during ascent/stops: highest-O2 gas whose MOD (given in the vector) is >= the depth.
10. CCR loading: `pO2 = min(setpoint, P_amb - 0.0627)`; inert = remainder split by diluent N2:He ratio.
11. TTS: sum of stop seconds plus `round()` of each ascent leg at the policy rate, including final stop to surface.

- [ ] **Step 1: Write the Python generator**

Create `scripts/deco_golden/generate_vectors.py`. Full implementation (~250 lines). Skeleton with all the load-bearing parts spelled out — the executor completes the `zhl16c` coefficient tables by copying the 6 arrays verbatim from `lib/core/deco/constants/buhlmann_coefficients.dart`:

```python
#!/usr/bin/env python3
"""Golden-vector generator for the Submersion deco engine.

Independent ZH-L16C + gradient-factor implementation. Semantics are pinned
to the contract in docs/superpowers/plans/2026-07-05-dive-planner-phase1-engine.md
(Task 9). Regenerate with:

    python3 scripts/deco_golden/generate_vectors.py > test/core/deco/golden/vectors.json
"""
import json
import math

# --- ZH-L16C tables: copy the 6 arrays VERBATIM from
# --- lib/core/deco/constants/buhlmann_coefficients.dart
N2_HALF = [4.0, 8.0, 12.5, 18.5, 27.0, 38.3, 54.3, 77.0,
           109.0, 146.0, 187.0, 239.0, 305.0, 390.0, 498.0, 635.0]
HE_HALF = [1.51, 3.02, 4.72, 6.99, 10.21, 14.48, 20.53, 29.11,
           41.20, 55.19, 70.69, 90.34, 115.29, 147.42, 188.24, 240.03]
N2_A = [1.2599, 1.0000, 0.8618, 0.7562, 0.6200, 0.5043, 0.4410, 0.4000,
        0.3750, 0.3500, 0.3295, 0.3065, 0.2835, 0.2610, 0.2480, 0.2327]
N2_B = [0.5050, 0.6514, 0.7222, 0.7825, 0.8126, 0.8434, 0.8693, 0.8910,
        0.9092, 0.9222, 0.9319, 0.9403, 0.9477, 0.9544, 0.9602, 0.9653]
HE_A = [1.7424, 1.3830, 1.1919, 1.0458, 0.9220, 0.8205, 0.7305, 0.6502,
        0.5950, 0.5545, 0.5333, 0.5189, 0.5181, 0.5176, 0.5172, 0.5119]
HE_B = [0.4245, 0.5747, 0.6527, 0.7223, 0.7582, 0.7957, 0.8279, 0.8553,
        0.8757, 0.8903, 0.8997, 0.9073, 0.9122, 0.9171, 0.9217, 0.9267]

WV = 0.0627
AIR_N2 = 0.7902
G = 9.80665


class Env:
    def __init__(self, surface=1.0, density=1019.716213):
        self.surface = surface
        self.density = density

    @property
    def bar_per_m(self):
        return self.density * G / 100000.0

    def p_at(self, depth):
        return self.surface + depth * self.bar_per_m

    def depth_at(self, p):
        return (p - self.surface) / self.bar_per_m


class State:
    def __init__(self, env):
        self.env = env
        surf_n2 = (env.surface - WV) * AIR_N2
        self.n2 = [surf_n2] * 16
        self.he = [0.0] * 16
        self.anchor = 0.0  # deepest GF-low ceiling so far, meters

    def clone(self):
        s = State(self.env)
        s.n2, s.he, s.anchor = list(self.n2), list(self.he), self.anchor
        return s


def schreiner(p0, pi, minutes, half):
    k = math.log(2) / half
    return pi + (p0 - pi) * math.exp(-k * minutes)


def ceiling_pressure(state, i, gf):
    pn, ph = state.n2[i], state.he[i]
    total = pn + ph
    if total == 0:
        a, b = N2_A[i], N2_B[i]
    else:
        a = (pn * N2_A[i] + ph * HE_A[i]) / total
        b = (pn * N2_B[i] + ph * HE_B[i]) / total
    return (total - a * gf) / (gf / b + 1 - gf)


def ceiling_m(state, gf):
    worst = 0.0
    for i in range(16):
        m = state.env.depth_at(ceiling_pressure(state, i, gf))
        worst = max(worst, m)
    return worst


def interp_gf(state, depth, gf_low, gf_high):
    if depth <= 0 or state.anchor <= 0:
        return gf_high
    if depth >= state.anchor:
        return gf_low
    return gf_high - (gf_high - gf_low) * (depth / state.anchor)


def load(state, depth, seconds, f_n2, f_he, gf_low, setpoint=None):
    amb = state.env.p_at(depth)
    p_alv = max(amb - WV, 0.0)
    if setpoint is None:
        i_n2, i_he = p_alv * f_n2, p_alv * f_he
    else:
        p_o2 = min(setpoint, p_alv)
        inert = max(p_alv - p_o2, 0.0)
        tot = f_n2 + f_he
        share = f_n2 / tot if tot > 0 else 0.0
        i_n2, i_he = inert * share, inert * (1 - share)
    minutes = seconds / 60.0
    for i in range(16):
        state.n2[i] = schreiner(state.n2[i], i_n2, minutes, N2_HALF[i])
        state.he[i] = schreiner(state.he[i], i_he, minutes, HE_HALF[i])
    state.anchor = max(state.anchor, ceiling_m(state, gf_low))


def gas_at(gases, depth):
    """Highest-O2 gas eligible at depth (depth <= mod)."""
    best = None
    for g in gases:
        if depth <= g["mod_m"] + 1e-9:
            fo2 = 1.0 - g["f_n2"] - g["f_he"]
            if best is None or fo2 > (1.0 - best["f_n2"] - best["f_he"]):
                best = g
    return best if best else min(gases, key=lambda g: 1 - g["f_n2"] - g["f_he"])


def switch_depths(gases, deeper, shallower):
    out = []
    for g in gases:
        m = g["mod_m"]
        if shallower + 1e-9 < m < deeper - 1e-9:
            below, above = gas_at(gases, m + 1e-6), gas_at(gases, m - 1e-6)
            if below is not above:
                out.append(m)
    return sorted(out, reverse=True)


def ascend(state, frm, to, rate, gases, gf_low):
    if frm <= to:
        return 0
    total = 0
    seg_top = frm
    for sw in switch_depths(gases, frm, to):
        total += _leg(state, seg_top, sw, rate, gases, gf_low)
        seg_top = sw
    total += _leg(state, seg_top, to, rate, gases, gf_low)
    return total


def _leg(state, frm, to, rate, gases, gf_low):
    if frm <= to:
        return 0
    g = gas_at(gases, frm)
    secs = round((frm - to) / rate * 60)
    load(state, (frm + to) / 2.0, secs, g["f_n2"], g["f_he"], gf_low)
    return secs


def stop_time(state, depth, gases, gf_low, gf_high, last_stop, incr):
    nxt = 0.0 if depth <= last_stop else depth - incr
    g = gas_at(gases, depth)
    t = 0
    while t < 120 * 60:
        trial = state.clone()
        load(trial, depth, 60, g["f_n2"], g["f_he"], gf_low)
        gf = interp_gf(trial, nxt, gf_low, gf_high)
        if ceiling_m(trial, gf) <= nxt:
            break
        state.n2, state.he, state.anchor = trial.n2, trial.he, trial.anchor
        t += 60
    return t


def schedule(state, depth, gases, gf_low, gf_high,
             last_stop=3.0, incr=3.0, rate=9.0):
    stops = []
    work = state.clone()
    gf_here = interp_gf(work, depth, gf_low, gf_high)
    ceil0 = ceiling_m(work, gf_here)
    if ceil0 <= 0:
        return stops, round(depth / rate * 60)
    stop = math.ceil(ceil0 / incr) * incr
    tts = ascend(work, depth, stop, rate, gases, gf_low)
    while stop >= last_stop:
        t = stop_time(work, stop, gases, gf_low, gf_high, last_stop, incr)
        if t > 0:
            stops.append({"depth_m": stop, "seconds": t})
            tts += t
        nxt = stop - incr
        if nxt >= last_stop:
            tts += ascend(work, stop, nxt, rate, gases, gf_low)
        stop = nxt
    tts += round(last_stop / rate * 60)
    return stops, tts
```

The TTS accumulation above must mirror the Dart `calculateTts`: Dart sums stop seconds plus per-leg `round((d1-d2)/rate*60)` transitions from the ORIGINAL depth through each stop depth to the surface, WITHOUT gas-switch splitting of the travel legs in the time sum. Reconcile the two carefully — if Dart and Python disagree by more than the tolerance, print both breakdowns and fix the PYTHON side to match the pinned Dart semantics (the Dart side is pinned by `tts_cleanroom_cross_check_test.dart`).

Then the case table and main:

```python
def run_case(name, env, gf, segments, sched_depth, gases,
             tissues=False, ccr_ceiling_at=None):
    st = State(env)
    for seg in segments:
        load(st, seg["avg_depth_m"], seg["seconds"], seg["f_n2"],
             seg["f_he"], gf[0] / 100.0, seg.get("setpoint"))
    expected = {}
    if sched_depth is not None:
        stops, tts = schedule(st, sched_depth, gases,
                              gf[0] / 100.0, gf[1] / 100.0)
        expected["stops"] = stops
        expected["tts_seconds"] = tts
    if tissues:
        expected["tissues_p_n2_bar"] = [round(x, 6) for x in st.n2]
        expected["tissues_p_he_bar"] = [round(x, 6) for x in st.he]
    if ccr_ceiling_at is not None:
        gf_here = interp_gf(st, ccr_ceiling_at, gf[0] / 100.0, gf[1] / 100.0)
        expected["ceiling_m"] = round(ceiling_m(st, gf_here), 3)
    return {
        "name": name,
        "environment": {"surface_pressure_bar": env.surface,
                        "water_density_kg_m3": env.density},
        "gf": gf,
        "segments": segments,
        "schedule_from_depth_m": sched_depth,
        "gases": gases,
        "expected": expected,
    }


AIR = {"f_n2": 0.7902, "f_he": 0.0, "mod_m": 66.0}
EAN50 = {"f_n2": 0.50, "f_he": 0.0, "mod_m": 22.0}   # ppO2 1.6
O2 = {"f_n2": 0.0, "f_he": 0.0, "mod_m": 6.0}        # ppO2 1.6
TX1845 = {"f_n2": 0.37, "f_he": 0.45, "mod_m": 78.0}

STD = Env()
cases = [
    run_case("air-30m-25min-gf5080", STD, [50, 80],
             [{"avg_depth_m": 15.0, "seconds": 100,
               "f_n2": 0.7902, "f_he": 0.0},
              {"avg_depth_m": 30.0, "seconds": 1500,
               "f_n2": 0.7902, "f_he": 0.0}],
             30.0, [AIR], tissues=True),
    run_case("air-40m-20min-gf3070", STD, [30, 70],
             [{"avg_depth_m": 20.0, "seconds": 133,
               "f_n2": 0.7902, "f_he": 0.0},
              {"avg_depth_m": 40.0, "seconds": 1200,
               "f_n2": 0.7902, "f_he": 0.0}],
             40.0, [AIR]),
    run_case("ean32-30m-40min-gf5080", STD, [50, 80],
             [{"avg_depth_m": 15.0, "seconds": 100,
               "f_n2": 0.68, "f_he": 0.0},
              {"avg_depth_m": 30.0, "seconds": 2400,
               "f_n2": 0.68, "f_he": 0.0}],
             30.0, [{"f_n2": 0.68, "f_he": 0.0, "mod_m": 40.0}]),
    run_case("tx1845-60m-25min-ean50-o2-gf5080", STD, [50, 80],
             [{"avg_depth_m": 30.0, "seconds": 200,
               "f_n2": 0.37, "f_he": 0.45},
              {"avg_depth_m": 60.0, "seconds": 1500,
               "f_n2": 0.37, "f_he": 0.45}],
             60.0, [TX1845, EAN50, O2]),
    run_case("air-30m-20min-altitude2000m", Env(surface=0.794973), [50, 80],
             [{"avg_depth_m": 15.0, "seconds": 100,
               "f_n2": 0.7902, "f_he": 0.0},
              {"avg_depth_m": 30.0, "seconds": 1200,
               "f_n2": 0.7902, "f_he": 0.0}],
             30.0, [AIR]),
    run_case("air-30m-25min-freshwater", Env(density=1000.0), [50, 80],
             [{"avg_depth_m": 15.0, "seconds": 100,
               "f_n2": 0.7902, "f_he": 0.0},
              {"avg_depth_m": 30.0, "seconds": 1500,
               "f_n2": 0.7902, "f_he": 0.0}],
             30.0, [AIR]),
    run_case("ccr-sp13-dil1845-60m-25min-loading", STD, [50, 80],
             [{"avg_depth_m": 30.0, "seconds": 200, "f_n2": 0.37,
               "f_he": 0.45, "setpoint": 1.3},
              {"avg_depth_m": 60.0, "seconds": 1500, "f_n2": 0.37,
               "f_he": 0.45, "setpoint": 1.3}],
             None, [], tissues=True, ccr_ceiling_at=60.0),
]

# The altitude surface pressure must equal the Dart ISA value; recompute it
# here rather than trusting the literal above:
isa = 1.01325 * (1 - 0.0000225577 * 2000.0) ** 5.25588
assert abs(cases[4]["environment"]["surface_pressure_bar"] - isa) < 1e-4, isa

print(json.dumps({"generator": "scripts/deco_golden/generate_vectors.py",
                  "semantics_version": 1, "cases": cases}, indent=2))
```

- [ ] **Step 2: Generate the vectors**

Run:
```bash
mkdir -p test/core/deco/golden
python3 scripts/deco_golden/generate_vectors.py > test/core/deco/golden/vectors.json
python3 -m json.tool test/core/deco/golden/vectors.json > /dev/null && echo OK
```
Expected: `OK`. Sanity-read the file: the trimix case must have stops at 21 m or deeper through 3 m; the altitude case must show MORE deco than the matching sea-level case.

- [ ] **Step 3: Write the Dart golden runner**

Create `test/core/deco/golden/golden_vector_test.dart`:

```dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/deco/ascent/ascent_gas_plan.dart';
import 'package:submersion/core/deco/buhlmann_algorithm.dart';
import 'package:submersion/core/deco/entities/breathing_config.dart';
import 'package:submersion/core/deco/entities/dive_environment.dart';

void main() {
  final file = File('test/core/deco/golden/vectors.json');
  final doc = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  final cases = (doc['cases'] as List).cast<Map<String, dynamic>>();

  for (final c in cases) {
    test('golden: ${c['name']}', () {
      final envJson = c['environment'] as Map<String, dynamic>;
      final env = DiveEnvironment(
        surfacePressureBar: (envJson['surface_pressure_bar'] as num)
            .toDouble(),
        waterDensityKgM3: (envJson['water_density_kg_m3'] as num).toDouble(),
      );
      final gf = (c['gf'] as List).cast<num>();
      final algo = BuhlmannAlgorithm(
        gfLow: gf[0] / 100.0,
        gfHigh: gf[1] / 100.0,
        environment: env,
      );

      for (final seg in (c['segments'] as List).cast<Map<String, dynamic>>()) {
        final setpoint = (seg['setpoint'] as num?)?.toDouble();
        final fN2 = (seg['f_n2'] as num).toDouble();
        final fHe = (seg['f_he'] as num).toDouble();
        algo.calculateSegment(
          depthMeters: (seg['avg_depth_m'] as num).toDouble(),
          durationSeconds: (seg['seconds'] as num).toInt(),
          fN2: fN2,
          fHe: fHe,
          breathing: setpoint != null
              ? ClosedCircuit(
                  setpoint: setpoint,
                  diluentFO2: 1.0 - fN2 - fHe,
                  diluentFHe: fHe,
                )
              : null,
        );
      }

      final expected = c['expected'] as Map<String, dynamic>;

      if (expected.containsKey('tissues_p_n2_bar')) {
        final expN2 = (expected['tissues_p_n2_bar'] as List).cast<num>();
        final expHe = (expected['tissues_p_he_bar'] as List).cast<num>();
        for (int i = 0; i < 16; i++) {
          expect(
            algo.compartments[i].currentPN2,
            closeTo(expN2[i].toDouble(), 5e-4),
            reason: '${c['name']} compartment ${i + 1} pN2',
          );
          expect(
            algo.compartments[i].currentPHe,
            closeTo(expHe[i].toDouble(), 5e-4),
            reason: '${c['name']} compartment ${i + 1} pHe',
          );
        }
      }

      if (expected.containsKey('ceiling_m')) {
        final depth = (c['segments'] as List).last['avg_depth_m'] as num;
        expect(
          algo.calculateCeiling(currentDepth: depth.toDouble()),
          closeTo((expected['ceiling_m'] as num).toDouble(), 0.5),
          reason: '${c['name']} ceiling',
        );
      }

      final schedDepth = c['schedule_from_depth_m'] as num?;
      if (schedDepth != null && expected.containsKey('stops')) {
        final gases = (c['gases'] as List)
            .cast<Map<String, dynamic>>()
            .map(
              (g) => AvailableGas(
                fN2: (g['f_n2'] as num).toDouble(),
                fHe: (g['f_he'] as num).toDouble(),
                maxPpO2Mod: (g['mod_m'] as num).toDouble(),
              ),
            )
            .toList();
        final plan = OptimalOcAscentGas(gases: gases, maxPpO2: 1.6);
        final stops = algo.calculateDecoSchedule(
          currentDepth: schedDepth.toDouble(),
          ascentGas: plan,
        );
        final expStops =
            (expected['stops'] as List).cast<Map<String, dynamic>>();
        expect(
          stops.length,
          expStops.length,
          reason: '${c['name']} stop count: '
              'got ${stops.map((s) => '${s.depthMeters}m/${s.durationSeconds}s')}',
        );
        for (int i = 0; i < expStops.length; i++) {
          expect(
            stops[i].depthMeters,
            (expStops[i]['depth_m'] as num).toDouble(),
            reason: '${c['name']} stop $i depth',
          );
          expect(
            stops[i].durationSeconds,
            closeTo((expStops[i]['seconds'] as num).toDouble(), 60),
            reason: '${c['name']} stop $i duration',
          );
        }
        final tts = algo.calculateTts(
          currentDepth: schedDepth.toDouble(),
          ascentGas: plan,
        );
        expect(
          tts,
          closeTo((expected['tts_seconds'] as num).toDouble(), 90),
          reason: '${c['name']} tts',
        );
      }
    });
  }
}
```

- [ ] **Step 4: Run and reconcile**

Run: `flutter test test/core/deco/golden/golden_vector_test.dart`

This is the cross-validation moment. If a case disagrees beyond tolerance, print both sides' stop lists and find the semantic divergence — work through pinned semantics 1-11 in order (anchor handling and TTS leg rounding are the two most likely culprits). Fix the PYTHON side unless the Dart side plainly violates its own pinned semantics (existing Dart tests define ground truth for legacy behavior). Regenerate `vectors.json` after any Python change. Do not widen tolerances to force a pass.

Expected once reconciled: ALL cases PASS.

- [ ] **Step 5: Write `scripts/deco_golden/README.md`**

```markdown
# Deco golden vectors

`generate_vectors.py` is an independent Python implementation of the
ZH-L16C + gradient-factor model, sharing pinned semantics with the Dart
engine (see docs/superpowers/plans/2026-07-05-dive-planner-phase1-engine.md,
Task 9). It generates `test/core/deco/golden/vectors.json`, which
`golden_vector_test.dart` replays against the Dart engine.

Regenerate after any intentional engine-semantics change:

    python3 scripts/deco_golden/generate_vectors.py > test/core/deco/golden/vectors.json

Never edit vectors.json by hand. Never derive expected values from an
LLM's recall — only from this script or a published external source.

Release gate: before each planner release, additionally compare a standard
plan set against MultiDeco by hand (see the design spec, Testing section).
```

- [ ] **Step 6: Commit**

```bash
dart format .
git add scripts/deco_golden/ test/core/deco/golden/
git commit -m "test(deco): golden-vector suite cross-validated against independent python model"
```

---

### Task 10: Property tests — model invariants

**Files:**
- Test: `test/core/deco/deco_property_test.dart`

**Interfaces:** consumes the engine API only; produces no new code.

- [ ] **Step 1: Write the tests**

Create `test/core/deco/deco_property_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/deco/buhlmann_algorithm.dart';
import 'package:submersion/core/deco/entities/dive_environment.dart';

int _tts({
  required double depth,
  required int bottomMinutes,
  double gfLow = 0.4,
  double gfHigh = 0.8,
  DiveEnvironment env = DiveEnvironment.standard,
}) {
  final algo = BuhlmannAlgorithm(
    gfLow: gfLow,
    gfHigh: gfHigh,
    environment: env,
  );
  algo.calculateSegment(
    depthMeters: depth,
    durationSeconds: bottomMinutes * 60,
  );
  return algo.calculateTts(currentDepth: depth);
}

void main() {
  group('deco invariants', () {
    test('longer bottom time never shortens TTS', () {
      for (final depth in [30.0, 45.0, 60.0]) {
        int previous = 0;
        for (int minutes = 10; minutes <= 60; minutes += 5) {
          final tts = _tts(depth: depth, bottomMinutes: minutes);
          expect(
            tts,
            greaterThanOrEqualTo(previous),
            reason: 'depth $depth, $minutes min',
          );
          previous = tts;
        }
      }
    });

    test('deeper dives never shorten TTS at fixed bottom time', () {
      int previous = 0;
      for (double depth = 20; depth <= 60; depth += 5) {
        final tts = _tts(depth: depth, bottomMinutes: 25);
        expect(tts, greaterThanOrEqualTo(previous), reason: 'depth $depth');
        previous = tts;
      }
    });

    test('raising GF-high never increases TTS', () {
      for (final depth in [40.0, 55.0]) {
        int? previous;
        for (double gfHigh = 0.6; gfHigh <= 0.95; gfHigh += 0.05) {
          final tts = _tts(
            depth: depth,
            bottomMinutes: 30,
            gfHigh: gfHigh,
          );
          if (previous != null) {
            expect(
              tts,
              lessThanOrEqualTo(previous),
              reason: 'depth $depth, gfHigh $gfHigh',
            );
          }
          previous = tts;
        }
      }
    });

    test('higher altitude never lengthens NDL', () {
      int? previous;
      for (double alt = 0; alt <= 3000; alt += 500) {
        final algo = BuhlmannAlgorithm(
          gfLow: 0.5,
          gfHigh: 0.8,
          environment: DiveEnvironment.forConditions(altitudeMeters: alt),
        );
        final ndl = algo.calculateNdl(depthMeters: 25);
        if (previous != null) {
          expect(ndl, lessThanOrEqualTo(previous), reason: 'altitude $alt');
        }
        previous = ndl;
      }
    });

    test('denser water never lengthens NDL at the same depth', () {
      int? previous;
      for (final density in [
        DiveEnvironment.freshWaterDensity,
        DiveEnvironment.brackishWaterDensity,
        DiveEnvironment.en13319Density,
        DiveEnvironment.saltWaterDensity,
      ]) {
        final algo = BuhlmannAlgorithm(
          gfLow: 0.5,
          gfHigh: 0.8,
          environment: DiveEnvironment(waterDensityKgM3: density),
        );
        final ndl = algo.calculateNdl(depthMeters: 30);
        if (previous != null) {
          expect(ndl, lessThanOrEqualTo(previous), reason: 'density $density');
        }
        previous = ndl;
      }
    });
  });
}
```

- [ ] **Step 2: Run**

Run: `flutter test test/core/deco/deco_property_test.dart`
Expected: PASS. Any failure here is an engine bug (or a genuinely surprising model property) — investigate before touching the test.

- [ ] **Step 3: Commit**

```bash
dart format .
git add test/core/deco/deco_property_test.dart
git commit -m "test(deco): property tests for deco model invariants"
```

---

### Task 11: Wire DiveEnvironment into the app's orchestrators

**Files:**
- Modify: `lib/features/dive_log/data/services/profile_analysis_service.dart` (constructor, ~line 467)
- Modify: `lib/features/dive_log/presentation/providers/profile_analysis_provider.dart` (`_resolveAnalysisService`, plus the bare `BuhlmannAlgorithm(...)` at ~line 1026)
- Modify: `lib/features/dive_planner/data/services/plan_calculator_service.dart` (`calculatePlan`, both `BuhlmannAlgorithm(...)` constructions at ~lines 73 and 451)
- Modify: `lib/features/dive_planner/presentation/providers/dive_planner_providers.dart` (`planResultsProvider` call site)
- Test: `test/features/dive_log/profile_analysis_environment_test.dart`

**Interfaces:**
- Consumes: `DiveEnvironment.forConditions` (Task 1). `Dive` already has `altitude` (meters, `double?`), `waterType` (`WaterType?`), and `surfacePressure` (bar, `double?`) — no schema change.
- Produces: `ProfileAnalysisService({..., DiveEnvironment environment = DiveEnvironment.standard})`; `PlanCalculatorService.calculatePlan({..., DiveEnvironment environment = DiveEnvironment.standard})`. Dive details and the planner now honor altitude/salinity. The deco calculator and surface-interval tool keep `DiveEnvironment.standard` implicitly (no edits).

- [ ] **Step 1: Write the failing test**

Create `test/features/dive_log/profile_analysis_environment_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/deco/entities/dive_environment.dart';
import 'package:submersion/features/dive_log/data/services/profile_analysis_service.dart';

void main() {
  // A square 30 m / 25 min profile sampled every 30 s.
  final depths = <double>[];
  final timestamps = <int>[];
  for (int t = 0; t <= 1620; t += 30) {
    timestamps.add(t);
    if (t < 120) {
      depths.add(30.0 * t / 120.0);
    } else if (t <= 1500) {
      depths.add(30.0);
    } else {
      depths.add(30.0 * (1620 - t) / 120.0);
    }
  }

  test('altitude environment yields shorter NDL in the analysis', () {
    final seaLevel = ProfileAnalysisService(gfLow: 0.5, gfHigh: 0.8);
    final altitude = ProfileAnalysisService(
      gfLow: 0.5,
      gfHigh: 0.8,
      environment: DiveEnvironment.forConditions(altitudeMeters: 2500),
    );

    final seaAnalysis = seaLevel.analyze(
      diveId: 'test',
      depths: depths,
      timestamps: timestamps,
    );
    final altAnalysis = altitude.analyze(
      diveId: 'test',
      depths: depths,
      timestamps: timestamps,
    );

    // Mid-bottom NDL is shorter at altitude.
    final mid = depths.length ~/ 2;
    expect(
      altAnalysis.ndlCurve[mid],
      lessThan(seaAnalysis.ndlCurve[mid]),
    );
  });
}
```

(Adjust the `analyze` call's named parameters to the real signature — read the method before writing; the parameters shown are the minimum from its docs. If `analyze` requires more arguments, supply their simplest values as existing tests under `test/features/dive_log/` do.)

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/dive_log/profile_analysis_environment_test.dart`
Expected: FAIL — `environment` parameter does not exist.

- [ ] **Step 3: Implement**

1. `ProfileAnalysisService`: add `DiveEnvironment environment = DiveEnvironment.standard` to the constructor and pass `environment: environment` into its `BuhlmannAlgorithm(...)` initializer.

2. `profile_analysis_provider.dart`: in `_resolveAnalysisService` (which already reads per-dive GF), build and pass the environment from the dive:

```dart
    final environment = DiveEnvironment.forConditions(
      altitudeMeters: dive.altitude,
      waterType: dive.waterType,
      surfacePressureBar: dive.surfacePressure,
    );
```

and pass `environment: environment` to the `ProfileAnalysisService(...)` construction there. For the settings-only `profileAnalysisServiceProvider` (no dive in scope) leave the default. At line ~1026 (`BuhlmannAlgorithm(gfLow: gfLow, gfHigh: gfHigh)`): check whether a `Dive` is in scope in that provider; if yes, pass `environment: DiveEnvironment.forConditions(altitudeMeters: dive.altitude, waterType: dive.waterType, surfacePressureBar: dive.surfacePressure)`; if not, leave it (standard default).

3. `PlanCalculatorService.calculatePlan`: add parameter `DiveEnvironment environment = DiveEnvironment.standard`, pass `environment: environment` to BOTH `BuhlmannAlgorithm(...)` constructions (lines ~73 and ~451 — the second is in `calculateSurfaceInterval`; give that method the same optional parameter).

4. `dive_planner_providers.dart`: in `planResultsProvider`, where `calculatePlan` is invoked, pass:

```dart
      environment: DiveEnvironment.forConditions(
        altitudeMeters: state.altitude > 0 ? state.altitude : null,
      ),
```

(`state.altitude` is non-null with default 0 in `DivePlanState`; treat 0 as sea level legacy. Water type comes to the planner in Phase 2.)

- [ ] **Step 4: Run tests and full verification**

```bash
flutter test test/features/dive_log/profile_analysis_environment_test.dart
flutter test test/core/deco/
flutter analyze
dart format .
```
Expected: new test PASS, deco suite PASS, analyze clean, format no changes. Then run the existing analysis/planner test files: `ls test/features/dive_log/ test/features/dive_planner/` and run each file that mentions `profile_analysis` or `plan_calculator` individually.

- [ ] **Step 5: Commit**

```bash
git add lib/features/dive_log/data/services/profile_analysis_service.dart lib/features/dive_log/presentation/providers/profile_analysis_provider.dart lib/features/dive_planner/data/services/plan_calculator_service.dart lib/features/dive_planner/presentation/providers/dive_planner_providers.dart test/features/dive_log/profile_analysis_environment_test.dart
git commit -m "feat(deco): honor dive altitude and water type in analysis and planning"
```

---

## Completion checklist (run after Task 11)

- [ ] `flutter test test/core/deco/` — all green (including golden + property suites)
- [ ] `flutter analyze` — no new issues
- [ ] `dart format .` — no changes
- [ ] The engine API is now FROZEN for Phase 2-7 parallel work: `DiveEnvironment`, `BreathingConfig`, `SchedulePolicy`, `DecoModel`/`BuhlmannGf`, `restoreState`, `pressureAfterConsuming`
- [ ] Known Phase 1 limitations carried forward (documented in the spec): deco SCHEDULES still breathe OC even for CCR loading (Phase 4 adds loop deco/bailout schedules); measured-ppO2-driven CCR loading (vs setpoint) is Phase 4; air-break CNS bookkeeping stays in `O2ToxicityCalculator` unchanged
