import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/dive_centers/domain/entities/dive_center.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_attribute.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_seller.dart';

/// Reading a gear item's seller (issue #5140).
void main() {
  final t = DateTime(2025);
  final anna = Buddy(id: 'b1', name: 'Anna B.', createdAt: t, updatedAt: t);
  final anchor = DiveCenter(
    id: 'c1',
    name: 'Anchor Dive',
    createdAt: t,
    updatedAt: t,
  );

  EquipmentItem item({String? retailer, String? buddy, String? centre}) =>
      EquipmentItem(
        id: 'e1',
        name: 'Reg',
        type: EquipmentType.regulator,
        sellerBuddyId: buddy,
        sellerDiveCenterId: centre,
        attributes: [
          if (retailer != null)
            EquipmentAttribute.curated(
              equipmentId: 'e1',
              key: 'retailer',
              valueText: retailer,
            ),
        ],
      );

  EquipmentSeller? resolve(EquipmentItem i) => resolveEquipmentSeller(
    i,
    buddies: {anna.id: anna},
    centers: {anchor.id: anchor},
  );

  test('a linked buddy reads with its current name, not the snapshot', () {
    final seller = resolve(item(retailer: 'Anna', buddy: 'b1'))!;
    expect(seller.kind, EquipmentSellerKind.buddy);
    expect(seller.id, 'b1');
    expect(seller.name, 'Anna B.');
  });

  test('a linked dive centre reads with its current name', () {
    final seller = resolve(item(retailer: 'Anchor', centre: 'c1'))!;
    expect(seller.kind, EquipmentSellerKind.diveCenter);
    expect(seller.id, 'c1');
    expect(seller.name, 'Anchor Dive');
  });

  test('a link this profile cannot resolve reads as the typed snapshot', () {
    final seller = resolve(item(retailer: 'Lars Holm', buddy: 'b9'))!;
    expect(seller.kind, EquipmentSellerKind.typed);
    expect(seller.id, isNull);
    expect(seller.name, 'Lars Holm');
  });

  test('a typed seller reads as typed', () {
    final seller = resolve(item(retailer: 'Dive Shop Ltd'))!;
    expect(seller.kind, EquipmentSellerKind.typed);
    expect(seller.name, 'Dive Shop Ltd');
  });

  test('no seller and no link reads as none', () {
    expect(resolve(item()), isNull);
    expect(resolve(item(retailer: '   ')), isNull);
  });

  test('an unresolvable link with no snapshot reads as none', () {
    expect(resolve(item(buddy: 'b9')), isNull);
  });
}
