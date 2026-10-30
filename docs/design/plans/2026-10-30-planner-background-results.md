# Planner Background Results Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stop plan edits running the range table, bailout solver and expanded contingencies on the UI isolate, with stale figures always marked.

**Architecture:** Four providers become settled `FutureProvider`s that run the existing pure services through an injectable runner (default `Isolate.run`), following `missionOutcomeProvider`. Each result carries the id of the plan it was computed for, and one pure function turns an `AsyncValue` into a value plus a display status, used by both the sheet and the chart.

**Tech Stack:** Flutter, Riverpod 3 (through `package:submersion/core/providers/provider.dart`), Dart isolates, ARB l10n.

**Spec:** `docs/design/specs/2026-10-30-planner-background-results-design.md`

## Global Constraints

- No em dashes anywhere, and no mention of the tool that wrote this, in code, comments, commits or the PR.
- Settle delay: 150 ms.
- `PlanEngine`, `ContingencyService` and `RangeTableService` do not change. `BailoutSolver` changes only to call the shared gate.
- `planOutcomeProvider`, `planIsValidProvider`, `activePlanOutcomeProvider`, `selectedContingencyProvider`, `planBestMixProvider` and `missionOutcomeProvider`'s behaviour do not change.
- Results are equal to a direct service call, not close. No cell, row or seed is dropped.
- Status is text, never dimming alone.
- Files stay within 800 lines. `plan_canvas_providers.dart` must shrink, not grow.
- Every new string goes in all 11 ARB files, inserted beside `plannerCanvas_results_noDeco`, then `flutter gen-l10n`, with the generated files committed.
- `test/features/planner/tmp_shot_test.dart`, `tmp_drag_bench_test.dart` and `goldens/` beside them are throwaway. Never stage them. Stage explicit paths only.
- Before each commit: `dart format` on touched files, `flutter analyze`, affected tests. Run `test/architecture/` and `test/shared/` after adding files under `lib/`.

## Review Focus

Each line has its test in the named task.

1. Exporting a slate within the settle window after an edit: the slate carries the new figures, not the previous ones (Task 6).
2. Opening another plan while a run for the first is in flight: the first plan's figures never appear, not even dimmed (Task 3).
3. A run fails, then the diver edits again: the status returns to pending and then current, it does not stay failed (Task 2, Task 3).
4. In Bailout view, removing the last bailout tank: the old line goes on that frame, with no label (Task 5).
5. A Settings change that alters the deco model while results are showing: the sections go pending and recompute, as an edit does (Task 3).

---

### Task 1: Convert logs the live plan, whatever the chart shows

**Files:**
- Modify: `lib/features/planner/presentation/providers/plan_canvas_providers.dart`
- Modify: `lib/features/planner/presentation/pages/plan_canvas_page.dart:755`
- Test: `test/features/planner/convert_to_dive_test.dart`

**Interfaces:**
- Produces: `planLiveCanvasSeriesProvider`, `Provider<PlanCanvasSeries>`, the live plan's series regardless of `chartDisplayModeProvider`. `planCanvasSeriesProvider` watches it.

- [ ] **Step 1: Write the failing test** `converting a loop plan from Bailout view logs the live profile`: seed a CCR plan with a bailout tank, set `chartDisplayModeProvider` to `ChartDisplayMode.bailout`, convert, and assert the saved dive's `profile` equals `container.read(planLiveCanvasSeriesProvider).profile` mapped to `DiveProfilePoint`s and differs from the bailout series.
- [ ] **Step 2: Run it.** `flutter test test/features/planner/convert_to_dive_test.dart`. Expected: FAIL, the provider does not exist.
- [ ] **Step 3: Extract the live branch of `planCanvasSeriesProvider` into `planLiveCanvasSeriesProvider`, and read it at `plan_canvas_page.dart:755`.**
- [ ] **Step 4: Run it.** Expected: PASS, and `test/features/planner/chart/` still passes.
- [ ] **Step 5: Commit** as `fix(planner): log the live plan when converting from Bailout view`.

