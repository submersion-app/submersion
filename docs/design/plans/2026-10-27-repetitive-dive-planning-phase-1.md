# Repetitive dive planning, phase 1: implementation plan

Issue: #3565. Spec:
[../specs/2026-10-27-repetitive-dive-planning-design.md](../specs/2026-10-27-repetitive-dive-planning-design.md).

Each step is test-first and lands as its own commit.

1. **Engine start exposure.** `DivePlan.startCns`/`startOtu` feed the engine's
   CNS/OTU counters. `DivePlanState.initialCns`/`initialOtu`, with the CNS
   decayed over the surface interval in `divePlanFromState`. Tests:
   `test/features/planner/plan_engine_start_exposure_test.dart`.
2. **Series domain.** `PlanSeries`/`PlanSeriesDive`, the edits (append,
   remove, select, update with typed-pressure pinning, Fill, Fill all) and
   `computeSeries`/`carriedState`. Tests: `test/features/planner/series/`
   (`plan_series_edits_test.dart`, `plan_series_calculator_test.dart`).
3. **Providers.** `planSeriesNotifierProvider` synced with the editor,
   `planSeriesResultsProvider`, `canAddSeriesDiveProvider`,
   `planSaveAllowedProvider`, `seriesFillPressuresProvider`. Tests:
   `plan_series_notifier_test.dart`.
4. **UI.** `PlanSeriesNavigator` above the chart (desktop chart column and
   phone), `PlanDiveDetailsCard` (dive name and surface interval) above
   Tanks, Fill and Fill all tanks in
   `PlanTankList`, Save and Convert to dive disabled for a series. Strings in
   every locale. Tests: `plan_series_ui_test.dart`, `hours_minutes_test.dart`.
5. **Finish.** This record, screenshots (phone and desktop, light and dark),
   `dart format`.
