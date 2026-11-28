import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/agent_access/data/writes/families/equipment_item_rules.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';

/// An agent's edit carries the item's seller links through (issue #5140):
/// the edit rebuilds the item whole, and a link left out of that rebuild
/// would be wiped by an unrelated change such as a rename.
void main() {
  test('a rename keeps a buddy seller link', () {
    const current = EquipmentItem(
      id: 'e1',
      name: 'Reg',
      type: EquipmentType.regulator,
      sellerBuddyId: 'b1',
    );
    final next = nextItem(current, {'name': 'Reg 2'});
    expect(next.sellerBuddyId, 'b1');
  });

  test('a notes edit keeps a dive centre seller link', () {
    const current = EquipmentItem(
      id: 'e1',
      name: 'Wing',
      type: EquipmentType.bcd,
      sellerDiveCenterId: 'c1',
    );
    final next = nextItem(current, {'notes': 'New bladder'});
    expect(next.sellerDiveCenterId, 'c1');
  });
}
