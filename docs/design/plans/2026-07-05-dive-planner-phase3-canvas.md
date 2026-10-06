# Dive Planner Phase 3: Live Profile Canvas UI — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the 3-tab planner page with the approved Live Profile Canvas (chart-centric, live recalc, results in a swipe-up sheet, adaptive to wide screens), driven by Phase 2's `PlanEngine`, plus a saved-plans surface — then cut the route over.

**Architecture:** New UI lives in `lib/features/planner/presentation/` (the Phase 2 module). Editing state stays on the existing `divePlanNotifierProvider` (all editing panels — `PlanSettingsPanel`, `PlanTankList`, `SegmentList` — are self-contained ConsumerWidgets and embed as-is). All DISPLAYED numbers come from a new `planOutcomeProvider` (PlanEngine), not the legacy `planResultsProvider`. Branch: stacked on `worktree-dive-planner-phase2-domain` (PR #485).

**Tech Stack:** fl_chart (inverted-Y convention from `plan_profile_chart.dart`), `ResponsiveBreakpoints`, `DraggableScrollableSheet`, `testApp` widget-test helper, `flutter gen-l10n` with 11 ARB locales.

**Spec:** `docs/superpowers/specs/2026-07-05-dive-planner-redesign-design.md` ("Planner UI — Live Profile Canvas (Phase 3)"). Mockup approved 2026-07-05 (Live Profile Canvas, option A).

## Global Constraints

- Every user-facing string is a NEW l10n key `plannerCanvas_<category>_<name>` added to `lib/l10n/arb/app_en.arb` AND hand-translated into all 10 non-en locales (ar, de, es, fr, he, hu, it, nl, pt, zh), keys alphabetical, then `flutter gen-l10n`. No hardcoded UI strings.
- All displayed values respect unit settings via `UnitFormatter(settings)` (depth symbols, pressure).
- Deferred per spec: direct waypoint drag-editing, tissue bars in the sheet, contingency ghost overlays (Phase 5), CCR toggle (Phase 4). The chart's ceiling overlay is the segment-end/stop approximation (exact per-sample envelope arrives with profile-grade timelines later).
- Old editing widgets are REUSED (settings/tanks/segments/segment-editor dialogs); old page + results/chart widgets are deleted at cutover (`dive_planner_page.dart`, `deco_results_panel.dart`, `gas_results_panel.dart`, `plan_profile_chart.dart`) along with `plannerTabIndexProvider`.
- `dart format .`, whole-project `flutter analyze`, specific-file test runs; commit per task; no Co-Authored-By.

---

### Task 1: Canvas data layer — `planOutcomeProvider` + `PlanCanvasSeries`

**Files:**
- Create: `lib/features/planner/presentation/providers/plan_canvas_providers.dart`
- Test: `test/features/planner/plan_canvas_providers_test.dart`

**Interfaces (later tasks consume exactly these):**

```dart
final planEngineConfigProvider = Provider<PlanEngineConfig>;   // from settings
final planOutcomeProvider = Provider<PlanOutcome>;             // PlanEngine on current state
final scrubTimeProvider = StateProvider<double?>((_) => null); // seconds, null = no cursor
final planResultsSheetSectionProvider = StateProvider<int>((_) => 0);

class CanvasPoint { final double timeSeconds; final double depth; }
class CanvasMarker { final double timeSeconds; final double depth; final String label; }
class PlanCanvasSeries {
  final List<CanvasPoint> profile;      // segments + computed ascent tail
  final List<CanvasPoint> ceiling;      // approximate envelope, may be empty
  final List<CanvasMarker> gasSwitches; // where the ascent gas changes
  final List<CanvasMarker> stopLabels;  // "9m·6'" style, one per stop
  final double maxTimeSeconds; final double maxDepth;
}
final planCanvasSeriesProvider = Provider<PlanCanvasSeries>;
```

**Implementation:**
- `planEngineConfigProvider`: `PlanEngineConfig(ppO2Working: ref.watch(ppO2MaxWorkingProvider), ppO2Deco: ref.watch(ppO2MaxDecoProvider), cnsWarningThreshold: ref.watch(cnsWarningThresholdProvider), o2Narcotic: <o2Narcotic settings provider — grep settings_providers.dart for the exact name; if none exists, default true>)`.
- `planOutcomeProvider`: `PlanEngine(config: ref.watch(planEngineConfigProvider)).compute(divePlanFromState(ref.watch(divePlanNotifierProvider)))`.
- `planCanvasSeriesProvider` builds from state segments (sorted by order: points at each segment start/end using cumulative runtime) then appends the ascent tail from `outcome.stops`: for each stop, a point at `(arrivalRuntimeSeconds, depthMeters)` and `(arrival + durationSeconds, depthMeters)`; final point at `(outcome.runtimeSeconds, 0)`. Ceiling: `(endRuntime, ceilingAtEnd)` per SegmentOutcome (skip zeros before the first nonzero) + `(arrival, depthMeters)` per stop. Gas switches: first stop whose gas differs from the last segment's gas + each stop whose gas differs from the previous stop; label via `GasMix(o2: fO2*100, he: fHe*100).name`. Stop labels: every stop, `"${depth}m·${ceil(min)}'"` composed in the WIDGET with l10n/units (series stores raw numbers: marker label may stay data-only here — put gas NAME in the marker since it is unit-free, and let stopLabels carry the raw values via label built in widget; simplest: series stores gas-name markers and stop markers with empty label + widget formats).

- [ ] Write failing unit tests: simple 30 m/25 min air plan → profile starts at (0,0), is monotonic in time, last point is (runtimeSeconds, 0); deco plan (45 m/25 min) → profile contains a flat sub-sequence per stop and stop markers count == stops count; trimix + EAN50/O2 plan → gasSwitches non-empty and located at ≤ 22 m depths; scrub provider defaults null. Use a `ProviderContainer` with `settingsProvider.overrideWith(_TestSettingsNotifier)` (copy the stub from `save_load_round_trip_test.dart`).
- [ ] Implement; run `flutter test test/features/planner/plan_canvas_providers_test.dart` → PASS.
- [ ] `dart format .` + commit `feat(planner): canvas data providers on PlanEngine`.

---

### Task 2: The canvas chart — `PlanCanvasChart`

**Files:**
- Create: `lib/features/planner/presentation/widgets/plan_canvas_chart.dart`
- Test: `test/features/planner/plan_canvas_chart_test.dart`

**Spec:** ConsumerWidget watching `planCanvasSeriesProvider`, `scrubTimeProvider`, `selectedSegmentIdProvider`, `settingsProvider` (units). Follow `plan_profile_chart.dart`'s conventions exactly (negative-Y depth, `_calculateInterval`, axis titles, bounds `minX:0/maxX*1.05/minY:-maxDepth*1.1/maxY:0`) with these additions:

1. **Profile line**: single `LineChartBarData` (primary color, gradient belowBar) built from `series.profile` (x = seconds/60).
2. **Ceiling overlay**: second `LineChartBarData` from `series.ceiling`, `dashArray: [4, 4]`, `colorScheme.error` at 70% opacity, no fill, hidden when empty.
3. **Gas-switch markers**: `ExtraLinesData(verticalLines:)` — one `VerticalLine` per `series.gasSwitches` with `VerticalLineLabel(show: true, labelResolver: (_) => marker.label)` (pattern: `dive_profile_chart.dart:4288-4330`).
4. **Scrub cursor**: `lineTouchData.touchCallback` — on drag/tap events store `response.lineBarSpots?.first.x * 60` into `scrubTimeProvider` and clear it on `FlPanEndEvent`/`FlTapUpEvent`/`FlPointerExitEvent` (pattern: `dive_profile_chart.dart:2251-2292`); when scrubTime != null add a grey dashed `VerticalLine` at it; suppress default tooltips (`handleBuiltInTouches: false` + custom `getTouchedSpotIndicator` returning subtle indicators).
5. **Scrub readout**: a small overlay chip (top-left inside the chart's Stack) shown when scrubbing: `RT {min}' · {depth}{unit}` — depth interpolated from `series.profile` at the scrub time. Style like `_StatChip` (`plan_profile_chart.dart:306`).
6. **Segment selection**: on `FlTapUpEvent`, map the tapped time to the covering user segment (cumulative durations from state.segments) and set `selectedSegmentIdProvider`; taps beyond the last segment clear it.
7. Empty state: reuse the empty-Card idiom with `plannerCanvas_empty_title` / `_subtitle` keys and a Quick Plan button setting `showSimplePlanDialogProvider`.

- [ ] Widget tests (via `testApp`): with a seeded notifier (use `divePlanNotifierProvider.notifier` in the container to `addSimplePlan(maxDepth: 45, bottomTimeMinutes: 25)` inside `overrides`-free pump then `pumpAndSettle`): `LineChart` renders; empty plan shows the empty-state title. (Interaction-level scrub tests are impractical in fl_chart unit tests — cover the time→segment mapping and profile interpolation as pure functions exported from the widget file and unit-test those directly.)
- [ ] Implement; run the test file → PASS; format + commit `feat(planner): live canvas chart with ceiling, switches, and scrub`.

---

### Task 3: Status chips + results sheet

**Files:**
- Create: `lib/features/planner/presentation/widgets/plan_status_chips.dart`
- Create: `lib/features/planner/presentation/widgets/plan_results_sheet.dart`
- Test: `test/features/planner/plan_results_widgets_test.dart`

**`PlanStatusChips`** (ConsumerWidget, horizontal `Wrap`): RT (runtimeSeconds, highlighted), TTS (ttsAtBottom or NDL when not in deco: show `NDL {min}'` if ndlAtBottom >= 0 else `TTS {min}'`), Deco (`totalDecoSeconds`, hidden when 0), CNS (`cnsEnd`%, warn-tinted ≥ warning threshold), Issues chip (`{n} issues`, tinted by the max severity color, hidden when 0; `onTap` callback provided by the page to open the sheet). Chip visual = `_StatChip` pill pattern.

**`PlanResultsSheet`** — the CONTENT column (the page owns the `DraggableScrollableSheet`); takes a `ScrollController`. Sections, each a labeled header:
1. **Runtime table**: header row (Depth / Stop / Runtime / Gas) + one row per `PlanStop`: depth (units), `ceil(duration/60)'` (+ small `+{airBreak}'` suffix when airBreakSeconds > 0), `arrival+duration` runtime minutes, gas name (`GasMix.name`). Empty → `plannerCanvas_results_noDeco` row.
2. **Gas**: per `PlanTankUsage` row: tank name (lookup in state.tanks) + gas name, liters used (rounded), remaining pressure (units; `error` color when reserveViolation, plain otherwise), percent bar (`LinearProgressIndicator`).
3. **Issues**: severity-styled rows modeled on `_WarningRow` (`deco_results_panel.dart:292-338`): critical → `Icons.error`/`colorScheme.error`; alert → `Icons.warning`/orange; warning → `Icons.warning_amber`/orange; info → `Icons.info_outline`. Message text: `PlanIssue.message` is engine-composed English — for l10n, map `PlanIssueType` → localized template (same approach as `_formatWarningMessage`, `deco_results_panel.dart:340`) using `issue.value`/`issue.threshold`; fall back to `issue.message` for safety.

- [ ] Widget tests: seeded deco plan → chips show a TTS value and an issues count; sheet shows ≥1 runtime row, a gas row with remaining pressure text, and (for a 45 m air plan) a critical gas-density issue row rendered with the error icon. 
- [ ] Implement; test file PASS; format + commit `feat(planner): status chips and results sheet on PlanOutcome`.

---

### Task 4: Saved-plans sheet + app-bar actions

**Files:**
- Create: `lib/features/planner/presentation/widgets/saved_plans_sheet.dart`
- Test: `test/features/planner/saved_plans_sheet_test.dart`

**`SavedPlansSheet`** (shown via `showModalBottomSheet`): watches `divePlanSummariesProvider`. Each tile: name, relative updated date, trailing summary chips (max depth in units, runtime min, TTS min when present), `onTap` → `context.pop()` then `context.go('/planning/dive-planner/${summary.id}')`; trailing `PopupMenuButton` with Duplicate (repository.duplicatePlan) and Delete (confirm `AlertDialog`, then repository.deletePlan). Empty state text. Loading via `AsyncValue.when` BUT render stale data during reload (`asyncValue.value` pattern per project memory — avoid the spinner flash).

- [ ] Widget tests (FK-ON test DB via `setUpTestDatabase` + `testApp`): with two saved plans (insert via `DivePlanRepository`), the sheet lists both names newest-first; delete flow removes one after confirm (verify repository count).
- [ ] Implement; PASS; format + commit `feat(planner): saved plans sheet`.

---

### Task 5: Page assembly + adaptive layout + route cutover

**Files:**
- Create: `lib/features/planner/presentation/pages/plan_canvas_page.dart`
- Modify: `lib/core/router/app_router.dart` (routes `divePlanner` + `editPlan` → `PlanCanvasPage`)
- Delete: `lib/features/dive_planner/presentation/pages/dive_planner_page.dart`, `.../widgets/deco_results_panel.dart`, `.../widgets/gas_results_panel.dart`, `.../widgets/plan_profile_chart.dart`; remove `plannerTabIndexProvider` from `dive_planner_providers.dart`.
- Test: `test/features/planner/plan_canvas_page_test.dart`

**`PlanCanvasPage`** (`ConsumerStatefulWidget`, `{String? planId}`):
- `initState`: the same `Future.microtask(loadPlanById)` block as the old page (copy from `dive_planner_page.dart:43-64` before deleting it).
- **AppBar**: title = plan name (tap → rename dialog with a `TextField`, `updateName`); an `OC` badge chip; actions: save icon (ports `_savePlan` from the old page but summary numbers from `planOutcomeProvider`: maxDepth/runtimeSeconds/ttsAtBottom), overflow `PopupMenuButton` {Quick plan → `SimplePlanDialog`, Saved plans → `SavedPlansSheet`, New plan → confirm-if-dirty then `newPlan()`, Plan settings → modal sheet embedding `PlanSettingsPanel`, Convert to dive → port `_convertToDive` verbatim from the old page}.
- **Phone body** (`ResponsiveBreakpoints.isMobile`): `Stack[ Column[ SizedBox(h: 42% of height, child: PlanCanvasChart), PlanStatusChips, Expanded(ListView[SegmentList(), PlanTankList()]) ], DraggableScrollableSheet(minChildSize: .08, initialChildSize: .08, maxChildSize: .85, snap: true, builder: (ctx, ctrl) => Material(elevation, rounded top) > PlanResultsSheet(controller: ctrl)) ]`. The Issues chip's onTap animates the sheet controller (keep a `DraggableScrollableController`).
- **Wide body** (≥ `ResponsiveBreakpoints.desktop`): `Row[ SizedBox(360, ListView[PlanSettingsPanel(), PlanTankList(), SegmentList()]), VerticalDivider, Expanded(Column[Expanded(PlanCanvasChart), PlanStatusChips, SizedBox(h:240, PlanResultsSheet(controller: ScrollController()))]) ]` — the sheet content doubles as the always-visible results pane; no Stack/sheet.
- **Cutover**: router lines 205-217 swap `DivePlannerPage` → `PlanCanvasPage` (import swap); delete the four old files; fix any remaining imports (`grep -rn "dive_planner_page\|DecoResultsPanel\|GasResultsPanel\|PlanProfileChart" lib/ test/`); delete tests that exclusively covered deleted widgets (check `test/features/dive_planner/`), keep everything else green.

- [ ] Widget tests: page pumps with a simple plan → shows chart + chips + segment list (phone size via `tester.view.physicalSize`); wide size (1400×900 logical) shows `PlanSettingsPanel` and NO `DraggableScrollableSheet`; save action invokes notifier.save (verify `isDirty` false after tap with test DB).
- [ ] Run `flutter test test/features/planner/ test/features/dive_planner/` — all green (old page tests removed/adjusted).
- [ ] Format + commit `feat(planner): Live Profile Canvas page and route cutover`.

---

### Task 6: l10n — keys in en + 10 locales

**Files:** all 11 `lib/l10n/arb/app_*.arb`.

- [ ] Collect every `plannerCanvas_*` key used by Tasks 2-5 (grep `l10n.plannerCanvas_` across `lib/features/planner/`). Expected ≈ 25-35 keys: empty state, chip labels (RT/TTS/NDL/Deco/CNS/issues), sheet section headers (Runtime table/Gas/Issues), runtime table column headers, no-deco row, saved-plans sheet (title, empty, duplicate, delete, delete-confirm title/body), rename dialog, menu items (quick plan/saved plans/new plan/plan settings/convert), unsaved-changes confirm, issue-type message templates (one per `PlanIssueType`, with `{value}`/`{threshold}`/`{depth}` placeholders where needed — add `@`-metadata ONLY for keys with placeholders).
- [ ] Add to `app_en.arb` alphabetically; translate into ar/de/es/fr/he/hu/it/nl/pt/zh following the chinese-localization plan rules (translate human text only, never placeholder names; alphabetical; no description-only metadata copies).
- [ ] `flutter gen-l10n` then `flutter analyze` (missing-key errors surface here) and re-run `flutter test test/features/planner/`.
- [ ] Format + commit `feat(planner): localize the canvas UI in all locales`.

---

### Task 7: Verification sweep

- [ ] `flutter analyze` clean; `dart format .` no changes.
- [ ] `flutter test test/features/planner/ test/features/dive_planner/` and `flutter test test/core/deco/` green; run any router/navigation test files that reference `/planning` (grep `test/` for `dive-planner`).
- [ ] Manual smoke note for the PR: run `flutter run -d macos`, open Planning → Dive Planner, quick-plan 45 m/25 min, observe live chart + chips + sheet; save; reopen via Saved plans.
- [ ] Commit anything outstanding.

## Explicitly out of scope (later phases)

Contingency ghost overlays and one-tap deviations (5); CCR toggle/badge switching and bailout scrub (4); tissue bars in the sheet and per-sample ceiling envelope; hub restyle + calculators (7); plan compare/slate/share (7); waypoint drag-editing (deferred indefinitely per spec).
