# DPV Mission Canvas, PR 3b (results) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Show what a DPV mission's failure scenarios conclude, on the plan canvas: the limiting diver and factor in one sentence, a card per diver, a list of waypoints with who survives a scooter failure there and how, a leg table, and a status chip for blocking issues, with the mission engine running in an isolate.

**Architecture:** A new `missionOutcomeProvider` (a `FutureProvider<MissionOutcome?>`) watches the editing state and the engine config and runs `MissionEngine.compute` through `Isolate.run`, behind an injectable runner so widget tests can run it synchronously. A "Mission" section in `PlanResultsSheet` renders the outcome through small widgets, all numbers in the diver's units and rounded in the conservative direction. A self-gating chip joins `PlanStatusChips`.

**Tech Stack:** Flutter, Dart 3 (`dart:isolate`), Riverpod 3 (`FutureProvider`), `flutter_test`, gen-l10n.

**Spec:** `docs/superpowers/specs/2026-09-18-dpv-mission-planner-design.md`, "User interface" (Results, Providers, Units) and "Error handling" (issue #2086). Decision taken with the user on 2026-09-28: the mission engine always runs in an isolate (no measurement gate), which replaces the spec's "measure, then move to an isolate" sentence; Task 7 records that in the spec.

**Depends on:** PR 3a (`docs/superpowers/plans/2026-09-28-dpv-mission-canvas-editing.md`) merged: this plan uses its `missionIssueText`, `missionLegName` and `MissionUnits`. Start with `git fetch origin && git merge origin/main` and `dart run build_runner build --delete-conflicting-outputs`.

## Global Constraints

- Every Global Constraint of the PR 3a plan applies unchanged (no dashes as punctuation, no tool attribution, immutability, `PlanNumberField`/`NumberField` only, no literal `/min`, units per the diver's settings, all strings in all 11 ARB files with `flutter gen-l10n` last, files under 400 lines, `Expanded` around labels in rows, tests restore global state, format and analyze before commits, `Refs #2086` in commits).
- Conservative rounding for every displayed planning figure: minutes and battery percent round **up** (`ceil`), a turn pressure rounds **up** in the display unit (turning early is safe), a distance home rounds **up**. Never round a mission figure to the nearest value.
- Never show a computed figure without its assumptions: the section states the battery reserve fraction and that the failed diver breathes the stressed SAC until the first stop.
- Minutes are shown with the planner's prime convention (`{minutes}′`, as `plannerCanvas_bailout_tts` does).
- The engine runs only through `missionEngineRunnerProvider`; nothing in `lib/` calls `MissionEngine.compute` on the UI isolate.
- The PR body says `Closes #2086` (this is the last PR of the feature) and carries screenshots.

## Review Focus

1. **Editing while a computation is in flight**: the section never shows an outcome for a mission other than the current one (a stale result from the previous edit must not be displayed as current). Tested in Task 1.
2. **A blocked mission** (empty team, a scooter with no numbers, a leg the current blocks): the section lists why instead of an empty table, and the chip counts the blocking issues. Tested in Tasks 4 and 5.
3. **A solo diver**: the tow line reads "no buddy", never an empty cell or a crash. Tested in Task 4.
4. **Imperial units**: distances in feet, speeds in ft/min, turn pressure in psi rounded up. Tested in Task 3.
5. **Three divers at 320 pt**: every card and waypoint block fits without overflow, with long German labels. Tested in Task 4.

---

## File Structure

| File | Status | Responsibility |
| --- | --- | --- |
| `lib/features/planner/presentation/providers/mission_outcome_provider.dart` | create | runner seam, isolate runner, `missionOutcomeProvider` |
| `lib/features/planner/presentation/mission/mission_result_text.dart` | create | constraint sentence, factor labels, conservative number formatting |
| `lib/features/planner/presentation/mission/mission_member_result_card.dart` | create | one diver: battery bar with the reserve, cruise setter, binding, turn pressure |
| `lib/features/planner/presentation/mission/mission_waypoint_list.dart` | create | one block per waypoint: distance, arrival, safe surface, each diver's exits |
| `lib/features/planner/presentation/mission/mission_leg_table.dart` | create | out and back speed and duration per leg |
| `lib/features/planner/presentation/mission/mission_results_section.dart` | create | the section: loading, blocked, or the full result |
| `lib/features/planner/presentation/widgets/plan_results_sheet.dart` | modify | the "Mission" section while a mission is on |
| `lib/features/planner/presentation/widgets/plan_status_chips.dart` | modify | `MissionIssuesChip` |
| `lib/l10n/arb/app_*.arb` (11) and generated `app_localizations*.dart` (12) | modify | the strings |
| `docs/superpowers/specs/2026-09-18-dpv-mission-planner-design.md` | modify | the isolate decision |

---

### Task 1: The mission outcome, in an isolate

**Files:**
- Create: `lib/features/planner/presentation/providers/mission_outcome_provider.dart`
- Test: `test/features/planner/mission/mission_outcome_provider_test.dart`

**Interfaces:**
- Produces:
  - `typedef MissionEngineRunner = Future<MissionOutcome> Function(domain.DivePlan plan, DpvMission mission, PlanEngineConfig config);`
  - `Future<MissionOutcome> runMissionEngineInIsolate(domain.DivePlan plan, DpvMission mission, PlanEngineConfig config)`
  - `final missionEngineRunnerProvider = Provider<MissionEngineRunner>(...)` (default: the isolate runner)
  - `final missionOutcomeProvider = FutureProvider<MissionOutcome?>(...)` (null when the plan has no mission)

- [ ] **Step 1: Write the failing test**

```dart
// test/features/planner/mission/mission_outcome_provider_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/map_style.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    as domain;
import 'package:submersion/features/planner/domain/entities/mission/dpv_mission.dart';
import 'package:submersion/features/planner/domain/entities/mission/mission_outcome.dart';
import 'package:submersion/features/planner/domain/entities/mission/scooter_spec.dart';
import 'package:submersion/features/planner/domain/services/dive_plan_state_mapper.dart';
import 'package:submersion/features/planner/domain/services/mission/mission_edits.dart';
import 'package:submersion/features/planner/domain/services/mission/mission_engine.dart';
import 'package:submersion/features/planner/domain/services/plan_engine.dart';
import 'package:submersion/features/planner/presentation/providers/mission_outcome_provider.dart';

/// A two-diver mission the engine can compute: 300 m at 20 m on 0.9 m/s
/// scooters.
void _buildMission(ProviderContainer container) {
  final notifier = container.read(divePlanNotifierProvider.notifier);
  notifier.addTank(
    const DiveTank(
      id: 'back',
      volume: 24,
      startPressure: 230,
      gasMix: GasMix(o2: 21),
      role: TankRole.backGas,
    ),
  );
  var m = MissionEdits.starter(
    legId: 'L1',
    memberId: 'a',
    memberName: 'Sam',
    sacBottom: 15,
  );
  m = MissionEdits.addMember(m, 'b', name: 'Alex', sacBottom: 14);
  m = MissionEdits.updateLeg(
    m,
    m.legs.single.copyWith(label: 'T', distanceM: 300, depthM: 20),
  );
  const scooter = ScooterSpec(
    name: 'Blacktip',
    ratedSpeedMps: 0.9,
    burnTimeSeconds: 5400,
  );
  m = m.copyWith(team: [for (final t in m.team) t.copyWith(scooter: scooter)]);
  notifier.enableMission(m);
}

/// Runs the engine on the calling isolate; widget tests cannot wait on a
/// real isolate inside testWidgets.
Future<MissionOutcome> _syncRunner(
  domain.DivePlan plan,
  DpvMission mission,
  PlanEngineConfig config,
) async => MissionEngine().compute(plan: plan, mission: mission);

void main() {
  test('no mission, no outcome', () async {
    final container = ProviderContainer(
      overrides: [missionEngineRunnerProvider.overrideWithValue(_syncRunner)],
    );
    addTearDown(container.dispose);
    expect(await container.read(missionOutcomeProvider.future), isNull);
  });

  test('a mission is computed with the diver engine config', () async {
    PlanEngineConfig? seen;
    final container = ProviderContainer(
      overrides: [
        missionEngineRunnerProvider.overrideWithValue((plan, mission, config) {
          seen = config;
          return _syncRunner(plan, mission, config);
        }),
      ],
    );
    addTearDown(container.dispose);
    _buildMission(container);
    final outcome = await container.read(missionOutcomeProvider.future);
    expect(outcome!.waypoints, hasLength(1));
    expect(seen, isNotNull);
  });

  test('the outcome follows the latest edit, not an earlier one', () async {
    final container = ProviderContainer(
      overrides: [missionEngineRunnerProvider.overrideWithValue(_syncRunner)],
    );
    addTearDown(container.dispose);
    _buildMission(container);
    final notifier = container.read(divePlanNotifierProvider.notifier);
    final mission = container.read(divePlanNotifierProvider).mission!;
    // Two edits in a row; only the second may be reported.
    notifier.updateMission(
      MissionEdits.addLeg(mission, 'L2'),
    );
    notifier.updateMission(
      MissionEdits.updateLeg(
        MissionEdits.addLeg(mission, 'L2'),
        MissionEdits.addLeg(mission, 'L2').legs.last.copyWith(distanceM: 100),
      ),
    );
    final outcome = await container.read(missionOutcomeProvider.future);
    expect(outcome!.waypoints, hasLength(2));
  });

  test('the isolate runner computes the same outcome', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    _buildMission(container);
    final state = container.read(divePlanNotifierProvider);
    final plan = divePlanFromState(state);
    const config = PlanEngineConfig();
    final inIsolate = await runMissionEngineInIsolate(
      plan,
      state.mission!,
      config,
    );
    expect(
      inIsolate,
      MissionEngine().compute(plan: plan, mission: state.mission!),
    );
  });
}
```

`DivePlanNotifier`'s provider reads a repository and settings when built; if `ProviderContainer()` with no overrides cannot build it, copy the overrides `dive_planner_providers_test.dart` uses into each container.

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/features/planner/mission/mission_outcome_provider_test.dart`
Expected: FAIL, `mission_outcome_provider.dart` does not resolve.

- [ ] **Step 3: Write the provider**

```dart
// lib/features/planner/presentation/providers/mission_outcome_provider.dart
import 'dart:isolate';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    as domain;
import 'package:submersion/features/planner/domain/entities/mission/dpv_mission.dart';
import 'package:submersion/features/planner/domain/entities/mission/mission_outcome.dart';
import 'package:submersion/features/planner/domain/services/dive_plan_state_mapper.dart';
import 'package:submersion/features/planner/domain/services/mission/mission_engine.dart';
import 'package:submersion/features/planner/domain/services/mission/mission_scenario_service.dart';
import 'package:submersion/features/planner/domain/services/plan_engine.dart';
import 'package:submersion/features/planner/presentation/providers/plan_canvas_providers.dart';

/// Computes a mission outcome. Injectable so tests can run it on the
/// calling isolate.
typedef MissionEngineRunner =
    Future<MissionOutcome> Function(
      domain.DivePlan plan,
      DpvMission mission,
      PlanEngineConfig config,
    );

/// Runs the mission engine on a background isolate. A realistic mission is
/// dozens of full plan-engine runs, which would drop frames on the UI
/// isolate; the plan, the mission and the config are plain values, so they
/// cross the isolate boundary by copy.
Future<MissionOutcome> runMissionEngineInIsolate(
  domain.DivePlan plan,
  DpvMission mission,
  PlanEngineConfig config,
) {
  return Isolate.run(
    () => MissionEngine(
      scenarios: MissionScenarioService(engine: PlanEngine(config: config)),
    ).compute(plan: plan, mission: mission),
  );
}

final missionEngineRunnerProvider = Provider<MissionEngineRunner>(
  (ref) => runMissionEngineInIsolate,
);

/// The failure-scenario outcome of the plan's DPV mission, or null when the
/// plan has none. Recomputed on every edit and settings change; Riverpod
/// drops the result of a computation superseded by a newer edit, so a stale
/// outcome is never delivered as current.
final missionOutcomeProvider = FutureProvider<MissionOutcome?>((ref) async {
  final state = ref.watch(divePlanNotifierProvider);
  final mission = state.mission;
  if (mission == null) return null;
  final config = ref.watch(planEngineConfigProvider);
  final runner = ref.watch(missionEngineRunnerProvider);
  return runner(divePlanFromState(state), mission, config);
});
```

Check `MissionEngine`'s constructor takes `scenarios:` and `MissionScenarioService`'s takes `engine:` (both confirmed in the design notes; `mission_engine.dart:28`, `mission_scenario_service.dart:34`).

- [ ] **Step 4: Run the tests**

Run: `flutter test test/features/planner/mission/mission_outcome_provider_test.dart test/architecture/`
Expected: PASS, 4 tests. If "the isolate runner computes the same outcome" fails with an "Illegal argument in isolate message" error, a value in `DivePlan` or `DpvMission` is not sendable (a closure or a native resource): find it in the error, and report it rather than working around it, since it means the entity carries more than data.

- [ ] **Step 5: Commit**

```bash
dart format lib/features/planner test/features/planner
git add lib/features/planner/presentation/providers/mission_outcome_provider.dart test/features/planner/mission/mission_outcome_provider_test.dart
git commit -m "feat(planner): compute the DPV mission outcome on a background isolate

Refs #2086"
```

---

### Task 2: The strings

**Files:**
- Modify: `lib/l10n/arb/app_en.arb` and the ten locale files, then regenerate.

**Keys** (English; placeholders are `String` unless marked):

| Key | English |
| --- | --- |
| `plannerMission_results_title` | Mission |
| `plannerMission_results_computing` | Working out the failure scenarios |
| `plannerMission_results_blocked` | The mission cannot be computed yet: |
| `plannerMission_results_limitedBy` | Limited by {name}'s {scooter} at {waypoint}: {factor} |
| `plannerMission_results_limitedByDiver` | Limited by {name} at {waypoint}: {factor} |
| `plannerMission_results_unconstrained` | Every waypoint is survivable for any single scooter failure |
| `plannerMission_results_assumptions` | Battery reserve {reserve}% of burn time. A diver whose scooter fails breathes the plan's stressed SAC until the first stop. |
| `plannerMission_results_abandonment` | Last waypoint every diver can get out from: {waypoint} |
| `plannerMission_results_noAbandonment` | No waypoint is survivable for every failure |
| `plannerMission_factor_battery` | battery reserve |
| `plannerMission_factor_ownGas` | own gas |
| `plannerMission_factor_teamGas` | a teammate's gas |
| `plannerMission_factor_exposure` | oxygen exposure |
| `plannerMission_factor_blockedByCurrent` | a current that blocks the way out |
| `plannerMission_factor_noFeasibleTow` | no workable tow |
| `plannerMission_factor_surfaceSwimLimit` | the surface swim limit |
| `plannerMission_factor_scenarioFailed` | a failure scenario that could not be computed |
| `plannerMission_results_battery` | Battery {percent}% of burn time ({minutes}′), reserve {reserve}% |
| `plannerMission_results_setsCruise` | Sets the team's cruise speed |
| `plannerMission_results_bindsAt` | Limit at {waypoint}: {factor} |
| `plannerMission_results_noLimit` | No limit on this route |
| `plannerMission_results_turnPressure` | Turn at {pressure} |
| `plannerMission_results_waypoints` | Waypoints |
| `plannerMission_results_waypointLine` | {distance}, arrive {minutes}′ |
| `plannerMission_results_safeSurface` | Safe surface in {minutes}′ |
| `plannerMission_results_home` | {distance} straight home |
| `plannerMission_results_survives` | gets out |
| `plannerMission_results_cannotGetOut` | cannot get out |
| `plannerMission_results_swim` | swim {minutes}′ |
| `plannerMission_results_tow` | tow by {name} {minutes}′ |
| `plannerMission_results_surface` | surface {minutes}′ |
| `plannerMission_results_surfaceViaShore` | surface via the shore {minutes}′ |
| `plannerMission_results_noBuddy` | no buddy |
| `plannerMission_results_legs` | Legs |
| `plannerMission_results_legLine` | out {outSpeed} {outMinutes}′, back {backSpeed} {backMinutes}′ |
| `plannerMission_chip_issues` | {count, plural, =1{Mission: {count} issue} other{Mission: {count} issues}} (`count`: int) |

- [ ] **Step 1: Add, translate, check and regenerate**

Follow PR 3a's Task 4 Steps 1 to 3 exactly (anchor-based insertion with `python3.14`, English sorted, real translations in the ten locales keeping placeholders verbatim and the `′` prime, the JSON and `numstat` checks, `flutter gen-l10n` last, the `grep -A1 "get plannerMission_results_title" lib/l10n/arb/app_localizations_de.dart` check, then `flutter test test/l10n/`). The plural key's `=1{...}` branch interpolates `{count}` as written above.

- [ ] **Step 2: Commit**

```bash
git add lib/l10n/arb
git commit -m "i18n(planner): DPV mission results strings in every language

Refs #2086"
```

---

### Task 3: Result text and conservative numbers

**Files:**
- Create: `lib/features/planner/presentation/mission/mission_result_text.dart`
- Test: `test/features/planner/mission/mission_result_text_test.dart`

**Interfaces:**
- Produces:
  - `String missionFactorLabel(AppLocalizations l10n, MissionBindingFactor factor)`
  - `String missionConstraintText(AppLocalizations l10n, MissionOutcome outcome, DpvMission mission)`: the "Limited by ..." sentence, or the unconstrained sentence when `outcome.constraint` is null.
  - `int ceilMinutes(int seconds)`
  - `String ceilPercent(double fraction)` (e.g. `0.334` gives `"34"`)
  - `String ceilPressure(UnitFormatter units, double bar)` (e.g. "171 bar", "2466 psi")
  - `String ceilDistance(UnitFormatter units, double meters)` (e.g. "213m", "699ft")

- [ ] **Step 1: Write the failing test**

```dart
// test/features/planner/mission/mission_result_text_test.dart
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/planner/domain/entities/mission/mission_outcome.dart';
import 'package:submersion/features/planner/domain/entities/mission/scooter_spec.dart';
import 'package:submersion/features/planner/domain/services/mission/mission_edits.dart';
import 'package:submersion/features/planner/presentation/mission/mission_result_text.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
  late AppLocalizations l10n;
  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  final base = MissionEdits.starter(
    legId: 'L1',
    memberId: 'm1',
    memberName: 'Sam',
    sacBottom: 15,
  );
  final mission = MissionEdits.updateLeg(
    MissionEdits.updateMember(
      base,
      base.team.single.copyWith(
        scooter: const ScooterSpec(
          name: 'Blacktip',
          ratedSpeedMps: 0.9,
          burnTimeSeconds: 5400,
        ),
      ),
    ),
    base.legs.single.copyWith(label: 'T'),
  );

  test('the constraint sentence names the diver, scooter, place and factor', () {
    const limited = MissionOutcome(
      segments: [],
      cruiseSpeedMps: 0.9,
      legs: [],
      waypoints: [],
      members: [],
      abandonmentIndex: null,
      constraint: MissionConstraint(
        memberId: 'm1',
        factor: MissionBindingFactor.battery,
        waypointIndex: 0,
      ),
      issues: [],
    );
    expect(
      missionConstraintText(l10n, limited, mission),
      "Limited by Sam's Blacktip at T: battery reserve",
    );
  });

  test('a constraint naming a diver no longer on the team reads as computing', () {
    const stale = MissionOutcome(
      segments: [],
      cruiseSpeedMps: 0.9,
      legs: [],
      waypoints: [],
      members: [],
      abandonmentIndex: null,
      constraint: MissionConstraint(
        memberId: 'gone',
        factor: MissionBindingFactor.battery,
        waypointIndex: 0,
      ),
      issues: [],
    );
    expect(
      missionConstraintText(l10n, stale, mission),
      'Working out the failure scenarios',
    );
  });

  test('every binding factor has a label', () {
    for (final factor in MissionBindingFactor.values) {
      expect(missionFactorLabel(l10n, factor), isNotEmpty, reason: factor.name);
    }
  });

  test('numbers round up, never to nearest', () {
    expect(ceilMinutes(61), 2);
    expect(ceilMinutes(60), 1);
    expect(ceilPercent(0.334), '34');
    final metric = UnitFormatter(const AppSettings());
    expect(ceilPressure(metric, 170.2), '171 bar');
    expect(ceilDistance(metric, 212.1), '213m');
    final imperial = UnitFormatter(
      const AppSettings(
        depthUnit: DepthUnit.feet,
        pressureUnit: PressureUnit.psi,
      ),
    );
    // 170.2 bar is 2468.6 psi: up to 2469.
    expect(ceilPressure(imperial, 170.2), '2469 psi');
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/features/planner/mission/mission_result_text_test.dart`
Expected: FAIL, `mission_result_text.dart` does not resolve.

- [ ] **Step 3: Write the helpers**

```dart
// lib/features/planner/presentation/mission/mission_result_text.dart
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/planner/domain/entities/mission/dpv_mission.dart';
import 'package:submersion/features/planner/domain/entities/mission/mission_outcome.dart';
import 'package:submersion/features/planner/presentation/mission/mission_issue_text.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

String missionFactorLabel(AppLocalizations l10n, MissionBindingFactor f) =>
    switch (f) {
      MissionBindingFactor.battery => l10n.plannerMission_factor_battery,
      MissionBindingFactor.ownGas => l10n.plannerMission_factor_ownGas,
      MissionBindingFactor.teamGas => l10n.plannerMission_factor_teamGas,
      MissionBindingFactor.exposure => l10n.plannerMission_factor_exposure,
      MissionBindingFactor.blockedByCurrent =>
        l10n.plannerMission_factor_blockedByCurrent,
      MissionBindingFactor.noFeasibleTow =>
        l10n.plannerMission_factor_noFeasibleTow,
      MissionBindingFactor.surfaceSwimLimit =>
        l10n.plannerMission_factor_surfaceSwimLimit,
      MissionBindingFactor.scenarioFailed =>
        l10n.plannerMission_factor_scenarioFailed,
    };

/// "Limited by Sam's Blacktip at T: battery reserve", or the unconstrained
/// sentence when no member binds anywhere on the route.
String missionConstraintText(
  AppLocalizations l10n,
  MissionOutcome outcome,
  DpvMission mission,
) {
  final c = outcome.constraint;
  if (c == null) return l10n.plannerMission_results_unconstrained;
  final member = mission.team.where((t) => t.id == c.memberId).firstOrNull;
  // An outcome computed before the latest edit can name a diver or waypoint
  // the mission no longer has; its replacement is on the way.
  if (member == null || c.waypointIndex >= mission.legs.length) {
    return l10n.plannerMission_results_computing;
  }
  final waypoint = missionLegName(l10n, mission.legs[c.waypointIndex]);
  final factor = missionFactorLabel(l10n, c.factor);
  final scooter = member.scooter.name.trim();
  return scooter.isEmpty
      ? l10n.plannerMission_results_limitedByDiver(
          member.displayName,
          waypoint,
          factor,
        )
      : l10n.plannerMission_results_limitedBy(
          member.displayName,
          scooter,
          waypoint,
          factor,
        );
}

/// Whole minutes, rounded up: a planning time is never shown shorter than
/// it is.
int ceilMinutes(int seconds) => (seconds / 60).ceil();

/// A fraction as a whole percent, rounded up.
String ceilPercent(double fraction) => (fraction * 100).ceil().toString();

/// A turn pressure in the diver's unit, rounded up: turning early is safe.
String ceilPressure(UnitFormatter units, double bar) =>
    '${units.convertPressure(bar).ceil()} ${units.pressureSymbol}';

/// A distance in the depth unit, rounded up.
String ceilDistance(UnitFormatter units, double meters) =>
    '${units.convertDepth(meters).ceil()}${units.depthSymbol}';
```

A `MissionConstraint`'s waypoint index is a position in the route's legs (waypoint k is the end of leg k); a route cut at an untraversable leg is a prefix of the mission's legs, so the index is always valid for the current mission unless the outcome is stale, which the guard handles.

- [ ] **Step 4: Run the tests and commit**

```bash
flutter test test/features/planner/mission/mission_result_text_test.dart test/architecture/
dart format lib/features/planner test/features/planner
git add lib/features/planner/presentation/mission/mission_result_text.dart test/features/planner/mission/mission_result_text_test.dart
git commit -m "feat(planner): the DPV mission's constraint sentence, with every figure rounded the safe way

Refs #2086"
```

---

### Task 4: The Mission results section

**Files:**
- Create: `lib/features/planner/presentation/mission/mission_member_result_card.dart`
- Create: `lib/features/planner/presentation/mission/mission_waypoint_list.dart`
- Create: `lib/features/planner/presentation/mission/mission_leg_table.dart`
- Create: `lib/features/planner/presentation/mission/mission_results_section.dart`
- Modify: `lib/features/planner/presentation/widgets/plan_results_sheet.dart`
- Test: `test/features/planner/mission/mission_results_section_test.dart`

**Interfaces:**
- Consumes: `missionOutcomeProvider` (Task 1), the text helpers (Task 3), `missionIssueText`/`missionLegName`/`MissionUnits` (PR 3a).
- Produces: `MissionResultsSection` (`const MissionResultsSection({super.key})`), shown in `PlanResultsSheet` under `PlanSectionHeader(l10n.plannerMission_results_title)` while `state.mission != null`.

- [ ] **Step 1: Write the failing widget test**

```dart
// test/features/planner/mission/mission_results_section_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    as domain;
import 'package:submersion/features/planner/domain/entities/mission/dpv_mission.dart';
import 'package:submersion/features/planner/domain/entities/mission/mission_outcome.dart';
import 'package:submersion/features/planner/domain/entities/mission/scooter_spec.dart';
import 'package:submersion/features/planner/domain/services/mission/mission_edits.dart';
import 'package:submersion/features/planner/domain/services/mission/mission_engine.dart';
import 'package:submersion/features/planner/presentation/mission/mission_results_section.dart';
import 'package:submersion/features/planner/domain/services/plan_engine.dart';
import 'package:submersion/features/planner/presentation/providers/mission_outcome_provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../helpers/test_app.dart';

class _TestSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _TestSettingsNotifier() : super(const AppSettings());

  @override
  Future<void> setMapStyle(MapStyle style) async =>
      state = state.copyWith(mapStyle: style);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<MissionOutcome> _syncRunner(
  domain.DivePlan plan,
  DpvMission mission,
  PlanEngineConfig config,
) async => MissionEngine().compute(plan: plan, mission: mission);

DpvMission _mission({int divers = 2}) {
  var m = MissionEdits.starter(
    legId: 'L1',
    memberId: 'a',
    memberName: 'Samantha Richardson',
    sacBottom: 15,
  );
  for (var i = 1; i < divers; i++) {
    m = MissionEdits.addMember(m, 'm$i', name: 'Alexandra $i', sacBottom: 14);
  }
  m = MissionEdits.updateLeg(
    m,
    m.legs.single.copyWith(label: 'Erster Abzweig', distanceM: 300, depthM: 20),
  );
  const scooter = ScooterSpec(
    name: 'Blacktip',
    ratedSpeedMps: 0.9,
    burnTimeSeconds: 5400,
  );
  return m.copyWith(
    team: [for (final t in m.team) t.copyWith(scooter: scooter)],
  );
}

Future<ProviderContainer> _pump(
  WidgetTester tester, {
  required double width,
  DpvMission? mission,
}) async {
  tester.view.physicalSize = Size(width, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    testApp(
      locale: const Locale('en'),
      overrides: [
        settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
        missionEngineRunnerProvider.overrideWithValue(_syncRunner),
      ],
      child: const SingleChildScrollView(child: MissionResultsSection()),
    ),
  );
  final container = ProviderScope.containerOf(
    tester.element(find.byType(MissionResultsSection)),
  );
  final notifier = container.read(divePlanNotifierProvider.notifier);
  notifier.addTank(
    const DiveTank(
      id: 'back',
      volume: 24,
      startPressure: 230,
      gasMix: GasMix(o2: 21),
      role: TankRole.backGas,
    ),
  );
  notifier.enableMission(mission ?? _mission());
  await tester.pumpAndSettle();
  return container;
}

void main() {
  testWidgets('a computed mission shows the sentence, cards and waypoints', (
    tester,
  ) async {
    await _pump(tester, width: 400);
    // Exactly one constraint sentence, whichever the engine concludes.
    expect(
      find.textContaining(RegExp(r'^(Limited by|Every waypoint is survivable)')),
      findsOneWidget,
    );
    // The default reserve is one third, shown rounded up.
    expect(find.textContaining('reserve 34%'), findsNWidgets(2));
    expect(find.text('Waypoints'), findsOneWidget);
    expect(find.text('Legs'), findsOneWidget);
  });

  testWidgets('removing a diver before the new outcome lands does not throw', (
    tester,
  ) async {
    final container = await _pump(tester, width: 400);
    final notifier = container.read(divePlanNotifierProvider.notifier);
    final mission = container.read(divePlanNotifierProvider).mission!;
    notifier.updateMission(MissionEdits.removeMember(mission, 'm1'));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('a solo diver reads no buddy for the tow', (tester) async {
    await _pump(tester, width: 400, mission: _mission(divers: 1));
    expect(find.textContaining('no buddy'), findsWidgets);
  });

  testWidgets('a blocked mission lists why', (tester) async {
    await _pump(
      tester,
      width: 400,
      mission: MissionEdits.starter(
        legId: 'L1',
        memberId: 'a',
        memberName: 'Sam',
        sacBottom: 15,
      ),
    );
    expect(find.textContaining('cannot be computed yet'), findsOneWidget);
    expect(find.textContaining("Sam's scooter needs"), findsOneWidget);
  });

  testWidgets('three divers fit a 320 pt phone', (tester) async {
    await _pump(tester, width: 320, mission: _mission(divers: 3));
    expect(tester.takeException(), isNull);
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/features/planner/mission/mission_results_section_test.dart`
Expected: FAIL, `mission_results_section.dart` does not resolve.

- [ ] **Step 3: Write the diver card**

```dart
// lib/features/planner/presentation/mission/mission_member_result_card.dart
import 'package:flutter/material.dart';

import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/planner/domain/entities/mission/dpv_mission.dart';
import 'package:submersion/features/planner/domain/entities/mission/mission_member.dart';
import 'package:submersion/features/planner/domain/entities/mission/mission_outcome.dart';
import 'package:submersion/features/planner/presentation/mission/mission_issue_text.dart';
import 'package:submersion/features/planner/presentation/mission/mission_result_text.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// One diver's result: the round-trip battery against the reserve, whether
/// their scooter sets the team's speed, where and why they bind, and their
/// turn pressure.
class MissionMemberResultCard extends StatelessWidget {
  const MissionMemberResultCard({
    super.key,
    required this.member,
    required this.result,
    required this.mission,
    required this.units,
  });

  final MissionMember member;
  final MemberOutcome result;
  final DpvMission mission;
  final UnitFormatter units;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final used = result.batteryRoundTripFraction.clamp(0.0, 1.0);
    final reserve = mission.batteryReserveFraction;
    final overReserve = result.batteryRoundTripFraction > 1 - reserve;
    final binding = result.bindingFactor;
    final bindingIndex = result.bindingWaypointIndex;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              member.displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 6),
            _BatteryBar(
              used: used,
              reserve: reserve,
              overReserve: overReserve,
            ),
            Text(
              l10n.plannerMission_results_battery(
                ceilPercent(result.batteryRoundTripFraction),
                ceilMinutes(
                  (result.batteryRoundTripFraction *
                          member.scooter.burnTimeSeconds)
                      .round(),
                ).toString(),
                ceilPercent(reserve),
              ),
              style: theme.textTheme.bodySmall,
            ),
            if (result.setsCruiseSpeed)
              Text(
                l10n.plannerMission_results_setsCruise,
                style: theme.textTheme.bodySmall,
              ),
            Text(
              binding == null ||
                      bindingIndex == null ||
                      bindingIndex >= mission.legs.length
                  ? l10n.plannerMission_results_noLimit
                  : l10n.plannerMission_results_bindsAt(
                      missionLegName(l10n, mission.legs[bindingIndex]),
                      missionFactorLabel(l10n, binding),
                    ),
              style: theme.textTheme.bodySmall,
            ),
            if (result.turnPressureBar != null)
              Text(
                l10n.plannerMission_results_turnPressure(
                  ceilPressure(units, result.turnPressureBar!),
                ),
                style: theme.textTheme.bodySmall,
              ),
          ],
        ),
      ),
    );
  }
}

/// A bar for the round-trip battery use, with the reserve marked from the
/// right. The fill turns to the error colour once it reaches the reserve.
class _BatteryBar extends StatelessWidget {
  const _BatteryBar({
    required this.used,
    required this.reserve,
    required this.overReserve,
  });

  final double used;
  final double reserve;
  final bool overReserve;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 10,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          return Stack(
            children: [
              Container(color: scheme.surfaceContainerHighest),
              Container(
                width: width * used,
                color: overReserve ? scheme.error : scheme.primary,
              ),
              Positioned(
                left: width * (1 - reserve) - 1,
                top: 0,
                bottom: 0,
                child: Container(width: 2, color: scheme.onSurface),
              ),
            ],
          );
        },
      ),
    );
  }
}
```

- [ ] **Step 4: Write the waypoint list and the leg table**

```dart
// lib/features/planner/presentation/mission/mission_waypoint_list.dart
import 'package:flutter/material.dart';