### Task 2: Result types, status mapping and the runner seam

**Files:**
- Create: `lib/features/planner/presentation/providers/plan_background_results.dart`
- Create: `test/helpers/planner_results.dart`
- Test: `test/features/planner/plan_background_results_test.dart`

**Interfaces:**
- Produces, all in `plan_background_results.dart`:
  - `class PlanResult<T> { final String planId; final T value; }`
  - `enum PlanResultStatus { current, updating, calculating, failed }`
  - `class PlanResultView<T> { final T? value; final PlanResultStatus status; bool get isMarked => status != PlanResultStatus.current; }`
  - `PlanResultView<T> planResultView<T>(AsyncValue<PlanResult<T>> result, String planId)`
  - `PlanResultStatus combinePlanResultStatus(PlanResultStatus a, PlanResultStatus b)`, the more severe of two: failed, calculating, updating, current.
  - `typedef PlanComputation<T> = T Function(domain.DivePlan plan, TissueState? startState, PlanEngineConfig config);`
  - `abstract interface class PlanResultRunner { Future<T> run<T>(PlanComputation<T> computation, domain.DivePlan plan, TissueState? startState, PlanEngineConfig config); }`
  - `class IsolatePlanResultRunner implements PlanResultRunner`, `Isolate.run` from a method that captures only its parameters, so no `ref` reaches the closure's context.
  - `final planResultRunnerProvider = Provider<PlanResultRunner>(...)`, default `IsolatePlanResultRunner`.
  - `final planResultsSettleDelayProvider = Provider<Duration>(...)`, default 150 ms.
- Produces, in `test/helpers/planner_results.dart`: `class InlinePlanResultRunner implements PlanResultRunner` and `List<dynamic> plannerResultsInline()` returning overrides for zero settle and the inline runner.

- [ ] **Step 1: Write failing tests of `planResultView`:**

| Input | Expected `value`, `status` |
| --- | --- |
| `AsyncData(PlanResult('p', 1))`, id `p` | 1, current |
| loading with previous `PlanResult('p', 1)`, id `p` | 1, updating |
| loading, no previous | null, calculating |
| loading with previous `PlanResult('other', 1)`, id `p` | null, calculating |
| `AsyncData(PlanResult('other', 1))`, id `p` | null, calculating |
| error, no previous | null, failed |
| error with previous `PlanResult('p', 1)` | 1, failed |
| error then reloading, previous `PlanResult('p', 1)` | 1, updating |
| error then reloading, no previous | null, calculating |

  `copyWithPrevious` is internal to Riverpod, so the rows with a previous value come from a real `FutureProvider` in a `ProviderContainer`, driven through a dependency that moves, and held mid-flight with a `Completer`. Add one test per ordering of `combinePlanResultStatus`.

- [ ] **Step 2: Run them.** Expected: FAIL, nothing defined.
- [ ] **Step 3: Implement.** Check `isLoading` before `hasError`, so a reload after a failure reads as pending.
- [ ] **Step 4: Run them.** Expected: PASS.
- [ ] **Step 5: Commit** as `feat(planner): add the background plan result types and runner`.

### Task 3: Shared bailout gate and the four background providers

**Files:**
- Modify: `lib/features/planner/domain/services/bailout_solver.dart:164-190`
- Modify: `lib/features/planner/domain/services/dive_plan_state_mapper.dart`
- Modify: `lib/features/planner/presentation/providers/mission_outcome_provider.dart:56-63`
- Create: `lib/features/planner/presentation/providers/plan_results_providers.dart`
- Test: `test/features/planner/bailout_solver_test.dart`
- Test: `test/features/planner/plan_results_providers_test.dart`

