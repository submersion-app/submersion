import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/data/sql/multi_cylinder_sac_sql.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/services/multi_cylinder_consumption.dart';

/// A suit inflation cylinder is not breathing gas (issue #4243): the one
/// rule every gas calculation starts from.
void main() {
  test('suit inflation is the only role that is not breathing gas', () {
    for (final role in TankRole.values) {
      expect(
        role.isBreathingGas,
        role != TankRole.suitInflation,
        reason: '$role',
      );
    }
  });

  test('the suit inflation role is stored and shown as Suit Inflation', () {
    expect(TankRole.suitInflation.name, 'suitInflation');
    expect(TankRole.suitInflation.displayName, 'Suit Inflation');
  });

  test('breathingTanks drops suit cylinders and keeps the order', () {
    const suit = DiveTank(id: 's', role: TankRole.suitInflation);
    const left = DiveTank(id: 'l', role: TankRole.sidemountLeft);
    const right = DiveTank(id: 'r', role: TankRole.sidemountRight);

    expect(breathingTanks(const [suit, left, right]), const [left, right]);
    expect(breathingTanks(const [suit]), isEmpty);
  });

  test('Dive.breathingTanks leaves the suit cylinder out', () {
    const back = DiveTank(id: 'b', role: TankRole.backGas);
    const suit = DiveTank(id: 's', role: TankRole.suitInflation);
    final dive = Dive(
      id: 'd',
      dateTime: DateTime(2026, 11, 6),
      tanks: const [suit, back],
    );

    expect(dive.breathingTanks, const [back]);
    expect(dive.tanks, const [suit, back]);
  });

  test('breathingTankSql keeps rows with no role', () {
    expect(
      breathingTankSql('t'),
      "(t.tank_role IS NULL OR t.tank_role <> 'suitInflation')",
    );
  });

  group('TankRole.fromName', () {
    test('reads every stored name', () {
      for (final role in TankRole.values) {
        expect(TankRole.fromName(role.name), role);
      }
    });

    test('a name this build does not know reads as back gas', () {
      expect(TankRole.fromName('argonBottle'), TankRole.backGas);
      expect(TankRole.fromName(null), TankRole.backGas);
    });
  });
}
