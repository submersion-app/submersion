import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/core/services/sync/sync_service.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';

import '../../../helpers/fake_cloud_storage_provider.dart';
import '../../../helpers/mock_providers.dart';
import '../../../helpers/test_database.dart';

/// Per-device sync files: each device writes its own
/// `submersion_sync_<deviceId>.json` and merges every other device's file on
/// read. This removes the single-shared-file write-write race (iCloud
/// "conflicted copy") that could silently drop a device's push.
void main() {
  group('Per-device sync files', () {
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

    /// Build a valid serialized payload file for [deviceId] carrying [dives].
    Future<Uint8List> craftDeviceFile(
      String deviceId,
      List<Map<String, dynamic>> dives,
    ) async {
      final data = SyncData(dives: dives);
      final checksum = sha256
          .convert(utf8.encode(jsonEncode(data.toJson())))
          .toString();
      final payload = SyncPayload(
        version: syncFormatVersion,
        exportedAt: 1700000000000,
        deviceId: deviceId,
        checksum: checksum,
        data: data,
        deletions: const {},
      );
      return Uint8List.fromList(
        utf8.encode(SyncDataSerializer().serializePayload(payload)),
      );
    }

    /// A valid dive JSON map (as produced by export) with the given id.
    Future<Map<String, dynamic>> validDiveMap(String id) async {
      final diveRepo = DiveRepository();
      await diveRepo.createDive(createTestDiveWithBottomTime(id: id));
      final exported = await SyncDataSerializer().exportData(
        deviceId: 'seed',
        deletions: const [],
      );
      final map = exported.data.dives.firstWhere((d) => d['id'] == id);
      await diveRepo.deleteDive(id);
      // Fully reset device sync state: createDive marked the record pending,
      // and _mergeEntity skips records in pendingRecordIds. resetSyncState
      // clears pending + conflict records, the deletion log, and lastSync so
      // the crafted device files apply cleanly.
      await SyncRepository().resetSyncState();
      return map;
    }

    test(
      'upload writes a per-device file, not the shared canonical file',
      () async {
        final diveRepo = DiveRepository();
        await diveRepo.createDive(
          createTestDiveWithBottomTime(id: 'dive-own-1'),
        );
        final deviceId = await SyncRepository().getDeviceId();

        await buildService().performSync();

        expect(
          cloud.bytesOf('submersion_sync_$deviceId.json'),
          isNotNull,
          reason: 'this device should write its own per-device file',
        );
        expect(
          cloud.bytesOf('submersion_sync.json'),
          isNull,
          reason:
              'the single shared canonical file must no longer be written '
              '(that is the source of the write-write race)',
        );
      },
    );

    test('pull applies every other device file in the folder', () async {
      final diveRepo = DiveRepository();
      // Distinct maxDepth per device so we verify the actual content merged,
      // not merely that a row exists (which one file alone could satisfy).
      final mapA = {...await validDiveMap('dive-from-A'), 'maxDepth': 11.0};
      final mapB = {...await validDiveMap('dive-from-B'), 'maxDepth': 22.0};

      await cloud.uploadFile(
        await craftDeviceFile('device-A', [mapA]),
        'submersion_sync_device-A.json',
      );
      await cloud.uploadFile(
        await craftDeviceFile('device-B', [mapB]),
        'submersion_sync_device-B.json',
      );

      final result = await buildService().performSync();
      expect(result.status, isNot(SyncResultStatus.error));

      final a = await diveRepo.getDiveById('dive-from-A');
      final b = await diveRepo.getDiveById('dive-from-B');
      expect(
        a?.maxDepth,
        11.0,
        reason: 'device A\'s file should be applied with its field values',
      );
      expect(
        b?.maxDepth,
        22.0,
        reason:
            'device B\'s file should also be applied (all files merge), '
            'proving both files were read, not just one',
      );
    });

    test('pull still applies a legacy shared submersion_sync.json', () async {
      final diveRepo = DiveRepository();
      final legacyMap = await validDiveMap('dive-legacy');

      await cloud.uploadFile(
        await craftDeviceFile('old-device', [legacyMap]),
        'submersion_sync.json',
      );

      final result = await buildService().performSync();
      expect(result.status, isNot(SyncResultStatus.error));

      expect(
        await diveRepo.getDiveById('dive-legacy'),
        isNotNull,
        reason: 'legacy single-file payloads must still import for back-compat',
      );
    });
  });
}
