# Lists Return to the Last-Opened Record: Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task (inline, in this session). Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** When the diver returns to any of the eight record lists, the list scrolls to the record they last opened, and on a wide window the details pane reopens it unless they closed it.

**Architecture:** Each list's existing `highlighted<X>IdProvider` stays the only record memory. A new shared file adds a pure "is it still listed" resolver and a per-section "pane closed on record X" map. `MasterDetailScaffold` (and so `TableModeLayout`) reopens the pane on mount from a remembered id the page hands it. Each list content restores its scroll on mount through a small shared `ListPositionRestorer`, and `EntityTableView` scrolls to its highlighted row on mount.

**Tech Stack:** Flutter, Riverpod (legacy `StateProvider` via `flutter_riverpod/legacy.dart`), go_router, flutter_test.

**Spec:** `docs/design/specs/2026-10-23-list-position-memory-design.md`

## Global Constraints

- The eight lists and their section ids: Dives `dives`, Sites `sites`, Equipment `equipment`, Buddies `buddies`, Trips `trips`, Dive centers `diveCenters`, Certifications `certifications`, Courses `courses`.
- Memory lasts while the app runs; nothing is persisted.
- An explicit `?selected=` on the route always wins over the memory.
- Pushed lists (`openDiveList`, `openTripList`, detected with `isImperativelyPushed(context)`) never restore on mount and never change the tab's memory.
- Restore never reopens a record the diver closed, nor a record the current list does not show (deleted, filtered out, other diver).
- Diver switch (spec rule 6) needs no reset code: the highlight providers are not reset today, but a record id from another diver's log is never in the current list, so `rememberedListedId` resolves it to null and nothing restores. A stale `closedPaneRecordProvider` entry only matters when it equals the remembered id, which it then cannot.
- Restore scrolls with `jumpTo`, not `animateTo`, so returning does not show a scroll from the top.
- Once the diver scrolls the list, a pending restore is abandoned.
- No new strings, so no ARB changes. No em-dashes in code or comments.
- Tests that override providers or global state restore them (CI bundles test files in one isolate).

## Review Focus

