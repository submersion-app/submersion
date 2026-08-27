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

/// Regression tests for issue #474: "Blanking custom dive name doesn't seem to
/// propagate to sync."
///
/// Renaming a dive to a NEW value syncs, but CLEARING the name (null) does not.
/// Root cause: the merge write path applies incoming rows with Drift's
/// `insertOnConflictUpdate(Dive.fromJson(data))`. A data class is serialized
/// via `toColumns(nullToAbsent: true)`, which OMITS a null column from the
/// `ON CONFLICT DO UPDATE SET ...` clause -- so an incoming `name: null` never
/// overwrites the receiving device's existing non-null name. Fixed by applying
/// rows as `.toCompanion(false)` (explicit nulls become `Value(null)`).
///
/// A blanket `.toCompanion(false)`, though, would also clear a column a peer
/// OMITTED entirely (e.g. a build predating that column). `_mergeEntity` guards
/// that by overlaying the winning remote row onto the local one, so an omitted
/// key keeps its local value while an explicit null still clears.
void main() {
  group('Clearing a dive name through the sync merge write path (#474)', () {
    setUp(() async {
      await setUpTestDatabase();
    });

    tearDown(() {
      DatabaseService.instance.resetForTesting();
    });

    /// The full JSON of a locally-stored dive that already carries a name,
    /// standing in for the row a receiving device holds before the changeset
    /// that blanks the name arrives.
    Future<Map<String, dynamic>> seedNamedDive(String id) async {
      final serializer = SyncDataSerializer();
      await DiveRepository().createDive(
        createTestDiveWithBottomTime(id: id).copyWith(name: 'Original Name'),
      );
      final seeded = await serializer.fetchRecord('dives', id);
      expect(
        seeded!['name'],
        'Original Name',
        reason: 'precondition: the dive is stored with its name',
      );
      return seeded;
    }

    test(
      'upsertRecords (batched merge path) clears the name when incoming is null',
      () async {
        final serializer = SyncDataSerializer();
        final seeded = await seedNamedDive('dive-clear-batch');

        // Incoming changeset from the other device: same row, name blanked.
        final cleared = {...seeded, 'name': null};
        await serializer.upsertRecords('dives', [cleared]);

        final after = await serializer.fetchRecord('dives', 'dive-clear-batch');
        expect(
          after!['name'],
          isNull,
          reason:
              'THE BUG: a blanked (null) name did not overwrite the stored name',
        );
      },
    );

    test(
      'upsertRecord (single merge path) clears the name when incoming is null',
      () async {
        final serializer = SyncDataSerializer();
        final seeded = await seedNamedDive('dive-clear-single');

        final cleared = {...seeded, 'name': null};
        await serializer.upsertRecord('dives', cleared);

        final after = await serializer.fetchRecord(
          'dives',
          'dive-clear-single',
        );
        expect(
          after!['name'],
          isNull,
          reason:
              'THE BUG: a blanked (null) name did not overwrite the stored name',
        );
      },
    );

    test(
      'a non-null rename still applies through the merge (control)',
      () async {
        final serializer = SyncDataSerializer();
        final seeded = await seedNamedDive('dive-rename-control');

        final renamed = {...seeded, 'name': 'New Name'};
        await serializer.upsertRecords('dives', [renamed]);

        final after = await serializer.fetchRecord(
          'dives',
          'dive-rename-control',
        );
        expect(
          after!['name'],
          'New Name',
          reason: 'a non-null rename must continue to propagate',
        );
      },
    );
  });

  group(
    'End-to-end merge: present-null clears, omitted key preserved (#474)',
    () {
      late FakeCloudStorageProvider cloud;

      setUp(() async {
        await setUpTestDatabase();
        cloud = FakeCloudStorageProvider();
      });

      tearDown(() => DatabaseService.instance.resetForTesting());

      SyncService buildService() => SyncService(
        syncRepository: SyncRepository(),
        serializer: SyncDataSerializer(),
        cloudProvider: cloud,
      );

      /// Seeds a named, already-synced (non-pending) dive locally, then returns
      /// its exported JSON so the test can build a peer's winning version of it.
      /// `resetSyncState` clears pending + epoch (leaving the row) so a pulled
      /// peer row reaches the LWW/overlay branch instead of being skipped.
      Future<Map<String, dynamic>> seedSyncedNamedDive(String id) async {
        final diveRepo = DiveRepository();
        await diveRepo.createDive(
          createTestDiveWithBottomTime(id: id).copyWith(name: 'Original Name'),
        );
        final row = await SyncDataSerializer().fetchRecord('dives', id);
        await SyncRepository().resetSyncState();
        return Map<String, dynamic>.from(row!);
      }

      /// Publishes [diveRow] as peer `peer-x`'s base and pulls it into this
      /// device via the real sync pipeline (`performSync` -> `_mergeEntity`).
      Future<void> pullPeerDive(Map<String, dynamic> diveRow) async {
        final data = SyncData(dives: [diveRow]);
        final payload = SyncPayload(
          version: syncFormatVersion,
          exportedAt: 9000,
          deviceId: 'peer-x',
          checksum: sha256
              .convert(utf8.encode(jsonEncode(data.toJson())))
              .toString(),
          data: data,
          deletions: const {},
        );
        await seedPeerBaseFromPayload(cloud, 'peer-x', payload);
        final result = await buildService().performSync();
        expect(result.status, isNot(SyncResultStatus.error));
      }

      test('a peer that OMITS the name key does not clear it', () async {
        final row = await seedSyncedNamedDive('dive-omit');

        // A build predating the `name` column: it never sends the key, and wins
        // LWW on updatedAt. The overlay must keep the local name.
        row.remove('name');
        row.remove('hlc'); // force the deterministic updatedAt LWW branch
        row['updatedAt'] = (row['updatedAt'] as int) + 1000;
        await pullPeerDive(row);

        final restored = await DiveRepository().getDiveById('dive-omit');
        expect(
          restored!.name,
          'Original Name',
          reason: 'a peer that never sent the name column must not clear it',
        );
      });

      test('a peer that sends an explicit null name DOES clear it', () async {
        final row = await seedSyncedNamedDive('dive-null');

        // A current-build peer that cleared the name: it sends the key as null
        // and wins LWW. The clear must propagate (the #474 fix).
        row['name'] = null;
        row.remove('hlc');
        row['updatedAt'] = (row['updatedAt'] as int) + 1000;
        await pullPeerDive(row);

        final restored = await DiveRepository().getDiveById('dive-null');
        expect(
          restored!.name,
          isNull,
          reason: 'an explicit null from a peer must clear the name (#474)',
        );
      });
    },
  );
}
