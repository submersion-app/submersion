# Liveaboard Tracking Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add a trip type system with comprehensive liveaboard tracking (vessel details, itinerary, voyage map, enhanced stats) to the Submersion dive logging app.

**Architecture:** Extends the existing `trips` table with a `trip_type` column. Creates two new Drift tables (`liveaboard_details`, `trip_itinerary_days`) linked to trips via FK. New domain entities, repositories, and providers follow existing patterns. The trip detail page gains a tabbed layout for liveaboard trips.

**Tech Stack:** Flutter 3.x, Drift ORM, Riverpod, go_router, flutter_map, latlong2, Material 3

**Design Doc:** `docs/plans/2026-03-01-liveaboard-tracking-design.md`

---

## Phase 1: Enums and Domain Entities (no DB changes yet)

### Task 1: Add TripType and DayType enums

**Files:**

- Modify: `lib/core/constants/enums.dart` (append at end of file)
- Test: `test/core/constants/trip_enums_test.dart`

**Step 1: Write the failing test**

Create `test/core/constants/trip_enums_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';

void main() {
  group('TripType', () {
    test('has all expected values', () {
      expect(TripType.values, hasLength(4));
      expect(TripType.shore.name, 'shore');
      expect(TripType.liveaboard.name, 'liveaboard');
      expect(TripType.resort.name, 'resort');
      expect(TripType.dayTrip.name, 'dayTrip');
    });

    test('displayName returns human-readable names', () {
      expect(TripType.shore.displayName, 'Shore');
      expect(TripType.liveaboard.displayName, 'Liveaboard');
      expect(TripType.resort.displayName, 'Resort');
      expect(TripType.dayTrip.displayName, 'Day Trip');
    });

    test('fromName parses valid names', () {
      expect(TripType.fromName('shore'), TripType.shore);
      expect(TripType.fromName('liveaboard'), TripType.liveaboard);
      expect(TripType.fromName('resort'), TripType.resort);
      expect(TripType.fromName('dayTrip'), TripType.dayTrip);
    });

    test('fromName returns shore for unknown values', () {
      expect(TripType.fromName('unknown'), TripType.shore);
      expect(TripType.fromName(''), TripType.shore);
    });
  });

  group('DayType', () {
    test('has all expected values', () {
      expect(DayType.values, hasLength(5));
      expect(DayType.diveDay.name, 'diveDay');
      expect(DayType.seaDay.name, 'seaDay');
      expect(DayType.portDay.name, 'portDay');
      expect(DayType.embark.name, 'embark');
      expect(DayType.disembark.name, 'disembark');
    });

    test('displayName returns human-readable names', () {
      expect(DayType.diveDay.displayName, 'Dive Day');
      expect(DayType.seaDay.displayName, 'Sea Day');
      expect(DayType.portDay.displayName, 'Port Day');
      expect(DayType.embark.displayName, 'Embark');
      expect(DayType.disembark.displayName, 'Disembark');
    });

    test('fromName parses valid names', () {
      expect(DayType.fromName('diveDay'), DayType.diveDay);
      expect(DayType.fromName('seaDay'), DayType.seaDay);
      expect(DayType.fromName('embark'), DayType.embark);
    });

    test('fromName returns diveDay for unknown values', () {
      expect(DayType.fromName('unknown'), DayType.diveDay);
    });
  });
}
```text
**Step 2: Run test to verify it fails**

Run: `flutter test test/core/constants/trip_enums_test.dart`
Expected: FAIL - `TripType` and `DayType` not defined

**Step 3: Write minimal implementation**

Append to `lib/core/constants/enums.dart`:

```dart
/// Trip type classification
enum TripType {
  shore('Shore'),
  liveaboard('Liveaboard'),
  resort('Resort'),
  dayTrip('Day Trip');

  final String displayName;
  const TripType(this.displayName);

  static TripType fromName(String name) {
    return TripType.values.firstWhere(
      (e) => e.name == name,
      orElse: () => TripType.shore,
    );
  }
}

/// Itinerary day type for liveaboard trips
enum DayType {
  diveDay('Dive Day'),
  seaDay('Sea Day'),
  portDay('Port Day'),
  embark('Embark'),
  disembark('Disembark');

  final String displayName;
  const DayType(this.displayName);

  static DayType fromName(String name) {
    return DayType.values.firstWhere(
      (e) => e.name == name,
      orElse: () => DayType.diveDay,
    );
  }
}
```text
**Step 4: Run test to verify it passes**

Run: `flutter test test/core/constants/trip_enums_test.dart`
Expected: PASS

**Step 5: Commit**

```bash
git add lib/core/constants/enums.dart test/core/constants/trip_enums_test.dart
git commit -m "feat: add TripType and DayType enums for trip type system"
```text
---

### Task 2: Create LiveaboardDetails domain entity

**Files:**

- Create: `lib/features/trips/domain/entities/liveaboard_details.dart`
- Test: `test/features/trips/domain/entities/liveaboard_details_test.dart`

**Step 1: Write the failing test**

Create `test/features/trips/domain/entities/liveaboard_details_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/trips/domain/entities/liveaboard_details.dart';

void main() {
  group('LiveaboardDetails', () {
    late LiveaboardDetails details;

    setUp(() {
      details = LiveaboardDetails(
        id: 'lb-1',
        tripId: 'trip-1',
        vesselName: 'Ocean Explorer',
        operatorName: 'Red Sea Divers',
        vesselType: 'Motor Yacht',
        cabinType: 'Deluxe Double',
        capacity: 24,
        embarkPort: 'Hurghada Marina',
        embarkLatitude: 27.2579,
        embarkLongitude: 33.8116,
        disembarkPort: 'Hurghada Marina',
        disembarkLatitude: 27.2579,
        disembarkLongitude: 33.8116,
        createdAt: DateTime(2024, 3, 1),
        updatedAt: DateTime(2024, 3, 1),
      );
    });

    test('props returns all fields for equality', () {
      final same = LiveaboardDetails(
        id: 'lb-1',
        tripId: 'trip-1',
        vesselName: 'Ocean Explorer',
        operatorName: 'Red Sea Divers',
        vesselType: 'Motor Yacht',
        cabinType: 'Deluxe Double',
        capacity: 24,
        embarkPort: 'Hurghada Marina',
        embarkLatitude: 27.2579,
        embarkLongitude: 33.8116,
        disembarkPort: 'Hurghada Marina',
        disembarkLatitude: 27.2579,
        disembarkLongitude: 33.8116,
        createdAt: DateTime(2024, 3, 1),
        updatedAt: DateTime(2024, 3, 1),
      );
      expect(details, equals(same));
    });

    test('copyWith preserves values when not provided', () {
      final copy = details.copyWith();
      expect(copy, equals(details));
    });

    test('copyWith updates provided values', () {
      final updated = details.copyWith(
        vesselName: 'Sea Spirit',
        capacity: 20,
      );
      expect(updated.vesselName, 'Sea Spirit');
      expect(updated.capacity, 20);
      expect(updated.operatorName, 'Red Sea Divers'); // unchanged
    });

    test('copyWith can set nullable fields to null', () {
      final cleared = details.copyWith(operatorName: null, cabinType: null);
      expect(cleared.operatorName, isNull);
      expect(cleared.cabinType, isNull);
    });

    test('hasEmbarkCoordinates returns true when both lat/lng set', () {
      expect(details.hasEmbarkCoordinates, isTrue);
    });

    test('hasEmbarkCoordinates returns false when missing', () {
      final noCoords = details.copyWith(
        embarkLatitude: null,
        embarkLongitude: null,
      );
      expect(noCoords.hasEmbarkCoordinates, isFalse);
    });

    test('hasDisembarkCoordinates returns true when both lat/lng set', () {
      expect(details.hasDisembarkCoordinates, isTrue);
    });
  });
}
```text
**Step 2: Run test to verify it fails**

