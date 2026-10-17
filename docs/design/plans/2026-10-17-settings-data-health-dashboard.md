# Settings > Data Health Dashboard Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task (inline, in this session). Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A status strip, attention lines and facts line at the top of a flat
Settings > Data page, plus matching status marks on the Backup, Cloud Sync,
Shared Site Libraries and Photos & Media rows, all from one health model.

**Architecture:** Pure evaluators in `lib/features/settings/domain/data_health/`
turn small input snapshots into a `FeatureHealth` (level + reason). Riverpod
providers in `data_health_providers.dart` gather the snapshots from the
existing backup, sync, shared-library and media providers. Two new pieces of
persisted state (scheduled backup failure plus cloud-copy flag in
`BackupPreferences`; last sync failure in a new `SyncFailureStore`) fill the
gaps. The Data section moves out of `settings_page.dart` into its own flat
page widget.

**Tech Stack:** Flutter, Riverpod (legacy `StateNotifier` via
`package:submersion/core/providers/provider.dart`), SharedPreferences, Drift
(`customSelect` for counts), ARB l10n (11 locales).

**Spec:** `docs/design/specs/2026-10-17-settings-data-health-dashboard-design.md`

## Global Constraints

- Four levels, severity order: failing > attention > healthy > notSetUp.
- Rows marked (gate) in the spec tables short-circuit; the rest compete, most severe wins, ties to the earlier row.
- Backup overdue: older than two frequency periods. Sync offline: network failure and no success in the last 7 days.
- Symbol colours from `StatusColors.of(context)`: failing `alert.accent`, attention `warn.accent`, healthy `ok.accent`, glyph `onAccent`; notSetUp is an outline in `colorScheme.outline`.
- Glyphs: healthy `Icons.check`, attention `Icons.priority_high`, failing `Icons.close`, notSetUp `Icons.remove`.
- Strip symbol 26 dp, row mark 16 dp.
- No `Card` anywhere on the Data page.
- Every new string in all 11 ARBs; run `flutter gen-l10n` only after every locale is translated.
- Facts count the whole database; sites exclude shared-library rows (`shared_library_id IS NULL`).
- Byte sizes use `formatBytes` from `lib/shared/utils/byte_format.dart` (not localized, per that file).
- No schema change. New state lives in SharedPreferences.
- Tests restore global state they replace. Run `test/architecture/` after adding `lib/` files.
- No em-dash characters anywhere.

**Two readings of the spec, settled here:** a custom backup location counts
as a copy off this device (the diver chose it, and the app cannot tell a NAS
or synced folder from a local one), so backup rule 5 needs cloud backup, sync
and a custom location all absent. An export to a chosen path stamps
`lastBackupTime` as today but does not touch the cloud-copy flag, since an
export never uploads.

## Review Focus

1. A sync failure stored in an earlier session, then a successful sync on launch: the strip must go back to healthy. (Task 4 test `success clears a stored failure`.)
2. A stored failure for provider A after switching to provider B: ignored. (Task 2 test `failure for another provider is ignored`.)
3. A reader library whose storage refuses writes: healthy, not "edits on hold". (Task 2 test `reader with read-only storage is healthy`.)
4. A store announced but its attach item dismissed on this device: notSetUp, no attention line. (Task 2 test `dismissed attach is not set up`.)
5. Phone width 320 dp at text scale 2.0: the strip and attention lines lay out without overflow. (Task 6 test `strip fits a narrow phone at large text`.)

---

### Task 1: Health model and backup evaluator

**Files:**
- Create: `lib/features/settings/domain/data_health/feature_health.dart`
- Create: `lib/features/settings/domain/data_health/backup_health.dart`
- Test: `test/features/settings/domain/data_health/backup_health_test.dart`

