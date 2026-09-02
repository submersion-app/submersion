// Characterization tests for cross-version sync (issue #1089).
//
// A peer on an older schema (the App Store fleet during an Apple review
// window) republishes rows WITHOUT the columns its build does not know.
// These tests freeze the receiving-side behavior that makes that safe:
//  - the #474 overlay refills omitted keys from the local row,
//  - a tied HLC keeps local (an unedited old-peer snapshot applies nothing),
//  - rows created on the old device apply with newer columns as null.
// The compatibility floor (AppDatabase.minimumCompatibleSchemaVersion)
// asserts this safety; when a migration raises the floor, extend
// postV137DiveKeys and add the analogous projection for the new boundary.
//
// The floor moved 137 -> 160 with the service type unification, which renamed
// the synced column service_records.service_type to service_category. That
// stops pre-160 peers applying OUR payloads, but the gate is one-directional,
// so the second group below covers the direction the floor cannot reach: a
// pre-160 peer's payload, keyed with the old spelling, arriving here.
// postV137DiveKeys stays as the record of the previous boundary.
import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/changeset_log/changeset_log_layout.dart';
import 'package:submersion/core/services/sync/changeset_log/sync_manifest.dart';
import 'package:submersion/core/services/sync/hlc.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/core/services/sync/sync_service.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/repositories/profile_series_repository.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_sample.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_series_codec.dart';

import '../../../helpers/changeset_test_helpers.dart';
import '../../../helpers/fake_cloud_storage_provider.dart';
import '../../../helpers/mock_providers.dart';
import '../../../helpers/test_database.dart';

/// The dives-table JSON keys a schema-137 (v1.7.2) build does not know.
/// From the migration ladder: v144 added dives.visibility_meters; no other
/// dives column landed between 138 and 153. Extend this list when a later
/// migration adds a dives column, so the projection stays a faithful model
/// of what the oldest supported reader republishes.
const postV137DiveKeys = ['visibilityMeters'];

