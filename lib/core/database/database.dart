import 'package:drift/drift.dart';

part 'database.g.dart';

// ============================================================================
// Table Definitions
// ============================================================================

/// Dive log entries
class Dives extends Table {
  TextColumn get id => text()();
  IntColumn get diveNumber => integer().nullable()();
  IntColumn get diveDateTime => integer()(); // Unix timestamp
  IntColumn get duration => integer().nullable()(); // seconds
  RealColumn get maxDepth => real().nullable()();
  RealColumn get avgDepth => real().nullable()();
  RealColumn get waterTemp => real().nullable()();
  RealColumn get airTemp => real().nullable()();
  TextColumn get visibility => text().nullable()();
  TextColumn get diveType => text().withDefault(const Constant('recreational'))();
  TextColumn get buddy => text().nullable()();
  TextColumn get diveMaster => text().nullable()();
  TextColumn get notes => text().withDefault(const Constant(''))();
  TextColumn get siteId => text().nullable().references(DiveSites, #id)();
  IntColumn get rating => integer().nullable()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Time-series dive profile data points
class DiveProfiles extends Table {
  TextColumn get id => text()();
  TextColumn get diveId => text().references(Dives, #id, onDelete: KeyAction.cascade)();
  IntColumn get timestamp => integer()(); // seconds from dive start
  RealColumn get depth => real()();
  RealColumn get pressure => real().nullable()(); // bar
  RealColumn get temperature => real().nullable()();
  IntColumn get heartRate => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Dive sites/locations
class DiveSites extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get description => text().withDefault(const Constant(''))();
  RealColumn get latitude => real().nullable()();
  RealColumn get longitude => real().nullable()();
  RealColumn get maxDepth => real().nullable()();
  TextColumn get country => text().nullable()();
  TextColumn get region => text().nullable()();
  RealColumn get rating => real().nullable()();
  TextColumn get notes => text().withDefault(const Constant(''))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Tanks used during dives
class DiveTanks extends Table {
  TextColumn get id => text()();
  TextColumn get diveId => text().references(Dives, #id, onDelete: KeyAction.cascade)();
  TextColumn get equipmentId => text().nullable().references(Equipment, #id)();
  RealColumn get volume => real().nullable()(); // liters
  IntColumn get startPressure => integer().nullable()(); // bar
  IntColumn get endPressure => integer().nullable()(); // bar
  RealColumn get o2Percent => real().withDefault(const Constant(21.0))();
  RealColumn get hePercent => real().withDefault(const Constant(0.0))();
  IntColumn get tankOrder => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Equipment catalog
class Equipment extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get type => text()(); // regulator, bcd, wetsuit, etc.
  TextColumn get brand => text().nullable()();
  TextColumn get model => text().nullable()();
  TextColumn get serialNumber => text().nullable()();
  IntColumn get purchaseDate => integer().nullable()();
  IntColumn get lastServiceDate => integer().nullable()();
  IntColumn get serviceIntervalDays => integer().nullable()();
  TextColumn get notes => text().withDefault(const Constant(''))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Junction table for equipment used per dive
class DiveEquipment extends Table {
  TextColumn get diveId => text().references(Dives, #id, onDelete: KeyAction.cascade)();
  TextColumn get equipmentId => text().references(Equipment, #id, onDelete: KeyAction.cascade)();

  @override
  Set<Column> get primaryKey => {diveId, equipmentId};
}

/// Equipment sets (named collections of equipment items)
class EquipmentSets extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get description => text().withDefault(const Constant(''))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Junction table for equipment items in sets
class EquipmentSetItems extends Table {
  TextColumn get setId => text().references(EquipmentSets, #id, onDelete: KeyAction.cascade)();
  TextColumn get equipmentId => text().references(Equipment, #id, onDelete: KeyAction.cascade)();

  @override
  Set<Column> get primaryKey => {setId, equipmentId};
}

/// Marine life species catalog
class Species extends Table {
  TextColumn get id => text()();
  TextColumn get commonName => text()();
  TextColumn get scientificName => text().nullable()();
  TextColumn get category => text()(); // fish, coral, mammal, etc.
  TextColumn get description => text().nullable()();
  TextColumn get photoPath => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Marine life sightings per dive
class Sightings extends Table {
  TextColumn get id => text()();
  TextColumn get diveId => text().references(Dives, #id, onDelete: KeyAction.cascade)();
  TextColumn get speciesId => text().references(Species, #id)();
  IntColumn get count => integer().withDefault(const Constant(1))();
  TextColumn get notes => text().withDefault(const Constant(''))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Photos and media files
class Media extends Table {
  TextColumn get id => text()();
  TextColumn get diveId => text().nullable().references(Dives, #id, onDelete: KeyAction.setNull)();
  TextColumn get siteId => text().nullable().references(DiveSites, #id, onDelete: KeyAction.setNull)();
  TextColumn get filePath => text()();
  TextColumn get fileType => text().withDefault(const Constant('photo'))();
  RealColumn get latitude => real().nullable()();
  RealColumn get longitude => real().nullable()();
  IntColumn get takenAt => integer().nullable()();
  TextColumn get caption => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Application settings key-value store
class Settings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text().nullable()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {key};
}

/// Dive buddies contact list
class Buddies extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get email => text().nullable()();
  TextColumn get phone => text().nullable()();
  TextColumn get certificationLevel => text().nullable()();
  TextColumn get certificationAgency => text().nullable()();
  TextColumn get photoPath => text().nullable()();
  TextColumn get notes => text().withDefault(const Constant(''))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Junction table for buddies on each dive (many-to-many with role)
class DiveBuddies extends Table {
  TextColumn get id => text()();
  TextColumn get diveId => text().references(Dives, #id, onDelete: KeyAction.cascade)();
  TextColumn get buddyId => text().references(Buddies, #id, onDelete: KeyAction.cascade)();
  TextColumn get role => text().withDefault(const Constant('buddy'))();
  IntColumn get createdAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

// ============================================================================
// Database Class
// ============================================================================

@DriftDatabase(
  tables: [
    Dives,
    DiveProfiles,
    DiveSites,
    DiveTanks,
    Equipment,
    DiveEquipment,
    EquipmentSets,
    EquipmentSetItems,
    Species,
    Sightings,
    Media,
    Settings,
    Buddies,
    DiveBuddies,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
      },
      onUpgrade: (Migrator m, int from, int to) async {
        if (from < 2) {
          // Migration v1 -> v2: Rename gear to equipment, add equipment sets
          // Rename gear table to equipment
          await customStatement('ALTER TABLE gear RENAME TO equipment');
          // Rename dive_gear table to dive_equipment and update column name
          await customStatement('ALTER TABLE dive_gear RENAME TO dive_equipment');
          // Rename gear_id column in dive_equipment to equipment_id
          await customStatement('''
            CREATE TABLE dive_equipment_new (
              dive_id TEXT NOT NULL REFERENCES dives(id) ON DELETE CASCADE,
              equipment_id TEXT NOT NULL REFERENCES equipment(id) ON DELETE CASCADE,
              PRIMARY KEY (dive_id, equipment_id)
            )
          ''');
          await customStatement('''
            INSERT INTO dive_equipment_new (dive_id, equipment_id)
            SELECT dive_id, gear_id FROM dive_equipment
          ''');
          await customStatement('DROP TABLE dive_equipment');
          await customStatement('ALTER TABLE dive_equipment_new RENAME TO dive_equipment');
          // Rename gear_id column in dive_tanks to equipment_id
          await customStatement('''
            CREATE TABLE dive_tanks_new (
              id TEXT NOT NULL PRIMARY KEY,
              dive_id TEXT NOT NULL REFERENCES dives(id) ON DELETE CASCADE,
              equipment_id TEXT REFERENCES equipment(id),
              volume REAL,
              start_pressure INTEGER,
              end_pressure INTEGER,
              o2_percent REAL NOT NULL DEFAULT 21.0,
              he_percent REAL NOT NULL DEFAULT 0.0,
              tank_order INTEGER NOT NULL DEFAULT 0
            )
          ''');
          await customStatement('''
            INSERT INTO dive_tanks_new (id, dive_id, equipment_id, volume, start_pressure, end_pressure, o2_percent, he_percent, tank_order)
            SELECT id, dive_id, gear_id, volume, start_pressure, end_pressure, o2_percent, he_percent, tank_order FROM dive_tanks
          ''');
          await customStatement('DROP TABLE dive_tanks');
          await customStatement('ALTER TABLE dive_tanks_new RENAME TO dive_tanks');
          // Create new equipment_sets table
          await customStatement('''
            CREATE TABLE equipment_sets (
              id TEXT NOT NULL PRIMARY KEY,
              name TEXT NOT NULL,
              description TEXT NOT NULL DEFAULT '',
              created_at INTEGER NOT NULL,
              updated_at INTEGER NOT NULL
            )
          ''');
          // Create new equipment_set_items junction table
          await customStatement('''
            CREATE TABLE equipment_set_items (
              set_id TEXT NOT NULL REFERENCES equipment_sets(id) ON DELETE CASCADE,
              equipment_id TEXT NOT NULL REFERENCES equipment(id) ON DELETE CASCADE,
              PRIMARY KEY (set_id, equipment_id)
            )
          ''');
        }
        if (from < 3) {
          // Migration v2 -> v3: Add buddies and dive_buddies tables
          await customStatement('''
            CREATE TABLE IF NOT EXISTS buddies (
              id TEXT NOT NULL PRIMARY KEY,
              name TEXT NOT NULL,
              email TEXT,
              phone TEXT,
              certification_level TEXT,
              certification_agency TEXT,
              photo_path TEXT,
              notes TEXT NOT NULL DEFAULT '',
              created_at INTEGER NOT NULL,
              updated_at INTEGER NOT NULL
            )
          ''');
          await customStatement('''
            CREATE TABLE IF NOT EXISTS dive_buddies (
              id TEXT NOT NULL PRIMARY KEY,
              dive_id TEXT NOT NULL REFERENCES dives(id) ON DELETE CASCADE,
              buddy_id TEXT NOT NULL REFERENCES buddies(id) ON DELETE CASCADE,
              role TEXT NOT NULL DEFAULT 'buddy',
              created_at INTEGER NOT NULL
            )
          ''');
          // Create index for faster lookups
          await customStatement('''
            CREATE INDEX IF NOT EXISTS idx_dive_buddies_dive_id ON dive_buddies(dive_id)
          ''');
          await customStatement('''
            CREATE INDEX IF NOT EXISTS idx_dive_buddies_buddy_id ON dive_buddies(buddy_id)
          ''');
        }
      },
      beforeOpen: (details) async {
        // Enable foreign keys
        await customStatement('PRAGMA foreign_keys = ON');
      },
    );
  }
}