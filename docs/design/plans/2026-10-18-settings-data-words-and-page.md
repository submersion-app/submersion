# Settings > Data, PR 1: Words and the Data Page Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Apply the design's vocabulary to Settings > Data and the pages it names, regroup the Data page into "Your data" rows with one-sentence statuses and "Set up" buttons, and fold the rarely used rows under Advanced, with no behaviour change.

**Architecture:** A pure row-status model (`DataRowStatus`) sits beside the health evaluators and is fed by small providers that read the same inputs the health strip reads, so rows and strip cannot disagree. The Data page becomes two groups of `DataRowTile`s; the import controls and the four data tools move to two small pages of their own. Every renamed string gets a new ARB key in all eleven locales and the old key is removed once nothing reads it.

**Tech Stack:** Flutter, Riverpod (`flutter_riverpod`, provider style already used in `lib/features/settings/presentation/providers/`), go_router, Flutter gen-l10n with ARB files, `flutter_test` widget tests.

**Spec:** `docs/design/specs/2026-10-17-settings-data-setup-and-accounts-design.md`, sections 4 (vocabulary), 5 (the Data page), 11 (phase 1), appendix. This plan is phase 1 of seven; later phases get their own plans once this one is merged.

## Global Constraints

- Sentence case for every title, row and button the plan touches (design section 4).
- Every new string exists in all eleven ARB files under `lib/l10n/arb/` (`app_ar`, `app_de`, `app_en`, `app_es`, `app_fr`, `app_he`, `app_hu`, `app_it`, `app_nl`, `app_pt`, `app_zh`), inserted next to a neighbouring key of the same feature group in each file (the files are feature-grouped, not sorted). A string whose meaning changes gets a new key and the old key is deleted from all eleven files once `grep -rn "<key>" lib --include='*.dart' | grep -v lib/l10n/arb` finds nothing. A case-only change updates the English value in place and leaves other locales alone unless they copied the capitalisation.
- After any ARB edit run `flutter gen-l10n` and commit the regenerated `lib/l10n/arb/app_localizations*.dart` with the ARB change; the pre-push hook rejects stale generated files.
- No em dashes anywhere, including commit messages and the PR body. No attribution lines or tool names in commits or on GitHub.
- Files stay under 800 lines; `data_section_content.dart` must end this PR shorter than it starts.
- Tests that replace process-wide state restore it in `addTearDown`; run `test/architecture` and `test/shared` after adding any file under `lib/`.
- No behaviour change: every tap lands on the same page as today, every setting keeps its value, the health model is untouched except for two label strings.
- Every PR of this program links the tracking issue with `Refs #<issue>`; this one does not close it.

## Review Focus

Inputs the spec implies that no task's tests exercise unless added here. Each line's test is added to the owning task.

1. A custom database folder: the Sync row must read "Only on this device" with no "Set up" button, because sync cannot be turned on there (Task 1, `syncRowStatus` with `syncCustomFolder`).
2. The cloud copy is on but the last backup never reached the cloud: the Backups row must not claim "copy in Google Drive" (Task 1, `backupsRowStatus` with `backupCloudCopyMissing`).
3. A device whose only peer has no name: the Sync row must never render "In step with , 12m ago" (Task 3, blank peer names are dropped before counting).
4. Arabic and French plurals in the new count strings: zero and one must render the right category (Task 2, the existing `test/l10n/arabic_plural_categories_test.dart` and plural-category guard must pass over the new keys).
5. Large text on a 320 px wide phone: a row with a "Set up" button and a long subtitle must not overflow (Task 5, a widget test at `textScaleFactor` 1.6 and width 320 asserts no exception).

---

### Task 0: Record the starting point

**Files:**
- Commit (already written): `docs/design/specs/2026-10-17-settings-data-setup-and-accounts-design.md`, `docs/design/findings/2026-10-17-settings-data-inventory.md`, `docs/design/specs/assets/2026-10-17-settings-data-*.html`, `docs/design/plans/2026-10-18-settings-data-words-and-page.md`
- Create (throwaway, never committed): `test/features/settings/presentation/pages/tmp_data_shot_test.dart` and its `goldens/`

- [ ] **Step 1: Commit the design records**

```bash
git add docs/design/specs/2026-10-17-settings-data-setup-and-accounts-design.md docs/design/findings/2026-10-17-settings-data-inventory.md docs/design/specs/assets/2026-10-17-settings-data-directions-mockup.html docs/design/specs/assets/2026-10-17-settings-data-setup-walkthrough-mockup.html docs/design/specs/assets/2026-10-17-settings-data-pages-mockup.html docs/design/plans/2026-10-18-settings-data-words-and-page.md
git commit -m "docs(design): Settings > Data setup and accounts design, inventory and phase 1 plan"
```

- [ ] **Step 2: Open the tracking issue** (only after the maintainer has said to; the plan review covers this)

