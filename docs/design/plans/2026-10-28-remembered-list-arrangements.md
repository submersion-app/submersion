# Remembered List Arrangements Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task, inline in this session. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Every list's sort, grouping and view mode comes back as the diver left it, per diver, synced, without letting a sort tap undo a settings change made on another device.

**Architecture:** New nullable `diver_settings` columns hold each list's encoded sort and grouping; Equipment's arrangement and group-by-location move into the same row. These columns, the existing view-mode columns and `groupTripsInDiveList` form one sync column group (`listArrangement`) with its own clock, reusing the media fact-group machinery (`SyncFactGroups`, `mergeFactGroups`, `markFactsPending`). The list providers stay `StateProvider`s but derive their value from the active diver's settings, and in-list writes go through `SettingsNotifier`.

**Tech Stack:** Flutter, Riverpod 3 (legacy `StateProvider` via `core/providers/provider.dart`), Drift, the app's HLC sync layer.

**Spec:** `docs/design/specs/2026-10-28-remembered-list-arrangements-design.md`

## Global Constraints

- Schema version: 323. Main is at 320; PR #3726 claims 321 and 322. Re-check open PR diffs for `currentSchemaVersion` before Task 2's commit and renumber if taken.
- New columns are nullable with no value backfill. The only backfill is the new group clock, copied from the row clock (Task 2).
- Null or unrecognized stored value: read as that list's current hardcoded starting value; never rewritten.
- Writes from list surfaces wait for `SettingsNotifier.settingsLoaded` before saving.
- No new code in `database.dart` beyond the version bump and the floor-list comment; no growth of `before_open.dart`.
- New code goes in new files; `settings_providers.dart` gains only the `ListArrangements` field and one method.
- No em-dash characters anywhere. `dart format .` before every commit.
- Tests that touch process-wide state restore it (`test/architecture/test_global_state_restored_test.dart`).
- Screenshots never run against the real library (see Task 0).

## Review Focus

1. A sort tapped while the diver's settings are still loading at launch survives the load (Task 4 test `setter waits for the load`).
2. Switching diver profile with a list open shows the new diver's arrangement (Task 5 test `follows a diver switch`).
3. A value written by a newer app version (unknown field name) shows the starting order and survives an unrelated settings save (Task 2 test `unknown value round-trips`, Task 5 test `unknown value falls back`).
4. A sort on a device holding stale settings does not revert a gradient-factor change made on another device (Task 3 test `stale device sort keeps peer settings`).
5. An Equipment edit made before the old app-wide arrangement has loaded never writes the defaults over it (Task 6 test `edit before legacy load builds on legacy value`).

---

### Task 0: Before screenshots

- [ ] **Step 1:** Read the `run` skill and confirm how it isolates app data. If it would open the real library (`~/Library/Containers/app.submersion/Data/Documents/Submersion`), launch with a throwaway data directory instead; a v323 migration of the real library would lock out the installed release.
- [ ] **Step 2:** On the current build, sort Saved Dive Plans by Name and Dive Sites grouped by Country, restart, and capture both lists showing the reset order: `01-saved-plans-before.png`, `02-dive-sites-before.png` in the scratchpad.

### Task 1: Generic sort codec

**Files:**
- Create: `lib/core/models/sort_state_codec.dart`
- Modify: `lib/features/media/domain/entities/media_library_sort.dart` (delegate `encodeMediaSort` / `decodeMediaSort` to the generic pair, same format)
- Test: `test/core/models/sort_state_codec_test.dart`

**Interfaces:**
- Produces: `String encodeSortState<T extends Enum>(SortState<T> sort)` giving `'<field.name>:<direction.name>'`; `SortState<T>? decodeSortState<T extends Enum>(String? raw, List<T> values)` returning null for null, wrong shape, unknown field or unknown direction; `T? decodeEnumName<T extends Enum>(String? raw, List<T> values)`.

