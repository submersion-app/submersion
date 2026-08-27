# Trip Return-Flight No-Fly Countdown - Design

Date: 2026-08-05
Status: Approved pending user review
Branch: worktree-trip-flight-no-fly

## Problem

When a diver is on a trip with a booked return flight, the question that
matters on the last diving days is not "when can I fly?" but "how much longer
can I keep diving?" Flying too soon after diving risks decompression sickness
from reduced cabin pressure. The app already tracks backward-looking no-fly
status (Settings > Safety, `NoFlyService`); this feature adds the
forward-looking countdown: given the trip's return flight departure time,
show the remaining hours and minutes of dive window, i.e. the latest time the
diver must surface so that the required pre-flight surface interval fits
before departure.

## Decisions (from brainstorming)

- No-fly rule source: the existing "flying after diving" setting
  (`DiverSettings.noFlyPreset`, standard 12/18/24h or strict 18/24/48h).
  No tissue-model computation; `NoFlyService`'s fixed agency intervals are
  deliberate and remain the single source of truth.
- Flight data stored: departure date/time only. No flight number, airline,
  or airports.
- Deadline anchor: exactly at flight departure. No built-in or per-trip
  buffer.
- Display surfaces: trip story view, No-Fly page, dashboard gauge strip,
  and a warning in the dive logging flow.
- Architecture: Approach A - the safety feature owns all computation; the
  trips feature only stores the flight time.

## Data Model and Migration (schema v142)

New nullable column on `Trips` in `lib/core/database/database.dart`:

- `return_flight_at` INT (epoch ms), wall-clock in device-local time, the
  same convention as `startDate`/`endDate` and dive times. No timezone
  column. Rationale: during the trip the device clock is trip-local time,
  which is the frame the countdown needs. Caveat (documented, not
  engineered around): setting the flight time from home for a trip in a
  different timezone stores home-wall-clock; editing it on location
  corrects it.

Migration mechanics (mirrors v135/v139 column-add pattern):

- Idempotent `_assertTripReturnFlightColumn()` called from both the
  `if (from < 142)` onUpgrade block and the beforeOpen backstop.
