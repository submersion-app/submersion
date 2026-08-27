import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/core/services/sync/sync_service.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/settings/presentation/providers/sync_providers.dart';

import '../../../helpers/changeset_test_helpers.dart';
import '../../../helpers/fake_cloud_storage_provider.dart';
import '../../../helpers/mock_providers.dart';
import '../../../helpers/test_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SyncRepository repository;

  setUp(() async {
    await setUpTestDatabase();
    SharedPreferences.setMockInitialValues({});
    repository = SyncRepository();
  });

  tearDown(() {
    DatabaseService.instance.resetForTesting();
  });

  group('reset and the deletion log', () {
    test('user-facing reset keeps the deletion log', () async {
      await repository.logDeletion(entityType: 'dives', recordId: 'gone-1');
      final service = SyncService(
        syncRepository: repository,
        serializer: SyncDataSerializer(),
      );

      await service.resetSyncState();

      expect(
        await repository.getAllDeletions(),
        isNotEmpty,
        reason:
            'reset wipes the sync baseline, not data history: without the '
            'tombstones, the first post-reset sync re-inserts every record '
            'a stale peer file still holds live',
      );
      expect(await repository.getLastSyncTime(), isNull);
    });

    test('repository reset clears the deletion log by default', () async {
      // rebaselineAfterRestore and impersonateFreshDevice rely on the
      // historical full-wipe semantics.
      await repository.logDeletion(entityType: 'dives', recordId: 'gone-2');

      await repository.resetSyncState();

      expect(await repository.getAllDeletions(), isEmpty);
    });

    test(
      'post-reset merge does not resurrect a locally deleted record',
      () async {
        // A stale peer file still holds dive 'deleted-1' live. The user
        // deleted it locally (tombstone), then ran Reset Sync State. Because
        // reset now keeps the deletion log, the null-baseline merge must NOT
        // re-insert the record.
        final cloud = FakeCloudStorageProvider();
        final diveRepo = DiveRepository();
        await diveRepo.createDive(
          createTestDiveWithBottomTime(id: 'deleted-1'),
        );
        final exported = await SyncDataSerializer().exportData(
          deviceId: 'seed',
          deletions: const [],
        );
        final staleDive = exported.data.dives.firstWhere(
          (d) => d['id'] == 'deleted-1',
        );
        await diveRepo.deleteDive('deleted-1');

        // Stale peer file carrying the deleted dive as a live row.
        final data = SyncData(dives: [staleDive]);
        final checksum = sha256
            .convert(utf8.encode(jsonEncode(data.toJson())))
            .toString();
        final payload = SyncPayload(
          version: syncFormatVersion,
          exportedAt: 1700000000000,
          deviceId: 'stale-peer',
          checksum: checksum,
          data: data,
          deletions: const {},
        );
        await seedPeerBaseFromPayload(cloud, 'stale-peer', payload);

        final service = SyncService(
          syncRepository: repository,
          serializer: SyncDataSerializer(),
          cloudProvider: cloud,
        );
        await service.resetSyncState();
        final result = await service.performSync();

        expect(result.isSuccess, isTrue);
        expect(
          await diveRepo.getDiveById('deleted-1'),
          isNull,
          reason:
              'the kept tombstone must guard the null-baseline merge against '
              'the stale peer file',
        );
      },
    );
  });

  group('SyncNotifier.resetSyncState cloud cleanup', () {
    test(
      'retires the old changeset log when adopting a new identity',
      () async {
        final cloud = FakeCloudStorageProvider();
        final oldId = await repository.getDeviceId();
        await seedPeerManifest(cloud, oldId);
        await seedPeerManifest(cloud, 'peer-device');

        final prefs = await SharedPreferences.getInstance();
        final container = ProviderContainer(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            cloudStorageProviderProvider.overrideWithValue(cloud),
          ],
        );
        addTearDown(container.dispose);

        await container.read(syncStateProvider.notifier).resetSyncState();

        expect(await repository.getDeviceId(), isNot(oldId));
        expect(
          await hasPublishedLog(cloud, oldId),
          isFalse,
          reason:
              'after the identity changes, the old log is no longer excluded '
              'as "our own" -- left in place this device would merge its own '
              'abandoned base as a peer forever',
        );
        expect(
          await hasPublishedLog(cloud, 'peer-device'),
          isTrue,
          reason: 'only the retired identity\'s own log may be deleted',
        );
      },
    );

    test('reset succeeds even when the cloud delete fails', () async {
      final cloud = FakeCloudStorageProvider()..failDeletes = true;
      final oldId = await repository.getDeviceId();
      await seedPeerManifest(cloud, oldId);

      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          cloudStorageProviderProvider.overrideWithValue(cloud),
        ],
      );
      addTearDown(container.dispose);

      await container.read(syncStateProvider.notifier).resetSyncState();

      expect(
        await repository.getDeviceId(),
        isNot(oldId),
        reason: 'cloud cleanup is best-effort; reset must not depend on it',
      );
    });
  });
}
