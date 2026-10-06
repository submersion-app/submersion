# iCloud Sync — Phase 0 (Diagnostic) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Determine exactly why the existing iCloud sync "doesn't sync anything," with evidence, before any fix is designed.

**Architecture:** Add a hardware-free reproduction harness (an in-memory fake `CloudStorageProvider` plus two round-trip tests) that isolates "logic bug" from "iCloud/selection/hardware bug," then add boundary instrumentation and a temporary on-device trigger so the same round-trip can be observed on real Apple hardware. The phase ends at a mandatory checkpoint that produces a one-sentence root-cause statement; the fix is planned separately afterward.

**Tech Stack:** Flutter, Dart, Drift (SQLite), Riverpod, `flutter_test`. Sync code under `lib/core/services/sync/` and `lib/core/services/cloud_storage/`.

---

## How to use this plan

This is a **diagnostic** plan. Its deliverable is *knowledge*, not a finished feature. Tasks 1-3 are pure-Dart tests that may immediately reproduce a logic bug (in which case later tasks may be unnecessary). Tasks 4-6 prepare and run the on-device observation needed if the logic layer turns out to be fine. **Do not write a fix in this phase.** Stop at the Checkpoint and report findings; the fix + data-coverage + UI work is a separate plan.

Spec: `docs/superpowers/specs/2026-06-01-icloud-sync-all-data-design.md`.

### Key facts established during planning (so you don't have to rediscover them)

- `SyncService.performSync()` returns `SyncResult` (`status` is a `SyncResultStatus`; `isSuccess` is true for `success`/`noChanges`/`hasConflicts`). With a **null** `cloudProvider` it returns `SyncResultStatus.error` ("No cloud provider configured"); when the provider reports not-authenticated it returns `SyncResultStatus.authError`. See `lib/core/services/sync/sync_service.dart:234-261`.
- Given a valid, authenticated provider, `performSync()` ALWAYS does a full export + upload (it is not gated on pending changes), and applies remote data only if it is newer than the last sync. The "remote not newer than last sync, skip apply" branches are at `sync_service.dart:299-314` and `sync_service.dart:338-348` and are themselves candidate defects.
- The selected provider lives in `selectedCloudProviderTypeProvider` (defaults to **null**) and is turned into a `CloudStorageProvider?` by `cloudStorageProviderProvider`, which also returns null when storage is in **custom-folder mode**. The only startup path that sets a provider is `restoreLastProviderProvider` (a `FutureProvider` that runs only if watched). See `lib/features/settings/presentation/providers/sync_providers.dart:93-122,417-426`.
- `SyncRepository` and `SyncDataSerializer` read the database from the **global singleton** `DatabaseService.instance.database` (not constructor-injected). Tests inject an in-memory DB with `setUpTestDatabase()` (from `test/helpers/test_database.dart`) and tear down with `DatabaseService.instance.resetForTesting()`.
- Serializer public API (`lib/core/services/sync/sync_data_serializer.dart`): `Future<SyncPayload> exportData({required String deviceId, DateTime? since, int? lastSyncTimestamp, required Map<String, List<SyncDeletion>> deletions})` (273), `String serializePayload(SyncPayload)` (424), `SyncPayload deserializePayload(String)` (429), `bool validateChecksum(SyncPayload)` (435). There is **no** public DB-apply method — applying remote data to the DB happens only inside `performSync()`.
- `CloudStorageProvider` interface: `lib/core/services/cloud_storage/cloud_storage_provider.dart:47-142`. Canonical sync filename is `CloudStorageProviderMixin.canonicalSyncFileName` = `submersion_sync.json`.

---

## File structure

| File | Create/Modify | Responsibility |
| --- | --- | --- |
| `test/helpers/fake_cloud_storage_provider.dart` | Create | In-memory `CloudStorageProvider` test double shared by both "devices". |
| `test/core/services/sync/sync_serializer_round_trip_test.dart` | Create | Pure serializer symmetry test (no provider, no DB-apply). |
| `test/core/services/sync/sync_round_trip_test.dart` | Create | Full `performSync()` round-trip against the fake provider, simulating device A -> device B. |
| `lib/core/services/sync/sync_service.dart` | Modify | Add INFO-level boundary logging (remote-file resolution + skip decisions). |
| `lib/core/services/cloud_storage/icloud_storage_provider.dart` | Modify | Add INFO-level logging of container path / fallback / listFiles. |
| `lib/features/settings/presentation/providers/sync_providers.dart` | Modify | Log provider selection outcome (selected / null / custom-folder-disabled). |
| `lib/features/settings/.../settings_page.dart` (or a debug entry) | Modify | Temporary reachable trigger so sync can be run on-device for observation. |
| `docs/superpowers/findings/2026-06-02-icloud-sync-diagnosis.md` | Create (Task 6) | The evidence + one-sentence root cause. |

