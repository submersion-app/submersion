# CCR gas use rates

Issue: #4082. Release: v1.8.4.

## Intent

A CCR diver wants to know how fast they used oxygen and diluent on a dive, and
what is typical for them. Today they work it out by hand: volume used, divided
by time. The Cylinders card gives them nothing for the O2 supply and a
misleading RMV for everything else.

Three facts in the code shape this:

- `tankUsageWindows` gives a cylinder breathing time only if it is back gas,
  sidemount, or the target of a gas switch. An O2 supply is never switched to,
  so `calculateCylinderSac` skips it and the card loses its "Gas used" line as
  well as its rate. A cylinder marked Diluent with no switch goes the same way.
- RMV divides by ambient pressure because open-circuit breathing scales with
  depth. O2 on a loop is metabolic and does not, and diluent use follows volume
  changes, not breathing. So the reporter's plain volume over time is the right
  sum, and RMV is the wrong one. The issue's `RMV 1.5 L/min` on a sidemount
  cylinder that lost 375 L shows the problem.
- Issue #3673 already took rebreather dives out of headline SAC and out of SAC
  and RMV averages, trends and records, for this same reason. The per-cylinder
  figure is the one place that decision never reached, and the by-role
  statistics card kept its diluent and oxygen rows on purpose.

The reporter's dive adds a wrinkle: the cylinders feeding the loop are logged as
Sidemount Left and Right, not Diluent, and for some rebreathers diluent and
bailout are one cylinder. Hiding a rate by role does not help them.

How often: only CCR dives. Most divers never see this, which is why the
statistics hide themselves when there is nothing to show. For a CCR diver it is
every dive.

## Goals

- Every cylinder on a CCR dive that lost gas shows a rate on the Cylinders card.
- Gas lost on the loop reads as plain volume per minute of loop time, with no
  depth correction and no bailout time.
- Gas lost after a recorded bailout reads as ordinary RMV over the bailout.
- O2 and diluent cylinders get their "Gas used" line back.
- Gas statistics show O2 and diluent rates per dive over time, with averages.
- The card and the statistics agree on one dive, because they share one
  calculation.

## Non-goals

- SCR dives. They keep today's behaviour everywhere, including the by-role card.
- Headline SAC and RMV on a rebreather dive. They stay blank, per #3673.
- Records (best and worst) for loop gas, list or table columns, exports, PDFs.
- Detecting O2 flushes. The existing "exclude from gas statistics" tick on a dive
  is how a diver leaves one out.
- Guessing or correcting a cylinder's role. No Data Quality prompt, no role
  change.
- Any schema, sync or stored-value change. Everything here is computed on read.

## Anti-goals

- The card and the statistics showing different numbers for one dive.
- A loop figure divided by depth.
- Bailout time counted in loop time.
- A gas statistics page that shows an empty rebreather card to an open-circuit
  diver.
- An SCR dive, or an open-circuit dive, changing in any way.

## Decisions the maintainer made

1. Option A: the rate follows when the gas left the cylinder, not the cylinder's
   role. Any cylinder can show a loop rate, a bailout RMV, or both.
2. Statistics are in scope.
3. Statistics use the combined layout: one "Rebreather gas use" card with O2 and
   diluent averages above one chart carrying both lines (mockup layout B).
4. "Loop use" as the label, and the Diluent and O2 Supply rows leaving the
   by-role card, were shown in the mockups and not objected to.
5. A cylinder not marked as loop gas needs more than 20 bar lost on the loop to
   count, so an unused bailout that only cooled does not read as diluent use.
6. A return to the loop onto a cylinder not marked Diluent stays a known limit.
   The feature follows the existing timeline, so the card always agrees with the
   profile.

7. "Gas used" on the Cylinders card follows the diver's gas model on every dive,
   not only CCR ones. It was always plain bar times litres while the rates
   followed the model, which a loop rate beside it made visible: at the default
   real-gas setting 371 L over 60 minutes read as 5.4 L/min. This changes the
   figure on open-circuit dives too, and is what #828 set out to do.

## Calls made while writing this

These were not discussed; check them while reading.

- Statistics read pressure series for every CCR dive, not only those with a
  bailout, because the card uses a series whenever there is one and the two must
  match.
- A switch in the first 60 seconds of the dive is ignored when building the
  timeline: it names the starting gas, and a dive does not begin bailed out.
- A cylinder holding pure O2 counts toward the O2 line whatever its role, not only
  one marked O2 Supply.
- CCR dives leave the by-role card entirely, not just its two loop rows. See "The
  by-role card".
- The new card sits between the by-role card and the records.