import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/planner/domain/entities/mission/dpv_mission.dart';
import 'package:submersion/features/planner/domain/entities/mission/mission_outcome.dart';
import 'package:submersion/features/planner/presentation/mission/mission_issue_text.dart';
import 'package:submersion/features/planner/presentation/mission/mission_result_text.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// One block per waypoint: where it is, when the team arrives, the time to
/// a safe surface, and for each diver whether a scooter failure there still
/// leaves a way out, with the exits that work and how long they take.
///
/// Blocks, not a table: a column per diver does not fit a phone.
class MissionWaypointList extends StatelessWidget {
  const MissionWaypointList({
    super.key,
    required this.outcome,
    required this.mission,
    required this.units,
  });

  final MissionOutcome outcome;
  final DpvMission mission;
  final UnitFormatter units;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final openWater = mission.environment == MissionEnvironment.openWater;
    // An outcome from before the latest edit can name a diver or waypoint
    // the mission no longer has; such rows are skipped until it is replaced.
    String? name(String memberId) =>
        mission.team.where((t) => t.id == memberId).firstOrNull?.displayName;

    String exits(MemberWaypointOutcome m) {
      final parts = <String>[
        if (m.swim.feasible)
          l10n.plannerMission_results_swim(
            ceilMinutes(m.swim.knownExitSeconds!).toString(),
          ),
        if (m.tow == null)
          l10n.plannerMission_results_noBuddy
        else if (m.tow!.feasible)
          l10n.plannerMission_results_tow(
            name(m.tow!.towerId!) ?? '',
            ceilMinutes(m.tow!.knownExitSeconds!).toString(),
          ),
        if (m.surface != null && m.surface!.feasible)
          (m.surface!.viaShore
              ? l10n.plannerMission_results_surfaceViaShore
              : l10n.plannerMission_results_surface)(
            ceilMinutes(m.surface!.knownExitSeconds!).toString(),
          ),
      ];
      return parts.join(', ');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final w in outcome.waypoints)
          if (w.index < mission.legs.length)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  missionLegName(l10n, mission.legs[w.index]),
                  style: theme.textTheme.titleSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  l10n.plannerMission_results_waypointLine(
                    ceilDistance(units, w.cumulativeDistanceM),
                    ceilMinutes(w.arrivalRuntimeSeconds).toString(),
                  ),
                  style: theme.textTheme.bodySmall,
                ),
                if (w.safeSurfaceSeconds != null)
                  Text(
                    l10n.plannerMission_results_safeSurface(
                      ceilMinutes(w.safeSurfaceSeconds!).toString(),
                    ),
                    style: theme.textTheme.bodySmall,
                  ),
                if (openWater)
                  Text(
                    l10n.plannerMission_results_home(
                      ceilDistance(units, w.directDistanceHomeM),
                    ),
                    style: theme.textTheme.bodySmall,
                  ),
                for (final m in w.members)
                  if (name(m.memberId) case final memberName?)
                  Text(
                    '$memberName: '
                    '${m.survivable ? l10n.plannerMission_results_survives : l10n.plannerMission_results_cannotGetOut}'
                    '${exits(m).isEmpty ? '' : ' (${exits(m)})'}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: m.survivable ? null : theme.colorScheme.error,
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
```

```dart
// lib/features/planner/presentation/mission/mission_leg_table.dart
import 'package:flutter/material.dart';

import 'package:submersion/features/planner/domain/entities/mission/dpv_mission.dart';
import 'package:submersion/features/planner/domain/entities/mission/mission_outcome.dart';
import 'package:submersion/features/planner/presentation/mission/mission_issue_text.dart';
import 'package:submersion/features/planner/presentation/mission/mission_result_text.dart';
import 'package:submersion/features/planner/presentation/mission/mission_units.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Out and back speed over the ground and duration for each leg.
class MissionLegTable extends StatelessWidget {
  const MissionLegTable({
    super.key,
    required this.outcome,
    required this.mission,
    required this.units,
  });

  final MissionOutcome outcome;
  final DpvMission mission;
  final MissionUnits units;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final leg in outcome.legs)
          if (mission.legs.where((l) => l.id == leg.legId).firstOrNull
              case final missionLeg?)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Text(
              '${missionLegName(l10n, missionLeg)}: '
              '${l10n.plannerMission_results_legLine(units.speed(leg.outboundSpeedMps), ceilMinutes(leg.outboundSeconds).toString(), units.speed(leg.returnSpeedMps), ceilMinutes(leg.returnSeconds).toString())}',
              style: theme.textTheme.bodySmall,
            ),
          ),
      ],
    );
  }
}
```

A feasible exit always has a known time (`knownExitSeconds` is null only for a failed or blocked exit, and neither is feasible), so the `!` on it is safe; a tow's `towerId` is set whenever its mode is `tow`.

- [ ] **Step 5: Write the section**

```dart
// lib/features/planner/presentation/mission/mission_results_section.dart
import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
import 'package:submersion/features/planner/domain/entities/mission/mission_outcome.dart';
import 'package:submersion/features/planner/presentation/mission/mission_issue_text.dart';
import 'package:submersion/features/planner/presentation/mission/mission_leg_table.dart';
import 'package:submersion/features/planner/presentation/mission/mission_member_result_card.dart';
import 'package:submersion/features/planner/presentation/mission/mission_result_text.dart';
import 'package:submersion/features/planner/presentation/mission/mission_units.dart';
import 'package:submersion/features/planner/presentation/mission/mission_waypoint_list.dart';
import 'package:submersion/features/planner/presentation/providers/mission_outcome_provider.dart';
import 'package:submersion/features/planner/presentation/widgets/plan_kit.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The "Mission" results: the constraint sentence and its assumptions, a
/// card per diver, the waypoints and the legs. While the first result is
/// computing it says so; a blocked mission lists why.
class MissionResultsSection extends ConsumerWidget {
  const MissionResultsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mission = ref.watch(divePlanNotifierProvider.select((s) => s.mission));
    if (mission == null) return const SizedBox.shrink();
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final units = UnitFormatter(ref.watch(settingsProvider));
    // Keep showing the last outcome while a newer edit computes; a new
    // result replaces it when it lands.
    final outcome = ref.watch(missionOutcomeProvider).value;
    if (outcome == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Text(
          l10n.plannerMission_results_computing,
          style: theme.textTheme.bodySmall,
        ),
      );
    }
    if (outcome.isBlocked) {
      final blocking = [
        for (final issue in outcome.issues)
          if (issue.severity == MissionIssueSeverity.blocking) issue,
      ];
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.plannerMission_results_blocked),
          for (final issue in blocking)
            Text(
              missionIssueText(l10n, issue, mission),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
        ],
      );
    }
    final abandonment = outcome.abandonmentIndex;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          missionConstraintText(l10n, outcome, mission),
          style: theme.textTheme.bodyMedium,
        ),
        Text(
          l10n.plannerMission_results_assumptions(
            ceilPercent(mission.batteryReserveFraction),
          ),
          style: theme.textTheme.bodySmall,
        ),
        Text(
          abandonment == null || abandonment >= mission.legs.length
              ? l10n.plannerMission_results_noAbandonment
              : l10n.plannerMission_results_abandonment(
                  missionLegName(l10n, mission.legs[abandonment]),
                ),
          style: theme.textTheme.bodySmall,
        ),
        for (final result in outcome.members)
          if (mission.team.where((t) => t.id == result.memberId).firstOrNull
              case final member?)
            MissionMemberResultCard(
              member: member,
              result: result,
              mission: mission,
              units: units,
            ),
        const SizedBox(height: 12),
        PlanSectionHeader(l10n.plannerMission_results_waypoints),
        MissionWaypointList(outcome: outcome, mission: mission, units: units),
        const SizedBox(height: 12),
        PlanSectionHeader(l10n.plannerMission_results_legs),
        MissionLegTable(
          outcome: outcome,
          mission: mission,
          units: MissionUnits(units),
        ),
      ],
    );
  }
}
```

`dart format` re-indents the collection `if` lines above; run it before reading the diff.

- [ ] **Step 6: Add it to the results sheet**

In `plan_results_sheet.dart`, import `mission_results_section.dart` and, in the `ListView` children directly after the gas consumption rows (`for (final usage in outcome.tankUsages) ...`), add:

```dart
        if (ref.watch(
          divePlanNotifierProvider.select((s) => s.mission != null),
        )) ...[
          const SizedBox(height: 20),
          PlanSectionHeader(context.l10n.plannerMission_results_title),
          const MissionResultsSection(),
        ],
