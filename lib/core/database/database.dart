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
  TextColumn get medications => text().nullable()();
  IntColumn get medicalClearanceExpiryDate =>
      integer().nullable()(); // Unix timestamp
  // Secondary emergency contact
  TextColumn get emergencyContact2Name => text().nullable()();
  TextColumn get emergencyContact2Phone => text().nullable()();
  TextColumn get emergencyContact2Relation => text().nullable()();
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
  // Surface pressure for altitude/weather corrections
  RealColumn get surfacePressure => real().nullable()(); // bar (default ~1.013)
  // Surface interval before this dive
  IntColumn get surfaceIntervalSeconds => integer().nullable()(); // seconds
  // Decompression gradient factors
  IntColumn get gradientFactorLow => integer().nullable()(); // 0-100
  IntColumn get gradientFactorHigh => integer().nullable()(); // 0-100
  // Dive computer that logged this dive (for display/export, separate from computerId relation)
  TextColumn get diveComputerModel => text().nullable()();
  TextColumn get diveComputerSerial => text().nullable()();
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

  // CCR Setpoints (v1.5) - in bar
  RealColumn get setpointLow =>
      real().nullable()(); // ~0.7 bar for descent/ascent
  RealColumn get setpointHigh => real().nullable()(); // ~1.2-1.3 bar for bottom
  RealColumn get setpointDeco => real().nullable()(); // ~1.3-1.6 bar for deco

  // SCR Configuration (v1.5)
  TextColumn get scrType => text().nullable()(); // 'cmf', 'pascr', 'escr'
  RealColumn get scrInjectionRate =>
      real().nullable()(); // L/min at surface (CMF)
  RealColumn get scrAdditionRatio =>
      real().nullable()(); // e.g., 0.33 for 1:3 (PASCR)
  TextColumn get scrOrificeSize =>
      text().nullable()(); // '40', '50', '60' (Dolphin)
  RealColumn get assumedVo2 =>
      real().nullable()(); // Assumed O2 consumption L/min

  // Diluent/Supply Gas (v1.5) - quick reference for CCR/SCR
  RealColumn get diluentO2 => real().nullable()(); // Diluent/supply O2%
  RealColumn get diluentHe => real().nullable()(); // Diluent/supply He%

  // Loop FO2 measurements (v1.5) - for SCR dives
  RealColumn get loopO2Min => real().nullable()(); // Min loop O2%
  RealColumn get loopO2Max => real().nullable()(); // Max loop O2%
  RealColumn get loopO2Avg => real().nullable()(); // Avg loop O2%

  // Shared rebreather fields (v1.5)
  RealColumn get loopVolume => real().nullable()(); // Loop volume in liters
  TextColumn get scrubberType => text().nullable()(); // e.g., 'Sofnolime 797'
  IntColumn get scrubberDurationMinutes =>
      integer().nullable()(); // Rated scrubber duration
  IntColumn get scrubberRemainingMinutes =>
      integer().nullable()(); // Remaining at dive start

  // Dive planner flag (v1.5)
  BoolColumn get isPlanned =>
      boolean().withDefault(const Constant(false))(); // True for planned dives

  // Primary computer used for this dive
  TextColumn get computerId =>
      text().nullable().references(DiveComputers, #id)();
  // Training course this dive belongs to (v1.5)
  TextColumn get courseId =>
      text().nullable().references(Courses, #id, onDelete: KeyAction.setNull)();
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
  BoolColumn get isPrimary => boolean().withDefault(
    const Constant(true),
  )(); // Primary profile for stats
  IntColumn get timestamp => integer()(); // seconds from dive start
  RealColumn get depth => real()();
  RealColumn get pressure => real().nullable()(); // bar
  RealColumn get temperature => real().nullable()();
  IntColumn get heartRate => integer().nullable()();
  // Computed decompression data (optional, can be calculated on-the-fly)
  RealColumn get ascentRate => real().nullable()(); // m/min
  RealColumn get ceiling => real().nullable()(); // deco ceiling in meters
  IntColumn get ndl => integer().nullable()(); // no-deco limit in seconds

  // CCR/SCR rebreather data (v1.5)
  RealColumn get setpoint =>
      real().nullable()(); // Current setpoint at sample (bar)
  RealColumn get ppO2 => real().nullable()(); // Measured/calculated ppO2 (bar)

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
  RealColumn get altitude => real()
      .nullable()(); // Altitude above sea level in meters (for altitude diving)
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
    const Constant('backGas'),
  )(); // backGas, stage, deco, bailout, etc.
  TextColumn get tankMaterial =>
      text().nullable()(); // aluminum, steel, carbonFiber
  TextColumn get tankName =>
      text().nullable()(); // user-friendly name like "Primary AL80"
  TextColumn get presetName =>
      text().nullable()(); // preset name (e.g., 'al80', 'hp100')

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
    const Constant('active'),
  )(); // active, needsService, retired, etc.
  IntColumn get purchaseDate => integer().nullable()();
  RealColumn get purchasePrice => real().nullable()();
  TextColumn get purchaseCurrency =>
      text().withDefault(const Constant('USD'))();
  IntColumn get lastServiceDate => integer().nullable()();
  IntColumn get serviceIntervalDays => integer().nullable()();
  TextColumn get notes => text().withDefault(const Constant(''))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  // Notification overrides (v27)
  BoolColumn get customReminderEnabled => boolean()
      .nullable()(); // NULL = use global, true = custom, false = disabled
  TextColumn get customReminderDays =>
      text().nullable()(); // JSON array override, e.g. "[7, 30]"
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

