# Repetitive dive planning

Issue: #3565. Design discussion: #3700.

## Intent

The dive planner plans one dive at a time. Divers plan days: two or three dives
with surface intervals between them, where each dive starts with the nitrogen,
CNS and OTU the earlier ones left behind, and with the gas left in the tanks.
This adds a **series** of planned dives to the planner, a way to move between
them, and the chain that carries each dive's end state into the next.

The full design, its mockups and its five phases are in discussion #3700. This
record covers what the phases agreed and the decisions made for phase 1, which
is the only phase built so far.

## Phases

1. **Series in memory** (this phase): navigator, add and remove dives, the
   Dive details card, the tissue/CNS/OTU chain, carried tank pressures with
   Fill.
2. **Shared settings**: settings shared across the series with per-dive
   overrides, series warnings, the series results summary.
3. **Persistence**: a `dive_plan_series` table (synced), migration of existing
   plans into one-dive series, the saved-plans list grouped by series, keyboard
   shortcuts.
4. **Logged dives**: follow any logged dive, the one-tap Follow prompt, "Plan
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
  dive with a warning, red when any is critical and orange otherwise. A
  logged dive the plan follows
  joins the bar in phase 4, as a solid diver and its dive number: today
  `sourceDiveId` names both a followed dive and the dive a "What if" plan
  replans, so the bar cannot yet tell which it is.
- The **Dive details** card sits above Tanks in the editor pane and at the
  top of the phone Tanks tab, on every dive. It holds:
  - **Dive name**, optional, up to 40 characters, with the dive's letter as
    its hint. A named dive's chip shows the name in place of the letter;
    the letter stays in its tooltip. The name belongs to the series
    (`PlanSeriesDive.name`), not to the plan, whose name stays the title of
    the whole; a new dive starts unnamed.
  - **Surface interval** (h:mm, 15-minute steppers). On a first dive that
    follows no logged dive it is empty and greyed out rather than hidden,
    so the panels below keep their place when the diver changes dives.
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

Dive A is computed as given, so a logged dive it follows still seeds it.

### Tanks

- **Fill** on a tank fills it to its start pressure in the dive the series
  first carried it in (the diver's own fill), falling back to its working
  pressure. **Fill all tanks** fills every tank.
- A filled tank, or one whose start pressure the diver types, is pinned: the
  previous dive's end pressure no longer carries into it.
- A tank that starts low is caught by the existing gas and reserve checks.

### Saving

A series cannot be saved until phase 3. While a plan has more than one dive,
Save is disabled (its tooltip says why), and so is Convert to dive, which saves
the plan. Removing dives back to one re-enables both.

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

## Out of scope for phase 1

Everything in phases 2 to 5, plus (as in #3700) a whole-day timeline chart,
series PDF export, and inserting or reordering dives.