---

## Task 0: Branch, worktree, and green baseline

**Files:** none (environment only)

- [ ] **Step 1: Create an isolated worktree/branch for this work**

Use the `superpowers:using-git-worktrees` skill. Branch name: `feat/icloud-sync-diagnostic`. Do NOT work on `main`.

- [ ] **Step 2: Initialize the worktree (submodules + deps + codegen)**

Worktrees do not inherit submodules or generated code, and a stale `database.g.dart` carried across a branch switch will break the build with "Type 'X' not found".

Run:
```bash
git submodule update --init --recursive
flutter pub get
dart run build_runner build --delete-conflicting-outputs
```

- [ ] **Step 3: Confirm a green baseline**

Run:
```bash
flutter analyze
```
Expected: `No issues found!`

- [ ] **Step 4: Commit nothing yet** (no changes). Proceed.

---

## Task 1: In-memory fake CloudStorageProvider (test double)

**Files:**
- Create: `test/helpers/fake_cloud_storage_provider.dart`

- [ ] **Step 1: Write the fake provider**

It stores uploaded files in a `Map` keyed by filename (so re-uploading `submersion_sync.json` overwrites the same logical file), always reports available + authenticated, and ignores `folderId`. This is the shared "cloud" both simulated devices talk to.

```dart
import 'dart:typed_data';

import 'package:submersion/core/services/cloud_storage/cloud_storage_provider.dart';

/// In-memory [CloudStorageProvider] for tests. Files are keyed by name, so the
/// canonical sync file maps to a single stable id across uploads.
class FakeCloudStorageProvider extends CloudStorageProvider
    with CloudStorageProviderMixin {
  final Map<String, _FakeFile> _files = {};
  bool authenticated = true;
  bool available = true;

  int get fileCount => _files.length;
  Uint8List? bytesOf(String name) => _files[name]?.data;

  @override
  String get providerName => 'Fake';

  @override
  String get providerId => 'fake';

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<bool> isAuthenticated() async => authenticated;

  @override
  Future<void> authenticate() async {
    authenticated = true;
  }

  @override
  Future<void> signOut() async {
    authenticated = false;
  }

  @override
  Future<String?> getUserEmail() async => 'tester@example.com';

  @override
  Future<UploadResult> uploadFile(
    Uint8List data,
    String filename, {
    String? folderId,
  }) async {
    _files[filename] = _FakeFile(data, DateTime.now());
    return UploadResult(fileId: filename, uploadTime: _files[filename]!.modified);
  }

  @override
  Future<Uint8List> downloadFile(String fileId) async {
    final f = _files[fileId];
    if (f == null) {
      throw CloudStorageException('File not found: $fileId');
    }
    return f.data;
  }

  @override
  Future<CloudFileInfo?> getFileInfo(String fileId) async {
    final f = _files[fileId];
    if (f == null) return null;
    return CloudFileInfo(
      id: fileId,
      name: fileId,
      modifiedTime: f.modified,
      sizeBytes: f.data.length,
    );
  }

  @override
  Future<List<CloudFileInfo>> listFiles({
    String? folderId,
    String? namePattern,
  }) async {
    return _files.entries
        .where((e) => namePattern == null || e.key.contains(namePattern))
        .map(
          (e) => CloudFileInfo(
            id: e.key,
            name: e.key,
            modifiedTime: e.value.modified,
            sizeBytes: e.value.data.length,
          ),
        )
        .toList();
  }

  @override
  Future<void> deleteFile(String fileId) async {
    _files.remove(fileId);
  }

  @override
  Future<bool> fileExists(String fileId) async => _files.containsKey(fileId);

  @override
  Future<String> createFolder(String folderName, {String? parentFolderId}) async =>
      'fake-folder';

  @override
  Future<String> getOrCreateSyncFolder() async => 'fake-sync-folder';
}

class _FakeFile {
  final Uint8List data;
  final DateTime modified;
  _FakeFile(this.data, this.modified);
}
```

- [ ] **Step 2: Verify it compiles and satisfies the interface**

Run:
```bash
flutter analyze test/helpers/fake_cloud_storage_provider.dart
```
Expected: `No issues found!` (if the analyzer reports a missing abstract member, implement it the same minimal way — the interface is the source of truth).