Run: `flutter test test/features/trips/domain/entities/liveaboard_details_test.dart`
Expected: FAIL - file not found

**Step 3: Write minimal implementation**

Create `lib/features/trips/domain/entities/liveaboard_details.dart`:

```dart
import 'package:equatable/equatable.dart';

/// Liveaboard vessel and logistics details, linked 1:1 to a Trip
class LiveaboardDetails extends Equatable {
  final String id;
  final String tripId;
  final String vesselName;
  final String? operatorName;
  final String? vesselType;
  final String? cabinType;
  final int? capacity;
  final String? embarkPort;
  final double? embarkLatitude;
  final double? embarkLongitude;
  final String? disembarkPort;
  final double? disembarkLatitude;
  final double? disembarkLongitude;
  final DateTime createdAt;
  final DateTime updatedAt;

  const LiveaboardDetails({
    required this.id,
    required this.tripId,
    required this.vesselName,
    this.operatorName,
    this.vesselType,
    this.cabinType,
    this.capacity,
    this.embarkPort,
    this.embarkLatitude,
    this.embarkLongitude,
    this.disembarkPort,
    this.disembarkLatitude,
    this.disembarkLongitude,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get hasEmbarkCoordinates =>
      embarkLatitude != null && embarkLongitude != null;

  bool get hasDisembarkCoordinates =>
      disembarkLatitude != null && disembarkLongitude != null;

  LiveaboardDetails copyWith({
    String? id,
    String? tripId,
    String? vesselName,
    Object? operatorName = _undefined,
    Object? vesselType = _undefined,
    Object? cabinType = _undefined,
    Object? capacity = _undefined,
    Object? embarkPort = _undefined,
    Object? embarkLatitude = _undefined,
    Object? embarkLongitude = _undefined,
    Object? disembarkPort = _undefined,
    Object? disembarkLatitude = _undefined,
    Object? disembarkLongitude = _undefined,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return LiveaboardDetails(
      id: id ?? this.id,
      tripId: tripId ?? this.tripId,
      vesselName: vesselName ?? this.vesselName,
      operatorName: operatorName == _undefined
          ? this.operatorName
          : operatorName as String?,
      vesselType:
          vesselType == _undefined ? this.vesselType : vesselType as String?,
      cabinType:
          cabinType == _undefined ? this.cabinType : cabinType as String?,
      capacity: capacity == _undefined ? this.capacity : capacity as int?,
      embarkPort:
          embarkPort == _undefined ? this.embarkPort : embarkPort as String?,
      embarkLatitude: embarkLatitude == _undefined
          ? this.embarkLatitude
          : embarkLatitude as double?,
      embarkLongitude: embarkLongitude == _undefined
          ? this.embarkLongitude
          : embarkLongitude as double?,
      disembarkPort: disembarkPort == _undefined
          ? this.disembarkPort
          : disembarkPort as String?,
      disembarkLatitude: disembarkLatitude == _undefined
          ? this.disembarkLatitude
          : disembarkLatitude as double?,
      disembarkLongitude: disembarkLongitude == _undefined
          ? this.disembarkLongitude
          : disembarkLongitude as double?,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    tripId,
    vesselName,
    operatorName,
    vesselType,
    cabinType,
    capacity,
    embarkPort,
    embarkLatitude,
    embarkLongitude,
    disembarkPort,
    disembarkLatitude,
    disembarkLongitude,
    createdAt,
    updatedAt,
  ];
}

const _undefined = Object();
```text
**Step 4: Run test to verify it passes**

Run: `flutter test test/features/trips/domain/entities/liveaboard_details_test.dart`
Expected: PASS

**Step 5: Commit**

```bash
git add lib/features/trips/domain/entities/liveaboard_details.dart test/features/trips/domain/entities/liveaboard_details_test.dart
git commit -m "feat: add LiveaboardDetails domain entity"
```text
---

### Task 3: Create ItineraryDay domain entity

**Files:**

- Create: `lib/features/trips/domain/entities/itinerary_day.dart`
- Test: `test/features/trips/domain/entities/itinerary_day_test.dart`

**Step 1: Write the failing test**