```

- [ ] **Step 7: Run the tests**

```bash
flutter test test/features/planner/mission/mission_results_section_test.dart test/features/planner/ test/architecture/
```

Expected: PASS.

- [ ] **Step 8: Commit**

```bash
dart format lib/features/planner test/features/planner
git add lib/features/planner/presentation/mission/mission_member_result_card.dart lib/features/planner/presentation/mission/mission_waypoint_list.dart lib/features/planner/presentation/mission/mission_leg_table.dart lib/features/planner/presentation/mission/mission_results_section.dart lib/features/planner/presentation/widgets/plan_results_sheet.dart test/features/planner/mission/mission_results_section_test.dart
git commit -m "feat(planner): show the DPV mission's limit, divers, waypoints and legs in the results

Refs #2086"
```

---

### Task 5: The status chip

**Files:**
- Modify: `lib/features/planner/presentation/widgets/plan_status_chips.dart`
- Test: `test/features/planner/mission/mission_issues_chip_test.dart`

**Interfaces:**
- Produces: `MissionIssuesChip` (`const MissionIssuesChip({super.key, required this.onTap})`), appended in `PlanStatusChips` after `const FollowingChip()`, passing the chips' existing `onIssuesTap`. Hidden when there is no mission or no blocking issue.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/planner/mission/mission_issues_chip_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/map_style.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    as domain;
import 'package:submersion/features/planner/domain/entities/mission/dpv_mission.dart';
import 'package:submersion/features/planner/domain/entities/mission/mission_outcome.dart';
import 'package:submersion/features/planner/domain/services/mission/mission_edits.dart';
import 'package:submersion/features/planner/domain/services/mission/mission_engine.dart';
import 'package:submersion/features/planner/domain/services/plan_engine.dart';
import 'package:submersion/features/planner/presentation/providers/mission_outcome_provider.dart';
import 'package:submersion/features/planner/presentation/widgets/plan_status_chips.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../helpers/test_app.dart';

class _TestSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _TestSettingsNotifier() : super(const AppSettings());

  @override
  Future<void> setMapStyle(MapStyle style) async =>
      state = state.copyWith(mapStyle: style);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<MissionOutcome> _syncRunner(
  domain.DivePlan plan,
  DpvMission mission,
  PlanEngineConfig config,
) async => MissionEngine().compute(plan: plan, mission: mission);

void main() {
  testWidgets('the chip counts blocking mission issues and hides without', (
    tester,
  ) async {
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        overrides: [
          settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
          missionEngineRunnerProvider.overrideWithValue(_syncRunner),
        ],
        child: MissionIssuesChip(onTap: () {}),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Mission:'), findsNothing);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(MissionIssuesChip)),
    );
    // The starter: an empty leg and a scooter with no numbers.
    container
        .read(divePlanNotifierProvider.notifier)
        .enableMission(
          MissionEdits.starter(
            legId: 'L1',
            memberId: 'a',
            memberName: 'Sam',
            sacBottom: 15,
          ),
        );
    await tester.pumpAndSettle();
    expect(find.textContaining('Mission:'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/features/planner/mission/mission_issues_chip_test.dart`