**Interfaces:**
- Produces:
  - `enum HealthLevel { failing, attention, healthy, notSetUp }` with `int get severity` (failing 3, attention 2, healthy 1, notSetUp 0).
  - `enum DataFeature { backup, sync, sharedLibraries, media }`.
  - `enum HealthReason { ok, notSetUp, backupAutoOff, backupFailed, backupOverdue, backupNever, backupCloudCopyMissing, backupNoOffDeviceCopy, syncCustomFolder, syncOff, syncNeedsPassphrase, syncAwaitingAdoption, syncSignedOut, syncFailed, syncOffline, syncConflicts, syncPeersHeld, syncAutoOff, syncNeverSynced, librariesFailed, librariesEditsHeld, mediaFinishSetup, mediaTransfersPaused }`.
  - `class FeatureHealth { final DataFeature feature; final HealthLevel level; final HealthReason reason; final DateTime? when; final int? count; final String? name; }` with `const` constructor, `==`/`hashCode` (Equatable).
  - `FeatureHealth pickHealth(DataFeature feature, List<FeatureHealth> candidates)`: most severe candidate, ties to the earliest; empty list gives healthy/`ok`.
  - `class BackupHealthInputs { bool autoEnabled; BackupFrequency frequency; DateTime? lastBackupAt; DateTime? lastScheduledFailureAt; bool cloudBackupEnabled; bool lastCloudCopyMissing; bool hasCustomLocation; bool syncConfigured; }`.
  - `FeatureHealth evaluateBackupHealth(BackupHealthInputs i, DateTime now)`.

- [ ] **Step 1: Write the failing tests** (table style, one `test` per row, fixed `now = DateTime(2026, 10, 17, 12)`):
  - `auto off is attention autoOff even after a failure` (gate): `autoEnabled: false, lastScheduledFailureAt: now - 1h` gives `(attention, backupAutoOff)`.
  - `failure newer than last success is failing`: failure at now-1h, lastBackup now-2d, gives `(failing, backupFailed, when: now-1h)`.
  - `failure older than last success is ignored`: failure now-3d, lastBackup now-1h, cloud on gives `(healthy, ok)`.
  - `never backed up is attention never`.
  - `weekly backup 13 days old is healthy, 15 days old is overdue` (two periods = 14 days): `(attention, backupOverdue, when: lastBackupAt)`.
  - `cloud copy missing is attention`.
  - `no cloud, no sync, no custom location is noOffDeviceCopy`; `custom location counts as off device`; `sync configured counts as off device`.
  - `failing outranks overdue` (both apply: result failing).

- [ ] **Step 2:** Run `flutter test test/features/settings/domain/data_health/backup_health_test.dart`. Expected: FAIL (missing files).
- [ ] **Step 3:** Implement the two files. Evaluator: gate row first, then `pickHealth` over the applicable non-gate candidates in spec order.
- [ ] **Step 4:** Re-run. Expected: PASS.
- [ ] **Step 5:** Commit `feat(settings): data health model and backup rules`.

### Task 2: Sync, shared-library and media evaluators

**Files:**
- Create: `lib/features/settings/domain/data_health/sync_health.dart`
- Create: `lib/features/settings/domain/data_health/shared_library_health.dart`
- Create: `lib/features/settings/domain/data_health/media_health.dart`
- Test: `test/features/settings/domain/data_health/sync_health_test.dart`, `shared_library_health_test.dart`, `media_health_test.dart`

**Interfaces:**
- Consumes: Task 1 types.
- Produces:
  - `enum SyncFailureKind { network, other }`; `class SyncFailureRecord { String providerId; DateTime at; SyncFailureKind kind; String message; }` (this file owns the type; Task 4 persists it).
  - `class SyncHealthInputs { bool customFolder; bool providerSelected; String? providerId; bool needsPassphrase; bool awaitingAdoption; bool authenticated; SyncFailureRecord? lastFailure; DateTime? lastSyncAt; int conflicts; bool peersHeld; bool autoSyncEnabled; }`.
  - `FeatureHealth evaluateSyncHealth(SyncHealthInputs i, DateTime now)`.
  - `class LibraryHealthInput { String name; String? lastError; bool rolesRejected; bool pendingRolesWaiting; bool readOnlyDetected; SharedLibraryRole listedRole; }`.
  - `FeatureHealth evaluateSharedLibraryHealth(List<LibraryHealthInput> libraries)`.
  - `class MediaHealthInputs { bool storeAttachedHere; bool storeAnnounced; bool attachItemPending; bool lightroomConnected; int mediaSetupItems; bool transfersSuspended; bool transfersWaitingWithReason; }`.
  - `FeatureHealth evaluateMediaHealth(MediaHealthInputs i)`.

