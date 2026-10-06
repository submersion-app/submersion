# Large-DB Performance Findings (Phase 3)

Fixture: pristine-20260710.db -- 1,032 dives / 1,077,216 dive_profiles rows /
784,752 tank_pressure_profiles rows / 34 multi-computer dives / 335 MB.
Machine: Apple M5 Pro (macOS).
Tool: tools/db_bench.dart (median of 5), commit of record on branch
large-db-perf-ws0.

Pre-WS0 index state of the fixture (and of any fresh install / restored /
sync-adopted database): 6 user indexes present out of ~40 intended, because
index creation lived only in onUpgrade migration blocks. See the design spec
(2026-07-10-large-db-performance-design.md) for the mechanism.

## WS0 SQL-level A/B (same fixture, before vs after kPerformanceIndexes)

| Query | Rows | Before (ms) | After (ms) |
|---|---|---|---|
| profile_fetch_densest | 4,762 | 39.2 | 4.0 |
| pressure_fetch_densest | 0 | 26.6 | 0.0 |
| tanks_fetch | 2 | 0.1 | 0.0 |
| summaries_page1 | 50 | 0.3 | 0.8 |
| dive_count | 1 | 0.0 | 0.0 |
| search_match_ids ("blue") | 74 | 4.6 | 3.2 |
| prev_dive | 1 | 0.8 | 0.3 |
| tags_for_page (50 ids) | 174 | 0.4 | 0.1 |
| search_hydration_first20 | 20 | 1,298.0 | 17.0 |

Reading the table:

- The pain is concentrated in per-dive fetches against the two million-row
  tables. Unindexed, EVERY per-dive profile fetch scans 1,077,216 rows
  (39 ms) and every pressure fetch scans 784,752 rows (26.6 ms even when the
  dive has ZERO pressure rows).
- search_hydration_first20 is the mechanical confirmation of the reported
  "20+ second search": 1.3 s for only 20 of 74 matches running only 3 of the
  ~10 per-dive hydration queries the app really runs. Extrapolated
  (74 matches, ~10 queries), full hydration lands around 16 s before WS0 and
  around 0.2 s after -- a ~76x improvement from indexes alone. The remaining
  N+1 shape is WS1's target.
- The LIKE match query itself was never the search bottleneck at this scale
  (4.6 ms): SQLite built AUTOMATIC COVERING INDEXes for the unindexed
  junctions at query time. The hydration N+1 was the bottleneck.
- summaries_page1 and the statistics-style aggregates were already fine
  (the dives table itself is only 1,032 rows); 0.3 -> 0.8 ms is noise.

