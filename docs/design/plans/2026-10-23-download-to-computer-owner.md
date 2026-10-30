# Downloads Follow the Computer's Owner Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A dive computer download defaults to the profile that owns the
computer, with a per-download profile picker on the review step and a switch
under Settings > Data > Import options.

**Architecture:** `DiveComputerAdapter` keeps the active diver it was built
with and gains a chosen (target) diver that every diver-dependent import step
reads. The bundle it builds carries an `ImportTargetChoice` when the owner
differs from the active profile; the review step renders a notice and dropdown
from it and asks the wizard notifier to retarget, which rebuilds and re-checks
the bundle. The import service's default-tank and transmitter loaders take the
target diver instead of reading the active profile.

**Tech Stack:** Flutter, Riverpod, Drift (SQLite), ARB localisation.

**Spec:** `docs/design/specs/2026-10-23-download-to-computer-owner-design.md`

## Global Constraints

- The switch is on by default (`true`), stored per diver in `diver_settings`.
- A profile picked on the review step applies to that download only; the
  computer's `diver_id` never changes.
- With the switch off the computer is still recognised (no duplicate record);
  only the picker's starting profile changes.
- The notice and picker appear only when the computer's owner exists, is not
  null, and differs from the active profile.
- Units, cylinder pressure at surfacing, site-match sensitivity and the
  auto-tag on/off come from the active profile; everything else diver-related
  follows the chosen profile, including the default tank.
- Every new string goes into all 11 ARB files (feature-grouped: insert beside
  a neighbouring key of the same group), then `flutter gen-l10n`.
- No em dashes anywhere. No file over 800 lines: new adapter logic goes in a
  new part file.
- Schema version: the next free one when the PR lands (309 at plan time;
  re-check open PRs before pushing).

## Review Focus

1. A library where the old behaviour already registered the same computer
   under two profiles: the active profile's copy must win, so no notice
   appears and nothing is filed under the stale copy. (Task 3 test.)
2. A computer whose owner was deleted, or with a null owner: no notice, dives
   go to the active profile. (Task 3 test.)
3. An unscoped library (active diver id empty): lookups stay global as today,
   no notice, no `diverOutcomes`. (Task 3 test.)
4. Changing the profile on the review step after editing row choices: the
   bundle is re-checked for the new diver and the per-row choices reset to
   that diver's defaults rather than keeping matches against the old diver's
   dives. (Task 5 test.)
5. Switch off with a differing owner: the notice names the active profile as
   the destination and the dropdown starts on it. (Task 5 widget test.)

---

### Task 1: The setting