- [ ] **Step 1: Write the failing tests:** `round-trips every DiveSortField in both directions`; `decodes null, '', 'name', 'name:sideways', 'bogus:ascending' to null`; `decodeEnumName returns null for an unknown name`. Keep the existing media sort tests green unchanged.
- [ ] **Step 2:** Run `flutter test test/core/models/sort_state_codec_test.dart`; expect a compile failure.
- [ ] **Step 3:** Implement the three functions; point the media pair at them.
- [ ] **Step 4:** Run the new test plus `test/features/media`; expect PASS.
- [ ] **Step 5:** Commit `feat(settings): add a generic sort state codec`.

### Task 2: Columns, schema v323 and the ListArrangements value

**Files:**
- Create: `lib/features/settings/domain/list_arrangements.dart`
- Create: `lib/core/database/migrations/helpers/list_arrangement_migrations.dart` (part file, registered in `app_database_migrations.dart`)
- Modify: `lib/core/database/tables/diver_tables.dart` (columns after `courseListViewMode`)
- Modify: `lib/core/database/database.dart` (`currentSchemaVersion = 323`, floor-list comment entry: additive, floor unchanged)
- Modify: `lib/core/database/migrations/ladder/rungs_v231_onward.dart` (rung 323 + `reportProgress`)
- Modify: `lib/core/database/migrations/before_open_settings_columns.dart` (v323 backstop call)
- Modify: `lib/features/settings/presentation/providers/settings_providers.dart` (`AppSettings.listArrangements` field, constructor default `ListArrangements.none`, `copyWith`)
- Modify: `lib/features/settings/data/repositories/diver_settings_repository.dart` (the three mapping sites next to `groupTripsInDiveList`: copy at ~332, `_storedColumns` at ~681, row-to-settings at ~949)
- Test: `test/core/database/migration_v323_list_arrangements_test.dart`, `test/features/settings/domain/list_arrangements_test.dart`, `test/features/settings/data/repositories/diver_settings_repository_list_arrangements_test.dart`

**Interfaces:**
- Produces columns (all nullable TEXT unless noted; Drift JSON keys in parentheses): `dive_list_sort` (`diveListSort`), `dive_plan_list_sort` (`divePlanListSort`), `trip_list_sort`, `course_list_sort`, `buddy_list_sort`, `dive_center_list_sort`, `site_list_sort`, `certification_list_sort`, `equipment_list_sort`, `site_list_group_by`, `certification_list_group_by`, `equipment_arrangement` (JSON of `EquipmentArrangement.toJson`), `equipment_group_by_location` (nullable BOOL), `list_arrangement_hlc` (the group clock).
- Produces `@immutable class ListArrangements` with nullable raw `String?` fields `diveSort, divePlanSort, tripSort, courseSort, buddySort, diveCenterSort, siteSort, certificationSort, equipmentSort, siteGroupBy, certificationGroupBy, equipmentArrangement` and `bool? equipmentGroupByLocation`; `static const none`; `copyWith`; value `==`/`hashCode`. Raw strings so an unknown value is carried, not dropped.
- Produces `Future<void> _assertListArrangementColumns()` on `AppDatabase`: adds each column if missing, then `UPDATE diver_settings SET list_arrangement_hlc = hlc WHERE list_arrangement_hlc IS NULL AND hlc IS NOT NULL`. Idempotent; called from rung 323 and the backstop.

- [ ] **Step 1: Write the failing tests:**
  - migration: `v322 database upgrades with every column present and null values`; `list_arrangement_hlc copies the row hlc`; `a row with no hlc keeps a null group clock`.
  - value: `copyWith keeps unset fields`; `equality covers every field`.
  - repository: `listArrangements round-trips through a save and a read`; `unknown value round-trips` (store `'bogus:ascending'` for `diveSort`, save an unrelated `depthUnit` change, read back the same raw string).
- [ ] **Step 2:** Run them; expect failures.
- [ ] **Step 3:** Implement columns, part file, rung, backstop, version bump, value class, `AppSettings` field and the three repository mappings.
- [ ] **Step 4:** `dart run build_runner build --delete-conflicting-outputs`, then run the three tests plus `test/core/database`; expect PASS.
- [ ] **Step 5:** Commit `feat(settings): store list arrangements per diver (schema v323)`.

