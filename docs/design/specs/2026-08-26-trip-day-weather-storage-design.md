# Stored trip day weather

## Problem

A trip story day that logs no dives shows a weather badge only if the app
fetches one from the network. `surfaceDayWeatherProvider` does that fetch on
every view: it is a `FutureProvider.family` that is deliberately not
auto-disposed, so it caches for the lifetime of the provider container, but
that cache dies with the process. Every cold open of a trip re-hits the
Open-Meteo archive for weather that cannot change, because it is historical.

Two further gaps follow from the same design:

- Only surface days fetch at all. `TripStoryDay.isSurface` is false whenever
  the day has an itinerary row, so travel days, port days, and sea days show no
  weather even though the trip records where the diver was.
- Nothing about the result is durable. It never reaches a backup, another
  device, or an export.

## Goal

Weather for a trip day is fetched at most once, stored as trip data, and read
from the database on every later view.

## Scope

In scope: every trip day whose dives supply no weather, which includes surface
days and dive-free itinerary days. Days in the future are excluded, because a
historical archive has nothing for them.

Out of scope: dive days. Dives already persist their own weather
(`cloudCover`, `precipitation`, `weatherCode`, `weatherSource`,
`weatherFetchedAt` on the dive row), and `TripStoryDay.weather` already
composes a day summary from them. That remains the higher-precedence source.

## Storage decision

The weather lives in a new synced table in the main database rather than in
`local_cache_database.dart` (where `BathymetryCache`, `ReefDataCache`, and
`NoaaTideStations` keep comparable third-party lookups), because it is trip
data: it belongs in backups, in sync, and in exports.

It gets its own table rather than columns on `trips` or on
`trip_itinerary_days`. Two reasons:

1. **Row-level conflict resolution.** HLC conflicts are resolved per row. A
   background weather write onto the `trips` row or an itinerary row would put
   a derived, automatic write in conflict with hand-entered data on the same
   row; a weather write racing a trip rename or an itinerary note edit from
   another device can lose that edit. Issue #1187 is the standing example of
   partial-entity writes wiping fields.
2. **Surface days have no itinerary row.** Materializing one to hold weather
   would make the day stop being a surface day, since
   `TripStoryDay.hasContent` counts any itinerary row as content, and would
   surface a weather-only row in the itinerary tab with a forced `dayType`.

`LiveaboardDetailRecords` is the existing template for a synced child record
of a trip and is the shape to copy.

## Data model

New table `TripDayWeather` in `lib/core/database/database.dart`:

| Column | Type | Notes |
| --- | --- | --- |
| `id` | text, pk | deterministic UUIDv5 over (`tripId`, day), via `tripDayWeatherRowId` |
| `tripId` | text | references `Trips(#id)` |
| `date` | int | epoch **milliseconds** at **UTC** midnight for the calendar day, via `tripDayMillis`. Milliseconds because that is what `ItineraryDayRepository` writes for `trip_itinerary_days.date`, despite that column comment saying "Unix timestamp". UTC rather than local midnight because the value is part of the row identity: a local midnight epoch differs in every timezone, so two devices would key the same trip day differently and never converge |
| `latitude` | real | the coordinate the lookup used |
| `longitude` | real | the coordinate the lookup used |
| `airTemp` | real, nullable | celsius |
| `cloudCover` | text, nullable | `CloudCover.name` |
| `precipitation` | text, nullable | `Precipitation.name` |
| `windSpeed` | real, nullable | m/s |
| `windDirection` | text, nullable | `CurrentDirection.name` |
| `humidity` | real, nullable | 0-100 |
| `surfacePressure` | real, nullable | bar |
| `weatherCode` | int, nullable | raw WMO code, so prose renders in the diver's locale at display time |
| `weatherSource` | text | defaults to `openMeteo` |
| `fetchedAt` | int | epoch milliseconds |
| `createdAt` | int | epoch milliseconds |
| `updatedAt` | int | epoch milliseconds |
| `hlc` | text, nullable | matches every other synced table |

Unique index on (`tripId`, `date`).

The id is **not** a v4 uuid. It is derived from the day it describes,
`UUIDv5(namespace, "$tripId|$dayMillis")`, following the same convention as
`importedDiveComputerId` and `qualityFindingId`. A per-device v4 would let two
devices store the same day under different primary keys; the serializer upserts
by primary key, so the peer's row would miss the `ON CONFLICT` target and hit
the unique index instead, throwing inside the merge transaction and aborting
the whole sync pull. The repository derives the id itself and ignores whatever
a caller passes.

The stored field set is the full `WeatherData` payload, not just the three
fields the day header renders. The API returns them in one response at no
extra cost, dive rows already store exactly this set, and a later migration to
widen the table is a six-place change on a collision-prone version ladder.
Storing them now costs nothing and renders nothing new.

Domain entity `TripDayWeather` in
`lib/features/trips/domain/entities/trip_day_weather.dart`, with `copyWith`
per the project convention, plus a mapping to the existing
`TripStoryDayWeather` view model that the day header already consumes.

## Schema version

**v171.** Renumbered from 168, which PR #1237 held. Derived by scanning open PR diffs for the scalar, not by grepping
main: main is at v164, and v165, v166, v167 are claimed by PRs #1300, #1290,
and #1276 respectively. Re-verify at implementation time, and re-grep the
scalar after any merge from main, because two branches writing the same number
auto-merge with no conflict marker.

