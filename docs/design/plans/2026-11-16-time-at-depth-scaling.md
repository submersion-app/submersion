# Time at depth: hours and adaptive bands Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The Insights > Profile "Time at depth" chart shows hours for big logs and depth bands that follow the diver's data, in round metric or imperial steps.

**Architecture:** The data layer bins samples by a band width given by a
`DepthBandScale` (10 m, or 30 ft = 9.144 m) and shapes the totals into a dense,
capped list whose edges are already in the diver's unit. The provider picks
the scale from the depth-unit setting. `CategoryBarChart` gains a y-axis scale
so the page can draw whole-hour ticks over minute values.

**Tech Stack:** Flutter, Riverpod, fl_chart, gen-l10n ARB files.

**Spec:** `docs/design/specs/2026-11-16-time-at-depth-scaling-design.md`

## Global Constraints

- Band step: 10 m (width 10.0 m) for metres, 30 ft (width 9.144 m) for feet.
- Bars run 0 to the deepest band holding time; empty bands in between are zero bars.
- At most 8 bars (`timeAtDepthMaxBars = 8`); the 8th is open-ended ("70+", "210+") when time exists deeper.
- Hours mode when the largest bar is at least 600 minutes; below that the chart is unchanged.
- Hours-mode values: under 60 min reads "N min"; under 100 h reads the existing `common_elapsed_hoursMinutes` ("18h 20m"); 100 h or more reads whole rounded hours with locale grouping ("1,104 h"). Reusing the app's existing hours-and-minutes string instead of a new "18 h 20 min" one is the builder's call, kept consistent with the rest of the app.
- New strings in all 11 ARBs, translated; `flutter gen-l10n` runs LAST.
- No em-dashes anywhere. No emojis.

## Review Focus

- A sample exactly on a feet edge (60 ft stored as 18.288 m) must land in the deeper band, not one below by float error: Task 1 test `edge depths land in the deeper band`.
- A negative depth (sensor noise above the surface) counts in the first band: Task 1 test `negative depth counts in the first band`.
- Rounding: the open-ended bar's minutes come from the summed seconds, not a sum of rounded minutes: Task 1 test `cap sums seconds before rounding`.
- A small bar inside an hours-mode chart reads "5 min", not "0h 5m": Task 3 test.
- Every other `CategoryBarChart` user keeps its axis (scale defaults to 1): Task 4 test `default scale keeps whole-count ticks`.

---

### Task 1: Banded seconds and dense, capped buckets

**Files:**
- Create: `lib/features/insights/data/depth_band_scale.dart`
- Modify: `lib/features/insights/data/series_profile_aggregates.dart` (`DepthBucket` doc, `timeAtDepthSecondsFromBlobs`, `timeAtDepthRangesFromBlobs`, `timeAtDepthRanges`, `_foldDepthSeconds`, `bucketsFromSeconds`; delete `_bucketLo`)
- Test: `test/features/insights/data/depth_band_scale_test.dart`, update `test/features/insights/data/series_profile_aggregates_test.dart`

**Interfaces:**
- Produces:
  - `class DepthBandScale { const DepthBandScale({required double widthMeters, required int step}); static const metric = DepthBandScale(widthMeters: 10, step: 10); static const imperial = DepthBandScale(widthMeters: 9.144, step: 30); static DepthBandScale forUnit(DepthUnit unit); int bandOf(double depthMeters); }`
  - `const timeAtDepthMaxBars = 8;` (in `depth_band_scale.dart`)
  - `Map<int, double> timeAtDepthSecondsFromBlobs(List<SeriesBlob> blobs, {DepthBandScale scale = DepthBandScale.metric})`, keyed by band index.
  - `List<DepthBucket> bucketsFromSeconds(Map<int, double> seconds, {DepthBandScale scale = DepthBandScale.metric, int maxBars = timeAtDepthMaxBars})`
  - `timeAtDepthRanges(samplesByStream, {scale})` and `timeAtDepthRangesFromBlobs(blobs, {scale})` take the same optional scale.
  - `DepthBucket` keeps its shape; `lowerDepth`/`upperDepth` are now in the scale's unit (`index * step`).

