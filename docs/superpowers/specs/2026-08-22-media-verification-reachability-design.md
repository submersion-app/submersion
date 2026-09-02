# Media Verification Reachability: Design

**Status:** approved 2026-08-22
**Branch:** `worktree-media-serving-status-badges`
**Supersedes nothing.** Complements PR #1125 (the status badge) and the
2026-08-20 media availability work.

## Problem

The status badge added by PR #1125 renders nothing on a device with no media
store attached, and the user reported this as "I don't see any badges on media
thumbnails".

Investigation showed the badge is correct. The defect is one layer down.

### Measured evidence

Taken from the reporting device's live database on 2026-08-22 (453 media rows):

| Fact | Value |
| --- | --- |
| `SELECT COUNT(*) FROM media` | 453 |
| `source_type` distribution | `platformGallery` for all 453 |
| `is_orphaned = 1` | 0 |
| `last_verified_at IS NOT NULL` | 0 |
| upload stamps (original / thumb / compressed) | 0 / 0 / 0 |
| `media_stores` rows | 0 |
| `media_transfer_queue` rows | 0 |
| prefs key `flutter.media_store_attached_store_id` | absent |

With no store attached, `mediaStatusFor` can only reach `MediaStatus.broken`,
and `broken` derives entirely from `MediaItem.isOrphaned`. That column is 0 for
every row and nothing will ever change it. See F1.

## Findings

Every claim below was verified by reading the cited lines in this worktree.

**F1. Nothing verifies a `platformGallery` row.**
`LocalFilesDiagnosticsService.reverifyAll` opens with
`getAllBySourceType(MediaSourceType.localFile)`
(`lib/features/media/data/services/local_files_diagnostics_service.dart:91`).
It is the only bulk sweep that writes `isOrphaned`. `MediaItemVerifier`
(`lib/features/media/data/services/media_item_verifier.dart:29`) handles any
source type but is a single-item call behind a manual action. Consequently a
library made of gallery rows never has `isOrphaned` or `lastVerifiedAt`
written after link time, and the `broken` badge is structurally unreachable
for it.

**F2. The serving layer discovers the same fact constantly and discards it.**
`MediaItemView._resolve`
(`lib/features/media/presentation/widgets/media_item_view.dart:137-160`)
records every resolution outcome, including
`UnavailableKind.notFound`, into `MediaServingRecorder`. That recorder is a
`ChangeNotifier` holding a 200-entry in-memory LRU
(`lib/features/media/data/services/media_serving_recorder.dart:44-57`) which
dies with the process. A deleted gallery asset is detected on every scroll
past its tile and written down nowhere.

**F3. `is_orphaned` is read by more than the badge.** It drives
`OrphanedMediaPlaceholder` (`media_grid.dart:91`), `OriginFacts.health`
(`media_provenance.dart:96`), and the orphan sweeps. A permanently-zero column
understates library damage everywhere it is read.

**F4. Serving failures are already surfaced in-tile, so a new badge state
would be redundant.** `UnavailableMediaPlaceholder`
(`lib/features/media/presentation/widgets/unavailable_media_placeholder.dart:47-78`)
maps all seven `UnavailableKind` values to an icon and a localized reason, and
`MediaItemView` renders it whenever a resolution fails. Both grids route
through it. This is why this design adds no `MediaStatus` values.

**F5. `updateMedia` is a sync-visible, 30-column write.**
`lib/features/media/data/repositories/media_repository.dart:293-364` writes
every column from the passed snapshot, then calls
`_syncRepository.markRecordPending` and `SyncEventBus.notifyLocalChange`. Two
consequences:
- A write per viewed tile would mark every viewed row pending for sync.
- Passing a stale in-memory `MediaItem` clobbers columns the caller never
  meant to touch. The tile's snapshot comes from a `FutureProvider` that an
  upload's stamp write does not invalidate, so it goes stale the moment an
  upload completes.

`markOrphaned` (`media_repository.dart:550-572`) is the correct narrow
primitive: it writes `isOrphaned` and `updatedAt` only. It does not stamp
`lastVerifiedAt`.

**F6. SAFETY HAZARD. Revoked photo permission is indistinguishable from a
deleted asset, and today already orphans rows.**

`ResolutionStatus` has exactly two values, `resolved` and `unavailable`
(`lib/features/media/data/services/asset_resolution_service.dart:10-16`). It
cannot express "I was unable to check".

`AssetResolutionService.resolveAssetId` returns `unavailable` when the
permission check throws, and when permission is anything other than
`authorized` or `limited`
(`asset_resolution_service.dart:160-176`).

`PlatformGalleryResolver._resolveId` maps `unavailable` to `null`, and
`verify` maps `null` to `VerifyResult.notFound`
(`lib/features/media/data/resolvers/platform_gallery_resolver.dart:149-167`).

