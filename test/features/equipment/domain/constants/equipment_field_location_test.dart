import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_field.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

/// The table's Location column (issue #3625): each item's current place.
void main() {
  const item = EquipmentItem(id: 'reg', name: 'Reg', type: EquipmentType.bcd);
  const units = UnitFormatter(AppSettings());

  test('location is appended last so saved layouts keep their order', () {
    const values = EquipmentField.values;
    expect(values.last, EquipmentField.location);
    expect(values[values.length - 2], EquipmentField.owner);
    expect(
      EquipmentFieldAdapter.instance.fieldFromName('location'),
      EquipmentField.location,
    );
  });

  test('location is a sortable details column', () {
    expect(EquipmentField.location.sortable, isTrue);
    expect(EquipmentField.location.categoryName, 'details');
    expect(EquipmentField.location.isRightAligned, isFalse);
  });

  test("location reads the item's place from the injected map", () {
    final adapter = EquipmentFieldAdapter(
      locationNames: const {'reg': "Joe's Scuba"},
    );
    final value = adapter.extractValue(EquipmentField.location, item);
    expect(value, "Joe's Scuba");
    expect(
      adapter.formatValue(EquipmentField.location, value, units),
      "Joe's Scuba",
    );
  });

  test('an item with no recorded place shows the empty placeholder', () {
    final adapter = EquipmentFieldAdapter();
    final value = adapter.extractValue(EquipmentField.location, item);
    expect(adapter.formatValue(EquipmentField.location, value, units), '--');
  });
}
