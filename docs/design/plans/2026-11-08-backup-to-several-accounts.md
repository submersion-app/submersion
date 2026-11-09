# Back Up to Several Accounts Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task (inline, in this session). Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Copy each backup to any number of connected accounts beside the existing main copy, and keep restore, retention, encryption and status honest for every copy.

**Architecture:** The main copy (`copyAccountId` / follow sync) is untouched. A list of extra roster rows lives in `BackupSettings`; `BackupService` receives one `ExtraCopyDestination(accountId, provider)` per row at build time and, in a new part file, uploads to each after the main copy, records each upload on the `BackupRecord`, deletes them with the record, and falls back to them on restore. The Backups page lists the extra rows under the main copy row.

**Tech Stack:** Flutter, Riverpod (`StateNotifier`, `Provider`, `FutureProvider`), SharedPreferences, `CloudStorageProvider`, ARB l10n.

**Spec:** `docs/design/specs/2026-11-08-backup-to-several-accounts-design.md`

## Global Constraints

- Extra copies run only while `cloudBackupEnabled` is true.
- An extra account equal to the account the main copy goes to is skipped.
- No second Google Drive or iCloud destination (process-wide sign-in).
- A failed extra copy never throws out of `performBackup`.
- History listing, pin markers, cross-device retention and the orphan scan stay main-folder only.
- SharedPreferences key: `backup_extra_copy_accounts` (JSON list of `{"id","kind"}`), `backup_last_extra_copy_missing` (string list).
- New strings in all 11 ARBs, inserted by anchor key, `flutter gen-l10n` run last, committed as `i18n(backup): ...`.
- No em-dashes anywhere; `dart format .` before each commit; files under 800 lines (`backup_service.dart` is already over: new logic goes in a part file).

## Review Focus

- The main copy follows sync, and sync moves onto an account that is also an extra: the backup must upload there once, not twice. (Task 2 test `skips an extra that is the main copy's account`.)
- An extra account removed from the roster on another device: no upload, its id lands in `lastExtraCopyMissingIds`, and deleting an old record still removes the record. (Task 2 `missed when provider is null`, Task 3 `unreachable extra copy is forgotten`.)
- Sync encryption on but this device locked: an extra copy must fail closed, never plaintext. (Task 2 `extra copy fails closed when locked`.)
- A Git extra account defers deletes: a pruned record's extra copy must be pushed. (Task 3 `flushes deferred deletes for extras`.)
- Backup encryption on: the extra copy is the `.sbe`, not the plaintext export. (Task 2 `extra copy uploads the sbe`.)

---

### Task 1: Settings, record and preferences

**Files:**
- Create: `lib/features/backup/domain/entities/backup_copy_account.dart`
- Create: `lib/features/backup/domain/entities/extra_cloud_copy.dart`
- Modify: `lib/features/backup/domain/entities/backup_settings.dart`
- Modify: `lib/features/backup/domain/entities/backup_record.dart`
- Modify: `lib/features/backup/data/repositories/backup_preferences.dart`
- Modify: `lib/features/backup/presentation/providers/backup_settings_notifier.dart`
- Test: `test/features/backup/domain/entities/backup_record_test.dart`, `test/features/backup/data/repositories/backup_preferences_test.dart`, `test/features/backup/presentation/providers/backup_settings_notifier_test.dart`

**Interfaces:**
- Produces: `class BackupCopyAccount extends Equatable { final String accountId; final AccountKind kind; Map<String, dynamic> toJson(); static BackupCopyAccount? fromJson(Object? json) /* null for an unknown kind */ }`
- Produces: `class ExtraCloudCopy extends Equatable { final String accountId; final String fileId; toJson(); static ExtraCloudCopy? fromJson(Object?) }`
- Produces: `BackupSettings.extraCopyAccounts: List<BackupCopyAccount>` (default `const []`), `BackupSettings.lastExtraCopyMissingIds: List<String>` (default `const []`), both in `copyWith` and `props`.
- Produces: `BackupRecord.extraCloudCopies: List<ExtraCloudCopy>` (default `const []`), in `copyWith`, `props`, JSON key `extraCloudCopies` (absent reads as empty), and kept by `withoutCloudCopy()` and `withoutLocalCopy()`.
- Produces: `BackupPreferences.setExtraCopyAccounts(List<BackupCopyAccount>)`, `BackupPreferences.setLastExtraCopyMissingIds(List<String>)`.
- Produces: `BackupSettingsNotifier.addExtraCopyAccount(ConnectedAccount row)` (no-op when already listed), `removeExtraCopyAccount(String accountId)`; `setCopyTo(row)` also removes `row.id` from the extras.

