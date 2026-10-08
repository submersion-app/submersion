# DPV Mission Canvas, PR 3a (editing) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let a diver turn a saved plan into a DPV mission and edit it on the plan canvas: the route as a list of legs, the team as diver cards with scooters, and the mission settings, with the plan's segments regenerated from the mission on every edit.

**Architecture:** The mission lives on `DivePlanState.mission` (added by PR 2, #2538). `DivePlanNotifier` gains three mutations (`enableMission`, `updateMission`, `disableMission`); every change regenerates `state.segments` through a new `MissionEngine.roundTripSegments`, so the chart, the plan outcome and every existing planner feature keep working on ordinary segments. All list edits (add, update, remove, reorder a leg or member) are pure functions in a new `MissionEdits` class, so they are unit tested without widgets. The UI swaps the segment list for a leg list while a mission is on and adds a "DPV team" accordion section. Results come in PR 3b.

**Tech Stack:** Flutter, Dart 3, Riverpod 3 (legacy `StateNotifier` API via `core/providers/provider.dart`), `flutter_test`, gen-l10n (11 ARB files).

**Spec:** `docs/design/specs/2026-09-18-dpv-mission-planner-design.md`, "User interface" and "Error handling" sections (issue #2086). Decisions taken with the user on 2026-09-28: PR 3 ships as two PRs (this one edits, PR 3b shows results); the team card's "who" picker lists buddies and "Me" only (no separate diver-profile list); the mission engine always runs in an isolate (PR 3b).

**Depends on:** #2538 (PR 2, `DivePlanState.mission`, persistence) and #2558 (calculator follow-ups: `MissionIssueType.speedBelowHeadwayFloor`, `MissionBindingFactor.scenarioFailed`). Start only after both are merged: `git fetch origin && git merge origin/main` into this branch, then `dart run build_runner build --delete-conflicting-outputs`. Confirm with `grep -n "final DpvMission? mission" lib/features/dive_planner/domain/entities/plan_result.dart` and `grep -n speedBelowHeadwayFloor lib/features/planner/domain/entities/mission/mission_outcome.dart`.

## Global Constraints

- No em-dashes (U+2014), and no en-dashes, double hyphens or spaced hyphens as prose punctuation, anywhere: code, comments, ARB strings, commit messages, PR text.
- No mention of any AI tool or model in any file, commit message or PR text; no co-author trailers.
- No emojis in code, comments or docs.
- Immutability: build new lists (`[...list]`, collection-for), never mutate an entity's list in place.
- Numbers are entered only through `PlanNumberField` (the planner's only numeric control) or `NumberField`; never call `parseUserDecimal`/`parseUserInt` (architecture guard `number_parsing_single_source_test.dart`).
- No literal `/min` in any Dart string (guard `rate_unit_single_source_test.dart`): speed units come from `attributeUnitSymbol(AttributeDimension.speedMps, units)` (m/min or ft/min) and SAC units from `units.rmvSymbol`.
- Units follow the active diver's settings. Store metric (m, m/s, L/min, s); convert only for display and input:
  - distance and depth: `units.convertDepth` / `units.depthToMeters` / `units.depthSymbol` (the spec shows distance in the depth unit);
  - scooter, swim and current speed: `attributeDisplayFromMetric(AttributeDimension.speedMps, units, mps)` and `attributeMetricFromDisplay(...)`, NOT `formatSpeed` (wind and boat convention);
  - SAC: `units.convertRmv` / `units.volumeToLiters` / `units.rmvSymbol`;
  - heading and current direction in degrees (0 to 360).
- Every user-visible string goes into all 11 ARB files (`lib/l10n/arb/app_*.arb`) with real translations in the ten non-English files; run `flutter gen-l10n` only after every locale has its values (see Task 4). Plural `=1{...}` branches interpolate `{count}`.
- A new file stays under 400 lines. `dive_planner_providers.dart` is already over 900 lines: this plan adds at most 70 lines there and nothing else.
- Widget rows: any `Row` with a label wraps the text in `Expanded`/`Flexible` with `maxLines: 1, overflow: TextOverflow.ellipsis` (the test font makes every glyph as wide as its size; German and Italian labels are long).
- Tests that replace global state restore it (`addTearDown`); widget tests pin `locale: const Locale('en')`.
- `dart format .` before every commit; whole-project `flutter analyze` before the final commit (infos fail CI); `flutter test test/architecture/` after the first new file under `lib/`.
- Commits: conventional prefix, body line `Refs #2086`. PR body: `Refs #2086` (PR 3b closes it), plus the Screenshots section filled in (Task 10).

## Review Focus

1. **A diver on imperial units** (feet, psi, cuft/min): every mission field shows and accepts ft, ft/min and cuft/min, and a value typed and read back does not drift (store metric, convert once each way). Tested in Tasks 6, 8 and 9.
2. **An incomplete mission while it is being built** (the starter mission has an empty leg and a scooter with no numbers): the generated-profile strip names the first blocking reason instead of showing an empty chart with no explanation. Tested in Task 7.
3. **Turning the mission off and on**: off asks first and keeps the last generated segments as ordinary editable segments; on starts a fresh mission. Tested in Task 7.
4. **A scooter picked from equipment that was later edited or deleted**: on load the live item's numbers replace the stored snapshot; a deleted item keeps the snapshot silently. Tested in Tasks 2 and 3.
5. **Phone width (320 pt) with long labels**: the leg list, the team cards and the dialogs lay out without overflow. Tested in Tasks 7 and 9.

---

## File Structure

| File | Status | Responsibility |
| --- | --- | --- |
| `lib/features/planner/domain/services/mission/mission_engine.dart` | modify | `roundTripSegments`: the planned round trip as segments |
| `lib/features/planner/domain/services/mission/mission_edits.dart` | create | pure mission edits: starter, add/update/remove/reorder legs and members, live scooter overlay |
| `lib/features/dive_planner/presentation/providers/dive_planner_providers.dart` | modify | `enableMission`, `updateMission`, `disableMission`, scooter overlay on load, equipment loader |
| `lib/features/planner/presentation/mission/mission_issue_text.dart` | create | one sentence per `MissionIssue` (used here and by PR 3b's chip) |
| `lib/features/planner/presentation/mission/mission_units.dart` | create | display and input conversion for mission speeds, distances and SAC |
| `lib/features/planner/presentation/mission/buddy_picker_sheet.dart` | create | single-select sheet: "Me" plus the diver's buddies |
| `lib/features/planner/presentation/mission/mission_leg_editor.dart` | create | dialog editing one leg (label, distance, depth, heading, current, shore exit) |
| `lib/features/planner/presentation/mission/mission_leg_list.dart` | create | route card: leg rows, add/edit/delete/reorder, generated-profile strip |
| `lib/features/planner/presentation/mission/mission_toggle_row.dart` | create | "Plan as DPV mission" switch with the turn-off confirmation |
| `lib/features/planner/presentation/mission/mission_member_editor.dart` | create | dialog editing one diver and their scooter |
| `lib/features/planner/presentation/mission/mission_team_section.dart` | create | accordion section: member cards and mission settings |
| `lib/features/planner/presentation/panes/plan_editor_pane.dart` | modify | toggle row; leg list instead of segment list while a mission is on |
| `lib/features/planner/presentation/panes/plan_setup_accordion.dart` | modify | "DPV team" section, only while a mission is on |
| `lib/l10n/arb/app_*.arb` (11) and generated `app_localizations*.dart` (12) | modify | the strings |

---

### Task 1: The round trip as segments

**Files:**
- Modify: `lib/features/planner/domain/services/mission/mission_engine.dart` (add one public method after `compute`)
- Test: `test/features/planner/mission/mission_round_trip_segments_test.dart`

**Interfaces:**
- Produces: `List<PlanSegment> MissionEngine.roundTripSegments({required domain.DivePlan plan, required DpvMission mission})`. Returns the same list as `compute(...).segments` for a mission with no blocking issue; the legs up to the first untraversable one for a blocked route; an empty list when the mission has a blocking validation issue or no leg can be travelled.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/planner/mission/mission_round_trip_segments_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    as domain;
import 'package:submersion/features/planner/domain/entities/mission/current_vector.dart';
import 'package:submersion/features/planner/domain/entities/mission/dpv_mission.dart';
import 'package:submersion/features/planner/domain/entities/mission/mission_leg.dart';
import 'package:submersion/features/planner/domain/entities/mission/mission_member.dart';
import 'package:submersion/features/planner/domain/entities/mission/scooter_spec.dart';
import 'package:submersion/features/planner/domain/services/mission/mission_engine.dart';

const _air = GasMix(o2: 21);

domain.DivePlan _plan() => domain.DivePlan(
  id: 'plan-1',
  name: 'Round trip',
  gfLow: 40,
  gfHigh: 80,
  tanks: const [
    DiveTank(
      id: 'back',
      volume: 24,
      startPressure: 230,
      gasMix: _air,
      role: TankRole.backGas,
    ),
  ],
  createdAt: DateTime(2026, 9, 28),
  updatedAt: DateTime(2026, 9, 28),
);

MissionMember _member(String id, int order) => MissionMember(
  id: id,
  order: order,
  displayName: id,
  sacBottom: 15,
  scooter: ScooterSpec(name: 'S', ratedSpeedMps: 0.5, burnTimeSeconds: 7200),
);

MissionLeg _leg(String id, int order, {double distance = 200}) => MissionLeg(
  id: id,
  order: order,
  label: id,
  distanceM: distance,
  depthM: 20,
  headingDeg: 0,
);

void main() {
  const engine = MissionEngine();

  test('a valid mission gives the same segments as compute', () {
    final mission = DpvMission(
      legs: [_leg('L1', 0), _leg('L2', 1)],
      team: [_member('a', 0), _member('b', 1)],
    );
    final segments = engine.roundTripSegments(plan: _plan(), mission: mission);
    expect(segments, isNotEmpty);
    expect(
      segments,
      engine.compute(plan: _plan(), mission: mission).segments,
    );
  });

  test('a route the current blocks keeps the legs before the block', () {
    // L2 heads north into a 0.6 m/s current setting south: the 0.5 m/s
    // scooters cannot make headway on it.
    final mission = DpvMission(
      legs: [
        _leg('L1', 0),
        _leg('L2', 1).copyWith(
          current: const CurrentVector(speedMps: 0.6, setsTowardDeg: 180),
        ),
      ],
      team: [_member('a', 0)],
    );
    final segments = engine.roundTripSegments(plan: _plan(), mission: mission);
    expect(segments.map((s) => s.id), everyElement(isNot(contains('L2'))));
    expect(segments.map((s) => s.id), contains('mission-out-L1'));
  });

  test('a mission with a blocking issue gives no segments', () {
    // The starter mission: one empty leg, a scooter with no numbers.
    final mission = DpvMission(
      legs: [_leg('L1', 0, distance: 0)],
      team: [
        MissionMember(
          id: 'a',
          order: 0,
          displayName: 'a',
          sacBottom: 15,
          scooter: const ScooterSpec(
            name: '',
            ratedSpeedMps: 0,
            burnTimeSeconds: 0,
          ),
        ),
      ],
    );
    expect(engine.roundTripSegments(plan: _plan(), mission: mission), isEmpty);
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/features/planner/mission/mission_round_trip_segments_test.dart`
Expected: FAIL, "The method 'roundTripSegments' isn't defined for the type 'MissionEngine'".

- [ ] **Step 3: Add the method**

In `mission_engine.dart`, directly after the closing `}` of `compute`, add (the names `validateMission`, `cruiseSpeedMps`, `MissionLeg`, `PlanSegment` and `MissionIssueSeverity` are already imported for `compute`; add any the analyzer reports missing):

```dart
  /// The planned round trip at cruise as the plan's segments: the outbound
  /// legs up to the first one the current makes untraversable, then the same
  /// way back. Empty when the mission has a blocking validation issue or no
  /// leg can be travelled, so a half-built mission never feeds the plan
  /// engine nonsense. For a mission [compute] accepts, this is its outcome's
  /// `segments`.
  List<PlanSegment> roundTripSegments({
    required domain.DivePlan plan,
    required DpvMission mission,
  }) {
    final blocked = validateMission(
      mission,
    ).any((i) => i.severity == MissionIssueSeverity.blocking);
    if (blocked) return const [];
    final cruise = cruiseSpeedMps(mission.team);
    final traversable = <MissionLeg>[];
    for (final leg in mission.legs) {
      final resolved = speeds.resolve(
        leg: leg,
        current: mission.currentFor(leg),
        baseSpeedMps: cruise,
      );
      // The route stops at the first leg the current blocks.
      if (!resolved.traversable) break;
      traversable.add(leg);
    }
    if (traversable.isEmpty) return const [];
    return builder
        .build(
          plan: plan,
          mission: mission.copyWith(legs: traversable),
          throughLegIndex: traversable.length - 1,
          outboundSpeedMps: cruise,
          exitSpeedMps: cruise,
        )
        .segments;
  }
```

- [ ] **Step 4: Run the tests**

Run: `flutter test test/features/planner/mission/mission_round_trip_segments_test.dart test/features/planner/mission/`
Expected: PASS (3 new tests; the mission suite unchanged).

- [ ] **Step 5: Format and commit**

```bash
dart format lib/features/planner/domain test/features/planner/mission
git add lib/features/planner/domain/services/mission/mission_engine.dart test/features/planner/mission/mission_round_trip_segments_test.dart
git commit -m "feat(planner): give the DPV mission's round trip as plan segments

Refs #2086"
```

---

### Task 2: Mission edits as pure functions

**Files:**
- Create: `lib/features/planner/domain/services/mission/mission_edits.dart`
- Test: `test/features/planner/mission/mission_edits_test.dart`

**Interfaces:**
- Consumes: the mission entities; `ScooterSpecResolver.overlay(ScooterSpec stored, EquipmentItem? live)`.
- Produces (all static, all return a new `DpvMission`, all renumber `order` to the list position):
  - `MissionEdits.starter({required String legId, required String memberId, required String memberName, required double sacBottom})`: one leg (distance 0, depth 0, heading 0, label ''), one member with that name and SAC, default swim speed, and a scooter with no numbers (`ScooterSpec(name: '', ratedSpeedMps: 0, burnTimeSeconds: 0)`).
  - `addLeg(DpvMission m, String id)`: appends a leg with the last leg's depth and heading (0 and 0 when there is none), distance 0, label ''.
  - `updateLeg(DpvMission m, MissionLeg leg)`, `removeLeg(DpvMission m, String id)`, `reorderLegs(DpvMission m, int oldIndex, int newIndex)` (same index convention as `DivePlanNotifier.reorderSegments`: remove at `oldIndex`, insert at `newIndex` clamped).
  - `addMember(DpvMission m, String id, {required String name, required double sacBottom})`, `updateMember(DpvMission m, MissionMember member)`, `removeMember(DpvMission m, String id)`.
  - `withLiveScooters(DpvMission m, List<EquipmentItem> items)`: each member's scooter overlaid with the item whose id is `scooter.equipmentId`; unchanged when there is no such item.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/planner/mission/mission_edits_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_attribute.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/planner/domain/entities/mission/dpv_mission.dart';
import 'package:submersion/features/planner/domain/entities/mission/mission_member.dart';
import 'package:submersion/features/planner/domain/entities/mission/scooter_spec.dart';
import 'package:submersion/features/planner/domain/services/mission/mission_edits.dart';

/// A DPV equipment item, built as scooter_spec_resolver_test.dart does.
EquipmentItem dpvItem(String id, {double speedMps = 0.9, double hours = 1.5}) {
  EquipmentAttribute num(String key, double value) =>
      EquipmentAttribute.curated(equipmentId: id, key: key, valueNum: value);
  return EquipmentItem(
    id: id,
    name: 'Blacktip',
    type: EquipmentType.dpv,
    attributes: [num('speed_mps', speedMps), num('burn_time_h', hours)],
  );
}

void main() {
  final starter = MissionEdits.starter(
    legId: 'L1',
    memberId: 'm1',
    memberName: 'Sam',
    sacBottom: 16,
  );

  test('the starter has one empty leg and one diver with no scooter', () {
    expect(starter.legs.single.distanceM, 0);
    expect(starter.legs.single.id, 'L1');
    final member = starter.team.single;
    expect(member.displayName, 'Sam');
    expect(member.sacBottom, 16);
    expect(member.swimSpeedMps, kDefaultSwimSpeedMps);
    expect(member.scooter.ratedSpeedMps, 0);
    expect(member.scooter.burnTimeSeconds, 0);
  });

  test('a new leg carries the last depth and heading', () {
    final withDepth = MissionEdits.updateLeg(
      starter,
      starter.legs.single.copyWith(depthM: 24, headingDeg: 135),
    );
    final added = MissionEdits.addLeg(withDepth, 'L2');
    expect(added.legs.map((l) => l.id), ['L1', 'L2']);
    expect(added.legs.last.depthM, 24);
    expect(added.legs.last.headingDeg, 135);
    expect(added.legs.last.distanceM, 0);
    expect(added.legs.map((l) => l.order), [0, 1]);
  });

  test('removing and reordering renumber the order', () {
    var m = MissionEdits.addLeg(starter, 'L2');
    m = MissionEdits.addLeg(m, 'L3');
    m = MissionEdits.reorderLegs(m, 2, 0);
    expect(m.legs.map((l) => l.id), ['L3', 'L1', 'L2']);
    expect(m.legs.map((l) => l.order), [0, 1, 2]);
    m = MissionEdits.removeLeg(m, 'L1');
    expect(m.legs.map((l) => l.id), ['L3', 'L2']);
    expect(m.legs.map((l) => l.order), [0, 1]);
  });

  test('members are added, updated and removed by id', () {
    var m = MissionEdits.addMember(starter, 'm2', name: 'Alex', sacBottom: 14);
    expect(m.team.map((t) => t.displayName), ['Sam', 'Alex']);
    m = MissionEdits.updateMember(
      m,
      m.team.last.copyWith(swimSpeedMps: 0.3),
    );
    expect(m.team.last.swimSpeedMps, 0.3);
    m = MissionEdits.removeMember(m, 'm1');
    expect(m.team.map((t) => t.id), ['m2']);
    expect(m.team.single.order, 0);
  });

  group('live scooters', () {
    DpvMission withScooter(String? equipmentId) => MissionEdits.updateMember(
      starter,
      starter.team.single.copyWith(
        scooter: ScooterSpec(
          equipmentId: equipmentId,
          name: 'Old name',
          ratedSpeedMps: 0.5,
          burnTimeSeconds: 3600,
        ),
      ),
    );

    test('a picked scooter takes the live item numbers', () {
      final m = MissionEdits.withLiveScooters(withScooter('eq-1'), [dpvItem('eq-1')]);
      final scooter = m.team.single.scooter;
      expect(scooter.name, 'Blacktip');
      expect(scooter.ratedSpeedMps, 0.9);
      expect(scooter.burnTimeSeconds, 5400);
    });

    test('a deleted item keeps the stored snapshot', () {
      final stored = withScooter('eq-gone');
      expect(MissionEdits.withLiveScooters(stored, [dpvItem('eq-1')]), stored);
    });

    test('a manual scooter is never overlaid', () {
      final stored = withScooter(null);
      expect(MissionEdits.withLiveScooters(stored, [dpvItem('eq-1')]), stored);
    });
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/features/planner/mission/mission_edits_test.dart`
Expected: FAIL, the import `mission_edits.dart` does not resolve.

- [ ] **Step 3: Write the edits**

```dart
// lib/features/planner/domain/services/mission/mission_edits.dart
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/planner/domain/entities/mission/dpv_mission.dart';
import 'package:submersion/features/planner/domain/entities/mission/mission_leg.dart';
import 'package:submersion/features/planner/domain/entities/mission/mission_member.dart';
import 'package:submersion/features/planner/domain/entities/mission/scooter_spec.dart';
import 'package:submersion/features/planner/domain/services/mission/scooter_spec_resolver.dart';

/// Every edit the canvas makes to a DPV mission (issue #2086), as pure
/// functions returning a new mission. Each keeps a leg's or member's `order`
/// equal to its list position, which is what persistence stores.
abstract final class MissionEdits {
  /// The mission a plan starts with when the diver turns it on: one empty
  /// leg and one diver whose scooter has no numbers yet. Both are blocking
  /// validation issues, which the canvas shows until they are filled in.
  static DpvMission starter({
    required String legId,
    required String memberId,
    required String memberName,
    required double sacBottom,
  }) {
    return DpvMission(
      legs: [
        MissionLeg(
          id: legId,
          order: 0,
          label: '',
          distanceM: 0,
          depthM: 0,
          headingDeg: 0,
        ),
      ],
      team: [
        MissionMember(
          id: memberId,
          order: 0,
          displayName: memberName,
          sacBottom: sacBottom,
          scooter: const ScooterSpec(
            name: '',
            ratedSpeedMps: 0,
            burnTimeSeconds: 0,
          ),
        ),
      ],
    );
  }

  /// Appends a leg that continues at the last leg's depth and heading.
  static DpvMission addLeg(DpvMission m, String id) {
    final last = m.legs.isEmpty ? null : m.legs.last;
    return _withLegs(m, [
      ...m.legs,
      MissionLeg(
        id: id,
        order: m.legs.length,
        label: '',
        distanceM: 0,
        depthM: last?.depthM ?? 0,
        headingDeg: last?.headingDeg ?? 0,
      ),
    ]);
  }

  static DpvMission updateLeg(DpvMission m, MissionLeg leg) => _withLegs(m, [
    for (final l in m.legs) l.id == leg.id ? leg : l,
  ]);

  static DpvMission removeLeg(DpvMission m, String id) => _withLegs(m, [
    for (final l in m.legs)
      if (l.id != id) l,
  ]);

  /// Same index convention as DivePlanNotifier.reorderSegments.
  static DpvMission reorderLegs(DpvMission m, int oldIndex, int newIndex) {
    final legs = [...m.legs];
    final moved = legs.removeAt(oldIndex);
    legs.insert(newIndex.clamp(0, legs.length), moved);
    return _withLegs(m, legs);
  }

  static DpvMission addMember(
    DpvMission m,
    String id, {
    required String name,
    required double sacBottom,
  }) {
    return _withTeam(m, [
      ...m.team,
      MissionMember(
        id: id,
        order: m.team.length,
        displayName: name,
        sacBottom: sacBottom,
        scooter: const ScooterSpec(
          name: '',
          ratedSpeedMps: 0,
          burnTimeSeconds: 0,
        ),
      ),
    ]);
  }

  static DpvMission updateMember(DpvMission m, MissionMember member) =>
      _withTeam(m, [for (final t in m.team) t.id == member.id ? member : t]);

  static DpvMission removeMember(DpvMission m, String id) => _withTeam(m, [
    for (final t in m.team)
      if (t.id != id) t,
  ]);

  /// Each member's scooter refreshed from the live equipment item it was
  /// picked from. A manual scooter, or one whose item is gone, keeps its
  /// stored numbers (the spec's snapshot fallback).
  static DpvMission withLiveScooters(
    DpvMission m,
    List<EquipmentItem> items,
  ) {
    const resolver = ScooterSpecResolver();
    final byId = {for (final item in items) item.id: item};
    final team = [
      for (final t in m.team)
        t.copyWith(
          scooter: resolver.overlay(
            t.scooter,
            t.scooter.equipmentId == null ? null : byId[t.scooter.equipmentId],
          ),
        ),
    ];
    final changed = [
      for (var i = 0; i < team.length; i++) team[i] != m.team[i],
    ].any((c) => c);
    return changed ? m.copyWith(team: team) : m;
  }

  static DpvMission _withLegs(DpvMission m, List<MissionLeg> legs) =>
      m.copyWith(
        legs: [for (final (i, l) in legs.indexed) l.copyWith(order: i)],
      );

  static DpvMission _withTeam(DpvMission m, List<MissionMember> team) =>
      m.copyWith(
        team: [for (final (i, t) in team.indexed) t.copyWith(order: i)],
      );
}
```

Check `ScooterSpecResolver`'s constructor is `const` and its method is `overlay(ScooterSpec stored, EquipmentItem? live)` (`scooter_spec_resolver.dart:30`); adjust the call if the name differs.

- [ ] **Step 4: Run the tests**

Run: `flutter test test/features/planner/mission/mission_edits_test.dart`
Expected: PASS, 7 tests.

- [ ] **Step 5: Format and commit**

```bash
dart format lib/features/planner/domain test/features/planner/mission
git add lib/features/planner/domain/services/mission/mission_edits.dart test/features/planner/mission/mission_edits_test.dart
git commit -m "feat(planner): edit a DPV mission's legs and team as pure functions

Refs #2086"
```

---

### Task 3: Mission mutations on the plan notifier

**Files:**
- Modify: `lib/features/dive_planner/presentation/providers/dive_planner_providers.dart`
- Test: `test/features/dive_planner/presentation/providers/dive_plan_notifier_mission_test.dart`

**Interfaces:**
- Consumes: `MissionEngine.roundTripSegments` (Task 1), `MissionEdits` (Task 2), `DivePlanState.mission` / `copyWith(mission:, clearMission:)` (PR 2), `divePlanFromState` (existing).
- Produces on `DivePlanNotifier`:
  - `void enableMission(DpvMission starter)`: sets the mission, regenerates segments.
  - `void updateMission(DpvMission mission)`: sets the mission, regenerates segments.
  - `void disableMission()`: clears the mission; the current segments stay as ordinary segments.
  - `loadPlanById` overlays live scooters (via the injected loader) and regenerates once when anything changed, leaving `isDirty` false.
  - New factory parameter `Future<List<EquipmentItem>> Function()? loadEquipment`, supplied by `divePlanNotifierProvider` from `allEquipmentProvider`.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/dive_planner/presentation/providers/dive_plan_notifier_mission_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_planner/data/services/plan_calculator_service.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
import 'package:submersion/features/planner/domain/entities/mission/mission_member.dart';
import 'package:submersion/features/planner/domain/entities/mission/scooter_spec.dart';
import 'package:submersion/features/planner/domain/services/mission/mission_edits.dart';

void main() {
  late DivePlanNotifier notifier;

  setUp(() {
    notifier = DivePlanNotifier(PlanCalculatorService());
    // The starter plan must carry a back-gas cylinder for segments to exist.
    notifier.addTank(
      const DiveTank(
        id: 'back',
        volume: 24,
        startPressure: 230,
        gasMix: GasMix(o2: 21),
        role: TankRole.backGas,
      ),
    );
  });

  tearDown(() => notifier.dispose());

  final starter = MissionEdits.starter(
    legId: 'L1',
    memberId: 'm1',
    memberName: 'Sam',
    sacBottom: 15,
  );

  test('enabling a half-built mission sets it and generates nothing', () {
    notifier.enableMission(starter);
    expect(notifier.state.mission, starter);
    expect(notifier.state.segments, isEmpty);
    expect(notifier.state.isDirty, isTrue);
  });

  test('completing the mission regenerates the segments', () {
    notifier.enableMission(starter);
    var mission = MissionEdits.updateLeg(
      starter,
      starter.legs.single.copyWith(distanceM: 300, depthM: 20),
    );
    mission = MissionEdits.updateMember(
      mission,
      mission.team.single.copyWith(
        scooter: const ScooterSpec(
          name: 'Blacktip',
          ratedSpeedMps: 0.9,
          burnTimeSeconds: 5400,
        ),
      ),
    );
    notifier.updateMission(mission);
    expect(notifier.state.segments.map((s) => s.id), contains('mission-out-L1'));

    // A second edit replaces the segments rather than appending to them.
    final count = notifier.state.segments.length;
    notifier.updateMission(
      MissionEdits.updateLeg(
        mission,
        mission.legs.single.copyWith(distanceM: 400),
      ),
    );
    expect(notifier.state.segments.length, count);
  });

  test('disabling keeps the generated segments as ordinary segments', () {
    notifier.enableMission(starter);
    final mission = MissionEdits.updateMember(
      MissionEdits.updateLeg(
        starter,
        starter.legs.single.copyWith(distanceM: 300, depthM: 20),
      ),
      starter.team.single.copyWith(
        scooter: const ScooterSpec(
          name: 'Blacktip',
          ratedSpeedMps: 0.9,
          burnTimeSeconds: 5400,
        ),
      ),
    );
    notifier.updateMission(mission);
    final generated = notifier.state.segments;
    notifier.disableMission();
    expect(notifier.state.mission, isNull);
    expect(notifier.state.segments, generated);
  });

  test('the default swim speed survives into the state', () {
    notifier.enableMission(starter);
    expect(
      notifier.state.mission!.team.single.swimSpeedMps,
      kDefaultSwimSpeedMps,
    );
  });
}
```

Check `DivePlanNotifier.addTank`'s signature (line ~389) before running; if it takes other arguments than a `DiveTank`, call it the way `dive_planner_providers_test.dart` does.

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/features/dive_planner/presentation/providers/dive_plan_notifier_mission_test.dart`
Expected: FAIL, "The method 'enableMission' isn't defined for the type 'DivePlanNotifier'".

- [ ] **Step 3: Add the mutations and the equipment loader**

Imports (group with the existing ones):

```dart
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/planner/domain/entities/mission/dpv_mission.dart';
import 'package:submersion/features/planner/domain/services/mission/mission_edits.dart';
import 'package:submersion/features/planner/domain/services/mission/mission_engine.dart';
```

If importing `equipment_providers.dart` creates an import cycle the analyzer reports, move only the provider wiring (Step 3d) into `lib/features/planner/presentation/providers/plan_repository_providers.dart` as a `planEquipmentLoaderProvider` and read that instead.

3a. Field, next to `final DivePlanRepository? _repository;`:

```dart
  /// Loads the diver's equipment, for refreshing a mission's scooters from
  /// the items they were picked from when a plan is opened.
  final Future<List<EquipmentItem>> Function() _loadEquipment;
```

3b. Factory: add the parameter `Future<List<EquipmentItem>> Function()? loadEquipment,` after `DivePlanRepository? repository,` and pass `loadEquipment: loadEquipment ?? (() async => const <EquipmentItem>[]),` to `DivePlanNotifier._`. Private constructor: add `required Future<List<EquipmentItem>> Function() loadEquipment,` and the initializer `_loadEquipment = loadEquipment,` after `_repository = repository,`.

3c. Methods, directly after `updateContingencies`:

```dart
  // --------------------------------------------------------------------------
  // DPV mission (issue #2086)
  // --------------------------------------------------------------------------

  /// Turns the plan into a DPV mission, starting from [starter].
  void enableMission(DpvMission starter) => _setMission(starter);

  /// Replaces the mission and regenerates the plan's segments from it.
  void updateMission(DpvMission mission) => _setMission(mission);

  /// Turns the mission off. The segments it last generated stay as ordinary
  /// segments the diver can edit.
  void disableMission() {
    state = state.copyWith(
      clearMission: true,
      isDirty: true,
      updatedAt: DateTime.now(),
    );
  }

  void _setMission(DpvMission mission, {bool markDirty = true}) {
    final plan = divePlanFromState(state.copyWith(mission: mission));
    state = state.copyWith(
      mission: mission,
      segments: const MissionEngine().roundTripSegments(
        plan: plan,
        mission: mission,
      ),
      isDirty: markDirty ? true : state.isDirty,
      updatedAt: markDirty ? DateTime.now() : state.updatedAt,
    );
  }
```

3d. In `loadPlanById`, replace `state = stateFromDivePlan(plan);\n    return true;` with:

```dart
    state = stateFromDivePlan(plan);
    final mission = plan.mission;
    if (mission != null) {
      // A scooter picked from equipment follows the live item; a manual or
      // deleted one keeps the numbers stored with the plan.
      final live = MissionEdits.withLiveScooters(
        mission,
        await _loadEquipment(),
      );
      if (!mounted) return false;
      if (live != mission) _setMission(live, markDirty: false);
    }
    return true;
```

3e. Provider: in `divePlanNotifierProvider`, add to the `DivePlanNotifier(...)` call:

```dart
        loadEquipment: () => read(allEquipmentProvider.future),
```

- [ ] **Step 4: Run the tests**

```bash
flutter test test/features/dive_planner/presentation/providers/dive_plan_notifier_mission_test.dart test/features/dive_planner/presentation/providers/dive_planner_providers_test.dart
```

Expected: PASS. Then add one test for the load overlay to the same file: build a `DivePlanNotifier` with a fake repository whose `getPlan` returns a plan carrying a mission whose scooter has `equipmentId: 'eq-1'` and stored speed 0.5, and `loadEquipment: () async => [dpvItem('eq-1')]` (copy the `dpvItem` helper from Task 2's test); after `await notifier.loadPlanById('plan-1')`, expect the member's `scooter.ratedSpeedMps` to be `0.9` and `isDirty` to be false. Use the fake repository pattern from `dive_planner_providers_test.dart` (search it for `getPlan`); if none exists, subclass `DivePlanRepository` and override only `getPlan`. Watch it fail by temporarily removing the `_setMission(live, markDirty: false)` line (copy the file first with `cp`, restore with `cp`, never `git checkout`), then restore.

- [ ] **Step 5: Format and commit**

```bash
dart format lib/features/dive_planner test/features/dive_planner
wc -l lib/features/dive_planner/presentation/providers/dive_planner_providers.dart
git add lib/features/dive_planner/presentation/providers/dive_planner_providers.dart test/features/dive_planner/presentation/providers/dive_plan_notifier_mission_test.dart
git commit -m "feat(planner): turn a plan into a DPV mission and regenerate its segments on every edit

Refs #2086"
```

---

### Task 4: The strings and the issue sentences

**Files:**
- Modify: `lib/l10n/arb/app_en.arb` and the ten locale files, then regenerate `lib/l10n/arb/app_localizations*.dart`
- Create: `lib/features/planner/presentation/mission/mission_issue_text.dart`
- Test: `test/features/planner/mission/mission_issue_text_test.dart`

**Interfaces:**
- Produces: every `plannerMission_*` key below; `String missionIssueText(AppLocalizations l10n, MissionIssue issue, DpvMission mission)`; `String missionLegName(AppLocalizations l10n, MissionLeg leg)` (the label, or "Leg n" when empty).

**Keys** (English values; placeholders are `String` unless marked `int`):

| Key | English |
| --- | --- |
| `plannerMission_enable` | Plan as DPV mission |
| `plannerMission_disableTitle` | Turn off the DPV mission? |
| `plannerMission_disableMessage` | The route and team are removed. The generated profile stays as ordinary segments you can edit. |
| `plannerMission_disableConfirm` | Turn off |
| `plannerMission_route_title` | Route |
| `plannerMission_route_addLeg` | Add leg |
| `plannerMission_route_editLeg` | Edit leg |
| `plannerMission_route_deleteLeg` | Delete leg |
| `plannerMission_route_unnamedLeg` | Leg {number} (`number`: int) |
| `plannerMission_route_legSummary` | {distance} at {depth}, heading {heading} |
| `plannerMission_route_ownCurrent` | Current {speed} toward {direction} |
| `plannerMission_route_shoreExit` | Shore exit: swim {swim}, walk {walk} |
| `plannerMission_profile_title` | Generated profile |
| `plannerMission_profile_none` | No profile yet: {reason} |
| `plannerMission_leg_label` | Waypoint name |
| `plannerMission_leg_distance` | Distance |
| `plannerMission_leg_depth` | Depth |
| `plannerMission_leg_heading` | Heading |
| `plannerMission_leg_useMissionCurrent` | Use the mission's current |
| `plannerMission_current_speed` | Current speed |
| `plannerMission_current_setsToward` | Sets toward |
| `plannerMission_leg_shoreExit` | Shore exit from here |
| `plannerMission_leg_shoreSwim` | Surface swim to shore |
| `plannerMission_leg_shoreWalk` | Walk to the entry |
| `plannerMission_team_title` | DPV team |
| `plannerMission_team_addDiver` | Add diver |
| `plannerMission_team_editDiver` | Edit diver |
| `plannerMission_team_removeDiver` | Remove diver |
| `plannerMission_team_defaultName` | Diver {number} (`number`: int) |
| `plannerMission_team_memberSummary` | SAC {sac}, swim {speed} |
| `plannerMission_team_noScooter` | No scooter set |
| `plannerMission_team_scooterSummary` | {name}: {speed}, {minutes} min burn |
| `plannerMission_team_capacity` | {wh} Wh battery |
| `plannerMission_member_name` | Name |
| `plannerMission_member_pickBuddy` | Choose a buddy |
| `plannerMission_member_sac` | Bottom SAC |
| `plannerMission_member_swimSpeed` | Swim speed |
| `plannerMission_member_scooter` | Scooter |
| `plannerMission_member_chooseScooter` | Choose from equipment |
| `plannerMission_member_manualScooter` | Enter manually |
| `plannerMission_scooter_name` | Scooter name |
| `plannerMission_scooter_speed` | Rated speed |
| `plannerMission_scooter_burnTime` | Burn time |
| `plannerMission_scooter_towSpeedFactor` | Tow speed factor |
| `plannerMission_scooter_towBurnFactor` | Tow burn factor |
| `plannerMission_buddyPicker_title` | Choose a buddy |
| `plannerMission_buddyPicker_me` | Me |
| `plannerMission_buddyPicker_empty` | No buddies yet |
| `plannerMission_settings_environment` | Environment |
| `plannerMission_environment_overhead` | Overhead |
| `plannerMission_environment_openWater` | Open water |
| `plannerMission_settings_batteryReserve` | Battery reserve |
| `plannerMission_settings_defaultCurrent` | Default current |
| `plannerMission_settings_walkSpeed` | Walking speed |
| `plannerMission_settings_surfaceSwimLimit` | Longest surface swim |
| `plannerMission_issue_emptyTeam` | Add at least one diver |
| `plannerMission_issue_emptyRoute` | Add at least one leg |
| `plannerMission_issue_scooterUnspecified` | {name}'s scooter needs a speed and burn time |
| `plannerMission_issue_memberSacUnset` | {name} needs a SAC |
| `plannerMission_issue_memberSwimSpeedUnset` | {name} needs a swim speed |
| `plannerMission_issue_speedBelowHeadwayFloor` | {name}'s swim, scooter or tow speed is too slow to make headway |
| `plannerMission_issue_openWaterInputInvalid` | A shore exit, the surface swim limit or the walking speed is negative |
| `plannerMission_issue_legTooShort` | {leg} is too short to travel |
| `plannerMission_issue_planHasNoTank` | Add a back-gas cylinder to the plan |
| `plannerMission_issue_tankBudgetUnknown` | Every cylinder needs a size and a fill pressure |
| `plannerMission_issue_unsupportedMode` | DPV missions plan open circuit dives only |
| `plannerMission_issue_planNotDiveable` | The planned route breaks a critical limit |
| `plannerMission_issue_batteryReserveInvalid` | The battery reserve must be between 0 and 100% |
| `plannerMission_issue_legDepthInvalid` | {leg} has an invalid depth |
| `plannerMission_issue_untraversableLeg` | The current blocks {leg} |
| `plannerMission_issue_scenarioFailed` | A failure scenario could not be computed |

- [ ] **Step 1: Add the English keys**

Insert every key in `app_en.arb` in alphabetical position (it is the only sorted file), each with its `@` metadata when it has placeholders, for example:

```json
  "plannerMission_route_unnamedLeg": "Leg {number}",
  "@plannerMission_route_unnamedLeg": {
    "placeholders": { "number": { "type": "int" } }
  },
  "plannerMission_route_legSummary": "{distance} at {depth}, heading {heading}",
  "@plannerMission_route_legSummary": {
    "placeholders": {
      "distance": { "type": "String" },
      "depth": { "type": "String" },
      "heading": { "type": "String" }
    }
  },
```

Insert with a script that anchors on an existing key, never a JSON round trip: pick a neighbouring key present in all 11 files (`grep -n '"plannerCanvas_turnRule_thirds"' lib/l10n/arb/app_*.arb`), insert before the anchor in `app_en.arb` and after it in the other ten, building each line as `'  "%s": %s,' % (key, json.dumps(value, ensure_ascii=False))`. Use `python3.14`.

- [ ] **Step 2: Translate into the ten locales**

Add real translations to `app_ar`, `app_de`, `app_es`, `app_fr`, `app_he`, `app_hu`, `app_it`, `app_nl`, `app_pt` and `app_zh`, after the same anchor, keeping every `{placeholder}` verbatim and matching the terms the neighbouring `plannerCanvas_*` and `divePlanner_*` keys already use in that language (for example the existing words for "segment", "cylinder", "SAC" and "current"). "DPV" stays "DPV". Then check:

```bash
python3.14 -c "import json,glob; [json.load(open(f)) for f in glob.glob('lib/l10n/arb/app_*.arb')]; print('json ok')"
git diff --numstat -- lib/l10n/arb/*.arb
```

Expected: `json ok`, and the same `+N 0` on every one of the 11 files (an uneven row means a locale did not change).

- [ ] **Step 3: Regenerate, last**

```bash
flutter gen-l10n
grep -A1 "get plannerMission_route_title" lib/l10n/arb/app_localizations_de.dart
flutter test test/l10n/
```

Expected: the German getter returns German, not "Route" copied from English (if it is English, a locale value was missing when gen-l10n ran: fix the ARB and rerun); the l10n suite passes (parity, duplicates, plural rules).

- [ ] **Step 4: Write the failing issue-text test**

```dart
// test/features/planner/mission/mission_issue_text_test.dart
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/planner/domain/entities/mission/mission_outcome.dart';
import 'package:submersion/features/planner/domain/services/mission/mission_edits.dart';
import 'package:submersion/features/planner/presentation/mission/mission_issue_text.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
  late AppLocalizations l10n;

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  final mission = MissionEdits.starter(
    legId: 'L1',
    memberId: 'm1',
    memberName: 'Sam',
    sacBottom: 15,
  );

  test('every issue type has a sentence', () {
    for (final type in MissionIssueType.values) {
      final text = missionIssueText(
        l10n,
        MissionIssue(
          type: type,
          severity: MissionIssueSeverity.blocking,
          legId: 'L1',
          memberId: 'm1',
        ),
        mission,
      );
      expect(text, isNotEmpty, reason: type.name);
    }
  });

  test('a member issue names the diver, a leg issue names the leg', () {
    expect(
      missionIssueText(
        l10n,
        const MissionIssue(
          type: MissionIssueType.scooterUnspecified,
          severity: MissionIssueSeverity.blocking,
          memberId: 'm1',
        ),
        mission,
      ),
      "Sam's scooter needs a speed and burn time",
    );
    expect(
      missionIssueText(
        l10n,
        const MissionIssue(
          type: MissionIssueType.legTooShort,
          severity: MissionIssueSeverity.blocking,
          legId: 'L1',
        ),
        mission,
      ),
      'Leg 1 is too short to travel',
    );
  });
}
```

Check `MissionIssue`'s constructor is `const` with named `type`, `severity`, `legId`, `memberId` (`mission_outcome.dart:78`); adjust if not.

- [ ] **Step 5: Run it to verify it fails**

Run: `flutter test test/features/planner/mission/mission_issue_text_test.dart`
Expected: FAIL, `mission_issue_text.dart` does not resolve.

- [ ] **Step 6: Write the issue text**

```dart
// lib/features/planner/presentation/mission/mission_issue_text.dart
import 'package:submersion/features/planner/domain/entities/mission/dpv_mission.dart';
import 'package:submersion/features/planner/domain/entities/mission/mission_leg.dart';
import 'package:submersion/features/planner/domain/entities/mission/mission_outcome.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// A leg's name as the canvas shows it: its waypoint label, or "Leg n".
String missionLegName(AppLocalizations l10n, MissionLeg leg) =>
    leg.label.trim().isEmpty
    ? l10n.plannerMission_route_unnamedLeg(leg.order + 1)
    : leg.label;

/// One sentence for [issue], naming the diver or leg it carries by id.
String missionIssueText(
  AppLocalizations l10n,
  MissionIssue issue,
  DpvMission mission,
) {
  String member() {
    for (final t in mission.team) {
      if (t.id == issue.memberId) return t.displayName;
    }
    return '';
  }

  String leg() {
    for (final l in mission.legs) {
      if (l.id == issue.legId) return missionLegName(l10n, l);
    }
    return '';
  }

  return switch (issue.type) {
    MissionIssueType.emptyTeam => l10n.plannerMission_issue_emptyTeam,
    MissionIssueType.emptyRoute => l10n.plannerMission_issue_emptyRoute,
    MissionIssueType.scooterUnspecified =>
      l10n.plannerMission_issue_scooterUnspecified(member()),
    MissionIssueType.memberSacUnset =>
      l10n.plannerMission_issue_memberSacUnset(member()),
    MissionIssueType.memberSwimSpeedUnset =>
      l10n.plannerMission_issue_memberSwimSpeedUnset(member()),
    MissionIssueType.speedBelowHeadwayFloor =>
      l10n.plannerMission_issue_speedBelowHeadwayFloor(member()),
    MissionIssueType.openWaterInputInvalid =>
      l10n.plannerMission_issue_openWaterInputInvalid,
    MissionIssueType.legTooShort =>
      l10n.plannerMission_issue_legTooShort(leg()),
    MissionIssueType.planHasNoTank => l10n.plannerMission_issue_planHasNoTank,
    MissionIssueType.tankBudgetUnknown =>
      l10n.plannerMission_issue_tankBudgetUnknown,
    MissionIssueType.unsupportedMode =>
      l10n.plannerMission_issue_unsupportedMode,
    MissionIssueType.planNotDiveable =>
      l10n.plannerMission_issue_planNotDiveable,
    MissionIssueType.batteryReserveInvalid =>
      l10n.plannerMission_issue_batteryReserveInvalid,
    MissionIssueType.legDepthInvalid =>
      l10n.plannerMission_issue_legDepthInvalid(leg()),
    MissionIssueType.untraversableLeg =>
      l10n.plannerMission_issue_untraversableLeg(leg()),
    MissionIssueType.scenarioFailed => l10n.plannerMission_issue_scenarioFailed,
  };
}
```

The `switch` is exhaustive on purpose: a new `MissionIssueType` fails to compile here until it has a sentence. If the analyzer lists a type this plan does not name, add a key for it (Steps 1 to 3) and an arm.

- [ ] **Step 7: Run the tests, architecture guards, and commit**

```bash
flutter test test/features/planner/mission/mission_issue_text_test.dart test/l10n/ test/architecture/
dart format lib/features/planner test/features/planner
git add lib/l10n/arb lib/features/planner/presentation/mission/mission_issue_text.dart test/features/planner/mission/mission_issue_text_test.dart
git commit -m "i18n(planner): DPV mission editing strings in every language, and one sentence per mission issue

Refs #2086"
```

---

### Task 5: Mission units

**Files:**
- Create: `lib/features/planner/presentation/mission/mission_units.dart`
- Test: `test/features/planner/mission/mission_units_test.dart`

**Interfaces:**
- Produces `class MissionUnits { MissionUnits(UnitFormatter units); }` with:
  - `String distance(double meters)` (e.g. "300m" or "984ft", via `formatDistance`), `double distanceDisplay(double meters)`, `double distanceMeters(double display)`, `String get distanceSymbol`;
  - `String speed(double mps)` (value plus "m/min" or "ft/min", no decimals), `double speedDisplay(double mps)`, `double speedMps(double display)`, `String get speedSymbol`;
  - `double sacDisplay(double litersPerMin)`, `double sacLitersPerMin(double display)`, `String get sacSymbol`, `String sac(double litersPerMin)`;
  - `String heading(double degrees)` (e.g. "135°").

- [ ] **Step 1: Write the failing test**

```dart
// test/features/planner/mission/mission_units_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/planner/presentation/mission/mission_units.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

void main() {
  final metric = MissionUnits(UnitFormatter(const AppSettings()));
  final imperial = MissionUnits(
    UnitFormatter(
      const AppSettings(
        depthUnit: DepthUnit.feet,
        volumeUnit: VolumeUnit.cubicFeet,
        pressureUnit: PressureUnit.psi,
      ),
    ),
  );

  test('speeds show per minute in the depth unit', () {
    expect(metric.speed(0.9), '54 ${metric.speedSymbol}');
    expect(metric.speedDisplay(0.9), closeTo(54, 1e-9));
    expect(imperial.speedDisplay(0.9), closeTo(177.165, 1e-3));
  });

  test('an imperial value typed and read back does not drift', () {
    const mps = 0.9;
    expect(imperial.speedMps(imperial.speedDisplay(mps)), closeTo(mps, 1e-12));
    const meters = 300.0;
    expect(
      imperial.distanceMeters(imperial.distanceDisplay(meters)),
      closeTo(meters, 1e-9),
    );
    const sac = 15.0;
    expect(imperial.sacLitersPerMin(imperial.sacDisplay(sac)), closeTo(sac, 1e-9));
  });

  test('a heading shows in whole degrees', () {
    expect(metric.heading(135.4), '135°');
  });
}
```

Check the `AppSettings` import path and field names (`depthUnit`, `volumeUnit`, `pressureUnit`) against `settings_providers.dart` and `lib/core/constants/units.dart` before running; `test/core/utils/unit_formatter_test.dart` shows how the repo builds imperial settings.

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/features/planner/mission/mission_units_test.dart`
Expected: FAIL, `mission_units.dart` does not resolve.

- [ ] **Step 3: Write the helper**

```dart
// lib/features/planner/presentation/mission/mission_units.dart
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_attribute_units.dart';

/// Display and input conversion for a DPV mission's numbers, in the active
/// diver's units. Stored values are metric: metres, m/s and L/min.
///
/// Speeds use the equipment attribute path (m/min or ft/min, following the
/// depth unit), the convention the DPV catalog attributes already use, not
/// the wind and boat speed format.
class MissionUnits {
  MissionUnits(this.units);

  final UnitFormatter units;

  String distance(double meters) => units.formatDistance(meters);
  double distanceDisplay(double meters) => units.convertDepth(meters);
  double distanceMeters(double display) => units.depthToMeters(display);
  String get distanceSymbol => units.depthSymbol;

  double speedDisplay(double mps) =>
      attributeDisplayFromMetric(AttributeDimension.speedMps, units, mps);
  double speedMps(double display) =>
      attributeMetricFromDisplay(AttributeDimension.speedMps, units, display);
  String get speedSymbol =>
      attributeUnitSymbol(AttributeDimension.speedMps, units);
  String speed(double mps) =>
      '${speedDisplay(mps).toStringAsFixed(0)} $speedSymbol';

  double sacDisplay(double litersPerMin) => units.convertRmv(litersPerMin);
  double sacLitersPerMin(double display) => units.volumeToLiters(display);
  String get sacSymbol => units.rmvSymbol;
  String sac(double litersPerMin) => units.formatRmv(litersPerMin);

  String heading(double degrees) => '${degrees.round() % 360}°';
}
```

Confirm `AttributeDimension` is exported from `equipment_attribute_catalog.dart` and the three `attribute*` functions take `(AttributeDimension, UnitFormatter, double)` in that order (`equipment_attribute_units.dart:4, 26, 42`); fix the import or argument order if not.

- [ ] **Step 4: Run the tests, then commit**

```bash
flutter test test/features/planner/mission/mission_units_test.dart test/architecture/
dart format lib/features/planner test/features/planner
git add lib/features/planner/presentation/mission/mission_units.dart test/features/planner/mission/mission_units_test.dart
git commit -m "feat(planner): show and read DPV mission numbers in the diver's units

Refs #2086"
```

---

### Task 6: The leg editor

**Files:**
- Create: `lib/features/planner/presentation/mission/mission_leg_editor.dart`
- Test: `test/features/planner/mission/mission_leg_editor_test.dart`

**Interfaces:**
- Consumes: `MissionUnits` (Task 5), `missionLegName` (Task 4), `PlanNumberField` (`lib/features/dive_planner/presentation/widgets/setup/plan_number_field.dart`: `label`, `value`, `hintValue`, `suffixText`, `onChanged(double?)`, `decimals`, `isInteger`, `min`, `max`, `allowEmpty`).
- Produces: `Future<MissionLeg?> showMissionLegEditor(BuildContext context, {required MissionLeg leg, required bool openWater, required MissionUnits units})`: returns the edited leg on Save, null on Cancel.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/planner/mission/mission_leg_editor_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/planner/domain/entities/mission/mission_leg.dart';
import 'package:submersion/features/planner/presentation/mission/mission_leg_editor.dart';
import 'package:submersion/features/planner/presentation/mission/mission_units.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../helpers/test_app.dart';

const _leg = MissionLeg(
  id: 'L1',
  order: 0,
  label: 'T',
  distanceM: 300,
  depthM: 20,
  headingDeg: 90,
);

/// What the dialog returned the last time it closed.
MissionLeg? lastResult;

Future<void> _open(
  WidgetTester tester, {
  bool openWater = false,
  AppSettings settings = const AppSettings(),
}) async {
  lastResult = null;
  await tester.pumpWidget(
    testApp(
      locale: const Locale('en'),
      child: Builder(
        builder: (context) => TextButton(
          onPressed: () async => lastResult = await showMissionLegEditor(
            context,
            leg: _leg,
            openWater: openWater,
            units: MissionUnits(UnitFormatter(settings)),
          ),
          child: const Text('open'),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('saving an edited distance returns the leg in metres', (
    tester,
  ) async {
    await _open(tester);
    await tester.enterText(find.widgetWithText(TextField, '300'), '450');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Waypoint name'), findsNothing);
    expect(lastResult!.distanceM, 450);
    expect(lastResult!.label, 'T');
  });

  testWidgets('a leg in feet is shown in feet', (tester) async {
    await _open(
      tester,
      settings: const AppSettings(depthUnit: DepthUnit.feet),
    );
    // 300 m is 984 ft.
    expect(find.widgetWithText(TextField, '984'), findsOneWidget);
  });

  testWidgets('the shore exit rows appear only in open water', (tester) async {
    await _open(tester);
    expect(find.text('Shore exit from here'), findsNothing);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    await _open(tester, openWater: true);
    expect(find.text('Shore exit from here'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/features/planner/mission/mission_leg_editor_test.dart`
Expected: FAIL, `mission_leg_editor.dart` does not resolve.

- [ ] **Step 3: Write the editor**

```dart
// lib/features/planner/presentation/mission/mission_leg_editor.dart
import 'package:flutter/material.dart';

import 'package:submersion/features/dive_planner/presentation/widgets/setup/plan_number_field.dart';
import 'package:submersion/features/planner/domain/entities/mission/current_vector.dart';
import 'package:submersion/features/planner/domain/entities/mission/mission_leg.dart';
import 'package:submersion/features/planner/domain/entities/mission/shore_exit.dart';
import 'package:submersion/features/planner/presentation/mission/mission_units.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Edits one leg of a DPV mission route. Returns the edited leg, or null
/// when the diver cancels. Values are shown and typed in the diver's units
/// and returned in metres, m/s and degrees.
Future<MissionLeg?> showMissionLegEditor(
  BuildContext context, {
  required MissionLeg leg,
  required bool openWater,
  required MissionUnits units,
}) {
  return showDialog<MissionLeg>(
    context: context,
    builder: (context) =>
        _MissionLegEditor(leg: leg, openWater: openWater, units: units),
  );
}

class _MissionLegEditor extends StatefulWidget {
  const _MissionLegEditor({
    required this.leg,
    required this.openWater,
    required this.units,
  });

  final MissionLeg leg;
  final bool openWater;
  final MissionUnits units;

  @override
  State<_MissionLegEditor> createState() => _MissionLegEditorState();
}

class _MissionLegEditorState extends State<_MissionLegEditor> {
  late final TextEditingController _label;
  late MissionLeg _draft;

  @override
  void initState() {
    super.initState();
    _draft = widget.leg;
    _label = TextEditingController(text: widget.leg.label);
  }

  @override
  void dispose() {
    _label.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final u = widget.units;
    final current = _draft.current;
    final shore = _draft.shoreExit;
    return AlertDialog(
      title: Text(l10n.plannerMission_route_editLeg),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _label,
              decoration: InputDecoration(
                labelText: l10n.plannerMission_leg_label,
              ),
            ),
            PlanNumberField(
              label: l10n.plannerMission_leg_distance,
              value: u.distanceDisplay(_draft.distanceM),
              hintValue: 0,
              suffixText: u.distanceSymbol,
              decimals: 0,
              min: 0,
              allowEmpty: false,
              onChanged: (v) => setState(
                () => _draft = _draft.copyWith(
                  distanceM: u.distanceMeters(v ?? 0),
                ),
              ),
            ),
            PlanNumberField(
              label: l10n.plannerMission_leg_depth,
              value: u.distanceDisplay(_draft.depthM),
              hintValue: 0,
              suffixText: u.distanceSymbol,
              decimals: 0,
              min: 0,
              allowEmpty: false,
              onChanged: (v) => setState(
                () => _draft = _draft.copyWith(depthM: u.distanceMeters(v ?? 0)),
              ),
            ),
            PlanNumberField(
              label: l10n.plannerMission_leg_heading,
              value: _draft.headingDeg,
              hintValue: 0,
              suffixText: '°',
              decimals: 0,
              min: 0,
              max: 359,
              allowEmpty: false,
              onChanged: (v) => setState(
                () => _draft = _draft.copyWith(headingDeg: v ?? 0),
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.plannerMission_leg_useMissionCurrent),
              value: current == null,
              onChanged: (useDefault) => setState(
                () => _draft = useDefault
                    ? _draft.copyWith(clearCurrent: true)
                    : _draft.copyWith(
                        current: const CurrentVector(
                          speedMps: 0,
                          setsTowardDeg: 0,
                        ),
                      ),
              ),
            ),
            if (current != null) ...[
              PlanNumberField(
                label: l10n.plannerMission_current_speed,
                value: u.speedDisplay(current.speedMps),
                hintValue: 0,
                suffixText: u.speedSymbol,
                decimals: 0,
                min: 0,
                allowEmpty: false,
                onChanged: (v) => setState(
                  () => _draft = _draft.copyWith(
                    current: CurrentVector(
                      speedMps: u.speedMps(v ?? 0),
                      setsTowardDeg: current.setsTowardDeg,
                    ),
                  ),
                ),
              ),
              PlanNumberField(
                label: l10n.plannerMission_current_setsToward,
                value: current.setsTowardDeg,
                hintValue: 0,
                suffixText: '°',
                decimals: 0,
                min: 0,
                max: 359,
                allowEmpty: false,
                onChanged: (v) => setState(
                  () => _draft = _draft.copyWith(
                    current: CurrentVector(
                      speedMps: current.speedMps,
                      setsTowardDeg: v ?? 0,
                    ),
                  ),
                ),
              ),
            ],
            if (widget.openWater) ...[
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.plannerMission_leg_shoreExit),
                value: shore != null,
                onChanged: (on) => setState(
                  () => _draft = on
                      ? _draft.copyWith(
                          shoreExit: const ShoreExit(surfaceSwimM: 0, walkM: 0),
                        )
                      : _draft.copyWith(clearShoreExit: true),
                ),
              ),
              if (shore != null) ...[
                PlanNumberField(
                  label: l10n.plannerMission_leg_shoreSwim,
                  value: u.distanceDisplay(shore.surfaceSwimM),
                  hintValue: 0,
                  suffixText: u.distanceSymbol,
                  decimals: 0,
                  min: 0,
                  allowEmpty: false,
                  onChanged: (v) => setState(
                    () => _draft = _draft.copyWith(
                      shoreExit: ShoreExit(
                        surfaceSwimM: u.distanceMeters(v ?? 0),
                        walkM: shore.walkM,
                      ),
                    ),
                  ),
                ),
                PlanNumberField(
                  label: l10n.plannerMission_leg_shoreWalk,
                  value: u.distanceDisplay(shore.walkM),
                  hintValue: 0,
                  suffixText: u.distanceSymbol,
                  decimals: 0,
                  min: 0,
                  allowEmpty: false,
                  onChanged: (v) => setState(
                    () => _draft = _draft.copyWith(
                      shoreExit: ShoreExit(
                        surfaceSwimM: shore.surfaceSwimM,
                        walkM: u.distanceMeters(v ?? 0),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.common_action_cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(
            _draft.copyWith(label: _label.text.trim()),
          ),
          child: Text(l10n.common_action_save),
        ),
      ],
    );
  }
}
```

`PlanNumberField` commits on change within its band; check whether it also needs an explicit commit on Save (the conventions note that a commit-on-blur field is not committed by a button tap on touch). If `PlanNumberField` commits only on blur, give each field a `GlobalKey<PlanNumberFieldState>` and call its commit method (see `plan_number_field.dart` for the name) before popping.

- [ ] **Step 4: Run the tests**

Run: `flutter test test/features/planner/mission/mission_leg_editor_test.dart`
Expected: PASS, 3 tests.

- [ ] **Step 5: Commit**

```bash
dart format lib/features/planner test/features/planner
git add lib/features/planner/presentation/mission/mission_leg_editor.dart test/features/planner/mission/mission_leg_editor_test.dart
git commit -m "feat(planner): edit a DPV mission leg in the diver's units

Refs #2086"
```

---

### Task 7: The route card, the toggle and the editor pane

**Files:**
- Create: `lib/features/planner/presentation/mission/mission_toggle_row.dart`
- Create: `lib/features/planner/presentation/mission/mission_leg_list.dart`
- Modify: `lib/features/planner/presentation/panes/plan_editor_pane.dart`
- Test: `test/features/planner/mission/mission_route_card_test.dart`

**Interfaces:**
- Consumes: `DivePlanNotifier.enableMission/updateMission/disableMission` (Task 3), `MissionEdits` (Task 2), `missionIssueText`/`missionLegName` (Task 4), `MissionUnits` (Task 5), `showMissionLegEditor` (Task 6), `validateMission` / `validatePlanForMission` (existing).
- Produces: `MissionToggleRow` (a `ConsumerWidget`, `const MissionToggleRow({super.key})`), `MissionLegList` (`const MissionLegList({super.key})`).

- [ ] **Step 1: Write the failing widget test**

```dart
// test/features/planner/mission/mission_route_card_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/map_style.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
import 'package:submersion/features/planner/presentation/panes/plan_editor_pane.dart';
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

Widget _harness() => testApp(
  overrides: [settingsProvider.overrideWith((ref) => _TestSettingsNotifier())],
  locale: const Locale('en'),
  child: const PlanEditorPane(),
);

void main() {

  testWidgets('turning the mission on swaps the segments for the route', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

    expect(find.text('Route'), findsNothing);
    await tester.tap(find.text('Plan as DPV mission'));
    await tester.pumpAndSettle();

    expect(find.text('Route'), findsOneWidget);
    expect(find.text('Leg 1'), findsOneWidget);
    // The starter is incomplete: the strip names why there is no profile.
    expect(find.textContaining('No profile yet'), findsOneWidget);
  });

  testWidgets('turning it off asks first and keeps the segments', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Plan as DPV mission'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Plan as DPV mission'));
    await tester.pumpAndSettle();
    expect(find.text('Turn off the DPV mission?'), findsOneWidget);
    await tester.tap(find.text('Turn off'));
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(PlanEditorPane)),
    );
    expect(container.read(divePlanNotifierProvider).mission, isNull);
    expect(find.text('Route'), findsNothing);
  });

  testWidgets('adding a leg adds a row', (tester) async {
    tester.view.physicalSize = const Size(400, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Plan as DPV mission'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Add leg'));
    await tester.pumpAndSettle();
    expect(find.text('Leg 2'), findsOneWidget);
  });

  testWidgets('the route card fits a 320 pt phone', (tester) async {
    tester.view.physicalSize = const Size(320, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Plan as DPV mission'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
```

`_TestSettingsNotifier` is the one in `test/features/planner/panes/plan_setup_accordion_test.dart`. If `PlanEditorPane` needs more overrides to build, take them from `test/features/planner/panes/plan_panes_test.dart`.

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/features/planner/mission/mission_route_card_test.dart`
Expected: FAIL, no widget with text "Plan as DPV mission".

- [ ] **Step 3: Write the toggle row**

```dart
// lib/features/planner/presentation/mission/mission_toggle_row.dart
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
import 'package:submersion/features/planner/domain/services/mission/mission_edits.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// "Plan as DPV mission": turns the mission on with a starter route and one
/// diver, or, after confirming, off, leaving the generated segments behind
/// as ordinary editable segments.
class MissionToggleRow extends ConsumerWidget {
  const MissionToggleRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final on = ref.watch(
      divePlanNotifierProvider.select((s) => s.mission != null),
    );
    final notifier = ref.read(divePlanNotifierProvider.notifier);
    return SwitchListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      title: Text(
        l10n.plannerMission_enable,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      value: on,
      onChanged: (enable) async {
        if (enable) {
          const uuid = Uuid();
          notifier.enableMission(
            MissionEdits.starter(
              legId: uuid.v4(),
              memberId: uuid.v4(),
              memberName: l10n.plannerMission_team_defaultName(1),
              sacBottom: ref.read(divePlanNotifierProvider).sacRate,
            ),
          );
          return;
        }
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(l10n.plannerMission_disableTitle),
            content: Text(l10n.plannerMission_disableMessage),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(l10n.common_action_cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(l10n.plannerMission_disableConfirm),
              ),
            ],
          ),
        );
        if (confirmed == true) notifier.disableMission();
      },
    );
  }
}
```

`DivePlanState.sacRate` is the plan's bottom SAC in L/min (`plan_result.dart:498`); if it is stored in another unit, convert it to L/min here.

- [ ] **Step 4: Write the route card**

```dart
// lib/features/planner/presentation/mission/mission_leg_list.dart
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_result.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_segment.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
import 'package:submersion/features/planner/domain/entities/mission/dpv_mission.dart';
import 'package:submersion/features/planner/domain/entities/mission/mission_leg.dart';
import 'package:submersion/features/planner/domain/entities/mission/mission_outcome.dart';
import 'package:submersion/features/planner/domain/services/dive_plan_state_mapper.dart';
import 'package:submersion/features/planner/domain/services/mission/mission_edits.dart';
import 'package:submersion/features/planner/domain/services/mission/mission_validator.dart';
import 'package:submersion/features/planner/presentation/mission/mission_issue_text.dart';
import 'package:submersion/features/planner/presentation/mission/mission_leg_editor.dart';
import 'package:submersion/features/planner/presentation/mission/mission_units.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The route of a DPV mission, in place of the segment list while a mission
/// is on: one row per leg, and below them the profile the legs generate.
class MissionLegList extends ConsumerWidget {
  const MissionLegList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(divePlanNotifierProvider);
    final mission = state.mission;
    if (mission == null) return const SizedBox.shrink();
    final notifier = ref.read(divePlanNotifierProvider.notifier);
    final units = MissionUnits(UnitFormatter(ref.watch(settingsProvider)));
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final openWater = mission.environment == MissionEnvironment.openWater;

    Future<void> edit(MissionLeg leg) async {
      final edited = await showMissionLegEditor(
        context,
        leg: leg,
        openWater: openWater,
        units: units,
      );
      if (edited != null) {
        notifier.updateMission(MissionEdits.updateLeg(mission, edited));
      }
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.route, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.plannerMission_route_title,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  tooltip: l10n.plannerMission_route_addLeg,
                  onPressed: () => notifier.updateMission(
                    MissionEdits.addLeg(mission, const Uuid().v4()),
                  ),
                ),
              ],
            ),
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: mission.legs.length,
              onReorderItem: (oldIndex, newIndex) => notifier.updateMission(
                MissionEdits.reorderLegs(mission, oldIndex, newIndex),
              ),
              itemBuilder: (context, index) {
                final leg = mission.legs[index];
                return ListTile(
                  key: ValueKey(leg.id),
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    missionLegName(l10n, leg),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    _legSubtitle(context, leg, mission, units),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () => edit(leg),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, size: 18),
                    tooltip: l10n.plannerMission_route_deleteLeg,
                    onPressed: () => notifier.updateMission(
                      MissionEdits.removeLeg(mission, leg.id),
                    ),
                  ),
                );
              },
            ),
            const Divider(),
            _GeneratedProfileStrip(
              segments: state.segments,
              units: units,
              reason: _blockingReason(context, state, mission),
            ),
          ],
        ),
      ),
    );
  }

  static String _legSubtitle(
    BuildContext context,
    MissionLeg leg,
    DpvMission mission,
    MissionUnits units,
  ) {
    final l10n = context.l10n;
    final lines = [
      l10n.plannerMission_route_legSummary(
        units.distance(leg.distanceM),
        units.distance(leg.depthM),
        units.heading(leg.headingDeg),
      ),
      if (leg.current != null)
        l10n.plannerMission_route_ownCurrent(
          units.speed(leg.current!.speedMps),
          units.heading(leg.current!.setsTowardDeg),
        ),
      if (leg.shoreExit != null)
        l10n.plannerMission_route_shoreExit(
          units.distance(leg.shoreExit!.surfaceSwimM),
          units.distance(leg.shoreExit!.walkM),
        ),
    ];
    return lines.join('\n');
  }

  /// The first blocking validation issue, as a sentence, or null.
  static String? _blockingReason(
    BuildContext context,
    DivePlanState state,
    DpvMission mission,
  ) {
    final issues = [
      ...validateMission(mission),
      ...validatePlanForMission(divePlanFromState(state)),
    ];
    for (final issue in issues) {
      if (issue.severity == MissionIssueSeverity.blocking) {
        return missionIssueText(context.l10n, issue, mission);
      }
    }
    return null;
  }
}

