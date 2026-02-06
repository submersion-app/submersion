# Wearable Integration Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Import dive data from Apple Watch Ultra via HealthKit, including depth profiles, temperature, heart rate, and GPS coordinates.

**Architecture:** A new `features/wearables/` feature module following existing patterns. Abstract `WearableImportService` interface with `HealthKitService` implementation for Apple platforms. Reuses existing `DiveComputerRepository` for profile storage and `DiveMatcher` for duplicate detection.

**Tech Stack:** Flutter, health package (^10.2.0), Riverpod, Drift ORM, go_router

---

## Phase 1: Core Infrastructure

### Task 1.1: Add health package dependency

**Files:**
- Modify: `pubspec.yaml`

**Step 1: Add the health package**

In `pubspec.yaml`, add under `dependencies:` (after the `# Platform Integration` comment block):

```yaml
  health: ^10.2.0  # Cross-platform health data (HealthKit, Health Connect)
```

**Step 2: Run flutter pub get**

```bash
flutter pub get
```

Expected: Resolving dependencies... Got dependencies!

**Step 3: Commit**

```bash
git add pubspec.yaml pubspec.lock
git commit -m "feat(wearables): add health package for HealthKit integration"
```

---

### Task 1.2: Create WearableDive entity

**Files:**
- Create: `lib/features/wearables/domain/entities/wearable_dive.dart`
- Test: `test/features/wearables/domain/entities/wearable_dive_test.dart`

**Step 1: Create the directory structure**

```bash
mkdir -p lib/features/wearables/domain/entities
mkdir -p test/features/wearables/domain/entities
```

**Step 2: Write the failing test**

Create `test/features/wearables/domain/entities/wearable_dive_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/wearables/domain/entities/wearable_dive.dart';

void main() {
  group('WearableDive', () {
    test('creates instance with required fields', () {
      final dive = WearableDive(
        sourceId: 'healthkit-uuid-123',
        source: WearableSource.appleWatch,
        startTime: DateTime(2026, 1, 15, 10, 0),
        endTime: DateTime(2026, 1, 15, 10, 45),
        maxDepth: 18.5,
        profile: [],
      );

      expect(dive.sourceId, 'healthkit-uuid-123');
      expect(dive.source, WearableSource.appleWatch);
      expect(dive.maxDepth, 18.5);
    });

    test('calculates duration correctly', () {
      final dive = WearableDive(
        sourceId: 'test',
        source: WearableSource.appleWatch,
        startTime: DateTime(2026, 1, 15, 10, 0),
        endTime: DateTime(2026, 1, 15, 10, 45),
        maxDepth: 18.5,
        profile: [],
      );

      expect(dive.duration, const Duration(minutes: 45));
    });

    test('WearableProfileSample creates with all fields', () {
      final sample = WearableProfileSample(
        timeSeconds: 120,
        depth: 15.5,
        temperature: 22.0,
        heartRate: 72,
      );

      expect(sample.timeSeconds, 120);
      expect(sample.depth, 15.5);
      expect(sample.temperature, 22.0);
      expect(sample.heartRate, 72);
    });
  });
}
```

**Step 3: Run test to verify it fails**

```bash
flutter test test/features/wearables/domain/entities/wearable_dive_test.dart
```

Expected: Error - Target of URI doesn't exist: 'package:submersion/features/wearables/domain/entities/wearable_dive.dart'

**Step 4: Write the implementation**

Create `lib/features/wearables/domain/entities/wearable_dive.dart`:

```dart
import 'package:equatable/equatable.dart';

/// Source of wearable dive data
enum WearableSource {
  appleWatch,
  garmin,
  suunto,
}

/// Extension for display names
extension WearableSourceExtension on WearableSource {
  String get displayName {
    switch (this) {
      case WearableSource.appleWatch:
        return 'Apple Watch';
      case WearableSource.garmin:
        return 'Garmin';
      case WearableSource.suunto:
        return 'Suunto';
    }
  }
}

/// A dive imported from a wearable device
class WearableDive extends Equatable {
  /// Unique identifier from the source (e.g., HealthKit UUID)
  final String sourceId;

  /// Source device type
  final WearableSource source;

  /// Dive start time
  final DateTime startTime;

  /// Dive end time
  final DateTime endTime;

  /// Maximum depth in meters
  final double maxDepth;

  /// Average depth in meters (calculated from samples if not provided)
  final double? avgDepth;

  /// Minimum water temperature in Celsius
  final double? minTemperature;

  /// Maximum water temperature in Celsius
  final double? maxTemperature;

  /// Average heart rate in BPM
  final double? avgHeartRate;

  /// GPS latitude at dive location (surface, pre/post dive)
  final double? latitude;

  /// GPS longitude at dive location
  final double? longitude;

  /// Time-series profile samples
  final List<WearableProfileSample> profile;

  const WearableDive({
    required this.sourceId,
    required this.source,
    required this.startTime,
    required this.endTime,
    required this.maxDepth,
    this.avgDepth,
    this.minTemperature,
    this.maxTemperature,
    this.avgHeartRate,
    this.latitude,
    this.longitude,
    required this.profile,
  });

  /// Calculated dive duration
  Duration get duration => endTime.difference(startTime);

  /// Duration in seconds (for compatibility with existing code)
  int get durationSeconds => duration.inSeconds;

  @override
  List<Object?> get props => [
        sourceId,
        source,
        startTime,
        endTime,
        maxDepth,
        avgDepth,
        minTemperature,
        maxTemperature,
        avgHeartRate,
        latitude,
        longitude,
        profile,
      ];
}

/// A single sample point in a wearable dive profile
class WearableProfileSample extends Equatable {
  /// Time in seconds from dive start
  final int timeSeconds;

  /// Depth in meters
  final double depth;

  /// Water temperature in Celsius (optional, not all samples have temp)
  final double? temperature;

  /// Heart rate in BPM (optional)
  final int? heartRate;

  const WearableProfileSample({
    required this.timeSeconds,
    required this.depth,
    this.temperature,
    this.heartRate,
  });

  @override
  List<Object?> get props => [timeSeconds, depth, temperature, heartRate];
}
```

