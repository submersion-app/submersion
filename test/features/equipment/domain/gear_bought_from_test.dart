import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/services/gear_bought_from.dart';

/// The gear a buddy or dive centre sold the diver (issue #5140).
void main() {
  EquipmentItem item(
    String id, {
    String? buddy,
    String? centre,
    DateTime? bought,
    EquipmentStatus status = EquipmentStatus.active,
  }) => EquipmentItem(
    id: id,
    name: id,
    type: EquipmentType.regulator,
    status: status,
    purchaseDate: bought,
    sellerBuddyId: buddy,
    sellerDiveCenterId: centre,
  );

  final items = [
    item('old', buddy: 'b1', bought: DateTime(2020)),
    item('undated b', buddy: 'b1'),
    item('new', buddy: 'b1', bought: DateTime(2025)),
    item('undated a', buddy: 'b1'),
    item('other', buddy: 'b2', bought: DateTime(2024)),
    item('shop', centre: 'c1', bought: DateTime(2023)),
    item(
      'sold on',
      buddy: 'b1',
      bought: DateTime(2022),
      status: EquipmentStatus.sold,
    ),
    item('wish', buddy: 'b1', status: EquipmentStatus.wanted),
  ];

  test('newest purchase first, undated last by name', () {
    expect(gearBoughtFrom(items, buddyId: 'b1').map((i) => i.id), [
      'new',
      'sold on',
      'old',
      'undated a',
      'undated b',
    ]);
  });

  test('a wishlist item is not bought yet', () {
    expect(
      gearBoughtFrom(items, buddyId: 'b1').map((i) => i.id),
      isNot(contains('wish')),
    );
  });

  test('a dive centre lists what was bought there', () {
    expect(gearBoughtFrom(items, centerId: 'c1').map((i) => i.id), ['shop']);
  });

  test('nobody named lists nothing', () {
    expect(gearBoughtFrom(items), isEmpty);
  });
}
