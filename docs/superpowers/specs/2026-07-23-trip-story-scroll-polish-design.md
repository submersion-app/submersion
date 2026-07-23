# Trip Story Scroll Polish — Design

**Date:** 2026-07-23
**Status:** Approved
**Scope:** Narrow (scrolling) layout of the trip detail story view. The wide
(>= 900px) layout keeps its fixed side-panel map and is visually unchanged.

## Problem

Three scroll-related problems in the trip story view
(`lib/features/trips/presentation/widgets/story/`):

1. **Collapsed map is useless.** The pinned map header shrinks from 260px to a
   120px `minExtent`, and ~50px of that is the stat strip pinned under the
   map. The map itself ends up roughly 70px tall and full width — too short to
   read.
2. **No day orientation while scrolling.** The "Day N - date" title lives
   inside each day's `Card`, so it scrolls away with the card. Deep in a long
   trip you cannot tell which day you are looking at.
3. **Redundant profile minimap.** Each dive row renders a right-side
   `DiveSparkline` next to `DiveListItem`, but the shared configurable dive
   card already renders its own profile minimap.

## Decisions (user-confirmed)

- Map stays pinned while scrolling, but with a taller collapsed height
  (~180px) so it remains usable.
- The trip-level stat strip is no longer pinned; it scrolls away with the top
  of the page.
- Day/date headers become sticky: pinned below the map until the next day's
  header pushes them out.
- Sticky header content: two compact lines — "Day 3 - Wed, Jul 8" (bold) plus
  the day-type/port/sites subtitle, ellipsized to one line.
- The right-side `DiveSparkline` is removed entirely.

## Approach

Sticky day headers use **`SliverMainAxisGroup` + pinned
`SliverPersistentHeader` per day** (framework-native, Flutter 3.13+). Group
semantics bound each pinned header to its group's extent, giving exactly the
"sticky until the next day arrives" behavior, and pinned headers stack
automatically below the pinned map header. Rejected alternatives: the
`flutter_sticky_header` package (unnecessary dependency) and a custom overlay
driven by the existing scroll tracking (rebuilds the hand-off animation the
framework provides free).

## Changes

### 1. Map header — `trip_story_map_header.dart`, `trip_story_view.dart`

- `TripStoryMapHeaderDelegate` becomes map-only: remove `TripStatStrip` from
  its `build`. `maxExtent` stays 260; `minExtent` rises from 120 to **180**.
- Narrow layout: `TripStatStrip` moves into a `SliverToBoxAdapter` placed
  immediately after the pinned map header (before the hero), so trip totals
  scroll away.
- Wide layout: the 380px side panel renders `Column(map, TripStatStrip)`
  explicitly, preserving today's visual (nothing scrolls in the panel).

### 2. Sticky day headers — `trip_story_view.dart`, `trip_story_day_card.dart`

- Replace the single `SliverList.builder` of day cards with one
  `SliverMainAxisGroup` per day:
  - a pinned `SliverPersistentHeader` (fixed extent ~52px) with the day
    title + subtitle on an opaque `surface` background, so cards scroll
    underneath cleanly. The "Planned" chip for future days rides in the
    header row.
  - a `SliverToBoxAdapter` with the day card body.
- Extract the header out of `TripStoryDayCard`; the card body keeps the day
  stat strip, rhythm bar, dive rows, photo strip, sightings, and planned
  extras.
- Surface days (no dives/media/itinerary) keep the slim `_SurfaceDayRow` with
  **no** sticky header.
- The "Today" divider stays inside its day's group, above the card.
- The existing GlobalKey + scroll-notification tracking that drives the map
  pin highlight is unchanged; keys attach to each day's group content.
- Day count per trip is small (tens), so building one group per day inside
  the `CustomScrollView` has no meaningful cost; slivers within groups remain
  lazy.

### 3. Sparkline removal — `trip_story_day_card.dart`

- Delete the `Row` wrapper and right-side `DiveSparkline(diveId: ...)` next to
  each `DiveListItem`; the dive card fills the full width.
- Delete `lib/features/trips/presentation/widgets/story/dive_sparkline.dart`
  and its tests (`test/features/trips/presentation/widgets/story/
  dive_sparkline_test.dart`). The separate
  `lib/core/presentation/widgets/dive_sparkline.dart` (used by the combine
  dives dialog and import wizard) is untouched.

## Error handling

No new failure modes: no I/O, no async work added. The sticky header renders
from data already present in `TripStoryDay`. Empty-subtitle days render the
header with the title line only.

## Testing

Update/extend the trip story widget tests:

- Map header: collapsed extent is 180; stat strip is not pinned (absent after
  scrolling past the top content).
- Sticky headers: a day's header is pinned below the map while its content is
  on screen; scrolling into the next day replaces it; surface days pin
  nothing.
- Day card: no `DiveSparkline` in the tree; dive rows fill the card width.
- Wide layout: stat strip still present in the side panel.
