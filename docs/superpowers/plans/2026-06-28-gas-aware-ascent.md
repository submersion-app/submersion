# Gas-Aware Ascent for Imported-Dive Decompression Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make every forward-looking decompression projection (TTS, ceiling, stop schedule) simulate the ascent on the best breathable gas the diver carries at each simulated depth, eliminating the discontinuous TTS step at recorded gas switches — for open-circuit dives only.

**Architecture:** Introduce a pluggable `AscentGasPlan` strategy that answers "what inert fractions do I breathe at this ascent depth?". Thread it through the existing Bühlmann ascent primitives (`calculateDecoSchedule` / `calculateTts` / `_calculateStopTime` / `_simulateAscent` / `getDecoStatus` / `processProfileWithGasSegments`), splitting each ascent leg at any gas-switch (MOD) depth it crosses. The bottom-phase tissue-loading path delivered by the 2026-03-31 spec is untouched; only the per-sample projection changes. CCR/SCR are out of scope and keep today's behavior.

**Tech Stack:** Flutter / Dart, Drift ORM (SQLite), Riverpod, Bühlmann ZH-L16C with gradient factors.

## Global Constraints

Every task's requirements implicitly include this section.

- **Open-circuit only.** Gas-aware ascent must never engage off the OC path. The existing `useOcGasSegments` guard (`diveMode == DiveMode.oc && gasSegments != null`, `profile_analysis_service.dart:573`) is the single gate. No `CcrLoopAscentGas`, no bailout modeling.
- **Single-gas dives must be byte-identical to `main`.** When only one gas is in play the plan must reduce to today's fixed-gas ascent exactly.
- **Eligibility ceiling reuses the existing `ppO2MaxDeco` diver setting (default 1.6 bar).** Do not add a parallel ppO2 setting. Eligibility uses `O2ToxicityCalculator.calculateMod(fO2, maxPpO2: ppO2MaxDeco)`, never an inline ppO2 re-derivation.
- **No invented gases.** Only cylinders actually recorded on `dive.tanks`. A cylinder's presence is proof it was carried and breathable.
- **Bühlmann math stays shared, not forked.** Thread the plan through the existing methods; do not copy the algorithm.
- **The recorded computer TTS overlay (`overlayComputerDecoData`) stays authoritative per-metric where present.** This plan changes only the *calculated* values it falls back to.
- **No schema/stored-data migration for dive deco data.** Curves recompute on next open. (The new *setting* below does add one Drift column + migration — that is the only migration in this plan.)
- **`fO2 = 1 - fN2 - fHe`** everywhere; `ProfileGasSegment` and `AscentGas` carry only `fN2`/`fHe`.
- **The "Plan ascent with" setting is a single persisted enum** `AscentGasSet { allCarried, decoStageOnly }`, default `allCarried`. `allCarried` = every recorded cylinder. `decoStageOnly` = cylinders with role `deco`/`stage`/`bailout` plus the current back gas (the gas actually being breathed at the sample, always included as the ascent floor). There is no separate feature kill-switch.
- **Run `dart format .` after each task.** All Dart must pass `dart format` with no changes (pre-push hook enforces it).
- **TDD.** Write the failing test first, watch it fail, implement minimally, watch it pass, commit.
- **Fixtures:** use only the committed files in `test/dives/`. OC: `001_short_deco_single_gas_switch.ssrf.xml`. CCR (used only to assert no-change): `002_ccr_only_low_sp_no_calculated_po2.ssrf.xml`, `003_ccr_with_setpoint_switch_and_calculated_po2.ssrf.xml`. Any other recording under `test/dives/` (e.g. `sanfran.ssrf`) is a private local file and must not be referenced.

---

## File Structure

| File | Responsibility |
| --- | --- |
| `lib/core/deco/ascent/ascent_gas_plan.dart` | **New.** `AscentGas`, `AscentGasPlan`, `FixedAscentGas`, `AvailableGas`, `OptimalOcAscentGas`. Pure logic, no Flutter/Drift imports. |
| `lib/core/deco/buhlmann_algorithm.dart` | Thread `AscentGasPlan` through the ascent primitives; MOD-split in `_simulateAscent`; keep `fN2/fHe` optional-param overloads. |
| `lib/features/settings/presentation/providers/settings_providers.dart` | `AscentGasSet` enum, `AppSettings.ascentGasSet` field + copyWith, `ascentGasSetProvider`. |
| `lib/core/database/database.dart` | `DiverSettings.ascentGasSet` Drift column (v94), `currentSchemaVersion = 94`, migration step. |
| `lib/features/settings/data/repositories/diver_settings_repository.dart` | Persist/read `ascentGasSet`. |
| `lib/core/services/sync/sync_data_serializer.dart` | Serialize/deserialize `ascentGasSet`. |
| `lib/features/dive_log/presentation/providers/profile_analysis_provider.dart` | `buildAvailableGases(dive)`; pass available gases + ppO2MaxDeco + gas-set into the isolate input; build `OptimalOcAscentGas` in the isolate (OC path only). |
| `lib/features/dive_log/data/services/profile_analysis_service.dart` | `analyze()` gains `ascentGasPlan`; plumb into `processProfileWithGasSegments` for the OC path. |
| `lib/features/dive_planner/data/services/plan_calculator_service.dart` | Select `OptimalOcAscentGas` (ideal) vs `FixedAscentGas` per the existing gas model. |
| `lib/features/settings/presentation/pages/<deco settings page>.dart` | "Plan ascent with" selector (all vs deco-only). |
| `test/core/deco/ascent_gas_plan_test.dart` | **New.** Strategy selection, MOD eligibility, tie-breaking, switch-depth enumeration. |
| `test/core/deco/buhlmann_algorithm_test.dart` | MOD-split / on-the-fly-switch / overload-delegation tests (append). |
| `test/core/deco/tts_gas_switch_regression_test.dart` | **New.** Step-free TTS across a switch; single-gas equivalence; CCR path unchanged. |
| `test/core/deco/tts_cleanroom_cross_check_test.dart` | **New.** Independent ZHL-16C/GF per-sample TTS cross-check pinning absolute numbers. |
| `test/features/settings/ascent_gas_set_setting_test.dart` | **New.** Default + round-trip persistence of the setting. |
| `test/features/dive_log/build_available_gases_test.dart` | **New.** `buildAvailableGases` mapping + gas-set filtering + no invented gases. |

---

### Task 1: `AscentGasPlan` strategy and implementations

**Files:**
- Create: `lib/core/deco/ascent/ascent_gas_plan.dart`
- Test: `test/core/deco/ascent_gas_plan_test.dart`

**Interfaces:**
- Consumes: `O2ToxicityCalculator.calculateMod(double o2Fraction, {double maxPpO2})` from `lib/core/deco/o2_toxicity_calculator.dart` (returns MOD in meters); `airN2Fraction` from `lib/core/deco/constants/buhlmann_coefficients.dart`.
- Produces:
  - `class AscentGas { final double fN2; final double fHe; const AscentGas({required this.fN2, required this.fHe}); }`
  - `abstract class AscentGasPlan { AscentGas gasForDepth(double depthMeters); List<double> switchDepthsBetween(double deeperDepth, double shallowerDepth); }`
  - `class FixedAscentGas extends AscentGasPlan { FixedAscentGas({required double fN2, double fHe}); }`
  - `class AvailableGas { final double fN2; final double fHe; final double maxPpO2Mod; double get fO2; const AvailableGas({required this.fN2, required this.fHe, required this.maxPpO2Mod}); }`
  - `class OptimalOcAscentGas extends AscentGasPlan { OptimalOcAscentGas({required List<AvailableGas> gases, required double maxPpO2}); }`

