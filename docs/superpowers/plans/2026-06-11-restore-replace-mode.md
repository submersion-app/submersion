# Restore Replace Mode (Library Epoch) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a "Replace everywhere" mode to database restore: the restored backup becomes the library locally, in the cloud, and on every synced device, instead of merging with the cloud on the next sync.

**Architecture:** A replace mints a library *epoch* (UUID). The replacing device writes a cloud marker file first, wipes all sync files, and re-uploads its library stamped with the new epoch; every sync gates on the marker, ignores stale-stamped files, and peers that knew the old epoch are prompted to adopt (wholesale authoritative apply with a safety backup first). A SharedPreferences-persisted pending-replace intent makes the cloud side at-least-once and fences off merging until it lands. Spec: `docs/superpowers/specs/2026-06-11-restore-replace-mode-design.md`.

**Tech Stack:** Flutter/Dart, Drift (SQLite), Riverpod StateNotifier, SharedPreferences, per-device JSON sync files over `CloudStorageProvider` (iCloud/Drive/S3), flutter gen-l10n (11 ARB locales).

**Branch/worktree:** All work happens in `.claude/worktrees/restore-replace-mode` on branch `worktree-restore-replace-mode`. Commits per task are pre-authorized. Do NOT add Co-Authored-By lines to commits.

---

## File structure (what gets created/modified)

**New files:**

| File | Responsibility |
|---|---|
| `lib/core/services/sync/library_epoch.dart` | `LibraryEpochMarker` model + marker filename constant |
| `lib/core/services/sync/library_epoch_store.dart` | SharedPreferences persistence: last-accepted marker mirror + pending-replace intent |
| `lib/features/backup/domain/entities/restore_mode.dart` | `RestoreMode { merge, replace }` enum |
| `test/core/services/sync/library_epoch_test.dart` | Marker model tests |
| `test/core/services/sync/library_epoch_store_test.dart` | Store tests |
| `test/core/services/sync/sync_service_epoch_test.dart` | Marker IO + gating decision table + replace + adopt tests |
| `test/features/backup/data/services/backup_service_replace_test.dart` | Restore-mode + validation-parity tests |
| `test/features/backup/presentation/widgets/restore_confirmation_dialog_test.dart` | Dialog mode-choice widget tests |

**Modified files:**

| File | Change |
|---|---|
| `lib/core/database/database.dart` | `lastAcceptedEpochId` column on `SyncMetadata`, schema v79 → v80, migration |
| `lib/core/data/repositories/sync_repository.dart` | epoch get/set; `rebaselineAfterRestore` gains `preserveEpochId` |
| `lib/core/services/sync/sync_data_serializer.dart` | `SyncPayload.epochId`; `exportData` gains `epochId` |
| `lib/core/services/sync/sync_service.dart` | epoch store dep; marker IO; gating in `performSync`; stale-stamp filter; `executeLibraryReplace`; `adoptReplacedLibrary`; `SyncResultStatus.awaitingAdoption`; `SyncResult.replaceMarker` |
| `lib/core/services/sync/sync_initializer.dart` | restore-detect path also realigns the epoch from its mirror |
| `lib/features/backup/data/services/backup_service.dart` | `RestoreMode` param; history-path validation; epoch capture; pending-intent mint |
| `lib/features/backup/presentation/providers/backup_providers.dart` | thread mode; epoch store injection; use extracted diver fixup |
| `lib/features/backup/presentation/widgets/restore_confirmation_dialog.dart` | returns `RestoreMode?`; mode radio; second confirmation |
| `lib/features/backup/presentation/pages/backup_settings_page.dart` | pass `offerReplace` + mode at both call sites |
| `lib/features/divers/presentation/providers/diver_providers.dart` | new public `realignActiveDiverAfterDataReplace(prefs)` |
| `lib/features/settings/presentation/providers/sync_providers.dart` | `libraryEpochStoreProvider`; state fields; result mapping; silent adopt; `libraryReplaceInfo`; `adoptReplacedLibrary`; pending-intent launch trigger; reset clears intent |
| `lib/features/settings/presentation/pages/cloud_sync_page.dart` | replace banner; adopt dialog in Sync Now |
| `lib/l10n/arb/app_*.arb` (11 files) | 13 new strings, fully translated |
| `test/helpers/fake_cloud_storage_provider.dart` | additive `operationLog` for order assertions |
| `test/features/settings/presentation/pages/cloud_sync_page_test.dart` | `_FakeSyncNotifier` gains new members |
| `test/features/settings/presentation/s3_config_page_test.dart` | its SyncNotifier fake gains new members |

**Conventions that apply to every task:** no emojis; `dart format lib/ test/` before each commit; run only the test files named in the task (broad directories time out); house import grouping (dart, flutter, packages, local).

---

### Task 0: Baseline — codegen and green tests

This worktree has never run Drift codegen (`database.g.dart` is gitignored and missing).

**Files:** none committed (generated files are gitignored).

- [ ] **Step 1: Generate code**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: completes with `Succeeded` (takes a few minutes).

- [ ] **Step 2: Verify the analyzer is clean**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 3: Verify the sync/backup baseline tests pass**

Run: `flutter test test/core/services/sync/ test/features/backup/data/services/backup_service_test.dart`
Expected: all tests pass. If anything fails here, STOP — the baseline is broken and must be reported, not patched around.

No commit for this task (nothing tracked changed).

---

### Task 1: Schema — `lastAcceptedEpochId` column + repository accessors

**Files:**
- Modify: `lib/core/database/database.dart` (SyncMetadata table ~line 1299-1326; `currentSchemaVersion` ~line 1559; migration blocks ~line 3769+)
- Modify: `lib/core/data/repositories/sync_repository.dart` (~line 852 `rebaselineAfterRestore`)
- Test: `test/core/data/repositories/sync_repository_epoch_test.dart` (create)

- [ ] **Step 1: Write the failing test**

Create `test/core/data/repositories/sync_repository_epoch_test.dart`. Mirror the setUp/tearDown of `test/core/data/repositories/sync_repository_rebaseline_test.dart` exactly (same test-database helper and imports), then:

```dart
group('last accepted epoch', () {
  test('defaults to null and round-trips', () async {
    final repo = SyncRepository();
    expect(await repo.getLastAcceptedEpochId(), isNull);
    await repo.setLastAcceptedEpochId('epoch-1');
    expect(await repo.getLastAcceptedEpochId(), 'epoch-1');
    await repo.setLastAcceptedEpochId(null);
    expect(await repo.getLastAcceptedEpochId(), isNull);
  });

  test('rebaselineAfterRestore overwrites epoch with the preserved value', () async {
    final repo = SyncRepository();
    await repo.setLastAcceptedEpochId('stale-from-backup');
    await repo.rebaselineAfterRestore(
      preserveDeviceId: 'device-1',
      preserveEpochId: 'live-epoch',
    );
    expect(await repo.getLastAcceptedEpochId(), 'live-epoch');
    expect(await repo.getDeviceId(), 'device-1');
  });

  test('rebaselineAfterRestore with no epoch clears the stale one', () async {
    final repo = SyncRepository();
    await repo.setLastAcceptedEpochId('stale-from-backup');
    await repo.rebaselineAfterRestore(preserveDeviceId: 'device-1');
    expect(await repo.getLastAcceptedEpochId(), isNull);
  });
});
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/core/data/repositories/sync_repository_epoch_test.dart`
Expected: FAIL — `getLastAcceptedEpochId` is not defined.

- [ ] **Step 3: Add the column and migration**

In `lib/core/database/database.dart`, inside `class SyncMetadata extends Table` after the `instanceToken` column:

```dart
  /// The library epoch this device last accepted (see library_epoch.dart).
  /// Dual-anchored: mirrored in SharedPreferences so a database restore
  /// cannot silently rewind it. Null means the pre-epoch world.
  TextColumn get lastAcceptedEpochId => text().nullable()();
```

Bump `static const int currentSchemaVersion = 79;` to `80`.

In the migration (`onUpgrade`), after the last existing `if (from < 79)` block, copy the house ALTER pattern:

```dart
        if (from < 80) {
          final cols = await customSelect(
            "PRAGMA table_info('sync_metadata')",
          ).get();
          final existing = cols.map((c) => c.read<String>('name')).toSet();
          if (cols.isNotEmpty && !existing.contains('last_accepted_epoch_id')) {
            await customStatement(
              'ALTER TABLE sync_metadata ADD COLUMN last_accepted_epoch_id TEXT',
            );
          }
        }
        if (from < 80) await reportProgress();
```

(Match the exact indentation and `reportProgress` cadence of the `if (from < 77)` block at ~line 3769.)

- [ ] **Step 4: Regenerate Drift code**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: `Succeeded`.

- [ ] **Step 5: Add the repository accessors**

In `lib/core/data/repositories/sync_repository.dart`, next to `getRemoteFileId`/`setRemoteFileId` (~line 256):

```dart
  /// The library epoch this device last accepted, or null in the pre-epoch
  /// world. Dual-anchored with LibraryEpochStore's SharedPreferences mirror.
  Future<String?> getLastAcceptedEpochId() async {
    final metadata = await getOrCreateMetadata();
    return metadata.lastAcceptedEpochId;
  }

  Future<void> setLastAcceptedEpochId(String? epochId) async {
    try {
      await getOrCreateMetadata();
      final now = DateTime.now().millisecondsSinceEpoch;
      await (_db.update(
        _db.syncMetadata,
      )..where((t) => t.id.equals(_globalMetadataId))).write(
        SyncMetadataCompanion(
          lastAcceptedEpochId: Value(epochId),
          updatedAt: Value(now),
        ),
      );
    } catch (e, stackTrace) {
      _log.error(
        'Failed to set last accepted epoch id',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }
```

Replace `rebaselineAfterRestore` (~line 852) with:

```dart
  Future<void> rebaselineAfterRestore({
    String? preserveDeviceId,
    String? preserveEpochId,
  }) async {
    if (preserveDeviceId != null && preserveDeviceId.isNotEmpty) {
      await setDeviceId(preserveDeviceId);
    }
    await resetSyncState();
    // The restored database carries the backup's stale epoch; overwrite it
    // with the live value captured by the caller before the swap (or null
    // when this install has never accepted an epoch).
    await setLastAcceptedEpochId(preserveEpochId);
    // Drop the in-memory clock so it re-seeds from the restored rows under
    // this device's id on the next write.
    SyncClock.instance.reset();
  }
```

(Keep the existing doc comment above the method; only the body and signature change.)

- [ ] **Step 6: Run tests to verify they pass**

Run: `flutter test test/core/data/repositories/sync_repository_epoch_test.dart test/core/data/repositories/sync_repository_rebaseline_test.dart`
Expected: PASS (rebaseline tests still pass — the new parameter is optional).

- [ ] **Step 7: Format and commit**

```bash
dart format lib/ test/
git add lib/core/database/database.dart lib/core/data/repositories/sync_repository.dart test/core/data/repositories/sync_repository_epoch_test.dart
git commit -m "feat(sync): add last-accepted library epoch to sync metadata"
```

---

### Task 2: `LibraryEpochMarker` model and filename

**Files:**
- Create: `lib/core/services/sync/library_epoch.dart`
- Test: `test/core/services/sync/library_epoch_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/cloud_storage/cloud_storage_provider.dart';
import 'package:submersion/core/services/sync/library_epoch.dart';

void main() {
  test('marker filename must not match the sync-file stem', () {
    // Sync-file discovery lists files by substring match on the stem; a
    // marker name containing it would be treated as a peer device's file.
    expect(
      libraryEpochFileName.contains(CloudStorageProviderMixin.syncFileStem),
      isFalse,
    );
  });

  test('round-trips through JSON', () {
    const marker = LibraryEpochMarker(
      epochId: 'e1',
      replacedAt: 1234,
      deviceId: 'd1',
      deviceName: 'Mac',
      appVersion: '1.5.0.1',
    );
    final restored = LibraryEpochMarker.fromJson(marker.toJson());
    expect(restored.epochId, 'e1');
    expect(restored.replacedAt, 1234);
    expect(restored.deviceId, 'd1');
    expect(restored.deviceName, 'Mac');
    expect(restored.appVersion, '1.5.0.1');
  });

  test('tolerates missing optional fields, rejects missing epochId', () {
    final restored = LibraryEpochMarker.fromJson({
      'epochId': 'e2',
      'replacedAt': 5,
      'deviceId': 'd2',
    });
    expect(restored.deviceName, isNull);
    expect(restored.appVersion, isNull);
    expect(
      () => LibraryEpochMarker.fromJson({'replacedAt': 5, 'deviceId': 'd'}),
      throwsFormatException,
    );
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/core/services/sync/library_epoch_test.dart`
Expected: FAIL — `library_epoch.dart` does not exist.

- [ ] **Step 3: Implement the model**

Create `lib/core/services/sync/library_epoch.dart`:

```dart
/// The library epoch protocol for restore Replace mode.
///
/// A "replace" restore mints a new epoch id. The cloud marker file is the
/// authoritative statement of the current library generation; every sync
/// payload carries the epoch it was written under, so files from an older
/// generation are identifiable and inert no matter when they surface.
library;

/// Cloud filename of the epoch marker.
///
/// MUST NOT contain CloudStorageProviderMixin.syncFileStem
/// ('submersion_sync'): sync-file discovery lists files by substring match
/// on that stem and would treat the marker as a peer device's sync file.
const String libraryEpochFileName = 'submersion_library_epoch.json';

/// Cloud marker contents: which epoch is current, who replaced the library,
/// and when. Doubles as the audit record shown in the peer adopt prompt.
class LibraryEpochMarker {
  final String epochId;

  /// Unix milliseconds of the replace.
  final int replacedAt;
  final String deviceId;
  final String? deviceName;
  final String? appVersion;

  const LibraryEpochMarker({
    required this.epochId,
    required this.replacedAt,
    required this.deviceId,
    this.deviceName,
    this.appVersion,
  });

  Map<String, dynamic> toJson() => {
    'epochId': epochId,
    'replacedAt': replacedAt,
    'deviceId': deviceId,
    'deviceName': deviceName,
    'appVersion': appVersion,
  };

  factory LibraryEpochMarker.fromJson(Map<String, dynamic> json) {
    final epochId = json['epochId'];
    if (epochId is! String || epochId.isEmpty) {
      throw const FormatException('Library epoch marker has no epochId');
    }
    return LibraryEpochMarker(
      epochId: epochId,
      replacedAt: (json['replacedAt'] as num?)?.toInt() ?? 0,
      deviceId: json['deviceId'] as String? ?? '',
      deviceName: json['deviceName'] as String?,
      appVersion: json['appVersion'] as String?,
    );
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/core/services/sync/library_epoch_test.dart`
Expected: PASS.

