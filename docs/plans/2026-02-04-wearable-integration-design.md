# Wearable Integration Design

**Date:** 2026-02-04
**Status:** Approved
**Phase:** v2.0

---

## Overview

Implement wearable device integration for Submersion, starting with Apple Watch Ultra via HealthKit. This enables users to import dive data from their smartwatch, including depth profiles, temperature, heart rate, and GPS coordinates.

### Scope

**In Scope (This Design):**
- Apple Watch Ultra import via HealthKit
- Full profile data (depth, temperature, heart rate)
- GPS coordinates from workout routes
- Manual import with preview wizard
- Duplicate detection and merge with existing dive computer dives

**Future Scope (Not This Design):**
- Garmin Connect API integration
- Suunto app integration
- Automatic background sync

---

## Architecture

### Directory Structure

```
lib/features/wearables/
├── domain/
│   ├── entities/
│   │   ├── wearable_dive.dart
│   │   └── wearable_device.dart
│   ├── services/
│   │   ├── wearable_import_service.dart
│   │   └── dive_matcher.dart
│   └── repositories/
│       └── wearable_repository.dart
├── data/
│   ├── services/
│   │   └── healthkit_service.dart
│   └── repositories/
│       └── wearable_repository_impl.dart
└── presentation/
    ├── pages/
    │   ├── wearable_list_page.dart
    │   └── wearable_import_page.dart
    ├── widgets/
    │   ├── wearable_dive_card.dart
    │   ├── wearable_dive_preview.dart
    │   └── merge_conflict_dialog.dart
    └── providers/
        └── wearable_providers.dart
```

### Key Design Decisions

1. **Platform abstraction** - `WearableImportService` is an abstract interface. `HealthKitService` implements it for Apple platforms. Future Garmin/Suunto implementations will follow the same interface.

2. **Reuse existing infrastructure** - Uses existing `DiveParser` patterns, `ProfilePointData` format, and duplicate detection from `dive_computer_repository`.

3. **Feature flag for platforms** - HealthKit only available on iOS/macOS. Android/Windows/Linux show "Not available on this platform" gracefully.

---

## Data Model

### HealthKit to Submersion Mapping

| HealthKit Data | Submersion Entity | Notes |
|----------------|-------------------|-------|
| `HKWorkout` (underwater diving) | `Dive` | Core dive record |
| `HKQuantityType.underwaterDepth` | `DiveProfile.depth` | Sampled every 1-2 seconds |
| `HKQuantityType.waterTemperature` | `DiveProfile.temperature` | Less frequent samples |
| `HKQuantityType.heartRate` | `DiveProfile.heartRate` | Already supported |
| `HKWorkout.startDate/endDate` | `Dive.entryTime/exitTime` | Dive timing |
| `HKWorkoutRoute` | `DiveSite.latitude/longitude` | GPS at surface |

### WearableDive Entity

```dart
enum WearableSource { appleWatch, garmin, suunto }

class WearableDive {
  final String sourceId;           // HealthKit UUID for deduplication
  final WearableSource source;
  final DateTime startTime;
  final DateTime endTime;
  final double maxDepth;           // meters
  final double? avgDepth;
  final double? minTemperature;
  final double? maxTemperature;
  final double? avgHeartRate;
  final double? latitude;          // GPS at dive start
  final double? longitude;
  final List<WearableProfileSample> profile;
}

class WearableProfileSample {
  final int timeSeconds;           // Relative to dive start
  final double depth;              // meters
  final double? temperature;       // Celsius
  final int? heartRate;            // BPM
}
```

### Database Migrations

```sql
-- Track wearable source on dives
ALTER TABLE dives ADD COLUMN wearable_source TEXT;
ALTER TABLE dives ADD COLUMN wearable_id TEXT;

-- Heart rate source tracking
ALTER TABLE dive_profiles ADD COLUMN heart_rate_source TEXT;
```

---

## HealthKit Integration

### Package Dependency

```yaml
dependencies:
  health: ^10.2.0
```

### Service Interface

```dart
abstract class WearableImportService {
  Future<bool> isAvailable();
  Future<bool> requestPermissions();
  Future<List<WearableDive>> fetchDives({
    required DateTime startDate,
    required DateTime endDate,
  });
  Future<List<WearableProfileSample>> fetchDiveProfile(String workoutId);
}
```

### iOS/macOS Configuration

```xml
<!-- ios/Runner/Info.plist -->
<key>NSHealthShareUsageDescription</key>
<string>Submersion imports your Apple Watch dive data including depth, temperature, and heart rate to create detailed dive logs.</string>

<key>NSHealthUpdateUsageDescription</key>
<string>Submersion can record dive activities to your Health app.</string>
```

### HealthKit Data Types Required

- `HKWorkoutActivityType.underwaterDiving`
- `HKQuantityType.underwaterDepth`
- `HKQuantityType.waterTemperature`
- `HKQuantityType.heartRate`
- `HKSeriesType.workoutRoute`

---

## Import Wizard UI

### Step 1: Select Dives

- Date range filter (default: last 30 days)
- List of available watch dives with summary info
- Duplicate warning badges for matches
- "Already imported" indicator for previously imported dives
- Multi-select checkboxes

### Step 2: Handle Duplicates

For each dive that matches an existing entry:

