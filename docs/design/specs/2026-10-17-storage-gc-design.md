# Storage garbage collection and cloud storage totals

Issue: #3396. Related: #3390 (Settings > Data dashboard, may show these numbers later).

## Why

The maintainer restored backups and re-uploaded media, and storage grew both on
the device and in the cloud media store with files nothing referenced. Cleanup
exists for parts of this, but it is spread across separate startup jobs, has gaps,
runs out of sight (the media store sweep every 30 days at best), and nothing tells
the diver how much space Submersion uses in the cloud or what was reclaimed.

Success: after a restore or a re-upload, the leftovers go away on their own within
a predictable time, the diver can see total storage on the device and in the
cloud, and can reclaim on demand, without any risk to their own media.

## Hard rule: only Submersion's own files

Cleanup deletes only files Submersion created, inside its own storage areas:

- the app temp and cache directories,
- `smv1/` objects in the media store (originals copies, thumbs, renditions,
  resumable sessions),
- `ssv1.*` files in the sync folder,
- files the app wrote in a shared library folder.

It never deletes anything in a source the diver connected (photo library, linked
folders, Immich, Google Photos, any media source), and never deletes a file by
following a path stored on a media record. Every deletion must match the app's own
naming pattern inside its own area; anything that does not match is skipped. This
is how the existing sweeps already behave and every new sweep keeps it. Tests
assert it for each sweep.

## Goals

1. Close the leaks found in the audit (below).
2. One storage GC coordinator that runs every sweep automatically, with no prompt,
   on a schedule, under shared safety rules.
3. Storage usage page shows device and cloud totals, what can be reclaimed, what
   was reclaimed last time, and a "Reclaim storage" button.

## Non-goals