- Version number: v142 per the schema ladder (v138 = divelogs #603,
  v139 = equipment currency #805). Re-grep `currentSchemaVersion = ` on
  current origin/main immediately before implementation; renumber upward if
  main has advanced.
- Migration test `migration_v142_trip_return_flight_test.dart` using
  `greaterThanOrEqualTo(142)` + `contains(142)`, plus a fresh-DB (onCreate)
  case and a stranded-at-currentSchemaVersion (backstop) case.

Entity and repository:

- `Trip.returnFlightAt` (`DateTime?`) with copyWith support that can also
  clear the value; the repository update path uses the established
  clear-field `.toCompanion(false)` pattern so null actually persists.
- Sync: `Trips` is already HLC-synced. Whole-row export picks up the new
  column automatically; schema-default hydration (post-#858) hydrates the
  column as null from older changesets. Updating the flight time bumps the
  trip HLC as any trip edit does. No further sync work.

Edit UI:

- Optional "Return flight departure" date + time picker on
  `trip_edit_page.dart`, with a clear affordance. Localized in en plus all
  10 non-English locales, l10n regenerated.

## Domain Logic (safety feature)

New pure method on `NoFlyService`
(`lib/features/safety/domain/services/no_fly_service.dart`), keeping `now`
as a parameter like the existing `NoFlyStatus.remaining(now)`:

```
FlightWindowStatus flightWindow({
  required DateTime flightAt,
  required NoFlyPreset preset,
  required NoFlyCategory prospectiveCategory,
  DateTime? currentNoFlyUntil,
  required DateTime now,
})
```

- Deadline (latest safe surfacing time) = `flightAt` minus the interval for
  (`preset`, category), reusing the exact interval table `evaluate()` uses.
- Prospective category: at least `repetitive` (a trip is multi-day diving
  by definition; `single` would show up to 6 phantom hours under the
  standard preset). Escalates to `deco` when any dive within the existing
  48h lookback had a deco obligation - the same signal `evaluate()` uses.
  This holds even before the first trip dive is logged (consistent and
  conservative).
- States on `FlightWindowStatus`:
  - `open`: now < deadline. Exposes `deadline` and `remaining(now)` - the
    time left in which diving may continue; the diver must surface by the
    deadline.
  - `closed`: deadline <= now < flightAt. No more diving before this
    flight.
  - `conflict`: the backward-looking `NoFlyStatus.until` (from
    `noFlyStatusProvider`) is after `flightAt`. The diver has already dived
    too recently for this flight. Alert treatment; takes precedence over
    open/closed.
  - `none`: flight is in the past, or no flight set (provider returns null
    before the service is even consulted).
- Category escalation mid-trip (first deco dive logged) legitimately jumps
  the deadline earlier and may flip open -> closed or conflict.

## Providers and Reactivity (safety feature)

- `tripFlightWindowProvider` -
  `FutureProvider.family<FlightWindowStatus?, String>` keyed by trip id.
  Reads the trip (`tripByIdProvider`), the `noFlyPreset` from
  `settingsProvider`, and `getNoFlyDiveInputs` over the same 48h lookback
  as `noFlyStatusProvider`. Returns null when the trip has no
  `returnFlightAt`. Self-invalidates on dive writes, mirroring
  `noFlyStatusProvider`. The provider derives `prospectiveCategory` by
  running `NoFlyService.evaluate()` over the lookback inputs (which yields
  the current category and `until`) and flooring the category at
  `repetitive`; the service method itself stays pure and takes the result
  as a parameter.
- `activeTripFlightWindowProvider` - resolves the trip containing today
  (`tripForDateProvider`) that has a flight time set, then delegates to the
  family. Consumed by the dashboard gauge and No-Fly page; the trip story
  passes its own trip id.
- Ticking: computation is pure against `now`; surfaces re-evaluate on a
  shared coarse minute-tick provider so displayed hh:mm stays current
  without re-reading dive inputs every tick.

Dependency direction note: the safety feature gains a read dependency on
the trip repository/providers (to fetch the active trip's flight time).
This matches the existing direction - the dashboard already reads safety
providers; trips never reads safety.

## UI Surfaces

1. Trip story (`TripStoryView`): a countdown card near the top while the
   trip is in progress and a flight is set.
   - open: "Time left to dive - 14h 32m (surface by Sat 09:15)"
   - closed: "No more diving before your flight."
   - conflict: alert-styled "Your no-fly time extends past your flight
     departure."
2. No-Fly page (`no_fly_page.dart`): a "Your flight" section when an
   active trip has a flight - departure time, latest safe surfacing time,
   and the comparison against the current no-fly clock (where conflict is
   most legible).
3. Dashboard gauge strip (`gauge_providers.dart` / `gauge_strip.dart`): a
   new flight-window gauge kind, shown only when an active trip has a
   flight and the state is open, closed, or conflict (i.e. inside the trip
   with the flight ahead). Additive; no behavior change without a
   trip/flight.
4. Dive logging (dive edit page): non-blocking warning banner when the
   dive's end time falls after the deadline. Warn, never block - the diver
   may be logging a past trip or knows better.

All new strings localized in en + 10 non-English locales with l10n regen.

## Edge Cases

- No dives logged on the trip yet: still assume `repetitive`.
- Trip endDate after the flight (fly out mid-trip): countdown anchors to
  the flight regardless of trip end.
- Overlapping trips: `tripForDateProvider` picks the containing trip;
  tie-breaking is its existing concern, not this feature's.
- Flight time cleared: all surfaces revert to current behavior.
- Flight in the past relative to now: `none`; nothing shown.

## Testing

- Unit tests for `flightWindow()` with fixed clocks: every state, both
  presets, category escalation, exact-boundary at the deadline, conflict
  precedence over open/closed.
- Migration test for v142: upgrade path, fresh DB, backstop.
- Widget tests for the trip story card states (open/closed/conflict).
- Provider tests for `tripFlightWindowProvider` null and populated paths.
- Known trap: adding a provider dependency to the dive edit page and
  No-Fly page breaks their existing consumer tests in ways
  `flutter analyze` does not catch; those test files get overrides updated
  in the same change.

## Out of Scope

- Flight number / airline / airport fields.
- Outbound-flight or multi-segment itineraries.
- Timezone modeling on trips.
- Tissue-model (Buhlmann) desaturation countdown.
- Notifications/alarms for the approaching deadline (possible follow-up).