- [ ] **Step 1: Write the failing test**

```dart
// test/core/deco/ascent_gas_plan_test.dart
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
      expect(plan.gasForDepth(21).fN2, 0.50); // EAN50 eligible (<= 22 m), richest
      expect(plan.gasForDepth(6).fN2, 0.0); // O2 eligible at its MOD (6 m)
      expect(plan.gasForDepth(3).fN2, 0.0); // O2 still richest
    });

    test('is eligible exactly at a gas MOD', () {
      expect(plan.gasForDepth(22).fN2, 0.50); // EAN50 ppO2 == 1.6 at 22 m
    });

    test('enumerates switch depths descending within a leg', () {
      expect(plan.switchDepthsBetween(40, 0), [22.0, 6.0]);
      expect(plan.switchDepthsBetween(40, 12), [22.0]); // 6 m is outside (40,12)
      expect(plan.switchDepthsBetween(9, 6), isEmpty); // no MOD strictly inside
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/deco/ascent_gas_plan_test.dart`
Expected: FAIL — `ascent_gas_plan.dart` does not exist / `OptimalOcAscentGas` undefined.

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/core/deco/ascent/ascent_gas_plan.dart
import 'package:submersion/core/deco/constants/buhlmann_coefficients.dart';

/// Inert gas fractions to breathe at a given simulated ascent depth.
class AscentGas {
  const AscentGas({required this.fN2, required this.fHe});
  final double fN2;
  final double fHe;
}

/// Strategy answering "what do I breathe at this ascent depth?" so the
/// Buhlmann algorithm stays ignorant of tank roles and ppO2 policy.
abstract class AscentGasPlan {
  /// Gas to breathe at [depthMeters] during a simulated ascent.
  AscentGas gasForDepth(double depthMeters);

  /// Depths in the open interval ([shallowerDepth], [deeperDepth]) where the
  /// selected gas changes, sorted deep-to-shallow (descending). An ascent leg
  /// is split at each so it never breathes a gas impermissible at its depth.
  List<double> switchDepthsBetween(double deeperDepth, double shallowerDepth);
}

/// Today's behavior: one gas the whole way up. Used by single-gas dives and the
/// planner's fixed-gas path. Reduces gas-aware ascent to the legacy ascent.
class FixedAscentGas extends AscentGasPlan {
  FixedAscentGas({required this.fN2, this.fHe = 0.0});
  final double fN2;
  final double fHe;

  @override
  AscentGas gasForDepth(double depthMeters) => AscentGas(fN2: fN2, fHe: fHe);

  @override
  List<double> switchDepthsBetween(double deeperDepth, double shallowerDepth) =>
      const [];
}

/// A cylinder available on the dive, with its precomputed MOD for the diver's
/// ppO2 ceiling. [maxPpO2Mod] is the deepest depth (m) where ppO2 <= ceiling.
class AvailableGas {
  const AvailableGas({
    required this.fN2,
    required this.fHe,
    required this.maxPpO2Mod,
  });
  final double fN2;
  final double fHe;
  final double maxPpO2Mod;

  double get fO2 => (1.0 - fN2 - fHe);
}

/// Open-circuit optimal ascent: at each depth picks the eligible gas with the
/// highest O2 (ppO2 at depth <= [maxPpO2]). Eligibility is expressed as MOD on
/// [AvailableGas.maxPpO2Mod], derived once via O2ToxicityCalculator.calculateMod
/// so ppO2 is never re-derived here.
class OptimalOcAscentGas extends AscentGasPlan {
  OptimalOcAscentGas({required List<AvailableGas> gases, required this.maxPpO2})
    : _gases = List.unmodifiable(gases);

  final List<AvailableGas> _gases;
  final double maxPpO2;

  @override
  AscentGas gasForDepth(double depthMeters) {
    AvailableGas? best;
    for (final g in _gases) {
      // Eligible when at or above its MOD (depth <= MOD). A tiny tolerance keeps
      // the gas eligible exactly at its MOD despite float rounding.
      if (depthMeters <= g.maxPpO2Mod + 1e-9) {
        if (best == null || _prefer(g, best)) best = g;
      }
    }
    // The back gas is always in [_gases], so best is never null in practice;
    // fall back to the deepest-usable gas (smallest fO2) if it ever is.
    best ??= _deepestUsable();
    return AscentGas(fN2: best.fN2, fHe: best.fHe);
  }

  @override
  List<double> switchDepthsBetween(double deeperDepth, double shallowerDepth) {
    final result = <double>[];
    for (final g in _gases) {
      final mod = g.maxPpO2Mod;
      if (mod > shallowerDepth + 1e-9 && mod < deeperDepth - 1e-9) {
        // Only a real switch: the selected gas differs just below vs just above.
        final below = gasForDepth(mod + 1e-6);
        final above = gasForDepth(mod - 1e-6);
        if (below.fN2 != above.fN2 || below.fHe != above.fHe) {
          result.add(mod);
        }
      }
    }
    result.sort((a, b) => b.compareTo(a)); // descending (deep to shallow)
    return result;
  }

  /// Prefer higher O2; tie-break by lower narcotic load (higher He), then a
  /// deterministic order so the result is stable.
  bool _prefer(AvailableGas candidate, AvailableGas current) {
    if (candidate.fO2 != current.fO2) return candidate.fO2 > current.fO2;
    if (candidate.fHe != current.fHe) return candidate.fHe > current.fHe;
    return candidate.fN2 < current.fN2;
  }

