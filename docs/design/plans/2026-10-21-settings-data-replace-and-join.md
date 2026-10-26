# Settings > Data, PR 5: Replace and join Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A device that already holds dives can replace its library with the one in its sync account, as a service with its own tests and recovery, not yet reachable from the UI. Phase 6 wires it into step 2 of Set up this device.

**Architecture:**
- The engine reuses the cloud-wins path the sync engine already has for a retired device (`SyncService._rejoinAfterRetirement`): collect the account's library bases, then apply them to the live database in one deferred-FK transaction that upserts every library row and deletes every local synced row the library lacks. It lives in a new part file, `sync_service_replace_join.dart`, as an extension on `SyncService`, so it reaches the private collectors and apply without growing the 5,768-line service.
- Everything the replace changes in the database happens in that one transaction: the apply, the device's own roster rows put back, the sync-state reset, the peer cursors and the adopted-base watermark. A crash or error before it commits leaves the database exactly as it was, by SQLite's own rollback.
- An orchestrator, `ReplaceAndJoinService`, runs the steps around the engine in the spec's order and makes each non-database side effect either reversible (the media attachment is snapshotted and put back on failure) or done only after the commit (the upload queue, established-provider and epoch prefs, the active diver).
- `replaceAndJoinServiceProvider` (its own file, since the sync providers may not import the backup providers) builds the orchestrator; `ReplaceAndJoinService.run(backupNote:)` runs it under the one-at-a-time `SyncCoordinator` and returns a typed outcome. There is no `SyncNotifier.replaceAndJoin`. Phase 6 adds the typed-word dialog, the full-screen page and the reload.

**Tech Stack:** Flutter, Riverpod 3, Drift, the changeset-log sync engine (`SyncService`, `SyncDataSerializer.applyInDeferredFkTransaction`, `PeerCursorStore`, publish-state store, `LibraryEpochStore`), `BackupService`, `MediaStoreAttachState`, `MediaTransferQueueRepository`, `flutter_test` with the fake cloud provider in `test/helpers/sync_test_helpers.dart`.

**Spec:** `docs/design/specs/2026-10-17-settings-data-setup-and-accounts-design.md`, sections 6.4 (step 2) and 6.4.1, 10, 11 (phase 5), 12. Phases 1-4 shipped as #3485, #3500, #3527, #3541 and #3547.

## Global Constraints

- **No schema change and no sync-format change.** No migration rung; the manifest gains no field (spec non-goal: replace and join is a device-side operation layered on the existing pull).
- **The device keeps its sync identity.** `sync_metadata.device_id` is never regenerated.
- **Kept across a replace (spec 6.4.1 step 4):** the device's connected accounts and their credentials, the chosen sync account (`sync_metadata.sync_account_id`, `sync_last_provider`), App Lock, and database encryption. None of them is written by the replace.
- **Never through `disableForDatabaseReset` or `signOut`:** both remove `sync_last_provider` and the sync account.
- **The set-aside backup is an ordinary History entry, pinned,** with the caller's note. Retention never removes it.
- **Runs under `SyncCoordinator.run`,** so no sync or merge runs during it.
- **Files stay under 800 lines;** no new file over 400. `sync_service.dart` gains no more than the `part` directive.
- **No em dashes, and no tool names or attribution.** Every commit and the PR say `Refs #3482`.
- **Tests restore any global state they replace** (`DatabaseService.instance`, providers, prefs). After adding files under `lib/`, run `test/architecture` and `test/shared`; run `test/core/services/sync` after touching the engine.

## Rulings and deferrals

Calls the plan makes where the spec leaves a choice or the code forces one. Each is cheap to reverse.

1. **One transaction instead of Reset's file delete plus the restore journal.** The spec asks for the Reset Database data path and for failures after step 4 to recover through the restore journal. Reset deletes the database files with no journal, and the restore journal guards a file swap. The sync engine's apply already replaces the library inside one transaction, so a failure at any point rolls back to the untouched library and no recovery screen is needed. This keeps the spec's promise (a failure never loses the device's dives) with less machinery. If you prefer the literal file swap, it is a contained change to Task 3.
2. **The device's own roster rows survive.** The library's `connected_accounts` table is synced, so a plain apply would delete this device's accounts that the library has not seen yet. They are put back inside the same transaction and marked pending, so they join the library's roster on the next sync. Credentials are keyed by row id in the keychain and are never touched.
3. **This device's own log is part of the library** (changed in the final review). Dives it published before are already its peers'; leaving its log out would drop them on this device alone and split the fleet. Retired devices' lingering logs are left out, as pull and the retirement fence leave them out.
4. **The library must be readable before anything changes.** No library, a newer-schema peer, or a locked encrypted library returns an outcome (`noLibrary`, `newerSchema`, `needsPassphrase`) before the backup is taken.
5. **The backup note is a parameter.** The service has no `BuildContext`; phase 6 passes the localized "Before joining the library, {date}" string. No ARB change in this PR.
6. **Dialog, progress page and reload are phase 6.** Spec phasing makes PR 5 a service "not yet reachable from the UI". The notifier returns the outcome; the caller reloads with `restartApp()` as Reset and Restore do.
7. **The upload queue is cleared only after the commit.** Its rows name the replaced library's media; clearing them earlier would lose a pending upload if the replace then failed. The media attachment is detached before the apply (so no drain runs against a library mid-replace) and put back from its snapshot if the replace fails.
8. **The epoch is always written, null included,** inside the transaction, and a pending replace is cleared after it (final review): an epoch this device accepted in another library would otherwise be written back into this one, and a peer would re-establish the account from its local library.
9. **The kept accounts are stamped after the clock reseeds from the library,** inside the transaction (final review), so they sort above the adopted watermark and publish even when the library's clocks ran ahead.
10. **This account's last sync time is written inside the transaction** (final review). It is what the Combine gate reads, so the gate stays quiet even if the later established mark is lost.
11. **Nothing after the commit reports a failure.** The engine's prefs mirrors and the orchestrator's later steps are each attempted and logged; only a failure before the commit puts the photo store back and is rethrown.
12. **A marker whose epoch has no readable base is `stillUploading`,** not `noLibrary`, as adopt waits it out.

