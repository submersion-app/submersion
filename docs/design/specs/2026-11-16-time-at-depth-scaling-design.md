# Time at depth: hours and adaptive depth bands (issue #4600)

## Why

The Insights > Profile "Time at depth" chart was built for small logs. A diver
with about 1,100 hours sees five-digit minute values squeezed into a left axis
sized for four digits, and every metre below 40 lands in one "40+" bar, which
hides the spread that matters most to deep and technical divers.

## Goals

- Readable time values at any log size: minutes for small logs, hours for
  large ones.
- Depth bands that follow the diver's own data, so deep diving is broken out
  instead of lumped together.
- Round, unit-native bands for feet users (0-30, 30-60 ft), not converted
  metre edges (0-33, 33-66 ft).

## Non-goals and anti-goals

- No change to how time is credited to a depth (the per-interval, cadence
  capped sum in `series_profile_aggregates.dart` stays as it is).
- No drill-down from a bar to its dives (not offered today, not added here).
- A recreational diver's chart must not get worse: no extra empty bars below
  their deepest band, and minutes stay minutes for small logs.

## Approaches considered

- **A. The page asks for bands of a given width (chosen).** The repository
  bins samples by a band width it is given, 10 m or 30 ft (9.144 m), and
  returns seconds per band index. Edges are exact in both units.
- **B. Fine histogram regrouped on the page.** The repository returns seconds
  per 0.1 m and the page regroups. Unit-free, but 30 ft edges do not land on
  0.1 m steps, so time near a feet edge can fall into the wrong band.
  Rejected for that inaccuracy.
- **C. Hours plus a fixed deeper band list.** Ruled out: the bands should
  adapt to the data.

## Design (as decided)

**Depth bands**

- Band width is 10 m when the diver's depth unit is metres and 30 ft when it
  is feet. The provider reads the unit from settings and passes the width to
  `getTimeAtDepthRanges`, so a unit change recomputes.
- Bands run from 0 down to the deepest band that holds any time. Bands in
  between that hold no time show as zero-height bars, so the depth axis stays
  continuous.
- Bars at the deep end that round to no minutes are left off (found in
  review): a depth spike a few seconds long would otherwise stretch the chart
  with bars reading 0.
- At most 8 bars. When time exists deeper than the 8th band, the 8th bar
  becomes an open-ended band holding all time from its lower edge down:
  "70+" in metres, "210+" in feet.
- Labels are whole numbers in the diver's unit ("0-10", "60-70", "70+";
  "0-30", "180-210", "210+"), with the unit shown once on the x axis as now.
- Crowded labels (decided during the build, when seven feet bands overlapped
  at phone width): when the widest label would not fit under its own bar, at
  the reader's text size, every label shortens to the depth its band starts
  at ("0", "30" ... "180"), and the open-ended band keeps its plus ("210+").
  A marked or hovered bar still names its whole range.

**Time values**

- When the biggest bar is under 10 hours, the chart is unchanged: the y axis
  reads "min" and values read "N min".
- At 10 hours or more, the y axis reads "h" with whole-hour ticks, and bar
  values (tooltips, semantics) read as hours and minutes in the app's existing
  elapsed-time wording ("18h 20m" in English), or whole hours with grouping
  ("1,104 h") once the value is 100 h or more. A bar under an hour in such a
  chart still reads in minutes ("5 min").

## Left to the builder

- The exact shape of the repository return type and of the band-building and
  time-format helpers (keep them pure and unit tested).
- How `CategoryBarChart` takes a y-axis tick formatter and an hour-scaled
  interval, keeping every other chart that uses it unchanged.
- New l10n strings for the hour unit and formats, added to every ARB file per
  the project's l10n process.