- [ ] **Step 5: Format and commit**

```bash
dart format lib/ test/
git add lib/core/services/sync/library_epoch.dart test/core/services/sync/library_epoch_test.dart
git commit -m "feat(sync): add library epoch marker model"
```

---

### Task 3: `LibraryEpochStore` — prefs mirror + pending intent

**Files:**
- Create: `lib/core/services/sync/library_epoch_store.dart`
- Test: `test/core/services/sync/library_epoch_store_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/services/sync/library_epoch.dart';
import 'package:submersion/core/services/sync/library_epoch_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const marker = LibraryEpochMarker(
    epochId: 'e1',
    replacedAt: 99,
    deviceId: 'd1',
    deviceName: 'Mac',
  );

  late LibraryEpochStore store;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = LibraryEpochStore(await SharedPreferences.getInstance());
  });

  test('last accepted marker round-trips and clears', () async {
    expect(store.lastAcceptedMarker, isNull);
    expect(store.lastAcceptedEpochId, isNull);
    await store.setLastAccepted(marker);
    expect(store.lastAcceptedEpochId, 'e1');
    expect(store.lastAcceptedMarker?.deviceName, 'Mac');
    await store.setLastAccepted(null);
    expect(store.lastAcceptedMarker, isNull);
  });

  test('pending replace round-trips and clears', () async {
    expect(store.pendingReplace, isNull);
    await store.setPendingReplace(marker);
    expect(store.pendingReplace?.epochId, 'e1');
    await store.clearPendingReplace();
    expect(store.pendingReplace, isNull);
  });

  test('corrupt stored JSON reads as null', () async {
    SharedPreferences.setMockInitialValues({
      'sync_last_accepted_epoch_marker': 'not json',
      'sync_pending_replace_marker': '{"replacedAt": 1}',
    });
    store = LibraryEpochStore(await SharedPreferences.getInstance());
    expect(store.lastAcceptedMarker, isNull);
    expect(store.pendingReplace, isNull);
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/core/services/sync/library_epoch_store_test.dart`
Expected: FAIL — `library_epoch_store.dart` does not exist.

- [ ] **Step 3: Implement the store**

Create `lib/core/services/sync/library_epoch_store.dart`:

```dart
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/services/sync/library_epoch.dart';

/// SharedPreferences persistence for the library epoch protocol.
///
/// Two records, both deliberately OUTSIDE the database:
/// - the last-accepted marker mirror: the database copy rewinds on restore,
///   the mirror survives and re-anchors it (same pattern as the device-id
///   sentinel in SyncInitializer);
/// - the pending-replace intent: a Replace restore's cloud side must retry
///   until it lands, across restarts, while merging stays fenced off.
class LibraryEpochStore {
  static const _lastAcceptedMarkerKey = 'sync_last_accepted_epoch_marker';
  static const _pendingReplaceKey = 'sync_pending_replace_marker';

  final SharedPreferences _prefs;

  LibraryEpochStore(this._prefs);

  LibraryEpochMarker? get lastAcceptedMarker =>
      _decode(_prefs.getString(_lastAcceptedMarkerKey));

  String? get lastAcceptedEpochId => lastAcceptedMarker?.epochId;

  Future<void> setLastAccepted(LibraryEpochMarker? marker) async {
    if (marker == null) {
      await _prefs.remove(_lastAcceptedMarkerKey);
    } else {
      await _prefs.setString(
        _lastAcceptedMarkerKey,
        jsonEncode(marker.toJson()),
      );
    }
  }

  LibraryEpochMarker? get pendingReplace =>
      _decode(_prefs.getString(_pendingReplaceKey));

  Future<void> setPendingReplace(LibraryEpochMarker marker) async {
    await _prefs.setString(_pendingReplaceKey, jsonEncode(marker.toJson()));
  }

  Future<void> clearPendingReplace() async {
    await _prefs.remove(_pendingReplaceKey);
  }

  LibraryEpochMarker? _decode(String? raw) {
    if (raw == null) return null;
    try {
      return LibraryEpochMarker.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (_) {
      return null;
    }
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/core/services/sync/library_epoch_store_test.dart`
Expected: PASS.

- [ ] **Step 5: Format and commit**

```bash
dart format lib/ test/
git add lib/core/services/sync/library_epoch_store.dart test/core/services/sync/library_epoch_store_test.dart
git commit -m "feat(sync): add library epoch store (mirror + pending replace intent)"
```

---

### Task 4: Epoch stamp in `SyncPayload` and `exportData`

**Files:**
- Modify: `lib/core/services/sync/sync_data_serializer.dart` (SyncPayload ~line 79-162; exportData ~line 360)
- Test: extend `test/core/services/sync/library_epoch_test.dart`

- [ ] **Step 1: Write the failing test**

Append to `test/core/services/sync/library_epoch_test.dart` (add imports `dart:convert` and `package:submersion/core/services/sync/sync_data_serializer.dart`):

```dart
  group('SyncPayload epoch stamp', () {
    test('serializes and parses epochId', () {
      final payload = SyncPayload(
        version: 1,
        exportedAt: 1,
        deviceId: 'd1',
        checksum: 'c',
        data: SyncData(),
        deletions: const {},
        epochId: 'e1',
      );
      final parsed = SyncPayload.fromJson(
        jsonDecode(jsonEncode(payload.toJson())) as Map<String, dynamic>,
      );
      expect(parsed.epochId, 'e1');
    });

    test('legacy payload without epochId parses as null', () {
      final payload = SyncPayload(
        version: 1,
        exportedAt: 1,
        deviceId: 'd1',
        checksum: 'c',
        data: SyncData(),
        deletions: const {},
      );
      final json = payload.toJson()..remove('epochId');
      final parsed = SyncPayload.fromJson(json);
      expect(parsed.epochId, isNull);
    });
  });
```

(If `SyncData()` requires const: use `SyncData()` exactly as its constructor allows — all fields default to `const []`.)

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/core/services/sync/library_epoch_test.dart`
Expected: FAIL — no `epochId` parameter on SyncPayload.

- [ ] **Step 3: Implement**

In `lib/core/services/sync/sync_data_serializer.dart`:

1. Add to `SyncPayload` fields (after `uploadNonce`):

```dart
  /// Library epoch this payload was written under (see library_epoch.dart).
  /// Null on legacy files, which become stale the moment any epoch exists.
  final String? epochId;
```

2. Add `this.epochId,` to the constructor's named parameters.
3. Add `'epochId': epochId,` to `toJson()`.
4. In `fromJson`, add `epochId: json['epochId'] as String?,` to the returned constructor call.
5. In `exportData` (~line 360), add a named parameter `String? epochId,` and pass `epochId: epochId,` where the `SyncPayload` is constructed at the end of the method.

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/core/services/sync/library_epoch_test.dart test/core/services/sync/`
Expected: PASS (including all existing serializer/sync tests — the field is optional everywhere).

- [ ] **Step 5: Format and commit**

```bash
dart format lib/ test/
git add lib/core/services/sync/sync_data_serializer.dart test/core/services/sync/library_epoch_test.dart
git commit -m "feat(sync): stamp sync payloads with their library epoch"
```

---

### Task 5: Launch reconcile realigns the epoch after a detected restore

**Files:**
- Modify: `lib/core/services/sync/sync_initializer.dart` (`reconcileDeviceIdentity`, restore-detected branch ~line 128)
- Test: extend `test/core/services/sync/sync_initializer_reconcile_test.dart`

- [ ] **Step 1: Write the failing test**

Open `test/core/services/sync/sync_initializer_reconcile_test.dart`, copy its existing "restore detected" test's arrange section (it seeds mismatched instance tokens), and add this test using the same setUp:

```dart
  test('restore-detect realigns the library epoch from its mirror', () async {
    // Arrange exactly like the existing restore-detected test (mismatched
    // mirrored instance token), plus: a mirrored epoch marker and a stale
    // in-DB epoch.
    SharedPreferences.setMockInitialValues({
      // ...same keys the existing restore-detected test seeds...
      'sync_last_accepted_epoch_marker':
          '{"epochId":"live-epoch","replacedAt":1,"deviceId":"d1"}',
    });
    final prefs = await SharedPreferences.getInstance();
    final repo = SyncRepository();
    await repo.setLastAcceptedEpochId('stale-epoch-from-backup');
    // ...seed device id/instance token mismatch as the existing test does...

    final initializer = SyncInitializer(syncRepository: repo, prefs: prefs);
    final status = await initializer.reconcileDeviceIdentity();

    expect(status, DeviceIdentityStatus.rebaselined);
    expect(await repo.getLastAcceptedEpochId(), 'live-epoch');
  });
```

IMPORTANT: the `// ...` lines mean "replicate the concrete arrange code already present in this file's restore-detected test" — copy those exact lines; do not leave comments in the final test.

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/core/services/sync/sync_initializer_reconcile_test.dart`
Expected: the new test FAILS (epoch stays `stale-epoch-from-backup`); existing tests pass.

- [ ] **Step 3: Implement**

In `lib/core/services/sync/sync_initializer.dart`:

1. Add import: `import 'package:submersion/core/services/sync/library_epoch_store.dart';`
2. In `reconcileDeviceIdentity()`, in the `if (restoreDetected)` branch, change the rebaseline call to:

```dart
      await _syncRepository.rebaselineAfterRestore(
        preserveDeviceId: sentinelDeviceId,
        preserveEpochId: LibraryEpochStore(_prefs).lastAcceptedEpochId,
      );
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/core/services/sync/sync_initializer_reconcile_test.dart test/core/services/sync/sync_initializer_test.dart`
Expected: PASS.

- [ ] **Step 5: Format and commit**

```bash
dart format lib/ test/
git add lib/core/services/sync/sync_initializer.dart test/core/services/sync/sync_initializer_reconcile_test.dart
git commit -m "feat(sync): realign library epoch from mirror when launch detects a restore"
```

---

### Task 6: SyncService marker IO + epoch check (+ fake provider op log)

**Files:**
- Modify: `lib/core/services/sync/sync_service.dart` (constructor ~line 127-145; new methods near `deleteDeviceSyncFile` ~line 1448)
- Modify: `test/helpers/fake_cloud_storage_provider.dart` (additive op log)
- Test: `test/core/services/sync/sync_service_epoch_test.dart` (create)

- [ ] **Step 1: Add the operation log to the fake provider**

In `test/helpers/fake_cloud_storage_provider.dart`, add a public field and record entries at the top of the three mutating/listing methods (keep all existing behavior):

```dart
  /// Ordered log of cloud operations, for asserting protocol order
  /// (e.g. "marker written before wipe"). Entries: 'upload:<name>',
  /// 'delete:<name>', 'list'.
  final List<String> operationLog = [];
```

- In `uploadFile`, first line of the method body: `operationLog.add('upload:$filename');`
- In `deleteFile`, first line: record the name of the file being deleted, e.g. `operationLog.add('delete:${_files.entries.where((e) => e.value.id == fileId).map((e) => e.key).firstOrNull ?? fileId}');` — adapt to the fake's actual internal map shape (`_files` is keyed by name; find the entry whose stored id matches).
- In `listFiles`, first line: `operationLog.add('list');`

- [ ] **Step 2: Write the failing tests for marker IO**

Create `test/core/services/sync/sync_service_epoch_test.dart`. Mirror the setUp/tearDown and `buildService()` helper of `test/core/services/sync/sync_conflict_resolution_test.dart` exactly (same test database bootstrap and `FakeCloudStorageProvider cloud`), with one change — the service gets an epoch store:

```dart
  late LibraryEpochStore epochStore;

  // in setUp, after SharedPreferences.setMockInitialValues({}):
  epochStore = LibraryEpochStore(await SharedPreferences.getInstance());

  SyncService buildService() => SyncService(
    syncRepository: SyncRepository(),
    serializer: SyncDataSerializer(),
    cloudProvider: cloud,
    epochStore: epochStore,
  );
```

First test group:

```dart
  group('marker IO', () {
    const marker = LibraryEpochMarker(
      epochId: 'e1',
      replacedAt: 1,
      deviceId: 'd1',
    );

    test('read returns null when no marker exists', () async {
      final service = buildService();
      expect(await service.readLibraryEpochMarker(cloud), isNull);
    });

    test('write then read round-trips', () async {
      final service = buildService();
      await service.writeLibraryEpochMarker(cloud, marker);
      final read = await service.readLibraryEpochMarker(cloud);
      expect(read?.epochId, 'e1');
    });

    test('marker file is invisible to sync-file discovery', () async {
      final service = buildService();
      await service.writeLibraryEpochMarker(cloud, marker);
      final files = await cloud.listFiles(
        namePattern: CloudStorageProviderMixin.syncFileStem,
      );
      expect(files.where((f) => f.name == libraryEpochFileName), isEmpty);
    });

    test('corrupt marker throws (read failure, not absence)', () async {
      await cloud.uploadFile(
        Uint8List.fromList(utf8.encode('not json')),
        libraryEpochFileName,
      );
      final service = buildService();
      expect(
        () => service.readLibraryEpochMarker(cloud),
        throwsA(isA<FormatException>()),
      );
    });
  });