Index build cost (the one-time first-open heal stall): **534 ms total for 35
indexes including ANALYZE (54 ms)**. Slowest: idx_tank_pressure_dive_tank
243 ms, idx_dive_profiles_dive_id 205 ms; everything else under 10 ms. This
disappears behind the existing ~1 s startup splash -- no progress UI needed
(the spec's threshold for that was ~10 s).

## Query plan evidence

Before (hot queries):

```text
profile_fetch:  SCAN dive_profiles                 + TEMP B-TREE FOR ORDER BY
pressure_fetch: SCAN tank_pressure_profiles        + TEMP B-TREE FOR ORDER BY
tanks_fetch:    SCAN dive_tanks
tags_for_page:  SCAN dive_tags
prev_dive:      SCAN dives                         + TEMP B-TREE FOR ORDER BY
```

After:

```text
profile_fetch:  SEARCH dive_profiles USING INDEX idx_dive_profiles_dive_id (dive_id=?)
pressure_fetch: SEARCH tank_pressure_profiles USING INDEX idx_tank_pressure_dive_tank (dive_id=?)
tanks_fetch:    SEARCH dive_tanks USING INDEX idx_dive_tanks_dive_id (dive_id=?)
tags_for_page:  SEARCH dive_tags USING INDEX idx_dive_tags_dive_id (dive_id=?)
prev_dive:      MULTI-INDEX OR ... USING INDEX idx_dives_diver_entrytime
search joins:   SEARCH db/dt/cf USING INDEX idx_dive_buddies/tags/custom_fields_dive_id
```

## Decision log

- Expression index idx_dives_diver_sort_timestamp
  (`dives(diver_id, COALESCE(entry_time, dive_date_time) DESC)`): the planner
  never selected it -- summaries_page1 chose idx_dives_favorite for the
  diver_id equality and still sorted 50 rows via TEMP B-TREE, because sorting
  a ~1k-row candidate set is cheaper than maintaining expression-index
  ordering. Timing was unaffected (0.3 vs 0.8 ms, noise). DROPPED from the
  canonical list in Task 4; it would cost write amplification on every dive
  insert for no measured benefit.
- pressure_fetch returning 0 rows for the densest dive is expected data
  shape (that dive has no transmitter data), and it makes the point well:
  unindexed, absence-of-data still cost a 785k-row scan.

## In-app verification (Task 5, 2026-07-10)

- Live DB healed on first open: 6 -> 40 user indexes (exactly the canonical
  list; 34 created on this open) after a single `flutter run -d macos`
  launch of the WS0 build. `EXPLAIN QUERY PLAN` on the live DB confirms
  `SEARCH dive_profiles USING INDEX idx_dive_profiles_dive_id`;
  sqlite_stat1 populated (48 rows), so ANALYZE ran.
- Expected heal cost was 534 ms (fixture-measured, identical data); startup
  showed no user-visible stall behind the splash.
- Logging caveat: the heal message uses dart:developer `log`, which appears
  in the DevTools logging view, NOT in `flutter run` stdout. Absence of a
  console line is not evidence the heal did not run; check
  sqlite_master.
- beforeOpen steady-state cost on an already-healed DB: one sqlite_master
  read + no DDL (idempotency unit-tested; created list empty). Confirmed
  in-app by startup instrumentation: `[startup] database: 3ms` on the
  second profile launch.

### Real-world heal cost (differs sharply from the fixture number)

The fixture measured 534 ms because the file was warm in the OS page cache
from the copy. On the real, cold 335 MB database the first (debug) launch
froze ~20 s at the splash, and the NEXT (profile) launch froze ~20 s again
with near-zero CPU across every thread (native `sample` evidence): the heal
had written hundreds of MB of index pages into the WAL, and the next open
paid WAL recovery/checkpoint -- pure disk I/O. Once checkpointed, the
following launch was instant (total init 9 ms).

Mitigation shipped in WS0: `PRAGMA wal_checkpoint(TRUNCATE)` immediately
after a non-empty heal, so the entire cost is paid once, inside the first
splash, and cannot leak into the next launch. Residual: the first-open
stall itself (up to ~20 s cold on very large DBs) currently shows only the
static splash -- progress UI is a product decision recorded below.

## Post-WS0 UI re-baseline (profile mode, Apple M5 Pro, 2026-07-10)

Captured with tools/vmcap.dart per the runbook; values are main-isolate CPU
time attributed by the Dart profiler during the interaction.

| Scenario | Measured | Target | Verdict |
|---|---|---|---|
| Startup (steady state) | 9 ms init + 1 s splash floor | < 2 s | MET (post-WS0) |
| Search, one character | ~3.5 s CPU | < 500 ms | WS1 |
| Detail open, dive 1006 (4,762 samples) | ~11 s CPU | < 500 ms | WS2 |
| Ceiling-source toggle | ~0.85 s CPU per toggle | < 200 ms | WS3 |

Signatures (what the profiler actually showed):

- Search: sqlite3VdbeExec on the main isolate + per-query SQL string
  building (_concatAll/_interpolate) + Map churn + mutex slow paths =
  thousands of tiny queries. The N+1 hydration shape, not SQLite speed, is
  now the cost. WS1 Phase A (bounded results, batched DiveSummary
  hydration, input debounce) attacks exactly this.
- Detail open: 23.7% raw allocation (TLAB) + pervasive dynamic-invocation
  type checks = hydrating enormous object graphs (double full-profile read,
  Buhlmann + residual CNS/tissue/OTU + weekly OTU lookback chains fully
  hydrating dozens of prior dives). WS2's items map one-to-one.
- Ceiling toggle: Skia dash-path measurement (SkContourMeasure::getSegment)
  + full series rebuild = undecimated 4,762-point curves redrawn wholesale
  per toggle. WS3 (decimation + per-series cache scoping) maps directly.

### Debug-only startup freeze (persistent, ~20 s per debug launch)

After the heal and WAL checkpoint, `flutter run -d macos` (debug) still froze
~20 s at the splash fade on every launch, while profile mode was clean.
Startup instrumentation put all six init steps at ~220 ms total and the
first frame after the ready state at 265 ms -- the freeze is NOT init and
NOT the widget build; it begins when the dashboard's async providers
resolve. Native sampling during the freeze shows the io.flutter.ui thread
spending 87% of the window in DartMicrotaskQueue::RunMicrotasks with ~40%
inside
dart::Compiler::CompileOptimizedFunction / FlowGraphInliner::Inline via
DRT_InterruptOrStackOverflow: the debug JIT's OPTIMIZING COMPILER running
synchronously on the UI thread, recompiling the hot Drift row-mapping
functions that the dashboard's getAllDives() microtask flood makes hot.

Implications:
- Debug-launch pain is WS4's workload amplified by JIT compilation of the
  very large generated database.g.dart mapping code. AOT (profile/release)
  users pay only the raw hydration (~1-2 s today, hidden behind the fade),
  which still scales linearly with dive count.
- No WS0 action; this hardens the case for WS4 (remove hot-path
  getAllDives) which fixes both the debug developer experience and the
  release-mode scaling liability.

## Recommended workstream order (evidence-based)

1. WS1 search (small change, 3.5 s -> sub-500 ms expected; fires on every
   keystroke so perceived cost is multiplied).
2. WS2 detail load path (largest absolute cost, 11 s; also the
   multi-computer complaint).
3. WS3 chart scaling (0.85 s per toggle; also shrinks WS2's chart share).
4. WS4 dashboard (startup steady-state already meets target post-WS0;
   getAllDives remains a scaling liability, not the current bottleneck).
5. WS5 DB isolate (unchanged: last, structural).