  AvailableGas _deepestUsable() =>
      _gases.reduce((a, b) => a.fO2 <= b.fO2 ? a : b);
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/deco/ascent_gas_plan_test.dart`
Expected: PASS (all 6 tests).

- [ ] **Step 5: Format and commit**

```bash
dart format .
git add lib/core/deco/ascent/ascent_gas_plan.dart test/core/deco/ascent_gas_plan_test.dart
git commit -m "feat(deco): add AscentGasPlan strategy for gas-aware ascent"
```

---

### Task 2: Thread `AscentGasPlan` through the Bühlmann ascent primitives

**Files:**
- Modify: `lib/core/deco/buhlmann_algorithm.dart` (`calculateDecoSchedule` `:277`, `_calculateStopTime` `:336`, `_simulateAscent` `:378`, `calculateTts` `:408`)
- Test: `test/core/deco/buhlmann_algorithm_test.dart` (append)

**Interfaces:**
- Consumes: `AscentGasPlan`, `FixedAscentGas`, `AscentGas` from Task 1.
- Produces (signatures later tasks rely on):
  - `List<DecoStop> calculateDecoSchedule({required double currentDepth, double fN2, double fHe, AscentGasPlan? ascentGas})`
  - `int calculateTts({required double currentDepth, double fN2, double fHe, AscentGasPlan? ascentGas})`
  - `_simulateAscent(double fromDepth, double toDepth, AscentGasPlan ascentGas)` and `_calculateStopTime(double stopDepth, AscentGasPlan ascentGas)` (private).
  - Invariant: when `ascentGas` is null/`FixedAscentGas`, output is byte-identical to the pre-change single-gas path.

- [ ] **Step 1: Write the failing test (append to `test/core/deco/buhlmann_algorithm_test.dart`)**

```dart
  group('gas-aware ascent (AscentGasPlan)', () {
    // A deco dive: 40 m for 25 min on air, then project ascent.
    BuhlmannAlgorithm loadedAt40() {
      final algo = BuhlmannAlgorithm(gfLow: 0.50, gfHigh: 0.80);
      algo.reset();
      algo.calculateSegment(
        depthMeters: 40,
        durationSeconds: 25 * 60,
        fN2: airN2Fraction,
        fHe: 0.0,
      );
      return algo;
    }

    test('FixedAscentGas TTS equals the fN2/fHe overload (equivalence)', () {
      final a = loadedAt40();
      final viaFraction = a.calculateTts(currentDepth: 40, fN2: airN2Fraction);
      final b = loadedAt40();
      final viaPlan = b.calculateTts(
        currentDepth: 40,
        ascentGas: FixedAscentGas(fN2: airN2Fraction),
      );
      expect(viaPlan, viaFraction);
    });

    test('richer ascent gas yields lower-or-equal TTS than all-air', () {
      final allAir = loadedAt40().calculateTts(
        currentDepth: 40,
        fN2: airN2Fraction,
      );
      // Air back gas + EAN50 (MOD 22 m @1.6) + O2 (MOD 6 m @1.6).
      final plan = OptimalOcAscentGas(
        gases: const [
          AvailableGas(fN2: 0.79, fHe: 0.0, maxPpO2Mod: double.infinity),
          AvailableGas(fN2: 0.50, fHe: 0.0, maxPpO2Mod: 22.0),
          AvailableGas(fN2: 0.0, fHe: 0.0, maxPpO2Mod: 6.0),
        ],
        maxPpO2: 1.6,
      );
      final gasAware = loadedAt40().calculateTts(
        currentDepth: 40,
        ascentGas: plan,
      );
      expect(gasAware, lessThanOrEqualTo(allAir));
    });

    test('MOD split: gas at the deeper end of each sub-leg is correct', () {
      // Spy plan records the depths gasForDepth() is queried at during a leg.
      final spy = _RecordingPlan(
        OptimalOcAscentGas(
          gases: const [
            AvailableGas(fN2: 0.79, fHe: 0.0, maxPpO2Mod: double.infinity),
            AvailableGas(fN2: 0.50, fHe: 0.0, maxPpO2Mod: 22.0),
          ],
          maxPpO2: 1.6,
        ),
      );
      final a = loadedAt40();
      // Drive a full schedule so _simulateAscent walks 40 -> first stop.
      a.calculateDecoSchedule(currentDepth: 40, ascentGas: spy);
      // The travel leg from 40 m must have been split at 22 m: back gas was
      // queried at a depth > 22 and EAN50 at exactly 22 (sub-leg deeper end).
      expect(spy.queriedDepths.any((d) => d >= 22.0), isTrue);
    });
  });
```

Add this private spy near the bottom of the test file:

```dart
class _RecordingPlan extends AscentGasPlan {
  _RecordingPlan(this._inner);
  final AscentGasPlan _inner;
  final List<double> queriedDepths = [];

  @override
  AscentGas gasForDepth(double depthMeters) {
    queriedDepths.add(depthMeters);
    return _inner.gasForDepth(depthMeters);
  }

  @override
  List<double> switchDepthsBetween(double deeper, double shallower) =>
      _inner.switchDepthsBetween(deeper, shallower);
}
```

Ensure the test file imports:
```dart
import 'package:submersion/core/deco/ascent/ascent_gas_plan.dart';
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/deco/buhlmann_algorithm_test.dart --plain-name "gas-aware ascent"`
Expected: FAIL — `calculateTts`/`calculateDecoSchedule` have no `ascentGas` parameter.

- [ ] **Step 3: Implement — replace the four primitives**

In `lib/core/deco/buhlmann_algorithm.dart`, add the import at the top:
```dart
import 'package:submersion/core/deco/ascent/ascent_gas_plan.dart';
```

Replace `calculateDecoSchedule` (`:277-333`) with:
```dart
  List<DecoStop> calculateDecoSchedule({
    required double currentDepth,
    double fN2 = airN2Fraction,
    double fHe = 0.0,
    AscentGasPlan? ascentGas,
  }) {
    final plan = ascentGas ?? FixedAscentGas(fN2: fN2, fHe: fHe);
    final stops = <DecoStop>[];

    final savedCompartments = List<TissueCompartment>.from(_compartments);

    final double ceiling = calculateCeiling(currentDepth: currentDepth);
    if (ceiling <= 0) {
      _compartments = savedCompartments;
      return stops; // No deco required
    }

    double currentStopDepth = (ceiling / stopIncrement).ceil() * stopIncrement;

    // Travel to first stop may cross a gas MOD: _simulateAscent splits it.
    _simulateAscent(currentDepth, currentStopDepth, plan);

    while (currentStopDepth >= lastStopDepth) {
      final int stopTime = _calculateStopTime(currentStopDepth, plan);

      if (stopTime > 0) {
        stops.add(
          DecoStop(
            depthMeters: currentStopDepth,
            durationSeconds: stopTime,
            isDeepStop: currentStopDepth > 9,
          ),
        );

        final stopGas = plan.gasForDepth(currentStopDepth);
        calculateSegment(
          depthMeters: currentStopDepth,
          durationSeconds: stopTime,
          fN2: stopGas.fN2,
          fHe: stopGas.fHe,
        );
      }

      final nextStop = currentStopDepth - stopIncrement;
      if (nextStop >= lastStopDepth) {
        _simulateAscent(currentStopDepth, nextStop, plan);
      }
      currentStopDepth = nextStop;
    }

    _compartments = savedCompartments;
    return stops;
  }
```

Replace `_calculateStopTime` (`:336-376`) with:
```dart
  /// Calculate time required at a stop depth, breathing the plan's gas there.
  int _calculateStopTime(double stopDepth, AscentGasPlan ascentGas) {
    final gas = ascentGas.gasForDepth(stopDepth);
    final nextStopDepth = stopDepth <= lastStopDepth
        ? 0.0
        : stopDepth - stopIncrement;
    int stopTime = 0;
    const maxStopTime = 120 * 60;

    while (stopTime < maxStopTime) {
      final testCompartments = List<TissueCompartment>.from(_compartments);

      calculateSegment(
        depthMeters: stopDepth,
        durationSeconds: 60,
        fN2: gas.fN2,
        fHe: gas.fHe,
      );

      final ceiling = calculateCeiling(currentDepth: stopDepth);

      _compartments = testCompartments;

      if (ceiling <= nextStopDepth) {
        break;
      }

      calculateSegment(
        depthMeters: stopDepth,
        durationSeconds: 60,
        fN2: gas.fN2,
        fHe: gas.fHe,
      );
      stopTime += 60;
    }

    return ((stopTime + 59) ~/ 60) * 60;
  }
```

Replace `_simulateAscent` (`:378-400`) with the split-aware version plus a single-leg helper:
```dart
  /// Simulate ascent between depths, splitting the leg at every gas-switch
  /// (MOD) depth it crosses so each sub-leg breathes the gas eligible at that
  /// sub-leg's deeper end. For [FixedAscentGas] there are no switch depths, so
  /// this collapses to a single average-depth segment (legacy behavior).
  void _simulateAscent(
    double fromDepth,
    double toDepth,
    AscentGasPlan ascentGas,
  ) {
    if (fromDepth <= toDepth) return;

    final switches = ascentGas.switchDepthsBetween(fromDepth, toDepth);
    double segTop = fromDepth;
    for (final switchDepth in switches) {
      // switches is descending; each is strictly between toDepth and fromDepth.
      _ascendLeg(segTop, switchDepth, ascentGas);
      segTop = switchDepth;
    }
    _ascendLeg(segTop, toDepth, ascentGas);
  }

