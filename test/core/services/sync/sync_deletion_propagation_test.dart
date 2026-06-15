import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart' show MediaCompanion;
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/core/services/sync/sync_service.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/marine_life/data/repositories/species_repository.dart';
import 'package:submersion/features/universal_import/data/repositories/csv_preset_repository.dart';

import '../../../helpers/changeset_test_helpers.dart';
import '../../../helpers/fake_cloud_storage_provider.dart';
import '../../../helpers/mock_providers.dart';
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

    tearDown(() async {
      await tearDownTestDatabase();
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

        // Publish device A's state -- parents live, the link tombstoned -- as a
        // peer, then reset to a fresh device. seedPeerLog carries A's deletion
        // log into the peer base (its writer disables compaction, which would
        // otherwise rebase the tiny test DB to a live-only snapshot and drop
        // the tombstone before any peer could receive it).
        await seedPeerLog(cloud, 'device-a');

        // Device B: re-create the parents and the link locally to simulate a
        // second device that hadn't yet received the delete; the next sync
        // pulls A's deletion as a cross-device receive.
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
        // sync_extra_entities_round_trip_test.dart), so this test focuses on
        // the deletion-logging behaviour.
        await serializer.upsertRecord('csvPresets', {
          'id': 'csv-del-1',
          'name': 'Suunto Layout',
          'presetJson': '{}',
          'createdAt': 1000,
          'updatedAt': 1000,
        });
        expect(
          await serializer.fetchRecord('csvPresets', 'csv-del-1'),
          isNotNull,
        );

        await presetRepo.deletePreset('csv-del-1');

        // Publish device A's state -- the preset tombstoned -- as a peer, then
        // reset to a fresh device. seedPeerLog carries A's deletion log into
        // the peer base (its writer disables compaction, which would otherwise
        // rebase the tiny test DB to a live-only snapshot and drop the
        // tombstone before any peer could receive it).
        await seedPeerLog(cloud, 'device-a');

        // Simulate device B that still has its own copy.
        await serializer.upsertRecord('csvPresets', {
          'id': 'csv-del-1',
          'name': 'Suunto Layout',
          'presetJson': '{}',
          'createdAt': 1000,
          'updatedAt': 1000,
        });
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
      await seedPeerBaseFromPayload(cloud, 'remote-dev', payload);

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

  /// A device that has deleted a record must not have it resurrected by a peer
  /// that still holds a live copy it has not yet seen deleted. This is the
  /// other direction of deletion propagation: applying a remote *live* record
  /// against a *local tombstone* (vs. applying a remote tombstone against a
  /// local live row, covered above).
  group('Local deletion is not resurrected by a peer live copy', () {
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

    Future<void> uploadPeerDive(
      SyncDataSerializer serializer,
      Map<String, dynamic> diveJson,
    ) async {
      final peerData = SyncData(dives: [diveJson]);
      final checksum = sha256
          .convert(utf8.encode(jsonEncode(peerData.toJson())))
          .toString();
      final payload = SyncPayload(
        version: syncFormatVersion,
        exportedAt: 2000,
        deviceId: 'peer-dev',
        checksum: checksum,
        data: peerData,
        deletions: const {},
      );
      await seedPeerBaseFromPayload(cloud, 'peer-dev', payload);
    }

    test('a deleted dive is NOT resurrected by a peer copy older than the '
        'deletion', () async {
      final serializer = SyncDataSerializer();
      final diveRepo = DiveRepository();

      // Device A creates dive #43 and syncs it (so it is no longer "pending"
      // -- a pending record is skipped on merge, which would mask the bug).
      await diveRepo.createDive(
        createTestDiveWithBottomTime(id: 'dive-43', diveNumber: 43),
      );
      await buildService().performSync();
      final diveJson = await serializer.fetchRecord('dives', 'dive-43');
      expect(diveJson, isNotNull);

      // A deletes #43 (writes a tombstone, removes the local row).
      await diveRepo.deleteDive('dive-43');
      expect(await serializer.fetchRecord('dives', 'dive-43'), isNull);

      // A peer that has not seen the delete still has the live dive, with an
      // updatedAt far older than our (just-now) deletion.
      await uploadPeerDive(serializer, {...diveJson!, 'updatedAt': 1000});

      await buildService().performSync();

      expect(
        await serializer.fetchRecord('dives', 'dive-43'),
        isNull,
        reason:
            "a peer's stale live copy must not resurrect a locally-deleted dive",
      );
    });

    test('a peer edit newer than the local deletion revives the dive and '
        'drops the tombstone', () async {
      final serializer = SyncDataSerializer();
      final diveRepo = DiveRepository();

      await diveRepo.createDive(
        createTestDiveWithBottomTime(id: 'dive-44', diveNumber: 44),
      );
      await buildService().performSync();
      final diveJson = await serializer.fetchRecord('dives', 'dive-44');
      await diveRepo.deleteDive('dive-44');

      // Peer edited the dive AFTER our deletion (updatedAt in the far future).
      await uploadPeerDive(serializer, {
        ...diveJson!,
        'updatedAt': 99999999999999,
      });

      await buildService().performSync();

      expect(
        await serializer.fetchRecord('dives', 'dive-44'),
        isNotNull,
        reason: 'a peer edit newer than the deletion is a genuine revival',
      );
      final remaining = await SyncRepository().getAllDeletions();
      expect(
        remaining.any((d) => d.recordId == 'dive-44'),
        isFalse,
        reason: 'a revived record should drop its now-obsolete tombstone',
      );
    });

    test('a deleted dive WITH child records is not resurrected and does not '
        'orphan its children', () async {
      final serializer = SyncDataSerializer();
      final diveRepo = DiveRepository();

      await diveRepo.createDive(
        createTestDiveWithBottomTime(id: 'dive-50', diveNumber: 50),
      );
      await serializer.upsertRecord('diveProfiles', {
        'id': 'prof-50',
        'diveId': 'dive-50',
        'isPrimary': true,
        'timestamp': 0,
        'depth': 5.0,
      });
      await buildService().performSync();
      final diveJson = await serializer.fetchRecord('dives', 'dive-50');
      final profJson = await serializer.fetchRecord('diveProfiles', 'prof-50');
      expect(profJson, isNotNull);

      // Deleting the dive cascades the child away locally.
      await diveRepo.deleteDive('dive-50');
      expect(await serializer.fetchRecord('dives', 'dive-50'), isNull);
      expect(await serializer.fetchRecord('diveProfiles', 'prof-50'), isNull);

      // Peer still has the live dive AND its live child profile.
      final peerData = SyncData(
        dives: [
          {...diveJson!, 'updatedAt': 1000},
        ],
        diveProfiles: [profJson!],
      );
      final checksum = sha256
          .convert(utf8.encode(jsonEncode(peerData.toJson())))
          .toString();
      final payload = SyncPayload(
        version: syncFormatVersion,
        exportedAt: 2000,
        deviceId: 'peer-dev',
        checksum: checksum,
        data: peerData,
        deletions: const {},
      );
      await seedPeerBaseFromPayload(cloud, 'peer-dev', payload);

      final result = await buildService().performSync();

      expect(
        result.status,
        isNot(SyncResultStatus.error),
        reason: 'a peer copy of a deleted dive+children must not error sync',
      );
      expect(
        await serializer.fetchRecord('dives', 'dive-50'),
        isNull,
        reason: 'the dive stays deleted',
      );
      expect(
        await serializer.fetchRecord('diveProfiles', 'prof-50'),
        isNull,
        reason: 'the orphaned child must not be resurrected either',
      );
    });

    test('a photo whose dive was deleted is preserved (set-null), not lost '
        'and not resurrected with a dangling link', () async {
      final serializer = SyncDataSerializer();
      final diveRepo = DiveRepository();
      final db = DatabaseService.instance.database;

      await diveRepo.createDive(
        createTestDiveWithBottomTime(id: 'dive-60', diveNumber: 60),
      );
      await db
          .into(db.media)
          .insert(
            MediaCompanion.insert(
              id: 'media-60',
              diveId: const Value('dive-60'),
              filePath: '/photo.jpg',
              createdAt: 1000,
              updatedAt: 1000,
            ),
          );
      await buildService().performSync();
      final diveJson = await serializer.fetchRecord('dives', 'dive-60');
      final mediaJson = await serializer.fetchRecord('media', 'media-60');
      expect(mediaJson, isNotNull);

      // Deleting the dive set-nulls the photo's diveId locally; the photo
      // survives (Media.diveId is nullable / onDelete: setNull).
      await diveRepo.deleteDive('dive-60');
      expect(await serializer.fetchRecord('dives', 'dive-60'), isNull);
      final localMedia = await serializer.fetchRecord('media', 'media-60');
      expect(
        localMedia,
        isNotNull,
        reason: 'the photo must survive the delete',
      );
      expect(localMedia!['diveId'], isNull);

      // Peer still has the live dive AND the photo still linked to it.
      final peerData = SyncData(
        dives: [
          {...diveJson!, 'updatedAt': 1000},
        ],
        media: [mediaJson!],
      );
      final checksum = sha256
          .convert(utf8.encode(jsonEncode(peerData.toJson())))
          .toString();
      final payload = SyncPayload(
        version: syncFormatVersion,
        exportedAt: 2000,
        deviceId: 'peer-dev',
        checksum: checksum,
        data: peerData,
        deletions: const {},
      );
      await seedPeerBaseFromPayload(cloud, 'peer-dev', payload);

      final result = await buildService().performSync();

      expect(result.status, isNot(SyncResultStatus.error));
      expect(await serializer.fetchRecord('dives', 'dive-60'), isNull);
      final afterMedia = await serializer.fetchRecord('media', 'media-60');
      expect(
        afterMedia,
        isNotNull,
        reason: 'the photo must NOT be lost when its dive is deleted',
      );
      expect(
        afterMedia!['diveId'],
        isNull,
        reason: 'the dangling dive link is cleared, not resurrected',
      );
    });

    test(
      'applying a peer deletion of a SITE a local dive still references does '
      'not fail the sync; the dive survives with a cleared site link',
      () async {
        final serializer = SyncDataSerializer();
        final diveRepo = DiveRepository();

        await serializer.upsertRecord('diveSites', {
          'id': 'site-x',
          'name': 'Reef',
          'description': '',
          'notes': '',
          'isShared': false,
          'createdAt': 1000,
          'updatedAt': 1000,
        });
        await diveRepo.createDive(
          createTestDiveWithBottomTime(id: 'dive-x', diveNumber: 1),
        );
        final diveJson = await serializer.fetchRecord('dives', 'dive-x');
        await serializer.upsertRecord('dives', {
          ...diveJson!,
          'siteId': 'site-x',
        });

        await buildService()
            .performSync(); // push current state, advance lastSync

        // A peer deletes the site while our local dive still references it
        // (dives.siteId is a non-cascading FK, so it would dangle at COMMIT).
        const data = SyncData();
        final checksum = sha256
            .convert(utf8.encode(jsonEncode(data.toJson())))
            .toString();
        final payload = SyncPayload(
          version: syncFormatVersion,
          exportedAt: 9000,
          deviceId: 'peer-dev',
          checksum: checksum,
          data: data,
          deletions: {
            'diveSites': [const SyncDeletion(id: 'site-x', deletedAt: 8000)],
          },
        );
        await seedPeerBaseFromPayload(cloud, 'peer-dev', payload);

        final result = await buildService().performSync();

        expect(
          result.status,
          isNot(SyncResultStatus.error),
          reason: 'a deleted parent must not abort the whole sync (787)',
        );
        expect(
          await serializer.fetchRecord('diveSites', 'site-x'),
          isNull,
          reason: 'the site deletion still applies',
        );
        final dive = await serializer.fetchRecord('dives', 'dive-x');
        expect(dive, isNotNull, reason: 'the dive itself must survive');
        expect(
          dive!['siteId'],
          isNull,
          reason: 'the dangling site link is cleared, not left to crash COMMIT',
        );
      },
    );

    test('a parent revived in the same payload keeps its children; the FK is '
        'not cleared by the stale tombstone snapshot (any merge order)', () async {
      final serializer = SyncDataSerializer();
      final diveRepo = DiveRepository();

      // Local: a site + a dive referencing it; capture the dive JSON.
      await serializer.upsertRecord('diveSites', {
        'id': 'site-r',
        'name': 'Reef',
        'description': '',
        'notes': '',
        'isShared': false,
        'createdAt': 1000,
        'updatedAt': 1000,
      });
      await diveRepo.createDive(
        createTestDiveWithBottomTime(id: 'dive-r', diveNumber: 7),
      );
      final diveBase = await serializer.fetchRecord('dives', 'dive-r');
      await serializer.upsertRecord('dives', {
        ...diveBase!,
        'siteId': 'site-r',
      });
      final diveJson = await serializer.fetchRecord('dives', 'dive-r');
      await buildService().performSync(); // push, advance lastSync

      // Locally delete (tombstone) the site. Remove the dive first so the
      // non-cascading FK lets the site row go; the tombstone predates the peer
      // edit below.
      await serializer.deleteRecord('dives', 'dive-r');
      await serializer.deleteRecord('diveSites', 'site-r');
      await SyncRepository().logDeletion(
        entityType: 'diveSites',
        recordId: 'site-r',
        deletedAt: 5000,
      );

      // Peer payload: the site is EDITED (updatedAt 9000 > deletion 5000, so it
      // revives) AND a dive still references it. `dives` merges before
      // `diveSites`, so the child is processed while the parent still looks
      // tombstoned -- the precomputed revived set must keep the FK.
      final peerData = SyncData(
        diveSites: [
          {
            'id': 'site-r',
            'name': 'Reef (renamed)',
            'description': '',
            'notes': '',
            'isShared': false,
            'createdAt': 1000,
            'updatedAt': 9000,
          },
        ],
        dives: [
          {...diveJson!, 'siteId': 'site-r', 'updatedAt': 9000},
        ],
      );
      final checksum = sha256
          .convert(utf8.encode(jsonEncode(peerData.toJson())))
          .toString();
      final payload = SyncPayload(
        version: syncFormatVersion,
        exportedAt: 9000,
        deviceId: 'peer-dev',
        checksum: checksum,
        data: peerData,
        deletions: const {},
      );
      await seedPeerBaseFromPayload(cloud, 'peer-dev', payload);

      final result = await buildService().performSync();

      expect(result.status, isNot(SyncResultStatus.error));
      expect(
        await serializer.fetchRecord('diveSites', 'site-r'),
        isNotNull,
        reason: 'the site is revived by the newer remote edit',
      );
      final revivedDive = await serializer.fetchRecord('dives', 'dive-r');
      expect(revivedDive, isNotNull);
      expect(
        revivedDive!['siteId'],
        'site-r',
        reason:
            'the FK must be preserved when the parent is revived in the '
            'same payload, regardless of merge order',
      );
    });
  });
}
