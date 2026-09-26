# Counterfactual Dive Lab Phase 1 (Engine + Domain) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A pure-Dart `ScenarioEngine` that takes a logged dive, a branch point and a list of interventions and returns a like-for-like `ScenarioOutcome` (actual vs counterfactual `ProfileAnalysis`, consumption, deltas, flags) in replay and re-plan mode.

**Architecture:** New module `lib/features/dive_lab/domain/` (entities + services, no Flutter imports). Replay re-runs `ProfileAnalysisService.analyze` over the recorded samples with the gas schedule rewritten after T. Re-plan derives a `BranchState` (tissues + GF-low anchor, CNS, OTU, per-tank pressure, SAC), compiles the dive's remaining bottom into a `DivePlan`, runs `PlanEngine.compute(plan, startState:)`, synthesises the remainder at 10 s, splices it onto the actual samples and analyses the spliced profile. One small change outside the module: `DecoStatus` gains the GF-low anchor so the mid-dive restore is exact.

**Tech Stack:** Dart 3 (sealed classes, records), `equatable`, existing `lib/core/deco` (BuhlmannAlgorithm, DecoModel, ProfileGasSegment, OptimalOcAscentGas), `lib/features/planner` (PlanEngine, DivePlan, PlanOutcome), `lib/features/dive_log` (ProfileAnalysisService, DiveTank, GasMix), `flutter_test`.

**Spec:** `docs/superpowers/specs/2026-08-21-counterfactual-dive-lab-design.md` (sections "Scope and the scenario model" and "Engine"; this plan implements Phase 1 of the phase table).

## Global Constraints

- Work in the worktree `.claude/worktrees/counterfactual-dive-lab` on branch `worktree-counterfactual-dive-lab`; every Read/Edit/Write path is absolute under that root (the Bash cwd can silently reset to the main checkout).
- Engine and domain code under `lib/features/dive_lab/domain/` imports nothing from `package:flutter/` and nothing from any `presentation/` directory.
- No em-dashes anywhere (code, comments, docs, commit messages); no emojis in code or docs.
- `dart format` clean for every file touched (run `dart format lib test` before each commit); `flutter analyze` clean for the whole project before the final commit.
- Files stay under 800 lines; prefer 200-400.
- Hand-computed test vectors only (compute the expected number in the test or in a comment; never recall one).
- Metric units internally (meters, bar, liters, seconds). SAC in L/min at surface pressure.
- Commits: local only on the feature branch, no pushes, no `Co-Authored-By` trailer.
- Test command shape: `cd <worktree> && flutter test <path>` (bare `flutter test` has no `-C`; confirm the cwd first with `pwd`).

## File structure

```
lib/core/deco/entities/deco_status.dart                 (modify: gfLowCeilingAnchor field)
lib/core/deco/buhlmann_algorithm.dart                   (modify: getDecoStatus sets the anchor)
lib/features/planner/domain/services/plan_engine.dart   (modify: public ascentPlanFor)

lib/features/dive_lab/domain/entities/
  scenario_mode.dart                 ScenarioMode enum
  scenario_intervention.dart         sealed ScenarioIntervention + TankRef + InterventionKind
  scenario_intervention_codec.dart   JSON codec (formatVersion 1)
  dive_scenario.dart                 DiveScenario aggregate + validateInterventions
  scenario_settings.dart             ScenarioSettings (analysis + engine configuration)
  scenario_request.dart              ScenarioRequest, ScenarioGasSwitch, TankPressureSample
  branch_state.dart                  BranchState, TankPressureAtBranch, PressureSource, SacSource
  scenario_delta.dart                DeltaMetric, DeltaUnit, BetterWhen, ScenarioDelta
  scenario_outcome.dart              ScenarioOutcome, ScenarioFlag, ScenarioConsumption, TankConsumption

lib/features/dive_lab/domain/services/
  tank_schedule.dart                 TankSchedule (tank in force over time) + gas segments + best tank by depth
  replay_schedule_rewriter.dart      rewriteScheduleForReplay
  sac_resolver.dart                  resolveBranchSac
  branch_state_builder.dart          branchIndexFor + buildBranchState
  remaining_bottom_compiler.dart     finalAscentStartIndex + compileRemainingBottom
  scenario_plan_compiler.dart        compileScenarioPlan
  counterfactual_profile_synthesizer.dart  synthesizeRemainder + spliceCounterfactual
  consumption_pass.dart              simulateConsumption
  scenario_delta_builder.dart        buildDeltas + selectVerdictDeltas
  scenario_engine.dart               ScenarioEngine.run + runScenarioEngine (compute entry)

test/core/deco/deco_status_anchor_test.dart
test/features/dive_lab/domain/... one test file per entity/service above
test/features/dive_lab/domain/support/synthetic_dives.dart   shared synthetic profiles
```

---

### Task 1: `DecoStatus.gfLowCeilingAnchor` (exact mid-dive restore)

**Files:**
- Modify: `lib/core/deco/entities/deco_status.dart`
- Modify: `lib/core/deco/buhlmann_algorithm.dart` (`getDecoStatus`, around line 701)
- Test: `test/core/deco/deco_status_anchor_test.dart`

**Interfaces:**
- Produces: `DecoStatus.gfLowCeilingAnchor` (`double?`, meters, null for hand-built statuses); set by every status produced by `BuhlmannAlgorithm.getDecoStatus` and therefore by `processProfile` / `processProfileWithGasSegments`.

- [ ] **Step 1: Write the failing test**

```dart
// test/core/deco/deco_status_anchor_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/deco/buhlmann_algorithm.dart';
import 'package:submersion/core/deco/constants/buhlmann_coefficients.dart';
import 'package:submersion/core/deco/entities/profile_gas_segment.dart';

/// 45 m for 25 min on air, ascend at 9 m/min to 21 m, hold 6 min, ascend to
/// 6 m, hold 10 min, surface. 10 s samples. Deep enough to set a deep GF-low
/// anchor that later off-gassing would otherwise re-derive shallower.
({List<double> depths, List<int> timestamps}) _profile() {
  final depths = <double>[];
  final timestamps = <int>[];
  var t = 0;
  void add(double d) {
    depths.add(d);
    timestamps.add(t);
    t += 10;
  }

  for (var i = 0; i <= 15; i++) {
    add(45.0 * i / 15); // 150 s descent
  }
  for (var i = 0; i < 150; i++) {
    add(45.0);
  }
  for (var i = 1; i <= 16; i++) {
    add(45.0 - 24.0 * i / 16); // 160 s to 21 m
  }
  for (var i = 0; i < 36; i++) {
    add(21.0);
  }
  for (var i = 1; i <= 10; i++) {
    add(21.0 - 15.0 * i / 10); // 100 s to 6 m
  }
  for (var i = 0; i < 60; i++) {
    add(6.0);
  }
  for (var i = 1; i <= 4; i++) {
    add(6.0 - 6.0 * i / 4);
  }
  return (depths: depths, timestamps: timestamps);
}

void main() {
  group('DecoStatus.gfLowCeilingAnchor', () {
    test('every status from a profile walk carries the running anchor', () {
      final p = _profile();
      final statuses = BuhlmannAlgorithm(
        gfLow: 0.30,
        gfHigh: 0.80,
      ).processProfile(depths: p.depths, timestamps: p.timestamps);
      expect(statuses.every((s) => s.gfLowCeilingAnchor != null), isTrue);
      // Running max: never decreases along the dive.
      for (var i = 1; i < statuses.length; i++) {
        expect(
          statuses[i].gfLowCeilingAnchor!,
          greaterThanOrEqualTo(statuses[i - 1].gfLowCeilingAnchor! - 1e-9),
        );
      }
      expect(statuses.last.gfLowCeilingAnchor!, greaterThan(0));
    });

    test('restoring from a mid-profile status continues the run exactly', () {
      final p = _profile();
      final full = BuhlmannAlgorithm(gfLow: 0.30, gfHigh: 0.80);
      final statuses = full.processProfile(
        depths: p.depths,
        timestamps: p.timestamps,
      );
      // Branch during the 21 m hold (after the deep anchor was set and some
      // off-gassing has happened).
      final split = 15 + 150 + 16 + 20;
      final tailDepths = p.depths.sublist(split);
      final tailTimes = p.timestamps.sublist(split);
      final seg = [
        ProfileGasSegment(startTimestamp: tailTimes.first, fN2: airN2Fraction),
      ];

      final exact = BuhlmannAlgorithm(gfLow: 0.30, gfHigh: 0.80)
        ..restoreState(
          statuses[split].compartments,
          gfLowCeilingAnchor: statuses[split].gfLowCeilingAnchor!,
        );
      final tail = exact.processProfileWithGasSegments(
        depths: tailDepths,
        timestamps: tailTimes,
        gasSegments: seg,
      );
      for (var k = 0; k < tail.length; k++) {
        expect(
          tail[k].ceilingMeters,
          closeTo(statuses[split + k].ceilingMeters, 1e-9),
          reason: 'sample $k',
        );
        expect(
          tail[k].ttsSeconds,
          statuses[split + k].ttsSeconds,
          reason: 'tts sample $k',
        );
      }

      // Control: setCompartments re-derives the anchor from the off-gassed
      // state and diverges somewhere in the tail.
      final rederived = BuhlmannAlgorithm(gfLow: 0.30, gfHigh: 0.80)
        ..setCompartments(statuses[split].compartments);
      final control = rederived.processProfileWithGasSegments(
        depths: tailDepths,
        timestamps: tailTimes,
        gasSegments: seg,
      );
      final diverges = List.generate(
        control.length,
        (k) => (control[k].ceilingMeters - statuses[split + k].ceilingMeters)
            .abs(),
      ).any((d) => d > 0.01);
      expect(diverges, isTrue);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/counterfactual-dive-lab && flutter test test/core/deco/deco_status_anchor_test.dart`
Expected: compile error, `gfLowCeilingAnchor` isn't defined for `DecoStatus`.

- [ ] **Step 3: Add the field and set it**

In `deco_status.dart` add after `surfacePressureBar`:

```dart
  /// Deepest GF-low ceiling (meters) reached so far in the dive at this
  /// sample: the running anchor BuhlmannAlgorithm interpolates gradient
  /// factors from. Together with [compartments] it is the complete restorable
  /// mid-dive state (`BuhlmannAlgorithm.restoreState`). Null when the status
  /// was not produced by a profile walk (hand-built statuses, older callers).
  final double? gfLowCeilingAnchor;
```

Add `this.gfLowCeilingAnchor,` to the constructor, `double? gfLowCeilingAnchor,` to `copyWith` (`gfLowCeilingAnchor: gfLowCeilingAnchor ?? this.gfLowCeilingAnchor`), and `gfLowCeilingAnchor` to `props`.

In `buhlmann_algorithm.dart` `getDecoStatus`, in the returned `DecoStatus(...)` add `gfLowCeilingAnchor: _gfLowCeilingAnchor,`.

- [ ] **Step 4: Run the test and the deco suite**

Run: `flutter test test/core/deco/deco_status_anchor_test.dart test/core/deco/` (from the worktree)
Expected: all PASS. If the control assertion (`diverges`) fails, lengthen the bottom to 30 min; the exactness assertions must pass unchanged.

- [ ] **Step 5: Commit**

```bash
git add lib/core/deco/entities/deco_status.dart lib/core/deco/buhlmann_algorithm.dart test/core/deco/deco_status_anchor_test.dart
git commit -m "feat(deco): carry the GF-low ceiling anchor on DecoStatus"
```

---

### Task 2: Scenario model (mode, interventions, DiveScenario, validation)

**Files:**
- Create: `lib/features/dive_lab/domain/entities/scenario_mode.dart`
- Create: `lib/features/dive_lab/domain/entities/scenario_intervention.dart`
- Create: `lib/features/dive_lab/domain/entities/dive_scenario.dart`
- Test: `test/features/dive_lab/domain/entities/dive_scenario_test.dart`

**Interfaces:**
- Produces: `enum ScenarioMode { replay, replan }`; `enum InterventionKind {switchGas, loseTank, shiftAscent, ascendNow, changeGf, shareGas, bailOut, ascentPolicy}`; `sealed class TankRef` with `ExistingTankRef(tankId)` and `HypotheticalTankRef(gasMix, volumeLiters, startPressureBar)` (+ `tankId` getter); `sealed class ScenarioIntervention` with `kind`, `requiresReplan`, `impliesAscendNow` and subclasses `SwitchGasIntervention(tank)`, `LoseTankIntervention(tankId)`, `ShiftAscentIntervention(deltaSeconds)`, `AscendNowIntervention()`, `ChangeGfIntervention(gfLow, gfHigh)`, `ShareGasIntervention(buddyFactor)`, `BailOutIntervention(tankId?)`, `AscentPolicyIntervention(ascentRate?, lastStopDepth?, extraLastStopSeconds?, gasSwitchStopSeconds?)`; `DiveScenario` (`id, diveId, name, notes, branchSeconds, mode, interventions, createdAt, updatedAt`, `effectiveMode`, `abortsAtBranch`, `copyWith`); `enum ScenarioValidationError { duplicateKind, shiftAscentWithAbort }`; `List<ScenarioValidationError> validateInterventions(List<ScenarioIntervention>)`.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/dive_lab/domain/entities/dive_scenario_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_lab/domain/entities/dive_scenario.dart';
import 'package:submersion/features/dive_lab/domain/entities/scenario_intervention.dart';
import 'package:submersion/features/dive_lab/domain/entities/scenario_mode.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

DiveScenario _scenario(
  List<ScenarioIntervention> interventions, {
  ScenarioMode mode = ScenarioMode.replay,
}) => DiveScenario(
  id: 's1',
  diveId: 'd1',
  name: 'test',
  branchSeconds: 1200,
  mode: mode,
  interventions: interventions,
  createdAt: DateTime(2026, 8, 21),
  updatedAt: DateTime(2026, 8, 21),
);

