# Backup Retention Keep All Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task (native, in session). Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let a diver keep every backup, type a custom backup count, and pin a backup as it is made from Back up now (#4535).

**Architecture:** "Keep all" is a sentinel count in the existing `retentionCount`
setting, so pruning code is untouched and older builds keep everything. A new
retention picker dialog replaces the plain choice list for the Keep tile. The
Back up now dialog returns a `pin` flag, and the operation notifier pins the new
record through `BackupService.pinBackup`.

**Tech Stack:** Flutter, Riverpod, SharedPreferences, ARB l10n.

**Spec:** `docs/design/specs/2026-11-14-backup-retention-keep-all-design.md`

## Global Constraints

- Keep all sentinel: `BackupSettings.keepAllRetentionCount = 1 << 30`, stored in `backup_retention_count`.
- Custom range: 1 to `BackupSettings.maxCustomRetentionCount = 9999`; any stored count above 9999 reads as Keep all.
- List choices stay 5, 10, 15, 20, 30.
- Every new string goes into all 11 ARB files (translated), then `flutter gen-l10n`.
- No em-dashes in code, comments or strings.

## Review Focus

- A stored sentinel pruned by `pruneOldBackups` removes nothing (test in Task 1).
- Custom input of empty, `0`, `10000`, or letters is rejected with Save disabled; `0365` saves 365 (Task 2).
- A custom count equal to a list value (e.g. 20) checks the list row, not the Custom row (Task 2).
- Switching from Keep all to 30 with "Count backups from all devices" on is treated as lowering (Task 3).
- A pin failure after a successful backup still reports the backup as created (Task 5).

---

### Task 1: Keep-all sentinel on BackupSettings

**Files:**
- Modify: `lib/features/backup/domain/entities/backup_settings.dart`
- Test: `test/features/backup/domain/entities/backup_settings_test.dart`
- Test: the existing prune test file under `test/features/backup/data/services/` that covers `pruneOldBackups`

**Interfaces:**
- Produces: `static const int BackupSettings.keepAllRetentionCount`, `static const int BackupSettings.maxCustomRetentionCount`, `bool get BackupSettings.keepsAll`.

- [ ] **Step 1: Failing tests**: `keepsAll` is false for 10 and 9999, true for 10000 and `keepAllRetentionCount`; `pruneOldBackups(BackupSettings.keepAllRetentionCount)` with 12 unpinned manual records deletes none.
- [ ] **Step 2: Run** `flutter test test/features/backup/domain/entities/backup_settings_test.dart`, expect FAIL (undefined getter).
- [ ] **Step 3: Implement** the two constants and `keepsAll => retentionCount > maxCustomRetentionCount`, with a doc comment explaining why the sentinel is large rather than 0 (older builds).
- [ ] **Step 4: Run** both tests, expect PASS.

### Task 2: Retention picker dialog

**Files:**
- Create: `lib/features/backup/presentation/widgets/backup_retention_dialog.dart`
- Test: `test/features/backup/presentation/widgets/backup_retention_dialog_test.dart`
- Modify: all `lib/l10n/arb/app_*.arb`

**Interfaces:**
- Produces: `Future<int?> showBackupRetentionDialog(BuildContext context, {required int selected})`, returning the chosen count (`keepAllRetentionCount` for Keep all) or null on dismiss. `const backupRetentionChoices = [5, 10, 15, 20, 30]`.

Strings (en): `backup_retention_keepAll` "Keep all"; `backup_retention_custom` "Custom number…"; `backup_retention_customCurrent` "Custom: {count}"; `backup_retention_custom_title` "Keep how many backups?"; `backup_retention_custom_label` "Number of backups"; `backup_retention_custom_error` "Enter a number from 1 to {max}". Title reuses `backup_schedule_retention`, buttons reuse `common_action_cancel` / `common_action_save`.

- [ ] **Step 1: Failing widget tests**:
  - tapping `10` returns 10; tapping Keep all returns `keepAllRetentionCount`;
  - with `selected: keepAllRetentionCount`, Keep all carries the check;
  - with `selected: 365`, the row reads "Custom: 365" and carries the check;
  - with `selected: 20`, the 20 row is checked and the custom row reads "Custom number…";
  - Custom number, type `365`, Save returns 365; `0365` returns 365;
  - empty, `0`, `10000` show the error text and Save is disabled;
  - Cancel in the custom dialog returns null from the picker.
