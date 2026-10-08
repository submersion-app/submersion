# Trip Surface-Day Weather

**Date:** 2026-08-12
**Status:** Approved design, pending implementation plan

## Problem

Trip story headers already show a compact weather badge on dive days: a
conditions icon plus air temperature in the active diver's temperature unit.
The badge is derived from weather stored on that day's dive records. A true
surface day has no dives or itinerary content, so it has no weather source and
its otherwise-identical header renders without the badge.

Surface days should fetch real historical weather and display the same badge
without delaying the rest of the trip story or inventing weather by copying a
neighboring dive day.

## Design summary

Fetch surface-day weather lazily and best-effort when its trip story header is
mounted. Resolve the geographically nearest point already present in the trip
story map (itinerary port, dive site, or liveaboard endpoint), request
Open-Meteo's historical hourly weather for local noon on the surface-day date,
and feed the result through the existing weather badge presentation.

The result is cached by Riverpod for the current application provider
container. It is not persisted to the database or sync payloads. A missing
coordinate, loading request, or failed request leaves the header unchanged.

## Components

### 1. Nearest trip location

`TripStoryMapGeometry` gains a pure nearest-point lookup for a day index.

- Compare points by the absolute difference between `point.dayIndex` and the
  requested day index.
- Preserve map-point order when distances tie. Because the route is built in
  trip order, this deterministically prefers the earlier point in an
  equidistant tie.
- A surface day before the first mapped day uses the first future point; one
  after the last mapped day uses the last prior point.
- Empty geometry returns no point and therefore causes no network request.

The story view resolves this point only for a surface day and passes its
coordinates to the day header. Dive-day headers keep deriving weather solely
from their logged dives and never start this fetch.

### 2. Surface weather request and provider

Add an immutable request value containing the surface date, latitude, and
longitude. A non-auto-dispose Riverpod family provider uses this value as its
cache key so the same surface day and coordinate are fetched once per app
provider container, including when its sliver scrolls offscreen and remounts.

The provider:

1. Builds a target timestamp at 12:00 on the surface date.
2. Calls the existing `WeatherService` for the selected coordinate and date.
3. Requests `timezone=auto` so Open-Meteo returns hourly timestamps in the
   coordinate's local timezone and the mapper selects local noon rather than
   noon GMT.
4. Converts the returned `WeatherData` to the existing compact
   `TripStoryDayWeather` fields: air temperature, cloud cover, and
   precipitation.
5. Returns null for unavailable or failed weather, matching the existing
   service's best-effort contract.

`WeatherService.fetchWeather` gains an optional location-timezone flag. It is
off by default so existing dive-edit weather requests retain their current API
contract; the surface-day provider enables it explicitly.

### 3. Header presentation

`TripStoryDayHeader` accepts an optional surface-weather request.

- Logged dive weather remains the first and only source for non-surface days.
- For a surface day with no logged weather, the header watches the surface
  weather provider when a request is available.
- While loading or on error, it renders no placeholder, spinner, error text,
  or layout reservation.
- Once data arrives, it sends the fetched summary through the same badge
  builder used by dive days. Icon precedence, semantic labels, typography,
  colors, and unit conversion therefore stay identical.

No new localization strings or visual components are required.

## Data flow

```text
TripStory map geometry
        |
        v
nearest map point for surface-day index
        |
        v
SurfaceDayWeatherRequest(date, latitude, longitude)
        |
        v
surfaceDayWeatherProvider --cached--> WeatherService
        |                                  |
        |                         Open-Meteo archive API
        v
TripStoryDayWeather? --> existing header weather badge
```

The trip story and header render before the network request completes. Weather
failure cannot fail or hold the trip story provider.

## Error handling and edge cases

- **No map points:** do not request weather and show no badge.
- **HTTP, network, malformed-data, or unavailable-date failure:** the existing
  service returns null; show no badge and keep the trip usable.
- **Surface day between different locations:** use the nearest day by calendar
  distance; ties follow route order deterministically.
- **Surface day at either trip boundary:** use the closest mapped point on the
  available side.
- **Multiple points on the chosen day:** use the first point in established map
  route order.
- **Header remount while scrolling:** the family provider's request key reuses
  the in-memory result instead of repeating the HTTP request.
- **Dive day with missing logged weather:** do not fetch. This feature is
  explicitly limited to true surface days so it does not silently replace the
  dive-log weather workflow.
- **Today or a date unavailable from the archive endpoint:** degrade to no
  badge. Forecast routing and retry UI are outside this feature.

## Testing

- Extend `trip_story_day_test.dart` with nearest-point selection for exact-day,
  prior/future boundary, equidistant tie, and empty-geometry cases.
- Extend `weather_service_test.dart` to prove the opt-in request includes
  `timezone=auto` while the default request contract remains unchanged.
- Add provider tests proving local-noon request construction, conversion to
  `TripStoryDayWeather`, one cached request per key, and null propagation.
- Extend `trip_story_day_header_test.dart` to prove fetched surface weather uses
  the existing icon and Celsius/Fahrenheit formatting, and that loading,
  failure, and missing-location states remain badge-free.
- Extend `trip_story_view_test.dart` to prove a surface header receives the
  nearest story coordinate and a dive day does not opt into surface fetching.
- Run the focused trip-story/weather suite, `flutter analyze`, and the full
  Flutter test suite before completion.

## Non-goals

- No database migration, trip-day weather entity, sync changes, or offline
  persistence.
- No copying or interpolating weather values from adjacent dives.
- No forecast API, recent-weather endpoint switching, retry button, loading
  indicator, or error message.
- No change to dive-day weather sourcing, editing, or persistence.
- No additional weather details beyond the existing compact icon and air
  temperature badge.