- [ ] **Step 1: Write the failing tests.**
  - Sync: `custom folder is notSetUp even with no provider` (gate order); `no provider is attention syncOff`; `needs passphrase is failing`; `awaiting adoption is failing`; `signed out is failing`; `other failure newer than last sync is failing with when`; `failure for another provider is ignored`; `network failure with sync 2 days ago is healthy`; `network failure with sync 8 days ago is attention offline`; `network failure and never synced is attention neverSynced`; `conflicts give count`; `peers held is attention`; `auto sync off is attention autoOff`; `never synced is attention`; `failing outranks conflicts`.
  - Libraries: `no libraries is notSetUp`; `lastError is failing with the library name`; `two libraries with errors give count 2`; `rolesRejected is attention editsHeld with name`; `pending roles is attention`; `editor with read-only storage is attention`; `reader with read-only storage is healthy`.
  - Media: `nothing attached and no Lightroom is notSetUp`; `dismissed attach is not set up` (announced, not attached, `attachItemPending: false`, no Lightroom); `announced with attach item pending is attention finishSetup`; `Lightroom only, all fine, is healthy`; `setup items is attention`; `suspended transfers is attention paused`; `waiting with reason is attention paused`.
- [ ] **Step 2:** Run the three files. Expected: FAIL.
- [ ] **Step 3:** Implement. Library rule 3 condition: `rolesRejected || pendingRolesWaiting || (readOnlyDetected && listedRole != SharedLibraryRole.reader)`. Library failing: `count` = number with `lastError`, `name` = first such library's name. Sync offline/neverSynced: when the failure is `network`, it yields offline only if `lastSyncAt` is non-null and older than 7 days; if `lastSyncAt` is null it yields `syncNeverSynced`.
- [ ] **Step 4:** Re-run. Expected: PASS.
- [ ] **Step 5:** Commit `feat(settings): sync, shared library and media health rules`.

### Task 3: Persist scheduled backup failures and the cloud-copy flag

**Files:**
- Modify: `lib/features/backup/domain/entities/backup_settings.dart` (fields + copyWith + props)
- Modify: `lib/features/backup/data/repositories/backup_preferences.dart`
- Modify: `lib/features/backup/data/services/backup_service.dart:~295` (performBackup path only, not the export at ~365)
- Modify: `lib/core/services/background_service.dart` (`runScheduledBackup` catch)
- Modify: `lib/features/backup/presentation/providers/backup_providers.dart` (`_checkDesktopBackup` catch; `BackupSettingsNotifier`)
- Test: `test/features/backup/data/repositories/backup_preferences_test.dart`, the existing `runScheduledBackup` test file (find with `grep -rln runScheduledBackup test`), the existing backup service test.

**Interfaces:**
- Produces:
  - `BackupSettings.lastScheduledFailureAt` (`DateTime?`), `lastScheduledFailureMessage` (`String?`), `lastCloudCopyMissing` (`bool`, default false).
  - `BackupPreferences.setLastScheduledFailure(DateTime at, String message)`, `setLastCloudCopyMissing(bool value)`; keys `backup_last_scheduled_failure_at`, `backup_last_scheduled_failure_message`, `backup_last_cloud_copy_missing`.
  - `BackupSettingsNotifier.recordScheduledFailure(String message)` and `Future<void> reloadFromDisk()` (awaits `SharedPreferences.reload()` then `refresh()`; picks up writes from the WorkManager isolate).

