# DPV mission planner

Date: 2026-09-18
Issue: #2086

## Problem

Divers who use a DPV (diver propulsion vehicle, a scooter) plan a dive as an
energy and failure-management problem, not only as a depth and time problem.
The questions they ask before a scooter dive are:

- How far in can the team go on battery, keeping a reserve for the exit?
- How does the current help on the way out and hurt on the way back?
- If one scooter dies at the deepest point of penetration, can that diver
  swim out, or be towed out, on the gas they have left? How long does it take,
  and what does the extra bottom time do to the decompression?
- Which diver and which scooter is the mission constraint? A team moves at the
  slowest scooter and turns on the highest gas consumer, and those are often
  different people.
- Where is the abandonment point, the last point at which a single scooter
  failure is still recoverable?

The planner today answers none of this. `DivePlan` (lib/features/planner)
models one diver, depth and time segments, tanks, deco and a turn-pressure
rule. It has no distance, no speed, no current, no team and no scooter.
Equipment already knows a DPV's rated speed, burn time, battery capacity and
style (equipment attribute catalog), but nothing consumes those numbers.

## Goals

- Attach a DPV mission to a saved dive plan: a waypoint route, a team, and
  scooters.
- Generate the plan's bottom segments from the route so the deco schedule,
  gas, slate and compare view all describe the same dive.
- Evaluate a scooter failure for every member at every waypoint under both
  exit modes (swim out, be towed out) using the existing `PlanEngine` for
  deco and time to surface.
- Report battery use with a reserve, per-member gas at every waypoint, the
  abandonment point, each member's turn pressure, and one sentence naming the
  member, scooter and factor that constrain the mission.
- Respect the active diver's unit settings everywhere a number is shown.
- Sync the mission with the plan across devices and round-trip it through
  the plan file format.

## Non-goals

- Per-member tank configurations. Version 1 assumes every member carries the
  plan's tanks, and the report states that assumption. Per-member tanks are a
  later phase.
- Layering a gas emergency (gas sharing) on top of a scooter failure. Version
  1 models the scooter failure alone, with the plan's stressed SAC applied to
  the failed member.
- A battery model built on watt-hours and a power curve. Version 1 uses rated
  burn time. The Wh attribute is shown on the scooter card but not used.
- Writing the mission turn pressure back into the plan's turn rule. The
  report is read-only in version 1.
- Printing the mission on the PDF slate, waypoint markers on the profile
  chart, and a DPV badge on saved plan list rows. All are natural follow-ups.
- Current as anything other than a steady vector per leg. Tides and time
  varying current are out of scope.

## Design

### Approach

A pure `MissionEngine` sits beside `PlanEngine` and never modifies it. The
mission engine turns the route into plan segments, computes battery burn, and
builds one scenario `DivePlan` per failure case, which it hands to
`PlanEngine.compute` for deco and time to surface. Per-member gas is derived
from the scenario's schedule rows times that member's SAC, so the engine runs
once per scenario rather than once per member. This keeps deco in one place,
keeps the mission logic unit testable like the gas calculators, and confines
the meeting point of the two engines to one small segment builder.

Two alternatives were rejected. Teaching `PlanEngine` about teams and
scooters would push a DPV-only concept into deco code and grow a file that is
already past the repository's size ceiling. A self-contained mission engine
with its own average-depth gas model would disagree with the plan's own
schedule, which is the number a diver trusts least.

### Domain model

New entities live under `lib/features/planner/domain/entities/mission/`, one
file each, immutable, `Equatable`, with `copyWith`, following `DivePlan`.

**DpvMission**, attached as `DivePlan.mission` (nullable) and mirrored on
`DivePlanState.mission`:

| Field | Type | Notes |
| --- | --- | --- |
| legs | List of MissionLeg | ordered outbound legs; the return is derived |
| team | List of MissionMember | ordered, at least one member for a valid mission |
| batteryReserveFraction | double | default 1/3, fraction of burn time that must remain at the surface |
| defaultCurrent | CurrentVector, nullable | inherited by legs whose own current is null |

**MissionLeg**: a leg ends at the waypoint it names.

| Field | Type | Notes |
| --- | --- | --- |
| id | String | |
| order | int | |
| label | String | waypoint name, for example "T" or "Jump 2" |
| distanceM | double | metres, > 0 |
| depthM | double | metres, the depth held along the leg |
| headingDeg | double | true heading of travel, 0 to 360 |
| current | CurrentVector, nullable | null inherits the mission default |

**CurrentVector**: `speedMps` (>= 0) and `setsTowardDeg` (0 to 360). The
oceanographic convention: the direction the water flows toward, not from.
Every label in the UI says "sets toward".

