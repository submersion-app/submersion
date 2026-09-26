import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/utils/usable_set_items.dart';

void main() {
  EquipmentItem item(String id) =>
      EquipmentItem(id: id, name: id, type: EquipmentType.bcd);

  test('keeps visible members in set order', () {
    expect(
      usableSetItems(
        [item('c'), item('a'), item('b')],
        {'a', 'c'},
      ).map((i) => i.id),
      ['c', 'a'],
    );
  });

  test('nothing visible applies nothing', () {
    expect(usableSetItems([item('a')], const {}), isEmpty);
  });
}