Expected: FAIL, `MissionIssuesChip` is not defined.

- [ ] **Step 3: Write the chip**

In `plan_status_chips.dart`, import `mission_outcome_provider.dart` and `mission_outcome.dart`, add after `FollowingChip`'s class:

```dart
/// Blocking DPV mission issues, visible from every tab. Hidden when the plan
/// has no mission or the mission computes cleanly.
class MissionIssuesChip extends ConsumerWidget {
  const MissionIssuesChip({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final outcome = ref.watch(missionOutcomeProvider).value;
    if (outcome == null) return const SizedBox.shrink();
    final blocking = outcome.issues
        .where((i) => i.severity == MissionIssueSeverity.blocking)
        .length;
    if (blocking == 0) return const SizedBox.shrink();
    return PlanChip(
      label: context.l10n.plannerMission_chip_issues(blocking),
      tint: Theme.of(context).colorScheme.error,
      onTap: onTap,
    );
  }
}
```

and append `MissionIssuesChip(onTap: onIssuesTap),` after `const FollowingChip(),` in `PlanStatusChips.build`. `PlanChip.tint` is a `Color?` (`plan_status_chips.dart:39`).

- [ ] **Step 4: Run and commit**

```bash
flutter test test/features/planner/mission/mission_issues_chip_test.dart test/features/planner/ test/architecture/
dart format lib/features/planner test/features/planner
git add lib/features/planner/presentation/widgets/plan_status_chips.dart test/features/planner/mission/mission_issues_chip_test.dart
git commit -m "feat(planner): a status chip for blocking DPV mission issues

Refs #2086"
```

