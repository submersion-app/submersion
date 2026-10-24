# Cross-device Backup Retention Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task (inline, in this session). Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** An opt-in, off-by-default switch that makes "Keep the last N backups" a ceiling on the whole shared cloud backup folder, with cross-device pin markers and a confirmation listing every backup it removes.

**Architecture:** Two pure modules decide things (pin-marker names, and which listed files a prune removes); a `part` of `BackupService` performs them against the cloud provider (marker writes, reconciliation, preview, apply) and hooks them into `pruneOldBackups` and pinning. The settings page gains a switch, a confirmation dialog and two small flows (turning on, lowering the number).

**Tech Stack:** Flutter, Riverpod (StateNotifier and FutureProvider), SharedPreferences, `CloudStorageProvider`, ARB l10n (10 locales).

**Spec:** `docs/design/specs/2026-10-23-cross-device-backup-retention-design.md`

## Global Constraints

- Switch default is off; stored as the confirmed cloud account key under the new pref `backup_retention_all_devices_account` (no migration, no schema change).
- Marker name: `<backup name without extension>__p<deviceTag(pinningDeviceId)>.pin`. Fixed once shipped.
- Order backups by the timestamp in the name (`submersion_backup_yyyy-MM-dd_HHmmss`), falling back to `modifiedTime`.
- Grace period: never delete a backup whose name timestamp OR modified time is less than 24 hours before now.
- Only cloud copies are deleted by the cross-device rule; nothing on the device is touched by it.
- A failure in the rule never fails the backup that triggered it.
- Every new string goes into all 10 ARB files (`ar de en es fr he hu it nl pt zh`), translated, in the backup group of each file.
- `backup_service.dart` is over 800 lines: new service code goes in a new `part` file, not in it, beyond the few hook lines named below.
- No em dashes anywhere, no emojis.

## Review Focus

1. Encrypted cloud copies are `X.sbe` while the record says `X.db`: stems, markers and local-pin matching must use the name without extension. Test in Task 1 and Task 4.
2. The re-listing before deletion fails: nothing is deleted. Test in Task 5.
3. The device id is unavailable or empty: no marker is written or deleted, pinning still succeeds, the rule still runs. Test in Task 4.
4. The folder holds prefix-matching non-backups (`.db.tmp`, `X (conflicted copy).db`, `.pin`): never counted or deleted as backups. Test in Task 2.
5. The cloud account changed after the switch was confirmed: the rule does not run and the switch reads as off. Test in Task 3 and Task 5.

---

### Task 1: Pin marker names

**Files:**
- Create: `lib/features/backup/data/services/backup_pin_markers.dart`
- Test: `test/features/backup/data/services/backup_pin_markers_test.dart`

**Interfaces:**
- Produces:
  - `const String pinMarkerExtension = '.pin';`
  - `String pinMarkerName({required String backupFilename, required String pinningDeviceId})`
  - `typedef PinMarker = ({String backupStem, String deviceTag});`
  - `PinMarker? parsePinMarker(String name)` (null for anything that is not exactly `submersion_backup_...__p<16 hex>.pin`)
  - `String backupStem(String filename)` (the name without `.db`/`.sbe`, `p.basenameWithoutExtension`)

- [ ] **Step 1: Write the failing tests**

```dart
test('marker name drops the extension and adds the pinning device tag', () {
  final tag = deviceTag('dev-B');
  expect(
    pinMarkerName(backupFilename: 'submersion_backup_2026-10-01_090000__d0123456789abcdef.sbe', pinningDeviceId: 'dev-B'),
    'submersion_backup_2026-10-01_090000__d0123456789abcdef__p$tag.pin',
  );
});
test('.db and .sbe copies of one backup share a marker', ...); // same output for both extensions
test('parsePinMarker round-trips', ...); // backupStem and deviceTag back out
test('parsePinMarker rejects non-markers', () {
  for (final n in ['submersion_backup_X.db', 'submersion_backup_X__pZZ.pin', 'other__p0123456789abcdef.pin', 'submersion_backup_X__p0123456789abcdef.pin.tmp']) {
    expect(parsePinMarker(n), isNull, reason: n);
  }
});
```