## The calculation

One pure domain function, used by both the card and the statistics. Suggested
home: `lib/features/dive_log/domain/services/ccr_cylinder_use.dart`, beside
`ccr_gas_schedule.dart` and `ccr_bailout_timeline.dart`.

Input: the dive's tanks, gas switches, resolved pressure series, dive end, the
profile (for depth during bailout), the dive environment, and the gas model.
Output, per cylinder: litres lost on the loop, loop rate, litres lost on
bailout, bailout seconds, and bailout SAC and RMV.

It applies only when `dive.diveMode == DiveMode.ccr`.

**The timeline.** The dive runs from 0 to the same dive end
`calculateCylinderSac` uses. `classifyCcrGasChanges` gives the bailout periods:
each runs from an `openCircuit` change to the next `diluent` change or the dive
end. A change at or before `startingSwitchGraceSeconds` is dropped first: it
names the starting gas, and downloads already skip that switch while a file
import may not. Loop time is everything else. No switches means all loop time.

**Where a cylinder's gas went.**

- *With a usable pressure series:* the drop across the loop periods is loop gas,
  and the drop across the stretches of bailout this cylinder was breathed is
  bailout gas. A cylinder cooling during another's bailout gave nothing up. A
  series showing no
  drop falls back to the logged pressures, as `calculateCylinderSac` does
  (issue #3373). Transmitter dropouts must not count as drops; reuse the rule in
  `_withoutDropouts` in `ccr_bailout_timeline.dart` rather than copying it.
- *With only logged start and end pressures:* the drop cannot be split, so one
  cylinder gets one figure. A missing logged pressure is filled from the series
  the way `CylindersCard._resolveTankPressures` does. A cylinder the diver bailed
  onto (its `tankUsageWindows` overlap a bailout period, which also covers a
  matched sidemount pair sharing one switch) counts it all as bailout gas. Every
  other cylinder counts it all as loop gas. A cylinder whose `ccrCylinderRole` is
  `oxygenSupply` or `diluent` is always loop gas here.

**The minimum drop.** A filled cylinder loses pressure as it cools: an 11 L
bailout filled warm drops about 13 bar in 5 C water without being touched, which
over an hour would read as 2.5 L/min. So a cylinder whose `ccrCylinderRole` is
neither `oxygenSupply` nor `diluent` has no loop gas at all unless its loop drop
exceeds 20 bar, the same value as `kBailoutMinOcDropBar`, in a constant of its own
beside that one. Cylinders marked as loop gas have no minimum.

**The figures.**

- Loop rate: loop gas in surface litres, from `gasVolume` under the configured
  gas model, divided by total loop minutes. Null when there is no loop gas, when
  there is no loop time, or when `consumptionVolume` knows no size.
- Bailout SAC and RMV: the existing `_zCorrectedSacRate` calculation over the
  bailout gas, the bailout seconds that cylinder was breathed, and the mean depth
  across them. Reuse it; do not write a second one.

**Known limits.** `classifyCcrGasChanges` decides the timeline from the role of
the cylinder switched to, and only a Diluent-role cylinder means the loop. This
feature follows it, so the card always agrees with the profile and the
decompression schedule, and it inherits two limits:

- A bailout onto a cylinder marked Diluent reads as staying on the loop, so that
  gas and time count as loop use. Marking the cylinder Sidemount or Bailout
  shows the split for a bailout that lasts to the end of the dive.
- A return to the loop onto a cylinder not marked Diluent reads as more bailout,
  so the rest of the dive counts as bailout. A real change of diluent onto such a
  cylinder does the same. It takes a bailout and a return on a non-Diluent loop
  cylinder together, so it should be rare. A shared cylinder cannot have both
  directions right with one role today.

## The Cylinders card

`calculateCylinderSac` keeps its open-circuit path untouched. On a CCR dive,
every tank gets a `CylinderSac` row, including those `tankUsageWindows` skips, so
the O2 supply gets its "Gas used" line. Rates come from the function above.

Each row's detail line, after "Gas used":

- `Loop use 6.3 L/min` when there is a loop rate. It shows whatever the diver's
  SAC, RMV or both preference is: it is a third figure, not one of those lanes.
- The usual SAC and RMV lines, following the preference, when there is bailout
  gas.
- Neither when there is no loop gas and no bailout gas. Today's `RMV 0.0` goes
  away: the issue's Left cylinder, which lost 1 bar, keeps `Gas used 4 L` and
  shows no rate. The mockup drew a small rate there; the minimum drop replaced it.

`Loop use` is formatted through `UnitFormatter.formatRmv`, so it follows the
diver's volume unit. A cylinder of unknown size shows no rate, as it shows no
RMV today.

MOD, MND and everything else on the row stay as they are.

## Gas statistics

A new "Rebreather gas use" card on the Gas insights page, between the by-role
card and the records. Its subtitle says it is per minute on the loop and leaves
out bailout time.

- **Scope:** dives in the page's filter, `dive_mode = 'ccr'`, under the `gas` stats
  variant of `DiveStatsScope`, not `consumptionRate`, which excludes rebreather
  dives. So the existing exclusion tick applies.
- **Per dive:** O2 is the loop gas of cylinders whose `ccrCylinderRole` is
  `oxygenSupply` or that hold pure O2 (99% or more, the test `ccrCylinderRole`
  uses), summed, over the dive's loop minutes. Diluent is the loop gas of every
  other cylinder, summed, over the same minutes: past the minimum drop, anything
  else leaving a cylinder on the loop went into the loop, and this is what puts
  the reporter's sidemount cylinders in the right line. A cylinder of unknown size
  adds nothing, as in `getSacVolumePerDive`. A dive with nothing for a line has no
  point on it.
- **Averages:** the mean of the per-dive rates, one tile each for O2 and diluent,
  over every dive in scope, not the chart's zoom window.
- **Chart:** `TrendChartSection` with a new `TrendChartIds` entry and two new
  optional parameters: secondary series, passed to `DiveTrendChart`, and a
  widget above the chart for the tiles. O2 is the primary series, diluent the
  secondary, so each has its colour and is named in the tooltip. Tapping a point
  opens the dive on either series, which `DiveTrendChart` already does. Its
  trend controls come along, and the fitted line and rolling mean follow the
  primary (O2) only, as they do for any secondary series.
- **Lanes:** the page's SAC and RMV selector does not affect this card.
- **Empty:** the card does not show at all when no dive in scope has a point.

The data goes through a new `InsightsRepository` method and provider following
`getSacVolumePerDive` and `sacTrendProvider`. It feeds the shared function the
same inputs the card has, so one dive cannot read differently in the two places.
It reads CCR dives' tanks, switches (`getGasSwitchesForDives`) and pressure series
in bulk for every CCR dive in scope. `getTankPressuresForDives` keeps every
source's series for the exports, while the card reads only the primary source's,
so this read applies `selectTankSeriesPerSource` per dive, as
`getTankPressuresForDive` does. CCR dives are a small share of a logbook, and the
bulk reads run one statement per chunk of ids rather than one per dive.

## The by-role card

CCR dives leave this card: `getSacVolumeByTankRole` and
`getSacPressureByTankRole` exclude `dive_mode = 'ccr'`. Removing the two rows
alone would leave a CCR dive's back gas and sidemount cylinders in other rows,
carrying the same depth-corrected, whole-dive sum, and `backGas` here seeds the
planner's default SAC in `plan_canvas_providers.dart`. SCR dives stay, so a
Diluent row can still appear for them.

This reverses the part of #3673 that kept these rows; the doc comments on both
methods and on the `consumptionRate` variant in `dive_stats_scope.dart` change to
say why.

## Copy

All new text goes through ARB in every locale. New strings: `Loop use`, the card
title and subtitle, and the tile labels. German uses its existing gas terms, not
"SAC" (`test/l10n/german_sac_terminology_test.dart`).

## Left to the builder

- The exact shape of the result type, and whether it extends `CylinderSac` or
  sits beside it.
- How the tiles are laid out, within the mockup's look.
- The diluent line's colour, as long as the two lines are clearly different in
  light and dark.

## Testing

- The function: no bailout, one bailout, a return to the loop onto a Diluent
  cylinder, a return onto a Sidemount cylinder (the known limit), a switch in the
  first 60 seconds, a shared cylinder with a series, a shared cylinder with logged
  pressures only, an O2 supply with a series across a bailout, a matched pair
  sharing a switch, unknown volume, a dropout in a series, an unbreathed bailout
  losing under 20 bar, a Diluent cylinder losing under 20 bar, and an SCR or
  open-circuit dive giving nothing.
- The card: the issue's dive, a split cylinder, each SAC, RMV and both setting,
  imperial units.
- The statistics: a sidemount cylinder landing in Diluent, a pure O2 Sidemount
  cylinder landing in O2, an excluded dive staying out, SCR and open-circuit dives
  staying out, the card hiding when empty, a multi-source dive using the primary
  source's series, and one dive's figures matching the card's.
- The by-role queries: CCR out, SCR in, open circuit unchanged.