**Interfaces:**
- Consumes: Task 2's types, `planEngineConfigProvider`, `contingenciesExpandedProvider`.
- Produces:
  - `bool planMayHaveBailout(domain.DivePlan plan)` in `bailout_solver.dart`: not OC, a resolved bailout-role tank, segments present. The solver calls it first.
  - `domain.DivePlan planForEngine(DivePlanState state)` in `dive_plan_state_mapper.dart`: `divePlanFromState` with name, notes and timestamps blanked. `_missionInputs` calls it.
  - Top-level `PlanComputation`s in `plan_results_providers.dart`: `computeRangeTable` returning `RangeTable?`, `computeBailout` returning `BailoutOutcome?`, `computeDeviations` returning `List<DeviationOutcome>`, `computeLostGas` returning `List<LostGasOutcome>`.
  - `planMayHaveBailoutProvider`, `Provider<bool>`.
  - `planRangeTableProvider`, `planBailoutProvider`, `planDeviationsProvider` and `planLostGasProvider`: `FutureProvider<PlanResult<...>>` of the four return types, `retry: (_, _) => null`.

Do not delete the old providers yet. `plan_results_providers.dart` imports `plan_canvas_providers.dart` with a `show` list, so the names cannot collide until Task 5 removes the old ones.

The shared body is a private `_settled<T>(Ref ref, PlanComputation<T> computation)`: `ref.watch` a `select` of `(planForEngine(s), s.initialTissueState, s.surfaceInterval)`, watch the config, runner and settle; await the settle and return early when `!ref.mounted`; `ref.read` the state for `startStateForPlan`; await the runner. `computation` is a top-level function, so its tear-off is sendable.

The contingency providers check `contingenciesExpandedProvider` first and return `PlanResult(planId, const [])` with no settle and no runner call when it is false.

- [ ] **Step 1: Write failing solver tests:** `the gate rejects open circuit, no bailout tank and no segments`, and `the solver returns null for every plan the gate rejects`. Add `a loop plan that never leaves the surface passes the gate and solves to null`, pinning the one-way rule.
- [ ] **Step 2: Run them.** Expected: FAIL.
- [ ] **Step 3: Implement `planMayHaveBailout` and `planForEngine`.** `test/features/planner/mission/` must still pass.
- [ ] **Step 4: Write failing provider tests,** in plain `test()` with a `ProviderContainer`. Use three plans: OC, multi-gas deco, and CCR with bailout, plus a seeded repetitive-dive state.
  - `each result crosses a real isolate and equals a direct call`: real runner, zero settle. Compare field by field: every range cell's TTS and runtime, the worst-case point and required litres, each deviation and lost-gas outcome's runtime and TTS.
  - `a burst of edits runs each service once, after the settle`: a counting runner, a short real settle, 30 edits, expect 0 runs before the settle ends and 1 per provider after.
  - `a superseded run never delivers`: a runner holding a `Completer` per call. Edit, complete the second, then the first; the provider ends on the second plan's result.
  - `a rename runs nothing`.
  - `a failed run recovers on the next edit` (Review Focus 3): a runner that throws once.
  - `a Settings change recomputes` (Review Focus 5): change a config input through an override and expect a second run.
  - `another plan never shows the previous plan's value` (Review Focus 2): load a plan with a new id with the first run still held, and assert `planResultView` gives null and calculating.
  - `collapsed contingencies run nothing`.
- [ ] **Step 5: Run them.** Expected: FAIL.
- [ ] **Step 6: Implement `plan_results_providers.dart`.**
- [ ] **Step 7: Run them,** and `test/architecture/` and `test/shared/`. Expected: PASS. A sendability failure here means a result holds a closure: fix the capture, not the result type.
- [ ] **Step 8: Commit** as `feat(planner): compute secondary plan results on a background isolate`.

### Task 4: Status strings and widgets

**Files:**
- Modify: all 11 `lib/l10n/arb/app_*.arb`, and generated `lib/l10n/arb/app_localizations*.dart`
- Create: `lib/features/planner/presentation/widgets/plan_result_status.dart`
- Test: `test/features/planner/presentation/widgets/plan_result_status_test.dart`

