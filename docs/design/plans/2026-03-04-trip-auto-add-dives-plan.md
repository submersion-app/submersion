# Trip Auto-Add Dives Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Automatically scan for and offer to associate dives that fall within a trip's date range when a trip is created, edited, or via a manual button.

**Architecture:** Repository-level query finds candidate dives (unassigned + other-trip) by date range. A shared scanner service wraps the query. Both trigger points (post-save in trip edit page, manual button on trip detail) call the scanner and present results in a DiveAssignmentDialog modal bottom sheet.

**Tech Stack:** Flutter, Drift ORM, Riverpod, Material 3

**Design doc:** `docs/plans/2026-03-04-trip-auto-add-dives-design.md`

---

## Task 1: DiveCandidate Entity

**Files:**
- Create: `lib/features/trips/domain/entities/dive_candidate.dart`
- Test: `test/features/trips/domain/entities/dive_candidate_test.dart`

**Step 1: Write the failing test**

```dart
// test/features/trips/domain/entities/dive_candidate_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/trips/domain/entities/dive_candidate.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

void main() {
  group('DiveCandidate', () {
    final dive = Dive(
      id: 'dive-1',
      dateTime: DateTime(2026, 3, 5),
      notes: '',
      tanks: const [],
      profile: const [],
      equipment: const [],
      photoIds: const [],
      sightings: const [],
      diveTypeId: '',
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

    test('isUnassigned returns true when currentTripId is null', () {
      final candidate = DiveCandidate(dive: dive);
      expect(candidate.isUnassigned, isTrue);
    });

    test('isUnassigned returns false when currentTripId is set', () {
      final candidate = DiveCandidate(
        dive: dive,
        currentTripId: 'trip-99',
        currentTripName: 'Other Trip',
      );
      expect(candidate.isUnassigned, isFalse);
    });

    test('supports value equality via Equatable', () {
      final a = DiveCandidate(dive: dive);
      final b = DiveCandidate(dive: dive);
      expect(a, equals(b));
    });

    test('different currentTripId produces inequality', () {
      final a = DiveCandidate(dive: dive);
      final b = DiveCandidate(dive: dive, currentTripId: 'trip-99');
      expect(a, isNot(equals(b)));
    });
  });
}
```

**Step 2: Run test to verify it fails**

Run: `flutter test test/features/trips/domain/entities/dive_candidate_test.dart`
Expected: FAIL — cannot resolve `DiveCandidate` import

**Step 3: Write minimal implementation**

```dart
// lib/features/trips/domain/entities/dive_candidate.dart
import 'package:equatable/equatable.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

/// A dive found during trip date-range scanning.
/// Wraps the dive with info about its current trip assignment (if any).
class DiveCandidate extends Equatable {
  final Dive dive;
  final String? currentTripId;
  final String? currentTripName;

  const DiveCandidate({
    required this.dive,
    this.currentTripId,
    this.currentTripName,
  });

  bool get isUnassigned => currentTripId == null;

  @override
  List<Object?> get props => [dive, currentTripId, currentTripName];
}
```

**Step 4: Run test to verify it passes**

Run: `flutter test test/features/trips/domain/entities/dive_candidate_test.dart`
Expected: PASS (4 tests)

**Step 5: Commit**

```bash
git add lib/features/trips/domain/entities/dive_candidate.dart test/features/trips/domain/entities/dive_candidate_test.dart
git commit -m "feat: add DiveCandidate entity for trip dive scanning"
```

---

## Task 2: Repository — findCandidateDivesForTrip

**Files:**
- Modify: `lib/features/trips/data/repositories/trip_repository.dart` (add method after line 265)
- Test: `test/features/trips/data/repositories/trip_repository_dive_scan_test.dart`

**Step 1: Write the failing test**

This is an integration test against a real in-memory Drift database. Follow the existing test pattern used in the project.

