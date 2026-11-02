# Trip details hero cards

Issue #4106. Release v1.8.4.

## Intent

The trip story is hard to look at. The trip header is two blocks divided by
shading (title area on the page surface, tinted stat strip under it) and each
day shows three stacked surfaces (tinted header band, a card with the map, a
tinted box inside that card with the stats, timeline and conditions). Both
become one hero card each, using the map fade the dive details header already
uses.

## Approved design

Trip hero card, replacing the title block and the stat strip:

- One card at the top of the story. Backdrop: a non-interactive map of every
  located site on the trip, fading into the card colour toward the bottom
  through `HeaderMapBackdrop`. Dark mode fades into the dark card colour.
- No located sites: a deep-to-light gradient in the theme's primary blues with
  white text.
- Content: trip icon, name, date range with day count, the "Day N of M" or
  "N days until" line, then the four trip stats (dives, runtime, max depth,
  sites) in the opaque band at the bottom.
- The checklist progress and the empty-trip prompt follow under the hero as
  ordinary content. Cylinders, flight countdown, vessel, notes and documents
  are unchanged.

Day hero, replacing the tinted header band and the tinted inner stats box:

- The day card's top is the day's map with the header row in its fade: day
  number badge, date, type/port/sites line, weather badge, Today or Planned
  chip.
- Then the stats row, the 24 hour timeline and the conditions line, untinted,
  inside the same card.
- Dive rows, photos and sightings stay inside the card below, as today. Pin
  taps still highlight dive rows; the expand button still opens the
  fullscreen map.
- No map points: the header row sits on the plain card. A surface day is only
  the header row. Today keeps its primary badge and card edge; a planned day
  keeps its outline and Planned chip.

Out of scope: the Prepare overview before departure keeps `TripStoryHero` as
it is.

## Steps

1. `HeaderMapBackdrop`: wrap the gradient overlay in `IgnorePointer` so pins
   under a fade stay tappable. Test: a tap through the overlay reaches the
   child.
2. Extract `_ChecklistCard` and `_EmptyState` from `trip_story_hero.dart`
   into `story/trip_checklist_card.dart` and `story/trip_story_empty_state.dart`
   as public widgets; `TripStoryHero` composes them unchanged.
3. `TripStatStrip`: drop its own tinted container; it now lives inside the
   hero card. Update its band test to assert no tint.
4. New `story/trip_hero_card.dart`: `TripHeroCard(story, stats, siteCount)`.
   A `Card` with `Clip.antiAlias`; when `story.mapGeometry.hasPoints` a
   `_TripSitesMap` (locked `FlutterMap` fitted to all points, small primary
   dots) under `HeaderMapBackdrop`; else a `LinearGradient` of
   `AppColors.primaryDark`, `primary`, `primaryLight` with onPrimary text.
   Content column: icon and name, dates, countdown or day-of-trip line, then
   `TripStatStrip`. Tests: map present with points, gradient without, stats
   and countdown inside the card.
5. `TripStoryView`: replace the hero and strip slivers with the hero card
   (16px padding) followed by the checklist card (upcoming trips) and the
   empty state (empty stories). Update view tests that look for
   `TripStoryHero` and `TripStatStrip`.
6. `TripStoryDayHeader`: becomes a transparent row (no `Material` band, no
   `minHeight` band, no `compact` flag). Today keeps its primary badge and
   chip. Update header tests that assert band colours.
7. `TripStoryDayCard`: gains `storedWeather`; renders the header itself. With
   map points: a `Stack` of `HeaderMapBackdrop(TripDayMap)` under a column
   whose top inset is the map peek height, then the header row, then the
   untinted summary section (stats, rhythm bar, conditions), then the plan,
   dive rows, photos, sightings. Without map points the header row leads the
   card. A day with no body still renders a card holding only the header row.
   Update card tests (summary band key and tint, map rect) and add tests for
   the header in the card and the surface day card.
8. `TripStoryView._dayChapter`: drop the separate header; pass
   `storedWeather` to the card. Update view tests counting headers.
9. `dart format .`, `flutter analyze`, trip story tests,
   `test/architecture/`, `test/shared/`.
