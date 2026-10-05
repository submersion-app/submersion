import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/deco/constants/buhlmann_coefficients.dart';
import 'package:submersion/core/deco/entities/profile_gas_segment.dart';
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
        final changes = classifyCcrGasChanges(
          [_switch('a', 900, tank)],
          [..._tanks, tank],
        );
        expect(changes.single.kind, CcrGasChangeKind.openCircuit);
        expect(changes.single.fN2, closeTo(0.5, 1e-9));
      });
    }

    group('an untagged (back gas) cylinder on a CCR dive', () {
      // File imports give a cylinder they know nothing about the Back Gas
      // role, so on a CCR dive it is read as loop gas, never as a bailout.
      const untagged = DiveTank(id: 'untagged', gasMix: GasMix(o2: 21, he: 35));
      const untaggedO2 = DiveTank(id: 'untagged-o2', gasMix: GasMix(o2: 100));
      const tanks = [..._tanks, untagged, untaggedO2];

      test('is a diluent change on the loop', () {
        final changes = classifyCcrGasChanges([
          _switch('a', 600, untagged),
        ], tanks);
        expect(changes.single.kind, CcrGasChangeKind.diluent);
        expect(changes.single.fHe, closeTo(0.35, 1e-9));
      });

      test('returns the diver to the loop after a bailout', () {
        final changes = classifyCcrGasChanges([
          _switch('a', 600, _bail),
          _switch('b', 900, untagged),
        ], tanks);
        expect(changes.map((c) => c.kind), [
          CcrGasChangeKind.openCircuit,
          CcrGasChangeKind.diluent,
        ]);
      });

      test('of pure O2 is the O2 supply: dropped on the loop', () {
        expect(
          classifyCcrGasChanges([_switch('a', 600, untaggedO2)], tanks),
          isEmpty,
        );
      });

      test('of pure O2 is open circuit on O2 after a bailout', () {
        final changes = classifyCcrGasChanges([
          _switch('a', 600, _bail),
          _switch('b', 900, untaggedO2),
        ], tanks);
        expect(changes.last.kind, CcrGasChangeKind.openCircuit);
        expect(changes.last.fN2, closeTo(0.0, 1e-9));
      });
    });

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
}