- [ ] **Step 1: Write failing tests:** prefs round-trip of all three; `runScheduledBackup` failure path stores the failure (existing seam `instanceFor`/throwing adapter); success path stores nothing; `performBackup` with cloud on and a provider whose upload returns null sets `lastCloudCopyMissing` true, and a later upload that succeeds sets it false; cloud off always writes false.
- [ ] **Step 2:** Run them. Expected: FAIL.
- [ ] **Step 3:** Implement. In `BackupService`, right after `setLastBackupTime` in the performBackup path: `setLastCloudCopyMissing(settings.cloudBackupEnabled && location == BackupLocation.local)`. Desktop catch calls `_ref.read(backupSettingsProvider.notifier).recordScheduledFailure(e.toString())`.
- [ ] **Step 4:** Run them plus `flutter test test/features/backup test/core/services/background_service_test.dart`. Expected: PASS.
- [ ] **Step 5:** Commit `feat(backup): remember scheduled backup failures and missing cloud copies`.

### Task 4: Persist the last sync failure

**Files:**
- Create: `lib/core/services/sync/sync_failure_store.dart`
- Modify: `lib/features/settings/presentation/providers/sync_providers.dart` (`_runSyncOnce` success, else and catch branches; new providers next to `postRestoreSyncStoreProvider`)
- Test: `test/core/services/sync/sync_failure_store_test.dart`, plus a notifier test beside the existing `_runSyncOnce` tests (find with `grep -rln "performSync" test/features/settings`).

**Interfaces:**
- Consumes: `SyncFailureRecord`, `SyncFailureKind` (Task 2).
- Produces:
  - `class SyncFailureStore { SyncFailureStore(SharedPreferences); SyncFailureRecord? get last; Future<void> record(SyncFailureRecord r); Future<void> clear(); }` stored as one JSON string under `sync_last_failure`.
  - `final syncFailureStoreProvider = Provider<SyncFailureStore>`.
  - `final syncFailureProvider = StateNotifierProvider<SyncFailureNotifier, SyncFailureRecord?>`, notifier with `record(...)`/`clear()` writing through the store.

- [ ] **Step 1: Write failing tests:** store round-trip and clear; malformed JSON reads as null; `networkError result records a network failure for the active provider`; `error and authError record other`; `a thrown sync records other`; `success clears a stored failure`.
- [ ] **Step 2:** Run. Expected: FAIL.
- [ ] **Step 3:** Implement. providerId from `_ref.read(cloudStorageProviderProvider)?.providerId`; skip recording when it is null. Kind: `networkError` gives network; `error`, `authError` and the catch give other; any other status reaching the else branch gives other.
- [ ] **Step 4:** Run, plus `flutter test test/features/settings/presentation/providers`. Expected: PASS.
- [ ] **Step 5:** Commit `feat(sync): remember the last sync failure across restarts`.

### Task 5: Health and facts providers

**Files:**
- Create: `lib/features/settings/presentation/providers/data_health_providers.dart`
- Create: `lib/features/settings/data/data_facts_repository.dart`
- Test: `test/features/settings/presentation/providers/data_health_providers_test.dart`, `test/features/settings/data/data_facts_repository_test.dart`

**Interfaces:**
- Consumes: Tasks 1 to 4; `backupSettingsProvider`, `isSyncEnabledProvider`, `syncStateProvider`, `isCloudSyncDisabledByCustomFolderProvider`, `selectedCloudProviderTypeProvider`, `cloudStorageProviderProvider`, `syncBehaviorProvider`, `syncFailureProvider`, `sharedLibrariesProvider`, `currentMembershipProvider`, `mediaStoresRepositoryProvider`, `mediaStoreAttachStateProvider`, `lightroomAccountProvider`, `pendingSetupItemsProvider`, `mediaTransferSummaryProvider`, `mediaTransfersSuspendedProvider`, `currentDatabasePathProvider`, `peerDeviceNamesProvider`.
- Produces:
  - `final backupHealthProvider = Provider<FeatureHealth>`
  - `final syncHealthProvider = Provider<FeatureHealth>`
  - `final sharedLibrariesHealthProvider = Provider<FeatureHealth>` (backed by a `FutureProvider.autoDispose<List<LibraryHealthInput>>`; loading or error reads as notSetUp)
  - `final mediaHealthProvider = Provider<FeatureHealth>` (backed by `FutureProvider.autoDispose<MediaHealthInputs>`; loading or error reads as notSetUp)
  - `final dataHealthProvider = Provider<List<FeatureHealth>>` in order backup, sync, sharedLibraries, media.
  - `final syncedDeviceCountProvider = Provider<int>`: `1 + peerDeviceNamesProvider` length (0 when loading).
  - `class DataFacts { int dives; int sites; int media; int databaseBytes; }`, `class DataFactsRepository { Future<DataFacts> load(AppDatabase db, String databasePath); }`, `final dataFactsProvider = FutureProvider.autoDispose<DataFacts>`.
