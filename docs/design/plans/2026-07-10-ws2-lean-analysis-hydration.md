# WS2: Lean Analysis Hydration Implementation Plan

> Executed inline (executing-plans) in worktree `.claude/worktrees/ws2-detail`,
> branch `worktree-ws2-detail`.

**Goal:** Cut the dive-detail open cost (~11 s main-isolate CPU measured on
dive 1006, profile mode, 1,032-dive DB) by removing full-Dive hydration from
the decompression-analysis path. The Buhlmann/exposure math itself
(`computeAnalysisForProfile`) is not touched.

**Spec:** WS2 in `2026-07-10-large-db-performance-design.md`. Evidence:
`2026-07-10-large-db-performance-findings.md` (23.7% raw allocation +
dynamic-dispatch checks; the residual CNS/tissue/OTU chains plus weekly OTU
hydrate every prior dive in the lookback window as a FULL Dive several times
over).

**Measured mechanics (agent-verified, file:line in findings):**
- The analysis pipeline reads ONLY dive-row scalars (diveMode, GF hi/lo,
  CCR/SCR settings, altitude, waterType, surfacePressure, times) + `tanks` +
  `profile`. No joined display entities.
- Each chain dive today costs ~5 full hydrations: `profileAnalysisProvider`
  watches `diveProvider` (full `getDiveById`), `getSurfaceInterval` fully
  hydrates BOTH its dives, `getPreviousDive` hydrates current + previous.
- Async placement and session caching (spec items 3-4) already exist:
  detail sections use `.valueOrNull` with fallbacks; analysis families are
  keepAlive.

**Scope decisions (recorded deviations):**
- The spec's "exactly one dive_profiles query per open" is amended: post-WS0
  an indexed per-dive profile read costs ~4 ms, and true dedup requires
  adding source attribution to `DiveProfilePoint` (three mapper sites, wide
  constructor surface). Not justified by measurement; the actual cost driver
  (chain full-hydration) is eliminated instead. Revisit only if the post-WS2
  profile shows the residual reads mattering.
- `getPreviousDive`/`getDivesInRange`/`getDiveById` keep their public
  behavior for other consumers; only the analysis call sites move to the new
  slim accessors.

## Design

New domain type `DiveTimes` (id, dateTime, entryTime, exitTime, runtime,
bottomTime, profileSpan) with an `effectiveRuntime` getter mirroring
`Dive.effectiveRuntime` exactly — the profile-derived fallback is preserved
via a SQL scalar subquery `MAX(timestamp)-MIN(timestamp)` (null unless > 0,
matching `calculateRuntimeFromProfile`).

New repository methods (dive_repository_impl.dart):
- `getDiveTimes(id)` — 1 statement.
- `getPreviousDiveTimes(id)` — 2 statements; predicate and ordering copied
  from `getPreviousDive`.
- `getDiveTimesInRange(start, end, {diverId})` — 1 statement; WHERE and
  ordering copied from `getDivesInRange`.
- `getMergedProfile(id)` — 1 statement; same mapping as `Dive.profile`
  (shared `_profilePointFromRow`, which also replaces the duplicated inline
  mapping in `_mapRowToDive`).
- `getDiveForAnalysis(id)` — 3 statements (dive row via
  `_mapRowToDiveWithPreloadedData` with empty joins, tanks, merged profile
  via copyWith). Doc contract: analysis only, never display.
- `getSurfaceInterval` reimplemented on `getDiveTimes` +
  `getPreviousDiveTimes` (public signature and formula unchanged; drops ~20
  statements per call).

Provider changes (profile_analysis_provider.dart):
- New `analysisDiveProvider` keepAlive family -> `getDiveForAnalysis`, with
  its own `invalidateSelfWhen(watchDiveDetailChanges())` (analyses currently
  refresh only transitively through diveProvider; this preserves that).
- `profileAnalysisProvider` and `sourceProfileAnalysisProvider` watch
  `analysisDiveProvider` instead of `diveProvider`.
- `_computeResidualCns`: `getPreviousDiveTimes`; the computer-CNS branch
  fetches `getMergedProfile(previous.id)` only when taken.
- `_computeResidualTissueState`: `getPreviousDiveTimes` (id only).
- `_computeResidualOtu` + `weeklyOtuProvider`: `getDiveTimes` +
  `getDiveTimesInRange`.

## Cost model (per chain dive)

Before: ~5 full hydrations x ~11 statements + full joined-entity mapping.
After: 3 statements (analysisDive) + 2 (surface interval) + 2 (prev times),
no joined-entity mapping, chain Dives no longer pinned fully in the
diveProvider keepAlive cache.

## Tasks

1. `DiveTimes` entity + repository slim accessors, TDD:
   `test/features/dive_log/data/repositories/dive_times_accessors_test.dart`
   asserting parity with the legacy methods on seeded data (previous-dive id,
   in-range ids/order, surface interval unchanged, getDiveForAnalysis vs
   getDiveById on scalars/tanks/profile).
2. Provider rewiring (analysisDiveProvider + six call-site swaps).
3. Regression: run the full deco suite (profile_analysis_provider_test,
   source_profile_analysis_provider_test, weekly_otu_provider_test,
   cumulative_tissue_test, profile_analysis_loading_race_test,
   computer_cns_provider_integration_test, profile_analysis_service_test,
   surface-interval coverage in dive_repository_coverage_test).
4. Sweep: format, whole-project analyze, mock regen if repository interface
   changed, commit, push --no-verify, PR.

## Verification gates

- All deco suites green untouched (they pin behavior through the new path).
- New parity tests green.
- Analyze clean, format clean.
