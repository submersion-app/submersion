import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/core/services/sync/sync_record_overlay.dart';
import 'package:submersion/core/services/sync/sync_service.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';

import '../../../helpers/changeset_test_helpers.dart';
import '../../../helpers/fake_cloud_storage_provider.dart';
import '../../../helpers/mock_providers.dart';
import '../../../helpers/test_database.dart';

/// Tests for the BLOB-as-base64 sync encoding (vs Drift's default
/// array-of-bytes), and the non-breaking acceptance of the legacy format.
void main() {
  group('Sync BLOB base64 encoding', () {
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
      'a BLOB is encoded as a base64 string in the exported payload',
      () async {
        final serializer = SyncDataSerializer();
        final diveRepo = DiveRepository();

        await diveRepo.createDive(
          createTestDiveWithBottomTime(id: 'dive-b64-1', diveNumber: 201),
        );
        final fingerprint = Uint8List.fromList([0x10, 0x20, 0x30, 0xAB, 0xCD]);
        await serializer.upsertRecord('diveDataSources', {
          'id': 'ds-b64-1',
          'diveId': 'dive-b64-1',
          'isPrimary': true,
          'importedAt': 1700000000000,
          'createdAt': 1700000000000,
          'rawFingerprint': fingerprint,
        });

        final deviceId = await SyncRepository().getDeviceId();
        await buildService().performSync();

        final payload = await cloudBasePayload(cloud, deviceId);
        final row = payload!.data.diveDataSources.firstWhere(
          (r) => r['id'] == 'ds-b64-1',
        );

        // The wire format must be a base64 String, not a JSON array of ints.
        expect(
          row['rawFingerprint'],
          isA<String>(),
          reason: 'BLOB should serialize as a base64 string, not a byte array',
        );
        expect(row['rawFingerprint'], base64Encode(fingerprint));
      },
    );

    test('a legacy array-encoded BLOB payload still imports', () async {
      final serializer = SyncDataSerializer();
      final diveRepo = DiveRepository();

      // Build a dive locally so the FK target exists on import.
      await diveRepo.createDive(
        createTestDiveWithBottomTime(id: 'dive-legacy-1', diveNumber: 202),
      );

      // Simulate a payload produced by the OLD serializer: rawFingerprint as a
      // JSON array of byte ints. upsertRecord must still accept it.
      await serializer.upsertRecord('diveDataSources', {
        'id': 'ds-legacy-1',
        'diveId': 'dive-legacy-1',
        'isPrimary': false,
        'importedAt': 1700000000000,
        'createdAt': 1700000000000,
        'rawFingerprint': [0x01, 0x02, 0x03],
      });

      final restored = await serializer.fetchRecord(
        'diveDataSources',
        'ds-legacy-1',
      );
      expect(restored, isNotNull);
      // After import + re-fetch it should be the same bytes, regardless of the
      // wire format it arrived in.
      final blob = restored!['rawFingerprint'];
      final bytes = blob is String
          ? base64Decode(blob)
          : Uint8List.fromList((blob as List).cast<int>());
      expect(bytes, [0x01, 0x02, 0x03]);
    });

    test('a null BLOB round-trips as null (no spurious empty bytes)', () async {
      final serializer = SyncDataSerializer();
      final diveRepo = DiveRepository();
      await diveRepo.createDive(
        createTestDiveWithBottomTime(id: 'dive-nullblob', diveNumber: 203),
      );
      await serializer.upsertRecord('diveDataSources', {
        'id': 'ds-null',
        'diveId': 'dive-nullblob',
        'isPrimary': false,
        'importedAt': 1700000000000,
        'createdAt': 1700000000000,
        'rawFingerprint': null,
      });

      final deviceId = await SyncRepository().getDeviceId();
      await buildService().performSync();
      final payload = await cloudBasePayload(cloud, deviceId);
      final row = payload!.data.diveDataSources.firstWhere(
        (r) => r['id'] == 'ds-null',
      );
      expect(
        row['rawFingerprint'],
        isNull,
        reason: 'a null BLOB must export as null, not "" or []',
      );
    });

    test('a large BLOB survives the base64 round-trip intact', () async {
      final serializer = SyncDataSerializer();
      final diveRepo = DiveRepository();
      await diveRepo.createDive(
        createTestDiveWithBottomTime(id: 'dive-bigblob', diveNumber: 204),
      );
      // 16 KB with every byte value cycling, to catch any encoding truncation.
      final big = Uint8List.fromList(List.generate(16384, (i) => i % 256));
      await serializer.upsertRecord('diveDataSources', {
        'id': 'ds-big',
        'diveId': 'dive-bigblob',
        'isPrimary': false,
        'importedAt': 1700000000000,
        'createdAt': 1700000000000,
        'rawFingerprint': big,
      });

      final restored = await serializer.fetchRecord(
        'diveDataSources',
        'ds-big',
      );
      final blob = restored!['rawFingerprint'];
      final bytes = blob is String
          ? base64Decode(blob)
          : Uint8List.fromList((blob as List).cast<int>());
      expect(
        bytes,
        big,
        reason: 'a large BLOB must not be truncated/corrupted',
      );
    });

    test('a buddy photo is exported as a base64 string', () async {
      final serializer = SyncDataSerializer();
      final photo = Uint8List.fromList(List.generate(256, (i) => i % 256));

      await serializer.upsertRecord('buddies', {
        'id': 'buddy-b64-1',
        'name': 'Jane Doe',
        'notes': '',
        'isFavorite': false,
        'createdAt': 1700000000000,
        'updatedAt': 1700000000000,
        'photo': photo,
      });

      final deviceId = await SyncRepository().getDeviceId();
      await buildService().performSync();

      final payload = await cloudBasePayload(cloud, deviceId);
      final row = payload!.data.buddies.firstWhere(
        (r) => r['id'] == 'buddy-b64-1',
      );

      expect(
        row['photo'],
        isA<String>(),
        reason: 'a buddy photo must serialize as base64, not a byte array',
      );
      expect(row['photo'], base64Encode(photo));
    });

    test('a diver photo round-trips through fetchRecord', () async {
      final serializer = SyncDataSerializer();
      final photo = Uint8List.fromList(
        List.generate(128, (i) => 255 - i % 256),
      );

      await serializer.upsertRecord('divers', {
        'id': 'diver-b64-1',
        'name': 'Jane Doe',
        'medicalNotes': '',
        'notes': '',
        'isDefault': false,
        'createdAt': 1700000000000,
        'updatedAt': 1700000000000,
        'photo': photo,
      });

      final restored = await serializer.fetchRecord('divers', 'diver-b64-1');
      expect(restored, isNotNull);
      final blob = restored!['photo'];
      final bytes = blob is String
          ? base64Decode(blob)
          : Uint8List.fromList((blob as List).cast<int>());
      expect(bytes, photo);
    });

    test('a legacy array-encoded buddy photo still imports', () async {
      final serializer = SyncDataSerializer();
      await serializer.upsertRecord('buddies', {
        'id': 'buddy-legacy-1',
        'name': 'Jane Doe',
        'notes': '',
        'isFavorite': false,
        'createdAt': 1700000000000,
        'updatedAt': 1700000000000,
        'photo': [0x01, 0x02, 0x03],
      });

      final restored = await serializer.fetchRecord(
        'buddies',
        'buddy-legacy-1',
      );
      final blob = restored!['photo'];
      final bytes = blob is String
          ? base64Decode(blob)
          : Uint8List.fromList((blob as List).cast<int>());
      expect(bytes, [0x01, 0x02, 0x03]);
    });

    test('a null buddy photo exports as null', () async {
      final serializer = SyncDataSerializer();
      await serializer.upsertRecord('buddies', {
        'id': 'buddy-nullphoto',
        'name': 'Jane Doe',
        'notes': '',
        'isFavorite': false,
        'createdAt': 1700000000000,
        'updatedAt': 1700000000000,
        'photo': null,
      });

      final deviceId = await SyncRepository().getDeviceId();
      await buildService().performSync();
      final payload = await cloudBasePayload(cloud, deviceId);
      final row = payload!.data.buddies.firstWhere(
        (r) => r['id'] == 'buddy-nullphoto',
      );
      expect(row['photo'], isNull);
    });
    Map<String, dynamic> centerRecord(String id, {Object? logo}) => {
      'id': id,
      'name': 'Blue Reef',
      'notes': '',
      'isPermanentlyClosed': false,
      'createdAt': 1700000000000,
      'updatedAt': 1700000000000,
      'logo': logo,
    };

    Uint8List blobOf(Object? value) => value is String
        ? base64Decode(value)
        : Uint8List.fromList((value as List).cast<int>());

    test('a dive center logo is exported as a base64 string', () async {
      final serializer = SyncDataSerializer();
      final logo = Uint8List.fromList(List.generate(200, (i) => i % 256));
      await serializer.upsertRecord(
        'diveCenters',
        centerRecord('center-b64-1', logo: logo),
      );

      final deviceId = await SyncRepository().getDeviceId();
      await buildService().performSync();

      final payload = await cloudBasePayload(cloud, deviceId);
      final row = payload!.data.diveCenters.firstWhere(
        (r) => r['id'] == 'center-b64-1',
      );
      expect(
        row['logo'],
        base64Encode(logo),
        reason: 'a center logo must serialize as base64, not a byte array',
      );
    });

    test('a dive center logo round-trips through fetchRecord', () async {
      final serializer = SyncDataSerializer();
      final logo = Uint8List.fromList(List.generate(64, (i) => 200 - i));
      await serializer.upsertRecord(
        'diveCenters',
        centerRecord('center-b64-2', logo: logo),
      );

      final restored = await serializer.fetchRecord(
        'diveCenters',
        'center-b64-2',
      );
      expect(restored!['logo'], isA<String>());
      expect(blobOf(restored['logo']), logo);
    });

    test('dive center logos are base64 in a batch fetch', () async {
      final serializer = SyncDataSerializer();
      final logo = Uint8List.fromList([5, 6, 7]);
      await serializer.upsertRecord(
        'diveCenters',
        centerRecord('center-b64-3', logo: logo),
      );

      final rows = await serializer.fetchRecords('diveCenters', [
        'center-b64-3',
      ]);
      expect(rows['center-b64-3']!['logo'], base64Encode(logo));
    });

    test('a batch of dive centers applies base64 logos', () async {
      final serializer = SyncDataSerializer();
      final logo = Uint8List.fromList([8, 9, 10]);
      await serializer.upsertRecords('diveCenters', [
        centerRecord('center-b64-4', logo: base64Encode(logo)),
      ]);

      final restored = await serializer.fetchRecord(
        'diveCenters',
        'center-b64-4',
      );
      expect(blobOf(restored!['logo']), logo);
    });

    test('a legacy array-encoded center logo still imports', () async {
      final serializer = SyncDataSerializer();
      await serializer.upsertRecord(
        'diveCenters',
        centerRecord('center-legacy-1', logo: [0x01, 0x02, 0x03]),
      );

      final restored = await serializer.fetchRecord(
        'diveCenters',
        'center-legacy-1',
      );
      expect(blobOf(restored!['logo']), [0x01, 0x02, 0x03]);
    });

    test(
      "an older peer's center row without a logo keeps the local logo",
      () async {
        final serializer = SyncDataSerializer();
        final logo = Uint8List.fromList([4, 4, 4]);
        await serializer.upsertRecord(
          'diveCenters',
          centerRecord('center-old-peer', logo: logo),
        );

        // A peer below v373 knows no logo column, so its row omits the key.
        final remote = centerRecord('center-old-peer')
          ..remove('logo')
          ..['name'] = 'Blue Reef Divers';
        final merged = overlayOntoLocal(
          'diveCenters',
          remote,
          await serializer.fetchRecord('diveCenters', 'center-old-peer'),
        );
        await serializer.upsertRecord('diveCenters', merged);

        final restored = await serializer.fetchRecord(
          'diveCenters',
          'center-old-peer',
        );
        expect(restored!['name'], 'Blue Reef Divers');
        expect(blobOf(restored['logo']), logo);
      },
    );
  });
}
