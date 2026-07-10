# WS1: Bounded Summary-Hydrated Search Implementation Plan

> **For agentic workers:** Executed inline (executing-plans) in worktree
> `.claude/worktrees/ws1-search`, branch `worktree-ws1-search`.

**Goal:** Take dive search from ~3.5 s of main-isolate CPU (measured, profile
mode, 1,032-dive DB) to well under 500 ms by eliminating the N+1 full-`Dive`
hydration: bound the match set and hydrate matches as `DiveSummary` rows with
exactly four SQL statements total, regardless of match count.

**Spec:** WS1 Phase A in
`docs/superpowers/specs/2026-07-10-large-db-performance-design.md`. Evidence:
`2026-07-10-large-db-performance-findings.md` (search signature: per-query SQL
string building + row-mapping Map churn on the UI isolate; 74-match term ran
~740 queries).

**Already in place (verified, no work needed):** input debounce
(`DebouncedSearchResults`, 300 ms, keeps last results visible);
`getCardColorValue(DiveSummary, ...)`; `DiveSummary` carries every field
`DiveListTile` renders; `diveSearchProvider` and `searchDives` have exactly
one consumer each (the delegate chain), so full replacement is safe.

## Design

- `DiveRepository.searchDiveSummaries(query, {diverId, limit = kDiveSearchResultLimit})`:
  1. Match query: the existing 12-column LIKE SQL + `ORDER BY
     COALESCE(d.entry_time, d.dive_date_time) DESC` + `LIMIT ?` — most-recent
     matches win when the set is bounded.
  2. Summary hydration: the `getDiveSummaries` slim SELECT reshaped as
     `WHERE d.id IN (...)`, same ORDER BY.
  3. Batched `getTagsForDives(ids)` + `_diveTypesForDives(ids)` (statements
     3 and 4).
  Row mapping extracted to a `_mapSummaryRows` helper shared with
  `getDiveSummaries` (DRY).
- `kDiveSearchResultLimit = 100` (static const on `DiveRepository`).
- Delete `searchDives` (sole consumer replaced).
- `diveSearchProvider` becomes `FutureProvider.family<List<DiveSummary>,
  String>`; empty query returns `const []` (the old empty-query fallback to
  `divesProvider`/getAllDives was unreachable from the UI and is a hot-path
  liability).
- `DiveSearchDelegate` becomes `SearchDelegate<String?>` (result value was
  unused); results render from `DiveSummary`; when `items.length >=
  kDiveSearchResultLimit`, a footer tile shows the new
  `diveLog_listPage_searchLimitNotice` string.
- l10n: new string in `app_en.arb` + the 10 non-en locales (ar, de, es, fr,
  he, hu, it, nl, pt, zh) + regenerate.
- Measurement: extend `tools/db_bench.dart` with the new 4-statement shape
  (`search_bounded_summaries`) for an A/B row in the PR against
  `search_hydration_first20`.

## Tasks

1. Repository: `_mapSummaryRows` extraction + `searchDiveSummaries` +
   delete `searchDives`. Tests first:
   `test/features/dive_log/data/repositories/dive_search_summaries_test.dart`
   covering: match across notes/site/buddy/tag fields; bound honored with
   most-recent-first selection; ordering by sort timestamp; tags/diveTypeIds
   populated; diverId scoping; empty result.
2. Provider + delegate + footer notice + l10n (all locales, regenerate).
3. db_bench shape + capture numbers on `~/SubmersionBench/work.db`.
4. Sweep: `dart format .`, whole-project `flutter analyze`, targeted tests
   (new file + startup/list page tests touched by delegate change), commit
   per task, push `--no-verify` (hook runs against main tree), PR.

## Verification gates

- New repo test file green; no remaining references to `searchDives`.
- db_bench: bounded shape total well under the 500 ms target on the 1,032
  dive fixture (expect ~2-5 ms).
- `flutter analyze` no issues; `dart format .` no changes.
