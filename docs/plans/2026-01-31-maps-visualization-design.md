# Maps & Visualization Design

**Date:** 2026-01-31
**Status:** Approved
**Feature:** Offline Maps & Dive Activity Heat Maps

---

## Overview

This design covers two map visualization features for Submersion:

1. **Offline Maps** - Hybrid tile caching with automatic background caching plus explicit region downloads
2. **Heat Map Visualization** - Gradient heat maps showing dive activity (Dives page) and site coverage (Sites page)

---

## Feature Requirements

### Offline Maps

- Automatic tile caching as user browses maps (LRU eviction, configurable limit)
- Explicit region download via bounding box selector
- User selects zoom levels to download (default: 8-16)
- Region management page for viewing, renaming, and deleting downloads
- Storage statistics and cache clearing options
- Offline mode indicator with graceful degradation
- Smart region naming via reverse geocoding

### Heat Maps

**Dive Activity Heat Map (Dives Page):**
- Canvas-based gradient heat map layer
- Data from dives grouped by site location, weighted by dive count
- Blue to Yellow to Red color gradient
- Opacity and radius controls
- Toggle between List / Map / Activity views

**Site Coverage Heat Map (Sites Page):**
- Same heat map rendering engine
- Data from all saved dive sites
- Shows geographic distribution of known sites
- Toggle between List / Map / Coverage views

---

## Architecture

### Feature Structure

```
lib/features/maps/
├── data/
│   ├── repositories/
│   │   └── offline_map_repository.dart      # Tile storage operations
│   └── services/
│       ├── tile_cache_service.dart          # Automatic tile caching
│       └── region_download_service.dart     # Bulk region downloads
├── domain/
│   └── entities/
│       ├── cached_region.dart               # Downloaded region metadata
│       └── heat_map_point.dart              # Weighted location for heat map
├── presentation/
│   ├── pages/
│   │   └── offline_maps_page.dart           # Manage downloaded regions
│   ├── widgets/
│   │   ├── heat_map_layer.dart              # Gradient heat overlay
│   │   ├── heat_map_controls.dart           # Opacity/radius sliders
│   │   ├── region_selector.dart             # Bounding box drawing
│   │   ├── region_download_dialog.dart      # Download configuration
│   │   └── download_progress_card.dart      # Download status UI
│   └── providers/
│       ├── heat_map_providers.dart          # Heat map data
│       └── offline_map_providers.dart       # Cache state management
```

### Database Schema

```sql
-- Track explicitly downloaded map regions
CREATE TABLE cached_regions (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  min_lat REAL NOT NULL,
  max_lat REAL NOT NULL,
  min_lng REAL NOT NULL,
  max_lng REAL NOT NULL,
  min_zoom INTEGER NOT NULL,
  max_zoom INTEGER NOT NULL,
  tile_count INTEGER NOT NULL,
  size_bytes INTEGER NOT NULL,
  created_at INTEGER NOT NULL,
  last_accessed_at INTEGER NOT NULL
);
```

---

## Offline Maps Implementation

### Hybrid Caching Strategy

**Automatic Caching (Background):**
- Tiles cached to local storage as user pans/zooms
- Uses `path_provider` documents directory
- LRU eviction when cache exceeds limit (default: 500MB)
- Cache structure: `tiles/{source}/{z}/{x}/{y}.png`

**Explicit Region Downloads:**
- User draws bounding box on map
- Selects zoom levels to download
- Background download with progress tracking
- Downloads are resumable if interrupted

### Tile Provider

Custom `CachedTileProvider` that:
1. Checks local cache first
2. Falls back to network if not cached
3. Automatically caches fetched tiles
4. Returns placeholder if offline and not cached

### Region Selector UI

```
┌─────────────────────────────────────┐
│  Draw a rectangle to select area    │
│  ┌─────────────────────┐            │
│  │ o───────────────o   │            │
│  │ │   Selected    │   │            │
│  │ │     Area      │   │            │
│  │ o───────────────o   │            │
│  └─────────────────────┘            │
│                                     │
│  Est. 847 tiles (~42 MB)            │
│  [Cancel]  [Download Zoom 8-16 v]   │
└─────────────────────────────────────┘
```

### Storage Estimates

- Zoom 10 (city level): ~50KB per tile
- Zoom 14 (neighborhood): ~30KB per tile
- Typical dive destination (50km sq) at zoom 8-16: ~50-100MB

---

## Heat Map Implementation

### Algorithm

