# Trip dates follow their dives

Issue: #3351. Release: v1.8.4.

## Why

A diver logging past dives groups them into a trip and the trip shows the wrong
dates: a new trip opens at today, and an existing trip stays where it was when an
older or later dive joins it. The diver then corrects dates the app already knows.

The rule this design delivers: **a trip covers its dives once you have touched
them.**

## Where things stand

- New Trip from a dive selection already prefills the dates (#3786, through
  `buildTripDraft` in `lib/features/trips/domain/services/trip_draft.dart`).
- Create new trip in the dive editor and in bulk edit pushes a blank `/trips/new`
  (`_showTripPicker` in `dive_edit_page.dart`), which defaults to today plus seven
  days. This is the reported behaviour.
- Nothing stretches an existing trip. The dive editor, bulk edit and logbook rules
  can all put a dive outside its trip's dates.
- The date-range scan only finds dives inside the range, so it never stretches
  anything, apart from the zone edge noted under Decisions.

## Goals

1. Create new trip in the dive editor and bulk edit opens the form prefilled from
   the dive or dives being edited.
2. A trip stretches outward when a dive lands on it outside its dates, or when a
   dive already on it gets a new date outside them.
3. The diver is told when this happens, and bulk edit's Undo puts the dates back.

## Non-goals

- Shrinking. Removing a dive never narrows a trip: the dates may be wider than the
  dives on purpose, for travel and surface days.
- Existing data. No migration or sweep; a trip already out of range stays so until
  the next dive lands outside it.
- Imports and downloads. A UDDF file brings its own trip with its own dates, and
  overriding them would alter what the diver imported.
- Data-quality time repairs (`bulkShiftDiveTimes`), the wall-clock migration
  (`dive_time_migration_service`, `dive_time_wall_clock_shift`) and the HealthKit
  shift. These correct clocks across many dives and are not an edit of one dive's
  date.
- Dive merge, uncombine and mirroring.
- The itinerary. Stretching does not add or remove itinerary rows, the same as
  editing a trip's dates in the form today (`regenerateForTrip` has no callers).
- Trip type. A day trip that stretches stays a day trip; the form already unlocks
  its end date when the range is longer than one day.

## Anti-goals

- A stretch must never move a date inward.
- A stretch must never overwrite a manual date edit, on undo or otherwise.
- A save with no trip or date change must not stretch, so a dive already outside
  its trip does not reopen a decision the diver made.

## Decisions (the maintainer's)

- Stretch automatically, with a short message showing the new dates. No prompt.
- A dive already on a trip that gets a new date stretches the trip too.
- Undo after a bulk edit restores the trip's old dates.

## Design

### The stretch

New pure function in `lib/features/trips/domain/services/trip_date_stretch.dart`.
Given a trip's start and end and the dives' `DateTime`s, it returns the covering
range, or null when the trip already covers them.

Days are compared, not instants, as in `tripForDiveDate`. A dive's day comes from
its wall clock in UTC components (`diveDateTime.toUtc()`); a trip's dates are local
midnight of a calendar day (`tripDay`). A new bound is written as local midnight of
the dive's wall-clock day, the same form `buildTripDraft` writes.

New data helper `stretchTripsToCoverDives(db, sync, diveIds, now:)` in
`lib/features/trips/data/repositories/trip_date_stretch.dart`, shaped like
`clearForeignTripCylinderLinks`: it takes the database and sync repository, opens no
transaction of its own, and notifies nobody. It:

1. reads the trip id and date of each dive, in chunks, grouped by trip;
2. stretches each trip that needs it;
3. when a stretched trip has a valid larger trip (the rule in `effectiveParentId`),
   stretches that one to cover the same dives;
4. writes `start_date`, `end_date` and `updated_at`, and marks the trip pending with
   entity type `trips`;
5. returns a `TripDateStretch` per changed trip: id, name, the bounds before and
   after, and whether it was the larger trip of a side trip.