**MissionMember**:

| Field | Type | Notes |
| --- | --- | --- |
| id | String | |
| order | int | |
| displayName | String | |
| buddyId | String, nullable | name and photo only, no SAC lives on a buddy |
| diverId | String, nullable | as above, for a diver profile |
| sacBottom | double | L/min at the surface |
| swimSpeedMps | double | default 0.2 (12 m/min) |
| scooter | ScooterSpec | |

**ScooterSpec**:

| Field | Type | Notes |
| --- | --- | --- |
| equipmentId | String, nullable | null for a manual scooter |
| name | String | |
| ratedSpeedMps | double | |
| burnTimeSeconds | int | rated run time at rated speed |
| towSpeedFactor | double | default 0.6, tower's speed while towing as a fraction of rated |
| towBurnFactor | double | default 1.5, burn rate multiplier while towing |

Values are snapshotted into the spec when a scooter is picked. When a plan is
opened and the equipment item still exists, its live attributes overlay the
snapshot (`speed_mps`, `burn_time_h`, `tow_speed_factor`, `tow_burn_factor`),
so correcting a burn time on the equipment page corrects every plan that uses
that scooter. A deleted item or a manual scooter falls back to the snapshot.
The overlay is a presentation-layer resolver (`MissionScooterResolver`) fed by
the equipment providers; the entity never reads the database.

**Equipment attribute catalog**: two new curated DPV attributes,
`tow_speed_factor` and `tow_burn_factor`, both numbers with dimension `none`.
An absent row means the default. No schema change, since attributes are rows
in `equipment_attributes`. `EquipmentItem` gains typed getters for the four
DPV numbers it currently exposes only through `attrNum`.

### Calculation

The mission engine lives in `lib/features/planner/domain/services/mission/`
as four small services plus an orchestrator.

**Current resolution.** For a leg with heading h and current (c, d), the
along-route component is `c * cos(d - h)`. Outbound effective speed is
`cruise + component`; return effective speed is `cruise - component`, which
is the same formula applied to the reversed heading. A leg whose effective
speed in either direction is at or below zero is untraversable and raises a
blocking issue naming the leg and direction.

**Cruise speed.** The team moves at the slowest member's rated speed. The
member whose scooter sets it is flagged in the report.

**MissionSegmentBuilder.** Each outbound leg becomes a `PlanSegment.hold` at
the leg depth lasting `distance / outboundEffectiveSpeed`, breathing the tank
the canvas assigns to a new segment (the back gas). Return legs are appended
in reverse order with their return speeds. The existing `SegmentChain` derives
descent and travel between depths as it does today. The generated list
replaces `plan.segments` on every mission edit and once on load when a mission
is present. Because the stored segments are a cache of the mission, every
downstream consumer (engine, slate, compare, convert to dive, file export)
keeps working unchanged.

**BatteryBurnService.** Burn rate is `1 / burnTimeSeconds` per second under
power at the rated rate. A member cruising slower than their rated speed still
burns at the rated rate; this is deliberately conservative and the report says
so. A towing member burns at `rate * towBurnFactor`. A dead scooter burns
nothing. A member's no-failure round trip must end with at least
`batteryReserveFraction` remaining.

**MissionScenarioService.** For every waypoint k (the end of outbound leg k)
and every member m, m's scooter dies on arrival at k. Two exits are evaluated:

- Swim exit: the whole team swims the return legs from k at the slowest swim
  speed in the team, with return current applied. No scooter burns.
- Tow exit: each teammate t is tried as the tower. Team speed is
  `t.ratedSpeed * t.towSpeedFactor`, capped by the other members' rated
  speeds. The tower burns at the tow rate, the other members at the rated
  rate, m burns nothing. The best feasible tower is reported, or none.

Each exit is a scenario `DivePlan`: the plan copied with segments = outbound
legs through k plus the exit legs. `PlanEngine.compute` runs once per
scenario and yields the schedule rows (depth, duration, phase) and time to
surface. Per-member gas over any span of rows is
`sum(duration * ambientPressure(depth) * sac(phase))` where the bottom SAC is
the member's own, the deco SAC is the plan's, and the failed member breathes
the plan's stressed SAC on the bottom portion of the exit. `ambientPressure`
is the existing helper in the gas calculators domain, honouring the plan's
water type and altitude through the engine config.

Gas remaining for member m at waypoint k is the plan's usable gas minus m's
outbound consumption through k. An exit is feasible for the team when, for
every member, remaining minus exit need stays at or above the plan's reserve
pressure, and for every scooter still running, burn stays within the reserve
fraction.