```bash
gh issue create --title "Settings > Data: one guided setup, one account model, plain words" --label enhancement --label "user interface" --body-file /dev/stdin <<'EOF'
**Is your feature request related to a problem? Please describe.**
Settings > Data is intimidating for divers who are not technical and inconsistent between features: five surfaces pick a cloud place in four different ways, the sync feature has six names, and three rules decide whether photo storage is set up. Setting up a second device means retyping what the first one already told the app.

**Describe the solution you'd like**
The design in docs/design/specs/2026-10-17-settings-data-setup-and-accounts-design.md: one re-runnable "Set up this device" flow (account, dives, backup, photos), Connected accounts as the one place to sign in with every feature page opening with the account it uses, and one vocabulary across the section. Nothing that exists today is removed; the inventory in docs/design/findings/2026-10-17-settings-data-inventory.md is the checklist.

Built in seven PRs, each mergeable on its own (design section 11): words and the Data page; accounts; backups; photos and videos; replace and join; set up this device; first run.

**Additional context**
Related: #3390, #3394, #3388, #3460, #2303, #1356.
EOF
```

Record the issue number; every commit message body and the PR body use `Refs #<issue>`.

- [ ] **Step 3: Capture the before screenshots**

Write `test/features/settings/presentation/pages/tmp_data_shot_test.dart` by copying `pumpData` from `data_section_content_test.dart` and adding four goldens with `matchesGoldenFile('goldens/<name>.png')` on `find.byType(SettingsPage)`: `01-data-before-phone.png` at `Size(412, 1600)` light, `02-data-before-phone-dark.png` the same size in dark, `03-data-before-desktop.png` at `Size(1280, 900)` light, and `04-data-before-attention.png` phone light with `dataHealth` carrying a failing backup (`HealthReason.backupFailed`, `when` three hours ago) and `HealthReason.syncAutoOff`. Pass `lastSync` twelve minutes ago, `devices: 3`, and override `peerDeviceNamesProvider` with three names. Theme: the app's default light and dark `ThemeData` if `lib/core/theme/` exposes them through one call (look in `app_theme_registry.dart`), otherwise `ThemeData(useMaterial3: true)` and `ThemeData.dark(useMaterial3: true)` with `themeMode` on the `MaterialApp.router`; use the same choice for the after images.

```bash
flutter test test/features/settings/presentation/pages/tmp_data_shot_test.dart --update-goldens
mkdir -p "$SCRATCHPAD/screenshots" && cp test/features/settings/presentation/pages/goldens/0*-data-before*.png "$SCRATCHPAD/screenshots/"
rm -rf test/features/settings/presentation/pages/tmp_data_shot_test.dart test/features/settings/presentation/pages/goldens
git status --porcelain
```

Expected: four PNGs in the scratchpad, a clean tree. Look at each image once; a blank or clipped image means the surface size is wrong, not that the page is empty.

---

### Task 1: The row status model

**Files:**
- Create: `lib/features/settings/domain/data_health/data_row_status.dart`
- Test: `test/features/settings/domain/data_health/data_row_status_test.dart`

**Interfaces:**
- Consumes: `FeatureHealth`, `HealthLevel`, `HealthReason`, `DataFeature` from `lib/features/settings/domain/data_health/feature_health.dart`.
- Produces:

```dart
enum DataRowStatusKind {
  backupsNever, backupsLocal, backupsCloud, backupsFolder, backupsFailed,
  syncOff, syncNever, syncAlone, syncWithOne, syncWithMany, syncPaused,
  photosOff, photosOn, photosAttention,
  librariesNone, librariesSome, librariesSomeNever, librariesAttention,
  accountsNone, accountsSignedIn, accountsNeedSignIn,
}

class DataRowStatus extends Equatable {
  const DataRowStatus(this.kind, {this.when, this.name, this.count, this.health, this.offersSetUp = false});
  final DataRowStatusKind kind;
  final DateTime? when;   // the time the text names
  final String? name;     // account label, device name, store hint, or joined account labels
  final int? count;       // devices, libraries or accounts
  final FeatureHealth? health; // set for the kinds whose text is the health reason
  final bool offersSetUp; // the row shows a trailing "Set up" button
}

DataRowStatus backupsRowStatus({required FeatureHealth health, required DateTime? lastBackup, required bool cloudCopyOn, required String? cloudAccountLabel, required bool customFolder});
DataRowStatus syncRowStatus({required FeatureHealth health, required DateTime? lastSync, required List<String> peerNames});
DataRowStatus photosRowStatus({required FeatureHealth health, required String? storeHint});
DataRowStatus librariesRowStatus({required FeatureHealth health, required int count, required DateTime? lastSync});
DataRowStatus accountsRowStatus({required List<String> signedInLabels, required int needSignIn});
```

Rules (design section 4, status lines), in evaluation order:

