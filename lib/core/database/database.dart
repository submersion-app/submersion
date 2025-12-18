import 'package:drift/drift.dart';

part 'database.g.dart';

// ============================================================================
// Table Definitions
// ============================================================================

/// Dive trips (group of dives at a destination)
class Trips extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  IntColumn get startDate => integer()(); // Unix timestamp
  IntColumn get endDate => integer()(); // Unix timestamp
  TextColumn get location => text().nullable()();
  TextColumn get resortName => text().nullable()();
  TextColumn get liveaboardName => text().nullable()();
  TextColumn get notes => text().withDefault(const Constant(''))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Dive log entries
class Dives extends Table {
  TextColumn get id => text()();
  IntColumn get diveNumber => integer().nullable()();
  IntColumn get diveDateTime => integer()(); // Unix timestamp (legacy, kept for compatibility)
  IntColumn get entryTime => integer().nullable()(); // Unix timestamp - when diver entered water
  IntColumn get exitTime => integer().nullable()(); // Unix timestamp - when diver exited water
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
  // Dive center reference
  TextColumn get diveCenterId => text().nullable().references(DiveCenters, #id)();
  // Trip reference
  TextColumn get tripId => text().nullable().references(Trips, #id)();
  // Conditions fields
  TextColumn get currentDirection => text().nullable()();
  TextColumn get currentStrength => text().nullable()();
  RealColumn get swellHeight => real().nullable()(); // meters
  TextColumn get entryMethod => text().nullable()();
  TextColumn get exitMethod => text().nullable()();
  TextColumn get waterType => text().nullable()();
  // Weight system fields
  RealColumn get weightAmount => real().nullable()(); // kg
  TextColumn get weightType => text().nullable()();
  // Favorite flag (v1.1)
  BoolColumn get isFavorite => boolean().withDefault(const Constant(false))();
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
  RealColumn get minDepth => real().nullable()(); // Shallowest point
  RealColumn get maxDepth => real().nullable()(); // Deepest point
  TextColumn get difficulty => text().nullable()(); // Beginner, Intermediate, Advanced, Technical
  TextColumn get country => text().nullable()();
  TextColumn get region => text().nullable()();
  RealColumn get rating => real().nullable()();
  TextColumn get notes => text().withDefault(const Constant(''))();
  TextColumn get hazards => text().nullable()(); // Currents, boats, marine life, etc.
  TextColumn get accessNotes => text().nullable()(); // How to get there, entry points
  TextColumn get mooringNumber => text().nullable()(); // Mooring buoy number for boats
  TextColumn get parkingInfo => text().nullable()(); // Parking availability and tips
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
  IntColumn get workingPressure => integer().nullable()(); // bar - rated pressure
  IntColumn get startPressure => integer().nullable()(); // bar
  IntColumn get endPressure => integer().nullable()(); // bar
  RealColumn get o2Percent => real().withDefault(const Constant(21.0))();
  RealColumn get hePercent => real().withDefault(const Constant(0.0))();
  IntColumn get tankOrder => integer().withDefault(const Constant(0))();
  TextColumn get tankRole => text().withDefault(const Constant('backGas'))(); // backGas, stage, deco, bailout, etc.
  TextColumn get tankMaterial => text().nullable()(); // aluminum, steel, carbonFiber
  TextColumn get tankName => text().nullable()(); // user-friendly name like "Primary AL80"

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
  TextColumn get size => text().nullable()(); // S, M, L, XL, or specific size
  TextColumn get status => text().withDefault(const Constant('active'))(); // active, needsService, retired, etc.
  IntColumn get purchaseDate => integer().nullable()();
  RealColumn get purchasePrice => real().nullable()();
  TextColumn get purchaseCurrency => text().withDefault(const Constant('USD'))();
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

/// Multiple weight entries per dive (e.g., integrated + trim weights)
class DiveWeights extends Table {
  TextColumn get id => text()();
  TextColumn get diveId => text().references(Dives, #id, onDelete: KeyAction.cascade)();
  TextColumn get weightType => text()(); // Integrated, Belt, Trim, Ankle, Backplate, Other
  RealColumn get amountKg => real()(); // kg
  TextColumn get notes => text().withDefault(const Constant(''))();
  IntColumn get createdAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
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

/// Diver certifications
class Certifications extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()(); // e.g., "Open Water Diver"
  TextColumn get agency => text()(); // PADI, SSI, etc.
  TextColumn get level => text().nullable()(); // For more specific level info
  TextColumn get cardNumber => text().nullable()();
  IntColumn get issueDate => integer().nullable()();
  IntColumn get expiryDate => integer().nullable()(); // For certs that expire
  TextColumn get instructorName => text().nullable()();
  TextColumn get instructorNumber => text().nullable()();
  TextColumn get photoFrontPath => text().nullable()(); // Front of cert card
  TextColumn get photoBackPath => text().nullable()(); // Back of cert card
  TextColumn get notes => text().withDefault(const Constant(''))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Equipment service records
class ServiceRecords extends Table {
  TextColumn get id => text()();
  TextColumn get equipmentId => text().references(Equipment, #id, onDelete: KeyAction.cascade)();
  TextColumn get serviceType => text()(); // annual, repair, inspection, etc.
  IntColumn get serviceDate => integer()();
  TextColumn get provider => text().nullable()(); // Shop or technician name
  RealColumn get cost => real().nullable()();
  TextColumn get currency => text().withDefault(const Constant('USD'))();
  IntColumn get nextServiceDue => integer().nullable()();
  TextColumn get notes => text().withDefault(const Constant(''))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Dive centers/operators
class DiveCenters extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get location => text().nullable()();
  RealColumn get latitude => real().nullable()();
  RealColumn get longitude => real().nullable()();
  TextColumn get country => text().nullable()();
  TextColumn get phone => text().nullable()();
  TextColumn get email => text().nullable()();
  TextColumn get website => text().nullable()();
  TextColumn get affiliations => text().nullable()(); // PADI, SSI, etc. comma-separated
  RealColumn get rating => real().nullable()();
  TextColumn get notes => text().withDefault(const Constant(''))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Tags for organizing dives (v1.5)
class Tags extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get color => text().nullable()(); // Hex color code for UI
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Custom dive types (v1.0)
class DiveTypes extends Table {
  TextColumn get id => text()(); // Unique identifier (slug)
  TextColumn get name => text()(); // Display name
  BoolColumn get isBuiltIn =>
      boolean().withDefault(const Constant(false))(); // System vs user-defined
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Junction table for dive tags (many-to-many)
class DiveTags extends Table {
  TextColumn get id => text()();
  TextColumn get diveId => text().references(Dives, #id, onDelete: KeyAction.cascade)();
  TextColumn get tagId => text().references(Tags, #id, onDelete: KeyAction.cascade)();
  IntColumn get createdAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

// ============================================================================
// Database Class
// ============================================================================

@DriftDatabase(
  tables: [
    Trips,
    Dives,
    DiveProfiles,
    DiveSites,
    DiveTanks,
    Equipment,
    DiveEquipment,
    DiveWeights,
    EquipmentSets,
    EquipmentSetItems,
    Species,
    Sightings,
    Media,
    Settings,
    Buddies,
    DiveBuddies,
    Certifications,
    ServiceRecords,
    DiveCenters,
    Tags,
    DiveTags,
    DiveTypes,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 12;

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
        if (from < 4) {
          // Migration v3 -> v4: Add certifications and service_records tables
          await customStatement('''
            CREATE TABLE IF NOT EXISTS certifications (
              id TEXT NOT NULL PRIMARY KEY,
              name TEXT NOT NULL,
              agency TEXT NOT NULL,
              level TEXT,
              card_number TEXT,
              issue_date INTEGER,
              expiry_date INTEGER,
              instructor_name TEXT,
              instructor_number TEXT,
              photo_front_path TEXT,
              photo_back_path TEXT,
              notes TEXT NOT NULL DEFAULT '',
              created_at INTEGER NOT NULL,
              updated_at INTEGER NOT NULL
            )
          ''');
          await customStatement('''
            CREATE TABLE IF NOT EXISTS service_records (
              id TEXT NOT NULL PRIMARY KEY,
              equipment_id TEXT NOT NULL REFERENCES equipment(id) ON DELETE CASCADE,
              service_type TEXT NOT NULL,
              service_date INTEGER NOT NULL,
              provider TEXT,
              cost REAL,
              currency TEXT NOT NULL DEFAULT 'USD',
              next_service_due INTEGER,
              notes TEXT NOT NULL DEFAULT '',
              created_at INTEGER NOT NULL,
              updated_at INTEGER NOT NULL
            )
          ''');
          // Create index for faster equipment service lookups
          await customStatement('''
            CREATE INDEX IF NOT EXISTS idx_service_records_equipment_id ON service_records(equipment_id)
          ''');
        }
        if (from < 5) {
          // Migration v4 -> v5: Add dive_centers table and new fields on dives/equipment

          // Create dive_centers table
          await customStatement('''
            CREATE TABLE IF NOT EXISTS dive_centers (
              id TEXT NOT NULL PRIMARY KEY,
              name TEXT NOT NULL,
              location TEXT,
              latitude REAL,
              longitude REAL,
              country TEXT,
              phone TEXT,
              email TEXT,
              website TEXT,
              affiliations TEXT,
              rating REAL,
              notes TEXT NOT NULL DEFAULT '',
              created_at INTEGER NOT NULL,
              updated_at INTEGER NOT NULL
            )
          ''');

          // Add new columns to dives table
          await customStatement('ALTER TABLE dives ADD COLUMN dive_center_id TEXT REFERENCES dive_centers(id)');
          await customStatement('ALTER TABLE dives ADD COLUMN current_direction TEXT');
          await customStatement('ALTER TABLE dives ADD COLUMN current_strength TEXT');
          await customStatement('ALTER TABLE dives ADD COLUMN swell_height REAL');
          await customStatement('ALTER TABLE dives ADD COLUMN entry_method TEXT');
          await customStatement('ALTER TABLE dives ADD COLUMN exit_method TEXT');
          await customStatement('ALTER TABLE dives ADD COLUMN water_type TEXT');
          await customStatement('ALTER TABLE dives ADD COLUMN weight_amount REAL');
          await customStatement('ALTER TABLE dives ADD COLUMN weight_type TEXT');

          // Add new columns to equipment table
          await customStatement('ALTER TABLE equipment ADD COLUMN size TEXT');
          await customStatement('ALTER TABLE equipment ADD COLUMN status TEXT NOT NULL DEFAULT \'active\'');
          await customStatement('ALTER TABLE equipment ADD COLUMN purchase_price REAL');
          await customStatement('ALTER TABLE equipment ADD COLUMN purchase_currency TEXT NOT NULL DEFAULT \'USD\'');
        }
        if (from < 6) {
          // Migration v5 -> v6: Add trips table and trip_id to dives

          // Create trips table
          await customStatement('''
            CREATE TABLE IF NOT EXISTS trips (
              id TEXT NOT NULL PRIMARY KEY,
              name TEXT NOT NULL,
              start_date INTEGER NOT NULL,
              end_date INTEGER NOT NULL,
              location TEXT,
              resort_name TEXT,
              liveaboard_name TEXT,
              notes TEXT NOT NULL DEFAULT '',
              created_at INTEGER NOT NULL,
              updated_at INTEGER NOT NULL
            )
          ''');

          // Add trip_id column to dives table
          await customStatement('ALTER TABLE dives ADD COLUMN trip_id TEXT REFERENCES trips(id)');

          // Create index for faster trip lookups
          await customStatement('''
            CREATE INDEX IF NOT EXISTS idx_dives_trip_id ON dives(trip_id)
          ''');
        }
        if (from < 7) {
          // Migration v6 -> v7: Add tank enhancements (role, material, working pressure, name)
          await customStatement("ALTER TABLE dive_tanks ADD COLUMN working_pressure INTEGER");
          await customStatement("ALTER TABLE dive_tanks ADD COLUMN tank_role TEXT NOT NULL DEFAULT 'backGas'");
          await customStatement('ALTER TABLE dive_tanks ADD COLUMN tank_material TEXT');
          await customStatement('ALTER TABLE dive_tanks ADD COLUMN tank_name TEXT');
        }
        if (from < 8) {
          // Migration v7 -> v8: Add favorites (v1.1) and tags (v1.5)

          // Add is_favorite column to dives table
          await customStatement('ALTER TABLE dives ADD COLUMN is_favorite INTEGER NOT NULL DEFAULT 0');

          // Create tags table
          await customStatement('''
            CREATE TABLE IF NOT EXISTS tags (
              id TEXT NOT NULL PRIMARY KEY,
              name TEXT NOT NULL,
              color TEXT,
              created_at INTEGER NOT NULL,
              updated_at INTEGER NOT NULL
            )
          ''');

          // Create dive_tags junction table
          await customStatement('''
            CREATE TABLE IF NOT EXISTS dive_tags (
              id TEXT NOT NULL PRIMARY KEY,
              dive_id TEXT NOT NULL REFERENCES dives(id) ON DELETE CASCADE,
              tag_id TEXT NOT NULL REFERENCES tags(id) ON DELETE CASCADE,
              created_at INTEGER NOT NULL
            )
          ''');

          // Create indexes for faster tag lookups
          await customStatement('''
            CREATE INDEX IF NOT EXISTS idx_dive_tags_dive_id ON dive_tags(dive_id)
          ''');
          await customStatement('''
            CREATE INDEX IF NOT EXISTS idx_dive_tags_tag_id ON dive_tags(tag_id)
          ''');
          await customStatement('''
            CREATE UNIQUE INDEX IF NOT EXISTS idx_tags_name ON tags(name)
          ''');
        }
        if (from < 9) {
          // Migration v8 -> v9: Add dive_weights table for multiple weight entries per dive
          await customStatement('''
            CREATE TABLE IF NOT EXISTS dive_weights (
              id TEXT NOT NULL PRIMARY KEY,
              dive_id TEXT NOT NULL REFERENCES dives(id) ON DELETE CASCADE,
              weight_type TEXT NOT NULL,
              amount_kg REAL NOT NULL,
              notes TEXT NOT NULL DEFAULT '',
              created_at INTEGER NOT NULL
            )
          ''');
          // Create index for faster weight lookups
          await customStatement('''
            CREATE INDEX IF NOT EXISTS idx_dive_weights_dive_id ON dive_weights(dive_id)
          ''');
          // Migrate existing weight data from dives table to dive_weights
          await customStatement('''
            INSERT INTO dive_weights (id, dive_id, weight_type, amount_kg, notes, created_at)
            SELECT 
              'migrated_' || id,
              id,
              COALESCE(weight_type, 'belt'),
              COALESCE(weight_amount, 0),
              '',
              strftime('%s', 'now') * 1000
            FROM dives
            WHERE weight_amount IS NOT NULL AND weight_amount > 0
          ''');
        }
        if (from < 10) {
          // Migration v9 -> v10: Add entry/exit time fields for separate time tracking
          await customStatement('ALTER TABLE dives ADD COLUMN entry_time INTEGER');
          await customStatement('ALTER TABLE dives ADD COLUMN exit_time INTEGER');

          // Migrate existing data: use diveDateTime as entry_time and calculate exit_time from duration
          await customStatement('''
            UPDATE dives 
            SET entry_time = dive_date_time,
                exit_time = CASE 
                  WHEN duration IS NOT NULL THEN dive_date_time + (duration * 1000)
                  ELSE NULL
                END
          ''');
        }
        if (from < 11) {
          // Migration v10 -> v11: Add enhanced dive site fields
          await customStatement('ALTER TABLE dive_sites ADD COLUMN min_depth REAL');
          await customStatement('ALTER TABLE dive_sites ADD COLUMN difficulty TEXT');
          await customStatement('ALTER TABLE dive_sites ADD COLUMN hazards TEXT');
          await customStatement('ALTER TABLE dive_sites ADD COLUMN access_notes TEXT');
          await customStatement('ALTER TABLE dive_sites ADD COLUMN mooring_number TEXT');
          await customStatement('ALTER TABLE dive_sites ADD COLUMN parking_info TEXT');
        }
        if (from < 12) {
          // Migration v11 -> v12: Add custom dive types table
          await customStatement('''
            CREATE TABLE IF NOT EXISTS dive_types (
              id TEXT NOT NULL PRIMARY KEY,
              name TEXT NOT NULL,
              is_built_in INTEGER NOT NULL DEFAULT 0,
              sort_order INTEGER NOT NULL DEFAULT 0,
              created_at INTEGER NOT NULL,
              updated_at INTEGER NOT NULL
            )
          ''');

          // Create index for sorting
          await customStatement('''
            CREATE INDEX IF NOT EXISTS idx_dive_types_sort_order ON dive_types(sort_order)
          ''');

          // Seed built-in dive types from the existing enum values
          final now = DateTime.now().millisecondsSinceEpoch;
          final builtInTypes = [
            ('recreational', 'Recreational', 0),
            ('technical', 'Technical', 1),
            ('freedive', 'Freedive', 2),
            ('training', 'Training', 3),
            ('wreck', 'Wreck', 4),
            ('cave', 'Cave', 5),
            ('ice', 'Ice', 6),
            ('night', 'Night', 7),
            ('drift', 'Drift', 8),
            ('deep', 'Deep', 9),
            ('altitude', 'Altitude', 10),
            ('shore', 'Shore', 11),
            ('boat', 'Boat', 12),
            ('liveaboard', 'Liveaboard', 13),
          ];

          for (final type in builtInTypes) {
            await customStatement('''
              INSERT OR IGNORE INTO dive_types (id, name, is_built_in, sort_order, created_at, updated_at)
              VALUES ('${type.$1}', '${type.$2}', 1, ${type.$3}, $now, $now)
            ''');
          }
        }
      },
      beforeOpen: (details) async {
        // Enable foreign keys
        await customStatement('PRAGMA foreign_keys = ON');

        // Seed built-in dive types if table is empty (fresh install)
        final count = await customSelect(
          'SELECT COUNT(*) as cnt FROM dive_types',
        ).getSingleOrNull();

        if (count == null || (count.data['cnt'] as int) == 0) {
          final now = DateTime.now().millisecondsSinceEpoch;
          final builtInTypes = [
            ('recreational', 'Recreational', 0),
            ('technical', 'Technical', 1),
            ('freedive', 'Freedive', 2),
            ('training', 'Training', 3),
            ('wreck', 'Wreck', 4),
            ('cave', 'Cave', 5),
            ('ice', 'Ice', 6),
            ('night', 'Night', 7),
            ('drift', 'Drift', 8),
            ('deep', 'Deep', 9),
            ('altitude', 'Altitude', 10),
            ('shore', 'Shore', 11),
            ('boat', 'Boat', 12),
            ('liveaboard', 'Liveaboard', 13),
          ];

          for (final type in builtInTypes) {
            await customStatement('''
              INSERT OR IGNORE INTO dive_types (id, name, is_built_in, sort_order, created_at, updated_at)
              VALUES ('${type.$1}', '${type.$2}', 1, ${type.$3}, $now, $now)
            ''');
          }
        }
      },
    );
  }
}