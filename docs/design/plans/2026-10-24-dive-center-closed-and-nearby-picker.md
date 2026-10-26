# Permanently Closed Dive Centers and Nearby-First Picker Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task, inline in this session. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let a diver mark a dive center permanently closed, show that everywhere a center is listed, and make the dive center picker list centers near the dive first.

**Architecture:** One synced boolean column on `dive_centers` (schema v313, additive, no backfill) carried through the entity and repository. A small shared `DiveCenterClosedTag` widget marks closed centers in the list tiles, table, detail page and picker. The picker's order comes from a pure ranking function over (centers, reference point), and the dive edit page resolves the reference point from site, entry GPS, exit GPS, then device location.

**Tech Stack:** Flutter, Drift, Riverpod, flutter_test, ARB l10n.

**Spec:** `docs/design/specs/2026-10-24-dive-center-closed-and-nearby-picker-design.md`

## Global Constraints

- Column `dive_centers.is_permanently_closed`, `INTEGER NOT NULL DEFAULT 0`, entity field `isPermanentlyClosed`, default false. Existing rows are never rewritten.
- Nearby radius: 50 km (`50000` metres), inclusive.
- Distances use `UnitFormatter.formatGeoDistance` (the diver's distance unit) and `distanceMeters` from `lib/core/utils/geo_math.dart`.
- Schema work goes through the migration ladder and helper part files; never add a rung or table to `database.dart` beyond the version constant and `migrationVersions` entry. `before_open.dart` is at the 800-line limit: add no lines to it.
- `minimumCompatibleSchemaVersion` stays 308 (additive synced column, like v249 fill hours).
- Every new string goes into all 11 ARB files (en plus ar, de, es, fr, he, hu, it, nl, pt, zh), inserted beside a neighbouring key of the same group, then `flutter gen-l10n`.
- No chip or text button in `ListTile.trailing` (`test/architecture/list_tile_trailing_width_test.dart`).
- No em-dash characters anywhere.

## Review Focus

1. A database restored from a pre-v313 backup or adopted through sync lacks the column: every center read selects the whole row, so the beforeOpen backstop must add it. Covered in Task 1 (fresh vs upgraded, and a v313-stamped database missing the column).
2. Two centers at exactly the same distance: order must be by name, not by input order or an unstable sort. Covered in Task 5 (ties arrive in reverse-name order).
3. A center exactly 50 km away counts as nearby; one at 50.001 km does not. Covered in Task 5.
4. The center already on the dive is closed: it must still show, checked, in the alphabetical section. Covered in Task 6.
5. Editing a center whose only change is the closed switch must count as a change and save it. Covered in Task 3.

---

### Task 1: Schema v313, entity and repository

**Files:**
- Modify: `lib/core/database/tables/site_tables.dart` (class `DiveCenters`, after `fillClosesAt`)
- Modify: `lib/core/database/migrations/helpers/site_migrations.dart` (new helper)
- Modify: `lib/core/database/migrations/ladder/rungs_v231_onward.dart` (v313 rung after v312)
- Modify: `lib/core/database/migrations/before_open_child_columns.dart` (backstop call)
- Modify: `lib/core/database/database.dart` (`currentSchemaVersion = 313`, `313` appended to `migrationVersions` with a comment)
- Modify: `lib/features/dive_centers/domain/entities/dive_center.dart`
- Modify: `lib/features/dive_centers/data/repositories/dive_center_repository.dart` (insert companion, update companion, `_mapRowToDiveCenter`, `_mapCustomRowToDiveCenter`)
- Modify: `lib/features/dive_log/data/repositories/dive_repository_impl.dart` (the two places near lines 4124 and 4557 that build a `DiveCenter` from a center row for a dive). UDDF export has no field for it and is left alone.
- Test: `test/core/database/migration_v313_dive_center_closed_test.dart` (new)
- Test: `test/features/dive_centers/domain/entities/dive_center_test.dart`
- Test: `test/features/dive_centers/data/repositories/dive_center_repository_test.dart`

**Interfaces:**
- Produces: `DiveCenter.isPermanentlyClosed` (`bool`, default `false`), `copyWith({bool? isPermanentlyClosed})`, included in `props`. Drift row field `isPermanentlyClosed`, JSON key `isPermanentlyClosed`.
- Produces: `Future<void> _assertDiveCenterClosedColumn()` on the `SiteMigrations` extension.

- [ ] **Step 1: Write the failing tests**

Migration test, modelled on `migration_v309_media_document_tags_test.dart`, with a v312 raw database containing a `divers` table and a `dive_centers` table with the pre-v313 columns and one row `('c1', 'Toucan Diving', ...)`:

```dart
test('v313 is the current schema version and in the ladder', () {
  expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(313));
  expect(AppDatabase.migrationVersions, contains(313));
  expect(AppDatabase.migrationStepCount(312), AppDatabase.migrationStepCount(313) + 1);
  expect(AppDatabase.minimumCompatibleSchemaVersion, 308);
});
test('existing centers start open', () async {
  // SELECT is_permanently_closed FROM dive_centers WHERE id = 'c1' -> 0
});
test('a database stamped v313 without the column gets it back in beforeOpen', () async {
  // user_version = 313, dive_centers without the column -> column present after open
});
test('a fresh database matches the upgraded one', () async {
  // PRAGMA table_info('dive_centers') row for is_permanently_closed equal in both
});
```

Entity test: `copyWith(isPermanentlyClosed: true)` sets it, plain `copyWith()` keeps it, two centers differing only in it are not equal, default is false.

Repository test: create a center with `isPermanentlyClosed: true`, read it back by id and through `getAllDiveCenters`, both `true`; update it to `false`, read back `false`.

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/core/database/migration_v313_dive_center_closed_test.dart test/features/dive_centers/domain/entities/dive_center_test.dart test/features/dive_centers/data/repositories/dive_center_repository_test.dart`
Expected: compile errors on `isPermanentlyClosed` and failing version expectations.

- [ ] **Step 3: Implement**

- Table: `BoolColumn get isPermanentlyClosed => boolean().withDefault(const Constant(false))();` with a doc comment naming #3379.
- Helper: `_addColumnIfMissing('dive_centers', 'is_permanently_closed', 'INTEGER NOT NULL DEFAULT 0 CHECK (is_permanently_closed IN (0, 1))')`.
- Rung: `if (from < 313) { await _assertDiveCenterClosedColumn(); } if (from < 313) await reportProgress();` with a comment: column only, no backfill, re-asserted in beforeOpen.
- Backstop: call it from `_assertChildRowColumns` with a v313 comment (every center read selects the whole row).
- Entity and repository: carry the field through every constructor, mapper and companion. The custom-row mapper reads `(row.data['is_permanently_closed'] as int? ?? 0) == 1`.
- Run `dart run build_runner build --delete-conflicting-outputs` (or `bash scripts/setup.sh` if denied).

- [ ] **Step 4: Run tests to verify they pass**

Run the Step 2 command, then `flutter test test/core/database`.
Expected: all pass.

- [ ] **Step 5: Commit**

`feat(dive-centers): store whether a dive center is permanently closed`

### Task 2: Strings, conflict field and query field

**Files:**
- Modify: all 11 `lib/l10n/arb/app_*.arb`, then `flutter gen-l10n`
- Modify: `lib/features/settings/presentation/conflicts/catalogue/site_trip_fields.dart`
- Modify: `lib/features/dive_centers/query/dive_center_query_entity.dart`
- Test: `test/features/dive_centers/query/dive_center_query_entity_test.dart`
- Test: `test/features/settings/presentation/conflicts/conflict_field_catalogue_test.dart`

**Interfaces:**
- Produces these ARB keys (English values fixed here):
  - `diveCenters_label_permanentlyClosed`: "Permanently closed"
  - `diveCenters_hint_permanentlyClosed`: "Still kept for past dives; left out of nearby centers in the picker."
  - `diveCenters_tag_closed`: "Closed"
  - `diveCenters_picker_nearSite`: "Near {siteName}" (String placeholder `siteName`)
  - `diveCenters_picker_nearThisDive`: "Near this dive"
  - `diveCenters_picker_allCenters`: "All dive centers"
  - `query_centers_closed`: "Permanently closed"

- [ ] **Step 1: Write the failing tests**

Query entity: the `closed` field exists, is `FieldType.bool`, its sql is `{r}.is_permanently_closed`, and a query `closed = true` against a seeded database returns only the closed center.
Conflict catalogue: the `isPermanentlyClosed` key resolves to a `FieldKind.boolean` field whose label is `diveCenters_label_permanentlyClosed`.

- [ ] **Step 2: Run them to verify they fail**

Run: `flutter test test/features/dive_centers/query/dive_center_query_entity_test.dart test/features/settings/presentation/conflicts/`
Expected: FAIL (field missing). The coverage test may also already fail on the new synced column, which confirms the entry is needed.

- [ ] **Step 3: Implement**

Add the ARB keys and translations, the `QueryField(key: 'closed', type: FieldType.bool, sql: '{r}.is_permanently_closed', emptySql: '0', labelKey: 'query_centers_closed')`, and the `'isPermanentlyClosed'` catalogue entry in alphabetical position.

- [ ] **Step 4: Run tests to verify they pass**

Same command, plus `flutter test test/l10n` if it exists. Expected: PASS.

- [ ] **Step 5: Commit**

`feat(dive-centers): name the permanently closed field in queries and sync conflicts`

### Task 3: Closed tag, edit switch and detail note

**Files:**
- Create: `lib/features/dive_centers/presentation/widgets/dive_center_closed_tag.dart`
- Modify: `lib/features/dive_centers/presentation/pages/dive_center_edit_page.dart` (state field, load, save, change detection, a `SwitchListTile` before the fill hours section)
- Modify: `lib/features/dive_centers/presentation/pages/dive_center_detail_page.dart` (`_HeaderSection`)
- Test: `test/features/dive_centers/presentation/widgets/dive_center_closed_tag_test.dart` (new)
- Test: `test/features/dive_centers/presentation/pages/dive_center_edit_page_closed_test.dart` (new, modelled on `dive_center_edit_page_fill_hours_test.dart`)
- Test: `test/features/dive_centers/presentation/pages/dive_center_detail_page_test.dart`

**Interfaces:**
- Produces: `class DiveCenterClosedTag extends StatelessWidget { const DiveCenterClosedTag({super.key}); }`: a small rounded outlined label reading `diveCenters_tag_closed` in `onSurfaceVariant`, not a `Chip`.
- Produces: `const double kClosedDiveCenterOpacity = 0.6;` in the same file, the one greying value every surface uses.

- [ ] **Step 1: Write the failing tests**

- Tag renders the text "Closed".
- Edit page: opening a closed center shows the switch on; toggling the switch on an open center and saving calls the repository update with `isPermanentlyClosed: true` (the only change made, Review Focus 5); the helper text is shown.
- Detail page: a closed center shows "Permanently closed" in the header; an open one does not.

- [ ] **Step 2: Run them to verify they fail**

Run: `flutter test test/features/dive_centers/presentation/widgets/dive_center_closed_tag_test.dart test/features/dive_centers/presentation/pages/`
Expected: FAIL.

- [ ] **Step 3: Implement** the tag, the switch (title `diveCenters_label_permanentlyClosed`, subtitle `diveCenters_hint_permanentlyClosed`), and the detail header line (a `do_not_disturb_on_outlined` icon and the label in `onSurfaceVariant`, under the name).

- [ ] **Step 4: Run the tests to verify they pass** (same command). Expected: PASS.

- [ ] **Step 5: Commit**

`feat(dive-centers): mark a dive center permanently closed from its edit page`

### Task 4: List, table and map

**Files:**
- Modify: `lib/features/dive_centers/presentation/widgets/dive_center_list_content.dart` (`DiveCenterListTile`, `_buildTableView`)
- Modify: `lib/features/dive_centers/presentation/widgets/compact_dive_center_list_tile.dart`
- Modify: `lib/features/dive_centers/presentation/widgets/dense_dive_center_list_tile.dart`
- Modify: `lib/shared/widgets/entity_table/entity_table_view.dart`
- Modify: `lib/features/dive_centers/presentation/widgets/dive_center_map_content.dart` (`_buildMarker`)
- Test: the existing tile, list content, map content tests under `test/features/dive_centers/presentation/widgets/`
- Test: `test/shared/widgets/entity_table/entity_table_view_test.dart` (or the existing file for this widget)

**Interfaces:**
- Consumes: `DiveCenterClosedTag`, `kClosedDiveCenterOpacity` (Task 3).
- Produces on `EntityTableView`: `final bool Function(T entity)? isEntityMuted;` (cells of a muted row render at `kClosedDiveCenterOpacity`-equivalent `0.6` opacity) and `final Widget? Function(T entity, F field)? cellTrailingBuilder;` (a widget after the cell text, inside the cell). Both null by default, so other tables are unchanged.

- [ ] **Step 1: Write the failing tests**

- Each of the three tiles: a closed center shows the "Closed" tag and its content sits under an `Opacity` of 0.6; an open center shows neither.
- `EntityTableView`: with `isEntityMuted` true for one entity, that row's cell is wrapped in `Opacity(0.6)` and the other is not; `cellTrailingBuilder` output appears in the named field's cell only.
- Map content: a closed center's marker is wrapped in `Opacity`; an open one is not.

- [ ] **Step 2: Run them to verify they fail**

Run: `flutter test test/features/dive_centers/presentation/widgets/ test/shared/widgets/entity_table/`
Expected: FAIL.

- [ ] **Step 3: Implement** the tag beside the name in each tile and in the table's `centerName` cell (via `cellTrailingBuilder`), muting via `isEntityMuted: (row) => row.center.isPermanentlyClosed`, and the faded marker (not faded while selected).

- [ ] **Step 4: Run the tests to verify they pass** (same command, plus `flutter test test/features/dive_centers`). Expected: PASS.

- [ ] **Step 5: Commit**

`feat(dive-centers): show closed dive centers greyed with a Closed tag`

### Task 5: Picker ranking

**Files:**
- Create: `lib/features/dive_centers/domain/services/dive_center_picker_ranking.dart`
- Test: `test/features/dive_centers/domain/services/dive_center_picker_ranking_test.dart` (new)

**Interfaces:**
- Produces:
  - `const double kNearbyDiveCenterRadiusMeters = 50000;`
  - `class DiveCenterPickerReference { const DiveCenterPickerReference({required this.point, this.siteName}); final GeoPoint point; final String? siteName; }` (null `siteName` means the point came from the dive's GPS or the device)
  - `DiveCenterPickerReference? resolveDiveCenterPickerReference({DiveSite? site, GeoPoint? entryLocation, GeoPoint? exitLocation, GeoPoint? deviceLocation})`
  - `class NearbyDiveCenter { const NearbyDiveCenter(this.center, this.distanceMeters); final DiveCenter center; final double distanceMeters; }`
  - `class DiveCenterPickerSections { const DiveCenterPickerSections({required this.nearby, required this.others}); final List<NearbyDiveCenter> nearby; final List<DiveCenter> others; }`
  - `DiveCenterPickerSections rankDiveCentersForPicker(List<DiveCenter> centers, {DiveCenterPickerReference? reference})`

- [ ] **Step 1: Write the failing tests**

```dart
// reference resolution order
expect(resolve(site: siteWithCoords, entryLocation: e, exitLocation: x, deviceLocation: d)!.siteName, 'Salt Pier');
expect(resolve(site: siteNoCoords, entryLocation: e, exitLocation: x)!.point, e);
expect(resolve(exitLocation: x, deviceLocation: d)!.point, x);
expect(resolve(deviceLocation: d)!.siteName, isNull);
expect(resolve(), isNull);
// ranking
// - nearby sorted by distance; equal distances sorted by name when they arrive Z before A
// - exactly 50000 m is nearby, 50001 m is not
// - closed centers never in nearby, and last in others (others: open alphabetical, then closed alphabetical, keeping input order within each group)
// - centers without coordinates go in others
// - no reference: nearby empty, others = open then closed
// - each center appears exactly once across both lists
```

Build test points with a known offset (for example latitude `0.0` vs `0.4496` is about 50 km) and compute expectations with `distanceMeters`, not hand-typed distances.

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/features/dive_centers/domain/services/dive_center_picker_ranking_test.dart`
Expected: FAIL (file missing).

- [ ] **Step 3: Implement.** Sort `nearby` with a comparator on distance then case-insensitive name; never rely on the stability of `List.sort`.

- [ ] **Step 4: Run it to verify it passes.** Expected: PASS.

- [ ] **Step 5: Commit**

`feat(dive-centers): rank dive centers by distance from the dive`

### Task 6: Picker sections and the dive edit page

**Files:**
- Modify: `lib/features/dive_centers/presentation/widgets/dive_center_picker.dart`
- Modify: `lib/features/dive_log/presentation/pages/dive_edit_page.dart` (`_showDiveCenterPicker`)
- Test: `test/features/dive_centers/presentation/widgets/dive_center_picker_test.dart` (new, or the existing picker test if one exists)

**Interfaces:**
- Consumes: Task 5's `resolveDiveCenterPickerReference`, `rankDiveCentersForPicker`; Task 3's tag and opacity.
- Produces: `DiveCenterPickerSheet({..., DiveCenterPickerReference? reference})`. The trip cylinder fill sheet passes nothing.

- [ ] **Step 1: Write the failing widget tests** (override `allDiveCentersProvider` and `settingsProvider`)

- With a site reference: header "Near Salt Pier", nearby rows in distance order with their formatted distance, header "All dive centers", the rest alphabetical.
- With a GPS reference (`siteName` null): header "Near this dive".
- Without a reference: no headers, closed centers last.
- A closed center that is the selected center shows in the alphabetical section, greyed, tagged and checked (Review Focus 4); tapping it calls `onCenterSelected`.
- Distances follow the diver's unit: with miles selected, the row shows "mi".

- [ ] **Step 2: Run it to verify it fails.**

Run: `flutter test test/features/dive_centers/presentation/widgets/dive_center_picker_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement.** Render the sections in the existing `ListView.builder` (headers as list items styled with `textTheme.labelMedium` in `onSurfaceVariant`). The distance goes in `trailing` as plain `Text`, or before the check icon in a `Row(mainAxisSize: min)` when selected. In `dive_edit_page.dart` pass `reference: resolveDiveCenterPickerReference(site: _selectedSite, entryLocation: _existingDive?.entryLocation, exitLocation: _existingDive?.exitLocation, deviceLocation: _currentLocation == null ? null : GeoPoint(_currentLocation!.latitude, _currentLocation!.longitude))`.

- [ ] **Step 4: Run it to verify it passes**, plus `flutter test test/features/dive_log/presentation/pages/` filtered to dive edit page tests and `test/features/trips` tests that open the fill sheet. Expected: PASS.

- [ ] **Step 5: Commit**

`feat(dive-centers): list nearby dive centers first in the picker`

### Task 7: Whole-branch checks

- [ ] `dart format .`
- [ ] `flutter analyze` with no issues
- [ ] `flutter test test/architecture/ test/shared/ test/features/dive_centers/ test/core/database/ test/features/settings/presentation/conflicts/`
- [ ] Generated l10n is current (`flutter gen-l10n` leaves no diff)
- [ ] Commit any formatting fixes as `chore: format`