**Step 5: Run test to verify it passes**

```bash
flutter test test/features/wearables/domain/entities/wearable_dive_test.dart
```

Expected: All tests passed!

**Step 6: Commit**

```bash
git add lib/features/wearables/domain/entities/wearable_dive.dart \
        test/features/wearables/domain/entities/wearable_dive_test.dart
git commit -m "feat(wearables): add WearableDive and WearableProfileSample entities"
```

---

### Task 1.3: Create WearableImportService interface

**Files:**
- Create: `lib/features/wearables/domain/services/wearable_import_service.dart`

**Step 1: Create directory**

```bash
mkdir -p lib/features/wearables/domain/services
```

**Step 2: Write the interface**

Create `lib/features/wearables/domain/services/wearable_import_service.dart`:

```dart
import 'package:submersion/features/wearables/domain/entities/wearable_dive.dart';

/// Abstract interface for importing dives from wearable devices.
///
/// Implementations handle platform-specific APIs:
/// - [HealthKitService] for Apple Watch (iOS/macOS)
/// - Future: GarminService, SuuntoService
abstract class WearableImportService {
  /// Check if this wearable service is available on the current platform.
  ///
  /// Returns true if the underlying health API is accessible.
  Future<bool> isAvailable();

  /// Request necessary permissions to read dive data.
  ///
  /// Returns true if all required permissions were granted.
  Future<bool> requestPermissions();

  /// Check if permissions have already been granted.
  ///
  /// Returns true if we can read dive data without prompting.
  Future<bool> hasPermissions();

  /// Fetch dives within the specified date range.
  ///
  /// [startDate] - Beginning of the date range (inclusive)
  /// [endDate] - End of the date range (inclusive)
  ///
  /// Returns a list of [WearableDive] objects with summary data.
  /// Call [fetchDiveProfile] to get detailed profile samples.
  Future<List<WearableDive>> fetchDives({
    required DateTime startDate,
    required DateTime endDate,
  });

  /// Fetch the detailed profile samples for a specific dive.
  ///
  /// [sourceId] - The unique identifier from [WearableDive.sourceId]
  ///
  /// Returns detailed profile samples including depth, temperature, HR.
  Future<List<WearableProfileSample>> fetchDiveProfile(String sourceId);

  /// Get the wearable source type for this service.
  WearableSource get source;
}
```

**Step 3: Commit**

```bash
git add lib/features/wearables/domain/services/wearable_import_service.dart
git commit -m "feat(wearables): add WearableImportService abstract interface"
```

---

### Task 1.4: Create DiveMatcher for duplicate detection

**Files:**
- Create: `lib/features/wearables/domain/services/dive_matcher.dart`
- Test: `test/features/wearables/domain/services/dive_matcher_test.dart`

**Step 1: Write the failing test**

Create `test/features/wearables/domain/services/dive_matcher_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/wearables/domain/entities/wearable_dive.dart';
import 'package:submersion/features/wearables/domain/services/dive_matcher.dart';

void main() {
  group('DiveMatcher', () {
    late DiveMatcher matcher;

    setUp(() {
      matcher = DiveMatcher();
    });

    group('calculateMatchScore', () {
      test('returns high score for identical time, depth, duration', () {
        final wearable = WearableDive(
          sourceId: 'test',
          source: WearableSource.appleWatch,
          startTime: DateTime(2026, 1, 15, 10, 0),
          endTime: DateTime(2026, 1, 15, 10, 45),
          maxDepth: 18.5,
          profile: [],
        );

        final score = matcher.calculateMatchScore(
          wearableStartTime: wearable.startTime,
          wearableMaxDepth: wearable.maxDepth,
          wearableDurationSeconds: wearable.durationSeconds,
          existingStartTime: DateTime(2026, 1, 15, 10, 0),
          existingMaxDepth: 18.5,
          existingDurationSeconds: 45 * 60,
        );

        expect(score, greaterThan(0.9));
      });

      test('returns lower score for 5 min time difference', () {
        final score = matcher.calculateMatchScore(
          wearableStartTime: DateTime(2026, 1, 15, 10, 0),
          wearableMaxDepth: 18.5,
          wearableDurationSeconds: 45 * 60,
          existingStartTime: DateTime(2026, 1, 15, 10, 5),
          existingMaxDepth: 18.5,
          existingDurationSeconds: 45 * 60,
        );

        expect(score, greaterThan(0.7));
        expect(score, lessThan(0.95));
      });

      test('returns low score for 20 min time difference', () {
        final score = matcher.calculateMatchScore(
          wearableStartTime: DateTime(2026, 1, 15, 10, 0),
          wearableMaxDepth: 18.5,
          wearableDurationSeconds: 45 * 60,
          existingStartTime: DateTime(2026, 1, 15, 10, 20),
          existingMaxDepth: 18.5,
          existingDurationSeconds: 45 * 60,
        );

        expect(score, lessThan(0.5));
      });

      test('reduces score for depth difference > 10%', () {
        final perfectScore = matcher.calculateMatchScore(
          wearableStartTime: DateTime(2026, 1, 15, 10, 0),
          wearableMaxDepth: 20.0,
          wearableDurationSeconds: 45 * 60,
          existingStartTime: DateTime(2026, 1, 15, 10, 0),
          existingMaxDepth: 20.0,
          existingDurationSeconds: 45 * 60,
        );

        final depthDiffScore = matcher.calculateMatchScore(
          wearableStartTime: DateTime(2026, 1, 15, 10, 0),
          wearableMaxDepth: 20.0,
          wearableDurationSeconds: 45 * 60,
          existingStartTime: DateTime(2026, 1, 15, 10, 0),
          existingMaxDepth: 25.0, // 25% different
          existingDurationSeconds: 45 * 60,
        );

        expect(depthDiffScore, lessThan(perfectScore));
      });
    });

    group('isProbableDuplicate', () {
      test('returns true for score >= 0.7', () {
        expect(matcher.isProbableDuplicate(0.7), isTrue);
        expect(matcher.isProbableDuplicate(0.9), isTrue);
      });

      test('returns false for score < 0.7', () {
        expect(matcher.isProbableDuplicate(0.69), isFalse);
        expect(matcher.isProbableDuplicate(0.5), isFalse);
      });
    });

    group('isPossibleDuplicate', () {
      test('returns true for score >= 0.5', () {
        expect(matcher.isPossibleDuplicate(0.5), isTrue);
        expect(matcher.isPossibleDuplicate(0.7), isTrue);
      });

      test('returns false for score < 0.5', () {
        expect(matcher.isPossibleDuplicate(0.49), isFalse);
      });
    });
  });
}
```