- [ ] **Step 1: Write failing tests** in `depth_band_scale_test.dart`:
  - `forUnit maps units`: `DepthBandScale.forUnit(DepthUnit.feet)` is `imperial`, meters is `metric`.
  - `edge depths land in the deeper band`: `metric.bandOf(30.0) == 3`, `metric.bandOf(29.99) == 2`, `imperial.bandOf(18.288) == 2`, `imperial.bandOf(9.144 * 7) == 7`.
  - `negative depth counts in the first band`: `metric.bandOf(-0.4) == 0`.
  - `fills gaps with zero bars`: `bucketsFromSeconds({0: 300, 4: 600})` equals `[(0,10,5),(10,20,0),(20,30,0),(30,40,0),(40,50,10)]`.
  - `caps at eight bars with an open-ended last bar`: seconds at bands 0..11 of 60 s each gives 8 buckets, last `(lowerDepth: 70, upperDepth: null, minutes: 5)`.
  - `exactly eight bands stay closed`: bands 0..7 give a last bucket `(70, 80, ...)`.
  - `cap sums seconds before rounding`: bands 7..9 of 20 s each gives the last bar `minutes: 1` (60 s), not 0.
  - `imperial edges`: `bucketsFromSeconds({0: 60, 2: 60}, scale: DepthBandScale.imperial)` lower edges `[0, 30, 60]`, upper `[30, 60, 90]`.
  - `empty seconds give no buckets`.
- [ ] **Step 2: Run** `flutter test test/features/insights/data/depth_band_scale_test.dart`; expect compile failure (no `DepthBandScale`).
- [ ] **Step 3: Implement** `DepthBandScale` (`bandOf` = `max(0, (depth / widthMeters + 1e-9).floor())`, the epsilon absorbing float error at exact edges), switch `_foldDepthSeconds` to `scale.bandOf`, and rewrite `bucketsFromSeconds` as dense 0..maxIndex, merging indices `>= maxBars - 1` into an open-ended bar only when `maxIndex >= maxBars`. Thread `scale` through the three public entry points.
- [ ] **Step 4: Update** `series_profile_aggregates_test.dart`: the cadence-cap test at 45 m now expects 5 buckets ending `(40, 50, ...)` with zeros at 0..30; the ascending test expects `[0, 10, 20, 30]`.
- [ ] **Step 5: Run** `flutter test test/features/insights/data/`; expect PASS (streaming tests unchanged).
- [ ] **Step 6: Commit** `feat(insights): band time at depth by a metric or imperial scale`.

### Task 2: Repository and provider use the diver's depth unit

**Files:**
- Modify: `lib/features/insights/data/repositories/insights_repository.dart` (`getTimeAtDepthRanges`)
- Modify: `lib/features/insights/presentation/providers/insights_providers.dart` (`timeAtDepthRangesProvider`)
- Test: update `test/features/insights/data/repositories/insights_repository_time_at_depth_test.dart`, add a provider case to `test/features/insights/presentation/providers/insights_providers_all_test.dart` if it can set settings, otherwise a focused new provider test file.

**Interfaces:**
- Consumes: Task 1's `DepthBandScale.forUnit`, `timeAtDepthSecondsFromBlobs(blobs, scale:)`, `bucketsFromSeconds(seconds, scale:)`.
- Produces: `Future<List<DepthBucket>> getTimeAtDepthRanges({String? diverId, DiveFilterState filter = const DiveFilterState(), DepthUnit depthUnit = DepthUnit.meters})`. The worker job is a top-level `Map<int, double> _timeAtDepthJob(({List<SeriesBlob> blobs, DepthBandScale scale}) job)` passed to `compute`.

- [ ] **Step 1: Write failing test** `feet bands come back in round feet`: a dive with 10 min at 15 m and 10 min at 50 m, `getTimeAtDepthRanges(depthUnit: DepthUnit.feet)` gives lower edges `[0, 30, 60, 90, 120, 150]` with 10 min at 30 (15 m is 49 ft) and 10 min at 150 (50 m is 164 ft).
- [ ] **Step 2: Update** the existing repo tests for dense output: line 154's `minutesAt(ranges, 20)` becomes `0`; line 163-164's single 40+ bucket becomes the last of five, `(40, 50)`.
- [ ] **Step 3: Run** the repo test; expect the feet test to FAIL.
- [ ] **Step 4: Implement** the `depthUnit` parameter and the job function; the provider watches `settingsProvider.select((s) => s.depthUnit)` and passes it. Update the method's doc comment (edges are in the requested unit).
- [ ] **Step 5: Run** `flutter test test/features/insights/`; expect PASS.
- [ ] **Step 6: Commit** `feat(insights): time at depth bands follow the depth unit setting`.

### Task 3: Time-at-depth value format and strings

