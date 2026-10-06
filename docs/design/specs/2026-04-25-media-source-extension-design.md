# Media Source Extension — Design

**Date**: 2026-04-25
**Status**: Approved design, awaiting implementation plan
**Scope**: Extend dive media linking beyond platform photo libraries to support local files, network URLs, manifest feeds, and authenticated service connectors.

## Summary

Today, dive media (`MediaItem`) supports two source patterns: platform gallery references (via `platformAssetId`, backed by `photo_manager` for Apple Photos / Google Photos / iCloud) and signature files (via `filePath` or `imageData` BLOB). This design generalizes that two-source split into a polymorphic source-type abstraction that supports five additional source families:

- **Local files** on the device's filesystem (or via iOS security-scoped bookmarks / Android persistable URIs on mobile).
- **Network URLs** — single ad-hoc HTTP/HTTPS image and video URLs.
- **Manifest feeds** — Atom/RSS, JSON, or CSV manifests that enumerate multiple network media items, with optional subscription mode for periodic refresh.
- **Service connectors** — authenticated integrations with hosted photo services (Immich, Dropbox, OneDrive, Piwigo, Flickr, SmugMug, etc.).

All new sources use a **pure-reference** model: the app stores a pointer (path, URL, bookmark ref, or remote asset ID), never copies bytes into app-managed storage. Resolution happens on every display via a swappable `MediaSourceResolver` interface; orphan tracking, EXIF enrichment, dive-profile overlay, and cross-device sync work uniformly across all source types.

The work is divided into **five sequential phases** delivered as separate implementation projects sharing this design document.

## Goals

- Let users link to dive photos and videos that live anywhere they own — local disk, mounted network volumes, self-hosted galleries, public URLs, cloud photo services — without copying bytes into Submersion's storage.
- Ship a generalizable source abstraction so adding a new service connector is a single-file plugin rather than a new vertical slice.
- Make the existing platform-gallery flow work on the new abstraction with no visible behavior change.
- Support all current Submersion target platforms (iOS, Android, macOS, Windows, Linux) for every source type, with platform-appropriate persistence (security-scoped bookmarks on iOS, persistable URIs on Android).
- Preserve cross-device sync semantics: rows sync everywhere, but bytes resolve per-device based on what's reachable from each device.

## Non-Goals

- **Photo editing** (crop, rotate, white balance) — this design is read-only display and linking.
- **Two-way sync** (uploading from Submersion to remote services) — connectors are read-only.
- **Bulk re-host** (moving an item from one source type to another) — out of scope.
- **Federated search across all sources** — search remains per-dive.
- **Photo deduplication across source types** — same photo from gallery and URL becomes two `MediaItem` rows.
- **Google Photos** — Library API restrictions for new third-party apps make this impractical; the replacement Picker API is one-shot import only and architecturally fits the URL tab pattern, not a connector. Status: not in this design.
- **iCloud Photos as a separate source** — already covered by the existing platform gallery integration via `photo_manager` on iOS/macOS.

## Architecture Overview

### The unifying concept: `MediaSourceType` + `MediaSourceResolver`

Today's two source models become six (and growing):

| `MediaSourceType` | Pointer field on `MediaItem` | Resolver implementation |
|---|---|---|
| `platformGallery` | `platformAssetId` (existing) | Existing — reads via `photo_manager` |
| `localFile` | `localPath` (desktop) / `bookmarkRef` (iOS, Android) | `dart:io` File or platform-channel security-scoped resource |
| `networkUrl` | `url` + optional `credentialsHostId` | HTTP GET via `package:http` |
| `manifestEntry` | parent `subscriptionId` + `url` + `entryKey` | HTTP GET, deduped per `(subscriptionId, entryKey)` |
| `serviceConnector` | `connectorAccountId` + `remoteAssetId` | Per-connector implementation |
| `signature` | existing `filePath` / `imageData` | Existing signature reading |

Every concrete source implements a small `MediaSourceResolver` interface. Everything above it (display, thumbnail caching, EXIF extraction, sync, orphan tracking) is source-agnostic.

### Phase summary

| Phase | Scope | Visible to users? |
|---|---|---|
| **1. Foundation** | `MediaSourceType` enum + schema migration; abstract `MediaSourceResolver`; refactor existing gallery code into a resolver implementation; unified picker page shell with tabs; source-type indicator UI for unavailable photos; cross-device sync semantics for new source types; iOS bookmarks / Android persistable URI infrastructure. | No new sources. Existing UX preserved bit-for-bit. |
| **2. Local files** | "Files" tab: file picker, folder picker with auto-match-by-date checkbox (default on); EXIF extraction at link time; per-platform bookmark/URI persistence. | Yes — first new source. |
| **3. Network URLs + manifests** | "URL" tab: single URL field, bulk paste, manifest URL fetcher (Atom/RSS, JSON, CSV); manifest one-shot default with subscription opt-in; `cached_network_image` + eager pre-fetch; per-host credentials + Settings → Data → Media Sources → Network Sources page; subscription polling state. | Yes. |
| **4. Connector framework** | Abstract `ServiceConnector` interface; `connector_accounts` table with secure credential storage (per-device, no sync); generic OAuth and API-key sign-in flow scaffolding; "Connected Services" Settings page; paged remote-browse UI shell. Validation `MockServiceConnector` only. | Mostly no — framework only. |
| **5. Per-service connectors** | Each concrete connector ships as its own sub-spec: Immich, Dropbox, OneDrive, Piwigo, Flickr, SmugMug, etc. iCloud explicitly skipped. Google Photos explicitly skipped. | Yes — one connector at a time. |

## Schema Changes

### New domain enum

`lib/features/media/domain/entities/media_source_type.dart`:

```dart
enum MediaSourceType {
  platformGallery,
  localFile,
  networkUrl,
  manifestEntry,
  serviceConnector,
  signature,
}
```

Stored as TEXT in SQLite, matching the existing pattern for `MediaType`.

### Migration to existing `Media` table (Drift schema version 26 → 27)

New columns (all nullable except `sourceType`):

| Column | Type | Used by | Notes |
|---|---|---|---|
| `sourceType` | TEXT NOT NULL DEFAULT `'platformGallery'` | Every row | Discriminator. Migration backfills from existing pointer columns. |
| `localPath` | TEXT | `localFile` (desktop) | Absolute filesystem path on macOS/Windows/Linux. |
| `bookmarkRef` | TEXT | `localFile` (iOS, Android) | iOS: opaque key into platform keychain where the security-scoped bookmark blob is stored (the blob itself never goes in the DB). Android: the persistable URI string itself, stored directly (URIs are not credentials). |
| `url` | TEXT | `networkUrl`, `manifestEntry` | The HTTPS URL where the bytes live. |
| `subscriptionId` | TEXT FK → `media_subscriptions(id)` | `manifestEntry` | Parent subscription. Cascade-delete with confirmation. |
| `entryKey` | TEXT | `manifestEntry` | Stable per-subscription identity (Atom GUID, JSON `id`, SHA hash for CSV). UNIQUE with `subscriptionId`. |
| `connectorAccountId` | TEXT FK → `connector_accounts(id)` | `serviceConnector` | Which configured account owns this item. |
| `remoteAssetId` | TEXT | `serviceConnector` | Per-service identifier (Immich asset UUID, Dropbox `path_lower`, etc.). |
| `originDeviceId` | TEXT | `localFile`, `serviceConnector` | Device that originally added this row. Drives the "from your other device" UI when the row is unavailable on the current device. |

Existing columns (`platformAssetId`, `filePath`, `imageData`) stay as-is. Their semantics are unchanged for the rows they already describe.

#### Migration backfill

```text
if mediaType == 'instructorSignature' → sourceType = 'signature'
elif platformAssetId IS NOT NULL → sourceType = 'platformGallery'
elif filePath IS NOT NULL → sourceType = 'localFile' AND localPath = filePath
else → sourceType = 'platformGallery'  -- safe default; unreachable in practice
```

After migration, `filePath` is only used by signatures going forward.

### New table: `media_subscriptions`

Tracks manifest URL subscriptions. **Syncs across devices** so all devices see the same subscription list.

