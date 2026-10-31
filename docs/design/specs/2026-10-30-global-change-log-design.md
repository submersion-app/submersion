# Global change log

Status: awaiting approval. Target release: v1.8.4. Delivery: one PR.

Mockups: [change log page and entry detail](assets/2026-10-30-global-change-log-mockup.html).

## Why

Submersion has no general record of what changed. Only rule runs and cylinder
fills keep their own history. When data looks wrong, as in #1720 where gear
went missing from many dives, a diver cannot see what happened, when, or on
which device, and cannot put it back without restoring a whole backup.

The log is written constantly and read rarely, mostly when something looks
wrong. It has to be cheap and silent while recording, complete when it is
needed, and able to repair what it shows.

## Goals

- Record every change to user data, from every source, with old and new values.
- Show the changes as a readable feed and per-record history, in the diver's
  units and language.
- Let the diver revert a field, an entry or a whole bulk action, and bring back
  deleted records with their children.

## Non-goals

- History from before the update that adds the log. It starts empty.
- Preferences kept outside the database (SharedPreferences). These are
  per-device display preferences, not library data.
- Moment-by-moment edits inside profile samples. The profile editor's revision
  history already covers them; the log records that a revision was made.
- Restoring media file bytes. Dive photos are links only, so a restored media
  row is a restored link.
- Searching old values, or exporting the log.

## Anti-goals

The feature has failed, even if it technically works, if:

- Logging ever blocks or fails a save, or stops the app opening.
- One tap produces a pile of entries, or a sync of untouched rows adds noise.
- A revert carries an old sync clock, so peers refuse it and devices diverge.
- A credential ends up in the log.
- App start becomes noticeably slower.

## Decisions made by the maintainer

| Topic | Decision |
| --- | --- |
| Entry detail | Old and new value per field, with revert |
| Coverage | All user data. Machine data is left out: profile samples, caches, derived metrics, sync bookkeeping |
| Sources | All: manual edits, imports, computer downloads, rules, synced changes and the app's own background jobs. Each labelled; a bulk action is one expandable entry |
| Automatic changes | Visible under an Automatic source, one operation per job, filterable and revertible |
| Undo of an import | Records later data still uses are kept and listed with the reason; everything else is undone |
| Log sync | Each device keeps its own log. It is not a sync table. It is included in that device's backups |
| Revert scope | Field, entry and bulk action; deleted records return with their children; a copy of a deleted dive's profile is kept until the log expires; warns when a value changed since; a revert is logged and syncs as a new edit |
| Retention | 12 months by default, adjustable to 3, 6 or 12 months or forever, plus Clear log |
| Layout | Feed with the first two changed fields inline |
| Detail page | Per-field Revert, Revert all, the changed-since warning, and Undo this import, as in the mockup |
| Location | Settings > Data, plus a History item on record detail pages that opens the log filtered to that record |
| Profiles | The active diver's records and anything shared with them. Deleting a diver deletes their entries |
| On/off | Always on, no switch |
| Delivery | One PR |

## Recording

### Why triggers

There are 582 `markRecordPending` calls across 139 files, and they run after the
row is written, so the old value is already gone. Sync merges, imports and raw
SQL do not all pass through that call. SQLite triggers see `OLD` and `NEW` for
every write without touching any of those call sites.

Measured on a scratch copy of the maintainer's macOS database with Python's
SQLite 3.54.1, without SQLCipher:

| Measure | Without triggers | With 429 triggers |
| --- | --- | --- |
| Open connection and first query | 1.3 ms | 7.8 ms |
| One-field dive update | 0.010 ms | 0.024 ms |

Deleting a dive took 2.7 ms and logged its cascaded children across 16 tables.
Phones and SQLCipher will be slower. The PR measures open time on the real
stack and reports it.

Two behaviours found in that test shape the design:

- `INSERT OR REPLACE` fires no delete trigger by default, so the old row would be
  lost. There are 44 such uses in `lib/`. Set `PRAGMA recursive_triggers = ON` in
  `_beforeOpen`, which every connection runs, including test databases; the
  replace then arrives as a delete and an insert, and settling folds that pair
  into one update.
- Foreign key cascades fire the child tables' delete triggers, so a deleted
  dive's children are captured with no extra work.

### Tables

New file `lib/core/database/tables/change_log_tables.dart`. None has an `hlc`
column and none is registered with sync.

- `change_log_context`: one row. The current source, source label, source device,
  operation id, and a `suppressed_until` time. Both the scope and the suppression
  carry an expiry that the running job renews, because the main database is opened
  from two isolates and a job can be killed part way. A stale value then lapses by
  itself instead of mislabelling or silencing later saves.
