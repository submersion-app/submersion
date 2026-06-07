import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/core/services/sync/sync_service.dart';
import 'package:submersion/features/marine_life/data/repositories/species_repository.dart';
import 'package:submersion/features/universal_import/data/repositories/csv_preset_repository.dart';

import '../../../helpers/fake_cloud_storage_provider.dart';
import '../../../helpers/sync_test_helpers.dart';
import '../../../helpers/test_database.dart';

/// Regression tests for cross-device deletion propagation gaps.
///
/// Two distinct bug classes were closed in this group:
///   1) entityType naming mismatch between deletion log and SyncData
///      (e.g. site_repository wrote 'site_species' but the serializer
///      switch only knows 'siteSpecies' -> silent no-op on receiver).
///   2) repositories missing logDeletion calls entirely (CsvPresets etc.)
///      so deletions never even reached the payload.
void main() {
  group('Cross-device deletion propagation', () {
    late FakeCloudStorageProvider cloud;

    setUp(() async {
      await setUpTestDatabase();
      cloud = FakeCloudStorageProvider();
    });

    tearDown(() {
      DatabaseService.instance.resetForTesting();
    });

    SyncService buildService() => SyncService(
      syncRepository: SyncRepository(),
      serializer: SyncDataSerializer(),
      cloudProvider: cloud,
    );

    test(
      'removing a site-species link on device A propagates the delete to B',
      () async {
        final serializer = SyncDataSerializer();
        final speciesRepo = SpeciesRepository();

        // Seed parent rows on "device A".
        await serializer.upsertRecord('diveSites', {
          'id': 'site-del-1',
          'name': 'Wall Site',
          'description': '',
          'notes': '',
          'isShared': false,
          'createdAt': 1000,
          'updatedAt': 1000,
        });
        await serializer.upsertRecord('species', {
          'id': 'sp-del-1',
          'commonName': 'Manta',
          'category': 'fish',
          'isBuiltIn': false,
        });
        await serializer.upsertRecord('siteSpecies', {
          'id': 'ss-del-1',
          'siteId': 'site-del-1',
          'speciesId': 'sp-del-1',
          'notes': 'often seen at depth',
          'createdAt': 1000,
        });

        await buildService().performSync(); // push the seeded state
        expect(
          await serializer.fetchRecord('siteSpecies', 'ss-del-1'),
          isNotNull,
        );

        // Device A removes the annotation through the repository (which
        // writes the deletion log entry under the correct entityType).
        await speciesRepo.removeExpectedSpecies('site-del-1', 'sp-del-1');
        expect(
          await serializer.fetchRecord('siteSpecies', 'ss-del-1'),
          isNull,
          reason: 'local row removed immediately',
        );

        await buildService().performSync(); // push the deletion

        // Now switch to "device B": re-insert the row locally to simulate a
        // second device that hadn't yet received the delete, reset sync state
        // so the next sync pulls A's deletion as a cross-device receive.
        await serializer.upsertRecord('siteSpecies', {
          'id': 'ss-del-1',
          'siteId': 'site-del-1',
          'speciesId': 'sp-del-1',
          'notes': 'often seen at depth',
          'createdAt': 1000,
        });
        await impersonateFreshDevice();
        expect(
          await serializer.fetchRecord('siteSpecies', 'ss-del-1'),
          isNotNull,
          reason: 'precondition: device B has the row before the pull',
        );

        await buildService().performSync(); // pull A's deletion

        expect(
          await serializer.fetchRecord('siteSpecies', 'ss-del-1'),
          isNull,
          reason:
              'cross-device delete must propagate; before the rename, the '
              'deletion log entry used a snake_case key the serializer '
              "switch didn't recognise and silently no-op'd",
        );
      },
    );

    test(
      'deleting a CSV preset on device A propagates the delete to B',
      () async {
        final serializer = SyncDataSerializer();
        final presetRepo = CsvPresetRepository();

        // Seed a preset directly (the upsert path is covered by
        // sync_extra_entities_round_trip_test.dart) and push it, so this
        // test focuses on the deletion-logging behaviour.
        await serializer.upsertRecord('csvPresets', {
          'id': 'csv-del-1',
          'name': 'Suunto Layout',
          'presetJson': '{}',
          'createdAt': 1000,
          'updatedAt': 1000,
        });
        await buildService().performSync();
        expect(
          await serializer.fetchRecord('csvPresets', 'csv-del-1'),
          isNotNull,
        );

        await presetRepo.deletePreset('csv-del-1');
        await buildService().performSync(); // push deletion

        // Simulate device B that still has its own copy.
        await serializer.upsertRecord('csvPresets', {
          'id': 'csv-del-1',
          'name': 'Suunto Layout',
          'presetJson': '{}',
          'createdAt': 1000,
          'updatedAt': 1000,
        });
        await impersonateFreshDevice();
        await buildService().performSync(); // pull

        expect(
          await serializer.fetchRecord('csvPresets', 'csv-del-1'),
          isNull,
          reason:
              'CsvPresetRepository.deletePreset must call logDeletion so the '
              'absence propagates; previously it just dropped the local row',
        );
      },
    );

    test('a remote tombstone does NOT delete a child row created locally after '
        'the last sync (createdAt-based conflict protection)', () async {
      final serializer = SyncDataSerializer();

      // Local: a site + species + a site-species link created at t=8000.
      await serializer.upsertRecord('diveSites', {
        'id': 'site-m3',
        'name': 'Wall',
        'description': '',
        'notes': '',
        'isShared': false,
        'createdAt': 1000,
        'updatedAt': 1000,
      });
      await serializer.upsertRecord('species', {
        'id': 'sp-m3',
        'commonName': 'Grouper',
        'category': 'fish',
        'isBuiltIn': false,
      });
      await serializer.upsertRecord('siteSpecies', {
        'id': 'ss-keep',
        'siteId': 'site-m3',
        'speciesId': 'sp-m3',
        'notes': 'local edit',
        'createdAt': 8000, // after the last sync below
      });

      // A foreign device's payload carrying a tombstone for that same link.
      const data = SyncData();
      final checksum = sha256
          .convert(utf8.encode(jsonEncode(data.toJson())))
          .toString();
      final payload = SyncPayload(
        version: syncFormatVersion,
        exportedAt: 9000,
        deviceId: 'remote-dev',
        checksum: checksum,
        data: data,
        deletions: {
          'siteSpecies': [const SyncDeletion(id: 'ss-keep', deletedAt: 5000)],
        },
      );
      await cloud.uploadFile(
        Uint8List.fromList(utf8.encode(serializer.serializePayload(payload))),
        'submersion_sync_remote-dev.json',
      );

      await impersonateFreshDevice();
      await setLastSync(DateTime.fromMillisecondsSinceEpoch(4000));
      await buildService().performSync();

      expect(
        await serializer.fetchRecord('siteSpecies', 'ss-keep'),
        isNotNull,
        reason:
            'the local row was created (8000) after last sync (4000), so '
            'a stale remote tombstone must not delete it',
      );
    });
  });
}
