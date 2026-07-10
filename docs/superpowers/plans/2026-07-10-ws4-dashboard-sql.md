# WS4: Dashboard Off getAllDives Implementation Plan

> Executed inline (executing-plans) in worktree
> `.claude/worktrees/ws4-dashboard`, branch `worktree-ws4-dashboard`.

**Goal:** Remove hot-path `getAllDives()` from app startup. The dashboard is
the initial route and three of its providers force `divesProvider` ->
`getAllDives()` (full hydration of every dive with all children) on the
first home frame. This is the workload behind the ~20 s debug-launch freeze
(debug-JIT compiling the Drift mapping code hot; findings doc) and a linear
scaling liability in release builds (~1-2 s at 1,032 dives today).

**Spec:** WS4 in `2026-07-10-large-db-performance-design.md`.

## Design (minimal-diff: provider internals only, cards untouched)

- `recentDivesProvider` keeps returning `List<Dive>`: ids come from
  `getDiveSummaries(limit: 3)` (SQL-bounded), then each of the <= 3 winners
  hydrates individually via indexed `getDiveById`. Batch mini-chart profile
  preload unchanged.
- `monthlyDiveCountProvider` / `yearToDateDiveCountProvider`: new
  `countDivesSince(since, {diverId})` repository method (one COUNT
  statement, same strict `>` comparison as the old Dart filter).
- `personalRecordsProvider` keeps returning `PersonalRecords` with `Dive?`
  fields: winner SELECTION moves to SQL (`getPersonalRecordIds`, six small
  indexed statements: deepest / longest / coldest / warmest / most-visited
  site GROUP BY), then the <= 4 distinct winner dives hydrate via
  `getDiveById`. The longest-dive ORDER BY reproduces
  `Dive.effectiveRuntime`'s full resolution order (runtime, exit - entry,
  profile span via scalar subquery, bottom time), which the old in-memory
  loop used; guards `> 0` and `max_depth > 0` preserve the old loop's
  strict-greater seeding semantics.
- All three rewritten providers self-invalidate on
  `watchDivesChanges()` (previously they inherited reactivity transitively
  through `divesProvider`; issue #217 pattern) and scope by
  `currentDiverIdProvider` exactly as `divesProvider` did.
- `daysSinceLastDiveProvider` is untouched (reads `recentDivesProvider`).

## Recorded deferral

Table view mode and detailed-cards-with-non-summary-fields still fall back
to `getAllDives()` (spec WS4 second half). They are opt-in views, not
startup cost; widening `DiveSummary` to every configurable column is a
separate change. Re-measure after this lands; follow up if table mode shows
up in practice.

## Tasks

1. Repository: `countDivesSince` + `getPersonalRecordIds`, TDD in
   `test/features/dive_log/data/repositories/dashboard_queries_test.dart`
   (count boundaries + diver scoping; winner ids incl. the
   profile-span-longest case and most-visited tie shape).
2. Provider rewrites (three sites) keeping types; dashboard suites green
   (`dashboard_providers_test`, `recent_dives_reactivity_test`,
   `dashboard_quick_stats_filter_test`).
3. Sweep: format, whole-project analyze, mock regen if needed, commit,
   push --no-verify, PR.

## Verification gates

- No `divesProvider` watch remains in dashboard_providers.dart.
- Dashboard + new repo suites green; analyze/format clean.
