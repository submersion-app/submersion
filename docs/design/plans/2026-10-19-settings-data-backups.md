# Settings > Data, PR 3: Backups Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give the backup copy an explicit destination: a "Copy to {account}" Using row with Change, where the sheet also offers "No copy off this device". A backup folder and a cloud copy can both be on. Nothing turns the copy off silently. The Backups page is reordered around a status line, with an Advanced section at the bottom.

**Architecture:**
- The destination is a device preference in `BackupPreferences`: the roster row id and kind of the copy account. Null means "same account as sync", which is what every upgraded device starts with.
- One resolver turns the preference into a `CloudStorageProvider`, through the same `SyncCapable.syncProvider(row)` call sync uses, so files land in the same `Submersion Backups` folder as today. `backupServiceProvider` and the headless scheduled backup both use it.
- `BackupService` stays the only writer. It learns the account each cloud copy went to, and it never touches a copy that lives in another account.
- The page is split into small widgets so `backup_settings_page.dart` ends well under 800 lines.

**Tech Stack:** Flutter, Riverpod 3, SharedPreferences (`BackupPreferences`), the phase 2 account model (`AccountGroup`, `showAccountSheet`, `AccountGroupService.ensureRole`), gen-l10n with 11 ARB files, `flutter_test`.

**Spec:** `docs/design/specs/2026-10-17-settings-data-setup-and-accounts-design.md`. The sections that bear on this PR are:
- section 2, the "silent side effects" anti-goal;
- section 4, vocabulary;
- section 7.1, backup copies stay in `Submersion Backups` inside the sync folder;
- section 7.3, the device preference with no schema change;
- section 8.1, Stop syncing pins the copy;
- section 8.2, Backups;
- section 11, phase 3;
- section 12, decisions;
- the appendix rows for Backup.

Phases 1 and 2 shipped as #3485, #3500 and #3527.

## Global Constraints

- **No schema change.** The destination lives in SharedPreferences, next to the other backup settings, because a restore must not overwrite it (see the `BackupPreferences` class comment).
- **Upgrades change nothing.** An upgraded device has no destination stored, so it reads as "same account as sync" and copies exactly where it copies today. Nothing is backfilled.
- **Nothing turns the copy off silently.** The copy goes off only when the diver chooses "No copy off this device", or after a confirmation that names the effect (sign out or remove of the account the copy uses). Choosing a backup folder never touches the copy, and turning the copy on never touches the folder.
- **Cloud copies stay framed as today.** The copy keeps today's framing rules: a backup-encrypted `.sbe` is uploaded as is; otherwise, while sync encryption is on, the copy is framed with the library key. A non-sync destination does not change this.
- **Vocabulary is spec section 4, in sentence case.** The device word is "device", as phases 1 and 2 shipped it ("on this device only").
- **Strings go in all eleven ARB files.** A string whose meaning changes gets a new key, and the old key is deleted once nothing reads it. Run `flutter gen-l10n` and commit the generated files.
- **Files stay under 800 lines.** `backup_settings_page.dart` (734 today) must end at or under 400. `backup_service.dart` is already over the limit (1,926 lines): this PR adds no more than 60 lines to it, and new logic goes into new files.
- **No em dashes, and no tool names or attribution.** Every commit and the PR say `Refs #3482`.
- **Tests restore any global state they replace.** After adding files under `lib/`, run `test/architecture` and `test/shared`.
- **Screenshots** of the Backups page come before and after, light and dark, and phone and desktop widths. The maintainer attaches them.

## Rulings and deferrals

These are calls the plan makes where the spec leaves a choice. Each one is cheap to reverse.

