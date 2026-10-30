# Storage Garbage Collection Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Close the storage leaks left by restores and media re-uploads, run every storage sweep from one coordinator on a schedule, and show device and cloud storage totals with a "Reclaim storage" action on the Storage usage page.

**Architecture:** Pure policy pieces (peer sync snapshot, orphan delete policy, sibling-key references) feed a reworked `MediaVerifyService` that can measure without deleting. A `StorageGcCoordinator` (plain Dart, injected callbacks) owns cadence, triggers and run results, persisted in SharedPreferences. Riverpod providers wire it to the live services; `app.dart` kicks it on launch and resume; the Storage usage page reads its state.

**Tech Stack:** Flutter, Riverpod 3, Drift, SharedPreferences, flutter_test with fakes.

**Spec:** `docs/design/specs/2026-10-17-storage-gc-design.md`

## Global Constraints

- Cleanup deletes only files Submersion created inside its own areas: app temp/cache dirs, `smv1/` media store objects, `ssv1.*` sync files, shared library files the app wrote. Never a connected source, never a path read off a media row. Every delete matches the app's own naming pattern; anything else is skipped.
- Cloud media orphan grace: 7 days from the object's `lastModified` (`MediaVerifyService.graceWindow`).
- Early delete clock-skew margin: 1 hour.
- Device sweeps: at most once a day. Local cache sweep keeps its weekly cadence. Cloud cleanup: weekly, unmetered only, fleet-wide via `media_stores.last_sweep_at`. Cloud measurement: weekly per device, device-local stamp.
- Manual "Reclaim storage" and "Rescan" ignore cadence and the unmetered requirement, never the safety rules.
- Sync folder and shared libraries: measurement only, no deletes.
- No schema change. All new state lives in SharedPreferences (device-local).
- Every user-visible string goes through l10n, with all 11 ARB files updated.
- Byte figures use `formatBytes` (`lib/core/utils/byte_format.dart`).
- Paths built with `p.join`; tests reach temp space through `Directory.systemTemp`.
- Tests that touch SharedPreferences or other process-wide state restore it (`docs/developer/testing.md`).
- No em dashes in code, comments, docs or commit messages.

## Review Focus

1. A Merge restore while another device still has the photos: cloud deletes must wait until a sync completes after the restore. Test in Task 2 (`policy defers every delete until a pull after the last restore`).
2. Two rows of one photo, one `.JPG` and one `.jpeg`, both still original: neither original key is deleted. Test in Task 3 (`keeps every extension some row still resolves to`).
3. A row whose upload is pending (hash stamped, no upload stamp): nothing under its hash is deleted, siblings included. Test in Task 3 (`a row with no upload stamp keeps every object under its hash`).
4. The share sheet's freshly exported `submersion_backup_*.db` in temp must survive the restore leftover sweep. Test in Task 6 (`keeps a backup-named file younger than 24 hours`).
5. A store listing that yields the same key twice must keep exactly one copy, and a key listed once is never deleted as a duplicate. Test in Task 4 (`deletes extra copies of a duplicated key and keeps one`).

---

### Task 1: Peer sync snapshot

Records, after every pull, what this device knows about its peers, so the media sweep can tell whether it is caught up and whether every peer has published since an object was uploaded.

**Files:**
- Create: `lib/core/services/sync/peer_sync_snapshot.dart`
- Modify: `lib/core/services/sync/sync_service.dart` (after the `recordsFailed == 0` / `updateLastSyncTime` block near line 836)
- Test: `test/core/services/sync/peer_sync_snapshot_test.dart`

**Interfaces:**
- Produces:
  - `class PeerPublish { final String deviceId; final DateTime publishedAt; }`
  - `class PeerSyncSnapshot { final DateTime takenAt; final bool caughtUp; final List<PeerPublish> peers; Map<String, Object?> toJson(); factory PeerSyncSnapshot.fromJson(Map<String, Object?>); }`
  - `PeerSyncSnapshot buildPeerSyncSnapshot({required DateTime now, required String selfDeviceId, required List<SyncManifest> peerManifests, required Set<String> fencedPeerIds, required Set<String> skippedPeerIds, required Set<String> readFailedPeerIds, required Set<String> newerSchemaPeerIds, required int recordsFailed})`
  - `class PeerSyncSnapshotStore { PeerSyncSnapshotStore(SharedPreferences prefs); static const key = 'sync_peer_snapshot_v1'; PeerSyncSnapshot? read(); Future<void> write(PeerSyncSnapshot s); }` (`read` returns null for a missing or malformed value)

