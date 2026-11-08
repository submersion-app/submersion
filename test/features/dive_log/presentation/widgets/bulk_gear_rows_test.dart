import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/sort_options.dart';
import 'package:submersion/features/dive_log/presentation/widgets/bulk_gear_rows.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_type_order.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/models/equipment_arrangement.dart';

/// The bulk editor's gear rows follow the diver's gear arrangement (#2274),
/// as the single-dive gear list does.
void main() {
  const headToToe = EquipmentArrangement(
    typeOrder: EquipmentTypeOrder.headToToe,
    groupByType: true,
    itemSortField: EquipmentItemSortField.name,
    itemSortDirection: SortDirection.ascending,
  );
  const zeagle = EquipmentItem(
    id: 'bcd-1',
    name: 'Zeagle',
    type: EquipmentType.bcd,
  );
  const faber = EquipmentItem(
    id: 'tank-1',
    name: 'Faber',
    type: EquipmentType.tank,
  );
  const apeks = EquipmentItem(
    id: 'reg-1',
    name: 'Apeks',
    type: EquipmentType.regulator,
  );
  const atomic = EquipmentItem(
    id: 'reg-2',
    name: 'Atomic',
    type: EquipmentType.regulator,
  );

  String typeLabel(EquipmentType type) => type.name;

  test('grouped rows follow the type order with one heading per type', () {
    final rows = arrangeBulkGearRows(
      const [zeagle, atomic, faber, apeks],
      headToToe,
      typeLabel: typeLabel,
    );

    expect(rows.items.map((r) => r.label), [
      'Faber',
      'Apeks',
      'Atomic',
      'Zeagle',
    ]);
    // The heading sits on the first row of each type only.
    expect(rows.headings, {
      'tank-1': EquipmentType.tank,
      'reg-1': EquipmentType.regulator,
      'bcd-1': EquipmentType.bcd,
    });
  });

  test('without grouping the rows are ordered but carry no headings', () {
    final rows = arrangeBulkGearRows(
      const [faber, apeks, zeagle],
      headToToe.copyWith(
        typeOrder: EquipmentTypeOrder.none,
        groupByType: false,
        itemSortDirection: SortDirection.descending,
      ),
      typeLabel: typeLabel,
    );

    expect(rows.items.map((r) => r.label), ['Zeagle', 'Faber', 'Apeks']);
    expect(rows.headings, isEmpty);
  });

  test('each row keeps the item id and its type icon', () {
    final rows = arrangeBulkGearRows(
      const [apeks],
      headToToe,
      typeLabel: typeLabel,
    );

    expect(rows.items.single.id, 'reg-1');
    expect(rows.items.single.icon, isNotNull);
  });

  test('no gear gives no rows', () {
    final rows = arrangeBulkGearRows(const [], headToToe, typeLabel: typeLabel);

    expect(rows.items, isEmpty);
    expect(rows.headings, isEmpty);
  });
}