```dart
// test/features/trips/data/repositories/trip_repository_dive_scan_test.dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/trips/data/repositories/trip_repository.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/core/constants/enums.dart';

void main() {
  late TripRepository repository;

  setUp(() async {
    final db = AppDatabase(NativeDatabase.memory());
    DatabaseService.instance.setDatabaseForTesting(db);
    repository = TripRepository();
  });

  tearDown(() async {
    await DatabaseService.instance.database.close();
  });

  group('findCandidateDivesForTrip', () {
    test('returns unassigned dives within trip date range', () async {
      // Create a trip: Mar 1-7
      final trip = await repository.createTrip(Trip(
        id: '',
        name: 'Red Sea Trip',
        startDate: DateTime(2026, 3, 1),
        endDate: DateTime(2026, 3, 7),
        diverId: 'diver-1',
        tripType: TripType.shore,
        notes: '',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));

      // Insert an unassigned dive on Mar 3 via raw SQL
      final db = DatabaseService.instance.database;
      final diveDate = DateTime(2026, 3, 3).millisecondsSinceEpoch;
      final now = DateTime.now().millisecondsSinceEpoch;
      await db.customInsert(
        'INSERT INTO dives (id, diver_id, dive_date_time, notes, dive_type_id, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?)',
        variables: [
          Variable.withString('dive-1'),
          Variable.withString('diver-1'),
          Variable.withInt(diveDate),
          Variable.withString(''),
          Variable.withString(''),
          Variable.withInt(now),
          Variable.withInt(now),
        ],
      );

      final candidates = await repository.findCandidateDivesForTrip(
        tripId: trip.id,
        startDate: DateTime(2026, 3, 1),
        endDate: DateTime(2026, 3, 7),
        diverId: 'diver-1',
      );

      expect(candidates, hasLength(1));
      expect(candidates.first.dive.id, 'dive-1');
      expect(candidates.first.isUnassigned, isTrue);
    });

    test('excludes dives already on this trip', () async {
      final trip = await repository.createTrip(Trip(
        id: '',
        name: 'My Trip',
        startDate: DateTime(2026, 3, 1),
        endDate: DateTime(2026, 3, 7),
        diverId: 'diver-1',
        tripType: TripType.shore,
        notes: '',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));

      // Insert a dive already assigned to this trip
      final db = DatabaseService.instance.database;
      final diveDate = DateTime(2026, 3, 3).millisecondsSinceEpoch;
      final now = DateTime.now().millisecondsSinceEpoch;
      await db.customInsert(
        'INSERT INTO dives (id, diver_id, dive_date_time, trip_id, notes, dive_type_id, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
        variables: [
          Variable.withString('dive-1'),
          Variable.withString('diver-1'),
          Variable.withInt(diveDate),
          Variable.withString(trip.id),
          Variable.withString(''),
          Variable.withString(''),
          Variable.withInt(now),
          Variable.withInt(now),
        ],
      );

      final candidates = await repository.findCandidateDivesForTrip(
        tripId: trip.id,
        startDate: DateTime(2026, 3, 1),
        endDate: DateTime(2026, 3, 7),
        diverId: 'diver-1',
      );

      expect(candidates, isEmpty);
    });

    test('includes dives on other trips with trip name', () async {
      final trip = await repository.createTrip(Trip(
        id: '',
        name: 'New Trip',
        startDate: DateTime(2026, 3, 1),
        endDate: DateTime(2026, 3, 7),
        diverId: 'diver-1',
        tripType: TripType.shore,
        notes: '',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));

      final otherTrip = await repository.createTrip(Trip(
        id: '',
        name: 'Sharm Weekend',
        startDate: DateTime(2026, 3, 1),
        endDate: DateTime(2026, 3, 3),
        diverId: 'diver-1',
        tripType: TripType.shore,
        notes: '',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));

      // Insert a dive on the other trip
      final db = DatabaseService.instance.database;
      final diveDate = DateTime(2026, 3, 2).millisecondsSinceEpoch;
      final now = DateTime.now().millisecondsSinceEpoch;
      await db.customInsert(
        'INSERT INTO dives (id, diver_id, dive_date_time, trip_id, notes, dive_type_id, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
        variables: [
          Variable.withString('dive-1'),
          Variable.withString('diver-1'),
          Variable.withInt(diveDate),
          Variable.withString(otherTrip.id),
          Variable.withString(''),
          Variable.withString(''),
          Variable.withInt(now),
          Variable.withInt(now),
        ],
      );

      final candidates = await repository.findCandidateDivesForTrip(
        tripId: trip.id,
        startDate: DateTime(2026, 3, 1),
        endDate: DateTime(2026, 3, 7),
        diverId: 'diver-1',
      );

      expect(candidates, hasLength(1));
      expect(candidates.first.isUnassigned, isFalse);
      expect(candidates.first.currentTripId, otherTrip.id);
      expect(candidates.first.currentTripName, 'Sharm Weekend');
    });

    test('excludes dives from other divers', () async {
      final trip = await repository.createTrip(Trip(
        id: '',
        name: 'My Trip',
        startDate: DateTime(2026, 3, 1),
        endDate: DateTime(2026, 3, 7),
        diverId: 'diver-1',
        tripType: TripType.shore,
        notes: '',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));

      // Insert an unassigned dive from a different diver
      final db = DatabaseService.instance.database;
      final diveDate = DateTime(2026, 3, 3).millisecondsSinceEpoch;
      final now = DateTime.now().millisecondsSinceEpoch;
      await db.customInsert(
        'INSERT INTO dives (id, diver_id, dive_date_time, notes, dive_type_id, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?)',
        variables: [
          Variable.withString('dive-other'),
          Variable.withString('diver-2'),
          Variable.withInt(diveDate),
          Variable.withString(''),
          Variable.withString(''),
          Variable.withInt(now),
          Variable.withInt(now),
        ],
      );

      final candidates = await repository.findCandidateDivesForTrip(
        tripId: trip.id,
        startDate: DateTime(2026, 3, 1),
        endDate: DateTime(2026, 3, 7),
        diverId: 'diver-1',
      );

      expect(candidates, isEmpty);
    });
  });
}
```

