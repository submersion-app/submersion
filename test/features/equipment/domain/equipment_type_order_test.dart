import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_type_order.dart';

void main() {
  final tables = {
    'headToToe': kHeadToToeTypeOrder,
    'dressingOrder': kDressingTypeOrder,
    'canonical': kCanonicalTypeOrder,
  };

  // The permutation guard is the point of this suite: it is what turns adding
  // a 29th EquipmentType into a loud failure rather than three silent
  // misorderings.
  for (final entry in tables.entries) {
    test('${entry.key} is an exact permutation of EquipmentType.values', () {
      final table = entry.value;
      expect(
        table.length,
        EquipmentType.values.length,
        reason: '${entry.key} has the wrong number of entries',
      );
      expect(
        table.toSet().length,
        table.length,
        reason: '${entry.key} contains a duplicate',
      );
      final missing = EquipmentType.values.toSet().difference(table.toSet());
      expect(
        missing,
        isEmpty,
        reason: '${entry.key} is missing ${missing.map((t) => t.name)}',
      );
    });
  }

  test('every order value maps to a table or to null', () {
    for (final order in EquipmentTypeOrder.values) {
      final table = equipmentTypeRankTable(order);
      final expectsTable =
          order != EquipmentTypeOrder.none &&
          order != EquipmentTypeOrder.alphabetical;
      expect(table != null, expectsTable, reason: order.name);
    }
  });

  test('rank follows table position', () {
    expect(equipmentTypeRank(EquipmentType.hood, kHeadToToeTypeOrder), 0);
    expect(
      equipmentTypeRank(EquipmentType.fins, kHeadToToeTypeOrder),
      kHeadToToeTypeOrder.length - 2,
    );
    expect(equipmentTypeRank(EquipmentType.rashGuard, kDressingTypeOrder), 0);
  });
}
