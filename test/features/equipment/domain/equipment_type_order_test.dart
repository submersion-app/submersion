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
    // Stated as relationships rather than arithmetic on length: the earlier
    // version pinned fins to `length - 2`, which broke the moment the
    // consumable tail grew even though fins had not moved.
    expect(equipmentTypeRank(EquipmentType.hood, kHeadToToeTypeOrder), 0);
    expect(equipmentTypeRank(EquipmentType.rashGuard, kDressingTypeOrder), 0);

    int rank(EquipmentType t) => equipmentTypeRank(t, kHeadToToeTypeOrder);
    // Fins are the toe end of the worn sequence.
    expect(rank(EquipmentType.fins), greaterThan(rank(EquipmentType.boots)));
    expect(rank(EquipmentType.fins), greaterThan(rank(EquipmentType.hood)));
  });

  test('consumable child parts tail every sequence', () {
    // They live inside another item, so they have no place in an anatomical
    // or a dressing sequence and must not displace worn gear.
    for (final table in tables.values) {
      for (final part in [EquipmentType.o2Cell, EquipmentType.battery]) {
        expect(
          equipmentTypeRank(part, table),
          greaterThan(equipmentTypeRank(EquipmentType.fins, table)),
          reason: '${part.name} should sit after the gear a diver wears',
        );
      }
    }
  });

  group('sortEquipmentTypesByLabel (#2937)', () {
    test('orders by label, not by enum declaration order', () {
      final sorted = sortEquipmentTypesByLabel(
        EquipmentType.values,
        (t) => t.displayName,
      );
      final labels = [for (final t in sorted) t.displayName.toLowerCase()];
      expect(labels, [...labels]..sort());
      expect(sorted.toSet(), EquipmentType.values.toSet());
      // The enum opens with regulator; alphabetically it cannot lead.
      expect(sorted.first, isNot(EquipmentType.regulator));
    });

    test('compares case-insensitively', () {
      final sorted = sortEquipmentTypesByLabel([
        EquipmentType.mask,
        EquipmentType.fins,
      ], (t) => t == EquipmentType.mask ? 'apple' : 'Banana');
      expect(sorted, [EquipmentType.mask, EquipmentType.fins]);
    });

    test('places an accented label by its base letter', () {
      // French labels the transmitter "Émetteur". By code unit "é"
      // sorts after "z", which put it last instead of before "Gilet".
      final sorted = sortEquipmentTypesByLabel([
        EquipmentType.bcd,
        EquipmentType.transmitter,
      ], (t) => t == EquipmentType.transmitter ? '\u00c9metteur' : 'Gilet');
      expect(sorted, [EquipmentType.transmitter, EquipmentType.bcd]);
    });

    test('breaks a shared label by enum name, whatever the input order', () {
      String label(EquipmentType _) => 'same';
      expect(
        sortEquipmentTypesByLabel([
          EquipmentType.wing,
          EquipmentType.bcd,
        ], label),
        [EquipmentType.bcd, EquipmentType.wing],
      );
      expect(
        sortEquipmentTypesByLabel([
          EquipmentType.bcd,
          EquipmentType.wing,
        ], label),
        [EquipmentType.bcd, EquipmentType.wing],
      );
    });

    test('follows the label, so a locale can reorder the list', () {
      // Light precedes mask by name and in English; a translation that sorts
      // it last must win, because the reader sees the label, not the name.
      final sorted = sortEquipmentTypesByLabel([
        EquipmentType.light,
        EquipmentType.mask,
      ], (t) => t == EquipmentType.light ? 'Zubehoer' : 'Maske');
      expect(sorted, [EquipmentType.mask, EquipmentType.light]);
    });

    test('returns a new list and leaves the input untouched', () {
      final input = List<EquipmentType>.unmodifiable([
        EquipmentType.wing,
        EquipmentType.bcd,
      ]);
      final sorted = sortEquipmentTypesByLabel(input, (t) => t.name);
      expect(sorted, [EquipmentType.bcd, EquipmentType.wing]);
      expect(input, [EquipmentType.wing, EquipmentType.bcd]);
    });
  });
}
