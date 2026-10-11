# Trip today highlight and richer day cards

Date: 2026-10-10
Release: v1.8.2

## Problem

During an active trip the diver opens the trip to see where they are and what
the day holds. Today, on the Overview story, today's chapter differs from its
neighbours only by a thin "Today" divider, and every day header uses the same
grey `surfaceContainer` band. The day cards on both tabs also leave out
information the diver wants at a glance:

- Overview story cards show itinerary notes and plan context only on future
  days, so today (before any dive is logged) is a bare header.
- Itinerary cards show no weather, no day totals, no conditions, no photos or
  species, and only time and depth on each dive row.
- Neither tab opens at today; on a long trip the diver scrolls to find it.

## Goals

1. Today stands out on the Overview and on the Itinerary tab while the trip is
   in progress.
2. Both tabs open scrolled to today while the trip is in progress.
3. Overview day cards show the day's plan (notes, planned versus logged dives)
   on every day, and a conditions line.
4. Itinerary day cards show weather, day totals, conditions, richer dive rows,
   and photo and species counts.

Non-goals: no schema change, no change to the Prepare overview shown before a
trip starts, no change to the itinerary edit sheet.

## Design

### Shared data (approach A)

The Itinerary tab keeps its numbered rows (`numberedItineraryDaysProvider`) and
its edit sheet, and looks up each row's `TripStoryDay` in `tripStoryProvider`
by calendar date (`tripDay`) for its media and sightings, as a best-effort
enrichment: while the story loads, or if it fails, the cards go without their
media line. The tab keeps grouping `divesForTripProvider` for the dives, so it
never waits on the story's checklist and media reads, and takes today from
`clock.now()` through the same `tripDayKind` rule the story builder uses.

New shared pieces:

- `DayConditions` (domain, `lib/features/trips/domain/services/`): a pure
  aggregation over a day's dives.
  - Water temperature: min and max of `waterTemp` across dives; null when none.
  - Visibility: min and max of measured `visibilityMeters`. When no dive has a
    measurement, the legacy `Visibility` bucket is used only when every dive
    that has one agrees (excluding `unknown`); otherwise none.
  - Current: min and max `CurrentStrength` by enum order; null when none.
  - `isEmpty` when all three are absent.
- `DayPlanProgress` (domain): from a story day, the planned count
  (`itineraryDay.plannedDives`, only when non-null and above 0) and the logged
  count (`dives.length`). Planned rest days (0) and derived plans (null) yield
  nothing.
- `resolveDayWeather(day, stored)`: the header's existing rule moved into a
  helper: logged weather wins when it can draw something, otherwise the
  stored day weather, otherwise the logged weather.
- Widgets in `lib/features/trips/presentation/widgets/day/`:
  `DayWeatherBadge` (icon plus air temperature, moved out of
  `TripStoryDayHeader`), `DayConditionsLine`, `DayPlanLine`, `TodayChip`.

### 1. Today on the Overview story

- `TripStoryDayHeader` for a day of kind `today`: band colour
  `primaryContainer`, date and subtitle in `onPrimaryContainer` (subtitle at
  reduced emphasis), a `TodayChip` (existing `trips_story_today` string) in the
  trailing slot, and the day-number badge in `primary` / `onPrimary` so it stays
  distinct on the tinted band. The compact form keeps a transparent
  background and only adds the chip.
- `TripStoryDayCard` for today: a 2px `primary` outline.
- `_TodayDivider` is removed; the header carries the signal.
- Colours come only from `ColorScheme` roles so every app theme and dark mode
  work.

### 2. Overview card content

- Plan section, on every day kind:
  - Itinerary notes (currently only future days show them).
  - `DayPlanLine`: past and today read "X of N planned dives"; future reads the
    existing "N dives planned". Shown only when `DayPlanProgress` has a plan.
  - The port history pills stay future-only.
- The card's empty-body guard also counts non-blank notes and a plan, so today
  with no dives yet shows its plan instead of only a header.
- `DayConditionsLine` sits in the summary band under the stat strip, for days
  with dives and non-empty conditions. Parts: water temperature
  ("26-28 C" or one value), visibility ("12-20 m" or the legacy bucket name),
  current ("Light to Moderate" or one value). All values use the diver's unit
  settings (`UnitFormatter`).

### 3. Itinerary cards

- Today: card colour `primaryContainer` at reduced alpha, blended onto the
  card's opaque surface (never a translucent fill), with a `primary`
  outline, and a `TodayChip` beside "Day N".
- Date line: the date, then `DayWeatherBadge` when there is weather (logged or
  stored from `tripDayWeatherProvider`).
- Totals: the "2 dives" label becomes "2 dives, 1h 42m, 24 m max" (dive count,
  total runtime, max depth), followed by `DayConditionsLine`.
- Dive rows: number, site, time, runtime, max depth, water temperature (each
  value only when present).
- Media line: "12 photos, 5 species" when either is non-zero (species counted
  as distinct species ids).
- Plan line: the same `DayPlanLine` rule as the Overview, replacing today's
  "planned dives on future days only" line.

### 4. Open at today

While the trip is in progress (`trip.isInProgress`):

- Overview: `TripStoryView` builds a `CustomScrollView` with `center` set to
  today's chapter. The slivers before it (hero, stat strip, cylinders,
  flight countdown, vessel, earlier days) are listed in reverse order so they
  grow upward; earlier days use a reversed-index `SliverList`. Offset 0 is the
  top of today's chapter.
- Itinerary: the same structure, anchored at the first row dated today or
  later; the Generate button and earlier rows sit above.
- Past and future trips, and an in-progress trip with no anchor day, keep the
  current single forward list.

The `center` approach is exact with lazily built, variable-height lists: no
measuring, no post-frame jump, and no flash of the top of the list.

## Localization

New ARB keys in every locale (translated):

- plan progress, plural on planned count: "{logged} of {planned} planned dives"
- conditions: water temperature, visibility and current labels, and a range
  joiner for current ("{from} to {to}")
- day totals joiner and the media line: photo count and species count plurals

Existing keys reused: `trips_story_today`, `trips_itinerary_diveCount`,
`trips_itinerary_plannedDives`, enum display names for current and visibility.

## Testing

- Unit: `DayConditions` (ranges, single values, measured versus legacy
  visibility, disagreeing legacy buckets, no data), `DayPlanProgress` (null,
  0, positive; past, today, future), `resolveDayWeather` (moved tests).
- Widget: header today styling and chip; card outline and plan section on a
  dive-free today; past day plan progress; conditions line in diver units;
  itinerary card weather, totals, rows, media line and today styling; both
  tabs show today's chapter on the first frame of a long in-progress trip and
  still reveal earlier days on scrolling up; past trips open at the top.