Create `test/features/trips/domain/entities/itinerary_day_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/trips/domain/entities/itinerary_day.dart';

void main() {
  group('ItineraryDay', () {
    late ItineraryDay day;

    setUp(() {
      day = ItineraryDay(
        id: 'day-1',
        tripId: 'trip-1',
        dayNumber: 1,
        date: DateTime(2024, 3, 5),
        dayType: DayType.embark,
        portName: 'Hurghada Marina',
        latitude: 27.2579,
        longitude: 33.8116,
        notes: 'Board at 4pm',
        createdAt: DateTime(2024, 3, 1),
        updatedAt: DateTime(2024, 3, 1),
      );
    });

    test('props returns all fields for equality', () {
      final same = ItineraryDay(
        id: 'day-1',
        tripId: 'trip-1',
        dayNumber: 1,
        date: DateTime(2024, 3, 5),
        dayType: DayType.embark,
        portName: 'Hurghada Marina',
        latitude: 27.2579,
        longitude: 33.8116,
        notes: 'Board at 4pm',
        createdAt: DateTime(2024, 3, 1),
        updatedAt: DateTime(2024, 3, 1),
      );
      expect(day, equals(same));
    });

    test('copyWith preserves values when not provided', () {
      final copy = day.copyWith();
      expect(copy, equals(day));
    });

    test('copyWith updates provided values', () {
      final updated = day.copyWith(
        dayType: DayType.diveDay,
        notes: 'Updated notes',
      );
      expect(updated.dayType, DayType.diveDay);
      expect(updated.notes, 'Updated notes');
      expect(updated.portName, 'Hurghada Marina'); // unchanged
    });

    test('copyWith can set nullable fields to null', () {
      final cleared = day.copyWith(portName: null, latitude: null);
      expect(cleared.portName, isNull);
      expect(cleared.latitude, isNull);
    });

    test('hasCoordinates returns true when both lat/lng set', () {
      expect(day.hasCoordinates, isTrue);
    });

    test('hasCoordinates returns false when missing', () {
      final noCoords = day.copyWith(latitude: null, longitude: null);
      expect(noCoords.hasCoordinates, isFalse);
    });
  });

  group('ItineraryDay.generateForTrip', () {
    test('generates correct number of days for date range', () {
      final days = ItineraryDay.generateForTrip(
        tripId: 'trip-1',
        startDate: DateTime(2024, 3, 5),
        endDate: DateTime(2024, 3, 12),
      );
      expect(days, hasLength(8)); // 5,6,7,8,9,10,11,12 = 8 days
    });

    test('first day is embark, last day is disembark', () {
      final days = ItineraryDay.generateForTrip(
        tripId: 'trip-1',
        startDate: DateTime(2024, 3, 5),
        endDate: DateTime(2024, 3, 12),
      );
      expect(days.first.dayType, DayType.embark);
      expect(days.first.dayNumber, 1);
      expect(days.last.dayType, DayType.disembark);
      expect(days.last.dayNumber, 8);
    });

    test('middle days default to diveDay', () {
      final days = ItineraryDay.generateForTrip(
        tripId: 'trip-1',
        startDate: DateTime(2024, 3, 5),
        endDate: DateTime(2024, 3, 12),
      );
      for (int i = 1; i < days.length - 1; i++) {
        expect(days[i].dayType, DayType.diveDay);
      }
    });

    test('single-day trip has both embark and disembark on same day', () {
      final days = ItineraryDay.generateForTrip(
        tripId: 'trip-1',
        startDate: DateTime(2024, 3, 5),
        endDate: DateTime(2024, 3, 5),
      );
      expect(days, hasLength(1));
      expect(days.first.dayType, DayType.embark);
    });

    test('two-day trip has embark and disembark', () {
      final days = ItineraryDay.generateForTrip(
        tripId: 'trip-1',
        startDate: DateTime(2024, 3, 5),
        endDate: DateTime(2024, 3, 6),
      );
      expect(days, hasLength(2));
      expect(days[0].dayType, DayType.embark);
      expect(days[1].dayType, DayType.disembark);
    });
  });
}
```text
**Step 2: Run test to verify it fails**

Run: `flutter test test/features/trips/domain/entities/itinerary_day_test.dart`
Expected: FAIL

**Step 3: Write minimal implementation**

Create `lib/features/trips/domain/entities/itinerary_day.dart`:

```dart
import 'package:equatable/equatable.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/constants/enums.dart';

/// A single day in a trip itinerary
class ItineraryDay extends Equatable {
  final String id;
  final String tripId;
  final int dayNumber;
  final DateTime date;
  final DayType dayType;
  final String? portName;
  final double? latitude;
  final double? longitude;
  final String notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ItineraryDay({
    required this.id,
    required this.tripId,
    required this.dayNumber,
    required this.date,
    required this.dayType,
    this.portName,
    this.latitude,
    this.longitude,
    this.notes = '',
    required this.createdAt,
    required this.updatedAt,
  });

  bool get hasCoordinates => latitude != null && longitude != null;

  /// Generate itinerary days for a trip date range.
  /// Day 1 = embark, last day = disembark, middle days = diveDay.
  static List<ItineraryDay> generateForTrip({
    required String tripId,
    required DateTime startDate,
    required DateTime endDate,
  }) {
    final uuid = const Uuid();
    final now = DateTime.now();
    final totalDays = endDate.difference(startDate).inDays + 1;
    final days = <ItineraryDay>[];

    for (int i = 0; i < totalDays; i++) {
      final DayType type;
      if (i == 0) {
        type = DayType.embark;
      } else if (i == totalDays - 1) {
        type = DayType.disembark;
      } else {
        type = DayType.diveDay;
      }

      days.add(ItineraryDay(
        id: uuid.v4(),
        tripId: tripId,
        dayNumber: i + 1,
        date: startDate.add(Duration(days: i)),
        dayType: type,
        createdAt: now,
        updatedAt: now,
      ));
    }

    return days;
  }

  ItineraryDay copyWith({
    String? id,
    String? tripId,
    int? dayNumber,
    DateTime? date,
    DayType? dayType,
    Object? portName = _undefined,
    Object? latitude = _undefined,
    Object? longitude = _undefined,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ItineraryDay(
      id: id ?? this.id,
      tripId: tripId ?? this.tripId,
      dayNumber: dayNumber ?? this.dayNumber,
      date: date ?? this.date,
      dayType: dayType ?? this.dayType,
      portName: portName == _undefined ? this.portName : portName as String?,
      latitude: latitude == _undefined ? this.latitude : latitude as double?,
      longitude:
          longitude == _undefined ? this.longitude : longitude as double?,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    tripId,
    dayNumber,
    date,
    dayType,
    portName,
    latitude,
    longitude,
    notes,
    createdAt,
    updatedAt,
  ];
}

const _undefined = Object();
```text
**Step 4: Run test to verify it passes**

Run: `flutter test test/features/trips/domain/entities/itinerary_day_test.dart`
Expected: PASS

**Step 5: Commit**

```bash
git add lib/features/trips/domain/entities/itinerary_day.dart test/features/trips/domain/entities/itinerary_day_test.dart
git commit -m "feat: add ItineraryDay domain entity with auto-generation"
```text
---

### Task 4: Update Trip entity with tripType field

**Files:**

- Modify: `lib/features/trips/domain/entities/trip.dart`
- Modify: `test/features/trips/domain/entities/trip_test.dart`

**Step 1: Write the failing test**

Add to `test/features/trips/domain/entities/trip_test.dart`:

```dart
import 'package:submersion/core/constants/enums.dart';

// Add inside main():

  group('Trip tripType', () {
    test('defaults to shore when not specified', () {
      final trip = Trip(
        id: 'trip-1',
        name: 'Test',
        startDate: DateTime(2024, 1, 1),
        endDate: DateTime(2024, 1, 7),
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 1),
      );
      expect(trip.tripType, TripType.shore);
    });

    test('isLiveaboard returns true for liveaboard type', () {
      final trip = Trip(
        id: 'trip-1',
        name: 'Red Sea Trip',
        tripType: TripType.liveaboard,
        startDate: DateTime(2024, 1, 1),
        endDate: DateTime(2024, 1, 7),
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 1),
      );
      expect(trip.isLiveaboard, isTrue);
    });

    test('copyWith preserves tripType', () {
      final trip = Trip(
        id: 'trip-1',
        name: 'Test',
        tripType: TripType.liveaboard,
        startDate: DateTime(2024, 1, 1),
        endDate: DateTime(2024, 1, 7),
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 1),
      );
      final copy = trip.copyWith(name: 'Updated');
      expect(copy.tripType, TripType.liveaboard);
    });

    test('copyWith can change tripType', () {
      final trip = Trip(
        id: 'trip-1',
        name: 'Test',
        tripType: TripType.shore,
        startDate: DateTime(2024, 1, 1),
        endDate: DateTime(2024, 1, 7),
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 1),
      );
      final updated = trip.copyWith(tripType: TripType.liveaboard);
      expect(updated.tripType, TripType.liveaboard);
    });
  });
```sql
**Step 2: Run test to verify it fails**

Run: `flutter test test/features/trips/domain/entities/trip_test.dart`
Expected: FAIL - `tripType` not a field on Trip

**Step 3: Write minimal implementation**

Modify `lib/features/trips/domain/entities/trip.dart`:

- Add import: `import 'package:submersion/core/constants/enums.dart';`
- Add field: `final TripType tripType;`
- Add to constructor: `this.tripType = TripType.shore,`
- Update `isLiveaboard` getter: `bool get isLiveaboard => tripType == TripType.liveaboard;`
- Add `tripType` to `copyWith` and `props`

The existing `isLiveaboard` logic (`liveaboardName != null && liveaboardName!.isNotEmpty`) changes to use the enum. The `isResort` getter similarly updates to `tripType == TripType.resort`. The `subtitle` getter logic stays the same (display liveaboardName or resortName based on type).

**Step 4: Run test to verify it passes**

Run: `flutter test test/features/trips/domain/entities/trip_test.dart`
Expected: PASS

**Step 5: Fix any broken callers**

Run: `flutter analyze`

Update any callers that construct `Trip` without `tripType` (they should all work since it defaults to `shore`). The existing `isLiveaboard` getter changes behavior — callers that previously set `liveaboardName` to trigger `isLiveaboard` now need `tripType: TripType.liveaboard`. Check:

- `lib/features/trips/data/repositories/trip_repository.dart` (`_mapRowToTrip`)
- `lib/features/trips/presentation/pages/trip_edit_page.dart` (`_saveTrip`)
- `lib/core/services/sync/sync_data_serializer.dart` (trip JSON mapping)
- Any test files constructing Trip objects

**Step 6: Commit**

```bash
git add lib/features/trips/domain/entities/trip.dart test/features/trips/domain/entities/trip_test.dart
git commit -m "feat: add tripType field to Trip entity"
```text
---

## Phase 2: Database Schema Changes

### Task 5: Add Drift table definitions

**Files:**

- Modify: `lib/core/database/database.dart`
  - Add `LiveaboardDetailRecords` table class (~line 62, after `Trips`)
  - Add `TripItineraryDays` table class
  - Add `tripType` column to `Trips` table
  - Register new tables in `@DriftDatabase` annotation (~line 1067)
  - Bump `schemaVersion` to 46
  - Add migration block for `from < 46`

**Step 1: Add trip_type column to Trips table**

In `lib/core/database/database.dart`, find the `Trips` class (line 46) and add:

```dart
class Trips extends Table {
  // ... existing columns ...
  TextColumn get tripType =>
      text().withDefault(const Constant('shore'))(); // TripType enum as string
  // ... rest of existing columns
}
```text
**Step 2: Add LiveaboardDetailRecords table**

Add after the `Trips` class definition (around line 62):

```dart
/// Liveaboard-specific details, 1:1 with trips
class LiveaboardDetailRecords extends Table {
  TextColumn get id => text()();
  TextColumn get tripId => text().references(Trips, #id)();
  TextColumn get vesselName => text()();
  TextColumn get operatorName => text().nullable()();
  TextColumn get vesselType => text().nullable()();
  TextColumn get cabinType => text().nullable()();
  IntColumn get capacity => integer().nullable()();
  TextColumn get embarkPort => text().nullable()();
  RealColumn get embarkLatitude => real().nullable()();
  RealColumn get embarkLongitude => real().nullable()();
  TextColumn get disembarkPort => text().nullable()();
  RealColumn get disembarkLatitude => real().nullable()();
  RealColumn get disembarkLongitude => real().nullable()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Itinerary days for trip planning
class TripItineraryDays extends Table {
  TextColumn get id => text()();
  TextColumn get tripId => text().references(Trips, #id)();
  IntColumn get dayNumber => integer()();
  IntColumn get date => integer()(); // Unix timestamp
  TextColumn get dayType =>
      text().withDefault(const Constant('diveDay'))(); // DayType enum
  TextColumn get portName => text().nullable()();
  RealColumn get latitude => real().nullable()();
  RealColumn get longitude => real().nullable()();
  TextColumn get notes => text().withDefault(const Constant(''))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}
```text
**Step 3: Register tables in @DriftDatabase**

Add `LiveaboardDetailRecords` and `TripItineraryDays` to the tables list at ~line 1067:

```dart
@DriftDatabase(
  tables: [
    // ... existing tables ...
    LiveaboardDetailRecords,
    TripItineraryDays,
  ],
)
```text
**Step 4: Bump schema version and add migration**

Change `schemaVersion` from 45 to 46 at line 1122.

Add migration block inside `onUpgrade` (after the `from < 45` block):

