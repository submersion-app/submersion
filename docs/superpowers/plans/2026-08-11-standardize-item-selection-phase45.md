# Standardized Selection Phases 4-5: Ten New Surfaces

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give selection to the ten list surfaces that have none, so every list and
grid in the app satisfies the same contract.

**Architecture:** Each surface gains a `SelectionController`, a keyed
`enter_selection` button, a `SelectionAppBar`, a `SelectableListScope`, pruning to
the visible list, and a `verifySelectionContract` call. Surfaces with rows that
cannot be acted on supply a non-selectable predicate.

**Tech Stack:** Flutter 3.x, Material 3, Riverpod, `flutter_test`, ARB localization.

## Scope

Phases 4 and 5 of `docs/superpowers/specs/2026-08-11-standardize-item-selection-design.md`.

**Stacked PR:** this branch is cut from `worktree-selection-phase3`, which is itself
cut from `worktree-standardize-selection`. Retarget order after merges:
#981 → then #988 to `main` → then this PR to `main`.

### Corrections to the spec's surface list

The spec named ten surfaces from a scan of pages that render lists. Three of its
assumptions are wrong and are corrected here:

1. **"Media storage" is not a list.** `media_storage_page.dart` is a settings form
   of text fields, switches and dropdowns. The selectable surface reached from it is
   `transfers_page.dart`.