- [ ] **Step 1: Write the failing tests**
  - `excludes self, fenced and stale-epoch peers`: manifests for `self`, `a`, `b` (fenced), `c` (skipped) give peers `[a]` with `publishedAt == DateTime.fromMillisecondsSinceEpoch(a.updatedAt)`.
  - `is caught up only after a clean pull`: `caughtUp` is true with all sets empty and `recordsFailed == 0`; false when `recordsFailed == 1`, when `readFailedPeerIds == {'a'}`, and when `newerSchemaPeerIds == {'a'}`.
  - `round-trips through the store`, and `read returns null for malformed json` (`prefs.setString(key, '{')`).
- [ ] **Step 2: Run** `flutter test test/core/services/sync/peer_sync_snapshot_test.dart`; expect compile failure.
- [ ] **Step 3: Implement** the types above. In `sync_service.dart`, after the clean-apply block, build the snapshot from `pullResult` (`peerManifests`, `skippedPeerDeviceIds`, `readFailedPeerDeviceIds`, `newerSchemaPeerDeviceIds`), `fencedPeerIds` and `recordsFailed`, and write it with `PeerSyncSnapshotStore(await SharedPreferences.getInstance())` inside a try/catch that logs and never fails the sync.
- [ ] **Step 4: Run** the test file; expect PASS. Run `flutter test test/core/services/sync/` to confirm no sync regression.
- [ ] **Step 5: Commit** `feat(storage): record a peer sync snapshot after each pull`

### Task 2: Orphan delete policy

**Files:**
- Create: `lib/features/media_store/data/orphan_delete_policy.dart`
- Test: `test/features/media_store/data/orphan_delete_policy_test.dart`

**Interfaces:**
- Consumes: `PeerSyncSnapshot` (Task 1).
- Produces:
  - `enum OrphanVerdict { delete, wait, deferred }` (`wait`: inside the grace window; `deferred`: this device is not caught up, nothing may be deleted)
  - `class OrphanDeletePolicy { const OrphanDeletePolicy({required DateTime now, required bool syncEnabled, PeerSyncSnapshot? snapshot, DateTime? lastRestoreAt, Duration grace = const Duration(days: 7), Duration skew = const Duration(hours: 1)}); bool get deletesAllowed; OrphanVerdict verdictFor(DateTime lastModified); }`
  - `const OrphanDeletePolicy.unrestricted(DateTime now)`: sync off, 7-day grace only (used by tests and when sync is off).

Rules (from the spec):
- `deletesAllowed` is false when `syncEnabled` and (`snapshot == null` or `!snapshot.caughtUp` or (`lastRestoreAt != null` and `!snapshot.takenAt.isAfter(lastRestoreAt)`)).
- Not allowed gives `deferred` for every object.
- `lastModified` before `now - grace` gives `delete`.
- Early delete, only when `syncEnabled`: `lastModified + skew` is before `snapshot.takenAt` and before every `peer.publishedAt` gives `delete` (vacuously true for zero peers).
- Otherwise `wait`.

- [ ] **Step 1: Write the failing tests**: `deletes after the grace window with sync off`, `waits inside the grace window with sync off`, `deletes early once every peer published after the upload`, `waits while one peer has not published since the upload`, `early delete respects the skew margin` (peer published 30 minutes after upload gives `wait`), `deletes early with no peers once a pull followed the upload`, `defers when sync is on and no snapshot exists`, `defers when the snapshot is not caught up`, `policy defers every delete until a pull after the last restore` (snapshot taken before `lastRestoreAt` gives `deferred` even for a 30-day-old object).
- [ ] **Step 2: Run** the file; expect compile failure.
- [ ] **Step 3: Implement** `OrphanDeletePolicy`.
- [ ] **Step 4: Run**; expect PASS.
- [ ] **Step 5: Commit** `feat(storage): add the cloud orphan delete policy`

### Task 3: Sibling-key references

Decides, for a hash some row still uses, which keys in each namespace a row could need.

**Files:**
- Create: `lib/features/media_store/data/media_key_references.dart`
- Modify: `lib/features/media/data/repositories/media_repository.dart` (add a query beside `getAllContentHashes`, line 2552)
- Modify: `docs/design/specs/2026-10-17-storage-gc-design.md` (replace the leak 3 sub-bullets with the rule below, and change the in-flight rule to "while a `transferring` row exists")
- Test: `test/features/media_store/data/media_key_references_test.dart`, plus a repository test in `test/features/media/data/repositories/` for the new query

