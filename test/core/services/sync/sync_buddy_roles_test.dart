import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/core/services/sync/sync_service.dart';

import '../../../helpers/changeset_test_helpers.dart';
import '../../../helpers/fake_cloud_storage_provider.dart';
import '../../../helpers/test_database.dart';

/// Sync replication for `buddy_roles` (professional credentials attached to a
/// buddy -- instructor, divemaster, dive guide; issue #395).
///
/// Like `dive_dive_types` (#414), this is a surrogate-UUID-keyed table, but it
/// carries its own `hlc` column (mirroring `buddies`) rather than being a
/// clockless append-only child, so its export uses the simple hlc-filter
/// pattern instead of gathering by an HLC parent.
void main() {
  group('buddy_roles sync (#395)', () {
    setUp(() async {
      await setUpTestDatabase();
    });

    tearDown(() async {
      await tearDownTestDatabase();
    });

    // Hlc string with a given physical-time component (counter 0), matching
    // the canonical zero-padded form the row-level `isBiggerThanValue` filter
    // compares against.
    String hlcAt(int physical, String node) =>
        '${physical.toString().padLeft(15, '0')}:000000:$node';

    Map<String, dynamic> buddyRow(String id) => {
      'id': id,
      'diverId': null,
      'name': 'Buddy $id',
      'email': null,
      'phone': null,
      'certificationLevel': null,
      'certificationAgency': null,
      'photoPath': null,
      'notes': '',
      'createdAt': 1000,
      'updatedAt': 1000,
      'hlc': null,
    };

    Map<String, dynamic> buddyRoleRow(
      String id,
      String buddyId, {
      required String hlc,
      String role = 'instructor',
      String? credentialNumber,
      String? agency,
    }) => {
      'id': id,
      'buddyId': buddyId,
      'role': role,
      'credentialNumber': credentialNumber,
      'agency': agency,
      'notes': '',
      'createdAt': 1000,
      'updatedAt': 1000,
      'hlc': hlc,
    };

    test('export includes a buddy_roles row', () async {
      final serializer = SyncDataSerializer();
      await serializer.upsertRecord('buddies', buddyRow('buddy-1'));
      await serializer.upsertRecord(
        'buddyRoles',
        buddyRoleRow(
          'role-1',
          'buddy-1',
          hlc: hlcAt(1000, 'dev-a'),
          credentialNumber: 'ABC123',
          agency: 'padi',
        ),
      );

      final payload = await serializer.exportData(
        deviceId: 'dev-a',
        deletions: const [],
      );

      final ids = payload.data.buddyRoles.map((r) => r['id']).toSet();
      expect(
        ids,
        contains('role-1'),
        reason: 'a buddy_roles row must appear in the exported payload',
      );
    });

    test(
      'round trip: wipe and re-import restores role, credentialNumber, agency',
      () async {
        final serializer = SyncDataSerializer();
        await serializer.upsertRecord('buddies', buddyRow('buddy-1'));
        await serializer.upsertRecord(
          'buddyRoles',
          buddyRoleRow(
            'role-1',
            'buddy-1',
            hlc: hlcAt(1000, 'dev-a'),
            role: 'diveMaster',
            credentialNumber: 'DM-42',
            agency: 'ssi',
          ),
        );

        final payload = await serializer.exportData(
          deviceId: 'dev-a',
          deletions: const [],
        );
        final exportedRow = payload.data.buddyRoles.singleWhere(
          (r) => r['id'] == 'role-1',
        );

        final db = DatabaseService.instance.database;
        await serializer.deleteAllRecords('buddyRoles');
        expect(
          await (db.select(
            db.buddyRoles,
          )..where((t) => t.id.equals('role-1'))).getSingleOrNull(),
          isNull,
          reason: 'sanity: the wipe actually removed the row',
        );

        await serializer.upsertRecord('buddyRoles', exportedRow);

        final restored = await (db.select(
          db.buddyRoles,
        )..where((t) => t.id.equals('role-1'))).getSingle();
        expect(restored.role, 'diveMaster');
        expect(restored.credentialNumber, 'DM-42');
        expect(restored.agency, 'ssi');
      },
    );

    test(
      'incremental export: only rows with hlc > watermark are included',
      () async {
        final serializer = SyncDataSerializer();
        await serializer.upsertRecord('buddies', buddyRow('buddy-1'));
        await serializer.upsertRecord(
          'buddyRoles',
          buddyRoleRow('role-old', 'buddy-1', hlc: hlcAt(1000, 'dev-a')),
        );
        await serializer.upsertRecord(
          'buddyRoles',
          buddyRoleRow('role-new', 'buddy-1', hlc: hlcAt(9000, 'dev-a')),
        );

        final changeset = await serializer.exportChangeset(
          deviceId: 'dev-a',
          hlcWatermark: hlcAt(5000, 'dev-a'),
          deletions: const [],
        );

        final ids = changeset.data.buddyRoles.map((r) => r['id']).toSet();
        expect(ids, contains('role-new'));
        expect(
          ids,
          isNot(contains('role-old')),
          reason: 'a buddy_role at/below the watermark must not be re-sent',
        );
      },
    );

    test(
      'end to end: a peer-published credential replicates via performSync',
      () async {
        // Device A (the peer) published a buddy plus an instructor credential;
        // this device pulls both down through the real sync pipeline
        // (mergeOrder, entityHasUpdatedAt, fetchRecords, parentRefs).
        final cloud = FakeCloudStorageProvider();
        final data = SyncData(
          buddies: [buddyRow('buddy-1')],
          buddyRoles: [
            buddyRoleRow(
              'role-1',
              'buddy-1',
              hlc: hlcAt(1000, 'peer-dev'),
              role: 'instructor',
              credentialNumber: 'INST-99',
              agency: 'padi',
            ),
          ],
        );
        final payload = SyncPayload(
          version: syncFormatVersion,
          exportedAt: 9000,
          deviceId: 'peer-dev',
          checksum: sha256
              .convert(utf8.encode(jsonEncode(data.toJson())))
              .toString(),
          data: data,
          deletions: const {},
        );
        await seedPeerBaseFromPayload(cloud, 'peer-dev', payload);

        final result = await SyncService(
          syncRepository: SyncRepository(),
          serializer: SyncDataSerializer(),
          cloudProvider: cloud,
        ).performSync();
        expect(result.status, isNot(SyncResultStatus.error));

        final db = DatabaseService.instance.database;
        final restored = await (db.select(
          db.buddyRoles,
        )..where((t) => t.id.equals('role-1'))).getSingleOrNull();
        expect(
          restored,
          isNotNull,
          reason: 'a peer-published credential must replicate to this device',
        );
        expect(restored!.buddyId, 'buddy-1');
        expect(restored.role, 'instructor');
        expect(restored.credentialNumber, 'INST-99');
        expect(restored.agency, 'padi');
      },
    );

    test('per-record plumbing: fetchRecord, recordIdsFor, deleteRecord, '
        'and SyncData.fromJson all handle buddyRoles', () async {
      final serializer = SyncDataSerializer();
      await serializer.upsertRecord('buddies', buddyRow('buddy-1'));
      await serializer.upsertRecord(
        'buddyRoles',
        buddyRoleRow(
          'role-1',
          'buddy-1',
          hlc: hlcAt(1000, 'dev-a'),
          credentialNumber: 'ABC123',
          agency: 'padi',
        ),
      );

      // Single-record fetch (used by the changeset path).
      final fetched = await serializer.fetchRecord('buddyRoles', 'role-1');
      expect(fetched, isNotNull);
      expect(fetched!['credentialNumber'], 'ABC123');

      final missing = await serializer.fetchRecord('buddyRoles', 'nope');
      expect(missing, isNull);

      // Local id enumeration (used by streaming adopt to delete strays).
      expect(await serializer.recordIdsFor('buddyRoles'), {'role-1'});

      // Payload container survives a JSON round trip.
      final payload = await serializer.exportData(
        deviceId: 'dev-a',
        deletions: const [],
      );
      final rehydrated = SyncData.fromJson(payload.data.toJson());
      expect(rehydrated.buddyRoles.map((r) => r['id']), contains('role-1'));

      // Tombstone application path.
      await serializer.deleteRecord('buddyRoles', 'role-1');
      expect(await serializer.recordIdsFor('buddyRoles'), isEmpty);
    });
  });
}
