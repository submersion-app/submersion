# DPV Mission Planner, PR 1 revision (open water, solo divers, speed over ground) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Revise PR #2138's domain layer to the 2026-09-25 spec: correct speed over ground for cross currents, add the open-water environment (straight-line and surface exits, hand-entered shore exits with a walk), make solo divers first-class, split the binding reasons, report time to the next safe surface, and move exit evaluation into a scooter-free service.

**Architecture:** `LegSpeedResolver` gains a heading-based resolver that accounts for the cross-track share of a current. A new geometry helper dead-reckons waypoint positions and produces the exit legs for each environment (retrace in an overhead, one straight leg home in open water). `MissionSegmentBuilder` splits into `outbound` and `appendExitLegs`. A new `ExitPathEvaluator` runs an exit through `PlanEngine` and charges each diver's gas, with no scooter concept; `MissionScenarioService` composes it with battery accounting and adds the surface exit. The engine and member analysis consume the new results.

**Tech Stack:** Flutter, Dart 3 (records, pattern matching), `equatable`, `flutter_test`. No UI, no schema, no persistence.

**Spec:** `docs/superpowers/specs/2026-09-18-dpv-mission-planner-design.md`, sections "Domain model", "Calculation" and "Revision 2026-09-25". Branch `ericgriffin/dpv-mission-planner-a7b686` (PR #2138).

## Global Constraints

- No em-dashes (U+2014), en-dashes as punctuation, or double hyphens as punctuation anywhere: code, comments, tests, commit messages.
- No mention of Claude, Claude Code or Anthropic in any file, commit message or PR text. No co-author trailers.
- No emojis in code, comments or docs.
- Immutability: build new lists; entities are `Equatable` with `const` constructors and `copyWith`.
- Files under 400 lines; `mission_engine.dart` may reach 400.
- Imports grouped dart, flutter, packages, local; absolute `package:submersion/...` imports.
- SI units throughout: metres, seconds, m/s, litres, bar, degrees.
- `dart format .` before every commit; `flutter analyze` on the whole project before the final commit (infos fail CI).
- Run tests one file or a short list at a time; never overlap two local test runs.
- Commit messages: conventional prefix, body line `Refs #2086`.
- Speed over ground: `a + sqrt(v^2 - x^2)` with along-track share `a = c * cos(d - h)` and cross-track share `x = c * sin(d - h)`; the track cannot be held when `|x| >= v`.
- Default walk speed 0.8 m/s. Surface swimming is not charged gas. A surface swim ignores current.

## Review Focus

1. A cross current exactly as fast as the diver (`|x| == v`): the track is blocked and no speed is NaN. Test in Task 1.
2. Headings outside 0 to 360 (450, -90): behave like their normalised twins, and a bearing home is always in [0, 360). Tests in Tasks 1 and 3.
3. A route that ends back at the entry in open water: no exit leg, no surface swim, no crash. Tests in Tasks 3 and 6.
4. A shore exit with a walk but a walking speed of zero: the shore route is dropped, never divided by zero. Test in Task 6.
5. A member whose swim speed is zero: a blocking validation issue, not an infinite exit time or a thrown error. Test in Task 7.

---

## File Structure

| File | Status | Responsibility |
| --- | --- | --- |
| `lib/features/planner/domain/entities/mission/current_vector.dart` | modify | add `crossTrackComponent` |
| `lib/features/planner/domain/services/mission/leg_speed_resolver.dart` | modify | speed over ground, `resolveHeading` |
| `lib/features/planner/domain/entities/mission/shore_exit.dart` | create | `ShoreExit` |
| `lib/features/planner/domain/entities/mission/mission_leg.dart` | modify | `shoreExit` |
| `lib/features/planner/domain/entities/mission/dpv_mission.dart` | modify | `MissionEnvironment`, `walkSpeedMps`, `surfaceSwimLimitM` |
| `lib/features/planner/domain/entities/mission/exit_leg.dart` | create | `ExitLeg` |
| `lib/features/planner/domain/services/mission/mission_geometry.dart` | create | positions, bearing home, exit legs per environment |
| `lib/features/planner/domain/services/mission/mission_segment_builder.dart` | rewrite | `outbound`, `appendExitLegs`, `build` |
| `lib/features/planner/domain/entities/mission/mission_outcome.dart` | modify | exit mode, binding factors, surface fields, waypoint fields |
| `lib/features/planner/domain/services/mission/exit_path_evaluator.dart` | create | scooter-free exit evaluation |
| `lib/features/planner/domain/services/mission/mission_scenario_service.dart` | rewrite | swim and tow via the evaluator, surface exit, overhead safe surface |
| `lib/features/planner/domain/services/mission/mission_engine.dart` | modify | positions, surface exit, safe surface, swim speed validation |
| `lib/features/planner/domain/services/mission/mission_member_analysis.dart` | modify | binding reasons, surface in turn pressure |

---

### Task 1: Speed over ground

**Files:**
- Modify: `lib/features/planner/domain/entities/mission/current_vector.dart`
- Modify: `lib/features/planner/domain/services/mission/leg_speed_resolver.dart`
- Test: `test/features/planner/mission/speed_over_ground_test.dart`

**Interfaces:**
- Produces: `double CurrentVector.crossTrackComponent(double headingDeg)`; `LegSpeeds LegSpeedResolver.resolveHeading({required double headingDeg, required CurrentVector? current, required double baseSpeedMps})`. `resolve` keeps its signature and delegates.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/planner/mission/speed_over_ground_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/planner/domain/entities/mission/current_vector.dart';
import 'package:submersion/features/planner/domain/entities/mission/mission_leg.dart';
import 'package:submersion/features/planner/domain/services/mission/leg_speed_resolver.dart';

void main() {
  const resolver = LegSpeedResolver();

  group('CurrentVector.crossTrackComponent', () {
    test('a current square to the heading is all cross track', () {
      const current = CurrentVector(speedMps: 0.3, setsTowardDeg: 90);
      expect(current.crossTrackComponent(0), closeTo(0.3, 1e-12));
      expect(current.alongRouteComponent(0), closeTo(0, 1e-12));
    });

    test('the cross share keeps its size on the reversed heading', () {
      const current = CurrentVector(speedMps: 0.2, setsTowardDeg: 45);
      expect(
        current.crossTrackComponent(180).abs(),
        closeTo(current.crossTrackComponent(0).abs(), 1e-12),
      );
    });
  });

  group('speed over ground', () {
    test('a pure cross current costs speed both ways', () {
      // sqrt(0.5^2 - 0.3^2) = 0.4
      final speeds = resolver.resolveHeading(
        headingDeg: 0,
        current: const CurrentVector(speedMps: 0.3, setsTowardDeg: 90),
        baseSpeedMps: 0.5,
      );
      expect(speeds.outboundMps, closeTo(0.4, 1e-9));
      expect(speeds.returnMps, closeTo(0.4, 1e-9));
    });

    test('a quartering current helps out, hurts back, and costs across', () {
      // a = x = 0.2 * cos 45 = 0.141421; sqrt(0.25 - 0.02) = 0.479583
      final speeds = resolver.resolveHeading(
        headingDeg: 0,
        current: const CurrentVector(speedMps: 0.2, setsTowardDeg: 45),
        baseSpeedMps: 0.5,
      );
      expect(speeds.outboundMps, closeTo(0.479583 + 0.141421, 1e-6));
      expect(speeds.returnMps, closeTo(0.479583 - 0.141421, 1e-6));
    });

    test('a cross current as fast as the diver cannot be held', () {
      final speeds = resolver.resolveHeading(
        headingDeg: 0,
        current: const CurrentVector(speedMps: 0.5, setsTowardDeg: 90),
        baseSpeedMps: 0.5,
      );
      expect(speeds.outboundMps.isNaN, isFalse);
      expect(speeds.returnMps.isNaN, isFalse);
      expect(speeds.outboundMps, 0);
      expect(speeds.returnMps, 0);
      expect(speeds.traversable, isFalse);
    });

    test('a cross current can block a swimmer but not a scooter', () {
      const current = CurrentVector(speedMps: 0.3, setsTowardDeg: 90);
      expect(
        resolver
            .resolveHeading(headingDeg: 0, current: current, baseSpeedMps: 0.2)
            .traversable,
        isFalse,
      );
      expect(
        resolver
            .resolveHeading(headingDeg: 0, current: current, baseSpeedMps: 0.9)
            .traversable,
        isTrue,
      );
    });

    test('headings outside 0 to 360 behave like their normalised twin', () {
      const current = CurrentVector(speedMps: 0.2, setsTowardDeg: 45);
      LegSpeeds at(double heading) => resolver.resolveHeading(
        headingDeg: heading,
        current: current,
        baseSpeedMps: 0.5,
      );
      expect(at(450).outboundMps, closeTo(at(90).outboundMps, 1e-12));
      expect(at(-90).returnMps, closeTo(at(270).returnMps, 1e-12));
    });

    test('resolve on a leg is resolveHeading on its heading', () {
      const leg = MissionLeg(
        id: 'L1',
        order: 0,
        label: 'T',
        distanceM: 300,
        depthM: 20,
        headingDeg: 30,
      );
      const current = CurrentVector(speedMps: 0.2, setsTowardDeg: 100);
      expect(
        resolver.resolve(leg: leg, current: current, baseSpeedMps: 0.6),
        resolver.resolveHeading(
          headingDeg: 30,
          current: current,
          baseSpeedMps: 0.6,
        ),
      );
    });
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/features/planner/mission/speed_over_ground_test.dart`
Expected: FAIL, "The method 'crossTrackComponent' isn't defined" and "The method 'resolveHeading' isn't defined".

- [ ] **Step 3: Implement**

In `current_vector.dart`, after `alongRouteComponent`:

```dart
  /// The component of this current across a leg travelled on [headingDeg],
  /// in m/s; positive sets the diver to the right of the track. A diver
  /// holding the track angles into it, which costs speed over the ground.
  double crossTrackComponent(double headingDeg) {
    final radians = (setsTowardDeg - headingDeg) * math.pi / 180.0;
    return speedMps * math.sin(radians);
  }
```

Replace the whole of `leg_speed_resolver.dart` with:

```dart
// lib/features/planner/domain/services/mission/leg_speed_resolver.dart
import 'dart:math' as math;

import 'package:equatable/equatable.dart';

import 'package:submersion/features/planner/domain/entities/mission/current_vector.dart';
import 'package:submersion/features/planner/domain/entities/mission/mission_leg.dart';

/// Speed over the ground along a track in each direction, in m/s.
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

/// Applies a current to a speed through the water.
///
/// A diver holding a straight track angles into the cross-track share of
/// the current, so their speed over the ground is the along-track share
/// plus `sqrt(v^2 - x^2)`. The return flips the along-track share and keeps
/// the cross share. A cross current as fast as the diver cannot be held at
/// all, and a direction whose speed over the ground is not positive cannot
/// be travelled.
class LegSpeedResolver {
  const LegSpeedResolver();

  LegSpeeds resolve({
    required MissionLeg leg,
    required CurrentVector? current,
    required double baseSpeedMps,
  }) {
    return resolveHeading(
      headingDeg: leg.headingDeg,
      current: current,
      baseSpeedMps: baseSpeedMps,
    );
  }

  LegSpeeds resolveHeading({
    required double headingDeg,
    required CurrentVector? current,
    required double baseSpeedMps,
  }) {
    final along = current?.alongRouteComponent(headingDeg) ?? 0.0;
    final cross = current?.crossTrackComponent(headingDeg) ?? 0.0;
    if (cross.abs() >= baseSpeedMps) {
      return const LegSpeeds(outboundMps: 0, returnMps: 0);
    }
    final made = math.sqrt(baseSpeedMps * baseSpeedMps - cross * cross);
    return LegSpeeds(outboundMps: made + along, returnMps: made - along);
  }
}
```

(Remove the `// lib/...` path comment line when writing the file.)

- [ ] **Step 4: Run the new test and every existing mission test**

```bash
flutter test test/features/planner/mission/speed_over_ground_test.dart test/features/planner/mission/leg_speed_resolver_test.dart test/features/planner/mission/mission_segment_builder_test.dart test/features/planner/mission/mission_engine_test.dart
```

Expected: PASS. The existing tests use only along-track currents, whose cross share is zero to floating precision, so their vectors are unchanged.

- [ ] **Step 5: Format and commit**

```bash
dart format lib/features/planner/domain test/features/planner/mission
git add lib/features/planner/domain/entities/mission/current_vector.dart lib/features/planner/domain/services/mission/leg_speed_resolver.dart test/features/planner/mission/speed_over_ground_test.dart
git commit -m "fix(planner): account for cross currents in DPV speed over ground

Refs #2086"
```

---

### Task 2: Open-water fields on the mission and its legs

**Files:**
- Create: `lib/features/planner/domain/entities/mission/shore_exit.dart`
- Modify: `lib/features/planner/domain/entities/mission/mission_leg.dart`
- Modify: `lib/features/planner/domain/entities/mission/dpv_mission.dart`
- Test: `test/features/planner/mission/mission_open_water_entities_test.dart`

**Interfaces:**
- Produces: `ShoreExit({required double surfaceSwimM, required double walkM})`; `MissionLeg.shoreExit` (`ShoreExit?`), `copyWith({ShoreExit? shoreExit, bool clearShoreExit = false})`; `enum MissionEnvironment { overhead, openWater }`; `const double kDefaultWalkSpeedMps = 0.8`; `DpvMission.environment`, `DpvMission.walkSpeedMps`, `DpvMission.surfaceSwimLimitM`, `copyWith({MissionEnvironment? environment, double? walkSpeedMps, double? surfaceSwimLimitM, bool clearSurfaceSwimLimit = false})`.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/planner/mission/mission_open_water_entities_test.dart
// Instances here are deliberately non-const: const instances canonicalise to
// a single instance, so == short-circuits on identity and the Equatable props
// under test are never evaluated.
// ignore_for_file: prefer_const_constructors

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/planner/domain/entities/mission/dpv_mission.dart';
import 'package:submersion/features/planner/domain/entities/mission/mission_leg.dart';
import 'package:submersion/features/planner/domain/entities/mission/shore_exit.dart';

MissionLeg _leg() => MissionLeg(
  id: 'L1',
  order: 0,
  label: 'T',
  distanceM: 300,
  depthM: 20,
  headingDeg: 90,
);

void main() {
  test('a mission defaults to overhead, a 0.8 m/s walk and no swim limit', () {
    final mission = DpvMission();
    expect(mission.environment, MissionEnvironment.overhead);
    expect(mission.walkSpeedMps, 0.8);
    expect(kDefaultWalkSpeedMps, 0.8);
    expect(mission.surfaceSwimLimitM, isNull);
  });

  test('copyWith sets the open-water fields and clears the limit', () {
    final mission = DpvMission().copyWith(
      environment: MissionEnvironment.openWater,
      walkSpeedMps: 1.1,
      surfaceSwimLimitM: 250,
    );
    expect(mission.environment, MissionEnvironment.openWater);
    expect(mission.walkSpeedMps, 1.1);
    expect(mission.surfaceSwimLimitM, 250);
    expect(mission.copyWith().surfaceSwimLimitM, 250);
    expect(
      mission.copyWith(clearSurfaceSwimLimit: true).surfaceSwimLimitM,
      isNull,
    );
  });

  test('the open-water fields take part in equality', () {
    expect(
      DpvMission(environment: MissionEnvironment.openWater),
      isNot(DpvMission()),
    );
    expect(DpvMission(walkSpeedMps: 1.0), isNot(DpvMission()));
    expect(DpvMission(surfaceSwimLimitM: 100), isNot(DpvMission()));
    expect(DpvMission(surfaceSwimLimitM: 100), DpvMission(surfaceSwimLimitM: 100));
  });

  test('a shore exit copies and compares by value', () {
    final shore = ShoreExit(surfaceSwimM: 120, walkM: 400);
    expect(shore, ShoreExit(surfaceSwimM: 120, walkM: 400));
    expect(shore.copyWith(walkM: 50), ShoreExit(surfaceSwimM: 120, walkM: 50));
    expect(
      shore.copyWith(surfaceSwimM: 10),
      ShoreExit(surfaceSwimM: 10, walkM: 400),
    );
    expect(shore.copyWith().hashCode, shore.hashCode);
  });

  test('a leg gains and loses a shore exit', () {
    final withShore = _leg().copyWith(
      shoreExit: ShoreExit(surfaceSwimM: 120, walkM: 400),
    );
    expect(withShore.shoreExit, ShoreExit(surfaceSwimM: 120, walkM: 400));
    expect(withShore, isNot(_leg()));
    expect(withShore.copyWith(label: 'X').shoreExit, isNotNull);
    expect(withShore.copyWith(clearShoreExit: true).shoreExit, isNull);
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/features/planner/mission/mission_open_water_entities_test.dart`
Expected: FAIL, `shore_exit.dart` does not exist.

- [ ] **Step 3: Implement**

Create `shore_exit.dart`:

```dart
// lib/features/planner/domain/entities/mission/shore_exit.dart
import 'package:equatable/equatable.dart';

/// The nearest way onto land from a waypoint, entered by hand (issue
/// #2086): a surface swim to the shore, then a walk back to the entry.
/// Nothing here is derived from a map.
class ShoreExit extends Equatable {
  /// Surface swim from the waypoint to the shore, in metres.
  final double surfaceSwimM;

  /// Walk from where the diver lands back to the entry, in metres.
  final double walkM;

  const ShoreExit({required this.surfaceSwimM, required this.walkM});

  ShoreExit copyWith({double? surfaceSwimM, double? walkM}) {
    return ShoreExit(
      surfaceSwimM: surfaceSwimM ?? this.surfaceSwimM,
      walkM: walkM ?? this.walkM,
    );
  }

  @override
  List<Object?> get props => [surfaceSwimM, walkM];
}
```

In `mission_leg.dart`:

- Add the import after the `current_vector.dart` import: `import 'package:submersion/features/planner/domain/entities/mission/shore_exit.dart';`
- After the `current` field:

```dart

  /// Open water only: the nearest way onto land from this leg's waypoint.
  final ShoreExit? shoreExit;
```

- Constructor, after `this.current,`: `this.shoreExit,`
- `copyWith` parameters, after `bool clearCurrent = false,`:

```dart
    ShoreExit? shoreExit,
    bool clearShoreExit = false,
```

- `copyWith` body, after the `current:` line: `shoreExit: clearShoreExit ? null : (shoreExit ?? this.shoreExit),`
- `props`, after `current,`: `shoreExit,`

In `dpv_mission.dart`:

- After `const double kDefaultBatteryReserveFraction = 1.0 / 3.0;`:

```dart

/// Walking speed on land in full kit, in m/s, for a shore exit.
const double kDefaultWalkSpeedMps = 0.8;

/// Where the mission is dived, which decides the ways out.
///
/// [overhead]: no direct ascent; an exit goes back along the route at depth.
/// [openWater]: a diver may ascend anywhere, swim straight home, or land on
/// a shore and walk.
enum MissionEnvironment { overhead, openWater }
```

- After the `defaultCurrent` field:

```dart

  final MissionEnvironment environment;

  /// Walking speed for a shore exit, in m/s. Open water only.
  final double walkSpeedMps;

  /// Longest acceptable surface swim, in metres; null means a surface exit
  /// is reported but never blocks. Open water only.
  final double? surfaceSwimLimitM;
```

- Constructor, after `this.defaultCurrent,`:

```dart
    this.environment = MissionEnvironment.overhead,
    this.walkSpeedMps = kDefaultWalkSpeedMps,
    this.surfaceSwimLimitM,
```

- `copyWith` parameters, after `bool clearDefaultCurrent = false,`:

```dart
    MissionEnvironment? environment,
    double? walkSpeedMps,
    double? surfaceSwimLimitM,
    bool clearSurfaceSwimLimit = false,
```

- `copyWith` body, after the `defaultCurrent:` entry:

```dart
      environment: environment ?? this.environment,
      walkSpeedMps: walkSpeedMps ?? this.walkSpeedMps,
      surfaceSwimLimitM: clearSurfaceSwimLimit
          ? null
          : (surfaceSwimLimitM ?? this.surfaceSwimLimitM),
```

- `props`, after `defaultCurrent,`:

```dart
    environment,
    walkSpeedMps,
    surfaceSwimLimitM,
```

- [ ] **Step 4: Run the tests**

```bash
flutter test test/features/planner/mission/mission_open_water_entities_test.dart test/features/planner/mission/mission_entities_test.dart test/features/planner/mission/mission_value_semantics_test.dart
```

Expected: PASS.

- [ ] **Step 5: Format and commit**

```bash
dart format lib/features/planner/domain/entities/mission test/features/planner/mission
git add lib/features/planner/domain/entities/mission/shore_exit.dart lib/features/planner/domain/entities/mission/mission_leg.dart lib/features/planner/domain/entities/mission/dpv_mission.dart test/features/planner/mission/mission_open_water_entities_test.dart
git commit -m "feat(planner): add open-water environment and shore exits to DPV missions

Refs #2086"
```

---

### Task 3: Positions and exit legs

**Files:**
- Create: `lib/features/planner/domain/entities/mission/exit_leg.dart`
- Create: `lib/features/planner/domain/services/mission/mission_geometry.dart`
- Test: `test/features/planner/mission/mission_geometry_test.dart`

**Interfaces:**
- Consumes: Task 2 `MissionEnvironment`, `DpvMission.currentFor`, `MissionLeg.returnHeadingDeg`.
- Produces: `ExitLeg({required String id, required double distanceM, required double depthM, required double headingDeg, CurrentVector? current})`; `const double kMinExitLegM = 0.5`; `RoutePoint({required double eastM, required double northM})` with `distanceHomeM` and `bearingHomeDeg`; `List<RoutePoint> waypointPositions(List<MissionLeg> legs)`; `List<ExitLeg> retraceExitLegs(DpvMission mission, int waypointIndex)`; `List<ExitLeg> exitLegsFor(DpvMission mission, int waypointIndex)`.

Hand-computed vectors: L1 300 m on 090, L2 400 m on 000. Positions (east, north): (300, 0), (300, 400). Distance home: 300, 500. Bearing home: from (300, 0) due west, 270; from (300, 400) `atan2(-300, -400)` is -143.13 degrees, so 216.87.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/planner/mission/mission_geometry_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/planner/domain/entities/mission/current_vector.dart';
import 'package:submersion/features/planner/domain/entities/mission/dpv_mission.dart';
import 'package:submersion/features/planner/domain/entities/mission/exit_leg.dart';
import 'package:submersion/features/planner/domain/entities/mission/mission_leg.dart';
import 'package:submersion/features/planner/domain/services/mission/mission_geometry.dart';

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
  distanceM: 400,
  depthM: 30,
  headingDeg: 0,
);

void main() {
  group('positions', () {
    test('dead reckoning sums each leg along its heading', () {
      final points = waypointPositions(const [_l1, _l2]);
      expect(points[0].eastM, closeTo(300, 1e-9));
      expect(points[0].northM, closeTo(0, 1e-9));
      expect(points[1].eastM, closeTo(300, 1e-9));
      expect(points[1].northM, closeTo(400, 1e-9));
      expect(points[0].distanceHomeM, closeTo(300, 1e-9));
      expect(points[1].distanceHomeM, closeTo(500, 1e-9));
    });

    test('the bearing home points back to the entry', () {
      final points = waypointPositions(const [_l1, _l2]);
      expect(points[0].bearingHomeDeg, closeTo(270, 1e-9));
      expect(points[1].bearingHomeDeg, closeTo(216.8699, 1e-3));
      expect(
        const RoutePoint(eastM: 0, northM: -100).bearingHomeDeg,
        closeTo(0, 1e-9),
      );
      expect(
        const RoutePoint(eastM: -100, northM: 0).bearingHomeDeg,
        closeTo(90, 1e-9),
      );
    });

    test('every bearing home is in [0, 360)', () {
      for (final (east, north) in [
        (1.0, 1.0),
        (-1.0, 1.0),
        (-1.0, -1.0),
        (1.0, -1.0),
        (0.0, 5.0),
      ]) {
        final bearing = RoutePoint(eastM: east, northM: north).bearingHomeDeg;
        expect(bearing, greaterThanOrEqualTo(0));
        expect(bearing, lessThan(360));
      }
    });

    test('a heading outside 0 to 360 lands where its twin does', () {
      final a = waypointPositions([_l1.copyWith(headingDeg: 450)]).single;
      final b = waypointPositions([_l1]).single;
      expect(a.eastM, closeTo(b.eastM, 1e-9));
      expect(a.northM, closeTo(b.northM, 1e-9));
    });

    test('at the entry the distance is zero and the bearing is 0', () {
      const here = RoutePoint(eastM: 0, northM: 0);
      expect(here.distanceHomeM, 0);
      expect(here.bearingHomeDeg, 0);
    });
  });

  group('exit legs', () {
    const current = CurrentVector(speedMps: 0.1, setsTowardDeg: 180);

    test('retracing runs the legs back in reverse on their reciprocals', () {
      final mission = DpvMission(
        legs: [_l1, _l2.copyWith(current: current)],
      );
      expect(retraceExitLegs(mission, 1), const [
        ExitLeg(
          id: 'L2',
          distanceM: 400,
          depthM: 30,
          headingDeg: 180,
          current: current,
        ),
        ExitLeg(id: 'L1', distanceM: 300, depthM: 20, headingDeg: 270),
      ]);
      expect(retraceExitLegs(mission, 0).map((e) => e.id), ['L1']);
    });

    test('an overhead exit retraces the route', () {
      const mission = DpvMission(legs: [_l1, _l2]);
      expect(exitLegsFor(mission, 1), retraceExitLegs(mission, 1));
    });

    test('an open-water exit is one straight leg home at the waypoint depth', () {
      const mission = DpvMission(
        legs: [_l1, _l2],
        environment: MissionEnvironment.openWater,
        defaultCurrent: current,
      );
      final legs = exitLegsFor(mission, 1);
      expect(legs, hasLength(1));
      expect(legs.single.id, 'home');
      expect(legs.single.distanceM, closeTo(500, 1e-9));
      expect(legs.single.headingDeg, closeTo(216.8699, 1e-3));
      expect(legs.single.depthM, 30);
      expect(legs.single.current, current);
    });

    test('without a mission default the straight leg takes the waypoint leg current', () {
      final mission = DpvMission(
        legs: [_l1, _l2.copyWith(current: current)],
        environment: MissionEnvironment.openWater,
      );
      expect(exitLegsFor(mission, 1).single.current, current);
      expect(exitLegsFor(mission, 0).single.current, isNull);
    });

    test('a route that ends at the entry has no open-water exit leg', () {
      const mission = DpvMission(
        legs: [
          MissionLeg(
            id: 'out',
            order: 0,
            label: 'A',
            distanceM: 200,
            depthM: 20,
            headingDeg: 0,
          ),
          MissionLeg(
            id: 'back',
            order: 1,
            label: 'B',
            distanceM: 200,
            depthM: 20,
            headingDeg: 180,
          ),
        ],
        environment: MissionEnvironment.openWater,
      );
      expect(exitLegsFor(mission, 1), isEmpty);
    });
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/features/planner/mission/mission_geometry_test.dart`
Expected: FAIL, the imports do not resolve.

- [ ] **Step 3: Implement**

```dart
// lib/features/planner/domain/entities/mission/exit_leg.dart
import 'package:equatable/equatable.dart';

import 'package:submersion/features/planner/domain/entities/mission/current_vector.dart';

/// One leg of a way out: travelled on [headingDeg] at [depthM] for
/// [distanceM], in [current] (already resolved; null means none). Carries
/// no scooter or diver, so any exit (a retrace, a straight line home, a
/// jump back to a line) can be expressed with it.
class ExitLeg extends Equatable {
  /// Names the generated segments: `mission-ret-<id>`.
  final String id;
  final double distanceM;
  final double depthM;
  final double headingDeg;
  final CurrentVector? current;

  const ExitLeg({
    required this.id,
    required this.distanceM,
    required this.depthM,
    required this.headingDeg,
    this.current,
  });

  @override
  List<Object?> get props => [id, distanceM, depthM, headingDeg, current];
}
```

```dart
// lib/features/planner/domain/services/mission/mission_geometry.dart
import 'dart:math' as math;

import 'package:equatable/equatable.dart';

import 'package:submersion/features/planner/domain/entities/mission/dpv_mission.dart';
import 'package:submersion/features/planner/domain/entities/mission/exit_leg.dart';
import 'package:submersion/features/planner/domain/entities/mission/mission_leg.dart';

/// An exit leg shorter than this is no leg at all: a route that ends where
/// it started has nothing to swim, and floating error must not make it one.
const double kMinExitLegM = 0.5;

/// A position relative to the entry, in metres east and north.
class RoutePoint extends Equatable {
  final double eastM;
  final double northM;

  const RoutePoint({required this.eastM, required this.northM});

  double get distanceHomeM => math.sqrt(eastM * eastM + northM * northM);

  /// True bearing from here back to the entry, in [0, 360). Zero at the
  /// entry itself, where there is no direction to go.
  double get bearingHomeDeg {
    if (distanceHomeM < kMinExitLegM) return 0;
    final degrees = math.atan2(-eastM, -northM) * 180.0 / math.pi;
    return (degrees + 360.0) % 360.0;
  }

  @override
  List<Object?> get props => [eastM, northM];
}

/// Each waypoint's position by dead reckoning: the sum of every leg up to
/// it along its heading.
List<RoutePoint> waypointPositions(List<MissionLeg> legs) {
  var east = 0.0;
  var north = 0.0;
  return [
    for (final leg in legs)
      () {
        final radians = leg.headingDeg * math.pi / 180.0;
        east += leg.distanceM * math.sin(radians);
        north += leg.distanceM * math.cos(radians);
        return RoutePoint(eastM: east, northM: north);
      }(),
  ];
}

/// The way back along the route from waypoint [waypointIndex]: its legs in
/// reverse, each on its reciprocal heading in its own current.
List<ExitLeg> retraceExitLegs(DpvMission mission, int waypointIndex) {
  final last = math.min(waypointIndex, mission.legs.length - 1);
  return [
    for (final leg in mission.legs.sublist(0, last + 1).reversed)
      ExitLeg(
        id: leg.id,
        distanceM: leg.distanceM,
        depthM: leg.depthM,
        headingDeg: leg.returnHeadingDeg,
        current: mission.currentFor(leg),
      ),
  ];
}

/// The underwater way out from waypoint [waypointIndex] for the mission's
/// environment: the route retraced in an overhead, or one straight leg home
/// at the waypoint's depth in open water (none when the waypoint is the
/// entry). The straight leg takes the mission's default current, else the
/// current of the leg that ends at the waypoint.
List<ExitLeg> exitLegsFor(DpvMission mission, int waypointIndex) {
  switch (mission.environment) {
    case MissionEnvironment.overhead:
      return retraceExitLegs(mission, waypointIndex);
    case MissionEnvironment.openWater:
      final point = waypointPositions(mission.legs)[waypointIndex];
      if (point.distanceHomeM < kMinExitLegM) return const [];
      final leg = mission.legs[waypointIndex];
      return [
        ExitLeg(
          id: 'home',
          distanceM: point.distanceHomeM,
          depthM: leg.depthM,
          headingDeg: point.bearingHomeDeg,
          current: mission.defaultCurrent ?? leg.current,
        ),
      ];
  }
}
```

- [ ] **Step 4: Run the test**

Run: `flutter test test/features/planner/mission/mission_geometry_test.dart`
Expected: PASS, 10 tests.

- [ ] **Step 5: Format and commit**

```bash
dart format lib/features/planner/domain test/features/planner/mission
git add lib/features/planner/domain/entities/mission/exit_leg.dart lib/features/planner/domain/services/mission/mission_geometry.dart test/features/planner/mission/mission_geometry_test.dart
git commit -m "feat(planner): dead-reckon DPV waypoints and build exit legs per environment

Refs #2086"
```

---

### Task 4: Segment builder split

**Files:**
- Rewrite: `lib/features/planner/domain/services/mission/mission_segment_builder.dart`
- Test: `test/features/planner/mission/mission_segment_builder_exit_test.dart`

**Interfaces:**
- Consumes: Task 1 `resolveHeading`; Task 3 `ExitLeg`, `retraceExitLegs`, `kMinExitLegM`.
- Produces: `MissionProfile outbound({required DivePlan plan, required DpvMission mission, required int throughLegIndex, required double speedMps})` (outbound segments and arrivals only); `List<PlanSegment> appendExitLegs({required DivePlan plan, required List<PlanSegment> segments, required List<ExitLeg> exitLegs, required double exitSpeedMps})`; `build(...)` unchanged in signature and output.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/planner/mission/mission_segment_builder_exit_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    as domain;
import 'package:submersion/features/planner/domain/entities/mission/dpv_mission.dart';
import 'package:submersion/features/planner/domain/entities/mission/exit_leg.dart';
import 'package:submersion/features/planner/domain/entities/mission/mission_leg.dart';
import 'package:submersion/features/planner/domain/services/mission/mission_segment_builder.dart';

const _air = GasMix(o2: 21);

domain.DivePlan _plan() => domain.DivePlan(
  id: 'plan-1',
  name: 'Builder exits',
  gfLow: 40,
  gfHigh: 80,
  descentRate: 18,
  ascentRate: 9,
  tanks: const [
    DiveTank(
      id: 'back',
      volume: 24,
      startPressure: 200,
      gasMix: _air,
      role: TankRole.backGas,
    ),
  ],
  createdAt: DateTime(2026, 9, 25),
  updatedAt: DateTime(2026, 9, 25),
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
  distanceM: 400,
  depthM: 30,
  headingDeg: 0,
);

void main() {
  const builder = MissionSegmentBuilder();
  const mission = DpvMission(legs: [_l1, _l2]);

  test('outbound stops at the waypoint', () {
    final profile = builder.outbound(
      plan: _plan(),
      mission: mission,
      throughLegIndex: 1,
      speedMps: 0.5,
    );
    expect(profile.segments.map((s) => s.id), [
      'mission-out-travel-L1',
      'mission-out-L1',
      'mission-out-travel-L2',
      'mission-out-L2',
    ]);
    expect(profile.waypointArrivalSeconds, [667, 1500]);
  });

  test('a straight leg home is appended at its own speed', () {
    final out = builder.outbound(
      plan: _plan(),
      mission: mission,
      throughLegIndex: 1,
      speedMps: 0.5,
    );
    final segments = builder.appendExitLegs(
      plan: _plan(),
      segments: out.segments,
      exitLegs: const [
        ExitLeg(id: 'home', distanceM: 500, depthM: 30, headingDeg: 216.87),
      ],
      exitSpeedMps: 0.2,
    );
    expect(segments.length, out.segments.length + 1);
    expect(segments.last.id, 'mission-ret-home');
    expect(segments.last.durationSeconds, 2500);
    expect(segments.last.order, out.segments.length);
    // The input list is left alone.
    expect(out.segments.length, 4);
  });

  test('an exit leg at a new depth gets its travel first', () {
    final out = builder.outbound(
      plan: _plan(),
      mission: mission,
      throughLegIndex: 1,
      speedMps: 0.5,
    );
    final segments = builder.appendExitLegs(
      plan: _plan(),
      segments: out.segments,
      exitLegs: const [
        ExitLeg(id: 'home', distanceM: 500, depthM: 10, headingDeg: 216.87),
      ],
      exitSpeedMps: 0.2,
    );
    expect(segments.map((s) => s.id).skip(4), [
      'mission-ret-travel-home',
      'mission-ret-home',
    ]);
  });

  test('an exit leg shorter than the minimum is skipped', () {
    final out = builder.outbound(
      plan: _plan(),
      mission: mission,
      throughLegIndex: 1,
      speedMps: 0.5,
    );
    final segments = builder.appendExitLegs(
      plan: _plan(),
      segments: out.segments,
      exitLegs: const [
        ExitLeg(id: 'home', distanceM: 0.1, depthM: 30, headingDeg: 0),
      ],
      exitSpeedMps: 0.2,
    );
    expect(segments, out.segments);
  });

  test('build is outbound plus the retraced route', () {
    final built = builder.build(
      plan: _plan(),
      mission: mission,
      throughLegIndex: 1,
      outboundSpeedMps: 0.5,
      exitSpeedMps: 0.5,
    );
    expect(built.segments.map((s) => s.id).skip(4), [
      'mission-ret-L2',
      'mission-ret-travel-L1',
      'mission-ret-L1',
    ]);
  });
}
```

Arrival vector: travel 0 to 20 m at 18 m/min is 67 s, L1 600 s, travel 20 to 30 m is 33 s, L2 800 s; arrivals 667 and 1500.

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/features/planner/mission/mission_segment_builder_exit_test.dart`
Expected: FAIL, "The method 'outbound' isn't defined".

- [ ] **Step 3: Rewrite the builder**

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
import 'package:submersion/features/planner/domain/entities/mission/exit_leg.dart';
import 'package:submersion/features/planner/domain/services/mission/leg_speed_resolver.dart';
import 'package:submersion/features/planner/domain/services/mission/mission_geometry.dart';

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
/// Each leg becomes a hold at its depth for `distance / speed over ground`,
/// and a depth change between legs becomes an explicit travel segment
/// first. The segment chain resolves a hold whose depth differs from the
/// previous one as a travel leg spanning its WHOLE duration, so the travel
/// must be authored separately or the leg would be integrated as a slow
/// descent. The engine's own ascent takes over after the last segment.
class MissionSegmentBuilder {
  final LegSpeedResolver speeds;

  const MissionSegmentBuilder({this.speeds = const LegSpeedResolver()});

  /// The planned round trip: outbound legs 0 through [throughLegIndex] at
  /// [outboundSpeedMps], then the same legs retraced at [exitSpeedMps]. An
  /// empty profile when the plan has no tank to breathe.
  MissionProfile build({
    required domain.DivePlan plan,
    required DpvMission mission,
    required int throughLegIndex,
    required double outboundSpeedMps,
    required double exitSpeedMps,
  }) {
    final out = outbound(
      plan: plan,
      mission: mission,
      throughLegIndex: throughLegIndex,
      speedMps: outboundSpeedMps,
    );
    if (out.segments.isEmpty) return out;
    final last = math.min(throughLegIndex, mission.legs.length - 1);
    return MissionProfile(
      segments: appendExitLegs(
        plan: plan,
        segments: out.segments,
        exitLegs: retraceExitLegs(mission, last),
        exitSpeedMps: exitSpeedMps,
      ),
      waypointArrivalSeconds: out.waypointArrivalSeconds,
    );
  }

  /// Outbound legs 0 through [throughLegIndex] at [speedMps] through the
  /// water, each in its own current.
  MissionProfile outbound({
    required domain.DivePlan plan,
    required DpvMission mission,
    required int throughLegIndex,
    required double speedMps,
  }) {
    final tank = _bottomTank(plan);
    if (tank == null || mission.legs.isEmpty) {
      return const MissionProfile(segments: [], waypointArrivalSeconds: []);
    }
    final last = math.min(throughLegIndex, mission.legs.length - 1);
    final segments = <PlanSegment>[];
    final arrivals = <int>[];
    var runtime = 0;
    var depth = 0.0;
    for (final leg in mission.legs.sublist(0, last + 1)) {
      if (leg.depthM != depth) {
        final travel = _travel(
          plan,
          tank,
          'mission-out-travel-${leg.id}',
          depth,
          leg.depthM,
          segments.length,
        );
        segments.add(travel);
        runtime += travel.durationSeconds;
        depth = leg.depthM;
      }
      final speed = speeds
          .resolve(
            leg: leg,
            current: mission.currentFor(leg),
            baseSpeedMps: speedMps,
          )
          .outboundMps;
      final hold = _hold(
        tank,
        'mission-out-${leg.id}',
        depth,
        leg.distanceM,
        speed,
        segments.length,
      );
      segments.add(hold);
      runtime += hold.durationSeconds;
      arrivals.add(runtime);
    }
    return MissionProfile(segments: segments, waypointArrivalSeconds: arrivals);
  }

  /// [segments] followed by [exitLegs] travelled at [exitSpeedMps] through
  /// the water, each on its own heading in its own current. Legs shorter
  /// than [kMinExitLegM] are skipped. Returns a new list.
  List<PlanSegment> appendExitLegs({
    required domain.DivePlan plan,
    required List<PlanSegment> segments,
    required List<ExitLeg> exitLegs,
    required double exitSpeedMps,
  }) {
    final tank = _bottomTank(plan);
    if (tank == null) return segments;
    final result = [...segments];
    var depth = segments.isEmpty ? 0.0 : segments.last.targetDepth;
    for (final leg in exitLegs) {
      if (leg.distanceM < kMinExitLegM) continue;
      if (leg.depthM != depth) {
        result.add(
          _travel(
            plan,
            tank,
            'mission-ret-travel-${leg.id}',
            depth,
            leg.depthM,
            result.length,
          ),
        );
        depth = leg.depthM;
      }
      final speed = speeds
          .resolveHeading(
            headingDeg: leg.headingDeg,
            current: leg.current,
            baseSpeedMps: exitSpeedMps,
          )
          .outboundMps;
      result.add(
        _hold(
          tank,
          'mission-ret-${leg.id}',
          depth,
          leg.distanceM,
          speed,
          result.length,
        ),
      );
    }
    return result;
  }

  PlanSegment _travel(
    domain.DivePlan plan,
    DiveTank tank,
    String id,
    double fromDepth,
    double toDepth,
    int order,
  ) {
    return PlanSegment.travel(
      id: id,
      fromDepth: fromDepth,
      targetDepth: toDepth,
      tankId: tank.id,
      gasMix: tank.gasMix,
      ratePerMinute: toDepth > fromDepth ? plan.descentRate : plan.ascentRate,
      order: order,
    );
  }

  PlanSegment _hold(
    DiveTank tank,
    String id,
    double depth,
    double metres,
    double mps,
    int order,
  ) {
    // Never clamp: a hold of one second against a current the diver cannot
    // beat would report an impossible exit as feasible. Callers check
    // traversability first; reaching here with no headway is a bug.
    if (mps <= 0) {
      throw ArgumentError.value(mps, 'mps', 'no headway on $id');
    }
    return PlanSegment(
      id: id,
      targetDepth: depth,
      durationSeconds: math.max(1, _holdSeconds(metres, mps)),
      tankId: tank.id,
      gasMix: tank.gasMix,
      order: order,
    );
  }

  /// Whole seconds to cover [metres] at [mps], rounded up so the hold never
  /// ends short of the waypoint. The tolerance keeps floating noise in a
  /// speed (0.5 + 0.1 is not exactly 0.6) from adding a spurious second to a
  /// leg that divides exactly.
  static int _holdSeconds(double metres, double mps) =>
      (metres / mps - 1e-6).ceil();

  /// The tank the bottom is breathed from: the first cylinder declared back
  /// gas, else the first cylinder (the one the canvas gives a new segment).
  ///
  /// Deliberately not `TankRoleResolver`: it derives the bottom tank from the
  /// plan's segments, and these are the segments being generated, so on a
  /// fresh mission it would just pick the first tank, deco bottle or not.
  DiveTank? _bottomTank(domain.DivePlan plan) {
    if (plan.tanks.isEmpty) return null;
    for (final tank in plan.tanks) {
      if (tank.role == TankRole.backGas) return tank;
    }
    return plan.tanks.first;
  }
}
```

The retraced legs run on their reciprocal heading through `resolveHeading`, which gives the same speed as the old `resolve(...).returnMps`: the along-track share flips sign and the cross share keeps its size.

- [ ] **Step 4: Run the builder tests and the tests that use it**

```bash
flutter test test/features/planner/mission/mission_segment_builder_exit_test.dart test/features/planner/mission/mission_segment_builder_test.dart test/features/planner/mission/mission_scenario_service_test.dart test/features/planner/mission/mission_engine_test.dart
```

Expected: PASS; every existing builder vector is unchanged.

- [ ] **Step 5: Format and commit**

```bash
dart format lib/features/planner/domain test/features/planner/mission
git add lib/features/planner/domain/services/mission/mission_segment_builder.dart test/features/planner/mission/mission_segment_builder_exit_test.dart
git commit -m "refactor(planner): split the DPV segment builder into outbound and exit legs

Refs #2086"
```

---

### Task 5: Outcome types for surface exits and the new binding reasons

**Files:**
- Modify: `lib/features/planner/domain/entities/mission/mission_outcome.dart`
- Modify: `lib/features/planner/domain/services/mission/mission_member_analysis.dart` (rename only)
- Modify: `lib/features/planner/domain/services/mission/mission_scenario_service.dart` (surface guard only)
- Modify: `test/features/planner/mission/mission_scenario_service_test.dart` (mode loop)
- Test: `test/features/planner/mission/mission_outcome_surface_test.dart`

**Interfaces:**
- Produces: `enum MissionExitMode { swim, tow, surface }`; `enum MissionBindingFactor { battery, ownGas, teamGas, blockedByCurrent, noFeasibleTow, surfaceSwimLimit }` (the order is the tie-break priority); `MissionIssueType.memberSwimSpeedUnset`; `ExitOutcome` gains `surfaceSeconds` (int, default 0), `surfaceSwimM` (double?), `walkM` (double?), `viaShore` (bool, default false), `surfaceLimitExceeded` (bool, default false), and `exitSeconds` includes `surfaceSeconds`; `MemberWaypointOutcome.surface` (`ExitOutcome?`, default null, open water only).

- [ ] **Step 1: Write the failing test**

```dart
// test/features/planner/mission/mission_outcome_surface_test.dart
// ignore_for_file: prefer_const_constructors

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/planner/domain/entities/mission/mission_outcome.dart';

ExitOutcome _surface({bool viaShore = true}) => ExitOutcome(
  mode: MissionExitMode.surface,
  feasible: true,
  exitBottomSeconds: 0,
  ttsSeconds: 240,
  exitLitersByMember: {'a': 300.0},
  surfaceSeconds: 875,
  surfaceSwimM: 100,
  walkM: 300,
  viaShore: viaShore,
);

void main() {
  test('the binding reasons are in tie-break order', () {
    expect(MissionBindingFactor.values, [
      MissionBindingFactor.battery,
      MissionBindingFactor.ownGas,
      MissionBindingFactor.teamGas,
      MissionBindingFactor.blockedByCurrent,
      MissionBindingFactor.noFeasibleTow,
      MissionBindingFactor.surfaceSwimLimit,
    ]);
  });

  test('a surface exit counts its surface time in the exit time', () {
    expect(_surface().exitSeconds, 240 + 875);
  });

  test('an underwater exit has no surface part', () {
    final swim = ExitOutcome(
      mode: MissionExitMode.swim,
      feasible: true,
      exitBottomSeconds: 1500,
      ttsSeconds: 300,
      exitLitersByMember: {'a': 1200.0},
    );
    expect(swim.surfaceSeconds, 0);
    expect(swim.surfaceSwimM, isNull);
    expect(swim.walkM, isNull);
    expect(swim.viaShore, isFalse);
    expect(swim.surfaceLimitExceeded, isFalse);
    expect(swim.exitSeconds, 1800);
  });

  test('the surface fields take part in equality', () {
    expect(_surface(), _surface());
    expect(_surface(viaShore: false), isNot(_surface()));
  });

  test('a member outcome carries the surface exit', () {
    MemberWaypointOutcome member(ExitOutcome? surface) => MemberWaypointOutcome(
      memberId: 'a',
      gasRemainingBar: 180,
      swim: ExitOutcome(
        mode: MissionExitMode.swim,
        feasible: false,
        exitBottomSeconds: 0,
        ttsSeconds: 0,
        exitLitersByMember: {},
        blockedByCurrent: true,
      ),
      surface: surface,
      survivable: surface != null,
    );
    expect(member(null).surface, isNull);
    expect(member(_surface()).surface, _surface());
    expect(member(_surface()), isNot(member(null)));
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/features/planner/mission/mission_outcome_surface_test.dart`
Expected: FAIL, "There's no constant named 'surface' in 'MissionExitMode'".

- [ ] **Step 3: Implement**

In `mission_outcome.dart`:

1. Add `memberSwimSpeedUnset,` to `MissionIssueType` after `memberSacUnset,`.
2. Replace the two enums:

```dart
/// A way out for a team whose member's scooter has died. In an overhead,
/// [swim] and [tow] retrace the route; in open water they go straight home.
/// [surface] is open water only: ascend in place, then swim at the surface.
enum MissionExitMode { swim, tow, surface }

/// The first thing that stops a member going further. The order is the
/// tie-break priority when two members bind at the same waypoint.
///
/// [teamGas]: the member could get out, but a teammate's gas cannot cover
/// the exit. [blockedByCurrent]: no exit can make headway. [noFeasibleTow]:
/// only when the member has a teammate whose tow was possible but failed.
/// [surfaceSwimLimit]: open water, the only way out is a surface swim longer
/// than the mission's limit.
enum MissionBindingFactor {
  battery,
  ownGas,
  teamGas,
  blockedByCurrent,
  noFeasibleTow,
  surfaceSwimLimit,
}
```

3. In `ExitOutcome`, after the `blockedByCurrent` field:

```dart

  /// Surface exit only: seconds at the surface after the ascent, swimming
  /// and, via a shore, walking.
  final int surfaceSeconds;

  /// Surface exit only: metres swum at the surface.
  final double? surfaceSwimM;

  /// Surface exit only: metres walked from the shore to the entry.
  final double? walkM;

  /// Surface exit only: whether it lands on the waypoint's shore exit
  /// rather than swimming straight to the entry.
  final bool viaShore;

  /// Surface exit only: no surface route is within the mission's limit.
  final bool surfaceLimitExceeded;
```

   Constructor, after `this.blockedByCurrent = false,`:

```dart
    this.surfaceSeconds = 0,
    this.surfaceSwimM,
    this.walkM,
    this.viaShore = false,
    this.surfaceLimitExceeded = false,
```

   Replace `int get exitSeconds => exitBottomSeconds + ttsSeconds;` with:

```dart
  int get exitSeconds => exitBottomSeconds + ttsSeconds + surfaceSeconds;
```

   In `props`, after `blockedByCurrent,`:

```dart
    surfaceSeconds,
    surfaceSwimM,
    walkM,
    viaShore,
    surfaceLimitExceeded,
```

4. In `MemberWaypointOutcome`, after the `tow` field:

```dart

  /// Open water only: ascend in place and continue at the surface. Shared
  /// by every member, because the ascent does not depend on whose scooter
  /// failed. Null in an overhead, or when the scenario could not be run.
  final ExitOutcome? surface;
```

   Constructor, after `this.tow,`: `this.surface,`
   Replace the props list with `[memberId, gasRemainingBar, swim, tow, surface, survivable]`.
   Update the `tow` field's doc comment to: `/// The best tow exit (feasible if any is), or null when the member has no teammate: a solo diver has no buddy to tow them.`

In `mission_member_analysis.dart`, replace `MissionBindingFactor.swimGas` with `MissionBindingFactor.teamGas` (one occurrence). Task 7 rewrites this logic.

In `mission_scenario_service.dart`, in `evaluate`, add a surface case to the `switch (mode)` expression so it stays exhaustive (Task 6 rewrites this file):

```dart
      MissionExitMode.surface => throw ArgumentError.value(
        mode,
        'mode',
        'the surface exit has its own evaluation',
      ),
```

In `test/features/planner/mission/mission_scenario_service_test.dart`, replace `for (final mode in MissionExitMode.values) {` with `for (final mode in [MissionExitMode.swim, MissionExitMode.tow]) {`.

- [ ] **Step 4: Run the tests**

```bash
flutter test test/features/planner/mission/
```

Expected: PASS, every mission test.

- [ ] **Step 5: Format and commit**

```bash
dart format lib/features/planner/domain test/features/planner/mission
git add lib/features/planner/domain/entities/mission/mission_outcome.dart lib/features/planner/domain/services/mission/mission_member_analysis.dart lib/features/planner/domain/services/mission/mission_scenario_service.dart test/features/planner/mission/mission_scenario_service_test.dart test/features/planner/mission/mission_outcome_surface_test.dart
git commit -m "feat(planner): add surface exits and split binding reasons in mission outcomes

Refs #2086"
```

---

### Task 6: Scooter-free exit evaluator, open-water scenarios and the surface exit

**Files:**
- Create: `lib/features/planner/domain/services/mission/exit_path_evaluator.dart`
- Rewrite: `lib/features/planner/domain/services/mission/mission_scenario_service.dart`
- Modify: `lib/features/planner/domain/services/mission/mission_engine.dart` (environment helper reference only)
- Test: `test/features/planner/mission/exit_path_evaluator_test.dart`
- Test: `test/features/planner/mission/mission_scenario_open_water_test.dart`

**Interfaces:**
- Consumes: Tasks 1 to 5.
- Produces:

```dart
class ExitDiver { const ExitDiver({required String id, required double sacBottom, bool stressed = false}); }
class ExitPathResult {
  final int exitBottomSeconds; final int ttsSeconds;
  final Map<String, double> exitLitersByMember; final Set<String> gasShortfallMemberIds;
  final bool blockedByCurrent;
  static const blocked = ...;
}
class ExitPathEvaluator {
  const ExitPathEvaluator({PlanEngine engine, MissionSegmentBuilder builder, MemberGasService gas, LegSpeedResolver speeds});
  ExitPathResult evaluate({required DivePlan plan, required List<PlanSegment> outboundSegments, required int failureRuntimeSeconds, required List<ExitLeg> exitLegs, required double exitSpeedMps, required List<ExitDiver> divers});
  static DiveEnvironment environmentFor(DivePlan plan);
}
class MissionScenarioService {
  const MissionScenarioService({PlanEngine engine, MissionSegmentBuilder builder, BatteryBurnService battery, ExitPathEvaluator exits});
  double towSpeedMps({...});                       // unchanged
  ExitOutcome evaluate({...});                     // unchanged signature; throws for surface
  ExitOutcome evaluateSurface({required DivePlan plan, required DpvMission mission, required int waypointIndex});
  int overheadSafeSurfaceSeconds({required DivePlan plan, required DpvMission mission, required int waypointIndex});
}
```

Hand-computed vectors for the open-water fixture (L1 300 m on 090 at 20 m, L2 400 m on 000 at 20 m, scooters 0.5 m/s, swim 0.2 m/s, tow factor 0.6):
- Straight home from waypoint 1 is 500 m: swim 500 / 0.2 = 2500 s; tow 500 / 0.3 = 1667 s (1666.7 rounded up).
- Overhead retrace from waypoint 1 is 700 m: 3500 s.
- Surface straight to the entry: 2500 s. Via a shore 100 m away and a 300 m walk at 0.8 m/s: 500 + 375 = 875 s.

- [ ] **Step 1: Write the failing tests**

```dart
// test/features/planner/mission/exit_path_evaluator_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/deco/entities/dive_environment.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_segment.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    as domain;
import 'package:submersion/features/planner/domain/entities/mission/current_vector.dart';
import 'package:submersion/features/planner/domain/entities/mission/exit_leg.dart';
import 'package:submersion/features/planner/domain/services/mission/exit_path_evaluator.dart';

const _air = GasMix(o2: 21);

domain.DivePlan _plan({double tankLiters = 40}) => domain.DivePlan(
  id: 'plan-1',
  name: 'Exit path',
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
      startPressure: 230,
      gasMix: _air,
      role: TankRole.backGas,
    ),
  ],
  createdAt: DateTime(2026, 9, 25),
  updatedAt: DateTime(2026, 9, 25),
);

/// Descend to 20 m (67 s) and hold 600 s: the failure point is at 667 s.
final _outbound = [
  PlanSegment.travel(
    id: 'down',
    fromDepth: 0,
    targetDepth: 20,
    tankId: 'back',
    gasMix: _air,
    ratePerMinute: 18,
  ),
  const PlanSegment(
    id: 'hold',
    targetDepth: 20,
    durationSeconds: 600,
    tankId: 'back',
    gasMix: _air,
    order: 1,
  ),
];

const _exitLeg = ExitLeg(id: 'x', distanceM: 300, depthM: 20, headingDeg: 180);

void main() {
  const evaluator = ExitPathEvaluator();

  ExitPathResult run({
    List<ExitLeg> legs = const [_exitLeg],
    double speed = 0.2,
    List<ExitDiver> divers = const [
      ExitDiver(id: 'a', sacBottom: 15),
      ExitDiver(id: 'b', sacBottom: 15, stressed: true),
    ],
    double tankLiters = 40,
  }) => evaluator.evaluate(
    plan: _plan(tankLiters: tankLiters),
    outboundSegments: _outbound,
    failureRuntimeSeconds: 667,
    exitLegs: legs,
    exitSpeedMps: speed,
    divers: divers,
  );

  test('the exit takes distance over speed and ends with an ascent', () {
    final result = run();
    expect(result.exitBottomSeconds, 1500);
    expect(result.ttsSeconds, greaterThan(0));
    expect(result.blockedByCurrent, isFalse);
  });

  test('a stressed diver breathes the stressed SAC on the exit bottom', () {
    final result = run();
    // 25 min at 3 bar: 1125 L at 15 L/min, 2812.5 L at 37.5 L/min; the
    // ascent is charged alike, so b is more than twice a.
    expect(
      result.exitLitersByMember['b']!,
      greaterThan(result.exitLitersByMember['a']! * 2),
    );
    expect(result.gasShortfallMemberIds, isEmpty);
  });

  test('no divers still yields the time, with nothing charged', () {
    final result = run(divers: const []);
    expect(result.exitBottomSeconds, 1500);
    expect(result.exitLitersByMember, isEmpty);
  });

  test('a current the exit speed cannot beat is blocked', () {
    final result = run(
      legs: const [
        ExitLeg(
          id: 'x',
          distanceM: 300,
          depthM: 20,
          headingDeg: 180,
          current: CurrentVector(speedMps: 0.3, setsTowardDeg: 0),
        ),
      ],
    );
    expect(result, ExitPathResult.blocked);
  });

  test('a leg shorter than the minimum is not travelled', () {
    final result = run(
      legs: const [ExitLeg(id: 'x', distanceM: 0.1, depthM: 20, headingDeg: 0)],
    );
    expect(result.exitBottomSeconds, 0);
    expect(result.blockedByCurrent, isFalse);
  });

  test('too little gas is a shortfall for every diver who runs out', () {
    expect(run(tankLiters: 3).gasShortfallMemberIds, {'a', 'b'});
  });
}
```

```dart
// test/features/planner/mission/mission_scenario_open_water_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/deco/entities/dive_environment.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    as domain;
import 'package:submersion/features/planner/domain/entities/mission/dpv_mission.dart';
import 'package:submersion/features/planner/domain/entities/mission/mission_leg.dart';
import 'package:submersion/features/planner/domain/entities/mission/mission_member.dart';
import 'package:submersion/features/planner/domain/entities/mission/mission_outcome.dart';
import 'package:submersion/features/planner/domain/entities/mission/scooter_spec.dart';
import 'package:submersion/features/planner/domain/entities/mission/shore_exit.dart';
import 'package:submersion/features/planner/domain/services/mission/mission_scenario_service.dart';

const _air = GasMix(o2: 21);

domain.DivePlan _plan() => domain.DivePlan(
  id: 'plan-1',
  name: 'Lake',
  gfLow: 40,
  gfHigh: 80,
  descentRate: 18,
  ascentRate: 9,
  sacBottom: 15,
  reservePressure: 50,
  salinityPpt: DiveEnvironment.salinityPptFromDensity(
    DiveEnvironment.en13319Density,
  ),
  tanks: const [
    DiveTank(
      id: 'back',
      volume: 40,
      startPressure: 230,
      gasMix: _air,
      role: TankRole.backGas,
    ),
  ],
  createdAt: DateTime(2026, 9, 25),
  updatedAt: DateTime(2026, 9, 25),
);

MissionMember _member(String id, int order) => MissionMember(
  id: id,
  order: order,
  displayName: id,
  sacBottom: 15,
  swimSpeedMps: 0.2,
  scooter: ScooterSpec(
    name: 'S-$id',
    ratedSpeedMps: 0.5,
    burnTimeSeconds: 7200,
  ),
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
  distanceM: 400,
  depthM: 20,
  headingDeg: 0,
);

DpvMission _mission({
  MissionEnvironment environment = MissionEnvironment.openWater,
  ShoreExit? shore,
  double? limit,
  double walkSpeed = 0.8,
}) => DpvMission(
  legs: [_l1, _l2.copyWith(shoreExit: shore)],
  team: [_member('a', 0), _member('b', 1)],
  environment: environment,
  walkSpeedMps: walkSpeed,
  surfaceSwimLimitM: limit,
);

void main() {
  const service = MissionScenarioService();

  group('underwater exits by environment', () {
    test('open water swims straight home', () {
      final exit = service.evaluate(
        plan: _plan(),
        mission: _mission(),
        waypointIndex: 1,
        failedMemberId: 'b',
        mode: MissionExitMode.swim,
      );
      expect(exit.exitBottomSeconds, 2500);
      expect(exit.blockedByCurrent, isFalse);
    });

    test('an overhead retraces the route', () {
      final exit = service.evaluate(
        plan: _plan(),
        mission: _mission(environment: MissionEnvironment.overhead),
        waypointIndex: 1,
        failedMemberId: 'b',
        mode: MissionExitMode.swim,
      );
      expect(exit.exitBottomSeconds, 3500);
    });

    test('an open-water tow goes straight home at tow speed', () {
      final exit = service.evaluate(
        plan: _plan(),
        mission: _mission(),
        waypointIndex: 1,
        failedMemberId: 'b',
        mode: MissionExitMode.tow,
        towerId: 'a',
      );
      expect(exit.towerId, 'a');
      expect(exit.exitBottomSeconds, 1667);
    });

    test('evaluate refuses the surface mode', () {
      expect(
        () => service.evaluate(
          plan: _plan(),
          mission: _mission(),
          waypointIndex: 1,
          failedMemberId: 'b',
          mode: MissionExitMode.surface,
        ),
        throwsArgumentError,
      );
    });
  });

  group('surface exit', () {
    ExitOutcome surface(DpvMission mission, {int waypoint = 1}) =>
        service.evaluateSurface(
          plan: _plan(),
          mission: mission,
          waypointIndex: waypoint,
        );

    test('without a shore exit it swims straight to the entry', () {
      final exit = surface(_mission());
      expect(exit.mode, MissionExitMode.surface);
      expect(exit.exitBottomSeconds, 0);
      expect(exit.ttsSeconds, greaterThan(0));
      expect(exit.surfaceSwimM, closeTo(500, 1e-6));
      expect(exit.walkM, 0);
      expect(exit.viaShore, isFalse);
      expect(exit.surfaceSeconds, 2500);
      expect(exit.feasible, isTrue);
      expect(exit.exitLitersByMember.keys, containsAll(['a', 'b']));
    });

    test('a shore exit and a walk win when they are faster', () {
      final exit = surface(
        _mission(shore: const ShoreExit(surfaceSwimM: 100, walkM: 300)),
      );
      expect(exit.viaShore, isTrue);
      expect(exit.surfaceSwimM, 100);
      expect(exit.walkM, 300);
      expect(exit.surfaceSeconds, 875);
    });

    test('a limit no route meets makes the surface exit infeasible', () {
      final exit = surface(
        _mission(
          shore: const ShoreExit(surfaceSwimM: 100, walkM: 300),
          limit: 50,
        ),
      );
      expect(exit.surfaceLimitExceeded, isTrue);
      expect(exit.feasible, isFalse);
      expect(exit.viaShore, isTrue, reason: 'still the fastest route');
    });

    test('a limit picks the route within it even when it is slower', () {
      // Direct 500 m swim: 2500 s. Shore: 100 m swim + 3000 m walk:
      // 500 + 3750 = 4250 s. Only the shore swim is within 200 m.
      final exit = surface(
        _mission(
          shore: const ShoreExit(surfaceSwimM: 100, walkM: 3000),
          limit: 200,
        ),
      );
      expect(exit.viaShore, isTrue);
      expect(exit.surfaceSeconds, 4250);
      expect(exit.feasible, isTrue);
    });

    test('a walk with no walking speed drops the shore route', () {
      final exit = surface(
        _mission(
          shore: const ShoreExit(surfaceSwimM: 100, walkM: 300),
          walkSpeed: 0,
        ),
      );
      expect(exit.viaShore, isFalse);
      expect(exit.surfaceSeconds, 2500);
    });

    test('a shore with no walk needs no walking speed', () {
      final exit = surface(
        _mission(
          shore: const ShoreExit(surfaceSwimM: 100, walkM: 0),
          walkSpeed: 0,
        ),
      );
      expect(exit.viaShore, isTrue);
      expect(exit.surfaceSeconds, 500);
    });

    test('a route that ends at the entry has nothing to swim', () {
      final mission = DpvMission(
        legs: const [
          MissionLeg(
            id: 'out',
            order: 0,
            label: 'A',
            distanceM: 200,
            depthM: 20,
            headingDeg: 0,
          ),
          MissionLeg(
            id: 'back',
            order: 1,
            label: 'B',
            distanceM: 200,
            depthM: 20,
            headingDeg: 180,
          ),
        ],
        team: [_member('a', 0)],
        environment: MissionEnvironment.openWater,
      );
      final exit = surface(mission);
      expect(exit.surfaceSeconds, 0);
      expect(exit.surfaceSwimM, closeTo(0, 1e-6));
      expect(exit.feasible, isTrue);
      final swim = service.evaluate(
        plan: _plan(),
        mission: mission,
        waypointIndex: 1,
        failedMemberId: 'a',
        mode: MissionExitMode.swim,
      );
      expect(swim.exitBottomSeconds, 0);
    });
  });

  test('the overhead time to a safe surface grows with distance in', () {
    final mission = _mission(environment: MissionEnvironment.overhead);
    final t0 = service.overheadSafeSurfaceSeconds(
      plan: _plan(),
      mission: mission,
      waypointIndex: 0,
    );
    final t1 = service.overheadSafeSurfaceSeconds(
      plan: _plan(),
      mission: mission,
      waypointIndex: 1,
    );
    // The way out at cruise alone is 600 s from waypoint 0 and 1400 s from
    // waypoint 1; the ascent comes on top.
    expect(t0, greaterThan(600));
    expect(t1, greaterThan(1400));
  });
}
```

- [ ] **Step 2: Run them to verify they fail**

Run: `flutter test test/features/planner/mission/exit_path_evaluator_test.dart test/features/planner/mission/mission_scenario_open_water_test.dart`
Expected: FAIL, `exit_path_evaluator.dart` does not exist.

- [ ] **Step 3: Write the evaluator**

```dart
// lib/features/planner/domain/services/mission/exit_path_evaluator.dart
import 'dart:math' as math;

import 'package:equatable/equatable.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/deco/entities/dive_environment.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_segment.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    as domain;
import 'package:submersion/features/planner/domain/entities/mission/exit_leg.dart';
import 'package:submersion/features/planner/domain/services/mission/leg_speed_resolver.dart';
import 'package:submersion/features/planner/domain/services/mission/member_gas_service.dart';
import 'package:submersion/features/planner/domain/services/mission/mission_geometry.dart';
import 'package:submersion/features/planner/domain/services/mission/mission_segment_builder.dart';
import 'package:submersion/features/planner/domain/services/plan_engine.dart';

/// One diver on an exit: their own bottom SAC, and whether they breathe the
/// plan's stressed SAC on the exit's bottom part.
class ExitDiver extends Equatable {
  final String id;
  final double sacBottom;
  final bool stressed;

  const ExitDiver({
    required this.id,
    required this.sacBottom,
    this.stressed = false,
  });

  @override
  List<Object?> get props => [id, sacBottom, stressed];
}

/// What one exit costs: time at depth, the ascent, and each diver's gas.
class ExitPathResult extends Equatable {
  /// Seconds from the failure point to the end of the exit legs.
  final int exitBottomSeconds;
  final int ttsSeconds;

  /// Surface litres each diver breathes from the failure point to the
  /// surface, by diver id.
  final Map<String, double> exitLitersByMember;

  /// Divers whose outbound plus exit gas leaves a tank below the plan's
  /// reserve.
  final Set<String> gasShortfallMemberIds;

  /// True when an exit leg cannot be travelled at the exit speed.
  final bool blockedByCurrent;

  const ExitPathResult({
    required this.exitBottomSeconds,
    required this.ttsSeconds,
    required this.exitLitersByMember,
    required this.gasShortfallMemberIds,
    required this.blockedByCurrent,
  });

  static const blocked = ExitPathResult(
    exitBottomSeconds: 0,
    ttsSeconds: 0,
    exitLitersByMember: {},
    gasShortfallMemberIds: {},
    blockedByCurrent: true,
  );

  @override
  List<Object?> get props => [
    exitBottomSeconds,
    ttsSeconds,
    exitLitersByMember,
    gasShortfallMemberIds,
    blockedByCurrent,
  ];
}

/// Evaluates a way out from a point on a dive: exit legs appended to the
/// outbound profile, the plan engine run once for the schedule and time to
/// surface, and each diver's gas charged from the schedule rows with their
/// own SAC.
///
/// Nothing here knows about scooters, so the overhead planner proposed in
/// #2164 and discussed in #2294 can use it for any exit (issue #2086).
class ExitPathEvaluator {
  final PlanEngine engine;
  final MissionSegmentBuilder builder;
  final MemberGasService gas;
  final LegSpeedResolver speeds;

  const ExitPathEvaluator({
    this.engine = const PlanEngine(),
    this.builder = const MissionSegmentBuilder(),
    this.gas = const MemberGasService(),
    this.speeds = const LegSpeedResolver(),
  });

  ExitPathResult evaluate({
    required domain.DivePlan plan,
    required List<PlanSegment> outboundSegments,
    required int failureRuntimeSeconds,
    required List<ExitLeg> exitLegs,
    required double exitSpeedMps,
    required List<ExitDiver> divers,
  }) {
    for (final leg in exitLegs) {
      if (leg.distanceM < kMinExitLegM) continue;
      final resolved = speeds.resolveHeading(
        headingDeg: leg.headingDeg,
        current: leg.current,
        baseSpeedMps: exitSpeedMps,
      );
      if (!resolved.outboundTraversable) return ExitPathResult.blocked;
    }

    final segments = builder.appendExitLegs(
      plan: plan,
      segments: outboundSegments,
      exitLegs: exitLegs,
      exitSpeedMps: exitSpeedMps,
    );
    final outcome = engine.compute(plan.copyWith(segments: segments));
    final authoredRuntime = outcome.runtimeSeconds - outcome.ttsAtBottom;
    final exitBottomSeconds = math.max(
      0,
      authoredRuntime - failureRuntimeSeconds,
    );
    final environment = environmentFor(plan);
    final outboundRows = outcome.schedule
        .where((r) => r.runtimeSeconds <= failureRuntimeSeconds)
        .toList();
    final exitRows = outcome.schedule
        .where((r) => r.runtimeSeconds > failureRuntimeSeconds)
        .toList();

    final liters = <String, double>{};
    final shortfall = <String>{};
    for (final diver in divers) {
      final outbound = gas.litersByTank(
        rows: outboundRows,
        environment: environment,
        sacFor: (_) => diver.sacBottom,
      );
      final exit = gas.litersByTank(
        rows: exitRows,
        environment: environment,
        sacFor: (row) {
          if (row.runtimeSeconds > authoredRuntime) {
            return plan.sacDecoEffective;
          }
          return diver.stressed ? plan.sacStressedEffective : diver.sacBottom;
        },
      );
      liters[diver.id] = exit.values.fold(0.0, (a, b) => a + b);
      if (_gasShort(plan, outbound, exit)) shortfall.add(diver.id);
    }

    return ExitPathResult(
      exitBottomSeconds: exitBottomSeconds,
      ttsSeconds: outcome.ttsAtBottom,
      exitLitersByMember: liters,
      gasShortfallMemberIds: shortfall,
      blockedByCurrent: false,
    );
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
  static DiveEnvironment environmentFor(domain.DivePlan plan) {
    return DiveEnvironment.forConditions(
      altitudeMeters: (plan.altitude ?? 0) > 0 ? plan.altitude : null,
      waterType: plan.waterType ?? WaterType.salt,
      salinityPpt: plan.salinityPpt,
    );
  }
}
```

- [ ] **Step 4: Rewrite the scenario service**

```dart
// lib/features/planner/domain/services/mission/mission_scenario_service.dart
import 'dart:math' as math;

import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    as domain;
import 'package:submersion/features/planner/domain/entities/mission/dpv_mission.dart';
import 'package:submersion/features/planner/domain/entities/mission/mission_outcome.dart';
import 'package:submersion/features/planner/domain/services/mission/battery_burn_service.dart';
import 'package:submersion/features/planner/domain/services/mission/exit_path_evaluator.dart';
import 'package:submersion/features/planner/domain/services/mission/mission_geometry.dart';
import 'package:submersion/features/planner/domain/services/mission/mission_segment_builder.dart';
import 'package:submersion/features/planner/domain/services/mission/mission_team.dart';
import 'package:submersion/features/planner/domain/services/plan_engine.dart';

/// One way home after a member's scooter dies on arrival at a waypoint:
/// the underwater swim or tow (retracing the route in an overhead, straight
/// home in open water), or in open water the surface exit.
///
/// The exit itself is evaluated by the scooter-free [ExitPathEvaluator];
/// this service adds what scooters bring: the tow speed and the battery.
class MissionScenarioService {
  final PlanEngine engine;
  final MissionSegmentBuilder builder;
  final BatteryBurnService battery;
  final ExitPathEvaluator exits;

  const MissionScenarioService({
    this.engine = const PlanEngine(),
    this.builder = const MissionSegmentBuilder(),
    this.battery = const BatteryBurnService(),
    this.exits = const ExitPathEvaluator(),
  });

  /// Speed through the water of a tow exit: the tower's tow speed, capped by
  /// every other running scooter's rated speed so the team stays together.
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

  /// The swim or tow exit after [failedMemberId]'s scooter dies at waypoint
  /// [waypointIndex]. The surface exit is [evaluateSurface].
  ExitOutcome evaluate({
    required domain.DivePlan plan,
    required DpvMission mission,
    required int waypointIndex,
    required String failedMemberId,
    required MissionExitMode mode,
    String? towerId,
  }) {
    if (mode == MissionExitMode.surface) {
      throw ArgumentError.value(
        mode,
        'mode',
        'the surface exit has its own evaluation',
      );
    }
    final exitSpeed = mode == MissionExitMode.swim
        ? slowestSwimSpeedMps(mission.team)
        : towSpeedMps(
            mission: mission,
            failedMemberId: failedMemberId,
            towerId: towerId!,
          );
    final outbound = builder.outbound(
      plan: plan,
      mission: mission,
      throughLegIndex: waypointIndex,
      speedMps: cruiseSpeedMps(mission.team),
    );
    final failureRuntime = outbound.waypointArrivalSeconds[waypointIndex];
    final result = exits.evaluate(
      plan: plan,
      outboundSegments: outbound.segments,
      failureRuntimeSeconds: failureRuntime,
      exitLegs: exitLegsFor(mission, waypointIndex),
      exitSpeedMps: exitSpeed,
      divers: [
        for (final member in mission.team)
          ExitDiver(
            id: member.id,
            sacBottom: member.sacBottom,
            stressed: member.id == failedMemberId,
          ),
      ],
    );
    final tower = mode == MissionExitMode.tow ? towerId : null;
    if (result.blockedByCurrent) {
      return ExitOutcome(
        mode: mode,
        towerId: tower,
        feasible: false,
        exitBottomSeconds: 0,
        ttsSeconds: 0,
        exitLitersByMember: const {},
        blockedByCurrent: true,
      );
    }

    final batteryShortfall = <String>{};
    for (final member in mission.team) {
      if (member.id == failedMemberId) continue;
      final tows = mode == MissionExitMode.tow && member.id == towerId;
      final powered =
          failureRuntime +
          (mode == MissionExitMode.tow && !tows ? result.exitBottomSeconds : 0);
      final fraction = battery.burnFraction(
        scooter: member.scooter,
        poweredSeconds: powered,
        towingSeconds: tows ? result.exitBottomSeconds : 0,
      );
      if (!battery.withinReserve(
        burnFraction: fraction,
        reserveFraction: mission.batteryReserveFraction,
      )) {
        batteryShortfall.add(member.id);
      }
    }

    return ExitOutcome(
      mode: mode,
      towerId: tower,
      feasible:
          result.gasShortfallMemberIds.isEmpty && batteryShortfall.isEmpty,
      exitBottomSeconds: result.exitBottomSeconds,
      ttsSeconds: result.ttsSeconds,
      exitLitersByMember: result.exitLitersByMember,
      gasShortfallMemberIds: result.gasShortfallMemberIds,
      batteryShortfallMemberIds: batteryShortfall,
    );
  }

  /// Open water: ascend at waypoint [waypointIndex], then swim at the
  /// surface straight to the entry or to the waypoint's shore exit and walk.
  ///
  /// The ascent does not depend on whose scooter failed, so the result is
  /// shared by every member. Surface swimming is not charged gas and ignores
  /// current. The fastest surface route is chosen, among those within the
  /// mission's surface swim limit when one is set; when none is within it,
  /// the fastest route is reported and the exit is infeasible.
  ExitOutcome evaluateSurface({
    required domain.DivePlan plan,
    required DpvMission mission,
    required int waypointIndex,
  }) {
    final outbound = builder.outbound(
      plan: plan,
      mission: mission,
      throughLegIndex: waypointIndex,
      speedMps: cruiseSpeedMps(mission.team),
    );
    final result = exits.evaluate(
      plan: plan,
      outboundSegments: outbound.segments,
      failureRuntimeSeconds: outbound.waypointArrivalSeconds[waypointIndex],
      exitLegs: const [],
      exitSpeedMps: 0,
      divers: [
        for (final member in mission.team)
          ExitDiver(id: member.id, sacBottom: member.sacBottom),
      ],
    );

    final swimSpeed = slowestSwimSpeedMps(mission.team);
    if (swimSpeed <= 0) {
      throw ArgumentError.value(swimSpeed, 'swimSpeed', 'no surface swim');
    }
    final shore = mission.legs[waypointIndex].shoreExit;
    final routes = <({double swimM, double walkM, bool viaShore})>[
      (
        swimM: waypointPositions(mission.legs)[waypointIndex].distanceHomeM,
        walkM: 0.0,
        viaShore: false,
      ),
      // A walk needs a walking speed; a shore right at the entry does not.
      if (shore != null && (shore.walkM <= 0 || mission.walkSpeedMps > 0))
        (swimM: shore.surfaceSwimM, walkM: shore.walkM, viaShore: true),
    ];
    int seconds(({double swimM, double walkM, bool viaShore}) route) {
      final walk = route.walkM > 0 ? route.walkM / mission.walkSpeedMps : 0.0;
      return math.max(0, (route.swimM / swimSpeed + walk - 1e-6).ceil());
    }

    final limit = mission.surfaceSwimLimitM;
    final within = [
      for (final route in routes)
        if (limit == null || route.swimM <= limit) route,
    ];
    final pool = within.isEmpty ? routes : within;
    final chosen = pool.reduce((a, b) => seconds(b) < seconds(a) ? b : a);
    final exceeded = within.isEmpty;

    return ExitOutcome(
      mode: MissionExitMode.surface,
      feasible: result.gasShortfallMemberIds.isEmpty && !exceeded,
      exitBottomSeconds: 0,
      ttsSeconds: result.ttsSeconds,
      exitLitersByMember: result.exitLitersByMember,
      gasShortfallMemberIds: result.gasShortfallMemberIds,
      surfaceSeconds: seconds(chosen),
      surfaceSwimM: chosen.swimM,
      walkM: chosen.walkM,
      viaShore: chosen.viaShore,
      surfaceLimitExceeded: exceeded,
    );
  }

  /// In an overhead, seconds from waypoint [waypointIndex] to a safe surface
  /// with no failure: the way out at cruise plus the ascent.
  int overheadSafeSurfaceSeconds({
    required domain.DivePlan plan,
    required DpvMission mission,
    required int waypointIndex,
  }) {
    final cruise = cruiseSpeedMps(mission.team);
    final outbound = builder.outbound(
      plan: plan,
      mission: mission,
      throughLegIndex: waypointIndex,
      speedMps: cruise,
    );
    final result = exits.evaluate(
      plan: plan,
      outboundSegments: outbound.segments,
      failureRuntimeSeconds: outbound.waypointArrivalSeconds[waypointIndex],
      exitLegs: retraceExitLegs(mission, waypointIndex),
      exitSpeedMps: cruise,
      divers: const [],
    );
    return result.exitBottomSeconds + result.ttsSeconds;
  }
}
```

In `mission_engine.dart`, the environment helper moved: replace `MissionScenarioService.environmentFor(plan)` with `ExitPathEvaluator.environmentFor(plan)` and add `import 'package:submersion/features/planner/domain/services/mission/exit_path_evaluator.dart';`.

- [ ] **Step 5: Run the tests**

```bash
flutter test test/features/planner/mission/exit_path_evaluator_test.dart test/features/planner/mission/mission_scenario_open_water_test.dart test/features/planner/mission/mission_scenario_service_test.dart test/features/planner/mission/mission_engine_test.dart
```

Expected: PASS. The existing scenario suite exercises the refactored overhead path and must not change.

- [ ] **Step 6: Format and commit**

```bash
dart format lib/features/planner/domain test/features/planner/mission
git add lib/features/planner/domain/services/mission/exit_path_evaluator.dart lib/features/planner/domain/services/mission/mission_scenario_service.dart lib/features/planner/domain/services/mission/mission_engine.dart test/features/planner/mission/exit_path_evaluator_test.dart test/features/planner/mission/mission_scenario_open_water_test.dart
git commit -m "feat(planner): evaluate DPV exits in open water through a scooter-free evaluator

Refs #2086"
```

---

### Task 7: Engine and member analysis

**Files:**
- Modify: `lib/features/planner/domain/entities/mission/mission_outcome.dart` (`WaypointOutcome`)
- Modify: `lib/features/planner/domain/services/mission/mission_engine.dart`
- Modify: `lib/features/planner/domain/services/mission/mission_member_analysis.dart`
- Modify: `test/features/planner/mission/mission_engine_test.dart` (one expectation)
- Modify: `test/features/planner/mission/mission_value_semantics_test.dart` (waypoint fixture)
- Test: `test/features/planner/mission/mission_engine_open_water_test.dart`

**Interfaces:**
- Consumes: Tasks 3, 5 and 6.
- Produces: `WaypointOutcome.directDistanceHomeM` (double, required) and `WaypointOutcome.safeSurfaceSeconds` (`int?`, required; null when it could not be computed).

- [ ] **Step 1: Write the failing test**

```dart
// test/features/planner/mission/mission_engine_open_water_test.dart
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
import 'package:submersion/features/planner/domain/entities/mission/shore_exit.dart';
import 'package:submersion/features/planner/domain/services/mission/mission_engine.dart';

const _air = GasMix(o2: 21);

domain.DivePlan _plan() => domain.DivePlan(
  id: 'plan-1',
  name: 'Lake',
  gfLow: 40,
  gfHigh: 80,
  descentRate: 18,
  ascentRate: 9,
  sacBottom: 15,
  reservePressure: 50,
  salinityPpt: DiveEnvironment.salinityPptFromDensity(
    DiveEnvironment.en13319Density,
  ),
  tanks: const [
    DiveTank(
      id: 'back',
      volume: 40,
      startPressure: 230,
      gasMix: _air,
      role: TankRole.backGas,
    ),
  ],
  createdAt: DateTime(2026, 9, 25),
  updatedAt: DateTime(2026, 9, 25),
);

MissionMember _member(String id, int order, {double swim = 0.2}) =>
    MissionMember(
      id: id,
      order: order,
      displayName: id,
      sacBottom: 15,
      swimSpeedMps: swim,
      scooter: ScooterSpec(
        name: 'S-$id',
        ratedSpeedMps: 0.5,
        burnTimeSeconds: 7200,
      ),
    );

/// Three 200 m legs due north at 20 m: waypoints 200, 400 and 600 m out.
List<MissionLeg> _legs({ShoreExit? shoreAtSecond}) => [
  for (var i = 0; i < 3; i++)
    MissionLeg(
      id: 'L$i',
      order: i,
      label: 'W$i',
      distanceM: 200,
      depthM: 20,
      headingDeg: 0,
      shoreExit: i == 1 ? shoreAtSecond : null,
    ),
];

/// Sets toward the north: the scooters make 0.8 m/s out and 0.2 m/s home,
/// and a 0.2 m/s swimmer makes no headway home at all.
const _northerly = CurrentVector(speedMps: 0.3, setsTowardDeg: 0);

void main() {
  const engine = MissionEngine();

  test('a solo lake diver: straight-line distances, a surface way out, no tow', () {
    final outcome = engine.compute(
      plan: _plan(),
      mission: DpvMission(
        legs: _legs(),
        team: [_member('a', 0)],
        environment: MissionEnvironment.openWater,
      ),
    );
    expect(outcome.waypoints.map((w) => w.directDistanceHomeM), [
      closeTo(200, 1e-6),
      closeTo(400, 1e-6),
      closeTo(600, 1e-6),
    ]);
    for (final waypoint in outcome.waypoints) {
      final a = waypoint.members.single;
      expect(a.tow, isNull, reason: 'a solo diver has no buddy to tow them');
      expect(a.surface, isNotNull);
      expect(a.survivable, isTrue);
      expect(waypoint.safeSurfaceSeconds, a.surface!.ttsSeconds);
    }
    expect(outcome.abandonmentIndex, 2);
    expect(outcome.constraint, isNull);
  });

  test('a buddy can tow in a lake, straight home at tow speed', () {
    final outcome = engine.compute(
      plan: _plan(),
      mission: DpvMission(
        legs: _legs(),
        team: [_member('a', 0), _member('b', 1)],
        environment: MissionEnvironment.openWater,
      ),
    );
    final b = outcome.waypoints.last.members.firstWhere(
      (m) => m.memberId == 'b',
    );
    expect(b.tow!.towerId, 'a');
    expect(b.tow!.exitBottomSeconds, 2000); // 600 m at 0.3 m/s
    expect(b.tow!.feasible, isTrue);
  });

  test('a surface swim limit binds when nothing underwater can get home', () {
    final outcome = engine.compute(
      plan: _plan(),
      mission: DpvMission(
        legs: _legs(),
        team: [_member('a', 0)],
        environment: MissionEnvironment.openWater,
        defaultCurrent: _northerly,
        surfaceSwimLimitM: 300,
      ),
    );
    expect(outcome.waypoints.map((w) => w.survivable), [true, false, false]);
    expect(outcome.waypoints[1].members.single.swim.blockedByCurrent, isTrue);
    expect(outcome.abandonmentIndex, 0);
    expect(
      outcome.constraint,
      const MissionConstraint(
        memberId: 'a',
        factor: MissionBindingFactor.surfaceSwimLimit,
        waypointIndex: 1,
      ),
    );
  });

  test('a shore exit and a walk rescue a waypoint the limit would lose', () {
    final outcome = engine.compute(
      plan: _plan(),
      mission: DpvMission(
        legs: _legs(
          shoreAtSecond: const ShoreExit(surfaceSwimM: 100, walkM: 300),
        ),
        team: [_member('a', 0)],
        environment: MissionEnvironment.openWater,
        defaultCurrent: _northerly,
        surfaceSwimLimitM: 300,
      ),
    );
    final second = outcome.waypoints[1].members.single.surface!;
    expect(second.viaShore, isTrue);
    expect(second.surfaceSeconds, 875);
    expect(outcome.abandonmentIndex, 1);
    expect(outcome.constraint!.waypointIndex, 2);
    expect(outcome.constraint!.factor, MissionBindingFactor.surfaceSwimLimit);
  });

  test('a solo diver in an overhead the current closes is blocked by current', () {
    final outcome = engine.compute(
      plan: _plan(),
      mission: DpvMission(
        legs: _legs(),
        team: [_member('a', 0)],
        defaultCurrent: _northerly,
      ),
    );
    expect(outcome.waypoints.first.members.single.surface, isNull);
    expect(outcome.abandonmentIndex, isNull);
    expect(
      outcome.constraint,
      const MissionConstraint(
        memberId: 'a',
        factor: MissionBindingFactor.blockedByCurrent,
        waypointIndex: 0,
      ),
    );
  });

  test('an overhead reports a growing time to the next safe surface', () {
    final outcome = engine.compute(
      plan: _plan(),
      mission: DpvMission(
        legs: _legs(),
        team: [_member('a', 0), _member('b', 1)],
      ),
    );
    final times = outcome.waypoints.map((w) => w.safeSurfaceSeconds!).toList();
    expect(times[0], greaterThan(0));
    expect(times[1], greaterThan(times[0]));
    expect(times[2], greaterThan(times[1]));
  });

  test('a member who cannot swim is a blocking issue, not a crash', () {
    final outcome = engine.compute(
      plan: _plan(),
      mission: DpvMission(
        legs: _legs(),
        team: [_member('a', 0, swim: 0)],
        environment: MissionEnvironment.openWater,
      ),
    );
    expect(outcome.isBlocked, isTrue);
    expect(
      outcome.issues.map((i) => (i.type, i.memberId)),
      contains((MissionIssueType.memberSwimSpeedUnset, 'a')),
    );
  });
}
```

The surface-limit test's vectors: the straight swim home heads 180 into a current setting toward 000 at 0.3 m/s, so a 0.2 m/s swimmer is blocked. The surface swims home are 200, 400 and 600 m; only the first is within 300 m.

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/features/planner/mission/mission_engine_open_water_test.dart`
Expected: FAIL, "The getter 'directDistanceHomeM' isn't defined".

- [ ] **Step 3: Add the waypoint fields**

In `mission_outcome.dart`, `WaypointOutcome`, after `arrivalRuntimeSeconds`:

```dart

  /// Straight-line distance from the waypoint back to the entry, in metres.
  final double directDistanceHomeM;

  /// Seconds to the next safe surface with no failure: in an overhead the
  /// way out at cruise plus the ascent, in open water the ascent alone. Null
  /// when it could not be computed.
  final int? safeSurfaceSeconds;
```

Constructor, after `required this.arrivalRuntimeSeconds,`:

```dart
    required this.directDistanceHomeM,
    required this.safeSurfaceSeconds,
```

`props`, after `arrivalRuntimeSeconds,`: `directDistanceHomeM,` and `safeSurfaceSeconds,`.

In `test/features/planner/mission/mission_value_semantics_test.dart`, in the `waypoint(...)` builder, after `arrivalRuntimeSeconds: 667,`:

```dart
      directDistanceHomeM: 300,
      safeSurfaceSeconds: 900,
```

- [ ] **Step 4: Update the engine**

In `mission_engine.dart`:

1. Add imports: `dpv_mission.dart` is already imported; add `import 'package:submersion/features/planner/domain/services/mission/mission_geometry.dart';`.

2. In `_validate`, inside the member loop after the SAC check:

```dart
      if (member.swimSpeedMps <= 0) {
        issues.add(
          MissionIssue(
            type: MissionIssueType.memberSwimSpeedUnset,
            severity: MissionIssueSeverity.blocking,
            memberId: member.id,
          ),
        );
      }
```

3. After `final route = mission.copyWith(legs: legs);` add:

```dart
    final positions = waypointPositions(legs);
    final openWater = route.environment == MissionEnvironment.openWater;
```

4. In the waypoint loop, directly before `final members = <MemberWaypointOutcome>[];`:

```dart
      final surface = openWater
          ? _evaluateSurface(plan: plan, mission: route, k: k, issues: issues)
          : null;
      final safeSurfaceSeconds = openWater
          ? surface?.ttsSeconds
          : _overheadSafeSurface(plan: plan, mission: route, k: k);
```

5. In the `MemberWaypointOutcome(` construction, add `surface: surface,` after `tow: best,`, and replace the `survivable:` line with:

```dart
            survivable:
                swim.feasible ||
                (best?.feasible ?? false) ||
                (surface?.feasible ?? false),
```

6. In the `WaypointOutcome(` construction, after `arrivalRuntimeSeconds: arrival,`:

```dart
          directDistanceHomeM: positions[k].distanceHomeM,
          safeSurfaceSeconds: safeSurfaceSeconds,
```

7. Add the two helpers after `_evaluate`:

```dart
  /// The shared open-water surface exit at waypoint [k], or null (with a
  /// warning) when its scenario cannot be run.
  ExitOutcome? _evaluateSurface({
    required domain.DivePlan plan,
    required DpvMission mission,
    required int k,
    required List<MissionIssue> issues,
  }) {
    try {
      return scenarios.evaluateSurface(
        plan: plan,
        mission: mission,
        waypointIndex: k,
      );
    } on Object {
      issues.add(
        MissionIssue(
          type: MissionIssueType.scenarioFailed,
          severity: MissionIssueSeverity.warning,
          legId: mission.legs[k].id,
        ),
      );
      return null;
    }
  }

  /// The overhead time to a safe surface from waypoint [k], or null when it
  /// cannot be computed.
  int? _overheadSafeSurface({
    required domain.DivePlan plan,
    required DpvMission mission,
    required int k,
  }) {
    try {
      return scenarios.overheadSafeSurfaceSeconds(
        plan: plan,
        mission: mission,
        waypointIndex: k,
      );
    } on Object {
      return null;
    }
  }
```

- [ ] **Step 5: Update the member analysis**

In `mission_member_analysis.dart`, replace the `} else if (!own.survivable) { ... }` block (the one that reads `own.swim.gasShortfallMemberIds`) with:

```dart
      } else if (!own.survivable) {
        factor = _whyUnsurvivable(member.id, own);
      }
```

Add, before `MissionConstraint? constraint(`:

```dart
  /// Why none of [own]'s exits works. The swim and the surface exit burn no
  /// battery, so their gas is the clean witness for a gas reason; then the
  /// surface limit, a possible tow that failed, and a current that closes
  /// every underwater exit.
  MissionBindingFactor _whyUnsurvivable(
    String memberId,
    MemberWaypointOutcome own,
  ) {
    final witnesses = [own.swim, if (own.surface != null) own.surface!];
    if (witnesses.any((e) => e.gasShortfallMemberIds.contains(memberId))) {
      return MissionBindingFactor.ownGas;
    }
    if (witnesses.any((e) => e.gasShortfallMemberIds.isNotEmpty)) {
      return MissionBindingFactor.teamGas;
    }
    if (own.surface?.surfaceLimitExceeded ?? false) {
      return MissionBindingFactor.surfaceSwimLimit;
    }
    final tow = own.tow;
    if (tow != null && !tow.blockedByCurrent) {
      return MissionBindingFactor.noFeasibleTow;
    }
    return MissionBindingFactor.blockedByCurrent;
  }
```

In the turn-pressure loop, replace `for (final exit in [other.swim, other.tow]) {` with `for (final exit in [other.swim, other.tow, other.surface]) {`.

In `test/features/planner/mission/mission_engine_test.dart`, the test that expects `MissionBindingFactor.noFeasibleTow` (both the swim and the tow are blocked by current) now expects `MissionBindingFactor.blockedByCurrent`: nothing about a tow was possible there. Change that expectation, and rename the test to `'a current that closes every exit binds as blocked by current'`.

- [ ] **Step 6: Run the tests and check the file sizes**

```bash
flutter test test/features/planner/mission/
wc -l lib/features/planner/domain/services/mission/*.dart lib/features/planner/domain/entities/mission/*.dart
```

Expected: PASS; no file above 400 lines.

- [ ] **Step 7: Format and commit**

```bash
dart format lib/features/planner/domain test/features/planner/mission
git add lib/features/planner/domain/entities/mission/mission_outcome.dart lib/features/planner/domain/services/mission/mission_engine.dart lib/features/planner/domain/services/mission/mission_member_analysis.dart test/features/planner/mission/mission_engine_test.dart test/features/planner/mission/mission_value_semantics_test.dart test/features/planner/mission/mission_engine_open_water_test.dart
git commit -m "feat(planner): report open-water exits, solo divers and time to safe surface

Refs #2086"
```

---

### Task 8: Verification

- [ ] **Step 1: Format and analyze the whole project**

```bash
dart format . && git status --short
flutter analyze
```

Expected: no formatter changes; `No issues found!`.

- [ ] **Step 2: Architecture guards**

Run: `flutter test test/architecture/`
Expected: PASS.

- [ ] **Step 3: One full suite run, in the background, with nothing else running**

Run `flutter test --reporter=failures-only`, redirected to a file (never piped into `grep`, which hides the exit status). Expected: exit 0.

- [ ] **Step 4: Stop before pushing**

Ask the user before pushing to PR #2138 and before editing the PR description. The description should gain a short "Revision 2026-09-25" paragraph naming the speed-over-ground correction, open water, shore exits, solo divers and the exit evaluator.

---

## Self-review

**Spec coverage.** Speed over ground (Task 1). Positions (Task 3). Exits per environment, straight home, surface exit with shore and walk, surface swim limit, surface not charged gas (Tasks 3, 6). Exit path evaluator with no scooter concept (Task 6). Solo divers: no tow, "no buddy" as a null tow (Tasks 5, 7). Split binding reasons (Tasks 5, 7). Time to the next safe surface per waypoint, straight-line distance home (Task 7). Turn pressure over every feasible exit including the surface (Task 7). Error handling: exits blocked by current reported per exit without running the engine (Task 6); an untraversable cruise leg by cross current (Task 1 through the existing engine cut). Persistence, codec and UI fields are PR 2 and PR 3.

**Type consistency.** `ExitLeg` (Task 3) is consumed by `appendExitLegs` (Task 4) and `ExitPathEvaluator` (Task 6). `kMinExitLegM` is defined in `mission_geometry.dart` and used by the builder and the evaluator. `MissionExitMode.surface` and the new `ExitOutcome` fields (Task 5) are produced by `evaluateSurface` (Task 6) and read by the engine and analysis (Task 7). `WaypointOutcome`'s new required fields land in Task 7 together with the only producer, the engine.

**Review Focus coverage.** `|x| == v` (Task 1), headings outside 0 to 360 (Tasks 1 and 3), a route ending at the entry (Tasks 3 and 6), a walk with no walking speed (Task 6), a swim speed of zero (Task 7).
