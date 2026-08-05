# Media Store Orphan Prevention - Design

Date: 2026-07-23
Status: Approved

## 1. Problem

A user's cloud media storage accumulates orphaned artifacts that consume
storage indefinitely. Two compounding layers:

**Layer 1 - orphan rows create artifacts that should never exist.** Dive
deletion (`deleteDive` / `bulkDeleteDives` in
`lib/features/dive_log/data/repositories/dive_repository_impl.dart`) deletes
only the dive row; the `media.dive_id` FK is `ON DELETE SET NULL`, so media
rows survive unlinked. `MediaRepository.getBackfillCandidateIds()` has no
linkage filter, so "Upload library" uploads these non-logbook bytes to the
user's cloud store and HLC-stamps the rows into sync, propagating them
fleet-wide. Confirmed in a debug DB: 369 media rows / 3 dives / 1 linked
photo; 83 backfill candidates, matching the transfer queue exactly.

**Layer 2 - deleted rows leak their blobs forever.** No deletion path
(`deleteMedia`, `deleteMultipleMedia`, dive deletion, sync tombstone
application) ever calls `MediaObjectStore.delete()`. Once uploaded, objects
under `smv1/objects/`, `smv1/thumbs/`, and `smv1/renditions/` are immortal.
Additionally, the S3 adapter's `_putMultipart` catch block rethrows without
aborting the in-flight multipart session; raw S3 buckets have no default
`AbortIncompleteMultipartUpload` lifecycle rule, so stranded parts bill
forever and are invisible to normal listings.

These layers interact: fixing dive deletion to remove media rows (Layer 1)
without remote-delete plumbing (Layer 2) converts row-orphans into
blob-orphans one-for-one. This design covers both, sequenced to avoid that.

This is the general-deletion/GC/verify scope originally deferred as Media
Store Phase 5 (spec `2026-07-10-s3-media-storage-design.md` section 12),
extended with the rendition namespace (which postdates that spec) and the
orphan-row root cause.

## 2. Locked decisions

- Unified design covering both layers, delivered as four sequenced PRs.
- Dive deletion cascades to its media rows. Media also linked to a site
  survives with `diveId` nulled; dive-only media is deleted and tombstoned.
- Existing orphan-row backlog: silent one-time sweep (no user confirmation),
  run at startup through the repository layer, not inside `onUpgrade`.
- Verify Library sweep: manual settings action plus opportunistic automatic
  runs (at most every 30 days fleet-wide, unmetered network only).
- Remote blob deletes ride the existing `media_transfer_queue` as a new
  `delete` operation kind (durability, retry/backoff, worker gate, and
  Transfers-page visibility for free).

## 3. Shared orphan predicate

A media row is *unlinked* when `dive_id IS NULL AND site_id IS NULL`. This
predicate is defined once in `MediaRepository` and shared by backfill
scoping, the dive-deletion cascade decision, and the backlog sweep, so the
three can never drift apart.

**Verification gate - RESOLVED 2026-07-23 (amended this section and 4.2 /
4.3).** The codebase audit found that bare unlinkedness is NOT a safe
deletion predicate; the remedy below is the source-type exclusion this
gate pre-authorized:

- **Library-level source types are legitimate without linkage.** URL-tab
  imports (`sourceType = 'networkUrl'`) and manifest-subscription imports
  (`'manifestEntry'`) are created with neither dive nor site and stay that
  way whenever auto-match is off or no confident timestamp match exists -
  `network_fetch_pipeline.dart` documents "auto-match is additive; the
  imported row stays library-level." These rows carry their own linkage
  (`url`, `subscriptionId`/`entryKey`) and are user-visible. The cascade
  and the backlog sweep must both treat
  `source_type IN ('networkUrl', 'manifestEntry')` as protected: never
  deleted for being unlinked; on dive deletion they revert to
  library-level (dive_id nulled) instead of dying.
- **All other creators always set diveId at creation** (gallery scan, OCR
  import, Files tab, Lightroom, signatures), so a null/null row of a
  non-library source type can only be the residue of a past dive deletion
  - exactly the backlog this design targets. This includes signature rows
  (`fileType` instructor/buddy signature): their dive is gone, and under
  the approved cascade semantics they die with it.
- **Buddy / diver / gear / certification / site images do not use the
  media table** (own `photoPath` / BLOB columns) - not affected.
- **Age guard retained as belt-and-suspenders:** the sweep additionally
  requires `created_at` older than 24 hours, covering any future
  add-then-link creator this audit could not foresee.

The *sweepable* predicate is therefore: unlinked AND
`source_type NOT IN ('networkUrl', 'manifestEntry')` AND older than 24
hours. Sweepable-ness is defined beside `isLinkedToDiveOrSite` in
`MediaRepository` so cascade and sweep share one definition.

