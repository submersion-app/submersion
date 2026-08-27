# Incremental Sync — Phase 6: Restore + Coexistence (and performSync wiring) Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans. Steps use checkbox (`- [ ]`) syntax.
>
> **READ THIS FIRST — verification posture.** Unlike Phases 1–5 (self-contained units, fully covered by fake-provider unit tests), this phase modifies **live, shipped** sync orchestration and the restore/epoch/twin machinery hardened across v77–v83. Fake-provider unit tests are necessary but **not sufficient** here: restore, library-epoch replace, twin-split, and iCloud ubiquity behavior require **real multi-device hardware verification** (see memory: `project_icloud_sync_needs_real_devices`, `project_restore_breaks_sync`, `project_instance_token_stranding_v83`). Execute this phase in a focused session and gate completion on device testing, not just `flutter test`.

**Goal:** Turn the tested transport (Phases 1–5) into live multi-device sync: wire `ChangesetWriter`+`ChangesetReader` into `performSync`, make stale-restore recover by authoritative rebuild, and confirm coexistence with library-epoch/replace, backend switching, and twin/clone detection.

**Phase roadmap:** 1–5 ✅ → **6 (restore + coexistence + wiring) ← this plan** (final).

---

### Task 1: Stale-restore detection (backstop to `instanceToken`)

