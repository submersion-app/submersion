# Media Store: Cloud Storage Backend for Photos and Video

- **Date:** 2026-07-10
- **Status:** Approved design (brainstormed and section-approved with Eric); implementation plan pending
- **Branch/worktree:** `worktree-s3-media-store`
- **Origin:** "I want to support an S3 storage backend for photos/media"

## 1. Problem

Submersion's media architecture is a pure-reference model: the synced `media` table
(`lib/core/database/database.dart:791`) stores pointers (`platformAssetId`, `localPath`,
`bookmarkRef`, `url`), and bytes are resolved at display time through the
`MediaSourceResolver` registry. Photo and video bytes never leave the device:

- **Sync** carries only DB rows (plus small in-DB BLOBs such as signatures and cert
  cards). On a second device, gallery photos are re-matched against that device's photo
  library by metadata (`AssetResolutionService`), which is fragile and produces
  "unavailable from other device" placeholders.
- **Backup** is a straight SQLite copy; media binaries are not included. Losing the
  device loses the bytes.
- Two prior specs (`2026-04-25-media-source-extension-design.md`,
  `2026-06-09-s3-sync-backend-design.md`) both explicitly declared media-byte upload a
  non-goal. Nothing in the app uploads a photo today.

This design adds a **Media Store**: a user-owned cloud location that becomes the
canonical home for media bytes. The synced DB remains the source of truth for metadata;
devices become caches for bytes.

## 2. Goals

All four were selected as goals of this feature:

1. **Cross-device photos and video** - media attached on one device displays on all
   synced devices, replacing gallery re-matching as the primary cross-device mechanism.
2. **Survive device loss** - once uploaded, bytes are safe in the user's bucket/account.
3. **Free up device space** - originals can live remotely; devices keep thumbnails and
   an evictable cache.
4. **Self-hosted option** - any S3-compatible service (AWS, MinIO, R2, B2, Wasabi, ...)
   can be the store, alongside the managed providers.

## 3. Non-goals (v1)

- **Client-side encryption.** Consistent with the abandoned encrypted-sync effort;
  server-side encryption is the user's bucket configuration.
- **Public sharing links** or any social/export surface.
- **Re-encoding originals.** Bytes upload exactly as they exist on device.
- **Deleting or modifying anything in the OS photo gallery.** The store never reaches
  into the platform photo library except to read.
- **Third-party read-only connectors** (Immich and friends). The reserved
  `MediaSourceType.serviceConnector` enum value, `ConnectorAccounts` table, and
  `remoteAssetId`/`connectorAccountId` columns stay untouched and reserved for that
  future feature. The Media Store is its own concept.
- **Multiple simultaneous stores.** Exactly one active media store per library.
- **OS-level background transfer daemons.** v1 transfers run while the app is open and
  resume on next launch. iOS `URLSession` background sessions / Android `WorkManager`
  are an explicitly flagged future enhancement; divers importing hundreds of photos will
  lock their phones, and v1 accepts pausing until the app is next foregrounded.

## 4. Decisions made during brainstorming

| Question | Decision |
| --- | --- |
| Config relationship to sync | **Independent.** The media store has its own provider selection and credentials, unrelated to the sync backend. A "Copy from Sync" prefill is offered when sync already uses S3. |
| Media scope | **Photos and video, both in v1.** The transfer layer (chunked, resumable, progress) is first-class. |
| Backend scope | **All four backends in v1**: S3-compatible, iCloud, Google Drive, Dropbox, behind a small `MediaObjectStore` interface. |
| Architecture | **Dedicated media-store subsystem** (parallel to sync, not inside it). Piggybacking on the `ssv1.` sync transport and realizing the ServiceConnector framework were both considered and rejected (see section 18). |

A consequence of multi-backend: presigned URLs cannot be the universal read path (only
S3 has them), so the read side is **download-to-local-cache** through each provider's
authenticated API. This is also the correct behavior for offline use on boats.

## 5. Architecture overview

```
                    synced DB (metadata truth)                 store (bytes truth)
              +------------------------------+          +---------------------------+
  attach ---> | media row  + contentHash     |          |  smv1/objects/<hash>      |
              |            + remoteUploadedAt| <-sync-> |  smv1/thumbs/<hash>.jpg   |
              +------------------------------+          |  smv1/store.json          |
                     ^                |                  +---------------------------+
                     | confirm        | row visible            ^            |
                     |                v on device B            | put        | get
              +---------------+   +--------------+       +-----------------------+
              | upload        |   | MediaStore   |       |  MediaObjectStore     |
              | pipeline      |-->| Resolver     |------>|  (S3 | iCloud |       |
              | (queue,hash,  |   | (cache, then |       |   Drive | Dropbox)    |
              |  thumb,put)   |   |  download)   |       +-----------------------+
              +---------------+   +--------------+
```

