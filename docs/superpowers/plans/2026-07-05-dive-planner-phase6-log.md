# Dive Planner Phase 6 — Log Integration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans
> to implement this plan task-by-task.

**Goal:** Wire the planner to the dive log: seed tissues from a logged dive,
auto-fill SAC from logged averages, persist convert-to-dive with a back-link,
and overlay the planned profile on the dive detail chart.

**Architecture:** The engine already accepts `startState` on
`PlanEngine.compute`; this phase feeds it. Followed-dive context lives on
`DivePlanState` (sourceDiveId + initialTissueState + surfaceInterval) and maps
into the `domain.DivePlan` aggregate. Convert-to-dive persists through the
existing `DiveRepository.createDive` and records `linkedDiveId` on the plan;
the dive detail page looks the plan back up by `linkedDiveId` and renders it
as a `ChartSourceOverlay`.

**Tech Stack:** Flutter, Riverpod, Drift, existing deco engine (`BuhlmannGf`).

## Global Constraints

- All deco math flows through the engine already used by dive details.
- Units respect diver settings via `UnitFormatter`.
- New user-facing strings go in `app_en.arb` + all 10 other locales,
  alphabetically, then `flutter gen-l10n`.
- `dart format .` clean; whole-project `flutter analyze` clean.
- Commit per task on `worktree-dive-planner-phase6-log`.

---

### Task 1: Followed-dive context on state, notifier, and mapper

**Files:**
- Modify: `lib/features/dive_planner/domain/entities/plan_result.dart`
- Modify: `lib/features/dive_planner/presentation/providers/dive_planner_providers.dart`
- Modify: `lib/features/planner/domain/services/dive_plan_state_mapper.dart`
- Test: `test/features/planner/dive_plan_state_mapper_test.dart`

**Steps:**
- [ ] Add `sourceDiveId` and `linkedDiveId` (`String?`, with
  `clearSourceDiveId`/`clearLinkedDiveId` copyWith flags) to `DivePlanState`.
- [ ] Notifier: replace stub `loadTissueFromDive` with
  `setFollowedDive({required String diveId, List<TissueCompartment>? compartments, required Duration surfaceInterval})`
  (sets sourceDiveId + initialTissueState + surfaceInterval, marks dirty),
  add `clearFollowedDive()` (clears all three) and `setLinkedDive(String? diveId)`.
- [ ] `stateFromDivePlan` copies sourceDiveId/linkedDiveId out of the plan;
  `divePlanFromState` writes them from the state (state-owned now — update the
  preservation test which expects `sourceDiveId` to survive from `existing`).
- [ ] Tests: round-trip both ids; `setFollowedDive`/`clearFollowedDive`
  behavior. Run mapper + planner provider tests. Commit.

### Task 2: Tissue seeding into the live outcome

**Files:**
- Modify: `lib/features/planner/presentation/providers/plan_canvas_providers.dart`
- Modify (if needed): `lib/core/deco/deco_model.dart`
- Test: `test/features/planner/plan_engine_seeding_test.dart`

**Steps:**
- [ ] Helper `TissueState? seededStartState(DivePlanState state, {required double gfLow, required double gfHigh})`:
  null when `initialTissueState` is null; otherwise off-gas the compartments
  at surface for `surfaceInterval` (air) via `BuhlmannAlgorithm` and return
  `BuhlmannGf(...).restoreState(...)` — mirroring
  `_computeResidualTissueState` in `profile_analysis_provider.dart`.
- [ ] `planOutcomeProvider` passes the seeded state to `engine.compute`.
- [ ] Engine-level test: identical deco plan computed fresh vs seeded with
  loaded compartments → seeded plan has strictly more `totalDecoSeconds`;
  a long surface interval (>12 h) trends back toward the fresh plan. Commit.

### Task 3: Follow-a-dive picker, Following chip, SAC auto-fill

**Files:**
- Create: `lib/features/planner/presentation/widgets/follow_dive_sheet.dart`
- Modify: `lib/features/planner/presentation/pages/plan_canvas_page.dart`
- Modify: `lib/features/dive_planner/presentation/widgets/plan_settings_panel.dart`
- Modify: `lib/features/planner/presentation/providers/plan_canvas_providers.dart`
- Test: `test/features/planner/follow_dive_test.dart`

**Steps:**
- [ ] `loggedAverageSacProvider` (`FutureProvider<double?>`): statistics
  repository `getSacVolumeByTankRole()`, return the `'backGas'` entry.
- [ ] `followDiveSheet`: recent dives (via `divesProvider`, first ~30) as
  ListTiles (name, date, depth/duration via UnitFormatter). On tap: read
  `profileAnalysisProvider(dive.id).future`, take
  `decoStatuses.last.compartments` (null-safe), surface interval =
  `now - dive end` clamped to ≥ 10 min (fallback 60 min when unknown), call
  `setFollowedDive`, pop.
- [ ] Canvas page: menu entry "Follow a dive"; when `sourceDiveId != null`
  show a Following chip next to the status chips with a clear (×) action.
- [ ] Settings panel: "Use logged average" affordance next to the SAC field
  that fills from `loggedAverageSacProvider` when available.
- [ ] Widget test: picker sets state; chip shows and clears. Commit.

### Task 4: Convert-to-dive persistence

**Files:**
- Modify: `lib/features/dive_planner/presentation/providers/dive_planner_providers.dart`
- Modify: `lib/features/planner/presentation/pages/plan_canvas_page.dart`
- Test: `test/features/planner/convert_to_dive_test.dart`

**Steps:**
- [ ] `toDive()` gets a fresh UUID (not the plan id), `isPlanned: true`,
  dive name from plan name.
- [ ] `_convertToDive`: confirm dialog → `DiveRepository.createDive` (via the
  same notifier/provider path other creators use so sync + list refresh
  happen), `setLinkedDive(dive.id)`, `save()`, snackbar with a View action
  navigating to `/dives/{id}`.
- [ ] Test: converting persists a dive with `isPlanned` and links the plan.
  Commit.

### Task 5: Plan-vs-actual overlay on dive detail

**Files:**
- Modify: `lib/features/planner/data/repositories/dive_plan_repository.dart`
- Create: `lib/features/planner/presentation/providers/plan_overlay_provider.dart`
- Modify: `lib/features/dive_log/presentation/pages/dive_detail_page.dart`
- Test: `test/features/planner/plan_overlay_test.dart`

**Steps:**
- [ ] Repository: `getPlanByLinkedDiveId(String diveId)` →
  `domain.DivePlan?` (query dive_plans where linked_dive_id = ?).
- [ ] `plannedProfileOverlayProvider` (`FutureProvider.family<ChartSourceOverlay?, String>`):
  load plan, run `PlanEngine`, `buildCanvasSeries`, map profile points →
  `DiveProfilePoint`; label from l10n, distinct color, `computerId: null`.
- [ ] Dive detail: watch the provider, append to `overlays` when non-null.
- [ ] Test: repository lookup + overlay point mapping. Commit.

### Task 6: l10n + verification sweep + PR

**Steps:**
- [ ] New keys (all locales, alphabetical, `flutter gen-l10n`).
- [ ] `dart format .`; whole-project `flutter analyze`; run
  `test/features/planner/` + touched dive_log tests.
- [ ] Commit, push `-u origin worktree-dive-planner-phase6-log --no-verify`
  (with `env -u GITHUB_TOKEN`), PR stacked on the Phase 5 branch.
