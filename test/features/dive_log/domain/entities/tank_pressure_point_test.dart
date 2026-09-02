import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/dive_log/domain/entities/dive.dart';

void main() {
  group('TankPressurePoint', () {
    test('two points with the same tank, timestamp and pressure are equal', () {
      const a = TankPressurePoint(tankId: 't1', timestamp: 10, pressure: 200.0);
      const b = TankPressurePoint(tankId: 't1', timestamp: 10, pressure: 200.0);
      expect(a, equals(b));
    });

    test('a different tank makes points unequal', () {
      const a = TankPressurePoint(tankId: 't1', timestamp: 10, pressure: 200.0);
      const b = TankPressurePoint(tankId: 't2', timestamp: 10, pressure: 200.0);
      expect(a, isNot(equals(b)));
    });

    test('a different timestamp makes points unequal', () {
      const a = TankPressurePoint(tankId: 't1', timestamp: 10, pressure: 200.0);
      const b = TankPressurePoint(tankId: 't1', timestamp: 20, pressure: 200.0);
      expect(a, isNot(equals(b)));
    });

    test('a different pressure makes points unequal', () {
      const a = TankPressurePoint(tankId: 't1', timestamp: 10, pressure: 200.0);
      const b = TankPressurePoint(tankId: 't1', timestamp: 10, pressure: 190.0);
      expect(a, isNot(equals(b)));
    });
  });
}