void main() {
  group('v137 peer round-trip through the real merge path (#1089)', () {
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

    /// Seeds a synced (non-pending) dive carrying a post-137 column value,
    /// returning its full exported JSON: the row as this newer device would
    /// publish it.
    Future<Map<String, dynamic>> seedModernDive(String id) async {
      await DiveRepository().createDive(
        createTestDiveWithBottomTime(id: id).copyWith(name: 'Original Name'),
      );
      final db = DatabaseService.instance.database;
      await db.customStatement(
        'UPDATE dives SET visibility_meters = 12.5 WHERE id = ?',
        [id],
      );
      final row = await SyncDataSerializer().fetchRecord('dives', id);
      expect(row!['visibilityMeters'], 12.5, reason: 'precondition');
      expect(row['hlc'], isNotNull, reason: 'precondition: row is clocked');
      await SyncRepository().resetSyncState();
      return Map<String, dynamic>.from(row);
    }

    /// Projects [row] onto the v137 dives schema: exactly what a 1.7.2 device
    /// ends up storing (fromJson ignores unknown keys) and later re-exporting
    /// (its row genuinely lacks the newer columns, so their keys are absent).
    Map<String, dynamic> asV137Peer(Map<String, dynamic> row) {
      final projected = Map<String, dynamic>.from(row);
      for (final key in postV137DiveKeys) {
        projected.remove(key);
      }
      return projected;
    }

    /// Publishes [diveRow] as peer `peer-137`'s data and pulls it through the
    /// full real pipeline (performSync, _mergeEntity, overlay, upsert).
    Future<void> pullPeerDive(Map<String, dynamic> diveRow) async {
      final data = SyncData(dives: [diveRow]);
      final payload = SyncPayload(
        version: syncFormatVersion,
        exportedAt: 9000,
        deviceId: 'peer-137',
        checksum: sha256
            .convert(utf8.encode(jsonEncode(data.toJson())))
            .toString(),
        data: data,
        deletions: const {},
      );
      await seedPeerBaseFromPayload(cloud, 'peer-137', payload);
      final result = await buildService().performSync();
      // A per-row apply failure flips the whole run to error, so this
      // assertion covers recordsFailed too.
      expect(result.status, isNot(SyncResultStatus.error));
    }

    test('old-peer edit applies AND the post-137 column survives', () async {
      final row = await seedModernDive('dive-xver');

      // The v137 peer edits the dive: its republished row carries only v137
      // keys, the edit, and a strictly-greater HLC minted by its own clock.
      final peerRow = asV137Peer(row)
        ..['name'] = 'Renamed on old device'
        ..['hlc'] = Hlc(
          Hlc.parse(row['hlc'] as String).physicalTime + 60000,
          0,
          'peer-137',
        ).toString()
        ..['updatedAt'] = (row['updatedAt'] as int) + 60000;

      await pullPeerDive(peerRow);

      final after = await SyncDataSerializer().fetchRecord(
        'dives',
        'dive-xver',
      );
      expect(
        after!['name'],
        'Renamed on old device',
        reason: 'the old peer legitimately won LWW; its edit must apply',
      );
      expect(
        after['visibilityMeters'],
        12.5,
        reason: 'THE HAZARD: the column the old peer never knew must survive',
      );
    });

    test(
      'tied-HLC republish (unedited old-peer snapshot) applies nothing',
      () async {
        final row = await seedModernDive('dive-tie');

        // The old peer republishes its full base without editing: same HLC.
        final peerRow = asV137Peer(row)..['name'] = 'Should Not Apply';

        await pullPeerDive(peerRow);

        final after = await SyncDataSerializer().fetchRecord(
          'dives',
          'dive-tie',
        );
        expect(
          after!['name'],
          'Original Name',
          reason: 'a tied HLC keeps local; nothing applies',
        );
        expect(after['visibilityMeters'], 12.5);
      },
    );

    test('row CREATED on the old device applies cleanly', () async {
      final template = await seedModernDive('dive-template');

      // A brand-new dive logged on the v137 device: no post-137 keys at all,
      // an id this device has never seen, the old device's own clock.
      final peerRow = asV137Peer(template)
        ..['id'] = 'dive-born-on-137'
        ..['name'] = 'Logged on old device'
        ..['hlc'] = Hlc(
          Hlc.parse(template['hlc'] as String).physicalTime + 60000,
          0,
          'peer-137',
        ).toString();

      await pullPeerDive(peerRow);

      final after = await SyncDataSerializer().fetchRecord(
        'dives',
        'dive-born-on-137',
      );
      expect(after, isNotNull, reason: 'the new row must apply');
      expect(after!['name'], 'Logged on old device');
      expect(
        after['visibilityMeters'],
        isNull,
        reason: 'nullable post-137 column backfills as null, not garbage',
      );
    });
  });

  group('pre-160 peer publishing a service record (service type rename)', () {
    late FakeCloudStorageProvider cloud;

    setUp(() async {
      await setUpTestDatabase();
      cloud = FakeCloudStorageProvider();
      // service_records.equipment_id is a real FK and foreign_keys is ON.
      await DatabaseService.instance.database.customStatement(
        "INSERT INTO equipment (id, name, type, purchase_currency, "
        "custom_reminder_enabled, custom_reminder_days, created_at, "
        "updated_at) VALUES ('e-xver', 'Reg', 'regulator', 'USD', 0, '', 1, 1)",
      );
    });

    tearDown(() => DatabaseService.instance.resetForTesting());

    SyncService buildService() => SyncService(
      syncRepository: SyncRepository(),
      serializer: SyncDataSerializer(),
      cloudProvider: cloud,
    );

    /// Publishes one service-record row as a peer and pulls it through the
    /// full real pipeline (performSync, _mergeEntity, overlay, upsert).
    Future<void> pullPeerServiceRecord(Map<String, dynamic> row) async {
      final data = SyncData(serviceRecords: [row]);
      final payload = SyncPayload(
        version: syncFormatVersion,
        exportedAt: 9000,
        deviceId: 'peer-159',
        checksum: sha256
            .convert(utf8.encode(jsonEncode(data.toJson())))
            .toString(),
        data: data,
        deletions: const {},
      );
      await seedPeerBaseFromPayload(cloud, 'peer-159', payload);
      final result = await buildService().performSync();
      expect(result.status, isNot(SyncResultStatus.error));
    }

    Map<String, dynamic> legacyRow(String id, String category) => {
      'id': id,
      'equipmentId': 'e-xver',
      // The pre-160 spelling. This is the whole point of the test.
      'serviceType': category,
      'serviceKindId': null,
      'serviceDate': 1700000000000,
      'provider': null,
      'cost': null,
      'currency': 'USD',
      'nextServiceDue': null,
      'notes': '',
      'createdAt': 1700000000000,
      'updatedAt': 1700000000000,
      'hlc': const Hlc(1700000000000, 0, 'peer-159').toString(),
    };

    test('an old-key payload applies through the merge path', () async {
      await pullPeerServiceRecord(legacyRow('rec-xver', 'repair'));

      final row = await DatabaseService.instance.database
          .customSelect(
            "SELECT service_category FROM service_records "
            "WHERE id = 'rec-xver'",
          )
          .getSingle();
      expect(row.read<String>('service_category'), 'repair');
    });
  });

  group('v181 peer round-trip across the series boundary (plan 2d)', () {
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

    /// Seeds a synced (non-pending) dive with no profile, mirroring
    /// [seedModernDive] in the v137 group above without the post-137 column
    /// edit this group has no use for.
    Future<Map<String, dynamic>> seedModernDive(String id) async {
      await DiveRepository().createDive(createTestDiveWithBottomTime(id: id));
      final row = await SyncDataSerializer().fetchRecord('dives', id);
      expect(row, isNotNull, reason: 'precondition');
      await SyncRepository().resetSyncState();
      return Map<String, dynamic>.from(row!);
    }

    /// Publishes [diveRow] alongside [legacyRows] as peer `peer-181`'s single
    /// changeset and pulls it through the real merge path, the way
    /// [pullPeerDive] does for the v137 group above. `SyncData.toJson` no
    /// longer carries the legacy `diveProfiles` key (it is inbound-only as of
    /// plan 2d task 2), so the payload's `data` section is assembled by hand
    /// from raw JSON and the checksum is recomputed over it, mirroring
    /// `buildPayloadJson`/`pullPeerPayload` in
    /// legacy_sample_entities_inbound_test.dart rather than going through a
    /// `SyncPayload` object (whose `toJson` would drop the key again).
    Future<void> pullPeerPayloadWithLegacy(
      Map<String, dynamic> diveRow,
      List<Map<String, dynamic>> legacyRows,
    ) async {
      const peerId = 'peer-181';
      final data = SyncData(dives: [diveRow]);
      final dataJson = {...data.toJson(), 'diveProfiles': legacyRows};
      final checksum = sha256
          .convert(utf8.encode(jsonEncode(dataJson)))
          .toString();
      final payloadJson = <String, dynamic>{
        'version': syncFormatVersion,
        'exportedAt': 9000,
        'deviceId': peerId,
        'lastSyncTimestamp': null,
        'checksum': checksum,
        'data': dataJson,
        'deletions': <String, dynamic>{},
        'uploadNonce': null,
        'epochId': null,
        'seq': 1,
        'baseSeq': null,
        'sinceHlc': null,
        'toHlc': null,
      };
      final bytes = Uint8List.fromList(utf8.encode(jsonEncode(payloadJson)));
      final folder = await cloud.getOrCreateSyncFolder();
      await cloud.uploadFile(
        bytes,
        ChangesetLogLayout.changesetName(peerId, 1),
        folderId: folder,
      );
      final manifest = SyncManifest(
        deviceId: peerId,
        provider: cloud.providerId,
        headSeq: 1,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      );
      await cloud.uploadFile(
        manifest.toBytes(),
        ChangesetLogLayout.manifestName(peerId),
        folderId: folder,
      );
      final result = await buildService().performSync();
      // A per-row apply failure flips the whole run to error, so this
      // assertion covers recordsFailed too.
      expect(result.status, isNot(SyncResultStatus.error));
    }

    test('the floor is 183', () {
      expect(AppDatabase.minimumCompatibleSchemaVersion, 183);
    });

    test('an old peer that still sends dive_profiles rows produces a series '
        'here', () async {
      // seedModernDive('dive-old') as the v137 group does, then delete its
      // series locally so the dive looks like one the peer created:
      final diveRow = await seedModernDive('dive-old');
      await ProfileSeriesRepository().deleteForDive('dive-old');
      await SyncRepository().resetSyncState();
      final legacyRows = [
        {
          'id': 'r1',
          'diveId': 'dive-old',
          'timestamp': 0,
          'depth': 0.0,
          'isPrimary': true,
        },
        {
          'id': 'r2',
          'diveId': 'dive-old',
          'timestamp': 30,
          'depth': 9.0,
          'isPrimary': true,
        },
      ];
      await pullPeerPayloadWithLegacy(diveRow, legacyRows);
      final series = await ProfileSeriesRepository().getSeriesForDive(
        'dive-old',
      );
      expect(series.single.samples.map((s) => s.depth), [0.0, 9.0]);
    });

    test(
      'a series row pushed by a modern peer applies with LWW by hlc',
      () async {
        final diveRow = await seedModernDive('dive-new');
        final diveId = diveRow['id'] as String;
        final seriesId = await ProfileSeriesRepository().insertSeries(
          diveId: diveId,
          samples: const [
            ProfileSample(timestamp: 0, depth: 5.0),
            ProfileSample(timestamp: 60, depth: 10.0),
          ],
        );
        final row = (await SyncDataSerializer().fetchRecord(
          'diveProfileSeries',
          seriesId,
        ))!;
        await SyncRepository().resetSyncState();

        const codec = ProfileSeriesCodec();
        final encoded = codec.encode(const [
          ProfileSample(timestamp: 0, depth: 1.0),
          ProfileSample(timestamp: 45, depth: 30.0),
        ]);
        final summary = encoded.summary;
        final peerRow = Map<String, dynamic>.from(row)
          ..['samples'] = base64Encode(encoded.bytes)
          ..['codecVersion'] = encoded.codecVersion
          ..['sampleCount'] = summary.sampleCount
          ..['startTimestamp'] = summary.startTimestamp
          ..['endTimestamp'] = summary.endTimestamp
          ..['maxDepth'] = summary.maxDepth
          ..['firstDepth'] = summary.firstDepth
          ..['lastDepth'] = summary.lastDepth
          ..['hasDecoType'] = summary.hasDecoType
          ..['hasDecoStop'] = summary.hasDecoStop
          ..['hasPositiveCeiling'] = summary.hasPositiveCeiling
          ..['hlc'] = Hlc(
            Hlc.parse(row['hlc'] as String).physicalTime + 60000,
            0,
            'peer-182',
          ).toString()
          ..['updatedAt'] = (row['updatedAt'] as int) + 60000;

        final data = SyncData(diveProfileSeries: [peerRow]);
        final payload = SyncPayload(
          version: syncFormatVersion,
          exportedAt: 9000,
          deviceId: 'peer-182',
          checksum: sha256
              .convert(utf8.encode(jsonEncode(data.toJson())))
              .toString(),
          data: data,
          deletions: const {},
        );
        await seedPeerBaseFromPayload(cloud, 'peer-182', payload);
        final result = await buildService().performSync();
        expect(result.status, isNot(SyncResultStatus.error));

        final profile = await DiveRepository().getDiveProfile(diveId);
        expect(profile.map((p) => p.depth), [1.0, 30.0]);
      },
    );
  });
}
