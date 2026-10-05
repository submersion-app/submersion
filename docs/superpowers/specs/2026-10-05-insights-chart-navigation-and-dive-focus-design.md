# Insights chart navigation and Dive focus (issue #1611)

## Problem

Issue #1611 reports that the date-axis charts in Insights (Gas, Progression,
Conditions, Equipment) can be zoomed but not scrolled, and asks for:

1. User-specified values for every date-based horizontal axis.
2. Horizontal scrolling while zoomed in.
3. More than one best and one worst gas consumption dive: the best and worst N.
4. For such a group of dives, a tabulation of what they have in common
   (temperature, depth, time of year, location, and so on).
5. A way to focus on dives meeting a threshold ("RMV above 0.75 cuft/min") and
   click through each matching dive.

### What exists today

- Every date-axis chart in Insights is one widget, `DiveTrendChart`
  (`lib/features/insights/presentation/widgets/dive_trend_chart.dart`). It
  already zooms and pans through `ChartViewport`: a mouse drag pans, a one-finger
  touch drag pans once zoomed, and the mouse wheel and trackpad pinch zoom at the
  pointer. The reporter (Windows, mouse) did not find the drag: nothing on screen
  shows where the visible window sits or that it can move, and the zoom buttons
  zoom about the middle of the visible window.
- `TrackpadZoomGestureRecognizer` reads only `panDelta.dy`, so a Mac trackpad's
  sideways two-finger swipe does nothing. A horizontal mouse wheel and
  shift+wheel are ignored.
- `MultiTrendLineChart` (Conditions, temperature by month) plots month of year,
  not dates, so it is out of scope for navigation.
- The Insights filter already has a start and end date, but it changes the data
  on every chart rather than one chart's visible window.
- The gas records card shows one best and one highest dive only.
- The query language has a `sac` field, but no Insights surface lists the dives
  matching a threshold.

## Brief

A diver with a long logbook, on any platform, can:

- find their way around a zoomed date chart and set its visible window
  precisely; and
- pick a group of dives by one metric (best or worst N, or above or below a
  value), see those dives, open any of them, and see what the group has in
  common compared with their other dives.

Constraints: values display in the active diver's units; the Insights filter
and the per-dive exclude-from-stats scope apply; new settings last for the
session only, like the existing trend chart settings; nothing changes the dive
list's own filter.

## Section 1: Chart navigation

Applies to `DiveTrendChart`, so to every date-axis chart in Insights and to the
equipment item page's condition trend card.

### Overview strip

- A slim strip under the plot, shown only while zoomed (`zoom > 1`).
- It draws every data point across the full range as a faint dot (x by date, y
  by value, normalised to the strip height) and the visible window as a
  highlighted box.
- Drag the box to pan. Drag either edge to resize the window, holding the other
  edge still (a zoom about that edge). Tap outside the box to centre the window
  on the tapped date.
- It reads and writes the chart's `ChartViewport`, so the strip, the zoom
  buttons and pointer gestures can never disagree. Viewport clamping
  (`minZoom`, `maxZoom`, bounds) is the viewport's existing behaviour.

### More pan inputs

- Shift+wheel and a horizontal wheel (`scrollDelta.dx != 0`) pan rather than
  zoom. A plain vertical wheel keeps zooming at the pointer.
- A trackpad two-finger swipe pans by its horizontal component
  (`panDelta.dx`) while its vertical component and pinch keep zooming. The
  recognizer gains an `onPan` callback; the dive profile chart and maps, which
  share it, leave `onPan` null and behave as today.
- Left and right arrow keys pan by a quarter of the visible window while the
  chart has keyboard focus (the chart becomes focusable; clicking it focuses
  it).

### Range menu

- A "Range" popup in `TrendControlStrip`: All, Last 5 years, Last 2 years,
  Last year, Last 6 months, Last 3 months, and Custom...
- A preset window ends at the latest data point in the chart and starts the
  preset span before it, clamped to the earliest point. When the data spans less
  than the preset, the preset shows everything (zoom 1).
- Custom... opens `showDateRangePicker` limited to the data's first and last
  dates and sets the window to the picked days (start of the first day to the
  end of the last).
- Picking a range sets the viewport. Panning or zooming afterwards, by any
  input, relabels the menu "Custom" while keeping the new window. Reset zoom
  returns to All.