New subsystem, three layers:

- **Transport:** `MediaObjectStore` interface + four adapters + shared `TransferEngine`
  (chunking, resume, progress, retry) in `lib/core/services/media_store/`.
- **Pipeline:** upload queue, hashing, thumbnail generation, backfill, GC in
  `lib/features/media_store/`.
- **Integration:** one new resolver (`MediaStoreResolver`) registered as a fallback in
  the existing media resolution flow; a settings area; per-item status badges.

Sync, backup, and the existing `CloudStorageProvider` interface are untouched.

## 6. Data model

### 6.1 Synced schema (main DB, migration to v103)

`media` table gains four nullable columns (nullable adds; no backfill required):

| Column | Type | Meaning |
| --- | --- | --- |
| `content_hash` | TEXT | Lowercase hex SHA-256 of the original bytes. Set when first hashed. |
| `content_size_bytes` | INTEGER | Byte length of the original. |
| `remote_uploaded_at` | DATETIME | Set when the original object is confirmed present in the store. |
| `remote_thumb_uploaded_at` | DATETIME | Set when the thumbnail object is confirmed present. |

These ride the existing `media` row sync (HLC conflict resolution, existing deletion
log). Once a device stamps `remote_uploaded_at`, every peer learns the bytes are
fetchable.

New synced table `media_stores` (registered in the sync serializer's changeset and base
table lists, with per-row tombstone support like other synced tables):

| Column | Type | Meaning |
| --- | --- | --- |
| `id` | TEXT PK | The store id (UUID), identical to `storeId` in `store.json`. |
| `provider_type` | TEXT | `s3`, `icloud`, `googledrive`, `dropbox`. |
| `display_hint` | TEXT | Secret-free label, e.g. `S3: dive-media @ minio.example.com`. |
| `created_at`, `updated_at`, `hlc` | | Standard synced-table bookkeeping. |

Purpose: announce to other devices that this library has a media store so they can
prompt "connect this device" (section 13). Never contains credentials. The app treats
the highest-HLC row as the active store; UI enforces a single row.

The reserved v72 columns (`remoteAssetId`, `connectorAccountId`, `originDeviceId`) are
**not** used by this feature; object keys derive from `content_hash`.

### 6.2 Per-device tables (local cache DB, never synced, never backed up)

Both go in the existing per-device Drift database
(`lib/core/database/local_cache_database.dart`, Application Support directory), which
already exists precisely for state that must not survive restore or ride backups. Its
own schema version bumps accordingly.

`media_transfer_queue`:

| Column | Notes |
| --- | --- |
| `id` | PK, autoincrement. |
| `media_id` | The `media` row this transfer serves. |
| `direction` | `upload` or `download`. |
| `object_kind` | `original` or `thumb`. |
| `content_hash` | Null until the hashing step completes (uploads). |
| `state` | `pending`, `hashing`, `transferring`, `done`, `failed`. |
| `attempts`, `next_attempt_at` | Retry bookkeeping (backoff, section 15). |
| `resume_state_json` | Provider-specific resume token: S3 `uploadId` + part list, Drive session URI + offset, Dropbox session id + offset. Null for single-shot. |
| `error_message` | Last failure, for the Transfers view. |
| `priority`, `created_at`, `updated_at` | Thumbs and user-requested downloads sort above bulk backfill. |

`media_cache_entries`:

| Column | Notes |
| --- | --- |
| `content_hash` + `kind` | Composite PK (`kind`: `original` or `thumb`). |
| `relative_path` | Under the cache root. |
| `size_bytes`, `last_accessed_at`, `created_at` | LRU eviction inputs. |

## 7. Store layout

