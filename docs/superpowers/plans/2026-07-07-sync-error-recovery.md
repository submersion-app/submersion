# Sync Error Recovery Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give users a reliable in-app way out of any wedged Cloud Sync state without a reinstall, and fix the two reported dead-ends at the source.

**Architecture:** A new Troubleshoot Sync screen (reached from the Cloud Sync page's Advanced section and by tapping the sync-error banner) hosts escalating recovery actions. Under it: (1) a comprehensive local "Repair Sync" that clears every local sync store including the SharedPreferences epoch markers today's Reset misses; (2) two active-provider cloud-clear actions; (3) a "rebuild this backend from this device" escape for a stuck library-epoch adoption. Separately, sync temp files move off `/tmp` to the app-container temp dir, fixing the #509 `PathAccessException`.

**Tech Stack:** Flutter, Riverpod (`StateNotifier`), Drift, `shared_preferences`, `path_provider`, `flutter_test`.

## Global Constraints

- Dart must pass `dart format .` with no changes (CI checks the whole project).
- `flutter analyze` must be clean (whole project).
- New user-facing strings are added to `lib/l10n/arb/app_en.arb` and translated into all 10 non-en locales (`ar, de, es, fr, he, hu, it, nl, pt, zh`), then `flutter gen-l10n` is run. (Where an existing plain `const Text('…')` pattern is already used in this page, e.g. "Reset Sync State", matching that literal-string style is acceptable to stay consistent — see each task.)
- Never touch dive data in any recovery action; only sync bookkeeping and cloud sync artifacts.
- Cloud-clear actions operate on the **active** provider only.
- New worktrees need codegen: if `database.g.dart` is missing, run `dart run build_runner build --delete-conflicting-outputs` before tests.
- Native/DB tests: run specific test files (not broad dirs) to avoid Bash timeouts.

---

## PR 1 — Temp-dir fix, comprehensive local Repair, Troubleshoot screen

### Task 1: Route sync base temp files to the app-container temp dir (fixes #509)

**Why:** `exportBaseToTempFile` and `BasePartFileSink` default their temp dir to `Directory.systemTemp`, which is `/tmp` on macOS. A hardened-runtime/sandboxed app is denied there → `PathAccessException: … path = '/tmp/ssv1_base_…json' (Operation not permitted, errno = 1)` on every publish/adopt. `path_provider`'s `getTemporaryDirectory()` returns the always-accessible app-container temp dir (already used in `backup_service.dart`).

**Files:**
- Modify: `lib/core/services/sync/sync_data_serializer.dart:728-732`
- Modify: `lib/core/services/sync/changeset_log/base_part_file_sink.dart:14-18`
- Test: `test/core/services/sync/changeset_log/base_part_file_sink_test.dart`

**Interfaces:**
- Produces: unchanged public signatures; only the *default* temp dir changes. `exportBaseToTempFile({… Future<Directory> Function()? tempDir})` and `BasePartFileSink({Future<Directory> Function()? tempDirProvider})` keep their injectable seams for tests.

- [ ] **Step 1: Write the failing test** (assert the default dir is the app temp dir, not systemTemp)

Add to `base_part_file_sink_test.dart` (create if absent; mock the `path_provider` channel exactly as `backup_service_leased_test.dart` does):

```dart
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/sync/changeset_log/base_part_file_sink.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory fakeAppTemp;

  setUpAll(() async {
    fakeAppTemp = await Directory.systemTemp.createTemp('app_temp_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async =>
          call.method == 'getTemporaryDirectory' ? fakeAppTemp.path : null,
    );
  });

  test('assemble writes into the app-container temp dir by default', () async {
    final sink = BasePartFileSink(); // no injected dir -> uses the default
    final path = await sink.assemble(
      name: 'ssv1_base_dev_0',
      partCount: 1,
      wholeChecksum: null,
      partChecksums: const [],
      downloadPart: (_) async => Uint8List.fromList([1, 2, 3]),
    );
    expect(path, isNotNull);
    expect(path!.startsWith(fakeAppTemp.path), isTrue,
        reason: 'must not fall back to /tmp (systemTemp)');
    await sink.deleteQuietly(path);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/services/sync/changeset_log/base_part_file_sink_test.dart`
Expected: FAIL — the default is `Directory.systemTemp`, so `path` starts with the system temp path, not `fakeAppTemp.path`.

- [ ] **Step 3: Change the `BasePartFileSink` default**

In `base_part_file_sink.dart`:

```dart
import 'package:path_provider/path_provider.dart';
// ...
class BasePartFileSink {
  BasePartFileSink({Future<Directory> Function()? tempDirProvider})
    : _tempDir = tempDirProvider ?? getTemporaryDirectory;
  // ...
}
```

- [ ] **Step 4: Change the `exportBaseToTempFile` default**

In `sync_data_serializer.dart` (ensure `import 'package:path_provider/path_provider.dart';` is present):

```dart
final dir = await (tempDir?.call() ?? getTemporaryDirectory());
```

(Replaces `Future.value(Directory.systemTemp)`.)

- [ ] **Step 5: Run tests to verify they pass**

Run: `flutter test test/core/services/sync/changeset_log/base_part_file_sink_test.dart test/core/services/sync/sync_data_serializer_test.dart`
Expected: PASS. (If `sync_data_serializer_test.dart` constructs the serializer and calls `exportBaseToTempFile` without injecting `tempDir`, add the same `path_provider` mock to its `setUpAll`.)

- [ ] **Step 6: Format, analyze, commit**

```bash
dart format lib/core/services/sync/sync_data_serializer.dart lib/core/services/sync/changeset_log/base_part_file_sink.dart test/core/services/sync/changeset_log/base_part_file_sink_test.dart
flutter analyze lib/core/services/sync/sync_data_serializer.dart lib/core/services/sync/changeset_log/base_part_file_sink.dart
git add -A && git commit -m "fix(sync): write base temp files to the app temp dir, not /tmp (#509)"
```

---

### Task 2: `LibraryEpochStore.clear()`

**Why:** The last-accepted epoch marker (`sync_last_accepted_epoch_marker`) is the one local sync state today's Reset does not clear — it lives in SharedPreferences, survives DB reset, and only a reinstall wiped it.

**Files:**
- Modify: `lib/core/services/sync/library_epoch_store.dart`
- Test: `test/core/services/sync/library_epoch_store_test.dart`

**Interfaces:**
- Produces: `Future<void> LibraryEpochStore.clear()` — removes both `sync_last_accepted_epoch_marker` and `sync_pending_replace_marker`.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/services/sync/library_epoch.dart';
import 'package:submersion/core/services/sync/library_epoch_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('clear() removes both the last-accepted and pending-replace markers',
      () async {
    SharedPreferences.setMockInitialValues({});
    final store = LibraryEpochStore(await SharedPreferences.getInstance());
    final marker = LibraryEpochMarker(
      epochId: 'e1',
      movedFrom: null,
      deviceId: 'd1',
      createdAt: 1,
    );
    await store.setLastAccepted(marker);
    await store.setPendingReplace(marker);

    await store.clear();

    expect(store.lastAcceptedMarker, isNull);
    expect(store.pendingReplace, isNull);
  });
}
```

(Confirm the `LibraryEpochMarker` constructor field names in `lib/core/services/sync/library_epoch.dart` and adjust the literal above to match before running.)

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/services/sync/library_epoch_store_test.dart`
Expected: FAIL — `clear` is not defined on `LibraryEpochStore`.

