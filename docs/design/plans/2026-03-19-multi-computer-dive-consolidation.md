# Multi-Computer Dive Consolidation — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Allow divers to import data from multiple dive computers for the same dive, consolidate them into a single dive record, and visualize/compare each computer's data independently.

**Architecture:** New `DiveComputerData` Drift table stores per-computer metadata snapshots (only populated for multi-computer dives, back-filled on first consolidation). Extend `ImportDuplicateChecker` with a "Consolidate" resolution option. Add computer toggle checkboxes to the profile chart. Add a "Computers" section to dive detail with "Set as primary" and "Unlink" actions. Post-import merge from dive detail screen. All storage in SI units per existing conventions.

**Tech Stack:** Flutter, Drift ORM (SQLite), Riverpod, fl_chart, Mockito for tests

**Spec:** `docs/superpowers/specs/2026-03-19-multi-computer-dive-consolidation-design.md`

---

### Task 1: Add `dive_computer_data` table and migration

**Files:**
- Modify: `lib/core/database/database.dart` (table definition at ~line 900, migration at ~line 1537, schema version at line 1187)

- [ ] **Step 1: Define the `DiveComputerData` table class**

Add after the `DiveComputers` table definition (around line 902):

```dart
/// Per-computer metadata snapshots for multi-computer dives.
/// Only populated when a dive has data from multiple computers.
class DiveComputerData extends Table {
  TextColumn get id => text()();
  TextColumn get diveId =>
      text().references(Dives, #id, onDelete: KeyAction.cascade)();
  TextColumn get computerId =>
      text().nullable().references(DiveComputers, #id)();
  BoolColumn get isPrimary =>
      boolean().withDefault(const Constant(false))();
  TextColumn get computerModel => text().nullable()();
  TextColumn get computerSerial => text().nullable()();
  TextColumn get sourceFormat => text().nullable()();
  RealColumn get maxDepth => real().nullable()();
  RealColumn get avgDepth => real().nullable()();
  IntColumn get duration => integer().nullable()();
  RealColumn get waterTemp => real().nullable()();
  DateTimeColumn get entryTime => dateTime().nullable()();
  DateTimeColumn get exitTime => dateTime().nullable()();
  RealColumn get maxAscentRate => real().nullable()();
  RealColumn get maxDescentRate => real().nullable()();
  IntColumn get surfaceInterval => integer().nullable()();
  RealColumn get cns => real().nullable()();
  RealColumn get otu => real().nullable()();
  TextColumn get decoAlgorithm => text().nullable()();
  IntColumn get gradientFactorLow => integer().nullable()();
  IntColumn get gradientFactorHigh => integer().nullable()();
  DateTimeColumn get importedAt => dateTime()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
```

- [ ] **Step 2: Add the table to the `@DriftDatabase` annotation**

Find the `@DriftDatabase(tables: [...])` annotation and add `DiveComputerData` to the list.

- [ ] **Step 3: Increment schema version and add migration**

Change `currentSchemaVersion` from `50` to `51`.

Add migration block at the end of `onUpgrade`:

```dart
if (from < 51) {
  await customStatement('''
    CREATE TABLE IF NOT EXISTS dive_computer_data (
      id TEXT NOT NULL PRIMARY KEY,
      dive_id TEXT NOT NULL REFERENCES dives(id) ON DELETE CASCADE,
      computer_id TEXT REFERENCES dive_computers(id),
      is_primary INTEGER NOT NULL DEFAULT 0,
      computer_model TEXT,
      computer_serial TEXT,
      source_format TEXT,
      max_depth REAL,
      avg_depth REAL,
      duration INTEGER,
      water_temp REAL,
      entry_time INTEGER,
      exit_time INTEGER,
      max_ascent_rate REAL,
      max_descent_rate REAL,
      surface_interval INTEGER,
      cns REAL,
      otu REAL,
      deco_algorithm TEXT,
      gradient_factor_low INTEGER,
      gradient_factor_high INTEGER,
      imported_at INTEGER NOT NULL,
      created_at INTEGER NOT NULL
    )
  ''');
  await customStatement('''
    CREATE INDEX IF NOT EXISTS idx_dive_computer_data_dive_id
    ON dive_computer_data(dive_id)
  ''');
}
```

- [ ] **Step 4: Run code generation**

Run: `dart run build_runner build --delete-conflicting-outputs`

Expected: Drift generates updated `database.g.dart` with `DiveComputerDataCompanion`, `DiveComputerDataData`, etc.

- [ ] **Step 5: Verify the app compiles**

Run: `flutter analyze`

Expected: No errors.

- [ ] **Step 6: Commit**

```bash
git add lib/core/database/database.dart lib/core/database/database.g.dart
git commit -m "feat: add dive_computer_data table for multi-computer support"
```

---

### Task 2: Create `DiveComputerReading` domain entity

**Files:**
- Create: `lib/features/dive_log/domain/entities/dive_computer_reading.dart`
- Create: `test/features/dive_log/domain/entities/dive_computer_reading_test.dart`

- [ ] **Step 1: Write the failing test for entity construction and copyWith**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_computer_reading.dart';

