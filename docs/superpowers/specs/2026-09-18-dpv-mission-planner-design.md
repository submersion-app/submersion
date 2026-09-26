# DPV mission planner

Date: 2026-09-18
Issue: #2086
Revised: 2026-09-25, after feedback on the issue (see "Revision 2026-09-25")

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

The same questions come up without an overhead. A lake or open-water diver
asked, on the issue, whether a buddy's scooter can bring both divers home
(slower over the ground, faster battery drain) and where the latest turning
point is; how long a solo diver takes to fin back and whether the gas lasts;
and, if swimming back is not possible, how far the walk is.

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
- Serve open water as well as overhead environments: in open water a diver
  may ascend anywhere, swim straight home, or land on a shore and walk.
- Treat a solo diver as a first-class team of one.
- Report, per waypoint, the time to the next safe surface, and keep the exit
  evaluation free of scooter concepts so the overhead planner proposed in
  #2164 and discussed in #2294 can reuse it.
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
- Shorelines from map data. The shore exit is entered by hand per waypoint;
  placing a route on a map (the territory of the underwater routes work in
  #1772) is a later phase.
- Charging gas for a surface swim. At the surface the diver is not breathing
  from a cylinder in this model, so a surface exit costs time, not gas.
- Rebreather plans. A CCR, SCR or pSCR plan's loop gas is not tied to a
  carried cylinder, so exit gas could not be charged per diver; version 1
  refuses a plan that is not open circuit with a blocking issue.

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
| environment | MissionEnvironment | `overhead` (default) or `openWater`; decides which exits exist |
| walkSpeedMps | double | default 0.8, walking speed for a shore exit, open water only |
| surfaceSwimLimitM | double, nullable | longest acceptable surface swim; null means surface exits are reported but never block |

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
| shoreExit | ShoreExit, nullable | open water only: the nearest way onto land from this waypoint |

**ShoreExit**: `surfaceSwimM` (surface swim from the waypoint to the nearest
shore) and `walkM` (walk from there back to the entry). Both are entered by
hand; nothing is derived from a map.

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
The overlay is a presentation-layer resolver (`ScooterSpecResolver`) fed by
the equipment providers; the entity never reads the database.

**Equipment attribute catalog**: two new curated DPV attributes,
`tow_speed_factor` and `tow_burn_factor`, both numbers with dimension `none`.
An absent row means the default. No schema change, since attributes are rows
in `equipment_attributes`. `EquipmentItem` gains typed getters for the four
DPV numbers it currently exposes only through `attrNum`.

### Calculation

The mission engine lives in `lib/features/planner/domain/services/mission/`
as small single-purpose services plus an orchestrator.

**Speed over ground.** For a leg with heading h and current (c, d), the
along-track share is `a = c * cos(d - h)` and the cross-track share is
`x = c * sin(d - h)`. A diver moving through the water at speed v holds the
track by angling into the cross current, so their speed over the ground is
`a + sqrt(v^2 - x^2)`. The return flips the sign of `a` and keeps `x`. The
track cannot be held when `|x| >= v`, and a direction whose speed over the
ground is at or below zero cannot be travelled. With no cross current this
reduces to `v + a`. The same formula serves cruising, towing and swimming,
each with its own v, which is the "reduced speed over ground" of a tow.

(The first version of this spec used only the along-track share. That is
right in a cave passage, where the current follows the route, and wrong in
open water, where a cross current is the main effect. Corrected 2026-09-25.)

**Positions.** Each leg has a heading and a distance, so dead reckoning gives
every waypoint's position relative to the entry: the sum of
`distance * (sin h, cos h)` over the legs up to it. From that the engine
takes the straight-line distance and bearing home from each waypoint.

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
and every member m, m's scooter dies on arrival at k. The exits evaluated
depend on the environment:

| Exit | Overhead | Open water |
| --- | --- | --- |
| Swim back along the route | yes | no |
| Tow back along the route | yes | no |
| Swim straight home at the failure depth | no | yes |
| Tow straight home at the failure depth | no | yes |
| Ascend in place, then surface to the entry or the shore | no | yes |

- Swim: the whole team swims at the slowest swim speed in the team. No
  scooter burns.
- Tow: each teammate t is tried as the tower. Team speed through the water
  is `t.ratedSpeed * t.towSpeedFactor`, capped by the other members' rated
  speeds. The tower burns at the tow rate, the other members at the rated
  rate, m burns nothing. The best feasible tower is reported, or none. A
  solo diver has no tow exit; the report says "no buddy".
- Straight home (open water): one leg from waypoint k to the entry along the
  dead-reckoned bearing, held at the depth of waypoint k. Its current is the
  one in force on the leg that ends at k: that leg's own, else the mission
  default. The surface swim home takes the same current.
- Surface exit (open water): the plan engine computes the ascent from k,
  including any deco, from the outbound profile alone. At the surface the
  team swims at the slowest swim speed, either straight to the entry or to
  the waypoint's shore exit and then walks at `walkSpeedMps`; the faster of
  the two is reported. A surface exit is feasible when the ascent gas is
  available and, if `surfaceSwimLimitM` is set, the surface swim it chose is
  within the limit. Surface swimming is not charged gas.

**ExitPathEvaluator.** Building an exit path from a failure point, running
it through `PlanEngine`, and charging each member's gas from the schedule
rows is a service with no scooter concept: it takes the outbound segments,
the failure point, a list of exit legs (distance, depth, speed through the
water, current) and the per-member SAC rules. `MissionScenarioService`
composes it with battery accounting. This is the seam the overhead planner
of #2164 can reuse for its own exits (a jump back to the line, a restriction,
a gas-loss exit) without inheriting anything about scooters.

