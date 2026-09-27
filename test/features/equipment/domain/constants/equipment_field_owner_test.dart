import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_field.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';

void main() {
  test('owner is appended last so saved layouts keep their order', () {
    expect(EquipmentField.values.last, EquipmentField.owner);
    expect(
      EquipmentFieldAdapter.instance.fieldFromName('owner'),
      EquipmentField.owner,
    );
  });

  test('owner resolves the name from the injected map', () {
    final adapter = EquipmentFieldAdapter(ownerNames: const {"wife": "Anna"});
    const item = EquipmentItem(
      id: 'a',
      diverId: 'wife',
      name: 'a',
      type: EquipmentType.bcd,
    );
    expect(adapter.extractValue(EquipmentField.owner, item), 'Anna');
  });
}