Namespace `smv1` ("Submersion media, format v1", sibling to sync's `ssv1.`), under the
user-configured prefix (S3) or app folder (managed providers):

```
<prefix>smv1/store.json                     identity marker
<prefix>smv1/objects/<aa>/<sha256>.<ext>    originals; aa = first two hex chars
<prefix>smv1/thumbs/<aa>/<sha256>.jpg       thumbnails, keyed by the ORIGINAL's hash
```

- `store.json`: `{ "storeId": "<uuid>", "formatVersion": 1, "createdAt": "<iso8601>" }`.
  Written once at store initialization; read to detect bucket swap/wipe (section 13).
- `<ext>` is derived from the original's detected type (lowercased; `bin` when
  unknown). Since identical bytes imply identical format, hash-to-ext is stable.
- Thumbnails are keyed by the original's hash so a reader can go straight from a
  `media` row to its thumb with no lookup.
- Fan-out directories (`aa`) keep listings and folder sizes manageable on all backends.
  Folder-backed providers (Drive, Dropbox, iCloud) materialize this as a real folder
  tree; S3 uses key prefixes.

Content addressing gives dedup (one object however many dives reference the photo),
idempotent uploads (two devices racing converge on the same key; a `head` check
replaces coordination), download integrity verification, and self-healing (any device
holding the bytes can restore a missing object).

## 8. Transport layer

### 8.1 `MediaObjectStore` interface

