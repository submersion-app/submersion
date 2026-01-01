# Database Schema

Submersion uses Drift ORM with SQLite, containing 30 tables organized into logical groups.

## Overview

| Category | Tables | Description |
|----------|--------|-------------|
| **Core** | 4 | Divers, Dives, Profiles, Tanks |
| **Location** | 3 | Sites, Centers, Trips |
| **Equipment** | 6 | Gear tracking |
| **People** | 3 | Buddies, Certifications |
| **Organization** | 3 | Tags, Dive Types |
| **Profile** | 3 | Computers, Events, Gas Switches |
| **Marine Life** | 2 | Species, Sightings |
| **Media** | 1 | Photos/Videos |
| **Settings** | 2 | Configuration |
| **Sync** | 3 | Cloud sync |

## Drift ORM

### Table Definitions

Tables are defined in `lib/core/database/database.dart`:

```dart
class Dives extends Table {
  TextColumn get id => text()();
  TextColumn get diverId => text().nullable().references(Divers, #id)();
  IntColumn get diveNumber => integer().nullable()();
  IntColumn get diveDateTime => integer()();
  // ...

  @override
  Set<Column> get primaryKey => {id};
}
```

### Generated Code

Run code generation after schema changes:

```bash
dart run build_runner build --delete-conflicting-outputs
```

Generates `database.g.dart` with:
- Companion classes
- Query builders
- Type converters

## Schema Version

Current version: **4**

Migrations handle schema evolution:

```dart
@override
int get schemaVersion => 4;

@override
MigrationStrategy get migration {
  return MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      // Seed data
    },
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        // Add column
      }
      if (from < 3) {
        // Add table
      }
    },
  );
}
```

## Core Tables

### Divers

Multi-account support:

```sql
CREATE TABLE divers (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  email TEXT,
  phone TEXT,
  photo_path TEXT,
  -- Emergency contact
  emergency_contact_name TEXT,
  emergency_contact_phone TEXT,
  emergency_contact_relation TEXT,
  -- Medical
  medical_notes TEXT DEFAULT '',
  blood_type TEXT,
  allergies TEXT,
  -- Insurance
  insurance_provider TEXT,
  insurance_policy_number TEXT,
  insurance_expiry_date INTEGER,
  -- Meta
  notes TEXT DEFAULT '',
  is_default INTEGER DEFAULT 0,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
);
```

### Dives

Primary dive log:

```sql
CREATE TABLE dives (
  id TEXT PRIMARY KEY,
  diver_id TEXT REFERENCES divers(id),
  dive_number INTEGER,
  dive_date_time INTEGER NOT NULL,
  entry_time INTEGER,
  exit_time INTEGER,
  duration INTEGER,
  runtime INTEGER,
  max_depth REAL,
  avg_depth REAL,
  water_temp REAL,
  air_temp REAL,
  visibility TEXT,
  -- References
  site_id TEXT REFERENCES dive_sites(id),
  dive_center_id TEXT REFERENCES dive_centers(id),
  trip_id TEXT REFERENCES trips(id),
  computer_id TEXT REFERENCES dive_computers(id),
  -- Conditions
  current_direction TEXT,
  current_strength TEXT,
  swell_height REAL,
  entry_method TEXT,
  exit_method TEXT,
  water_type TEXT,
  -- Technical
  altitude REAL,
  surface_pressure REAL,
  surface_interval_seconds INTEGER,
  gradient_factor_low INTEGER,
  gradient_factor_high INTEGER,
  dive_mode TEXT DEFAULT 'oc',
  dive_computer_model TEXT,
  dive_computer_serial TEXT,
  -- O2 toxicity
  cns_start REAL DEFAULT 0,
  cns_end REAL,
  otu REAL,
  -- Weight
  weight_amount REAL,
  weight_type TEXT,
  -- Meta
  dive_type TEXT DEFAULT 'recreational',
  buddy TEXT,
  dive_master TEXT,
  rating INTEGER,
  notes TEXT DEFAULT '',
  is_favorite INTEGER DEFAULT 0,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
);
```

### DiveProfiles

Time-series profile data:

```sql
CREATE TABLE dive_profiles (
  id TEXT PRIMARY KEY,
  dive_id TEXT NOT NULL REFERENCES dives(id) ON DELETE CASCADE,
  computer_id TEXT REFERENCES dive_computers(id),
  is_primary INTEGER DEFAULT 1,
  timestamp INTEGER NOT NULL,
  depth REAL NOT NULL,
  pressure REAL,
  temperature REAL,
  heart_rate INTEGER,
  ascent_rate REAL,
  ceiling REAL,
  ndl INTEGER
);

CREATE INDEX idx_profile_dive ON dive_profiles(dive_id, timestamp);
```

### DiveTanks

Gas configuration:

```sql
CREATE TABLE dive_tanks (
  id TEXT PRIMARY KEY,
  dive_id TEXT NOT NULL REFERENCES dives(id) ON DELETE CASCADE,
  equipment_id TEXT REFERENCES equipment(id),
  volume REAL,
  working_pressure INTEGER,
  start_pressure INTEGER,
  end_pressure INTEGER,
  o2_percent REAL DEFAULT 21.0,
  he_percent REAL DEFAULT 0.0,
  tank_order INTEGER DEFAULT 0,
  tank_role TEXT DEFAULT 'backGas',
  tank_material TEXT,
  tank_name TEXT,
  preset_name TEXT
);
```