**Interfaces:**
- Produces:
  - `class MediaKeyReference { final String originalExtension; final bool isVideo; final bool hasOriginalStamp; final bool hasRenditionStamp; }`
  - `MediaRepository.getContentReferences() -> Future<Map<String, List<MediaKeyReference>>>`: every row with a non-null `contentHash`, keyed by hash. `originalExtension` is `StoreKeys.extensionFor(originalFilename)`. selectOnly projection, no BLOB columns.
  - `enum StoreNamespace { objects, thumbs, renditions }`
  - `bool isKeyReferenced({required StoreNamespace namespace, required String extension, required List<MediaKeyReference> refs})`

Rule:
- Empty `refs` returns false (a plain orphan).
- If any ref has neither an original nor a rendition stamp, return true (pending upload, reverse repair, or a restore from before the upload keeps everything).
- `thumbs` returns true.
- `objects` returns true when some ref has `hasOriginalStamp` and `originalExtension == extension`.
- `renditions` returns true when some ref has `hasRenditionStamp` and `extension == (isVideo ? 'mp4' : 'jpg')`.

- [ ] **Step 1: Write the failing tests**: `an unreferenced hash is not referenced`, `a row with no upload stamp keeps every object under its hash`, `keeps every extension some row still resolves to` (`.jpg` and `.jpeg` refs both stamped original), `drops an extension no stamped row resolves to` (only `jpg` refs, key `bin`), `drops the original once every row is stamped compressed only`, `drops the rendition once every row is stamped original only`, `thumbs are always referenced`. Repository test: two rows with one hash and filenames `a.JPG`, `b.jpeg` give two refs with extensions `jpg` and `jpeg`; a row with a null hash is absent.
- [ ] **Step 2: Run** both files; expect compile failure.
- [ ] **Step 3: Implement** the query and `isKeyReferenced`; update the spec text.
- [ ] **Step 4: Run**; expect PASS.
- [ ] **Step 5: Commit** `feat(storage): decide which sibling store keys a row still needs`

### Task 4: Verify sweep measures, applies the policy and removes siblings and duplicates

**Files:**
- Modify: `lib/features/media_store/data/media_verify_service.dart`
- Modify: `lib/features/media_store/presentation/providers/media_store_providers.dart` (`mediaVerifyRunnerProvider`, line 175: pass the live policy, see Task 8 for the provider it reads)
- Test: `test/features/media_store/data/media_verify_service_test.dart` (extend the existing file)

**Interfaces:**
- Consumes: `OrphanDeletePolicy`, `OrphanVerdict` (Task 2); `getContentReferences`, `isKeyReferenced`, `StoreNamespace` (Task 3).
- Produces:
  - `MediaVerifyService.run({void Function(int)? onProgress, OrphanDeletePolicy? policy, bool dryRun = false})`. A null `policy` means `OrphanDeletePolicy.unrestricted(now)`, which keeps today's behaviour for existing callers.
  - `VerifyLibraryReport` gains `int totalBytes` (sum of listed sizes across all namespaces, duplicates included), `int reclaimableBytes` (bytes whose verdict was `delete`; equal to `bytesReclaimed` when not a dry run), `int waitingBytes` (unreferenced bytes with verdict `wait` or `deferred`), `bool deferred` (policy did not allow deletes).

Behaviour:
- `referenced` comes from `getContentReferences()`. For each listed key whose hash parses, look up refs.
- A key is a candidate when `!isKeyReferenced(...)`, using the key's extension.
- A candidate is deleted only when `!dryRun` and the verdict is `delete`.
- **Duplicates:** count occurrences per key during the listing. After a namespace finishes, a key listed `n > 1` times that is not deleted as a candidate gets `n - 1` further `_store.delete(key)` calls, since each call removes one copy. Skipped in a dry run, but its extra bytes count as reclaimable.
- `present*` sets for reverse repair still record every referenced hash, as today.
- A dry run skips the reverse repair and the session reap.

