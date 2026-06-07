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
import '../../../helpers/sync_test_helpers.dart';
import '../../../helpers/test_database.dart';

/// Regression tests for the per-device-file flow's data-loss edges:
/// C1 (failed apply must not advance lastSync), M1 (no unreliable mtime skip),
/// M6 (own-device payloads are skipped by identity).
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

    Future<Map<String, dynamic>> baseDiveMap(String id) async {
      final diveRepo = DiveRepository();
      await diveRepo.createDive(createTestDiveWithBottomTime(id: id));
      final exported = await SyncDataSerializer().exportData(
        deviceId: 'seed',
        deletions: const [],
      );
      final map = Map<String, dynamic>.from(
        exported.data.dives.firstWhere((d) => d['id'] == id),
      );
      await diveRepo.deleteDive(id);
      await SyncRepository().resetSyncState();
      return map;
    }

    Future<void> uploadFile(
      String name,
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
      await cloud.uploadFile(
        Uint8List.fromList(
          utf8.encode(SyncDataSerializer().serializePayload(payload)),
        ),
        name,
      );
    }

    test(
      'C1: a failed apply does not advance lastSync (so it is retried)',
      () async {
        final base = await baseDiveMap('dive-ok');
        final goodDive = {...base, 'id': 'dive-ok'};
        final corruptDive = {
          ...base,
          'id': 'dive-bad',
          'maxDepth': 'NOT_A_NUMBER',
        };
        await uploadFile('submersion_sync_remote.json', 'remote-dev', [
          goodDive,
          corruptDive,
        ]);

        await impersonateFreshDevice();
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

    test('M1: a foreign file is applied even if its mtime is older than '
        'lastSync (mtime is unreliable on iCloud)', () async {
      final base = await baseDiveMap('dive-mtime');
      await uploadFile('submersion_sync_remote.json', 'remote-dev', [
        {...base, 'id': 'dive-mtime'},
      ]);

      await impersonateFreshDevice();
      // lastSync far in the future; the foreign file's mtime (now) is older.
      await setLastSync(DateTime.now().add(const Duration(days: 365)));

      await buildService().performSync();

      expect(
        await DiveRepository().getDiveById('dive-mtime'),
        isNotNull,
        reason:
            'the foreign file must still be applied; a mtime-based skip '
            'would have dropped it',
      );
    });

    test(
      'M6: a payload authored by THIS device is skipped by identity',
      () async {
        final base = await baseDiveMap('dive-self');
        final myDeviceId = await SyncRepository().getDeviceId();

        // A legacy-named file whose payload claims OUR device id.
        await uploadFile('submersion_sync.json', myDeviceId, [
          {...base, 'id': 'dive-self'},
        ]);

        final result = await buildService().performSync();
        expect(result.status, isNot(SyncResultStatus.error));

        expect(
          await DiveRepository().getDiveById('dive-self'),
          isNull,
          reason: 'our own payload (any filename) must not be re-applied to us',
        );
      },
    );
  });
}