- [ ] **Step 1: Write failing tests**
  - `backup_record_test`: `extraCloudCopies round-trips through JSON`; `a record without extraCloudCopies reads as empty`; `withoutCloudCopy keeps extra copies`.
  - `backup_preferences_test`: `extra copy accounts round-trip`; `an entry with an unknown kind is dropped`; `malformed JSON reads as empty`; `last extra copy missing ids round-trip`.
  - `backup_settings_notifier_test`: `addExtraCopyAccount appends once`; `removeExtraCopyAccount drops it`; `setCopyTo removes the row from the extras`.
- [ ] **Step 2: Run** `flutter test test/features/backup/domain test/features/backup/data/repositories test/features/backup/presentation/providers/backup_settings_notifier_test.dart`; expect compile failures.
- [ ] **Step 3: Implement** the interfaces above. `getSettings` decodes the JSON in a try/catch and skips entries `fromJson` rejects.
- [ ] **Step 4: Run** the same tests; expect PASS.
- [ ] **Step 5: Commit** `feat(backup): store extra backup copy accounts`.

### Task 2: Upload to extra accounts

**Files:**
- Create: `lib/features/backup/data/services/extra_copy_destination.dart`
- Create: `lib/features/backup/data/services/backup_service_extra_copies.dart` (part of `backup_service.dart`)
- Modify: `lib/features/backup/data/services/backup_service.dart` (constructor, `_performBackupInto`, `_uploadToCloud`, `_getOrCreateCloudBackupFolder`)
- Test: `test/features/backup/data/services/backup_service_extra_copies_test.dart`

**Interfaces:**
- Consumes: Task 1 entities and preference setters.
- Produces: `class ExtraCopyDestination { const ExtraCopyDestination(this.accountId, this.provider); final String accountId; final CloudStorageProvider? provider; }`
- Produces: `BackupService({..., List<ExtraCopyDestination> extraCopies = const []})`.
- Changes: `_uploadToCloud(String localPath, String filename, {CloudStorageProvider? via})` and `_getOrCreateCloudBackupFolder({bool rethrowRefused = false, CloudStorageProvider? via})`; `via` defaults to `_cloudProvider`.
- Produces (part file): `Future<({List<ExtraCloudCopy> copies, List<String> missed})> _copyToExtras(String sourcePath, String storedName, {required String? mainAccountId})`, never throws. Called from both branches of `_performBackupInto` right after the main `_copyToCloud`, only when `settings.cloudBackupEnabled`. The record gets `extraCloudCopies: copies`; then `setLastExtraCopyMissingIds(missed)` (empty when the copy is off).

