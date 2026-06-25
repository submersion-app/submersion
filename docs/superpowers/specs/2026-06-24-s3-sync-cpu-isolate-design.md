# S3 — Offload the Sync Base-Apply CPU to a Worker Isolate — Design

**Date:** 2026-06-24
**Status:** Design approved
**Branch/worktree:** `worktree-s3-sync-cpu-isolate` (off `origin/main`, independent of PR #410 / #412)
**Parent:** Phase 2 of the app performance investigation (`2026-06-24-app-performance-investigation-design.md`, findings in `2026-06-24-app-performance-findings.md`)

## Goal

Stop background sync from stuttering the UI. Measurement (Phase 1 + the D1a re-measure) showed the on-launch / on-resume sync runs a base-file apply **entirely on the main/UI isolate** — `pread` (file read) ~448 ms, SHA-256 ~217 ms, `BaseJsonStreamReader` parse ~324 ms, plus ~245 ms of DB writes — dominating the cold start and firing on every window focus. Move the pure-CPU work (read + parse; the whole-file checksum fold-in is a deferred follow-up, see Implementation status) to a worker isolate so the main isolate is free to render; only the irreducible DB writes stay on main.

## The hard constraint

The DB writes cannot leave the main isolate. The merge (`_mergeEntity`, `sync_service.dart`) reads the current local row per record (`fetchRecord`) to make the LWW/HLC decision, then upserts — all on the deliberately **synchronous main-isolate `NativeDatabase`** (`database_service.dart:98`), inside one transaction. So "offload sync" means offloading the *parse/read* (and, as a follow-up, the *checksum*), never the writes or the merge.

## What is offloadable vs pinned (from the pipeline map)

- **Offloadable (pure CPU, no DB):** the base file `pread`, the whole-file SHA-256, the `BaseJsonStreamReader` byte-FSM, and per-row `jsonDecode`. The data crossing the boundary is plain (`Map<String,dynamic>` rows, `Map` deletions/parent-updatedAt) — fully sendable.
- **Pinned to main (DB):** `_mergeEntity` (per-record `fetchRecord` + `upsertRecord` + `SyncClock.receive` + conflict writes), `_applyRemoteDeletions`, `repairDanglingForeignKeys`, the `applyInDeferredFkTransaction` transaction.

## Scope

- **In scope:** `_applyRemoteBaseFile` (`sync_service.dart`) — the base apply, the measured hot spot. Always large, so always worth the isolate.
- **Deferred (YAGNI):** the **delta path** (`_applyRemotePayload`). Deltas are usually tiny; `compute()`'s isolate-spawn overhead would exceed the decode cost. Only rare large catch-up deltas would benefit — a future follow-up, not S3.
- **Out of scope:** moving the DB off the main isolate (S4 root-cause lever), and the open-transaction-blocks-reads issue (S4/S1) — both separate.

## Architecture: a per-base-apply parsing worker, pull-based

When a base apply starts, the main isolate spawns a worker, handing it the base file **path** (the file read moves into the worker, per the EXIF/media `compute(fn, path)` precedent) and the manifest checksums. The worker owns all the pure CPU. The main isolate drives a tiny request/response port protocol:

- `pass1` → worker returns `{exportedAt, deletions}` (small — whole message)
- `pass2` → worker returns `{parentUpdatedAt, contradictedByEntity}` (small — whole message)
- `nextDataBatch` (repeated) → worker returns the next ≤500 decoded row-maps, until `done`

The main isolate's apply logic is **unchanged except its data source**: instead of `file.openRead()` + inline `jsonDecode`, it pulls already-decoded `Map<String,dynamic>` rows from the worker. `_mergeEntity`, the deferred-FK transaction, `_applyRemoteDeletions`, and `repairDanglingForeignKeys` stay on the main isolate.

**Memory bound (#358) preserved by construction:** pull-based = backpressure. The worker parses the next batch only when the main isolate (bottlenecked on DB writes) asks — at most one batch in flight.

## Components

1. **Worker entrypoint** (top-level function, the isolate body): owns a `RandomAccessFile`/`openRead` and a `BaseJsonStreamReader` instance (the whole-file SHA-256 fold-in is deferred — it still runs in `BasePartFileSink.assemble` on main); serves `pass1`/`pass2`/`nextDataBatch`/`dispose` over a `SendPort`.
2. **`BaseParseClient`** (main-side): wraps the `Isolate.spawn` handshake + port protocol behind a clean async API (`pass1()`, `pass2()`, `nextDataBatch()`, `dispose()`). `_applyRemoteBaseFile` talks only to the client, never raw ports.
3. **`BaseJsonStreamReader` adaptation:** the existing byte-FSM, driven on-demand — it consumes the file via a pausable `StreamSubscription`, accumulates rows into the current batch, and **pauses when the batch hits 500**; the next `nextDataBatch` resumes it. The FSM and `jsonDecode` are unchanged.
4. **Checksum fold-in (deferred — not in this PR):** the design folds the whole-file SHA-256 validation into the worker's first read (moving ~217 ms off main); as shipped, that hashing still runs in `BasePartFileSink.assemble` on the main isolate, and `assemble`'s per-part download checks stay. See Implementation status.

**Mechanism note:** deliberately a long-lived `Isolate.spawn` worker with bidirectional `SendPort`s, **not** `compute()` (one-shot, can't stream). This is the one new isolate pattern for the codebase and where the novelty/risk concentrates.

**Honest cost:** each 500-row batch is deep-copied across the isolate boundary (Dart isolates don't share memory). Cheaper than the main isolate re-parsing the bytes, bounded by the batch — the price of parallelism, justified because parse+hash+IO (~990 ms) dwarfs the copy of decoded maps.

## Correctness

- **Parity is the centerpiece.** Only the *source* of parsed rows changes; the merge/transaction/FK logic is untouched, so semantics are identical **provided the worker emits rows in exact file order, batched per-table identically** (so `mergeOrder` / parents-before-children is preserved). The **parity test** is the proof: apply a representative base file both ways (inline vs worker-fed) to two fresh DBs and assert **row-identical** final state (mirrors the #358 parity test).
- **The worker is a pure optimization that cannot break sync — via fallback.** The current inline `_applyRemoteBaseFile` stays as the fallback. The worker is tried first; on *any* failure — spawn error, parse error, checksum mismatch, crash/OOM, timeout — the main isolate aborts the (auto-rolled-back) transaction and **retries inline**. A broken isolate degrades to old behaviour, never to data loss or a failed sync.
- **Error flow:** parse error / checksum mismatch → worker sends an error message → main aborts → fallback. Worker crash → `onExit`/`onError` port fires → main detects → fallback. Worker disposed in a `finally`.
- **Lifecycle:** `pass1`/`pass2` run before the transaction; `nextDataBatch` streams *inside* it (each pull is an `await`; Drift transactions are async-aware and auto-roll-back on throw).

## Testing

- **Parity test** (critical): inline vs worker-fed apply → identical DB state, on a representative multi-table base with deletions + parent/child rows.
- **Fallback tests:** injected parse error / checksum mismatch / simulated worker death → main aborts cleanly, falls back to inline, sync still succeeds.
- **`BaseParseClient` protocol tests** + the pausable-reader adaptation (batch boundaries; backpressure = at most one batch in flight).
- **Before/after `vmcap.dart` measurement:** confirm `pread`/parse are gone from the main isolate during a base apply (SHA-256 stays until the deferred checksum fold-in lands); frames smooth.

## Success criteria

- A base apply runs `pread` + parse on the worker isolate (the whole-file SHA-256 remains on main as a deferred follow-up); only DB writes remain on main (measured before/after).
- Parity test green — worker-fed apply is row-identical to inline.
- Any worker failure falls back to inline; sync never fails or loses data because of the isolate.
- Memory stays bounded (at most one batch in flight) — #358 preserved.
- Test suite green; sync correctness (LWW/HLC/parity) unchanged.

## Out of scope / follow-ups

- Delta-path `compute()` offload (only large catch-up deltas benefit).
- S4 (DB off the UI isolate) — fixes the open-transaction-blocks-reads issue this does not.
- Reusing one persistent worker across syncs (this spec spawns per base apply for simplicity).

## Implementation status (2026-06-24)

Built and parity-proven. The base-apply parse (`BaseJsonStreamReader` + per-row `jsonDecode`) and file read now run in an `Isolate.spawn`'d worker (`base_parse_worker.dart` / `base_parse_client.dart`), pull-backpressured one ≤500-row batch at a time; the merge/writes/transaction stay on the main isolate (`_applyRemoteBaseFileViaWorker`), with `_applyRemoteBaseFileInline` retained as the fallback.

- The existing `streaming base apply matches in-memory apply byte-for-byte` parity test now runs **through the worker** and is green; a forced-spawn-failure test proves the inline fallback; the whole sync suite (335 tests) passes.
- **The offload is structural** — the parse runs in a spawned isolate by construction — so no live before/after was captured (a base apply is occasional and hard to trigger reliably).

### Deferred follow-ups
1. Fold the whole-file SHA-256 (currently in `BasePartFileSink.assemble`, ~217 ms on main) into the worker's read.
2. The delta-path `compute()` decode offload.
3. A persistent worker reused across syncs (avoids per-apply spawn cost).
