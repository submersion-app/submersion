# Wider Dive Profile Chart Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task, inline in one session. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give the dive profile plot more width by replacing the two rotated axis-title strips with unit captions above the tick columns, and trimming the dive details profile card's side padding.

**Architecture:** `DiveProfileChart` stops passing `axisNameWidget` to fl_chart's left and right axes, so fl_chart no longer reserves their 16 px strips. A one-line caption row between the legend and the plot shows the depth unit over the left ticks and the right axis's unit over the right ticks. Every helper that mirrors fl_chart's layout (`plotLeftInset`, `plotRightInset`, the legend's left padding, the right-axis tap overlay) drops the old strip in the same change.

**Tech Stack:** Flutter, fl_chart, Riverpod, flutter_test.

**Spec:** `docs/design/specs/2026-11-25-dive-profile-chart-width-design.md`

## Global Constraints

- Page padding and card margins do not change; the profile card keeps the same left and right edges as the other cards (#4488).
- Tick gutter widths and their 350 px breakpoint (`leftAxisSize`, `rightAxisSize`) do not change.
- Captions follow the active diver's unit settings (`UnitFormatter`), and the right caption uses the right axis's colour (`_palette.rightAxisColor`).
- The right caption is absent when the right axis shows no metric.
- Card side padding: 6 px; top and bottom stay 12 px.
- No new strings in the ARB files: captions are unit symbols from `UnitFormatter` and existing `profileMetricUnitSuffix` / `profileMetricShortName`.

## Review Focus

- A right-axis metric with no unit (an unknown or unitless metric): the caption falls back to the metric's short name rather than showing nothing. Pinned in Task 1.
- Hover auto-switch of the right axis: the caption changes with the axis, not only with the stored preference. Task 2 drives the metric through `rightAxisMetricOverride` or the hover path the existing right-axis tests use.
- The right-axis tap overlay must not reach into the plot now that the gutter is narrower, or it steals scrub touches near the right edge. Pinned in Task 2.
- Imperial units: `ft` and `psi` captions. Pinned in Task 2.
- The narrow-toolbar breakpoint on 360 and 375 px phones after the card gains 12 px of inner width: `dive_detail_page_profile_toolbar_narrow_test.dart` must still pass. Run in Task 3.

---

### Task 0: Before screenshots (throwaway, uncommitted)

**Files:**
- Create (never committed): `test/_pr_shots/profile_width_shots_test.dart`

- [ ] **Step 1:** Write a golden test that loads the SDK's material fonts (Roboto and MaterialIcons from `bin/cache/artifacts/material_fonts` via `FontLoader`), pumps a `DiveDetailProfileSection` card for a seeded dive (about 45 min, 30 m, with pressure data, so the right axis shows) inside `MaterialApp(theme: submersionLight)` with the providers it needs (copy the overrides from `test/features/dive_log/presentation/pages/dive_detail_page_profile_toolbar_narrow_test.dart`), at 390 x 844 and 1000 x 800 logical, devicePixelRatio 2. Golden names come from `--dart-define=STAGE=before|after`.
- [ ] **Step 2:** Run `flutter test test/_pr_shots/profile_width_shots_test.dart --update-goldens --dart-define=STAGE=before` and copy the PNGs to the scratchpad as `01-profile-phone-before.png` and `02-profile-desktop-before.png`.

### Task 1: Right-axis unit caption text

**Files:**
- Modify: `lib/features/dive_log/presentation/widgets/profile_right_axis_metric_labels.dart:205-232`
- Test: `test/features/dive_log/presentation/widgets/profile_right_axis_unit_caption_test.dart`

**Interfaces:**
- Produces: `String rightAxisUnitCaption(ProfileRightAxisMetric metric, UnitFormatter units, AppLocalizations l10n)` returning the unit alone: `temperature` gives `units.temperatureSymbol`; `pressure` gives `units.pressureSymbol`; `meanDepth` gives `units.depthSymbol`; `sac` gives `'${units.pressureSymbol}/${l10n.units_profileMetric_min}'`; `ascentRate` gives `'${units.depthSymbol}/${l10n.units_profileMetric_min}'`; `buoyancy` and `aveloBuoyancy` give `units.weightSymbol`; `computerRmv` gives `units.rmvSymbol`; any other metric gives `profileMetricUnitSuffix(l10n, metric) ?? profileMetricShortName(l10n, metric)`.
- `rightAxisLabel` is deleted once Task 2 removes its only caller.

- [ ] **Step 1: Write the failing tests**: `metric units give bare symbols` (temperature `°C`, pressure `bar`, sac `bar/min`, ascentRate `m/min` with metric settings), `imperial units` (pressure `psi`, meanDepth `ft`), `a metric without a unit falls back to its short name` (pick a metric whose `profileMetricUnitSuffix` is null and expect `profileMetricShortName` for it).
- [ ] **Step 2:** Run `flutter test test/features/dive_log/presentation/widgets/profile_right_axis_unit_caption_test.dart`; expect failure (undefined function).
- [ ] **Step 3:** Implement `rightAxisUnitCaption` beside `rightAxisLabel`.
- [ ] **Step 4:** Rerun; expect PASS.

### Task 2: Unit captions in place of the rotated axis titles

**Files:**
- Modify: `lib/features/dive_log/presentation/widgets/dive_profile_chart.dart` (constants near 438, `plotLeftInset`/`plotRightInset` near 640, `build` near 3376 and its Column, `leftTitles`/`rightTitles` near 4650 and 4726, the right-axis tap overlay near 5324, `_rightAxisLabel` near 8198)
- Modify: `lib/features/dive_log/presentation/widgets/profile_right_axis_metric_labels.dart` (delete `rightAxisLabel`)
- Test: `test/features/dive_log/presentation/widgets/dive_profile_chart_axis_captions_test.dart`
- Modify test: `test/features/dive_log/presentation/widgets/dive_profile_chart_range_selection_test.dart:118-122` (`plotLeft` becomes `32 + 1.0`, comment updated)

**Interfaces:**
- Consumes: `rightAxisUnitCaption` (Task 1).
- Produces: `ProfileAxisCaptions.leftKey` and `ProfileAxisCaptions.rightKey` (static `ValueKey<String>`s on the two caption `Text`s), `plotLeftInset(w) == leftAxisSize(w) + 1`, `plotRightInset(w, hasRightAxis: true) == rightAxisSize(w) + 1`.

- [ ] **Step 1: Write the failing tests** (pump the chart the way `dive_profile_chart_right_axis_ticks_test.dart` does):
  - `left caption shows the depth unit`: text of `ProfileAxisCaptions.leftKey` is `m`; with imperial settings, `ft`.
  - `right caption shows the right axis unit in its colour`: with pressure on the right axis, `ProfileAxisCaptions.rightKey` reads `bar` (imperial: `psi`) and its style colour equals the right-axis tick label colour.
  - `right caption follows the right axis metric`: switch the right axis to temperature and expect `°C`.
  - `no right caption without a right axis metric`: `find.byKey(ProfileAxisCaptions.rightKey)` finds nothing.
  - `rotated axis titles are gone`: `find.text('Depth (m)')` finds nothing.
  - `captions sit over their tick columns`: the left caption's left edge is at the chart's left edge (within 0.5), the right caption's right edge at the chart's right edge.
  - `plot insets drop the axis-name strip`: `plotLeftInset(400) == 33`, `plotRightInset(400, hasRightAxis: true) == 39`, `plotLeftInset(300) == 29`.
  - `right axis tap overlay stays in the gutter`: the overlay found by the `diveLog_profile_semantics_changeRightAxis` semantics label is no wider than `plotRightInset(width, hasRightAxis: true)`.
- [ ] **Step 2:** Run the new test file; expect failures.
- [ ] **Step 3: Implement.**
  - Delete `_leftRightAxisNameSize`; remove `axisNameWidget` from `leftTitles` and `rightTitles`.
  - `plotLeftInset`/`plotRightInset` drop the name size; `legendLeftPadding` becomes `leftAxisSize(constraints.maxWidth)`.
  - Add `ProfileAxisCaptions` in a new file `lib/features/dive_log/presentation/widgets/profile_axis_captions.dart` (the chart file is far over 800 lines; keep the new widget out of it): `const ProfileAxisCaptions({required String leftCaption, String? rightCaption, Color? rightColor, VoidCallback? onRightTap})`, a `Row` with the left caption, a `Spacer`, and the right caption when non-null, each `labelSmall`, `maxLines: 1`, keyed with `leftKey` and `rightKey`. The chart passes `onRightTap` (opening `_showRightAxisMetricSelector`) when `!widget.depthAndPressureOnly`.
  - Insert the row in the build Column between the legend row and the plot, for every chart (including `depthAndPressureOnly`). It needs the effective right-axis metric and range the plot uses, so compute them once in `build` the way `_plotInsets` does and pass them in.
  - Tap overlay width: `DiveProfileChart.plotRightInset(availableWidth, hasRightAxis: true)` instead of the literal 50.
  - Replace `_rightAxisLabel` with nothing; delete `rightAxisLabel` from the labels file.
- [ ] **Step 4:** Run the new test file and the existing chart tests whose layout this touches, by path: `dive_profile_chart_range_selection_test.dart` (after updating `plotLeft`), `dive_profile_chart_depth_pressure_only_test.dart`, `dive_profile_chart_right_axis_ticks_test.dart`, `dive_profile_chart_right_axis_scale_test.dart`, `dive_profile_chart_test.dart`, `edit_sections/gas_switch_time_sheet_test.dart`. Expect PASS; fix any that asserted the old 16 px strip by updating the expected geometry, never by loosening it.
- [ ] **Step 5:** `dart format .`, `flutter analyze`, commit `feat(dive-log): unit captions in place of the profile chart's rotated axis titles`.

### Task 3: Slimmer side padding on the dive details profile card

**Files:**
- Modify: `lib/features/dive_log/presentation/widgets/dive_detail/dive_detail_profile_section.dart:279-282`
- Test: `test/features/dive_log/presentation/pages/dive_detail_profile_card_padding_test.dart`

**Interfaces:**
- Produces: `static const EdgeInsets cardPadding = EdgeInsets.fromLTRB(6, 12, 6, 12)` on `DiveDetailProfileSection`.

- [ ] **Step 1: Write the failing test** `profile card pads its sides by 6 and its top and bottom by 12`: pump the section (harness from the toolbar-narrow test), find the `Padding` that is the direct child of the section's `Card`, expect `EdgeInsets.fromLTRB(6, 12, 6, 12)`.
- [ ] **Step 2:** Run it; expect FAIL (`EdgeInsets.all(12)`).
- [ ] **Step 3:** Use `cardPadding` in `card()`.
- [ ] **Step 4:** Run the new test plus `test/features/dive_log/presentation/pages/dive_detail_page_profile_toolbar_narrow_test.dart` and `test/features/dive_log/presentation/pages/dive_detail_pinned_profile_test.dart`; expect PASS.
- [ ] **Step 5:** `dart format .`, `flutter analyze`, commit `feat(dive-log): slimmer side padding on the dive details profile card`.

### Task 4: After screenshots

- [ ] **Step 1:** Rerun Task 0's test with `--dart-define=STAGE=after`; save `01-profile-phone-after.png` and `02-profile-desktop-after.png`. Also render a 360 px phone with imperial units and a deep dive (3-digit feet) as `03-profile-phone-imperial-after.png`, to check the range ends.
- [ ] **Step 2:** Delete `test/_pr_shots/` before pushing.