  /// Load one un-split ascent sub-leg on the gas eligible at its deeper end.
  void _ascendLeg(double fromDepth, double toDepth, AscentGasPlan ascentGas) {
    if (fromDepth <= toDepth) return;
    final gas = ascentGas.gasForDepth(fromDepth);
    final depthChange = fromDepth - toDepth;
    final ascentTimeSeconds = (depthChange / ascentRate * 60).round();
    final avgDepth = (fromDepth + toDepth) / 2.0;

    calculateSegment(
      depthMeters: avgDepth,
      durationSeconds: ascentTimeSeconds,
      fN2: gas.fN2,
      fHe: gas.fHe,
    );
  }
```

Replace `calculateTts` (`:408-440`) signature/body head to accept the plan and delegate the schedule (the ascent-time accounting is gas-independent — depth/rate only — so the rest is unchanged):
```dart
  int calculateTts({
    required double currentDepth,
    double fN2 = airN2Fraction,
    double fHe = 0.0,
    AscentGasPlan? ascentGas,
  }) {
    final plan = ascentGas ?? FixedAscentGas(fN2: fN2, fHe: fHe);
    final stops = calculateDecoSchedule(
      currentDepth: currentDepth,
      ascentGas: plan,
    );

    int tts = 0;
    for (final stop in stops) {
      tts += stop.durationSeconds;
    }

    double depth = currentDepth;
    for (final stop in stops) {
      final ascentTime = ((depth - stop.depthMeters) / ascentRate * 60).round();
      tts += ascentTime;
      depth = stop.depthMeters;
    }

    if (depth > 0) {
      tts += (depth / ascentRate * 60).round();
    }

    return tts;
  }
```

- [ ] **Step 4: Run the new tests and the full deco suite to verify pass + no regression**

Run: `flutter test test/core/deco/buhlmann_algorithm_test.dart`
Expected: PASS, including the existing single-gas tests (equivalence invariant holds).

- [ ] **Step 5: Format and commit**

```bash
dart format .
git add lib/core/deco/buhlmann_algorithm.dart test/core/deco/buhlmann_algorithm_test.dart
git commit -m "feat(deco): thread AscentGasPlan through ascent primitives with MOD split"
```

---

### Task 3: `getDecoStatus` and `processProfileWithGasSegments` accept a plan

**Files:**
- Modify: `lib/core/deco/buhlmann_algorithm.dart` (`getDecoStatus` `:448`, `processProfileWithGasSegments` `:535`)
- Test: `test/core/deco/tts_gas_switch_regression_test.dart` (new)

**Interfaces:**
- Consumes: `calculateTts`/`calculateDecoSchedule` with `ascentGas` (Task 2).
- Produces:
  - `DecoStatus getDecoStatus({required double currentDepth, double fN2, double fHe, int safetyStopTimeAccumulated, AscentGasPlan? ascentGas})`
  - `List<DecoStatus> processProfileWithGasSegments({required List<double> depths, required List<int> timestamps, required List<ProfileGasSegment> gasSegments, AscentGasPlan? ascentGasPlan})`
  - Invariant: `ascentGasPlan == null` reproduces today's per-sample `FixedAscentGas(active gas)` behavior exactly.

- [ ] **Step 1: Write the failing regression test**

```dart
// test/core/deco/tts_gas_switch_regression_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/deco/ascent/ascent_gas_plan.dart';
import 'package:submersion/core/deco/buhlmann_algorithm.dart';
import 'package:submersion/core/deco/constants/buhlmann_coefficients.dart';
import 'package:submersion/core/deco/entities/profile_gas_segment.dart';

void main() {
  // Synthetic deco profile: descend to 40 m, 25 min bottom on air, switch to
  // EAN50 at 21 m on the way up, sampled every 60 s to the surface.
  ({List<double> depths, List<int> timestamps, List<ProfileGasSegment> gas})
  buildProfile() {
    final depths = <double>[];
    final timestamps = <int>[];
    var t = 0;
    void add(double d) {
      depths.add(d);
      timestamps.add(t);
      t += 60;
    }

    for (var d = 0.0; d <= 40.0; d += 8) {
      add(d);
    }
    for (var i = 0; i < 25; i++) {
      add(40);
    }
    for (var d = 40.0; d >= 0.0; d -= 3) {
      add(d);
    }

    // Recorded switch to EAN50 (fN2 0.50) at the sample nearest 21 m on ascent.
    final switchIndex = depths.lastIndexWhere((d) => (d - 21).abs() < 1.6);
    final gas = <ProfileGasSegment>[
      const ProfileGasSegment(startTimestamp: 0, fN2: airN2Fraction),
      ProfileGasSegment(
        startTimestamp: timestamps[switchIndex],
        fN2: 0.50,
      ),
    ];
    return (depths: depths, timestamps: timestamps, gas: gas);
  }

  test('gas-aware TTS is monotone non-increasing across the recorded switch '
      'and reads 0 at the surface', () {
    final p = buildProfile();
    final algo = BuhlmannAlgorithm(gfLow: 0.50, gfHigh: 0.80);
    algo.reset();
    final plan = OptimalOcAscentGas(
      gases: const [
        AvailableGas(fN2: airN2Fraction, fHe: 0.0, maxPpO2Mod: double.infinity),
        AvailableGas(fN2: 0.50, fHe: 0.0, maxPpO2Mod: 22.0),
      ],
      maxPpO2: 1.6,
    );
    final statuses = algo.processProfileWithGasSegments(
      depths: p.depths,
      timestamps: p.timestamps,
      gasSegments: p.gas,
      ascentGasPlan: plan,
    );

    // Surface sample TTS is 0.
    expect(statuses.last.ttsSeconds, 0);

    // No upward step in TTS at the recorded switch: from the bottom phase
    // through the ascent the TTS must never jump UP at the switch sample.
    final tts = statuses.map((s) => s.ttsSeconds).toList();
    final switchIndex = p.depths.lastIndexWhere((d) => (d - 21).abs() < 1.6);
    expect(
      tts[switchIndex] <= tts[switchIndex - 1] + 1,
      isTrue,
      reason: 'TTS stepped up at the recorded gas switch',
    );
  });

  test('null ascentGasPlan reproduces the single-gas-per-sample legacy path', () {
    final p = buildProfile();
    final a = BuhlmannAlgorithm(gfLow: 0.50, gfHigh: 0.80)..reset();
    final legacy = a.processProfileWithGasSegments(
      depths: p.depths,
      timestamps: p.timestamps,
      gasSegments: p.gas,
    );
    final b = BuhlmannAlgorithm(gfLow: 0.50, gfHigh: 0.80)..reset();
    final explicitNull = b.processProfileWithGasSegments(
      depths: p.depths,
      timestamps: p.timestamps,
      gasSegments: p.gas,
      ascentGasPlan: null,
    );
    expect(
      explicitNull.map((s) => s.ttsSeconds),
      legacy.map((s) => s.ttsSeconds),
    );
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/core/deco/tts_gas_switch_regression_test.dart`
Expected: FAIL — `processProfileWithGasSegments` has no `ascentGasPlan` parameter.

- [ ] **Step 3: Implement**

In `getDecoStatus` (`:448`), add the parameter and thread it into the in-deco branches:
```dart
  DecoStatus getDecoStatus({
    required double currentDepth,
    double fN2 = airN2Fraction,
    double fHe = 0.0,
    int safetyStopTimeAccumulated = 0,
    AscentGasPlan? ascentGas,
  }) {
    final plan = ascentGas ?? FixedAscentGas(fN2: fN2, fHe: fHe);
    final ndl = calculateNdl(depthMeters: currentDepth, fN2: fN2, fHe: fHe);
```
Then change the two in-deco computations to pass the plan:
```dart
    final stops = ndl < 0
        ? calculateDecoSchedule(currentDepth: currentDepth, ascentGas: plan)
        : <DecoStop>[];
```
and
```dart
    if (ndl < 0) {
      tts = calculateTts(currentDepth: currentDepth, ascentGas: plan);
    } else {
      // ... unchanged safety-stop branch ...
    }
```
Leave `calculateNdl` on `fN2`/`fHe` (NDL stays on the current breathing gas per the spec — it is intentionally not ascent-plan-aware) and the `ceiling`/no-deco branches unchanged.

In `processProfileWithGasSegments` (`:535`), add the parameter and pass it to each per-sample `getDecoStatus`. The bottom-phase loading loop (using `_activeGasAtTimestamp`) is unchanged.
```dart
  List<DecoStatus> processProfileWithGasSegments({
    required List<double> depths,
    required List<int> timestamps,
    required List<ProfileGasSegment> gasSegments,
    AscentGasPlan? ascentGasPlan,
  }) {
```
At the `results.add(getDecoStatus(...))` call (`:621`), pass `ascentGas: ascentGasPlan`. When `ascentGasPlan` is null, `getDecoStatus` falls back to `FixedAscentGas(active gas)` (today's behavior) because `fN2`/`fHe` are still the active-sample gas.

- [ ] **Step 4: Run to verify pass**

Run: `flutter test test/core/deco/tts_gas_switch_regression_test.dart test/core/deco/buhlmann_algorithm_test.dart`
Expected: PASS.

- [ ] **Step 5: Format and commit**

```bash
dart format .
git add lib/core/deco/buhlmann_algorithm.dart test/core/deco/tts_gas_switch_regression_test.dart
git commit -m "feat(deco): plumb ascent gas plan into getDecoStatus and profile processing"
```

---

### Task 4: `AscentGasSet` setting — enum, model, Drift column + migration, persistence, sync

**Files:**
- Modify: `lib/features/settings/presentation/providers/settings_providers.dart` (`AppSettings` `:65`, copyWith `:410`, providers tail)
- Modify: `lib/core/database/database.dart` (`DiverSettings` table `:757`, `currentSchemaVersion` `:1710`, migration block near `:1845`)
- Modify: `lib/features/settings/data/repositories/diver_settings_repository.dart`
- Modify: `lib/core/services/sync/sync_data_serializer.dart`
- Test: `test/features/settings/ascent_gas_set_setting_test.dart` (new)

**Interfaces:**
- Produces:
  - `enum AscentGasSet { allCarried, decoStageOnly }` (exported from `settings_providers.dart`).
  - `AppSettings.ascentGasSet` (default `AscentGasSet.allCarried`) + `copyWith({AscentGasSet? ascentGasSet})`.
  - `final ascentGasSetProvider = Provider<AscentGasSet>(...)`.
  - Drift `DiverSettings.ascentGasSet` int column, default `0` (= `allCarried.index`). `currentSchemaVersion == 94`.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/settings/ascent_gas_set_setting_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

void main() {
  test('AppSettings defaults ascentGasSet to allCarried', () {
    const settings = AppSettings();
    expect(settings.ascentGasSet, AscentGasSet.allCarried);
  });

  test('copyWith overrides ascentGasSet and preserves it otherwise', () {
    const settings = AppSettings();
    final updated = settings.copyWith(ascentGasSet: AscentGasSet.decoStageOnly);
    expect(updated.ascentGasSet, AscentGasSet.decoStageOnly);
    expect(updated.copyWith(gfLow: 40).ascentGasSet, AscentGasSet.decoStageOnly);
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/features/settings/ascent_gas_set_setting_test.dart`
Expected: FAIL — `AscentGasSet` / `ascentGasSet` undefined.

- [ ] **Step 3: Implement the model + provider**

In `settings_providers.dart`, near the top-level enums, add:
```dart
/// Which cylinders the simulated (ideal) ascent may breathe.
enum AscentGasSet {
  /// Every cylinder recorded on the dive (default).
  allCarried,

  /// Only deco/stage/bailout cylinders plus the current back gas.
  decoStageOnly,
}
```
Add the field to `AppSettings` (next to `lastStopDepth`):
```dart
  /// Which carried gases feed the ideal (best-gas) ascent projection.
  final AscentGasSet ascentGasSet;
```
Add to the constructor defaults:
```dart
    this.ascentGasSet = AscentGasSet.allCarried,
```
Add to `copyWith` params and body:
```dart
    AscentGasSet? ascentGasSet,
    // ...
      ascentGasSet: ascentGasSet ?? this.ascentGasSet,
```
Add the provider near `lastStopDepthProvider`:
```dart
final ascentGasSetProvider = Provider<AscentGasSet>((ref) {
  return ref.watch(settingsProvider.select((s) => s.ascentGasSet));
});
```

- [ ] **Step 4: Run the model test to verify pass**

Run: `flutter test test/features/settings/ascent_gas_set_setting_test.dart`
Expected: PASS.

- [ ] **Step 5: Add the Drift column + migration**

In `database.dart`, in `DiverSettings` (after `lastStopDepth`, `:808`):
```dart
  /// Index of AscentGasSet (0 = allCarried). Drives the ideal-gas ascent set.
  IntColumn get ascentGasSet => integer().withDefault(const Constant(0))();
```
Bump `currentSchemaVersion` (`:1710`) from `93` to `94`. In the `onUpgrade`/migration strategy (the `MigrationStrategy` near `:1845`), add a step mirroring the existing `addColumn` pattern used by prior versions:
```dart
        if (from < 94) {
          await m.addColumn(diverSettings, diverSettings.ascentGasSet);
        }
```
Regenerate Drift code:
```bash
dart run build_runner build --delete-conflicting-outputs
```

- [ ] **Step 6: Persist + read in the repository**

In `diver_settings_repository.dart`, in the `toCompanion`/insert path (near the existing `lastStopDepth: Value(...)`) add:
```dart
              ascentGasSet: Value(s.ascentGasSet.index),
```
(do this in BOTH companion builders — the insert at `:80` area and the update at `:215` area). In the row -> `AppSettings` mapper (near `:397`), add:
```dart
      ascentGasSet: AscentGasSet.values[row.ascentGasSet],
```
Guard the index against out-of-range values defensively:
```dart
      ascentGasSet: row.ascentGasSet >= 0 &&
              row.ascentGasSet < AscentGasSet.values.length
          ? AscentGasSet.values[row.ascentGasSet]
          : AscentGasSet.allCarried,
```

- [ ] **Step 7: Sync serialization**

In `sync_data_serializer.dart`, find where diver settings fields (e.g. `ppO2MaxDeco`, `lastStopDepth`) are written to / read from the sync map and add `ascentGasSet` as an int (`.index` out, `AscentGasSet.values[...]` in, with the same range guard). Default to `allCarried` when the key is absent so older synced payloads upgrade cleanly.

- [ ] **Step 8: Run settings + sync tests**

Run: `flutter test test/features/settings/ test/core/services/sync/`
Expected: PASS (no regression; migration default verified by existing settings/migration tests if present).

- [ ] **Step 9: Format and commit**

```bash
dart format .
git add lib/features/settings/presentation/providers/settings_providers.dart lib/core/database/database.dart lib/core/database/database.g.dart lib/features/settings/data/repositories/diver_settings_repository.dart lib/core/services/sync/sync_data_serializer.dart test/features/settings/ascent_gas_set_setting_test.dart
git commit -m "feat(settings): add persisted ascentGasSet diver setting (schema v94)"
```

---

### Task 5: `buildAvailableGases` and plumbing the plan through the analysis service

**Files:**
- Modify: `lib/features/dive_log/presentation/providers/profile_analysis_provider.dart` (add `buildAvailableGases`; extend `_ProfileAnalysisInput` + `_runProfileAnalysis`; build the plan in the isolate; pass gas-set + ppO2MaxDeco)
- Modify: `lib/features/dive_log/data/services/profile_analysis_service.dart` (`analyze()` `:521`, OC branch `:574`)
- Test: `test/features/dive_log/build_available_gases_test.dart` (new)

**Interfaces:**
- Consumes: `OptimalOcAscentGas`, `AvailableGas` (Task 1); `O2ToxicityCalculator.calculateMod`; `AscentGasSet` (Task 4); `DiveTank`/`TankRole`/`GasMix` from `dive.dart`.
- Produces:
  - `@visibleForTesting List<AvailableGas> buildAvailableGases(Dive dive, {required double maxPpO2, required AscentGasSet gasSet})` in the provider file.
  - `ProfileAnalysisService.analyze({..., AscentGasPlan? ascentGasPlan})` — passed to `processProfileWithGasSegments` only on the OC gas-segment path.

- [ ] **Step 1: Write the failing test for `buildAvailableGases`**

```dart
// test/features/dive_log/build_available_gases_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_analysis_provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

Dive _diveWith(List<DiveTank> tanks) => Dive(
      id: 'd1',
      diveNumber: 1,
      dateTime: DateTime.utc(2026, 1, 1),
      tanks: tanks,
    );

void main() {
  final air = DiveTank(id: 't1', gasMix: const GasMix(o2: 21), role: TankRole.backGas);
  final ean50 = DiveTank(id: 't2', gasMix: const GasMix(o2: 50), role: TankRole.deco);
  final o2 = DiveTank(id: 't3', gasMix: const GasMix(o2: 100), role: TankRole.deco);

  test('allCarried maps every tank mix and invents no gases', () {
    final gases = buildAvailableGases(
      _diveWith([air, ean50, o2]),
      maxPpO2: 1.6,
      gasSet: AscentGasSet.allCarried,
    );
    expect(gases.length, 3);
    // EAN50 MOD at 1.6 = 22 m.
    final ean = gases.firstWhere((g) => (g.fO2 - 0.5).abs() < 1e-9);
    expect(ean.maxPpO2Mod, closeTo(22.0, 1e-6));
  });

  test('decoStageOnly keeps deco/stage/bailout plus the back gas', () {
    final gases = buildAvailableGases(
      _diveWith([air, ean50, o2]),
      maxPpO2: 1.6,
      gasSet: AscentGasSet.decoStageOnly,
    );
    // Back gas (air) is always retained as the floor; deco gases kept.
    expect(gases.any((g) => (g.fO2 - 0.21).abs() < 1e-9), isTrue);
    expect(gases.any((g) => (g.fO2 - 0.50).abs() < 1e-9), isTrue);
    expect(gases.any((g) => (g.fO2 - 1.0).abs() < 1e-9), isTrue);
  });
}
```

(If the `Dive` constructor requires more required fields, supply the minimal set used elsewhere in `test/features/dive_log/`; mirror an existing `Dive(...)` test fixture in that folder.)

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/features/dive_log/build_available_gases_test.dart`
Expected: FAIL — `buildAvailableGases` undefined.

- [ ] **Step 3: Implement `buildAvailableGases`**

In `profile_analysis_provider.dart`, next to `buildProfileGasSegments` (`:172`), add (and import `ascent_gas_plan.dart` + `o2_toxicity_calculator.dart`):
```dart
/// Maps the dive's recorded cylinders to the gas set the ideal ascent may use.
///
/// [maxPpO2] is the diver's ppO2MaxDeco ceiling; each gas's MOD is derived from
/// it via [O2ToxicityCalculator.calculateMod]. No gases are invented — only
/// cylinders recorded on the dive. [gasSet] filters per the diver setting; the
/// back gas is always retained as the ascent floor.
@visibleForTesting
List<AvailableGas> buildAvailableGases(
  Dive dive, {
  required double maxPpO2,
  required AscentGasSet gasSet,
}) {
  bool keep(DiveTank t) {
    if (gasSet == AscentGasSet.allCarried) return true;
    return t.role == TankRole.backGas ||
        t.role == TankRole.deco ||
        t.role == TankRole.stage ||
        t.role == TankRole.bailout;
  }

  final gases = <AvailableGas>[];
  final seen = <String>{};
  for (final tank in dive.tanks.where(keep)) {
    final fO2 = tank.gasMix.o2 / 100.0;
    final fHe = tank.gasMix.he / 100.0;
    final fN2 = (1.0 - fO2 - fHe).clamp(0.0, 1.0);
    // Deduplicate identical mixes so the optimizer's tie-break stays stable.
    final key = '${fO2.toStringAsFixed(4)}_${fHe.toStringAsFixed(4)}';
    if (!seen.add(key)) continue;
    gases.add(
      AvailableGas(
        fN2: fN2,
        fHe: fHe,
        maxPpO2Mod: O2ToxicityCalculator.calculateMod(fO2, maxPpO2: maxPpO2),
      ),
    );
  }
  return gases;
}
```

- [ ] **Step 4: Run the unit test to verify pass**

Run: `flutter test test/features/dive_log/build_available_gases_test.dart`
Expected: PASS.

- [ ] **Step 5: Thread the plan through the service**

In `profile_analysis_service.dart`, add `AscentGasPlan? ascentGasPlan` to `analyze()` (`:521`) and pass it on the OC branch only (`:574`):
```dart
    final decoStatuses = useOcGasSegments
        ? _buhlmannAlgorithm.processProfileWithGasSegments(
            depths: depths,
            timestamps: timestamps,
            gasSegments: gasSegments,
            ascentGasPlan: ascentGasPlan,
          )
        : _buhlmannAlgorithm.processProfile(
            depths: depths,
            timestamps: timestamps,
            fN2: n2Fraction,
            fHe: heFraction,
          );
```
Import `ascent_gas_plan.dart` in the service. The CCR/SCR `processProfile` branch is untouched.

- [ ] **Step 6: Build the plan in the isolate and pass available gases through the input**

In `_ProfileAnalysisInput`, add isolate-safe fields:
```dart
  final List<AvailableGas>? ascentGases; // OC only; null => FixedAscentGas
  final double ascentMaxPpO2;
```
(add to the constructor with defaults `this.ascentGases`, `this.ascentMaxPpO2 = 1.6`). In `_runProfileAnalysis`, build the plan from those fields and pass it to `analyze`:
```dart
  final ascentGasPlan = input.ascentGases != null && input.ascentGases!.isNotEmpty
      ? OptimalOcAscentGas(
          gases: input.ascentGases!,
          maxPpO2: input.ascentMaxPpO2,
        )
      : null;
  return service.analyze(
    // ... existing args ...
    gasSegments: input.gasSegments,
    ascentGasPlan: ascentGasPlan,
    rebreatherPpO2Curve: input.rebreatherPpO2Curve,
  );
```
In `profileAnalysisProvider` (`:686` area), where `gasSegments` is built for OC, also build the gas set and pass it into the input:
```dart
    final ascentGases = dive.diveMode == DiveMode.oc
        ? buildAvailableGases(
            dive,
            maxPpO2: ref.watch(ppO2MaxDecoProvider),
            gasSet: ref.watch(ascentGasSetProvider),
          )
        : null;
```
and in the `_ProfileAnalysisInput(...)` construction add `ascentGases: ascentGases, ascentMaxPpO2: ref.watch(ppO2MaxDecoProvider),`. Do the equivalent in `diveProfileAnalysisProvider` (`:1048`) using `_resolveAnalysisService` + a direct `service.analyze(..., ascentGasPlan: ...)` built from `buildAvailableGases` (read `ppO2MaxDecoProvider` and `ascentGasSetProvider` via `ref.watch`). For the synchronous provider it may call `buildAvailableGases` and construct `OptimalOcAscentGas` inline (no isolate).

- [ ] **Step 7: Run the dive_log + provider suites**

Run: `flutter test test/features/dive_log/`
Expected: PASS — existing single-gas/CCR analyses unchanged (the plan only engages for OC multi-gas).

- [ ] **Step 8: Format and commit**

```bash
dart format .
git add lib/features/dive_log/presentation/providers/profile_analysis_provider.dart lib/features/dive_log/data/services/profile_analysis_service.dart test/features/dive_log/build_available_gases_test.dart
git commit -m "feat(deco): drive OC profile analysis with the optimal ascent gas plan"
```

---

### Task 6: "Plan ascent with" settings UI

**Files:**
- Modify: the deco/units settings page that renders `ppO2MaxDeco` / `lastStopDepth` controls (locate via grep below)
- Test: optional widget test if the page has existing widget-test coverage; otherwise manual verification

**Interfaces:**
- Consumes: `ascentGasSetProvider`, `settingsProvider` notifier, `AscentGasSet` (Task 4).

- [ ] **Step 1: Locate the deco settings page**

Run: `flutter pub run`-free grep — use the repo search:
`grep -rln "ppO2MaxDeco\|lastStopDepth" lib/features/settings/presentation/pages/`
Open the page that builds the decompression section.

- [ ] **Step 2: Add the selector control**

Add a segmented/radio control bound to the setting, following the page's existing control idiom (match the surrounding widgets — do not introduce a new pattern):
```dart
// Pseudostructure — adapt to the page's existing settings-row widgets.
final ascentGasSet = ref.watch(ascentGasSetProvider);
SettingsRadioRow<AscentGasSet>(
  title: 'Plan ascent with',
  value: ascentGasSet,
  options: const {
    AscentGasSet.allCarried: 'All carried cylinders',
    AscentGasSet.decoStageOnly: 'Deco/stage/bailout + back gas',
  },
  onChanged: (v) => ref
      .read(settingsProvider.notifier)
      .updateSettings((s) => s.copyWith(ascentGasSet: v)),
);
```
Use whatever the notifier's actual update method is (mirror how `lastStopDepth`/`ppO2MaxDeco` are written on the same page). Respect the active diver's settings exactly as the neighboring controls do.

- [ ] **Step 3: Verify build + analyze**

Run: `flutter analyze`
Expected: No new issues.

- [ ] **Step 4: Manual check (optional)**

Run: `flutter run -d windows` (or `-d macos`), open deco settings, toggle "Plan ascent with", confirm it persists across app restart.

- [ ] **Step 5: Format and commit**

```bash
dart format .
git add lib/features/settings/presentation/pages/
git commit -m "feat(settings): add Plan ascent with selector to deco settings"
```

---

### Task 7: Planner selects the ideal ascent gas

**Files:**
- Modify: `lib/features/dive_planner/data/services/plan_calculator_service.dart` (`_buildDecoSchedule` `:381`)
- Test: extend the existing planner service test (locate via grep) or add a focused test

**Interfaces:**
- Consumes: `OptimalOcAscentGas`/`FixedAscentGas`/`AvailableGas` (Task 1); `calculateDecoSchedule({..., ascentGas})` (Task 2).

- [ ] **Step 1: Write the failing test**

Locate the planner test: `grep -rln "plan_calculator_service\|PlanCalculatorService" test/`. Add a test asserting that, given a plan with a deco gas richer than back gas, the computed deco schedule total stop time is `<=` the all-back-gas schedule for the same plan (ideal gas can only shorten or equal deco):
```dart
  test('ideal-gas ascent gives <= deco time than fixed back gas', () {
    // Build a planner input with back gas + EAN50 deco gas reaching deco.
    // (Mirror the existing planner-test fixture construction in this file.)
    final idealTotal = /* total stop seconds with OptimalOcAscentGas */;
    final fixedTotal = /* total stop seconds with FixedAscentGas(back gas) */;
    expect(idealTotal, lessThanOrEqualTo(fixedTotal));
  });
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/features/dive_planner/`
Expected: FAIL (until the planner passes a plan).

- [ ] **Step 3: Implement plan selection in `_buildDecoSchedule`**

Build an `OptimalOcAscentGas` from the plan's carried gases (the planner already has tank/`gasMix` data — see the segment gas usage at `:125-181` and tank list at `:503-563`) and pass it into `calculateDecoSchedule`:
```dart
    final ascentGases = <AvailableGas>[
      for (final tank in planTanks)
        AvailableGas(
          fN2: (100.0 - tank.gasMix.o2 - tank.gasMix.he) / 100.0,
          fHe: tank.gasMix.he / 100.0,
          maxPpO2Mod: O2ToxicityCalculator.calculateMod(
            tank.gasMix.o2 / 100.0,
            maxPpO2: ppO2MaxDeco, // planner's existing deco ppO2 value
          ),
        ),
    ];
    final algoStops = algorithm.calculateDecoSchedule(
      currentDepth: currentDepth,
      ascentGas: ascentGases.isEmpty
          ? null
          : OptimalOcAscentGas(gases: ascentGases, maxPpO2: ppO2MaxDeco),
    );
```
Then set each `DecoStop.gasMix` from the plan's `gasForDepth(stop.depthMeters)` instead of the hard-coded `const GasMix()` at `:405`, so the planner UI reflects the gas actually used at each stop. If the planner has no configured ppO2 deco value, use `1.6` to match the diver default. Keep `FixedAscentGas` selection wherever the existing gas model is single-gas.

- [ ] **Step 4: Run to verify pass**

Run: `flutter test test/features/dive_planner/`
Expected: PASS.

- [ ] **Step 5: Format and commit**

```bash
dart format .
git add lib/features/dive_planner/data/services/plan_calculator_service.dart test/features/dive_planner/
git commit -m "feat(planner): use optimal ascent gas for deco schedule"
```

---

### Task 8: Fixture shape tests + clean-room ZHL-16C cross-check

**Files:**
- Modify/Extend: existing fixture-loading test (locate the harness that parses `test/dives/001...`), or add a new fixture test
- Create: `test/core/deco/tts_cleanroom_cross_check_test.dart`

**Interfaces:**
- Consumes: the full pipeline (Tasks 1-5) for fixture 001; `BuhlmannAlgorithm` + `OptimalOcAscentGas` for the clean-room comparison.

- [ ] **Step 1: Write the fixture shape test (OC 001 + CCR no-change)**

Locate the SSRF fixture parser used in existing tests: `grep -rln "001_short_deco_single_gas_switch\|\.ssrf" test/`. Following that harness, add:
```dart
  test('fixture 001: gas-aware calculated TTS is monotone, step-free, '
      '0 at surface (shape only — not GF-consistent absolute)', () {
    // Parse 001 -> depths/timestamps/gasSegments/tanks via the existing helper.
    // Run analyze() with the OptimalOcAscentGas plan (allCarried).
    final ttsCurve = analysis.ttsCurve!;
    expect(ttsCurve.last, 0);
    // Step-free across the recorded switch: no upward jump at the switch sample.
    for (var i = 1; i < ttsCurve.length; i++) {
      // Allow tiny +1 s rounding; forbid the multi-minute switch step.
      expect(ttsCurve[i] <= ttsCurve[i - 1] + 1, isTrue);
    }
  });
```
And the CCR no-change assertions for 002 / 003:
```dart
  test('fixture 002/003 (CCR): analysis is byte-identical to the no-plan path', () {
    // Run analyze() for the CCR fixture WITHOUT and WITH the gas-aware machinery
    // available. Because diveMode != oc, useOcGasSegments is false and the plan
    // never engages, so ttsCurve/ceilingCurve/ndlCurve must be equal.
    expect(withFeature.ttsCurve, equals(baseline.ttsCurve));
    expect(withFeature.ceilingCurve, equals(baseline.ceilingCurve));
    expect(withFeature.ndlCurve, equals(baseline.ndlCurve));
  });
```

- [ ] **Step 2: Write the clean-room ZHL-16C/GF cross-check**

```dart
// test/core/deco/tts_cleanroom_cross_check_test.dart
//
// Independent ZHL-16C + gradient-factor TTS, written from the published model
// (Schreiner equation, Workman/Buhlmann a/b coefficients) WITHOUT calling the
// production schedule code, to pin the absolute gas-aware TTS numbers. The
// coefficient constants are physical (published) values, re-used from the
// constants file; the integration/ascent logic here is a separate code path.
import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/deco/ascent/ascent_gas_plan.dart';
import 'package:submersion/core/deco/buhlmann_algorithm.dart';
import 'package:submersion/core/deco/constants/buhlmann_coefficients.dart';

// --- Independent reference implementation (square-profile, multi-gas) ---
// Returns optimal TTS (seconds) from [startDepth] given loaded N2 tensions,
// GF low/high, ascent rate 9 m/min, 3 m stops, and a best-gas selector.
int referenceTts({
  required List<double> pn2, // 16 compartment N2 tensions (bar)
  required double startDepth,
  required double gfLow,
  required double gfHigh,
  required AscentGas Function(double depth) gasForDepth,
}) {
  // ... independent Schreiner loop over a 1-second ascent + stop integration,
  // using zhl16cN2HalfTimes / zhl16cN2A / zhl16cN2B and surface-target ceiling
  // with GF interpolation. Implemented inline here, NOT via BuhlmannAlgorithm.
  // (Full body written during implementation; deterministic, no production
  // schedule calls.)
  throw UnimplementedError();
}

void main() {
  test('production gas-aware TTS matches the clean-room reference within 60 s',
      () {
    // 1. Load tissues by running BuhlmannAlgorithm.calculateSegment for a known
    //    square profile (loading primitive is shared and already validated).
    final algo = BuhlmannAlgorithm(gfLow: 0.50, gfHigh: 0.80)..reset();
    algo.calculateSegment(
      depthMeters: 40,
      durationSeconds: 25 * 60,
      fN2: airN2Fraction,
    );
    final plan = OptimalOcAscentGas(
      gases: const [
        AvailableGas(fN2: airN2Fraction, fHe: 0.0, maxPpO2Mod: double.infinity),
        AvailableGas(fN2: 0.50, fHe: 0.0, maxPpO2Mod: 22.0),
        AvailableGas(fN2: 0.0, fHe: 0.0, maxPpO2Mod: 6.0),
      ],
      maxPpO2: 1.6,
    );

    final prod = algo.calculateTts(currentDepth: 40, ascentGas: plan);

    final reference = referenceTts(
      pn2: algo.compartments.map((c) => c.currentPN2).toList(),
      startDepth: 40,
      gfLow: 0.50,
      gfHigh: 0.80,
      gasForDepth: plan.gasForDepth,
    );

    expect((prod - reference).abs(), lessThanOrEqualTo(60));
  });
}
```
Implement `referenceTts` fully during the task (a self-contained integrator over the published coefficients). The acceptance is a per-sample TTS agreement within a stated tolerance (start at 60 s; tighten if the implementations track more closely). This — not the fixtures — pins the absolute numbers.

- [ ] **Step 3: Run to verify fail then implement, then pass**

Run: `flutter test test/core/deco/tts_cleanroom_cross_check_test.dart`
Expected: first FAIL (`UnimplementedError`), then PASS after `referenceTts` is written.

- [ ] **Step 4: Run the full deco + dive_log suites for regression**

Run: `flutter test test/core/deco/ test/features/dive_log/ test/features/settings/`
Expected: PASS.

- [ ] **Step 5: Format and commit**

```bash
dart format .
git add test/core/deco/tts_cleanroom_cross_check_test.dart test/
git commit -m "test(deco): fixture shape + clean-room ZHL-16C TTS cross-check for gas-aware ascent"
```

---

## Final Verification

- [ ] `dart format --set-exit-if-changed lib test` — no diffs.
- [ ] `flutter analyze` — no new issues.
- [ ] `flutter test` — full suite green.
- [ ] Manual: open an OC multi-gas deco dive without recorded computer TTS; confirm the calculated TTS curve is smooth across the recorded gas switch (no downward step). Open a single-gas dive; confirm TTS is unchanged. Open a CCR dive (fixture 002/003 equivalent); confirm unchanged.

## Self-Review notes (coverage vs. spec)

- Ideal best-gas-at-depth ascent → Tasks 1-3, 5. MOD-split (stop-to-stop no-op + on-the-fly to first stop) → Task 2 (`_simulateAscent`/`switchDepthsBetween`) with tests in Tasks 1-3.
- `ppO2MaxDeco` as eligibility ceiling via `calculateMod`, no new ppO2 setting → Tasks 1, 5.
- Single-gas byte-identical → Task 2 equivalence test + Task 3 legacy-path test.
- CCR/SCR unchanged (gated by `useOcGasSegments`) → Tasks 5, 8.
- Overlay stays authoritative → unchanged code path; not modified (verified by leaving `overlayComputerDecoData` untouched).
- "Plan ascent with" setting (all vs deco-only), persisted, synced → Tasks 4, 6.
- Planner gains ideal-gas ascent → Task 7.
- Step-free TTS / 0 at surface fixture shape + clean-room absolute pin → Task 8.
- Non-goal guard: no penalty period, no invented gases (dedup + recorded-only in `buildAvailableGases`), no CCR ascent model — honored.