1. **Data Collection** - Query sites with coordinates, include dive count
2. **Point Weighting** - Each site becomes a heat point weighted by dive count
3. **Kernel Smoothing** - Apply Gaussian blur for smooth gradients
4. **Color Mapping** - Map intensity to color gradient

### Color Gradient

| Intensity | Dives | Color |
|-----------|-------|-------|
| Low | 1-2 | Blue (#3B82F6) |
| Medium | 3-5 | Cyan to Green (#06B6D4 to #22C55E) |
| High | 6-10 | Yellow (#EAB308) |
| Very High | 10+ | Orange to Red (#F97316 to #EF4444) |

### Rendering

Canvas-based `CustomPainter` approach:
- Draws heat map on canvas as single layer
- Renders over map tiles
- Smooth gradients, performant with hundreds of points

### Controls

- **Opacity slider** - Adjust transparency (default 60%)
- **Radius slider** - Control spread of heat points
- **Toggle** - Show/hide heat map layer

---

## Navigation & Integration

### Dives Page

```
┌─────────────────────────────────────┐
│  Dive Log                    [:]   │
│  ┌───────┬───────┬──────────┐      │
│  │ List  │  Map  │ Activity │      │
│  └───────┴───────┴──────────┘      │
│         ^          ^               │
│    Site markers   Heat map         │
└─────────────────────────────────────┘
```

### Sites Page

```
┌─────────────────────────────────────┐
│  Dive Sites                  [:]   │
│  ┌───────┬───────┬──────────┐      │
│  │ List  │  Map  │ Coverage │      │
│  └───────┴───────┴──────────┘      │
│         ^          ^               │
│   Site markers   Heat map          │
└─────────────────────────────────────┘
```

### Offline Maps Access

- Settings > Storage > Offline Maps
- Quick action on any map: "Download this area" in overflow menu

### Offline Indicator

- Banner/icon when device is offline
- Cached tiles display normally
- Uncached areas show placeholder
- Heat maps work offline (local database)

---

## Dependencies

```yaml
dependencies:
  flutter_map_tile_caching: ^9.1.0  # Mature caching for flutter_map
```

No additional packages needed for heat map (custom implementation).

---

## Data Providers

### Heat Map Providers

```dart
// Dive activity heat map - aggregates dives by site location
final diveActivityHeatMapProvider = FutureProvider<List<HeatMapPoint>>((ref) async {
  // Query dives grouped by site, weight by dive count
});

// Site coverage heat map - all sites equally weighted
final siteCoverageHeatMapProvider = FutureProvider<List<HeatMapPoint>>((ref) async {
  // Query all sites with coordinates
});
```

### Offline Map Providers

```dart
// List of downloaded regions
final cachedRegionsProvider = FutureProvider<List<CachedRegion>>((ref) async {
  // Query cached_regions table
});

// Cache statistics
final cacheStatsProvider = FutureProvider<CacheStats>((ref) async {
  // Calculate total size, tile count, etc.
});

// Download progress notifier
final downloadProgressProvider = StateNotifierProvider<DownloadProgressNotifier, DownloadState>((ref) {
  // Track active downloads
});
```

---

## Implementation Phases

### Phase 1: Offline Maps Infrastructure
1. Add flutter_map_tile_caching dependency
2. Create CachedTileProvider
3. Implement automatic background caching
4. Update existing maps to use cached provider

### Phase 2: Region Downloads
1. Add cached_regions table to database
2. Create RegionSelector widget (bounding box)
3. Implement RegionDownloadService
4. Create OfflineMapsPage for management

### Phase 3: Heat Map Core
1. Create HeatMapPoint entity
2. Implement HeatMapLayer CustomPainter
3. Create heat map providers (dive activity, site coverage)
4. Add HeatMapControls widget

### Phase 4: Integration
1. Add Activity view toggle to Dives page
2. Add Coverage view toggle to Sites page
3. Add offline download quick action to maps
4. Add Settings > Storage > Offline Maps navigation

---

## Testing Strategy

### Unit Tests
- Heat map point aggregation logic
- Color gradient interpolation
- Tile count estimation for regions
- Cache size calculations

### Widget Tests
- RegionSelector interaction (draw, resize, confirm)
- HeatMapControls state management
- OfflineMapsPage list display

### Integration Tests
- Download region flow (select > configure > download > verify)
- Heat map toggle and display
- Offline mode behavior

---

## Success Criteria

1. User can download map regions for offline use before trips
2. Maps display cached tiles when offline
3. Heat map clearly shows dive activity concentration
4. Both Dives and Sites pages have functional heat map views
5. Storage management allows clearing cache when needed
6. Performance remains smooth with 500+ dive sites