- [ ] **Step 1: Write the failing tests** against the existing fake store (extend it so `list` can yield a key twice and `delete` removes one occurrence):
  - `dry run deletes nothing and reports reclaimable bytes`
  - `deferred policy deletes nothing and reports waiting bytes`
  - `deletes an unreferenced extension sibling past the grace window`
  - `keeps a sibling a pending row still needs`
  - `deletes extra copies of a duplicated key and keeps one`
  - `a key listed once is never deleted as a duplicate`
  - `totalBytes sums every listed object`
- [ ] **Step 2: Run** the file; expect failures.
- [ ] **Step 3: Implement.** Keep the per-object best-effort try/catch around every delete.
- [ ] **Step 4: Run** the file and `flutter test test/features/media_store/`; expect PASS.
- [ ] **Step 5: Commit** `feat(storage): verify sweep measures, applies the delete policy, removes siblings and duplicates`

### Task 5: Abandon resumable sessions a re-upload or Transfers delete drops

**Files:**
- Modify: `lib/features/media_store/data/media_transfer_queue_repository.dart` (`enqueueReupload`, line 181; `delete`)
- Modify: `lib/features/media_store/data/media_store_worker.dart` (`reuploadAndKick`, line 608)
- Modify: `lib/features/media_store/presentation/pages/transfers_page.dart` (bulk delete, line 215)
- Test: the queue repository and worker tests under `test/features/media_store/`

**Interfaces:**
- Produces:
  - `class DroppedResume { final String mediaId; final String? contentHash; final String resumeStateJson; }`
  - `enqueueReupload(...)` returns `Future<({int id, List<DroppedResume> dropped})>`.
  - `delete(int id)` returns `Future<DroppedResume?>` (null when the row had no resume state).
  - `MediaStoreWorker.abandonDroppedSessions(List<DroppedResume> dropped) -> Future<void>`: derives the original key (`StoreKeys.objectKey(hash, extension: extensionFor(media.originalFilename))`, media row read by `mediaId`) and calls `_store.abandonResume(key, json)` best-effort. It skips an entry with no hash or no media row. Resumable sessions only exist for originals (`media_upload_pipeline.dart:251`).

- [ ] **Step 1: Write the failing tests**: `enqueueReupload reports the resume state it dropped`, `delete reports the resume state it dropped`, `worker abandons the session a re-upload dropped` (fake store records `abandonResume(key, json)` with the `.jpg` key), `worker skips a dropped entry without a hash`.
- [ ] **Step 2: Run**; expect failures.
- [ ] **Step 3: Implement.** Update every caller of the two changed return types (`grep -rn "enqueueReupload\|queue.delete(" lib test`). The Transfers page calls `abandonDroppedSessions` through the runtime's worker when a runtime exists.
- [ ] **Step 4: Run** `flutter test test/features/media_store/`; expect PASS.
- [ ] **Step 5: Commit** `fix(media-store): abandon resumable sessions a re-upload or delete drops`

### Task 6: Device leaks: restore downloads, and dry-run measurement for device sweeps

**Files:**
- Modify: `lib/features/backup/data/services/backup_service.dart` (`restoreFromBackup`, lines 739-818)
- Create: `lib/core/services/storage/restore_temp_sweep.dart`
- Modify: `lib/core/services/storage/scratch_sweep.dart` (`run`)
- Test: `test/core/services/storage/restore_temp_sweep_test.dart`, `test/core/services/storage/scratch_sweep_test.dart`, and the backup service restore test

**Interfaces:**
- Produces:
  - `class RestoreTempSweep { RestoreTempSweep({required Future<Directory> Function() temporaryDirectory}); static const minAge = Duration(hours: 24); Future<ScratchSweepReport> run({DateTime? now, bool dryRun = false}); }`. It matches only regular files directly in the temp dir named `^submersion_backup_.+\.(db|sbe)$` and older than `minAge` by modified time.
  - `StorageScratchSweep.run({DateTime? now, bool dryRun = false})`: in a dry run, counts what it would delete without deleting.

- [ ] **Step 1: Write the failing tests**:
  - `deletes an old downloaded backup left in temp`
  - `keeps a backup-named file younger than 24 hours`
  - `ignores files in subfolders and names that do not match` (`notes.db`, `picked/submersion_backup_x.db`)
  - `dry run counts without deleting` (both sweeps)
  - Backup service: `restoreFromBackup deletes a cloud download once the restore finishes` and `restoreFromBackup never deletes the record's own local file`.
