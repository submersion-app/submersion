# Pre-Migration Database Backup

**Date:** 2026-04-12

## Problem

When `AppDatabase` opens at app startup with a stored schema version lower
than `currentSchemaVersion`, Drift runs the `onUpgrade` migration
strategy. Migration runs against the user's real dive log — dozens of
tables with many years of data. A bug in a migration step, a
platform-specific sqlite quirk, or a partial failure mid-migration can
leave the user with a damaged database and no way back.

The app already has a mature `BackupService` for manual and automatic
backups, but nothing is wired into the startup path. The user's most
recent backup may be weeks old, or they may never have triggered one.
The exact moment when damage is most likely is also the moment when the
user has no safety net.

## Solution

Add a `PreMigrationBackupService` that runs in the existing
`StartupPage` state machine, after the schema-version probe but before
Drift opens the database. When `storedSchemaVersion <
currentSchemaVersion`, the service makes a file-level copy of
`submersion.db` into `BackupService`'s existing backup folder and
registers it via the existing `BackupPreferences` registry (the same
SharedPreferences-backed registry that already tracks manual backups)
with `type: BackupType.preMigration`, then prunes older pre-migration
records to a rolling window of three (pinned records exempt).

Failure to back up hard-fails startup with a dedicated error screen
(Retry / Quit) — by design, the app must not migrate without a safety
net. Descriptor-write and prune failures soft-fail and are logged.

Pre-migration backups appear in the existing backup UI alongside manual
backups, distinguished by a `v63 → v64` badge. Users can pin any backup
(manual or pre-migration) to exempt it from retention. Restoring a
pre-migration backup shows a compatibility dialog that warns honestly
when the user's current app would re-trigger the same migration the
backup was made to protect against.

## Architecture and Components

### New code

- **`lib/features/backup/data/services/pre_migration_backup_service.dart`**
  — new service. Single method:
  `backupIfMigrationPending({required int stored, required int target,
  required String appVersion}) → Future<void>`. Operates on the closed
  DB file; holds no long-lived state. Throws
  `BackupFailedException` on unrecoverable error.

### Changes to existing code

- **`lib/features/backup/data/entities/backup_record.dart`** — extend
  the existing `BackupRecord` with new nullable fields: `type`
  (`BackupType` enum — `manual` or `preMigration`, default `manual`
  when absent), `appVersion` (String?), `fromSchemaVersion` (int?),
  `toSchemaVersion` (int?), `pinned` (bool, default `false`). Also
  make the existing `diveCount` / `siteCount` fields nullable because
  pre-migration records can't compute them (the DB is closed). Update
  `toJson` / `fromJson` to handle the new shape backward-compatibly
  (absent `type` → `manual`).
- **`lib/features/backup/data/services/backup_service.dart`** — add
  `pinBackup(String id)` / `unpinBackup(String id)` methods
  (rewrite the corresponding `BackupRecord` in `BackupPreferences`).
  Existing manual-backup code paths are otherwise untouched; because
  `getBackupHistory()` already returns every record in the registry,
  pre-migration records show up automatically once they're added.
- **`lib/core/services/startup_page.dart`** (or wherever
  `_runInitialization` lives) — after the schema probe and before
  `DatabaseService.initialize()`, invoke
  `PreMigrationBackupService.backupIfMigrationPending(...)`. Add
  `StartupState.backingUp` and `StartupState.backupFailed` to the
  startup state enum with their corresponding views.
- **Backup list UI** (under `lib/features/backup/presentation/`) — each
  row gains a pin/unpin icon button. Pre-migration rows gain a `v63 →
  v64` badge next to the timestamp.
- **Restore confirmation dialog** — new compatibility branching (see
  Restore UX below). Manual-backup dialog gains an `appVersion` line
  pulled from the descriptor.

### Why split `PreMigrationBackupService` out from `BackupService`

