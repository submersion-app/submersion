# Local media: auto-upload on import, and a not-backed-up tile indicator

Date: 2026-07-23
Branch: `worktree-media-local-upload-badge`

## Problem

Media thumbnails in dive details show an upload-state overlay icon for media
sourced from Apple Photos, but locally sourced photos show no overlay.

The overlay itself is not the defect. `MediaStoreBadge` is rendered
unconditionally for every tile (`dive_media_section.dart:635`) and is not
gated on source type. Its state comes from `mediaBadgeStateProvider`, which
maps the newest media transfer queue row for the item; no row resolves to
`MediaBadgeState.none`, which renders `SizedBox.shrink()`.

The absent overlay is the UI correctly reporting "no transfer in flight".
The real defect is upstream: locally imported media is never enqueued, so it
silently never auto-uploads.

Everything downstream of the enqueue already supports local files:

- `media_upload_pipeline.dart:69-73` lists `localFile` in `_eligibleSources`.
- `media_repository.dart:928-932` includes `localFile` in the backfill query.

The gap is the enqueue hook. `mediaStoreEnqueueProvider` is wired at exactly
two call sites: the photo picker (`photo_picker_providers.dart:243`) and
Lightroom (`lightroom_providers.dart:111`). The Files-tab import path,
`FilesTabNotifier._persistOne` (`files_tab_providers.dart:181-232`), calls
`mediaRepository.createMedia` and returns the id without calling any hook.

Consequence: a photo added through the Files tab is never auto-uploaded. It
stays local-only until the user manually runs "Upload existing library"
backfill, with no indication anywhere in the UI that this is the case.

## Goals

1. Locally imported media auto-uploads on import, exactly as gallery media
   does.
2. When a media store is attached, media that is not backed up is visually
   distinguishable from media that is.
3. Every item that can display the not-backed-up indicator has a path to
   clearing it.

## Non-goals

- No change to the badge's "quiet on success" philosophy
  (`media_store_badge.dart:7-9`). A fully backed-up library shows no icons.
- No indicator at all when no media store is attached. Most users have none,
  and marking every tile would read as a broken state.
- No new user-facing strings. The badge is icon-only today and stays
  icon-only, avoiding a 10-locale l10n sweep. Per-state semantics labels are
  a separate, later improvement.
- No change to which quality level uploads use.

## Design

### 1. Wire the enqueue hook into the Files-tab import path

`FilesTabNotifier` gains an optional `onMediaCreated` callback, mirroring the
one `MediaImportService` already exposes (`media_import_service.dart:64`).

`_persistOne` calls `onMediaCreated?.call(saved.id)` after `createMedia`
(`files_tab_providers.dart:230`).

`filesTabNotifierProvider` (`files_tab_providers.dart:235-242`) wires it to
`ref.watch(mediaStoreEnqueueProvider)`, the same one-liner used at
`photo_picker_providers.dart:243`.

Nothing else changes. `mediaStoreEnqueueImplProvider`
(`media_store_providers.dart:282-290`) already no-ops when auto-upload is
disabled or no store is attached, so this is inert for users without a store.

### 2. Shared backup-status predicate

New file: `lib/features/media_store/domain/media_backup_status.dart`.

Pure functions, no Riverpod and no database dependency, so they are directly
unit-testable:

- `kUploadableSources` — the `Set<MediaSourceType>` currently inlined as
  `_eligibleSources` in `media_upload_pipeline.dart:69-73`. The pipeline
  imports the shared constant and keeps its own
  `resolver.canResolveOnThisDevice(item)` and instructor-signature checks
  locally, since those need the resolver registry.
- `bool isBackedUp(MediaItem item)` — for thumb-only items (a
  `serviceConnector` video, matching `_isThumbOnly` at
  `media_upload_pipeline.dart:81-83`), `remoteThumbUploadedAt != null`;
  otherwise `remoteUploadedAt != null || remoteCompressedUploadedAt != null`.
  This mirrors the pipeline's own dedup check at
  `media_upload_pipeline.dart:93-99`.

Moving `_eligibleSources` to a shared constant is the only pipeline change;
its behavior is unchanged.

### 3. `notBackedUp` badge state

`MediaBadgeState` gains a `notBackedUp` member. The priority ladder,
highest first:

| State         | Icon            | Container            |
| ------------- | --------------- | -------------------- |
| `failed`      | `error_outline` | `errorContainer`     |
| `transferring`| `cloud_upload`  | `primaryContainer`   |
| `queued`      | `schedule`      | `surfaceContainerHighest` |
| `notBackedUp` | `cloud_off`     | `surfaceContainerHighest`, muted |
| `none`        | nothing         | nothing              |

Transient transfer state always wins over persistent backup state: an
in-flight upload and a failure are the more actionable signals.

`MediaStoreBadge` gains one arm in its existing switch
(`media_store_badge.dart:22-29`). It stays a dumb renderer; all decision
logic lives in the provider so it can be tested without a widget tree.

New provider `mediaStoreAttachedProvider`, a `FutureProvider<bool>` reading
`ref.watch(mediaStoreAttachStateProvider).attachedStoreId() != null`.

This is deliberately **not** `mediaStoreRuntimeProvider`. That provider
constructs the full store runtime and kicks a queue drain
(`media_store_providers.dart:158`); watching it from every visible
thumbnail tile would trigger that work merely by scrolling a dive's media
grid. The attach check only needs one SharedPreferences read.

`mediaBadgeStateProvider` becomes an `async*` stream:

1. Await `mediaStoreAttachedProvider` once, at subscription.
2. Map each queue emission: `failed`, `transferring`, and `pending` pass
   through unchanged, with no row re-read.
3. For a `done` or absent row, compute the settled state **at that
   emission**: `notBackedUp` when the store is attached, the item's source
   is in `kUploadableSources`, and the freshly re-read row is not backed up;
   otherwise `none`.

Step 3 must be evaluated per emission rather than once at subscription.
Computing it upfront would cache a pre-upload answer and defeat the
freshness requirement below.

#### Freshness: re-read the row, do not trust the tile snapshot

`mediaForDiveProvider` (`media_providers.dart:13-22`) is a `FutureProvider`
invalidated only by `watchDiveDetailChanges()`. Writing `remoteUploadedAt`
to a media row does not fire that stream, so the `MediaItem` held by a tile
is a stale snapshot for as long as the dive detail stays open.

Evaluating `isBackedUp` against that snapshot would leave a `cloud_off` icon
stuck on a photo that just finished uploading, until the user leaves and
re-enters the dive.

Therefore the settled-state computation re-reads the row via
`mediaRepositoryProvider.getMediaById(item.id)` rather than using the
family-key snapshot.

This is race-free by construction: the pipeline calls `stampRemoteUploaded`
at `media_upload_pipeline.dart:261`, strictly before `markDone` at
`media_upload_pipeline.dart:276`. The queue emission that reports `done`
therefore always follows the stamp write, so the re-read observes it.

It also survives `deleteDone` (`media_transfer_queue_repository.dart:279`)
purging the completed row while the page is open: with no row, the fallback
is recomputed from fresh persisted stamps and still resolves to `none`.

#### Degradation

The whole settled-state computation is wrapped so that any failure resolves
to `none`, extending the existing `StateError` guard at
`media_store_providers.dart:132-134`.

This matters for tests. `media_store_badge_test.dart:28-31` builds a
`ProviderContainer` overriding only `mediaTransferQueueRepositoryProvider`,
and its fixture is a `localFile` item with no remote stamps — precisely the
shape that would newly resolve to `notBackedUp`. With the guard, those tests
continue to observe `none` without modification, and new `notBackedUp`
coverage supplies its own overrides explicitly.

### 4. Backfill covers non-connector videos

`getBackfillCandidateIds` (`media_repository.dart:920-944`) restricts
`platformGallery`/`localFile`/`serviceConnector` candidates to
`fileType = 'photo'`. Videos are only picked up for `serviceConnector`, via
the thumb-only branch.

Without a change here, a local video imported before this fix would display
`notBackedUp` permanently with no way to clear it: import-time enqueue only
helps new imports, and backfill would skip it. That violates goal 3.

The photo branch's `fileType` restriction is dropped so that
`platformGallery` and `localFile` videos with no upload stamps become
backfill candidates. The `serviceConnector` thumb-only branch is unchanged.

This is a deliberate behavior change: "Upload existing library" will begin
uploading videos, which is a meaningful bandwidth increase for users with
large local video libraries. It is accepted here because the alternative
leaves an unclearable indicator on screen.

## Data flow

Import (new):

```
Files tab -> FilesTabNotifier._persistOne
  -> mediaRepository.createMedia
  -> onMediaCreated(id) -> mediaStoreEnqueueProvider
  -> worker.enqueueAndKick(id)          [no-op if no store / auto-upload off]
```

Badge (new):

```
mediaStoreAttachedProvider ---+
                              v
queue.watchLatestForMedia --> mediaBadgeStateProvider --> MediaStoreBadge
                              ^
mediaRepository.getMediaById -+   [settled states only]
```

## Testing

Unit, `media_backup_status.dart`:

- `isBackedUp` false when all three stamps are null.
- True on `remoteUploadedAt`, and separately on
  `remoteCompressedUploadedAt`.
- Connector video: true on `remoteThumbUploadedAt` alone; a connector
  *photo* with only a thumb stamp is not backed up.
- `kUploadableSources` excludes `networkUrl`, `manifestEntry`, `signature`.

Provider, `mediaBadgeStateProvider`:

- Store not attached, unbacked local item, no queue row -> `none`.
- Store attached, unbacked local item, no queue row -> `notBackedUp`.
- Store attached, backed-up local item -> `none`.
- Store attached, unbacked `networkUrl` item -> `none` (ineligible source).
- Store attached, unbacked item with a `pending` row -> `queued`
  (transfer wins over backup state); likewise `transferring` and `failed`.
- Store attached, item whose row goes `done` after stamps are written ->
  `none`, asserting the re-read rather than the stale snapshot.
- Media repository unavailable -> `none` (degradation guard).

Widget, `MediaStoreBadge`:

- Renders a `cloud_off` avatar for `notBackedUp`.
- Renders nothing for `none`.

Import wiring, `FilesTabNotifier`:

- `_persistOne` invokes `onMediaCreated` with the saved id.
- A null `onMediaCreated` does not throw.

Repository, `getBackfillCandidateIds`:

- An unbacked `localFile` video is now a candidate.
- An unbacked `platformGallery` video is now a candidate.
- A backed-up video is not a candidate.
- Existing photo and connector-thumb assertions still hold.

## Risks

- **Bandwidth.** Backfill now includes videos. Accepted, per section 4.
- **Per-tile reads.** The badge provider performs one extra `getMediaById`
  per settled emission. Bounded by visible tiles and only on queue-state
  changes, not on every rebuild.
- **Existing badge tests.** Covered by the degradation guard; verified as
  part of implementation rather than assumed.
