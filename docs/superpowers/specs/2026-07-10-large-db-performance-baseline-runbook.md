# Large-DB Performance Measurement Runbook (Phase 3)

Applies to every workstream gate in the Phase 3 program
(2026-07-10-large-db-performance-design.md). Two layers.

## Layer 1: SQL-level (automated, per-PR)

1. App CLOSED. Fixture (already created once):

   ```bash
   sqlite3 ~/Library/Containers/app.submersion/Data/Documents/Submersion/submersion.db \
     ".backup '$HOME/SubmersionBench/pristine-20260710.db'"
   ```

2. Fresh working copy:

   ```bash
   cp ~/SubmersionBench/pristine-20260710.db ~/SubmersionBench/work.db
   ```

3. Before: `dart run tools/db_bench.dart bench ~/SubmersionBench/work.db`
4. Apply the change under test (for WS0:
   `dart run tools/db_bench.dart create-indexes ~/SubmersionBench/work.db`).
5. After: `dart run tools/db_bench.dart bench ~/SubmersionBench/work.db`
6. Plans: `dart run tools/db_bench.dart plans ~/SubmersionBench/work.db`
7. Record medians and plans in
   2026-07-10-large-db-performance-findings.md.

CAUTION: after WS0 ships, opening ANY copy with the app (or any AppDatabase)
heals its indexes -- for a true "before", always start from the pristine
file, which predates WS0 and must never be opened by the app.

## Layer 2: UI-level (user-paced, per-workstream re-baseline)

Launch: `flutter run --profile -d macos`
(debug builds overstate costs; profile mode is the honest one).
Copy the VM service `ws://` URI from the launch output.

The five anchor scenarios (record wall time + vmcap output for each):

1. Cold start: quit app; time launch to dashboard interactive (stopwatch);
   then `dart run tools/vmcap.dart <ws-uri> read` for startup CPU
   attribution.
2. Search: `vmcap clear`, type a term matching many dives in dive search,
   results visible, `vmcap read`. Record wall time to results.
3. Detail open x3: densest single-computer dive, a 2-computer dive, a dive
   at the end of a dense repetitive week. `vmcap clear` before each tap,
   `vmcap read` when the page settles.
4. Chart toggles: on the dense technical dive -- ceiling calculated to
   computer and back, one overlay on/off. `vmcap frames 10` while toggling.
5. List stress: table view mode on, then a fast scroll through the paginated
   card list. `vmcap frames 10`.

Record everything in 2026-07-10-large-db-performance-findings.md with date
and commit hash.

## vmcap gotchas (from the June 2026 Phase 1 effort)

- Always run `clear` immediately before the interaction window; otherwise
  the VM service's own JSON serialization dominates the samples.
- `frames` counts only events timestamped after subscribing, because the VM
  replays its historical frame buffer to new subscribers.
- A sandboxed browser cannot reach the host VM-service port; run vmcap from
  a normal shell.
- `--trace-startup` kills the app at first frame; do not use it to measure
  the startup floor.
