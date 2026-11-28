import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_attribute.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/editing/gear_item_edit_fields.dart';

/// The Seller value a gear item's sitting edits (issue #5140): the links
/// and the `retailer` name move as one.
void main() {
  final typed = EquipmentItem(
    id: 'e1',
    name: 'Reg',
    type: EquipmentType.regulator,
    attributes: [
      EquipmentAttribute.curated(
        equipmentId: 'e1',
        key: 'sku',
        valueText: 'SKU-1',
      ),
      EquipmentAttribute.curated(
        equipmentId: 'e1',
        key: 'retailer',
        valueText: 'Dive Shop Ltd',
      ),
    ],
  );

  test('reads a typed seller', () {
    expect(gearSellerField.read(typed), (
      buddyId: null,
      centerId: null,
      name: 'Dive Shop Ltd',
    ));
  });

  test('picking a buddy writes the link and the name together', () {
    final next = gearSellerField.write(typed, (
      buddyId: 'b1',
      centerId: null,
      name: 'Anna Berg',
    ));
    expect(next.sellerBuddyId, 'b1');
    expect(next.sellerDiveCenterId, isNull);
    expect(next.retailer, 'Anna Berg');
    // The rest of the purchase record stays.
    expect(next.sku, 'SKU-1');
  });

  test('a dive centre replaces a buddy', () {
    final buddy = typed.copyWith(sellerBuddyId: 'b1');
    final next = gearSellerField.write(buddy, (
      buddyId: null,
      centerId: 'c1',
      name: 'Anchor Dive',
    ));
    expect(next.sellerBuddyId, isNull);
    expect(next.sellerDiveCenterId, 'c1');
  });

  test('a blank typed seller removes the name and the links', () {
    final next = gearSellerField.write(typed.copyWith(sellerBuddyId: 'b1'), (
      buddyId: null,
      centerId: null,
      name: '  ',
    ));
    expect(next.sellerBuddyId, isNull);
    expect(next.retailer, isNull);
    expect(next.sku, 'SKU-1');
  });

  test('names differing only in outer spaces are the same seller', () {
    expect(
      gearSellerField.same(
        (buddyId: null, centerId: null, name: 'Anna '),
        (buddyId: null, centerId: null, name: 'Anna'),
      ),
      isTrue,
    );
    expect(
      gearSellerField.same(
        (buddyId: 'b1', centerId: null, name: 'Anna'),
        (buddyId: null, centerId: null, name: 'Anna'),
      ),
      isFalse,
    );
  });
}
