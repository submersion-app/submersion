# Back navigation from linked items and "show dives" links

Date: 2026-10-11
Status: approved design

## Problem

Two related gaps leave the diver with no way back to where they were.

1. **Dive details to a linked item.** On desktop and tablet (master-detail
   widths), opening a dive's equipment, buddy, trip, dive center, or (through
   the course card) certification lands in that section's list with the item
   selected, and there is no back arrow to the dive. Site, course, dive
   computer, species, documents, tracks and transmitters already keep one.
2. **An item to its dives (#2784).** "View all dives" on a site, gear item,
   buddy, dive center or dive computer, "View on map" on a trip, a tag chip on
   a dive, an Insights country or region row, and Connections "Show dives" all
   replace the screen with the Dives tab. There is no back arrow to the item.
   Tag chips sit on the dive details page, so they are also part of gap 1.

Phones are unaffected by gap 1 (nothing redirects at phone width), and on
Android the system back button partly hides gap 2. Windows and macOS have
nothing.

## Cause

The app has one `ShellRoute`, so every section shares one Navigator stack.
`context.push` adds a page; `context.go` discards the stack and rebuilds it
from the URL.

- **Gap 1.** Each detail page runs a desktop redirect in `build()`: shown
  standalone at master-detail width, it calls
  `context.go('/<section>?selected=<id>')` to appear in the split view. The
  site page skips this when something is under it
  (`!Navigator.of(context).canPop()`), and the dive detail page got the same
  guard in #764 (`!(GoRouter.maybeOf(context)?.canPop() ?? false)`).
  Equipment, buddy, trip, dive center and certification never got it, so a
  page pushed from dive details redirects and erases the stack.
- **Gap 2.** Every "show dives" link writes the global `diveFilterProvider`
  and then calls `go('/dives')`. Pushing instead is not enough by itself:
  `MasterDetailScaffold` and the dive list change selection, mode and view
  with `router.go(...)`, so the first dive clicked in a pushed list on desktop
  erases the stack again.

## Goals

- Every item opened from dive details shows a back arrow that returns to the
  same dive, at every width.
- Every "show dives" browse link opens a dive list with a back arrow that
  returns to the page that opened it, at any depth (dive, gear, the gear's
  dives, a dive, then back, back, back).
- Using the pushed list (selecting dives, editing, switching to map or table)
  never loses the way back.
- Leaving a pushed list restores the dive-list filter that was in place
  before it opened.
- Sections opened from the sidebar or a deep link behave exactly as today.

## Non-goals

- No change to phone-width navigation beyond the new back arrow on a pushed
  dive list.
- The import wizard's "view imported dives" keeps `go('/dives')`: it ends a
  flow, so there is nothing to return to.
- The embedded (master-detail) headers' edit buttons that call `go` are not
  changed; they only run in the split view, never on a pushed page.
- No change to how filters are chosen or displayed.

## Design

### 1. One redirect rule for detail pages

A helper in `lib/core/router/` decides whether a detail page redirects to its
section's master-detail split. It redirects only when all of these hold:

- the page is not embedded,
- the page was not pushed: it is not the page of a go_router imperative
  match (`isImperativelyPushed`). Page-local `canPop` is not enough here,
  because every detail route is a child of its list: `go('/equipment/e1')`
  builds the list under the item, so the item can pop without having been
  pushed,
- the layout is master-detail width,
- the section is not in table mode (the caller passes its view mode).

Used by all seven detail pages that redirect today:

| Page | Change |
| --- | --- |
| Equipment, buddy, trip, dive center, certification | Gains the "not pushed" check (the fix) |
| Site, dive | Moves from its hand-rolled guard to the helper. Reached by URL, these now snap into the split too; their old `canPop` guards never fired with the list underneath |

A pushed page then stays a standalone page with a title bar and back arrow,
as Site already does. A page reached by URL (a deep link, or an item opened
at phone width before the window was widened) still redirects.

### 2. `goInPlace`: URL changes that keep the stack

An extension method next to `pushOrReturnTo` in
`lib/core/router/section_navigation.dart`:

- current page was pushed (`isImperativelyPushed`, the same rule as the
  redirect in section 1): `GoRouter.of(context).replace(location)`,
- otherwise: `go(location)`. That includes a page go() built over its
  parent (Planning's gas calculators): it can pop, but `replace` would turn
  it into a push and its URL would stop reflecting the selection.

`replace` keeps the page key, so the page's `State` (scroll position, pane
width, the restore snapshot below) survives. This generalises the idiom the
dive detail stepper already uses (`go` embedded, `replace` standalone).

Switched to `goInPlace`:

- `MasterDetailScaffold`: select, clear selection, create, save, cancel
  (desktop paths). On phones, opening a detail from a pushed master pane uses
  `push` instead of `go`.
- `DiveListPage`: view and map toggles, map "details" tap, table-mode
  selection.
- `DiveListContent`: the "new dive" header button.
- `DiveSummaryWidget`: open a dive, new dive.
- `DiveDetailPage` (embedded): the edit button and the previous/next stepper.

Links that deliberately leave for another section (the summary's
"Dive computers" and "Insights" buttons) keep `go`.

### 3. `openDiveList`: the one way to show a set of dives

`openDiveList(context, ref, filter, {bool map = false})` in
`lib/features/dive_log/presentation/`:

1. reads the current `diveFilterProvider` state (the previous filter),
2. writes `filter`,
3. pushes `/dives` (or `/dives?view=map`) with `extra` carrying the previous
   filter.

Callers moved onto it:

| Caller | Filter |
| --- | --- |
| Site detail "View all dives" | `siteId` |
| Equipment detail dive count | `equipmentIds` |
| Equipment history card | as today |
| Buddy "Shared dives" view all | `diveIds`, `buddyId` |
| Dive center detail | as today |
| Dive computer "View dives" | `computerId` |
| Trip "View on map" (both headers) | `tripId`, map |
| Tag chip on a dive (`openDivesWithTag`) | `tagIds` |
| Insights country and region rows (`openInsightsDives`) | as today |
| Connections "Show dives" | `diveIds` |

### 4. Restoring the previous filter

The pushed `DiveListPage` keeps the previous filter from `extra` in its
`State`. When that `State` is disposed (back arrow, system back, or the stack
being replaced by a sidebar tap) it writes the previous filter back, deferred
to after the frame so no provider changes while the tree is finalising. The
provider container is captured while the page is mounted.

The restore is tied to the page, not to the `push` future: in go_router 17.5
a pushed route's future completes only on pop, and `replace` gives the route a
new completer, so the original future never completes once the diver has
selected a dive.

Nested pushed lists unwind in order, each restoring what was in place before
it opened. A top-level dive list (no `extra`) restores nothing.

### 5. The back arrow

Shown only when the dive list page was pushed; it pops.

- desktop list header (`_buildCompactAppBar`): leading `IconButton`,
- table-mode header,
- phone app bar (`_buildAppBar`),
- map view (desktop and phone). The phone map view's existing arrow, today
  `go('/dives')`, pops when the page was pushed, so trip, "View on map",
  back returns to the trip.

The selection app bar is unchanged; it has its own close.

## Testing

Written first (TDD):

- **Redirect helper:** a table of cases (embedded, pushed, root, phone width,
  table mode) to redirect or not.
- **Fixed pages:** one regression test each for equipment, buddy, trip, dive
  center and certification, modelled on
  `test/features/dive_log/presentation/pages/dive_detail_pushed_context_test.dart`:
  pushed over a placeholder at desktop width, the page stays and `pop`
  returns to the placeholder; a root visit still redirects to `?selected=`.
- **`goInPlace`:** on a pushed page it replaces and the page below survives;
  on a root page it goes.
- **`openDiveList` and restore:** sets the filter and pushes; after a
  selection change (`replace`) and a pop, the previous filter is back; removed
  by a `go`, the previous filter is also back; nested lists unwind in order.
- **Back arrow:** shown when pushed and hidden at top level, for the list,
  table and map headers; tapping it pops.
- **Call-site guard:** an architecture test fails if `diveFilterProvider` is
  written next to a `go('/dives')` anywhere except the import wizard.

Before merge: `test/architecture/`, `test/shared/`, and the affected feature
test folders.

## Screenshots

Desktop and phone, before and after:

- dive details, then equipment (no back arrow, then back arrow),
- site, then "View all dives" (no back arrow, then back arrow).