**Step 2: Run test to verify it fails**

Run: `flutter test test/features/trips/data/repositories/trip_repository_dive_scan_test.dart`
Expected: FAIL — `findCandidateDivesForTrip` not found

**Step 3: Write minimal implementation**

Add to `lib/features/trips/data/repositories/trip_repository.dart` after `removeDiveFromTrip` (line 265):

```dart
import 'package:submersion/features/trips/domain/entities/dive_candidate.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
```

```dart
  /// Find dives within a trip's date range that are either unassigned
  /// or assigned to a different trip (excludes dives already on this trip).
  Future<List<DiveCandidate>> findCandidateDivesForTrip({
    required String tripId,
    required DateTime startDate,
    required DateTime endDate,
    required String diverId,
  }) async {
    try {
      _log.info('Scanning for candidate dives: $startDate - $endDate');
      final startMs = startDate.millisecondsSinceEpoch;
      final endMs = endDate.millisecondsSinceEpoch;

      final rows = await _db.customSelect('''
        SELECT d.id as dive_id, t.id as other_trip_id, t.name as other_trip_name
        FROM dives d
        LEFT JOIN trips t ON d.trip_id = t.id AND d.trip_id != ?
        WHERE d.dive_date_time >= ? AND d.dive_date_time <= ?
          AND d.diver_id = ?
          AND (d.trip_id IS NULL OR d.trip_id != ?)
        ORDER BY d.dive_date_time ASC
      ''', variables: [
        Variable.withString(tripId),
        Variable.withInt(startMs),
        Variable.withInt(endMs),
        Variable.withString(diverId),
        Variable.withString(tripId),
      ]).get();

      if (rows.isEmpty) return [];

      // Load full dive objects
      final diveRepository = DiveRepository();
      final diveIds = rows.map((r) => r.data['dive_id'] as String).toList();
      final dives = await diveRepository.getDivesByIds(diveIds);

      // Build a map for quick lookup
      final diveMap = {for (final d in dives) d.id: d};

      // Build candidates, preserving order from query
      final candidates = <DiveCandidate>[];
      for (final row in rows) {
        final diveId = row.data['dive_id'] as String;
        final dive = diveMap[diveId];
        if (dive == null) continue;

        candidates.add(DiveCandidate(
          dive: dive,
          currentTripId: row.data['other_trip_id'] as String?,
          currentTripName: row.data['other_trip_name'] as String?,
        ));
      }

      _log.info('Found ${candidates.length} candidate dives');
      return candidates;
    } catch (e, stackTrace) {
      _log.error('Failed to find candidate dives', e, stackTrace);
      rethrow;
    }
  }
```

**Step 4: Run test to verify it passes**

Run: `flutter test test/features/trips/data/repositories/trip_repository_dive_scan_test.dart`
Expected: PASS (4 tests)

**Step 5: Commit**

```bash
git add lib/features/trips/data/repositories/trip_repository.dart lib/features/trips/domain/entities/dive_candidate.dart test/features/trips/data/repositories/trip_repository_dive_scan_test.dart
git commit -m "feat: add findCandidateDivesForTrip to TripRepository"
```

---

## Task 3: Repository — assignDivesToTrip (batch)

**Files:**
- Modify: `lib/features/trips/data/repositories/trip_repository.dart`
- Test: `test/features/trips/data/repositories/trip_repository_dive_scan_test.dart` (add tests)

**Step 1: Write the failing test**

