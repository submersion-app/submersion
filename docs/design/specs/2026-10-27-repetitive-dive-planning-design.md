# Repetitive dive planning

Issue: #3565. Design discussion: #3700.

## Intent

The dive planner plans one dive at a time. Divers plan days: two or three dives
with surface intervals between them, where each dive starts with the nitrogen,
CNS and OTU the earlier ones left behind, and with the gas left in the tanks.
This adds a **series** of planned dives to the planner, a way to move between
them, and the chain that carries each dive's end state into the next.

The full design, its mockups and its five phases are in discussion #3700. This
record covers what the phases agreed and the decisions made for phases 1 and
4, the phases built so far.

## Phases

1. **Series in memory** (built): navigator, add and remove dives, the
   Dive details card, the tissue/CNS/OTU chain, carried tank pressures with
   Fill.
2. **Shared settings**: settings shared across the series with per-dive
   overrides, series warnings.
3. **Persistence**: a `dive_plan_series` table (synced), migration of existing
   plans into one-dive series, the saved-plans list grouped by series, keyboard
   shortcuts.
4. **Logged dives** (built): follow any logged dive, the one-tap Follow prompt, "Plan
   repetitive dive" in the dive detail menu, the read-only logged-dive view.
5. **Plan vs actual**: a logged plan becomes Dive #xxx, and the dives after it
   are recalculated from it.

## Phase 1 behaviour

- Every plan is a series. A new plan is just **Dive A**; `+` appends a dive.
- Planned dives are lettered A, B ... Z, AA, AB. "Plan" stays the name of the
  whole.
- A new dive copies the previous dive's settings, profile, tanks and gases
  under fresh ids, with a **1:00** surface interval, and is selected.
- Any dive can be removed (after confirming) except the last one left. The
  letters close up. The dive after it carries from the dive before it.
  Removing Dive A makes Dive B a fresh first dive.
- The navigator shows each planned dive as the main menu's diver
  (`Icons.scuba_diving`) filled white and outlined in the primary colour,
  then its name, or its letter while it has none (cut short past 160 px);
  Material has no outlined diver, so the glyph is painted twice, filled and
  stroked. Each surface interval is its time above two waves (the top two
  lines of `Icons.waves`). There are no step arrows: the bar scrolls by
  touch or mouse drag, and a dive is selected by tapping it. A dot marks a
  dive with a warning, red when any is critical and orange otherwise.
  Logged dives the plan follows lead the bar from phase 4 (below).
- The **Dive details** card sits above Tanks in the editor pane and at the
  top of the phone Tanks tab, on every dive. It holds:
  - **Dive name**, optional, up to 40 characters, with the dive's letter as
    its hint. A named dive's chip shows the name in place of the letter;
    the letter stays in its tooltip. The name belongs to the series
    (`PlanSeriesDive.name`), not to the plan, whose name stays the title of
    the whole; a new dive starts unnamed.
  - **Surface interval** (h:mm, 15-minute steppers). On a first dive that
    follows no logged dive it is empty and greyed out rather than hidden,
    so the panels below keep their place when the diver changes dives. A
    replan seeded from the dive before the replanned one keeps its interval
    live.
  - Water type and altitude stay in Plan settings.
- DPV mission plans stay single dives: `+` is disabled for them, and "Plan as
  DPV mission" is disabled for a series, with a tooltip saying why. A series
  mixing ordinary and mission dives is a separate feature.

### What carries into the next dive

| Carried | How |
| --- | --- |
| Tissues | The previous dive's compartments on reaching the surface (`PlanOutcome.surfacedTissue`: after the ascent, its stops and any air breaks), off-gassed on air over the surface interval (`seededTissueState`, the existing follow-a-dive seed). |
| CNS | The previous dive's end CNS, decayed over the surface interval with the 90-minute half-time the dive log uses. |
| OTU | The OTU of every earlier dive that ended less than 24 hours before this dive starts (a rolling daily total). Times run from Dive A's start; each dive starts its surface interval after the previous one ends. |
| Tank pressures | Each tank starts at its source tank's end pressure (clamped at 0), unless it was filled or its start pressure typed. |