**Files:**
- Modify: `lib/core/database/tables/diver_tables.dart` (beside `autoTagImports`)
- Create: `lib/core/database/migrations/helpers/download_owner_migrations.dart`
- Modify: `lib/core/database/migrations/app_database_migrations.dart` (part directive)
- Modify: `lib/core/database/migrations/ladder/rungs_v231_onward.dart` (rung)
- Modify: `lib/core/database/migrations/before_open.dart` (backstop call)
- Modify: `lib/core/database/database.dart` (`currentSchemaVersion`)
- Modify: `lib/features/settings/presentation/providers/settings_providers.dart`
- Modify: `lib/features/settings/data/repositories/diver_settings_repository.dart` (all three mapping sites)
- Modify: `lib/core/services/sync/sync_data_serializer.dart` (`_applyDiverSettingDefaults`)
- Modify: `lib/features/settings/presentation/conflicts/catalogue/diver_settings_fields.dart`
- Modify: `lib/features/settings/presentation/widgets/import_preferences_group.dart`
- Modify: `lib/l10n/arb/app_*.arb` (11 files)
- Test: `test/core/database/migration_v310_download_owner_test.dart` (shipped
  as v310: #3605 took 309 first)
- Test: `test/features/settings/data/repositories/diver_settings_repository_download_owner_test.dart`
- Test: `test/features/settings/presentation/widgets/import_preferences_group_download_owner_test.dart`

**Interfaces:**
- Produces: column `diver_settings.downloads_follow_computer_owner`
  (`BoolColumn get downloadsFollowComputerOwner => boolean().withDefault(const Constant(true))()`);
  `AppSettings.downloadsFollowComputerOwner` (bool, default `true`, in
  `copyWith`); `SettingsNotifier.setDownloadsFollowComputerOwner(bool value)`.
- Produces l10n keys: `settings_downloadsFollowOwner_title` = "Add downloads
  to the computer's owner"; `settings_downloadsFollowOwner_subtitle` = "When a
  dive computer belongs to another profile, its dives go to that profile's
  log. You can change it on the review screen.";
  `settings_conflict_field_downloadsFollowComputerOwner` = "Add downloads to
  the computer's owner".

- [ ] **Step 1: Write failing tests.** Migration test: a database created at
  the previous version gains the column with value 1 for an existing row, and
  re-running the backstop is a no-op (copy the shape of the newest
  `migration_v3xx_*_test.dart`). Repository test: `updateSettingsForDiver`
  with `downloadsFollowComputerOwner: false` reads back `false`; a fresh diver
  reads `true`. Widget test: the switch renders on, tapping it calls
  `setDownloadsFollowComputerOwner(false)` (use the existing
  `ImportPreferencesGroup` tests' harness).
- [ ] **Step 2: Run them and see them fail** (`flutter test <the three files>`).
- [ ] **Step 3: Implement.** Helper
  `Future<void> _assertDownloadOwnerColumn()` using `_addColumnIfMissing(
  'diver_settings', 'downloads_follow_computer_owner', 'INTEGER NOT NULL
  DEFAULT 1 CHECK (downloads_follow_computer_owner IN (0, 1))')`; rung
  `if (from < 309)` plus `reportProgress()`; beforeOpen backstop call; bump
  `currentSchemaVersion`; serializer default `'downloadsFollowComputerOwner':
  true`; conflict catalogue entry; switch (icon `Icons.person_pin_outlined`)
  as the last tile in `ImportPreferencesGroup`; ARB keys in all locales;
  `dart run build_runner build --delete-conflicting-outputs` and
  `flutter gen-l10n`.
- [ ] **Step 4: Run the tests and see them pass**, plus `test/core/database`
  and `test/core/services/sync`.
- [ ] **Step 5: Commit** `feat(settings): switch for adding downloads to the computer's owner`.

### Task 2: Import loaders take the target diver

**Files:**
- Modify: `lib/features/dive_computer/data/services/dive_import_service.dart:255-330, 368-369, 846-847, 1027-1028`
- Modify: `lib/features/dive_computer/presentation/providers/download_providers.dart:40-64`
- Modify: `lib/features/transmitters/presentation/providers/transmitter_providers.dart:17-23`
- Test: `test/features/dive_computer/presentation/providers/download_default_tank_preset_test.dart`
- Test: `test/features/dive_computer/presentation/providers/download_transmitter_matcher_test.dart`
- Test: `test/features/dive_computer/data/services/dive_import_service_test.dart`

**Interfaces:**
- Produces: `typedef DefaultTankPresetLoader = Future<TankPresetEntity?> Function(String? diverId);`
  and `typedef ImportTransmitterMatcherLoader = Future<TransmitterMatcher> Function(String? diverId);`
  in `dive_import_service.dart` (the service's `transmitterMatcherForImports`
  takes the latter; `TransmitterMatcherLoader` stays as is for reparse).
- Produces: `Future<TransmitterMatcher> loadTransmitterMatcher(Ref ref, {String? diverId})`
  (null or empty means the active diver, as today);
  `Future<TankPresetEntity?> loadDefaultTankPresetForDownloads(Ref ref, {String? diverId})`
  (null, empty or the active diver reads `settingsProvider` as today; another
  diver reads `diverSettingsRepositoryProvider.getSettingsForDiver(diverId)`,
  falling back to `const AppSettings()` when that diver has no row).
- The service passes the `diverId` it already receives in `importDives`,
  `importSingleDiveAsNew` and `resolveConflict` to both loaders.

- [ ] **Step 1: Write failing tests.** Default tank: with the active diver's
  settings off and diver B's settings on with preset X, `diverId: 'B'` returns
  X and no diverId returns null. Transmitters: entries saved for diver B are
  matched when `diverId: 'B'` and not when omitted. Service: a recording
  loader receives the `diverId` passed to `importSingleDiveAsNew`.
- [ ] **Step 2: Run and see them fail.**
- [ ] **Step 3: Implement** the typedefs, loader parameters and call sites;
  update the provider wiring to `(diverId) => loadX(ref, diverId: diverId)`
  and existing test fakes to the new arity.
- [ ] **Step 4: Run** the three test files and `test/features/dive_computer`.
- [ ] **Step 5: Commit** `feat(dive-computer): import loaders read the target diver's settings`.

### Task 3: Adapter lookup and target diver

**Files:**
- Create: `lib/features/import_wizard/data/adapters/dive_computer_adapter_target.dart` (part of the adapter)
- Create: `lib/features/import_wizard/domain/models/import_target_choice.dart`
- Modify: `lib/features/import_wizard/domain/models/import_bundle.dart` (field on `ImportBundle`)
- Modify: `lib/features/import_wizard/data/adapters/dive_computer_adapter.dart`
- Modify: `lib/features/import_wizard/data/adapters/dive_computer_adapter_connections.dart:16`
- Modify: `lib/features/import_wizard/data/adapters/dive_computer_adapter_import_steps.dart:88`
- Test: `test/features/import_wizard/data/adapters/dive_computer_adapter_owner_test.dart`

**Interfaces:**
- Produces: `class ImportTargetChoice { const ImportTargetChoice({required String ownerDiverId, required String chosenDiverId}); }`
  with `==`/`hashCode`; `ImportBundle.targetChoice` (nullable, default null,
  carried by `copyWith` if present).
- Produces: `abstract interface class RetargetableImportAdapter { Future<void> setTargetDiver(String diverId); }`
  in `lib/features/import_wizard/domain/adapters/import_source_adapter.dart`;
  `DiveComputerAdapter implements ImportSourceAdapter, RetargetableImportAdapter`.
- Produces on `DiveComputerAdapter`: constructor params `bool followComputerOwner = true`
  and `DiverRepository? diverRepository` (else read from `_ref` via
  `diverRepositoryProvider`); getters `String get activeDiverId`,
  `String get targetDiverId` (chosen, else active), and
  `String get provisionalTargetDiverId` (the known computer's owner when
  `followComputerOwner` and the owner is non-empty and not active, else
  active; used before the download for the first-sync cutoff).
- Renames `_diverId` to `_activeDiverId`.

Behaviour:
- **Lookup.** `_resolveByLocalConnection`, `findByBluetoothAddress` and both
  `findByHardwareIdentity` calls first search the active diver (as today),
  then, when that misses and the active id is non-empty, search with no
  diverId. A new computer is still created with `diverId: _activeDiverId`.
- **Resolving the owner** happens once in `buildBundle`, after
  `_retryPendingComputerSave`, in `Future<void> _resolveTarget()`: the owner
  is `computer?.diverId` when non-empty, not the active id, the active id is
  non-empty, and `getDiverById(owner)` returns a diver. When there is such an
  owner and no choice has been made yet, the choice defaults to the owner if
  `followComputerOwner`, else the active id. `buildBundle` sets
  `targetChoice` only when there is such an owner.
- **Diver-dependent reads use `targetDiverId`:** `checkDuplicates` (source
  keys, `detectDuplicate`, planned dives), `resolveConflict`,
  `importSingleDiveAsNew`, the consolidate path in the import-steps part.
- `setTargetDiver(id)` records the choice; it never touches the computer row.
- `resetState()` clears the choice.

- [ ] **Step 1: Write failing tests** (reuse the fakes or mocks in
  `dive_computer_adapter_test.dart`; computers A owned by `mitchell`,
  active diver `bill`):
  - `resolveKnownComputer finds another profile's computer by address`:
    `adapter.computer?.id == 'A'`.
  - `ensureComputer reuses another profile's computer by serial`: no
    `createComputer` call, `computer.id == 'A'`.
  - `active profile's duplicate wins`: A (mitchell) and A2 (bill) share a
    serial; resolves to A2 and `bundle.targetChoice == null`.
  - `bundle names the owner and defaults to them`: `targetChoice ==
    ImportTargetChoice(ownerDiverId: 'mitchell', chosenDiverId: 'mitchell')`,
    `targetDiverId == 'mitchell'`.
  - `switch off defaults to the active profile`: `followComputerOwner: false`
    gives `chosenDiverId: 'bill'`.
  - `deleted or null owner shows no choice`: owner id unknown to the diver
    repository, or `diverId: null`, gives `targetChoice == null` and
    `targetDiverId == 'bill'`.
  - `unscoped library keeps global lookup and no choice`: active id `''`.
  - `import writes to the chosen diver`: after `setTargetDiver('bill')` on
    Mitchell's computer, `importSingleDiveAsNew` is called with
    `diverId: 'bill'` and `computerId: 'A'`, and A's `diverId` is unchanged.
- [ ] **Step 2: Run and see them fail.**
- [ ] **Step 3: Implement** per Behaviour above.
- [ ] **Step 4: Run** the new file and every
  `test/features/import_wizard/data/adapters/dive_computer_adapter_*` file.
- [ ] **Step 5: Commit** `feat(import-wizard): downloads find and target the computer's owner`.

### Task 4: Result reports the profile

**Files:**
- Modify: `lib/features/import_wizard/data/adapters/dive_computer_adapter.dart` (`performImport` result)
- Test: `test/features/import_wizard/data/adapters/dive_computer_adapter_owner_test.dart`

**Interfaces:**
- Consumes: `targetDiverId`, `activeDiverId` from Task 3.
- When `targetDiverId != activeDiverId` and the active id is non-empty, the
  result carries `diverOutcomes: [DiverImportOutcome(diverId: target, name:
  <getDiverById(target).name>, isNew: false, isActive: false, diveIds:
  importedDiveIds)]`. Otherwise `diverOutcomes` stays empty, as today.

- [ ] **Step 1: Write failing tests:** `result names the chosen profile` (one
  outcome, `isActive == false`, ids equal `importedDiveIds`) and `own computer
  has no outcomes`.
- [ ] **Step 2: Run and see them fail.**
- [ ] **Step 3: Implement.** Tagging (`_applyImportTags`) and logbook rules
  (`runImportRules`) already prefer `diverOutcomes`; the summary's "By
  profile" section shows because `isActive` is false.
- [ ] **Step 4: Run** the adapter tests and
  `test/features/import_wizard/presentation/providers`.
- [ ] **Step 5: Commit** `feat(import-wizard): import summary names the profile a download went to`.

### Task 5: Review step notice, picker and retargeting

**Files:**
- Create: `lib/features/import_wizard/presentation/widgets/computer_owner_notice.dart`
- Modify: `lib/features/import_wizard/presentation/providers/import_wizard_providers.dart`
- Modify: `lib/features/import_wizard/presentation/widgets/review_step.dart:49, 279, 490`
- Modify: `lib/features/dive_log/presentation/providers/dive_providers.dart` (next to `nextDiveNumberProvider`)
- Modify: `lib/l10n/arb/app_*.arb` (11 files)
- Test: `test/features/import_wizard/presentation/widgets/computer_owner_notice_test.dart`
- Test: `test/features/import_wizard/presentation/providers/import_wizard_retarget_test.dart`

**Interfaces:**
- Consumes: `ImportTargetChoice`, `RetargetableImportAdapter` (Task 3).
- Produces: `Future<void> ImportWizardNotifier.changeTargetDiver(String diverId)`:
  no-op unless the adapter is a `RetargetableImportAdapter` and the bundle has
  a `targetChoice`; otherwise `setTargetDiver`, then `buildBundle`,
  `checkDuplicates` (a failure falls back to the unchecked bundle, as in
  `unified_import_wizard.dart`), then `setBundle`. Import tags are kept.
- Produces: `ComputerOwnerNotice({required ImportTargetChoice choice, required ValueChanged<String> onChanged})`,
  a `ConsumerWidget` reading `allDiversProvider`; renders nothing when the
  owner is not in the list.
- Produces: `final nextDiveNumberForDiverProvider = FutureProvider.family<int, String?>`
  (same body as `nextDiveNumberProvider` with the given diver);
  `nextDiveNumberProvider` delegates to it with the current diver.
- Produces l10n keys (placeholders in this map order: `owner`, `chosen`):
  `universalImport_computerOwner_notice` = "This computer belongs to {owner}.
  Dives will be added to {chosen}'s log."; `universalImport_computerOwner_profileLabel`
  = "Profile".

Review step: render `ComputerOwnerNotice` directly after `ImportSourceCard`
when `bundle.targetChoice != null` (not subject to the source card's height
guard); the dive-number preview and `plannedFillCandidatesProvider` use
`bundle.targetChoice?.chosenDiverId ?? <today's value>`.

- [ ] **Step 1: Write failing tests.** Widget: Mitchell and Bill profiles,
  choice (mitchell, mitchell) renders "This computer belongs to Mitchell.
  Dives will be added to Mitchell's log."; choice (mitchell, bill) renders
  "...added to Bill's log." with the dropdown on Bill; selecting Bill calls
  `onChanged('bill')`; an owner missing from the list renders nothing.
  Notifier: with a fake retargetable adapter whose `checkDuplicates` marks
  dive 0 duplicate only for diver `mitchell`, `changeTargetDiver('bill')`
  calls `setTargetDiver('bill')`, the new bundle has `chosenDiverId: 'bill'`,
  dive 0 is selected again with no duplicate action, and `importTags` is
  unchanged.
- [ ] **Step 2: Run and see them fail.**
- [ ] **Step 3: Implement**, add ARB keys in all locales, `flutter gen-l10n`.
- [ ] **Step 4: Run** the new tests and `test/features/import_wizard`.
- [ ] **Step 5: Commit** `feat(import-wizard): choose the profile for a download on the review step`.

### Task 6: Wiring at both entry points and the cutoff

**Files:**
- Modify: `lib/core/router/app_router.dart:2206-2227, 2299-2316`
- Modify: `lib/features/dive_computer/presentation/providers/download_providers.dart:617-624`
- Modify: `lib/features/import_wizard/presentation/widgets/dc_adapter_steps.dart:599`
- Modify: the four `test/features/import_wizard/presentation/widgets/dc_adapter_download_step_*_test.dart` overrides
- Test: `test/features/dive_computer/presentation/providers/first_sync_cutoff_default_test.dart`

**Interfaces:**
- Consumes: `followComputerOwner`, `provisionalTargetDiverId` (Task 3),
  `AppSettings.downloadsFollowComputerOwner` (Task 1).
- Produces: `firstSyncCutoffDefaultProvider` becomes
  `FutureProvider.autoDispose.family<DateTime?, String?>` keyed on a diver id
  (null or empty returns null); the download step watches it with
  `adapter.provisionalTargetDiverId`.
- Both routes pass `followComputerOwner: ref.read(settingsProvider).downloadsFollowComputerOwner`;
  `diverId` stays the active diver.

- [ ] **Step 1: Write a failing test:** the provider returns diver B's newest
  dive for `'B'` and null for `''`.
- [ ] **Step 2: Run and see it fail.**
- [ ] **Step 3: Implement**, update the four overrides to `.overrideWith((ref, _) async => null)`.
- [ ] **Step 4: Run** `test/features/import_wizard`, `test/features/dive_computer`,
  `test/architecture`, `test/shared`; `dart format .`; `flutter analyze`.
- [ ] **Step 5: Commit** `feat(dive-computer): downloads follow the computer's owner from both entry points`.