- [ ] **Step 2: Run**; expect failures.
- [ ] **Step 3: Implement.** In `restoreFromBackup`, remember whether `sourcePath` came from `_safPort.readBackup` or `_downloadFromCloud`. If it did, delete it best-effort in a `finally` that wraps everything after it was produced, so a validation failure also cleans up.
- [ ] **Step 4: Run** the three files; expect PASS.
- [ ] **Step 5: Commit** `fix(backup): remove downloaded backups after a restore and sweep leftovers`

### Task 7: Cloud usage measurement for sync and shared libraries

**Files:**
- Create: `lib/core/services/storage/gc/cloud_usage_measure.dart`
- Modify: `lib/core/services/shared_library/shared_library_transport.dart` (add `measureBytes`)
- Test: `test/core/services/storage/gc/cloud_usage_measure_test.dart`, and a transport test beside the existing transport tests

**Interfaces:**
- Produces:
  - `Future<int> measureSyncFolderBytes(CloudStorageProvider provider, {String? folderId})`: sums `sizeBytes` of `listFiles(folderId: folderId, namePattern: ChangesetLogLayout.listPattern)`, counting only names for which `ChangesetLogLayout.deviceIdOf` is non-null.
  - `SharedLibraryTransport.measureBytes() -> Future<({int bytes, bool partial})>`: sums the files directly in the library root and in its `members`, `sites`, `suggestions` and `backups` folders, using the same `_directlyIn` guard as `_listKind`. Any file with a null size sets `partial`.
  - `class CloudUsage { final int? mediaBytes; final int? mediaReclaimableBytes; final int? mediaWaitingBytes; final int? syncBytes; final int? librariesBytes; final bool partial; final DateTime scannedAt; toJson/fromJson }`. A null field means the area is not set up. `partial` is set when any area failed or reported partial.

- [ ] **Step 1: Write the failing tests** with fake providers: `sums only sync files`, `library measure ignores nested library folders`, `a file without a size marks the library partial`, `CloudUsage round-trips through json`.
- [ ] **Step 2: Run**; expect failures.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run**; expect PASS.
- [ ] **Step 5: Commit** `feat(storage): measure cloud sync and shared library usage`

### Task 8: Storage GC coordinator, store and wiring

**Files:**
- Create: `lib/core/services/storage/gc/storage_gc_store.dart`
- Create: `lib/core/services/storage/gc/storage_gc_coordinator.dart`
- Create: `lib/features/settings/presentation/providers/storage_gc_providers.dart`
- Modify: `lib/core/presentation/pages/startup_page.dart` (remove the scratch and local cache blocks, lines 1098-1157; `sweepLeftoverSyncTempFiles`, the media backlog sweep, the scanned-logs migration and the tombstone GC stay where they are)
- Modify: `lib/features/media_store/presentation/providers/media_store_providers.dart` (remove the auto-verify block, lines 543-586)
- Modify: `lib/features/backup/data/services/backup_service.dart` (`_armPostRestoreSync`, line 964: stamp the restore time)
- Modify: `lib/app.dart` (kick on first frame and on resume, beside `_resumeMediaTransfers`)
- Test: `test/core/services/storage/gc/storage_gc_coordinator_test.dart`, `test/core/services/storage/gc/storage_gc_store_test.dart`