`MediaItemVerifier.verify` then writes `isOrphaned = true`
(`media_item_verifier.dart:60-70`).

So on a device with revoked or not-yet-granted photo permission, verifying a
gallery row marks it orphaned today. This is a latent bug, not one this design
introduces. It is currently low-impact only because F1 means almost nothing
calls it. Both changes in this design would raise its blast radius to the
whole library, and the damage would replicate: every flipped row calls
`markRecordPending` and syncs to every other device.

`AssetResolutionService` already understands the danger. It explicitly refuses
to cache an unresolved result under denied permission, because "caching would
apply the 24h+ backoff to a transient, user-recoverable condition"
(`asset_resolution_service.dart:152-159`). It just has no way to tell its
caller.

**F6b. The SERVING path collapses the same distinction, and it is the path
that feeds Part 2.** `PlatformGalleryResolver.resolve` and
`resolveThumbnail` return `UnavailableData(kind: UnavailableKind.notFound)` at
all six of their failure exits
(`platform_gallery_resolver.dart:49,53,60,64,77,88`). `resolveThumbnail`
delegates to `_fetchThumbnail`, whose `Uint8List?` return type discards the
reason entirely, and which returns null when `_resolveId` returns null, which
is what `accessDenied` produces (`:103-104`).

Grid tiles call `resolveThumbnail`. So on a permission-revoked device every
tile serves `notFound`, and a reconciler keyed on `UnavailableKind` alone
would orphan the entire library. `ResolutionStatus.accessDenied` is therefore
necessary but NOT sufficient: `UnavailableKind` needs the same third value,
and the gallery resolver's serving path has to produce it.

`GalleryThumbnailCache.getOrFetch` deliberately does not cache nulls
(`gallery_thumbnail_cache.dart:99-103`), so re-deriving the reason on the
failure path costs nothing in the common case and cannot be poisoned by a
cached miss.

**F7. Every resolver implements `verify`.** `platform_gallery_resolver.dart:149`,
`http_url_media_resolver.dart:131`, `connector_media_resolver.dart:66`,
`signature_resolver.dart:52`, `local_file_resolver.dart:381`,
`media_store_source_resolver.dart:75`. `verify` is declared on the abstract
`MediaSourceResolver` (`lib/features/media/domain/services/media_source_resolver.dart:57`),
so a registry-dispatched sweep across all source types is possible with no new
resolver work.

## Design

Three parts. Part 1 is a precondition for the safety of parts 2 and 3 and must
land first.

### Part 1: make "could not check" expressible

Add a third value to `ResolutionStatus`:

```dart
enum ResolutionStatus {
  resolved,
  unavailable,

  /// The gallery could not be consulted, so nothing was learned about the
  /// asset. Distinct from [unavailable], which is a positive finding that no
  /// matching asset exists. Never a reason to orphan a row: the asset is
  /// probably fine and the user can restore access.
  accessDenied,
}
```

`AssetResolutionService.resolveAssetId` returns `accessDenied` at both sites
that currently return `unavailable` for a permission reason
(`asset_resolution_service.dart:167` on a thrown check, `:175` on a
non-authorized status).

Add a matching `VerifyResult.accessDenied`, and have
`PlatformGalleryResolver.verify` return it when `_resolveId` reports
`accessDenied`. `_resolveId` must therefore return the status rather than
collapsing it to a nullable id.

Both existing consumers of `VerifyResult` already have a transient branch that
stamps `lastVerifiedAt` and leaves `isOrphaned` untouched
(`media_item_verifier.dart:60-64`,
`local_files_diagnostics_service.dart:100-106`). `accessDenied` joins
`volumeOffline` and `transientError` there.

Add a third `UnavailableKind.accessDenied` for the serving path (F6b), and
have the gallery resolver produce it. `resolve` can read the status directly.
`resolveThumbnail` cannot, because `_fetchThumbnail` returns `Uint8List?` and
has already discarded the reason, so on a null it re-derives the status:

```dart
    if (bytes == null) {
      // Failure path only, and getOrFetch never caches a null, so this costs
      // nothing in the common case. resolveAssetId short-circuits at the
      // permission check before any gallery query.
      final status = (await _resolutionService.resolveAssetId(item)).status;
      return UnavailableData(
        kind: status == ResolutionStatus.accessDenied
            ? UnavailableKind.accessDenied
            : UnavailableKind.notFound,
      );
    }
```

`UnavailableMediaPlaceholder` has two exhaustive switches over
`UnavailableKind` (`unavailable_media_placeholder.dart:47-78`); both gain an
`accessDenied` arm, with `Icons.no_photography_outlined` and one new ARB key.

Together these fix the latent bug in F6 and close the F6b path before Part 2
can drive it.

### Part 2: passive reconciliation from the serving path

A new `MediaOrphanReconciler` service turns what the serving layer already
observed into a persisted fact, under strict write discipline.