- [ ] **Step 3: Implement `clear()`**

In `library_epoch_store.dart`:

```dart
/// Wipe both epoch records. Used by the comprehensive local sync repair: the
/// last-accepted marker is the only local sync state a DB reset does not
/// touch (it is in SharedPreferences), so a wedge that survives Reset needs
/// this to be a true reinstall-equivalent.
Future<void> clear() async {
  await _prefs.remove(_lastAcceptedMarkerKey);
  await _prefs.remove(_pendingReplaceKey);
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/services/sync/library_epoch_store_test.dart`
Expected: PASS.

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format lib/core/services/sync/library_epoch_store.dart test/core/services/sync/library_epoch_store_test.dart
flutter analyze lib/core/services/sync/library_epoch_store.dart
git add -A && git commit -m "feat(sync): add LibraryEpochStore.clear() for comprehensive local repair"
```

---

### Task 3: `SyncService.repairLocalSyncState()` + notifier `repairSync()`

**Why:** One comprehensive local reset that is a true reinstall-equivalent: everything the current Reset does, PLUS clearing the last-accepted epoch marker and leftover base temp files, then clearing the error banner. This is the guaranteed local escape.

**Files:**
- Modify: `lib/core/services/sync/sync_service.dart` (add method near `resetSyncState`, ~line 2002)
- Modify: `lib/features/settings/presentation/providers/sync_providers.dart` (add `repairSync()` to `SyncNotifier`, near `resetSyncState`, ~line 907)
- Test: `test/core/services/sync/sync_service_repair_test.dart`

**Interfaces:**
- Consumes: `LibraryEpochStore.clear()` (Task 2); existing `SyncService.resetSyncState()`, `_epochStore`, `_baseSink` (`BasePartFileSink`).
- Produces:
  - `Future<void> SyncService.repairLocalSyncState()` — calls `resetSyncState()`, `_epochStore?.clear()`, and best-effort deletes leftover `ssv1_base_*` / `*.base` files from the app temp dir.
  - `Future<void> SyncNotifier.repairSync()` — runs the full provider-level reset (fresh identity, this-device cloud file removal, etc. — reusing the existing `resetSyncState()` body) then `repairLocalSyncState`'s extra clears, and sets `state` back to idle with no error.

- [ ] **Step 1: Write the failing test** (service clears the epoch store and leftover temp files)

```dart
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
// import the SyncService + fakes following the pattern in existing
// test/core/services/sync/*_test.dart files (fake SyncRepository, in-memory
// AppDatabase, a real LibraryEpochStore over SharedPreferences.setMockInitialValues).

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('repairLocalSyncState clears the epoch store', () async {
    // Arrange: build a SyncService with a real LibraryEpochStore holding a
    // last-accepted marker (see Task 2 for marker construction) and a fake
    // SyncRepository whose resetSyncState records that it was called.
    // Act:
    await service.repairLocalSyncState();
    // Assert:
    expect(epochStore.lastAcceptedMarker, isNull);
    expect(fakeRepo.resetSyncStateCalled, isTrue);
  });
}
```

(Follow the construction/fakes used by the nearest existing `sync_service` test. If none constructs `SyncService` directly, add a minimal fake `SyncRepository` exposing `resetSyncState` and reuse the in-memory DB helper already in the test suite.)

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/services/sync/sync_service_repair_test.dart`
Expected: FAIL — `repairLocalSyncState` not defined.

