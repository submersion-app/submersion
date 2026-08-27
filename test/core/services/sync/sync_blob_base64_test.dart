import 'dart:convert';
import 'dart:typed_data';

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
  });
}