class _GeneratedProfileStrip extends StatelessWidget {
  const _GeneratedProfileStrip({
    required this.segments,
    required this.units,
    required this.reason,
  });

  final List<PlanSegment> segments;
  final MissionUnits units;

  /// Why there is no profile, or null when the mission generates one.
  final String? reason;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    if (reason != null) {
      return Text(
        l10n.plannerMission_profile_none(reason!),
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.error,
        ),
      );
    }
    // Read-only: the diver sees exactly what the engine is fed.
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: Text(
        l10n.plannerMission_profile_title,
        style: theme.textTheme.bodyMedium,
      ),
      children: [
        for (final segment in segments)
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '${units.distance(segment.targetDepth)}, '
              '${(segment.durationSeconds / 60).ceil()} min',
              style: theme.textTheme.bodySmall,
            ),
          ),
      ],
    );
  }
}
```

Minutes round up (`ceil`) because a shown time is a planning figure and rounding it down understates the dive. `min` is the untranslated SI minute symbol the app uses everywhere (`UnitFormatter.perMinute` builds rates from it); it contains no `/min`, so the rate guard does not apply.

- [ ] **Step 5: Wire the editor pane**

In `plan_editor_pane.dart`, import the two new files and `dive_planner_providers.dart`, watch the mission flag in `build`:

```dart
    final missionOn = ref.watch(
      divePlanNotifierProvider.select((s) => s.mission != null),
    );