- [ ] **Step 1: Write failing tests** (fake `CloudStorageProvider`s as in `backup_service_test.dart`'s "performBackup cloud upload" group):
  - `uploads the backup to every extra account` (two extras, record lists both file ids).
  - `a failing extra does not stop the next one or the backup` (first throws; second uploaded; missed == [first]).
  - `missed when provider is null`.
  - `skips an extra that is the main copy's account` (sync account id == extra id; that fake receives no upload; missed empty).
  - `no extra copies while the copy is off`.
  - `extra copy uploads the sbe` (backup encryption on; uploaded name ends `.sbe`).
  - `extra copy fails closed when locked` (sync encryption on, no key; no upload, id in missed).
- [ ] **Step 2: Run** `flutter test test/features/backup/data/services/backup_service_extra_copies_test.dart`; expect FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** that file and `test/features/backup/data/services/backup_service_test.dart`; expect PASS.
- [ ] **Step 5: Commit** `feat(backup): copy each backup to the extra accounts`.

### Task 3: Delete, prune and restore through extra copies

**Files:**
- Modify: `backup_service_extra_copies.dart`, `backup_service.dart` (`_deleteBackup`), `backup_service_copy_out.dart` (`_resolveBackupSource`)
- Test: `backup_service_extra_copies_test.dart`

**Interfaces:**
- Produces (part file): `CloudStorageProvider? _extraProviderFor(String accountId)` (null unless listed with a provider); `Future<void> _deleteExtraCopies(BackupRecord record)` (deletes each reachable copy, `flushDeferredWrites` once per provider touched, logs and forgets the rest, never throws); `Future<PreparedBackupFile?> _fetchFromExtra(BackupRecord record)` (first reachable copy via `_fetchToTemp`, trying the next on failure; null when none).
- `_deleteBackup` calls `_deleteExtraCopies(record)` before removing the record, whatever `deleteCloud` says (pruning batches only the main copy).
- `_resolveBackupSource` tries `_fetchFromExtra` after the main copy and before raising `BackupCopyInOtherAccountException` / "not found".

- [ ] **Step 1: Write failing tests:** `deleteBackup removes extra copies`; `pruning removes extra copies of pruned records`; `unreachable extra copy is forgotten` (record removed, no throw); `flushes deferred deletes for extras` (fake counts flushes); `restore falls back to an extra copy` (no local file, main provider null); `restore tries the next extra when one fails`.
- [ ] **Step 2: Run**; expect FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** the file plus `backup_service_copy_out_test.dart` and `backup_service_test.dart`; expect PASS.
- [ ] **Step 5: Commit** `feat(backup): remove and restore extra backup copies`.

### Task 4: Encryption paths

**Files:**
- Modify: `backup_service.dart` (`reencryptExistingBackups`, `deletePlaintextCloudBackups`), `backup_service_extra_copies.dart`
- Test: `backup_service_extra_copies_test.dart`

**Interfaces:**
- Produces (part file): `Future<({List<ExtraCloudCopy> copies, bool residual})> _reencryptExtras(BackupRecord record, String newPath, String newName)`: re-uploads each copy whose account is reachable, deletes the old id when it changed, flushes and resets history per provider; an unreachable copy or failed delete sets `residual`. Copies it could not reach stay in the list with their old id.
- `reencryptExistingBackups` commits `extraCloudCopies` from it and counts `residual` as a failure.
- `deletePlaintextCloudBackups` also clears `.db` files from each extra provider's folder and adds them to the count.

- [ ] **Step 1: Write failing tests:** `re-encrypt re-uploads extra copies`; `re-encrypt counts an unreachable extra as failed`; `deletePlaintextCloudBackups clears extra folders`.
- [ ] **Step 2: Run**; expect FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** the file plus `backup_service_encryption_test.dart`; expect PASS.
- [ ] **Step 5: Commit** `feat(backup): re-encrypt extra backup copies`.

### Task 5: Build the destinations (foreground and scheduled)

**Files:**
- Create: `lib/features/backup/presentation/providers/extra_copy_providers.dart`
- Modify: `lib/features/backup/presentation/providers/backup_providers.dart` (`backupServiceProvider`)
- Modify: `lib/core/services/cloud_storage/headless_cloud_provider.dart`, `lib/core/services/background_service.dart`
- Test: `test/features/backup/presentation/providers/extra_copy_providers_test.dart`, `test/core/services/cloud_storage/headless_cloud_provider_test.dart`, `test/core/services/background_service_backup_test.dart`

**Interfaces:**
- Produces: `final extraCopyDestinationsProvider = Provider<List<ExtraCopyDestination>>` : empty while the copy is off; otherwise one per `extraCopyAccounts` entry, its provider built like `backupCopyProviderProvider`'s pinned branch (`copyRowOnRosterProvider`, `capabilityFor<SyncCapable>`, `wrapForLibrary`).
- Produces: `Future<List<ExtraCopyDestination>> resolveHeadlessExtraCopyDestinations({required SharedPreferences prefs, EncryptionKeyStore? encryptionKeyStore, CloudStorageProvider Function(CloudProviderType)? instanceFor, CloudStorageProvider? Function(AccountKind, String)? forAccount, Future<bool> Function(String)? accountOnRoster})`, built per row like the pinned branch of `resolveHeadlessBackupCopyProvider` (shared helper extracted).
- `runScheduledBackup`: `cloudCopyMissing` is also true when the refreshed settings' `lastExtraCopyMissingIds` is non-empty.

- [ ] **Step 1: Write failing tests:** provider `empty while the copy is off`, `one destination per extra account`, `null provider for a row not on the roster`; headless `builds each extra destination`, `null provider off the roster`; background `a missed extra copy reports the copy missing`.
- [ ] **Step 2: Run**; expect FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** those files; expect PASS.
- [ ] **Step 5: Commit** `feat(backup): build extra copy destinations`.

### Task 6: Health, account usage and account removal

**Files:**
- Modify: `lib/features/settings/domain/data_health/feature_health.dart`, `backup_health.dart`, `lib/features/settings/presentation/providers/data_health_providers.dart`, `lib/features/settings/presentation/widgets/data_health/health_text.dart`
- Modify: `lib/core/services/accounts/account_usage_service.dart`
- Modify: `lib/features/settings/presentation/pages/account_detail_page.dart`
- Test: `test/features/settings/domain/data_health/backup_health_test.dart`, `test/core/services/accounts/account_usage_service_test.dart` (or its existing home), account detail page test

**Interfaces:**
- Produces: `HealthReason.backupExtraCopyMissing`; `BackupHealthInputs.lastExtraCopyMissing` (bool, default false). Attention when the copy is on, the main copy arrived and an extra did not. Text key `dataHealth_backup_extraCopyMissing`.
- Produces: `AccountUsageSnapshot.backupExtraCopyAccountIds: Set<String>`; `usagesOf` gives `backupCopy` for those ids (once, even when also the main copy).
- Account detail sign-out and remove call `removeExtraCopyAccount` for every row id of the group.

- [ ] **Step 1: Write failing tests:** health `a missed extra copy needs attention`, `a missed main copy keeps its own reason`; usage `an extra copy account is used for the backup copy`; detail page `signing out drops the account from the extra copies`.
- [ ] **Step 2: Run**; expect FAIL.
- [ ] **Step 3: Implement** (English string added to `app_en.arb` now; translations in Task 7).
- [ ] **Step 4: Run** those tests; expect PASS.
- [ ] **Step 5: Commit** `feat(backup): report missed extra copies`.

### Task 7: Backups page rows and strings

**Files:**
- Create: `lib/features/backup/presentation/widgets/backup_extra_copy_rows.dart`
- Modify: `lib/features/backup/presentation/pages/backup_settings_page.dart` (below `BackupCopyRow()`)
- Modify: `lib/features/settings/presentation/widgets/accounts/account_chooser.dart` and `account_sheet.dart` (`excludedKeys`)
- Modify: all 11 `lib/l10n/arb/app_*.arb`
- Test: `test/features/backup/presentation/widgets/backup_extra_copy_rows_test.dart`, `test/features/settings/presentation/widgets/accounts/account_chooser_test.dart` (existing home)

**Interfaces:**
- Produces: `AccountChooser({..., Set<String> excludedKeys = const {}})` and `showAccountSheet(..., Set<String> excludedKeys = const {})`: hides those groups from "Your accounts" without changing which kinds count as already added.
- Produces: `class BackupExtraCopyRows extends ConsumerWidget`: nothing unless the main copy target is `CopyFollowsSync(group != null)` or `CopyToAccount`. Then one `ListTile` per extra (key `backup-extra-copy-<id>`): title `settings_backups_alsoCopyTo(label)`, subtitle `settings_backups_extraCopyMissed` when in `lastExtraCopyMissingIds`, else `settings_backups_copyAccountGone` when the roster lacks it, else `accountStateText`; `TileSubtitleAction` `common_action_remove` (key `backup-extra-copy-remove-<id>`). Then an add `ListTile` (key `backup-extra-copy-add`, icon `Icons.add`) titled `settings_backups_addCopyAccount`, opening `showAccountSheet(allowedKinds: syncAccountKinds minus Google Drive / iCloud kinds already used, excludedKeys: main and extra group keys)`, then `_syncRowOf`-style row resolution (move `_syncRowOf` to a shared public `backupCopyRowOf`) and `addExtraCopyAccount`.
- Strings (en): `settings_backups_alsoCopyTo` "Also copy to {account}", `settings_backups_addCopyAccount` "Copy to another account too", `settings_backups_extraCopyMissed` "The last backup did not reach this account", `dataHealth_backup_extraCopyMissing` "Last backup did not reach every account".

- [ ] **Step 1: Write failing tests:** rows `hidden while there is no copy`, `lists each extra account`, `shows a missed copy`, `remove drops the account`, `add excludes accounts already used`; chooser `excludedKeys hides the group`.
- [ ] **Step 2: Run**; expect FAIL.
- [ ] **Step 3: Implement**, then translate the four keys into the ten locale ARBs and run `flutter gen-l10n` last.
- [ ] **Step 4: Run** the tests, `test/features/backup`, `test/features/settings`, `test/architecture`, `test/shared`; `flutter analyze`; expect clean.
- [ ] **Step 5: Commit** `feat(backup): add extra copy accounts on the Backups page` and `i18n(backup): translate extra copy strings`.

### Task 8: After screenshots

- [ ] Capture the Backups page with one extra account, light and dark, phone and desktop widths; same names as the before set.