## Relationship Patterns

### One-to-Many

```dart
// Diver has many Dives
TextColumn get diverId => text().nullable().references(Divers, #id)();
```

### Many-to-Many

Junction tables with composite keys:

```dart
// Dives <-> Equipment
class DiveEquipment extends Table {
  TextColumn get diveId =>
    text().references(Dives, #id, onDelete: KeyAction.cascade)();
  TextColumn get equipmentId =>
    text().references(Equipment, #id, onDelete: KeyAction.cascade)();

  @override
  Set<Column> get primaryKey => {diveId, equipmentId};
}
```

### Junction with Attributes

```dart
// DiveBuddies has role attribute
class DiveBuddies extends Table {
  TextColumn get id => text()();
  TextColumn get diveId =>
    text().references(Dives, #id, onDelete: KeyAction.cascade)();
  TextColumn get buddyId =>
    text().references(Buddies, #id, onDelete: KeyAction.cascade)();
  TextColumn get role => text().withDefault(const Constant('buddy'))();
  IntColumn get createdAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}
```

## Cascade Deletes

Child records auto-delete:

```dart
TextColumn get diveId =>
  text().references(Dives, #id, onDelete: KeyAction.cascade)();
```

Used for:
- DiveProfiles (dive deleted → profiles deleted)
- DiveTanks
- DiveWeights
- DiveProfileEvents
- GasSwitches

## Repository Pattern

### Base Repository

```dart
class DiveRepository {
  final AppDatabase _db = DatabaseService.instance.database;

  Future<List<domain.Dive>> getAllDives({String? diverId}) async {
    final query = _db.select(_db.dives);
    if (diverId != null) {
      query.where((d) => d.diverId.equals(diverId));
    }
    query.orderBy([(d) => OrderingTerm.desc(d.diveDateTime)]);

    final rows = await query.get();
    return rows.map(_mapToDomain).toList();
  }

  Future<domain.Dive> createDive(domain.Dive dive) async {
    final companion = _toCompanion(dive);
    await _db.into(_db.dives).insert(companion);
    return dive;
  }

  Future<void> updateDive(domain.Dive dive) async {
    await (_db.update(_db.dives)
      ..where((d) => d.id.equals(dive.id)))
      .write(_toCompanion(dive));
  }

  Future<void> deleteDive(String id) async {
    await (_db.delete(_db.dives)
      ..where((d) => d.id.equals(id)))
      .go();
  }
}
```

### Domain Mapping

```dart
domain.Dive _mapToDomain(Dive row) {
  return domain.Dive(
    id: row.id,
    diverId: row.diverId,
    diveNumber: row.diveNumber,
    dateTime: DateTime.fromMillisecondsSinceEpoch(row.diveDateTime),
    // ... map all fields
  );
}

DivesCompanion _toCompanion(domain.Dive dive) {
  return DivesCompanion(
    id: Value(dive.id),
    diverId: Value(dive.diverId),
    diveNumber: Value(dive.diveNumber),
    diveDateTime: Value(dive.dateTime.millisecondsSinceEpoch),
    // ... map all fields
  );
}
```

## Queries

### Select with Joins

```dart
Future<domain.Dive?> getDiveWithDetails(String id) async {
  final query = _db.select(_db.dives).join([
    leftOuterJoin(_db.diveSites,
      _db.diveSites.id.equalsExp(_db.dives.siteId)),
    leftOuterJoin(_db.diveCenters,
      _db.diveCenters.id.equalsExp(_db.dives.diveCenterId)),
  ]);
  query.where(_db.dives.id.equals(id));

  final row = await query.getSingleOrNull();
  if (row == null) return null;

  return _mapWithRelations(row);
}
```

### Aggregations

```dart
Future<DiveStats> getStats(String diverId) async {
  final result = await _db.customSelect('''
    SELECT
      COUNT(*) as dive_count,
      SUM(duration) as total_time,
      MAX(max_depth) as max_depth
    FROM dives
    WHERE diver_id = ?
  ''', variables: [Variable.withString(diverId)]).getSingle();

  return DiveStats(
    diveCount: result.read<int>('dive_count'),
    totalTime: result.read<int>('total_time'),
    maxDepth: result.read<double>('max_depth'),
  );
}
```

## Seeded Data

Built-in dive types seeded on create:

```dart
final builtInTypes = [
  ('recreational', 'Recreational', 0),
  ('technical', 'Technical', 1),
  ('freedive', 'Freedive', 2),
  // ...
];

for (final type in builtInTypes) {
  await customStatement('''
    INSERT OR IGNORE INTO dive_types
    (id, name, is_built_in, sort_order, created_at, updated_at)
    VALUES (?, ?, 1, ?, ?, ?)
  ''');
}
```

## Performance Tips

### Indexes

Add indexes for common queries:
- Already indexed: `dive_profiles(dive_id, timestamp)`
- Consider: `dives(diver_id, dive_date_time)`

### Batch Operations

```dart
Future<void> bulkInsertProfiles(List<DiveProfile> profiles) async {
  await _db.batch((batch) {
    batch.insertAll(_db.diveProfiles,
      profiles.map(_toCompanion).toList());
  });
}
```

### Lazy Loading

Don't load profiles until needed:
```dart
// In dive list: just dive data
// In dive detail: load profile on demand
```