```

and replace `const SegmentList(),` with:

```dart
        const MissionToggleRow(),
        if (missionOn) const MissionLegList() else const SegmentList(),
```

- [ ] **Step 6: Run the tests**

```bash
flutter test test/features/planner/mission/mission_route_card_test.dart test/features/planner/panes/ test/architecture/
```

Expected: PASS. If a pane test counted `PlanEditorPane`'s children or found `SegmentList` by position, update it for the toggle row and say so in the commit body.

- [ ] **Step 7: Commit**

```bash
dart format lib/features/planner test/features/planner
git add lib/features/planner/presentation/mission/mission_toggle_row.dart lib/features/planner/presentation/mission/mission_leg_list.dart lib/features/planner/presentation/panes/plan_editor_pane.dart test/features/planner/mission/mission_route_card_test.dart
git commit -m "feat(planner): turn a plan into a DPV mission and edit its route on the canvas

Refs #2086"
```

---

### Task 8: The buddy picker and the diver editor

**Files:**
- Create: `lib/features/planner/presentation/mission/buddy_picker_sheet.dart`
- Create: `lib/features/planner/presentation/mission/mission_member_editor.dart`
- Test: `test/features/planner/mission/mission_member_editor_test.dart`

**Interfaces:**
- Consumes: `allBuddiesProvider` (`FutureProvider<List<Buddy>>`), `currentDiverProvider` (`FutureProvider<Diver?>`), `diverByIdProvider` (family, for a buddy linked to a diver profile), `ProfileAvatar(photo:, initials:, radius:)`, `EquipmentPickerSheet(scrollController:, selectedEquipmentIds:, typeFilter:, hideSpare:, onEquipmentSelected:)`, `ScooterSpecResolver.fromEquipment(EquipmentItem)`, `MissionUnits` (Task 5).
- Produces:
  - `typedef MissionWho = ({String name, String? buddyId, String? diverId});`
  - `Future<MissionWho?> showBuddyPickerSheet(BuildContext context)`: "Me" (the active diver: its name and `diverId`) and each buddy (name and `buddyId`), with photos.
  - `Future<MissionMember?> showMissionMemberEditor(BuildContext context, {required MissionMember member, required MissionUnits units})`.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/planner/mission/mission_member_editor_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_providers.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_attribute.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/planner/domain/entities/mission/mission_member.dart';
import 'package:submersion/features/planner/domain/entities/mission/scooter_spec.dart';
import 'package:submersion/features/planner/presentation/mission/mission_member_editor.dart';
import 'package:submersion/features/planner/presentation/mission/mission_units.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../helpers/test_app.dart';

MissionMember? lastResult;

const _member = MissionMember(
  id: 'm1',
  order: 0,
  displayName: 'Diver 1',
  sacBottom: 15,
  scooter: ScooterSpec(name: '', ratedSpeedMps: 0, burnTimeSeconds: 0),
);

Future<void> _open(WidgetTester tester) async {
  tester.view.physicalSize = const Size(400, 1200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  lastResult = null;
  await tester.pumpWidget(
    testApp(
      locale: const Locale('en'),
      overrides: [
        allBuddiesProvider.overrideWith(
          (ref) async => [
            Buddy(
              id: 'b1',
              name: 'Alex Rivers',
              createdAt: DateTime(2026, 9, 28),
              updatedAt: DateTime(2026, 9, 28),
            ),
          ],
        ),
        currentDiverProvider.overrideWith(
          (ref) async => Diver(
            id: 'd1',
            name: 'Sam Lee',
            createdAt: DateTime(2026, 9, 28),
            updatedAt: DateTime(2026, 9, 28),
          ),
        ),
        activeEquipmentProvider.overrideWith(
          (ref) async => [
            EquipmentItem(
              id: 'eq-1',
              name: 'Blacktip',
              type: EquipmentType.dpv,
              attributes: [
                EquipmentAttribute.curated(
                  equipmentId: 'eq-1',
                  key: 'speed_mps',
                  valueNum: 0.9,
                ),
                EquipmentAttribute.curated(
                  equipmentId: 'eq-1',
                  key: 'burn_time_h',
                  valueNum: 1.5,
                ),
              ],
            ),
          ],
        ),
      ],
      child: Builder(
        builder: (context) => TextButton(
          onPressed: () async => lastResult = await showMissionMemberEditor(
            context,
            member: _member,
            units: MissionUnits(UnitFormatter(const AppSettings())),
          ),
          child: const Text('open'),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('picking a buddy fills the name and buddy id', (tester) async {
    await _open(tester);
    await tester.tap(find.text('Choose a buddy'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Alex Rivers'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(lastResult!.displayName, 'Alex Rivers');
    expect(lastResult!.buddyId, 'b1');
    expect(lastResult!.diverId, isNull);
  });

  testWidgets('picking Me fills the active diver', (tester) async {
    await _open(tester);
    await tester.tap(find.text('Choose a buddy'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Me'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(lastResult!.displayName, 'Sam Lee');
    expect(lastResult!.diverId, 'd1');
  });

  testWidgets('a scooter from equipment brings its numbers', (tester) async {
    await _open(tester);
    await tester.tap(find.text('Choose from equipment'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Blacktip'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    final scooter = lastResult!.scooter;
    expect(scooter.equipmentId, 'eq-1');
    expect(scooter.ratedSpeedMps, 0.9);
    expect(scooter.burnTimeSeconds, 5400);
  });

  testWidgets('editing a picked scooter by hand makes it manual', (
    tester,
  ) async {
    await _open(tester);
    await tester.tap(find.text('Choose from equipment'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Blacktip'));
    await tester.pumpAndSettle();
    // 0.9 m/s shows as 54 m/min; the diver types their own figure.
    await tester.enterText(find.widgetWithText(TextField, '54'), '60');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(lastResult!.scooter.equipmentId, isNull);
    expect(lastResult!.scooter.ratedSpeedMps, closeTo(1.0, 1e-9));
  });
}
```