New, in `lib/core/services/media_store/`. Deliberately file-based, never
whole-`Uint8List` (the existing `CloudStorageProvider.uploadFile(Uint8List, ...)` shape
would materialize a whole video in RAM - the OOM class sync fought in #358):

```dart
abstract class MediaObjectStore {
  Future<StoreObjectInfo?> head(String key);
  Future<void> putFile(
    String key,
    File source, {
    required String contentType,
    TransferProgressCallback? onProgress,
    TransferResumeState? resume,
    ValueChanged<TransferResumeState>? onResumeStateChanged,
  });
  Future<void> getFile(
    String key,
    File destination, {
    TransferProgressCallback? onProgress,
    TransferResumeState? resume,
    ValueChanged<TransferResumeState>? onResumeStateChanged,
  });
  Future<void> delete(String key); // idempotent, like S3ApiClient.deleteObject
  Stream<StoreObjectInfo> list(String keyPrefix); // paginated internally; GC/verify
}
```

`StoreObjectInfo` carries key, size, and last-modified. `TransferResumeState` is an
opaque JSON-serializable value owned by each adapter.

### 8.2 Adapters

| Backend | Small objects (< 8 MB) | Large objects | Resume | Download |
| --- | --- | --- | --- | --- |
| S3 | existing `putObject` | Multipart API - new `S3ApiClient` operations: `CreateMultipartUpload`, `UploadPart`, `CompleteMultipartUpload`, `AbortMultipartUpload` | stored `uploadId` + `ListParts` | streamed `GET` to file; `Range` on resume |
| Google Drive | single-shot upload | resumable session (`uploadType=resumable`, 308 protocol) | session URI + confirmed offset | `alt=media` with `Range` |
| Dropbox | single upload | `upload_session` start / append / finish | session id + offset | `Range` |
| iCloud | native file APIs via `icloud_native_service` (already file-path shaped) | same - the OS moves files into the ubiquity container | OS-managed | OS-managed |

The `SigV4Signer` is pure functions, so signing multipart part-requests is mechanical.
Adapters live beside, not inside, the existing providers: sync and backup keep their
whole-file semantics untouched, and this feature adds zero risk to the sync engine.
Where a managed provider requires sign-in, the adapter reuses the existing auth
managers and token stores (Drive, Dropbox PKCE); a user who uses the same service for
sync and media signs in once.

### 8.3 `TransferEngine`

Shared driver above the adapters:

- Reads sources in 8 MB chunks (sync's proven `BaseChunker` constant).
- Streams SHA-256 while uploading (integrity for free) and verifies hash on download
  before promoting a temp file into the cache.
- Persists resume state into the queue row after every acknowledged chunk, so a
  transfer killed at 80 percent restarts at the last acknowledged part.
- Honors cancellation, network-policy gating (section 9), and the retry taxonomy
  (section 15).

## 9. Upload pipeline

**Triggers:** (1) on attach/import - `MediaImportService` enqueues immediately after
creating the row; (2) backfill - a settings action enumerating device-resident rows
lacking `remote_uploaded_at`, newest `takenAt` first, with progress and pause;
(3) queue drain on app launch and on connectivity regain.

**Eligibility:** `sourceType` in `platformGallery`, `localFile`. Excluded:
`networkUrl`/`manifestEntry` (bytes already have a durable remote home), signatures and
cert cards (already inside the synced DB), and rows another device owns
(`canResolveOnThisDevice() == false`).

**Per-item pipeline** - each step idempotent so a crash replays harmlessly:

1. **Resolve bytes to a temp file** via the existing resolver registry - the resolvers
   already know how to extract bytes from gallery assets and bookmarked files; no new
   extraction code.
2. **Hash** (streamed SHA-256); stamp `content_hash` + `content_size_bytes` on the row.
3. **Dedup check:** `head(objects/<hash>)` - if present (other device won, or same
   photo on two dives), skip to step 6.
4. **Thumbnail:** longest side 512 px, JPEG quality 80, orientation baked in (EXIF is
   dropped by re-encoding, which also strips GPS from the thumb). Sources: gallery
   photos and videos come nearly free from `photo_manager`'s thumbnail API; non-gallery
   photos decode via the Flutter image codec; non-gallery video files use a platform
   thumbnailer (AVFoundation on iOS/macOS, `MediaMetadataRetriever` on Android;
   Windows/Linux ship v1 without local-video thumbnailing and use a placeholder).
   Thumbnail generation is best-effort: failure never blocks the original's upload.
5. **Upload thumb first, then original.** Thumbs are tiny, so remote devices get
   something renderable fast even while a video crawls up.
6. **Confirm:** stamp `remote_thumb_uploaded_at` / `remote_uploaded_at` (HLC row
   update, which syncs).

**Network policies** (device-local preferences, stored in SharedPreferences like other
per-device flags): auto-upload on by default once a store is configured; photos and
thumbs allowed on any network; **videos Wi-Fi-only by default**; both configurable; a
per-item "upload now" override bypasses gating. Network type comes from
`connectivity_plus`.

**Progress surfaces:** a Transfers view (active, queued, failed with reasons, retry
buttons) and small status badges on gallery tiles. Badges are quiet-on-success: only
queued / uploading / failed states render; steady state shows nothing.

## 10. Read path

Resolution becomes a two-step fallback, implemented where media resolution is already
orchestrated (registry consumers), not by rewriting resolvers:

1. The row's native resolver runs first (gallery/local file) - fast, free, offline, and
   unchanged on the device that owns the bytes.
2. Only if it returns `UnavailableData` and the row has `remote_uploaded_at` does the
   new `MediaStoreResolver` engage. It lives in `lib/features/media/data/resolvers/`
   beside the existing resolvers but is deliberately *not* registered under a
   `MediaSourceType` (rows keep their native source type); the resolution orchestration
   invokes it as a fallback:
   - **Cache hit:** return `FileData` from the content-addressed cache.
   - **Thumbnail request:** download synchronously (small), cache, return.
   - **Original request:** enqueue a priority download task and return the thumbnail
     with a progress affordance; on completion, invalidate that media item's provider
     only (targeted, per-`mediaId`, avoiding the invalidation-storm class of bug), so
     the UI re-resolves to the full asset.
3. No store configured, or offline with a cache miss: today's `UnavailableData`
   placeholder behavior, with copy that distinguishes "connect your media store" from
   "will fetch when online".

**Cache:** `media_cache/{originals,thumbs}/<aa>/<hash>` under Application Support
(excluded from device backups, consistent with the local cache DB). LRU eviction by
`last_accessed_at` against per-pool caps - originals default 2 GB, thumbs default
256 MB, both configurable - run after each write and at launch. Thumbs pool is separate
so bulk original downloads can never evict the thumbnails that keep grids rendering.

## 11. Free up device space

- Downloaded originals live in the evictable cache; eviction is the mechanism.
- App-owned original files (today: OCR scanned-log copies in `scanned_logs/`) migrate
  under cache management once their upload is confirmed: the file moves into the
  content-addressed cache and becomes evictable. The row itself is untouched - its
  native resolution simply misses, falls through to the store path, and finds the bytes
  in the cache by `content_hash` (or re-downloads after eviction). This is where
  net-new device space is reclaimed.
- Gallery originals are never touched (non-goal), so "free up space" for gallery media
  means: the *app* stores only thumbs plus whatever cache the user allows, and the user
  may delete from the OS gallery themselves once uploads are confirmed - the app keeps
  working via the store.

## 12. Deletion and GC

**Fast path.** When a user deletes a media row on this device (the row deletion itself
propagates via the existing sync deletion log), the store service computes the local
refcount of its `content_hash` across remaining media rows. If zero, it enqueues
idempotent deletes for original + thumb. Only the device where the user performed the
deletion enqueues remote deletes; devices applying the same deletion via sync do not.
This avoids delete storms while staying correct: misses fall to the sweep.

**Verify Library (manual sweep, settings action).**

1. List `smv1/objects/` and `smv1/thumbs/`; diff against all `content_hash` values in
   the DB.
2. Delete unreferenced objects whose last-modified is older than a 30-day grace window.
3. Reverse repair: rows claiming `remote_uploaded_at` whose object is missing get the
   stamp cleared; if the bytes are still resolvable locally they are re-enqueued for
   upload, otherwise the row falls back to placeholder behavior.
4. Report a summary (objects checked, orphans removed, repairs queued).

**Race analysis.** All races are benign and repairable: deletes are idempotent; a
device that fetches a just-deleted object gets a 404 placeholder; a device that still
holds bytes for a live row re-uploads to the same key (self-healing); the grace window
prevents the sweep from deleting objects whose referencing rows simply have not synced
yet. There is deliberately no distributed coordination protocol.

## 13. Multi-device semantics

- **Identity:** `store.json` holds the `storeId`. Each configured device records the
  `storeId` it attached to (SharedPreferences) alongside its credentials (keychain via
  the existing `FallbackSecureStorage` path; S3 media config uses its own keychain key,
  `media_store_s3_config`, sibling of sync's `sync_s3_config`).
- **Mismatch:** if the marker is missing where one existed, or the `storeId` differs
  from the attached one (bucket wiped or repointed), transfers suspend and settings
  surface the condition. v1 (Phase 1) blocks with a clear error; Phase 5 adds guided
  flows: adopt the new store, rebuild the store from this device's library, or detach.
  Same defensive pattern as sync's library-epoch marker.
- **Second device attach:** the synced `media_stores` descriptor row tells other
  devices a store exists (`display_hint` only - never secrets). Media surfaces prompt
  "connect this device to your media store"; the user enters credentials (or signs in)
  on that device. Until connected, the device keeps today's behavior.
- **No store on a device:** rows still resolve local-first; the store fallback is
  simply absent.

## 14. Settings UI

New **Media Storage** page beside Sync/Backup in settings:

- Provider chooser (S3-compatible, iCloud, Google Drive, Dropbox), mirroring the cloud
  sync chooser pattern.
- Per-provider configuration. The S3 form is a sibling of
  `lib/features/settings/presentation/pages/s3_config_page.dart` (endpoint, bucket,
  keys, region auto-detection, path-style handling, test-connection probe) with its own
  storage key, default prefix `submersion-media/`, and a "Copy from Sync" prefill when
  sync is on S3.
- Policies: auto-upload toggle; cellular permissions for photos and for videos
  (separate); cache size caps (originals, thumbs).
- Actions: Backfill ("Upload existing library", with progress), Transfers view, Verify
  Library, Disconnect (detaches this device; data stays in the store).

## 15. Error handling

| Class | Examples | Behavior |
| --- | --- | --- |
| Transient | timeouts, 5xx, connectivity loss | exponential backoff per item (1 min, 5 min, 30 min, then hourly, capped); queue-wide wake on connectivity regain |
| Auth | 401/403, refresh failure | pause queue; "Reconnect" surfaced in settings and Transfers view; delegates to existing auth managers / S3 error normalization |
| Quota / storage full | provider-specific quota errors | pause uploads; explicit user-facing message |
| Integrity | download hash mismatch | delete temp file, retry once, then mark failed with reason |
| Missing object | 404 on a confirmed key | placeholder; reverse-repair via Verify Library; re-upload if bytes local |
| Fatal | other 4xx | mark item failed with normalized message (reuse `S3ApiClient` error normalization patterns) |

Offline is a normal state, not an error: the queue idles and the UI shows queued
badges. Insecure (plain HTTP) endpoints reuse the existing warning treatment from the
S3 sync config page.

## 16. Testing strategy

- **Unit:** key derivation and fan-out; streamed hashing; queue state-machine
  transitions (including crash-replay idempotence); resume-state persistence; refcount
  and GC logic including the grace window; error classification. Multipart SigV4
  canonical requests verified against computed AWS test vectors (vectors computed with
  python3, never from memory).
- **Pipeline integration:** an in-memory fake `MediaObjectStore` drives end-to-end
  tests: attach, upload, confirm, simulated second device fetch, delete, GC; dedup race
  (two uploaders, one object); kill-and-resume mid-transfer.
- **Migration:** main DB v103 test following the existing migration-test pattern; local
  cache DB migration test.
- **Widget:** badges, Transfers view, Media Storage settings (respecting the known
  FormSection test gotchas).
- **Manual/integration harness:** MinIO in Docker for the S3 adapter (single-shot +
  multipart + resume); real-account smoke for Drive/Dropbox/iCloud; device matrix smoke
  (macOS, iOS, Android) for gallery extraction and thumbnails.

## 17. Delivery phases

Each phase is independently shippable; scope of all five is agreed as v1.

1. **Foundation** - v103 migration, `media_stores` table + sync registration,
   `MediaObjectStore` + S3 single-shot adapter, transfer queue, upload-on-attach for
   photos, `MediaStoreResolver` + cache + eviction, `store.json` written and checked.
   Exit: a photo attached on device A displays on device B via S3 (MinIO and AWS).
2. **UX layer** - thumbnail objects, Transfers view, gallery badges, backfill,
   network policies. Exit: badges and transfers reflect reality; backfill completes a
   real library; video-off-Wi-Fi gating enforced.
3. **Large objects** - `TransferEngine` chunking/resume, S3 multipart, video support,
   video thumbnailers. Exit: a multi-GB video survives kill-and-resume and plays on a
   second device; poster thumbs render everywhere.
4. **Backends** - Google Drive, Dropbox, iCloud adapters (single-shot + large-object
   paths). Exit: Phase 1 and Phase 3 exit criteria pass on all four backends.
5. **Lifecycle** - deletion refcount + remote delete, Verify Library, free-space
   migration of app-owned originals, full store-mismatch UX. Exit: deletes propagate;
   seeded inconsistencies (orphan object, missing object, wrong marker) are all
   detected and repaired or surfaced.

## 18. Alternatives considered

- **Ship media through the sync engine (`ssv1.` transport).** Rejected: couples media
  to the sync backend choice (contradicts the independent-config decision), entangles
  immutable blobs with changeset/base compaction lifecycle, and the sync layout is a
  log, not a blob store.
- **Realize the ServiceConnector framework and make this the first connector.**
  Rejected for v1: that framework was designed read-only for third-party libraries;
  wedging a read-write canonical store into it muddies both concepts. The seam stays
  reserved; a future Immich-style connector remains possible unchanged.

## 19. Risks

- **iCloud adapter capability.** The native service is file-path shaped, but resumable
  large-file semantics are OS-managed; verify early in Phase 4 and, if needed, gate
  very large files on iCloud with a clear message.
- **Desktop video thumbnails.** Windows/Linux have no v1 thumbnailer for non-gallery
  video files; placeholder is the accepted degradation.
- **Metered-network surprises.** Mitigated by Wi-Fi-only-videos default, cellular
  toggles, and quiet queue idling.
- **No OS background transfers in v1.** Large backfills require the app foregrounded;
  explicitly documented behavior with resume-on-launch.

## 20. Planned file map (indicative)

```
lib/core/services/media_store/
  media_object_store.dart            interface + StoreObjectInfo + resume types
  store_keys.dart                    hash -> key derivation, fan-out, ext detection
  store_marker.dart                  store.json read/write/verify
  transfer_engine.dart               chunk loop, resume, hashing, gating
  transfer_error.dart                error taxonomy
  adapters/s3_media_object_store.dart
  adapters/google_drive_media_object_store.dart
  adapters/dropbox_media_object_store.dart
  adapters/icloud_media_object_store.dart
lib/core/services/cloud_storage/s3/s3_multipart.dart   new S3ApiClient operations
lib/features/media_store/
  data/media_store_service.dart      orchestration, confirmation stamps, refcounts
  data/media_upload_pipeline.dart    the six-step pipeline
  data/media_backfill_service.dart
  data/media_gc_service.dart         fast-path deletes + Verify Library
  data/media_cache_store.dart        content-addressed cache + LRU eviction
  data/thumbnail_generator.dart
  presentation/pages/media_storage_page.dart
  presentation/pages/s3_media_config_page.dart
  presentation/pages/transfers_page.dart
  presentation/providers/...
  presentation/widgets/media_store_badge.dart
lib/features/media/data/resolvers/media_store_resolver.dart
```

Schema changes land in `lib/core/database/database.dart` (v103) and
`lib/core/database/local_cache_database.dart`.
