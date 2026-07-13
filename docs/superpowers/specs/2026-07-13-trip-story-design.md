# Trip Story: Interactive Day-by-Day Trip Breakdown

**Date:** 2026-07-13
**Issue:** #166 (Daily breakdown view for non-liveaboard trips)
**Branch:** feature/trip-story

## Implementation deviations (recorded 2026-07-13, post-build)

Notes discovered while implementing; the design above stands, these refine it:

- **DST day-span math:** `buildTripStory` counts days with
  `(inHours / 24).round() + 1`, not integer division, because a spring-forward
  boundary inside the range makes the hour delta 71 not 72 (mirrors
  `ItineraryDay.generateForTrip`). Caught by TDD on a March-8 fixture.
- **DST rhythm placement:** the day-rhythm bar positions dives by wall-clock
  `hour/minute/second`, not `difference()` from midnight, which measures
  elapsed physical time and shifts an hour across DST. Dive times are
  wall-clock-as-UTC here, so the components are the truth.
- **Sparkline source:** no `diveProfileSparklineProvider`; `divesForTripProvider`
  already hydrates `dive.profile`, so `DiveSparkline` downsamples it directly.
- **Checklist placement:** planned/in-progress trips show the checklist in the
  hero; past non-liveaboard trips show it as a collapsed progress tile
  (`"N of M done"`) at the story's end (liveaboards keep their dedicated tab).
- **Test-surface gotchas:** lazy `SliverList` only builds on-screen day cards,
  so story-view widget tests use a tall (2600px) viewport; a null
  `liveaboardDetails` renders the vessel section as a zero-size `shrink` that
  `find.byType` skips by default, so that test supplies real details.