`EquipmentPickerSheet` may title an item by brand and model rather than `name`; if the tap on 'Blacktip' finds nothing, give the fixture a `brand`/`model` and tap the text the sheet shows.

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/features/planner/mission/mission_member_editor_test.dart`
Expected: FAIL, `mission_member_editor.dart` does not resolve.

- [ ] **Step 3: Write the buddy picker**

```dart
// lib/features/planner/presentation/mission/buddy_picker_sheet.dart
import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/profile_photo/profile_avatar.dart';

/// Who a DPV mission member is: a name, and the buddy or diver profile it
/// came from (at most one of the two ids is set).
typedef MissionWho = ({String name, String? buddyId, String? diverId});

/// A single-select sheet listing the active diver ("Me") and their buddies,
/// with photos. Returns null when dismissed.
Future<MissionWho?> showBuddyPickerSheet(BuildContext context) {
  return showModalBottomSheet<MissionWho>(
    context: context,
    isScrollControlled: true,
    builder: (context) => const _BuddyPickerSheet(),
  );
}

class _BuddyPickerSheet extends ConsumerWidget {
  const _BuddyPickerSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final me = ref.watch(currentDiverProvider).value;
    final buddies = ref.watch(allBuddiesProvider).value ?? const <Buddy>[];
    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          ListTile(title: Text(l10n.plannerMission_buddyPicker_title)),
          if (me != null)
            ListTile(
              leading: ProfileAvatar(photo: me.photo, initials: me.initials),
              title: Text(l10n.plannerMission_buddyPicker_me),
              subtitle: Text(me.name, maxLines: 1),
              onTap: () => Navigator.of(
                context,
              ).pop((name: me.name, buddyId: null, diverId: me.id)),
            ),
          if (buddies.isEmpty)
            ListTile(title: Text(l10n.plannerMission_buddyPicker_empty)),
          for (final buddy in buddies)
            ListTile(
              leading: ProfileAvatar(
                photo: buddy.photo,
                initials: buddy.initials,
              ),
              title: Text(
                buddy.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () => Navigator.of(
                context,
              ).pop((name: buddy.name, buddyId: buddy.id, diverId: null)),
            ),
        ],
      ),
    );
  }
}
```

A buddy linked to a diver profile shows that profile's photo when the buddy has none: follow `_BuddyAvatar` in `lib/features/buddies/presentation/widgets/buddy_list_tile.dart:291` (read `diverByIdProvider(buddy.linkedDiverId!)` and prefer `buddy.photo ?? diver.photo`) as a small private `_BuddyLeading` widget here.

- [ ] **Step 4: Write the diver editor**

```dart
// lib/features/planner/presentation/mission/mission_member_editor.dart
import 'package:flutter/material.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/presentation/widgets/pickers/equipment_picker_sheet.dart';
import 'package:submersion/features/dive_planner/presentation/widgets/setup/plan_number_field.dart';
import 'package:submersion/features/planner/domain/entities/mission/mission_member.dart';
import 'package:submersion/features/planner/domain/entities/mission/scooter_spec.dart';
import 'package:submersion/features/planner/domain/services/mission/scooter_spec_resolver.dart';
import 'package:submersion/features/planner/presentation/mission/buddy_picker_sheet.dart';
import 'package:submersion/features/planner/presentation/mission/mission_units.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Edits one diver of a DPV mission: who they are, their SAC and swim
/// speed, and their scooter, picked from equipment or entered by hand.
Future<MissionMember?> showMissionMemberEditor(
  BuildContext context, {
  required MissionMember member,
  required MissionUnits units,
}) {
  return showDialog<MissionMember>(
    context: context,
    builder: (context) => _MissionMemberEditor(member: member, units: units),
  );
}