**Interfaces:**
- Consumes: Tasks 1, 2, 4, 6 and 7.
- Produces:
  - `enum StorageGcTrigger { launch, resume, timer, postRestore, manual, rescan }`
  - `class AreaResult { final int bytes; final int items; final DateTime at; }`
  - `class StorageGcStore { StorageGcStore(SharedPreferences); DateTime? lastDeviceRun; DateTime? lastCloudMeasure; DateTime? lastRestoreAt; DateTime? postRestorePendingSince; AreaResult? lastDeviceResult; AreaResult? lastCloudResult; CloudUsage? cloudUsage; ...setters as Futures; static Future<void> markRestored(SharedPreferences prefs, DateTime at); }`. `markRestored` sets both `lastRestoreAt` and `postRestorePendingSince`.
  - `class StorageGcCoordinator` with injected dependencies:
    - `deviceSweeps: List<DeviceSweep>`, where `typedef DeviceSweep = Future<ScratchSweepReport> Function({required DateTime now, required bool dryRun})`.
    - `localCacheSweep: Future<void> Function(DateTime now)`, keeping its weekly stamp `kLocalCacheSweepStampKey`.
    - `network: Future<NetworkKind> Function()`.
    - `isSyncBusy: bool Function()`, `hasTransferringUploads: Future<bool> Function()`.
    - `mediaSweep: Future<VerifyLibraryReport?> Function({required bool dryRun})`: null when no store is attached. The provider builds the policy from `PeerSyncSnapshotStore`, `cloudStorageProviderProvider != null` and `lastRestoreAt`.
    - `fleetSweepDue: Future<bool> Function(DateTime now)` and `stampFleetSweep: Future<void> Function(DateTime now)`. These wrap `shouldAutoVerify`-style checks on `media_stores.last_sweep_at` with a 7-day period, falling back to a device-local stamp when `getActive()` is null.
    - `measureSync: Future<int?> Function()`, `measureLibraries: Future<({int bytes, bool partial})?> Function()`.
    - `store: StorageGcStore`, `now: DateTime Function()`.
  - `Future<void> run(StorageGcTrigger trigger)`. It is re-entrancy safe: a call while running returns the running future.
  - `Stream<StorageGcStatus> get status`, where `StorageGcStatus { idle, running }`.
  - Providers:
    - `storageGcCoordinatorProvider`. Builds the coordinator and starts a 6-hour `Timer.periodic` calling `run(timer)`, cancelled in `ref.onDispose`.
    - `storageGcStateProvider`. A StreamProvider emitting a `StorageGcView` with `cloudUsage`, `lastDeviceResult`, `lastCloudResult`, `deviceReclaimableBytes`, `running` and `postRestorePending`, re-read after each run.
    - `deviceReclaimableBytesProvider`. A dry run of the device sweeps.

Run logic (per trigger):
- **Device part:**
  - Runs when `trigger` is `manual` or `postRestore`, or when `lastDeviceRun` is null or at least 1 day old (same future-stamp defence as `shouldSweepScratch`).
  - Runs every `deviceSweeps` entry, then `localCacheSweep`.
  - Records `lastDeviceResult` (summed) and `lastDeviceRun`.
  - Not run on `rescan`.
- **Cloud part:**
  - Skipped when `isSyncBusy()`. It is also skipped when an upload is transferring, except on `rescan`, which deletes nothing.
  - Automatic triggers need `NetworkKind.unmetered`. `manual` and `rescan` run on any network.
  - Deletes (`mediaSweep(dryRun: false)`) happen when `trigger == manual`, or when `fleetSweepDue(now)`. After a delete run it calls `stampFleetSweep`.
  - Otherwise, when the measurement is due (`lastCloudMeasure` null or at least 7 days old, or `trigger` is `rescan` or `postRestore`), it runs `mediaSweep(dryRun: true)`.
  - Either path then measures sync and libraries and stores `CloudUsage` and `lastCloudMeasure`. A delete run also stores `lastCloudResult`.
- **Post-restore:**
  - The first `launch`, `resume` or `timer` run that finds `postRestorePendingSince` set runs as `postRestore`.
  - It clears the flag only after the device part succeeds.
  - Its cloud deletes still go through the policy, which defers until a pull after `lastRestoreAt`.
  - It forces a fleet delete run once the policy allows, by keeping a `postRestoreCloudPending` flag until a non-deferred media sweep completes.
- Every part is wrapped so a failure logs and never throws to the caller.

- [ ] **Step 1: Write the failing tests** with fakes and `SharedPreferences.setMockInitialValues`:
  - `launch runs device sweeps once a day`
  - `manual runs device and cloud regardless of cadence and network`
  - `automatic cloud waits for an unmetered network`
  - `cloud part skips while sync is busy`
  - `rescan measures without deleting`
  - `a restore marker forces a post-restore run and clears after it`
  - `post-restore keeps the cloud delete pending while the media sweep is deferred`
  - `records last reclaimed per area`
  - `a failing sweep does not stop the others`
  - `concurrent runs share one execution`
  - Store test: `round-trips every field`.
- [ ] **Step 2: Run**; expect failures.
- [ ] **Step 3: Implement** the store, coordinator and providers. In `_armPostRestoreSync` call `StorageGcStore.markRestored(prefs, DateTime.now())`. In `app.dart`, `ref.read(storageGcCoordinatorProvider).run(StorageGcTrigger.launch)` after the first frame, and `run(StorageGcTrigger.resume)` in the existing resume handler, both `unawaited`. Remove the startup and auto-verify blocks. `mediaVerifyRunnerProvider` now passes the live policy from a `orphanDeletePolicyProvider` defined in `storage_gc_providers.dart` (a FutureProvider building `OrphanDeletePolicy` from the snapshot store, the sync provider and the GC store).
- [ ] **Step 4: Run** the new tests, `flutter test test/features/media_store/ test/core/services/storage/`, and `flutter test test/architecture/ test/shared/` (new lib files, provider annotations such as `// no-tick:`); expect PASS.
- [ ] **Step 5: Commit** `feat(storage): one coordinator runs every storage sweep on a schedule`

