# Counterfactual Dive Lab Phase 2 (Ephemeral Lab Page) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A full-screen Dive Lab page reachable from dive detail that runs the Phase 1 `ScenarioEngine` on a logged dive with a draft scenario (branch point, mode, the five core interventions) and shows the actual vs counterfactual chart, controls and delta panel. Nothing persists in this phase.

**Architecture:** Provider layer (`lib/features/dive_lab/presentation/providers/`) assembles a `ScenarioRequest` from the same sources the dive detail analysis uses, holds a `LabDraft` per dive, and runs the engine under `compute()` with a 150 ms debounce. Widgets (`lib/features/dive_lab/presentation/widgets/`) compose the existing `DiveProfileChart` (ghost via `ChartSourceOverlay`), `PlanKit` tiles/chips, `TissueHeatMapStrip`, and planner result patterns. `DiveLabPage` is pushed on the root navigator (the `FullscreenProfilePage` pattern). Entry points: profile-card toolbar icon + overflow "What if..." in both dive-detail chrome variants.

**Tech Stack:** Flutter/Material 3, Riverpod 3.4 (legacy `StateNotifierProvider.family` via `core/providers/provider.dart`), `compute`, `flutter gen-l10n` (11 locales), `flutter_test` with `testApp` harness.

**Spec:** `docs/superpowers/specs/2026-08-21-counterfactual-dive-lab-design.md` (sections "UI" and "Engine: Execution, caching, performance"; Phase 2 row of the phase table). Phase 1 plan: `docs/superpowers/plans/2026-08-21-dive-lab-phase1-engine.md`.

## Global Constraints

- Worktree `.claude/worktrees/counterfactual-dive-lab`, branch `worktree-counterfactual-dive-lab`; absolute paths for every Read/Edit/Write; `pwd` before `flutter test`.
- No em-dashes anywhere; no emojis in code or docs.
- `dart format lib test` clean; `flutter analyze` clean (infos are fatal in CI); files under 800 lines.
- Every user-facing string through `context.l10n.<key>` with keys `diveLab_*` added to ALL 11 ARBs (`lib/l10n/arb/app_{en,ar,de,es,fr,he,hu,it,nl,pt,zh}.arb`), then `flutter gen-l10n` and commit the generated `app_localizations*.dart`.
- Every displayed unit value goes through `UnitFormatter(ref.watch(settingsProvider))`; times as `M:SS` or minutes with a prime (`12′`).
- Widget tests pin `locale: const Locale('en')` and override `settingsProvider` with `MockSettingsNotifier` (`test/helpers/mock_providers.dart`); provider tests that need the engine override `scenarioEngineRunnerProvider` with a synchronous runner; no `compute` in `testWidgets`.
- Commits local only, no `Co-Authored-By`.

## File structure

```
lib/features/dive_lab/domain/entities/scenario_settings.dart       (modify: surfacePressureBar)
lib/features/dive_log/presentation/providers/profile_analysis_provider.dart (modify: drop @visibleForTesting on resolveCcrDiluentMix + buildCcrProfileGasSegments)

lib/features/dive_lab/presentation/providers/
  lab_request_inputs_provider.dart   LabRequestInputs + labRequestInputsProvider (FutureProvider.family)
  lab_draft_provider.dart            LabDraft, LabDraftNotifier, labDraftProvider, labDefaultBranchProvider
  scenario_outcome_provider.dart     scenarioEngineRunnerProvider, scenarioOutcomeProvider (debounced compute)

lib/features/dive_lab/presentation/
  lab_format.dart                    metric labels, value/delta formatting, verdict phrases
  pages/dive_lab_page.dart           DiveLabPage + showDiveLab (root navigator push)
  widgets/lab_chart.dart             DiveProfileChart host with the counterfactual overlay
  widgets/lab_branch_controls.dart   readout + slider + steppers
  widgets/lab_mode_toggle.dart       SegmentedButton<ScenarioMode>
  widgets/lab_intervention_chips.dart chips + add button
  widgets/lab_add_intervention_sheet.dart kind list + per-kind editors
  widgets/lab_delta_panel.dart       verdict, tiles, table, tissue strips, gas rows, issues, runtime
  widgets/lab_runtime_table.dart     stops table (copy of the planner's private table)

lib/features/dive_log/presentation/pages/dive_detail_page.dart (modify: toolbar icon + 2 menu items)
lib/l10n/arb/app_*.arb (modify: diveLab_* keys) + generated app_localizations*.dart

test/features/dive_lab/presentation/providers/lab_request_inputs_provider_test.dart  (real DB)
test/features/dive_lab/presentation/providers/lab_draft_provider_test.dart
test/features/dive_lab/presentation/providers/scenario_outcome_provider_test.dart
test/features/dive_lab/presentation/widgets/lab_delta_panel_test.dart
test/features/dive_lab/presentation/widgets/lab_add_intervention_sheet_test.dart
test/features/dive_lab/presentation/pages/dive_lab_page_test.dart
test/features/dive_lab/domain/entities/scenario_settings_test.dart
```

---

### Task 1: Engine adjustments for the provider layer