- [ ] **Step 3: Commit**

```bash
git add test/helpers/fake_cloud_storage_provider.dart
git commit -m "test(sync): add in-memory fake CloudStorageProvider for diagnostics"
```

---

## Task 2: Serializer symmetry test (no provider)

Proves the narrow question: does a record survive `export -> serialize -> deserialize` with a valid checksum? If this fails, the defect is in the serializer and we have reproduced it in pure Dart.

**Files:**
- Create: `test/core/services/sync/sync_serializer_round_trip_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';

import '../../../helpers/test_database.dart';
import '../../../helpers/mock_providers.dart';

void main() {
  group('Sync serializer symmetry', () {
    setUp(() async {
      await setUpTestDatabase();
    });

    tearDown(() {
      DatabaseService.instance.resetForTesting();
    });

    test('a dive survives export -> serialize -> deserialize with valid checksum',
        () async {
      // Seed one dive. If the first run fails on a foreign-key requirement
      // (e.g. a diver must exist), insert that prerequisite first — the red
      // run will tell you exactly what is missing.
      final dive = createTestDiveWithBottomTime(id: 'dive-rt-1', diveNumber: 7);
      await DiveRepositoryImpl().createDive(dive);

      final serializer = SyncDataSerializer();
      final deviceId = await SyncRepository().getDeviceId();

      final payload = await serializer.exportData(
        deviceId: deviceId,
        since: null,
        lastSyncTimestamp: null,
        deletions: const <String, List<SyncDeletion>>{},
      );
      final json = serializer.serializePayload(payload);
      final restored = serializer.deserializePayload(json);

      expect(serializer.validateChecksum(restored), isTrue,
          reason: 'checksum should validate after a clean round-trip');
      expect(json, contains('dive-rt-1'),
          reason: 'the seeded dive must appear in the exported payload');
    });
  });
}
```

- [ ] **Step 2: Run it**

Run:
```bash
flutter test test/core/services/sync/sync_serializer_round_trip_test.dart
```
Expected: it either PASSES (serializer is healthy) or FAILS with a concrete error. **Record the outcome** — a failure here is a reproduced logic bug; capture the exact message for the findings doc.

- [ ] **Step 3: If it failed for an environmental reason** (missing FK row, missing helper import), fix only the test setup (add the prerequisite row / import) and re-run until the test exercises the real assertions. Do not change production code.

- [ ] **Step 4: Commit**

```bash
git add test/core/services/sync/sync_serializer_round_trip_test.dart
git commit -m "test(sync): add serializer symmetry round-trip test"
```

---

## Task 3: Full round-trip through performSync (the money test)

Simulates two devices against the shared fake provider using one in-memory DB: device A uploads, then we reset local sync state and delete the dive to impersonate a fresh device B, and sync again. If the dive comes back, the orchestration + serializer + provider round-trip is healthy in pure Dart and the bug is in the real iCloud provider/selection/hardware layer. If it does not, we have reproduced the no-op in a test.

**Files:**
- Create: `test/core/services/sync/sync_round_trip_test.dart`

- [ ] **Step 1: Write the test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/core/services/sync/sync_service.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';

import '../../../helpers/fake_cloud_storage_provider.dart';
import '../../../helpers/test_database.dart';
import '../../../helpers/mock_providers.dart';