### Task 3: The listArrangement sync group

**Files:**
- Modify: `lib/core/services/sync/sync_fact_groups.dart` (new group, `byEntity['diverSettings']`, `tables['diverSettings'] = (table: 'diver_settings', pk: 'id')`; update the "Only media does today" doc)
- Modify: `lib/features/settings/data/repositories/diver_settings_repository.dart` (`updateSettingsForDiver` stamping)
- Modify: `lib/core/services/sync/sync_data_serializer.dart` (`_exportDiverSettings` where clause adds `t.listArrangementHlc.isBiggerThanValue(hlcSince)`)
- Modify: `lib/features/settings/presentation/conflicts/catalogue/diver_settings_fields.dart` and the 12 ARB files (labels for the 13 new value columns and `listArrangementHlc`), then `flutter gen-l10n`
- Test: `test/core/services/sync/diver_settings_list_arrangement_sync_test.dart`, `test/features/settings/data/repositories/diver_settings_repository_arrangement_clock_test.dart`

**Interfaces:**
- Consumes: Task 2 columns.
- Produces: `SyncFactGroups.diverSettingsListArrangement` with `name: 'listArrangement'`, `clockKey: 'listArrangementHlc'`, `clockColumn: 'list_arrangement_hlc'`, `columns`: the 13 new value columns plus `diveListViewMode, siteListViewMode, tripListViewMode, equipmentListViewMode, buddyListViewMode, diveCenterListViewMode, certificationListViewMode, courseListViewMode, groupTripsInDiveList` (JSON key to SQL name).
- Stamping rule in `updateSettingsForDiver`: changed columns all in the group: write the changed columns and `updatedAt` as today, then call `markFactsPending(group: diverSettingsListArrangement)`; changed columns mixing group and other synced columns: `markRecordPending(alsoStamp: [group])`; otherwise unchanged behaviour. Device-local-only branch unchanged.

- [ ] **Step 1: Write the failing tests:**
  - repository: `an arrangement-only change stamps the group clock and leaves hlc`; `a units change stamps hlc and leaves a set group clock`; `a mixed change stamps both`; each also asserts the row is pending.
  - sync: `stale device sort keeps peer settings` (local: sort changed after peer's GF edit by group clock, older row clock; peer: newer row clock, newer `gfLow`, older group clock; after merge the row holds the peer's `gfLow` and the local `diveListSort`); `a peer with a newer group clock wins every group column`; `an older peer without the group clock key leaves new columns untouched`; `incremental export includes a row whose only change was an arrangement`.
- [ ] **Step 2:** Run; expect failures.
- [ ] **Step 3:** Implement the group, stamping rule, export clause and catalogue entries with translations.
- [ ] **Step 4:** Run the new tests, `test/core/services/sync`, `test/core/data`, `test/core/services/nearby`, `test/features/settings/presentation/conflicts`, `test/l10n` (whatever ARB guards exist); expect PASS.
- [ ] **Step 5:** Commit `feat(sync): sync list arrangements under their own clock`.

### Task 4: Writing arrangements through SettingsNotifier

**Files:**
- Modify: `lib/features/settings/presentation/providers/settings_providers.dart` (one method; view-mode setters and `setGroupTripsInDiveList` await `settingsLoaded` first)
- Create: `lib/features/settings/presentation/providers/list_arrangement_writes.dart` (extension)
- Modify: `test/helpers/mock_providers.dart` (mock implements the method)
- Test: `test/features/settings/presentation/providers/list_arrangement_writes_test.dart`