**Files:**
- Modify: `lib/features/dive_lab/domain/entities/scenario_settings.dart`
- Modify: `lib/features/dive_log/presentation/providers/profile_analysis_provider.dart` (lines 234 and 264: remove the `@visibleForTesting` annotation from `resolveCcrDiluentMix` and `buildCcrProfileGasSegments`; they become ordinary public helpers used by the Dive Lab provider)
- Test: `test/features/dive_lab/domain/entities/scenario_settings_test.dart`

**Interfaces:**
- `ScenarioSettings` gains `final double? surfacePressureBar;` and `environment` becomes `DiveEnvironment.forConditions(altitudeMeters: altitudeMeters, waterType: waterType, surfacePressureBar: surfacePressureBar)`, mirroring `profile_analysis_provider` exactly (the engine's own "altitude <= 0 is unset" rule stays inside `PlanEngine`, which receives `altitude` separately). `copyWith` and `props` updated.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/dive_lab/domain/entities/scenario_settings_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/deco/entities/dive_environment.dart';
import 'package:submersion/features/dive_lab/domain/entities/scenario_settings.dart';

void main() {
  test('environment mirrors the dive detail analysis resolution', () {
    const s = ScenarioSettings(
      altitudeMeters: 1500,
      waterType: WaterType.fresh,
      surfacePressureBar: 0.9,
    );
    expect(
      s.environment,
      DiveEnvironment.forConditions(
        altitudeMeters: 1500,
        waterType: WaterType.fresh,
        surfacePressureBar: 0.9,
      ),
    );
    expect(const ScenarioSettings().environment, DiveEnvironment.standard);
    expect(
      const ScenarioSettings(altitudeMeters: 0).environment.surfacePressureBar,
      closeTo(1.01325, 1e-3),
    );
  });

  test('withGf replaces only the gradient factors', () {
    const s = ScenarioSettings(surfacePressureBar: 0.95, buddyFactor: 3);
    final g = s.withGf(low: 40, high: 85);
    expect(g.gfLowPercent, 40);
    expect(g.gfHighPercent, 85);
    expect(g.surfacePressureBar, 0.95);
    expect(g.buddyFactor, 3);
  });
}
```

- [ ] **Step 2: Run, expect failure (`surfacePressureBar` undefined)**
- [ ] **Step 3: Implement** (field, ctor param, `environment`, `copyWith`, `props`; remove the two annotations in the provider file)
- [ ] **Step 4: Run `flutter test test/features/dive_lab test/core/deco` and `flutter analyze lib/features/dive_log/presentation/providers/profile_analysis_provider.dart`**
- [ ] **Step 5: Commit** `feat(dive-lab): settings carry surface pressure; expose CCR gas helpers`

---

### Task 2: `LabRequestInputs` + `labRequestInputsProvider` (real-DB integration test)

**Files:**
- Create: `lib/features/dive_lab/presentation/providers/lab_request_inputs_provider.dart`
- Test: `test/features/dive_lab/presentation/providers/lab_request_inputs_provider_test.dart`

**Interfaces:**
```dart
class LabRequestInputs {
  const LabRequestInputs({required this.dive, required this.profile, required this.depths, required this.timestamps, required this.diveMode, required this.tanks, required this.gasSwitches, required this.tankPressures, this.loopGasSegments, this.rebreatherPpO2Curve, this.setpointHigh, this.setpointLow, this.startCompartments, required this.startCns, required this.startOtu, this.fallbackSacLpm, required this.settings});
  final Dive dive; final List<DiveProfilePoint> profile; final List<double> depths; final List<int> timestamps; final DiveMode diveMode; final List<DiveTank> tanks; final List<ScenarioGasSwitch> gasSwitches; final Map<String, List<TankPressureSample>> tankPressures; final List<ProfileGasSegment>? loopGasSegments; final List<double>? rebreatherPpO2Curve; final double? setpointHigh; final double? setpointLow; final List<TissueCompartment>? startCompartments; final double startCns; final double startOtu; final double? fallbackSacLpm; final ScenarioSettings settings;
  int get durationSeconds => timestamps.isEmpty ? 0 : timestamps.last - timestamps.first;
  ScenarioRequest toRequest(DiveScenario scenario);
}
/// Null when the dive is ineligible (gauge mode, or fewer than 2 profile samples).
final labRequestInputsProvider = FutureProvider.family<LabRequestInputs?, String>((ref, diveId) async { ... });
```
Sources (all existing): `diveProvider(diveId)`, `diveProfileProvider(diveId)` (primary), `gasSwitchesProvider(diveId)` (`gas_switch_providers.dart`), `tankPressuresProvider(diveId)`, `residualTissueStateProvider(diveId)`, `residualCnsProvider(diveId)`, `residualOtuProvider(diveId)`, `loggedAverageSacProvider`, settings providers (`gfLowProvider`, `gfHighProvider`, `ppO2MaxWorkingProvider`, `ppO2MaxDecoProvider`, `cnsWarningThresholdProvider`, `ascentRateWarningProvider`, `ascentRateCriticalProvider`, `lastStopDepthProvider`, `decoStopIncrementProvider`, `cnsCalculationMethodProvider`, `gasModelProvider`, `settingsProvider.select((s) => s.o2Narcotic)`), `planEngineConfigProvider` (buddy factor), `GradientFactorSource.resolve(diveGfLow: dive.gradientFactorLow, diveGfHigh: dive.gradientFactorHigh, settingsGfLow, settingsGfHigh, recordedAlgorithm: dive.decoAlgorithm)`. CCR/SCR: `resolveRebreatherPpO2(profile)?.curve` and `buildCcrProfileGasSegments(timestamps:, loopPpO2Curve:, diluentMix: resolveCcrDiluentMix(dive), fallbackSetpoint: dive.setpointHigh ?? dive.setpointLow)`. Gas switches map to `ScenarioGasSwitch(timestamp: s.timestamp, tankId: s.tankId)`; tank pressures map each `TankPressurePoint` to `TankPressureSample(timestamp, pressureBar: pressure)`. `ScenarioSettings(gfLow: gf.lowFraction, gfHigh: gf.highFraction, ..., altitudeMeters: dive.altitude, waterType: dive.waterType, surfacePressureBar: dive.surfacePressure, buddyFactor: engineConfig.buddyFactor, reservePressureBar: 50)`.

- [ ] **Step 1: Write the failing test** (seeds a dive with a square profile, two tanks, one gas switch and a pressure series through `DiveRepository().createDive`, `createGasSwitch`, `TankPressureRepository().insertTankPressures`; reads the provider from a `ProviderContainer` with `settingsProvider` overridden by `MockSettingsNotifier` and `loggedAverageSacProvider` overridden to `17.0`; asserts depths/timestamps length, tanks ids, one `ScenarioGasSwitch` at the switch timestamp, the pressure series mapped, `settings.gfLowPercent` from the mock settings (defaults) unless the dive carries both GF values, `fallbackSacLpm == 17`, and that a gauge dive yields null).

```dart
// test/features/dive_lab/presentation/providers/lab_request_inputs_provider_test.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_lab/presentation/providers/lab_request_inputs_provider.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/repositories/tank_pressure_repository.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/gas_switch.dart';
import 'package:submersion/features/planner/presentation/providers/plan_canvas_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

List<DiveProfilePoint> _square() => [
  for (var t = 0; t <= 1800; t += 10)
    DiveProfilePoint(timestamp: t, depth: t < 120 ? t / 3.0 : (t < 1500 ? 40.0 : 40.0 - (t - 1500) / 300 * 40.0)),
];

void main() {
  setUp(setUpTestDatabase);
  tearDown(tearDownTestDatabase);

  ProviderContainer container() => ProviderContainer(
    overrides: [
      settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
      loggedAverageSacProvider.overrideWith((ref) async => 17.0),
    ],
  );

  test('assembles the request inputs from the real database', () async {
    final dive = await DiveRepository().createDive(
      Dive(
        id: '',
        diveNumber: 1,
        dateTime: DateTime(2026, 1, 1),
        profile: _square(),
        gradientFactorLow: 35,
        gradientFactorHigh: 75,
        tanks: const [
          DiveTank(id: 'back', volume: 24, startPressure: 200, endPressure: 80, gasMix: GasMix(o2: 21), role: TankRole.backGas),
          DiveTank(id: 'deco', volume: 11.1, startPressure: 200, endPressure: 150, gasMix: GasMix(o2: 50), role: TankRole.deco),
        ],
      ),
    );
    await DiveRepository().createGasSwitch(
      GasSwitch(id: 'sw1', diveId: dive.id, timestamp: 1600, tankId: 'deco', depth: 21, createdAt: DateTime(2026)),
    );
    await TankPressureRepository().insertTankPressures(dive.id, {
      'back': [(timestamp: 0, pressure: 200.0), (timestamp: 900, pressure: 140.0)],
    });

    final c = container();
    addTearDown(c.dispose);
    final inputs = await c.read(labRequestInputsProvider(dive.id).future);
    expect(inputs, isNotNull);
    expect(inputs!.depths.length, _square().length);
    expect(inputs.timestamps.last, 1800);
    expect(inputs.tanks.map((t) => t.id), containsAll(['back', 'deco']));
    expect(inputs.gasSwitches.single.timestamp, 1600);
    expect(inputs.gasSwitches.single.tankId, 'deco');
    expect(inputs.tankPressures['back']!.last.pressureBar, 140.0);
    expect(inputs.settings.gfLowPercent, 35);
    expect(inputs.settings.gfHighPercent, 75);
    expect(inputs.fallbackSacLpm, 17.0);
    expect(inputs.diveMode, DiveMode.oc);
    expect(inputs.loopGasSegments, isNull);
  });

  test('a gauge dive is ineligible', () async {
    final dive = await DiveRepository().createDive(
      Dive(id: '', diveNumber: 2, dateTime: DateTime(2026, 1, 2), profile: _square(), diveMode: DiveMode.gauge),
    );
    final c = container();
    addTearDown(c.dispose);
    expect(await c.read(labRequestInputsProvider(dive.id).future), isNull);
  });
}
```

- [ ] **Step 2: Run, expect failure**
- [ ] **Step 3: Implement the provider** (see Interfaces; the body awaits the futures in sequence; `settingsProvider.select` for `o2Narcotic`; gauge or `profile.length < 2` returns null)
- [ ] **Step 4: Run the test; PASS**
- [ ] **Step 5: Commit** `feat(dive-lab): assemble the scenario request from dive providers`

---

### Task 3: `LabDraft`, `LabDraftNotifier`, `labDefaultBranchProvider`

**Files:**
- Create: `lib/features/dive_lab/presentation/providers/lab_draft_provider.dart`
- Test: `test/features/dive_lab/presentation/providers/lab_draft_provider_test.dart`

**Interfaces:**
```dart
class LabDraft extends Equatable {
  const LabDraft({this.branchSeconds, this.mode = ScenarioMode.replay, this.interventions = const []});
  final int? branchSeconds;            // null = not seeded yet
  final ScenarioMode mode;
  final List<ScenarioIntervention> interventions;
  bool get isSeeded => branchSeconds != null;
  ScenarioMode get effectiveMode;      // replan when any intervention requiresReplan
  DiveScenario toScenario(String diveId);   // id 'draft', name 'draft', createdAt/updatedAt = DateTime.fromMillisecondsSinceEpoch(0)
  LabDraft copyWith({int? branchSeconds, ScenarioMode? mode, List<ScenarioIntervention>? interventions});
}
class LabDraftNotifier extends StateNotifier<LabDraft> {
  LabDraftNotifier() : super(const LabDraft());
  void seedBranch(int seconds);                       // only when not seeded
  void setBranchSeconds(int seconds, {required int maxSeconds});   // clamped to [0, maxSeconds]
  void nudgeBranch(int deltaSeconds, {required int maxSeconds});
  void setMode(ScenarioMode mode);                    // ignored if a path-changing intervention forces replan
  void addIntervention(ScenarioIntervention i);       // replaces same kind; flips mode to replan when i.requiresReplan
  void removeIntervention(InterventionKind kind);
  void clearInterventions();
}
final labDraftProvider = StateNotifierProvider.family<LabDraftNotifier, LabDraft, String>((ref, diveId) => LabDraftNotifier());
/// The branch the lab opens at: the detail chart's tracking index if set, else the final ascent start, else the max-depth time.
final labDefaultBranchProvider = FutureProvider.family<int, String>((ref, diveId) async { ... });
```
`labDefaultBranchProvider` reads `profileTrackingIndexProvider(diveId)` (one-shot `ref.read`, not watch), `labRequestInputsProvider(diveId)` and `profileAnalysisProvider(diveId)`; uses `finalAscentStartIndex(depths, timestamps, ndlCurve, decoStopCurve)` from the Phase 1 compiler; falls back to the timestamp of the deepest sample.

- [ ] **Step 1: Write the failing test** (notifier: seed once; clamp; nudge; add replaces kind and flips mode; setMode ignored while forced; remove restores mode freedom)
- [ ] **Step 2: Run, expect failure**
- [ ] **Step 3: Implement**
- [ ] **Step 4: Run; PASS**
- [ ] **Step 5: Commit** `feat(dive-lab): draft scenario state and default branch`

---

### Task 4: `scenarioOutcomeProvider` with debounce and isolate runner

**Files:**
- Create: `lib/features/dive_lab/presentation/providers/scenario_outcome_provider.dart`
- Test: `test/features/dive_lab/presentation/providers/scenario_outcome_provider_test.dart`

**Interfaces:**
```dart
typedef ScenarioRunner = Future<ScenarioOutcome> Function(ScenarioRequest request);
/// Runs the engine in a background isolate; tests override with a synchronous runner.
final scenarioEngineRunnerProvider = Provider<ScenarioRunner>((_) => (r) => compute(runScenarioEngine, r));
const Duration kLabRecomputeDebounce = Duration(milliseconds: 150);
/// Null until the draft is seeded or when the dive is ineligible. Keeps the previous value while recomputing (Riverpod's AsyncLoading carries it; read `.valueOrNull`).
final scenarioOutcomeProvider = FutureProvider.autoDispose.family<ScenarioOutcome?, String>((ref, diveId) async {
  final draft = ref.watch(labDraftProvider(diveId));
  if (!draft.isSeeded) return null;
  final inputs = await ref.watch(labRequestInputsProvider(diveId).future);
  if (inputs == null) return null;
  var cancelled = false;
  ref.onDispose(() => cancelled = true);
  await Future<void>.delayed(kLabRecomputeDebounce);
  if (cancelled) return Completer<ScenarioOutcome?>().future;   // superseded: never resolves, Riverpod drops it
  return ref.read(scenarioEngineRunnerProvider)(inputs.toRequest(draft.toScenario(diveId)));
});
```

- [ ] **Step 1: Write the failing test** (ProviderContainer with `labRequestInputsProvider(id).overrideWith((ref) async => inputs built from `squareDive()`)` and a counting synchronous runner; (a) unseeded draft yields null without running; (b) after `seedBranch(900)`, `await container.read(provider.future)` yields an outcome and the runner ran once; (c) three rapid `nudgeBranch` calls followed by one await run the engine once more, not three times; (d) the outcome's branch runtime equals the draft branch).
- [ ] **Step 2: Run, expect failure**
- [ ] **Step 3: Implement**
- [ ] **Step 4: Run; PASS**
- [ ] **Step 5: Commit** `feat(dive-lab): debounced scenario outcome provider on an isolate`

---

### Task 5: l10n keys for the lab (all 11 locales) + `flutter gen-l10n`

**Files:**
- Modify: `lib/l10n/arb/app_en.arb` (keys + `@` metadata for placeholders), `app_ar.arb`, `app_de.arb`, `app_es.arb`, `app_fr.arb`, `app_he.arb`, `app_hu.arb`, `app_it.arb`, `app_nl.arb`, `app_pt.arb`, `app_zh.arb` (translated values)
- Generated: `lib/l10n/arb/app_localizations*.dart` (committed)

**Keys (English values):**
```
diveLab_title: Dive Lab
diveLab_action_whatIf: What if…
diveLab_tooltip_open: Open the Dive Lab
diveLab_empty_ineligible: This dive has no profile to branch from.
diveLab_loading: Loading the dive…
diveLab_branch_label: Branch
diveLab_branch_readout: {time} at {depth}          (placeholders time: String, depth: String)
diveLab_branch_minusMinute: -1 min
diveLab_branch_minusTenSeconds: -10 s
diveLab_branch_plusTenSeconds: +10 s
diveLab_branch_plusMinute: +1 min
diveLab_mode_replay: Replay
diveLab_mode_replan: Re-plan
diveLab_mode_replayHint: Same depth path, changed inputs
diveLab_mode_replanHint: The engine plans the ascent from the branch
diveLab_mode_forced: Re-plan is required by an intervention
diveLab_interventions_label: Interventions
diveLab_interventions_add: Add
diveLab_interventions_none: No interventions yet: the what-if equals the actual dive.
diveLab_kind_switchGas: Switch gas
diveLab_kind_loseTank: Lose a cylinder
diveLab_kind_shiftAscent: Shift the ascent
diveLab_kind_ascendNow: Ascend now
diveLab_kind_changeGf: Gradient factors
diveLab_kind_shareGas: Share gas with a buddy
diveLab_kind_bailOut: Bail out to open circuit
diveLab_kind_ascentPolicy: Ascent policy
diveLab_kindDesc_switchGas: Breathe a different cylinder from the branch point
diveLab_kindDesc_loseTank: A deco or stage cylinder is lost from the branch point
diveLab_kindDesc_shiftAscent: Begin the final ascent earlier or later
diveLab_kindDesc_ascendNow: Abort the bottom phase at the branch point
diveLab_kindDesc_changeGf: Run the what-if under other gradient factors
diveLab_kindDesc_shareGas: An out-of-gas buddy shares your gas from the branch point
diveLab_kindDesc_bailOut: Leave the loop and ascend on open-circuit bailout
diveLab_kindDesc_ascentPolicy: Other ascent rate, last stop depth or stop lengths
diveLab_chip_switchGas: Switch to {gas}                (gas: String)
diveLab_chip_loseTank: Lost {tank}                     (tank: String)
diveLab_chip_shiftAscent: Ascent {delta}               (delta: String)
diveLab_chip_ascendNow: Ascend now
diveLab_chip_changeGf: GF {low}/{high}                 (low: int, high: int)
diveLab_chip_shareGas: Share gas x{factor}             (factor: String)
diveLab_chip_bailOut: Bail out
diveLab_chip_ascentPolicy: Ascent policy
diveLab_chip_remove: Remove {name}                     (name: String)
diveLab_sheet_title: Add an intervention
diveLab_sheet_add: Add
diveLab_sheet_cylinder: Cylinder
diveLab_sheet_hypothetical: Hypothetical cylinder
diveLab_sheet_o2: O2 %
diveLab_sheet_he: He %
diveLab_sheet_volume: Volume ({unit})                  (unit: String)
diveLab_sheet_startPressure: Start pressure ({unit})   (unit: String)
diveLab_sheet_minutes: Minutes
diveLab_sheet_earlier: earlier
diveLab_sheet_later: later
diveLab_sheet_buddyFactor: Buddy factor
diveLab_sheet_noCandidates: No cylinder on this dive can be used here.
diveLab_sheet_allAdded: Every intervention is already in the scenario.
diveLab_panel_verdict: Verdict
diveLab_panel_actual: Actual
diveLab_panel_whatIf: What if
diveLab_panel_delta: Delta
diveLab_panel_tissues: Tissues at the surface
diveLab_panel_gas: Gas
diveLab_panel_issues: Issues
diveLab_panel_runtime: Runtime
diveLab_panel_noIssues: No issues
diveLab_panel_computing: Computing…
diveLab_panel_identity: No change: the what-if matches the actual dive.
diveLab_panel_notes: Notes
diveLab_verdict_item: {label}: {actual} to {whatIf} ({delta})   (label, actual, whatIf, delta: String)
diveLab_flag_sacEstimated: SAC estimated
diveLab_flag_pressureEstimated: Pressure estimated for {tank}   (tank: String)
diveLab_flag_pressureUnknown: Pressure unknown for {tank}       (tank: String)
diveLab_flag_tankVolumeAssumed: Volume assumed for {tank}       (tank: String)
diveLab_flag_noBottomRemaining: The branch is already in the ascent
diveLab_flag_replanNotCompletable: Not completable as branched
diveLab_flag_loopGasMissing: Loop gas unknown; open circuit assumed
diveLab_metric_runtime: Runtime
diveLab_metric_ttsAtBranch: TTS at branch
diveLab_metric_decoTimeAfterBranch: Deco time after branch
diveLab_metric_deepestStopAfterBranch: Deepest stop
diveLab_metric_surfaceGf: Surface GF
diveLab_metric_peakGf99AfterBranch: Peak GF99 after branch
diveLab_metric_cnsEnd: CNS at surface
diveLab_metric_otuEnd: OTU at surface
diveLab_metric_maxPpO2AfterBranch: Max ppO2 after branch
diveLab_metric_tankEndPressure: {tank} end pressure         (tank: String)
diveLab_metric_gasOutTime: {tank} out of gas at            (tank: String)
diveLab_metric_minGasMarginAtBranch: Min gas margin at branch
diveLab_metric_ceilingViolations: Ceiling violations
diveLab_metric_worstCeilingViolation: Worst ceiling excursion
diveLab_gas_reserve: reserve at {time}                     (time: String)
diveLab_gas_empty: empty at {time}                         (time: String)
diveLab_gas_unknown: unknown
diveLab_tile_tts: TTS
diveLab_tile_deco: Deco
diveLab_tile_surfGf: Surf GF
diveLab_tile_cns: CNS
diveLab_tile_backGas: Back gas
diveLab_value_none: n/a
```
Translate every value into the other 10 locales (write the translations; do not leave English copies except for symbols like "GF {low}/{high}" and "TTS"). Insert the keys before the closing brace of each ARB (textual insertion keeps the existing formatting), add `@diveLab_*` placeholder metadata in `app_en.arb` only, then run `flutter gen-l10n`.

- [ ] **Step 1: Add the keys to all 11 ARBs** (script: for each ARB, parse with `json.load` to verify validity AFTER insertion; insert text before the final `}`)
- [ ] **Step 2: Run `flutter gen-l10n`; confirm `lib/l10n/arb/app_localizations.dart` gained `diveLab_title`**
- [ ] **Step 3: Verify key counts are equal across the 11 ARBs** (`grep -c '"diveLab_' app_*.arb` equal for all)
- [ ] **Step 4: Commit** `feat(dive-lab): localized strings for the lab page`

---

### Task 6: Formatting helpers + delta panel

**Files:**
- Create: `lib/features/dive_lab/presentation/lab_format.dart`
- Create: `lib/features/dive_lab/presentation/widgets/lab_runtime_table.dart`
- Create: `lib/features/dive_lab/presentation/widgets/lab_delta_panel.dart`
- Test: `test/features/dive_lab/presentation/widgets/lab_delta_panel_test.dart`

**Interfaces:**
```dart
// lab_format.dart
String formatLabTime(int seconds);                       // "23:40"
String formatLabMinutes(int seconds);                    // "12′" (ceil)
String labMetricLabel(AppLocalizations l10n, ScenarioDelta d, String Function(String tankId) tankName);
String labMetricValue(AppLocalizations l10n, UnitFormatter units, DeltaMetric m, double? v);   // unit-aware, "n/a" when null
String labDeltaValue(AppLocalizations l10n, UnitFormatter units, ScenarioDelta d);             // signed, "+4′", "-12 bar", "+3.2%"
Color? labDeltaColor(ColorScheme scheme, ScenarioDelta d);   // green when better, error when worse, null neutral/zero
String labInterventionChipLabel(AppLocalizations l10n, UnitFormatter units, ScenarioIntervention i, String Function(String tankId) tankName);
String labFlagText(AppLocalizations l10n, ScenarioFlag f, String Function(String tankId) tankName);
String labTankName(List<DiveTank> tanks, String tankId);  // name ?? mix name ?? id
// lab_runtime_table.dart
class LabRuntimeTable extends StatelessWidget { const LabRuntimeTable({super.key, required PlanOutcome outcome, required UnitFormatter units}); }
// lab_delta_panel.dart
class LabDeltaPanel extends ConsumerWidget { const LabDeltaPanel({super.key, required LabRequestInputs inputs, required AsyncValue<ScenarioOutcome?> outcome}); }
```
Panel sections in order: verdict (or identity / computing line), tiles (TTS at branch, deco time after branch, surface GF, CNS end, back-gas end pressure) via `PlanStatTile` in a 2-column grid, delta table (actual | what-if | delta per `ScenarioDelta`, delta colored by `labDeltaColor`), tissue strips (two `TissueHeatMapStrip`s with `colorFnForScheme(ref.watch(tissueColorSchemeProvider))`, labels Actual / What if), gas rows per counterfactual tank (start to end pressure, reserve/empty instants, estimated badge), issues (`planIssueMessage` from `plan_results_sheet.dart` + `planIssueSeverityColor`), runtime table (re-plan only), notes (flags). While `outcome.isLoading && outcome.hasValue`, wrap the body in `Opacity(0.6)` and show a thin `LinearProgressIndicator` on top.

- [ ] **Step 1: Write the failing widget test** (pump `LabDeltaPanel` inside `testApp(locale: en, overrides: settings mock)` with an outcome from `ScenarioEngine().run(...)` on `squareDive()` with a `ShiftAscentIntervention(-300)`; expect the metric label "Runtime", the column headers "Actual"/"What if"/"Delta", a tissue strip count of 2 (`find.byType(TissueHeatMapStrip)`), and the runtime table header "Depth"; and a second pump with an AsyncLoading-with-value shows the progress bar).
- [ ] **Step 2: Run, expect failure**
- [ ] **Step 3: Implement**
- [ ] **Step 4: Run; PASS**
- [ ] **Step 5: Commit** `feat(dive-lab): delta panel, runtime table and formatting`

---

### Task 7: Chart host, branch controls, mode toggle, chips, add-intervention sheet

**Files:**
- Create: `lib/features/dive_lab/presentation/widgets/lab_chart.dart`
- Create: `lib/features/dive_lab/presentation/widgets/lab_branch_controls.dart`
- Create: `lib/features/dive_lab/presentation/widgets/lab_mode_toggle.dart`
- Create: `lib/features/dive_lab/presentation/widgets/lab_intervention_chips.dart`
- Create: `lib/features/dive_lab/presentation/widgets/lab_add_intervention_sheet.dart`
- Test: `test/features/dive_lab/presentation/widgets/lab_add_intervention_sheet_test.dart`

**Interfaces:**
```dart
class LabChart extends ConsumerWidget { const LabChart({super.key, required String diveId, required LabRequestInputs inputs, required ScenarioOutcome? outcome, required int? branchSeconds}); }
// DiveProfileChart(profile: inputs.profile, overlays: [ghost], ceilingCurve: replay ? outcome.counterfactual.ceilingCurve : outcome.actual.ceilingCurve, decoStopCurve: likewise, highlightedTimestamp: branchSeconds, showTemperature: false)
// ghost = ChartSourceOverlay(sourceId: 'lab:draft', name: l10n.diveLab_panel_whatIf, color: Colors.teal, computerId: null, points: cf samples with timestamp >= branch)
const Color kLabGhostColor = Colors.teal;
class LabBranchControls extends ConsumerWidget { const LabBranchControls({super.key, required String diveId, required LabRequestInputs inputs, required ScenarioOutcome? outcome}); }
// readout l10n.diveLab_branch_readout(formatLabTime(branch), units.formatDepth(depth at branch)); Slider(min 0, max durationSeconds, divisions = durationSeconds ~/ 10); four OutlinedButtons calling nudgeBranch(-60/-10/+10/+60)
class LabModeToggle extends ConsumerWidget { const LabModeToggle({super.key, required String diveId}); }
// SegmentedButton<ScenarioMode>; disabled (onSelectionChanged null) with diveLab_mode_forced helper text when forced
class LabInterventionChips extends ConsumerWidget { const LabInterventionChips({super.key, required String diveId, required LabRequestInputs inputs}); }
// Wrap of PlanChip(label: labInterventionChipLabel(...), value: '✕' (use "x" glyph via Icons.close inside label? PlanChip takes String value: use '✕' U+2715 is fine), onTap: remove) + ActionChip-like PlanChip(label: l10n.diveLab_interventions_add, emphasized: true, onTap: showLabAddInterventionSheet)
Future<void> showLabAddInterventionSheet(BuildContext context, {required String diveId, required LabRequestInputs inputs});
// modal bottom sheet (showDragHandle, isScrollControlled): list of available kinds (phase 2: switchGas, loseTank, shiftAscent, ascendNow, changeGf, shareGas; switchGas hidden on CCR/SCR; loseTank hidden when no losable tank) minus kinds already present; tapping a kind shows its editor below the list; "Add" calls labDraftProvider.notifier.addIntervention and pops.
// editors: _SwitchGasEditor (DropdownButton over inputs.tanks + a "hypothetical" entry revealing O2/He/volume/pressure TextFields through formatDecimalForInput/parseUserDecimal and units.depth/pressure conversions), _LoseTankEditor (dropdown over tanks with role deco/stage/bailout/pony or isTravelGas), _ShiftAscentEditor (minutes stepper -/+ with earlier/later label), _ChangeGfEditor (two sliders 10..100), _ShareGasEditor (buddy factor stepper 1.0..3.0 by 0.5)
```

- [ ] **Step 1: Write the failing widget test** (pump a host that opens `showLabAddInterventionSheet` for a dive with a back gas + deco tank; tap "Gradient factors", move nothing, tap "Add": `labDraftProvider(diveId)` now holds a `ChangeGfIntervention`; reopen: "Gradient factors" is no longer listed; tap "Lose a cylinder", choose the deco tank, "Add": a `LoseTankIntervention(tankId: 'deco')`; tap "Ascend now" + "Add": draft mode is replan).
- [ ] **Step 2: Run, expect failure**
- [ ] **Step 3: Implement the five widgets**
- [ ] **Step 4: Run; PASS**
- [ ] **Step 5: Commit** `feat(dive-lab): chart host, branch controls, mode toggle, intervention chips and sheet`

---

### Task 8: `DiveLabPage` + `showDiveLab`

**Files:**
- Create: `lib/features/dive_lab/presentation/pages/dive_lab_page.dart`
- Test: `test/features/dive_lab/presentation/pages/dive_lab_page_test.dart`

**Interfaces:**
```dart
class DiveLabPage extends ConsumerStatefulWidget { const DiveLabPage({super.key, required String diveId}); }
Future<void> showDiveLab(BuildContext context, String diveId) => Navigator.of(context, rootNavigator: true).push(MaterialPageRoute<void>(builder: (_) => DiveLabPage(diveId: diveId)));
```
Behaviour: watches `labRequestInputsProvider(diveId)` (loading -> centered progress + `diveLab_loading`; null -> empty state with `diveLab_empty_ineligible`); seeds the draft once from `labDefaultBranchProvider(diveId)` in a `ref.listen`/post-frame (`seedBranch`); watches `scenarioOutcomeProvider(diveId)`; layout: `LayoutBuilder`: width >= 1160 -> `Row[Expanded(flex: 3, Column[LabChart (Expanded), controls]), SizedBox(width: 420, child: scroll(LabDeltaPanel))]`; else `Column[SizedBox(height: 0.4 * maxHeight, LabChart), Expanded(ListView[controls, LabDeltaPanel])]` where controls = `LabBranchControls`, `LabModeToggle`, `LabInterventionChips`. AppBar title `diveLab_title` (Save/Share/Saved actions arrive in Phases 3 and 5).

- [ ] **Step 1: Write the failing widget test** (override `labRequestInputsProvider(id)` with inputs from `squareDive()`, `labDefaultBranchProvider(id)` with 900, `scenarioEngineRunnerProvider` with a synchronous runner; pump `testApp(child: DiveLabPage(diveId: id))` at 420x800 and at 1280x800; `await tester.pump(const Duration(milliseconds: 300))`; expect `find.byType(DiveProfileChart)`, the Replay/Re-plan toggle, the branch readout "15:00", the Add chip; tap "+1 min" and expect "16:00"; select Re-plan and expect the draft mode; on 1280 width expect the panel beside the chart (`find.byType(LabDeltaPanel)` present in both).
- [ ] **Step 2: Run, expect failure**
- [ ] **Step 3: Implement**
- [ ] **Step 4: Run; PASS**
- [ ] **Step 5: Commit** `feat(dive-lab): Dive Lab page with phone and wide layouts`

---

### Task 9: Entry points on dive detail

**Files:**
- Modify: `lib/features/dive_log/presentation/pages/dive_detail_page.dart` (toolbar `IconButton(icon: Icons.science, tooltip: l10n.diveLab_tooltip_open)` after the `Icons.terrain` button at ~1758, shown only when `!dive.isGauge && dive.profile.length >= 2`; `'whatIf'` case + `PopupMenuItem` in BOTH `PopupMenuButton<String>` menus (~851 and ~1029), guarded the same way; all call `showDiveLab(context, dive.id)`)

- [ ] **Step 1: Make the edits**
- [ ] **Step 2: `flutter analyze lib/features/dive_log/presentation/pages/dive_detail_page.dart` clean; run `flutter test test/features/dive_log/presentation/pages/` (existing detail page tests still pass)**
- [ ] **Step 3: Commit** `feat(dive-lab): open the Dive Lab from dive detail`

---

### Task 10: Verification

- [ ] `dart format lib test`; `flutter analyze` whole project clean
- [ ] `flutter test test/features/dive_lab test/features/dive_log/presentation test/features/planner test/core/deco`
- [ ] Commit any fixes: `chore(dive-lab): phase 2 verification`

## Self-review notes

- Spec UI coverage in Phase 2: lab page (root push, entry points, layout), chart with ghost overlay and branch marker, branch controls (slider + steppers; the chart's `onPointSelected` is deliberately not wired because it fires on mouse hover, which would move the branch under the pointer), mode toggle with forced state, chips + add sheet for the five core kinds, delta panel with verdict/tiles/table/tissue strips/gas rows/issues/runtime/notes, recompute debounce + dimming. Deferred to later phases: Save/Share/Saved (3, 5), buoyancy rows and bailOut/ascentPolicy editors (4), teaser card (3).
- Counterfactual curves in the chart: in re-plan mode the counterfactual analysis runs over the spliced profile (different length), so the chart keeps the ACTUAL ceiling/stop curves and shows the what-if only as the ghost path; in replay mode (same length) it shows the what-if ceiling and stops.