---

### Task 6: Record the isolate decision in the spec

**Files:**
- Modify: `docs/superpowers/specs/2026-09-18-dpv-mission-planner-design.md` ("Providers" paragraph of "User interface")

- [ ] **Step 1: Replace the measurement sentence**

Replace the sentence beginning "If a measured recompute on a realistic mission exceeds about 100 ms" (to the end of that paragraph) with:

```text
The scenario evaluation always runs on a background isolate
(`Isolate.run`, behind an injectable runner so widget tests run it
synchronously); decided on 2026-09-28 instead of measuring first, since a
realistic mission is dozens of full plan-engine runs. The results section
keeps showing the previous outcome while a newer edit computes.
```

and change "`missionOutcomeProvider` ... runs the mission engine synchronously as the plan outcome does" in the same paragraph to "runs the mission engine through that runner". Rewrap to the file's width; scan for dashes.

- [ ] **Step 2: Commit**

```bash
git add docs/superpowers/specs/2026-09-18-dpv-mission-planner-design.md
git commit -m "docs(planner): record that the DPV mission engine runs on an isolate

Refs #2086"
```

---

### Task 7: Verification, screenshots and the PR

- [ ] **Step 1: Whole-project checks**

```bash
dart format . && git status --short
flutter analyze
flutter test test/architecture/ test/l10n/
```

