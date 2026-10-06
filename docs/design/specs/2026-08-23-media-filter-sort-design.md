# Media Library Filter and Sort Controls: Design

**Status:** approved 2026-08-23
**Branch:** `worktree-media-filter-sort`
**Supersedes nothing.** Replaces the Phase 5 filter chip row introduced with
the Media section console.

## Problem

The Media section's Library view puts every filter facet on screen at once as
a row of chips: All, Photos, Videos, Site, Trip, Dates, Clear, Save as album,
and an Albums menu. The user reported that the row "spills over into the other
UI items on the right when it gets too long".

The report is accurate and the cause is structural.
`media_library_view.dart:56` wraps `MediaLibraryFilterBar` in an `Expanded`,
and the bar is itself a horizontal `SingleChildScrollView`. The chips
therefore never wrap and never overflow visually, but they claim all
available width and squeeze the view-mode `SegmentedButton`
(`media_library_view.dart:58`) that shares the row.

Every other list surface in the app already solved this. `site_list_page.dart`
uses a `Badge`-wrapped `Icons.filter_list` button opening a filter sheet
(line 137) beside an `Icons.sort` button opening the shared
`showSortBottomSheet` (line 155). Dives, trips, and equipment follow the same
pattern. Media is the outlier.

The Library also has no sort control at all. Ordering is hard-coded to
newest-first at `media_library_repository.dart:131`.

## Scope

Confirmed with the user on 2026-08-23:

1. Replace the chip row with the app-standard badged filter button plus filter
   sheet.
2. Add a real sort control offering date, file name, and file size, each in
   both directions.
3. Keep active filters visible: when the filter is non-empty, render a strip
   of removable chips below the toolbar showing only the facets actually set.
4. Controls live in the Library toolbar row, not the Media section AppBar.

## Findings

Every claim below was verified by reading the cited lines in this worktree.

**F1. `_sortKey` serves two unrelated jobs.**
`media_library_repository.dart:32` defines
`COALESCE(taken_at, created_at)`. It is used for the keyset pagination order
(lines 120, 121, 131) and, separately, for the `fromDate`/`toDate` filter
bounds (lines 71, 79). Generalising `_sortKey` to mean "the active sort key"
without splitting these would make a date-range filter compare calendar bounds
against byte counts whenever sort-by-size is active.

**F2. A nullable sort column silently truncates keyset pagination.**
The cursor predicate is `key < ? OR (key = ? AND id < ?)`
(`media_library_repository.dart:120-122`). In SQL, a comparison against NULL
evaluates to NULL, which is falsy. Both candidate sort columns are nullable:
`original_filename` (`database.dart:1295`) and `content_size_bytes`
(`database.dart:1322`). Paging into a run of NULL keys with a naive predicate
matches zero rows, so the grid stops loading with no error and no indication
that results were dropped.

**F3. The grouped view modes assume date ordering.**
`groupByTimeline` (`media_library_groupers.dart:74`) buckets an
already-sorted stream into calendar days in first-seen order, and its
docstring says so. Feeding it a name-sorted or size-sorted page produces a
long list of one-item day groups. `groupByDive`
(`media_library_groupers.dart:42`) is less badly affected but its group order
becomes arbitrary.

**F4. New indexes need no schema migration.**
`performance_indexes.dart` is a registry of `CREATE INDEX IF NOT EXISTS` DDL
applied outside the schema-version ladder. No version bump, no migration step.
Note that the current default date ordering has no covering index today.

**F5. Smart albums serialize the filter only.**
`MediaLibraryFilter.toJson` (`media_library_filter.dart`) is the album
payload. Sort is not part of it and must not become part of it, or every
persisted album gains a field and needs lenient-decode handling.

## Design

### UI

The Library toolbar becomes fixed-width controls that cannot crowd each other:

```
┌──────────────────────────────────────────────────────┐
│ [filter•] [sort]                  [ grid | dive | ▤ ] │  toolbar (always)
├──────────────────────────────────────────────────────┤
│ (Photos x) (Blue Hole x) (Jun 1-14 x)  Clear   Save   │  only when filtered
├──────────────────────────────────────────────────────┤
│  media grid                                           │
└──────────────────────────────────────────────────────┘
```

`media_library_filter_bar.dart` is deleted and replaced by three focused
widgets:

| File | Responsibility |
| --- | --- |
| `media_library_toolbar.dart` | The icon row: badged filter button, sort button, view-mode `SegmentedButton` |
| `media_library_filter_sheet.dart` | Bottom sheet, draft-then-Apply local state, modeled on `SiteFilterSheet` |
| `media_library_active_filter_chips.dart` | Removable chips per active facet, Clear all, Save as album |

