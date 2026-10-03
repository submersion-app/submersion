import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_share_repository.dart';
import 'package:submersion/features/equipment/data/services/equipment_transfer_service.dart';

import '../../../helpers/test_database.dart';

/// A transfer and a kept-gear handover reach a peer (issue #2852). Device A
/// makes the change; its pending rows and tombstones are then applied to a
/// fresh database holding the state before the change, as device B, through
/// the serializer's apply paths in a deferred-FK transaction, in both orders.
void main() {
  late AppDatabase db;

  setUp(() async => db = await setUpTestDatabase());
  tearDown(tearDownTestDatabase);

  /// Both devices start here: Bill owns `light`, shared with Anna and Tom,
  /// and Tom's dive uses it.
  Future<void> seed() async {
    const t = 1000;
    for (final id in ['bill', 'anna', 'tom']) {
      await db
          .into(db.divers)
          .insert(
            DiversCompanion.insert(
              id: id,
              name: id,
              createdAt: t,
              updatedAt: t,
              isDefault: Value(id == 'anna'),
            ),
          );
    }
    await db
        .into(db.equipment)
        .insert(
          EquipmentCompanion.insert(
            id: 'light',
            name: 'light',
            type: 'light',
            createdAt: t,
            updatedAt: t,
            diverId: const Value('bill'),
          ),
        );
    await db
        .into(db.equipmentShares)
        .insert(
          EquipmentSharesCompanion.insert(
            id: 'share-anna',
            equipmentId: 'light',
            diverId: 'anna',
            createdAt: 1,
          ),
        );
    await db
        .into(db.equipmentShares)
        .insert(
          EquipmentSharesCompanion.insert(
            id: 'share-tom',
            equipmentId: 'light',
            diverId: 'tom',
            createdAt: 2,
          ),
        );
    await db
        .into(db.dives)
        .insert(
          DivesCompanion.insert(
            id: 'tom-dive',
            diverId: const Value('tom'),
            diveDateTime: t,
            createdAt: t,
            updatedAt: t,
          ),
        );
    await db
        .into(db.diveEquipment)
        .insert(
          DiveEquipmentCompanion.insert(
            diveId: 'tom-dive',
            equipmentId: 'light',
          ),
        );
  }

  /// Device A's outbound change: every pending record's JSON and every
  /// tombstone, entity types the serializer handles only.
  Future<
    ({
      List<(String, Map<String, dynamic>)> upserts,
      List<(String, String)> deletions,
    })
  >
  outbound() async {
    final serializer = SyncDataSerializer();
    final upserts = <(String, Map<String, dynamic>)>[];
    for (final r
        in await db
            .customSelect('SELECT entity_type, record_id FROM sync_records')
            .get()) {
      final type = r.read<String>('entity_type');
      final json = await serializer.fetchRecord(
        type,
        r.read<String>('record_id'),
      );
      if (json != null) upserts.add((type, json));
    }
    final deletions = [
      for (final r in await db.select(db.deletionLog).get())
        (r.entityType, r.recordId),
    ];
    return (upserts: upserts, deletions: deletions);
  }

  /// Resets to a fresh device B in the seeded state and applies [change].
  Future<void> applyOnPeer(
    ({
      List<(String, Map<String, dynamic>)> upserts,
      List<(String, String)> deletions,
    })
    change, {
    required bool deletionsFirst,
  }) async {
    await tearDownTestDatabase();
    db = await setUpTestDatabase();
    await seed();
    final serializer = SyncDataSerializer();
    Future<void> upsertAll() async {
      for (final (type, json) in change.upserts) {
        await serializer.upsertRecord(type, json);
      }
    }

    Future<void> deleteAll() async {
      for (final (type, id) in change.deletions) {
        await serializer.deleteRecord(type, id);
      }
    }

    await serializer.applyInDeferredFkTransaction(() async {
      if (deletionsFirst) {
        await deleteAll();
        await upsertAll();
      } else {
        await upsertAll();
        await deleteAll();
      }
      await serializer.repairDanglingForeignKeys();
    });
  }

  Future<String?> ownerOfLight() async => (await (db.select(
    db.equipment,
  )..where((t) => t.id.equals('light'))).getSingleOrNull())?.diverId;

  for (final deletionsFirst in [false, true]) {
    final order = deletionsFirst ? 'tombstones first' : 'upserts first';

    test(
      'a transfer with kept access converges on the peer ($order)',
      () async {
        await seed();
        await EquipmentTransferService().transfer(
          equipmentIds: ['light'],
          toDiverId: 'anna',
          actingDiverId: 'bill',
        );
        final change = await outbound();
        await applyOnPeer(change, deletionsFirst: deletionsFirst);

        expect(await ownerOfLight(), 'anna');
        final shares = await db.select(db.equipmentShares).get();
        expect({for (final s in shares) s.diverId}, {'bill', 'tom'});
        final transferred = await (db.select(
          db.equipmentOwnershipEvents,
        )..where((e) => e.kind.equals('transferred'))).get();
        expect(transferred, hasLength(1));
        expect(transferred.single.fromDiverId, 'bill');
        expect(transferred.single.toDiverId, 'anna');
        expect(await db.select(db.diveEquipment).get(), hasLength(1));
      },
    );

    test('a kept-gear handover converges on the peer ($order)', () async {
      await seed();
      await DiverRepository().deleteDiverWithReassignment('bill');
      final change = await outbound();
      await applyOnPeer(change, deletionsFirst: deletionsFirst);

      expect(await ownerOfLight(), 'anna');
      expect(
        await (db.select(
          db.divers,
        )..where((d) => d.id.equals('bill'))).getSingleOrNull(),
        isNull,
      );
      final shares = await db.select(db.equipmentShares).get();
      expect({for (final s in shares) s.diverId}, {'tom'});
      final transferred = await (db.select(
        db.equipmentOwnershipEvents,
      )..where((e) => e.kind.equals('transferred'))).getSingle();
      expect(transferred.fromDiverId, isNull);
      expect(transferred.toDiverId, 'anna');
      expect(
        await db.select(db.diveEquipment).get(),
        hasLength(1),
        reason: "Tom's dive keeps the handed-over light on the peer",
      );
    });
  }

  test('the share repository entity names are what the peer applies', () {
    expect(EquipmentShareRepository.sharesEntity, 'equipmentShares');
    expect(EquipmentShareRepository.eventsEntity, 'equipmentOwnershipEvents');
  });
}
