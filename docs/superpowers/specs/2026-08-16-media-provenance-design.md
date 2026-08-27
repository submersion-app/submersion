# Media Provenance: Origin, Backup, and Serving Source

Date: 2026-08-16
Status: Approved (design), not yet planned or implemented

## 1. Problem

A user cannot tell, for any given photo, video, or document in the app:

1. **Where it was linked from.** Was it picked from the device photo library,
   imported from a folder on disk, fetched from a URL, or pulled from a
   manifest feed? Was it linked on this device or another one?
2. **Whether it is safely backed up.** Has the cloud media store received the
   original, only a thumbnail, or only a compressed rendition? Is it queued,
   in flight, or failed?
3. **Why it is broken** when a thumbnail is grey or the original will not
   open.
4. **Where the bytes are coming from right now.** Local disk, the local media
   cache, or a live download from the cloud store (which costs bandwidth).

Today the app answers none of these. `originalFilename`, `contentSizeBytes`,
`width`/`height`, `sourceType`, `contentHash`, every `remote*UploadedAt`
stamp, `originDeviceId`, `lastVerifiedAt`, and `retainInLibrary` are stored on
every row and displayed nowhere. There is no info panel, info sheet, or
details screen for a media item anywhere in `lib/`.

### 1.1 Root cause for the "serving from" question

Resolution is a pure `MediaItem -> MediaSourceData` function.
`MediaSourceData` (`lib/features/media/domain/value_objects/media_source_data.dart`)
is a sealed union of **transport shapes** (`FileData`, `NetworkData`,
`BytesData`, `UnavailableData`), not of **origins**. A local disk read
(`local_file_resolver.dart:94`), a media-cache hit
(`media_store_resolver.dart:130`), and a fresh cloud download
(`media_store_resolver.dart:149`) all return a structurally identical
`FileData`, and are therefore indistinguishable to every caller and every
widget.

The provenance is known at the moment each value is constructed and discarded
immediately. Six lines in `MediaStoreResolver` (`:75`/`:86`, `:107`/`:117`,
`:130`/`:149`) are the only place in the codebase that knows cache from
network.

### 1.2 The two-path complication

The native-then-store fallback is implemented twice, independently:

- `MediaItemView._resolve` (`lib/features/media/presentation/widgets/media_item_view.dart:114-233`)
- `mediaBytesProvider` (`lib/features/media/presentation/providers/media_bytes_providers.dart:33-58`)

These are **not** duplicates that can simply be merged. `MediaItemView` carries
PDF page-1 rendering, thumbnail-versus-original branching, a `storeConfirmed`
stamp gate, and the `videoPosterMissing` / `documentRenderable` view hints.
`mediaBytesProvider` is a simpler full-resolution-only path. Their divergence
previously shipped issue #1019.

## 2. Goals

- Every media item can report its origin, its backup state, and its live
  serving source.
- The "serving from" readout reflects what actually painted the pixels, not an
  inference or a re-probe.
- Diagnosis is possible for a broken item: the user can see that the native
  source failed and the store served instead.
- Status is scannable at a glance in grids without opening anything.
- Where a problem is surfaced, the fix is reachable from the same place,
  reusing repair machinery that already ships.

## 3. Non-goals

- No new repair, verification, or cache-management logic. Actions are entry
  points into existing engines only.
- No cache pinning, forced re-download, or manual cache eviction.
- No schema change. Every displayed fact is an existing column.
- No unification of the two fallback paths. That is a worthwhile separate
  refactor; this design deliberately does not depend on it.
- No cleanup of the hard-coded English strings in
  `lib/features/media/presentation/pages/media_sources_page.dart`.

## 4. Approach

Provenance rides on the value object, stamped at each production site, rather
than being computed by consumers. Both fallback paths then inherit correct
provenance for free and cannot disagree, without either path being rewritten.

A small recorder captures the outcome of real resolutions so the info panel
can read what the on-screen image actually used, including the one fact the
resolvers cannot know: that the native source failed first.