The filter button carries `Badge(isLabelVisible: !filter.isEmpty)`, matching
`site_list_page.dart:137`.

Smart albums move off the toolbar: loading an album becomes a row in the
filter sheet's header, and Save as album moves to the active-chips strip,
where it is only reachable once the filter says something. This removes four
controls from the toolbar.

The sort button renders only in grid mode. Per F3 the grouped modes define
their own order, and hiding the control is preferable to rendering a shredded
timeline.

### Sort model

Following the existing app convention rather than inventing a parallel one:

- `MediaSortField { dateTaken, fileName, fileSize }` is added to
  `lib/core/constants/sort_options.dart` alongside `DiveSortField` and
  `SiteSortField`, carrying `displayName` and `icon` like its siblings.
- Localized names go in `sort_options_display.dart`.
- The UI uses the shared `showSortBottomSheet<MediaSortField>` and
  `SortState<MediaSortField>` that sites and dives already use.
- `mediaLibrarySortProvider` is a `StateNotifierProvider` persisting the
  choice through `AppSettingsRepository` under the key
  `media_library_sort`, exactly as `MediaLibraryViewModeNotifier` persists
  `media_library_view_mode`. The serialized form is `"<field>:<direction>"`,
  decoded leniently: an unrecognized value falls back to date descending
  rather than throwing.
- `mediaLibraryNotifierProvider` watches the sort provider and passes it to
  the repository, so changing sort reloads page one the same way changing the
  filter does.

Per F5, sort stays out of `MediaLibraryFilter` and out of album
serialization.

### Repository

`getPage` gains a `MediaLibrarySort sort` parameter (defaulting to date
descending, preserving today's behavior for every existing caller).

Internally, each field maps to a sort spec pairing a SQL expression with a
cursor-value extractor. Every expression is coalesced so the key can never be
NULL, which is what makes the keyset predicate total (F2):

| Field | Expression | Rationale |
| --- | --- | --- |
| `dateTaken` | `COALESCE(taken_at, created_at)` | unchanged; `created_at` is `NOT NULL` |
| `fileName` | `COALESCE(original_filename, file_path)` | `file_path` is `NOT NULL`, so this always resolves |
| `fileSize` | `COALESCE(content_size_bytes, -1)` | unhashed rows sort as smallest rather than disappearing |

`MediaLibraryCursor.sortKey` widens from `int` to `Object` (an `int` for date
and size, a `String` for name). Direction drives both the cursor comparison
operator and the `orderBy` terms, with `id` as the tiebreaker in the same
direction so the total order stays stable.

Per F1, `_sortKey` is renamed `_dateKey` and keeps serving the `fromDate` and
`toDate` bounds. The active sort key is a separate expression. This is a
behavior-preserving rename for the date bounds and a bug prevented for the
new sort fields.

Three expression indexes are added to `performance_indexes.dart`, one per sort
key, each covering `(key, id)`. `COALESCE` is deterministic, so SQLite accepts
it in an index expression. Per F4 this needs no migration, and it makes the
existing default ordering faster than it is today.

### Known behavior

Sorting by size groups every never-uploaded row into one undifferentiated
block at the bottom, because `content_size_bytes` is populated only once the
media store has hashed a row. This is honest rather than wrong, but it will
look odd on a library that has never been uploaded. Documented here so it is
not later reported as a defect.

## Testing

Test-first, per the project's TDD rule.

**Repository (the important layer).** For each field and each direction, page
through a fixture set that deliberately includes rows with a NULL
`original_filename` and rows with a NULL `content_size_bytes`, then assert
that concatenating every page yields all rows exactly once in the expected
order. This is the test that catches the F2 truncation; a fixture without
NULLs passes vacuously.

A separate regression test asserts that a `fromDate`/`toDate` filter still
bounds on the date key while sorting by size, guarding F1.

**Widgets.**

- The filter badge is invisible on an empty filter and visible once any facet
  is set.
- The sheet's Apply writes the drafted facets to `mediaLibraryFilterProvider`;
  dismissing without applying leaves it unchanged.
- Each active chip's delete clears exactly its own facet and leaves the others
  alone.
- The sort sheet writes `mediaLibrarySortProvider`.
- The sort button is absent in timeline and by-dive modes and present in grid
  mode.

**Rewrites.** `media_library_filter_bar_test.dart` and
`media_smart_album_test.dart` currently drive the deleted widget and are
rewritten against the new ones. The smart album test's coverage (load an
album into the filter, save the current filter, delete failure surfaces a
snackbar) is preserved against the sheet and chip strip.

**Localization.** New keys are added to all 11 ARB files under `lib/l10n/arb/`
with real translations, not English stubs.