- `backupsRowStatus`: `health.reason == backupFailed` gives `backupsFailed(when: health.when)`; `lastBackup == null` gives `backupsNever`; `cloudCopyOn && health.reason != backupCloudCopyMissing` gives `backupsCloud(when: lastBackup, name: cloudAccountLabel ?? '')`; `customFolder` gives `backupsFolder(when: lastBackup)`; otherwise `backupsLocal(when: lastBackup)`. `offersSetUp` is `health.reason == backupAutoOff`.
- `syncRowStatus`: reason in {`syncNeedsPassphrase`, `syncAwaitingAdoption`, `syncSignedOut`, `syncFailed`} gives `syncPaused(health: health)`; `health.level == notSetUp` or `reason == syncOff` gives `syncOff`; `lastSync == null` gives `syncNever`; the names are filtered to non-blank first, then empty gives `syncAlone(when)`, one gives `syncWithOne(when, name)`, more gives `syncWithMany(when, count)`. `offersSetUp` is `reason == syncOff` only (never for `syncCustomFolder`).
- `photosRowStatus`: `health.level == notSetUp` gives `photosOff` with `offersSetUp: true`; `level == attention` gives `photosAttention(health)`; otherwise `photosOn(name: storeHint)`.
- `librariesRowStatus`: `count == 0` gives `librariesNone`; `level` attention or failing gives `librariesAttention(health, count)`; `lastSync == null` gives `librariesSomeNever(count)`; otherwise `librariesSome(count, when: lastSync)`.
- `accountsRowStatus`: `needSignIn > 0` gives `accountsNeedSignIn(count: needSignIn)`; empty labels give `accountsNone`; otherwise `accountsSignedIn(name: signedInLabels.join(', '))`.

- [ ] **Step 1: Write the failing tests**

One `group` per function; each case is one `test` asserting `kind`, and `when`, `name`, `count`, `offersSetUp` where the rule sets them. Cover every rule above plus these from Review Focus:

```dart
test('custom folder reads off and offers no set up', () {
  final s = syncRowStatus(
    health: const FeatureHealth(feature: DataFeature.sync, level: HealthLevel.notSetUp, reason: HealthReason.syncCustomFolder),
    lastSync: DateTime(2026, 10, 18, 9), peerNames: const ['Eric\'s iPhone']);
  expect((s.kind, s.offersSetUp), (DataRowStatusKind.syncOff, false));
});
test('a cloud copy that did not upload does not claim a copy', () {
  final s = backupsRowStatus(
    health: const FeatureHealth(feature: DataFeature.backup, level: HealthLevel.attention, reason: HealthReason.backupCloudCopyMissing),
    lastBackup: DateTime(2026, 10, 18, 6), cloudCopyOn: true, cloudAccountLabel: 'Google Drive', customFolder: false);
  expect(s.kind, DataRowStatusKind.backupsLocal);
});
test('blank peer names are not counted', () {
  final s = syncRowStatus(
    health: const FeatureHealth(feature: DataFeature.sync, level: HealthLevel.healthy, reason: HealthReason.ok),
    lastSync: DateTime(2026, 10, 18, 9), peerNames: const ['', ' ']);
  expect(s.kind, DataRowStatusKind.syncAlone);
});
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/features/settings/domain/data_health/data_row_status_test.dart`
Expected: compile failure, `data_row_status.dart` does not exist.

- [ ] **Step 3: Implement `data_row_status.dart`** with the enum, the class and the five functions as specified; no I/O, no l10n.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/features/settings/domain/data_health/data_row_status_test.dart`
Expected: all PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/settings/domain/data_health/data_row_status.dart test/features/settings/domain/data_health/data_row_status_test.dart
git commit -m "feat(settings): pure row status model for the Data page

Refs #<issue>"
```

---

### Task 2: Strings

**Files:**
- Modify: all eleven `lib/l10n/arb/app_*.arb`; regenerate `lib/l10n/arb/app_localizations*.dart`
- Test: existing `test/l10n/arb_parity_test.dart`, `test/l10n/arb_no_duplicate_keys_test.dart`, `test/l10n/arabic_plural_categories_test.dart`, `test/l10n/localization_test.dart`

**Interfaces:**
- Produces the keys below, used by Tasks 3 to 7 exactly under these names.

New keys, English values, inserted after `dataHealth_sync_rowSubtitleDevices` in every file (the Data health group), with `@` metadata declaring each placeholder type (`String` for `when`, `account`, `device`, `store`, `accounts`; `int` for `count`):

| Key | English |
| --- | --- |
| `settings_data_header_yourData` | Your data |
| `settings_data_header_advanced` | Advanced |
| `settings_data_setUp` | Set up |
| `settings_data_importOptions` | Import options |
| `settings_data_importOptions_subtitle` | Site matching, surfacing pressure, auto tags |
| `settings_data_dataTools` | Data tools |
| `settings_data_dataTools_subtitle` | Fix dive times, link buddies, retype gear, data quality |
| `settings_sync_title` | Sync between devices |
| `settings_backups_title` | Backups |
| `settings_photosVideos_title` | Photos & videos |
| `settings_section_data_tagline` | Backups, sync and photos |
| `dataHealth_feature_photos` | Photos |
| `settings_data_backups_status_never` | Not backed up yet |
| `settings_data_backups_status_local` | Backed up {when}, on this device only |
| `settings_data_backups_status_cloud` | Backed up {when}, copy in {account} |
| `settings_data_backups_status_folder` | Backed up {when}, copy in your backup folder |
| `settings_data_sync_status_off` | Only on this device |
| `settings_data_sync_status_alone` | Synced {when}, only this device so far |
| `settings_data_sync_status_one` | In step with {device}, {when} |
| `settings_data_sync_status_many` | {count, plural, one{In step with {count} device, {when}} other{In step with {count} devices, {when}}} |
| `settings_data_photos_status_off` | Copies are not kept in the cloud |
| `settings_data_photos_status_on` | Copies kept in {store} |
| `settings_data_photos_status_onUnknown` | Copies kept in the cloud |
| `settings_data_libraries_status_none` | None joined |
| `settings_data_libraries_status_some` | {count, plural, one{{count} library, last sync {when}} other{{count} libraries, last sync {when}}} |
| `settings_data_libraries_status_someNever` | {count, plural, one{{count} library, not synced yet} other{{count} libraries, not synced yet}} |
| `settings_data_accounts_status_none` | None yet |
| `settings_data_accounts_status_signedIn` | {accounts}, signed in |
| `settings_data_accounts_status_needSignIn` | {count, plural, one{{count} account needs sign-in} other{{count} accounts need sign-in}} |