Rejected alternatives:

- **Unify into a resolution service first.** Highest fidelity and would give a
  full attempt ladder, but the view concerns (PDF render, poster hints,
  document renderability) either migrate into the service and bloat it or stay
  outside and leave the unification partial. Large blast radius on the app's
  most load-bearing media widget.
- **Side-channel observer only.** Least invasive, but the fallback layer cannot
  see inside `MediaStoreResolver`, so cache-versus-network is unavailable, and
  that distinction is the entire bandwidth-awareness goal.

## 5. The provenance channel

### 5.1 Value object changes

In `lib/features/media/domain/value_objects/media_source_data.dart`:

```dart
enum ServedFrom {
  localDisk,        // LocalFileResolver, file read off a mounted volume
  platformGallery,  // photo_manager asset bytes
  storeCache,       // MediaCacheStore hit, no network touched
  storeNetwork,     // downloaded from the cloud store just now
  networkUrl,       // handed to cached_network_image to stream
  connectorCache,   // ConnectorMediaResolver's own cache
  connectorNetwork,
  embedded,         // signature BLOB on the row
}

/// Which of the three store tiers the bytes are. Distinct from [ServedFrom]:
/// the store can serve any tier from either cache or network.
enum ServedTier { original, thumbnail, rendition }

sealed class MediaSourceData {
  const MediaSourceData({
    this.servedFrom,
    this.servedTier = ServedTier.original,
  });
  final ServedFrom? servedFrom;
  final ServedTier servedTier;
}
```

Both fields are defaulted so every existing `const` construction site keeps
compiling. `UnavailableData` leaves `servedFrom` null: nothing served it.

### 5.2 Stamping sites

| File | Lines | Stamp |
| --- | --- | --- |
| `local_file_resolver.dart` | `:94`, `:146`, `:174` | `localDisk` |
| `local_file_resolver.dart` | `:235` (video poster) | `localDisk`, `tier: thumbnail` |
| `platform_gallery_resolver.dart` | `:62-66` | `platformGallery` |
| `platform_gallery_resolver.dart` | `:90` | `platformGallery`, `tier: thumbnail` |
| `signature_resolver.dart` | `:26`, `:32` | `embedded` |
| `http_url_media_resolver.dart` | `:100` | `networkUrl` |
| `connector_media_resolver.dart` | `:98`, `:127`, `:137` | `connectorCache` |
| `connector_media_resolver.dart` | `:145` | `connectorNetwork` |
| `media_store_resolver.dart` | `:75` / `:86` | `storeCache` / `storeNetwork`, `tier: thumbnail` |
| `media_store_resolver.dart` | `:107` / `:117` | `storeCache` / `storeNetwork`, `tier: rendition` |
| `media_store_resolver.dart` | `:130` / `:149` | `storeCache` / `storeNetwork`, `tier: original` |

Line numbers are as of commit `1d0a69c3360` and must be re-derived at
implementation time.

Neither `MediaItemView._resolve` nor `mediaBytesProvider` computes provenance;
the value arrives already stamped and passes through.

**One exception.** `MediaItemView`'s PDF page-1 branch
(`media_item_view.dart:124-137`) constructs a fresh `BytesData` from a render
rather than returning the resolver's own value. It must carry through the
provenance of the `resolver.resolve()` call that fed the renderer, with
`tier: thumbnail`.

### 5.3 The recorder

A plain service, deliberately **not** a `StateNotifier`: the grid must not
rebuild when a tile finishes resolving.

```dart
class MediaServingRecorder {
  void record(
    String mediaId, {
    required bool thumbnail,
    ServedFrom? from,
    ServedTier tier,
    UnavailableKind? failure,
    bool storeFallbackUsed,
  });

  ServingObservation? lastFor(String mediaId, {required bool thumbnail});
  Listenable listenableFor(String mediaId);
}
```