1. **Choosing the account sync uses stores "same as sync" (null), not a pin.** The row then reads "Same account as sync", which is what will happen if sync later moves. Pinning that account would show the same row with no subtitle; the difference only appears after a sync switch.
2. **The preference stores the roster row id plus its kind** (`backup_copy_account_id`, `backup_copy_account_kind`). The headless scheduled backup has no database registry, so it builds the provider from the kind and id alone. Every adapter's `syncProvider` needs nothing else.
3. **For an S3 or WebDAV account, the copy goes through the account's sync-role row.** If that row does not exist yet, it is created with `ensureRole(group, AccountRole.sync)`, which writes the default `submersion-sync/` or `Submersion` folder (spec section 12).
4. **Each backup record now notes which account its cloud copy went to** (`BackupRecord.cloudAccountId`). Pruning, Delete, Restore and pinning skip a cloud copy that is in another account. Old records have no account noted and keep today's behaviour.
5. **A copy account that was removed** (from another device, or its row deleted) keeps the preference. The Using row reads "The copy's account was removed" with Choose an account. The backup stays on this device, and the existing "cloud copy missing" health reason flags it. Nothing silently switches the copy off.
6. **The Advanced section is a plain header** (`settings_data_header_advanced`, reused), the same as on the Data and Sync pages. It is not a collapsible fold.
7. **The setup wizard's "Keep a copy in the cloud" switch** keeps its meaning (the copy on, same as sync) until phase 7 replaces that step.

## Review Focus

These are inputs the spec implies that no task's tests would otherwise exercise. Each test is added to the task that owns the code.

1. **Android, with a SAF backup folder and the cloud copy on.** The backup lands in the folder and the cloud copy uploads from a filesystem file. The upload must never be handed a `content://` ref (Task 5).
2. **Sync on S3 account A, copy pinned to S3 account B, a scheduled backup in the background isolate.** The upload goes to B's sync folder, never A's (Task 4).
3. **Copy pinned to Dropbox, then the diver uses Stop syncing on the sync account (iCloud).** The copy stays on Dropbox, and nothing is reset (Task 6).
4. **A history row whose cloud copy is in a previous copy account, with no local file.**
   - Delete removes the record and never calls `deleteFile` on the current account.
   - Restore says where the copy is instead of downloading from the wrong account (Task 2).
5. **Turning the copy off and on again with a folder chosen.** The folder survives both changes (Task 1).

---

### Task 1: The destination preference and independent folder and copy

**Files:**
- Modify: `lib/features/backup/domain/entities/backup_settings.dart`, `lib/features/backup/data/repositories/backup_preferences.dart`, `lib/features/backup/presentation/providers/backup_providers.dart` (only the `BackupSettingsNotifier` part)
- Test: `test/features/backup/data/repositories/backup_preferences_test.dart` and `test/features/backup/presentation/providers/backup_settings_notifier_test.dart` (create the second if it does not exist; otherwise extend the file that already tests the notifier)

**Interfaces:**
- Produces:
  - `BackupSettings.copyAccountId` (`String?`) and `BackupSettings.copyAccountKind` (`AccountKind?`). Both are in `props`. Null means "same as sync".
  - `BackupPreferences.setCopyDestination({required String? accountId, required AccountKind? kind})`. Passing null for both removes both keys.
  - Notifier:
    - `Future<void> setCopyTo(ConnectedAccount row)` turns the copy on and stores the row.
    - `Future<void> setCopyFollowsSync()` turns the copy on and clears the row.
    - `Future<void> setNoCopy()` turns the copy off and clears the row.
    - `Future<void> pinCopyTo(ConnectedAccount row)` stores the row without changing whether the copy is on. Used by Stop syncing.
    - `Future<void> useDefaultBackupLocation()` is `setBackupLocation(null)`.
  - `setCloudBackupEnabled` no longer clears the location. `setBackupLocation`, `setBackupLocationWithBookmark` and `setSafBackupLocation` no longer turn the copy off. `disableCloudBackup` is deleted; Task 6 replaces its two callers.