Each exit is a scenario `DivePlan`: the plan copied with segments = outbound
legs through k plus the exit legs. `PlanEngine.compute` runs once per
scenario and yields the schedule rows (depth, duration, phase) and time to
surface. Per-member gas over any span of rows is
`sum(duration * ambientPressure(depth) * sac(phase))`. A travel row is
charged at the mean of its start and end depth, and the exit's first row
starts at the failure depth. The working SAC is the member's own; the failed
member is stressed, breathing their own SAC scaled by the plan's
stressed-to-bottom ratio (never less than their own), so a heavy breather is
stressed in proportion. The working (or stressed) SAC holds through the exit
legs and the ascent up to the first decompression stop; from the first stop
on, everyone breathes the plan's deco SAC. `ambientPressure` comes from
`PlanEngine.environmentFor`, the one derivation the deco schedule uses.

Gas remaining for member m at waypoint k is the plan's usable gas minus m's
outbound consumption through k. An exit is feasible for the team when, for
every member, every cylinder they breathe ends at or above the plan's reserve
pressure, and for every scooter still running, burn stays within the reserve
fraction. As in the plan engine's own reserve rule, a cylinder never breathed
and a bailout cylinder are not held to the reserve.

A leg shorter than half a metre is a blocking validation issue: it is too
short to travel, and its outbound and return could not be matched.

Validation blocks, before any scenario runs: a battery reserve outside 0 to 1
or not a number; a scooter whose speed, burn time, tow speed factor or tow
burn factor is not positive; a negative or non-numeric leg depth; negative
open-water distances, limits or walking speed; a plan that is not open
circuit; a plan with no cylinder; and a cylinder with no volume or fill
pressure, whose gas no exit could prove safe. A planned route the plan engine
already calls not diveable (a critical ppO2, hypoxic gas, gas density or CNS
limit) is refused too. An exit that breaks one of those limits on its own,
in practice CNS from the extra time, is infeasible, and binds as exposure.
Gas running out is not one of them: it is judged per diver, not at the plan's
single SAC.

Scenario count per failure is one swim plus up to `members - 1` tows, so the
underwater exits take at most `waypoints * members * members` engine runs (54
for three members and six waypoints). An overhead mission adds one run per
waypoint for the time to the next safe surface, `waypoints * (members *
members + 1)` in all (60). Open water instead adds one surface-exit run per
failed member: the ascent is the same whoever failed, but the failed diver
breathes their stressed SAC up to the first stop, so the gas differs. That is
`waypoints * (members * members + members)` (72). Each waypoint's outbound
profile is built once and shared by every run there.

**MissionOutcome.** The result type the UI reads:

- `legs`: per leg, outbound and return effective speed and duration.
- `waypoints`: per waypoint, cumulative distance, straight-line distance
  home (open water), arrival run time, the time to the next safe surface
  with no failure (overhead: the way out at cruise plus the ascent; open
  water: the ascent alone), and per member: gas remaining, the swim exit
  result, the tow exit result (tower, exit minutes, time to surface, gas
  needed per member, feasible, or "no buddy"), the surface exit result in
  open water (surface swim distance, walk distance, whether it went via the
  shore, surface minutes, feasible), and whether a failure of that member's
  scooter there is survivable.
- `abandonmentIndex`: the last waypoint at which every member's failure has
  at least one feasible exit. Equal to the last leg when the whole route is
  survivable. Null when even the first waypoint is not.