Dive A is computed as given unless the series follows a logged dive (phase
4, below).

### Tanks

- **Fill** on a tank fills it to its start pressure in the dive the series
  first carried it in (the diver's own fill), falling back to its working
  pressure. **Fill all tanks** fills every tank.
- A filled tank, or one whose start pressure the diver types, is pinned: the
  previous dive's end pressure no longer carries into it.
- A tank that starts low is caught by the existing gas and reserve checks.

### Saving

A series saves as a whole: a `dive_plan_series` row, and each dive as an
ordinary saved plan placed in it (`series_id`, `series_index`). A plan with no
series is a one-dive series, so nothing is backfilled. Save is on whenever any
dive has changed, or a dive was added, removed or named. A single dive that
follows a logged dive saves as a series too, since the series row holds the
followed dive.

Opening any dive opens its series with that dive selected. What it carries in
is never stored: the follow is rebuilt from the followed dive, without
re-minting tanks or resetting the interval, and the chain runs again, so a
saved followed plan reopens with the same schedule, CNS and OTU it was saved
with.

## Updating the log

**Create planned dives** replaces Convert to Dive in the planner's menu, for a
single plan or a series. It reads **Update planned dives** once any dive has an
entry in the log. The log only changes through this action, never on save.

- A dive with no entry gets a planned one, with its time, site, computed profile
  and tanks, linked by the plan's `linkedDiveId`.
- A dive whose entry is still planned has it rewritten, keeping its id. A rename
  made in the log to a planned entry is overwritten.
- A dive already dived is left alone: the log owns it now.
- A series with no start asks for the first dive's, since its dives need times.
- A series' entries take each dive's own name, or none, so a completed dive goes
  by its number. A single plan's entry takes the plan's name, its only one.
- A dive of the plan that can't be logged (critical warnings, no segments) stops
  the whole update with nothing written, and the message names the dive. A later
  dive running out of gas on carried pressures is the usual case: Fill clears it.
- A dive removed from the series whose entry is still planned is offered for
  deletion on the next update. That list is held in memory, so it's lost when
  the app closes, and the entry stays in the log as a plain planned dive.

**From the log:** a planned entry's banner has **Open in planner**, and a dived
one has **View in planner** in its menu, both while the plan still exists. The
link is the plan's, so deleting the plan takes both away with nothing to clean up.

**The saved plans list** shows a series as one row with its dive count, deepest
depth and total runtime, and each dive on a line that opens the series on it.
Rename, Duplicate, Share and Delete act on the whole series. Compare stays on
single plans: a series' later dives depend on the dives before them. A single
dive that follows a logged dive is saved as a series but reads as one plan, and
is shared as one.

**Leaving** the planner, or replacing the plan with "Plan repetitive dive",
with unsaved series changes asks: Save, Discard or Cancel. A series with nothing
to save goes without asking.

**Opening a different saved plan** with unsaved changes asks the same, as "Save
this series?" or "Save this dive?" by what is being edited. Cancel, or cancelling
the name prompt that a first save opens, stays on the plan being edited. Opening
a dive of the series being edited selects it, keeping the edits.

**A `.subplan` file** at version 4 holds a series: each dive's plan, name and
interval, its setting overrides, and which tank of the dive before each tank
carries from, by position. The followed dive and start times stay out: the
dive is in the sender's log, and a start belongs to the sender's day. Older
installs refuse the file rather than open one dive as if it stood alone. A
single dive is still written as version 2 or 3.

**Across profiles**, saved plans aren't scoped to a diver yet (#4074). A plan
following another diver's dive still finds that dive, so it carries the same
load, and a series keeps the diver who first saved it.

## Phase 4 behaviour

- **Follow or replan.** Until phase 4, `sourceDiveId` named both the dive a
  plan follows and the dive "Replan this dive" rebuilds, so the planner could
  not tell them apart. Now the series holds the follow
  (`PlanSeries.follow`), in memory like the rest of the series, and
  `sourceDiveId` is a replan's alone: its compare strip and overlay, and the
  reset when the planner closes, apply to replans only. A plan following a
  logged dive cannot be saved or converted until phase 3 persists series: what
  it carries in is not stored, so it would reopen as a fresh diver. Stop
  following gives both back. Plans saved before keep their `sourceDiveId` and
  open as replans, as they did.
- **What is followed.** The followed dive and the logged dives before it,
  back to the first gap of 48 hours or more, the window the log uses for
  residual tissue. Planned dives and dives logged after the followed one are
  left out.
- **Bar.** Each logged dive is the main menu's diver, solid, and its name,
  else its dive number, else its date (the same in the Follow prompt), with
  the real
  interval between logged dives, then Dive A's interval. Tapping a logged
  dive shows it read-only in place of the planner: its profile (the dive
  log's own chart, starting on depth, NDL, deco stops and ceiling, with NDL
  on the right axis; its toggles are scoped to the view, so the dive log
  keeps its own), Open in dive log, Stop following on the followed dive,
  and what it carries into the next dive (interval, end CNS, OTU, each
  tank's end pressure). Tapping a planned dive goes back. The bar opens on
  the selected planned dive, scrolled past the logged ones.
- **Carry into Dive A.** As between planned dives: the followed dive's end
  tissues and CNS (the dive log's analysis, residual from the dives before
  it included), off-gassed and decayed over Dive A's interval; the OTU of
  every logged dive that ended less than 24 hours before the dive starts,
  for Dive A and every later dive; and the tanks. Dive A takes the followed
  dive's own tanks (name, size, rated pressure, gas, role), each starting at
  the pressure it ended with; one with no recorded end pressure starts at
  its logged fill. Fill fills to the logged fill. The profile, and Dive B's
  tank links, move to the new tank of the same gas (rounded O2 and He),
  else to the first. A followed dive with no tanks leaves Dive A's own,
  which keep their pressures. Stop following keeps the tanks, back at their
  fills. Removing Dive A leaves Dive B following, its tanks carrying from
  the logged tanks Dive A's did, after its own interval.
- **Interval.** Following a dive that ended less than an hour ago gives Dive A
  the usual 1:00, and its start follows from that. A dive that ended an hour
  or more ago starts Dive A after the time since, rounded up to the minute, so
  by default a plan starts now and never in the past, however old the dive.
  These are defaults only: the diver can type a shorter interval or an earlier
  start.
- **Ways to follow.**
  - Follow a dive (planner menu) lists every logged dive.
  - A one-tap prompt under the bar offers the most recent logged dive when
    it ended less than 48 hours ago; hidden for a replan, once the plan
    follows a dive, and once dismissed (for the session).
  - **Plan repetitive dive** in the dive detail menu, right after "Replan
    this dive", on every logged dive (not a planned one), opens a new plan
    that follows it. Like "Replan this dive", it goes back to the planner
    rather than pushing a second one when the planner is already in the
    stack (a dive opened from the planner), which go_router cannot hold. It lands next to the "What if" entry #2407 changes; the
    merge is a matter of keeping both.
- **Stopping.** Stop following sits in the followed dive's read-only view.
  There is no Following chip under the profile: it read as part of the chart
  while acting on the whole series, and one tap dropped the followed dive.

## Start time and site

Phases 2, 3 and 5 are built together; the plan is
`docs/design/plans/2026-11-01-repetitive-dive-planning-phase-2-3-5.md`.

- The Dive details card holds, in order: the dive name, its **start**, the
  surface interval, and its **site**. Both new fields are optional.
- **Start and interval set each other.** A dive's start is the previous
  dive's end plus its interval. The diver can set either:
  - Setting a later dive's start fixes it (`PlanSeriesDive.fixedStart`): its
    interval is then measured from the previous dive's end, and a longer
    earlier dive shortens it rather than moving the start.
  - Setting the interval lets it lead again, and the start follows.
  - Clearing a fixed start lets the interval lead, from the interval the dive
    had.
  - A first dive that follows a logged dive works the same way against the
    logged dive's end.
  - A first dive that follows nothing has no interval; its start is its own,
    and optional.
- A later dive can be timed only once the dive before it has a start, so its
  start field is greyed out ("Give the first dive a start time first") until
  the first dive has one or follows a logged dive.
- A start before the previous dive ends computes the dive from no surface
  interval.
- **Times are clock digits stamped UTC**, like the dive log's
  (`DateTime.utc` of the digits shown). The arithmetic runs on true instants
  (`fromWallClockUtc`), so a daylight saving change inside an interval does
  not move a dive by an hour. Saved plans store the start the same way, and
  Convert to Dive writes it, or the clock time now, straight into the dive.
- **The site** is the plan's existing `siteId`, now editable here with the
  dive log's site picker. The planner doesn't use it; a dive logged from the
  plan takes it. A new dive copies the previous dive's site.

## Shared settings and tanks

- **The first dive's settings are the series'.** Each Setup section
  (Decompression, Rates, Gas, Environment, Contingencies) and the Tanks card
  is a group. Changing a group on the first dive reaches every later dive
  that has not set its own. Changing it on a later dive makes it that dive's
  own at once, without asking. The section then reads "This dive only" and
  offers **Reset to series** and **Apply to all dives**. On a single dive
  nothing shows.
- **Tanks** follow the same rule for what a tank is: its size, rated
  pressure, gas, role and name. Adding, removing or changing a tank on the
  first dive does the same on the later dives that share the series' tanks,
  and their profiles move off a removed tank. A dive on another circuit keeps
  its own.
- **Start pressures are not shared.** A tank carries what was left in its
  tank on the previous planned dive only while it is the same tank, the same
  size and gas. A tank that is no longer the same one starts full at its
  rated pressure, and a tank the previous dive does not have starts at the
  series' fill. A pressure the diver filled or typed stays, and doesn't make
  the tanks the dive's own.
- **The same goes for a followed dive.** Dive A takes the logged dive's tanks,
  and so do the later dives that share the series' tanks. Each carries the
  logged end pressure only while it is that tank: changed to another size or
  gas, it starts full. Nothing here changes the logged dive.

## Series warnings

Each dive of a series, and a first dive that follows a logged dive, is checked
against what came before (`seriesIssuesFor`). The warnings join the dive's own,
so its dot, the warnings list and the count all include them.

| Warning | When | Severity |
| --- | --- | --- |
| Short surface interval | Under 10 minutes | Warning |
| Starts before the previous dive ends | A fixed start earlier than that end | Critical |
| Starts owing deco | Off-gassed tissues still can't surface at the high GF | Critical |
| Reverse profile | More than 12 m deeper than the dive before | Warning |

A planned dive's stops always clear the ceiling before it surfaces, so owing deco
comes only from a followed logged dive that left it, or a later dive with a
stricter high GF than the one before.

CNS and OTU need no warning of their own: the engine starts each dive from the
carried exposure, so its existing warnings already count earlier dives. The OTU
limit stays 300 against the rolling 24-hour total.

A series summary card, with no-fly time, was built and removed: the results
pane has little room, and the deco schedule matters more there. The planner shows
no no-fly time.

## Design

- **Engine**: `DivePlan` gains `startCns`/`startOtu`, engine inputs that are not
  persisted. The engine starts its CNS and OTU from them. Contingency and
  range-table variants copy the plan, so they start from the same exposure.
- **Editing state**: `DivePlanState` gains `initialCns`/`initialOtu`. The
  mapper decays `initialCns` over the surface interval on the way to the
  engine, as the tissue seed is off-gassed, so editing the interval
  recalculates live.
- **Series domain** (`plan_series.dart`, `plan_series_edits.dart`,
  `plan_series_calculator.dart`): pure Dart, immutable. `computeSeries` runs
  the chain; `carriedState` seeds one dive from the results before it.
- **State**: `planSeriesNotifierProvider` holds the series around the existing
  `divePlanNotifierProvider`, which keeps editing the selected dive, so the
  cards, chart and results work unchanged. Selecting a dive stores the edited
  one and loads the selected one with its carry applied. Edits flow back
  through a listener. A plan the editor starts or loads by itself starts a new
  one-dive series.

## Out of scope

Everything in phases 2, 3 and 5, plus (as in #3700) a whole-day timeline chart,
series PDF export, and inserting or reordering dives.