```dart
/// Decides whether a completed resolution changes a row's orphan flag.
///
/// Pure. Returns null when nothing should be written, which is the common
/// case and the reason a library scroll costs no writes at all.
bool? reconciledOrphanFlag({
  required bool currentlyOrphaned,
  required UnavailableKind? failure,
})
```

Mapping, chosen so that only a positive finding may orphan a row:

| `failure` | Meaning | Desired flag |
| --- | --- | --- |
| `null` (bytes served) | positive finding: present | `false` |
| `notFound` | positive finding: absent | `true` |
| `unauthenticated` | positive finding: absent to us | `true` |
| `accessDenied` | the source refused to answer | leave alone |
| `signInRequired` | recoverable, user action | leave alone |
| `fromOtherDevice` | not a claim about this device | leave alone |
| `networkError` | transient | leave alone |
| `volumeOffline` | transient, documented never-orphan | leave alone |
| `stillFetching` | nothing is wrong, just slow | leave alone |

The function returns `null` whenever the desired flag equals
`currentlyOrphaned`, so a steady-state library performs zero writes no matter
how far it is scrolled. This is the constraint that makes F5 acceptable.

Wiring: `MediaItemView._resolve` calls the reconciler immediately after
`recorder.record(...)`, fire and forget, having already checked `mounted`. On
a decision it calls `MediaRepository.markVerified`, a new narrow write:

```dart
/// Writes the orphan flag and the verification stamp together, and nothing
/// else. Deliberately not updateMedia: that writes all 30 columns from the
/// caller's snapshot, and a grid tile's snapshot is routinely stale (F5).
Future<void> markVerified(String id, {required bool isOrphaned, required DateTime verifiedAt})
```

`markOrphaned` stays as is for its existing callers.

Because `platformGallery` failures route through `AssetResolutionService`,
Part 1 guarantees a permission problem arrives as `accessDenied` rather than
`notFound`, so it can never reach the `true` row of the table above.

### Part 3: a sweep that covers every source type

Extract the sweep loop out of `LocalFilesDiagnosticsService` into a new
`MediaVerificationSweep`:

```dart
/// Verifies every row of the given source types, or all rows when
/// [sourceTypes] is null, dispatching through the resolver registry.
Future<SweepOutcome> run({Set<MediaSourceType>? sourceTypes, void Function(int done, int total)? onProgress})
```

It reuses `MediaItemVerifier` per item rather than reimplementing the
persistence contract, which is what `MediaItemVerifier`'s own doc comment says
that contract exists for.

`LocalFilesDiagnosticsService` loses `reverifyAll` entirely and keeps only its
read path. The Settings page calls the sweep directly for both actions: with
`sourceTypes: {MediaSourceType.localFile}` for the existing Local files
re-verify tile, and unfiltered for the new one.

**Corrected during implementation.** The first attempt injected the sweep into
`LocalFilesDiagnosticsService` and delegated. That put
`mediaSourceResolverRegistryProvider` on the dependency path of
`localFilesDiagnosticsProvider`, so merely rendering two integers constructed
every resolver in the app, and the Media Sources page tests failed with
`ProviderException: Tried to use a provider that is in error state`. The read
path must stay cheap: a service that answers "how many rows are flagged" has
no business owning the machinery that checks them.

Settings gets a second action under Media Sources, "Check all media", calling
the sweep with no filter. It reports counts and, when any row came back
`accessDenied`, says so explicitly rather than reporting those rows as
healthy. A sweep that could not see the photo library must not look like a
clean bill of health.

## Out of scope

- **New `MediaStatus` values.** Serving failures are already reported in-tile
  by `UnavailableMediaPlaceholder` (F4). Adding a badge for them would be
  redundant double-reporting and would break the quiet-badge contract.
- **Ungating `notBackedUp` from `storeAttached`.** A badge on 100% of tiles
  carries no information, and the action it implies is a one-time global
  setup, not a per-item fix.
- **Automatic background sweeps on a timer.** Part 2 covers rows the user
  actually looks at; Part 3 covers the rest on demand. A scheduled sweep is a
  separate decision about battery and I/O.
- **Reporting `accessDenied` in the badge.** It is a device-wide condition,
  not a per-item one, so it belongs in the Media Sources settings section.

## Product decisions (do not relitigate)

- Only a positive finding may orphan a row. Every "I could not check" outcome
  leaves the flag alone. The cost of a false orphan is a diver being told a
  photo they still have is gone, and it replicates through sync.
- The passive path writes only on a flag change. It never writes merely to
  refresh `lastVerifiedAt`, because that would put one sync-pending row on the
  queue per thumbnail scrolled past.
- The passive path stamps `lastVerifiedAt` when it writes at all, since the
  write is already happening and the info panel should not show a flipped row
  as never verified.
- Reuse `MediaItemVerifier` in the sweep. Two implementations of the
  persistence contract would eventually disagree about the same row.
