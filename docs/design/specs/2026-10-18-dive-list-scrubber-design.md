# Dive list scrubber

Date: 2026-10-18. Issue: #3456.

## Why

With a few hundred dives the dive list gets hard to move through: finding a
dive from a past trip means a long scroll with no sense of where you are. The
issue asks for the timeline navigation Immich has in its scrollbar: a thumb on
the right edge you can drag, with labels that tell you where you will land.

The dive list can be sorted six ways, so the orientation has to follow the
sort rather than always being a timeline, and the scrubber shows the sort
value at the thumb.

## Goals

- A draggable thumb on the right edge of the dive list (detailed and compact
  modes) that covers every dive the list shows, not only the loaded ones.
- Markers along the track that follow the active sort.
- The sort value at the thumb, shown inside the scrubber's panel.
- A little context per sort (trips, gases, numbering gaps), the favourite
  dives and the selected dive, without crowding the list.
- Dropping the thumb anywhere lands the list on that dive, loading what it
  needs to.

## Non-goals

- Trips list, sites list and table mode. The scrubber widget is generic so
  they can adopt it later, each in its own change.
- Tapping the track to jump, haptic ticks on markers.
- Windowed loading (keeping only the rows around the target in memory). A far
  drop keeps every row it loaded, and a silent reload re-reads them all.

## Behaviour

### Visibility

- The scrubber floats over the list at the right edge (the left edge in
  right-to-left layouts); it takes no layout width.
- It exists only when the list has more than three viewport heights of dives,
  estimated from the loaded rows' height scaled up to every dive. A list of
  fewer than 20 dives never fetches the index, so it has no scrubber either.
- While it exists it hides the platform's own scrollbar, so desktop shows one
  scroll indicator, not two.
- The thumb appears while the list scrolls or the pointer hovers the 48 px
  strip at the edge, fades in and out over 200 ms, and hides about 1.5 s after
  scrolling stops.
- The thumb looks like the app's scrollbar thumb: thickness, colour, radius
  and edge gap come from the scrollbar theme, with Material's per-platform
  defaults (8 px on desktop, 4 px on Android), in its idle, hovered and
  dragged states. It is a fixed 48 px long, has no icon, and its touch target
  is 48 by 48 px. It follows ordinary scrolling.
- The scrubber is active while hovered, dragged or busy landing a drop. Idle,
  it is only the thumb and the selected-dive dot; the panel shows only while
  active.
- A mouse sweeping across the strip with a button held does not activate it.
- The add-dive button hides while the scrubber is active and returns when it
  goes idle.

### Panel

The panel is a square-cornered column down the end edge, 64 px wide, in
`surfaceContainerHigh` at 70% opacity, with a hairline in `outlineVariant` on
its start edge. It fades in when the scrubber becomes active and leaves the
tree when it goes idle. In date sort it is 19 px wider, for the month bars
(see Per-sort details). Everything on it only paints: the list does not move,
and taps on the panel or beside the thumb reach the rows beneath.

From the start edge inwards it holds the per-sort context column, the month
bars in date sort, the marker labels, the favourite ticks and the thumb.

### Markers

Markers are drawn along the track for the active sort. Each marks a boundary,
like an axis tick: ascending, at the first slot of a bucket; descending, at its
last slot. So in a newest-first log, a dive from April 2022 sits between the
"2023" and "2022" markers.

| Sort | Markers |
|---|---|
| Date | Years; months when the dives span two calendar years or fewer |
| Dive number | Round steps sized to the range: 10, 50, 100 or 500 |
| Site | First letter of the site name, folding ASCII case only, as the site sort's `COLLATE NOCASE` does |
| Max depth | Depth steps in the diver's depth unit: 5 or 10 m, 10, 20 or 50 ft, sized to the range |
| Bottom time | 10, 15 or 30 minute steps, sized to the range |
| Rating | Star counts, and "Unrated" |

Month and year labels follow the diver's date-format preference: a bare month
reads "Mar" under the spelled-out preferences and "03" under the numeric ones.
The earliest month of each calendar year carries the year ("Mar 2024",
"2024-03"); a month that repeats further down carries it only once.

Labels are `labelSmall` in `onSurfaceVariant`, centred on their tick in a
60 px column, each on its own backing (`surfaceContainerHigh` at 0.9, radius 4,
6 px side padding) so it reads over the rows beneath. Markers closer than
28 px are thinned once per marker set and track. Markers level with the thumb
are hidden, and a marker that one of them had thinned away comes back if it
keeps its spacing, so markers away from the thumb never move.