**Step 2: Run test to verify it fails**

```bash
flutter test test/features/wearables/domain/services/dive_matcher_test.dart
```

Expected: Error - Target of URI doesn't exist

**Step 3: Write the implementation**

Create `lib/features/wearables/domain/services/dive_matcher.dart`:

```dart
/// Service for matching wearable dives to existing dive log entries.
///
/// Uses fuzzy matching based on time, depth, and duration to detect
/// potential duplicates when importing from wearable devices.
class DiveMatcher {
  /// Calculate a match score between a wearable dive and an existing dive.
  ///
  /// Returns a score from 0.0 (no match) to 1.0 (perfect match).
  ///
  /// Scoring weights:
  /// - Time proximity: 50% (most important)
  /// - Depth similarity: 30%
  /// - Duration similarity: 20%
  double calculateMatchScore({
    required DateTime wearableStartTime,
    required double wearableMaxDepth,
    required int wearableDurationSeconds,
    required DateTime existingStartTime,
    required double existingMaxDepth,
    required int existingDurationSeconds,
  }) {
    // Time score: within 5 min = 100%, 15 min = 0%
    final timeDiff = wearableStartTime.difference(existingStartTime).abs();
    final timeMinutes = timeDiff.inMinutes;
    final timeScore = timeMinutes <= 5
        ? 1.0
        : timeMinutes >= 15
            ? 0.0
            : 1.0 - ((timeMinutes - 5) / 10);

    // Depth score: within 10% = 100%, 20% = 0%
    final depthDiff = (wearableMaxDepth - existingMaxDepth).abs();
    final depthPercent =
        existingMaxDepth > 0 ? depthDiff / existingMaxDepth : 1.0;
    final depthScore = depthPercent <= 0.10
        ? 1.0
        : depthPercent >= 0.20
            ? 0.0
            : 1.0 - ((depthPercent - 0.10) / 0.10);

    // Duration score: within 3 min = 100%, 10 min = 0%
    final durationDiff =
        (wearableDurationSeconds - existingDurationSeconds).abs();
    final durationDiffMinutes = durationDiff / 60;
    final durationScore = durationDiffMinutes <= 3
        ? 1.0
        : durationDiffMinutes >= 10
            ? 0.0
            : 1.0 - ((durationDiffMinutes - 3) / 7);

    // Weighted composite score
    return (timeScore * 0.50) + (depthScore * 0.30) + (durationScore * 0.20);
  }

  /// Check if the score indicates a probable duplicate (high confidence).
  bool isProbableDuplicate(double score) => score >= 0.7;

  /// Check if the score indicates a possible duplicate (medium confidence).
  bool isPossibleDuplicate(double score) => score >= 0.5;
}

/// Result of matching a wearable dive against existing dives.
class DiveMatchResult {
  /// ID of the matching dive in the database
  final String diveId;

  /// Match confidence score (0.0 to 1.0)
  final double score;

  /// Time difference in milliseconds
  final int timeDifferenceMs;

  /// Depth difference in meters (null if not available)
  final double? depthDifferenceMeters;

  /// Duration difference in seconds (null if not available)
  final int? durationDifferenceSeconds;

  const DiveMatchResult({
    required this.diveId,
    required this.score,
    required this.timeDifferenceMs,
    this.depthDifferenceMeters,
    this.durationDifferenceSeconds,
  });

  /// Whether this is a high-confidence match
  bool get isProbable => score >= 0.7;

  /// Whether this is a possible match worth showing to user
  bool get isPossible => score >= 0.5;
}
```

**Step 4: Run test to verify it passes**

```bash
flutter test test/features/wearables/domain/services/dive_matcher_test.dart
```

Expected: All tests passed!

**Step 5: Commit**

```bash
git add lib/features/wearables/domain/services/dive_matcher.dart \
        test/features/wearables/domain/services/dive_matcher_test.dart
git commit -m "feat(wearables): add DiveMatcher for duplicate detection"
```

---

### Task 1.5: Add database columns for wearable tracking

**Files:**
- Modify: `lib/core/database/database.dart`

**Step 1: Add wearable columns to Dives table**

In `lib/core/database/database.dart`, find the `Dives` table class and add these columns after the `courseId` column (around line 168):