class _MissionMemberEditor extends StatefulWidget {
  const _MissionMemberEditor({required this.member, required this.units});

  final MissionMember member;
  final MissionUnits units;

  @override
  State<_MissionMemberEditor> createState() => _MissionMemberEditorState();
}

class _MissionMemberEditorState extends State<_MissionMemberEditor> {
  late MissionMember _draft;
  late final TextEditingController _name;
  late final TextEditingController _scooterName;

  @override
  void initState() {
    super.initState();
    _draft = widget.member;
    _name = TextEditingController(text: widget.member.displayName);
    _scooterName = TextEditingController(text: widget.member.scooter.name);
  }

  @override
  void dispose() {
    _name.dispose();
    _scooterName.dispose();
    super.dispose();
  }

  Future<void> _pickWho() async {
    final who = await showBuddyPickerSheet(context);
    if (who == null) return;
    setState(() {
      _name.text = who.name;
      _draft = _draft.copyWith(
        displayName: who.name,
        buddyId: who.buddyId,
        clearBuddyId: who.buddyId == null,
        diverId: who.diverId,
        clearDiverId: who.diverId == null,
      );
    });
  }

  Future<void> _pickScooter() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => EquipmentPickerSheet(
          scrollController: scrollController,
          selectedEquipmentIds: {?_draft.scooter.equipmentId},
          typeFilter: EquipmentType.dpv,
          hideSpare: false,
          onEquipmentSelected: (item) {
            Navigator.of(context).pop();
            final spec = const ScooterSpecResolver().fromEquipment(item);
            if (spec == null) return;
            setState(() {
              _scooterName.text = spec.name;
              _draft = _draft.copyWith(scooter: spec);
            });
          },
        ),
      ),
    );
  }

  void _setScooter(ScooterSpec scooter) =>
      setState(() => _draft = _draft.copyWith(scooter: scooter));

  /// A number typed over a picked scooter makes it manual: the next load
  /// must not overwrite the diver's figure from the equipment item.
  void _setScooterNumbers(ScooterSpec scooter) =>
      _setScooter(scooter.copyWith(clearEquipmentId: true));

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final u = widget.units;
    final scooter = _draft.scooter;
    return AlertDialog(
      title: Text(l10n.plannerMission_team_editDiver),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _name,
              decoration: InputDecoration(
                labelText: l10n.plannerMission_member_name,
              ),
              onChanged: (v) => _draft = _draft.copyWith(displayName: v),
            ),
            TextButton.icon(
              icon: const Icon(Icons.people_outline),
              label: Text(l10n.plannerMission_member_pickBuddy),
              onPressed: _pickWho,
            ),
            PlanNumberField(
              label: l10n.plannerMission_member_sac,
              value: u.sacDisplay(_draft.sacBottom),
              hintValue: 0,
              suffixText: u.sacSymbol,
              decimals: 1,
              min: 0,
              allowEmpty: false,
              onChanged: (v) => setState(
                () => _draft = _draft.copyWith(
                  sacBottom: u.sacLitersPerMin(v ?? 0),
                ),
              ),
            ),
            PlanNumberField(
              label: l10n.plannerMission_member_swimSpeed,
              value: u.speedDisplay(_draft.swimSpeedMps),
              hintValue: 0,
              suffixText: u.speedSymbol,
              decimals: 0,
              min: 0,
              allowEmpty: false,
              onChanged: (v) => setState(
                () => _draft = _draft.copyWith(swimSpeedMps: u.speedMps(v ?? 0)),
              ),
            ),
            const Divider(),
            Text(l10n.plannerMission_member_scooter),
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton(
                  onPressed: _pickScooter,
                  child: Text(l10n.plannerMission_member_chooseScooter),
                ),
                OutlinedButton(
                  onPressed: () => _setScooter(
                    scooter.copyWith(clearEquipmentId: true),
                  ),
                  child: Text(l10n.plannerMission_member_manualScooter),
                ),
              ],
            ),
            TextField(
              controller: _scooterName,
              decoration: InputDecoration(
                labelText: l10n.plannerMission_scooter_name,
              ),
              onChanged: (v) => _setScooter(scooter.copyWith(name: v)),
            ),
            PlanNumberField(
              label: l10n.plannerMission_scooter_speed,
              value: u.speedDisplay(scooter.ratedSpeedMps),
              hintValue: 0,
              suffixText: u.speedSymbol,
              decimals: 0,
              min: 0,
              allowEmpty: false,
              onChanged: (v) => _setScooterNumbers(
                scooter.copyWith(ratedSpeedMps: u.speedMps(v ?? 0)),
              ),
            ),
            PlanNumberField(
              label: l10n.plannerMission_scooter_burnTime,
              value: scooter.burnTimeSeconds / 60,
              hintValue: 0,
              suffixText: 'min',
              isInteger: true,
              decimals: 0,
              min: 0,
              allowEmpty: false,
              onChanged: (v) => _setScooterNumbers(
                scooter.copyWith(burnTimeSeconds: ((v ?? 0) * 60).round()),
              ),
            ),
            PlanNumberField(
              label: l10n.plannerMission_scooter_towSpeedFactor,
              value: scooter.towSpeedFactor,
              hintValue: kDefaultTowSpeedFactor,
              suffixText: '',
              decimals: 2,
              min: 0,
              max: 1,
              allowEmpty: false,
              onChanged: (v) => _setScooterNumbers(
                scooter.copyWith(towSpeedFactor: v ?? kDefaultTowSpeedFactor),
              ),
            ),
            PlanNumberField(
              label: l10n.plannerMission_scooter_towBurnFactor,
              value: scooter.towBurnFactor,
              hintValue: kDefaultTowBurnFactor,
              suffixText: '',
              decimals: 2,
              min: 1,
              allowEmpty: false,
              onChanged: (v) => _setScooterNumbers(
                scooter.copyWith(towBurnFactor: v ?? kDefaultTowBurnFactor),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.common_action_cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(
            _draft.copyWith(displayName: _name.text.trim()),
          ),
          child: Text(l10n.common_action_save),
        ),
      ],
    );
  }
}
```

`min` is the untranslated SI minute symbol the app uses everywhere (`UnitFormatter.perMinute` builds rates from it); it contains no `/min`, so the rate guard does not apply.

- [ ] **Step 5: Run the tests**

Run: `flutter test test/features/planner/mission/mission_member_editor_test.dart test/architecture/`
Expected: PASS, 4 tests (3 above plus the manual-override test).

- [ ] **Step 6: Commit**

```bash
dart format lib/features/planner test/features/planner
git add lib/features/planner/presentation/mission/buddy_picker_sheet.dart lib/features/planner/presentation/mission/mission_member_editor.dart test/features/planner/mission/mission_member_editor_test.dart
git commit -m "feat(planner): edit a DPV mission diver, with a buddy picker and a scooter from equipment