Value updates in place, all eleven files re-translated where the words change:

| Key | New English |
| --- | --- |
| `dataHealth_feature_backup` | Backups |
| `sharedLibrary_settings_title` | Shared site libraries (case only) |
| `settings_connectedAccounts_title` | Connected accounts (case only) |
| `settings_data_databaseStorage` | Database storage (case only) |
| `settings_data_offlineMaps` | Offline maps (case only) |
| `connections_empty_buddies` | ... convert legacy buddy names under Settings > Data > Advanced > Data tools. |
| `settings_cloudSync_firstSync_replaceHint` | ... cancel and use Settings > Data > Sync between devices > Replace cloud library. |
| `settings_storage_customFolder_deviceOnly_noCloudSync` | ... so use Backups to keep copies elsewhere. |
| `settings_storage_resetDialog_body` | ... you can reconnect it under Settings > Data > Sync between devices. |
| `settings_storage_resetComplete_description` | ... you can reconnect it under Settings > Data > Sync between devices. Tap continue to reload the app. |
| `transfer_export_aboutContent` | ... from Settings > Data > Backups. |
| `transfer_export_backupLink` | Go to Backups |
| `db_location_backup_note` | ... set a backup folder under Backups. |
| `settings_mediaStorage_connect_dropbox_hint` | Uses your Dropbox connection from Sync between devices. Media is stored in your Dropbox app folder. |
| `startup_interruptedRestore_recoverNote` | ... You can restore or delete it later under Settings > Data > Backups. |
| `startup_interruptedRestore_keepNote` | ... You can restore or delete it later under Settings > Data > Backups. |

Keys to delete in Task 7 once nothing reads them: `settings_data_backup`, `settings_data_backup_subtitle`, `settings_cloudSync_appBar_title`, `settings_cloudSync_entry_subtitle`, `settings_photosMedia_title`, `settings_photosMedia_subtitle`, `backup_appBar_title`, `settings_data_header_backupSync`, `settings_data_header_storage`, `settings_data_header_import`, `settings_data_header_dataTools`, `dataHealth_feature_media`, `dataHealth_sync_rowSubtitle`, `dataHealth_sync_rowSubtitleDevices`, `sharedLibrary_settings_subtitle`, `settings_connectedAccounts_subtitle`. Any of these still read by a page outside this plan's scope stays.

- [ ] **Step 1: Add the new keys and the value updates to `app_en.arb`**, then to each of the ten other files with that locale's translation of the same string, keeping each file's own group placement.

- [ ] **Step 2: Regenerate and run the l10n suite**

Run: `flutter gen-l10n && flutter test test/l10n`
Expected: all PASS (parity, no duplicates, plural categories, diacritics).

- [ ] **Step 3: Commit**

```bash
git add lib/l10n/arb
git commit -m "feat(l10n): strings for the Data page vocabulary pass

Refs #<issue>"
```

---

### Task 3: Row status providers

**Files:**
- Create: `lib/features/settings/presentation/providers/data_row_status_providers.dart`
- Create: `lib/features/settings/presentation/widgets/data_health/data_row_status_text.dart`
- Test: `test/features/settings/presentation/providers/data_row_status_providers_test.dart`, `test/features/settings/presentation/widgets/data_health/data_row_status_text_test.dart`

**Interfaces:**
- Consumes: `backupHealthProvider`, `syncHealthProvider`, `sharedLibrariesHealthProvider`, `mediaHealthProvider`, `mediaHealthInputsProvider` (`lib/features/settings/presentation/providers/data_health_providers.dart`); `backupSettingsProvider` and `lastBackupTimeProvider` (`lib/features/backup/presentation/providers/backup_providers.dart`); `lastSyncTimeProvider` and `peerDeviceNamesProvider` (`sync_providers.dart`); `connectedAccountsRepositoryProvider` with `getSyncAccountId()` and `getById`; `mediaStoreAttachStateProvider` and `mediaStoresRepositoryProvider.getActive()` (never `mediaStoreRuntimeProvider`, which would build the media runtime on the Settings page); `sharedLibrariesProvider`; `connectedAccountsWithStatusProvider` and `AccountStatus` (`connected_accounts_page.dart`, `account_provider_adapter.dart`); `relativeAgo` and `healthReasonText` from `health_text.dart`.
- Produces:

```dart
final syncAccountLabelProvider = FutureProvider.autoDispose<String?>  // label of the roster row getSyncAccountId() names, a pure read with no side effect
final attachedStoreHintProvider = FutureProvider.autoDispose<String?>  // getActive()?.displayHint when attachedStoreId() is non-null, else null
final backupsRowStatusProvider = Provider.autoDispose<DataRowStatus>
final syncRowStatusProvider = Provider.autoDispose<DataRowStatus>
final photosRowStatusProvider = Provider.autoDispose<DataRowStatus>
final librariesRowStatusProvider = Provider.autoDispose<DataRowStatus>
final accountsRowStatusProvider = Provider.autoDispose<DataRowStatus>

String dataRowStatusText(AppLocalizations l10n, DataRowStatus status, DateTime now);
```

`dataRowStatusText` maps kinds to the Task 2 keys; `backupsFailed` uses `dataHealth_backup_failed(relativeAgo(...))`, `syncNever` uses `dataHealth_sync_neverSynced`, `syncPaused`, `photosAttention` and `librariesAttention` return `healthReasonText(l10n, status.health!, now)`; `photosOn` with an empty or null name uses `settings_data_photos_status_onUnknown`. Async inputs that have not loaded count as absent (`null`, empty list, zero), never as an error. `connectedAccountsWithStatusProvider` is declared in a page file today; if an architecture guard rejects importing it from a providers file, move it unchanged into a new `lib/features/settings/presentation/providers/connected_accounts_providers.dart` and import that from both places.

- [ ] **Step 1: Write the failing text tests**

```dart
testWidgets('renders each kind in English', ...) // pump a MaterialApp with the delegates, read AppLocalizations.of(context)
// asserts, with now = 2026-10-18 12:00 and when = 11:48:
// backupsCloud(name: 'Google Drive') -> 'Backed up 12m ago, copy in Google Drive'
// syncWithOne(name: "Eric's iPhone") -> "In step with Eric's iPhone, 12m ago"
// syncWithMany(count: 3) -> 'In step with 3 devices, 12m ago'
// photosOn(name: '') -> 'Copies kept in the cloud'
// librariesSome(count: 1) -> '1 library, last sync 12m ago'
// accountsNeedSignIn(count: 2) -> '2 accounts need sign-in'
// syncPaused(health: needsPassphrase) -> same string as healthReasonText for that health
```

- [ ] **Step 2: Write the failing provider tests**

Use a `ProviderContainer` with overrides for the consumed providers (the shared fakes in `test/helpers/mock_providers.dart` already override the health list; override `lastSyncTimeProvider`, `peerDeviceNamesProvider`, `lastBackupTimeProvider`, `backupSettingsProvider`, `sharedLibrariesProvider`, `connectedAccountsWithStatusProvider` directly):

```dart
test('sync row names the single peer', ...)      // peer map {'id-1': "Eric's iPhone"}, lastSync set, healthy -> syncWithOne, name "Eric's iPhone"
test('backups row names the sync account', ...)  // cloudBackupEnabled true, syncAccountLabelProvider overridden to 'Google Drive' -> backupsCloud, name 'Google Drive'
test('photos row never builds the media runtime', ...) // override mediaStoreRuntimeProvider with overrideWith((ref) { built = true; return Future.value(null); }); read photosRowStatusProvider; expect(built, isFalse) and the kind photosOff for notSetUp health
test('sync row with the peer stream', ...)       // peerDeviceNamesProvider.overrideWith((ref) => Stream.value({'id-1': "Eric's iPhone"})) is how peers are supplied in every test of this plan
test('accounts row counts sign-ins needed', ...) // two accounts, one needsSignIn -> accountsNeedSignIn count 1
```

- [ ] **Step 3: Run both files to verify they fail**

Run: `flutter test test/features/settings/presentation/providers/data_row_status_providers_test.dart test/features/settings/presentation/widgets/data_health/data_row_status_text_test.dart`
Expected: compile failures on the missing files.

- [ ] **Step 4: Implement the two files** per the interfaces. The five status providers call the Task 1 functions with inputs read through `ref.watch(...).value` or `.valueOrNull` for async providers.

- [ ] **Step 5: Run the tests to verify they pass**

Run: the same command.
Expected: all PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/features/settings/presentation/providers/data_row_status_providers.dart lib/features/settings/presentation/widgets/data_health/data_row_status_text.dart test/features/settings/presentation/providers/data_row_status_providers_test.dart test/features/settings/presentation/widgets/data_health/data_row_status_text_test.dart
git commit -m "feat(settings): row status providers and text for the Data page