**Design — detection signal.** The **primary** restore detector stays the existing `SyncInitializer.reconcileDeviceIdentity` (`sync_initializer.dart:101`): it compares the in-DB `instanceToken` to a SharedPreferences mirror a DB restore can't rewind. It is **edit-robust** (fires on the launch after a restore regardless of later edits) and already calls `rebaselineAfterRestore`. The changeset-log addition is a **backstop** for that detector's documented blind spot (a restore predating the anchors — today's "manual Reset Sync State"): at sync time, re-read the device's own cloud manifest and flag stale if

```
localHlcHigh < cloudManifest.publishedHlcHigh
```

Caveat to document in code: this backstop is masked by a post-restore edit (the edit lifts `localHlcHigh` above the watermark); that case is covered by the primary `instanceToken` detector. So the backstop only needs to catch the no-edit-yet pre-anchor restore.

**Files:** Create `lib/core/services/sync/changeset_log/stale_restore_detector.dart`; expose `SyncRepository.maxRowHlc()` (public wrapper over the existing private `_maxRowHlc()`); test `test/core/services/sync/changeset_log/stale_restore_detector_test.dart`.

- [ ] **Step 1 (test):** publish as the device (sets `cloudManifest.publishedHlcHigh`); assert `isStaleRestore() == false`. Then delete the most-recent local HLC-bearing rows so `maxRowHlc()` drops below the published watermark (simulating a restore to an earlier state); assert `isStaleRestore() == true`. Then with no published manifest, assert `false`.
- [ ] **Step 2:** run → FAIL.
- [ ] **Step 3:** add `Future<String?> maxRowHlc()` to `SyncRepository` (return `await _maxRowHlc()`); implement `StaleRestoreDetector.isStaleRestore({provider, deviceId, folderId})` = read own manifest (list `prefix`, find `manifestName(deviceId)`, parse) → if `publishedHlcHigh == null` return false → compare `(await repo.maxRowHlc())` vs it with HLC string comparison (`null` local treated as below any non-null cloud watermark).
- [ ] **Step 4:** run → PASS. **Step 5:** analyze, format, commit `feat(sync): add stale-restore detector (HLC-vs-cloud-manifest backstop)`.

---

### Task 2: Authoritative restore rebuild (`RestoreReconciler`)

**Design (spec §8b).** On a confirmed stale restore, recovery does NOT merge the restored data — it rebuilds from the current authoritative library and discards stale local rows, preserving genuine post-restore edits:
1. **Quarantine** local rows with `hlc > cloudManifest.publishedHlcHigh` (true post-restore edits).
2. **Reset** `sync_peer_cursors` + `local_publish_states` for the provider (so the next sync cold-starts every peer and republishes a base) — reuse `PeerCursorStore.resetForProvider` / `PublishStateStore.resetForProvider`, alongside the existing `rebaselineAfterRestore`.
3. **Rebuild**: pull every peer's base+changesets (the Phase 4 reader, cold-start) AND re-adopt the device's own published base from its cloud namespace, through the real merge — yielding the converged current library (deleted rows absent, per §12's "published deletions live in the changeset log until compaction").
4. **Re-apply** the quarantined edits on top; they publish forward with fresh HLCs.

**Why no tombstone-window dependence:** rebuilding from the authoritative published state inherently excludes deleted rows; the 90-day local prune only governs how changesets are *built*.

- [ ] Implement `RestoreReconciler.reconcile({provider, deviceId, folderId, reader, apply})` and test against the fake provider with an injected real-ish apply: seed+publish, simulate restore (rewind local rows + reset publish state), reconcile, assert the device re-converges to the published state and a since-deleted row does NOT resurrect. **Gate:** also exercises with a backup older than the 90-day window (must still not resurrect).

> This task is unit-testable against the fake provider, but its *trigger* is wired in Task 4; verify the composed behavior on device.

---

### Task 3: Coexistence (epoch/replace, backend switch, twin) — mostly composition

Most coexistence is already structural; this task confirms and fills gaps:
- **Library epoch / replace:** writer/reader already thread `epochId` through the manifest. On a newer epoch than `lastAcceptedEpochId`, reset the peer cursor for that device and adopt its new base (Case-C). Confirm the existing adopt-vs-merge/moved-marker logic still gates this. **Device-verify** the "replace everywhere" flow.
- **Backend switch:** `sync_peer_cursors` and `local_publish_states` are already `provider`-keyed → a new backend cold-starts and republishes a base automatically. Confirm the existing "clean up old backend" step deletes the device's `ssv1.<deviceId>.*` files on the old provider.
- **Twin/clone:** the manifest carries `uploadNonce`; reuse `isForeignUploadNonce` → `adoptFreshIdentity` (new `<deviceId>` namespace, republish base). Confirm a clone splits and both converge.

- [ ] Unit-test what's deterministic (per-provider cursor isolation already covered; add an epoch-bump cursor-reset test). **Device-verify** epoch/replace, backend switch, twin.

---

### Task 4: Wire writer+reader into `SyncService.performSync` (LIVE)

Replace the legacy full-file upload/download in `performSync` (the `exportData(...)` upload at ~`sync_service.dart:514` and the list+download+merge loop at ~`374–505`) with:
- **Upload phase:** `ChangesetWriter.publish(provider, deviceId, folderId, deletions, epochId, uploadNonce)`.
- **Download phase:** `ChangesetReader.pull(provider, selfDeviceId: deviceId, folderId, apply: _applyRemotePayload)` — passing the existing merge as `apply` (wrap each payload in `applyInDeferredFkTransaction`, as `_applyRemotePayload` already does).
- **Restore hook:** before publishing, run Task 1 detection; on stale → Task 2 reconcile.
- Keep: twin check, epoch filtering, deletion logging, the per-provider cursor stamping (now via the new stores), progress reporting.
- Remove/retire: `_deviceSyncFileName` full-file path and the legacy shared-file retirement (no released users on the old format — memory `project_incremental_sync_design`).

- [ ] Update the existing sync integration tests to the changeset-log format. Many assertions about `submersion_sync_<id>.json` must move to the `ssv1.*` layout. Expect a substantial test-migration here.

> **DO NOT mark Phase 6 / the feature complete on green unit tests alone.** Required before merge:
> - [ ] Two real devices (ideally one Apple + one non-Apple over S3/R2) converge: add dives on each, confirm both sides receive only deltas.
> - [ ] Restore an older DB backup on one device; confirm automatic recovery (no manual Reset Sync State) and no resurrected deletes.
> - [ ] Backend switch (e.g. iCloud → S3) cold-starts cleanly.
> - [ ] Library "replace everywhere" propagates.

---

### Phase 6 wrap-up

After device verification, use `superpowers:finishing-a-development-branch` to merge/PR `feat/incremental-sync`. Update the spec's §4 to the flat `ssv1.*` layout (the implemented form) and the README/multi-device-sync guide to describe incremental sync.
