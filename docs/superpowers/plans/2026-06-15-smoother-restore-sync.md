# Smoother Restore Sync Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** After a database restore, resume cloud sync without the user having to find and tap "Sync Now" — auto-resume the restoring device (Merge), and make the other devices' replace-adopt pause unmissable instead of silent.

**Architecture:** Carry the restore dialog's consent forward. A Merge restore persists a post-restore sync intent (mirrors the existing `pendingReplace`) that `_initialize` consumes on next launch via a gate-bypassing `performSync(auto:false)`; a durable per-provider "established" anchor (SharedPreferences, survives restore) stops a wiped cursor from re-arming the first-contact gate. For the destructive Replace-adopt path on other devices, detect the foreign epoch proactively on launch (independent of auto-sync toggles) and surface a global modal dialog + persistent banner; the adopt itself stays confirmed and unchanged.

**Tech Stack:** Flutter, Riverpod (`StateNotifier`), Drift, SharedPreferences, go_router, Flutter gen-l10n. Tests use `flutter_test`, hand-written fakes, `SharedPreferences.setMockInitialValues`, and `ProviderContainer` overrides.

**Spec:** `docs/superpowers/specs/2026-06-15-smoother-restore-sync-design.md`

**Branch:** `feat/smoother-restore-sync` (already created from the post-#330 `origin/main`).

---

## File Structure

**New files:**
- `lib/core/services/sync/post_restore_sync_store.dart` — Merge restore "sync once on next launch" intent (SharedPreferences bool).
- `lib/core/services/sync/established_provider_store.dart` — set of providerIds this install has successfully synced to (SharedPreferences string list).
- `lib/features/settings/presentation/widgets/adopt_replaced_library_dialog.dart` — reusable adopt dialog, shared by the Cloud Sync page and the app root.
- `test/core/services/sync/post_restore_sync_store_test.dart`
- `test/core/services/sync/established_provider_store_test.dart`
- `test/features/settings/presentation/providers/sync_providers_restore_test.dart`

**Modified files:**
- `lib/features/settings/presentation/providers/sync_providers.dart` — store providers; `SyncState.postRestoreSyncing`; `firstSyncMergeInfo` anchor short-circuit; success-path anchor write + intent clear; `_initialize` merge-intent + proactive-replace branches; `_runPostRestoreSync`; `_detectReplacedLibraryForSurfacing`; `resetSyncState` clears anchor + intent.
- `lib/features/backup/data/services/backup_service.dart` — set the Merge intent on restore.
- `lib/features/backup/presentation/providers/backup_providers.dart` — inject `PostRestoreSyncStore` into `backupServiceProvider`.
- `lib/features/settings/presentation/pages/cloud_sync_page.dart` — call the extracted dialog; remove the in-page `_showAdoptDialog`.
- `lib/core/router/app_router.dart` — add a root navigator key.
- `lib/app.dart` — app-root `ref.listen` surfacing (notice SnackBar + adopt dialog + persistent banner).
- `lib/l10n/arb/app_en.arb` + 10 locale ARBs — three new strings.
- `test/features/backup/data/services/backup_service_test.dart` — Merge sets intent / Replace does not.

---

## Task 1: PostRestoreSyncStore

**Files:**
- Create: `lib/core/services/sync/post_restore_sync_store.dart`
- Test: `test/core/services/sync/post_restore_sync_store_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// test/core/services/sync/post_restore_sync_store_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/services/sync/post_restore_sync_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late PostRestoreSyncStore store;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = PostRestoreSyncStore(await SharedPreferences.getInstance());
  });

  test('defaults to not pending', () {
    expect(store.pending, isFalse);
  });

  test('setPending then clear round-trips', () async {
    await store.setPending();
    expect(store.pending, isTrue);
    await store.clear();
    expect(store.pending, isFalse);
  });

  test('survives a new store instance over the same prefs (restore)', () async {
    await store.setPending();
    final reopened = PostRestoreSyncStore(await SharedPreferences.getInstance());
    expect(reopened.pending, isTrue);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/services/sync/post_restore_sync_store_test.dart`
Expected: FAIL — `Target of URI doesn't exist: '.../post_restore_sync_store.dart'`.

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/core/services/sync/post_restore_sync_store.dart
import 'package:shared_preferences/shared_preferences.dart';

/// SharedPreferences flag set when a Merge restore completes, consumed once on
/// the next launch to force a sync that bypasses the first-contact gate.
///
/// Deliberately OUTSIDE the database (mirrors the pending-replace intent in
/// LibraryEpochStore): the restore rewinds the in-DB sync cursor, and the
/// Merge path mints no epoch, so this is the only durable signal that the
/// just-restored data still owes the cloud one reconciling sync.
class PostRestoreSyncStore {
  static const _pendingKey = 'sync_post_restore_pending';

  final SharedPreferences _prefs;

  PostRestoreSyncStore(this._prefs);

  bool get pending => _prefs.getBool(_pendingKey) ?? false;

  Future<void> setPending() async {
    await _prefs.setBool(_pendingKey, true);
  }

  Future<void> clear() async {
    await _prefs.remove(_pendingKey);
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/services/sync/post_restore_sync_store_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/core/services/sync/post_restore_sync_store.dart test/core/services/sync/post_restore_sync_store_test.dart
git commit -m "feat(sync): add PostRestoreSyncStore for the Merge-restore sync intent"
```

---

## Task 2: EstablishedProviderStore

**Files:**
- Create: `lib/core/services/sync/established_provider_store.dart`
- Test: `test/core/services/sync/established_provider_store_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// test/core/services/sync/established_provider_store_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/services/sync/established_provider_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late EstablishedProviderStore store;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = EstablishedProviderStore(await SharedPreferences.getInstance());
  });

  test('unknown provider is not established', () {
    expect(store.contains('s3'), isFalse);
  });

  test('add marks a provider established and is idempotent', () async {
    await store.add('s3');
    await store.add('s3');
    expect(store.contains('s3'), isTrue);
  });

  test('is scoped per provider', () async {
    await store.add('s3');
    expect(store.contains('s3'), isTrue);
    expect(store.contains('icloud'), isFalse);
  });

  test('survives a new store instance over the same prefs (restore)', () async {
    await store.add('s3');
    final reopened =
        EstablishedProviderStore(await SharedPreferences.getInstance());
    expect(reopened.contains('s3'), isTrue);
  });

  test('clear forgets all providers', () async {
    await store.add('s3');
    await store.clear();
    expect(store.contains('s3'), isFalse);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/services/sync/established_provider_store_test.dart`
Expected: FAIL — URI does not exist.

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/core/services/sync/established_provider_store.dart
import 'package:shared_preferences/shared_preferences.dart';

/// SharedPreferences set of cloud providerIds this install has completed a
/// successful sync against.
///
/// Lives outside the database so a restore (which rewinds the in-DB sync
/// cursor) cannot make an established device look like a brand-new one to the
/// first-contact gate. Same survive-the-restore role as the device-id / epoch
/// anchors. Keyed on the providerId used by `getLastSyncTime(forProvider:)`,
/// so the gate stays correct across backend switches.
class EstablishedProviderStore {
  static const _key = 'sync_established_providers';

  final SharedPreferences _prefs;

  EstablishedProviderStore(this._prefs);

  bool contains(String providerId) =>
      (_prefs.getStringList(_key) ?? const <String>[]).contains(providerId);

  Future<void> add(String providerId) async {
    final current = _prefs.getStringList(_key) ?? const <String>[];
    if (current.contains(providerId)) return;
    await _prefs.setStringList(_key, [...current, providerId]);
  }

  Future<void> clear() async {
    await _prefs.remove(_key);
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/services/sync/established_provider_store_test.dart`
Expected: PASS (5 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/core/services/sync/established_provider_store.dart test/core/services/sync/established_provider_store_test.dart
git commit -m "feat(sync): add EstablishedProviderStore anchor (survives restore)"
```

---

## Task 3: Wire the two store providers

**Files:**
- Modify: `lib/features/settings/presentation/providers/sync_providers.dart` (imports near line 16-24; provider block near line 46-55)

- [ ] **Step 1: Add the imports**

In the import block (after the existing `library_moved_store.dart` import, around line 19), add:

```dart
import 'package:submersion/core/services/sync/established_provider_store.dart';
import 'package:submersion/core/services/sync/post_restore_sync_store.dart';
```

- [ ] **Step 2: Add the providers**

After `libraryMovedStoreProvider` (around line 55), add:

```dart
/// Merge-restore "sync once on next launch" intent.
final postRestoreSyncStoreProvider = Provider<PostRestoreSyncStore>((ref) {
  return PostRestoreSyncStore(ref.watch(sharedPreferencesProvider));
});

/// Providers this install has successfully synced to (survives restore).
final establishedProviderStoreProvider =
    Provider<EstablishedProviderStore>((ref) {
  return EstablishedProviderStore(ref.watch(sharedPreferencesProvider));
});
```

- [ ] **Step 3: Verify it compiles**

Run: `flutter analyze lib/features/settings/presentation/providers/sync_providers.dart`
Expected: No new errors (unused providers warning is acceptable until later tasks use them; if `analyze` reports them as errors, proceed — they are referenced in Tasks 5-8).

- [ ] **Step 4: Commit**

```bash
git add lib/features/settings/presentation/providers/sync_providers.dart
git commit -m "feat(sync): expose post-restore intent and established-provider store providers"
```

---

## Task 4: Add `SyncState.postRestoreSyncing`

**Files:**
- Modify: `lib/features/settings/presentation/providers/sync_providers.dart` (the `SyncState` class, lines 172-260)

- [ ] **Step 1: Add the field**

After `final bool firstSyncAwaitingConfirmation;` (line 180), add:

```dart
  /// True while the one forced post-restore sync is running. Drives the
  /// app-root "Syncing your restored library..." notice; never persisted.
  final bool postRestoreSyncing;
```

- [ ] **Step 2: Add the constructor default**

In the `const SyncState({...})` constructor (after `this.firstSyncAwaitingConfirmation = false,`, line 213), add:

```dart
    this.postRestoreSyncing = false,
```

- [ ] **Step 3: Add the copyWith param + assignment**

In `copyWith`, after the `bool? firstSyncAwaitingConfirmation,` parameter (line 228), add:

```dart
    bool? postRestoreSyncing,
```

In the returned `SyncState(...)`, after the `firstSyncAwaitingConfirmation:` assignment (line 244-245), add:

```dart
      postRestoreSyncing: postRestoreSyncing ?? this.postRestoreSyncing,
```

- [ ] **Step 4: Verify it compiles**

Run: `flutter analyze lib/features/settings/presentation/providers/sync_providers.dart`
Expected: No new errors.

- [ ] **Step 5: Commit**

```bash
git add lib/features/settings/presentation/providers/sync_providers.dart
git commit -m "feat(sync): add SyncState.postRestoreSyncing flag"
```

---

## Task 5: `firstSyncMergeInfo` skips established providers

This is the root-cause fix: an established device must not be treated as first-contact after a restore wipes its cursor — while a genuinely new device still is.

**Files:**
- Modify: `lib/features/settings/presentation/providers/sync_providers.dart` (`firstSyncMergeInfo`, lines 369-397)
- Test: `test/features/settings/presentation/providers/sync_providers_restore_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// test/features/settings/presentation/providers/sync_providers_restore_test.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/established_provider_store.dart';
import 'package:submersion/core/services/sync/post_restore_sync_store.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/settings/presentation/providers/sync_providers.dart';

import '../../../../helpers/changeset_test_helpers.dart';
import '../../../../helpers/fake_cloud_storage_provider.dart';
import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

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

  tearDown(() {
    DatabaseService.instance.resetForTesting();
  });

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

  Future<void> seedLocalDive(String id) async {
    await DiveRepository().createDive(createTestDiveWithBottomTime(id: id));
  }

  group('firstSyncMergeInfo established-provider short-circuit', () {
    test('genuine new device with peers + local dives still gates', () async {
      final container = await makeContainer();
      await seedLocalDive('d1');
      await seedPeerManifest(cloud, 'peer-device');

      final info =
          await container.read(syncStateProvider.notifier).firstSyncMergeInfo();
      expect(info, isNotNull,
          reason: 'a brand-new device must still confirm before merging');
    });

    test('established provider short-circuits the gate (restore case)',
        () async {
      await EstablishedProviderStore(prefs).add(cloud.providerId);
      final container = await makeContainer();
      await seedLocalDive('d1');
      await seedPeerManifest(cloud, 'peer-device');

      final info =
          await container.read(syncStateProvider.notifier).firstSyncMergeInfo();
      expect(info, isNull,
          reason:
              'a device that already synced here is not first-contact, even '
              'after a restore wiped its in-DB cursor');
    });
  });
}
```

- [ ] **Step 2: Run test to verify the second case fails**

Run: `flutter test test/features/settings/presentation/providers/sync_providers_restore_test.dart`
Expected: FIRST test passes; SECOND test FAILS (`info` is non-null because the anchor is ignored).

- [ ] **Step 3: Add the short-circuit**

In `firstSyncMergeInfo`, immediately after `if (provider == null) return null;` (line 372), add:

```dart
      // An established device is never first-contact: a restore wipes the
      // in-DB cursor (lastSyncTime), but this anchor survives, so the gate
      // must not re-fire for a device that already merged here.
      if (_ref.read(establishedProviderStoreProvider).contains(
        provider.providerId,
      )) {
        return null;
      }
```

- [ ] **Step 4: Run test to verify both pass**

Run: `flutter test test/features/settings/presentation/providers/sync_providers_restore_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/features/settings/presentation/providers/sync_providers.dart test/features/settings/presentation/providers/sync_providers_restore_test.dart
git commit -m "fix(sync): established provider is not first-contact (restore no longer re-gates)"
```

---

## Task 6: Record the anchor + clear the intent on a successful sync

**Files:**
- Modify: `lib/features/settings/presentation/providers/sync_providers.dart` (`performSync` success block, lines 676-689)
- Test: same file as Task 5

- [ ] **Step 1: Write the failing test**

Add to the `group(...)` in `sync_providers_restore_test.dart`:

```dart
    test('a successful sync anchors the provider and clears the intent',
        () async {
      await PostRestoreSyncStore(prefs).setPending();
      final container = await makeContainer();
      await seedLocalDive('d1');

      await container.read(syncStateProvider.notifier).performSync();

      expect(EstablishedProviderStore(prefs).contains(cloud.providerId), isTrue,
          reason: 'a clean sync marks this provider established');
      expect(PostRestoreSyncStore(prefs).pending, isFalse,
          reason: 'the post-restore intent is consumed once a sync succeeds');
    });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/settings/presentation/providers/sync_providers_restore_test.dart --name "anchors the provider"`
Expected: FAIL — provider not anchored / intent still pending.

- [ ] **Step 3: Add anchor write + intent clear**

In `performSync`, inside `if (result.isSuccess) {`, immediately after the `state = state.copyWith(... progress: 1.0,);` block and before `await _surfaceOldBackendCleanupOffer();` (line 689), add:

```dart
          // Mark this provider established and consume any post-restore intent:
          // a future restore that wipes the in-DB cursor must not make this
          // device look like first-contact again, and the Merge restore's
          // one-shot intent is now satisfied.
          final syncedProvider = _ref.read(cloudStorageProviderProvider);
          if (syncedProvider != null) {
            await _ref
                .read(establishedProviderStoreProvider)
                .add(syncedProvider.providerId);
          }
          await _ref.read(postRestoreSyncStoreProvider).clear();
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/settings/presentation/providers/sync_providers_restore_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/features/settings/presentation/providers/sync_providers.dart test/features/settings/presentation/providers/sync_providers_restore_test.dart
git commit -m "feat(sync): anchor the provider and clear the post-restore intent on sync success"
```

---

## Task 7: `_initialize` consumes the Merge intent (forced gate-bypassing sync)

**Files:**
- Modify: `lib/features/settings/presentation/providers/sync_providers.dart` (`_initialize`, lines 291-301; add `_runPostRestoreSync`)
- Test: same file as Task 5

- [ ] **Step 1: Write the failing test**

Add to `sync_providers_restore_test.dart` (new group):

```dart
  group('post-restore launch sync', () {
    test('a pending intent forces a sync that bypasses the first-contact gate',
        () async {
      // Arrange the EXACT condition that used to defer: peers + local dives +
      // null cursor + a pending post-restore intent.
      await PostRestoreSyncStore(prefs).setPending();
      await seedPeerManifest(cloud, 'peer-device');

      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          cloudStorageProviderProvider.overrideWithValue(cloud),
        ],
      );
      addTearDown(container.dispose);
      await DiveRepository()
          .createDive(createTestDiveWithBottomTime(id: 'd1'));

      // Construct the notifier (runs _initialize) and let it finish.
      container.read(syncStateProvider);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      // Allow the forced sync (and its internal post-success refresh delay) to
      // complete.
      await Future<void>.delayed(const Duration(seconds: 3));

      final state = container.read(syncStateProvider);
      expect(state.firstSyncAwaitingConfirmation, isFalse,
          reason: 'THE BUG: the forced post-restore sync must not defer');
      expect(PostRestoreSyncStore(prefs).pending, isFalse,
          reason: 'a successful forced sync consumes the intent');
      expect(state.postRestoreSyncing, isFalse,
          reason: 'the syncing flag is lowered when the forced sync finishes');
    });
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/settings/presentation/providers/sync_providers_restore_test.dart --name "bypasses the first-contact gate"`
Expected: FAIL — `firstSyncAwaitingConfirmation` is true and/or intent still pending (the intent is not yet consumed by `_initialize`).

- [ ] **Step 3: Rewrite `_initialize` and add `_runPostRestoreSync`**

Replace the existing `_initialize` (lines 291-301):

```dart
  Future<void> _initialize() async {
    // Load initial state
    if (!mounted) return;
    await refreshState();
    if (!mounted) return;

    // A Replace restore persists its cloud side as a pending intent; execute
    // it as soon as the app is back up, regardless of auto-sync settings.
    if (_ref.read(libraryEpochStoreProvider).pendingReplace != null) {
      unawaited(performSync());
      return;
    }

    final provider = _ref.read(cloudStorageProviderProvider);
    if (provider == null) return;

    // A Merge restore persists a post-restore intent: the restore dialog's
    // Merge choice is the consent, so force one sync that bypasses the
    // first-contact gate (auto:false) regardless of the auto-sync toggles.
    if (_ref.read(postRestoreSyncStoreProvider).pending) {
      unawaited(_runPostRestoreSync());
      return;
    }

    // On the other devices, surface a Replace-everywhere adoption proactively
    // (even with auto-sync off) so a paused device is never hidden behind a
    // manual Sync Now. See Task 12.
    unawaited(_detectReplacedLibraryForSurfacing());
  }

  /// Force the one consented post-restore sync. `performSync(auto:false)` skips
  /// the first-contact gate; the success path clears the intent (Task 6).
  Future<void> _runPostRestoreSync() async {
    if (!mounted) return;
    state = state.copyWith(postRestoreSyncing: true);
    await performSync();
    if (mounted) state = state.copyWith(postRestoreSyncing: false);
  }
```

NOTE: `_detectReplacedLibraryForSurfacing` is added in Task 12. To keep the tree compiling between commits, add this temporary stub now, directly below `_runPostRestoreSync` (Task 12 replaces its body):

```dart
  Future<void> _detectReplacedLibraryForSurfacing() async {
    // Implemented in Task 12.
  }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/settings/presentation/providers/sync_providers_restore_test.dart`
Expected: PASS (all tests in the file).

- [ ] **Step 5: Commit**

```bash
git add lib/features/settings/presentation/providers/sync_providers.dart test/features/settings/presentation/providers/sync_providers_restore_test.dart
git commit -m "feat(sync): force a gate-bypassing sync after a Merge restore"
```

---

## Task 8: `resetSyncState` clears the anchor and the intent

**Files:**
- Modify: `lib/features/settings/presentation/providers/sync_providers.dart` (`resetSyncState`, lines 767-777)
- Test: same file as Task 5

- [ ] **Step 1: Write the failing test**

Add to `sync_providers_restore_test.dart`:

```dart
  test('resetSyncState clears the anchor and the post-restore intent',
      () async {
    await EstablishedProviderStore(prefs).add(cloud.providerId);
    await PostRestoreSyncStore(prefs).setPending();
    final container = await makeContainer();

    await container.read(syncStateProvider.notifier).resetSyncState();

    expect(EstablishedProviderStore(prefs).contains(cloud.providerId), isFalse,
        reason: 'an explicit reset is a true fresh start, so re-arm the gate');
    expect(PostRestoreSyncStore(prefs).pending, isFalse);
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/settings/presentation/providers/sync_providers_restore_test.dart --name "resetSyncState clears"`
Expected: FAIL — anchor still present after reset.

- [ ] **Step 3: Add the clears**

In `resetSyncState`, after `await _ref.read(libraryEpochStoreProvider).clearPendingReplace();` (line 774), add:

```dart
    await _ref.read(postRestoreSyncStoreProvider).clear();
    await _ref.read(establishedProviderStoreProvider).clear();
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/settings/presentation/providers/sync_providers_restore_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/settings/presentation/providers/sync_providers.dart test/features/settings/presentation/providers/sync_providers_restore_test.dart
git commit -m "feat(sync): Reset Sync State clears the established anchor and post-restore intent"
```

---

## Task 9: BackupService sets the Merge intent on restore

**Files:**
- Modify: `lib/features/backup/data/services/backup_service.dart` (constructor lines 58-83; `restoreFromBackup` line 312-314; `restoreFromFile` line 344-346)
- Modify: `lib/features/backup/presentation/providers/backup_providers.dart` (`backupServiceProvider`, lines 26-33)
- Test: `test/features/backup/data/services/backup_service_test.dart`

- [ ] **Step 1: Write the failing test**

Add these tests to the relevant `group` in `backup_service_test.dart` (mirror the existing `restoreFromFile` test's construction; use a real `PostRestoreSyncStore` over mock prefs). Add the import at the top:

```dart
import 'package:submersion/core/services/sync/post_restore_sync_store.dart';
```

Then add:

```dart
  test('Merge restore sets the post-restore sync intent', () async {
    SharedPreferences.setMockInitialValues({});
    final intentPrefs = await SharedPreferences.getInstance();
    final intentStore = PostRestoreSyncStore(intentPrefs);
    final service = BackupService(
      dbAdapter: fakeDb,
      preferences: preferences,
      syncRepository: _SpySyncRepository(),
      postRestoreSyncStore: intentStore,
    );
    final src = File(
      '${Directory.systemTemp.path}/restore_merge_'
      '${DateTime.now().microsecondsSinceEpoch}.db',
    );
    await src.writeAsString('db');
    addTearDown(() async {
      if (await src.exists()) await src.delete();
    });

    await service.restoreFromFile(src.path); // mode defaults to merge

    expect(intentStore.pending, isTrue,
        reason: 'a Merge restore must arm the post-restore sync intent');
  });

  test('Replace restore does NOT set the merge intent', () async {
    SharedPreferences.setMockInitialValues({});
    final intentPrefs = await SharedPreferences.getInstance();
    final intentStore = PostRestoreSyncStore(intentPrefs);
    final service = BackupService(
      dbAdapter: fakeDb,
      preferences: preferences,
      syncRepository: _SpySyncRepository(),
      epochStore: LibraryEpochStore(intentPrefs),
      postRestoreSyncStore: intentStore,
    );
    final src = File(
      '${Directory.systemTemp.path}/restore_replace_'
      '${DateTime.now().microsecondsSinceEpoch}.db',
    );
    await src.writeAsString('db');
    addTearDown(() async {
      if (await src.exists()) await src.delete();
    });

    await service.restoreFromFile(src.path, mode: RestoreMode.replace);

    expect(intentStore.pending, isFalse,
        reason: 'Replace uses pendingReplace, not the merge intent');
  });
```

Ensure these imports exist at the top of the test file (add any missing):

```dart
import 'package:submersion/core/services/sync/library_epoch_store.dart';
import 'package:submersion/features/backup/domain/entities/restore_mode.dart';
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/backup/data/services/backup_service_test.dart --name "post-restore sync intent"`
Expected: FAIL — `BackupService` has no `postRestoreSyncStore` named parameter.

- [ ] **Step 3: Add the dependency and set the intent**

In `backup_service.dart`, add the import (after the `library_epoch_store.dart` import, line 17):

```dart
import 'package:submersion/core/services/sync/post_restore_sync_store.dart';
```

Add the field after `_epochStore` (line 66):

```dart
  /// Set on a Merge restore so the next launch forces one reconciling sync.
  /// Nullable so existing constructions keep working.
  final PostRestoreSyncStore? _postRestoreSyncStore;
```

Add the constructor parameter after `LibraryEpochStore? epochStore,` (line 78):

```dart
    PostRestoreSyncStore? postRestoreSyncStore,
```

Add the initializer after `_epochStore = epochStore;` — change that line to:

```dart
       _epochStore = epochStore,
       _postRestoreSyncStore = postRestoreSyncStore;
```

In `restoreFromBackup`, replace lines 312-314:

```dart
    if (mode == RestoreMode.replace) {
      await _mintPendingReplace();
    } else {
      await _postRestoreSyncStore?.setPending();
    }
```

In `restoreFromFile`, replace lines 344-346 identically:

```dart
    if (mode == RestoreMode.replace) {
      await _mintPendingReplace();
    } else {
      await _postRestoreSyncStore?.setPending();
    }
```

- [ ] **Step 4: Wire the provider**

In `backup_providers.dart`, add the import (after line 6):

```dart
import 'package:submersion/core/services/sync/post_restore_sync_store.dart';
```

In `backupServiceProvider` (line 27-32), add the argument after `epochStore: ...`:

```dart
    postRestoreSyncStore:
        PostRestoreSyncStore(ref.watch(sharedPreferencesProvider)),
```

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/features/backup/data/services/backup_service_test.dart`
Expected: PASS (existing + 2 new tests).

- [ ] **Step 6: Commit**

```bash
git add lib/features/backup/data/services/backup_service.dart lib/features/backup/presentation/providers/backup_providers.dart test/features/backup/data/services/backup_service_test.dart
git commit -m "feat(backup): arm the post-restore sync intent on a Merge restore"
```

---

## Task 10: Localization strings (en + 10 locales)

**Files:**
- Modify: `lib/l10n/arb/app_en.arb` and `app_ar.arb`, `app_de.arb`, `app_es.arb`, `app_fr.arb`, `app_he.arb`, `app_hu.arb`, `app_it.arb`, `app_nl.arb`, `app_pt.arb`, `app_zh.arb`

Three new keys (no placeholders): `settings_cloudSync_postRestore_syncing`, `settings_cloudSync_postRestore_synced`, `settings_cloudSync_replace_reviewAction`. (The spec named two; the persistent banner's action label requires the third, "Review".)

- [ ] **Step 1: Add to the English template**

In `lib/l10n/arb/app_en.arb`, add near the other `settings_cloudSync_` keys (these are simple strings; no `@`-metadata block needed):

```json
  "settings_cloudSync_postRestore_syncing": "Syncing your restored library with the cloud…",
  "settings_cloudSync_postRestore_synced": "Restored library synced.",
  "settings_cloudSync_replace_reviewAction": "Review",
```

- [ ] **Step 2: Add translations to each locale ARB**

Add the same three keys with translated values to each locale file:

`app_ar.arb`:
```json
  "settings_cloudSync_postRestore_syncing": "تتم مزامنة مكتبتك المستعادة مع السحابة…",
  "settings_cloudSync_postRestore_synced": "تمت مزامنة المكتبة المستعادة.",
  "settings_cloudSync_replace_reviewAction": "مراجعة",
```

`app_de.arb`:
```json
  "settings_cloudSync_postRestore_syncing": "Wiederhergestellte Bibliothek wird mit der Cloud synchronisiert…",
  "settings_cloudSync_postRestore_synced": "Wiederhergestellte Bibliothek synchronisiert.",
  "settings_cloudSync_replace_reviewAction": "Überprüfen",
```

`app_es.arb`:
```json
  "settings_cloudSync_postRestore_syncing": "Sincronizando tu biblioteca restaurada con la nube…",
  "settings_cloudSync_postRestore_synced": "Biblioteca restaurada sincronizada.",
  "settings_cloudSync_replace_reviewAction": "Revisar",
```

`app_fr.arb`:
```json
  "settings_cloudSync_postRestore_syncing": "Synchronisation de votre bibliothèque restaurée avec le cloud…",
  "settings_cloudSync_postRestore_synced": "Bibliothèque restaurée synchronisée.",
  "settings_cloudSync_replace_reviewAction": "Examiner",
```

`app_he.arb`:
```json
  "settings_cloudSync_postRestore_syncing": "מסנכרן את הספרייה המשוחזרת שלך עם הענן…",
  "settings_cloudSync_postRestore_synced": "הספרייה המשוחזרת סונכרנה.",
  "settings_cloudSync_replace_reviewAction": "סקירה",
```

`app_hu.arb`:
```json
  "settings_cloudSync_postRestore_syncing": "A visszaállított könyvtár szinkronizálása a felhővel…",
  "settings_cloudSync_postRestore_synced": "A visszaállított könyvtár szinkronizálva.",
  "settings_cloudSync_replace_reviewAction": "Áttekintés",
```

`app_it.arb`:
```json
  "settings_cloudSync_postRestore_syncing": "Sincronizzazione della libreria ripristinata con il cloud…",
  "settings_cloudSync_postRestore_synced": "Libreria ripristinata sincronizzata.",
  "settings_cloudSync_replace_reviewAction": "Rivedi",
```

`app_nl.arb`:
```json
  "settings_cloudSync_postRestore_syncing": "Je herstelde bibliotheek wordt met de cloud gesynchroniseerd…",
  "settings_cloudSync_postRestore_synced": "Herstelde bibliotheek gesynchroniseerd.",
  "settings_cloudSync_replace_reviewAction": "Controleren",
```

`app_pt.arb`:
```json
  "settings_cloudSync_postRestore_syncing": "A sincronizar a sua biblioteca restaurada com a nuvem…",
  "settings_cloudSync_postRestore_synced": "Biblioteca restaurada sincronizada.",
  "settings_cloudSync_replace_reviewAction": "Rever",
```

`app_zh.arb`:
```json
  "settings_cloudSync_postRestore_syncing": "正在将恢复的资料库与云同步…",
  "settings_cloudSync_postRestore_synced": "已同步恢复的资料库。",
  "settings_cloudSync_replace_reviewAction": "查看",
```

- [ ] **Step 3: Regenerate localizations**

Run: `flutter gen-l10n`
Expected: regenerates `lib/l10n/arb/app_localizations*.dart`. Then verify:

Run: `flutter analyze lib/l10n/arb/app_localizations.dart`
Expected: the three getters exist (no errors).

- [ ] **Step 4: Commit**

```bash
git add lib/l10n/arb/
git commit -m "feat(l10n): post-restore sync notice + replace review action in all locales"
```

---

## Task 11: Extract the adopt dialog into a reusable widget

**Files:**
- Create: `lib/features/settings/presentation/widgets/adopt_replaced_library_dialog.dart`
- Modify: `lib/features/settings/presentation/pages/cloud_sync_page.dart` (`_onSyncNowPressed` line 1003; remove `_showAdoptDialog` lines 1043-1079)
- Test: `test/features/settings/presentation/widgets/adopt_replaced_library_dialog_test.dart`

- [ ] **Step 1: Create the reusable dialog (copy the existing logic verbatim)**

```dart
// lib/features/settings/presentation/widgets/adopt_replaced_library_dialog.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/sync/library_epoch.dart';
import 'package:submersion/features/backup/presentation/providers/backup_providers.dart';
import 'package:submersion/features/settings/presentation/providers/sync_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Confirm and run adoption of a replaced cloud library. Shared by the Cloud
/// Sync page and the app-root surfacing so the destructive adopt has exactly
/// one implementation. The safety backup runs here (not in SyncNotifier)
/// because backup providers import sync providers; this widget layer may
/// import both.
Future<void> showAdoptReplacedLibraryDialog(
  BuildContext context,
  WidgetRef ref,
  LibraryEpochMarker marker,
) async {
  final l10n = context.l10n;
  final date = marker.replacedAt > 0
      ? DateFormat.yMMMd().add_jm().format(
          DateTime.fromMillisecondsSinceEpoch(marker.replacedAt),
        )
      : '?';
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l10n.settings_cloudSync_adopt_dialogTitle),
      content: Text(
        l10n.settings_cloudSync_adopt_dialogContent(marker.displayName, date),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(l10n.settings_cloudSync_adopt_notNow),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(l10n.settings_cloudSync_adopt_confirm),
        ),
      ],
    ),
  );
  if (confirmed != true) return;
  // Safety backup of this device's current data BEFORE it is overwritten.
  await ref.read(backupServiceProvider).performBackup(isAutomatic: true);
  await ref.read(syncStateProvider.notifier).adoptReplacedLibrary();
}
```

- [ ] **Step 2: Point the Cloud Sync page at it**

In `cloud_sync_page.dart`, add the import near the other widget/feature imports:

```dart
import 'package:submersion/features/settings/presentation/widgets/adopt_replaced_library_dialog.dart';
```

In `_onSyncNowPressed`, replace the call on line 1003:

```dart
      await _showAdoptDialog(context, ref, replaceInfo);
```

with:

```dart
      await showAdoptReplacedLibraryDialog(context, ref, replaceInfo);
```

Then delete the now-unused private method `_showAdoptDialog` (lines 1043-1079). If `intl`'s `DateFormat` import in `cloud_sync_page.dart` becomes unused after deletion, remove that import too (verify with analyze in Step 4).

- [ ] **Step 3: Write the dialog widget test**

```dart
// test/features/settings/presentation/widgets/adopt_replaced_library_dialog_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/sync/library_epoch.dart';
import 'package:submersion/features/settings/presentation/widgets/adopt_replaced_library_dialog.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
  testWidgets('renders the replacing device name and the two actions',
      (tester) async {
    const marker = LibraryEpochMarker(
      epochId: 'e1',
      replacedAt: 1764000000000,
      deviceId: 'replacer',
      deviceName: 'Eric Mac',
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: Consumer(
                builder: (context, ref, _) => ElevatedButton(
                  onPressed: () =>
                      showAdoptReplacedLibraryDialog(context, ref, marker),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Adopt Restored Library?'), findsOneWidget);
    expect(find.textContaining('Eric Mac'), findsOneWidget);
    // Cancelling must not throw / must close cleanly.
    expect(find.text('Not now'), findsOneWidget);
    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();
    expect(find.text('Adopt Restored Library?'), findsNothing);
  });
}
```

(If the `settings_cloudSync_adopt_notNow` English value is not exactly "Not now", read it from `lib/l10n/arb/app_en.arb` and update the `find.text` matcher to match.)

- [ ] **Step 4: Run tests + analyze**

Run: `flutter test test/features/settings/presentation/widgets/adopt_replaced_library_dialog_test.dart`
Expected: PASS.
Run: `flutter analyze lib/features/settings/presentation/pages/cloud_sync_page.dart lib/features/settings/presentation/widgets/adopt_replaced_library_dialog.dart`
Expected: No errors (no unused imports).

- [ ] **Step 5: Commit**

```bash
git add lib/features/settings/presentation/widgets/adopt_replaced_library_dialog.dart lib/features/settings/presentation/pages/cloud_sync_page.dart test/features/settings/presentation/widgets/adopt_replaced_library_dialog_test.dart
git commit -m "refactor(sync): extract reusable adopt-replaced-library dialog"
```

---

## Task 12: Proactive replace detection on launch

**Files:**
- Modify: `lib/features/settings/presentation/providers/sync_providers.dart` (replace the `_detectReplacedLibraryForSurfacing` stub from Task 7)
- Test: same file as Task 5

- [ ] **Step 1: Write the failing test**

Add to `sync_providers_restore_test.dart` (mirror how `sync_providers_epoch_test.dart` seeds a foreign epoch marker via `cloud.seedFile(libraryEpochFileName, ...)`; add the needed imports `dart:convert`, `dart:typed_data`, and `library_epoch.dart`):

```dart
  test('a foreign epoch with local dives arms replaceAwaitingAdoption without '
      'syncing', () async {
    const foreign = LibraryEpochMarker(
      epochId: 'foreign-epoch',
      replacedAt: 1764000000000,
      deviceId: 'mac-device',
      deviceName: 'Eric Mac',
    );
    cloud.seedFile(
      libraryEpochFileName,
      Uint8List.fromList(utf8.encode(jsonEncode(foreign.toJson()))),
    );

    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        cloudStorageProviderProvider.overrideWithValue(cloud),
      ],
    );
    addTearDown(container.dispose);
    await DiveRepository().createDive(createTestDiveWithBottomTime(id: 'd1'));

    final notifier = container.read(syncStateProvider.notifier);
    await notifier.refreshState();
    await notifier.detectReplacedLibraryForSurfacing();

    final state = container.read(syncStateProvider);
    expect(state.replaceAwaitingAdoption, isTrue);
    expect(state.replaceMarker?.epochId, 'foreign-epoch');
  });
```

Add at the top of the file (if not present):

```dart
import 'dart:convert';
import 'dart:typed_data';
import 'package:submersion/core/services/sync/library_epoch.dart';
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/settings/presentation/providers/sync_providers_restore_test.dart --name "arms replaceAwaitingAdoption"`
Expected: FAIL — the method is a no-op stub and is private (rename below makes it callable).

- [ ] **Step 3: Implement the detection**

Replace the Task-7 stub with this (rename it to public so it is directly testable and callable from `_initialize`):

```dart
  /// On a device that did NOT restore, surface a Replace-everywhere adoption
  /// proactively — even with auto-sync off — so the pause is never hidden
  /// behind a manual Sync Now. Detection only; the destructive adopt stays
  /// behind the confirmation dialog.
  Future<void> detectReplacedLibraryForSurfacing() async {
    final marker = await libraryReplaceInfo();
    if (marker == null || !mounted) return;
    final diveCount = await _ref.read(diveRepositoryProvider).getDiveCount();
    if (!mounted) return;
    if (diveCount == 0) {
      // Nothing local to lose: let the existing empty-device auto-adopt path
      // in performSync handle it.
      unawaited(performSync());
    } else {
      state = state.copyWith(
        replaceAwaitingAdoption: true,
        replaceMarker: marker,
      );
    }
  }
```

In `_initialize`, update the final call to use the public name:

```dart
    unawaited(detectReplacedLibraryForSurfacing());
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/settings/presentation/providers/sync_providers_restore_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/settings/presentation/providers/sync_providers.dart test/features/settings/presentation/providers/sync_providers_restore_test.dart
git commit -m "feat(sync): detect a replaced library on launch regardless of auto-sync toggles"
```

---

## Task 13: Add a root navigator key to GoRouter

**Files:**
- Modify: `lib/core/router/app_router.dart` (lines 124-125)

- [ ] **Step 1: Define and pass the key**

Above `final appRouterProvider = Provider<GoRouter>((ref) {` (line 124), add:

```dart
/// Root navigator key, so app-wide modals (e.g. the replaced-library adopt
/// dialog surfaced from the app root) can be shown above the shell.
final rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');
```

Inside `GoRouter(` (line 125), add as the first argument:

```dart
    navigatorKey: rootNavigatorKey,
```

(If a `ShellRoute` is present, leave its own `navigatorKey`/parentNavigatorKey untouched; the root key belongs only to the top-level `GoRouter`.)

- [ ] **Step 2: Verify it compiles and routing still works**

Run: `flutter analyze lib/core/router/app_router.dart`
Expected: No errors.
Run: `flutter test` (smoke — routing-dependent widget tests must still pass)
Expected: No new failures.

- [ ] **Step 3: Commit**

```bash
git add lib/core/router/app_router.dart
git commit -m "feat(router): expose a root navigator key for app-wide dialogs"
```

---

## Task 14: App-root surfacing (notice + adopt dialog + persistent banner)

This is wired with global keys (`_scaffoldMessengerKey`, `rootNavigatorKey`); it is verified manually (Step 4) because app-root global-key surfacing is impractical to unit-test.

**Files:**
- Modify: `lib/app.dart` (imports; add a session flag; add `ref.listen` in `build`; add handler methods)

- [ ] **Step 1: Add imports + session flag**

Add imports (near the existing feature imports):

```dart
import 'package:submersion/core/services/sync/library_epoch.dart';
import 'package:submersion/features/settings/presentation/widgets/adopt_replaced_library_dialog.dart';
```

(`rootNavigatorKey` comes from the already-imported `app_router.dart`.)

In `_SubmersionAppState`, after `final _scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();` (line 68), add:

```dart
  bool _adoptDialogShownThisSession = false;
```

- [ ] **Step 2: Add the listener in `build`**

In `build`, immediately after `ref.watch(reconcileDeviceIdentityProvider);` (line 188), add:

```dart
    // Turn transient sync state into unmissable, screen-independent UI:
    // the post-restore "syncing" notice, and the replaced-library adopt prompt.
    ref.listen<SyncState>(syncStateProvider, _onSyncStateChanged);
```

- [ ] **Step 3: Add the handler methods**

Add these methods to `_SubmersionAppState` (e.g. after `_maybeSyncOnResume`, line 149):

```dart
  void _onSyncStateChanged(SyncState? prev, SyncState next) {
    final ctx = _scaffoldMessengerKey.currentContext;
    final l10n = ctx != null ? AppLocalizations.of(ctx) : null;
    final messenger = _scaffoldMessengerKey.currentState;

    // Post-restore merge notice (start).
    if (next.postRestoreSyncing && !(prev?.postRestoreSyncing ?? false)) {
      messenger?.showSnackBar(
        SnackBar(
          content: Text(
            l10n?.settings_cloudSync_postRestore_syncing ??
                'Syncing your restored library with the cloud…',
          ),
        ),
      );
    }
    // Post-restore merge notice (done).
    if ((prev?.postRestoreSyncing ?? false) &&
        !next.postRestoreSyncing &&
        (next.status == SyncStatus.success ||
            next.status == SyncStatus.hasConflicts)) {
      messenger?.showSnackBar(
        SnackBar(
          content: Text(
            l10n?.settings_cloudSync_postRestore_synced ??
                'Restored library synced.',
          ),
        ),
      );
    }
    // Replaced-library adopt: persistent banner + once-per-session modal.
    if (next.replaceAwaitingAdoption &&
        !(prev?.replaceAwaitingAdoption ?? false)) {
      _surfaceReplaceAdoption(next.replaceMarker);
    }
    if (!next.replaceAwaitingAdoption &&
        (prev?.replaceAwaitingAdoption ?? false)) {
      messenger?.clearMaterialBanners();
    }
  }

  void _surfaceReplaceAdoption(LibraryEpochMarker? marker) {
    if (marker == null) return;
    final ctx = _scaffoldMessengerKey.currentContext;
    final l10n = ctx != null ? AppLocalizations.of(ctx) : null;
    final messenger = _scaffoldMessengerKey.currentState;

    // Persistent banner: rides across every screen until adopted.
    messenger?.clearMaterialBanners();
    messenger?.showMaterialBanner(
      MaterialBanner(
        content: Text(
          l10n?.settings_cloudSync_replace_banner(marker.displayName) ??
              'Sync paused: the library was replaced from a backup. Tap Review.',
        ),
        leading: const Icon(Icons.restore_page_outlined),
        actions: [
          TextButton(
            onPressed: () => _openAdoptDialog(marker),
            child: Text(l10n?.settings_cloudSync_replace_reviewAction ?? 'Review'),
          ),
        ],
      ),
    );

    // Modal once per session.
    if (!_adoptDialogShownThisSession) {
      _adoptDialogShownThisSession = true;
      _openAdoptDialog(marker);
    }
  }

  void _openAdoptDialog(LibraryEpochMarker marker) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final navContext = rootNavigatorKey.currentContext;
      if (navContext == null) return;
      showAdoptReplacedLibraryDialog(navContext, ref, marker);
    });
  }
```

- [ ] **Step 4: Verify (analyze + manual)**

Run: `flutter analyze lib/app.dart`
Expected: No errors.

Manual verification (two real devices or two app data dirs sharing one cloud), document results in the PR:
1. **Merge restore (restoring device):** with Auto Sync OFF, restore a backup, relaunch. Expect a "Syncing your restored library…" SnackBar, then "Restored library synced.", and the Cloud Sync page shows no "First sync needs confirmation" banner.
2. **Replace-everywhere (other device):** on device B (which has local dives), after device A does a Replace restore, launch device B with Auto Sync OFF. Expect the adopt dialog to appear over whatever screen B is on, plus a persistent banner. Dismiss the dialog → banner remains; tap Review → dialog returns. Confirm → safety backup is created, local data is replaced, banner clears.

- [ ] **Step 5: Commit**

```bash
git add lib/app.dart
git commit -m "feat(sync): surface post-restore notice and replaced-library adopt at the app root"
```

---

## Task 15: Two-device convergence integration test

**Files:**
- Create: `test/core/services/sync/restore_resume_convergence_test.dart`

This asserts the end-to-end Merge outcome that the original bug broke: after a restore-style rebaseline, a device with the established anchor + pending intent converges with a peer without manual intervention. Model it on `test/core/services/sync/changeset_sync_convergence_test.dart` (Device A publishes to a shared fake cloud; Device B, anchored + intent-armed, syncs and pulls A's dive).

- [ ] **Step 1: Write the test**

```dart
// test/core/services/sync/restore_resume_convergence_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/established_provider_store.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/core/services/sync/sync_service.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';

import '../../../helpers/fake_cloud_storage_provider.dart';
import '../../../helpers/mock_providers.dart';
import '../../../helpers/test_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('an established device pulls a peer dive after a restore-style rebaseline',
      () async {
    final cloud = FakeCloudStorageProvider();

    // Device A: create a dive and publish.
    await setUpTestDatabase();
    var svc = SyncService(
      syncRepository: SyncRepository(),
      serializer: SyncDataSerializer(),
      cloudProvider: cloud,
    );
    await DiveRepository()
        .createDive(createTestDiveWithBottomTime(id: 'a1', diveNumber: 1));
    expect((await svc.performSync()).status, SyncResultStatus.success);
    await tearDownTestDatabase();

    // Device B: fresh DB, same cloud, marked established (as if it had synced
    // here before a restore wiped its cursor). A direct performSync mirrors the
    // forced post-restore sync (auto:false, no gate).
    SharedPreferences.setMockInitialValues({});
    await EstablishedProviderStore(await SharedPreferences.getInstance())
        .add(cloud.providerId);
    await setUpTestDatabase();
    svc = SyncService(
      syncRepository: SyncRepository(),
      serializer: SyncDataSerializer(),
      cloudProvider: cloud,
    );
    expect((await svc.performSync()).status, SyncResultStatus.success);

    final row = await DatabaseService.instance.database
        .customSelect("SELECT id FROM dives WHERE id = 'a1'")
        .getSingleOrNull();
    expect(row, isNotNull,
        reason: 'device B must converge with A without a manual Sync Now');
    await tearDownTestDatabase();
  });
}
```

- [ ] **Step 2: Run it**

Run: `flutter test test/core/services/sync/restore_resume_convergence_test.dart`
Expected: PASS.

- [ ] **Step 3: Commit**

```bash
git add test/core/services/sync/restore_resume_convergence_test.dart
git commit -m "test(sync): restore-resume two-device convergence"
```

---

## Task 16: Final verification

- [ ] **Step 1: Format**

Run: `dart format lib/ test/`
Expected: reformats only touched files (commit if anything changed).

- [ ] **Step 2: Analyze (whole project)**

Run: `flutter analyze`
Expected: No issues (matches the project's pre-push hook).

- [ ] **Step 3: Full test suite**

Run: `flutter test`
Expected: All pass.

- [ ] **Step 4: Commit any formatting**

```bash
git add -u
git commit -m "style: dart format" # only if Step 1 changed files
```

- [ ] **Step 5: Push and open the PR (only when the user asks)**

```bash
git push -u origin feat/smoother-restore-sync
gh pr create --base main --title "feat(sync): smoother database restore (auto-resume merge, unmissable replace-adopt)" --body "Implements docs/superpowers/specs/2026-06-15-smoother-restore-sync-design.md"
```

---

## Self-Review

**Spec coverage:** D1 auto-resume + notice → Tasks 7, 14. D2 force one sync regardless of toggles → Task 7 (`_initialize` `performSync(auto:false)`). D3 unmissable confirm → Tasks 11-14. D4 mirror intent + root anchor → Tasks 1-9. Localization → Task 10. Edge cases: intent cleared on success / retained on failure → Task 6; Reset clears anchor+intent → Task 8; branch precedence (Replace before Merge) → Task 7 `_initialize`; per-provider anchor scoping → Task 2. Testing → Tasks 1-12, 15. Verification → Task 16. All spec sections map to a task.

**Placeholder scan:** No "TBD"/"handle errors"/"similar to" — the only deferred reference (`_detectReplacedLibraryForSurfacing` used in Task 7 before Task 12) is resolved by an explicit compiling stub in Task 7.

**Type consistency:** `PostRestoreSyncStore` (`pending`/`setPending`/`clear`), `EstablishedProviderStore` (`contains`/`add`/`clear`), provider names (`postRestoreSyncStoreProvider`, `establishedProviderStoreProvider`), `SyncState.postRestoreSyncing`, `detectReplacedLibraryForSurfacing` (public in Task 12, called in Task 7 via stub then renamed), `showAdoptReplacedLibraryDialog`, and `rootNavigatorKey` are used consistently across tasks.