- Media setup items count: `pendingSetupItems` filtered to kinds `mediaStoreAttach`, `mediaStoreReconnect`, plus `accountSignIn` whose `route` is `/settings/media-storage` or `/settings/lightroom`. `attachItemPending` = any `mediaStoreAttach` item. `lightroomConnected` = `lightroomAccountProvider` non-null. `transfersWaitingWithReason` = `summary.waitingReason != null || summary.hold != null`.
- Database bytes: main file plus `-wal` sibling when present (`p.join`-free: same path with suffix), 0 when unreadable.

- [ ] **Step 1: Write failing tests:** a `ProviderContainer` per case with the source providers overridden: `backup health follows backupSettings`; `sync health uses the active provider id`; `library health resolves the member role`; `media health counts only media setup items` (a sync-account sign-in item routed to `/settings/cloud-sync` does not count); `dataHealthProvider orders the four features`. Facts: in-memory `AppDatabase` with 2 dives, 1 personal site, 1 library site, 3 media rows gives `DataFacts(dives: 2, sites: 1, media: 3, ...)`; a temp DB file (via `Directory.systemTemp.createTemp`, cleaned in `addTearDown`) plus `-wal` sums both sizes.
- [ ] **Step 2:** Run. Expected: FAIL.
- [ ] **Step 3:** Implement. `now` is `DateTime.now()` inside the providers; tests pin time through the evaluator tests, so provider tests use ages far from any threshold.
- [ ] **Step 4:** Run. Expected: PASS.
- [ ] **Step 5:** Commit `feat(settings): data health and facts providers`.

### Task 6: Strip, attention lines, row mark and facts widgets

**Files:**
- Create: `lib/features/settings/presentation/widgets/data_health/health_symbol.dart`
- Create: `lib/features/settings/presentation/widgets/data_health/health_text.dart`
- Create: `lib/features/settings/presentation/widgets/data_health/data_health_strip.dart`
- Create: `lib/features/settings/presentation/widgets/data_health/data_facts_line.dart`
- Modify: `lib/l10n/arb/app_en.arb` (English only in this task)
- Test: `test/features/settings/presentation/widgets/data_health/data_health_strip_test.dart`, `health_symbol_test.dart`, `data_facts_line_test.dart`

**Interfaces:**
- Consumes: Task 1 types, Task 5 providers.
- Produces:
  - `HealthSymbol({required HealthLevel level, double size = 26, String? semanticLabel})`.
  - `String healthReasonText(AppLocalizations l10n, FeatureHealth h, DateTime now)`; `String healthLevelLabel(AppLocalizations, HealthLevel)`; `String dataFeatureLabel(AppLocalizations, DataFeature)`; `String relativeAgo(AppLocalizations, DateTime at, DateTime now)` built on the existing `backup_time_justNow/minutesAgo/hoursAgo/daysAgo` keys.
  - `DataHealthStrip()` (ConsumerWidget): the four items in a `Row` (`MainAxisAlignment.spaceBetween`) inside `ConstrainedBox(maxWidth: 480)`, each an `InkWell` to `/settings/backup`, `/settings/cloud-sync`, `/settings/shared-libraries`, `/settings/photos-media`, with semantics `"{feature}: {level}"`; below it one attention line per failing/attention feature, failing first, each tappable to the same route.
  - `DataFactsLine()` (ConsumerWidget): one `bodySmall` line in `onSurfaceVariant`, items joined with " · ", nothing while loading.
