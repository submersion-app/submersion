import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/sort_options.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_type_order.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/models/equipment_arrangement.dart';
import 'package:submersion/features/equipment/domain/services/equipment_arranger.dart';

EquipmentItem item(
  String id,
  String name,
  EquipmentType type, {
  DateTime? purchased,
  DateTime? added,
  DateTime? serviced,
}) => EquipmentItem(
  id: id,
  name: name,
  type: type,
  purchaseDate: purchased,
  createdAt: added,
  lastServiceDate: serviced,
);

String english(EquipmentType t) => t.displayName;

void main() {
  final gear = [
    item('3', 'Zeagle', EquipmentType.bcd),
    item('1', 'Apeks', EquipmentType.regulator),
    item('2', 'Aqualung', EquipmentType.regulator),
    item('4', 'Faber', EquipmentType.tank),
  ];

  test('groups by type and orders headers alphabetically', () {
    final groups = arrangeEquipment(
      gear,
      EquipmentArrangement.defaults,
      typeLabel: english,
    );

    expect(groups.map((g) => g.type).toList(), [
      EquipmentType.bcd,
      EquipmentType.regulator,
      EquipmentType.tank,
    ]);
    expect(groups[1].items.map((i) => i.name).toList(), ['Apeks', 'Aqualung']);
  });

  test('alphabetical follows the injected label, not the English name', () {
    // A resolver whose ordering differs from English, standing in for a
    // locale where the translated type names sort differently.
    String reversed(EquipmentType t) => switch (t) {
      EquipmentType.bcd => 'Zzz',
      EquipmentType.regulator => 'Aaa',
      EquipmentType.tank => 'Mmm',
      _ => t.displayName,
    };

    final groups = arrangeEquipment(
      gear,
      EquipmentArrangement.defaults,
      typeLabel: reversed,
    );

    expect(groups.map((g) => g.type).toList(), [
      EquipmentType.regulator,
      EquipmentType.tank,
      EquipmentType.bcd,
    ]);
  });

  test('head to toe orders headers by the curated table', () {
    final groups = arrangeEquipment(
      gear,
      EquipmentArrangement.defaults.copyWith(
        typeOrder: EquipmentTypeOrder.headToToe,
      ),
      typeLabel: english,
    );

    // Head to toe puts tank before regulator before bcd.
    expect(groups.map((g) => g.type).toList(), [
      EquipmentType.tank,
      EquipmentType.regulator,
      EquipmentType.bcd,
    ]);
  });

  test('groupByType false yields one headerless group, still type-ordered', () {
    final groups = arrangeEquipment(
      gear,
      EquipmentArrangement.defaults.copyWith(groupByType: false),
      typeLabel: english,
    );

    expect(groups, hasLength(1));
    expect(groups.single.type, isNull);
    expect(groups.single.items.map((i) => i.name).toList(), [
      'Zeagle',
      'Apeks',
      'Aqualung',
      'Faber',
    ]);
  });

  test('typeOrder none ignores type entirely', () {
    final groups = arrangeEquipment(
      gear,
      EquipmentArrangement.defaults.copyWith(
        typeOrder: EquipmentTypeOrder.none,
        groupByType: false,
      ),
      typeLabel: english,
    );

    expect(groups.single.items.map((i) => i.name).toList(), [
      'Apeks',
      'Aqualung',
      'Faber',
      'Zeagle',
    ]);
  });

  test('typeOrder none forces headers off even when groupByType is set', () {
    final groups = arrangeEquipment(
      gear,
      EquipmentArrangement.defaults.copyWith(
        typeOrder: EquipmentTypeOrder.none,
      ),
      typeLabel: english,
    );

    expect(groups, hasLength(1));
    expect(groups.single.type, isNull);
  });

  test('descending reverses the item sort but not the type order', () {
    final groups = arrangeEquipment(
      gear,
      EquipmentArrangement.defaults.copyWith(
        itemSortDirection: SortDirection.descending,
      ),
      typeLabel: english,
    );

    expect(groups.first.type, EquipmentType.bcd);
    expect(groups[1].items.map((i) => i.name).toList(), ['Aqualung', 'Apeks']);
  });

  test('items with no date sort last in both directions', () {
    final mixed = [
      item('a', 'Dated', EquipmentType.tank, purchased: DateTime(2020)),
      item('b', 'Undated', EquipmentType.tank),
      item('c', 'Older', EquipmentType.tank, purchased: DateTime(2010)),
    ];

    List<String> namesFor(SortDirection d) => arrangeEquipment(
      mixed,
      EquipmentArrangement.defaults.copyWith(
        itemSortField: EquipmentItemSortField.purchaseDate,
        itemSortDirection: d,
      ),
      typeLabel: english,
    ).single.items.map((i) => i.name).toList();

    expect(namesFor(SortDirection.ascending), ['Older', 'Dated', 'Undated']);
    expect(namesFor(SortDirection.descending), ['Dated', 'Older', 'Undated']);
  });

  test('sorts by date added', () {
    final mixed = [
      item('a', 'Second', EquipmentType.tank, added: DateTime(2021)),
      item('b', 'First', EquipmentType.tank, added: DateTime(2019)),
    ];

    final groups = arrangeEquipment(
      mixed,
      EquipmentArrangement.defaults.copyWith(
        itemSortField: EquipmentItemSortField.dateAdded,
      ),
      typeLabel: english,
    );

    expect(groups.single.items.map((i) => i.name).toList(), [
      'First',
      'Second',
    ]);
  });

  test('sorts by last service date', () {
    final mixed = [
      item('a', 'Recent', EquipmentType.tank, serviced: DateTime(2025)),
      item('b', 'Overdue', EquipmentType.tank, serviced: DateTime(2018)),
    ];

    final groups = arrangeEquipment(
      mixed,
      EquipmentArrangement.defaults.copyWith(
        itemSortField: EquipmentItemSortField.lastServiceDate,
      ),
      typeLabel: english,
    );

    expect(groups.single.items.map((i) => i.name).toList(), [
      'Overdue',
      'Recent',
    ]);
  });

  test('ties break deterministically across repeated calls', () {
    final twins = [
      item('z', 'Same', EquipmentType.tank),
      item('a', 'Same', EquipmentType.tank),
    ];

    final first = arrangeEquipment(
      twins,
      EquipmentArrangement.defaults,
      typeLabel: english,
    ).single.items.map((i) => i.id).toList();
    final second = arrangeEquipment(
      twins.reversed.toList(),
      EquipmentArrangement.defaults,
      typeLabel: english,
    ).single.items.map((i) => i.id).toList();

    expect(first, second);
    expect(first, ['a', 'z']);
  });

  test('the type order can be reversed (toe to head, #1486)', () {
    final groups = arrangeEquipment(
      gear,
      EquipmentArrangement.defaults.copyWith(
        typeOrder: EquipmentTypeOrder.headToToe,
        typeOrderDescending: true,
      ),
      typeLabel: english,
    );

    // Head to toe is tank, regulator, bcd; reversed it is bcd first.
    expect(groups.map((g) => g.type).toList(), [
      EquipmentType.bcd,
      EquipmentType.regulator,
      EquipmentType.tank,
    ]);
  });

  test('reversing the type order leaves the item order alone', () {
    final groups = arrangeEquipment(
      gear,
      EquipmentArrangement.defaults.copyWith(typeOrderDescending: true),
      typeLabel: english,
    );

    // Types reversed (Tank, Regulator, BCD) but names still ascend inside.
    expect(groups.first.type, EquipmentType.tank);
    expect(groups[1].items.map((i) => i.name).toList(), ['Apeks', 'Aqualung']);
  });

  test('reverse alphabetical type order', () {
    final groups = arrangeEquipment(
      gear,
      EquipmentArrangement.defaults.copyWith(typeOrderDescending: true),
      typeLabel: english,
    );

    expect(groups.map((g) => g.type).toList(), [
      EquipmentType.tank,
      EquipmentType.regulator,
      EquipmentType.bcd,
    ]);
  });

  test('resolves each type label at most once, not per comparison', () {
    // compareTypes runs inside the ITEM comparator when not grouping, so a
    // label resolved in there costs O(n log n) calls and two String
    // allocations each. Pinned so a refactor cannot silently undo it.
    final calls = <EquipmentType>[];
    String counting(EquipmentType t) {
      calls.add(t);
      return t.displayName;
    }

    final many = [
      for (var i = 0; i < 40; i++)
        item('i\$i', 'Item \$i', EquipmentType.values[i % 6]),
    ];

    arrangeEquipment(
      many,
      EquipmentArrangement.defaults.copyWith(groupByType: false),
      typeLabel: counting,
    );

    expect(calls.toSet(), hasLength(6), reason: 'six distinct types present');
    expect(
      calls,
      hasLength(6),
      reason: 'resolved once each, not once per comparison',
    );
  });

  test('does not mutate the caller list', () {
    final input = List<EquipmentItem>.from(gear);

    arrangeEquipment(input, EquipmentArrangement.defaults, typeLabel: english);

    expect(input.map((i) => i.id).toList(), ['3', '1', '2', '4']);
  });

  test('an empty list yields no groups', () {
    expect(
      arrangeEquipment(
        const [],
        EquipmentArrangement.defaults,
        typeLabel: english,
      ),
      isEmpty,
    );
  });

  group('compareItems override (the Equipment page)', () {
    // The Equipment page keeps its own item sort, which includes Service Due,
    // but shares the type axis with every other gear surface. Its comparator
    // replaces the arrangement's item sort; the type axis is untouched.
    int byNameDescending(EquipmentItem a, EquipmentItem b) =>
        b.name.compareTo(a.name);

    test('orders items inside each group, headers still by type order', () {
      final groups = arrangeEquipment(
        gear,
        EquipmentArrangement.defaults,
        typeLabel: english,
        compareItems: byNameDescending,
      );

      expect(groups.map((g) => g.type).toList(), [
        EquipmentType.bcd,
        EquipmentType.regulator,
        EquipmentType.tank,
      ]);
      expect(groups[1].items.map((i) => i.name).toList(), [
        'Aqualung',
        'Apeks',
      ]);
    });

    test('orders a flat list after the type axis', () {
      final groups = arrangeEquipment(
        gear,
        EquipmentArrangement.defaults.copyWith(groupByType: false),
        typeLabel: english,
        compareItems: byNameDescending,
      );

      expect(groups.single.type, isNull);
      expect(groups.single.items.map((i) => i.name).toList(), [
        'Zeagle', // BCD
        'Aqualung', // Regulator
        'Apeks', // Regulator
        'Faber', // Tank
      ]);
    });

    test('alone orders the list when nothing orders the types', () {
      final groups = arrangeEquipment(
        gear,
        EquipmentArrangement.defaults.copyWith(
          typeOrder: EquipmentTypeOrder.none,
        ),
        typeLabel: english,
        compareItems: byNameDescending,
      );

      expect(groups.single.items.map((i) => i.name).toList(), [
        'Zeagle',
        'Faber',
        'Aqualung',
        'Apeks',
      ]);
    });
  });
}
