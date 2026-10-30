# Share a Backup from the History Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task (inline, in this session). Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Every backup history row gets a Share (or "Save a copy") item that
opens a small sheet offering Save to folder and Share for that existing
backup, byte-for-byte, downloading a cloud-only backup to a temp copy first.

**Architecture:** A new `BackupService` part file resolves a history record
to a real file (in place, SAF stream, or cloud download), mirroring
`restoreFromBackup`'s resolution order, and reports whether the file is a
device-locked safety copy. `BackupOperationNotifier` gains share/save methods
that drive the operation state. A new sheet widget plus a menu item on
`BackupHistoryTile` expose it. Restore from file is widened to accept a
SQLCipher safety copy the live key opens, and the SAF plugin gains a
no-replace write.

**Tech Stack:** Flutter, Riverpod, share_plus, file_picker, submersion_saf
(Kotlin), sqlite3/SQLCipher.

**Spec:** `docs/design/specs/2026-10-28-share-backup-from-history-design.md`

## Global Constraints

- The shared or saved file is the backup's bytes unchanged: no decryption, no
  re-encryption, no note re-stamping.
- Nothing is added to or changed in the backup history by Share or Save.
- Share temp copy: the record's original `filename`, in `resolveSyncTempDir()`
  root, left for `RestoreTempSweep`. Save temp copy: `restore-<uuid>-<filename>`,
  deleted in a `finally`.
- Menu label: "Share" on iOS, macOS, Android; "Save a copy" on Windows, Linux
  (Save to folder only there).
- Disabled while `backupOperationProvider.status == inProgress`.
- Demo mode: `DemoModeGate.instance.ensureNotDemo(DemoSealedFeature.backup)`.
- Every new string in `app_en.arb` and translated in `ar de es fr he hu it nl
  pt zh`, inserted after a neighbouring key of the same group in each file.
- Dates via `UnitFormatter.formatDateTime(..., l10n: context.l10n)`.
- Paths via `p.join`, temp via `Directory.systemTemp` in tests.
- No em-dashes anywhere, including strings and comments.

## Review Focus

1. A SAF-backed record whose document was deleted outside the app: Share and
   Save fail with the existing not-found error and leave no temp file.
   (Task 3 test `saf record whose document is gone throws not found`.)
2. Saving into the folder that already holds the same backup (desktop): the
   original is untouched and the copy gets a numbered name. (Task 4 test
   `uniqueDestinationPath skips existing names`, Task 4 notifier test
   `save into the source folder never overwrites the source`.)
3. A cloud download that fails part way: error state, no file left in temp.
   (Task 3 test `failed cloud download leaves nothing in temp`.)
4. Tapping Share twice fast, or while a scheduled backup runs: the second
   call is a no-op. (Task 4 test `prepareBackupForSharing is a no-op while busy`.)
5. A plaintext `.db` picked in Restore from file still restores exactly as
   before after the validation change. (Task 2 test
   `restoreFromFilePath still accepts a plain backup`.)

---

### Task 1: SAF plugin no-replace write

**Files:**
- Modify: `packages/submersion_saf/lib/submersion_saf.dart:33-44`
- Modify: `packages/submersion_saf/android/src/main/kotlin/app/submersion/saf/SubmersionSafPlugin.kt:135-158`
- Test: `test/features/backup/data/services/submersion_saf_facade_test.dart`

**Interfaces:**
- Produces: `SubmersionSaf.writeBackup({required String treeUri, required String fileName, required String sourcePath, bool replaceExisting = true}) -> Future<String>`; sends channel arg `'replaceExisting'`.

- [ ] **Step 1: Write the failing tests**

`writeBackup sends replaceExisting true by default`: mock channel, call without
the flag, `expect((seen!.arguments as Map)['replaceExisting'], isTrue)`.
`writeBackup passes replaceExisting false`: call with `replaceExisting: false`,
expect `isFalse`.

- [ ] **Step 2: Run, expect FAIL** (`flutter test test/features/backup/data/services/submersion_saf_facade_test.dart`; the arg is null)

