# Trend charts: collapse long gaps in diving into axis breaks

Date: 2026-10-11
Status: approved design

## Problem

A diver took a six-year break from diving. On every per-dive trend chart
(`DiveTrendChart`) the empty years take up about half the plot, the dives on
either side are squeezed together, and after zooming in the diver still has to
pan a long way across nothing. Two more symptoms come from the same gap:

- The rolling average counts dives, not days, so its 21-dive window averages
  dives from both sides of the break and draws a flat line across the empty
  years, as if diving had continued at that level.
- On a phone-width card the year labels run together ("2014201620172018...").

Small gaps (a winter off) are fine and should stay on the real time scale.

## Goals

- A stretch with no dives longer than a diver-chosen threshold collapses into
  a narrow hatched band on the x axis, labelled with its length.
- No line (rolling average, overall trend, aggregated mean) is drawn across a
  band.
- Zoom and pan travel only over time with dives in it.
- Date labels never overlap, at any width.
- With the setting Off, or no qualifying gap, the chart is unchanged.

## Non-goals

- The older index-based `TrendLineChart` (monthly series plotted by index) is
  not changed; it has no time gaps to collapse.
- No per-chart threshold. One synced per-diver setting drives every chart.
- The overview strip is not hatched.

## Setting

| Choice | Stored months | Meaning |
| --- | --- | --- |
| Off | 0 | Continuous axis, as before this change |
| 6 months | 6 | Collapse gaps longer than 6 calendar months |
| 1 year (default) | 12 | Collapse gaps longer than 12 calendar months |
| 2 years | 24 | Collapse gaps longer than 24 calendar months |

- Column `diver_settings.trend_gap_collapse_months`, INTEGER NOT NULL DEFAULT
  12, added by a migration rung at schema v281. This is a new setting, not a
  changed default, so every diver (existing ones included) starts at 1 year.
- Synced like every other diver setting: table column, rung, sync serializer
  arm, `diver_settings_repository`, conflict-catalogue entry,
  `AppSettings.trendGapThreshold` (a `TrendGapThreshold`) with `copyWith`, a
  notifier setter and a `trendGapThresholdProvider`.
- Domain type `TrendGapThreshold { off, months6, year1, years2 }` with its
  month count and conversion from the stored int. Any other stored or synced
  value falls back to `year1`.

### Where the diver changes it

- Settings > Appearance > General: a tile "Collapse gaps in trend charts"
  with a one-line explanation and the current choice in a trailing dropdown,
  the same picker the Map style tile beside it uses. The tablet and desktop
  settings pane renders the same `AppearanceGeneralTiles`, so it gets the tile
  too.
- The Range menu of every `TrendChartSection`: below the range presets, a
  divider, a "Collapse gaps" heading and four checked items (Off, 6 months,
  1 year, 2 years). Picking one writes the same synced setting.
- Charts without a Range menu (cumulative dives, Focus results, the equipment
  condition-trend card) follow the setting.

## Architecture

### `TrendTimeScale` (new, `lib/features/insights/domain/`)

Pure Dart, no Flutter. A piecewise-linear map between dates and chart x
positions.

- Built from every date the chart plots (raw dives of every series and, when
  aggregated, the bucket dates) and a `TrendGapThreshold`.
- A break is any two consecutive plotted dates further apart than the
  threshold, measured in calendar months: with 12 months, a gap is one where
  the later date is after the earlier date plus 12 calendar months. Exactly 12
  months is not a gap.
- Between breaks (a "period") axis distance equals real time. Each break is
  replaced by a band whose width is 3% of the collapsed span (the sum of all
  periods); a date inside a break maps proportionally across its band.
- API:
  - `toAxis(DateTime) -> double`
  - `toDate(double) -> DateTime`, the inverse; exact inside periods
  - `breaks`: each with real start and end (the dives either side) and its
    axis start and end
  - `breakAt(double axisX)`: the break whose band contains the position, or
    null
  - `isIdentity`: true when Off or no break qualifies; then
    `toAxis(d) == d.millisecondsSinceEpoch` and the chart renders exactly as
    before
- Built once per data or threshold change, not on every pan.