void main() {
  group('Sync end-to-end round-trip (fake provider)', () {
    late FakeCloudStorageProvider cloud;

    setUp(() async {
      await setUpTestDatabase();
      cloud = FakeCloudStorageProvider();
    });

    tearDown(() {
      DatabaseService.instance.resetForTesting();
    });

    SyncService buildService() => SyncService(
          syncRepository: SyncRepository(),
          serializer: SyncDataSerializer(),
          cloudProvider: cloud,
        );

    test('a dive created on "device A" is restored on "device B"', () async {
      final diveRepo = DiveRepositoryImpl();

      // Device A: seed and push.
      await diveRepo.createDive(
        createTestDiveWithBottomTime(id: 'dive-xfer-1', diveNumber: 11),
      );
      final pushResult = await buildService().performSync();
      expect(pushResult.isSuccess, isTrue,
          reason: 'device A push should succeed; got ${pushResult.status} '
              '(${pushResult.message})');
      expect(cloud.bytesOf('submersion_sync.json'), isNotNull,
          reason: 'the canonical sync file should exist in the cloud after push');

      // Impersonate a fresh device B sharing the same cloud: forget local sync
      // state and remove the dive locally.
      await SyncRepository().resetSyncState();
      await diveRepo.deleteDive('dive-xfer-1');
      expect(await diveRepo.getDiveById('dive-xfer-1'), isNull,
          reason: 'precondition: dive is gone locally before the pull');

      // Device B: pull.
      final pullResult = await buildService().performSync();
      expect(pullResult.isSuccess, isTrue,
          reason: 'device B pull should succeed; got ${pullResult.status} '
              '(${pullResult.message})');

      // The decisive assertion.
      final restored = await diveRepo.getDiveById('dive-xfer-1');
      expect(restored, isNotNull,
          reason: 'THE BUG: dive did not propagate A -> B through the round-trip');
    });
  });
}
```

- [ ] **Step 2: Confirm the dive-repository method names used above**

The test references `DiveRepositoryImpl().deleteDive(...)` and `.getDiveById(...)`. Confirm the exact names/signatures before running:
```bash
grep -nE "Future<.*> (deleteDive|getDiveById|getDive|removeDive)\b" lib/features/dive_log/data/repositories/dive_repository_impl.dart
```
Adjust the calls to match the real methods (e.g. `getDive(id)` if that is the accessor). Do not invent methods.

- [ ] **Step 3: Run it**

Run:
```bash
flutter test test/core/services/sync/sync_round_trip_test.dart
```
Expected: a definitive result. PASS => the pure-Dart round-trip works; the no-op lives in the real provider/selection/hardware layer (continue to Tasks 4-6). FAIL => the no-op is reproduced in pure Dart; **capture the failing assertion and `pushResult`/`pullResult` status+message** for the findings doc — that is the root cause to fix in the next plan.

**Rule out one false-failure first:** this test assumes `resetSyncState()` clears the stored last-sync time, so device B does not treat the remote file as "not newer." Before trusting a FAIL, confirm `resetSyncState()` nulls the last sync time:
```bash
grep -nA15 "resetSyncState" lib/core/data/repositories/sync_repository.dart
```
If it does not clear it, the pull will be skipped by the `sync_service.dart:299-314` "not newer" branch — a test-setup artifact, not the bug. In that case set the last sync time to a clearly-old value (or null) before the device-B `performSync()` and re-run. A genuine FAIL is one where the dive is absent even though the logs show the remote file was found and applied.

- [ ] **Step 4: Commit**

```bash
git add test/core/services/sync/sync_round_trip_test.dart
git commit -m "test(sync): add end-to-end round-trip test against fake provider"
```

---

## Task 4: Boundary instrumentation (for the on-device run)

Only needed if Task 3 passes (logic is healthy) and we must observe real iCloud. Adds INFO-level logging at the three boundaries most likely to hide a silent no-op: provider selection, remote-file resolution + skip decisions, and the iCloud container/listing.

**Files:**
- Modify: `lib/features/settings/presentation/providers/sync_providers.dart`
- Modify: `lib/core/services/sync/sync_service.dart`
- Modify: `lib/core/services/cloud_storage/icloud_storage_provider.dart`

- [ ] **Step 1: Log the provider-selection outcome**

In `cloudStorageProviderProvider` (`sync_providers.dart:106-122`), add logging for each return path. Add `import 'package:submersion/core/services/logger_service.dart';` if absent, and a file-level `final _log = LoggerService.forClass(CloudStorageProvider);` (or reuse an existing logger). Insert before each `return`:

```dart
// custom-folder branch:
_log.info('cloudProvider: null (custom-folder mode disables app sync)');
// providerType == null branch:
_log.info('cloudProvider: null (no provider selected)');
// icloud branch:
_log.info('cloudProvider: iCloud selected');
```

- [ ] **Step 2: Log remote-file resolution and skip decisions in performSync**

In `sync_service.dart`, after `remoteFileId` is resolved (around line 295) add:
```dart
_log.info('remote sync file resolved: ${remoteFileId ?? "NONE"}');
```
At the two "not newer, skipping" branches (`sync_service.dart:301-306` and `342-347`), upgrade the existing `_log.debug(...)` lines to `_log.info(...)` and include the timestamps being compared, e.g.:
```dart
_log.info('skip apply: remote modified ${info.modifiedTime} <= lastSync $lastSyncTime');
```
After the export, log the payload size and deletion count (near `sync_service.dart:400`):
```dart
_log.info('exported payload: ${localData.length} bytes, '
    '${deletions.length} deletion groups');
