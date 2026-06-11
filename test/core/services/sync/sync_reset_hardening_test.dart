import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/core/services/sync/sync_service.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/settings/presentation/providers/sync_providers.dart';

import '../../../helpers/fake_cloud_storage_provider.dart';
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
  });

  group('SyncNotifier.resetSyncState cloud cleanup', () {
    test(
      'retires the old per-device file when adopting a new identity',
      () async {
        final cloud = FakeCloudStorageProvider();
        final oldId = await repository.getDeviceId();
        final oldFile = 'submersion_sync_$oldId.json';
        cloud.seedFile(oldFile, Uint8List.fromList([1, 2, 3]));

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
          await cloud.fileExists(oldFile),
          isFalse,
          reason:
              'after the identity changes, the old file is no longer excluded '
              'as "our own" -- left in place this device would merge its own '
              'abandoned snapshot as a peer forever',
        );
      },
    );

    test('reset succeeds even when the cloud delete fails', () async {
      final cloud = FakeCloudStorageProvider()..failDeletes = true;
      final oldId = await repository.getDeviceId();
      cloud.seedFile(
        'submersion_sync_$oldId.json',
        Uint8List.fromList([1, 2, 3]),
      );

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
