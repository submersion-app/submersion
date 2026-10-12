import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

void main() {
  const tank = DiveTank(id: 't1', passportId: 'p-1');

  test('copyWith keeps, replaces and clears the passport id', () {
    expect(tank.copyWith(startPressure: 200).passportId, 'p-1');
    expect(tank.copyWith(passportId: 'p-2').passportId, 'p-2');
    expect(tank.copyWith(clearPassportId: true).passportId, isNull);
  });

  test('the passport id is part of equality', () {
    expect(tank, isNot(const DiveTank(id: 't1')));
    expect(tank, const DiveTank(id: 't1', passportId: 'p-1'));
  });
}