- New `app_en.arb` keys (group them under a `dataHealth_` prefix, next to `settings_data_*`): `dataHealth_feature_backup` "Backup", `dataHealth_feature_sync` "Sync", `dataHealth_feature_libraries` "Libraries", `dataHealth_feature_media` "Media", `dataHealth_level_healthy` "Healthy", `dataHealth_level_attention` "Needs attention", `dataHealth_level_failing` "Failing", `dataHealth_level_notSetUp` "Not set up", `dataHealth_semantics` "{feature}: {status}", `dataHealth_backup_autoOff` "Recommended: turn on automatic backups", `dataHealth_backup_failed` "Last backup failed {when}", `dataHealth_backup_overdue` "Backup overdue: last one {when}", `dataHealth_backup_never` "No backup yet", `dataHealth_backup_cloudCopyMissing` "Last backup did not reach the cloud", `dataHealth_backup_noOffDeviceCopy` "No copy off this device", `dataHealth_sync_off` "Recommended: turn on cloud sync", `dataHealth_sync_needsPassphrase` "Sync paused: enter your passphrase", `dataHealth_sync_awaitingAdoption` "Sync paused: the cloud library was replaced", `dataHealth_sync_signedOut` "Sync paused: sign in again", `dataHealth_sync_failed` "Last sync failed {when}", `dataHealth_sync_offline` "Offline: last synced {when}", `dataHealth_sync_conflicts` plural `{count, plural, one{{count} sync conflict to resolve} other{{count} sync conflicts to resolve}}`, `dataHealth_sync_peersHeld` "Another device needs attention before it can sync", `dataHealth_sync_autoOff` "Recommended: turn on automatic sync", `dataHealth_sync_neverSynced` "Not synced yet", `dataHealth_libraries_failed` "{name}: sync failed", `dataHealth_libraries_failedMany` plural `{count, plural, one{{count} library failed to sync} other{{count} libraries failed to sync}}`, `dataHealth_libraries_editsHeld` "{name}: your edits are on hold", `dataHealth_media_finishSetup` "Photos: finish setting up this device", `dataHealth_media_transfersPaused` "Photo transfers are paused", `dataHealth_facts_dives` plural "{count} dive(s)", `dataHealth_facts_sites` plural "{count} site(s)", `dataHealth_facts_media` plural "{count} photo(s) and video(s)", `dataHealth_sync_rowSubtitle` "Synced {when}", `dataHealth_sync_rowSubtitleDevices` "Synced {when} · {count} devices". Plural counts use `{"type": "int"}` and the CLDR `one` category, never `=1`.

- [ ] **Step 1: Write failing tests** (pump with `locale: Locale('en')` and l10n delegates; override `dataHealthProvider`/`dataFactsProvider`):
  - `strip shows four labelled items with semantics` (`find.bySemanticsLabel('Backup: Healthy')` etc.).
  - `attention lines list failing before attention` and `no attention lines when all healthy or not set up`.
  - `tapping an item and a line navigates to the feature route` (GoRouter with stub routes).
  - `health symbol uses status colours and the right glyph per level`, in light and dark themes built with `StatusColors.light/dark` extensions.
  - `strip fits a narrow phone at large text` (320 x 800 surface, `MediaQuery(textScaler: TextScaler.linear(2))`, `tester.takeException()` is null).
  - `facts line joins counts and size` gives `2 dives · 1 site · 3 photos and videos · 1.5 MB` (with `formatBytes` output).
- [ ] **Step 2:** Run. Expected: FAIL.
- [ ] **Step 3:** Add the ARB keys (surgical anchor insert, never a JSON round-trip of `app_en.arb`), run `flutter gen-l10n` to compile English, implement the widgets.
- [ ] **Step 4:** Run. Expected: PASS.
- [ ] **Step 5:** Commit `feat(settings): data health strip, attention lines and facts line`.

### Task 7: Flat Data page with row marks