void main() {
  group('ScenarioIntervention flags', () {
    test('path-changing kinds require re-plan', () {
      expect(const ShiftAscentIntervention(deltaSeconds: -300).requiresReplan,
          isTrue);
      expect(const AscendNowIntervention().requiresReplan, isTrue);
      expect(const AscentPolicyIntervention(ascentRate: 6).requiresReplan,
          isTrue);
      expect(const ChangeGfIntervention(gfLow: 40, gfHigh: 85).requiresReplan,
          isFalse);
      expect(const LoseTankIntervention(tankId: 't').requiresReplan, isFalse);
    });

    test('aborting kinds imply ascend-now', () {
      expect(const ShareGasIntervention().impliesAscendNow, isTrue);
      expect(const BailOutIntervention().impliesAscendNow, isTrue);
      expect(const AscendNowIntervention().impliesAscendNow, isTrue);
      expect(
        const SwitchGasIntervention(tank: ExistingTankRef('t')).impliesAscendNow,
        isFalse,
      );
    });

    test('hypothetical tank ref has a stable derived id', () {
      const ref = HypotheticalTankRef(
        gasMix: GasMix(o2: 50),
        volumeLiters: 11.1,
        startPressureBar: 200,
      );
      expect(ref.tankId, 'lab-hypothetical-50-0-11-200');
      expect(ref.tankId, const HypotheticalTankRef(
        gasMix: GasMix(o2: 50),
        volumeLiters: 11.1,
        startPressureBar: 200,
      ).tankId);
    });
  });

  group('DiveScenario', () {
    test('effectiveMode flips to re-plan when a path change is present', () {
      expect(_scenario(const []).effectiveMode, ScenarioMode.replay);
      expect(
        _scenario(const [AscendNowIntervention()]).effectiveMode,
        ScenarioMode.replan,
      );
      expect(
        _scenario(
          const [ChangeGfIntervention(gfLow: 40, gfHigh: 85)],
          mode: ScenarioMode.replan,
        ).effectiveMode,
        ScenarioMode.replan,
      );
    });

    test('abortsAtBranch only in re-plan with an aborting intervention', () {
      expect(_scenario(const [ShareGasIntervention()]).abortsAtBranch, isFalse);
      expect(
        _scenario(const [ShareGasIntervention()], mode: ScenarioMode.replan)
            .abortsAtBranch,
        isTrue,
      );
    });

    test('copyWith replaces interventions', () {
      final s = _scenario(const []);
      final c = s.copyWith(interventions: const [AscendNowIntervention()]);
      expect(c.interventions, hasLength(1));
      expect(s.interventions, isEmpty);
      expect(c.id, s.id);
    });
  });

  group('validateInterventions', () {
    test('duplicate kinds are rejected', () {
      final errors = validateInterventions(const [
        ChangeGfIntervention(gfLow: 30, gfHigh: 70),
        ChangeGfIntervention(gfLow: 40, gfHigh: 85),
      ]);
      expect(errors, contains(ScenarioValidationError.duplicateKind));
    });

    test('shiftAscent cannot combine with an aborting kind', () {
      final errors = validateInterventions(const [
        ShiftAscentIntervention(deltaSeconds: -60),
        ShareGasIntervention(),
      ]);
      expect(errors, contains(ScenarioValidationError.shiftAscentWithAbort));
    });

    test('a valid stack has no errors', () {
      expect(
        validateInterventions(const [
          LoseTankIntervention(tankId: 'deco'),
          ChangeGfIntervention(gfLow: 40, gfHigh: 85),
          AscendNowIntervention(),
        ]),
        isEmpty,
      );
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/dive_lab/domain/entities/dive_scenario_test.dart`
Expected: FAIL, imports not found.

- [ ] **Step 3: Write the entities**

`scenario_mode.dart`:

```dart
/// How the counterfactual timeline is produced.
///
/// [replay] keeps the recorded depth path and changes only inputs (gas,
/// gradient factors, consumption). [replan] hands the remainder of the dive
/// to the planner engine, which computes the ascent and decompression.
enum ScenarioMode { replay, replan }
```

`scenario_intervention.dart`:

```dart
import 'package:equatable/equatable.dart';

import 'package:submersion/features/dive_log/domain/entities/dive.dart';

/// The kinds of "one changed decision" a scenario can apply from the branch
/// point onward. Stable names: they are the JSON `kind` discriminator.
enum InterventionKind {
  switchGas,
  loseTank,
  shiftAscent,
  ascendNow,
  changeGf,
  shareGas,
  bailOut,
  ascentPolicy,
}

/// A cylinder an intervention refers to: one the dive carried, or a
/// hypothetical cylinder the diver did not have.
sealed class TankRef extends Equatable {
  const TankRef();

  /// The id the compiled plan and the consumption pass use for this tank.
  String get tankId;
}

class ExistingTankRef extends TankRef {
  const ExistingTankRef(this.tankId);

  @override
  final String tankId;

  @override
  List<Object?> get props => [tankId];
}

class HypotheticalTankRef extends TankRef {
  const HypotheticalTankRef({
    required this.gasMix,
    required this.volumeLiters,
    required this.startPressureBar,
  });

  final GasMix gasMix;
  final double volumeLiters;
  final double startPressureBar;

  /// Deterministic so the same hypothetical tank gets the same id across
  /// recomputes and in saved scenarios.
  @override
  String get tankId =>
      'lab-hypothetical-${gasMix.roundedO2}-${gasMix.roundedHe}-'
      '${volumeLiters.round()}-${startPressureBar.round()}';

  @override
  List<Object?> get props => [gasMix, volumeLiters, startPressureBar];
}

/// One changed decision applied from the branch point onward.
sealed class ScenarioIntervention extends Equatable {
  const ScenarioIntervention();

  InterventionKind get kind;

  /// Path-changing kinds can only be evaluated by re-planning the remainder.
  bool get requiresReplan => false;

  /// Kinds that abort the dive at the branch point in re-plan mode.
  bool get impliesAscendNow => false;
}

class SwitchGasIntervention extends ScenarioIntervention {
  const SwitchGasIntervention({required this.tank});
  final TankRef tank;
  @override
  InterventionKind get kind => InterventionKind.switchGas;
  @override
  List<Object?> get props => [tank];
}

class LoseTankIntervention extends ScenarioIntervention {
  const LoseTankIntervention({required this.tankId});
  final String tankId;
  @override
  InterventionKind get kind => InterventionKind.loseTank;
  @override
  List<Object?> get props => [tankId];
}

class ShiftAscentIntervention extends ScenarioIntervention {
  const ShiftAscentIntervention({required this.deltaSeconds});

  /// Negative = begin the ascent earlier.
  final int deltaSeconds;
  @override
  InterventionKind get kind => InterventionKind.shiftAscent;
  @override
  bool get requiresReplan => true;
  @override
  List<Object?> get props => [deltaSeconds];
}

class AscendNowIntervention extends ScenarioIntervention {
  const AscendNowIntervention();
  @override
  InterventionKind get kind => InterventionKind.ascendNow;
  @override
  bool get requiresReplan => true;
  @override
  bool get impliesAscendNow => true;
  @override
  List<Object?> get props => const [];
}

class ChangeGfIntervention extends ScenarioIntervention {
  const ChangeGfIntervention({required this.gfLow, required this.gfHigh});

  /// Percent (0-100).
  final int gfLow;
  final int gfHigh;
  @override
  InterventionKind get kind => InterventionKind.changeGf;
  @override
  List<Object?> get props => [gfLow, gfHigh];
}

class ShareGasIntervention extends ScenarioIntervention {
  const ShareGasIntervention({this.buddyFactor});

  /// Null = the engine's configured buddy factor.
  final double? buddyFactor;
  @override
  InterventionKind get kind => InterventionKind.shareGas;
  @override
  bool get impliesAscendNow => true;
  @override
  List<Object?> get props => [buddyFactor];
}

class BailOutIntervention extends ScenarioIntervention {
  const BailOutIntervention({this.tank});

  /// Null = every bailout-role tank the dive carried.
  final TankRef? tank;
  @override
  InterventionKind get kind => InterventionKind.bailOut;
  @override
  bool get impliesAscendNow => true;
  @override
  List<Object?> get props => [tank];
}

class AscentPolicyIntervention extends ScenarioIntervention {
  const AscentPolicyIntervention({
    this.ascentRate,
    this.lastStopDepth,
    this.extraLastStopSeconds,
    this.gasSwitchStopSeconds,
  });

  final double? ascentRate;
  final double? lastStopDepth;
  final int? extraLastStopSeconds;
  final int? gasSwitchStopSeconds;
  @override
  InterventionKind get kind => InterventionKind.ascentPolicy;
  @override
  bool get requiresReplan => true;
  @override
  List<Object?> get props => [
    ascentRate,
    lastStopDepth,
    extraLastStopSeconds,
    gasSwitchStopSeconds,
  ];
}
```

`dive_scenario.dart`:

```dart
import 'package:equatable/equatable.dart';

import 'package:submersion/features/dive_lab/domain/entities/scenario_intervention.dart';
import 'package:submersion/features/dive_lab/domain/entities/scenario_mode.dart';

/// A saved "what if" on a logged dive: inputs only; results are recomputed.
class DiveScenario extends Equatable {
  const DiveScenario({
    required this.id,
    required this.diveId,
    required this.name,
    this.notes,
    required this.branchSeconds,
    required this.mode,
    this.interventions = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String diveId;
  final String name;
  final String? notes;

  /// Runtime seconds on the dive's primary profile where the timelines part.
  final int branchSeconds;
  final ScenarioMode mode;
  final List<ScenarioIntervention> interventions;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// The mode the engine actually runs: a path-changing intervention forces
  /// re-plan regardless of the stored mode.
  ScenarioMode get effectiveMode =>
      interventions.any((i) => i.requiresReplan) ? ScenarioMode.replan : mode;

  /// Whether the counterfactual aborts the dive at the branch point.
  bool get abortsAtBranch =>
      effectiveMode == ScenarioMode.replan &&
      interventions.any((i) => i.impliesAscendNow);

  DiveScenario copyWith({
    String? id,
    String? diveId,
    String? name,
    String? notes,
    bool clearNotes = false,
    int? branchSeconds,
    ScenarioMode? mode,
    List<ScenarioIntervention>? interventions,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DiveScenario(
      id: id ?? this.id,
      diveId: diveId ?? this.diveId,
      name: name ?? this.name,
      notes: clearNotes ? null : (notes ?? this.notes),
      branchSeconds: branchSeconds ?? this.branchSeconds,
      mode: mode ?? this.mode,
      interventions: interventions ?? this.interventions,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    diveId,
    name,
    notes,
    branchSeconds,
    mode,
    interventions,
    createdAt,
    updatedAt,
  ];
}

enum ScenarioValidationError { duplicateKind, shiftAscentWithAbort }

/// Composition rules from the spec: at most one intervention per kind, and a
/// shifted ascent cannot combine with a kind that aborts the dive.
List<ScenarioValidationError> validateInterventions(
  List<ScenarioIntervention> interventions,
) {
  final errors = <ScenarioValidationError>[];
  final kinds = <InterventionKind>{};
  for (final i in interventions) {
    if (!kinds.add(i.kind)) {
      errors.add(ScenarioValidationError.duplicateKind);
      break;
    }
  }
  final hasShift = interventions.any((i) => i.kind == InterventionKind.shiftAscent);
  final hasAbort = interventions.any((i) => i.impliesAscendNow);
  if (hasShift && hasAbort) {
    errors.add(ScenarioValidationError.shiftAscentWithAbort);
  }
  return errors;
}
```

- [ ] **Step 4: Run the test**

Run: `flutter test test/features/dive_lab/domain/entities/dive_scenario_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/dive_lab/domain/entities/scenario_mode.dart lib/features/dive_lab/domain/entities/scenario_intervention.dart lib/features/dive_lab/domain/entities/dive_scenario.dart test/features/dive_lab/domain/entities/dive_scenario_test.dart
git commit -m "feat(dive-lab): scenario model, interventions and validation"
```

---

### Task 3: Intervention JSON codec

**Files:**
- Create: `lib/features/dive_lab/domain/entities/scenario_intervention_codec.dart`
- Test: `test/features/dive_lab/domain/entities/scenario_intervention_codec_test.dart`

**Interfaces:**
- Produces: `const int scenarioInterventionFormatVersion = 1;` `String encodeInterventions(List<ScenarioIntervention>)`; `List<ScenarioIntervention> decodeInterventions(String json)` (throws `FormatException` on malformed input, unknown kind, or a newer `formatVersion`); `Map<String, Object?> interventionToJson(ScenarioIntervention)`; `ScenarioIntervention interventionFromJson(Map<String, Object?>)`.
- JSON shape: `{"formatVersion":1,"interventions":[{"kind":"switchGas","tank":{"type":"existing","tankId":"t1"}}, {"kind":"switchGas","tank":{"type":"hypothetical","o2":50.0,"he":0.0,"volumeLiters":11.1,"startPressureBar":200.0}}, {"kind":"loseTank","tankId":"t2"}, {"kind":"shiftAscent","deltaSeconds":-300}, {"kind":"ascendNow"}, {"kind":"changeGf","gfLow":40,"gfHigh":85}, {"kind":"shareGas","buddyFactor":2.0}, {"kind":"bailOut","tank":null}, {"kind":"ascentPolicy","ascentRate":6.0,"lastStopDepth":6.0,"extraLastStopSeconds":120,"gasSwitchStopSeconds":60}]}`

- [ ] **Step 1: Write the failing test**

```dart
// test/features/dive_lab/domain/entities/scenario_intervention_codec_test.dart
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_lab/domain/entities/scenario_intervention.dart';
import 'package:submersion/features/dive_lab/domain/entities/scenario_intervention_codec.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

void main() {
  const all = <ScenarioIntervention>[
    SwitchGasIntervention(tank: ExistingTankRef('t1')),
    SwitchGasIntervention(
      tank: HypotheticalTankRef(
        gasMix: GasMix(o2: 50),
        volumeLiters: 11.1,
        startPressureBar: 200,
      ),
    ),
    LoseTankIntervention(tankId: 't2'),
    ShiftAscentIntervention(deltaSeconds: -300),
    AscendNowIntervention(),
    ChangeGfIntervention(gfLow: 40, gfHigh: 85),
    ShareGasIntervention(buddyFactor: 2.0),
    ShareGasIntervention(),
    BailOutIntervention(),
    BailOutIntervention(tank: ExistingTankRef('bo')),
    AscentPolicyIntervention(
      ascentRate: 6,
      lastStopDepth: 6,
      extraLastStopSeconds: 120,
      gasSwitchStopSeconds: 60,
    ),
    AscentPolicyIntervention(),
  ];

  test('every kind round-trips', () {
    final json = encodeInterventions(all);
    expect(decodeInterventions(json), equals(all));
  });

  test('the envelope carries the format version and kind names', () {
    final map = jsonDecode(encodeInterventions(all)) as Map<String, Object?>;
    expect(map['formatVersion'], scenarioInterventionFormatVersion);
    final list = map['interventions'] as List;
    expect((list.first as Map)['kind'], 'switchGas');
    expect((list[4] as Map)['kind'], 'ascendNow');
  });

  test('empty list round-trips', () {
    expect(decodeInterventions(encodeInterventions(const [])), isEmpty);
  });

  test('a newer format version is rejected', () {
    final json = jsonEncode({'formatVersion': 99, 'interventions': []});
    expect(() => decodeInterventions(json), throwsFormatException);
  });

  test('an unknown kind is rejected', () {
    final json = jsonEncode({
      'formatVersion': 1,
      'interventions': [
        {'kind': 'teleport'},
      ],
    });
    expect(() => decodeInterventions(json), throwsFormatException);
  });

  test('malformed input is rejected', () {
    expect(() => decodeInterventions('not json'), throwsFormatException);
    expect(() => decodeInterventions('[]'), throwsFormatException);
    expect(
      () => decodeInterventions(jsonEncode({'formatVersion': 1})),
      throwsFormatException,
    );
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/dive_lab/domain/entities/scenario_intervention_codec_test.dart`
Expected: FAIL, codec file missing.

- [ ] **Step 3: Write the codec**

```dart
// lib/features/dive_lab/domain/entities/scenario_intervention_codec.dart
import 'dart:convert';

import 'package:submersion/features/dive_lab/domain/entities/scenario_intervention.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

/// Version of the interventions JSON envelope. Bump when a kind's fields
/// change shape; decoding a newer version than this is refused.
const int scenarioInterventionFormatVersion = 1;

String encodeInterventions(List<ScenarioIntervention> interventions) =>
    jsonEncode({
      'formatVersion': scenarioInterventionFormatVersion,
      'interventions': [for (final i in interventions) interventionToJson(i)],
    });

List<ScenarioIntervention> decodeInterventions(String json) {
  final Object? decoded;
  try {
    decoded = jsonDecode(json);
  } on FormatException {
    rethrow;
  }
  if (decoded is! Map<String, Object?>) {
    throw const FormatException('interventions envelope must be an object');
  }
  final version = decoded['formatVersion'];
  if (version is! int) {
    throw const FormatException('interventions envelope lacks formatVersion');
  }
  if (version > scenarioInterventionFormatVersion) {
    throw FormatException(
      'interventions formatVersion $version is newer than supported '
      '$scenarioInterventionFormatVersion',
    );
  }
  final list = decoded['interventions'];
  if (list is! List) {
    throw const FormatException('interventions envelope lacks a list');
  }
  return [
    for (final item in list)
      interventionFromJson(_asMap(item, 'intervention')),
  ];
}

Map<String, Object?> interventionToJson(ScenarioIntervention i) {
  return switch (i) {
    SwitchGasIntervention(:final tank) => {
      'kind': i.kind.name,
      'tank': _tankRefToJson(tank),
    },
    LoseTankIntervention(:final tankId) => {
      'kind': i.kind.name,
      'tankId': tankId,
    },
    ShiftAscentIntervention(:final deltaSeconds) => {
      'kind': i.kind.name,
      'deltaSeconds': deltaSeconds,
    },
    AscendNowIntervention() => {'kind': i.kind.name},
    ChangeGfIntervention(:final gfLow, :final gfHigh) => {
      'kind': i.kind.name,
      'gfLow': gfLow,
      'gfHigh': gfHigh,
    },
    ShareGasIntervention(:final buddyFactor) => {
      'kind': i.kind.name,
      'buddyFactor': buddyFactor,
    },
    BailOutIntervention(:final tank) => {
      'kind': i.kind.name,
      'tank': tank == null ? null : _tankRefToJson(tank),
    },
    AscentPolicyIntervention(
      :final ascentRate,
      :final lastStopDepth,
      :final extraLastStopSeconds,
      :final gasSwitchStopSeconds,
    ) =>
      {
        'kind': i.kind.name,
        'ascentRate': ascentRate,
        'lastStopDepth': lastStopDepth,
        'extraLastStopSeconds': extraLastStopSeconds,
        'gasSwitchStopSeconds': gasSwitchStopSeconds,
      },
  };
}

ScenarioIntervention interventionFromJson(Map<String, Object?> map) {
  final kindName = map['kind'];
  final kind = InterventionKind.values.cast<InterventionKind?>().firstWhere(
    (k) => k!.name == kindName,
    orElse: () => null,
  );
  if (kind == null) {
    throw FormatException('unknown intervention kind: $kindName');
  }
  return switch (kind) {
    InterventionKind.switchGas => SwitchGasIntervention(
      tank: _tankRefFromJson(_asMap(map['tank'], 'tank')),
    ),
    InterventionKind.loseTank => LoseTankIntervention(
      tankId: _asString(map['tankId'], 'tankId'),
    ),
    InterventionKind.shiftAscent => ShiftAscentIntervention(
      deltaSeconds: _asInt(map['deltaSeconds'], 'deltaSeconds'),
    ),
    InterventionKind.ascendNow => const AscendNowIntervention(),
    InterventionKind.changeGf => ChangeGfIntervention(
      gfLow: _asInt(map['gfLow'], 'gfLow'),
      gfHigh: _asInt(map['gfHigh'], 'gfHigh'),
    ),
    InterventionKind.shareGas => ShareGasIntervention(
      buddyFactor: _asDoubleOrNull(map['buddyFactor']),
    ),
    InterventionKind.bailOut => BailOutIntervention(
      tank: map['tank'] == null
          ? null
          : _tankRefFromJson(_asMap(map['tank'], 'tank')),
    ),
    InterventionKind.ascentPolicy => AscentPolicyIntervention(
      ascentRate: _asDoubleOrNull(map['ascentRate']),
      lastStopDepth: _asDoubleOrNull(map['lastStopDepth']),
      extraLastStopSeconds: _asIntOrNull(map['extraLastStopSeconds']),
      gasSwitchStopSeconds: _asIntOrNull(map['gasSwitchStopSeconds']),
    ),
  };
}

Map<String, Object?> _tankRefToJson(TankRef ref) => switch (ref) {
  ExistingTankRef(:final tankId) => {'type': 'existing', 'tankId': tankId},
  HypotheticalTankRef(
    :final gasMix,
    :final volumeLiters,
    :final startPressureBar,
  ) =>
    {
      'type': 'hypothetical',
      'o2': gasMix.o2,
      'he': gasMix.he,
      'volumeLiters': volumeLiters,
      'startPressureBar': startPressureBar,
    },
};

TankRef _tankRefFromJson(Map<String, Object?> map) {
  final type = map['type'];
  if (type == 'existing') {
    return ExistingTankRef(_asString(map['tankId'], 'tankId'));
  }
  if (type == 'hypothetical') {
    return HypotheticalTankRef(
      gasMix: GasMix(
        o2: _asDouble(map['o2'], 'o2'),
        he: _asDouble(map['he'], 'he'),
      ),
      volumeLiters: _asDouble(map['volumeLiters'], 'volumeLiters'),
      startPressureBar: _asDouble(map['startPressureBar'], 'startPressureBar'),
    );
  }
  throw FormatException('unknown tank ref type: $type');
}

Map<String, Object?> _asMap(Object? v, String field) {
  if (v is Map<String, Object?>) return v;
  if (v is Map) return v.cast<String, Object?>();
  throw FormatException('$field must be an object');
}

String _asString(Object? v, String field) {
  if (v is String) return v;
  throw FormatException('$field must be a string');
}

int _asInt(Object? v, String field) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  throw FormatException('$field must be an integer');
}

int? _asIntOrNull(Object? v) => v == null ? null : _asInt(v, 'value');

double _asDouble(Object? v, String field) {
  if (v is num) return v.toDouble();
  throw FormatException('$field must be a number');
}

double? _asDoubleOrNull(Object? v) => v == null ? null : _asDouble(v, 'value');
```

- [ ] **Step 4: Run the test**

Run: `flutter test test/features/dive_lab/domain/entities/scenario_intervention_codec_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/dive_lab/domain/entities/scenario_intervention_codec.dart test/features/dive_lab/domain/entities/scenario_intervention_codec_test.dart
git commit -m "feat(dive-lab): versioned JSON codec for scenario interventions"
```

---

### Task 4: Tank schedule, gas segments, best-tank-by-depth, replay rewriter

**Files:**
- Create: `lib/features/dive_lab/domain/entities/scenario_request.dart` (only `ScenarioGasSwitch` and `TankPressureSample` for now; the full request lands in Task 5)
- Create: `lib/features/dive_lab/domain/services/tank_schedule.dart`
- Create: `lib/features/dive_lab/domain/services/replay_schedule_rewriter.dart`
- Test: `test/features/dive_lab/domain/services/tank_schedule_test.dart`
- Test: `test/features/dive_lab/domain/services/replay_schedule_rewriter_test.dart`

**Interfaces:**
- Produces: `class ScenarioGasSwitch extends Equatable { final int timestamp; final String tankId; }`; `class TankPressureSample extends Equatable { final int timestamp; final double pressureBar; }`; `class TankInterval extends Equatable { final int startTimestamp; final String? tankId; }`; `class TankSchedule` with `TankSchedule.fromDive({required List<DiveTank> tanks, required List<ScenarioGasSwitch> switches, int originTimestamp = 0})`, `List<TankInterval> intervals`, `List<DiveTank> tanks`, `String? tankIdAt(int t)`, `DiveTank? tankById(String? id)`, `DiveTank? tankAt(int t)`, `GasMix mixAt(int t)`, `List<ProfileGasSegment> toGasSegments()`, `TankSchedule switchedTo(String tankId, {required int fromTimestamp, DiveTank? addedTank})`, `TankSchedule withTanks(List<DiveTank>)`, `List<ScenarioGasSwitch> switchesAfter(int t)`; top-level `double fN2Of(GasMix mix)` (air -> `airN2Fraction`, else `(100 - o2 - he)/100`, mirroring `buildProfileGasSegments`), `DiveTank? bestTankForDepth(List<DiveTank> tanks, double depthMeters, {required double maxPpO2})` (eligible = `O2ToxicityCalculator.calculateMod(fO2, maxPpO2:) >= depth - 1e-9`; prefer higher O2 then higher He; fallback back gas then first; null when no tanks); `TankSchedule substituteTankByDepth(TankSchedule schedule, {required String lostTankId, required int fromTimestamp, required List<int> timestamps, required List<double> depths, required double maxPpO2, List<DiveTank>? candidates})`.
- `rewriteScheduleForReplay({required TankSchedule actual, required List<ScenarioIntervention> interventions, required int branchTimestamp, required List<int> timestamps, required List<double> depths, required double maxPpO2}) -> TankSchedule` applying, in order: `switchGas` (hypothetical tank appended), `loseTank` (tank removed, usage after T substituted by depth), `bailOut` (from T, only bailout-role tanks plus the hypothetical, substituted by depth).

- [ ] **Step 1: Write the failing tests**

```dart
// test/features/dive_lab/domain/services/tank_schedule_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/deco/constants/buhlmann_coefficients.dart';
import 'package:submersion/features/dive_lab/domain/entities/scenario_request.dart';
import 'package:submersion/features/dive_lab/domain/services/tank_schedule.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

const back = DiveTank(id: 'back', volume: 24, startPressure: 200, gasMix: GasMix(o2: 21), role: TankRole.backGas);
const deco50 = DiveTank(id: 'deco50', volume: 11.1, startPressure: 200, gasMix: GasMix(o2: 50), role: TankRole.deco);
const o2 = DiveTank(id: 'o2', volume: 7, startPressure: 200, gasMix: GasMix(o2: 100), role: TankRole.deco);

void main() {
  group('TankSchedule.fromDive', () {
    test('starts on the back gas and follows switches in time order', () {
      final s = TankSchedule.fromDive(
        tanks: const [deco50, back],
        switches: const [
          ScenarioGasSwitch(timestamp: 1800, tankId: 'deco50'),
          ScenarioGasSwitch(timestamp: 1500, tankId: 'back'), // no-op
        ],
      );
      expect(s.tankIdAt(0), 'back');
      expect(s.tankIdAt(1799), 'back');
      expect(s.tankIdAt(1800), 'deco50');
      expect(s.intervals, hasLength(2));
    });

    test('no tanks yields an air schedule', () {
      final s = TankSchedule.fromDive(tanks: const [], switches: const []);
      expect(s.tankIdAt(100), isNull);
      expect(s.mixAt(100).isAir, isTrue);
      expect(s.toGasSegments().single.fN2, airN2Fraction);
    });

    test('gas segments mirror the schedule', () {
      final s = TankSchedule.fromDive(
        tanks: const [back, deco50],
        switches: const [ScenarioGasSwitch(timestamp: 1800, tankId: 'deco50')],
      );
      final segs = s.toGasSegments();
      expect(segs[0].startTimestamp, 0);
      expect(segs[0].fN2, airN2Fraction);
      expect(segs[1].startTimestamp, 1800);
      expect(segs[1].fN2, closeTo(0.5, 1e-9));
    });

    test('switchedTo inserts an interval at T and keeps later switches', () {
      final s = TankSchedule.fromDive(
        tanks: const [back, deco50, o2],
        switches: const [
          ScenarioGasSwitch(timestamp: 1800, tankId: 'deco50'),
          ScenarioGasSwitch(timestamp: 2400, tankId: 'o2'),
        ],
      );
      final r = s.switchedTo('deco50', fromTimestamp: 1600);
      expect(r.tankIdAt(1599), 'back');
      expect(r.tankIdAt(1600), 'deco50');
      expect(r.tankIdAt(1800), 'deco50');
      expect(r.tankIdAt(2400), 'o2');
      // Consecutive identical intervals collapse.
      expect(r.intervals.map((i) => i.tankId), ['back', 'deco50', 'o2']);
    });
  });

  group('bestTankForDepth', () {
    test('prefers the richest eligible mix at the deco ppO2', () {
      expect(bestTankForDepth(const [back, deco50, o2], 21.0, maxPpO2: 1.6)?.id, 'deco50');
      expect(bestTankForDepth(const [back, deco50, o2], 6.0, maxPpO2: 1.6)?.id, 'o2');
      expect(bestTankForDepth(const [back, deco50, o2], 30.0, maxPpO2: 1.6)?.id, 'back');
    });

    test('falls back to back gas when nothing is eligible', () {
      expect(bestTankForDepth(const [deco50, back], 80.0, maxPpO2: 1.6)?.id, 'back');
      expect(bestTankForDepth(const [], 10.0, maxPpO2: 1.6), isNull);
    });
  });

  group('substituteTankByDepth', () {
    test('replaces the lost tank after T with the best remaining gas per depth', () {
      // 10 s samples: 21 m from 1800 to 2100, then 6 m from 2100 to 2400.
      final timestamps = <int>[];
      final depths = <double>[];
      for (var t = 0; t <= 2400; t += 10) {
        timestamps.add(t);
        depths.add(t < 1800 ? 40.0 : (t < 2100 ? 21.0 : 6.0));
      }
      final s = TankSchedule.fromDive(
        tanks: const [back, deco50, o2],
        switches: const [ScenarioGasSwitch(timestamp: 1800, tankId: 'deco50')],
      );
      final r = substituteTankByDepth(
        s,
        lostTankId: 'deco50',
        fromTimestamp: 1700,
        timestamps: timestamps,
        depths: depths,
        maxPpO2: 1.6,
      );
      expect(r.tanks.map((t) => t.id), isNot(contains('deco50')));
      expect(r.tankIdAt(1800), 'back'); // 21 m: O2 not eligible, 50% gone
      expect(r.tankIdAt(2100), 'o2'); // 6 m: O2 eligible
    });
  });
}
```

```dart
// test/features/dive_lab/domain/services/replay_schedule_rewriter_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_lab/domain/entities/scenario_intervention.dart';
import 'package:submersion/features/dive_lab/domain/entities/scenario_request.dart';
import 'package:submersion/features/dive_lab/domain/services/replay_schedule_rewriter.dart';
import 'package:submersion/features/dive_lab/domain/services/tank_schedule.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

const back = DiveTank(id: 'back', volume: 24, startPressure: 200, gasMix: GasMix(o2: 21), role: TankRole.backGas);
const deco50 = DiveTank(id: 'deco50', volume: 11.1, startPressure: 200, gasMix: GasMix(o2: 50), role: TankRole.deco);
const bailout = DiveTank(id: 'bo', volume: 11.1, startPressure: 200, gasMix: GasMix(o2: 32), role: TankRole.bailout);

List<int> _times() => [for (var t = 0; t <= 2400; t += 10) t];
List<double> _depths() => [for (var t = 0; t <= 2400; t += 10) t < 1800 ? 40.0 : 15.0];

void main() {
  test('switchGas to a hypothetical tank adds it and breathes it from T', () {
    final s = TankSchedule.fromDive(tanks: const [back], switches: const []);
    final r = rewriteScheduleForReplay(
      actual: s,
      interventions: const [
        SwitchGasIntervention(
          tank: HypotheticalTankRef(gasMix: GasMix(o2: 50), volumeLiters: 11.1, startPressureBar: 200),
        ),
      ],
      branchTimestamp: 1800,
      timestamps: _times(),
      depths: _depths(),
      maxPpO2: 1.6,
    );
    expect(r.tanks, hasLength(2));
    expect(r.tankIdAt(1799), 'back');
    expect(r.tankAt(1800)!.gasMix.o2, 50);
  });

  test('loseTank removes the tank and substitutes by depth after T', () {
    final s = TankSchedule.fromDive(
      tanks: const [back, deco50],
      switches: const [ScenarioGasSwitch(timestamp: 1800, tankId: 'deco50')],
    );
    final r = rewriteScheduleForReplay(
      actual: s,
      interventions: const [LoseTankIntervention(tankId: 'deco50')],
      branchTimestamp: 1000,
      timestamps: _times(),
      depths: _depths(),
      maxPpO2: 1.6,
    );
    expect(r.tanks.map((t) => t.id), ['back']);
    expect(r.tankIdAt(2000), 'back');
  });

  test('bailOut breathes only bailout tanks from T', () {
    final s = TankSchedule.fromDive(tanks: const [back, bailout], switches: const []);
    final r = rewriteScheduleForReplay(
      actual: s,
      interventions: const [BailOutIntervention()],
      branchTimestamp: 1800,
      timestamps: _times(),
      depths: _depths(),
      maxPpO2: 1.6,
    );
    expect(r.tankIdAt(1799), 'back');
    expect(r.tankIdAt(1800), 'bo');
    expect(r.tankIdAt(2400), 'bo');
  });

  test('no interventions returns the actual schedule unchanged', () {
    final s = TankSchedule.fromDive(tanks: const [back], switches: const []);
    expect(
      rewriteScheduleForReplay(
        actual: s,
        interventions: const [],
        branchTimestamp: 100,
        timestamps: _times(),
        depths: _depths(),
        maxPpO2: 1.6,
      ),
      same(s),
    );
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/dive_lab/domain/services/`
Expected: FAIL, files missing.

- [ ] **Step 3: Write `scenario_request.dart` (partial), `tank_schedule.dart`, `replay_schedule_rewriter.dart`**

`scenario_request.dart` (Task 5 appends `ScenarioRequest` to this same file):

```dart
import 'package:equatable/equatable.dart';

/// A recorded gas switch on the primary profile: from [timestamp] the diver
/// breathed [tankId].
class ScenarioGasSwitch extends Equatable {
  const ScenarioGasSwitch({required this.timestamp, required this.tankId});
  final int timestamp;
  final String tankId;
  @override
  List<Object?> get props => [timestamp, tankId];
}

/// One point of a tank's recorded pressure series.
class TankPressureSample extends Equatable {
  const TankPressureSample({required this.timestamp, required this.pressureBar});
  final int timestamp;
  final double pressureBar;
  @override
  List<Object?> get props => [timestamp, pressureBar];
}
```

`tank_schedule.dart`:

```dart
import 'package:equatable/equatable.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/deco/constants/buhlmann_coefficients.dart';
import 'package:submersion/core/deco/entities/profile_gas_segment.dart';
import 'package:submersion/core/deco/o2_toxicity_calculator.dart';
import 'package:submersion/features/dive_lab/domain/entities/scenario_request.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

/// Nitrogen fraction the deco engine breathes for [mix]: air is the exact
/// atmospheric fraction, everything else the remainder after O2 and He
/// (mirrors the dive detail page's buildProfileGasSegments).
double fN2Of(GasMix mix) =>
    mix.isAir ? airN2Fraction : (100.0 - mix.o2 - mix.he) / 100.0;

/// From [startTimestamp] the diver breathes [tankId] (null = no tank known,
/// treated as air).
class TankInterval extends Equatable {
  const TankInterval({required this.startTimestamp, required this.tankId});
  final int startTimestamp;
  final String? tankId;
  @override
  List<Object?> get props => [startTimestamp, tankId];
}

/// Which carried tank is breathed when, over a profile.
class TankSchedule extends Equatable {
  const TankSchedule({required this.intervals, required this.tanks});

  /// Ascending by [TankInterval.startTimestamp]; never empty.
  final List<TankInterval> intervals;
  final List<DiveTank> tanks;

  /// The dive's schedule: back gas (else the first tank) from [originTimestamp],
  /// then each recorded switch in time order. Switches to the tank already in
  /// force are dropped; two switches at one timestamp keep the later-sorted.
  factory TankSchedule.fromDive({
    required List<DiveTank> tanks,
    required List<ScenarioGasSwitch> switches,
    int originTimestamp = 0,
  }) {
    final primary = tanks.isEmpty
        ? null
        : tanks.firstWhere(
            (t) => t.role == TankRole.backGas,
            orElse: () => tanks.first,
          );
    final intervals = <TankInterval>[
      TankInterval(startTimestamp: originTimestamp, tankId: primary?.id),
    ];
    final sorted = List<ScenarioGasSwitch>.from(switches)
      ..sort((a, b) {
        final c = a.timestamp.compareTo(b.timestamp);
        return c != 0 ? c : a.tankId.compareTo(b.tankId);
      });
    for (final s in sorted) {
      if (s.timestamp < originTimestamp) continue;
      if (intervals.last.startTimestamp == s.timestamp) {
        intervals[intervals.length - 1] = TankInterval(
          startTimestamp: s.timestamp,
          tankId: s.tankId,
        );
        continue;
      }
      if (intervals.last.tankId == s.tankId) continue;
      intervals.add(TankInterval(startTimestamp: s.timestamp, tankId: s.tankId));
    }
    return TankSchedule(intervals: _collapse(intervals), tanks: tanks);
  }

  static List<TankInterval> _collapse(List<TankInterval> raw) {
    final out = <TankInterval>[];
    for (final i in raw) {
      if (out.isNotEmpty && out.last.tankId == i.tankId) continue;
      out.add(i);
    }
    return out;
  }

  String? tankIdAt(int timestamp) {
    var id = intervals.first.tankId;
    for (final i in intervals) {
      if (i.startTimestamp <= timestamp) {
        id = i.tankId;
      } else {
        break;
      }
    }
    return id;
  }

  DiveTank? tankById(String? id) {
    if (id == null) return null;
    for (final t in tanks) {
      if (t.id == id) return t;
    }
    return null;
  }

  DiveTank? tankAt(int timestamp) => tankById(tankIdAt(timestamp));

  GasMix mixAt(int timestamp) => tankAt(timestamp)?.gasMix ?? const GasMix();

  /// Open-circuit gas segments for ProfileAnalysisService / BuhlmannAlgorithm.
  List<ProfileGasSegment> toGasSegments() => [
    for (final i in intervals)
      () {
        final mix = tankById(i.tankId)?.gasMix ?? const GasMix();
        return ProfileGasSegment(
          startTimestamp: i.startTimestamp,
          fN2: fN2Of(mix),
          fHe: mix.he / 100.0,
        );
      }(),
  ];

  /// Recorded switches strictly after [timestamp].
  List<ScenarioGasSwitch> switchesAfter(int timestamp) => [
    for (final i in intervals)
      if (i.startTimestamp > timestamp && i.tankId != null)
        ScenarioGasSwitch(timestamp: i.startTimestamp, tankId: i.tankId!),
  ];

  TankSchedule withTanks(List<DiveTank> newTanks) =>
      TankSchedule(intervals: intervals, tanks: newTanks);

  /// Breathe [tankId] from [fromTimestamp] until the next recorded switch;
  /// intervals before stay, later switches stay. [addedTank] joins [tanks].
  TankSchedule switchedTo(
    String tankId, {
    required int fromTimestamp,
    DiveTank? addedTank,
  }) {
    final before = intervals.where((i) => i.startTimestamp < fromTimestamp);
    final after = intervals.where((i) => i.startTimestamp > fromTimestamp);
    final merged = <TankInterval>[
      ...before,
      TankInterval(startTimestamp: fromTimestamp, tankId: tankId),
      ...after,
    ];
    return TankSchedule(
      intervals: _collapse(merged),
      tanks: addedTank == null ? tanks : [...tanks, addedTank],
    );
  }

  @override
  List<Object?> get props => [intervals, tanks];
}

/// The richest carried mix breathable at [depthMeters] under [maxPpO2]
/// (MOD at the deco ppO2, the OptimalOcAscentGas rule), preferring higher
/// O2 then higher He. Falls back to the back gas, else the first tank, when
/// nothing is eligible; null when [tanks] is empty.
DiveTank? bestTankForDepth(
  List<DiveTank> tanks,
  double depthMeters, {
  required double maxPpO2,
}) {
  if (tanks.isEmpty) return null;
  DiveTank? best;
  for (final t in tanks) {
    final mod = O2ToxicityCalculator.calculateMod(
      t.gasMix.o2 / 100.0,
      maxPpO2: maxPpO2,
    );
    if (depthMeters > mod + 1e-9) continue;
    if (best == null ||
        t.gasMix.o2 > best.gasMix.o2 ||
        (t.gasMix.o2 == best.gasMix.o2 && t.gasMix.he > best.gasMix.he)) {
      best = t;
    }
  }
  if (best != null) return best;
  return tanks.firstWhere(
    (t) => t.role == TankRole.backGas,
    orElse: () => tanks.first,
  );
}

/// Every interval after [fromTimestamp] that breathed [lostTankId] (and the
/// part of the interval in force at [fromTimestamp]) is replaced by the best
/// remaining tank for the depth at each sample; the lost tank leaves
/// [TankSchedule.tanks]. [candidates] restricts the substitutes (bailout).
TankSchedule substituteTankByDepth(
  TankSchedule schedule, {
  required String lostTankId,
  required int fromTimestamp,
  required List<int> timestamps,
  required List<double> depths,
  required double maxPpO2,
  List<DiveTank>? candidates,
}) {
  final remaining = schedule.tanks.where((t) => t.id != lostTankId).toList();
  final pool = candidates ?? remaining;
  final out = <TankInterval>[];
  for (var k = 0; k < schedule.intervals.length; k++) {
    final interval = schedule.intervals[k];
    final end = k + 1 < schedule.intervals.length
        ? schedule.intervals[k + 1].startTimestamp
        : (timestamps.isEmpty ? interval.startTimestamp : timestamps.last + 1);
    if (end <= fromTimestamp || interval.tankId != lostTankId) {
      out.add(interval);
      continue;
    }
    final start = interval.startTimestamp < fromTimestamp
        ? fromTimestamp
        : interval.startTimestamp;
    if (interval.startTimestamp < fromTimestamp) {
      out.add(interval); // the part before T stays on the lost tank
    }
    String? current;
    for (var i = 0; i < timestamps.length; i++) {
      final t = timestamps[i];
      if (t < start || t >= end) continue;
      final id = bestTankForDepth(pool, depths[i], maxPpO2: maxPpO2)?.id;
      if (id != current) {
        out.add(TankInterval(startTimestamp: t, tankId: id));
        current = id;
      }
    }
    if (current == null) {
      // No sample fell inside the interval: pick by the depth nearest start.
      final idx = _nearestIndex(timestamps, start);
      final id = idx == null
          ? null
          : bestTankForDepth(pool, depths[idx], maxPpO2: maxPpO2)?.id;
      out.add(TankInterval(startTimestamp: start, tankId: id));
    }
  }
  return TankSchedule(intervals: TankSchedule._collapse(out), tanks: remaining);
}

int? _nearestIndex(List<int> timestamps, int t) {
  if (timestamps.isEmpty) return null;
  var best = 0;
  for (var i = 1; i < timestamps.length; i++) {
    if ((timestamps[i] - t).abs() < (timestamps[best] - t).abs()) best = i;
  }
  return best;
}
```

`replay_schedule_rewriter.dart`:

```dart
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_lab/domain/entities/scenario_intervention.dart';
import 'package:submersion/features/dive_lab/domain/services/tank_schedule.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

/// A hypothetical cylinder as a carried tank (deco role so the optimal
/// ascent treats it as a deco gas).
DiveTank hypotheticalTank(HypotheticalTankRef ref) => DiveTank(
  id: ref.tankId,
  name: ref.gasMix.name,
  volume: ref.volumeLiters,
  startPressure: ref.startPressureBar,
  gasMix: ref.gasMix,
  role: TankRole.deco,
);

/// The breathing schedule the replay timeline follows: the actual schedule
/// with the interventions applied from [branchTimestamp]. Returns [actual]
/// itself when nothing changes.
TankSchedule rewriteScheduleForReplay({
  required TankSchedule actual,
  required List<ScenarioIntervention> interventions,
  required int branchTimestamp,
  required List<int> timestamps,
  required List<double> depths,
  required double maxPpO2,
}) {
  var schedule = actual;
  for (final i in interventions) {
    if (i is SwitchGasIntervention) {
      final ref = i.tank;
      schedule = switch (ref) {
        ExistingTankRef(:final tankId) => schedule.switchedTo(
          tankId,
          fromTimestamp: branchTimestamp,
        ),
        HypotheticalTankRef() => schedule.switchedTo(
          ref.tankId,
          fromTimestamp: branchTimestamp,
          addedTank: hypotheticalTank(ref),
        ),
      };
    }
  }
  for (final i in interventions) {
    if (i is LoseTankIntervention) {
      schedule = substituteTankByDepth(
        schedule,
        lostTankId: i.tankId,
        fromTimestamp: branchTimestamp,
        timestamps: timestamps,
        depths: depths,
        maxPpO2: maxPpO2,
      );
    }
  }
  for (final i in interventions) {
    if (i is BailOutIntervention) {
      final ref = i.tank;
      final pool = <DiveTank>[
        if (ref is ExistingTankRef)
          ...schedule.tanks.where((t) => t.id == ref.tankId)
        else if (ref is HypotheticalTankRef)
          hypotheticalTank(ref)
        else
          ...schedule.tanks.where((t) => t.role == TankRole.bailout),
      ];
      if (pool.isEmpty) continue;
      final tanks = [
        ...schedule.tanks,
        for (final t in pool)
          if (!schedule.tanks.any((x) => x.id == t.id)) t,
      ];
      final current = schedule.tankIdAt(branchTimestamp);
      // Re-route everything from T: mark the in-force tank as "lost" from T
      // so the substitution walks the remainder on the bailout pool.
      final marker = current ?? '__none__';
      final routed = substituteTankByDepth(
        schedule.withTanks(tanks),
        lostTankId: marker,
        fromTimestamp: branchTimestamp,
        timestamps: timestamps,
        depths: depths,
        maxPpO2: maxPpO2,
        candidates: pool,
      );
      // substituteTankByDepth only rewrites intervals on the marker tank;
      // later actual switches (other tanks) must also be overridden.
      final before = routed.intervals.where(
        (iv) => iv.startTimestamp < branchTimestamp,
      );
      final after = routed.intervals.where(
        (iv) => iv.startTimestamp >= branchTimestamp,
      );
      var last = <TankInterval>[];
      for (final iv in after) {
        final t = routed.tankById(iv.tankId);
        final onPool = t != null && pool.any((p) => p.id == t.id);
        last.add(
          onPool
              ? iv
              : TankInterval(
                  startTimestamp: iv.startTimestamp,
                  tankId: bestTankForDepth(
                    pool,
                    depths[_indexAtOrAfter(timestamps, iv.startTimestamp)],
                    maxPpO2: maxPpO2,
                  )?.id,
                ),
        );
      }
      if (last.isEmpty || last.first.startTimestamp != branchTimestamp) {
        last = [
          TankInterval(
            startTimestamp: branchTimestamp,
            tankId: bestTankForDepth(
              pool,
              depths[_indexAtOrAfter(timestamps, branchTimestamp)],
              maxPpO2: maxPpO2,
            )?.id,
          ),
          ...last,
        ];
      }
      schedule = TankSchedule(
        intervals: [...before, ...last],
        tanks: tanks,
      );
    }
  }
  return schedule;
}

int _indexAtOrAfter(List<int> timestamps, int t) {
  for (var i = 0; i < timestamps.length; i++) {
    if (timestamps[i] >= t) return i;
  }
  return timestamps.length - 1;
}
```

- [ ] **Step 4: Run the tests**

Run: `flutter test test/features/dive_lab/domain/services/`
Expected: PASS. (If `TankSchedule._collapse` is unreachable from `substituteTankByDepth` because of library privacy, it is in the same file, so it is reachable.)

- [ ] **Step 5: Commit**

```bash
git add lib/features/dive_lab/domain/entities/scenario_request.dart lib/features/dive_lab/domain/services/tank_schedule.dart lib/features/dive_lab/domain/services/replay_schedule_rewriter.dart test/features/dive_lab/domain/services/tank_schedule_test.dart test/features/dive_lab/domain/services/replay_schedule_rewriter_test.dart
git commit -m "feat(dive-lab): tank schedule, best gas by depth and replay rewriter"
```

---

### Task 5: Settings, request, branch state (pressure + SAC at T)

**Files:**
- Create: `lib/features/dive_lab/domain/entities/scenario_settings.dart`
- Modify: `lib/features/dive_lab/domain/entities/scenario_request.dart` (append `ScenarioRequest`)
- Create: `lib/features/dive_lab/domain/entities/branch_state.dart`
- Create: `lib/features/dive_lab/domain/services/sac_resolver.dart`
- Create: `lib/features/dive_lab/domain/services/branch_state_builder.dart`
- Create: `test/features/dive_lab/domain/support/synthetic_dives.dart`
- Test: `test/features/dive_lab/domain/services/branch_state_builder_test.dart`

**Interfaces:**
- Produces `ScenarioSettings` (const ctor, all defaults: `gfLow 0.30, gfHigh 0.70, ppO2Working 1.4, ppO2Deco 1.6, cnsWarningThreshold 80, ascentRateWarning 9, ascentRateCritical 12, lastStopDepth 3, stopIncrement 3, ascentRate 9, descentRate 18, gasSwitchStopSeconds 0, airBreaks null, altitudeMeters null, waterType null, cnsMethod shearwater, gasModel real, o2Narcotic true, defaultSacLpm 15, buddyFactor 2.0, reservePressureBar 50`), `environment` getter (forConditions with the "altitude <= 0 is unset" rule), `gfLowPercent/gfHighPercent`, `withGf({required int low, required int high})`, `engineConfig` (`PlanEngineConfig`), `buildAnalysisService()` (`ProfileAnalysisService`), `copyWith`.
- Produces `ScenarioRequest({diveId, depths, timestamps, diveMode = oc, tanks = const [], gasSwitches = const [], tankPressures = const {}, loopGasSegments, rebreatherPpO2Curve, setpointHigh, setpointLow, startCompartments, startCns = 0, startOtu = 0, fallbackSacLpm, settings = const ScenarioSettings(), scenario})`.
- Produces `enum PressureSource { measured, estimated, unknown }`, `enum SacSource { measured, diveAverage, logAverage, defaultValue }`, `TankPressureAtBranch(tankId, pressureBar, source)`, `BranchState(index, runtimeSeconds, depthMeters, compartments, gfLowCeilingAnchor, cnsPercent, otu, activeTankId, tankPressures, sacLitersPerMin, sacSource)` with `BuhlmannState get tissueState`, `double? pressureFor(String)`, `PressureSource pressureSourceFor(String)`.
- Produces `double? pressureAtTimestamp(List<TankPressureSample> series, int t)` (linear, clamped to the ends), `class ResolvedSac {litersPerMin, source}`, `ResolvedSac resolveBranchSac({...})`, `int branchIndexFor(List<int> timestamps, int branchSeconds)` (nearest sample, earlier on ties, clamped), `BranchState buildBranchState({required ScenarioRequest request, required ProfileAnalysis actual, required TankSchedule schedule, required int branchIndex})`.
- Test support: `SyntheticDive squareDive({double depth = 40, int bottomMinutes = 25, bool withDeco50 = true, bool withPressures = true, double sacLpm = 20})` with fields `depths, timestamps, tanks, switches, tankPressures, bottomEndIndex, switchIndex` and a 10 s sample step: descent at 20 m/min, bottom, ascent at 9 m/min with a switch to 50% at 21 m (when present) and a 3 min stop at 5 m, then surface. Pressure series under the ideal gas law at `sacLpm` so the resolver's measured SAC is exactly `sacLpm`.

- [ ] **Step 1: Write the test support and the failing test**

```dart
// test/features/dive_lab/domain/support/synthetic_dives.dart
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_lab/domain/entities/scenario_request.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

class SyntheticDive {
  SyntheticDive({
    required this.depths,
    required this.timestamps,
    required this.tanks,
    required this.switches,
    required this.tankPressures,
    required this.bottomEndIndex,
    required this.switchIndex,
  });

  final List<double> depths;
  final List<int> timestamps;
  final List<DiveTank> tanks;
  final List<ScenarioGasSwitch> switches;
  final Map<String, List<TankPressureSample>> tankPressures;

  /// Last sample of the bottom phase.
  final int bottomEndIndex;

  /// Sample at which the 50% switch happened (-1 when no deco tank).
  final int switchIndex;

  int indexAt(int seconds) => timestamps.indexOf(seconds);
}

/// Square open-circuit dive at 10 s samples: descend at 20 m/min, hold
/// [bottomMinutes] at [depth], ascend at 9 m/min, switch to 50% at 21 m when
/// [withDeco50], 3 min stop at 5 m, surface. Pressure series follow the ideal
/// gas law at [sacLpm] so a resolver that reads drop x volume / ambient /
/// minutes recovers [sacLpm] exactly.
SyntheticDive squareDive({
  double depth = 40,
  int bottomMinutes = 25,
  bool withDeco50 = true,
  bool withPressures = true,
  double sacLpm = 20,
}) {
  const step = 10;
  final depths = <double>[];
  final timestamps = <int>[];
  var t = 0;
  void add(double d) {
    depths.add(d);
    timestamps.add(t);
    t += step;
  }

  final descentSamples = (depth / 20.0 * 60 / step).round();
  for (var i = 0; i <= descentSamples; i++) {
    add(depth * i / descentSamples);
  }
  for (var i = 0; i < bottomMinutes * 60 ~/ step; i++) {
    add(depth);
  }
  final bottomEndIndex = depths.length - 1;
  var switchIndex = -1;
  var d = depth;
  while (d > 5.0 + 1e-9) {
    d = (d - 9.0 * step / 60).clamp(5.0, depth);
    add(double.parse(d.toStringAsFixed(3)));
    if (withDeco50 && switchIndex < 0 && d <= 21.0) {
      switchIndex = depths.length - 1;
    }
  }
  for (var i = 0; i < 18; i++) {
    add(5.0);
  }
  add(2.5);
  add(0.0);

  const back = DiveTank(
    id: 'back',
    volume: 24,
    startPressure: 200,
    endPressure: 80,
    gasMix: GasMix(o2: 21),
    role: TankRole.backGas,
  );
  const deco = DiveTank(
    id: 'deco50',
    volume: 11.1,
    startPressure: 200,
    endPressure: 150,
    gasMix: GasMix(o2: 50),
    role: TankRole.deco,
  );
  final tanks = [back, if (withDeco50) deco];
  final switches = [
    if (withDeco50 && switchIndex >= 0)
      ScenarioGasSwitch(timestamp: timestamps[switchIndex], tankId: 'deco50'),
  ];

  final pressures = <String, List<TankPressureSample>>{};
  if (withPressures) {
    var backBar = 200.0;
    var decoBar = 200.0;
    final backSeries = <TankPressureSample>[
      const TankPressureSample(timestamp: 0, pressureBar: 200),
    ];
    final decoSeries = <TankPressureSample>[];
    for (var i = 1; i < depths.length; i++) {
      final dt = timestamps[i] - timestamps[i - 1];
      final ambient = 1.0 + (depths[i] + depths[i - 1]) / 2 / 10.0;
      final liters = sacLpm * ambient * dt / 60.0;
      final onDeco = switchIndex >= 0 && i > switchIndex;
      if (onDeco) {
        decoBar -= liters / 11.1;
        decoSeries.add(
          TankPressureSample(timestamp: timestamps[i], pressureBar: decoBar),
        );
      } else {
        backBar -= liters / 24.0;
        backSeries.add(
          TankPressureSample(timestamp: timestamps[i], pressureBar: backBar),
        );
      }
    }
    pressures['back'] = backSeries;
    if (withDeco50) pressures['deco50'] = decoSeries;
  }

  return SyntheticDive(
    depths: depths,
    timestamps: timestamps,
    tanks: tanks,
    switches: switches,
    tankPressures: pressures,
    bottomEndIndex: bottomEndIndex,
    switchIndex: switchIndex,
  );
}

/// Multi-level variant: [depth] for [deepMinutes], then [shallowDepth] for
/// [shallowMinutes], then the same ascent as [squareDive]. No deco tank.
SyntheticDive multiLevelDive({
  double depth = 40,
  int deepMinutes = 15,
  double shallowDepth = 20,
  int shallowMinutes = 15,
}) {
  const step = 10;
  final depths = <double>[];
  final timestamps = <int>[];
  var t = 0;
  void add(double d) {
    depths.add(d);
    timestamps.add(t);
    t += step;
  }

  final descentSamples = (depth / 20.0 * 60 / step).round();
  for (var i = 0; i <= descentSamples; i++) {
    add(depth * i / descentSamples);
  }
  for (var i = 0; i < deepMinutes * 60 ~/ step; i++) {
    add(depth);
  }
  var d = depth;
  while (d > shallowDepth + 1e-9) {
    d = (d - 9.0 * step / 60).clamp(shallowDepth, depth);
    add(double.parse(d.toStringAsFixed(3)));
  }
  for (var i = 0; i < shallowMinutes * 60 ~/ step; i++) {
    add(shallowDepth);
  }
  final bottomEndIndex = depths.length - 1;
  while (d > 5.0 + 1e-9) {
    d = (d - 9.0 * step / 60).clamp(5.0, depth);
    add(double.parse(d.toStringAsFixed(3)));
  }
  for (var i = 0; i < 18; i++) {
    add(5.0);
  }
  add(2.5);
  add(0.0);
  return SyntheticDive(
    depths: depths,
    timestamps: timestamps,
    tanks: const [
      DiveTank(
        id: 'back',
        volume: 24,
        startPressure: 200,
        endPressure: 80,
        gasMix: GasMix(o2: 21),
        role: TankRole.backGas,
      ),
    ],
    switches: const [],
    tankPressures: const {},
    bottomEndIndex: bottomEndIndex,
    switchIndex: -1,
  );
}
```

```dart
// test/features/dive_lab/domain/services/branch_state_builder_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_lab/domain/entities/branch_state.dart';
import 'package:submersion/features/dive_lab/domain/entities/dive_scenario.dart';
import 'package:submersion/features/dive_lab/domain/entities/scenario_mode.dart';
import 'package:submersion/features/dive_lab/domain/entities/scenario_request.dart';
import 'package:submersion/features/dive_lab/domain/entities/scenario_settings.dart';
import 'package:submersion/features/dive_lab/domain/services/branch_state_builder.dart';
import 'package:submersion/features/dive_lab/domain/services/tank_schedule.dart';
import 'package:submersion/features/dive_log/data/services/profile_analysis_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

import '../support/synthetic_dives.dart';

DiveScenario _scenario(int branchSeconds) => DiveScenario(
  id: 's',
  diveId: 'd',
  name: 'n',
  branchSeconds: branchSeconds,
  mode: ScenarioMode.replay,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

ScenarioRequest _request(
  SyntheticDive dive, {
  int branchSeconds = 900,
  Map<String, List<TankPressureSample>>? pressures,
  List<DiveTank>? tanks,
  double? fallbackSacLpm,
}) => ScenarioRequest(
  diveId: 'd',
  depths: dive.depths,
  timestamps: dive.timestamps,
  diveMode: DiveMode.oc,
  tanks: tanks ?? dive.tanks,
  gasSwitches: dive.switches,
  tankPressures: pressures ?? dive.tankPressures,
  fallbackSacLpm: fallbackSacLpm,
  scenario: _scenario(branchSeconds),
);

ProfileAnalysis _analyze(ScenarioRequest r) {
  final schedule = TankSchedule.fromDive(tanks: r.tanks, switches: r.gasSwitches);
  return r.settings.buildAnalysisService().analyze(
    diveId: r.diveId,
    depths: r.depths,
    timestamps: r.timestamps,
    gasSegments: schedule.toGasSegments(),
  );
}

void main() {
  group('branchIndexFor', () {
    test('nearest sample, earlier on ties, clamped', () {
      const ts = [0, 10, 20, 30];
      expect(branchIndexFor(ts, 0), 0);
      expect(branchIndexFor(ts, 14), 1);
      expect(branchIndexFor(ts, 15), 1);
      expect(branchIndexFor(ts, 16), 2);
      expect(branchIndexFor(ts, 99), 3);
      expect(branchIndexFor(ts, -5), 0);
    });
  });

  group('buildBranchState', () {
    test('reads tissues, anchor, CNS, OTU, active tank at the branch', () {
      final dive = squareDive();
      final r = _request(dive, branchSeconds: 900);
      final actual = _analyze(r);
      final schedule = TankSchedule.fromDive(tanks: r.tanks, switches: r.gasSwitches);
      final i = branchIndexFor(r.timestamps, 900);
      final b = buildBranchState(request: r, actual: actual, schedule: schedule, branchIndex: i);
      expect(b.index, i);
      expect(b.runtimeSeconds, 900);
      expect(b.depthMeters, 40.0);
      expect(b.compartments, actual.decoStatuses[i].compartments);
      expect(b.gfLowCeilingAnchor, actual.decoStatuses[i].gfLowCeilingAnchor);
      expect(b.cnsPercent, actual.cnsCurve![i]);
      expect(b.otu, actual.otuCurve![i]);
      expect(b.activeTankId, 'back');
      expect(b.tissueState.gfLowCeilingAnchor, b.gfLowCeilingAnchor);
    });

    test('measured pressure and SAC from the active tank series', () {
      final dive = squareDive(sacLpm: 20);
      final r = _request(dive, branchSeconds: 900);
      final actual = _analyze(r);
      final schedule = TankSchedule.fromDive(tanks: r.tanks, switches: r.gasSwitches);
      final b = buildBranchState(
        request: r, actual: actual, schedule: schedule, branchIndex: branchIndexFor(r.timestamps, 900),
      );
      expect(b.pressureSourceFor('back'), PressureSource.measured);
      // Generator: 200 bar minus 20 L/min x 5 bar(40 m) x 15 min / 24 L minus
      // the descent (2 min at mean 3 bar): 200 - (1500 + 120) / 24 = 132.5.
      expect(b.pressureFor('back'), closeTo(132.5, 0.2));
      expect(b.sacSource, SacSource.measured);
      expect(b.sacLitersPerMin, closeTo(20.0, 0.05));
      // Deco tank untouched so far: its series starts after the switch.
      expect(b.pressureSourceFor('deco50'), PressureSource.measured);
      expect(b.pressureFor('deco50'), closeTo(200.0, 1e-9));
    });

    test('no series: estimated linear pressure and dive-average SAC', () {
      final dive = squareDive(withPressures: false);
      final r = _request(dive, branchSeconds: 900);
      final actual = _analyze(r);
      final schedule = TankSchedule.fromDive(tanks: r.tanks, switches: r.gasSwitches);
      final b = buildBranchState(
        request: r, actual: actual, schedule: schedule, branchIndex: branchIndexFor(r.timestamps, 900),
      );
      expect(b.pressureSourceFor('back'), PressureSource.estimated);
      final p = b.pressureFor('back')!;
      expect(p, lessThan(200));
      expect(p, greaterThan(80));
      expect(b.sacSource, SacSource.diveAverage);
      expect(b.sacLitersPerMin, greaterThan(0));
    });

    test('no pressures at all: unknown pressure, log-average then default SAC', () {
      final dive = squareDive(withPressures: false);
      const bare = DiveTank(id: 'back', volume: 24, gasMix: GasMix(o2: 21), role: TankRole.backGas);
      final r1 = _request(dive, tanks: const [bare], fallbackSacLpm: 17.5);
      final a1 = _analyze(r1);
      final s1 = TankSchedule.fromDive(tanks: r1.tanks, switches: const []);
      final b1 = buildBranchState(request: r1, actual: a1, schedule: s1, branchIndex: 30);
      expect(b1.pressureSourceFor('back'), PressureSource.unknown);
      expect(b1.pressureFor('back'), isNull);
      expect(b1.sacSource, SacSource.logAverage);
      expect(b1.sacLitersPerMin, 17.5);

      final r2 = _request(dive, tanks: const [bare]);
      final b2 = buildBranchState(request: r2, actual: _analyze(r2), schedule: s1, branchIndex: 30);
      expect(b2.sacSource, SacSource.defaultValue);
      expect(b2.sacLitersPerMin, const ScenarioSettings().defaultSacLpm);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/dive_lab/domain/services/branch_state_builder_test.dart`
Expected: FAIL, imports missing.

- [ ] **Step 3: Write settings, request, branch state, resolver, builder**

`scenario_settings.dart`:

```dart
import 'package:equatable/equatable.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/gas_model.dart';
import 'package:submersion/core/deco/entities/cns_calculation_method.dart';
import 'package:submersion/core/deco/entities/dive_environment.dart';
import 'package:submersion/core/deco/schedule_policy.dart';
import 'package:submersion/features/dive_log/data/services/profile_analysis_service.dart';
import 'package:submersion/features/planner/domain/services/plan_engine.dart';

/// Everything the engine needs from diver settings and the dive, resolved by
/// the provider layer exactly as profile_analysis_provider does (per-dive GF
/// only when both values are present, else the diver settings).
class ScenarioSettings extends Equatable {
  const ScenarioSettings({
    this.gfLow = 0.30,
    this.gfHigh = 0.70,
    this.ppO2Working = 1.4,
    this.ppO2Deco = 1.6,
    this.cnsWarningThreshold = 80,
    this.ascentRateWarning = 9.0,
    this.ascentRateCritical = 12.0,
    this.lastStopDepth = 3.0,
    this.stopIncrement = 3.0,
    this.ascentRate = 9.0,
    this.descentRate = 18.0,
    this.gasSwitchStopSeconds = 0,
    this.airBreaks,
    this.altitudeMeters,
    this.waterType,
    this.cnsMethod = CnsCalculationMethod.shearwater,
    this.gasModel = GasModel.real,
    this.o2Narcotic = true,
    this.defaultSacLpm = 15.0,
    this.buddyFactor = 2.0,
    this.reservePressureBar = 50.0,
  });

  /// Fractions (0-1).
  final double gfLow;
  final double gfHigh;
  final double ppO2Working;
  final double ppO2Deco;
  final int cnsWarningThreshold;
  final double ascentRateWarning;
  final double ascentRateCritical;
  final double lastStopDepth;
  final double stopIncrement;
  final double ascentRate;
  final double descentRate;
  final int gasSwitchStopSeconds;
  final AirBreakPolicy? airBreaks;
  final double? altitudeMeters;
  final WaterType? waterType;
  final CnsCalculationMethod cnsMethod;
  final GasModel gasModel;
  final bool o2Narcotic;

  /// Last-resort SAC (L/min) when the dive offers no measurement.
  final double defaultSacLpm;
  final double buddyFactor;
  final double reservePressureBar;

  /// Altitude <= 0 is unset (legacy 1.0 bar), matching PlanEngine.
  DiveEnvironment get environment => DiveEnvironment.forConditions(
    altitudeMeters: (altitudeMeters ?? 0) > 0 ? altitudeMeters : null,
    waterType: waterType,
  );

  int get gfLowPercent => (gfLow * 100).round();
  int get gfHighPercent => (gfHigh * 100).round();

  ScenarioSettings withGf({required int low, required int high}) =>
      copyWith(gfLow: low / 100.0, gfHigh: high / 100.0);

  PlanEngineConfig get engineConfig => PlanEngineConfig(
    ppO2Working: ppO2Working,
    ppO2Deco: ppO2Deco,
    cnsWarningThreshold: cnsWarningThreshold,
    o2Narcotic: o2Narcotic,
    buddyFactor: buddyFactor,
    cnsMethod: cnsMethod,
    gasModel: gasModel,
  );

  ProfileAnalysisService buildAnalysisService() => ProfileAnalysisService(
    ascentRateWarning: ascentRateWarning,
    ascentRateCritical: ascentRateCritical,
    ppO2WarningThreshold: ppO2Working,
    ppO2CriticalThreshold: ppO2Deco,
    cnsWarningThreshold: cnsWarningThreshold,
    gfLow: gfLow,
    gfHigh: gfHigh,
    lastStopDepth: lastStopDepth,
    decoStopIncrement: stopIncrement,
    environment: environment,
    cnsCalculationMethod: cnsMethod,
  );

  ScenarioSettings copyWith({
    double? gfLow,
    double? gfHigh,
    double? ppO2Working,
    double? ppO2Deco,
    int? cnsWarningThreshold,
    double? ascentRateWarning,
    double? ascentRateCritical,
    double? lastStopDepth,
    double? stopIncrement,
    double? ascentRate,
    double? descentRate,
    int? gasSwitchStopSeconds,
    AirBreakPolicy? airBreaks,
    double? altitudeMeters,
    WaterType? waterType,
    CnsCalculationMethod? cnsMethod,
    GasModel? gasModel,
    bool? o2Narcotic,
    double? defaultSacLpm,
    double? buddyFactor,
    double? reservePressureBar,
  }) {
    return ScenarioSettings(
      gfLow: gfLow ?? this.gfLow,
      gfHigh: gfHigh ?? this.gfHigh,
      ppO2Working: ppO2Working ?? this.ppO2Working,
      ppO2Deco: ppO2Deco ?? this.ppO2Deco,
      cnsWarningThreshold: cnsWarningThreshold ?? this.cnsWarningThreshold,
      ascentRateWarning: ascentRateWarning ?? this.ascentRateWarning,
      ascentRateCritical: ascentRateCritical ?? this.ascentRateCritical,
      lastStopDepth: lastStopDepth ?? this.lastStopDepth,
      stopIncrement: stopIncrement ?? this.stopIncrement,
      ascentRate: ascentRate ?? this.ascentRate,
      descentRate: descentRate ?? this.descentRate,
      gasSwitchStopSeconds: gasSwitchStopSeconds ?? this.gasSwitchStopSeconds,
      airBreaks: airBreaks ?? this.airBreaks,
      altitudeMeters: altitudeMeters ?? this.altitudeMeters,
      waterType: waterType ?? this.waterType,
      cnsMethod: cnsMethod ?? this.cnsMethod,
      gasModel: gasModel ?? this.gasModel,
      o2Narcotic: o2Narcotic ?? this.o2Narcotic,
      defaultSacLpm: defaultSacLpm ?? this.defaultSacLpm,
      buddyFactor: buddyFactor ?? this.buddyFactor,
      reservePressureBar: reservePressureBar ?? this.reservePressureBar,
    );
  }

  @override
  List<Object?> get props => [
    gfLow, gfHigh, ppO2Working, ppO2Deco, cnsWarningThreshold,
    ascentRateWarning, ascentRateCritical, lastStopDepth, stopIncrement,
    ascentRate, descentRate, gasSwitchStopSeconds, airBreaks, altitudeMeters,
    waterType, cnsMethod, gasModel, o2Narcotic, defaultSacLpm, buddyFactor,
    reservePressureBar,
  ];
}
```

Append to `scenario_request.dart` (add the imports it needs: `enums.dart`, `profile_gas_segment.dart`, `tissue_compartment.dart`, `dive.dart`, `dive_scenario.dart`, `scenario_settings.dart`):

```dart
/// Everything the engine needs, isolate-safe, assembled by the provider layer.
class ScenarioRequest extends Equatable {
  const ScenarioRequest({
    required this.diveId,
    required this.depths,
    required this.timestamps,
    this.diveMode = DiveMode.oc,
    this.tanks = const [],
    this.gasSwitches = const [],
    this.tankPressures = const {},
    this.loopGasSegments,
    this.rebreatherPpO2Curve,
    this.setpointHigh,
    this.setpointLow,
    this.startCompartments,
    this.startCns = 0.0,
    this.startOtu = 0.0,
    this.fallbackSacLpm,
    this.settings = const ScenarioSettings(),
    required this.scenario,
  });

  final String diveId;
  final List<double> depths;
  final List<int> timestamps;
  final DiveMode diveMode;
  final List<DiveTank> tanks;
  final List<ScenarioGasSwitch> gasSwitches;
  final Map<String, List<TankPressureSample>> tankPressures;

  /// CCR/SCR: diluent + setpoint segments built by the provider (the engine
  /// does not derive loop gas itself in Phase 1).
  final List<ProfileGasSegment>? loopGasSegments;
  final List<double>? rebreatherPpO2Curve;
  final double? setpointHigh;
  final double? setpointLow;

  /// Repetitive-dive seeds, mirroring the dive detail page.
  final List<TissueCompartment>? startCompartments;
  final double startCns;
  final double startOtu;

  /// The diver's logged average SAC (L/min), used when the dive has none.
  final double? fallbackSacLpm;
  final ScenarioSettings settings;
  final DiveScenario scenario;

  int get sampleCount => depths.length;

  @override
  List<Object?> get props => [
    diveId, depths, timestamps, diveMode, tanks, gasSwitches, tankPressures,
    loopGasSegments, rebreatherPpO2Curve, setpointHigh, setpointLow,
    startCompartments, startCns, startOtu, fallbackSacLpm, settings, scenario,
  ];
}
```

`branch_state.dart`:

```dart
import 'package:equatable/equatable.dart';

import 'package:submersion/core/deco/deco_model.dart';
import 'package:submersion/core/deco/entities/tissue_compartment.dart';

enum PressureSource { measured, estimated, unknown }

enum SacSource { measured, diveAverage, logAverage, defaultValue }

class TankPressureAtBranch extends Equatable {
  const TankPressureAtBranch({
    required this.tankId,
    required this.pressureBar,
    required this.source,
  });
  final String tankId;
  final double? pressureBar;
  final PressureSource source;
  @override
  List<Object?> get props => [tankId, pressureBar, source];
}

/// The complete state of the dive at the branch point.
class BranchState extends Equatable {
  const BranchState({
    required this.index,
    required this.runtimeSeconds,
    required this.depthMeters,
    required this.compartments,
    required this.gfLowCeilingAnchor,
    required this.cnsPercent,
    required this.otu,
    required this.activeTankId,
    required this.tankPressures,
    required this.sacLitersPerMin,
    required this.sacSource,
  });

  final int index;
  final int runtimeSeconds;
  final double depthMeters;
  final List<TissueCompartment> compartments;
  final double gfLowCeilingAnchor;
  final double cnsPercent;
  final double otu;
  final String? activeTankId;
  final List<TankPressureAtBranch> tankPressures;
  final double sacLitersPerMin;
  final SacSource sacSource;

  BuhlmannState get tissueState => BuhlmannState(
    compartments: compartments,
    gfLowCeilingAnchor: gfLowCeilingAnchor,
  );

  TankPressureAtBranch? _entry(String tankId) {
    for (final p in tankPressures) {
      if (p.tankId == tankId) return p;
    }
    return null;
  }

  double? pressureFor(String tankId) => _entry(tankId)?.pressureBar;

  PressureSource pressureSourceFor(String tankId) =>
      _entry(tankId)?.source ?? PressureSource.unknown;

  @override
  List<Object?> get props => [
    index, runtimeSeconds, depthMeters, compartments, gfLowCeilingAnchor,
    cnsPercent, otu, activeTankId, tankPressures, sacLitersPerMin, sacSource,
  ];
}
```

`sac_resolver.dart`:

```dart
import 'package:submersion/core/deco/entities/dive_environment.dart';
import 'package:submersion/features/dive_lab/domain/entities/branch_state.dart';
import 'package:submersion/features/dive_lab/domain/entities/scenario_request.dart';
import 'package:submersion/features/dive_lab/domain/services/tank_schedule.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

/// Pressure of [series] at [timestamp]: linear between neighbours, clamped
/// to the first/last point; null for an empty series.
double? pressureAtTimestamp(List<TankPressureSample> series, int timestamp) {
  if (series.isEmpty) return null;
  if (timestamp <= series.first.timestamp) return series.first.pressureBar;
  if (timestamp >= series.last.timestamp) return series.last.pressureBar;
  for (var i = 1; i < series.length; i++) {
    final a = series[i - 1];
    final b = series[i];
    if (timestamp <= b.timestamp) {
      final span = b.timestamp - a.timestamp;
      if (span <= 0) return b.pressureBar;
      final f = (timestamp - a.timestamp) / span;
      return a.pressureBar + (b.pressureBar - a.pressureBar) * f;
    }
  }
  return series.last.pressureBar;
}

class ResolvedSac {
  const ResolvedSac(this.litersPerMin, this.source);
  final double litersPerMin;
  final SacSource source;
}

/// Mean ambient pressure over the samples whose timestamp lies in
/// [from, to]; the pressure at the nearest sample when none does.
double _meanAmbient(
  List<int> timestamps,
  List<double> depths,
  DiveEnvironment env,
  int from,
  int to,
) {
  var sum = 0.0;
  var n = 0;
  for (var i = 0; i < timestamps.length; i++) {
    if (timestamps[i] < from || timestamps[i] > to) continue;
    sum += env.pressureAtDepth(depths[i]);
    n++;
  }
  if (n > 0) return sum / n;
  var best = 0;
  for (var i = 1; i < timestamps.length; i++) {
    if ((timestamps[i] - from).abs() < (timestamps[best] - from).abs()) best = i;
  }
  return env.pressureAtDepth(depths.isEmpty ? 0 : depths[best]);
}

/// The span [start, end] over which [tankId] is in force on [schedule].
(int, int)? _usageSpan(TankSchedule schedule, String tankId, int diveEnd) {
  int? start;
  int? end;
  for (var k = 0; k < schedule.intervals.length; k++) {
    final iv = schedule.intervals[k];
    if (iv.tankId != tankId) continue;
    start ??= iv.startTimestamp;
    end = k + 1 < schedule.intervals.length
        ? schedule.intervals[k + 1].startTimestamp
        : diveEnd;
  }
  if (start == null || end == null) return null;
  return (start, end);
}

/// SAC (L/min at surface) at the branch: from the active tank's measured
/// series over a window around T (measured), else that tank's start/end
/// pressure over its usage span (diveAverage), else [fallbackLpm]
/// (logAverage), else [defaultLpm] (defaultValue).
ResolvedSac resolveBranchSac({
  required int branchTimestamp,
  required DiveTank? activeTank,
  required List<TankPressureSample>? activeSeries,
  required TankSchedule schedule,
  required List<int> timestamps,
  required List<double> depths,
  required DiveEnvironment environment,
  double? fallbackLpm,
  required double defaultLpm,
  int windowSeconds = 180,
}) {
  final volume = activeTank?.volume;
  if (activeTank != null && volume != null && volume > 0) {
    final series = activeSeries ?? const [];
    if (series.length >= 2) {
      for (final half in [windowSeconds ~/ 2, 300]) {
        final from = (branchTimestamp - half).clamp(
          series.first.timestamp,
          series.last.timestamp,
        );
        final to = (branchTimestamp + half).clamp(
          series.first.timestamp,
          series.last.timestamp,
        );
        if (to - from < 30) continue;
        final drop = pressureAtTimestamp(series, from)! -
            pressureAtTimestamp(series, to)!;
        if (drop <= 0) continue;
        final ambient = _meanAmbient(timestamps, depths, environment, from, to);
        final minutes = (to - from) / 60.0;
        return ResolvedSac(drop * volume / minutes / ambient, SacSource.measured);
      }
    }
    final start = activeTank.startPressure;
    final end = activeTank.endPressure;
    final span = _usageSpan(
      schedule,
      activeTank.id,
      timestamps.isEmpty ? 0 : timestamps.last,
    );
    if (start != null && end != null && start > end && span != null) {
      final minutes = (span.$2 - span.$1) / 60.0;
      if (minutes > 0) {
        final ambient = _meanAmbient(
          timestamps,
          depths,
          environment,
          span.$1,
          span.$2,
        );
        return ResolvedSac(
          (start - end) * volume / minutes / ambient,
          SacSource.diveAverage,
        );
      }
    }
  }
  if (fallbackLpm != null && fallbackLpm > 0) {
    return ResolvedSac(fallbackLpm, SacSource.logAverage);
  }
  return ResolvedSac(defaultLpm, SacSource.defaultValue);
}

/// Pressure of [tank] at [timestamp]: measured series, else linear between
/// start and end pressure over the tank's usage span (estimated), else the
/// start pressure alone (estimated), else unknown.
TankPressureAtBranch tankPressureAt({
  required DiveTank tank,
  required List<TankPressureSample>? series,
  required TankSchedule schedule,
  required int timestamp,
  required int diveEnd,
}) {
  if (series != null && series.isNotEmpty) {
    return TankPressureAtBranch(
      tankId: tank.id,
      pressureBar: pressureAtTimestamp(series, timestamp),
      source: PressureSource.measured,
    );
  }
  final start = tank.startPressure;
  if (start == null) {
    return TankPressureAtBranch(
      tankId: tank.id,
      pressureBar: null,
      source: PressureSource.unknown,
    );
  }
  final end = tank.endPressure;
  final span = _usageSpan(schedule, tank.id, diveEnd);
  double value = start;
  if (end != null && span != null && span.$2 > span.$1) {
    if (timestamp >= span.$2) {
      value = end;
    } else if (timestamp > span.$1) {
      final f = (timestamp - span.$1) / (span.$2 - span.$1);
      value = start + (end - start) * f;
    }
  }
  return TankPressureAtBranch(
    tankId: tank.id,
    pressureBar: value,
    source: PressureSource.estimated,
  );
}
```

`branch_state_builder.dart`:

```dart
import 'package:submersion/features/dive_lab/domain/entities/branch_state.dart';
import 'package:submersion/features/dive_lab/domain/entities/scenario_request.dart';
import 'package:submersion/features/dive_lab/domain/services/sac_resolver.dart';
import 'package:submersion/features/dive_lab/domain/services/tank_schedule.dart';
import 'package:submersion/features/dive_log/data/services/profile_analysis_service.dart';

/// Index of the sample nearest [branchSeconds] (earlier on ties), clamped.
int branchIndexFor(List<int> timestamps, int branchSeconds) {
  if (timestamps.isEmpty) return 0;
  var best = 0;
  for (var i = 1; i < timestamps.length; i++) {
    if ((timestamps[i] - branchSeconds).abs() <
        (timestamps[best] - branchSeconds).abs()) {
      best = i;
    }
  }
  return best;
}

/// The dive's complete state at [branchIndex], read from [actual] (tissues,
/// anchor, CNS, OTU) and [request] (tanks, pressures, SAC).
BranchState buildBranchState({
  required ScenarioRequest request,
  required ProfileAnalysis actual,
  required TankSchedule schedule,
  required int branchIndex,
}) {
  if (actual.decoStatuses.isEmpty) {
    throw StateError('actual analysis carries no deco statuses');
  }
  final i = branchIndex.clamp(0, actual.decoStatuses.length - 1);
  final status = actual.decoStatuses[i];
  final t = request.timestamps[i];
  final diveEnd = request.timestamps.last;
  final activeTankId = schedule.tankIdAt(t);
  final activeTank = schedule.tankById(activeTankId);
  final pressures = [
    for (final tank in request.tanks)
      tankPressureAt(
        tank: tank,
        series: request.tankPressures[tank.id],
        schedule: schedule,
        timestamp: t,
        diveEnd: diveEnd,
      ),
  ];
  final sac = resolveBranchSac(
    branchTimestamp: t,
    activeTank: activeTank,
    activeSeries: activeTankId == null
        ? null
        : request.tankPressures[activeTankId],
    schedule: schedule,
    timestamps: request.timestamps,
    depths: request.depths,
    environment: request.settings.environment,
    fallbackLpm: request.fallbackSacLpm,
    defaultLpm: request.settings.defaultSacLpm,
  );
  return BranchState(
    index: i,
    runtimeSeconds: t,
    depthMeters: request.depths[i],
    compartments: status.compartments,
    gfLowCeilingAnchor: status.gfLowCeilingAnchor ?? 0.0,
    cnsPercent: actual.cnsCurve != null && i < actual.cnsCurve!.length
        ? actual.cnsCurve![i]
        : 0.0,
    otu: actual.otuCurve != null && i < actual.otuCurve!.length
        ? actual.otuCurve![i]
        : 0.0,
    activeTankId: activeTankId,
    tankPressures: pressures,
    sacLitersPerMin: sac.litersPerMin,
    sacSource: sac.source,
  );
}
```

- [ ] **Step 4: Run the test**

Run: `flutter test test/features/dive_lab/domain/services/branch_state_builder_test.dart`
Expected: PASS. If the measured back pressure differs from 132.5 by more than 0.2, recompute the expectation from the generator (descent is `depth/20` minutes at mean ambient `1 + depth/20` bar; bottom is `(900 - descentSeconds)/60` minutes at `1 + depth/10` bar) and fix the test comment and value; do not loosen the tolerance.

- [ ] **Step 5: Commit**

```bash
git add lib/features/dive_lab/domain/entities/scenario_settings.dart lib/features/dive_lab/domain/entities/scenario_request.dart lib/features/dive_lab/domain/entities/branch_state.dart lib/features/dive_lab/domain/services/sac_resolver.dart lib/features/dive_lab/domain/services/branch_state_builder.dart test/features/dive_lab/domain/support/synthetic_dives.dart test/features/dive_lab/domain/services/branch_state_builder_test.dart
git commit -m "feat(dive-lab): settings, request and branch state at the branch point"
```

---

### Task 6: Remaining-bottom compiler (final ascent start + PlanSegments)

**Files:**
- Create: `lib/features/dive_lab/domain/services/remaining_bottom_compiler.dart`
- Test: `test/features/dive_lab/domain/services/remaining_bottom_compiler_test.dart`

**Interfaces:**
- Produces constants `kLevelToleranceMeters = 1.5`, `kReDescentToleranceMeters = 3.0`, `kSafetyStopBandMeters = 6.5`, `kLevelWindowSeconds = 60`; `int? finalAscentStartIndex({required List<double> depths, required List<int> timestamps, List<int> ndlCurve = const [], List<double> decoStopCurve = const []})` (the LAST sample index that is (a) within 3 m of the deepest depth still ahead, (b) deeper than 6.5 m, (c) not a deco stop: not (`ndl < 0` and `depth <= decoStop + 1.5`), (d) level: every sample in the preceding 60 s is within 1.5 m of it; null when no sample qualifies); `List<PlanSegment> compileRemainingBottom({required List<double> depths, required List<int> timestamps, required int branchIndex, required int? bottomEndIndex, required TankSchedule schedule, String? forcedTankId, int shiftSeconds = 0, bool ascendNow = false, String idPrefix = 'lab-seg'})` (groups samples into levels within +/-1.5 m of the running mean, emits a bottom segment per level at its mean depth and an ascent/descent transition between levels; shift trims/extends the last bottom segment; ascendNow or nothing remaining yields a single zero-duration bottom segment at the branch depth so `PlanEngine` schedules from that depth).

- [ ] **Step 1: Write the failing test**

```dart
// test/features/dive_lab/domain/services/remaining_bottom_compiler_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_lab/domain/services/remaining_bottom_compiler.dart';
import 'package:submersion/features/dive_lab/domain/services/tank_schedule.dart';
import 'package:submersion/features/dive_log/data/services/profile_analysis_service.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_segment.dart';

import '../support/synthetic_dives.dart';

ProfileAnalysis _analyze(SyntheticDive d) => ProfileAnalysisService(
  gfLow: 0.30,
  gfHigh: 0.70,
).analyze(
  diveId: 'd',
  depths: d.depths,
  timestamps: d.timestamps,
  gasSegments: TankSchedule.fromDive(
    tanks: d.tanks,
    switches: d.switches,
  ).toGasSegments(),
);

void main() {
  group('finalAscentStartIndex', () {
    test('square dive: the last bottom sample', () {
      final d = squareDive();
      final a = _analyze(d);
      expect(
        finalAscentStartIndex(
          depths: d.depths,
          timestamps: d.timestamps,
          ndlCurve: a.ndlCurve,
          decoStopCurve: a.decoStopCurve,
        ),
        d.bottomEndIndex,
      );
    });

    test('multi-level dive: the end of the shallow level', () {
      final d = multiLevelDive();
      final a = _analyze(d);
      expect(
        finalAscentStartIndex(
          depths: d.depths,
          timestamps: d.timestamps,
          ndlCurve: a.ndlCurve,
          decoStopCurve: a.decoStopCurve,
        ),
        d.bottomEndIndex,
      );
    });

    test('deco dive: stops are not mistaken for a bottom level', () {
      // 45 m for 30 min goes into deco at GF 30/70; the 5 m hold is inside
      // the safety band and any deeper stop sits on the ceiling.
      final d = squareDive(depth: 45, bottomMinutes: 30, withDeco50: false);
      final a = _analyze(d);
      expect(a.hadDecoObligation, isTrue);
      expect(
        finalAscentStartIndex(
          depths: d.depths,
          timestamps: d.timestamps,
          ndlCurve: a.ndlCurve,
          decoStopCurve: a.decoStopCurve,
        ),
        d.bottomEndIndex,
      );
    });

    test('no sample deeper than the safety band yields null', () {
      expect(
        finalAscentStartIndex(
          depths: [0, 3, 5, 5, 5, 2, 0],
          timestamps: [0, 10, 20, 30, 40, 50, 60],
        ),
        isNull,
      );
    });
  });

  group('compileRemainingBottom', () {
    test('branch mid-bottom yields one bottom segment to the ascent start', () {
      final d = squareDive();
      final schedule = TankSchedule.fromDive(tanks: d.tanks, switches: d.switches);
      final branch = d.indexAt(900);
      final segs = compileRemainingBottom(
        depths: d.depths,
        timestamps: d.timestamps,
        branchIndex: branch,
        bottomEndIndex: d.bottomEndIndex,
        schedule: schedule,
      );
      expect(segs, hasLength(1));
      expect(segs.single.type, SegmentType.bottom);
      expect(segs.single.startDepth, closeTo(40, 1e-9));
      expect(
        segs.single.durationSeconds,
        d.timestamps[d.bottomEndIndex] - 900,
      );
      expect(segs.single.tankId, 'back');
      expect(segs.single.gasMix.o2, 21);
      expect(segs.single.order, 0);
    });

    test('multi-level branch yields level, transition, level', () {
      final d = multiLevelDive();
      final schedule = TankSchedule.fromDive(tanks: d.tanks, switches: d.switches);
      final branch = d.indexAt(600);
      final segs = compileRemainingBottom(
        depths: d.depths,
        timestamps: d.timestamps,
        branchIndex: branch,
        bottomEndIndex: d.bottomEndIndex,
        schedule: schedule,
      );
      expect(segs.map((s) => s.type), [
        SegmentType.bottom,
        SegmentType.ascent,
        SegmentType.bottom,
      ]);
      expect(segs[0].startDepth, closeTo(40, 1e-9));
      expect(segs[1].startDepth, closeTo(40, 0.5));
      expect(segs[1].endDepth, closeTo(20, 0.5));
      expect(segs[2].startDepth, closeTo(20, 1e-9));
      final total = segs.fold(0, (s, x) => s + x.durationSeconds);
      expect(total, d.timestamps[d.bottomEndIndex] - 600);
      expect(segs.map((s) => s.order), [0, 1, 2]);
    });

    test('forcedTankId overrides the tank on every segment', () {
      final d = squareDive();
      final schedule = TankSchedule.fromDive(tanks: d.tanks, switches: d.switches);
      final segs = compileRemainingBottom(
        depths: d.depths,
        timestamps: d.timestamps,
        branchIndex: d.indexAt(900),
        bottomEndIndex: d.bottomEndIndex,
        schedule: schedule,
        forcedTankId: 'deco50',
      );
      expect(segs.single.tankId, 'deco50');
      expect(segs.single.gasMix.o2, 50);
    });

    test('negative shift trims the last bottom; positive extends it', () {
      final d = squareDive();
      final schedule = TankSchedule.fromDive(tanks: d.tanks, switches: d.switches);
      final base = compileRemainingBottom(
        depths: d.depths,
        timestamps: d.timestamps,
        branchIndex: d.indexAt(900),
        bottomEndIndex: d.bottomEndIndex,
        schedule: schedule,
      ).single.durationSeconds;
      final earlier = compileRemainingBottom(
        depths: d.depths,
        timestamps: d.timestamps,
        branchIndex: d.indexAt(900),
        bottomEndIndex: d.bottomEndIndex,
        schedule: schedule,
        shiftSeconds: -300,
      );
      expect(earlier.single.durationSeconds, base - 300);
      final later = compileRemainingBottom(
        depths: d.depths,
        timestamps: d.timestamps,
        branchIndex: d.indexAt(900),
        bottomEndIndex: d.bottomEndIndex,
        schedule: schedule,
        shiftSeconds: 300,
      );
      expect(later.single.durationSeconds, base + 300);
    });

    test('a shift larger than the remainder collapses to ascend-now', () {
      final d = squareDive();
      final schedule = TankSchedule.fromDive(tanks: d.tanks, switches: d.switches);
      final segs = compileRemainingBottom(
        depths: d.depths,
        timestamps: d.timestamps,
        branchIndex: d.indexAt(900),
        bottomEndIndex: d.bottomEndIndex,
        schedule: schedule,
        shiftSeconds: -99999,
      );
      expect(segs, hasLength(1));
      expect(segs.single.durationSeconds, 0);
      expect(segs.single.startDepth, 40);
    });

    test('ascendNow and branch-after-bottom yield a zero-duration hold', () {
      final d = squareDive();
      final schedule = TankSchedule.fromDive(tanks: d.tanks, switches: d.switches);
      final now = compileRemainingBottom(
        depths: d.depths,
        timestamps: d.timestamps,
        branchIndex: d.indexAt(900),
        bottomEndIndex: d.bottomEndIndex,
        schedule: schedule,
        ascendNow: true,
      );
      expect(now.single.durationSeconds, 0);
      expect(now.single.startDepth, 40);
      final late = compileRemainingBottom(
        depths: d.depths,
        timestamps: d.timestamps,
        branchIndex: d.bottomEndIndex + 30,
        bottomEndIndex: d.bottomEndIndex,
        schedule: schedule,
      );
      expect(late.single.durationSeconds, 0);
      expect(late.single.startDepth, d.depths[d.bottomEndIndex + 30]);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/dive_lab/domain/services/remaining_bottom_compiler_test.dart`
Expected: FAIL, file missing.

- [ ] **Step 3: Write the compiler**

```dart
// lib/features/dive_lab/domain/services/remaining_bottom_compiler.dart
import 'package:submersion/features/dive_lab/domain/services/tank_schedule.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_segment.dart';

/// Samples within this of a level's running mean belong to that level.
const double kLevelToleranceMeters = 1.5;

/// A later sample more than this deeper means the ascent had not begun.
const double kReDescentToleranceMeters = 3.0;

/// Samples at or shallower than this are the safety-stop band, never bottom.
const double kSafetyStopBandMeters = 6.5;

/// Window over which a sample must be level to count as bottom.
const int kLevelWindowSeconds = 60;

/// The last sample of the bottom phase: the last index that is within
/// [kReDescentToleranceMeters] of the deepest depth still ahead, deeper than
/// [kSafetyStopBandMeters], not sitting on a deco stop (in deco and within
/// 1.5 m of the stop level), and level over the preceding
/// [kLevelWindowSeconds]. Null when nothing qualifies.
int? finalAscentStartIndex({
  required List<double> depths,
  required List<int> timestamps,
  List<int> ndlCurve = const [],
  List<double> decoStopCurve = const [],
}) {
  if (depths.isEmpty || depths.length != timestamps.length) return null;
  final n = depths.length;
  final useStops = ndlCurve.length == n && decoStopCurve.length == n;
  var deepestAhead = 0.0;
  for (var i = n - 1; i >= 0; i--) {
    if (depths[i] > deepestAhead) deepestAhead = depths[i];
    final d = depths[i];
    if (d <= kSafetyStopBandMeters) continue;
    if (d < deepestAhead - kReDescentToleranceMeters) continue;
    if (useStops &&
        ndlCurve[i] < 0 &&
        d <= decoStopCurve[i] + kLevelToleranceMeters) {
      continue;
    }
    if (!_isLevel(depths, timestamps, i)) continue;
    return i;
  }
  return null;
}

bool _isLevel(List<double> depths, List<int> timestamps, int i) {
  final from = timestamps[i] - kLevelWindowSeconds;
  for (var j = i; j >= 0 && timestamps[j] >= from; j--) {
    if ((depths[j] - depths[i]).abs() > kLevelToleranceMeters) return false;
  }
  return true;
}

class _Level {
  _Level(this.startIndex, double depth) : sum = depth, count = 1, endIndex = startIndex;
  final int startIndex;
  int endIndex;
  double sum;
  int count;
  double get mean => sum / count;
  void add(int index, double depth) {
    endIndex = index;
    sum += depth;
    count++;
  }
}

/// The dive's remaining bottom phase, from [branchIndex] to [bottomEndIndex],
/// as planner segments (see the spec's re-plan pipeline). Always returns at
/// least one segment: a zero-duration hold at the branch depth anchors the
/// engine's computed ascent when nothing remains.
List<PlanSegment> compileRemainingBottom({
  required List<double> depths,
  required List<int> timestamps,
  required int branchIndex,
  required int? bottomEndIndex,
  required TankSchedule schedule,
  String? forcedTankId,
  int shiftSeconds = 0,
  bool ascendNow = false,
  String idPrefix = 'lab-seg',
}) {
  final branchDepth = depths[branchIndex];
  PlanSegment hold() => PlanSegment(
    id: '$idPrefix-0',
    type: SegmentType.bottom,
    startDepth: branchDepth,
    endDepth: branchDepth,
    durationSeconds: 0,
    tankId: _tankIdAt(schedule, timestamps[branchIndex], forcedTankId),
    gasMix: _mixAt(schedule, timestamps[branchIndex], forcedTankId),
    order: 0,
  );
  if (ascendNow || bottomEndIndex == null || bottomEndIndex <= branchIndex) {
    return [hold()];
  }

  final levels = <_Level>[_Level(branchIndex, depths[branchIndex])];
  for (var i = branchIndex + 1; i <= bottomEndIndex; i++) {
    final current = levels.last;
    if ((depths[i] - current.mean).abs() <= kLevelToleranceMeters) {
      current.add(i, depths[i]);
    } else {
      levels.add(_Level(i, depths[i]));
    }
  }

  final segments = <PlanSegment>[];
  var order = 0;
  for (var k = 0; k < levels.length; k++) {
    final level = levels[k];
    final startTs = timestamps[level.startIndex];
    if (k > 0) {
      final prev = levels[k - 1];
      final transitionSeconds = startTs - timestamps[prev.endIndex];
      if (transitionSeconds > 0) {
        final goingDown = level.mean > prev.mean;
        segments.add(
          PlanSegment(
            id: '$idPrefix-$order',
            type: goingDown ? SegmentType.descent : SegmentType.ascent,
            startDepth: prev.mean,
            endDepth: level.mean,
            durationSeconds: transitionSeconds,
            tankId: _tankIdAt(schedule, startTs, forcedTankId),
            gasMix: _mixAt(schedule, startTs, forcedTankId),
            order: order,
          ),
        );
        order++;
      }
    }
    final holdSeconds = timestamps[level.endIndex] - startTs;
    if (holdSeconds > 0) {
      segments.add(
        PlanSegment(
          id: '$idPrefix-$order',
          type: SegmentType.bottom,
          startDepth: level.mean,
          endDepth: level.mean,
          durationSeconds: holdSeconds,
          tankId: _tankIdAt(schedule, startTs, forcedTankId),
          gasMix: _mixAt(schedule, startTs, forcedTankId),
          order: order,
        ),
      );
      order++;
    }
  }

  if (shiftSeconds != 0) {
    var remaining = shiftSeconds;
    for (var k = segments.length - 1; k >= 0 && remaining != 0; k--) {
      final s = segments[k];
      if (s.type != SegmentType.bottom) continue;
      final newDuration = s.durationSeconds + remaining;
      if (newDuration > 0) {
        segments[k] = s.copyWith(durationSeconds: newDuration);
        remaining = 0;
      } else {
        remaining = newDuration; // still negative: carry into earlier bottoms
        segments.removeAt(k);
      }
    }
    // Drop transitions left dangling at the end after trimming.
    while (segments.isNotEmpty && segments.last.type != SegmentType.bottom) {
      segments.removeLast();
    }
  }

  if (segments.isEmpty) return [hold()];
  return [
    for (var k = 0; k < segments.length; k++)
      segments[k].copyWith(id: '$idPrefix-$k', order: k),
  ];
}

String _tankIdAt(TankSchedule schedule, int t, String? forced) =>
    forced ?? schedule.tankIdAt(t) ?? 'lab-no-tank';

GasMix _mixAt(TankSchedule schedule, int t, String? forced) =>
    (forced != null ? schedule.tankById(forced)?.gasMix : null) ??
    schedule.mixAt(t);
```

- [ ] **Step 4: Run the test**

Run: `flutter test test/features/dive_lab/domain/services/remaining_bottom_compiler_test.dart`
Expected: PASS. If the multi-level transition test yields an extra level (the 9 m/min ramp produces intermediate samples > 1.5 m apart, each its own level), tighten: the expected shape there is exactly `[bottom, ascent, bottom]`, so the grouping must merge the ramp into a single transition. Fix by treating samples that fall between two levels as transition (not level) only when the level's hold would be zero: i.e. keep the grouping as written but when building segments merge consecutive zero-hold levels into the transition (their `holdSeconds == 0` already emits no bottom; the transition duration spans from the previous real level's end to the next real level's start). Implement by skipping levels with `count < 2` when computing `prev`.

- [ ] **Step 5: Commit**

```bash
git add lib/features/dive_lab/domain/services/remaining_bottom_compiler.dart test/features/dive_lab/domain/services/remaining_bottom_compiler_test.dart
git commit -m "feat(dive-lab): final ascent detection and remaining-bottom compiler"
```

---

### Task 7: Scenario plan compiler (+ public `PlanEngine.ascentPlanFor`)

**Files:**
- Modify: `lib/features/planner/domain/services/plan_engine.dart` (rename `_ascentPlanFor` to public `ascentPlanFor`; update its two call sites)
- Create: `lib/features/dive_lab/domain/services/scenario_plan_compiler.dart`
- Test: `test/features/dive_lab/domain/services/scenario_plan_compiler_test.dart`

**Interfaces:**
- Produces `AscentGasPlan PlanEngine.ascentPlanFor(List<DiveTank> tanks)` (same body as the private one).
- Produces `class CompiledScenario { final DivePlan plan; final String? forcedTankId; final int extraLastStopSeconds; }`, `String? forcedTankIdFor({required List<ScenarioIntervention> interventions, required List<DiveTank> tanks, required double branchDepth, required double maxPpO2})` and `CompiledScenario compileScenarioPlan({required ScenarioRequest request, required BranchState branch, required ScenarioSettings settings, required List<ScenarioIntervention> interventions, required List<PlanSegment> remainingBottom})`:
  - tanks: `request.tanks` with `startPressure = branch.pressureFor(id)` when known (else the tank's own start pressure stays, flagged later); `loseTank` removed; `switchGas`/`bailOut` hypothetical tank appended via `hypotheticalTank(ref)`; `switchGas` existing tank `copyWith(decoSwitchDepth: branch.depthMeters)`; `bailOut` restricts the plan's tanks to the bailout pool (bailout-role tanks, or the named/hypothetical tank).
  - `forcedTankId` = the switchGas tank id (the caller passes it to `compileRemainingBottom` BEFORE calling this function; the compiler returns it for convenience). For `bailOut` the forced tank is the best bailout tank at the branch depth.
  - mode: `DiveMode.oc -> PlanMode.oc`, `ccr -> PlanMode.ccr`, `scr -> PlanMode.scr`; `bailOut` forces `PlanMode.oc`.
  - GF from `settings.gfLowPercent/gfHighPercent`; `altitude`, `waterType`, `ascentRate`, `descentRate`, `lastStopDepth`, `gasSwitchStopSeconds`, `airBreaks` from settings with `AscentPolicyIntervention` overrides (`extraLastStopSeconds` is applied by the synthesizer, not here); `reservePressure = settings.reservePressureBar`; `setpointLow/High` from the request.
  - SAC: `sacBottom = branch.sacLitersPerMin`; `shareGas` sets `sacBottom = sacDeco = branch.sac x 2.5 x (buddyFactor ?? settings.buddyFactor)`; `bailOut` sets both to `branch.sac x 2.5`.
  - `id = 'lab-${scenario.id}'`, `name = scenario.name`, `sourceDiveId = request.diveId`, `createdAt/updatedAt = scenario.createdAt`.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/dive_lab/domain/services/scenario_plan_compiler_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_lab/domain/entities/branch_state.dart';
import 'package:submersion/features/dive_lab/domain/entities/dive_scenario.dart';
import 'package:submersion/features/dive_lab/domain/entities/scenario_intervention.dart';
import 'package:submersion/features/dive_lab/domain/entities/scenario_mode.dart';
import 'package:submersion/features/dive_lab/domain/entities/scenario_request.dart';
import 'package:submersion/features/dive_lab/domain/entities/scenario_settings.dart';
import 'package:submersion/features/dive_lab/domain/services/scenario_plan_compiler.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_segment.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart' as domain;

const back = DiveTank(id: 'back', volume: 24, startPressure: 200, gasMix: GasMix(o2: 21), role: TankRole.backGas);
const deco50 = DiveTank(id: 'deco50', volume: 11.1, startPressure: 200, gasMix: GasMix(o2: 50), role: TankRole.deco);
const bo = DiveTank(id: 'bo', volume: 11.1, startPressure: 200, gasMix: GasMix(o2: 32), role: TankRole.bailout);

final scenario = DiveScenario(
  id: 'sc', diveId: 'd', name: 'What if', branchSeconds: 900,
  mode: ScenarioMode.replan, createdAt: DateTime(2026, 8, 21), updatedAt: DateTime(2026, 8, 21),
);

ScenarioRequest _request({List<DiveTank> tanks = const [back, deco50], DiveMode mode = DiveMode.oc}) =>
    ScenarioRequest(
      diveId: 'd', depths: const [0, 40, 40], timestamps: const [0, 10, 20],
      diveMode: mode, tanks: tanks, scenario: scenario,
    );

const branch = BranchState(
  index: 1, runtimeSeconds: 900, depthMeters: 40, compartments: [], gfLowCeilingAnchor: 12,
  cnsPercent: 5, otu: 20, activeTankId: 'back',
  tankPressures: [
    TankPressureAtBranch(tankId: 'back', pressureBar: 130, source: PressureSource.measured),
    TankPressureAtBranch(tankId: 'deco50', pressureBar: 198, source: PressureSource.estimated),
  ],
  sacLitersPerMin: 18, sacSource: SacSource.measured,
);

final bottom = [
  PlanSegment.bottom(id: 'lab-seg-0', depth: 40, durationMinutes: 5, tankId: 'back', gasMix: const GasMix(o2: 21)),
];

void main() {
  test('baseline: tanks at branch pressure, settings, SAC, identity', () {
    final c = compileScenarioPlan(
      request: _request(), branch: branch, settings: const ScenarioSettings(gfLow: 0.4, gfHigh: 0.85),
      interventions: const [], remainingBottom: bottom,
    );
    final p = c.plan;
    expect(p.id, 'lab-sc');
    expect(p.sourceDiveId, 'd');
    expect(p.mode, domain.PlanMode.oc);
    expect(p.gfLow, 40);
    expect(p.gfHigh, 85);
    expect(p.sacBottom, 18);
    expect(p.sacDeco, isNull);
    expect(p.tanks.map((t) => t.id), ['back', 'deco50']);
    expect(p.tanks[0].startPressure, 130);
    expect(p.tanks[1].startPressure, 198);
    expect(p.segments, bottom);
    expect(p.reservePressure, 50);
    expect(c.forcedTankId, isNull);
  });

  test('loseTank removes the tank', () {
    final c = compileScenarioPlan(
      request: _request(), branch: branch, settings: const ScenarioSettings(),
      interventions: const [LoseTankIntervention(tankId: 'deco50')], remainingBottom: bottom,
    );
    expect(c.plan.tanks.map((t) => t.id), ['back']);
  });

  test('switchGas pins the switch depth and reports the forced tank', () {
    final c = compileScenarioPlan(
      request: _request(), branch: branch, settings: const ScenarioSettings(),
      interventions: const [SwitchGasIntervention(tank: ExistingTankRef('deco50'))], remainingBottom: bottom,
    );
    expect(c.forcedTankId, 'deco50');
    expect(c.plan.tanks.firstWhere((t) => t.id == 'deco50').decoSwitchDepth, 40);
  });

  test('switchGas to a hypothetical tank appends it', () {
    const ref = HypotheticalTankRef(gasMix: GasMix(o2: 50), volumeLiters: 11.1, startPressureBar: 200);
    final c = compileScenarioPlan(
      request: _request(tanks: const [back]), branch: branch, settings: const ScenarioSettings(),
      interventions: const [SwitchGasIntervention(tank: ref)], remainingBottom: bottom,
    );
    expect(c.plan.tanks.map((t) => t.id), ['back', ref.tankId]);
    expect(c.forcedTankId, ref.tankId);
    expect(c.plan.tanks.last.decoSwitchDepth, 40);
  });

  test('shareGas stresses both SAC rates by the buddy factor', () {
    final c = compileScenarioPlan(
      request: _request(), branch: branch, settings: const ScenarioSettings(buddyFactor: 2),
      interventions: const [ShareGasIntervention()], remainingBottom: bottom,
    );
    expect(c.plan.sacBottom, closeTo(18 * 2.5 * 2, 1e-9));
    expect(c.plan.sacDeco, closeTo(18 * 2.5 * 2, 1e-9));
    final custom = compileScenarioPlan(
      request: _request(), branch: branch, settings: const ScenarioSettings(),
      interventions: const [ShareGasIntervention(buddyFactor: 1.5)], remainingBottom: bottom,
    );
    expect(custom.plan.sacBottom, closeTo(18 * 2.5 * 1.5, 1e-9));
  });

  test('bailOut compiles an OC plan on the bailout pool at stressed SAC', () {
    final c = compileScenarioPlan(
      request: _request(tanks: const [back, bo], mode: DiveMode.ccr), branch: branch,
      settings: const ScenarioSettings(), interventions: const [BailOutIntervention()], remainingBottom: bottom,
    );
    expect(c.plan.mode, domain.PlanMode.oc);
    expect(c.plan.tanks.map((t) => t.id), ['bo']);
    expect(c.forcedTankId, 'bo');
    expect(c.plan.sacBottom, closeTo(45, 1e-9));
  });

  test('ascentPolicy overrides the schedule fields', () {
    final c = compileScenarioPlan(
      request: _request(), branch: branch, settings: const ScenarioSettings(),
      interventions: const [AscentPolicyIntervention(ascentRate: 6, lastStopDepth: 6, gasSwitchStopSeconds: 60)],
      remainingBottom: bottom,
    );
    expect(c.plan.ascentRate, 6);
    expect(c.plan.lastStopDepth, 6);
    expect(c.plan.gasSwitchStopSeconds, 60);
  });

  test('ccr request compiles a ccr plan with the setpoints', () {
    final r = ScenarioRequest(
      diveId: 'd', depths: const [0, 40, 40], timestamps: const [0, 10, 20], diveMode: DiveMode.ccr,
      tanks: const [back], setpointHigh: 1.3, setpointLow: 0.7, scenario: scenario,
    );
    final c = compileScenarioPlan(
      request: r, branch: branch, settings: const ScenarioSettings(), interventions: const [], remainingBottom: bottom,
    );
    expect(c.plan.mode, domain.PlanMode.ccr);
    expect(c.plan.setpointHigh, 1.3);
    expect(c.plan.setpointLow, 0.7);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/dive_lab/domain/services/scenario_plan_compiler_test.dart`
Expected: FAIL, file missing.

- [ ] **Step 3: Make `ascentPlanFor` public and write the compiler**

In `plan_engine.dart`: rename `AscentGasPlan _ascentPlanFor(List<DiveTank> tanks)` to `AscentGasPlan ascentPlanFor(List<DiveTank> tanks)` with a doc comment ("The open-circuit ascent gas plan for [tanks]: the richest eligible mix at each depth under the deco ppO2. Public so the Dive Lab synthesises the same switches the engine schedules."); update the call in `compute` (`: _ascentPlanFor(plan.tanks)` becomes `: ascentPlanFor(plan.tanks)`) and any other reference (`grep -n _ascentPlanFor`).

```dart
// lib/features/dive_lab/domain/services/scenario_plan_compiler.dart
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_lab/domain/entities/branch_state.dart';
import 'package:submersion/features/dive_lab/domain/entities/scenario_intervention.dart';
import 'package:submersion/features/dive_lab/domain/entities/scenario_request.dart';
import 'package:submersion/features/dive_lab/domain/entities/scenario_settings.dart';
import 'package:submersion/features/dive_lab/domain/services/replay_schedule_rewriter.dart';
import 'package:submersion/features/dive_lab/domain/services/tank_schedule.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_segment.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart' as domain;

/// The planner input the re-plan pipeline feeds to PlanEngine.
class CompiledScenario {
  const CompiledScenario({
    required this.plan,
    required this.forcedTankId,
    required this.extraLastStopSeconds,
  });

  final domain.DivePlan plan;

  /// The tank the remaining bottom breathes when an intervention switches
  /// gas at the branch (switchGas, bailOut); null = the recorded schedule.
  final String? forcedTankId;

  /// Seconds the synthesizer appends to the final stop (ascentPolicy).
  final int extraLastStopSeconds;
}

/// The tank the remaining bottom must breathe for [interventions], resolved
/// before compiling segments: the switchGas tank, or the best bailout tank
/// at the branch depth. Null when the recorded schedule stands.
String? forcedTankIdFor({
  required List<ScenarioIntervention> interventions,
  required List<DiveTank> tanks,
  required double branchDepth,
  required double maxPpO2,
}) {
  for (final i in interventions) {
    if (i is SwitchGasIntervention) return i.tank.tankId;
  }
  for (final i in interventions) {
    if (i is BailOutIntervention) {
      final pool = _bailoutPool(i, tanks);
      return bestTankForDepth(pool, branchDepth, maxPpO2: maxPpO2)?.id;
    }
  }
  return null;
}

List<DiveTank> _bailoutPool(BailOutIntervention i, List<DiveTank> tanks) {
  final ref = i.tank;
  if (ref is HypotheticalTankRef) return [hypotheticalTank(ref)];
  if (ref is ExistingTankRef) {
    return tanks.where((t) => t.id == ref.tankId).toList();
  }
  return tanks.where((t) => t.role == TankRole.bailout).toList();
}

CompiledScenario compileScenarioPlan({
  required ScenarioRequest request,
  required BranchState branch,
  required ScenarioSettings settings,
  required List<ScenarioIntervention> interventions,
  required List<PlanSegment> remainingBottom,
}) {
  final scenario = request.scenario;

  // Tanks at the branch.
  var tanks = <DiveTank>[
    for (final t in request.tanks)
      branch.pressureFor(t.id) != null
          ? t.copyWith(startPressure: branch.pressureFor(t.id))
          : t,
  ];
  var mode = switch (request.diveMode) {
    DiveMode.ccr => domain.PlanMode.ccr,
    DiveMode.scr => domain.PlanMode.scr,
    DiveMode.oc || DiveMode.gauge => domain.PlanMode.oc,
  };
  var sacBottom = branch.sacLitersPerMin;
  double? sacDeco;
  String? forcedTankId;
  var ascentRate = settings.ascentRate;
  var lastStopDepth = settings.lastStopDepth;
  var gasSwitchStopSeconds = settings.gasSwitchStopSeconds;
  var extraLastStopSeconds = 0;

  for (final i in interventions) {
    switch (i) {
      case LoseTankIntervention(:final tankId):
        tanks = tanks.where((t) => t.id != tankId).toList();
      case SwitchGasIntervention(:final tank):
        switch (tank) {
          case ExistingTankRef(:final tankId):
            tanks = [
              for (final t in tanks)
                t.id == tankId
                    ? t.copyWith(decoSwitchDepth: branch.depthMeters)
                    : t,
            ];
            forcedTankId = tankId;
          case HypotheticalTankRef():
            tanks = [
              ...tanks,
              hypotheticalTank(tank).copyWith(
                decoSwitchDepth: branch.depthMeters,
              ),
            ];
            forcedTankId = tank.tankId;
        }
      case ShareGasIntervention(:final buddyFactor):
        final stressed =
            branch.sacLitersPerMin * 2.5 * (buddyFactor ?? settings.buddyFactor);
        sacBottom = stressed;
        sacDeco = stressed;
      case BailOutIntervention():
        final pool = _bailoutPool(i, request.tanks);
        tanks = [
          for (final t in pool)
            branch.pressureFor(t.id) != null
                ? t.copyWith(startPressure: branch.pressureFor(t.id))
                : t,
        ];
        mode = domain.PlanMode.oc;
        final stressed = branch.sacLitersPerMin * 2.5;
        sacBottom = stressed;
        sacDeco = stressed;
        forcedTankId = bestTankForDepth(
          tanks,
          branch.depthMeters,
          maxPpO2: settings.ppO2Deco,
        )?.id;
      case AscentPolicyIntervention(
        ascentRate: final rate,
        lastStopDepth: final lastStop,
        extraLastStopSeconds: final extra,
        gasSwitchStopSeconds: final switchStop,
      ):
        if (rate != null && rate > 0) ascentRate = rate;
        if (lastStop != null && lastStop > 0) lastStopDepth = lastStop;
        if (switchStop != null && switchStop >= 0) {
          gasSwitchStopSeconds = switchStop;
        }
        if (extra != null && extra > 0) extraLastStopSeconds = extra;
      case ShiftAscentIntervention() ||
          AscendNowIntervention() ||
          ChangeGfIntervention():
        break; // applied elsewhere (segments / settings)
    }
  }

  final plan = domain.DivePlan(
    id: 'lab-${scenario.id}',
    name: scenario.name,
    createdAt: scenario.createdAt,
    updatedAt: scenario.createdAt,
    mode: mode,
    altitude: settings.altitudeMeters,
    waterType: settings.waterType,
    gfLow: settings.gfLowPercent,
    gfHigh: settings.gfHighPercent,
    descentRate: settings.descentRate,
    ascentRate: ascentRate,
    lastStopDepth: lastStopDepth,
    gasSwitchStopSeconds: gasSwitchStopSeconds,
    airBreaks: settings.airBreaks,
    sacBottom: sacBottom,
    sacDeco: sacDeco,
    reservePressure: settings.reservePressureBar,
    sourceDiveId: request.diveId,
    setpointLow: request.setpointLow,
    setpointHigh: request.setpointHigh,
    segments: remainingBottom,
    tanks: tanks,
  );
  return CompiledScenario(
    plan: plan,
    forcedTankId: forcedTankId,
    extraLastStopSeconds: extraLastStopSeconds,
  );
}
```

- [ ] **Step 4: Run the test and the planner engine tests**

Run: `flutter test test/features/dive_lab/domain/services/scenario_plan_compiler_test.dart test/features/planner/`
Expected: PASS (the rename must not break planner tests).

- [ ] **Step 5: Commit**

```bash
git add lib/features/planner/domain/services/plan_engine.dart lib/features/dive_lab/domain/services/scenario_plan_compiler.dart test/features/dive_lab/domain/services/scenario_plan_compiler_test.dart
git commit -m "feat(dive-lab): compile a scenario into a DivePlan; expose PlanEngine.ascentPlanFor"
```

---

### Task 8: Counterfactual remainder synthesizer + splice

**Files:**
- Create: `lib/features/dive_lab/domain/services/counterfactual_profile_synthesizer.dart`
- Test: `test/features/dive_lab/domain/services/counterfactual_profile_synthesizer_test.dart`

**Interfaces:**
- Produces `class LoopSetpoints { final double low; final double high; final double switchDepth; final GasMix diluent; }`; `class SynthesizedRemainder { final List<int> timestamps; final List<double> depths; final List<ProfileGasSegment> gasSegments; final List<ScenarioGasSwitch> tankSwitches; final int bottomEndTimestamp; }`; `SynthesizedRemainder synthesizeRemainder({required DivePlan plan, required PlanOutcome outcome, required int startTimestamp, required double startDepth, required AscentGasPlan ascentPlan, LoopSetpoints? loop, int stepSeconds = 10, int extraLastStopSeconds = 0})` (first sample is `(startTimestamp, startDepth)`; plan segments walked linearly; ascent legs at `plan.ascentRate`; stops held for `durationSeconds` (+ extra on the last); final leg to 0 m; timestamps strictly increasing; OC gas segments emitted when `(fN2, fHe)` changes using segment mixes on the bottom and `ascentPlan.gasForDepth` on the ascent/stops; loop mode emits setpoint segments (high below `switchDepth`, low above) with diluent fractions; `tankSwitches` name the tank of each OC gas change by matching the mix against `plan.tanks`, deco/stage roles winning ties); `class SplicedProfile { timestamps, depths, gasSegments }`; `SplicedProfile spliceCounterfactual({required List<int> actualTimestamps, required List<double> actualDepths, required List<ProfileGasSegment> actualGasSegments, required int branchIndex, required SynthesizedRemainder remainder})` (actual samples `0..branchIndex` then the remainder minus its first sample; gas segments = actual ones starting at or before the branch timestamp then the remainder's).

- [ ] **Step 1: Write the failing test**

```dart
// test/features/dive_lab/domain/services/counterfactual_profile_synthesizer_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/deco/constants/buhlmann_coefficients.dart';
import 'package:submersion/core/deco/entities/profile_gas_segment.dart';
import 'package:submersion/features/dive_lab/domain/services/counterfactual_profile_synthesizer.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_segment.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart' as domain;
import 'package:submersion/features/planner/domain/services/plan_engine.dart';

const back = DiveTank(id: 'back', volume: 24, startPressure: 150, gasMix: GasMix(o2: 21), role: TankRole.backGas);
const deco50 = DiveTank(id: 'deco50', volume: 11.1, startPressure: 200, gasMix: GasMix(o2: 50), role: TankRole.deco);

domain.DivePlan _plan({int bottomMinutes = 10, List<DiveTank> tanks = const [back, deco50]}) => domain.DivePlan(
  id: 'p', name: 'p', gfLow: 30, gfHigh: 70,
  createdAt: DateTime(2026), updatedAt: DateTime(2026),
  tanks: tanks,
  segments: [
    PlanSegment.bottom(id: 's0', depth: 45, durationMinutes: bottomMinutes, tankId: 'back', gasMix: const GasMix(o2: 21)),
  ],
);

void main() {
  test('remainder starts at T, walks the bottom, stops, and surfaces', () {
    final plan = _plan();
    const engine = PlanEngine();
    final outcome = engine.compute(plan);
    final r = synthesizeRemainder(
      plan: plan, outcome: outcome, startTimestamp: 1500, startDepth: 45,
      ascentPlan: engine.ascentPlanFor(plan.tanks),
    );
    expect(r.timestamps.first, 1500);
    expect(r.depths.first, 45);
    expect(r.depths.last, 0);
    for (var i = 1; i < r.timestamps.length; i++) {
      expect(r.timestamps[i], greaterThan(r.timestamps[i - 1]), reason: 'sample $i');
    }
    expect(r.bottomEndTimestamp, 1500 + 600);
    // Total synthesized duration = bottom + outcome ascent (tts from bottom).
    expect(r.timestamps.last - 1500, 600 + outcome.ttsAtBottom);
    // Stops appear as level holds at the outcome's stop depths.
    for (final stop in outcome.stops) {
      expect(r.depths.where((d) => (d - stop.depthMeters).abs() < 1e-9).length, greaterThan(1), reason: 'stop ${stop.depthMeters}');
    }
  });

  test('gas segments switch to 50% on the ascent and name the tank', () {
    final plan = _plan();
    const engine = PlanEngine();
    final outcome = engine.compute(plan);
    final r = synthesizeRemainder(
      plan: plan, outcome: outcome, startTimestamp: 0, startDepth: 45,
      ascentPlan: engine.ascentPlanFor(plan.tanks),
    );
    expect(r.gasSegments.first.startTimestamp, 0);
    expect(r.gasSegments.first.fN2, airN2Fraction);
    expect(r.gasSegments.any((g) => (g.fN2 - 0.5).abs() < 1e-9), isTrue);
    expect(r.tankSwitches.map((s) => s.tankId), contains('deco50'));
    // The 50% switch happens no deeper than its MOD at 1.6 (21 m).
    final sw = r.tankSwitches.firstWhere((s) => s.tankId == 'deco50');
    final idx = r.timestamps.indexOf(sw.timestamp);
    expect(r.depths[idx], lessThanOrEqualTo(21.0 + 1e-6));
  });

  test('extraLastStopSeconds lengthens only the final stop', () {
    final plan = _plan();
    const engine = PlanEngine();
    final outcome = engine.compute(plan);
    final base = synthesizeRemainder(plan: plan, outcome: outcome, startTimestamp: 0, startDepth: 45, ascentPlan: engine.ascentPlanFor(plan.tanks));
    final longer = synthesizeRemainder(plan: plan, outcome: outcome, startTimestamp: 0, startDepth: 45, ascentPlan: engine.ascentPlanFor(plan.tanks), extraLastStopSeconds: 120);
    expect(longer.timestamps.last - base.timestamps.last, 120);
  });

  test('loop mode emits setpoint segments', () {
    final plan = _plan(tanks: const [back]).copyWith(mode: domain.PlanMode.ccr, setpointLow: 0.7, setpointHigh: 1.3);
    const engine = PlanEngine();
    final outcome = engine.compute(plan);
    final r = synthesizeRemainder(
      plan: plan, outcome: outcome, startTimestamp: 0, startDepth: 45,
      ascentPlan: engine.ascentPlanFor(plan.tanks),
      loop: const LoopSetpoints(low: 0.7, high: 1.3, switchDepth: 10, diluent: GasMix(o2: 21)),
    );
    expect(r.gasSegments.first.setpoint, 1.3);
    expect(r.gasSegments.last.setpoint, 0.7);
  });

  test('splice keeps the actual prefix and appends the remainder once', () {
    final plan = _plan();
    const engine = PlanEngine();
    final outcome = engine.compute(plan);
    final r = synthesizeRemainder(plan: plan, outcome: outcome, startTimestamp: 20, startDepth: 45, ascentPlan: engine.ascentPlanFor(plan.tanks));
    final s = spliceCounterfactual(
      actualTimestamps: const [0, 10, 20, 30, 40],
      actualDepths: const [0, 20, 45, 45, 45],
      actualGasSegments: const [ProfileGasSegment(startTimestamp: 0, fN2: airN2Fraction)],
      branchIndex: 2,
      remainder: r,
    );
    expect(s.timestamps.sublist(0, 3), [0, 10, 20]);
    expect(s.timestamps[3], r.timestamps[1]);
    expect(s.depths.length, s.timestamps.length);
    expect(s.gasSegments.first.startTimestamp, 0);
    for (var i = 1; i < s.timestamps.length; i++) {
      expect(s.timestamps[i], greaterThan(s.timestamps[i - 1]));
    }
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/dive_lab/domain/services/counterfactual_profile_synthesizer_test.dart`
Expected: FAIL, file missing.

- [ ] **Step 3: Write the synthesizer**

```dart
// lib/features/dive_lab/domain/services/counterfactual_profile_synthesizer.dart
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/deco/ascent/ascent_gas_plan.dart';
import 'package:submersion/core/deco/entities/profile_gas_segment.dart';
import 'package:submersion/features/dive_lab/domain/entities/scenario_request.dart';
import 'package:submersion/features/dive_lab/domain/services/tank_schedule.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_segment.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart' as domain;
import 'package:submersion/features/planner/domain/entities/plan_outcome.dart';

/// Loop setpoints for a rebreather remainder: high below [switchDepth], low
/// above, inert gas from [diluent].
class LoopSetpoints {
  const LoopSetpoints({
    required this.low,
    required this.high,
    required this.switchDepth,
    required this.diluent,
  });
  final double low;
  final double high;
  final double switchDepth;
  final GasMix diluent;
}

class SynthesizedRemainder {
  const SynthesizedRemainder({
    required this.timestamps,
    required this.depths,
    required this.gasSegments,
    required this.tankSwitches,
    required this.bottomEndTimestamp,
  });
  final List<int> timestamps;
  final List<double> depths;
  final List<ProfileGasSegment> gasSegments;
  final List<ScenarioGasSwitch> tankSwitches;

  /// Timestamp where the plan's user segments end and the computed ascent
  /// starts (consumption switches from bottom to deco SAC here).
  final int bottomEndTimestamp;
}

class _Builder {
  _Builder(this.plan, this.loop, this.step)
    : tanks = plan.tanks;
  final domain.DivePlan plan;
  final LoopSetpoints? loop;
  final int step;
  final List<DiveTank> tanks;
  final timestamps = <int>[];
  final depths = <double>[];
  final gasSegments = <ProfileGasSegment>[];
  final tankSwitches = <ScenarioGasSwitch>[];
  double? _fN2;
  double? _fHe;
  double? _setpoint;
  String? _tankId;

  int get now => timestamps.last;

  void sample(int t, double d) {
    if (timestamps.isNotEmpty && t <= timestamps.last) return;
    timestamps.add(t);
    depths.add(d);
  }

  void gas({required int t, required double fN2, required double fHe, String? tankId, double? setpoint}) {
    if (_fN2 == fN2 && _fHe == fHe && _setpoint == setpoint) return;
    gasSegments.add(ProfileGasSegment(startTimestamp: t, fN2: fN2, fHe: fHe, setpoint: setpoint));
    _fN2 = fN2;
    _fHe = fHe;
    _setpoint = setpoint;
    if (tankId != null && tankId != _tankId) {
      tankSwitches.add(ScenarioGasSwitch(timestamp: t, tankId: tankId));
      _tankId = tankId;
    }
  }

  /// Gas in force at [depth] on the computed ascent.
  void ascentGasAt(int t, double depth, AscentGasPlan ascentPlan) {
    final l = loop;
    if (l != null) {
      gas(
        t: t,
        fN2: fN2Of(l.diluent),
        fHe: l.diluent.he / 100.0,
        setpoint: depth > l.switchDepth ? l.high : l.low,
      );
      return;
    }
    final g = ascentPlan.gasForDepth(depth);
    final fO2 = 1.0 - g.fN2 - g.fHe;
    gas(t: t, fN2: g.fN2, fHe: g.fHe, tankId: tankIdForMix(tanks, fO2, g.fHe));
  }

  /// Linear leg from the current depth to [toDepth] over [seconds], sampled
  /// every [step] seconds; gas re-evaluated at each sample.
  void leg(double toDepth, int seconds, void Function(int t, double d) gasAt) {
    if (seconds <= 0) return;
    final fromDepth = depths.last;
    final start = now;
    for (var s = step; s < seconds; s += step) {
      final d = fromDepth + (toDepth - fromDepth) * s / seconds;
      sample(start + s, d);
      gasAt(start + s, d);
    }
    sample(start + seconds, toDepth);
    gasAt(start + seconds, toDepth);
  }
}

/// The carried tank whose mix matches [fO2]/[fHe]; deco/stage roles win
/// ties (mirrors PlanEngine's private rule).
String? tankIdForMix(List<DiveTank> tanks, double fO2, double fHe) {
  DiveTank? match;
  for (final tank in tanks) {
    final tankFO2 = tank.gasMix.o2 / 100.0;
    final tankFHe = tank.gasMix.he / 100.0;
    if ((tankFO2 - fO2).abs() < 0.005 && (tankFHe - fHe).abs() < 0.005) {
      final isDeco = tank.role == TankRole.deco || tank.role == TankRole.stage;
      if (match == null ||
          (isDeco && match.role != TankRole.deco && match.role != TankRole.stage)) {
        match = tank;
      }
    }
  }
  return match?.id;
}

/// Samples for the counterfactual remainder: the plan's segments, then the
/// engine's ascent and stops, then the final leg to the surface.
SynthesizedRemainder synthesizeRemainder({
  required domain.DivePlan plan,
  required PlanOutcome outcome,
  required int startTimestamp,
  required double startDepth,
  required AscentGasPlan ascentPlan,
  LoopSetpoints? loop,
  int stepSeconds = 10,
  int extraLastStopSeconds = 0,
}) {
  final b = _Builder(plan, loop, stepSeconds);
  b.sample(startTimestamp, startDepth);

  final segments = List<PlanSegment>.from(plan.segments)
    ..sort((x, y) => x.order.compareTo(y.order));
  void segmentGas(PlanSegment s) => b.gas(
    t: b.now,
    fN2: fN2Of(s.gasMix),
    fHe: s.gasMix.he / 100.0,
    tankId: s.tankId,
    setpoint: loop == null
        ? null
        : (s.avgDepth > loop.switchDepth ? loop.high : loop.low),
  );
  for (final s in segments) {
    segmentGas(s);
    if (s.durationSeconds <= 0) {
      // A zero-duration hold (ascend-now anchor): adopt its depth without
      // advancing time.
      continue;
    }
    b.leg(s.endDepth, s.durationSeconds, (t, d) => segmentGas(s));
  }
  final bottomEnd = b.now;

  var depth = b.depths.last;
  final stops = outcome.stops;
  for (var k = 0; k < stops.length; k++) {
    final stop = stops[k];
    final legSeconds = ((depth - stop.depthMeters) / plan.ascentRate * 60).round();
    b.leg(stop.depthMeters, legSeconds, (t, d) => b.ascentGasAt(t, d, ascentPlan));
    b.ascentGasAt(b.now, stop.depthMeters, ascentPlan);
    final hold = stop.durationSeconds + (k == stops.length - 1 ? extraLastStopSeconds : 0);
    b.leg(stop.depthMeters, hold, (t, d) => b.ascentGasAt(t, d, ascentPlan));
    depth = stop.depthMeters;
  }
  if (depth > 0) {
    final legSeconds = (depth / plan.ascentRate * 60).round();
    b.leg(0.0, legSeconds, (t, d) => b.ascentGasAt(t, d, ascentPlan));
  }
  if (b.depths.last != 0.0) {
    b.sample(b.now + 1, 0.0);
  }
  if (b.gasSegments.isEmpty) {
    b.ascentGasAt(startTimestamp, startDepth, ascentPlan);
  }
  return SynthesizedRemainder(
    timestamps: b.timestamps,
    depths: b.depths,
    gasSegments: b.gasSegments,
    tankSwitches: b.tankSwitches,
    bottomEndTimestamp: bottomEnd,
  );
}

class SplicedProfile {
  const SplicedProfile({required this.timestamps, required this.depths, required this.gasSegments});
  final List<int> timestamps;
  final List<double> depths;
  final List<ProfileGasSegment> gasSegments;
}

/// Actual samples 0..[branchIndex] followed by [remainder] (whose first
/// sample is the branch sample itself and is dropped). Gas segments: the
/// actual ones in force up to the branch, then the remainder's.
SplicedProfile spliceCounterfactual({
  required List<int> actualTimestamps,
  required List<double> actualDepths,
  required List<ProfileGasSegment> actualGasSegments,
  required int branchIndex,
  required SynthesizedRemainder remainder,
}) {
  final branchTs = actualTimestamps[branchIndex];
  final timestamps = <int>[...actualTimestamps.sublist(0, branchIndex + 1)];
  final depths = <double>[...actualDepths.sublist(0, branchIndex + 1)];
  for (var i = 0; i < remainder.timestamps.length; i++) {
    if (remainder.timestamps[i] <= branchTs) continue;
    timestamps.add(remainder.timestamps[i]);
    depths.add(remainder.depths[i]);
  }
  final gas = <ProfileGasSegment>[
    for (final g in actualGasSegments)
      if (g.startTimestamp < branchTs) g,
  ];
  for (final g in remainder.gasSegments) {
    if (gas.isNotEmpty && gas.last.startTimestamp == g.startTimestamp) {
      gas[gas.length - 1] = g;
    } else {
      gas.add(g);
    }
  }
  if (gas.isEmpty || gas.first.startTimestamp > timestamps.first) {
    gas.insert(0, actualGasSegments.isNotEmpty ? actualGasSegments.first : remainder.gasSegments.first);
  }
  return SplicedProfile(timestamps: timestamps, depths: depths, gasSegments: gas);
}
```

Note on the remainder's first gas segment: `segmentGas` is called before the first leg, so `gasSegments.first.startTimestamp == startTimestamp`; the splice keeps actual segments strictly before the branch timestamp and lets the remainder's segment at the branch supersede.

- [ ] **Step 4: Run the test**

Run: `flutter test test/features/dive_lab/domain/services/counterfactual_profile_synthesizer_test.dart`
Expected: PASS. If `timestamps.last - 1500 != 600 + outcome.ttsAtBottom` by a few seconds, the cause is rounding of the per-leg `legSeconds` versus the engine's `ttsSeconds`; accept a tolerance of +/- stops.length seconds in the test and document it.

- [ ] **Step 5: Commit**

```bash
git add lib/features/dive_lab/domain/services/counterfactual_profile_synthesizer.dart test/features/dive_lab/domain/services/counterfactual_profile_synthesizer_test.dart
git commit -m "feat(dive-lab): synthesize and splice the counterfactual remainder"
```

---

### Task 9: Consumption pass

**Files:**
- Create: `lib/features/dive_lab/domain/entities/scenario_consumption.dart`
- Create: `lib/features/dive_lab/domain/services/consumption_pass.dart`
- Test: `test/features/dive_lab/domain/services/consumption_pass_test.dart`

**Interfaces:**
- Produces `class TankConsumption extends Equatable { tankId, startPressureBar (double?), endPressureBar (double?), litersUsed, reserveReachedAtSeconds (int?), emptyAtSeconds (int?), source (PressureSource) }`; `class ScenarioConsumption extends Equatable { actual: List<TankConsumption>, counterfactual: List<TankConsumption>, reservePressureBar }` with `TankConsumption? actualFor(id)`, `counterfactualFor(id)`; `List<TankConsumption> simulateConsumption({required List<int> timestamps, required List<double> depths, required TankSchedule schedule, required Map<String, double?> startPressures, required double Function(int sampleIndex) sacLpmAt, required DiveEnvironment environment, required GasModel gasModel, required double reservePressureBar, int fromIndex = 0, int? toIndex, PressureSource source = PressureSource.estimated})` (for each sample `i` in `(fromIndex, toIndex]`: `liters = sacLpmAt(i) x environment.pressureAtDepth(mean depth of i-1,i) x dt/60` charged to `schedule.tankIdAt(timestamps[i-1])`; per tank `pressureAfterConsuming(volume ?? 11.0, start, liters, o2, he, model)`; `reserveReachedAtSeconds` = first `timestamps[i]` where pressure <= reserve; `emptyAtSeconds` = first where pressure <= 0; unknown start pressure yields `endPressureBar null`, source `unknown`, litres still counted).

- [ ] **Step 1: Write the failing test**

```dart
// test/features/dive_lab/domain/services/consumption_pass_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/gas_model.dart';
import 'package:submersion/core/deco/entities/dive_environment.dart';
import 'package:submersion/features/dive_lab/domain/entities/branch_state.dart';
import 'package:submersion/features/dive_lab/domain/entities/scenario_request.dart';
import 'package:submersion/features/dive_lab/domain/services/consumption_pass.dart';
import 'package:submersion/features/dive_lab/domain/services/tank_schedule.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

const back = DiveTank(id: 'back', volume: 10, startPressure: 200, gasMix: GasMix(o2: 21), role: TankRole.backGas);
const deco = DiveTank(id: 'deco', volume: 10, startPressure: 100, gasMix: GasMix(o2: 50), role: TankRole.deco);

void main() {
  test('ideal gas, constant depth: hand-computed pressure drop', () {
    // 10 min at 30 m (4 bar) at 20 L/min = 800 L; 10 L tank: 80 bar drop.
    final ts = [for (var t = 0; t <= 600; t += 60) t];
    final depths = List.filled(ts.length, 30.0);
    final schedule = TankSchedule.fromDive(tanks: const [back], switches: const []);
    final out = simulateConsumption(
      timestamps: ts, depths: depths, schedule: schedule,
      startPressures: const {'back': 200.0}, sacLpmAt: (_) => 20.0,
      environment: DiveEnvironment.standard, gasModel: GasModel.ideal, reservePressureBar: 50,
    );
    final b = out.single;
    expect(b.litersUsed, closeTo(800, 1e-9));
    expect(b.endPressureBar, closeTo(120, 1e-9));
    expect(b.reserveReachedAtSeconds, isNull);
    expect(b.emptyAtSeconds, isNull);
    expect(b.source, PressureSource.estimated);
  });

  test('reserve and empty instants are the first crossing samples', () {
    // 40 m (5 bar), 30 L/min = 150 L/min = 15 bar/min on a 10 L tank.
    // From 200 bar: reserve 50 after 10 min, empty after 13.33 min.
    final ts = [for (var t = 0; t <= 1200; t += 60) t];
    final depths = List.filled(ts.length, 40.0);
    final schedule = TankSchedule.fromDive(tanks: const [back], switches: const []);
    final out = simulateConsumption(
      timestamps: ts, depths: depths, schedule: schedule,
      startPressures: const {'back': 200.0}, sacLpmAt: (_) => 30.0,
      environment: DiveEnvironment.standard, gasModel: GasModel.ideal, reservePressureBar: 50,
    ).single;
    expect(out.reserveReachedAtSeconds, 600);
    expect(out.emptyAtSeconds, 840);
    expect(out.endPressureBar, 0);
  });

  test('consumption follows the schedule across a switch', () {
    // 0-300 s on back at 30 m, 300-600 s on deco at 30 m, 20 L/min.
    final ts = [for (var t = 0; t <= 600; t += 60) t];
    final depths = List.filled(ts.length, 30.0);
    final schedule = TankSchedule.fromDive(
      tanks: const [back, deco],
      switches: const [ScenarioGasSwitch(timestamp: 300, tankId: 'deco')],
    );
    final out = simulateConsumption(
      timestamps: ts, depths: depths, schedule: schedule,
      startPressures: const {'back': 200.0, 'deco': 100.0}, sacLpmAt: (_) => 20.0,
      environment: DiveEnvironment.standard, gasModel: GasModel.ideal, reservePressureBar: 50,
    );
    final b = out.firstWhere((t) => t.tankId == 'back');
    final d = out.firstWhere((t) => t.tankId == 'deco');
    expect(b.litersUsed, closeTo(400, 1e-9));
    expect(d.litersUsed, closeTo(400, 1e-9));
    expect(b.endPressureBar, closeTo(160, 1e-9));
    expect(d.endPressureBar, closeTo(60, 1e-9));
  });

  test('fromIndex skips earlier samples and an unknown start stays unknown', () {
    final ts = [for (var t = 0; t <= 600; t += 60) t];
    final depths = List.filled(ts.length, 30.0);
    final schedule = TankSchedule.fromDive(tanks: const [back], switches: const []);
    final out = simulateConsumption(
      timestamps: ts, depths: depths, schedule: schedule,
      startPressures: const {'back': null}, sacLpmAt: (_) => 20.0,
      environment: DiveEnvironment.standard, gasModel: GasModel.ideal, reservePressureBar: 50,
      fromIndex: 5,
    ).single;
    expect(out.litersUsed, closeTo(400, 1e-9));
    expect(out.endPressureBar, isNull);
    expect(out.source, PressureSource.unknown);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/dive_lab/domain/services/consumption_pass_test.dart`
Expected: FAIL, files missing.

- [ ] **Step 3: Write the entity and the pass**

```dart
// lib/features/dive_lab/domain/entities/scenario_consumption.dart
import 'package:equatable/equatable.dart';

import 'package:submersion/features/dive_lab/domain/entities/branch_state.dart';

/// One tank's gas over one timeline.
class TankConsumption extends Equatable {
  const TankConsumption({
    required this.tankId,
    required this.startPressureBar,
    required this.endPressureBar,
    required this.litersUsed,
    this.reserveReachedAtSeconds,
    this.emptyAtSeconds,
    required this.source,
  });
  final String tankId;
  final double? startPressureBar;
  final double? endPressureBar;
  final double litersUsed;
  final int? reserveReachedAtSeconds;
  final int? emptyAtSeconds;
  final PressureSource source;
  @override
  List<Object?> get props => [
    tankId, startPressureBar, endPressureBar, litersUsed,
    reserveReachedAtSeconds, emptyAtSeconds, source,
  ];
}

class ScenarioConsumption extends Equatable {
  const ScenarioConsumption({
    required this.actual,
    required this.counterfactual,
    required this.reservePressureBar,
  });
  final List<TankConsumption> actual;
  final List<TankConsumption> counterfactual;
  final double reservePressureBar;

  TankConsumption? actualFor(String tankId) => _find(actual, tankId);
  TankConsumption? counterfactualFor(String tankId) => _find(counterfactual, tankId);

  static TankConsumption? _find(List<TankConsumption> list, String id) {
    for (final t in list) {
      if (t.tankId == id) return t;
    }
    return null;
  }

  @override
  List<Object?> get props => [actual, counterfactual, reservePressureBar];
}
```

```dart
// lib/features/dive_lab/domain/services/consumption_pass.dart
import 'package:submersion/core/constants/gas_model.dart';
import 'package:submersion/core/deco/entities/dive_environment.dart';
import 'package:submersion/core/utils/gas_compressibility.dart';
import 'package:submersion/features/dive_lab/domain/entities/branch_state.dart';
import 'package:submersion/features/dive_lab/domain/entities/scenario_consumption.dart';
import 'package:submersion/features/dive_lab/domain/services/tank_schedule.dart';

/// Tank volume assumed when a tank records none (PlanEngine's convention).
const double kAssumedTankVolumeLiters = 11.0;

/// Per-sample consumption over a timeline: litres per sample = SAC x ambient
/// (mean depth of the interval) x minutes, charged to the tank in force at
/// the interval start; pressures via the configured gas model. Samples
/// `i` in `(fromIndex, toIndex]` are charged.
List<TankConsumption> simulateConsumption({
  required List<int> timestamps,
  required List<double> depths,
  required TankSchedule schedule,
  required Map<String, double?> startPressures,
  required double Function(int sampleIndex) sacLpmAt,
  required DiveEnvironment environment,
  required GasModel gasModel,
  required double reservePressureBar,
  int fromIndex = 0,
  int? toIndex,
  PressureSource source = PressureSource.estimated,
}) {
  final tanks = schedule.tanks;
  final liters = <String, double>{for (final t in tanks) t.id: 0.0};
  final reserveAt = <String, int?>{for (final t in tanks) t.id: null};
  final emptyAt = <String, int?>{for (final t in tanks) t.id: null};
  final last = toIndex ?? timestamps.length - 1;

  double? pressureOf(String tankId) {
    final start = startPressures[tankId];
    if (start == null) return null;
    final tank = schedule.tankById(tankId)!;
    return pressureAfterConsuming(
      tankSizeLiters: tank.volume ?? kAssumedTankVolumeLiters,
      startPressureBar: start,
      litersConsumed: liters[tankId] ?? 0.0,
      o2Percent: tank.gasMix.o2,
      hePercent: tank.gasMix.he,
      model: gasModel,
    );
  }

  for (var i = (fromIndex < 1 ? 1 : fromIndex + 1); i <= last && i < timestamps.length; i++) {
    final dt = timestamps[i] - timestamps[i - 1];
    if (dt <= 0) continue;
    final tankId = schedule.tankIdAt(timestamps[i - 1]);
    if (tankId == null || !liters.containsKey(tankId)) continue;
    final ambient = environment.pressureAtDepth((depths[i] + depths[i - 1]) / 2.0);
    liters[tankId] = liters[tankId]! + sacLpmAt(i) * ambient * dt / 60.0;
    final p = pressureOf(tankId);
    if (p != null) {
      if (reserveAt[tankId] == null && p <= reservePressureBar) {
        reserveAt[tankId] = timestamps[i];
      }
      if (emptyAt[tankId] == null && p <= 0) {
        emptyAt[tankId] = timestamps[i];
      }
    }
  }

  return [
    for (final t in tanks)
      TankConsumption(
        tankId: t.id,
        startPressureBar: startPressures[t.id],
        endPressureBar: pressureOf(t.id),
        litersUsed: liters[t.id] ?? 0.0,
        reserveReachedAtSeconds: reserveAt[t.id],
        emptyAtSeconds: emptyAt[t.id],
        source: startPressures[t.id] == null ? PressureSource.unknown : source,
      ),
  ];
}
```

- [ ] **Step 4: Run the test**

Run: `flutter test test/features/dive_lab/domain/services/consumption_pass_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/dive_lab/domain/entities/scenario_consumption.dart lib/features/dive_lab/domain/services/consumption_pass.dart test/features/dive_lab/domain/services/consumption_pass_test.dart
git commit -m "feat(dive-lab): per-sample consumption pass with reserve and empty instants"
```

---

### Task 10: Deltas and verdict selection

**Files:**
- Create: `lib/features/dive_lab/domain/entities/scenario_delta.dart`
- Create: `lib/features/dive_lab/domain/services/scenario_delta_builder.dart`
- Test: `test/features/dive_lab/domain/services/scenario_delta_builder_test.dart`

**Interfaces:**
- Produces `enum DeltaUnit { seconds, meters, percent, bar, count }`, `enum BetterWhen { lower, higher, neutral }`, `enum DeltaMetric { runtime, ttsAtBranch, decoTimeAfterBranch, deepestStopAfterBranch, surfaceGf, peakGf99AfterBranch, cnsEnd, otuEnd, maxPpO2AfterBranch, tankEndPressure, gasOutTime, minGasMarginAtBranch, ceilingViolations, worstCeilingViolation }` with getters `unit`, `betterWhen`, `significanceScale` (runtime 300 s, ttsAtBranch 120 s, decoTimeAfterBranch 120 s, deepestStopAfterBranch 3 m, surfaceGf 10 %, peakGf99AfterBranch 10 %, cnsEnd 10 %, otuEnd 50, maxPpO2AfterBranch 0.1 bar, tankEndPressure 20 bar, gasOutTime 60 s, minGasMarginAtBranch 20 bar, ceilingViolations 1, worstCeilingViolation 1 m); `class ScenarioDelta extends Equatable { metric, actual (double?), counterfactual (double?), tankId (String?) }` with `double? get delta` (cf minus actual when both present), `double get significance` (|delta| / scale, 0 when null), `BetterWhen get betterWhen`.
- Produces `List<ScenarioDelta> buildDeltas({required ProfileAnalysis actual, required ProfileAnalysis counterfactual, required List<double> actualDepths, required List<double> counterfactualDepths, required List<int> actualTimestamps, required List<int> counterfactualTimestamps, required int branchIndex, required ScenarioConsumption consumption, PlanOutcome? planOutcome, double? branchBackGasPressureBar})` and `List<ScenarioDelta> selectVerdictDeltas(List<ScenarioDelta> deltas, {int count = 3})` (non-zero deltas sorted by significance, descending, first `count`).
- Metric definitions (both timelines unless stated): runtime = `timestamps.last - timestamps.first`; ttsAtBranch = `ttsCurve[branchIndex]`; decoTimeAfterBranch = sum of `dt` over samples `i > branchIndex` where `ndlCurve[i] < 0`; deepestStopAfterBranch = max `decoStopCurve[i]` over `i > branchIndex` with `ndlCurve[i] < 0` (0 when never in deco); surfaceGf = `surfaceGfCurve.last`; peakGf99AfterBranch = max `gfCurve[i]`, `i > branchIndex`; cnsEnd = `cnsCurve.last`; otuEnd = `otuCurve.last`; maxPpO2AfterBranch = max `ppO2Curve[i]`, `i > branchIndex`; tankEndPressure per tank in `consumption.counterfactual` (actual from `consumption.actual`); gasOutTime per tank: counterfactual `emptyAtSeconds` (actual = actual's `emptyAtSeconds`), only when either is non-null; minGasMarginAtBranch = `branchBackGasPressureBar - minGasBar` from the back-gas `PlanTankUsage` when both exist (counterfactual only); ceilingViolations = count of `i > branchIndex` with `depth[i] < ceilingCurve[i] - 0.1`; worstCeilingViolation = max `(ceiling - depth)` over those (0 when none).

- [ ] **Step 1: Write the failing test**

```dart
// test/features/dive_lab/domain/services/scenario_delta_builder_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_lab/domain/entities/branch_state.dart';
import 'package:submersion/features/dive_lab/domain/entities/scenario_consumption.dart';
import 'package:submersion/features/dive_lab/domain/entities/scenario_delta.dart';
import 'package:submersion/features/dive_lab/domain/services/scenario_delta_builder.dart';
import 'package:submersion/features/dive_lab/domain/services/tank_schedule.dart';
import 'package:submersion/features/dive_log/data/services/profile_analysis_service.dart';

import '../support/synthetic_dives.dart';

ProfileAnalysis _analyze(SyntheticDive d, {double gfHigh = 0.70}) =>
    ProfileAnalysisService(gfLow: 0.30, gfHigh: gfHigh).analyze(
      diveId: 'd',
      depths: d.depths,
      timestamps: d.timestamps,
      gasSegments: TankSchedule.fromDive(tanks: d.tanks, switches: d.switches).toGasSegments(),
    );

const _tank = TankConsumption(
  tankId: 'back', startPressureBar: 200, endPressureBar: 80, litersUsed: 2000,
  source: PressureSource.measured,
);

void main() {
  test('identical timelines produce all-zero deltas and an empty verdict', () {
    final d = squareDive();
    final a = _analyze(d);
    final deltas = buildDeltas(
      actual: a, counterfactual: a,
      actualDepths: d.depths, counterfactualDepths: d.depths,
      actualTimestamps: d.timestamps, counterfactualTimestamps: d.timestamps,
      branchIndex: d.indexAt(900),
      consumption: const ScenarioConsumption(actual: [_tank], counterfactual: [_tank], reservePressureBar: 50),
    );
    expect(deltas.where((x) => x.delta != null).every((x) => x.delta!.abs() < 1e-9), isTrue);
    expect(selectVerdictDeltas(deltas), isEmpty);
    expect(deltas.map((x) => x.metric), contains(DeltaMetric.runtime));
    expect(deltas.map((x) => x.metric), contains(DeltaMetric.surfaceGf));
    expect(deltas.firstWhere((x) => x.metric == DeltaMetric.tankEndPressure).tankId, 'back');
  });

  test('a longer dive at a higher GF shows the expected signs', () {
    final d = squareDive(bottomMinutes: 25);
    final longer = squareDive(bottomMinutes: 35);
    final a = _analyze(d);
    final c = _analyze(longer, gfHigh: 0.90);
    final deltas = buildDeltas(
      actual: a, counterfactual: c,
      actualDepths: d.depths, counterfactualDepths: longer.depths,
      actualTimestamps: d.timestamps, counterfactualTimestamps: longer.timestamps,
      branchIndex: d.indexAt(900),
      consumption: const ScenarioConsumption(
        actual: [_tank],
        counterfactual: [
          TankConsumption(tankId: 'back', startPressureBar: 200, endPressureBar: 40, litersUsed: 3000, emptyAtSeconds: null, source: PressureSource.estimated),
        ],
        reservePressureBar: 50,
      ),
    );
    double delta(DeltaMetric m) => deltas.firstWhere((x) => x.metric == m).delta!;
    expect(delta(DeltaMetric.runtime), 600);
    expect(delta(DeltaMetric.surfaceGf), greaterThan(0));
    expect(delta(DeltaMetric.cnsEnd), greaterThan(0));
    expect(delta(DeltaMetric.tankEndPressure), -40);
    final verdict = selectVerdictDeltas(deltas);
    expect(verdict, hasLength(3));
    expect(verdict.first.significance, greaterThanOrEqualTo(verdict.last.significance));
  });

  test('gas-out and min-gas rows appear only when they exist', () {
    final d = squareDive();
    final a = _analyze(d);
    final none = buildDeltas(
      actual: a, counterfactual: a,
      actualDepths: d.depths, counterfactualDepths: d.depths,
      actualTimestamps: d.timestamps, counterfactualTimestamps: d.timestamps,
      branchIndex: 10,
      consumption: const ScenarioConsumption(actual: [_tank], counterfactual: [_tank], reservePressureBar: 50),
    );
    expect(none.any((x) => x.metric == DeltaMetric.gasOutTime), isFalse);
    expect(none.any((x) => x.metric == DeltaMetric.minGasMarginAtBranch), isFalse);
    final out = buildDeltas(
      actual: a, counterfactual: a,
      actualDepths: d.depths, counterfactualDepths: d.depths,
      actualTimestamps: d.timestamps, counterfactualTimestamps: d.timestamps,
      branchIndex: 10,
      consumption: const ScenarioConsumption(
        actual: [_tank],
        counterfactual: [TankConsumption(tankId: 'back', startPressureBar: 200, endPressureBar: 0, litersUsed: 9000, emptyAtSeconds: 2400, source: PressureSource.estimated)],
        reservePressureBar: 50,
      ),
    );
    final go = out.firstWhere((x) => x.metric == DeltaMetric.gasOutTime);
    expect(go.counterfactual, 2400);
    expect(go.actual, isNull);
    expect(go.tankId, 'back');
  });

  test('ceiling violations count samples below the ceiling after the branch', () {
    // Counterfactual: same depths but ceilings forced 5 m deeper than depth on 4 samples.
    final d = squareDive();
    final a = _analyze(d);
    final ceilings = List<double>.from(a.ceilingCurve);
    final i0 = d.indexAt(900);
    for (var k = 1; k <= 4; k++) {
      ceilings[i0 + k] = d.depths[i0 + k] + 5;
    }
    final c = a.copyWith(ceilingCurve: ceilings);
    final deltas = buildDeltas(
      actual: a, counterfactual: c,
      actualDepths: d.depths, counterfactualDepths: d.depths,
      actualTimestamps: d.timestamps, counterfactualTimestamps: d.timestamps,
      branchIndex: i0,
      consumption: const ScenarioConsumption(actual: [], counterfactual: [], reservePressureBar: 50),
    );
    expect(deltas.firstWhere((x) => x.metric == DeltaMetric.ceilingViolations).counterfactual, 4);
    expect(deltas.firstWhere((x) => x.metric == DeltaMetric.worstCeilingViolation).counterfactual, closeTo(5, 1e-9));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/dive_lab/domain/services/scenario_delta_builder_test.dart`
Expected: FAIL, files missing.

- [ ] **Step 3: Write the entity and builder**

```dart
// lib/features/dive_lab/domain/entities/scenario_delta.dart
import 'package:equatable/equatable.dart';

enum DeltaUnit { seconds, meters, percent, bar, count }

enum BetterWhen { lower, higher, neutral }

enum DeltaMetric {
  runtime(DeltaUnit.seconds, BetterWhen.neutral, 300),
  ttsAtBranch(DeltaUnit.seconds, BetterWhen.lower, 120),
  decoTimeAfterBranch(DeltaUnit.seconds, BetterWhen.lower, 120),
  deepestStopAfterBranch(DeltaUnit.meters, BetterWhen.lower, 3),
  surfaceGf(DeltaUnit.percent, BetterWhen.lower, 10),
  peakGf99AfterBranch(DeltaUnit.percent, BetterWhen.lower, 10),
  cnsEnd(DeltaUnit.percent, BetterWhen.lower, 10),
  otuEnd(DeltaUnit.count, BetterWhen.lower, 50),
  maxPpO2AfterBranch(DeltaUnit.bar, BetterWhen.lower, 0.1),
  tankEndPressure(DeltaUnit.bar, BetterWhen.higher, 20),
  gasOutTime(DeltaUnit.seconds, BetterWhen.neutral, 60),
  minGasMarginAtBranch(DeltaUnit.bar, BetterWhen.higher, 20),
  ceilingViolations(DeltaUnit.count, BetterWhen.lower, 1),
  worstCeilingViolation(DeltaUnit.meters, BetterWhen.lower, 1);

  const DeltaMetric(this.unit, this.betterWhen, this.significanceScale);
  final DeltaUnit unit;
  final BetterWhen betterWhen;

  /// A delta of this size is "one unit of significance" for verdict ranking.
  final double significanceScale;
}

/// One actual-vs-counterfactual comparison.
class ScenarioDelta extends Equatable {
  const ScenarioDelta({
    required this.metric,
    required this.actual,
    required this.counterfactual,
    this.tankId,
  });
  final DeltaMetric metric;
  final double? actual;
  final double? counterfactual;
  final String? tankId;

  double? get delta =>
      actual != null && counterfactual != null ? counterfactual! - actual! : null;

  double get significance =>
      delta == null ? 0.0 : delta!.abs() / metric.significanceScale;

  BetterWhen get betterWhen => metric.betterWhen;

  @override
  List<Object?> get props => [metric, actual, counterfactual, tankId];
}
```

```dart
// lib/features/dive_lab/domain/services/scenario_delta_builder.dart
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_lab/domain/entities/scenario_consumption.dart';
import 'package:submersion/features/dive_lab/domain/entities/scenario_delta.dart';
import 'package:submersion/features/dive_log/data/services/profile_analysis_service.dart';
import 'package:submersion/features/planner/domain/entities/plan_outcome.dart';

double? _last(List<double>? curve) =>
    curve == null || curve.isEmpty ? null : curve.last;

double? _at(List<num>? curve, int i) =>
    curve == null || i < 0 || i >= curve.length ? null : curve[i].toDouble();

double? _maxAfter(List<double>? curve, int branchIndex) {
  if (curve == null || curve.length <= branchIndex + 1) return null;
  var m = double.negativeInfinity;
  for (var i = branchIndex + 1; i < curve.length; i++) {
    if (curve[i] > m) m = curve[i];
  }
  return m;
}

double _decoTimeAfter(ProfileAnalysis a, List<int> timestamps, int branchIndex) {
  var total = 0.0;
  for (var i = branchIndex + 1; i < a.ndlCurve.length && i < timestamps.length; i++) {
    if (a.ndlCurve[i] < 0) total += timestamps[i] - timestamps[i - 1];
  }
  return total;
}

double _deepestStopAfter(ProfileAnalysis a, int branchIndex) {
  var deepest = 0.0;
  for (var i = branchIndex + 1; i < a.ndlCurve.length && i < a.decoStopCurve.length; i++) {
    if (a.ndlCurve[i] < 0 && a.decoStopCurve[i] > deepest) deepest = a.decoStopCurve[i];
  }
  return deepest;
}

(int count, double worst) _violations(ProfileAnalysis a, List<double> depths, int branchIndex) {
  var count = 0;
  var worst = 0.0;
  for (var i = branchIndex + 1; i < a.ceilingCurve.length && i < depths.length; i++) {
    final excess = a.ceilingCurve[i] - depths[i];
    if (excess > 0.1) {
      count++;
      if (excess > worst) worst = excess;
    }
  }
  return (count, worst);
}

/// Every like-for-like comparison the delta panel shows. Entries whose
/// inputs do not exist on either side are omitted (gas-out, min gas).
List<ScenarioDelta> buildDeltas({
  required ProfileAnalysis actual,
  required ProfileAnalysis counterfactual,
  required List<double> actualDepths,
  required List<double> counterfactualDepths,
  required List<int> actualTimestamps,
  required List<int> counterfactualTimestamps,
  required int branchIndex,
  required ScenarioConsumption consumption,
  PlanOutcome? planOutcome,
  double? branchBackGasPressureBar,
}) {
  final deltas = <ScenarioDelta>[];
  void add(DeltaMetric m, double? a, double? c, {String? tankId}) =>
      deltas.add(ScenarioDelta(metric: m, actual: a, counterfactual: c, tankId: tankId));

  add(
    DeltaMetric.runtime,
    (actualTimestamps.last - actualTimestamps.first).toDouble(),
    (counterfactualTimestamps.last - counterfactualTimestamps.first).toDouble(),
  );
  add(DeltaMetric.ttsAtBranch, _at(actual.ttsCurve, branchIndex), _at(counterfactual.ttsCurve, branchIndex));
  add(
    DeltaMetric.decoTimeAfterBranch,
    _decoTimeAfter(actual, actualTimestamps, branchIndex),
    _decoTimeAfter(counterfactual, counterfactualTimestamps, branchIndex),
  );
  add(DeltaMetric.deepestStopAfterBranch, _deepestStopAfter(actual, branchIndex), _deepestStopAfter(counterfactual, branchIndex));
  add(DeltaMetric.surfaceGf, _last(actual.surfaceGfCurve), _last(counterfactual.surfaceGfCurve));
  add(DeltaMetric.peakGf99AfterBranch, _maxAfter(actual.gfCurve, branchIndex), _maxAfter(counterfactual.gfCurve, branchIndex));
  add(DeltaMetric.cnsEnd, _last(actual.cnsCurve), _last(counterfactual.cnsCurve));
  add(DeltaMetric.otuEnd, _last(actual.otuCurve), _last(counterfactual.otuCurve));
  add(DeltaMetric.maxPpO2AfterBranch, _maxAfter(actual.ppO2Curve, branchIndex), _maxAfter(counterfactual.ppO2Curve, branchIndex));

  for (final c in consumption.counterfactual) {
    final a = consumption.actualFor(c.tankId);
    add(DeltaMetric.tankEndPressure, a?.endPressureBar, c.endPressureBar, tankId: c.tankId);
    if (c.emptyAtSeconds != null || a?.emptyAtSeconds != null) {
      add(DeltaMetric.gasOutTime, a?.emptyAtSeconds?.toDouble(), c.emptyAtSeconds?.toDouble(), tankId: c.tankId);
    }
  }

  if (planOutcome != null && branchBackGasPressureBar != null) {
    for (final u in planOutcome.tankUsages) {
      final minGas = u.minGasBar;
      if (minGas != null) {
        add(DeltaMetric.minGasMarginAtBranch, null, branchBackGasPressureBar - minGas, tankId: u.tankId);
        break;
      }
    }
  }

  final av = _violations(actual, actualDepths, branchIndex);
  final cv = _violations(counterfactual, counterfactualDepths, branchIndex);
  add(DeltaMetric.ceilingViolations, av.$1.toDouble(), cv.$1.toDouble());
  add(DeltaMetric.worstCeilingViolation, av.$2, cv.$2);
  return deltas;
}

/// The leading non-zero deltas by significance, for the verdict sentence.
List<ScenarioDelta> selectVerdictDeltas(List<ScenarioDelta> deltas, {int count = 3}) {
  final ranked = deltas.where((d) => d.delta != null && d.delta!.abs() > 1e-9).toList()
    ..sort((a, b) => b.significance.compareTo(a.significance));
  return ranked.take(count).toList();
}
```

(The `enums.dart` import is unused if nothing references it; drop it to keep analyze clean.)

- [ ] **Step 4: Run the test**

Run: `flutter test test/features/dive_lab/domain/services/scenario_delta_builder_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/dive_lab/domain/entities/scenario_delta.dart lib/features/dive_lab/domain/services/scenario_delta_builder.dart test/features/dive_lab/domain/services/scenario_delta_builder_test.dart
git commit -m "feat(dive-lab): actual-vs-counterfactual deltas and verdict ranking"
```

---

### Task 11: ScenarioEngine (replay + re-plan) and invariants

**Files:**
- Create: `lib/features/dive_lab/domain/entities/scenario_outcome.dart`
- Create: `lib/features/dive_lab/domain/services/scenario_engine.dart`
- Test: `test/features/dive_lab/domain/services/scenario_engine_test.dart`

**Interfaces:**
- Produces `enum ScenarioFlagKind { sacEstimated, pressureEstimated, pressureUnknown, tankVolumeAssumed, noBottomRemaining, replanNotCompletable, loopGasMissing }`, `class ScenarioFlag extends Equatable { kind, tankId? }`, `class ScenarioOutcome { branch, mode (effective ScenarioMode), actual, counterfactual, counterfactualDepths, counterfactualTimestamps, counterfactualGasSegments, planOutcome?, compiledPlan (DivePlan?), consumption, deltas, verdictDeltas, flags }`.
- Produces `class ScenarioEngine { const ScenarioEngine(); ScenarioOutcome run(ScenarioRequest request); }` and top-level `ScenarioOutcome runScenarioEngine(ScenarioRequest request)` (the `compute()` entry point; a plain function so it can cross an isolate).
- Pipeline (`run`):
  1. `settings = request.settings`, replaced by `withGf` when a `ChangeGfIntervention` is present; `service = settings.buildAnalysisService()`.
  2. `schedule = TankSchedule.fromDive(tanks: request.tanks, switches: request.gasSwitches, originTimestamp: request.timestamps.first)`; for OC `actualGas = schedule.toGasSegments()` and `ascentPlan = OptimalOcAscentGas(gases: availableGases(request.tanks, settings.ppO2Deco), maxPpO2: settings.ppO2Deco)` (or `FixedAscentGas(fN2: 0.7902)` when no tanks); for CCR/SCR `actualGas = request.loopGasSegments` (null -> flag `loopGasMissing` and fall back to OC segments), `ascentPlan = null`.
  3. `actual = service.analyze(diveId, depths, timestamps, o2Fraction/heFraction of the primary tank, startCns, diveMode, setpointHigh/Low, startCompartments, startOtu, gasSegments: actualGas, ascentGasPlan, rebreatherPpO2Curve)`.
  4. `branchIndex = branchIndexFor(timestamps, scenario.branchSeconds)`; `branch = buildBranchState(...)`; flags from `branch.sacSource != measured` (sacEstimated), per-tank `pressureSourceFor` (pressureEstimated / pressureUnknown), tanks with null volume used by the schedule (tankVolumeAssumed).
  5. Replay: `cfSchedule = rewriteScheduleForReplay(...)`; `cfGas = OC ? cfSchedule.toGasSegments() : actualGas`; `cfAscent = OC ? optimal plan over cfSchedule.tanks : null`; `counterfactual = service.analyze(same as 3 with cfGas/cfAscent)`; `cfDepths/cfTimestamps = request's`; consumption: actual = `simulateConsumption` from index 0 with start pressures = tank start pressures (source estimated; tanks with an `endPressure` report it as `endPressureBar` with source measured), counterfactual = `simulateConsumption(fromIndex: branchIndex, startPressures: branch pressures, schedule: cfSchedule, sacLpmAt: (_) => branch.sac x multiplier)` where multiplier = `2.5 x (buddyFactor ?? settings.buddyFactor)` for shareGas, `2.5` for bailOut, else 1; a measured series gives the actual side its measured end pressure.
  6. Re-plan: `bottomEnd = finalAscentStartIndex(depths, timestamps, ndlCurve: actual.ndlCurve, decoStopCurve: actual.decoStopCurve)`; `forcedTankId = forcedTankIdFor(...)`; `remaining = compileRemainingBottom(... forcedTankId, shiftSeconds from ShiftAscentIntervention, ascendNow: scenario.abortsAtBranch || any AscendNowIntervention)`; `compiled = compileScenarioPlan(...)`; `engine = PlanEngine(config: settings.engineConfig)`; `planOutcome = engine.compute(compiled.plan, startState: branch.tissueState)`; `remainder = synthesizeRemainder(plan, planOutcome, startTimestamp: branch.runtimeSeconds, startDepth: branch.depthMeters, ascentPlan: engine.ascentPlanFor(plan.tanks), loop: plan.mode is ccr/scr ? LoopSetpoints(low: plan.effectiveSetpointLow, high: plan.effectiveSetpointHigh, switchDepth: plan.effectiveSetpointSwitchDepth, diluent: last segment mix) : null, extraLastStopSeconds: compiled.extraLastStopSeconds)`; `spliced = spliceCounterfactual(...)`; `counterfactual = service.analyze(spliced depths/timestamps/gas, same seeds; rebreatherPpO2Curve = actual curve up to branch + setpoint-derived after, or null for OC)`; consumption: counterfactual = `simulateConsumption` over the spliced profile from `branchIndex` with a schedule `TankSchedule.fromDive(tanks: plan.tanks, switches: remainder.tankSwitches, originTimestamp: branch.runtimeSeconds)` preceded by the actual schedule up to the branch (build as `cfSchedule = actualSchedule intervals before T + remainder switches`, tanks = plan.tanks), `sacLpmAt: (i) => timestamps[i] <= remainder.bottomEndTimestamp ? plan.sacBottom : plan.sacDecoEffective`; flag `replanNotCompletable` when `!planOutcome.isDiveable`; flag `noBottomRemaining` when `bottomEnd == null || bottomEnd <= branchIndex`.
  7. `deltas = buildDeltas(...)` with `branchBackGasPressureBar = branch.pressureFor(back gas id)`; `verdictDeltas = selectVerdictDeltas(deltas)`.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/dive_lab/domain/services/scenario_engine_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_lab/domain/entities/branch_state.dart';
import 'package:submersion/features/dive_lab/domain/entities/dive_scenario.dart';
import 'package:submersion/features/dive_lab/domain/entities/scenario_delta.dart';
import 'package:submersion/features/dive_lab/domain/entities/scenario_intervention.dart';
import 'package:submersion/features/dive_lab/domain/entities/scenario_mode.dart';
import 'package:submersion/features/dive_lab/domain/entities/scenario_outcome.dart';
import 'package:submersion/features/dive_lab/domain/entities/scenario_request.dart';
import 'package:submersion/features/dive_lab/domain/entities/scenario_settings.dart';
import 'package:submersion/features/dive_lab/domain/services/scenario_engine.dart';

import '../support/synthetic_dives.dart';

ScenarioRequest _request(
  SyntheticDive dive, {
  required int branchSeconds,
  ScenarioMode mode = ScenarioMode.replay,
  List<ScenarioIntervention> interventions = const [],
  ScenarioSettings settings = const ScenarioSettings(),
}) => ScenarioRequest(
  diveId: 'd',
  depths: dive.depths,
  timestamps: dive.timestamps,
  diveMode: DiveMode.oc,
  tanks: dive.tanks,
  gasSwitches: dive.switches,
  tankPressures: dive.tankPressures,
  settings: settings,
  scenario: DiveScenario(
    id: 's',
    diveId: 'd',
    name: 'n',
    branchSeconds: branchSeconds,
    mode: mode,
    interventions: interventions,
    createdAt: DateTime(2026, 8, 21),
    updatedAt: DateTime(2026, 8, 21),
  ),
);

ScenarioOutcome _run(ScenarioRequest r) => const ScenarioEngine().run(r);

void main() {
  final dive = squareDive(depth: 45, bottomMinutes: 30); // goes into deco at 30/70
  final branchT = 900; // mid-bottom
  final bottomEndT = dive.timestamps[dive.bottomEndIndex];

  group('replay', () {
    test('identity: no interventions reproduces the actual analysis exactly', () {
      final o = _run(_request(dive, branchSeconds: branchT));
      expect(o.mode, ScenarioMode.replay);
      expect(o.counterfactual.ceilingCurve, o.actual.ceilingCurve);
      expect(o.counterfactual.gfCurve, o.actual.gfCurve);
      expect(o.counterfactual.cnsCurve, o.actual.cnsCurve);
      expect(o.counterfactual.ttsCurve, o.actual.ttsCurve);
      expect(o.counterfactualTimestamps, dive.timestamps);
      expect(o.deltas.where((d) => d.delta != null).every((d) => d.delta!.abs() < 1e-9), isTrue);
    });

    test('changeGf: tissues identical everywhere, ceilings differ after deco begins', () {
      final o = _run(_request(
        dive,
        branchSeconds: branchT,
        interventions: const [ChangeGfIntervention(gfLow: 20, gfHigh: 60)],
      ));
      expect(o.counterfactual.gfCurve, o.actual.gfCurve);
      expect(o.counterfactual.surfaceGfCurve, o.actual.surfaceGfCurve);
      expect(o.counterfactual.ceilingCurve, isNot(o.actual.ceilingCurve));
      // Lower GF: deeper ceilings, so more violations on the same path.
      final v = o.deltas.firstWhere((d) => d.metric == DeltaMetric.ceilingViolations);
      expect(v.counterfactual!, greaterThanOrEqualTo(v.actual!));
    });

    test('switchGas at the branch changes CNS after T but nothing before', () {
      final o = _run(_request(
        dive,
        branchSeconds: bottomEndT, // switch to 50% at 45 m: a ppO2 answer, not advice
        interventions: const [SwitchGasIntervention(tank: ExistingTankRef('deco50'))],
      ));
      final i = o.branch.index;
      expect(o.counterfactual.cnsCurve!.sublist(0, i + 1), o.actual.cnsCurve!.sublist(0, i + 1));
      expect(o.counterfactual.cnsCurve!.last, greaterThan(o.actual.cnsCurve!.last));
      final pp = o.deltas.firstWhere((d) => d.metric == DeltaMetric.maxPpO2AfterBranch);
      expect(pp.counterfactual!, greaterThan(2.0));
    });

    test('shareGas: back gas ends lower and may run out', () {
      final base = _run(_request(dive, branchSeconds: branchT));
      final o = _run(_request(
        dive,
        branchSeconds: branchT,
        interventions: const [ShareGasIntervention()],
      ));
      final baseEnd = base.consumption.counterfactualFor('back')!.endPressureBar!;
      final shared = o.consumption.counterfactualFor('back')!;
      expect(shared.endPressureBar!, lessThan(baseEnd));
      expect(shared.source, PressureSource.estimated);
    });
  });

  group('re-plan', () {
    test('continuity: tissue curves equal the actual at the branch; prefix identical', () {
      final o = _run(_request(dive, branchSeconds: branchT, mode: ScenarioMode.replan));
      expect(o.mode, ScenarioMode.replan);
      final i = o.branch.index;
      expect(o.counterfactualTimestamps.sublist(0, i + 1), dive.timestamps.sublist(0, i + 1));
      expect(o.counterfactual.gfCurve!.sublist(0, i + 1), o.actual.gfCurve!.sublist(0, i + 1));
      expect(o.counterfactual.ceilingCurve.sublist(0, i + 1), o.actual.ceilingCurve.sublist(0, i + 1));
      expect(o.counterfactual.decoStatuses[i].compartments, o.actual.decoStatuses[i].compartments);
      expect(o.planOutcome, isNotNull);
      expect(o.counterfactualDepths.last, 0);
      for (var k = 1; k < o.counterfactualTimestamps.length; k++) {
        expect(o.counterfactualTimestamps[k], greaterThan(o.counterfactualTimestamps[k - 1]));
      }
    });

    test('ascendNow from mid-bottom ends sooner than the actual dive', () {
      final o = _run(_request(
        dive,
        branchSeconds: branchT,
        interventions: const [AscendNowIntervention()],
      ));
      final runtime = o.deltas.firstWhere((d) => d.metric == DeltaMetric.runtime);
      expect(runtime.delta!, lessThan(0));
      expect(o.flags.any((f) => f.kind == ScenarioFlagKind.noBottomRemaining), isFalse);
    });

    test('loseTank never shortens deco; earlier ascent never lengthens it', () {
      final base = _run(_request(dive, branchSeconds: branchT, mode: ScenarioMode.replan));
      final lost = _run(_request(
        dive,
        branchSeconds: branchT,
        mode: ScenarioMode.replan,
        interventions: const [LoseTankIntervention(tankId: 'deco50')],
      ));
      expect(lost.planOutcome!.totalDecoSeconds, greaterThanOrEqualTo(base.planOutcome!.totalDecoSeconds));
      final earlier = _run(_request(
        dive,
        branchSeconds: branchT,
        interventions: const [ShiftAscentIntervention(deltaSeconds: -300)],
      ));
      expect(earlier.planOutcome!.totalDecoSeconds, lessThanOrEqualTo(base.planOutcome!.totalDecoSeconds));
      expect(earlier.planOutcome!.runtimeSeconds, lessThan(base.planOutcome!.runtimeSeconds));
    });

    test('raising GF-high never raises TTS', () {
      final base = _run(_request(dive, branchSeconds: branchT, mode: ScenarioMode.replan));
      final looser = _run(_request(
        dive,
        branchSeconds: branchT,
        mode: ScenarioMode.replan,
        interventions: const [ChangeGfIntervention(gfLow: 30, gfHigh: 90)],
      ));
      expect(looser.planOutcome!.ttsAtBottom, lessThanOrEqualTo(base.planOutcome!.ttsAtBottom));
      expect(looser.planOutcome!.totalDecoSeconds, lessThanOrEqualTo(base.planOutcome!.totalDecoSeconds));
    });

    test('branch during the ascent flags no bottom remaining and still completes', () {
      final o = _run(_request(
        dive,
        branchSeconds: bottomEndT + 120,
        mode: ScenarioMode.replan,
      ));
      expect(o.flags.any((f) => f.kind == ScenarioFlagKind.noBottomRemaining), isTrue);
      expect(o.counterfactualDepths.last, 0);
      expect(o.planOutcome, isNotNull);
    });

    test('consumption after the branch follows the plan tanks and SAC', () {
      final o = _run(_request(dive, branchSeconds: branchT, mode: ScenarioMode.replan));
      final back = o.consumption.counterfactualFor('back')!;
      expect(back.startPressureBar, closeTo(o.branch.pressureFor('back')!, 1e-9));
      expect(back.endPressureBar!, lessThan(back.startPressureBar!));
      expect(o.consumption.counterfactualFor('deco50'), isNotNull);
    });
  });

  test('runScenarioEngine is the top-level compute entry', () {
    final o = runScenarioEngine(_request(dive, branchSeconds: branchT));
    expect(o.actual.decoStatuses, isNotEmpty);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/dive_lab/domain/services/scenario_engine_test.dart`
Expected: FAIL, files missing.

- [ ] **Step 3: Write the outcome entity and the engine**

```dart
// lib/features/dive_lab/domain/entities/scenario_outcome.dart
import 'package:equatable/equatable.dart';

import 'package:submersion/core/deco/entities/profile_gas_segment.dart';
import 'package:submersion/features/dive_lab/domain/entities/branch_state.dart';
import 'package:submersion/features/dive_lab/domain/entities/scenario_consumption.dart';
import 'package:submersion/features/dive_lab/domain/entities/scenario_delta.dart';
import 'package:submersion/features/dive_lab/domain/entities/scenario_mode.dart';
import 'package:submersion/features/dive_log/data/services/profile_analysis_service.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart' as domain;
import 'package:submersion/features/planner/domain/entities/plan_outcome.dart';

enum ScenarioFlagKind {
  sacEstimated,
  pressureEstimated,
  pressureUnknown,
  tankVolumeAssumed,
  noBottomRemaining,
  replanNotCompletable,
  loopGasMissing,
}

class ScenarioFlag extends Equatable {
  const ScenarioFlag(this.kind, {this.tankId});
  final ScenarioFlagKind kind;
  final String? tankId;
  @override
  List<Object?> get props => [kind, tankId];
}

/// Everything the engine computed for one scenario.
class ScenarioOutcome {
  const ScenarioOutcome({
    required this.branch,
    required this.mode,
    required this.actual,
    required this.counterfactual,
    required this.counterfactualDepths,
    required this.counterfactualTimestamps,
    required this.counterfactualGasSegments,
    required this.planOutcome,
    required this.compiledPlan,
    required this.consumption,
    required this.deltas,
    required this.verdictDeltas,
    required this.flags,
  });

  final BranchState branch;
  final ScenarioMode mode;
  final ProfileAnalysis actual;
  final ProfileAnalysis counterfactual;
  final List<double> counterfactualDepths;
  final List<int> counterfactualTimestamps;
  final List<ProfileGasSegment> counterfactualGasSegments;
  final PlanOutcome? planOutcome;
  final domain.DivePlan? compiledPlan;
  final ScenarioConsumption consumption;
  final List<ScenarioDelta> deltas;
  final List<ScenarioDelta> verdictDeltas;
  final List<ScenarioFlag> flags;
}
```

```dart
// lib/features/dive_lab/domain/services/scenario_engine.dart
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/deco/ascent/ascent_gas_plan.dart';
import 'package:submersion/core/deco/entities/profile_gas_segment.dart';
import 'package:submersion/core/deco/o2_toxicity_calculator.dart';
import 'package:submersion/features/dive_lab/domain/entities/branch_state.dart';
import 'package:submersion/features/dive_lab/domain/entities/scenario_consumption.dart';
import 'package:submersion/features/dive_lab/domain/entities/scenario_intervention.dart';
import 'package:submersion/features/dive_lab/domain/entities/scenario_mode.dart';
import 'package:submersion/features/dive_lab/domain/entities/scenario_outcome.dart';
import 'package:submersion/features/dive_lab/domain/entities/scenario_request.dart';
import 'package:submersion/features/dive_lab/domain/entities/scenario_settings.dart';
import 'package:submersion/features/dive_lab/domain/services/branch_state_builder.dart';
import 'package:submersion/features/dive_lab/domain/services/consumption_pass.dart';
import 'package:submersion/features/dive_lab/domain/services/counterfactual_profile_synthesizer.dart';
import 'package:submersion/features/dive_lab/domain/services/remaining_bottom_compiler.dart';
import 'package:submersion/features/dive_lab/domain/services/replay_schedule_rewriter.dart';
import 'package:submersion/features/dive_lab/domain/services/scenario_delta_builder.dart';
import 'package:submersion/features/dive_lab/domain/services/scenario_plan_compiler.dart';
import 'package:submersion/features/dive_lab/domain/services/tank_schedule.dart';
import 'package:submersion/features/dive_log/data/services/profile_analysis_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart' as domain;
import 'package:submersion/features/planner/domain/services/plan_engine.dart';

/// Top-level entry for `compute()`: a plain function crosses the isolate
/// boundary where a method tear-off would not.
ScenarioOutcome runScenarioEngine(ScenarioRequest request) =>
    const ScenarioEngine().run(request);

/// Replay and re-plan pipelines from the spec, composed from
/// ProfileAnalysisService (both timelines) and PlanEngine (re-plan).
class ScenarioEngine {
  const ScenarioEngine();

  ScenarioOutcome run(ScenarioRequest request) {
    final scenario = request.scenario;
    final interventions = scenario.interventions;
    var settings = request.settings;
    for (final i in interventions) {
      if (i is ChangeGfIntervention) {
        settings = settings.withGf(low: i.gfLow, high: i.gfHigh);
      }
    }
    final service = settings.buildAnalysisService();
    final flags = <ScenarioFlag>[];
    final isOc = request.diveMode == DiveMode.oc;

    final schedule = TankSchedule.fromDive(
      tanks: request.tanks,
      switches: request.gasSwitches,
      originTimestamp: request.timestamps.first,
    );
    List<ProfileGasSegment> actualGas;
    if (isOc) {
      actualGas = schedule.toGasSegments();
    } else {
      final loop = request.loopGasSegments;
      if (loop == null || loop.isEmpty) {
        flags.add(const ScenarioFlag(ScenarioFlagKind.loopGasMissing));
        actualGas = schedule.toGasSegments();
      } else {
        actualGas = loop;
      }
    }
    final primary = schedule.tankAt(request.timestamps.first)?.gasMix ?? const GasMix();

    ProfileAnalysis analyze({
      required List<double> depths,
      required List<int> timestamps,
      required List<ProfileGasSegment> gas,
      required AscentGasPlan? ascent,
      List<double>? rebreatherPpO2Curve,
    }) => service.analyze(
      diveId: request.diveId,
      depths: depths,
      timestamps: timestamps,
      o2Fraction: primary.o2 / 100.0,
      heFraction: primary.he / 100.0,
      startCns: request.startCns,
      diveMode: request.diveMode,
      setpointHigh: request.setpointHigh,
      setpointLow: request.setpointLow,
      startCompartments: request.startCompartments,
      startOtu: request.startOtu,
      gasSegments: gas,
      ascentGasPlan: ascent,
      rebreatherPpO2Curve: rebreatherPpO2Curve,
    );

    final actual = analyze(
      depths: request.depths,
      timestamps: request.timestamps,
      gas: actualGas,
      ascent: isOc ? _ascentPlan(request.tanks, settings) : null,
      rebreatherPpO2Curve: request.rebreatherPpO2Curve,
    );

    final branchIndex = branchIndexFor(request.timestamps, scenario.branchSeconds);
    final branch = buildBranchState(
      request: request,
      actual: actual,
      schedule: schedule,
      branchIndex: branchIndex,
    );
    if (branch.sacSource != SacSource.measured) {
      flags.add(const ScenarioFlag(ScenarioFlagKind.sacEstimated));
    }
    for (final p in branch.tankPressures) {
      if (p.source == PressureSource.estimated) {
        flags.add(ScenarioFlag(ScenarioFlagKind.pressureEstimated, tankId: p.tankId));
      } else if (p.source == PressureSource.unknown) {
        flags.add(ScenarioFlag(ScenarioFlagKind.pressureUnknown, tankId: p.tankId));
      }
    }
    for (final t in request.tanks) {
      if (t.volume == null) {
        flags.add(ScenarioFlag(ScenarioFlagKind.tankVolumeAssumed, tankId: t.id));
      }
    }

    final actualConsumption = _actualConsumption(request, schedule, branch, settings);
    final mode = scenario.effectiveMode;
    final branchT = branch.runtimeSeconds;
    final branchPressures = {
      for (final p in branch.tankPressures) p.tankId: p.pressureBar,
    };

    if (mode == ScenarioMode.replay) {
      final cfSchedule = rewriteScheduleForReplay(
        actual: schedule,
        interventions: interventions,
        branchTimestamp: branchT,
        timestamps: request.timestamps,
        depths: request.depths,
        maxPpO2: settings.ppO2Deco,
      );
      final counterfactual = analyze(
        depths: request.depths,
        timestamps: request.timestamps,
        gas: isOc ? cfSchedule.toGasSegments() : actualGas,
        ascent: isOc ? _ascentPlan(cfSchedule.tanks, settings) : null,
        rebreatherPpO2Curve: request.rebreatherPpO2Curve,
      );
      final multiplier = _replayMultiplier(interventions, settings);
      final cfStart = {
        for (final t in cfSchedule.tanks)
          t.id: branchPressures.containsKey(t.id)
              ? branchPressures[t.id]
              : t.startPressure,
      };
      final cfConsumption = simulateConsumption(
        timestamps: request.timestamps,
        depths: request.depths,
        schedule: cfSchedule,
        startPressures: cfStart,
        sacLpmAt: (_) => branch.sacLitersPerMin * multiplier,
        environment: settings.environment,
        gasModel: settings.gasModel,
        reservePressureBar: settings.reservePressureBar,
        fromIndex: branchIndex,
      );
      final consumption = ScenarioConsumption(
        actual: actualConsumption,
        counterfactual: cfConsumption,
        reservePressureBar: settings.reservePressureBar,
      );
      final deltas = buildDeltas(
        actual: actual,
        counterfactual: counterfactual,
        actualDepths: request.depths,
        counterfactualDepths: request.depths,
        actualTimestamps: request.timestamps,
        counterfactualTimestamps: request.timestamps,
        branchIndex: branchIndex,
        consumption: consumption,
      );
      return ScenarioOutcome(
        branch: branch,
        mode: mode,
        actual: actual,
        counterfactual: counterfactual,
        counterfactualDepths: request.depths,
        counterfactualTimestamps: request.timestamps,
        counterfactualGasSegments: isOc ? cfSchedule.toGasSegments() : actualGas,
        planOutcome: null,
        compiledPlan: null,
        consumption: consumption,
        deltas: deltas,
        verdictDeltas: selectVerdictDeltas(deltas),
        flags: flags,
      );
    }

    // Re-plan.
    final bottomEnd = finalAscentStartIndex(
      depths: request.depths,
      timestamps: request.timestamps,
      ndlCurve: actual.ndlCurve,
      decoStopCurve: actual.decoStopCurve,
    );
    if (bottomEnd == null || bottomEnd <= branchIndex) {
      flags.add(const ScenarioFlag(ScenarioFlagKind.noBottomRemaining));
    }
    final forcedTankId = forcedTankIdFor(
      interventions: interventions,
      tanks: request.tanks,
      branchDepth: branch.depthMeters,
      maxPpO2: settings.ppO2Deco,
    );
    var shift = 0;
    var ascendNow = scenario.abortsAtBranch;
    for (final i in interventions) {
      if (i is ShiftAscentIntervention) shift = i.deltaSeconds;
      if (i is AscendNowIntervention) ascendNow = true;
    }
    // A forced hypothetical tank must be known to the schedule the segments
    // are compiled against.
    var segmentSchedule = schedule;
    for (final i in interventions) {
      if (i is SwitchGasIntervention && i.tank is HypotheticalTankRef) {
        segmentSchedule = segmentSchedule.withTanks([
          ...schedule.tanks,
          hypotheticalTank(i.tank as HypotheticalTankRef),
        ]);
      }
      if (i is BailOutIntervention && i.tank is HypotheticalTankRef) {
        segmentSchedule = segmentSchedule.withTanks([
          ...schedule.tanks,
          hypotheticalTank(i.tank as HypotheticalTankRef),
        ]);
      }
    }
    final remaining = compileRemainingBottom(
      depths: request.depths,
      timestamps: request.timestamps,
      branchIndex: branchIndex,
      bottomEndIndex: bottomEnd,
      schedule: segmentSchedule,
      forcedTankId: forcedTankId,
      shiftSeconds: shift,
      ascendNow: ascendNow,
    );
    final compiled = compileScenarioPlan(
      request: request,
      branch: branch,
      settings: settings,
      interventions: interventions,
      remainingBottom: remaining,
    );
    final plan = compiled.plan;
    final engine = PlanEngine(config: settings.engineConfig);
    final planOutcome = engine.compute(plan, startState: branch.tissueState);
    if (!planOutcome.isDiveable) {
      flags.add(const ScenarioFlag(ScenarioFlagKind.replanNotCompletable));
    }
    final isLoop = plan.mode == domain.PlanMode.ccr || plan.mode == domain.PlanMode.scr;
    final remainder = synthesizeRemainder(
      plan: plan,
      outcome: planOutcome,
      startTimestamp: branchT,
      startDepth: branch.depthMeters,
      ascentPlan: engine.ascentPlanFor(plan.tanks),
      loop: isLoop
          ? LoopSetpoints(
              low: plan.effectiveSetpointLow,
              high: plan.effectiveSetpointHigh,
              switchDepth: plan.effectiveSetpointSwitchDepth,
              diluent: plan.segments.isEmpty ? const GasMix() : plan.segments.last.gasMix,
            )
          : null,
      extraLastStopSeconds: compiled.extraLastStopSeconds,
    );
    final spliced = spliceCounterfactual(
      actualTimestamps: request.timestamps,
      actualDepths: request.depths,
      actualGasSegments: actualGas,
      branchIndex: branchIndex,
      remainder: remainder,
    );
    List<double>? cfPpO2;
    if (!isOc && request.rebreatherPpO2Curve != null) {
      final measured = request.rebreatherPpO2Curve!;
      cfPpO2 = [
        for (var i = 0; i < spliced.depths.length; i++)
          if (i <= branchIndex && i < measured.length)
            measured[i]
          else
            (isLoop
                ? (spliced.depths[i] > plan.effectiveSetpointSwitchDepth
                    ? plan.effectiveSetpointHigh
                    : plan.effectiveSetpointLow)
                : _ocPpO2(spliced, i, settings)),
      ];
    }
    final counterfactual = analyze(
      depths: spliced.depths,
      timestamps: spliced.timestamps,
      gas: spliced.gasSegments,
      ascent: plan.mode == domain.PlanMode.oc ? engine.ascentPlanFor(plan.tanks) : null,
      rebreatherPpO2Curve: cfPpO2,
    );

    final cfSchedule = TankSchedule(
      intervals: [
        ...schedule.intervals.where((i) => i.startTimestamp < branchT),
        for (final s in remainder.tankSwitches)
          TankInterval(startTimestamp: s.timestamp, tankId: s.tankId),
      ],
      tanks: plan.tanks,
    );
    final cfStart = {
      for (final t in plan.tanks)
        t.id: branchPressures.containsKey(t.id) ? branchPressures[t.id] : t.startPressure,
    };
    final cfConsumption = simulateConsumption(
      timestamps: spliced.timestamps,
      depths: spliced.depths,
      schedule: cfSchedule,
      startPressures: cfStart,
      sacLpmAt: (i) => spliced.timestamps[i] <= remainder.bottomEndTimestamp
          ? plan.sacBottom
          : plan.sacDecoEffective,
      environment: settings.environment,
      gasModel: settings.gasModel,
      reservePressureBar: settings.reservePressureBar,
      fromIndex: branchIndex,
    );
    final consumption = ScenarioConsumption(
      actual: actualConsumption,
      counterfactual: cfConsumption,
      reservePressureBar: settings.reservePressureBar,
    );
    String? backId;
    for (final t in request.tanks) {
      if (t.role == TankRole.backGas) {
        backId = t.id;
        break;
      }
    }
    final deltas = buildDeltas(
      actual: actual,
      counterfactual: counterfactual,
      actualDepths: request.depths,
      counterfactualDepths: spliced.depths,
      actualTimestamps: request.timestamps,
      counterfactualTimestamps: spliced.timestamps,
      branchIndex: branchIndex,
      consumption: consumption,
      planOutcome: planOutcome,
      branchBackGasPressureBar: backId == null ? null : branch.pressureFor(backId),
    );
    return ScenarioOutcome(
      branch: branch,
      mode: mode,
      actual: actual,
      counterfactual: counterfactual,
      counterfactualDepths: spliced.depths,
      counterfactualTimestamps: spliced.timestamps,
      counterfactualGasSegments: spliced.gasSegments,
      planOutcome: planOutcome,
      compiledPlan: plan,
      consumption: consumption,
      deltas: deltas,
      verdictDeltas: selectVerdictDeltas(deltas),
      flags: flags,
    );
  }

  double _ocPpO2(SplicedProfile spliced, int i, ScenarioSettings settings) {
    var fN2 = spliced.gasSegments.first.fN2;
    var fHe = spliced.gasSegments.first.fHe;
    for (final g in spliced.gasSegments) {
      if (g.startTimestamp <= spliced.timestamps[i]) {
        fN2 = g.fN2;
        fHe = g.fHe;
      }
    }
    return settings.environment.pressureAtDepth(spliced.depths[i]) * (1.0 - fN2 - fHe);
  }

  double _replayMultiplier(List<ScenarioIntervention> interventions, ScenarioSettings settings) {
    var m = 1.0;
    for (final i in interventions) {
      if (i is ShareGasIntervention) m = 2.5 * (i.buddyFactor ?? settings.buddyFactor);
      if (i is BailOutIntervention && m == 1.0) m = 2.5;
    }
    return m;
  }

  AscentGasPlan _ascentPlan(List<DiveTank> tanks, ScenarioSettings settings) {
    if (tanks.isEmpty) return FixedAscentGas(fN2: 0.7902);
    final seen = <String>{};
    final gases = <AvailableGas>[];
    for (final t in tanks) {
      final fO2 = t.gasMix.o2 / 100.0;
      final fHe = t.gasMix.he / 100.0;
      final key = '${fO2.toStringAsFixed(4)}_${fHe.toStringAsFixed(4)}';
      if (!seen.add(key)) continue;
      gases.add(
        AvailableGas(
          fN2: (1.0 - fO2 - fHe).clamp(0.0, 1.0),
          fHe: fHe,
          maxPpO2Mod: O2ToxicityCalculator.calculateMod(fO2, maxPpO2: settings.ppO2Deco),
        ),
      );
    }
    return OptimalOcAscentGas(gases: gases, maxPpO2: settings.ppO2Deco);
  }

  /// Actual-timeline consumption: simulated from the start on the recorded
  /// schedule at the branch SAC; a tank with a recorded end pressure reports
  /// it (measured) instead of the simulated value.
  List<TankConsumption> _actualConsumption(
    ScenarioRequest request,
    TankSchedule schedule,
    BranchState branch,
    ScenarioSettings settings,
  ) {
    final simulated = simulateConsumption(
      timestamps: request.timestamps,
      depths: request.depths,
      schedule: schedule,
      startPressures: {for (final t in request.tanks) t.id: t.startPressure},
      sacLpmAt: (_) => branch.sacLitersPerMin,
      environment: settings.environment,
      gasModel: settings.gasModel,
      reservePressureBar: settings.reservePressureBar,
    );
    return [
      for (final s in simulated)
        () {
          final tank = schedule.tankById(s.tankId);
          final series = request.tankPressures[s.tankId];
          final measuredEnd = series != null && series.isNotEmpty
              ? series.last.pressureBar
              : tank?.endPressure;
          return measuredEnd == null
              ? s
              : TankConsumption(
                  tankId: s.tankId,
                  startPressureBar: s.startPressureBar,
                  endPressureBar: measuredEnd,
                  litersUsed: s.litersUsed,
                  reserveReachedAtSeconds: s.reserveReachedAtSeconds,
                  emptyAtSeconds: s.emptyAtSeconds,
                  source: PressureSource.measured,
                );
        }(),
    ];
  }
}
```

- [ ] **Step 4: Run the test and the whole dive_lab suite**

Run: `flutter test test/features/dive_lab/`
Expected: PASS. Likely first-run issues and their fixes: (a) `ProfileAnalysisService.analyze` throws on `gasSegments.first.startTimestamp > timestamps.first` if the schedule origin is not the first timestamp (origin is passed, so fine); (b) the replay identity test fails if `_ascentPlan` differs from what the provider passes today (it is built the same way as `buildAvailableGases` with `allCarried`, and both timelines use the same builder, so identity holds); (c) `ascendNow` runtime shorter: if the engine's deco from 45 m mid-bottom is longer than the remaining actual dive the assertion would fail; the branch at 15 min of a 30 min bottom leaves 15 min plus the actual ascent, and the deco from a 15 min exposure at 45 m on air is well under that, so the assertion holds.

- [ ] **Step 5: Commit**

```bash
git add lib/features/dive_lab/domain/entities/scenario_outcome.dart lib/features/dive_lab/domain/services/scenario_engine.dart test/features/dive_lab/domain/services/scenario_engine_test.dart
git commit -m "feat(dive-lab): ScenarioEngine replay and re-plan pipelines with invariants"
```

---

### Task 12: Spec wording, format, analyze, full verification

**Files:**
- Modify: `docs/superpowers/specs/2026-08-21-counterfactual-dive-lab-design.md` (the anchor field is `gfLowCeilingAnchor` in meters, not `gfLowCeilingAnchorBar`)

- [ ] **Step 1: Fix the spec wording**

Replace every `gfLowCeilingAnchorBar` with `gfLowCeilingAnchor` and the phrase "nullable `gfLowCeilingAnchorBar`" with "nullable `gfLowCeilingAnchor` (meters)". `grep -n gfLowCeilingAnchorBar docs/` must return nothing afterwards.

- [ ] **Step 2: Format and analyze**

Run: `dart format lib test && flutter analyze`
Expected: "Analyzing counterfactual-dive-lab..." then "No issues found!". Fix any lint (unused imports, prefer_const) inline.

- [ ] **Step 3: Run the affected suites**

Run: `flutter test test/core/deco test/features/dive_lab test/features/planner test/features/dive_log/data/services`
Expected: all PASS (no summary line or a silent exit means an infra kill; rerun).

- [ ] **Step 4: Commit**

```bash
git add -A docs lib test
git commit -m "chore(dive-lab): phase 1 engine verification and spec wording"
```

---

## Self-review notes

- Spec coverage (Phase 1 rows): `DecoStatus` anchor (Task 1); scenario model, interventions, composition rules (Task 2); codec (Task 3); tank schedule and replay rewrite incl. lost-tank substitution and bailout pool (Task 4); settings resolution shape, branch state with pressure and SAC sources (Task 5); final ascent start and remaining-bottom compile incl. shift and ascend-now (Task 6); plan compile rules incl. switch-depth pin, SAC rules, policy overrides (Task 7); synthesis at 10 s, splice, loop setpoints (Task 8); consumption pass with reserve/empty instants (Task 9); delta metrics and verdict (Task 10); engine pipelines, flags, invariants identity/continuity/monotonicity (Task 11).
- Deferred to Phase 2 (provider layer): building `ScenarioRequest` from providers (residual seeds, loop gas segments, logged SAC), isolate invocation and debounce.
- Type consistency: `CompiledScenario {plan, forcedTankId, extraLastStopSeconds}` (Task 7 code is authoritative over its Interfaces summary); `TankSchedule.withTanks`, `switchedTo`, `toGasSegments`, `tankIdAt`, `tankById`, `tankAt`, `mixAt`, `switchesAfter` are the only public members; `forcedTankIdFor` lives in the plan compiler file; `hypotheticalTank` lives in the replay rewriter file and is imported by the compiler.
