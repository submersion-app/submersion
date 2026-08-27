import 'dart:convert';

import 'package:crypto/crypto.dart';
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
