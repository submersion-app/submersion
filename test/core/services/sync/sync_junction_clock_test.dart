import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/core/services/sync/sync_service.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';

import '../../../helpers/changeset_test_helpers.dart';
import '../../../helpers/fake_cloud_storage_provider.dart';
import '../../../helpers/mock_providers.dart';
import '../../../helpers/test_database.dart';

/// Regression tests for issue #1728.
///
/// The composite-natural-key gear junctions carried no clock, which broke the
/// merge in two directions at once:
///
///  * `_applyRemoteDeletions` derives both of its guards from
///    `localUpdatedAt`, each written as `localUpdatedAt != null && ...`, so a
///    null collapsed both to false and an uncontradicted remote tombstone
///    applied unconditionally.
///  * `_mergeEntity`'s local-tombstone branch computed `remoteUpdatedAt` as
///    `hasUpdatedAt ? ... : null` and bailed on null, so the revival path was
///    unreachable for a clockless entity. A link lost anywhere was permanent.
///
/// These use tombstones with NO matching live row in the same payload, which
/// is what defeats the same-payload contradiction check that #347 added.
void main() {
  group('Gear junctions carry a clock (issue #1728)', () {
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

    test('a link edited after the tombstone survives it', () async {
      final serializer = SyncDataSerializer();
      final diveRepo = DiveRepository();
      final db = DatabaseService.instance.database;

      await serializer.upsertRecord(
        'equipment',
        equipmentRow('gear-1', 'Wing', 'bcd'),
      );
      await diveRepo.createDive(
        createTestDiveWithBottomTime(id: 'dive-1', diveNumber: 1),
      );
      // This device re-attached the gear at 6000, AFTER the peer deleted it.
      await serializer.upsertRecord('diveEquipment', {
        'diveId': 'dive-1',
        'equipmentId': 'gear-1',
        'updatedAt': 6000,
      });

      final payload = payloadOf(const SyncData(), {
        'diveEquipment': [
          const SyncDeletion(id: 'dive-1|gear-1', deletedAt: 5000),
        ],
      });
      await seedPeerBaseFromPayload(cloud, 'peer-dev', payload);

      final result = await buildService().performSync();
      expect(result.status, isNot(SyncResultStatus.error));

      final links = await (db.select(
        db.diveEquipment,
      )..where((t) => t.diveId.equals('dive-1'))).get();
      expect(
        links.map((l) => l.equipmentId),
        contains('gear-1'),
        reason:
            'the local link is newer than the tombstone, so the age guard '
            'must route it to a conflict rather than delete it',
      );
      expect(result.conflictsFound, greaterThan(0));
    });

    test('a lost link is revived by a newer live copy from a peer', () async {
      final serializer = SyncDataSerializer();
      final diveRepo = DiveRepository();
      final db = DatabaseService.instance.database;

      await serializer.upsertRecord(
        'equipment',
        equipmentRow('gear-2', 'Regulator', 'regulator'),
      );
      await diveRepo.createDive(
        createTestDiveWithBottomTime(id: 'dive-2', diveNumber: 2),
      );
      // This device already lost the link and holds the tombstone.
      await SyncRepository().logDeletion(
        entityType: 'diveEquipment',
        recordId: 'dive-2|gear-2',
        deletedAt: 4000,
      );

      // A peer that never lost it publishes the live row, and nothing in the
      // payload contradicts our tombstone.
      final payload = payloadOf(
        const SyncData(
          diveEquipment: [
            {'diveId': 'dive-2', 'equipmentId': 'gear-2', 'updatedAt': 5000},
          ],
        ),
        const {},
      );
      await seedPeerBaseFromPayload(cloud, 'peer-dev', payload);

      final result = await buildService().performSync();
      expect(result.status, isNot(SyncResultStatus.error));

      final links = await (db.select(
        db.diveEquipment,
      )..where((t) => t.diveId.equals('dive-2'))).get();
      expect(
        links.map((l) => l.equipmentId),
        contains('gear-2'),
        reason:
            'a live copy newer than the local tombstone must revive the '
            'link, otherwise a single lost link is permanent',
      );
    });

    test('a genuine deletion of an older link still applies', () async {
      final serializer = SyncDataSerializer();
      final diveRepo = DiveRepository();
      final db = DatabaseService.instance.database;

      await serializer.upsertRecord(
        'equipment',
        equipmentRow('gear-3', 'Fins', 'fins'),
      );
      await diveRepo.createDive(
        createTestDiveWithBottomTime(id: 'dive-3', diveNumber: 3),
      );
      await serializer.upsertRecord('diveEquipment', {
        'diveId': 'dive-3',
        'equipmentId': 'gear-3',
        'updatedAt': 3000,
      });

      final payload = payloadOf(const SyncData(), {
        'diveEquipment': [
          const SyncDeletion(id: 'dive-3|gear-3', deletedAt: 5000),
        ],
      });
      await seedPeerBaseFromPayload(cloud, 'peer-dev', payload);

      final result = await buildService().performSync();
      expect(result.status, isNot(SyncResultStatus.error));

      final links = await (db.select(
        db.diveEquipment,
      )..where((t) => t.diveId.equals('dive-3'))).get();
      expect(
        links,
        isEmpty,
        reason:
            'the guard must not turn every removal into a conflict: a '
            'link older than the tombstone is still deleted',
      );
    });

    test('a pre-v207 peer cannot null out a clock we already hold', () async {
      // Rollout hazard: a peer on an older build sends these rows with no
      // updatedAt at all. Drift's insert drops the absent field, so the
      // column's clientDefault fires and a plain upsert overwrites the stamp
      // this device holds with `now`. Every base import from an old peer
      // would then make every gear link look freshly edited, flipping the age
      // guard so legitimate removals pile up as conflicts.
      final serializer = SyncDataSerializer();
      final diveRepo = DiveRepository();
      final db = DatabaseService.instance.database;

      await serializer.upsertRecord(
        'equipment',
        equipmentRow('gear-5', 'Torch', 'light'),
      );
      await diveRepo.createDive(
        createTestDiveWithBottomTime(id: 'dive-5', diveNumber: 5),
      );
      await serializer.upsertRecord('diveEquipment', {
        'diveId': 'dive-5',
        'equipmentId': 'gear-5',
        'updatedAt': 8000,
      });

      // Exactly what an older build puts on the wire: the key and nothing else.
      await serializer.upsertRecord('diveEquipment', {
        'diveId': 'dive-5',
        'equipmentId': 'gear-5',
      });

      final row = await (db.select(
        db.diveEquipment,
      )..where((t) => t.diveId.equals('dive-5'))).getSingle();
      expect(
        row.updatedAt,
        8000,
        reason: 'a wire row with no clock must leave the local one standing',
      );
    });

    test(
      'a clockless dive-plan row keeps our clock but still clears provenance',
      () async {
        // The dive-plan twin of the test above, and the case the upsert's doc
        // comment distinguishes: an old peer's row must leave the local clock
        // standing, yet an explicit null provenance pointer (a peer that
        // deleted the assembly) must still be applied, not dropped.
        final serializer = SyncDataSerializer();
        final db = DatabaseService.instance.database;

        await serializer.upsertRecord(
          'equipment',
          equipmentRow('gear-6', 'Regulator', 'regulator'),
        );
        await serializer.upsertRecord(
          'equipment',
          equipmentRow('rig-6', 'Travel rig', 'regulator'),
        );
        await db
            .into(db.divePlans)
            .insert(
              DivePlansCompanion.insert(
                id: 'plan-6',
                name: 'Reef 18 m',
                gfLow: 50,
                gfHigh: 80,
                createdAt: 1000,
                updatedAt: 1000,
              ),
            );
        await serializer.upsertRecord('divePlanEquipment', {
          'planId': 'plan-6',
          'equipmentId': 'gear-6',
          'viaEquipmentId': 'rig-6',
          'updatedAt': 8000,
        });

        await serializer.upsertRecord('divePlanEquipment', {
          'planId': 'plan-6',
          'equipmentId': 'gear-6',
          'viaEquipmentId': null,
        });

        final row = await (db.select(
          db.divePlanEquipment,
        )..where((t) => t.planId.equals('plan-6'))).getSingle();
        expect(row.updatedAt, 8000, reason: 'the wire carried no clock');
        expect(
          row.viaEquipmentId,
          isNull,
          reason: 'an explicit null provenance pointer is a deliberate clear',
        );
      },
    );

    test('an incremental changeset carries the set-item clock', () async {
      // _exportEquipmentSetItems used to hand-build {setId, equipmentId}, so
      // the clock never left the device and every receiver's age guard saw
      // null again. The incremental path (a watermark, a changed set) is the
      // one ordinary syncs take.
      final serializer = SyncDataSerializer();

      await serializer.upsertRecord(
        'equipment',
        equipmentRow('gear-7', 'Hood', 'hood'),
      );
      await serializer.upsertRecord('equipmentSets', {
        'id': 'set-7',
        'name': 'Cold water',
        'description': '',
        'isDefault': false,
        'createdAt': 1000,
        'updatedAt': 1000,
        'hlc': '0002-changed-hlc',
      });
      await serializer.upsertRecord('equipmentSetItems', {
        'setId': 'set-7',
        'equipmentId': 'gear-7',
        'updatedAt': 7000,
      });

      final payload = await serializer.exportChangeset(
        deviceId: 'this-dev',
        hlcWatermark: '0001-older-hlc',
        deletions: const [],
      );

      expect(payload.data.equipmentSetItems, [containsPair('updatedAt', 7000)]);
    });

    test('a dive-plan gear row merges instead of failing', () async {
      final serializer = SyncDataSerializer();
      final db = DatabaseService.instance.database;

      await serializer.upsertRecord(
        'equipment',
        equipmentRow('gear-4', 'Mask', 'mask'),
      );
      await db
          .into(db.divePlans)
          .insert(
            DivePlansCompanion.insert(
              id: 'plan-1',
              name: 'Wreck 60 m',
              gfLow: 50,
              gfHigh: 80,
              createdAt: 1000,
              updatedAt: 1000,
              hlc: const Value('0001-test-hlc'),
            ),
          );

      final payload = payloadOf(
        const SyncData(
          divePlanEquipment: [
            {'planId': 'plan-1', 'equipmentId': 'gear-4', 'updatedAt': 5000},
          ],
        ),
        const {},
      );
      await seedPeerBaseFromPayload(cloud, 'peer-dev', payload);

      final result = await buildService().performSync();
      expect(result.status, isNot(SyncResultStatus.error));

      final links = await (db.select(
        db.divePlanEquipment,
      )..where((t) => t.planId.equals('plan-1'))).get();
      expect(
        links.map((l) => l.equipmentId),
        contains('gear-4'),
        reason:
            '_recordIdForEntity had no divePlanEquipment case, so every '
            'incoming dive-plan gear row resolved to a null id and was '
            'counted as malformed instead of applied',
      );
    });
  });
}