- [ ] **Step 1: Write the failing tests**
  - `'choosing a folder keeps the cloud copy on'`: copy on, then `setBackupLocationWithBookmark('/x', null)`. Expect `cloudBackupEnabled` true and `backupLocation` `'/x'`.
  - `'turning the copy on keeps the chosen folder'`: same idea, in the other order, for `setCloudBackupEnabled(true)` and `setSafBackupLocation`.
  - `'off and on again keeps the folder'`: covers Review Focus 5.
  - `'setCopyTo stores the row id and kind and turns the copy on'`, `'setCopyFollowsSync clears the row'` and `'setNoCopy turns the copy off and clears the row'`: each reads the result back through a fresh `BackupPreferences(prefs).getSettings()`.
  - `'useDefaultBackupLocation clears the folder, its bookmark and its label'`.
  - `'an unknown stored kind reads as no destination'`: `backup_copy_account_kind` is `'ftp'`. Expect both fields null.
- [ ] **Step 2: Run the tests.** Expected: FAIL, because the fields and methods do not exist yet.
- [ ] **Step 3: Implement.** Kind is stored as `AccountKind.name` and parsed with `asNameMap()`. Write the kind first and the id last, so a crash between the two writes leaves no id. Rewrite the class comments that describe the mutual exclusion.
- [ ] **Step 4: Run the tests.** Expected: PASS. Then run `flutter analyze`. Expected: only the two `disableCloudBackup` callers fail. Keep a temporary forwarding `disableCloudBackup` that calls `setNoCopy` until Task 6, and delete it there.
- [ ] **Step 5: Commit** `feat(backup): a backup copy destination, independent of the backup folder`.

### Task 2: Records know their copy's account

**Files:**
- Modify: `lib/features/backup/domain/entities/backup_record.dart` (field, JSON, copyWith), `lib/features/backup/data/services/backup_service.dart`
- Create: `lib/features/backup/data/services/backup_copy_guard.dart`
- Test: `test/features/backup/data/services/backup_copy_guard_test.dart`, plus additions to the existing `backup_service` test file that covers delete and prune

**Interfaces:**
- Produces:
  - `BackupRecord.cloudAccountId` (`String?`, JSON key `cloudAccountId`, absent in old JSON).
  - `bool cloudCopyReachable(BackupRecord r, {required String? copyAccountId})` returns true when `r.cloudFileId != null && (r.cloudAccountId == null || r.cloudAccountId == copyAccountId)`.
  - `BackupService` takes `Future<String?> Function()? copyAccountId`, which replaces `_syncAccountIdOrNull` as the account recorded on a new copy and on `setLastBackupDestination`.
  - Restore of a record whose only copy is unreachable throws `BackupFailedException` with the code `copyInOtherAccount`. The page shows the new string `backup_restore_copyInOtherAccount`: "This backup's copy is in another account. Choose that account under Copy to, then try again."

- [ ] **Step 1: Write the failing tests**
  - Guard table: a legacy record (no account) is reachable; the same account is reachable; another account is not; a record with no cloud file is not.
  - `'delete of a record whose copy is in another account never deletes a cloud file'`, using a recording fake provider (Review Focus 4).
  - `'pruning skips another account's cloud copy'`.
  - `'restore of an unreachable cloud-only record throws copyInOtherAccount'`.
  - `'a new cloud copy records the copy account, not the sync account'`, with the resolver returning `'acct-b'`.
  - The record JSON round-trips with and without `cloudAccountId`.
- [ ] **Step 2: Run the tests.** Expected: FAIL.
- [ ] **Step 3: Implement.** Route every `record.cloudFileId != null && _cloudProvider != null` check (delete, prune, restore, `pinRecord`) through `cloudCopyReachable`. `copyAccountId` defaults to today's sync-account read, so callers that pass nothing keep today's behaviour.
- [ ] **Step 4: Run the tests.** Expected: PASS. Then run the whole `test/features/backup` folder. Expected: PASS.
- [ ] **Step 5: Commit** `feat(backup): each backup record notes the account its copy went to`.

### Task 3: Resolve the copy account in the foreground

**Files:**
- Create: `lib/features/backup/presentation/providers/backup_copy_providers.dart`
- Modify: `backup_providers.dart` (`backupServiceProvider` reads the new provider), `lib/core/services/accounts/account_usage_service.dart` (a `backupCopy` usage)
- Test: `test/features/backup/presentation/providers/backup_copy_providers_test.dart`, and `account_usage_service_test.dart`