- `change_log_events`: one row per changed record: table, record id, action
  (insert, update, delete), time, operation id, settled flag, and the schema
  version it was written under.
- `change_log_fields`: one row per changed column: event id, column, old value,
  new value. Values keep their SQLite type, including blobs.
- `change_log_operations`: one row per thing the diver sees in the feed: source,
  label, device, owner diver, root table and record, display label, time, count,
  reverted-by link.

### Triggers

Generated at runtime from drift's table list and a policy map, never written by
hand:

- **Update:** fires only when a tracked column differs, so a clock stamp or a
  no-op save writes nothing. It inserts one event, then one `change_log_fields`
  row per differing column. Per-column rows avoid SQLite's function argument
  limit, since `diver_settings` has 217 columns and `dives` has 99.
- **Delete:** one event, and one field row per non-null column, so the row can be
  rebuilt.
- **Insert:** one event with no fields. Undoing an insert removes the record.
- Each trigger checks `change_log_context.suppressed_until`.

`ChangeLogPolicy` classifies every table as one of:

- `tracked`: all three triggers.
- `deleteCopyOnly`: delete trigger only, for machine rows a restore needs, such
  as `dive_profile_series` and `tank_pressure_series`.
- `excluded`: no triggers, such as caches, derived metrics and sync bookkeeping.

The policy also lists excluded columns: the bookkeeping set
(`conflictBookkeepingColumns` less `id`) and credentials
(`shared_library` signing keys, `credentials_ref`, `credentials_host_id`,
`instance_token`). A new test fails if any table in `allTables` is unclassified,
mirroring `sync_hlc_target_registration_test`, so a new table cannot be missed
silently.

Tables with no single-column primary key use the same composite id as
`syncRecordId`.

### Trigger lifecycle

Triggers go stale when a migration changes a table, and an old trigger can make
`DROP COLUMN` fail. So:

1. `_onUpgrade` drops every `change_log_*` trigger before the ladder runs.
2. `_beforeOpen` ends by checking a hash of the generated SQL stored in the
   context row, and recreates the triggers on a mismatch. A database arriving by
   restore or adoption is caught the same way. It runs on every open, including
   the Workmanager headless isolate's, so it must not touch suppression.
   Backstops need no suppression: they are idempotent, and update triggers fire
   only on real differences, so one that does change data is logged honestly as
   Automatic.
3. A startup failure to install triggers is logged and the app opens normally,
   without recording.

This goes in a new part file, `before_open_change_log.dart`, because
`before_open.dart` is at the 800-line guard.

### Source and grouping

`ChangeLogScope.run(source, label, body)` writes the context row, runs the body,
and restores the previous context. It wraps the top-level entry points: the
import wizard commit, dive computer download, rule runs, each peer's sync apply,
merges and consolidation, bulk edits and deletes, and data quality repairs.
Background jobs that write tracked tables use source `automatic`, one operation
per job, such as `GalleryOriginBackfill`, the media origin republish and the gear
file conversion. The plan inventories these writers. A write with no scope is
`manual`, so an unwrapped job would be blamed on the diver; the inventory is a
required task, not a best effort.

Full library writes on a device with no library of its own set `suppressed_until`
and record one summary operation: first adoption, restore, replace and join, and
demo mode entry and exit. Otherwise a new device would log its whole library.

An established device also applies a whole base file when a peer's compaction has
lapped it, through `_applyRemoteBaseFile` in the routine pull. That is not
suppressed. It runs as a normal sync operation, since these are real changes and
update triggers skip rows that did not change. The apply must therefore tell first
adoption from a lapped base.

A plain Dart settling step turns raw events into operations. It runs debounced
after writes and when the log opens:

- Events with an operation id join that operation. Manual events on the same root
  record within 5 seconds join one operation.
- A delete and insert of one record in one operation becomes an update.
- It resolves the root record through a parent map in the policy (`dive_tanks` to
  `dives`, for example), the owner diver, and a display label. Labels are stored,
  so an entry still reads properly after its record is deleted.

Settling never runs inside a user's write, so its failures cannot affect saves.
Unsettled events are retried.

A manual save made while a long non-transactional import runs could get that
import's label. The values remain right. The plan wraps long jobs in transactions
where they already exist and accepts this narrow case elsewhere.

## Reading

Pages live in `lib/features/change_log/`.

- **Feed:** `/settings/change-log`, a tile in Settings > Data. Newest first,
  grouped by day, keyset paged, filter chips for record type and source. Shows
  the first two changed fields, as in option B of the mockup.
- **Detail:** `/settings/change-log/:id`, in the three states of the mockup.
- **Record history:** a History item on detail pages opens the feed filtered to
  that root record. The plan lists every page with a detail view.
