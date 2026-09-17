# Restore journal: never delete a `.pre-restore` that may be the only copy

Date: 2026-09-13
Issue: #1901
Delivery: one PR, based on `main`
Related: PR #1856 (open, fork `urbamax/submersion`, `fix/restore-cleanup-resilience`)

## Problem

`DatabaseService.restore` (`lib/core/services/database_service.dart`) moves
the live database aside to `<db>.pre-restore` (with its `-wal`/`-shm`) before
swapping a backup in. Two code paths delete that file unconditionally as a
"stale leftover":

1. The swap step `await _deleteIfExists(asidePath);`, which runs after
   `close(strict: true)`.
2. `_sweepRestoreTempFiles`, run when the restore source is missing, which
   best-effort deletes `.pre-restore` and its sidecars.

That is only safe when `.pre-restore` really is a leftover of a restore that
completed. Several paths on `main` today end with the database closed, an
exception thrown, and the user's original database existing only at
`.pre-restore`:

- **Case 1, newer-schema rollback stops.** The
  `on DatabaseVersionMismatchException` handler deletes the rejected file
  strictly before renaming the original back. If a delete throws, the
  original is stranded aside while the too-new file sits at the live path.
  PR #1856 makes this stop deliberate (it refuses to pair the original with a
  foreign journal), with the same end state.
- **Case 2, swap-failure rollback rename throws.** The live path is left
  missing. On the next launch `_openDatabase` treats a missing file as a first
  run and `onCreate` creates a fresh, empty database there.
- **Case 3, post-swap failure other than a version mismatch.**
  `encryptInPlace` throws, or the reopen fails on a corrupt restored file. The
  restored file is live; the last good database is at `.pre-restore`.

On the next launch the startup page (`lib/core/presentation/pages/startup_page.dart`)
can offer a downgrade restore from the schema-mismatch screen (case 1).
`_preserveNewerDatabase` saves the too-new file, then `restore()` runs and its
first swap step deletes `.pre-restore`: the only copy of the user's data. A
restore pointed at a missing file sweeps it the same way, and the sweep's
"safe while the live database is open" premise does not hold at startup, where
nothing is open.

A probe of the live file alone cannot tell these states apart: in case 2 the
fresh empty database created on the next launch opens cleanly at the current
schema, so it looks healthy while the real data sits aside.

## Goals

- No code path deletes a `.pre-restore` unless it is provably a leftover of a
  completed restore.
- A `.pre-restore` that may be the only copy is preserved on disk, and a new
  restore still proceeds (the startup downgrade restore keeps working).
- On the next launch, an interrupted restore is detected before anything is
  opened, and the user is offered recovery of their previous database.
- Every failure of the new machinery costs disk space or an extra prompt,
  never data.

## Non-goals (each filed as a follow-up issue)

- Listing, restoring or pruning quarantined files from the Backups UI.
- Recovering users whose earlier launch, on a build without this fix, already
  replaced a missing live file with a fresh empty database. That state cannot
  be told apart from a healthy install without a content heuristic.
- Changing PR #1856's rollback ordering; this design composes with it.

## Design

### 1. `RestoreJournal` (new, `lib/core/services/restore_journal.dart`)

A file-only unit (no Drift connections), so it is testable against real temp
files without the singleton. `database_service.dart` is already 1085 lines,
past the 800-line cap, so the logic lives here rather than growing it.

Constructor inputs:

- `dbPath`: the live database path.
- `readSchemaVersion`: `int? Function(String path)`, defaulting (at the call
  sites) to `DatabaseService.getStoredSchemaVersion(path, keyHex: <live key>)`.
- `deleteFile`: `Future<void> Function(String path)`. `DatabaseService` passes
  its `_deleteIfExists`, so the `debugFailDeleteFor` test seam reaches every
  journal delete.
- `now`: `DateTime Function()`, for timestamps; defaults to `DateTime.now`.

Paths:

- Marker: `<db>.restore-pending`
- Aside copy: `<db>.pre-restore` (plus `-wal`, `-shm`)

Members:

| Member | Behaviour |
| --- | --- |
| `begin()` | Writes the marker with `flush: true`. Content is `{"startedAt": "<UTC ISO-8601>"}`. |
| `commit()` | Deletes the marker. |
| `hasMarker` | Marker exists. Presence is the whole signal; unparseable content still counts as present. |
| `classifyPreRestore()` | Returns `none`, `stale` or `precious` (rules below). |
| `quarantine(path)` | Renames `path` and its `-wal`/`-shm` to `<path>.<yyyyMMddTHHmmssZ>` (sidecars as `<path>.<ts>-wal` so SQLite still pairs them). If the target exists, appends `-1`, `-2`, and so on. Returns the new main path. |
| `findInterrupted()` | Synchronous startup query, returns `InterruptedRestore?`. |
| `recover()` | Puts the original back (below). |
| `keepCurrent()` | Quarantines `.pre-restore`, then `commit()`. |

