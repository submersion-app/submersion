# SAC trend by cylinder role

Issue: #771 (the remaining part). Related: #3673 and PR #3696 (rebreather dives
left out of SAC), #4082 and PR #4135 (O2 and diluent loop rates), #3109
(multi-cylinder SAC), #3374 (twin set role), #1272 (exclude from gas
statistics).

## Intent

The reporter logs open-circuit recreational dives (bottom gas), open-circuit
technical dives (bottom gas plus deco gas) and CCR dives (diluent, oxygen, and
bailout plus deco on the dives where they bailed out). They want a consumption
trend per cylinder role, so they can see their typical bottom, deco and stage
rates over time and use those figures to plan dives.

Most of the original complaint is already fixed:

- PR #3696 took CCR and SCR dives out of every SAC and RMV aggregate, so the
  main trend no longer mixes loop dives with open-circuit ones.
- PR #4135 added the Rebreather gas use card: O2 and diluent trends in litres
  per minute of loop time.

What is missing is the trend split by role. Today the Gas page has:

- **SAC trend:** one series. Each point is one dive, with the gas of every
  breathed cylinder summed and divided once (#3109). On a technical dive that
  blends bottom, stage and deco gas into one figure.
- **SAC by tank role:** one average per role, no trend. Its SQL
  (`getSacVolumeByTankRole`, `getSacPressureByTankRole` in
  `insights_repository.dart`) divides each cylinder's gas by the **whole
  dive's** runtime and **whole dive's** average depth. A deco cylinder breathed
  for 10 minutes at 6 m on a 60 minute dive with a 25 m average comes out at a
  small fraction of its real rate. A back gas cylinder on a deco dive is
  understated too, since the deco minutes on another gas count against it.

That second point matters more than the chart. A per-role trend built on
whole-dive arithmetic would put wrong numbers on a chart the diver plans from.
The planner's default SAC ("from your log", `loggedAverageSacProvider` in
`plan_canvas_providers.dart`) reads the backmount row of the same query, so it
carries the same understatement for anyone who logs deco dives.

The right arithmetic already exists for one dive. `calculateCylinderSac` in
`gas_analysis_service.dart` works out when each cylinder was breathed from the
gas switches (`tankUsageWindows` in `tank_usage_range.dart`), the mean depth
over those windows from the profile, and the drop from the pressure series
when there is one. The dive detail's per-cylinder SAC uses it. The statistics
never have.

How often: every dive for a technical diver who logs gas switches, and never
for a single-cylinder recreational diver, whose figures do not change.

## Goals

- A per-role consumption trend on the Gas page: one line per role group, one
  point per dive, on the existing `TrendChartSection` and `DiveTrendChart`.
- Each point is that role's rate over the time it was breathed and the depth it
  was breathed at, from the same calculation as the dive detail's per-cylinder
  SAC. One dive reads the same in both places.
- The per-role averages, the trend and the planner's logged default SAC come
  from that one calculation, so they agree with each other.
- Both lanes work: SAC (pressure per minute) and RMV (volume per minute), as
  the page's lane toggle chooses, in the active diver's units.
- A dive whose breathing times cannot be known is left out, and the card says
  how many dives that left out, rather than dropping them silently.
- CCR bailout gets its own line: the open-circuit rate while bailed out, from
  the windows `ccrDiveUse` already finds.

## Non-goals

- Changing the main SAC trend, the records, or any other SAC/RMV aggregate.
  The main trend stays the diver's overall figure per dive.
- Changing the Rebreather gas use card. Diluent and O2 are already there and do
  not get lines here.
- Changing the query language's `sac` field or the dive overview's headline
  SAC.
- A left versus right balance view for sidemount.
- A persisted cache of per-cylinder rates. See Performance.
- Any schema change, migration, or change to stored data.

## Anti-goals

- A role line whose figure disagrees with the dive detail for the same dive and
  cylinder (beyond the documented downsampling tolerance below).