`BackupService` collects backup metadata (counts of dives, sites, etc.)
by querying the open DB. Pre-migration backups by definition run
*before* the DB is opened for migration, so that metadata path is
unavailable. Keeping two focused services avoids forcing
`BackupService` to carry two lifecycle modes ("operates on an open DB"
vs "operates on a closed DB file") with nullable fields and conditional
branches. The `BackupDescriptor` entity is the shared seam — both
services write descriptors into the same folder in the same format, and
the listing side stays unified.

## Data Flow and Sequencing

```
StartupPage._runInitialization
   │
   1. Read stored schema version via
   │    `DatabaseService.getStoredSchemaVersion()` (raw sqlite3,
   │    `PRAGMA user_version`)
   │
   2. Resolve DB path via DatabaseLocationService
   │
   3. Live DB file exists at path?
   │     ├─ no (fresh install) → skip backup, go to step 7
   │     └─ yes → continue
   │
   4. storedSchemaVersion < AppDatabase.currentSchemaVersion?
   │     ├─ no (up-to-date) → skip backup, go to step 7
   │     └─ yes → continue
   │
   5. UI state = StartupState.backingUp
   │
   6. PreMigrationBackupService.backupIfMigrationPending(...)
   │        6a. Sweep <backupsDir> for any .tmp files, delete them
   │        6b. Compute tempPath  = <backupsDir>/.<ts>-v<from>-v<to>.db.tmp
   │        6c. Compute finalPath = <backupsDir>/<ts>-v<from>-v<to>.db
   │        6d. Ensure backupsDir exists
   │        6e. File.copy(livePath, tempPath)
   │        6f. Rename tempPath → finalPath   (atomic on same filesystem)
   │        6g. Register via BackupPreferences.addRecord() with a
   │              BackupRecord: {id: uuid, filename, timestamp,
   │              sizeBytes, localPath: finalPath, type: preMigration,
   │              appVersion, fromSchemaVersion, toSchemaVersion,
   │              pinned: false, diveCount: null, siteCount: null}
   │        6h. Prune: load records where type == preMigration;
   │              partition by pinned; sort unpinned by timestamp DESC;
   │              keep first 3; for each to-delete unlink the .db
   │              file first, then remove the record via
   │              BackupPreferences.removeRecord()
   │        6i. Return void
   │
   │  On exception at 6b–6f: rethrow wrapped as BackupFailedException
   │  On exception at 6a, 6g, 6h: log at warning, do not abort
   │
   7. UI state = StartupState.migrating
   │   DatabaseService.initialize()   ← Drift opens DB, runs onUpgrade
   │
   8. UI state = StartupState.ready → navigate to app
```

### Atomicity

Every crash point must leave the filesystem + registry in a
recoverable state:

- Steps 6e + 6f use write-temp-then-rename so a crash during the copy
  never leaves a partial file being mistaken for a complete backup.
  The `.tmp` extension and leading dot also hide in-progress copies
  from Finder.
- Step 6h unlinks the paired `.db` file *before* removing the registry
  record during prune. A crash mid-prune leaves a registry record
  referencing a missing file — which the existing
  `BackupService.getValidatedBackupHistory()` already filters
  defensively, and which the user can dismiss through normal UI. This
  is preferable to the reverse order, which would silently leak `.db`
  files on disk (the `.tmp` sweep does not target `.db` files by
  design).
- Step 6g registers the record *after* the `.db` rename. A crash
  between 6f and 6g leaves an orphan `.db` on disk — safer than a
  record referring to a file that is not there. A subsequent
  successful run will NOT reuse the orphan filename (timestamps
  differ), so the orphan persists harmlessly.

Orphan `.db` files are *not* automatically deleted on startup. They
may be the user's only copy of a failed-to-register backup. The
`.tmp` sweep at step 6a only deletes provably-incomplete files.

## File Layout and Backup Record Format

### Directory layout

Pre-migration backup `.db` files live in `BackupService`'s existing
backup folder alongside manual backup `.db` files. The folder
contains *only* `.db` files; metadata is held in the
`BackupPreferences` registry (SharedPreferences), matching existing
practice:

