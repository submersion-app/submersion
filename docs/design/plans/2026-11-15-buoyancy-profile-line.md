# Net buoyancy line on the dive profile: implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans
> to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for
> tracking.

**Goal:** An optional two-colour net buoyancy line on every logged-dive
profile chart, with a synced "show by default" setting (issue #4593).

**Architecture:** A new right-axis metric, `ProfileRightAxisMetric.buoyancy`,
drawn in the existing metric band as runs of one sign. The values come from
the buoyancy model run on the series the chart draws (the card's result when
that is the primary). Surfaces only run the model while the line is on.

**Tech Stack:** Flutter, Riverpod, Drift, fl_chart, ARB l10n.

**Spec:** `docs/design/specs/2026-11-15-buoyancy-profile-line-design.md`

## Global Constraints

- Schema version 370 for `diver_settings.default_show_buoyancy`, BOOLEAN,
  default false, no backfill. Rescan open PRs and worktrees for a 370 claim
  right before pushing; renumber if taken.
- Two fixed colours, not diver-customizable (they carry meaning, like the
  ascent-rate bands): `ProfileMetricColors.buoyancyBuoyant` and
  `ProfileMetricColors.buoyancyHeavy`. Each distinct from
  `AppColors.chartDepth` and from each other, each at least 3:1 against the
  chart surface in light and dark (`contrast_ratio.dart`).
- No fill under or around the line.
- One legend entry and one Chart options row, label "Buoyancy", with a
  two-colour swatch.
- Tooltip: one decimal in the diver's weight unit, sign and side in words:
  "+0.9 kg buoyant", "-2.4 kg heavy", "0.0 kg neutral" when it rounds to 0.
- Axis range always contains 0, padded 10% of the span, minimum span 1 kg.
- Surfaces never run the simulation while the line is off, except where the
  dive page already runs it for the Buoyancy card.
- Every new string in all 11 ARB files with a translation; info sheet
  strings within the two-sentence (`_body`) and three-sentence
  (`_background`) caps.
- Never use em-dashes in code, comments, strings or docs.

## Review Focus

1. **A secondary computer is active and has no pressure series:** the line
   still draws, from the assembler's estimated pressures. Pinned in Task 3
   (`secondary source without pressures still models`).
2. **A dive whose net never crosses 0 (always heavy):** one heavy run, the
   axis still includes 0 and the neutral rule is inside the plot. Pinned in
   Task 2 (`always heavy keeps zero in range`).
3. **Twin samples and drawn samples disagree in length or timestamps** (a
   Combine's sequential halves draw the union, the card models primary rows
   only): unmatched samples are gaps, never shifted values. Pinned in Task 3
   (`unmatched timestamps become null`).
4. **Imperial diver:** axis ticks and tooltip in lb, with the "+" sign and
   the range still anchored at 0. Pinned in Task 4 (`tooltip in pounds`,
   `axis tick has plus sign`).
5. **Default on, dashboard opened:** the model runs (line on); default off:
   it does not. Pinned in Task 5 (`dashboard does not run the model while
   off`).

---

### Task 1: The synced default setting and legend state

**Files:**
- Modify: `lib/core/database/tables/diver_tables.dart` (after
  `defaultShowCounterdiffusion`)
- Modify: `lib/core/database/database.dart` (`currentSchemaVersion` 370,
  version list entry with comment)
- Create: `lib/core/database/migrations/helpers/buoyancy_line_migrations.dart`
  (`_assertDefaultShowBuoyancyColumn`, same shape as
  `counterdiffusion_migrations.dart`)
- Modify: `lib/core/database/migrations/app_database_migrations.dart`
  (`part`), `ladder/rungs_v340_onward.dart` (v370 rung),
  `before_open_settings_columns.dart` (backstop)
- Modify: `lib/core/services/sync/sync_data_serializer.dart` (seed
  `'defaultShowBuoyancy': false`)
- Modify: `lib/features/agent_access/data/resources/sql_column_notes.generated.dart`
- Modify: `lib/features/settings/data/repositories/diver_settings_repository.dart`
  (three sites, as counterdiffusion)
- Modify: `lib/features/settings/presentation/conflicts/catalogue/diver_settings_fields.dart`
- Modify: `lib/features/settings/presentation/providers/settings_providers.dart`
  (`AppSettings.defaultShowBuoyancy`, copyWith,
  `SettingsNotifier.setDefaultShowBuoyancy`)
- Modify: `lib/features/settings/presentation/pages/default_visible_metrics_page.dart`
  (a `SwitchListTile` after gas density),
  `section_appearance_page.dart` (the count list)
- Modify: `lib/features/dive_log/presentation/providers/profile_legend_provider.dart`
  (`showBuoyancy` field, copyWith, ==, hashCode, active count, seed from
  `defaultShowBuoyancy`, `toggleBuoyancy()`)
- Modify: `test/helpers/mock_providers.dart` (`setDefaultShowBuoyancy`)
- Test: `test/core/database/migration_v370_buoyancy_default_test.dart`,
  `test/features/settings/data/repositories/diver_settings_repository_buoyancy_test.dart`,
  `test/core/services/sync/sync_diver_settings_fallback_test.dart` (add a
  case), `test/features/settings/presentation/pages/default_visible_metrics_page_test.dart`
  (add a case), `test/features/dive_log/presentation/providers/profile_legend_provider_test.dart`
  (add cases), plus the fixtures the counterdiffusion change had to touch
  (`settings_page_test`, `settings_page_shared_data_test`,
  `every_setter_waits_for_load_test`, `settings_sync_reload_test`,
  `records_page_test`)

**Interfaces:**
- Produces: `AppSettings.defaultShowBuoyancy` (bool),
  `SettingsNotifier.setDefaultShowBuoyancy(bool)`,
  `ProfileLegendState.showBuoyancy` (bool, default false),
  `ProfileLegend.toggleBuoyancy()`, l10n key
  `settings_appearance_metric_buoyancy` ("Buoyancy") and
  `settings_conflict_field_defaultShowBuoyancy`.

- [ ] **Step 1: Write the failing tests**
  - Migration: a database opened at 369 gains `default_show_buoyancy`
    with value 0 for an existing row; `migrationStepCount(369) == 1`
    pinned the way the v366 test pins its relation.
  - Repository: saving `defaultShowBuoyancy: true` and reading back
    returns true; a fresh diver reads false.
  - Sync fallback: a payload without `defaultShowBuoyancy` hydrates with
    false.
  - Default visible metrics page: tapping the "Buoyancy" switch calls
    `setDefaultShowBuoyancy(true)`.
  - Legend provider: `showBuoyancy` seeds from `defaultShowBuoyancy`;
    `toggleBuoyancy()` flips it and counts toward the active count.
- [ ] **Step 2: Run them and see them fail** (missing members).
- [ ] **Step 3: Implement**, mirroring `defaultShowCounterdiffusion` at
  every site listed. Add the ARB keys to `app_en.arb` and translations to
  the other 10, then `flutter gen-l10n`. Run build_runner for the table
  change (unfiltered, in the background).
- [ ] **Step 4: Run the tests** listed above plus
  `test/core/database` and `test/features/settings`; expect PASS.
- [ ] **Step 5: Commit** `feat(settings): default visibility for the buoyancy line on the dive profile`

### Task 2: Pure line logic: range, runs and bars

**Files:**
- Create: `lib/features/dive_log/presentation/widgets/profile_buoyancy_line.dart`
- Modify: `lib/features/dive_log/presentation/widgets/profile_metric_colors.dart`
  (the two colours)
- Test: `test/features/dive_log/presentation/widgets/profile_buoyancy_line_test.dart`

**Interfaces:**
- Produces:
  - `({double min, double max})? buoyancyAxisRange(List<double?> curveKg)`:
    null when fewer than two non-null values.
  - `List<BuoyancyRun> buoyancySignRuns(List<double?> curveKg, List<int> timestamps)`
    where `class BuoyancyRun { final bool buoyant; final List<({double t, double kg})> points; }`.
    Runs split at each sign change with an interpolated point at exactly
    0 kg shared by both runs; a value of exactly 0 does not start a run; a
    null ends the current run (gap).
  - `List<LineChartBarData> buildBuoyancyLines({required List<BuoyancyRun> runs, required MetricBand band, required ({double min, double max}) range, required Color buoyant, required Color heavy})`:
    one bar per run, `isCurved: false`, no `belowBarData`/`aboveBarData`,
    y = `-band.map(kg, range.min, range.max)`.
  - `LineChartBarData buildNeutralRule({required MetricBand band, required ({double min, double max}) range, required double minX, required double maxX, required Color color})`:
    a two-spot dashed bar (`dashArray: [4, 3]`, width 1) at 0 kg.

- [ ] **Step 1: Write the failing tests**
  - `range includes zero and pads ten percent`: `[-3.0, -1.0, 2.0]` gives
    `(min: -3.5, max: 2.5)`.
  - `always heavy keeps zero in range`: `[-3.0, -2.0]` gives max >= 0 and
    min < -3.0.
  - `minimum span is one kilogram`: `[0.1, 0.2]` gives `max - min >= 1.0`
    with 0 inside.
  - `fewer than two values gives null`: `[null, 1.0]` gives null.
  - `one crossing gives two runs sharing an interpolated zero`:
    curve `[-1.0, 1.0]` at t `[0, 10]` gives a heavy run ending at
    `(t: 5, kg: 0)` and a buoyant run starting at `(t: 5, kg: 0)`.
  - `exact zero does not split`: `[-1.0, 0.0, -1.0]` gives one heavy run.
  - `null leaves a gap`: `[-1.0, null, -1.0]` gives two heavy runs.
  - `bars use the run colours and carry no fill`: two runs give two bars,
    colours buoyant/heavy, `belowBarData.show == false`.
- [ ] **Step 2: Run and see them fail.**
- [ ] **Step 3: Implement** in `profile_buoyancy_line.dart`; pick the two
  colours and add a test in the same file asserting each against
  `AppColors.chartDepth` and the 3:1 contrast in light and dark surfaces
  via `contrast_ratio.dart`.
- [ ] **Step 4: Run the test file; expect PASS.**
- [ ] **Step 5: Commit** `feat(dive-log): buoyancy line runs, range and bars`

### Task 3: Data: which computer is modelled, and the aligned curve

**Files:**
- Create: `lib/features/dive_log/presentation/providers/chart_buoyancy_providers.dart`
- Create: `lib/features/dive_log/presentation/utils/buoyancy_curve.dart`
- Modify: `lib/features/dive_log/data/services/buoyancy_twin_assembler.dart`
  (add `static bool isModelable(Dive dive)`, used by `assemble`)
- Test: `test/features/dive_log/presentation/providers/chart_buoyancy_providers_test.dart`,
  `test/features/dive_log/presentation/utils/buoyancy_curve_test.dart`,
  `test/features/dive_log/data/services/buoyancy_twin_assembler_test.dart`
  (add a case)

**Interfaces:**
- Consumes: `buoyancyTwinProvider`, `activeSourceProfileProvider`,
  `activeSourceTankPressuresProvider`, `diveDataSourcesProvider`,
  `diveProvider`, `weightCalibrationProvider`, `latestDiverWeightProvider`,
  `runBuoyancyTwin`.
- Produces:
  - `BuoyancyTwinAssembler.isModelable(Dive dive) -> bool` (tanks non-empty
    or an exposure suit; `assemble` returns null exactly when this is
    false).
  - `buoyancyModelableProvider`: `FutureProvider.autoDispose.family<bool, String>`
    reading `diveProvider` only.
  - `chartBuoyancyTwinProvider`: `FutureProvider.autoDispose.family<BuoyancyTwinResult?, String>`.
    Active source null or primary: `buoyancyTwinProvider`'s `result`.
    Otherwise: assemble from `dive.copyWith(profile: active.points)` with
    the active source's pressures, `compute(runBuoyancyTwin, input)`.
  - `List<double?> alignBuoyancyCurve(List<DiveProfilePoint> drawn, List<TwinSample> samples)`:
    same length as `drawn`; each entry the `netKg` of the sample with the
    same timestamp, else null.

- [ ] **Step 1: Write the failing tests**
  - `unmatched timestamps become null`: drawn t `[0, 10, 20]`, samples t
    `[0, 20]` gives `[v0, null, v20]`.
  - `isModelable` is false with no tanks and no suit, true with a tank.
  - `single source reuses the card result`: with the card provider
    overridden, the chart provider returns the identical object.
  - `secondary source models its own points`: override the active source
    to a secondary with points at depths unlike the primary's; the result's
    sample timestamps equal the secondary's points.
  - `secondary source without pressures still models`: same, with an
    empty pressure map; result is non-null and `pressuresEstimated` is true.
- [ ] **Step 2: Run and see them fail.**
- [ ] **Step 3: Implement.** Confirm whether the primary `SourceProfile`
  points equal `diveProfileProvider`'s rows (edited rows included); if they
  can differ, the primary branch models the active points too, and the
  test changes to match.
- [ ] **Step 4: Run; expect PASS.** Also run
  `test/features/dive_log/presentation/providers/buoyancy_twin_provider_test.dart`
  if present.
- [ ] **Step 5: Commit** `feat(dive-log): model the buoyancy line on the computer the chart draws`

### Task 4: The chart: line, neutral rule, axis, legend, options, tooltip

**Files:**
- Modify: `lib/core/constants/profile_metrics.dart` (`buoyancy` value,
  category `other`)
- Modify: `lib/features/dive_log/presentation/widgets/dive_profile_chart.dart`
  (inputs `buoyancyCurve: List<double?>?` and `buoyancyAvailable: bool =
  false`; `_showBuoyancy` from legend state; bars tagged
  `ProfileRightAxisMetric.buoyancy`; neutral rule while shown; series
  signature; tooltip row; legend config flag)
- Modify: `profile_right_axis_metric_labels.dart`,
  `profile_right_axis_tick_format.dart` (convert with
  `units.convertWeight`, 1 decimal base, "+" prefix for positive buoyancy
  ticks), `profile_cursor_tooltip.dart` and
  `profile_metric_palette.dart` if their switches need the value
- Modify: `profile_legend_config.dart` (`hasBuoyancy`),
  `active_legend_entries.dart` (one entry with `secondColor`),
  `dive_profile_legend.dart` (`LegendSwatch.secondColor`: left half
  `color`, right half `secondColor`), `chart_options_dialog.dart` and
  `chart_options_dialog_rows.dart` (`buildToggleItem(secondColor:)`)
- Modify: `lib/features/settings/presentation/conflicts/conflict_enum_labels_settings.dart`
  if it needs a label
- Test: `test/features/dive_log/presentation/widgets/dive_profile_chart_buoyancy_test.dart`,
  `test/features/dive_log/presentation/widgets/profile_right_axis_tick_format_test.dart`
  (add a case), `chart_options_buoyancy_test.dart`

**Interfaces:**
- Consumes: Task 1 `ProfileLegendState.showBuoyancy`,
  `ProfileLegend.toggleBuoyancy()`; Task 2 functions and colours.
- Produces: `DiveProfileChart({List<double?>? buoyancyCurve, bool buoyancyAvailable = false})`;
  l10n keys `diveLog_legend_label_buoyancy` ("Buoyancy"),
  `diveLog_tooltip_buoyancy` ("Buoyancy"), `diveLog_buoyancy_side_buoyant`
  ("buoyant"), `diveLog_buoyancy_side_heavy` ("heavy"),
  `diveLog_buoyancy_side_neutral` ("neutral"), `enum_profileMetric_buoyancy`,
  `enum_profileMetric_buoyancy_short`.

- [ ] **Step 1: Write the failing tests**
  - `draws heavy and buoyant runs when on`: chart with a crossing curve,
    `showBuoyancy` true: bars tagged buoyancy number 2, colours
    buoyant/heavy, and one dashed neutral bar.
  - `draws nothing when off`: no buoyancy bars, no neutral rule.
  - `options row only when available`: `buoyancyAvailable: false` hides
    the "Buoyancy" row; true shows it, and tapping it toggles.
  - `one legend entry with two colours`: when on, exactly one legend entry
    labelled "Buoyancy" whose swatch carries both colours.
  - `tooltip names the side`: at a sample of +0.94 kg the row reads
    "+0.9 kg buoyant"; at -2.36 kg "-2.4 kg heavy"; at 0.04 kg
    "0.0 kg neutral".
  - `tooltip in pounds`: imperial units, -2.36 kg reads "-5.2 lb heavy".
  - `axis tick has plus sign`: `formatRightAxisTick(buoyancy, 2.0, metric)`
    gives "+2.0", `-3.0` gives "-3.0", `0` gives "0.0".
- [ ] **Step 2: Run and see them fail.**
- [ ] **Step 3: Implement.** Add the enum value first and let
  `flutter analyze` list every non-exhaustive switch. Build the bars with
  the Task 2 functions over the decimated indices, with a flat surface
  lead-in like GF. ARB keys in all 11 files, `flutter gen-l10n`.
- [ ] **Step 4: Run** the new tests and
  `test/features/dive_log/presentation/widgets/`; expect PASS.
- [ ] **Step 5: Commit** `feat(dive-log): draw the buoyancy line on the dive profile`

### Task 5: Wire every surface, inside the cost rule

**Files:**
- Create: `lib/features/dive_log/presentation/widgets/chart_buoyancy_inputs.dart`
  (`({bool available, List<double?>? curve}) watchChartBuoyancy(WidgetRef ref, String diveId, List<DiveProfilePoint> drawn)`)
- Modify: `dive_profile_chart_host.dart`, `dive_profile_panel.dart`,
  `pages/fullscreen_profile_page.dart` (pass `buoyancyAvailable` and
  `buoyancyCurve`)
- Test: `test/features/dive_log/presentation/widgets/chart_buoyancy_inputs_test.dart`,
  `test/features/dashboard/presentation/widgets/recent_dive_profile_preview_buoyancy_test.dart`

**Interfaces:**
- Consumes: Task 3 providers and `alignBuoyancyCurve`; Task 1
  `profileLegendProvider.select((s) => s.showBuoyancy)`.
- Produces: the record above. `available` comes from
  `buoyancyModelableProvider` only; `curve` is non-null only while
  `showBuoyancy` is true and `chartBuoyancyTwinProvider` has a value.

- [ ] **Step 1: Write the failing tests**
  - `dashboard does not run the model while off`: pump the recent-dive
    preview with `showBuoyancy` false and a counting override of
    `chartBuoyancyTwinProvider`; the count stays 0. With it true, the
    count is 1 and the chart receives a non-null curve.
  - `switching the active computer changes the curve`: host with two
    sources; changing `activeDiveSourceProvider` changes the curve passed
    to `DiveProfileChart`.
  - `planner logged chart follows the default`: no override of
    `showBuoyancy` in `_LoggedDiveLegend` (assert the seeded value is the
    setting's).
- [ ] **Step 2: Run and see them fail.**
- [ ] **Step 3: Implement**, passing `drawn` as the series each surface
  already gives the chart (`chartProfile` in the host).
- [ ] **Step 4: Run** the new tests and the existing host, panel,
  fullscreen and dashboard preview tests; expect PASS.
- [ ] **Step 5: Commit** `feat(dive-log): show the buoyancy line on every logged-dive profile`

### Task 6: Explanations and docs

**Files:**
- Modify: `lib/shared/widgets/info_sheet/dive_terms.dart`
  (`DiveTerm.buoyancyProfile`), `lib/features/dive_log/presentation/info/dive_profile_info.dart`
  (listed when `config.hasBuoyancy && state.showBuoyancy`),
  `lib/features/settings/presentation/info/settings_info.dart` if the
  default visible metrics section lists terms
- Modify: `docs/user/dive-profiles.md` (one line)
- Test: `test/features/dive_log/presentation/info/dive_detail_info_builders_test.dart`
  (add a case)

- [ ] **Step 1: Write the failing test**: the profile info terms include
  `DiveTerm.buoyancyProfile` exactly when buoyancy is available and on.
- [ ] **Step 2: Run and see it fail.**
- [ ] **Step 3: Implement**, with body (2 sentences) and background (3
  sentences) in all 11 ARB files: what the line is, that it is the
  Buoyancy card's model on the computer shown, and what the colours mean.
- [ ] **Step 4: Run** the info tests and `test/l10n` (sentence caps);
  expect PASS.
- [ ] **Step 5: Commit** `docs(dive-log): explain the buoyancy line`

### Finish

- [ ] `dart format .`, `flutter analyze` (whole repo), `test/architecture/`
  and `test/shared/`.
- [ ] Screenshots before and after (in-process harness): dive page profile
  with the line on (light, dark), Chart options, Default visible metrics,
  phone and desktop widths.
