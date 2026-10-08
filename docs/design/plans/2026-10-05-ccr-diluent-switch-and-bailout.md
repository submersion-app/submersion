# CCR Diluent Switches and OC Bailout Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task, inline in this session. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Gas switches on a CCR dive change the analysed breathing gas: a diluent switch changes the loop's He:N2 split, and a switch to an open-circuit cylinder is a bailout that tissues, ppO2, CNS/OTU, gas overlays and the simulated ascent all follow.

**Architecture:** A pure classifier turns a CCR dive's gas switches plus cylinder roles into a timeline of diluent and open-circuit changes. The CCR segment builder (moved to a new domain file) walks samples with that timeline, emitting setpoint-bearing loop segments or `setpoint: null` open-circuit segments. The engine uses the loop ascent on loop samples and the supplied OC plan on bailout samples, and the analysis service computes ppO2 from the breathed gas on bailout samples.

**Tech Stack:** Flutter/Dart, Riverpod, Drift (integration test only), flutter_test.

**Spec:** `docs/design/specs/2026-10-05-ccr-diluent-switch-and-bailout-design.md`

## Revisions after implementation

The tasks below are the plan as executed; these later decisions supersede
parts of them (the spec is current):

- `TankRole.backGas` is no longer an open-circuit role on a CCR dive. File
  imports give untagged cylinders that role, so `ccrCylinderRole` reads it as
  the O2 supply at 99% O2 or more and otherwise as a diluent, both when
  classifying switches and when resolving the initial diluent (Task 1's
  `backGas` test case and role table are stale).
- `buildAvailableGases(excludeLoopCylinders:)` (Task 5) became
  `forCcrBailout:`: the diluent is left out, the O2 supply is kept under either
  ascent-gas setting, and the gases come from the analysed computer's tanks.
- The ppO2/ppN2/ppHe chart lines are drawn straight between samples.

## Global Constraints