- `members`: per member, battery used on the no-failure round trip, whether
  their scooter sets the cruise speed, the first factor to bind with the
  waypoint where it binds, and the mission turn pressure: gas that must
  remain at the abandonment point to cover that member's worst feasible exit
  plus the plan's reserve. The binding factors are battery, own gas, a
  teammate's gas, exposure (an exit that breaks a critical oxygen or gas
  limit), blocked by current, no feasible tow (only when the member has a
  teammate), and surface swim over the limit.
- `constraint`: the member and factor that bind earliest. This is the
  sentence the feature exists to produce.
- `issues`: blocking and warning issues (untraversable leg, empty team,
  scooter without a speed or burn time, member with zero SAC).

In open water without a surface swim limit the surface exit is almost always
feasible, so the abandonment point is usually the last waypoint. That is the
honest answer for open water: the question becomes how long the way home
takes, which the report shows per waypoint, not whether one exists. Setting a
limit turns the surface swim back into a constraint.

### Persistence

Three new tables in `lib/core/database/database.dart`, following the
`dive_plan_segments` pattern: text id, parent id, sort order, created and
updated timestamps, nullable hlc, no cascade, explicit child deletes.

| Table | Columns |
| --- | --- |
| dive_plan_missions | id (equals plan_id), plan_id (unique), battery_reserve_fraction, default_current_speed_mps (nullable), default_current_sets_toward_deg (nullable), environment (text, default overhead), walk_speed_mps, surface_swim_limit_m (nullable), created_at, updated_at, hlc |
| dive_plan_mission_legs | id, plan_id, sort_order, label, distance_m, depth_m, heading_deg, current_speed_mps (nullable), current_sets_toward_deg (nullable), shore_swim_m (nullable), shore_walk_m (nullable), created_at, updated_at, hlc |
| dive_plan_mission_members | id, plan_id, sort_order, display_name, buddy_id (nullable), diver_id (nullable), sac_bottom, swim_speed_mps, scooter_equipment_id (nullable), scooter_name, scooter_speed_mps, scooter_burn_seconds, tow_speed_factor, tow_burn_factor, created_at, updated_at, hlc |

Legs and members reference `plan_id` rather than a mission id, so they sit
one level under their plan like `dive_plan_segments`, which is the only
shape the diver deletion, the repository's delete-and-reinsert and the sync
parent references support. The mission row's id is its plan's id.
`buddy_id`, `diver_id` and `scooter_equipment_id` are plain ids with no
foreign key: a key with no delete action would block deleting the buddy,
diver or item.

"No mission" is "no row" in `dive_plan_missions`, so `DivePlan.mission` is
null exactly when the plan has none.

The migration rung takes the next free number at implementation time. On
2026-09-25 main is at v226, #2315 claims v227 and #1772 claims v228, so this
lands as v229 or later; re-check `origin/main` before opening the PR.
The rung creates the tables and their indexes with create-if-missing
statements and has an idempotent assert like the existing plan column asserts,
so a database that already carries them is left alone.

Every seam the plan tables already cross gets the three new tables:

- the sync registry in `lib/core/data/repositories/sync_repository.dart`;
- export and import, full and since-HLC, in
  `lib/core/services/sync/sync_data_serializer.dart`;
- `lib/features/divers/data/repositories/diver_owned_rows.dart`, so deleting
  a diver removes their missions with their plans;
- plan-id indexes on the leg and member tables in
  `lib/core/database/performance_indexes.dart` (the mission table's unique
  `plan_id` key is already an index).

`DivePlanRepository.savePlan` writes the mission inside the existing
transaction with delete-and-reinsert, and records sync bookkeeping for the
three entity types after the transaction commits, as it does for segments.
`getPlan` hydrates the mission. `deletePlan` removes the rows. `duplicatePlan`
copies them with new ids.

The plan file codec (`plan_file_codec.dart`) moves to version 3 and adds an
optional `mission` block, including the environment, walk speed, surface
swim limit and each leg's shore exit. Version 2 files, and version 3 files
without a mission, load unchanged. Export writes the block whenever a mission
exists, and leaves out the buddy, diver and scooter equipment links, because
they name rows of the exporting install.

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
default"), and in open water an expandable shore exit row (surface swim to
shore, walk to the entry). Legs can be added, deleted and reordered. Below
the list a
collapsed "Generated profile" strip shows the generated segments read-only, so
the diver can see what the engine is fed.