- [ ] **Step 2: Run, expect FAIL** (`flutter test test/features/backup/data/services/backup_pin_markers_test.dart`: undefined names)
- [ ] **Step 3: Implement** reusing `deviceTag` and the 16-hex rule from `backup_attribution.dart` (export a public `isDeviceTag(String)` there rather than duplicating the regex).
- [ ] **Step 4: Run, expect PASS**
- [ ] **Step 5: Commit** `feat(backup): name cross-device pin markers`

### Task 2: The cross-device retention planner

**Files:**
- Create: `lib/features/backup/data/services/cross_device_retention.dart`
- Modify: `lib/features/backup/data/services/cloud_backup_history.dart` (make `_timestampFromName` public as `backupTimestampFromName`)
- Test: `test/features/backup/data/services/cross_device_retention_test.dart`

**Interfaces:**
- Consumes: Task 1 (`parsePinMarker`, `backupStem`); `classifyBackupFile`, `backupFileExtensions` from `backup_attribution.dart`.
- Produces:

```dart
class RetentionCandidate {            // one backup the plan removes
  final CloudFileInfo file;
  final DateTime timestamp;           // name timestamp, else modifiedTime
  final BackupOwnership ownership;    // from classifyBackupFile
}
class CrossDeviceRetentionPlan {
  final int keepCount;
  final List<RetentionCandidate> toDelete;   // oldest last
  final List<CloudFileInfo> orphanMarkers;   // markers whose backup is not listed
  final int pinnedKept;                      // backups skipped because pinned
  int get totalBytes;                        // sum of toDelete sizes (null size = 0)
  bool get isEmpty;                          // toDelete.isEmpty
}
CrossDeviceRetentionPlan planCrossDeviceRetention({
  required Iterable<CloudFileInfo> listing,
  required int keepCount,
  required Set<String> locallyPinnedStems,
  required Set<String> locallyPinnedFileIds,
  required String thisDeviceId,
  required DateTime now,
});
```

Algorithm: backups are listed files whose name starts `submersion_backup_` and whose extension is in `backupFileExtensions` (dedupe by id); markers are files `parsePinMarker` accepts. A backup is pinned when any marker has its stem, or its stem is in `locallyPinnedStems`, or its id is in `locallyPinnedFileIds`. Sort unpinned backups newest first by timestamp; skip the first `keepCount`; of the rest, drop any inside the 24-hour grace (name timestamp or `modifiedTime`); the remainder is `toDelete`.

- [ ] **Step 1: Write the failing tests** (seed `CloudFileInfo`s directly; `now = DateTime(2026, 10, 24, 12)`):
  - `keeps the newest keepCount and removes the rest, oldest last`: 7 backups dated days 1..7 Oct, keep 5, expect days 2 and 1 removed in that order.
  - `a marker from any device pins its backup, whatever the extension`: marker for `X` plus `X.sbe` listed; X not removed; `pinnedKept == 1`.
  - `locally pinned stems and file ids are kept`.
  - `pinned backups do not count toward keepCount`: 6 backups, newest pinned, keep 5: none removed.
  - `backups inside the 24 hour grace are never removed`: keep 1, two backups both named today: none removed; one named 3 Oct but `modifiedTime` 2 hours ago: kept.
  - `orders by the name, not modifiedTime`: names and modified times disagree; removal follows the names.
  - `prefix lookalikes are ignored` (Review Focus 4): `.db.tmp`, `X (conflicted copy).db` are never in `toDelete`.
  - `orphan markers are reported`: a marker whose stem is not listed lands in `orphanMarkers`.
  - `ownership comes from the name`: this device's tag, another tag, and an unattributed name classify as `thisDevice`, `otherDevice`, `unattributed`.
- [ ] **Step 2: Run, expect FAIL**
- [ ] **Step 3: Implement** in `cross_device_retention.dart`.
- [ ] **Step 4: Run, expect PASS**, plus `test/features/backup/data/services/cloud_backup_history_test.dart` still green.
- [ ] **Step 5: Commit** `feat(backup): plan cross-device retention from a cloud listing`

### Task 3: The setting

**Files:**
- Modify: `lib/features/backup/domain/entities/backup_settings.dart`, `lib/features/backup/data/repositories/backup_preferences.dart`, `lib/features/backup/presentation/providers/backup_settings_notifier.dart`
- Test: `test/features/backup/data/repositories/backup_preferences_test.dart` (extend; create the cross-device group if the file lacks one)