**Interfaces:**
- Produces on `SettingsNotifier`: `Future<void> updateListArrangements(ListArrangements Function(ListArrangements current) change)`: awaits `settingsLoaded`, applies `change` to the current `state.listArrangements`, saves via `_saveSettings`.
- Produces `extension ListArrangementWrites on SettingsNotifier` with `setDiveSort(SortState<DiveSortField>)`, `setDivePlanSort`, `setTripSort`, `setCourseSort`, `setBuddySort`, `setDiveCenterSort`, `setSiteSort`, `setCertificationSort`, `setEquipmentSort`, `setSiteGroupBy(SiteGroupBy)`, `setCertificationGroupBy(CertificationGroupBy)`, `setEquipmentGroupByLocation(bool)`, all `Future<void>`, encoding with Task 1's codec (group-bys by `.name`).

- [ ] **Step 1: Write the failing tests:** `setDiveSort saves the encoded value for the active diver`; `two quick sorts both land` (second builds on the first); `setter waits for the load` (call before the diver row loads, then let the load land; the stored and state value is the tapped one); `setSiteListViewMode waits for the load` (same shape).
- [ ] **Step 2:** Run; expect failures.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Run the new test and `test/features/settings/presentation/providers`; expect PASS.
- [ ] **Step 5:** Commit `feat(settings): save list arrangements from the lists`.

### Task 5: Lists read and write the saved arrangement

**Files:**
- Modify the providers (body watches `settingsProvider.select((s) => s.listArrangements.<field>)`, decodes with Task 1's codec, falls back to the provider's current hardcoded value): `diveSortProvider` (`dive_providers.dart:56`), `divePlanSortProvider` (`plan_repository_providers.dart:24`), `tripSortProvider`, `courseSortProvider`, `buddySortProvider` (not `buddyPickerSortProvider`), `diveCenterSortProvider`, `siteSortProvider`, `certificationSortProvider`, `equipmentSortProvider`, `siteGroupByProvider`, `certificationGroupByProvider`.
- Modify the eight view-mode providers and `diveListGroupTripsProvider` (`settings_providers.dart` ~3765-3810): `ref.watch(settingsProvider.select(...))` instead of a one-time `ref.read`; rewrite their doc comments.
- Modify every lib write `ref.read(<one of the above>.notifier).state = x` (about 50; `grep -rEn "(Sort|GroupBy|ViewMode|GroupTrips)Provider\.notifier\)" lib`) to the matching `ref.read(settingsProvider.notifier).set...(x)`. In `section_appearance_page.dart` ~718-739 drop the now redundant provider writes.
- Test: `test/features/settings/presentation/providers/list_arrangement_providers_test.dart`, plus fixes to existing widget tests whose sort-sheet taps now need the mock notifier.

**Interfaces:**
- Consumes: Task 4 setters; Task 1 codec.
- Produces: unchanged provider names and types, so the existing `overrideWith((ref) => value)` test overrides keep compiling.

- [ ] **Step 1: Write the failing tests** (ProviderContainer with a settings notifier seeded per diver): `each sort provider reads its saved value` (table-driven over the nine); `unknown value falls back` (`'bogus:ascending'` gives the current default); `follows a diver switch` (diver A `diveSort` name-ascending, diver B depth-descending; switching changes the provider); `follows an Appearance change` (`setSiteListViewMode` updates `siteListViewModeProvider`); widget test `saved plans sort sheet persists the choice` (tap Name, assert `listArrangements.divePlanSort == 'name:ascending'`).
- [ ] **Step 2:** Run; expect failures.
- [ ] **Step 3:** Implement providers, then the call sites.
- [ ] **Step 4:** Run the new tests and the feature test folders for dive_log, planner, trips, courses, buddies, dive_centers, dive_sites, certifications, equipment, settings, dashboard, training; fix tests that relied on the session-only write. Expect PASS.
- [ ] **Step 5:** Commit `feat(lists): bring every list back as the diver left it`.

### Task 6: Equipment arrangement and group-by-location per diver

