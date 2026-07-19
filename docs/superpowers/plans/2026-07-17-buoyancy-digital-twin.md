# Buoyancy Digital Twin Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Model net buoyancy through a dive (cylinder swing, suit compression) and surface a diagnosis + chart on dive detail, plus forward simulation in the Dive Planner and Weight Planner, per the approved spec `docs/superpowers/specs/2026-07-17-buoyancy-digital-twin-design.md`.

**Architecture:** A pure-Dart simulator in `lib/core/buoyancy/` composes the existing weight-prediction pieces (`BuoyancyPhysics`, `FittedWeightModel`) with `DiveEnvironment` (from `core/deco`) for depth-to-pressure. Feature glue assembles inputs from the dive log, runs the simulator in a `compute` isolate behind a `FutureProvider.family`, and three UI surfaces consume one result type.

**Tech Stack:** Flutter 3 / Material 3, Drift, Riverpod, fl_chart, gen-l10n.

## Global Constraints

- All work happens in worktree `.claude/worktrees/buoyancy-digital-twin`, branch `worktree-buoyancy-digital-twin`. Never touch the main checkout.
- `lib/core/buoyancy/` stays pure Dart: no Flutter imports (import of `core/deco` entities is fine — they are pure too).
- Sign convention everywhere: **positive kg = buoyant = needs lead; negative = sinks**.
- Storage and math in metric (kg, meters, bar, liters). Display only via `UnitFormatter` (`lib/core/utils/unit_formatter.dart`): `formatWeight`, `formatDepth`, `formatPressure`, `formatVolume`.
- Every new user-facing string goes into ALL 11 arb files (`lib/l10n/arb/app_en.arb` + ar, de, es, fr, he, hu, it, nl, pt, zh), then run `flutter gen-l10n` (config in `l10n.yaml`; generated files under `lib/l10n/arb/` are checked in and must be committed).
- No emojis in code, comments, or docs. Comments state constraints only, never narrate.
- After each task: `dart format .` (whole project — repo rule), then `flutter analyze` with NO pipe to `tail`/`head` (piping masks the exit code; run it bare).
- Run only the test files you created/changed (`flutter test <path>`), never the whole suite mid-task.
- Commits per task are preauthorized. Conventional-commit style (`feat(buoyancy): ...`). NO Co-Authored-By line, no session URLs.
- Test vectors in this plan were computed with python3 on 2026-07-17 (not recalled). If you change a constant, recompute with python3 — do not adjust expectations by hand.
- Existing key APIs you will consume (verified 2026-07-17):
  - `BuoyancyPhysics` (`lib/core/buoyancy/buoyancy_physics.dart`): `airDensityKgPerLBar = 0.001225`, `defaultReserveBar = 50.0`, `tankTermKg(...)`, `tankDryMassKg(...)`, `waterTermKg(...)`, `kTankCatalog`.
  - `FittedWeightModel` (`lib/core/buoyancy/weight_prediction_engine.dart:293`): `personalCoefficient`, `coefficientsById: Map<String,double>`, `usageCounts`, `supportingDives`, `predict(RigSpec)`; `TermSource {measured, userSpec, typeDefault, physics}`; `PredictionTerm{label,kg,source}`.
  - `GearFeature.fromEquipment` / `gearFeatureFor(EquipmentItem)` (`lib/features/weight_planner/presentation/providers/weight_planner_providers.dart:18`) returns null for `weights`/`tank` types.
  - `DiveEnvironment` (`lib/core/deco/entities/dive_environment.dart`): `forConditions({altitudeMeters, waterType, surfacePressureBar})`, `pressureAtDepth(m)`, `surfacePressureBar`, `waterDensityKgM3`.
  - `Dive` (`lib/features/dive_log/domain/entities/dive.dart`): `profile: List<DiveProfilePoint>{timestamp(s), depth(m)}`, `tanks: List<DiveTank>{volume, workingPressure, startPressure, endPressure, gasMix(o2,he), material, presetName, id}`, `weights: List<DiveWeight>`, `weightAmount`, `equipment: List<EquipmentItem>`, `isGauge`, `waterType`, `altitude` (verify exact altitude field name in dive.dart when wiring).
  - `tankPressuresProvider(diveId)` (`lib/features/dive_log/presentation/providers/dive_providers.dart:996`): `FutureProvider.family<Map<String, List<TankPressurePoint>>, String>` keyed by tank id; `TankPressurePoint{tankId, timestamp(s), pressure(bar)}`.
  - `analysisDiveProvider(diveId)` (`lib/features/dive_log/presentation/providers/profile_analysis_provider.dart:733`): lean, primary-profile hydration used by deco analysis. Use it (NOT a raw profile query) — the #536 trap is unfiltered profiles double-counting.
  - `weightCalibrationProvider`, `weightObservationsProvider`, `latestDiverWeightProvider`, `allEquipmentProvider` — see `weight_planner_providers.dart`.
  - `WeightObservation` (`lib/core/buoyancy/weight_observation.dart`): `carriedKg`, `placement: Map<String,double>` keyed by `WeightType.name`, `equipmentIds`, `feedback`, `feedbackKg`, `diveDateTime`.
  - `WeightType` enum: `belt, integrated, ankleWeights, trimWeights, backplate, mixed`.
  - `DiveDetailSectionId` + `DiveDetailSectionConfig` (`lib/core/constants/dive_detail_sections.dart`) — `ensureAllSections` auto-appends new enum values for existing users.
  - Planner: `PlanSegment{startDepth, endDepth, durationSeconds, tankId}` (`lib/features/dive_planner/domain/entities/plan_segment.dart`), `GasConsumption{tankId?, startPressure, remainingPressure}` (`plan_result.dart:128`), section widget `lib/features/dive_planner/presentation/widgets/plan_gear_weights_section.dart`.

---

### Task 1: Gas mix density module

**Files:**
- Create: `lib/core/buoyancy/gas_density.dart`
- Test: `test/core/buoyancy/gas_density_test.dart`

**Interfaces:**
- Consumes: `BuoyancyPhysics.airDensityKgPerLBar`.
- Produces: `GasDensity.mixDensityKgPerLBar({required double o2Percent, required double hePercent}) -> double` — used by Task 3.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/buoyancy/gas_density.dart';