- Show side-by-side comparison (existing vs watch)
- Options:
  - **Merge watch data into existing dive** - adds HR profile, GPS coordinates
  - **Import as separate profile** - creates secondary profile source
  - **Skip this dive** - do not import
- "Apply to All" for batch handling

### Step 3: Summary

- Count of dives imported as new
- Count of dives merged with existing
- Count of dives skipped
- "View Imported Dives" action

---

## Duplicate Detection & Merge

### Match Algorithm

```dart
class DiveMatcher {
  double calculateMatchScore(WearableDive wearable, Dive existing) {
    double score = 0.0;

    // Time proximity (weight: 0.5)
    final timeDiff = wearable.startTime.difference(existing.entryTime).abs();
    if (timeDiff.inMinutes <= 5) score += 0.5;
    else if (timeDiff.inMinutes <= 15) score += 0.3;

    // Depth similarity within 10% (weight: 0.3)
    final depthDiff = (wearable.maxDepth - existing.maxDepth).abs();
    if (depthDiff / existing.maxDepth <= 0.10) score += 0.3;
    else if (depthDiff / existing.maxDepth <= 0.20) score += 0.15;

    // Duration similarity within 3 min (weight: 0.2)
    final durationDiff = (wearable.duration - existing.duration).abs();
    if (durationDiff.inMinutes <= 3) score += 0.2;

    return score.clamp(0.0, 1.0);
  }

  bool isProbableDuplicate(double score) => score >= 0.7;
  bool isPossibleDuplicate(double score) => score >= 0.5;
}
```

### Merge Behavior

| Data Field | Merge Behavior |
|------------|----------------|
| Heart rate profile | Add as new data series |
| GPS coordinates | Set on dive site if missing, or create new site |
| Temperature | Keep dive computer data (more accurate) |
| Depth profile | Keep dive computer as primary, store watch as secondary |
| Duration | Keep dive computer timing |

### Deduplication

- Store `wearable_id` (HealthKit UUID) on imported dives
- On future imports, check if UUID exists → mark as "Already imported"

---

## Implementation Phases

### Phase 1: Core Infrastructure
- [ ] Create `features/wearables/` directory structure
- [ ] Add `health` package dependency
- [ ] Implement `WearableImportService` interface
- [ ] Add database migrations
- [ ] Create `WearableDive` and `WearableProfileSample` entities

### Phase 2: HealthKit Integration
- [ ] Implement `HealthKitService` with permission handling
- [ ] iOS/macOS Info.plist configuration
- [ ] Fetch underwater diving workouts
- [ ] Parse depth, temperature, heart rate samples
- [ ] Extract GPS from workout routes

### Phase 3: Import Wizard UI
- [ ] `WearableImportPage` with 3-step wizard
- [ ] Dive selection list with date range filter
- [ ] `DiveMatcher` for duplicate detection
- [ ] `MergeConflictDialog` for user decisions
- [ ] Import summary screen

### Phase 4: Merge & Storage
- [ ] Merge logic for combining wearable + dive computer data
- [ ] Store watch profile as secondary source
- [ ] HR profile integration with existing chart
- [ ] GPS to dive site association

### Phase 5: Polish & Edge Cases
- [ ] Platform graceful degradation (Android/Windows/Linux)
- [ ] Empty state when no watch dives found
- [ ] Error handling (permission denied, no data)
- [ ] Settings page entry point for wearables

---

## Testing Strategy

### Unit Tests
- `DiveMatcher` scoring algorithm
- Profile sample parsing
- Merge logic correctness

### Widget Tests
- Import wizard navigation flow
- Duplicate conflict dialog interactions
- Platform availability checks

### Integration Tests
- Full import flow with mock HealthKit data
- Database migration verification
- Merge operations

### Manual Testing
- Real Apple Watch Ultra on iOS device
- Permission flow verification
- Edge cases (no dives, many dives, partial data)

### Test Structure

```
test/features/wearables/
├── domain/
│   ├── dive_matcher_test.dart
│   └── wearable_dive_test.dart
├── data/
│   └── healthkit_service_test.dart
└── presentation/
    ├── wearable_import_page_test.dart
    └── merge_conflict_dialog_test.dart
```

---

## Future Considerations

### Garmin Connect Integration
- OAuth 2.0 authentication flow
- Garmin Wellness API for dive activities
- Similar import wizard with Garmin-specific data mapping

### Suunto Integration
- Suunto app API or UDDF export parsing
- Movescount legacy data support

### Automatic Background Sync
- iOS background app refresh for periodic HealthKit checks
- Notification when new watch dives detected
- Settings toggle to enable/disable auto-sync

---

## Dependencies

### New Package
```yaml
health: ^10.2.0  # Cross-platform health data access
```

### Existing Packages Used
- `flutter_riverpod` - State management
- `drift` - Database migrations
- `go_router` - Navigation to import wizard

---

## Success Criteria

1. Users can import Apple Watch Ultra dives on iOS/macOS
2. Depth profiles display correctly in existing chart
3. Heart rate overlay works with imported HR data
4. GPS coordinates populate dive site or suggest new site
5. Duplicate detection prevents accidental reimport
6. Merge correctly combines watch + dive computer data
7. Non-Apple platforms show graceful "not available" message
8. 80%+ test coverage on new code