Add to the existing test file:

```dart
  group('assignDivesToTrip', () {
    test('batch assigns multiple dives to a trip', () async {
      final trip = await repository.createTrip(Trip(
        id: '',
        name: 'Batch Trip',
        startDate: DateTime(2026, 3, 1),
        endDate: DateTime(2026, 3, 7),
        diverId: 'diver-1',
        tripType: TripType.shore,
        notes: '',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));

      final db = DatabaseService.instance.database;
      final now = DateTime.now().millisecondsSinceEpoch;
      for (final id in ['d1', 'd2', 'd3']) {
        await db.customInsert(
          'INSERT INTO dives (id, diver_id, dive_date_time, notes, dive_type_id, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?)',
          variables: [
            Variable.withString(id),
            Variable.withString('diver-1'),
            Variable.withInt(DateTime(2026, 3, 3).millisecondsSinceEpoch),
            Variable.withString(''),
            Variable.withString(''),
            Variable.withInt(now),
            Variable.withInt(now),
          ],
        );
      }

      await repository.assignDivesToTrip(['d1', 'd2', 'd3'], trip.id);

      // Verify all dives now have trip_id set
      for (final id in ['d1', 'd2', 'd3']) {
        final result = await db.customSelect(
          'SELECT trip_id FROM dives WHERE id = ?',
          variables: [Variable.withString(id)],
        ).getSingle();
        expect(result.data['trip_id'], trip.id);
      }
    });

    test('handles empty list gracefully', () async {
      // Should not throw
      await repository.assignDivesToTrip([], 'any-trip-id');
    });
  });
```

**Step 2: Run test to verify it fails**

Run: `flutter test test/features/trips/data/repositories/trip_repository_dive_scan_test.dart`
Expected: FAIL — `assignDivesToTrip` not found

**Step 3: Write minimal implementation**

Add to `TripRepository` after `findCandidateDivesForTrip`:

```dart
  /// Batch assign multiple dives to a trip in a single transaction.
  Future<void> assignDivesToTrip(List<String> diveIds, String tripId) async {
    if (diveIds.isEmpty) return;

    try {
      _log.info('Batch assigning ${diveIds.length} dives to trip $tripId');
      final now = DateTime.now().millisecondsSinceEpoch;

      await _db.transaction(() async {
        for (final diveId in diveIds) {
          await _db.customUpdate(
            'UPDATE dives SET trip_id = ?, updated_at = ? WHERE id = ?',
            variables: [
              Variable.withString(tripId),
              Variable.withInt(now),
              Variable.withString(diveId),
            ],
            updates: {_db.dives},
          );
        }
      });

      // Mark dives as pending sync
      for (final diveId in diveIds) {
        await _syncRepository.markRecordPending(
          entityType: 'dives',
          recordId: diveId,
          localUpdatedAt: now,
        );
      }
      SyncEventBus.notifyLocalChange();

      _log.info('Batch assigned ${diveIds.length} dives to trip $tripId');
    } catch (e, stackTrace) {
      _log.error('Failed to batch assign dives to trip', e, stackTrace);
      rethrow;
    }
  }
```

**Step 4: Run test to verify it passes**

Run: `flutter test test/features/trips/data/repositories/trip_repository_dive_scan_test.dart`
Expected: PASS (6 tests)

**Step 5: Commit**

```bash
git add lib/features/trips/data/repositories/trip_repository.dart test/features/trips/data/repositories/trip_repository_dive_scan_test.dart
git commit -m "feat: add batch assignDivesToTrip to TripRepository"
```

---

## Task 4: Localization Strings

**Files:**
- Modify: `lib/l10n/arb/app_en.arb`

**Step 1: Add localization keys**

Add after the existing `trips_detail_scan_*` keys (around line 6976):

