# Photo Picker Integration Design

## Overview

Custom gallery browser for adding dive photos with intelligent date filtering. Shows only photos taken during the dive's time window, with multi-select support and automatic depth/temperature enrichment.

## Key Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Selection mode | Multi-select gallery browser | Divers take multiple photos per dive |
| Date filtering | Dive duration ± 30 min buffer | Catches pre/post-dive shots automatically |
| Package | photo_manager (iOS/Android/macOS) | Direct gallery query by date range |
| Desktop fallback | image_picker (Windows/Linux) | Graceful degradation, no platform blocked |
| Enrichment timing | On import | Data ready immediately for thumbnail badges |

## Architecture

### File Structure

```
lib/features/media/
├── data/services/
│   ├── photo_picker_service.dart         # Abstract interface
│   ├── photo_picker_service_mobile.dart  # photo_manager (iOS/Android/macOS)
│   └── photo_picker_service_desktop.dart # image_picker fallback (Windows/Linux)
├── presentation/
│   ├── pages/
│   │   └── photo_picker_page.dart        # Gallery browser UI
│   └── providers/
│       └── photo_picker_providers.dart   # State management
```

### PhotoPickerService Interface

```dart
abstract class PhotoPickerService {
  /// Query gallery for photos/videos in date range
  Future<List<AssetInfo>> getAssetsInDateRange(DateTime start, DateTime end);

  /// Get thumbnail bytes for grid display
  Future<Uint8List?> getThumbnail(String assetId, {int size = 200});

  /// Check/request photo library permission
  Future<PermissionStatus> requestPermission();

  /// Whether this platform supports date-filtered gallery browsing
  bool get supportsGalleryBrowsing;
}
```

### Platform Detection

```dart
final photoPickerServiceProvider = Provider<PhotoPickerService>((ref) {
  if (Platform.isWindows || Platform.isLinux) {
    return PhotoPickerServiceDesktop();
  }
  return PhotoPickerServiceMobile();
});
```

## UI Design

### PhotoPickerPage (iOS/Android/macOS)

```
┌─────────────────────────────────────┐
│ ← Select Photos            Done (3) │
├─────────────────────────────────────┤
│ Showing photos from Jan 15, 10:00am │
│ to 11:30am                          │
├─────────────────────────────────────┤
│ ┌─────┐ ┌─────┐ ┌─────┐ ┌─────┐    │
│ │  ✓  │ │     │ │  ✓  │ │     │    │
│ │thumb│ │thumb│ │thumb│ │thumb│    │
│ └─────┘ └─────┘ └─────┘ └─────┘    │
│ ┌─────┐ ┌─────┐ ┌─────┐ ┌─────┐    │
│ │  ✓  │ │ ▶   │ │     │ │     │    │
│ │thumb│ │video│ │thumb│ │thumb│    │
│ └─────┘ └─────┘ └─────┘ └─────┘    │
└─────────────────────────────────────┘
```

**Behaviors:**
- 4-column grid with thumbnails
- Tap to toggle selection (checkmark overlay)
- Videos show play icon
- "Done" button shows count, disabled until ≥1 selected
- Empty state: "No photos found in this time range"

### Desktop Fallback (Windows/Linux)

- Standard OS file picker dialog
- No date filtering (user browses manually)
- Multi-file selection supported

## Import Flow

```dart
Future<void> importSelectedPhotos(List<AssetInfo> selected, Dive dive) async {
  for (final asset in selected) {
    // 1. Create MediaItem with gallery reference
    final mediaItem = MediaItem(
      id: '',
      diveId: dive.id,
      platformAssetId: asset.id,
      filePath: null,  // Reference-only storage
      mediaType: asset.isVideo ? MediaType.video : MediaType.photo,
      takenAt: asset.createDateTime,
      width: asset.width,
      height: asset.height,
      durationSeconds: asset.isVideo ? asset.duration : null,
      latitude: asset.latitude,
      longitude: asset.longitude,
    );

    // 2. Save to database
    final saved = await mediaRepository.createMedia(mediaItem);

    // 3. Calculate enrichment from dive profile
    final enrichment = enrichmentService.calculateEnrichment(
      profile: dive.profile,
      diveStartTime: dive.dateTime,
      photoTime: asset.createDateTime,
    );

    // 4. Save enrichment if depth data available
    if (enrichment.depthMeters != null) {
      await mediaRepository.saveEnrichment(MediaEnrichment(
        id: '',
        mediaId: saved.id,
        diveId: dive.id,
        depthMeters: enrichment.depthMeters,
        temperatureCelsius: enrichment.temperatureCelsius,
        elapsedSeconds: enrichment.elapsedSeconds,
        matchConfidence: enrichment.matchConfidence,
      ));
    }
  }
}
```

## Permission Handling

```
User taps "Add Photo"
        │
        ▼
Check permission status
        │
   ┌────┴────┐
granted     denied/undetermined
   │              │
   ▼              ▼
Open          Request permission
gallery              │
browser        ┌─────┴─────┐
            granted     denied
               │           │
               ▼           ▼
            Open       Show "Open
            gallery    Settings" prompt
            browser
```

## Error Handling

| Error | Handling |
|-------|----------|
| Permission denied | Prompt with "Open Settings" button |
| No photos in range | "No photos found" with expand search option |
| Thumbnail load fail | Placeholder icon |
| Import failure | Log error, skip item, continue with rest |

## Dependencies

**Add to pubspec.yaml:**
```yaml
dependencies:
  photo_manager: ^3.6.0
```

**Platform configuration required:**
- iOS: Add `NSPhotoLibraryUsageDescription` to Info.plist
- Android: Add `READ_EXTERNAL_STORAGE` / `READ_MEDIA_IMAGES` permissions
- macOS: Add `NSPhotoLibraryUsageDescription` to entitlements

## Testing Strategy

- **Unit tests:** PhotoPickerService interface with mock implementations
- **Widget tests:** PhotoPickerPage with mock service returning test assets
- **Integration tests:** Full import flow with test database