```dart
  // Wearable integration (v2.0)
  TextColumn get wearableSource =>
      text().nullable()(); // 'apple_watch', 'garmin', 'suunto'
  TextColumn get wearableId =>
      text().nullable()(); // Source UUID for deduplication
```

**Step 2: Add heart rate source to DiveProfiles table**

In the `DiveProfiles` table, add after the `ppO2` column (around line 200):

```dart
  // Wearable heart rate source tracking (v2.0)
  TextColumn get heartRateSource =>
      text().nullable()(); // 'dive_computer', 'wearable'
```

**Step 3: Update schema version**

Find `schemaVersion` in the database class and increment it by 1.

**Step 4: Add migration**

Find the `migration` getter and add a new migration step for the new schema version:

```dart
// In the MigrationStrategy onUpgrade callback, add:
if (from < NEW_VERSION) {
  await m.addColumn(dives, dives.wearableSource);
  await m.addColumn(dives, dives.wearableId);
  await m.addColumn(diveProfiles, diveProfiles.heartRateSource);
}
```

**Step 5: Run code generation**

```bash
dart run build_runner build --delete-conflicting-outputs
```

**Step 6: Run tests to verify nothing broke**

```bash
flutter test
```

Expected: All tests pass

**Step 7: Commit**

```bash
git add lib/core/database/database.dart lib/core/database/database.g.dart
git commit -m "feat(wearables): add database columns for wearable tracking"
```

---

## Phase 2: HealthKit Integration

### Task 2.1: Configure iOS/macOS HealthKit entitlements

**Files:**
- Modify: `ios/Runner/Info.plist`
- Modify: `macos/Runner/Info.plist`
- Modify: `ios/Runner/Runner.entitlements` (create if needed)
- Modify: `macos/Runner/Release.entitlements`
- Modify: `macos/Runner/DebugProfile.entitlements`

**Step 1: Add iOS Info.plist entries**

In `ios/Runner/Info.plist`, add before the closing `</dict>`:

```xml
	<key>NSHealthShareUsageDescription</key>
	<string>Submersion imports your Apple Watch dive data including depth, temperature, and heart rate to create detailed dive logs.</string>
	<key>NSHealthUpdateUsageDescription</key>
	<string>Submersion can record dive activities to your Health app.</string>
```

**Step 2: Add iOS entitlements**

Create or modify `ios/Runner/Runner.entitlements`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>com.apple.developer.healthkit</key>
	<true/>
	<key>com.apple.developer.healthkit.access</key>
	<array/>
</dict>
</plist>
```

**Step 3: Add macOS Info.plist entries**

In `macos/Runner/Info.plist`, add before the closing `</dict>`:

```xml
	<key>NSHealthShareUsageDescription</key>
	<string>Submersion imports your Apple Watch dive data including depth, temperature, and heart rate to create detailed dive logs.</string>
	<key>NSHealthUpdateUsageDescription</key>
	<string>Submersion can record dive activities to your Health app.</string>
```

**Step 4: Add macOS entitlements**

In both `macos/Runner/Release.entitlements` and `macos/Runner/DebugProfile.entitlements`, add:

```xml
	<key>com.apple.developer.healthkit</key>
	<true/>
	<key>com.apple.developer.healthkit.access</key>
	<array/>
```

**Step 5: Commit**

```bash
git add ios/Runner/Info.plist ios/Runner/Runner.entitlements \
        macos/Runner/Info.plist macos/Runner/Release.entitlements \
        macos/Runner/DebugProfile.entitlements
git commit -m "feat(wearables): add HealthKit entitlements for iOS/macOS"
```

---

### Task 2.2: Implement HealthKitService

**Files:**
- Create: `lib/features/wearables/data/services/healthkit_service.dart`
- Test: `test/features/wearables/data/services/healthkit_service_test.dart`

**Step 1: Create directory**

```bash
mkdir -p lib/features/wearables/data/services
mkdir -p test/features/wearables/data/services
```

**Step 2: Write the test (mocked)**

Create `test/features/wearables/data/services/healthkit_service_test.dart`:

```dart
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/wearables/data/services/healthkit_service.dart';
import 'package:submersion/features/wearables/domain/entities/wearable_dive.dart';

void main() {
  group('HealthKitService', () {
    late HealthKitService service;

    setUp(() {
      service = HealthKitService();
    });

    test('source returns appleWatch', () {
      expect(service.source, WearableSource.appleWatch);
    });

    test('isAvailable returns true only on Apple platforms', () async {
      final available = await service.isAvailable();

      // In test environment, Platform checks work
      if (Platform.isIOS || Platform.isMacOS) {
        expect(available, isTrue);
      } else {
        expect(available, isFalse);
      }
    });
  });
}
```

**Step 3: Run test to verify it fails**

```bash
flutter test test/features/wearables/data/services/healthkit_service_test.dart
```

**Step 4: Write the implementation**

Create `lib/features/wearables/data/services/healthkit_service.dart`:

```dart
import 'dart:io';

import 'package:health/health.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/wearables/domain/entities/wearable_dive.dart';
import 'package:submersion/features/wearables/domain/services/wearable_import_service.dart';

/// HealthKit implementation of [WearableImportService] for Apple Watch.
///
/// Reads underwater diving workouts from HealthKit on iOS and macOS.
/// Requires iOS 16+ or macOS 13+ for underwater depth data.
class HealthKitService implements WearableImportService {
  final _log = LoggerService.forClass(HealthKitService);
  final Health _health = Health();

  // HealthKit data types we need to read
  static const _requiredTypes = [
    HealthDataType.WORKOUT,
  ];