Expected: nothing changed; `No issues found!`; both pass.

- [ ] **Step 2: One full suite run**

```bash
flutter test --reporter=failures-only > /tmp/pr3b-suite.log 2>&1; echo "exit $?" >> /tmp/pr3b-suite.log; tail -3 /tmp/pr3b-suite.log
```

Expected: `exit 0`.

- [ ] **Step 3: Run it in the app**

Run the macOS debug build from the worktree, open a plan, turn on the mission, fill two divers and three legs (one with a current, open water with a shore exit) and confirm the Mission section appears within about a second of each edit without the canvas stalling, and that the chip appears for an incomplete diver. Note what you saw in the PR's test plan.

- [ ] **Step 4: Screenshots**

As in PR 3a Task 10 Step 3: the results pane with the Mission section (after; before is the results pane without it), phone and desktop widths, metric and imperial, light and dark, plus the status chip. Realistic data.

- [ ] **Step 5: Open the PR**

Push and open against main. The body says `Closes #2086`, summarises PR 3b, lists the tests and what Step 3 showed, and lists each screenshot. No tool attribution anywhere.

---

## Self-review

**Spec coverage.** Results 1 (constraint sentence, Task 3 and 4), 2 (member cards with battery bar and reserve mark, cruise setter, binding factor and waypoint, turn pressure, Task 4), 3 (waypoint table: cumulative distance, arrival, time to safe surface, per-member survivable with working exits and minutes, open-water distance home and surface route, "no buddy", Task 4), 4 (leg table, Task 4); status chip (Task 5); `missionOutcomeProvider` watching the state and the engine config (Task 1); the isolate, per the 2026-09-28 decision (Tasks 1 and 6); units and conservative rounding (Task 3); strings (Task 2); widget tests for the constraint sentence and waypoint table (Task 4).

**Type consistency.** `MissionEngineRunner` and `missionEngineRunnerProvider` are identical in Tasks 1, 4 and 5; the text helpers in Tasks 3 and 4; `MissionUnits` is PR 3a's.

**Review Focus coverage.** 1: "the outcome follows the latest edit" (Task 1) and the one-pump removal test (Task 4 Step 5). 2: "a blocked mission lists why" (Task 4) and the chip test (Task 5). 3: the solo test (Task 4). 4: the imperial pressure and distance tests (Task 3). 5: the 320 pt test with three divers and long names (Task 4).
