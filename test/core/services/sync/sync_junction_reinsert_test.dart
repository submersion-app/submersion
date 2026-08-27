import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/core/services/sync/sync_service.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';

import '../../../helpers/changeset_test_helpers.dart';
import '../../../helpers/fake_cloud_storage_provider.dart';
import '../../../helpers/mock_providers.dart';
import '../../../helpers/test_database.dart';

/// Regression tests for issue #347 ("iCloud Syncing Equipment Sets").
///
/// Composite-natural-key junction tables (equipment_set_items keyed by
/// `setId|equipmentId`, dive_equipment keyed by `diveId|equipmentId`) are
/// rebuilt by their repositories with a "delete all rows for the parent,
/// log a tombstone for each, then re-insert" idiom. A single sync payload
/// therefore carries the membership row as LIVE *and* a tombstone for the
/// exact same key.
///
/// These rows carry no per-row clock (no updatedAt / hlc), so the merge's
/// local-deletion guard compares a null remote timestamp against the
/// tombstone's deletedAt and the deletion always wins -- silently dropping
/// the membership on every other device. The set's name/description survive
/// because the parent row is only ever updated, never delete-logged.
///
/// The fix: a tombstone whose key is also present as a LIVE row in the same
/// payload is a stale artifact; the live row is the source's current truth.
void main() {
  group('Same-payload junction reinsert (issue #347)', () {
    late FakeCloudStorageProvider cloud;

    setUp(() async {
      await setUpTestDatabase();
      cloud = FakeCloudStorageProvider();
    });

    tearDown(() async {
      await tearDownTestDatabase();
    });

    SyncService buildService() => SyncService(
      syncRepository: SyncRepository(),
      serializer: SyncDataSerializer(),
      cloudProvider: cloud,
    );

    // A complete equipment row: Drift's fromJson casts every non-nullable
    // column, so DB defaults (status, currency, notes, isActive) must be
    // present in the JSON even though the table declares defaults for them.
    Map<String, dynamic> equipmentRow(String id, String name, String type) => {
      'id': id,
      'name': name,
      'type': type,
      'status': 'active',
      'purchaseCurrency': 'USD',
      'notes': '',
      'isActive': true,
      'createdAt': 1000,
      'updatedAt': 1000,
    };

    SyncPayload payloadOf(SyncData data, Map<String, List<SyncDeletion>> dels) {
      final checksum = sha256
          .convert(utf8.encode(jsonEncode(data.toJson())))
          .toString();
      return SyncPayload(
        version: syncFormatVersion,
        exportedAt: 9000,
        deviceId: 'peer-dev',
        checksum: checksum,
        data: data,
        deletions: dels,
      );
    }

    test(
      'equipment-set membership survives a same-payload tombstone',
      () async {
        final serializer = SyncDataSerializer();
        final db = DatabaseService.instance.database;

        // Parents already exist on this device (synced earlier).
        await serializer.upsertRecord(
          'equipment',
          equipmentRow('gear-1', 'Wetsuit', 'wetsuit'),
        );
        await serializer.upsertRecord('equipmentSets', {
          'id': 'set-1',
          'name': 'Warm Weather',
          'description': 'six items',
          'isDefault': false,
          'createdAt': 1000,
          'updatedAt': 1000,
        });

        // Peer's changeset: the membership row is live AND tombstoned (the
        // delete-all+reinsert signature of EquipmentSetRepository.updateSet).
        final payload = payloadOf(
          const SyncData(
            equipmentSetItems: [
              {'setId': 'set-1', 'equipmentId': 'gear-1'},
            ],
          ),
          {
            'equipmentSetItems': [
              const SyncDeletion(id: 'set-1|gear-1', deletedAt: 5000),
            ],
          },
        );
        await seedPeerBaseFromPayload(cloud, 'peer-dev', payload);

        final result = await buildService().performSync();
        expect(result.status, isNot(SyncResultStatus.error));

        final items = await (db.select(
          db.equipmentSetItems,
        )..where((t) => t.setId.equals('set-1'))).get();
        expect(
          items.map((i) => i.equipmentId),
          contains('gear-1'),
          reason:
              'the set must keep its gear: the live row in the same payload is '
              'authoritative over a stale reinsert tombstone',
        );
      },
    );

    test(
      'dive-equipment membership survives a same-payload tombstone',
      () async {
        final serializer = SyncDataSerializer();
        final diveRepo = DiveRepository();
        final db = DatabaseService.instance.database;

        await serializer.upsertRecord(
          'equipment',
          equipmentRow('gear-2', 'Regulator', 'regulator'),
        );
        await diveRepo.createDive(
          createTestDiveWithBottomTime(id: 'dive-1', diveNumber: 1),
        );

        final payload = payloadOf(
          const SyncData(
            diveEquipment: [
              {'diveId': 'dive-1', 'equipmentId': 'gear-2'},
            ],
          ),
          {
            'diveEquipment': [
              const SyncDeletion(id: 'dive-1|gear-2', deletedAt: 5000),
            ],
          },
        );
        await seedPeerBaseFromPayload(cloud, 'peer-dev', payload);

        final result = await buildService().performSync();
        expect(result.status, isNot(SyncResultStatus.error));

        final links = await (db.select(
          db.diveEquipment,
        )..where((t) => t.diveId.equals('dive-1'))).get();
        expect(
          links.map((l) => l.equipmentId),
          contains('gear-2'),
          reason: 'editing a dive must not drop its gear on the peer',
        );
      },
    );

    test('a genuine deletion (no live row in payload) still applies', () async {
      final serializer = SyncDataSerializer();
      final db = DatabaseService.instance.database;

      await serializer.upsertRecord(
        'equipment',
        equipmentRow('gear-3', 'Fins', 'fins'),
      );
      await serializer.upsertRecord('equipmentSets', {
        'id': 'set-2',
        'name': 'Cold Weather',
        'description': '',
        'isDefault': false,
        'createdAt': 1000,
        'updatedAt': 1000,
      });
      // The membership currently exists locally.
      await serializer.upsertRecord('equipmentSetItems', {
        'setId': 'set-2',
        'equipmentId': 'gear-3',
      });

      // Peer removed the item: a tombstone with NO matching live row.
      final payload = payloadOf(const SyncData(), {
        'equipmentSetItems': [
          const SyncDeletion(id: 'set-2|gear-3', deletedAt: 5000),
        ],
      });
      await seedPeerBaseFromPayload(cloud, 'peer-dev', payload);

      final result = await buildService().performSync();
      expect(result.status, isNot(SyncResultStatus.error));

      final items = await (db.select(
        db.equipmentSetItems,
      )..where((t) => t.setId.equals('set-2'))).get();
      expect(
        items,
        isEmpty,
        reason:
            'a real removal (tombstone without a live row) must still apply',
      );
    });

    test('an already-dropped item is healed when re-published live', () async {
      final serializer = SyncDataSerializer();
      final db = DatabaseService.instance.database;

      // This device previously applied the buggy delete and dropped the item,
      // leaving behind a local tombstone for it.
      await serializer.upsertRecord(
        'equipment',
        equipmentRow('gear-4', 'Mask', 'mask'),
      );
      await serializer.upsertRecord('equipmentSets', {
        'id': 'set-3',
        'name': 'Travel',
        'description': '',
        'isDefault': false,
        'createdAt': 1000,
        'updatedAt': 1000,
      });
      await SyncRepository().logDeletion(
        entityType: 'equipmentSetItems',
        recordId: 'set-3|gear-4',
        deletedAt: 4000,
      );

      // The good device re-publishes the set (live row + reinsert tombstone).
      final payload = payloadOf(
        const SyncData(
          equipmentSetItems: [
            {'setId': 'set-3', 'equipmentId': 'gear-4'},
          ],
        ),
        {
          'equipmentSetItems': [
            const SyncDeletion(id: 'set-3|gear-4', deletedAt: 5000),
          ],
        },
      );
      await seedPeerBaseFromPayload(cloud, 'peer-dev', payload);

      final result = await buildService().performSync();
      expect(result.status, isNot(SyncResultStatus.error));

      final items = await (db.select(
        db.equipmentSetItems,
      )..where((t) => t.setId.equals('set-3'))).get();
      expect(
        items.map((i) => i.equipmentId),
        contains('gear-4'),
        reason:
            'a stale local tombstone must not block a live row the same payload '
            're-inserts: the corrupted device self-heals',
      );
    });

    test(
      'a set edit keeps survivors and removes one in the same payload',
      () async {
        final serializer = SyncDataSerializer();
        final db = DatabaseService.instance.database;

        await serializer.upsertRecord(
          'equipment',
          equipmentRow('g-a', 'A', 'mask'),
        );
        await serializer.upsertRecord(
          'equipment',
          equipmentRow('g-b', 'B', 'fins'),
        );
        await serializer.upsertRecord(
          'equipment',
          equipmentRow('g-c', 'C', 'bcd'),
        );
        await serializer.upsertRecord('equipmentSets', {
          'id': 'set-4',
          'name': 'Mixed',
          'description': '',
          'isDefault': false,
          'createdAt': 1000,
          'updatedAt': 1000,
        });
        // C is currently a member locally and is being removed by the edit.
        await serializer.upsertRecord('equipmentSetItems', {
          'setId': 'set-4',
          'equipmentId': 'g-c',
        });

        // updateSet on the peer keeps A and B (live + reinsert tombstone) and
        // drops C (tombstone only, no live row) -- one payload that is
        // contradicted for some keys and a genuine delete for another.
        final payload = payloadOf(
          const SyncData(
            equipmentSetItems: [
              {'setId': 'set-4', 'equipmentId': 'g-a'},
              {'setId': 'set-4', 'equipmentId': 'g-b'},
            ],
          ),
          {
            'equipmentSetItems': [
              const SyncDeletion(id: 'set-4|g-a', deletedAt: 5000),
              const SyncDeletion(id: 'set-4|g-b', deletedAt: 5000),
              const SyncDeletion(id: 'set-4|g-c', deletedAt: 5000),
            ],
          },
        );
        await seedPeerBaseFromPayload(cloud, 'peer-dev', payload);

        final result = await buildService().performSync();
        expect(result.status, isNot(SyncResultStatus.error));

        final ids =
            (await (db.select(
                  db.equipmentSetItems,
                )..where((t) => t.setId.equals('set-4'))).get())
                .map((i) => i.equipmentId)
                .toSet();
        expect(
          ids,
          {'g-a', 'g-b'},
          reason:
              'survivors (live + same-payload tombstone) are kept; the genuinely '
              'removed item (tombstone with no live row) is deleted',
        );
      },
    );
  });
}
