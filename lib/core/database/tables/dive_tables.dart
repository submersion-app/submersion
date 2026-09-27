/// Dives and the rows that hang directly off a dive.
library;

// Table classes are pure drift DSL. build_runner reads the column
// getter bodies to generate the `$<Table>Table` subclasses, whose
// fields override the getters, so the bodies never run and no test
// can cover them.
// coverage:ignore-file

import 'package:drift/drift.dart';

import 'package:submersion/core/database/tables/buddy_tables.dart';
import 'package:submersion/core/database/tables/dive_profile_tables.dart';
import 'package:submersion/core/database/tables/diver_tables.dart';
import 'package:submersion/core/database/tables/equipment_tables.dart';
import 'package:submersion/core/database/tables/site_tables.dart';
import 'package:submersion/core/database/tables/trip_tables.dart';

/// Dive log entries
class Dives extends Table {
  TextColumn get id => text()();
  TextColumn get diverId => text().nullable().references(Divers, #id)();
  IntColumn get diveNumber => integer().nullable()();
  // User-defined dive name (#400). Null = never named; display falls back
  // to the site name.
  TextColumn get name => text().nullable()();
  IntColumn get diveDateTime =>
      integer()(); // Unix timestamp (legacy, kept for compatibility)
  IntColumn get entryTime =>
      integer().nullable()(); // Unix timestamp - when diver entered water
  IntColumn get exitTime =>
      integer().nullable()(); // Unix timestamp - when diver exited water
  IntColumn get bottomTime => integer().nullable()(); // seconds (bottom time)
  IntColumn get runtime => integer().nullable()(); // seconds (total runtime)
  RealColumn get maxDepth => real().nullable()();
  RealColumn get avgDepth => real().nullable()();
  RealColumn get waterTemp => real().nullable()();
  RealColumn get airTemp => real().nullable()();

  /// Legacy visibility bucket (pre-v144). Retained read-only so dives logged
  /// before measured visibility keep the band they were filed under; cleared
  /// when [visibilityMeters] is written. New code must not write this.
  TextColumn get visibility => text().nullable()();

  /// v144: measured horizontal visibility in meters, canonical from v144 on.
  ///
  /// Storing the measurement rather than a judgment is what lets the
  /// good/poor adjective be calibrated per diver: six meters is six meters in
  /// Cozumel and in Puget Sound, only the adjective differs.
  RealColumn get visibilityMeters => real().nullable()();
  TextColumn get diveType =>
      text().withDefault(const Constant('recreational'))();
  TextColumn get buddy => text().nullable()();
  TextColumn get diveMaster => text().nullable()();

  /// The active diver's own role on this dive (dive_roles id, #547).
  TextColumn get diverRole => text().nullable()();
  // MacDive import fields — common dive metadata
  TextColumn get boatName => text().nullable()();
  TextColumn get boatCaptain => text().nullable()();
  TextColumn get diveOperator => text().nullable()();
  TextColumn get surfaceConditions => text().nullable()();
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
  // Deco model metadata
  TextColumn get decoAlgorithm =>
      text().nullable()(); // "buhlmann", "vpm", "rgbm", "dciem"
  IntColumn get decoConservatism =>
      integer().nullable()(); // Personal adjustment (0=neutral)
  // Dive computer that logged this dive (for display/export, separate from computerId relation)
  TextColumn get diveComputerModel => text().nullable()();
  TextColumn get diveComputerSerial => text().nullable()();
  TextColumn get diveComputerFirmware => text().nullable()();
  // Weight system fields
  RealColumn get weightAmount => real().nullable()(); // kg
  TextColumn get weightType => text().nullable()();
  // Weighting feedback (v104): 'correct' | 'overweighted' | 'underweighted'.
  TextColumn get weightingFeedback => text().nullable()();
  // Magnitude in kg; direction implied by weightingFeedback.
  RealColumn get weightingFeedbackKg => real().nullable()();
  // Favorite flag (v1.1)
  BoolColumn get isFavorite => boolean().withDefault(const Constant(false))();
  // Statistics exclusion (schema v180, issues #526 and #1272).
  // excludedFromStats is the master flag: the dive stays in the logbook but
  // contributes to no descriptive aggregate, its count included.
  // excludedFromGasStats drops the dive from SAC/RMV and gas-mix aggregates
  // only, for an otherwise ordinary dive whose gas number is unrepresentative
  // (for example purging the tank for an end-of-dive weight check).
  // The master flag implies the gas flag; the implication is applied in SQL by
  // DiveStatsScope, not stored on the row.
  BoolColumn get excludedFromStats =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get excludedFromGasStats =>
      boolean().withDefault(const Constant(false))();
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

  /// Shared id across the sibling dives created by one mirror action (issue
  /// #2002). Not a foreign key: a lone dive with an outing id is valid, and a
  /// group id written once per row never half-applies under sync.
  TextColumn get outingId => text().nullable()();

  // Primary computer used for this dive
  TextColumn get computerId =>
      text().nullable().references(DiveComputers, #id)();
  // Training course this dive belongs to (v1.5)
  TextColumn get courseId =>
      text().nullable().references(Courses, #id, onDelete: KeyAction.setNull)();

  // Import source tracking - tracks import source for Apple Watch, Garmin, etc.
  TextColumn get importSource =>
      text().nullable()(); // 'appleWatch', 'garmin', 'suunto'
  TextColumn get importId =>
      text().nullable()(); // Source-specific ID (e.g., HealthKit UUID)

  // Weather conditions
  RealColumn get windSpeed => real().nullable()(); // m/s
  TextColumn get windDirection =>
      text().nullable()(); // enum: CurrentDirection.name
  TextColumn get cloudCover => text().nullable()();
  TextColumn get precipitation => text().nullable()();
  RealColumn get humidity => real().nullable()(); // 0-100
  TextColumn get weatherDescription => text().nullable()();
  TextColumn get weatherSource =>
      text().nullable()(); // enum: WeatherSource.name
  IntColumn get weatherFetchedAt => integer().nullable()(); // unix timestamp

  /// Raw WMO weather code from the forecast provider.
  ///
  /// Retained so the description can be rendered in the diver's locale and
  /// units at display time rather than frozen as English prose at fetch time.
  IntColumn get weatherCode => integer().nullable()();

  // GPS entry/exit fixes from dive computer (Shearwater Swift). Decimal degrees.
  RealColumn get entryLatitude => real().nullable()();
  RealColumn get entryLongitude => real().nullable()();
  RealColumn get exitLatitude => real().nullable()();
  RealColumn get exitLongitude => real().nullable()();

  // Import version: null = pre-fix, 1 = wall-clock-as-UTC convention
  IntColumn get importVersion => integer().nullable()();

  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  /// Hybrid Logical Clock for cross-device conflict resolution
  /// (nullable: rows written before HLC rollout fall back to updatedAt).
  TextColumn get hlc => text().nullable()();

  /// When the diver dismissed the site suggestion for this dive (photo GPS or
  /// dive-computer GPS). Null = never dismissed. Synced with the row.
  IntColumn get siteSuggestionDismissedAt => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Tanks used during dives
class DiveTanks extends Table {
  TextColumn get id => text()();
  TextColumn get diveId =>
      text().references(Dives, #id, onDelete: KeyAction.cascade)();

  /// The cylinder's gear item, written by the transmitter registry. v210:
  /// ON DELETE SET NULL, like every other nullable link to equipment, so
  /// deleting the item clears the link instead of failing on it.
  TextColumn get equipmentId => text().nullable().references(
    Equipment,
    #id,
    onDelete: KeyAction.setNull,
  )();
  RealColumn get volume => real().nullable()(); // liters
  RealColumn get workingPressure => real().nullable()(); // bar - rated pressure
  RealColumn get startPressure => real().nullable()(); // bar
  RealColumn get endPressure => real().nullable()(); // bar
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
  // Serial of the air-integration transmitter that reported this tank, as the
  // computer logged it (v194). Null for manual tanks and computers that report
  // none. Two computers paired to one transmitter logged the same cylinder,
  // so consolidation matches tanks on this before falling back to gas mix.
  TextColumn get transmitterSerial => text().nullable()();
  // Which parsed tank index this row's computer-owned data (pressure series,
  // serial, start and end pressure) comes from (v200, issue #1314). Download
  // and re-parse write it equal to the index; null on rows written before
  // v200 means "same as tankOrder"; -1 (kNoSourceTankIndex) means the row
  // takes no parsed tank, which is what a reassignment leaves behind.
  IntColumn get sourceTankIndex => integer().nullable()();

  /// v202: the regulator breathed from this cylinder, so high-O2 exposure
  /// reaches the regulator's service clocks. User-authored; downloads and
  /// re-parses never write it.
  TextColumn get regulatorEquipmentId => text().nullable().references(
    Equipment,
    #id,
    onDelete: KeyAction.setNull,
  )();

  /// v232: the trip cylinder slot this tank was breathed from (issue
  /// #2325). User-authored through the tank editor; downloads and re-parses
  /// never write it. Set null when the slot goes, like every other nullable
  /// link on this table.
  TextColumn get tripCylinderId => text().nullable().references(
    TripCylinders,
    #id,
    onDelete: KeyAction.setNull,
  )();
  // Which computer contributed this tank (null = primary source / manual).
  // Same null-means-primary semantics as dive_profiles.computerId; deletes
  // set null.
  TextColumn get computerId => text().nullable().references(
    DiveComputers,
    #id,
    onDelete: KeyAction.setNull,
  )();

  @override
  Set<Column> get primaryKey => {id};

  /// v210: this child's own clock, stamped when it is marked pending. The
  /// merge refuses a remote copy strictly older than the local one, so a
  /// stale full row from a peer cannot overwrite a newer local edit
  /// (SyncDataSerializer.parentGatedChildEntities).
  TextColumn get hlc => text().nullable()();
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

  /// v210: this child's own clock, stamped when it is marked pending. The
  /// merge refuses a remote copy strictly older than the local one, so a
  /// stale full row from a peer cannot overwrite a newer local edit
  /// (SyncDataSerializer.parentGatedChildEntities).
  TextColumn get hlc => text().nullable()();
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

  /// v210: this child's own clock, stamped when it is marked pending. The
  /// merge refuses a remote copy strictly older than the local one, so a
  /// stale full row from a peer cannot overwrite a newer local edit
  /// (SyncDataSerializer.parentGatedChildEntities).
  TextColumn get hlc => text().nullable()();
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

  /// v210: this child's own clock, stamped when it is marked pending. The
  /// merge refuses a remote copy strictly older than the local one, so a
  /// stale full row from a peer cannot overwrite a newer local edit
  /// (SyncDataSerializer.parentGatedChildEntities).
  TextColumn get hlc => text().nullable()();
}

/// User-defined key:value fields per dive
class DiveCustomFields extends Table {
  TextColumn get id => text()();
  TextColumn get diveId =>
      text().references(Dives, #id, onDelete: KeyAction.cascade)();
  TextColumn get fieldKey => text()();
  TextColumn get fieldValue => text().withDefault(const Constant(''))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  IntColumn get createdAt => integer()();

  @override
  Set<Column> get primaryKey => {id};

  /// v210: this child's own clock, stamped when it is marked pending. The
  /// merge refuses a remote copy strictly older than the local one, so a
  /// stale full row from a peer cannot overwrite a newer local edit
  /// (SyncDataSerializer.parentGatedChildEntities).
  TextColumn get hlc => text().nullable()();
}