```dart
if (from < 46) {
  // Add trip type column
  final tripsInfo = await customSelect(
    'PRAGMA table_info(trips)',
  ).get();
  final tripsCols = tripsInfo
      .map((r) => r.read<String>('name'))
      .toSet();
  if (!tripsCols.contains('trip_type')) {
    await customStatement(
      "ALTER TABLE trips ADD COLUMN trip_type TEXT NOT NULL DEFAULT 'shore'",
    );
  }

  // Create liveaboard_details table
  await customStatement('''
    CREATE TABLE IF NOT EXISTS liveaboard_detail_records (
      id TEXT NOT NULL PRIMARY KEY,
      trip_id TEXT NOT NULL REFERENCES trips(id),
      vessel_name TEXT NOT NULL,
      operator_name TEXT,
      vessel_type TEXT,
      cabin_type TEXT,
      capacity INTEGER,
      embark_port TEXT,
      embark_latitude REAL,
      embark_longitude REAL,
      disembark_port TEXT,
      disembark_latitude REAL,
      disembark_longitude REAL,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL
    )
  ''');

  // Create trip_itinerary_days table
  await customStatement('''
    CREATE TABLE IF NOT EXISTS trip_itinerary_days (
      id TEXT NOT NULL PRIMARY KEY,
      trip_id TEXT NOT NULL REFERENCES trips(id),
      day_number INTEGER NOT NULL,
      date INTEGER NOT NULL,
      day_type TEXT NOT NULL DEFAULT 'diveDay',
      port_name TEXT,
      latitude REAL,
      longitude REAL,
      notes TEXT NOT NULL DEFAULT '',
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL
    )
  ''');

  // Migrate existing liveaboard trips
  await customStatement('''
    UPDATE trips SET trip_type = 'liveaboard'
    WHERE liveaboard_name IS NOT NULL AND liveaboard_name != ''
  ''');

  // Migrate existing resort trips (only those not already liveaboard)
  await customStatement('''
    UPDATE trips SET trip_type = 'resort'
    WHERE resort_name IS NOT NULL AND resort_name != ''
      AND trip_type = 'shore'
  ''');

  // Create liveaboard_detail_records for existing liveaboard trips
  await customStatement('''
    INSERT INTO liveaboard_detail_records (
      id, trip_id, vessel_name, created_at, updated_at
    )
    SELECT
      lower(hex(randomblob(4)) || '-' || hex(randomblob(2)) || '-4' ||
        substr(hex(randomblob(2)),2) || '-' ||
        substr('89ab', abs(random()) % 4 + 1, 1) ||
        substr(hex(randomblob(2)),2) || '-' || hex(randomblob(6))),
      id,
      liveaboard_name,
      created_at,
      updated_at
    FROM trips
    WHERE trip_type = 'liveaboard'
  ''');
}
```text
**Step 5: Run code generation**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: Generates updated `database.g.dart`

**Step 6: Run tests to verify nothing is broken**

Run: `flutter test`
Expected: All existing tests pass

**Step 7: Commit**

```bash
git add lib/core/database/database.dart lib/core/database/database.g.dart
git commit -m "feat: add liveaboard_details and trip_itinerary_days tables, schema v46"
```text
---

## Phase 3: Repository Layer

### Task 6: Update TripRepository for tripType

**Files:**

- Modify: `lib/features/trips/data/repositories/trip_repository.dart`
- Modify: `test/features/trips/data/repositories/trip_repository_test.dart`

**Step 1: Update `_mapRowToTrip` to include tripType**

In `lib/features/trips/data/repositories/trip_repository.dart`, update the `_mapRowToTrip` method (line 382) to include:

```dart
tripType: TripType.fromName(row.tripType),
```dart
Also add import: `import 'package:submersion/core/constants/enums.dart';`

**Step 2: Update `createTrip` and `updateTrip` to persist tripType**

In `createTrip` (line 96), add to `TripsCompanion`:

```dart
tripType: Value(trip.tripType.name),
```text
In `updateTrip` (line 136), add to `TripsCompanion`:

```dart
tripType: Value(trip.tripType.name),
```text
**Step 3: Update all `customSelect` methods that construct Trip**

Search for manual `domain.Trip(` constructions in `searchTrips`, `findTripForDate`, `getAllTripsWithStats` and add:

```dart
tripType: TripType.fromName((row.data['trip_type'] as String?) ?? 'shore'),
```text
**Step 4: Run tests**

Run: `flutter test test/features/trips/`
Expected: PASS (existing tests should still work since tripType defaults to shore)

**Step 5: Commit**

```bash
git add lib/features/trips/data/repositories/trip_repository.dart
git commit -m "feat: persist tripType in TripRepository"
```text
---

### Task 7: Create LiveaboardDetailsRepository

**Files:**

- Create: `lib/features/trips/data/repositories/liveaboard_details_repository.dart`
- Test: `test/features/trips/data/repositories/liveaboard_details_repository_test.dart`

**Step 1: Write the failing test**

Create `test/features/trips/data/repositories/liveaboard_details_repository_test.dart`. Note: this project uses a real in-memory database for repository tests. Check existing `test/features/trips/data/repositories/trip_repository_test.dart` for the pattern and replicate it.

The test should cover:

- `getByTripId` returns null when no details exist
- `createOrUpdate` creates new details
- `getByTripId` returns created details
- `createOrUpdate` updates existing details
- `deleteByTripId` removes details

**Step 2: Write implementation**

Create `lib/features/trips/data/repositories/liveaboard_details_repository.dart`:

```dart
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/features/trips/domain/entities/liveaboard_details.dart'
    as domain;

class LiveaboardDetailsRepository {
  AppDatabase get _db => DatabaseService.instance.database;
  final SyncRepository _syncRepository = SyncRepository();
  final _uuid = const Uuid();
  final _log = LoggerService.forClass(LiveaboardDetailsRepository);

  Future<domain.LiveaboardDetails?> getByTripId(String tripId) async {
    try {
      final query = _db.select(_db.liveaboardDetailRecords)
        ..where((t) => t.tripId.equals(tripId));
      final row = await query.getSingleOrNull();
      return row != null ? _mapRow(row) : null;
    } catch (e, stackTrace) {
      _log.error('Failed to get liveaboard details for trip: $tripId', e, stackTrace);
      rethrow;
    }
  }

  Future<domain.LiveaboardDetails> createOrUpdate(
    domain.LiveaboardDetails details,
  ) async {
    try {
      final id = details.id.isEmpty ? _uuid.v4() : details.id;
      final now = DateTime.now();

      await _db.into(_db.liveaboardDetailRecords).insertOnConflictUpdate(
        LiveaboardDetailRecordsCompanion(
          id: Value(id),
          tripId: Value(details.tripId),
          vesselName: Value(details.vesselName),
          operatorName: Value(details.operatorName),
          vesselType: Value(details.vesselType),
          cabinType: Value(details.cabinType),
          capacity: Value(details.capacity),
          embarkPort: Value(details.embarkPort),
          embarkLatitude: Value(details.embarkLatitude),
          embarkLongitude: Value(details.embarkLongitude),
          disembarkPort: Value(details.disembarkPort),
          disembarkLatitude: Value(details.disembarkLatitude),
          disembarkLongitude: Value(details.disembarkLongitude),
          createdAt: Value(now.millisecondsSinceEpoch),
          updatedAt: Value(now.millisecondsSinceEpoch),
        ),
      );

      await _syncRepository.markRecordPending(
        entityType: 'liveaboardDetails',
        recordId: id,
        localUpdatedAt: now.millisecondsSinceEpoch,
      );
      SyncEventBus.notifyLocalChange();

      return details.copyWith(id: id, createdAt: now, updatedAt: now);
    } catch (e, stackTrace) {
      _log.error('Failed to create/update liveaboard details', e, stackTrace);
      rethrow;
    }
  }

  Future<void> deleteByTripId(String tripId) async {
    try {
      final existing = await getByTripId(tripId);
      if (existing == null) return;

      await (_db.delete(_db.liveaboardDetailRecords)
            ..where((t) => t.tripId.equals(tripId)))
          .go();
      await _syncRepository.logDeletion(
        entityType: 'liveaboardDetails',
        recordId: existing.id,
      );
      SyncEventBus.notifyLocalChange();
    } catch (e, stackTrace) {
      _log.error('Failed to delete liveaboard details for trip: $tripId', e, stackTrace);
      rethrow;
    }
  }

  domain.LiveaboardDetails _mapRow(LiveaboardDetailRecord row) {
    return domain.LiveaboardDetails(
      id: row.id,
      tripId: row.tripId,
      vesselName: row.vesselName,
      operatorName: row.operatorName,
      vesselType: row.vesselType,
      cabinType: row.cabinType,
      capacity: row.capacity,
      embarkPort: row.embarkPort,
      embarkLatitude: row.embarkLatitude,
      embarkLongitude: row.embarkLongitude,
      disembarkPort: row.disembarkPort,
      disembarkLatitude: row.disembarkLatitude,
      disembarkLongitude: row.disembarkLongitude,
      createdAt: DateTime.fromMillisecondsSinceEpoch(row.createdAt),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(row.updatedAt),
    );
  }
}
```text
**Step 3: Run tests, commit**

```bash
git add lib/features/trips/data/repositories/liveaboard_details_repository.dart test/features/trips/data/repositories/liveaboard_details_repository_test.dart
git commit -m "feat: add LiveaboardDetailsRepository with CRUD"
```sql
---

### Task 8: Create ItineraryDayRepository

**Files:**

- Create: `lib/features/trips/data/repositories/itinerary_day_repository.dart`
- Test: `test/features/trips/data/repositories/itinerary_day_repository_test.dart`

**Step 1: Write implementation**

Follow the same pattern as Task 7. Key methods:

- `getByTripId(String tripId)` -> `Future<List<domain.ItineraryDay>>`
- `saveAll(List<domain.ItineraryDay> days)` -> bulk insert/update
- `updateDay(domain.ItineraryDay day)` -> single day update
- `deleteByTripId(String tripId)` -> delete all days for a trip
- `regenerateForTrip(String tripId, DateTime startDate, DateTime endDate)` -> delete old days, generate and save new ones, preserving notes from matching dates

The `regenerateForTrip` method is the key logic: when a trip's date range changes, it should:

1. Load existing days
2. Generate new days from the new date range
3. For dates that exist in both old and new ranges, preserve the old day's type, port, and notes
4. Save the merged result

**Step 2: Tests, commit**

```bash
git add lib/features/trips/data/repositories/itinerary_day_repository.dart test/features/trips/data/repositories/itinerary_day_repository_test.dart
git commit -m "feat: add ItineraryDayRepository with regeneration logic"
```typescript
---

## Phase 4: Sync Integration

### Task 9: Add liveaboard_details and trip_itinerary_days to sync

**Files:**

- Modify: `lib/core/services/sync/sync_data_serializer.dart`
  - Add fields to `SyncData` class (~line 96)
  - Add export calls in `exportData()` (~line 265)
  - Add cases in `fetchRecord()` (~line 432)
  - Add cases in `upsertRecord()` (~line 601)
  - Add cases in `deleteRecord()` (~line 753)
  - Add `_exportLiveaboardDetails()` helper
  - Add `_exportItineraryDays()` helper
  - Add `_liveaboardDetailToJson()` converter
  - Add `_itineraryDayToJson()` converter
  - Update `_tripToJson()` to include `tripType` field
- Modify: `lib/core/services/sync/sync_service.dart`
  - Add entries to `mergeOrder` (~line 571) after the `trips` entry

**Step 1: Update SyncData class**

Add two new fields:

```dart
final List<Map<String, dynamic>> liveaboardDetails;
final List<Map<String, dynamic>> itineraryDays;
```text
Add to constructor, toJson, fromJson.

**Step 2: Update _tripToJson to include tripType**

```dart
Map<String, dynamic> _tripToJson(Trip r) => {
  // ... existing fields ...
  'tripType': r.tripType, // ADD THIS
};
```text
**Step 3: Add export, fetch, upsert, delete handlers**

Follow the exact pattern of existing trip handlers. Place `liveaboardDetails` and `itineraryDays` in `mergeOrder` right after `trips` since they have a FK dependency on trips:

```dart
(type: 'trips', records: data.trips, hasUpdatedAt: true),
(type: 'liveaboardDetails', records: data.liveaboardDetails, hasUpdatedAt: true),
(type: 'itineraryDays', records: data.itineraryDays, hasUpdatedAt: true),
```text
**Step 4: Run existing sync tests**

Run: `flutter test test/core/services/`
Expected: PASS

**Step 5: Commit**

```bash
git add lib/core/services/sync/sync_data_serializer.dart lib/core/services/sync/sync_service.dart
git commit -m "feat: add liveaboard details and itinerary days to sync"
```dart
---

## Phase 5: Providers

### Task 10: Add liveaboard and itinerary providers

**Files:**

- Modify: `lib/features/trips/presentation/providers/trip_providers.dart`
- Create: `lib/features/trips/presentation/providers/liveaboard_providers.dart`

**Step 1: Create provider file**