**Interfaces:**
- Produces:
  - `sealed class BackupCopyTarget`, with these cases:
    - `CopyFollowsSync(AccountGroup? group)`: `group` is null when sync has no account.
    - `CopyToAccount(AccountGroup group, ConnectedAccount row)`.
    - `CopyAccountGone(String accountId)`.
    - `NoCopy()`.
  - `backupCopyTargetProvider`: `FutureProvider<BackupCopyTarget>`, read from `backupSettingsProvider` and `accountGroupsProvider` (`retry: (_, _) => null`).
  - `backupCopyProviderProvider`: `Provider<CloudStorageProvider?>`, resolved as follows:
    - Following sync, it is `cloudStorageProviderProvider`.
    - Pinned to a row, it is `registry.capabilityFor<SyncCapable>(row.kind)?.syncProvider(row)`, wrapped in `EncryptingCloudStorageProvider` exactly as `cloudStorageProviderProvider` wraps sync. Extract that wrap into a shared helper `wrapForLibrary(raw, session)` in `sync_providers.dart`, so the two cannot drift.
    - With the row missing or the copy off, it falls back to `cloudStorageProviderProvider`. History still lists the sync folder's backups, as it does today with the switch off.
  - `AccountUsageKind.backupCopy`: listed for the pinned row only. Following sync is already covered by `databaseSync`. The detail page and the sign-out and remove confirmations then name it. New string `settings_accounts_usage_backups`, "Backup copies".

- [ ] **Step 1: Write the failing tests.** One test per `BackupCopyTarget` case, from prefs plus a fake group list. Then:
  - `'a pinned S3 row builds a provider from that row, not the sync account'`, asserting the provider reads the `AccountCredentialsStore.keyFor(rowB)` key.
  - `'with sync encryption unlocked the pinned provider is wrapped'`.
  - The usage list includes `backupCopy` for the pinned row only.
- [ ] **Step 2: Run the tests.** Expected: FAIL.
- [ ] **Step 3: Implement.** `backupServiceProvider` passes `cloudProvider: ref.watch(backupCopyProviderProvider)` and a `copyAccountId` that returns the pinned id, or otherwise today's sync-account read.
- [ ] **Step 4: Run the tests.** Expected: PASS. Run `test/features/backup` and `test/features/settings`. Expected: PASS.
- [ ] **Step 5: Commit** `feat(backup): resolve the backup copy's account the way sync does`.

### Task 4: The scheduled backup copies to the same account

**Files:**
- Modify: `lib/core/services/cloud_storage/headless_cloud_provider.dart`, `lib/core/services/background_service.dart`
- Test: `test/core/services/cloud_storage/headless_cloud_provider_test.dart`, `test/core/services/background_service_test.dart` (or wherever `runScheduledBackup` is tested now)

**Interfaces:**
- Produces:
  - `Future<CloudStorageProvider?> resolveHeadlessBackupCopyProvider({required SharedPreferences prefs, EncryptionKeyStore? encryptionKeyStore, CloudStorageProvider Function(CloudProviderType)? instanceFor, CloudStorageProvider Function(AccountKind kind, String accountId)? forAccount})`.
    - With no pinned row, it delegates to `resolveHeadlessCloudProvider`.
    - With a pinned row, it builds the provider per kind:
      - S3 and WebDAV: the storage provider with the `keyFor(id)` credential store, as the adapters do.
      - Dropbox: `DropboxStorageProvider` with the per-account auth store.
      - Google Drive and iCloud: today's singletons.
    - The encryption wrap is the same as today. Custom-folder storage mode still returns null.
  - `buildScheduledBackupService` uses it. It passes `copyAccountId` from the stored preference, or otherwise today's sync read.