**Interfaces:**
- Produces:
  - `BackupSettings.crossDeviceRetentionAccount` (`String?`, in `props` and `copyWith`)
  - `bool BackupSettings.crossDeviceRetentionFor(String? accountId)`: true only when the stored value is non-null and equals `accountId ?? ''`.
  - `Future<void> BackupPreferences.setCrossDeviceRetentionAccount(String? accountKey)` (null removes the key)
  - `Future<void> BackupSettingsNotifier.setCrossDeviceRetentionAccount(String? accountKey)` (writes, then refreshes state like `setRetentionCount`)

- [ ] **Step 1: Failing tests:** default is off (`crossDeviceRetentionFor('acct') == false`); stored `'acct'` is on for `'acct'` and off for `'other'` (Review Focus 5); stored `''` is on for a null account; `setCrossDeviceRetentionAccount(null)` turns it off.
- [ ] **Step 2: Run, expect FAIL**
- [ ] **Step 3: Implement** with the key `backup_retention_all_devices_account`.
- [ ] **Step 4: Run, expect PASS**
- [ ] **Step 5: Commit** `feat(backup): store the cross-device retention switch per account`

### Task 4: Pin markers in the cloud folder

**Files:**
- Create: `lib/features/backup/data/services/backup_service_retention.dart` (`part of 'backup_service.dart'`)
- Modify: `lib/features/backup/data/services/backup_service.dart` (the `part` directive; `pinBackup`, `unpinBackup`, `pinRecord` call the marker helpers; `pruneOldBackups` hook, see Task 5)
- Modify: `test/helpers/fake_cloud_storage_provider.dart` (`seedFile(name, data, {DateTime? modified})`)
- Test: `test/features/backup/data/services/backup_service_pin_markers_test.dart`

**Interfaces:**
- Consumes: Task 1.
- Produces (in a public `extension BackupServiceRetention on BackupService` in the part file):
  - `Future<String?> thisDeviceIdOrNull()` (null when unreadable or empty)
  - private `Future<List<CloudFileInfo>?> _listCloudFolder()` (null on any failure, unlike `getCloudBackups`)
  - private `Future<void> _writePinMarker(BackupRecord record)` / `_deletePinMarker(BackupRecord record)`: best-effort, log and return on failure, no-op without provider, cloud copy here, or device id; flush deferred writes.
  - private `Future<void> _reconcilePinMarkers(List<CloudFileInfo> listing)`: upload this device's missing markers for pinned records whose cloud copy is listed (match by `cloudFileId` or stem); delete this device's markers for stems no longer pinned here; never touches another tag's markers.