```json
  "trips_diveScan_title": "Add Dives to Trip",
  "trips_diveScan_subtitle": "{count} dives found in date range",
  "@trips_diveScan_subtitle": {
    "placeholders": {
      "count": {"type": "int"}
    }
  },
  "trips_diveScan_groupUnassigned": "Unassigned ({count})",
  "@trips_diveScan_groupUnassigned": {
    "placeholders": {
      "count": {"type": "int"}
    }
  },
  "trips_diveScan_groupOtherTrips": "On other trips ({count})",
  "@trips_diveScan_groupOtherTrips": {
    "placeholders": {
      "count": {"type": "int"}
    }
  },
  "trips_diveScan_currentTrip": "Currently on: {tripName}",
  "@trips_diveScan_currentTrip": {
    "placeholders": {
      "tripName": {"type": "String"}
    }
  },
  "trips_diveScan_addButton": "Add {count} Dives",
  "@trips_diveScan_addButton": {
    "placeholders": {
      "count": {"type": "int"}
    }
  },
  "trips_diveScan_cancel": "Cancel",
  "trips_diveScan_noMatches": "No matching dives found",
  "trips_diveScan_added": "Added {count} dives to trip",
  "@trips_diveScan_added": {
    "placeholders": {
      "count": {"type": "int"}
    }
  },
  "trips_diveScan_error": "Error scanning for dives: {error}",
  "@trips_diveScan_error": {
    "placeholders": {
      "error": {"type": "String"}
    }
  },
  "trips_diveScan_findButton": "Find matching dives",
  "trips_diveScan_unknownSite": "Unknown Site",
  "trips_diveScan_selectAll": "Select all",
  "trips_diveScan_deselectAll": "Deselect all",
```

**Step 2: Run codegen to regenerate localizations**

Run: `flutter gen-l10n`
Expected: Regenerated `app_localizations.dart` and `app_localizations_en.dart`

**Step 3: Verify build**

Run: `flutter analyze lib/l10n/`
Expected: No errors

**Step 4: Commit**

```bash
git add lib/l10n/
git commit -m "feat: add localization strings for trip dive scanning"
```

---

## Task 5: DiveAssignmentDialog Widget

**Files:**
- Create: `lib/features/trips/presentation/widgets/dive_assignment_dialog.dart`
- Test: `test/features/trips/presentation/widgets/dive_assignment_dialog_test.dart`

**Step 1: Write the failing test**

```dart
// test/features/trips/presentation/widgets/dive_assignment_dialog_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/trips/domain/entities/dive_candidate.dart';
import 'package:submersion/features/trips/presentation/widgets/dive_assignment_dialog.dart';
import '../../../../helpers/test_app.dart';

void main() {
  final unassignedDive = Dive(
    id: 'dive-1',
    diveNumber: 42,
    dateTime: DateTime(2026, 3, 5),
    notes: '',
    tanks: const [],
    profile: const [],
    equipment: const [],
    photoIds: const [],
    sightings: const [],
    diveTypeId: '',
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );

  final otherTripDive = Dive(
    id: 'dive-2',
    diveNumber: 40,
    dateTime: DateTime(2026, 3, 4),
    notes: '',
    tanks: const [],
    profile: const [],
    equipment: const [],
    photoIds: const [],
    sightings: const [],
    diveTypeId: '',
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );

  final candidates = [
    DiveCandidate(dive: unassignedDive),
    DiveCandidate(
      dive: otherTripDive,
      currentTripId: 'trip-99',
      currentTripName: 'Sharm Weekend',
    ),
  ];

  group('DiveAssignmentDialog', () {
    testWidgets('shows unassigned dives pre-checked', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => showDiveAssignmentDialog(
                    context: context,
                    candidates: candidates,
                  ),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Unassigned dive should be present
      expect(find.text('#42'), findsOneWidget);
      // Other-trip dive should show trip name
      expect(find.textContaining('Sharm Weekend'), findsOneWidget);
    });

    testWidgets('returns selected dive IDs on confirm', (tester) async {
      List<String>? result;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () async {
                    result = await showDiveAssignmentDialog(
                      context: context,
                      candidates: candidates,
                    );
                  },
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Tap the add button (only unassigned pre-checked = 1 dive)
      await tester.tap(find.textContaining('Add'));
      await tester.pumpAndSettle();

      expect(result, isNotNull);
      expect(result, contains('dive-1'));
      expect(result, isNot(contains('dive-2')));
    });

    testWidgets('returns null on cancel', (tester) async {
      List<String>? result;
      bool callbackInvoked = false;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () async {
                    result = await showDiveAssignmentDialog(
                      context: context,
                      candidates: candidates,
                    );
                    callbackInvoked = true;
                  },
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.tap(find.textContaining('Cancel'));
      await tester.pumpAndSettle();

      expect(callbackInvoked, isTrue);
      expect(result, isNull);
    });
  });
}
```

**Step 2: Run test to verify it fails**

Run: `flutter test test/features/trips/presentation/widgets/dive_assignment_dialog_test.dart`
Expected: FAIL — cannot resolve `showDiveAssignmentDialog` import

**Step 3: Write minimal implementation**

