import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_clock.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/core/services/sync/sync_service.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';

import '../../../helpers/fake_cloud_storage_provider.dart';
import '../../../helpers/mock_providers.dart';
import '../../../helpers/sync_test_helpers.dart';
import '../../../helpers/test_database.dart';

/// The Hybrid Logical Clock drives cross-device conflict resolution: when both
/// the local and remote copies of a record carry an HLC, the higher HLC wins
/// regardless of wall-clock `updatedAt`. This is the clock-skew fix.
void main() {
  group('HLC-driven merge', () {
    late FakeCloudStorageProvider cloud;

    setUp(() async {
      await setUpTestDatabase();
      cloud = FakeCloudStorageProvider();
    });

    tearDown(() {
      SyncClock.instance.reset();
      DatabaseService.instance.resetForTesting();
    });

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

    Future<void> uploadDeviceFile(
      String deviceId,
      Map<String, dynamic> diveMap,
    ) async {
      final data = SyncData(dives: [diveMap]);
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
        'submersion_sync_$deviceId.json',
      );
    }

    // Hlc string with a given physical-time component (counter 0).
    String hlcAt(int physical, String node) =>
        '${physical.toString().padLeft(15, '0')}:000000:$node';

    test(
      'remote wins when its HLC is higher even though its updatedAt is lower '
      '(clock-skew fix)',
      () async {
        final serializer = SyncDataSerializer();
        final diveRepo = DiveRepository();
        final base = await baseDiveMap('dive-skew');

        // Local copy: NEWER wall clock (updatedAt 5000) but an OLDER logical
        // clock (HLC physical 1000). maxDepth 10.
        await serializer.upsertRecord('dives', {
          ...base,
          'maxDepth': 10.0,
          'updatedAt': 5000,
          'hlc': hlcAt(1000, 'local'),
        });

        // Remote copy: OLDER wall clock (updatedAt 2000) but a NEWER logical
        // clock (HLC physical 9000) -- this is the genuinely-later edit made on
        // a device whose wall clock was behind. maxDepth 99.
        await uploadDeviceFile('remote-dev', {
          ...base,
          'maxDepth': 99.0,
          'updatedAt': 2000,
          'hlc': hlcAt(9000, 'remote-dev'),
        });

        await impersonateFreshDevice();
        final result = await buildService().performSync();
        expect(result.status, isNot(SyncResultStatus.error));

        final restored = await diveRepo.getDiveById('dive-skew');
        expect(
          restored!.maxDepth,
          99.0,
          reason:
              'higher HLC must win even though its updatedAt is lower; '
              'updatedAt-only ordering would have wrongly kept the local copy',
        );
      },
    );

    test('local wins when its HLC is higher than the remote', () async {
      final serializer = SyncDataSerializer();
      final diveRepo = DiveRepository();
      final base = await baseDiveMap('dive-localwin');

      await serializer.upsertRecord('dives', {
        ...base,
        'maxDepth': 42.0,
        'updatedAt': 2000,
        'hlc': hlcAt(9000, 'local'),
      });
      await uploadDeviceFile('remote-dev', {
        ...base,
        'maxDepth': 7.0,
        'updatedAt': 5000, // higher wall clock...
        'hlc': hlcAt(1000, 'remote-dev'), // ...but lower logical clock
      });

      await impersonateFreshDevice();
      await buildService().performSync();

      final restored = await diveRepo.getDiveById('dive-localwin');
      expect(
        restored!.maxDepth,
        42.0,
        reason: 'local higher HLC must be preserved against a lower remote HLC',
      );
    });

    test('HLC resolves a concurrent edit (both edited since last sync) instead '
        'of flagging a conflict', () async {
      final serializer = SyncDataSerializer();
      final diveRepo = DiveRepository();
      final base = await baseDiveMap('dive-concurrent');

      // Local: edited at updatedAt 5000 with a LOWER hlc.
      await serializer.upsertRecord('dives', {
        ...base,
        'maxDepth': 10.0,
        'updatedAt': 5000,
        'hlc': hlcAt(1000, 'local'),
      });
      // Remote: also edited since last sync (updatedAt 6000) with a HIGHER
      // hlc. Both > lastSync, so the legacy path would mark a conflict.
      await uploadDeviceFile('remote-dev', {
        ...base,
        'maxDepth': 99.0,
        'updatedAt': 6000,
        'hlc': hlcAt(9000, 'remote-dev'),
      });

      await impersonateFreshDevice();
      await setLastSync(DateTime.fromMillisecondsSinceEpoch(4000));
      final result = await buildService().performSync();

      expect(
        result.conflictsFound,
        0,
        reason:
            'when both sides carry an HLC, it resolves the edit; no '
            'manual conflict should be raised',
      );
      final restored = await diveRepo.getDiveById('dive-concurrent');
      expect(
        restored!.maxDepth,
        99.0,
        reason: 'higher HLC wins the concurrent edit',
      );
    });

    test(
      'still raises a conflict for a concurrent edit when NEITHER side has an '
      'HLC (pre-rollout rows)',
      () async {
        final serializer = SyncDataSerializer();
        final diveRepo = DiveRepository();
        final base = await baseDiveMap('dive-nohlc-conflict');

        await serializer.upsertRecord('dives', {
          ...base,
          'maxDepth': 10.0,
          'updatedAt': 5000,
          'hlc': null,
        });
        await uploadDeviceFile('remote-dev', {
          ...base,
          'maxDepth': 99.0,
          'updatedAt': 6000,
          'hlc': null,
        });

        await impersonateFreshDevice();
        await setLastSync(DateTime.fromMillisecondsSinceEpoch(4000));
        final result = await buildService().performSync();

        expect(
          result.conflictsFound,
          greaterThan(0),
          reason:
              'without HLCs, a both-edited-since-last-sync case is still a '
              'conflict (updatedAt fallback)',
        );
        final restored = await diveRepo.getDiveById('dive-nohlc-conflict');
        expect(
          restored!.maxDepth,
          10.0,
          reason:
              'a conflict is not auto-applied; local is kept pending review',
        );
      },
    );

    test(
      'an exact HLC tie keeps the local record (does not overwrite)',
      () async {
        final serializer = SyncDataSerializer();
        final diveRepo = DiveRepository();
        final base = await baseDiveMap('dive-tie');

        const tie = '000000000005000:000000:same-node';
        await serializer.upsertRecord('dives', {
          ...base,
          'maxDepth': 10.0,
          'updatedAt': 1000,
          'hlc': tie,
        });
        await uploadDeviceFile('remote-dev', {
          ...base,
          'maxDepth': 99.0,
          'updatedAt': 2000,
          'hlc': tie,
        });

        await impersonateFreshDevice();
        await buildService().performSync();

        final restored = await diveRepo.getDiveById('dive-tie');
        expect(
          restored!.maxDepth,
          10.0,
          reason: 'an exact HLC tie must not silently overwrite the local row',
        );
      },
    );

    test(
      'falls back to updatedAt when an HLC is absent on either side',
      () async {
        final serializer = SyncDataSerializer();
        final diveRepo = DiveRepository();
        final base = await baseDiveMap('dive-fallback');

        // Local has no HLC (pre-rollout row); remote has a newer updatedAt.
        await serializer.upsertRecord('dives', {
          ...base,
          'maxDepth': 10.0,
          'updatedAt': 1000,
          'hlc': null,
        });
        await uploadDeviceFile('remote-dev', {
          ...base,
          'maxDepth': 55.0,
          'updatedAt': 9000,
          'hlc': null,
        });

        await impersonateFreshDevice();
        await buildService().performSync();

        final restored = await diveRepo.getDiveById('dive-fallback');
        expect(
          restored!.maxDepth,
          55.0,
          reason: 'with no HLC on either side, the newer updatedAt wins',
        );
      },
    );
  });
}