**Files:**
- Modify: `lib/features/equipment/presentation/providers/equipment_arrangement_provider.dart` (replace the storage-reading notifier)
- Modify: `lib/features/equipment/presentation/providers/equipment_location_providers.dart` (`equipmentGroupByLocationProvider`)
- Modify: `lib/features/equipment/presentation/widgets/equipment_grouping_controls.dart`, `equipment_arrange_sheet.dart`, `group_by_location_switch.dart`
- Modify: `lib/features/settings/presentation/providers/list_arrangement_writes.dart` (add `updateEquipmentArrangement`)
- Modify: `lib/features/settings/data/repositories/app_settings_repository.dart` (doc: the keys are now read-only legacy fallbacks; keep the setters only if a test or an older-peer path needs them, else remove)
- Modify: PDF path: `PdfExportService.generateDivePdfBytes` / `exportDivesToPdf` / `saveDivesToPdfFile`, `ExportService` pass-throughs, callers in `export_providers.dart` and `dive_list_content.dart`
- Test: `test/features/equipment/presentation/providers/equipment_arrangement_per_diver_test.dart`, updates to existing arrangement and PDF tests

**Interfaces:**
- Produces `legacyEquipmentArrangementProvider = FutureProvider<EquipmentArrangement?>` (reads `AppSettingsRepository.getEquipmentArrangement`, invalidated on `watchSettingsChanges`) and `legacyEquipmentGroupByLocationProvider = FutureProvider<bool?>` (null when never written).
- Produces `equipmentArrangementProvider = Provider<EquipmentArrangement>`: per-diver JSON decoded, else legacy value, else `EquipmentArrangement.defaults`.
- Produces `resolvedEquipmentArrangementProvider = FutureProvider<EquipmentArrangement>`: awaits `settingsLoaded` and the legacy future, then resolves as above. Replaces the old notifier's `loaded`.
- Produces on the extension: `Future<void> updateEquipmentArrangement(EquipmentArrangement Function(EquipmentArrangement current) change)`: awaits load, bases on per-diver value, else `await` the legacy future (a failed legacy read throws `StateError`, refusing the change), else defaults; saves the JSON.
- `equipmentGroupByLocationProvider` stays `FutureProvider<bool>`: per-diver value, else legacy, else false.
- The PDF methods take `required EquipmentArrangement gearArrangement`; `PdfExportService` no longer reads `AppSettingsRepository`.

- [ ] **Step 1: Write the failing tests:** `per-diver value wins over legacy`; `no per-diver value shows legacy`; `neither gives defaults`; `edit before legacy load builds on legacy value`; `failed legacy read refuses the edit`; `group by location falls back to legacy then false`; `switching diver switches the arrangement`; PDF: `export prints in the passed arrangement`.
- [ ] **Step 2:** Run; expect failures.
- [ ] **Step 3:** Implement; delete the queue and sequence machinery the old notifier needed for storage reads.
- [ ] **Step 4:** Run the new tests, `test/features/equipment`, `test/core/services/export`, `test/features/settings/presentation/providers`; expect PASS.
- [ ] **Step 5:** Commit `feat(equipment): keep the gear arrangement per diver`.

### Task 7: Docs and full verification

**Files:**
- Modify: `docs/user/multi-device-sync.md` ("What Syncs Between Devices": list arrangements sync per diver; Equipment's arrangement now per diver)
- Modify: `lib/core/services/sync/device_local_fields.dart` audit comment (`equipment_arrangement`, `equipment_group_by_location` are legacy, read only as a fallback)

- [ ] **Step 1:** Update the docs.
- [ ] **Step 2:** `dart format .`, `flutter analyze` (no issues), `flutter test test/architecture test/shared`, then the full suite via `scripts/run_all_tests.sh` logged to the scratchpad; zero failures.
- [ ] **Step 3:** Commit `docs(sync): list arrangements sync per diver`.

### Task 8: After screenshots

- [ ] **Step 1:** In the same isolated data directory as Task 0, repeat its steps on this build: `01-saved-plans-after.png` (still sorted by Name after restart), `02-dive-sites-after.png` (still grouped by Country).
- [ ] **Step 2:** Send all four with SendUserFile (`display: attach`), captioned for the PR's Screenshots section.
