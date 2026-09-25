# Trip-scale gas logistics

Date: 2026-09-25
Status: approved design, implementation plans pending (one per PR)
Branch: ericgriffin/trip-scale-gas-logistics-865434
Issue: none filed yet. One umbrella issue is opened before PR 1; PRs 1 to 4
say `Part of #N`, PR 5 says `Closes #N` (see Delivery).

## Problem

A Bonaire week is a cylinder inventory problem, not a dive problem. The diver
rents a truck, collects cylinders from an operator's drive-through, dives two
to four times a day and swaps empties for fulls. Across the week the real
questions are not about any one dive: what is in the truck right now, what
mix is it, was it analyzed, is it enough for tomorrow, and when do we have to
be back at the fill station before it closes.

Submersion records every dive's cylinders (`dive_tanks`: volume, working
pressure, start and end pressure, mix, role, preset, transmitter serial) and
knows the diver's owned cylinders (equipment of type tank) and the operator
(dive centers, with rental gear memory from #2075). Nothing ties any of that
to a trip. The trip page forecasts one consumable already, scrubber time, and
nothing about gas.

## Decisions

Taken during brainstorming on 2026-09-25 and fixed for this spec.

- Scope: all three jobs, phased. A live cylinder board first, fill-run
  forecasting on top of it, then the per-trip gas record that falls out of
  the dive-to-cylinder link.
- Identity: one row type. A trip cylinder row can stand alone (a rental) or
  link to an owned equipment cylinder and inherit its specs.
- A row is a slot, one of the N cylinders the diver holds, not a physical
  bottle. Each fill carries the operator's number for the bottle in that
  slot right now. Owned bottles keep a fixed label on the row.
- State events: fills and adjustments in a ledger, plus linked dive tanks.
  Current state is a fold over the timeline. Nothing derived is stored.
- Dive link: a picker in the tank editor with a preselected suggestion,
  plus a shortcut from the board to log a dive on a chosen slot. Never
  automatic. The transmitter serial identifies the diver's regulator, not a
  rental bottle, so it is not used for linking.
- UI home: a compact card in the trip story beside the scrubber margin card,
  opening a full board page. No new tabs on standard trips.
- Forecast inputs: a dives-per-day target with a per-day override on
  itinerary days, a divers-sharing count, and optional fill hours on dive
  centers.
- Fill fields: analysis (ordered mix plus analyzed O2 and He) and cost
  (price, currency, package flag).
- Data model: approach A, identity rows plus an event ledger plus a nullable
  link column on `dive_tanks`. Mutable status columns (B) and label-only
  linking without a cylinder table (C) were rejected.

## Data model

Everything is stored metric (liters, bar) and displayed in the active
diver's units through the existing formatters. Cylinder sizes go through
`formatTankVolume` with the working pressure; gas quantities through
`formatVolume`; pressures through `formatPressure`; money through
`lib/core/utils/currency.dart`.

### Phase 1, schema rung 227

Main is at 226 and no open PR claimed a higher rung on 2026-09-25. The
ladder (open PR diffs and bodies, plus main) is re-checked right before PR
1's plan is written and again before push. The migration is an inline
`if (from < 227)` block in `database.dart` creating both tables and adding
the column, followed by `reportProgress()`, with the version added to
`migrationVersions`, an idempotent `_assertTripCylindersSchema()` backstop
called from `beforeOpen`, and a `migration_v227_trip_cylinders_test.dart`
after the v221 gear notes test.

`trip_cylinders`, one row per slot:

| Column | Type | Meaning |
| --- | --- | --- |
| id | text, primary key | uuid |
| trip_id | text, FK trips.id | the trip; children are deleted before the trip, house style |
| equipment_id | text, FK equipment.id, nullable, ON DELETE SET NULL | the owned cylinder in this slot |
| label | text, not null, default '' | slot name or the owned bottle's mark ("Truck 3", "My HP100") |
| volume | real, nullable | liters, copied from the equipment or preset at creation, editable |
| working_pressure | real, nullable | bar |
| material | text, nullable | `TankMaterial.name` |
| preset_name | text, nullable | the preset the slot was made from |
| sort_order | integer, not null, default 0 | board order |
| notes | text, not null, default '' | free text |
| created_at, updated_at | datetime | row timestamps |
| hlc | text, nullable | sync clock |

`trip_cylinder_events`, the ledger:

| Column | Type | Meaning |
| --- | --- | --- |
| id | text, primary key | uuid |
| trip_cylinder_id | text, FK trip_cylinders.id, ON DELETE CASCADE | the slot |
| kind | text, not null | `fill` or `adjustment` |
| occurred_at | datetime, not null | when; defaults to now in the sheet |
| bottle_label | text, nullable | operator's number for the bottle now in the slot (fills) |
| pressure | real, nullable | fill pressure, or the corrected current pressure |
| o2_percent, he_percent | real, nullable | the mix ordered |
| analyzed_o2, analyzed_he | real, nullable | what the analyzer read |
| dive_center_id | text, FK dive_centers.id, nullable, ON DELETE SET NULL | where filled |
| cost | real, nullable | price of this fill |
| currency | text, nullable | null means the diver's default currency, as service costs do |
| is_package | boolean, not null, default false | covered by a prepaid package |
| note | text, not null, default '' | free text |
| created_at, updated_at | datetime | row timestamps |
| hlc | text, nullable | sync clock |

`dive_tanks.trip_cylinder_id`, text, nullable, FK trip_cylinders.id,
ON DELETE SET NULL. This is the consumption link. Like `equipment_id` before
it, the column must be carried by `DiveTank`, `_tankCompanion`, both
row-to-entity mappers, the bulk-edit undo mapper (`_tanksFromRows`) and the
tank editor's preserve path, or replace and undo wipe it.

Domain entities, in `lib/features/trips/domain/entities/`:
`TripCylinder`, `TripCylinderEvent` with `enum TripCylinderEventKind { fill,
adjustment }`, each with `copyWith`. An unknown stored kind from a newer
peer maps to `adjustment` on read rather than throwing.

### Phase 2, its own rung

Claimed when PR 4's plan is written, re-checking the ladder then.

- `trips.divers_sharing_cylinders`, integer, not null, default 1.
- `trips.dives_per_day_target`, integer, nullable. Null means derive.
- `trip_itinerary_days.planned_dives`, integer, nullable. The per-day
  override. The itinerary stays the one per-day planning object.
- `dive_centers.fill_opens_at`, `dive_centers.fill_closes_at`, integer
  minutes since local midnight, nullable. One daily window; no weekday
  schedule.

Existing rows keep their defaults; no backfill of any kind.

### Phase 3

No schema. The record is a query.

### Sync registration

Both tables are updatedAt-clocked children registered exactly like
`tripDayWeather`, at every serializer site the pinning tests cover:
`SyncRepository.hlcTargets`, the `SyncData` field with `toJson` and
`fromJson`, `_baseTables`, the export in `_buildSyncData`, `fetchRecord`,
`fetchRecords`, `upsertRecord`, `upsertRecords`, `recordIdsFor`,
`_syncTableFor`, `deleteRecord`; then `SyncService.mergeOrder`,
`entityHasUpdatedAt`, `parentRefs`, and the FK labels in
`conflict_reference.dart`.

Parent refs: `tripCylinders` needs `(tripId, trips, not nullable)` and
`(equipmentId, equipment, nullable)`; `tripCylinderEvents` needs
`(tripCylinderId, tripCylinders, not nullable)` and `(diveCenterId,
diveCenters, nullable)`. Merge order puts cylinders after trips and
equipment, events after cylinders and dive centers, and both before dives,
so a dive tank's link never lands before its slot. The tank writer nulls a
link to a slot it cannot find, or whose trip differs from the dive's trip,
rather than failing the dive. Both tables join the replace-adopt wipe set
through `entityHasUpdatedAt`. The repository calls `markRecordPending` after
every insert or update, outside any `batch` closure, and `logDeletion` on
delete.

### Deletion

- Deleting a trip deletes events, then slots, then nulls `trip_cylinder_id`
  on the trip's dive tanks, in `TripRepository.deleteTrip` and in the diver
  delete steps.
- Deleting a slot cascades its events and nulls its tank links. The UI asks
  first, naming how many dives are linked. The tanks keep their copied specs
  and mix.
- Removing a dive from a trip, or moving it to another trip, nulls its
  tanks' links. The link means nothing outside the trip.
- Deleting equipment or a dive center nulls the reference. The slot keeps
  its copied specs; the fill keeps its data.

## Deriving a slot's state

`foldCylinderState` in `lib/features/trips/domain/services/` is pure.
Input: the slot, its events, and the tanks linked to it, each carrying its
dive's entry time, start and end pressure and mix. Output
`TripCylinderState`: current pressure (bar, nullable), current mix
(nullable), bottle label, status, last fill (nullable), last timeline item,
linked dive count.

Timeline: events and linked tanks merged and ordered by instant. A fill or
adjustment sits at `occurred_at`; a tank sits at its dive's entry time. On
an equal instant a fill sorts before a dive.

Rules, applied in order down the timeline:

- A fill sets pressure to its fill pressure, or the slot's working pressure
  when blank; mix to the analyzed values when present, else the ordered
  mix; bottle label when it carries one.
- An adjustment sets pressure. It changes the mix only if it carries one.
- A tank sets pressure to its end pressure. An unknown end pressure makes
  the pressure unknown but the slot used. A tank never changes the slot's
  mix.

Status, from the last item: `full` when it is a fill, or an adjustment at
or above 90 percent of the working pressure; `empty` when pressure is at or
below 50 bar (the planner's default reserve, a named constant, not a
setting); `partial` otherwise; `unknown` when there are no items, and the
board asks for a first fill.

Suggestion for the picker: candidates are `full` slots not linked by a
sibling tank on the same dive. When the tank's mix is not air, prefer slots
whose O2 matches within one percentage point. Among those, oldest fill
first. No full slot, no preselection.

Pre-fill on link: the tank takes the slot's volume, working pressure,
material and preset name; its mix becomes the slot's mix; its start
pressure is filled from the slot's current pressure only when the tank has
none. All editable afterwards; the link survives edits.

Reading: `tripCylinderStatesProvider(tripId)` runs two queries, the events
joined through slots, and a lean select over `dive_tanks` joined to `dives`
on `trip_id` taking tank id, dive id, entry time, pressures, mix and slot
id. No full dive hydration. It invalidates on dives table changes the way
`divesForTripProvider` does.

## Phase 1 UI

- `TripCylindersCard` sits with the scrubber margin card above the story
  body in both trip layouts (`trip_detail_page.dart`). Summary line ("3
  full, 1 partial, 2 empty") and a wrap of chips, one per slot: label, mix,
  pressure, status colour. Tap opens the board. Shown when the trip has
  slots, or when the trip is upcoming or underway and has none, offering
  "Set up cylinders". Past trips with no slots show nothing.
- `TripCylinderBoardPage` at `/trips/:tripId/cylinders`, route name
  `tripCylinders`, under the `tripDetail` route beside `gallery`. One card
  per slot in board order: label and bottle number, specs, mix and
  pressure, status, and the last timeline item in words. Per-slot actions:
  Fill, Adjust, Log dive, Edit, Delete. Page actions: Add cylinders, Fill
  selected, Reorder. A segmented switch selects Board, Ledger (every event
  on the trip, chronological, edit and delete) and, from phase 3, Record.
- Add cylinders sheet, two tabs. Rental: count, preset, label prefix,
  creating that many slots ("Truck 1" to "Truck 4"). From my equipment:
  active owned cylinders not already in a slot on this trip; specs copied,
  identifier used as the label.
- Fill sheet: when (now), where (dive center picker remembering the last
  center used on this trip), pressure, ordered mix with Air, EAN32 and
  EAN36 chips, analyzed O2 and He, bottle number, cost with currency and a
  package toggle, note. Multi-slot mode shows the shared fields once and a
  row per selected slot for bottle number and analyzed values; each slot
  still gets its own event row.
- Adjust sheet: pressure with a "Mark empty" shortcut, optional mix, time,
  note.
- Log dive shortcut: opens the new-dive route with `tripId` and
  `tripCylinderId` query parameters. `DiveEditPage` applies them on init:
  trip selected, first tank linked and pre-filled.
- Tank editor picker: `TankEditor` gains a nullable `tripId`, passed from
  `DiveEditPage._selectedTrip` through the tanks section and `tank_row.dart`.
  When the trip has slots, a "Trip cylinder" dropdown appears above the
  regulator picker with "None" and one row per slot (label, bottle number,
  mix, status). It follows the regulator picker's two habits: watch the
  provider with `.value` so a reload never flickers to None, and always keep
  the currently linked slot in the list. The suggestion fires only for tanks
  created in the current editing session, is preselected and marked
  "Suggested" until the dive is saved.
- Dive detail: the cylinders card shows the slot label and bottle number as
  a small line under a linked tank.
- Every string in every locale.

## Phase 2 forecasting

`computeFillForecast(FillForecastInputs)` in the trips domain is pure;
`tripFillForecastProvider(tripId)` gathers inputs; nothing is stored.

Inputs: today (device local day); remaining dive days (itinerary days typed
dive day from today onward, else calendar days to the trip end); planned
dives per day, first match wins: the itinerary day's `planned_dives`, the
trip's `dives_per_day_target`, `expectedDives` spread over dive days, the
diver's median dives per dive day from `TripHistoryRepository.divesPerDiveDay`,
else 2; `divers_sharing_cylinders`; slot states; fill hours from the dive
center of the trip's most recent fill, when set.

Rules: a day's demand is planned dives times divers sharing. Today's demand
is reduced by dives already logged on the trip today, floored at zero.
Supply is the count of `full` slots; partial slots are reported but never
counted. Shortfall is demand minus supply, floored at zero. A fill run is
needed when tomorrow's demand exceeds supply. The deadline is today's
closing time when the station has hours and closes later today, else
absent. Caution is set when today's remaining demand already exceeds
supply.

Outputs: full count, partial count, today's remaining demand, tomorrow's
demand, both shortfalls, fill-run flag, deadline, and the whole-trip
remaining demand.

Surfaces: one line on the story card, in the error colour on a shortfall
("Tomorrow needs 6, you have 3 full. Fill before 17:00.", deadline clause
dropped without hours), else "Enough full cylinders through tomorrow." The
board shows the same line as a banner plus a strip of remaining days with
planned counts; tapping a day writes the itinerary day's `planned_dives`,
creating the row if missing with the same double-insert guard
`trip_story_hero.dart` uses. The trip edit page's Planning section gains
"Divers sharing cylinders" and "Dives per day". The dive center edit page
gains fill hours with open and close time pickers. A trip that has ended,
or has no slots, shows no forecast.

## Phase 3 gas record

`buildTripGasRecord` in the trips domain is pure, fed by the same lean tank
rows and events. The Record segment of the board shows one row per linked
dive tank on the trip, in dive order: dive date and time, site, slot label,
bottle number, analyzed O2 and He, ordered mix, fill pressure, dive start
and end pressure, fill center. Bottle number and analysis come from the
fill in effect at the dive's entry time, found by the same timeline walk as
the fold, so a bottle swapped mid-week is attributed correctly on both
sides of the swap.

Totals: fills logged, dives per slot, gas breathed per slot in liters via
`gas_compressibility.dart` with the diver's gas model, and cost. Cost sums
non-package fills grouped by currency, null currency resolved to the
diver's default, and lists package fills as a count.

Gaps: a footer counts dive tanks on trip dives with no slot link and opens
the first such dive's editor.

Export: a CSV following the unit-aware convention (units in headers, values
converted), shared through `lib/core/services/export/shared/file_export_utils.dart`,
one file per trip named after the trip and the date.

## Edge cases

- Unknown event kind from a newer peer: read as an adjustment with its
  pressure, generic label, never throws.
- A fill requires pressure and mix, both defaulted (working pressure; the
  slot's last mix, else air). Analyzed O2 in 1 to 100, He in 0 to 99, sum
  at most 100, validated in the sheet.
- Two tanks on one dive pointing at the same slot: the picker prevents it;
  the fold tolerates it if a peer sends it.
- Times are instants; only "today" is local. Editing a dive's entry time or
  a fill's time re-sorts on the next read.
- Two devices filling the same slot produce two events; the fold takes the
  later. Two edits of one event resolve by clock.
- A trip deleted while the board is open shows the existing not-found state.

## Testing

Tests are written before the code they cover, and every vector is computed
by hand first.

- Unit: `foldCylinderState` (fill then dive; a dive timestamped before the
  last fill; the tie rule; mark empty; unknown end pressure; analyzed over
  ordered mix; bottle label carry; unknown kind); the suggestion rule (mix
  match, oldest fill first, sibling exclusion, no full slot);
  `computeFillForecast` (each step of the fallback chain, today's logged
  dives, deadline present and absent, ended trip, no slots);
  `buildTripGasRecord` (attribution across a swap, mixed currencies, package
  count, gap footer).
- Migration tests per rung. Sync pinning tests (`sync_hlc_target_registration_test`,
  `sync_parent_refs_completeness_test`, `sync_data_serializer_record_ids_test`,
  `sync_adopt_streaming_parity_test`, `cross_version_roundtrip_test`, the
  `entityHasUpdatedAt` coverage test) updated; an FK gating test for a tank
  link to a missing or foreign-trip slot.
- Repository: trip deletion, diver deletion, removing or moving a dive,
  and `trip_cylinder_id` round-tripping through create, update and
  bulk-edit undo.
- Widget: card summary and empty states; board actions; fill sheet
  validation and multi-slot rows; picker hidden without a trip or slots,
  keeps a linked slot in its list, suggests only for new tanks, pre-fills on
  select; imperial rendering of pressure, volume and cost; l10n coverage.
- `test/architecture/` runs after any new file under `lib/`.

## Delivery

Five PRs, each based on main after the previous one merges, each with its
own implementation plan written only then. `dart format .` and
`flutter analyze --fatal-infos` clean before every push.

1. Phase 1 data: rung 227, entities, repository, sync registration, the
   fold, deletion paths, `DiveTank.tripCylinderId` end to end. No UI.
2. Phase 1 board: the story card, the board page, add, fill and adjust
   sheets, the ledger, the route.
3. Phase 1 link: the tank editor picker with suggestion, the log-dive
   shortcut, the dive detail line.
4. Phase 2: its rung, `computeFillForecast`, the card line, the day strip,
   the trip and dive center edit fields.
5. Phase 3: the record view and CSV export.

Issue linking: one umbrella issue for the program. PR bodies 1 to 4 carry
`Part of #N`; PR 5 carries `Closes #N`. The "PR Issue Link" check blocks
merge otherwise.

## Out of scope

- Automatic linking by transmitter serial (it names the regulator).
- Weekday schedules for fill hours; a single daily window only.
- Trip-level data-quality findings (`quality_findings.dive_id` is NOT NULL).
- Linking dive plans to trips; the forecast uses counts, not plan engine
  gas demand.
- UDDF export of slots, events or the link.
- Per-diver ownership of slots on a shared trip; the trip owns its slots.