```
<backupsDir>/
  20260101-143022-manual.db                ← existing manual
  20260412-081201000-v63-v64.db            ← new pre-migration
  .20260412-081535000-v63-v64.db.tmp       ← transient; swept on next
                                             migration-pending startup
```

### Filename convention

- Manual backups: existing convention (unchanged).
- Pre-migration backups: `<UTC-timestamp>-v<from>-v<to>.db` where
  timestamp is `yyyyMMdd-HHmmssSSS` (millisecond precision prevents
  same-second collisions on rapid retry). Encoding the schema pair in
  the filename makes the folder self-describing for support purposes
  (e.g., "the v63→v64 backup I'm looking for is on disk even if the
  SharedPreferences registry is lost in a reinstall").

### BackupRecord shape (extended)

The existing `BackupRecord` entity gets new fields:

| Field | Type | Default | Manual backup | Pre-migration backup |
| --- | --- | --- | --- | --- |
| `id` | String | (uuid) | uuid | uuid |
| `filename` | String | required | `...-manual.db` | `...-v63-v64.db` |
| `timestamp` | DateTime | required | set by service | set by service |
| `sizeBytes` | int | required | file size | file size |
| `location` | BackupLocation | required | local / cloud | local only |
| `diveCount` | int? | null | computed | null |
| `siteCount` | int? | null | computed | null |
| `cloudFileId` | String? | null | set if cloud | null |
| `localPath` | String? | null | set if local | set |
| `isAutomatic` | bool | false | existing | true |
| `type` *(new)* | BackupType | `manual` | `manual` | `preMigration` |
| `appVersion` *(new)* | String? | null | current version | current version |
| `fromSchemaVersion` *(new)* | int? | null | null | set |
| `toSchemaVersion` *(new)* | int? | null | null | set |
| `pinned` *(new)* | bool | false | user-toggled | user-toggled |

Making `diveCount` and `siteCount` nullable is necessary because
pre-migration backups can't compute them (the DB isn't open).
Backward compatibility is preserved via `toJson` / `fromJson`
fallbacks: `type` absent → `BackupType.manual`, `pinned` absent →
`false`, `appVersion` absent → `null`, count fields absent or
present → parsed as-is.

### Listing behaviour

`BackupService.getBackupHistory()` and `getValidatedBackupHistory()`
continue to return every record in the registry (no API change). The
row UI distinguishes types by reading `record.type`:

- Pre-migration → badge `v63 → v64`
- Pinned (either type) → filled pin icon; unpinned shows outlined pin

## Error Handling and Startup UI

### Startup states

```
StartupState {
  initial,
  checkingVersion,   // existing
  migrating,         // existing
  backingUp,         // new
  backupFailed,      // new
  ready,             // existing
}
```

### Backing-up screen

- Title: "Backing up your data"
- Body: "We're saving a copy of your dive log before updating your
  database."
- Indeterminate spinner, no cancel button (cancelling would strand the
  user in an inconsistent state).
- No progress bar in this change. `File.copy` is sub-second for
  typical dive logs and ~3–5 s for very large ones on SSD. We ship
  the spinner and measure before investing in chunked-copy progress,
  consistent with the "measure before optimising" policy.

### Backup-failed screen

- Title: "Couldn't back up your data"
- Body: human-readable cause (see classification below), followed by
  "Your dive log hasn't changed — we didn't update it. Free up space
  (or fix the issue) and try again."
- Primary: `Retry` → re-invokes `backupIfMigrationPending` only (not
  the full startup).
- Secondary: `Quit` → `SystemNavigator.pop()` on mobile, `exit(0)` on
  desktop.
- Expandable `Technical details` row with exception class + message,
  for copy-paste to support.

### Error classification

