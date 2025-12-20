import 'package:drift/drift.dart';

part 'database.g.dart';

// ============================================================================
// Table Definitions
// ============================================================================

/// Diver profiles (multi-account support)
class Divers extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get email => text().nullable()();
  TextColumn get phone => text().nullable()();
  TextColumn get photoPath => text().nullable()();
  // Emergency contact
  TextColumn get emergencyContactName => text().nullable()();
  TextColumn get emergencyContactPhone => text().nullable()();
  TextColumn get emergencyContactRelation => text().nullable()();
  // Medical info
  TextColumn get medicalNotes => text().withDefault(const Constant(''))();
  TextColumn get bloodType => text().nullable()();
  TextColumn get allergies => text().nullable()();
  // Insurance
  TextColumn get insuranceProvider => text().nullable()();
  TextColumn get insurancePolicyNumber => text().nullable()();
  IntColumn get insuranceExpiryDate => integer().nullable()(); // Unix timestamp
  // General
  TextColumn get notes => text().withDefault(const Constant(''))();
  BoolColumn get isDefault => boolean().withDefault(const Constant(false))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Dive trips (group of dives at a destination)
class Trips extends Table {
  TextColumn get id => text()();
  TextColumn get diverId => text().nullable().references(Divers, #id)();
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
  TextColumn get diverId => text().nullable().references(Divers, #id)();
  IntColumn get diveNumber => integer().nullable()();
  IntColumn get diveDateTime =>
      integer()(); // Unix timestamp (legacy, kept for compatibility)
  IntColumn get entryTime =>
      integer().nullable()(); // Unix timestamp - when diver entered water
  IntColumn get exitTime =>
      integer().nullable()(); // Unix timestamp - when diver exited water
  IntColumn get duration => integer().nullable()(); // seconds (bottom time)
  IntColumn get runtime => integer().nullable()(); // seconds (total runtime)
  RealColumn get maxDepth => real().nullable()();
  RealColumn get avgDepth => real().nullable()();
  RealColumn get waterTemp => real().nullable()();
  RealColumn get airTemp => real().nullable()();
  TextColumn get visibility => text().nullable()();
  TextColumn get diveType =>
      text().withDefault(const Constant('recreational'))();
  TextColumn get buddy => text().nullable()();
  TextColumn get diveMaster => text().nullable()();
  TextColumn get notes => text().withDefault(const Constant(''))();
  TextColumn get siteId => text().nullable().references(DiveSites, #id)();
  IntColumn get rating => integer().nullable()();
  // Dive center reference
  TextColumn get diveCenterId =>
      text().nullable().references(DiveCenters, #id)();
  // Trip reference
  TextColumn get tripId => text().nullable().references(Trips, #id)();
  // Conditions fields
  TextColumn get currentDirection => text().nullable()();
  TextColumn get currentStrength => text().nullable()();
  RealColumn get swellHeight => real().nullable()(); // meters
  TextColumn get entryMethod => text().nullable()();
  TextColumn get exitMethod => text().nullable()();
  TextColumn get waterType => text().nullable()();
  // Altitude for altitude diving
  RealColumn get altitude => real().nullable()(); // meters above sea level
  // Weight system fields
  RealColumn get weightAmount => real().nullable()(); // kg
  TextColumn get weightType => text().nullable()();
  // Favorite flag (v1.1)
  BoolColumn get isFavorite => boolean().withDefault(const Constant(false))();
  // Dive mode for CCR/SCR (v1.5)
  TextColumn get diveMode =>
      text().withDefault(const Constant('oc'))(); // oc, ccr, scr
  // O2 toxicity tracking (v1.5)
  RealColumn get cnsStart =>
      real().withDefault(const Constant(0))(); // CNS% at dive start
  RealColumn get cnsEnd => real().nullable()(); // CNS% at dive end
  RealColumn get otu => real().nullable()(); // OTU accumulated this dive
  // Primary computer used for this dive
  TextColumn get computerId =>
      text().nullable().references(DiveComputers, #id)();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Time-series dive profile data points
class DiveProfiles extends Table {
  TextColumn get id => text()();
  TextColumn get diveId =>
      text().references(Dives, #id, onDelete: KeyAction.cascade)();
  TextColumn get computerId =>
      text().nullable().references(DiveComputers, #id)();
  BoolColumn get isPrimary =>
      boolean().withDefault(const Constant(true))(); // Primary profile for stats
  IntColumn get timestamp => integer()(); // seconds from dive start
  RealColumn get depth => real()();
  RealColumn get pressure => real().nullable()(); // bar
  RealColumn get temperature => real().nullable()();
  IntColumn get heartRate => integer().nullable()();
  // Computed decompression data (optional, can be calculated on-the-fly)
  RealColumn get ascentRate => real().nullable()(); // m/min
  RealColumn get ceiling => real().nullable()(); // deco ceiling in meters
  IntColumn get ndl => integer().nullable()(); // no-deco limit in seconds

  @override
  Set<Column> get primaryKey => {id};
}

/// Dive sites/locations
class DiveSites extends Table {
  TextColumn get id => text()();
  TextColumn get diverId => text().nullable().references(Divers, #id)();
  TextColumn get name => text()();
  TextColumn get description => text().withDefault(const Constant(''))();
  RealColumn get latitude => real().nullable()();
  RealColumn get longitude => real().nullable()();
  RealColumn get minDepth => real().nullable()(); // Shallowest point
  RealColumn get maxDepth => real().nullable()(); // Deepest point
  TextColumn get difficulty =>
      text().nullable()(); // Beginner, Intermediate, Advanced, Technical
  TextColumn get country => text().nullable()();
  TextColumn get region => text().nullable()();
  RealColumn get rating => real().nullable()();
  TextColumn get notes => text().withDefault(const Constant(''))();
  TextColumn get hazards =>
      text().nullable()(); // Currents, boats, marine life, etc.
  TextColumn get accessNotes =>
      text().nullable()(); // How to get there, entry points
  TextColumn get mooringNumber =>
      text().nullable()(); // Mooring buoy number for boats
  TextColumn get parkingInfo =>
      text().nullable()(); // Parking availability and tips
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Tanks used during dives
class DiveTanks extends Table {
  TextColumn get id => text()();
  TextColumn get diveId =>
      text().references(Dives, #id, onDelete: KeyAction.cascade)();
  TextColumn get equipmentId => text().nullable().references(Equipment, #id)();
  RealColumn get volume => real().nullable()(); // liters
  IntColumn get workingPressure =>
      integer().nullable()(); // bar - rated pressure
  IntColumn get startPressure => integer().nullable()(); // bar
  IntColumn get endPressure => integer().nullable()(); // bar
  RealColumn get o2Percent => real().withDefault(const Constant(21.0))();
  RealColumn get hePercent => real().withDefault(const Constant(0.0))();
  IntColumn get tankOrder => integer().withDefault(const Constant(0))();
  TextColumn get tankRole => text().withDefault(
      const Constant('backGas'))(); // backGas, stage, deco, bailout, etc.
  TextColumn get tankMaterial =>
      text().nullable()(); // aluminum, steel, carbonFiber
  TextColumn get tankName =>
      text().nullable()(); // user-friendly name like "Primary AL80"

  @override
  Set<Column> get primaryKey => {id};
}

/// Equipment catalog
class Equipment extends Table {
  TextColumn get id => text()();
  TextColumn get diverId => text().nullable().references(Divers, #id)();
  TextColumn get name => text()();
  TextColumn get type => text()(); // regulator, bcd, wetsuit, etc.
  TextColumn get brand => text().nullable()();
  TextColumn get model => text().nullable()();
  TextColumn get serialNumber => text().nullable()();
  TextColumn get size => text().nullable()(); // S, M, L, XL, or specific size
  TextColumn get status => text().withDefault(
      const Constant('active'))(); // active, needsService, retired, etc.
  IntColumn get purchaseDate => integer().nullable()();
  RealColumn get purchasePrice => real().nullable()();
  TextColumn get purchaseCurrency =>
      text().withDefault(const Constant('USD'))();
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
  TextColumn get diveId =>
      text().references(Dives, #id, onDelete: KeyAction.cascade)();
  TextColumn get equipmentId =>
      text().references(Equipment, #id, onDelete: KeyAction.cascade)();

  @override
  Set<Column> get primaryKey => {diveId, equipmentId};
}

/// Multiple weight entries per dive (e.g., integrated + trim weights)
class DiveWeights extends Table {
  TextColumn get id => text()();
  TextColumn get diveId =>
      text().references(Dives, #id, onDelete: KeyAction.cascade)();
  TextColumn get weightType =>
      text()(); // Integrated, Belt, Trim, Ankle, Backplate, Other
  RealColumn get amountKg => real()(); // kg
  TextColumn get notes => text().withDefault(const Constant(''))();
  IntColumn get createdAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Equipment sets (named collections of equipment items)
class EquipmentSets extends Table {
  TextColumn get id => text()();
  TextColumn get diverId => text().nullable().references(Divers, #id)();
  TextColumn get name => text()();
  TextColumn get description => text().withDefault(const Constant(''))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Junction table for equipment items in sets
class EquipmentSetItems extends Table {
  TextColumn get setId =>
      text().references(EquipmentSets, #id, onDelete: KeyAction.cascade)();
  TextColumn get equipmentId =>
      text().references(Equipment, #id, onDelete: KeyAction.cascade)();

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
  TextColumn get diveId =>
      text().references(Dives, #id, onDelete: KeyAction.cascade)();
  TextColumn get speciesId => text().references(Species, #id)();
  IntColumn get count => integer().withDefault(const Constant(1))();
  TextColumn get notes => text().withDefault(const Constant(''))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Photos and media files
class Media extends Table {
  TextColumn get id => text()();
  TextColumn get diveId =>
      text().nullable().references(Dives, #id, onDelete: KeyAction.setNull)();
  TextColumn get siteId => text()
      .nullable()
      .references(DiveSites, #id, onDelete: KeyAction.setNull)();
  TextColumn get filePath => text()();
  TextColumn get fileType => text().withDefault(const Constant('photo'))();
  RealColumn get latitude => real().nullable()();
  RealColumn get longitude => real().nullable()();
  IntColumn get takenAt => integer().nullable()();
  TextColumn get caption => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Application settings key-value store (legacy - kept for backward compatibility)
class Settings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text().nullable()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {key};
}

/// Per-diver settings (v16)
class DiverSettings extends Table {
  TextColumn get id => text()();
  TextColumn get diverId => text().references(Divers, #id)();
  // Unit settings
  TextColumn get depthUnit =>
      text().withDefault(const Constant('meters'))();
  TextColumn get temperatureUnit =>
      text().withDefault(const Constant('celsius'))();
  TextColumn get pressureUnit =>
      text().withDefault(const Constant('bar'))();
  TextColumn get volumeUnit =>
      text().withDefault(const Constant('liters'))();
  TextColumn get weightUnit =>
      text().withDefault(const Constant('kilograms'))();
  // Theme
  TextColumn get themeMode =>
      text().withDefault(const Constant('system'))();
  // Defaults
  TextColumn get defaultDiveType =>
      text().withDefault(const Constant('recreational'))();
  RealColumn get defaultTankVolume =>
      real().withDefault(const Constant(12.0))();
  IntColumn get defaultStartPressure =>
      integer().withDefault(const Constant(200))();
  // Decompression settings
  IntColumn get gfLow =>
      integer().withDefault(const Constant(30))();
  IntColumn get gfHigh =>
      integer().withDefault(const Constant(70))();
  RealColumn get ppO2MaxWorking =>
      real().withDefault(const Constant(1.4))();
  RealColumn get ppO2MaxDeco =>
      real().withDefault(const Constant(1.6))();
  IntColumn get cnsWarningThreshold =>
      integer().withDefault(const Constant(80))();
  RealColumn get ascentRateWarning =>
      real().withDefault(const Constant(9.0))();
  RealColumn get ascentRateCritical =>
      real().withDefault(const Constant(12.0))();
  BoolColumn get showCeilingOnProfile =>
      boolean().withDefault(const Constant(true))();
  BoolColumn get showAscentRateColors =>
      boolean().withDefault(const Constant(true))();
  BoolColumn get showNdlOnProfile =>
      boolean().withDefault(const Constant(true))();
  RealColumn get lastStopDepth =>
      real().withDefault(const Constant(3.0))();
  RealColumn get decoStopIncrement =>
      real().withDefault(const Constant(3.0))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Dive buddies contact list
class Buddies extends Table {
  TextColumn get id => text()();
  TextColumn get diverId => text().nullable().references(Divers, #id)();
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
  TextColumn get diveId =>
      text().references(Dives, #id, onDelete: KeyAction.cascade)();
  TextColumn get buddyId =>
      text().references(Buddies, #id, onDelete: KeyAction.cascade)();
  TextColumn get role => text().withDefault(const Constant('buddy'))();
  IntColumn get createdAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Diver certifications
class Certifications extends Table {
  TextColumn get id => text()();
  TextColumn get diverId => text().nullable().references(Divers, #id)();
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
  TextColumn get equipmentId =>
      text().references(Equipment, #id, onDelete: KeyAction.cascade)();
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
  TextColumn get diverId => text().nullable().references(Divers, #id)();
  TextColumn get name => text()();
  TextColumn get location => text().nullable()();
  RealColumn get latitude => real().nullable()();
  RealColumn get longitude => real().nullable()();
  TextColumn get country => text().nullable()();
  TextColumn get phone => text().nullable()();
  TextColumn get email => text().nullable()();
  TextColumn get website => text().nullable()();
  TextColumn get affiliations =>
      text().nullable()(); // PADI, SSI, etc. comma-separated
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
  TextColumn get diverId => text().nullable().references(Divers, #id)();
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
  TextColumn get diverId =>
      text().nullable().references(Divers, #id)(); // null for built-in types
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
  TextColumn get diveId =>
      text().references(Dives, #id, onDelete: KeyAction.cascade)();
  TextColumn get tagId =>
      text().references(Tags, #id, onDelete: KeyAction.cascade)();
  IntColumn get createdAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Dive computers (devices that record dive data)
class DiveComputers extends Table {
  TextColumn get id => text()();
  TextColumn get diverId => text().nullable().references(Divers, #id)();
  TextColumn get name => text()(); // User-friendly name e.g., "My Perdix"
  TextColumn get manufacturer => text().nullable()(); // e.g., "Shearwater"
  TextColumn get model => text().nullable()(); // e.g., "Perdix AI"
  TextColumn get serialNumber => text().nullable()();
  TextColumn get connectionType =>
      text().nullable()(); // "bluetooth", "usb", "ble"
  TextColumn get bluetoothAddress => text().nullable()(); // MAC address
  IntColumn get lastDownloadTimestamp =>
      integer().nullable()(); // Unix timestamp
  IntColumn get diveCount => integer().withDefault(const Constant(0))();
  BoolColumn get isFavorite => boolean().withDefault(const Constant(false))();
  TextColumn get notes => text().withDefault(const Constant(''))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Profile events (markers on dive profile)
class DiveProfileEvents extends Table {
  TextColumn get id => text()();
  TextColumn get diveId =>
      text().references(Dives, #id, onDelete: KeyAction.cascade)();
  IntColumn get timestamp => integer()(); // seconds from dive start
  TextColumn get eventType => text()(); // See ProfileEventType enum
  TextColumn get severity =>
      text().withDefault(const Constant('info'))(); // info, warning, alert
  TextColumn get description => text().nullable()();
  RealColumn get depth => real().nullable()(); // depth at event (meters)
  RealColumn get value =>
      real().nullable()(); // event-specific value (e.g., ascent rate)
  TextColumn get tankId => text().nullable()(); // for gas switch events
  IntColumn get createdAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Gas switches during a dive
class GasSwitches extends Table {
  TextColumn get id => text()();
  TextColumn get diveId =>
      text().references(Dives, #id, onDelete: KeyAction.cascade)();
  IntColumn get timestamp => integer()(); // seconds from dive start
  TextColumn get tankId =>
      text().references(DiveTanks, #id, onDelete: KeyAction.cascade)();
  RealColumn get depth => real().nullable()(); // depth at switch (meters)
  IntColumn get createdAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

// ============================================================================
// Database Class
// ============================================================================

@DriftDatabase(
  tables: [
    Divers,
    DiverSettings,
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
    DiveComputers,
    DiveProfileEvents,
    GasSwitches,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();

        // Seed built-in dive types
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
      },
      beforeOpen: (details) async {
        // Enable foreign keys
        await customStatement('PRAGMA foreign_keys = ON');
      },
    );
  }
}
