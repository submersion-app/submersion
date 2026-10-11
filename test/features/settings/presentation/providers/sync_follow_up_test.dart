import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart'
    hide SyncStatus;
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/features/equipment/data/services/equipment_findings_pass.dart';
import 'package:submersion/features/equipment/data/services/sensor_summary_scheduler.dart';
import 'package:submersion/features/equipment/domain/entities/exposure_thresholds.dart';
import 'package:submersion/features/media/presentation/providers/gallery_origin_backfill_provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/settings/presentation/providers/sync_providers.dart';

import '../../../../helpers/fake_cloud_storage_provider.dart';
import '../../../../helpers/global_test_defaults.dart';
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

  tearDown(() async {
    // Waits out any batch a test queued before restoring the harness's
    // scheduler defaults (one test turns the summary scheduler on).
    await SensorSummaryScheduler.instance.idle;
    applyGlobalTestDefaults();
    DatabaseService.instance.resetForTesting();
  });

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

  test('the follow-up waits for the post-sync findings pass', () async {
    // The findings pass after the summary sweep runs unawaited and is the
    // likeliest source of the stranded rows. One that writes after the
    // settle delay must still be published by the same press.
    final scheduler = SensorSummaryScheduler.instance;
    final loader = scheduler.conditionInputsLoader;
    addTearDown(() => scheduler.conditionInputsLoader = loader);
    SensorSummaryScheduler.enabled = true;
    var passes = 0;
    scheduler.conditionInputsLoader = () async {
      passes++;
      if (passes == 1) {
        // Later than the 2s settle the count used to be read after.
        await Future<void>.delayed(const Duration(seconds: 3));
        await stampAfterPublish('equipment-finding');
      }
      return const ConditionPassInputs(
        diverId: null,
        thresholds: ExposureThresholds.defaults,
        engineEnabled: false,
      );
    };
    var runs = 0;
    final container = await makeContainer(() async => runs++);

    await container.read(syncStateProvider.notifier).performSync();

    expect(runs, 2, reason: 'the findings stamp went out in a follow-up');
    expect(container.read(syncStateProvider).pendingChanges, 0);
  });

  test('the wait drains batches the findings pass queues itself', () async {
    // A findings pass can queue another batch (summaries it found missing),
    // which replaces the scheduler's tail after the sync read it. Waiting on
    // the first tail alone would settle before the second batch stamps.
    final scheduler = SensorSummaryScheduler.instance;
    final loader = scheduler.conditionInputsLoader;
    addTearDown(() => scheduler.conditionInputsLoader = loader);
    SensorSummaryScheduler.enabled = true;
    var passes = 0;
    scheduler.conditionInputsLoader = () async {
      passes++;
      if (passes == 1) {
        await Future<void>.delayed(const Duration(seconds: 1));
        scheduler.scheduleFindings({'regulator'});
      } else if (passes == 2) {
        // Past the old single wait (pass 1) plus its 2s settle.
        await Future<void>.delayed(const Duration(seconds: 3));
        await stampAfterPublish('second-batch-finding');
      }
      return const ConditionPassInputs(
        diverId: null,
        thresholds: ExposureThresholds.defaults,
        engineEnabled: false,
      );
    };
    var runs = 0;
    final container = await makeContainer(() async => runs++);

    await container.read(syncStateProvider.notifier).performSync();

    expect(passes, greaterThanOrEqualTo(2));
    expect(runs, 2, reason: 'the second batch went out in a follow-up');
    expect(container.read(syncStateProvider).pendingChanges, 0);
  });
}
