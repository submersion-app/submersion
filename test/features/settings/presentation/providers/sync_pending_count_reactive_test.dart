import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/settings/presentation/providers/sync_providers.dart';

import '../../../../helpers/fake_cloud_storage_provider.dart';
import '../../../../helpers/test_database.dart';

/// Issue #990: with auto-sync OFF, editing dives left the Home "Synced" chip
/// and the Cloud Sync page showing a launch-time count of zero for the whole
/// session -- SyncState.pendingChanges was only ever recomputed by a sync.
/// Holds each [getUnsyncedChangeCount] call open once [armed], so a test can
/// choose the order the overlapping refreshes answer in. Before arming, calls
/// resolve immediately so notifier construction and refreshState are unaffected.
class _GatedSyncRepository extends SyncRepository {
  bool armed = false;
  final List<Completer<int>> gates = [];

  @override
  Future<int> getUnsyncedChangeCount({required String? providerId}) {
    if (!armed) return Future.value(0);
    final gate = Completer<int>();
    gates.add(gate);
    return gate.future;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;
  late FakeCloudStorageProvider cloud;

  setUp(() async {
    await setUpTestDatabase();
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    cloud = FakeCloudStorageProvider();
  });

  tearDown(tearDownTestDatabase);

  Future<ProviderContainer> makeContainer() async {
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        cloudStorageProviderProvider.overrideWithValue(cloud),
      ],
    );
    addTearDown(container.dispose);
    container.read(syncStateProvider);
    await container.read(syncStateProvider.notifier).refreshState();
    return container;
  }

  /// Past the notifier's 400ms coalescing window.
  Future<void> settleDebounce() =>
      Future<void>.delayed(const Duration(milliseconds: 700));

  test('a local edit updates the count while auto-sync is OFF', () async {
    final container = await makeContainer();
    // The reporter's exact configuration, and the default.
    expect(container.read(syncBehaviorProvider).autoSyncEnabled, isFalse);
    expect(container.read(syncStateProvider).pendingChanges, 0);

    await SyncRepository().markRecordPending(
      entityType: 'dives',
      recordId: 'dive-1',
      localUpdatedAt: 1000,
    );
    SyncEventBus.notifyLocalChange();
    await settleDebounce();

    expect(container.read(syncStateProvider).pendingChanges, 1);
  });

  test('a local deletion updates the count', () async {
    final container = await makeContainer();

    await SyncRepository().logDeletion(entityType: 'dives', recordId: 'gone');
    SyncEventBus.notifyLocalChange();
    await settleDebounce();

    expect(container.read(syncStateProvider).pendingChanges, 1);
  });

  test('a burst of edits coalesces into the settled total', () async {
    final container = await makeContainer();
    final repo = SyncRepository();

    for (var i = 0; i < 5; i++) {
      await repo.markRecordPending(
        entityType: 'dives',
        recordId: 'dive-$i',
        localUpdatedAt: 1000,
      );
      SyncEventBus.notifyLocalChange();
    }
    await settleDebounce();

    expect(container.read(syncStateProvider).pendingChanges, 5);
  });

  test('the count returns to zero once pending records clear', () async {
    final container = await makeContainer();
    final repo = SyncRepository();

    await repo.markRecordPending(
      entityType: 'dives',
      recordId: 'dive-1',
      localUpdatedAt: 1000,
    );
    SyncEventBus.notifyLocalChange();
    await settleDebounce();
    expect(container.read(syncStateProvider).pendingChanges, 1);

    // What a successful publish does.
    await repo.clearPendingRecords();
    SyncEventBus.notifyLocalChange();
    await settleDebounce();

    expect(container.read(syncStateProvider).pendingChanges, 0);
  });

  test('a slow earlier refresh cannot overwrite a newer count', () async {
    // The debounce cancels pending TIMERS, not an in-flight refresh: a write
    // arriving while the queries run starts a second refresh alongside the
    // first. If the slower earlier one published last, the chip would show a
    // stale count until something else recomputed it.
    final repo = _GatedSyncRepository();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        cloudStorageProviderProvider.overrideWithValue(cloud),
        syncRepositoryProvider.overrideWithValue(repo),
      ],
    );
    addTearDown(container.dispose);
    container.read(syncStateProvider);
    await container.read(syncStateProvider.notifier).refreshState();

    repo.armed = true;
    // Refresh A starts and blocks on its gate.
    SyncEventBus.notifyLocalChange();
    await settleDebounce();
    // Refresh B starts alongside it.
    SyncEventBus.notifyLocalChange();
    await settleDebounce();
    expect(repo.gates, hasLength(2));

    // B (the newer caller) answers first, then A answers late with a lower,
    // now-stale count.
    repo.gates[1].complete(5);
    await Future<void>.delayed(Duration.zero);
    repo.gates[0].complete(1);
    await Future<void>.delayed(Duration.zero);

    expect(container.read(syncStateProvider).pendingChanges, 5);
  });

  test('a disposed notifier does not refresh after its debounce', () async {
    final container = await makeContainer();
    await SyncRepository().markRecordPending(
      entityType: 'dives',
      recordId: 'dive-1',
      localUpdatedAt: 1000,
    );
    SyncEventBus.notifyLocalChange();
    container.dispose();

    // The pending timer must be cancelled in dispose; firing it would touch a
    // disposed StateNotifier and throw.
    await settleDebounce();
  });
}