**Files:**
- Create: `lib/features/insights/presentation/widgets/time_at_depth_format.dart`
- Modify: all 11 `lib/l10n/arb/app_*.arb`, then regenerate
- Test: `test/features/insights/presentation/widgets/time_at_depth_format_test.dart`

**Interfaces:**
- Produces:
  - `const timeAtDepthHoursThresholdMinutes = 600;`
  - `bool timeAtDepthUsesHours(int maxMinutes)` (true when `>= 600`)
  - `String formatTimeAtDepth(AppLocalizations l10n, int minutes, {required bool hours})`
  - ARB keys: `units_profileMetric_h` = `"h"` (next to `units_profileMetric_min`), and `insights_profile_timeAtDepth_hoursFormat` = `"{hours} h"` with `hours` typed `int`, `"format": "decimalPattern"` (next to `insights_profile_timeAtDepth_valueFormat`).

- [ ] **Step 1: Write failing tests** with English `AppLocalizations` (`lookupAppLocalizations(const Locale('en'))`):
  - `599` is minutes mode, `600` is hours mode.
  - minutes mode: `formatTimeAtDepth(l10n, 66240, hours: false) == '66240 min'` (today's string, unchanged).
  - hours mode: `5 -> '5 min'`, `1100 -> '18h 20m'`, `5999 -> '99h 59m'`, `6000 -> '100 h'`, `66240 -> '1,104 h'`, `66270 -> '1,105 h'` (rounds).
- [ ] **Step 2: Run** it; expect compile failure.
- [ ] **Step 3: Add** both keys to `app_en.arb` with `@` metadata, translate into the 10 other ARBs (anchored beside the neighbouring key of the same group in each), implement the formatter, then run `flutter gen-l10n` last and confirm `grep -A2 "hoursFormat" lib/l10n/arb/app_localizations_de.dart` is not English-only where German differs.
- [ ] **Step 4: Run** the test and `flutter test test/l10n/` (ARB guards); expect PASS.
- [ ] **Step 5: Commit** `feat(insights): hour formats for time at depth`.

### Task 4: Hour-scaled y axis on CategoryBarChart, wired into the page

**Files:**
- Modify: `lib/features/insights/presentation/widgets/category_bar_chart.dart`
- Modify: `lib/features/insights/presentation/pages/insights_profile_page.dart` (`_buildTimeAtDepthSection`)
- Test: `test/features/insights/presentation/widgets/category_bar_chart_axis_scale_test.dart`, `test/features/insights/presentation/pages/insights_profile_time_at_depth_test.dart`

**Interfaces:**
- Consumes: Task 3's `timeAtDepthUsesHours`, `formatTimeAtDepth`, `units_profileMetric_h`; Task 2's provider output (edges already in display units).
- Produces: `CategoryBarChart({..., int yAxisScale = 1})`: the axis is `ChartAxis.forCounts(maxCount / yAxisScale)` with `min`, `max` and `interval` multiplied back by `yAxisScale`, and each tick labelled `(value / yAxisScale).round()`.

- [ ] **Step 1: Write failing widget tests:**
  - `default scale keeps whole-count ticks`: data max 40 with no scale shows the same tick texts as today (e.g. `'0'`, `'20'`, `'40'`).
  - `scale 60 labels ticks in hours`: data `[(label: 'a', count: 66240)]`, `yAxisScale: 60` shows tick `'1000'` and no tick text above `'1500'`.
  - Page: override `timeAtDepthRangesProvider` with 8 buckets ending `(70, null, 66240)` and shows `'70+'` and axis label `'h'`; a second case with max 120 minutes shows axis label `'min'`; a third with feet edges `(0, 30)`/`(30, 60)` shows `'0-30'` and `'30-60'` untouched by conversion.
- [ ] **Step 2: Run** them; expect FAIL.
- [ ] **Step 3: Implement** `yAxisScale` and the page change: drop `convertDepth` from labels (edges are already display units), compute `hours = timeAtDepthUsesHours(max minutes)`, pass `yAxisScale: hours ? 60 : 1`, `yAxisLabel: hours ? l10n.units_profileMetric_h : l10n.units_profileMetric_min`, and `valueFormatter: (m) => formatTimeAtDepth(l10n, m, hours: hours)`.
- [ ] **Step 4: Run** `flutter test test/features/insights/` and `flutter test test/architecture/ test/shared/`; expect PASS. Run `dart format .` and `flutter analyze`; expect no issues.
- [ ] **Step 5: Commit** `feat(insights): show time at depth in hours and adaptive bands`.
