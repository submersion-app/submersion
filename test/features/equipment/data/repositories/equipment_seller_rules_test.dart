import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_seller_rules.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_attribute.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';

import '../../../../helpers/test_database.dart';

/// The seller rules every save goes through (issue #5140): at most one
/// link, and a retailer changed by anything but the Seller field turns the
/// item into a typed seller.
void main() {
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
    // Renamed since the item was linked: the snapshot still says "Anna".
    await db.customStatement(
      'INSERT INTO buddies (id, name, created_at, updated_at) '
      "VALUES ('b1', 'Anna B.', 0, 0)",
    );
    await db.customStatement(
      'INSERT INTO dive_centers (id, name, created_at, updated_at) '
      "VALUES ('c1', 'Anchor Dive', 0, 0)",
    );
  });
  tearDown(tearDownTestDatabase);

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

  test('an item with both links is refused', () async {
    await expectLater(
      applySellerRules(
        db,
        stored: null,
        next: item(buddy: 'b1', centre: 'c1'),
      ),
      throwsArgumentError,
    );
  });

  test('a retailer edited elsewhere drops the links', () async {
    final next = await applySellerRules(
      db,
      stored: item(retailer: 'Anna', buddy: 'b1'),
      next: item(retailer: 'Lars Holm', buddy: 'b1'),
    );
    expect(next.sellerBuddyId, isNull);
    expect(next.retailer, 'Lars Holm');
  });

  test('re-picking a renamed buddy keeps the link', () async {
    final next = await applySellerRules(
      db,
      stored: item(retailer: 'Anna', buddy: 'b1'),
      next: item(retailer: 'Anna B.', buddy: 'b1'),
    );
    expect(next.sellerBuddyId, 'b1');
  });

  test('a renamed centre picked again keeps its link', () async {
    final next = await applySellerRules(
      db,
      stored: item(retailer: 'Anchor', centre: 'c1'),
      next: item(retailer: 'Anchor Dive', centre: 'c1'),
    );
    expect(next.sellerDiveCenterId, 'c1');
  });

  test('an unchanged retailer keeps the links', () async {
    final next = await applySellerRules(
      db,
      stored: item(retailer: 'Anna', buddy: 'b1'),
      next: item(retailer: 'Anna', buddy: 'b1').copyWith(name: 'Reg 2'),
    );
    expect(next.sellerBuddyId, 'b1');
  });

  test('a new link keeps whatever name came with it', () async {
    final next = await applySellerRules(
      db,
      stored: item(retailer: 'Shop'),
      next: item(retailer: 'Anchor Dive', centre: 'c1'),
    );
    expect(next.sellerDiveCenterId, 'c1');
  });

  test('the repository applies the rules on update', () async {
    await db.customStatement(
      'INSERT INTO equipment (id, name, type, seller_buddy_id, created_at, '
      "updated_at) VALUES ('e1', 'Reg', 'regulator', 'b1', 0, 0)",
    );
    final repo = EquipmentRepository();
    await repo.saveAttributes('e1', item(retailer: 'Anna').attributes);

    await repo.updateEquipment(item(retailer: 'Lars Holm', buddy: 'b1'));

    final read = await repo.getEquipmentById('e1');
    expect(read!.sellerBuddyId, isNull);
    expect(read.retailer, 'Lars Holm');
  });

  test('the repository refuses both links on create', () async {
    await expectLater(
      EquipmentRepository().createEquipment(
        item(buddy: 'b1', centre: 'c1').copyWith(id: ''),
      ),
      throwsArgumentError,
    );
  });
}
