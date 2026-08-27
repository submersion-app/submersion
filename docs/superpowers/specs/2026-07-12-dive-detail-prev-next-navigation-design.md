# Dive Detail Previous / Next Navigation

**Date:** 2026-07-12
**Status:** Approved (design)
**Branch/worktree:** `worktree-detail-scroll-retention`

## Problem

From an open dive's detail page there is no way to step to the adjacent dive.
Users must go back to the list, find the next dive, and open it — tedious when
comparing several dives in a row. Add **Previous / Next** controls (buttons plus
desktop arrow keys) that walk to adjacent dives.

## Definition of "adjacent"

Previous/Next follow the **current list order** — the dive list's active filter
and sort (`diveFilterProvider` + `diveSortProvider`). If the user filtered to one
site sorted by depth, "next" is the next dive in that filtered, sorted sequence.
This matches what the user sees, so adjacency is never surprising.

Both providers are app-global `StateProvider`s, so the current filter/sort is
available from the detail page on every platform (embedded master-detail and
standalone mobile route alike).

## Root of the ordering: reuse the visible list's SQL

The visible list is ordered in SQL:
`DiveRepositoryImpl.getDiveSummaries` builds its query from
`_buildFilterWhereClauses(filter, ...)` and `_buildSortOrderBy(sort)`
(`dive_repository_impl.dart`). Prev/Next MUST reuse those same clause builders so
the neighbor order can never drift from the list order.

## Architecture

### 1. Ordering source — `getOrderedDiveIds` (Approach A)

Add a repository method that returns just the ordered IDs — not full `Dive`
objects, keeping it friendly to the large-DB perf work:

```
Future<List<String>> getOrderedDiveIds({
  String? diverId,
  DiveFilterState filter = const DiveFilterState(),
  SortState<DiveSortField>? sort,
});
```

Implementation mirrors `getDiveSummaries` exactly, minus pagination:
`SELECT d.id FROM dives d LEFT JOIN dive_sites s ON d.site_id = s.id`
`<same WHERE from _buildFilterWhereClauses> ORDER BY <same _buildSortOrderBy>`
— no `LIMIT`, no `OFFSET`, no cursor. The `LEFT JOIN dive_sites` is kept because
site-name sort references `s.name`. Returns the ordered `List<String>`.

Rejected alternatives:
- **B (reuse `sortedFilteredDivesProvider`):** relies on the full in-memory
  `Dive` list the app moved away from for large DBs, and its Dart sort can drift
  from the DB order.
- **C (keyset neighbor queries):** lightest at scale but needs bespoke comparator
  SQL per sort field × direction × nulls. Error-prone; not worth it now.

### 2. Providers

- `orderedDiveIdsProvider` — a `FutureProvider<List<String>>` (autoDispose) that
  reads `currentDiverIdProvider`, `diveFilterProvider`, `diveSortProvider` and
  calls `getOrderedDiveIds`. Recomputes when filter/sort/diver change.
- `diveNeighborsProvider` — a `Provider.family<DiveNeighbors, String>` (by dive
  id) that reads the ordered IDs and computes:
  - `index = ids.indexOf(diveId)`
  - `previousId = index > 0 ? ids[index - 1] : null`
  - `nextId = index >= 0 && index < ids.length - 1 ? ids[index + 1] : null`
  - `index == -1` (dive not in the current filtered list) → both null.
  `DiveNeighbors` is a tiny immutable value type `(String? previousId, String?
  nextId)`.

### 3. UI — `DiveNavButtons`

A small, reusable stateless widget: two `IconButton`s
(`Icons.chevron_left` "Previous", `Icons.chevron_right` "Next"), each disabled
(`onPressed: null`) when its neighbor id is null. It reads
`diveNeighborsProvider(diveId)` and calls an injected
`void Function(String neighborId) onNavigate`.

Placed in both detail surfaces of `dive_detail_page.dart`:
- **Standalone `AppBar`:** prepend the pair to `actions` (before favorite/edit).
- **Embedded header** (`_buildEmbeddedHeader`, master-detail): add the pair to
  the compact header row.

### 4. Navigation

The detail page owns navigation and branches on `widget.embedded`:
- **Embedded (master-detail desktop):**
  `context.go('/dives?selected=$neighborId')` — the same query-param swap the
  list uses. Bonus: the `DetailScrollRetainer` keeps the scroll offset, so the
  user lands on the same section of the adjacent dive.
- **Standalone (mobile route `/dives/:id`):**
  `context.replace('/dives/$neighborId')` — replace (not push) so stepping
  through dives does not pile up the back stack.

### 5. Arrow keys (desktop)

Wrap the detail content in `CallbackShortcuts` (inside a focused subtree) binding:
- `LogicalKeyboardKey.arrowLeft` → previous
- `LogicalKeyboardKey.arrowRight` → next

Left/Right are chosen so Up/Down remain free for vertical scrolling. Each binding
is a no-op when its neighbor is null. The shortcuts live on the detail pane's
focus scope so they do not fight the master list's own key handling.

## Edge cases

- **Dive not in the current filter** (user filtered it out after opening) → both
  controls disabled; arrow keys no-op.
- **Ends of the list** → Previous disabled on the first, Next on the last.
- **Single-dive list** → both disabled.
- **Filter/sort changes while viewing** → `orderedDiveIdsProvider` recomputes and
  the buttons re-enable/disable reactively.

## Testing

- **Repository test:** `getOrderedDiveIds` returns the same id order as
  `getDiveSummaries` (paged, concatenated) for a representative filter and for at
  least two sorts (date desc, depth asc), including a filtered subset.
- **Provider test:** `diveNeighborsProvider` — middle (both), first (prev null),
  last (next null), not-found (both null), single-item (both null).
- **Widget test:** `DiveNavButtons` renders both buttons; disabled at ends; tap
  fires `onNavigate` with the right id. Detail-page test: Left/Right arrow keys
  invoke previous/next.

## Scope

- **Dives only** (per the request). `DiveNavButtons`, `DiveNeighbors`, and the
  ordered-ids/neighbors provider pattern are written to generalize, so other
  detail pages (sites, etc.) could adopt the same shape later — but no other
  section is touched here.

## Files touched

- `lib/features/dive_log/domain/repositories/dive_repository.dart` — add
  `getOrderedDiveIds` to the interface.
- `lib/features/dive_log/data/repositories/dive_repository_impl.dart` — implement
  it (reusing `_buildFilterWhereClauses` / `_buildSortOrderBy`).
- `lib/features/dive_log/presentation/providers/dive_providers.dart` — add
  `orderedDiveIdsProvider` and `diveNeighborsProvider` (+ `DiveNeighbors`).
- `lib/features/dive_log/presentation/widgets/dive_nav_buttons.dart` — new
  `DiveNavButtons` widget.
- `lib/features/dive_log/presentation/pages/dive_detail_page.dart` — mount the
  buttons in the AppBar and embedded header; navigation; arrow-key shortcuts.
- Tests under `test/features/dive_log/` for repo, providers, and widget/keys.