  // Data types for dive details (may not be available on all devices)
  static const _diveDataTypes = [
    HealthDataType.HEART_RATE,
    HealthDataType.WATER_TEMPERATURE,
  ];

  @override
  WearableSource get source => WearableSource.appleWatch;

  @override
  Future<bool> isAvailable() async {
    // Only available on Apple platforms
    if (!Platform.isIOS && !Platform.isMacOS) {
      return false;
    }

    try {
      // Check if Health app is available
      return await _health.isHealthConnectAvailable();
    } catch (e) {
      _log.error('Failed to check HealthKit availability', e);
      return false;
    }
  }

  @override
  Future<bool> hasPermissions() async {
    if (!await isAvailable()) return false;

    try {
      final permissions = await _health.hasPermissions(
        _requiredTypes,
        permissions: [HealthDataAccess.READ],
      );
      return permissions ?? false;
    } catch (e) {
      _log.error('Failed to check HealthKit permissions', e);
      return false;
    }
  }

  @override
  Future<bool> requestPermissions() async {
    if (!await isAvailable()) return false;

    try {
      // Request workout read permission
      final granted = await _health.requestAuthorization(
        [..._requiredTypes, ..._diveDataTypes],
        permissions: [
          HealthDataAccess.READ,
          HealthDataAccess.READ,
          HealthDataAccess.READ,
        ],
      );

      _log.info('HealthKit permissions granted: $granted');
      return granted;
    } catch (e) {
      _log.error('Failed to request HealthKit permissions', e);
      return false;
    }
  }

  @override
  Future<List<WearableDive>> fetchDives({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    if (!await hasPermissions()) {
      _log.warning('Cannot fetch dives: permissions not granted');
      return [];
    }

    try {
      _log.info('Fetching dives from $startDate to $endDate');

      // Fetch all workouts in date range
      final workouts = await _health.getHealthDataFromTypes(
        types: [HealthDataType.WORKOUT],
        startTime: startDate,
        endTime: endDate,
      );

      // Filter to only underwater diving workouts
      final divingWorkouts = workouts
          .whereType<HealthDataPoint>()
          .where((w) => _isUnderwaterDiving(w))
          .toList();

      _log.info('Found ${divingWorkouts.length} diving workouts');

      // Convert to WearableDive
      final dives = <WearableDive>[];
      for (final workout in divingWorkouts) {
        final dive = await _workoutToWearableDive(workout);
        if (dive != null) {
          dives.add(dive);
        }
      }

      return dives;
    } catch (e, stackTrace) {
      _log.error('Failed to fetch dives from HealthKit', e, stackTrace);
      return [];
    }
  }

  @override
  Future<List<WearableProfileSample>> fetchDiveProfile(String sourceId) async {
    // TODO: Implement detailed profile fetching
    // This requires querying UNDERWATER_DEPTH samples within the workout timeframe
    _log.warning('fetchDiveProfile not yet implemented');
    return [];
  }

  /// Check if a workout is an underwater diving activity
  bool _isUnderwaterDiving(HealthDataPoint workout) {
    // The health package uses workout type names
    // Check if it's a diving workout
    final value = workout.value;
    if (value is WorkoutHealthValue) {
      // WorkoutHealthValue has workoutActivityType
      final activityType = value.workoutActivityType;
      return activityType == HealthWorkoutActivityType.UNDERWATER_DIVING;
    }
    return false;
  }

  /// Convert a HealthKit workout to a WearableDive
  Future<WearableDive?> _workoutToWearableDive(HealthDataPoint workout) async {
    try {
      final value = workout.value;
      if (value is! WorkoutHealthValue) return null;

      // Extract basic info
      final sourceId = workout.uuid;
      final startTime = workout.dateFrom;
      final endTime = workout.dateTo;

      // Fetch depth data for this time range
      double maxDepth = 0;
      double? avgDepth;
      final profile = <WearableProfileSample>[];

      // Try to get depth samples
      // Note: UNDERWATER_DEPTH may not be available in all health package versions
      // This is a placeholder for the actual implementation
      try {
        // Depth samples would be fetched here
        // For now, we'll use workout metadata if available
        maxDepth = value.totalDistance ?? 0; // Placeholder
      } catch (e) {
        _log.warning('Could not fetch depth data: $e');
      }

      // Fetch heart rate data
      double? avgHeartRate;
      try {
        final hrData = await _health.getHealthDataFromTypes(
          types: [HealthDataType.HEART_RATE],
          startTime: startTime,
          endTime: endTime,
        );

        if (hrData.isNotEmpty) {
          final hrValues = hrData
              .map((d) => d.value)
              .whereType<NumericHealthValue>()
              .map((v) => v.numericValue.toDouble())
              .toList();

          if (hrValues.isNotEmpty) {
            avgHeartRate =
                hrValues.reduce((a, b) => a + b) / hrValues.length;
          }
        }
      } catch (e) {
        _log.warning('Could not fetch heart rate data: $e');
      }

      // Fetch water temperature
      double? minTemp, maxTemp;
      try {
        final tempData = await _health.getHealthDataFromTypes(
          types: [HealthDataType.WATER_TEMPERATURE],
          startTime: startTime,
          endTime: endTime,
        );

        if (tempData.isNotEmpty) {
          final temps = tempData
              .map((d) => d.value)
              .whereType<NumericHealthValue>()
              .map((v) => v.numericValue.toDouble())
              .toList();

          if (temps.isNotEmpty) {
            minTemp = temps.reduce((a, b) => a < b ? a : b);
            maxTemp = temps.reduce((a, b) => a > b ? a : b);
          }
        }
      } catch (e) {
        _log.warning('Could not fetch temperature data: $e');
      }

      // GPS coordinates from workout route
      double? latitude, longitude;
      // Note: Workout routes require additional HealthKit queries
      // This would be implemented with HKWorkoutRouteQuery

      return WearableDive(
        sourceId: sourceId,
        source: WearableSource.appleWatch,
        startTime: startTime,
        endTime: endTime,
        maxDepth: maxDepth,
        avgDepth: avgDepth,
        minTemperature: minTemp,
        maxTemperature: maxTemp,
        avgHeartRate: avgHeartRate,
        latitude: latitude,
        longitude: longitude,
        profile: profile,
      );
    } catch (e, stackTrace) {
      _log.error('Failed to convert workout to WearableDive', e, stackTrace);
      return null;
    }
  }
}
```

**Step 5: Run test to verify it passes**

```bash
flutter test test/features/wearables/data/services/healthkit_service_test.dart
```

**Step 6: Commit**

```bash
git add lib/features/wearables/data/services/healthkit_service.dart \
        test/features/wearables/data/services/healthkit_service_test.dart
git commit -m "feat(wearables): implement HealthKitService for Apple Watch"
```

---

## Phase 3: Import Wizard UI

### Task 3.1: Create Riverpod providers for wearables

**Files:**
- Create: `lib/features/wearables/presentation/providers/wearable_providers.dart`

**Step 1: Create directory**

```bash
mkdir -p lib/features/wearables/presentation/providers
```

**Step 2: Write the providers**

Create `lib/features/wearables/presentation/providers/wearable_providers.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:submersion/features/wearables/data/services/healthkit_service.dart';
import 'package:submersion/features/wearables/domain/entities/wearable_dive.dart';
import 'package:submersion/features/wearables/domain/services/dive_matcher.dart';
import 'package:submersion/features/wearables/domain/services/wearable_import_service.dart';

/// Provider for the HealthKit service (Apple platforms)
final healthKitServiceProvider = Provider<WearableImportService>((ref) {
  return HealthKitService();
});

/// Provider for the dive matcher
final diveMatcherProvider = Provider<DiveMatcher>((ref) {
  return DiveMatcher();
});

/// Provider for checking if wearable import is available
final wearableAvailableProvider = FutureProvider<bool>((ref) async {
  final service = ref.watch(healthKitServiceProvider);
  return await service.isAvailable();
});

/// Provider for checking if permissions are granted
final wearablePermissionsProvider = FutureProvider<bool>((ref) async {
  final service = ref.watch(healthKitServiceProvider);
  return await service.hasPermissions();
});

/// State for the wearable import wizard
class WearableImportState {
  final List<WearableDive> availableDives;
  final Set<String> selectedDiveIds;
  final Map<String, DiveMatchResult?> matchResults;
  final bool isLoading;
  final String? error;
  final int currentStep; // 0: Select, 1: Handle Duplicates, 2: Summary

