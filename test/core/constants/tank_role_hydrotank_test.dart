import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/app_enums.dart';
import 'package:submersion/features/dive_log/domain/services/multi_cylinder_consumption.dart';

/// The Avelo Hydrotank role (issue #4657): the diver breathes from it, but
/// water pumped in for buoyancy raises its pressure, so its pressure does
/// not measure the gas used.
void main() {
  group('TankRole.hydrotank', () {
    test('is breathing gas whose pressure does not measure gas use', () {
      expect(TankRole.hydrotank.isBreathingGas, isTrue);
      expect(TankRole.hydrotank.pressureMeasuresGasUse, isFalse);
    });

    test('a suit inflation bottle measures no gas use either', () {
      expect(TankRole.suitInflation.pressureMeasuresGasUse, isFalse);
    });

    test('every other role measures gas use by its pressure', () {
      for (final role in TankRole.values) {
        if (role == TankRole.hydrotank || role == TankRole.suitInflation) {
          continue;
        }
        expect(role.pressureMeasuresGasUse, isTrue, reason: role.name);
      }
    });

    test('is the only breathed role whose pressure is unmeasured', () {
      expect(TankRole.values.where((r) => r.isUnmeasuredBreathingGas), [
        TankRole.hydrotank,
      ]);
    });

    test('round-trips through its stored name', () {
      expect(TankRole.hydrotank.name, 'hydrotank');
      expect(TankRole.fromName('hydrotank'), TankRole.hydrotank);
    });

    test('is a backmount cylinder, so it stays the main cylinder', () {
      expect(backmountRoles, contains(TankRole.hydrotank));
    });
  });
}