The claim touches the six places the ladder requires: the
`currentSchemaVersion` scalar, the `migrationVersions` ladder entry, the
`_assertTripDayWeatherSchema()` helper docstring, the `if (from < 171)`
onUpgrade guard and its `reportProgress()` twin, the `beforeOpen` backstop
comment, and the `migration_v171_trip_day_weather_test.dart` filename with its
version assertions. The ladder is non-contiguous by design (v162 is
permanently skipped, and reserved rungs may be missing), so the migration
audit asserts monotonic, unique, and scalar equals max, never contiguous.

`minimumCompatibleSchemaVersion` does not move: a new table is additive, and
an older build simply ignores it.

## Fetch and write

A new `TripDayWeatherRepository` in
`lib/features/trips/data/repositories/trip_day_weather_repository.dart`:

- `watchWeatherChanges()` emits on every table change, so the display
  provider refreshes after a backfill write or a sync import.
- `getForTrip(String tripId)` reads a trip's rows, keyed by
  `date.millisecondsSinceEpoch`.
- `upsert(TripDayWeather)` writes one row, keyed on (trip, date) rather than
  on id so two devices that both fetch the same day converge on one row.
- `deleteByTripId(String tripId)` removes them, called from the trip-delete
  path alongside itinerary days.

The method names follow `ItineraryDayRepository`, which is the sibling to
copy.

A backfill service in
`lib/features/trips/domain/services/trip_day_weather_backfill.dart` decides
what to fetch. Given a built `TripStory` and the rows already stored, a day is
fetched only when all of these hold:

1. `day.weather == null`, so no dive on that day supplies weather.
2. `day.kind != TripStoryDayKind.future`.
3. No stored row exists for (`tripId`, `date`).
4. `story.mapGeometry.nearestPointForDay(index)` yields a coordinate.

Each qualifying day is fetched through the existing
`WeatherService.fetchWeather` at local noon with `useLocationTimezone: true`,
matching what `surfaceDayWeatherProvider` does today. Requests run
sequentially rather than all at once, since widening from surface days to all
dive-free days raises the first-view request count. Sequential also means rows
land progressively, so headers fill in as results arrive.

**A fetch that returns null, or returns a `WeatherData` with no usable field,
writes no row and is retried on the next view.** This mirrors the rule already
stated on `ReefDataCache` and `BathymetryCache`: transient failures write no
row. It is also what makes the design correct against the Open-Meteo archive's
few-day lag, since a day fetched too early simply has no row yet and is
retried later. The cost of that policy is that a location with genuinely no
archive data is re-requested once per trip view; that is the same behavior as
today and is bounded by how often a trip is opened.

Range batching is deliberately not implemented. The archive endpoint accepts a
`start_date`/`end_date` range, so days sharing a coordinate could collapse
into one request (a fixed-base resort trip would go from seven requests to
one), but every day is fetched exactly once ever and then never again. Noted
as a possible follow-up, not built here.

## Read path

`trip_story_view.dart` watches `tripDayWeatherProvider(tripId)` once for the
whole trip and passes each day's stored weather into `TripStoryDayHeader`,
replacing the per-day `SurfaceDayWeatherRequest` it builds today. Precedence
in the header is unchanged in spirit: `day.weather ?? storedWeather`, so
dive-logged weather always wins over a fetched summary.

The view also watches a backfill provider whose job is the side effect of
filling gaps. Because the display provider subscribes to the table's change
tick, a row written by the backfill re-renders the header without the widget
knowing a fetch occurred.

`lib/features/trips/presentation/providers/surface_day_weather_provider.dart`
and its test are deleted. This design replaces them.

## Sync

The serializer works on whole rows (`row.toJson()` on export,
`Entity.fromJson(data).toCompanion(false)` on import), so registering a new
table is mechanical but touches several sites:

- `sync_repository.dart`'s table map gains
  `'tripDayWeather': (table: 'trip_day_weather', pk: 'id')`.
- `sync_data_serializer.dart` gains the payload field, its `toJson`/`fromJson`
  entries, its export entry, and the roughly ten `switch` arms that every
  synced collection has.
- Tombstones and the trip-deletion FK path follow whatever `itineraryDays`
  does, so deleting a trip takes its weather rows with it on every device.

## Testing

Tests come first, per the project's TDD rule.

- **Repository:** upsert, read back, per-trip scoping, and that deleting a
  trip removes its weather rows.
- **Backfill:** one test per skip condition (dive-sourced weather present,
  future day, row already stored, no coordinate available), plus the two
  negative-result cases that must write no row (service returns null; service
  returns an all-null `WeatherData`).
- **Migration:** `migration_v171_trip_day_weather_test.dart`, including a
  stranded-database fixture at the previous `PRAGMA user_version`, plus the
  existing ladder audit in `test/core/database/`.
- **Sync:** a round trip proving a row exports and re-imports intact.
- **Header widget:** a stored row renders the badge; a day whose dives carry
  weather still prefers the dive-sourced summary.
- The deleted `surface_day_weather_provider_test.dart` is replaced by the
  backfill and header tests above.

## Risks

- **Version collision.** The ladder scalar auto-merges with no conflict marker
  when two branches write the same number. Re-grep after every merge from
  main and re-run `test/core/database/`.
- **Request volume on first view.** Widening from surface days to all
  dive-free days increases first-view requests for a trip. Bounded by
  sequential fetching, and one-time per day per trip.
- **Coordinate drift.** Stored rows record the coordinate used. If a site
  later moves, the stored weather is not re-fetched. Accepted: the row records
  what it was fetched for, and a day's weather is not materially sensitive to
  a site correction of a few kilometers.
