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
        final changes = classifyCcrGasChanges(
          [_switch('a', 900, tank)],
          [..._tanks, tank],
        );
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