**Files:**
- Create: `lib/features/settings/presentation/pages/data_section_content.dart` (moved `_DataSectionContent` and `_buildBackupSubtitle`, made public as `DataSectionContent`)
- Modify: `lib/features/settings/presentation/pages/settings_page.dart` (both `case 'data'` call sites, delete the moved code)
- Rename: `lib/features/settings/presentation/widgets/import_preferences_card.dart` to `import_preferences_group.dart`, class `ImportPreferencesGroup` with no `Card`; move its test likewise.
- Modify: `test/helpers/mock_providers.dart` (`getBaseOverrides`: override `dataHealthProvider` with four notSetUp entries and `dataFactsProvider` with zeros, so pages never reach real services)
- Modify: `test/features/settings/presentation/pages/settings_page_data_import_group_test.dart`
- Test: `test/features/settings/presentation/pages/data_section_content_test.dart`

**Interfaces:**
- Consumes: Task 6 widgets, Task 5 providers.
- Produces: `class DataSectionContent extends ConsumerStatefulWidget` that calls `backupSettingsProvider.notifier.reloadFromDisk()` and invalidates `dataFactsProvider` once in `initState` (post-frame).

Layout from the top: `DataHealthStrip`, `DataFactsLine`, `Divider`, then the four existing groups as header + plain `ListTile`s (no `Card`, no dividers between tiles), same order and routes. Row marks: `HealthSymbol(size: 16)` after the title text in a `Row(mainAxisSize: min)` for the four rows, omitted when notSetUp, with the same semantics label as the strip. Cloud Sync subtitle: `dataHealth_sync_rowSubtitleDevices` when `lastSync` is set and device count > 1, `dataHealth_sync_rowSubtitle` when set, else the existing generic subtitle.

- [ ] **Step 1: Before screenshots** of Settings > Data (phone light, phone dark, desktop light) via the `run` skill, saved to the scratchpad as `01-data-before.png`, `02-data-before-dark.png`, `03-data-before-desktop.png`. Do this before any Task 7 code change (stash nothing: Tasks 1 to 6 add no visible change).
- [ ] **Step 2: Write failing tests:** `the Data page has no Card`; `row marks match the strip` (backup healthy shows a 16 dp check beside "Backup & Restore"; photos notSetUp shows no mark); `sync row shows synced time and device count`; `the dashboard sits above the Backup & Sync header`. Update the import test: replace `nothing sits above the Backup & Sync header` with `only the dashboard sits above the Backup & Sync header` (texts above the header must be descendants of `DataHealthStrip` or `DataFactsLine`), and `the import options share one card` with `the import options share one group` (common `ImportPreferencesGroup` ancestor).
- [ ] **Step 3:** Run. Expected: FAIL.
- [ ] **Step 4:** Implement the move, rename and layout.
- [ ] **Step 5:** Run the new and updated tests, `flutter test test/features/settings test/architecture`. Expected: PASS.
- [ ] **Step 6:** Commit `feat(settings): flat Data page with health strip and row marks`.

### Task 8: Translations

**Files:**
- Modify: the ten locale ARBs `lib/l10n/arb/app_{ar,de,es,fr,he,hu,it,nl,pt,zh}.arb` and the regenerated `app_localizations_*.dart`.

- [ ] **Step 1:** Insert every Task 6 key into each locale ARB by anchor line (python, `json.loads` check after writing, no round-trip), matching each locale's existing terms for backup, sync, library and site.
- [ ] **Step 2:** `flutter gen-l10n`; expected no untranslated messages for `dataHealth_` keys. Spot-check `grep -A1 "get dataHealth_sync_off" lib/l10n/arb/app_localizations_de.dart` is German.
- [ ] **Step 3:** `git diff --numstat lib/l10n/arb/` rows equal across locales.
- [ ] **Step 4:** Commit `i18n(settings): translate the data health dashboard`.

### Task 9: Verify and capture

- [ ] **Step 1:** `dart format .`, `flutter analyze` (no issues), `flutter test test/features/settings test/features/backup test/core/services/sync test/architecture test/shared`.
- [ ] **Step 2: After screenshots** of the same three views plus one with an attention line showing (`04-data-after-attention.png`), named `<nn>-data-after[-dark|-desktop].png`; send them with SendUserFile.
- [ ] **Step 3:** Fix anything found, commit as `fix(settings): ...`.