- The choice is stored per chart in `TrendChartSettings` (session only), next to
  the aggregation and overlay settings. Charts without a control strip (the
  equipment condition card) get the strip and the pan inputs but no Range menu.
- The y axis and the fits are unchanged: data, rolling mean and linear fit stay
  computed over the whole filtered range; only the visible window changes.

## Section 2: The Dive focus page

### Entry points

- A new Insights category, "Dive focus" (`Icons.filter_center_focus`), at
  route `/insights/focus`, in the category grid on phones and the master list
  on desktop.
- A "See top 10" link on the gas records card that opens Dive focus preset to
  the gas page's lane (RMV or SAC), best 10.

### Group selector

One row, wrapping on a phone:

- **Metric:** RMV, SAC (pressure), max depth, bottom time, weight, water temp.
- **Mode:** for RMV and SAC, "Best N" (lowest values) and "Worst N" (highest);
  for other metrics, "Lowest N" and "Highest N". Every metric also has
  "Above..." and "Below...".
- **Value:** for N, chips 5, 10 and 20 plus a custom number from 1 to 999;
  default 10. For a threshold, a number field in the diver's display unit for
  the metric (cuft/min or L/min; bar/min or psi/min; m or ft; minutes; kg or
  lb; Celsius or Fahrenheit), converted to storage units before comparing.
  "Above" is strictly greater than; "below" is strictly less than. An
  unparseable or negative entry shows inline validation and keeps the previous
  group.
- The selection lives in an in-memory provider for the session.

### Results

Top to bottom:

1. **Summary line:** "12 of 148 dives, group average 0.58 cuft/min vs 0.71
   overall" (localised, units from the diver's settings).
2. **Chart:** the metric's `DiveTrendChart` (with Section 1's navigation), with
   the group's dives in the accent colour and the others faded. Tapping a point
   opens that dive.
3. **Dive list:** in rank order for N modes and newest first for threshold
   modes. Each row shows date, site, the metric value, and max depth and
   duration. Tapping a row opens `/dives/<id>`.
4. **Common factors table** (Section 3).

### Edge states

- No dives with the metric: the existing `StatEmptyState`.
- N larger than the dives available: all of them, and the summary says so.
- A threshold matching nothing: "No dives above 0.75 cuft/min", with the
  metric's overall range so the diver can adjust.
- Ties at the N cut-off break by date, newest first, so the result is stable.

### Metric sources

Each metric reuses the per-dive series the trend charts already use, so a
dive's value on this page is exactly its value on the trend chart, with the
same filter and exclusion scope:

| Metric | Repository method |
| --- | --- |
| RMV | `getSacVolumePerDive` |
| SAC (pressure) | `getSacPressurePerDive` |
| Max depth | `getDepthPerDive` |
| Bottom time | `getBottomTimePerDive` |
| Weight | `getWeightPerDive` |
| Water temp | `getWaterTempPerDive` |

Ranking and thresholds run in Dart over these series.

## Section 3: Common factors table

### Baseline

The group is compared with the dives that have the metric inside the current
Insights filter (for RMV: in-scope dives with usable tank data that are not
excluded from gas statistics), not with every dive. This keeps the comparison
about the dives that could have made the list.

### Data

A new repository method, `getFocusFactorRows({diverId, filter})`, scoped
through `_diveFilter` so the stats-scope census applies without an exemption,
returns one row per in-filter dive:

- id and date (`dive_date_time`, with `entry_time` preferred for time of day as
  the Time patterns page does);
- max depth, average depth, duration (`runtime`, falling back to
  `bottom_time`);