```dart
// lib/features/trips/presentation/widgets/dive_assignment_dialog.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:submersion/features/trips/domain/entities/dive_candidate.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Show the dive assignment dialog. Returns a list of selected dive IDs,
/// or null if the user cancelled.
Future<List<String>?> showDiveAssignmentDialog({
  required BuildContext context,
  required List<DiveCandidate> candidates,
}) {
  return showModalBottomSheet<List<String>>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => DiveAssignmentDialog(candidates: candidates),
  );
}

class DiveAssignmentDialog extends StatefulWidget {
  final List<DiveCandidate> candidates;

  const DiveAssignmentDialog({super.key, required this.candidates});

  @override
  State<DiveAssignmentDialog> createState() => _DiveAssignmentDialogState();
}

class _DiveAssignmentDialogState extends State<DiveAssignmentDialog> {
  late final Set<String> _selectedIds;

  List<DiveCandidate> get _unassigned =>
      widget.candidates.where((c) => c.isUnassigned).toList();

  List<DiveCandidate> get _otherTrip =>
      widget.candidates.where((c) => !c.isUnassigned).toList();

  @override
  void initState() {
    super.initState();
    // Pre-select unassigned dives
    _selectedIds = _unassigned.map((c) => c.dive.id).toSet();
  }

  void _toggleAll(List<DiveCandidate> group, bool select) {
    setState(() {
      for (final c in group) {
        if (select) {
          _selectedIds.add(c.dive.id);
        } else {
          _selectedIds.remove(c.dive.id);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final dateFormat = DateFormat.MMMd();

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => Column(
        children: [
          // Handle bar
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 4),
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  l10n.trips_diveScan_title,
                  style: theme.textTheme.titleLarge,
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                l10n.trips_diveScan_subtitle(widget.candidates.length),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Scrollable content
          Expanded(
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                if (_unassigned.isNotEmpty) ...[
                  _buildGroupHeader(
                    l10n.trips_diveScan_groupUnassigned(_unassigned.length),
                    _unassigned,
                    _unassigned.every((c) => _selectedIds.contains(c.dive.id)),
                  ),
                  ..._unassigned.map((c) => _buildDiveRow(c, dateFormat, theme)),
                  const SizedBox(height: 16),
                ],
                if (_otherTrip.isNotEmpty) ...[
                  _buildGroupHeader(
                    l10n.trips_diveScan_groupOtherTrips(_otherTrip.length),
                    _otherTrip,
                    _otherTrip.every((c) => _selectedIds.contains(c.dive.id)),
                  ),
                  ..._otherTrip.map((c) => _buildDiveRow(c, dateFormat, theme)),
                ],
              ],
            ),
          ),
          // Action buttons
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(l10n.trips_diveScan_cancel),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _selectedIds.isEmpty
                        ? null
                        : () => Navigator.of(context).pop(
                            _selectedIds.toList(),
                          ),
                    child: Text(
                      l10n.trips_diveScan_addButton(_selectedIds.length),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupHeader(
    String label,
    List<DiveCandidate> group,
    bool allSelected,
  ) {
    return Row(
      children: [
        Checkbox(
          value: allSelected,
          onChanged: (val) => _toggleAll(group, val ?? false),
        ),
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDiveRow(
    DiveCandidate candidate,
    DateFormat dateFormat,
    ThemeData theme,
  ) {
    final dive = candidate.dive;
    final isSelected = _selectedIds.contains(dive.id);

    return InkWell(
      onTap: () {
        setState(() {
          if (isSelected) {
            _selectedIds.remove(dive.id);
          } else {
            _selectedIds.add(dive.id);
          }
        });
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Checkbox(
              value: isSelected,
              onChanged: (val) {
                setState(() {
                  if (val == true) {
                    _selectedIds.add(dive.id);
                  } else {
                    _selectedIds.remove(dive.id);
                  }
                });
              },
            ),
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: Text(
                '#${dive.diveNumber ?? '-'}',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    dive.site?.name ??
                        context.l10n.trips_diveScan_unknownSite,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Row(
                    children: [
                      Text(
                        dateFormat.format(dive.dateTime),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      if (dive.maxDepth != null) ...[
                        const SizedBox(width: 8),
                        Text(
                          '${dive.maxDepth!.toStringAsFixed(0)}m',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (!candidate.isUnassigned &&
                      candidate.currentTripName != null)
                    Text(
                      context.l10n.trips_diveScan_currentTrip(
                        candidate.currentTripName!,
                      ),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.tertiary,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

**Step 4: Run test to verify it passes**

Run: `flutter test test/features/trips/presentation/widgets/dive_assignment_dialog_test.dart`
Expected: PASS (3 tests)

**Step 5: Format and commit**

```bash
dart format lib/features/trips/presentation/widgets/dive_assignment_dialog.dart test/features/trips/presentation/widgets/dive_assignment_dialog_test.dart
git add lib/features/trips/presentation/widgets/dive_assignment_dialog.dart test/features/trips/presentation/widgets/dive_assignment_dialog_test.dart
git commit -m "feat: add DiveAssignmentDialog for trip dive scanning"
```

---

## Task 6: TripListNotifier — assignDivesToTrip + Provider Invalidation

**Files:**
- Modify: `lib/features/trips/presentation/providers/trip_providers.dart` (add method to `TripListNotifier`, line ~323)

**Step 1: Add batch assignment method to TripListNotifier**

Add after `removeDiveFromTrip` method (line 323):

```dart
  Future<void> assignDivesToTrip(
    List<String> diveIds,
    String tripId, {
    Set<String>? oldTripIds,
  }) async {
    await _repository.assignDivesToTrip(diveIds, tripId);
    await refresh();
    _ref.invalidate(tripWithStatsProvider(tripId));
    _ref.invalidate(diveIdsForTripProvider(tripId));
    _ref.invalidate(divesForTripProvider(tripId));

    // Invalidate old trip providers if dives were reassigned
    if (oldTripIds != null) {
      for (final oldTripId in oldTripIds) {
        _ref.invalidate(tripWithStatsProvider(oldTripId));
        _ref.invalidate(diveIdsForTripProvider(oldTripId));
        _ref.invalidate(divesForTripProvider(oldTripId));
      }
    }
  }
