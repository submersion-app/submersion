# Profile time-only zoom and right axis Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task, inline in this session. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A three-way Zoom choice (both axes magnify, both axes keep overlays in view, time only), ascent rate as a right-axis scale matching its bars, and a Right axis row in chart options (issue #5069).

**Architecture:** `ChartViewport` gains an independent depth zoom `zoomY`; the profile chart passes a time-only flag on every zoom path. A new synced diver setting `profileZoomTimeOnly` pairs with `profileMetricsFollowViewport` and the pair is presented as one `ProfileZoomMode`. The right axis gains a plot-fraction labelling mode for ascent rate, and the axis menu moves to a shared builder that both the axis tap strip and a new chart-options row call.

**Tech Stack:** Flutter, Riverpod, Drift (schema rung), fl_chart.

**Spec:** `docs/design/specs/2026-11-27-profile-axis-zoom-and-right-axis-design.md`

## Global Constraints

- Schema version 389 (open PRs #5062 and #5031 claim 387 and 388). The rung only adds a nullable column; the sync floor (`minimumCompatibleSchemaVersion = 386`) does not move.
- New tables, rungs and helpers never go in `lib/core/database/database.dart`; only the version constant and the `migrationVersions` list entry do.
- No stored value is rewritten. Fresh and existing rows read `profileZoomTimeOnly` as false.
- Every new string in all 12 ARB files under `lib/l10n/arb/`, inserted beside a neighbouring key of the same group, then `flutter gen-l10n`.
- Units: ascent-rate labels in the diver's depth unit per minute.
- No new widget shape that exists only in one zoom mode above the gesture recognizers (#2350).
- Run only the test files you wrote or changed, by path. Never a folder or the whole suite.
- `dart format .` and `flutter analyze` before each commit. No emojis, no em-dashes.
- `lib/features/dive_log/presentation/widgets/dive_profile_chart.dart` is already 8300 lines: put new logic in new small files and keep the chart's edits to call sites.

## Review Focus

1. The pinned profile copy while time-only zoomed: its frame must show full depth (Task 1 test `withViewport keeps full depth for a time-only window`).
2. A continuous trackpad zoom in Time only, across several `panZoomUpdate`s: depth never moves and the gesture is not dropped (Task 4 test `trackpad zoom in Time only keeps the full depth window`).
3. A gentle 6 m dive whose rates never pass the critical threshold: the ascent-rate axis uses the floor span and every label is finite (Task 6 test `gentle dive labels use the floor span`).
4. Imperial units: ascent-rate labels in ft/min (Task 6 test `labels in feet per minute for an imperial diver`).
5. A diver whose Settings default is Ascent Rate with the bars off: the axis falls back to a drawn line, and to ascent rate only when only the bars are drawn (Task 6 resolver tests).

---

### Task 1: Depth zoom on ChartViewport

**Files:**
- Modify: `lib/core/ui/chart_viewport.dart`
- Modify: `lib/features/dive_log/presentation/widgets/profile_plot_frame.dart:49-61` and its `==`/`hashCode`
- Test: `test/core/ui/chart_viewport_test.dart`, `test/features/dive_log/presentation/widgets/profile_plot_frame_test.dart`

**Interfaces:**
- Produces: `ChartViewport({double zoom = 1, double? zoomY, double offsetX = 0, double offsetY = 0, double zoomLimit = maxZoom})` where `zoomY` defaults to `zoom`; getter `double get zoomY`; `visibleHeight => 1 / zoomY`; `isZoomed => zoom > 1 || zoomY > 1`; `zoomedAt(double focalX, double focalY, double factor, {bool timeOnly = false})`; `ChartViewport withFullDepth()` (returns `zoomY: 1, offsetY: 0`, same x window); `sameWindowAs` compares `zoomY`.

- [ ] **Step 1: Write the failing tests** in `chart_viewport_test.dart`:
  - `zoomY defaults to zoom`: `ChartViewport(zoom: 3).zoomY == 3`, `visibleHeight == 1/3`.
  - `timeOnly zoom leaves depth untouched`: `ChartViewport.reset.zoomedAt(0.5, 0.5, 2, timeOnly: true)` gives `zoom == 2`, `zoomY == 1`, `offsetY == 0`, `visibleHeight == 1`.
  - `timeOnly zoom keeps the time anchor`: from `reset`, `zoomedAt(0.25, 0.9, 4, timeOnly: true)`: `offsetX + 0.25 / 4 == 0.25` (closeTo 1e-12).
  - `both-axes zoom scales each factor independently`: `ChartViewport(zoom: 4, zoomY: 1).zoomedAt(0.5, 0.5, 2)` gives `zoom == 8`, `zoomY == 2`; then `.zoomedAt(0.5, 0.5, 2)` gives `zoom == 10` (limit), `zoomY == 4`.
  - `zoomY never exceeds zoom under both-axes zoom`: loop 30 random factors in [0.5, 2] from `ChartViewport(zoom: 5, zoomY: 1)`; each step `zoomY <= zoom + 1e-9`.
  - `vertical pan is a no-op at full depth`: `ChartViewport(zoom: 3, zoomY: 1).pannedBy(0.1, 0.3).offsetY == 0`.
  - `withFullDepth keeps the x window`: `ChartViewport(zoom: 3, zoomY: 3, offsetX: 0.4, offsetY: 0.5).withFullDepth()` gives `offsetX == 0.4`, `zoom == 3`, `zoomY == 1`, `offsetY == 0`.
  - `sameWindowAs sees zoomY`: `ChartViewport(zoom: 2).sameWindowAs(ChartViewport(zoom: 2, zoomY: 1))` is false.
  - `lerp interpolates depth edges`: `lerp(ChartViewport(zoom: 2, zoomY: 1), ChartViewport(zoom: 2, zoomY: 2), 0.5)` has `visibleHeight` closeTo 0.75.
  - existing anchor-invariant test still passes unchanged.
- [ ] **Step 2:** In `profile_plot_frame_test.dart` add `withViewport keeps full depth for a time-only window`: a frame at `ChartViewport.reset` over 0..2700 s and 0..30 m, `withViewport(ChartViewport(zoom: 3, zoomY: 1, offsetX: 0.5))` gives `minDepthMeters == 0`, `maxDepthMeters == 30`, `maxSeconds - minSeconds` closeTo 900. Add `frames differing only in zoomY are not equal`.
- [ ] **Step 3: Run** `flutter test test/core/ui/chart_viewport_test.dart test/features/dive_log/presentation/widgets/profile_plot_frame_test.dart`. Expected: the new tests fail (no `zoomY`).
- [ ] **Step 4: Implement.** `_clamped` clamps `offsetY` to `[0, 1 - 1/zoomY]` and each factor to `[minZoom, zoomLimit]`. Both-axes `zoomedAt` multiplies each factor by `factor`, clamps each, anchors each axis with its own factor, returns `this` when neither changed. `forWindow`, `withZoomLimit`, `pannedBy`, `centredOn`, `lerp` carry `zoomY` (lerp mixes `windowStart/End` and the vertical edges `offsetY`, `offsetY + 1/zoomY`). `ProfilePlotFrame.withViewport` uses `viewport.zoomY` / `other.zoomY` for the depth span; `==` and `hashCode` include `viewport.zoomY`.
- [ ] **Step 5: Run** the same command. Expected: PASS. Also run `flutter test test/features/insights/presentation/widgets/dive_trend_chart_test.dart` if it exists (Insights shares the class; it must be unchanged).
- [ ] **Step 6: Commit** `feat(dive-log): give the chart viewport its own depth zoom` with the four files.

### Task 2: Synced `profileZoomTimeOnly` setting

**Files:**
- Modify: `lib/core/database/tables/diver_tables.dart` (next to `profileMetricsFollowViewport`, line 453)
- Modify: `lib/core/database/migrations/helpers/diver_migrations.dart` (new `_assertProfileZoomTimeOnlyColumn`)
- Modify: `lib/core/database/migrations/ladder/rungs_v340_onward.dart` (`if (from < 389) ...` plus `reportProgress`)
- Modify: `lib/core/database/migrations/before_open_settings_columns.dart` (backstop call)
- Modify: `lib/core/database/database.dart` (`currentSchemaVersion = 389`; `migrationVersions` gains `389` with a comment)
- Modify: `lib/core/services/sync/sync_data_serializer.dart:11991` (`'profileZoomTimeOnly'` joins the diverSettings `_nullMeansUnsetKeys` set) and the doc line in `sync_record_overlay.dart`
- Modify: `lib/features/settings/data/repositories/diver_settings_repository.dart` (`unsetAdoptableColumns`, `adoptDeviceLocalValues`, the companion write near 769, the read near 1068)
- Modify: `lib/features/settings/presentation/providers/settings_providers.dart` (`SettingsKeys.profileZoomTimeOnly = 'profile_zoom_time_only'`, `AppSettings.profileZoomTimeOnly` default false with `copyWith`, prefs read and no-diver state, the adoption candidate, the `_prefsAreStore` pref write)
- Modify: `lib/features/settings/presentation/conflicts/catalogue/diver_settings_fields.dart` (`'profileZoomTimeOnly'` as `FieldKind.boolean`, label from Task 5's `settings_appearance_zoomTimeOnly_conflict`; until Task 5 lands use the existing `settings_appearance_metricsFollowViewport` label and switch it in Task 5)
- Test: `test/core/database/migration_v389_profile_zoom_time_only_test.dart` (new), `test/features/settings/data/repositories/diver_settings_repository_adoptable_prefs_test.dart`, `test/features/settings/synced_device_prefs_adoption_test.dart`, `test/core/services/sync/sync_diver_settings_device_prefs_test.dart`

**Interfaces:**
- Produces: `AppSettings.profileZoomTimeOnly` (bool, default false); repository `unsetAdoptableColumns` returns `({bool pscrRatio, bool profileMetricsFollowViewport, bool profileZoomTimeOnly})`; `adoptDeviceLocalValues(diverId, {double? pscrRatio, bool? profileMetricsFollowViewport, bool? profileZoomTimeOnly})`.

- [ ] **Step 1: Write the failing tests.**
  - New migration test, modelled on `migration_v359_pin_profile_on_scroll_test.dart`: `v389 is in the ladder` (`migrationVersions` contains 389; `migrationStepCount(386) == migrationStepCount(389) + 1`), `the column is additive and did not move the sync floor` (`minimumCompatibleSchemaVersion == 386`), `upgrading from v386 adds a null profile_zoom_time_only` (column exists, value is null), `beforeOpen heals a database already at v389 that lacks it`.
  - Adoptable prefs test: `profileZoomTimeOnly adopts only into a null column` (seed the column true via a sync-shaped write, adopt false: stays true; with the column null, adopt true: reads true and the row is marked pending).
  - Provider adoption test: `a Time only pick made before a diver exists is adopted` (prefs `profile_zoom_time_only = true`, no diver; then a diver loads: `settings.profileZoomTimeOnly` is true); `a default pref is not adopted` (pref false leaves the column null).
  - Sync test: `an explicit null profileZoomTimeOnly from a peer keeps ours`.
- [ ] **Step 2: Run** those four files. Expected: FAIL.
- [ ] **Step 3: Implement** following the `profileMetricsFollowViewport` pattern line for line: `BoolColumn get profileZoomTimeOnly => boolean().nullable()();`, helper adds `'profile_zoom_time_only', 'INTEGER'`, rung comment `// v389 (issue #5069): diver_settings.profile_zoom_time_only, the Time only zoom choice. Nullable, no backfill, re-asserted in beforeOpen; the floor does not move.` Then `dart run build_runner build --delete-conflicting-outputs` (unfiltered, in the background) for the Drift classes.
- [ ] **Step 4: Run** the four files plus `test/features/settings/presentation/providers/every_setter_waits_for_load_test.dart`. Expected: PASS.
- [ ] **Step 5: Commit** `feat(settings): sync a time-only profile zoom choice (schema 389)` with explicit paths.

### Task 3: `ProfileZoomMode` in settings and the legend session

**Files:**
- Create: `lib/core/constants/profile_zoom_mode.dart`
- Modify: `lib/features/settings/presentation/providers/settings_providers.dart` (`setProfileZoomMode`, `AppSettings.profileZoomMode` getter)
- Modify: `lib/features/dive_log/presentation/providers/profile_legend_provider.dart` (`zoomTimeOnly` field seeded from settings, `setZoomMode`, `zoomMode` getter)
- Modify: the concrete `SettingsNotifier` fakes: `test/helpers/mock_providers.dart`, `test/features/insights/presentation/pages/records_page_test.dart`, `test/features/settings/presentation/pages/settings_page_test.dart`, `test/features/settings/presentation/pages/settings_page_shared_data_test.dart`
- Test: `test/core/constants/profile_zoom_mode_test.dart` (new), `test/features/dive_log/presentation/providers/profile_legend_provider_test.dart`

**Interfaces:**
- Produces: `enum ProfileZoomMode { magnifyOverlays, keepOverlaysInView, timeOnly }` with `static ProfileZoomMode fromFlags({required bool timeOnly, required bool followViewport})`; `SettingsNotifier.setProfileZoomMode(ProfileZoomMode mode)`; `ProfileLegendState.zoomTimeOnly` (bool), `ProfileLegendState.zoomMode` getter; `ProfileLegend.setZoomMode(ProfileZoomMode mode)`. `setZoomMode(timeOnly)` sets only `zoomTimeOnly = true`; the two both-axes values set `zoomTimeOnly = false` and `metricsFollowViewport` to false / true. `toggleMetricsFollowViewport` is removed once Task 5 replaces its only caller.

- [ ] **Step 1: Write the failing tests:** `fromFlags` table (timeOnly wins over followViewport; else follow -> keepOverlaysInView; else magnify). Legend: `zoomTimeOnly seeds from settings`, `setZoomMode(timeOnly) keeps metricsFollowViewport`, `setZoomMode(keepOverlaysInView) clears zoomTimeOnly and sets follow`, `setZoomMode(magnifyOverlays) clears both`, `equality and hashCode include zoomTimeOnly`. Settings: `setProfileZoomMode(timeOnly) leaves profileMetricsFollowViewport alone` in the existing settings provider test that covers `setProfileMetricsFollowViewport`.
- [ ] **Step 2: Run** those files. Expected: FAIL.
- [ ] **Step 3: Implement.** `profileLegendProvider.build` selects `profileZoomTimeOnly` alongside `profileMetricsFollowViewport`.
- [ ] **Step 4: Run.** Expected: PASS.
- [ ] **Step 5: Commit** `feat(dive-log): one zoom mode for the profile chart session and settings`.

### Task 4: Time-only zoom in the chart

**Files:**
- Modify: `lib/features/dive_log/presentation/widgets/dive_profile_chart.dart`: a `_zoomTimeOnly` field synced in `build` next to `_metricsFollowViewport` (line 3245); a helper `ChartViewport _zoomBy(ChartViewport vp, double fx, double fy, double factor) => vp.zoomedAt(fx, fy, factor, timeOnly: _zoomTimeOnly)` used by the trackpad handler (~3512), wheel (~3727), touch pinch (~3856), double-tap (~3884), `_zoomIn`/`_zoomOut` (~3174); the mouse-drag pan (~3624) and touch-pinch pan (~3858) divide the vertical delta by `zoomY`; a `ref.listen` on `profileLegendProvider.select((s) => s.zoomTimeOnly)` that applies `_viewport = _viewport.withFullDepth()` when it turns true.
- Test: `test/features/dive_log/presentation/widgets/dive_profile_chart_time_only_zoom_test.dart` (new; harness copied from `dive_profile_chart_zoom_window_test.dart`, with a `_TestSettingsNotifier` whose state has `profileZoomTimeOnly: true`, and no `exportKey`)

**Interfaces:**
- Consumes: Task 1 `zoomedAt(..., timeOnly:)`, `withFullDepth()`, `zoomY`; Task 3 `ProfileLegendState.zoomTimeOnly`.

- [ ] **Step 1: Write the failing tests** (read the window with `onViewportChanged` or the LineChart's `minY`/`maxY`):
  - `wheel zoom in Time only keeps the full depth window`: 10 wheel clicks; `minY`/`maxY` equal the 1x values, `maxX - minX` shrinks.
  - `zoom buttons in Time only scale time only`.
  - `double-tap in Time only zooms time only`.
  - `trackpad zoom in Time only keeps the full depth window`: `createGesture(kind: trackpad)`, `panZoomStart`, five `panZoomUpdate(scale: 1.2 * i)` each followed by `pump()`, `panZoomEnd`; depth window unchanged, time zoom > 2.
  - `vertical mouse drag in Time only does not move depth` after zooming.
  - `switching to Time only while zoomed snaps depth to full and keeps the time window`: start both-axes, wheel-zoom, then `container.read(profileLegendProvider.notifier).setZoomMode(ProfileZoomMode.timeOnly)`, pump; depth full, x window unchanged.
  - `both-axes zoom still scales depth` (regression, mode magnify).
- [ ] **Step 2: Run** the new file. Expected: FAIL.
- [ ] **Step 3: Implement** as in Files. `_zoomNotifier.value` stays `value.zoom` (spec: `zoomY <= zoom`).
- [ ] **Step 4: Run** the new file plus `dive_profile_chart_zoom_window_test.dart`, `dive_profile_chart_gestures_test.dart`. Expected: PASS.
- [ ] **Step 5: Commit** `feat(dive-log): zoom the profile chart's time axis alone`.

### Task 5: Zoom choice in chart options and Settings

**Files:**
- Modify: `lib/features/dive_log/presentation/widgets/chart_options_dialog_rows.dart` (new `buildMenuRow(BuildContext context, {required String label, required String value, required VoidCallback onTap, Key? key})`: label left, value and a dropdown chevron right, one `InkWell`, semantics as a button with the value)
- Modify: `lib/features/dive_log/presentation/widgets/chart_options_dialog.dart:670-690` (Display: a Zoom `buildMenuRow` replaces the `metricsFollowViewport` item; tap opens `showMenu` with the three `ProfileZoomMode` values, the current one checked, calling `legendNotifier.setZoomMode`)
- Create: `lib/features/dive_log/presentation/widgets/profile_zoom_mode_labels.dart` (`String profileZoomModeLabel(AppLocalizations l10n, ProfileZoomMode mode)`)
- Modify: `lib/features/settings/presentation/pages/section_appearance_page.dart:588-600` (the switch becomes a `ListTile` with `LabelWithControl` and a `DropdownButton<ProfileZoomMode>`, like the Right Y-axis metric row above it, calling `setProfileZoomMode`)
- Modify: all 12 `lib/l10n/arb/app_*.arb`: `diveLog_chartOption_zoom` ("Zoom"), `diveLog_chartOption_zoom_magnify` ("Both axes, magnify overlays"), `diveLog_chartOption_zoom_keepInView` ("Both axes, keep overlays in view"), `diveLog_chartOption_zoom_timeOnly` ("Time only"), `settings_appearance_profileZoom` ("Zoom"), `settings_appearance_profileZoom_subtitle` ("What zooming the dive profile scales"), `settings_appearance_zoomTimeOnly_conflict` ("Profile zoom: time only"); retire `diveLog_chartOption_metricsFollowViewport` and `settings_appearance_metricsFollowViewport_subtitle` only if no caller remains (the conflict field keeps `settings_appearance_metricsFollowViewport`).
- Modify: `diver_settings_fields.dart` label for `profileZoomTimeOnly` to `settings_appearance_zoomTimeOnly_conflict`
- Test: `test/features/dive_log/presentation/widgets/chart_options_zoom_mode_test.dart` (new), `test/features/settings/presentation/pages/section_appearance_page_test.dart`

- [ ] **Step 1: Write the failing tests:** chart options `Display shows Zoom with the session value`, `picking Time only sets the legend's zoom mode`, `the Keep overlays in view checkbox is gone`; settings page `Dive Profile shows a Zoom dropdown with three values` and `choosing Time only calls setProfileZoomMode(timeOnly)` (MockSettingsNotifier records the call).
- [ ] **Step 2: Run** both files. Expected: FAIL.
- [ ] **Step 3: Implement**, add the strings (translated, per locale group), `flutter gen-l10n`.
- [ ] **Step 4: Run** both files plus the chart options tests that referenced the old row (`grep -l metricsFollowViewport test/features/dive_log/presentation/widgets/*.dart`, by path). Expected: PASS.
- [ ] **Step 5: Commit** `feat(dive-log): one Zoom choice in chart options and Settings`.

### Task 6: Ascent rate on the right axis

**Files:**
- Modify: `lib/features/dive_log/presentation/widgets/profile_right_axis_resolver.dart` (ascent rate is the last fallback: after `fallbackPriority` and the declaration-order loop, return `ascentRate` if drawn)
- Create: `lib/features/dive_log/presentation/widgets/ascent_rate_axis_scale.dart` with `double ascentRateAtAxisValue(double axisValue, {required double axisMin, required double axisMax, required double maxAbsRate})` (the bars' plot-relative scale: `maxAbsRate * (2 * (axisValue - axisMin) / (axisMax - axisMin) - 1)`, so the top edge is `+maxAbsRate`, the middle 0, the bottom `-maxAbsRate`; returns 0 for a zero-height axis)
- Modify: `dive_profile_chart.dart`: in `rightTitles.getTitlesWidget` (~4759) an `ascentRate` branch uses `ascentRateAtAxisValue(value, axisMin: meta.min, axisMax: meta.max, maxAbsRate: _ascentRateAxisRange(widget.ascentRates)!.max)` and `formatRightAxisTick` with a sign; the axis menu stops filtering `ascentRate` (~5662); where the bars' hover sets `_hoveredAscentRateTimestamp` (~5100), set `_hoverRightAxisMetric = ProfileRightAxisMetric.ascentRate` unless `rightAxisHidden`, and clear it with the hover.
- Test: `test/features/dive_log/presentation/widgets/profile_right_axis_resolver_test.dart`, `test/features/dive_log/presentation/widgets/ascent_rate_axis_scale_test.dart` (new), `test/features/dive_log/presentation/widgets/dive_profile_chart_ascent_rate_axis_test.dart` (new)

- [ ] **Step 1: Write the failing tests:**
  - Resolver: `ascent rate is the last fallback` (only ascent rate drawn returns it); `a drawn line beats ascent rate` (temperature hidden, heart rate and ascent rate drawn returns heart rate); `preferred ascent rate with bars off falls back` (returns a drawn line).
  - Scale: `top is +max, middle 0, bottom -max` for axis -30..0, max 12; `zero-height axis returns 0`.
  - Chart: `the axis menu offers Ascent Rate when the dive has rates`; `picking Ascent Rate labels 0 at mid-plot` (find the `0` label and assert its y is within 2 px of the plot centre); `gentle dive labels use the floor span` (6 m dive, top label equals `AscentRateCalculator.defaultCriticalThreshold * 1.25` formatted, all labels parse as finite); `labels in feet per minute for an imperial diver`; `hovering the bars switches the axis to ascent rate`; `hovering the bars does not bring back a None axis`.
- [ ] **Step 2: Run** the three files plus `dive_profile_chart_right_axis_follows_lines_test.dart`. Expected: new tests FAIL.
- [ ] **Step 3: Implement** as in Files.
- [ ] **Step 4: Run** the same files plus `dive_profile_chart_right_axis_ticks_test.dart`. Expected: PASS.
- [ ] **Step 5: Commit** `feat(dive-log): ascent rate as a right-axis scale that matches its bars`.

### Task 7: Right axis row in chart options

**Files:**
- Create: `lib/features/dive_log/presentation/widgets/right_axis_metric_menu.dart` with `typedef RightAxisChoice = ({ProfileRightAxisMetric metric, Color color});` and `Future<void> showRightAxisMetricMenu(BuildContext context, {required RelativeRect position, required List<RightAxisChoice> choices, required ProfileRightAxisMetric? current, required void Function(ProfileRightAxisMetric metric) onPick, required VoidCallback onNone})` (the body of `_showRightAxisMetricSelector`, unchanged in look: None, divider, category headers, checked current)
- Modify: `dive_profile_chart.dart`: `_showRightAxisMetricSelector` calls `showRightAxisMetricMenu`; the legend config gets the choices and the shown metric
- Modify: `lib/features/dive_log/presentation/widgets/profile_legend_config.dart` (`final List<RightAxisChoice> rightAxisChoices; final ProfileRightAxisMetric? shownRightAxisMetric;`, defaults `const []` and null, in `==`/`hashCode` if the class has them)
- Modify: `chart_options_dialog.dart` Display section: a Right axis `buildMenuRow` under Zoom, value `profileMetricName(l10n, shown)` or `diveLog_profile_rightAxis_none`, shown only when `rightAxisChoices` is not empty; tap opens `showRightAxisMetricMenu` positioned at the row, `onPick: legendNotifier.setRightAxisMetric`, `onNone: legendNotifier.hideRightAxis`
- Modify: 12 ARB files: `diveLog_chartOption_rightAxis` ("Right axis")
- Test: `test/features/dive_log/presentation/widgets/chart_options_right_axis_test.dart` (new)

- [ ] **Step 1: Write the failing tests:** `the row shows what the axis shows` (temperature hidden, axis on heart rate: row reads "Heart Rate"); `the row reads None after None is chosen`; `picking a metric from the row restores the axis` (after None, pick Temperature: chart shows the "Temp" axis name again and the row reads "Temperature"); `the row reads None when only depth is drawn`; `no row when the dive has no right-axis metric`.
- [ ] **Step 2: Run** the new file plus `profile_legend_right_axis_pick_test.dart`. Expected: new tests FAIL.
- [ ] **Step 3: Implement** as in Files; strings translated; `flutter gen-l10n`.
- [ ] **Step 4: Run** the same files plus `dive_profile_chart_right_axis_follows_lines_test.dart`. Expected: PASS.
- [ ] **Step 5: Commit** `feat(dive-log): bring the right axis back from chart options`.

### Task 8: After screenshots and final checks

- [ ] **Step 1:** Copy the scratchpad harness back to `test/_pr_shots/`, extend it with the Time only zoomed chart, the axis menu with Ascent Rate, the ascent-rate axis, and the Display section with Zoom and Right axis (desktop and phone), and the Settings Zoom row; run with `--dart-define=STAGE=after --update-goldens`.
- [ ] **Step 2:** Copy the PNGs to the scratchpad, `pngquant` them, delete `test/_pr_shots/` (never staged).
- [ ] **Step 3:** `dart format .`, `flutter analyze` (whole repo, clean), and every test file this plan created or changed, by path.