**Interfaces:**
- Consumes: Task 2's types.
- Produces:
  - ARB keys `plannerCanvas_results_calculating` ("Calculating"), `plannerCanvas_results_updating` ("Updating"), `plannerCanvas_results_failed` ("Could not be calculated"), translated into every locale.
  - `class PlanResultStatusText extends StatelessWidget { const PlanResultStatusText(PlanResultStatus status); }`: renders nothing for `current`, the error colour for `failed`.
  - `class PlanResultSection<T> extends StatelessWidget { final PlanResultView<T> view; final Widget Function(T value) builder; }`: the status line above the content; content at `Opacity(0.5)` when `view.isMarked`; no content when `view.value` is null.

- [ ] **Step 1: Write failing tests,** one per row of the spec's four-state table, asserting the text is found and the `Opacity`, and that `current` shows no status and no `Opacity`.
- [ ] **Step 2: Run them.** Expected: FAIL.
- [ ] **Step 3: Add the strings, run `flutter gen-l10n`, implement the widgets.**
- [ ] **Step 4: Run them.** Expected: PASS.
- [ ] **Step 5: Commit** as `feat(planner): add the plan result status widgets`.

### Task 5: Move every consumer over

This task is one commit: removing the old providers breaks each consumer at once.

**Files:**
- Modify: `lib/features/planner/presentation/providers/plan_canvas_providers.dart`, removing the four old providers and moving `planCanvasSeriesProvider` out.
- Modify: `lib/features/planner/presentation/providers/plan_results_providers.dart`
- Modify: `lib/features/planner/presentation/widgets/plan_results_sheet.dart`
- Modify: `lib/features/planner/presentation/widgets/range_table_section.dart`
- Modify: `lib/features/planner/presentation/widgets/chart_mode_toggle.dart`
- Modify: `lib/features/planner/presentation/widgets/plan_result_status.dart`
- Modify: `lib/features/planner/presentation/chart/plan_profile_chart.dart`
- Modify: `lib/features/planner/presentation/pages/plan_canvas_page.dart`
- Test: `test/helpers/planner_results.dart` users, listed in Step 5
- Test: `test/features/planner/plan_results_providers_test.dart`
- Test: `test/features/planner/chart/plan_chart_bailout_status_test.dart`

**Interfaces:**
- Consumes: Tasks 1 to 4.
- Produces:
  - `planChartBailoutProvider`, `Provider<({BailoutOutcome? picture, PlanResultStatus? status})>` in `plan_results_providers.dart`, implementing the spec's chart table. Both fields null when the chart is not in Bailout view or the gate is false.
  - `planCanvasSeriesProvider`, moved to `plan_results_providers.dart`: the bailout picture when `picture` is non-null, else `planLiveCanvasSeriesProvider`.
  - `class PlanChartBailoutStatus extends ConsumerWidget` in `plan_result_status.dart`: an `IgnorePointer`ed `PlanResultStatusText` on a surface-coloured pill, placed top-centre in the chart's `Stack`, clear of the phone corner readouts.

- [ ] **Step 1: Write failing tests of `planChartBailoutProvider`,** one per row of the spec's chart table, including Review Focus 4: remove the last bailout tank with an older picture held and expect both fields null on the same read. Pending with an older null value reads as calculating.
- [ ] **Step 2: Write failing widget tests** in `plan_chart_bailout_status_test.dart`: each labelled row shows its text in `PlanProfileChart` and in `PlanChartFullscreenPage`; the unlabelled rows show none; and `the toggle does not flicker through an edit`: with a loop plan and a held runner, the Bailout chip is found on every pump across an edit.
- [ ] **Step 3: Run them.** Expected: FAIL.
- [ ] **Step 4: Switch the consumers.**
  - `ChartModeToggle`: hide when `planMayHaveBailoutProvider` is false, or when the bailout view is `current` with a null value.
  - Sheet: `planId` comes from `state.id`. The bailout section shows when the gate is true and the view is not current-and-null, through `PlanResultSection`. `loopTankUsages` is unchanged.
  - Range table: the header shows when `state.segments.isNotEmpty` and the view is not current-and-null. `RangeTableSection` renders through `PlanResultSection`.
  - Contingencies: one status line from `combinePlanResultStatus` of the two views, rows from `view.value ?? const []`, dimmed when marked.
  - Chart: add `PlanChartBailoutStatus` to the `Stack`.
  - Delete the four old providers and the `show` list.
