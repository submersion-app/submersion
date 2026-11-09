# Equipment List Foldable Groups Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Every group header on the equipment list page folds its group, location headers read as the strong level, and folds are saved per diver and synced.

**Architecture:** Folded group keys are stored as a JSON list in a new nullable `diver_settings` column inside the existing `ListArrangements` bundle (list arrangement sync fact group). A Riverpod notifier exposes the effective folded keys (saved ones, or session-only ones while a filter is active). A pure layout function turns arranged groups plus folded keys into flat rows and keyboard stops, replacing the show-more cap. A shared collapsible header, lifted from the dive site list, draws both header levels.

**Tech Stack:** Flutter, Riverpod (legacy `StateNotifier` settings, `Notifier` for new state), Drift, ARB l10n (11 locales).

**Spec:** `docs/design/specs/2026-11-09-equipment-list-foldable-groups-design.md`

## Global Constraints

- Default is open: only folded keys are stored; an empty or null list means every group open.
- Keys: `loc:<locationId>`, `loc:none`, `loc:<locationId>/type:<typeName>`, `loc:none/type:<typeName>`, `type:<typeName>`, `type:none`.
- Location header: `titleSmall` w700, location-kind icon, count at the end, indent 16, divider above every location header but the first.
- Type header: `titleSmall` w600, count at the end, indent 40 under a location, 16 when outermost.
- Chevron `chevron_right` folded, `expand_more` open; whole row is the tap target; `Semantics(button: true, expanded:)`.
- Table mode stays flat. No headers when type grouping and location grouping are both off.
- Folds made while `EquipmentFilterState.hasActiveFilters` is true are memory-only and every group renders open during that time.
- Temporary reveals are never written to settings.
- Every new user-facing string goes in all 11 ARB files with a real translation (the untranslated-values gate fails English copies).
- No em-dashes anywhere (code, comments, ARB, commits, PR).
- Schema version: the next free one after main's `currentSchemaVersion` (348 at the time of writing; re-check main before Task 2).
- `dart format .` before every commit; whole-repo `flutter analyze` before pushing.

## Review Focus