```
BackupFailedException(cause, userMessage, technicalDetails)
   ├─ DiskFull           // FileSystemException errorCode ENOSPC (28)
   ├─ PermissionDenied   // EACCES (13) / EPERM (1)
   ├─ SourceMissing
   ├─ RenameFailed
   └─ Unknown(e)
```

Classification matches on `FileSystemException.osError?.errorCode`
because OS error messages are localised on some platforms but
`errorCode` is a POSIX integer. `Unknown(e)` is always logged with a
full stack trace — never silently swallowed.

### What is *not* a hard failure

- Prune failures (step 6h) — logged at warning level, backup still
  succeeds. The user's data is safe the moment step 6f completes.
- Descriptor-write failures *after* successful `.db` rename — logged,
  retried once, then logged again if still failing. The backup is
  effectively orphaned from the listing UI but the data is on disk; a
  warning is surfaced in the backup list if the user opens it, but
  startup continues because the contract ("there will be a copy
  before migration runs") is already fulfilled.

## Retention, Pruning, and Pinning

### When pruning runs

Only after a successful backup, as step 6h. Not on app startup, not
on a timer, not on backup-list view. This means prune failures are
covered by the same error handling as the backup itself (soft-fail;
logged).

### Prune algorithm

1. Load all `BackupRecord`s from `BackupPreferences` where
   `type == BackupType.preMigration`.
2. Partition into pinned vs unpinned.
3. Sort unpinned by `timestamp` DESC.
4. Keep the first 3; mark the rest for deletion.
5. For each to-delete: unlink the `.db` file at `record.localPath`
   first (if non-null), then remove the record via
   `BackupPreferences.removeRecord(id)`.
6. Pinned backups are never deleted (unbounded by design — pinning is
   the user's explicit opt-in to retain).

### Pinning UX

- Every row in the backup list (manual and pre-migration alike) has a
  pin icon button on the trailing side, alongside the existing
  overflow menu.
- Tapping toggles `pinned` on the underlying `BackupRecord` via
  `BackupService.pinBackup(id)` / `unpinBackup(id)`.
- Filled icon = pinned; outlined icon = unpinned.
- No confirmation dialog; the operation is cheap and reversible.

Manual-backup retention is unchanged by this project ("keep forever").
Pinning a manual backup has no effect today but is honored by any
future manual-backup retention policy.

### Edge cases

| Case | Behaviour |
| --- | --- |
| User pins many pre-migration backups over years | All retained; pinning is explicit user intent. |
| N=3 but only 2 unpinned exist | No-op; prune list is empty. |
| Registry record exists but `.db` is missing | `getValidatedBackupHistory()` already flags this via existing validation; row can be dismissed, which calls `BackupPreferences.removeRecord(id)`. |
| `.db` on disk but no registry record (crash mid-creation, or user restored a reinstall with backups folder intact but prefs lost) | Not visible in listing. Startup `.tmp` sweep does **not** touch these. Orphans are logged at warning level as support recovery artefacts. |
| User manually deletes a `.db` via Finder | Same as "record with missing `.db`" case. |

## Restore UX

`BackupService.restoreFromBackup(BackupRecord)` already performs
"close DB → `File.copy` → reopen DB". Pre-migration restore reuses
this; the only new code is a compatibility-warning dialog layered on
top.

### The compatibility problem

A pre-migration backup's `.db` is at `fromSchemaVersion` (e.g. v63).
The currently-installed app targets `currentSchemaVersion` (e.g. v64).
Restoring the backup while running the current app overwrites the
live DB with a v63 file; on the next open, Drift sees `PRAGMA
user_version = 63` and re-runs `onUpgrade(63, 64)`. If that migration
is what damaged the user's data originally, **the same bug happens
again**.

The only safe recovery path is: install an older app version first,
then restore. The dialog must state this plainly.

### Confirmation dialog (pre-migration backup)

Fields pulled from the `BackupRecord`: `appVersion`, `timestamp`,
`fromSchemaVersion`, `toSchemaVersion`. The dialog branches on
schema compatibility:

| Situation | Dialog behaviour |
| --- | --- |
| `currentSchemaVersion == fromSchemaVersion` | Green path. "Restore safe — app version matches." Single `Restore` button. |
| `currentSchemaVersion > fromSchemaVersion` | Warning path. Explicitly states that restoring will re-run the same migration. `Restore anyway` styled destructive; also offers `Cancel`. |
| `currentSchemaVersion < fromSchemaVersion` | Hard block. "This backup is newer than your app. Install a newer app version to restore it." Only `Cancel`. |

### Manual-backup dialog

No behavioural change. Gains an `appVersion` line when the
underlying `BackupRecord.appVersion` is non-null (records created
before this change will have `appVersion == null` and the line is
simply omitted — no defensive conditional fallbacks needed).

### After restore

No change from existing `BackupService.restore()` behaviour. Drift
inspects `user_version` on reopen and migrates as needed.

## Testing Strategy

### Unit tests

`test/features/backup/pre_migration_backup_service_test.dart`:

- Happy path: copies live DB byte-for-byte.
- Registered `BackupRecord` has correct `type`, schema pair,
  `appVersion`, `timestamp`.
- Skip when live DB file does not exist (no exception, no output).
- Skip when `stored == target`.
- `.tmp` files from a previous crash are swept at step 6a of the
  next migration-pending invocation (not on every app startup).
- Prune keeps newest N unpinned plus all pinned.
- Prune removes registry record before unlinking `.db` (inject a
  fake `BackupPreferences` + filesystem where the file unlink fails;
  assert record is gone, `.db` survives as orphan).
- `ENOSPC` → `DiskFull`, `EACCES` → `PermissionDenied`, unknown code
  → `Unknown(e)`.
- Orphan `.db` with no corresponding registry record is preserved
  (not deleted on next run).

### Widget tests

`test/features/startup/pre_migration_backup_flow_test.dart`:

- `StartupState.backingUp` shows progress screen.
- Successful backup transitions to `migrating`.
- Failed backup shows `backupFailed` screen with classified message.
- `Retry` re-invokes the service only (not full startup).
- Classified errors render human-readable copy, not
  `exception.toString()`.

`test/features/backup/restore_dialog_compat_test.dart`:

- Green path when `currentSchema == fromSchema`.
- Warning path when `currentSchema > fromSchema`.
- Hard block when `currentSchema < fromSchema`.

### Integration test

`test/core/database/pre_migration_backup_integration_test.dart`:

- Seed a v63 SQLite file at the live DB path using the existing
  migration fixture pattern (`PRAGMA user_version = 63`).
- Stub `SharedPreferences` with `storedSchemaVersion = 63`.
- Run the full startup flow with `AppDatabase` at
  `currentSchemaVersion = 64`.
- Assert: (a) a pre-migration backup `.db` exists post-startup; (b)
  its bytes equal the original v63 seed; (c) the live DB opens at
  schema 64 with migrated rows.

### Out of scope for tests

- Cross-platform filesystem oddities (Windows path limits, Android SAF
  edges) — covered indirectly via the existing `BackupService` folder
  resolution, which is reused verbatim.
- Disk-full during integration tests — hard to simulate portably;
  unit-level error classification covers the code path.

## Out of Scope

- Making pre-migration backup retention user-configurable. N=3 is a
  constant; lifting it to settings adds test matrix for zero proven
  demand.
- Automatic upload of pre-migration backups to cloud storage. The
  existing `BackupService` cloud hooks are reachable by a user if they
  restore a pre-migration backup then manually upload it, but
  pre-migration backups do not auto-upload.
- Rolling out pinning to manual-backup retention semantics. The field
  is now present on manual descriptors, but manual retention remains
  "keep forever" as before.
- Schema downgrade. Drift does not support this; restoring a v63
  backup in a v64-only app will re-trigger the forward migration.
  The restore dialog surfaces this clearly; we do not attempt to
  mitigate at the storage layer.
