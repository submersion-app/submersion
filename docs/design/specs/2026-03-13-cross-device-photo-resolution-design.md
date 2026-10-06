# Cross-Device Photo Resolution

## Problem

Submersion stores references to device gallery photos using `platformAssetId` — a platform-specific identifier (e.g., Apple Photos' `PHAsset` local identifier). These IDs are device-specific: the same photo synced via iCloud Photos or Google Photos gets a different local identifier on each device.

When the Submersion database syncs between devices (file-level sync via iCloud or Google Drive), the `platformAssetId` values from the originating device don't resolve on the receiving device. Photos appear broken even though they exist in the local gallery.

## Solution

A local-only asset resolution cache that maps synced media records to device-specific gallery asset IDs. Each device maintains its own cache independently. The synced database is never modified — resolution is purely local.

## Architecture

### Local Cache Database

A separate Drift database (`submersion_local.db`) stored in `getApplicationSupportDirectory()` — never in the synced location. This directory is device-local on both iOS and macOS. On iOS, `Application Support` is excluded from iCloud backup by default. On macOS, `~/Library/Application Support/` is not synced by iCloud Drive (iCloud only syncs the iCloud Drive folder and app-specific iCloud containers). No explicit `NSURLIsExcludedFromBackupKey` is needed.

**Table: `local_asset_cache`**

| Column | Type | Description |
|--------|------|-------------|
| `media_id` | TEXT, PK | FK to the synced Media table |
| `local_asset_id` | TEXT, nullable | Platform-specific asset ID on this device (null = unresolved) |
| `resolved_at` | INTEGER | When the resolution was performed (ms epoch) |
| `resolution_method` | TEXT | How it was matched: `original_id`, `filename_timestamp`, `timestamp_dimensions`, `unresolved` |
| `attempt_count` | INTEGER, default 0 | Number of resolution attempts. Used for escalating backoff: `[24h, 3d, 7d][min(attempt_count, 2)]` |

### Resolution Strategy

When a photo needs to be displayed:

1. **Check local cache** — if `local_asset_cache` has an entry for this `mediaId`, use `local_asset_id`
2. **Try original ID** — attempt `AssetEntity.fromId(platformAssetId)` from the synced DB. Verify the asset is actually loadable (call `thumbnailDataWithSize` to confirm it returns data, not just a non-null `AssetEntity`). If it resolves and loads, cache as `original_id` method
3. **Search gallery by metadata** — if original ID fails, run tiered matching:
   - **Tier 1 (filename + timestamp):** Query `photo_manager` for assets within +/-5 seconds of `takenAt`. Match by `originalFilename` exact match. If exactly one match, cache as `filename_timestamp`. If multiple matches, fall through to Tier 2.
   - **Tier 2 (timestamp + dimensions):** Reuse the assets from the Tier 1 gallery query (same +/-5 second window). Apply a tighter match predicate: `width` + `height` must match exactly, and `takenAt` must be within +/-2 seconds. The tighter time window reduces false positives from burst-mode photos with identical dimensions. If exactly one match, cache as `timestamp_dimensions`. If multiple matches, fall through to Tier 3.
   - **Tier 3 (unresolved):** No unique match found. Cache with `local_asset_id = null` and method `unresolved`. Show "not available on this device" placeholder. Re-attempt with escalating backoff: 24 hours, then 3 days, then 7 days (accommodates slow iCloud Photos sync for large libraries).

### Batch Resolution

When the app detects multiple unresolved items for the same dive, it resolves them all in one gallery query (using the dive's time window) rather than N individual queries. This avoids repeated gallery scans when opening a dive with many photos.

### Cache Invalidation

- On app launch: no invalidation. Gallery asset IDs are stable on the same device.
- If `photo_manager` returns null for a cached `local_asset_id`: the photo was deleted from the gallery. Clear the cache entry and re-attempt resolution.
- Unresolved entries re-attempt with escalating backoff (24 hours, 3 days, 7 days) based on `resolved_at` and `attempt_count`.

### Rebuild Safety

The local cache is entirely derivable. If the file is deleted (app reinstall, clearing cache), the app re-resolves photos lazily as they are displayed. No data loss.

## Integration Points

### AssetResolutionService (new)

Single class that owns the resolution logic. Takes a `MediaItem`, returns the best local asset ID (from cache, original ID, or fresh resolution). Depends on `PhotoPickerService` (for gallery queries), `MediaRepository` (for looking up `MediaItem` metadata when resolving by ID), and the local cache database.

Includes a coalescing mechanism: when multiple resolution requests arrive concurrently for the same dive (e.g., opening a dive with 20 photos triggers 20 providers simultaneously), the service batches them into a single gallery query using the dive's time window. Implemented via a resolution lock per dive ID — the first request triggers the batch query, subsequent concurrent requests await the same future.

### Provider Layer (two-tier approach)

The existing raw-asset-ID providers are kept unchanged for the **photo picker flow** (where no `mediaId` exists yet — the user is selecting from the gallery before any `MediaItem` record is created):

- `assetThumbnailProvider(String platformAssetId)` — unchanged, used by photo picker
- `assetFullResolutionProvider(String platformAssetId)` — unchanged, used by photo picker

New **resolved** providers are added for the **display flow** (showing already-linked media):

- `resolvedThumbnailProvider(MediaItem item)` — resolves `item` to a local asset ID via `AssetResolutionService`, then loads thumbnail. Returns `Uint8List?` or a resolution status (unresolved/unavailable).
- `resolvedFullResolutionProvider(MediaItem item)` — same pattern for full-res display.
- `resolvedFilePathProvider(MediaItem item)` — same pattern for video playback.

### Widget Call Site Changes

All widget files that currently pass `item.platformAssetId!` directly to the raw providers must switch to the resolved providers. These files each need modification:

| File | Current Usage | Change |
|------|--------------|--------|
| `dive_media_section.dart` | `assetThumbnailProvider(item.platformAssetId!)` | Use `resolvedThumbnailProvider(item)`, add unavailable placeholder |
| `photo_viewer_page.dart` | `assetFullResolutionProvider(item.platformAssetId!)`, `assetFilePathProvider(...)` (4 provider calls + 1 cache invalidation + 1 metadata write) | Use resolved variants for display and share flows. Metadata write stays as-is (originating device only). Cache invalidation (`ref.invalidate`) targets the resolved provider instead. |
| `trip_photo_viewer_page.dart` | `assetFullResolutionProvider(item.platformAssetId!)` (2 references) | Use `resolvedFullResolutionProvider(item)` |
| `trip_photo_section.dart` | `assetThumbnailProvider(item.platformAssetId!)` | Use `resolvedThumbnailProvider(item)` |
| `trip_gallery_page.dart` | `assetThumbnailProvider(item.platformAssetId!)` | Use `resolvedThumbnailProvider(item)` |

### "Not Available" Placeholder (new widget)

Replaces the broken image icon for unresolved photos. Shows:

- "Not available on this device" message
- Photo metadata (timestamp, depth if enriched) so the user knows what the photo represents
- Visually distinct from the "orphaned" placeholder (which means the photo was deleted from the gallery)

### PhotoPickerService Interface

The existing `PhotoPickerService.getAssetsInDateRange()` method already provides the query capability needed for resolution (date-range filtered gallery access with metadata). No interface changes needed — `AssetResolutionService` uses this method for gallery queries and then applies the tiered matching predicates on the returned `AssetInfo` objects.

### Unchanged Components

- **Synced `Media` table** — no schema changes
- **`MediaImportService`** — import still stores the originating device's `platformAssetId`
- **`MediaRepository`** — no schema/CRUD changes (but used as a dependency by `AssetResolutionService` for metadata lookups)
- **Raw asset providers** — kept for photo picker flow
- **Photo picker page** — unchanged, continues using raw `platformAssetId` providers

### Desktop Platforms

Cross-device resolution is not applicable on Windows/Linux, where `PhotoPickerServiceDesktop` uses file-based access rather than gallery asset IDs. The resolved providers detect the desktop service and fall through to `filePath`-based loading directly.

## Platform Scope

Covers both Apple Photos (iOS/macOS) and Google Photos (Android). The resolution strategy is platform-agnostic — it relies on `photo_manager`'s cross-platform API for gallery queries, and the metadata matching (filename, timestamp, dimensions) works identically regardless of platform.

## Local Database Lifecycle

**Initialization:** `LocalCacheDatabaseService` (new singleton, separate from `DatabaseService`) initializes at app startup alongside the main database. Lightweight Drift database with a single table. Initialized wherever `DatabaseService.initialize()` is called in the app startup sequence.

**Location:** Always in `getApplicationSupportDirectory()`. On iOS, `Application Support` is excluded from iCloud backup by default. On macOS, `~/Library/Application Support/` is not synced by iCloud Drive. No explicit `NSURLIsExcludedFromBackupKey` is needed.

**Testing:** Constructor injection of the Drift `QueryExecutor`, same pattern as `DatabaseService.setTestDatabase`.

## File Inventory

### New Files

- `lib/core/database/local_cache_database.dart` — Drift database definition for local cache
- `lib/core/services/local_cache_database_service.dart` — singleton service for local cache DB lifecycle
- `lib/features/media/data/services/asset_resolution_service.dart` — resolution logic with batch coalescing
- `lib/features/media/data/repositories/local_asset_cache_repository.dart` — cache CRUD
- `lib/features/media/presentation/providers/resolved_asset_providers.dart` — new resolved providers for display flow
- `lib/features/media/presentation/widgets/unavailable_photo_placeholder.dart` — "not on this device" widget
- Tests for each of the above

### Modified Files

- `lib/features/media/presentation/widgets/dive_media_section.dart` — switch to resolved providers, add unavailable placeholder
- `lib/features/media/presentation/pages/photo_viewer_page.dart` — switch to resolved providers (6 call sites)
- `lib/features/media/presentation/pages/trip_photo_viewer_page.dart` — switch to resolved providers (2 call sites)
- `lib/features/trips/presentation/widgets/trip_photo_section.dart` — switch to resolved providers
- `lib/features/trips/presentation/pages/trip_gallery_page.dart` — switch to resolved providers
- App startup initialization — add `LocalCacheDatabaseService.initialize()` call
