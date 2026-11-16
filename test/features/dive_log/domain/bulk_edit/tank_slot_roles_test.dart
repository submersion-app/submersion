import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/app_enums.dart';
import 'package:submersion/features/dive_log/domain/bulk_edit/tank_slot_roles.dart';

void main() {
  const sidemount = [TankRole.sidemountLeft, TankRole.sidemountRight];

  group('slotRolesForDive', () {
    test('assigns roles by ascending order regardless of list order', () {
      expect(
        slotRolesForDive(const [
          (id: 'b', order: 1),
          (id: 'a', order: 0),
        ], sidemount),
        {'a': TankRole.sidemountLeft, 'b': TankRole.sidemountRight},
      );
    });

    test('returns null when the dive has more tanks than positions', () {
      expect(
        slotRolesForDive(const [
          (id: 'a', order: 0),
          (id: 'b', order: 1),
          (id: 'c', order: 2),
        ], sidemount),
        isNull,
      );
    });

    test('returns null when the dive has fewer tanks than positions', () {
      expect(slotRolesForDive(const [(id: 'a', order: 0)], sidemount), isNull);
    });

    // Which cylinder is "tank 1" is a guess when two share an order.
    test('returns null when two tanks share an order', () {
      expect(
        slotRolesForDive(const [
          (id: 'a', order: 0),
          (id: 'b', order: 0),
        ], sidemount),
        isNull,
      );
    });

    test('returns null for no positions', () {
      expect(slotRolesForDive(const [], const []), isNull);
    });

    test('does not reorder the list it is given', () {
      final tanks = [(id: 'b', order: 1), (id: 'a', order: 0)];
      slotRolesForDive(tanks, sidemount);
      expect(tanks.first.id, 'b');
    });
  });
}