  const WearableImportState({
    this.availableDives = const [],
    this.selectedDiveIds = const {},
    this.matchResults = const {},
    this.isLoading = false,
    this.error,
    this.currentStep = 0,
  });

  WearableImportState copyWith({
    List<WearableDive>? availableDives,
    Set<String>? selectedDiveIds,
    Map<String, DiveMatchResult?>? matchResults,
    bool? isLoading,
    String? error,
    int? currentStep,
  }) {
    return WearableImportState(
      availableDives: availableDives ?? this.availableDives,
      selectedDiveIds: selectedDiveIds ?? this.selectedDiveIds,
      matchResults: matchResults ?? this.matchResults,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      currentStep: currentStep ?? this.currentStep,
    );
  }
}

/// Notifier for managing wearable import state
class WearableImportNotifier extends StateNotifier<WearableImportState> {
  final WearableImportService _service;
  final DiveMatcher _matcher;

  WearableImportNotifier(this._service, this._matcher)
      : super(const WearableImportState());

  /// Request permissions from the user
  Future<bool> requestPermissions() async {
    return await _service.requestPermissions();
  }

  /// Fetch available dives from the wearable
  Future<void> fetchDives({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final dives = await _service.fetchDives(
        startDate: startDate,
        endDate: endDate,
      );

      // Select all by default
      final selectedIds = dives.map((d) => d.sourceId).toSet();

      state = state.copyWith(
        availableDives: dives,
        selectedDiveIds: selectedIds,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to fetch dives: $e',
      );
    }
  }

  /// Toggle selection of a dive
  void toggleDiveSelection(String sourceId) {
    final newSelection = Set<String>.from(state.selectedDiveIds);
    if (newSelection.contains(sourceId)) {
      newSelection.remove(sourceId);
    } else {
      newSelection.add(sourceId);
    }
    state = state.copyWith(selectedDiveIds: newSelection);
  }

  /// Select all dives
  void selectAll() {
    final allIds = state.availableDives.map((d) => d.sourceId).toSet();
    state = state.copyWith(selectedDiveIds: allIds);
  }

  /// Deselect all dives
  void deselectAll() {
    state = state.copyWith(selectedDiveIds: {});
  }

  /// Move to next step
  void nextStep() {
    if (state.currentStep < 2) {
      state = state.copyWith(currentStep: state.currentStep + 1);
    }
  }

  /// Move to previous step
  void previousStep() {
    if (state.currentStep > 0) {
      state = state.copyWith(currentStep: state.currentStep - 1);
    }
  }