/// Photos and media files (also used for signatures)
class Media extends Table {
  TextColumn get id => text()();
  TextColumn get diveId =>
      text().nullable().references(Dives, #id, onDelete: KeyAction.setNull)();
  TextColumn get siteId => text().nullable().references(
    DiveSites,
    #id,
    onDelete: KeyAction.setNull,
  )();
  TextColumn get filePath => text()();
  TextColumn get fileType => text().withDefault(
    const Constant('photo'),
  )(); // photo, video, instructor_signature
  RealColumn get latitude => real().nullable()();
  RealColumn get longitude => real().nullable()();
  IntColumn get takenAt => integer().nullable()();
  TextColumn get caption => text().nullable()();
  // Signature fields (v1.5) - used when fileType='instructor_signature'
  TextColumn get signerId =>
      text().nullable().references(Buddies, #id, onDelete: KeyAction.setNull)();
  TextColumn get signerName => text().nullable()();
  // Signature type (v22) - distinguishes instructor vs buddy signatures
  TextColumn get signatureType => text().nullable()(); // 'instructor' | 'buddy'
  // Signature image data (v23) - stores signature as BLOB instead of file
  BlobColumn get imageData => blob().nullable()();
  // Gallery photo fields (v2.0) - for underwater photography feature
  TextColumn get platformAssetId =>
      text().nullable()(); // Platform-specific asset ID for gallery photos
  TextColumn get originalFilename => text().nullable()();
  IntColumn get width => integer().nullable()();
  IntColumn get height => integer().nullable()();
  IntColumn get durationSeconds => integer().nullable()(); // For videos
  BoolColumn get isFavorite => boolean().withDefault(const Constant(false))();
  IntColumn get thumbnailGeneratedAt => integer().nullable()();
  IntColumn get lastVerifiedAt => integer().nullable()();
  BoolColumn get isOrphaned => boolean().withDefault(const Constant(false))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Enrichment data calculated from dive profile at photo timestamp
class MediaEnrichment extends Table {
  TextColumn get id => text()();
  TextColumn get mediaId =>
      text().references(Media, #id, onDelete: KeyAction.cascade)();
  TextColumn get diveId =>
      text().references(Dives, #id, onDelete: KeyAction.cascade)();
  // Calculated from dive profile at photo timestamp
  RealColumn get depthMeters => real().nullable()();
  RealColumn get temperatureCelsius => real().nullable()();
  IntColumn get elapsedSeconds => integer().nullable()();
  // Confidence/quality
  TextColumn get matchConfidence => text().withDefault(
    const Constant('exact'),
  )(); // exact, interpolated, estimated, no_profile
  IntColumn get timestampOffsetSeconds => integer().nullable()();
  IntColumn get createdAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Species tags on media (many-to-many with optional spatial annotation)
class MediaSpecies extends Table {
  TextColumn get id => text()();
  TextColumn get mediaId =>
      text().references(Media, #id, onDelete: KeyAction.cascade)();
  TextColumn get speciesId =>
      text().references(Species, #id, onDelete: KeyAction.cascade)();
  TextColumn get sightingId => text().nullable().references(
    Sightings,
    #id,
    onDelete: KeyAction.setNull,
  )();
  // Reserved for future spatial annotation (nullable for now)
  RealColumn get bboxX => real().nullable()();
  RealColumn get bboxY => real().nullable()();
  RealColumn get bboxWidth => real().nullable()();
  RealColumn get bboxHeight => real().nullable()();
  TextColumn get notes => text().nullable()();
  IntColumn get createdAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Pending photo suggestions for background scan feature
class PendingPhotoSuggestions extends Table {
  TextColumn get id => text()();
  TextColumn get diveId =>
      text().references(Dives, #id, onDelete: KeyAction.cascade)();
  TextColumn get platformAssetId => text()();
  IntColumn get takenAt => integer()();
  TextColumn get thumbnailPath => text().nullable()();
  BoolColumn get dismissed => boolean().withDefault(const Constant(false))();
  IntColumn get createdAt => integer()();

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
  TextColumn get depthUnit => text().withDefault(const Constant('meters'))();
  TextColumn get temperatureUnit =>
      text().withDefault(const Constant('celsius'))();
  TextColumn get pressureUnit => text().withDefault(const Constant('bar'))();
  TextColumn get volumeUnit => text().withDefault(const Constant('liters'))();
  TextColumn get weightUnit =>
      text().withDefault(const Constant('kilograms'))();
  TextColumn get altitudeUnit => text().withDefault(const Constant('meters'))();
  TextColumn get sacUnit =>
      text().withDefault(const Constant('litersPerMin'))();
  // Time/Date format settings
  TextColumn get timeFormat =>
      text().withDefault(const Constant('twelveHour'))();
  TextColumn get dateFormat => text().withDefault(const Constant('mmmDYYYY'))();
  // Theme
  TextColumn get themeMode => text().withDefault(const Constant('system'))();
  // Defaults
  TextColumn get defaultDiveType =>
      text().withDefault(const Constant('recreational'))();
  RealColumn get defaultTankVolume =>
      real().withDefault(const Constant(12.0))();
  IntColumn get defaultStartPressure =>
      integer().withDefault(const Constant(200))();
  // Decompression settings
  IntColumn get gfLow => integer().withDefault(const Constant(30))();
  IntColumn get gfHigh => integer().withDefault(const Constant(70))();
  RealColumn get ppO2MaxWorking => real().withDefault(const Constant(1.4))();
  RealColumn get ppO2MaxDeco => real().withDefault(const Constant(1.6))();
  IntColumn get cnsWarningThreshold =>
      integer().withDefault(const Constant(80))();
  RealColumn get ascentRateWarning => real().withDefault(const Constant(9.0))();
  RealColumn get ascentRateCritical =>
      real().withDefault(const Constant(12.0))();
  BoolColumn get showCeilingOnProfile =>
      boolean().withDefault(const Constant(true))();
  BoolColumn get showAscentRateColors =>
      boolean().withDefault(const Constant(true))();
  BoolColumn get showNdlOnProfile =>
      boolean().withDefault(const Constant(true))();
  RealColumn get lastStopDepth => real().withDefault(const Constant(3.0))();
  RealColumn get decoStopIncrement => real().withDefault(const Constant(3.0))();
  // Appearance settings
  BoolColumn get showDepthColoredDiveCards =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get showMapBackgroundOnDiveCards =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get showMapBackgroundOnSiteCards =>
      boolean().withDefault(const Constant(false))();
  // Dive profile markers
  BoolColumn get showMaxDepthMarker =>
      boolean().withDefault(const Constant(true))();
  BoolColumn get showPressureThresholdMarkers =>
      boolean().withDefault(const Constant(false))();
  // Notification settings (v26)
  BoolColumn get notificationsEnabled =>
      boolean().withDefault(const Constant(true))();
  TextColumn get serviceReminderDays =>
      text().withDefault(const Constant('[7, 14, 30]'))(); // JSON array
  TextColumn get reminderTime =>
      text().withDefault(const Constant('09:00'))(); // HH:mm format
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
  TextColumn get photoFrontPath => text()
      .nullable()(); // Front of cert card (deprecated, kept for migration)
  TextColumn get photoBackPath =>
      text().nullable()(); // Back of cert card (deprecated, kept for migration)
  BlobColumn get photoFront => blob().nullable()(); // Front of cert card (BLOB)
  BlobColumn get photoBack => blob().nullable()(); // Back of cert card (BLOB)
  // Link to training course (bidirectional, v1.5)
  TextColumn get courseId =>
      text().nullable().references(Courses, #id, onDelete: KeyAction.setNull)();
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
  TextColumn get street => text().nullable()(); // Street address
  TextColumn get city => text().nullable()();
  TextColumn get stateProvince =>
      text().nullable()(); // State, province, or region
  TextColumn get postalCode => text().nullable()();
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

/// Custom tank presets (user-defined tank configurations)
class TankPresets extends Table {
  TextColumn get id => text()();
  TextColumn get diverId =>
      text().nullable().references(Divers, #id)(); // Owner of preset
  TextColumn get name => text()(); // Internal name/identifier
  TextColumn get displayName => text()(); // User-friendly display name
  RealColumn get volumeLiters => real()(); // Water volume in liters
  IntColumn get workingPressureBar => integer()(); // Rated working pressure
  TextColumn get material => text()(); // aluminum, steel, carbonFiber
  TextColumn get description =>
      text().withDefault(const Constant(''))(); // Optional description
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

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

/// Per-tank time-series pressure data for multi-tank dives
/// Enables visualization of pressure curves for each tank (AI transmitters)
class TankPressureProfiles extends Table {
  TextColumn get id => text()();
  TextColumn get diveId =>
      text().references(Dives, #id, onDelete: KeyAction.cascade)();
  TextColumn get tankId =>
      text().references(DiveTanks, #id, onDelete: KeyAction.cascade)();
  IntColumn get timestamp => integer()(); // seconds from dive start
  RealColumn get pressure => real()(); // bar

  @override
  Set<Column> get primaryKey => {id};
}

/// Tide data recorded with a dive for historical reference.
///
/// Stores the tide conditions at the time of a dive, including:
/// - Current height and state (rising/falling)
/// - Nearby high and low tide information
///
/// This enables post-dive analysis of conditions and correlation with dive quality.
class TideRecords extends Table {
  TextColumn get id => text()();
  TextColumn get diveId =>
      text().references(Dives, #id, onDelete: KeyAction.cascade)();
  // Current tide at dive time
  RealColumn get heightMeters => real()(); // Tide height at dive start
  TextColumn get tideState => text()(); // rising, falling, slackHigh, slackLow
  RealColumn get rateOfChange =>
      real().nullable()(); // meters per hour (positive = rising)
  // Nearby high tide
  RealColumn get highTideHeight => real().nullable()(); // Height at high tide
  IntColumn get highTideTime =>
      integer().nullable()(); // Unix timestamp of high tide
  // Nearby low tide
  RealColumn get lowTideHeight => real().nullable()(); // Height at low tide
  IntColumn get lowTideTime =>
      integer().nullable()(); // Unix timestamp of low tide
  IntColumn get createdAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

// ============================================================================
// Sync Tables
// ============================================================================

/// Global sync metadata - tracks sync state for this device
class SyncMetadata extends Table {
  TextColumn get id => text()(); // Always 'global' for single record
  IntColumn get lastSyncTimestamp =>
      integer().nullable()(); // Unix timestamp ms of last successful sync
  TextColumn get deviceId => text()(); // This device's unique UUID
  TextColumn get syncProvider =>
      text().nullable()(); // 'icloud' or 'googledrive'
  TextColumn get remoteFileId =>
      text().nullable()(); // Provider-specific file reference
  IntColumn get syncVersion =>
      integer().withDefault(const Constant(1))(); // Sync format version
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Per-record sync tracking for conflict detection
class SyncRecords extends Table {
  TextColumn get id => text()();
  TextColumn get entityType => text()(); // e.g., 'dives', 'dive_sites'
  TextColumn get recordId => text()(); // Primary key of the synced record
  IntColumn get localUpdatedAt => integer()(); // Local modification timestamp
  IntColumn get syncedAt => integer().nullable()(); // When last synced to cloud
  TextColumn get syncStatus => text().withDefault(
    const Constant('synced'),
  )(); // synced, pending, conflict
  TextColumn get conflictData =>
      text().nullable()(); // JSON of conflicting remote data
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Deletion log for tracking deleted records during sync
class DeletionLog extends Table {
  TextColumn get id => text()();
  TextColumn get entityType => text()(); // Which table the record was in
  TextColumn get recordId => text()(); // Primary key of deleted record
  IntColumn get deletedAt => integer()(); // Unix timestamp of deletion

  @override
  Set<Column> get primaryKey => {id};
}

/// Cached map regions for offline use
class CachedRegions extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  RealColumn get minLat => real()();
  RealColumn get maxLat => real()();
  RealColumn get minLng => real()();
  RealColumn get maxLng => real()();
  IntColumn get minZoom => integer()();
  IntColumn get maxZoom => integer()();
  IntColumn get tileCount => integer()();
  IntColumn get sizeBytes => integer()();
  IntColumn get createdAt => integer()();
  IntColumn get lastAccessedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Training courses (e.g., "Advanced Open Water", "Rescue Diver")
class Courses extends Table {
  TextColumn get id => text()();
  TextColumn get diverId =>
      text().references(Divers, #id, onDelete: KeyAction.cascade)();
  TextColumn get name => text()(); // e.g., "Advanced Open Water Diver"
  TextColumn get agency => text()(); // CertificationAgency enum
  IntColumn get startDate => integer()(); // Unix timestamp
  IntColumn get completionDate => integer().nullable()(); // null = in progress
  // Instructor can be a buddy reference OR just text fields
  TextColumn get instructorId =>
      text().nullable().references(Buddies, #id, onDelete: KeyAction.setNull)();
  TextColumn get instructorName => text().nullable()(); // Text fallback
  TextColumn get instructorNumber =>
      text().nullable()(); // Instructor cert number
  // Link to earned certification (bidirectional)
  TextColumn get certificationId => text().nullable().references(
    Certifications,
    #id,
    onDelete: KeyAction.setNull,
  )();
  TextColumn get location => text().nullable()(); // Dive center/shop
  TextColumn get notes => text().withDefault(const Constant(''))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Junction table for expected species at dive sites (manual curation)
class SiteSpecies extends Table {
  TextColumn get id => text()();
  TextColumn get siteId =>
      text().references(DiveSites, #id, onDelete: KeyAction.cascade)();
  TextColumn get speciesId =>
      text().references(Species, #id, onDelete: KeyAction.cascade)();
  TextColumn get notes => text().withDefault(const Constant(''))();
  IntColumn get createdAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Tracks scheduled notifications to enable smart rescheduling
class ScheduledNotifications extends Table {
  TextColumn get id => text()();
  TextColumn get equipmentId =>
      text().references(Equipment, #id, onDelete: KeyAction.cascade)();
  IntColumn get scheduledDate => integer()(); // Unix timestamp
  IntColumn get reminderDaysBefore => integer()(); // 7, 14, or 30
  IntColumn get notificationId => integer()(); // Platform notification ID
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
    MediaEnrichment,
    MediaSpecies,
    PendingPhotoSuggestions,
    Settings,
    Buddies,
    DiveBuddies,
    Certifications,
    ServiceRecords,
    DiveCenters,
    Tags,
    DiveTags,
    DiveTypes,
    TankPresets,
    DiveComputers,
    DiveProfileEvents,
    GasSwitches,
    TankPressureProfiles,
    TideRecords,
    // Site-species junction
    SiteSpecies,
    // Training courses (v1.5)
    Courses,
    // Sync tables
    SyncMetadata,
    SyncRecords,
    DeletionLog,
    // Maps & Visualization
    CachedRegions,
    // Notifications
    ScheduledNotifications,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 28;

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
      onUpgrade: (Migrator m, int from, int to) async {
        if (from < 2) {
          // Add sacUnit column to diver_settings
          await customStatement(
            "ALTER TABLE diver_settings ADD COLUMN sac_unit TEXT NOT NULL DEFAULT 'litersPerMin'",
          );
        }
        if (from < 3) {
          // Add presetName column to dive_tanks
          await customStatement(
            'ALTER TABLE dive_tanks ADD COLUMN preset_name TEXT',
          );
        }
        if (from < 4) {
          // Add sync tables for cloud sync feature
          await customStatement('''
            CREATE TABLE IF NOT EXISTS sync_metadata (
              id TEXT NOT NULL PRIMARY KEY,
              last_sync_timestamp INTEGER,
              device_id TEXT NOT NULL,
              sync_provider TEXT,
              remote_file_id TEXT,
              sync_version INTEGER NOT NULL DEFAULT 1,
              created_at INTEGER NOT NULL,
              updated_at INTEGER NOT NULL
            )
          ''');
          await customStatement('''
            CREATE TABLE IF NOT EXISTS sync_records (
              id TEXT NOT NULL PRIMARY KEY,
              entity_type TEXT NOT NULL,
              record_id TEXT NOT NULL,
              local_updated_at INTEGER NOT NULL,
              synced_at INTEGER,
              sync_status TEXT NOT NULL DEFAULT 'synced',
              conflict_data TEXT,
              created_at INTEGER NOT NULL,
              updated_at INTEGER NOT NULL
            )
          ''');
          await customStatement('''
            CREATE TABLE IF NOT EXISTS deletion_log (
              id TEXT NOT NULL PRIMARY KEY,
              entity_type TEXT NOT NULL,
              record_id TEXT NOT NULL,
              deleted_at INTEGER NOT NULL
            )
          ''');
        }
        if (from < 5) {
          // Add showMapBackgroundOnDiveCards column to diver_settings
          await customStatement(
            'ALTER TABLE diver_settings ADD COLUMN show_map_background_on_dive_cards INTEGER NOT NULL DEFAULT 0',
          );
        }
        if (from < 6) {
          // Add showMapBackgroundOnSiteCards column to diver_settings
          await customStatement(
            'ALTER TABLE diver_settings ADD COLUMN show_map_background_on_site_cards INTEGER NOT NULL DEFAULT 0',
          );
        }
        if (from < 7) {
          // Add showDepthColoredDiveCards column to diver_settings (was missing migration)
          await customStatement(
            'ALTER TABLE diver_settings ADD COLUMN show_depth_colored_dive_cards INTEGER NOT NULL DEFAULT 0',
          );
        }
        if (from < 8) {
          // Add dive profile marker settings
          await customStatement(
            'ALTER TABLE diver_settings ADD COLUMN show_max_depth_marker INTEGER NOT NULL DEFAULT 1',
          );
          await customStatement(
            'ALTER TABLE diver_settings ADD COLUMN show_pressure_threshold_markers INTEGER NOT NULL DEFAULT 0',
          );
        }
        if (from < 9) {
          // Add per-tank pressure profiles for multi-tank visualization
          await customStatement('''
            CREATE TABLE IF NOT EXISTS tank_pressure_profiles (
              id TEXT NOT NULL PRIMARY KEY,
              dive_id TEXT NOT NULL REFERENCES dives(id) ON DELETE CASCADE,
              tank_id TEXT NOT NULL REFERENCES dive_tanks(id) ON DELETE CASCADE,
              timestamp INTEGER NOT NULL,
              pressure REAL NOT NULL
            )
          ''');
          // Index for efficient queries by dive and tank
          await customStatement('''
            CREATE INDEX IF NOT EXISTS idx_tank_pressure_dive_tank
            ON tank_pressure_profiles(dive_id, tank_id, timestamp)
          ''');
        }
        if (from < 10) {
          // Add time/date format columns to diver_settings
          await customStatement(
            "ALTER TABLE diver_settings ADD COLUMN time_format TEXT NOT NULL DEFAULT 'twelveHour'",
          );
          await customStatement(
            "ALTER TABLE diver_settings ADD COLUMN date_format TEXT NOT NULL DEFAULT 'mmmDYYYY'",
          );
        }
        if (from < 11) {
          // CCR/SCR Rebreather Support (v1.5)

          // CCR Setpoints (bar)
          await customStatement(
            'ALTER TABLE dives ADD COLUMN setpoint_low REAL',
          );
          await customStatement(
            'ALTER TABLE dives ADD COLUMN setpoint_high REAL',
          );
          await customStatement(
            'ALTER TABLE dives ADD COLUMN setpoint_deco REAL',
          );

          // SCR Configuration
          await customStatement('ALTER TABLE dives ADD COLUMN scr_type TEXT');
          await customStatement(
            'ALTER TABLE dives ADD COLUMN scr_injection_rate REAL',
          );
          await customStatement(
            'ALTER TABLE dives ADD COLUMN scr_addition_ratio REAL',
          );
          await customStatement(
            'ALTER TABLE dives ADD COLUMN scr_orifice_size TEXT',
          );
          await customStatement(
            'ALTER TABLE dives ADD COLUMN assumed_vo2 REAL',
          );

          // Diluent/Supply Gas
          await customStatement('ALTER TABLE dives ADD COLUMN diluent_o2 REAL');
          await customStatement('ALTER TABLE dives ADD COLUMN diluent_he REAL');

          // Loop FO2 measurements (SCR)
          await customStatement(
            'ALTER TABLE dives ADD COLUMN loop_o2_min REAL',
          );
          await customStatement(
            'ALTER TABLE dives ADD COLUMN loop_o2_max REAL',
          );
          await customStatement(
            'ALTER TABLE dives ADD COLUMN loop_o2_avg REAL',
          );

          // Shared rebreather fields
          await customStatement(
            'ALTER TABLE dives ADD COLUMN loop_volume REAL',
          );
          await customStatement(
            'ALTER TABLE dives ADD COLUMN scrubber_type TEXT',
          );
          await customStatement(
            'ALTER TABLE dives ADD COLUMN scrubber_duration_minutes INTEGER',
          );
          await customStatement(
            'ALTER TABLE dives ADD COLUMN scrubber_remaining_minutes INTEGER',
          );

          // DiveProfiles CCR/SCR fields
          await customStatement(
            'ALTER TABLE dive_profiles ADD COLUMN setpoint REAL',
          );
          await customStatement(
            'ALTER TABLE dive_profiles ADD COLUMN pp_o2 REAL',
          );
        }
        if (from < 12) {
          // Add isPlanned column for dive planner feature
          await customStatement(
            'ALTER TABLE dives ADD COLUMN is_planned INTEGER NOT NULL DEFAULT 0',
          );
        }
        if (from < 13) {
          // Add custom tank presets table
          await customStatement('''
            CREATE TABLE IF NOT EXISTS tank_presets (
              id TEXT NOT NULL PRIMARY KEY,
              diver_id TEXT REFERENCES divers(id),
              name TEXT NOT NULL,
              display_name TEXT NOT NULL,
              volume_liters REAL NOT NULL,
              working_pressure_bar INTEGER NOT NULL,
              material TEXT NOT NULL,
              description TEXT NOT NULL DEFAULT '',
              sort_order INTEGER NOT NULL DEFAULT 0,
              created_at INTEGER NOT NULL,
              updated_at INTEGER NOT NULL
            )
          ''');
        }
        if (from < 14) {
          // Add tide records table for storing tide data with dives
          await customStatement('''
            CREATE TABLE IF NOT EXISTS tide_records (
              id TEXT NOT NULL PRIMARY KEY,
              dive_id TEXT NOT NULL REFERENCES dives(id) ON DELETE CASCADE,
              height_meters REAL NOT NULL,
              tide_state TEXT NOT NULL,
              rate_of_change REAL,
              high_tide_height REAL,
              high_tide_time INTEGER,
              low_tide_height REAL,
              low_tide_time INTEGER,
              created_at INTEGER NOT NULL
            )
          ''');
          // Index for efficient lookup by dive
          await customStatement('''
            CREATE INDEX IF NOT EXISTS idx_tide_records_dive
            ON tide_records(dive_id)
          ''');
        }
        if (from < 15) {
          // Add index on dive_profiles.dive_id for faster profile loading
          // This table has 160K+ rows and is queried frequently by dive_id
          await customStatement('''
            CREATE INDEX IF NOT EXISTS idx_dive_profiles_dive_id
            ON dive_profiles(dive_id)
          ''');
          // Add composite index on sync_records for efficient pending/conflict lookups
          await customStatement('''
            CREATE INDEX IF NOT EXISTS idx_sync_records_entity_record
            ON sync_records(entity_type, record_id)
          ''');
        }
        if (from < 16) {
          // Add altitude column to dive_sites for altitude diving support
          await customStatement(
            'ALTER TABLE dive_sites ADD COLUMN altitude REAL',
          );
        }
        if (from < 17) {
          // Add personal & medical data fields to divers table
          await customStatement(
            'ALTER TABLE divers ADD COLUMN medications TEXT',
          );
          await customStatement(
            'ALTER TABLE divers ADD COLUMN medical_clearance_expiry_date INTEGER',
          );
          // Secondary emergency contact
          await customStatement(
            'ALTER TABLE divers ADD COLUMN emergency_contact2_name TEXT',
          );
          await customStatement(
            'ALTER TABLE divers ADD COLUMN emergency_contact2_phone TEXT',
          );
          await customStatement(
            'ALTER TABLE divers ADD COLUMN emergency_contact2_relation TEXT',
          );
        }
        if (from < 18) {
          // Add site_species junction table for expected marine life at sites
          await customStatement('''
            CREATE TABLE IF NOT EXISTS site_species (
              id TEXT NOT NULL PRIMARY KEY,
              site_id TEXT NOT NULL REFERENCES dive_sites(id) ON DELETE CASCADE,
              species_id TEXT NOT NULL REFERENCES species(id) ON DELETE CASCADE,
              notes TEXT NOT NULL DEFAULT '',
              created_at INTEGER NOT NULL
            )
          ''');
          // Index for efficient lookup by site
          await customStatement('''
            CREATE INDEX IF NOT EXISTS idx_site_species_site
            ON site_species(site_id)
          ''');
        }
        if (from < 19) {
          // Training courses feature (v1.5)
          // Create courses table
          await customStatement('''
            CREATE TABLE IF NOT EXISTS courses (
              id TEXT NOT NULL PRIMARY KEY,
              diver_id TEXT NOT NULL REFERENCES divers(id) ON DELETE CASCADE,
              name TEXT NOT NULL,
              agency TEXT NOT NULL,
              start_date INTEGER NOT NULL,
              completion_date INTEGER,
              instructor_id TEXT REFERENCES buddies(id) ON DELETE SET NULL,
              instructor_name TEXT,
              instructor_number TEXT,
              certification_id TEXT REFERENCES certifications(id) ON DELETE SET NULL,
              location TEXT,
              notes TEXT NOT NULL DEFAULT '',
              created_at INTEGER NOT NULL,
              updated_at INTEGER NOT NULL
            )
          ''');
          // Index for efficient lookup by diver
          await customStatement('''
            CREATE INDEX IF NOT EXISTS idx_courses_diver
            ON courses(diver_id)
          ''');

          // Add courseId FK to dives table
          await customStatement(
            'ALTER TABLE dives ADD COLUMN course_id TEXT REFERENCES courses(id) ON DELETE SET NULL',
          );

          // Add courseId FK to certifications table (bidirectional link)
          await customStatement(
            'ALTER TABLE certifications ADD COLUMN course_id TEXT REFERENCES courses(id) ON DELETE SET NULL',
          );

          // Add signature fields to media table
          await customStatement(
            'ALTER TABLE media ADD COLUMN signer_id TEXT REFERENCES buddies(id) ON DELETE SET NULL',
          );
          await customStatement(
            'ALTER TABLE media ADD COLUMN signer_name TEXT',
          );
        }
        if (from < 20) {
          // Underwater photography feature (v2.0)
          final now = DateTime.now().millisecondsSinceEpoch;

          // Add new columns to media table for gallery photos
          await customStatement(
            'ALTER TABLE media ADD COLUMN platform_asset_id TEXT',
          );
          await customStatement(
            'ALTER TABLE media ADD COLUMN original_filename TEXT',
          );
          await customStatement('ALTER TABLE media ADD COLUMN width INTEGER');
          await customStatement('ALTER TABLE media ADD COLUMN height INTEGER');
          await customStatement(
            'ALTER TABLE media ADD COLUMN duration_seconds INTEGER',
          );
          await customStatement(
            'ALTER TABLE media ADD COLUMN is_favorite INTEGER NOT NULL DEFAULT 0',
          );
          await customStatement(
            'ALTER TABLE media ADD COLUMN thumbnail_generated_at INTEGER',
          );
          await customStatement(
            'ALTER TABLE media ADD COLUMN last_verified_at INTEGER',
          );
          await customStatement(
            'ALTER TABLE media ADD COLUMN is_orphaned INTEGER NOT NULL DEFAULT 0',
          );
          // Add timestamps with default for existing rows
          await customStatement(
            'ALTER TABLE media ADD COLUMN created_at INTEGER NOT NULL DEFAULT $now',
          );
          await customStatement(
            'ALTER TABLE media ADD COLUMN updated_at INTEGER NOT NULL DEFAULT $now',
          );

          // Index on platform_asset_id for gallery photo lookups
          await customStatement('''
            CREATE INDEX IF NOT EXISTS idx_media_platform_asset_id
            ON media(platform_asset_id)
          ''');

          // Create media_enrichment table
          await customStatement('''
            CREATE TABLE IF NOT EXISTS media_enrichment (
              id TEXT NOT NULL PRIMARY KEY,
              media_id TEXT NOT NULL REFERENCES media(id) ON DELETE CASCADE,
              dive_id TEXT NOT NULL REFERENCES dives(id) ON DELETE CASCADE,
              depth_meters REAL,
              temperature_celsius REAL,
              elapsed_seconds INTEGER,
              match_confidence TEXT NOT NULL DEFAULT 'exact',
              timestamp_offset_seconds INTEGER,
              created_at INTEGER NOT NULL
            )
          ''');
          // Indexes for media_enrichment
          await customStatement('''
            CREATE INDEX IF NOT EXISTS idx_media_enrichment_media
            ON media_enrichment(media_id)
          ''');
          await customStatement('''
            CREATE INDEX IF NOT EXISTS idx_media_enrichment_dive
            ON media_enrichment(dive_id)
          ''');

          // Create media_species table
          await customStatement('''
            CREATE TABLE IF NOT EXISTS media_species (
              id TEXT NOT NULL PRIMARY KEY,
              media_id TEXT NOT NULL REFERENCES media(id) ON DELETE CASCADE,
              species_id TEXT NOT NULL REFERENCES species(id) ON DELETE CASCADE,
              sighting_id TEXT REFERENCES sightings(id) ON DELETE SET NULL,
              bbox_x REAL,
              bbox_y REAL,
              bbox_width REAL,
              bbox_height REAL,
              notes TEXT,
              created_at INTEGER NOT NULL
            )
          ''');
          // Indexes for media_species
          await customStatement('''
            CREATE INDEX IF NOT EXISTS idx_media_species_media
            ON media_species(media_id)
          ''');
          await customStatement('''
            CREATE INDEX IF NOT EXISTS idx_media_species_species
            ON media_species(species_id)
          ''');

          // Create pending_photo_suggestions table
          await customStatement('''
            CREATE TABLE IF NOT EXISTS pending_photo_suggestions (
              id TEXT NOT NULL PRIMARY KEY,
              dive_id TEXT NOT NULL REFERENCES dives(id) ON DELETE CASCADE,
              platform_asset_id TEXT NOT NULL,
              taken_at INTEGER NOT NULL,
              thumbnail_path TEXT,
              dismissed INTEGER NOT NULL DEFAULT 0,
              created_at INTEGER NOT NULL
            )
          ''');
          // Index for pending_photo_suggestions
          await customStatement('''
            CREATE INDEX IF NOT EXISTS idx_pending_photo_suggestions_dive
            ON pending_photo_suggestions(dive_id)
          ''');
        }
        if (from < 21) {
          // Cached map regions for offline maps feature
          await customStatement('''
            CREATE TABLE IF NOT EXISTS cached_regions (
              id TEXT NOT NULL PRIMARY KEY,
              name TEXT NOT NULL,
              min_lat REAL NOT NULL,
              max_lat REAL NOT NULL,
              min_lng REAL NOT NULL,
              max_lng REAL NOT NULL,
              min_zoom INTEGER NOT NULL,
              max_zoom INTEGER NOT NULL,
              tile_count INTEGER NOT NULL,
              size_bytes INTEGER NOT NULL,
              created_at INTEGER NOT NULL,
              last_accessed_at INTEGER NOT NULL
            )
          ''');
        }
        if (from < 22) {
          // Buddy signatures feature - add signature type column
          await customStatement(
            'ALTER TABLE media ADD COLUMN signature_type TEXT',
          );
        }
        if (from < 23) {
          // Store photos as BLOBs instead of file paths for backup/export
          // Add BLOB columns to certifications table
          await customStatement(
            'ALTER TABLE certifications ADD COLUMN photo_front BLOB',
          );
          await customStatement(
            'ALTER TABLE certifications ADD COLUMN photo_back BLOB',
          );
          // Add BLOB column to media table for signatures
          await customStatement('ALTER TABLE media ADD COLUMN image_data BLOB');
        }
        if (from < 24) {
          // Add structured address fields to dive_centers
          // The original table had 'location' but not 'city', so we add all new columns
          // Check which columns exist to handle partial migrations
          final tableInfo = await customSelect(
            "PRAGMA table_info('dive_centers')",
          ).get();
          final existingColumns = tableInfo
              .map((row) => row.data['name'] as String)
              .toSet();

          if (!existingColumns.contains('street')) {
            await customStatement(
              'ALTER TABLE dive_centers ADD COLUMN street TEXT',
            );
          }
          if (!existingColumns.contains('city')) {
            await customStatement(
              'ALTER TABLE dive_centers ADD COLUMN city TEXT',
            );
          }
          if (!existingColumns.contains('state_province')) {
            await customStatement(
              'ALTER TABLE dive_centers ADD COLUMN state_province TEXT',
            );
          }
          if (!existingColumns.contains('postal_code')) {
            await customStatement(
              'ALTER TABLE dive_centers ADD COLUMN postal_code TEXT',
            );
          }
          // Migrate existing location data to the new city column (if location exists)
          if (existingColumns.contains('location')) {
            await customStatement('''
              UPDATE dive_centers
              SET city = location
              WHERE location IS NOT NULL AND (city IS NULL OR city = '')
            ''');
          }
        }
        if (from < 25) {
          // Add altitudeUnit column to diver_settings
          await customStatement(
            "ALTER TABLE diver_settings ADD COLUMN altitude_unit TEXT NOT NULL DEFAULT 'meters'",
          );
        }
        if (from < 26) {
          // Notification settings for service reminders
          await customStatement(
            'ALTER TABLE diver_settings ADD COLUMN notifications_enabled INTEGER NOT NULL DEFAULT 1',
          );
          await customStatement(
            "ALTER TABLE diver_settings ADD COLUMN service_reminder_days TEXT NOT NULL DEFAULT '[7, 14, 30]'",
          );
          await customStatement(
            "ALTER TABLE diver_settings ADD COLUMN reminder_time TEXT NOT NULL DEFAULT '09:00'",
          );
        }
        if (from < 27) {
          // Per-equipment notification overrides
          await customStatement(
            'ALTER TABLE equipment ADD COLUMN custom_reminder_enabled INTEGER',
          );
          await customStatement(
            'ALTER TABLE equipment ADD COLUMN custom_reminder_days TEXT',
          );
        }
        if (from < 28) {
          // Scheduled notifications tracking table
          await customStatement('''
            CREATE TABLE IF NOT EXISTS scheduled_notifications (
              id TEXT NOT NULL PRIMARY KEY,
              equipment_id TEXT NOT NULL REFERENCES equipment(id) ON DELETE CASCADE,
              scheduled_date INTEGER NOT NULL,
              reminder_days_before INTEGER NOT NULL,
              notification_id INTEGER NOT NULL,
              created_at INTEGER NOT NULL
            )
          ''');
          // Index for efficient lookup by equipment
          await customStatement('''
            CREATE INDEX IF NOT EXISTS idx_scheduled_notifications_equipment
            ON scheduled_notifications(equipment_id)
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
