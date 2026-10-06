# Large-Database Performance (Phase 3) — Design

Date: 2026-07-10
Status: Approved (brainstorming session)
Predecessors: `2026-06-24-app-performance-investigation-design.md` (Phase 1),
Phase 2 PRs #412 (chart memoization), #415 (sync parse isolate), #417 (batched
merge writes), #420 (rebuild coalescing).

## Context

Phases 1-2 fixed what was measurable at 37 dives / 40.9k profile samples. A
scubaboard user with 1,000+ dives (Subsurface import, Shearwater, technical
dives, PC + Android) reports a new scale regime:

- Search takes 20+ seconds on PC; on Android the app hits "not responding"
  (ANR) dialogs before search completes.
- Changing dive profile graph options (for example switching the deco ceiling
  overlay from calculated to dive computer) can take minutes on technical
  dives.

The local debug database reproduces the slowness: 1,032 dives, 1,077,216
`dive_profiles` rows, 784,752 `tank_pressure_profiles` rows, 34 multi-computer
dives, densest dive 4,762 samples, 335 MB on disk.

### Evidence gathered (2026-07-10)

**The dominant finding: the live v102 database has almost no indexes.**
Performance indexes are created only inside `onUpgrade` migration blocks
(`lib/core/database/database.dart`, `from < 31` block at :2957-:3013, `from <
78` at :4438). They are never created in `onCreate` (which is
`m.createAll()` + seed only, :2300-:2306) and never re-asserted in
`beforeOpen`. Any database created fresh at a recent schema version, or
arriving via restore or sync-adopt, gets none of them. The live DB has 6 user
indexes out of ~20 intended; `EXPLAIN QUERY PLAN` confirms `SCAN
dive_profiles` (a 1.08M-row full scan) for a single dive's profile fetch.
The scubaboard reporter (fresh install + import) is in the same state.

Code-level findings that compound with the missing indexes:

| Surface | Finding |
|---|---|
| Search | `searchDives` (`dive_repository_impl.dart:1932`) runs a 12-column leading-wildcard `LIKE` across 5 joined tables with no `LIMIT`, then hydrates every match through `_mapRowToDive` (:2588) — roughly 10 queries per matched dive (N+1). |
| Dive detail | `getDiveById` eagerly loads all sources' full profiles with no filter (:2608); `sourceProfilesProvider` re-reads the same rows (:625, :645). Residual CNS/tissue/OTU chains plus `weeklyOtuProvider` (`profile_analysis_provider.dart:950`, :1011, :1071, :1160) fully hydrate and Buhlmann-analyze every dive back 24-48 h of surface interval and 7 days of history — 20-30 extra full-dive hydrations on a dense week. |
| Chart | The feature-preserving decimator (`profile_decimator.dart`) from PR #412 has zero production callers. Every curve is a full-length `isCurved` FlSpot list; overlays add up to 4 full-length series per source. The series cache has one all-or-nothing signature (`dive_profile_chart.dart:815-847`), so one toggle rebuilds every series. |
| Dashboard | `recentDivesProvider`, `personalRecordsProvider`, and month/YTD counts (`dashboard_providers.dart:49`, :97-:118, :155) all await `divesProvider` → `getAllDives()`: full hydration of every dive with all children on the first home frame. Table view mode and detailed cards with non-summary fields hit the same path (`dive_list_content.dart:674`, :1200-1214). |
| Structural | All SQLite execution happens on the UI isolate — the ANR mechanism. |
| Already sound | The paginated card list (50/page, SQL-bounded, batched follow-ups) and the Statistics tab (pure SQL aggregates via `buildFilteredDiveIdSubquery`) need no work. |

## Goals

Interactive-grade targets at 1,000+ dives, measured on macOS against the live
debug DB:

| Operation | Target |
|---|---|
| Search (results visible) | < 500 ms |
| Dive detail open (core content) | < 500 ms |
| Chart option toggle | < 200 ms |
| Cold start to usable dashboard | < 2 s |
| UI-thread blocking from DB work | zero blocks > 1 frame |

Non-goals: the reporter's correctness complaints (bottom-time calculation,
ceiling accuracy, import cancellation) are tracked separately; this program is
performance only. Measurement is macOS-only; Android/Windows verification
happens at the end of the program.

## Approach

Surgical sequence with per-workstream measurement gates: a compact scripted
baseline first, then independent workstreams in descending expected-yield
order. Each workstream opens with its own measurement and closes with a
before/after comparison in its PR. Ordering logic: shrink the work
(WS0-WS4), then move the work off-thread (WS5). Re-baseline after WS0, since
indexes reshuffle every downstream measurement.