- **List data still loading when the page mounts** (cold provider after a diver switch or sync): the restore must wait for data, then land, not give up at the top. Pinned in Task 2 (scaffold waits on `AsyncLoading`) and Task 3 (restorer retries on the source's change).
- **Remembered record deleted while the diver was elsewhere** (deleted from a dive's site page, say): the pane must stay on the summary, never a "not found" detail. Pinned in Task 1 (`rememberedListedId` returns null for an absent id) and Task 6 (sites: absent id gives no pane and no scroll).
- **Diver scrolls before a slow restore lands** (dive paging forward): no late jump. Pinned in Task 3.
- **Record opened at phone width, window widened before returning:** pane reopens it. Pinned in Task 2 (no closed entry, remembered id present, pane opens).
- **Bulk selection cleared the highlight before leaving:** nothing to restore; list at top, pane on summary. Pinned in Task 2 (`AsyncData(null)`) and Task 3 (attempt reports done with no target).

---

## File Structure

- Create `lib/shared/widgets/master_detail/remembered_selection.dart`: `rememberedListedId`, `closedPaneRecordProvider`.
- Create `lib/shared/widgets/master_detail/list_position_restorer.dart`: `ListPositionRestorer`.
- Modify `lib/shared/widgets/master_detail/master_detail_scaffold.dart`: `rememberedSelectedId` parameter, mount restore, closed-pane bookkeeping.
- Modify `lib/shared/widgets/table_mode_layout/table_mode_layout.dart`: forward `rememberedSelectedId`.
- Modify `lib/shared/widgets/entity_table/entity_table_view.dart`: scroll to highlighted row on mount.
- Modify `lib/features/dive_log/presentation/providers/highlight_providers.dart`: `rememberedDiveIdProvider`, `kRememberedDiveSearchLimit`.
- Modify each of the eight `*_list_page.dart` and `*_list_content.dart`.
- Modify `lib/features/dive_log/presentation/navigation/open_dive_list.dart` and `lib/features/trips/presentation/navigation/open_trip_list.dart`.

---

### Task 1: Remembered-selection primitives

**Files:**
- Create: `lib/shared/widgets/master_detail/remembered_selection.dart`
- Test: `test/shared/widgets/master_detail/remembered_selection_test.dart`

**Interfaces:**
- Produces:
  - `AsyncValue<String?> rememberedListedId<T>({required AsyncValue<List<T>> items, required String? rememberedId, required String Function(T item) idOf})`
  - `final closedPaneRecordProvider = StateProvider<Map<String, String>>((ref) => const {});` mapping section id to the record id the pane showed when the diver closed it.

- [ ] **Step 1: Write the failing tests**

```dart
group('rememberedListedId', () {
  test('null remembered id resolves to data(null) at once', () {
    expect(rememberedListedId<String>(items: const AsyncLoading(), rememberedId: null, idOf: (s) => s), const AsyncData<String?>(null));
  });
  test('waits while the items load', () {
    expect(rememberedListedId<String>(items: const AsyncLoading(), rememberedId: 'a', idOf: (s) => s).isLoading, isTrue);
  });
  test('listed id resolves to itself', () {
    expect(rememberedListedId<String>(items: const AsyncData(['a', 'b']), rememberedId: 'b', idOf: (s) => s), const AsyncData<String?>('b'));
  });
  test('absent id (deleted, filtered out, other diver) resolves to null', () {
    expect(rememberedListedId<String>(items: const AsyncData(['a']), rememberedId: 'gone', idOf: (s) => s), const AsyncData<String?>(null));
  });
  test('an error resolves to null rather than waiting forever', () {
    expect(rememberedListedId<String>(items: AsyncError(Exception(), StackTrace.empty), rememberedId: 'a', idOf: (s) => s), const AsyncData<String?>(null));
  });
});
test('closedPaneRecordProvider starts empty', () {
  final container = ProviderContainer();
  addTearDown(container.dispose);
  expect(container.read(closedPaneRecordProvider), isEmpty);
});
```

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/shared/widgets/master_detail/remembered_selection_test.dart`
Expected: FAIL, `rememberedListedId` not defined.

- [ ] **Step 3: Implement both in `remembered_selection.dart`**, with doc comments explaining that the highlight is the record memory and the map is the "closed on purpose" flag (spec, "Design decisions already made").

- [ ] **Step 4: Run to verify pass.** Same command. Expected: PASS.

- [ ] **Step 5: Commit** `feat(master-detail): remembered selection resolver and closed-pane memory`

---

### Task 2: MasterDetailScaffold reopens the remembered record

**Files:**
- Modify: `lib/shared/widgets/master_detail/master_detail_scaffold.dart`
- Modify: `lib/shared/widgets/table_mode_layout/table_mode_layout.dart` (forward only)
- Test: `test/shared/widgets/master_detail/master_detail_scaffold_restore_test.dart`

**Interfaces:**
- Consumes: Task 1.
- Produces: `MasterDetailScaffold({..., AsyncValue<String?>? rememberedSelectedId})` and `TableModeLayout({..., AsyncValue<String?>? rememberedSelectedId})`. Null means the scaffold does not restore (all non-record screens keep today's behaviour).

Behaviour (state field `bool _restoreSettled = false`):
- In `build`, while not settled, settle without restoring when any holds: not `isMasterDetail`; `_selectedId != null`; `_query['mode'] != null`; `_isMapView`; `isImperativelyPushed(context)`; `widget.rememberedSelectedId == null`.
- Otherwise, if `rememberedSelectedId` is loading, stay unsettled (re-checked on the next build). If it is data `id` and `id != ref.read(closedPaneRecordProvider)[widget.sectionId]`, settle and, in a post-frame callback, `context.goInPlace('$_ownPath?${widget.queryParamKey}=$id')`. Otherwise settle.
- The `_DetailPane.onClose` callback records `closedPaneRecordProvider[sectionId] = _selectedId` (when non-null) before `_onItemSelected(null)`.
- When the scaffold builds on a wide window with `_selectedId != null` and the map holds an entry for its section, remove that entry post-frame (the diver opened a record, so the pane is no longer "closed").

- [ ] **Step 1: Write the failing tests.** Harness: a `GoRouter` with `/items` (the scaffold, detail builder renders `Text('detail $id')`, summary renders `Text('summary')`) and `/other`, at a wide surface (`tester.view.physicalSize` 1400x900, restored in `addTearDown`). "Return" = `router.go('/other')`, pump, `router.go('/items')`, pump settle.
  - `reopens the remembered record on return`: `rememberedSelectedId: AsyncData('a')` → finds `detail a`; `router.routeInformationProvider.value.uri.queryParameters['selected'] == 'a'`.
  - `stays closed after the diver closed the pane`: open `/items?selected=a`, tap the pane's close button, return → finds `summary`; `container.read(closedPaneRecordProvider)['items'] == 'a'`.
  - `a different remembered record reopens despite a closed entry`: closed map `{'items': 'a'}`, remembered `AsyncData('b')` → `detail b`.
  - `opening a record clears the closed entry`: closed map `{'items': 'a'}`, `go('/items?selected=a')` → map has no `items` key.
  - `explicit selected wins`: remembered `'a'`, `go('/items?selected=b')` → `detail b`.
  - `waits while loading, then reopens`: start `AsyncLoading()`, pump → `summary`; rebuild with `AsyncData('a')` → `detail a`.
  - `nothing remembered`: `AsyncData(null)` → `summary`, no `selected` param.
  - `edit mode is not restored`: return after `?selected=a&mode=edit` with remembered `'a'` → `detail a` (view mode), no `mode` param.
  - `narrow window never restores`: surface 600x900 → no `selected` param.
  - `pushed list never restores`: `router.push('/items')` over `/other` → `summary`.
  - `null rememberedSelectedId keeps today's behaviour`: → `summary`.
- [ ] **Step 2: Run to verify failure.** `flutter test test/shared/widgets/master_detail/master_detail_scaffold_restore_test.dart` → FAIL (no such parameter).
- [ ] **Step 3: Implement the behaviour above.** Add the parameter to `TableModeLayout` and pass it to its `MasterDetailScaffold` in `_buildWithDetailPane`.
- [ ] **Step 4: Run the new test and the existing scaffold and table tests**: `flutter test test/shared/widgets/master_detail test/shared/widgets/table_mode_layout` → PASS.
- [ ] **Step 5: Commit** `feat(master-detail): reopen the last-opened record when a list is returned to`

---

### Task 3: ListPositionRestorer

**Files:**
- Create: `lib/shared/widgets/master_detail/list_position_restorer.dart`
- Test: `test/shared/widgets/master_detail/list_position_restorer_test.dart`

**Interfaces:**
- Produces:

```dart
/// Brings a freshly built list back to the record the diver last opened.
class ListPositionRestorer {
  ListPositionRestorer({required ScrollController controller, required bool Function() attempt});
  /// Tries [attempt] after the first frame, then again each time [source]
  /// notifies, until it returns true, the diver scrolls, or [dispose].
  void start(WidgetRef ref, ProviderListenable<Object?> source);
  bool get isDone;
  void dispose();
}
```

`attempt` returns true when restoring is over: the target was scrolled to, or the data has loaded and there is nothing to scroll to. It returns false only while it is still waiting (data loading, or dives paging forward). A user scroll is detected from the controller's position having a non-idle `userScrollDirection`; programmatic `jumpTo` leaves it idle. Use `ref.listenManual` for `source` and close the subscription in `dispose`.

- [ ] **Step 1: Write the failing tests** (a `ConsumerStatefulWidget` harness with a `ListView` of 100 rows and a `StateProvider<int>` as `source`):
  - `attempts after the first frame`: attempt counter is 1 after `pump()`.
  - `retries on source change until done`: attempt returns false then true; bump the provider twice → counter 2, `isDone` true, a third bump → still 2.
  - `abandons after a user drag`: attempt returns false; `tester.drag(find.byType(ListView), Offset(0, -300))`; bump source → counter unchanged, `isDone` true.
  - `dispose stops listening`: dispose the harness widget, bump → no exception, counter unchanged.
- [ ] **Step 2: Run to verify failure.** `flutter test test/shared/widgets/master_detail/list_position_restorer_test.dart` → FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run to verify pass.**
- [ ] **Step 5: Commit** `feat(master-detail): restorer that returns a list to its remembered row`

---

### Task 4: EntityTableView scrolls to the highlighted row on mount

**Files:**
- Modify: `lib/shared/widgets/entity_table/entity_table_view.dart:141-210`
- Test: `test/shared/widgets/entity_table/entity_table_view_test.dart` (add a group; reuse `entity_table_test_harness.dart`)

**Interfaces:**
- Produces: `_scrollToHighlightedRow({bool jump = false})`; on mount it runs once post-frame with `jump: true`. If `entities` is empty at mount, it runs once on the first `didUpdateWidget` whose `entities` contain `highlightedId`, then never again from that path.

- [ ] **Step 1: Write the failing test** `scrolls a highlighted row into view on mount`: 200 rows, `highlightedId` = row 150's id, pump → the pinned vertical controller's offset > 0 and row 150's cell is found on screen (`find.text(<row 150 label>)` finds one).
- [ ] **Step 2: Run** `flutter test test/shared/widgets/entity_table/entity_table_view_test.dart` → FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** the whole `test/shared/widgets/entity_table` directory → PASS.
- [ ] **Step 5: Commit** `feat(entity-table): scroll to the highlighted row when the table is built`

---

### Task 5: Dives

**Files:**
- Modify: `lib/features/dive_log/presentation/providers/highlight_providers.dart`
- Modify: `lib/features/dive_log/presentation/widgets/dive_list_content.dart` (`initState` :245, `_scrollToSelectedItem` :443, `dispose`)
- Modify: `lib/features/dive_log/presentation/pages/dive_list_page.dart` (table branch :182, wide branch :369)
- Test: `test/features/dive_log/presentation/providers/remembered_dive_id_provider_test.dart`
- Test: `test/features/dive_log/presentation/widgets/dive_list_content_restore_test.dart`

**Interfaces:**
- Consumes: Tasks 1 to 4.
- Produces:
  - `const int kRememberedDiveSearchLimit = 1000;` (rows loaded before the search gives up).
  - `final rememberedDiveIdProvider = Provider<AsyncValue<String?>>(...)` over `highlightedDiveIdProvider` and `paginatedDiveListProvider`: `AsyncData(null)` when no highlight; `AsyncData(id)` when a loaded `DiveSummary` has that id; `AsyncLoading()` while the provider loads, or while not found and `hasMore && !loadMoreFailed && dives.length < kRememberedDiveSearchLimit`; otherwise `AsyncData(null)`.
  - `_scrollToSelectedItem([String? overrideId, {bool jump = false}])` returning `bool` (target found in loaded dives).

Restore in `DiveListContent`: unless `isImperativelyPushed(context)`, start a `ListPositionRestorer` in `initState` with source `rememberedDiveIdProvider`. Its attempt reads that provider: data(null) → true; data(id) → `_scrollToSelectedItem(id, jump: true)`, set `_lastScrolledToId = id`, true; loading with paginated data present and `!isLoadingMore` → `loadNextPage()`, false; loading otherwise → false. Keep the existing `initState` path for `widget.selectedId` but skip it when the restorer already targets the same id. `DiveListPage` passes `rememberedSelectedId: ref.watch(rememberedDiveIdProvider)` to both the wide `MasterDetailScaffold` and the `TableModeLayout`.

- [ ] **Step 1: Write the failing provider tests**: no highlight → data(null); highlight in loaded page → data(id); highlight absent, `hasMore` true, 50 loaded → loading; absent and `hasMore` false → data(null); absent and 1000 loaded → data(null); absent and `loadMoreFailed` → data(null).
- [ ] **Step 2: Write the failing widget tests** (follow `dive_list_content_test.dart`'s overrides and fake repository):
  - `phone: returns to the highlighted dive`: 120 dives, highlight dive 90 (loaded in pages 1 and 2), pump `DiveListContent(showAppBar: true)` → dive 90's row is found on screen.
  - `phone: pages forward to a dive beyond the first page`: highlight dive 80, only page 1 loaded at mount → after settle, `loadNextPage` was called and dive 80 is on screen.
  - `does not restore inside a pushed list`: built as a pushed route → scroll offset 0.
- [ ] **Step 3: Run both to verify failure.**
- [ ] **Step 4: Implement.**
- [ ] **Step 5: Run** `flutter test test/features/dive_log/presentation` → PASS.
- [ ] **Step 6: Commit** `feat(dive-log): return the dive list to the last-opened dive`

---

### Task 6: Sites (the model for the remaining lists)

**Files:**
- Modify: `lib/features/dive_sites/presentation/widgets/site_list_content.dart` (`initState` :169, `_scrollToSelectedItem` :200)
- Modify: `lib/features/dive_sites/presentation/pages/site_list_page.dart` (table branch :103, wide branch :262)
- Test: `test/features/dive_sites/presentation/widgets/site_list_content_restore_test.dart`

**Interfaces:**
- Consumes: Tasks 1 to 4.
- Produces the per-list pattern Tasks 7 and 8 copy:
  1. `_scrollToSelectedItem({String? targetId, bool jump = false})` returns `bool`, target `targetId ?? widget.selectedId`; true when the target is in the loaded data, including when it first has to open a collapsed group.
  2. A `ListPositionRestorer` started in `initState` (skipped when `isImperativelyPushed(context)`), source = the list's displayed provider, attempt = data not loaded → false; target = `widget.selectedId ?? ref.read(highlighted<X>IdProvider)`; null → true; otherwise `_scrollToSelectedItem(targetId: target, jump: true)` and set `_lastScrolledToId`, then true. Disposed in `dispose`.
  3. The page passes `rememberedSelectedId: rememberedListedId(items: ref.watch(<displayed provider>), rememberedId: ref.watch(highlighted<X>IdProvider), idOf: ...)` to its `MasterDetailScaffold` and `TableModeLayout`.
- Sites: displayed provider `sortedSitesWithCountsProvider`, `idOf: (s) => s.site.id`, highlight `highlightedSiteIdProvider`.

- [ ] **Step 1: Write the failing tests** (follow `site_list_content_test.dart`):
  - `phone: scrolls to the highlighted site on mount` (60 sites, highlight site 50 → its tile on screen).
  - `grouped: opens a collapsed group to reach it` (follow `site_list_content_grouped_test.dart`).
  - `absent highlighted site: stays at the top` (offset 0).
  - `page passes the listed id to the scaffold`: pump `SiteListPage` wide with highlight on a listed site → detail pane shows it; with a deleted (absent) id → summary.
- [ ] **Step 2: Run to verify failure.**
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** `flutter test test/features/dive_sites/presentation` → PASS.
- [ ] **Step 5: Commit** `feat(dive-sites): return the site list to the last-opened site`

---

### Task 7: Buddies, Trips, Dive centers, Certifications

Same pattern as Task 6. Each already has `_scrollToSelectedItem`.

| List | Content file (`_scrollToSelectedItem`) | Displayed provider | `idOf` | Highlight |
| --- | --- | --- | --- | --- |
| Buddies | `buddy_list_content.dart:162` | `filteredBuddiesWithDiveCountProvider` | `(b) => b.buddy.id` | `highlightedBuddyIdProvider` |
| Trips | `trip_list_content.dart:137` | `sortedFilteredTripsProvider` | `(t) => t.trip.id` | `highlightedTripIdProvider` |
| Dive centers | `dive_center_list_content.dart:148` | `filteredDiveCentersProvider` | check the row type | `highlightedDiveCenterIdProvider` |
| Certifications | `certification_list_content.dart:133` | `filteredCertificationsProvider` | `(c) => c.id` | `highlightedCertificationIdProvider` |

Trips: `_scrollToSelectedItem` reads `tripListNotifierProvider` but the list shows `sortedFilteredTripsProvider`, so the index can point at the wrong row. Switch it to the displayed provider as part of this task. Confirm each `idOf` against the element type before writing it.

- [ ] **Step 1: Write one failing test per list** in its existing `*_list_content_test.dart`: `scrolls to the highlighted <x> on mount` (enough rows to scroll, highlight a late one, its tile is on screen).
- [ ] **Step 2: Run to verify failure.**
- [ ] **Step 3: Implement the pattern in all four content files and their pages.**
- [ ] **Step 4: Run** the four features' `presentation` test directories → PASS.
- [ ] **Step 5: Commit** `feat(lists): return buddies, trips, dive centers and certifications to the last-opened record`

---

### Task 8: Equipment and Courses

Same pattern, but neither has `_scrollToSelectedItem`. Add one modelled on `buddy_list_content.dart:162` (flat list, index times average row height from scroll geometry, `jump` honoured).

| List | Displayed provider | `idOf` | Highlight |
| --- | --- | --- | --- |
| Equipment | `filteredEquipmentProvider` | `(e) => e.id` | `highlightedEquipmentIdProvider` |
| Courses | `filteredCoursesProvider` | `(c) => c.id` | `highlightedCourseIdProvider` |

Equipment's type tabs filter the list: an item hidden by the current tab is absent from `filteredEquipmentProvider`, so it is not restored (spec rule 4). Equipment sets are out of scope.

- [ ] **Step 1: Write one failing test per list** in `equipment_list_content_test.dart` and `course_list_content_test.dart`, as in Task 7.
- [ ] **Step 2: Run to verify failure.**
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** `flutter test test/features/equipment/presentation test/features/courses/presentation` → PASS.
- [ ] **Step 5: Commit** `feat(lists): return equipment and courses to the last-opened record`

---

### Task 9: Pushed lists keep the tab's closed-pane state

**Files:**
- Modify: `lib/features/dive_log/presentation/navigation/open_dive_list.dart`
- Modify: `lib/features/trips/presentation/navigation/open_trip_list.dart`
- Test: `test/features/dive_log/presentation/navigation/open_dive_list_test.dart`, `test/features/trips/presentation/navigation/open_trip_list_test.dart`

**Interfaces:**
- Produces: `DiveListReturn({required filter, required highlightedDiveId, String? closedPaneDiveId})`; `bindRestore` also puts `closedPaneRecordProvider['dives']` back to `closedPaneDiveId` (removing the key when null). `openDiveList` snapshots it. Same for `TripListReturn` with `closedPaneTripId` and section `trips`.

- [ ] **Step 1: Write the failing tests**: with `closedPaneRecordProvider` `{'dives': 'a'}`, open the pushed list, select dive `b` in it (which clears the entry), pop → map is `{'dives': 'a'}` again. Starting from `{}` → back to `{}`. Same for trips.
- [ ] **Step 2: Run to verify failure.**
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** both test files → PASS.
- [ ] **Step 5: Commit** `feat(navigation): pushed lists leave the tab's pane memory as they found it`

---

### Task 10: Whole-branch verification

- [ ] `dart format .` → no changes left unstaged.
- [ ] `flutter analyze` → No issues found.
- [ ] `flutter test test/architecture test/shared` → PASS (new `lib/` files, adoption guards).
- [ ] `flutter test test/shared/widgets test/features/dive_log test/features/dive_sites test/features/equipment test/features/buddies test/features/trips test/features/dive_centers test/features/certifications test/features/courses` → PASS (log to the scratchpad).
- [ ] Run the app (`run` skill), capture after screenshots per the build-feature Screenshots section: Dives phone and wide, Sites wide with pane closed, table view.
