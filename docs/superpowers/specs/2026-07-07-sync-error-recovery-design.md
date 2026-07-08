# Sync Error Recovery — Design

Date: 2026-07-07
Issue: [#509](https://github.com/submersion-app/submersion/issues/509) (plus a related maintainer-observed dead-end)

## Problem

Users can land in a persistent Cloud Sync error with no in-app way out — a
reinstall is currently the only escape. Two concrete triggers were reported:

1. **"The replaced library is still uploading. Try again shortly."**
   (`sync_service.dart` `adoptReplacedLibrary`, ~line 2192). A device did a
   "Replace everywhere", bumping the library epoch, but the uploading device
   went **offline** before publishing the new base. Every other device sees the
   new epoch marker, finds no base for it (`sources.baseFilePaths.isEmpty`),
   and — because the marker is not stale/old-format, so `_recoverUnreadableEpoch`
   returns false — returns "still uploading, try again shortly" **forever**.

2. **`PathAccessException: Cannot open file, path = '/tmp/ssv1_base_…json'
   (OS Error: Operation not permitted, errno = 1)`** (#509). The base export
   temp file is written to `Directory.systemTemp` (`sync_data_serializer.dart`
   `exportBaseToTempFile`, line 730; also `base_part_file_sink.dart` line 16),
   which resolves to `/tmp` on macOS. A hardened-runtime / sandboxed app can be
   denied access there (EPERM), so publishing/adopting a base fails on every
   sync.

### Why existing recovery does not help

"Reset Sync State" (`SyncService.resetSyncState`) only calls
`_syncRepository.resetSyncState(clearDeletionLog: false)` — DB-level sync rows,
cursors, and device identity. It does **not** clear the `LibraryEpochStore`
(SharedPreferences keys `sync_last_accepted_epoch_marker` and
`sync_pending_replace_marker`), nor any cloud-side epoch marker. So the next
sync re-reads the same wedged epoch state and re-wedges. Deleting the database
also leaves the SharedPreferences epoch keys intact. Only a full reinstall
(which wipes the app container, including SharedPreferences) escaped — which is
exactly what the #509 reporter had to do.

## Goals

- Give users a reliable, in-app **way out** of any wedged sync state without a
  reinstall and without losing dive data.
- Fix the two specific dead-ends at the source so they stop being terminal.
- Let a user reclaim cloud space by clearing this device's — or all — sync
  artifacts on the active backend.

## Non-goals

- No change to the normal sync/merge/replace happy paths.
- No multi-backend fan-out: cloud-clear operates on the **active** provider only.
- No automatic background repair; recovery is user-initiated (except the two
  targeted fixes, which make specific failures non-terminal).

## Surfaces

- New **Troubleshoot Sync** screen, opened from the Cloud Sync page's *Advanced*
  section (`cloud_sync_page.dart` `_buildAdvancedSection`).
- The existing **"Sync error" banner becomes tappable** and routes to that
  screen, so a stuck user finds the exit where the error is shown.

The existing "Reset Sync State" and "Sign Out" entries remain unchanged; the new
recovery actions live on the Troubleshoot screen with escalating severity and
plain-language descriptions so users pick the right one.

## Component 1 — Repair Sync (comprehensive local reset)

The guaranteed escape: a new `SyncService.repairLocalSyncState()` that clears
**all** local sync state without touching dive data — everything a reinstall
clears, minus the reinstall.

Clears:
- `_syncRepository.resetSyncState(clearDeletionLog: false)` — which already
  clears sync records, **peer cursors, and all `local_publish_states` rows**
  (verified: `sync_repository.dart` deletes `syncPeerCursors` and
  `localPublishStates`), plus assigns a new device identity. The deletion log is
  preserved so deletions don't resurrect, consistent with today's Reset.
- **`LibraryEpochStore.clear()`** (new): removes both
  `sync_last_accepted_epoch_marker` and `sync_pending_replace_marker`. This is
  the **only** local sync state `resetSyncState` does not touch (it lives in
  SharedPreferences, not the DB) — the reinstall-only survivor and the crux of
  why today's "Reset Sync State" fails to clear a wedge.
- Best-effort deletion of leftover base temp files (see Component 2's temp dir).
- Clears the persisted/in-memory sync error so the banner goes away.

In short: today's Reset already nukes the DB-side sync state; Repair adds the
SharedPreferences epoch markers (and temp/error cleanup) to make it a true
reinstall-equivalent.

After repair the device is a fresh participant; the next sync runs the normal
first-sync merge flow. Repair does **not** auto-trigger a sync — the user taps
"Sync Now" when ready. UI confirmation stresses that dive data is safe and only
the sync bookkeeping is reset.

## Component 2 — Targeted fixes for the two dead-ends

### 2a. Offline-uploader adopt wait becomes actionable

When `adoptReplacedLibrary()` finds no base for a **non-stale** epoch, instead of
the terminal "still uploading, try again shortly", surface a distinct *waiting*
outcome the Troubleshoot screen presents with an action:

> "The other device may be offline. Rebuild this backend from **this** device's
> library."

Choosing it republishes this device's library as the current epoch's base
(reusing the existing re-establish path — the same mechanism
`_recoverUnreadableEpoch` uses today, generalized to a user-driven choice rather
than only auto-firing for stale/old-format markers). "Try again shortly"
remains available for the case where the uploader is merely slow, not gone.

### 2b. Sync temp files use the app-container temp dir; base failures are non-fatal

- Default the temp dir for `exportBaseToTempFile` (`sync_data_serializer.dart`)
  and `BasePartFileSink` (`base_part_file_sink.dart`) to
  `path_provider`'s `getTemporaryDirectory()` (always accessible app-container
  temp) instead of `Directory.systemTemp` (`/tmp`). The existing injectable
  `tempDir`/`tempDirProvider` seams are kept for tests; only the default changes.
- A base open/read/write failure is logged and treated as **transient** (retry
  next sync) rather than surfacing as a terminal sync error that recurs every
  attempt. Combined with Component 1, no base-file problem can permanently wedge
  a device.

## Component 3 — Cloud clear on the active provider (two distinct actions)

Both operate on the **active** provider only and are exposed on the Troubleshoot
screen with clearly different severities.

### 3a. Remove this device's sync files (safe)

`SyncService.deleteDeviceSyncFile(thisDeviceId)` already retires this device's
changeset log; extend it to also remove this device's base parts and any
conflict copies. Other devices keep syncing; frees this device's share of the
folder. `thisDeviceId` from `SyncRepository.getDeviceId()`. Standard
confirmation.

### 3b. Wipe ALL sync data on this backend (destructive)

`SyncService.deleteAllSyncFiles(provider)` already wipes changeset logs
(`ssv1.*`) and legacy full-file uploads, but **deliberately preserves** the
`submersion_library_*` epoch/moved markers. For a genuine fresh start this action
additionally deletes those epoch markers. Every device re-establishes from
scratch. Guarded by an extra/typed confirmation distinct from 3a.

## Data / state inventory (what "wedged" state lives where)

| State | Location | Cleared by Reset today? | Cleared by Repair (C1)? |
|-------|----------|-------------------------|-------------------------|
| Sync records, peer cursors, device id | main DB | yes | yes |
| `local_publish_states` (all providers) | main DB | yes | yes |
| Last-accepted / pending-replace epoch markers | **SharedPreferences** | **no** | **yes** |
| Deletion log | main DB | kept by design | kept by design |
| Base temp files | temp dir | n/a | best-effort delete |
| Cloud epoch markers + per-device files | cloud | no | no (that's Component 3) |

## Error handling

- Every recovery action is best-effort and idempotent: partial failure (e.g.
  provider offline during a cloud clear) is logged, reported to the user, and
  safe to re-run. Cloud clears already swallow per-file errors.
- Repair must complete the local clears even if the active provider is
  unreachable (local state is the point).

## Testing

- **Unit** (`SyncService` / stores with fakes):
  - `repairLocalSyncState` clears each store (sync repo, pending, epoch prefs,
    publish state) and the error; deletion log preserved.
  - `LibraryEpochStore.clear()` removes both keys.
  - `adoptReplacedLibrary` with no base for a non-stale epoch returns the new
    actionable *waiting* outcome (not a bare error), and the rebuild action
    republishes the local library.
  - `exportBaseToTempFile` / `BasePartFileSink` default to the app temp dir; a
    base file error is non-fatal.
  - 3a targets only this device's files; 3b also deletes epoch markers.
- **Widget** (`cloud_sync_page` / Troubleshoot screen):
  - Advanced → Troubleshoot navigation; tappable error banner routes there.
  - Each action shows its confirmation; destructive 3b requires the stronger
    confirmation.

## Sizing / delivery

Cohesive but sizable — one spec, delivered as a small stack of two PRs so each
stays reviewable:

- **PR 1**: temp-dir fix (2b) + Repair Sync core (C1, incl. `LibraryEpochStore.clear`)
  + Troubleshoot screen scaffold + tappable error banner.
- **PR 2**: cloud-clear actions (C3) + offline-uploader actionable escape (2a).

## Resolved decisions

- "Wipe all" (3b) **also clears epoch markers** for a true fresh start.
- Repair Sync **does not auto-trigger a sync**; the user syncs when ready.
- Cloud clear targets the **active provider only**.