| Column | Type | Notes |
|---|---|---|
| `id` | TEXT PK | UUID |
| `manifestUrl` | TEXT NOT NULL | The URL we poll. |
| `format` | TEXT NOT NULL | `atom`, `rss`, `json`, `csv` — sniffed at add time, stored. |
| `displayName` | TEXT | Human-readable label. |
| `pollIntervalSeconds` | INTEGER NOT NULL DEFAULT 86400 | 24 h default; user-configurable per subscription. |
| `isActive` | BOOLEAN NOT NULL DEFAULT 1 | User can pause without deleting. |
| `credentialsHostId` | TEXT FK → `network_credential_hosts(id)` NULL | If the manifest URL needs auth. |
| `createdAt` / `updatedAt` | INTEGER NOT NULL | Standard. |

### New table: `media_subscription_state`

Per-device polling state. **Does not sync** (every device polls independently per design decision).

| Column | Type | Notes |
|---|---|---|
| `subscriptionId` | TEXT PK FK → `media_subscriptions(id)` | One row per subscription per device. |
| `lastPolledAt` | INTEGER | |
| `nextPollAt` | INTEGER | Computed from `lastPolledAt + pollIntervalSeconds`. |
| `lastEtag` / `lastModified` | TEXT | For conditional GET. |
| `lastError` / `lastErrorAt` | TEXT / INTEGER | Last poll failure for the Settings UI. |

### New table: `connector_accounts`

User-configured service connector accounts. **Does not sync** (credentials are per-device).

| Column | Type | Notes |
|---|---|---|
| `id` | TEXT PK | UUID |
| `connectorType` | TEXT NOT NULL | `immich`, `dropbox`, `onedrive`, etc. |
| `displayName` | TEXT NOT NULL | "My Immich" |
| `baseUrl` | TEXT | For self-hosted services. |
| `accountIdentifier` | TEXT | User's email or username for display. |
| `credentialsRef` | TEXT NOT NULL | Opaque key into platform keychain. |
| `addedAt` / `lastUsedAt` | INTEGER | |

### New table: `network_credential_hosts`

Per-host credentials for ad-hoc network URLs. **Does not sync.** Credentials live in the keychain; this table is metadata for the Settings page.

| Column | Type | Notes |
|---|---|---|
| `id` | TEXT PK | UUID |
| `hostname` | TEXT NOT NULL UNIQUE | e.g., `private.example.com` |
| `authType` | TEXT NOT NULL | `basic`, `bearer` |
| `displayName` | TEXT | User-set label. |
| `credentialsRef` | TEXT NOT NULL | Opaque keychain key. |
| `addedAt` / `lastUsedAt` | INTEGER | |

### New table: `media_fetch_diagnostics`