```

- [ ] **Step 3: Run it to verify it fails**

Run: `flutter test test/core/services/sync/sync_service_epoch_test.dart`
Expected: FAIL — no `epochStore` parameter, no marker methods.

- [ ] **Step 4: Implement constructor dep and marker IO**

In `lib/core/services/sync/sync_service.dart`:

1. Add imports:

```dart
import 'package:submersion/core/services/sync/library_epoch.dart';
import 'package:submersion/core/services/sync/library_epoch_store.dart';
```

2. Add a field and constructor parameter (nullable, so the many existing test constructions keep compiling; epoch behavior activates only when provided):

```dart
  final LibraryEpochStore? _epochStore;
```

and in the constructor: `LibraryEpochStore? epochStore,` plus `_epochStore = epochStore,` in the initializer list.

3. Add near `deleteDeviceSyncFile` (~line 1448):

```dart
  /// Download and parse the cloud epoch marker. Returns null when absent.
  /// Throws on listing/parse failure: "unreadable" must be distinguishable
  /// from "absent" -- the caller fails the sync closed rather than guessing.
  Future<LibraryEpochMarker?> readLibraryEpochMarker(
    CloudStorageProvider provider,
  ) async {
    final files = await provider
        .listFiles(namePattern: libraryEpochFileName)
        .timeout(const Duration(seconds: 8));
    final candidates = files
        .where((f) => !_isConflictCopy(f.name))
        .where((f) => f.name == libraryEpochFileName)
        .toList();
    if (candidates.isEmpty) return null;
    candidates.sort((a, b) => b.modifiedTime.compareTo(a.modifiedTime));
    final bytes = await provider
        .downloadFile(candidates.first.id)
        .timeout(const Duration(seconds: 30));
    final decoded = jsonDecode(utf8.decode(bytes));
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Library epoch marker is not a JSON object');
    }
    return LibraryEpochMarker.fromJson(decoded);
  }

  /// Upload (or overwrite) the cloud epoch marker.
  Future<void> writeLibraryEpochMarker(
    CloudStorageProvider provider,
    LibraryEpochMarker marker,
  ) async {
    final bytes = Uint8List.fromList(utf8.encode(jsonEncode(marker.toJson())));
    String? folderId;
    try {
      folderId = await provider.getOrCreateSyncFolder();
    } catch (_) {
      folderId = null;
    }
    await provider
        .uploadFile(bytes, libraryEpochFileName, folderId: folderId)
        .timeout(const Duration(seconds: 60));
    _log.info('Wrote library epoch marker ${marker.epochId}');
  }
```

If `_isConflictCopy` does not already exist in sync_service.dart (it exists in sync_initializer.dart), add the same private helper to sync_service.dart:

```dart
  bool _isConflictCopy(String filename) {
    final lower = filename.toLowerCase();
    return lower.contains('conflicted copy') || lower.contains('conflict');
  }
```

(Check first — `_listSyncFiles` at ~line 722 already filters conflict copies, so the helper may already exist; reuse it if so.)

- [ ] **Step 5: Run tests to verify they pass**

Run: `flutter test test/core/services/sync/sync_service_epoch_test.dart`
Expected: PASS.

- [ ] **Step 6: Format and commit**

```bash
dart format lib/ test/
git add lib/core/services/sync/sync_service.dart test/helpers/fake_cloud_storage_provider.dart test/core/services/sync/sync_service_epoch_test.dart
git commit -m "feat(sync): library epoch marker read/write on SyncService"
```

---

### Task 7: `executeLibraryReplace` — wipe, marker-first, re-seed

**Files:**
- Modify: `lib/core/services/sync/sync_service.dart`
- Test: extend `test/core/services/sync/sync_service_epoch_test.dart`

- [ ] **Step 1: Write the failing tests**

Add to `sync_service_epoch_test.dart`. Seeding helper for cloud files: upload a fake peer sync file by serializing a minimal payload (mirror how `sync_conflict_resolution_test.dart` builds remote payloads — reuse its helper if one exists; otherwise build with `SyncDataSerializer().exportData` against the test DB or hand-roll a `SyncPayload(...).toJson()` JSON string).

```dart
  group('executeLibraryReplace', () {
    const marker = LibraryEpochMarker(
      epochId: 'new-epoch',
      replacedAt: 1,
      deviceId: 'replacer',
    );

    test('wipes sync files, writes marker before wipe, uploads stamped file, commits epoch', () async {
      // Seed: one peer file and one legacy shared file in the cloud.
      await cloud.uploadFile(
        Uint8List.fromList(utf8.encode('{"version":1}')),
        '${CloudStorageProviderMixin.syncFilePrefix}peer-1'
        '${CloudStorageProviderMixin.syncFileExtension}',
      );
      await cloud.uploadFile(
        Uint8List.fromList(utf8.encode('{"version":1}')),
        CloudStorageProviderMixin.canonicalSyncFileName,
      );
      await epochStore.setPendingReplace(marker);
      cloud.operationLog.clear();

      final service = buildService();
      final result = await service.executeLibraryReplace(marker);

      expect(result.isSuccess, isTrue);
      // Marker upload happens before any sync-file delete.
      final markerIdx = cloud.operationLog.indexWhere(
        (op) => op == 'upload:$libraryEpochFileName',
      );
      final firstDeleteIdx = cloud.operationLog.indexWhere(
        (op) => op.startsWith('delete:'),
      );
      expect(markerIdx, isNonNegative);
      expect(firstDeleteIdx, isNonNegative);
      expect(markerIdx, lessThan(firstDeleteIdx));

      // Peer and legacy files are gone; our stamped file exists.
      final files = await cloud.listFiles(
        namePattern: CloudStorageProviderMixin.syncFileStem,
      );
      final deviceId = await SyncRepository().getDeviceId();
      expect(files.map((f) => f.name), [
        '${CloudStorageProviderMixin.syncFilePrefix}$deviceId'
            '${CloudStorageProviderMixin.syncFileExtension}',
      ]);

      // Epoch committed to both anchors; intent cleared; lastSync set.
      expect(await SyncRepository().getLastAcceptedEpochId(), 'new-epoch');
      expect(epochStore.lastAcceptedEpochId, 'new-epoch');
      expect(epochStore.pendingReplace, isNull);
      expect(await SyncRepository().getLastSyncTime(), isNotNull);
    });

    test('upload failure keeps the pending intent for retry', () async {
      await epochStore.setPendingReplace(marker);
      cloud.failUploads = true;

      final service = buildService();
      final result = await service.executeLibraryReplace(marker);

      expect(result.isSuccess, isFalse);
      expect(epochStore.pendingReplace?.epochId, 'new-epoch');
      expect(await SyncRepository().getLastAcceptedEpochId(), isNull);
    });
  });
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/core/services/sync/sync_service_epoch_test.dart`
Expected: FAIL — `executeLibraryReplace` not defined.

- [ ] **Step 3: Implement**

In `lib/core/services/sync/sync_service.dart`, add below `writeLibraryEpochMarker`:

```dart
  /// Best-effort deletion of EVERY sync file in the cloud folder: all peers'
  /// per-device files, our own, the legacy shared file, and conflict copies.
  /// Failures are logged and skipped -- files that survive carry a stale (or
  /// missing) epoch stamp and are inert to every current-epoch device.
  Future<void> deleteAllSyncFiles(CloudStorageProvider provider) async {
    try {
      final files = await provider
          .listFiles(namePattern: CloudStorageProviderMixin.syncFileStem)
          .timeout(const Duration(seconds: 8));
      for (final f in files) {
        try {
          await provider.deleteFile(f.id).timeout(const Duration(seconds: 8));
          _log.info('Deleted sync file ${f.name} for library replace');
        } catch (e) {
          _log.warning('Could not delete sync file ${f.name}: $e');
        }
      }
    } catch (e) {
      _log.warning('Could not list sync files for replace wipe: $e');
    }
  }

  /// Execute the cloud side of a Replace restore: write the new epoch marker
  /// FIRST (a peer syncing mid-replace must learn the new epoch before it can
  /// misread a half-empty folder), wipe every sync file, upload our library
  /// stamped with the new epoch, then commit the epoch locally and clear the
  /// pending intent. On any failure the intent is kept so the next sync
  /// retries instead of merging.
  Future<SyncResult> executeLibraryReplace(LibraryEpochMarker marker) async {
    final provider = _cloudProvider;
    final store = _epochStore;
    if (provider == null || store == null) {
      return const SyncResult(
        status: SyncResultStatus.error,
        message: 'No cloud provider configured',
      );
    }
    try {
      if (!await provider.isAuthenticated()) {
        return const SyncResult(
          status: SyncResultStatus.authError,
          message: 'Not authenticated with cloud provider',
        );
      }
      final deviceId = await _syncRepository.getDeviceId();
      await _syncRepository.ensureSyncClockConfigured();

      await writeLibraryEpochMarker(provider, marker);
      await deleteAllSyncFiles(provider);

      final deletions = await _syncRepository.getAllDeletions();
      final uploadNonce = _uuid.v4();
      final localPayload = await _serializer.exportData(
        deviceId: deviceId,
        since: null,
        lastSyncTimestamp: null,
        deletions: deletions,
        uploadNonce: uploadNonce,
        epochId: marker.epochId,
      );
      final localJson = _serializer.serializePayload(localPayload);
      final localData = Uint8List.fromList(utf8.encode(localJson));
      String? syncFolder;
      try {
        syncFolder = await provider.getOrCreateSyncFolder();
      } catch (_) {
        syncFolder = null;
      }
      await _syncInitializer?.recordUploadNonce(
        uploadNonce,
        provider.providerId,
      );
      final upload = await provider
          .uploadFile(
            localData,
            _deviceSyncFileName(deviceId),
            folderId: syncFolder,
          )
          .timeout(const Duration(seconds: 180));

      await _syncRepository.setLastAcceptedEpochId(marker.epochId);
      await store.setLastAccepted(marker);
      await _syncRepository.updateLastSyncTime(upload.uploadTime);
      await _syncRepository.persistSyncClock();
      await store.clearPendingReplace();
      _log.info('Library replace executed under epoch ${marker.epochId}');
      return SyncResult(
        status: SyncResultStatus.success,
        message: 'Library replaced',
        lastSyncTime: upload.uploadTime,
      );
    } catch (e, stackTrace) {
      _log.error(
        'Library replace failed; pending intent kept for retry',
        error: e,
        stackTrace: stackTrace,
      );
      return SyncResult(
        status: SyncResultStatus.error,
        message: 'Library replace failed: $e',
      );
    }
  }
```

Verify these existing members are referenced correctly before running: `_syncRepository.getAllDeletions()`, `_serializer.serializePayload(...)`, `_syncRepository.persistSyncClock()`, `_syncInitializer?.recordUploadNonce(nonce, providerId)` — all are used by `performSync` (~lines 415-530); match their exact spellings from that block.

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/core/services/sync/sync_service_epoch_test.dart`
Expected: PASS.

- [ ] **Step 5: Format and commit**

```bash
dart format lib/ test/
git add lib/core/services/sync/sync_service.dart test/core/services/sync/sync_service_epoch_test.dart
git commit -m "feat(sync): execute library replace (marker-first wipe and re-seed)"
```

---

### Task 8: Epoch gating in `performSync` + stale-stamp filter

**Files:**
- Modify: `lib/core/services/sync/sync_service.dart` (enum ~line 17; SyncResult ~line 27; performSync insertion after ~line 292; merge loop ~line 379-413)
- Test: extend `test/core/services/sync/sync_service_epoch_test.dart`

- [ ] **Step 1: Write the failing decision-table tests**