Alternatives considered and rejected:

- Exhaustive baseline before any fix: the anchor scenarios are already
  precisely defined by user complaints and DB inspection; exhaustive
  baselining delays relief WS0 can deliver immediately.
- Architecture first (DB isolate before algorithmic fixes): the isolate move
  makes slow work invisible, not fast — a 20 s search becomes a 20 s
  background wait. Do the riskiest refactor against a lean workload, last.

## Baseline measurement

Five scripted anchor scenarios, run with the VM-service profiler technique
from Phase 1. The `vmcap.dart` tool was scratchpad-only and is lost; it gets
recreated and committed to `tools/` this time so the runbook is reproducible.

1. Cold start to interactive dashboard.
2. Search for a term matching many dives.
3. Detail open: densest single-computer dive (~4.8k samples), a 2-computer
   dive, and a dive at the end of a dense repetitive week (worst lookback
   chain).
4. Chart toggles: ceiling calculated/computer, overlay on/off.
5. Table view mode switch and a paginated-list fast scroll.

Each scenario records wall time, UI-isolate busy time, and query counts
(Drift `logStatements` plus `EXPLAIN QUERY PLAN` captures). Numbers land in a
findings doc next to this spec; every workstream PR must show its
before/after.

## Workstreams

### WS0 — Index integrity

- A single idempotent `_ensurePerformanceIndexes()` — a list of `CREATE INDEX
  IF NOT EXISTS` statements — called from both `onCreate` and `beforeOpen`.
  This matches the existing `beforeOpen` re-assert pattern (dive-type seed,
  buddyRoles, dive-plan indexes) and permanently heals every user's DB on
  next launch.
- The list is the full intended set (v31 + v78 era) plus new indexes the
  query map justifies: `dive_profiles(dive_id)`,
  `tank_pressure_profiles(dive_id)`, and an expression index on
  `(diver_id, COALESCE(entry_time, dive_date_time) DESC)` — the actual sort
  key of the paginated list, currently not index-backed.
- Run `ANALYZE` after any index was actually created (consider `PRAGMA
  optimize` on open) so the planner uses the new indexes.
- First-open cost: building ~15 indexes over a 335 MB DB is a one-time stall
  behind the existing splash. Measure it; add progress UI only if it exceeds
  a few seconds. `IF NOT EXISTS` makes later opens free.
- CI guard: a test opening a fresh schema DB asserting the hot queries'
  `EXPLAIN QUERY PLAN` output contains `USING INDEX`. Query-plan assertions
  are CI-stable where timing assertions are not.
- No schema version bump: `beforeOpen` only, so no collision with parallel
  branch migrations (schema stays at v102).

### WS1 — Search

- Phase A (surgical): cap results (`LIMIT 100` with a "showing first 100"
  affordance); hydrate matches as `DiveSummary` rows via the existing
  paginated-list machinery (slim `customSelect` + batched tags/types) instead
  of full `_mapRowToDive` hydration; debounce search-as-you-type input.
- Phase B (FTS5): a `dive_search_index` FTS5 table covering notes, site
  name/location, buddy names, tags, dive center, and custom-field values.
  Populated by a one-time backfill migration; kept current at the repository
  write layer (the single seam all dive writes pass through), not triggers,
  to avoid trigger/sync interaction surprises. Query becomes indexed `MATCH`
  with prefix support, ranked, joined back to `dives` by id.
- Phase B ships only if Phase A's measured numbers still miss the 500 ms
  target on realistic terms. Accepted semantic change for Phase B:
  word-prefix matching instead of arbitrary substring.

### WS2 — Dive detail load path

1. One profile read per open: a single per-dive profile fetch (all sources,
   one indexed query) shared by `diveProvider` and `sourceProfilesProvider`
   — likely a `diveProfileBundleProvider` both consume. Design constraint:
   exactly one `dive_profiles` query per detail open. Exact wiring decided in
   the implementation plan.
2. Narrow hydration for analysis lookbacks: `getPreviousDive` /
   `getDivesInRange` currently return fully hydrated `Dive`s when the
   analysis needs only profile + tanks + timestamps. Add a lean
   `getDiveForAnalysis` accessor; the lookback chains switch to it.
