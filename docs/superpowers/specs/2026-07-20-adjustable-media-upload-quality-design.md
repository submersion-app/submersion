# Adjustable Media Upload Quality (Full / Compressed)

Status: design approved (brainstorm 2026-07-20). Extends the Media Store
subsystem (`docs/superpowers/specs/2026-07-10-s3-media-storage-design.md`,
shipped as PR #550 phases 1-4).

## 1. Problem

The Media Store uploads media bytes *exactly as they exist on device* -- an
explicit v1 non-goal was "re-encoding originals." For divers this is expensive:
a single 4K dive clip dwarfs a whole dive's worth of stills, and a library of
hundreds of dives can run to many gigabytes. Users on metered connections, on a
boat, or paying for cloud storage want to trade fidelity for size. This feature
lifts that non-goal as an **opt-in, per-device, per-media-type** upload quality
setting.

## 2. Goals

1. **Adjustable upload quality** per device, chosen independently for photos and
   for video, from a small set of named levels (`Original / High / Balanced /
   Small`).
2. **Compressed uploads replace the original in the store**, not supplement it:
   exactly one artifact is uploaded per item -- the reduced rendition, or (for a
   file already smaller than the level's ceiling) the untouched original, never
   both. Storage and bandwidth savings are the point.
3. **The local source is never modified.** As with the rest of the store, the
   device only ever *reads* the source (gallery asset, `localFile`, app-owned
   copy); it is never re-encoded, moved, or deleted.
4. **Per-item override.** A user can re-upload a single photo/video at a
   different quality than their device default, replacing what is stored.
5. **Uniform behavior across all five platforms** (iOS, Android, macOS, Windows,
   Linux), including video transcoding.

## 3. Non-goals (v1)

- **Bulk "re-compress my library."** Changing the level affects *future* uploads
  only. A bulk action that walks already-uploaded media and re-renders it at a
  new level is a clean follow-up, deliberately deferred (see section 12). The
  per-item override (goal 4) covers the targeted case.
- **Preserving the full-resolution original of files that exceed the level's
  ceiling.** Such originals are not uploaded in a compressed level; they survive
  only on whatever device still holds the source, so "survive device loss" means
  surviving at the compressed fidelity. (Files already under the ceiling upload
  untouched -- see section 8.) The settings UI states this plainly.
- **Quality-keyed object identity.** `contentHash` continues to mean "the
  original." Compression is a purely additive rendition tier; it never changes
  what `contentHash` identifies (see section 18, alternative C).
- **Multiple coexisting renditions per item.** Exactly one rendition per content
  hash is stored (first-writer-wins across devices; the per-item override
  overwrites in place). The stored level is recorded, not multiplied.
- **RAW/exotic still formats as a compression *input* guarantee.** Formats the
  pure-Dart decoder cannot read fall back to uploading the original (section 9).

## 4. Decisions made during brainstorming

| Question | Decision |
| --- | --- |
| What does "compressed" do to the original? | **Replace it.** Upload a compressed rendition instead; never upload the original; never touch the local source. |
| Photos, video, or both? | **Both.** |
| Video on Windows/Linux (no native transcoder)? | **Bundle ffmpeg** for uniform transcoding on all platforms. |
| ffmpeg license fit? | App is **GPL-compatible open source**, so the GPL ffmpeg build with `libx264`/`libx265` is permitted -> one uniform codepath everywhere. |
| Architecture | **Parallel rendition tier**, modeled exactly on the existing thumbnail tier (derived artifact, keyed by the original's hash, not hash-verified). |
| Amount control | **Named levels, chosen separately for photos and video.** `Original / High / Balanced / Small`. |
| Level-change scope | **Future uploads only.** Bulk re-compress deferred; per-item re-upload included. |
| ffmpeg binding on mobile | **Build our own `submersion_transcoder` federated plugin** (vendored GPL ffmpeg), same playbook as `libdivecomputer`. |

## 5. Architecture overview

Compression slots into the Media Store as one additional, *derived* object tier
alongside `objects/` (originals) and `thumbs/` (thumbnails):

```
                 synced DB (metadata truth)              store (bytes truth)
        +-----------------------------------+     +----------------------------+
attach  | media row + contentHash           |     | smv1/objects/<hash>        | <- original (verified)
        |           + remoteUploadedAt       |<-->| smv1/renditions/<hash>.<ext>| <- compressed (NOT verified)  [NEW]
        |           + remoteCompressedUpload*|     | smv1/thumbs/<hash>.jpg     | <- thumb (NOT verified)
        |           + compressedLevel [NEW]  |     +----------------------------+
        +-----------------------------------+
                 ^                     |
      pipeline chooses a compressor   |  resolver serves best available:
      by media type + device level    v  original -> compressed -> thumb
```

Nothing load-bearing changes. Disconnecting the store still degrades every row
to native behavior; `contentHash` still means "the original"; dedup, GC
refcounts, and self-healing keep working. Compression is additive.

## 6. Data model

### 6.1 Synced `media` columns (main DB migration)

Mirrors the existing `remoteThumbUploadedAt` pattern. Schema version = next free
slot (confirm against `currentSchemaVersion` and open PRs at implementation; the
ladder drifts and collisions get renumbered on rebase).

| Column | Type | Purpose |
| --- | --- | --- |
| `remoteCompressedUploadedAt` | DateTime? | stamp when a rendition is confirmed in the store |
| `compressedLevel` | Text? | the level that produced the stored rendition (`high`/`balanced`/`small`); drives UI ("stored at Balanced") and records the first-writer-wins winner |
| `compressedSizeBytes` | int? | rendition byte size, for space/quota UI |

A `beforeOpen` backstop re-asserts these columns (same defensive pattern the
media store already uses for `content_hash` et al.).

### 6.2 Per-device policy (SharedPreferences, NOT synced)

Added to `MediaStorePolicies` beside `autoUpload`, `photosOnCellular`,
`videosOnCellular`. Per-device because quality is a device choice (a phone on
cellular may want `Small`; a desktop may want `Original`).

| Key | Default | Meaning |
| --- | --- | --- |
| `media_store_photo_quality` | `original` | photo upload level |
| `media_store_video_quality` | `original` | video upload level |

Defaulting to `original` is a correctness choice: existing Media Store users
must not have their upload behavior silently change. Compression is strictly
opt-in.

### 6.3 Quality level enum

```dart
enum MediaUploadQuality { original, high, balanced, small }
```

One enum, used for both settings; the concrete parameters differ by media type
(section 8). `original` is the sentinel for "upload the untouched original"
(today's behavior).

## 7. Store layout

One new namespace under the existing `smv1` root:

```
smv1/renditions/<aa>/<sha256>.<ext>    ext = jpg (photo) | mp4 (video)
                                       keyed by the ORIGINAL's hash; NOT hash-verified
```

- Keyed by the original's `contentHash` (not by quality), so a reader goes
  straight from a `media` row to its rendition with no lookup, and the store
  holds exactly one rendition per content hash.
- `<ext>` is the *rendition's* output format (`jpg` for photos, `mp4` for
  H.264/AAC video) -- derived from `mediaType`, NOT from the original filename.
- Not hash-verified: a derived artifact cannot hash back to the original. The
  key carries the original's hash purely for stable addressing and dedup, the
  same contract thumbnails already use.

New helper: `StoreKeys.renditionKey(contentHash, {required String ext})`.

## 8. Quality levels and presets

A level is a **ceiling**, not a mandate. Media already at or below the level's
target uploads as the **untouched original** (routed to `objects/`,
hash-verified) -- we never re-encode a file into something larger, and never
take generation loss on an already-small JPEG. So a compressed-level item lands
in `objects/` (already-small original) OR `renditions/` (compressed), never
both.

Proposed presets (tunable):

| Level | Photo (long edge, JPEG quality) | Video (max resolution, H.264) |
| --- | --- | --- |
| `original` | untouched upload | untouched upload |
| `high` | 3072 px, q90 | 1080p, CRF ~20, AAC 128k |
| `balanced` | 2048 px, q85 | 720p, CRF ~23, AAC 128k |
| `small` | 1280 px, q75 | 480p, CRF ~26, AAC 96k |

Presets live in a single source-of-truth map (`quality_presets.dart`) consumed
by both compressors, the settings UI (for size estimates), and tests.

## 9. Compression strategies

A small seam chosen by media type. Both return `null` to signal "upload the
original instead" (already under the ceiling, or an undecodable input):

```dart
abstract class MediaCompressor {
  Future<CompressionResult?> compress(
    MediaItem item, File source, MediaUploadQuality level);
}
// CompressionResult { File file; String ext; int sizeBytes; }
```

- **Photos -- `ImageCompressor`** (pure-Dart, no new native code):
  - Gallery assets compress via `photo_manager`'s sized-thumbnail API, which
    decodes HEIC natively (hardware) and returns JPEG -- sidestepping the
    `image` package's lack of a HEIC decoder.
  - File/bytes sources decode via the `image` package (already a dependency and
    used by `ThumbnailGenerator`), resize to the ceiling, re-encode JPEG.
  - Undecodable inputs (e.g. a `localFile` HEIC/RAW that `image` cannot read)
    return `null` -> upload original. (Routing such inputs through the ffmpeg
    plugin as an image fallback is a possible refinement, not v1.)
- **Video -- `VideoTranscoder`** (the ffmpeg engine, section 16): output
  H.264/AAC `.mp4` with `+faststart` for progressive playback. Injectable
  behind the `MediaCompressor` seam so pipeline tests use a fake.

## 10. Upload pipeline changes

In `MediaUploadPipeline.process`, after materializing the original to a staging
file and computing its SHA-256 (still required -- it keys the rendition and
stamps `contentHash`), branch on the device level for this media type:

1. `level == original` -> existing path: upload staged original to
   `objects/<hash>`, stamp `remoteUploadedAt`.
2. otherwise -> `compressor.compress(item, staged, level)`:
   - `null` (ceiling/undecodable) -> fall back to path (1).
   - result -> `head`-dedup + `putFile` the rendition to
     `renditionKey(hash, ext)`, then stamp `remoteCompressedUploadedAt`,
     `compressedLevel`, `compressedSizeBytes`.

The thumbnail step (thumb-first) is unchanged and independent of level. The
"already uploaded" short-circuit at the top of `process` becomes: done if an
original **or** a rendition already exists (respecting first-writer-wins), plus
the existing thumb-only connector case.

### 10.1 Transcode-once, upload-resumably (video)

Transcoding a long clip costs minutes, so it must never repeat on an upload
retry. The transcoded rendition is persisted to a deterministic staging path
(`<hash>.<ext>`) that survives the transcode -> upload boundary *and* app
restarts; only `markDone` (or terminal failure) deletes it. The existing
resumable multipart upload then transfers it. Interrupted transcode -> restart
transcode; interrupted upload -> resume upload from the persisted rendition.
This mirrors how the queue already persists resume state.

## 11. Read path

`MediaStoreResolver.tryResolveRemote` gains a middle tier:

```
thumbnail request:  thumb (if remoteThumbUploadedAt) -> else fall through
full request:       original (remoteUploadedAt, HASH-VERIFIED)
                 -> compressed (remoteCompressedUploadedAt, NOT verified)
                 -> null
```

- Rendition fetch derives its ext from `mediaType` (photo -> jpg, video -> mp4).
- A new `MediaCacheKind.rendition` keeps renditions distinct from originals in
  the evictable cache. `kind` is a value (part of the cache PK), so no local
  cache DB migration is required; the cache gains a rendition pool budget.

### 11.1 Rendition freshness (mutable renditions)

The per-item override (section 12) can overwrite `renditions/<hash>.<ext>` at a
new level. That makes the rendition tier **mutable** at a stable key, which
breaks the usual "bytes at a key never change, so a cache never goes stale"
assumption. Fix: a rendition cache entry records the `remoteCompressedUploadedAt`
it was fetched at; the resolver refetches when the synced stamp advances.
Originals stay immutable and hash-verified; only the derived rendition tier gets
this freshness check.

## 12. Per-item re-upload override

An "Upload quality" action on the media detail overflow menu and as a per-row
action in the Transfers view lets a user pick `Original / High / Balanced /
Small` for one item and **replace** what is stored.

- **Forced re-run.** Bypasses the "already uploaded" dedup gate (an explicit
  `replace` flag on enqueue) and re-renders from the original.
- **Overwrite semantics.** Because the rendition key ignores quality,
  compressed -> compressed (different level) overwrites the same key. The
  cross-namespace cases swap stamps and GC the abandoned object if its content
  refcount is zero:
  - Original -> compressed: write `renditions/`, set compressed stamps, clear
    `remoteUploadedAt`, enqueue delete of `objects/<hash>` if refcount 0.
  - compressed -> Original: write `objects/`, set `remoteUploadedAt`, clear
    compressed stamps, enqueue delete of `renditions/<hash>.<ext>` if refcount 0.
- **Precondition.** Re-rendering pulls from the original, so the action requires
  the original to be resolvable on this device (its source or a cached
  original). If only a compressed copy remains (source already freed), going
  *higher* is physically impossible; v1 offers only equal-or-lower there, or
  explains why. Downscaling from an existing rendition is a possible refinement.

## 13. Deletion and GC

**Important correction (found during planning):** the Media Store's general
deletion fast-path and Verify Library sweep, described in its own spec's
section 12, were specified for a Phase 5 that was never built. The shipped code
has no content-hash refcount, no delete queue, and no store-listing sweep. This
feature therefore does NOT build a general sweep. Two scopes:

- **Now (Phase A): targeted override delete only.** The per-item re-upload
  override (section 12) reclaims space by deleting the specific abandoned object
  (the old original or old rendition) when a precise guard proves no remaining
  `media` row wants it -- `countRowsWithOriginal` / `countRowsWithRendition`
  over the shared `content_hash`. This is a direct, idempotent `store.delete`,
  not a queued sweep.
- **Future (Media-Store Phase 5): general GC.** When the store's deletion
  fast-path and Verify Library sweep are eventually built, they must also cover
  `smv1/renditions/`: delete renditions unreferenced past the grace window, and
  reverse-repair rows whose `remoteCompressedUploadedAt` points at a missing
  object (clear the stamp; re-enqueue if bytes are locally resolvable). The
  rendition tier is designed to slot into that sweep unchanged.

## 14. Multi-device semantics

- **Mixed fidelity is first-class.** An `Original` device and a `Small` device
  can reference the same photo; the store may hold an original (`objects/`) and
  a rendition (`renditions/`) under the same hash. Readers prefer the original.
- **First-writer-wins.** If device X uploads `Balanced` and device Y later
  processes the same photo at `Small`, Y's `head` check finds the rendition and
  marks done; `compressedLevel` records what X wrote. The per-item override is
  the escape hatch when a specific item must change.
- **Synced stamps advertise availability.** `remoteUploadedAt`,
  `remoteCompressedUploadedAt`, and `compressedLevel` propagate so every device
  resolves best-available and honors the freshness check (11.1).

## 15. Settings UI

The **Media Storage** page gains an "Upload quality" section:

- Two controls -- **Photos** and **Video** -- each a picker over `Original /
  High / Balanced / Small`, backed by the two SharedPreferences keys.
- Helper text per level (approx resolution) and, where cheap, an estimated size.
- A plain-language caveat: *"With a compression level set, full-resolution
  originals are not uploaded -- they remain only on this device."*
- New l10n keys across all 11 `.arb` locales (en is the template; includes ar).

## 16. The `submersion_transcoder` plugin (ffmpeg)

A federated plugin under `packages/submersion_transcoder`, vendoring a GPL
ffmpeg build with `libx264`/`libx265`, exposing one `VideoTranscoder` interface.
Same vendoring/build playbook as `packages/libdivecomputer_plugin`.

- **Desktop (Windows / Linux / macOS):** bundle the `ffmpeg` binary; drive it
  via `Process.start`; parse `-progress pipe:` for a 0->1 progress stream.
- **Mobile (iOS / Android):** no subprocesses allowed -> link `libffmpeg` and
  call transcode over a `MethodChannel`, streaming progress over an
  `EventChannel`.
- **Uniform params** from the level preset: `scale` filter to the resolution
  ceiling, `-c:v libx264 -crf <n> -preset medium`, `-c:a aac -b:a <k>`,
  `-movflags +faststart`.
- **Licensing:** GPL build is compatible with the app's GPL-compatible license;
  a `LICENSE` file should be committed to make the app's license explicit and
  document the ffmpeg linking basis. Per-platform build scripts + CI wiring are
  part of Phase B.

## 17. Delivery phases

- **Phase A -- Photos (full architecture, pure-Dart compressor).** Schema +
  backstop; `renditionKey`; `MediaCacheKind.rendition` + freshness; read-path
  middle tier; both policy settings; `MediaUploadQuality` + presets;
  `ImageCompressor`; pipeline branch + ceiling fallback; per-item override;
  GC/Verify coverage; settings UI + l10n. The **video setting ships but degrades
  gracefully** -- `VideoTranscoder` is absent, so a compressed video level falls
  back to uploading the original -- until Phase B. Phase A is a complete,
  shippable feature on its own.
- **Phase B -- Video.** The `submersion_transcoder` federated plugin (vendored
  GPL ffmpeg, per-platform builds + CI); `VideoTranscoder` implementation;
  pipeline video branch with transcode-once/persisted-rendition/progress;
  transcode smoke tests.

## 18. Alternatives considered

- **A. Parallel rendition tier (chosen).** Additive, mirrors thumbnails, changes
  nothing load-bearing.
- **B. Overload the thumbnail tier.** Make the thumb bigger in compressed mode
  instead of a new tier. Rejected: conflates the 512px UI thumbnail with a
  "compressed original," so the same photo serves 512px from a full-mode device
  and 2048px from a compressed-mode device -- inconsistent fidelity and a broken
  "thumbs are always cheap" invariant.
- **C. Quality-keyed object identity.** Let `contentHash` be the hash of whatever
  was uploaded, so the existing verify path "just works." Rejected: shatters
  dedup, churns identity whenever the level changes, and contradicts the four
  consumers that rely on `contentHash` meaning "the original."
- **Quality-in-key renditions** (`renditions/<hash>/<level>.<ext>`). Immutable
  per-level objects, no freshness check needed. Rejected for v1: multiplies
  stored bytes and adds a "which level do I fetch" decision on every read; the
  single mutable rendition + timestamp check is cheaper for a personal log.
- **Community ffmpeg_kit fork** instead of an own plugin. Rejected: the original
  was retired in 2025; own plugin gives control and matches the codebase.

## 19. Risks

- **ffmpeg vendoring across five platforms is the effort centroid** (2 linked-lib
  + 3 CLI binaries, GPL build with x264/x265). Mitigated by phasing (video is
  Phase B) and by reusing the `libdivecomputer` vendoring playbook.
- **App binary size** grows with bundled ffmpeg. Acceptable for the feature;
  measure per platform.
- **Generation loss** if a user re-compresses (per-item) repeatedly. Mitigated
  by always re-rendering from the original, never from a rendition.
- **Mutable renditions** could serve stale cached bytes across devices. Mitigated
  by the `remoteCompressedUploadedAt` freshness check (11.1).
- **Lost originals.** In a compressed level the original is never uploaded; if
  the source is later freed, full resolution is unrecoverable. This is the
  user's explicit, stated trade-off; the settings copy makes it unambiguous.

## 20. Testing strategy

- **Unit:** preset -> params mapping; `ImageCompressor` resize/quality and
  ceiling -> `null`; ceiling fallback routes to original-upload;
  `StoreKeys.renditionKey`; read-path tier ordering (original > compressed >
  thumb); dedup gate with a compressed stamp; rendition freshness (refetch when
  the stamp advances); per-item override stamp-swap + orphan GC.
- **Fakes:** store fake gains the `renditions/` namespace (put/head/get,
  first-writer-wins, overwrite); a fake `VideoTranscoder` for pipeline tests.
- **Pipeline:** compressed path stamps compressed (not `remoteUploadedAt`); thumb
  still first; retry reuses the persisted rendition (no re-transcode);
  `markDone` cleans rendition staging.
- **Video (Phase B):** a gated real-ffmpeg smoke test where the binary/lib is
  available; unit-level `VideoTranscoder` param construction.
- **Widget:** settings pickers + caveat text; per-item override action.
- **Coverage:** target >= 90% patch coverage (Eric's bar on media-store work).

## 21. Planned file map (indicative)

```
lib/core/services/media_store/media_store_policies.dart        (+photo/video quality)
lib/core/services/media_store/store_keys.dart                  (+renditionKey)
lib/features/media_store/domain/media_upload_quality.dart      (NEW enum)
lib/features/media_store/data/quality_presets.dart             (NEW preset map)
lib/features/media_store/data/media_compressor.dart            (NEW seam + result)
lib/features/media_store/data/image_compressor.dart            (NEW, Phase A)
lib/features/media_store/data/video_transcoder.dart            (NEW interface, Phase A)
lib/features/media_store/data/media_upload_pipeline.dart       (branch on level)
lib/features/media/data/repositories/media_repository.dart     (+compressed stamps)
lib/features/media/data/resolvers/media_store_resolver.dart    (+compressed tier, freshness)
lib/features/media_store/data/media_cache_store.dart           (+rendition kind/pool)
lib/features/media_store/data/media_store_service.dart         (GC/Verify renditions)
lib/features/media_store/presentation/pages/media_storage_page.dart (+quality section)
lib/features/media_store/presentation/.../reupload action      (per-item override)
lib/core/database/database.dart                                (migration vNNN + backstop)
lib/l10n/*.arb                                                 (11 locales)
packages/submersion_transcoder/                                (NEW plugin, Phase B)
```