- [ ] **Step 1: Write the failing tests.**
  - `'a pinned S3 row resolves to that row, not the sync selection'`, with sync on S3 and a different pinned row (Review Focus 2).
  - `'no pinned row resolves exactly as before'`.
  - `'a pinned row in custom-folder mode resolves to null'`.
- [ ] **Step 2: Run the tests.** Expected: FAIL.
- [ ] **Step 3: Implement.** Put the per-kind construction in one function, `headlessSyncProviderFor(AccountKind, String id)`, and make the three adapters call the same constructor, so the foreground and background cannot disagree.
- [ ] **Step 4: Run the tests.** Expected: PASS.
- [ ] **Step 5: Commit** `feat(backup): scheduled backups copy to the chosen account`.

### Task 5: A folder and a cloud copy together

**Files:**
- Modify: `lib/features/backup/data/services/backup_target.dart`, `lib/features/backup/data/services/backup_service.dart` (`_performBackupInto`)
- Test: `test/features/backup/data/services/backup_target_test.dart`, plus the existing `backup_service` test for the upload

**Interfaces:**
- Produces:
  - `BackupWriteResult.uploadSource` (`String?`): a filesystem path that holds the same bytes as the stored backup.
    - For a filesystem target it equals `ref`.
    - For a SAF target it is the staged file, which `write` now leaves in place. The caller deletes it.
  - `_performBackupInto` uploads from `uploadSource`. In the encrypted branch it uploads from `tempSbe` before deleting it. It deletes the staged and temp files in a `finally` once the upload has finished or failed.
  - When both a folder and a cloud copy succeed, `LastBackupDestination` is `cloud`: the copy that names an account.

- [ ] **Step 1: Write the failing tests.**
  - `'a SAF target hands the upload a filesystem file'`, with a fake port and a recording provider: assert the uploaded path is not `content://` and that it exists during the upload (Review Focus 1).
  - `'the staged file is deleted after the upload, including when it throws'`.
  - `'folder plus cloud records cloud as the destination'`.
  - `'encrypted backup to a folder plus cloud uploads the .sbe'`.
- [ ] **Step 2: Run the tests.** Expected: FAIL.
- [ ] **Step 3: Implement.** Remove the "mutually exclusive, so ref is always a filesystem path" comment and its assumption.
- [ ] **Step 4: Run the tests.** Expected: PASS. Then run `test/features/backup`.
- [ ] **Step 5: Commit** `feat(backup): a backup folder and a cloud copy can both be on`.

### Task 6: No silent off

**Files:**
- Modify: `lib/features/settings/presentation/widgets/sync/sync_advanced_section.dart` (Stop syncing), `lib/features/settings/presentation/widgets/sync/sync_account_switch.dart` (`leaveSyncForAccount`), `lib/features/settings/presentation/pages/account_detail_page.dart` (`_backupWarning` and the sign-out and remove flows)
- Test: `sync_advanced_section_test.dart`, `sync_account_switch_test.dart`, `account_detail_page_test.dart`

**Interfaces:**
- Consumes: Task 1's `pinCopyTo` and `setNoCopy`, and Task 3's `backupCopyTargetProvider`.
- Produces:
  - **Stop syncing**, with the copy following sync and on: it calls `pinCopyTo(syncRow)` before sync is torn down. The copy keeps going to the same place, and the dialog no longer carries the backup warning in that case.
  - **`leaveSyncForAccount`** (signing out of, or removing, the sync account): it calls `setNoCopy()` only when the copy goes to that account, whether by following sync or by a pin to one of its rows. A pin to another account is left alone.
  - **Account detail:** signing out of, or removing, an account the copy is pinned to shows the new paragraph `settings_accounts_backupCopyStops`, "Backups will stop making a copy in this account." It then calls `setNoCopy()` after the confirmation. The existing `settings_cloudSync_signOut_backupWarning` stays for the sync account.
  - The temporary `disableCloudBackup` from Task 1 is deleted.