Observations are keyed by `(mediaId, thumbnail)` because a tile resolves a
thumbnail while the viewer resolves an original, and both are interesting.
Storage is a bounded LRU of roughly 200 entries so scrolling a large library
does not accumulate.

Written at the end of `MediaItemView._resolve` and at the end of
`mediaBytesProvider`. Read only by the info panel.

`storeFallbackUsed` is the single fact the fallback layer knows and the
resolvers do not. It is what turns "the cloud served this" into "your photo
library lookup failed, and the cloud served this", which is the diagnosis the
user asked for.

## 6. The provenance model

New file `lib/features/media/domain/entities/media_provenance.dart`:

```dart
class MediaProvenance {
  final OriginFacts origin;    // where it was linked from
  final BackupFacts backup;    // whether the cloud store has it
  final ServingFacts serving;  // what actually painted the pixels
}
```

### 6.1 OriginFacts

Pure row reads, no I/O.

- `sourceType`, plus the human-meaningful pointer for that type:
  `platformAssetId` for gallery, `localPath` or `bookmarkRef` for local files,
  `url` for network and manifest rows, `contentHash` for `mediaStore` rows,
  `connectorAccountId` plus `remoteAssetId` for connectors.
- `originDeviceId`, so the panel can distinguish "linked on this device" from
  "linked on your iPad".
- Health, derived from `isOrphaned` and `lastVerifiedAt`, as one of `healthy`,
  `missing`, or `neverVerified`, carrying the verification date.

**Naming trap.** In this codebase `isOrphaned` means *the file is missing* and
is orthogonal to *the row has no dive or site link* (which the orphan sweep
calls unlinked). `OriginFacts.health` maps from `isOrphaned` only.
`retainInLibrary` is unrelated and must not appear here.

Health is derived from stored state rather than probed, so that opening the
panel never does source I/O and so that the badge (section 8) can share the
same provider on every grid tile. An explicit **Check now** action performs the
probe on demand via the existing `MediaSourceResolver.verify` contract
(`lib/features/media/domain/services/media_source_resolver.dart:57`).

### 6.2 BackupFacts

- `storeAttached`, plus the store identity hint from
  `mediaStoreStatusHintProvider`
  (`lib/features/media_store/presentation/providers/media_store_providers.dart:496-503`),
  which already yields `"bucket @ host"`.
- Per-tier upload state from `remoteThumbUploadedAt`, `remoteUploadedAt`, and
  `remoteCompressedUploadedAt`, so "thumbnail only, original not sent" is
  expressible. That state exists today and is invisible.
- Live queue state from the `media_transfer_queue` row for this media id, the
  same watch `mediaBadgeStateProvider` already performs, including the failure
  message.
- `notUploadable` when `sourceType` falls outside `kUploadableSources`
  (`lib/features/media_store/domain/media_backup_status.dart:7-11`), so a URL
  row reads as "not eligible for backup" rather than an alarming "not backed
  up".

### 6.3 ServingFacts

From the recorder: `servedFrom`, `servedTier`, `storeFallbackUsed`, the
`UnavailableKind` if resolution failed, and the observation timestamp.

Null when the item has not been rendered yet in this session. The panel then
says "not loaded yet" rather than guessing.

### 6.4 Exposure

`mediaProvenanceProvider = Provider.family<MediaProvenance, MediaItem>`.

**AMENDED 2026-08-16, during PR 2a planning.** The original claim here was that
this provider is "synchronous and cheap: every input is either a row field or
an already-watched provider". That is wrong, and it matters, because the
section 8 badge was to derive from the same object on every grid tile.

`mediaStoreStatusHintProvider` awaits `mediaStoreRuntimeProvider`, and building
that runtime does a keychain read, constructs the object store, kicks a
transfer-queue drain and can trigger an auto verify sweep.
`mediaStoreAttachedProvider` exists precisely so per-tile widgets never reach
it. Deriving the badge from a model that resolves store identity would have put
a runtime construction behind every visible tile.

The model is therefore split along the cost boundary rather than the conceptual
one:

- `mediaProvenanceProvider = Provider.family<MediaProvenance, MediaItem>` holds
  origin and backup facts, watching only row fields, the per-item transfer-queue
  row, and `mediaStoreAttachedProvider`. Cheap enough for every tile, and PR 3's
  badge consumes it.
- `mediaStoreIdentityProvider = FutureProvider<MediaStoreIdentity?>` resolves
  the store's provider type and display hint. Panel-only by contract; never
  watched from a tile.

Same facts, two access costs. PR 2a's provider test pins this by overriding the
runtime provider with a throwing builder and asserting `mediaProvenanceProvider`
still resolves, so the expensive dependency cannot be reintroduced silently.

`ServingFacts` is likewise not a member of `MediaProvenance`. It comes from
`MediaServingRecorder`, a `ChangeNotifier`, which the panel reads through a
`ListenableBuilder`. Wrapping it in a provider would collide with Riverpod 3
auto-pause, which trips an assertion on providers that self-invalidate from a
listener the framework cannot see; the repo's fix for that
(`Ref.invalidateSelfWhen`) takes a `Stream<void>`, which a `ChangeNotifier` is
not.

## 7. The info panel

New widget `lib/features/media/presentation/widgets/media_info_panel.dart`,
plus a `showMediaInfoSheet(context, item)` launcher.

**AMENDED 2026-08-16.** The original wording called for "a draggable bottom
sheet on compact widths, a right-hand panel inside the viewer on wide ones".
The repo has `ResponsiveBreakpoints` and a `MasterDetailScaffold`, but **no
transient panel in this app branches on them**: every one is
`showModalBottomSheet(isScrollControlled: true)` at all widths, including all
four existing media-feature sheets. The tall-content template is
`scan_results_dialog.dart:398-410`, a `DraggableScrollableSheet` inside the
modal sheet. Following the repo beats following this spec.

### 7.1 Blocks

**1. File.** `originalFilename`, `width` x `height`, `contentSizeBytes` (and
`compressedSizeBytes` when a rendition exists), media type, `takenAt`,
coordinates when present. All units respect the active diver's unit settings
per project convention. Every one of these is on the row today and none is
displayed anywhere in the app.

**2. Origin.** Source type label, the pointer for that type, the origin device
when it is not this one, and health with its verification date.

**3. Backup.** Store identity, per-tier state, queue state or failure text.

**4. Serving now.** `servedFrom` and `servedTier` as one sentence, with the
fallback note when `storeFallbackUsed` is set, for example: "Photo library
lookup failed; served from cloud store."

### 7.2 Actions

All reuse existing machinery. No new repair logic.

| Action | Wires to |
| --- | --- |
| Check now | `MediaSourceResolver.verify` (`media_source_resolver.dart:57`) |
| Locate | `MediaRepairService` / repair wizard, scoped to one item |
| Reveal in Finder, Copy path | platform reveal helper, desktop `localFile` rows only |
| Back up now, Retry | existing transfer-queue enqueue and retry |
| Re-upload | existing `MediaReuploadButton` (`media_reupload_button.dart:12-50`) |

**RESOLVED 2026-08-16.** `MediaRepairWizardPage`'s constructor is
`const MediaRepairWizardPage({super.key})` and its notifier is hardcoded to
page the entire library, so it has **no single-item scope**. It does not need
one: `MediaRepairService.apply(List<RepairProposal>)` accepts a one-element
list and is already a usable single-item entry point, and the single-item
repair flow **already exists** as the private `_replaceLink(MediaItem)` at
`dive_media_section.dart:265` (file picker, hash verify, `apply` with one
proposal). **Locate** therefore extracts that existing private flow into a
shared helper. No repair logic is added.