Refs #2086"
```

---

### Task 9: The DPV team section

**Files:**
- Create: `lib/features/planner/presentation/mission/mission_team_section.dart`
- Modify: `lib/features/planner/presentation/panes/plan_setup_accordion.dart`
- Test: `test/features/planner/mission/mission_team_section_test.dart`

**Interfaces:**
- Consumes: `showMissionMemberEditor` (Task 8), `MissionEdits` (Task 2), `MissionUnits` (Task 5), `DivePlanNotifier.updateMission` (Task 3).
- Produces: `MissionTeamSection` (`const MissionTeamSection({super.key})`), and an accordion record `('dpvTeam', l10n.plannerMission_team_title, const MissionTeamSection())` present only while a mission is on.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/planner/mission/mission_team_section_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/map_style.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
import 'package:submersion/features/planner/domain/entities/mission/dpv_mission.dart';
import 'package:submersion/features/planner/domain/services/mission/mission_edits.dart';
import 'package:submersion/features/planner/presentation/panes/plan_setup_accordion.dart';
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

Widget _harness() => testApp(
  overrides: [settingsProvider.overrideWith((ref) => _TestSettingsNotifier())],
  locale: const Locale('en'),
  child: const SingleChildScrollView(child: PlanSetupAccordion()),
);

void main() {
  testWidgets('the DPV team section appears only with a mission', (
    tester,
  ) async {
    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();
    expect(find.text('DPV team'), findsNothing);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(PlanSetupAccordion)),
    );
    container
        .read(divePlanNotifierProvider.notifier)
        .enableMission(
          MissionEdits.starter(
            legId: 'L1',
            memberId: 'm1',
            memberName: 'Sam',
            sacBottom: 15,
          ),
        );
    await tester.pumpAndSettle();
    expect(find.text('DPV team'), findsOneWidget);
  });

  testWidgets('adding a diver adds a card, open water shows walk speed', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(PlanSetupAccordion)),
    );
    final notifier = container.read(divePlanNotifierProvider.notifier);
    notifier.enableMission(
      MissionEdits.starter(
        legId: 'L1',
        memberId: 'm1',
        memberName: 'Sam',
        sacBottom: 15,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('DPV team'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Add diver'));
    await tester.pumpAndSettle();
    expect(container.read(divePlanNotifierProvider).mission!.team, hasLength(2));

    expect(find.text('Walking speed'), findsNothing);
    await tester.tap(find.text('Open water'));
    await tester.pumpAndSettle();
    expect(
      container.read(divePlanNotifierProvider).mission!.environment,
      MissionEnvironment.openWater,
    );
    expect(find.text('Walking speed'), findsOneWidget);
  });
}
```

