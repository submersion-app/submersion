# Trip Story Split Band

Date: 2026-09-20
Status: approved design, implementation plan pending
Branch: ericgriffin/trips-map-screen-space-f72bd0
Issue: none yet. Open one before the PR and link it with `Closes #N`.

## Problem

On the trip story (trip detail Overview) the map costs too much of the
screen, and it costs it permanently.

Two pinned layers stack at the top of the narrow layout:

- `TripStoryMapHeaderDelegate`, a pinned `SliverPersistentHeader` that opens
  at 260px and parks at 180px.
- Each day chapter's `TripStoryDayHeader`, a `PinnedHeaderSliver` with a 52px
  floor that sticks directly below the map.

While a diver is reading, 232px of a roughly 700px phone viewport is chrome,
about a third of the screen. The lower layer does all the naming (day number,
date, day type, port, sites, weather); the upper layer contributes geography
that a 180px band conveys poorly.

The wide layout (the story's own constraints at or above 900px) has the
mirror problem: the map is a fixed 380px column wrapped in an `Expanded`, so
on a 900px-tall window it renders roughly 850px of map.

## Decisions

Taken during brainstorming and fixed for this spec.

- The two pinned layers merge into one band. The day occupies the start half,
  the map the end half.
- The band is continuous, not two-state: the map's width and the day panel's
  opacity interpolate with the header's `shrinkOffset`.
- One layout at every width. The 900px branch, `_wideBreakpoint` and the
  `trip-story-wide-layout` key are deleted.
- Day headers stop being pinned and become ordinary chapter content.
- The docked day and the map camera share one index, so the band's two halves
  can never name different days.
- The docked panel is tappable and scrolls its chapter back into view.
- No width quantization. The morph runs per frame, and a profile run decides
  whether any bounding is needed later.

## Geometry

One pinned `SliverPersistentHeader` replaces both of today's pinned layers.

| | Expanded (at rest) | Docked (parked) |
| --- | --- | --- |
| Band height | 260px | 96px |
| Map width | 100% | 50%, at the end edge |
| Day panel | absent, faded out | 50%, at the start edge |

Interpolation runs on `t = shrinkOffset / (maxExtent - minExtent)`. The map's
width goes from 100% to 50% across the whole of `t`. The day panel's opacity
runs on a later interval, roughly `t` 0.5 to 1.0, so it never sits half
visible beside a still-wide map.

Both extents are computed, not hardcoded, from
`MediaQuery.textScalerOf(context)` read in the view's build, following the
`day_rhythm_bar.dart` precedent:

- `docked = max(96, scaledDayPanelHeight)`
- `expanded = max(260, docked + 100)`

`scaledDayPanelHeight` is the compact panel's intrinsic height at the current
scaler: the scaled line heights of the date and subtitle, plus the band's
vertical padding, floored by the 28px day badge.

A fixed extent is the price of `SliverPersistentHeader`, and the day header
used `PinnedHeaderSliver` precisely to avoid it. Computing the extents from
the scaler preserves that property: at 200% text the band grows instead of
clipping the date.

The band uses start and end edges, never left and right, so RTL locales
mirror.

With the 380px column gone, the band and the story slivers share a centered
max content width of 900px so the story does not stretch across a very wide
window. `TripStatStrip` stops being pinned in a column and becomes ordinary
scroll content, which is what it already is in the narrow layout.

## Docking behavior

Each chapter's `TripStoryDayHeader` moves into its `SliverMainAxisGroup` as
ordinary content. It still scrolls with its chapter and still carries
`_dayKeys[index]`; it simply no longer sticks.

`_onScroll` keeps its existing machinery (frame-timestamp throttle,
`_dayKeys` positions, reverse iteration, the day 0 fallback) with one change:
the threshold moves from `viewportTop + viewportHeight / 3` to
`viewportTop + currentBandExtent`. The docked day is therefore the last
chapter whose heading has travelled above the band's bottom edge, which is
the exact moment its full-width heading disappears under the band. That
timing is what makes the swap read as a hand-off rather than a glitch.

The map camera follows the same index. The accepted consequence is that the
camera eases to a new day later than it does today: on reaching the chapter
rather than when the chapter is a third of the way up the viewport.

The panel cross-fades with an `AnimatedSwitcher` of about 200ms, paired with
a small upward slide, so the incoming day appears to continue the travel the
full-width heading was already making.

The panel renders a compact variant of `TripStoryDayHeader`: day badge, date,
subtitle and weather badge, all of which already ellipsize to one line. The
`Planned` chip is omitted in the compact variant, because at roughly 195px on
a phone it would consume the subtitle, and the chapter's own full-width
heading still carries it.

Tapping the panel calls the existing `_scrollToDay`, mirroring what tapping a
map pin already does.

## Performance

The morph forces `FlutterMap` to re-run layout and recompute its visible tile
set on every width change. Tiles come from `TileCacheService`, so this is
layout and widget churn rather than network traffic.

Mitigations:

- The `FlutterMap` subtree is built once and held in the `State`, with only a
  sizing wrapper animating around it, so widget identity is stable every frame
  and Flutter pays for layout only.
- A `RepaintBoundary` wraps the map so its raster is not merged with the day
  panel fading beside it.
- The existing `shouldRebuild` discipline is preserved: the stable
  `MapController` and the named `_onPinSelected` callback exist so the pinned
  map is not rebuilt on every parent rebuild.
- Interaction stays `InteractiveFlag.none`, so there is no gesture arena work.

Verification is a profile run, since frame cost is invisible to widget tests:
`flutter run --profile` on a real Android device, collapsing and expanding the
band repeatedly, reading worst-frame times from the DevTools timeline. If the
worst frame is unacceptable, the ordered escape hatch is to quantize the
interpolated width (4px steps, then 8 or 12), and only then to fall back to a
threshold-driven snap dock.

## Edge cases

- **No mappable points.** The existing `_MapFallback` gradient keeps the map
  half. The band does not restructure itself, so adding a site mid-trip does
  not reshuffle the layout.
- **No days at all.** The panel's day 1 fallback has nothing to fall back to.
  An empty story docks with no panel and the map keeps the full width.
- **Story shortening.** The `didUpdateWidget` clamp that survives a refresh
  removing days is unchanged.
- **Surface days.** They have no card body and their header is the whole
  chapter. As ordinary content that still holds.

## File organization

`trip_story_map_header.dart` is already about 300 lines carrying the camera
animator, the delegate, the map, the fallback and the stat strip. The work
splits it:

- `trip_story_band.dart` (new): the band delegate.
- `trip_story_docked_day.dart` (new): the compact day panel.
- `trip_stat_strip.dart` (new): `TripStatStrip`, which lives in the map header
  file only by accident.
- `trip_story_map_header.dart`: the map widget, the fallback and
  `MapCameraAnimator` stay.
- `trip_story_view.dart`: restructured, wide branch deleted.
- `trip_story_day_header.dart`: gains the compact variant.

## Localization

The tappable panel needs a semantics label, so one new ARB key is added
across all 11 locales. Only `app_en.arb` is alphabetical, so the insert is
anchored on a neighbouring key in each file rather than appended.

## Testing

Written first. Ten tests, two of which replace existing ones.

1. Scrolling docks the band: its extent equals the docked height and the panel
   shows the expected day.
2. The docked day's full-width heading is no longer on screen. Replaces
   `day header sticks below the collapsed map while scrolling`.
3. The panel changes as a heading crosses the band's bottom edge, not at a
   third of the viewport.
4. The map camera follows the docked index, reusing the existing
   marker-opacity assertion.
5. Tapping the panel scrolls that chapter's heading back into view.
6. At 1400x900 there is no `trip-story-wide-layout`, there is one band, and
   content is centered at 900px max. Replaces `wide layout docks the map
   beside the story`.
7. At 200% text the band grows and the date is not clipped.
8. Under RTL the day panel sits at the start edge.
9. A story with no days, and a trip with no map points, both render without
   crashing.
10. The stat strip still scrolls away. Unchanged from today.

## Out of scope

- The trips list map in table mode, which already has an on/off toggle.
- Any change to what the map draws: route, pins, fallback and attribution are
  untouched.
- Any change to day card contents, the hero, the checklist or notes closers.