Create `lib/features/trips/presentation/providers/liveaboard_providers.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/features/trips/data/repositories/liveaboard_details_repository.dart';
import 'package:submersion/features/trips/data/repositories/itinerary_day_repository.dart';
import 'package:submersion/features/trips/domain/entities/liveaboard_details.dart';
import 'package:submersion/features/trips/domain/entities/itinerary_day.dart';

final liveaboardDetailsRepositoryProvider =
    Provider<LiveaboardDetailsRepository>((ref) {
  return LiveaboardDetailsRepository();
});

final itineraryDayRepositoryProvider =
    Provider<ItineraryDayRepository>((ref) {
  return ItineraryDayRepository();
});

final liveaboardDetailsProvider =
    FutureProvider.family<LiveaboardDetails?, String>((ref, tripId) async {
  final repository = ref.watch(liveaboardDetailsRepositoryProvider);
  return repository.getByTripId(tripId);
});

final itineraryDaysProvider =
    FutureProvider.family<List<ItineraryDay>, String>((ref, tripId) async {
  final repository = ref.watch(itineraryDayRepositoryProvider);
  return repository.getByTripId(tripId);
});
```text
**Step 2: Commit**

```bash
git add lib/features/trips/presentation/providers/liveaboard_providers.dart
git commit -m "feat: add Riverpod providers for liveaboard details and itinerary"
```swift
---

## Phase 6: Localization

### Task 11: Add l10n strings for liveaboard UI

**Files:**

- Modify: `lib/l10n/arb/app_en.arb`
- Run: `flutter gen-l10n` (or let build_runner handle it)

**Step 1: Add strings to app_en.arb**

Add trip type and liveaboard-specific strings following the existing `trips_` naming convention:

```json
"trips_type_shore": "Shore",
"trips_type_liveaboard": "Liveaboard",
"trips_type_resort": "Resort",
"trips_type_dayTrip": "Day Trip",

"trips_edit_label_tripType": "Trip Type",
"trips_edit_sectionTitle_vessel": "Vessel Details",
"trips_edit_label_vesselName": "Vessel Name *",
"trips_edit_hint_vesselName": "e.g. Ocean Explorer",
"trips_edit_label_operatorName": "Operator / Charter",
"trips_edit_hint_operatorName": "e.g. Red Sea Divers",
"trips_edit_label_vesselType": "Vessel Type",
"trips_edit_label_cabinType": "Cabin Type",
"trips_edit_hint_cabinType": "e.g. Deluxe Double",
"trips_edit_label_capacity": "Passenger Capacity",
"trips_edit_sectionTitle_embarkDisembark": "Embark / Disembark",
"trips_edit_label_embarkPort": "Embark Port",
"trips_edit_hint_embarkPort": "e.g. Hurghada Marina",
"trips_edit_label_disembarkPort": "Disembark Port",
"trips_edit_hint_disembarkPort": "e.g. Hurghada Marina",
"trips_edit_validation_vesselRequired": "Vessel name is required for liveaboard trips",

"trips_detail_tab_overview": "Overview",
"trips_detail_tab_itinerary": "Itinerary",
"trips_detail_tab_photos": "Photos",
"trips_detail_tab_dives": "Dives",
"trips_detail_sectionTitle_vessel": "Vessel",
"trips_detail_label_operator": "Operator",
"trips_detail_label_vesselType": "Type",
"trips_detail_label_cabin": "Cabin",
"trips_detail_label_capacity": "Capacity",
"trips_detail_label_embark": "Embark",
"trips_detail_label_disembark": "Disembark",
"trips_detail_stat_divesPerDay": "Dives per day",
"trips_detail_stat_diveDays": "Dive days",
"trips_detail_stat_seaDays": "Sea days",
"trips_detail_stat_sitesVisited": "Sites visited",
"trips_detail_stat_speciesSeen": "Species seen",
"trips_detail_sectionTitle_dailyBreakdown": "Daily Breakdown",
"trips_detail_sectionTitle_voyageMap": "Voyage Route",

"trips_itinerary_dayLabel": "Day {dayNumber}",
"trips_itinerary_diveCount": "{count, plural, =1{1 dive} other{{count} dives}}",
"trips_itinerary_editDay": "Edit Day",
"trips_itinerary_dayType_label": "Day Type",
"trips_itinerary_portName_label": "Port / Anchorage",
"trips_itinerary_notes_label": "Notes",
"trips_itinerary_noDives": "No dives",

"trips_vesselType_catamaran": "Catamaran",
"trips_vesselType_motorYacht": "Motor Yacht",
"trips_vesselType_sailingYacht": "Sailing Yacht",
"trips_vesselType_other": "Other"
```text
**Step 2: Regenerate l10n**

Run: `flutter gen-l10n`
Expected: Updates `app_localizations.dart` and `app_localizations_en.dart`

**Step 3: Commit**

```bash
git add lib/l10n/
git commit -m "feat: add l10n strings for liveaboard tracking UI"
```sql
---

## Phase 7: UI - Trip Edit Form

### Task 12: Add trip type selector to trip edit page

**Files:**

- Modify: `lib/features/trips/presentation/pages/trip_edit_page.dart`

**Step 1: Add state for trip type and liveaboard fields**

Add to `_TripEditPageState`:

- `TripType _tripType = TripType.shore;`
- Controllers: `_vesselNameController`, `_operatorController`, `_cabinTypeController`, `_capacityController`, `_embarkPortController`, `_disembarkPortController`
- `String? _vesselType`

**Step 2: Add SegmentedButton at top of form**

Insert before the Name field:

```dart
SegmentedButton<TripType>(
  segments: [
    ButtonSegment(value: TripType.shore, label: Text(context.l10n.trips_type_shore)),
    ButtonSegment(value: TripType.liveaboard, label: Text(context.l10n.trips_type_liveaboard)),
    ButtonSegment(value: TripType.resort, label: Text(context.l10n.trips_type_resort)),
    ButtonSegment(value: TripType.dayTrip, label: Text(context.l10n.trips_type_dayTrip)),
  ],
  selected: {_tripType},
  onSelectionChanged: (selected) {
    setState(() {
      _tripType = selected.first;
      _hasChanges = true;
    });
  },
),
```typescript
**Step 3: Conditionally show vessel and embark/disembark sections**

Wrap liveaboard-specific fields in `if (_tripType == TripType.liveaboard) ...[ ]`

Add vessel name validation that only fires when type is liveaboard:

```dart
validator: (value) {
  if (_tripType == TripType.liveaboard && (value == null || value.trim().isEmpty)) {
    return context.l10n.trips_edit_validation_vesselRequired;
  }
  return null;
},
```typescript
**Step 4: Update _loadTrip to load liveaboard details**