Add to `sync_service_epoch_test.dart`. For seeding stamped/unstamped peer files, add this local helper to the test file (adjust only if `SyncPayload`'s constructor differs — it should match Task 4):

```dart
  Future<void> seedPeerFile({
    required String peerDeviceId,
    String? epochId,
  }) async {
    final serializer = SyncDataSerializer();
    final payload = await serializer.exportData(
      deviceId: peerDeviceId,
      since: null,
      lastSyncTimestamp: null,
      deletions: const [],
      uploadNonce: null,
      epochId: epochId,
    );
    final json = serializer.serializePayload(payload);
    await cloud.uploadFile(
      Uint8List.fromList(utf8.encode(json)),
      '${CloudStorageProviderMixin.syncFilePrefix}$peerDeviceId'
      '${CloudStorageProviderMixin.syncFileExtension}',
    );
  }
```

(`exportData` exports the local test DB's content; that is fine — the peer file just needs to be a valid checksummed payload with a chosen deviceId/epoch.)

```dart
  group('performSync epoch gating', () {
    const marker = LibraryEpochMarker(
      epochId: 'e1',
      replacedAt: 1,
      deviceId: 'replacer',
    );

    test('pending intent executes the replace instead of merging', () async {
      await seedPeerFile(peerDeviceId: 'peer-1');
      await epochStore.setPendingReplace(marker);

      final result = await buildService().performSync();

      expect(result.isSuccess, isTrue);
      expect(epochStore.pendingReplace, isNull);
      expect(await SyncRepository().getLastAcceptedEpochId(), 'e1');
      // The peer file was wiped, not merged.
      final files = await cloud.listFiles(
        namePattern: CloudStorageProviderMixin.syncFileStem,
      );
      expect(files.any((f) => f.name.contains('peer-1')), isFalse);
    });

    test('no marker + no accepted epoch behaves as legacy (normal sync)', () async {
      final result = await buildService().performSync();
      expect(result.isSuccess, isTrue);
      expect(result.status, isNot(SyncResultStatus.awaitingAdoption));
    });

    test('marker matching accepted epoch proceeds and filters stale files', () async {
      final service = buildService();
      await service.writeLibraryEpochMarker(cloud, marker);
      await SyncRepository().setLastAcceptedEpochId('e1');
      await epochStore.setLastAccepted(marker);
      await seedPeerFile(peerDeviceId: 'stale-peer'); // unstamped = stale
      await seedPeerFile(peerDeviceId: 'fresh-peer', epochId: 'e1');

      final result = await service.performSync();

      expect(result.isSuccess, isTrue);
      // Stale file was ignored and opportunistically deleted.
      final files = await cloud.listFiles(
        namePattern: CloudStorageProviderMixin.syncFileStem,
      );
      expect(files.any((f) => f.name.contains('stale-peer')), isFalse);
      expect(files.any((f) => f.name.contains('fresh-peer')), isTrue);
    });

    test('marker mismatch halts before merge or upload', () async {
      final service = buildService();
      await service.writeLibraryEpochMarker(cloud, marker);
      // This device never accepted e1.
      await seedPeerFile(peerDeviceId: 'peer-1', epochId: 'e1');
      cloud.operationLog.clear();

      final result = await service.performSync();

      expect(result.status, SyncResultStatus.awaitingAdoption);
      expect(result.replaceMarker?.epochId, 'e1');
      // No upload of our own file happened.
      expect(
        cloud.operationLog.where((op) => op.startsWith('upload:')),
        isEmpty,
      );
    });

    test('missing marker with accepted epoch self-heals the marker', () async {
      await SyncRepository().setLastAcceptedEpochId('e1');
      await epochStore.setLastAccepted(marker);

      final service = buildService();
      final result = await service.performSync();

      expect(result.isSuccess, isTrue);
      expect((await service.readLibraryEpochMarker(cloud))?.epochId, 'e1');
    });

    test('unreadable marker fails the sync closed', () async {
      await cloud.uploadFile(
        Uint8List.fromList(utf8.encode('not json')),
        libraryEpochFileName,
      );
      final result = await buildService().performSync();
      expect(result.status, SyncResultStatus.error);
    });
  });
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/core/services/sync/sync_service_epoch_test.dart`
Expected: FAIL — `SyncResultStatus.awaitingAdoption` and `replaceMarker` not defined; gating absent.

- [ ] **Step 3: Implement result-type additions**

In `lib/core/services/sync/sync_service.dart`:

1. Extend the enum (line ~17):

```dart
enum SyncResultStatus {
  success,
  noChanges,
  hasConflicts,
  networkError,
  authError,
  awaitingAdoption,
  error,
}
```

2. Add to `SyncResult`: field `final LibraryEpochMarker? replaceMarker;`, constructor param `this.replaceMarker,`. `isSuccess` is NOT changed (awaiting adoption is not success).

- [ ] **Step 4: Implement the gate and stale filter**

In `performSync`, immediately after the `ensureSyncClockConfigured` block (~line 292) and before the "Try to download existing remote file" progress report, insert:

```dart
      // ---- Library epoch gate (restore Replace mode) ----
      // Order matters: a pending replace must run INSTEAD of a merge (merging
      // would pull back the data the user just replaced away), and a marker
      // from an unknown epoch must halt everything until the user adopts.
      String? currentEpochId;
      final epochStore = _epochStore;
      if (epochStore != null) {
        final pending = epochStore.pendingReplace;
        if (pending != null) {
          return await executeLibraryReplace(pending);
        }
        final accepted =
            await _syncRepository.getLastAcceptedEpochId() ??
            epochStore.lastAcceptedEpochId;
        LibraryEpochMarker? marker;
        try {
          marker = await readLibraryEpochMarker(provider);
        } catch (e) {
          _log.warning('Library epoch marker unreadable; failing closed: $e');
          return const SyncResult(
            status: SyncResultStatus.error,
            message: 'Could not read the library epoch marker',
          );
        }
        if (marker == null) {
          if (accepted != null) {
            // We are on an epoch but the marker vanished: self-heal it from
            // the mirrored copy and continue as current.
            final stored = epochStore.lastAcceptedMarker;
            if (stored != null) {
              try {
                await writeLibraryEpochMarker(provider, stored);
              } catch (e) {
                _log.warning('Could not self-heal epoch marker: $e');
              }
            }
            currentEpochId = accepted;
          }
          // accepted == null: pre-epoch world, proceed exactly as today.
        } else if (marker.epochId == accepted) {
          currentEpochId = accepted;
        } else {
          _log.info(
            'Cloud library was replaced (epoch ${marker.epochId}); '
            'halting sync until the user adopts',
          );
          return SyncResult(
            status: SyncResultStatus.awaitingAdoption,
            message: 'The cloud library was replaced from a backup',
            replaceMarker: marker,
          );
        }
      }
```

Then two follow-up edits:

1. **Stale-stamp filter** — inside the merge loop (`for (final file in remoteFiles)` ~line 379), immediately after `_downloadAndParsePayload` returns a non-null `payload` and before any merge/legacy handling, insert:

```dart
        if (currentEpochId != null && payload.epochId != currentEpochId) {
          _log.info(
            'Ignoring stale-epoch sync file ${file.name} '
            '(${payload.epochId ?? 'unstamped'} != $currentEpochId)',
          );
          try {
            await provider.deleteFile(file.id).timeout(
              const Duration(seconds: 8),
            );
          } catch (e) {
            _log.warning('Could not delete stale sync file ${file.name}: $e');
          }
          continue;
        }
```

(Place it so the existing `if (payload.deviceId == deviceId)` skip and legacy-file bookkeeping run only for current-epoch files.)

2. **Stamped upload** — in the export block (~line 422), pass the epoch to `exportData`:

```dart
        epochId: currentEpochId,
```

(Where `currentEpochId` is null — legacy world — payloads stay unstamped, exactly as today.)

- [ ] **Step 5: Run tests to verify they pass**

Run: `flutter test test/core/services/sync/sync_service_epoch_test.dart`
Expected: PASS.

- [ ] **Step 6: Run the full existing sync suite (regression)**

Run: `flutter test test/core/services/sync/`
Expected: PASS — existing tests construct SyncService without an epoch store, so gating is skipped for them.

- [ ] **Step 7: Format and commit**

```bash
dart format lib/ test/
git add lib/core/services/sync/sync_service.dart test/core/services/sync/sync_service_epoch_test.dart
git commit -m "feat(sync): gate every sync on the library epoch marker"
```

---

### Task 9: `adoptReplacedLibrary` — authoritative apply

**Files:**
- Modify: `lib/core/services/sync/sync_service.dart`
- Test: extend `test/core/services/sync/sync_service_epoch_test.dart`

- [ ] **Step 1: Write the failing tests**

The test needs local rows. Mirror how `sync_conflict_resolution_test.dart` inserts dives/sites into the test DB (reuse its insert helpers if present; otherwise insert via `SyncDataSerializer().upsertRecord('dives', {...})` with the minimal field map that the existing tests use).

```dart
  group('adoptReplacedLibrary', () {
    const marker = LibraryEpochMarker(
      epochId: 'e1',
      replacedAt: 1,
      deviceId: 'replacer',
    );

    test('aborts when the marker exists but no current-epoch file does', () async {
      final service = buildService();
      await service.writeLibraryEpochMarker(cloud, marker);
      // Replace still in flight: marker written, stamped upload not landed.
      final result = await service.adoptReplacedLibrary();
      expect(result.isSuccess, isFalse);
      expect(await SyncRepository().getLastAcceptedEpochId(), isNull);
    });

    test('applies the restored library wholesale and commits the epoch', () async {
      // Local library: one dive that the restored library does NOT contain.
      // (Insert a local dive row here using the same helper/insert pattern
      // as sync_conflict_resolution_test.dart — concrete code, not a stub.)
      // Cloud: replacer's stamped file containing a different dive.
      // Build it via a SECOND serializer export from a temporarily-seeded
      // state, or hand-roll the payload JSON with one 'dives' record copied
      // from the local insert helper's field map but a different id.

      final service = buildService();
      await service.writeLibraryEpochMarker(cloud, marker);
      await seedPeerFile(peerDeviceId: 'replacer', epochId: 'e1');
      // seedPeerFile exports the CURRENT local DB; so: insert cloud-dive,
      // seed the peer file, then delete cloud-dive locally and insert
      // local-only-dive — leaving local != cloud.

      final result = await service.adoptReplacedLibrary();

      expect(result.isSuccess, isTrue);
      expect(await SyncRepository().getLastAcceptedEpochId(), 'e1');
      expect(epochStore.lastAcceptedEpochId, 'e1');
      // Local-only row is gone; cloud row is present.
      final serializer = SyncDataSerializer();
      expect(await serializer.fetchRecord('dives', 'local-only-dive'), isNull);
      expect(await serializer.fetchRecord('dives', 'cloud-dive'), isNotNull);
    });

    test('adoption preserves device identity', () async {
      final repo = SyncRepository();
      final before = await repo.getDeviceId();
      final service = buildService();
      await service.writeLibraryEpochMarker(cloud, marker);
      await seedPeerFile(peerDeviceId: 'replacer', epochId: 'e1');
      await service.adoptReplacedLibrary();
      expect(await repo.getDeviceId(), before);
    });

    test('adoption is idempotent', () async {
      final service = buildService();
      await service.writeLibraryEpochMarker(cloud, marker);
      await seedPeerFile(peerDeviceId: 'replacer', epochId: 'e1');
      final first = await service.adoptReplacedLibrary();
      final second = await service.adoptReplacedLibrary();
      expect(first.isSuccess, isTrue);
      expect(second.isSuccess, isTrue);
    });
  });
```

In the wholesale-apply test, replace the comment lines with the concrete insert/seed sequence described — the sequencing trick (insert cloud-dive, seed peer file, swap local rows) avoids hand-rolling checksummed JSON.

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/core/services/sync/sync_service_epoch_test.dart`
Expected: FAIL — `adoptReplacedLibrary` not defined.

- [ ] **Step 3: Implement**

Add to `lib/core/services/sync/sync_service.dart` (below `executeLibraryReplace`):

```dart
  /// Adopt the replaced library: apply the current-epoch cloud files as
  /// authoritative -- upsert every record they contain and delete every
  /// local record (of synced entity types) they do not. Device identity is
  /// deliberately untouched: adoption changes data, not identity. The caller
  /// is responsible for the pre-adoption safety backup and any post-adoption
  /// fix-ups (active diver, follow-up sync).
  Future<SyncResult> adoptReplacedLibrary() async {
    final provider = _cloudProvider;
    final store = _epochStore;
    if (provider == null || store == null) {
      return const SyncResult(
        status: SyncResultStatus.error,
        message: 'No cloud provider configured',
      );
    }
    try {
      final marker = await readLibraryEpochMarker(provider);
      if (marker == null) {
        return const SyncResult(
          status: SyncResultStatus.error,
          message: 'No library replacement marker found',
        );
      }

      final files = await _listSyncFiles(
        provider,
      ).timeout(const Duration(seconds: 8));
      final payloads = <SyncPayload>[];
      for (final file in files) {
        final payload = await _downloadAndParsePayload(provider, file);
        if (payload != null && payload.epochId == marker.epochId) {
          payloads.add(payload);
        }
      }
      if (payloads.isEmpty) {
        // Replace still in flight (marker written, stamped upload pending).
        // Applying an empty set would wipe this library to zero -- abort.
        return const SyncResult(
          status: SyncResultStatus.error,
          message: 'The replaced library is still uploading. Try again shortly.',
        );
      }
      payloads.sort((a, b) => a.exportedAt.compareTo(b.exportedAt));

      final deviceId = await _syncRepository.getDeviceId();
      final localSnapshot = await _serializer.exportData(
        deviceId: deviceId,
        since: null,
        lastSyncTimestamp: null,
        deletions: const [],
        uploadNonce: null,
      );

      await _serializer.applyInDeferredFkTransaction(() async {
        // Union the restored records; for ids present in several files the
        // latest export wins (payloads are sorted ascending).
        final cloudIds = <String, Set<String>>{};
        final restored = <String, Map<String, Map<String, dynamic>>>{};
        for (final payload in payloads) {
          for (final entry in payload.data.toJson().entries) {
            final entityType = entry.key;
            final records = (entry.value as List)
                .cast<Map<String, dynamic>>();
            for (final record in records) {
              final id = _recordIdForEntity(entityType, record);
              if (id == null) continue;
              (cloudIds[entityType] ??= <String>{}).add(id);
              (restored[entityType] ??= {})[id] = record;
            }
          }
        }

        // Delete local rows the restored library does not contain.
        for (final entry in localSnapshot.data.toJson().entries) {
          final entityType = entry.key;
          final records = (entry.value as List).cast<Map<String, dynamic>>();
          for (final record in records) {
            final id = _recordIdForEntity(entityType, record);
            if (id == null) continue;
            if (!(cloudIds[entityType]?.contains(id) ?? false)) {
              await _serializer.deleteRecord(entityType, id);
            }
          }
        }

        // Upsert every restored record.
        for (final entry in restored.entries) {
          for (final record in entry.value.values) {
            await _serializer.upsertRecord(entry.key, record);
          }
        }

        await _serializer.repairDanglingForeignKeys();
      });

      // Re-baseline under the adopted epoch. Our tombstones are obsolete --
      // the restored library is authoritative.
      await _syncRepository.resetSyncState(clearDeletionLog: true);
      await _syncRepository.setLastAcceptedEpochId(marker.epochId);
      await store.setLastAccepted(marker);
      SyncClock.instance.reset();
      _log.info('Adopted replaced library (epoch ${marker.epochId})');
      return const SyncResult(
        status: SyncResultStatus.success,
        message: 'Adopted the restored library',
      );
    } catch (e, stackTrace) {
      _log.error(
        'Failed to adopt replaced library',
        error: e,
        stackTrace: stackTrace,
      );
      return SyncResult(
        status: SyncResultStatus.error,
        message: 'Failed to adopt the restored library: $e',
      );
    }
  }
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/core/services/sync/sync_service_epoch_test.dart`
Expected: PASS.

- [ ] **Step 5: Format and commit**

```bash
dart format lib/ test/
git add lib/core/services/sync/sync_service.dart test/core/services/sync/sync_service_epoch_test.dart
git commit -m "feat(sync): adopt replaced library as authoritative apply"
```

---

### Task 10: BackupService — restore mode, intent mint, validation parity

**Files:**
- Create: `lib/features/backup/domain/entities/restore_mode.dart`
- Modify: `lib/features/backup/data/services/backup_service.dart` (constructor ~line 65; restore methods ~line 263-362)
- Modify: `lib/features/backup/presentation/providers/backup_providers.dart` (backupServiceProvider ~line 25; notifier methods ~line 183, 282)
- Test: `test/features/backup/data/services/backup_service_replace_test.dart` (create)

- [ ] **Step 1: Create the enum**

`lib/features/backup/domain/entities/restore_mode.dart`:

```dart
/// How a database restore treats the cloud library.
enum RestoreMode {
  /// Restore locally; the next sync merges the restored data with the
  /// cloud library (historical behavior, the default).
  merge,

  /// The restored backup becomes the library everywhere: a pending replace
  /// intent is minted and the next sync wipes and re-seeds the cloud under
  /// a new library epoch.
  replace,
}
```

- [ ] **Step 2: Write the failing tests**

Create `test/features/backup/data/services/backup_service_replace_test.dart`. Mirror the setUp and `FakeBackupDatabaseAdapter` usage of `test/features/backup/data/services/backup_service_test.dart` exactly (it fakes the DB adapter so no real file swap happens), plus a SharedPreferences-backed `LibraryEpochStore` and a valid temp backup file (the existing test file shows how a valid .db fixture is produced — reuse the same approach):

```dart
  group('restore modes', () {
    test('merge mode (default) does not mint a pending replace', () async {
      await service.restoreFromFile(validBackupPath);
      expect(epochStore.pendingReplace, isNull);
    });

    test('replace mode mints a pending replace with a fresh epoch', () async {
      await service.restoreFromFile(validBackupPath, mode: RestoreMode.replace);
      final intent = epochStore.pendingReplace;
      expect(intent, isNotNull);
      expect(intent!.epochId, isNotEmpty);
      expect(intent.replacedAt, greaterThan(0));
    });

    test('replace mode preserves the live epoch through the rebaseline', () async {
      // Live device accepted epoch 'live-e' before restoring with MERGE:
      // the captured value must survive the swap.
      await syncRepository.setLastAcceptedEpochId('live-e');
      await service.restoreFromFile(validBackupPath);
      expect(await syncRepository.getLastAcceptedEpochId(), 'live-e');
    });
  });

  group('history restore validation parity', () {
    test('restoreFromBackup rejects a corrupt backup file', () async {
      final corrupt = File('${tempDir.path}/corrupt.db')
        ..writeAsStringSync('not a database');
      final record = BackupRecord(
        id: 'r1',
        filename: 'corrupt.db',
        timestamp: DateTime(2026),
        sizeBytes: 10,
        location: BackupLocation.local,
        localPath: corrupt.path,
      );
      expect(
        () => service.restoreFromBackup(record),
        throwsA(isA<BackupException>()),
      );
    });
  });
```

(Adapt constructor arguments of `BackupRecord` to its actual required fields — copy from how `backup_service_test.dart` builds records. `service` must be constructed with `epochStore: epochStore` and `syncRepository: syncRepository` — see Step 4.)

- [ ] **Step 3: Run it to verify it fails**

Run: `flutter test test/features/backup/data/services/backup_service_replace_test.dart`
Expected: FAIL — no `mode` parameter, no `epochStore`.

- [ ] **Step 4: Implement BackupService changes**

In `lib/features/backup/data/services/backup_service.dart`:

1. Add imports:

```dart
import 'package:package_info_plus/package_info_plus.dart';
import 'package:submersion/core/services/sync/library_epoch.dart';
import 'package:submersion/core/services/sync/library_epoch_store.dart';
import 'package:submersion/features/backup/domain/entities/restore_mode.dart';
```

(`dart:io` and `uuid` are already imported.)

2. Add field `final LibraryEpochStore? _epochStore;` and constructor parameter `LibraryEpochStore? epochStore,` with `_epochStore = epochStore,` in the initializer list.

3. Change `restoreFromBackup` (~line 263) — add the mode parameter and source validation:

```dart
  Future<void> restoreFromBackup(
    BackupRecord record, {
    RestoreMode mode = RestoreMode.merge,
  }) async {
    _log.info('Starting restore from: ${record.filename} (mode: $mode)');

    await performBackup();

    String sourcePath;
    if (record.localPath != null && await File(record.localPath!).exists()) {
      sourcePath = record.localPath!;
    } else if (record.cloudFileId != null && _cloudProvider != null) {
      _log.info('Downloading backup from cloud');
      sourcePath = await _downloadFromCloud(
        record.cloudFileId!,
        record.filename,
      );
    } else {
      throw const BackupException('Backup file not found locally or in cloud');
    }

    // Parity with the file-picker path: the file on disk (or the fresh
    // download) may have been corrupted since the record was written.
    final validation = await validateBackupFile(sourcePath);
    if (!validation.isValid) {
      throw BackupException(
        validation.error ?? 'Backup file failed validation',
      );
    }

    await _replaceDatabaseAndRebaselineSync(sourcePath);
    if (mode == RestoreMode.replace) {
      await _mintPendingReplace();
    }

    _log.info('Restore completed from: ${record.filename}');
  }
```

(If `BackupException`'s constructor is const-only with a positional message — it is, per `const BackupException('...')` usages — the non-const `BackupException(validation.error ?? ...)` call is fine.)

4. Change `restoreFromFile` (~line 299) the same way:

```dart
  Future<void> restoreFromFile(
    String filePath, {
    RestoreMode mode = RestoreMode.merge,
  }) async {
    _log.info('Starting restore from file: $filePath (mode: $mode)');

    final file = File(filePath);
    if (!await file.exists()) {
      throw const BackupException('Backup file not found');
    }

    await performBackup();
    await _replaceDatabaseAndRebaselineSync(filePath);
    if (mode == RestoreMode.replace) {
      await _mintPendingReplace();
    }

    _log.info('Restore from file completed: ${p.basename(filePath)}');
  }
```

5. In `_replaceDatabaseAndRebaselineSync` (~line 327), capture the live epoch next to the live device id (before `_dbAdapter.restore`), and pass it through:

```dart
    String? liveEpochId;
    try {
      liveEpochId =
          await _syncRepository.getLastAcceptedEpochId() ??
          _epochStore?.lastAcceptedEpochId;
    } catch (_) {
      liveEpochId = _epochStore?.lastAcceptedEpochId;
    }
```

and change the rebaseline call to:

```dart
      await _syncRepository.rebaselineAfterRestore(
        preserveDeviceId: liveDeviceId,
        preserveEpochId: liveEpochId,
      );
```

6. Add the intent minting helper:

```dart
  /// Mint and persist the pending-replace intent. The cloud side executes on
  /// the next sync (typically the post-restart launch sync); until it lands,
  /// the intent fences off merging.
  Future<void> _mintPendingReplace() async {
    final store = _epochStore;
    if (store == null) {
      _log.warning('Replace mode requested but no epoch store is configured');
      return;
    }
    String deviceId;
    try {
      deviceId = await _syncRepository.getDeviceId();
    } catch (_) {
      deviceId = '';
    }
    String? deviceName;
    try {
      deviceName = Platform.localHostname;
    } catch (_) {
      deviceName = null;
    }
    String? appVersion;
    try {
      appVersion = (await PackageInfo.fromPlatform()).version;
    } catch (_) {
      appVersion = null;
    }
    final marker = LibraryEpochMarker(
      epochId: const Uuid().v4(),
      replacedAt: DateTime.now().millisecondsSinceEpoch,
      deviceId: deviceId,
      deviceName: deviceName,
      appVersion: appVersion,
    );
    await store.setPendingReplace(marker);
    _log.info('Minted pending library replace (epoch ${marker.epochId})');
  }
```

7. In `lib/features/backup/presentation/providers/backup_providers.dart`, update `backupServiceProvider` (~line 25) to inject the store:

```dart
final backupServiceProvider = Provider<BackupService>((ref) {
  return BackupService(
    dbAdapter: DefaultBackupDatabaseAdapter(DatabaseService.instance),
    preferences: ref.watch(backupPreferencesProvider),
    cloudProvider: ref.watch(cloudStorageProviderProvider),
    epochStore: LibraryEpochStore(ref.watch(sharedPreferencesProvider)),
  );
});
```

(Add imports for `library_epoch_store.dart` and, if not already imported, `sharedPreferencesProvider` from `settings_providers.dart`.)

8. Thread the mode through the notifier — change the two methods' signatures and the service calls:

```dart
  Future<void> restoreFromBackup(
    BackupRecord record, {
    RestoreMode mode = RestoreMode.merge,
  }) async {
    ...
      await _service.restoreFromBackup(record, mode: mode);
    ...
  }

  Future<void> restoreFromFilePath(
    String filePath, {
    RestoreMode mode = RestoreMode.merge,
  }) async {
    ...
      await _service.restoreFromFile(filePath, mode: mode);
    ...
  }
```

(Only the signature lines and the `_service.` call lines change; every other line of those methods stays as-is. Add the `restore_mode.dart` import.)

- [ ] **Step 5: Run tests to verify they pass**

Run: `flutter test test/features/backup/data/services/backup_service_replace_test.dart test/features/backup/data/services/backup_service_test.dart`
Expected: PASS (existing tests unchanged — `mode` defaults to merge; note the existing tests now also exercise the new history-validation, so if any used an invalid fixture for `restoreFromBackup`, fix the fixture to be a valid SQLite file, not the assertion).

- [ ] **Step 6: Format and commit**

```bash
dart format lib/ test/
git add lib/features/backup/domain/entities/restore_mode.dart lib/features/backup/data/services/backup_service.dart lib/features/backup/presentation/providers/backup_providers.dart test/features/backup/data/services/backup_service_replace_test.dart
git commit -m "feat(backup): restore modes, pending replace intent, history validation parity"
```

---

### Task 11: Extract the active-diver fixup (breaks an import cycle before Task 13 needs it)

`sync_providers.dart` must run the fixup after adoption, but it cannot import `backup_providers.dart` (which imports `sync_providers.dart` for `cloudStorageProviderProvider`). Move the logic to the divers feature, which neither imports.

**Files:**
- Modify: `lib/features/divers/presentation/providers/diver_providers.dart` (add a free function near `currentDiverIdKey`, line ~60)
- Modify: `lib/features/backup/presentation/providers/backup_providers.dart` (`_syncActiveDiverAfterRestore` ~line 125 delegates)

- [ ] **Step 1: Add the function**

In `lib/features/divers/presentation/providers/diver_providers.dart`, below the `currentDiverIdKey` constant:

```dart
/// After the local database content has been replaced wholesale (backup
/// restore, or adopting a replaced sync library), realign the active diver:
/// validate the restored settings' active diver against the divers table,
/// fall back to the default diver, and persist the result to
/// SharedPreferences so startup picks up the right diver.
Future<void> realignActiveDiverAfterDataReplace(
  SharedPreferences prefs,
) async {
  try {
    final repository = DiverRepository();

    var restoredId = await repository.getActiveDiverIdFromSettings();

    if (restoredId != null) {
      final diver = await repository.getDiverById(restoredId);
      if (diver == null) {
        restoredId = null;
      }
    }

    if (restoredId == null) {
      final defaultDiver = await repository.getDefaultDiver();
      restoredId = defaultDiver?.id;
    }

    if (restoredId != null) {
      await prefs.setString(currentDiverIdKey, restoredId);
    }
  } catch (_) {
    // Non-fatal: startup validation in CurrentDiverIdNotifier handles it.
  }
}
```

(Check this file's imports: `SharedPreferences` and `DiverRepository` are almost certainly already imported; add if missing.)

- [ ] **Step 2: Delegate from backup_providers**

Replace the body of `_syncActiveDiverAfterRestore` (~line 125-154) in `backup_providers.dart` with:

```dart
  Future<void> _syncActiveDiverAfterRestore() async {
    await realignActiveDiverAfterDataReplace(
      _ref.read(sharedPreferencesProvider),
    );
  }
```

(Remove the now-unused imports if the analyzer flags them.)

- [ ] **Step 3: Verify**

Run: `flutter analyze`
Expected: `No issues found!`

Run: `flutter test test/features/backup/data/services/backup_service_test.dart test/features/backup/presentation/`
Expected: PASS (if no widget tests exist under that presentation path, the command reports the service tests only).

- [ ] **Step 4: Format and commit**

```bash
dart format lib/ test/
git add lib/features/divers/presentation/providers/diver_providers.dart lib/features/backup/presentation/providers/backup_providers.dart
git commit -m "refactor(divers): extract active-diver realign for reuse by sync adoption"
```

---

### Task 12: Localization — 13 strings, 11 locales

**Files:**
- Modify: `lib/l10n/arb/app_en.arb` + the 10 translated ARB files (`app_ar.arb`, `app_de.arb`, `app_es.arb`, `app_fr.arb`, `app_he.arb`, `app_hu.arb`, `app_it.arb`, `app_nl.arb`, `app_pt.arb`, `app_zh.arb`)
- Generated: `lib/l10n/arb/app_localizations*.dart` (via gen-l10n; commit the regenerated files since they are checked in)

- [ ] **Step 1: Add the English strings**

Insert into `app_en.arb`, alphabetically near the existing `backup_restore_dialog_*` keys (~line 269) and `settings_cloudSync_firstSync_*` keys (~line 5652). Note: each ARB file keeps keys sorted; match the file's existing ordering convention.

```json
  "backup_replaceConfirm_confirm": "Replace Everywhere",
  "backup_replaceConfirm_content": "The library on all synced devices will be replaced with this backup. Each device creates a safety backup of its current data first. This cannot be undone.",
  "backup_replaceConfirm_title": "Replace Library Everywhere?",
  "backup_restore_dialog_modeMerge_subtitle": "Restore to this device. Your next sync combines the restored data with the cloud library.",
  "backup_restore_dialog_modeMerge_title": "Merge on next sync",
  "backup_restore_dialog_modeReplace_subtitle": "The backup becomes the library on this device, in the cloud, and on every synced device.",
  "backup_restore_dialog_modeReplace_title": "Replace everywhere",
  "backup_restore_dialog_restoreReplace": "Restore and Replace Everywhere",
  "settings_cloudSync_adopt_confirm": "Adopt Restored Library",
  "settings_cloudSync_adopt_dialogContent": "The library was replaced from a backup on \"{deviceName}\" ({date}). Adopting replaces this device's data with the restored library. A safety backup of this device's current data will be created first.",
  "@settings_cloudSync_adopt_dialogContent": {
    "placeholders": {
      "deviceName": { "type": "String" },
      "date": { "type": "String" }
    }
  },
  "settings_cloudSync_adopt_dialogTitle": "Adopt Restored Library?",
  "settings_cloudSync_adopt_notNow": "Not Now",
  "settings_cloudSync_replace_banner": "Sync is paused: the library was replaced from a backup on \"{deviceName}\". Tap Sync Now to review.",
  "@settings_cloudSync_replace_banner": {
    "placeholders": {
      "deviceName": { "type": "String" }
    }
  }
```

- [ ] **Step 2: Add the translations**

Add the same keys (including the `@` metadata for the two parameterized strings, identical placeholder blocks) to each locale file with these values:

**app_de.arb:**
```json
  "backup_replaceConfirm_confirm": "Überall ersetzen",
  "backup_replaceConfirm_content": "Die Bibliothek auf allen synchronisierten Geräten wird durch dieses Backup ersetzt. Jedes Gerät erstellt zuerst eine Sicherheitskopie seiner aktuellen Daten. Dies kann nicht rückgängig gemacht werden.",
  "backup_replaceConfirm_title": "Bibliothek überall ersetzen?",
  "backup_restore_dialog_modeMerge_subtitle": "Auf diesem Gerät wiederherstellen. Die nächste Synchronisierung führt die wiederhergestellten Daten mit der Cloud-Bibliothek zusammen.",
  "backup_restore_dialog_modeMerge_title": "Bei nächster Synchronisierung zusammenführen",
  "backup_restore_dialog_modeReplace_subtitle": "Das Backup wird zur Bibliothek auf diesem Gerät, in der Cloud und auf jedem synchronisierten Gerät.",
  "backup_restore_dialog_modeReplace_title": "Überall ersetzen",
  "backup_restore_dialog_restoreReplace": "Wiederherstellen und überall ersetzen",
  "settings_cloudSync_adopt_confirm": "Wiederhergestellte Bibliothek übernehmen",
  "settings_cloudSync_adopt_dialogContent": "Die Bibliothek wurde am {date} aus einem Backup auf \"{deviceName}\" ersetzt. Beim Übernehmen werden die Daten dieses Geräts durch die wiederhergestellte Bibliothek ersetzt. Zuerst wird eine Sicherheitskopie der aktuellen Daten dieses Geräts erstellt.",
  "settings_cloudSync_adopt_dialogTitle": "Wiederhergestellte Bibliothek übernehmen?",
  "settings_cloudSync_adopt_notNow": "Nicht jetzt",
  "settings_cloudSync_replace_banner": "Synchronisierung pausiert: Die Bibliothek wurde aus einem Backup auf \"{deviceName}\" ersetzt. Tippe auf \"Jetzt synchronisieren\", um sie zu überprüfen."
```

**app_es.arb:**
```json
  "backup_replaceConfirm_confirm": "Reemplazar en todas partes",
  "backup_replaceConfirm_content": "La biblioteca de todos los dispositivos sincronizados se reemplazará con esta copia de seguridad. Cada dispositivo crea primero una copia de seguridad de sus datos actuales. Esto no se puede deshacer.",
  "backup_replaceConfirm_title": "¿Reemplazar la biblioteca en todas partes?",
  "backup_restore_dialog_modeMerge_subtitle": "Restaurar en este dispositivo. La próxima sincronización combinará los datos restaurados con la biblioteca en la nube.",
  "backup_restore_dialog_modeMerge_title": "Combinar en la próxima sincronización",
  "backup_restore_dialog_modeReplace_subtitle": "La copia de seguridad se convierte en la biblioteca en este dispositivo, en la nube y en todos los dispositivos sincronizados.",
  "backup_restore_dialog_modeReplace_title": "Reemplazar en todas partes",
  "backup_restore_dialog_restoreReplace": "Restaurar y reemplazar en todas partes",
  "settings_cloudSync_adopt_confirm": "Adoptar la biblioteca restaurada",
  "settings_cloudSync_adopt_dialogContent": "La biblioteca se reemplazó desde una copia de seguridad en \"{deviceName}\" ({date}). Al adoptarla, los datos de este dispositivo se reemplazarán con la biblioteca restaurada. Primero se creará una copia de seguridad de los datos actuales de este dispositivo.",
  "settings_cloudSync_adopt_dialogTitle": "¿Adoptar la biblioteca restaurada?",
  "settings_cloudSync_adopt_notNow": "Ahora no",
  "settings_cloudSync_replace_banner": "Sincronización en pausa: la biblioteca se reemplazó desde una copia de seguridad en \"{deviceName}\". Toca Sincronizar ahora para revisarla."
```

**app_fr.arb:**
```json
  "backup_replaceConfirm_confirm": "Remplacer partout",
  "backup_replaceConfirm_content": "La bibliothèque de tous les appareils synchronisés sera remplacée par cette sauvegarde. Chaque appareil crée d'abord une sauvegarde de sécurité de ses données actuelles. Cette action est irréversible.",
  "backup_replaceConfirm_title": "Remplacer la bibliothèque partout ?",
  "backup_restore_dialog_modeMerge_subtitle": "Restaurer sur cet appareil. La prochaine synchronisation combinera les données restaurées avec la bibliothèque dans le cloud.",
  "backup_restore_dialog_modeMerge_title": "Fusionner à la prochaine synchronisation",
  "backup_restore_dialog_modeReplace_subtitle": "La sauvegarde devient la bibliothèque sur cet appareil, dans le cloud et sur chaque appareil synchronisé.",
  "backup_restore_dialog_modeReplace_title": "Remplacer partout",
  "backup_restore_dialog_restoreReplace": "Restaurer et remplacer partout",
  "settings_cloudSync_adopt_confirm": "Adopter la bibliothèque restaurée",
  "settings_cloudSync_adopt_dialogContent": "La bibliothèque a été remplacée à partir d'une sauvegarde sur « {deviceName} » ({date}). En l'adoptant, les données de cet appareil seront remplacées par la bibliothèque restaurée. Une sauvegarde de sécurité des données actuelles de cet appareil sera d'abord créée.",
  "settings_cloudSync_adopt_dialogTitle": "Adopter la bibliothèque restaurée ?",
  "settings_cloudSync_adopt_notNow": "Pas maintenant",
  "settings_cloudSync_replace_banner": "Synchronisation en pause : la bibliothèque a été remplacée à partir d'une sauvegarde sur « {deviceName} ». Touchez Synchroniser maintenant pour vérifier."
```

**app_it.arb:**
```json
  "backup_replaceConfirm_confirm": "Sostituisci ovunque",
  "backup_replaceConfirm_content": "La libreria su tutti i dispositivi sincronizzati verrà sostituita con questo backup. Ogni dispositivo crea prima un backup di sicurezza dei propri dati attuali. Questa operazione non può essere annullata.",
  "backup_replaceConfirm_title": "Sostituire la libreria ovunque?",
  "backup_restore_dialog_modeMerge_subtitle": "Ripristina su questo dispositivo. La prossima sincronizzazione combinerà i dati ripristinati con la libreria nel cloud.",
  "backup_restore_dialog_modeMerge_title": "Unisci alla prossima sincronizzazione",
  "backup_restore_dialog_modeReplace_subtitle": "Il backup diventa la libreria su questo dispositivo, nel cloud e su ogni dispositivo sincronizzato.",
  "backup_restore_dialog_modeReplace_title": "Sostituisci ovunque",
  "backup_restore_dialog_restoreReplace": "Ripristina e sostituisci ovunque",
  "settings_cloudSync_adopt_confirm": "Adotta la libreria ripristinata",
  "settings_cloudSync_adopt_dialogContent": "La libreria è stata sostituita da un backup su \"{deviceName}\" ({date}). Adottandola, i dati di questo dispositivo verranno sostituiti con la libreria ripristinata. Prima verrà creato un backup di sicurezza dei dati attuali di questo dispositivo.",
  "settings_cloudSync_adopt_dialogTitle": "Adottare la libreria ripristinata?",
  "settings_cloudSync_adopt_notNow": "Non ora",
  "settings_cloudSync_replace_banner": "Sincronizzazione in pausa: la libreria è stata sostituita da un backup su \"{deviceName}\". Tocca Sincronizza ora per controllare."
```

**app_nl.arb:**
```json
  "backup_replaceConfirm_confirm": "Overal vervangen",
  "backup_replaceConfirm_content": "De bibliotheek op alle gesynchroniseerde apparaten wordt vervangen door deze back-up. Elk apparaat maakt eerst een veiligheidsback-up van zijn huidige gegevens. Dit kan niet ongedaan worden gemaakt.",
  "backup_replaceConfirm_title": "Bibliotheek overal vervangen?",
  "backup_restore_dialog_modeMerge_subtitle": "Herstel op dit apparaat. Bij de volgende synchronisatie worden de herstelde gegevens samengevoegd met de cloudbibliotheek.",
  "backup_restore_dialog_modeMerge_title": "Samenvoegen bij volgende synchronisatie",
  "backup_restore_dialog_modeReplace_subtitle": "De back-up wordt de bibliotheek op dit apparaat, in de cloud en op elk gesynchroniseerd apparaat.",
  "backup_restore_dialog_modeReplace_title": "Overal vervangen",
  "backup_restore_dialog_restoreReplace": "Herstellen en overal vervangen",
  "settings_cloudSync_adopt_confirm": "Herstelde bibliotheek overnemen",
  "settings_cloudSync_adopt_dialogContent": "De bibliotheek is vervangen vanuit een back-up op \"{deviceName}\" ({date}). Bij overname worden de gegevens van dit apparaat vervangen door de herstelde bibliotheek. Eerst wordt een veiligheidsback-up van de huidige gegevens van dit apparaat gemaakt.",
  "settings_cloudSync_adopt_dialogTitle": "Herstelde bibliotheek overnemen?",
  "settings_cloudSync_adopt_notNow": "Niet nu",
  "settings_cloudSync_replace_banner": "Synchronisatie gepauzeerd: de bibliotheek is vervangen vanuit een back-up op \"{deviceName}\". Tik op Nu synchroniseren om te controleren."
```

**app_pt.arb:**
```json
  "backup_replaceConfirm_confirm": "Substituir em todo lugar",
  "backup_replaceConfirm_content": "A biblioteca em todos os dispositivos sincronizados será substituída por este backup. Cada dispositivo cria primeiro um backup de segurança dos seus dados atuais. Isso não pode ser desfeito.",
  "backup_replaceConfirm_title": "Substituir a biblioteca em todo lugar?",
  "backup_restore_dialog_modeMerge_subtitle": "Restaurar neste dispositivo. A próxima sincronização combinará os dados restaurados com a biblioteca na nuvem.",
  "backup_restore_dialog_modeMerge_title": "Mesclar na próxima sincronização",
  "backup_restore_dialog_modeReplace_subtitle": "O backup se torna a biblioteca neste dispositivo, na nuvem e em todos os dispositivos sincronizados.",
  "backup_restore_dialog_modeReplace_title": "Substituir em todo lugar",
  "backup_restore_dialog_restoreReplace": "Restaurar e substituir em todo lugar",
  "settings_cloudSync_adopt_confirm": "Adotar a biblioteca restaurada",
  "settings_cloudSync_adopt_dialogContent": "A biblioteca foi substituída a partir de um backup em \"{deviceName}\" ({date}). Ao adotá-la, os dados deste dispositivo serão substituídos pela biblioteca restaurada. Primeiro será criado um backup de segurança dos dados atuais deste dispositivo.",
  "settings_cloudSync_adopt_dialogTitle": "Adotar a biblioteca restaurada?",
  "settings_cloudSync_adopt_notNow": "Agora não",
  "settings_cloudSync_replace_banner": "Sincronização pausada: a biblioteca foi substituída a partir de um backup em \"{deviceName}\". Toque em Sincronizar agora para revisar."
```

**app_hu.arb:**
```json
  "backup_replaceConfirm_confirm": "Csere mindenhol",
  "backup_replaceConfirm_content": "Az összes szinkronizált eszközön lévő könyvtár erre a biztonsági mentésre cserélődik. Minden eszköz először biztonsági mentést készít a jelenlegi adatairól. Ez nem vonható vissza.",
  "backup_replaceConfirm_title": "Könyvtár cseréje mindenhol?",
  "backup_restore_dialog_modeMerge_subtitle": "Visszaállítás erre az eszközre. A következő szinkronizálás egyesíti a visszaállított adatokat a felhőkönyvtárral.",
  "backup_restore_dialog_modeMerge_title": "Egyesítés a következő szinkronizáláskor",
  "backup_restore_dialog_modeReplace_subtitle": "A biztonsági mentés lesz a könyvtár ezen az eszközön, a felhőben és minden szinkronizált eszközön.",
  "backup_restore_dialog_modeReplace_title": "Csere mindenhol",
  "backup_restore_dialog_restoreReplace": "Visszaállítás és csere mindenhol",
  "settings_cloudSync_adopt_confirm": "Visszaállított könyvtár átvétele",
  "settings_cloudSync_adopt_dialogContent": "A könyvtárat egy biztonsági mentésből cserélték le a(z) \"{deviceName}\" eszközön ({date}). Az átvétellel ennek az eszköznek az adatai a visszaállított könyvtárra cserélődnek. Először biztonsági mentés készül az eszköz jelenlegi adatairól.",
  "settings_cloudSync_adopt_dialogTitle": "Átveszi a visszaállított könyvtárat?",
  "settings_cloudSync_adopt_notNow": "Most nem",
  "settings_cloudSync_replace_banner": "A szinkronizálás szünetel: a könyvtárat egy biztonsági mentésből cserélték le a(z) \"{deviceName}\" eszközön. Koppintson a Szinkronizálás most gombra az áttekintéshez."
```

**app_zh.arb:**
```json
  "backup_replaceConfirm_confirm": "全部替换",
  "backup_replaceConfirm_content": "所有已同步设备上的资料库都将被此备份替换。每台设备会先为其当前数据创建安全备份。此操作无法撤销。",
  "backup_replaceConfirm_title": "在所有设备上替换资料库？",
  "backup_restore_dialog_modeMerge_subtitle": "恢复到此设备。下次同步时会将恢复的数据与云端资料库合并。",
  "backup_restore_dialog_modeMerge_title": "下次同步时合并",
  "backup_restore_dialog_modeReplace_subtitle": "此备份将成为本设备、云端及所有已同步设备上的资料库。",
  "backup_restore_dialog_modeReplace_title": "全部替换",
  "backup_restore_dialog_restoreReplace": "恢复并全部替换",
  "settings_cloudSync_adopt_confirm": "采用恢复的资料库",
  "settings_cloudSync_adopt_dialogContent": "资料库已被 \"{deviceName}\" 上的备份替换（{date}）。采用后，此设备的数据将被恢复的资料库替换。系统会先为此设备的当前数据创建安全备份。",
  "settings_cloudSync_adopt_dialogTitle": "采用恢复的资料库？",
  "settings_cloudSync_adopt_notNow": "暂不",
  "settings_cloudSync_replace_banner": "同步已暂停：资料库已被 \"{deviceName}\" 上的备份替换。点按\"立即同步\"以查看。"
```

**app_ar.arb:**
```json
  "backup_replaceConfirm_confirm": "استبدال في كل مكان",
  "backup_replaceConfirm_content": "سيتم استبدال المكتبة على جميع الأجهزة المتزامنة بهذه النسخة الاحتياطية. يقوم كل جهاز أولاً بإنشاء نسخة احتياطية آمنة من بياناته الحالية. لا يمكن التراجع عن هذا الإجراء.",
  "backup_replaceConfirm_title": "استبدال المكتبة في كل مكان؟",
  "backup_restore_dialog_modeMerge_subtitle": "الاستعادة على هذا الجهاز. ستدمج المزامنة التالية البيانات المستعادة مع مكتبة السحابة.",
  "backup_restore_dialog_modeMerge_title": "الدمج عند المزامنة التالية",
  "backup_restore_dialog_modeReplace_subtitle": "تصبح النسخة الاحتياطية هي المكتبة على هذا الجهاز وفي السحابة وعلى كل جهاز متزامن.",
  "backup_restore_dialog_modeReplace_title": "استبدال في كل مكان",
  "backup_restore_dialog_restoreReplace": "استعادة واستبدال في كل مكان",
  "settings_cloudSync_adopt_confirm": "اعتماد المكتبة المستعادة",
  "settings_cloudSync_adopt_dialogContent": "تم استبدال المكتبة من نسخة احتياطية على \"{deviceName}\" ({date}). عند الاعتماد، سيتم استبدال بيانات هذا الجهاز بالمكتبة المستعادة. سيتم أولاً إنشاء نسخة احتياطية آمنة من البيانات الحالية لهذا الجهاز.",
  "settings_cloudSync_adopt_dialogTitle": "اعتماد المكتبة المستعادة؟",
  "settings_cloudSync_adopt_notNow": "ليس الآن",
  "settings_cloudSync_replace_banner": "المزامنة متوقفة مؤقتًا: تم استبدال المكتبة من نسخة احتياطية على \"{deviceName}\". اضغط على \"مزامنة الآن\" للمراجعة."
```

**app_he.arb:**
```json
  "backup_replaceConfirm_confirm": "החלפה בכל מקום",
  "backup_replaceConfirm_content": "הספרייה בכל המכשירים המסונכרנים תוחלף בגיבוי זה. כל מכשיר יוצר תחילה גיבוי בטיחות של הנתונים הנוכחיים שלו. לא ניתן לבטל פעולה זו.",
  "backup_replaceConfirm_title": "להחליף את הספרייה בכל מקום?",
  "backup_restore_dialog_modeMerge_subtitle": "שחזור במכשיר זה. הסנכרון הבא ישלב את הנתונים המשוחזרים עם ספריית הענן.",
  "backup_restore_dialog_modeMerge_title": "מיזוג בסנכרון הבא",
  "backup_restore_dialog_modeReplace_subtitle": "הגיבוי הופך לספרייה במכשיר זה, בענן ובכל מכשיר מסונכרן.",
  "backup_restore_dialog_modeReplace_title": "החלפה בכל מקום",
  "backup_restore_dialog_restoreReplace": "שחזור והחלפה בכל מקום",
  "settings_cloudSync_adopt_confirm": "אימוץ הספרייה המשוחזרת",
  "settings_cloudSync_adopt_dialogContent": "הספרייה הוחלפה מגיבוי במכשיר \"{deviceName}\" ({date}). אימוץ יחליף את נתוני מכשיר זה בספרייה המשוחזרת. תחילה ייווצר גיבוי בטיחות של הנתונים הנוכחיים של מכשיר זה.",
  "settings_cloudSync_adopt_dialogTitle": "לאמץ את הספרייה המשוחזרת?",
  "settings_cloudSync_adopt_notNow": "לא עכשיו",
  "settings_cloudSync_replace_banner": "הסנכרון מושהה: הספרייה הוחלפה מגיבוי במכשיר \"{deviceName}\". יש להקיש על \"סנכרן עכשיו\" לבדיקה."
```

Each of the two parameterized keys also needs its `@` metadata block in every locale file, identical to the English one.

- [ ] **Step 3: Regenerate and verify**

Run: `flutter gen-l10n`
Expected: completes; the pre-existing "14 untranslated message(s)" per locale count stays at 14 (our 13 new keys are translated everywhere; do NOT fix the pre-existing 14 — out of scope).

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 4: Format and commit**

```bash
dart format lib/ test/
git add lib/l10n/
git commit -m "feat(l10n): strings for restore Replace mode and library adoption"
```

---

### Task 13: Restore dialog mode choice + page wiring

**Files:**
- Modify: `lib/features/backup/presentation/widgets/restore_confirmation_dialog.dart`
- Modify: `lib/features/backup/presentation/pages/backup_settings_page.dart` (~line 240 and ~line 355)
- Test: `test/features/backup/presentation/widgets/restore_confirmation_dialog_test.dart` (create)

- [ ] **Step 1: Write the failing widget tests**

Create the test file. House widget tests wrap in `MaterialApp` with localization delegates — copy the `pumpWidget` scaffold (MaterialApp + `AppLocalizations.delegate` etc.) from `test/features/settings/presentation/pages/cloud_sync_page_test.dart`'s helper. Build a minimal `BackupRecord` as `backup_settings_page` does (id 'temp', `BackupLocation.local`).

```dart
  Future<RestoreMode?> pumpAndOpen(
    WidgetTester tester, {
    required bool offerReplace,
  }) async {
    RestoreMode? result;
    await tester.pumpWidget(
      wrapApp(
        Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              result = await RestoreConfirmationDialog.show(
                context,
                record,
                currentSchemaVersion: 80,
                offerReplace: offerReplace,
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return result;
  }

  testWidgets('without offerReplace there is no mode choice', (tester) async {
    await pumpAndOpen(tester, offerReplace: false);
    expect(find.text('Merge on next sync'), findsNothing);
    expect(find.text('Restore'), findsOneWidget);
  });

  testWidgets('confirming with merge selected returns RestoreMode.merge', (tester) async {
    await pumpAndOpen(tester, offerReplace: true);
    expect(find.text('Merge on next sync'), findsOneWidget);
    expect(find.text('Replace everywhere'), findsOneWidget);
    await tester.tap(find.text('Restore'));
    await tester.pumpAndSettle();
    // result captured by pumpAndOpen's closure
  });

  testWidgets('replace requires the second confirmation', (tester) async {
    await pumpAndOpen(tester, offerReplace: true);
    await tester.tap(find.text('Replace everywhere'));
    await tester.pumpAndSettle();
    expect(find.text('Restore and Replace Everywhere'), findsOneWidget);
    await tester.tap(find.text('Restore and Replace Everywhere'));
    await tester.pumpAndSettle();
    // Second confirmation appears.
    expect(find.text('Replace Library Everywhere?'), findsOneWidget);
    await tester.tap(find.text('Replace Everywhere'));
    await tester.pumpAndSettle();
    // Dialog closed, RestoreMode.replace returned.
  });

  testWidgets('cancel returns null', (tester) async {
    await pumpAndOpen(tester, offerReplace: true);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
  });
```

Assert the captured `result` values at the end of each test (`RestoreMode.merge`, `RestoreMode.replace`, `null`) — restructure `pumpAndOpen` to expose the captured value (e.g., return a `ValueGetter<RestoreMode?>`), since `show` only completes when the dialog closes.

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/features/backup/presentation/widgets/restore_confirmation_dialog_test.dart`
Expected: FAIL — `show` has no `offerReplace` and returns `bool`.

- [ ] **Step 3: Rewrite the dialog**

Rework `restore_confirmation_dialog.dart`:

1. Convert to a `StatefulWidget` holding `RestoreMode _mode = RestoreMode.merge;`. Add `final bool offerReplace;` to fields/constructor.
2. Change `show` to:

```dart
  /// Shows the dialog. Returns the chosen restore mode, or null on cancel.
  static Future<RestoreMode?> show(
    BuildContext context,
    BackupRecord record, {
    required int currentSchemaVersion,
    bool offerReplace = false,
  }) {
    return showDialog<RestoreMode>(
      context: context,
      builder: (_) => RestoreConfirmationDialog(
        record: record,
        currentSchemaVersion: currentSchemaVersion,
        offerReplace: offerReplace,
      ),
    );
  }
```

3. In `_buildManual`, between the details card and the warning row, insert (only when `offerReplace`):

```dart
          if (widget.offerReplace) ...[
            const SizedBox(height: 12),
            RadioListTile<RestoreMode>(
              value: RestoreMode.merge,
              groupValue: _mode,
              onChanged: (v) => setState(() => _mode = v!),
              title: Text(context.l10n.backup_restore_dialog_modeMerge_title),
              subtitle: Text(
                context.l10n.backup_restore_dialog_modeMerge_subtitle,
              ),
              contentPadding: EdgeInsets.zero,
              dense: true,
            ),
            RadioListTile<RestoreMode>(
              value: RestoreMode.replace,
              groupValue: _mode,
              onChanged: (v) => setState(() => _mode = v!),
              title: Text(
                context.l10n.backup_restore_dialog_modeReplace_title,
              ),
              subtitle: Text(
                context.l10n.backup_restore_dialog_modeReplace_subtitle,
              ),
              contentPadding: EdgeInsets.zero,
              dense: true,
            ),
          ],
```

Wrap the dialog `content` Column in `SingleChildScrollView` if it overflows in tests (`content: SingleChildScrollView(child: Column(...))`).

4. Replace the confirm `FilledButton` with:

```dart
        FilledButton(
          onPressed: () => _confirm(context),
          style: FilledButton.styleFrom(
            backgroundColor: theme.colorScheme.error,
          ),
          child: Text(
            _mode == RestoreMode.replace
                ? context.l10n.backup_restore_dialog_restoreReplace
                : context.l10n.backup_restore_dialog_restore,
          ),
        ),
```

with the cancel button popping `null` (`Navigator.of(context).pop()`), and:

```dart
  Future<void> _confirm(BuildContext context) async {
    if (_mode == RestoreMode.merge) {
      Navigator.of(context).pop(RestoreMode.merge);
      return;
    }
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final sure = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.backup_replaceConfirm_title),
        content: Text(l10n.backup_replaceConfirm_content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.backup_restore_dialog_cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: theme.colorScheme.error,
            ),
            child: Text(l10n.backup_replaceConfirm_confirm),
          ),
        ],
      ),
    );
    if (sure == true && context.mounted) {
      Navigator.of(context).pop(RestoreMode.replace);
    }
  }
```

5. The pre-migration variants (`_buildPreMigration`): in the two restorable branches (schema match and "Restore anyway"), keep their current single-button flow but pop `RestoreMode.merge` instead of `true`, and pop `null` instead of `false` for cancels. The mode radio is NOT added to pre-migration dialogs — they are an emergency recovery path; replace-everywhere can be run afterwards from a normal restore. (This narrows spec section 4's pre-migration sentence; record the narrowing in the commit message and PR description.)

Add the import: `import 'package:submersion/features/backup/domain/entities/restore_mode.dart';`

6. Update both call sites in `backup_settings_page.dart`. In `_handleImport` (~line 240):

```dart
    final offerReplace =
        ref.read(cloudStorageProviderProvider) != null;
    final mode = await RestoreConfirmationDialog.show(
      context,
      record,
      currentSchemaVersion: AppDatabase.currentSchemaVersion,
      offerReplace: offerReplace,
    );
    if (mode != null) {
      ref
          .read(backupOperationProvider.notifier)
          .restoreFromFilePath(filePath, mode: mode);
    }
```

In `_handleHistoryAction` (~line 355):

```dart
      case 'restore':
        final offerReplace =
            ref.read(cloudStorageProviderProvider) != null;
        final mode = await RestoreConfirmationDialog.show(
          context,
          record,
          currentSchemaVersion: AppDatabase.currentSchemaVersion,
          offerReplace: offerReplace,
        );
        if (mode != null) {
          ref
              .read(backupOperationProvider.notifier)
              .restoreFromBackup(record, mode: mode);
        }
```

Add imports for `cloudStorageProviderProvider` (from `sync_providers.dart`) and `restore_mode.dart` to the page.

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/backup/presentation/widgets/restore_confirmation_dialog_test.dart test/features/backup/presentation/pages/backup_settings_page_test.dart`
Expected: PASS. If `backup_settings_page_test.dart` stubs `RestoreConfirmationDialog.show`'s old bool return, update those expectations to the new `RestoreMode?` API.

- [ ] **Step 5: Format and commit**

```bash
dart format lib/ test/
git add lib/features/backup/ test/features/backup/
git commit -m "feat(backup): restore dialog offers merge vs replace-everywhere"
```

---

### Task 14: SyncNotifier — awaiting state, silent adopt, launch trigger

**Files:**
- Modify: `lib/features/settings/presentation/providers/sync_providers.dart`
- Modify: `test/features/settings/presentation/pages/cloud_sync_page_test.dart` (`_FakeSyncNotifier`)
- Modify: `test/features/settings/presentation/s3_config_page_test.dart` (its SyncNotifier fake)
- Test: extend whichever provider-level sync test exists (`test/features/settings/...sync_providers_test.dart`); if none exists, the state-mapping coverage lives in Task 15's widget tests — still add the fakes' members here so everything compiles.

- [ ] **Step 1: Add the epoch store provider and service wiring**

In `sync_providers.dart`:

```dart
/// Library epoch persistence (mirror + pending replace intent).
final libraryEpochStoreProvider = Provider<LibraryEpochStore>((ref) {
  return LibraryEpochStore(ref.watch(sharedPreferencesProvider));
});
```

and extend `syncServiceProvider` (~line 131):

```dart
final syncServiceProvider = Provider<SyncService>((ref) {
  return SyncService(
    syncRepository: ref.watch(syncRepositoryProvider),
    serializer: ref.watch(syncDataSerializerProvider),
    cloudProvider: ref.watch(cloudStorageProviderProvider),
    syncInitializer: ref.watch(syncInitializerProvider),
    epochStore: ref.watch(libraryEpochStoreProvider),
  );
});
```

Add imports: `library_epoch.dart`, `library_epoch_store.dart`, and `realignActiveDiverAfterDataReplace` (from `diver_providers.dart`).

- [ ] **Step 2: Extend SyncState**

Add two fields, following the `message` sentinel pattern for the clearable marker:

```dart
  final bool replaceAwaitingAdoption;
  final LibraryEpochMarker? replaceMarker;
  static const Object _markerSentinel = Object();
```

Constructor: `this.replaceAwaitingAdoption = false, this.replaceMarker,`.

`copyWith`: add `bool? replaceAwaitingAdoption, Object? replaceMarker = _markerSentinel,` and in the body:

```dart
      replaceAwaitingAdoption:
          replaceAwaitingAdoption ?? this.replaceAwaitingAdoption,
      replaceMarker: identical(replaceMarker, _markerSentinel)
          ? this.replaceMarker
          : replaceMarker as LibraryEpochMarker?,
```

- [ ] **Step 3: Map the awaiting result + silent adopt in `performSync`**

In `SyncNotifier.performSync` (~line 347), replace the single service call line:

```dart
        final result = await _syncService.performSync();
```

with:

```dart
        var result = await _syncService.performSync();

        if (result.status == SyncResultStatus.awaitingAdoption) {
          final diveCount = await _ref
              .read(diveRepositoryProvider)
              .getDiveCount();
          if (diveCount == 0) {
            // Nothing local to lose: adopt silently, like an empty device
            // joining sync, then run the normal sync to upload our file.
            final adopt = await _syncService.adoptReplacedLibrary();
            if (adopt.isSuccess) {
              await realignActiveDiverAfterDataReplace(
                _ref.read(sharedPreferencesProvider),
              );
              result = await _syncService.performSync();
            } else {
              result = adopt;
            }
          } else {
            state = state.copyWith(
              status: SyncStatus.idle,
              replaceAwaitingAdoption: true,
              replaceMarker: result.replaceMarker,
              message:
                  'Sync paused: the library was replaced from a backup. '
                  'Tap Sync Now to review.',
              progress: null,
            );
            return;
          }
        }
```

Also add `replaceAwaitingAdoption: false, replaceMarker: null,` to the `state = state.copyWith(status: SyncStatus.syncing, ...)` block at the start of the sync (next to `firstSyncAwaitingConfirmation: false`) so a successful flow clears stale flags.

- [ ] **Step 4: Add the notifier methods**

After `firstSyncMergeInfo()` (~line 307):

```dart
  /// Non-null when the cloud library was replaced under an epoch this device
  /// has not accepted -- the next sync would halt for adoption. Mirrors the
  /// firstSyncMergeInfo() pre-check pattern for the Sync Now button.
  Future<LibraryEpochMarker?> libraryReplaceInfo() async {
    try {
      final provider = _ref.read(cloudStorageProviderProvider);
      if (provider == null) return null;
      final store = _ref.read(libraryEpochStoreProvider);
      if (store.pendingReplace != null) return null; // we ARE the replacer
      final marker = await _syncService
          .readLibraryEpochMarker(provider)
          .timeout(const Duration(seconds: 8));
      if (marker == null) return null;
      final accepted =
          await _syncRepository.getLastAcceptedEpochId() ??
          store.lastAcceptedEpochId;
      if (marker.epochId == accepted) return null;
      return marker;
    } catch (e) {
      // Never block the button on this pre-check; performSync gates anyway.
      _log.warning('Library replace pre-check failed: $e');
      return null;
    }
  }

  /// Adopt the replaced cloud library. The CALLER is responsible for the
  /// safety backup (cloud_sync_page runs it via backupServiceProvider to
  /// avoid a provider import cycle). Ends with a follow-up sync that uploads
  /// this device's freshly stamped file.
  Future<void> adoptReplacedLibrary() async {
    if (_syncInFlight || state.status == SyncStatus.syncing) return;
    state = state.copyWith(
      status: SyncStatus.syncing,
      message: 'Adopting the restored library...',
    );
    final result = await _syncService.adoptReplacedLibrary();
    if (!result.isSuccess) {
      state = state.copyWith(
        status: SyncStatus.error,
        message: result.message ?? 'Failed to adopt the restored library',
      );
      return;
    }
    await realignActiveDiverAfterDataReplace(
      _ref.read(sharedPreferencesProvider),
    );
    state = state.copyWith(
      status: SyncStatus.idle,
      replaceAwaitingAdoption: false,
      replaceMarker: null,
      message: null,
    );
    await performSync();
  }
```

- [ ] **Step 5: Launch trigger + reset hygiene**

1. At the end of `_initialize()` in SyncNotifier, add:

```dart
    // A Replace restore persists its cloud side as a pending intent; execute
    // it as soon as the app is back up, regardless of auto-sync settings.
    if (_ref.read(libraryEpochStoreProvider).pendingReplace != null) {
      unawaited(performSync());
    }
```

(`unawaited` from `dart:async` — already imported in this file for stream use; add `import 'dart:async';` if missing.)

2. In `resetSyncState()` (~line 436), after `await _syncService.resetSyncState();` add:

```dart
    await _ref.read(libraryEpochStoreProvider).clearPendingReplace();
    state = state.copyWith(
      replaceAwaitingAdoption: false,
      replaceMarker: null,
    );
```

- [ ] **Step 6: Fix the fakes**

Both `_FakeSyncNotifier` in `test/features/settings/presentation/pages/cloud_sync_page_test.dart` and the SyncNotifier fake in `test/features/settings/presentation/s3_config_page_test.dart` use `implements SyncNotifier`, so they now fail to compile. Add to each:

```dart
  LibraryEpochMarker? replaceInfo;
  int adoptCalls = 0;

  @override
  Future<LibraryEpochMarker?> libraryReplaceInfo() async => replaceInfo;

  @override
  Future<void> adoptReplacedLibrary() async {
    adoptCalls++;
  }
```

(plus the `library_epoch.dart` import in each test file).

- [ ] **Step 7: Verify everything compiles and existing tests pass**

Run: `flutter analyze`
Expected: `No issues found!` (this is the gate that catches any fake or call site missed — the SettingsNotifier-mocks lesson).

Run: `flutter test test/features/settings/presentation/pages/cloud_sync_page_test.dart test/features/settings/presentation/s3_config_page_test.dart`
Expected: PASS.

- [ ] **Step 8: Format and commit**

```bash
dart format lib/ test/
git add lib/features/settings/presentation/providers/sync_providers.dart test/features/settings/
git commit -m "feat(sync): awaiting-adoption state, silent empty adopt, pending replace launch trigger"
```

---

### Task 15: Cloud sync page — banner and adopt dialog

**Files:**
- Modify: `lib/features/settings/presentation/pages/cloud_sync_page.dart` (banner block ~line 578; `_onSyncNowPressed` ~line 772)
- Test: extend `test/features/settings/presentation/pages/cloud_sync_page_test.dart`

- [ ] **Step 1: Write the failing widget tests**

Using the file's existing fakes and pump helper:

```dart
  testWidgets('shows replace banner when awaiting adoption', (tester) async {
    // Arrange the fake notifier's state with replaceAwaitingAdoption: true
    // and a marker (deviceName: 'Eric Mac').
    ...
    expect(
      find.textContaining('the library was replaced from a backup'),
      findsOneWidget,
    );
  });

  testWidgets('Sync Now offers adopt dialog when a replace is pending', (tester) async {
    // fake.replaceInfo = marker; tap Sync Now.
    ...
    expect(find.text('Adopt Restored Library?'), findsOneWidget);
    await tester.tap(find.text('Adopt Restored Library'));
    await tester.pumpAndSettle();
    expect(fake.adoptCalls, 1);
  });

  testWidgets('Not Now leaves sync paused without adopting', (tester) async {
    ...
    await tester.tap(find.text('Not Now'));
    await tester.pumpAndSettle();
    expect(fake.adoptCalls, 0);
  });
```

Replace each `...` with the file's concrete arrange/pump idiom (copy from the existing firstSync banner/dialog tests in the same file, which exercise the same pattern).

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/features/settings/presentation/pages/cloud_sync_page_test.dart`
Expected: new tests FAIL (no banner/dialog yet).

- [ ] **Step 3: Implement the banner**

In `cloud_sync_page.dart`, directly above the existing `if (syncState.firstSyncAwaitingConfirmation)` banner (~line 578), add a sibling banner with the same Card layout but `errorContainer` colors:

```dart
        if (syncState.replaceAwaitingAdoption)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Card(
              color: Theme.of(context).colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(
                      Icons.restore_page_outlined,
                      color: Theme.of(context).colorScheme.onErrorContainer,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        context.l10n.settings_cloudSync_replace_banner(
                          syncState.replaceMarker?.deviceName ??
                              syncState.replaceMarker?.deviceId ??
                              '?',
                        ),
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
```

- [ ] **Step 4: Implement the adopt branch in `_onSyncNowPressed`**

At the top of `_onSyncNowPressed` (before the firstSync check):

```dart
    final notifier = ref.read(syncStateProvider.notifier);
    final replaceInfo = await notifier.libraryReplaceInfo();
    if (replaceInfo != null) {
      if (!context.mounted) return;
      await _showAdoptDialog(context, ref, replaceInfo);
      return;
    }
```

(then the existing body continues; it already declares `notifier` — remove the duplicate declaration). Add the dialog method:

```dart
  /// Confirm and run adoption of a replaced cloud library. The safety backup
  /// runs here (not in SyncNotifier) because backup providers import sync
  /// providers; the page is the layer that may import both.
  Future<void> _showAdoptDialog(
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
          l10n.settings_cloudSync_adopt_dialogContent(
            marker.deviceName ?? marker.deviceId,
            date,
          ),
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
    await ref.read(backupServiceProvider).performBackup();
    await ref.read(syncStateProvider.notifier).adoptReplacedLibrary();
  }
```

Add imports: `package:intl/intl.dart` (if absent), `library_epoch.dart`, and `backup_providers.dart` (for `backupServiceProvider`).

- [ ] **Step 5: Run tests to verify they pass**

Run: `flutter test test/features/settings/presentation/pages/cloud_sync_page_test.dart`
Expected: PASS. (The fake notifier's `adoptReplacedLibrary` counts calls; the safety-backup line needs `backupServiceProvider` overridden in the test harness — override it with a fake `BackupService` or override the provider to a no-op fake, following how the test file already overrides other providers.)

- [ ] **Step 6: Format and commit**

```bash
dart format lib/ test/
git add lib/features/settings/presentation/pages/cloud_sync_page.dart test/features/settings/presentation/pages/cloud_sync_page_test.dart
git commit -m "feat(sync): replace banner and adopt-restored-library dialog"
```

---

### Task 16: Final verification

**Files:** none (verification only; fix anything found and amend the relevant commit area).

- [ ] **Step 1: Format check**

Run: `dart format lib/ test/`
Expected: `0 changed` (if files changed, commit the formatting with the nearest relevant scope).

- [ ] **Step 2: Whole-project analyze (never piped/filtered)**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 3: Test suite in chunks (avoid timeout on broad directories)**

Run each, expecting PASS:

```bash
flutter test test/core/services/sync/
flutter test test/core/data/repositories/
flutter test test/features/backup/
flutter test test/features/settings/presentation/pages/cloud_sync_page_test.dart test/features/settings/presentation/s3_config_page_test.dart
```

Then the remaining suite:

```bash
flutter test test/ --exclude-tags=slow
```

(If the repo does not use tags, run `flutter test test/` with a 10-minute timeout; if the harness cannot, run remaining top-level test directories individually.)

- [ ] **Step 4: Manual verification notes (cannot be automated)**

Record in the PR description, not in code:

- iCloud ubiquity containers do not propagate in the iOS Simulator. Final acceptance needs real hardware: Replace on the Mac, observe the iPhone's paused banner and adopt flow; then the reverse direction.
- Replace propagates correctly only once all devices run this app version; older versions ignore the marker (spec section 8 limitation — include in release notes).

- [ ] **Step 5: Hand off**

Use superpowers:finishing-a-development-branch to decide merge/PR/cleanup.

---

## Self-review checklist results (kept for the executor's awareness)

- Spec coverage: every spec section maps to tasks — UX dialog (13), peer banner/prompt (14, 15), epoch mechanism (1-4), replace flow (7, 10), gating (8), adoption (9, 14, 15), parity fix (10), reconcile dual-anchor (5), reset hygiene (14), l10n (12), testing strategy (throughout), compatibility/manual notes (16).
- Known narrowing vs spec: pre-migration restore dialogs do NOT get the mode radio (Task 13 Step 3.5 records why); spec section 4 said they would. Surface this in the PR for sign-off.
- Type consistency: `LibraryEpochMarker`/`LibraryEpochStore`/`RestoreMode` names and signatures are used identically across tasks 2-15; `SyncResultStatus.awaitingAdoption` + `SyncResult.replaceMarker` introduced in Task 8 and consumed in 14.
