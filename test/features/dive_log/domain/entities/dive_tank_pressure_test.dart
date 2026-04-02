import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/domain/entities/cylinder_sac.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

void main() {
  group('DiveTank', () {
    test('pressureUsed returns difference of start and end pressure', () {
      const tank = DiveTank(id: 't1', startPressure: 200.0, endPressure: 50.0);
      expect(tank.pressureUsed, 150.0);
    });

    test('pressureUsed returns null when start is null', () {
      const tank = DiveTank(id: 't1', endPressure: 50.0);
      expect(tank.pressureUsed, isNull);
    });

    test('pressureUsed returns null when end is null', () {
      const tank = DiveTank(id: 't1', startPressure: 200.0);
      expect(tank.pressureUsed, isNull);
    });

    test('copyWith updates pressure fields', () {
      const tank = DiveTank(
        id: 't1',
        startPressure: 200.0,
        endPressure: 50.0,
        workingPressure: 207.0,
      );
      final copy = tank.copyWith(startPressure: 210.0);
      expect(copy.startPressure, 210.0);
      expect(copy.endPressure, 50.0);
      expect(copy.workingPressure, 207.0);
    });
  });

  group('CylinderSac', () {
    test('gasUsedBar returns difference of start and end', () {
      const sac = CylinderSac(
        tankId: 't1',
        tankName: 'AL80',
        gasMix: GasMix(),
        role: TankRole.backGas,
        tankVolume: 11.1,
        startPressure: 200.0,
        endPressure: 50.0,
      );
      expect(sac.gasUsedBar, 150.0);
    });

    test('gasUsedBar returns null when pressures missing', () {
      const sac = CylinderSac(
        tankId: 't1',
        tankName: 'AL80',
        gasMix: GasMix(),
        role: TankRole.backGas,
        tankVolume: 11.1,
      );
      expect(sac.gasUsedBar, isNull);
    });
  });
}