## 4. Layer 1 - row fixes

### 4.1 Backfill scoping

`getBackfillCandidateIds()` gains `dive_id IS NOT NULL OR site_id IS NOT
NULL` on both the photo arm and the video arm. Placed in the query, not the
service loop, so any future caller inherits it. This also removes the latent
widening: broadening the video arm's source types can no longer pull in
hundreds of unlinked gallery videos.

### 4.2 Dive-deletion cascade

Inside `deleteDive` / `bulkDeleteDives`, for each media row linked to the
dive:

- `site_id` also set, OR a protected library source type
  (`networkUrl` / `manifestEntry`): keep the row, explicitly null
  `dive_id` (today's FK behavior, now intentional) and HLC-stamp the
  update so the unlink syncs.
- Otherwise (dive-only, non-library): enqueue a remote-delete intent
  (section 5) before the row dies, then delete the row and
  `logDeletion(entityType: 'media', ...)` so the deletion tombstones and
  syncs.

Caller audit note: dive merge and consolidation services reassign media to
the surviving dive BEFORE calling `bulkDeleteDives`, so the cascade sees no
dive-only media for merged-away dives; this ordering is asserted by
regression tests in PR 3.

### 4.3 One-time backlog sweep

Deletes rows matching the *sweepable* predicate from section 3 (unlinked
AND non-library source type AND older than 24 hours), enqueueing
remote-delete intents for rows with remote stamps. Runs once at first launch
after
upgrade, through `MediaRepository` (proper HLC-stamped tombstones and
remote-delete intents require live sync machinery that does not exist during
`onUpgrade`), guarded by a persisted completion flag. The flag is set only
on successful completion, giving at-least-once execution; tombstones and
remote deletes are idempotent, making at-least-once safe. Each device sweeps
its own rows independently; duplicate tombstones for the same row are
idempotent in the deletion log.

## 5. Layer 2 - remote blob deletion fast path

### 5.1 Queue `delete` operation (local cache DB v6)

*(As built in PR 2 #702.)* Delete intents ride the queue's existing
`direction` column (`'delete'`; the column and `content_hash` existed
unused since Phase 1), so v6 adds only one nullable `payload_json` column
holding `{"originalExt": ..., "renditionExt": ...}` - the two facts
unrecoverable after the media row dies (the v4 `from >= 2` guard idiom
applies to the migration).

One delete entry covers all tiers of one hash, idempotent per hash: at
drain time it issues idempotent deletes for the original, thumb, and
rendition keys derived from the hash via `StoreKeys`.

### 5.2 Enqueue-before-delete ordering

The queue lives in `submersion_local.db`, a different database from the
media table; no cross-database transaction exists. Ordering resolves the
crash windows: enqueue the delete intent first, then delete the media row.
A crash between the two leaves an intent whose drain-time refcount check
(5.3) sees the row still alive and no-ops. The reverse order has an
unfixable leak window.

### 5.3 Drain-time refcount, maximally conservative

Before deleting, the worker checks whether any media row with this
`content_hash` still exists - uploaded or not. Any hit: mark the entry done
without deleting. This is deliberately broader than Phase A's
`countRowsWithOriginal` (remote-stamped rows only): skipping a delete is
free, and the broad check removes a class of races. Checking at drain time
means references that appear between enqueue and drain (for example a sync
pull landing a row from another device) win.

### 5.4 Single-enqueuer rule

Only the device where the user performed the deletion enqueues remote
deletes. Devices applying the same deletion via sync tombstone do not.
Avoids N-device delete storms; a missed delete (deleting device dies before
draining) falls to the sweep.

### 5.5 S3 multipart abort

- `_putMultipart`'s catch block aborts the in-flight `uploadId` unless
  resume state was successfully persisted for retry. Resumable failures keep
  their session; unresumable ones abort immediately.
- When a queue entry reaches terminal `failed` or is removed (`deleteDone`,
  user dismissal), any persisted `uploadId` in its resume state gets a
  best-effort abort.
- The sweep backstops both via `ListMultipartUploads` (section 6.1).

Dropbox and Google Drive upload sessions self-expire server-side; no client
work needed.

### 5.6 Network gating

Delete drains bypass the Wi-Fi-only policy gate (tiny API calls, no
payload) but respect the offline gate: no network, no drain, the entry
waits.

## 6. Verify Library sweep

### 6.1 Sweep algorithm

For each namespace (`smv1/objects/`, `smv1/thumbs/`, `smv1/renditions/`):

1. Stream `MediaObjectStore.list()` (implemented by all four adapters;
   currently unused).
2. Build the referenced-hash set from the media table - any row with a
   `content_hash`, uploaded or not (same conservative rule as 5.3).
3. Delete objects whose hash is unreferenced AND whose `lastModified` is
   older than a 7-day grace window. Younger objects are skipped: they may
   belong to rows still in flight from an unsynced device.
4. S3 only: `ListMultipartUploads`; abort sessions older than 7 days.
   Requires one new operation on `S3ApiClient` (listing multipart uploads;
   abort already exists for resume validation).

### 6.2 Reverse repair

While listing, the sweep also checks the opposite direction: media rows
whose remote stamps are set but whose object is absent from the listing get
the stale stamp cleared; if local bytes resolve, a re-upload is enqueued.
This heals the benign single-enqueuer race (5.4) and makes the feature
verification, not just garbage collection.

### 6.3 Manual trigger

"Verify library" action on the Media Storage settings page with progress and
a completion summary: objects checked, orphans removed, bytes reclaimed,
sessions aborted, repairs queued. All strings localized across the 11 arb
locales.

### 6.4 Opportunistic automatic runs

All conditions required: at least 30 days since the last fleet-wide sweep,
unmetered network, media store attached and reachable. The last-sweep
timestamp is a new column on the synced `media_stores` table
(`last_sweep_at`, schema v136 - the only main-DB schema change in this
design), so one device's sweep counts for the whole fleet. Auto-runs use the
identical code path as manual runs, without foreground progress UI. The
timestamp is stamped only on successful completion.

### 6.5 Race analysis

- Unsynced new rows on another device: protected by the 7-day grace window;
  sync converges far faster than the window.
- Local references appearing mid-flight: protected by drain-time refcount.
- Blob deleted while an unsynced row referenced it: healed by reverse
  repair (re-upload from local bytes).
- Stale restore holding fleet-deleted rows: makes the sweep keep blobs
  others deleted - conservative, harmless, self-corrects when the restore
  problem itself is resolved.
- No unrecoverable state exists while any device holds local bytes; when
  none does, the media was already unrecoverable before the sweep ran.

## 7. Error handling

| Failure | Behavior |
| --- | --- |
| Remote delete fails (network/5xx) | Queue retry/backoff, same policy as uploads; terminal `failed` entries visible on Transfers page and fall to the sweep |
| Delete of already-absent key | Success; `delete()` is idempotent per the store contract |
| Sweep interrupted (network drop, app close) | Abort cleanly; all actions idempotent, next run resumes; fleet timestamp stamped only on completion |
| Provider unavailable during auto-sweep | Skip silently; retry at next eligibility check |
| Backlog sweep crash mid-way | Completion flag unset, re-runs fully; idempotent |

## 8. Testing

TDD throughout; 80 percent minimum coverage on new code.

- Backfill scoping regression test: in-memory DB with one orphan row (the
  observed repro, miniaturized).
- Cascade: dive-only media dies with tombstone plus queue intent;
  site-linked media survives with `dive_id` nulled; bulk variant.
- Cache DB v6 migration: existing rows default to `upload`; v1-to-v6 path
  does not double-add (v4 guard idiom).
- Drain-time refcount, including the enqueue-then-reference race.
- Multipart abort against `test/helpers/fake_s3_server.dart` (fault
  injection persists until cleared).
- Sweep over `InMemoryMediaObjectStore`: seeded orphan removed,
  grace-window-protected young object kept, missing-object reverse repair,
  multipart reap.
- Widget tests: settings action and summary.
- Schema tripwire: exact-version assertion moves to v136; prior tripwires
  relaxed to `>=`.

## 9. Delivery

Four PRs, each in its own worktree, sequenced so no step converts
row-orphans into blob-orphans:

1. **Stop the bleeding:** backfill query scoping (4.1). Tiny, independent.
2. **Blob fast path:** cache DB v6 delete operation, enqueue-before-delete
   in existing media-delete flows, drain-time refcount, S3 multipart
   abort-at-failure (section 5).
3. **Row cascade plus backlog:** dive-deletion cascade (4.2), one-time
   startup sweep (4.3). Gated on the section 3 verification.
4. **Verify Library:** sweep service, `S3ApiClient` multipart list/abort,
   settings UI plus l10n, opportunistic auto-run, `media_stores.last_sweep_at`
   (schema v136) (section 6).

## 10. Out of scope

- Bulk re-compress / re-upload library actions.
- Lifecycle-rule provisioning on the user's S3 bucket (the app cannot
  assume IAM permission to set bucket policy; client-side abort plus sweep
  reap covers it).
- An unattached-media browsing surface (the cascade makes unlinked rows
  stop existing rather than needing a UI).
- Local cache eviction (already handled by `MediaCacheStore` LRU).