Scenario count is `waypoints * members * members` at most (one swim plus up
to `members - 1` tow scenarios per failure). A three-member, six-waypoint
mission is 54 engine runs.

**MissionOutcome.** The result type the UI reads:

- `legs`: per leg, outbound and return effective speed and duration.
- `waypoints`: per waypoint, cumulative distance, arrival run time, and per
  member: gas remaining, the swim exit result, the tow exit result (tower,
  exit minutes, time to surface, gas needed per member, feasible), and
  whether a failure of that member's scooter there is survivable.
- `abandonmentIndex`: the last waypoint at which every member's failure has
  at least one feasible exit. Equal to the last leg when the whole route is
  survivable. Null when even the first waypoint is not.
- `members`: per member, battery used on the no-failure round trip, whether
  their scooter sets the cruise speed, the first factor to bind (battery,
  own gas, no feasible tow, swim gas) with the waypoint where it binds, and
  the mission turn pressure: gas that must remain at the abandonment point to
  cover that member's worst feasible exit plus the plan's reserve.
- `constraint`: the member and factor that bind earliest. This is the
  sentence the feature exists to produce.
- `issues`: blocking and warning issues (untraversable leg, empty team,
  scooter without a speed or burn time, member with zero SAC).

### Persistence

Three new tables in `lib/core/database/database.dart`, following the
`dive_plan_segments` pattern: text id, parent id, sort order, created and
updated timestamps, nullable hlc, no cascade, explicit child deletes.

| Table | Columns |
| --- | --- |
| dive_plan_missions | id, plan_id (unique), battery_reserve_fraction, default_current_speed_mps (nullable), default_current_sets_toward_deg (nullable), created_at, updated_at, hlc |
| dive_plan_mission_legs | id, mission_id, sort_order, label, distance_m, depth_m, heading_deg, current_speed_mps (nullable), current_sets_toward_deg (nullable), created_at, updated_at, hlc |
| dive_plan_mission_members | id, mission_id, sort_order, display_name, buddy_id (nullable), diver_id (nullable), sac_bottom, swim_speed_mps, scooter_equipment_id (nullable), scooter_name, scooter_speed_mps, scooter_burn_seconds, tow_speed_factor, tow_burn_factor, created_at, updated_at, hlc |

"No mission" is "no row" in `dive_plan_missions`, so `DivePlan.mission` is
null exactly when the plan has none.

