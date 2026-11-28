# Equipment list assembly view Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task (inline, in this session). Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fold each assembly's parts (components and installed parts) under the assembly's row on the Equipment list, behind a synced "Show parts under their assembly" switch that is on by default with every assembly folded.

**Architecture:** A pure part graph (`EquipmentPartTree`) unions component edges and installed-in edges. `layoutEquipmentRows` gains an optional nesting pass that walks that graph inside each placement unit (a place section, or the whole list), emitting indented item rows and an `asm:<id>` fold per assembly. Folds keep using the synced fold list; an `asm:` key there means "opened", and the page resolves stored keys to one "collapsed now" set before layout so the reveal and toggle logic stay as they are.

**Tech Stack:** Flutter, Riverpod (`core/providers/provider.dart`), flutter_test.

**Spec:** `docs/design/specs/2026-11-27-equipment-assembly-view-design.md` (issue #5071).

## Global Constraints

- No schema change, no migration rung, no new `list_arrangements` column.
- `nestParts` lives in `EquipmentArrangement` JSON under key `nestParts`; absent or non-bool reads as `true`.
- Assembly fold key is `asm:<equipmentId>`; its presence in the stored list means opened (outside a filter).
- Table mode never nests. Pickers, PDFs, exports, the inventory report and the dive surfaces' arrange sheet are unchanged.
- A part is never hidden: unplaceable parts fall back to the top level in their own type group.
- Indent grows one step per level and stops growing after level 4.
- Chevron: semantics label "Show parts" / "Hide parts", 48 dp hit area.
- No new code in `equipment_list_content.dart` beyond wiring (the file is at 1800 lines); new logic goes in new files.
- Every new user-visible string goes into every locale ARB (feature-grouped, anchored on a neighbouring key of the same group), then `flutter gen-l10n`.
- `dart format .`, `flutter analyze`, and only the test files changed or added (never a folder, never the whole suite).

## Review Focus

1. A search that matches a part but not its assembly: the part shows at the top level in its own type group, fully visible. (Task 4 test `orphaned part stays top level`.)
2. A diver with no assemblies: rows, headings, keyboard stops and Expand/Collapse menu identical to today. (Task 4 test `no parts graph leaves layout unchanged`; Task 7 widget test `no assemblies, no chevrons`.)
3. Opening a nested part from outside the list (dive detail link) with its assembly folded: the part's whole path opens once, and the diver can fold it again. (Task 4 test `reveal path lists the first path's asm keys`; Task 7 widget test `deep link opens the folded assembly`.)
4. A part shared by two assemblies, both open: both rows render, keyboard Down passes each once, selecting it marks both. (Task 4 test `shared part gets a second nav key`; Task 7 widget test `shared part arrow navigation`.)
5. A corrupt component loop (A part of B, B part of A, no top-level entry): both items still show. (Task 4 test `loop members still show`.)

---

### Task 1: `nestParts` axis and unknown-key preservation on `EquipmentArrangement`

**Files:**
- Modify: `lib/features/equipment/domain/models/equipment_arrangement.dart`
- Test: `test/features/equipment/domain/equipment_arrangement_test.dart`

**Interfaces:**
- Produces: `EquipmentArrangement.nestParts` (bool, default `true`), `copyWith({bool? nestParts})`, JSON key `nestParts`; unknown JSON keys round-trip.

- [ ] **Step 1: Write the failing tests** (new `group('nestParts', ...)`)
  - `defaults.nestParts` is `true`.
  - `EquipmentArrangement.fromJson({})` gives `nestParts == true`; `{'nestParts': false}` gives `false`; `{'nestParts': 'no'}` gives `true`.
  - `toJson()` contains `'nestParts': false` after `copyWith(nestParts: false)`.
  - Two arrangements differing only in `nestParts` are not `==` and (normally) have different `hashCode`.
  - `fromJson({'futureAxis': 3, 'groupByType': false}).toJson()['futureAxis'] == 3`, and `copyWith(groupByType: true)` on it still writes `futureAxis`.
- [ ] **Step 2: Run** `flutter test test/features/equipment/domain/equipment_arrangement_test.dart`; expect the new tests to FAIL.
- [ ] **Step 3: Implement.** Add `final bool nestParts;` and a private `final Map<String, Object?> _extras` (const `{}` default, unmodifiable), filled in `fromJson` with every key not in the known set (`typeOrder`, `typeOrderDescending`, `groupByType`, `itemSortField`, `itemSortDirection`, `nestParts`). `toJson` writes `{..._extras, ...known}`. `copyWith` carries `_extras`. `==` compares `nestParts` and `_extras` (`mapEquals`); `hashCode` includes `nestParts`. Update the doc comment's axis list.
- [ ] **Step 4: Run** the same file; expect PASS. Also run `test/core/services/pdf_equipment_arrangement_test.dart` and `test/features/settings/data/equipment_arrangement_settings_test.dart` (they build arrangements and compare JSON).
- [ ] **Step 5: Commit** `feat(equipment): add the nestParts arrangement axis`.

### Task 2: `EquipmentPartTree`

**Files:**
- Create: `lib/features/equipment/domain/services/equipment_part_tree.dart`
- Test: `test/features/equipment/domain/services/equipment_part_tree_test.dart`

**Interfaces:**
- Consumes: `ComponentsIndex` (`byParent`, sorted), `EquipmentItem.parentEquipmentId`, `EquipmentItem.cellSlot`.
- Produces:
  ```dart
  class EquipmentPartTree {
    factory EquipmentPartTree.build({
      required ComponentsIndex components,
      required Iterable<EquipmentItem> items,
    });
    static const empty;
    List<String> childrenOf(String id);   // display order, deduplicated
    List<String> parentsOf(String id);    // both links, deduplicated
    bool hasParts(String id);
    Set<String> get assemblyIds;          // ids with at least one child
  }
  ```

- [ ] **Step 1: Write the failing tests**
  - `components come first in template order`: index rows P->c2 (sortOrder 0), P->c1 (sortOrder 1); `childrenOf('P') == ['c2', 'c1']`.
  - `installed parts follow by cell slot then name`: items i3 (slot 3, name 'a'), i1 (slot 1, name 'z'), iN (no slot, name 'b'), iM (no slot, name 'a'), all `parentEquipmentId: 'P'`, plus component c1; `childrenOf('P') == ['c1', 'i1', 'i3', 'iM', 'iN']`.
  - `item both component and installed in the same host is listed once`.
  - `parentsOf unions both links`: x is a component of A and installed in B gives `{'A', 'B'}`.
  - `installed-in to an id not in items still counts` (parent id need not be in `items`).
  - `assemblyIds` holds exactly the ids with children; `hasParts` agrees.
- [ ] **Step 2: Run** `flutter test test/features/equipment/domain/services/equipment_part_tree_test.dart`; expect FAIL (file missing).
- [ ] **Step 3: Implement** in the new file. Installed children sort: `cellSlot ?? 1 << 20`, then `name` case-insensitively, then id (same key as `childEquipmentProvider`). Maps built once, exposed unmodifiable.
- [ ] **Step 4: Run** the test; expect PASS.
- [ ] **Step 5: Commit** `feat(equipment): add the part tree over components and installed parts`.

### Task 3: Assembly fold keys and the folds notifier

**Files:**
- Modify: `lib/features/equipment/domain/models/equipment_fold_keys.dart`
- Modify: `lib/features/equipment/presentation/providers/equipment_fold_providers.dart`
- Test: `test/features/equipment/domain/models/equipment_fold_keys_test.dart`
- Test: `test/features/equipment/presentation/providers/equipment_fold_providers_test.dart`

**Interfaces:**
- Produces:
  ```dart
  String assemblyFoldKey(String equipmentId);          // 'asm:<id>'
  bool isAssemblyFoldKey(String key);
  /// Keys folded now: stored type/place keys, plus asm:<id> for each id in
  /// [assemblyIds] that is folded (stored-absent when !assembliesStartOpen,
  /// stored-present when assembliesStartOpen).
  Set<String> resolveCollapsedKeys(
    Iterable<String> stored,
    Iterable<String> assemblyIds, {
    required bool assembliesStartOpen,
  });
  // EquipmentFoldsNotifier:
  bool get assembliesStartOpen;                         // true while a filter is on
  void expandAll({Iterable<String> assemblyIds = const []});
  void collapseAll(List<String> outer, {Iterable<String> assemblyIds = const []});
  ```
- `toggle(key)` is unchanged (presence flip works for both semantics).

- [ ] **Step 1: Write the failing tests**
  - Keys: `assemblyFoldKey('x') == 'asm:x'`; `isAssemblyFoldKey` true for it, false for `'type:bcd'` and `'loc:none/type:bcd'`.
  - `resolveCollapsedKeys(['type:bcd', 'asm:a'], ['a', 'b'], assembliesStartOpen: false) == {'type:bcd', 'asm:b'}`.
  - Same stored keys with `assembliesStartOpen: true` gives `{'type:bcd', 'asm:a'}`.
  - A stored `asm:` key for an id not in `assemblyIds` resolves to nothing.
  - Notifier, no filter: `expandAll(assemblyIds: ['a', 'b'])` stores exactly `['asm:a', 'asm:b']`; then `collapseAll(['type:bcd'], assemblyIds: ['a', 'b'])` stores `['type:bcd']`.
  - Notifier, filter on: `assembliesStartOpen` is true; `expandAll(assemblyIds: ['a'])` leaves state `[]`; `collapseAll([], assemblyIds: ['a'])` gives `['asm:a']`; nothing is written to settings.
- [ ] **Step 2: Run** both test files; expect FAIL.
- [ ] **Step 3: Implement.** Extend the key file's header comment with the `asm:` rule (presence = opened outside a filter, = folded during one). In the notifier expose `_sessionOnly` as `assembliesStartOpen`; `expandAll` sets folds to `assembliesStartOpen ? [] : asm keys`; `collapseAll` folds outer keys as now, then removes every `asm:` key (normal) or adds every assembly's key (filter on).
- [ ] **Step 4: Run** both files; expect PASS.
- [ ] **Step 5: Commit** `feat(equipment): fold keys for assemblies`.

### Task 4: Nesting in the row layout

**Files:**
- Modify: `lib/features/equipment/presentation/utils/equipment_list_rows.dart` (row fields, entry point)
- Create: `lib/features/equipment/presentation/utils/equipment_assembly_rows.dart` (the walk)
- Test: `test/features/equipment/presentation/utils/equipment_list_rows_test.dart` (new `group('assembly view', ...)`)

**Interfaces:**
- Consumes: `EquipmentPartTree` (Task 2), `assemblyFoldKey` (Task 3).
- Produces:
  ```dart
  class EquipmentItemRow extends EquipmentListRow {
    final EquipmentItem item;
    final int depth;            // 0 at top level
    final String navKey;        // item id on the first occurrence
    final String? parentId;     // the assembly this row sits under
    final String? foldKey;      // asm:<id> when the row has children on the list in its unit
    final bool isExpanded;      // meaningful only with foldKey
    final int partCount;        // children on the list in its unit
  }
  EquipmentRowLayout layoutEquipmentRows({
    required List<EquipmentGroup> groups,
    List<EquipmentLocationSection>? sections,
    required Set<String> collapsed,          // resolved: every key folded now
    EquipmentPartTree? parts,                // null = individual view
  });
  // New EquipmentRowLayout fields:
  final Set<String> assemblyIds;             // every assembly placed on the list, folded or not
  final Map<String, String> itemIdByNavKey;  // every item stop, visible rows only
  final Map<String, String> assemblyFoldByNavKey; // assembly row nav key -> asm key
  final Map<String, String> parentNavKeyOf;  // nested row nav key -> its assembly row nav key
  ```
- `EquipmentTypeHeadingRow.items` and `EquipmentLocationHeadingRow.items` hold top-level items only when nesting; a type group with no top-level item emits no heading and no fold.

- [ ] **Step 1: Write the failing tests** (build trees with `EquipmentPartTree.build` from `ComponentsIndex.fromRows` and items with `parentEquipmentId`; read rows with an extended `_kinds` that prints depth, e.g. `'I sf2'`, `'I  cell1'` with two spaces per level, and `'A sf2+'` / `'A sf2-'` for an open / folded assembly row)
  - `no parts graph leaves layout unchanged`: `parts: null` and `parts: EquipmentPartTree.empty` both produce today's rows, keys, and `navStops.keys` for the existing fixtures.
  - `parts move under their assembly and leave their type`: sf2 (rebreather) with component head (other) and installed cell1, cell2 (sensor); `collapsed: {}` gives `['T type:rebreather', 'A sf2+', 'I  head', 'I  cell1', 'I  cell2']` (sensor and other headings gone).
  - `folded assembly hides its parts`: `collapsed: {'asm:sf2'}` gives `['T type:rebreather', 'A sf2-']`, and `foldKeysByItem['cell1'] == ['type:rebreather', 'asm:sf2']`.
  - `nested assembly folds inside its parent`: sf2 > cellSet > cell1; `collapsed: {'asm:cellSet'}` shows `A sf2+`, `A  cellSet-`, no cell1; `foldKeysByItem['cell1'] == ['type:rebreather', 'asm:sf2', 'asm:cellSet']`.
  - `heading counts top-level rows only`: the rebreather heading's `items` is `[sf2]`.
  - `orphaned part stays top level`: cell1 on the list, sf2 not; cell1 shows under `T type:sensor` at depth 0 with `parentId == null`.
  - `shared part gets a second nav key`: second stage s under regA and regB, both open; two rows for s, the first with `navKey == 's'`, the second with a different nav key; `itemIdByNavKey` maps both to `'s'`; `foldKeysByItem['s']` is the first path only.
  - `loop members still show`: a component of b, b component of a, both on the list, nothing else; both ids appear in the rows exactly as many times as placed, at least once each, and the layout terminates.
  - `place sections nest within a place only`: sf2 in place G, cell1 in G, cell2 in place F; under G, cell1 nests; under F, cell2 is top level in `loc:F/type:sensor`. Asm key in G is `asm:sf2` (per item, not per place).
  - `keyboard stops`: for the open sf2 case, `navStops.keys` lists the type heading, then `sf2`, `head`, `cell1`, `cell2`; `assemblyFoldByNavKey['sf2'] == 'asm:sf2'`; `parentNavKeyOf['cell1'] == 'sf2'`.
  - `assemblyIds includes folded and nested assemblies`: with `asm:sf2` folded, `assemblyIds == {'sf2', 'cellSet'}`.
- [ ] **Step 2: Run** `flutter test test/features/equipment/presentation/utils/equipment_list_rows_test.dart`; expect the new group to FAIL.
- [ ] **Step 3: Implement.** In `equipment_assembly_rows.dart`, a function that, for one unit, takes the unit's groups and id set and returns the per-group top-level items plus an emitter that walks a top-level item's subtree:

  ```
  onList = ids in the unit
  topLevel(id) = no parent of id is in onList
  placed = {}
  walk(id, path): placed.add(id); for c in childrenOf(id) if c in onList and c not in path: walk(c, path + id)
  for each group, for each item in order: if topLevel(item) walk(item, {})
  for each group, for each item in order: if item not in placed: mark it top level, walk(item, {})
  ```

  Emission repeats the walk with fold state: an assembly row is emitted with its `asm:` key; children are emitted only when its key is not in `collapsed`, but `foldKeysByItem` and `assemblyIds` are recorded for the whole subtree regardless (first path wins for `foldKeysByItem`). Nav key for a repeat occurrence: `'part:<parent navKey>/<id>'`. Nested rows call `navStops.addRow(navKey, header: <enclosing type heading key or place key>)`. `layoutEquipmentRows` delegates to this only when `parts != null && parts.assemblyIds.isNotEmpty`.
- [ ] **Step 4: Run** the test file; expect PASS (old groups included).
- [ ] **Step 5: Commit** `feat(equipment): nest parts under their assembly in the list layout`.

### Task 5: Rollup clock over both links

**Files:**
- Modify: `lib/features/equipment/presentation/providers/equipment_component_providers.dart`
- Test: `test/features/equipment/presentation/providers/equipment_rollup_clock_provider_test.dart`

**Interfaces:**
- Produces: `equipmentAssemblyRollupClockProvider` (`FutureProvider<Map<String, RollupClock>>`), the existing rollup over components plus installed-in edges (`parentEquipmentId` of active evaluated items). `equipmentRollupClockProvider` is unchanged.

- [ ] **Step 1: Write the failing test** `assembly rollup includes installed parts`: host H with no clock of its own, installed cell C overdue; `equipmentAssemblyRollupClockProvider` gives H's rollup `ownerId == 'C'` while `equipmentRollupClockProvider` has no entry for H.
- [ ] **Step 2: Run** the file; expect FAIL.
- [ ] **Step 3: Implement.** Extract the provider body into a top-level `Map<String, RollupClock> rollUpClocks(List<...> evaluated, Iterable<String> Function(String id) childrenOf)` in the same file; both providers call it, the new one with component children plus installed children.
- [ ] **Step 4: Run**; expect PASS.
- [ ] **Step 5: Commit** `feat(equipment): roll service clocks up through installed parts for assembly rows`.

### Task 6: Assembly row frame, chips and tiles

**Files:**
- Create: `lib/features/equipment/presentation/widgets/assembly_row_frame.dart`
- Modify: `lib/features/equipment/presentation/widgets/assembly_chips.dart`
- Modify: `lib/features/equipment/presentation/widgets/equipment_list_content.dart` (`EquipmentListTile` parameters only)
- Modify: `lib/features/equipment/presentation/widgets/dense_equipment_list_tile.dart` (same parameters)
- Modify: every `lib/l10n/arb/app_*.arb` (keys below), then `flutter gen-l10n`
- Test: `test/features/equipment/presentation/widgets/assembly_row_frame_test.dart`
- Test: `test/features/equipment/presentation/widgets/assembly_chips_test.dart`

**Interfaces:**
- Produces:
  ```dart
  class AssemblyRowFrame extends StatelessWidget {
    const AssemblyRowFrame({required int depth, bool? isExpanded, VoidCallback? onToggle, required Widget child});
    // isExpanded null = no chevron (a plain part or a top-level non-assembly)
  }
  class AssemblyChips {
    const AssemblyChips({required String itemId, int? partCount, String? hideParentId});
    static bool showsAny(ComponentsIndex index, String itemId, {int? partCount, String? hideParentId});
  }
  // EquipmentListTile and DenseEquipmentListTile gain:
  //   int? partCount, String? hideParentId, bool rollupInstalledParts = false
  ```
- l10n keys (feature group `equipment_list_*`, next to `equipment_list_expandAllGroups`): `equipment_list_showParts` "Show parts", `equipment_list_hideParts` "Hide parts". (Sort sheet keys come in Task 8.)

- [ ] **Step 1: Write the failing tests**
  - Frame: depth 0 with `isExpanded: null` adds no left inset; depth 2 adds `2 * kAssemblyIndentStep`; depth 6 adds `4 * kAssemblyIndentStep`; with `isExpanded: false` a chevron with semantics label "Show parts" and a hit box of at least 48x48 shows, tapping it calls `onToggle` once; `isExpanded: true` labels it "Hide parts".
  - Chips: `partCount: 5` on an item with 2 components shows "5 components"; `hideParentId: 'sf2'` on a part of only sf2 shows no chip and `showsAny` is false; a part of sf2 and regB with `hideParentId: 'sf2'` shows the "Part of regB" chip.
- [ ] **Step 2: Run** both files; expect FAIL.
- [ ] **Step 3: Implement.** `kAssemblyIndentStep = 20.0`, max 4 steps. The chevron is an `IconButton` (`Icons.chevron_right` folded, `Icons.expand_more` open) with `tooltip` and semantics from the new keys. Tiles: `hasChips` uses `AssemblyChips.showsAny(...)` with the new parameters; the badge reads `equipmentAssemblyRollupClockProvider` when `rollupInstalledParts`. Translate the two keys into every locale.
- [ ] **Step 4: Run** both files plus `test/features/equipment/presentation/widgets/equipment_list_content_test.dart` (the tile's own tests); expect PASS.
- [ ] **Step 5: Commit** `feat(equipment): assembly row frame and chips for the assembly view`.

### Task 7: Wire the Equipment list

**Files:**
- Modify: `lib/features/equipment/presentation/widgets/equipment_list_content.dart` (wiring only)
- Modify: `lib/features/equipment/presentation/widgets/equipment_list_folds.dart`
- Test: `test/features/equipment/presentation/widgets/equipment_list_content_assembly_test.dart` (new; reuse the harness in `equipment_list_content_folds.dart` / `equipment_list_content_test.dart`)

**Interfaces:**
- Consumes: Tasks 1 to 6.

- [ ] **Step 1: Write the failing widget tests**
  - `folded by default`: SF2 with three installed cells; the list shows the SF2 row with a "Show parts" chevron and no cell rows; the Sensors heading is absent.
  - `chevron opens and remembers`: tapping the chevron shows the cells indented and stores `asm:<sf2 id>` in `equipmentCollapsedGroups`; tapping the row body opens the SF2 detail (`onItemSelected` called with the SF2).
  - `switch off shows today's list`: `nestParts: false` gives Sensors heading with the three cells, no chevrons.
  - `table mode never nests`.
  - `no assemblies, no chevrons`: an inventory without parts renders the same rows as before and the fold menu entries follow today's rule.
  - `filter opens assemblies`: a search for "cell" shows the SF2 open with matching cells; clearing it folds the SF2 again.
  - `expand and collapse all include assemblies`, including with type and location grouping off (menu offered because an assembly is on screen).
  - `deep link opens the folded assembly`: `selectedId` = cell1 opens `asm:sf2` for display without writing it to settings.
  - `keyboard`: on the SF2 row, Right opens it, Left folds it, Enter opens the detail; on cell1, Left folds the SF2 and moves the cursor to it.
  - `shared part arrow navigation`: a part in two open assemblies is reached twice by Down and both rows are marked when it is selected.
- [ ] **Step 2: Run** the new file; expect FAIL.
- [ ] **Step 3: Implement.**
  - In `build`: `nest = viewMode != ListViewMode.table && ref.watch(equipmentArrangementProvider).nestParts`. When `nest`, build `EquipmentPartTree.build(components: <components index value or empty>, items: <the visible items>)`.
  - In the folds mixin: keep `folds` as the stored set; compute `collapsed = resolveCollapsedKeys(stored, tree.assemblyIds, assembliesStartOpen: notifier.assembliesStartOpen)`, and lay out with `collapsed.difference(revealed)`. `_revealed` now takes keys on the target's path that are in `collapsed` (not dismissed). `_isOpen` and `_toggleFold` read `collapsed`. Store `_assemblyIds` from the layout; offer the menu entries when `_outerKeys.isNotEmpty || _assemblyIds.isNotEmpty`; pass `assemblyIds` to `expandAll` / `collapseAll`.
  - In `_buildEquipmentList`: map nav keys through `layout.itemIdByNavKey`; `onExpand` / `onCollapse` handle `assemblyFoldByNavKey` and `parentNavKeyOf` as the spec's keyboard section says; scroll-to-selected matches the first row whose `item.id` is the selection; each item row is wrapped in `AssemblyRowFrame(depth, isExpanded: row.foldKey == null ? null : row.isExpanded, onToggle: ...)` and passes `partCount`, `hideParentId: row.parentId`, `rollupInstalledParts: nest` to the tile; `KeyboardListItem(navigationKey: row.navKey)`.
  - `_scrollToIndex` keeps its estimates (nested rows are item rows).
- [ ] **Step 4: Run** the new file, `equipment_list_content_test.dart`, and `test/features/equipment/presentation/utils/equipment_list_rows_test.dart`; expect PASS.
- [ ] **Step 5: Commit** `feat(equipment): show parts under their assembly on the Equipment list`.

### Task 8: The switch on the Equipment page's sort sheet

**Files:**
- Create: `lib/features/equipment/presentation/widgets/nest_parts_switch.dart`
- Modify: `lib/features/equipment/presentation/widgets/equipment_list_sort_sheet.dart:97`
- Modify: every `lib/l10n/arb/app_*.arb`, then `flutter gen-l10n`
- Test: `test/features/equipment/presentation/widgets/nest_parts_switch_test.dart`

**Interfaces:**
- Produces: `NestPartsSwitch` (`ConsumerWidget`, `ValueKey('equipment_nest_parts')`), writing through `applyEquipmentArrangement(context, ref, (a) => a.copyWith(nestParts: value))`.
- l10n keys next to `equipment_arrange_groupByLocation`: `equipment_arrange_nestParts` "Show parts under their assembly", `equipment_arrange_nestPartsSubtitle` "Fold each assembly's parts under it".

- [ ] **Step 1: Write the failing tests**: the switch reads on by default; toggling it saves an arrangement whose JSON has `nestParts: false`; a failed save shows `equipment_arrange_saveFailed`. The Equipment page sort sheet shows both "Group by location" and the new switch; the dive arrange sheet (`equipment_arrange_sheet.dart`) does not show the new switch.
- [ ] **Step 2: Run**; expect FAIL.
- [ ] **Step 3: Implement**: the widget mirrors `GroupByLocationSwitch`; `pageGrouping:` becomes a `Column(mainAxisSize: MainAxisSize.min, children: [GroupByLocationSwitch(), NestPartsSwitch()])`. Translate both keys into every locale.
- [ ] **Step 4: Run** the new file and `test/features/equipment/presentation/widgets/group_by_location_switch_test.dart`; expect PASS.
- [ ] **Step 5: Commit** `feat(equipment): switch for the assembly view on the Equipment sort sheet`.

### Task 9: Finish

- [ ] `dart format .`, `flutter analyze` (no issues), every test file touched in Tasks 1 to 8 by path.
- [ ] Check the range: a few-item inventory, a 40-item inventory with three nested assemblies, phone (390 wide) and desktop widths, in the after screenshots.
- [ ] Commit any formatting changes.
