import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/core/services/sync/sync_service.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';

import '../../../helpers/changeset_test_helpers.dart';
import '../../../helpers/fake_cloud_storage_provider.dart';
import '../../../helpers/mock_providers.dart';
import '../../../helpers/test_database.dart';

/// Round-trip tests for entities that were silently absent from SyncData.
///
/// Each is user data with FKs into an already-synced parent, but was never
/// being exported, so its contents never propagated A -> B. Same shape as
/// the courses oversight fixed earlier on this branch:
///   - DiveCustomFields: per-dive user-entered key/value fields
///   - SiteSpecies: user-curated expected species per dive site
///   - CsvPresets: saved CSV-import column maps
///   - ViewConfigs: per-diver/view-mode saved configurations
///   - FieldPresets: per-diver/view-mode saved field-mapping presets
///   - DiveDataSources: raw dive-data lineage (incl. fingerprint BLOBs)
void main() {
  group('Extra entities round-trip', () {
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

    Future<void> seedDiver(SyncDataSerializer serializer, String id) async {
      await serializer.upsertRecord('divers', {
        'id': id,
        'name': 'Test Diver',
        'medicalNotes': '',
        'notes': '',
        'isDefault': false,
        'createdAt': 1000,
        'updatedAt': 1000,
      });
    }

    Future<void> seedDiveSite(SyncDataSerializer serializer, String id) async {
      await serializer.upsertRecord('diveSites', {
        'id': id,
        'name': 'Test Site',
        'description': '',
        'notes': '',
        'isShared': false,
        'createdAt': 1000,
        'updatedAt': 1000,
      });
    }

    Future<void> seedSpecies(SyncDataSerializer serializer, String id) async {
      await serializer.upsertRecord('species', {
        'id': id,
        'commonName': 'Test Fish',
        'category': 'fish',
        'isBuiltIn': false,
      });
    }

    test('DiveCustomFields round-trips A -> B', () async {
      final serializer = SyncDataSerializer();
      final diveRepo = DiveRepository();

      await diveRepo.createDive(
        createTestDiveWithBottomTime(id: 'dive-cf-1', diveNumber: 101),
      );
      await serializer.upsertRecord('diveCustomFields', {
        'id': 'cf-1',
        'diveId': 'dive-cf-1',
        'fieldKey': 'visibility_m',
        'fieldValue': '20',
        'sortOrder': 0,
        'createdAt': 1000,
      });

      await seedPeerLog(cloud, 'device-a');
      expect(await serializer.fetchRecord('diveCustomFields', 'cf-1'), isNull);

      final pull = await buildService().performSync();
      expect(pull.status, isNot(SyncResultStatus.error));

      final restored = await serializer.fetchRecord('diveCustomFields', 'cf-1');
      expect(restored, isNotNull, reason: 'custom field must round-trip');
      expect(restored!['fieldKey'], 'visibility_m');
      expect(restored['fieldValue'], '20');
    });

    test('SiteSpecies round-trips A -> B', () async {
      final serializer = SyncDataSerializer();

      await seedDiveSite(serializer, 'site-ss-1');
      await seedSpecies(serializer, 'species-ss-1');
      await serializer.upsertRecord('siteSpecies', {
        'id': 'ss-1',
        'siteId': 'site-ss-1',
        'speciesId': 'species-ss-1',
        'notes': 'commonly seen on the wall',
        'createdAt': 1000,
      });

      await seedPeerLog(cloud, 'device-a');
      expect(await serializer.fetchRecord('siteSpecies', 'ss-1'), isNull);

      final pull = await buildService().performSync();
      expect(pull.status, isNot(SyncResultStatus.error));

      final restored = await serializer.fetchRecord('siteSpecies', 'ss-1');
      expect(restored, isNotNull, reason: 'site-species link must round-trip');
      expect(restored!['notes'], 'commonly seen on the wall');
    });

    test('CsvPresets round-trips A -> B', () async {
      final serializer = SyncDataSerializer();

      await serializer.upsertRecord('csvPresets', {
        'id': 'csv-1',
        'name': 'Suunto CSV',
        'presetJson': '{"columns":["date","depth"]}',
        'createdAt': 1000,
        'updatedAt': 1000,
      });

      await seedPeerLog(cloud, 'device-a');
      expect(await serializer.fetchRecord('csvPresets', 'csv-1'), isNull);

      final pull = await buildService().performSync();
      expect(pull.status, isNot(SyncResultStatus.error));

      final restored = await serializer.fetchRecord('csvPresets', 'csv-1');
      expect(restored, isNotNull);
      expect(restored!['name'], 'Suunto CSV');
      expect(restored['presetJson'], '{"columns":["date","depth"]}');
    });

    test('ViewConfigs round-trips A -> B', () async {
      final serializer = SyncDataSerializer();

      await seedDiver(serializer, 'diver-vc-1');
      await serializer.upsertRecord('viewConfigs', {
        'id': 'vc-1',
        'diverId': 'diver-vc-1',
        'viewMode': 'table',
        'configJson': '{"columns":["date","depth","duration"]}',
        'updatedAt': 1000,
      });

      await seedPeerLog(cloud, 'device-a');
      expect(await serializer.fetchRecord('viewConfigs', 'vc-1'), isNull);

      final pull = await buildService().performSync();
      expect(pull.status, isNot(SyncResultStatus.error));

      final restored = await serializer.fetchRecord('viewConfigs', 'vc-1');
      expect(restored, isNotNull);
      expect(restored!['viewMode'], 'table');
    });

    test('FieldPresets round-trips A -> B', () async {
      final serializer = SyncDataSerializer();

      await seedDiver(serializer, 'diver-fp-1');
      await serializer.upsertRecord('fieldPresets', {
        'id': 'fp-1',
        'diverId': 'diver-fp-1',
        'viewMode': 'table',
        'name': 'My Tech Layout',
        'configJson': '{"fields":["max_depth","cns"]}',
        'isBuiltIn': false,
        'createdAt': 1000,
      });

      await seedPeerLog(cloud, 'device-a');
      expect(await serializer.fetchRecord('fieldPresets', 'fp-1'), isNull);

      final pull = await buildService().performSync();
      expect(pull.status, isNot(SyncResultStatus.error));

      final restored = await serializer.fetchRecord('fieldPresets', 'fp-1');
      expect(restored, isNotNull);
      expect(restored!['name'], 'My Tech Layout');
    });

    test(
      'DiveDataSources round-trips A -> B including raw BLOB fingerprint',
      () async {
        final serializer = SyncDataSerializer();
        final diveRepo = DiveRepository();

        await diveRepo.createDive(
          createTestDiveWithBottomTime(id: 'dive-ds-1', diveNumber: 102),
        );
        final fingerprint = Uint8List.fromList([0x01, 0x02, 0x03, 0xFE, 0xFF]);
        await serializer.upsertRecord('diveDataSources', {
          'id': 'ds-1',
          'diveId': 'dive-ds-1',
          'isPrimary': true,
          'sourceFormat': 'shearwater',
          'importedAt': 1700000000000,
          'createdAt': 1700000000000,
          'rawFingerprint': fingerprint,
          // Consolidation's time re-base (#1177). It cannot be recovered from
          // the raw bytes, so a peer that loses it re-parses the folded-in
          // strand onto the wrong clock.
          'timeOffsetSeconds': 60,
        });

        await seedPeerLog(cloud, 'device-a');
        expect(await serializer.fetchRecord('diveDataSources', 'ds-1'), isNull);

        final pull = await buildService().performSync();
        expect(pull.status, isNot(SyncResultStatus.error));

        final restored = await serializer.fetchRecord(
          'diveDataSources',
          'ds-1',
        );
        expect(
          restored,
          isNotNull,
          reason: 'data-source row (with BLOB) must round-trip',
        );
        expect(restored!['sourceFormat'], 'shearwater');
        expect(restored['timeOffsetSeconds'], 60);

        // BLOB survives the JSON round-trip. The sync layer encodes BLOBs as
        // base64 strings (see sync_blob_base64_test.dart); fetchRecord decodes
        // them back to a Uint8List. Accept any of the shapes defensively.
        final restoredBlob = restored['rawFingerprint'];
        expect(restoredBlob, isNotNull);
        final List<int> restoredBytes;
        if (restoredBlob is Uint8List) {
          restoredBytes = restoredBlob.toList();
        } else if (restoredBlob is String) {
          restoredBytes = base64Decode(restoredBlob);
        } else {
          restoredBytes = (restoredBlob as List).cast<int>();
        }
        expect(restoredBytes, [0x01, 0x02, 0x03, 0xFE, 0xFF]);
      },
    );

    test('a DiveDataSources payload from a pre-v159 peer, with no '
        'timeOffsetSeconds key at all, still applies (#1177)', () async {
      final serializer = SyncDataSerializer();
      final diveRepo = DiveRepository();

      await diveRepo.createDive(
        createTestDiveWithBottomTime(id: 'dive-ds-2', diveNumber: 103),
      );

      // Older writers do not know the column exists. The receiving side
      // must read that as "no offset", not reject the row.
      await serializer.upsertRecord('diveDataSources', {
        'id': 'ds-2',
        'diveId': 'dive-ds-2',
        'isPrimary': true,
        'sourceFormat': 'shearwater',
        'importedAt': 1700000000000,
        'createdAt': 1700000000000,
      });

      final stored = await serializer.fetchRecord('diveDataSources', 'ds-2');
      expect(stored, isNotNull);
      expect(stored!['timeOffsetSeconds'], isNull);
    });
  });
}