Classification of an existing `.pre-restore`:

- `none`: no `.pre-restore` and no `.pre-restore-wal` or `-shm`. An orphaned
  sidecar is classified like a main file, so it is never left to pair with the
  next swap's aside copy. `quarantine` tolerates a missing main file for the
  same reason.
- `precious`: the marker exists; or, with no marker (a leftover from a build
  without the journal), the live file is missing, `readSchemaVersion` throws
  (including `DatabaseLockedException`), returns null or 0, or returns a
  version above `AppDatabase.currentSchemaVersion`.
- `stale`: no marker, and the live file reports a version in
  `1..currentSchemaVersion`.

`findInterrupted()` returns a value only when `.pre-restore` exists, is
`precious`, and is itself recoverable: `readSchemaVersion(.pre-restore)`
returns a version in `1..currentSchemaVersion`. The value carries `startedAt`
(parsed from the marker; null for a legacy leftover or unparseable content)
and `liveExists`. A marker with no `.pre-restore` is an orphan: it is deleted
best-effort and the result is null. A precious but unrecoverable
`.pre-restore` returns null: no offer that would fail the same way the
database just did. Startup then continues as it does today, and the restore
guard below still protects the file. The method is synchronous (sync stat,
sync probe, sync marker read), matching `_loadDowngradeOption`, whose async
form left widget tests pumping until timeout.

`recover()` runs with the database closed and is idempotent under retry:

1. If a live file exists, quarantine it and its sidecars to
   `<db>.restore-rejected.<ts>`. It is kept, not deleted: in case 3 it may be
   the backup the user wanted.
2. Rename `.pre-restore` and its sidecars to the live path.
3. `commit()`.

A crash after step 1 leaves the live path missing with the marker and
`.pre-restore` intact, which the next launch detects again; step 1 is then a
no-op.

### 2. `DatabaseService.restore()` changes

1. **Missing source.** `_sweepRestoreTempFiles` still deletes
   `.restore-staging`. It deletes `.pre-restore` and its sidecars only when
   `classifyPreRestore()` returns `stale`, leaves a `precious` one untouched,
   and never touches the marker.
2. **Staging copy.** Unchanged.
3. **Leftover handling, before `close()`.** New. With the database still open:
   a `stale` leftover is deleted strictly (with sidecars); a `precious` one is
   quarantined and a warning logged (an old marker needs no separate commit:
   `begin()` in step 4 overwrites it). A
   failure of either aborts the restore: the staging copy is cleaned up
   best-effort, the error propagates, and the live database was never closed.
   This replaces the unconditional `_deleteIfExists(asidePath)` inside the
   unavailable window, and so also covers the concern PR #1856 fixes by moving
   that line into the swap's `try`.
4. **`begin()`.** New. Failure aborts the same way as step 3.
5. **Close and swap.** `close(strict: true)`, the window seam, and the swap
   are unchanged apart from the removed delete.
6. **Settling the outcome.**
   - Reopen succeeds: `commit()` first (best-effort, logged), then the
     existing best-effort delete of `.pre-restore` and its sidecars. The
     marker's deletion is the commit point.
   - Swap-failure catch and the newer-schema handler: after their rollback
     block, `commit()` (best-effort) when `.pre-restore` no longer exists. The
     marker protects `.pre-restore`; with nothing aside there is nothing to
     protect.
   - Every path that leaves `.pre-restore` in place (the rollback rename
     throws, the rollback stops, `encryptInPlace` throws, a reopen fails with
     anything other than a version mismatch) leaves the marker, so the next
     launch shows the recovery screen.

Ordering rationale: step 3 before step 4 means a new marker is only ever
paired with the `.pre-restore` its own swap creates. If the marker were
written first, a crash between writing it and clearing an old stale leftover
would pair them, and the next launch would offer to recover a database the
user replaced long ago.

Failure directions: a marker that cannot be committed after a success costs
one unnecessary recovery prompt. A committed marker whose `.pre-restore`
delete failed leaves a leftover the probe later classifies as `stale`. No
ordering of crashes or failures deletes a `precious` file.

`DatabaseService` gains `debugFailDeleteFor` with PR #1856's exact name,
shape and semantics (a `Set<String>?` checked before the existence test in
`_deleteIfExists`, cleared by `resetForTesting`), so whichever PR merges
second resolves a trivial conflict.

### 3. Startup detection and flow (`startup_page.dart`)

Kept thin; the page is already 1709 lines.

- New `_StartupState.interruptedRestore` and field
  `InterruptedRestore? _interruptedRestore`.
- In `_runInitialization`, immediately after `_resolveSecurityGate(dbPath)`
  (the probe needs the cipher key) and before the schema probe:
  `findInterrupted()`; if non-null, set the state and return. Nothing is
  opened, so `onCreate` never runs over a missing live file.
