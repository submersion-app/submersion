# S2 — Batch the Sync Row Writes — Design

**Date:** 2026-06-24
**Status:** Design approved
**Branch/worktree:** `worktree-s2-batch-sync-writes` (off `origin/main`, independent of PR #410 / #412 / #415)
**Parent:** Phase 2 of the app performance investigation (`2026-06-24-app-performance-investigation-design.md`).

## Goal

Reduce the per-row database cost of applying a sync changeset. `_mergeEntity` (`lib/core/services/sync/sync_service.dart`) applies records row-by-row inside the deferred-FK transaction: for each `hasUpdatedAt` record it does one `fetchRecord` (a DB read for the LWW/HLC compare) and, on a win, one `upsertRecord` (one `insertOnConflictUpdate`). Measurement flagged `sqlite3VdbeExec` (these per-row writes) plus per-row map building as a sync hot spot. Collapse the N per-row reads into one batched lookup and the N per-row writes into one Drift `batch()`.

## What is batchable vs pinned per-record

Per record, `_mergeEntity` runs:
- **In-memory** (no DB): id resolution (`_recordIdForEntity`), the pending-edit skip (`pendingRecordIds`), the parent-deletion and local-deletion guards (lookups in the pre-fetched `allTombstones`/`revivedParents` maps), and `SyncClock.instance.receive(remoteHlc)` (in-memory HLC advance).
- **Batchable DB ops**: `fetchRecord` (the LWW read) and `upsertRecord` (the win write) — the hot path.
- **Rare DB ops** (left per-record): `removeDeletion` (revival/self-heal) and `markRecordConflict` (two-sided conflict).

## Design: read-decide-write

Restructure `_mergeEntity` into three phases, behaviour-identical:

1. **Batch-read.** For `hasUpdatedAt` entities, fetch the local rows for the batch's record-ids in one query. New serializer method `Future<Map<String, Map<String, dynamic>>> fetchRecords(String entityType, Iterable<String> ids)` (a single `WHERE id IN (...)` select; batch size ≤500, well under SQLite's IN-clause limit). The clockless (`!hasUpdatedAt`) path needs no read.
2. **Decide in memory.** The loop is unchanged except it reads `localById[recordId]` instead of `await fetchRecord(...)`. It still calls `SyncClock.receive` for every remote HLC, runs every guard, and performs the rare `removeDeletion`/`markRecordConflict` inline. Records that should be written are appended to a `toUpsert` list.
3. **Batch-write.** Apply the winners in one Drift `batch()`. New serializer method `Future<void> upsertRecords(String entityType, List<Map<String, dynamic>> records)` that issues `insertOnConflictUpdate` for each record inside a single `_db.batch(...)`, in list order.

The clockless path appends to `toUpsert` too (a blind win), so all writes for the batch flush once at the end.

## Correctness

- **The decision argument:** every in-loop decision depends only on the pre-fetched local row + the pre-fetched in-memory tombstone/pending maps — never on a write made earlier in the same loop. Deferring all writes to the end therefore cannot change any decision, so the resulting DB is identical.
- **The one assumption: unique ids within a batch.** With a duplicate id, row-by-row would let the first write affect the second record's `fetchRecord`; batching would not. Changesets are one-row-per-id-per-table, so this never occurs. (If defensiveness is wanted, `fetchRecords` + the decision loop can de-dup last-wins, but it is not required for changeset data.)
- **`removeDeletion`/`markRecordConflict` stay per-record and unbatched** — they are rare and touch different tables (`deletion_log`/conflicts), so their ordering vs the deferred upserts does not affect final state.
- **Counts unchanged:** `applied`/`conflicts`/`failed` are tallied exactly as today (a record appended to `toUpsert` counts as applied; a batch-write failure is surfaced — see testing).

## Testing

- **Parity (centerpiece):** the existing `sync_base_streaming_parity_test` (byte-for-byte: streaming/worker apply == in-memory apply) must stay green — it now also exercises the batched merge, proving identical DB + identical counts on a rich library (parent, clockless children, junction, BLOB, updatedAt tables, tombstone).
- **Whole sync suite (335 tests)** stays green — covers LWW conflicts, HLC ordering, revival/self-heal, the #347 junction reinsert, and convergence.
- **Targeted `_mergeEntity` tests** (if a focused harness exists): a two-sided conflict still marks a conflict; an HLC-newer remote wins; a pending local edit is still skipped; a tombstoned-parent child is dropped/null'd — all unchanged under batching.
- **Error handling:** a failure inside the batch write must still increment `failed` (not be masked) — verify the batch path surfaces errors like the per-row path did.
- **Before/after `vmcap.dart`** (optional): fewer `sqlite3VdbeExec` invocations per apply.

## Success criteria

- `_mergeEntity` issues one batched read + one batched write per merge-batch instead of N + N.
- Parity test + full sync suite green; LWW/HLC/conflict semantics and counts unchanged.
- No behaviour change observable to sync (correctness is the gate; throughput is the win).

## Out of scope / follow-ups

- `_applyRemoteDeletions` (the deletions pass) batching.
- `repairDanglingForeignKeys` (post-merge FK-repair) — separate.
- S3 (already shipped: base-apply parse offload), S4 (DB off the UI isolate).