The existing `plan_setup_accordion_test.dart` asserts six sections on an open-circuit plan; with no mission the count stays six, so it must keep passing unchanged.

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/features/planner/mission/mission_team_section_test.dart`
Expected: FAIL, no "DPV team" after enabling the mission.

- [ ] **Step 3: Write the section**

```dart
// lib/features/planner/presentation/mission/mission_team_section.dart
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
import 'package:submersion/features/dive_planner/presentation/widgets/setup/plan_number_field.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/planner/domain/entities/mission/current_vector.dart';
import 'package:submersion/features/planner/domain/entities/mission/dpv_mission.dart';
import 'package:submersion/features/planner/domain/entities/mission/mission_member.dart';
import 'package:submersion/features/planner/domain/services/mission/mission_edits.dart';
import 'package:submersion/features/planner/presentation/mission/mission_member_editor.dart';
import 'package:submersion/features/planner/presentation/mission/mission_units.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The "DPV team" accordion section: one card per diver, then the mission's
/// own settings (environment, battery reserve, default current and, in open
/// water, walking speed and the longest surface swim).
class MissionTeamSection extends ConsumerWidget {
  const MissionTeamSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mission = ref.watch(divePlanNotifierProvider.select((s) => s.mission));
    if (mission == null) return const SizedBox.shrink();
    final notifier = ref.read(divePlanNotifierProvider.notifier);
    final units = MissionUnits(UnitFormatter(ref.watch(settingsProvider)));
    final l10n = context.l10n;
    final defaultCurrent = mission.defaultCurrent;
    final openWater = mission.environment == MissionEnvironment.openWater;