- [ ] **Step 1: Write the failing tests.**
  - `'Stop syncing pins the copy to the sync account and keeps it on'`.
  - `'Stop syncing with the copy pinned elsewhere leaves it alone'` (Review Focus 3).
  - `'signing out of the sync account turns off a copy that follows sync'`.
  - `'signing out of the sync account leaves a copy pinned to another account'`.
  - `'removing the pinned copy account warns and turns the copy off'`.
  - `'cancelling that confirmation changes nothing'`.
- [ ] **Step 2: Run the tests.** Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run the tests.** Expected: PASS. Run `test/features/settings`.
- [ ] **Step 5: Commit** `feat(backup): the backup copy never turns off without saying so`.

### Task 7: The account sheet offers "No copy off this device"

**Files:**
- Modify: `lib/features/settings/presentation/widgets/accounts/account_sheet.dart`
- Test: `test/features/settings/presentation/widgets/accounts/account_sheet_test.dart`

**Interfaces:**
- Produces:
  - `sealed class AccountSheetChoice` with two cases: `ChoseAccount(AccountGroup group)` and `ChoseNone()`.
  - `Future<AccountSheetChoice?> showAccountOrNoneSheet(BuildContext context, {required String noneLabel, required bool noneSelected, Set<AccountKind>? allowedKinds, String? currentKey, String? Function(AccountGroup)? consequenceOf})`.
    - It puts a "none" tile (icon `Icons.phone_android`) at the top of "Your accounts". The tile is selected when `noneSelected` is true.
    - `showAccountSheet` keeps its signature and return type. Both functions share `_AccountSheet`, which pops an `AccountSheetChoice` internally.

- [ ] **Step 1: Write the failing tests.**
  - `'the none tile returns ChoseNone'`.
  - `'an account returns ChoseAccount after any sign-in'`.
  - `'showAccountSheet callers still get an AccountGroup'`: one existing test kept unchanged as proof.
  - `'the none tile is selected when noneSelected'`.
- [ ] **Step 2: Run the tests.** Expected: FAIL.
- [ ] **Step 3: Implement.** Keep `account_sheet.dart` under 400 lines. If it goes over, move the pending-consequence view into `account_sheet_consequence.dart`.
- [ ] **Step 4: Run the tests.** Expected: PASS. Run the phase 2 sheet callers' tests (`sync_using_row`, the library pages). Expected: PASS.
- [ ] **Step 5: Commit** `feat(settings): the account sheet can offer a none choice`.

### Task 8: The Backups page