void main() {
  group('DiveComputerReading', () {
    test('constructs with required fields', () {
      final now = DateTime.now();
      final reading = DiveComputerReading(
        id: 'r1',
        diveId: 'd1',
        isPrimary: true,
        importedAt: now,
        createdAt: now,
      );

      expect(reading.id, 'r1');
      expect(reading.diveId, 'd1');
      expect(reading.isPrimary, true);
      expect(reading.maxDepth, isNull);
      expect(reading.computerModel, isNull);
    });

    test('constructs with all fields', () {
      final now = DateTime.now();
      final entry = DateTime(2026, 3, 19, 10, 0);
      final exit = DateTime(2026, 3, 19, 10, 42);
      final reading = DiveComputerReading(
        id: 'r1',
        diveId: 'd1',
        computerId: 'c1',
        isPrimary: true,
        computerModel: 'Shearwater Perdix',
        computerSerial: 'SN12345',
        sourceFormat: 'UDDF',
        maxDepth: 30.2,
        avgDepth: 18.4,
        duration: 2535,
        waterTemp: 26.1,
        entryTime: entry,
        exitTime: exit,
        maxAscentRate: 9.5,
        maxDescentRate: 18.0,
        surfaceInterval: 65,
        cns: 12.0,
        otu: 22.0,
        decoAlgorithm: 'Buhlmann ZHL-16C',
        gradientFactorLow: 30,
        gradientFactorHigh: 70,
        importedAt: now,
        createdAt: now,
      );

      expect(reading.computerModel, 'Shearwater Perdix');
      expect(reading.maxDepth, 30.2);
      expect(reading.duration, 2535);
      expect(reading.gradientFactorLow, 30);
    });

    test('copyWith replaces specified fields', () {
      final now = DateTime.now();
      final reading = DiveComputerReading(
        id: 'r1',
        diveId: 'd1',
        isPrimary: true,
        maxDepth: 30.2,
        computerModel: 'Shearwater Perdix',
        importedAt: now,
        createdAt: now,
      );

      final updated = reading.copyWith(
        isPrimary: false,
        maxDepth: 29.8,
      );

      expect(updated.isPrimary, false);
      expect(updated.maxDepth, 29.8);
      expect(updated.id, 'r1');
      expect(updated.computerModel, 'Shearwater Perdix');
    });

    test('copyWith preserves null fields when not specified', () {
      final now = DateTime.now();
      final reading = DiveComputerReading(
        id: 'r1',
        diveId: 'd1',
        isPrimary: true,
        importedAt: now,
        createdAt: now,
      );

      final updated = reading.copyWith(isPrimary: false);

      expect(updated.maxDepth, isNull);
      expect(updated.computerModel, isNull);
    });
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/dive_log/domain/entities/dive_computer_reading_test.dart`

Expected: FAIL — `DiveComputerReading` class not found.

- [ ] **Step 3: Implement the entity**

Create `lib/features/dive_log/domain/entities/dive_computer_reading.dart`:

```dart
import 'package:equatable/equatable.dart';

class DiveComputerReading extends Equatable {
  final String id;
  final String diveId;
  final String? computerId;
  final bool isPrimary;
  final String? computerModel;
  final String? computerSerial;
  final String? sourceFormat;
  final double? maxDepth;
  final double? avgDepth;
  final int? duration;
  final double? waterTemp;
  final DateTime? entryTime;
  final DateTime? exitTime;
  final double? maxAscentRate;
  final double? maxDescentRate;
  final int? surfaceInterval;
  final double? cns;
  final double? otu;
  final String? decoAlgorithm;
  final int? gradientFactorLow;
  final int? gradientFactorHigh;
  final DateTime importedAt;
  final DateTime createdAt;

  const DiveComputerReading({
    required this.id,
    required this.diveId,
    this.computerId,
    required this.isPrimary,
    this.computerModel,
    this.computerSerial,
    this.sourceFormat,
    this.maxDepth,
    this.avgDepth,
    this.duration,
    this.waterTemp,
    this.entryTime,
    this.exitTime,
    this.maxAscentRate,
    this.maxDescentRate,
    this.surfaceInterval,
    this.cns,
    this.otu,
    this.decoAlgorithm,
    this.gradientFactorLow,
    this.gradientFactorHigh,
    required this.importedAt,
    required this.createdAt,
  });

  /// Display name for the computer (model, or "Unknown Computer").
  String get displayName => computerModel ?? 'Unknown Computer';

  DiveComputerReading copyWith({
    String? id,
    String? diveId,
    String? computerId,
    bool? isPrimary,
    String? computerModel,
    String? computerSerial,
    String? sourceFormat,
    double? maxDepth,
    double? avgDepth,
    int? duration,
    double? waterTemp,
    DateTime? entryTime,
    DateTime? exitTime,
    double? maxAscentRate,
    double? maxDescentRate,
    int? surfaceInterval,
    double? cns,
    double? otu,
    String? decoAlgorithm,
    int? gradientFactorLow,
    int? gradientFactorHigh,
    DateTime? importedAt,
    DateTime? createdAt,
  }) {
    return DiveComputerReading(
      id: id ?? this.id,
      diveId: diveId ?? this.diveId,
      computerId: computerId ?? this.computerId,
      isPrimary: isPrimary ?? this.isPrimary,
      computerModel: computerModel ?? this.computerModel,
      computerSerial: computerSerial ?? this.computerSerial,
      sourceFormat: sourceFormat ?? this.sourceFormat,
      maxDepth: maxDepth ?? this.maxDepth,
      avgDepth: avgDepth ?? this.avgDepth,
      duration: duration ?? this.duration,
      waterTemp: waterTemp ?? this.waterTemp,
      entryTime: entryTime ?? this.entryTime,
      exitTime: exitTime ?? this.exitTime,
      maxAscentRate: maxAscentRate ?? this.maxAscentRate,
      maxDescentRate: maxDescentRate ?? this.maxDescentRate,
      surfaceInterval: surfaceInterval ?? this.surfaceInterval,
      cns: cns ?? this.cns,
      otu: otu ?? this.otu,
      decoAlgorithm: decoAlgorithm ?? this.decoAlgorithm,
      gradientFactorLow: gradientFactorLow ?? this.gradientFactorLow,
      gradientFactorHigh: gradientFactorHigh ?? this.gradientFactorHigh,
      importedAt: importedAt ?? this.importedAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props => [
    id, diveId, computerId, isPrimary,
    computerModel, computerSerial, sourceFormat,
    maxDepth, avgDepth, duration, waterTemp,
    entryTime, exitTime, maxAscentRate, maxDescentRate,
    surfaceInterval, cns, otu,
    decoAlgorithm, gradientFactorLow, gradientFactorHigh,
    importedAt, createdAt,
  ];
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/features/dive_log/domain/entities/dive_computer_reading_test.dart`

Expected: All 4 tests PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/dive_log/domain/entities/dive_computer_reading.dart test/features/dive_log/domain/entities/dive_computer_reading_test.dart
git commit -m "feat: add DiveComputerReading domain entity with tests"
```

---

### Task 3: Add repository methods for `dive_computer_data` CRUD and back-fill

**Files:**
- Modify: `lib/features/dive_log/data/repositories/dive_repository_impl.dart`
- Create: `test/features/dive_log/data/repositories/dive_computer_data_repository_test.dart`

- [ ] **Step 1: Write failing tests for CRUD and back-fill**

Create the test file with tests for:
1. `getComputerReadings(diveId)` — returns empty list for single-computer dive
2. `getComputerReadings(diveId)` — returns list for multi-computer dive
3. `saveComputerReading(reading)` — inserts a new row
4. `deleteComputerReading(id)` — removes the row
5. `backfillPrimaryComputerReading(diveId)` — extracts metadata from the `dives` record and creates a `dive_computer_data` row for the primary computer
6. `hasMultipleComputers(diveId)` — returns true/false

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_computer_reading.dart';
import 'package:drift/native.dart';
import 'package:uuid/uuid.dart';

void main() {
  late AppDatabase db;
  late DiveRepository repository;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repository = DiveRepository(db: db);
  });

  tearDown(() async {
    await db.close();
  });

  group('DiveComputerData CRUD', () {
    test('getComputerReadings returns empty for single-computer dive', () async {
      // Insert a dive with no dive_computer_data rows
      // ...setup code...
      final readings = await repository.getComputerReadings('dive1');
      expect(readings, isEmpty);
    });

    test('saveComputerReading inserts a row', () async {
      final now = DateTime.now();
      final reading = DiveComputerReading(
        id: const Uuid().v4(),
        diveId: 'dive1',
        computerId: 'comp1',
        isPrimary: false,
        computerModel: 'Garmin Descent Mk3',
        maxDepth: 29.8,
        duration: 2518,
        importedAt: now,
        createdAt: now,
      );
      await repository.saveComputerReading(reading);
      final readings = await repository.getComputerReadings('dive1');
      expect(readings, hasLength(1));
      expect(readings.first.computerModel, 'Garmin Descent Mk3');
    });

    test('backfillPrimaryComputerReading extracts from dives record', () async {
      // Create a dive with maxDepth, duration, waterTemp, etc.
      // Call backfillPrimaryComputerReading
      // Verify a dive_computer_data row was created with matching values
    });

    test('hasMultipleComputers returns false for zero rows', () async {
      final result = await repository.hasMultipleComputers('dive1');
      expect(result, false);
    });

    test('hasMultipleComputers returns true for 2+ rows', () async {
      // Insert two dive_computer_data rows for same dive
      final result = await repository.hasMultipleComputers('dive1');
      expect(result, true);
    });
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/dive_log/data/repositories/dive_computer_data_repository_test.dart`

Expected: FAIL — methods don't exist yet.

- [ ] **Step 3: Implement repository methods in `DiveRepository`**

Add these methods to `DiveRepository` in `dive_repository_impl.dart`:

```dart
/// Get all computer readings for a dive.
/// Returns empty list for single-computer dives.
Future<List<DiveComputerReading>> getComputerReadings(String diveId) async {
  final query = _db.select(_db.diveComputerData)
    ..where((t) => t.diveId.equals(diveId));
  final rows = await query.get();
  return rows.map(_mapRowToReading).toList();
}

/// Check if a dive has data from multiple computers.
Future<bool> hasMultipleComputers(String diveId) async {
  final query = _db.select(_db.diveComputerData)
    ..where((t) => t.diveId.equals(diveId));
  final rows = await query.get();
  return rows.length >= 2;
}

/// Save a computer reading to the database.
Future<void> saveComputerReading(DiveComputerReading reading) async {
  await _db.into(_db.diveComputerData).insert(
    DiveComputerDataCompanion(
      id: Value(reading.id),
      diveId: Value(reading.diveId),
      computerId: Value(reading.computerId),
      isPrimary: Value(reading.isPrimary),
      computerModel: Value(reading.computerModel),
      computerSerial: Value(reading.computerSerial),
      sourceFormat: Value(reading.sourceFormat),
      maxDepth: Value(reading.maxDepth),
      avgDepth: Value(reading.avgDepth),
      duration: Value(reading.duration),
      waterTemp: Value(reading.waterTemp),
      entryTime: Value(reading.entryTime),
      exitTime: Value(reading.exitTime),
      maxAscentRate: Value(reading.maxAscentRate),
      maxDescentRate: Value(reading.maxDescentRate),
      surfaceInterval: Value(reading.surfaceInterval),
      cns: Value(reading.cns),
      otu: Value(reading.otu),
      decoAlgorithm: Value(reading.decoAlgorithm),
      gradientFactorLow: Value(reading.gradientFactorLow),
      gradientFactorHigh: Value(reading.gradientFactorHigh),
      importedAt: Value(reading.importedAt),
      createdAt: Value(reading.createdAt),
    ),
  );
}

/// Delete a computer reading.
Future<void> deleteComputerReading(String id) async {
  await (_db.delete(_db.diveComputerData)
    ..where((t) => t.id.equals(id)))
    .go();
}

/// Back-fill a dive_computer_data row from the existing dives record.
/// Used on first consolidation to preserve the primary computer's metadata.
Future<DiveComputerReading> backfillPrimaryComputerReading(
  String diveId,
) async {
  final dive = await getDiveById(diveId);
  if (dive == null) throw StateError('Dive not found: $diveId');

  final now = DateTime.now();
  final reading = DiveComputerReading(
    id: const Uuid().v4(),
    diveId: diveId,
    computerId: dive.computerId,
    isPrimary: true,
    computerModel: dive.diveComputerModel,
    computerSerial: dive.diveComputerSerial,
    maxDepth: dive.maxDepth,
    avgDepth: dive.avgDepth,
    duration: dive.duration,
    waterTemp: dive.waterTemp,
    entryTime: dive.entryTime,
    exitTime: dive.exitTime,
    surfaceInterval: dive.surfaceInterval,
    cns: dive.cns,
    decoAlgorithm: dive.decoAlgorithm,
    gradientFactorLow: dive.gradientFactorLow,
    gradientFactorHigh: dive.gradientFactorHigh,
    importedAt: now,
    createdAt: now,
  );

  await saveComputerReading(reading);
  return reading;
}

DiveComputerReading _mapRowToReading(DiveComputerDataData row) {
  return DiveComputerReading(
    id: row.id,
    diveId: row.diveId,
    computerId: row.computerId,
    isPrimary: row.isPrimary,
    computerModel: row.computerModel,
    computerSerial: row.computerSerial,
    sourceFormat: row.sourceFormat,
    maxDepth: row.maxDepth,
    avgDepth: row.avgDepth,
    duration: row.duration,
    waterTemp: row.waterTemp,
    entryTime: row.entryTime,
    exitTime: row.exitTime,
    maxAscentRate: row.maxAscentRate,
    maxDescentRate: row.maxDescentRate,
    surfaceInterval: row.surfaceInterval,
    cns: row.cns,
    otu: row.otu,
    decoAlgorithm: row.decoAlgorithm,
    gradientFactorLow: row.gradientFactorLow,
    gradientFactorHigh: row.gradientFactorHigh,
    importedAt: row.importedAt,
    createdAt: row.createdAt,
  );
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/features/dive_log/data/repositories/dive_computer_data_repository_test.dart`

Expected: All tests PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/dive_log/data/repositories/dive_repository_impl.dart test/features/dive_log/data/repositories/dive_computer_data_repository_test.dart
git commit -m "feat: add DiveComputerData CRUD and back-fill in DiveRepository"
```

---

### Task 4: Add consolidation and merge repository methods

**Files:**
- Modify: `lib/features/dive_log/data/repositories/dive_repository_impl.dart`
- Create: `test/features/dive_log/data/repositories/dive_consolidation_test.dart`

- [ ] **Step 1: Write failing tests for consolidation operations**

Tests needed:
1. `consolidateComputer(targetDiveId, sourceDive, sourceComputerReading)` — adds secondary computer data to an existing dive
2. `mergeDives(primaryDiveId, secondaryDiveId)` — merges Dive B into Dive A (re-parents profiles, creates computer reading, deletes Dive B)
3. `unlinkComputer(diveId, computerReadingId)` — reverses consolidation by creating a new dive from detached data
4. `setPrimaryComputer(diveId, computerReadingId)` — swaps which computer is primary, updates `dives` record

```dart
group('Dive Consolidation', () {
  test('consolidateComputer adds secondary and back-fills primary', () async {
    // Create a dive with profile data
    // Call consolidateComputer with new computer data
    // Verify: 2 dive_computer_data rows exist (primary back-filled + new secondary)
    // Verify: new profile data inserted with isPrimary=false
    // Verify: dives record unchanged
  });

  test('consolidateComputer skips back-fill if already multi-computer', () async {
    // Create dive with existing dive_computer_data rows
    // Add a third computer
    // Verify: no duplicate back-fill of primary
  });

  test('mergeDives re-parents profiles and deletes source dive', () async {
    // Create two dives with profiles
    // Merge dive B into dive A
    // Verify: dive B's profiles now reference dive A with isPrimary=false
    // Verify: dive_computer_data row created from dive B's metadata
    // Verify: dive B no longer exists
  });

  test('unlinkComputer creates new dive from detached data', () async {
    // Create consolidated dive with 2 computers
    // Unlink secondary computer
    // Verify: new dive created with secondary's metadata
    // Verify: profiles re-parented to new dive
    // Verify: original dive back to single-computer (no dive_computer_data rows)
  });

  test('unlinkComputer promotes next computer if primary is unlinked', () async {
    // Create consolidated dive with 2 computers
    // Unlink the primary computer
    // Verify: secondary promoted to primary on original dive
    // Verify: dives record updated with secondary's metadata
  });

  test('setPrimaryComputer swaps flags and updates dives record', () async {
    // Create consolidated dive with 2 computers
    // Set secondary as primary
    // Verify: isPrimary flags swapped on dive_computer_data
    // Verify: dives record updated with new primary's metadata
  });
});
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/dive_log/data/repositories/dive_consolidation_test.dart`

Expected: FAIL — methods don't exist.

- [ ] **Step 3: Implement `consolidateComputer`**

```dart
/// Add a secondary computer's data to an existing dive.
/// Back-fills the primary computer's dive_computer_data row if this is
/// the first consolidation for this dive.
Future<void> consolidateComputer({
  required String targetDiveId,
  required DiveComputerReading secondaryReading,
  required List<domain.DiveProfilePoint> secondaryProfile,
}) async {
  await _db.transaction(() async {
    // Back-fill primary if first consolidation
    final existingReadings = await getComputerReadings(targetDiveId);
    if (existingReadings.isEmpty) {
      await backfillPrimaryComputerReading(targetDiveId);
    }

    // Save secondary computer reading
    await saveComputerReading(secondaryReading);

    // Insert secondary profile data with isPrimary=false
    await _db.batch((batch) {
      for (final point in secondaryProfile) {
        batch.insert(
          _db.diveProfiles,
          DiveProfilesCompanion(
            id: Value(const Uuid().v4()),
            diveId: Value(targetDiveId),
            computerId: Value(secondaryReading.computerId),
            isPrimary: const Value(false),
            timestamp: Value(point.timestamp),
            depth: Value(point.depth),
            pressure: Value(point.pressure),
            temperature: Value(point.temperature),
            heartRate: Value(point.heartRate),
            ceiling: Value(point.ceiling),
            ndl: Value(point.ndl),
            ascentRate: Value(point.ascentRate),
            cns: Value(point.cns),
            tts: Value(point.tts),
            rbt: Value(point.rbt),
            decoType: Value(point.decoType),
            setpoint: Value(point.setpoint),
            ppO2: Value(point.ppO2),
          ),
        );
      }
    });
  });

  SyncEventBus.notifyLocalChange();
}
```

- [ ] **Step 4: Implement `mergeDives`**

```dart
/// Merge Dive B into Dive A. Re-parents B's profiles to A,
/// creates a computer reading from B's metadata, then deletes B.
Future<void> mergeDives({
  required String primaryDiveId,
  required String secondaryDiveId,
}) async {
  await _db.transaction(() async {
    // Back-fill primary if first consolidation
    final existingReadings = await getComputerReadings(primaryDiveId);
    if (existingReadings.isEmpty) {
      await backfillPrimaryComputerReading(primaryDiveId);
    }

    // Get secondary dive for metadata
    final secondaryDive = await getDiveById(secondaryDiveId);
    if (secondaryDive == null) {
      throw StateError('Secondary dive not found: $secondaryDiveId');
    }

    // Create computer reading from secondary dive's metadata
    final now = DateTime.now();
    final reading = DiveComputerReading(
      id: const Uuid().v4(),
      diveId: primaryDiveId,
      computerId: secondaryDive.computerId,
      isPrimary: false,
      computerModel: secondaryDive.diveComputerModel,
      computerSerial: secondaryDive.diveComputerSerial,
      maxDepth: secondaryDive.maxDepth,
      avgDepth: secondaryDive.avgDepth,
      duration: secondaryDive.duration,
      waterTemp: secondaryDive.waterTemp,
      entryTime: secondaryDive.entryTime,
      exitTime: secondaryDive.exitTime,
      surfaceInterval: secondaryDive.surfaceInterval,
      cns: secondaryDive.cns,
      decoAlgorithm: secondaryDive.decoAlgorithm,
      gradientFactorLow: secondaryDive.gradientFactorLow,
      gradientFactorHigh: secondaryDive.gradientFactorHigh,
      importedAt: now,
      createdAt: now,
    );
    await saveComputerReading(reading);

    // Re-parent secondary dive's profiles to primary dive
    await (_db.update(_db.diveProfiles)
      ..where((t) => t.diveId.equals(secondaryDiveId)))
      .write(DiveProfilesCompanion(
        diveId: Value(primaryDiveId),
        isPrimary: const Value(false),
      ));

    // Delete the secondary dive (cascade deletes tanks, equipment, etc.)
    await (_db.delete(_db.dives)
      ..where((t) => t.id.equals(secondaryDiveId)))
      .go();
  });

  SyncEventBus.notifyLocalChange();
}
```

- [ ] **Step 5: Implement `unlinkComputer`**

```dart
/// Unlink a computer from a consolidated dive by creating a new standalone dive.
Future<String> unlinkComputer({
  required String diveId,
  required String computerReadingId,
}) async {
  late String newDiveId;

  await _db.transaction(() async {
    final reading = (await getComputerReadings(diveId))
        .firstWhere((r) => r.id == computerReadingId);

    newDiveId = const Uuid().v4();
    final now = DateTime.now();

    // Create new dive from the computer reading's metadata
    await _db.into(_db.dives).insert(
      DivesCompanion(
        id: Value(newDiveId),
        diveDateTime: Value(
          (reading.entryTime ?? now).millisecondsSinceEpoch,
        ),
        entryTime: Value(reading.entryTime),
        exitTime: Value(reading.exitTime),
        maxDepth: Value(reading.maxDepth),
        avgDepth: Value(reading.avgDepth),
        duration: Value(reading.duration),
        waterTemp: Value(reading.waterTemp),
        diveComputerModel: Value(reading.computerModel),
        diveComputerSerial: Value(reading.computerSerial),
        computerId: Value(reading.computerId),
        surfaceInterval: Value(reading.surfaceInterval),
        decoAlgorithm: Value(reading.decoAlgorithm),
        gradientFactorLow: Value(reading.gradientFactorLow),
        gradientFactorHigh: Value(reading.gradientFactorHigh),
        createdAt: Value(now.millisecondsSinceEpoch),
        updatedAt: Value(now.millisecondsSinceEpoch),
      ),
    );

    // Re-parent this computer's profiles to the new dive
    await (_db.update(_db.diveProfiles)
      ..where((t) =>
          t.diveId.equals(diveId) &
          t.computerId.equals(reading.computerId ?? '')))
      .write(DiveProfilesCompanion(
        diveId: Value(newDiveId),
        isPrimary: const Value(true),
      ));

    // Delete this computer's reading from original dive
    await deleteComputerReading(computerReadingId);

    // If unlinking the primary, promote next computer
    if (reading.isPrimary) {
      final remaining = await getComputerReadings(diveId);
      if (remaining.isNotEmpty) {
        await setPrimaryComputer(
          diveId: diveId,
          computerReadingId: remaining.first.id,
        );
      }
    }

    // If only one computer remains, clean up dive_computer_data
    final remaining = await getComputerReadings(diveId);
    if (remaining.length == 1) {
      await deleteComputerReading(remaining.first.id);
    }
  });

  SyncEventBus.notifyLocalChange();
  return newDiveId;
}
```

- [ ] **Step 6: Implement `setPrimaryComputer`**

```dart
/// Set a different computer as the primary for a dive.
/// Updates dive_computer_data flags and the dives record.
Future<void> setPrimaryComputer({
  required String diveId,
  required String computerReadingId,
}) async {
  await _db.transaction(() async {
    // Demote all to non-primary
    await (_db.update(_db.diveComputerData)
      ..where((t) => t.diveId.equals(diveId)))
      .write(const DiveComputerDataCompanion(
        isPrimary: Value(false),
      ));

    // Promote the selected one
    await (_db.update(_db.diveComputerData)
      ..where((t) => t.id.equals(computerReadingId)))
      .write(const DiveComputerDataCompanion(
        isPrimary: Value(true),
      ));

    // Update the dives record with the new primary's metadata
    final reading = (await getComputerReadings(diveId))
        .firstWhere((r) => r.id == computerReadingId);

    await (_db.update(_db.dives)
      ..where((t) => t.id.equals(diveId)))
      .write(DivesCompanion(
        maxDepth: Value(reading.maxDepth),
        avgDepth: Value(reading.avgDepth),
        duration: Value(reading.duration),
        waterTemp: Value(reading.waterTemp),
        entryTime: Value(reading.entryTime),
        exitTime: Value(reading.exitTime),
        diveComputerModel: Value(reading.computerModel),
        diveComputerSerial: Value(reading.computerSerial),
        computerId: Value(reading.computerId),
        surfaceInterval: Value(reading.surfaceInterval),
        decoAlgorithm: Value(reading.decoAlgorithm),
        gradientFactorLow: Value(reading.gradientFactorLow),
        gradientFactorHigh: Value(reading.gradientFactorHigh),
        updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
      ));

    // Also swap isPrimary on dive_profiles for this dive
    // Demote all profiles
    await (_db.update(_db.diveProfiles)
      ..where((t) => t.diveId.equals(diveId)))
      .write(const DiveProfilesCompanion(isPrimary: Value(false)));

    // Promote the new primary computer's profiles
    if (reading.computerId != null) {
      await (_db.update(_db.diveProfiles)
        ..where((t) =>
            t.diveId.equals(diveId) &
            t.computerId.equals(reading.computerId!)))
        .write(const DiveProfilesCompanion(isPrimary: Value(true)));
    }
  });

  SyncEventBus.notifyLocalChange();
}
```

- [ ] **Step 7: Run all tests to verify they pass**

Run: `flutter test test/features/dive_log/data/repositories/dive_consolidation_test.dart`

Expected: All tests PASS.

- [ ] **Step 8: Commit**

```bash
git add lib/features/dive_log/data/repositories/dive_repository_impl.dart test/features/dive_log/data/repositories/dive_consolidation_test.dart
git commit -m "feat: add consolidation, merge, unlink, and set-primary repository methods"
```

---

### Task 5: Add Riverpod providers for computer readings

**Files:**
- Modify: `lib/features/dive_log/presentation/providers/dive_providers.dart`

- [ ] **Step 1: Add providers**

```dart
/// Provider to load computer readings for a dive.
/// Returns empty list for single-computer dives.
final diveComputerReadingsProvider =
    FutureProvider.family<List<DiveComputerReading>, String>((
  ref,
  diveId,
) async {
  final repository = ref.watch(diveRepositoryProvider);
  return repository.getComputerReadings(diveId);
});

/// Provider to check if a dive has multiple computers.
final isMultiComputerDiveProvider =
    FutureProvider.family<bool, String>((
  ref,
  diveId,
) async {
  final repository = ref.watch(diveRepositoryProvider);
  return repository.hasMultipleComputers(diveId);
});
```

- [ ] **Step 2: Run analysis to verify compilation**

Run: `flutter analyze`

Expected: No errors.

- [ ] **Step 3: Commit**

```bash
git add lib/features/dive_log/presentation/providers/dive_providers.dart
git commit -m "feat: add diveComputerReadingsProvider and isMultiComputerDiveProvider"
```

---

### Task 6: Extend import duplicate checker with "Consolidate" resolution

**Files:**
- Modify: `lib/features/universal_import/data/services/import_duplicate_checker.dart`
- Modify: `lib/features/universal_import/data/models/import_enums.dart` (or wherever `DuplicateResolution` enum lives)

- [ ] **Step 1: Find and read the current duplicate resolution enum/model**

Search for the resolution enum used in the import UI. Look in `import_enums.dart` or the duplicate checker file for values like `skip`, `replace`, `importAsNew`.

- [ ] **Step 2: Add `consolidate` to the resolution enum**

```dart
enum DuplicateResolution {
  skip,
  replace,
  importAsNew,
  consolidate, // NEW: merge as additional computer data
}
```

- [ ] **Step 3: Update the import UI to show the "Consolidate" option**

Find the duplicate resolution dialog/widget in the import UI flow. When a `DiveMatchResult` has `isProbable` or `isHighConfidence`, add a "Consolidate as additional computer" button alongside the existing Skip/Replace/Import as New options.

The exact file will be in `lib/features/universal_import/presentation/` — look for a widget that handles duplicate resolution display.

- [ ] **Step 4: Handle the `consolidate` resolution in the import pipeline**

When the user chooses `consolidate`, instead of creating a new dive or skipping, call `repository.consolidateComputer()` with:
- `targetDiveId`: the matched existing dive's ID
- `secondaryReading`: a `DiveComputerReading` built from the imported dive's metadata
- `secondaryProfile`: the imported dive's profile data

- [ ] **Step 5: Write a test verifying the consolidation path**

```dart
test('consolidate resolution adds computer data to existing dive', () async {
  // Set up existing dive
  // Import a file that matches
  // Choose consolidate resolution
  // Verify: existing dive now has 2 computer readings
  // Verify: existing dive's dives record unchanged
  // Verify: new profile data added with isPrimary=false
});
```

- [ ] **Step 6: Run tests**

Run: `flutter test test/features/universal_import/`

Expected: All tests PASS.

- [ ] **Step 7: Commit**

```bash
git add lib/features/universal_import/ test/features/universal_import/
git commit -m "feat: add 'Consolidate' resolution to import duplicate checker"
```

---

### Task 7: Add "Computers" section to dive detail page

**Files:**
- Create: `lib/features/dive_log/presentation/widgets/dive_computers_section.dart`
- Modify: `lib/features/dive_log/presentation/pages/dive_detail_page.dart`
- Create: `test/features/dive_log/presentation/widgets/dive_computers_section_test.dart`

- [ ] **Step 1: Write failing widget test for the computers section**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_computers_section.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_computer_reading.dart';

void main() {
  group('DiveComputersSection', () {
    test('does not render when readings is empty', () async {
      // Pump widget with empty list
      // Verify nothing is rendered
    });

    test('renders computer cards when readings provided', () async {
      // Pump widget with 2 readings
      // Verify "Computers (2)" header
      // Verify both computer models shown
      // Verify primary badge shown on primary computer
    });

    test('shows Set as Primary option for secondary computers', () async {
      // Tap secondary card
      // Verify "Set as primary" action appears
    });

    test('shows Unlink option in overflow menu', () async {
      // Tap overflow menu on a card
      // Verify "Unlink computer" option appears
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/dive_log/presentation/widgets/dive_computers_section_test.dart`

Expected: FAIL — widget doesn't exist.

- [ ] **Step 3: Implement `DiveComputersSection` widget**

Create `lib/features/dive_log/presentation/widgets/dive_computers_section.dart`:

The widget takes:
- `List<DiveComputerReading> readings`
- `String diveId`
- `UnitSettings units` (for formatting depth/temp values)
- Callbacks: `onSetPrimary(String readingId)`, `onUnlink(String readingId)`

It renders a `CollapsibleSection` with the header "Computers (N)" containing a `Card` per reading. Each card shows: computer model, max depth, avg depth, duration, water temp, CNS%, GF settings. The primary card gets a "(primary)" badge. Secondary cards show "Set as primary" on tap. All cards have an overflow menu with "Unlink computer".

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/dive_log/presentation/widgets/dive_computers_section_test.dart`

Expected: All tests PASS.

- [ ] **Step 5: Add the section to `dive_detail_page.dart`**

In `_buildContent()`, after the profile/decompression sections, add:

```dart
// Computer readings section (only for multi-computer dives)
final computerReadingsAsync = ref.watch(
  diveComputerReadingsProvider(dive.id),
);
computerReadingsAsync.whenData((readings) {
  if (readings.length >= 2) {
    // Insert DiveComputersSection into the Column children
  }
});
```

Wire up `onSetPrimary` to call `repository.setPrimaryComputer()` and invalidate providers.
Wire up `onUnlink` to show a confirmation dialog, then call `repository.unlinkComputer()` and invalidate providers.

- [ ] **Step 6: Run full test suite**

Run: `flutter test`

Expected: All tests PASS.

- [ ] **Step 7: Commit**

```bash
git add lib/features/dive_log/presentation/widgets/dive_computers_section.dart lib/features/dive_log/presentation/pages/dive_detail_page.dart test/features/dive_log/presentation/widgets/dive_computers_section_test.dart
git commit -m "feat: add Computers section to dive detail with set-primary and unlink"
```

---

### Task 8: Add "Merge with another dive" action to dive detail

**Files:**
- Create: `lib/features/dive_log/presentation/widgets/merge_dive_dialog.dart`
- Modify: `lib/features/dive_log/presentation/pages/dive_detail_page.dart`
- Create: `test/features/dive_log/presentation/widgets/merge_dive_dialog_test.dart`

- [ ] **Step 1: Write failing test for the merge dialog**

```dart
group('MergeDiveDialog', () {
  test('shows candidate dives from same day sorted by time proximity', () async {
    // Provide a list of candidate dives
    // Verify they are sorted by time proximity to target dive
    // Verify only same-day dives are shown
  });

  test('confirmation shows data loss warning', () async {
    // Select a dive to merge
    // Verify warning text mentions tanks, equipment, notes will be discarded
    // Verify user must acknowledge before proceeding
  });

  test('calls onMerge with selected dive id on confirmation', () async {
    // Select a dive, confirm merge
    // Verify callback called with correct diveId
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/dive_log/presentation/widgets/merge_dive_dialog_test.dart`

Expected: FAIL.

- [ ] **Step 3: Implement `MergeDiveDialog`**

The dialog:
1. Loads candidate dives from the same calendar day as the target dive (using existing `divesProvider`)
2. Filters out the target dive and any already-merged dives
3. Shows candidates sorted by time proximity
4. On selection, shows a confirmation screen with side-by-side comparison and a data loss warning listing what will be discarded from the source dive
5. On confirm, calls the `onMerge` callback

- [ ] **Step 4: Add "Merge with another dive" to dive detail overflow menu**

In `dive_detail_page.dart`, find the `PopupMenuButton` or overflow menu in the app bar. Add a new menu item:

```dart
PopupMenuItem(
  value: 'merge',
  child: ListTile(
    leading: Icon(Icons.merge),
    title: Text('Merge with another dive'),
  ),
),
```

Handle the `merge` action by showing the `MergeDiveDialog`, then calling `repository.mergeDives()` on confirmation.

- [ ] **Step 5: Run tests**

Run: `flutter test test/features/dive_log/presentation/widgets/merge_dive_dialog_test.dart`

Expected: All tests PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/features/dive_log/presentation/widgets/merge_dive_dialog.dart lib/features/dive_log/presentation/pages/dive_detail_page.dart test/features/dive_log/presentation/widgets/merge_dive_dialog_test.dart
git commit -m "feat: add merge-with-another-dive action to dive detail"
```

---

### Task 9: Add computer toggle bar to profile chart

**Files:**
- Create: `lib/features/dive_log/presentation/widgets/computer_toggle_bar.dart`
- Modify: `lib/features/dive_log/presentation/widgets/dive_profile_chart.dart`
- Modify: `lib/features/dive_log/presentation/pages/dive_detail_page.dart`
- Create: `test/features/dive_log/presentation/widgets/computer_toggle_bar_test.dart`

- [ ] **Step 1: Write failing test for `ComputerToggleBar`**

```dart
group('ComputerToggleBar', () {
  test('does not render for single-computer dives', () async {
    // Pass empty or single-item list
    // Verify widget renders nothing
  });

  test('renders checkbox per computer with correct colors', () async {
    // Pass 2 computers
    // Verify 2 checkboxes with labels
    // Verify primary shows "(primary)" badge
    // Verify colors: first=cyan, second=orange
  });

  test('toggling checkbox calls onToggle callback', () async {
    // Tap a checkbox
    // Verify onToggle called with correct computerId and new value
  });

  test('assigns colors from palette: cyan, orange, green, magenta', () async {
    // Pass 4 computers
    // Verify each gets distinct color from palette
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/dive_log/presentation/widgets/computer_toggle_bar_test.dart`

Expected: FAIL.

- [ ] **Step 3: Implement `ComputerToggleBar` widget**

Create `lib/features/dive_log/presentation/widgets/computer_toggle_bar.dart`:

```dart
import 'package:flutter/material.dart';

/// Color palette for multi-computer profiles.
const computerColors = [
  Color(0xFF00D4FF), // cyan (primary)
  Color(0xFFFF9500), // orange
  Color(0xFF2ECC71), // green
  Color(0xFFE91E8C), // magenta
];

/// Returns the color for a computer at the given index.
/// Cycles with reduced opacity for 5+ computers.
Color computerColorAt(int index) {
  final baseColor = computerColors[index % computerColors.length];
  if (index >= computerColors.length) {
    return baseColor.withOpacity(0.6);
  }
  return baseColor;
}

class ComputerToggleBar extends StatelessWidget {
  final List<ComputerToggleItem> computers;
  final void Function(String computerId, bool enabled) onToggle;

  const ComputerToggleBar({
    super.key,
    required this.computers,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    if (computers.length <= 1) return const SizedBox.shrink();
    // Render a row of checkbox toggles with computer names and color indicators
    // Primary computer gets solid line indicator, secondaries get dashed
    // ...
  }
}

class ComputerToggleItem {
  final String computerId;
  final String label;
  final bool isPrimary;
  final bool isEnabled;
  final Color color;

  const ComputerToggleItem({
    required this.computerId,
    required this.label,
    required this.isPrimary,
    required this.isEnabled,
    required this.color,
  });
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/dive_log/presentation/widgets/computer_toggle_bar_test.dart`

Expected: All tests PASS.

- [ ] **Step 5: Integrate with `DiveProfileChart`**

Modify `dive_profile_chart.dart` to accept multi-computer profile data:

Add new parameters to the constructor:
```dart
/// Map of computerId -> profile points for multi-computer rendering.
/// When non-null and has 2+ entries, enables multi-computer mode.
final Map<String, List<DiveProfilePoint>>? computerProfiles;

/// Set of currently visible computer IDs (controlled by toggle bar).
final Set<String>? visibleComputers;
```

In the chart painting logic, when `computerProfiles` is provided with 2+ entries:
- For each visible computer, draw all enabled data type curves (depth, ceiling, NDL, etc.) using that computer's color
- Primary computer uses solid lines; secondaries use dashed
- The existing single-profile `profile` parameter continues to work for single-computer dives (backward compatible)

- [ ] **Step 6: Wire up in dive detail page**

In `dive_detail_page.dart`'s `_buildProfileSection()`:
- Load profiles by source using `getProfilesBySource()`
- If multiple sources exist, build `ComputerToggleItem` list from computer readings
- Pass `computerProfiles` and `visibleComputers` to `DiveProfileChart`
- Manage toggle state with a local `Set<String>` (all enabled by default)
- Render `ComputerToggleBar` below the chart

- [ ] **Step 7: Run full test suite**

Run: `flutter test`

Expected: All tests PASS.

- [ ] **Step 8: Commit**

```bash
git add lib/features/dive_log/presentation/widgets/computer_toggle_bar.dart lib/features/dive_log/presentation/widgets/dive_profile_chart.dart lib/features/dive_log/presentation/pages/dive_detail_page.dart test/features/dive_log/presentation/widgets/computer_toggle_bar_test.dart
git commit -m "feat: add computer toggle bar and multi-computer profile rendering"
```

---

### Task 10: Update `getProfilesBySource` to support multi-computer chart data

**Files:**
- Modify: `lib/features/dive_log/data/repositories/dive_repository_impl.dart`
- Create: `test/features/dive_log/data/repositories/profile_by_source_test.dart`

- [ ] **Step 1: Write failing test for updated `getProfilesBySource`**

```dart
test('getProfilesBySource groups profiles by computerId for multi-computer dives', () async {
  // Insert profiles with different computerIds for the same dive
  // Call getProfilesBySource
  // Verify: map keys are the computerIds (not 'original')
  // Verify: each key maps to the correct profile points
});

test('getProfilesBySource includes user-edited as separate source', () async {
  // Insert profiles: 2 computer sources + 1 user-edited (computerId=null, isPrimary=true)
  // Verify: map has 3 entries: 'user-edited', 'comp1', 'comp2'
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/dive_log/data/repositories/profile_by_source_test.dart`

Expected: FAIL or unexpected grouping.

- [ ] **Step 3: Update `getProfilesBySource` if needed**

Review the existing implementation (lines 340-395 of `dive_repository_impl.dart`). It already groups by `computerId` or `'original'`, and handles user-edited profiles. Verify it handles the multi-computer case correctly:
- When there are 3+ sources (2 computers + user-edited), all should appear as separate map entries
- Computer IDs should be used as keys, not just `'original'`

Adjust the grouping logic if the current implementation doesn't handle this correctly.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/dive_log/data/repositories/profile_by_source_test.dart`

Expected: All tests PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/dive_log/data/repositories/dive_repository_impl.dart test/features/dive_log/data/repositories/profile_by_source_test.dart
git commit -m "feat: ensure getProfilesBySource handles multi-computer grouping"
```

---

### Task 11: Update profile editing for multi-computer dives

**Files:**
- Modify: `lib/features/dive_log/presentation/widgets/profile_editor_chart.dart` (or wherever profile editing is triggered)
- Modify: `lib/features/dive_log/data/repositories/dive_repository_impl.dart`

- [ ] **Step 1: Add source selection when opening profile editor on multi-computer dive**

When the user opens the profile editor on a multi-computer dive, show a bottom sheet asking which computer's profile to start editing from. Options: each computer's name, or "User edited" if one already exists.

- [ ] **Step 2: Verify existing `saveEditedProfile` handles multi-computer case**

The existing `saveEditedProfile()` already demotes all profiles to `isPrimary=false` and inserts the edited profile with `isPrimary=true` and `computerId=null`. This naturally works for multi-computer dives — the edited layer becomes primary, and all original computer profiles are preserved as non-primary.

Read the method and confirm no changes are needed.

- [ ] **Step 3: Verify revert works for multi-computer case**

When reverting a user-edited profile on a multi-computer dive, the app should:
1. Delete the user-edited profile points (where `computerId` is null and `isPrimary` is true)
2. Restore the previous primary computer's profiles to `isPrimary=true`

Check if the existing revert logic handles this, or if it needs to consult `dive_computer_data` to know which computer was previously primary.

- [ ] **Step 4: Write test for multi-computer profile editing round-trip**

```dart
test('editing profile on multi-computer dive creates user-edited layer', () async {
  // Create dive with 2 computer profiles
  // Edit profile
  // Verify: user-edited profile is primary
  // Verify: both computer profiles still exist as non-primary
  // Verify: getProfilesBySource returns 3 entries
});

test('reverting user-edited profile restores previous primary', () async {
  // Create dive with 2 computers (comp1 is primary)
  // Edit profile (user-edited becomes primary)
  // Revert
  // Verify: comp1 is primary again
  // Verify: user-edited profile deleted
});
```

- [ ] **Step 5: Run tests**

Run: `flutter test`

Expected: All tests PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/features/dive_log/presentation/ lib/features/dive_log/data/repositories/ test/
git commit -m "feat: support profile editing with source selection on multi-computer dives"
```

---

### Task 12: Final integration test and cleanup

**Files:**
- Create: `test/features/dive_log/integration/multi_computer_integration_test.dart`

- [ ] **Step 1: Write end-to-end integration test**

```dart
test('full multi-computer workflow: consolidate, visualize, set primary, unlink', () async {
  // 1. Create a dive with profile data (simulating first computer import)
  // 2. Call consolidateComputer to add second computer's data
  // 3. Verify: 2 computer readings exist
  // 4. Verify: getProfilesBySource returns 2 entries
  // 5. Call setPrimaryComputer to swap primary
  // 6. Verify: dives record updated with new primary's metadata
  // 7. Call unlinkComputer to detach secondary
  // 8. Verify: original dive back to single-computer (no dive_computer_data rows)
  // 9. Verify: new standalone dive created with correct metadata
});

test('full merge workflow: import two dives, merge, verify, unlink', () async {
  // 1. Create two separate dives (simulating two imports)
  // 2. Call mergeDives
  // 3. Verify: primary dive has 2 computer readings
  // 4. Verify: secondary dive deleted
  // 5. Call unlinkComputer
  // 6. Verify: both dives exist again as standalone
});
```

- [ ] **Step 2: Run integration tests**

Run: `flutter test test/features/dive_log/integration/multi_computer_integration_test.dart`

Expected: All tests PASS.

- [ ] **Step 3: Run full test suite and analyzer**

Run: `flutter test && flutter analyze`

Expected: All tests PASS, no analysis errors.

- [ ] **Step 4: Format code**

Run: `dart format lib/ test/`

Expected: No formatting changes (already formatted).

- [ ] **Step 5: Commit**

```bash
git add test/features/dive_log/integration/
git commit -m "test: add multi-computer dive integration tests"
```

---

### Task Summary

| Task | Description | Dependencies |
|------|-------------|-------------|
| 1 | Database table + migration | None |
| 2 | Domain entity | Task 1 (codegen) |
| 3 | Repository CRUD + back-fill | Tasks 1, 2 |
| 4 | Consolidation/merge/unlink/set-primary | Task 3 |
| 5 | Riverpod providers | Tasks 3, 4 |
| 6 | Import consolidation resolution | Tasks 3, 4 |
| 7 | Dive detail computers section | Tasks 4, 5 |
| 8 | Merge dive dialog | Tasks 4, 5 |
| 9 | Profile chart computer toggle | Tasks 5, 10 |
| 10 | Profile-by-source update | Task 3 |
| 11 | Profile editing for multi-computer | Tasks 4, 10 |
| 12 | Integration tests + cleanup | All above |