## Review Focus

1. **A failure in the middle of the apply** (an exception thrown by the apply or by a roster write) leaves dives, divers, the roster, sync bookkeeping and the media attachment exactly as before (Task 3).
2. **A locked encrypted library** returns `needsPassphrase` with no backup taken and nothing changed; after unlocking, the same call succeeds (Task 3).
3. **A peer published from a newer schema** returns `newerSchema` and changes nothing (Task 2).
4. **The next sync after a replace** pulls nothing it already has, publishes the device's kept roster rows, never publishes the replaced dives, and never raises the Combine gate (Task 4).
5. **A library this device published before** (its own manifest in the account) does not resurrect the replaced dives (Task 2).

---

### Task 1: Reversible media detach and a queue clear

**Files:**
- Modify: `lib/core/services/media_store/media_store_attach_state.dart`
- Modify: `lib/features/media_store/data/media_transfer_queue_repository.dart`
- Test: `test/core/services/media_store/media_store_attach_state_snapshot_test.dart`, `test/features/media_store/media_transfer_queue_clear_all_test.dart`

**Interfaces:**
- Produces: `Future<MediaStoreAttachSnapshot> MediaStoreAttachState.snapshot()` and `Future<void> MediaStoreAttachState.restore(MediaStoreAttachSnapshot)`; `Future<int> MediaTransferQueueRepository.clearAll()` (deletes every row, returns the count).

- [ ] **Step 1:** Tests: a snapshot of an attached state, then `clear()`, then `restore` reads back the same store id, provider type, account id and marker-mismatch flag, and bumps the attach generation (so a runtime built before is superseded). A snapshot of a detached state restores to detached. `clearAll` on a queue holding pending, transferring, failed and done rows of both directions leaves it empty and returns 4.
- [ ] **Step 2:** Run them; expect compile failures for the missing members.
- [ ] **Step 3:** Implement. The snapshot is an immutable record of the five prefs keys; `restore` writes them through the same setters `setAttached` uses (or `clear()` for a detached snapshot).
- [ ] **Step 4:** Run; expect PASS. Commit `feat(media-store): reversible detach and a queue clear` with `Refs #3482`.

### Task 2: The engine

**Files:**
- Create: `lib/core/services/sync/sync_service_replace_join.dart` (`part of 'sync_service.dart'`)
- Modify: `lib/core/services/sync/sync_service.dart` (the `part` directive only)
- Test: `test/core/services/sync/sync_service_replace_join_test.dart`

**Interfaces:**
- Produces: `enum ReplaceJoinOutcome { replaced, noLibrary, newerSchema, needsPassphrase }`; `ReplaceJoinResult` (the outcome plus `newerSchemaPeerNames`); and two calls, so the caller can take its backup between proving the library readable and changing anything:
  - `Future<({ReplaceJoinPrepared? prepared, ReplaceJoinResult? refused})> prepareReplaceJoin()`: downloads and classifies the account's library, changes nothing local. `prepared` holds the collected bases (temp files), cursors and epoch id; `refused` carries `noLibrary`, `newerSchema` or `needsPassphrase`. `ReplaceJoinPrepared.dispose()` deletes its temp files.
  - `Future<ReplaceJoinResult> applyReplaceJoin(ReplaceJoinPrepared prepared, {void Function()? afterApplyForTest})`: the transaction and the after-commit steps; always disposes `prepared`.

