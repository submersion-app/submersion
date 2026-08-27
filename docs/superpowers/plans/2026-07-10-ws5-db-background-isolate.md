# WS5: Database Executor Off the UI Isolate Implementation Plan

> Executed inline (executing-plans) in worktree
> `.claude/worktrees/ws5-isolate`, branch `worktree-ws5-isolate`.

**Goal:** No SQLite statement ever executes on the UI isolate in normal
operation — the structural ANR fix (spec WS5). Sequenced last deliberately:
WS0-WS4 made the workload lean first, so the isolate boundary moves small
result sets, not bloated ones.

**Spec:** WS5 in `2026-07-10-large-db-performance-design.md`.

## History honored (why this was not a one-line flip)

`database_service.dart` deliberately used the synchronous `NativeDatabase`
with this comment: "Background isolates can cause close() to hang
indefinitely if called mid-migration." The migration path (progress
callbacks, pre-migration backup close/reopen, hot-journal recovery) is
battle-tested on the main-isolate executor and stays on it.

## Design: two-phase open in DatabaseService

- `_openDatabase(dbPath, {onMigrationProgress})`:
  1. `getStoredSchemaVersion(dbPath)`; if a migration is PENDING
     (0 < stored < current), open with the synchronous `NativeDatabase`
     exactly as today, force the upgrade ladder to completion
     (`SELECT 1`), then `close()` (post-migration, never mid-migration)
     and fall through.
  2. Open with `NativeDatabase.createInBackground(file)` — every
     statement now executes on drift's worker isolate; the repository API,
     stream queries, and transactions are unchanged (drift proxies them).
- Fresh databases (no file / user_version 0) skip phase 1: `onCreate` +
  the WS0 heal run through the remote executor (drift migration callbacks
  execute on the main isolate and issue statements remotely, so
  `onMigrationProgress` and `beforeOpen` semantics are unchanged).
- `reinitializeAtPath` uses the same helper (it can also hit a pending
  ladder when restoring an older file); its existing `SELECT 1` +
  timeout verification stays.
- A `@visibleForTesting lastOpenMode` field records which path ran
  (`background` | `migrationThenBackground`) so tests can pin the
  orchestration without reaching into drift internals.

## Why no isolateSetup / sqlite plumbing is needed

The app applies NO `open.overrideFor` / `sqlite3.tempDirectory` overrides
on the main isolate (verified by grep); it relies on the sqlite3 package's
default per-OS loading, which resolves the sqlite3_flutter_libs-bundled
library identically from any isolate. The #509 temp-dir work
(`resolveSyncTempDir`) concerns sync payload files, not SQLite, and is
executor-independent.

## Out of scope (recorded)

- `LocalCacheDatabaseService` (small cache DB) stays on the main isolate;
  follow-up candidate.
- The sync S3 parse worker interplay is unchanged: it parses in its own
  isolate and hands rows to the main isolate, which now issues writes
  through the remote executor (one more hop, off-UI both ways).

## Tasks

1. TDD `test/core/services/database_service_isolate_test.dart`:
   fresh-path open (mode `background`, `SELECT 1` works, WS0 index present
   through the remote executor, user_version == current); pending-migration
   path (seed a current-schema file, rewind `user_version` by one, expect
   mode `migrationThenBackground`, version healed to current, queries
   work); reinitializeAtPath keeps working.
2. Implement `_openDatabase` + `lastOpenMode`; wire `initialize` and
   `reinitializeAtPath`.
3. Regression: startup page suites, migration suites, WS0 suites, a sync
   suite file; whole-project analyze/format; commit; push --no-verify; PR.

## Verification gates

- New service tests green; migration/startup/WS0 suites green.
- Analyze/format clean.
- Residual (next user session): scroll the dive list during an active
  sync in profile mode — zero dropped frames expected (spec metric).