- [ ] **Step 3: Implement `repairLocalSyncState`**

In `sync_service.dart`:

```dart
/// Comprehensive local sync reset: everything [resetSyncState] clears, PLUS
/// the SharedPreferences epoch markers (the one local sync state a DB reset
/// misses) and any leftover base temp files. A true reinstall-equivalent for
/// sync state that never touches dive data. The caller (notifier) still runs
/// the provider-level identity/cloud-file cleanup.
Future<void> repairLocalSyncState() async {
  await resetSyncState();
  await _epochStore?.clear();
  await _deleteLeftoverBaseTempFiles();
}

Future<void> _deleteLeftoverBaseTempFiles() async {
  try {
    final dir = await getTemporaryDirectory();
    await for (final e in dir.list(followLinks: false)) {
      if (e is! File) continue;
      final name = e.uri.pathSegments.last;
      if (name.startsWith('ssv1_base_') || name.endsWith('.base')) {
        try {
          await e.delete();
        } catch (_) {/* best effort */}
      }
    }
  } catch (e) {
    _log.warning('Could not sweep leftover base temp files: $e');
  }
}
```

(Add `import 'package:path_provider/path_provider.dart';` if not present.)

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/services/sync/sync_service_repair_test.dart`
Expected: PASS.

- [ ] **Step 5: Add the notifier `repairSync()`**

In `sync_providers.dart`, add to `SyncNotifier` (reuse the existing `resetSyncState()` body, then the extra clears):

```dart
/// Comprehensive local repair: the full Reset (fresh identity, this device's
/// cloud file removed, pending-replace/awaiting-adoption cleared) PLUS the
/// last-accepted epoch marker and leftover base temp files, ending with the
/// error cleared. The guaranteed local escape from a wedged sync.
Future<void> repairSync() async {
  await resetSyncState(); // existing: fresh identity + cloud-file + markers
  await _ref.read(libraryEpochStoreProvider).clear();
  await _syncService.repairLocalSyncState();
  state = state.copyWith(status: SyncStatus.idle, message: null);
  await refreshState();
}
```

(Note: `repairLocalSyncState` internally calls `resetSyncState` again; that is idempotent and safe. If preferred for tightness, split the temp-file sweep into a public `SyncService.deleteLeftoverBaseTempFiles()` and call only that here — either is acceptable, keep whichever keeps the test in Step 1 green.)

- [ ] **Step 6: Format, analyze, commit**

```bash
dart format lib/core/services/sync/sync_service.dart lib/features/settings/presentation/providers/sync_providers.dart test/core/services/sync/sync_service_repair_test.dart
flutter analyze lib/core/services/sync/sync_service.dart lib/features/settings/presentation/providers/sync_providers.dart
git add -A && git commit -m "feat(sync): comprehensive local Repair (reset + epoch markers + temp sweep)"
```

---

### Task 4: Troubleshoot Sync screen + Advanced entry (replaces the standalone Reset tile), wired to Repair

**Why:** One discoverable home for recovery, with plain-language actions. Replacing the lone "Reset Sync State" tile avoids two near-identical reset buttons — Repair is the superset.

**Files:**
- Create: `lib/features/settings/presentation/pages/troubleshoot_sync_page.dart`
- Modify: `lib/features/settings/presentation/pages/cloud_sync_page.dart:1185-1198` (Advanced section: replace the "Reset Sync State" `ListTile` with a "Troubleshoot Sync" tile that navigates to the new page; keep "Sign Out")
- Test: `test/features/settings/presentation/pages/troubleshoot_sync_page_test.dart`

**Interfaces:**
- Consumes: `syncStateProvider` notifier `repairSync()` (Task 3).
- Produces: `TroubleshootSyncPage` widget (a `ConsumerWidget`) with a "Repair Sync" `ListTile` that shows a confirm dialog then calls `repairSync()`. (Cloud-clear + rebuild tiles are added by PR 2 Tasks 8/9.)

- [ ] **Step 1: Write the failing widget test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:submersion/features/settings/presentation/pages/troubleshoot_sync_page.dart';

void main() {
  testWidgets('shows Repair Sync action with an explanation', (tester) async {
    await tester.pumpWidget(const ProviderScope(
      child: MaterialApp(home: TroubleshootSyncPage()),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Repair Sync'), findsOneWidget);
    expect(find.textContaining('dive data'), findsWidgets); // "data is safe"
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/settings/presentation/pages/troubleshoot_sync_page_test.dart`
Expected: FAIL — file/type does not exist.

