# Trip Photo Galleries Design

## Overview

Add photo gallery functionality to trips, showing aggregated photos from all dives within a trip. Photos remain linked to individual dives (no schema changes) but can be browsed at the trip level.

## Decisions

| Question | Decision |
|----------|----------|
| Scope | Aggregated view only - no direct trip→media relationship |
| Location | Dedicated collapsible section on trip detail page |
| Organization | Photos grouped by dive with collapsible sections |
| Preview | Responsive row showing as many photos as fit screen width |
| Viewer | Trip-scoped viewer, swipe through all trip photos with dive context overlays |
| Empty state | Show section with CTA to auto-link photos from device gallery |
| Auto-link | Always available via "Scan for photos" button in section header |

## Data Layer

### New Providers (`trip_media_providers.dart`)

**`mediaForTripProvider(tripId)`**
- Returns `Map<Dive, List<MediaItem>>` preserving dive grouping
- Process:
  1. Get all dive IDs for trip via `diveIdsForTripProvider`
  2. For each dive, fetch media with enrichment via `mediaForDiveProvider`
  3. Return grouped map
- Riverpod handles caching and invalidation

**`mediaCountForTripProvider(tripId)`**
- Returns total photo count across all dives in trip
- Used for badges and headers

### New Service (`trip_media_scanner.dart`)

**`TripMediaScanner.scanAndLinkPhotos(tripId)`**
1. Get all dives for trip with start/end times
2. Query device gallery for photos in trip date range (with 1-hour buffer)
3. Match each photo to a dive by timestamp:
   - Exact match: `dive.startTime <= photo.takenAt <= dive.endTime`
   - Buffer match: Within 30 minutes of dive boundaries
   - Unmatched: Photos outside all dive windows
4. Filter out already-linked photos by `platformAssetId`
5. Return `ScanResult` with matched and unmatched photos

## UI Components

### 1. TripPhotoSection (`trip_photo_section.dart`)

Collapsible card on trip detail page.

```
+---------------------------------------------+
| Photos (24)                    [Scan] [v]   |
+---------------------------------------------+
| [img] [img] [img] [img] [+16]          ->   |
+---------------------------------------------+
```

- Header: Photo count, "Scan for photos" icon button, expand/collapse
- Body: Horizontal scrollable row of thumbnails
- Last thumbnail shows "+N" if more photos exist
- Tap opens full gallery page
- Empty state: "No photos yet" + "Scan device gallery" button

### 2. TripGalleryPage (`trip_gallery_page.dart`)

Route: `/trips/:id/gallery`

Scrollable list of dive sections with 4-column photo grids.

```
+---------------------------------------------+
| <- Trip Photos                      [Scan]  |
+---------------------------------------------+
| v Dive #3 - Blue Corner (6 photos)          |
| [img] [img] [img] [img]                     |
| [img] [img]                                 |
+---------------------------------------------+
| v Dive #2 - Manta Point (4 photos)          |
| [img] [img] [img] [img]                     |
+---------------------------------------------+
```

- Each dive section: Collapsible header + photo grid
- Dive header: Dive number, site name, photo count
- Tap photo opens trip-scoped viewer

### 3. TripPhotoViewerPage (`trip_photo_viewer_page.dart`)

Full-screen photo viewer for browsing all trip photos.

- Input: `tripId`, `initialMediaId`, flat list of all trip media
- Swipe left/right through ALL trip photos (across dives)
- Overlays:
  - Dive context: Site name, dive date
  - Enrichment data: Depth, temperature, profile graph
- Overlays update smoothly when crossing dive boundaries

### 4. ScanResultsDialog (`scan_results_dialog.dart`)

Bottom sheet showing scan results before linking.

```
+---------------------------------------------+
| Found 23 new photos                         |
+---------------------------------------------+
| [x] Dive #3 - Blue Corner         8 photos  |
| [x] Dive #2 - Manta Point         6 photos  |
| [x] Dive #1 - Coral Garden        5 photos  |
| ------------------------------------------- |
| (!) Unmatched (outside dive times) 4 photos |
|     [View & assign manually]                |
+---------------------------------------------+
|        [Cancel]    [Link 19 photos]         |
+---------------------------------------------+
```

- Checkboxes to include/exclude dive groups
- Unmatched photos can be manually assigned
- Link button shows count of selected photos
- Progress indicator during linking

## File Structure

### New Files

```
lib/features/trips/presentation/
  widgets/
    trip_photo_section.dart
  pages/
    trip_gallery_page.dart
  providers/
    trip_media_providers.dart

lib/features/media/presentation/
  pages/
    trip_photo_viewer_page.dart
  widgets/
    scan_results_dialog.dart

lib/features/media/data/services/
  trip_media_scanner.dart
```

### Modified Files

```
lib/features/trips/presentation/pages/trip_detail_page.dart
  - Add TripPhotoSection widget

lib/core/router/app_router.dart
  - Add /trips/:id/gallery route
```

## Edge Cases

| Scenario | Handling |
|----------|----------|
| No photos found | "All photos already linked" message |
| No dives in trip | "Add dives first to match photos" message |
| Gallery permission denied | Settings redirect prompt |
| Photo at exact dive boundary | Assign to dive that contains timestamp |
| Orphaned gallery photo | Show orphaned indicator, allow re-verification |

## Testing Strategy

| Layer | Focus |
|-------|-------|
| Unit | `TripMediaScanner` - timestamp matching, timezone handling, boundary conditions |
| Unit | Providers - aggregation logic, cache invalidation |
| Widget | `TripPhotoSection` - empty state, loading, interactions |
| Widget | `ScanResultsDialog` - checkbox state, count calculations |
| Integration | Full scan -> link -> display flow with mock gallery |
