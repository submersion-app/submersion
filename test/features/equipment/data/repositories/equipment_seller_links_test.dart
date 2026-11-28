import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/buddies/data/repositories/buddy_conversion_repository.dart';
import 'package:submersion/features/buddies/data/repositories/buddy_repository.dart';
import 'package:submersion/features/buddies/domain/entities/legacy_buddy_conversion.dart';
import 'package:submersion/features/dive_centers/data/repositories/dive_center_repository.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_seller_links.dart';

import '../../../../helpers/test_database.dart';
import '../../../media/data/repositories/species_photo_fixtures.dart';

/// A gear item keeps its seller's name when the buddy or centre that sold
/// it goes (issue #5140). Each helper and delete path writes the name into
/// `retailer`, clears the link by hand and queues the item, because the
/// schema's SET NULL reaches no peer.
void main() {
  late AppDatabase db;
  const stale = 1000;
  const now = 5000;

  setUp(() async {
    db = await setUpTestDatabase();
    await insertTestDiver('me');
    await insertTestBuddy(id: 'anna', name: 'Anna Berg', diverId: 'me');
    await insertTestBuddy(id: 'sam', name: 'Sam Holm', diverId: 'me');
    await db.customStatement(
      'INSERT INTO dive_centers (id, diver_id, name, created_at, updated_at) '
      "VALUES ('anchor', 'me', 'Anchor Dive', 0, 0)",
    );
  });
  tearDown(tearDownTestDatabase);

  Future<void> insertItem(
    String id, {
    String? buddyId,
    String? centerId,
    String? retailer,
  }) async {
    await db
        .into(db.equipment)
        .insert(
          EquipmentCompanion.insert(
            id: id,
            diverId: const Value('me'),
            name: id,
            type: 'regulator',
            sellerBuddyId: Value(buddyId),
            sellerDiveCenterId: Value(centerId),
            createdAt: stale,
            updatedAt: stale,
          ),
        );
    if (retailer != null) {
      await db
          .into(db.equipmentAttributes)
          .insert(
            EquipmentAttributesCompanion.insert(
              id: 'attr_${id}_retailer',
              equipmentId: id,
              attrKey: 'retailer',
              valueText: Value(retailer),
              createdAt: stale,
              updatedAt: stale,
            ),
          );
    }
  }

  Future<EquipmentData> item(String id) =>
      (db.select(db.equipment)..where((t) => t.id.equals(id))).getSingle();

  Future<String?> retailer(String id) async =>
      (await (db.select(db.equipmentAttributes)..where(
                (t) => t.equipmentId.equals(id) & t.attrKey.equals('retailer'),
              ))
              .getSingleOrNull())
          ?.valueText;

  Future<bool> isPending(String type, String id) async =>
      (await db.select(db.syncRecords).get()).any(
        (r) => r.entityType == type && r.recordId == id,
      );

  /// Unlinked, the seller's [name] kept as typed, and queued for sync.
  Future<void> expectTyped(String id, String name) async {
    final row = await item(id);
    expect(row.sellerBuddyId, isNull);
    expect(row.sellerDiveCenterId, isNull);
    expect(row.updatedAt, greaterThan(stale));
    expect(await retailer(id), name);
    expect(await isPending('equipment', id), isTrue);
    expect(
      await isPending('equipmentAttributes', 'attr_${id}_retailer'),
      isTrue,
    );
  }

  group('clearEquipmentSellerBuddyLinks', () {
    test('writes the buddy\'s current name and drops the link', () async {
      // The snapshot is stale: Anna was renamed since the purchase.
      await insertItem('reg', buddyId: 'anna', retailer: 'Anna');
      await insertItem('wing', buddyId: 'sam', retailer: 'Sam Holm');

      await clearEquipmentSellerBuddyLinks(db, SyncRepository(), [
        'anna',
      ], now: now);

      await expectTyped('reg', 'Anna Berg');
      expect((await item('wing')).sellerBuddyId, 'sam');
      expect(await isPending('equipment', 'wing'), isFalse);
    });

    test('creates the retailer row when the item had none', () async {
      await insertItem('reg', buddyId: 'anna');

      await clearEquipmentSellerBuddyLinks(db, SyncRepository(), [
        'anna',
      ], now: now);

      await expectTyped('reg', 'Anna Berg');
    });

    test('reaches every buddy in a list longer than one chunk', () async {
      final ids = [for (var i = 0; i < 600; i++) 'b$i'];
      for (final id in ids) {
        await insertTestBuddy(id: id, name: 'Buddy $id', diverId: 'me');
      }
      await insertItem('last', buddyId: ids.last);

      await clearEquipmentSellerBuddyLinks(db, SyncRepository(), ids, now: now);

      await expectTyped('last', 'Buddy ${ids.last}');
    });
  });

  test('clearEquipmentSellerCenterLinks writes the centre\'s name', () async {
    await insertItem('reg', centerId: 'anchor', retailer: 'Anchor');

    await clearEquipmentSellerCenterLinks(db, SyncRepository(), [
      'anchor',
    ], now: now);

    await expectTyped('reg', 'Anchor Dive');
  });

  group('repoint and restore', () {
    test('repoint moves the link and names the survivor', () async {
      await insertItem('reg', buddyId: 'sam', retailer: 'Sam');

      final previous = await repointEquipmentSellerBuddyLinks(
        db,
        SyncRepository(),
        fromBuddyIds: ['sam'],
        toBuddyId: 'anna',
        now: now,
      );

      expect((await item('reg')).sellerBuddyId, 'anna');
      expect(await retailer('reg'), 'Anna Berg');
      expect(await isPending('equipment', 'reg'), isTrue);
      expect(previous, {'reg': (buddyId: 'sam', retailer: 'Sam')});
    });

    test('restore puts the link and the old name back', () async {
      await insertItem('reg', buddyId: 'anna', retailer: 'Anna Berg');

      await restoreEquipmentSellerBuddyLinks(db, SyncRepository(), {
        'reg': (buddyId: 'sam', retailer: 'Sam'),
      }, now: now);

      expect((await item('reg')).sellerBuddyId, 'sam');
      expect(await retailer('reg'), 'Sam');
    });

    test('restore removes a name the item did not have', () async {
      await insertItem('reg', buddyId: 'anna', retailer: 'Anna Berg');

      await restoreEquipmentSellerBuddyLinks(db, SyncRepository(), {
        'reg': (buddyId: 'sam', retailer: null),
      }, now: now);

      expect(await retailer('reg'), isNull);
    });
  });

  group('delete paths keep the seller', () {
    test('deleteBuddy', () async {
      await insertItem('reg', buddyId: 'anna', retailer: 'Anna');
      await BuddyRepository().deleteBuddy('anna');
      await expectTyped('reg', 'Anna Berg');
    });

    test('bulkDeleteBuddies', () async {
      await insertItem('reg', buddyId: 'anna');
      await insertItem('wing', buddyId: 'sam');
      await BuddyRepository().bulkDeleteBuddies(['anna', 'sam']);
      await expectTyped('reg', 'Anna Berg');
      await expectTyped('wing', 'Sam Holm');
    });

    test('undoing a legacy buddy conversion', () async {
      await insertItem('reg', buddyId: 'anna');
      await BuddyConversionRepository().undo(
        const ConversionReceipt(diverId: 'me', createdBuddyIds: ['anna']),
      );
      await expectTyped('reg', 'Anna Berg');
    });

    test('deleteDiver: another profile\'s gear keeps the name', () async {
      // Anna and Anchor belong to "me"; the gear is "you"'s.
      await insertTestDiver('you');
      await insertItem('reg', buddyId: 'anna');
      await insertItem('wing', centerId: 'anchor');
      await db.customStatement(
        "UPDATE equipment SET diver_id = 'you' WHERE id IN ('reg', 'wing')",
      );

      await DiverRepository().deleteDiver('me');

      await expectTyped('reg', 'Anna Berg');
      await expectTyped('wing', 'Anchor Dive');
    });

    test('deleteDiveCenter', () async {
      await insertItem('reg', centerId: 'anchor');
      await DiveCenterRepository().deleteDiveCenter('anchor');
      await expectTyped('reg', 'Anchor Dive');
    });
  });

  group('buddy merge', () {
    Future<BuddyMergeResult> merge() async {
      final repo = BuddyRepository();
      final survivor = (await repo.getBuddyById('anna'))!;
      return (await repo.mergeBuddies(
        mergedBuddy: survivor,
        buddyIds: ['anna', 'sam'],
      ))!;
    }

    test('moves the seller to the survivor', () async {
      await insertItem('reg', buddyId: 'sam', retailer: 'Sam Holm');
      await merge();
      expect((await item('reg')).sellerBuddyId, 'anna');
      expect(await retailer('reg'), 'Anna Berg');
    });

    test('undo puts the seller back', () async {
      await insertItem('reg', buddyId: 'sam', retailer: 'Sam Holm');
      final result = await merge();

      await BuddyRepository().undoMerge(result.snapshot!);

      expect((await item('reg')).sellerBuddyId, 'sam');
      expect(await retailer('reg'), 'Sam Holm');
    });
  });
}