**Files:**
- Modify: `lib/features/backup/presentation/pages/backup_settings_page.dart` (it becomes the layout only), `lib/features/backup/presentation/widgets/export_bottom_sheet.dart` (the "Save to a folder" label), `lib/features/backup/presentation/widgets/backup_encryption_section.dart` and `quarantined_databases_section.dart` (header text only)
- Create, under `lib/features/backup/presentation/widgets/`:
  - `backup_status_line.dart`
  - `backup_auto_row.dart` (the switch plus the frequency subtitle and its picker dialog)
  - `backup_copy_row.dart` (the Using row)
  - `backup_actions.dart` (Back up now, Restore from a file, with today's handlers moved here unchanged)
  - `backup_history_section.dart` (moved unchanged)
  - `backup_advanced_section.dart` (Keep the last {n} backups with the footprint, Backup folder on this device with Change and Use default, Save a backup file, Password protection, Set-aside databases)
- Modify: the 11 ARB files and the generated l10n
- Test: `test/features/backup/presentation/pages/backup_settings_page_test.dart` (ported), plus one test file per new widget that has logic (`backup_copy_row_test.dart`, `backup_auto_row_test.dart`, `backup_advanced_section_test.dart`)

**Interfaces:**
- Consumes: Task 3's `backupCopyTargetProvider`, Task 7's `showAccountOrNoneSheet`, `backupsRowStatusProvider`, and `DataRowStatusText` (phase 1, for the status line).
- **Order, top to bottom:**
  1. The operation status message, as today.
  2. The status line.
  3. Back up automatically.
  4. Copy to.
  5. Back up now.
  6. Restore from a file.
  7. History.
  8. Advanced.
- **The Copy to row, per `BackupCopyTarget`:**

  | Target | Title | Subtitle | Action |
  | --- | --- | --- | --- |
  | `CopyFollowsSync(group)` | Copy to {group.label} | Same account as sync | Change |
  | `CopyToAccount` | Copy to {group.label} | the account state, from `statusOf(row.id)` | Change |
  | `CopyAccountGone` | The copy's account was removed | | Choose an account |
  | `NoCopy`, or following sync with no account | No copy off this device | | Choose an account |

  - Change and Choose an account open `showAccountOrNoneSheet` with `allowedKinds: syncAccountKinds`.
  - `ChoseNone` calls `setNoCopy`.
  - Choosing the sync group calls `setCopyFollowsSync`.
  - Choosing any other group resolves its sync-role row, through `ensureRole(group, AccountRole.sync)` for S3 and WebDAV, then calls `setCopyTo(row)`.
- **New strings** (11 locales):
  - `settings_backups_copyTo` "Copy to {account}"
  - `settings_backups_copySameAsSync` "Same account as sync"
  - `settings_backups_noCopy` "No copy off this device"
  - `settings_backups_chooseAccount` "Choose an account"
  - `settings_backups_copyAccountGone` "The copy's account was removed"
  - `settings_backups_auto` "Back up automatically"
  - `settings_backups_backUpNow` "Back up now"
  - `settings_backups_restoreFile` "Restore from a file"
  - `settings_backups_keepLast` "Keep the last {count} backups"
  - `settings_backups_folder` "Backup folder on this device"
  - `settings_backups_useDefault` "Use default"
  - `settings_backups_saveFile` "Save a backup file"
  - `settings_backups_saveToFolder` "Save to a folder"
  - `settings_backups_passwordProtection` "Password protection"
  - `settings_backups_setAside` "Set-aside databases"
  - plus Task 2's `backup_restore_copyInOtherAccount`, and Task 6's `settings_accounts_backupCopyStops` and `settings_accounts_usage_backups`.
- **Deleted keys** once nothing reads them: `backup_cloud_enabled`, `backup_cloud_enabled_subtitle`, `backup_location_title`, `backup_schedule_enabled`, `backup_backupNow`, `backup_export_title` and `backup_import_title` (with their subtitles), and `backup_section_auto`. Before deleting each one, check that no other caller reads it.

- [ ] **Step 1: Before screenshots** of today's page (light, dark, phone, desktop).
- [ ] **Step 2: Write the failing widget tests.**
  - The order test finds the eight sections in order.
  - One Copy to row test per target state.
  - `'choosing No copy turns the copy off'`.
  - `'choosing the sync account follows sync'`.
  - `'choosing an S3 account with no sync row creates it, then pins it'`.
  - `'Use default shows only with a folder chosen and clears it'`.
  - `'the frequency subtitle opens a picker that saves'`.
  - `'Keep the last shows whatever the schedule'`: today it is hidden while automatic backups are off, and the spec moves it to Advanced, always shown.
  - Today's tests for export, restore, history, pin and delete, ported to the new structure with the same assertions.
- [ ] **Step 3: Run the tests.** Expected: FAIL.
- [ ] **Step 4: Implement.** Add the ARB strings and run `flutter gen-l10n`.
- [ ] **Step 5: Run the tests.** Expected: PASS. Then run, in order: `dart format .`, `flutter analyze`, `test/features/backup`, `test/features/settings`, `test/architecture`, `test/shared`.
- [ ] **Step 6: After screenshots** of the same views.
- [ ] **Step 7: Commit** `feat(backup): reorder the Backups page around its status and copy`.

## Done when

- The copy can go to any account the sheet offers, or nowhere. A backup folder and a cloud copy can both be on.
- Only the diver's choice, or a named confirmation, turns the copy off.
- Upgraded devices behave exactly as before until the diver touches Copy to.
- Every row from the spec's Backup appendix is reachable on the new page.
- The suite is green, and the files are within their limits.