- [ ] **Step 3: Implement**

Dart: add the parameter and the map entry; doc comment says false leaves a
same-name document and lets the provider pick a new name. Kotlin:
`val replace = call.argument<Boolean>("replaceExisting") ?: true`; wrap the
existing `tree.findFile(fileName)?.delete()` in `if (replace)`; keep the
retry comment, add one saying why a diver-chosen save must not replace.

- [ ] **Step 4: Run, expect PASS**

- [ ] **Step 5: Commit** `feat(backup): let a SAF write keep an existing same-name file`

### Task 2: Restore from file accepts a protected safety copy on this device

**Files:**
- Modify: `lib/features/backup/presentation/providers/backup_providers.dart:502` (`restoreFromFilePath`)
- Modify: `lib/features/backup/data/services/backup_service.dart` (`validateBackupFile` keyed-open failure message; `restoreFromFile` deep check of a decrypted copy)
- Test: `test/features/backup/data/services/backup_service_premigration_restore_test.dart` (reuse `writeEncryptedPreMigrationCopy`, `_liveKeyHex`)
- Test: `test/features/backup/presentation/providers/backup_restore_from_file_protected_test.dart` (create)

**Interfaces:**
- Produces: `BackupService.lockedCopyWrongKeyMessage` (static const String) used by validation and its tests.

- [ ] **Step 1: Write the failing tests**

Service:
- `validateBackupFile names a key mismatch when the live key does not open the file`:
  encrypted copy, adapter key = a different 64-hex key,
  `allowLiveDatabaseEncryption: true` → `isValid false`,
  `error == BackupService.lockedCopyWrongKeyMessage`.
- `restoreFromFile deep-checks a decrypted copy with the live key`: make an
  `.sbe` of a SQLCipher copy (`BackupCrypto.encryptFile` with a test key slot,
  as `backup_service_encryption_test.dart` does), adapter with a WRONG live
  key → `restoreFromFile` throws `BackupException`, adapter `restoreCalls == 0`,
  history length unchanged (no pre-restore backup).
- Same with the RIGHT live key → restores (`restoreCalls == 1`).

Provider (`ProviderContainer`, service subclass recording calls, pattern of
`backup_export_saf_test.dart`):
- `restoreFromFilePath accepts a SQLCipher copy the live key opens`: real
  encrypted file + right key → `restoreFromFile` called.
- `restoreFromFilePath refuses a SQLCipher copy with no live key`: state
  `error`, message is the existing "This safety copy cannot be opened..."
  text, `restoreFromFile` not called.
- `restoreFromFilePath still accepts a plain backup`: plaintext Submersion db
  → `restoreFromFile` called.

- [ ] **Step 2: Run, expect FAIL**

- [ ] **Step 3: Implement**

