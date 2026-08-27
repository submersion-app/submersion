import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/post_restore_sync_store.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/core/services/sync/sync_service.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/settings/presentation/providers/sync_providers.dart';

import '../../../helpers/fake_cloud_storage_provider.dart';
import '../../../helpers/mock_providers.dart';
import '../../../helpers/test_database.dart';
import '../../../helpers/wait_until.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'a pending post-restore intent converges with a peer on launch, no manual '
    'Sync Now',
    () async {
      final cloud = FakeCloudStorageProvider();

      // Device A: create a dive and publish it to the shared cloud.
      await setUpTestDatabase();
      final svcA = SyncService(
        syncRepository: SyncRepository(),
        serializer: SyncDataSerializer(),
        cloudProvider: cloud,
      );
      await DiveRepository().createDive(
        createTestDiveWithBottomTime(id: 'a1', diveNumber: 1),
      );
      expect((await svcA.performSync()).status, SyncResultStatus.success);
      await tearDownTestDatabase();

      // Device B: fresh DB with a pending post-restore intent (as if just
      // restored). No auto-sync triggers are wired here; only _initialize's
      // forced, gate-bypassing sync runs.
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await PostRestoreSyncStore(prefs).setPending();
      await setUpTestDatabase();
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          cloudStorageProviderProvider.overrideWithValue(cloud),
        ],
      );
      addTearDown(container.dispose);

      // Constructing the notifier runs _initialize, which consumes the intent.
      container.read(syncStateProvider);
      // Poll for the pulled row instead of a fixed sleep (CI-robust).
      await waitUntil(
        () async =>
            (await DatabaseService.instance.database
                .customSelect("SELECT id FROM dives WHERE id = 'a1'")
                .getSingleOrNull()) !=
            null,
      );

      final row = await DatabaseService.instance.database
          .customSelect("SELECT id FROM dives WHERE id = 'a1'")
          .getSingleOrNull();
      expect(
        row,
        isNotNull,
        reason:
            'device B must converge with A via the forced post-restore sync, '
            'without a manual Sync Now',
      );
      await tearDownTestDatabase();
    },
  );
}
