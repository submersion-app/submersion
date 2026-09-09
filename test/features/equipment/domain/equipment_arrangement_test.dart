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
  });

  test('round-trips through JSON', () {
    const original = EquipmentArrangement(
      typeOrder: EquipmentTypeOrder.dressingOrder,
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
}