- water temp, visibility, current strength, water type, entry method;
- site id and name, dive type;
- gas class: trimix if any tank has helium, nitrox if any tank's O2 is above
  21.5%, otherwise air (the gas mix chart's thresholds); null when the dive has
  no tanks;
- first tank's volume (by tank order);
- lead weight (`weight_amount`);
- suit: drysuit, wetsuit with thickness in mm, or unknown, classified as
  `getDivesBySuitThickness` does; null when no suit is linked;
- solo or buddy, as `getSoloVsBuddyCount` classifies it.

Month and time of day (Night before 06:00, Morning before 12:00, Afternoon
before 18:00, Evening otherwise; the Time patterns page's buckets and clock)
are derived in Dart from the date.

A pure Dart `FocusFactorAnalyzer` (domain layer, no Flutter, no Drift) takes the
group's rows and the baseline's rows and returns the table model.

### Table

Grouped under Dive shape, Conditions, When and where, and Kit and gas.

- **Numeric factors** (max depth, average depth, duration, water temp, tank
  volume, weight): the group average and the baseline average in display units,
  with the difference ("-4.2 m"). When only some of the group recorded the
  factor, coverage shows ("9 of 12 dives").
- **Categorical factors** (visibility, current, water type, entry method,
  month, time of day, site, dive type, gas, suit, solo or buddy): the group's
  three most common values, each with the group share against the baseline
  share ("Boat: 75% vs 40%").
- **Stands out:** a numeric factor whose difference from the baseline average is
  at least half the baseline's standard deviation, or a categorical value whose
  group share exceeds its baseline share by at least 20 percentage points with
  at least 2 group dives. Standouts carry a chip in the table and are listed in
  a one-line summary above it.
- The factor that is the ranking metric is omitted: max depth when ranking by
  max depth, duration when ranking by bottom time, weight when ranking by
  weight, water temp when ranking by water temp. RMV and SAC have no matching
  factor row.
- A factor with no data in the group shows "Not recorded".
- With fewer than 3 dives in the group the table is replaced by "Choose at
  least 3 dives to compare common factors".

## Section 4: Structure, errors and testing

### Units

| Unit | Purpose |
| --- | --- |
| `lib/core/ui/chart_viewport.dart` (changed) | Helpers mapping a viewport to and from a visible fraction window, shared by the strip and the Range menu. |
| `insights/presentation/widgets/chart_overview_strip.dart` (new) | Strip painter and gestures; takes the points, a `ChartViewport` and `onViewportChanged`. |
| `insights/domain/trend_range_preset.dart` (new) | `TrendRangePreset` and a pure `windowFor(preset, dataStart, dataEnd)`. |
| `dive_trend_chart.dart` (changed), `dive_trend_chart_input.dart` (new) | The chart, with pointer, wheel, trackpad and key handling moved into the new file so both stay under 800 lines. |
| `trackpad_zoom_recognizer.dart`, `trend_control_strip.dart`, `trend_chart_settings_provider.dart` (changed) | `onPan`, the Range menu, and the range in settings. |
| `insights/domain/focus/` (new): `focus_metric.dart`, `focus_selection.dart`, `focus_group.dart`, `focus_factor_analyzer.dart` | Pure Dart: metrics, selection, ranking and thresholds, factor analysis. |
| `insights_repository.dart` (changed) | `getFocusFactorRows`. |
| `insights/presentation/providers/insights_focus_providers.dart` (new) | Selection `StateProvider`; group and factor `FutureProvider`s built on the existing per-dive series. |
| `insights/presentation/pages/insights_focus_page.dart` and `widgets/focus/` (new) | Page, selector, dive list, factors table. |
| Router, Insights categories, gas page (changed) | Route `/insights/focus`, category entry, records card link. |
| ARB files, all locales (changed) | New strings, translated. |

### Errors

Repository methods log and rethrow like their neighbours. The page renders each
`AsyncValue` with the existing loading, `StatEmptyState` and error patterns.

### Testing (written first)

- Unit: viewport window helpers; `windowFor` for every preset, including data
  shorter than the preset; `FocusGroup` ranking, ties and thresholds;
  `FocusFactorAnalyzer` averages, shares, the standout rule, coverage, the
  omitted self-factor and the fewer-than-3 rule; display-to-storage threshold
  conversion in metric and imperial.
- Repository: `getFocusFactorRows` with an excluded dive, a planned dive, a
  gas-excluded dive, and the suit and gas classifications. The stats-scope
  census still passes.
- Widget: strip drag, edge resize and tap to jump; shift+wheel and horizontal
  wheel pan; arrow keys; the Range menu and custom picker relabelling to
  Custom after a pan; the Focus page in each mode, imperial units, empty and
  no-match states, row tap navigation, and the gas card link.
- `test/architecture/` after adding files under `lib/`.

## Out of scope

- Persisting the Range choice or the focus selection across launches.
- Statistical significance testing of factors.
- Navigation for `MultiTrendLineChart` (month of year axis).
- Pushing a focus group into the dive list's filter.