Per-row failure diagnostics. **Does not sync** (each device's failures are local).

| Column | Type | Notes |
|---|---|---|
| `mediaItemId` | TEXT PK FK → `media(id)` | |
| `lastErrorAt` | INTEGER | |
| `lastErrorMessage` | TEXT | |
| `errorCount` | INTEGER NOT NULL DEFAULT 0 | |

### Indexes

```sql
CREATE INDEX media_source_type_idx ON media(sourceType);
CREATE UNIQUE INDEX media_subscription_entry_idx ON media(subscriptionId, entryKey)
  WHERE subscriptionId IS NOT NULL;
CREATE INDEX media_connector_account_idx ON media(connectorAccountId);
CREATE INDEX media_origin_device_idx ON media(originDeviceId);
```

The unique constraint on `(subscriptionId, entryKey)` is the cross-device dedup mechanism — when device A and device B both poll the same Atom feed and both see new entry GUID `xyz`, the sync engine merges the two rows into one.

## Source-Type Abstraction

### The `MediaSourceResolver` interface

Located at `lib/features/media/domain/services/media_source_resolver.dart`:

```dart
abstract class MediaSourceResolver {
  MediaSourceType get sourceType;

  /// True if this resolver can read [item] on the current device.
  /// False when item.originDeviceId points elsewhere and the source is device-local.
  bool canResolveOnThisDevice(MediaItem item);

  /// Resolves the item to a displayable handle. Never throws — returns
  /// UnavailableData with a reason on failure (drives the orphan UI).
  Future<MediaSourceData> resolve(MediaItem item);

  /// Resolves a thumbnail-sized representation. Default returns the same
  /// handle as resolve(); resolvers with native thumbnail APIs override.
  Future<MediaSourceData> resolveThumbnail(MediaItem item, {required Size target}) =>
      resolve(item);

  /// Extracts EXIF / format metadata at link time. Called once when the
  /// item is added; results stored on the MediaItem row.
  Future<MediaSourceMetadata?> extractMetadata(MediaItem item);

  /// Lightweight existence check.
  Future<VerifyResult> verify(MediaItem item);
}
```

### The result type: `MediaSourceData`

Sealed class with four variants. Each maps to an appropriate Flutter widget:

```dart
sealed class MediaSourceData {}

class FileData extends MediaSourceData {
  final File file;          // → Image.file, VideoPlayerController.file
}

class NetworkData extends MediaSourceData {
  final Uri url;
  final Map<String, String> headers;   // → CachedNetworkImage(headers: ...)
}

class BytesData extends MediaSourceData {
  final Uint8List bytes;    // → Image.memory (signatures, small assets only)
}

class UnavailableData extends MediaSourceData {
  final UnavailableKind kind;
  final String? userMessage;
  final String? originDeviceLabel;
}

enum UnavailableKind {
  notFound,
  unauthenticated,
  fromOtherDevice,
  networkError,
  signInRequired,
}
```

### The registry

A `Map<MediaSourceType, MediaSourceResolver>` provided by Riverpod. Lookup is O(1); resolver instances are singletons. Adding a new connector is a one-line registration plus the connector implementation.

### Universal display widget

`lib/features/media/presentation/widgets/media_item_view.dart` wraps resolution and dispatch:

```dart
class MediaItemView extends ConsumerWidget {
  final MediaItem item;
  final Size targetSize;
  final bool thumbnail;

  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(mediaResolutionProvider(item));
    return switch (data) {
      AsyncData(value: FileData(file: final f))         => Image.file(f, ...),
      AsyncData(value: NetworkData(url: final u, headers: final h)) =>
        CachedNetworkImage(imageUrl: u.toString(), httpHeaders: h, ...),
      AsyncData(value: BytesData(bytes: final b))       => Image.memory(b, ...),
      AsyncData(value: UnavailableData())               => UnavailableMediaPlaceholder(...),
      AsyncLoading()                                    => const ShimmerThumbnail(),
      AsyncError()                                      => const ErrorThumbnail(),
    };
  }
}
```

Every existing display callsite (`dive_media_section.dart`, `photo_viewer_page.dart`, `trip_photo_viewer_page.dart`, signature renderers) gets refactored to use `MediaItemView`.

### Per-source resolver implementations

| Resolver | Reads from | Returns |
|---|---|---|
| `PlatformGalleryResolver` | Existing `photo_manager` plumbing | `BytesData` (current behavior) or `FileData` if photo_manager exposes the underlying file |
| `LocalFileResolver` | Desktop: `File(item.localPath)`. Mobile: resolves `bookmarkRef` via platform channel | `FileData` or `UnavailableData` (notFound, fromOtherDevice) |
| `NetworkUrlResolver` | HTTP GET via `package:http` with credentials looked up from `network_credential_hosts` + keychain by hostname | `NetworkData`, or `UnavailableData(unauthenticated)` on 401 |
| `ManifestEntryResolver` | Delegates to `NetworkUrlResolver` using `item.url`; auth inherited from the parent subscription's `credentialsHostId` | Same shapes as `NetworkUrlResolver` |
| `ServiceConnectorResolver` | Looks up `connectorAccountId`, dispatches to the matching connector plugin implementing `ServiceConnector` | Connector-specific. Most return `NetworkData` with a short-lived signed URL |
| `SignatureResolver` | Existing logic — reads `imageData` BLOB or `filePath` file | `BytesData` or `FileData` |

### Error model

`verify()` returns `VerifyResult`: `available`, `notFound`, `unauthenticated`, `transientError`, `fromOtherDevice`. Only `notFound` and `unauthenticated` flip `isOrphaned = true` (persistent conditions). `transientError` updates `lastVerifiedAt` but doesn't mark orphan.

`extractMetadata()` returns `null` on failure rather than throwing — failed extraction is surfaced as a "couldn't read EXIF" warning in the add UI but doesn't block linking.

### Threading model

All resolution is `async`. File I/O uses `dart:io` (non-blocking). HTTP uses `package:http` (non-blocking). EXIF parsing dispatches to a background isolate via `compute()` for files larger than 5 MB. The Dart UI thread never blocks on bytes.

## Phase 1 — Foundation

Phase 1 is intentionally invisible to end users. No new sources appear, no new buttons get added. It's pure scaffolding plus a refactor of the existing gallery flow onto the new abstraction.

### Deliverables

1. **Schema migration** — Drift version bump (26 → 27). Adds the new media columns and creates `media_subscriptions`, `media_subscription_state`, `connector_accounts`, `network_credential_hosts`, `media_fetch_diagnostics`. Backfills `sourceType`. Idempotent with `PRAGMA table_info` guards matching the existing migration style at [database.dart:1843-1907](lib/core/database/database.dart#L1843-L1907).

2. **Domain entities and value types**:
   - `lib/features/media/domain/entities/media_source_type.dart`
   - `lib/features/media/domain/value_objects/media_source_data.dart` (sealed class)
   - `lib/features/media/domain/value_objects/media_source_metadata.dart`
   - `lib/features/media/domain/value_objects/verify_result.dart`
   - `MediaItem` gains `sourceType` and the new pointer fields plus updated `copyWith` and `props`.

3. **Resolver interface and gallery resolver**:
   - `lib/features/media/domain/services/media_source_resolver.dart` (abstract)
   - `lib/features/media/data/resolvers/platform_gallery_resolver.dart` — wraps existing `photo_manager` calls
   - `lib/features/media/data/resolvers/signature_resolver.dart` — wraps existing signature read code
   - `lib/features/media/data/services/media_source_resolver_registry.dart` — registry with `platformGallery` and `signature` registered; other entries throw `UnimplementedError` until later phases

4. **Universal display widget**:
   - `lib/features/media/presentation/widgets/media_item_view.dart` — the `MediaItemView` from the architecture section.
   - Refactor every existing display callsite to use it. Behind a feature flag, the old code paths are preserved for one development cycle for A/B verification.

5. **Picker page tab shell**:
   - [photo_picker_page.dart](lib/features/media/presentation/pages/photo_picker_page.dart) becomes a `TabBarView` host. The "Gallery" tab holds the existing UI unchanged. "Files" and "URL" tabs ship as placeholders behind a debug flag.

6. **Source-type indicator UI for unavailable photos**:
   - `lib/features/media/presentation/widgets/unavailable_media_placeholder.dart` (refactored from existing `unavailable_photo_placeholder.dart`).
   - Renders a grayed thumbnail with an icon and short label per `UnavailableKind`. Long-press shows context actions: "Try again", "Mark as missing", "Remove link".

7. **Cross-device sync wiring**:
   - Coordinate with the existing sync engine to populate `originDeviceId` on row creation.
   - Sync engine merge rules: `media` rows with `(subscriptionId, entryKey)` collisions dedup; `connector_accounts`, `network_credential_hosts`, `media_subscription_state`, `media_fetch_diagnostics` registered as `noSync`.

8. **iOS / Android persistence infrastructure** (built in phase 1, used by phase 2):
   - iOS native: method channel `com.submersion.app/local_media` with `createBookmark`, `resolveBookmark`, `releaseBookmark`. Bookmark blobs stored in `flutter_secure_storage`.
   - Android native: equivalent channel using `ContentResolver.takePersistableUriPermission` and `DocumentFile`. Honors the per-app 128-URI budget with auto-release-oldest behavior.
   - Desktop: stub implementations that round-trip the file path.
   - Dart side: `LocalMediaPlatform` class wrapping the channel.

9. **Settings page scaffold**:
   - Add a "Media Sources" entry to `_DataSectionContent` in [settings_page.dart](lib/features/settings/presentation/pages/settings_page.dart#L225) that routes to a new `MediaSourcesPage`.
   - Initial content: existing photo library status, a Diagnostics toggle that exposes hidden tabs in the picker for dev testing.

### Acceptance criteria

- Existing dive-photo flows work bit-for-bit identically to before.
- `flutter test` passes; `flutter analyze` clean.
- New unit tests for `MediaSourceType`, `MediaSourceData`, the registry, the migration backfill, the iOS/Android bookmark channel.
- One end-to-end integration test exercises a gallery photo add through the new abstraction.
- The schema migration runs cleanly on a database snapshot containing real existing media rows.

## Phase 2 — Local Files

### Deliverables

1. **Files tab UI** — replaces the placeholder shipped in phase 1. Two primary actions:
   - **"Pick files…"** — system file picker, multi-select, restricted to image and video MIME types.
   - **"Pick a folder…"** — system folder picker. Below the action: `[x] Auto-match photos to dives by EXIF date` checkbox, default checked.

   A selected-items review pane below shows thumbnail cards with EXIF-extracted metadata and inline actions to reassign target dive or remove from selection.

2. **File/folder picker plumbing** via `package:file_picker`. Folder enumeration runs on a background isolate via `compute()`. Recognized extensions: `.jpg .jpeg .heic .heif .png .webp .gif .mp4 .mov .m4v`. Cancel button on the progress indicator aborts cleanly.

3. **Mobile persistence**:
   - **iOS**: On file pick, immediately call `LocalMediaPlatform.createBookmark(filePath)` and store the returned `bookmarkRef` in the `MediaItem.bookmarkRef` column. The `localPath` column stays null on iOS. Display flows resolve via the channel with security-scoped resource lifecycle.
   - **Android**: Same shape, but the channel calls `ContentResolver.takePersistableUriPermission` and the URI string is stored directly in the `MediaItem.bookmarkRef` column (no keychain involvement — the URI is an identifier, not a credential). Per-app 128-URI budget enforced with a "release oldest" warning when approaching the limit.
   - **Desktop**: `localPath` is the absolute file path; `bookmarkRef` stays null.

4. **EXIF extraction at link time** — new service `lib/features/media/data/services/exif_extractor.dart`:
   - Files ≤5 MB: read directly on the calling isolate.
   - Larger files: dispatch to a background isolate via `compute()`.
   - Extracts `DateTimeOriginal`, `GPSLatitude/Longitude`, image width/height, video duration.
   - Returns `MediaSourceMetadata`.
   - Failure non-fatal: file becomes a valid linked `MediaItem` with `takenAt = file mtime` as fallback (flagged as low-confidence for auto-match weighting).

5. **Auto-match-by-date** — new shared service `lib/features/media/domain/services/dive_photo_matcher.dart`:
   - Matches each file's `takenAt` against dives whose `[startTime - 30min, endTime + 60min]` window contains the timestamp.
   - For overlapping matches, picks the dive whose `startTime` is closest to the file's `takenAt`.
   - Files with no `takenAt` or no match go into `unmatched`.
   - The existing gallery scan logic is refactored to call this same matcher.

6. **Review-and-adjust experience** — review pane groups files by target dive (collapsible by date) with an "Unmatched" group at the bottom. Summary line: "12 photos → 3 dives, 4 unmatched". A "Don't auto-match next time" preference toggle persists the checkbox default.

7. **Commit flow**:
   - Validate per-platform persistence (call `createBookmark` on iOS; `takePersistableUriPermission` on Android).
   - Insert a `MediaItem` row per file with `sourceType = localFile`, appropriate pointer field, `originDeviceId`, EXIF-extracted metadata.
   - Run the existing `MediaEnrichment` pipeline against the dive profile.
   - Show a toast with the count linked plus an Undo action.

8. **Dive media section context** — long-press on a linked local file surfaces:
   - "Show in Finder/Explorer/Files" (desktop only)
   - "Replace link…" — re-pick the file
   - ("Convert to gallery photo…" deferred to phase 5 polish)

9. **Settings page additions** under Media Sources:
   - "Local files" subsection with linked count by status (available / unavailable / from another device).
   - "Re-verify all local files" action.
   - Android only: "URI usage: 47 / 128" indicator with "Release unused URIs" action.

### Edge cases handled

- HEIC files on Windows/Linux without native decode: display falls back to "preview unavailable" with file still linked.
- Folders with >5,000 files: confirmation prompt with date-range filter option before enumeration.
- Files with no EXIF and no recognizable extension: excluded with a warning chip.
- Symlinks: followed only if pointing within the picked folder.
- Files on removable media: linked normally; orphan when unmounted; recover on remount.

### Acceptance criteria

- Files tab functional on macOS, Windows, Linux, iOS, Android.
- Folder pick of 100+ photos auto-matches correctly to dives whose time windows contain the EXIF timestamps.
- iOS user can link a file, quit Submersion, relaunch, and the file still displays.
- Android user can link 100 files without exceeding the URI budget; 129th surfaces the release-oldest UI.
- A local file deleted from disk shows as `notFound` orphan on next display attempt.
- Shared `DivePhotoMatcher` is used by both the new Files tab flow and the existing gallery scan.

## Phase 3 — Network URLs and Manifests

### Deliverables

1. **URL tab UI** — two modes via segmented control: **"URLs"** | **"Manifest"**.

   **URLs mode**: Multi-line text field accepting one URL per line. Real-time validation marks malformed URLs in red. Single-line "Add URL" entry available for one-at-a-time on mobile. Auto-match-by-date checkbox identical to Files tab (default on).

   **Manifest mode**: Single URL field, "Subscribe to updates (poll for new entries)" checkbox **default off**. After "Fetch":
   - GET the URL.
   - Sniff format by Content-Type then content (Atom/RSS root, JSON top-level structure, CSV header heuristic).
   - Show detected format with override dropdown.
   - Parse, preview entry count + first 5 entries.
   - If subscription on, show "Poll every: [24 hours ▼]" dropdown.
   - "Import N entries" button commits.

2. **Per-host credentials** — service `lib/features/media/data/services/network_credentials_service.dart`. On 401 from any HTTP request, the resolver returns `UnavailableData(unauthenticated)`. Tapping "Sign in" on the badge opens a sheet:
   - Hostname (read-only, from URL)
   - Auth type: Basic | Bearer
   - Username + Password (Basic) or Token (Bearer)
   - Optional display name

   Saving creates a `network_credential_hosts` row and stores the credential in the platform keychain via `flutter_secure_storage`. All future requests to that hostname include the auth header automatically. In-memory cache of resolved (hostname → headers) maps.

3. **Settings → Data → Media Sources → Network Sources page**:
   - Saved hosts: hostname, auth type, displayName, last used, action menu (Test credentials, Edit, Delete).
   - Manifest subscriptions: displayName, format, last poll status, next poll time, isActive toggle, action menu (Poll now, Edit URL/credentials, Delete).
   - Cache size + Clear cache.
   - Scan all network media.

4. **Manifest parsers** in `lib/features/media/data/parsers/`:

   - **`atom_manifest_parser.dart`** — uses `package:xml`. Pulls `<entry>` (Atom) or `<item>` (RSS). Per entry: `id`/`<guid>` → `entryKey`; `<media:content>` or `<enclosure>` → `url`; `<published>`/`<pubDate>` → `takenAt`; `<title>` → `caption`; `<media:thumbnail>` for preview; `<georss:point>` → lat/lon. Tolerant of mixed Atom/RSS in the wild.

   - **`json_manifest_parser.dart`** — Submersion JSON manifest v1 (documented in `docs/superpowers/specs/manifest_json_v1.md` for users to author):

     ```json
     {
       "version": 1,
       "title": "Eric's Dive Photos",
       "items": [
         {
           "id": "dive-2024-04-12-img-001",
           "url": "https://photos.example.com/dive-001.jpg",
           "thumbnailUrl": "https://photos.example.com/dive-001-thumb.jpg",
           "takenAt": "2024-04-12T14:32:00Z",
           "caption": "Yellowtail at the swim-through",
           "mediaType": "photo",
           "lat": 25.123,
           "lon": -80.456,
           "width": 4032,
           "height": 3024,
           "durationSeconds": null
         }
       ]
     }
     ```

     All fields except `id` and `url` are optional. Missing `id` falls back to `SHA(url + takenAt ?? '')`.

   - **`csv_manifest_parser.dart`** — uses `package:csv`. Required header: at minimum `url`. Recognized columns: `url`, `id`, `takenAt`, `caption`, `mediaType`, `lat`, `lon`, `width`, `height`, `durationSeconds`, `thumbnailUrl`.

   All parsers return a `List<ManifestEntry>` value type.

5. **Eager fetch pipeline**:

   - **Synchronous step (sub-second)**: insert one `MediaItem` row per URL/entry with `sourceType = networkUrl` or `manifestEntry`, `url` populated, manifest-supplied metadata applied. `lastVerifiedAt` is null at this point.
   - **Background step (queued, runs serially in a Riverpod-managed isolate)**: for each row, `NetworkUrlResolver.extractMetadata(row)` issues a range request (or full GET if not supported), runs EXIF extraction, fills blanks. Eager thumbnail pre-fetch through `cached_network_image`. Updates the row with extracted metadata + `lastVerifiedAt = now` on success. On failure, marks `isOrphaned = true` and writes to `media_fetch_diagnostics`.
   - UI shows shimmer placeholders for any row where `lastVerifiedAt` is null; transitions as the pipeline completes.

   Pipeline rate-limited: default 4 concurrent fetches, honors `Retry-After` headers per host.

6. **Subscription polling** in `lib/features/media/data/services/subscription_poller.dart`:

   - Triggered on app launch (after 30s warm-up), on a periodic Riverpod timer (smaller of `pollIntervalSeconds / 4` and 1 hour), and on user "Poll now".
   - Each cycle: select active subscriptions where `nextPollAt <= now`; conditional GET (`If-None-Match`, `If-Modified-Since`); on 304 just update timestamps; on 200 parse and diff.
   - Diff:
     - **New entries**: insert as `MediaItem` rows, run through eager fetch pipeline, run auto-match if subscription has the pref enabled.
     - **Removed entries** (in DB but not in new manifest): mark `isOrphaned = true`. Don't delete (user may have linked them with notes/tags). Settings action "Cleanup orphaned manifest entries" cleans up.
     - **Changed entries** (same `entryKey`, different fields): patch the row.
   - Updates per-device state. On error: writes `lastError`/`lastErrorAt`, backs off (`now + min(pollInterval * 2, 24h)`).

   Cross-device dedup: device A and device B both polling the same feed both insert rows for new `entryKey`; the unique constraint on `(subscriptionId, entryKey)` causes the sync engine to merge.

7. **EXIF / format extraction over HTTP** in `NetworkUrlResolver.extractMetadata()`:

   - First attempt: `Range: bytes=0-65535` — EXIF typically lives in first 64 KB.
   - Fallback: full GET; downloaded bytes flow into `cached_network_image`'s cache.
   - For videos: full GET to a temp file, then `package:video_thumbnail` + `package:ffmpeg_kit_flutter` for poster + duration. Flagged in URL tab review pane as "video — full download".
   - If manifest already provided `takenAt`/`lat`/`lon`/etc., skip EXIF extraction entirely.

8. **User-triggered HTTP scan** (Settings → Network Sources → "Scan all network media"):

   - Iterates every `MediaItem` with `sourceType IN (networkUrl, manifestEntry)`.
   - HEAD request per item, falling back to range-GET if HEAD unsupported.
   - Updates `isOrphaned` and `lastVerifiedAt`.
   - Shows progress + final summary.
   - Rate-limited per-host (4 concurrent, max 1 every 250 ms per host).
   - Purely user-initiated; no background timer.

9. **CachedNetworkImage integration**:

   - LRU disk cache, default 500 MB cap (configurable in Settings).
   - LRU memory cache, default 75 MB cap.
   - Headers from `NetworkCredentialsService` passed through.
   - `errorWidget` builder uses `UnavailableMediaPlaceholder`.
   - Eager pre-fetch on link calls `CachedNetworkImageProvider(...).resolve(...)` for each new row at thumbnail size.

### Edge cases handled

- Redirects: up to 5 followed automatically. Final URL recorded as `finalUrl` only if it differs (used for cache key stability).
- Mixed-content (manifest is HTTPS, entries are HTTP): blocked entries show as `UnavailableData(networkError)` with "blocked: plain HTTP" message.
- Servers that don't support range requests: detected on first 416/200-with-full-body, cached per host in memory.
- Manifests with thousands of entries: streaming parser for Atom/JSON; CSV is line-by-line. UI shows progress with Cancel.
- HTTPS cert errors: surfaced via `UnavailableMediaPlaceholder`. User can "Trust this host" via Settings (advanced; off by default).
- URLs that are HTML pages (e.g., Flickr photo page instead of image URL): detected by Content-Type `text/html`, surfaces error in review pane suggesting direct image URL.

### Acceptance criteria

- A user can paste 50 image URLs, see them appear with shimmer placeholders, and have thumbnails fill in over the next minute.
- A user can paste a Flickr public RSS URL, opt into subscription, and see new photos automatically appear when the feed updates.
- A user can paste a Piwigo Atom URL with HTTP basic auth, save the per-host credentials once, and have all entries (including new ones from polls) authenticate transparently.
- Two devices polling the same Atom subscription don't produce duplicate rows after sync.
- HEAD-scan reports correct counts.
- Cache eviction works under storage pressure; clearing cache doesn't delete media rows.

## Phase 4 — Connector Framework

Phase 4 is intentionally a framework phase — it adds no concrete service connectors, just the scaffolding that future connectors slot into.

### Deliverables

1. **The `ServiceConnector` interface** at `lib/features/media/domain/services/service_connector.dart`:

   ```dart
   abstract class ServiceConnector {
     String get connectorType;
     ConnectorMeta get meta;
     ConnectorAuth get auth;

     Future<ConnectorAccountInfo> probeAccount(ConnectorCredentials creds);

     Future<Page<RemoteBrowseNode>> listRoots(ConnectorAccount account, {String? cursor});
     Future<Page<RemoteBrowseNode>> listChildren(
       ConnectorAccount account,
       RemoteBrowseNode parent, {
       String? cursor,
     });

     Future<MediaSourceData> resolve(ConnectorAccount account, MediaItem item);
     Future<MediaSourceData> resolveThumbnail(
       ConnectorAccount account,
       MediaItem item,
       Size target,
     );
     Future<MediaSourceMetadata?> extractMetadata(ConnectorAccount account, MediaItem item);
     Future<VerifyResult> verify(ConnectorAccount account, MediaItem item);
   }
   ```

   Supporting types:

   ```dart
   class Page<T> { final List<T> items; final String? nextCursor; }

   sealed class RemoteBrowseNode {
     String get id;
     String get displayName;
   }
   class RemoteFolder extends RemoteBrowseNode { ... }
   class RemoteMedia extends RemoteBrowseNode { ... }

   sealed class ConnectorAuth {}
   class ApiKeyAuth extends ConnectorAuth { ... }
   class OAuth2Auth extends ConnectorAuth { ... }
   class BasicAuth extends ConnectorAuth { ... }
   ```

2. **Connector registry** at `lib/features/media/data/services/service_connector_registry.dart`. Phase 4 ships with one entry: a `MockServiceConnector` for end-to-end framework validation, hidden behind a debug build flag.

   The framework's `ServiceConnectorResolver` (registered in the `MediaSourceResolverRegistry`) dispatches based on `connectorAccountId → connectorType → connector`.

3. **OAuth / API-key sign-in flow** at `lib/features/media/presentation/pages/connector_signin_page.dart`. Renders different UI based on the connector's `ConnectorAuth`:

   - **`ApiKeyAuth`**: form with optional Base URL, API Key field, Sign in button, optional "Where do I get this?" link.
   - **`OAuth2Auth`**: "Sign in with <ConnectorMeta.displayName>" button launches an in-app webview targeting `authorizeUrl` with appropriate params (PKCE if `usesPkce`). On redirect, captures auth code, exchanges at `tokenUrl`, stores result.
   - **`BasicAuth`**: username/password form.

   After credential capture: calls `connector.probeAccount(creds)`, inserts a `connector_accounts` row, stores credentials in keychain via `flutter_secure_storage` keyed by `credentialsRef`.

   OAuth tokens stored as JSON: `{accessToken, refreshToken, expiresAt}`. Token refresh handled by `ConnectorTokenManager` wrapping every connector HTTP call with retry-on-401 + refresh-then-retry.

4. **Per-connector configuration registration** — each connector at `lib/features/media/connectors/<connector>/<connector>_connector.dart` exports a `ServiceConnector` implementation, a Riverpod provider, and a registration call invoked from app startup.

5. **Browse UI shell** at `lib/features/media/presentation/pages/connector_browse_page.dart`:

   - Top-level shows `listRoots()` (typically albums).
   - Tap `RemoteFolder` → push new instance showing children.
   - Tap `RemoteMedia` → toggle selection.
   - Long-press → multi-select.
   - "Link N items" commits.
   - Infinite-scroll pagination via `listChildren(..., cursor: nextCursor)`.

   Commit flow: insert one `MediaItem` per selected `RemoteMedia` with `sourceType = serviceConnector`, `connectorAccountId`, `remoteAssetId`, and any browse-supplied metadata. Background `extractMetadata()` and thumbnail pre-fetch. Auto-match-by-date if user opted in.

6. **Signed-URL expiration handling**:

   - `MediaSourceData.NetworkData` is a snapshot, valid only until expiration.
   - `ServiceConnectorResolver.resolve()` is called fresh per display; the connector returns a fresh signed URL each call.
   - For thumbnails, a custom `ConnectorThumbnailImageProvider` uses `(connectorAccountId, remoteAssetId, sizeBucket)` as a stable cache key, asking the resolver for a fresh URL on cache miss.

7. **"Connected Services" Settings page** under Settings → Data → Media Sources:

   - Per `connector_accounts` row: connector icon + display name, account identifier, linked-asset count by status, last successful API call, action menu (Browse photos…, Re-authenticate, Test connection, Sign out and remove).
   - "+ Add account" FAB lists all registered connector types and launches the appropriate sign-in flow.

8. **Sign-out lifecycle**:

   - Linked `MediaItem` rows for the account stay in the DB but display as `UnavailableData(signInRequired)` with "Sign in to <connectorType>" badge.
   - Cached thumbnails not auto-purged (re-signing-in restores instant display); separate "Clear cache" action.
   - Keychain credential deleted; `connector_accounts` row deleted.
   - Re-sign-in to same service: framework offers "Reconnect previous photos" — if the new account's `accountIdentifier` matches a deleted account, prompt to re-point the orphaned `MediaItem` rows.

9. **Cross-device coordination**:

   - `connector_accounts` doesn't sync. User signs in per device.
   - When device A links a connector item and syncs to device B, device B looks up `connectorAccountId`, finds no matching local account, returns `UnavailableData(signInRequired, userMessage: "Sign in to <connectorType> to view")`.
   - "Sign in to <connectorType>" badge tap takes user to the appropriate sign-in flow.
   - After sign-in: "Found 32 photos that were linked to this service on another device — connect them?" prompt offers to re-point local rows to the new account ID.

### Edge cases handled

- Token refresh fails permanently: mark all account items as `UnavailableData(signInRequired)`, prompt re-auth.
- API rate limits: `ConnectorTokenManager` honors `Retry-After`; for connectors publishing rate-limit headers, proactively backs off near limit.
- Self-hosted instance moves to new URL: "Edit base URL" action; resolver picks up transparently.
- Connector adds new auth scopes: framework re-prompts via "Re-authenticate".
- Connector implementation throws: framework wraps in try/catch returning `UnavailableData(networkError)` rather than crashing UI.

### Acceptance criteria

- Validation `MockServiceConnector` can be added as an account, browsed, photos selected and linked, and linked photos display correctly using bundled test assets.
- OAuth webview flow round-trips a redirect URI, captures code, exchanges for token (validated against local OAuth test server in CI).
- Token refresh works on forced 401.
- Signed URL expiration produces re-resolution rather than permanent 404.
- Sign-out transitions linked photos to "sign in to view" without data loss.
- Cross-device sync of a connector-linked row produces correct "sign in to view" badge on the other device.

## Phase 5 — Per-Service Connectors

Phase 5 is a family of small projects, each shipped as a separate spec → plan → implementation cycle. Recommended order:

1. **Immich** — easiest, validates framework against a real service
2. **Dropbox** — clean OAuth 2, large user base
3. **OneDrive** — clean OAuth 2, decent user base
4. **Piwigo** — self-hosted, popular in dive community
5. **Flickr** — OAuth 1.0a, real demand, more work
6. **SmugMug** — OAuth 1.0a, niche
7. **(future)** PhotoPrism, Lychee, Nextcloud Photos, etc.

### Per-connector summaries

#### 5.1 Immich

- **Auth**: `ApiKeyAuth(requiresBaseUrl: true)`. Future: OAuth via Immich's OIDC integration.
- **Browse roots**: Albums via `GET /api/album`. Plus virtual "All assets" root.
- **listChildren**: For album, `GET /api/album/{id}` returns assets directly (no nested folders). For "All assets", paged via `GET /api/asset?take=100&skip=...`.
- **Resolve**: `GET /api/asset/{id}/original`. Thumbnail: `GET /api/asset/{id}/thumbnail?format=webp&size=preview`.
- **Metadata**: Available in asset object — `exifInfo` includes `dateTimeOriginal`, `latitude`, `longitude`, `exifImageWidth`, `exifImageHeight`. No EXIF re-extraction needed.
- **URLs**: stable, not signed → cache key can use URL itself.
- **API keys don't expire** → no token refresh.
- **Estimated scope**: 3–5 days.

#### 5.2 Dropbox

- **Auth**: `OAuth2Auth(usesPkce: true, scopes: [files.metadata.read, files.content.read])`. Redirect: `submersion://oauth/dropbox`.
- **Browse roots**: Single root pointing to `/`.
- **listChildren**: `POST /2/files/list_folder` with paging via `list_folder/continue`.
- **Resolve**: `POST /2/files/get_temporary_link` returns 4-hour signed URL. Thumbnails: `POST /2/files/get_thumbnail_v2` or `get_thumbnail_batch`.
- **Metadata**: `media_info` field on file entries provides `time_taken`, `dimensions`, `location`.
- **URLs expire** → re-resolve per display; thumbnail cache uses `(connectorAccountId, path_lower)`.
- **Filter to image/video files** in listing results.
- **Personal vs Business**: probed during `probeAccount`.
- **Estimated scope**: 5–7 days.

#### 5.3 OneDrive

- **Auth**: `OAuth2Auth(usesPkce: true, scopes: [Files.Read, offline_access])`. Microsoft identity platform endpoints. Redirect: `submersion://oauth/onedrive`.
- **Browse roots**: Two virtual roots — "Files" (`/me/drive/root/children`) and "Photos" (`/me/photos`).
- **listChildren**: `GET /me/drive/items/{id}/children?$top=100` with `@odata.nextLink` paging.
- **Resolve**: `GET /me/drive/items/{id}` returns `@microsoft.graph.downloadUrl`. Thumbnails: `GET /me/drive/items/{id}/thumbnails/0/large`.
- **Metadata**: `photo` and `image` facets provide `takenDateTime`, dimensions; `location` facet for GPS.
- **Personal vs Work/School accounts**: probed during `probeAccount`. Default OAuth tenant: `common`.
- **Estimated scope**: 5–7 days.

#### 5.4 Piwigo

- **Auth**: `BasicAuthWithBaseUrl` (new sub-variant of `BasicAuth` — added by Piwigo connector). Sign-in calls `pwg.session.login`, stores session cookie in keychain.
- **Browse roots**: Categories via `pwg.categories.getList?recursive=false`. Categories nest.
- **listChildren**: `pwg.categories.getImages?cat_id=N&per_page=100&page=...` for images; `pwg.categories.getList?cat_id=N` for sub-categories.
- **Resolve**: Image URLs returned directly (`element_url`, `derivatives.thumb.url`). URLs are stable.
- **Metadata**: `date_creation`, `width`, `height`, `tags`, `geo` available in `getImages` response.
- **Session refresh** via re-login on 401 (silent, using stored credentials).
- **LDAP / double-auth edge cases**: detected during `probeAccount`.
- **Estimated scope**: 5–7 days.

#### 5.5 Flickr

- **Auth**: `OAuth1aAuth` — new auth variant added by Flickr connector. Framework lift to add OAuth 1.0a happens here.
- **Browse roots**: Photosets via `flickr.photosets.getList`. Optional "Camera Roll" root via `flickr.photos.search?user_id=me`.
- **listChildren**: `flickr.photosets.getPhotos?extras=date_taken,geo,url_o,url_l,url_z,url_t&per_page=100&page=...`.
- **Resolve**: URLs returned via `extras` (`url_o`, `url_l`, `url_z`, `url_t`). Stable. Direct GETs for public photos; signed URL via `flickr.photos.getSizes` for private.
- **Metadata**: `date_taken`, `latitude`, `longitude`, `width_o`, `height_o` via `extras`.
- **Spec must verify currently-supported endpoints at implementation time** (Flickr API is being deprecated in pieces).
- **Public-feed-only usage**: Flickr publishes Atom feeds — covered by phase 3 manifest URL pattern, not this connector. Flickr connector targets private and contacts-only photos.
- **Estimated scope**: 10–14 days including OAuth 1.0a framework lift.

#### 5.6 SmugMug

- **Auth**: `OAuth1aAuth` (shares lift with Flickr).
- **Browse roots**: User's nodes via `/api/v2/user/<nickname>!nodes`.
- **listChildren**: For gallery, `/api/v2/album/<id>!images` paginated.
- **Resolve**: `MediumImageUrl`, `ThumbnailUrl`, `LargeImageUrl`, plus per-image `Uri` for signed URL.
- **Metadata**: `OriginalSize`, `DateTimeOriginal`, `Latitude`, `Longitude` in image response.
- **Estimated scope**: 7–10 days assuming OAuth 1.0a is in framework.

### Cross-cutting phase 5 framework lifts

Each happens alongside the first connector to need it:

- **OAuth 1.0a** — landed by Flickr or SmugMug, whichever ships first.
- **`BasicAuthWithBaseUrl`** — landed by Piwigo.
- **WebDAV** — eventual shared layer if/when Nextcloud + ownCloud + others enter.

### Per-connector acceptance criteria

Each connector ships with:

- Working sign-in flow against a real instance.
- Browse + select + link working end-to-end on every supported platform.
- Linked items resolve correctly across signed-URL expiration.
- Sign-out cleanly transitions linked items to "sign in to view".
- Cross-device sync of linked items produces correct per-device behavior.
- Unit tests for the connector (mocked HTTP).
- Integration test against a real account in CI (gated by env var; for self-hosted, containerized instance in CI; for OAuth services, credentials in CI secrets, run nightly).

## Cross-Cutting Concerns

### Verification / orphan tracking

Per source type:

| Source | Verification trigger | Effect on `isOrphaned` |
|---|---|---|
| `platformGallery` | Existing `photo_manager` orphan signal | Existing behavior unchanged |
| `localFile` | Lazy on display attempt; user-triggered "Re-verify all local files" | `notFound` → orphan; transient → no change |
| `networkUrl` | User-triggered "Scan all network media" only | `notFound`/401 → orphan; transient → no change |
| `manifestEntry` | Same as `networkUrl`, plus during subscription poll (entries removed from manifest) | `notFound`/removed → orphan |
| `serviceConnector` | User-triggered scan; opportunistically during display when re-resolution fails | `notFound`/401 → orphan; signed URL expiry → re-resolve, not orphan |
| `signature` | Existing | Existing |

`lastVerifiedAt` records the last successful read or check; `isOrphaned` flips back to `false` automatically when a previously-orphaned source becomes readable again. Both flow through normal sync, but the meaning is per-device — a row can be available on device A and orphaned on device B; the dive view shows the per-device truth.

### Caching

| Cache | Scope | Backed by | Eviction |
|---|---|---|---|
| **Thumbnail cache** | All non-gallery sources | `cached_network_image` for `NetworkData`; in-memory `LruCache` keyed by `MediaItem.id` for `FileData` | LRU; default 500 MB disk + 75 MB memory (configurable) |
| **EXIF / metadata cache** | All sources | The `MediaItem` row itself | Never evicted (lives with the row) |
| **Resolved-URL cache** | Service connectors only | In-memory `Map<MediaItemId, ExpiringUrl>` | TTL = signed URL expiry minus 60s safety margin |

The platform gallery resolver continues to use `photo_manager`'s built-in caching, separate from the above.

### Settings tree (final)

```text
Settings
├── Profile
├── Units
├── Decompression
├── Appearance
├── Notifications
├── Manage
├── Data
│   ├── ... (existing data items)
│   └── Media Sources
│       ├── Photo library
│       │   ├── Permission status
│       │   └── Linked count
│       ├── Local files                   (phase 2)
│       │   ├── Linked count by status
│       │   ├── Re-verify all local files
│       │   └── (Android only) URI usage / Release unused
│       ├── Network Sources               (phase 3)
│       │   ├── Saved hosts
│       │   ├── Manifest subscriptions
│       │   ├── Cache size / Clear cache
│       │   └── Scan all network media
│       ├── Connected Services            (phase 4)
│       │   ├── (per account) Browse photos, Re-authenticate, Test, Sign out
│       │   └── + Add account
│       └── Diagnostics
│           ├── Show source-type chips on grid (debug)
│           ├── Show fetch error details (debug)
│           └── Last sync timestamps for each subscription
└── Data Sources                          (existing — separate; unrelated to this design)
```

Phase 1 adds a "Media Sources" entry to `_DataSectionContent` in [settings_page.dart](lib/features/settings/presentation/pages/settings_page.dart#L225) routing to a new `MediaSourcesPage`. Each later phase adds items inside that page. l10n keys follow the existing data-section naming pattern.

### Credential storage architecture

All credentials live in `flutter_secure_storage`, mapping per-platform to:
- iOS Keychain (`ksecAttrAccessibleAfterFirstUnlockThisDeviceOnly` — never syncs to iCloud)
- Android EncryptedSharedPreferences
- macOS Keychain
- Windows Credential Manager
- Linux Secret Service

A `CredentialStorage` service in `lib/core/services/credential_storage.dart` wraps `flutter_secure_storage` and namespaces keys:

| Key prefix | Used by | Value shape |
|---|---|---|
| `network_host:<credentialsRef>` | Phase 3 per-host credentials | `{authType, username, password}` or `{authType, token}` |
| `connector_account:<credentialsRef>` | Phase 4 service connector accounts | `{accessToken, refreshToken, expiresAt}` for OAuth; `{apiKey}` for API key; `{username, sessionCookie}` for session-based |
| `bookmark:<bookmarkRef>` | Phase 1 iOS security-scoped bookmarks | binary bookmark blob, base64-encoded |

A "Wipe all credentials" Diagnostics action exists for users debugging stuck auth state.

### Cross-device sync semantics

| Source | Row syncs? | Origin device used? | Cross-device behavior |
|---|---|---|---|
| `platformGallery` | Yes | Existing | Existing `resolved_asset_providers` handles cross-device asset ID resolution |
| `localFile` (desktop path) | Yes | Yes | Other devices: `UnavailableData(fromOtherDevice, originDeviceLabel: ...)` |
| `localFile` (iOS bookmark) | Yes (without bookmark blob) | Yes | Other devices: `UnavailableData(fromOtherDevice)` |
| `localFile` (Android URI) | Yes (without URI) | Yes | Other devices: `UnavailableData(fromOtherDevice)` |
| `networkUrl` (no auth) | Yes | No (works everywhere) | Same UX on every device |
| `networkUrl` (with auth) | Yes (without credentials) | No | Other devices show `UnavailableData(unauthenticated)` until matching host credentials added |
| `manifestEntry` | Yes | No | Same UX on every device assuming manifest URL is reachable + auth configured |
| `serviceConnector` | Yes | Yes (account is per-device) | Other devices show `UnavailableData(signInRequired)` with "found N photos linked from another device" prompt on first sign-in |
| `signature` | Existing | Existing | Existing |

Non-syncing tables (`media_subscription_state`, `connector_accounts`, `network_credential_hosts`, `media_fetch_diagnostics`) registered as `noSync` exclusions.

Sync engine merge rules:
- `media` rows merge by `id` (existing).
- `media` rows with same `(subscriptionId, entryKey)` dedup to one row.
- `media_subscriptions` merge by `id`; immutable fields (URL, format) refuse to update; mutable fields (displayName, pollIntervalSeconds, isActive) last-write-wins.

### Diagnostics and error handling

`MediaDiagnosticsService` writes to `media_fetch_diagnostics` (per-device, no sync) on resolver failures. "Show details" affordance on `UnavailableMediaPlaceholder` exposes last error (gated by Diagnostics toggle).

User-facing error messages avoid stack traces or internal API details:
- Generic: "Couldn't load this photo" + "Show details" link
- Specific where useful: "Sign in to <service>", "From <device>", "File not found"

### Performance considerations

- **Dive list rendering**: Network-backed sources could mean N HTTP requests on a list that historically did zero network IO. Cache-first strategy plus eager pre-fetch makes typical renders cache-only. Cold cache: thumbnails deferred to a `Future.microtask`-scheduled widget showing shimmer placeholders rather than blocking layout.
- **Bulk linking** (folder pick of 500 files, manifest of 1,000 entries): eager EXIF + thumbnail pipeline rate-limited (4 concurrent). UI shows progress, remains interactive. User can navigate away; pipeline continues in background.
- **Subscription polling**: debounced background task; never on UI thread. Bulk processing of new entries rate-limited.
- **Search/filter on dive media grid**: no new performance hit — source-type filter is indexed.

### Security considerations

- All credentials in keychain — never in shared preferences or plaintext columns.
- HTTPS required by default; HTTP allowed only for explicitly trusted hosts (Settings toggle, off by default).
- Cert pinning not implemented in initial design; defers to platform cert validation.
- iOS bookmark blobs are device-bound by Apple's API; useless if exfiltrated.
- OAuth uses PKCE wherever possible (no client secret embedded). Services that require client secret addressed per-connector.
- `flutter_secure_storage` on macOS uses user keychain; unlocked Mac can read values. Acceptable risk.

### Telemetry / observability

Submersion's existing logging pipeline used. New log channels:
- `media.resolver.<sourceType>` — resolution attempts, failures, latencies
- `media.fetch.<sourceType>` — eager-fetch pipeline activity
- `media.subscription` — subscription polls, errors, dedup events
- `media.connector.<connectorType>` — per-connector API call activity

No new telemetry endpoints; logs are local-only, accessible via existing diagnostics export.

### Backwards compatibility

- Existing dive media UX unchanged for users who never opt into new sources. Phase 1 `MediaItemView` refactor is bit-for-bit equivalent (covered by feature-flagged dual-display path).
- Schema migration is one-way; only destructive change is the additive column set — existing rows keep working.
- Old app versions opening a database written by a new version fail Drift's schema version check (existing behavior, unchanged).
- Sync compatibility: an old client receiving a row with `sourceType = networkUrl` from a newer client doesn't display the row; no crashes (existing "ignore unknown columns" sync behavior).

### Internationalization

All new user-facing strings flow through the existing l10n pipeline. Source-type labels, error messages, badge text, settings labels — all translatable.

### Accessibility

- `MediaItemView` exposes semantic labels: "Photo from <source name>, taken <date>" for available; "Photo unavailable: <reason>" for unavailable.
- Source-type badges include both icon and visible text label.
- Unified picker page tabs are keyboard-navigable.
- Connector browse page supports VoiceOver/TalkBack.

## Testing Strategy

### Test pyramid

| Layer | Count target | Speed | Purpose |
|---|---|---|---|
| **Unit tests** | High volume | <100 ms each | Per-component correctness |
| **Integration tests** | ~50 across all phases | <2 s each | Multi-component paths |
| **Widget tests** | ~20 | <2 s each | UI behavior |
| **End-to-end tests** | ~10 critical paths | <30 s each | Full app launch + user flow against in-memory DB with mocked network/filesystem |
| **Real-service tests** | One per connector | Variable | Phase 5 connectors against actual APIs — gated, not run by default |

### Per-phase test packages

Each phase's tests live alongside the code they cover.

**Phase 1**:
- `test/features/media/domain/media_source_type_test.dart`
- `test/features/media/domain/media_source_data_test.dart`
- `test/features/media/data/resolvers/platform_gallery_resolver_test.dart`
- `test/features/media/data/resolvers/signature_resolver_test.dart`
- `test/features/media/data/services/media_source_resolver_registry_test.dart`
- `test/core/database/migrations/migration_27_test.dart` — runs against snapshots of databases at version 26 with various row mixes; verifies backfill rules
- `test/features/media/platform/local_media_platform_test.dart` — channel mocked; round-trips bookmark create/resolve/release
- `test/features/media/presentation/widgets/media_item_view_test.dart`
- `test/integration/sync/media_origin_device_sync_test.dart`

**Phase 2**:
- `test/features/media/data/resolvers/local_file_resolver_test.dart`
- `test/features/media/data/services/exif_extractor_test.dart`
- `test/features/media/domain/services/dive_photo_matcher_test.dart`
- `test/features/media/presentation/pages/photo_picker_page_files_tab_test.dart`
- `test/integration/local_file_link_flow_test.dart`
- `test/integration/android_uri_budget_test.dart`
- `test/integration/ios_bookmark_persistence_test.dart`

**Phase 3**:
- `test/features/media/data/resolvers/network_url_resolver_test.dart`
- `test/features/media/data/services/network_credentials_service_test.dart`
- `test/features/media/data/parsers/atom_manifest_parser_test.dart`
- `test/features/media/data/parsers/json_manifest_parser_test.dart`
- `test/features/media/data/parsers/csv_manifest_parser_test.dart`
- `test/features/media/data/services/subscription_poller_test.dart`
- `test/features/media/data/services/eager_fetch_pipeline_test.dart`
- `test/features/media/presentation/pages/photo_picker_page_url_tab_test.dart`
- `test/integration/network_url_link_flow_test.dart`
- `test/integration/manifest_subscription_flow_test.dart`
- `test/integration/cross_device_manifest_dedup_test.dart`

**Phase 4**:
- `test/features/media/domain/services/service_connector_test.dart` — interface contract tests using a `FakeServiceConnector`
- `test/features/media/data/services/connector_token_manager_test.dart`
- `test/features/media/data/services/service_connector_registry_test.dart`
- `test/features/media/presentation/pages/connector_signin_page_test.dart`
- `test/features/media/presentation/pages/connector_browse_page_test.dart`
- `test/features/media/data/connectors/mock_service_connector_test.dart`
- `test/integration/connector_oauth_flow_test.dart`
- `test/integration/connector_signed_url_expiration_test.dart`
- `test/integration/cross_device_connector_signin_test.dart`

**Phase 5** — each connector:
- `test/features/media/connectors/<connector>/<connector>_connector_test.dart`
- `test/features/media/connectors/<connector>/<connector>_oauth_test.dart` (OAuth connectors)
- `test/integration/<connector>_real_test.dart` (gated by env var)

### Cross-phase tests in `test/integration/cross_phase/`

- `mixed_source_dive_test.dart` — single dive with photos from gallery, local file, URL, manifest, and service connector simultaneously. Display, multi-select, bulk delete, EXIF-driven dive-profile overlay all work uniformly.
- `cross_device_full_sync_test.dart` — two simulated devices add media from various sources, sync, verify per-device unavailability rules.
- `migration_with_real_data_test.dart` — loads anonymized production DB snapshot, runs phase 1 migration, verifies every existing row's `sourceType` correctly backfilled.

### Fixtures and infrastructure

- `test/fixtures/media/` — JPEG with EXIF, HEIC with EXIF, JPEG without EXIF, PNG, MP4 with metadata, MOV without metadata.
- `test/fixtures/manifests/` — Atom (Flickr, Piwigo, generic), JSON (full, minimal, malformed), CSV (various column shapes).
- `test/helpers/mock_local_media_platform.dart`
- `test/helpers/fake_http_client.dart`
- `test/helpers/in_memory_credentials_storage.dart`
- `test/helpers/two_device_sync_harness.dart`

### CI integration

Default `flutter test` (per PR): all unit + integration (except gated real-service) + widget + cross-phase tests.

Nightly CI: real-service connector tests, full migration test against production snapshot, performance regression tests.

Pre-push hook runs default `flutter test` (per `CLAUDE.md`).

### Performance regression tests

Three benchmarks:
- **Cold dive list render** with 100 dives, 5 mixed-source media each — first-paint time and memory peak.
- **Bulk link** of 500 photos via folder pick — end-to-end commit time and memory peak.
- **Subscription poll** of 1,000-entry manifest — parse + diff + insert time.

Baselines stored as JSON under `test/performance/baselines/`. CI fails perf job on regression past tolerance.

### Manual test plans

Each phase's PR includes a manual test plan section. Phase 5 connector PRs always include "test against a real instance" — automated tests against canned responses don't catch breaking API changes.

## Open Questions

None outstanding. All major decisions confirmed during design:

- Pure-reference model (not copy) for all new sources.
- All-platform support including iOS bookmarks and Android persistable URIs.
- Both filesystem and HTTP-based network sources first-class.
- Manifest support for Atom/RSS, JSON, CSV.
- Subscription default off, opt-in.
- Per-host credentials with Settings management.
- `cached_network_image` plus eager pre-fetch on link.
- Eager EXIF extraction at link time.
- Source badges shown only for unavailable photos.
- Verification: filesystem lazy-on-display, HTTP user-triggered scan only, no periodic background sweep.
- `connector_accounts` per-device, no credential sync.
- Cross-device polling: every device polls independently, dedup via unique `(subscriptionId, entryKey)`.
- Settings page placement: Settings → Data → Media Sources.
- Multi-quarter spec accepted; build in five sequential phases.

## Appendix A — Submersion JSON Manifest v1

The full JSON manifest format spec lives in `docs/superpowers/specs/manifest_json_v1.md` (created during phase 3) and is documented for users to author their own manifests. Fields summary:

- `version` (number, required, currently `1`)
- `title` (string, optional) — display name for the manifest
- `items` (array, required) — list of entries

Each entry:
- `id` (string, optional) — stable identity; falls back to `SHA(url + takenAt ?? '')`
- `url` (string, required) — image or video URL
- `thumbnailUrl` (string, optional) — preview URL for cheap thumbnails
- `takenAt` (ISO 8601 string, optional) — capture timestamp for auto-match
- `caption` (string, optional)
- `mediaType` (string, optional) — `photo` or `video`; defaults to `photo`
- `lat` / `lon` (numbers, optional) — GPS coordinates
- `width` / `height` (numbers, optional) — pixel dimensions
- `durationSeconds` (number, optional) — video duration

## Appendix B — Files Created vs Modified (Phase 1)

**Created:**
- `lib/features/media/domain/entities/media_source_type.dart`
- `lib/features/media/domain/value_objects/media_source_data.dart`
- `lib/features/media/domain/value_objects/media_source_metadata.dart`
- `lib/features/media/domain/value_objects/verify_result.dart`
- `lib/features/media/domain/services/media_source_resolver.dart`
- `lib/features/media/data/resolvers/platform_gallery_resolver.dart`
- `lib/features/media/data/resolvers/signature_resolver.dart`
- `lib/features/media/data/services/media_source_resolver_registry.dart`
- `lib/features/media/data/services/local_media_platform.dart`
- `lib/features/media/presentation/widgets/media_item_view.dart`
- `lib/features/media/presentation/widgets/unavailable_media_placeholder.dart`
- `lib/features/media/presentation/pages/media_sources_page.dart`
- `ios/Runner/LocalMediaHandler.swift`
- `android/app/src/main/kotlin/.../LocalMediaHandler.kt`
- Test files per phase 1 listing

**Modified:**
- [lib/core/database/database.dart](lib/core/database/database.dart) — schema version bump, new columns and tables, migration block
- [lib/features/media/domain/entities/media_item.dart](lib/features/media/domain/entities/media_item.dart) — new fields and `copyWith`
- [lib/features/media/data/repositories/media_repository.dart](lib/features/media/data/repositories/media_repository.dart) — handles new columns
- [lib/features/media/presentation/widgets/dive_media_section.dart](lib/features/media/presentation/widgets/dive_media_section.dart) — uses `MediaItemView`
- [lib/features/media/presentation/pages/photo_viewer_page.dart](lib/features/media/presentation/pages/photo_viewer_page.dart) — uses `MediaItemView`
- [lib/features/media/presentation/pages/trip_photo_viewer_page.dart](lib/features/media/presentation/pages/trip_photo_viewer_page.dart) — uses `MediaItemView`
- [lib/features/media/presentation/pages/photo_picker_page.dart](lib/features/media/presentation/pages/photo_picker_page.dart) — tab shell
- [lib/features/settings/presentation/pages/settings_page.dart](lib/features/settings/presentation/pages/settings_page.dart) — Media Sources entry under Data
- Sync engine files — `noSync` registrations, `originDeviceId` population, merge rules

Files created/modified for phases 2–5 are detailed in the per-phase implementation plans (created when each phase enters implementation).
