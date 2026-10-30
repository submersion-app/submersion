# Leave out unused open-circuit gases on rebreather downloads: Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task (inline, never subagents). Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A synced, off-by-default import setting that stops CCR/SCR dive computer downloads and re-parses from creating cylinders for open-circuit gases that have no transmitter and were never breathed (issue #3668).

**Architecture:** The tank resolver marks such cylinders (`unusedOcGas`) and keeps returning them, so the bailout ranking, diluent resolution and the bailout transmitter claim see every gas exactly as today. Each libdivecomputer writer (new dive, re-download, re-parse) drops the marked cylinders after the claim when the setting is on, through one pure helper. Re-parse protects anything the diver edited, using a wider test than the claim's and excusing the pre-v1.8.1 importer's role and preset guesses.

**Tech Stack:** Flutter, Dart, Drift (SQLite), Riverpod, mockito, flutter_test.

**Spec:** `docs/design/specs/2026-10-25-ccr-unused-gas-import-design.md`

## Global Constraints

- Setting off by default; existing divers get it off (column only, no backfill).
- Schema v315, additive; `minimumCompatibleSchemaVersion` does not move.
- Name everywhere: column `omit_unused_oc_gases`, Drift getter and `AppSettings` field `omitUnusedOcGases`, flag on tanks `unusedOcGas`.
- Only dive modes `ccr` and `scr` are ever marked.
- Backstop goes in `before_open_settings_columns.dart`, never `before_open.dart`.
- Every ARB locale gets the new strings (ar, de, en, es, fr, he, hu, it, nl, pt, zh); ARB files are feature-grouped, insert beside the `settings_downloadsFollowOwner_*` / `settings_conflict_field_downloadsFollowComputerOwner` keys.
- No em dashes or en dashes as punctuation anywhere; no emojis; no AI tool named in any commit.
- Stage explicit paths only (`test/zz_tmp_shot/` is a throwaway screenshot harness that must never be committed).

## Review Focus

1. A bailout transmitter registered as Bailout on a dive with an unused Air gas: the transmitter still takes Air through the claim, switch on (Task 5 and Task 6 tests).
2. A gas the diver bailed out onto mid-dive is kept (Task 3 test).
3. A computer that reports no per-sample gas marks nothing (Task 3 test), and a drop that would leave no cylinder is skipped (Task 4 test).
4. A cylinder added by hand in the dive editor, at the order a dropped gas held, survives re-parse with its own mix (Task 6 test).
5. Switch off: every path writes the same cylinders as before (Task 5 and Task 6 tests).

---

### Task 1: The `omit_unused_oc_gases` setting (schema v315 and settings plumbing)

