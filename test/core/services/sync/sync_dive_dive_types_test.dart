import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/core/services/sync/sync_service.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;

import '../../../helpers/changeset_test_helpers.dart';
import '../../../helpers/fake_cloud_storage_provider.dart';
import '../../../helpers/test_database.dart';

/// Sync replication for the `dive_dive_types` junction (issue #414).
///
/// Unlike the composite-key junctions of issue #347, this table uses a
/// surrogate UUID primary key, so a reinserted row never collides with the
/// tombstone of the row it replaced — it is structurally immune to that bug.
/// These tests therefore verify the two directions that matter: a peer's row
/// replicates (add) and a peer's tombstone removes a row (delete).
void main() {
  group('dive_dive_types sync (#414)', () {
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

    Map<String, dynamic> ddtRow(String id, String diveId, String typeId) => {
      'id': id,
      'diveId': diveId,
      'diveTypeId': typeId,
      'createdAt': 1000,
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

    test('a peer-published dive-type row replicates via sync', () async {
      final diveRepo = DiveRepository();
      final db = DatabaseService.instance.database;

      await diveRepo.createDive(
        domain.Dive(
          id: 'dive-1',
          dateTime: DateTime(2026, 1, 1),
          diveTypeIds: const ['shore'],
        ),
      );

      final payload = payloadOf(
        SyncData(diveDiveTypes: [ddtRow('ddt-wreck', 'dive-1', 'wreck')]),
        const {},
      );
      await seedPeerBaseFromPayload(cloud, 'peer-dev', payload);

      final result = await buildService().performSync();
      expect(result.status, isNot(SyncResultStatus.error));

      final ids =
          (await (db.select(
                db.diveDiveTypes,
              )..where((t) => t.diveId.equals('dive-1'))).get())
              .map((r) => r.diveTypeId)
              .toSet();
      expect(
        ids,
        contains('wreck'),
        reason: 'a peer-published dive-type row must replicate to this device',
      );
    });

    // A reorder renumbers created_at on the rows it keeps, under their
    // existing ids (issue #4477), so the peer's copy hits the primary key.
    // The apply must take the new order rather than drop the row.
    Future<List<String>> typesInOrder(String diveId) async {
      final db = DatabaseService.instance.database;
      final rows =
          await (db.select(db.diveDiveTypes)
                ..where((t) => t.diveId.equals(diveId))
                ..orderBy([
                  (t) => OrderingTerm(expression: t.createdAt),
                  (t) => OrderingTerm(expression: t.id),
                ]))
              .get();
      return [for (final r in rows) r.diveTypeId];
    }

    Future<void> seedTwoTypes(SyncDataSerializer serializer) async {
      await DiveRepository().createDive(
        domain.Dive(
          id: 'dive-1',
          dateTime: DateTime(2026, 1, 1),
          diveTypeIds: const ['shore'],
        ),
      );
      final db = DatabaseService.instance.database;
      await (db.delete(
        db.diveDiveTypes,
      )..where((t) => t.diveId.equals('dive-1'))).go();
      await serializer.upsertRecord('diveDiveTypes', {
        ...ddtRow('ddt-a', 'dive-1', 'shore'),
        'createdAt': 1000,
      });
      await serializer.upsertRecord('diveDiveTypes', {
        ...ddtRow('ddt-b', 'dive-1', 'wreck'),
        'createdAt': 1001,
      });
    }

    test('a peer reorder of kept rows applies (#4477)', () async {
      final serializer = SyncDataSerializer();
      await seedTwoTypes(serializer);
      expect(await typesInOrder('dive-1'), ['shore', 'wreck']);

      await serializer.upsertRecord('diveDiveTypes', {
        ...ddtRow('ddt-b', 'dive-1', 'wreck'),
        'createdAt': 2000,
      });
      await serializer.upsertRecord('diveDiveTypes', {
        ...ddtRow('ddt-a', 'dive-1', 'shore'),
        'createdAt': 2001,
      });

      expect(await typesInOrder('dive-1'), ['wreck', 'shore']);
    });

    test('a batched peer reorder of kept rows applies (#4477)', () async {
      final serializer = SyncDataSerializer();
      await seedTwoTypes(serializer);

      await serializer.upsertRecords('diveDiveTypes', [
        {...ddtRow('ddt-b', 'dive-1', 'wreck'), 'createdAt': 2000},
        {...ddtRow('ddt-a', 'dive-1', 'shore'), 'createdAt': 2001},
      ]);

      expect(await typesInOrder('dive-1'), ['wreck', 'shore']);
    });

    test('a peer tombstone removes a dive-type row', () async {
      final serializer = SyncDataSerializer();
      final diveRepo = DiveRepository();
      final db = DatabaseService.instance.database;

      await diveRepo.createDive(
        domain.Dive(
          id: 'dive-1',
          dateTime: DateTime(2026, 1, 1),
          diveTypeIds: const ['shore'],
        ),
      );
      // A clean (already-synced) extra type row that the peer then removes.
      await serializer.upsertRecord(
        'diveDiveTypes',
        ddtRow('ddt-wreck', 'dive-1', 'wreck'),
      );

      final payload = payloadOf(const SyncData(), {
        'diveDiveTypes': [const SyncDeletion(id: 'ddt-wreck', deletedAt: 5000)],
      });
      await seedPeerBaseFromPayload(cloud, 'peer-dev', payload);

      final result = await buildService().performSync();
      expect(result.status, isNot(SyncResultStatus.error));

      final ids =
          (await (db.select(
                db.diveDiveTypes,
              )..where((t) => t.diveId.equals('dive-1'))).get())
              .map((r) => r.diveTypeId)
              .toSet();
      expect(
        ids,
        isNot(contains('wreck')),
        reason: 'a tombstoned dive-type row must be deleted on the peer',
      );
    });
  });
}
