# Clearing a clockless child column reaches peers

Issue #2644.

## Problem

A device that sets a column on a synced child row back to `null` never passes
the clear to its peers; they keep the old value. Two known cases:

- A re-parse (`ReparseService._carryOverTanks`) clears a tank's
  `transmitter_serial` that the new parse no longer reports.
- A dive split (`DiveSplitService.split`) clears `computer_id` on the original
  dive's tanks.

A peer holding a stale transmitter serial attributes pressure-data gaps to the
wrong transmitter, so transmitter findings differ between devices for the same
dive.

The cause is the apply path. The 25 `parentGatedChildEntities` merge as blind
upserts through `insertOnConflictUpdate(<Row>.fromJson(data))`, and Drift
serializes a data class with `nullToAbsent: true`: a `null` column is left out
of `ON CONFLICT DO UPDATE SET`, so it is never written. That was deliberate
(#474): with no clock on a child, a re-applied copy of the device's own base
could not be told apart from a newer edit, and writing its nulls wiped values
set by direct writes such as the consolidation `computer_id` backfill.

Since #1769 every parent-gated child carries an `hlc`, and the merge already
refuses a remote copy strictly older than the local row. That clock is what
lets a deliberate clear be told apart from a stale or omitted value.

## Goal

- A clear made on one device lands on its peers after one sync, for every
  parent-gated child table.
- Re-applying a device's own base (a tied clock) still never wipes a value.
- A key a peer omits keeps the local value; only an explicit `null` clears.
- No wire-format change and no compatibility-floor bump.

## Decisions

| Topic | Decision |
|---|---|
| Scope | All 25 `parentGatedChildEntities`. Media (`clockGuardedEntities`) is unchanged: it already clears through its fact groups (`writeFactGroup`). |
| Approach | Clock-gated: write a remote's explicit nulls only when its `hlc` is strictly newer than the local row's. Not an explicit clear marker in the payload. |
| Local row with a NULL `hlc` | Counts as older than any stamped remote, so the clear applies. Rows from before v210 have no clock, and requiring both clocks would leave the reported bug in place on those libraries. |
| Remote with no `hlc` (tie or older peer) | Never clears. Today's behaviour. |
| Writers that set a child value without restamping | Fixed in the same change, so no release carries the erase hazard described under "Writers". |
| Undo paths that restore an older `hlc` | Out of scope; filed as a separate issue. |
| Adopt (joining or rejoining a library) | Also lands clears, in replay order, beside the media fact clears (added after the whole-branch review). |
| Nullable columns with a default | Not clearable: a fresh insert fills them, and the gear links' `updated_at` is the age signal the deletion guards read. |

## Design

### 1. The merge rule (`SyncService._mergeEntity`)

In the clockless branch, for an entity in `parentGatedChildEntities`:

- The row is applied exactly as today: it joins `toUpsert` and goes through
  the existing `upsertRecords` arm with `nullToAbsent`. None of the 25 upsert
  arms change, so junction id reconciliation, tag scoping and
  insert-or-ignore behave as before.
- The row is **newer** when the remote `hlc` is present, a local row exists,
  and the local `hlc` is NULL or strictly older than the remote one.
- For a newer row, the cleared keys are those the remote map carries
  explicitly as `null` (`containsKey` and a `null` value) while the local
  value is non-null. They are collected as `clears[recordId] = {jsonKeys}`.
  A key the remote omits is never cleared.
- After the batch upsert succeeds, and inside the same `try`, the merge calls
  `SyncDataSerializer.clearChildColumns(entityType, clears)`. If it throws, the
  failure is rethrown so the payload rolls back and is re-applied next sync,
  the same handling as the media fact writes: the upsert already wrote the
  peer's clock, so counting the batch failed would lose the clear.

**Trade-off.** Children now resolve like the HLC entities already do:
whole-row last-writer-wins. Suppose device A stamps `computer_id` on a tank,
and before the two sync, device B edits the same tank's pressure with a later
clock while its copy still holds `computer_id = null`. Both devices converge
on B's row and A's value is lost. Today the same case diverges instead: A
keeps the value and B never receives it, because A's copy is older. Per-field
clocks would avoid both outcomes and are not part of this change.

### 2. The clear pass (`SyncDataSerializer.clearChildColumns`)

Modelled on `writeFactGroup`:

- Resolves the table through `parentGatedTables` and `_db.allTables`, and the
  key through `_parentGatedKeyColumns`, splitting a composite `a|b` record id
  the same way `_fetchParentGatedChildren` does.
- Maps each JSON key to a column by matching `camelCase(column.$name)` over
  `table.$columns`. Drift's `toJson` keys are the Dart getter names, which are
  the camel-case form of the SQL names for every table; a test pins that.
- Clears only nullable columns. Key columns, NOT NULL columns, `hlc`, and
  unknown keys are skipped, so a malformed or legacy payload can neither fail
  on `SET x = NULL` nor touch a row's key. Column names come from the schema,
  never from the payload, and id values are bound as parameters.
- Issues one `UPDATE <table> SET a = NULL, b = NULL WHERE <key> = ?` per
  cleared row. Clears are rare, so per-row statements stay simple and far
  below the bound-variable limit.
- Known limit, documented at the method: on junctions whose apply keeps the
  lowest id per pair, a remote row whose id lost to a local one has nothing
  to clear and the update matches no row. Those junctions carry no meaningful
  nullable user columns.

The `upsertRecord` doc comment keeps its #474 rule (no `.toCompanion(false)`
on a clockless case) and gains a paragraph naming the clock-gated clear pass
as the one way a clockless `null` lands.