- **Scope:** operations owned by the active diver, or whose root record is shared
  with them through `site_shares`, `equipment_shares` or `trip_shares`.

Reuse from `lib/features/settings/presentation/conflicts/`: `conflictFieldFor`,
`conflict_field_format.dart`, `ConflictReferenceResolver`, `word_diff.dart` and
`conflict_device_labels.dart`. These give labels, unit-aware values, record names
and device names. Move what the log shares to a neutral location only if the
imports require it. All new strings go through ARB files.

## Revert

Revert follows the existing undo rule from #2705: an undo is a new edit.

- Never restore a logged `hlc`. Write the value, then `markRecordPending` with a
  fresh clock, and stamp any `SyncFactGroup` the column belongs to.
- A clockless child marks the child, never the parent, restamps its own `hlc`,
  and uses `clearChildColumns` when the value is null.
- A restored row is inserted, `removeDeletion` is called, and it is marked
  pending. A restored root row gets `updated_at = now` so peers revive it.
- A pair junction is restored as a row and removed with a tombstone, never
  edited in place.

Behaviour:

- **Changed since:** compare the current value with the entry's new value. On a
  mismatch, show the three-value warning from the mockup.
- **Bulk action:** one transaction, newest change first, parents before children
  on restore. Removing a created dive goes through `bulkDeleteDives`, so media and
  route cascades stay correct.
- **Records in use:** before removing a created record, check every foreign key
  that points at it, because the two kinds fail differently. `dives.site_id` has
  no delete action, so removal would fail and roll back the whole undo.
  `dive_equipment.equipment_id` cascades, so removal would silently strip gear
  from later dives. A record that data outside the operation still uses is kept.
  The result lists what was kept and why.
- **Blocked:** a parent that no longer exists, a column dropped by a later
  migration, or a value from before a migration that rewrote that column. The
  value is still shown and the revert explains why it is unavailable. Rewriting
  rungs are declared in a list next to the ladder, such as the wall-clock shift
  of `dive_date_time`. Packed profile blobs are covered by the same check against
  their codec version.
- **After a revert:** run the same refresh as `refreshAfterRuleWrites` for
  affected dives, so derived metrics, safety reviews and tissue data are
  recomputed, and notify drift watchers.
- **Logging:** a revert is its own operation with source `revert`, linked to what
  it reverted, and the original shows a Reverted badge. A revert can be reverted.
- **Failure:** the transaction rolls back and the diver sees one error message.

## Retention

- Stored per device with the other device preferences, default 12 months.
- Clear log removes the active diver's operations, with a confirmation.
- Pruning runs after startup and at most daily, in small batches off the UI path.
  Expired entries take their fields, including kept dive profiles, with them.
- Deleting a diver and wiping the app remove that data's log entries.
- The Storage usage page gets a Change log line, so the growth is visible.

## Guards and tests

- Unclassified table test, as above.
- A generated test that writes to each tracked table with its triggers installed,
  so a bad trigger is caught before it can fail a user's save.
- Migration test: upgrade with triggers present, including a column drop.
- Round-trip tests: edit, revert and compare; delete a dive and restore with
  children and profile; undo an import, including a record a later dive uses, for
  both a no-action and a cascading foreign key.
- Context tests: a concurrent open leaves suppression and the source alone, and
  an expired scope lapses. A lapped base logs, and first adoption does not.
- Two-device sync test: a revert reaches the peer, for a root row, a clockless
  child, a pair junction and a fact-group column.
- `test/architecture/` and `test/shared/` run after adding files under `lib/`.
- Schema: next free version at branch time (main is 327). Recheck open PRs before
  pushing, since rungs collide.

## Calls made by the designer

These were not decided by the maintainer. Change any of them.

- `recursive_triggers` on for the main database.
- The 5-second window for grouping manual edits.
- Suppression and source context expire by time and are never set during open.
- A lapped base on an established device is logged as a normal sync.
- Each event stores its schema version, and reverts are blocked across migrations
  that declare they rewrote that column. This adds a rule for future rungs that
  rewrite values. Requiring those rungs to rewrite the log too was rejected as a
  permanent cost on every data migration.
- Medical and emergency contact fields are logged like other user data, since the
  log is reachable only by someone already holding the device. Only credentials
  are excluded.
- Bulk undo with edited-since records offers Revert the rest, Revert all or
  Cancel.
- Clear log clears the active diver's entries, not other profiles'.
- The Storage usage line.

## Left to the builder

- How `change_log_fields` declares its untyped columns in drift.
- Exact chip set, and the list of pages that get a History item.
- The debounce interval for settling.
