# Dive Planner Phase 7 — Outputs + Hub Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans
> to implement this plan task-by-task.

**Goal:** Ship the plan outputs (slate PDF, .subplan share file, range tables,
multi-plan compare) and reorganize the planning hub around the planner.

**Architecture:** All outputs are pure consumers of `PlanEngine`/`PlanOutcome`
— no engine changes. The slate PDF reuses the existing
`lib/core/services/export/` infrastructure (`pw.Document`, `sharePdfBytes`).
Range tables are a small domain service (grid of engine runs). The .subplan
file is versioned JSON over the existing `domain.DivePlan` aggregate. The hub
page gets saved plans + New plan first, tools below.

**Tech Stack:** `pdf`/`printing`/`share_plus`/`file_picker` (all already in
pubspec), Riverpod, existing PlanEngine.

## Global Constraints

- Deco math only through the shared engine (`PlanEngine`/`BuhlmannGf`).
- Units respect diver settings (`UnitFormatter`) — including inside the PDF.
- New strings in `app_en.arb` + 10 locales, alphabetical, `flutter gen-l10n`.
- `dart format .` and whole-project `flutter analyze` clean; commit per task.

---

### Task 1: Range table service

**Files:**
- Create: `lib/features/planner/domain/services/range_table_service.dart`
- Test: `test/features/planner/range_table_service_test.dart`

`RangeTableService.compute(domain.DivePlan plan, {depthDeltas: [-6,-3,0,3,6], timeDeltas: [-10,-5,0,5,10]})`
→ `RangeTable` (rows = depth variants, cols = time variants, each cell
`RangeCell(runtimeSeconds, ttsSeconds, totalDecoSeconds, isDiveable)`), built
by re-running the engine on deviated plans via the existing
`ContingencyService`-style segment adjustment (deepen bottom segments /
extend last bottom segment). Skip variants that go ≤ 0 m or ≤ 0 min. Test:
base cell matches the plan's own outcome; deeper/longer cells have ≥ TTS.

### Task 2: Range table UI section

**Files:**
- Create: `lib/features/planner/presentation/widgets/range_table_section.dart`
- Modify: `plan_results_sheet.dart` (append section), `plan_canvas_providers.dart` (provider)
- Test: `test/features/planner/range_table_section_test.dart`

`planRangeTableProvider` (Provider, watches state + engine config; empty when
plan has no deco-relevant segments). Compact grid: depth rows × time columns,
cell shows TTS minutes (tinted when not diveable). Widget test via the
existing results-sheet harness pattern.

### Task 3: Slate PDF export

**Files:**
- Create: `lib/features/planner/data/services/plan_slate_pdf_service.dart`
- Modify: `plan_canvas_page.dart` (menu: "Export slate (PDF)")
- Test: `test/features/planner/plan_slate_pdf_test.dart`

`PlanSlatePdfService.buildSlate({plan, outcome, deviations, lostGas, rangeTable, bailout, units, labels})`
→ `Future<List<int>>` (pw.Document): header (name, date, mode, GF), main
runtime table, gas plan (per-tank usage, turn pressure, min gas), deviation
tables, lost-gas tables, bailout summary (CCR), range table. High-contrast
monochrome for print. Menu action shares via existing `sharePdfBytes`. Test:
bytes non-empty + parseable header (`%PDF`), and builder covers OC + CCR
plans without throwing.

### Task 4: .subplan share + import

**Files:**
- Create: `lib/features/planner/data/services/plan_file_codec.dart`
- Modify: `saved_plans_sheet.dart` (per-plan Share action, Import action in header), `plan_canvas_page.dart` (menu Share plan)
- Test: `test/features/planner/plan_file_codec_test.dart`

`planToSubplanJson(domain.DivePlan) → String` (envelope
`{format: "submersion-plan", version: 1, plan: {...}}`) and
`subplanFromJson(String) → domain.DivePlan` (fresh ids on import to avoid
collisions; throws FormatException on wrong format/newer version). Share via
`saveAndShareFile`; import via `file_picker` → repository.savePlan → open.
Test: round-trip equality on the engine-relevant fields (segments, tanks,
GF, mode, setpoints, contingency config); version guard throws.

### Task 5: Multi-plan compare

**Files:**
- Create: `lib/features/planner/presentation/pages/plan_compare_page.dart`
- Modify: `saved_plans_sheet.dart` (multi-select → Compare), router (`/planning/dive-planner/compare?ids=`)
- Test: `test/features/planner/plan_compare_test.dart`

Pick 2-3 saved plans → overlaid profiles (fl_chart, one color per plan, reuse
`buildCanvasSeries`) + diff table (runtime, TTS, deco time, max depth, CNS,
per-tank gas). Provider loads plans by id and computes outcomes. Test: diff
rows present for 2 plans; profiles map to distinct line bars.

### Task 6: Hub redesign + deco calculator environment

**Files:**
- Modify: `lib/features/planning/presentation/pages/planning_page.dart`
- Modify: `lib/features/deco_calculator/presentation/providers/deco_calculator_providers.dart` (+ page inputs)
- Test: `test/features/planning/planning_page_test.dart` (update/create)

Hub: "New plan" CTA + recent saved plans (top 3 via
`divePlanSummariesProvider`, tap → open, "All plans" → saved-plans sheet)
above the tools list; tools keep existing tiles (restyled section header).
Deco calculator: altitude + water-type inputs feeding
`DiveEnvironment.forConditions` into `BuhlmannAlgorithm(environment:)` so it
agrees with the planner at altitude.

### Task 7: l10n + verification sweep + PR

Translate new keys into all locales, `flutter gen-l10n`, `dart format .`,
whole-project `flutter analyze`, run `test/features/planner/` +
`test/features/planning/` + `test/features/deco_calculator/`, push
`worktree-dive-planner-phase7-outputs`, PR stacked on the Phase 6 branch.
