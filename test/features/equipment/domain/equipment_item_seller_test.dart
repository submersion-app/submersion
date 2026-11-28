import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/editing/gear_item_edit_fields.dart';

/// The seller links on [EquipmentItem] (issue #5140).
void main() {
  const linked = EquipmentItem(
    id: 'e1',
    name: 'Reg',
    type: EquipmentType.regulator,
    sellerBuddyId: 'b1',
  );

  test('clearSellerLinks drops both links', () {
    final cleared = linked
        .copyWith(sellerDiveCenterId: 'c1')
        .copyWith(clearSellerLinks: true);
    expect(cleared.sellerBuddyId, isNull);
    expect(cleared.sellerDiveCenterId, isNull);
  });

  test('a copy keeps the links it is not told to change', () {
    final renamed = linked.copyWith(name: 'Reg 2');
    expect(renamed.sellerBuddyId, 'b1');
  });

  test('items differing only in a seller link are not equal', () {
    expect(linked, isNot(linked.copyWith(sellerBuddyId: 'b2')));
    expect(
      linked.copyWith(clearSellerLinks: true),
      isNot(linked.copyWith(clearSellerLinks: true, sellerDiveCenterId: 'c1')),
    );
  });

  test('an editor field write keeps the seller links', () {
    // The fields rebuild the item whole; a link left out of that rebuild
    // would vanish on every save from the gear page.
    final written = gearPurchaseDateField.write(linked, DateTime(2025, 3, 12));
    expect(written.sellerBuddyId, 'b1');
    final centre = gearPurchaseDateField.write(
      linked.copyWith(clearSellerLinks: true, sellerDiveCenterId: 'c1'),
      null,
    );
    expect(centre.sellerDiveCenterId, 'c1');
  });
}