```

**Step 2: Run existing tests**

Run: `flutter test test/features/trips/`
Expected: PASS (no regression)

**Step 3: Commit**

```bash
git add lib/features/trips/presentation/providers/trip_providers.dart
git commit -m "feat: add batch assignDivesToTrip to TripListNotifier"
```

---

## Task 7: Trip Edit Page — Post-Save Scan Trigger

**Files:**
- Modify: `lib/features/trips/presentation/pages/trip_edit_page.dart` (modify `_saveTrip` method, lines 700-815)

**Step 1: Add imports**

Add at top of file:

```dart
import 'package:submersion/features/trips/domain/entities/dive_candidate.dart';
import 'package:submersion/features/trips/presentation/widgets/dive_assignment_dialog.dart';
```

**Step 2: Store original dates for comparison**

The `_originalTrip` is already stored (line 57). We compare `_originalTrip?.startDate`/`endDate` with the new values to detect date changes.

**Step 3: Modify _saveTrip to trigger scan after save**

Replace the success block in `_saveTrip` (after line 786, the liveaboard cleanup block) with:

```dart
      // Scan for candidate dives (on create, or when dates changed on edit)
      final datesChanged = !isEditing ||
          _originalTrip?.startDate != _startDate ||
          _originalTrip?.endDate != _endDate;

      if (mounted && datesChanged && trip.diverId != null) {
        final candidates = await ref
            .read(tripRepositoryProvider)
            .findCandidateDivesForTrip(
              tripId: savedId,
              startDate: _startDate,
              endDate: _endDate,
              diverId: trip.diverId!,
            );

        if (candidates.isNotEmpty && mounted) {
          final selectedIds = await showDiveAssignmentDialog(
            context: context,
            candidates: candidates,
          );

          if (selectedIds != null && selectedIds.isNotEmpty && mounted) {
            // Collect old trip IDs for provider invalidation
            final oldTripIds = candidates
                .where((c) => selectedIds.contains(c.dive.id) && !c.isUnassigned)
                .map((c) => c.currentTripId!)
                .toSet();

            await ref
                .read(tripListNotifierProvider.notifier)
                .assignDivesToTrip(selectedIds, savedId, oldTripIds: oldTripIds);

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    context.l10n.trips_diveScan_added(selectedIds.length),
                  ),
                ),
              );
            }
          }
        }
      }

      if (mounted) {
        if (widget.embedded) {
          widget.onSaved?.call(savedId);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                isEditing
                    ? context.l10n.trips_edit_snackBar_updated
                    : context.l10n.trips_edit_snackBar_added,
              ),
            ),
          );
          context.pop();
        }
      }