- [ ] **Step 1: Failing tests** with `FakeCloudStorageProvider` and a fake `SyncRepository` device id:
  - `pinning a backup with a cloud copy writes this device's marker`
  - `unpinning deletes only this device's marker` (another device's marker for the same stem survives)
  - `a marker that cannot be written does not fail the pin` (`failUploads = true`; record still pinned)
  - `reconcile writes markers for pins made before this version, and removes stale ones`
  - `reconcile leaves other devices' markers alone`
  - `no device id: no marker written, pin still succeeds` (Review Focus 3)
  - `an .sbe cloud copy of an X.db record gets the X marker` (Review Focus 1)
- [ ] **Step 2: Run, expect FAIL**
- [ ] **Step 3: Implement**
- [ ] **Step 4: Run, expect PASS**, plus `test/features/backup/data/services/backup_service_test.dart` and `backup_service_cloud_history_test.dart`.
- [ ] **Step 5: Commit** `feat(backup): mirror pins into the cloud folder as markers`

### Task 5: Running the rule

**Files:**
- Modify: `lib/features/backup/data/services/backup_service_retention.dart`, `lib/features/backup/data/services/backup_service.dart` (`pruneOldBackups`), `lib/features/backup/domain/entities/backup_record.dart`
- Test: `test/features/backup/data/services/backup_service_cross_device_retention_test.dart`

**Interfaces:**
- Consumes: Tasks 2, 3, 4.
- Produces:
  - `BackupRecord withoutCloudCopy()` (location `local`, `cloudFileId` and `cloudAccountId` null)
  - `Future<String> crossDeviceRetentionAccountKey()` (`await _copyAccountIdOrNull() ?? ''`)
  - `Future<bool> crossDeviceRetentionActive()` (settings `crossDeviceRetentionFor` the current copy account)
  - `Future<CrossDeviceRetentionPlan?> previewCrossDeviceRetention(int keepCount)` (null when no provider, signed out, or the listing fails)
  - `Future<int> applyCrossDeviceRetention(CrossDeviceRetentionPlan plan)`: re-list (null listing: delete nothing, return 0); drop candidates that now have a marker; delete each (a delete that throws counts as done when `fileExists` says it is gone); delete `orphanMarkers`; flush once; for each deleted file that is a history record's cloud copy, `updateRecord(withoutCloudCopy())` when it has `localPath`, else `removeRecord`; returns files deleted.
  - In `pruneOldBackups(keepCount)`: list once; `_reconcilePinMarkers`; in the per-device loop, a record whose cloud stem has another device's marker keeps its cloud copy (local copy and record deleted as today); then, when `crossDeviceRetentionActive()`, preview and apply. All of it wrapped so a failure only logs.

- [ ] **Step 1: Failing tests:**
  - `with the switch on, a backup prunes the folder to keepCount across devices`: 8 old backups from three device tags, keep 5, `performBackup()`: the 3 oldest (plus the extra the new backup pushes out) are gone from the fake.
  - `with the switch off, other devices' backups are untouched` (today's behaviour).
  - `a switch confirmed for another account does nothing` (Review Focus 5).
  - `a marker that appears between preview and apply saves that backup`.
  - `a failed re-listing deletes nothing` (Review Focus 2, `failLists = true` before apply).
  - `a file already deleted elsewhere counts as deleted`.
  - `this device's own record loses only its cloud copy when it has a local copy`, and `is removed when cloud-only`.
  - `pre-migration and pre-downgrade backups are never in the listing` (their names do not start with `submersion_backup_`; register one of each and assert the plan ignores them).
  - `per-device pruning keeps a cloud copy another device pinned`.
  - `a rule failure does not fail the backup` (`failDeletes = true`; `performBackup` returns a record).
- [ ] **Step 2: Run, expect FAIL**
- [ ] **Step 3: Implement**
- [ ] **Step 4: Run, expect PASS**, plus every file in `test/features/backup/data/services/`.
- [ ] **Step 5: Commit** `feat(backup): apply the retention rule across devices`

### Task 6: History shows pins from other devices

**Files:**
- Modify: `lib/features/backup/domain/entities/backup_record.dart` (transient `pinnedOnAnotherDevice`, default false, in `props`/`copyWith`, never serialized), `lib/features/backup/data/services/cloud_backup_history.dart`, `lib/features/backup/presentation/providers/backup_providers.dart` (`backupHistoryProvider`), `lib/features/backup/presentation/widgets/backup_history_tile.dart`
- Test: `test/features/backup/data/services/cloud_backup_history_test.dart`, `test/features/backup/presentation/widgets/backup_history_tile_test.dart`

**Interfaces:**
- Produces: `List<BackupRecord> markPinnedOnAnotherDevice(List<BackupRecord> rows, Iterable<CloudFileInfo> listing, {required String? thisDeviceId})`: a row not pinned here whose stem has a marker with a tag other than this device's gets `pinnedOnAnotherDevice: true`.

- [ ] **Step 1: Failing tests:** the helper marks a discovered row with another device's marker, ignores this device's own marker, leaves locally pinned rows alone; `toJson` has no `pinnedOnAnotherDevice`; the tile shows a filled pin, tooltip "Pinned on another device", and a disabled pin button.
- [ ] **Step 2: Run, expect FAIL**
- [ ] **Step 3: Implement**; the provider passes `await service.thisDeviceIdOrNull()`.
- [ ] **Step 4: Run, expect PASS**
- [ ] **Step 5: Commit** `feat(backup): show backups pinned on another device`

### Task 7: The switch, the confirmation and the strings

**Files:**
- Create: `lib/features/backup/presentation/widgets/cross_device_retention_dialog.dart`, `lib/features/backup/presentation/widgets/cross_device_retention_actions.dart`
- Modify: `lib/features/backup/presentation/widgets/backup_advanced_section.dart`, `lib/features/backup/presentation/providers/backup_providers.dart`, all 10 `lib/l10n/arb/app_*.arb`
- Test: `test/features/backup/presentation/widgets/cross_device_retention_dialog_test.dart`, `test/features/backup/presentation/widgets/backup_advanced_section_test.dart`

**Interfaces:**
- Consumes: Tasks 3 and 5.
- Produces:
  - `crossDeviceRetentionAvailableProvider` (bool): `settings.cloudBackupEnabled` and the copy target is `CopyToAccount` or `CopyFollowsSync` with a group.
  - `crossDeviceRetentionActiveProvider` (`FutureProvider.autoDispose<bool>`, watches settings and the service).
  - `Future<bool> showCrossDeviceRetentionDialog(BuildContext context, CrossDeviceRetentionPlan plan)`
  - `Future<void> setCrossDeviceRetention(BuildContext context, WidgetRef ref, bool on)`: off clears the pref. On: preview (null: snackbar `backup_retention_listFailed`, stays off); empty plan: save the account key; otherwise dialog, and on confirm save the key then `applyCrossDeviceRetention`, snackbar with the count removed; refresh history.
  - `Future<void> changeRetentionCount(BuildContext context, WidgetRef ref, int count)`: when active and `count` is lower, the same preview, dialog and apply, saving the count only on confirm; otherwise save as today.

Strings (English; translate for the other nine):

| Key | English |
| --- | --- |
| `backup_retention_allDevices_title` | Count backups from all devices |
| `backup_retention_allDevices_off` | Off: this device removes only the backups it made |
| `backup_retention_allDevices_on` | The cloud folder keeps the last {count} backups from every device. Pinned backups are kept. If other devices use this too, the smallest number wins. Update the app on every device first so their pins are seen. |
| `backup_retention_cloudFootprint` | {count} backups in the cloud folder use {size} |
| `backup_retention_confirm_title` | Remove {count} backups? (plural, `one{{count}...}` form) |
| `backup_retention_confirm_body` | Keeping the last {keep} backups removes these {count} backups ({size}) from the cloud folder. |
| `backup_retention_confirm_pinnedKept` | {count, plural, one{{count} pinned backup is kept.} other{{count} pinned backups are kept.}} |
| `backup_retention_confirm_action` | Remove {count} backups (plural) |
| `backup_retention_source_thisDevice` / `_anotherDevice` / `_unknown` | This device / Another device / Unknown device |
| `backup_retention_listFailed` | Could not read the cloud backup folder, so nothing was changed. |
| `backup_retention_removed` | Removed {count} backups from the cloud folder (plural) |
| `backup_history_pinnedOnAnotherDevice` | Pinned on another device |

Dates in the list use the app's existing date-time formatter with `l10n:`; sizes use `formatBytes`.

- [ ] **Step 1: Failing tests:**
  - Dialog: renders the title with the count, the body with size, the pinned line only when `pinnedKept > 0`, one row per candidate with its source label; Cancel returns false; the destructive button returns true.
  - Section: the switch is absent with no cloud copy; present and off by default; turning it on with an empty plan turns it on with no dialog; with a non-empty plan shows the dialog, Cancel leaves it off and deletes nothing, confirm deletes exactly the listed files; a failed listing shows the snackbar and stays off; lowering the count while on shows the dialog and Cancel keeps the old count; raising it shows no dialog; the footprint line switches to the cloud folder wording when on.
- [ ] **Step 2: Run, expect FAIL**
- [ ] **Step 3: Implement**, run `flutter gen-l10n` (or the project's l10n step) after the ARB edits.
- [ ] **Step 4: Run, expect PASS**, plus `test/features/backup/presentation/` and `test/features/backup/presentation/pages/backup_settings_page_layout_test.dart`.
- [ ] **Step 5: Commit** `feat(backup): switch and confirmation for cross-device retention`

### Task 8: Verify and capture

- [ ] `dart format .` leaves nothing changed after the last commit.
- [ ] `flutter analyze` reports no issues.
- [ ] `flutter test test/features/backup test/architecture test/shared test/l10n` passes.
- [ ] After screenshots of the Advanced section (light, dark, switch off and on) and the confirmation dialog, with the throwaway golden test in the scratchpad; the test file is deleted from `test/` afterwards.