void main() {
  group('GasDensity.mixDensityKgPerLBar', () {
    // Vectors computed with python3 (molar masses O2 31.998, N2 28.014,
    // He 4.0026, air 28.9647; scaled so air matches 0.001225 kg/L/bar).
    test('21/0 is near the air constant', () {
      expect(
        GasDensity.mixDensityKgPerLBar(o2Percent: 21, hePercent: 0),
        closeTo(0.0012201760763964412, 1e-9),
      );
    });

    test('EAN32 is denser than air', () {
      expect(
        GasDensity.mixDensityKgPerLBar(o2Percent: 32, hePercent: 0),
        closeTo(0.0012387104993319452, 1e-9),
      );
    });

    test('Tx 18/45 is much lighter than air', () {
      expect(
        GasDensity.mixDensityKgPerLBar(o2Percent: 18, hePercent: 45),
        closeTo(0.0007581413841676246, 1e-9),
      );
    });

    test('pure oxygen', () {
      expect(
        GasDensity.mixDensityKgPerLBar(o2Percent: 100, hePercent: 0),
        closeTo(0.0013532869320241534, 1e-9),
      );
    });

    test('density scales linearly with molar mass (monotone in He)', () {
      final lighter =
          GasDensity.mixDensityKgPerLBar(o2Percent: 21, hePercent: 30);
      final air = GasDensity.mixDensityKgPerLBar(o2Percent: 21, hePercent: 0);
      expect(lighter, lessThan(air));
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/buoyancy/gas_density_test.dart`
Expected: FAIL — `gas_density.dart` does not exist / `GasDensity` undefined.

- [ ] **Step 3: Write the implementation**

```dart
import 'package:submersion/core/buoyancy/buoyancy_physics.dart';

/// Mass density of breathing-gas mixes per liter of cylinder volume per bar.
///
/// Component molar masses are scaled so that atmospheric air reproduces
/// [BuoyancyPhysics.airDensityKgPerLBar] exactly, keeping the twin's tank
/// math consistent with the static weight-prediction engine.
class GasDensity {
  static const double _molarMassO2 = 31.998;
  static const double _molarMassN2 = 28.014;
  static const double _molarMassHe = 4.0026;
  static const double _molarMassAir = 28.9647;

  static double mixDensityKgPerLBar({
    required double o2Percent,
    required double hePercent,
  }) {
    final o2 = o2Percent / 100.0;
    final he = hePercent / 100.0;
    final n2 = (1.0 - o2 - he).clamp(0.0, 1.0);
    final molarMass =
        o2 * _molarMassO2 + n2 * _molarMassN2 + he * _molarMassHe;
    return BuoyancyPhysics.airDensityKgPerLBar * molarMass / _molarMassAir;
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/buoyancy/gas_density_test.dart`
Expected: PASS (5 tests).

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add lib/core/buoyancy/gas_density.dart test/core/buoyancy/gas_density_test.dart
git commit -m "feat(buoyancy): gas mix density module for cylinder swing"
```

---

### Task 2: Suit compression module

**Files:**
- Create: `lib/core/buoyancy/suit_compression.dart`
- Test: `test/core/buoyancy/suit_compression_test.dart`

**Interfaces:**
- Consumes: nothing new (pure math).
- Produces (used by Tasks 3-4):
  - `SuitCompression.kNeopreneResidualFraction = 0.3`
  - `SuitCompression.surfaceFromAnchor({required double anchorKg, required double anchorPressureBar, required double surfacePressureBar}) -> double`
  - `SuitCompression.buoyancyAtPressure({required double surfaceKg, required double pressureBar, required double surfacePressureBar}) -> double`
  - `SuitCompression.loftLitersFromBuoyancy({required double suitTermKg, required double waterDensityKgL}) -> double`
  - `SuitCompression.drysuitGasLiters({required double loftLiters, required List<double> pressuresBar}) -> double`

- [ ] **Step 1: Write the failing test**

```dart
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/buoyancy/suit_compression_test.dart`
Expected: FAIL — `SuitCompression` undefined.

- [ ] **Step 3: Write the implementation**

```dart
/// Neoprene exposure-suit buoyancy versus pressure, and the drysuit gas
/// budget. Pure math; pressures come from DiveEnvironment at call sites.
///
/// Model: suit buoyancy = incompressible residual + gas fraction obeying
/// Boyle's law. The residual fraction is a global engine constant; the
/// per-diver anchor value comes from the fitted weight model (which
/// represents the suit near the safety stop) and is inverted to a surface
/// value through [surfaceFromAnchor].
class SuitCompression {
  /// Fraction of surface buoyancy that does not compress (solid rubber,
  /// trapped-cell floor). Initial value from published neoprene
  /// compression data; recompute test vectors if changed.
  static const double kNeopreneResidualFraction = 0.3;

  /// Inversion guard: a fitted anchor can be noisy; the recovered surface
  /// buoyancy is clamped to [anchorKg, kMaxSurfaceToAnchorRatio*anchorKg].
  static const double kMaxSurfaceToAnchorRatio = 3.0;

  static double surfaceFromAnchor({
    required double anchorKg,
    required double anchorPressureBar,
    required double surfacePressureBar,
  }) {
    if (anchorKg <= 0) return 0.0;
    final pRel = anchorPressureBar / surfacePressureBar;
    const r = kNeopreneResidualFraction;
    final surface = anchorKg / (r + (1 - r) / pRel);
    return surface.clamp(anchorKg, kMaxSurfaceToAnchorRatio * anchorKg);
  }

  static double buoyancyAtPressure({
    required double surfaceKg,
    required double pressureBar,
    required double surfacePressureBar,
  }) {
    final pRel = pressureBar / surfacePressureBar;
    const r = kNeopreneResidualFraction;
    return surfaceKg * (r + (1 - r) / pRel);
  }

  static double loftLitersFromBuoyancy({
    required double suitTermKg,
    required double waterDensityKgL,
  }) => suitTermKg <= 0 ? 0.0 : suitTermKg / waterDensityKgL;

  /// Surface-equivalent liters the diver must add to hold constant loft
  /// across the descents in [pressuresBar] (vents on ascent are free).
  static double drysuitGasLiters({
    required double loftLiters,
    required List<double> pressuresBar,
  }) {
    var total = 0.0;
    for (var i = 1; i < pressuresBar.length; i++) {
      final delta = pressuresBar[i] - pressuresBar[i - 1];
      if (delta > 0) total += loftLiters * delta;
    }
    return total;
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/buoyancy/suit_compression_test.dart`
Expected: PASS (8 tests).

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add lib/core/buoyancy/suit_compression.dart test/core/buoyancy/suit_compression_test.dart
git commit -m "feat(buoyancy): neoprene compression curve and drysuit gas budget"
```

---

### Task 3: Twin input types and per-sample simulator

**Files:**
- Create: `lib/core/buoyancy/buoyancy_twin.dart`
- Test: `test/core/buoyancy/buoyancy_twin_test.dart`

**Interfaces:**
- Consumes: `GasDensity` (Task 1), `SuitCompression` (Task 2), `BuoyancyPhysics`, `DiveEnvironment`, `TermSource` (existing).
- Produces (used by Tasks 4, 6, 12, 13, 14):

```dart
class TwinProfileSample { final int timestamp; final double depthM; }
class TwinPressureSample { final int timestamp; final double pressureBar; }
class TwinTankInput {
  final String id; final String label;
  final String? presetName; final double? volumeL;
  final double? workingPressureBar; final TankMaterial? material;
  final double o2Percent; final double hePercent;
  final double? startPressureBar; final double? endPressureBar;
  final List<TwinPressureSample>? pressureSeries; // measured; null = interpolate
}
enum TwinSuitKind { none, wetsuit, drysuit }
class TwinSuitInput { final TwinSuitKind kind; final double anchorKg; final TermSource source; }
class TwinStaticTerm { final String label; final double kg; final TermSource source; }
class TwinInput {
  final List<TwinProfileSample> profile; // empty = no-profile dive
  final List<TwinTankInput> tanks;
  final TwinSuitInput suit;
  final List<TwinStaticTerm> staticTerms; // personal, non-suit gear, water
  final double leadKg; final double droppableLeadKg;
  final DiveEnvironment environment;
}
class TwinSample {
  final int timestamp; final double depthM;
  final double suitKg; final double tanksKg; final double netKg;
}
class BuoyancyTwinResult {
  final List<TwinSample> samples;
  final double staticKg;          // sum(staticTerms)
  final double suitSurfaceKg;     // 0 for none/drysuit
  final double drysuitGasLiters;  // 0 unless drysuit
  final bool pressuresEstimated;  // true if any tank lacked a measured series
  final TwinInput input;          // echoed for analyzers and what-if
}
BuoyancyTwinResult runBuoyancyTwin(TwinInput input); // top-level, compute()-safe
double twinTankKgAt(TwinTankInput tank, double pressureBar); // exposed for tests/analyzer
double twinTankPressureAt(TwinTankInput tank, int timestamp, int firstTs, int lastTs);
```

Simulator semantics (implement exactly):
- Suit term per sample: `none` -> 0; `wetsuit` -> invert anchor once via `surfaceFromAnchor` (anchor pressure = `environment.pressureAtDepth(5.0)`), then `buoyancyAtPressure` at each sample; `drysuit` -> constant `anchorKg` every sample, plus `drysuitGasLiters` from the per-sample ambient pressures and `loftLitersFromBuoyancy(anchorKg, environment.waterDensityKgM3 / 1000.0)` (the kg/m3-to-kg/L conversion happens HERE and only here).
- Tank pressure at time t: with a measured series, linear interpolation between neighboring samples (clamp before first / after last); without, linear from `startPressureBar` to `endPressureBar` by time fraction `(t - firstTs)/(lastTs - firstTs)`; a tank with neither start nor end pressure contributes `emptyBuoyancy - gasMass(reserve 50 bar)` constant (the static convention) and sets `pressuresEstimated`.
- Tank term: `BuoyancyPhysics.tankTermKg(presetName:, volumeL:, workingPressureBar:, material:, reserveBar: 0.0)` gives the EMPTY buoyancy (reserve 0 subtracts nothing); subtract `volume * pressure * GasDensity.mixDensityKgPerLBar(...)`. Resolve volume the same way `tankTermKg` does: `volumeL ?? TankPresets.byName(presetName)?.volumeLiters ?? 11.0`.
- `net = suitKg + tanksKg + staticKg - leadKg`.
- Empty profile: `samples` empty; the analyzer (Task 4) handles the static fallback.

- [ ] **Step 1: Write the failing test** — cover, with a two-tank synthetic dive (square profile 0->30 m->0, 60 samples):
  - net at a mid-dive sample equals the hand-composed sum of terms (compose expected value IN the test from `twinTankKgAt` + `SuitCompression.buoyancyAtPressure` + constants, not a magic number).
  - measured-series tank: pressure at a timestamp between two samples interpolates linearly (series [(0,200),(600,100)] at t=300 -> 150 bar exactly).
  - interpolated tank at last sample uses endPressure exactly.
  - tank with no pressures: constant term, `pressuresEstimated` true.
  - air tank, V=11.0, empty buoyancy from explicit `presetName: null, material: aluminum` path at 200 bar vs 50 bar: swing matches python vectors -0.9843873680721706 -> +1.0289031579819574 given empty buoyancy +1.65 (= 11.0*0.15). Adjust: with the per-material fallback the empty value is `11.0 * 0.15 = 1.65`, so assert `twinTankKgAt(tank, 200)` == closeTo(1.65 - 11.0*200*0.0012201760763964412, 1e-9) — compose, don't hardcode.
  - drysuit input: suit term constant across samples; `drysuitGasLiters > 0` for a descent.
  - wetsuit: suit term at the 5 m samples closeTo(anchorKg).
- [ ] **Step 2: Run test to verify it fails** — `flutter test test/core/buoyancy/buoyancy_twin_test.dart` — FAIL (types undefined).
- [ ] **Step 3: Implement `buoyancy_twin.dart`** exactly per the interface block above. All classes const-constructible with named required params; no Flutter imports. `runBuoyancyTwin` must be a top-level function (isolate entry point).
- [ ] **Step 4: Run test to verify it passes** — same command, PASS.
- [ ] **Step 5: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add lib/core/buoyancy/buoyancy_twin.dart test/core/buoyancy/buoyancy_twin_test.dart
git commit -m "feat(buoyancy): per-sample buoyancy twin simulator"
```

---

### Task 4: Anchor detection and derived outputs

**Files:**
- Create: `lib/core/buoyancy/twin_analyzer.dart`
- Test: `test/core/buoyancy/twin_analyzer_test.dart`

**Interfaces:**
- Consumes: `BuoyancyTwinResult`, `TwinInput`, `TwinSample`, `twinTankKgAt` (Task 3), `SuitCompression`.
- Produces (used by Tasks 6, 9-14):

```dart
enum TwinAnchorKind { detectedStop, shallowWindow, convention }
class TwinAnchor { final TwinAnchorKind kind; final int timestamp; final double depthM; }
class TwinVerdict {
  final TwinAnchor anchor;
  final double netKg;
  final List<TwinStaticTerm> terms; // suit@anchor, each tank@anchor, statics, lead (negative)
}
class TwinOutputs {
  final double beginNetKg; final double endNetKg;
  final double peakLiftDemandKg;
  final double minDitchableKg; final double droppableLeadKg;
  final double idealLeadKg;
  final TwinVerdict verdict;
  final double drysuitGasLiters;
}
class TwinAnalyzer {
  static const double kAnchorMaxDepthM = 9.0;
  static const double kAnchorMaxRangeM = 1.5;
  static const int kAnchorMinDurationS = 60;
  static const double kSurfaceDepthM = 1.0;
  static const double kDitchableMarginKg = 2.0;
  static TwinOutputs analyze(BuoyancyTwinResult result);
}
```

Semantics (implement exactly):
- Anchor: scan `samples` from the end for the last contiguous run with every depth in `(kSurfaceDepthM, kAnchorMaxDepthM]` and `max-min <= kAnchorMaxRangeM` lasting `>= kAnchorMinDurationS`; anchor = the run's middle sample (`detectedStop`). Fallback: the 60 s window with the lowest mean depth among samples deeper than `kSurfaceDepthM` in the last third of the dive (`shallowWindow`). Empty profile: evaluate statically at 5 m with tanks at `endPressureBar ?? reserve 50` (`convention`, timestamp -1).
- `beginNetKg`/`endNetKg`: first/last sample with `depthM > kSurfaceDepthM`; empty profile -> evaluate at 5 m with start pressures (begin) and end pressures (end).
- `peakLiftDemandKg = max over samples of max(0, -netKg)` (0 when no samples).
- `minDitchableKg = max(0, kDitchableMarginKg - worstNet)` where `worstNet = min over samples of netKg` (empty profile: use beginNetKg).
- `idealLeadKg = input.leadKg + verdict.netKg`, clamped `>= 0`.
- Verdict terms: recompute suit and each tank at the anchor sample's pressure via the Task 3 helpers; append every `staticTerms` entry; append `TwinStaticTerm(label: 'lead', kg: -input.leadKg, source: TermSource.measured)`.

- [ ] **Step 1: Write the failing test** — synthetic profiles:
  - square 30 m dive with a 5 m x 3 min stop at the end: anchor kind `detectedStop`, anchor depth closeTo(5, 0.5); verdict terms sum closeTo(verdict.netKg, 1e-9).
  - profile with no stop (direct ascent): anchor kind `shallowWindow`.
  - empty profile: anchor kind `convention`; begin/end computed from start/end pressures.
  - `minDitchableKg`: craft input with worstNet -4.5 -> expect closeTo(6.5, 1e-9) (python: max(0, 2-(-4.5))).
  - `peakLiftDemandKg` equals `-worstNet` when worstNet < 0.
  - `idealLeadKg`: leadKg 6.0, verdict net +1.8 -> 7.8.
- [ ] **Step 2: Run to verify it fails.** `flutter test test/core/buoyancy/twin_analyzer_test.dart`
- [ ] **Step 3: Implement `twin_analyzer.dart`.**
- [ ] **Step 4: Run to verify it passes.**
- [ ] **Step 5: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add lib/core/buoyancy/twin_analyzer.dart test/core/buoyancy/twin_analyzer_test.dart
git commit -m "feat(buoyancy): anchor detection and derived twin outputs"
```

---

### Task 5: Static-engine agreement test

**Files:**
- Test: `test/core/buoyancy/twin_static_agreement_test.dart`

**Interfaces:** consumes Tasks 1-4 plus `WeightPredictionEngine.fit` / `FittedWeightModel.predict`; produces nothing new — this is a pure invariant guard.

- [ ] **Step 1: Write the test** — build a `FittedWeightModel` via `WeightPredictionEngine.fit` with zero observations (pure priors), a rig with one wetsuit `GearFeature` and one `TankSpec(volumeL: 11.0, material: TankMaterial.aluminum)`, salt water, body weight 75. Take `prediction.totalKg` as lead. Build the equivalent `TwinInput`: single profile sample at depth 5.0 m, tank at 50 bar (the reserve convention), suit anchor = the model's suit coefficient/prior, staticTerms = the prediction's personal + water terms. Assert `runBuoyancyTwin(...).samples.single.netKg` is `closeTo(0.0, 0.05)` — the twin evaluated at the static convention must agree with the static engine (tolerance covers the air-vs-21/79 density delta and salt barPerMeter vs the 10 m/bar convention).
- [ ] **Step 2: Run it** — `flutter test test/core/buoyancy/twin_static_agreement_test.dart`. If it fails outside tolerance, the sign conventions or reserve handling diverged — fix the twin, not the tolerance. Document the residual in a test comment.
- [ ] **Step 3: Commit**

```bash
dart format .
flutter analyze
git add test/core/buoyancy/twin_static_agreement_test.dart
git commit -m "test(buoyancy): twin agrees with static engine at the weighting convention"
```

---

### Task 6: Assembly service and dive provider

**Files:**
- Create: `lib/features/dive_log/data/services/buoyancy_twin_assembler.dart`
- Create: `lib/features/dive_log/presentation/providers/buoyancy_twin_provider.dart`
- Test: `test/features/dive_log/data/services/buoyancy_twin_assembler_test.dart`

**Interfaces:**
- Consumes: `Dive`, `TankPressurePoint`, `FittedWeightModel`, `EquipmentItem`, `gearFeatureFor`, Tasks 3-4 types.
- Produces:

```dart
class BuoyancyTwinOutcome {
  final BuoyancyTwinResult result;
  final TwinOutputs outputs;
  final double? wingLiftCapacityKg; // Task 7 fills this in; null until then
}
class BuoyancyTwinAssembler {
  /// Null when there is nothing to model (no tanks AND no suit; covers apnea).
  static TwinInput? assemble({
    required Dive dive,
    required Map<String, List<TankPressurePoint>> tankPressures,
    required FittedWeightModel model,
    required double? bodyWeightKg,
  });
  static double droppableLeadKg(Dive dive); // ditchability map
}
final buoyancyTwinProvider =
    FutureProvider.family<BuoyancyTwinOutcome?, String>; // keyed by diveId
```

Assembly rules (implement exactly):
- Profile: `dive.profile` mapped to `TwinProfileSample` (it is the primary profile via `analysisDiveProvider` — do not query profiles directly).
- Tanks: each `DiveTank` -> `TwinTankInput` with `pressureSeries` from `tankPressures[tank.id]` when non-empty (sorted by timestamp).
- Suit: first `dive.equipment` item with type `wetsuit` or `drysuit`; anchor = `model.coefficientsById[item.id]`, else `gearFeatureFor(item)!.priorKg`; source `measured` when fitted and `(model.usageCounts[item.id] ?? 0) >= 3`, `userSpec` when `item.buoyancyKg != null`, else `typeDefault`. Non-positive anchor -> fall back to the prior (spec rule).
- Static terms: `personal` (= `model.personalCoefficient`); every non-suit, non-null `gearFeatureFor` item as its fitted-or-prior kg; `water` via `BuoyancyPhysics.waterTermKg(waterType: dive.waterType, totalMassKg: body + gear dry + tank dry)` exactly as `FittedWeightModel.predict` composes it.
- Lead: sum of `dive.weights` `amountKg`; empty -> `dive.weightAmount ?? 0`.
- `droppableLeadKg`: `belt` and `integrated` rows droppable; `ankleWeights`, `trimWeights`, `backplate`, `mixed` fixed (conservative). Legacy scalar: droppable unless the dive's legacy weight-type field maps to a fixed type; verify the Dive field name (`weightType`) in `dive.dart` while implementing.
- Environment: `DiveEnvironment.forConditions(altitudeMeters: <dive altitude field>, waterType: dive.waterType)`.
- Return null when `dive.tanks.isEmpty && suit == null`.

Provider (in `buoyancy_twin_provider.dart`):

```dart
final buoyancyTwinProvider =
    FutureProvider.family<BuoyancyTwinOutcome?, String>((ref, diveId) async {
  final dive = await ref.watch(analysisDiveProvider(diveId).future);
  if (dive == null) return null;
  final model = await ref.watch(weightCalibrationProvider.future);
  final tankPressures = await ref.watch(tankPressuresProvider(diveId).future);
  final latestWeight = await ref.watch(latestDiverWeightProvider.future);
  final input = BuoyancyTwinAssembler.assemble(
    dive: dive,
    tankPressures: tankPressures,
    model: model,
    bodyWeightKg: latestWeight?.weightKg,
  );
  if (input == null) return null;
  final result = await compute(runBuoyancyTwin, input);
  return BuoyancyTwinOutcome(
    result: result,
    outputs: TwinAnalyzer.analyze(result),
    wingLiftCapacityKg: null,
  );
});
```

(`analysisDiveProvider` already self-invalidates on dive changes; `tankPressuresProvider` on detail changes; `weightCalibrationProvider` on history/gear/body changes — do not add extra watchers.)

- [ ] **Step 1: Write the failing assembler test** — pure unit test on `assemble` (no database): construct a `Dive` with two tanks, weights rows (belt 4.0 + trimWeights 2.0), a wetsuit `EquipmentItem`, and a fitted model from `WeightPredictionEngine.fit` with zero observations. Assert: lead 6.0; droppable 4.0; suit anchor equals the wetsuit prior; static terms contain `personal` and `water`; null returned for a dive with no tanks and no suit; drysuit item maps to `TwinSuitKind.drysuit`.
- [ ] **Step 2: Run to verify it fails.** `flutter test test/features/dive_log/data/services/buoyancy_twin_assembler_test.dart`
- [ ] **Step 3: Implement assembler + provider.**
- [ ] **Step 4: Run to verify it passes.**
- [ ] **Step 5: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add lib/features/dive_log/data/services/buoyancy_twin_assembler.dart lib/features/dive_log/presentation/providers/buoyancy_twin_provider.dart test/features/dive_log/data/services/buoyancy_twin_assembler_test.dart
git commit -m "feat(dive-log): assemble and provide buoyancy twin per dive"
```

---

### Task 7: Wing lift capacity capture

**Files:**
- Modify: `lib/core/database/database.dart` (Equipment table ~line 690-705; `currentSchemaVersion` at line 2208; the `onUpgrade` ladder)
- Modify: `lib/features/equipment/domain/entities/equipment_item.dart`
- Modify: equipment repository mapping + every exporter/backup site that maps `buoyancyKg` (find them all: `grep -rn "buoyancyKg" lib --include="*.dart"` and mirror each)
- Modify: `lib/features/equipment/presentation/pages/equipment_edit_page.dart` (Advanced group, near the existing buoyancy field ~line 120/918)
- Modify: all 11 arb files + `flutter gen-l10n`
- Modify: `lib/features/dive_log/presentation/providers/buoyancy_twin_provider.dart` (fill `wingLiftCapacityKg` from the dive's bcd item)
- Test: migration test mirroring the newest `test/core/database/migration_*` file; edit-page widget test addition

**Interfaces:**
- Produces: `EquipmentItem.liftCapacityKg: double?` — the ONLY way any other task reads lift capacity.

- [ ] **Step 1: Decide the storage mechanism.** Run `env -u GITHUB_TOKEN gh pr view 608 --json state`. If MERGED (equipment-attributes KV landed): add `liftCapacityKg` as an attribute-catalog entry for the bcd type following that PR's catalog pattern, expose the same `EquipmentItem.liftCapacityKg` getter, and skip the migration steps below. If OPEN (expected): take the column path below.
- [ ] **Step 2: Verify the schema-version claim.** Read `currentSchemaVersion` in `database.dart` on THIS branch (112 at plan time) and the memory file `project_schema_version_ladder_claims.md`. Claim the next FREE ladder number (v119 as of 2026-07-17 — re-verify; several open PRs hold v113-v118). Use that number below wherever `<NEXT>` appears, and update the ladder memory file with the claim.
- [ ] **Step 3: Write the failing migration test** — copy the structure of the newest existing migration test under `test/core/database/`, asserting: a database at the previous version upgrades to `<NEXT>` and `equipment.liftCapacityKg` is queryable/null, existing equipment rows survive, and a fresh `onCreate` database has the column.
- [ ] **Step 4: Run it** — expected FAIL (column missing).
- [ ] **Step 5: Implement the column path**
  - In the `Equipment` table, after `weightKg` (line ~703): `RealColumn get liftCapacityKg => real().nullable()();`
  - Bump `currentSchemaVersion` to `<NEXT>`; add to the `onUpgrade` ladder, following the existing per-version blocks exactly: `if (from < <NEXT>) { await m.addColumn(equipment, equipment.liftCapacityKg); }`
  - `dart run build_runner build --delete-conflicting-outputs`
  - `EquipmentItem`: add `final double? liftCapacityKg;` + constructor param + `copyWith` + `props`, matching how `buoyancyKg` is threaded.
  - Mirror every `buoyancyKg` mapping site found by the grep (repository toDomain/toCompanion, JSON export/import, backup/restore, sync changeset field list if equipment columns are enumerated anywhere). The column rides the existing equipment HLC sync — no new tables, no tombstones.
- [ ] **Step 6: Run the migration test** — PASS.
- [ ] **Step 7: Edit-page field** — in the Advanced group next to the buoyancy field: a `TextFormField` shown only when the selected type is `EquipmentType.bcd`, storing kg via the same convert-on-save pattern as `_buoyancyController` (lines ~120 and ~918). New l10n key `equipment_edit_liftCapacityLabel` ("Lift capacity ({unit})") in all 11 arbs; `flutter gen-l10n`. Extend the existing equipment edit page test with: field hidden for a wetsuit, shown for a bcd, value round-trips.
- [ ] **Step 8: Fill `wingLiftCapacityKg` in `buoyancyTwinProvider`**: first `dive.equipment` item with type `bcd` and non-null `liftCapacityKg`.
- [ ] **Step 9: Run tests** — migration test + equipment edit test + `flutter test test/core/buoyancy/`.
- [ ] **Step 10: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add -u && git add test/core/database/ && git commit -m "feat(equipment): wing lift capacity capture (schema v<NEXT>)"
```

---

### Task 8: Buoyancy detail-section registration

**Files:**
- Modify: `lib/core/constants/dive_detail_sections.dart` (enum + names + descriptions + `defaultSections`)
- Modify: all 11 arb files (`diveDetailSection_buoyancy_name`, `diveDetailSection_buoyancy_description`) + `flutter gen-l10n`
- Modify: `lib/features/dive_log/presentation/pages/dive_detail_page.dart` (builders map, ~line 341-447)
- Test: extend the existing dive-detail-sections test (find it: `grep -rln "ensureAllSections" test/`)

**Interfaces:**
- Consumes: `BuoyancySection` widget — created in Task 9; in THIS task register the enum and wire a placeholder-free builder that returns `BuoyancySection(diveId: dive.id, units: units)` (Task 9 creates the widget file first if you execute out of order — otherwise do Tasks 8 and 9 together before committing).
- Produces: `DiveDetailSectionId.buoyancy`.

- [ ] **Step 1: Failing test** — extend the sections test: `ensureAllSections` on a legacy JSON list (without buoyancy) appends `DiveDetailSectionId.buoyancy`; `fromJson`/`toJson` round-trips it.
- [ ] **Step 2: Run to verify it fails.**
- [ ] **Step 3: Implement** — add `buoyancy` to the enum between `weights` and `tanks` (default order: next to the weighting data it explains); add `displayName` 'Buoyancy', `description` 'Buoyancy through the dive, swing, ditchable weight'; add the two localized switch arms; add the `defaultSections` entry in the same position; `hiddenInGaugeMode` stays false. Add the builder in `dive_detail_page.dart`:

```dart
DiveDetailSectionId.buoyancy: () {
  if (dive.tanks.isEmpty && !_hasExposureSuit(dive)) return [];
  return [
    const SizedBox(height: 24),
    BuoyancySection(diveId: dive.id, units: units),
  ];
},
```

with `bool _hasExposureSuit(Dive dive) => dive.equipment.any((e) => e.type == EquipmentType.wetsuit || e.type == EquipmentType.drysuit);`. Add the l10n keys to all 11 arbs (English source; translate the other ten — short UI strings, follow neighboring keys' tone) and run `flutter gen-l10n`.
- [ ] **Step 4: Run the sections test** — PASS.
- [ ] **Step 5: Format, analyze, commit** (message `feat(dive-log): register buoyancy detail section`). If Task 9 is not yet done, commit Tasks 8+9 together.

---

### Task 9: BuoyancySection widget — diagnosis, breakdown, summary

**Files:**
- Create: `lib/features/dive_log/presentation/widgets/buoyancy_section.dart`
- Test: `test/features/dive_log/presentation/widgets/buoyancy_section_test.dart`

**Interfaces:**
- Consumes: `buoyancyTwinProvider`, `BuoyancyTwinOutcome`, `TwinOutputs`, `TwinVerdict`, `UnitFormatter`, l10n.
- Produces: `class BuoyancySection extends ConsumerWidget { const BuoyancySection({required this.diveId, required this.units}); }` — consumed by Task 8; exposes a `showWhatIf` callback slot used by Task 12.

Layout (Card matching sibling sections like `CylindersCard`):
1. Header row: localized section title "BUOYANCY" + an info tooltip.
2. Diagnosis line (headline `titleMedium`): localized template `buoyancy_verdictLine` — "At your final stop (~{depth}, {pressure}) you were about {amount} {direction}" with direction `buoyancy_buoyant`/`buoyancy_heavy`; when `|netKg| <= 0.5` use `buoyancy_verdictNeutral` ("Your rig was close to neutral at the final stop"). Anchor kind `convention` uses `buoyancy_verdictStatic` wording ("Estimated at the 5 m convention").
3. Expandable breakdown (ExpansionTile): one row per `verdict.terms` — label, signed kg via `units.formatWeight`, and a source chip (reuse the tri-state wording from the Weight Planner's breakdown card — see `weight_prediction_card.dart` for the pattern and localize with the same existing keys if present, else new keys).
4. Summary rows (2-column wrap): begin/end net, swing (`endNetKg - beginNetKg`), peak wing lift demand (+ warning icon when `wingLiftCapacityKg != null && peak > capacity`), min ditchable vs droppable (+ warning when droppable < minDitchable), drysuit gas (only when > 0).
5. Estimated-data hint when `result.pressuresEstimated` (localized `buoyancy_estimatedPressures`); no-suit hint when `input.suit.kind == TwinSuitKind.none` (localized `buoyancy_linkSuitHint`, "Link an exposure suit to this dive for a fuller picture").
6. Loading: `SizedBox.shrink`; error: `SizedBox.shrink` (section self-suppresses — never a broken card); null outcome: `SizedBox.shrink`.

All strings via new l10n keys (`buoyancy_*`) in all 11 arbs.

- [ ] **Step 1: Failing widget test** — with a `ProviderScope` override of `buoyancyTwinProvider(diveId)` returning a fixed `BuoyancyTwinOutcome` (build it directly from Task 3/4 types — no database): verdict text renders the formatted amount; breakdown expands to show a `lead` row; ditchable warning appears when droppable < required; everything hidden when the override returns null. Follow the FormSection test gotchas: labels may render uppercased — match case-insensitively; `tester.ensureVisible` before tapping the ExpansionTile.
- [ ] **Step 2: Run to verify it fails.** `flutter test test/features/dive_log/presentation/widgets/buoyancy_section_test.dart`
- [ ] **Step 3: Implement the widget + l10n keys + `flutter gen-l10n`.**
- [ ] **Step 4: Run to verify it passes.**
- [ ] **Step 5: Format, analyze, commit** — `feat(dive-log): buoyancy section with final-stop diagnosis` (include Task 8 files here if deferred).

---

### Task 10: Net-buoyancy chart

**Files:**
- Create: `lib/features/dive_log/presentation/widgets/buoyancy_chart.dart`
- Modify: `lib/features/dive_log/presentation/widgets/buoyancy_section.dart` (embed below the diagnosis)
- Test: `test/features/dive_log/presentation/widgets/buoyancy_chart_test.dart`

**Interfaces:**
- Consumes: `BuoyancyTwinResult.samples`, `UnitFormatter`.
- Produces: `class BuoyancyChart extends StatelessWidget { const BuoyancyChart({required this.result, required this.units, this.height = 180}); }`

Implementation notes:
- fl_chart `LineChart`, x = minutes, y = net kg (converted via `units.convertWeight`); a dashed horizontal zero line (`extraLinesData`); area tint above zero (buoyant) vs below (heavy) using two `LineChartBarData` splits — mirror the styling approach of `dive_profile_chart.dart`'s simpler siblings (see `sac` graph widgets), NOT the full profile chart.
- Touch: `LineTouchTooltipData` showing time, depth, and the three term groups (suit/tanks/static-lead) from the touched `TwinSample`.
- Guard the NaN trap: skip non-finite values when building `FlSpot`s (repo has a known NaN-FlSpot crash).
- Hidden entirely (`SizedBox.shrink`) when `samples.length < 2`.

- [ ] **Step 1: Failing widget test** — renders a `LineChart` for a 3-sample result; renders nothing for an empty-profile result; a NaN-net sample is skipped, not crashed (construct one with a tank of NaN pressure via a crafted series — or directly assert the spot-building helper filters non-finite; expose `visibleSpots(List<TwinSample>)` as a static for testability).
- [ ] **Step 2: Run to verify it fails.**
- [ ] **Step 3: Implement; embed in `BuoyancySection` between diagnosis and summary.**
- [ ] **Step 4: Run chart + section tests — PASS.**
- [ ] **Step 5: Format, analyze, commit** — `feat(dive-log): net buoyancy chart with per-moment breakdown`.

---

### Task 11: Weighting-history strip

**Files:**
- Create: `lib/features/dive_log/presentation/providers/buoyancy_history_provider.dart`
- Create: `lib/features/dive_log/presentation/widgets/buoyancy_history_strip.dart`
- Modify: `buoyancy_section.dart` (append strip)
- Test: `test/features/dive_log/presentation/providers/buoyancy_history_provider_test.dart`, widget test additions

**Interfaces:**
- Consumes: `weightObservationsProvider`, `buoyancyTwinProvider` internals (assembler + engine directly — NOT the family provider per dive, to avoid registering N provider watchers), `analysisDiveProvider`.
- Produces:

```dart
class BuoyancyHistoryEntry {
  final String diveId; final DateTime diveDateTime;
  final double carriedKg; final double idealKg; final String? feedback;
}
final buoyancyHistoryProvider =
    FutureProvider.family<List<BuoyancyHistoryEntry>, String>; // arg: current diveId
```

Semantics: take the current dive's exposure-suit equipment id (null allowed); from `weightObservationsProvider` (already oldest-first, weight-bearing dives only), filter to dives whose `equipmentIds` contain that suit id (all dives when null), take the most recent 10 excluding the current dive. For each, load the dive lean via `ref.read(analysisDiveProvider(id).future)` (READ, not watch — cross-dive lookbacks must not create invalidation cascades; established repo pattern), assemble + run the twin, and record `idealKg = outputs.idealLeadKg`, `carriedKg = observation.carriedKg`, `feedback = observation.feedback`. Dives whose twin returns null are skipped. Run the whole batch inside one `compute` call if assembly shows up in profiling — start simple (sequential await) since results cache.

Widget: horizontal bar-pair strip (carried vs ideal per dive, most recent last), a delta caption ("You typically carry {delta} more than the model suggests" — median of carried-ideal, localized, hidden when |median| < 0.5 kg), and feedback glyphs on rated dives. Empty list -> `SizedBox.shrink`.

- [ ] **Step 1: Failing provider test** — with overridden `weightObservationsProvider` (3 fake observations sharing a suit id, 1 not sharing) and a stubbed `analysisDiveProvider` per dive: returns entries only for same-suit dives, excludes the current dive, orders oldest-first, skips a dive with no tanks/suit.
- [ ] **Step 2: Run to verify it fails.**
- [ ] **Step 3: Implement provider + widget + l10n keys (all 11 arbs, `flutter gen-l10n`).**
- [ ] **Step 4: Run provider + widget tests — PASS.**
- [ ] **Step 5: Format, analyze, commit** — `feat(dive-log): weighting history strip comparing carried vs modeled lead`.

---

### Task 12: What-if re-simulation sheet

**Files:**
- Create: `lib/features/dive_log/presentation/widgets/buoyancy_what_if_sheet.dart`
- Modify: `buoyancy_section.dart` (an "Adjust" `TextButton` opening the sheet)
- Test: `test/features/dive_log/presentation/widgets/buoyancy_what_if_sheet_test.dart`

**Interfaces:**
- Consumes: `TwinInput` (from `outcome.result.input`), `runBuoyancyTwin`, `TwinAnalyzer`, `UnitFormatter`.
- Produces: `Future<void> showBuoyancyWhatIfSheet(BuildContext context, {required TwinInput baseInput, required UnitFormatter units})`.

Sheet content (StatefulWidget, ALL state local — nothing persists, deliberate):
- Lead stepper: +/- 0.5 kg (metric) or 1 lb steps around `baseInput.leadKg`.
- Water type `SegmentedButton<WaterType>` — swapping rebuilds the environment via `DiveEnvironment.forConditions` and rescales the water static term proportionally to density ratio (recompute the `water` `TwinStaticTerm` as `original * (newDensity/oldDensity assumption)`; simplest correct approach: recompute `BuoyancyPhysics.waterTermKg` needs total mass — carry `totalMassKg` on `TwinInput` as an extra field added in this task WITH its Task 3 test updated).
- Tank preset dropdown per tank (from `TankPresets`; swapping replaces presetName/volume/workingPressure/material, keeps pressures).
- Suit anchor slider (0-10 kg) labeled with the suit name.
- Live result: recompute `runBuoyancyTwin` synchronously on change (pure Dart, tens of samples per ms — no isolate needed for a single dive) and show the new verdict line + begin/end + min ditchable, plus a delta chip vs the base outcome. Reset button restores `baseInput`.

- [ ] **Step 1: Failing widget test** — open the sheet with a fixed `TwinInput`; tap lead "+" twice -> verdict amount changes in the buoyant direction by ~1 kg; Reset restores the original verdict text; nothing is written to any provider (assert no ProviderScope overrides are touched — construct with plain widgets, no scope needed beyond settings for units).
- [ ] **Step 2: Run to verify it fails.**
- [ ] **Step 3: Implement (plus the `TwinInput.totalMassKg` field + updated Task 3 test + assembler wiring).**
- [ ] **Step 4: Run what-if + twin + assembler tests — PASS.**
- [ ] **Step 5: Format, analyze, commit** — `feat(dive-log): what-if buoyancy re-simulation sheet`.

---

### Task 13: Dive Planner — twin outputs in Gear & Weights

**Files:**
- Modify: `lib/features/dive_planner/presentation/widgets/plan_gear_weights_section.dart`
- Create: `lib/features/weight_planner/presentation/providers/plan_buoyancy_twin_provider.dart`
- Test: `test/features/weight_planner/presentation/providers/plan_buoyancy_twin_provider_test.dart`

**Interfaces:**
- Consumes: `divePlanNotifierProvider` state (`segments: List<PlanSegment>`, tanks, `equipmentIds`), `weightCalibrationProvider`, `planWeightPredictionProvider` (the accepted/predicted lead is the twin's `leadKg`), `GasConsumption` from the plan result provider (locate the provider exposing `PlanResult` in `dive_planner_providers.dart` while implementing), Tasks 3-4.
- Produces: `final planBuoyancyTwinProvider = Provider<BuoyancyTwinOutcome?>` — recomputes synchronously on plan edits (plans have few segments; no isolate).

Semantics:
- Profile synthesis: walk `segments` in order emitting one `TwinProfileSample` per segment boundary (`t` accumulates `durationSeconds`; depth = `startDepth` then `endDepth`), plus one interior sample per 30 s of bottom/stop segments so anchor detection has a run to find.
- Tanks: plan tanks -> `TwinTankInput` with linear pressure from `GasConsumption.startPressure` to `remainingPressure` when the plan result has them, else no pressures (constant convention term).
- Suit/static/lead: reuse `BuoyancyTwinAssembler`-style composition from the planned `equipmentIds` — extract the shared gear-composition helper out of `BuoyancyTwinAssembler.assemble` into a static `composeRigTerms({required List<EquipmentItem> items, required FittedWeightModel model, required WaterType? waterType, required double? bodyWeightKg})` returning `(suit: TwinSuitInput, staticTerms: List<TwinStaticTerm>, totalMassKg: double)` and reuse it from BOTH assemble sites (DRY — update Task 6's file and test in this task).
- Lead: the plan's accepted `plannedWeightKg` if set, else the live `planWeightPredictionProvider` total, else 0 with the outputs card hidden.
- UI: append a compact outputs row to `plan_gear_weights_section.dart`: swing, peak lift, min ditchable (reuse the summary-row composition from `BuoyancySection` by extracting those rows into a small shared widget `TwinSummaryRows` in `lib/shared/widgets/` — used by Tasks 9, 13, 14).
- [ ] **Step 1: Failing provider test** — fake plan state with a descent/bottom/ascent/safety-stop segment list: profile synthesis yields monotonically increasing timestamps, bottom samples every 30 s, anchor detection finds the safety stop; provider returns null when the plan has no tanks.
- [ ] **Step 2: Run to verify it fails.**
- [ ] **Step 3: Implement (helper extraction + provider + UI row + l10n keys in all 11 arbs + `flutter gen-l10n`).**
- [ ] **Step 4: Run the new test + Task 6 tests (the extraction touched them) — PASS.**
- [ ] **Step 5: Format, analyze, commit** — `feat(planner): buoyancy twin outputs in Gear & Weights`.

---

### Task 14: Weight Planner tool — "Through the dive" panel

**Files:**
- Modify: `lib/features/weight_planner/presentation/pages/weight_planner_page.dart`
- Test: extend `test/features/weight_planner/` page test (locate the existing weight planner page test file and follow its setup)

**Interfaces:**
- Consumes: the page's existing rig state (gear items, tanks, water type, body weight), `weightCalibrationProvider`, `composeRigTerms` (Task 13), Tasks 3-4, `TwinSummaryRows` (Task 13).
- Produces: UI only.

Semantics: below the prediction card, an expandable "Through the dive" panel with two inputs — max depth and bottom time (both via existing unit-aware text-field patterns on the page) — defaulting to 18 m / 45 min. Synthesize a square profile: descent at 18 m/min, bottom at max depth, direct ascent at 9 m/min with a 3 min stop at 5 m; tanks linear from `workingPressureBar` (fallback 200) down to reserve 50 bar. Lead = the current prediction's `totalKg`. Show `TwinSummaryRows` + the verdict line. Recompute synchronously on any input change.

- [ ] **Step 1: Failing widget test** — panel renders swing and min-ditchable rows for a default rig; changing max depth changes the swing row; panel absent when the rig has no tanks.
- [ ] **Step 2: Run to verify it fails.**
- [ ] **Step 3: Implement + l10n keys (all 11 arbs) + `flutter gen-l10n`.**
- [ ] **Step 4: Run the page test — PASS.**
- [ ] **Step 5: Format, analyze, commit** — `feat(weight-planner): through-the-dive simulation panel`.

---

### Task 15: Final sweep

**Files:** none new.

- [ ] **Step 1: Spec coverage check** — reread `docs/superpowers/specs/2026-07-17-buoyancy-digital-twin-design.md` section by section and confirm each requirement maps to landed code; fix gaps now.
- [ ] **Step 2: Full formatting + analysis**

```bash
dart format .
flutter analyze
```
Expected: no changes, "No issues found!". Never pipe analyze.
- [ ] **Step 3: Run the feature's test surface**

```bash
flutter test test/core/buoyancy/ test/features/dive_log/presentation/widgets/buoyancy_section_test.dart test/features/dive_log/presentation/widgets/buoyancy_chart_test.dart test/features/dive_log/presentation/widgets/buoyancy_what_if_sheet_test.dart test/features/dive_log/presentation/providers/buoyancy_history_provider_test.dart test/features/dive_log/data/services/buoyancy_twin_assembler_test.dart test/features/weight_planner/
```
Plus the migration test and equipment edit test from Task 7, and the sections test from Task 8. Expected: all PASS.
- [ ] **Step 4: Commit any sweep fixes** — `chore(buoyancy): post-implementation sweep`.