    Future<void> edit(MissionMember member) async {
      final edited = await showMissionMemberEditor(
        context,
        member: member,
        units: units,
      );
      if (edited != null) {
        notifier.updateMission(MissionEdits.updateMember(mission, edited));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final member in mission.team)
          _MemberCard(
            member: member,
            units: units,
            onEdit: () => edit(member),
            onRemove: mission.team.length == 1
                ? null
                : () => notifier.updateMission(
                    MissionEdits.removeMember(mission, member.id),
                  ),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: Tooltip(
            message: l10n.plannerMission_team_addDiver,
            child: TextButton.icon(
              icon: const Icon(Icons.person_add_alt),
              label: Text(l10n.plannerMission_team_addDiver),
              onPressed: () => notifier.updateMission(
                MissionEdits.addMember(
                  mission,
                  const Uuid().v4(),
                  name: l10n.plannerMission_team_defaultName(
                    mission.team.length + 1,
                  ),
                  // A new diver starts on the first diver's SAC; the plan's
                  // own SAC seeded that one.
                  sacBottom: mission.team.isEmpty
                      ? ref.read(divePlanNotifierProvider).sacRate
                      : mission.team.first.sacBottom,
                ),
              ),
            ),
          ),
        ),
        const Divider(),
        Text(l10n.plannerMission_settings_environment),
        SegmentedButton<MissionEnvironment>(
          segments: [
            ButtonSegment(
              value: MissionEnvironment.overhead,
              label: Text(l10n.plannerMission_environment_overhead),
            ),
            ButtonSegment(
              value: MissionEnvironment.openWater,
              label: Text(l10n.plannerMission_environment_openWater),
            ),
          ],
          selected: {mission.environment},
          onSelectionChanged: (s) => notifier.updateMission(
            mission.copyWith(environment: s.single),
          ),
        ),
        PlanNumberField(
          label: l10n.plannerMission_settings_batteryReserve,
          value: mission.batteryReserveFraction * 100,
          hintValue: kDefaultBatteryReserveFraction * 100,
          suffixText: '%',
          decimals: 0,
          min: 0,
          max: 100,
          allowEmpty: false,
          onChanged: (v) => notifier.updateMission(
            mission.copyWith(
              batteryReserveFraction: (v ?? kDefaultBatteryReserveFraction * 100) / 100,
            ),
          ),
        ),
        PlanNumberField(
          label: l10n.plannerMission_settings_defaultCurrent,
          value: defaultCurrent == null
              ? null
              : units.speedDisplay(defaultCurrent.speedMps),
          hintValue: 0,
          suffixText: units.speedSymbol,
          decimals: 0,
          min: 0,
          onChanged: (v) => notifier.updateMission(
            v == null || v == 0
                ? mission.copyWith(clearDefaultCurrent: true)
                : mission.copyWith(
                    defaultCurrent: CurrentVector(
                      speedMps: units.speedMps(v),
                      setsTowardDeg: defaultCurrent?.setsTowardDeg ?? 0,
                    ),
                  ),
          ),
        ),
        if (defaultCurrent != null)
          PlanNumberField(
            label: l10n.plannerMission_current_setsToward,
            value: defaultCurrent.setsTowardDeg,
            hintValue: 0,
            suffixText: '°',
            decimals: 0,
            min: 0,
            max: 359,
            allowEmpty: false,
            onChanged: (v) => notifier.updateMission(
              mission.copyWith(
                defaultCurrent: CurrentVector(
                  speedMps: defaultCurrent.speedMps,
                  setsTowardDeg: v ?? 0,
                ),
              ),
            ),
          ),
        if (openWater) ...[
          PlanNumberField(
            label: l10n.plannerMission_settings_walkSpeed,
            value: units.speedDisplay(mission.walkSpeedMps),
            hintValue: units.speedDisplay(kDefaultWalkSpeedMps),
            suffixText: units.speedSymbol,
            decimals: 0,
            min: 0,
            allowEmpty: false,
            onChanged: (v) => notifier.updateMission(
              mission.copyWith(
                walkSpeedMps: v == null ? kDefaultWalkSpeedMps : units.speedMps(v),
              ),
            ),
          ),
          PlanNumberField(
            label: l10n.plannerMission_settings_surfaceSwimLimit,
            value: mission.surfaceSwimLimitM == null
                ? null
                : units.distanceDisplay(mission.surfaceSwimLimitM!),
            hintValue: 0,
            suffixText: units.distanceSymbol,
            decimals: 0,
            min: 0,
            onChanged: (v) => notifier.updateMission(
              v == null
                  ? mission.copyWith(clearSurfaceSwimLimit: true)
                  : mission.copyWith(
                      surfaceSwimLimitM: units.distanceMeters(v),
                    ),
            ),
          ),
        ],
      ],
    );
  }
}

class _MemberCard extends ConsumerWidget {
  const _MemberCard({
    required this.member,
    required this.units,
    required this.onEdit,
    required this.onRemove,
  });

  final MissionMember member;
  final MissionUnits units;
  final VoidCallback onEdit;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final scooter = member.scooter;
    final hasScooter = scooter.ratedSpeedMps > 0 && scooter.burnTimeSeconds > 0;
    // Capacity is for information only and is not part of the snapshot, so
    // it comes from the live item a picked scooter still points at.
    final equipmentId = scooter.equipmentId;
    final capacityWh = equipmentId == null
        ? null
        : ref.watch(equipmentItemProvider(equipmentId)).value?.dpvBatteryCapacityWh;
    return Card(
      child: ListTile(
        title: Text(
          member.displayName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          [
            l10n.plannerMission_team_memberSummary(
              units.sac(member.sacBottom),
              units.speed(member.swimSpeedMps),
            ),
            if (hasScooter)
              l10n.plannerMission_team_scooterSummary(
                scooter.name,
                units.speed(scooter.ratedSpeedMps),
                (scooter.burnTimeSeconds / 60).round().toString(),
              )
            else
              l10n.plannerMission_team_noScooter,
            if (capacityWh != null)
              l10n.plannerMission_team_capacity(capacityWh.round().toString()),
          ].join('\n'),
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
        onTap: onEdit,
        trailing: onRemove == null
            ? null
            : IconButton(
                icon: const Icon(Icons.delete, size: 18),
                tooltip: l10n.plannerMission_team_removeDiver,
                onPressed: onRemove,
              ),
      ),
    );
  }
}
```

- [ ] **Step 4: Add the accordion record**

In `plan_setup_accordion.dart`, import `mission_team_section.dart`, watch the mission flag next to `mode`:

```dart
    final missionOn = ref.watch(
      divePlanNotifierProvider.select((s) => s.mission != null),
    );
```

and add after the `'contingencies'` record:

```dart
      if (missionOn)
        (
          'dpvTeam',
          context.l10n.plannerMission_team_title,
          const MissionTeamSection(),
        ),
```

- [ ] **Step 5: Run the tests**

```bash
flutter test test/features/planner/mission/ test/features/planner/panes/ test/architecture/
```

Expected: PASS, including the unchanged six-section accordion test.

- [ ] **Step 6: Commit**

```bash
dart format lib/features/planner test/features/planner
git add lib/features/planner/presentation/mission/mission_team_section.dart lib/features/planner/presentation/panes/plan_setup_accordion.dart test/features/planner/mission/mission_team_section_test.dart
git commit -m "feat(planner): the DPV team and mission settings in the plan setup

Refs #2086"
```

---

### Task 10: Verification, screenshots and the PR

- [ ] **Step 1: Whole-project checks**

```bash
dart format . && git status --short
flutter analyze
flutter test test/architecture/ test/l10n/
```

Expected: nothing changed by the formatter; `No issues found!`; both suites pass.

- [ ] **Step 2: One full suite run, with nothing else running**

```bash
flutter test --reporter=failures-only > /tmp/pr3a-suite.log 2>&1; echo "exit $?" >> /tmp/pr3a-suite.log; tail -3 /tmp/pr3a-suite.log
```

Expected: `exit 0`. Do not pipe the test run into `grep`; read the log.

- [ ] **Step 3: Screenshots**

The PR changes `lib/**/presentation/`, so it needs screenshots. Capture each with a throwaway golden test (a `testWidgets` that pumps the canvas at the target size, calls `expectLater(find.byType(...), matchesGoldenFile('shot.png'))`, run with `--update-goldens`, then delete the test and keep the PNGs outside the repo). Needed, with realistic data (a two-diver mission, three legs, one with a current, open water with a shore exit):
- the editor pane with the mission off (before) and on (after), phone (390 wide) and desktop (1280 wide);
- the leg editor dialog and the diver editor dialog, metric and imperial;
- the DPV team section expanded, light and dark.

Hand the image files to the maintainer; they are dragged into the PR description on github.com.

- [ ] **Step 4: Open the PR**

Push the branch and open the PR against main with a body that says `Refs #2086`, summarises the change (PR 3a of the canvas UI: editing), lists the tests, and keeps the Screenshots section listing what each image shows. No tool attribution anywhere.

---

## Self-review

**Spec coverage.** Enabling (Task 7: toggle, starter mission from the plan's SAC, confirmation on turning off, segments kept); route editor with label, distance, depth, heading, current row with the mission default, open-water shore exit, add/delete/reorder, generated-profile strip (Tasks 6, 7); team editor with name and buddy picker (buddies and "Me", per the 2026-09-28 decision), SAC, swim speed, scooter from DPV equipment or manual, Wh capacity for information, mission-level fields (Tasks 8, 9); notifier mutations regenerating segments and the scooter overlay on load (Task 3); units per the spec's Units paragraph (Task 5); strings in all eleven files (Task 4); widget tests for leg edits, the team section's scooter picker, enabling and disabling (Tasks 7 to 9). The Results section, the status chip, `missionOutcomeProvider` and the isolate are PR 3b.

**Type consistency.** `MissionEdits` names are identical in Tasks 2, 3, 7, 8 and 9; `missionIssueText`/`missionLegName` in Tasks 4 and 7; `MissionUnits` members in Tasks 5 to 9; `MissionWho` only in Task 8.

**Review Focus coverage.** 1: `mission_units_test` round trip and the feet display test (Tasks 5, 6). 2: the "No profile yet" assertion (Task 7). 3: the disable test (Tasks 3, 7). 4: the overlay tests (Tasks 2, 3). 5: the 320 pt test (Task 7); add the same check to the team section test after Step 5 of Task 9.