```

This replaces the block from line 788 to line 814 in the current code.

**Step 4: Verify build**

Run: `flutter analyze lib/features/trips/presentation/pages/trip_edit_page.dart`
Expected: No errors

**Step 5: Commit**

```bash
git add lib/features/trips/presentation/pages/trip_edit_page.dart
git commit -m "feat: trigger dive scan after trip save"
```

---

## Task 8: Trip Overview Tab — Manual Scan Button

**Files:**
- Modify: `lib/features/trips/presentation/widgets/trip_overview_tab.dart` (add button in dives section header)

**Step 1: Add imports**

Add at top of file:

```dart
import 'package:submersion/features/trips/domain/entities/dive_candidate.dart';
import 'package:submersion/features/trips/presentation/widgets/dive_assignment_dialog.dart';
```

**Step 2: Add scan button to dives section header**

In the `_buildDivesSection` method, add an icon button in the `Row` at line 381-405, between the title and the "View All" button. Insert after the title `Text` widget:

```dart
                IconButton(
                  icon: const Icon(Icons.playlist_add, size: 20),
                  visualDensity: VisualDensity.compact,
                  tooltip: context.l10n.trips_diveScan_findButton,
                  onPressed: () => _scanForDives(context, ref),
                ),
```

**Step 3: Add the _scanForDives method**

Add a new method to `TripOverviewTab`:

```dart
  Future<void> _scanForDives(BuildContext context, WidgetRef ref) async {
    final trip = tripWithStats.trip;
    if (trip.diverId == null) return;

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final candidates = await ref
          .read(tripRepositoryProvider)
          .findCandidateDivesForTrip(
            tripId: trip.id,
            startDate: trip.startDate,
            endDate: trip.endDate,
            diverId: trip.diverId!,
          );

      if (!context.mounted) return;
      Navigator.of(context).pop(); // Dismiss loading

      if (candidates.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.trips_diveScan_noMatches),
          ),
        );
        return;
      }

      final selectedIds = await showDiveAssignmentDialog(
        context: context,
        candidates: candidates,
      );

      if (selectedIds == null || selectedIds.isEmpty || !context.mounted) return;

      // Collect old trip IDs for invalidation
      final oldTripIds = candidates
          .where((c) => selectedIds.contains(c.dive.id) && !c.isUnassigned)
          .map((c) => c.currentTripId!)
          .toSet();

      await ref
          .read(tripListNotifierProvider.notifier)
          .assignDivesToTrip(selectedIds, trip.id, oldTripIds: oldTripIds);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.l10n.trips_diveScan_added(selectedIds.length),
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) Navigator.of(context).pop();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.trips_diveScan_error('$e')),
          ),
        );
      }
    }
  }
```

**Step 4: Verify build and format**

Run: `dart format lib/features/trips/presentation/widgets/trip_overview_tab.dart && flutter analyze lib/features/trips/presentation/widgets/trip_overview_tab.dart`
Expected: No errors

**Step 5: Commit**

```bash
git add lib/features/trips/presentation/widgets/trip_overview_tab.dart
git commit -m "feat: add manual 'Find matching dives' button on trip detail"
```

---

## Task 9: Final Verification

**Step 1: Run all trip tests**

Run: `flutter test test/features/trips/`
Expected: All PASS

**Step 2: Run full test suite**

Run: `flutter test`
Expected: All PASS

**Step 3: Run analyze**

Run: `flutter analyze`
Expected: No issues

**Step 4: Run format check**

Run: `dart format --set-exit-if-changed lib/ test/`
Expected: No changes needed

**Step 5: Manual smoke test (if possible)**

Run: `flutter run -d macos`

1. Create a new trip with date range covering existing dives -> dialog should appear
2. Accept defaults -> dives assigned
3. Open trip detail -> verify dives appear
4. Tap "Find matching dives" button -> should show "No matching dives found" (already assigned)
5. Create another trip overlapping dates -> dialog should show dives "On other trips"

---

## Summary

| Task | Description | New Files | Modified Files |
|------|-------------|-----------|----------------|
| 1 | DiveCandidate entity | 2 | 0 |
| 2 | findCandidateDivesForTrip | 0 | 1 (+test) |
| 3 | assignDivesToTrip batch | 0 | 1 (+test) |
| 4 | Localization strings | 0 | 1 |
| 5 | DiveAssignmentDialog widget | 2 | 0 |
| 6 | TripListNotifier batch method | 0 | 1 |
| 7 | Post-save scan trigger | 0 | 1 |
| 8 | Manual scan button | 0 | 1 |
| 9 | Final verification | 0 | 0 |