**Also resolved, and this one does need new code.** "Check now" was specced as
calling the resolver contract's existing `verify(item)`. That contract exists,
but the only caller that PERSISTS a result is
`LocalFilesDiagnosticsService.reverifyAll()`, which is a bulk sweep AND is
hardcoded to `LocalFileResolver` rather than dispatching through
`MediaSourceResolverRegistry`. A per-item, any-source-type verify is genuinely
new, roughly 15 lines. `MediaRepository.markAsVerified(id)` already exists,
sets `isOrphaned` and `lastVerifiedAt` in one write, and is currently called
from nowhere. Both belong to PR 2b.

### 7.3 Entry points

- An info button in the viewer's `_TopOverlay`
  (`lib/features/media/presentation/pages/media_viewer_page.dart:1101-1226`),
  which today has close, page indicator, go-to-dive, write-metadata, Perdix
  toggle, Lightroom, share, and re-upload, but no info affordance.
- Tile **right-click** (`onSecondaryTapDown` plus `showMenu`) in both grids,
  matching `dive_media_section.dart:595-600`. **AMENDED 2026-08-16:** the
  original said long-press, which the gesture system does not allow.
  `MediaThumbnailTile` has no gesture callbacks at all, and its enclosing
  `DragSelectGridView` deliberately registers no long-press recognizer so that
  a hold falls through to the tap recognizer (commit `899d7f58baa`, "remove
  long-press as a way into multi-select"); adding one would both break that
  intent and win the gesture arena against the grid's own drag-anchor
  recognizer during selection. `MediaLibraryTile.onLongPress` is already
  claimed by selection toggling. Consequence, accepted: right-click is
  desktop-only, so on a phone the grid has no tile-level route to the panel and
  the viewer's info button is the way in. This entry point ships with PR 3,
  alongside the badge that shares it.
- `MediaMissingView` tiles, whose `onTileTap` is currently a literal no-op
  (`lib/features/media/presentation/pages/media_missing_view.dart:107`).
  Wiring it to the panel makes the Missing view answer why an item is missing,
  in the place a user would look.

### 7.4 Localization

All strings go through the 11 ARB catalogs, which must stay at exact key
parity. Roughly 35 to 45 new `media_info_*` keys.

## 8. The tile badge

Extends the existing `MediaStoreBadge`
(`lib/features/media_store/presentation/widgets/media_store_badge.dart:12-42`)
rather than replacing it. Four of the six states already exist; this is mostly
a priority ladder plus two new states.

### 8.1 Ladder, first match wins

| Priority | State | Glyph | Condition |
| --- | --- | --- | --- |
| 1 | `broken` (new) | `error_outline`, error tint | origin health is `missing` **and** `isBackedUp` is false |
| 2 | `transferFailed` | `cloud_off`, error tint | queue row failed |
| 3 | `transferring` / `queued` | `cloud_upload` / `schedule` | live queue row |
| 4 | `notBackedUp` | `cloud_off` | store attached, source uploadable, no upload stamp |
| 5 | `cloudOnly` (new) | `cloud` | origin health is `missing` **and** `isBackedUp` is true |
| n/a | `none` | nothing | healthy and backed up |

`broken` and `cloudOnly` are the same local condition split by whether the
store can cover for it, and the split is what keeps the badge honest. An item
whose local file is gone but whose bytes are in the store is not broken: it
still displays, it just streams. An item whose local file is gone and which
was never uploaded cannot be displayed at all. `isBackedUp` is the existing
predicate in `media_backup_status.dart:23-25`, reused rather than restated, so
the badge and the upload pipeline can never disagree about what "backed up"
means.

Note that both conditions read `OriginFacts.health`, which is derived from
`isOrphaned`, and neither reads `ServingFacts`. The badge is therefore
well-defined for an item that has never been rendered, which is the normal
case for a tile scrolling into view.

Transfer state deliberately outranks `notBackedUp`. A queued item is by
definition not yet backed up, so the reverse ordering would mean the transfer
glyph never appears: every in-flight item would render as `cloud_off`.
Transfer state is transient, self-resolving, and more informative.

### 8.2 Gating rules

Both are correct in the current badge and are easy to lose.

- Sources outside `kUploadableSources` never reach states 3 through 5. A URL
  row is not eligible for backup, not failing at it.
- `broken` renders **even when no store is attached**. Today the whole badge is
  suppressed by `mediaStoreAttachedProvider`
  (`media_store_providers.dart:262`), so the attach gate moves from wrapping
  the badge to guarding states 2 through 5 only.

### 8.3 Mounting

- `MediaThumbnailTile` already has the slot at
  `lib/features/media/presentation/widgets/media_grid.dart:138` (top-left;
  top-right is the selection checkmark, bottom-right holds the video, document
  and depth chips).
- `MediaLibraryTile`
  (`lib/features/media/presentation/widgets/media_library_grid.dart:8-52`)
  gains the same slot. This is the fix for the entire Media console currently
  rendering badge-less grids.

Each badge carries a `Tooltip`. Tapping it opens the info panel scrolled to
the block that explains it.

### 8.4 Cost

`mediaBadgeStateProvider` already watches a per-item queue stream on every
tile, so the per-tile subscription count does not change. The two new states
derive from `isOrphaned` and the upload stamps, both plain row fields, so no
tile performs I/O.

## 9. Testing

TDD per project convention. Tests are written before implementation.

- **Per-resolver unit tests** asserting the stamp on every return.
- **The load-bearing test:** `MediaStoreResolver` against a fake
  `MediaObjectStore` plus a real `MediaCacheStore`, proving a cache hit stamps
  `storeCache` and a miss stamps `storeNetwork`, on all three tiers. This
  single test is the difference between the feature being true and being
  decorative.
- **Badge ladder** as a pure function over `MediaProvenance`, table-driven
  across all six states plus both gating rules.
- **Recorder tests:** `storeFallbackUsed` is set when the native resolver
  returns `UnavailableData` and the store then serves; the LRU bound holds
  under a large scroll.
- **Widget tests** for each panel block and each action dispatching to a fake.
- **Regression:** existing media tests stay green unchanged. This design adds
  information and changes no behavior.

### 9.1 Known repo traps this work walks into

1. **Adding l10n to a shared widget breaks consumer tests.**
   `MediaLibraryTile` and the badge are rendered by many test-hosted trees;
   localized tooltips will fail every consumer widget test that does not host
   localizations. Budget for the fanout.
2. **New providers must be registered in the tick-subscription contract test.**
   The repo has a test enumerating media providers that has caught this
   omission before.
3. **pdfrx cannot render under `flutter_test`.** The PDF page-1 provenance
   pass-through can only be unit-tested, never widget-tested. Issue #1019
   shipped because a bug hid behind exactly that mock.

## 10. Delivery

Three stacked PRs, each in its own worktree per `CLAUDE.md`.

| PR | Contents | Why separable |
| --- | --- | --- |
| 1 | `ServedFrom`, `ServedTier`, the stamping sites, `MediaServingRecorder`, recorder writes in both fallback paths | Pure plumbing, no UI, fully unit-testable, zero user-visible change |
| 2a | `MediaProvenance` and its two providers, the READ-ONLY info panel, viewer and Missing-view entry points, ARB keys x11 | The feature proper |
| 2b | The actions layer: Check now, Locate, Back up now / Retry, Reveal, Copy path | Separable, different risk profile |
| 3 | Badge ladder, `MediaLibraryTile` slot, badge-to-panel tap, Missing-view tap | Depends on PR 2 for its tap target |

## 11. Risks

- The stamping edit is wide but shallow: roughly 15 sites across 6 resolver
  files, one argument each. Low risk individually, easy to miss one. A test
  per resolver is the guard.
- ARB parity across 11 catalogs for roughly 40 keys is the most tedious part
  and the most likely source of CI failure.
- The badge may read as noisy on first run with a store attached, since
  nothing is backed up until backfill runs. That is the existing
  `notBackedUp` behavior rather than something new, but extending it to the
  console grids makes it far more visible.