2. **"Service kinds referenced by a ledger entry" is not a delete blocker.**
   `ServiceRecords.serviceKindId` is deliberately a plain text column with no FK
   (`lib/core/database/database.dart:1820-1822`, commented "so records survive
   custom-kind deletion"). The only predicate is `isBuiltIn`.
3. **Dive centers has no merge.** Grep finds merge only under dive_log, dive_sites,
   buddies, divers and tags. Do not invent one; delete-only is the honest set.

### Decisions taken before implementation

- **Cylinder configs and transfers get net-new bulk delete.** Neither has a
  single-item delete today. Cylinder configs has an unused
  `CylinderConfigRepository.deleteConfig`; transfers has no delete method at all.
  Each is implemented in **its own commit**, carrying the repository change, the
  confirm dialog and the l10n together, so a reviewer can judge the new capability
  separately from the refactor.
- **Species in-use rows are non-selectable via a prefetched count.** `isBuiltIn` is
  synchronous, but "has sightings" is a `SELECT COUNT(*)`. A sighting-count map is
  loaded for the visible list so an in-use species renders no checkbox and is
  excluded from select-all.

## Global Constraints

- `dart format .` clean; `flutter analyze` silent (CI treats **infos** as fatal).
- Every new user-facing string in all 11 locales in `lib/l10n/arb/`.
- Reuse `common_selection_*`. Only add keys a surface genuinely needs.
- No emojis in code, comments or docs.
- Commit messages carry no `Co-Authored-By`, no Claude attribution, no session URL.
- Work in `.claude/worktrees/selection-phase45` on `worktree-selection-phase45`.

## The conversion recipe

Proven across dives, sites, buddies, tags and media. Apply per surface:

1. `final SelectionController _selection = SelectionController();` plus
   `bool get _isSelectionMode => _selection.value.isActive;` and
   `Set<String> get _selectedIds => _selection.value.checkedIds;`. Dispose it.
2. **Build list content inside the `ValueListenableBuilder`**, never before it.
   Convert `final content = ...` into `Widget buildContent() { ... }`. Skipping
   this makes the bar swap while rows stay frozen and no checkbox renders --
   the failure reads like a broken tile and misdirects.
3. Wrap in `SelectableListScope(controller:, selectableIds:, child:)` for Escape,
   Ctrl/Cmd-A and Android back.
4. Post-frame `_selection.pruneTo(visibleIds)` in `build`.
5. Keyed Select button before the overflow menu:
   `IconButton(key: const ValueKey('enter_selection'), icon: Icon(Icons.checklist), tooltip: context.l10n.common_selection_enterTooltip, onPressed: _selection.enterExplicit)`.
6. Replace bar builders with `SelectionAppBar`. Pane shells use
   `maxInlineActions: 1`.
7. Route row checkboxes through `SelectionLeading`.
8. **Compact/pane bars only:** wrap `FeatureAppBarTitle` in `Flexible`. Not in a
   full `AppBar(title:)`, where the title is not a `Row` child.
9. Add `verifySelectionContract` to the surface's test file.

### Per-surface facts

`selectableIds` must be derived from **whichever list the live path renders**.
Courses and certifications render an unfiltered, unsorted list in table mode and a
filtered, sorted one in list mode; using the wrong one breaks contract pruning.

| # | Surface | File | Id | Notes |
| --- | --- | --- | --- | --- |
| 1 | Trips | `trip_list_content.dart` | `t.trip.id` | Omits table selection params |
| 2 | Equipment | `equipment_list_content.dart` | `e.id` | Provider varies by `_selectedFilter` |
| 3 | Courses | `course_list_content.dart` | `c.id` | Hard-codes `selectedIds: const {}` :189 |
| 4 | Certifications | `certification_list_content.dart` | `c.id` | Hard-codes the literals :250 |
| 5 | Dive centers | `dive_center_list_content.dart` | `d.center.id` | Map mode short-circuits tap |
| 6 | Devices | `device_list_page.dart` | `computer.id` | `ConsumerWidget` -> stateful |
| 7 | Service kinds | `service_kind_list_page.dart` | `kind.id` | `ConsumerWidget`; no `actions:` |
| 8 | Cylinder configs | `cylinder_config_list_page.dart` | `config.id` | `ConsumerWidget`; no `actions:` |
| 9 | Species | `species_manage_page.dart` | `species.id` | Already stateful |
| 10 | Transfers | `transfers_page.dart` | `e.id.toString()` | `ConsumerWidget`; **int id** |

### Bulk actions beyond delete

Only actions with an existing single-item equivalent:

| Surface | Extras |
| --- | --- |
| Trips | export |
| Equipment | retire / reactivate |
| Courses | mark completed (gate on `isInProgress`), export |
| Transfers | retry (only `failed`, or `pending` with an error) |
| All others | baseline only |

### Non-selectable predicates

| Surface | Predicate |
| --- | --- |
| Service kinds | `(k) => !k.isBuiltIn` |
| Species | `(s) => !s.isBuiltIn && sightingCount[s.id] == 0` |
| Transfers (retry) | `state == 'failed' \|\| (state == 'pending' && errorMessage != null)` |
| All others | everything selectable |

---

### Task 1: Trips

**Files:** `lib/features/trips/presentation/widgets/trip_list_content.dart`;
test `test/features/trips/presentation/widgets/trip_list_content_test.dart`

**Interfaces:** consumes the shared package; produces
`_TripListContentState._selection` and `_bulkActions(List<TripWithStats>)`.

- [ ] **Step 1: Write the failing contract test.** Model the override setup on
  `test/features/dive_sites/presentation/widgets/site_list_content_test.dart`'s
  `group('selection contract')`, using a test-local `StateProvider<List<TripWithStats>>`
  that `sortedFilteredTripsProvider` watches, so `applyFilter` can narrow it via
  `ProviderScope.containerOf`.
- [ ] **Step 2: Run it; expect FAIL** on the missing `enter_selection` key.
- [ ] **Step 3: Apply the recipe**, steps 1-8. Wire `EntityTableView` at `:254` with
  `selectedIds: _selectedIds`, `isSelectionMode: _isSelectionMode`, and
  `onEntityLongPress`. Wrap `_buildTableModeScaffold` `:222` in the
  `Column(selectionBar, Expanded(table))` shape used by
  `site_list_content.dart:552-560`. Add `Flexible` to the compact title at `:293`.
  Insert the Select button before the overflow at `:186` and `:313`.
- [ ] **Step 4: Declare the actions.** Baseline delete calls a new
  `_confirmAndDelete` modelled on `trip_detail_page.dart:532`, reusing
  `trips_detail_dialog_deleteTitle` / `_deleteConfirm` and
  `trips_detail_snackBar_deleted`. One extra: export, mirroring
  `trip_detail_page.dart:506`.
- [ ] **Step 5:** `flutter test test/features/trips/` and
  `flutter analyze lib/features/trips test/features/trips`. Expect PASS, clean.
- [ ] **Step 6: Commit** `refactor(trips): add standardized selection`.

---

### Task 2: Equipment

**Files:** `lib/features/equipment/presentation/widgets/equipment_list_content.dart`;
test `test/features/equipment/presentation/widgets/equipment_list_content_test.dart`

- [ ] **Step 1:** failing contract test, same shape as Task 1.
- [ ] **Step 2:** run it; expect FAIL.
- [ ] **Step 3:** apply the recipe. `selectableIds` must come from the branch
  `_selectedFilter` selected (`:141`/`:145`/`:148`), not from a fixed provider.
  Wire the table at `:284`; `Flexible` on the compact title `:320`; Select button
  before `:208` and `:340`.
- [ ] **Step 4: Declare the actions.** Delete reuses
  `equipment_deleteDialog_title` / `_content` / `_cancel` / `_confirm` and
  `equipment_snackbar_deleted` from `equipment_detail_page.dart:784-812`.
  Extras: retire and reactivate, mirroring `:760` and `:770`. **Mixed selections:**
  retire is enabled only when every checked item `isActive`, reactivate only when
  none is -- so the action never has to guess. Add
  `common_selection_retireTooltip` and `common_selection_reactivateTooltip` if no
  existing key fits.
- [ ] **Step 5:** test and analyze `lib/features/equipment`.
- [ ] **Step 6: Commit** `refactor(equipment): add standardized selection`.

---

### Task 3: Courses

**Files:** `lib/features/courses/presentation/widgets/course_list_content.dart`;
test `test/features/courses/presentation/widgets/course_list_content_test.dart`

- [ ] **Step 1:** failing contract test.
- [ ] **Step 2:** run it; expect FAIL.
- [ ] **Step 3:** apply the recipe. **Replace the hard-coded
  `selectedIds: const {}` `:189` and `isSelectionMode: false` `:190`.** Derive
  `selectableIds` from the filtered+sorted list in list mode (`:74-80`) and the raw
  list in table mode (`:165`), matching whichever is rendering.
- [ ] **Step 4: Declare the actions.** Delete reuses
  `courses_dialog_deleteTitle` / `_deleteMessage` from
  `course_detail_page.dart:673-702`. Extras: mark completed, gated
  `minCount: 1` and enabled only when every checked course `isInProgress`
  (`copyWith(completionDate: DateTime.now())` -> `updateCourse`, confirm copy
  `courses_dialog_complete`); and export, mirroring `:284`.
- [ ] **Step 5:** test and analyze `lib/features/courses`.
- [ ] **Step 6: Commit** `refactor(courses): add standardized selection`.

---

### Task 4: Certifications

**Files:** `lib/features/certifications/presentation/widgets/certification_list_content.dart`;
test `test/features/certifications/presentation/widgets/certification_list_content_test.dart`

- [ ] **Step 1:** failing contract test.
- [ ] **Step 2:** run it; expect FAIL.
- [ ] **Step 3:** apply the recipe. Replace the hard-coded literals at `:250-251`.
  List mode groups into expired / expiringSoon / valid at `:355-367`; the
  `selectableIds` set is the union of the three groups in the order rendered.
- [ ] **Step 4: Declare the actions.** Delete only, reusing
  `certifications_detail_snackBar_deleted` and the confirm strings from
  `certification_detail_page.dart:307-322`. The detail page offers only edit and
  delete, so there is no honest extra to add.
- [ ] **Step 5:** test and analyze `lib/features/certifications`.
- [ ] **Step 6: Commit** `refactor(certifications): add standardized selection`.

---

### Task 5: Dive centers

**Files:** `lib/features/dive_centers/presentation/widgets/dive_center_list_content.dart`;
test `test/features/dive_centers/presentation/widgets/dive_center_list_content_test.dart`

- [ ] **Step 1:** failing contract test.
- [ ] **Step 2:** run it; expect FAIL.
- [ ] **Step 3:** apply the recipe. **`_handleItemTap` `:130-140` short-circuits to
  `onItemTapForMap` when `isMapMode`; the selection-mode check must come first**, or
  tapping a row in map mode will open the detail instead of toggling. The compact
  bar `:319` is the most crowded of the five -- `Flexible` on its title `:334` is
  required, not optional.
- [ ] **Step 4: Declare the actions.** Delete only, reusing
  `diveCenters_dialog_deleteTitle` / `_deleteMessage` from
  `dive_center_detail_page.dart:218-252`. **No merge** -- none exists to lift.
- [ ] **Step 5:** test and analyze `lib/features/dive_centers`, including
  `dive_center_map_page_test.dart`.
- [ ] **Step 6: Commit** `refactor(dive-centers): add standardized selection`.

---

### Task 6: Devices

**Files:** `lib/features/dive_computer/presentation/pages/device_list_page.dart`;
test `test/features/dive_computer/presentation/pages/device_list_page_test.dart` (create)

- [ ] **Step 1: Convert `DeviceListPage` to `ConsumerStatefulWidget`.** It is a
  `ConsumerWidget` `:11` and cannot hold a controller otherwise. No behaviour change
  in this step; run the existing dive_computer tests to confirm.
- [ ] **Step 2: Write the failing contract test** in a new file. There is no test for
  this page today.
- [ ] **Step 3:** run it; expect FAIL.
- [ ] **Step 4:** apply the recipe. Only one `AppBar` `:21`, so
  `SelectionBarShell.appBar` is the only shell and no `Flexible` work applies. Put
  the Select button in `actions:` beside the help button `:23`. Rows are
  `_ComputerCard` `:189` in a plain `ListView.builder` `:112`; route its leading
  through `SelectionLeading`.
- [ ] **Step 5: Declare the actions.** Delete only, lifting
  `diveComputer_detail_deleteDialogTitle` / `_deleteDialogContent` from
  `device_detail_page.dart:587-617`. No extra: favourite reads as singular and a
  multi-device download would be a new flow, not a lifted action.
- [ ] **Step 6:** test and analyze `lib/features/dive_computer`.
- [ ] **Step 7: Commit** `feat(devices): add standardized selection`.

---

### Task 7: Service kinds

**Files:** `lib/features/equipment/presentation/pages/service_kind_list_page.dart`;
test `test/features/equipment/presentation/pages/service_kind_list_page_test.dart`

- [ ] **Step 1:** convert to `ConsumerStatefulWidget` (`:12`).
- [ ] **Step 2: Write the failing contract test**, including one asserting a
  built-in row renders **no** checkbox and is excluded from select-all.
- [ ] **Step 3:** run it; expect FAIL.
- [ ] **Step 4:** apply the recipe. The `AppBar` `:36` has **no `actions:` list** --
  add one. Pass `isSelectable: !kind.isBuiltIn` to `SelectionLeading` for the
  built-in section rows `:50-56`, and set
  `selectableIds` to `kinds.where((k) => !k.isBuiltIn).map((k) => k.id)`.
- [ ] **Step 5: Declare the actions.** Delete only, reusing
  `equipment_serviceKinds_deleteConfirmTitle` / `_deleteConfirmBody` `:97-106`.
  After deleting, invalidate `serviceKindsProvider` and
  `activeEquipmentClocksProvider` as `_confirmDelete` does at `:113-116`.
- [ ] **Step 6:** test and analyze.
- [ ] **Step 7: Commit** `feat(service-kinds): add standardized selection`.

---

### Task 8: Cylinder configs, including net-new delete

**Files:** `lib/features/cylinder_configs/presentation/pages/cylinder_config_list_page.dart`;
`lib/l10n/arb/app_*.arb`;
test `test/features/cylinder_configs/presentation/cylinder_config_list_page_test.dart`

**This task adds destructive capability that does not exist today.** Keep it in its
own commit so it can be reviewed as such.

- [ ] **Step 1: Add the l10n keys** in all 11 locales:
  `cylinderConfigs_delete_confirmTitle`,
  `cylinderConfigs_delete_confirmBody` (with a `{count}` placeholder),
  `cylinderConfigs_delete_snackbar` (with `{count}`). Run `flutter gen-l10n`.
- [ ] **Step 2: Write the failing test** asserting bulk delete calls
  `CylinderConfigRepository.deleteConfig` once per checked id, plus the contract
  test.
- [ ] **Step 3:** run it; expect FAIL.
- [ ] **Step 4:** convert to `ConsumerStatefulWidget` (`:13`) and apply the recipe.
  The `AppBar` `:23` has no `actions:` -- add one.
- [ ] **Step 5: Wire delete** to the existing but uncalled
  `CylinderConfigRepository.deleteConfig`
  (`lib/features/cylinder_configs/data/repositories/cylinder_config_repository.dart:197`),
  which already tombstones child items at `:200-210`. Everything is deletable:
  configs are applied by **copying** into `dive_tanks`, so no dive references a
  config id and there is no in-use predicate.
- [ ] **Step 6:** test and analyze.
- [ ] **Step 7: Commit** `feat(cylinder-configs): add selection and bulk delete`.

---

### Task 9: Species, with prefetched sighting counts

**Files:** `lib/features/marine_life/presentation/pages/species_manage_page.dart`;
`lib/features/marine_life/presentation/providers/species_providers.dart`;
`lib/l10n/arb/app_*.arb`;
test `test/features/marine_life/presentation/pages/species_manage_page_test.dart` (create)

- [ ] **Step 1: Localize the existing delete strings.** They are hard-coded English
  today (`:227`, `:238`, `:240`, `:263`, `:269`). Add
  `marineLife_species_delete_confirmTitle`, `_confirmBody`, `_inUseError`,
  `_deletedSnackbar`, `_errorSnackbar` in all 11 locales and replace the literals.
  Commit this separately from the selection work.
- [ ] **Step 2: Add a sighting-count provider.** A
  `FutureProvider<Map<String, int>>` over the visible species ids, backed by the
  same query `SpeciesRepository.isSpeciesInUse` uses
  (`species_repository.dart:581-589`) but batched -- one `GROUP BY species_id`
  rather than one query per row.
- [ ] **Step 3: Write the failing tests** in a new file: the contract, plus one
  asserting an in-use species renders no checkbox and is excluded from select-all.
- [ ] **Step 4:** run them; expect FAIL.
- [ ] **Step 5:** apply the recipe. Already stateful `:18`. Select button into
  `actions:` before the reset-to-defaults menu `:35`. Selectable predicate is
  `!s.isBuiltIn && (counts[s.id] ?? 0) == 0`; `selectableIds` filters on the same.
  Built-ins already render without a delete button `:205`.
- [ ] **Step 6: Declare the actions.** Delete only, now using the keys from Step 1.
  Keep reset-to-defaults in the normal app bar -- it operates over exactly the rows
  that are non-selectable.
- [ ] **Step 7:** test and analyze `lib/features/marine_life`.
- [ ] **Step 8: Commit** `feat(species): add standardized selection`.

---

### Task 10: Transfers, including net-new delete

**Files:** `lib/features/media_store/presentation/pages/transfers_page.dart`;
`lib/features/media_store/data/media_transfer_queue_repository.dart`;
`lib/l10n/arb/app_*.arb`;
test `test/features/media_store/transfers_page_test.dart`

**This task adds destructive capability that does not exist today.** Own commit.

- [ ] **Step 1: Add `Future<void> delete(int id)`** to
  `MediaTransferQueueRepository`, beside `retry` `:306` and `deleteDone` `:371`.
  Unit-test it directly.
- [ ] **Step 2: Add the l10n keys** in all 11 locales:
  `mediaStore_transfers_delete_confirmTitle`,
  `_confirmBody` (`{count}`), `_snackbar` (`{count}`). Run `flutter gen-l10n`.
- [ ] **Step 3: Write the failing contract test.** Ids are `int`, so the surface
  converts with `e.id.toString()` and parses back on invoke.
- [ ] **Step 4:** run it; expect FAIL.
- [ ] **Step 5:** convert `TransfersPage` to `ConsumerStatefulWidget` (`:11`) and
  apply the recipe. Put the Select button beside the existing keyed
  `Key('transfers-clear-done')` button `:22`. No FAB, no compact bar.
- [ ] **Step 6: Declare the actions.** Baseline delete via the new repo method.
  One extra: retry, mirroring `_retry` `:137-142` -- it clears the local-asset
  negative cache before retrying, so lift that too. Retry is enabled only when
  every checked entry is `failed`, or `pending` with an `errorMessage`; a
  `transferring` row must never be retried (double-upload risk, per the comment at
  `:110-119`).
- [ ] **Step 7:** test and analyze `lib/features/media_store`.
- [ ] **Step 8: Commit** `feat(transfers): add selection, bulk retry and bulk delete`.

---

### Task 11: Verify and open the stacked PR

- [ ] **Step 1:** `dart format .`, `flutter analyze`, `flutter test`. All clean.
- [ ] **Step 2:** `grep -rln "verifySelectionContract" test/ | wc -l` -- expect 16
  (15 surfaces plus the helper).
- [ ] **Step 3:** `grep -rn "isSelectionMode: false\|selectedIds: const {}" lib/` --
  expect no matches; those literals were the switched-off plumbing.
- [ ] **Step 4:** open the PR against `worktree-selection-phase3`, stating the
  retarget chain and calling out the two net-new delete capabilities prominently.

## Definition of Done

- Every list and grid in the app satisfies `verifySelectionContract`.
- No `lib/features/**` file declares its own selection mode boolean or id set.
- Built-in service kinds, built-in species and in-use species render no checkbox
  and are excluded from select-all.
- A `transferring` queue entry can never be bulk-retried.
- `dart format .` clean, `flutter analyze` silent, `flutter test` green.

## Follow-ups deliberately not done here

- **Delete undo** for the surfaces that lack it. Needs repository restore support.
- **Multi-device download** and **batched trip photo scans** -- new flows, not
  liftable single-item actions.
- **Phase 6 cleanup:** `TableModeLayout`'s dead selection API, `DenseDiveListTile`,
  the mislabeled `codemaps/frontend.md:234`, and the unbound Escape entry in
  `app_shortcuts.dart`.