- A CCR dive with no recorded switches analyses exactly as before.
- No loop ppO2 information (no curve, no dive-level setpoint) still returns a null schedule (withheld tissues, #2593).
- SCR ignores gas switches.
- No schema, importer, sync or planner changes.
- No em-dashes in code, comments, commits or docs; no emojis; no AI-tool attribution anywhere.
- `dart format .` and `flutter analyze` clean before every commit; `test/architecture/` after adding the new `lib/` file.

## Review Focus

1. A switch exactly at the first sample: it replaces the seed instead of stacking a zero-length segment (Task 2 test "a change at the first sample replaces the seed").
2. A return to the loop between two samples: the setpoint comes from the sample before the switch, not after (Task 2 test "a change between samples takes the loop ppO2 seen before it").
3. A switch to a cylinder this computer does not own, or a deleted cylinder: dropped, not treated as a bailout (Task 1 test "a switch to an unknown tank is dropped").
4. A CCR dive whose only switch is to the O2 supply (common on Shearwater imports): analysis unchanged (Task 1 test "an O2 supply switch on the loop is dropped").
5. A bailout and return to an identical loop at the same timestamp: no redundant duplicate segment (Task 2 test "same-timestamp bailout and return leaves no redundant segment").

---

### Task 0: Before screenshots

**Files:**
- Create (scratchpad, not committed): `<scratchpad>/ccr_bailout_fixture.ssrf`

- [ ] **Step 1: Write the fixture dive**

A CCR dive to 30 m on air diluent at setpoint 1.3, a diluent switch to 10/50 at 12:00, a bailout to the 21/35 bailout cylinder at 25:00, then an ascent with a switch to EAN50 at 21 m. Cylinder indices: 0 diluent air, 1 O2, 2 diluent 10/50, 3 bailout 21/35, 4 bailout EAN50.

```xml
<divelog program='subsurface' version='3'>
<dives>
<dive number='577' date='2026-10-01' time='10:00:00' duration='50:00 min'>
  <cylinder size='3.0 l' workpressure='200.0 bar' description='Dil air' o2='21.0%' use='diluent' />
  <cylinder size='3.0 l' workpressure='200.0 bar' description='O2' o2='100.0%' use='oxygen' />
  <cylinder size='3.0 l' workpressure='200.0 bar' description='Dil 10/50' o2='10.0%' he='50.0%' use='diluent' />
  <cylinder size='11.1 l' workpressure='207.0 bar' description='Bailout 21/35' o2='21.0%' he='35.0%' use='bailout' />
  <cylinder size='11.1 l' workpressure='207.0 bar' description='Bailout 50' o2='50.0%' use='bailout' />
  <divecomputer model='Fixture CCR' dctype='CCR'>
  <depth max='30.0 m' mean='22.0 m' />
  <event time='12:00 min' type='25' flags='3' name='gaschange' cylinder='2' />
  <event time='25:00 min' type='25' flags='4' name='gaschange' cylinder='3' />
  <event time='33:00 min' type='25' flags='5' name='gaschange' cylinder='4' />
  <sample time='0:00 min' depth='0.0 m' po2='1.3 bar' />
  <sample time='2:00 min' depth='30.0 m' />
  <sample time='25:00 min' depth='30.0 m' />
  <sample time='31:00 min' depth='21.0 m' />
  <sample time='36:00 min' depth='12.0 m' />
  <sample time='40:00 min' depth='6.0 m' />
  <sample time='48:00 min' depth='3.0 m' />
  <sample time='50:00 min' depth='0.0 m' />
  </divecomputer>
</dive>
</dives>
</divelog>
```

Fill in intermediate samples every 30 s with a small Python script in the scratchpad so the profile is smooth (linear interpolation between the depths above). Keep `po2='1.3 bar'` on the first sample only; the parser forward-fills it.

- [ ] **Step 2: Launch the app from this worktree (pre-change code) with the `run` skill, import the fixture via the universal import wizard, and open the dive's detail page.**

- [ ] **Step 3: Capture `01-dive-profile-ccr-bailout-before.png`** (desktop width, light mode): the profile chart with the ppO2 overlay and ceiling/TTS visible, plus `02-dive-o2-tox-ccr-bailout-before.png` (the CNS/OTU summary). Save to the scratchpad.

Note the dive id; the after screenshots reuse it, and the dive is deleted from the dev logbook once the after screenshots are taken.

---

### Task 1: Classify CCR gas switches

**Files:**
- Create: `lib/features/dive_log/domain/services/ccr_gas_schedule.dart`
- Test: `test/features/dive_log/domain/services/ccr_gas_schedule_test.dart`

**Interfaces:**
- Produces: `enum CcrGasChangeKind { diluent, openCircuit }`; `class CcrGasChange { int timestamp; CcrGasChangeKind kind; double fN2; double fHe; }` (Equatable, const constructor); `List<CcrGasChange> classifyCcrGasChanges(List<GasSwitchWithTank> switches, List<DiveTank> tanks)` returning changes ordered by timestamp then switch id.

- [ ] **Step 1: Write the failing tests**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/deco/constants/buhlmann_coefficients.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/gas_switch.dart';
import 'package:submersion/features/dive_log/domain/services/ccr_gas_schedule.dart';

const _dilAir = DiveTank(
  id: 'dil-air',
  gasMix: GasMix(),
  role: TankRole.diluent,
);
const _dilTx = DiveTank(
  id: 'dil-tx',
  gasMix: GasMix(o2: 10, he: 50),
  role: TankRole.diluent,
);
const _o2 = DiveTank(
  id: 'o2',
  gasMix: GasMix(o2: 100),
  role: TankRole.oxygenSupply,
);
const _bail = DiveTank(
  id: 'bail',
  gasMix: GasMix(o2: 21, he: 35),
  role: TankRole.bailout,
);
const _tanks = [_dilAir, _dilTx, _o2, _bail];

GasSwitchWithTank _switch(String id, int timestamp, DiveTank tank) =>
    GasSwitchWithTank(
      gasSwitch: GasSwitch(
        id: id,
        diveId: 'd',
        timestamp: timestamp,
        tankId: tank.id,
        createdAt: DateTime.utc(2026, 10, 5),
      ),
      tankName: tank.id,
      gasMix: tank.id,
      o2Fraction: tank.gasMix.o2 / 100.0,
      heFraction: tank.gasMix.he / 100.0,
    );

void main() {
  group('classifyCcrGasChanges', () {
    test('a diluent switch on the loop is a diluent change', () {
      final changes = classifyCcrGasChanges([
        _switch('a', 600, _dilTx),
      ], _tanks);
      expect(changes, hasLength(1));
      expect(changes.single.timestamp, 600);
      expect(changes.single.kind, CcrGasChangeKind.diluent);
      expect(changes.single.fN2, closeTo(0.4, 1e-9));
      expect(changes.single.fHe, closeTo(0.5, 1e-9));
    });

    test('an air diluent uses the air N2 fraction', () {
      final changes = classifyCcrGasChanges([
        _switch('a', 600, _dilAir),
      ], _tanks);
      expect(changes.single.fN2, airN2Fraction);
    });

    for (final role in [
      TankRole.bailout,
      TankRole.deco,
      TankRole.stage,
      TankRole.backGas,
      TankRole.pony,
      TankRole.sidemountLeft,
      TankRole.sidemountRight,
    ]) {
      test('a switch to a ${role.name} cylinder is open circuit', () {
        final tank = DiveTank(
          id: 'oc',
          gasMix: const GasMix(o2: 50),
          role: role,
        );
        final changes = classifyCcrGasChanges([
          _switch('a', 900, tank),
        ], [..._tanks, tank]);
        expect(changes.single.kind, CcrGasChangeKind.openCircuit);
        expect(changes.single.fN2, closeTo(0.5, 1e-9));
      });
    }

    test('an O2 supply switch on the loop is dropped', () {
      expect(classifyCcrGasChanges([_switch('a', 300, _o2)], _tanks), isEmpty);
    });

    test('an O2 supply switch after a bailout is open circuit on O2', () {
      final changes = classifyCcrGasChanges([
        _switch('a', 900, _bail),
        _switch('b', 1500, _o2),
      ], _tanks);
      expect(changes.map((c) => c.kind), [
        CcrGasChangeKind.openCircuit,
        CcrGasChangeKind.openCircuit,
      ]);
      expect(changes.last.fN2, closeTo(0.0, 1e-9));
      expect(changes.last.fHe, closeTo(0.0, 1e-9));
    });

    test('a diluent switch after a bailout returns to the loop', () {
      final changes = classifyCcrGasChanges([
        _switch('a', 900, _bail),
        _switch('b', 1200, _dilAir),
      ], _tanks);
      expect(changes.last.kind, CcrGasChangeKind.diluent);
      expect(changes.last.timestamp, 1200);
    });

    test('a switch to an unknown tank is dropped', () {
      const stranger = DiveTank(
        id: 'other-computer',
        gasMix: GasMix(o2: 32),
        role: TankRole.backGas,
      );
      expect(
        classifyCcrGasChanges([_switch('a', 900, stranger)], _tanks),
        isEmpty,
      );
    });

    test('changes are ordered by timestamp, then switch id', () {
      final changes = classifyCcrGasChanges([
        _switch('z', 1200, _dilAir),
        _switch('b', 600, _bail),
        _switch('a', 600, _dilTx),
      ], _tanks);
      expect(changes.map((c) => c.timestamp), [600, 600, 1200]);
      // 'a' (diluent) precedes 'b' (bailout) at 600, so the state machine
      // is on open circuit when 'z' returns it to the loop.
      expect(changes.map((c) => c.kind), [
        CcrGasChangeKind.diluent,
        CcrGasChangeKind.openCircuit,
        CcrGasChangeKind.diluent,
      ]);
    });
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/features/dive_log/domain/services/ccr_gas_schedule_test.dart`
Expected: FAIL, compile error (`ccr_gas_schedule.dart` does not exist).

- [ ] **Step 3: Implement**

```dart
import 'package:equatable/equatable.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/deco/constants/buhlmann_coefficients.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/gas_switch.dart';

/// What a recorded gas switch means on a closed-circuit dive (issue #577).
enum CcrGasChangeKind {
  /// The diver is on the loop, breathing over this diluent.
  diluent,

  /// The diver has bailed out and breathes this cylinder open circuit.
  openCircuit,
}

/// A change of breathing gas on a CCR dive, derived from a gas switch and
/// the role of the cylinder switched to.
class CcrGasChange extends Equatable {
  const CcrGasChange({
    required this.timestamp,
    required this.kind,
    required this.fN2,
    this.fHe = 0.0,
  });

  /// Seconds from dive start.
  final int timestamp;
  final CcrGasChangeKind kind;

  /// Nitrogen fraction (0.0-1.0) of the diluent or open-circuit gas.
  final double fN2;

  /// Helium fraction (0.0-1.0) of the diluent or open-circuit gas.
  final double fHe;

  @override
  List<Object?> get props => [timestamp, kind, fN2, fHe];
}

/// Classifies a CCR dive's gas switches by the role of the cylinder switched
/// to. A diluent switch puts the diver on the loop over that diluent (ending a
/// bailout); a switch to any open-circuit cylinder is a bailout onto it. The
/// O2 supply feeds the loop, so a switch to it while on the loop is dropped;
/// once bailed out it is open circuit on O2.
///
/// [tanks] is the cylinder set the analysed computer breathed: a switch to a
/// cylinder outside it is dropped. The result is ordered by timestamp, ties
/// broken by switch id as the open-circuit schedule does.
List<CcrGasChange> classifyCcrGasChanges(
  List<GasSwitchWithTank> switches,
  List<DiveTank> tanks,
) {
  final roles = {for (final tank in tanks) tank.id: tank.role};
  final ordered =
      switches.where((s) => roles.containsKey(s.gasSwitch.tankId)).toList()
        ..sort((a, b) {
          final byTime = a.gasSwitch.timestamp.compareTo(b.gasSwitch.timestamp);
          return byTime != 0 ? byTime : a.gasSwitch.id.compareTo(b.gasSwitch.id);
        });

  var onLoop = true;
  final changes = <CcrGasChange>[];
  for (final gasSwitch in ordered) {
    final kind = switch (roles[gasSwitch.gasSwitch.tankId]!) {
      TankRole.diluent => CcrGasChangeKind.diluent,
      TankRole.oxygenSupply => onLoop ? null : CcrGasChangeKind.openCircuit,
      _ => CcrGasChangeKind.openCircuit,
    };
    if (kind == null) continue;
    onLoop = kind == CcrGasChangeKind.diluent;
    changes.add(
      CcrGasChange(
        timestamp: gasSwitch.gasSwitch.timestamp,
        kind: kind,
        fN2: gasSwitch.isAir ? airN2Fraction : gasSwitch.n2Fraction,
        fHe: gasSwitch.heFraction,
      ),
    );
  }
  return changes;
}
```

- [ ] **Step 4: Run to verify it passes**

Run: `flutter test test/features/dive_log/domain/services/ccr_gas_schedule_test.dart`
Expected: PASS.

- [ ] **Step 5: Format, analyze, architecture guards, commit**

```bash
dart format lib/features/dive_log/domain/services/ccr_gas_schedule.dart test/features/dive_log/domain/services/ccr_gas_schedule_test.dart
flutter analyze lib/features/dive_log/domain/services/ccr_gas_schedule.dart test/features/dive_log/domain/services/ccr_gas_schedule_test.dart
flutter test test/architecture/
git add lib/features/dive_log/domain/services/ccr_gas_schedule.dart test/features/dive_log/domain/services/ccr_gas_schedule_test.dart
git commit -m "feat(dive-log): classify CCR gas switches by cylinder role"
```

---

### Task 2: CCR segment builder with gas changes

Moves `buildCcrProfileGasSegments` from the provider into `ccr_gas_schedule.dart`, adds `gasChanges`, and seeds at the first profile timestamp.

**Files:**
- Modify: `lib/features/dive_log/domain/services/ccr_gas_schedule.dart`
- Modify: `lib/features/dive_log/presentation/providers/profile_analysis_provider.dart:284-349` (remove the builder; import the domain file)
- Modify (imports only): `test/core/deco/cns_method_fixture_cross_validation_test.dart`, `test/core/deco/ccr_loop_deco_fixture_test.dart`, `test/core/deco/tts_fixture_shape_test.dart`, `test/features/dive_log/presentation/providers/profile_analysis_provider_test.dart`
- Test: `test/features/dive_log/domain/services/ccr_gas_schedule_test.dart`

**Interfaces:**
- Consumes: `CcrGasChange`, `CcrGasChangeKind` (Task 1).
- Produces: `List<ProfileGasSegment>? buildCcrProfileGasSegments({required List<int> timestamps, required List<double>? loopPpO2Curve, required GasMix diluentMix, double? fallbackSetpoint, double setpointTolerance = 0.05, List<CcrGasChange> gasChanges = const []})`; `bool hasOpenCircuitBailout(List<ProfileGasSegment>? loopSchedule)`.

- [ ] **Step 1: Write the failing tests** (append a second `group` inside `main()` of the Task 1 test file; add `import 'package:submersion/core/deco/entities/profile_gas_segment.dart';`)

```dart
  group('buildCcrProfileGasSegments with gas changes', () {
    const times = [0, 60, 120, 180, 240];
    const flat = [1.3, 1.3, 1.3, 1.3, 1.3];
    const air = GasMix();

    ({int t, double fN2, double fHe, double? sp}) view(ProfileGasSegment s) =>
        (t: s.startTimestamp, fN2: s.fN2, fHe: s.fHe, sp: s.setpoint);

    CcrGasChange bailout(int t, {double fN2 = 0.5, double fHe = 0.0}) =>
        CcrGasChange(
          timestamp: t,
          kind: CcrGasChangeKind.openCircuit,
          fN2: fN2,
          fHe: fHe,
        );
    CcrGasChange diluent(int t, {double fN2 = airN2Fraction, double fHe = 0}) =>
        CcrGasChange(
          timestamp: t,
          kind: CcrGasChangeKind.diluent,
          fN2: fN2,
          fHe: fHe,
        );

    test('no changes keeps the single-diluent schedule', () {
      final segments = buildCcrProfileGasSegments(
        timestamps: times,
        loopPpO2Curve: flat,
        diluentMix: air,
      )!;
      expect(segments.map(view), [
        (t: 0, fN2: airN2Fraction, fHe: 0.0, sp: 1.3),
      ]);
    });

    test('a diluent change switches the loop inert split', () {
      final segments = buildCcrProfileGasSegments(
        timestamps: times,
        loopPpO2Curve: flat,
        diluentMix: air,
        gasChanges: [diluent(120, fN2: 0.4, fHe: 0.5)],
      )!;
      expect(segments.map(view), [
        (t: 0, fN2: airN2Fraction, fHe: 0.0, sp: 1.3),
        (t: 120, fN2: 0.4, fHe: 0.5, sp: 1.3),
      ]);
    });

    test('a bailout is open circuit and ignores loop ppO2 noise', () {
      final segments = buildCcrProfileGasSegments(
        timestamps: times,
        loopPpO2Curve: const [1.3, 1.3, 0.9, 1.6, 1.3],
        diluentMix: air,
        gasChanges: [bailout(120)],
      )!;
      expect(segments.map(view), [
        (t: 0, fN2: airN2Fraction, fHe: 0.0, sp: 1.3),
        (t: 120, fN2: 0.5, fHe: 0.0, sp: null),
      ]);
    });

    test('returning to the loop re-seeds the setpoint from the curve', () {
      final segments = buildCcrProfileGasSegments(
        timestamps: times,
        loopPpO2Curve: const [1.3, 1.3, 1.3, 1.0, 1.0],
        diluentMix: air,
        gasChanges: [bailout(120), diluent(180)],
      )!;
      expect(segments.map(view), [
        (t: 0, fN2: airN2Fraction, fHe: 0.0, sp: 1.3),
        (t: 120, fN2: 0.5, fHe: 0.0, sp: null),
        (t: 180, fN2: airN2Fraction, fHe: 0.0, sp: 1.0),
      ]);
    });

    test('a change between samples takes the loop ppO2 seen before it', () {
      final segments = buildCcrProfileGasSegments(
        timestamps: times,
        loopPpO2Curve: const [1.3, 1.3, 1.2, 1.0, 1.0],
        diluentMix: air,
        gasChanges: [bailout(90), diluent(150)],
      )!;
      expect(segments.map(view), [
        (t: 0, fN2: airN2Fraction, fHe: 0.0, sp: 1.3),
        (t: 90, fN2: 0.5, fHe: 0.0, sp: null),
        (t: 150, fN2: airN2Fraction, fHe: 0.0, sp: 1.2),
        (t: 180, fN2: airN2Fraction, fHe: 0.0, sp: 1.0),
      ]);
    });

    test('with only a fallback setpoint the loop resumes on it', () {
      final segments = buildCcrProfileGasSegments(
        timestamps: times,
        loopPpO2Curve: null,
        diluentMix: air,
        fallbackSetpoint: 1.2,
        gasChanges: [bailout(60), diluent(180)],
      )!;
      expect(segments.map(view), [
        (t: 0, fN2: airN2Fraction, fHe: 0.0, sp: 1.2),
        (t: 60, fN2: 0.5, fHe: 0.0, sp: null),
        (t: 180, fN2: airN2Fraction, fHe: 0.0, sp: 1.2),
      ]);
    });

    test('a change at the first sample replaces the seed', () {
      final segments = buildCcrProfileGasSegments(
        timestamps: times,
        loopPpO2Curve: flat,
        diluentMix: air,
        gasChanges: [bailout(0)],
      )!;
      expect(segments.map(view), [(t: 0, fN2: 0.5, fHe: 0.0, sp: null)]);
    });

    test('the seed sits at the first sample, before zero if need be', () {
      final segments = buildCcrProfileGasSegments(
        timestamps: const [-30, 30, 90],
        loopPpO2Curve: const [1.3, 1.3, 1.3],
        diluentMix: air,
        gasChanges: [bailout(-60)],
      )!;
      expect(segments.map(view), [
        (t: -30, fN2: airN2Fraction, fHe: 0.0, sp: 1.3),
      ]);
    });

    test('same-timestamp bailout and return leaves no redundant segment', () {
      final segments = buildCcrProfileGasSegments(
        timestamps: times,
        loopPpO2Curve: flat,
        diluentMix: air,
        gasChanges: [bailout(120), diluent(120)],
      )!;
      expect(segments.map(view), [
        (t: 0, fN2: airN2Fraction, fHe: 0.0, sp: 1.3),
      ]);
    });

    test('no loop ppO2 information still returns null', () {
      expect(
        buildCcrProfileGasSegments(
          timestamps: times,
          loopPpO2Curve: null,
          diluentMix: air,
          gasChanges: [bailout(60)],
        ),
        isNull,
      );
    });
  });

  group('hasOpenCircuitBailout', () {
    test('false for no schedule and for a loop-only schedule', () {
      expect(hasOpenCircuitBailout(null), isFalse);
      expect(
        hasOpenCircuitBailout(const [
          ProfileGasSegment(startTimestamp: 0, fN2: 0.79, setpoint: 1.3),
        ]),
        isFalse,
      );
    });

    test('true once a segment is open circuit', () {
      expect(
        hasOpenCircuitBailout(const [
          ProfileGasSegment(startTimestamp: 0, fN2: 0.79, setpoint: 1.3),
          ProfileGasSegment(startTimestamp: 600, fN2: 0.5),
        ]),
        isTrue,
      );
    });
  });
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/features/dive_log/domain/services/ccr_gas_schedule_test.dart`
Expected: FAIL, compile error (`buildCcrProfileGasSegments` / `hasOpenCircuitBailout` not defined in the domain file).

- [ ] **Step 3: Implement in `ccr_gas_schedule.dart`** (add `import 'package:submersion/core/deco/entities/profile_gas_segment.dart';`)

```dart
/// Builds the CCR gas schedule for decompression analysis: the loop ppO2 as
/// each loop segment's setpoint over the diluent breathed at that point, so
/// the engine loads tissues at constant ppO2 (inspired inert = ambient - loop
/// ppO2, split by the diluent's He:N2 ratio) and holds the setpoint through
/// the TTS ascent.
///
/// [loopPpO2Curve] is the per-sample resolved loop ppO2, aligned with
/// [timestamps]. On the loop a new segment starts when the value moves more
/// than [setpointTolerance] bar from the active setpoint, tracking real
/// setpoint switches without a segment per noisy cell sample.
/// [fallbackSetpoint] (the dive-level setpoint) stands in when no curve
/// exists. Returns null when neither exists: with no loop ppO2 information the
/// loop cannot be modelled.
///
/// [gasChanges] ([classifyCcrGasChanges], time-ordered) switch the diluent or
/// bail out (issue #577). A bailout segment carries no setpoint: the diver
/// breathes that cylinder open circuit, and loop ppO2 movement is ignored
/// until a diluent change returns them to the loop, re-seeded from the loop
/// ppO2 at the switch. A change between two samples takes the loop ppO2 of the
/// sample before it. Changes before the first sample are dropped; one at the
/// first sample replaces the seed.
///
/// The first segment starts at the first profile timestamp, which on a
/// secondary computer's own bucket of a multi-source dive can be negative.
List<ProfileGasSegment>? buildCcrProfileGasSegments({
  required List<int> timestamps,
  required List<double>? loopPpO2Curve,
  required GasMix diluentMix,
  double? fallbackSetpoint,
  double setpointTolerance = 0.05,
  List<CcrGasChange> gasChanges = const [],
}) {
  final curve =
      timestamps.isNotEmpty &&
          loopPpO2Curve != null &&
          loopPpO2Curve.length == timestamps.length
      ? loopPpO2Curve
      : null;
  if (curve == null && fallbackSetpoint == null) return null;
  double setpointAt(int index) => curve != null ? curve[index] : fallbackSetpoint!;

  final seed = timestamps.isEmpty ? 0 : timestamps.first;
  var loopFN2 = diluentMix.isAir
      ? airN2Fraction
      : (100.0 - diluentMix.o2 - diluentMix.he) / 100.0;
  var loopFHe = diluentMix.he / 100.0;
  var onLoop = true;
  var openFN2 = 0.0;
  var openFHe = 0.0;

  ProfileGasSegment segmentAt(int start, double setpoint) => onLoop
      ? ProfileGasSegment(
          startTimestamp: start,
          fN2: loopFN2,
          fHe: loopFHe,
          setpoint: setpoint,
        )
      : ProfileGasSegment(startTimestamp: start, fN2: openFN2, fHe: openFHe);

  final segments = <ProfileGasSegment>[];
  void emit(ProfileGasSegment next) {
    if (segments.isNotEmpty &&
        segments.last.startTimestamp == next.startTimestamp) {
      segments.removeLast();
    }
    if (segments.isNotEmpty && _sameGas(segments.last, next)) return;
    segments.add(next);
  }

  final changes = gasChanges.where((c) => c.timestamp >= seed).toList();
  var nextChange = 0;
  for (var i = 0; i < timestamps.length; i++) {
    final timestamp = timestamps[i];
    while (nextChange < changes.length &&
        changes[nextChange].timestamp <= timestamp) {
      final change = changes[nextChange++];
      if (change.kind == CcrGasChangeKind.diluent) {
        loopFN2 = change.fN2;
        loopFHe = change.fHe;
        onLoop = true;
      } else {
        openFN2 = change.fN2;
        openFHe = change.fHe;
        onLoop = false;
      }
      final setpointIndex = change.timestamp < timestamp ? i - 1 : i;
      emit(segmentAt(change.timestamp, setpointAt(setpointIndex)));
    }
    // A change landing on this sample already carries its loop ppO2, so the
    // tolerance check below is a no-op for it; one landing between samples
    // still needs this sample's reading checked.
    if (segments.isEmpty) {
      emit(segmentAt(seed, setpointAt(0)));
    } else if (onLoop &&
        (setpointAt(i) - segments.last.setpoint!).abs() > setpointTolerance) {
      emit(segmentAt(timestamp, setpointAt(i)));
    }
  }
  if (segments.isEmpty) emit(segmentAt(seed, fallbackSetpoint!));
  return segments;
}

/// Whether a CCR loop schedule from [buildCcrProfileGasSegments] contains a
/// bailout: a segment with no setpoint, breathed open circuit.
bool hasOpenCircuitBailout(List<ProfileGasSegment>? loopSchedule) =>
    loopSchedule != null && loopSchedule.any((s) => s.setpoint == null);

bool _sameGas(ProfileGasSegment a, ProfileGasSegment b) =>
    a.fN2 == b.fN2 &&
    a.fHe == b.fHe &&
    a.setpoint == b.setpoint &&
    a.loopHoldsSetpoint == b.loopHoldsSetpoint;
```

Then delete the old `buildCcrProfileGasSegments` (doc comment through closing brace, lines 284-349) from `profile_analysis_provider.dart` and add `import 'package:submersion/features/dive_log/domain/services/ccr_gas_schedule.dart';` to its imports. In each of the four test files listed above, add the same import; if `flutter analyze` then reports the provider import as unused in a file, remove that import.

- [ ] **Step 4: Run the new tests and every existing CCR suite**

Run: `flutter test test/features/dive_log/domain/services/ccr_gas_schedule_test.dart test/core/deco/cns_method_fixture_cross_validation_test.dart test/core/deco/ccr_loop_deco_fixture_test.dart test/core/deco/tts_fixture_shape_test.dart test/features/dive_log/presentation/providers/profile_analysis_provider_test.dart test/features/dive_log/presentation/providers/rebreather_profile_gas_segments_test.dart`
Expected: PASS, with the existing suites unchanged.

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format lib/features/dive_log test/core/deco test/features/dive_log
flutter analyze lib/features/dive_log test/core/deco test/features/dive_log
git add lib/features/dive_log/domain/services/ccr_gas_schedule.dart lib/features/dive_log/presentation/providers/profile_analysis_provider.dart test/features/dive_log/domain/services/ccr_gas_schedule_test.dart test/core/deco/cns_method_fixture_cross_validation_test.dart test/core/deco/ccr_loop_deco_fixture_test.dart test/core/deco/tts_fixture_shape_test.dart test/features/dive_log/presentation/providers/profile_analysis_provider_test.dart
git commit -m "feat(dive-log): build CCR schedules across diluent switches and bailouts"
```

---

### Task 3: Engine ascent precedence

**Files:**
- Modify: `lib/core/deco/buhlmann_algorithm.dart:1000-1123` (doc comment and the `ascentGas:` argument)
- Test: `test/core/deco/ccr_bailout_ascent_test.dart`

**Interfaces:**
- Produces: `processProfileWithGasSegments` uses the loop ascent on setpoint-bearing samples and `ascentGasPlan` on open-circuit samples.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/deco/ascent/ascent_gas_plan.dart';
import 'package:submersion/core/deco/buhlmann_algorithm.dart';
import 'package:submersion/core/deco/constants/buhlmann_coefficients.dart';
import 'package:submersion/core/deco/entities/profile_gas_segment.dart';

/// Issue #577: a CCR dive that bails out mixes loop and open-circuit
/// segments. The simulated ascent from a loop sample stays on the loop; from
/// a bailout sample it uses the carried open-circuit gases.
void main() {
  final timestamps = [for (var t = 0; t <= 32 * 60; t += 60) t];
  final depths = [
    for (final t in timestamps) t < 120 ? 45.0 * t / 120 : 45.0,
  ];
  const loop = ProfileGasSegment(
    startTimestamp: 0,
    fN2: airN2Fraction,
    setpoint: 1.3,
  );
  OptimalOcAscentGas airOnly() => OptimalOcAscentGas(
    gases: [AvailableGas(fN2: airN2Fraction, fHe: 0.0, maxPpO2Mod: 66.0)],
    maxPpO2: 1.6,
  );

  int finalTts(List<ProfileGasSegment> segments, AscentGasPlan? plan) =>
      BuhlmannAlgorithm(gfLow: 0.3, gfHigh: 0.7)
          .processProfileWithGasSegments(
            depths: depths,
            timestamps: timestamps,
            gasSegments: segments,
            ascentGasPlan: plan,
          )
          .last
          .ttsSeconds;

  test('a loop sample ascends on the loop even with an OC plan supplied', () {
    expect(finalTts(const [loop], airOnly()), finalTts(const [loop], null));
  });

  test('a bailout sample ascends on the supplied OC plan', () {
    const segments = [
      loop,
      ProfileGasSegment(startTimestamp: 20 * 60, fN2: airN2Fraction),
    ];
    final withDecoGas = OptimalOcAscentGas(
      gases: [
        AvailableGas(fN2: airN2Fraction, fHe: 0.0, maxPpO2Mod: 66.0),
        AvailableGas(fN2: 0.5, fHe: 0.0, maxPpO2Mod: 22.0),
      ],
      maxPpO2: 1.6,
    );
    expect(finalTts(segments, withDecoGas), lessThan(finalTts(segments, null)));
  });
}
```

- [ ] **Step 2: Run to verify the first test fails**

Run: `flutter test test/core/deco/ccr_bailout_ascent_test.dart`
Expected: FAIL on "a loop sample ascends on the loop..." (the OC air plan overrides the loop today, so its TTS is longer). The second test may already pass; it guards the bailout half.

- [ ] **Step 3: Implement**

In `processProfileWithGasSegments`, replace

```dart
          ascentGas: ascentGasPlan ?? _loopAscentPlanFor(sampleGas, depths[i]),
```

with

```dart
          // A loop sample ascends on the loop; a bailout (open-circuit)
          // sample on the supplied plan (issue #577).
          ascentGas: sampleGas.setpoint != null
              ? _loopAscentPlanFor(sampleGas, depths[i])
              : ascentGasPlan,
```

and update the method's doc comment sentence about [ascentGasPlan] to: "[ascentGasPlan] optionally sets the ascent gas selection for TTS and deco-schedule calculations on open-circuit segments; null reproduces the legacy per-sample single-gas behavior. A segment carrying a [ProfileGasSegment.setpoint] always ascends on the loop itself (see [_loopAscentPlanFor]), so a CCR dive that bails out ascends on the loop before the bailout and on [ascentGasPlan] after it."

- [ ] **Step 4: Run engine suites**

Run: `flutter test test/core/deco/`
Expected: PASS.

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format lib/core/deco/buhlmann_algorithm.dart test/core/deco/ccr_bailout_ascent_test.dart
flutter analyze lib/core/deco test/core/deco
git add lib/core/deco/buhlmann_algorithm.dart test/core/deco/ccr_bailout_ascent_test.dart
git commit -m "feat(deco): ascend on the loop from loop samples and on the OC plan after a bailout"
```

---

### Task 4: Analysis service follows the bailout gas

**Files:**
- Modify: `lib/features/dive_log/data/services/profile_analysis_service.dart` (CCR arm of the ppO2 switch near line 805; `_calculateCcrLoopFractions` near line 1925; new private helper beside `_calculatePpCurve`)
- Test: `test/features/dive_log/data/services/profile_analysis_service_ccr_bailout_test.dart`

**Interfaces:**
- Consumes: segment semantics from Task 2 (`setpoint == null` means open circuit).
- Produces: `ProfileAnalysis.ppO2Curve`, `ppN2Curve`, `modCurve`, `o2Exposure` follow the open-circuit gas on bailout samples of a CCR dive.

- [ ] **Step 1: Write the failing tests**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/deco/constants/buhlmann_coefficients.dart';
import 'package:submersion/core/deco/entities/profile_gas_segment.dart';
import 'package:submersion/core/deco/o2_toxicity_calculator.dart';
import 'package:submersion/features/dive_log/data/services/profile_analysis_service.dart';

/// Issue #577: after a bailout the O2 cells keep reading a loop the diver no
/// longer breathes. ppO2, CNS/OTU and the gas overlays follow the bailout gas.
void main() {
  // CCR at 1.3 over air diluent at 21 m; bailout to EAN50 at 20 min.
  final timestamps = [for (var t = 0; t <= 40 * 60; t += 60) t];
  final depths = [
    for (final t in timestamps) t < 120 ? 21.0 * t / 120 : 21.0,
  ];
  final loopCurve = List<double>.filled(timestamps.length, 1.3);
  const bailoutAt = 20 * 60;
  final bailoutIndex = timestamps.indexOf(bailoutAt);
  const ambient = 3.1; // 21 m on the service's 1 + d/10 basis
  final service = ProfileAnalysisService(gfLow: 0.3, gfHigh: 0.7);

  const loop = ProfileGasSegment(
    startTimestamp: 0,
    fN2: airN2Fraction,
    setpoint: 1.3,
  );
  const bailout = ProfileGasSegment(startTimestamp: bailoutAt, fN2: 0.5);

  ProfileAnalysis analyze(List<ProfileGasSegment> segments) => service.analyze(
    diveId: 'ccr-bailout',
    depths: depths,
    timestamps: timestamps,
    o2Fraction: 1.0 - airN2Fraction,
    diveMode: DiveMode.ccr,
    setpointHigh: 1.3,
    gasSegments: segments,
    rebreatherPpO2Curve: loopCurve,
  );

  test('ppO2 follows the loop before the bailout and the gas after', () {
    final analysis = analyze(const [loop, bailout]);
    expect(analysis.ppO2Curve[bailoutIndex - 1], closeTo(1.3, 1e-9));
    expect(analysis.ppO2Curve[bailoutIndex], closeTo(ambient * 0.5, 1e-9));
    expect(analysis.ppO2Curve.last, closeTo(ambient * 0.5, 1e-9));
  });

  test('CNS and OTU count the bailout gas', () {
    final loopOnly = analyze(const [loop]);
    final bailedOut = analyze(const [loop, bailout]);
    expect(
      bailedOut.o2Exposure.cnsEnd,
      greaterThan(loopOnly.o2Exposure.cnsEnd),
    );
    expect(bailedOut.o2Exposure.otu, greaterThan(loopOnly.o2Exposure.otu));
    expect(bailedOut.o2Exposure.maxPpO2, closeTo(ambient * 0.5, 1e-6));
  });

  test('ppN2 and the MOD line describe the bailout gas', () {
    final analysis = analyze(const [loop, bailout]);
    // On the loop over air diluent all inert gas is N2: ambient less ppO2.
    expect(analysis.ppN2Curve![bailoutIndex - 1], closeTo(ambient - 1.3, 1e-9));
    expect(analysis.ppN2Curve![bailoutIndex], closeTo(ambient * 0.5, 1e-9));
    expect(
      analysis.modCurve![bailoutIndex - 1],
      closeTo(
        O2ToxicityCalculator.calculateMod(1.0 - airN2Fraction, maxPpO2: 1.4),
        1e-9,
      ),
    );
    expect(
      analysis.modCurve![bailoutIndex],
      closeTo(O2ToxicityCalculator.calculateMod(0.5, maxPpO2: 1.4), 1e-9),
    );
  });

  test('a loop-only schedule keeps the loop ppO2 throughout', () {
    final analysis = analyze(const [loop]);
    expect(analysis.ppO2Curve.skip(1), everyElement(closeTo(1.3, 1e-9)));
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/features/dive_log/data/services/profile_analysis_service_ccr_bailout_test.dart`
Expected: FAIL on the ppO2, CNS/OTU and ppN2 assertions (the bailout stretch still reads 1.3).

- [ ] **Step 3: Implement**

In the `DiveMode.ccr` arm, assign the loop curve to a local and post-process it:

```dart
      case DiveMode.ccr:
        // ... existing comment ...
        final ccrSetpoint = setpointHigh ?? setpointLow;
        final List<double> loopPpO2;
        if (measuredPpO2 != null) {
          loopPpO2 = measuredPpO2;
        } else if (ccrSetpoint != null) {
          loopPpO2 = _o2ToxicityCalculator.calculatePpO2CurveCCR(
            depths,
            setpointHigh: ccrSetpoint,
            setpointLow: setpointHigh != null ? setpointLow : null,
            lowSetpointMaxDepth: lowSetpointMaxDepth,
          );
        } else {
          loopPpO2 = List<double>.filled(depths.length, 0.0);
        }
        ppO2Curve = gasSegments == null
            ? loopPpO2
            : _withOpenCircuitPpO2(
                depths: depths,
                timestamps: timestamps,
                gasSegments: gasSegments,
                loopPpO2Curve: loopPpO2,
              );
```

(Keep the existing per-branch comments on the measured and setpoint branches.) Add the helper beside `_calculatePpCurve`:

```dart
  /// The loop ppO2 on samples breathed on the loop, and ambient x FO2 on
  /// samples breathed open circuit after a bailout (issue #577): the O2 cells
  /// keep reading a loop the diver is no longer breathing.
  List<double> _withOpenCircuitPpO2({
    required List<double> depths,
    required List<int> timestamps,
    required List<ProfileGasSegment> gasSegments,
    required List<double> loopPpO2Curve,
  }) {
    return List<double>.generate(depths.length, (i) {
      final gas = _activeGasSegmentAtTimestamp(timestamps[i], gasSegments);
      if (gas.setpoint != null) return loopPpO2Curve[i];
      final fO2 = (1.0 - gas.fN2 - gas.fHe).clamp(0.0, 1.0);
      return (1.0 + depths[i] / 10.0) * fO2;
    });
  }
```

In `_calculateCcrLoopFractions`, after `diluentO2Fractions.add(1.0 - diluentInert);`, add:

```dart
      // Bailed out: the diver breathes this cylinder open circuit, not the
      // loop (issue #577).
      if (diluent.setpoint == null) {
        o2Fractions.add(1.0 - diluentInert);
        n2Fractions.add(diluentFN2);
        heFractions.add(diluentFHe);
        continue;
      }
```

and extend its doc comment with: "A bailout segment (no setpoint) is breathed open circuit on its own fractions."

- [ ] **Step 4: Run service suites**

Run: `flutter test test/features/dive_log/data/services/`
Expected: PASS.

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format lib/features/dive_log/data/services/profile_analysis_service.dart test/features/dive_log/data/services/profile_analysis_service_ccr_bailout_test.dart
flutter analyze lib/features/dive_log/data/services test/features/dive_log/data/services
git add lib/features/dive_log/data/services/profile_analysis_service.dart test/features/dive_log/data/services/profile_analysis_service_ccr_bailout_test.dart
git commit -m "feat(dive-log): analyse ppO2, CNS and gas overlays on the bailout gas"
```

---

### Task 5: Provider wiring and the displayed ppO2

**Files:**
- Modify: `lib/features/dive_log/domain/services/ccr_gas_schedule.dart` (add `breathedPpO2Curve`)
- Modify: `lib/features/dive_log/presentation/providers/profile_analysis_provider.dart` (`buildRebreatherProfileGasSegments`, `buildAvailableGases`, the gas-schedule and ascent-gas block near line 1331, the overlay call near line 1437)
- Test: `test/features/dive_log/domain/services/ccr_gas_schedule_test.dart`, `test/features/dive_log/presentation/providers/rebreather_profile_gas_segments_test.dart`, `test/features/dive_log/presentation/providers/profile_analysis_provider_test.dart`, new `test/features/dive_log/presentation/providers/profile_analysis_ccr_bailout_wiring_test.dart`

**Interfaces:**
- Consumes: `classifyCcrGasChanges`, `buildCcrProfileGasSegments(gasChanges:)`, `hasOpenCircuitBailout` (Tasks 1-2).
- Produces: `List<double> breathedPpO2Curve({required List<double> loopCurve, required List<double> analysedCurve, required List<int> timestamps, required List<ProfileGasSegment> segments})`; `buildRebreatherProfileGasSegments(dive, {profile, rebreatherPpO2, List<GasSwitchWithTank> gasSwitches = const [], List<DiveTank>? tanks})`; `buildAvailableGases(dive, {maxPpO2, gasSet, bool excludeLoopCylinders = false})`.

- [ ] **Step 1: Write the failing unit tests**

Append to `ccr_gas_schedule_test.dart`:

```dart
  group('breathedPpO2Curve', () {
    test('loop ppO2 on the loop, the analysed ppO2 after a bailout', () {
      final curve = breathedPpO2Curve(
        loopCurve: const [1.3, 1.3, 1.3, 1.3],
        analysedCurve: const [9.9, 9.9, 1.55, 1.55],
        timestamps: const [0, 60, 120, 180],
        segments: const [
          ProfileGasSegment(startTimestamp: 0, fN2: 0.79, setpoint: 1.3),
          ProfileGasSegment(startTimestamp: 120, fN2: 0.5),
        ],
      );
      expect(curve, [1.3, 1.3, 1.55, 1.55]);
    });
  });
```

Append to `rebreather_profile_gas_segments_test.dart` inside `main()` (add imports for `gas_switch.dart` if missing):

```dart
  group('gas switches (issue #577)', () {
    const bailout = DiveTank(
      id: 'bail',
      gasMix: GasMix(o2: 50),
      role: TankRole.bailout,
    );
    final toBailout = GasSwitchWithTank(
      gasSwitch: GasSwitch(
        id: 's1',
        diveId: 'ccr',
        timestamp: 1200,
        tankId: 'bail',
        createdAt: DateTime.utc(2026, 10, 5),
      ),
      tankName: 'Bailout',
      gasMix: 'EAN50',
      o2Fraction: 0.5,
    );

    test('CCR breathes the bailout cylinder open circuit after the switch', () {
      final dive = Dive(
        id: 'ccr',
        dateTime: DateTime.utc(2026, 10, 5),
        diveMode: DiveMode.ccr,
        tanks: const [o2, diluent, bailout],
        profile: profile(setpoint: 1.3),
      );
      final segments = buildRebreatherProfileGasSegments(
        dive,
        profile: dive.profile,
        rebreatherPpO2: resolveRebreatherPpO2(dive.profile),
        gasSwitches: [toBailout],
      )!;
      expect(segments, hasLength(2));
      expect(segments[1].startTimestamp, 1200);
      expect(segments[1].setpoint, isNull);
      expect(segments[1].fN2, closeTo(0.5, 1e-9));
    });

    test('SCR ignores gas switches', () {
      final dive = Dive(
        id: 'scr',
        dateTime: DateTime.utc(2026, 10, 5),
        diveMode: DiveMode.scr,
        tanks: const [supply, bailout],
        profile: profile(ppO2: 1.0),
      );
      final segments = buildRebreatherProfileGasSegments(
        dive,
        profile: dive.profile,
        rebreatherPpO2: resolveRebreatherPpO2(
          dive.profile,
          measuredOnly: true,
        ),
        gasSwitches: [toBailout],
      )!;
      expect(segments, hasLength(1));
      expect(segments.single.setpoint, isNotNull);
    });
  });
```

Append to `profile_analysis_provider_test.dart` inside `main()`:

```dart
  group('buildAvailableGases excludeLoopCylinders', () {
    test('drops the diluent and the O2 supply', () {
      final dive = makeDive(
        diveMode: DiveMode.ccr,
        tanks: const [
          DiveTank(id: 'dil', gasMix: GasMix(), role: TankRole.diluent),
          DiveTank(
            id: 'o2',
            gasMix: GasMix(o2: 100),
            role: TankRole.oxygenSupply,
          ),
          DiveTank(
            id: 'bail',
            gasMix: GasMix(o2: 21, he: 35),
            role: TankRole.bailout,
          ),
          DiveTank(id: 'deco', gasMix: GasMix(o2: 50), role: TankRole.deco),
        ],
      );
      final gases = buildAvailableGases(
        dive,
        maxPpO2: 1.6,
        gasSet: AscentGasSet.allCarried,
        excludeLoopCylinders: true,
      );
      expect(
        gases.map((g) => g.fO2),
        [closeTo(0.21, 1e-9), closeTo(0.5, 1e-9)],
      );
    });
  });
```

- [ ] **Step 2: Run to verify they fail**

Run: `flutter test test/features/dive_log/domain/services/ccr_gas_schedule_test.dart test/features/dive_log/presentation/providers/rebreather_profile_gas_segments_test.dart test/features/dive_log/presentation/providers/profile_analysis_provider_test.dart`
Expected: FAIL, compile errors (`breathedPpO2Curve`, `gasSwitches:`, `excludeLoopCylinders:` not defined).

- [ ] **Step 3: Implement the units**

In `ccr_gas_schedule.dart`:

```dart
/// The ppO2 a CCR diver breathed at each sample, for display: the loop's own
/// resolved [loopCurve] while on the loop, and the analysed open-circuit ppO2
/// ([analysedCurve], ambient x FO2) on samples after a bailout, where the O2
/// cells read a loop no longer breathed (issue #577).
List<double> breathedPpO2Curve({
  required List<double> loopCurve,
  required List<double> analysedCurve,
  required List<int> timestamps,
  required List<ProfileGasSegment> segments,
}) {
  return List<double>.generate(timestamps.length, (i) {
    var active = segments.first;
    for (final segment in segments) {
      if (segment.startTimestamp > timestamps[i]) break;
      active = segment;
    }
    return active.setpoint == null ? analysedCurve[i] : loopCurve[i];
  });
}
```

In `buildRebreatherProfileGasSegments`, add parameters and use them in the CCR arm only:

```dart
List<ProfileGasSegment>? buildRebreatherProfileGasSegments(
  Dive dive, {
  required List<DiveProfilePoint> profile,
  required RebreatherPpO2? rebreatherPpO2,
  List<GasSwitchWithTank> gasSwitches = const [],
  List<DiveTank>? tanks,
}) {
  final timestamps = [for (final p in profile) p.timestamp];
  switch (dive.diveMode) {
    case DiveMode.ccr:
      return buildCcrProfileGasSegments(
        timestamps: timestamps,
        loopPpO2Curve: rebreatherPpO2?.curve,
        diluentMix: resolveCcrDiluentMix(dive),
        fallbackSetpoint: dive.setpointHigh ?? dive.setpointLow,
        gasChanges: classifyCcrGasChanges(gasSwitches, tanks ?? dive.tanks),
      );
```

and extend its doc comment: "[gasSwitches] are this computer's recorded switches and [tanks] the cylinders it breathed (default every tank); on CCR they switch the diluent or bail out (issue #577). SCR ignores them."

In `buildAvailableGases`, add `bool excludeLoopCylinders = false` and start `keep` with:

```dart
    // A bailout ascent cannot breathe the loop's own cylinders.
    if (excludeLoopCylinders &&
        (t.role == TankRole.diluent || t.role == TankRole.oxygenSupply)) {
      return false;
    }
```

- [ ] **Step 4: Run the unit tests**

Run the Step 2 command. Expected: PASS.

- [ ] **Step 5: Write the failing integration test**

`test/features/dive_log/presentation/providers/profile_analysis_ccr_bailout_wiring_test.dart`:

```dart
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/profile_series_repository.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_sample.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_analysis_provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/test_database.dart';

/// Issue #577: a CCR dive's recorded switch to its bailout cylinder reaches
/// the analysis and the displayed ppO2 through profileAnalysisProvider.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  setUp(() async => db = await setUpTestDatabase());
  tearDown(() async => tearDownTestDatabase());

  const diveId = 'ccr-bailout-dive';
  const bailoutAt = 20 * 60;

  Future<void> seed() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.dives)
        .insert(
          DivesCompanion(
            id: const Value(diveId),
            diveDateTime: Value(now),
            maxDepth: const Value(21.0),
            avgDepth: const Value(20.0),
            bottomTime: const Value(40 * 60),
            diveMode: const Value('ccr'),
            setpointHigh: const Value(1.3),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
    for (final (id, o2, role, order) in [
      ('dil', 21.0, 'diluent', 0),
      ('bail', 50.0, 'bailout', 1),
    ]) {
      await db
          .into(db.diveTanks)
          .insert(
            DiveTanksCompanion(
              id: Value(id),
              diveId: const Value(diveId),
              o2Percent: Value(o2),
              tankRole: Value(role),
              tankOrder: Value(order),
            ),
          );
    }
    await db
        .into(db.gasSwitches)
        .insert(
          GasSwitchesCompanion(
            id: const Value('switch-bail'),
            diveId: const Value(diveId),
            timestamp: const Value(bailoutAt),
            tankId: const Value('bail'),
            createdAt: Value(now),
          ),
        );
    await ProfileSeriesRepository().insertSeries(
      diveId: diveId,
      samples: [
        for (var t = 0; t <= 40 * 60; t += 60)
          ProfileSample(
            timestamp: t,
            depth: t < 120 ? 21.0 * t / 120 : 21.0,
            setpoint: 1.3,
          ),
      ],
    );
  }

  test('the bailout switch moves ppO2 onto the bailout gas', () async {
    await seed();
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    final analysis = await container.read(
      profileAnalysisProvider(diveId).future,
    );

    expect(analysis, isNotNull);
    expect(analysis!.tissueLoadingWithheld, isFalse);
    final bailoutIndex = bailoutAt ~/ 60;
    expect(analysis.ppO2Curve[bailoutIndex - 1], closeTo(1.3, 1e-6));
    expect(analysis.ppO2Curve[bailoutIndex], closeTo(3.1 * 0.5, 1e-6));
  });
}
```

If the generated companions require fields not listed here (check `lib/core/database/database.g.dart` for `DiveTanksCompanion` / `GasSwitchesCompanion` required columns), add them with plain values.

- [ ] **Step 6: Run to verify it fails**

Run: `flutter test test/features/dive_log/presentation/providers/profile_analysis_ccr_bailout_wiring_test.dart`
Expected: FAIL on `ppO2Curve[bailoutIndex]` (still 1.3: the provider does not load CCR switches and the overlay replaces ppO2 with the loop curve).

- [ ] **Step 7: Wire the provider**

Replace the `gasSegments` switch and the `ascentGases` assignment near line 1331 with:

```dart
    // Scope switches to this computer's own gas plan: on a multi-source
    // dive, getGasSwitchesForDive returns every computer's switches on its
    // own clock, and mixing another computer's timestamps into this source's
    // schedule can produce a non-monotonic list that BuhlmannAlgorithm
    // rejects outright (#garmin-cloud-merge-analysis-blank), silently
    // blanking every decompression/gas overlay. A switch must go to a tank
    // this computer breathed, and be its own or unattributed: a cylinder two
    // computers share carries both computers' switches (#2560).
    Future<List<GasSwitchWithTank>> scopedGasSwitches() async =>
        (await repository.getGasSwitchesForDive(diveId))
            .where(
              (gs) =>
                  computerId == null ||
                  (tankIds.contains(gs.gasSwitch.tankId) &&
                      gs.gasSwitch.appliesTo(computerId)),
            )
            .toList();
    final gasSegments = switch (dive.diveMode) {
      DiveMode.oc => buildProfileGasSegments(
        dive,
        await scopedGasSwitches(),
        tanks: tanks,
        // A secondary computer's own bucket on a multi-source dive can
        // start before the merged timeline's zero point (it was switched on
        // earlier); seed the schedule there instead of a hardcoded 0.
        startTimestamp: timestamps.isEmpty ? 0 : timestamps.first,
      ),
      // A CCR diver's switches change the diluent or bail out (#577).
      DiveMode.ccr => buildRebreatherProfileGasSegments(
        dive,
        profile: profile,
        rebreatherPpO2: rebreatherPpO2,
        gasSwitches: await scopedGasSwitches(),
        tanks: tanks,
      ),
      // Gauge dives return a profile-only analysis before this point; they
      // take the rebreather arm only for exhaustiveness (it returns null).
      DiveMode.scr || DiveMode.gauge => buildRebreatherProfileGasSegments(
        dive,
        profile: profile,
        rebreatherPpO2: rebreatherPpO2,
      ),
    };
    final ascentMaxPpO2 = inputs.ppO2MaxDeco;
    // OC ascends on its carried gases; a CCR dive that bailed out ascends
    // from its bailout samples on the open-circuit cylinders it carried.
    final ascentGases = switch (dive.diveMode) {
      DiveMode.oc => buildAvailableGases(
        dive,
        maxPpO2: ascentMaxPpO2,
        gasSet: inputs.ascentGasSet,
      ),
      DiveMode.ccr when hasOpenCircuitBailout(gasSegments) =>
        buildAvailableGases(
          dive,
          maxPpO2: ascentMaxPpO2,
          gasSet: inputs.ascentGasSet,
          excludeLoopCylinders: true,
        ),
      _ => null,
    };
```

Before the `overlayComputerDecoData` call, add:

```dart
    // After a bailout the chart's ppO2 is the gas breathed, not the cells'
    // reading of the abandoned loop (#577).
    final displayedPpO2 =
        rebreatherPpO2 != null &&
            dive.diveMode == DiveMode.ccr &&
            hasOpenCircuitBailout(gasSegments)
        ? (
            curve: breathedPpO2Curve(
              loopCurve: rebreatherPpO2.curve,
              analysedCurve: analysis.ppO2Curve,
              timestamps: timestamps,
              segments: gasSegments!,
            ),
            fromSensorAverage: rebreatherPpO2.fromSensorAverage,
            sensorCurves: rebreatherPpO2.sensorCurves,
          )
        : rebreatherPpO2;
```

and pass `rebreatherPpO2: displayedPpO2,` to `overlayComputerDecoData` in place of `rebreatherPpO2: rebreatherPpO2,`.

- [ ] **Step 8: Run the provider suites**

Run: `flutter test test/features/dive_log/presentation/providers/ test/features/dive_log/domain/services/ccr_gas_schedule_test.dart`
Expected: PASS.

- [ ] **Step 9: Format, analyze, commit**

```bash
dart format lib/features/dive_log test/features/dive_log
flutter analyze lib/features/dive_log test/features/dive_log
git add lib/features/dive_log/domain/services/ccr_gas_schedule.dart lib/features/dive_log/presentation/providers/profile_analysis_provider.dart test/features/dive_log/domain/services/ccr_gas_schedule_test.dart test/features/dive_log/presentation/providers/rebreather_profile_gas_segments_test.dart test/features/dive_log/presentation/providers/profile_analysis_provider_test.dart test/features/dive_log/presentation/providers/profile_analysis_ccr_bailout_wiring_test.dart
git commit -m "feat(dive-log): read CCR gas switches into the analysis and the ppO2 chart"
```

---

### Task 6: Verification and after screenshots

- [ ] **Step 1: Whole-project checks**

```bash
dart format .
flutter analyze
flutter test test/architecture/ test/core/deco/ test/features/dive_log/ test/features/insights/ test/features/planner/
```

Expected: format clean, no analyzer issues, all green. Log output to the scratchpad, not `$TMPDIR`.

- [ ] **Step 2: After screenshots**

Relaunch the app from this worktree with the `run` skill, open the Task 0 fixture dive, and capture `01-dive-profile-ccr-bailout-after.png` and `02-dive-o2-tox-ccr-bailout-after.png` with the same framing as the before shots. Expected visible differences: the ppO2 line steps from 1.3 to the bailout gas's ppO2 at 25:00 (21/35 at 30 m: 0.84 bar), then to EAN50 at 33:00; CNS/OTU and ceiling/TTS change accordingly.

- [ ] **Step 3: Remove the fixture dive** from the dev logbook (delete it in the app), then send all four screenshots to the user in one SendUserFile call (`display: attach`).