The migration rung takes the next free number at implementation time. The
open buddy-linking PR (#2040) claims v220, so this lands as v221 or later.
The rung creates the tables and their indexes with create-if-missing
statements and has an idempotent assert like the existing plan column asserts,
so a database that already carries them is left alone.

Every seam the plan tables already cross gets the three new tables:

- the sync registry in `lib/core/data/repositories/sync_repository.dart`;
- export and import, full and since-HLC, in
  `lib/core/services/sync/sync_data_serializer.dart`;
- `lib/features/divers/data/repositories/diver_owned_rows.dart`, so deleting
  a diver removes their missions with their plans;
- plan-id and mission-id indexes in `lib/core/database/performance_indexes.dart`.

`DivePlanRepository.savePlan` writes the mission inside the existing
transaction with delete-and-reinsert, and records sync bookkeeping for the
three entity types after the transaction commits, as it does for segments.
`getPlan` hydrates the mission. `deletePlan` removes the rows. `duplicatePlan`
copies them with new ids.

The plan file codec (`plan_file_codec.dart`) moves to version 3 and adds an
optional `mission` block. Version 2 files, and version 3 files without a
mission, load unchanged. Export writes the block whenever a mission exists.

`DivePlanState` gains a `mission` field, and `dive_plan_state_mapper.dart`
maps it both ways.

### User interface

No new route. The mission lives in the existing three-pane plan canvas.

**Enabling.** A "Plan as DPV mission" action at the top of the segment list
in `plan_editor_pane.dart`. Turning it on creates a mission with one member
seeded from the plan's bottom SAC and no scooter, and one empty leg. Turning
it off asks for confirmation, removes the mission, and leaves the last
generated segments in place as ordinary editable segments.

**Route editor.** With a mission present, the hand-authored `SegmentList` is
replaced by a `MissionLegList`: one row per leg with label, distance, depth,
heading, and an expandable current row (speed, sets toward, or "use mission
default"). Legs can be added, deleted and reordered. Below the list a
collapsed "Generated profile" strip shows the generated segments read-only, so
the diver can see what the engine is fed.

**Team editor.** A new "DPV team" section in `plan_setup_accordion.dart`,
placed next to Contingency. One card per member: display name with an
optional buddy or diver picker that fills the name and photo, bottom SAC, swim
speed, and a scooter picker listing equipment items of type DPV with a
"manual scooter" fallback that exposes the numbers directly. The card shows
the scooter's Wh capacity when known, for information only. Mission-level
fields (battery reserve fraction, default current) sit at the bottom of the
section.

**Results.** A "Mission" section in `plan_results_pane.dart`:

1. The constraint sentence, for example "Limited by Sam's Blacktip at T:
   battery reserve".
2. Per-member cards: battery bar for the round trip with the reserve marked,
   whether the scooter sets the cruise speed, the binding factor and waypoint,
   and the member's turn pressure.
3. A waypoint table: cumulative distance, arrival run time, and per member a
   survivable or not status with the exit modes that still work and their
   exit minutes.
4. A leg table: outbound and return effective speed and duration.

Blocking mission issues also raise a status chip in `plan_status_chips.dart`
so they are visible from every tab.

**Providers.** `missionOutcomeProvider` in `plan_canvas_providers.dart` sits
beside `planOutcomeProvider`, watches the editing state and the engine
config, and runs the mission engine synchronously as the plan outcome does.
`DivePlanNotifier` gains mission mutations (set mission, add, update, remove,
reorder leg or member, set reserve, set default current); each regenerates
the segments through `MissionSegmentBuilder`. On load with a mission present,
the notifier resolves the scooter overlay through `MissionScooterResolver`
and regenerates once. If a measured recompute on a realistic mission exceeds
about 100 ms on a mid-range phone, the scenario evaluation moves to a compute
isolate; the move is made only after measuring.

**Units.** Distance through `UnitFormatter.formatDistance` (the depth unit,
metres or feet). Scooter, swim and current speed through the equipment
attribute unit path (`AttributeDimension.speedMps`, shown as m/min or
ft/min), not `formatSpeed`, which is the wind and boat convention. Heading in
degrees. Battery as percent of burn time with minutes beside it. Pressure and
SAC through the existing formatters. Every string goes into all eleven ARB
files, anchored on a neighbouring key in the non-English files.

### Error handling

- An untraversable leg (current at or above cruise speed in either
  direction) is a blocking issue. Segments are still generated for the
  traversable legs so the chart does not go blank, and the scenario service
  skips scenarios that cross the blocked leg.
- A mission with no members or with a member whose scooter lacks a speed or
  burn time produces a warning issue and an outcome with no scenarios rather
  than an exception.
- A scooter equipment id that no longer resolves falls back to the snapshot
  silently, with an informational issue naming the member.
- The engine call for a scenario is wrapped so one failing scenario is
  reported as an issue and does not hide the others.
- Repository writes stay inside the plan's transaction, so a failure mid-save
  leaves the plan and mission consistent.

## Testing

Tests are written first, in the pure-domain layer, with hand-computed
vectors, under `test/features/planner/mission/`.

- Current resolution: along-route component for a quartering current, sign
  flip on the return heading, an inherited mission default, and a current at
  or above cruise speed raising the blocking issue.
- Segment builder: durations from distance and effective speed, mirrored
  return legs, back-gas tank assignment, cruise set by the slowest scooter,
  regeneration replacing rather than appending.
- Battery: rated burn over a round trip, tow burn factor, the reserve check
  at the boundary, a dead scooter burning nothing.
- Scenarios, with the real `PlanEngine`: a two-member fixture where the swim
  exit needs more gas than the tow exit; tower selection when one teammate
  lacks battery; per-member gas from schedule rows with the stressed SAC
  applied only to the failed member; abandonment point on a route where the
  last waypoint is not survivable; and the constraint sentence on a
  three-member fixture where the slowest scooter belongs to one member and
  the highest SAC to another.
- Persistence: repository round trip with a mission, delete and duplicate,
  the migration rung on an empty and a populated database, serializer export
  and import for the three tables, diver-owned rows removal, codec version 2
  and version 3 loading, state mapper round trip.
- Catalog: the two new DPV attributes, defaults applied when absent, typed
  getters on `EquipmentItem`.
- Widgets, in English: leg list edits regenerate segments; the team section's
  scooter picker overlays live attributes; the results section renders the
  constraint sentence and waypoint table; enabling and disabling the mission.
- `test/architecture/` runs after the new files land, since affected-directory
  runs never include it.

## Delivery

The work splits into PRs that each
leave main working:

1. Domain and calculation: entities, the four services, the orchestrator,
   the catalog attributes and typed getters, with their tests. No UI, no
   schema.
2. Persistence: tables, migration, repository, sync seams, codec version 3,
   state mapper, with their tests.
3. Canvas UI: enabling action, leg list, team section, results section,
   status chip, providers, l10n, widget tests, and the recompute measurement.