**Files:**
- Modify: `lib/core/database/tables/diver_tables.dart` (beside `downloadsFollowComputerOwner`)
- Create: `lib/core/database/migrations/helpers/unused_oc_gas_migrations.dart`
- Modify: `lib/core/database/migrations/app_database_migrations.dart` (add `part`)
- Modify: `lib/core/database/migrations/ladder/rungs_v231_onward.dart` (v315 rung after v314)
- Modify: `lib/core/database/migrations/before_open_settings_columns.dart` (v315 backstop)
- Modify: `lib/core/database/database.dart` (`currentSchemaVersion = 315`, `315` in `migrationVersions` with a comment like v314's)
- Modify: `lib/core/services/sync/sync_data_serializer.dart` (`'omitUnusedOcGases': true` beside `'downloadsFollowComputerOwner': true`)
- Modify: `lib/features/settings/data/repositories/diver_settings_repository.dart` (the three sites v310 touched)
- Modify: `lib/features/settings/presentation/providers/settings_providers.dart` (field, constructor default `false`, `copyWith`, setter)
- Modify: `lib/features/settings/presentation/conflicts/catalogue/diver_settings_fields.dart`
- Modify: `test/helpers/mock_providers.dart` (override the setter)
- Modify: every `lib/l10n/arb/app_*.arb` for `settings_conflict_field_omitUnusedOcGases` ("Skip unused bailout gases" in English)
- Test: `test/core/database/migration_v315_omit_unused_oc_gases_test.dart`
- Test: `test/features/settings/data/repositories/diver_settings_repository_unused_oc_gases_test.dart`

**Interfaces:**
- Produces: `AppSettings.omitUnusedOcGases` (bool, default false); `SettingsNotifier.setOmitUnusedOcGases(bool value)` (waits for `settingsLoaded` like `setDownloadsFollowComputerOwner`); Drift `DiverSettings.omitUnusedOcGases`.

- [ ] **Step 1: Write the failing migration test**, modelled on `migration_v310_download_owner_test.dart`: `'v315 is in the ladder'` (currentSchemaVersion >= 315, `migrationVersions` contains 315, step count 314 = 315 + 1), `'the column is additive and did not move the sync floor'` (`minimumCompatibleSchemaVersion` is not 315), `'upgrading from v314 leaves the switch off for an existing diver'` (reads `omit_unused_oc_gases` as false), `'beforeOpen heals a database already at v315 that lacks it'`.
- [ ] **Step 2: Write the failing repository test**, modelled on `diver_settings_repository_download_owner_test.dart`: saving `AppSettings(omitUnusedOcGases: true)` and reading it back gives true; a fresh diver reads false.
- [ ] **Step 3: Run both; expect compile failures** (`omitUnusedOcGases` undefined).
  Run: `flutter test test/core/database/migration_v315_omit_unused_oc_gases_test.dart test/features/settings/data/repositories/diver_settings_repository_unused_oc_gases_test.dart`
- [ ] **Step 4: Implement.** Column `boolean().withDefault(const Constant(false))()`. Helper `_assertOmitUnusedOcGasesColumn()` calls `_addColumnIfMissing('diver_settings', 'omit_unused_oc_gases', 'INTEGER NOT NULL DEFAULT 0 CHECK (omit_unused_oc_gases IN (0, 1))')`. Rung: `if (from < 315) await _assertOmitUnusedOcGasesColumn(); if (from < 315) await reportProgress();`. Then the plumbing at each site v310 touched, and the conflict field `ConflictField((l) => l.settings_conflict_field_omitUnusedOcGases, FieldKind.boolean)`. Add the ARB key to every locale, then run `flutter gen-l10n` and `dart run build_runner build --delete-conflicting-outputs`.
- [ ] **Step 5: Run the two tests plus the guards; expect PASS.**
  Run: `flutter test test/core/database/migration_v315_omit_unused_oc_gases_test.dart test/features/settings test/core/services/sync test/core/database`
- [ ] **Step 6: Commit** `feat(settings): add the omit-unused-OC-gases import setting (schema v315)`.

### Task 2: The switch in Settings > Data > Import

**Files:**
- Modify: `lib/features/settings/presentation/widgets/import_preferences_group.dart` (new `SwitchListTile` directly after the tank-pressure-at-surfacing one; doc comment gains the setting)
- Modify: every `lib/l10n/arb/app_*.arb` for `settings_omitUnusedOcGases_title` and `settings_omitUnusedOcGases_subtitle`
- Test: `test/features/settings/presentation/widgets/import_preferences_group_test.dart`

**Interfaces:**
- Consumes: `AppSettings.omitUnusedOcGases`, `setOmitUnusedOcGases` (Task 1).

English copy (fixed): title "Skip unused bailout gases"; subtitle "On rebreather downloads, leave out a gas with no transmitter that was never breathed". Icon: `Icons.filter_alt_off_outlined` (my call).

- [ ] **Step 1: Write the failing tests** in a new group `'skip unused bailout gases switch (issue #3668)'`: `'is off by default'` (switch found, value false); `'sits directly below tank pressure at surfacing'` (its top equals the surfacing tile's bottom via `tester.getRect`); `'toggling it records on'` (`notifier.state.omitUnusedOcGases` is true).
- [ ] **Step 2: Run; expect FAIL** (no such switch).
  Run: `flutter test test/features/settings/presentation/widgets/import_preferences_group_test.dart`
- [ ] **Step 3: Add the tile and the translated strings; `flutter gen-l10n`.**
- [ ] **Step 4: Run; expect PASS.** Also run `test/features/settings/presentation/pages/settings_page_test.dart`.
- [ ] **Step 5: Commit** `feat(settings): add the skip-unused-bailout-gases switch`.

### Task 3: The resolver marks unused open-circuit gases

**Files:**
- Modify: `lib/features/dive_computer/domain/entities/downloaded_dive.dart` (`DownloadedTank.unusedOcGas`, constructor default false, `copyWith`)
- Modify: `lib/features/dive_log/data/repositories/dive_computer_repository_impl.dart` (`TankData.unusedOcGas`, default false, `copyWith`)
- Modify: `lib/features/dive_computer/data/services/dive_parser.dart` (`tankDataFrom` copies it)
- Modify: `lib/features/dive_computer/data/services/parsed_tank_resolver.dart`
- Test: `test/features/dive_computer/data/services/parsed_tank_resolver_unused_gas_test.dart`

**Interfaces:**
- Produces: `DownloadedTank.unusedOcGas`, `TankData.unusedOcGas` (both `bool`, default `false`); public `String openCircuitGasRole(double o2Percent)` in `parsed_tank_resolver.dart` returning `TankRole.deco.name` at or above `_decoMinO2Percent`, else `TankRole.backGas.name`. `_inferRole` delegates to it for a null usage (behaviour unchanged).

Rule, in `_resolveCylinders` for every cylinder created from a gas-list entry (the tankless branch and the "unclaimed" loop; never a transmitter cylinder): `unusedOcGas` is true when `parsed.diveMode` is `'ccr'` or `'scr'`, `!_hasReportedUsage(gas)`, the set `{for (final b in breathedGasSequence(parsed)) b.gasIndex}` is non-empty, and that set does not contain the gas index. Compute the set once per call.

Fixture: the reporter's dive, modelled on `parsed_tank_resolver_ccr_transmitters_test.dart`: gas 0 O2 99/0 (no usage), gas 1 Air 21/0 (no usage), gas 2 Air 21/0 with `usage: 2`; tank 0 diluent transmitter (usage 2, serial 818), tank 1 oxygen transmitter (usage 1, serial 154648), both `gasMixIndex: 4294967295`; samples on gas 2 throughout.

- [ ] **Step 1: Write the failing tests:**
  - `'the reporter's dive marks the O2 and Air OC gases unused'`: four tanks; the two with no transmitter serial have `unusedOcGas` true; the transmitter tanks false.
  - `'a gas the diver bailed out onto is not unused'`: same dive, samples switch to gas 1 for the last minutes; gas 1's cylinder false, gas 0's true.
  - `'no per-sample gas marks nothing'`: every sample `gasMixIndex: null`; all false.
  - `'open circuit is never marked'`: `diveMode: 'oc'`, same gas list with no transmitters, samples on gas 1; gas 0 false.
  - `'a diluent or oxygen-tagged gas with no transmitter is not marked'`: tankless CCR dive, a second diluent (usage 2) never breathed; false.
  - `'SCR is marked like CCR'`.
  - `'tankDataFrom carries the flag'` (in the same file, `DiveParser.tankDataFrom`).
- [ ] **Step 2: Run; expect compile failure** (`unusedOcGas` undefined).
  Run: `flutter test test/features/dive_computer/data/services/parsed_tank_resolver_unused_gas_test.dart`
- [ ] **Step 3: Implement the fields, `openCircuitGasRole`, and the marking.**
- [ ] **Step 4: Run the new file and every `parsed_tank_resolver_*_test.dart`, `dive_parser_*_test.dart`; expect PASS.**
- [ ] **Step 5: Commit** `feat(dive-computer): mark unused open-circuit gases on rebreather parses`.

### Task 4: The drop helper and the re-parse edit test

**Files:**
- Create: `lib/features/dive_computer/data/services/unused_oc_gas_cleanup.dart`
- Test: `test/features/dive_computer/data/services/unused_oc_gas_cleanup_test.dart`

**Interfaces:**
- Consumes: `TankData.unusedOcGas`, `openCircuitGasRole` (Task 3).
- Produces:
  - `typedef UnusedOcGasDrop = ({List<TankData> tanks, Set<int> dropped});`
  - `UnusedOcGasDrop dropUnusedOcGases(List<TankData> tanks, {Set<int> keep = const {}})`: removes every tank with `unusedOcGas` whose `index` is not in `keep`; `dropped` holds the removed indices. When the result would be empty it returns `(tanks: tanks, dropped: const {})`. Returns new lists.
  - `bool unusedOcGasEditedByDiver(DiveTank row, TankData parsed, {TankPresetEntity? defaultPreset})`: true when the row carries anything the diver set (spec, "Re-parse rules").

`unusedOcGasEditedByDiver` is true when any of: `tankName`, `equipmentId`, `startPressure`, `endPressure`, `regulatorEquipmentId`, `tripCylinderId`, `passportId` non-null; `extraRegulatorIds` non-null and non-empty; o2 or he differs from `parsed` by more than 0.5; `row.tankRole` differs from `parsed.role ?? 'backGas'` and also from `openCircuitGasRole(row.o2Percent)`; any of `volume > 0`, `workingPressure`, `tankMaterial`, `presetName` set, unless `row.tankRole == 'backGas'`, `defaultPreset != null`, and all four equal the preset (`volumeLiters` and `workingPressureBar` within 0.01, `material.name`, `name`).

- [ ] **Step 1: Write the failing tests:** drop removes marked tanks and reports their indices; keeps a marked tank in `keep`; keeps unmarked tanks; returns the input untouched when every tank is marked. Edit test: a bare row (role bailout, mix as parsed) is not edited; each of the listed fields set alone makes it edited; a pre-v1.8.1 row with role `backGas` on Air and parsed role `bailout` is not edited; the same row with the AL80 preset's four values and `defaultPreset: al80` is not edited; with three of the four matching it is edited; with the preset values but `defaultPreset: null` it is edited; a `deco` row on 100% O2 parsed `deco` is not edited.
- [ ] **Step 2: Run; expect compile failure.**
  Run: `flutter test test/features/dive_computer/data/services/unused_oc_gas_cleanup_test.dart`
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run; expect PASS.**
- [ ] **Step 5: Commit** `feat(dive-computer): add the unused-OC-gas drop and edit check`.

### Task 5: Downloads drop unused gases when the setting is on

**Files:**
- Modify: `lib/features/dive_computer/data/services/dive_import_service.dart`
- Modify: `lib/features/dive_computer/presentation/providers/download_providers.dart`
- Test: `test/features/dive_computer/data/services/dive_import_service_unused_gas_test.dart` (imports `dive_import_service_test.mocks.dart`)
- Test: `test/features/dive_computer/presentation/providers/download_unused_gas_loader_test.dart` (modelled on `download_default_tank_preset_test.dart`)

**Interfaces:**
- Consumes: `dropUnusedOcGases` (Task 4), `AppSettings.omitUnusedOcGases` (Task 1).
- Produces: `typedef OmitUnusedOcGasesLoader = Future<bool> Function(String? diverId);` and a `DiveImportService` constructor parameter `OmitUnusedOcGasesLoader? omitUnusedOcGasesForImports`; private `Future<bool> _loadOmitUnusedOcGases(String? diverId)` (false when no loader or the load throws, logged). `@visibleForTesting Future<bool> loadOmitUnusedOcGasesForDownloads(Ref ref, {String? diverId})` in `download_providers.dart`, reading the diver's settings the same way `loadDefaultTankPresetForDownloads` does (extract the shared "settings of this diver" lookup into one private helper; an unreadable other diver gives false).

Wiring: resolve the flag wherever the default tank preset is resolved (once per `importDives` batch; per call in `importSingleDiveAsNew` and `resolveConflict`), and pass it into `_importNewDive` as `bool omitUnusedOcGases = false`. In `_importNewDive`, apply `dropUnusedOcGases(claim.tanks).tanks` after the claim and before `applyDefaultPresetToTanks`. In `_updateExistingDive`, apply it to `_parser.parseTanks(dive)` with the flag loaded for the active diver (`null`). `attachToPlannedDive` is unchanged.

- [ ] **Step 1: Write the failing service tests** (capture `tanks` from `importProfile` as `dive_import_service_test.dart` does). Fixture: a `DownloadedDive` with `diveMode: DiveMode.ccr`, the two transmitter tanks, and two tanks with `unusedOcGas: true` (O2, Air bailout):
  - `'switch on: a new dive gets only the transmitter cylinders'`
  - `'switch off: a new dive gets all four'` (loader returns false) and `'no loader: all four'`
  - `'a registered bailout transmitter still takes the unused Air gas'`: add a third transmitter tank (bailout, serial 555, `mixRecorded: false`, role bailout via the matcher); switch on; the transmitter tank has o2 21 and `mixRecorded` true, and no pressureless Air tank is written.
  - `'re-download into an existing dive with the switch on passes no unused gas'` (through `resolveConflict` with a replace resolution, the path `_updateExistingDive` serves).
  - `'a loader that throws imports everything'`.
- [ ] **Step 2: Write the failing loader tests:** active diver reads live settings; another diver reads their saved settings; an unreadable other diver gives false.
- [ ] **Step 3: Run; expect FAIL.**
  Run: `flutter test test/features/dive_computer/data/services/dive_import_service_unused_gas_test.dart test/features/dive_computer/presentation/providers/download_unused_gas_loader_test.dart`
- [ ] **Step 4: Implement the loader, the constructor parameter, the provider wiring and the two call sites.**
- [ ] **Step 5: Run the new files plus `dive_import_service_test.dart` and `download_default_tank_preset_test.dart`; expect PASS.**
- [ ] **Step 6: Commit** `feat(dive-computer): skip unused OC gases on rebreather downloads`.

### Task 6: Re-parse removes unused gases when the setting is on

**Files:**
- Modify: `lib/features/dive_computer/data/services/reparse_service.dart`
- Modify: `lib/features/dive_computer/presentation/providers/reparse_providers.dart`
- Modify: `lib/features/dive_computer/presentation/providers/download_providers.dart` (`loadDefaultTankPresetForDownloads` gains `bool ignoreImportOptIn = false`)
- Test: `test/features/dive_computer/data/services/reparse_service_unused_gas_test.dart` (own copies of the `insertDive` / `insertComputer` / `insertSource` / `makeParsedDive` helpers from `reparse_service_test.dart`)

**Interfaces:**
- Consumes: `dropUnusedOcGases`, `unusedOcGasEditedByDiver` (Task 4).
- Produces: `ReparseService` constructor parameters `bool omitUnusedOcGases = false` and `Future<TankPresetEntity?> Function()? cleanupTankPresetLoader` (null or a throwing load means no preset, logged). Provider passes `omitUnusedOcGases: ref.watch(settingsProvider.select((s) => s.omitUnusedOcGases))` and `cleanupTankPresetLoader: () => loadDefaultTankPresetForDownloads(ref, ignoreImportOptIn: true)`.

Changes in `_carryOverTanks`, only when `omitUnusedOcGases`:
1. Load the preset once per call.
2. `keep` = parsed indices `i` whose `matches[i]` row has `sourceTankIndex == i` and `unusedOcGasEditedByDiver(row, parsedTank, defaultPreset: preset)`.
3. `drop = dropUnusedOcGases(claim.tanks, keep: keep)`; the insert/update loop walks `drop.tanks` instead of `claim.tanks`.
4. `newTankOrders.addAll(drop.dropped)`, so the pre-v200 rule never deletes a row sitting at a dropped order.
5. For each dropped index whose matched row has `sourceTankIndex` equal to it, delete that row and `logDeletion` it (it is in `matchedIds`, so the existing loop would skip it). A row matched only through the order fallback is left untouched.

- [ ] **Step 1: Write the failing tests** with a CCR parse of the reporter's dive (Task 3 fixture) re-parsed over stored rows. Stored rows: the two transmitter cylinders (`sourceTankIndex` 0 and 1) and the two gas cylinders (`sourceTankIndex` 2 and 3, roles deco and bailout):
  - `'switch on: the unused gas cylinders are deleted and the deletions logged'` (two rows left; `sync` deletion log has both ids)
  - `'switch off: all four stay'`
  - `'a gas cylinder with a hand-entered start pressure is kept'`
  - `'a pre-v1.8.1 Air row stored as back gas is deleted'` (role backGas, no other fields)
  - `'a pre-v1.8.1 Air row filled from the default preset is deleted'` (AL80 values, `cleanupTankPresetLoader` returns AL80)
  - `'the same row is kept when the default preset changed'` (loader returns a different preset)
  - `'a cylinder added in the editor at a dropped order keeps its own mix'`: stored rows only the two transmitters plus a hand row with `sourceTankIndex` null, `tankOrder` 2, Air, role bailout; after re-parse the hand row exists with o2 21 and role bailout.
  - `'a registered bailout transmitter still takes the unused Air gas'` (transmitter matcher with a bailout entry, as in `reparse_service_test.dart`'s #2595 group)
  - `'a parse with no per-sample gas deletes nothing'`
- [ ] **Step 2: Run; expect FAIL.**
  Run: `flutter test test/features/dive_computer/data/services/reparse_service_unused_gas_test.dart`
- [ ] **Step 3: Implement the constructor parameters, the five carry-over changes and the provider wiring.**
- [ ] **Step 4: Run the new file and every `reparse_service_*_test.dart`; expect PASS.**
- [ ] **Step 5: Commit** `feat(dive-computer): re-parse removes unused OC gases when the setting is on`.

### Task 7: Whole-branch checks and the after screenshot

- [ ] **Step 1:** `dart format .` then `flutter analyze`; expect no issues.
- [ ] **Step 2:** `flutter test test/architecture test/shared test/core/database test/features/dive_computer test/features/settings test/features/import_wizard`; expect all pass.
- [ ] **Step 3:** Re-run the throwaway `test/zz_tmp_shot/shot_test.dart` with `--update-goldens`, copy the PNG to the scratchpad as `01-settings-import-after.png`, then delete `test/zz_tmp_shot/`.
- [ ] **Step 4:** Commit any formatting changes as `chore: format`.