- A deco or stage figure computed over the whole dive. Leaving a dive out is
  better than showing a wrong rate.
- A rebreather loop figure on any open-circuit role line.
- An open-circuit diver with one cylinder per dive seeing a busier page. If
  only one role group has data, the card shows one line, and the page should
  read as it does now apart from the card's new chart.

## Role groups

Each line is a role group. A cylinder joins a group by its `TankRole`:

| Group | Roles | Notes |
| --- | --- | --- |
| Bottom gas | `backGas`, `twinSet`, `sidemountLeft`, `sidemountRight` | The primary gas, however it is worn. |
| Stage | `stage` | |
| Deco | `deco` | |
| Pony | `pony` | Only appears when some dive breathed one. |
| Bailout | `bailout` on an open-circuit dive, and bailout time on a CCR dive | See Bailout. |

`diluent` and `oxygenSupply` cylinders on an open-circuit dive (a mislabelled
log) join no group.

Sidemount is folded into Bottom gas (my call). A sidemount pair is breathed in
turns on one gas, and `tankUsageWindows` gives both cylinders one shared window
until each has a switch of its own (#3373), so a per-side rate is about half
the diver's real rate and says nothing useful for planning. The reporter
suggested tracking the sides separately because "Bottom" would then be
unclear. Folding answers that: Bottom gas is whatever primary gas was worn,
backmount or sidemount, summed the way the main trend sums it. Backmount
already folds back gas and twin set (#3374).

Pony gets its own line rather than being dropped (my call). It is rarely
breathed, and a dive where it was is worth seeing, but it must not drag the
bottom gas line around.

## The per-dive, per-group figure

### Which cylinders count

A cylinder **counts** toward its group on a dive when it lost gas, its
breathing time is known, and its gas can be measured in the lane's unit:

- **Breathing time known:** `tankUsageWindows` gives it a window, or it has a
  recorded usage duration (`tank.usageDuration`, #1496) and is a primary gas
  cylinder (Bottom gas group). A dive's only cylinder is breathed for the
  whole dive. Without gas switches only the primary gas is known to span the
  dive; a stage, deco, pony or bailout cylinder with no switch has no window.
- **Measurable:** RMV lane, its size is known or comes from its matched
  partner (`consumptionVolume`). SAC lane, its size is known, or it is the
  group's only cylinder, or it forms a matched pair with the group's
  reference (which then counts one to one, as `referencePressureDrop` does).
- **Lost gas:** a pressure series drop over its windows, else logged start
  above logged end. A cylinder that lost nothing was carried, not breathed,
  and is simply ignored. So is a stage, deco, pony or bailout cylinder with no
  switch onto it and no recorded duration whose drop is at most the larger of
  15 bar and 7% of its start: a fill cooling to the water (30 to 10 C is about
  7%) and a hand-read gauge move a carried cylinder that much. A recorded
  duration says the gas was breathed, so it keeps the strict rule.

A cylinder that lost gas but does not count is **unresolved**. Its gas and its
time both stay out of its group (my call): joining only its time would put a
low rate on the chart, as with two stages breathed in turn where only one has
a size.

A stage, deco or pony cylinder with a recorded duration but no switches is
unresolved (my call). The duration says how long but not at what depth, and a
deco rate at the whole dive's mean depth is about half its real value, which
is the error this design exists to remove. The dive detail still shows its
per-cylinder figure; the chart does not.

### When a dive leaves every group

If any open-circuit cylinder on the dive is unresolved because its **time** is
unknown (a stage, deco or pony cylinder that lost gas with no switch), the
dive adds no point to **any** group, Bottom gas included (my call). Without
switches the back gas window is the whole dive, so its rate would be divided
by the deco minutes too: the understatement from Intent. This is the common
case for a diver who logs deco dives by hand, and it is why the left-out note
exists. A cylinder unresolved only because its **size** is unknown leaves just
that cylinder out, since the others' windows are still right.

### The figure

For each dive in scope and each group with at least one counting cylinder:

- **Time:** depth-corrected minutes (minutes times mean ambient pressure over
  the time, as `calculateCylinderSac` computes it). For cylinders with switch
  windows, the minutes of the **union** of their windows, so a sidemount pair
  on a shared window counts its time once while two stages breathed one after
  the other add theirs. For cylinders timed by recorded durations, the
  recorded seconds, with a matched pair taking the longer of the two rather
  than their sum (they were breathed in turns). Both kinds on one dive cannot
  happen: `calculateCylinderSac` ignores recorded durations once a switch is
  known.
- **RMV lane:** the group's surface litres under the diver's gas model (real
  or ideal), divided by the time.
- **SAC lane:** the same litres divided by the reference cylinder's volume
  (the group's first counting cylinder by order), divided by the time (my
  call). That is how `calculateCylinderSac` arrives at `sacRate`, so the lane
  matches the dive detail. It does **not** match the main SAC trend, which
  adds raw bar drops (`referencePressureDrop`); the two can differ by a few
  percent at real gas, and that difference is accepted and noted in the user
  docs. With no known size (a lone cylinder, or a matched pair), raw bar drop
  over the time, as `calculateCylinderSac`'s fallback does.
- A group with one counting cylinder must equal that cylinder's `sacRate`
  (SAC lane) and `rmv` (RMV lane) from `calculateCylinderSac` on the same
  inputs. That is the agreement test.

The remaining inputs are `calculateCylinderSac`'s own:

- The pressure drop from the tank's pressure series when it shows one over the
  windows, else the logged start and end pressures.
- Mean depth over the windows from the profile, else the dive's stored average
  depth when there is no profile.

Whether the builder aggregates from `CylinderSac` rows or pulls a shared
lower-level helper out of `calculateCylinderSac` is the builder's choice, so
long as the agreement test holds and the dive detail keeps its current output.

## Scope of dives

- Open-circuit groups use the consumption rate scope
  (`DiveStatsScope` `consumptionRate`): no CCR, no SCR, no gauge dives, no
  dives ticked "Exclude from gas statistics". This drops SCR dives from the
  by-role figures, which they fed until now (my call): an SCR's supply drop is
  not an open-circuit rate, and putting it on the Bottom gas line is the same
  mixing this issue reports.
- The Bailout group's CCR part uses the `gas` scope restricted to
  `dive_mode = 'ccr'`, as `getCcrGasUsePerDive` does, so the exclude tick still
  applies.
- The page's filter and saved dive group (`insightsFilterProvider`) and the
  current diver apply, as on every other card.
- On a dive consolidated from two computers, only the primary source's
  cylinders count (`tankOwnedByPrimary`), as for the CCR rates.

## Bailout

On a CCR dive, `ccrDiveUse` already returns, per cylinder, the bailout windows
and the gas lost in them (`bailoutWindows`, `bailoutLiters`, `bailoutBar`). The
Bailout line's point for that dive is the open-circuit rate over those windows:
litres (RMV lane) or bar of the reference cylinder (SAC lane), divided by
depth-corrected minutes of the union of the bailout windows, with depth from
the profile over those windows. A CCR dive with no bailout adds no point.

A `bailout` cylinder breathed on an open-circuit dive (rare) adds its point to
the same line by the open-circuit rule above.

This inherits the known limits of `classifyCcrGasChanges` that PR #4135
documents: a bailout onto a cylinder marked Diluent reads as staying on the
loop, and a return to the loop onto a cylinder not marked Diluent reads as more
bailout. The card does not try to fix that.

The Bailout line is self-contained: if it proves costly, it can ship in a
second PR after the open-circuit groups.

## The card

The "SAC by tank role" card becomes "Consumption by cylinder role", a
`TrendChartSection` (my call: replacing the averages list rather than adding a
second card that shows the same numbers twice).

- **Header:** each group's average over the dives in view, with its colour,
  like the Rebreather gas use card's header. The average is the mean of the
  per-dive points, matching `CcrGasUseTrend`.
- **Chart:** the primary series is Bottom gas, or the first group with data
  when there is none. The others are `secondarySeries`. The fit, the rolling
  mean and the range picker read the primary series, as on the CCR card.
  `pointLabel` names the primary line in the tooltip.
- **Colours:** one per group, distinct from each other in both themes and from
  the rolling mean's amber and the CCR card's blue and green. Exact colours are
  the builder's call.
- **Dots open dives:** `onDiveSelected` pushes `/dives/<id>`, like the other
  trend cards. `docs/user/statistics.md` currently says SAC by tank role does
  not open dives; that line changes.
- **Left-out note:** under the chart (the section's `footer`), when some dives
  in view left every group because a stage, deco or pony cylinder lost gas
  with no switch, one line says how many and why ("N dives with a stage or
  deco cylinder have no gas switches, so they are left out"). Size-only
  exclusions are not counted here; they drop one cylinder, not the dive.
  Wording is the builder's, in plain language, through ARB with all locales.
- **Empty state:** the card's existing empty message when no group has data.
- The lane toggle on the page switches the card like every other gas card.
- A new `TrendChartIds` entry for the card's settings.

## The planner default

`loggedAverageSacProvider` moves from `getSacVolumeByTankRole` to the Bottom
gas group's RMV average from the new calculation (my call). For a diver who
logs deco dives with switches, the planner's "from your log" default rises to
their real bottom gas rate. A diver who logs deco dives without switches loses
those dives from the default (see When a dive leaves every group). For a
single-cylinder diver it moves a little: the depth term changes from the
computer's reported average depth to the profile's time-weighted mean, and the
time term from runtime to the same runtime. This is a visible change and goes
in the PR summary, with the before and after default on the local logbook.

Once nothing calls them, `getSacVolumeByTankRole` and
`getSacPressureByTankRole` are removed, with their tests moved to the new
calculation.

## Performance

The CCR card already runs a Dart calculation over every CCR dive in chunks
(`InsightsRepository._diveChunks`, `getDivesByIdsWithoutSamples`,
`getGasSwitchesForDives`, `getDisplayedTankPressuresForDives`). This card does
the same over every open-circuit dive in scope, which is most of a logbook,
and needs depth during each window, which the lean dive read does not carry.

- **Depth source (my call):** every dive with a profile reads its depth from
  `getBatchProfileSummaries` (downsampled to at most 120 points, decoded on a
  background isolate), including single-cylinder dives. The stored
  `avg_depth` is the computer's own reported average on downloaded dives, not
  the time-weighted profile mean the dive detail uses, so a shortcut through
  it would break the agreement goal on the most common dive. Only a dive with
  no profile uses the stored average, as the dive detail does.
- The dive detail uses full samples, so the two can differ slightly. The
  agreement test runs on the same profile for both, and a separate test pins
  that the 120-point mean stays within a small tolerance of the full one on a
  realistic deco profile with short switch windows.
- Measure the card's load on the largest local logbook before and after with
  `PerfTimer`, and note it in the PR. If it is noticeably slower than the
  other gas cards, a per-dive cache on the `deco_classification_cache` pattern
  (keyed by an inputs hash) is the follow-up, not part of this change.

## Constraints

- New repository code goes in a new part file beside
  `insights_repository_ccr_gas_use.dart`; `insights_repository.dart` is over
  3000 lines and must not grow.
- The calculation lives in domain code with no database access, so it can be
  tested on hand-built dives and run against a real database in one
  integration test, as #4135 did for `ccrDiveUse`.
- Units follow the active diver's settings (pressure and volume units, the SAC
  or RMV lane).
- New strings go through the ARB files for every locale; run the l10n
  staleness check.
- Run `test/architecture/` and `test/shared/` after adding files.
- CI runs tests under `TZ=Australia/Sydney`; dive dates come back as UTC.
- `docs/user/statistics.md` is updated: what the card shows, that sidemount
  counts as bottom gas, that a dive with a stage or deco cylinder needs gas
  switches to count, that rebreather dives feed only the Bailout line here,
  that the card's SAC can differ by a few percent from the main SAC trend
  (real gas against raw bar), and that dots open dives. Two existing lines
  change: line 66 (by-role does not open dives) and line 151 (SCR dives count
  toward consumption by tank role).

## Known limit: role labels

Groups follow the role on each cylinder. Downloads tag any open-circuit gas
below 41% O2 as `backGas` (`parsed_tank_resolver.dart`), and a cylinder added
by hand defaults to `backGas`, so an EAN32 stage or a 21/35 travel gas often
arrives as back gas and joins Bottom gas. With switches its time joins the
union, so the Bottom gas point becomes the blended figure the main trend
already shows; the Stage line stays empty. This design accepts that (my call):
the role is the diver's own statement, the dive detail groups the same way,
and fixing a label fixes the chart. A guard (for example, two backmount
cylinders of different mixes that are not a matched pair) is a possible
follow-up, not part of this change.

## Tests the builder must write

- One-cylinder group equals `calculateCylinderSac` for that cylinder, both
  lanes, with and without a pressure series, with and without a profile.
- Back gas plus deco with switches: each group's rate uses its own window and
  depth; neither uses the whole dive.
- Deco cylinder that lost gas with no switch: the dive adds no point to any
  group, Bottom gas included, and is counted in the left-out number.
- Deco cylinder with a recorded duration and no switch: same as above.
- Back gas plus a stage of unknown size with switches: Bottom gas keeps its
  point; Stage has none; the stage's window does not join anything; the dive
  is not in the left-out number.
- Sidemount pair on a shared window: Bottom gas time is counted once and the
  litres of both cylinders add.
- Sidemount pair timed by recorded durations: the longer duration, not the
  sum.
- Two stages breathed one after the other: their time adds.
- SAC lane at the real gas model: a one-cylinder group equals `sacRate`, not
  the raw bar figure.
- CCR dive: no open-circuit group gets a point; with a recorded bailout the
  Bailout line does, and without one it does not.
- SCR and gauge dives and "Exclude from gas statistics" dives add nothing to
  the open-circuit groups.
- Consolidated dive: only the primary source's cylinders count.
- Planner default equals the Bottom gas RMV average.
- Widget test of the card: one line for a single-group diver, several lines
  and the left-out note for a technical diver, dot tap opens the dive, lane
  toggle switches units.

## Left to the builder

- Colours, layout details of the header, exact strings.
- How the calculation is factored out of `calculateCylinderSac`, within the
  agreement rule above.
- Chunk sizes and the exact downsampling tolerance in the depth test.
- Whether the Bailout line ships in the same PR or a second one.

## Calls I made (the maintainer skipped the questions)

- Sidemount left and right fold into Bottom gas.
- Pony gets its own line when breathed.
- SCR dives leave the by-role figures.
- The averages list is replaced by one trend card with averages in its header.
- The planner's logged default moves to the new Bottom gas figure.
- Every dive with a profile uses the 120-point profile summary for depth;
  only profileless dives use the stored average.
- CCR bailout gets a line on this card.
- The SAC lane follows the dive detail (gas model litres over the reference
  volume), not the main trend's raw bar.
- A stage, deco or pony cylinder that lost gas without a switch takes the
  whole dive out of every group, Bottom gas included.
- A stage, deco or pony cylinder timed only by a recorded duration is treated
  as having no switch.
- A cylinder whose size is unknown drops out with its time; the rest of the
  dive still counts.
- Groups follow the cylinder's role as logged, mislabels included.