- [ ] **Step 5: Bring the existing tests over.** Add `...plannerResultsInline()` to the overrides of every test that mounts the sheet, the canvas or the toggle: `test/core/router/app_router_test.dart`; under `test/features/planner/`: `ccr_ui_test`, `contingency_ui_test`, `plan_canvas_page_test`, `plan_canvas_delete_test`, `plan_canvas_export_test`, `plan_canvas_first_save_test`, `plan_canvas_replan_reset_test`, `plan_results_widgets_test`, `panes/plan_panes_test`, `mission/mission_results_section_test`, `presentation/widgets/plan_results_sheet_stop_minimum_test`, `chart/plan_profile_chart_test`, `chart/plan_profile_chart_drag_test`, `chart/plan_profile_chart_waypoint_menu_test`, `chart/plan_profile_chart_golden_test`, `plan_canvas_providers_test`. Provider tests that read the old synchronous value become `await container.read(provider.future)`, then `.value`. A test may need a further `pump` for the result to land. Do not loosen an assertion.
- [ ] **Step 6: Run** `flutter test test/features/planner test/core/router test/architecture test/shared`. Expected: all pass.
- [ ] **Step 7: Commit** as `feat(planner): show background plan results with their status`.

### Task 6: Export waits for current results

**Files:**
- Modify: `lib/features/planner/presentation/widgets/plan_export_files.dart:53-75`
- Test: `test/features/planner/plan_canvas_export_test.dart`

**Interfaces:**
- Consumes: Task 3's four providers.

- [ ] **Step 1: Write failing tests:** `a slate exported straight after an edit carries the new figures` (Review Focus 1): real settle, a held runner. Start the export after an edit, complete the run, and assert the service received the edited plan's outcome. Then `a failed result fails the export`, no slate produced, and `collapsed contingencies stay out of the slate`.
- [ ] **Step 2: Run them.** Expected: FAIL.
- [ ] **Step 3: Await `ref.read(provider.future)` for all four and pass `.value`.** Awaiting all four before `buildSlate` keeps a failure out of a half-built slate.
- [ ] **Step 4: Run them.** Expected: PASS.
- [ ] **Step 5: Commit** as `fix(planner): build the slate from results for the current plan`.

### Task 7: Measure and capture

**Files:** no committed files. The throwaway harness files stay unstaged and are deleted at the end.

- [ ] **Step 1: Run** `flutter test test/features/planner/tmp_drag_bench_test.dart` and record the BENCH lines beside the baseline: OC 40/20 median 86.4 ms, OC 90/30 225.4 ms, CCR 80/40 207.9 ms, every frame over 16.7 ms.
- [ ] **Step 2: Count engine runs per settled edit** before and after, from the counting runner and the service loops: 25 range cells, 3 deviations, one lost-gas run per losable tank, and one bailout solve.
- [ ] **Step 3: Attempt a macOS profile build** and a real drag. If the harness cannot run it, record that for the PR.
- [ ] **Step 4: Capture after shots** with `tmp_shot_test.dart`, using a held runner to freeze each state: sheet updating, sheet calculating, sheet failed, chart updating on desktop and phone, chart failed, and light and dark for the dimmed sheet. Name them `<nn>-<screen>-after[-dark][-phone].png` in the scratchpad.
- [ ] **Step 5: Send the shots** with one SendUserFile call, `display: attach`, captioned as going in the PR's Screenshots section.
- [ ] **Step 6: Delete** `tmp_shot_test.dart`, `tmp_drag_bench_test.dart` and `test/features/planner/goldens/`. Confirm `git status --porcelain` shows none of them, and `git ls-files test/features/planner/goldens` is empty.
