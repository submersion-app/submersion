import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/services/equipment_arranger.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_group_cap.dart';

void main() {
  EquipmentGroup groupOf(
    int count, {
    EquipmentType? type = EquipmentType.bcd,
  }) => EquipmentGroup(
    type: type,
    items: [
      for (var i = 0; i < count; i++)
        EquipmentItem(id: 'item$i', name: 'Item $i', type: EquipmentType.bcd),
    ],
  );

  List<String> tailIds(EquipmentGroup g) => [
    for (final item in cappedGroupTail(g)) item.id,
  ];

  group('cappedGroupTail', () {
    test('hides nothing in a group of four, whose tail would be one item', () {
      expect(cappedGroupTail(groupOf(4)), isEmpty);
    });

    test('hides everything past the third item from five items up', () {
      expect(tailIds(groupOf(5)), ['item3', 'item4']);
      expect(tailIds(groupOf(7)), ['item3', 'item4', 'item5', 'item6']);
    });

    test('never caps an ungrouped run, which has no heading to sit under', () {
      expect(cappedGroupTail(groupOf(12, type: null)), isEmpty);
    });
  });
}