Refs #<issue>"
```

---

### Task 4: Import options and Data tools pages

**Files:**
- Create: `lib/features/settings/presentation/pages/import_options_page.dart`, `lib/features/settings/presentation/pages/data_tools_page.dart`
- Modify: `lib/core/router/app_router.dart` (the `/settings` children, next to `path: 'storage'` at about line 1355)
- Modify: `lib/features/settings/presentation/widgets/import_preferences_group.dart` (drop the zero `contentPadding` theme, the group now sits on a padded page)
- Test: `test/features/settings/presentation/pages/import_options_page_test.dart`, `test/features/settings/presentation/pages/data_tools_page_test.dart`; move the import cases out of `test/features/settings/presentation/pages/settings_page_data_import_group_test.dart`; update `test/features/settings/presentation/widgets/import_preferences_group_test.dart` where it asserts the zero inset or the Import card

**Interfaces:**
- Produces: `class ImportOptionsPage extends StatelessWidget` at route `/settings/import-options` (name `importOptions`), app bar `settings_data_importOptions`, body a `ListView` with 16 px padding holding `ImportPreferencesGroup`. `class DataToolsPage extends StatelessWidget` at `/settings/data-tools` (name `dataTools`), app bar `settings_data_dataTools`, body the four rows now in `data_section_content.dart:181-205` with their icons, titles, subtitles and routes unchanged.

- [ ] **Step 1: Write the failing tests**

`import_options_page_test.dart`, using `testApp` from `test/helpers/test_app.dart` with `getBaseOverrides()`:

```dart
testWidgets('shows the three import controls', ...)   // finds settings_siteMatch_title, settings_tankPressureAtSurfacing_title, settings_autoTagImports_title texts, app bar 'Import options'
testWidgets('choosing a site matching level records the preference', ...) // port the case of the same name from settings_page_data_import_group_test.dart
```

`data_tools_page_test.dart`:

```dart
testWidgets('lists the four tools and pushes their routes', ...) // taps 'Fix Dive Times' and expects the GoRouter location '/settings/fix-dive-times'; asserts the other three titles are present
```

- [ ] **Step 2: Run them to verify they fail**

Run: `flutter test test/features/settings/presentation/pages/import_options_page_test.dart test/features/settings/presentation/pages/data_tools_page_test.dart`
Expected: compile failures on the missing pages.

- [ ] **Step 3: Create both pages and register both routes** in `app_router.dart` with `name:` values `importOptions` and `dataTools`, following the `storage` route's shape.

- [ ] **Step 4: Run the new tests and the router tests**

Run: `flutter test test/features/settings/presentation/pages/import_options_page_test.dart test/features/settings/presentation/pages/data_tools_page_test.dart test/core/router`
Expected: all PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/settings/presentation/pages/import_options_page.dart lib/features/settings/presentation/pages/data_tools_page.dart lib/core/router/app_router.dart lib/features/settings/presentation/widgets/import_preferences_group.dart test/features/settings/presentation/pages/import_options_page_test.dart test/features/settings/presentation/pages/data_tools_page_test.dart
git commit -m "feat(settings): Import options and Data tools pages

Refs #<issue>"
```

---

### Task 5: The Data page

**Files:**
- Create: `lib/features/settings/presentation/widgets/data_row_tile.dart`
- Modify: `lib/features/settings/presentation/pages/data_section_content.dart`
- Modify: `lib/features/settings/presentation/widgets/data_health/health_text.dart` (`dataFeatureLabel`: backup now `dataHealth_feature_backup` reads "Backups", media uses `dataHealth_feature_photos`)
- Test: `test/features/settings/presentation/pages/data_section_content_test.dart`, `test/features/settings/presentation/widgets/data_health/data_health_strip_test.dart`, `test/features/settings/presentation/widgets/data_row_tile_test.dart`; delete `test/features/settings/presentation/pages/settings_page_data_import_group_test.dart` once Task 4 holds its surviving cases

**Interfaces:**
- Consumes: the five status providers and `dataRowStatusText` (Task 3), `HealthSymbol` and `healthSemanticsLabel` (existing), `dataHealthProvider`.
- Produces:

```dart
class DataRowTile extends StatelessWidget {
  const DataRowTile({required this.icon, required this.title, required this.subtitle, required this.route, this.health, this.offersSetUp = false, this.setUpRoute});
  // leading icon; title with the 16 dp HealthSymbol when health is non-null and not notSetUp (as today's featureTitle);
  // subtitle text; trailing: FilledButton.tonal(settings_data_setUp) opening setUpRoute ?? route when offersSetUp, else the chevron.
  // The whole tile still pushes route.
}
```

Page order (design section 5): strip, attention lines, facts line, divider, header `settings_data_header_yourData`, rows Backups (`settings_backups_title`, route `/settings/backup`), Sync between devices (`settings_sync_title`, `/settings/cloud-sync`), Photos & videos (`settings_photosVideos_title`, `/settings/photos-media`), Shared site libraries (`sharedLibrary_settings_title`, `/settings/shared-libraries`), Connected accounts (`settings_connectedAccounts_title`, `/settings/connected-accounts`); header `settings_data_header_advanced`, rows Database storage (`/settings/storage`, subtitle as today), Offline maps (`/settings/offline-maps`, subtitle as today), Import options (`/settings/import-options`, `settings_data_importOptions_subtitle`), Data tools (`/settings/data-tools`, `settings_data_dataTools_subtitle`). The lifecycle reload in `initState`, `_reloadBackup` and `_onResume` stays exactly as it is. In this PR `setUpRoute` is the feature's own route.

