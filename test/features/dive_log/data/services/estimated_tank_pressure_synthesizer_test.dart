import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/data/services/estimated_tank_pressure_synthesizer.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/gas_switch.dart';

DiveTank _tank({
  required String id,
  double? start,
  double? end,
  int order = 0,
}) => DiveTank(
  id: id,
  gasMix: const GasMix(o2: 21),
  order: order,
  startPressure: start,
  endPressure: end,
);

GasSwitchWithTank _switch({required String tankId, required int timestamp}) =>
    GasSwitchWithTank(
      gasSwitch: GasSwitch(
        id: 'gs-$timestamp',
        diveId: 'd1',
        timestamp: timestamp,
        tankId: tankId,
        createdAt: DateTime(2026, 1, 1),
      ),
      tankName: '',
      gasMix: '',
      o2Fraction: 0.21,
    );

void main() {
  group('synthesizeEstimatedTankPressures', () {
    test('single tank, no switches -> straight two-point line', () {
      final result = synthesizeEstimatedTankPressures(
        existing: const {},
        tanks: [_tank(id: 't1', start: 200, end: 65)],
        gasSwitches: const [],
        diveDurationSeconds: 2400,
      );
      expect(result.estimatedTankIds, {'t1'});
      final pts = result.pressures['t1']!;
      expect(pts.map((p) => (p.timestamp, p.pressure)), [
        (0, 200.0),
        (2400, 65.0),
      ]);
    });

    test('deco bottle -> flat, drop, flat', () {
      final result = synthesizeEstimatedTankPressures(
        existing: const {},
        tanks: [
          _tank(id: 'back', start: 200, end: 90),
          _tank(id: 'deco', start: 190, end: 130, order: 1),
        ],
        gasSwitches: [
          _switch(tankId: 'deco', timestamp: 1200),
          _switch(tankId: 'back', timestamp: 1800),
        ],
        diveDurationSeconds: 2400,
      );
      final deco = result.pressures['deco']!.map(
        (p) => (p.timestamp, p.pressure),
      );
      expect(deco, [(0, 190.0), (1200, 190.0), (1800, 130.0), (2400, 130.0)]);
    });

    test('back gas returned to -> drop split across windows by duration', () {
      final result = synthesizeEstimatedTankPressures(
        existing: const {},
        tanks: [
          _tank(id: 'back', start: 200, end: 65),
          _tank(id: 'deco', start: 190, end: 130, order: 1),
        ],
        gasSwitches: [
          _switch(tankId: 'deco', timestamp: 1200),
          _switch(tankId: 'back', timestamp: 1800),
        ],
        diveDurationSeconds: 2400,
      );
      // active [0,1200]+[1800,2400] = 1800s, drop 135 -> 0.075 bar/s.
      final back = result.pressures['back']!.map(
        (p) => (p.timestamp, p.pressure),
      );
      expect(back, [(0, 200.0), (1200, 110.0), (1800, 110.0), (2400, 65.0)]);
    });

    test('real data passes through untouched and is not marked estimated', () {
      final real = {
        't1': const [
          TankPressurePoint(
            id: 'r0',
            tankId: 't1',
            timestamp: 0,
            pressure: 205,
          ),
          TankPressurePoint(
            id: 'r1',
            tankId: 't1',
            timestamp: 600,
            pressure: 150,
          ),
        ],
      };
      final result = synthesizeEstimatedTankPressures(
        existing: real,
        tanks: [_tank(id: 't1', start: 200, end: 65)],
        gasSwitches: const [],
        diveDurationSeconds: 2400,
      );
      expect(result.estimatedTankIds, isEmpty);
      expect(result.pressures['t1'], same(real['t1']));
    });

    test('skips when a pressure is missing, equal, or inverted', () {
      for (final tank in [
        _tank(id: 'x', start: 200), // no end
        _tank(id: 'x', end: 100), // no start
        _tank(id: 'x', start: 100, end: 100), // equal
        _tank(id: 'x', start: 90, end: 120), // inverted
      ]) {
        final result = synthesizeEstimatedTankPressures(
          existing: const {},
          tanks: [tank],
          gasSwitches: const [],
          diveDurationSeconds: 2400,
        );
        expect(result.estimatedTankIds, isEmpty);
        expect(result.pressures.containsKey('x'), isFalse);
      }
    });

    test('no profile duration -> nothing synthesized', () {
      final result = synthesizeEstimatedTankPressures(
        existing: const {},
        tanks: [_tank(id: 't1', start: 200, end: 65)],
        gasSwitches: const [],
        diveDurationSeconds: 0,
      );
      expect(result.estimatedTankIds, isEmpty);
    });
  });
}