Step 3 runs only for a trip that stretched in step 2. Nothing keeps a side trip
inside its larger trip's dates, and a diver may place one past the end on purpose,
so a dive landing inside a side trip's existing dates changes neither trip. This
leaves one gap, accepted: a new side trip built around a dive outside its larger
trip does not stretch the larger trip. (Builder's call, on the smaller write.)

A dive with no trip contributes nothing. Planned dives and dives excluded from
stats count, since they are still the trip's dives. Trips shared by another profile
stretch too: any profile that may place a dive on a trip may already edit its dates.

### Who calls it

| Path | Where | Message |
| --- | --- | --- |
| Bulk edit | `BulkDiveEditService._applyInner`, in its transaction, when `req.scalars.tripId` is present and not null | Yes |
| Logbook rules | `DiveRuleApplier`, after the `bulkUpdateFields` chunks, when the companion sets a trip | No, a rule runs unattended |
| Dive editor | `_saveDive` in `dive_edit_page.dart`, after the dive saves, only for a new dive or when the trip or the date changed | Yes |
| `assignDivesToTrip`, `assignDiveToTrip` | `TripRepository`, in their transactions | No |
| `bulkUpdateTrip` | `_bulkUpdateTripInner`, for the same reason | No |

It does not go in `createDive`, `updateDive` or `bulkUpdateFields`: imports and
quality repairs use those, and they are non-goals.

The dive editor's call is not in the save's transaction. As with route links, a
failure is logged and reported but never undoes the saved dive.

`assignDivesToTrip` covers New Trip from a selection, where a diver who narrows the
prefilled dates in the form gets them widened again on save. The dives are what the
trip was made for, so the rule holds there too, and the form's saved message stands.

### Prefilled Create new trip

`newTripFromSelection` splits so the draft can be built without assigning dives.
A new helper builds the `TripDraft` from `SelectionDiveFacts`; the existing action
keeps its behaviour.

- **Bulk edit:** facts from `loadSelectionTripFacts(bulkDiveIds)`.
- **Dive editor:** facts built from the form, not the database: the entered date,
  selected site's region and country, selected dive center's name, and the selected
  trip. This also serves a new dive that has no row yet.

Both push `/trips/new` with the draft's `diveIds` emptied. The new trip is chosen in
the form and the dives join it when the edit saves, so backing out moves nothing.
Bulk edit's save then needs no stretch unless the diver narrowed the dates.

An existing consequence, kept: a draft skips the date-range scan, and a dive already
on a trip offers that trip as Part of, both as New Trip from a selection does.

### Telling the diver

One new string, for example `{trip} now runs {dates}`, with `dates` from
`UnitFormatter.formatDateRange`, so it follows the diver's date format.

- **Bulk edit:** a second line on the existing applied message, which keeps its
  Undo. The message names the dive's own trip, not a stretched larger trip.
- **Dive editor:** a SnackBar through a captured `ScaffoldMessenger`, shown before
  navigating away so it survives the pop.

### Undo

`BulkEditSnapshot` gains `tripDateStretches`. `BulkDiveEditService.undo` restores
each bound only if the stored value still equals what the stretch wrote, so a manual
edit or a later stretch at that bound survives. A restored trip gets a fresh
`updated_at` and is marked pending, so the undo wins last-write-wins.

Rule undo leaves the stretch in place: it tracks dive and site changes only, and the
Change Log records the trip row, so that revert already exists.

### Refreshing the UI

After a stretch the trip list, `tripByIdProvider`, `tripWithStatsProvider` and
`allTripsProvider` hold old dates. A small helper invalidates them for the stretched
trip ids, called from the bulk save, its undo and the dive editor.

## Edge cases

- **Two zones.** `findCandidateDivesForTrip` compares a wall-clock instant against
  local-midnight instants, so a scan can offer a dive just past the last day. It
  then stretches by a day, which is correct: the dive's own day is outside the trip.
- **Daylight saving.** Bounds are built from calendar parts, never by adding hours.
- **A dive before 1950 or after 2100.** The pickers limit the form, not this path;
  a stretch writes the date as is.
- **Sync.** A trip stretched on two devices resolves by last write, like any trip
  edit. The losing device's dives remain, and its next touch stretches again.

## Testing

- Pure function: inside, before, after, both ends, the wall-clock day near midnight
  in a non-UTC zone, and a daylight-saving boundary. CI runs under
  `TZ=Australia/Sydney`, so wall-clock-as-UTC mistakes show up there.
- Data helper against a real database: no trip, no change writes nothing and stages
  nothing, a side trip stretches its larger trip, a broken parent link is ignored.
- Each caller: bulk edit, a rule, assign, and the editor's new, trip-changed,
  date-changed and unchanged saves.
- Undo: restores, leaves a manually edited bound, and leaves a later stretch.
- Widget tests for the prefilled form from both entry points and for both messages.

## Left to the builder

File layout within the trips feature, the string's key and exact wording, and the
order of the steps.