- [ ] **Step 1: Rewrite the failing page tests**

In `data_section_content_test.dart` rename the title finders ('Backup & Restore' to 'Backups', 'Database Cloud Sync' to 'Sync between devices', 'Shared Site Libraries' to 'Shared site libraries', 'Photos & Media' to 'Photos & videos', the 'Backup & Sync' header to 'Your data') and replace the two sync subtitle tests with:

```dart
testWidgets('sync row names the peers', ...)        // lastSync 12 minutes ago, devices 3 -> 'In step with 3 devices, 12m ago' when peerDeviceNamesProvider has three names; with one name -> "In step with Eric's iPhone, 12m ago"
testWidgets('sync row reads off with no provider', ...) // health syncOff -> 'Only on this device' and a 'Set up' button beside it
testWidgets('photos row offers set up when not kept', ...) // media notSetUp -> 'Copies are not kept in the cloud' and 'Set up'
testWidgets('advanced rows push their pages', ...)  // taps 'Import options' and 'Data tools', expects '/settings/import-options' and '/settings/data-tools'
testWidgets('tool rows and import controls left the page', ...) // find.text('Fix Dive Times') and find.text(settings_siteMatch_title) are absent
testWidgets('only the dashboard sits above the Your data header', ...) // port of the same-named case from settings_page_data_import_group_test.dart
testWidgets('a long subtitle with a Set up button fits a 320 px phone at large text', ...) // surface 320x1600, MediaQuery textScaler 1.6, pump, expect(tester.takeException(), isNull)
```

In `data_health_strip_test.dart` change the expected labels to 'Backups', 'Sync', 'Libraries', 'Photos' and the semantics to 'Photos: Not set up'.

Add `data_row_tile_test.dart`: the mark is absent for `notSetUp` health, present at size 16 otherwise; `offersSetUp` renders the button and tapping it pushes `setUpRoute`.

- [ ] **Step 2: Run the three files to verify they fail**

Run: `flutter test test/features/settings/presentation/pages/data_section_content_test.dart test/features/settings/presentation/widgets/data_health/data_health_strip_test.dart test/features/settings/presentation/widgets/data_row_tile_test.dart`
Expected: FAIL on the new titles, the new subtitles and the missing widget.

- [ ] **Step 3: Implement `DataRowTile`, rewrite `data_section_content.dart` to the page order above, and update `dataFeatureLabel`.** Remove the import group and the four tool rows from the page, and the now-unused `_backupSubtitle` and `_syncSubtitle`.

- [ ] **Step 4: Run the settings suite**

Run: `flutter test test/features/settings test/l10n test/architecture test/shared`
Expected: all PASS; `wc -l lib/features/settings/presentation/pages/data_section_content.dart` is below 247.

- [ ] **Step 5: Commit**

```bash
git rm test/features/settings/presentation/pages/settings_page_data_import_group_test.dart
git add lib/features/settings/presentation/widgets/data_row_tile.dart lib/features/settings/presentation/pages/data_section_content.dart lib/features/settings/presentation/widgets/data_health/health_text.dart test/features/settings/presentation/pages/data_section_content_test.dart test/features/settings/presentation/widgets/data_health/data_health_strip_test.dart test/features/settings/presentation/widgets/data_row_tile_test.dart
git commit -m "feat(settings): Your data rows with statuses, Set up buttons and an Advanced fold

Refs #<issue>"
```

---

### Task 6: Page titles, the Settings root and navigation hints

**Files:**
- Modify: `lib/features/settings/presentation/pages/cloud_sync_page.dart:119` (`settings_sync_title`), `lib/features/backup/presentation/pages/backup_settings_page.dart:48` (`settings_backups_title`), `lib/features/settings/presentation/pages/photos_media_hub_page.dart:24` (`settings_photosVideos_title`), `lib/shared/widgets/nav/nav_shortcuts.dart:372` (`settings_backups_title`)
- Modify: `lib/features/settings/presentation/widgets/settings_list_content.dart:57` (fallback `'Backups, sync and photos'`) and `:338`, `lib/features/settings/presentation/pages/settings_page.dart:440` (both read `settings_section_data_tagline`)
- Modify: any other `.dart` file still reading a key from Task 2's deletion list, found with the grep in Global Constraints
- Test: the files that assert the old titles: `test/features/settings/presentation/pages/cloud_sync_page_test.dart`, `test/features/settings/photos_media_hub_test.dart`, `test/features/settings/presentation/pages/settings_page_connected_accounts_test.dart`, `test/features/settings/presentation/pages/connected_accounts_page_test.dart`, `test/core/router/nav_shortcut_pages_test.dart`, and any other hit of `grep -rln "Database Cloud Sync\|Backup & Restore\|Photos & Media\|Connected Accounts\|Shared Site Libraries\|Backup, restore & storage" test`

- [ ] **Step 1: Update the test expectations** to 'Sync between devices', 'Backups', 'Photos & videos', 'Connected accounts', 'Shared site libraries' and 'Backups, sync and photos'.

- [ ] **Step 2: Run them to verify they fail**