### 2b. Adopt

Adopt replays the library it joins through the same null-dropping upsert,
outside `_mergeEntity`, so a column a later change cleared kept its earlier
value under the clock of the change that cleared it: every later copy of the
row ties, and the merge rule could never repair it. Both adopt paths (the
in-memory reference and the streaming production path) now call
`_landAdoptedChildClears` beside `_landAdoptedFactClears`. Replay order is
the resolution, so it passes every explicit null a row carries.

Every exported row carries explicit nulls, so `clearChildColumns` groups rows
by the columns they clear, sends one `UPDATE ... WHERE <key> IN (...)` per
chunk of ids, and skips rows whose columns are already null. A per-row
statement made a 2,000-row clear take 2,000 statements; it now takes 3.

### 3. Writers

Under the new rule, a writer that sets a child value without restamping the
row can have that value erased by a peer's newer copy that lacks it. Each fix
adds a fresh clock to the same statement, following the event writes already
beside them (`hlc: Value(await _syncRepository.issueRowClock())`). Each flow
already marks the parent dives pending, and the incremental export includes
the children of a pending parent, so stamping is enough to publish; no parent
is re-staged for a child (#1769).

| Writer | Table and column |
|---|---|
| `DiveConsolidationService.apply`, first-consolidation backfill | `dive_tanks.computer_id` |
| `DiveComputerMergeRepository._repointDiveOwnedTables` | `dive_data_sources.computer_id` |
| `DiveComputerMergeRepository._repointDiveOwnedTables` | `dive_tanks.computer_id` |
| `DiveComputerRepositoryImpl._relinkOrphanedRows` (raw SQL) | `dive_data_sources.computer_id` |
| `DiveComputerRepositoryImpl.importProfile`, pressure fill | `dive_tanks.start_pressure`, `end_pressure` |

Writes of NOT NULL columns (`dive_data_sources.is_primary`) cannot be erased
by a null and are left alone.

## Testing

Tests are written first.

- **Clear pass** (`test/core/services/sync/child_column_clear_test.dart`):
  nulls the named nullable columns on a `dive_tanks` row and leaves the rest;
  works on a composite-key table (`dive_equipment`); skips NOT NULL, key,
  `hlc` and unknown keys without throwing. A pin test checks, for all 25
  tables, that a real row's `toJson()` keys equal the camel-case forms of its
  column names.
- **Merge rule**, same file: a strictly newer remote with an explicit null
  clears; a local NULL clock with a stamped remote clears; a tie keeps the
  value; a remote with no clock keeps it; an omitted key keeps it; an older
  remote is skipped.
- **Two devices** (`FakeCloudStorageProvider` and `performSync`): a re-parse
  on A that clears a tank's transmitter serial, and a split on A that clears
  its tanks' `computer_id`, both reach B.
- **Writers**: one test per writer asserting the touched child rows hold a
  fresh, newer `hlc`, each checked red against the unfixed line.
- **Regression**: `consolidation_sync_roundtrip_test.dart`, all of
  `test/core/services/sync` and `test/integration/sync`, then one full-suite
  run before the pull request.
