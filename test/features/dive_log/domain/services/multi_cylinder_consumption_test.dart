import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/services/multi_cylinder_consumption.dart';

void main() {
  group('referenceBarsPerBar', () {
    const backGas = DiveTank(id: 'bg', volume: 12, role: TankRole.backGas);

    test('a cylinder is worth itself, even with no size', () {
      const unsized = DiveTank(id: 'st', role: TankRole.stage);

      expect(referenceBarsPerBar(backGas, backGas, const [backGas]), 1);
      expect(referenceBarsPerBar(unsized, unsized, const [unsized]), 1);
    });

    test('scales a sized cylinder by volume', () {
      const stage = DiveTank(id: 'st', volume: 6, role: TankRole.stage);

      expect(referenceBarsPerBar(stage, backGas, const [backGas, stage]), 0.5);
    });

    test('a matched pair with no sizes counts one to one', () {
      const left = DiveTank(id: 'l', role: TankRole.sidemountLeft);
      const right = DiveTank(id: 'r', role: TankRole.sidemountRight);

      expect(referenceBarsPerBar(right, left, const [left, right]), 1);
    });

    test('a pair takes its partner size', () {
      const left = DiveTank(id: 'l', volume: 12, role: TankRole.sidemountLeft);
      const right = DiveTank(id: 'r', role: TankRole.sidemountRight);

      expect(referenceBarsPerBar(right, left, const [left, right]), 1);
    });

    test('an unsized cylinder that is no pair cannot be related', () {
      const stage = DiveTank(id: 'st', role: TankRole.stage);

      expect(
        referenceBarsPerBar(stage, backGas, const [backGas, stage]),
        isNull,
      );
    });
  });

  group('twin set (issue #3374)', () {
    DiveTank tank(TankRole role, {double o2 = 21}) => DiveTank(
      id: role.name,
      role: role,
      gasMix: GasMix(o2: o2),
    );

    test('two twin set rows are a matched pair whatever their gas', () {
      expect(
        isMatchedPair(tank(TankRole.twinSet), tank(TankRole.twinSet, o2: 32)),
        isTrue,
      );
    });

    test('a twin set is the SAC reference ahead of a stage', () {
      final twin = tank(TankRole.twinSet);
      expect(sacReferenceTankOf([tank(TankRole.stage), twin]), same(twin));
    });
  });
}