### Task 9: Storage usage page: totals, reclaim card and cloud group

**Files:**
- Modify: `lib/features/settings/presentation/pages/storage_usage_page.dart`
- Create: `lib/features/settings/presentation/widgets/storage_reclaim_card.dart`
- Create: `lib/features/settings/presentation/widgets/cloud_storage_group.dart`
- Modify: all 11 `lib/l10n/arb/app_*.arb`, then regenerate l10n
- Test: `test/features/settings/presentation/pages/storage_usage_page_test.dart` (extend), `test/features/settings/presentation/widgets/storage_reclaim_card_test.dart`, `test/features/settings/presentation/widgets/cloud_storage_group_test.dart`

**Interfaces:**
- Consumes: `storageGcStateProvider`, `storageGcCoordinatorProvider`, `deviceReclaimableBytesProvider` (Task 8).

Layout (approved option A):
- **Total header.** The total of device plus known cloud bytes, and a second line "{device} on this device, {cloud} in the cloud". The existing partial-total label applies when any device category or any cloud area is unmeasured, or `CloudUsage.partial` is set. The cloud line is omitted when no cloud area is set up.
- **Reclaim card**, first after the header:
  - Title "About {bytes} can be reclaimed", where bytes is device reclaimable plus `mediaReclaimableBytes`. When that is 0, the title reads "Nothing to reclaim right now".
  - "Last reclaimed {bytes}, {relative time}" from the newer of the two `AreaResult`s; the line is hidden when neither exists.
  - When `mediaWaitingBytes > 0`: "{bytes} more will be reclaimable after the safety wait".
  - A FilledButton "Reclaim storage". While running it is disabled and shows a progress indicator.
  - When done, a SnackBar "Reclaimed {bytes}".
- **On this device:** the existing groups unchanged. The Temporary files row gains a secondary line "{bytes} reclaimable" from the dry-run sweeps when that is above 0.
- **In the cloud:** a new group after the device groups.
  - Rows for Media store (used, plus "{bytes} reclaimable" when above 0), Database sync and Shared libraries, each shown only when its `CloudUsage` field is non-null.
  - Footer "Scanned {relative time}" with a TextButton "Rescan" (`run(rescan)`), or "Not scanned yet" with the same button.
  - The group is hidden when no cloud area is set up.

- [ ] **Step 1: Write the failing widget tests** (English locale, overrides as in the existing page test):
  - `header splits device and cloud totals`
  - `reclaim card shows reclaimable and last reclaimed`
  - `reclaim card says nothing to reclaim at zero`
  - `reclaim button runs a manual pass and disables while running`
  - `cloud group shows only areas that are set up`
  - `rescan runs a rescan pass`
  - `cloud group hidden when nothing is set up`
  - `waiting bytes line appears only above zero`
  - The existing tests keep passing, including the 360px no-overflow expectation.
- [ ] **Step 2: Run**; expect failures.
- [ ] **Step 3: Implement.** Add ARB keys under the `settings_storageUsage_` prefix with placeholders, translate them into every ARB file (follow the l10n memory index rules for placeholders and plurals), and run `flutter gen-l10n`.
- [ ] **Step 4: Run** the page and widget tests, then `flutter test test/l10n/` if present and `test/architecture/`; expect PASS.
- [ ] **Step 5: Capture after screenshots** with the throwaway harness at `test/zz_tmp_shots/` (never staged). Use light, dark, desktop and phone, with cloud areas populated. Name them `01-storage-usage-after*.png` in the scratchpad.
- [ ] **Step 6: Commit** `feat(storage): show cloud totals and reclaim storage on the Storage usage page` (stage explicit paths only).

### Task 10: Final checks

- [ ] `dart format .`, `flutter analyze` (no issues), `flutter test test/architecture/ test/shared/`, and every test directory touched above.
- [ ] `git status`: the throwaway `test/zz_tmp_shots/` is untracked and is deleted after the screenshots are copied out.
- [ ] Grep the diff for the em dash character; expect none.