- [ ] **Step 3: Implement `TroubleshootSyncPage`** (mirror the existing page's `ListTile` + `showDialog` idioms from `cloud_sync_page.dart`)

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:submersion/features/settings/presentation/providers/sync_providers.dart';

class TroubleshootSyncPage extends ConsumerWidget {
  const TroubleshootSyncPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Troubleshoot Sync')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.healing),
            title: const Text('Repair Sync'),
            subtitle: const Text(
              'Fix a stuck sync. Clears this device’s sync state and gives '
              'it a fresh sync identity. Your dive data is not affected.',
            ),
            onTap: () => _confirmRepair(context, ref),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmRepair(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Repair Sync?'),
        content: const Text(
          'This clears all local sync state and gives this device a new sync '
          'identity, then reconnects fresh on the next sync. Your dive data is '
          'safe and is not deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Repair'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(syncStateProvider.notifier).repairSync();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sync repaired')),
      );
    }
  }
}
```

- [ ] **Step 4: Wire the Advanced entry** — in `cloud_sync_page.dart` `_buildAdvancedSection`, replace the "Reset Sync State" `ListTile` with:

```dart
ListTile(
  leading: const Icon(Icons.build),
  title: const Text('Troubleshoot Sync'),
  subtitle: const Text('Fix a stuck sync or free cloud space'),
  onTap: () => Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => const TroubleshootSyncPage()),
  ),
),
```

(Add the import for `troubleshoot_sync_page.dart`. Remove the now-unused `_confirmResetSyncState` method only if nothing else references it; otherwise leave it. Keep "Sign Out".)

- [ ] **Step 5: Run tests to verify they pass**

Run: `flutter test test/features/settings/presentation/pages/troubleshoot_sync_page_test.dart`
Expected: PASS.

- [ ] **Step 6: Format, analyze, commit**

```bash
dart format lib/features/settings/presentation/pages/troubleshoot_sync_page.dart lib/features/settings/presentation/pages/cloud_sync_page.dart test/features/settings/presentation/pages/troubleshoot_sync_page_test.dart
flutter analyze lib/features/settings/presentation/pages
git add -A && git commit -m "feat(sync): Troubleshoot Sync screen with Repair Sync action"
```

---

### Task 5: Make the sync-error banner tappable → Troubleshoot Sync

**Why:** A stuck user should find the exit where the error is shown, not only under Advanced.

**Files:**
- Modify: `lib/features/settings/presentation/pages/cloud_sync_page.dart:316-410` (`_buildSyncStatusCard`; wrap the error card in an `InkWell`/`onTap` when `syncState.status == SyncStatus.error`)
- Test: `test/features/settings/presentation/pages/cloud_sync_page_test.dart` (add a case; reuse the file's existing harness/overrides)

**Interfaces:**
- Consumes: `SyncStatus.error` from `syncStateProvider`; `TroubleshootSyncPage` (Task 4).

- [ ] **Step 1: Write the failing widget test** — seed an error `SyncState`, tap the "Sync error" card, expect the Troubleshoot page. (Model the harness on the existing tests in this file; if it seeds providers via `ProviderScope` overrides, override `syncStateProvider` to a notifier in `SyncStatus.error`.)

```dart
testWidgets('tapping the sync error banner opens Troubleshoot Sync',
    (tester) async {
  // pump CloudSyncPage with syncState.status == SyncStatus.error (see existing
  // test harness in this file for provider overrides)
  await tester.tap(find.text('Sync error'));
  await tester.pumpAndSettle();
  expect(find.text('Troubleshoot Sync'), findsOneWidget); // the page's AppBar
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/settings/presentation/pages/cloud_sync_page_test.dart`
Expected: FAIL — the banner is not tappable; Troubleshoot page does not open.

- [ ] **Step 3: Implement** — in `_buildSyncStatusCard`, when the status is error, wrap the card body so the whole card is tappable:

```dart
// inside the SyncStatus.error branch of the status card:
return Card(
  color: Theme.of(context).colorScheme.errorContainer,
  child: InkWell(
    onTap: () => Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const TroubleshootSyncPage()),
    ),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Row(children: [/* existing icon + title + message + a chevron */]),
    ),
  ),
);
```

(Keep the existing icon/title/message content; add a trailing `Icon(Icons.chevron_right)` to signal tappability. Only the error state becomes tappable; leave the other statuses unchanged.)

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/settings/presentation/pages/cloud_sync_page_test.dart`
Expected: PASS.

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format lib/features/settings/presentation/pages/cloud_sync_page.dart test/features/settings/presentation/pages/cloud_sync_page_test.dart
flutter analyze lib/features/settings/presentation/pages/cloud_sync_page.dart
git add -A && git commit -m "feat(sync): tap the sync error banner to open Troubleshoot Sync"
```

**End of PR 1.** Open a PR titled `feat(sync): sync error recovery — temp-dir fix, Repair Sync, Troubleshoot screen (#509)`.

---

## PR 2 — Cloud clear + offline-uploader escape

### Task 6: "Remove this device's cloud sync files" (3a)

**Why:** Free this device's share of the folder without disturbing peers.

**Files:**
- Modify: `lib/core/services/sync/sync_service.dart` (`deleteDeviceSyncFile`, ~line 2012 — confirm it removes this device's base parts and conflict copies too, not just the manifest/log; extend via `ChangesetLogLayout` if needed)
- Modify: `lib/features/settings/presentation/providers/sync_providers.dart` (add `removeThisDeviceCloudFiles()`)
- Test: `test/core/services/sync/sync_service_cloud_clear_test.dart` (fake `CloudStorageProvider` recording deleted file ids)

**Interfaces:**
- Consumes: `SyncRepository.getDeviceId()`; a fake `CloudStorageProvider` with `listFiles(namePattern:)` / `deleteFile(id)`.
- Produces:
  - `deleteDeviceSyncFile(String deviceId)` deletes every cloud file whose `ChangesetLogLayout.deviceIdOf(name) == deviceId` (manifest, base parts, changesets, conflict copies).
  - `Future<void> SyncNotifier.removeThisDeviceCloudFiles()`.

- [ ] **Step 1: Write the failing test** — a fake provider returns several files for two device ids across the log patterns; assert only this device's are deleted.

```dart
test('deleteDeviceSyncFile removes only this device’s files (all parts)',
    () async {
  final provider = FakeCloudProvider(files: [
    fakeFile('ssv1.dev1.manifest.json'),
    fakeFile('ssv1.dev1.base.0.json'),
    fakeFile('ssv1.dev1.cs.5.json'),
    fakeFile('ssv1.dev2.manifest.json'),
  ]);
  await service.deleteDeviceSyncFile('dev1'); // service built with `provider`
  expect(provider.deletedNames, containsAll(<String>[
    'ssv1.dev1.manifest.json', 'ssv1.dev1.base.0.json', 'ssv1.dev1.cs.5.json',
  ]));
  expect(provider.deletedNames, isNot(contains('ssv1.dev2.manifest.json')));
});
```

(Use the real `ChangesetLogLayout` file-name shapes — read `changeset_log_layout.dart` for the exact `prefix`, `deviceIdOf`, and part-name format, and build `fakeFile` names accordingly.)

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/services/sync/sync_service_cloud_clear_test.dart`
Expected: FAIL if the current `deleteDeviceSyncFile` misses base parts/conflict copies (or PASS if `deviceIdOf` already matches every part — in which case this task only adds the notifier method + test, and Step 3 is a no-op).

- [ ] **Step 3: Ensure `deleteDeviceSyncFile` covers all of this device's files**

Verify the loop in `deleteDeviceSyncFile` matches every file where `ChangesetLogLayout.deviceIdOf(f.name) == deviceId`. If conflict-copy names are not covered by that predicate, extend the match to include them (read `ChangesetLogLayout` for the conflict-copy naming). Keep it best-effort (per-file try/catch, timeouts) exactly as the existing method does.

- [ ] **Step 4: Add the notifier method**

```dart
/// Remove THIS device's sync files from the active backend. Safe: other
/// devices keep syncing; frees this device's share of the folder.
Future<void> removeThisDeviceCloudFiles() async {
  final deviceId = await _syncRepository.getDeviceId();
  await _syncService.deleteDeviceSyncFile(deviceId);
  await refreshState();
}
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `flutter test test/core/services/sync/sync_service_cloud_clear_test.dart`
Expected: PASS.

- [ ] **Step 6: Format, analyze, commit**

```bash
dart format lib/core/services/sync/sync_service.dart lib/features/settings/presentation/providers/sync_providers.dart test/core/services/sync/sync_service_cloud_clear_test.dart
flutter analyze lib/core/services/sync/sync_service.dart
git add -A && git commit -m "feat(sync): remove this device's cloud sync files (Troubleshoot)"
```

---

### Task 7: "Wipe ALL sync data on this backend" incl. epoch markers (3b)

**Why:** The ultimate reset — reclaims all space and forces every device to re-establish. The existing `deleteAllSyncFiles` deliberately leaves the `submersion_library_*` epoch markers; a true fresh start must also delete them.

**Files:**
- Modify: `lib/core/services/sync/sync_service.dart` (add `wipeAllSyncData(provider)` that calls `deleteAllSyncFiles(provider)` then deletes the epoch/moved markers)
- Modify: `lib/features/settings/presentation/providers/sync_providers.dart` (add `wipeAllCloudSyncData()`)
- Test: `test/core/services/sync/sync_service_cloud_clear_test.dart` (extend)

**Interfaces:**
- Consumes: `deleteAllSyncFiles(CloudStorageProvider)`; the epoch-marker file-name pattern (read the `submersion_library_*` constant used by the epoch protocol / `readLibraryEpochMarker`).
- Produces:
  - `Future<void> SyncService.wipeAllSyncData(CloudStorageProvider provider)`.
  - `Future<void> SyncNotifier.wipeAllCloudSyncData()` (operates on the active `_cloudProvider`).

- [ ] **Step 1: Write the failing test** — fake provider returns log files AND a `submersion_library_*` marker; assert `wipeAllSyncData` deletes both.

```dart
test('wipeAllSyncData deletes logs AND the epoch markers', () async {
  final provider = FakeCloudProvider(files: [
    fakeFile('ssv1.dev1.manifest.json'),
    fakeFile('submersion_library_epoch.json'),
  ]);
  await service.wipeAllSyncData(provider);
  expect(provider.deletedNames, containsAll(<String>[
    'ssv1.dev1.manifest.json', 'submersion_library_epoch.json',
  ]));
});
```

(Use the real epoch-marker name pattern from the epoch protocol code.)

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/services/sync/sync_service_cloud_clear_test.dart`
Expected: FAIL — `wipeAllSyncData` not defined; `deleteAllSyncFiles` alone leaves the marker.

- [ ] **Step 3: Implement `wipeAllSyncData`**

```dart
/// Delete EVERY sync artifact on [provider], including the library epoch
/// markers that [deleteAllSyncFiles] intentionally preserves. A genuine fresh
/// start: every device re-establishes. Best-effort; failures are logged.
Future<void> wipeAllSyncData(CloudStorageProvider provider) async {
  await deleteAllSyncFiles(provider);
  try {
    final markers = await provider
        .listFiles(namePattern: /* submersion_library_ prefix constant */)
        .timeout(const Duration(seconds: 8));
    for (final f in markers) {
      try {
        await provider.deleteFile(f.id).timeout(const Duration(seconds: 8));
        _log.info('Deleted epoch marker ${f.name} for full sync wipe');
      } catch (e) {
        _log.warning('Could not delete epoch marker ${f.name}: $e');
      }
    }
  } catch (e) {
    _log.warning('Could not list epoch markers for wipe: $e');
  }
}
```

(Replace the comment with the actual epoch-marker name-pattern constant.)

- [ ] **Step 4: Add the notifier method**

```dart
/// Wipe ALL sync data on the active backend, including epoch markers. Every
/// device re-establishes from scratch.
Future<void> wipeAllCloudSyncData() async {
  await _syncService.wipeAllSyncDataOnActiveProvider(); // thin wrapper over
  // wipeAllSyncData(_cloudProvider); or expose _cloudProvider access as needed
  await refreshState();
}
```

(If `_cloudProvider` is private to `SyncService`, add a `SyncService.wipeAllSyncDataOnActiveProvider()` that no-ops when null and otherwise calls `wipeAllSyncData(_cloudProvider!)`. Keep whichever wiring compiles and keeps Step 1's test — which targets `wipeAllSyncData(provider)` directly — green.)

- [ ] **Step 5: Run tests to verify they pass**

Run: `flutter test test/core/services/sync/sync_service_cloud_clear_test.dart`
Expected: PASS.

- [ ] **Step 6: Format, analyze, commit**

```bash
dart format lib/core/services/sync/sync_service.dart lib/features/settings/presentation/providers/sync_providers.dart test/core/services/sync/sync_service_cloud_clear_test.dart
flutter analyze lib/core/services/sync/sync_service.dart
git add -A && git commit -m "feat(sync): wipe all cloud sync data incl. epoch markers"
```

---

### Task 8: Cloud-clear actions on the Troubleshoot screen (3a standard confirm, 3b typed confirm)

**Files:**
- Modify: `lib/features/settings/presentation/pages/troubleshoot_sync_page.dart` (add two tiles)
- Test: `test/features/settings/presentation/pages/troubleshoot_sync_page_test.dart` (extend)

**Interfaces:**
- Consumes: `SyncNotifier.removeThisDeviceCloudFiles()` (Task 6), `SyncNotifier.wipeAllCloudSyncData()` (Task 7).

- [ ] **Step 1: Write the failing widget tests**

```dart
testWidgets('shows both cloud-clear actions', (tester) async {
  await tester.pumpWidget(const ProviderScope(
      child: MaterialApp(home: TroubleshootSyncPage())));
  await tester.pumpAndSettle();
  expect(find.text('Remove this device’s cloud files'), findsOneWidget);
  expect(find.text('Wipe all sync data on this backend'), findsOneWidget);
});

testWidgets('wipe-all requires typed confirmation', (tester) async {
  await tester.pumpWidget(const ProviderScope(
      child: MaterialApp(home: TroubleshootSyncPage())));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Wipe all sync data on this backend'));
  await tester.pumpAndSettle();
  final confirmBtn = find.widgetWithText(FilledButton, 'Wipe everything');
  expect(tester.widget<FilledButton>(confirmBtn).onPressed, isNull); // disabled
  await tester.enterText(find.byType(TextField), 'WIPE');
  await tester.pump();
  expect(tester.widget<FilledButton>(confirmBtn).onPressed, isNotNull);
});
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/settings/presentation/pages/troubleshoot_sync_page_test.dart`
Expected: FAIL — the tiles/dialogs don't exist yet.

- [ ] **Step 3: Implement** — add two `ListTile`s below Repair. 3a uses a standard confirm dialog calling `removeThisDeviceCloudFiles()`. 3b uses a dialog with a `TextField` whose `onChanged` enables the "Wipe everything" `FilledButton` only when the text equals `WIPE`, then calls `wipeAllCloudSyncData()`. (Use `StatefulBuilder` inside `showDialog` for the enable-on-type behavior; model spacing/layout on the existing dialogs in `cloud_sync_page.dart`.)

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/settings/presentation/pages/troubleshoot_sync_page_test.dart`
Expected: PASS.

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format lib/features/settings/presentation/pages/troubleshoot_sync_page.dart test/features/settings/presentation/pages/troubleshoot_sync_page_test.dart
flutter analyze lib/features/settings/presentation/pages/troubleshoot_sync_page.dart
git add -A && git commit -m "feat(sync): cloud-clear actions on Troubleshoot screen"
```

---

### Task 9: Offline-uploader escape — "rebuild this backend from this device" (2a)

**Why:** When the replacing device is offline, `adoptReplacedLibrary` finds no base for the epoch and returns a terminal "still uploading, try again shortly". Give the waiting device a concrete action to republish its own library as the current epoch's base, resolving the wedge on the cloud side.

**Files:**
- Modify: `lib/core/services/sync/sync_service.dart` (add `rebuildBackendFromThisDevice()`; reuse `_recoverUnreadableEpoch` / the re-establish path already invoked at `adoptReplacedLibrary` ~line 2181)
- Modify: `lib/features/settings/presentation/providers/sync_providers.dart` (expose `rebuildBackendFromThisDevice()`)
- Modify: `lib/features/settings/presentation/pages/troubleshoot_sync_page.dart` (add a tile, shown when awaiting adoption / after a "still uploading" result)
- Test: `test/core/services/sync/sync_service_repair_test.dart` (extend)

**Interfaces:**
- Consumes: existing `readLibraryEpochMarker`, `_recoverUnreadableEpoch`, `executeLibraryReplace`.
- Produces:
  - `Future<SyncResult> SyncService.rebuildBackendFromThisDevice()` — reads the current epoch marker and re-establishes the backend from this device's library (publishes a base for the current epoch), so peers/this device stop waiting on the offline uploader.
  - `Future<SyncResult> SyncNotifier.rebuildBackendFromThisDevice()`.

- [ ] **Step 1: Write the failing test** — with a current-epoch marker present but no base for it, `rebuildBackendFromThisDevice()` returns success and publishes this device's base (assert via the fake provider that a base for the current epoch was written).

```dart
test('rebuildBackendFromThisDevice re-establishes the epoch from local library',
    () async {
  // Arrange: epoch marker E present in the fake cloud, no base for E.
  final result = await service.rebuildBackendFromThisDevice();
  expect(result.status, SyncResultStatus.success);
  // Assert the fake provider received an upload stamped with epoch E.
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/services/sync/sync_service_repair_test.dart`
Expected: FAIL — method not defined.

- [ ] **Step 3: Implement `rebuildBackendFromThisDevice`** — read the current marker via `readLibraryEpochMarker(provider)`; call the existing re-establish path (`_recoverUnreadableEpoch(provider, marker)` returns true on success) or `executeLibraryReplace` with the current marker so this device's library becomes the epoch's authoritative base. Return `SyncResult(status: success, message: 'Rebuilt this backend from this device’s library')`, or an error `SyncResult` if no marker/provider.

- [ ] **Step 4: Make the adopt wait actionable** — in `adoptReplacedLibrary` (~line 2189-2193), keep returning an error `SyncResult`, but ensure the notifier surfaces the *awaiting adoption* state (the code already has `replaceAwaitingAdoption`) so the Troubleshoot tile appears. Add the notifier + UI tile (guarded by awaiting-adoption / a "still uploading" result) that calls `rebuildBackendFromThisDevice()`.

- [ ] **Step 5: Run tests to verify they pass**

Run: `flutter test test/core/services/sync/sync_service_repair_test.dart test/features/settings/presentation/pages/troubleshoot_sync_page_test.dart`
Expected: PASS.

- [ ] **Step 6: Format, analyze, commit**

```bash
dart format lib/core/services/sync lib/features/settings/presentation
flutter analyze lib/core/services/sync/sync_service.dart lib/features/settings/presentation
git add -A && git commit -m "feat(sync): rebuild backend from this device when a replace is stuck (offline uploader)"
```

**End of PR 2.** Open a PR titled `feat(sync): cloud sync clear + offline-uploader recovery (#509)`.

---

## Final verification (both PRs)

- [ ] `dart format .` clean across the repo.
- [ ] `flutter analyze` clean (whole project).
- [ ] `flutter test test/core/services/sync/ test/features/settings/presentation/pages/` green.
- [ ] Manual device pass (Apple + Android): (a) macOS with a hardened-runtime build — confirm base temp files land under the app container and #509's `/tmp` EPERM is gone; (b) two devices, do "Replace everywhere" on device A then take A offline — on device B, confirm "Troubleshoot Sync → rebuild this backend from this device" clears the stuck "still uploading"; (c) confirm Repair Sync and both cloud-clear actions behave and never touch dive data.

## Spec traceability

- Surfaces (Troubleshoot screen + tappable banner) → Tasks 4, 5.
- Component 1 (Repair) → Tasks 2, 3, 4.
- Component 2a (offline-uploader escape) → Task 9.
- Component 2b (temp dir + non-fatal base) → Task 1 (temp dir; the sink already returns null on failure, satisfying "non-fatal").
- Component 3a / 3b (cloud clear) → Tasks 6, 7, 8.