### `DiveTrendChart`

- New parameter `gapThreshold` (`TrendGapThreshold`, default `off`), threaded
  in by each caller from the setting, as `dateFormat` is today.
- Every coordinate goes through the scale: dots, buckets, band min and max,
  rolling mean, the fit, the highlight range, the overview strip and the
  tooltip date (`toDate`).
- Lines stop at each band using fl_chart null spots inside the existing bars,
  so bar indices stay stable for tooltip labels and tap-to-open. Where a data
  bar gains null spots, the spot-index to bucket mapping skips them.
- A new overlay painter, stacked on the plot, draws each visible break as a
  diagonal-hatched band the full height of the plot, and its length ("6y 9m",
  localized) under the x axis.
- Hover or tap inside a band replaces the readout with "No dives: {start} to
  {end}", dates in the diver's date format. The pointer's axis position comes
  from the touch callback, since fl_chart reports the nearest spot rather than
  the pointer.

### Overlays

- `rollingMean` takes the breaks and computes each period separately: the
  21-dive window never reaches across a break and truncates at period edges.
- The overall trend stays one least-squares fit over every dive, so its
  per-year rate is unchanged, but it is drawn only across each period and
  visibly steps at a band.
- The aggregated mean line, and the min/max band, also stop at each band.

### Axis labels (`DateAxis`)

- Granularity (year, quarter, month, day) is chosen from the collapsed visible
  span, so the empty years no longer push a seven-year logbook to year ticks
  sized for thirteen.
- Labels are thinned by the plot's measured pixel width so neighbours never
  touch. This also fixes the overlap on a continuous long logbook.
- No date label inside a band or close enough to crowd its length label.

### Zoom, pan and Range

- `ChartViewport` fractions run over the collapsed axis, so zoom and pan never
  cross empty years. The narrowest zoom stays one week of collapsed axis.
- `TrendWindowSeater` and `trendRangeFractions` convert dates through the
  scale. Presets stay calendar-true: "Last 2 years" is two real years back
  from the latest dive; a start inside a break opens at the matching point of
  its band.
- A custom window reported after a pan holds real dates (via `toDate`), so a
  later threshold change keeps showing the same dates.

## Error handling and edge cases

- One dive, or all dives on one day: no breaks; the existing one-day widening
  applies.
- Every series empty: the existing empty state.
- Unknown stored or synced threshold: falls back to 1 year.
- A break with the viewport zoomed entirely inside one period: no band drawn.
- Bucket dates (start of week or month) earlier than the first dive of a
  period are part of the scale's input, so they never fall inside a band.

## Testing

- `TrendTimeScale`: identity when Off or no qualifying gap; one and several
  breaks; threshold boundary (exactly 12 months is not a gap, a day more is);
  `toDate(toAxis(d)) == d` inside periods; proportional mapping inside a band;
  band width; aggregated bucket dates.
- `rollingMean` with breaks: no window crosses a break; short periods
  truncate; unchanged without breaks.
- `DateAxis`: granularity from the collapsed span; width thinning leaves no
  overlapping labels on a phone-width 13-year axis; no labels in or crowding
  a band.
- Seater and `trendRangeFractions` through a scale: presets calendar-true,
  custom ranges round-trip real dates, identity scale matches today.
- `DiveTrendChart` widget tests: one band per visible break with its label;
  null spots at breaks in fit and rolling bars; "No dives" readout over a
  band; tap-to-open still opens the right dive after a break; Off unchanged.
- Settings: migration rung, sync serializer round-trip including an
  out-of-range value, repository read and write, notifier, the Appearance
  tile dialog, and a Range-menu pick writing the setting.
- Repo gates: `test/architecture/`, `test/shared/`, l10n staleness,
  `dart format`, `flutter analyze`.

## Strings

New `app_en.arb` keys for the settings tile and its subtitle, the four
choices, the Range menu heading, the band length label and the "No dives"
readout, translated into every other shipped locale in the same change.

## Screenshots

Before and after of the Progression depth chart with a seeded six-year gap at
phone and desktop widths, light and dark; plus the Range menu open and the
Settings tile, after only.