3. Analysis off the critical path (approved UX change): the page renders core
   content immediately; the deco panel, residual-tissue values, and weekly
   OTU resolve asynchronously with "calculating" placeholders. The existing
   `_lastDecoPanelAnalysis` anti-flicker fallback generalizes into this.
4. Bound and cache the chains: residual chains keep their physiological
   semantics (walk back until 24 h / 48 h surface interval) but per-dive
   analysis results get memoized in a session-scope LRU keyed by dive id +
   profile revision, so consecutive detail opens within a trip share prior
   analyses. A persisted analysis-cache table is explicitly deferred: measure
   first; the in-memory cache plus WS0 indexes probably suffices, and a
   schema table brings sync/invalidation complexity we should not buy blind.

### WS3 — Chart scaling

1. Wire the existing tested decimator (`decimateProfileIndices`) into series
   building: main depth line, each metric curve, and every overlay series
   decimate to a render budget of ~1,500-2,000 points per series.
   Feature-preserving: peaks, ceiling violations, and gas switches survive.
2. Zoom-aware re-decimation: decimate over the visible window so zooming
   progressively restores full sample detail.
3. Per-series cache scoping: split the single `'main'` cache signature so a
   toggle rebuilds only the affected series.
4. Ceiling toggle specifically: switching calculated/computer must not re-run
   analysis (WS2 caches it) and must not rebuild unrelated series. Target
   < 200 ms.
5. `isCurved` cost is measured post-decimation; at ~2k points the smooth
   rendering is likely fine to keep.

### WS4 — Dashboard startup and table mode

- Replace each dashboard consumer of `getAllDives()` with bounded SQL:
  recent dives = `getDiveSummaries(limit: 3)`; personal records = `MIN`/`MAX`
  aggregates; month/YTD = `COUNT` with date ranges. The statistics repository
  already demonstrates every pattern needed.
- Table mode moves onto the paginated summary query with SQL sort. The
  "detailed card needs full dive" leak is fixed by widening the summary
  column set to cover configurable card fields rather than falling back to
  `getAllDives()`.
- End state: nothing in the app calls `getAllDives()` on a hot path. Remaining
  legacy consumers of `diveListNotifierProvider` get an audit note in the
  implementation plan.

### WS5 — DB off the UI isolate (S4)

- Switch the Drift executor to a background isolate
  (`NativeDatabase.createInBackground`), keeping the repository API and
  stream queries unchanged (Drift proxies them over the isolate port).
- Sequenced last deliberately: by then the workload is lean, per-workstream
  behavior tests exist, and the Phase 2 sync-parity suite (byte-for-byte
  tests) verifies the merge path.
- Plan-level attention: `beforeOpen` re-asserts run on the isolate; the
  sqlite temp-dir handling from the #509 work; interplay with the S3 sync
  parse worker.
- Success metric: zero dropped frames during an active sync while scrolling
  the dive list. This is also the structural ANR fix — after WS5 no future
  regression can block frames with DB work.

## Testing and regression protection

- TDD per workstream: query-plan assertions (WS0); search parity tests
  old-vs-new on a seeded DB (WS1); profile-read-count tests asserting exactly
  one `dive_profiles` query per detail open via Drift statement logging
  (WS2); decimation goldens on technical profiles (WS3); dashboard value
  parity tests SQL-vs-legacy (WS4); the existing sync parity suite re-run
  (WS5).
- The five-scenario runbook (with committed `tools/vmcap.dart`) is the manual
  before/after gate for every PR in this program.
- Whole-project `dart format .` and `flutter analyze` before each push.

## Risks

| Risk | Mitigation |
|---|---|
| WS0 first-open index build stalls very large DBs | Measured behind splash; `IF NOT EXISTS` makes it one-time; progress UI if over a few seconds |
| FTS5 index drifts from source tables | Repository-layer writes (single seam), backfill migration, parity test; Phase B only ships if Phase A misses target |
| Decimation hides a real profile spike | Feature-preserving algorithm; zoom restores full detail; goldens on technical profiles |
| WS5 isolate breaks sync / temp-dir / beforeOpen assumptions | Sequenced last; parity suite; inline-fallback pattern proven in S3 (PR #415) |
| Migration collisions with parallel branches | WS0 uses `beforeOpen` (no version bump); FTS5, if needed, takes v103+ |

## Rollout

Each workstream is an independent PR off main with its own measurement
evidence, so any workstream can ship alone and the program can stop early if
targets are met — plausibly as soon as WS0 + WS1. Android and Windows
verification (including the ANR scenario) happens after the workstreams
land, before release notes claim the improvement.