- [ ] **Step 1:** Tests, with two devices on the fake provider (`sync_test_helpers.dart`). Device A publishes a library (two dives, a diver, one roster row). Device B holds its own dives and a roster row A has not seen.
  - `replaced`: B's local dives equal A's; B's own dives are gone; B's roster holds both rows; B's `device_id` and `sync_account_id` are unchanged.
  - B has no pending records except its kept roster row; its peer cursors point at A's applied sequence; the adopted watermark is set.
  - An account with no library returns `noLibrary` and changes nothing.
  - A peer published from a newer schema returns `newerSchema` with its name and changes nothing.
  - B's own earlier manifest in the account (B synced once before) is excluded: none of B's replaced dives come back.
  - An encrypted library with no key returns `needsPassphrase` and changes nothing.
  - `afterApplyForTest` throwing inside the transaction leaves B's dives, roster and sync bookkeeping as before.
- [ ] **Step 2:** Run; expect failures for the missing extension.
- [ ] **Step 3:** Implement, mirroring `_rejoinAfterRetirement` without its pending replay:
  1. `prepareReplaceJoin`: resolve provider, folder and this device's id; read the cloud epoch marker if any (`SyncEncryptionRequired` maps to `needsPassphrase`); `_collectEpochBaseSources(provider, folderId, epochId, excludeDeviceIds: {deviceId})`. A newer-schema peer or no base files is a `refused` result, with the temp files deleted.
  2. `applyReplaceJoin`: snapshot this device's `connected_accounts` rows.
  3. One `applyInDeferredFkTransaction`: `_adoptApplyStreaming`, put back roster rows the library lacks, `resetSyncState(clearDeletionLog: true)`, upsert the collected cursors, `markAdoptedPendingBase(maxRowHlc)`, then the test hook.
  4. After commit: mark the put-back roster rows pending, store the accepted epoch, `SyncClock.instance.reset()`, delete the collected base temp files, `_flushAfterRun`.
  If drift refuses one of these writes inside the outer transaction, the ruling is to keep the apply and roster in the transaction and run the bookkeeping writes right after it in a second transaction, ledgered.
- [ ] **Step 4:** Run the task's tests and `test/core/services/sync`; expect PASS. Commit `feat(sync): replace this device's library with the account's` with `Refs #3482`.

### Task 3: The orchestrator

**Files:**
- Create: `lib/core/services/sync/replace_and_join_service.dart`
- Create: `lib/features/settings/presentation/providers/replace_and_join_providers.dart` (`ProductionReplaceJoinSteps` and `replaceAndJoinServiceProvider`)
- Test: `test/core/services/sync/replace_and_join_service_test.dart`

**Interfaces:**
- Consumes: Task 1's snapshot/restore and `clearAll`; Task 2's `prepareReplaceJoin` and `applyReplaceJoin`; `BackupService.performBackup(note:)` and `pinBackup(id)`; `MediaStoreService.disconnect()`; `EstablishedProviderStore`; `realignActiveDiverAfterDataReplace(prefs)`.
- Produces: `ReplaceAndJoinService.run({required String backupNote}) → Future<ReplaceJoinResult>`, read through `replaceAndJoinServiceProvider`.

- [ ] **Step 1:** Tests with fakes for backup, media and the engine:
  - Order on success: prepare, pinned backup with the note, snapshot and detach, apply, then queue cleared, provider marked established, post-restore flag cleared, active diver realigned.
  - The backup is pinned and carries the note; retention set to 1 then pruning keeps it.
  - Prepare refuses (`noLibrary` / `newerSchema` / `needsPassphrase`): no backup taken, media still attached, queue untouched.
  - The backup fails: the prepared bases are disposed, nothing else changed, the error propagates.
  - Apply throws after the detach: the attachment is restored from its snapshot, the queue is untouched, the backup stays in History, the error propagates.
  - The notifier runs it under the coordinator (a sync requested meanwhile waits).
- [ ] **Step 2:** Run; expect failures.
- [ ] **Step 3:** Implement: prepare (return a refusal as is), pinned backup, snapshot and detach, apply, then the after-commit prefs. A failure after the detach restores the snapshot and rethrows; `prepared` is disposed on every path.
- [ ] **Step 4:** Run; expect PASS. Commit `feat(sync): replace and join as one service` with `Refs #3482`.

### Task 4: After a replace, sync carries on

**Files:**
- Test: `test/core/services/sync/replace_and_join_followup_sync_test.dart`

- [ ] **Step 1:** Two devices on the fake provider. B replaces and joins A's library, then syncs; A syncs.
  - B's sync downloads nothing new and publishes only its kept roster row.
  - A ends with its own dives plus B's roster row, and none of B's replaced dives.
  - `firstSyncMergeInfo()` on B returns null afterwards.
  - B adds a dive after the replace; A receives it on its next sync.
- [ ] **Step 2:** Run; fix any engine gap it shows under TDD in Task 2's file. Commit with the task that needed the fix, or `test(sync): replace and join hands over to normal sync` with `Refs #3482` when nothing changed.

## Done when

- `dart format .`, `flutter analyze`, `test/core/services/sync`, `test/core/services/media_store`, `test/features/media_store`, `test/features/settings`, `test/architecture` and `test/shared` pass.
- The PR says `Refs #3482`, lists the rulings above, and states that nothing is reachable from the UI yet.
