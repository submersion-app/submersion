# Statistics trend charts: per-dive values, selectable span, optional smoothing

Design for issue [#299](https://github.com/submersion-app/submersion/issues/299),
"Statistics: trend plots make no sense statistically".

Date: 2026-08-27
Branch: `worktree-issue-299-statistics-trends`

## Problem

Four charts present a monthly aggregate as if it were a progression:

| Chart | Page | Current aggregate |
| --- | --- | --- |
| Maximum Depth Progression | Progression | `MAX(max_depth)` grouped by month |
| Bottom Time Trend | Progression | `AVG(bottom_time / 60)` grouped by month |
| SAC Rate Trend | Gas | mean of per-dive SAC, grouped by month |
| Weight Trend | Equipment | `AVG(amount_kg)` grouped by month |

A fifth, "Water Temperature by Month" on the Conditions page, is a different
problem: it collapses every year of history into twelve calendar buckets, so a
diver who travels between cold and warm water sees a meaningless middle value.

The reporter's ask, in their words: individual dive values rather than averages,
a selectable time span with presets and a custom interval, and averaging demoted
to an option.

Three defects sit underneath the feature request:

1. A hardcoded `DateTime.now().subtract(const Duration(days: 365 * 5))` is
   repeated in five separate repository methods
   (`statistics_repository.dart` L210, L343, L845, L892, L2117). It is not a
   parameter and not derived from any filter.
2. The statistics filter's date range is injected as
   `AND dives.id IN (SELECT id FROM dives WHERE ...)`, which stacks on top of
   that cutoff. The filter can only narrow the window, never widen it, so
   **"lifetime" is currently unreachable** for all four progression charts.
3. `TrendLineChart` plots `FlSpot(index.toDouble(), value)`
   (`stat_charts.dart` L165-168). X is the array position, not the date. A
   three-month gap and a three-week gap render identically, and months with no
   dives occupy no width.

Defect 3 is why simply removing the `GROUP BY` would not work. Per-dive points
on a positional axis would draw a liveaboard week and a quiet year at the same
scale, which is a worse distortion than the monthly average it replaced.

## Decisions

Settled during design, with the reasoning that produced them.

**Span is global, owned by the existing statistics filter.** Submersion already
shipped a whole-tab filter in #453; `statisticsFilterProvider` holds a
`DiveFilterState` whose first two fields are `startDate` and `endDate`. Adding a
second, per-chart notion of "date range" would create two controls that
inevitably disagree. The presets the reporter asked for become presets on the
existing sheet.

**Aggregation is per chart.** Span decides what data is in scope, which should
be consistent across a page. Aggregation decides how one metric is drawn, which
is a rendering choice and reasonably differs between a weight series with a few
dozen points and a SAC series with two thousand.

**Raw per-dive is the default.** This is the headline request.

**Charts draw a scatter plus a fitted trend line.** Dots alone make direction
hard to read; dots joined by a line imply continuity between dives months apart.
A fitted overlay answers "am I progressing?" without lying about what happened
in between.

**Both fits are available, rolling mean by default.** A straight least-squares
line reports a single direction for an entire history. The common dive career
shape, ramp up, a technical period, then a settled return to recreational
depths, makes a straight fit report "still going deeper" about someone who
peaked years ago. The rolling mean follows the real shape. The straight fit is
kept as an opt-in overlay because it yields a stateable rate ("+4.4 m/yr") that
a rolling mean cannot give.

**The rolling window counts dives, not calendar time.** A six-month window would
compute some points from forty dives on a liveaboard and others from none.
Counting dives puts equal evidence behind every point on the line, which matters
because real logbooks are heavily clustered.

**Controls live on one row beneath the chart.** A compact dropdown plus two
tappable legend entries. The cost is one line per card regardless of how many
controls a card carries, and the legend doubles as the colour key so the
overlays never need explaining. A dropdown rather than chips because further
modes (quarterly, yearly) would not fit a chip row.

**An aggregated bucket draws its mean with a min/max band.** Smoothing must not
re-hide the spread that this issue is about.

**The seasonal temperature chart is kept, not replaced.** The reporter concedes
it shows real variation for a diver who stays in one region. It is retitled so
its all-years collapse is explicit, and a proper temperature trend chart is
added beside it.

**Settings are in-memory for the session, not persisted.** This matches
`statisticsFilterProvider`, which is a plain unpersisted `StateProvider`.

## Architecture

### Domain: `lib/features/statistics/domain/trend_aggregation.dart`

Pure Dart. No Flutter imports, no database imports. This is where the
statistical behaviour lives and where it is tested.

`TrendDataPoint` is currently declared in `statistics_repository.dart` L32-43.
It moves into this domain file, and the repository imports it from there. A pure
domain module must not import the data layer.

```dart
enum TrendAggregation { none, weekly, monthly }

class TrendBucket {
  final DateTime date;   // bucket start, or the dive's own date when none
  final double mean;
  final double min;
  final double max;
  final int count;
}

class LinearFit {
  final double slopePerDay;
  final double intercept;
  double get perYear => slopePerDay * 365.25;
}

List<TrendBucket> aggregate(List<TrendDataPoint> points, TrendAggregation mode);
List<TrendDataPoint> rollingMean(List<TrendDataPoint> points, {int window = 21});
LinearFit? linearFit(List<TrendDataPoint> points);
```

`aggregate` with `none` returns one bucket per dive, with `mean == min == max`
and `count == 1`, so the widget has a single uniform shape to render.

`rollingMean` is a centred mean over `window` neighbouring dives by index. At
the ends the window truncates rather than padding.

`linearFit` returns null below 5 points, so a confident line is never drawn
through four dives. `rollingMean` returns an empty list below the same
threshold.

Both fits are always computed from the **raw per-dive points**, never from the
buckets, in every aggregation mode. Fitting a rolling mean over monthly means
would smooth twice, and switching the dropdown would move the trend line, which
would wrongly imply the underlying trend had changed.

Bucket keys derive from `dive_date_time` read as a wall clock, matching the
`/ 1000, 'unixepoch'` convention used with no `'utc'` modifier throughout the
repository.

### Data: `statistics_repository.dart`

Five methods lose their `GROUP BY` and their hardcoded cutoff, and are renamed
to say what they now return:

| Was | Becomes |
| --- | --- |
| `getDepthProgressionTrend` | `getDepthPerDive` |
| `getBottomTimeTrend` | `getBottomTimePerDive` |
| `getWeightTrend` | `getWeightPerDive` |
| `getSacVolumeTrend` | `getSacVolumePerDive` |
| `getSacPressureTrend` | `getSacPressurePerDive` |

Each returns `List<TrendDataPoint>` ordered by `dive_date_time`, scoped only by
`diverId` and the `filter` threaded through the existing `_diveFilter` helper.
The `Duration(days: 365 * 5)` constants are deleted outright.

`getSacVolumePerDive` is close to free: `getSacVolumeTrend` already computes a
per-dive SAC value (L297-307) and only then buckets it in Dart (L309-325). The
change is to stop at the per-dive step.

`getWaterTempPerDive` is added for the new temperature trend.

`getTemperatureByMonth` is untouched and keeps feeding the seasonal chart.

The existing `catch (e, stackTrace) { _log.error(...); return []; }` error
handling is preserved on every method.

`TrendDataPoint.label` is currently built by `_monthAbbr` (L2531-2547) from a
hardcoded English month array. Per-dive points no longer need a month label, and
axis labels are formatted at render time from the date, so this English array
stops being used by the affected charts.

### Presentation: providers

The five existing `FutureProvider`s keep their names and their
`ref.watch(statisticsFilterProvider)`, returning per-dive points instead of
monthly ones. `waterTempTrendProvider` is added.

Per-chart aggregation and overlay state lives in a separate provider family
keyed by chart id, so toggling a control re-renders without re-running the
query.

Before altering any provider, grep its consumers across all of `lib/`, not just
`features/statistics/`. #453 silently rescoped the marine-life species detail
page by making a shared provider filter-aware; the same trap applies here.
`statistics_providers_all_test.dart` is the test that fails first when a
provider is added or renamed.

### Presentation: `DiveTrendChart`

New widget at
`lib/features/statistics/presentation/widgets/dive_trend_chart.dart`.

`TrendLineChart` and `MultiTrendLineChart` are left untouched: the former still
serves Cumulative Dive Count and charts outside this scope, the latter still
serves the seasonal temperature chart.

X values are `date.millisecondsSinceEpoch.toDouble()`. This is the change that
makes gaps read as gaps. It requires a date-tick helper beside the existing
`ChartAxis`, choosing year, quarter, or month ticks by span so a one-year view
does not label every tick with the same year. Y bounds continue to use
`ChartAxis.forTrend`, which already solves the grid-line alignment from #219.

Layers, composed into a single fl_chart `LineChart`:

| Layer | Raw mode | Weekly or monthly mode |
| --- | --- | --- |
| Data | dots via `barWidth: 0` plus `FlDotData(show: true)` | mean line, plus invisible min and max series filled with `BetweenBarsData` |
| Rolling mean | drawn, default on | drawn, default on |
| Linear rate | opt-in, default off | opt-in, default off |

`LineChartData.betweenBarsData` and `BetweenBarsData` are confirmed present in
the resolved fl_chart 1.2.0 (`line_chart_data.dart` L73, L616).

fl_chart's `ScatterChart` is deliberately not used: it cannot also hold the
rolling-mean and rate line series, and every layer must share one set of axes.

Degenerate cases:

- Below the minimum point count, fits return null and are not drawn.
- A bucket containing one dive produces a zero-height band.
- An empty result keeps the existing empty-state card.

Touching a point shows a tooltip with the dive's date and value. Navigating to
the dive from a tooltip is **not** in scope.

Large logbooks are not downsampled in this change. Whether 2000 dots is a
problem should be measured against a real logbook rather than pre-optimised. If
it does need mitigation, the fix is local to this widget.

### Presentation: `TrendControlStrip`

One row beneath the chart, in its own widget so the controls have a single set
of test keys:

- A `PopupMenuButton` rendered as "Per dive" with a caret. Not Material 3's
  `DropdownMenu`, which is a text-field-shaped widget far too heavy here. The
  compact popup pattern in `gps_track_date_filter_action.dart` is the precedent.
- Two tappable legend entries, "Rolling avg" and the rate label, which toggle
  their overlay and act as the colour key.

When the linear rate overlay is on, its legend entry shows the computed rate,
formatted in the active diver's units.

## Pages

| Page | Change |
| --- | --- |
| `statistics_progression_page.dart` | Max Depth and Bottom Time move to `DiveTrendChart`. Dives Per Year, Suit Thickness and Cumulative Count are untouched. |
| `statistics_gas_page.dart` | SAC Rate Trend moves to `DiveTrendChart`, both the volume and pressure branches. |
| `statistics_equipment_page.dart` | Weight Trend moves to `DiveTrendChart`. |
| `statistics_conditions_page.dart` | New "Water Temperature Trend" card. The existing chart is retitled "Seasonal Water Temperature" with a subtitle stating that it collapses all years. |

## Span control

`dive_filter_sheet.dart` L221-332 already offers All Time, This Year, Last 12
Months and Last Year, plus custom start and end dates. Two presets are added,
**Last 5 Years** and **Last 10 Years**, completing the list the reporter asked
for. Custom start and end already covers "custom interval".

That sheet is shared with the dive list filter, so the new presets appear there
too. This is a deliberate, accepted side effect outside the Statistics tab.

The affected detail pages have no filter affordance today: on mobile the span
must be set on `/statistics` before drilling in. Each affected page gains the
filter action on its standalone route and shows `StatisticsFilterBar` so a
scoped chart is never mysterious. In the embedded master-detail layout the list
pane already owns the filter icon, so no second icon is added there.

## Localization

New keys are needed for the three aggregation modes, the two legend labels, and
the rate label. Existing subtitles become false and must be rewritten:

- `statistics_progression_depthProgression_subtitle` ("Monthly max depth over 5 years")
- `statistics_progression_bottomTime_subtitle` ("Average duration by month")
- `statistics_gas_sacTrend_subtitle` ("Monthly average over 5 years")
- `statistics_equipment_weightTrend_subtitle` ("Average weight over time")
- `statistics_conditions_temperature_title` and `_subtitle`, retitled for the seasonal framing

All keys must be added to every locale, not only English. `arb_parity_test`
fails on a key present in English and missing elsewhere.

## Schema

None. This is entirely read-path work: no migration, no rung on the schema
version ladder.

## Testing

TDD, per the project development guide.

**Unit, `trend_aggregation_test.dart`.** The statistical core, tested without a
database or a widget pump:

- bucket boundaries for weekly and monthly, including a dive on a boundary
- mean, min, max and count per bucket
- `none` returns one bucket per dive with `mean == min == max`
- rolling mean at both ends of the array, where the window truncates
- rolling mean over clustered dates, confirming the window counts dives
- linear fit slope and `perYear` against hand-computed vectors
- null fits below the minimum point count

**Repository.** Per-dive results, ordering, and filter propagation for all six
methods. One regression test carries the weight of defect 2: **a dive eight
years old must appear with an empty filter.** It fails against today's code and
is the proof the cutoffs are gone. `statistics_repository_error_test.dart`
needs its method names updated.

**Widget.** New tests for `DiveTrendChart` (X values are dates not indices; the
band is present only when aggregated; fits absent below the threshold; the
tooltip renders) and for `TrendControlStrip` (dropdown changes mode, legend
entries toggle overlays).

**Page.** `statistics_progression_page_test.dart` and
`statistics_equipment_page_test.dart` do not exist today and are written as part
of this work. `statistics_gas_page_test.dart` and
`statistics_conditions_visibility_test.dart` need updating.
`statistics_providers_all_test.dart` must gain the new temperature provider.

## Out of scope

Named explicitly so the work does not drift:

- **#771**, SAC trend mixing open-circuit and CCR cylinders. A real defect in
  what SAC *means*, orthogonal to how it is plotted.
- **#641**, depth distribution capped at 40 m.
- **#526**, excluding shallow or short dives from statistics.
- Persisting per-chart settings across app restarts.

## Added after the design was written

Feedback on the running app pulled several things in that this document had
either excluded or never considered. Recorded here so the spec matches what
shipped:

- **Navigating from a chart point to the dive it represents**, listed above as
  out of scope. `TrendDataPoint` gained a `diveId`, every per-dive query
  selects it, and tapping a point in per-dive mode opens that dive. A bucket
  carries no id, because it stands for several dives.
- **Zoom and pan** over the time axis, matching the dive profile chart:
  wheel, trackpad, drag and pinch, plus a shared `ChartZoomControls` extracted
  from the profile legend. The viewport maths moved to
  `lib/core/ui/chart_viewport.dart` and lost its `Profile` prefix.
- **A readout matching the profile chart**: monospace label and value columns,
  every series named, drawn above the plot so it cannot cover the point it
  describes, and a full-height hover line.
- **Framed plot areas** on all four statistics chart types.
- **Denser cumulative dive count**, stepping once per dive rather than once
  per month.
- **Self-describing aggregation values** ("Every dive", "Weekly average",
  "Monthly average") and an abbreviated year on every axis label.

Two things this document proposed were dropped: pulling the date range out of
the filter sheet into the statistics top bar, and spelling the axis year only
where it changes.