  /// Reset the wizard
  void reset() {
    state = const WearableImportState();
  }
}

/// Provider for the import wizard state
final wearableImportProvider =
    StateNotifierProvider<WearableImportNotifier, WearableImportState>((ref) {
  final service = ref.watch(healthKitServiceProvider);
  final matcher = ref.watch(diveMatcherProvider);
  return WearableImportNotifier(service, matcher);
});
```

**Step 3: Commit**

```bash
git add lib/features/wearables/presentation/providers/wearable_providers.dart
git commit -m "feat(wearables): add Riverpod providers for import wizard"
```

---

### Task 3.2: Create WearableImportPage

**Files:**
- Create: `lib/features/wearables/presentation/pages/wearable_import_page.dart`
- Create: `lib/features/wearables/presentation/widgets/wearable_dive_card.dart`

**Step 1: Create directories**

```bash
mkdir -p lib/features/wearables/presentation/pages
mkdir -p lib/features/wearables/presentation/widgets
```

**Step 2: Create the dive card widget**

Create `lib/features/wearables/presentation/widgets/wearable_dive_card.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:submersion/features/wearables/domain/entities/wearable_dive.dart';

/// Card widget for displaying a wearable dive in the import list.
class WearableDiveCard extends StatelessWidget {
  final WearableDive dive;
  final bool isSelected;
  final bool isAlreadyImported;
  final bool isPossibleDuplicate;
  final VoidCallback? onTap;