- Provider: `validateBackupFile(filePath, allowLiveDatabaseEncryption: true)`,
  with a comment that this is the history row's rule extended to the same
  file picked from outside (issue #3650).
- `validateBackupFile`: when `deepCheckKeyHex != null` and the keyed open or
  `SELECT 1` throws, return `invalid(lockedCopyWrongKeyMessage)`:
  `'This copy came from a protected database that this install has no key '
  'for (another device, or protection was turned off and on again since), '
  'or the file is corrupt.'`
- `restoreFromFile`: right after `_materializePlaintextBackup`, when
  `materialized.isTemp`, run `validateBackupFile(materialized.path,
  allowLiveDatabaseEncryption: true)` and throw `BackupException(error)` when
  invalid, before the schema guard and `performBackup`.
- Update the `validateBackupFile` doc paragraph that says portable backups
  keep the strict plaintext rule: the opt-in now also covers Restore from file.

- [ ] **Step 4: Run, expect PASS**, plus the whole `test/features/backup/` folder (the stricter decrypted-copy check must not break existing `.sbe` restore tests).

- [ ] **Step 5: Commit** `feat(backup): restore a protected safety copy from a file on this device`

### Task 3: Resolve a history record to a file, and spot device-locked copies

**Files:**
- Create: `lib/features/backup/data/services/backup_service_copy_out.dart` (`part of 'backup_service.dart'`)
- Modify: `lib/features/backup/data/services/backup_service.dart` (add `part`, two public delegating methods)
- Modify: `lib/core/services/storage/restore_temp_sweep.dart` (pre-downgrade name)
- Test: `test/features/backup/data/services/backup_service_copy_out_test.dart` (create)
- Test: `test/core/services/storage/restore_temp_sweep_test.dart`

**Interfaces:**
- Consumes: `_cloudCopyHere`, `_downloadFromCloud`, `_safPort`, `isSafRef`,
  `BackupCopyInOtherAccountException`, `_restoreCopyName`.
- Produces:
  - `enum BackupCopyPurpose { share, save }`
  - `class PreparedBackupFile { final String path; final bool isTemp; Future<void> discard(); }` (discard deletes only when `isTemp`, best effort)
  - `BackupService.prepareBackupCopy(BackupRecord record, {required BackupCopyPurpose purpose}) -> Future<PreparedBackupFile>`
  - `BackupService.isDeviceLockedSafetyCopy(BackupRecord record) -> Future<bool>`

- [ ] **Step 1: Write the failing tests** (fake adapter, fake SAF port and
  `FakeCloudStorageProvider` as in `backup_service_saf_io_test.dart`;
  temp dir mocked via the path_provider channel)

- `local record is used in place`: `path == localPath`, `isTemp false`, bytes equal.
- `saf record is streamed to temp`: share purpose → `p.basename(path) == record.filename`, `isTemp true`; save purpose → basename starts with `restore-` and ends with the filename.
- `saf record whose document is gone throws not found`: port `exists` false → `BackupException`; temp folder has no file of that name.
- `cloud-only record is downloaded`: share → basename is `record.filename`, bytes equal the cloud bytes.
- `failed cloud download leaves nothing in temp`: provider throws → rethrows, no file left.
- `cloud copy in another account throws BackupCopyInOtherAccountException`.
- `missing everywhere throws BackupException`.
- `encrypted sbe is returned byte for byte`: `.sbe` local record → bytes equal, no secret asked.
- `history is unchanged after preparing a copy`: `preferences.getHistory()` equal before and after, for local and cloud.
- `isDeviceLockedSafetyCopy`: true for a preMigration SQLCipher `.db`; true for a preDowngrade SQLCipher `.db`; false for a plain preMigration `.db`; false for a manual SQLCipher-looking file; for a preMigration `.sbe`: true when adapter `databaseKeyHex != null`, false when null; false for a SAF or cloud-only safety copy.
- Sweep: `matches a pre-downgrade copy name` (`20261028-101500123-v300-newer.db`, aged → deleted).

- [ ] **Step 2: Run, expect FAIL**

- [ ] **Step 3: Implement**

Part file holds a private extension with `_prepareBackupCopy` and
`_isDeviceLockedSafetyCopy`; `backup_service.dart` gets only the `part` line
and the two one-line public delegates (with doc comments), so subclasses in
tests can override them. `prepareBackupCopy` calls the demo gate first, then
follows `restoreFromBackup`'s order exactly; the temp name is
`record.filename` for share and `_restoreCopyName(record.filename)` for save;
a failed SAF stream deletes its partial file. `_isDeviceLockedSafetyCopy`:
type must be `preMigration` or `preDowngrade`; needs a non-SAF `localPath`
that exists; `.sbe` (`BackupCrypto.isEncryptedBackup`) → `_dbAdapter.databaseKeyHex != null`; else `isEncryptedDatabaseFile(path)`.
Sweep regex: `-v\d+-v\d+\.db` becomes `-v\d+-(?:v\d+|newer)\.db`; update its doc list.

- [ ] **Step 4: Run, expect PASS**

- [ ] **Step 5: Commit** `feat(backup): resolve a history backup to a file for sharing or saving`

### Task 4: Notifier share and save methods

**Files:**
- Create: `lib/features/backup/data/services/backup_copy_destination.dart`
- Modify: `lib/features/backup/presentation/providers/backup_providers.dart` (`BackupOperationNotifier`)
- Test: `test/features/backup/data/services/backup_copy_destination_test.dart` (create)
- Test: `test/features/backup/presentation/providers/backup_copy_out_notifier_test.dart` (create)

**Interfaces:**
- Consumes: `prepareBackupCopy`, `PreparedBackupFile`, `BackupCopyPurpose`, `SubmersionSaf.writeBackup(replaceExisting:)`.
- Produces:
  - `Future<String> uniqueDestinationPath(String directory, String fileName)`: `name.ext`, then `name (1).ext`, `name (2).ext`... first that does not exist.
  - `BackupOperationNotifier.prepareBackupForSharing(BackupRecord record) -> Future<File?>`
  - `BackupOperationNotifier.saveBackupCopyToDirectory(BackupRecord record, String directory) -> Future<void>`
  - `BackupOperationNotifier.saveBackupCopyToSafTree(BackupRecord record, String treeUri) -> Future<void>`

- [ ] **Step 1: Write the failing tests**

- `uniqueDestinationPath returns the plain name when free`, `uniqueDestinationPath skips existing names` (`a.db` and `a (1).db` exist → `a (2).db`).
- Notifier, with a service subclass overriding `prepareBackupCopy`:
  - `prepareBackupForSharing returns the file and ends in success` (message `backup_operation_shareReady`); the prepared file is NOT discarded.
  - `prepareBackupForSharing is a no-op while busy` (state preset to inProgress → returns null, service not called).
  - `prepareBackupForSharing maps another account to the copyInOtherAccount message`.
  - `prepareBackupForSharing maps other errors to exportFailed`.
  - `saveBackupCopyToDirectory copies and discards the temp copy`: destination file bytes equal, temp gone, state success `backup_operation_exported(size)`.
  - `save into the source folder never overwrites the source`: local in-place record, directory = its own folder → source unchanged, new file `name (1).ext`.
  - `saveBackupCopyToDirectory discards the temp copy on failure` (destination dir missing → error state, temp gone).
  - `saveBackupCopyToSafTree writes with replaceExisting false` (mock the `app.submersion/saf` channel, assert args, temp discarded).
  - `nothing is added to history` after each save.

- [ ] **Step 2: Run, expect FAIL**

- [ ] **Step 3: Implement**

Each method returns early when busy, sets `inProgress` with
`backup_operation_preparingShare` (share) or `backup_operation_exporting`
(save), catches `BackupCopyInOtherAccountException` →
`backup_restore_copyInOtherAccount`, else `backup_operation_exportFailed`.
Save methods discard the prepared file in `finally`; share does not. No
history invalidation.

- [ ] **Step 4: Run, expect PASS**

- [ ] **Step 5: Commit** `feat(backup): share or save an existing backup from the operation notifier`

### Task 5: Strings and the copy sheet

**Files:**
- Modify: `lib/l10n/arb/app_*.arb` (11 files), regenerate with `flutter gen-l10n`
- Create: `lib/features/backup/presentation/widgets/backup_copy_sheet.dart`
- Test: `test/features/backup/presentation/widgets/backup_copy_sheet_test.dart` (create)

**Interfaces:**
- Produces:
  - Keys (after `backup_history_action_restore`, group neighbours): `backup_history_action_share` "Share", `backup_history_action_saveCopy` "Save a copy"; (after `backup_export_share_subtitle`): `backup_copySheet_title` "Backup from {dateTime}" (`dateTime` String placeholder), `backup_copySheet_deviceLocked` "This safety copy was taken from your protected database. It can only be restored on this device."
  - `class BackupCopySheet extends ConsumerWidget { final BackupRecord record; final bool deviceLocked; final VoidCallback onSaveToFolder; final VoidCallback? onShare; }`
  - `static Future<void> BackupCopySheet.show(BuildContext context, {required BackupRecord record, required bool deviceLocked, required VoidCallback onSaveToFolder, VoidCallback? onShare})`: pops the sheet before calling either callback, like `ExportBottomSheet.show`.

- [ ] **Step 1: Write the failing widget tests**

- `shows the title with the formatted date and both actions`: finds `settings_backups_saveToFolder` and `backup_export_share` texts and their subtitles; no `TextField`.
- `hides Share when onShare is null`.
- `shows the device-locked line only when deviceLocked`.
- `tapping Save calls onSaveToFolder`, `tapping Share calls onShare`.

- [ ] **Step 2: Run, expect FAIL**

- [ ] **Step 3: Implement** the ARB entries (each locale translated, placeholders metadata only in `app_en.arb` per existing practice), regenerate, and the widget with `ExportBottomSheet`'s layout minus the note field (drag handle, title, optional line in `bodyMedium` `onSurfaceVariant`, two `ListTile`s with `Icons.save_alt` and `Icons.share`).

- [ ] **Step 4: Run, expect PASS**, plus the l10n staleness check the pre-push hook runs.

- [ ] **Step 5: Commit** `feat(backup): add the sheet for saving or sharing an existing backup`

### Task 6: Menu item, wiring and actions

**Files:**
- Modify: `lib/features/backup/presentation/widgets/backup_history_tile.dart`
- Modify: `lib/features/backup/presentation/widgets/backup_history_section.dart`
- Create: `lib/features/backup/presentation/widgets/backup_copy_actions.dart`
- Modify: `lib/features/backup/presentation/widgets/export_bottom_sheet.dart:30` (use `platformHasShareSheet`)
- Test: `test/features/backup/presentation/widgets/backup_history_tile_test.dart`

**Interfaces:**
- Consumes: Task 3 `isDeviceLockedSafetyCopy`, Task 4 notifier methods, Task 5 `BackupCopySheet`.
- Produces:
  - `BackupHistoryTile` gains `final VoidCallback? onShare;` (null disables the item) and `required bool shareSheetAvailable`.
  - `bool get platformHasShareSheet` (iOS, macOS, Android) in `backup_copy_actions.dart`; `ExportBottomSheet.show` switches to it.
  - `Future<void> showBackupCopySheet(BuildContext context, WidgetRef ref, BackupRecord record)`.

- [ ] **Step 1: Write the failing tile tests**

- `menu shows Share between Restore and Delete when a share sheet exists` (order of `PopupMenuItem` values `restore, share, delete`).
- `menu shows Save a copy when no share sheet exists`.
- `Share item is disabled when onShare is null`.
- `choosing Share calls onShare`.

- [ ] **Step 2: Run, expect FAIL**

- [ ] **Step 3: Implement**

Tile: new `PopupMenuItem(value: 'share', enabled: onShare != null)` with
`Icons.share` / `Icons.save_alt` and the matching label. Section: watch
`backupOperationProvider`; pass `onShare: busy ? null : () =>
showBackupCopySheet(context, ref, record)` and
`shareSheetAvailable: platformHasShareSheet`. `showBackupCopySheet`:
capture `shareAnchorFrom(context)` first, await
`isDeviceLockedSafetyCopy`, show the sheet; Save on Android
`SubmersionSaf.pickFolder()` → `saveBackupCopyToSafTree` (coverage-ignored,
as in `saveBackupFile`), elsewhere `FilePicker.getDirectoryPath` →
`saveBackupCopyToDirectory`; Share → `prepareBackupForSharing` then
`SharePlus.instance.share(ShareParams(files: [XFile(file.path)],
sharePositionOrigin: anchor))`, passing `onShare: null` when
`!platformHasShareSheet`. Update the section's doc comment.

- [ ] **Step 4: Run, expect PASS**, then `test/features/backup/` and `test/architecture/` and `test/shared/`.

- [ ] **Step 5: Commit** `feat(backup): share a backup from the history`

### Task 7: Final checks and screenshots

- [ ] `dart format .`, `flutter analyze` (no issues), `flutter test test/features/backup test/core/services/storage test/architecture test/shared`, all green.
- [ ] After screenshots of the history menu and the sheet (light and dark, phone and desktop widths; the device-locked line if reproducible), matching the before shots taken before Task 1.
