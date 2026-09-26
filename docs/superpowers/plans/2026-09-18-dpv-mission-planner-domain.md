# DPV Mission Planner, PR 1 (domain and calculation) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the pure-domain DPV mission model and the mission engine that turns a waypoint route plus a team into plan segments, battery burn, per-waypoint failure scenarios and a constraint report, with no UI and no schema change.

**Architecture:** New entities under `lib/features/planner/domain/entities/mission/` and services under `lib/features/planner/domain/services/mission/`. The mission engine builds scenario `DivePlan` copies and runs the existing `PlanEngine.compute` once per scenario for deco and time to surface; per-member gas is derived from the scenario schedule rows. `PlanEngine` is never modified. `DivePlan` gains one nullable `mission` field. The DPV equipment attribute catalog gains two tow factors and `EquipmentItem` gains typed getters.

**Tech Stack:** Flutter, Dart 3 (records, pattern matching), `equatable`, `flutter_test`. No Riverpod, Drift or widgets in this PR.

**Spec:** `docs/superpowers/specs/2026-09-18-dpv-mission-planner-design.md` (issue #2086). Read the spec first; the plan argues from it.

## Global Constraints

- No em-dashes (U+2014), en-dashes as punctuation, or double hyphens anywhere: code, comments, tests, commit messages. Rewrite the sentence instead.
- No mention of Claude, Claude Code or Anthropic in any file, commit message or PR text. No co-author trailers.
- No emojis in code, comments or docs.
- Immutability: every entity is `Equatable` with `const` constructors and `copyWith`; never mutate lists, always build new ones.
- Files: one responsibility each, 200-400 lines typical, 800 max.
- Imports grouped: dart, flutter, packages, local. Use absolute `package:submersion/...` imports as the planner does.
- All metric values are stored in SI: metres, seconds, m/s, litres, bar. No unit conversion in this PR (no UI).
- Run `dart format .` before every commit. Run `flutter analyze` on the whole project before the final commit; infos are fatal in CI.
- Run tests with `flutter test <specific file>`; never a whole large directory in one foreground call.
- Commit messages: conventional prefix (`feat(planner):`, `test(planner):`), body line `Refs #2086`.
- Every PR body must contain `Refs #2086` (this PR does not close the issue).

---

## File Structure

Entities (`lib/features/planner/domain/entities/mission/`):

| File | Responsibility |
| --- | --- |
| `current_vector.dart` | `CurrentVector` (speed, sets-toward direction) and its along-route component |
| `scooter_spec.dart` | `ScooterSpec` with tow-factor defaults |
| `mission_member.dart` | `MissionMember` |
| `mission_leg.dart` | `MissionLeg` |
| `dpv_mission.dart` | `DpvMission` aggregate, effective current per leg |
| `mission_outcome.dart` | Every result type the engine produces (issues, leg, waypoint, member, constraint, outcome) |

Services (`lib/features/planner/domain/services/mission/`):

| File | Responsibility |
| --- | --- |
| `scooter_spec_resolver.dart` | `ScooterSpec` from an `EquipmentItem`, and live-attribute overlay of a stored spec |
| `mission_team.dart` | Cruise speed, cruise-limiting member, slowest swim speed |
| `leg_speed_resolver.dart` | Outbound and return effective speed per leg, traversability |
| `mission_segment_builder.dart` | Route to `PlanSegment` list with waypoint arrival times |
| `battery_burn_service.dart` | Burn fraction and reserve check |
| `member_gas_service.dart` | Litres per tank over schedule rows for one member, remaining pressure |
| `mission_scenario_service.dart` | One failure scenario (member, waypoint, exit mode) through `PlanEngine` |
| `mission_engine.dart` | Orchestrator: validation, route, scenarios, abandonment point, constraint, turn pressure |

Modified:

| File | Change |
| --- | --- |
| `lib/features/planner/domain/entities/dive_plan.dart` | `mission` field, `copyWith` with `clearMission`, props |
| `lib/features/equipment/domain/constants/equipment_attribute_catalog.dart` | five `EquipmentAttrKeys` constants, two DPV defs |
| `lib/features/equipment/domain/entities/equipment_item.dart` | five typed DPV getters |
| `lib/features/equipment/presentation/utils/equipment_attribute_l10n.dart` | two label cases |
| `lib/l10n/arb/app_*.arb` (11 files) | `attrLabel_tow_speed_factor`, `attrLabel_tow_burn_factor` |

Tests mirror under `test/features/planner/mission/` and `test/features/equipment/`.

---

### Task 1: Mission entities

**Files:**
- Create: `lib/features/planner/domain/entities/mission/current_vector.dart`
- Create: `lib/features/planner/domain/entities/mission/scooter_spec.dart`
- Create: `lib/features/planner/domain/entities/mission/mission_member.dart`
- Create: `lib/features/planner/domain/entities/mission/mission_leg.dart`
- Create: `lib/features/planner/domain/entities/mission/dpv_mission.dart`
- Test: `test/features/planner/mission/mission_entities_test.dart`

**Interfaces:**
- Produces: `CurrentVector({required double speedMps, required double setsTowardDeg})` with `double alongRouteComponent(double headingDeg)`; `ScooterSpec({String? equipmentId, required String name, required double ratedSpeedMps, required int burnTimeSeconds, double towSpeedFactor = kDefaultTowSpeedFactor, double towBurnFactor = kDefaultTowBurnFactor})`; `MissionMember({required String id, required int order, required String displayName, String? buddyId, String? diverId, required double sacBottom, double swimSpeedMps = kDefaultSwimSpeedMps, required ScooterSpec scooter})`; `MissionLeg({required String id, required int order, required String label, required double distanceM, required double depthM, required double headingDeg, CurrentVector? current})`; `DpvMission({List<MissionLeg> legs = const [], List<MissionMember> team = const [], double batteryReserveFraction = kDefaultBatteryReserveFraction, CurrentVector? defaultCurrent})` with `CurrentVector? currentFor(MissionLeg leg)`.

- [ ] **Step 1: Write the failing tests**

```dart
// test/features/planner/mission/mission_entities_test.dart
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/planner/domain/entities/mission/current_vector.dart';
import 'package:submersion/features/planner/domain/entities/mission/dpv_mission.dart';
import 'package:submersion/features/planner/domain/entities/mission/mission_leg.dart';
import 'package:submersion/features/planner/domain/entities/mission/mission_member.dart';
import 'package:submersion/features/planner/domain/entities/mission/scooter_spec.dart';

const _scooter = ScooterSpec(
  name: 'Blacktip',
  ratedSpeedMps: 0.9,
  burnTimeSeconds: 5400,
);

MissionLeg _leg({String id = 'l1', CurrentVector? current}) => MissionLeg(
  id: id,
  order: 0,
  label: 'T',
  distanceM: 300,
  depthM: 20,
  headingDeg: 90,
  current: current,
);

void main() {
  group('CurrentVector.alongRouteComponent', () {
    test('a current setting along the heading helps by its full speed', () {
      const current = CurrentVector(speedMps: 0.5, setsTowardDeg: 90);
      expect(current.alongRouteComponent(90), closeTo(0.5, 1e-9));
    });

    test('a current setting against the heading hurts by its full speed', () {
      const current = CurrentVector(speedMps: 0.5, setsTowardDeg: 270);
      expect(current.alongRouteComponent(90), closeTo(-0.5, 1e-9));
    });

    test('a cross current contributes nothing along the route', () {
      const current = CurrentVector(speedMps: 0.5, setsTowardDeg: 0);
      expect(current.alongRouteComponent(90), closeTo(0, 1e-9));
    });

    test('a quartering current contributes cos(45 degrees) of its speed', () {
      const current = CurrentVector(speedMps: 0.5, setsTowardDeg: 45);
      expect(
        current.alongRouteComponent(90),
        closeTo(0.5 * math.cos(math.pi / 4), 1e-9),
      );
    });

    test('the reversed heading flips the sign', () {
      const current = CurrentVector(speedMps: 0.5, setsTowardDeg: 45);
      expect(
        current.alongRouteComponent(270),
        closeTo(-current.alongRouteComponent(90), 1e-9),
      );
    });
  });

  group('ScooterSpec defaults', () {
    test('tow factors default to 0.6 speed and 1.5 burn', () {
      expect(_scooter.towSpeedFactor, 0.6);
      expect(_scooter.towBurnFactor, 1.5);
      expect(_scooter.equipmentId, isNull);
    });

    test('copyWith can clear the equipment id', () {
      const linked = ScooterSpec(
        equipmentId: 'eq-1',
        name: 'Blacktip',
        ratedSpeedMps: 0.9,
        burnTimeSeconds: 5400,
      );
      expect(linked.copyWith(clearEquipmentId: true).equipmentId, isNull);
      expect(linked.copyWith(name: 'Other').equipmentId, 'eq-1');
    });
  });

  group('MissionMember defaults', () {
    test('swim speed defaults to 0.2 m/s', () {
      const member = MissionMember(
        id: 'm1',
        order: 0,
        displayName: 'Sam',
        sacBottom: 15,
        scooter: _scooter,
      );
      expect(member.swimSpeedMps, 0.2);
      expect(member.buddyId, isNull);
      expect(member.diverId, isNull);
    });
  });

  group('DpvMission', () {
    test('battery reserve defaults to one third', () {
      const mission = DpvMission();
      expect(mission.batteryReserveFraction, closeTo(1 / 3, 1e-12));
      expect(mission.legs, isEmpty);
      expect(mission.team, isEmpty);
    });

    test('currentFor prefers the leg current over the mission default', () {
      const legCurrent = CurrentVector(speedMps: 0.3, setsTowardDeg: 10);
      const defaultCurrent = CurrentVector(speedMps: 0.1, setsTowardDeg: 200);
      final mission = DpvMission(
        legs: [_leg(current: legCurrent), _leg(id: 'l2')],
        defaultCurrent: defaultCurrent,
      );
      expect(mission.currentFor(mission.legs[0]), legCurrent);
      expect(mission.currentFor(mission.legs[1]), defaultCurrent);
    });

    test('currentFor is null when neither the leg nor the mission has one', () {
      final mission = DpvMission(legs: [_leg()]);
      expect(mission.currentFor(mission.legs[0]), isNull);
    });

    test('value equality holds across copies', () {
      final a = DpvMission(legs: [_leg()], batteryReserveFraction: 0.25);
      final b = DpvMission(legs: [_leg()], batteryReserveFraction: 0.25);
      expect(a, b);
      expect(a.copyWith(batteryReserveFraction: 0.5), isNot(b));
    });
  });
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/features/planner/mission/mission_entities_test.dart`
Expected: FAIL, the imports do not resolve ("Target of URI doesn't exist").

- [ ] **Step 3: Write the entities**

```dart
// lib/features/planner/domain/entities/mission/current_vector.dart
import 'dart:math' as math;

import 'package:equatable/equatable.dart';

/// A steady water current: how fast it flows and the direction it sets
/// toward (the oceanographic convention, the opposite of wind, which is named
/// by where it comes from).
class CurrentVector extends Equatable {
  /// Current speed in metres per second, never negative.
  final double speedMps;

  /// True direction the water flows toward, in degrees 0 to 360.
  final double setsTowardDeg;

  const CurrentVector({required this.speedMps, required this.setsTowardDeg});

  /// The component of this current along a leg travelled on [headingDeg],
  /// in m/s. Positive helps the diver along, negative holds them back.
  double alongRouteComponent(double headingDeg) {
    final radians = (setsTowardDeg - headingDeg) * math.pi / 180.0;
    return speedMps * math.cos(radians);
  }

  CurrentVector copyWith({double? speedMps, double? setsTowardDeg}) {
    return CurrentVector(
      speedMps: speedMps ?? this.speedMps,
      setsTowardDeg: setsTowardDeg ?? this.setsTowardDeg,
    );
  }

  @override
  List<Object?> get props => [speedMps, setsTowardDeg];
}
```

```dart
// lib/features/planner/domain/entities/mission/scooter_spec.dart
import 'package:equatable/equatable.dart';

/// Tower's speed while towing, as a fraction of the scooter's rated speed.
const double kDefaultTowSpeedFactor = 0.6;

/// Burn-rate multiplier while towing.
const double kDefaultTowBurnFactor = 1.5;

/// The numbers a mission needs from a scooter.
///
/// Snapshotted from the equipment item when the scooter is picked, so a plan
/// stays computable after the item is deleted, and overlaid with the item's
/// live attributes whenever it still exists (see `ScooterSpecResolver`).
class ScooterSpec extends Equatable {
  /// The equipment item this came from; null for a manual scooter.
  final String? equipmentId;
  final String name;

  /// Rated cruise speed in m/s.
  final double ratedSpeedMps;

  /// Rated run time at rated speed, in seconds.
  final int burnTimeSeconds;
  final double towSpeedFactor;
  final double towBurnFactor;

  const ScooterSpec({
    this.equipmentId,
    required this.name,
    required this.ratedSpeedMps,
    required this.burnTimeSeconds,
    this.towSpeedFactor = kDefaultTowSpeedFactor,
    this.towBurnFactor = kDefaultTowBurnFactor,
  });

  /// Speed in m/s this scooter makes while towing another diver.
  double get towSpeedMps => ratedSpeedMps * towSpeedFactor;

  ScooterSpec copyWith({
    String? equipmentId,
    bool clearEquipmentId = false,
    String? name,
    double? ratedSpeedMps,
    int? burnTimeSeconds,
    double? towSpeedFactor,
    double? towBurnFactor,
  }) {
    return ScooterSpec(
      equipmentId: clearEquipmentId ? null : (equipmentId ?? this.equipmentId),
      name: name ?? this.name,
      ratedSpeedMps: ratedSpeedMps ?? this.ratedSpeedMps,
      burnTimeSeconds: burnTimeSeconds ?? this.burnTimeSeconds,
      towSpeedFactor: towSpeedFactor ?? this.towSpeedFactor,
      towBurnFactor: towBurnFactor ?? this.towBurnFactor,
    );
  }

  @override
  List<Object?> get props => [
    equipmentId,
    name,
    ratedSpeedMps,
    burnTimeSeconds,
    towSpeedFactor,
    towBurnFactor,
  ];
}
```

```dart
// lib/features/planner/domain/entities/mission/mission_member.dart
import 'package:equatable/equatable.dart';

import 'package:submersion/features/planner/domain/entities/mission/scooter_spec.dart';

/// Unassisted swim speed with full kit, in m/s (12 m/min).
const double kDefaultSwimSpeedMps = 0.2;

/// One diver on a DPV mission, with their own consumption and scooter.
///
/// SAC lives here because no buddy or diver record stores one; the optional
/// links only supply a name and a photo.
class MissionMember extends Equatable {
  final String id;
  final int order;
  final String displayName;
  final String? buddyId;
  final String? diverId;

  /// Bottom surface air consumption in litres per minute.
  final double sacBottom;

  /// Speed this member swims at when their scooter is dead, in m/s.
  final double swimSpeedMps;
  final ScooterSpec scooter;

  const MissionMember({
    required this.id,
    required this.order,
    required this.displayName,
    this.buddyId,
    this.diverId,
    required this.sacBottom,
    this.swimSpeedMps = kDefaultSwimSpeedMps,
    required this.scooter,
  });

  MissionMember copyWith({
    String? id,
    int? order,
    String? displayName,
    String? buddyId,
    bool clearBuddyId = false,
    String? diverId,
    bool clearDiverId = false,
    double? sacBottom,
    double? swimSpeedMps,
    ScooterSpec? scooter,
  }) {
    return MissionMember(
      id: id ?? this.id,
      order: order ?? this.order,
      displayName: displayName ?? this.displayName,
      buddyId: clearBuddyId ? null : (buddyId ?? this.buddyId),
      diverId: clearDiverId ? null : (diverId ?? this.diverId),
      sacBottom: sacBottom ?? this.sacBottom,
      swimSpeedMps: swimSpeedMps ?? this.swimSpeedMps,
      scooter: scooter ?? this.scooter,
    );
  }

  @override
  List<Object?> get props => [
    id,
    order,
    displayName,
    buddyId,
    diverId,
    sacBottom,
    swimSpeedMps,
    scooter,
  ];
}
```

```dart
// lib/features/planner/domain/entities/mission/mission_leg.dart
import 'package:equatable/equatable.dart';

import 'package:submersion/features/planner/domain/entities/mission/current_vector.dart';

/// One outbound leg of a mission route. It ends at the waypoint it names.
class MissionLeg extends Equatable {
  final String id;
  final int order;

  /// Waypoint name, for example "T" or "Jump 2".
  final String label;

  /// Horizontal distance in metres, greater than zero.
  final double distanceM;

  /// Depth held along the leg, in metres.
  final double depthM;

  /// True heading of travel in degrees, 0 to 360.
  final double headingDeg;

  /// Current on this leg; null inherits the mission default.
  final CurrentVector? current;

  const MissionLeg({
    required this.id,
    required this.order,
    required this.label,
    required this.distanceM,
    required this.depthM,
    required this.headingDeg,
    this.current,
  });

  /// Heading of the return trip along this leg.
  double get returnHeadingDeg => (headingDeg + 180.0) % 360.0;

  MissionLeg copyWith({
    String? id,
    int? order,
    String? label,
    double? distanceM,
    double? depthM,
    double? headingDeg,
    CurrentVector? current,
    bool clearCurrent = false,
  }) {
    return MissionLeg(
      id: id ?? this.id,
      order: order ?? this.order,
      label: label ?? this.label,
      distanceM: distanceM ?? this.distanceM,
      depthM: depthM ?? this.depthM,
      headingDeg: headingDeg ?? this.headingDeg,
      current: clearCurrent ? null : (current ?? this.current),
    );
  }

  @override
  List<Object?> get props => [
    id,
    order,
    label,
    distanceM,
    depthM,
    headingDeg,
    current,
  ];
}
```

```dart
// lib/features/planner/domain/entities/mission/dpv_mission.dart
import 'package:equatable/equatable.dart';

import 'package:submersion/features/planner/domain/entities/mission/current_vector.dart';
import 'package:submersion/features/planner/domain/entities/mission/mission_leg.dart';
import 'package:submersion/features/planner/domain/entities/mission/mission_member.dart';

/// Fraction of burn time that must remain at the surface.
const double kDefaultBatteryReserveFraction = 1.0 / 3.0;

/// A scooter mission attached to a dive plan: the outbound route, the team,
/// and the battery reserve rule. The return trip is derived, never authored.
class DpvMission extends Equatable {
  /// Ordered outbound legs.
  final List<MissionLeg> legs;

  /// Ordered team; a valid mission has at least one member.
  final List<MissionMember> team;
  final double batteryReserveFraction;

  /// Current inherited by legs whose own current is null.
  final CurrentVector? defaultCurrent;

  const DpvMission({
    this.legs = const [],
    this.team = const [],
    this.batteryReserveFraction = kDefaultBatteryReserveFraction,
    this.defaultCurrent,
  });

  /// The current in force on [leg]: its own, else the mission default.
  CurrentVector? currentFor(MissionLeg leg) => leg.current ?? defaultCurrent;

  DpvMission copyWith({
    List<MissionLeg>? legs,
    List<MissionMember>? team,
    double? batteryReserveFraction,
    CurrentVector? defaultCurrent,
    bool clearDefaultCurrent = false,
  }) {
    return DpvMission(
      legs: legs ?? this.legs,
      team: team ?? this.team,
      batteryReserveFraction:
          batteryReserveFraction ?? this.batteryReserveFraction,
      defaultCurrent: clearDefaultCurrent
          ? null
          : (defaultCurrent ?? this.defaultCurrent),
    );
  }

  @override
  List<Object?> get props => [
    legs,
    team,
    batteryReserveFraction,
    defaultCurrent,
  ];
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/features/planner/mission/mission_entities_test.dart`
Expected: PASS, 12 tests.

- [ ] **Step 5: Format and commit**

```bash
dart format lib/features/planner/domain/entities/mission test/features/planner/mission
git add lib/features/planner/domain/entities/mission test/features/planner/mission/mission_entities_test.dart
git commit -m "feat(planner): add DPV mission entities

Refs #2086"
```

---

### Task 2: `DivePlan.mission`

**Files:**
- Modify: `lib/features/planner/domain/entities/dive_plan.dart` (fields near line 136, constructor near line 189, `copyWith` near line 281, props near line 407)
- Test: `test/features/planner/mission/dive_plan_mission_field_test.dart`

**Interfaces:**
- Produces: `DivePlan.mission` (`DpvMission?`, default null), `copyWith({DpvMission? mission, bool clearMission = false})`.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/planner/mission/dive_plan_mission_field_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    as domain;
import 'package:submersion/features/planner/domain/entities/mission/dpv_mission.dart';

domain.DivePlan _plan() => domain.DivePlan(
  id: 'plan-1',
  name: 'Mission field',
  gfLow: 40,
  gfHigh: 80,
  createdAt: DateTime(2026, 9, 18),
  updatedAt: DateTime(2026, 9, 18),
);

void main() {
  test('a plan has no mission by default', () {
    expect(_plan().mission, isNull);
  });

  test('copyWith sets and clears the mission', () {
    const mission = DpvMission(batteryReserveFraction: 0.5);
    final withMission = _plan().copyWith(mission: mission);
    expect(withMission.mission, mission);
    expect(withMission.copyWith(name: 'renamed').mission, mission);
    expect(withMission.copyWith(clearMission: true).mission, isNull);
  });

  test('the mission takes part in equality', () {
    const mission = DpvMission(batteryReserveFraction: 0.5);
    expect(_plan().copyWith(mission: mission), isNot(_plan()));
    expect(
      _plan().copyWith(mission: mission),
      _plan().copyWith(mission: mission),
    );
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/planner/mission/dive_plan_mission_field_test.dart`
Expected: FAIL, "The getter 'mission' isn't defined" and "No named parameter with the name 'mission'".

- [ ] **Step 3: Add the field**

In `lib/features/planner/domain/entities/dive_plan.dart`:

Add the import after the `gear_provenance.dart` import:

```dart
import 'package:submersion/features/planner/domain/entities/mission/dpv_mission.dart';
```

After the `plannedWeightPlacement` field declaration (the last field before the constructor), add:

```dart
  /// The DPV mission layered on this plan, or null for a plan without one.
  /// When present, [segments] are generated from the mission's route and
  /// must be treated as a cache of it, never edited by hand.
  final DpvMission? mission;
```

In the constructor, after `this.plannedWeightPlacement,` add:

```dart
    this.mission,
```

In `copyWith`'s parameter list, after `Map<String, double>? plannedWeightPlacement,` add:

```dart
    DpvMission? mission,
    bool clearMission = false,
```

In the `DivePlan(` body of `copyWith`, after the `plannedWeightPlacement:` line add:

```dart
      mission: clearMission ? null : (mission ?? this.mission),
```

In `props`, after `plannedWeightPlacement,` add:

```dart
    mission,
```

- [ ] **Step 4: Run the test and the plan entity tests to verify they pass**

Run: `flutter test test/features/planner/mission/dive_plan_mission_field_test.dart test/features/planner/dive_plan_entity_test.dart`
Expected: PASS.

- [ ] **Step 5: Format and commit**

```bash
dart format lib/features/planner/domain/entities/dive_plan.dart test/features/planner/mission
git add lib/features/planner/domain/entities/dive_plan.dart test/features/planner/mission/dive_plan_mission_field_test.dart
git commit -m "feat(planner): give DivePlan a nullable mission

Refs #2086"
```

---

### Task 3: DPV attribute keys, tow-factor catalog entries, typed getters, labels

**Files:**
- Modify: `lib/features/equipment/domain/constants/equipment_attribute_catalog.dart` (`EquipmentAttrKeys` near line 57, DPV block near line 522)
- Modify: `lib/features/equipment/domain/entities/equipment_item.dart` (typed getters near line 144)
- Modify: `lib/features/equipment/presentation/utils/equipment_attribute_l10n.dart` (the `attributeLabel` switch)
- Modify: `lib/l10n/arb/app_en.arb`, `app_ar.arb`, `app_de.arb`, `app_es.arb`, `app_fr.arb`, `app_he.arb`, `app_hu.arb`, `app_it.arb`, `app_nl.arb`, `app_pt.arb`, `app_zh.arb`
- Test: `test/features/equipment/domain/constants/equipment_attribute_catalog_dpv_test.dart`

**Interfaces:**
- Produces: `EquipmentAttrKeys.dpvSpeedMps = 'speed_mps'`, `EquipmentAttrKeys.dpvBurnTimeH = 'burn_time_h'`, `EquipmentAttrKeys.dpvBatteryCapacityWh = 'battery_capacity_wh'`, `EquipmentAttrKeys.towSpeedFactor = 'tow_speed_factor'`, `EquipmentAttrKeys.towBurnFactor = 'tow_burn_factor'`; `EquipmentItem.dpvSpeedMps`, `dpvBurnTimeHours`, `dpvBatteryCapacityWh`, `dpvTowSpeedFactor`, `dpvTowBurnFactor` (all `double?`).

- [ ] **Step 1: Write the failing test**

```dart
// test/features/equipment/domain/constants/equipment_attribute_catalog_dpv_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_attribute.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';

void main() {
  test('DPV carries the two tow factors as plain numbers', () {
    final keys = EquipmentAttributeCatalog.attributesFor(
      EquipmentType.dpv,
    ).map((d) => d.key).toList();
    expect(keys, containsAll(['tow_speed_factor', 'tow_burn_factor']));
    for (final key in ['tow_speed_factor', 'tow_burn_factor']) {
      final def = EquipmentAttributeCatalog.defFor(key)!;
      expect(def.kind, AttributeKind.number, reason: key);
      expect(def.dimension, AttributeDimension.none, reason: key);
    }
  });

  test('the stable keys name the stored attribute keys', () {
    expect(EquipmentAttrKeys.dpvSpeedMps, 'speed_mps');
    expect(EquipmentAttrKeys.dpvBurnTimeH, 'burn_time_h');
    expect(EquipmentAttrKeys.dpvBatteryCapacityWh, 'battery_capacity_wh');
    expect(EquipmentAttrKeys.towSpeedFactor, 'tow_speed_factor');
    expect(EquipmentAttrKeys.towBurnFactor, 'tow_burn_factor');
  });

  test('typed getters read the curated rows and are null when absent', () {
    final item = EquipmentItem(
      id: 'dpv-1',
      name: 'Blacktip',
      type: EquipmentType.dpv,
      attributes: [
        EquipmentAttribute.curated(
          equipmentId: 'dpv-1',
          key: 'speed_mps',
          valueNum: 0.9,
        ),
        EquipmentAttribute.curated(
          equipmentId: 'dpv-1',
          key: 'burn_time_h',
          valueNum: 1.5,
        ),
        EquipmentAttribute.curated(
          equipmentId: 'dpv-1',
          key: 'tow_burn_factor',
          valueNum: 1.8,
        ),
      ],
    );
    expect(item.dpvSpeedMps, 0.9);
    expect(item.dpvBurnTimeHours, 1.5);
    expect(item.dpvTowBurnFactor, 1.8);
    expect(item.dpvBatteryCapacityWh, isNull);
    expect(item.dpvTowSpeedFactor, isNull);
  });
}
```

Before running, open `lib/features/equipment/domain/entities/equipment_attribute.dart` and confirm the curated constructor's name and required parameters (it is documented near line 40 as minting ids `attr_<equipmentId>_<key>`). If the factory is named differently, use that name in the test; the test's intent is a curated (non-custom) numeric row. Likewise confirm the required parameters of `EquipmentItem` (open `equipment_item.dart` near line 30) and add any other required ones with placeholder values.

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/equipment/domain/constants/equipment_attribute_catalog_dpv_test.dart`
Expected: FAIL, "The getter 'dpvSpeedMps' isn't defined" and the tow keys missing from the DPV list.

- [ ] **Step 3: Add keys, defs and getters**

In `equipment_attribute_catalog.dart`, inside `EquipmentAttrKeys` after the `rechargeable` constant, add:

```dart
  // DPV mission planning (issue #2086). The three existing keys are named
  // here so the planner never spells a raw string; the two tow factors are
  // new and default when absent (see ScooterSpec).
  static const dpvSpeedMps = 'speed_mps';
  static const dpvBurnTimeH = 'burn_time_h';
  static const dpvBatteryCapacityWh = 'battery_capacity_wh';
  static const towSpeedFactor = 'tow_speed_factor';
  static const towBurnFactor = 'tow_burn_factor';
```

In the `EquipmentType.dpv` list, after the `speed_mps` def and before the `depth_rating_m` def, add:

```dart
      // Towing a dead scooter's diver: the tower's speed as a fraction of
      // rated, and the burn-rate multiplier. Absent means the planner's
      // defaults (0.6 and 1.5), so a diver only fills these in to correct
      // them for a ride-on or an unusually strong scooter.
      EquipmentAttributeDef(
        key: EquipmentAttrKeys.towSpeedFactor,
        kind: AttributeKind.number,
      ),
      EquipmentAttributeDef(
        key: EquipmentAttrKeys.towBurnFactor,
        kind: AttributeKind.number,
      ),
```

In `equipment_item.dart`, after the `workingPressureBar` getter, add:

```dart
  /// DPV specs (curated attributes; see the DPV entry in
  /// [EquipmentAttributeCatalog]). Null when unspecified. Burn time is stored
  /// in hours and the tow factors are dimensionless (issue #2086).
  double? get dpvSpeedMps => attrNum(EquipmentAttrKeys.dpvSpeedMps);
  double? get dpvBurnTimeHours => attrNum(EquipmentAttrKeys.dpvBurnTimeH);
  double? get dpvBatteryCapacityWh =>
      attrNum(EquipmentAttrKeys.dpvBatteryCapacityWh);
  double? get dpvTowSpeedFactor => attrNum(EquipmentAttrKeys.towSpeedFactor);
  double? get dpvTowBurnFactor => attrNum(EquipmentAttrKeys.towBurnFactor);
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/features/equipment/domain/constants/equipment_attribute_catalog_dpv_test.dart`
Expected: PASS, 3 tests.

- [ ] **Step 5: Add the labels to all eleven ARB files**

The English file is alphabetical; the other ten are grouped by feature. Anchor on `"attrLabel_speed_mps"`, which exists in all eleven files. Confirm first:

```bash
grep -c '"attrLabel_speed_mps"' lib/l10n/arb/app_*.arb
```

Expected: eleven lines, each `:1`.

In `app_en.arb`, insert directly after the `"attrLabel_speed_mps": "Top speed",` line (English stays alphabetical: `tow_` sorts after `speed_`; if a key between them exists, insert in sorted position):

```json
  "attrLabel_tow_burn_factor": "Tow burn factor",
  "attrLabel_tow_speed_factor": "Tow speed factor",
```

In each of the ten translated files, insert directly after the `"attrLabel_speed_mps"` line:

| File | tow_burn_factor | tow_speed_factor |
| --- | --- | --- |
| app_ar.arb | "معامل استهلاك البطارية أثناء السحب" | "معامل السرعة أثناء السحب" |
| app_de.arb | "Verbrauchsfaktor beim Schleppen" | "Geschwindigkeitsfaktor beim Schleppen" |
| app_es.arb | "Factor de consumo al remolcar" | "Factor de velocidad al remolcar" |
| app_fr.arb | "Facteur de consommation en remorquage" | "Facteur de vitesse en remorquage" |
| app_he.arb | "מקדם צריכת סוללה בגרירה" | "מקדם מהירות בגרירה" |
| app_hu.arb | "Fogyasztási tényező vontatáskor" | "Sebességtényező vontatáskor" |
| app_it.arb | "Fattore di consumo in traino" | "Fattore di velocità in traino" |
| app_nl.arb | "Verbruiksfactor bij slepen" | "Snelheidsfactor bij slepen" |
| app_pt.arb | "Fator de consumo ao rebocar" | "Fator de velocidade ao rebocar" |
| app_zh.arb | "拖带耗电系数" | "拖带速度系数" |

Watch the trailing comma on the line you insert after; every inserted line ends with a comma because a later key always follows.

Then in `equipment_attribute_l10n.dart`, add two cases to the `attributeLabel` switch next to the `'speed_mps'` case:

```dart
  'tow_speed_factor' => l10n.attrLabel_tow_speed_factor,
  'tow_burn_factor' => l10n.attrLabel_tow_burn_factor,
```

Regenerate and verify:

```bash
flutter gen-l10n
git diff --numstat -- lib/l10n/arb/app_*.arb
```

Expected: eleven `.arb` rows each showing `2` added and `0` removed, plus the generated `app_localizations*.dart` files changed. Then confirm every file still parses:

```bash
for f in lib/l10n/arb/app_*.arb; do python3 -c "import json,sys; json.load(open(sys.argv[1]))" "$f" || echo "BROKEN $f"; done
```

Expected: no `BROKEN` line.

- [ ] **Step 6: Run the catalog and label tests**

Run: `flutter test test/features/equipment/domain/constants/ test/features/equipment/presentation/utils/`
Expected: PASS.

- [ ] **Step 7: Format and commit**

```bash
dart format lib/features/equipment lib/l10n/arb test/features/equipment
git add lib/features/equipment/domain/constants/equipment_attribute_catalog.dart lib/features/equipment/domain/entities/equipment_item.dart lib/features/equipment/presentation/utils/equipment_attribute_l10n.dart lib/l10n/arb test/features/equipment/domain/constants/equipment_attribute_catalog_dpv_test.dart
git commit -m "feat(equipment): add DPV tow factors and typed scooter getters

Refs #2086"
```

---

### Task 4: `ScooterSpecResolver`

**Files:**
- Create: `lib/features/planner/domain/services/mission/scooter_spec_resolver.dart`
- Test: `test/features/planner/mission/scooter_spec_resolver_test.dart`

**Interfaces:**
- Consumes: `ScooterSpec` (Task 1), `EquipmentItem` typed getters (Task 3).
- Produces: `class ScooterSpecResolver { const ScooterSpecResolver(); ScooterSpec? fromEquipment(EquipmentItem item); ScooterSpec overlay(ScooterSpec stored, EquipmentItem? live); }`.

- [ ] **Step 1: Write the failing tests**

```dart
// test/features/planner/mission/scooter_spec_resolver_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_attribute.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/planner/domain/entities/mission/scooter_spec.dart';
import 'package:submersion/features/planner/domain/services/mission/scooter_spec_resolver.dart';

EquipmentItem _dpv({
  double? speedMps = 0.9,
  double? burnHours = 1.5,
  double? towSpeed,
  double? towBurn,
}) {
  EquipmentAttribute num(String key, double value) =>
      EquipmentAttribute.curated(equipmentId: 'dpv-1', key: key, valueNum: value);
  return EquipmentItem(
    id: 'dpv-1',
    name: 'Blacktip',
    type: EquipmentType.dpv,
    attributes: [
      if (speedMps != null) num('speed_mps', speedMps),
      if (burnHours != null) num('burn_time_h', burnHours),
      if (towSpeed != null) num('tow_speed_factor', towSpeed),
      if (towBurn != null) num('tow_burn_factor', towBurn),
    ],
  );
}

void main() {
  const resolver = ScooterSpecResolver();

  group('fromEquipment', () {
    test('copies speed, burn time in seconds and the item id and name', () {
      final spec = resolver.fromEquipment(_dpv())!;
      expect(spec.equipmentId, 'dpv-1');
      expect(spec.name, 'Blacktip');
      expect(spec.ratedSpeedMps, 0.9);
      expect(spec.burnTimeSeconds, 5400);
      expect(spec.towSpeedFactor, kDefaultTowSpeedFactor);
      expect(spec.towBurnFactor, kDefaultTowBurnFactor);
    });

    test('uses the item tow factors when present', () {
      final spec = resolver.fromEquipment(_dpv(towSpeed: 0.5, towBurn: 2.0))!;
      expect(spec.towSpeedFactor, 0.5);
      expect(spec.towBurnFactor, 2.0);
    });

    test('is null without a speed or without a burn time', () {
      expect(resolver.fromEquipment(_dpv(speedMps: null)), isNull);
      expect(resolver.fromEquipment(_dpv(burnHours: null)), isNull);
    });
  });

  group('overlay', () {
    const stored = ScooterSpec(
      equipmentId: 'dpv-1',
      name: 'Old name',
      ratedSpeedMps: 0.7,
      burnTimeSeconds: 3600,
      towSpeedFactor: 0.55,
      towBurnFactor: 1.4,
    );

    test('live attributes win over the snapshot, absent ones keep it', () {
      final spec = resolver.overlay(stored, _dpv(towBurn: 2.0));
      expect(spec.name, 'Blacktip');
      expect(spec.ratedSpeedMps, 0.9);
      expect(spec.burnTimeSeconds, 5400);
      expect(spec.towBurnFactor, 2.0);
      expect(spec.towSpeedFactor, 0.55, reason: 'not on the item');
    });

    test('a deleted item leaves the snapshot untouched', () {
      expect(resolver.overlay(stored, null), stored);
    });

    test('a manual scooter is never overlaid', () {
      const manual = ScooterSpec(
        name: 'Manual',
        ratedSpeedMps: 0.6,
        burnTimeSeconds: 1800,
      );
      expect(resolver.overlay(manual, _dpv()), manual);
    });
  });
}
```

Use the same `EquipmentAttribute` and `EquipmentItem` constructor names verified in Task 3.

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/features/planner/mission/scooter_spec_resolver_test.dart`
Expected: FAIL, the resolver import does not resolve.

- [ ] **Step 3: Write the resolver**

```dart
// lib/features/planner/domain/services/mission/scooter_spec_resolver.dart
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/planner/domain/entities/mission/scooter_spec.dart';

/// Builds and refreshes a [ScooterSpec] from a DPV equipment item.
///
/// The spec is a snapshot so a plan stays computable after the item is
/// deleted; [overlay] refreshes the snapshot from the live item so a corrected
/// burn time on the equipment page reaches every plan that uses the scooter.
class ScooterSpecResolver {
  const ScooterSpecResolver();

  /// A spec from [item], or null when the item lacks a speed or a burn time.
  ScooterSpec? fromEquipment(EquipmentItem item) {
    final speed = item.dpvSpeedMps;
    final burnHours = item.dpvBurnTimeHours;
    if (speed == null || burnHours == null) return null;
    return ScooterSpec(
      equipmentId: item.id,
      name: item.name,
      ratedSpeedMps: speed,
      burnTimeSeconds: (burnHours * 3600).round(),
      towSpeedFactor: item.dpvTowSpeedFactor ?? kDefaultTowSpeedFactor,
      towBurnFactor: item.dpvTowBurnFactor ?? kDefaultTowBurnFactor,
    );
  }

  /// [stored] refreshed from [live]. Attributes the item carries win; ones it
  /// lacks keep the snapshot. A null item (deleted) or a manual scooter (no
  /// equipment id) returns [stored] unchanged.
  ScooterSpec overlay(ScooterSpec stored, EquipmentItem? live) {
    if (live == null || stored.equipmentId == null) return stored;
    if (live.id != stored.equipmentId) return stored;
    final burnHours = live.dpvBurnTimeHours;
    return stored.copyWith(
      name: live.name,
      ratedSpeedMps: live.dpvSpeedMps,
      burnTimeSeconds: burnHours == null ? null : (burnHours * 3600).round(),
      towSpeedFactor: live.dpvTowSpeedFactor,
      towBurnFactor: live.dpvTowBurnFactor,
    );
  }
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/features/planner/mission/scooter_spec_resolver_test.dart`
Expected: PASS, 6 tests.

- [ ] **Step 5: Format and commit**

```bash
dart format lib/features/planner/domain/services/mission test/features/planner/mission
git add lib/features/planner/domain/services/mission/scooter_spec_resolver.dart test/features/planner/mission/scooter_spec_resolver_test.dart
git commit -m "feat(planner): resolve scooter specs from DPV equipment

Refs #2086"
```

---

### Task 5: Mission outcome types

**Files:**
- Create: `lib/features/planner/domain/entities/mission/mission_outcome.dart`
- Test: `test/features/planner/mission/mission_outcome_test.dart`

**Interfaces:**
- Produces (all `Equatable`, `const` constructors): the enums `MissionIssueType { emptyTeam, emptyRoute, scooterUnspecified, memberSacUnset, untraversableLeg, scenarioFailed }`, `MissionIssueSeverity { info, warning, blocking }`, `MissionExitMode { swim, tow }`, `MissionBindingFactor { battery, ownGas, noFeasibleTow, swimGas }`; the classes `MissionIssue`, `LegOutcome`, `ExitOutcome`, `MemberWaypointOutcome`, `WaypointOutcome`, `MemberOutcome`, `MissionConstraint`, `MissionOutcome` with the exact fields below.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/planner/mission/mission_outcome_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/planner/domain/entities/mission/mission_outcome.dart';

void main() {
  test('MissionOutcome.empty carries only the issues it was given', () {
    const issue = MissionIssue(
      type: MissionIssueType.emptyTeam,
      severity: MissionIssueSeverity.blocking,
    );
    final outcome = MissionOutcome.empty(issues: const [issue]);
    expect(outcome.issues, [issue]);
    expect(outcome.segments, isEmpty);
    expect(outcome.legs, isEmpty);
    expect(outcome.waypoints, isEmpty);
    expect(outcome.members, isEmpty);
    expect(outcome.abandonmentIndex, isNull);
    expect(outcome.constraint, isNull);
    expect(outcome.cruiseSpeedMps, 0);
    expect(outcome.isBlocked, isTrue);
  });

  test('isBlocked is false when no issue is blocking', () {
    final outcome = MissionOutcome.empty(
      issues: const [
        MissionIssue(
          type: MissionIssueType.memberSacUnset,
          severity: MissionIssueSeverity.warning,
          memberId: 'm1',
        ),
      ],
    );
    expect(outcome.isBlocked, isFalse);
  });

  test('ExitOutcome exposes the exit runtime as bottom plus tts', () {
    const exit = ExitOutcome(
      mode: MissionExitMode.tow,
      towerId: 'm2',
      feasible: true,
      exitBottomSeconds: 1200,
      ttsSeconds: 300,
      exitLitersByMember: {'m1': 900.0, 'm2': 600.0},
    );
    expect(exit.exitSeconds, 1500);
    expect(exit.gasShortfallMemberIds, isEmpty);
    expect(exit.batteryShortfallMemberIds, isEmpty);
    expect(exit.blockedByCurrent, isFalse);
  });

  test('value equality holds for nested outcomes', () {
    const a = MemberWaypointOutcome(
      memberId: 'm1',
      gasRemainingBar: 120,
      swim: ExitOutcome(
        mode: MissionExitMode.swim,
        feasible: false,
        exitBottomSeconds: 3000,
        ttsSeconds: 200,
        exitLitersByMember: {'m1': 2000.0},
        gasShortfallMemberIds: {'m1'},
      ),
      survivable: false,
    );
    const b = MemberWaypointOutcome(
      memberId: 'm1',
      gasRemainingBar: 120,
      swim: ExitOutcome(
        mode: MissionExitMode.swim,
        feasible: false,
        exitBottomSeconds: 3000,
        ttsSeconds: 200,
        exitLitersByMember: {'m1': 2000.0},
        gasShortfallMemberIds: {'m1'},
      ),
      survivable: false,
    );
    expect(a, b);
    expect(a.tow, isNull);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/planner/mission/mission_outcome_test.dart`
Expected: FAIL, the import does not resolve.

- [ ] **Step 3: Write the outcome types**

```dart
// lib/features/planner/domain/entities/mission/mission_outcome.dart
import 'package:equatable/equatable.dart';

import 'package:submersion/features/dive_planner/domain/entities/plan_segment.dart';

/// What went wrong, or what the diver should know, while computing a mission.
enum MissionIssueType {
  emptyTeam,
  emptyRoute,
  scooterUnspecified,
  memberSacUnset,
  untraversableLeg,
  scenarioFailed,
}

enum MissionIssueSeverity { info, warning, blocking }

/// How a team gets a diver with a dead scooter back to the start.
enum MissionExitMode { swim, tow }

/// The first thing that stops a member going further.
enum MissionBindingFactor { battery, ownGas, noFeasibleTow, swimGas }

/// One issue found while computing a mission. Carries ids, not prose; the
/// UI localises the message.
class MissionIssue extends Equatable {
  final MissionIssueType type;
  final MissionIssueSeverity severity;
  final String? legId;
  final String? memberId;

  /// For [MissionIssueType.untraversableLeg]: true when the outbound
  /// direction is blocked, false for the return, null when not applicable.
  final bool? outbound;

  const MissionIssue({
    required this.type,
    required this.severity,
    this.legId,
    this.memberId,
    this.outbound,
  });

  @override
  List<Object?> get props => [type, severity, legId, memberId, outbound];
}

/// Effective speeds and durations of one leg at the team cruise speed.
class LegOutcome extends Equatable {
  final String legId;
  final double outboundSpeedMps;
  final double returnSpeedMps;
  final int outboundSeconds;
  final int returnSeconds;

  const LegOutcome({
    required this.legId,
    required this.outboundSpeedMps,
    required this.returnSpeedMps,
    required this.outboundSeconds,
    required this.returnSeconds,
  });

  @override
  List<Object?> get props => [
    legId,
    outboundSpeedMps,
    returnSpeedMps,
    outboundSeconds,
    returnSeconds,
  ];
}

/// One way out after a scooter failure, evaluated through the plan engine.
class ExitOutcome extends Equatable {
  final MissionExitMode mode;

  /// The teammate towing, for [MissionExitMode.tow]; null for a swim.
  final String? towerId;
  final bool feasible;

  /// Seconds from the failure point back to the start of the route.
  final int exitBottomSeconds;

  /// Time to surface from the end of the exit, from the plan engine.
  final int ttsSeconds;

  /// Surface litres each member breathes from the failure point to the
  /// surface, by member id.
  final Map<String, double> exitLitersByMember;
  final Set<String> gasShortfallMemberIds;
  final Set<String> batteryShortfallMemberIds;

  /// True when a current on some exit leg is at least as fast as the exit
  /// speed, so the team cannot make headway at all. A current the scooters
  /// beat at cruise can still stop a swim or a slow tow.
  final bool blockedByCurrent;

  const ExitOutcome({
    required this.mode,
    this.towerId,
    required this.feasible,
    required this.exitBottomSeconds,
    required this.ttsSeconds,
    required this.exitLitersByMember,
    this.gasShortfallMemberIds = const {},
    this.batteryShortfallMemberIds = const {},
    this.blockedByCurrent = false,
  });

  int get exitSeconds => exitBottomSeconds + ttsSeconds;

  @override
  List<Object?> get props => [
    mode,
    towerId,
    feasible,
    exitBottomSeconds,
    ttsSeconds,
    exitLitersByMember,
    gasShortfallMemberIds,
    batteryShortfallMemberIds,
    blockedByCurrent,
  ];
}

/// One member's situation at one waypoint if their scooter dies there.
class MemberWaypointOutcome extends Equatable {
  final String memberId;

  /// Pressure left on the bottom tank on arrival; null when the tank has no
  /// start pressure.
  final double? gasRemainingBar;
  final ExitOutcome swim;

  /// The best tow exit (feasible if any is), or null with no teammate.
  final ExitOutcome? tow;
  final bool survivable;

  const MemberWaypointOutcome({
    required this.memberId,
    required this.gasRemainingBar,
    required this.swim,
    this.tow,
    required this.survivable,
  });

  @override
  List<Object?> get props => [memberId, gasRemainingBar, swim, tow, survivable];
}

/// One waypoint of the route with every member's failure evaluated there.
class WaypointOutcome extends Equatable {
  final int index;
  final String legId;
  final double cumulativeDistanceM;
  final int arrivalRuntimeSeconds;
  final List<MemberWaypointOutcome> members;

  /// True when every member's failure here has a feasible exit.
  final bool survivable;

  const WaypointOutcome({
    required this.index,
    required this.legId,
    required this.cumulativeDistanceM,
    required this.arrivalRuntimeSeconds,
    required this.members,
    required this.survivable,
  });

  @override
  List<Object?> get props => [
    index,
    legId,
    cumulativeDistanceM,
    arrivalRuntimeSeconds,
    members,
    survivable,
  ];
}

/// One member across the whole mission.
class MemberOutcome extends Equatable {
  final String memberId;

  /// Fraction of burn time used on the no-failure round trip.
  final double batteryRoundTripFraction;
  final bool setsCruiseSpeed;
  final MissionBindingFactor? bindingFactor;
  final int? bindingWaypointIndex;

  /// Bottom-tank pressure that must remain at the abandonment point to cover
  /// this member's worst feasible exit plus the plan reserve; null when no
  /// waypoint is survivable.
  final double? turnPressureBar;

  const MemberOutcome({
    required this.memberId,
    required this.batteryRoundTripFraction,
    required this.setsCruiseSpeed,
    this.bindingFactor,
    this.bindingWaypointIndex,
    this.turnPressureBar,
  });

  @override
  List<Object?> get props => [
    memberId,
    batteryRoundTripFraction,
    setsCruiseSpeed,
    bindingFactor,
    bindingWaypointIndex,
    turnPressureBar,
  ];
}

/// The member and factor that bind earliest along the route.
class MissionConstraint extends Equatable {
  final String memberId;
  final MissionBindingFactor factor;
  final int waypointIndex;

  const MissionConstraint({
    required this.memberId,
    required this.factor,
    required this.waypointIndex,
  });

  @override
  List<Object?> get props => [memberId, factor, waypointIndex];
}

/// Everything the mission engine computes.
class MissionOutcome extends Equatable {
  /// The generated round-trip segments the plan should carry.
  final List<PlanSegment> segments;
  final double cruiseSpeedMps;
  final List<LegOutcome> legs;
  final List<WaypointOutcome> waypoints;
  final List<MemberOutcome> members;

  /// Last waypoint index at which every member's failure is survivable and
  /// every earlier waypoint is too; null when even the first is not.
  final int? abandonmentIndex;
  final MissionConstraint? constraint;
  final List<MissionIssue> issues;

  const MissionOutcome({
    required this.segments,
    required this.cruiseSpeedMps,
    required this.legs,
    required this.waypoints,
    required this.members,
    required this.abandonmentIndex,
    required this.constraint,
    required this.issues,
  });

  /// An outcome with nothing computed, for a mission that cannot run.
  const MissionOutcome.empty({required this.issues})
    : segments = const [],
      cruiseSpeedMps = 0,
      legs = const [],
      waypoints = const [],
      members = const [],
      abandonmentIndex = null,
      constraint = null;

  bool get isBlocked =>
      issues.any((i) => i.severity == MissionIssueSeverity.blocking);

  @override
  List<Object?> get props => [
    segments,
    cruiseSpeedMps,
    legs,
    waypoints,
    members,
    abandonmentIndex,
    constraint,
    issues,
  ];
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/features/planner/mission/mission_outcome_test.dart`
Expected: PASS, 4 tests.

- [ ] **Step 5: Format and commit**

```bash
dart format lib/features/planner/domain/entities/mission test/features/planner/mission
git add lib/features/planner/domain/entities/mission/mission_outcome.dart test/features/planner/mission/mission_outcome_test.dart
git commit -m "feat(planner): add mission outcome types

Refs #2086"
```

---

### Task 6: Team helpers and `LegSpeedResolver`

**Files:**
- Create: `lib/features/planner/domain/services/mission/mission_team.dart`
- Create: `lib/features/planner/domain/services/mission/leg_speed_resolver.dart`
- Test: `test/features/planner/mission/mission_team_test.dart`
- Test: `test/features/planner/mission/leg_speed_resolver_test.dart`

**Interfaces:**
- Consumes: entities from Task 1.
- Produces: in `mission_team.dart`, top-level functions `double cruiseSpeedMps(List<MissionMember> team)` (0 for an empty team), `String? cruiseLimitingMemberId(List<MissionMember> team)` (first member in order with the slowest rated speed), `double slowestSwimSpeedMps(List<MissionMember> team)`; in `leg_speed_resolver.dart`, `class LegSpeeds extends Equatable { final double outboundMps; final double returnMps; bool get outboundTraversable; bool get returnTraversable; bool get traversable; }` and `class LegSpeedResolver { const LegSpeedResolver(); LegSpeeds resolve({required MissionLeg leg, required CurrentVector? current, required double baseSpeedMps}); }`.

- [ ] **Step 1: Write the failing tests**

```dart
// test/features/planner/mission/mission_team_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/planner/domain/entities/mission/mission_member.dart';
import 'package:submersion/features/planner/domain/entities/mission/scooter_spec.dart';
import 'package:submersion/features/planner/domain/services/mission/mission_team.dart';

MissionMember _member(String id, int order, double speed, {double swim = 0.2}) =>
    MissionMember(
      id: id,
      order: order,
      displayName: id,
      sacBottom: 15,
      swimSpeedMps: swim,
      scooter: ScooterSpec(
        name: 'S-$id',
        ratedSpeedMps: speed,
        burnTimeSeconds: 3600,
      ),
    );

void main() {
  test('the team cruises at the slowest rated speed', () {
    final team = [_member('a', 0, 0.9), _member('b', 1, 0.7), _member('c', 2, 0.8)];
    expect(cruiseSpeedMps(team), 0.7);
    expect(cruiseLimitingMemberId(team), 'b');
  });

  test('a tie goes to the earlier member', () {
    final team = [_member('a', 0, 0.7), _member('b', 1, 0.7)];
    expect(cruiseLimitingMemberId(team), 'a');
  });

  test('an empty team has no cruise speed and no limiting member', () {
    expect(cruiseSpeedMps(const []), 0);
    expect(cruiseLimitingMemberId(const []), isNull);
    expect(slowestSwimSpeedMps(const []), 0);
  });

  test('the slowest swimmer sets the swim exit speed', () {
    final team = [_member('a', 0, 0.9, swim: 0.25), _member('b', 1, 0.9, swim: 0.15)];
    expect(slowestSwimSpeedMps(team), 0.15);
  });
}
```

```dart
// test/features/planner/mission/leg_speed_resolver_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/planner/domain/entities/mission/current_vector.dart';
import 'package:submersion/features/planner/domain/entities/mission/mission_leg.dart';
import 'package:submersion/features/planner/domain/services/mission/leg_speed_resolver.dart';

const _leg = MissionLeg(
  id: 'l1',
  order: 0,
  label: 'T',
  distanceM: 300,
  depthM: 20,
  headingDeg: 90,
);

void main() {
  const resolver = LegSpeedResolver();

  test('no current: both directions run at the base speed', () {
    final speeds = resolver.resolve(leg: _leg, current: null, baseSpeedMps: 0.5);
    expect(speeds, const LegSpeeds(outboundMps: 0.5, returnMps: 0.5));
    expect(speeds.traversable, isTrue);
  });

  test('a following current helps outbound and hurts the return', () {
    const current = CurrentVector(speedMps: 0.2, setsTowardDeg: 90);
    final speeds = resolver.resolve(leg: _leg, current: current, baseSpeedMps: 0.5);
    expect(speeds.outboundMps, closeTo(0.7, 1e-9));
    expect(speeds.returnMps, closeTo(0.3, 1e-9));
  });

  test('a current as strong as the base speed blocks the return only', () {
    const current = CurrentVector(speedMps: 0.5, setsTowardDeg: 90);
    final speeds = resolver.resolve(leg: _leg, current: current, baseSpeedMps: 0.5);
    expect(speeds.outboundTraversable, isTrue);
    expect(speeds.returnTraversable, isFalse);
    expect(speeds.traversable, isFalse);
  });

  test('a head current stronger than the base speed blocks the outbound', () {
    const current = CurrentVector(speedMps: 0.6, setsTowardDeg: 270);
    final speeds = resolver.resolve(leg: _leg, current: current, baseSpeedMps: 0.5);
    expect(speeds.outboundTraversable, isFalse);
    expect(speeds.returnTraversable, isTrue);
  });

  test('a zero base speed is never traversable', () {
    final speeds = resolver.resolve(leg: _leg, current: null, baseSpeedMps: 0);
    expect(speeds.traversable, isFalse);
  });
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/features/planner/mission/mission_team_test.dart test/features/planner/mission/leg_speed_resolver_test.dart`
Expected: FAIL, imports do not resolve.

- [ ] **Step 3: Write the helpers and the resolver**

```dart
// lib/features/planner/domain/services/mission/mission_team.dart
import 'package:submersion/features/planner/domain/entities/mission/mission_member.dart';

/// Speed the team travels at: the slowest scooter. Zero for an empty team.
double cruiseSpeedMps(List<MissionMember> team) {
  if (team.isEmpty) return 0;
  var slowest = double.infinity;
  for (final member in team) {
    if (member.scooter.ratedSpeedMps < slowest) {
      slowest = member.scooter.ratedSpeedMps;
    }
  }
  return slowest;
}

/// The member whose scooter sets the cruise speed; the earlier member on a
/// tie. Null for an empty team.
String? cruiseLimitingMemberId(List<MissionMember> team) {
  if (team.isEmpty) return null;
  final cruise = cruiseSpeedMps(team);
  for (final member in team) {
    if (member.scooter.ratedSpeedMps == cruise) return member.id;
  }
  return null;
}

/// Speed the team swims at with a scooter dead: the slowest swimmer. Zero
/// for an empty team.
double slowestSwimSpeedMps(List<MissionMember> team) {
  if (team.isEmpty) return 0;
  var slowest = double.infinity;
  for (final member in team) {
    if (member.swimSpeedMps < slowest) slowest = member.swimSpeedMps;
  }
  return slowest;
}
```

```dart
// lib/features/planner/domain/services/mission/leg_speed_resolver.dart
import 'package:equatable/equatable.dart';

import 'package:submersion/features/planner/domain/entities/mission/current_vector.dart';
import 'package:submersion/features/planner/domain/entities/mission/mission_leg.dart';

/// Effective ground speed along a leg in each direction, in m/s.
class LegSpeeds extends Equatable {
  final double outboundMps;
  final double returnMps;

  const LegSpeeds({required this.outboundMps, required this.returnMps});

  bool get outboundTraversable => outboundMps > 0;
  bool get returnTraversable => returnMps > 0;
  bool get traversable => outboundTraversable && returnTraversable;

  @override
  List<Object?> get props => [outboundMps, returnMps];
}

/// Applies a leg's current to a base travel speed.
///
/// The along-route component of the current is added outbound and subtracted
/// on the return, which is the same formula evaluated on the reversed
/// heading. A direction whose effective speed is not positive cannot be
/// travelled at all.
class LegSpeedResolver {
  const LegSpeedResolver();

  LegSpeeds resolve({
    required MissionLeg leg,
    required CurrentVector? current,
    required double baseSpeedMps,
  }) {
    final component = current?.alongRouteComponent(leg.headingDeg) ?? 0.0;
    return LegSpeeds(
      outboundMps: baseSpeedMps + component,
      returnMps: baseSpeedMps - component,
    );
  }
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/features/planner/mission/mission_team_test.dart test/features/planner/mission/leg_speed_resolver_test.dart`
Expected: PASS, 9 tests.

- [ ] **Step 5: Format and commit**

```bash
dart format lib/features/planner/domain/services/mission test/features/planner/mission
git add lib/features/planner/domain/services/mission/mission_team.dart lib/features/planner/domain/services/mission/leg_speed_resolver.dart test/features/planner/mission/mission_team_test.dart test/features/planner/mission/leg_speed_resolver_test.dart
git commit -m "feat(planner): resolve team cruise speed and leg speeds under current

Refs #2086"
```

---

### Task 7: `MissionSegmentBuilder`

**Files:**
- Create: `lib/features/planner/domain/services/mission/mission_segment_builder.dart`
- Test: `test/features/planner/mission/mission_segment_builder_test.dart`

**Interfaces:**
- Consumes: `DpvMission`, `MissionLeg`, `LegSpeedResolver` (Task 6), `PlanSegment` (existing: `PlanSegment({required id, required targetDepth, required durationSeconds, required tankId, required gasMix, order})` and `PlanSegment.travel({required id, required fromDepth, required targetDepth, required tankId, required gasMix, required ratePerMinute, order})`), `TankRoleResolver.rolesFor(plan)` (existing, returns `Map<String, TankRole>`).
- Produces: `class MissionProfile extends Equatable { final List<PlanSegment> segments; final List<int> waypointArrivalSeconds; }` and `class MissionSegmentBuilder { const MissionSegmentBuilder(); MissionProfile build({required DivePlan plan, required DpvMission mission, required int throughLegIndex, required double outboundSpeedMps, required double exitSpeedMps}); }`.

Segment id convention (stable across regeneration, so equality and diffing work): `mission-out-travel-<legId>`, `mission-out-<legId>`, `mission-ret-<legId>`, `mission-ret-travel-<legId>`.

Hand-computed vector used by the tests. Plan: descent 18 m/min, ascent 9 m/min, one back-gas tank `back` (air). Legs: L1 300 m at 20 m heading 90; L2 200 m at 30 m heading 180. Speed 0.5 m/s both ways, no current.

| Segment | id | depth | seconds |
| --- | --- | --- | --- |
| travel 0 to 20 at 18 m/min | mission-out-travel-L1 | 20 | round(20/18*60) = 67 |
| hold L1 | mission-out-L1 | 20 | 300/0.5 = 600 |
| travel 20 to 30 at 18 m/min | mission-out-travel-L2 | 30 | round(10/18*60) = 33 |
| hold L2 | mission-out-L2 | 30 | 200/0.5 = 400 |
| hold L2 return | mission-ret-L2 | 30 | 400 |
| travel 30 to 20 at 9 m/min | mission-ret-travel-L1 | 20 | round(10/9*60) = 67 |
| hold L1 return | mission-ret-L1 | 20 | 600 |

Waypoint arrivals: [67 + 600, 667 + 33 + 400] = [667, 1100].

- [ ] **Step 1: Write the failing tests**

```dart
// test/features/planner/mission/mission_segment_builder_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    as domain;
import 'package:submersion/features/planner/domain/entities/mission/current_vector.dart';
import 'package:submersion/features/planner/domain/entities/mission/dpv_mission.dart';
import 'package:submersion/features/planner/domain/entities/mission/mission_leg.dart';
import 'package:submersion/features/planner/domain/services/mission/mission_segment_builder.dart';

const _air = GasMix(o2: 21);

domain.DivePlan _plan({List<DiveTank>? tanks}) => domain.DivePlan(
  id: 'plan-1',
  name: 'Builder',
  gfLow: 40,
  gfHigh: 80,
  descentRate: 18,
  ascentRate: 9,
  tanks:
      tanks ??
      const [
        DiveTank(
          id: 'back',
          volume: 24,
          startPressure: 200,
          gasMix: _air,
          role: TankRole.backGas,
        ),
      ],
  createdAt: DateTime(2026, 9, 18),
  updatedAt: DateTime(2026, 9, 18),
);

const _l1 = MissionLeg(
  id: 'L1',
  order: 0,
  label: 'A',
  distanceM: 300,
  depthM: 20,
  headingDeg: 90,
);
const _l2 = MissionLeg(
  id: 'L2',
  order: 1,
  label: 'B',
  distanceM: 200,
  depthM: 30,
  headingDeg: 180,
);

void main() {
  const builder = MissionSegmentBuilder();

  test('a two-leg route becomes travel and hold segments out and back', () {
    final profile = builder.build(
      plan: _plan(),
      mission: const DpvMission(legs: [_l1, _l2]),
      throughLegIndex: 1,
      outboundSpeedMps: 0.5,
      exitSpeedMps: 0.5,
    );
    final ids = profile.segments.map((s) => s.id).toList();
    expect(ids, [
      'mission-out-travel-L1',
      'mission-out-L1',
      'mission-out-travel-L2',
      'mission-out-L2',
      'mission-ret-L2',
      'mission-ret-travel-L1',
      'mission-ret-L1',
    ]);
    expect(profile.segments.map((s) => s.targetDepth).toList(), [
      20.0, 20.0, 30.0, 30.0, 30.0, 20.0, 20.0,
    ]);
    expect(profile.segments.map((s) => s.durationSeconds).toList(), [
      67, 600, 33, 400, 400, 67, 600,
    ]);
    expect(profile.segments.map((s) => s.order).toList(), [0, 1, 2, 3, 4, 5, 6]);
    expect(profile.waypointArrivalSeconds, [667, 1100]);
  });

  test('every segment breathes the back gas tank', () {
    final profile = builder.build(
      plan: _plan(
        tanks: const [
          DiveTank(id: 'deco', volume: 11, startPressure: 200, gasMix: GasMix(o2: 50), role: TankRole.deco),
          DiveTank(id: 'back', volume: 24, startPressure: 200, gasMix: _air, role: TankRole.backGas),
        ],
      ),
      mission: const DpvMission(legs: [_l1]),
      throughLegIndex: 0,
      outboundSpeedMps: 0.5,
      exitSpeedMps: 0.5,
    );
    expect(profile.segments.map((s) => s.tankId).toSet(), {'back'});
    expect(profile.segments.first.gasMix, _air);
  });

  test('a failure at the first waypoint exits only that leg, at exit speed', () {
    final profile = builder.build(
      plan: _plan(),
      mission: const DpvMission(legs: [_l1, _l2]),
      throughLegIndex: 0,
      outboundSpeedMps: 0.5,
      exitSpeedMps: 0.2,
    );
    expect(profile.segments.map((s) => s.id).toList(), [
      'mission-out-travel-L1',
      'mission-out-L1',
      'mission-ret-L1',
    ]);
    expect(profile.segments.last.durationSeconds, 1500);
    expect(profile.waypointArrivalSeconds, [667]);
  });

  test('a per-leg current changes the outbound and return holds', () {
    // 0.1 m/s setting toward 90 on a heading of 90: 0.6 out, 0.4 back.
    final leg = _l1.copyWith(
      current: const CurrentVector(speedMps: 0.1, setsTowardDeg: 90),
    );
    final profile = builder.build(
      plan: _plan(),
      mission: DpvMission(legs: [leg]),
      throughLegIndex: 0,
      outboundSpeedMps: 0.5,
      exitSpeedMps: 0.5,
    );
    expect(profile.segments[1].durationSeconds, 500);
    expect(profile.segments[2].durationSeconds, 750);
  });

  test('a leg at the same depth as the previous one needs no travel segment', () {
    final flat = _l2.copyWith(depthM: 20);
    final profile = builder.build(
      plan: _plan(),
      mission: DpvMission(legs: [_l1, flat]),
      throughLegIndex: 1,
      outboundSpeedMps: 0.5,
      exitSpeedMps: 0.5,
    );
    expect(profile.segments.map((s) => s.id).toList(), [
      'mission-out-travel-L1',
      'mission-out-L1',
      'mission-out-L2',
      'mission-ret-L2',
      'mission-ret-L1',
    ]);
  });

  test('a speed that makes no headway is refused rather than clamped', () {
    // A one-second hold against a current the diver cannot beat would report
    // an impossible exit as feasible, so the builder must refuse it.
    final leg = _l1.copyWith(
      current: const CurrentVector(speedMps: 0.3, setsTowardDeg: 90),
    );
    expect(
      () => builder.build(
        plan: _plan(),
        mission: DpvMission(legs: [leg]),
        throughLegIndex: 0,
        outboundSpeedMps: 0.5,
        exitSpeedMps: 0.2,
      ),
      throwsArgumentError,
    );
  });

  test('a plan without tanks yields no segments', () {
    final profile = builder.build(
      plan: _plan(tanks: const []),
      mission: const DpvMission(legs: [_l1]),
      throughLegIndex: 0,
      outboundSpeedMps: 0.5,
      exitSpeedMps: 0.5,
    );
    expect(profile.segments, isEmpty);
    expect(profile.waypointArrivalSeconds, isEmpty);
  });
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/features/planner/mission/mission_segment_builder_test.dart`
Expected: FAIL, the builder import does not resolve.

- [ ] **Step 3: Write the builder**

```dart
// lib/features/planner/domain/services/mission/mission_segment_builder.dart
import 'dart:math' as math;

import 'package:equatable/equatable.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_segment.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    as domain;
import 'package:submersion/features/planner/domain/entities/mission/dpv_mission.dart';
import 'package:submersion/features/planner/domain/services/mission/leg_speed_resolver.dart';
import 'package:submersion/features/planner/domain/services/tank_role_resolver.dart';

/// The segments a route produces, with the run time at which each outbound
/// waypoint is reached.
class MissionProfile extends Equatable {
  final List<PlanSegment> segments;

  /// Elapsed seconds on arrival at waypoint k (the end of outbound leg k).
  final List<int> waypointArrivalSeconds;

  const MissionProfile({
    required this.segments,
    required this.waypointArrivalSeconds,
  });

  @override
  List<Object?> get props => [segments, waypointArrivalSeconds];
}

/// Turns a mission route into the bottom segments of a plan.
///
/// Each outbound leg becomes a hold at its depth for `distance / speed`, and a
/// depth change between legs becomes an explicit travel segment first. The
/// segment chain resolves a hold whose depth differs from the previous one as
/// a travel leg spanning its WHOLE duration, so the travel must be authored
/// separately or the leg would be integrated as a slow descent. The return
/// legs are appended in reverse at [build]'s exit speed, and the engine's own
/// ascent takes over after the last one.
class MissionSegmentBuilder {
  final LegSpeedResolver speeds;
  final TankRoleResolver roles;

  const MissionSegmentBuilder({
    this.speeds = const LegSpeedResolver(),
    this.roles = const TankRoleResolver(),
  });

  /// Outbound legs 0 through [throughLegIndex] at [outboundSpeedMps], then
  /// the same legs back at [exitSpeedMps]. Currents apply per leg. An empty
  /// profile when the plan has no tank to breathe.
  MissionProfile build({
    required domain.DivePlan plan,
    required DpvMission mission,
    required int throughLegIndex,
    required double outboundSpeedMps,
    required double exitSpeedMps,
  }) {
    final tank = _bottomTank(plan);
    if (tank == null || mission.legs.isEmpty) {
      return const MissionProfile(segments: [], waypointArrivalSeconds: []);
    }
    final last = math.min(throughLegIndex, mission.legs.length - 1);
    final legs = mission.legs.sublist(0, last + 1);
    final segments = <PlanSegment>[];
    final arrivals = <int>[];
    var runtime = 0;
    var depth = 0.0;

    void add(PlanSegment segment) {
      segments.add(segment);
      runtime += segment.durationSeconds;
    }

    PlanSegment travel(String id, double target) => PlanSegment.travel(
      id: id,
      fromDepth: depth,
      targetDepth: target,
      tankId: tank.id,
      gasMix: tank.gasMix,
      ratePerMinute: target > depth ? plan.descentRate : plan.ascentRate,
      order: segments.length,
    );

    PlanSegment hold(String id, double target, double metres, double mps) {
      // Never clamp: a hold of one second against a current the diver cannot
      // beat would report an impossible exit as feasible. Callers check
      // traversability first; reaching here with no headway is a bug.
      if (mps <= 0) {
        throw ArgumentError.value(mps, 'mps', 'no headway on $id');
      }
      return PlanSegment(
        id: id,
        targetDepth: target,
        durationSeconds: math.max(1, (metres / mps).round()),
        tankId: tank.id,
        gasMix: tank.gasMix,
        order: segments.length,
      );
    }

    for (final leg in legs) {
      final legSpeeds = speeds.resolve(
        leg: leg,
        current: mission.currentFor(leg),
        baseSpeedMps: outboundSpeedMps,
      );
      if (leg.depthM != depth) {
        add(travel('mission-out-travel-${leg.id}', leg.depthM));
        depth = leg.depthM;
      }
      add(hold('mission-out-${leg.id}', depth, leg.distanceM, legSpeeds.outboundMps));
      arrivals.add(runtime);
    }

    for (final leg in legs.reversed) {
      final legSpeeds = speeds.resolve(
        leg: leg,
        current: mission.currentFor(leg),
        baseSpeedMps: exitSpeedMps,
      );
      if (leg.depthM != depth) {
        add(travel('mission-ret-travel-${leg.id}', leg.depthM));
        depth = leg.depthM;
      }
      add(hold('mission-ret-${leg.id}', depth, leg.distanceM, legSpeeds.returnMps));
    }

    return MissionProfile(segments: segments, waypointArrivalSeconds: arrivals);
  }

  /// The tank the bottom is breathed from: the derived back-gas cylinder,
  /// else the first tank.
  DiveTank? _bottomTank(domain.DivePlan plan) {
    if (plan.tanks.isEmpty) return null;
    final derived = roles.rolesFor(plan);
    for (final tank in plan.tanks) {
      if (derived[tank.id] == TankRole.backGas) return tank;
    }
    return plan.tanks.first;
  }
}
```

Note on the travel-segment id order: in the test vector the return travel from 30 m to 20 m is named after the leg being entered (`mission-ret-travel-L1`), which is what the loop above produces because the travel is added when `leg` is L1 and the depth still sits at 30 m.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/features/planner/mission/mission_segment_builder_test.dart`
Expected: PASS, 7 tests. If the `rolesFor` derivation returns no `backGas` for a plan whose segments are empty, the fallback to the first tank keeps the first and second tests passing; the second test lists the deco tank first on purpose, so if it fails on `{'deco'}`, read `tank_role_resolver.dart:_bottomTankId` and prefer the tank whose declared role is `TankRole.backGas` before falling back to the derived roles.

- [ ] **Step 5: Format and commit**

```bash
dart format lib/features/planner/domain/services/mission test/features/planner/mission
git add lib/features/planner/domain/services/mission/mission_segment_builder.dart test/features/planner/mission/mission_segment_builder_test.dart
git commit -m "feat(planner): build plan segments from a mission route

Refs #2086"
```

---

### Task 8: `BatteryBurnService`

**Files:**
- Create: `lib/features/planner/domain/services/mission/battery_burn_service.dart`
- Test: `test/features/planner/mission/battery_burn_service_test.dart`

**Interfaces:**
- Consumes: `ScooterSpec` (Task 1).
- Produces: `class BatteryBurnService { const BatteryBurnService(); double burnFraction({required ScooterSpec scooter, required int poweredSeconds, int towingSeconds = 0}); bool withinReserve({required double burnFraction, required double reserveFraction}); }`.

- [ ] **Step 1: Write the failing tests**

```dart
// test/features/planner/mission/battery_burn_service_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/planner/domain/entities/mission/scooter_spec.dart';
import 'package:submersion/features/planner/domain/services/mission/battery_burn_service.dart';

const _scooter = ScooterSpec(
  name: 'S',
  ratedSpeedMps: 0.5,
  burnTimeSeconds: 3600,
  towBurnFactor: 1.5,
);

void main() {
  const service = BatteryBurnService();

  test('cruising burns one over burn time per second', () {
    expect(
      service.burnFraction(scooter: _scooter, poweredSeconds: 1200),
      closeTo(1 / 3, 1e-9),
    );
  });

  test('towing burns at the tow factor on top of cruising', () {
    expect(
      service.burnFraction(
        scooter: _scooter,
        poweredSeconds: 1200,
        towingSeconds: 600,
      ),
      closeTo(1 / 3 + 0.25, 1e-9),
    );
  });

  test('a dead scooter burns nothing', () {
    expect(service.burnFraction(scooter: _scooter, poweredSeconds: 0), 0);
  });

  test('a scooter without a burn time is treated as flat', () {
    const dead = ScooterSpec(name: 'S', ratedSpeedMps: 0.5, burnTimeSeconds: 0);
    expect(service.burnFraction(scooter: dead, poweredSeconds: 60), double.infinity);
  });

  test('the reserve check holds at the boundary and fails just past it', () {
    expect(
      service.withinReserve(burnFraction: 2 / 3, reserveFraction: 1 / 3),
      isTrue,
    );
    expect(
      service.withinReserve(burnFraction: 2 / 3 + 1e-6, reserveFraction: 1 / 3),
      isFalse,
    );
  });
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/features/planner/mission/battery_burn_service_test.dart`
Expected: FAIL, import does not resolve.

- [ ] **Step 3: Write the service**

```dart
// lib/features/planner/domain/services/mission/battery_burn_service.dart
import 'package:submersion/features/planner/domain/entities/mission/scooter_spec.dart';

/// Battery use as a fraction of rated burn time.
///
/// Burn accrues at the rated rate for every second under power, even when
/// the team cruises slower than the scooter's rated speed. That is
/// conservative on purpose: a throttled scooter draws less, but by an amount
/// no attribute records, and a plan that under-counts battery is the one that
/// strands a diver.
class BatteryBurnService {
  const BatteryBurnService();

  /// Fraction of burn time used by [poweredSeconds] at cruise plus
  /// [towingSeconds] at the tow burn factor. Infinite for a scooter with no
  /// burn time, so it can never pass a reserve check.
  double burnFraction({
    required ScooterSpec scooter,
    required int poweredSeconds,
    int towingSeconds = 0,
  }) {
    if (poweredSeconds <= 0 && towingSeconds <= 0) return 0;
    if (scooter.burnTimeSeconds <= 0) return double.infinity;
    final rate = 1.0 / scooter.burnTimeSeconds;
    return poweredSeconds * rate + towingSeconds * rate * scooter.towBurnFactor;
  }

  /// True when [burnFraction] leaves at least [reserveFraction] unused. A
  /// tiny epsilon absorbs floating error at the exact boundary.
  bool withinReserve({
    required double burnFraction,
    required double reserveFraction,
  }) {
    return burnFraction <= (1.0 - reserveFraction) + 1e-9;
  }
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/features/planner/mission/battery_burn_service_test.dart`
Expected: PASS, 5 tests.

- [ ] **Step 5: Format and commit**

```bash
dart format lib/features/planner/domain/services/mission test/features/planner/mission
git add lib/features/planner/domain/services/mission/battery_burn_service.dart test/features/planner/mission/battery_burn_service_test.dart
git commit -m "feat(planner): compute scooter battery burn with a reserve

Refs #2086"
```

---

### Task 9: `MemberGasService`

**Files:**
- Create: `lib/features/planner/domain/services/mission/member_gas_service.dart`
- Test: `test/features/planner/mission/member_gas_service_test.dart`

**Interfaces:**
- Consumes: `PlanScheduleRow` (existing: `kind`, `depthMeters` at the END of the line, `durationSeconds`, `runtimeSeconds`, `tankId`), `DiveEnvironment.pressureAtDepth(double)` (existing), `pressureAfterConsuming(...)` in `lib/core/utils/gas_compressibility.dart` (existing), `DiveTank`, `GasModel`.
- Produces: `class MemberGasService { const MemberGasService(); Map<String, double> litersByTank({required List<PlanScheduleRow> rows, required DiveEnvironment environment, required double Function(PlanScheduleRow row) sacFor}); double? remainingBar({required DiveTank tank, required double litersUsed, required GasModel model}); }`.

Travel rows are charged at the mean of their start and end depth, where the start depth is the previous row's end depth (zero for the first row). Level and stop rows are charged at their own depth. `sacFor` returns litres per minute for the row; the caller decides bottom, stressed or deco.

Hand-computed vector with `DiveEnvironment.standard` (10 m per bar exactly): a descent row 0 to 20 m over 60 s at 15 L/min is 1 min at 2.0 bar = 30 L; a level row at 20 m for 600 s at 15 L/min is 10 min at 3.0 bar = 450 L; an ascent row 20 to 6 m over 90 s at 12 L/min is 1.5 min at mean 13 m = 2.3 bar = 41.4 L.

- [ ] **Step 1: Write the failing tests**

```dart
// test/features/planner/mission/member_gas_service_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/gas_model.dart';
import 'package:submersion/core/deco/entities/dive_environment.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/planner/domain/entities/plan_outcome.dart';
import 'package:submersion/features/planner/domain/services/mission/member_gas_service.dart';

PlanScheduleRow _row(
  PlanScheduleRowKind kind,
  double depth,
  int seconds,
  int runtime, {
  String tankId = 'back',
}) => PlanScheduleRow(
  kind: kind,
  depthMeters: depth,
  durationSeconds: seconds,
  runtimeSeconds: runtime,
  gasFO2: 0.21,
  gasFHe: 0,
  tankId: tankId,
);

void main() {
  const service = MemberGasService();
  const env = DiveEnvironment.standard;

  test('level rows are charged at their own depth', () {
    final liters = service.litersByTank(
      rows: [_row(PlanScheduleRowKind.level, 20, 600, 600)],
      environment: env,
      sacFor: (_) => 15,
    );
    expect(liters, {'back': closeTo(450, 1e-6)});
  });

  test('travel rows are charged at the mean of start and end depth', () {
    final liters = service.litersByTank(
      rows: [
        _row(PlanScheduleRowKind.descent, 20, 60, 60),
        _row(PlanScheduleRowKind.level, 20, 600, 660),
        _row(PlanScheduleRowKind.ascent, 6, 90, 750),
      ],
      environment: env,
      sacFor: (row) => row.kind == PlanScheduleRowKind.ascent ? 12 : 15,
    );
    expect(liters['back'], closeTo(30 + 450 + 41.4, 1e-6));
  });

  test('rows are split by tank', () {
    final liters = service.litersByTank(
      rows: [
        _row(PlanScheduleRowKind.level, 20, 600, 600),
        _row(PlanScheduleRowKind.stop, 6, 300, 900, tankId: 'deco'),
      ],
      environment: env,
      sacFor: (_) => 10,
    );
    expect(liters, {'back': closeTo(300, 1e-6), 'deco': closeTo(80, 1e-6)});
  });

  test('a row without a tank is ignored', () {
    final liters = service.litersByTank(
      rows: [
        PlanScheduleRow(
          kind: PlanScheduleRowKind.level,
          depthMeters: 20,
          durationSeconds: 60,
          runtimeSeconds: 60,
          gasFO2: 0.21,
          gasFHe: 0,
        ),
      ],
      environment: env,
      sacFor: (_) => 10,
    );
    expect(liters, isEmpty);
  });

  test('remainingBar inverts the ideal gas volume', () {
    const tank = DiveTank(
      id: 'back',
      volume: 24,
      startPressure: 200,
      gasMix: GasMix(o2: 21),
      role: TankRole.backGas,
    );
    expect(
      service.remainingBar(tank: tank, litersUsed: 1200, model: GasModel.ideal),
      closeTo(150, 1e-9),
    );
  });

  test('remainingBar is null without a start pressure or volume', () {
    const tank = DiveTank(id: 'back', gasMix: GasMix(o2: 21), role: TankRole.backGas);
    expect(service.remainingBar(tank: tank, litersUsed: 10, model: GasModel.ideal), isNull);
  });
}
```

Confirm the `DiveTank` constructor's required parameters in `lib/features/dive_log/domain/entities/dive.dart` near line 1081 (the engine tests construct it with `id`, `volume`, `startPressure`, `gasMix`, `role`); add any other required parameter with a neutral value.

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/features/planner/mission/member_gas_service_test.dart`
Expected: FAIL, import does not resolve.

- [ ] **Step 3: Write the service**

```dart
// lib/features/planner/domain/services/mission/member_gas_service.dart
import 'package:submersion/core/constants/gas_model.dart';
import 'package:submersion/core/deco/entities/dive_environment.dart';
import 'package:submersion/core/utils/gas_compressibility.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/planner/domain/entities/plan_outcome.dart';

/// Gas one team member breathes over a schedule, from their own SAC.
///
/// The plan engine charges gas at the plan's single SAC; a mission has one
/// SAC per member, so consumption is re-derived from the engine's schedule
/// rows (depth and duration) instead of running the engine once per member.
class MemberGasService {
  const MemberGasService();

  /// Surface litres breathed per tank id over [rows]. A travel row is charged
  /// at the mean of its start depth (the previous row's end, or the surface)
  /// and its end depth; a level or stop row at its own depth. [sacFor] gives
  /// the litres per minute in force on a row.
  Map<String, double> litersByTank({
    required List<PlanScheduleRow> rows,
    required DiveEnvironment environment,
    required double Function(PlanScheduleRow row) sacFor,
  }) {
    final liters = <String, double>{};
    var previousDepth = 0.0;
    for (final row in rows) {
      final tankId = row.tankId;
      final isTravel =
          row.kind == PlanScheduleRowKind.descent ||
          row.kind == PlanScheduleRowKind.ascent;
      final depth = isTravel
          ? (previousDepth + row.depthMeters) / 2.0
          : row.depthMeters;
      previousDepth = row.depthMeters;
      if (tankId == null) continue;
      final minutes = row.durationSeconds / 60.0;
      final used = minutes * sacFor(row) * environment.pressureAtDepth(depth);
      liters[tankId] = (liters[tankId] ?? 0.0) + used;
    }
    return liters;
  }

  /// Pressure left in [tank] after [litersUsed], or null when the tank has no
  /// start pressure or no volume.
  double? remainingBar({
    required DiveTank tank,
    required double litersUsed,
    required GasModel model,
  }) {
    final start = tank.startPressure;
    final volume = tank.volume;
    if (start == null || volume == null) return null;
    return pressureAfterConsuming(
      tankSizeLiters: volume,
      startPressureBar: start,
      litersConsumed: litersUsed,
      o2Percent: tank.gasMix.o2,
      hePercent: tank.gasMix.he,
      model: model,
    );
  }
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/features/planner/mission/member_gas_service_test.dart`
Expected: PASS, 6 tests. If `DiveEnvironment.standard` is not 10 m per bar (the first test would read about 448.9 instead of 450), replace `env` in the test with `DiveEnvironment.forConditions(altitudeMeters: null, waterType: WaterType.salt, salinityPpt: DiveEnvironment.salinityPptFromDensity(DiveEnvironment.en13319Density))`, which the engine tests use to pin exactly 10 m per bar.

- [ ] **Step 5: Format and commit**

```bash
dart format lib/features/planner/domain/services/mission test/features/planner/mission
git add lib/features/planner/domain/services/mission/member_gas_service.dart test/features/planner/mission/member_gas_service_test.dart
git commit -m "feat(planner): derive per-member gas from schedule rows

Refs #2086"
```

---

### Task 10: `MissionScenarioService`

**Files:**
- Create: `lib/features/planner/domain/services/mission/mission_scenario_service.dart`
- Test: `test/features/planner/mission/mission_scenario_service_test.dart`

**Interfaces:**
- Consumes: `MissionSegmentBuilder.build` (Task 7), `BatteryBurnService` (Task 8), `MemberGasService` (Task 9), `slowestSwimSpeedMps` and `cruiseSpeedMps` (Task 6), `ExitOutcome`, `MissionExitMode` (Task 5), `PlanEngine.compute(DivePlan)` returning `PlanOutcome` with `schedule`, `runtimeSeconds`, `ttsAtBottom` (existing), `PlanEngineConfig.gasModel` (existing), `DiveEnvironment.forConditions` (existing).
- Produces:

```dart
class MissionScenarioService {
  const MissionScenarioService({
    PlanEngine engine = const PlanEngine(),
    MissionSegmentBuilder builder = const MissionSegmentBuilder(),
    BatteryBurnService battery = const BatteryBurnService(),
    MemberGasService gas = const MemberGasService(),
  });

  /// The exit for [failedMemberId]'s scooter dying on arrival at waypoint
  /// [waypointIndex]. For [MissionExitMode.tow], [towerId] names the tower.
  ExitOutcome evaluate({
    required DivePlan plan,
    required DpvMission mission,
    required int waypointIndex,
    required String failedMemberId,
    required MissionExitMode mode,
    String? towerId,
  });

  /// Speed of a tow exit: the tower's tow speed, capped by the rated speed of
  /// every other running scooter.
  double towSpeedMps({required DpvMission mission, required String failedMemberId, required String towerId});
}
```

Semantics (from the spec):
- Outbound speed is the team cruise speed. Exit speed is `slowestSwimSpeedMps(team)` for a swim and `towSpeedMps(...)` for a tow.
- The scenario plan is `plan.copyWith(segments: profile.segments)` and is run through `engine.compute` once.
- `failureRuntime = profile.waypointArrivalSeconds[waypointIndex]`; `authoredRuntime = outcome.runtimeSeconds - outcome.ttsAtBottom`.
- Rows with `runtimeSeconds <= failureRuntime` are outbound; the rest are exit rows. Exit rows with `runtimeSeconds <= authoredRuntime` are the bottom part of the exit; later rows are deco.
- SAC per member and row: outbound rows use `member.sacBottom`; exit bottom rows use `plan.sacStressedEffective` for the failed member and `member.sacBottom` for others; deco rows use `plan.sacDecoEffective` for everyone.
- Gas feasibility per member: for every tank that has a start pressure and volume, `remainingBar(tank, outbound + exit litres on that tank) >= plan.reservePressure`.
- Battery: outbound powered seconds = `failureRuntime` for everyone. Exit bottom seconds = `authoredRuntime - failureRuntime`. Swim: nobody powered on the exit. Tow: tower has `towingSeconds = exitBottomSeconds`, other running members have `poweredSeconds += exitBottomSeconds`, the failed member none. A member fails battery when `!withinReserve(burnFraction, mission.batteryReserveFraction)`; the failed member is never a battery shortfall.
- `feasible` is true when both shortfall sets are empty.
- `exitLitersByMember` holds each member's total exit litres across tanks.
- `exitBottomSeconds` is `authoredRuntime - failureRuntime`; `ttsSeconds` is `outcome.ttsAtBottom`.

Fixture for the tests. Plan: gf 40/80, salinity pinned to EN13319 (10 m per bar), descent 18, ascent 9, reserve 50 bar, sacBottom 15 (so stressed is 37.5), one back tank `back` 24 L at 200 bar of air. Route: one leg `L1`, 300 m at 20 m, heading 0, no current. Team A and B, both SAC 15, swim 0.2, scooters at 0.5 m/s with 7200 s burn. Then:
- outbound: travel 67 s, hold 600 s; `waypointArrivalSeconds = [667]`.
- swim exit hold: 300 / 0.2 = 1500 s. Tow exit by A: tow speed 0.5 * 0.6 = 0.3, capped by nothing (B is dead, not counted) so 0.3; hold 1000 s.
- gas, at 3 bar: outbound about 0.75 L/s x 600 s + 33 L = 483 L; the failed member's swim exit 1.875 L/s x 1500 s = 2813 L. A 40 L tank at 230 bar leaves about 6800 L above the 50 bar reserve, so both exits are feasible with room for deco; a 3 L tank (600 L) fails on the outbound alone.
- Exit traversability: before building a scenario, every leg from the waypoint back is resolved at the exit speed. If any return speed is zero or below, the scenario returns `ExitOutcome(feasible: false, blockedByCurrent: true, exitBottomSeconds: 0, ttsSeconds: 0, exitLitersByMember: {})` without calling the engine.

- [ ] **Step 1: Write the failing tests**

```dart
// test/features/planner/mission/mission_scenario_service_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/deco/entities/dive_environment.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    as domain;
import 'package:submersion/features/planner/domain/entities/mission/current_vector.dart';
import 'package:submersion/features/planner/domain/entities/mission/dpv_mission.dart';
import 'package:submersion/features/planner/domain/entities/mission/mission_leg.dart';
import 'package:submersion/features/planner/domain/entities/mission/mission_member.dart';
import 'package:submersion/features/planner/domain/entities/mission/mission_outcome.dart';
import 'package:submersion/features/planner/domain/entities/mission/scooter_spec.dart';
import 'package:submersion/features/planner/domain/services/mission/mission_scenario_service.dart';

const _air = GasMix(o2: 21);

domain.DivePlan _plan({double tankLiters = 24, double startBar = 200}) =>
    domain.DivePlan(
      id: 'plan-1',
      name: 'Scenario',
      gfLow: 40,
      gfHigh: 80,
      descentRate: 18,
      ascentRate: 9,
      sacBottom: 15,
      reservePressure: 50,
      salinityPpt: DiveEnvironment.salinityPptFromDensity(
        DiveEnvironment.en13319Density,
      ),
      tanks: [
        DiveTank(
          id: 'back',
          volume: tankLiters,
          startPressure: startBar,
          gasMix: _air,
          role: TankRole.backGas,
        ),
      ],
      createdAt: DateTime(2026, 9, 18),
      updatedAt: DateTime(2026, 9, 18),
    );

MissionMember _member(String id, int order, {int burn = 7200, double speed = 0.5}) =>
    MissionMember(
      id: id,
      order: order,
      displayName: id,
      sacBottom: 15,
      swimSpeedMps: 0.2,
      scooter: ScooterSpec(name: 'S-$id', ratedSpeedMps: speed, burnTimeSeconds: burn),
    );

const _leg = MissionLeg(
  id: 'L1',
  order: 0,
  label: 'T',
  distanceM: 300,
  depthM: 20,
  headingDeg: 0,
);

DpvMission _mission({List<MissionMember>? team, MissionLeg leg = _leg}) =>
    DpvMission(
  legs: [leg],
  team: team ?? [_member('a', 0), _member('b', 1)],
);

void main() {
  const service = MissionScenarioService();

  test('a swim exit covers the leg at the slowest swim speed with no burn', () {
    final exit = service.evaluate(
      plan: _plan(),
      mission: _mission(),
      waypointIndex: 0,
      failedMemberId: 'b',
      mode: MissionExitMode.swim,
    );
    expect(exit.mode, MissionExitMode.swim);
    expect(exit.towerId, isNull);
    expect(exit.exitBottomSeconds, 1500);
    expect(exit.ttsSeconds, greaterThan(0));
    expect(exit.batteryShortfallMemberIds, isEmpty);
    expect(exit.exitLitersByMember.keys, containsAll(['a', 'b']));
  });

  test('the failed member breathes stressed SAC on the swim out', () {
    final exit = service.evaluate(
      plan: _plan(),
      mission: _mission(),
      waypointIndex: 0,
      failedMemberId: 'b',
      mode: MissionExitMode.swim,
    );
    // Same tank, same schedule: only the SAC differs, 37.5 versus 15 on the
    // bottom rows, so b's exit gas is well above a's.
    expect(exit.exitLitersByMember['b']!, greaterThan(exit.exitLitersByMember['a']! * 2));
  });

  test('a tow exit is faster than a swim and needs less gas', () {
    final swim = service.evaluate(
      plan: _plan(),
      mission: _mission(),
      waypointIndex: 0,
      failedMemberId: 'b',
      mode: MissionExitMode.swim,
    );
    final tow = service.evaluate(
      plan: _plan(),
      mission: _mission(),
      waypointIndex: 0,
      failedMemberId: 'b',
      mode: MissionExitMode.tow,
      towerId: 'a',
    );
    expect(tow.towerId, 'a');
    expect(tow.exitBottomSeconds, 1000);
    expect(tow.exitBottomSeconds, lessThan(swim.exitBottomSeconds));
    expect(tow.exitLitersByMember['b']!, lessThan(swim.exitLitersByMember['b']!));
  });

  test('a tower without battery for the tow is a battery shortfall', () {
    // Outbound 667 s plus 1000 s towing at 1.5x on a 3000 s battery:
    // 667/3000 + 1000*1.5/3000 = 0.72, past the two-thirds allowed.
    final tow = service.evaluate(
      plan: _plan(),
      mission: _mission(team: [_member('a', 0, burn: 3000), _member('b', 1)]),
      waypointIndex: 0,
      failedMemberId: 'b',
      mode: MissionExitMode.tow,
      towerId: 'a',
    );
    expect(tow.batteryShortfallMemberIds, {'a'});
    expect(tow.feasible, isFalse);
  });

  test('a tank too small for the exit is a gas shortfall for that member', () {
    // 3 L at 200 bar is 600 L; the outbound is about 483 L and the swim
    // out adds over 1100 L for either member, so both run out.
    final swim = service.evaluate(
      plan: _plan(tankLiters: 3),
      mission: _mission(),
      waypointIndex: 0,
      failedMemberId: 'b',
      mode: MissionExitMode.swim,
    );
    expect(swim.gasShortfallMemberIds, {'a', 'b'});
    expect(swim.feasible, isFalse);
  });

  test('a generous tank and battery make both exits feasible', () {
    for (final mode in MissionExitMode.values) {
      final exit = service.evaluate(
        plan: _plan(tankLiters: 40, startBar: 230),
        mission: _mission(),
        waypointIndex: 0,
        failedMemberId: 'b',
        mode: mode,
        towerId: mode == MissionExitMode.tow ? 'a' : null,
      );
      expect(exit.feasible, isTrue, reason: '$mode');
    }
  });

  test('a current a swim cannot beat blocks the exit without running the engine', () {
    // 0.3 m/s setting toward 0 on a heading of 0: the scooters make 0.2 m/s
    // on the way back, but a 0.2 m/s swim makes no headway at all.
    const leg = MissionLeg(
      id: 'L1',
      order: 0,
      label: 'T',
      distanceM: 300,
      depthM: 20,
      headingDeg: 0,
      current: CurrentVector(speedMps: 0.3, setsTowardDeg: 0),
    );
    final swim = service.evaluate(
      plan: _plan(tankLiters: 40, startBar: 230),
      mission: _mission(leg: leg),
      waypointIndex: 0,
      failedMemberId: 'b',
      mode: MissionExitMode.swim,
    );
    expect(swim.blockedByCurrent, isTrue);
    expect(swim.feasible, isFalse);
    expect(swim.exitLitersByMember, isEmpty);
  });

  test('the tow speed is capped by the slowest other running scooter', () {
    final mission = _mission(
      team: [_member('a', 0, speed: 1.0), _member('b', 1), _member('c', 2, speed: 0.4)],
    );
    // a tows b: 1.0 * 0.6 = 0.6, but c can only make 0.4.
    expect(
      service.towSpeedMps(mission: mission, failedMemberId: 'b', towerId: 'a'),
      closeTo(0.4, 1e-9),
    );
    // c tows b: 0.4 * 0.6 = 0.24, a keeps up easily.
    expect(
      service.towSpeedMps(mission: mission, failedMemberId: 'b', towerId: 'c'),
      closeTo(0.24, 1e-9),
    );
  });
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/features/planner/mission/mission_scenario_service_test.dart`
Expected: FAIL, import does not resolve.

- [ ] **Step 3: Write the service**

```dart
// lib/features/planner/domain/services/mission/mission_scenario_service.dart
import 'dart:math' as math;

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/deco/entities/dive_environment.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    as domain;
import 'package:submersion/features/planner/domain/entities/mission/dpv_mission.dart';
import 'package:submersion/features/planner/domain/entities/mission/mission_member.dart';
import 'package:submersion/features/planner/domain/entities/mission/mission_outcome.dart';
import 'package:submersion/features/planner/domain/entities/plan_outcome.dart';
import 'package:submersion/features/planner/domain/services/mission/battery_burn_service.dart';
import 'package:submersion/features/planner/domain/services/mission/leg_speed_resolver.dart';
import 'package:submersion/features/planner/domain/services/mission/member_gas_service.dart';
import 'package:submersion/features/planner/domain/services/mission/mission_segment_builder.dart';
import 'package:submersion/features/planner/domain/services/mission/mission_team.dart';
import 'package:submersion/features/planner/domain/services/plan_engine.dart';

/// Evaluates one scooter failure: a member's scooter dies on arrival at a
/// waypoint and the team exits by swimming or by towing.
///
/// Each scenario is a plan copy whose segments run out to the waypoint at
/// cruise and back at the exit speed. The plan engine runs once per scenario
/// for the schedule and time to surface; per-member gas is re-derived from
/// the schedule rows with each member's own SAC.
class MissionScenarioService {
  final PlanEngine engine;
  final MissionSegmentBuilder builder;
  final BatteryBurnService battery;
  final MemberGasService gas;
  final LegSpeedResolver speeds;

  const MissionScenarioService({
    this.engine = const PlanEngine(),
    this.builder = const MissionSegmentBuilder(),
    this.battery = const BatteryBurnService(),
    this.gas = const MemberGasService(),
    this.speeds = const LegSpeedResolver(),
  });

  /// Speed of a tow exit: the tower's tow speed, capped by every other
  /// running scooter's rated speed so the team stays together.
  double towSpeedMps({
    required DpvMission mission,
    required String failedMemberId,
    required String towerId,
  }) {
    var speed = double.infinity;
    for (final member in mission.team) {
      if (member.id == failedMemberId) continue;
      final own = member.id == towerId
          ? member.scooter.towSpeedMps
          : member.scooter.ratedSpeedMps;
      speed = math.min(speed, own);
    }
    return speed.isFinite ? speed : 0.0;
  }

  ExitOutcome evaluate({
    required domain.DivePlan plan,
    required DpvMission mission,
    required int waypointIndex,
    required String failedMemberId,
    required MissionExitMode mode,
    String? towerId,
  }) {
    final exitSpeed = switch (mode) {
      MissionExitMode.swim => slowestSwimSpeedMps(mission.team),
      MissionExitMode.tow => towSpeedMps(
        mission: mission,
        failedMemberId: failedMemberId,
        towerId: towerId!,
      ),
    };
    if (!_exitTraversable(mission, waypointIndex, exitSpeed)) {
      return ExitOutcome(
        mode: mode,
        towerId: mode == MissionExitMode.tow ? towerId : null,
        feasible: false,
        exitBottomSeconds: 0,
        ttsSeconds: 0,
        exitLitersByMember: const {},
        blockedByCurrent: true,
      );
    }
    final profile = builder.build(
      plan: plan,
      mission: mission,
      throughLegIndex: waypointIndex,
      outboundSpeedMps: cruiseSpeedMps(mission.team),
      exitSpeedMps: exitSpeed,
    );
    final outcome = engine.compute(plan.copyWith(segments: profile.segments));
    final failureRuntime = profile.waypointArrivalSeconds[waypointIndex];
    final authoredRuntime = outcome.runtimeSeconds - outcome.ttsAtBottom;
    final exitBottomSeconds = math.max(0, authoredRuntime - failureRuntime);
    final environment = _environmentFor(plan);

    final outboundRows = outcome.schedule
        .where((r) => r.runtimeSeconds <= failureRuntime)
        .toList();
    final exitRows = outcome.schedule
        .where((r) => r.runtimeSeconds > failureRuntime)
        .toList();

    final exitLiters = <String, double>{};
    final gasShortfall = <String>{};
    final batteryShortfall = <String>{};

    for (final member in mission.team) {
      final failed = member.id == failedMemberId;
      final outbound = gas.litersByTank(
        rows: outboundRows,
        environment: environment,
        sacFor: (_) => member.sacBottom,
      );
      final exit = gas.litersByTank(
        rows: exitRows,
        environment: environment,
        sacFor: (row) => _exitSac(
          plan: plan,
          member: member,
          failed: failed,
          row: row,
          authoredRuntime: authoredRuntime,
        ),
      );
      exitLiters[member.id] = exit.values.fold(0.0, (a, b) => a + b);
      if (_gasShort(plan, outbound, exit)) gasShortfall.add(member.id);
      if (!failed) {
        final tows = mode == MissionExitMode.tow && member.id == towerId;
        final powered = failureRuntime +
            (mode == MissionExitMode.tow && !tows ? exitBottomSeconds : 0);
        final fraction = battery.burnFraction(
          scooter: member.scooter,
          poweredSeconds: powered,
          towingSeconds: tows ? exitBottomSeconds : 0,
        );
        if (!battery.withinReserve(
          burnFraction: fraction,
          reserveFraction: mission.batteryReserveFraction,
        )) {
          batteryShortfall.add(member.id);
        }
      }
    }

    return ExitOutcome(
      mode: mode,
      towerId: mode == MissionExitMode.tow ? towerId : null,
      feasible: gasShortfall.isEmpty && batteryShortfall.isEmpty,
      exitBottomSeconds: exitBottomSeconds,
      ttsSeconds: outcome.ttsAtBottom,
      exitLitersByMember: exitLiters,
      gasShortfallMemberIds: gasShortfall,
      batteryShortfallMemberIds: batteryShortfall,
    );
  }

  /// True when the team can make headway at [exitSpeed] on every leg from
  /// waypoint [waypointIndex] back to the start.
  bool _exitTraversable(DpvMission mission, int waypointIndex, double exitSpeed) {
    for (var i = 0; i <= waypointIndex; i++) {
      final leg = mission.legs[i];
      final resolved = speeds.resolve(
        leg: leg,
        current: mission.currentFor(leg),
        baseSpeedMps: exitSpeed,
      );
      if (!resolved.returnTraversable) return false;
    }
    return true;
  }

  double _exitSac({
    required domain.DivePlan plan,
    required MissionMember member,
    required bool failed,
    required PlanScheduleRow row,
    required int authoredRuntime,
  }) {
    if (row.runtimeSeconds > authoredRuntime) return plan.sacDecoEffective;
    return failed ? plan.sacStressedEffective : member.sacBottom;
  }

  /// True when any tank with a known size and fill would end below the plan
  /// reserve after [outbound] plus [exit] litres.
  bool _gasShort(
    domain.DivePlan plan,
    Map<String, double> outbound,
    Map<String, double> exit,
  ) {
    for (final tank in plan.tanks) {
      final used = (outbound[tank.id] ?? 0.0) + (exit[tank.id] ?? 0.0);
      final remaining = gas.remainingBar(
        tank: tank,
        litersUsed: used,
        model: engine.config.gasModel,
      );
      if (remaining == null) continue;
      if (remaining < plan.reservePressure) return true;
    }
    return false;
  }

  /// The same environment the engine derives for [plan] (see
  /// `PlanEngine._computeInternal`), so ambient pressure agrees with deco.
  static DiveEnvironment _environmentFor(domain.DivePlan plan) {
    return DiveEnvironment.forConditions(
      altitudeMeters: (plan.altitude ?? 0) > 0 ? plan.altitude : null,
      waterType: plan.waterType ?? WaterType.salt,
      salinityPpt: plan.salinityPpt,
    );
  }
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/features/planner/mission/mission_scenario_service_test.dart`
Expected: PASS, 8 tests. If the "generous tank" test fails on the tow mode with a battery shortfall, check the arithmetic: outbound 667 s plus 1000 s towing at 1.5 on a 7200 s battery is 0.093 + 0.208 = 0.30, under the 0.667 allowed; a failure there means the powered seconds were double counted.

- [ ] **Step 5: Format and commit**

```bash
dart format lib/features/planner/domain/services/mission test/features/planner/mission
git add lib/features/planner/domain/services/mission/mission_scenario_service.dart test/features/planner/mission/mission_scenario_service_test.dart
git commit -m "feat(planner): evaluate scooter failure exits through the plan engine

Refs #2086"
```

---

### Task 11: `MissionEngine`

**Files:**
- Create: `lib/features/planner/domain/services/mission/mission_engine.dart`
- Test: `test/features/planner/mission/mission_engine_test.dart`

**Interfaces:**
- Consumes: everything from Tasks 5 to 10.
- Produces:

```dart
class MissionEngine {
  const MissionEngine({
    MissionScenarioService scenarios = const MissionScenarioService(),
    MissionSegmentBuilder builder = const MissionSegmentBuilder(),
    BatteryBurnService battery = const BatteryBurnService(),
    LegSpeedResolver speeds = const LegSpeedResolver(),
  });

  MissionOutcome compute({required DivePlan plan, required DpvMission mission});
}
```

Algorithm:
1. Validation issues. `emptyTeam` (blocking) when the team is empty; `emptyRoute` (blocking) when there are no legs; `scooterUnspecified` (blocking, memberId) for a member whose scooter has `ratedSpeedMps <= 0` or `burnTimeSeconds <= 0`; `memberSacUnset` (blocking, memberId) for `sacBottom <= 0`. With any blocking issue, return `MissionOutcome.empty(issues: issues)`.
2. `cruise = cruiseSpeedMps(team)`, `limitingId = cruiseLimitingMemberId(team)`.
3. For each leg in order, `speeds.resolve(leg, mission.currentFor(leg), cruise)`. The first leg that is not traversable adds an `untraversableLeg` blocking issue (legId, `outbound: !outboundTraversable`) and cuts the route: `traversable = mission.copyWith(legs: legs before it)`. If no leg is traversable, return `MissionOutcome.empty` with the issues. Legs after the cut are dropped from every list below.
4. `profile = builder.build(plan, traversable, throughLegIndex: last, outboundSpeedMps: cruise, exitSpeedMps: cruise)`. `segments = profile.segments`. Leg outcomes: from the resolved speeds and the hold segment durations (`mission-out-<id>` and `mission-ret-<id>`).
5. Round-trip battery per member: `battery.burnFraction(scooter, poweredSeconds: total of all segment durations)`.
6. For each waypoint k and member m: `swim = scenarios.evaluate(mode: swim)`; for every teammate t, `scenarios.evaluate(mode: tow, towerId: t.id)`; best tow = a feasible one with the smallest `exitSeconds`, else the infeasible one with the smallest `exitSeconds`, null with no teammate. A scenario that throws becomes a `scenarioFailed` warning issue (memberId, legId) and counts as infeasible: catch `Object`, record the issue, and substitute an `ExitOutcome` with `feasible: false`, zero seconds and empty maps. `survivable = swim.feasible || (tow?.feasible ?? false)`. `gasRemainingBar` for m at k: the bottom tank (the tank of `segments.first`) remaining after m's outbound litres; compute it with `MemberGasService` on the rows of `engine.compute` for the round-trip plan, restricted to `runtimeSeconds <= profile.waypointArrivalSeconds[k]`, at `member.sacBottom`. Cumulative distance is the sum of leg distances through k; arrival runtime is `profile.waypointArrivalSeconds[k]`.
7. `abandonmentIndex`: the largest k such that waypoints 0 through k are all survivable; null when waypoint 0 is not.
8. Per member binding factor, checked at each k in order, first hit wins. At each k, `battery` binds first when `burnFraction(scooter, poweredSeconds: arrival_k + returnSeconds_k)` exceeds the reserve, where `returnSeconds_k` is the sum of the return hold and travel segments of legs 0 through k. Battery can bind at a k where the failure is still survivable. Otherwise, at the first k where m's own failure is not survivable, classify by the swim exit, because a swim never burns battery and so fails only on gas or current: `ownGas` when m is in the swim's gas shortfall; `swimGas` when a teammate is (m could swim out, but the team's gas cannot cover it, and no tow works either); `noFeasibleTow` otherwise, which is the case where the swim is blocked by current and no tow works.
9. `constraint`: the member with the smallest `bindingWaypointIndex`; ties broken by factor order `battery, ownGas, noFeasibleTow, swimGas`, then member order. Null when nobody binds.
10. `turnPressureBar` per member: at `a = abandonmentIndex` (null gives null), the maximum over every scenario at a that is feasible (every failed member, swim and best tow) of m's exit litres on the bottom tank, converted to bar as `startPressure - remainingBar(tank, exitLiters)` and then plus `plan.reservePressure`. Use `MemberGasService.remainingBar` for the conversion. To get per-tank exit litres, extend `ExitOutcome.exitLitersByMember` semantics: it already holds total litres per member; for the turn pressure use the total (the mission's bottom phase is on one tank, and deco litres on a deco tank are a small over-estimate that errs safe). State this in a comment.

Fixtures for the tests reuse Task 10's plan and members. Add a three-member constraint fixture: route of two legs, each 400 m at 15 m, heading 0. Team: `a` SAC 25, scooter 0.9 m/s, 7200 s; `b` SAC 15, scooter 0.7 m/s, burn 2400 s; `c` SAC 15, scooter 0.4 m/s, 7200 s. Tank 40 L at 230 bar. Cruise is 0.4 (c). Each hold is 1000 s; travel 0 to 15 at 18 m/min is 50 s. Waypoint 0 arrival 1050 s; return from 0 is 1000 s; 2050 / 2400 = 0.85 > 0.667, so `b` binds by battery at waypoint 0. `a` has the highest SAC but a 9200 L tank; `c` sets the cruise.

- [ ] **Step 1: Write the failing tests**

```dart
// test/features/planner/mission/mission_engine_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/deco/entities/dive_environment.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    as domain;
import 'package:submersion/features/planner/domain/entities/mission/current_vector.dart';
import 'package:submersion/features/planner/domain/entities/mission/dpv_mission.dart';
import 'package:submersion/features/planner/domain/entities/mission/mission_leg.dart';
import 'package:submersion/features/planner/domain/entities/mission/mission_member.dart';
import 'package:submersion/features/planner/domain/entities/mission/mission_outcome.dart';
import 'package:submersion/features/planner/domain/entities/mission/scooter_spec.dart';
import 'package:submersion/features/planner/domain/services/mission/mission_engine.dart';

const _air = GasMix(o2: 21);

domain.DivePlan _plan({double tankLiters = 24, double startBar = 200}) =>
    domain.DivePlan(
      id: 'plan-1',
      name: 'Engine',
      gfLow: 40,
      gfHigh: 80,
      descentRate: 18,
      ascentRate: 9,
      sacBottom: 15,
      reservePressure: 50,
      salinityPpt: DiveEnvironment.salinityPptFromDensity(
        DiveEnvironment.en13319Density,
      ),
      tanks: [
        DiveTank(
          id: 'back',
          volume: tankLiters,
          startPressure: startBar,
          gasMix: _air,
          role: TankRole.backGas,
        ),
      ],
      createdAt: DateTime(2026, 9, 18),
      updatedAt: DateTime(2026, 9, 18),
    );

MissionMember _member(
  String id,
  int order, {
  double sac = 15,
  double speed = 0.5,
  int burn = 7200,
}) => MissionMember(
  id: id,
  order: order,
  displayName: id,
  sacBottom: sac,
  swimSpeedMps: 0.2,
  scooter: ScooterSpec(name: 'S-$id', ratedSpeedMps: speed, burnTimeSeconds: burn),
);

MissionLeg _leg(String id, int order, {double distance = 500, double depth = 20, CurrentVector? current}) =>
    MissionLeg(
      id: id,
      order: order,
      label: id,
      distanceM: distance,
      depthM: depth,
      headingDeg: 0,
      current: current,
    );

void main() {
  const engine = MissionEngine();

  group('validation', () {
    test('an empty team is blocking and computes nothing', () {
      final outcome = engine.compute(
        plan: _plan(),
        mission: DpvMission(legs: [_leg('L1', 0)]),
      );
      expect(outcome.isBlocked, isTrue);
      expect(outcome.issues.single.type, MissionIssueType.emptyTeam);
      expect(outcome.segments, isEmpty);
    });

    test('an empty route is blocking', () {
      final outcome = engine.compute(
        plan: _plan(),
        mission: DpvMission(team: [_member('a', 0)]),
      );
      expect(outcome.issues.single.type, MissionIssueType.emptyRoute);
    });

    test('a scooter without a speed and a member without SAC are named', () {
      final outcome = engine.compute(
        plan: _plan(),
        mission: DpvMission(
          legs: [_leg('L1', 0)],
          team: [_member('a', 0, speed: 0), _member('b', 1, sac: 0)],
        ),
      );
      expect(
        outcome.issues.map((i) => (i.type, i.memberId)).toSet(),
        {
          (MissionIssueType.scooterUnspecified, 'a'),
          (MissionIssueType.memberSacUnset, 'b'),
        },
      );
      expect(outcome.isBlocked, isTrue);
    });
  });

  group('route', () {
    test('the round trip segments and leg outcomes come from the cruise speed', () {
      final outcome = engine.compute(
        plan: _plan(tankLiters: 40, startBar: 230),
        mission: DpvMission(
          legs: [_leg('L1', 0), _leg('L2', 1, depth: 30)],
          team: [_member('a', 0), _member('b', 1, speed: 0.9)],
        ),
      );
      expect(outcome.cruiseSpeedMps, 0.5);
      expect(outcome.members.firstWhere((m) => m.memberId == 'a').setsCruiseSpeed, isTrue);
      expect(outcome.members.firstWhere((m) => m.memberId == 'b').setsCruiseSpeed, isFalse);
      expect(outcome.segments.map((s) => s.id).toList(), [
        'mission-out-travel-L1',
        'mission-out-L1',
        'mission-out-travel-L2',
        'mission-out-L2',
        'mission-ret-L2',
        'mission-ret-travel-L1',
        'mission-ret-L1',
      ]);
      expect(outcome.legs.map((l) => l.legId).toList(), ['L1', 'L2']);
      expect(outcome.legs.first.outboundSeconds, 1000);
      expect(outcome.legs.first.returnSeconds, 1000);
      expect(outcome.waypoints.map((w) => w.cumulativeDistanceM).toList(), [500, 1000]);
      expect(outcome.waypoints.map((w) => w.arrivalRuntimeSeconds).toList(), [1067, 2100]);
    });

    test('an untraversable leg blocks and cuts the route before it', () {
      final outcome = engine.compute(
        plan: _plan(tankLiters: 40, startBar: 230),
        mission: DpvMission(
          legs: [
            _leg('L1', 0),
            _leg('L2', 1, current: const CurrentVector(speedMps: 0.5, setsTowardDeg: 0)),
            _leg('L3', 2),
          ],
          team: [_member('a', 0), _member('b', 1)],
        ),
      );
      final issue = outcome.issues.singleWhere(
        (i) => i.type == MissionIssueType.untraversableLeg,
      );
      expect(issue.legId, 'L2');
      expect(issue.outbound, isFalse, reason: 'the return is the blocked direction');
      expect(outcome.isBlocked, isTrue);
      expect(outcome.legs.map((l) => l.legId).toList(), ['L1']);
      expect(outcome.waypoints, hasLength(1));
    });
  });

  group('failure management', () {
    test('a generous plan survives every waypoint with no constraint', () {
      final outcome = engine.compute(
        plan: _plan(tankLiters: 40, startBar: 230),
        mission: DpvMission(
          legs: [_leg('L1', 0, distance: 200), _leg('L2', 1, distance: 200)],
          team: [_member('a', 0), _member('b', 1)],
        ),
      );
      expect(outcome.waypoints.every((w) => w.survivable), isTrue);
      expect(outcome.abandonmentIndex, 1);
      expect(outcome.constraint, isNull);
      for (final member in outcome.members) {
        expect(member.bindingFactor, isNull, reason: member.memberId);
        expect(member.turnPressureBar, greaterThan(50), reason: member.memberId);
      }
    });

    test('a tiny tank makes the first waypoint unsurvivable on own gas', () {
      final outcome = engine.compute(
        plan: _plan(tankLiters: 3),
        mission: DpvMission(
          legs: [_leg('L1', 0)],
          team: [_member('a', 0), _member('b', 1)],
        ),
      );
      expect(outcome.waypoints.single.survivable, isFalse);
      expect(outcome.abandonmentIndex, isNull);
      expect(outcome.constraint, isNotNull);
      expect(outcome.constraint!.factor, MissionBindingFactor.ownGas);
      expect(outcome.constraint!.waypointIndex, 0);
      expect(outcome.members.every((m) => m.turnPressureBar == null), isTrue);
    });

    test('a current only the scooters beat makes a tow the only way out', () {
      // 0.3 m/s setting toward 0 on a heading of 0: the team makes 0.2 m/s
      // home on scooters, a tow at 0.3 - 0.3 = 0 makes none, and a swim at
      // 0.2 makes none. Every failure is unsurvivable and blocked by current.
      final outcome = engine.compute(
        plan: _plan(tankLiters: 40, startBar: 230),
        mission: DpvMission(
          legs: [
            _leg(
              'L1',
              0,
              distance: 200,
              current: const CurrentVector(speedMps: 0.3, setsTowardDeg: 0),
            ),
          ],
          team: [_member('a', 0), _member('b', 1)],
        ),
      );
      final b = outcome.waypoints.single.members.firstWhere(
        (m) => m.memberId == 'b',
      );
      expect(b.swim.blockedByCurrent, isTrue);
      expect(b.tow!.blockedByCurrent, isTrue);
      expect(b.survivable, isFalse);
      expect(outcome.constraint!.factor, MissionBindingFactor.noFeasibleTow);
    });

    test('the abandonment point is the last survivable waypoint', () {
      // 24 L at 200 bar (about 3460 L above reserve): a tow out from 200 m
      // needs about 1650 L all in, from 600 m about 4700 L.
      final outcome = engine.compute(
        plan: _plan(),
        mission: DpvMission(
          legs: [
            _leg('L1', 0, distance: 200),
            _leg('L2', 1, distance: 200),
            _leg('L3', 2, distance: 200),
          ],
          team: [_member('a', 0), _member('b', 1)],
        ),
      );
      final survivable = outcome.waypoints.map((w) => w.survivable).toList();
      expect(survivable.first, isTrue);
      expect(survivable.last, isFalse);
      expect(outcome.abandonmentIndex, survivable.lastIndexOf(true));
      expect(outcome.constraint!.waypointIndex, survivable.indexOf(false));
    });

    test('the swim needs more than the tow, so the tow is the reported best exit', () {
      final outcome = engine.compute(
        plan: _plan(tankLiters: 40, startBar: 230),
        mission: DpvMission(
          legs: [_leg('L1', 0)],
          team: [_member('a', 0), _member('b', 1)],
        ),
      );
      final b = outcome.waypoints.single.members.firstWhere((m) => m.memberId == 'b');
      expect(b.tow!.towerId, 'a');
      expect(b.tow!.exitSeconds, lessThan(b.swim.exitSeconds));
      expect(b.gasRemainingBar, lessThan(230));
    });

    test('the constraint names the battery-limited member, not the slowest or thirstiest', () {
      final outcome = engine.compute(
        plan: _plan(tankLiters: 40, startBar: 230),
        mission: DpvMission(
          legs: [_leg('L1', 0, distance: 400, depth: 15), _leg('L2', 1, distance: 400, depth: 15)],
          team: [
            _member('a', 0, sac: 25, speed: 0.9),
            _member('b', 1, speed: 0.7, burn: 2400),
            _member('c', 2, speed: 0.4),
          ],
        ),
      );
      expect(outcome.cruiseSpeedMps, 0.4);
      expect(outcome.members.firstWhere((m) => m.memberId == 'c').setsCruiseSpeed, isTrue);
      expect(outcome.constraint, const MissionConstraint(
        memberId: 'b',
        factor: MissionBindingFactor.battery,
        waypointIndex: 0,
      ));
      final b = outcome.members.firstWhere((m) => m.memberId == 'b');
      expect(b.batteryRoundTripFraction, greaterThan(2 / 3));
      // a has the highest SAC and does bind, on own gas at the second
      // waypoint, but b's battery binds first.
      final a = outcome.members.firstWhere((m) => m.memberId == 'a');
      expect(a.bindingWaypointIndex ?? 99, greaterThan(0));
    });
  });
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/features/planner/mission/mission_engine_test.dart`
Expected: FAIL, import does not resolve.

- [ ] **Step 3: Write the engine**

```dart
// lib/features/planner/domain/services/mission/mission_engine.dart
import 'dart:math' as math;

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/deco/entities/dive_environment.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    as domain;
import 'package:submersion/features/planner/domain/entities/mission/dpv_mission.dart';
import 'package:submersion/features/planner/domain/entities/mission/mission_leg.dart';
import 'package:submersion/features/planner/domain/entities/mission/mission_member.dart';
import 'package:submersion/features/planner/domain/entities/mission/mission_outcome.dart';
import 'package:submersion/features/planner/domain/entities/plan_outcome.dart';
import 'package:submersion/features/planner/domain/services/mission/battery_burn_service.dart';
import 'package:submersion/features/planner/domain/services/mission/leg_speed_resolver.dart';
import 'package:submersion/features/planner/domain/services/mission/member_gas_service.dart';
import 'package:submersion/features/planner/domain/services/mission/mission_scenario_service.dart';
import 'package:submersion/features/planner/domain/services/mission/mission_segment_builder.dart';
import 'package:submersion/features/planner/domain/services/mission/mission_team.dart';

/// Computes a DPV mission: the round-trip segments, per-leg speeds, every
/// scooter failure at every waypoint, the abandonment point and the member
/// and factor that constrain the mission.
class MissionEngine {
  final MissionScenarioService scenarios;
  final MissionSegmentBuilder builder;
  final BatteryBurnService battery;
  final LegSpeedResolver speeds;
  final MemberGasService gas;

  const MissionEngine({
    this.scenarios = const MissionScenarioService(),
    this.builder = const MissionSegmentBuilder(),
    this.battery = const BatteryBurnService(),
    this.speeds = const LegSpeedResolver(),
    this.gas = const MemberGasService(),
  });

  MissionOutcome compute({
    required domain.DivePlan plan,
    required DpvMission mission,
  }) {
    final issues = _validate(mission);
    if (issues.any((i) => i.severity == MissionIssueSeverity.blocking)) {
      return MissionOutcome.empty(issues: issues);
    }

    final team = mission.team;
    final cruise = cruiseSpeedMps(team);
    final limitingId = cruiseLimitingMemberId(team);

    // Resolve every leg at cruise and cut the route at the first one the
    // current makes untraversable in either direction.
    final legSpeeds = <LegSpeeds>[];
    for (final leg in mission.legs) {
      final resolved = speeds.resolve(
        leg: leg,
        current: mission.currentFor(leg),
        baseSpeedMps: cruise,
      );
      if (!resolved.traversable) {
        issues.add(
          MissionIssue(
            type: MissionIssueType.untraversableLeg,
            severity: MissionIssueSeverity.blocking,
            legId: leg.id,
            outbound: !resolved.outboundTraversable,
          ),
        );
        break;
      }
      legSpeeds.add(resolved);
    }
    if (legSpeeds.isEmpty) return MissionOutcome.empty(issues: issues);
    final legs = mission.legs.sublist(0, legSpeeds.length);
    final route = mission.copyWith(legs: legs);

    final profile = builder.build(
      plan: plan,
      mission: route,
      throughLegIndex: legs.length - 1,
      outboundSpeedMps: cruise,
      exitSpeedMps: cruise,
    );
    if (profile.segments.isEmpty) return MissionOutcome.empty(issues: issues);

    final legOutcomes = _legOutcomes(legs, legSpeeds, profile);
    final roundTripSeconds = profile.segments.fold(
      0,
      (sum, s) => sum + s.durationSeconds,
    );
    final returnSecondsFrom = _returnSecondsFrom(legs, profile);
    final roundTripOutcome = scenarios.engine.compute(
      plan.copyWith(segments: profile.segments),
    );
    final environment = _environmentFor(plan);
    final bottomTank = plan.tanks.firstWhere(
      (t) => t.id == profile.segments.first.tankId,
    );

    final waypoints = <WaypointOutcome>[];
    var cumulative = 0.0;
    for (var k = 0; k < legs.length; k++) {
      cumulative += legs[k].distanceM;
      final arrival = profile.waypointArrivalSeconds[k];
      final outboundRows = roundTripOutcome.schedule
          .where((r) => r.runtimeSeconds <= arrival)
          .toList();
      final members = <MemberWaypointOutcome>[];
      for (final member in team) {
        final swim = _evaluate(
          plan: plan,
          mission: route,
          k: k,
          member: member,
          mode: MissionExitMode.swim,
          issues: issues,
        );
        ExitOutcome? best;
        for (final tower in team) {
          if (tower.id == member.id) continue;
          final tow = _evaluate(
            plan: plan,
            mission: route,
            k: k,
            member: member,
            mode: MissionExitMode.tow,
            towerId: tower.id,
            issues: issues,
          );
          best = _betterTow(best, tow);
        }
        final outboundLiters = gas.litersByTank(
          rows: outboundRows,
          environment: environment,
          sacFor: (_) => member.sacBottom,
        );
        members.add(
          MemberWaypointOutcome(
            memberId: member.id,
            gasRemainingBar: gas.remainingBar(
              tank: bottomTank,
              litersUsed: outboundLiters[bottomTank.id] ?? 0.0,
              model: scenarios.engine.config.gasModel,
            ),
            swim: swim,
            tow: best,
            survivable: swim.feasible || (best?.feasible ?? false),
          ),
        );
      }
      waypoints.add(
        WaypointOutcome(
          index: k,
          legId: legs[k].id,
          cumulativeDistanceM: cumulative,
          arrivalRuntimeSeconds: arrival,
          members: members,
          survivable: members.every((m) => m.survivable),
        ),
      );
    }

    int? abandonment;
    for (var k = 0; k < waypoints.length; k++) {
      if (!waypoints[k].survivable) break;
      abandonment = k;
    }

    final memberOutcomes = [
      for (final member in team)
        _memberOutcome(
          member: member,
          mission: route,
          waypoints: waypoints,
          abandonment: abandonment,
          roundTripSeconds: roundTripSeconds,
          returnSecondsFrom: returnSecondsFrom,
          setsCruise: member.id == limitingId,
          bottomTank: bottomTank,
          reserveBar: plan.reservePressure,
        ),
    ];

    return MissionOutcome(
      segments: profile.segments,
      cruiseSpeedMps: cruise,
      legs: legOutcomes,
      waypoints: waypoints,
      members: memberOutcomes,
      abandonmentIndex: abandonment,
      constraint: _constraint(memberOutcomes),
      issues: issues,
    );
  }

  List<MissionIssue> _validate(DpvMission mission) {
    final issues = <MissionIssue>[];
    if (mission.team.isEmpty) {
      issues.add(
        const MissionIssue(
          type: MissionIssueType.emptyTeam,
          severity: MissionIssueSeverity.blocking,
        ),
      );
    }
    if (mission.legs.isEmpty) {
      issues.add(
        const MissionIssue(
          type: MissionIssueType.emptyRoute,
          severity: MissionIssueSeverity.blocking,
        ),
      );
    }
    for (final member in mission.team) {
      if (member.scooter.ratedSpeedMps <= 0 ||
          member.scooter.burnTimeSeconds <= 0) {
        issues.add(
          MissionIssue(
            type: MissionIssueType.scooterUnspecified,
            severity: MissionIssueSeverity.blocking,
            memberId: member.id,
          ),
        );
      }
      if (member.sacBottom <= 0) {
        issues.add(
          MissionIssue(
            type: MissionIssueType.memberSacUnset,
            severity: MissionIssueSeverity.blocking,
            memberId: member.id,
          ),
        );
      }
    }
    return issues;
  }

  List<LegOutcome> _legOutcomes(
    List<MissionLeg> legs,
    List<LegSpeeds> legSpeeds,
    MissionProfile profile,
  ) {
    int seconds(String id) => profile.segments
        .firstWhere((s) => s.id == id)
        .durationSeconds;
    return [
      for (var i = 0; i < legs.length; i++)
        LegOutcome(
          legId: legs[i].id,
          outboundSpeedMps: legSpeeds[i].outboundMps,
          returnSpeedMps: legSpeeds[i].returnMps,
          outboundSeconds: seconds('mission-out-${legs[i].id}'),
          returnSeconds: seconds('mission-ret-${legs[i].id}'),
        ),
    ];
  }

  /// Seconds of the cruise-speed return from each waypoint k back to the
  /// start: the return hold and travel segments of legs 0 through k.
  List<int> _returnSecondsFrom(List<MissionLeg> legs, MissionProfile profile) {
    return [
      for (var k = 0; k < legs.length; k++)
        profile.segments
            .where((s) {
              if (!s.id.startsWith('mission-ret-')) return false;
              for (var i = 0; i <= k; i++) {
                if (s.id == 'mission-ret-${legs[i].id}' ||
                    s.id == 'mission-ret-travel-${legs[i].id}') {
                  return true;
                }
              }
              return false;
            })
            .fold(0, (sum, s) => sum + s.durationSeconds),
    ];
  }

  ExitOutcome _evaluate({
    required domain.DivePlan plan,
    required DpvMission mission,
    required int k,
    required MissionMember member,
    required MissionExitMode mode,
    String? towerId,
    required List<MissionIssue> issues,
  }) {
    try {
      return scenarios.evaluate(
        plan: plan,
        mission: mission,
        waypointIndex: k,
        failedMemberId: member.id,
        mode: mode,
        towerId: towerId,
      );
    } on Object {
      // One scenario the engine cannot schedule must not hide the others;
      // report it and treat the exit as unavailable.
      issues.add(
        MissionIssue(
          type: MissionIssueType.scenarioFailed,
          severity: MissionIssueSeverity.warning,
          legId: mission.legs[k].id,
          memberId: member.id,
        ),
      );
      return ExitOutcome(
        mode: mode,
        towerId: towerId,
        feasible: false,
        exitBottomSeconds: 0,
        ttsSeconds: 0,
        exitLitersByMember: const {},
      );
    }
  }

  /// Prefers a feasible tow, then the quicker one.
  ExitOutcome _betterTow(ExitOutcome? current, ExitOutcome candidate) {
    if (current == null) return candidate;
    if (candidate.feasible != current.feasible) {
      return candidate.feasible ? candidate : current;
    }
    return candidate.exitSeconds < current.exitSeconds ? candidate : current;
  }

  MemberOutcome _memberOutcome({
    required MissionMember member,
    required DpvMission mission,
    required List<WaypointOutcome> waypoints,
    required int? abandonment,
    required int roundTripSeconds,
    required List<int> returnSecondsFrom,
    required bool setsCruise,
    required DiveTank bottomTank,
    required double reserveBar,
  }) {
    MissionBindingFactor? factor;
    int? bindingIndex;
    for (var k = 0; k < waypoints.length; k++) {
      final own = waypoints[k].members.firstWhere(
        (m) => m.memberId == member.id,
      );
      final roundTrip = battery.burnFraction(
        scooter: member.scooter,
        poweredSeconds:
            waypoints[k].arrivalRuntimeSeconds + returnSecondsFrom[k],
      );
      if (!battery.withinReserve(
        burnFraction: roundTrip,
        reserveFraction: mission.batteryReserveFraction,
      )) {
        factor = MissionBindingFactor.battery;
      } else if (!own.survivable) {
        // A swim burns no battery, so it fails only on gas or on a current
        // it cannot beat; that makes it the clean witness for why.
        final swimShort = own.swim.gasShortfallMemberIds;
        if (swimShort.contains(member.id)) {
          factor = MissionBindingFactor.ownGas;
        } else if (swimShort.isNotEmpty) {
          factor = MissionBindingFactor.swimGas;
        } else {
          factor = MissionBindingFactor.noFeasibleTow;
        }
      }
      if (factor != null) {
        bindingIndex = k;
        break;
      }
    }

    double? turnPressure;
    if (abandonment != null) {
      // The worst feasible exit at the abandonment point, over every failure
      // (anyone's scooter) and both modes. Total exit litres are charged to
      // the bottom tank: deco litres really come off a deco cylinder when
      // one is carried, so this errs on the safe side.
      var worstLiters = 0.0;
      for (final other in waypoints[abandonment].members) {
        for (final exit in [other.swim, other.tow]) {
          if (exit == null || !exit.feasible) continue;
          worstLiters = math.max(
            worstLiters,
            exit.exitLitersByMember[member.id] ?? 0.0,
          );
        }
      }
      final start = bottomTank.startPressure;
      final after = gas.remainingBar(
        tank: bottomTank,
        litersUsed: worstLiters,
        model: scenarios.engine.config.gasModel,
      );
      if (start != null && after != null) {
        turnPressure = (start - after) + reserveBar;
      }
    }

    return MemberOutcome(
      memberId: member.id,
      batteryRoundTripFraction: battery.burnFraction(
        scooter: member.scooter,
        poweredSeconds: roundTripSeconds,
      ),
      setsCruiseSpeed: setsCruise,
      bindingFactor: factor,
      bindingWaypointIndex: bindingIndex,
      turnPressureBar: turnPressure,
    );
  }

  MissionConstraint? _constraint(List<MemberOutcome> members) {
    MemberOutcome? binding;
    for (final member in members) {
      final index = member.bindingWaypointIndex;
      if (index == null) continue;
      if (binding == null) {
        binding = member;
        continue;
      }
      final current = binding.bindingWaypointIndex!;
      if (index < current) {
        binding = member;
      } else if (index == current &&
          member.bindingFactor!.index < binding.bindingFactor!.index) {
        binding = member;
      }
    }
    if (binding == null) return null;
    return MissionConstraint(
      memberId: binding.memberId,
      factor: binding.bindingFactor!,
      waypointIndex: binding.bindingWaypointIndex!,
    );
  }

  static DiveEnvironment _environmentFor(domain.DivePlan plan) {
    return DiveEnvironment.forConditions(
      altitudeMeters: (plan.altitude ?? 0) > 0 ? plan.altitude : null,
      waterType: plan.waterType ?? WaterType.salt,
      salinityPpt: plan.salinityPpt,
    );
  }
}
```

If `lib/features/planner/domain/services/mission/mission_engine.dart` passes 400 lines after formatting, move `_memberOutcome`, `_constraint` and `_returnSecondsFrom` into a sibling file `mission_member_analysis.dart` as a `MissionMemberAnalysis` class with the same signatures, injected into the engine; keep both files under 400 lines.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/features/planner/mission/mission_engine_test.dart`
Expected: PASS, 11 tests. If the abandonment test's expectations on the 24 L tank are off (all three waypoints survivable, or none), adjust `tankLiters` in that test only, keeping the shape "first survivable, last not", and note the value used in the commit body. Do not weaken the constraint test: its numbers are hand-derived above.

- [ ] **Step 5: Format and commit**

```bash
dart format lib/features/planner/domain/services/mission test/features/planner/mission
git add lib/features/planner/domain/services/mission test/features/planner/mission/mission_engine_test.dart
git commit -m "feat(planner): add the DPV mission engine

Refs #2086"
```

---

### Task 12: Whole-project verification

**Files:**
- None created. Verifies everything above.

- [ ] **Step 1: Format the whole project and check nothing changed**

```bash
dart format . && git status --short
```

Expected: no modified files listed. If any are, review the diff, then commit them with `style(planner): format` and `Refs #2086`.

- [ ] **Step 2: Analyze the whole project**

```bash
flutter analyze
```

Expected: `No issues found!`. Infos count as failures in CI; fix every one.

- [ ] **Step 3: Run the new test directory and the neighbouring suites**

```bash
flutter test test/features/planner/mission/
```

Expected: all pass. Then, one file at a time, the suites touched by the `DivePlan` and catalog edits:

```bash
flutter test test/features/planner/dive_plan_entity_test.dart test/features/planner/plan_file_codec_test.dart test/features/planner/dive_plan_repository_test.dart test/features/equipment/domain/constants/ test/core/services/export/csv/codec/csv_attribute_codec_test.dart
```

Expected: all pass. The CSV attribute codec test may enumerate the catalog; if it asserts a fixed count of DPV attributes, update that count to include the two tow factors.

- [ ] **Step 4: Run the architecture guards**

```bash
flutter test test/architecture/
```

Expected: all pass. These scan every file under `lib/`, and affected-directory runs never include them.

- [ ] **Step 5: Confirm the l10n output is current**

```bash
flutter gen-l10n && git status --short lib/l10n
```

Expected: no changes listed (the generated files were committed in Task 3).

- [ ] **Step 6: Review the branch**

```bash
git log --oneline origin/main..HEAD
git diff --stat origin/main..HEAD
```

Expected: the spec commit plus eleven feature commits; no file outside `docs/`, `lib/features/planner`, `lib/features/equipment`, `lib/l10n`, and `test/` in the diff.

---

## Amendments (2026-09-18, before execution)

- Test fixtures re-derived by hand: Task 10 uses a 300 m leg, Task 11's generous and abandonment cases use 200 m legs. The original distances made the feasible cases infeasible on gas.
- Task 11's constraint test no longer asserts that member a never binds; a binds on own gas at the second waypoint, after b's battery.
- Exits can be blocked by a current the scooters beat at cruise. `ExitOutcome.blockedByCurrent`, a traversability check in `MissionScenarioService`, a refusal of non-positive speeds in `MissionSegmentBuilder`, and a binding rule keyed on the swim exit handle it.

Deviations made during execution:

- Task 7: `MissionSegmentBuilder` picks the bottom tank as the first cylinder declared back gas, else the first cylinder. `TankRoleResolver` derives the bottom tank from the plan's segments, which are the segments being generated, so on a fresh mission it picked a deco bottle listed first. The builder no longer depends on the resolver.
- Task 11: the engine came to 443 lines, so `returnSecondsFrom`, `memberOutcome` and `constraint` moved to `mission_member_analysis.dart` (`MissionMemberAnalysis`, injected, gas model passed in). The engine's unused battery field went with them, and the engine reuses `MissionScenarioService.environmentFor` instead of a private copy.
- Task 12: `test/features/equipment/domain/equipment_attribute_catalog_test.dart` pins the ordered DPV key list; it now includes the two tow factors after `speed_mps`.

## Self-review

**Spec coverage.** Domain model: Tasks 1, 2, 5 (all fields in the spec tables are present; `MissionLeg.returnHeadingDeg` is an added convenience). Scooter snapshot and overlay: Task 4. Catalog attributes and typed getters: Task 3. Current resolution and cruise speed: Task 6. Segment builder with explicit travel segments and mirrored return: Task 7. Battery with reserve and tow factor: Task 8. Per-member gas from schedule rows with mean-depth travel: Task 9. Scenarios through `PlanEngine`, swim and tow, tower selection, stressed SAC for the failed member, gas and battery feasibility: Task 10. Outcome with legs, waypoints, abandonment, binding factors, constraint, turn pressure, issues, and the error handling for untraversable legs and throwing scenarios: Task 11. Persistence, state mapper, codec, UI, l10n for UI strings and the PDF slate are PR 2 and PR 3 by the spec's delivery section and are not in this plan.

**Type consistency.** `ExitOutcome.exitLitersByMember` (Task 5) is what Task 10 fills and Task 11 reads. `MissionProfile.waypointArrivalSeconds` (Task 7) is read in Tasks 10 and 11. `LegSpeeds.outboundTraversable` (Task 6) is read in Task 11. `MissionScenarioService.engine` is a public final field so Task 11 can reuse the same `PlanEngine` and its `config.gasModel`. `slowestSwimSpeedMps` and `cruiseSpeedMps` are the top-level functions of Task 6 used in Tasks 10 and 11.

**Known judgement calls recorded in code comments.** Burn at the rated rate when cruising slower (Task 8). Total exit litres charged to the bottom tank for the turn pressure (Task 11). A hold segment for a leg is preceded by an explicit travel segment because the chain would otherwise integrate the whole hold as a slow descent (Task 7).