1. A diver folds a location, then deletes that location: the stale `loc:<id>` key must not crash or fold another place (Task 1 test `decode keeps unknown keys`, Task 5 test `stale key folds nothing`).
2. Malformed JSON in the column (hand-edited DB, newer build's shape): must read as "nothing folded", never throw (Task 1 test `malformed raw decodes to empty`).
3. The detail pane's item sits in a group the diver folds: the fold must hold, the pane keeps the item, the list does not re-open it on the next rebuild (Task 6 test `folding the selected item's group sticks`).
4. Filter on, fold something, filter off: saved folds return untouched and nothing was written during the filter (Task 3 test `session folds are dropped and never saved`).
5. Two devices fold different groups: the list arrangement clock decides; the later write wins whole (Task 2 sync test `collapsed groups ride the list arrangement group`).

---

### Task 1: Fold keys codec

**Files:**
- Create: `lib/features/equipment/domain/models/equipment_fold_keys.dart`
- Test: `test/features/equipment/domain/models/equipment_fold_keys_test.dart`

**Interfaces:**
- Produces:
  - `const int kMaxStoredFoldKeys = 300;`
  - `String locationFoldKey(String? locationId)`
  - `String typeFoldKey(EquipmentType? type, {String? locationKey})`
  - `List<String> decodeFoldKeys(String? raw)`
  - `String encodeFoldKeys(List<String> keys)`
  - `List<String> toggleFoldKey(List<String> keys, String key, {int cap = kMaxStoredFoldKeys})`

- [ ] **Step 1: Write the failing tests**

```dart
test('location keys', () {
  expect(locationFoldKey('abc'), 'loc:abc');
  expect(locationFoldKey(null), 'loc:none');
});
test('type keys, nested and outermost', () {
  expect(typeFoldKey(EquipmentType.bcd), 'type:bcd');
  expect(typeFoldKey(null), 'type:none');
  expect(typeFoldKey(EquipmentType.secondStage, locationKey: 'loc:abc'),
      'loc:abc/type:secondStage');
});
test('malformed raw decodes to empty', () {
  for (final raw in [null, '', '  ', '{', '{"a":1}', '42']) {
    expect(decodeFoldKeys(raw), isEmpty, reason: '$raw');
  }
});
test('non-string entries are skipped, order kept', () {
  expect(decodeFoldKeys('["loc:a", 3, "type:bcd"]'), ['loc:a', 'type:bcd']);
});
test('decode keeps unknown keys', () {
  expect(decodeFoldKeys('["future:thing"]'), ['future:thing']);
});
test('round trip', () {
  const keys = ['loc:a', 'loc:a/type:bcd'];
  expect(decodeFoldKeys(encodeFoldKeys(keys)), keys);
});
test('toggle appends then removes', () {
  expect(toggleFoldKey(['a'], 'b'), ['a', 'b']);
  expect(toggleFoldKey(['a', 'b'], 'a'), ['b']);
});
test('toggle drops the oldest past the cap', () {
  expect(toggleFoldKey(['a', 'b', 'c'], 'd', cap: 3), ['b', 'c', 'd']);
});
```

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/equipment/domain/models/equipment_fold_keys_test.dart`
Expected: FAIL, functions not defined.

- [ ] **Step 3: Implement the six members in `equipment_fold_keys.dart`**

`decodeFoldKeys` wraps `jsonDecode` in try/catch and accepts only a top-level list. Functions return new lists; never mutate the argument. Doc comment names the key grammar from Global Constraints.

- [ ] **Step 4: Run to verify pass** (same command, expect PASS)

- [ ] **Step 5: Commit**

```bash
git add lib/features/equipment/domain/models/equipment_fold_keys.dart test/features/equipment/domain/models/equipment_fold_keys_test.dart
git commit -m "feat(equipment): fold key codec for the equipment list"
```

---

### Task 2: Store folded keys per diver (schema, settings, sync)

Follow the `firstDayOfWeek` commit `869017751fb` for the migration shape, but this is a nullable column inside the list arrangement bundle (#3783), so there is no serializer default and no `AppSettings` field: it rides `ListArrangements`.

**Files:**
- Modify: `lib/core/database/tables/diver_tables.dart` (after `equipmentGroupByLocation`, ~:417): `TextColumn get equipmentCollapsedGroups => text().nullable()();` with a doc comment (it feeds the generated SQL notes): "vNNN: the Equipment page's folded group keys, a JSON list. Null or empty means every group open."
- Modify: `lib/core/database/database.dart`: bump `currentSchemaVersion`; append the version to the floor list with a comment that a nullable column an older peer omits leaves the floor alone.
- Create: `lib/core/database/migrations/helpers/equipment_collapsed_groups_migrations.dart` (`part of`), `Future<void> _assertEquipmentCollapsedGroupsColumn()` adding `equipment_collapsed_groups TEXT` via `_addColumnIfMissing`.
- Modify: `lib/core/database/migrations/app_database_migrations.dart` (part line), `ladder/rungs_v340_onward.dart` (rung + `reportProgress`), `before_open_settings_columns.dart` (backstop).
- Modify: `lib/features/settings/domain/list_arrangements.dart`: `final String? equipmentCollapsedGroups;` in the constructor, `copyWith`, `_props`.
- Modify: `lib/features/settings/data/repositories/list_arrangement_columns.dart`: both directions.
- Modify: `lib/core/services/sync/sync_fact_groups.dart`: `'equipmentCollapsedGroups': 'equipment_collapsed_groups'` in `diverSettingsListArrangement.columns`.
- Modify: `lib/features/settings/presentation/conflicts/catalogue/diver_settings_fields.dart`: `'equipmentCollapsedGroups'` as `FieldKind.opaque` with label key `settings_conflict_field_equipmentCollapsedGroups` ("Equipment folded groups"), in all 11 ARB files next to `settings_conflict_field_equipmentGroupByLocation`.
- Modify: `lib/features/settings/presentation/providers/list_arrangement_writes.dart`: `Future<void> setEquipmentCollapsedGroups(List<String> keys)`.
- Regenerate: `dart run tool/generate_sql_column_notes.dart`; `dart run build_runner build --delete-conflicting-outputs` (unfiltered, in the background); `flutter gen-l10n`.
- Test: `test/core/database/migration_vNNN_equipment_collapsed_groups_test.dart`, `test/features/settings/domain/list_arrangements_test.dart`, `test/features/settings/data/repositories/diver_settings_repository_list_arrangements_test.dart`, `test/core/services/sync/diver_settings_list_arrangement_sync_test.dart`, `test/features/settings/presentation/providers/list_arrangement_writes_test.dart`.

**Interfaces:**
- Consumes: `encodeFoldKeys` (Task 1).
- Produces: `ListArrangements.equipmentCollapsedGroups` (`String?`, raw JSON); `SettingsNotifier.setEquipmentCollapsedGroups(List<String> keys)` (extension `ListArrangementWrites`).

- [ ] **Step 1: Write the failing tests**
  - Migration test modelled on `migration_v343_first_day_of_week_test.dart`: `vNNN is in the ladder`, `the new column is additive and kept the floor`, `upgrading from vNNN-1 adds a null column`, `a database already carrying the column keeps its value` (stored `'["loc:a"]'`).
  - `list_arrangements_test.dart`: `copyWith keeps equipmentCollapsedGroups`, equality includes it.
  - Repository test: saving `ListArrangements(equipmentCollapsedGroups: '["loc:a"]')` reads back the same string.
  - Sync test `collapsed groups ride the list arrangement group`: the field is serialized under the `listArrangement` group and applied by its clock, like `equipmentGroupByLocation` in the same file.
  - Writes test: `setEquipmentCollapsedGroups(['loc:a','type:bcd'])` stores `'["loc:a","type:bcd"]'`; `setEquipmentCollapsedGroups([])` stores `'[]'` (never null: a changed list stays changed).

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/core/database/migration_vNNN_equipment_collapsed_groups_test.dart test/features/settings test/core/services/sync/diver_settings_list_arrangement_sync_test.dart`
Expected: FAIL (missing column / field).

- [ ] **Step 3: Make the changes listed under Files**

- [ ] **Step 4: Run to verify pass**, then the whole `test/core/database` and `test/core/services/sync` folders (catalogue and fact-group completeness guards live there).

- [ ] **Step 5: Commit**

```bash
git add lib/core/database lib/core/services/sync/sync_fact_groups.dart lib/features/settings lib/features/agent_access/data/resources/sql_column_notes.generated.dart lib/l10n test/core test/features/settings
git commit -m "feat(settings): store the equipment list's folded groups per diver"
```

---

### Task 3: Folds notifier

**Files:**
- Create: `lib/features/equipment/presentation/providers/equipment_fold_providers.dart`
- Test: `test/features/equipment/presentation/providers/equipment_fold_providers_test.dart`

**Interfaces:**
- Consumes: `decodeFoldKeys`, `toggleFoldKey` (Task 1); `setEquipmentCollapsedGroups` (Task 2); `effectiveEquipmentFilterProvider`; `settingsProvider`.
- Produces:
  - `final equipmentFoldsProvider = NotifierProvider<EquipmentFoldsNotifier, List<String>>(EquipmentFoldsNotifier.new);` state = the effective folded keys.
  - `class EquipmentFoldsNotifier` with `bool get isSessionOnly`, `void toggle(String key)`, `void expandAll()`, `void collapseAll()`.
  - `final equipmentOuterGroupKeysProvider = StateProvider<List<String>>((ref) => const []);` (same legacy style as `highlightedEquipmentIdProvider`): the outermost fold keys the list currently shows, published by the list (Task 6), read by `collapseAll` and by the overflow menu (Task 7).

`build()` watches `effectiveEquipmentFilterProvider.select((f) => f.hasActiveFilters)`. Active: returns `const []` and `isSessionOnly` is true. Inactive: returns `decodeFoldKeys(settings.listArrangements.equipmentCollapsedGroups)`. Mutators set `state` first, then, only when not session-only, call `setEquipmentCollapsedGroups(state)` unawaited. `collapseAll` adds every key in `equipmentOuterGroupKeysProvider` not already folded; `expandAll` sets `[]`.

- [ ] **Step 1: Write the failing tests** (ProviderContainer with `MockSettingsNotifier` from `test/helpers/mock_providers.dart` and an overridden `equipmentFilterProvider`)
  - `reads saved folds`: settings hold `'["loc:a"]'`, state is `['loc:a']`.
  - `toggle saves`: toggle `type:bcd`, mock settings now hold `'["loc:a","type:bcd"]'`.
  - `session folds are dropped and never saved`: set a type filter, toggle `loc:b`, state `['loc:b']`, settings unchanged; clear the filter, state back to `['loc:a']`.
  - `collapseAll folds outer keys only`: outer keys `['loc:a','loc:b']`, saved `['loc:a/type:bcd']`, result contains all three.
  - `expandAll clears`: state `[]`, settings `'[]'`.

- [ ] **Step 2: Run to verify failure**: `flutter test test/features/equipment/presentation/providers/equipment_fold_providers_test.dart` (FAIL)
- [ ] **Step 3: Implement**
- [ ] **Step 4: Run to verify pass**
- [ ] **Step 5: Commit** `feat(equipment): folds notifier with session folds under filters`

---

### Task 4: Shared collapsible group header

**Files:**
- Create: `lib/shared/widgets/collapsible_group_header.dart`
- Modify: `lib/features/dive_sites/presentation/widgets/site_picker/grouped_site_list_view.dart` (`SiteGroupHeader.build` returns a `CollapsibleGroupHeader`)
- Test: `test/shared/widgets/collapsible_group_header_test.dart`; existing `test/features/dive_sites/presentation/widgets/site_picker/grouped_site_list_view_test.dart` must stay green unchanged.

**Interfaces:**
- Produces: `CollapsibleGroupHeader({Key? key, required String label, required String countLabel, required bool isExpanded, required VoidCallback onTap, double indent = 16, Widget? leading, String? summary, FontWeight titleWeight = FontWeight.w600, bool isHeading = false})`. No l10n inside (callers pass strings), so shared-widget l10n never leaks into other features' tests.

Layout is today's `SiteGroupHeader` row (padding `fromSTEB(indent, 12, 16, 12)`, chevron, 12 gap, title `titleSmall` with `titleWeight`, count `labelMedium` onSurfaceVariant), plus `leading` after the chevron and, when `summary` is non-null and `!isExpanded`, a second line in `bodySmall` onSurfaceVariant under the title. `Semantics(button: true, expanded: isExpanded, header: isHeading)`.

- [ ] **Step 1: Failing tests**: `shows chevron_right folded and expand_more open`; `summary only while folded`; `tap anywhere on the row calls onTap`; `semantics: button, expanded, heading`; `title uses the given weight` (find the title `Text`, `style.fontWeight == FontWeight.w700`).
- [ ] **Step 2: Run, FAIL**: `flutter test test/shared/widgets/collapsible_group_header_test.dart`
- [ ] **Step 3: Implement, and make `SiteGroupHeader` delegate** with `countLabel: context.l10n.diveSites_group_siteCount(siteCount)`.
- [ ] **Step 4: Run both test files, PASS**
- [ ] **Step 5: Commit** `refactor(shared): lift the site list's group header into a shared collapsible header`

---

### Task 5: Row layout, keyboard stops and folded summaries

`equipment_list_content.dart` is 1830 lines, well over the 800-line limit. The row model and its flattening move out of it here, so Task 6 shrinks the file instead of growing it.

**Files:**
- Create: `lib/features/equipment/presentation/utils/equipment_list_rows.dart`
- Create: `lib/features/equipment/presentation/utils/equipment_fold_summary.dart`
- Modify: all 11 `lib/l10n/arb/app_*.arb` (anchor next to `equipment_location_groupCount`; every ARB is feature-grouped)
- Test: `test/features/equipment/presentation/utils/equipment_list_rows_test.dart`, `test/features/equipment/presentation/utils/equipment_fold_summary_test.dart`

**Interfaces:**
- Consumes: `locationFoldKey`, `typeFoldKey` (Task 1); `EquipmentGroup`, `EquipmentLocationSection`; `KeyboardNavStops` (`lib/shared/widgets/master_detail/keyboard_nav_stops.dart`).
- Produces:

```dart
sealed class EquipmentListRow { const EquipmentListRow(); }
class EquipmentLocationHeadingRow extends EquipmentListRow {
  final EquipmentLocation? location; final String foldKey;
  final List<(EquipmentType, int)> typeCounts; // section order, typed groups only
  final List<EquipmentItem> items; final bool isExpanded; final bool isFirst;
}
class EquipmentTypeHeadingRow extends EquipmentListRow {
  final EquipmentType type; final String foldKey; final String? parentKey;
  final List<EquipmentItem> items; final bool isExpanded;
}
class EquipmentItemRow extends EquipmentListRow {
  final EquipmentItem item; final String? headerKey; // innermost open header
}
class EquipmentRowLayout {
  final List<EquipmentListRow> rows;
  final Map<String, List<String>> foldKeysByItem; // every key hiding an item, outer first, folded or not
  final List<String> outerKeys;
  final KeyboardNavStops navStops; // headers as 'group:<foldKey>', items by id
}
EquipmentRowLayout layoutEquipmentRows({
  required List<EquipmentGroup> groups,
  List<EquipmentLocationSection>? sections,
  required Set<String> collapsed, // folded minus revealed
});
String equipmentGroupNavKey(String foldKey) => 'group:$foldKey';

String? foldedLocationSummary(AppLocalizations l10n, List<(EquipmentType, int)> typeCounts);
String? foldedTypeSummary(AppLocalizations l10n, {required int serviceDueCount});
String foldedSelectionSummary(AppLocalizations l10n, {required int selected, required int total});
```

Rules: a group whose `type` is null gets no header, cannot fold, and its items' `headerKey` is the location key (or null). A folded location emits only its heading row. A folded type emits only its heading row. `foldedLocationSummary` joins at most three `equipment_group_foldedTypeCount` entries with `' · '`, then appends `equipment_group_foldedMoreTypes(rest)`; null when `typeCounts` is empty. `foldedTypeSummary` is null when the count is 0.

New ARB keys (English):
- `equipment_group_foldedTypeCount`: `"{type} {count}"` (type String, count int; locales may reorder)
- `equipment_group_foldedMoreTypes`: `"{count, plural, one{and {count} more} other{and {count} more}}"`
- `equipment_group_foldedServiceDue`: `"{count, plural, one{{count} service due} other{{count} service due}}"`
- `equipment_group_foldedSelected`: `"{selected} of {total} selected"`
- `equipment_list_expandAllGroups`: `"Expand all"`
- `equipment_list_collapseAllGroups`: `"Collapse all"`

Use `one{...{count}...}`, never `=1{1 ...}` (the CLDR `one` category covers zero in fr and pt).

- [ ] **Step 1: Failing tests** (`equipment_list_rows_test.dart`)
  - `ungrouped list has no headers`: one null-type group, rows are items only, `outerKeys` empty.
  - `type groups only`: two typed groups, rows `[type, item, type, item]`, `outerKeys == ['type:bcd','type:regulator']`.
  - `by location nests types`: row kinds and `parentKey == 'loc:g'` on the nested type row; first location row `isFirst`.
  - `folded location hides its types and items`: collapsed `{'loc:g'}`, only the heading row for `g`, its `typeCounts` still filled.
  - `folded type under an open location`: collapsed `{'loc:g/type:bcd'}`.
  - `stale key folds nothing`: collapsed `{'loc:deleted'}` yields the same rows as `{}`.
  - `foldKeysByItem lists outer then inner`: item in garage BCDs maps to `['loc:g','loc:g/type:bcd']`.
  - `nav stops skip folded rows`: `navStops.keys` for a folded type has the header stop and no item ids; `headerFor(itemId)` is the type header's nav key.
- [ ] **Step 2: Failing tests** (`equipment_fold_summary_test.dart`, English l10n)
  - `foldedLocationSummary(l10n, [(bcd,2),(secondStage,1),(tank,4)]) == 'BCD 2 · Second stage 1 · Tank 4'` (use the real `localizedName` labels in the expectation).
  - Five types: `'BCD 2 · Second stage 1 · Tank 4 · and 2 more'` (the "more" entry is joined with the same `' · '`).
  - `foldedTypeSummary(serviceDueCount: 0)` is null; `1` gives `'1 service due'`.
  - `foldedSelectionSummary(selected: 2, total: 8) == '2 of 8 selected'`.
- [ ] **Step 3: Run, FAIL**: `flutter test test/features/equipment/presentation/utils/`
- [ ] **Step 4: Implement both files; add the ARB keys to all 11 locales with translations; `flutter gen-l10n`**
- [ ] **Step 5: Run, PASS**, plus `flutter test test/l10n`
- [ ] **Step 6: Commit** `feat(equipment): lay out foldable equipment rows and their summaries`

---

### Task 6: Wire folds into the equipment list

**Files:**
- Modify: `lib/features/equipment/presentation/widgets/equipment_list_content.dart`
- Modify: `lib/features/equipment/presentation/widgets/equipment_location_group_header.dart` (becomes a wrapper over `CollapsibleGroupHeader`: icon leading, `titleWeight: FontWeight.w700`, `isHeading: true`, adds `isExpanded`, `onTap`, `summary`; keeps its `ValueKey('equipment-location-header-<id|none>')`)
- Create: `lib/features/equipment/presentation/widgets/equipment_type_fold_header.dart` (`EquipmentTypeFoldHeader`: `CollapsibleGroupHeader` with the type label, `isHeading: true`, `indent` 40 or 16, key `ValueKey('equipment-type-fold-<foldKey>')`). `EquipmentGroupHeader` stays as it is for the pickers and set pages.
- Delete: `lib/features/equipment/presentation/utils/equipment_group_cap.dart`, `lib/features/equipment/presentation/widgets/equipment_group_show_more.dart`, `test/features/equipment/presentation/utils/equipment_group_cap_test.dart` (no other users; grep first).
- Test: `test/features/equipment/presentation/widgets/equipment_list_content_test.dart` (replace the `show more within a type group (#3993)` group and the `each place caps and expands...` test; switch finders from `EquipmentGroupHeader` to `EquipmentTypeFoldHeader`; give `_buildPhoneOverrides` an `AppSettings? settings` parameter passed to `MockSettingsNotifier`).

**Interfaces:**
- Consumes: Tasks 3, 4, 5. `equipmentServiceUrgencyProvider` (`Map<String, ServiceClockStatus>`, severity `ServiceClockSeverity { ok, dueSoon, overdue }`).

Behaviour to build in `_buildEquipmentList`:
- Replace `_expandedGroups`, `_groupKey` and `_rowsForGroup` with `layoutEquipmentRows(groups:, sections:, collapsed: folds.toSet().difference(_revealed))`.
- Publish `layout.outerKeys` to `equipmentOuterGroupKeysProvider` in a post-frame callback, only when it changed (the `pruneToSettled` pattern above it).
- Temporary reveal, widget state `Set<String> _revealed` and `String? _revealedFor`: when `widget.selectedId ?? _restoreTargetId` is non-null, differs from `_revealedFor`, and `_selectionFromList` is false, set `_revealed = layout.foldKeysByItem[id]` (replacing the old set) and `_revealedFor = id`, then lay out again before scrolling. Never write settings for it.
- Header tap: if the key is in `_revealed` and in the folds, remove it from `_revealed` (folds again, no write); otherwise `equipmentFoldsProvider.notifier.toggle(key)`.
- Keyboard: `KeyboardListNavigator(keys: layout.navStops.keys, ...)` with `onActivate`, `onExpand`, `onCollapse` wired as in `site_list_content.dart` around :1574-1607; headers wrapped in `KeyboardListItem(navigationKey: equipmentGroupNavKey(foldKey))`; `onMove` ignores header stops.
- Summaries: folded location uses `foldedLocationSummary`; folded type uses `foldedTypeSummary` with the count of its items whose urgency severity is not `ok`. Watch `equipmentServiceUrgencyProvider` only when at least one type heading row is folded. In selection mode, a folded header holding checked items shows `foldedSelectionSummary` instead.
- Divider above every location heading where `!isFirst`.
- Selection: `SelectableListScope.selectableIds` stays every matching id (select all reaches folded items). The page has no shift-range selection today (`_handleRowTap` only enters selection), so there is nothing to change for ranges.
- Update the doc comment at the old "headings are labels, not folds" line.

- [ ] **Step 1: Failing widget tests** (in `equipment_list_content_test.dart`, new group `foldable groups (#4184)`)
  - `tapping a location header folds it and saves`: rows of that place disappear, header shows the type summary, mock settings hold its key.
  - `saved folds apply on open`: settings `'["loc:garage-id"]'`, garage items absent.
  - `nested type header folds alone`.
  - `an active filter opens every group and saves nothing`: saved folds present, `filter: EquipmentFilterState(type: EquipmentType.bcd)`, folded items visible, toggling writes nothing.
  - `switching group by location keeps the saved keys`: saved `['loc:g','type:bcd']`; grouped by location the garage is folded; ungrouped the BCD group is folded.
  - `a deep link reveals a folded item without writing settings`: pump with `selectedId` inside a folded place, the tile is visible, settings unchanged.
  - `folding the selected item's group sticks`: after the reveal, tap that header, the group folds and stays folded across a rebuild with the same `selectedId`.
  - `keyboard: Left on an item folds its group, Right opens it, Enter toggles`.
  - `folded header shows N of M selected in selection mode`.
  - `type header shows service due when folded` (override `equipmentServiceUrgencyProvider` with one `dueSoon` item).
  - `location headers are bold`: the location title `Text` has `FontWeight.w700`.
- [ ] **Step 2: Run, FAIL**: `flutter test test/features/equipment/presentation/widgets/equipment_list_content_test.dart`
- [ ] **Step 3: Implement**; delete the cap files after `grep -rn "equipment_group_cap\|EquipmentGroupShowMore" lib test` shows no other users.
- [ ] **Step 4: Run the file, then `flutter test test/features/equipment test/features/dive_sites test/architecture test/shared`, PASS**
- [ ] **Step 5: Commit** `feat(equipment): fold equipment list groups, bold location headers (#4184)`

---

### Task 7: Expand all and Collapse all

**Files:**
- Modify: `lib/features/equipment/presentation/pages/equipment_list_page.dart` (overflow `PopupMenuButton` around :370)
- Test: `test/features/equipment/presentation/pages/equipment_list_page_test.dart` (or the existing page test file that covers the overflow menu; find it with `grep -rln "view_detailed\|ListViewModeToggle" test/features/equipment`)

**Interfaces:**
- Consumes: `equipmentFoldsProvider` (`expandAll()`, `collapseAll()`), `equipmentOuterGroupKeysProvider` (Task 3).

Entries `fold_expand_all` and `fold_collapse_all`, labels `equipment_list_expandAllGroups` / `equipment_list_collapseAllGroups`, shown only when the view mode is not table and `equipmentOuterGroupKeysProvider` is non-empty, read as the menu opens like `currentMode`.

- [ ] **Step 1: Failing tests**: `menu offers expand and collapse all when grouped`; `not in table mode`; `collapse all folds every location` (then every location header shows its summary); `expand all opens everything`.
- [ ] **Step 2: Run, FAIL**
- [ ] **Step 3: Implement**
- [ ] **Step 4: Run, PASS**
- [ ] **Step 5: Commit** `feat(equipment): expand all and collapse all equipment groups`

---

### Task 8: Verify and prepare the PR

- [ ] **Step 1:** `dart format .` then `flutter analyze` (whole repo). Expected: no issues.
- [ ] **Step 2:** `flutter test test/architecture test/shared test/core/database test/core/services/sync test/features/equipment test/features/dive_sites test/features/settings test/l10n`. Expected: all pass. Re-run under `TZ=Australia/Sydney` if anything date-related fails only in CI.
- [ ] **Step 3:** Run the app (macOS dev build with its own `SUBMERSION_DB_PATH`), group by location, and confirm by eye: bold location headers, indented type headers, folding, folded summaries, Expand all and Collapse all, light and dark, phone and desktop widths.
- [ ] **Step 4:** Capture before (from main) and after screenshots per the global PR screenshot rules, upload through the project's current secret gist.
- [ ] **Step 5:** Open the PR with `Closes #4184` and `Part of #3364` in the body, screenshots embedded, no attribution lines.