### Current value

While dragging, the sort value at the thumb shows on a band across the panel,
level with the thumb's centre: the value styled and backed like a marker, only
bold, then a short line in the same colour running to the thumb. While a far
drop loads, the band shows the loading label instead.

| Sort | Example |
|---|---|
| Date | Mar 2024, or Mar 2024 · Red Sea on a trip |
| Dive number | #412 |
| Site | Blue Hole |
| Max depth | 32 m |
| Bottom time | 48 min |
| Rating | 4★ |

Depth follows the diver's unit settings and the date follows the diver's
date-format preference. In date sort, a dive on a trip adds the trip name.
Missing values read "--", "Unknown Site" or "Unrated".

The panel keeps its width at all times. A value too long for it makes only
the band stick out past the panel's start edge, as a square tab in the
panel's own translucent colour with the hairline running around it, up to
160 px in all and never more than the host width minus 16. Beyond that the
value is ellipsized. A short value keeps the band inside the panel.

### Favourite ticks

While active, the panel marks each slot holding a favourite dive with a short
horizontal tick, 6 by 2 px, in a column right beside the thumb track, above
the marker labels and below the value band, in the app's favourite colour
(`AppColors.favorite`, the dive card's heart), whatever the sort. A collapsed
trip's slot is ticked when any of its dives is a favourite. Ticks closer than
2 px merge.

### Selected dive

When the detail pane shows a dive, or the keyboard cursor highlights one, a
6 px dot in `primary` marks its slot on the thumb's column, above the thumb. A
dive inside a collapsed trip marks the trip's slot. The dot shows whenever the
thumb does, idle or active.

### Per-sort details

While active, three sorts add a detail in a 4 px context column just inside
the panel's start edge, apart from the thumb column. Other sorts show none.

- **Date:** a stripe per run of consecutive slots on the same trip, as the
  list's trip sections run, in `tertiary` at 0.7. Stripes are at least 2 px
  tall with 1 px between neighbours, and a collapsed trip's stripe covers its
  one slot. Dragging over a trip's slot shows "value · trip name".
- **Date, month bars:** beside the context column, one bar per calendar month
  of the sort timestamp, in slot order, as long as its dive count against the
  busiest month's (at most 12 px, at least 2 px), in `onSurfaceVariant` at
  0.35. A collapsed trip's slot counts all its dives in its first dive's
  month. The bars leave out the value band.
- **Max depth:** a 3 px tick per dive in the profile chart's gas colours
  (`GasColors.air`, `GasColors.nitrox`, `GasColors.trimix`), classed with the
  chart's thresholds by the richest gas across the dive's tanks: any helium is
  trimix, otherwise O2 above 22% is nitrox (pure oxygen counts as nitrox),
  otherwise air. A dive with no tanks gets no tick, and a collapsed trip's
  slot takes the richest class of its dives. Air ticks paint first, under
  nitrox and trimix.
- **Dive number:** a tick in the warning colour at each numbered dive whose
  number skips ahead of or repeats the previous numbered dive in list order,
  in the sort direction. Unnumbered dives are passed over.

### Dragging and landing

- Over dives already loaded, the list follows the thumb live (jump, no
  animation). Dragging past either end of the track and back moves the thumb
  at once.
- Over dives not loaded yet, only the thumb and its value follow. On release
  the list loads through the target in one query, showing the loading label,
  and then lands on it.
- The list lands with the target dive at the top, below its trip's pinned
  header when it is inside an expanded trip. A target inside a collapsed trip
  lands on that trip's header; the trip stays collapsed.
- The dive is not selected or opened, and the detail pane keeps what it
  showed.
- Overlapping drops: only the latest one clears the loading state and lands.
  A failed load is logged and clears the loading state.
- If the target dive is gone by the time the load finishes, the list stays
  where it is.
- If the list shrinks below the threshold mid-drag, the drag is dropped
  without landing.

### Unchanged

Mouse wheel, ordinary scrolling, keyboard navigation, pull to refresh,
selection mode, search and filters all work as before. The scrubber spans
exactly the dives the list shows under the current filter.

## Design

### Slots

The track represents the list as slots: one per dive, except that a collapsed
trip (with trip grouping on) is a single slot, because its dives take no
height on screen. The thumb sits at `slot / slotCount`. Positions are by count,
not by pixels, so varying row heights do not matter. A slot carries its first
dive, that dive's position in list order, the collapsed trip id, and whether
any dive it stands for is a favourite.

During ordinary scrolling the thumb maps the scroll offset proportionally
onto the loaded slots; dragging over loaded slots maps back the same way, so
the two never disagree. Landing on a dive after a drop uses the keyboard
navigator's existing reveal logic (`KeyboardListNavigator.revealRow`), which
builds an off-screen row by jumping toward it and then aligns it at the top
without moving the cursor, instead of a second copy of an offset estimate.

### Scrubber index

`DiveRepository.getDiveScrubberIndex({diverId, filter, sort})` returns one
`DiveScrubberEntry` per dive the list would show:

- `id`, `tripId`, `tripName` (both through the `trips` join, as the list reads
  them)
- `sortTimestamp`, `diveNumber`, `siteName`, `maxDepth`, `bottomTime`,
  `rating`, `isFavorite`
- `gas`: air, nitrox or trimix, or null with no tanks, from the highest O2 and
  helium across the dive's tanks, read from one aggregated join
  (`MAX(o2_percent)`, `MAX(he_percent)` over `dive_tanks` grouped by
  `dive_id`) and classed through `GasMix`, the same getters the chart's
  `GasColors.forMixPercent` now uses

It builds its WHERE and ORDER BY with the same private helpers as
`getDiveSummaries` (`_buildFilterWhereClauses`, `_buildSortOrderBy`), so its
order matches the list by construction. It selects none of the columns only
the list rows need (gas mix labels, safety badges, media, buddies). The entry
has `copyWith`.

`diveScrubberIndexProvider` holds a `DiveScrubberIndex`: the entries plus the
diver, filter and sort they were built for. The paginated list state carries a
`revision` that each reload from the top bumps (diver, filter or sort change,
and the list's own table ticks), never a page load or `loadThrough`. The
provider watches it only while the list's total count is at least
`diveScrubberMinDives` (20); a shorter list gets an empty index without a
query. It loads once the list is on screen, so markers are ready on first
scroll.

The scrubber uses an index only when it was built for the current diver,
filter and sort. A refetch for the same query (a sync tick, an edit) keeps the
previous index until the new one lands, so a drag in progress survives it. A
change of diver, filter or sort shows no scrubber until the matching index
lands, so an old index is never mixed with new rows.

### Loading through a target

`PaginatedDiveListNotifier.loadThrough(diveId, targetIndex:)` fetches the rows
from the current end of the list through the target, plus one page, in one
query, using the same cursor or offset paging as `loadNextPage`. It runs
through the notifier's paging queue, so it cannot interleave with a page load
or reload, and keeps the spinner flag of a page load queued behind it. The
target's position comes from the scrubber index. It returns whether the target
is loaded afterwards; if not, the list is left as loaded.

The scrubber addresses dives by id, never by row number, so a brief mismatch
between index and list (a write landing between their refreshes) can at worst
show a stale marker, never land on the wrong dive.

### Profiles

A far drop can add thousands of rows, and decoding every mini profile at once
would stall the list. `loadThrough` preloads profiles only for the last 100
rows it added, where the target sits. Every card that builds without a cached
profile asks `DiveProfileBatcher` for it; the batcher gathers the requests of
one frame into one `getBatchProfileSummaries` call, skips dives that are
cached, being fetched or already requested, and logs failures. Page preloads
go through the same batcher, so a dive is never fetched twice at once.

### Caching

`DiveListScrubber` keeps its derived data between builds:

- slots and favourite slots, rebuilt when the entries (by identity), trip
  grouping or the collapsed trips change
- markers, per-sort segments and ticks and month bars, rebuilt when the slots,
  sort field or direction, depth unit, date-format preference, locale or theme
  colours change
- the loaded slot count, when the slots or the loaded rows change
- the selected slot, when the slots or the selected dive change

The panel caches its marker positions and thinning per marker set and track,
and its shown markers per set of markers level with the thumb, so scrolling
while hovered does not re-thin. The tick, context and bar painters sit behind
repaint boundaries and repaint only when their lists change identity. The
add-dive button watches the scrubbing flag itself, so a flip rebuilds only
the button, not the page.

### Add-dive button

`ListScrubber.onActiveChanged` reports after a frame in which the scrubber
became active or idle. `DiveListScrubber` writes it to
`diveListScrubbingProvider` and clears it on dispose. `DiveListAddFab` scales
to nothing while the flag is set and then takes no taps, focus or semantics.
It implements `MasterDetailCreateFab`, so `MasterDetailScaffold` re-targets it
at its create handler instead of wrapping it in a tap and semantics layer that
would still catch taps while it is hidden.

### Units

1. `ListScrubber` (`lib/shared/widgets/list_scrubber/`): the generic widget.
   Takes the scroll controller, slot and loaded slot counts, a label callback,
   markers, a drop callback (`onScrubEnd`), a busy label, `onActiveChanged`,
   the highlighted slot, highlight ticks and their colour, `segments`
   (`ScrubberSegment`), `contextTicks` (`ScrubberTick`) and `density`
   (`ScrubberDensityBin`). Owns thumb, panel, current value, marker thinning,
   fading, hover and RTL mirroring, with the panel, edge, tick, context and
   bar painters, the geometry functions and `ListScrubberThumbStyle` beside
   it. Knows nothing of dives.
2. `DiveScrubberEntry` and `DiveScrubberGas`
   (`lib/features/dive_log/domain/entities/`).
3. Pure helpers (`lib/features/dive_log/presentation/helpers/`): value text and
   markers per sort (`dive_scrubber_labels.dart`), slots and favourite slots
   (`dive_scrubber_slots.dart`), and trip runs, gas slots, number gaps and
   month bins (`dive_scrubber_details.dart`).
4. `getDiveScrubberIndex`, `diveScrubberIndexProvider` and
   `diveListScrubbingProvider`.
5. `PaginatedDiveListNotifier.loadThrough` and `DiveProfileBatcher`.
6. `DiveListScrubber`: wires 1 to 5 into the dive list.
   `dive_list_content.dart` only wraps its scroll view in it and lands a drop
   through `KeyboardListNavigator.revealRow`.
7. `DiveListAddFab` and `MasterDetailCreateFab`.

Small additions elsewhere: `UnitFormatter.formatMonthOnly`,
`AppColors.favorite`, and `GasColors.forMixPercent` delegating to `GasMix`.

### Strings

Two new localized strings in all locales: the "Unrated" marker and value, and
the "value · trip" current value. The loading label is the existing common
one. Month and year labels follow the diver's date-format preference.

## Testing

- Repository: for every sort field in both directions, with an active filter
  and with ties on the sort value, `getDiveScrubberIndex` returns ids in exactly
  the order `getDiveSummaries` does. It also carries the values the labels
  read, classes each dive by the richest gas across its tanks, and reads the
  trip id through the join as the list does.
- Entry: gas classes at the chart's boundaries, agreement with `GasColors` on a
  grid of O2 and helium values, no tanks as unclassified, and `copyWith`.
- Labels and markers: the value alone for every sort, metres and feet, the date
  preference, missing values; boundary markers in both directions, months for
  a short span and years for a long one, the year on the earliest month only,
  numeric month preferences, accented site initials, "Unrated".
- Slots and details: trip grouping on and off, collapsed and expanded trips,
  favourites; trip runs, gas slots, number gaps in both directions and month
  bins, including collapsed trips.
- Index provider: a short list never queries, a long one does, a filter change
  gives the filtered subset, and a table tick refetches.
- `loadThrough`: one query, waits behind a page load in flight, keeps a queued
  page load's spinner, leaves the list as loaded when the target has vanished,
  and preloads one window of profiles at its target. The revision bumps on
  reloads, not on page loads.
- Profiles: the batcher sends one deduplicated batch per frame, skips cached
  and in-flight dives and swallows failures; cards built without a profile
  fetch theirs in one batch.
- `ListScrubber`: absent for a short list, appears on scroll and fades out,
  follows ordinary scrolling, hides the platform scrollbar on desktop, keeps
  the scroll offset when it appears, clamps a held slot and an overshoot,
  drops a drag whose thumb unmounts, idle shows only the thumb, hover and drag
  show the panel, the value on its band and its sticking-out tab within
  limits, marker hiding and thinning, the themed thumb against Material's
  `Scrollbar`, the 48 px touch target, active reports and held-button sweeps,
  taps passing through, RTL, and the dot, ticks, context column and bars.
- Dive list: dropping past the loaded rows, including mid-list, lands the
  target at the top with the selection unchanged; a collapsed trip lands on
  its header and an expanded one below its pinned header; a vanished target
  stays put; overlapping and failed drops; a stale index is never used after a
  filter or sort change but kept through a same-query reload; per-sort
  details, favourite ticks and the selected dot follow the index, sort and
  date preference; caches are reused while their inputs hold.
- Add-dive button: hidden while scrubbing on phone and in master-detail, taps
  reach the row beneath it, no create semantics or focus while hidden, and a
  flip rebuilds only the button.
