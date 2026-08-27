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
import '../../../helpers/sync_test_helpers.dart';
import '../../../helpers/test_database.dart';

/// Regression tests for the changeset-log flow's data-loss edges:
/// C1 (failed apply must not advance lastSync), M1 (a foreign peer is applied
/// regardless of cloud mtime), M6 (this device's own log is skipped by
/// identity).
void main() {
  group('Sync flow data-loss guards', () {
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

    test(
      'C1: a failed apply does not advance lastSync (so it is retried)',
      () async {
        final serializer = SyncDataSerializer();
        final diveRepo = DiveRepository();

        // Two dives so the export carries a good record alongside the bad one:
        // the good one applying must NOT let lastSync advance past the failure.
        await diveRepo.createDive(
          createTestDiveWithBottomTime(id: 'dive-ok', diveNumber: 1),
        );
        await diveRepo.createDive(
          createTestDiveWithBottomTime(id: 'dive-bad', diveNumber: 2),
        );

        // Export as a peer payload, corrupt a non-nullable field on one dive,
        // then recompute the checksum so it still passes transport validation:
        // the failure must surface at APPLY time, not as a transport error.
        final exported = await serializer.exportChangeset(
          deviceId: 'peer-corrupt',
          hlcWatermark: null,
          deletions: const [],
        );
        exported.data.dives.firstWhere(
          (d) => d['id'] == 'dive-bad',
        )['maxDepth'] = 'NOT_A_NUMBER';
        final corrupt = SyncPayload(
          version: exported.version,
          exportedAt: exported.exportedAt,
          deviceId: exported.deviceId,
          lastSyncTimestamp: exported.lastSyncTimestamp,
          checksum: sha256
              .convert(utf8.encode(jsonEncode(exported.data.toJson())))
              .toString(),
          data: exported.data,
          deletions: exported.deletions,
          toHlc: exported.toHlc,
        );

        // Fresh device B; seed the corrupt peer log; pull it.
        await diveRepo.deleteDive('dive-ok');
        await diveRepo.deleteDive('dive-bad');
        await impersonateFreshDevice();
        await seedPeerBaseFromPayload(cloud, 'peer-corrupt', corrupt);
        final result = await buildService().performSync();

        expect(result.status, SyncResultStatus.error);
        expect(
          await SyncRepository().getLastSyncTime(),
          isNull,
          reason:
              'lastSync must not advance when a record failed to apply, or '
              'the freshness/conflict window moves past it and it is lost',
        );
      },
    );

    test('M1: a foreign peer is applied regardless of cloud mtime', () async {
      // The changeset reader advances per-peer cursors and never consults
      // mtime, so a foreign peer must be applied even when local lastSync is
      // far newer than anything the cloud reports.
      final diveRepo = DiveRepository();
      await diveRepo.createDive(
        createTestDiveWithBottomTime(id: 'dive-mtime', diveNumber: 3),
      );
      await seedPeerLog(cloud, 'remote-dev');

      // lastSync far in the future; an mtime-based skip would have dropped the
      // peer. The changeset transport must apply it anyway.
      await setLastSync(DateTime.now().add(const Duration(days: 365)));

      await buildService().performSync();

      expect(
        await diveRepo.getDiveById('dive-mtime'),
        isNotNull,
        reason:
            'the foreign peer must still be applied; a mtime-based skip '
            'would have dropped it',
      );
    });

    test('M6: this device\'s own log is skipped by identity', () async {
      final diveRepo = DiveRepository();
      final myDeviceId = await SyncRepository().getDeviceId();

      // Publish a log under OUR OWN device id, then remove the dive locally.
      // The reader excludes the self log, so the pull must not resurrect it.
      await diveRepo.createDive(
        createTestDiveWithBottomTime(id: 'dive-self', diveNumber: 4),
      );
      await publishOwnLog(cloud, myDeviceId);
      await diveRepo.deleteDive('dive-self');
      expect(await diveRepo.getDiveById('dive-self'), isNull);

      final result = await buildService().performSync();
      expect(result.status, isNot(SyncResultStatus.error));

      expect(
        await diveRepo.getDiveById('dive-self'),
        isNull,
        reason: 'our own log must not be re-applied to us',
      );
    });
  });
}
