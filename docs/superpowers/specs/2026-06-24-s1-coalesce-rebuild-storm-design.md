# S1 — Coalesce the Reactive Rebuild Storm — Design

**Date:** 2026-06-24
**Status:** Design approved
**Branch/worktree:** `worktree-s1-debounce-rebuilds` (off `origin/main`, independent of PR #410 / #412 / #415 / #417)
**Parent:** Phase 2 of the app performance investigation.

## Goal

Cut the redundant UI re-queries that sync triggers. The repositories expose `watch*Changes` streams built on Drift `tableUpdates`; ~26 provider subscriptions re-run queries on each tick. A sync that pulls K changesets fires K ticks, so the same providers re-query K times on the main isolate while sync is still writing there. Coalesce the bursts so K ticks become ~2 refreshes, losslessly.

## Evidence (the mechanism, traced)

- **Streams fire post-commit, not per-row.** `watchDivesChanges` = `_db.tableUpdates(onTable(dives))`; `watchDiveDetailChanges` = `tableUpdates(allOf([...22 tables...]))` (`dive_repository_impl.dart:50,70`). Drift delivers these once per transaction COMMIT. So a base apply (thousands of rows, one transaction) already fires only once.
- **The burst is per-changeset.** `changeset_reader.dart:63` loops `for (final peerId in peerIds)` and applies one `applyInDeferredFkTransaction` per changeset (`_applyRemotePayload` per changeset). K changesets → K commits → **K ticks**. A caught-up device: K≈1; a device back from offline / a busy multi-device library: K is tens.
- **Fan-out.** ~26 subscription references across ~10 provider files; `watchDiveDetailChanges` feeds ~14 per-dive detail/section providers that re-hydrate a dive (tanks, pressures, profile, equipment) on each tick.
- **Cost.** Those re-queries run on the main-isolate synchronous `NativeDatabase` — the same thread sync is writing on — so K × fan-out re-queries interleave with sync's writes and contend for the one DB thread.
- **No coalescing exists** (no `distinct`/throttle/debounce anywhere on these streams).
- **The ticks are `void`.** They carry no payload, so collapsing N ticks into 1 is lossless: a subscriber re-queries current DB state regardless of how many ticks it missed.

## Design: a shared leading+trailing coalescer

Add one small, tested stream transformer and apply it at the shared `watch*Changes` source:

- **`Stream<void> coalesce(Duration window)`** (a `StreamTransformer`/extension): emits the first tick **immediately** (leading), then suppresses further ticks for `window` and emits exactly **one** trailing tick after the burst goes quiet.
  - Single local edit → 1 immediate tick (no added latency).
  - Burst of K commits → **2 ticks** (leading at the start, one trailing at the end), regardless of K.
- **Window:** ~200 ms — longer than the gap between back-to-back changeset commits (so a sync burst keeps resetting the trailing timer and fires once at the end), short enough to be imperceptible for an isolated edit.
- **Where:** wrap the returned stream in each `watch*Changes` method (the shared source), so every subscriber benefits and there is exactly one place to reason about. The high-fan-out `watchDivesChanges` and `watchDiveDetailChanges` are the priority; apply uniformly to all `watch*Changes` for consistency.

## Why leading+trailing (not plain debounce or throttle)

- **Trailing-only debounce** delays every single edit's refresh by `window` (~200 ms — borderline noticeable).
- **Throttle** re-emits every `window` during a long sync (~K/window refreshes) — better than K, but still many.
- **Leading+trailing** gives an isolated edit a zero-latency refresh and a burst exactly 2 refreshes (start + end) no matter its length — the best of both.

## Correctness / safety

- **Lossless.** Ticks are `void`; subscribers always re-query current DB, so coalescing changes only *when* a refresh happens, never *what* it shows.
- **The trailing tick is mandatory.** It guarantees the end state is always reflected — the coalescer must never drop the final tick of a burst.
- **No change** to sync semantics, to the providers, or to the 2026-06-15 reactive-after-sync wiring — only the timing of the shared streams.

## Testing

- **Transformer unit tests** (fake-async / `fakeAsync`):
  - single tick → emits once, immediately.
  - burst of N ticks within `window` → emits exactly 2 (leading + one trailing).
  - the trailing emit always fires after the last tick (final never dropped).
  - ticks spaced > `window` apart → each emits (not over-coalesced).
  - source closes mid-window → a pending trailing tick is still delivered before done.
- **Repository test:** a rapid burst on `watchDivesChanges` collapses to 2 emits under `fakeAsync`.
- **Full suite green** — subscribers behave identically; they just fire fewer times.

## Success criteria

- A K-changeset sync produces ~2 detail/list refreshes instead of K.
- Single local edits refresh with no added latency.
- No staleness (final state always reflected); suite green.

## Out of scope / follow-ups

- S4 (DB off the UI isolate) — removes the contention this mitigates.
- Reducing K (applying changesets in fewer transactions) — separate and riskier (per-changeset cursor advance + error isolation).
- D2 (lazy below-the-fold), D1b (chart decimation).