- [ ] **Step 2: Run**, expect FAIL.
- [ ] **Step 3: Implement** a `SimpleDialog` (same row style as `showBackupChoiceDialog`) and a private stateful custom-number `AlertDialog` with a `TextField` using the shared `numberInputFormatters()` and `readNumber(integer: true, allowNegative: false)` (the number-parsing architecture guard requires both), `keyboardType: TextInputType.number`, prefilled with the current count when it is a custom count (not keep all), `errorText` while invalid and non-empty-after-edit, Save enabled only for 1..9999. The custom row pops the picker first, then opens the custom dialog on the same navigator context.
- [ ] **Step 4: Add strings** to every ARB, run `flutter gen-l10n`, then the tests, expect PASS.

### Task 3: Advanced section uses the picker and Keep-all wording

**Files:**
- Modify: `lib/features/backup/presentation/widgets/backup_advanced_section.dart`
- Test: `test/features/backup/presentation/widgets/backup_advanced_section_test.dart`
- Modify: all ARB files

**Interfaces:**
- Consumes: `showBackupRetentionDialog`, `BackupSettings.keepsAll`, `changeRetentionCount` (unchanged).

Strings (en): `settings_backups_keepAll` "Keep all backups"; `backup_schedule_retention_keepAll_subtitle` "Backups are never removed automatically"; `backup_retention_allDevices_onKeepAll` "Keep all is on, so this device removes no backups from the cloud folder. Pinned backups are kept."

- [ ] **Step 1: Failing tests**: with retentionCount = sentinel the tile reads "Keep all backups" and the never-removed subtitle; tapping the tile and choosing Keep all saves the sentinel in prefs; the cross-device tile, on, shows the Keep-all wording; a `changeRetentionCount` from sentinel to 30 with cross-device active goes through the confirm path (lowering).
- [ ] **Step 2: Run**, expect FAIL.
- [ ] **Step 3: Implement**: drop `retentionChoices` from the section, call `showBackupRetentionDialog`, and branch the title, `_RetentionSubtitle` explanation and `_CrossDeviceRetentionTile` subtitle on `keepsAll`.
- [ ] **Step 4: Run**, expect PASS.

### Task 4: Set-up step wording

**Files:**
- Modify: `lib/features/settings/presentation/widgets/set_up_device/set_up_backups_step.dart`
- Test: `test/features/settings/presentation/widgets/set_up_device/set_up_backups_step_test.dart`
- Modify: all ARB files

Strings (en): `settings_setUpDevice_backups_autoDetailKeepAll` "{frequency}. Every backup is kept here."; `settings_setUpDevice_backups_autoDetailDesktopKeepAll` "{frequency}, while Submersion is open. Every backup is kept here."

- [ ] **Step 1: Failing test**: with the sentinel stored, the auto switch subtitle reads "Weekly. Every backup is kept here." (phone width) and never shows the sentinel number.
- [ ] **Step 2: Run**, expect FAIL. **Step 3: Implement** the branch. **Step 4: Run**, expect PASS.

### Task 5: Keep this backup in Back up now

**Files:**
- Modify: `lib/features/backup/presentation/widgets/backup_note_dialog.dart`
- Modify: `lib/features/backup/presentation/widgets/backup_actions.dart`
- Modify: `lib/features/backup/presentation/providers/backup_providers.dart`
- Test: `test/features/backup/presentation/widgets/backup_note_dialog_test.dart`
- Test: `test/features/backup/presentation/providers/backup_providers_backup_test.dart`
- Modify: all ARB files

**Interfaces:**
- Produces: `BackupNoteResult(String? note, {bool pin = false})` with `final bool pin`; `BackupOperationNotifier.performBackup({String? note, bool pin = false})`.
- Consumes: `BackupService.pinBackup(String id)`.

Strings (en): `backup_note_keep_title` "Keep this backup"; `backup_note_keep_subtitle` "Pinned backups are never removed automatically"; `backup_operation_createdNotPinned` "Backup created: {size}. It could not be pinned, so pin it from the history."

- [ ] **Step 1: Failing tests**:
  - dialog: the switch is off by default; Back Up returns `pin == false`; toggled on, returns `pin == true` with the note;
  - notifier: `performBackup(pin: true)` calls `pinBackup('r1')` once; `pin: false` never calls it; a `pinBackup` that throws leaves status success with the createdNotPinned message; a failed backup never calls `pinBackup`.
- [ ] **Step 2: Run**, expect FAIL.
- [ ] **Step 3: Implement**: a `SwitchListTile` under the note field in a `Column(mainAxisSize: min)`; the notifier pins after `_service.performBackup` returns, inside its own try so a pin error only changes the message; `BackupNowTile` passes `pin: result.pin`.
- [ ] **Step 4: Run**, expect PASS.

### Task 6: Checks and commit

- [ ] `dart format .`, `flutter analyze` (no issues), the tests above, `test/architecture/` and `test/shared/` (a new lib file was added).
- [ ] Commit `feat(backup): keep all backups, a custom count, and pin from Back up now`.