- **OSM tile user-agent test (#132):** the retired `TripVoyageMap` and old
  overview-map groups were consolidated into one group covering the new story
  map header's tile user agent.
- **Detail-page tests:** 13 page-level tests asserting the old overview body
  (Statistics/Dives/Notes section titles, empty-dives message) were removed;
  that content moved to the story and is covered by `trip_overview_tab_test.dart`
  and the story widget tests. A single page-level test verifies the page wires
  the story in.

## Summary

Rebuild the trip detail Overview tab as an interactive, scroll-driven "trip
story": a vertical day-by-day narrative with a pinned map that follows the
reader through the trip. Every trip type gets a daily breakdown (resolving
issue #166), and the same experience renders planned trips (itinerary-driven),
past trips (dive-driven), and in-progress trips (a blend of both, separated by
a "today" divider).

## Motivation

- Issue #166: the existing `TripDailyBreakdown` widget is liveaboard-only and
  driven entirely by itinerary days; non-liveaboard trips get no day-level
  view even though shore diving has a strong daily rhythm.
- The Overview tab is a long static column of cards; the when/where narrative
  of a trip (which sites on which days, in what order) is invisible.
- Planned trips currently show almost nothing useful on the Overview tab
  despite itinerary days and checklists existing as planning features.

## Key design decisions (from brainstorm)

1. **Unified design:** one feature covers #166 and the interactive
   visualization; the daily breakdown is the story's backbone.
2. **Placement:** rebuild the Overview tab (not a new tab, not fullscreen).
3. **Metaphor:** Story Scroll - vertical day chapters with a pinned map that
   pans/highlights as the user scrolls (chosen over map-hero and
   calendar-strip alternatives).
4. **Day chapter contents:** day stat strip, 24h day-rhythm bar, depth
   profile sparklines on dive rows, per-day photo strip, marine life badges,
   header context line (sites, conditions, itinerary day type).
5. **Planned-trip mode:** countdown hero, checklist progress with due-soon
   items, planned route map, itinerary day chapters, destination context
   pills from the diver's own site history, and in-progress blending.
6. **Full absorption:** the story replaces the existing Overview content.
   Utility actions move to the app bar overflow menu. `TripDailyBreakdown`,
   `TripVoyageMap`, and the inline dives list are retired;
   `TripEnhancedStats` content folds into the stat strips.
7. **Architecture:** unified view-model (`tripStoryProvider`) composing all
   sources into one day list; rendering via `CustomScrollView` with a pinned
   map header (chosen over distributed per-widget providers and an
   animation-timeline engine).

## Domain model

New entities in `lib/features/trips/domain/entities/`:

### `TripStoryDay`

| Field | Type | Notes |
| ----- | ---- | ----- |
| `date` | `DateTime` | Calendar day (date-only semantics) |
| `dayNumber` | `int` | 1-based from the story's first day |
| `itineraryDay` | `ItineraryDay?` | Planning metadata when present |
| `dives` | `List<Dive>` | Time-sorted dives on this day |
| `media` | `List<MediaItem>` | This day's photos/videos (joined from per-dive trip media) |
| `sightings` | `List<MarineSighting>` | Species records for this day's dives |
| `kind` | `TripStoryDayKind` | `past` / `today` / `future`, date-only derivation |

Derived getters: `diveCount`, `totalBottomTime`, `maxDepth`, `siteIds`,
`siteNames`, `hasContent`.

### `TripStory`

| Field | Type | Notes |
| ----- | ---- | ----- |
| `trip` | `Trip` | |
| `days` | `List<TripStoryDay>` | Complete day span, in order |
| `stats` | `TripWithStats` | Reuses existing trip-level stats |
| `checklist` | `TripStoryChecklistSummary` | done/total plus next due items |
| `mapGeometry` | `TripStoryMapGeometry` | Ordered per-day site/port points and the route polyline, precomputed |

### Day span rule

Days run from `min(trip.startDate, earliest dive date)` to
`max(trip.endDate, latest dive date)`. Dives assigned to the trip but logged
outside its nominal dates still get a chapter. Days with no dives and no
itinerary content are still emitted and render as slim "surface day" rows,
preserving the trip's real rhythm.

### `buildTripStory` (pure function)

```dart
TripStory buildTripStory({
  required Trip trip,
  required List<Dive> dives,
  required List<ItineraryDay> itineraryDays,
  required Map<String, List<MediaItem>> mediaByDive,
  required Map<String, List<MarineSighting>> sightingsByDive,
  required List<TripChecklistItem> checklistItems,
  required DateTime today,
})
```

Note on sightings: `divesForTripProvider` hydrates dives without their
`sightings` collection (only `getDiveById` loads it). Rather than N
per-dive queries, add a batched `getSightingsForDives(List<String> diveIds)`
to `SpeciesRepository` and feed the result in as `sightingsByDive`.

All grouping/joining logic lives here, in the domain layer, unit-testable
with no mocks. `today` is injected so date-boundary behavior is testable
(existing `Trip.isUpcoming`/`isInProgress` call `DateTime.now()` internally;
the story pipeline does not inherit that).

## Providers

- `tripStoryProvider(tripId)`: `FutureProvider.family` that watches the
  existing source providers (`divesForTripProvider`, `itineraryDaysProvider`,
  `mediaForTripProvider`, checklist) plus the new batched sightings fetch,
  and calls `buildTripStory`. Sync-driven invalidations cascade through the
  watches.
- `siteHistoryProvider(siteId)`: family returning average temperature,
  visibility, and depth from the diver's past dives at that site. Queried
  lazily per planned day chapter (planned trips must not pay history-query
  cost up front). Days at sites with no history show no context pills.
- `diveProfileSparklineProvider(diveId)`: returns a downsampled point list
  (about 40 points) for the row sparkline. Loaded lazily per visible row.

## Rendering

`TripOverviewTab` is rebuilt around a `CustomScrollView`:

1. **Pinned map header** (`SliverPersistentHeader`): flutter_map wrapped in
   the existing `TrackpadZoomMap`, showing all site/port pins and the route
   polyline; shrinks from about 260px to about 120px on scroll. The
   trip-level stat strip (dives, bottom time, max depth, sites) sits at its
   base and stays visible.
2. **Hero sliver**: trip name, dates, type icon. Future trips add the
   countdown hero and checklist progress card; in-progress trips show a
   compact "Day N of M" variant.
3. **Day chapter slivers**: one `TripStoryDayCard` per day, with a "today"
   divider inserted between past and future chapters on in-progress trips.

### Scroll-to-map linkage

A scroll listener resolves the active day (the chapter crossing a line about
one third down the viewport) and animates the map camera to that day's
points with an eased `AnimationController`-driven move (same approach as the
current `TripVoyageMap`). Active-day pins render full color; others dim.
Tapping a pin scrolls the story to that day (reverse linkage).

### `TripStoryDayCard`

- Header: day number and date; itinerary day type and port when present;
  site names; conditions summary.
- Day stat strip (dives, bottom time, max depth, sites) using the existing
  `StatRow` visual language, horizontal.
- Rhythm bar: CustomPainter plotting dives as blocks on a 24h axis; night
  dives tinted differently; surface intervals visible as gaps.
- Dive rows: reuse the shared `DiveListItem` widget (single source of truth
  for dive rows) with a new optional sparkline slot.
- Photo strip: horizontal thumbnails; tap opens the trip gallery.
- Marine life badges from that day's sightings.
- Planned/future days: dashed border, itinerary notes, context pills.
- Empty past days: one slim "surface day" line.

### Wide layouts

On wide panes (macOS/desktop, detail pane) the map docks as a persistent
side column next to the scrolling story instead of a pinned top header -
the same breakpoint-driven adaptation pattern as the dive detail page's
`ResponsiveSectionPair`.

### Disposition of existing Overview content

| Current element | Destination |
| --------------- | ----------- |
| Trip header with map background | Replaced by pinned map header + hero sliver |
| Vessel section (liveaboard) | Compact section under the hero |
| Info card (location/resort/vessel) | Folded into hero |
| Trip stats card | Trip-level stat strip in pinned header |
| `TripEnhancedStats` | Folded into trip/day stat strips; widget retired |
| `TripDailyBreakdown` | Replaced by day chapters; widget retired |
| `TripVoyageMap` | Replaced by pinned map header; widget retired |
| Checklist section | Planned/in-progress: checklist card in hero; past trips: collapsed expandable at story end. Liveaboard checklist tab unchanged |
| Notes | Compact section after the last chapter |
| Photo section | Per-day photo strips; trip gallery unchanged |
| Inline dives list | Replaced by chapter dive rows |
| Scan for dives / gallery scan / Lightroom scan | App bar overflow menu |

## Mode behavior

- **Past trip:** dive-driven chapters; no countdown; checklist collapsed at
  the end.
- **Planned trip:** countdown hero, checklist progress card, dashed
  itinerary chapters, planned route. No itinerary: hero offers "Generate
  itinerary" (reusing `ItineraryDay.generateForTrip`); future days render as
  slim date-only rows.
- **In-progress:** past days real, future days planned, "today" divider
  between; "Day N of M" in the hero.
- **Degenerate:** zero dives and zero itinerary shows an empty-state chapter
  area with CTAs (scan for dives, generate itinerary). No mappable points:
  header falls back to the existing gradient hero card instead of a map.

## Error handling and resilience

- The story renders with whatever data loaded: media or sightings failures
  degrade to chapters without photo strips/badges; they never fail the page.
- Reloads render through last-known values (`AsyncValue.value` pattern) to
  avoid loading-flash during sync invalidation storms.
- Dives without sites contribute no map points; dives without profiles show
  an empty sparkline slot.

## Conventions

- All displayed units go through `UnitFormatter` (respects active diver's
  unit settings).
- Every new string is localized into all 10 non-English locales and l10n is
  regenerated.
- RTL-safe layout; `Semantics` labels on stat strips, the rhythm bar
  (textual description), and dive rows, matching existing patterns.
- No emojis in code or docs; `dart format .` clean.

## Testing

TDD throughout; 80 percent minimum coverage on new code.

- **Unit (deepest):** `buildTripStory` - day-span rule including dives
  outside nominal trip dates, `kind` derivation at date boundaries via
  injected `today`, grouping correctness, empty-day synthesis, checklist
  summary math. Rhythm-bar layout math and sparkline downsampling as pure
  functions.
- **Widget:** `TripStoryDayCard` in past/planned/surface-day variants;
  planned-trip hero (countdown, checklist card); today-divider placement;
  map-header fallback with no points; scroll listener to active-day
  resolution.
- Existing `TripOverviewTab` tests are rewritten against the new structure.
  The 428 passing trips-feature tests are the regression baseline.

## Out of scope

- External weather/conditions APIs (context pills use only the diver's own
  history).
- Changes to the trip list page, trip edit page, gallery tab, or liveaboard
  itinerary/checklist tabs beyond the dispositions listed above.
- Database schema changes: none required; the feature composes existing
  tables.
