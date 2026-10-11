import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart'
    hide SyncStatus;
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/features/media/presentation/providers/gallery_origin_backfill_provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/settings/presentation/providers/sync_providers.dart';

import '../../../../helpers/fake_cloud_storage_provider.dart';
import '../../../../helpers/test_database.dart';

/// Issue #3265: a sync reported success, then showed ~20 unsynced items that
/// another Sync press did not clear until the app was restarted.
///
/// The post-sync work (equipment findings, GPS stamps, gallery origin stamps)
/// runs after the publish, so whatever it marks pending is left for the next
/// sync. That work also runs inside the sync's single flight, and a press
/// landing there used to be dropped without a word, so "press Sync again" did
/// nothing. The gallery backfill override stands in for that post-sync work.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    await setUpTestDatabase();
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() => DatabaseService.instance.resetForTesting());

  Future<ProviderContainer> makeContainer(
    Future<void> Function() postSyncWork,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        cloudStorageProviderProvider.overrideWithValue(
          FakeCloudStorageProvider(),
        ),
        galleryOriginBackfillProvider.overrideWithValue(postSyncWork),
      ],
    );
    addTearDown(container.dispose);
    await container.read(syncStateProvider.notifier).refreshState();
    return container;
  }

  /// What a post-sync stamp does: a pending mark made after the publish.
  Future<void> stampAfterPublish(String recordId) async {
    await SyncRepository().markRecordPending(
      entityType: 'media',
      recordId: recordId,
      localUpdatedAt: DateTime.now().millisecondsSinceEpoch,
    );
    SyncEventBus.notifyLocalChange();
  }

  test(
    'a press during the post-sync window runs once the flight ends',
    () async {
      final started = Completer<void>();
      final release = Completer<void>();
      var runs = 0;
      final container = await makeContainer(() {
        runs++;
        if (!started.isCompleted) started.complete();
        return release.future;
      });
      final notifier = container.read(syncStateProvider.notifier);

      final sync = notifier.performSync();
      await started.future;
      // The first sync already reads as a success here.
      expect(container.read(syncStateProvider).status, SyncStatus.success);

      // The user presses Sync again. It must not overlap the running flight,
      // and it must not be lost either.
      await notifier.performSync();
      expect(runs, 1, reason: 'never two syncs at once');

      release.complete();
      await sync;
      expect(runs, 2, reason: 'the second press ran after the first');
    },
  );

  test('stamps made after the publish go out in one follow-up sync', () async {
    var runs = 0;
    final container = await makeContainer(() async {
      runs++;
      if (runs == 1) await stampAfterPublish('photo-1');
    });

    await container.read(syncStateProvider.notifier).performSync();

    expect(runs, 2, reason: 'one press published the post-sync stamps');
    final state = container.read(syncStateProvider);
    expect(state.pendingChanges, 0);
    expect(state.lastSync, isNotNull);
  });

  test('the automatic follow-up runs at most once per press', () async {
    // Two devices whose post-sync work rewrites each other's rows would
    // otherwise trigger each other's follow-ups for ever.
    var runs = 0;
    final container = await makeContainer(() async {
      runs++;
      await stampAfterPublish('photo-$runs');
    });

    await container.read(syncStateProvider.notifier).performSync();

    expect(runs, 2);
    expect(container.read(syncStateProvider).pendingChanges, 1);
  });

  test('no follow-up when the sync left nothing unsynced', () async {
    var runs = 0;
    final container = await makeContainer(() async => runs++);

    await container.read(syncStateProvider.notifier).performSync();

    expect(runs, 1);
    expect(container.read(syncStateProvider).pendingChanges, 0);
  });
}