```

- [ ] **Step 3: Log the iCloud container path, fallback, and listing**

In `icloud_storage_provider.dart`, locate the methods that resolve the container path (via `ICloudNativeService.getContainerPath()`), `getOrCreateSyncFolder()`, and `listFiles(...)`. Add INFO logs at their returns:
```dart
_log.info('iCloud container: $containerPath (fallback=$usingLocalFallback)');
_log.info('iCloud sync folder: $syncFolderPath');
_log.info('iCloud listFiles -> ${files.map((f) => f.name).toList()}');
```
If the provider has no logger yet, add `final _log = LoggerService.forClass(ICloudStorageProvider);`. Confirm the actual local-variable names by reading the methods first; match them.

- [ ] **Step 4: Verify build**

Run:
```bash
dart format lib/
flutter analyze
```
Expected: `No issues found!`

- [ ] **Step 5: Commit**

```bash
git add lib/
git commit -m "feat(sync): add boundary instrumentation for sync diagnosis"
```

---

## Task 5: Temporary on-device trigger

The Settings UI for sync is orphaned (no route/tile), so sync currently cannot be invoked on a device. Add a temporary, clearly-marked debug trigger that selects iCloud and runs a sync, so the instrumented logs can be produced on real hardware. This is throwaway scaffolding for Phase 0; the real UI is Phase 3.

**Files:**
- Modify: `lib/features/settings/presentation/pages/settings_page.dart` (Data section), or wherever a debug action is easiest to reach.

- [ ] **Step 1: Add a debug-only "Run iCloud sync (diagnostic)" action**

Wrap it in `if (kDebugMode)` so it never ships. It must (a) set the provider to iCloud and (b) call `performSync()`:
```dart
if (kDebugMode)
  ListTile(
    leading: const Icon(Icons.bug_report),
    title: const Text('Run iCloud sync (diagnostic)'),
    onTap: () async {
      ref.read(selectedCloudProviderTypeProvider.notifier).state =
          CloudProviderType.icloud;
      await ref.read(syncStateProvider.notifier).performSync();
      final s = ref.read(syncStateProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sync: ${s.status} — ${s.message ?? ""}')),
      );
    },
  ),
```
Add imports as needed (`package:flutter/foundation.dart` for `kDebugMode`, the sync providers, and `CloudProviderType` from `sync_data_serializer.dart`). Confirm the surrounding widget exposes a `WidgetRef ref` (this section is built inside a `ConsumerWidget`/`Consumer`); if not, wrap the tile in a `Consumer`.

- [ ] **Step 2: Verify build**

Run:
```bash
dart format lib/
flutter analyze
```
Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add lib/
git commit -m "feat(sync): add debug-only on-device sync trigger for diagnosis"
```

---

## Task 6: Hardware reproduction run + findings

**Files:**
- Create: `docs/superpowers/findings/2026-06-02-icloud-sync-diagnosis.md`

- [ ] **Step 1: Run on real hardware (not the Simulator)**

iCloud ubiquity containers do not propagate on the iOS Simulator, so a Simulator result is inconclusive by itself. On a real iPhone (and ideally a Mac signed into the same Apple ID), run:
```bash
flutter run -d <device-id>
```
Sign into iCloud on the device. Trigger the diagnostic action from Task 5. Capture the console logs (the INFO lines from Task 4).

- [ ] **Step 2: Record the evidence**

Create the findings doc with: the Task 2/3 test outcomes; the on-device log excerpt; and which boundary the data stops at. Answer explicitly:
- Was a provider non-null and authenticated? (selection log + `isAuthenticated`)
- Did `getOrCreateSyncFolder` resolve the real ubiquity container or a local fallback?
- Did `uploadFile` succeed and a file appear in iCloud (check the Files app / the container)?
- On a second device/run, did `listFiles` find `submersion_sync.json`, and was it downloaded and applied — or skipped by a "not newer" branch?

- [ ] **Step 3: State the root cause in one sentence** at the top of the findings doc.

- [ ] **Step 4: Commit**

```bash
git add docs/superpowers/findings/2026-06-02-icloud-sync-diagnosis.md
git commit -m "docs(sync): record Phase 0 iCloud sync diagnosis"
```

---

## CHECKPOINT — stop here

Do not design or write a fix in this phase. Report the one-sentence root cause and the findings doc to the spec author. The next plan (Phase 1 fix + Phase 2 data coverage + Phase 3 UI + Phase 4 hardware verification) is written from these findings. If Task 3 already reproduced the bug in pure Dart, the next plan begins with a TDD fix keyed on that failing test; if the logic layer was healthy, it begins with the specific provider/selection/hardware defect named in the findings.