**Team editor.** A new "DPV team" section in `plan_setup_accordion.dart`,
placed next to Contingency. One card per member: display name with an
optional buddy or diver picker that fills the name and photo, bottom SAC, swim
speed, and a scooter picker listing equipment items of type DPV with a
"manual scooter" fallback that exposes the numbers directly. The card shows
the scooter's Wh capacity when known, for information only. Mission-level
fields (environment, battery reserve fraction, default current, and in open
water the walk speed and the optional surface swim limit) sit at the bottom
of the section. A team of one is a normal team; the card list simply has one
card.

**Results.** A "Mission" section in `plan_results_pane.dart`:

1. The constraint sentence, for example "Limited by Sam's Blacktip at T:
   battery reserve".
2. Per-member cards: battery bar for the round trip with the reserve marked,
   whether the scooter sets the cruise speed, the binding factor and waypoint,
   and the member's turn pressure.
3. A waypoint table: cumulative distance, arrival run time, time to the next
   safe surface, and per member a survivable or not status with the exit
   modes that still work and their exit minutes. In open water it also shows
   the straight-line distance home and the surface exit (via the entry or via
   the shore and a walk). A solo diver's tow column reads "no buddy".
4. A leg table: outbound and return effective speed and duration.

Blocking mission issues also raise a status chip in `plan_status_chips.dart`
so they are visible from every tab.

**Providers.** `missionOutcomeProvider` in `plan_canvas_providers.dart` sits
beside `planOutcomeProvider`, watches the editing state and the engine
config, and runs the mission engine synchronously as the plan outcome does.
`DivePlanNotifier` gains mission mutations (set mission, add, update, remove,
reorder leg or member, set reserve, set default current); each regenerates
the segments through `MissionSegmentBuilder`. On load with a mission present,
the notifier resolves the scooter overlay through `ScooterSpecResolver`
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

- An untraversable leg (a cross current at or above cruise speed, or a
  speed over the ground at or below zero, in either direction) is a
  blocking issue. Segments are still generated for the
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
- An exit whose own speed (a swim, a slow tow) cannot hold the track or make
  headway is reported as blocked by current, per exit, without running the
  engine; the other exits still run.

## Testing

Tests are written first, in the pure-domain layer, with hand-computed
vectors, under `test/features/planner/mission/`.

- Speed over ground: a pure along-track current, a pure cross current
  (0.5 m/s through the water in a 0.3 m/s cross current makes 0.4 m/s over
  the ground), a quartering current, the return keeping the cross share, a
  cross current at or above the speed through the water blocking the track,
  and an inherited mission default.
- Positions: dead reckoning over legs on different headings, and the
  straight-line distance and bearing home.
- Open water: straight-home and surface exits replace the retrace exits; the
  surface exit takes the shore and walk when that is faster; a surface swim
  limit makes a waypoint unsurvivable; with no limit the abandonment point
  is the last waypoint.
- Solo diver: no tow exit, "no buddy" in the outcome, and a current-blocked
  swim binding as blocked by current rather than as no feasible tow.
- Exit path evaluator: per-member gas and time to surface with no scooter in
  the fixture.
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
  and version 3 loading (including the environment, walk speed, limit and
  shore exits), state mapper round trip.
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
   schema. PR #2138; the 2026-09-25 revision (speed over ground, open
   water, shore exits, solo divers, the exit path evaluator) lands in it
   before merge.
2. Persistence: tables, migration, repository, sync seams, codec version 3,
   state mapper, with their tests.
3. Canvas UI: enabling action, leg list, team section, results section,
   status chip, providers, l10n, widget tests, and the recompute measurement.

## Revision 2026-09-25

Three comments on #2086 shaped this revision.

- A lake diver asked whether a buddy's scooter can bring both divers home
  and where the latest turn is, how long a solo fin back takes and whether
  the gas lasts, and how far the walk is when swimming back is not possible.
  The tow exit and the abandonment point already answered the first. This
  revision adds the open-water environment (straight-line and surface
  exits), hand-entered shore exits with a walk, and first-class solo divers.
- Answering the "slower over the ground" part exposed an error: the first
  version ignored the cross-track share of a current. Speed over ground now
  accounts for the diver angling into a cross current.
- A contributor suggested building the cave planner (#2164) first; the
  follow-up discussion (#2294) proposes one concept for every overhead
  scenario, the time and distance to the next safe surface. The DPV work
  continues, and adopts that concept: every waypoint reports its time to the
  next safe surface, and the exit evaluation is a scooter-free service the
  overhead planner can reuse.

