# Dive List: Inline Trip Grouping

Status: proposed
Date: 2026-09-09
Issue: [#1193](https://github.com/submersion-app/submersion/issues/1193)

## Problem

The dive list is a flat chronological stream. A diver who logs 14 dives on a
liveaboard scrolls past 14 undifferentiated cards with no sense that they
belong together, and no way to fold them away to reach the dives on either
side.

The issue asks for collapsible trip groups shown inline in the list, with the
trip header toggling its dives open and closed.

### The constraint that shapes the design

The mock-ups attached to the issue indent a trip's dives behind a vertical
rail, which makes a grouped dive card visibly narrower than a loose one. The
maintainer's requirement is explicit: **grouping must not make the dive cards
any narrower.** Every dive card keeps the 16px horizontal margin it has today,
grouped or not.

This rules out any treatment that takes width away from the card and pushes
the design toward decoration that sits *behind* or *around* the cards instead.

## Decisions

Settled during brainstorming:

| Question | Decision |
| --- | --- |
| Grouping scope | Trips only. Not a general "group by" menu. |
| Visual treatment | Trip header band plus a faint full-bleed band behind the group. No side rail. |
| Header count | "6 of 14 dives" when loaded and total differ, "14 dives" when they agree. |
| Collapse default | Expanded. Collapse persists across restarts. |
| View modes | Detailed and compact. Table mode ignores the toggle. |
| Non-chronological sorts | Grouping pauses, with an inline notice. Toggle stays on. |
| List structure | `CustomScrollView` with a `SliverMainAxisGroup` per trip and pinned trip headers. |

### Why the band and not a rail

The dive card's background colour is already a four-way multiplexed channel:
the attribute gradient (`cardColorAttribute`), the selection tint, the
highlight fill, and map-tile mode where the whole card is a satellite tile
under a dark scrim. Tinting member *cards* to show trip membership is
therefore unavailable. Tinting the region *behind* them is not.

The band runs edge to edge, so the grouped region is wider than the cards it
contains, never narrower. The rail from the issue mock-up was dropped on the
maintainer's call: it also removes the right-to-left mirroring problem.

### Why pinned headers

Scrolled into the middle of a 14-dive trip, a non-sticky header has left the
viewport and nothing on screen says which trip you are in. A pinned header
inside a `SliverMainAxisGroup` stays stuck to the top of its own group and
releases when the next group arrives. The trip story page
(`lib/features/trips/presentation/widgets/story/`) already proves this pattern
in this codebase.

Flutter 3.47 ships `DecoratedSliver`, which paints a `BoxDecoration` behind a
sliver's paint extent. The band is therefore
`DecoratedSliver(sliver: SliverMainAxisGroup([header, body]))`: no wrapper
widget forcing the whole group to build eagerly, and the band's top and bottom
hairlines land on the group's real bounds without measuring anything.

## Data

### DiveSummary gains four scalars

`DiveSummary` exists so a list row never drags a full `DiveSite`, `Trip`,
tanks or profile behind it. That stays true: it gains `tripId`, `tripName`,
`tripStartDate` and `tripEndDate`, all nullable, and no `Trip` object.

They are fed by `LEFT JOIN trips t ON d.trip_id = t.id` added to the slim
list SELECT. That join must be added in **two** places, both of which share
`_mapRowToSummary` in `dive_repository_impl.dart`:

1. the paginated page query (around line 2013), and
2. `getSummariesByIds` (around line 2742).

`DiveSummary.fromDive` maps them from `dive.trip`.

This is a primary-key join on the hottest query in the app. The
implementation re-runs the large-database timing harness rather than assuming
it is free.

### Trip totals

One query for the entire list, not one per header:

```sql
SELECT trip_id, COUNT(*) AS n FROM dives WHERE trip_id IS NOT NULL
GROUP BY trip_id
```

Exposed as `tripDiveCountsProvider` returning `Map<String, int>`, invalidated
on the same dive-change tick the list already watches.

The count is what makes a page-straddling trip legible. Without it a 14-dive
trip cut by the 50-dive page boundary looks like a smaller trip, with nothing
saying more of it is still below.

## Settings and persistence

Two pieces of state with different lifetimes, so two homes.

**`groupTripsInDiveList`**: a `BoolColumn` on the `diver_settings` table
beside `diveListViewMode`, surfaced through `AppSettings` and a runtime
`StateProvider` following the `diveListViewModeProvider` pattern exactly:
`ref.read` at creation, so an unrelated settings write cannot stomp a session
override.

This is a schema rung. Current version is 199; **this feature claims v202**,
because 200 is claimed by the transmitter registry program (PR #1677) and 201
by equipment assemblies. Migration, ladder rung and schema test come with it.
If either of those programs lands differently, re-check the number before
writing the migration.

**Collapsed trip ids**: a `Set<String>` in `SharedPreferences`, keyed per
diver. This is per-device browsing state, and putting it in the synced
settings table would push an ever-growing id blob through sync for no
benefit.

One rule falls out: if the dive open in the detail pane, or the highlighted
row, belongs to a collapsed group, that group auto-expands. The app never
hides the dive you are looking at.

## Grouping model

A pure function, so the awkward cases are testable without a widget tree:

```dart
List<DiveListSection> buildDiveListSections({
  required List<DiveSummary> dives,       // flat, in list order
  required bool groupingEnabled,
  required Set<String> collapsedTripIds,
  required Map<String, int> tripTotals,
  String? forceExpandedTripId,
});
```

`DiveListSection` is sealed:

- `LooseSection`: a run of dives with no trip.
- `TripSection`: trip identity, member dives, `collapsed`, plus `loadedCount`
  and `totalCount` for the header.

Single pass over the ordered list. A change of `tripId` to a non-null value
opens a `TripSection`; matching consecutive ids extend it; null ids fall into
a `LooseSection`.

### Three consequences, stated rather than discovered

**Sections are runs, not sets.** A trip interrupted by a non-trip dive on the
same date produces two sections for the same trip. Both label with the trip's
real total, so it reads as "this trip, continued". The alternative, gathering
a trip's dives out of date order, would break the date sort the list is built
on.

**Every dive keeps its flat index.** The detailed card's dive-number fallback
(`dive.diveNumber ?? index + 1`) and the detail page's prev/next both depend
on flat list position, so each entry carries its original index, never a
position within its section.

**Shift-range selection walks the visible order.** Dives inside a collapsed
group are not swept up by a range spanning it, matching how Finder treats a
collapsed folder. `_selectRangeTo` receives the visible-order id list.

### Gating

`groupingEnabled` is a derived provider: the toggle is on **and** the sort is
`DiveSortField.date` or `DiveSortField.diveNumber` **and** the view mode is
not `ListViewMode.table`. One place to reason about it, rather than three
scattered conditionals.

Date and dive number are both effectively chronological, so trips stay
contiguous under either. Under any other sort a trip's dives scatter and
grouping would fragment a 14-dive trip into a dozen one-dive headers, which
is noisier than no grouping at all.

## List structure

`_buildDiveList` in `dive_list_content.dart` becomes:

```
RefreshIndicator
└ Column
   ├ active filters bar                      (unchanged, outside the scroll view)
   └ Expanded(CustomScrollView(
        controller: _scrollController,       (unchanged)
        slivers: [
          grouping-paused notice   -> SliverToBoxAdapter, when applicable
          LooseSection             -> SliverList.builder
          TripSection              -> DecoratedSliver(
                                        sliver: SliverMainAxisGroup([
                                          SliverPersistentHeader(pinned: true, ...),
                                          if (!collapsed) SliverList.builder(members),
                                        ]))
          sentinel                 -> SliverToBoxAdapter(spinner / retry row)
        ]))
```

Rows are still rendered by `DiveListItem`, unchanged, so the home screen's
Recent dives list and the list display settings stay in sync (#506).

### The pagination sentinel must stay a built widget

The sentinel is a real widget whose `build` kicks `_loadNextPageIfStranded`,
not a scroll-offset check. That is what the #1610 fix depends on, and it
matters far more here than before: collapse every trip and a freshly loaded
page of 50 dives can be almost entirely invisible, leaving the viewport
unfilled with no scroll event to notice it. Building the sentinel is itself
the signal to load, so the list keeps pulling until something visible fills
the screen or `hasMore` goes false.

A page load that already failed is still left alone: the retry row is the only
way back, and the kick must not clear `loadMoreFailed` behind the diver's
back.

### Header extent

The pinned header needs a fixed extent, so the delegate computes it from the
ambient `textScaler` rather than hardcoding a value. A diver at 200% text
size would otherwise get a clipped header, and widget tests running at
standard density with the Ahem font would never see it.

## The header widget

One row, fixed extent:

- leading trip glyph,
- `TRIP · Tassie` on the first line,
- `Jun 8 - Jun 9, 2026 · 6 of 14 dives` on the second, collapsing to
  `· 14 dives` when the counts agree,
- trailing open-trip icon button,
- expand/collapse chevron.

**Tapping the header toggles collapse**, as the issue asks. The whole band is
the target, not just the chevron. Navigation to the trip detail page lives on
its own icon button, because the dive cards below already spend both tap and
double-tap.

**In selection mode** the open-trip button is replaced by a tri-state checkbox
that selects or clears every dive of that group currently in the list, the
same "loaded dives only" semantics the existing select-all has. It reads mixed
when only some are selected. Collapsing does not clear a selection.

## Chrome

**The toggle** is a checked item, "Group trips", appended to the existing
view-mode popup menu. It must be added in **two** places: the wide app bar
(around line 1043) and the compact app bar (around line 1211) each build their
own copy of that menu. The same menu also gains Expand all trips and Collapse
all trips, shown only while grouping is active.

**The paused notice**, when grouping is on but the sort is not chronological,
is the first sliver: "Trip grouping is off while sorted by depth", with a
"Sort by date" action. The toggle stays on and stays checked; nothing
silently reverts. It is not folded into the active-filters bar, because that
bar only exists when a filter is active and a paused grouping is not a filter.

## Testing

**The width constraint gets a direct regression test.** Render a list holding
one grouped and one ungrouped dive and assert `tester.getSize()` reports
identical widths for both cards. That is the thing that must not regress, and
it should not rely on a human looking at a screenshot.

Unit:

- `buildDiveListSections`: plain runs, a trip interrupted by a loose dive,
  collapsed sections, `forceExpandedTripId`, grouping disabled.
- `tripDiveCountsProvider` query shape and invalidation.

Repository:

- both summary SELECTs carry the trip fields, including `getSummariesByIds`.
- `DiveSummary.fromDive` maps them.

Widget:

- tap toggles collapse; chevron state follows.
- the pinned header stays put while scrolling through its own group and
  releases at the next group.
- the paused notice appears under a depth sort and its action restores the
  date sort.
- table mode ignores the toggle entirely.
- **every trip collapsed, so a whole 50-dive page is invisible**: the list
  keeps paging without stalling, and stops when `hasMore` goes false. Both
  directions asserted.
- selection: the group checkbox reads mixed, selects loaded dives only, and
  a shift-range does not sweep dives inside a collapsed group.

Schema:

- v202 migration and its ladder rung.

## Known traps

- New l10n keys must be anchored on a neighbouring **key** in each of the 11
  ARB files. Only `app_en.arb` is alphabetical; the others are grouped by
  feature.
- Adding a provider that `DiveListContent` watches tends to break existing
  widget tests whose base overrides do not mock it. `tripDiveCountsProvider`
  needs an override in the shared test overrides.
- This worktree needs `build_runner` codegen before app code compiles.
- Re-check the v202 claim against PR #1677 and the equipment assemblies
  program before writing the migration.

## Out of scope

- Grouping in table mode. `DiveTableView` runs two vertically-synced
  `ListView.builder`s (a frozen first column and a horizontally scrollable
  remainder); a group header has to exist in both at identical heights and
  decide what it does under horizontal scroll. That is its own piece of work.
- Any grouping dimension other than trip.
- Collapse/expand animation. Instant, with the chevron indicating state.