  const WearableDiveCard({
    super.key,
    required this.dive,
    required this.isSelected,
    this.isAlreadyImported = false,
    this.isPossibleDuplicate = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat.yMMMd();
    final timeFormat = DateFormat.Hm();

    return Card(
      elevation: isSelected ? 2 : 0,
      color: isAlreadyImported
          ? theme.colorScheme.surfaceContainerHighest.withOpacity(0.5)
          : null,
      child: InkWell(
        onTap: isAlreadyImported ? null : onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Selection checkbox
              if (!isAlreadyImported)
                Checkbox(
                  value: isSelected,
                  onChanged: onTap != null ? (_) => onTap!() : null,
                )
              else
                const Icon(
                  Icons.check_circle,
                  color: Colors.grey,
                ),

              const SizedBox(width: 12),

              // Dive info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Date and time
                    Text(
                      '${dateFormat.format(dive.startTime)} at ${timeFormat.format(dive.startTime)}',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: isAlreadyImported ? Colors.grey : null,
                      ),
                    ),

                    const SizedBox(height: 4),

                    // Depth and duration
                    Row(
                      children: [
                        Icon(
                          Icons.arrow_downward,
                          size: 16,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${dive.maxDepth.toStringAsFixed(1)}m',
                          style: theme.textTheme.bodyMedium,
                        ),
                        const SizedBox(width: 16),
                        Icon(
                          Icons.timer_outlined,
                          size: 16,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${dive.duration.inMinutes}min',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    ),

                    // Temperature if available
                    if (dive.maxTemperature != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.thermostat_outlined,
                            size: 16,
                            color: theme.colorScheme.secondary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${dive.maxTemperature!.toStringAsFixed(0)}C',
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ],

                    // Status badges
                    if (isAlreadyImported || isPossibleDuplicate) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: [
                          if (isAlreadyImported)
                            Chip(
                              label: const Text('Already imported'),
                              labelStyle: theme.textTheme.labelSmall,
                              padding: EdgeInsets.zero,
                              visualDensity: VisualDensity.compact,
                            ),
                          if (isPossibleDuplicate && !isAlreadyImported)
                            Chip(
                              label: const Text('Possible duplicate'),
                              labelStyle: theme.textTheme.labelSmall,
                              backgroundColor:
                                  theme.colorScheme.tertiaryContainer,
                              padding: EdgeInsets.zero,
                              visualDensity: VisualDensity.compact,
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              // Source icon
              Icon(
                Icons.watch,
                color: theme.colorScheme.outline,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

**Step 3: Create the import page**

Create `lib/features/wearables/presentation/pages/wearable_import_page.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/features/wearables/presentation/providers/wearable_providers.dart';
import 'package:submersion/features/wearables/presentation/widgets/wearable_dive_card.dart';

/// Page for importing dives from wearable devices (Apple Watch).
class WearableImportPage extends ConsumerStatefulWidget {
  const WearableImportPage({super.key});

  @override
  ConsumerState<WearableImportPage> createState() => _WearableImportPageState();
}

class _WearableImportPageState extends ConsumerState<WearableImportPage> {
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _checkPermissionsAndFetch();
  }

  Future<void> _checkPermissionsAndFetch() async {
    final hasPermissions = await ref.read(wearablePermissionsProvider.future);
    if (!hasPermissions) {
      final granted =
          await ref.read(wearableImportProvider.notifier).requestPermissions();
      if (!granted && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Permission denied. Please enable Health access in Settings.'),
          ),
        );
        return;
      }
    }

    ref.read(wearableImportProvider.notifier).fetchDives(
          startDate: _startDate,
          endDate: _endDate,
        );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(wearableImportProvider);
    final isAvailable = ref.watch(wearableAvailableProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Import from Apple Watch'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
      ),
      body: isAvailable.when(
        data: (available) {
          if (!available) {
            return _buildUnavailable(context);
          }
          return _buildContent(context, state);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Widget _buildUnavailable(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.watch_off,
              size: 64,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              'Apple Watch Import Unavailable',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'This feature requires iOS or macOS with HealthKit support.',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, WearableImportState state) {
    if (state.isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Fetching dives from Health app...'),
          ],
        ),
      );
    }

    if (state.error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(state.error!),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _checkPermissionsAndFetch,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (state.availableDives.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.scuba_diving,
              size: 64,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 16),
            const Text('No diving workouts found'),
            const SizedBox(height: 8),
            Text(
              'No Apple Watch dives found in the last 30 days.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      );
    }

    // Step-based content
    return switch (state.currentStep) {
      0 => _buildSelectStep(context, state),
      1 => _buildDuplicatesStep(context, state),
      2 => _buildSummaryStep(context, state),
      _ => const SizedBox.shrink(),
    };
  }

  Widget _buildSelectStep(BuildContext context, WearableImportState state) {
    final notifier = ref.read(wearableImportProvider.notifier);

    return Column(
      children: [
        // Header with select all
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Text(
                '${state.availableDives.length} dives found',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const Spacer(),
              TextButton(
                onPressed: state.selectedDiveIds.length ==
                        state.availableDives.length
                    ? notifier.deselectAll
                    : notifier.selectAll,
                child: Text(
                  state.selectedDiveIds.length == state.availableDives.length
                      ? 'Deselect All'
                      : 'Select All',
                ),
              ),
            ],
          ),
        ),

        // Dive list
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: state.availableDives.length,
            itemBuilder: (context, index) {
              final dive = state.availableDives[index];
              return WearableDiveCard(
                dive: dive,
                isSelected: state.selectedDiveIds.contains(dive.sourceId),
                onTap: () => notifier.toggleDiveSelection(dive.sourceId),
              );
            },
          ),
        ),

        // Bottom actions
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => context.pop(),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: FilledButton(
                  onPressed: state.selectedDiveIds.isNotEmpty
                      ? () => notifier.nextStep()
                      : null,
                  child: Text('Next (${state.selectedDiveIds.length})'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDuplicatesStep(BuildContext context, WearableImportState state) {
    // TODO: Implement duplicate handling UI
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('Duplicate handling step - Coming soon'),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () =>
                ref.read(wearableImportProvider.notifier).nextStep(),
            child: const Text('Continue to Import'),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryStep(BuildContext context, WearableImportState state) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.check_circle, size: 64, color: Colors.green),
          const SizedBox(height: 16),
          Text(
            'Import Complete',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text('${state.selectedDiveIds.length} dives imported'),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () => context.pop(),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }
}
```

**Step 4: Commit**

```bash
git add lib/features/wearables/presentation/pages/wearable_import_page.dart \
        lib/features/wearables/presentation/widgets/wearable_dive_card.dart
git commit -m "feat(wearables): add WearableImportPage with selection wizard"
```

---

### Task 3.3: Add route to router

**Files:**
- Modify: `lib/core/router/router.dart`

**Step 1: Add the import**

At the top of `lib/core/router/router.dart`, add:

```dart
import 'package:submersion/features/wearables/presentation/pages/wearable_import_page.dart';
```

**Step 2: Add the route**

Find where other feature routes are defined and add:

```dart
GoRoute(
  path: '/wearables/import',
  name: 'wearable-import',
  builder: (context, state) => const WearableImportPage(),
),
```

**Step 3: Commit**

```bash
git add lib/core/router/router.dart
git commit -m "feat(wearables): add route for wearable import page"
```

---

### Task 3.4: Add entry point in Settings or Transfer page

**Files:**
- Modify: `lib/features/settings/presentation/pages/settings_page.dart` (or appropriate page)

**Step 1: Add navigation button**

Find an appropriate location in the settings or transfer page and add:

```dart
ListTile(
  leading: const Icon(Icons.watch),
  title: const Text('Import from Apple Watch'),
  subtitle: const Text('Import dives via HealthKit'),
  trailing: const Icon(Icons.chevron_right),
  onTap: () => context.push('/wearables/import'),
),
```

**Step 2: Commit**

```bash
git add lib/features/settings/presentation/pages/settings_page.dart
git commit -m "feat(wearables): add Apple Watch import entry in settings"
```

---

## Phase 4: Merge & Storage (Future Tasks)

The following tasks are outlined for Phase 4 implementation:

### Task 4.1: Implement WearableRepository for persisting imported dives
- Create repository with methods to:
  - Check if a wearable dive was already imported (by sourceId)
  - Save imported dives with wearable metadata
  - Merge wearable data (HR, GPS) into existing dives

### Task 4.2: Implement merge logic
- Add method to merge HR profile from wearable into existing dive
- Add method to add GPS coordinates to dive site
- Handle profile storage as secondary source

### Task 4.3: Complete duplicate handling UI
- Show side-by-side comparison dialog
- Implement merge/skip/import-as-new options
- Add "Apply to All" batch handling

### Task 4.4: Add import summary with undo
- Show detailed import results
- Provide undo option for recent imports
- Navigate to imported dives

---

## Testing Checklist

After completing all tasks, verify:

- [ ] `flutter test` passes (672+ tests)
- [ ] `flutter analyze` has no errors
- [ ] `dart format .` makes no changes
- [ ] App builds on macOS: `flutter build macos`
- [ ] App builds on iOS: `flutter build ios --no-codesign`
- [ ] Wearable import page shows "unavailable" on non-Apple platforms
- [ ] On macOS/iOS, permission dialog appears when accessing HealthKit

---

## Commit Summary

After completing all tasks, the following commits should exist:

1. `feat(wearables): add health package for HealthKit integration`
2. `feat(wearables): add WearableDive and WearableProfileSample entities`
3. `feat(wearables): add WearableImportService abstract interface`
4. `feat(wearables): add DiveMatcher for duplicate detection`
5. `feat(wearables): add database columns for wearable tracking`
6. `feat(wearables): add HealthKit entitlements for iOS/macOS`
7. `feat(wearables): implement HealthKitService for Apple Watch`
8. `feat(wearables): add Riverpod providers for import wizard`
9. `feat(wearables): add WearableImportPage with selection wizard`
10. `feat(wearables): add route for wearable import page`
11. `feat(wearables): add Apple Watch import entry in settings`