When editing an existing liveaboard trip, also load from `LiveaboardDetailsRepository` and populate the new controllers.

**Step 5: Update _saveTrip to persist liveaboard details**

After saving the trip, if type is liveaboard, create/update `LiveaboardDetails`. If type changed away from liveaboard, delete existing details.

Also save itinerary days (generate if new liveaboard trip, keep existing if editing).

**Step 6: Run widget tests**

Run: `flutter test test/features/trips/presentation/pages/trip_edit_page_test.dart`
Expected: Existing tests pass (they create shore trips by default)

**Step 7: Commit**

```bash
git add lib/features/trips/presentation/pages/trip_edit_page.dart
git commit -m "feat: add trip type selector and liveaboard form fields"
```text
---

## Phase 8: UI - Trip Detail (Tabbed Layout)

### Task 13: Refactor trip detail page for liveaboard tabbed layout

**Files:**

- Modify: `lib/features/trips/presentation/pages/trip_detail_page.dart`
- Create: `lib/features/trips/presentation/widgets/trip_overview_tab.dart`
- Create: `lib/features/trips/presentation/widgets/trip_itinerary_tab.dart`
- Create: `lib/features/trips/presentation/widgets/trip_voyage_map.dart`
- Create: `lib/features/trips/presentation/widgets/trip_enhanced_stats.dart`

**Step 1: Extract current content into TripOverviewTab**

Move the existing `_TripDetailContent` body into a new `TripOverviewTab` widget. For liveaboard trips, this tab also includes the voyage map and enhanced stats.

**Step 2: Create TripItineraryTab**

Displays the auto-generated day timeline:

- Uses `itineraryDaysProvider(tripId)` and `divesForTripProvider(tripId)`
- Groups dives by date to show under each day
- Each day row is tappable to edit type/port/notes via a bottom sheet

**Step 3: Create TripVoyageMap**

Interactive flutter_map widget showing:

- Embark port marker (from `liveaboardDetails`)
- Dive site markers (from `tripSitesWithLocationsProvider`)
- Disembark port marker (from `liveaboardDetails`)
- PolylineLayer connecting points in chronological order

**Step 4: Create TripEnhancedStats**

Extended stats card for liveaboard trips showing the additional metrics (dives per day, dive days, sea days, sites visited, species seen).

**Step 5: Wire up TabBarView in trip detail**

For `trip.isLiveaboard`, use `DefaultTabController` + `TabBar` + `TabBarView` with 4 tabs: Overview, Itinerary, Photos, Dives. For non-liveaboard trips, keep the current single-scroll layout.

**Step 6: Run tests**

Run: `flutter test test/features/trips/`
Expected: PASS

**Step 7: Commit**

```bash
git add lib/features/trips/presentation/
git commit -m "feat: add tabbed liveaboard detail page with itinerary and voyage map"
```typescript
---

## Phase 9: Itinerary Day Editing

### Task 14: Add itinerary day edit bottom sheet

**Files:**

- Create: `lib/features/trips/presentation/widgets/itinerary_day_edit_sheet.dart`

**Step 1: Create bottom sheet widget**

A `showModalBottomSheet` that allows editing:

- Day type (dropdown of DayType values)
- Port name (text field)
- Notes (text field, multiline)

On save, calls `ItineraryDayRepository.updateDay()` and invalidates `itineraryDaysProvider`.

**Step 2: Wire into itinerary tab**

Each day row in `TripItineraryTab` calls `showItineraryDayEditSheet()` on tap.

**Step 3: Commit**

```bash
git add lib/features/trips/presentation/widgets/itinerary_day_edit_sheet.dart
git commit -m "feat: add itinerary day editing bottom sheet"
```text
---

## Phase 10: Daily Breakdown & Final Polish

### Task 15: Add daily breakdown section

**Files:**

- Create: `lib/features/trips/presentation/widgets/trip_daily_breakdown.dart`

**Step 1: Create widget**

A collapsible `ExpansionTile` or similar that shows a compact table: Day | Type | Dives | Bottom Time | Sites. Uses data from itinerary days joined with dives grouped by date.

**Step 2: Wire into overview tab for liveaboard trips**

**Step 3: Commit**

```bash
git add lib/features/trips/presentation/widgets/trip_daily_breakdown.dart
git commit -m "feat: add daily breakdown summary for liveaboard trips"
```typescript
---

### Task 16: Update UDDF/CSV import/export for trip type

**Files:**

- Modify: `lib/core/services/export/csv/csv_export_service.dart`
- Modify: `lib/core/services/export/csv/csv_import_service.dart`
- Modify: `lib/core/services/export/uddf/uddf_export_builders.dart`
- Modify: `lib/core/services/export/uddf/uddf_import_parsers.dart`

**Step 1: Add tripType to CSV export columns**

Include `trip_type` column in CSV trip export. Import should parse it with `TripType.fromName()`.

**Step 2: Add tripType to UDDF trip element**

Add as an extension element in UDDF export. Import should read it if present.

**Step 3: Run import/export tests**

Run: `flutter test test/core/services/export_service_test.dart test/integration/uddf_round_trip_test.dart`
Expected: PASS

**Step 4: Commit**

```bash
git add lib/core/services/export/
git commit -m "feat: include trip type in CSV and UDDF import/export"
```diff
---

### Task 17: Run full test suite and format

**Step 1: Format all code**

Run: `dart format lib/ test/`

**Step 2: Analyze**

Run: `flutter analyze`
Expected: No issues

**Step 3: Run full test suite**

Run: `flutter test`
Expected: All tests pass

**Step 4: Final commit**

```bash
git add -A
git commit -m "chore: format and fix any remaining issues"
```

---

## Summary

| Phase | Tasks | Description |
|-------|-------|-------------|
| 1 | 1-4 | Enums and domain entities (no DB changes) |
| 2 | 5 | Database schema: new tables, migration, codegen |
| 3 | 6-8 | Repository layer: CRUD for all new data |
| 4 | 9 | Sync integration for cloud sync |
| 5 | 10 | Riverpod providers |
| 6 | 11 | Localization strings |
| 7 | 12 | Trip edit form with type selector |
| 8 | 13 | Trip detail tabbed layout, voyage map, enhanced stats |
| 9 | 14 | Itinerary day editing |
| 10 | 15-17 | Daily breakdown, import/export, final polish |

**Total estimated commits:** 15-17
**Key risk:** Schema migration (Task 5) - test with existing data to ensure backward compatibility