Run: `flutter test <the listed test files>`
Expected: FAIL on the old titles.

- [ ] **Step 3: Switch the app bars, the shortcut label and the root subtitle to the new keys.**

- [ ] **Step 4: Run them to verify they pass**

Run: the same command plus `flutter test test/features/settings test/features/backup test/core/router`
Expected: all PASS.

- [ ] **Step 5: Commit**

```bash
git add -u
git commit -m "feat(settings): sentence-case page titles and the Data tagline

Refs #<issue>"
```

---

### Task 7: Remove the orphaned keys

**Files:**
- Modify: all eleven ARB files; regenerate the localizations

- [ ] **Step 1: For each key in Task 2's deletion list, confirm it is unread**

Run: `for k in settings_data_backup settings_data_backup_subtitle settings_cloudSync_appBar_title settings_cloudSync_entry_subtitle settings_photosMedia_title settings_photosMedia_subtitle backup_appBar_title settings_data_header_backupSync settings_data_header_storage settings_data_header_import settings_data_header_dataTools dataHealth_feature_media dataHealth_sync_rowSubtitle dataHealth_sync_rowSubtitleDevices sharedLibrary_settings_subtitle settings_connectedAccounts_subtitle; do echo "== $k"; grep -rn "\b$k\b" lib test --include='*.dart' | grep -v lib/l10n/arb; done`
Expected: no lines under a key means it can go; a key with hits stays and is noted in the PR body.

- [ ] **Step 2: Delete the unread keys and their `@` entries from all eleven files, regenerate, run the l10n suite and the orphan guard**

Run: `flutter gen-l10n && flutter test test/l10n test/architecture`
Expected: all PASS.

- [ ] **Step 3: Commit**

```bash
git add lib/l10n/arb
git commit -m "chore(l10n): drop the Data page strings nothing reads

Refs #<issue>"
```

---

### Task 8: User docs

**Files:**
- Modify: `docs/user/settings.md`, `docs/user/backup-and-restore.md`, `docs/user/multi-device-sync.md`, `docs/user/media-sync.md`, `docs/user/shared-site-libraries.md`, `docs/user/data-quality-assistant.md`, `docs/user/import-export.md`, `docs/user/marine-life-and-photos.md`, `docs/user/encrypted-sync.md`, `docs/user/_sidebar.md`

- [ ] **Step 1: Rename the pages in the user guide**

Replace the navigation names only: "Backup & Restore" becomes "Backups", "Database Cloud Sync" and "Cloud Sync" (as a page name) become "Sync between devices", "Photos & Media" becomes "Photos & videos", "Connected Accounts" becomes "Connected accounts", "Shared Site Libraries" becomes "Shared site libraries", "Data Tools" becomes "Advanced > Data tools", and the import options are reached under "Settings > Data > Advanced > Import options". Rewrite the Settings > Data section of `docs/user/settings.md` to list the two groups, Your data and Advanced, and the one-sentence statuses. Leave feature behaviour text alone.

- [ ] **Step 2: Check the links**

Run: `python3.14 scripts/check_docs_links.py`
Expected: every line `ok`.

- [ ] **Step 3: Commit**

```bash
git add docs/user
git commit -m "docs(user): Settings > Data names after the vocabulary pass

Refs #<issue>"
```

---

### Task 9: Full checks, after screenshots and the PR

- [ ] **Step 1: Format, analyze, test**

```bash
dart format . && flutter analyze
flutter test test/features/settings test/features/backup test/features/media_store test/core/router test/l10n test/architecture test/shared
```

Expected: formatted with no diff, no analyzer issues, all PASS. Log long runs to the scratchpad and read the tail.

- [ ] **Step 2: After screenshots**

Recreate the throwaway golden test from Task 0 Step 3 unchanged (same four cases), run it with `--update-goldens`, copy the PNGs to `$SCRATCHPAD/screenshots/` as `01-data-after-phone.png`, `02-data-after-phone-dark.png`, `03-data-after-desktop.png`, `04-data-after-attention.png`, delete the test and its goldens, confirm `git status --porcelain` is clean. Look at every image: the after images must show "Your data", the five rows with one-sentence statuses, a "Set up" button on Photos & videos, and the Advanced group. Send the eight images in one `SendUserFile` call with `display: attach`.

- [ ] **Step 3: Push and open the PR**

Branch: the worktree's `ericgriffin/settings-data-ui-simplify-4353be`. PR title: `Settings > Data: plain words, Your data rows and an Advanced fold`. Body from `.github/PULL_REQUEST_TEMPLATE.md` with `Refs #<issue>` under Related Issue, a Summary that names the design document and says this is phase 1 of 7 with no behaviour change, a Changes list per task, a Test Plan with the commands of Step 1 ticked, and a Screenshots section listing the eight images for the maintainer to drag in. Do not tick "No visible UI change".

```bash
git push -u origin ericgriffin/settings-data-ui-simplify-4353be
gh pr create --title "Settings > Data: plain words, Your data rows and an Advanced fold" --body-file "$SCRATCHPAD/pr-body.md"
```

Expected: the PR Issue Link check passes on `Refs #<issue>`; CI green.