- Actions use the existing `StartupRestoreStatus` (idle, running, failed):
  - Recover: `recover()`, then reset state and rerun `_runInitialization()`
    from the top, like `_restoreAtStartup`, so the security gate, migrations
    and the mismatch screen all run normally afterwards.
  - Keep current: `keepCurrent()`, then rerun `_runInitialization()`.
  - Failure: stay on the screen with the error.
- New test seam on `StartupWrapper`, next to the existing overrides:
  `RestoreJournal Function(String dbPath)? restoreJournalFactory`, so widget
  tests inject a fake journal.

Per case: in case 1, Recover restores the user's own database and Keep
current leads to the version-mismatch screen as today. In case 2 only Recover
is offered. In case 3 the user chooses between the previous and the restored
database.

### 4. `InterruptedRestoreView` (new, `lib/core/presentation/widgets/interrupted_restore_view.dart`)

A `StatelessWidget` shaped like `VersionMismatchView`: scrolls itself, takes
`textColor` and `subtitleColor`, receives `StartupRestoreStatus` and `error`
from the page. `StartupRestoreCard` is not reused (it requires a
`BackupRecord`), but its conventions are: dates format through
`MaterialLocalizations`, because the saved locale is not readable yet.

- `Icons.restore_page` in orange, title, body with or without a date.
- Primary `FilledButton`: Recover. When `liveExists`, a caption says the
  current file is kept, not deleted.
- Secondary `OutlinedButton`: Keep current, hidden when `!liveExists`, with a
  caption saying the previous database is kept as a file in the database
  folder.
- `TextButton`: Close.
- While running, both actions are disabled and a progress indicator shows; on
  failure, the failed message shows.

English copy (keys `startup_interruptedRestore_*`, added to all 11 ARB files;
only `app_en.arb` is alphabetical, so the other ten insert beside a
neighbouring key; then regenerate):

| Key | Text |
| --- | --- |
| `title` | A restore did not finish |
| `bodyWithDate` | Submersion was restoring a backup on {date} when it stopped. Your dive log from before that restore is still on this device, and this version can open it. |
| `body` | Submersion was restoring a backup when it stopped. Your dive log from before that restore is still on this device, and this version can open it. |
| `recoverAction` | Recover my previous dive log |
| `recoverNote` | The file that is in its place now is kept beside it, not deleted. |
| `keepAction` | Keep what is there now |
| `keepNote` | Your previous dive log is kept as a file in the database folder. |
| `failed` | Recovery did not complete. Nothing was deleted; both files are still on this device. |

## Testing (TDD: each test is seen red before its code)

1. `test/core/services/restore_journal_test.dart` (new; real temp files, fake
   schema reader and clock):
   - classification matrix: marker present or absent, crossed with a live file
     that is missing, throws, returns null, 0, too new, or in range;
   - quarantine moves sidecars, uses the timestamp name, and suffixes on
     collision;
   - `findInterrupted`: orphan marker cleared, unrecoverable `.pre-restore`
     returns null, unparseable marker returns a value with a null date,
     `liveExists` reported;
   - `recover()` idempotent after a simulated crash between steps 1 and 2;
   - `keepCurrent()` quarantines and commits.
2. `test/core/services/database_service_isolate_test.dart` (the real
   `restore()`):
   - headline regression: stage the stranded state (live file stamped
     `PRAGMA user_version = currentSchemaVersion + 1`, the original at
     `.pre-restore`, the marker present), run a restore of a valid older
     backup, and assert the original's rows are readable from
     `.pre-restore.<ts>`;
   - the same through the legacy probe, with no marker;
   - end to end: a newer-schema restore whose rollback delete fails through
     `debugFailDeleteFor` leaves the marker and `.pre-restore`; a second
     restore then quarantines rather than deletes;
   - the missing-source sweep leaves a `precious` `.pre-restore` untouched;
   - a locked `stale` leftover aborts the restore with the database still
     open and queryable;
   - the marker is committed on success and on both successful rollbacks.
   - The existing sweep tests stay green unchanged: their `'stale'` files sit
     next to a healthy database, so the probe classifies them `stale`.
3. Widgets:
   - `test/core/presentation/widgets/interrupted_restore_view_test.dart`:
     buttons per `liveExists`, running and failed states, date and no date;
   - `test/core/presentation/pages/startup_page_test.dart`, through
     `restoreJournalFactory`: the screen appears before the schema probe and
     initializer are called; Recover and Keep current each rerun
     initialization; a failure keeps the screen with the error.

## Delivery

- The PR body says `Closes #1901` and `Refs #1856`.
- One PR from a branch off `origin/main`, including the l10n regeneration.
- Leave a comment on PR #1856 describing the overlap (the shared seam, and
  that step 3 supersedes its move of the `.pre-restore` delete).
- No tool or model attribution in commits, the PR, or comments.
