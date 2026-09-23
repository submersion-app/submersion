# Media Sync Program. Design

**Status:** approved in brainstorm 2026-09-18, awaiting spec review
**Branch:** `ericgriffin/media-sync-program`
**Builds on:** the 2026-07-10 S3 media storage design, the 2026-03-13
cross-device photo resolution design, the 2026-08-22 media verification
reachability design and the 2026-08-23 attached-or-absent design.
**Tracking:** issue #2090, with one sub-issue per slice in section 10
(#2091, #2094, #2097, #2100, #2103, #2108, #2113, #2116, #2121, #2126,
#2129, #2132).

## 1. Problem

Photo and video sync produces a steady stream of reports that each look
different to the user and each get fixed in isolation. The census taken on
2026-09-18 (181 open issues, 565 closed since June) found these.

Open and genuinely about media sync:

| Issue | Symptom | Layer |
| --- | --- | --- |
| #425 | Mac and iPhone on one iCloud Photo Library; each device sees only the photos it linked itself. Retested 2026-08-11, still failing. | Resolution |
| #1937 | Match gallery photos across devices by PhotoKit cloud identifier. The durable fix for #425 on Apple. | Resolution |
| #1625 | Android says "media not available" for a photo that was never moved or deleted. Undiagnosed. | Resolution |
| #2018 | Google Drive transfer errors show a bare HTTP status. | Media store |
| #1954 | Deleting a diver leaves their media detached and unsynced. | Row sync |
| #1738 | Dropbox app frozen pending review. External to the code. | Media store |

Closed by a workaround rather than a fix, so the class will recur:

- #1968: a tile showed "from another device" and was fine a few minutes
  later. The store fallback was waiting on upload stamps that a sync had
  dropped or not yet delivered.
- #1661: "cannot read the library epoch marker" after adding media; the
  reporter disconnected and reconnected the store.

Fixed since June, and the regression history this program must not repeat:
#885, #1210, #1270, #1279, #1356, #1370, #1409, #1531, #1638, #1961, #2016.

Known and unfiled until now:

- Any local write to a `media` row between two syncs makes the engine skip
  the peer's whole update for that row, and the changeset cursor still
  advances, so a peer's upload stamps can be dropped permanently.
- The media store runtime drains only once something reads it, and a tile
  reads it only once the row is already confirmed uploaded. Desktop apps that
  sit in one process for days expose the loop; mobile lifecycle churn hides it.

Media sync is three systems that the user experiences as one feature:

1. **Row sync.** The `media` table and its children (`mediaEnrichment`,
   `mediaSpecies`, `mediaStores`) travel through the changeset engine.
2. **Resolution.** Device B re-finds the bytes in its own photo library or on
   its own disk, through `AssetResolutionService` and the resolver registry.
3. **Media store.** Content-addressed copies in S3, Google Drive, Dropbox or
   iCloud, drained by `MediaStoreWorker` from `media_transfer_queue`.

Almost every report above is a failure at a handoff between two of them.
This program treats the handoffs as the unit of work.

## 2. Locked decisions

Made during the brainstorm on 2026-09-18, in this order:

1. **Scope is end to end.** A photo linked on device A shows, with bytes, on
   device B, on every platform pair; transfers never wait silently; deletes
   propagate.
2. **The plan lives in a spec plus a tracking issue.** This document, then
   one tracking issue with a sub-issue per slice. Every PR links its slice.
3. **Harness and diagnostics come first.** No behaviour fix ships before a
   two-device harness scenario reproduces the seam it closes.
4. **The merge rule change is engine-wide.** "Merge and keep pending"
   replaces "skip while pending" for every synced entity, not only `media`.
   Each entity declares its device-stamped fact columns; only the media
   tables declare any today.
5. **Deleting a diver cascades their media** the way single dive, site and
   gear deletes already do. Originals are never touched.
6. **The cloud identifier ships in this program**, not as a later slice.
7. **Facts carry their own clocks** (decided 2026-09-19, while planning
   Phase 1). Upload stamps are legitimately cleared (Verify Library, a
   quality override, repair), so a "non-null always wins" rule would
   resurrect cleared stamps. Instead `media` gains two synced clock columns,
   one per fact group; fact writes stamp their group clock and never the
   row clock, and each group merges last-writer-wins by its own clock.

Product rules carried over unchanged: Submersion never deletes a user's
original photo or video; a media row is attached to a dive or a site or it
does not exist; Live Photo metadata writing stays unsupported.

## 3. Where the seams are today

File references are to main at `f3094a71228`. Line numbers will drift; the
symbol names will not.

### 3.1 Row sync

- `media`, `mediaEnrichment`, `mediaStores` and `mediaSpecies` are
  registered `hasUpdatedAt: false` in `lib/core/services/sync/sync_service.dart`
  and take the blind-upsert path: no last-writer-wins, no conflict card,
  the last copy to arrive owns the whole row.
- All four carry an `hlc` column and are HLC-gated on export
  (`SyncRepository.hlcTargets`, `_exportMedia(hlcSince)`), but none is in
  `parentGatedChildEntities` in `sync_data_serializer.dart`, so the
  stale-copy guard in `_mergeEntity` never runs for them. An older snapshot
  from device B overwrites device A's newer `remoteUploadedAt` and
  `isOrphaned` with no detection.
- `_mergeEntity` skips any inbound record whose id is in `pendingRecordIds`.
  `ChangesetReader` records `appliedThrough = seq` after `apply` returns and
  upserts the peer cursor, so the skipped record is never replayed. Pending
  marks clear only after a publish. The peer re-sends the row only on its own
  next clock-bumping edit.
- `media` rows are marked pending by many non-user paths in
  `MediaRepository`: `markOrphaned`, `markVerified` (called per grid tile by
  `MediaItemView`), `stampVerification` (called by `MediaItemVerifier` for
  every outcome, including inconclusive), `republishForSync`, the five upload
  stamp and clear methods, and the relink and unlink cascades. A "Check all"
  on device B marks the whole library pending and guarantees the skip.
- `mediaStores` has no `parentRefs` entry. `mediaEnrichment` and
  `mediaStores` are never tombstoned; they rely on the FK cascade, which
  writes no deletion-log entry, so a peer re-adds them on its next publish.

### 3.2 Resolution

- Tier order in `AssetResolutionService`: `local_asset_cache` hit; unexpired
  `unresolved` entry (short-circuit to unavailable); original
  `platformAssetId` probe; permission gate; filename plus timestamp; exact
  second plus dimensions; two-second window plus dimensions; cache
  `unresolved` with a 24 hour, 3 day, 7 day backoff.
- `LocalFileResolver` upgrades `notFound` to `fromOtherDevice` when
  `originDeviceId` is another device. `PlatformGalleryResolver` does so only
  on Windows and Linux (`hasPhotoLibrary: false`). On iOS, macOS and Android
  it never answers `fromOtherDevice`; every failed search is `notFound`.
- `notFound` is the only verdict `MediaOrphanReconciler` turns into an
  `isOrphaned = true` write, through `markVerified` and `stampVerification`.
  That write syncs. A peer can therefore orphan a row on every device.
- On Android, `PhotoPermissionStatus.limited` is admitted as full access, so
  a photo outside the user's selected subset produces an empty candidate set,
  an `unresolved` cache entry, and a synced orphan flag. Content-URI grant
  loss and MediaStore id churn after an OS update reach the same path on the
  origin device itself.

### 3.3 Media store

- `MediaItemView.storeConfirmed` requires `contentHash` plus one of the
  three remote-upload stamps. Without them the tile never constructs the
  store runtime and renders the anonymous "From another device" placeholder.
  `UnavailableData.originDeviceLabel` exists and is rendered when set, but no
  producer sets it.
- `MediaStoreWorker.drain` leaves rows `pending` with no error and no
  wakeup when: the preflight throws (suspension is not recorded); the
  per-entry budget expires (defer with no reason); a `delete` entry meets no
  processor (silent defer loop); rows stranded in `transferring` are
  reclaimed by a process-cached provider that may run after the first drain;
  or the queue holds only deferred rows so the resume gate never builds a
  runtime. The Transfers page shows "Pending" with no reason for all five.
- Store identity is `StoreMarker.storeId` alone; the epoch lives in the sync
  layer. A marker mismatch or epoch failure surfaces as a log line and a
  stuck queue, and clears only on a manual disconnect and reconnect.
- `GoogleDriveMediaObjectStore._forStatus` drops the response body. S3 and
  Dropbox forward their client's message. iCloud raises fixed strings.

### 3.4 Deletion

- Dive, site and equipment deletes partition media into "linked only here"
  (deleted through `MediaDeletionCoordinator` with tombstones and a
  blob-delete intent) and "linked elsewhere" (unlinked, stamped, pending).
- `DiverRepository.deleteDiverWithReassignment` has no media step. The
  diver's media dies by SQLite cascade with no tombstone and no blob-delete
  intent, or survives detached when the FK is `SET NULL`.

### 3.5 Diagnostics

- The Media info panel shows source type, "Linked on: this device or another
  device" without a name, found or missing, last checked, backup tier and
  queue state.
- Verify Library reports counts only, with no per-item detail.
- The debug log export has no media category, and the file floor is
  `warning` outside debug mode, so every resolver and worker breadcrumb is
  absent from an ordinary user's export.

### 3.6 Tests

No test simulates two devices exchanging a media row and its stamps. The
sync round-trip test pushes one media row through the serializer only.
Resolver, reconciler, verifier, cache and store-gate tests each cover one
layer with fakes on both sides.

## 4. Phase 0: foundations

### 4.1 Two-device harness

`test/helpers/two_device_media_harness.dart` builds two complete devices in
memory:

- two `AppDatabase` instances and two `LocalCacheDatabase` instances;
- one shared in-memory sync backend, reusing the fake the sync tests already
  use, so publish and pull run the real `SyncService` code;
- one shared `InMemoryMediaObjectStore` with one `StoreMarker`, so the real
  upload pipeline, preflight and `MediaStoreResolver` run;
- per-device fake photo libraries and file systems, distinct device ids and
  display names, and a per-device resolver registry built from the
  production factory with the fakes injected.

The API reads like the user's story:

```dart
final h = await TwoDeviceMediaHarness.create();
final id = await h.a.linkGalleryPhoto(bytes, takenAt: t, dims: (4032, 3024));
await h.sync(h.a);
await h.sync(h.b);
await h.drain(h.a);
await h.sync(h.a);
await h.sync(h.b);
expect(await h.b.tileState(id), TileState.storeConfirmed);
expect(await h.b.bytes(id), bytes);
```

Also exposed: `linkFile`, `verifyAll`, `checkTile`, `healthReport`,
`deleteDive`, `deleteDiver`, `setPermission(limited)`, `advanceClock`,
`killDuringTransfer`. The harness is a test helper, never production code,
and its scenarios run in the affected-directory shards like any other test.

Seed scenarios, each written to fail on main before its fix lands:

| Id | Scenario | Closes the seam in |
| --- | --- | --- |
| S1 | B marks a row pending (tile reconcile), A's upload stamps arrive in the same pull; stamps must survive. | 5.1 |
| S2 | B runs "Check all" on a healthy library; no row may become pending. | 5.2 |
| S3 | A's older snapshot arrives after B's newer stamps; newer stamps survive. | 5.1 |
| S4 | A's stamps never arrive (simulated drop); B attached to the same store still shows the photo. | 7.2 |
| S5 | B cannot find A's gallery photo; B's row must read `fromOtherDevice`, and A's row must not become orphaned. | 6.1 |
| S6 | Burst pair on A, same second and size; B resolves both by cloud id. | 6.2 |
| S7 | Android B with limited access; the photo outside the subset must not be orphaned. | 6.3 |
| S8 | Preflight throws on A; the queue reports suspended with a reason and resumes when the preflight passes. | 7.1 |
| S9 | Diver deleted on A; B ends with no detached media rows and a blob-delete intent per store-backed original that was linked only to that diver. | 5.4 |
| S10 | A killed mid-transfer; on relaunch the stranded row is retried before the first drain. | 7.1 |

### 4.2 Media health report

`MediaHealthReport` (`lib/features/media/data/services/media_health_report.dart`)
produces, per media row or for the whole library, both a plain-text and a
JSON document with:

- media id, source type, original filename, `takenAt`, dive or site link;
- origin device id and display name, and whether that is this device;
- synced facts: `contentHash`, `contentSizeBytes`, the three remote-upload
  stamps, `isOrphaned`, `lastVerifiedAt`, `hlc`, and whether a pending sync
  record exists for the row;
- local cache verdict: resolved id and method, or `unresolved` with attempt
  count and next retry time;
- resolver verdict on this device, run fresh, with the `UnavailableKind`;
- store verdict: attached store id, marker id read from the store, and, for
  a single-row report only, whether the object exists in the store;
- transfer queue entry state, attempt count, next attempt, waiting reason and
  error message.

Entry points: a "Copy diagnostics" action on the Media info panel (single
row); an "Export media report" action on the Media Storage page (whole
library, written to a file and shared through the platform share sheet);
and inclusion of the whole-library report in the existing debug log export.
The export dialog states that the report contains file paths and device
names. Nothing in the report is sent anywhere by the app.

### 4.3 Log plumbing

- `LogCategory.media` (short label `MED`) joins the enum; the debug log viewer
  gets its filter chip through the existing `log_category_display.dart`.
- `LoggerService` gains a per-category file floor; `media` is written at
  `info` and above regardless of debug mode. The existing rotation bounds
  the size.
- `AssetResolutionService`, the resolvers, `MediaStoreWorker`,
  `MediaStorePreflight` and the upload pipeline log under the new category.

### 4.4 Named origin device

A producer for `UnavailableData.originDeviceLabel`: the resolver registry
resolves `originDeviceId` to the display name from the sync device registry
(the source of the names shown on the Devices page) and falls back to the
existing anonymous string. The Media info panel's "Linked on" row shows the
same name.

## 5. Phase 1: row sync

### 5.1 Merge and keep pending

`_mergeEntity` stops skipping a record whose id is pending whenever both
the local row and the peer's copy carry a clock: the entity's ordinary
resolution orders them, and the local pending mark is kept, so this device
still publishes whatever wins. Where either clock is missing nothing can
order an unpublished local edit against the peer's, so the skip stays. Only
three merged entities have no clock at all (`diveProfiles`,
`tankPressureProfiles`, `equipmentFindings`); every other entity carries
one. This fixes a divergence that is not specific to media: today a peer's
newer edit to a dive, buddy or site is dropped while the local row is
pending, and the peer then refuses this device's older copy.

`media`, `mediaEnrichment`, `mediaSpecies` and `mediaStores` join the
stale-copy guard the parent-gated children use: a copy strictly older than
the local row is refused, a tie or a missing clock applies. They join
through their own set, not `parentGatedChildEntities`, because that set also
drives the pending-children export and media rows export on their own
clock.

A fact is a device-stamped observation rather than a user edit. Facts come
in groups, and each group has its own synced clock column on the row:

| Group | Clock column | Columns |
| --- | --- | --- |
| Upload facts | `upload_facts_hlc` | `contentHash`, `contentSizeBytes`, `remoteUploadedAt`, `remoteThumbUploadedAt`, `remoteCompressedUploadedAt`, `compressedLevel`, `compressedSizeBytes` |
| Verification facts | `verify_facts_hlc` | `isOrphaned`, `lastVerifiedAt` |

- A fact write stamps its group clock and marks the row pending; it never
  moves the row clock, so a stamp written after a caption edit cannot make a
  stale caption win.
- The rest of the row (links, caption, `takenAt`, source pointer and so on)
  merges by the row clock as above. Each fact group then merges on its own:
  the side with the newer group clock supplies every column of the group,
  including explicit nulls, so a cleared stamp propagates.
- A missing group clock falls back to that side's row clock. Rows written
  by an older app version stamp facts through the row clock, so they still
  order correctly against new ones, and rows that predate the columns behave
  exactly as today.
- The v224 rung backfills both clocks from the row clock for existing rows,
  and a new row stamps both at creation, so later user edits do not move a
  fact group's effective clock.
- The media upsert drops explicit nulls (`nullToAbsent`), so the merge writes
  each winning fact group with a targeted update that sets nulls too.
- Export selects a media row when its row clock or either fact clock is past
  the watermark, and the published watermark counts fact clocks, so a
  fact-only change is published once and not again.

The implementation plan enumerates every entity the pending change touches
and the harness gains one scenario per distinct policy, not per table.

`ChangesetReader` is unchanged: once nothing is skipped that can be ordered,
advancing the cursor after `apply` is correct.

### 5.2 Quiet verification

- The verification writers publish only when `isOrphaned` actually moves.
  `lastVerifiedAt` is set to "now" on every check, so including it would
  mean every check publishes, which is the thing this section exists to
  stop. The date is recorded locally without a clock, and it STAYS local
  until something stamps the verification group, which only a real flag
  change does: a later row edit moves the row clock, and the merge compares
  each fact group on its own clock, so a peer with an equal or newer
  verification clock keeps its own date. A peer can therefore show an older
  "last checked" indefinitely for a row whose every check confirms what it
  already said. The media health report shows this device's own value,
  which is the one a support thread needs. (Amended 2026-09-19 while
  planning slice 4; the "reaches peers on the next sync-visible write"
  wording was corrected 2026-09-20 after review showed the merge discards
  it.)
- Inconclusive verifier outcomes (`fromOtherDevice`, `accessDenied`, no
  resolver, throw) never write the row.
- `MediaItemView` reconciles only when the resolver verdict is `notFound` on
  the origin device, per section 6.1.

### 5.3 Hardening

- `mediaStores` needs no `parentRefs` entry: the table declares no foreign
  keys, and `sync_parent_refs_completeness_test` reads the live schema, so
  it already demands an entry the moment one appears. It needs no tombstone
  either: no local path deletes a descriptor, and Disconnect deliberately
  keeps it so other devices still learn the store exists. Both facts are
  pinned by `media_stores_no_parent_refs_test`, which fails with the reason
  if either changes. (Corrected 2026-09-19, while planning slice 4; the
  original bullets described work that does not apply.)
- `mediaEnrichment` deletions already log a tombstone wherever they are
  deliberate. The gap is the FK cascade: a photo that survives a dive
  deletion because a site still shows it loses its dive-scoped enrichment
  silently, and a peer re-adds it on the next publish. The dive-unlink path
  drops those rows explicitly, with tombstones, before the dive rows go.
- Google Drive: `_forStatus` folds Google's `error.message` into the
  exception text when the body parses as that shape, otherwise the bare
  status (#2018). The S3, Dropbox and iCloud adapters are checked for the
  same gap in the same PR.

### 5.4 Diver delete (#1954)

`deleteDiverWithReassignment` gains the same media partition the single
entity deletes use, computed before the transaction and applied through
`MediaDeletionCoordinator` after it: media linked only to the diver's dives,
sites and gear is deleted with `media` and `mediaEnrichment` tombstones and
a blob-delete intent for anything store-backed; media also linked to a
surviving row is unlinked, stamped and marked pending. Originals are never
touched. #1957 (the rest of the diver delete) stays its own issue; the two
PRs coordinate on the transaction boundary.

## 6. Phase 2: resolution

### 6.1 Origin-aware verdicts on every platform

`PlatformGalleryResolver` on iOS, macOS and Android adopts the rule
`LocalFileResolver` already follows: when the original id probe and every
metadata tier fail on a row whose `originDeviceId` is another device, the
verdict is `fromOtherDevice`, never `notFound`. `notFound` is reserved for
the origin device, and only with full library access. The reconciler and
verifier are unchanged; they already treat `fromOtherDevice` as
inconclusive. The effect is that a peer can degrade a tile but never the
row.

Rows with a null `originDeviceId` need an origin before this rule can
apply to them, and today nothing provides one: gallery rows are inserted
with a null origin by design (`MediaRepository._effectiveOriginDeviceId`
returns null for `platformGallery`), and the origin republish sweep only
selects rows this device already owns. Slice 7 therefore adds two things:
gallery links stamp the linking device's id at insert from then on, and a
one-time origin backfill stamps this device's id (a narrow write, one clock
bump) on every null-origin row that resolves natively here. Until a row has
an origin it keeps today's behaviour on the device with a cache hit for it
and answers `fromOtherDevice` elsewhere.

### 6.2 PhotoKit cloud identifier (#1937)

- Schema: a synced, nullable `cloud_asset_id` text column on `media`, added
  at the next schema rung with a `beforeOpen` backstop, mirroring the
  `originDeviceId` rung.
- Stamp at link time on iOS and macOS through
  `AssetEntity.darwin.cloudIdentifier`; null when iCloud Photos is off or
  the OS is too old.
- Resolution: the candidate set the metadata tiers already fetch for the
  photo's time window gets its cloud ids in one
  `PhotoManager.plugin.getCloudIdentifiers` call; a match on cloud id wins
  before any metadata tier and is cached in `local_asset_cache` with method
  `cloud_id`.
- Backfill: the origin republish sweep, on a device whose `platformAssetId`
  still loads, reads cloud ids in batch and stamps rows that lack one.
- Cache invalidation: when a sync applies a new `cloud_asset_id` or new
  upload facts to a row, its `unresolved` cache entry is deleted, so the
  next view retries instead of waiting out the backoff.

### 6.3 Android (#1625)

- `PhotoPermissionStatus.limited` becomes an inconclusive verdict
  (`accessDenied` with a `limited` reason) rather than full access. The
  tile's placeholder offers "Allow full access" and "Choose photo again".
- On the origin device, content-URI grant loss and a failed original id
  probe re-run the metadata tiers before anything is `notFound`.
- A `checkPermission` platform-channel throw stays `accessDenied` but is
  logged under the media category with the exception, so the health report
  shows it.
- Reproduction plan: ask the #1625 reporter for a single-row health report;
  reproduce on the maintainer's Android phone with limited access, with a
  moved file, and across an OS re-index.

### 6.4 #425

The reporter's last retest (2026-08-11) predates the tier-matcher fixes that
shipped in v1.7.5. Actions, in order: ask for a retest on the current build
with a health report for one photo from each device; ship 6.1 and 6.2;
verify on the maintainer's Mac and iPhone against a shared library, including
a burst pair, before asking the reporter to confirm.

## 7. Phase 3: media store

### 7.1 The queue never waits silently

- A preflight throw records suspension with a reason; the Transfers page
  and the Media Storage summary row show the existing suspended notice with
  that reason; the retry window is armed as today.
- A per-entry budget expiry writes a waiting reason on the entry.
- A `delete` entry with no processor is marked failed with a message rather
  than deferred.
- Stranded `transferring` rows are reclaimed before the first drain and
  again on every resume, by making the reclaim part of `drain` rather than a
  process-cached provider.
- The resume gate arms a wakeup for a queue that holds only deferred rows.
- A marker mismatch or epoch failure raises the existing pending-setup card
  with a one-tap reconnect, and the queue's suspended notice names it.

### 7.2 Store gate probe

When a tile's verdict is `fromOtherDevice` and this device is attached to a
media store, the tile probes the store for the row's `contentHash` once per
row per session, negative-cached in memory, and falls back to the store when
the object exists. Section 5.1 makes lost stamps rare; this makes a late or
lost stamp cosmetic.

## 8. Phase 4: verification matrix

A manual checklist committed as
`docs/superpowers/specs/2026-09-18-media-sync-manual-test-checklist.md`,
in the style of the Google Drive checklist. Each row is a harness scenario
first and a hardware pass second:

| Pair | Store | Cases |
| --- | --- | --- |
| Mac and iPhone, shared iCloud Photos | iCloud, then S3 | gallery photo each way, burst pair, video, Check all on the peer, delete dive on the peer |
| Android and Windows | S3, then Google Drive | gallery photo from Android, file from Windows, limited access on Android, kill mid-upload |
| Linux as a pure peer | S3 | every foreign row reads from the store, no file dialog, health report exports |

The matrix passing on hardware is the exit criterion for the tracking
issue.

## 9. Error handling and safety

- No slice deletes, moves or rewrites a user's original file.
- The merge rule never discards a non-null upload fact; the worst case of a
  wrong merge is a redundant re-upload, which the head-dedup already skips.
- Orphan flags are written only by the origin device with full access; every
  other device can only show a placeholder.
- Every new background path that consults the picker or photo library checks
  `supportsGalleryBrowsing` first, so Windows and Linux never open a dialog.
- The health report is generated on demand, written only where the user
  chooses, and never transmitted by the app.

## 10. Slices and tracking

One tracking issue, "Media sync program", with this checklist. Each entry
becomes a sub-issue and one PR. Dependencies run top to bottom.

1. Two-device harness with scenarios S1 to S10 marked as expected failures
   where main is wrong. (4.1)
2. Media health report with its three entry points, `LogCategory.media`,
   per-category file floor, named origin device. (4.2 to 4.4)
3. Engine merge rule: merge and keep pending where both sides are clocked,
   media tables join the stale-copy guard, two fact clocks (schema v224),
   fact writers stamp their group clock. Turns S1 and S3 green. (5.1)
4. Quiet verification: an inconclusive check writes nothing, and a
   verification publishes only when the orphan flag moves. Tombstone the
   enrichment a dive deletion takes with it. Turns S2 green. (5.2, 5.3)
5. Google Drive error message and adapter audit. Closes #2018. (5.3)
6. Diver delete media cascade. Turns S9 green. Closes #1954. (5.4)
7. Origin-aware gallery verdicts on iOS, macOS and Android. Turns S5 green. (6.1)
8. PhotoKit cloud identifier: schema, stamp, resolve, backfill, cache
   invalidation. Turns S6 green. Closes #1937. (6.2)
9. Android limited access and origin-device re-resolution. Turns S7 green.
   Closes #1625 once reproduced. (6.3)
10. Queue visibility: suspension reason, waiting reasons, delete failure,
    reclaim in drain, deferred-only wakeup, marker card. Turns S8 and S10
    green. (7.1)
11. Store gate probe. Turns S4 green. (7.2)
12. Verification matrix checklist and hardware pass. Closes #425 on
    confirmation. Closes the tracking issue.

Existing issues stay open until the slice that closes them merges and, for
#425 and #1625, until the reporter or the hardware pass confirms. #1738 is
listed on the tracking issue as an external blocker with no code slice.

## 11. Out of scope

- The photo picker selection reset (#1996, PR #2082) and every picker,
  viewer, tagging and album feature request from the census.
- The media viewer analysis cascade freeze, which is not a sync problem.
- Lightroom and network-source pipelines beyond what the merge rule covers.
- Backfilling from device B a photo that only device A could ever read.
  When A is gone and never uploaded, the health report says so; nothing can
  recover the bytes.
- Dropbox's developer-console review (#1738).

## 12. Open assumptions

Stated here so the implementation plan can verify them first:

- The sync tests' in-memory backend can host two `SyncService` instances
  against one store without process-global state. If not, slice 1 adds a
  fake that can.
- `photo_manager` 3.12.0's `getCloudIdentifiers` returns ids for the whole
  candidate batch in one call on both iOS and macOS. If it is per-id, the
  window query bounds the cost and slice 8 measures it.
- The device display names shown on the Devices page are available on
  every device that has synced at least once. Rows from a device that never
  published a name fall back to the anonymous string.
