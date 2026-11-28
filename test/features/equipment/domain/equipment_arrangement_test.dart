import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/sort_options.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_type_order.dart';
import 'package:submersion/features/equipment/domain/models/equipment_arrangement.dart';

void main() {
  test('defaults group by type, alphabetically, items A to Z', () {
    const d = EquipmentArrangement.defaults;
    expect(d.groupByType, isTrue);
    expect(d.typeOrder, EquipmentTypeOrder.alphabetical);
    expect(d.itemSortField, EquipmentItemSortField.name);
    expect(d.itemSortDirection, SortDirection.ascending);
    expect(d.typeOrderDescending, isFalse);
  });

  test('round-trips through JSON', () {
    const original = EquipmentArrangement(
      typeOrder: EquipmentTypeOrder.dressingOrder,
      typeOrderDescending: true,
      groupByType: false,
      itemSortField: EquipmentItemSortField.purchaseDate,
      itemSortDirection: SortDirection.descending,
    );

    expect(EquipmentArrangement.fromJson(original.toJson()), original);
  });

  test('an unknown enum value degrades to the default for that axis', () {
    final decoded = EquipmentArrangement.fromJson({
      'typeOrder': 'zodiacal',
      'groupByType': true,
      'itemSortField': 'phaseOfMoon',
      'itemSortDirection': 'sideways',
    });

    expect(decoded.typeOrder, EquipmentArrangement.defaults.typeOrder);
    expect(decoded.itemSortField, EquipmentArrangement.defaults.itemSortField);
    expect(
      decoded.itemSortDirection,
      EquipmentArrangement.defaults.itemSortDirection,
    );
  });

  test('a non-bool typeOrderDescending degrades to the default', () {
    final decoded = EquipmentArrangement.fromJson({
      'typeOrderDescending': 'backwards',
    });

    expect(decoded.typeOrderDescending, isFalse);
  });

  test('a partial or wrongly typed blob degrades to defaults', () {
    expect(EquipmentArrangement.fromJson({}), EquipmentArrangement.defaults);
    expect(
      EquipmentArrangement.fromJson({'groupByType': 'yes please'}),
      EquipmentArrangement.defaults,
    );
  });

  test('copyWith replaces only the named axis', () {
    final changed = EquipmentArrangement.defaults.copyWith(groupByType: false);

    expect(changed.groupByType, isFalse);
    expect(changed.typeOrder, EquipmentArrangement.defaults.typeOrder);
    expect(changed.itemSortField, EquipmentArrangement.defaults.itemSortField);
  });

  test('equal arrangements hash equally', () {
    // Load-bearing rather than boilerplate: the arrangement is compared by
    // value to decide provider rebuilds, and a broken hashCode would silently
    // misbehave the moment one is used as a Set or Map key.
    const a = EquipmentArrangement(
      typeOrder: EquipmentTypeOrder.dressingOrder,
      typeOrderDescending: true,
      groupByType: false,
      itemSortField: EquipmentItemSortField.dateAdded,
      itemSortDirection: SortDirection.descending,
    );
    const b = EquipmentArrangement(
      typeOrder: EquipmentTypeOrder.dressingOrder,
      typeOrderDescending: true,
      groupByType: false,
      itemSortField: EquipmentItemSortField.dateAdded,
      itemSortDirection: SortDirection.descending,
    );

    expect(a, b);
    expect(a.hashCode, b.hashCode);
    // Every axis participates, so a difference in any one is distinguishable.
    expect({
      EquipmentArrangement.defaults,
      EquipmentArrangement.defaults.copyWith(typeOrderDescending: true),
      EquipmentArrangement.defaults.copyWith(groupByType: false),
      EquipmentArrangement.defaults.copyWith(
        typeOrder: EquipmentTypeOrder.canonical,
      ),
      EquipmentArrangement.defaults.copyWith(
        itemSortField: EquipmentItemSortField.dateAdded,
      ),
      EquipmentArrangement.defaults.copyWith(
        itemSortDirection: SortDirection.descending,
      ),
    }, hasLength(6));
  });

  test('equality is by value, so provider rebuilds are not spurious', () {
    expect(
      EquipmentArrangement.defaults,
      equals(
        const EquipmentArrangement(
          typeOrder: EquipmentTypeOrder.alphabetical,
          groupByType: true,
          itemSortField: EquipmentItemSortField.name,
          itemSortDirection: SortDirection.ascending,
        ),
      ),
    );
  });

  group('nestParts (#5071)', () {
    test('defaults to on', () {
      expect(EquipmentArrangement.defaults.nestParts, isTrue);
    });

    test('an absent or non-bool value reads as on', () {
      expect(EquipmentArrangement.fromJson(const {}).nestParts, isTrue);
      expect(
        EquipmentArrangement.fromJson(const {'nestParts': 'no'}).nestParts,
        isTrue,
      );
      expect(
        EquipmentArrangement.fromJson(const {'nestParts': false}).nestParts,
        isFalse,
      );
    });

    test('is written to JSON', () {
      final off = EquipmentArrangement.defaults.copyWith(nestParts: false);
      expect(off.toJson()['nestParts'], isFalse);
    });

    test('takes part in equality', () {
      final off = EquipmentArrangement.defaults.copyWith(nestParts: false);
      expect(off, isNot(EquipmentArrangement.defaults));
      expect(off.hashCode, isNot(EquipmentArrangement.defaults.hashCode));
    });

    test('unknown keys with nested values compare by value', () {
      EquipmentArrangement read() => EquipmentArrangement.fromJson(
        jsonDecode('{"futureAxis": [1, 2]}') as Map<String, dynamic>,
      );
      expect(read(), read());
    });

    test('keys this build does not know survive a round trip', () {
      final read = EquipmentArrangement.fromJson(const {
        'futureAxis': 3,
        'groupByType': false,
      });
      expect(read.toJson()['futureAxis'], 3);
      expect(read.copyWith(groupByType: true).toJson()['futureAxis'], 3);
    });

    test('resetting the shared axes keeps nestParts and unknown keys', () {
      final read = EquipmentArrangement.fromJson(const {
        'futureAxis': 3,
        'typeOrder': 'dressingOrder',
        'groupByType': false,
        'nestParts': false,
      });
      final reset = read.resetSharedAxes();
      expect(reset.typeOrder, EquipmentArrangement.defaults.typeOrder);
      expect(reset.groupByType, isTrue);
      expect(reset.nestParts, isFalse);
      expect(reset.toJson()['futureAxis'], 3);
    });
  });
}