- Deleting quarantined `.pre-restore.<ts>` and `.restore-rejected.<ts>` databases.
  They may be someone's only copy of their data; they stay manual on the Backups
  page. (Designer's call.)
- Deleting a retired or idle device's sync files sooner than today. Removal stays on
  the Sync devices page and the existing 365-day retirement. (Designer's call.)
- Shared library tombstones (`sites/site-<id>.json` with `deleted: true`). Tiny, and
  dropping one before every member has seen it resurrects the site. (Designer's
  call.) Shared libraries hold no media blobs, so the issue's "orphaned blobs" gap
  does not exist.
- Provider account quota figures (Drive, Dropbox). They report the whole account,
  not Submersion's files.
- The two restore correctness risks the audit turned up (pre-restore prune may
  remove the backup being restored; an interrupted base export may resume and
  publish the pre-restore library). They are not storage leaks; file them
  separately.

## Anti-goals

- Any deletion of a diver's source media, ever.
- Deleting a cloud object another device still needs.
- A cleanup that blocks or slows sync or uploads.
- A total presented as complete when part of it could not be measured (the page's
  existing "partial total" rule applies to the cloud figures too).

## Leaks to close

### Device

1. **Downloaded backups left in temp after restore.** `restoreFromBackup` downloads
   a cloud backup or copies a SAF backup to `<temp>/<record.filename>`
   (`backup_service.dart:757`, `:1745`) and never deletes it. Delete it in the
   restore's `finally` when the path was a download or SAF copy (never when it was
   the record's own `localPath`). The coordinator's device sweep also removes
   leftovers already present: files directly in the temp dir matching the backup
   name patterns (`submersion_backup_*.db|.sbe`, also behind a `restore-<uuid>-`
   or `<uuid>-` copy prefix; pre-migration `<ts>-v<n>-v<m>.db`, also behind
   `restore-<uuid>-`) and the backup code's working copies (`restore_<uuid>.db`,
   the decrypted plaintext; `export_<uuid>.db`; `reenc_<uuid>.sbe`) older than
   24 hours. The age guard matters because `exportBackupToTemp` (share sheet)
   writes the same names there.
2. Existing local sweeps (`StorageScratchSweep`, `LocalCacheSweep`,
   `sweepLeftoverSyncTempFiles`, `MediaOrphanBacklogSweep`) keep their logic and
   move under the coordinator.

### Media store

3. **Sibling objects under a hash still in use.** Verify today treats a hash as
   referenced in every namespace and every extension, so these are never removed:
   - the same photo under a second extension (`.JPG` vs `.jpeg`, or `.bin` for a
     row with no filename), because `extensionFor` is not injective;
   - the original left behind after switching a photo to compressed (or the
     rendition after switching back), because that delete is best-effort and
     ignores failures (`media_upload_pipeline.dart:224-235`, `:278-289`).

   Change verify so a sibling under an in-use hash is deleted only when no row
   with that hash could need it. The rule is deliberately conservative
   (designer's call), unioned over every row with the hash:
   - **Any row with the hash that has no upload stamp** (upload pending,
     reverse repair, or a restored backup taken before the upload) keeps every
     object under that hash.
   - **Originals:** otherwise `<hash>.<ext>` is referenced only when some row
     with the hash has a `remoteUploadedAt` stamp and resolves to `ext`. This
     drops both a second extension and the original left after every row
     switched to compressed.
   - **Renditions:** referenced only when some row with the hash has a
     `remoteCompressedUploadedAt` stamp and the key's extension is that row's
     rendition format (`mp4` for video, `jpg` otherwise).

   The resolver itself derives both keys for every row, so it must not be copied
   literally here. Thumbs stay keyed by hash alone.
4. **Abandoned resumable sessions.** `enqueueReupload`
   (`media_transfer_queue_repository.dart:181-202`) and the Transfers page delete
   (`transfers_page.dart:215`) drop resume state without calling `abandonResume`.
   Call it. Verify's 7-day session reap stays as the backstop.
5. **Google Drive duplicates.** Two devices uploading one key at once can leave two
   files with the same name; `list()` yields both and `delete` removes one.
   Verify keeps one copy of a duplicated key and deletes the rest, only inside the
   store's `submersion-media` folder. Which copy to keep is the builder's call
   (content is identical by hash).
6. **Orphans after a restore** (media added after the backup was taken). Already
   handled by verify; the fixes are timing (coordinator) and the early-delete rule
   below. The coordinator must also run when `getActive()` is null after a restore
   that predates attaching the store: it uses the runtime's attached store
   (`attachedId`) and measures, instead of bailing out forever
   (`media_store_providers.dart:556`). It deletes nothing until a descriptor row
   exists again (a peer's sync brings it back, or a reconnect writes it), as the
   old auto-verify required: a database without one may be a fresh or reset dive
   log that knows only some of the store's media, and would judge the rest
   orphaned. Then the synced fleet stamp takes over. Verify Library follows
   the same rule. (Designer's call, narrowed by the review.)

   After a Merge restore (the default), rows for media added after the backup come
   back from peers on the next reconciling sync, so those objects are not orphans
   until that sync says so. See the caught-up rule below.

### Sync folder and shared libraries

Measurement only (designer's call). The audit found no leak there:
`ChangesetWriter._pruneSupersededBelow` already prunes this device's superseded
files inline, retired devices are handled by retirement and the Sync devices page,
and shared library tombstones are a non-goal. These rows show bytes used and no
reclaimable figure. A sync-folder deletion sweep is not part of this work.

## Safety rules (all sweeps)

- **Grace window for cloud media orphans:** 7 days from the object's
  `lastModified`, as today. The iCloud store sets each staged copy's modification
  time to the upload time: a file copy keeps the source's time, which would make
  a new upload look as old as the photo. An upload it cannot date is not
  published; the retry dates it again. Its age is the later of the modified and
  changed times, so an object an older build staged without setting the time
  is aged from its arrival, not from the photo.
- **Early delete:** an orphan may go sooner once every other known sync device has
  synced since it was uploaded, meaning, for each peer, its manifest `updatedAt`
  (capped by the time the cloud listed that manifest, since a peer's clock can
  run ahead; and dated when its content was exported, not when a retried upload
  finished) is later than the object's `lastModified` plus a clock-skew margin
  (an hour),
  this device's last clean pull started later than that too, and this device has
  applied that peer through its manifest's `publishedHlcHigh`. Retired peers
  (`ssv1.<id>.retired.json`) do not count. A peer whose manifest cannot be read
  blocks early delete, and so do a device with sync files but no manifest yet
  (its first publish is still under way) and a peer still on an older library
  epoch (its changes are not applied here, so its publish time proves nothing);
  their objects wait out the 7 days. If sync is off, the 7 days always apply.
- **Caught up before any cloud media delete** (designer's call): when database
  sync is on, every cloud media delete (orphans and siblings, early or after 7
  days) requires the latest pull to have read every live peer to its published
  head (no unreadable manifest, gap, missing base or failed record) and applied
  it through its manifest's `publishedHlcHigh`, with no post-restore sync or
  replace adoption still pending. That pull must also come from the sync backend
  in use now, be no older than the grace window (a device that stopped syncing
  must not keep deleting on what it knew then), and have started after the last
  restore. Otherwise the media sweep measures and defers. Each sync marks this
  device not caught up before it authenticates, so a sync that fails, halts or
  cannot sign in leaves it that way, and a sync that cannot write that mark does
  not run. The pull's result is recorded once the pull and the retirement sweep
  are done: a publish or cleanup that fails after a clean pull does not change
  which peer rows this device holds (and a full cloud fails every publish, while
  the cleanup is what frees the space). Every restore path (Settings and the
  startup screen) records the restore before it swaps the database, and a
  restore that cannot record it does not go ahead. Switching to another
  database (an existing one at a new location, or back to the default) records
  it the same way. The post-restore run therefore does its device part at once and
  its cloud deletes after the first reconciling sync completes.
- **A database that does not know the store deletes nothing from it:** the
  automatic cleanup and Reclaim delete only while the dive log has an active
  `media_stores` row (see Media store item 6), and no sweep deletes when no row
  references any media while the store holds objects (a fresh or reset dive log
  with the attachment still in place). Such runs measure and defer.
- **Only this library's store:** every sweep, Verify Library included, first runs
  the store-marker check the upload worker runs before each transfer. A detached,
  wiped or repointed store is not swept.
- **A run that may not delete does not repair either:** reverse repair clears
  synced upload stamps, so a deferred run skips it. Its view of which rows still
  need an object may be out of date.
- **Known limitation:** a device that shares the media store without database
  sync is invisible to this one. Its rows are not in the reference set, so its
  objects can be deleted after 7 days, or within hours under early delete, which
  counts only the devices this one knows of; that device's reverse repair
  re-uploads them from its local copy. Early delete makes this happen sooner than
  before; it does not fix it. Accepted (maintainer's call): the setup is rare,
  the cost is a re-upload rather than lost data, and early delete is what clears
  the leftovers of a restore and re-upload within hours.
- **Nothing deleted while work is in flight:** cloud media deletes wait while the
  transfer queue has a `transferring` row (a `pending` row's hash is already
  protected by the no-stamp rule, and a row stuck pending must not block cleanup
  forever);
  sync-folder work waits while `SyncCoordinator.busy`. A sweep that finds its area
  busy defers to the next opportunity rather than waiting. An automatic run skips
  the cloud part while a sync runs; Reclaim and Rescan still measure then, but
  delete nothing. A sync, a restore or a change of media store attachment that
  starts while a sweep is deleting stops the deletes, and that run counts as deferred: it neither stamps the fleet sweep
  nor clears the post-restore flag. That check starts before the store is
  connected, so a change during the connect counts too. Before each delete the
  sweep re-reads the rows for that hash, and keeps the object if they changed
  since its listing (an import that found the object already there, a quality
  switch). The cleanup and Verify Library never sweep at once: one waits for
  the other. The launch and resume runs start once the syncs those triggers
  start have ended, so they are not skipped for a sync they began beside. A post-restore device pass with a failed
  sweep stays pending, so the forced retry is not lost.
- **Never another device's in-progress files:** only this device's own superseded
  sync files and temp files; malformed or unexpected keys are skipped. A device
  file's age is the later of its modified and changed times, because a copy keeps
  the source's modified time on Apple platforms.
- **Unreadable is skip, not delete**, as in the shared library transport.

## Coordinator

One `StorageGcCoordinator` replaces the separate fire-and-forget storage blocks in
`StartupPage` (the scratch and local cache sweeps) and the auto-verify block in the
media store runtime provider. Two startup jobs stay where they are on purpose:
`sweepLeftoverSyncTempFiles` must run before the database opens, ahead of any
provider, and `MediaOrphanBacklogSweep` deletes unlinked media rows (through the
deletion coordinator), not files, so it is not a storage sweep. Each
area is a sweep with a common shape: what it can measure (bytes used, bytes
reclaimable now, bytes waiting on the grace window), how to reclaim, its cadence,
and its preconditions. Exact interface is the builder's call.

Schedule (approved):

- **Device sweeps:** at launch, at most once a day (local cache sweep keeps its
  weekly cadence inside that). An automatic pass in which a sweep failed is tried
  again after an hour, not on every resume.
- **Cloud scan and cleanup:** about weekly, unmetered network only, fleet-wide for
  the media store (the synced `media_stores.last_sweep_at` stamp of the store
  this device is attached to means one device does it for all). Measurement is per device (designer's call): each device lists
  the cloud areas on its own weekly, device-local cadence so every device has
  figures to show; when the device also wins the fleet cleanup, one listing serves
  both. Sync folder and shared library sizes are measured on the same scan; a
  measurement that takes over two minutes is dropped and the total marked
  partial, so a stalled call cannot hold the pass. A scan that only measures
  lists what the device already has on iCloud instead of refreshing the
  container, since the refresh starts downloading every evicted item; an
  evicted item that left a placeholder counts with no size, so the total reads
  as partial. The weekly
  fleet cleanup, which deletes and repairs, still refreshes, and reads a
  placeholder as the object it stands for (deleting it removes the
  placeholder). A media store that takes over a minute to connect fails that
  sweep rather than holding the pass.
- **After a restore:** an extra run of both, regardless of cadence (cloud still
  needs an unmetered network). A restore ends in a soft restart that does not
  re-run `StartupPage`, so trigger it from the post-restore path (for example the
  `PostRestoreSyncStore` pending flag or the restore notifier), not from launch.
- **Long-running sessions:** desktop apps stay open for days, so the coordinator
  also checks whether it is due on app resume and on a slow timer. Builder's call
  on the mechanism.
- **"Reclaim storage" button:** runs every sweep now, ignoring cadence and the
  unmetered-network requirement (approved: the diver asked for it, so it runs on
  cellular too), under the same safety rules (grace, early delete, caught up,
  in flight). No override of those. Rescan likewise runs on any network.
  Reclaim also runs the local cache sweep whatever its weekly stamp says.
- **Verify Library** (Media storage page) runs under the same gates as the
  cleanup, and its result shows on the Storage usage page.

Results of each run (per area: bytes and items reclaimed, time) are kept
device-locally (SharedPreferences). The cloud "last reclaimed" therefore shows what
this device reclaimed; a run done by another device is not shown. (Designer's
call.)

## Storage usage page (approved layout A)

Extend `StorageUsagePage`:

- **Header:** total, with a line splitting it into "on this device" and "in the
  cloud". Partial-total labelling applies when any area could not be measured.
- **Reclaim card** at the top: "About N can be reclaimed", "Last reclaimed X, <when>",
  a "Reclaim storage" button, progress while it runs, and a short result when done.
  When some cloud bytes are only waiting for the grace window, say so in one line
  rather than counting them as reclaimable. Bytes the cleanup holds back say
  what they wait on: a sync, uploads finishing, or reconnecting the media store
  (a dive log that never registered it); the Reclaim result and Verify Library
  name the same reason. Held-back bytes never count as reclaimable.
- **On this device:** the existing groups, unchanged, plus the reclaimable amount
  inline on rows that have one (temporary files, for example). The database row
  keeps its Compact row.
- **In the cloud:** new group with rows for media store, database sync and shared
  libraries, each with bytes used (and reclaimable for the media store only), and
  a "Scanned <when>, Rescan" line.
  Rescan runs the cloud measurement only (no deletes). Rows for areas the diver has
  not set up are hidden, but the group and its Rescan always show (approved
  follow-up), so an area connected since the last scan can be measured at once.
  "Set up" is checked now, not at the last scan: an area disconnected since
  drops out of the rows, the header and the reclaim card. Media figures carry
  the store they were measured on, and show only while that store is attached;
  a scan whose media listing fails keeps the last figures only if they are the
  same store's.

Cloud measurement:

- Media store: sum of `list()` sizes over `smv1/objects`, `thumbs`, `renditions`
  of the attached store, collected during the verify listing.
- Database sync: sum of `ssv1.*` sizes from `listFiles` on the active provider.
- Shared libraries: sum over joined libraries of the sized listings available
  (`listSites`, `listSuggestions`); members, keyslots and backups have no sized
  listing, so the figure is marked partial unless the builder adds sized listings.
  (Built: the measurement lists the library's own folders. It looks the
  optional suggestions and backups folders up without creating them, since
  creating writes on WebDAV, and counts a missing one as empty.)

Units follow the existing byte formatting. All strings go through l10n with every
ARB file updated.

## Left to the builder

- Coordinator and sweep interfaces, file layout, provider wiring.
- Duplicate-keep choice on Drive, clock-skew margin, the resume/timer mechanism.
- How measurement results are cached between page visits.
- Whether shared library backups and members get sized listings or stay partial.
