import 'dart:convert';
import 'dart:developer' as developer;

import 'package:drift/drift.dart';

import 'package:submersion/core/database/performance_indexes.dart';
import 'package:submersion/core/constants/enums.dart';

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

  /// Hybrid Logical Clock for cross-device conflict resolution
  /// (nullable: rows written before HLC rollout fall back to updatedAt).
  TextColumn get hlc => text().nullable()();

  // Prior dive experience (issue #331): per-diver lifetime offsets for dives
  // logged before the diver started using Submersion. Null = none.
  IntColumn get priorDiveCount => integer().nullable()();
  IntColumn get priorDiveTimeSeconds => integer().nullable()();
  IntColumn get divingSince => integer().nullable()(); // year, e.g. 1990

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
  TextColumn get tripType => text().withDefault(const Constant('shore'))();
  TextColumn get notes => text().withDefault(const Constant(''))();
  BoolColumn get isShared => boolean().withDefault(const Constant(false))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  /// Hybrid Logical Clock for cross-device conflict resolution
  /// (nullable: rows written before HLC rollout fall back to updatedAt).
  TextColumn get hlc => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

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

  /// Hybrid Logical Clock for cross-device conflict resolution
  /// (nullable: rows written before HLC rollout fall back to updatedAt).
  TextColumn get hlc => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Itinerary days for trip planning
class TripItineraryDays extends Table {
  TextColumn get id => text()();
  TextColumn get tripId => text().references(Trips, #id)();
  IntColumn get dayNumber => integer()();
  IntColumn get date => integer()(); // Unix timestamp
  TextColumn get dayType => text().withDefault(const Constant('diveDay'))();
  TextColumn get portName => text().nullable()();
  RealColumn get latitude => real().nullable()();
  RealColumn get longitude => real().nullable()();
  TextColumn get notes => text().withDefault(const Constant(''))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  /// Hybrid Logical Clock for cross-device conflict resolution
  /// (nullable: rows written before HLC rollout fall back to updatedAt).
  TextColumn get hlc => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Reusable checklist templates for trip planning (issue #164)
class ChecklistTemplates extends Table {
  // coverage:ignore-start
  // Drift column getters run at build time via drift_dev, not at runtime, so
  // lcov never records hits (true of every Table class in this file).
  TextColumn get id => text()();
  TextColumn get diverId => text().nullable().references(Divers, #id)();
  TextColumn get name => text()();
  TextColumn get description => text().withDefault(const Constant(''))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  /// Hybrid Logical Clock for cross-device conflict resolution
  /// (nullable: rows written before HLC rollout fall back to updatedAt).
  TextColumn get hlc => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
  // coverage:ignore-end
}

/// Items belonging to a checklist template
class ChecklistTemplateItems extends Table {
  // coverage:ignore-start
  TextColumn get id => text()();
  TextColumn get templateId => text().references(ChecklistTemplates, #id)();
  TextColumn get title => text()();
  TextColumn get category => text().nullable()();
  TextColumn get notes => text().withDefault(const Constant(''))();

  /// Days before trip start the item is due (14 = "two weeks out").
  IntColumn get dueOffsetDays => integer().nullable()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  /// Hybrid Logical Clock for cross-device conflict resolution
  /// (nullable: rows written before HLC rollout fall back to updatedAt).
  TextColumn get hlc => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
  // coverage:ignore-end
}

/// Per-trip checklist items (copied from templates or added ad hoc)
class TripChecklistItems extends Table {
  // coverage:ignore-start
  TextColumn get id => text()();
  TextColumn get tripId => text().references(Trips, #id)();
  TextColumn get title => text()();
  TextColumn get category => text().nullable()();
  TextColumn get notes => text().withDefault(const Constant(''))();

  /// Absolute due date, resolved from the template offset at apply time.
  IntColumn get dueDate => integer().nullable()();
  BoolColumn get isDone => boolean().withDefault(const Constant(false))();
  IntColumn get completedAt => integer().nullable()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  /// Hybrid Logical Clock for cross-device conflict resolution
  /// (nullable: rows written before HLC rollout fall back to updatedAt).
  TextColumn get hlc => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
  // coverage:ignore-end
}

/// Pre-dive checklist templates (spec 2026-07-16-pre-dive-checklist).
/// Built-ins (isBuiltIn) are seeded by kSeedBuiltInPreDiveTemplate* SQL,
/// re-asserted in beforeOpen, and skipped by sync export.
class PreDiveChecklistTemplates extends Table {
  // coverage:ignore-start
  TextColumn get id => text()();
  TextColumn get diverId => text().nullable().references(Divers, #id)();
  TextColumn get name => text()();
  TextColumn get description => text().withDefault(const Constant(''))();
  TextColumn get category => text().nullable()();

  /// Enforce item order during sessions (CCR-build style).
  BoolColumn get strictOrder => boolean().withDefault(const Constant(false))();
  BoolColumn get isBuiltIn => boolean().withDefault(const Constant(false))();

  /// Stable identity for built-in re-seeding and content upgrades.
  TextColumn get builtinKey => text().nullable()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  /// Hybrid Logical Clock for cross-device conflict resolution
  /// (nullable: rows written before HLC rollout fall back to updatedAt).
  TextColumn get hlc => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
  // coverage:ignore-end
}

/// Items belonging to a pre-dive checklist template.
class PreDiveChecklistTemplateItems extends Table {
  // coverage:ignore-start
  TextColumn get id => text()();
  TextColumn get templateId =>
      text().references(PreDiveChecklistTemplates, #id)();

  /// Visual grouping header (e.g. "Cells", "Bailout").
  TextColumn get section => text().nullable()();
  TextColumn get title => text()();
  TextColumn get notes => text().withDefault(const Constant(''))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  /// 'check' | 'value' | 'equipmentSet' (PreDiveItemType.name).
  TextColumn get itemType => text().withDefault(const Constant('check'))();
  TextColumn get valueLabel => text().nullable()();
  TextColumn get valueUnit => text().nullable()();

  /// Warning thresholds for value items — advisory, never blocking.
  RealColumn get valueMin => real().nullable()();
  RealColumn get valueMax => real().nullable()();

  /// Required items must end Done or Flagged (never Skipped).
  BoolColumn get isRequired => boolean().withDefault(const Constant(false))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  /// Hybrid Logical Clock for cross-device conflict resolution.
  TextColumn get hlc => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
  // coverage:ignore-end
}

/// A pre-dive checklist run. Snapshots everything at start; completed and
/// aborted sessions are immutable audit records (repository-enforced).
class PreDiveSessions extends Table {
  // coverage:ignore-start
  TextColumn get id => text()();
  TextColumn get diverId => text().nullable().references(Divers, #id)();
  TextColumn get templateId => text().nullable().references(
    PreDiveChecklistTemplates,
    #id,
    onDelete: KeyAction.setNull,
  )();

  /// Snapshot; survives template deletion.
  TextColumn get templateName => text()();

  /// Snapshot of the template's strictOrder at session start.
  BoolColumn get strictOrder => boolean().withDefault(const Constant(false))();
  TextColumn get diveId =>
      text().nullable().references(Dives, #id, onDelete: KeyAction.setNull)();
  TextColumn get tripId =>
      text().nullable().references(Trips, #id, onDelete: KeyAction.setNull)();
  IntColumn get startedAt => integer()();
  IntColumn get completedAt => integer().nullable()();

  /// 'inProgress' | 'completed' | 'aborted' (PreDiveSessionStatus.name).
  TextColumn get status => text().withDefault(const Constant('inProgress'))();
  TextColumn get equipmentSetId => text().nullable().references(
    EquipmentSets,
    #id,
    onDelete: KeyAction.setNull,
  )();

  /// Display snapshot; survives set deletion.
  TextColumn get equipmentSetName => text().nullable()();
  TextColumn get notes => text().withDefault(const Constant(''))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  /// Hybrid Logical Clock for cross-device conflict resolution.
  TextColumn get hlc => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
  // coverage:ignore-end
}

/// Per-session checklist items: a full snapshot of the template item plus
/// run state. Mutated individually during a run, so first-class HLC rows.
class PreDiveSessionItems extends Table {
  // coverage:ignore-start
  TextColumn get id => text()();
  TextColumn get sessionId =>
      text().references(PreDiveSessions, #id, onDelete: KeyAction.cascade)();
  TextColumn get section => text().nullable()();
  TextColumn get title => text()();
  TextColumn get notes => text().withDefault(const Constant(''))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  TextColumn get itemType => text().withDefault(const Constant('check'))();
  TextColumn get valueLabel => text().nullable()();
  TextColumn get valueUnit => text().nullable()();
  RealColumn get valueMin => real().nullable()();
  RealColumn get valueMax => real().nullable()();
  BoolColumn get isRequired => boolean().withDefault(const Constant(false))();

  /// 'pending' | 'done' | 'skipped' | 'flagged' (PreDiveItemState.name).
  TextColumn get state => text().withDefault(const Constant('pending'))();
  RealColumn get valueNumber => real().nullable()();
  TextColumn get valueText => text().nullable()();

  /// Diver note recorded during the run (e.g. "cell 2 sluggish").
  TextColumn get note => text().withDefault(const Constant(''))();

  /// Stamped at tap time — audit evidence, never backfilled.
  IntColumn get completedAt => integer().nullable()();

  /// Set for equipment-expanded rows; navigation only.
  TextColumn get equipmentId => text().nullable().references(
    Equipment,
    #id,
    onDelete: KeyAction.setNull,
  )();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  /// Hybrid Logical Clock for cross-device conflict resolution.
  TextColumn get hlc => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
  // coverage:ignore-end
}

/// GPS surface tracks recorded by the phone during a dive day (spec
/// 2026-07-06-gps-track-logging). One row per recording session; points
/// live in a gzipped JSON blob because matching always reads whole tracks
/// and blob-per-session keeps sync to one HLC row per boat day.
@DataClassName('GpsTrackRow')
class GpsTracks extends Table {
  // coverage:ignore-start
  TextColumn get id => text()();

  /// Wall-clock-as-UTC epoch milliseconds (same convention as dives.entryTime)
  IntColumn get startTime => integer()();
  IntColumn get endTime => integer().nullable()();

  /// Device UTC offset at recording start, to reconstruct true UTC later
  IntColumn get tzOffsetMinutes => integer().withDefault(const Constant(0))();
  TextColumn get deviceName => text().nullable()();
  IntColumn get pointCount => integer().withDefault(const Constant(0))();

  /// Gzipped JSON array of [wallClockEpochSeconds, lat, lon, accuracyMeters]
  BlobColumn get points => blob().nullable()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  /// Hybrid Logical Clock for cross-device conflict resolution
  TextColumn get hlc => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
  // coverage:ignore-end
}

/// Local-only append buffer for the in-progress GPS recording session.
/// Never synced (no hlc). Finalized into gps_tracks.points on stop or
/// crash recovery.
@DataClassName('GpsTrackPointRow')
class GpsTrackPointsLocal extends Table {
  // coverage:ignore-start
  IntColumn get rowId => integer().autoIncrement()();
  TextColumn get trackId => text()();

  /// Wall-clock-as-UTC epoch seconds
  IntColumn get timestamp => integer()();
  RealColumn get latitude => real()();
  RealColumn get longitude => real()();
  RealColumn get accuracy => real().nullable()();
  // coverage:ignore-end
}

/// Saved dive plans (dive planner redesign, Phase 2)
class DivePlans extends Table {
  // coverage:ignore-start
  TextColumn get id => text()();
  TextColumn get diverId => text().nullable().references(Divers, #id)();
  TextColumn get name => text()();
  TextColumn get notes => text().withDefault(const Constant(''))();

  /// PlanMode enum name: 'oc' | 'ccr' | 'scr' | 'pscr'.
  TextColumn get mode => text().withDefault(const Constant('oc'))();
  TextColumn get siteId => text().nullable().references(DiveSites, #id)();

  /// Planned start time (Unix seconds); null = "now" at planning. Drives
  /// repetitive tissue init and overlap detection (v120).
  IntColumn get startDateTime => integer().nullable()();

  /// Tissue-seeding source dive (repetitive planning, Phase 6).
  TextColumn get sourceDiveId => text().nullable().references(Dives, #id)();

  /// Executed dive this plan is linked to (plan-vs-actual, Phase 6).
  TextColumn get linkedDiveId => text().nullable().references(Dives, #id)();
  RealColumn get altitude => real().nullable()();

  /// WaterType enum name; null = unspecified (EN13319 density).
  TextColumn get waterType => text().nullable()();
  IntColumn get gfLow => integer()();
  IntColumn get gfHigh => integer()();
  RealColumn get descentRate => real().withDefault(const Constant(18.0))();
  RealColumn get ascentRate => real().withDefault(const Constant(9.0))();
  RealColumn get lastStopDepth => real().withDefault(const Constant(3.0))();
  IntColumn get gasSwitchStopSeconds =>
      integer().withDefault(const Constant(0))();

  /// Air-break policy; both null = no air breaks.
  IntColumn get airBreakO2Seconds => integer().nullable()();
  IntColumn get airBreakBreakSeconds => integer().nullable()();
  RealColumn get sacBottom => real().withDefault(const Constant(15.0))();

  /// Null = derive 0.8x / 2.5x of sacBottom.
  RealColumn get sacDeco => real().nullable()();
  RealColumn get sacStressed => real().nullable()();
  RealColumn get reservePressure => real().withDefault(const Constant(50.0))();
  IntColumn get surfaceIntervalSeconds => integer().nullable()();

  /// CCR setpoints (Phase 4 UI; persisted now to avoid a later migration).
  RealColumn get setpointLow => real().nullable()();
  RealColumn get setpointHigh => real().nullable()();
  RealColumn get setpointSwitchDepth => real().nullable()();

  /// Contingency config (Phase 5 UI).
  RealColumn get deviationDepthDelta =>
      real().withDefault(const Constant(5.0))();
  IntColumn get deviationTimeMinutes =>
      integer().withDefault(const Constant(5))();

  /// TurnPressureRule enum name; null = none.
  TextColumn get turnPressureRule => text().nullable()();
  RealColumn get turnPressureFraction => real().nullable()();

  /// Accepted weight prediction snapshot (v104). Placement is a JSON object
  /// keyed by WeightType.name -> kg.
  RealColumn get plannedWeightKg => real().nullable()();
  TextColumn get plannedWeightPlacement => text().nullable()();

  /// Denormalized list-display summary (no engine run per list row).
  RealColumn get summaryMaxDepth => real().nullable()();
  IntColumn get summaryRuntimeSeconds => integer().nullable()();
  IntColumn get summaryTtsSeconds => integer().nullable()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  /// Hybrid Logical Clock for cross-device conflict resolution
  /// (nullable: rows written before HLC rollout fall back to updatedAt).
  TextColumn get hlc => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
  // coverage:ignore-end
}

/// Tanks carried on a saved dive plan
class DivePlanTanks extends Table {
  // coverage:ignore-start
  TextColumn get id => text()();
  TextColumn get planId => text().references(DivePlans, #id)();
  TextColumn get name => text().nullable()();
  RealColumn get volume => real().nullable()();
  RealColumn get workingPressure => real().nullable()();
  RealColumn get startPressure => real().nullable()();
  RealColumn get gasO2 => real().withDefault(const Constant(21.0))();
  RealColumn get gasHe => real().withDefault(const Constant(0.0))();

  /// TankRole enum name.
  TextColumn get role => text().withDefault(const Constant('backGas'))();

  /// TankMaterial enum name; null = unspecified.
  TextColumn get material => text().nullable()();
  TextColumn get presetName => text().nullable()();

  /// Deco gas-switch depth override in meters; null = auto (MOD at deco pO2).
  /// Subsurface per-cylinder "Deco switch at" (v120).
  RealColumn get decoSwitchDepth => real().nullable()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  /// Hybrid Logical Clock for cross-device conflict resolution
  /// (nullable: rows written before HLC rollout fall back to updatedAt).
  TextColumn get hlc => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
  // coverage:ignore-end
}

/// User-authored segments (the bottom portion) of a saved dive plan
class DivePlanSegments extends Table {
  // coverage:ignore-start
  TextColumn get id => text()();
  TextColumn get planId => text().references(DivePlans, #id)();

  /// SegmentType enum name.
  TextColumn get type => text()();
  RealColumn get startDepth => real()();
  RealColumn get endDepth => real()();
  IntColumn get durationSeconds => integer()();
  TextColumn get tankId => text().references(DivePlanTanks, #id)();
  RealColumn get gasO2 => real()();
  RealColumn get gasHe => real()();
  RealColumn get rate => real().nullable()();
  TextColumn get switchToTankId => text().nullable()();

  /// Per-segment CCR setpoint override in bar; null = the plan's depth-based
  /// setpoint (v120, Subsurface per-segment setpoint column).
  RealColumn get setpointBar => real().nullable()();

  /// Per-segment dive-mode override enum name ('oc'|'ccr'|'scr'|'pscr'); null =
  /// the plan's mode. Models mid-plan bailout (v120).
  TextColumn get diveModeOverride => text().nullable()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  /// Hybrid Logical Clock for cross-device conflict resolution
  /// (nullable: rows written before HLC rollout fall back to updatedAt).
  TextColumn get hlc => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
  // coverage:ignore-end
}

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
  TextColumn get visibility => text().nullable()();
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
  // Deprecated: use tank_pressure_profiles table. Column retained for schema compat.
  RealColumn get pressure => real().nullable()();
  RealColumn get temperature => real().nullable()();
  IntColumn get heartRate => integer().nullable()();
  // Compass heading in degrees (0-359) from DC_SAMPLE_BEARING; null when the
  // computer does not report bearing samples.
  RealColumn get heading => real().nullable()();
  // Computed decompression data (optional, can be calculated on-the-fly)
  RealColumn get ascentRate => real().nullable()(); // m/min
  RealColumn get ceiling => real().nullable()(); // deco ceiling in meters
  IntColumn get ndl => integer().nullable()(); // no-deco limit in seconds

  // CCR/SCR rebreather data (v1.5)
  RealColumn get setpoint =>
      real().nullable()(); // Current setpoint at sample (bar)
  RealColumn get ppO2 => real().nullable()(); // Measured/calculated ppO2 (bar)

  // Individual CCR O2 cell readings (bar). Subsurface exports up to 6
  // (sensor1..sensor6); rebreathers run 3 (e.g. JJ-CCR) to 5 (e.g. rEvo).
  // Stored raw exactly as the source reports them; null when absent.
  RealColumn get o2Sensor1 => real().nullable()();
  RealColumn get o2Sensor2 => real().nullable()();
  RealColumn get o2Sensor3 => real().nullable()();
  RealColumn get o2Sensor4 => real().nullable()();
  RealColumn get o2Sensor5 => real().nullable()();
  RealColumn get o2Sensor6 => real().nullable()();

  // Per-sample decompression data (v1.5)
  RealColumn get cns => real().nullable()(); // CNS percentage 0-100
  IntColumn get tts => integer().nullable()(); // Time to surface in seconds
  IntColumn get rbt =>
      integer().nullable()(); // Remaining bottom time in seconds
  IntColumn get decoType =>
      integer().nullable()(); // 0=NDL, 1=safety, 2=deco, 3=deep

  // Wearable integration (v2.0) - tracks source of heart rate data
  TextColumn get heartRateSource =>
      text().nullable()(); // 'diveComputer', 'appleWatch', 'garmin', 'manual'

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
  // MacDive site metadata
  TextColumn get waterType => text().nullable()();
  TextColumn get bodyOfWater => text().nullable()();
  // Location hierarchy
  TextColumn get city => text().nullable()();
  TextColumn get island => text().nullable()();
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
  BoolColumn get isShared => boolean().withDefault(const Constant(false))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  /// Hybrid Logical Clock for cross-device conflict resolution
  /// (nullable: rows written before HLC rollout fall back to updatedAt).
  TextColumn get hlc => text().nullable()();

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
  TextColumn get thickness => text().nullable()(); // 2,3,4,5,6 or 6mm (v112)
  // Buoyancy metadata (v104): net in-water buoyancy in kg (positive floats),
  // and dry weight in kg (feeds displacement scaling).
  RealColumn get buoyancyKg => real().nullable()();
  RealColumn get weightKg => real().nullable()();
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

  /// Hybrid Logical Clock for cross-device conflict resolution
  /// (nullable: rows written before HLC rollout fall back to updatedAt).
  TextColumn get hlc => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Type-specific and user-defined attributes for equipment items (v124).
/// Curated rows (isCustom = false) use deterministic ids
/// `attr_<equipmentId>_<attrKey>` so independently migrated devices converge;
/// custom rows use random UUIDs. "Unset" is "no row" -- clearing a value
/// deletes the row and writes a tombstone.
@DataClassName('EquipmentAttributeRow')
class EquipmentAttributes extends Table {
  TextColumn get id => text()();
  TextColumn get equipmentId =>
      text().references(Equipment, #id, onDelete: KeyAction.cascade)();
  TextColumn get attrKey => text()();
  BoolColumn get isCustom => boolean().withDefault(const Constant(false))();
  TextColumn get valueText => text().nullable()();
  RealColumn get valueNum => real().nullable()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  /// Hybrid Logical Clock for cross-device conflict resolution.
  TextColumn get hlc => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
    {equipmentId, attrKey, isCustom},
  ];
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

/// Dated body-mass measurements per diver (weight prediction, v104).
@DataClassName('DiverWeightEntryRow')
class DiverWeightEntries extends Table {
  TextColumn get id => text()();
  TextColumn get diverId => text().references(Divers, #id)();
  IntColumn get measuredAt => integer()(); // Unix ms
  RealColumn get weightKg => real()();
  RealColumn get heightCm => real().nullable()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  /// Hybrid Logical Clock for cross-device conflict resolution.
  TextColumn get hlc => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Junction: equipment attached to a saved dive plan (v104).
class DivePlanEquipment extends Table {
  TextColumn get planId =>
      text().references(DivePlans, #id, onDelete: KeyAction.cascade)();
  TextColumn get equipmentId =>
      text().references(Equipment, #id, onDelete: KeyAction.cascade)();

  @override
  Set<Column> get primaryKey => {planId, equipmentId};
}

/// Equipment sets (named collections of equipment items)
class EquipmentSets extends Table {
  TextColumn get id => text()();
  TextColumn get diverId => text().nullable().references(Divers, #id)();
  TextColumn get name => text()();
  TextColumn get description => text().withDefault(const Constant(''))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  /// Whether this set is the diver's default (auto-applied to new dives with
  /// no equipment). Mutual exclusion is enforced per-diver at the repository
  /// layer, mirroring DiverRepository.setDefaultDiver.
  BoolColumn get isDefault => boolean().withDefault(const Constant(false))();

  /// Hybrid Logical Clock for cross-device conflict resolution
  /// (nullable: rows written before HLC rollout fall back to updatedAt).
  TextColumn get hlc => text().nullable()();

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

/// Geofences attached to an equipment set. A geofence matches a dive when its
/// center is within [radiusMeters] of any of the dive's known points (linked
/// site GPS, or the computer's entry/exit fixes). First-class synced entity:
/// own id + hlc.
class EquipmentSetGeofences extends Table {
  TextColumn get id => text()();
  TextColumn get setId =>
      text().references(EquipmentSets, #id, onDelete: KeyAction.cascade)();

  /// Display label; seeded from the anchor site's name or diver-entered.
  TextColumn get label => text().nullable()();
  RealColumn get latitude => real()();
  RealColumn get longitude => real()();
  RealColumn get radiusMeters => real()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  /// Hybrid Logical Clock for cross-device conflict resolution.
  TextColumn get hlc => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Data-quality findings produced by the Data Quality Assistant detectors.
/// One row per (dive, detector, discriminator). Ids are deterministic
/// UUIDv5 values so independent scans on two devices converge on the same
/// row. A user dismissal is a status update, never a delete -- deterministic
/// ids would otherwise resurrect a dismissed finding on the next rescan. (The
/// scan pipeline itself may still delete a finding that no longer reproduces;
/// that path writes a sync tombstone.)
@DataClassName('QualityFindingRow')
class QualityFindings extends Table {
  TextColumn get id => text()();
  TextColumn get diveId =>
      text().references(Dives, #id, onDelete: KeyAction.cascade)();

  /// The other dive for cross-dive findings (duplicates, splits, overlaps).
  TextColumn get relatedDiveId =>
      text().nullable().references(Dives, #id, onDelete: KeyAction.setNull)();

  /// Source computer for source-scoped findings.
  TextColumn get computerId => text().nullable().references(
    DiveComputers,
    #id,
    onDelete: KeyAction.setNull,
  )();
  TextColumn get detectorId => text()();
  IntColumn get detectorVersion => integer()();
  TextColumn get category => text()();
  TextColumn get severity => text()();
  TextColumn get status => text().withDefault(const Constant('open'))();

  /// JSON object of numeric arguments; the UI renders localized messages
  /// from these. Never store prose.
  TextColumn get params => text().withDefault(const Constant('{}'))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  /// Hybrid Logical Clock for cross-device conflict resolution.
  TextColumn get hlc => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Catalog of service kinds (hydro, VIP, regulator service, ...).
/// Built-ins are reference data: seeded on create/upgrade/open, skipped by
/// sync export, undeletable through the repository. Custom kinds sync.
@DataClassName('ServiceKindRow')
class ServiceKinds extends Table {
  TextColumn get id => text()();
  TextColumn get diverId => text().nullable().references(Divers, #id)();
  TextColumn get name => text()();

  /// JSON array of EquipmentType names this kind suggests for, e.g. '["tank"]'.
  TextColumn get applicableTypes => text().withDefault(const Constant('[]'))();
  IntColumn get defaultIntervalDays => integer().nullable()();
  IntColumn get defaultIntervalDives => integer().nullable()();
  RealColumn get defaultIntervalHours => real().nullable()();

  /// Auto-create a schedule when matching equipment is created.
  BoolColumn get autoAttach => boolean().withDefault(const Constant(false))();
  BoolColumn get isBuiltIn => boolean().withDefault(const Constant(false))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  /// Hybrid Logical Clock for cross-device conflict resolution.
  TextColumn get hlc => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// One service clock per (equipment item, service kind). Next-due is always
/// computed from the newest ServiceRecord of the kind (anchorDate/purchase
/// fallbacks) -- never stored, so dive logging does not churn sync rows.
@DataClassName('ServiceScheduleRow')
class ServiceSchedules extends Table {
  TextColumn get id => text()();
  TextColumn get equipmentId =>
      text().references(Equipment, #id, onDelete: KeyAction.cascade)();
  TextColumn get serviceKindId =>
      text().references(ServiceKinds, #id, onDelete: KeyAction.cascade)();

  /// Per-item overrides; null = inherit the kind's default interval.
  IntColumn get intervalDays => integer().nullable()();
  IntColumn get intervalDives => integer().nullable()();
  RealColumn get intervalHours => real().nullable()();

  /// Baseline when no ServiceRecord of this kind exists yet (e.g. last hydro
  /// before app adoption). Fallback chain: purchaseDate, then createdAt.
  IntColumn get anchorDate => integer().nullable()();
  BoolColumn get enabled => boolean().withDefault(const Constant(true))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  /// Hybrid Logical Clock for cross-device conflict resolution.
  TextColumn get hlc => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Marine life species catalog
class Species extends Table {
  TextColumn get id => text()();
  TextColumn get commonName => text()();
  TextColumn get scientificName => text().nullable()();
  TextColumn get category => text()(); // fish, coral, mammal, etc.
  TextColumn get taxonomyClass => text().nullable()(); // e.g. Actinopterygii
  TextColumn get description => text().nullable()();
  TextColumn get photoPath => text().nullable()();
  BoolColumn get isBuiltIn => boolean().withDefault(const Constant(false))();
  TextColumn get hlc => text().nullable()();

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
  // Source-type extension (v72)
  // Drift's build_runner replaces these getters with `GeneratedColumn`
  // declarations on the `$MediaTable` subclass, so the bodies below never
  // execute at runtime — they're DSL the schema generator reads as AST.
  // coverage:ignore-start
  TextColumn get sourceType =>
      text().withDefault(const Constant('platformGallery'))();
  TextColumn get localPath => text().nullable()();
  TextColumn get bookmarkRef => text().nullable()();
  TextColumn get url => text().nullable()();
  TextColumn get subscriptionId => text().nullable()();
  TextColumn get entryKey => text().nullable()();
  TextColumn get connectorAccountId => text().nullable()();
  TextColumn get remoteAssetId => text().nullable()();
  TextColumn get originDeviceId => text().nullable()();
  // Media store (v103) - content identity + upload confirmation stamps.
  // Nullable adds; a row with remote_uploaded_at set has its original bytes
  // confirmed present in the library's media store at the content-hash key.
  TextColumn get contentHash => text().nullable()();
  IntColumn get contentSizeBytes => integer().nullable()();
  IntColumn get remoteUploadedAt => integer().nullable()();
  IntColumn get remoteThumbUploadedAt => integer().nullable()();

  // Adjustable upload quality (v133): a compressed rendition, keyed by the
  // original's content hash, may be uploaded instead of the original.
  TextColumn get compressedLevel => text().nullable()();
  IntColumn get compressedSizeBytes => integer().nullable()();
  IntColumn get remoteCompressedUploadedAt => integer().nullable()();
  // coverage:ignore-end
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  TextColumn get hlc => text().nullable()();

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
  // v130: sync replication. media_enrichment is the depth/time association for
  // a linked photo; without an hlc it never travelled through sync and was
  // lost on other devices / after restore.
  TextColumn get hlc => text().nullable()();

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

/// Pending photo suggestions for background scan feature.
///
/// v106: connector suggestions (Lightroom) reuse this table. For those
/// rows `connectorAccountId`/`remoteAssetId` are set and the remote asset
/// id is mirrored into the NOT NULL `platformAssetId` key column.
class PendingPhotoSuggestions extends Table {
  TextColumn get id => text()();
  TextColumn get diveId =>
      text().references(Dives, #id, onDelete: KeyAction.cascade)();
  TextColumn get platformAssetId => text()();
  IntColumn get takenAt => integer()();
  TextColumn get thumbnailPath => text().nullable()();
  BoolColumn get dismissed => boolean().withDefault(const Constant(false))();
  IntColumn get createdAt => integer()();
  TextColumn get connectorAccountId => text().nullable()();
  TextColumn get remoteAssetId => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

// Drift table classes added in v72. The column getter bodies below are
// pure DSL (read by build_runner to generate `$<Table>Table` subclasses
// with overriding `GeneratedColumn` fields) and never execute at runtime,
// so they cannot be covered by tests. The schema is exercised end-to-end
// in `migration_72_test.dart` and `new_tables_drift_access_test.dart`.
// coverage:ignore-start

/// Manifest-feed subscriptions (Atom/RSS, JSON, CSV) for periodic polling.
/// Synced across devices.
class MediaSubscriptions extends Table {
  TextColumn get id => text()();
  TextColumn get manifestUrl => text()();
  TextColumn get format => text()();
  TextColumn get displayName => text().nullable()();
  IntColumn get pollIntervalSeconds =>
      integer().withDefault(const Constant(86400))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  TextColumn get credentialsHostId => text().nullable()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  /// Hybrid Logical Clock for cross-device conflict resolution (v108;
  /// nullable: rows written before the rollout fall back to updatedAt).
  TextColumn get hlc => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Per-device polling state for each subscription. Not synced.
class MediaSubscriptionState extends Table {
  TextColumn get subscriptionId =>
      text().references(MediaSubscriptions, #id, onDelete: KeyAction.cascade)();
  IntColumn get lastPolledAt => integer().nullable()();
  IntColumn get nextPollAt => integer().nullable()();
  TextColumn get lastEtag => text().nullable()();
  TextColumn get lastModified => text().nullable()();
  TextColumn get lastError => text().nullable()();
  IntColumn get lastErrorAt => integer().nullable()();

  @override
  Set<Column> get primaryKey => {subscriptionId};
}

/// Per-host credentials for ad-hoc HTTP(S) media URLs. Not synced.
class NetworkCredentialHosts extends Table {
  TextColumn get id => text()();
  TextColumn get hostname => text()();
  TextColumn get authType => text()();
  TextColumn get displayName => text().nullable()();
  TextColumn get credentialsRef => text()();
  IntColumn get addedAt => integer()();
  IntColumn get lastUsedAt => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};

  // Match the v72 migration's `hostname TEXT NOT NULL UNIQUE` so fresh
  // installs (created from the Drift schema) reject duplicate hostnames the
  // same way upgraded DBs do.
  @override
  List<Set<Column>> get uniqueKeys => [
    {hostname},
  ];
}

/// Per-device fetch error diagnostics for media items. Not synced.
class MediaFetchDiagnostics extends Table {
  TextColumn get mediaItemId =>
      text().references(Media, #id, onDelete: KeyAction.cascade)();
  IntColumn get lastErrorAt => integer().nullable()();
  TextColumn get lastErrorMessage => text().nullable()();
  IntColumn get errorCount => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {mediaItemId};
}

/// The library's media store descriptor (secret-free). Synced so other
/// devices learn a store exists and can prompt to connect. Exactly one
/// active row is expected; credentials never live here (keychain only).
class MediaStores extends Table {
  TextColumn get id => text()(); // storeId UUID, matches smv1/store.json
  TextColumn get providerType => text()(); // 's3' (Phase 4 adds others)
  TextColumn get displayHint => text()(); // e.g. 'dive-media @ minio.host'
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  TextColumn get hlc => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Linked credentialed endpoints (secret-free). Synced roster: other
/// devices see which accounts exist and prompt for sign-in (program spec
/// section 5). Credentials live in the keychain under
/// `account_<id>_credentials`, never here.
class ConnectedAccounts extends Table {
  TextColumn get id => text()();
  TextColumn get kind => text()(); // AccountKind.name
  TextColumn get label => text()();
  TextColumn get accountIdentifier => text().nullable()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  TextColumn get hlc => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
// coverage:ignore-end

/// Application settings key-value store (legacy - kept for backward compatibility)
class Settings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text().nullable()();
  IntColumn get updatedAt => integer()();

  /// Hybrid Logical Clock for cross-device conflict resolution
  /// (nullable: rows written before HLC rollout fall back to updatedAt).
  TextColumn get hlc => text().nullable()();

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
  TextColumn get themePreset =>
      text().withDefault(const Constant('submersion'))();
  // Locale (language preference: 'system', 'en', 'es', 'fr', etc.)
  TextColumn get locale => text().withDefault(const Constant('system'))();
  // Defaults
  TextColumn get defaultDiveType =>
      text().withDefault(const Constant('recreational'))();
  RealColumn get defaultTankVolume =>
      real().withDefault(const Constant(12.0))();
  IntColumn get defaultStartPressure =>
      integer().withDefault(const Constant(200))();
  TextColumn get defaultTankPreset =>
      text().nullable().withDefault(const Constant('al80'))();
  BoolColumn get applyDefaultTankToImports =>
      boolean().withDefault(const Constant(false))();
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
      boolean().withDefault(const Constant(false))();
  BoolColumn get showNdlOnProfile =>
      boolean().withDefault(const Constant(true))();
  RealColumn get lastStopDepth => real().withDefault(const Constant(3.0))();
  RealColumn get decoStopIncrement => real().withDefault(const Constant(3.0))();
  // coverage:ignore-start
  /// Index of AscentGasSet (0 = allCarried). Drives the ideal-gas ascent set.
  IntColumn get ascentGasSet => integer().withDefault(const Constant(0))();
  // coverage:ignore-end
  BoolColumn get o2Narcotic => boolean().withDefault(const Constant(true))();
  RealColumn get endLimit => real().withDefault(const Constant(30.0))();
  BoolColumn get useDiveComputerCnsData =>
      boolean().withDefault(const Constant(false))();
  IntColumn get defaultNdlSource => integer().withDefault(const Constant(1))();
  IntColumn get defaultCeilingSource =>
      integer().withDefault(const Constant(1))();
  IntColumn get defaultTtsSource => integer().withDefault(const Constant(1))();
  IntColumn get defaultCnsSource => integer().withDefault(const Constant(1))();
  // CNS calculation method: 'classic' | 'shearwater' | 'subsurface' (v113)
  TextColumn get cnsCalculationMethod =>
      text().withDefault(const Constant('shearwater'))();
  // Deco stop band on the profile chart (v133). Source is a MetricDataSource
  // index: 0 = computer, 1 = calculated.
  BoolColumn get showDecoStopsOnProfile =>
      boolean().withDefault(const Constant(true))();
  IntColumn get defaultDecoStopSource =>
      integer().withDefault(const Constant(1))();
  // Post-dive safety review (safety features phase 1, v123)
  BoolColumn get safetyReviewEnabled =>
      boolean().withDefault(const Constant(true))();
  // JSON array of SafetyRuleId.dbValue strings; null/absent = none disabled.
  TextColumn get safetyReviewDisabledRules => text().nullable()();
  // Flying-after-diving conservatism (NoFlyPreset.dbValue, v125).
  TextColumn get noFlyPreset =>
      text().withDefault(const Constant('standard'))();
  // Emergency card (v126): hidden bundled chamber ids (JSON list) and a
  // manual region override (ISO country code).
  TextColumn get hiddenChamberIds => text().nullable()();
  TextColumn get emergencyRegion => text().nullable()();
  // Appearance settings
  BoolColumn get showDepthColoredDiveCards =>
      boolean().withDefault(const Constant(false))();
  // Card coloring settings (v35)
  TextColumn get cardColorAttribute =>
      text().withDefault(const Constant('none'))();
  TextColumn get cardColorGradientPreset =>
      text().withDefault(const Constant('ocean'))();
  IntColumn get cardColorGradientStart => integer().nullable()();
  IntColumn get cardColorGradientEnd => integer().nullable()();
  // Tissue visualization settings
  TextColumn get tissueColorScheme =>
      text().withDefault(const Constant('classic'))();
  TextColumn get tissueVizMode =>
      text().withDefault(const Constant('heatMap'))();
  BoolColumn get showMapBackgroundOnDiveCards =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get showMapBackgroundOnSiteCards =>
      boolean().withDefault(const Constant(false))();
  // Dive profile markers
  BoolColumn get showMaxDepthMarker =>
      boolean().withDefault(const Constant(true))();
  BoolColumn get showPressureThresholdMarkers =>
      boolean().withDefault(const Constant(false))();
  // Dive list view mode (v51)
  TextColumn get diveListViewMode =>
      text().withDefault(const Constant('detailed'))();
  // List view modes for other features (v52)
  TextColumn get siteListViewMode =>
      text().withDefault(const Constant('detailed'))();
  TextColumn get tripListViewMode =>
      text().withDefault(const Constant('detailed'))();
  TextColumn get equipmentListViewMode =>
      text().withDefault(const Constant('detailed'))();
  TextColumn get buddyListViewMode =>
      text().withDefault(const Constant('detailed'))();
  TextColumn get diveCenterListViewMode =>
      text().withDefault(const Constant('detailed'))();
  // Map style (v67)
  TextColumn get mapStyle =>
      text().withDefault(const Constant('openStreetMap'))();
  // Auto site matching sensitivity (v76): strict | balanced | relaxed
  TextColumn get siteMatchSensitivity =>
      text().withDefault(const Constant('balanced'))();
  // Dive profile chart defaults
  TextColumn get defaultRightAxisMetric =>
      text().withDefault(const Constant('temperature'))();
  BoolColumn get defaultShowTemperature =>
      boolean().withDefault(const Constant(true))();
  BoolColumn get defaultShowPressure =>
      boolean().withDefault(const Constant(true))();
  BoolColumn get defaultShowHeartRate =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get defaultShowSac =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get defaultShowEvents =>
      boolean().withDefault(const Constant(true))();
  BoolColumn get defaultShowPpO2 =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get defaultShowPpN2 =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get defaultShowPpHe =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get defaultShowGasDensity =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get defaultShowGf =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get defaultShowSurfaceGf =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get defaultShowMeanDepth =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get defaultShowTts =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get defaultShowCns =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get defaultShowOtu =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get defaultShowGasSwitchMarkers =>
      boolean().withDefault(const Constant(true))();
  BoolColumn get defaultShowGasTimeline =>
      boolean().withDefault(const Constant(false))();
  // Drift column declarations are codegen inputs shadowed by the generated
  // table at runtime, so this line is never executed (every sibling column
  // getter is likewise uncovered). The default is verified via the migration
  // and settings tests, not by exercising this declaration.
  // coverage:ignore-start
  BoolColumn get defaultShowAscentRateLine =>
      boolean().withDefault(const Constant(false))();
  // coverage:ignore-end
  // coverage:ignore-start
  BoolColumn get defaultShowPhotoMarkers =>
      boolean().withDefault(const Constant(true))();
  // coverage:ignore-end
  // Notification settings (v26)
  BoolColumn get notificationsEnabled =>
      boolean().withDefault(const Constant(true))();
  TextColumn get serviceReminderDays =>
      text().withDefault(const Constant('[7, 14, 30]'))(); // JSON array
  TextColumn get reminderTime =>
      text().withDefault(const Constant('09:00'))(); // HH:mm format
  // v122: days before a trip to nag about gear due before trip end.
  IntColumn get tripServiceLeadDays =>
      integer().withDefault(const Constant(14))();
  // Data source badge visibility (v55)
  BoolColumn get showDataSourceBadges =>
      boolean().withDefault(const Constant(true))();
  // Dive detail section order and visibility (v56) — JSON array
  TextColumn get diveDetailSections => text().nullable()();
  // Table view profile panel default visibility (v61)
  BoolColumn get showProfilePanelInTableView =>
      boolean().withDefault(const Constant(true))();
  // Per-section details pane visibility in table view (v63)
  BoolColumn get showDetailsPaneDives =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get showDetailsPaneSites =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get showDetailsPaneBuddies =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get showDetailsPaneTrips =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get showDetailsPaneEquipment =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get showDetailsPaneDiveCenters =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get showDetailsPaneCertifications =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get showDetailsPaneCourses =>
      boolean().withDefault(const Constant(false))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  /// Hybrid Logical Clock for cross-device conflict resolution
  /// (nullable: rows written before HLC rollout fall back to updatedAt).
  TextColumn get hlc => text().nullable()();

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
  TextColumn get photoPath => text().nullable()();
  TextColumn get notes => text().withDefault(const Constant(''))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  /// Hybrid Logical Clock for cross-device conflict resolution
  /// (nullable: rows written before HLC rollout fall back to updatedAt).
  TextColumn get hlc => text().nullable()();

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

/// Professional credentials held by a buddy (instructor, divemaster,
/// dive guide). One row per (buddy, role); the repository enforces that
/// logical uniqueness. Issue #395.
@DataClassName('BuddyRoleRow')
class BuddyRoles extends Table {
  TextColumn get id => text()();
  TextColumn get buddyId =>
      text().references(Buddies, #id, onDelete: KeyAction.cascade)();
  TextColumn get role => text()(); // BuddyRole enum name
  TextColumn get credentialNumber => text().nullable()();
  TextColumn get agency => text().nullable()(); // CertificationAgency enum name
  TextColumn get notes => text().withDefault(const Constant(''))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  /// Hybrid Logical Clock for cross-device conflict resolution
  /// (nullable: rows written before HLC rollout fall back to updatedAt).
  TextColumn get hlc => text().nullable()();

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
  // Structured instructor link (issue #395). The text fields above remain
  // the historical snapshot and survive buddy deletion.
  TextColumn get instructorId =>
      text().nullable().references(Buddies, #id, onDelete: KeyAction.setNull)();
  // Owner when this certification belongs to a buddy instead of the diver
  // (issue #553). At most one of {diverId, buddyId} is set (ownerless rows are
  // allowed -- legacy + no-validated-diver). Cascade so a buddy delete removes
  // their certs (deletion tombstones are written explicitly in the repository
  // -- cascade alone does not tombstone).
  TextColumn get buddyId =>
      text().nullable().references(Buddies, #id, onDelete: KeyAction.cascade)();
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

  /// Hybrid Logical Clock for cross-device conflict resolution
  /// (nullable: rows written before HLC rollout fall back to updatedAt).
  TextColumn get hlc => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Equipment service records
class ServiceRecords extends Table {
  TextColumn get id => text()();
  TextColumn get equipmentId =>
      text().references(Equipment, #id, onDelete: KeyAction.cascade)();
  TextColumn get serviceType => text()(); // annual, repair, inspection, etc.

  /// v122: which service kind this record fulfills (resets that clock).
  /// Plain text (no FK) so records survive custom-kind deletion.
  TextColumn get serviceKindId => text().nullable()();
  IntColumn get serviceDate => integer()();
  TextColumn get provider => text().nullable()(); // Shop or technician name
  RealColumn get cost => real().nullable()();
  TextColumn get currency => text().withDefault(const Constant('USD'))();
  IntColumn get nextServiceDue => integer().nullable()();
  TextColumn get notes => text().withDefault(const Constant(''))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  /// Hybrid Logical Clock for cross-device conflict resolution
  /// (nullable: rows written before HLC rollout fall back to updatedAt).
  TextColumn get hlc => text().nullable()();

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

  /// Hybrid Logical Clock for cross-device conflict resolution
  /// (nullable: rows written before HLC rollout fall back to updatedAt).
  TextColumn get hlc => text().nullable()();

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

  /// Hybrid Logical Clock for cross-device conflict resolution
  /// (nullable: rows written before HLC rollout fall back to updatedAt).
  TextColumn get hlc => text().nullable()();

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

  /// Hybrid Logical Clock for cross-device conflict resolution
  /// (nullable: rows written before HLC rollout fall back to updatedAt).
  TextColumn get hlc => text().nullable()();

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

/// Junction table for dive types (many-to-many).
///
/// Surrogate UUID primary key (never a composite key) so fresh-id reinserts
/// never collide with a replaced row's tombstone — this is how the junction
/// stays clear of the composite-key sync data-loss bug (#347).
class DiveDiveTypes extends Table {
  TextColumn get id => text()();
  TextColumn get diveId =>
      text().references(Dives, #id, onDelete: KeyAction.cascade)();
  TextColumn get diveTypeId => text()();
  IntColumn get createdAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Seeds one junction row per existing dive from its representative dive_type
/// slug. Used by the v92 migration and asserted directly in tests.
const String kSeedDiveDiveTypesSql = '''
  INSERT INTO dive_dive_types (id, dive_id, dive_type_id, created_at)
  SELECT
    lower(hex(randomblob(16))),
    id,
    COALESCE(NULLIF(dive_type, ''), 'recreational'),
    CAST(strftime('%s','now') AS INTEGER) * 1000
  FROM dives
''';

/// Seeds the built-in dive types. Used by BOTH [onCreate] (fresh installs) and
/// the v93 migration (backfill for upgraded databases). The full built-in set
/// was historically seeded only in onCreate, so every database that reached the
/// app via migration kept an EMPTY `dive_types` table -- harmless until the
/// multi-select dive-type picker (#414) read it and showed no options.
///
/// `INSERT OR IGNORE` keyed on the stable slug ids preserves any rows already
/// present (synced custom types, or 'cavern' added by the v88 migration) and
/// makes re-running the seed a no-op. Keep this list in sync with the
/// onboarding documentation; it is asserted directly in tests.
///
/// The timestamp is computed once (the trailing `CROSS JOIN`) and reused for
/// both `created_at` and `updated_at`, so the two can never diverge across a
/// `strftime('now')` second boundary.
const String kSeedBuiltInDiveTypesSql = '''
  INSERT OR IGNORE INTO dive_types
    (id, name, is_built_in, sort_order, created_at, updated_at)
  SELECT t.id, t.name, 1, t.sort_order, n.now_ms, n.now_ms
  FROM (
    SELECT 'recreational' AS id, 'Recreational' AS name, 0 AS sort_order
    UNION ALL SELECT 'technical', 'Technical', 1
    UNION ALL SELECT 'freedive', 'Freedive', 2
    UNION ALL SELECT 'training', 'Training', 3
    UNION ALL SELECT 'wreck', 'Wreck', 4
    UNION ALL SELECT 'cave', 'Cave', 5
    UNION ALL SELECT 'ice', 'Ice', 6
    UNION ALL SELECT 'night', 'Night', 7
    UNION ALL SELECT 'drift', 'Drift', 8
    UNION ALL SELECT 'deep', 'Deep', 9
    UNION ALL SELECT 'altitude', 'Altitude', 10
    UNION ALL SELECT 'shore', 'Shore', 11
    UNION ALL SELECT 'boat', 'Boat', 12
    UNION ALL SELECT 'liveaboard', 'Liveaboard', 13
    UNION ALL SELECT 'cavern', 'Cavern', 14
  ) t
  CROSS JOIN (SELECT CAST(strftime('%s','now') AS INTEGER) * 1000 AS now_ms) n
''';

/// Per-dive role vocabulary: built-in + custom (v103, issues #551/#547).
/// Built-in ids are the legacy BuddyRole enum names so existing
/// dive_buddies.role strings resolve without data migration; custom ids
/// are UUIDs so renames never break references.
@DataClassName('DiveRoleRow')
class DiveRoles extends Table {
  TextColumn get id => text()();
  TextColumn get diverId =>
      text().nullable().references(Divers, #id)(); // null for built-in roles
  TextColumn get name => text()();
  BoolColumn get isBuiltIn => boolean().withDefault(const Constant(false))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  /// Hybrid Logical Clock for cross-device conflict resolution
  /// (nullable: rows written before HLC rollout fall back to updatedAt).
  TextColumn get hlc => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Built-in pre-dive checklist templates. INSERT OR IGNORE keyed on stable
/// ids so re-seeding on every open is idempotent and restores replace-adopt
/// wipes. Built-ins are read-only in the UI and skipped by sync export.
/// Timestamps are the constant 0: built-ins are device-local reference data,
/// never synced, and deterministic values keep the statement idempotent.
const String kSeedBuiltInPreDiveTemplatesSql = '''
  INSERT OR IGNORE INTO pre_dive_checklist_templates
    (id, name, description, category, strict_order, is_built_in,
     builtin_key, created_at, updated_at)
  VALUES
    ('builtin-predive-bwraf', 'BWRAF Buddy Check',
     'Standard recreational pre-dive safety check',
     'Safety', 0, 1, 'builtin-predive-bwraf', 0, 0),
    ('builtin-predive-gue-edge', 'GUE EDGE',
     'Team pre-dive sequence',
     'Safety', 0, 1, 'builtin-predive-gue-edge', 0, 0),
    ('builtin-predive-ccr-build', 'CCR Build (generic)',
     'Generic rebreather assembly and pre-breathe checklist',
     'CCR', 1, 1, 'builtin-predive-ccr-build', 0, 0),
    ('builtin-predive-gear-packing', 'Gear Packing',
     'Pack and stage everything before leaving for the site',
     'Packing', 0, 1, 'builtin-predive-gear-packing', 0, 0)
''';

/// Items for the built-in pre-dive templates. Same idempotence contract as
/// [kSeedBuiltInPreDiveTemplatesSql].
const String kSeedBuiltInPreDiveTemplateItemsSql = '''
  INSERT OR IGNORE INTO pre_dive_checklist_template_items
    (id, template_id, section, title, notes, sort_order, item_type,
     value_label, value_unit, value_min, value_max, is_required,
     created_at, updated_at)
  VALUES
    ('builtin-predive-bwraf-0', 'builtin-predive-bwraf', NULL,
     'BCD / Buoyancy: inflate, deflate, dump valves', '', 0, 'check',
     NULL, NULL, NULL, NULL, 1, 0, 0),
    ('builtin-predive-bwraf-1', 'builtin-predive-bwraf', NULL,
     'Weights: in place, releases clear', '', 1, 'check',
     NULL, NULL, NULL, NULL, 1, 0, 0),
    ('builtin-predive-bwraf-2', 'builtin-predive-bwraf', NULL,
     'Releases: locate and check all buckles', '', 2, 'check',
     NULL, NULL, NULL, NULL, 1, 0, 0),
    ('builtin-predive-bwraf-3', 'builtin-predive-bwraf', NULL,
     'Air: valve open, breathe both regs, check gauge', '', 3, 'check',
     NULL, NULL, NULL, NULL, 1, 0, 0),
    ('builtin-predive-bwraf-4', 'builtin-predive-bwraf', NULL,
     'Final OK: mask, fins, computer set, buddy signal', '', 4, 'check',
     NULL, NULL, NULL, NULL, 1, 0, 0),
    ('builtin-predive-gue-0', 'builtin-predive-gue-edge', NULL,
     'Equipment: full gear check head to toe', '', 0, 'check',
     NULL, NULL, NULL, NULL, 1, 0, 0),
    ('builtin-predive-gue-1', 'builtin-predive-gue-edge', NULL,
     'Descent: agree on descent method and reference', '', 1, 'check',
     NULL, NULL, NULL, NULL, 1, 0, 0),
    ('builtin-predive-gue-2', 'builtin-predive-gue-edge', NULL,
     'Gas: analyze, label, confirm MOD and turn pressure', '', 2, 'check',
     NULL, NULL, NULL, NULL, 1, 0, 0),
    ('builtin-predive-gue-3', 'builtin-predive-gue-edge', NULL,
     'Environment: conditions, entry/exit, hazards', '', 3, 'check',
     NULL, NULL, NULL, NULL, 1, 0, 0),
    ('builtin-predive-ccr-0', 'builtin-predive-ccr-build', 'Assembly',
     'Scrubber packed and within duration limits', '', 0, 'check',
     NULL, NULL, NULL, NULL, 1, 0, 0),
    ('builtin-predive-ccr-1', 'builtin-predive-ccr-build', 'Assembly',
     'Loop assembled, mushroom valves checked', '', 1, 'check',
     NULL, NULL, NULL, NULL, 1, 0, 0),
    ('builtin-predive-ccr-2', 'builtin-predive-ccr-build', 'Tests',
     'Negative pressure test held 60 s', '', 2, 'check',
     NULL, NULL, NULL, NULL, 1, 0, 0),
    ('builtin-predive-ccr-3', 'builtin-predive-ccr-build', 'Tests',
     'Positive pressure test held 60 s', '', 3, 'check',
     NULL, NULL, NULL, NULL, 1, 0, 0),
    ('builtin-predive-ccr-4', 'builtin-predive-ccr-build', 'Cells',
     'Cell 1 mV in air', '', 4, 'value',
     'Cell 1', 'mV', 8.5, 13.0, 1, 0, 0),
    ('builtin-predive-ccr-5', 'builtin-predive-ccr-build', 'Cells',
     'Cell 2 mV in air', '', 5, 'value',
     'Cell 2', 'mV', 8.5, 13.0, 1, 0, 0),
    ('builtin-predive-ccr-6', 'builtin-predive-ccr-build', 'Cells',
     'Cell 3 mV in air', '', 6, 'value',
     'Cell 3', 'mV', 8.5, 13.0, 1, 0, 0),
    ('builtin-predive-ccr-7', 'builtin-predive-ccr-build', 'Gas',
     'Diluent and O2 analyzed, MOD labels on', '', 7, 'check',
     NULL, NULL, NULL, NULL, 1, 0, 0),
    ('builtin-predive-ccr-8', 'builtin-predive-ccr-build', 'Pre-breathe',
     'Five-minute pre-breathe, setpoint holds', '', 8, 'check',
     NULL, NULL, NULL, NULL, 1, 0, 0),
    ('builtin-predive-ccr-9', 'builtin-predive-ccr-build', 'Bailout',
     'Bailout analyzed, pressurized, clipped', '', 9, 'check',
     NULL, NULL, NULL, NULL, 1, 0, 0),
    ('builtin-predive-pack-0', 'builtin-predive-gear-packing', NULL,
     'Certification card and insurance', '', 0, 'check',
     NULL, NULL, NULL, NULL, 0, 0, 0),
    ('builtin-predive-pack-1', 'builtin-predive-gear-packing', NULL,
     'Equipment set', '', 1, 'equipmentSet',
     NULL, NULL, NULL, NULL, 0, 0, 0),
    ('builtin-predive-pack-2', 'builtin-predive-gear-packing', NULL,
     'Save-a-dive kit and spares', '', 2, 'check',
     NULL, NULL, NULL, NULL, 0, 0, 0),
    ('builtin-predive-pack-3', 'builtin-predive-gear-packing', NULL,
     'Water, sun protection, logbook', '', 3, 'check',
     NULL, NULL, NULL, NULL, 0, 0, 0)
''';

/// Seeds the nine built-in dive roles. Mirrors [kSeedBuiltInDiveTypesSql]:
/// INSERT OR IGNORE keyed on stable slug ids keeps it idempotent, and the
/// seed is re-asserted in beforeOpen so replace-adopt flows that clear the
/// table cannot leave built-ins missing. The timestamp is computed once via
/// the trailing CROSS JOIN.
const String kSeedBuiltInDiveRolesSql = '''
  INSERT OR IGNORE INTO dive_roles
    (id, name, is_built_in, sort_order, created_at, updated_at)
  SELECT t.id, t.name, 1, t.sort_order, n.now_ms, n.now_ms
  FROM (
    SELECT 'buddy' AS id, 'Buddy' AS name, 0 AS sort_order
    UNION ALL SELECT 'diveGuide', 'Dive Guide', 1
    UNION ALL SELECT 'instructor', 'Instructor', 2
    UNION ALL SELECT 'student', 'Student', 3
    UNION ALL SELECT 'diveMaster', 'Divemaster', 4
    UNION ALL SELECT 'solo', 'Solo', 5
    UNION ALL SELECT 'rearGuard', 'Rear Guard', 6
    UNION ALL SELECT 'supportDiver', 'Support Diver', 7
    UNION ALL SELECT 'safetyDiver', 'Safety Diver', 8
  ) t
  CROSS JOIN (SELECT CAST(strftime('%s','now') AS INTEGER) * 1000 AS now_ms) n
''';

/// Built-in service kinds: identical on every device, stable slug ids
/// (service_schedules.service_kind_id references them), INSERT OR IGNORE
/// so re-running is a no-op. Intervals per tech-diving convention.
const String kSeedBuiltInServiceKindsSql = '''
  INSERT OR IGNORE INTO service_kinds
    (id, diver_id, name, applicable_types, default_interval_days,
     default_interval_dives, default_interval_hours, auto_attach,
     is_built_in, created_at, updated_at)
  SELECT t.id, NULL, t.name, t.types, t.days, t.dives, NULL, t.auto, 1,
         n.now_ms, n.now_ms
  FROM (
    SELECT 'hydro' AS id, 'Hydrostatic test' AS name, '["tank"]' AS types,
           1825 AS days, NULL AS dives, 1 AS auto
    UNION ALL SELECT 'vip', 'Visual inspection (VIP)', '["tank"]',
           365, NULL, 1
    UNION ALL SELECT 'o2-clean', 'O2 clean', '["tank"]', 365, NULL, 0
    UNION ALL SELECT 'regulator-service', 'Regulator service',
           '["regulator"]', 365, 100, 1
    UNION ALL SELECT 'computer-battery', 'Computer battery', '["computer"]',
           730, NULL, 1
    UNION ALL SELECT 'transmitter-battery', 'Transmitter battery',
           '["transmitter"]', 365, NULL, 1
    UNION ALL SELECT 'bcd-inspection', 'BCD/wing inspection', '["bcd"]',
           365, NULL, 1
    UNION ALL SELECT 'drysuit-seals', 'Drysuit seals', '["drysuit"]',
           730, NULL, 0
    UNION ALL SELECT 'general-service', 'General service', '[]',
           NULL, NULL, 0
  ) t
  CROSS JOIN (SELECT CAST(strftime('%s','now') AS INTEGER) * 1000 AS now_ms) n
''';

/// Custom tank presets (user-defined tank configurations)
class TankPresets extends Table {
  TextColumn get id => text()();
  TextColumn get diverId =>
      text().nullable().references(Divers, #id)(); // Owner of preset
  TextColumn get name => text()(); // Internal name/identifier
  TextColumn get displayName => text()(); // User-friendly display name
  RealColumn get volumeLiters => real()(); // Water volume in liters
  RealColumn get workingPressureBar => real()(); // Rated working pressure
  TextColumn get material => text()(); // aluminum, steel, carbonFiber
  TextColumn get description =>
      text().withDefault(const Constant(''))(); // Optional description
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  /// Hybrid Logical Clock for cross-device conflict resolution
  /// (nullable: rows written before HLC rollout fall back to updatedAt).
  TextColumn get hlc => text().nullable()();

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
  TextColumn get firmwareVersion => text().nullable()();
  TextColumn get connectionType =>
      text().nullable()(); // "bluetooth", "usb", "ble"
  TextColumn get bluetoothAddress => text().nullable()(); // MAC address
  TextColumn get lastDiveFingerprint => text().nullable()();
  IntColumn get lastDownloadTimestamp =>
      integer().nullable()(); // Unix timestamp
  IntColumn get diveCount => integer().withDefault(const Constant(0))();
  BoolColumn get isFavorite => boolean().withDefault(const Constant(false))();
  TextColumn get notes => text().withDefault(const Constant(''))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  /// Hybrid Logical Clock for cross-device conflict resolution
  /// (nullable: rows written before HLC rollout fall back to updatedAt).
  TextColumn get hlc => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Per-source metadata snapshots for multi-source dives.
/// Only populated when a dive has data from multiple sources.
@DataClassName('DiveDataSourcesData')
class DiveDataSources extends Table {
  TextColumn get id => text()();
  TextColumn get diveId =>
      text().references(Dives, #id, onDelete: KeyAction.cascade)();
  TextColumn get computerId => text().nullable().references(
    DiveComputers,
    #id,
    onDelete: KeyAction.setNull,
  )();
  BoolColumn get isPrimary => boolean().withDefault(const Constant(false))();
  TextColumn get computerModel => text().nullable()();
  TextColumn get computerSerial => text().nullable()();
  TextColumn get sourceFormat => text().nullable()();
  TextColumn get sourceFileName => text().nullable()();
  TextColumn get sourceFileFormat => text().nullable()();
  RealColumn get maxDepth => real().nullable()();
  RealColumn get avgDepth => real().nullable()();
  IntColumn get duration => integer().nullable()();
  RealColumn get waterTemp => real().nullable()();
  RealColumn get entryLatitude => real().nullable()();
  RealColumn get entryLongitude => real().nullable()();
  RealColumn get exitLatitude => real().nullable()();
  RealColumn get exitLongitude => real().nullable()();
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
  BlobColumn get rawData => blob().nullable()();
  BlobColumn get rawFingerprint => blob().nullable()();
  TextColumn get sourceUuid => text().nullable()();
  TextColumn get descriptorVendor => text().nullable()();
  TextColumn get descriptorProduct => text().nullable()();
  IntColumn get descriptorModel => integer().nullable()();
  TextColumn get libdivecomputerVersion => text().nullable()();
  DateTimeColumn get lastParsedAt => dateTime().nullable()();

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
  TextColumn get source =>
      text().withDefault(const Constant('imported'))(); // EventSource.name
  // Which computer contributed this event (null = primary source / manual).
  // Same null-means-primary semantics as dive_profiles.computerId; deletes
  // set null.
  TextColumn get computerId => text().nullable().references(
    DiveComputers,
    #id,
    onDelete: KeyAction.setNull,
  )();
  IntColumn get createdAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Marker row recording that the safety review engine has analyzed a dive.
/// Lets zero-findings (clean) dives be distinguished from never-analyzed
/// dives without replaying the profile. Write-once child of Dives: no HLC
/// columns; sync uses markRecordPending/logDeletion like DiveProfileEvents.
class DiveSafetyReviews extends Table {
  TextColumn get diveId =>
      text().references(Dives, #id, onDelete: KeyAction.cascade)();
  IntColumn get engineVersion => integer()();
  IntColumn get reviewedAt => integer()();

  @override
  Set<Column> get primaryKey => {diveId};
}

/// One safety review observation for a dive (see SafetyFinding entity).
/// Write-once child of Dives except for dismissed_at, which toggles.
class DiveSafetyFindings extends Table {
  TextColumn get id => text()();
  TextColumn get diveId =>
      text().references(Dives, #id, onDelete: KeyAction.cascade)();
  TextColumn get ruleId => text()(); // SafetyRuleId.dbValue
  TextColumn get severity => text()(); // SafetySeverity.dbValue
  IntColumn get startTimestamp => integer().nullable()();
  IntColumn get endTimestamp => integer().nullable()();
  RealColumn get value => real().nullable()();
  IntColumn get engineVersion => integer()();
  IntColumn get dismissedAt => integer().nullable()();
  IntColumn get createdAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

/// User-added hyperbaric chamber entries for the offline emergency card
/// (bundled chambers stay asset-resident). Aggregate root with HLC for
/// cross-device conflict resolution.
class EmergencyChambers extends Table {
  TextColumn get id => text()();
  TextColumn get diverId =>
      text().nullable().references(Divers, #id, onDelete: KeyAction.cascade)();
  TextColumn get name => text()();
  TextColumn get country => text()();
  TextColumn get city => text().nullable()();
  TextColumn get phone => text()();
  RealColumn get latitude => real().nullable()();
  RealColumn get longitude => real().nullable()();
  TextColumn get notes => text().nullable()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  TextColumn get hlc => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Near-miss incident reports (safety phase 4). Standalone aggregate root
/// with optional dive link; the link is severed (not cascaded) on dive
/// deletion so the report survives. Synced between the diver's devices but
/// deliberately absent from every outbound exporter.
class Incidents extends Table {
  TextColumn get id => text()();
  TextColumn get diverId =>
      text().nullable().references(Divers, #id, onDelete: KeyAction.cascade)();
  TextColumn get diveId =>
      text().nullable().references(Dives, #id, onDelete: KeyAction.setNull)();
  IntColumn get occurredAt => integer()();
  TextColumn get category => text()();
  TextColumn get severity => text()();
  TextColumn get narrative => text()();
  TextColumn get contributingFactors => text().nullable()();
  TextColumn get lessonsLearned => text().nullable()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  TextColumn get hlc => text().nullable()();

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
  // Which computer contributed this pressure sample (null = primary source /
  // manual). Same null-means-primary semantics as dive_profiles.computerId;
  // deletes set null.
  TextColumn get computerId => text().nullable().references(
    DiveComputers,
    #id,
    onDelete: KeyAction.setNull,
  )();

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
      text().nullable()(); // 'icloud', 'googledrive', or 's3'

  /// The connected account driving sync, or null pre-account-migration.
  /// syncProvider stays populated (kind name) for backward compatibility.
  TextColumn get syncAccountId => text().nullable()();
  TextColumn get remoteFileId =>
      text().nullable()(); // Provider-specific file reference
  IntColumn get syncVersion =>
      integer().withDefault(const Constant(1))(); // Sync format version
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  /// Hybrid Logical Clock for cross-device conflict resolution
  /// (nullable: rows written before HLC rollout fall back to updatedAt).
  TextColumn get hlc => text().nullable()();

  /// Opaque per-database token, rotated on each launch and mirrored outside the
  /// database. A mismatch between this and the mirrored copy means the on-disk
  /// database was replaced (restore/overwrite), even when the device id is
  /// unchanged. Nullable: rows predating this column read as "no token yet".
  TextColumn get instanceToken => text().nullable()();

  /// The library epoch this device last accepted (see library_epoch.dart).
  /// Dual-anchored: mirrored in SharedPreferences so a database restore
  /// cannot silently rewind it. Null means the pre-epoch world.
  TextColumn get lastAcceptedEpochId => text().nullable()();

  /// The provider [lastSyncTimestamp] was minted against. A cursor read for a
  /// different provider returns null, so first contact with a newly switched
  /// backend is detectable. Null means a legacy cursor (pre-stamp rows),
  /// valid for any provider. Written only together with the cursor.
  TextColumn get lastSyncProvider => text().nullable()();

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
  // Monotonic HLC stamped at deletion time (local filter metadata only, not on
  // the wire). Lets an incremental changeset carry only tombstones newer than
  // the published watermark instead of re-sending the whole log every sync.
  // Nullable as a safety net: the v86 migration backfills pre-existing rows to a
  // minimal sentinel, so null only arises for a delete logged before the sync
  // clock was configured; such a tombstone is always included in a base.
  TextColumn get hlc => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Per-peer download cursor: how far this device has consumed each peer's
/// changeset log. Scoped per provider so a backend switch starts fresh
/// (mirrors the v81 per-provider cursor lesson).
@DataClassName('SyncPeerCursor')
class SyncPeerCursors extends Table {
  TextColumn get peerDeviceId => text()();
  TextColumn get provider => text()();
  IntColumn get baseSeqApplied => integer().nullable()();
  IntColumn get lastSeqApplied => integer().withDefault(const Constant(0))();

  // Highest HLC applied FROM this peer's log -- published in our manifest's
  // appliedPeerHlc map so the peer can garbage-collect tombstones we have
  // provably seen (fleet-acked horizon).
  TextColumn get appliedHlcHigh => text().nullable()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {peerDeviceId, provider};
}

/// This device's own published position in its changeset log, per provider.
/// Splits the old conflated lastSyncTimestamp: this is the upload side
/// (per-peer cursors are the download side).
@DataClassName('LocalPublishState')
class LocalPublishStates extends Table {
  TextColumn get provider => text()();
  IntColumn get baseSeq => integer().nullable()();
  IntColumn get basePartCount => integer().nullable()();
  IntColumn get baseBytes => integer().nullable()();
  IntColumn get headSeq => integer().withDefault(const Constant(0))();
  TextColumn get publishedHlcHigh => text().nullable()();
  IntColumn get changesetBytesSinceBase =>
      integer().withDefault(const Constant(0))();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {provider};
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
  // Link to earned certification (bidirectional, no FK to avoid circular ref)
  TextColumn get certificationId => text().nullable()();
  TextColumn get location => text().nullable()(); // Dive center/shop
  TextColumn get notes => text().withDefault(const Constant(''))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  /// Hybrid Logical Clock for cross-device conflict resolution
  /// (nullable: rows written before HLC rollout fall back to updatedAt).
  TextColumn get hlc => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Countable requirements for a training course (requirement tracker spec,
/// docs/superpowers/specs/2026-07-16-course-requirement-tracker-design.md).
/// kind is a RequirementKind enum name: 'dive' rows derive progress from
/// course_requirement_dives links; 'checklist' rows complete via completedAt.
@DataClassName('CourseRequirementRow')
class CourseRequirements extends Table {
  TextColumn get id => text()();
  TextColumn get courseId =>
      text().references(Courses, #id, onDelete: KeyAction.cascade)();
  TextColumn get name => text()();
  TextColumn get kind => text()();
  IntColumn get targetCount => integer().withDefault(const Constant(1))();
  IntColumn get completedAt => integer().nullable()(); // Unix ms, checklist
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  TextColumn get notes => text().nullable()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  /// Hybrid Logical Clock for cross-device conflict resolution
  /// (nullable: rows written before HLC rollout fall back to updatedAt).
  TextColumn get hlc => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Junction crediting a logged dive toward a course requirement.
///
/// The id is a DETERMINISTIC UUIDv5 of (requirementId, diveId) -- see
/// CourseRequirementRepository.linkIdFor -- so the same link created on two
/// devices converges to a single row under sync upsert; no unique index is
/// needed. No hlc column: delta export is gated by the parent requirement's
/// hlc, which linkDive/unlinkDive bump (equipment_set_items pattern).
@DataClassName('CourseRequirementDiveRow')
class CourseRequirementDives extends Table {
  TextColumn get id => text()();
  TextColumn get requirementId =>
      text().references(CourseRequirements, #id, onDelete: KeyAction.cascade)();
  TextColumn get diveId =>
      text().references(Dives, #id, onDelete: KeyAction.cascade)();
  IntColumn get createdAt => integer()();

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

  /// v122: the service schedule this reminder belongs to (null = legacy
  /// single-clock reminder). Local-only table, not synced.
  TextColumn get scheduleId => text().nullable()();
  IntColumn get scheduledDate => integer()(); // Unix timestamp
  IntColumn get reminderDaysBefore => integer()(); // 7, 14, or 30
  IntColumn get notificationId => integer()(); // Platform notification ID
  IntColumn get createdAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

/// User-saved CSV import presets (synced across devices; carries an hlc column)
class CsvPresets extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get presetJson => text()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  /// Hybrid Logical Clock for cross-device conflict resolution
  /// (nullable: rows written before HLC rollout fall back to updatedAt).
  TextColumn get hlc => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Stores the active view configuration per (diver, view_mode).
class ViewConfigs extends Table {
  TextColumn get id => text()();
  TextColumn get diverId =>
      text().references(Divers, #id, onDelete: KeyAction.cascade)();
  TextColumn get viewMode => text()();
  TextColumn get configJson => text()();
  IntColumn get updatedAt => integer()();

  /// Hybrid Logical Clock for cross-device conflict resolution
  /// (nullable: rows written before HLC rollout fall back to updatedAt).
  TextColumn get hlc => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Named presets per (diver, view_mode).
class FieldPresets extends Table {
  TextColumn get id => text()();
  TextColumn get diverId =>
      text().references(Divers, #id, onDelete: KeyAction.cascade)();
  TextColumn get viewMode => text()();
  TextColumn get name => text()();
  TextColumn get configJson => text()();
  BoolColumn get isBuiltIn => boolean().withDefault(const Constant(false))();
  IntColumn get createdAt => integer()();
  TextColumn get hlc => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

// ============================================================================
// Database Class
// ============================================================================

/// Prefix of the deterministic id for a synthesized/backfilled primary data
/// source -- the row a dive gets when it has profile samples but no
/// dive_data_sources row (older file imports). Shared by the beforeOpen
/// backfill ([AppDatabase._backfillMissingDataSources]) and the read-time
/// synthesis ([DiveRepository.getProfilesByDataSource]) so the id a consumer
/// sees before the heal equals the id persisted afterward. Never change it:
/// existing databases already carry rows with this exact prefix.
const String kLegacyDataSourceIdPrefix = 'legacy-src-';

/// Full deterministic data-source id for [diveId]. See
/// [kLegacyDataSourceIdPrefix].
String legacyDataSourceId(String diveId) => '$kLegacyDataSourceIdPrefix$diveId';

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
    DiverWeightEntries,
    DivePlanEquipment,
    EquipmentSets,
    EquipmentSetItems,
    EquipmentSetGeofences,
    QualityFindings,
    EquipmentAttributes,
    Species,
    Sightings,
    Media,
    MediaEnrichment,
    MediaSpecies,
    PendingPhotoSuggestions,
    Settings,
    Buddies,
    DiveBuddies,
    BuddyRoles,
    Certifications,
    ServiceRecords,
    DiveCenters,
    Tags,
    DiveTags,
    DiveDiveTypes,
    DiveTypes,
    DiveRoles,
    TankPresets,
    DiveComputers,
    DiveDataSources,
    DiveProfileEvents,
    DiveSafetyReviews,
    DiveSafetyFindings,
    EmergencyChambers,
    Incidents,
    GasSwitches,
    TankPressureProfiles,
    TideRecords,
    // Site-species junction
    SiteSpecies,
    // Training courses (v1.5)
    Courses,
    // Course requirement tracker (v121)
    CourseRequirements,
    CourseRequirementDives,
    // Sync tables
    SyncMetadata,
    SyncRecords,
    DeletionLog,
    SyncPeerCursors,
    LocalPublishStates,
    // Maps & Visualization
    CachedRegions,
    // Notifications
    ScheduledNotifications,
    // User-defined custom fields
    DiveCustomFields,
    // Liveaboard tracking (v2.0)
    LiveaboardDetailRecords,
    TripItineraryDays,
    ChecklistTemplates,
    ChecklistTemplateItems,
    TripChecklistItems,
    // Pre-dive checklists (spec 2026-07-16-pre-dive-checklist)
    PreDiveChecklistTemplates,
    PreDiveChecklistTemplateItems,
    PreDiveSessions,
    PreDiveSessionItems,
    // GPS surface track logging (discussion #289)
    GpsTracks,
    GpsTrackPointsLocal,
    // Saved dive plans (planner redesign Phase 2)
    DivePlans,
    DivePlanTanks,
    DivePlanSegments,
    // CSV import presets (local-only)
    CsvPresets,
    // Column view configuration
    ViewConfigs,
    FieldPresets,
    MediaSubscriptions,
    MediaSubscriptionState,
    NetworkCredentialHosts,
    MediaFetchDiagnostics,
    MediaStores,
    ConnectedAccounts,
    ServiceKinds,
    ServiceSchedules,
  ],
)
class AppDatabase extends _$AppDatabase {
  final void Function(int currentStep, int totalSteps)? onMigrationProgress;

  AppDatabase(super.e, {this.onMigrationProgress});

  /// The current schema version as a static constant so that pre-open checks
  /// (e.g. version-mismatch guard) can reference it without an instance.
  static const int currentSchemaVersion = 134;

  /// Every schema version that has a migration block in onUpgrade.
  /// Used to calculate progress step counts. When adding a new migration,
  /// append the new version number here.
  static const List<int> migrationVersions = [
    2,
    3,
    4,
    5,
    6,
    7,
    8,
    9,
    10,
    11,
    12,
    13,
    14,
    15,
    16,
    17,
    18,
    19,
    20,
    21,
    22,
    23,
    24,
    25,
    26,
    27,
    28,
    29,
    30,
    31,
    32,
    33,
    34,
    35,
    36,
    37,
    38,
    39,
    40,
    41,
    42,
    43,
    45,
    46,
    47,
    48,
    49,
    50,
    51,
    52,
    53,
    54,
    55,
    56,
    57,
    58,
    59,
    60,
    61,
    62,
    63,
    64,
    65,
    66,
    67,
    68,
    69,
    70,
    71,
    72,
    73,
    74,
    75,
    76,
    77,
    78,
    79,
    80,
    81,
    82,
    83,
    84,
    85,
    86,
    87,
    88,
    89,
    90,
    91,
    92,
    93,
    94,
    95,
    96,
    97,
    98,
    99,
    100,
    101,
    102,
    103,
    104,
    105,
    106,
    107,
    108,
    109,
    110,
    111,
    112,
    113,
    114,
    // v120 claimed in-worktree for the planner Subsurface-parity columns;
    // 115-119 belong to other branches and interleave at merge time.
    120,
    // v121: course requirement tracker tables (renumbered from v114 at merge
    // time; v114 became the tombstone-GC migration on main).
    121,
    // v122: gear service ledger (renumbered from v115 as main advanced past
    // it; see schema-version ladder).
    122,
    // v123: post-dive safety review tables + diver safety settings columns
    // (renumbered from v115 as main advanced past it at merge time).
    123,
    // v124: equipment type-specific attributes (renumbered from v115/v123 as
    // main advanced past it at merge time; see schema-version ladder).
    124,
    // v125: diver_settings.no_fly_preset column (safety phase 2, no-fly
    // countdown). Renumbered from v117/v124 as main advanced past it at merge
    // time.
    125,
    // v126: emergency_chambers table + emergency card settings columns
    // (renumbered from v118 as main advanced past it at merge time).
    126,
    // v127: incidents table (near-miss log, safety phase 4). Renumbered from
    // v119 as main advanced past it at merge time.
    127,
    // v128: pre-dive checklist tables + built-in template seeds (renumbered
    // from v117/v127 as main advanced past it at merge time).
    128,
    // v129: quality_findings table for the Data Quality Assistant (renumbered
    // from v118 as main advanced past it at merge time).
    129,
    // v130: media_enrichment.hlc so a photo's depth/time association syncs.
    130,
    // v131: reconcile legacy service intervals edited after the v122 backfill
    // into General service clocks (deletion-log guarded).
    131,
    // v132: backfill dives whose bottom_time was wrongly stored equal to
    // runtime by older imports, recomputing it from the primary profile.
    132,
    // v133: deco stop band columns on diver_settings (renumbered from v130 as
    // main advanced past it at merge time).
    133,
    // v134: media compressed-rendition columns (adjustable upload quality
    // Phase A). Renumbered from v130 as main advanced past it at merge time.
    134,
  ];

  /// Idempotent DDL for the v106 connector-suggestion columns (Lightroom
  /// auto-linking). Called from the v106 onUpgrade block and from the
  /// beforeOpen backstop so a parallel-branch schema-version collision
  /// cannot strand a database without them.
  Future<void> _assertConnectorSuggestionColumns() async {
    final cols = await customSelect(
      "PRAGMA table_info('pending_photo_suggestions')",
    ).get();
    // An empty PRAGMA result means the table itself is absent (only
    // possible in minimal test fixtures); skip the ALTERs rather than fail.
    if (cols.isEmpty) return;
    final names = cols.map((c) => c.read<String>('name')).toSet();
    if (!names.contains('connector_account_id')) {
      await customStatement(
        'ALTER TABLE pending_photo_suggestions '
        'ADD COLUMN connector_account_id TEXT',
      );
    }
    if (!names.contains('remote_asset_id')) {
      await customStatement(
        'ALTER TABLE pending_photo_suggestions '
        'ADD COLUMN remote_asset_id TEXT',
      );
    }
  }

  /// v107: connected accounts roster + sync account selection. Idempotent;
  /// also run from beforeOpen as a parallel-branch collision backstop.
  Future<void> _assertConnectedAccountsSchema() async {
    await customStatement(
      'CREATE TABLE IF NOT EXISTS connected_accounts ('
      'id TEXT NOT NULL PRIMARY KEY, '
      'kind TEXT NOT NULL, '
      'label TEXT NOT NULL, '
      'account_identifier TEXT, '
      'created_at INTEGER NOT NULL, '
      'updated_at INTEGER NOT NULL, '
      'hlc TEXT)',
    );
    final metaCols = await customSelect(
      "PRAGMA table_info('sync_metadata')",
    ).get();
    if (metaCols.isNotEmpty &&
        !metaCols.any((c) => c.read<String>('name') == 'sync_account_id')) {
      await customStatement(
        'ALTER TABLE sync_metadata ADD COLUMN sync_account_id TEXT',
      );
    }
  }

  /// v108: HLC on media_subscriptions so the table can sync. Idempotent;
  /// also run from beforeOpen as a parallel-branch collision backstop.
  Future<void> _assertMediaSubscriptionsHlc() async {
    final cols = await customSelect(
      "PRAGMA table_info('media_subscriptions')",
    ).get();
    // An empty PRAGMA result means the table itself is absent (only
    // possible in minimal test fixtures); skip the ALTER rather than fail.
    if (cols.isEmpty) return;
    if (!cols.any((c) => c.read<String>('name') == 'hlc')) {
      await customStatement(
        'ALTER TABLE media_subscriptions ADD COLUMN hlc TEXT',
      );
    }
  }

  /// Idempotent DDL for the issue #553 buddy-owner column on certifications.
  /// Called from the v109 onUpgrade block and the beforeOpen backstop.
  Future<void> _assertCertificationBuddyOwnerColumn() async {
    final cols = await customSelect(
      "PRAGMA table_info('certifications')",
    ).get();
    if (cols.isEmpty) return;
    final has = cols.any((c) => c.read<String>('name') == 'buddy_id');
    if (!has) {
      await customStatement(
        'ALTER TABLE certifications ADD COLUMN buddy_id TEXT '
        'REFERENCES buddies (id) ON DELETE CASCADE',
      );
    }
  }

  /// v124: equipment_attributes table + indexes. Idempotent so it is safe to
  /// call from both onUpgrade and the beforeOpen backstop. Deliberately does
  /// NOT copy legacy data -- see _migrateLegacyEquipmentColumnsToAttributes,
  /// which must run exactly once (re-running it on open would resurrect
  /// attribute rows the user has since cleared).
  Future<void> _assertEquipmentAttributesSchema() async {
    await createMigrator().createTable(equipmentAttributes);
    await customStatement('''
      CREATE INDEX IF NOT EXISTS idx_equipment_attributes_equipment_id
      ON equipment_attributes(equipment_id)
    ''');
    await customStatement('''
      CREATE INDEX IF NOT EXISTS idx_equipment_attributes_key_num
      ON equipment_attributes(attr_key, value_num)
    ''');
  }

  /// v124 data copy: legacy equipment.size/thickness/buoyancy_kg/weight_kg
  /// into equipment_attributes rows. Deterministic ids and parent-row
  /// timestamps make the result byte-identical on every device that runs the
  /// migration, so no sync traffic is needed to converge; hlc stays NULL
  /// (LWW falls back to updated_at, same as pre-HLC equipment rows).
  /// INSERT OR IGNORE keeps a re-run harmless, but this is still only called
  /// from onUpgrade (never beforeOpen) to avoid resurrecting cleared values.
  Future<void> _migrateLegacyEquipmentColumnsToAttributes() async {
    // PRAGMA-guarded like every other migration helper: a database without
    // the equipment table or without a given legacy column (minimal
    // old-schema test fixtures; ancient databases) simply has nothing to
    // copy for that column.
    final cols = await customSelect("PRAGMA table_info('equipment')").get();
    final names = cols.map((c) => c.read<String>('name')).toSet();
    if (names.isEmpty) return;
    // Every copy reads the parent-row timestamps.
    if (!names.contains('created_at') || !names.contains('updated_at')) {
      return;
    }
    if (names.contains('size')) await _copyLegacySizeColumn();
    if (names.contains('thickness')) await _copyLegacyThicknessColumn();
    if (names.contains('buoyancy_kg')) await _copyLegacyBuoyancyColumn();
    if (names.contains('weight_kg')) await _copyLegacyDryWeightColumn();
  }

  Future<void> _copyLegacySizeColumn() async {
    await customStatement('''
      INSERT OR IGNORE INTO equipment_attributes
        (id, equipment_id, attr_key, is_custom, value_text, value_num,
         sort_order, created_at, updated_at, hlc)
      SELECT 'attr_' || id || '_size', id, 'size', 0, TRIM(size), NULL,
             0, created_at, updated_at, NULL
      FROM equipment WHERE size IS NOT NULL AND TRIM(size) != ''
    ''');
  }

  Future<void> _copyLegacyThicknessColumn() async {
    await customStatement('''
      INSERT OR IGNORE INTO equipment_attributes
        (id, equipment_id, attr_key, is_custom, value_text, value_num,
         sort_order, created_at, updated_at, hlc)
      SELECT 'attr_' || id || '_thickness_mm', id, 'thickness_mm', 0,
             TRIM(thickness),
             CASE WHEN TRIM(thickness) GLOB '[0-9]*'
                  THEN CAST(TRIM(thickness) AS REAL) ELSE NULL END,
             0, created_at, updated_at, NULL
      FROM equipment WHERE thickness IS NOT NULL AND TRIM(thickness) != ''
    ''');
  }

  Future<void> _copyLegacyBuoyancyColumn() async {
    await customStatement('''
      INSERT OR IGNORE INTO equipment_attributes
        (id, equipment_id, attr_key, is_custom, value_text, value_num,
         sort_order, created_at, updated_at, hlc)
      SELECT 'attr_' || id || '_buoyancy_kg', id, 'buoyancy_kg', 0, NULL,
             buoyancy_kg, 0, created_at, updated_at, NULL
      FROM equipment WHERE buoyancy_kg IS NOT NULL
    ''');
  }

  Future<void> _copyLegacyDryWeightColumn() async {
    await customStatement('''
      INSERT OR IGNORE INTO equipment_attributes
        (id, equipment_id, attr_key, is_custom, value_text, value_num,
         sort_order, created_at, updated_at, hlc)
      SELECT 'attr_' || id || '_dry_weight_kg', id, 'dry_weight_kg', 0, NULL,
             weight_kg, 0, created_at, updated_at, NULL
      FROM equipment WHERE weight_kg IS NOT NULL
    ''');
  }

  /// v132 data fix: older imports (Subsurface/MacDive/CSV routed through the
  /// UDDF entity importer) seeded `bottom_time` from the total-time `duration`,
  /// so bottom time was stored equal to `runtime`. For any such dive that also
  /// carries a profile, recompute bottom time from the PRIMARY profile the same
  /// way [Dive.calculateBottomTimeFromProfile] does (time at/above 85% of max
  /// depth) and correct it only when the derived value is shorter than runtime.
  ///
  /// Deterministic on every device, so `hlc` is left untouched and no sync
  /// traffic is needed to converge (LWW falls back to the existing hlc /
  /// updated_at, exactly like the v124 legacy-attribute copy). PRAGMA-guarded
  /// for minimal old-schema fixtures. onUpgrade only -- never beforeOpen -- so
  /// a dive a user deliberately left with bottom_time == runtime (and no
  /// profile to prove otherwise) is never re-touched.
  Future<void> _backfillBottomTimeFromProfile() async {
    // PRAGMA-guarded like every other migration helper: minimal old-schema
    // test fixtures (and any DB that reached this block through a guarded
    // path) may lack the tables or the specific columns this reads, in which
    // case there is simply nothing to backfill.
    final diveCols = await customSelect("PRAGMA table_info('dives')").get();
    final diveColNames = diveCols.map((c) => c.read<String>('name')).toSet();
    if (!diveColNames.contains('bottom_time') ||
        !diveColNames.contains('runtime')) {
      return;
    }
    final profileCols = await customSelect(
      "PRAGMA table_info('dive_profiles')",
    ).get();
    final profileColNames = profileCols
        .map((c) => c.read<String>('name'))
        .toSet();
    if (!profileColNames.contains('dive_id') ||
        !profileColNames.contains('is_primary') ||
        !profileColNames.contains('timestamp') ||
        !profileColNames.contains('depth')) {
      return;
    }

    final candidates = await customSelect(
      'SELECT id, runtime FROM dives '
      'WHERE bottom_time IS NOT NULL AND runtime IS NOT NULL '
      'AND bottom_time = runtime',
    ).get();

    for (final candidate in candidates) {
      final diveId = candidate.read<String>('id');
      final runtimeSeconds = candidate.read<int>('runtime');

      // Primary profile rows only, mirroring the domain profile hydration in
      // DiveRepositoryImpl (is_primary = 1); mixing a secondary computer's rows
      // would compute the wrong bottom window.
      final points = await customSelect(
        'SELECT timestamp, depth FROM dive_profiles '
        'WHERE dive_id = ? AND is_primary = 1 '
        'ORDER BY timestamp ASC',
        variables: [Variable<String>(diveId)],
      ).get();

      final bottomSeconds = _bottomTimeSecondsFromProfileRows(points);
      if (bottomSeconds != null && bottomSeconds < runtimeSeconds) {
        await customStatement('UPDATE dives SET bottom_time = ? WHERE id = ?', [
          bottomSeconds,
          diveId,
        ]);
      }
    }
  }

  /// Bottom time in seconds from timestamp-ordered profile rows, replicating
  /// [Dive.calculateBottomTimeFromProfile]: the span between the first and last
  /// samples at/above 85% of max depth. Returns null when the profile is too
  /// small or lacks a clear bottom window.
  int? _bottomTimeSecondsFromProfileRows(List<QueryRow> points) {
    if (points.length < 3) return null;

    var maxDepth = 0.0;
    for (final point in points) {
      final depth = point.read<double>('depth');
      if (depth > maxDepth) maxDepth = depth;
    }
    if (maxDepth <= 0) return null;

    final threshold = maxDepth * 0.85;

    int? descentEnd;
    for (final point in points) {
      if (point.read<double>('depth') >= threshold) {
        descentEnd = point.read<int>('timestamp');
        break;
      }
    }

    int? ascentStart;
    for (var i = points.length - 1; i >= 0; i--) {
      if (points[i].read<double>('depth') >= threshold) {
        ascentStart = points[i].read<int>('timestamp');
        break;
      }
    }

    if (descentEnd == null || ascentStart == null) return null;
    if (ascentStart <= descentEnd) return null;
    return ascentStart - descentEnd;
  }

  /// v114: collapse duplicate tombstones (newest deleted_at per entity_type +
  /// record_id wins) and (re-)assert the unique index that keeps the deletion
  /// log collapsed. Cheap when the index already exists; the dedupe DELETE
  /// only runs when index creation fails *and* actual duplicates are present.
  /// Any other index-creation failure (corruption, disk full, locked DB) is
  /// rethrown unchanged rather than masked behind a destructive DELETE. Called
  /// from the v114 upgrade and the beforeOpen backstop (parallel-branch
  /// schema-version collisions heal here, mirroring the v111 backstop).
  Future<void> ensureDeletionLogIndex() async {
    // Self-guarding when the table is absent (minimal migration-test
    // fixtures), mirroring the other beforeOpen backstop helpers.
    final table = await customSelect(
      "SELECT name FROM sqlite_master WHERE type='table' AND name='deletion_log'",
    ).get();
    if (table.isEmpty) return;
    const createIndex =
        'CREATE UNIQUE INDEX IF NOT EXISTS idx_deletion_log_entity_record '
        'ON deletion_log (entity_type, record_id)';
    try {
      await customStatement(createIndex);
    } catch (_) {
      // The only expected cause is pre-existing duplicate (entity_type,
      // record_id) rows -- a DB written before the unique index existed
      // (parallel-branch collision, or logDeletion duplicates from before the
      // v114 upsert). Confirm duplicates are actually present before running
      // the dedupe DELETE; if there are none, the failure is something else
      // (corruption, disk full, locked) that must surface, not be swallowed.
      final hasDuplicates = await customSelect(
        'SELECT 1 FROM deletion_log GROUP BY entity_type, record_id '
        'HAVING COUNT(*) > 1 LIMIT 1',
      ).get();
      if (hasDuplicates.isEmpty) rethrow;
      await customStatement('''
        DELETE FROM deletion_log WHERE rowid NOT IN (
          SELECT rowid FROM (
            SELECT rowid, ROW_NUMBER() OVER (
              PARTITION BY entity_type, record_id
              ORDER BY deleted_at DESC, COALESCE(hlc, '') DESC, rowid DESC
            ) AS rn FROM deletion_log
          ) WHERE rn = 1
        )
      ''');
      await customStatement(createIndex);
    }
  }

  /// v112: equipment.thickness column. Idempotent so it is safe to call from
  /// both onUpgrade and the beforeOpen backstop.
  Future<void> _assertEquipmentThicknessColumn() async {
    final cols = await customSelect("PRAGMA table_info('equipment')").get();
    final hasThickness = cols.any((c) => c.read<String>('name') == 'thickness');
    if (cols.isNotEmpty && !hasThickness) {
      await customStatement('ALTER TABLE equipment ADD COLUMN thickness TEXT');
    }
  }

  /// v129: quality_findings table for the Data Quality Assistant.
  /// Idempotent so it is safe to call from both onUpgrade and the
  /// beforeOpen backstop.
  Future<void> _assertQualityFindingsSchema() async {
    await customStatement('''
      CREATE TABLE IF NOT EXISTS quality_findings (
        id TEXT NOT NULL PRIMARY KEY,
        dive_id TEXT NOT NULL REFERENCES dives (id) ON DELETE CASCADE,
        related_dive_id TEXT REFERENCES dives (id) ON DELETE SET NULL,
        computer_id TEXT REFERENCES dive_computers (id) ON DELETE SET NULL,
        detector_id TEXT NOT NULL,
        detector_version INTEGER NOT NULL,
        category TEXT NOT NULL,
        severity TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'open',
        params TEXT NOT NULL DEFAULT '{}',
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        hlc TEXT
      )
    ''');
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_quality_findings_dive '
      'ON quality_findings (dive_id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_quality_findings_status '
      'ON quality_findings (status)',
    );
  }

  /// v127: pre-dive checklist tables. Migrator.createTable is IF NOT EXISTS,
  /// so this is safe to call from both onUpgrade and the beforeOpen backstop
  /// (parallel-branch version-collision self-heal).
  Future<void> _assertPreDiveChecklistSchema() async {
    final m = createMigrator();
    await m.createTable(preDiveChecklistTemplates);
    await m.createTable(preDiveChecklistTemplateItems);
    await m.createTable(preDiveSessions);
    await m.createTable(preDiveSessionItems);
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_pre_dive_template_items_template_id '
      'ON pre_dive_checklist_template_items(template_id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_pre_dive_sessions_dive_id '
      'ON pre_dive_sessions(dive_id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_pre_dive_session_items_session_id '
      'ON pre_dive_session_items(session_id)',
    );
  }

  /// Seeds the built-in pre-dive templates and their items, but only when the
  /// FK parent `divers` table exists. pre_dive_checklist_templates.diver_id
  /// references divers, so with foreign_keys=ON the seed cannot even prepare
  /// when that table is absent. Minimal migration-test fixtures upgrade an old
  /// schema without the full table set and legitimately lack it -- skipping
  /// the seed there is correct (the tables are still created). Real databases
  /// always have divers, so they always seed. Mirrors the guarded dive_types
  /// re-seed in beforeOpen.
  Future<void> _seedBuiltInPreDiveTemplates() async {
    final diversTable = await customSelect(
      "SELECT name FROM sqlite_master WHERE type='table' AND name='divers'",
    ).get();
    if (diversTable.isEmpty) return;
    await customStatement(kSeedBuiltInPreDiveTemplatesSql);
    await customStatement(kSeedBuiltInPreDiveTemplateItemsSql);
  }

  /// v120: planner Subsurface-parity columns - plan start time, per-segment
  /// setpoint + dive-mode override, and per-tank deco-switch depth. Idempotent
  /// (each ALTER is PRAGMA-guarded) so it is safe from both onUpgrade and the
  /// beforeOpen backstop (shared sandbox DB heals across parallel branches).
  Future<void> _assertPlannerParitySchema() async {
    Future<void> add(String table, String column, String type) async {
      final cols = await customSelect("PRAGMA table_info('$table')").get();
      if (cols.isEmpty) return;
      final has = cols.any((c) => c.read<String>('name') == column);
      if (!has) {
        await customStatement('ALTER TABLE $table ADD COLUMN $column $type');
      }
    }

    await add('dive_plans', 'start_date_time', 'INTEGER');
    await add('dive_plan_segments', 'setpoint_bar', 'REAL');
    await add('dive_plan_segments', 'dive_mode_override', 'TEXT');
    await add('dive_plan_tanks', 'deco_switch_depth', 'REAL');
  }

  /// v113: diver_settings.cns_calculation_method column. Self-guarding when
  /// the diver_settings table is absent (partial-schema migration tests), so
  /// it is safe to call from both onUpgrade and the beforeOpen backstop.
  Future<void> _assertCnsCalculationMethodColumn() async {
    final cols = await customSelect(
      "PRAGMA table_info('diver_settings')",
    ).get();
    final hasColumn = cols.any(
      (c) => c.read<String>('name') == 'cns_calculation_method',
    );
    if (cols.isNotEmpty && !hasColumn) {
      await customStatement(
        "ALTER TABLE diver_settings ADD COLUMN cns_calculation_method "
        "TEXT NOT NULL DEFAULT 'shearwater'",
      );
    }
  }

  /// v123: safety review tables, index, and settings columns. Idempotent
  /// (createTable is IF NOT EXISTS; the ALTERs are PRAGMA-guarded) so it is
  /// safe to call from both onUpgrade and the beforeOpen backstop.
  Future<void> _assertSafetyReviewSchema() async {
    final m = createMigrator();
    await m.createTable(diveSafetyReviews);
    await m.createTable(diveSafetyFindings);
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_dive_safety_findings_dive_id '
      'ON dive_safety_findings (dive_id)',
    );
    final cols = await customSelect(
      "PRAGMA table_info('diver_settings')",
    ).get();
    final names = cols.map((c) => c.read<String>('name')).toSet();
    if (cols.isNotEmpty && !names.contains('safety_review_enabled')) {
      await customStatement(
        'ALTER TABLE diver_settings ADD COLUMN safety_review_enabled '
        'INTEGER NOT NULL DEFAULT 1 CHECK (safety_review_enabled IN (0, 1))',
      );
    }
    if (cols.isNotEmpty && !names.contains('safety_review_disabled_rules')) {
      await customStatement(
        'ALTER TABLE diver_settings ADD COLUMN safety_review_disabled_rules '
        'TEXT',
      );
    }
  }

  /// v125: diver_settings.no_fly_preset column. Idempotent so it is safe to
  /// call from both onUpgrade and the beforeOpen backstop.
  Future<void> _assertNoFlySettingsColumn() async {
    final cols = await customSelect(
      "PRAGMA table_info('diver_settings')",
    ).get();
    final names = cols.map((c) => c.read<String>('name')).toSet();
    if (cols.isNotEmpty && !names.contains('no_fly_preset')) {
      await customStatement(
        "ALTER TABLE diver_settings ADD COLUMN no_fly_preset TEXT "
        "NOT NULL DEFAULT 'standard'",
      );
    }
  }

  /// v126: emergency_chambers table + emergency card settings columns.
  /// Idempotent so it is safe to call from both onUpgrade and the
  /// beforeOpen backstop.
  Future<void> _assertEmergencyCardSchema() async {
    await createMigrator().createTable(emergencyChambers);
    final cols = await customSelect(
      "PRAGMA table_info('diver_settings')",
    ).get();
    final names = cols.map((c) => c.read<String>('name')).toSet();
    if (cols.isNotEmpty && !names.contains('hidden_chamber_ids')) {
      await customStatement(
        'ALTER TABLE diver_settings ADD COLUMN hidden_chamber_ids TEXT',
      );
    }
    if (cols.isNotEmpty && !names.contains('emergency_region')) {
      await customStatement(
        'ALTER TABLE diver_settings ADD COLUMN emergency_region TEXT',
      );
    }
  }

  /// v127: incidents table (near-miss log). Idempotent for onUpgrade +
  /// beforeOpen backstop use.
  Future<void> _assertIncidentsSchema() async {
    await createMigrator().createTable(incidents);
  }

  /// v133: diver_settings deco stop band columns. PRAGMA-guarded and
  /// idempotent so it is safe to call from both onUpgrade and the beforeOpen
  /// backstop. The guard on cols.isNotEmpty keeps partial-schema migration
  /// tests, which open databases without this table, from crashing on DDL.
  Future<void> _assertDecoStopSettingsColumns() async {
    final cols = await customSelect(
      "PRAGMA table_info('diver_settings')",
    ).get();
    final names = cols.map((c) => c.read<String>('name')).toSet();
    if (cols.isNotEmpty && !names.contains('show_deco_stops_on_profile')) {
      await customStatement(
        'ALTER TABLE diver_settings ADD COLUMN show_deco_stops_on_profile '
        'INTEGER NOT NULL DEFAULT 1 '
        'CHECK (show_deco_stops_on_profile IN (0, 1))',
      );
    }
    if (cols.isNotEmpty && !names.contains('default_deco_stop_source')) {
      await customStatement(
        'ALTER TABLE diver_settings ADD COLUMN default_deco_stop_source '
        'INTEGER NOT NULL DEFAULT 1',
      );
    }
  }

  /// v111: equipment_sets.is_default column + equipment_set_geofences table.
  /// Idempotent (createTable is IF NOT EXISTS; the ALTER is PRAGMA-guarded) so
  /// it is safe to call from both onUpgrade and the beforeOpen backstop.
  Future<void> _assertEquipmentSetDefaultAndGeofenceSchema() async {
    await createMigrator().createTable(equipmentSetGeofences);
    final cols = await customSelect(
      "PRAGMA table_info('equipment_sets')",
    ).get();
    final hasIsDefault = cols.any(
      (c) => c.read<String>('name') == 'is_default',
    );
    if (cols.isNotEmpty && !hasIsDefault) {
      await customStatement(
        'ALTER TABLE equipment_sets ADD COLUMN is_default '
        'INTEGER NOT NULL DEFAULT 0 CHECK (is_default IN (0, 1))',
      );
    }
  }

  /// v122: service ledger -- service_kinds + service_schedules tables,
  /// service_records.service_kind_id, scheduled_notifications.schedule_id,
  /// diver_settings.trip_service_lead_days, built-in kind seed, and the
  /// legacy single-clock backfill. Idempotent; called from onUpgrade AND
  /// the beforeOpen backstop (parallel-branch collision self-heal).
  Future<void> _assertServiceLedgerSchema() async {
    await createMigrator().createTable(serviceKinds);
    await createMigrator().createTable(serviceSchedules);

    final srCols = await customSelect(
      "PRAGMA table_info('service_records')",
    ).get();
    if (srCols.isNotEmpty &&
        !srCols.any((c) => c.read<String>('name') == 'service_kind_id')) {
      await customStatement(
        'ALTER TABLE service_records ADD COLUMN service_kind_id TEXT',
      );
    }

    final snCols = await customSelect(
      "PRAGMA table_info('scheduled_notifications')",
    ).get();
    if (snCols.isNotEmpty &&
        !snCols.any((c) => c.read<String>('name') == 'schedule_id')) {
      await customStatement(
        'ALTER TABLE scheduled_notifications ADD COLUMN schedule_id TEXT',
      );
    }

    final dsCols = await customSelect(
      "PRAGMA table_info('diver_settings')",
    ).get();
    if (dsCols.isNotEmpty &&
        !dsCols.any(
          (c) => c.read<String>('name') == 'trip_service_lead_days',
        )) {
      await customStatement(
        'ALTER TABLE diver_settings ADD COLUMN trip_service_lead_days '
        'INTEGER NOT NULL DEFAULT 14',
      );
    }

    // Indexes: onCreate's createAll() never builds raw-SQL indexes, so they
    // must be asserted here to exist on fresh installs too. The
    // service_records index is guarded on the table existing so this helper
    // stays self-guarding for partial fixture databases (old-migration
    // tests) where service_records is absent.
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_service_schedules_equipment '
      'ON service_schedules(equipment_id)',
    );
    if (srCols.isNotEmpty) {
      await customStatement(
        'CREATE INDEX IF NOT EXISTS idx_service_records_kind '
        'ON service_records(equipment_id, service_kind_id)',
      );
    }

    // Seed built-ins only when the divers FK parent exists (self-guard for
    // partial fixture databases; real databases always have divers).
    final diversTable = await customSelect(
      "SELECT name FROM sqlite_master WHERE type='table' AND name='divers'",
    ).get();
    if (diversTable.isNotEmpty) {
      await customStatement(kSeedBuiltInServiceKindsSql);
    }
  }

  /// v122 one-time data copy: items with a legacy single-clock interval get
  /// one "General service" schedule. Invoked from the v122 onUpgrade block
  /// only, NEVER the beforeOpen backstop -- re-running on every open would
  /// resurrect a schedule the user deleted (mirrors the v109 buddy-cert
  /// rule). The deterministic id ('legacy-svc-' || equipment id) plus
  /// INSERT OR IGNORE makes independent per-device migrations converge to
  /// one row under sync instead of duplicating.
  Future<void> _backfillLegacyServiceSchedules() async {
    // Self-guard for partial fixture databases: skip unless the equipment
    // table exists WITH the legacy columns the copy reads.
    final eqCols = await customSelect("PRAGMA table_info('equipment')").get();
    final names = eqCols.map((c) => c.read<String>('name')).toSet();
    if (!names.containsAll({'service_interval_days', 'last_service_date'})) {
      return;
    }
    await customStatement('''
      INSERT OR IGNORE INTO service_schedules
        (id, equipment_id, service_kind_id, interval_days, anchor_date,
         enabled, created_at, updated_at)
      SELECT 'legacy-svc-' || e.id, e.id, 'general-service',
             e.service_interval_days, e.last_service_date, 1,
             n.now_ms, n.now_ms
      FROM equipment e
      CROSS JOIN (
        SELECT CAST(strftime('%s','now') AS INTEGER) * 1000 AS now_ms
      ) n
      WHERE e.service_interval_days IS NOT NULL
    ''');
  }

  /// v131 one-time reconciliation: items whose legacy interval was set via the
  /// edit form AFTER the v122 backfill ran have an interval column but no
  /// clock. Create the same deterministic `legacy-svc-<id>` "General service"
  /// clock for them so removing the legacy edit field does not drop their due
  /// signal. Guarded by the deletion log so a clock the user deleted is never
  /// resurrected. onUpgrade only, never beforeOpen (re-running would resurrect
  /// a user-deleted clock; mirrors [_backfillLegacyServiceSchedules]).
  Future<void> _reconcileLegacyServiceSchedules() async {
    // Self-guard for partial fixture databases (old-migration tests): skip
    // unless every table the copy reads exists. Real databases always have
    // deletion_log; a minimal fixture that omits it must not crash the copy.
    final tables = await customSelect(
      "SELECT name FROM sqlite_master WHERE type='table'",
    ).get();
    final tableNames = tables.map((t) => t.read<String>('name')).toSet();
    if (!tableNames.containsAll({
      'equipment',
      'service_schedules',
      'deletion_log',
    })) {
      return;
    }
    final eqCols = await customSelect("PRAGMA table_info('equipment')").get();
    final names = eqCols.map((c) => c.read<String>('name')).toSet();
    if (!names.containsAll({'service_interval_days', 'last_service_date'})) {
      return;
    }
    await customStatement('''
      INSERT OR IGNORE INTO service_schedules
        (id, equipment_id, service_kind_id, interval_days, anchor_date,
         enabled, created_at, updated_at)
      SELECT 'legacy-svc-' || e.id, e.id, 'general-service',
             e.service_interval_days, e.last_service_date, 1,
             n.now_ms, n.now_ms
      FROM equipment e
      CROSS JOIN (
        SELECT CAST(strftime('%s','now') AS INTEGER) * 1000 AS now_ms
      ) n
      WHERE e.service_interval_days IS NOT NULL
        AND NOT EXISTS (
          SELECT 1 FROM service_schedules s WHERE s.id = 'legacy-svc-' || e.id
        )
        AND NOT EXISTS (
          SELECT 1 FROM deletion_log d
          WHERE d.entity_type = 'serviceSchedules'
            AND d.record_id = 'legacy-svc-' || e.id
        )
    ''');
  }

  /// Test-only hook exercising the v131 reconciliation directly.
  Future<void> reconcileLegacyServiceSchedulesForTest() =>
      _reconcileLegacyServiceSchedules();

  /// Data self-heal: synthesize a primary [DiveDataSources] row for any dive
  /// that has profile samples but no data-source row. Older file imports (and
  /// any import path predating dive_data_sources) wrote dive_profiles without
  /// the metadata row, which stranded the grouped-by-source view that the 3D
  /// scene, spatial map, and computer-compare all read -- they spun forever on
  /// a null scene. The 2D chart survived because it reads dive.profile directly.
  ///
  /// Runs on every open; a cheap no-op once healed (the NOT EXISTS guard leaves
  /// nothing to insert). Local-only by design: the id is deterministic
  /// (`legacy-src-<diveId>`), so every device heals to the identical row
  /// without syncing, and a device on an older build simply heals itself after
  /// upgrade. It never touches the parent dive's HLC, so it does not trigger a
  /// fleet re-sync of the healed dives. imported_at/created_at are Drift
  /// dateTime() columns stored as unix SECONDS (unlike the dives table's plain
  /// millisecond int columns), hence strftime('%s') without the *1000.
  Future<void> _backfillMissingDataSources() async {
    // Self-guard for partial/legacy schemas (migration tests and databases
    // caught mid-upgrade): skip unless all three tables exist. beforeOpen runs
    // for every open, including old-version fixtures where these tables may not
    // exist yet.
    final tables = await customSelect(
      "SELECT name FROM sqlite_master WHERE type='table' "
      "AND name IN ('dives', 'dive_profiles', 'dive_data_sources')",
    ).get();
    final present = tables.map((r) => r.read<String>('name')).toSet();
    if (!present.containsAll({'dives', 'dive_profiles', 'dive_data_sources'})) {
      return;
    }
    await customStatement('''
      INSERT OR IGNORE INTO dive_data_sources
        (id, dive_id, is_primary, imported_at, created_at)
      SELECT '$kLegacyDataSourceIdPrefix' || d.id, d.id, 1, n.now_s, n.now_s
      FROM dives d
      CROSS JOIN (
        SELECT CAST(strftime('%s','now') AS INTEGER) AS now_s
      ) n
      WHERE EXISTS (
        SELECT 1 FROM dive_profiles p
        WHERE p.dive_id = d.id AND p.is_primary = 1
      )
      AND NOT EXISTS (
        SELECT 1 FROM dive_data_sources s WHERE s.dive_id = d.id
      )
    ''');
  }

  /// Copy each buddy's inline certification into a certifications row owned by
  /// that buddy (issue #553). Invoked from the onUpgrade blocks only (v109
  /// expand + the v110 contract safety-net), NEVER the beforeOpen backstop --
  /// the inline columns survive until v110, and re-running the copy on every
  /// open would resurrect a user-deleted buddy cert. The id is deterministic
  /// (`buddycert-<buddyId>`) and the insert upserts, so independent per-device
  /// migrations converge to one row under sync instead of duplicating.
  Future<void> _migrateBuddyInlineCertifications() async {
    final buddyCols = await customSelect("PRAGMA table_info('buddies')").get();
    final names = buddyCols.map((c) => c.read<String>('name')).toSet();
    if (!names.contains('certification_level') &&
        !names.contains('certification_agency')) {
      return;
    }
    final rows = await customSelect(
      'SELECT id, certification_level, certification_agency FROM buddies '
      'WHERE certification_level IS NOT NULL '
      'OR certification_agency IS NOT NULL',
    ).get();
    for (final r in rows) {
      final buddyId = r.read<String>('id');
      final level = r.read<String?>('certification_level');
      final agency = r.read<String?>('certification_agency') ?? 'other';
      final certId = 'buddycert-$buddyId';
      final name = _displayNameForMigratedCert(level, agency);
      final now = DateTime.now().millisecondsSinceEpoch;
      await customStatement(
        'INSERT INTO certifications '
        '(id, buddy_id, diver_id, name, agency, level, notes, '
        'created_at, updated_at) '
        "VALUES (?, ?, NULL, ?, ?, ?, '', ?, ?) "
        'ON CONFLICT(id) DO UPDATE SET buddy_id = excluded.buddy_id',
        [certId, buddyId, name, agency, level, now, now],
      );
    }
  }

  /// Human-readable name for a migrated buddy cert: the level's display name
  /// when present, else the agency's.
  String _displayNameForMigratedCert(String? level, String agency) {
    if (level != null) {
      return CertificationLevel.values
          .firstWhere(
            (e) => e.name == level,
            orElse: () => CertificationLevel.other,
          )
          .displayName;
    }
    return CertificationAgency.values
        .firstWhere(
          (e) => e.name == agency,
          orElse: () => CertificationAgency.other,
        )
        .displayName;
  }

  /// v130: media_enrichment.hlc column. Self-guarding when the table is absent
  /// (partial-schema migration fixtures) and PRAGMA-guarded so it is safe to
  /// call from both onUpgrade and the beforeOpen backstop (parallel-branch
  /// collision self-heal).
  Future<void> _assertMediaEnrichmentHlcColumn() async {
    final cols = await customSelect(
      "PRAGMA table_info('media_enrichment')",
    ).get();
    final hasColumn = cols.any((c) => c.read<String>('name') == 'hlc');
    if (cols.isNotEmpty && !hasColumn) {
      await customStatement('ALTER TABLE media_enrichment ADD COLUMN hlc TEXT');
    }
  }

  /// Idempotent DDL for the v103 media store objects. Called from the v103
  /// onUpgrade block and from the beforeOpen backstop so a parallel-branch
  /// schema-version collision cannot strand a database without them.
  Future<void> _assertMediaStoreSchema() async {
    // An empty PRAGMA result means the media table itself is absent (only
    // possible in minimal test fixtures); skip the ALTERs rather than fail.
    final cols = await customSelect("PRAGMA table_info('media')").get();
    if (cols.isNotEmpty) {
      final names = cols.map((c) => c.read<String>('name')).toSet();
      Future<void> add(String name, String type) async {
        if (!names.contains(name)) {
          await customStatement('ALTER TABLE media ADD COLUMN $name $type');
        }
      }

      await add('content_hash', 'TEXT');
      await add('content_size_bytes', 'INTEGER');
      await add('remote_uploaded_at', 'INTEGER');
      await add('remote_thumb_uploaded_at', 'INTEGER');
    }
    await customStatement('''
      CREATE TABLE IF NOT EXISTS media_stores (
        id TEXT NOT NULL PRIMARY KEY,
        provider_type TEXT NOT NULL,
        display_hint TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        hlc TEXT
      )
    ''');
  }

  /// Idempotent DDL for the v133 compressed-rendition columns. Called from the
  /// v133 onUpgrade step and the beforeOpen backstop, matching the
  /// _assertMediaStoreSchema pattern so a schema-version collision cannot
  /// strand a database without them.
  Future<void> _assertMediaCompressedRenditionColumns() async {
    final cols = await customSelect("PRAGMA table_info('media')").get();
    if (cols.isEmpty) return;
    final names = cols.map((c) => c.read<String>('name')).toSet();
    Future<void> add(String name, String type) async {
      if (!names.contains(name)) {
        await customStatement('ALTER TABLE media ADD COLUMN $name $type');
      }
    }

    await add('compressed_level', 'TEXT');
    await add('compressed_size_bytes', 'INTEGER');
    await add('remote_compressed_uploaded_at', 'INTEGER');
  }

  /// Tables that carry a per-row Hybrid Logical Clock for cross-device conflict
  /// resolution (plus sync_metadata for the device clock). Shared between the
  /// v77 backfill (original add), the v82 backfill (recovery for databases that
  /// landed at user_version = 77 via the schema-version collision with PR #302's
  /// surface-interval index migration) and the v83 backfill (comprehensive
  /// recovery for databases stranded past v77 by the wider set of sync-branch
  /// version collisions — see the v82 and v83 blocks below).
  static const List<String> _hlcTables = [
    'divers',
    'diver_settings',
    'buddies',
    'buddy_roles',
    'dive_centers',
    'trips',
    'liveaboard_detail_records',
    'trip_itinerary_days',
    'equipment',
    'equipment_sets',
    'equipment_attributes',
    'dive_types',
    'dive_roles',
    'tank_presets',
    'dive_computers',
    'tags',
    'courses',
    'dives',
    'dive_sites',
    'diver_weight_entries',
    'certifications',
    'service_records',
    'settings',
    'csv_presets',
    'view_configs',
    'sync_metadata',
    'media',
    'species',
    'field_presets',
    'quality_findings',
  ];

  /// Returns the number of migration steps that will execute when upgrading
  /// from [fromVersion] to [currentSchemaVersion].
  static int migrationStepCount(int fromVersion) {
    return migrationVersions.where((v) => v > fromVersion).length;
  }

  @override
  int get schemaVersion => currentSchemaVersion;

  /// Test hook: run the v102 stranded-pressure repair on demand so tests can
  /// assert it is idempotent (a second run over already-healed data is a
  /// no-op). Not used in production; the migration invokes the private method.
  Future<void> relinkStrandedTankPressuresForTest() =>
      _relinkStrandedTankPressures();

  /// Re-link tank pressure series stranded under a stale tank id (issue #510).
  ///
  /// A reparse, re-import, or multi-computer consolidation can regenerate a
  /// dive's tanks with fresh UUIDs while its `tank_pressure_profiles` rows keep
  /// the old tank id. The per-cylinder SAC calculation looked those up by exact
  /// tank id and missed them, so SAC by cylinder went blank even though the
  /// pressure data was present (the runtime fix now tolerates this at read
  /// time; this migration heals the stored data once so the exact-id path works
  /// for every future consumer too).
  ///
  /// Mirrors the runtime resolver (`GasAnalysisService`): exact id matches are
  /// left alone; each orphaned series (keyed to an id that is no longer one of
  /// the dive's tanks) is adopted by a still-unmatched current tank, in tank
  /// order. Every reassignment targets a current tank of the same dive, so it
  /// is foreign-key safe. Idempotent: a second run finds no orphans.
  Future<void> _relinkStrandedTankPressures() async {
    // Defensive: both tables predate v102 in any real database, but migration
    // tests (and any partial DB) may reach this block without them. A missing
    // table would make the query below throw and abort the whole upgrade.
    Future<bool> tableExists(String name) async {
      final rows = await customSelect(
        "SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = ?",
        variables: [Variable<String>(name)],
      ).get();
      return rows.isNotEmpty;
    }

    if (!await tableExists('dive_tanks') ||
        !await tableExists('tank_pressure_profiles')) {
      return;
    }

    // Current tanks per dive (id + order for deterministic assignment).
    final tankRows = await customSelect(
      'SELECT dive_id, id, tank_order FROM dive_tanks',
    ).get();
    final tanksByDive = <String, List<({String id, int order})>>{};
    for (final r in tankRows) {
      (tanksByDive[r.read<String>('dive_id')] ??= []).add((
        id: r.read<String>('id'),
        order: r.read<int>('tank_order'),
      ));
    }
    if (tanksByDive.isEmpty) return;

    // One entry per (dive, pressure tank id), with the earliest sample time so
    // orphans are ordered the same way the runtime resolver iterates them.
    final pressureKeyRows = await customSelect(
      'SELECT dive_id, tank_id, MIN(timestamp) AS first_ts '
      'FROM tank_pressure_profiles GROUP BY dive_id, tank_id',
    ).get();
    final pressureKeysByDive = <String, List<({String tankId, int firstTs})>>{};
    for (final r in pressureKeyRows) {
      (pressureKeysByDive[r.read<String>('dive_id')] ??= []).add((
        tankId: r.read<String>('tank_id'),
        firstTs: r.read<int>('first_ts'),
      ));
    }

    for (final entry in pressureKeysByDive.entries) {
      final diveId = entry.key;
      final tanks = tanksByDive[diveId];
      if (tanks == null || tanks.isEmpty) continue;

      final currentIds = {for (final t in tanks) t.id};
      final matchedIds = {
        for (final k in entry.value)
          if (currentIds.contains(k.tankId)) k.tankId,
      };

      final orphans =
          [
            for (final k in entry.value)
              if (!currentIds.contains(k.tankId)) k,
          ]..sort((a, b) {
            final byTime = a.firstTs.compareTo(b.firstTs);
            return byTime != 0 ? byTime : a.tankId.compareTo(b.tankId);
          });
      if (orphans.isEmpty) continue;

      final unmatchedTanks =
          [
            for (final t in tanks)
              if (!matchedIds.contains(t.id)) t,
          ]..sort((a, b) {
            // id tie-break so tanks sharing the default order (0) pair
            // deterministically -- Dart's sort is not stable.
            final byOrder = a.order.compareTo(b.order);
            return byOrder != 0 ? byOrder : a.id.compareTo(b.id);
          });
      if (unmatchedTanks.isEmpty) continue;

      final count = orphans.length < unmatchedTanks.length
          ? orphans.length
          : unmatchedTanks.length;
      for (var i = 0; i < count; i++) {
        await customStatement(
          'UPDATE tank_pressure_profiles SET tank_id = ? '
          'WHERE dive_id = ? AND tank_id = ?',
          [unmatchedTanks[i].id, diveId, orphans[i].tankId],
        );
      }
    }
  }

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();

        // Seed built-in dive types (the same set the v93 migration backfills
        // for databases created before this seed existed).
        await customStatement(kSeedBuiltInDiveTypesSql);

        // Seed built-in dive roles (the v103 migration backfills these for
        // upgraded databases).
        await customStatement(kSeedBuiltInDiveRolesSql);

        // Seed built-in pre-dive checklist templates (the v127 migration
        // backfills these for upgraded databases).
        await _seedBuiltInPreDiveTemplates();

        // Seed built-in service kinds (the v122 migration backfills these
        // for upgraded databases; beforeOpen re-asserts).
        await customStatement(kSeedBuiltInServiceKindsSql);
      },
      onUpgrade: (Migrator m, int from, int to) async {
        int completedSteps = 0;
        final totalSteps = migrationStepCount(from);

        Future<void> reportProgress() async {
          completedSteps++;
          onMigrationProgress?.call(completedSteps, totalSteps);
          // Yield to the event loop so the UI can repaint (update the progress
          // bar). With synchronous NativeDatabase, DDL blocks the main thread
          // during each step, but this yield between steps gives the framework
          // a chance to schedule a frame after setState.
          await Future<void>.delayed(Duration.zero);
        }

        if (from < 2) {
          // Add sacUnit column to diver_settings
          await customStatement(
            "ALTER TABLE diver_settings ADD COLUMN sac_unit TEXT NOT NULL DEFAULT 'litersPerMin'",
          );
        }
        if (from < 2) await reportProgress();
        if (from < 3) {
          // Add presetName column to dive_tanks
          await customStatement(
            'ALTER TABLE dive_tanks ADD COLUMN preset_name TEXT',
          );
        }
        if (from < 3) await reportProgress();
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
        if (from < 4) await reportProgress();
        if (from < 5) {
          // Add showMapBackgroundOnDiveCards column to diver_settings
          await customStatement(
            'ALTER TABLE diver_settings ADD COLUMN show_map_background_on_dive_cards INTEGER NOT NULL DEFAULT 0',
          );
        }
        if (from < 5) await reportProgress();
        if (from < 6) {
          // Add showMapBackgroundOnSiteCards column to diver_settings
          await customStatement(
            'ALTER TABLE diver_settings ADD COLUMN show_map_background_on_site_cards INTEGER NOT NULL DEFAULT 0',
          );
        }
        if (from < 6) await reportProgress();
        if (from < 7) {
          // Add showDepthColoredDiveCards column to diver_settings (was missing migration)
          await customStatement(
            'ALTER TABLE diver_settings ADD COLUMN show_depth_colored_dive_cards INTEGER NOT NULL DEFAULT 0',
          );
        }
        if (from < 7) await reportProgress();
        if (from < 8) {
          // Add dive profile marker settings
          await customStatement(
            'ALTER TABLE diver_settings ADD COLUMN show_max_depth_marker INTEGER NOT NULL DEFAULT 1',
          );
          await customStatement(
            'ALTER TABLE diver_settings ADD COLUMN show_pressure_threshold_markers INTEGER NOT NULL DEFAULT 0',
          );
        }
        if (from < 8) await reportProgress();
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
        if (from < 9) await reportProgress();
        if (from < 10) {
          // Add time/date format columns to diver_settings
          await customStatement(
            "ALTER TABLE diver_settings ADD COLUMN time_format TEXT NOT NULL DEFAULT 'twelveHour'",
          );
          await customStatement(
            "ALTER TABLE diver_settings ADD COLUMN date_format TEXT NOT NULL DEFAULT 'mmmDYYYY'",
          );
        }
        if (from < 10) await reportProgress();
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
        if (from < 11) await reportProgress();
        if (from < 12) {
          // Add isPlanned column for dive planner feature
          await customStatement(
            'ALTER TABLE dives ADD COLUMN is_planned INTEGER NOT NULL DEFAULT 0',
          );
        }
        if (from < 12) await reportProgress();
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
        if (from < 13) await reportProgress();
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
        if (from < 14) await reportProgress();
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
        if (from < 15) await reportProgress();
        if (from < 16) {
          // Add altitude column to dive_sites for altitude diving support
          await customStatement(
            'ALTER TABLE dive_sites ADD COLUMN altitude REAL',
          );
        }
        if (from < 16) await reportProgress();
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
        if (from < 17) await reportProgress();
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
        if (from < 18) await reportProgress();
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
        if (from < 19) await reportProgress();
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
        if (from < 20) await reportProgress();
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
        if (from < 21) await reportProgress();
        if (from < 22) {
          // Buddy signatures feature - add signature type column
          await customStatement(
            'ALTER TABLE media ADD COLUMN signature_type TEXT',
          );
        }
        if (from < 22) await reportProgress();
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
        if (from < 23) await reportProgress();
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
        if (from < 24) await reportProgress();
        if (from < 25) {
          // Add altitudeUnit column to diver_settings
          await customStatement(
            "ALTER TABLE diver_settings ADD COLUMN altitude_unit TEXT NOT NULL DEFAULT 'meters'",
          );
        }
        if (from < 25) await reportProgress();
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
        if (from < 26) await reportProgress();
        if (from < 27) {
          // Per-equipment notification overrides
          await customStatement(
            'ALTER TABLE equipment ADD COLUMN custom_reminder_enabled INTEGER',
          );
          await customStatement(
            'ALTER TABLE equipment ADD COLUMN custom_reminder_days TEXT',
          );
        }
        if (from < 27) await reportProgress();
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
        if (from < 28) await reportProgress();
        if (from < 29) {
          // Add dive profile chart default visibility settings to diver_settings
          await customStatement(
            "ALTER TABLE diver_settings ADD COLUMN default_right_axis_metric TEXT NOT NULL DEFAULT 'temperature'",
          );
          await customStatement(
            'ALTER TABLE diver_settings ADD COLUMN default_show_temperature INTEGER NOT NULL DEFAULT 1',
          );
          await customStatement(
            'ALTER TABLE diver_settings ADD COLUMN default_show_pressure INTEGER NOT NULL DEFAULT 0',
          );
          await customStatement(
            'ALTER TABLE diver_settings ADD COLUMN default_show_heart_rate INTEGER NOT NULL DEFAULT 0',
          );
          await customStatement(
            'ALTER TABLE diver_settings ADD COLUMN default_show_sac INTEGER NOT NULL DEFAULT 0',
          );
          await customStatement(
            'ALTER TABLE diver_settings ADD COLUMN default_show_events INTEGER NOT NULL DEFAULT 1',
          );
          await customStatement(
            'ALTER TABLE diver_settings ADD COLUMN default_show_pp_o2 INTEGER NOT NULL DEFAULT 0',
          );
          await customStatement(
            'ALTER TABLE diver_settings ADD COLUMN default_show_pp_n2 INTEGER NOT NULL DEFAULT 0',
          );
          await customStatement(
            'ALTER TABLE diver_settings ADD COLUMN default_show_pp_he INTEGER NOT NULL DEFAULT 0',
          );
          await customStatement(
            'ALTER TABLE diver_settings ADD COLUMN default_show_gas_density INTEGER NOT NULL DEFAULT 0',
          );
          await customStatement(
            'ALTER TABLE diver_settings ADD COLUMN default_show_gf INTEGER NOT NULL DEFAULT 0',
          );
          await customStatement(
            'ALTER TABLE diver_settings ADD COLUMN default_show_surface_gf INTEGER NOT NULL DEFAULT 0',
          );
          await customStatement(
            'ALTER TABLE diver_settings ADD COLUMN default_show_mean_depth INTEGER NOT NULL DEFAULT 0',
          );
          await customStatement(
            'ALTER TABLE diver_settings ADD COLUMN default_show_tts INTEGER NOT NULL DEFAULT 0',
          );
          await customStatement(
            'ALTER TABLE diver_settings ADD COLUMN default_show_gas_switch_markers INTEGER NOT NULL DEFAULT 1',
          );
        }
        if (from < 29) await reportProgress();
        if (from < 30) {
          // Wearable integration (v2.0) - Apple Watch, Garmin, Suunto import
          // Add wearable source tracking to dives table
          await customStatement(
            'ALTER TABLE dives ADD COLUMN wearable_source TEXT',
          );
          await customStatement(
            'ALTER TABLE dives ADD COLUMN wearable_id TEXT',
          );
          // Add heart rate source tracking to dive_profiles table
          await customStatement(
            'ALTER TABLE dive_profiles ADD COLUMN heart_rate_source TEXT',
          );
        }
        if (from < 30) await reportProgress();
        if (from < 31) {
          // Performance indexes for 5000+ dives
          // Primary query: dives by diver, ordered by date
          await customStatement('''
            CREATE INDEX IF NOT EXISTS idx_dives_diver_datetime
            ON dives(diver_id, dive_date_time DESC)
          ''');
          await customStatement('''
            CREATE INDEX IF NOT EXISTS idx_dives_diver_entrytime
            ON dives(diver_id, entry_time DESC)
          ''');
          // FK lookups for batch loading in getAllDives()
          await customStatement('''
            CREATE INDEX IF NOT EXISTS idx_dives_site_id
            ON dives(site_id)
          ''');
          await customStatement('''
            CREATE INDEX IF NOT EXISTS idx_dives_trip_id
            ON dives(trip_id)
          ''');
          await customStatement('''
            CREATE INDEX IF NOT EXISTS idx_dives_dive_center_id
            ON dives(dive_center_id)
          ''');
          await customStatement('''
            CREATE INDEX IF NOT EXISTS idx_dives_course_id
            ON dives(course_id)
          ''');
          // Favorite filter
          await customStatement('''
            CREATE INDEX IF NOT EXISTS idx_dives_favorite
            ON dives(diver_id, is_favorite)
          ''');
          // Child table lookups for batch loading
          await customStatement('''
            CREATE INDEX IF NOT EXISTS idx_dive_tanks_dive_id
            ON dive_tanks(dive_id)
          ''');
          await customStatement('''
            CREATE INDEX IF NOT EXISTS idx_dive_equipment_dive_id
            ON dive_equipment(dive_id)
          ''');
          await customStatement('''
            CREATE INDEX IF NOT EXISTS idx_dive_weights_dive_id
            ON dive_weights(dive_id)
          ''');
          await customStatement('''
            CREATE INDEX IF NOT EXISTS idx_dive_tags_dive_id
            ON dive_tags(dive_id)
          ''');
          await customStatement('''
            CREATE INDEX IF NOT EXISTS idx_dive_tags_tag_id
            ON dive_tags(tag_id)
          ''');
          await customStatement('''
            CREATE INDEX IF NOT EXISTS idx_dive_buddies_dive_id
            ON dive_buddies(dive_id)
          ''');
        }
        if (from < 31) await reportProgress();
        if (from < 32) {
          // Add taxonomy class and built-in flag to species table
          await customStatement(
            'ALTER TABLE species ADD COLUMN taxonomy_class TEXT',
          );
          await customStatement(
            'ALTER TABLE species ADD COLUMN is_built_in INTEGER NOT NULL DEFAULT 0',
          );
        }
        if (from < 32) await reportProgress();
        if (from < 33) {
          // Add locale column for i18n language preference
          final cols = await customSelect(
            'PRAGMA table_info(diver_settings)',
          ).get();
          final hasLocale = cols.any(
            (row) => row.read<String>('name') == 'locale',
          );
          if (!hasLocale) {
            await customStatement(
              "ALTER TABLE diver_settings ADD COLUMN locale TEXT NOT NULL DEFAULT 'system'",
            );
          }
        }
        if (from < 33) await reportProgress();
        if (from < 34) {
          // User-defined key:value custom fields per dive
          await customStatement('''
            CREATE TABLE IF NOT EXISTS dive_custom_fields (
              id TEXT NOT NULL PRIMARY KEY,
              dive_id TEXT NOT NULL REFERENCES dives(id) ON DELETE CASCADE,
              field_key TEXT NOT NULL,
              field_value TEXT NOT NULL DEFAULT '',
              sort_order INTEGER NOT NULL DEFAULT 0,
              created_at INTEGER NOT NULL
            )
          ''');
          await customStatement('''
            CREATE INDEX IF NOT EXISTS idx_dive_custom_fields_dive_id
            ON dive_custom_fields(dive_id)
          ''');
          await customStatement('''
            CREATE INDEX IF NOT EXISTS idx_dive_custom_fields_key
            ON dive_custom_fields(field_key)
          ''');
        }
        if (from < 34) await reportProgress();
        if (from < 35) {
          // Card coloring: attribute selector + gradient settings
          await customStatement(
            "ALTER TABLE diver_settings ADD COLUMN card_color_attribute TEXT NOT NULL DEFAULT 'none'",
          );
          await customStatement(
            "ALTER TABLE diver_settings ADD COLUMN card_color_gradient_preset TEXT NOT NULL DEFAULT 'ocean'",
          );
          await customStatement(
            'ALTER TABLE diver_settings ADD COLUMN card_color_gradient_start INTEGER',
          );
          await customStatement(
            'ALTER TABLE diver_settings ADD COLUMN card_color_gradient_end INTEGER',
          );
          // Migrate existing depth coloring users
          await customStatement(
            "UPDATE diver_settings SET card_color_attribute = 'depth' WHERE show_depth_colored_dive_cards = 1",
          );
        }
        if (from < 35) await reportProgress();
        if (from < 36) {
          // Backfill water_temp from profile temperature data for dives
          // where water_temp is NULL but profile points have temperature.
          // Uses MIN(temperature) to match the import fallback logic.
          await customStatement('''
            UPDATE dives SET water_temp = (
              SELECT MIN(temperature) FROM dive_profiles
              WHERE dive_profiles.dive_id = dives.id
              AND dive_profiles.is_primary = 1
              AND dive_profiles.temperature IS NOT NULL
              AND dive_profiles.temperature >= -2
              AND dive_profiles.temperature <= 40
            ) WHERE water_temp IS NULL
          ''');
        }
        if (from < 36) await reportProgress();
        if (from < 37) {
          await customStatement(
            'ALTER TABLE dive_computers ADD COLUMN firmware_version TEXT',
          );
          await customStatement(
            'ALTER TABLE dives ADD COLUMN dive_computer_firmware TEXT',
          );
        }
        if (from < 37) await reportProgress();

        if (from < 38) {
          // Remove any existing duplicate media (same gallery photo linked
          // to same dive). Keep the oldest record (lowest created_at).
          await customStatement('''
            DELETE FROM media WHERE id IN (
              SELECT m.id FROM media m
              INNER JOIN (
                SELECT platform_asset_id, dive_id, MIN(created_at) as min_created
                FROM media
                WHERE platform_asset_id IS NOT NULL AND dive_id IS NOT NULL
                GROUP BY platform_asset_id, dive_id
                HAVING COUNT(*) > 1
              ) dupes ON m.platform_asset_id = dupes.platform_asset_id
                AND m.dive_id = dupes.dive_id
                AND m.created_at > dupes.min_created
            )
          ''');
          // Partial unique index: same gallery photo cannot be linked to
          // same dive twice. Only constrains rows where both columns are
          // non-null (signatures/orphans unaffected).
          await customStatement('''
            CREATE UNIQUE INDEX IF NOT EXISTS idx_media_asset_dive_unique
            ON media(platform_asset_id, dive_id)
            WHERE platform_asset_id IS NOT NULL AND dive_id IS NOT NULL
          ''');
        }
        if (from < 38) await reportProgress();
        if (from < 39) {
          // Backfill avg_depth from profile data for dives that have
          // profile points but no avg_depth recorded.
          await customStatement('''
            UPDATE dives SET avg_depth = (
              SELECT AVG(depth) FROM dive_profiles
              WHERE dive_profiles.dive_id = dives.id
              AND dive_profiles.is_primary = 1
              AND dive_profiles.depth IS NOT NULL
            )
            WHERE avg_depth IS NULL
            AND EXISTS (
              SELECT 1 FROM dive_profiles
              WHERE dive_profiles.dive_id = dives.id
              AND dive_profiles.is_primary = 1
              AND dive_profiles.depth IS NOT NULL
            )
          ''');
          // Add CNS/OTU default visibility columns to settings
          final tableInfo = await customSelect(
            "PRAGMA table_info('diver_settings')",
          ).get();
          final existingColumns = tableInfo
              .map((row) => row.data['name'] as String)
              .toSet();
          if (!existingColumns.contains('default_show_cns')) {
            await customStatement(
              'ALTER TABLE diver_settings ADD COLUMN default_show_cns INTEGER NOT NULL DEFAULT 0',
            );
          }
          if (!existingColumns.contains('default_show_otu')) {
            await customStatement(
              'ALTER TABLE diver_settings ADD COLUMN default_show_otu INTEGER NOT NULL DEFAULT 0',
            );
          }
        }
        if (from < 39) await reportProgress();
        if (from < 40) {
          // Add per-sample decompression data columns to dive_profiles
          await customStatement(
            'ALTER TABLE dive_profiles ADD COLUMN cns REAL',
          );
          await customStatement(
            'ALTER TABLE dive_profiles ADD COLUMN tts INTEGER',
          );
          await customStatement(
            'ALTER TABLE dive_profiles ADD COLUMN rbt INTEGER',
          );
          await customStatement(
            'ALTER TABLE dive_profiles ADD COLUMN deco_type INTEGER',
          );
          // Add deco model fields to dives
          await customStatement(
            'ALTER TABLE dives ADD COLUMN deco_algorithm TEXT',
          );
          await customStatement(
            'ALTER TABLE dives ADD COLUMN deco_conservatism INTEGER',
          );
        }
        if (from < 40) await reportProgress();
        if (from < 41) {
          await customStatement(
            'ALTER TABLE diver_settings ADD COLUMN use_dive_computer_cns_data INTEGER NOT NULL DEFAULT 0',
          );
        }
        if (from < 41) await reportProgress();
        if (from < 42) {
          // Add per-metric data source columns
          await customStatement(
            'ALTER TABLE diver_settings ADD COLUMN default_ndl_source INTEGER NOT NULL DEFAULT 1',
          );
          await customStatement(
            'ALTER TABLE diver_settings ADD COLUMN default_ceiling_source INTEGER NOT NULL DEFAULT 1',
          );
          await customStatement(
            'ALTER TABLE diver_settings ADD COLUMN default_tts_source INTEGER NOT NULL DEFAULT 1',
          );
          await customStatement(
            'ALTER TABLE diver_settings ADD COLUMN default_cns_source INTEGER NOT NULL DEFAULT 1',
          );
          // Migrate existing CNS toggle: if user had it enabled, set CNS source to computer (0)
          await customStatement(
            'UPDATE diver_settings SET default_cns_source = 0 WHERE use_dive_computer_cns_data = 1',
          );
        }
        if (from < 42) await reportProgress();
        if (from < 43) {
          await customStatement(
            "ALTER TABLE diver_settings ADD COLUMN theme_preset TEXT NOT NULL DEFAULT 'submersion'",
          );
        }
        if (from < 43) await reportProgress();
        if (from < 45) {
          // Migrations 44-45 add columns to diver_settings.
          // Guard with PRAGMA table_info to handle partial migrations
          // (ALTER TABLE ADD COLUMN cannot be rolled back in SQLite).
          final settingsInfo = await customSelect(
            'PRAGMA table_info(diver_settings)',
          ).get();
          final settingsCols = settingsInfo
              .map((r) => r.read<String>('name'))
              .toSet();
          if (!settingsCols.contains('o2_narcotic')) {
            await customStatement(
              'ALTER TABLE diver_settings ADD COLUMN o2_narcotic INTEGER NOT NULL DEFAULT 1',
            );
          }
          if (!settingsCols.contains('end_limit')) {
            await customStatement(
              'ALTER TABLE diver_settings ADD COLUMN end_limit REAL NOT NULL DEFAULT 30.0',
            );
          }
          if (!settingsCols.contains('tissue_color_scheme')) {
            await customStatement(
              "ALTER TABLE diver_settings ADD COLUMN tissue_color_scheme TEXT NOT NULL DEFAULT 'classic'",
            );
          }
          if (!settingsCols.contains('tissue_viz_mode')) {
            await customStatement(
              "ALTER TABLE diver_settings ADD COLUMN tissue_viz_mode TEXT NOT NULL DEFAULT 'heatMap'",
            );
          }
        }
        if (from < 45) await reportProgress();

        if (from < 46) {
          // Add trip type column to trips
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

          // Create liveaboard_detail_records table
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

          // Migrate existing resort trips (only non-liveaboard)
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
              COALESCE(liveaboard_name, 'Unknown Vessel'),
              created_at,
              updated_at
            FROM trips
            WHERE trip_type = 'liveaboard'
              AND id NOT IN (SELECT trip_id FROM liveaboard_detail_records)
          ''');
        }
        if (from < 46) await reportProgress();
        if (from < 47) {
          // Add lastDiveFingerprint column for incremental dive download
          final dcInfo = await customSelect(
            'PRAGMA table_info(dive_computers)',
          ).get();
          final dcCols = dcInfo.map((r) => r.read<String>('name')).toSet();
          if (!dcCols.contains('last_dive_fingerprint')) {
            await customStatement(
              'ALTER TABLE dive_computers ADD COLUMN last_dive_fingerprint TEXT',
            );
          }
        }
        if (from < 47) await reportProgress();
        if (from < 48) {
          // Add weather columns to dives table.
          // Guard with PRAGMA table_info to handle partial migrations
          // (ALTER TABLE ADD COLUMN cannot be rolled back in SQLite).
          final divesInfo = await customSelect(
            'PRAGMA table_info(dives)',
          ).get();
          final divesCols = divesInfo
              .map((r) => r.read<String>('name'))
              .toSet();
          if (!divesCols.contains('wind_speed')) {
            await customStatement(
              'ALTER TABLE dives ADD COLUMN wind_speed REAL',
            );
          }
          if (!divesCols.contains('wind_direction')) {
            await customStatement(
              'ALTER TABLE dives ADD COLUMN wind_direction TEXT',
            );
          }
          if (!divesCols.contains('cloud_cover')) {
            await customStatement(
              'ALTER TABLE dives ADD COLUMN cloud_cover TEXT',
            );
          }
          if (!divesCols.contains('precipitation')) {
            await customStatement(
              'ALTER TABLE dives ADD COLUMN precipitation TEXT',
            );
          }
          if (!divesCols.contains('humidity')) {
            await customStatement('ALTER TABLE dives ADD COLUMN humidity REAL');
          }
          if (!divesCols.contains('weather_description')) {
            await customStatement(
              'ALTER TABLE dives ADD COLUMN weather_description TEXT',
            );
          }
          if (!divesCols.contains('weather_source')) {
            await customStatement(
              'ALTER TABLE dives ADD COLUMN weather_source TEXT',
            );
          }
          if (!divesCols.contains('weather_fetched_at')) {
            await customStatement(
              'ALTER TABLE dives ADD COLUMN weather_fetched_at INTEGER',
            );
          }
        }
        if (from < 48) await reportProgress();
        if (from < 49) {
          // Add importVersion column.
          final divesInfo = await customSelect(
            'PRAGMA table_info(dives)',
          ).get();
          final divesCols = divesInfo
              .map((r) => r.read<String>('name'))
              .toSet();

          if (!divesCols.contains('import_version')) {
            await customStatement(
              'ALTER TABLE dives ADD COLUMN import_version INTEGER',
            );
          }

          // Migrate dive timestamps to wall-clock-as-UTC convention.
          // Computer-imported dives: already in correct format (the original
          // bug stored local wall-clock components as UTC, which matches the
          // target convention). Only mark them with importVersion = 1.
          await customStatement('''
            UPDATE dives SET import_version = 1
            WHERE dive_computer_model IS NOT NULL
               OR computer_id IS NOT NULL
          ''');

          // Wearable and manual dives: stored as true local epoch.
          // Both categories get the same shift so they are collapsed into one
          // UPDATE using `import_version IS NULL` (computer dives are already
          // set to 1 above).
          //
          // Convert local epoch to wall-clock-as-UTC:
          //   newEpoch = localEpoch + timeZoneOffsetMs
          //
          // UTC+8 example: local 8:42 = 0:42 UTC epoch.  +8 h = 8:42 UTC.
          // UTC-4 example: local 8:42 = 12:42 UTC epoch. -4 h = 8:42 UTC.
          final now = DateTime.now();
          final offsetMs = now.timeZoneOffset.inMilliseconds;

          await customStatement('''
            UPDATE dives
            SET dive_date_time = dive_date_time + $offsetMs,
                entry_time = CASE WHEN entry_time IS NOT NULL
                             THEN entry_time + $offsetMs ELSE NULL END,
                exit_time = CASE WHEN exit_time IS NOT NULL
                            THEN exit_time + $offsetMs ELSE NULL END,
                import_version = 1
            WHERE import_version IS NULL
          ''');
        }
        if (from < 49) await reportProgress();
        if (from < 50) {
          final settingsInfo = await customSelect(
            'PRAGMA table_info(diver_settings)',
          ).get();
          final settingsCols = settingsInfo
              .map((r) => r.read<String>('name'))
              .toSet();
          if (!settingsCols.contains('default_tank_preset')) {
            await customStatement(
              "ALTER TABLE diver_settings ADD COLUMN default_tank_preset TEXT DEFAULT 'al80'",
            );
          }
          if (!settingsCols.contains('apply_default_tank_to_imports')) {
            await customStatement(
              'ALTER TABLE diver_settings ADD COLUMN apply_default_tank_to_imports INTEGER NOT NULL DEFAULT 0',
            );
          }
        }
        if (from < 50) await reportProgress();
        if (from < 51) {
          await customStatement(
            "ALTER TABLE diver_settings ADD COLUMN dive_list_view_mode TEXT NOT NULL DEFAULT 'detailed'",
          );
        }
        if (from < 51) await reportProgress();
        if (from < 52) {
          await customStatement(
            "ALTER TABLE diver_settings ADD COLUMN site_list_view_mode TEXT NOT NULL DEFAULT 'detailed'",
          );
          await customStatement(
            "ALTER TABLE diver_settings ADD COLUMN trip_list_view_mode TEXT NOT NULL DEFAULT 'detailed'",
          );
          await customStatement(
            "ALTER TABLE diver_settings ADD COLUMN equipment_list_view_mode TEXT NOT NULL DEFAULT 'detailed'",
          );
          await customStatement(
            "ALTER TABLE diver_settings ADD COLUMN buddy_list_view_mode TEXT NOT NULL DEFAULT 'detailed'",
          );
          await customStatement(
            "ALTER TABLE diver_settings ADD COLUMN dive_center_list_view_mode TEXT NOT NULL DEFAULT 'detailed'",
          );
        }
        if (from < 52) await reportProgress();
        if (from < 53) {
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
        if (from < 53) await reportProgress();
        if (from < 54) {
          await customStatement(
            'ALTER TABLE dive_computer_data RENAME TO dive_data_sources',
          );
          await customStatement(
            'ALTER TABLE dive_data_sources ADD COLUMN source_file_name TEXT',
          );
          await customStatement(
            'ALTER TABLE dive_data_sources ADD COLUMN source_file_format TEXT',
          );
          await customStatement(
            'ALTER TABLE dives RENAME COLUMN wearable_source TO import_source',
          );
          await customStatement(
            'ALTER TABLE dives RENAME COLUMN wearable_id TO import_id',
          );
          await customStatement(
            'DROP INDEX IF EXISTS idx_dive_computer_data_dive_id',
          );
          await customStatement('''
            CREATE INDEX IF NOT EXISTS idx_dive_data_sources_dive_id
            ON dive_data_sources(dive_id)
          ''');
        }
        if (from < 54) await reportProgress();
        if (from < 55) {
          // Add data source badge visibility setting to diver_settings
          await customStatement(
            'ALTER TABLE diver_settings ADD COLUMN show_data_source_badges INTEGER NOT NULL DEFAULT 1',
          );
        }
        if (from < 55) await reportProgress();
        if (from < 56) {
          await m.database.customStatement(
            'ALTER TABLE dives RENAME COLUMN duration TO bottom_time',
          );
        }
        if (from < 56) await reportProgress();
        if (from < 57) {
          // Add dive detail section configuration column to diver_settings
          await customStatement(
            'ALTER TABLE diver_settings ADD COLUMN dive_detail_sections TEXT',
          );
        }
        if (from < 57) await reportProgress();
        if (from < 58) {
          // Add csv_presets table for user-saved CSV import presets
          await customStatement('''
            CREATE TABLE IF NOT EXISTS csv_presets (
              id TEXT NOT NULL PRIMARY KEY,
              name TEXT NOT NULL,
              preset_json TEXT NOT NULL,
              created_at INTEGER NOT NULL,
              updated_at INTEGER NOT NULL
            )
          ''');
          // Convert pressure columns from INTEGER to REAL in dive_tanks
          // to avoid rounding errors in PSI/bar conversions.
          // SQLite doesn't support ALTER COLUMN, so recreate the table.
          await customStatement('''
            CREATE TABLE dive_tanks_new (
              id TEXT NOT NULL PRIMARY KEY,
              dive_id TEXT NOT NULL REFERENCES dives(id) ON DELETE CASCADE,
              equipment_id TEXT REFERENCES equipment(id),
              volume REAL,
              working_pressure REAL,
              start_pressure REAL,
              end_pressure REAL,
              o2_percent REAL NOT NULL DEFAULT 21.0,
              he_percent REAL NOT NULL DEFAULT 0.0,
              tank_order INTEGER NOT NULL DEFAULT 0,
              tank_role TEXT NOT NULL DEFAULT 'backGas',
              tank_material TEXT,
              tank_name TEXT,
              preset_name TEXT
            )
          ''');
          await customStatement('''
            INSERT INTO dive_tanks_new
              (id, dive_id, equipment_id, volume,
               working_pressure, start_pressure, end_pressure,
               o2_percent, he_percent, tank_order, tank_role,
               tank_material, tank_name, preset_name)
            SELECT id, dive_id, equipment_id, volume,
                   CAST(working_pressure AS REAL),
                   CAST(start_pressure AS REAL),
                   CAST(end_pressure AS REAL),
                   o2_percent, he_percent, tank_order, tank_role,
                   tank_material, tank_name, preset_name
            FROM dive_tanks
          ''');
          await customStatement('DROP TABLE dive_tanks');
          await customStatement(
            'ALTER TABLE dive_tanks_new RENAME TO dive_tanks',
          );
          await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_dive_tanks_dive_id ON dive_tanks(dive_id)',
          );
          // Convert workingPressureBar from INTEGER to REAL in tank_presets
          await customStatement('''
            CREATE TABLE tank_presets_new (
              id TEXT NOT NULL PRIMARY KEY,
              diver_id TEXT REFERENCES divers(id),
              name TEXT NOT NULL,
              display_name TEXT NOT NULL,
              volume_liters REAL NOT NULL,
              working_pressure_bar REAL NOT NULL,
              material TEXT NOT NULL,
              description TEXT NOT NULL DEFAULT '',
              sort_order INTEGER NOT NULL DEFAULT 0,
              created_at INTEGER NOT NULL,
              updated_at INTEGER NOT NULL
            )
          ''');
          await customStatement('''
            INSERT INTO tank_presets_new
              (id, diver_id, name, display_name, volume_liters,
               working_pressure_bar, material, description,
               sort_order, created_at, updated_at)
            SELECT id, diver_id, name, display_name, volume_liters,
                   CAST(working_pressure_bar AS REAL),
                   material, description, sort_order, created_at, updated_at
            FROM tank_presets
          ''');
          await customStatement('DROP TABLE tank_presets');
          await customStatement(
            'ALTER TABLE tank_presets_new RENAME TO tank_presets',
          );
        }
        if (from < 58) await reportProgress();
        if (from < 59) {
          // Migrate legacy dive_profiles.pressure data into
          // tank_pressure_profiles in a single bulk INSERT.
          // For each dive that has pressure data in dive_profiles but NO
          // existing rows in tank_pressure_profiles, copy the pressure
          // points associated with the dive's first tank (by rowid).
          //
          // Performance: use EXCEPT on small dive_id sets instead of
          // per-row NOT EXISTS (which triggers full table scans on
          // large tables). Reuse dp.id instead of generating UUIDs.
          // Temp tables with PKs give SQLite indexed join paths.

          // Build an indexed lookup of first tank per dive (~500 rows).
          await customStatement('''
            CREATE TEMP TABLE _migration_first_tanks (
              dive_id TEXT PRIMARY KEY,
              tank_id TEXT NOT NULL
            )
          ''');
          await customStatement('''
            INSERT INTO _migration_first_tanks (dive_id, tank_id)
            SELECT dive_id, id
            FROM (
              SELECT dive_id, id,
                     ROW_NUMBER() OVER (PARTITION BY dive_id ORDER BY rowid) AS rn
              FROM dive_tanks
            )
            WHERE rn = 1
          ''');

          // Ensure index exists so NOT EXISTS can use it
          // (may be missing depending on migration history).
          await customStatement('''
            CREATE INDEX IF NOT EXISTS idx_tank_pressure_dive_tank
            ON tank_pressure_profiles(dive_id, tank_id, timestamp)
          ''');

          // Find dive_ids needing migration: have legacy pressure data
          // but no rows in tank_pressure_profiles yet. Uses set
          // difference on small distinct-dive_id sets (~hundreds) rather
          // than per-row NOT EXISTS on ~100k profile rows.
          final divesToMigrate = await customSelect('''
            SELECT DISTINCT dp.dive_id
            FROM dive_profiles dp
            WHERE dp.pressure IS NOT NULL AND dp.is_primary = 1
            EXCEPT
            SELECT DISTINCT dive_id FROM tank_pressure_profiles
          ''').get();

          if (divesToMigrate.isNotEmpty) {
            // Stash the dive_ids that need migration.
            await customStatement('''
              CREATE TEMP TABLE _migration_dive_ids (
                dive_id TEXT PRIMARY KEY
              )
            ''');
            for (final row in divesToMigrate) {
              await customStatement(
                "INSERT INTO _migration_dive_ids VALUES (?)",
                [row.read<String>('dive_id')],
              );
            }

            // Drop secondary index for faster bulk insert.
            await customStatement(
              'DROP INDEX IF EXISTS idx_tank_pressure_dive_tank',
            );
            final cacheResult = await customSelect('PRAGMA cache_size').get();
            final previousCacheSize = cacheResult.first.read<int>('cache_size');
            await customStatement('PRAGMA cache_size = -65536');
            await customStatement('''
              INSERT INTO tank_pressure_profiles (id, dive_id, tank_id, timestamp, pressure)
              SELECT
                dp.id,
                dp.dive_id,
                ft.tank_id,
                dp.timestamp,
                dp.pressure
              FROM dive_profiles dp
              JOIN _migration_first_tanks ft ON ft.dive_id = dp.dive_id
              JOIN _migration_dive_ids md ON md.dive_id = dp.dive_id
              WHERE dp.pressure IS NOT NULL
                AND dp.is_primary = 1
            ''');
            await customStatement('PRAGMA cache_size = $previousCacheSize');
            await customStatement('''
              CREATE INDEX IF NOT EXISTS idx_tank_pressure_dive_tank
              ON tank_pressure_profiles(dive_id, tank_id, timestamp)
            ''');
            await customStatement('DROP TABLE IF EXISTS _migration_dive_ids');
          }

          await customStatement('DROP TABLE IF EXISTS _migration_first_tanks');
        }
        if (from < 59) await reportProgress();

        if (from < 60) {
          await customStatement('''
            CREATE TABLE IF NOT EXISTS view_configs (
              id TEXT NOT NULL PRIMARY KEY,
              diver_id TEXT NOT NULL REFERENCES divers(id) ON DELETE CASCADE,
              view_mode TEXT NOT NULL,
              config_json TEXT NOT NULL,
              updated_at INTEGER NOT NULL
            )
          ''');
          await customStatement('''
            CREATE TABLE IF NOT EXISTS field_presets (
              id TEXT NOT NULL PRIMARY KEY,
              diver_id TEXT NOT NULL REFERENCES divers(id) ON DELETE CASCADE,
              view_mode TEXT NOT NULL,
              name TEXT NOT NULL,
              config_json TEXT NOT NULL,
              is_built_in INTEGER NOT NULL DEFAULT 0,
              created_at INTEGER NOT NULL
            )
          ''');
          await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_view_configs_diver ON view_configs(diver_id, view_mode)',
          );
          await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_field_presets_diver ON field_presets(diver_id, view_mode)',
          );
        }
        if (from < 60) await reportProgress();

        if (from < 61) {
          // Add showProfilePanelInTableView column to diver_settings.
          // Guard against table not existing in older migration test contexts.
          final columns = await customSelect(
            "PRAGMA table_info('diver_settings')",
          ).get();
          if (columns.isNotEmpty &&
              !columns.any(
                (c) =>
                    c.read<String>('name') ==
                    'show_profile_panel_in_table_view',
              )) {
            await customStatement('''
              ALTER TABLE diver_settings
              ADD COLUMN show_profile_panel_in_table_view INTEGER NOT NULL DEFAULT 1
            ''');
          }
        }
        if (from < 61) await reportProgress();

        if (from < 62) {
          await customStatement('''
            CREATE UNIQUE INDEX IF NOT EXISTS idx_view_configs_unique
            ON view_configs(diver_id, view_mode)
          ''');
        }
        if (from < 62) await reportProgress();

        if (from < 63) {
          // Add per-section details pane toggle columns to diver_settings.
          final columns = await customSelect(
            "PRAGMA table_info('diver_settings')",
          ).get();
          if (columns.isNotEmpty) {
            final existing = columns.map((c) => c.read<String>('name')).toSet();
            const newColumns = {
              'show_details_pane_dives': 0,
              'show_details_pane_sites': 0,
              'show_details_pane_buddies': 0,
              'show_details_pane_trips': 0,
              'show_details_pane_equipment': 0,
              'show_details_pane_dive_centers': 0,
              'show_details_pane_certifications': 0,
              'show_details_pane_courses': 0,
            };
            for (final entry in newColumns.entries) {
              if (!existing.contains(entry.key)) {
                await customStatement('''
                  ALTER TABLE diver_settings
                  ADD COLUMN ${entry.key} INTEGER NOT NULL DEFAULT ${entry.value}
                ''');
              }
            }
          }
        }
        if (from < 63) await reportProgress();

        if (from < 64) {
          // Delete orphaned records (diver_id = NULL) left by prior diver
          // deletions that nullified instead of cascade-deleting.
          // Delete dives first so child tables CASCADE automatically.
          // Guard: only run on tables that have a diver_id column (older
          // migration-test databases may not have it).
          for (final table in [
            'dives',
            'trips',
            'dive_sites',
            'equipment',
            'equipment_sets',
            'buddies',
            'certifications',
            'dive_centers',
            'tags',
            'dive_computers',
            'tank_presets',
          ]) {
            final cols = await customSelect(
              "PRAGMA table_info('$table')",
            ).get();
            if (cols.any((c) => c.read<String>('name') == 'diver_id')) {
              await customStatement(
                'DELETE FROM $table WHERE diver_id IS NULL',
              );
            }
          }

          // Custom dive types may be orphaned too, but built-in types
          // (is_built_in = 1) intentionally have null diver_id. Only
          // delete orphaned custom types.
          final diveTypeCols = await customSelect(
            "PRAGMA table_info('dive_types')",
          ).get();
          final hasDiverId = diveTypeCols.any(
            (c) => c.read<String>('name') == 'diver_id',
          );
          final hasBuiltIn = diveTypeCols.any(
            (c) => c.read<String>('name') == 'is_built_in',
          );
          if (hasDiverId && hasBuiltIn) {
            await customStatement(
              'DELETE FROM dive_types WHERE diver_id IS NULL AND is_built_in = 0',
            );
          }
        }
        if (from < 64) await reportProgress();

        if (from < 65) {
          // Flip legacy detailed-card stat2 default from bottomTime to runtime.
          // Preserves deliberate customizations (e.g. waterTemp) by only
          // rewriting rows that still carry the old default.
          final rows = await customSelect(
            "SELECT id, config_json FROM view_configs WHERE view_mode = 'detailed'",
          ).get();
          final now = DateTime.now().millisecondsSinceEpoch;
          for (final row in rows) {
            final configJson = row.read<String>('config_json');
            Map<String, dynamic> parsed;
            try {
              parsed = jsonDecode(configJson) as Map<String, dynamic>;
            } catch (_) {
              continue;
            }
            final slots = parsed['slots'];
            if (slots is! List) continue;
            var modified = false;
            for (final slot in slots) {
              if (slot is Map<String, dynamic> &&
                  slot['slotId'] == 'stat2' &&
                  slot['field'] == 'bottomTime') {
                slot['field'] = 'runtime';
                modified = true;
              }
            }
            if (!modified) continue;
            await customStatement(
              'UPDATE view_configs SET config_json = ?, updated_at = ? WHERE id = ?',
              [jsonEncode(parsed), now, row.read<String>('id')],
            );
          }
        }
        if (from < 65) await reportProgress();
        if (from < 66) {
          // Guard: dive_data_sources may not exist in older migration tests.
          final ddsColumns = await customSelect(
            "PRAGMA table_info('dive_data_sources')",
          ).get();
          if (ddsColumns.isNotEmpty) {
            final existing = ddsColumns
                .map((c) => c.read<String>('name'))
                .toSet();
            if (!existing.contains('raw_data')) {
              await customStatement(
                'ALTER TABLE dive_data_sources ADD COLUMN raw_data BLOB',
              );
            }
            if (!existing.contains('raw_fingerprint')) {
              await customStatement(
                'ALTER TABLE dive_data_sources ADD COLUMN raw_fingerprint BLOB',
              );
            }
            if (!existing.contains('descriptor_vendor')) {
              await customStatement(
                'ALTER TABLE dive_data_sources ADD COLUMN descriptor_vendor TEXT',
              );
            }
            if (!existing.contains('descriptor_product')) {
              await customStatement(
                'ALTER TABLE dive_data_sources ADD COLUMN descriptor_product TEXT',
              );
            }
            if (!existing.contains('descriptor_model')) {
              await customStatement(
                'ALTER TABLE dive_data_sources ADD COLUMN descriptor_model INTEGER',
              );
            }
            if (!existing.contains('libdivecomputer_version')) {
              await customStatement(
                'ALTER TABLE dive_data_sources ADD COLUMN libdivecomputer_version TEXT',
              );
            }
            if (!existing.contains('last_parsed_at')) {
              await customStatement(
                'ALTER TABLE dive_data_sources ADD COLUMN last_parsed_at INTEGER',
              );
            }

            // Rebuild the table to update the computer_id FK from the
            // original NO ACTION to ON DELETE SET NULL. SQLite cannot
            // alter constraints in place, so we create → copy → swap.
            await customStatement('PRAGMA foreign_keys = OFF');
            await customStatement('''
              CREATE TABLE dive_data_sources_new (
                id TEXT NOT NULL PRIMARY KEY,
                dive_id TEXT NOT NULL REFERENCES dives(id) ON DELETE CASCADE,
                computer_id TEXT REFERENCES dive_computers(id) ON DELETE SET NULL,
                is_primary INTEGER NOT NULL DEFAULT 0,
                computer_model TEXT,
                computer_serial TEXT,
                source_format TEXT,
                source_file_name TEXT,
                source_file_format TEXT,
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
                created_at INTEGER NOT NULL,
                raw_data BLOB,
                raw_fingerprint BLOB,
                descriptor_vendor TEXT,
                descriptor_product TEXT,
                descriptor_model INTEGER,
                libdivecomputer_version TEXT,
                last_parsed_at INTEGER
              )
            ''');
            await customStatement('''
              INSERT INTO dive_data_sources_new
              SELECT id, dive_id, computer_id, is_primary,
                     computer_model, computer_serial, source_format,
                     source_file_name, source_file_format,
                     max_depth, avg_depth, duration, water_temp,
                     entry_time, exit_time, max_ascent_rate, max_descent_rate,
                     surface_interval, cns, otu, deco_algorithm,
                     gradient_factor_low, gradient_factor_high,
                     imported_at, created_at,
                     raw_data, raw_fingerprint,
                     descriptor_vendor, descriptor_product, descriptor_model,
                     libdivecomputer_version, last_parsed_at
              FROM dive_data_sources
            ''');
            await customStatement('DROP TABLE dive_data_sources');
            await customStatement(
              'ALTER TABLE dive_data_sources_new RENAME TO dive_data_sources',
            );
            await customStatement('''
              CREATE INDEX IF NOT EXISTS idx_dive_data_sources_dive_id
              ON dive_data_sources(dive_id)
            ''');
            await customStatement('PRAGMA foreign_keys = ON');
          }
        }
        if (from < 66) await reportProgress();

        if (from < 67) {
          final cols = await customSelect(
            "PRAGMA table_info('diver_settings')",
          ).get();
          if (cols.isNotEmpty) {
            final existing = cols.map((c) => c.read<String>('name')).toSet();
            if (!existing.contains('map_style')) {
              await customStatement(
                "ALTER TABLE diver_settings ADD COLUMN map_style TEXT NOT NULL DEFAULT 'openStreetMap'",
              );
            }
          }
        }
        if (from < 67) await reportProgress();

        if (from < 68) {
          // Guard: dive_profile_events may not exist in older migration tests.
          final dpeColumns = await customSelect(
            "PRAGMA table_info('dive_profile_events')",
          ).get();
          if (dpeColumns.isNotEmpty) {
            final existing = dpeColumns
                .map((c) => c.read<String>('name'))
                .toSet();
            if (!existing.contains('source')) {
              await customStatement(
                "ALTER TABLE dive_profile_events ADD COLUMN source TEXT NOT NULL DEFAULT 'imported'",
              );
            }
          }
        }
        if (from < 68) await reportProgress();
        if (from < 69) {
          // Guard: trips may not exist in older migration test schemas.
          final tripColumns = await customSelect(
            "PRAGMA table_info('trips')",
          ).get();
          if (tripColumns.isNotEmpty) {
            final existing = tripColumns
                .map((c) => c.read<String>('name'))
                .toSet();
            if (!existing.contains('is_shared')) {
              await customStatement(
                'ALTER TABLE trips ADD COLUMN is_shared INTEGER NOT NULL DEFAULT 0',
              );
            }
          }
          // Guard: dive_sites may not exist in older migration test schemas.
          final siteColumns = await customSelect(
            "PRAGMA table_info('dive_sites')",
          ).get();
          if (siteColumns.isNotEmpty) {
            final existing = siteColumns
                .map((c) => c.read<String>('name'))
                .toSet();
            if (!existing.contains('is_shared')) {
              await customStatement(
                'ALTER TABLE dive_sites ADD COLUMN is_shared INTEGER NOT NULL DEFAULT 0',
              );
            }
          }
        }
        if (from < 69) await reportProgress();
        if (from < 70) {
          // Migration 70: add source_uuid to dive_data_sources for
          // cross-format import deduplication (MacDive UUID, Shearwater
          // DiveId, Subsurface SSRF id, generic UDDF dive id).
          // libdivecomputer continues to use raw_fingerprint.
          // Guard: dive_data_sources may not exist in older migration tests.
          final cols = await customSelect(
            "PRAGMA table_info('dive_data_sources')",
          ).get();
          if (cols.isNotEmpty) {
            final existing = cols.map((c) => c.read<String>('name')).toSet();
            if (!existing.contains('source_uuid')) {
              await customStatement(
                'ALTER TABLE dive_data_sources ADD COLUMN source_uuid TEXT',
              );
            }
          }
        }
        if (from < 70) await reportProgress();
        if (from < 71) {
          // Migration 71: add MacDive dive + site metadata fields.
          final divesCols = await customSelect(
            "PRAGMA table_info('dives')",
          ).get();
          final divesExisting = divesCols
              .map((r) => r.data['name'] as String)
              .toSet();
          if (divesCols.isNotEmpty) {
            if (!divesExisting.contains('boat_name')) {
              await customStatement(
                'ALTER TABLE dives ADD COLUMN boat_name TEXT',
              );
            }
            if (!divesExisting.contains('boat_captain')) {
              await customStatement(
                'ALTER TABLE dives ADD COLUMN boat_captain TEXT',
              );
            }
            if (!divesExisting.contains('dive_operator')) {
              await customStatement(
                'ALTER TABLE dives ADD COLUMN dive_operator TEXT',
              );
            }
            if (!divesExisting.contains('surface_conditions')) {
              await customStatement(
                'ALTER TABLE dives ADD COLUMN surface_conditions TEXT',
              );
            }
          }
          final sitesCols = await customSelect(
            "PRAGMA table_info('dive_sites')",
          ).get();
          final sitesExisting = sitesCols
              .map((r) => r.data['name'] as String)
              .toSet();
          if (sitesCols.isNotEmpty) {
            if (!sitesExisting.contains('water_type')) {
              await customStatement(
                'ALTER TABLE dive_sites ADD COLUMN water_type TEXT',
              );
            }
            if (!sitesExisting.contains('body_of_water')) {
              await customStatement(
                'ALTER TABLE dive_sites ADD COLUMN body_of_water TEXT',
              );
            }
          }
        }
        if (from < 71) await reportProgress();
        if (from < 72) {
          // Phase 1 of Media Source Extension.
          // Add discriminator and new pointer columns to media.
          await customStatement(
            "ALTER TABLE media ADD COLUMN source_type TEXT NOT NULL DEFAULT 'platformGallery'",
          );
          await customStatement('ALTER TABLE media ADD COLUMN local_path TEXT');
          await customStatement(
            'ALTER TABLE media ADD COLUMN bookmark_ref TEXT',
          );
          await customStatement('ALTER TABLE media ADD COLUMN url TEXT');
          await customStatement(
            'ALTER TABLE media ADD COLUMN subscription_id TEXT',
          );
          await customStatement('ALTER TABLE media ADD COLUMN entry_key TEXT');
          await customStatement(
            'ALTER TABLE media ADD COLUMN connector_account_id TEXT',
          );
          await customStatement(
            'ALTER TABLE media ADD COLUMN remote_asset_id TEXT',
          );
          await customStatement(
            'ALTER TABLE media ADD COLUMN origin_device_id TEXT',
          );

          // Subscription registry (synced across devices).
          await customStatement('''
            CREATE TABLE IF NOT EXISTS media_subscriptions (
              id TEXT NOT NULL PRIMARY KEY,
              manifest_url TEXT NOT NULL,
              format TEXT NOT NULL,
              display_name TEXT,
              poll_interval_seconds INTEGER NOT NULL DEFAULT 86400,
              is_active INTEGER NOT NULL DEFAULT 1,
              credentials_host_id TEXT,
              created_at INTEGER NOT NULL,
              updated_at INTEGER NOT NULL
            )
          ''');

          // Per-device polling state (NOT synced).
          await customStatement('''
            CREATE TABLE IF NOT EXISTS media_subscription_state (
              subscription_id TEXT NOT NULL PRIMARY KEY
                REFERENCES media_subscriptions(id) ON DELETE CASCADE,
              last_polled_at INTEGER,
              next_poll_at INTEGER,
              last_etag TEXT,
              last_modified TEXT,
              last_error TEXT,
              last_error_at INTEGER
            )
          ''');

          // Service connector accounts (NOT synced).
          await customStatement('''
            CREATE TABLE IF NOT EXISTS connector_accounts (
              id TEXT NOT NULL PRIMARY KEY,
              connector_type TEXT NOT NULL,
              display_name TEXT NOT NULL,
              base_url TEXT,
              account_identifier TEXT,
              credentials_ref TEXT NOT NULL,
              added_at INTEGER NOT NULL,
              last_used_at INTEGER
            )
          ''');

          // Per-host credentials for ad-hoc network URLs (NOT synced).
          await customStatement('''
            CREATE TABLE IF NOT EXISTS network_credential_hosts (
              id TEXT NOT NULL PRIMARY KEY,
              hostname TEXT NOT NULL UNIQUE,
              auth_type TEXT NOT NULL,
              display_name TEXT,
              credentials_ref TEXT NOT NULL,
              added_at INTEGER NOT NULL,
              last_used_at INTEGER
            )
          ''');

          // Per-device fetch diagnostics (NOT synced).
          await customStatement('''
            CREATE TABLE IF NOT EXISTS media_fetch_diagnostics (
              media_item_id TEXT NOT NULL PRIMARY KEY
                REFERENCES media(id) ON DELETE CASCADE,
              last_error_at INTEGER,
              last_error_message TEXT,
              error_count INTEGER NOT NULL DEFAULT 0
            )
          ''');

          // Backfill source_type for existing rows.
          // Order matters: signature first (most specific), then platformGallery,
          // then localFile, with platformGallery as the safe default for the
          // unreachable "neither pointer set" case.
          await customStatement('''
            UPDATE media SET source_type = 'signature'
            WHERE file_type = 'instructor_signature'
          ''');
          await customStatement('''
            UPDATE media
            SET source_type = 'platformGallery'
            WHERE file_type != 'instructor_signature'
              AND platform_asset_id IS NOT NULL
          ''');
          await customStatement('''
            UPDATE media
            SET source_type = 'localFile',
                local_path = file_path
            WHERE file_type != 'instructor_signature'
              AND platform_asset_id IS NULL
              AND file_path IS NOT NULL
              AND file_path != ''
          ''');

          // Indexes.
          await customStatement('''
            CREATE INDEX IF NOT EXISTS idx_media_source_type
            ON media(source_type)
          ''');
          await customStatement('''
            CREATE UNIQUE INDEX IF NOT EXISTS idx_media_subscription_entry
            ON media(subscription_id, entry_key)
            WHERE subscription_id IS NOT NULL
          ''');
          await customStatement('''
            CREATE INDEX IF NOT EXISTS idx_media_connector_account
            ON media(connector_account_id)
          ''');
          await customStatement('''
            CREATE INDEX IF NOT EXISTS idx_media_origin_device
            ON media(origin_device_id)
          ''');
        }
        if (from < 72) await reportProgress();
        if (from < 73) {
          // Guard: dives may not exist in older migration-test contexts.
          final divesCols = await customSelect(
            "PRAGMA table_info('dives')",
          ).get();
          if (divesCols.isNotEmpty) {
            final divesExisting = divesCols
                .map((c) => c.read<String>('name'))
                .toSet();
            if (!divesExisting.contains('entry_latitude')) {
              await customStatement(
                'ALTER TABLE dives ADD COLUMN entry_latitude REAL',
              );
              await customStatement(
                'ALTER TABLE dives ADD COLUMN entry_longitude REAL',
              );
              await customStatement(
                'ALTER TABLE dives ADD COLUMN exit_latitude REAL',
              );
              await customStatement(
                'ALTER TABLE dives ADD COLUMN exit_longitude REAL',
              );
            }
          }
        }
        if (from < 73) await reportProgress();
        if (from < 74) {
          final cols = await customSelect(
            "PRAGMA table_info('dive_data_sources')",
          ).get();
          if (cols.isNotEmpty) {
            final existing = cols.map((c) => c.read<String>('name')).toSet();
            if (!existing.contains('entry_latitude')) {
              await customStatement(
                'ALTER TABLE dive_data_sources ADD COLUMN entry_latitude REAL',
              );
              await customStatement(
                'ALTER TABLE dive_data_sources ADD COLUMN entry_longitude REAL',
              );
              await customStatement(
                'ALTER TABLE dive_data_sources ADD COLUMN exit_latitude REAL',
              );
              await customStatement(
                'ALTER TABLE dive_data_sources ADD COLUMN exit_longitude REAL',
              );
            }
          }
        }
        if (from < 74) await reportProgress();
        if (from < 75) {
          final cols = await customSelect(
            "PRAGMA table_info('diver_settings')",
          ).get();
          if (cols.isNotEmpty) {
            final existing = cols.map((c) => c.read<String>('name')).toSet();
            if (!existing.contains('default_show_gas_timeline')) {
              await customStatement(
                'ALTER TABLE diver_settings ADD COLUMN default_show_gas_timeline INTEGER NOT NULL DEFAULT 0',
              );
            }
          }
        }
        if (from < 75) await reportProgress();
        if (from < 76) {
          final cols = await customSelect(
            "PRAGMA table_info('diver_settings')",
          ).get();
          if (cols.isNotEmpty) {
            final existing = cols.map((c) => c.read<String>('name')).toSet();
            if (!existing.contains('site_match_sensitivity')) {
              await customStatement(
                "ALTER TABLE diver_settings ADD COLUMN site_match_sensitivity TEXT NOT NULL DEFAULT 'balanced'",
              );
            }
          }
        }
        if (from < 76) await reportProgress();
        if (from < 77) {
          // Add nullable Hybrid Logical Clock column to every conflict-capable
          // syncable table (and sync_metadata for the device clock). Nullable
          // so existing rows fall back to updatedAt ordering until rewritten.
          for (final table in _hlcTables) {
            final cols = await customSelect(
              "PRAGMA table_info('$table')",
            ).get();
            final existing = cols.map((c) => c.read<String>('name')).toSet();
            if (cols.isNotEmpty && !existing.contains('hlc')) {
              await customStatement('ALTER TABLE $table ADD COLUMN hlc TEXT');
            }
          }
        }
        if (from < 77) await reportProgress();
        if (from < 78) {
          // Add the nullable per-database instance token to sync_metadata. Used
          // to detect a database restore/overwrite that leaves the device id
          // unchanged (a same-device backup). Nullable so existing rows read as
          // "no token yet" and are treated like a first-run seed.
          final cols = await customSelect(
            "PRAGMA table_info('sync_metadata')",
          ).get();
          final existing = cols.map((c) => c.read<String>('name')).toSet();
          if (cols.isNotEmpty && !existing.contains('instance_token')) {
            await customStatement(
              'ALTER TABLE sync_metadata ADD COLUMN instance_token TEXT',
            );
          }
        }
        if (from < 78) await reportProgress();
        if (from < 79) {
          // Support surface-interval derivation from timestamps (issue #235):
          // the correlated subquery SELECT MAX(exit_time) WHERE diver_id AND
          // exit_time < entry_time needs this index to stay fast at scale.
          // Guard with PRAGMA in case partial-schema migration fixtures are
          // used in tests where dives may not yet have these columns.
          final divesCols = await customSelect(
            "PRAGMA table_info('dives')",
          ).get();
          if (divesCols.isNotEmpty) {
            final colNames = divesCols
                .map((c) => c.read<String>('name'))
                .toSet();
            if (colNames.contains('diver_id') &&
                colNames.contains('exit_time')) {
              await customStatement('''
                CREATE INDEX IF NOT EXISTS idx_dives_diver_exittime
                ON dives(diver_id, exit_time DESC)
              ''');
            }
          }
        }
        if (from < 79) await reportProgress();
        if (from < 80) {
          // Library epoch anchor for restore Replace mode: the epoch this
          // device last accepted, dual-anchored with a SharedPreferences
          // mirror (see library_epoch_store.dart).
          final cols = await customSelect(
            "PRAGMA table_info('sync_metadata')",
          ).get();
          final existing = cols.map((c) => c.read<String>('name')).toSet();
          if (cols.isNotEmpty && !existing.contains('last_accepted_epoch_id')) {
            await customStatement(
              'ALTER TABLE sync_metadata ADD COLUMN last_accepted_epoch_id TEXT',
            );
          }
        }
        if (from < 80) await reportProgress();
        if (from < 81) {
          // Provider stamp for the sync cursor: lastSyncTimestamp minted
          // against one backend must read as absent for another, so first
          // contact with a switched backend stays detectable. Nullable so
          // existing cursors read as legacy (valid for any provider).
          final cols = await customSelect(
            "PRAGMA table_info('sync_metadata')",
          ).get();
          final existing = cols.map((c) => c.read<String>('name')).toSet();
          if (cols.isNotEmpty && !existing.contains('last_sync_provider')) {
            await customStatement(
              'ALTER TABLE sync_metadata ADD COLUMN last_sync_provider TEXT',
            );
          }
        }
        if (from < 81) await reportProgress();
        if (from < 82) {
          // Recover databases stranded by the v77 schema-version collision:
          // PR #302 (surface-interval index) shipped a v77 that only created
          // an index, while the HLC backfill also claimed v77. Any database
          // that upgraded under the index-only v77 sits at user_version >= 77
          // with no hlc columns, so the v77 guard above (from < 77) is false
          // and the backfill is skipped — leaving every sync UNION query
          // (e.g. SELECT MAX(hlc) FROM "equipment") failing at prepare time.
          //
          // Re-run the same PRAGMA-guarded ALTER: healthy databases that
          // already have hlc no-op on every table; affected databases get the
          // missing columns added and sync starts working again.
          for (final table in _hlcTables) {
            final cols = await customSelect(
              "PRAGMA table_info('$table')",
            ).get();
            final existing = cols.map((c) => c.read<String>('name')).toSet();
            if (cols.isNotEmpty && !existing.contains('hlc')) {
              await customStatement('ALTER TABLE $table ADD COLUMN hlc TEXT');
            }
          }
        }
        if (from < 82) await reportProgress();
        if (from < 83) {
          // Comprehensive recovery for databases stranded past v77 by the wider
          // set of sync-branch schema-version collisions. The v77 HLC / PR #302
          // index collision (healed by the v82 block above) was only the first:
          // the abandoned encrypted-sync and iCloud-diagnostic lineages also
          // reused v78-v81 for unrelated migrations. A database that reached
          // user_version >= 78 via one of those branches skipped the canonical
          // sync_metadata ALTERs — instance_token (v78), last_accepted_epoch_id
          // (v80), last_sync_provider (v81) — because their `from < N` guards
          // are false once `from` already passed N. The v82 block re-added only
          // hlc, so the three text columns stayed missing once the database sat
          // at the current version and stopped running onUpgrade. Every identity
          // write then failed at prepare time with "no such column:
          // instance_token" (launch-time reconcile and the twin-split
          // adopt-fresh-identity path), so sync could never start.
          //
          // Re-assert every post-v76 sync_metadata column with PRAGMA-guarded
          // ALTERs: healthy databases no-op, stranded databases are healed. The
          // columns are all nullable, so existing rows read as "not yet set"
          // exactly as they did on the original add.
          const syncMetadataColumns = <String, String>{
            'instance_token': 'TEXT',
            'last_accepted_epoch_id': 'TEXT',
            'last_sync_provider': 'TEXT',
          };
          final smCols = await customSelect(
            "PRAGMA table_info('sync_metadata')",
          ).get();
          if (smCols.isNotEmpty) {
            final existing = smCols.map((c) => c.read<String>('name')).toSet();
            for (final entry in syncMetadataColumns.entries) {
              if (!existing.contains(entry.key)) {
                await customStatement(
                  'ALTER TABLE sync_metadata '
                  'ADD COLUMN ${entry.key} ${entry.value}',
                );
              }
            }
          }
          // Re-run the hlc backfill as well, covering any database that reached
          // user_version 82 (so the v82 block no longer fires) while still
          // missing hlc on some table via a collision that also claimed v82.
          for (final table in _hlcTables) {
            final cols = await customSelect(
              "PRAGMA table_info('$table')",
            ).get();
            final existing = cols.map((c) => c.read<String>('name')).toSet();
            if (cols.isNotEmpty && !existing.contains('hlc')) {
              await customStatement('ALTER TABLE $table ADD COLUMN hlc TEXT');
            }
          }
        }
        if (from < 83) await reportProgress();
        if (from < 84) {
          // Incremental changeset-log sync: per-peer download cursors and this
          // device's own per-provider publish position.
          await customStatement('''
            CREATE TABLE IF NOT EXISTS sync_peer_cursors (
              peer_device_id TEXT NOT NULL,
              provider TEXT NOT NULL,
              base_seq_applied INTEGER,
              last_seq_applied INTEGER NOT NULL DEFAULT 0,
              updated_at INTEGER NOT NULL,
              PRIMARY KEY (peer_device_id, provider)
            )
          ''');
          await customStatement('''
            CREATE TABLE IF NOT EXISTS local_publish_states (
              provider TEXT NOT NULL PRIMARY KEY,
              base_seq INTEGER,
              base_part_count INTEGER,
              base_bytes INTEGER,
              head_seq INTEGER NOT NULL DEFAULT 0,
              published_hlc_high TEXT,
              changeset_bytes_since_base INTEGER NOT NULL DEFAULT 0,
              updated_at INTEGER NOT NULL
            )
          ''');
        }
        if (from < 84) await reportProgress();
        if (from < 85) {
          // media, species, field_presets become first-class HLC entities so
          // they delta by their own hlc instead of being exported in full.
          // Table/column identifiers cannot be SQL-parameterized; these names
          // are a fixed compile-time const list (no user input), so the string
          // interpolation below is injection-safe.
          for (final table in const ['media', 'species', 'field_presets']) {
            final cols = await customSelect(
              "PRAGMA table_info('$table')",
            ).get();
            final existing = cols.map((c) => c.read<String>('name')).toSet();
            if (cols.isNotEmpty && !existing.contains('hlc')) {
              await customStatement('ALTER TABLE $table ADD COLUMN hlc TEXT');
            }
          }
        }
        if (from < 85) await reportProgress();
        if (from < 86) {
          // Deletions become HLC-versioned like rows: logDeletion now stamps a
          // monotonic hlc so an incremental changeset can carry only NEW
          // tombstones instead of re-publishing the whole deletion log every
          // sync. Backfill pre-existing tombstones with a minimal sentinel so
          // they read as already-published (excluded from incrementals) while
          // still riding every full base -- no re-publish, no resurrection.
          final cols = await customSelect(
            "PRAGMA table_info('deletion_log')",
          ).get();
          if (cols.isNotEmpty) {
            final existing = cols.map((c) => c.read<String>('name')).toSet();
            if (!existing.contains('hlc')) {
              await customStatement(
                'ALTER TABLE deletion_log ADD COLUMN hlc TEXT',
              );
            }
            await customStatement(
              "UPDATE deletion_log SET hlc = '000000000000000:000000:legacy' "
              'WHERE hlc IS NULL',
            );
          }
        }
        if (from < 86) await reportProgress();
        if (from < 87) {
          // Prior dive experience (issue #331): three nullable columns on
          // `divers`. PRAGMA-guarded so a healthy database no-ops; existing
          // rows read as NULL = "no prior experience".
          final cols = await customSelect("PRAGMA table_info('divers')").get();
          if (cols.isNotEmpty) {
            final existing = cols.map((c) => c.read<String>('name')).toSet();
            if (!existing.contains('prior_dive_count')) {
              await customStatement(
                'ALTER TABLE divers ADD COLUMN prior_dive_count INTEGER',
              );
            }
            if (!existing.contains('prior_dive_time_seconds')) {
              await customStatement(
                'ALTER TABLE divers ADD COLUMN prior_dive_time_seconds INTEGER',
              );
            }
            if (!existing.contains('diving_since')) {
              await customStatement(
                'ALTER TABLE divers ADD COLUMN diving_since INTEGER',
              );
            }
          }
        }
        if (from < 87) await reportProgress();
        if (from < 88) {
          // Add 'Cavern' as a built-in dive type. Cavern diving (light-zone
          // only, cavern cert) is a distinct discipline from Cave (beyond
          // light zone, full cave cert). Guarded by a sqlite_master check so
          // minimal-schema test databases without dive_types are not affected;
          // INSERT OR IGNORE preserves any user-created 'cavern' row.
          //
          // Renumbered from v84 to v88 because upstream claimed v84-v87 for
          // sync-infrastructure migrations (see blocks above).
          final tables = await customSelect(
            "SELECT name FROM sqlite_master WHERE type='table' AND name='dive_types'",
          ).get();
          if (tables.isNotEmpty) {
            final now = DateTime.now().millisecondsSinceEpoch;
            await customStatement('''
              INSERT OR IGNORE INTO dive_types (id, name, is_built_in, sort_order, created_at, updated_at)
              VALUES ('cavern', 'Cavern', 1, 14, $now, $now)
            ''');
          }
        }
        if (from < 88) await reportProgress();
        if (from < 89) {
          // Individual CCR O2 cell readings (sensor1..sensor6 from Subsurface
          // CCR imports): six nullable columns on `dive_profiles`. PRAGMA-guarded
          // so a healthy database no-ops; existing rows read as NULL.
          //
          // Renumbered from v88 to v89 because upstream claimed v88 for the
          // Cavern dive-type migration (see block above).
          final cols = await customSelect(
            "PRAGMA table_info('dive_profiles')",
          ).get();
          if (cols.isNotEmpty) {
            final existing = cols.map((c) => c.read<String>('name')).toSet();
            for (var n = 1; n <= 6; n++) {
              if (!existing.contains('o2_sensor$n')) {
                await customStatement(
                  'ALTER TABLE dive_profiles ADD COLUMN o2_sensor$n REAL',
                );
              }
            }
          }
        }
        if (from < 89) await reportProgress();
        if (from < 90) {
          // City and Island localities for dive sites (issue #344). Lets
          // divers tell apart sites that share a country and region (e.g.
          // multiple islands off Cebu). PRAGMA-guarded so a healthy database
          // no-ops; existing rows read as NULL. body_of_water already exists.
          final cols = await customSelect(
            "PRAGMA table_info('dive_sites')",
          ).get();
          if (cols.isNotEmpty) {
            final existing = cols.map((c) => c.read<String>('name')).toSet();
            if (!existing.contains('city')) {
              await customStatement(
                'ALTER TABLE dive_sites ADD COLUMN city TEXT',
              );
            }
            if (!existing.contains('island')) {
              await customStatement(
                'ALTER TABLE dive_sites ADD COLUMN island TEXT',
              );
            }
          }
        }
        if (from < 90) await reportProgress();
        if (from < 91) {
          // Persisted default for the "Ascent Rate Line" profile overlay
          // (issue: ascent-rate toggles default-off). Previously the line was a
          // session-only toggle with no setting; it now joins the Default
          // Visible Metrics list. PRAGMA-guarded so a healthy database no-ops
          // and an interrupted upgrade does not fail on a duplicate ALTER.
          final cols = await customSelect(
            "PRAGMA table_info('diver_settings')",
          ).get();
          if (cols.isNotEmpty) {
            final existing = cols.map((c) => c.read<String>('name')).toSet();
            if (!existing.contains('default_show_ascent_rate_line')) {
              await customStatement(
                'ALTER TABLE diver_settings '
                'ADD COLUMN default_show_ascent_rate_line '
                'INTEGER NOT NULL DEFAULT 0',
              );
            }
          }
        }
        if (from < 91) await reportProgress();
        if (from < 92) {
          await m.createTable(diveDiveTypes);
          // Seed only when the dives table (with its dive_type column) is
          // present. Minimal-schema migration tests build a partial database
          // without it, and the seed must not fail there.
          final diveCols = await customSelect(
            "PRAGMA table_info('dives')",
          ).get();
          final hasDiveType = diveCols.any(
            (c) => c.read<String>('name') == 'dive_type',
          );
          if (hasDiveType) {
            await customStatement(kSeedDiveDiveTypesSql);
          }
        }
        if (from < 92) await reportProgress();
        if (from < 93) {
          // Backfill built-in dive types. The full built-in set was only ever
          // seeded in onCreate, so every database that reached the app via
          // migration (rather than a fresh install) kept an EMPTY dive_types
          // table -- the multi-select dive-type picker (#414) then showed no
          // options. Guarded by a sqlite_master check so minimal-schema
          // migration tests without dive_types are unaffected; INSERT OR IGNORE
          // preserves rows already present (synced custom types, 'cavern' from
          // the v88 migration).
          final tables = await customSelect(
            "SELECT name FROM sqlite_master WHERE type='table' AND name='dive_types'",
          ).get();
          if (tables.isNotEmpty) {
            await customStatement(kSeedBuiltInDiveTypesSql);
          }
        }
        if (from < 93) await reportProgress();
        if (from < 94) {
          // Guarded by sqlite_master so minimal-schema migration tests without
          // diver_settings are unaffected.
          final dsTable = await customSelect(
            "SELECT name FROM sqlite_master WHERE type='table' AND name='diver_settings'",
          ).get();
          if (dsTable.isNotEmpty) {
            await m.addColumn(diverSettings, diverSettings.ascentGasSet);
          }
        }
        if (from < 94) await reportProgress();
        if (from < 95) {
          // Dive naming (#400): optional user-defined dive name. Guarded by a
          // PRAGMA check so an interrupted upgrade that already added the
          // column does not fail on a duplicate ALTER, and so minimal-schema
          // migration tests without a dives table are unaffected (empty
          // table_info means no dives table).
          final diveCols = await customSelect(
            "PRAGMA table_info('dives')",
          ).get();
          final hasName = diveCols.any((c) => c.read<String>('name') == 'name');
          if (diveCols.isNotEmpty && !hasName) {
            await customStatement('ALTER TABLE dives ADD COLUMN name TEXT');
          }
        }
        if (from < 95) await reportProgress();
        if (from < 96) {
          // Persisted default for the "Photo Markers" profile overlay
          // (issue #162). Guarded like v91: skip when diver_settings does
          // not exist (minimal-schema migration tests) or the column is
          // already present (interrupted upgrade).
          final cols = await customSelect(
            "PRAGMA table_info('diver_settings')",
          ).get();
          if (cols.isNotEmpty) {
            final existing = cols.map((c) => c.read<String>('name')).toSet();
            if (!existing.contains('default_show_photo_markers')) {
              await customStatement(
                'ALTER TABLE diver_settings '
                'ADD COLUMN default_show_photo_markers '
                'INTEGER NOT NULL DEFAULT 1',
              );
            }
          }
        }
        if (from < 96) await reportProgress();
        if (from < 97) {
          // Multi-computer consolidation: per-source attribution for tanks,
          // pressure curves, and events. Guarded per table so minimal-schema
          // migration tests without these tables are unaffected; existing
          // rows keep NULL (= primary source / manual entry). (Authored as
          // v94 on the feature branch; renumbered on merge as later
          // migrations landed on main: ascent_gas_set v94, dive naming v95,
          // photo markers v96.)
          for (final table in [
            'dive_tanks',
            'tank_pressure_profiles',
            'dive_profile_events',
          ]) {
            final cols = await customSelect(
              "PRAGMA table_info('$table')",
            ).get();
            if (cols.isEmpty) continue;
            final names = cols.map((c) => c.read<String>('name')).toSet();
            if (!names.contains('computer_id')) {
              await customStatement(
                'ALTER TABLE $table ADD COLUMN computer_id TEXT '
                'REFERENCES dive_computers (id) ON DELETE SET NULL',
              );
            }
          }
        }
        if (from < 97) await reportProgress();
        if (from < 98) {
          // Checklist tables for trip planning (issue #164). Raw idempotent
          // DDL (matches the v84 idiom) so interrupted migrations are safe.
          // Renumbered v95 -> v96 -> v97 -> v98 as parallel branches each
          // consumed a version before this merged (dive naming v95, photo
          // markers v96, multi-computer consolidation v97), stranding some
          // live databases at those versions without the checklist tables.
          // Re-running the idempotent CREATE TABLE/INDEX IF NOT EXISTS
          // statements here recovers them without disturbing what earlier
          // versions added — the same recovery pattern as the v82/v83
          // schema-version-collision blocks above.
          await customStatement('''
            CREATE TABLE IF NOT EXISTS checklist_templates (
              id TEXT NOT NULL PRIMARY KEY,
              diver_id TEXT REFERENCES divers (id),
              name TEXT NOT NULL,
              description TEXT NOT NULL DEFAULT '',
              created_at INTEGER NOT NULL,
              updated_at INTEGER NOT NULL,
              hlc TEXT
            )
          ''');
          await customStatement('''
            CREATE TABLE IF NOT EXISTS checklist_template_items (
              id TEXT NOT NULL PRIMARY KEY,
              template_id TEXT NOT NULL REFERENCES checklist_templates (id),
              title TEXT NOT NULL,
              category TEXT,
              notes TEXT NOT NULL DEFAULT '',
              due_offset_days INTEGER,
              sort_order INTEGER NOT NULL DEFAULT 0,
              created_at INTEGER NOT NULL,
              updated_at INTEGER NOT NULL,
              hlc TEXT
            )
          ''');
          await customStatement('''
            CREATE TABLE IF NOT EXISTS trip_checklist_items (
              id TEXT NOT NULL PRIMARY KEY,
              trip_id TEXT NOT NULL REFERENCES trips (id),
              title TEXT NOT NULL,
              category TEXT,
              notes TEXT NOT NULL DEFAULT '',
              due_date INTEGER,
              is_done INTEGER NOT NULL DEFAULT 0,
              completed_at INTEGER,
              sort_order INTEGER NOT NULL DEFAULT 0,
              created_at INTEGER NOT NULL,
              updated_at INTEGER NOT NULL,
              hlc TEXT
            )
          ''');
          await customStatement('''
            CREATE INDEX IF NOT EXISTS idx_checklist_template_items_template_id
            ON checklist_template_items(template_id)
          ''');
          await customStatement('''
            CREATE INDEX IF NOT EXISTS idx_trip_checklist_items_trip_id
            ON trip_checklist_items(trip_id)
          ''');
        }
        if (from < 98) await reportProgress();
        if (from < 99) {
          // Buddy professional credentials + structured instructor link on
          // certifications (issue #395). PRAGMA-guarded so a healthy database
          // no-ops and an interrupted upgrade does not fail on a duplicate
          // ALTER. createTable is IF NOT EXISTS. (v99: renumbered from v94
          // repeatedly as main claimed 94-96, then 97, then 98 while the
          // branch was in review; a beforeOpen backstop re-asserts these
          // objects too, so a version collision can't strand them.)
          final certCols = await customSelect(
            "PRAGMA table_info('certifications')",
          ).get();
          if (certCols.isNotEmpty) {
            final existing = certCols
                .map((c) => c.read<String>('name'))
                .toSet();
            if (!existing.contains('instructor_id')) {
              await customStatement(
                'ALTER TABLE certifications ADD COLUMN instructor_id TEXT '
                'REFERENCES buddies (id) ON DELETE SET NULL',
              );
            }
          }
          await m.createTable(buddyRoles);
        }
        if (from < 99) await reportProgress();
        if (from < 100) {
          // Saved dive plans (planner redesign Phase 2): three synced tables.
          // createTable is IF NOT EXISTS and the indexes are guarded, so this
          // block is idempotent; the beforeOpen backstop re-asserts the same
          // objects against schema-version collisions.
          await m.createTable(divePlans);
          await m.createTable(divePlanTanks);
          await m.createTable(divePlanSegments);
          await customStatement('''
            CREATE INDEX IF NOT EXISTS idx_dive_plan_tanks_plan_id
            ON dive_plan_tanks(plan_id)
          ''');
          await customStatement('''
            CREATE INDEX IF NOT EXISTS idx_dive_plan_segments_plan_id
            ON dive_plan_segments(plan_id)
          ''');
        }
        if (from < 100) await reportProgress();
        if (from < 101) {
          // GPS surface track logging (discussion #289). Raw idempotent DDL
          // (v98 checklist idiom) so interrupted migrations and schema-version
          // collisions are safe. gps_track_points_local is a device-local
          // recording buffer and is never synced.
          await customStatement('''
            CREATE TABLE IF NOT EXISTS gps_tracks (
              id TEXT NOT NULL PRIMARY KEY,
              start_time INTEGER NOT NULL,
              end_time INTEGER,
              tz_offset_minutes INTEGER NOT NULL DEFAULT 0,
              device_name TEXT,
              point_count INTEGER NOT NULL DEFAULT 0,
              points BLOB,
              created_at INTEGER NOT NULL,
              updated_at INTEGER NOT NULL,
              hlc TEXT
            )
          ''');
          await customStatement('''
            CREATE TABLE IF NOT EXISTS gps_track_points_local (
              row_id INTEGER PRIMARY KEY AUTOINCREMENT,
              track_id TEXT NOT NULL,
              timestamp INTEGER NOT NULL,
              latitude REAL NOT NULL,
              longitude REAL NOT NULL,
              accuracy REAL
            )
          ''');
          await customStatement('''
            CREATE INDEX IF NOT EXISTS idx_gps_track_points_local_track_id
            ON gps_track_points_local(track_id)
          ''');
        }
        if (from < 101) await reportProgress();
        if (from < 102) {
          await _relinkStrandedTankPressures();
        }
        if (from < 102) await reportProgress();
        if (from < 103) {
          // Two features independently claimed v103 on parallel branches
          // (media store spec 2026-07-10; dive roles #551/#547). Both
          // blocks are idempotent and touch disjoint tables, so the merge
          // keeps both and beforeOpen re-asserts each against the
          // schema-version collision this very overlap illustrates.

          // Media store Phase 1: content identity + upload stamps on media,
          // plus the secret-free store descriptor. Guarded ALTERs and
          // IF NOT EXISTS keep this idempotent.
          await _assertMediaStoreSchema();

          // Dive roles vocabulary (#551) + the diver's own role (#547).
          // createTable is IF NOT EXISTS and the seed is INSERT OR IGNORE,
          // so this block is idempotent. The existence guards (divers for
          // the seed's FK parent, dives for the ALTER) only matter for
          // minimal test-fixture databases.
          await m.createTable(diveRoles);
          final diversTable = await customSelect(
            "SELECT name FROM sqlite_master "
            "WHERE type='table' AND name='divers'",
          ).get();
          if (diversTable.isNotEmpty) {
            await customStatement(kSeedBuiltInDiveRolesSql);
          }
          final diveCols = await customSelect(
            "PRAGMA table_info('dives')",
          ).get();
          final hasDiverRole = diveCols.any(
            (c) => c.read<String>('name') == 'diver_role',
          );
          if (diveCols.isNotEmpty && !hasDiverRole) {
            await customStatement(
              'ALTER TABLE dives ADD COLUMN diver_role TEXT',
            );
          }
        }
        if (from < 103) await reportProgress();
        if (from < 104) {
          await m.createTable(diverWeightEntries);
          await m.createTable(divePlanEquipment);
          Future<void> addColumnIfMissing(
            String table,
            String column,
            String type,
          ) async {
            final cols = await customSelect(
              "PRAGMA table_info('$table')",
            ).get();
            final has = cols.any((c) => c.read<String>('name') == column);
            if (cols.isNotEmpty && !has) {
              await customStatement(
                'ALTER TABLE $table ADD COLUMN $column $type',
              );
            }
          }

          await addColumnIfMissing('dives', 'weighting_feedback', 'TEXT');
          await addColumnIfMissing('dives', 'weighting_feedback_kg', 'REAL');
          await addColumnIfMissing('equipment', 'buoyancy_kg', 'REAL');
          await addColumnIfMissing('equipment', 'weight_kg', 'REAL');
          await addColumnIfMissing('dive_plans', 'planned_weight_kg', 'REAL');
          await addColumnIfMissing(
            'dive_plans',
            'planned_weight_placement',
            'TEXT',
          );
          await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_diver_weight_entries_diver_id '
            'ON diver_weight_entries(diver_id)',
          );
          await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_dive_plan_equipment_plan_id '
            'ON dive_plan_equipment(plan_id)',
          );
        }
        if (from < 104) await reportProgress();
        if (from < 105) {
          // v105: per-sample compass heading (DC_SAMPLE_BEARING) on
          // dive_profiles. PRAGMA-guarded so a healthy database no-ops.
          final profileCols = await customSelect(
            "PRAGMA table_info('dive_profiles')",
          ).get();
          if (profileCols.isNotEmpty) {
            final hasHeading = profileCols.any(
              (c) => c.read<String>('name') == 'heading',
            );
            if (!hasHeading) {
              await customStatement(
                'ALTER TABLE dive_profiles ADD COLUMN heading REAL',
              );
            }
          }
        }
        if (from < 105) await reportProgress();
        if (from < 106) {
          // Lightroom auto-linking: connector identity on pending photo
          // suggestions. PRAGMA-guarded ALTERs keep this idempotent; the
          // beforeOpen backstop re-asserts it against parallel-branch
          // schema-version collisions (v104 weight planner and v105
          // heading both renumbered this block already, the same disease
          // the v103 comment documents).
          await _assertConnectorSuggestionColumns();
        }
        if (from < 106) await reportProgress();
        if (from < 107) {
          // Connected accounts (program spec section 5). Idempotent DDL;
          // beforeOpen re-asserts against parallel-branch version collisions.
          await _assertConnectedAccountsSchema();
          // Adopt Lightroom connector accounts (ids preserved: scan state
          // and suggestion rows key on them), then retire the table. Guarded
          // on table existence for fresh installs and minimal test fixtures.
          final connectorTable = await customSelect(
            "SELECT name FROM sqlite_master WHERE type='table' "
            "AND name='connector_accounts'",
          ).get();
          if (connectorTable.isNotEmpty) {
            await customStatement(
              "INSERT OR IGNORE INTO connected_accounts "
              "(id, kind, label, account_identifier, created_at, updated_at) "
              "SELECT id, 'adobeLightroom', display_name, account_identifier, "
              "added_at, added_at FROM connector_accounts "
              "WHERE connector_type = 'lightroom'",
            );
            await customStatement('DROP TABLE IF EXISTS connector_accounts');
          }
        }
        if (from < 107) await reportProgress();
        if (from < 108) {
          // Manifest subscriptions become synced (program spec section 6).
          await _assertMediaSubscriptionsHlc();
        }
        if (from < 108) await reportProgress();
        if (from < 109) {
          // issue #553: certifications can belong to a buddy. Add the owner
          // column, then copy each buddy's inline cert into a certifications
          // row (deterministic id so per-device migration converges). The copy
          // runs here only -- see _migrateBuddyInlineCertifications.
          await _assertCertificationBuddyOwnerColumn();
          await _migrateBuddyInlineCertifications();
        }
        if (from < 109) await reportProgress();
        if (from < 110) {
          // issue #553 contract: the inline buddy cert columns are redundant
          // (data now lives in certifications rows). Copy once more as a
          // safety net -- covers a collision that advanced user_version to
          // v109 without running the v109 copy -- THEN drop. SQLite >= 3.35
          // supports DROP COLUMN; the PRAGMA guard keeps a fresh v110 db a
          // no-op.
          await _migrateBuddyInlineCertifications();
          final buddyCols = await customSelect(
            "PRAGMA table_info('buddies')",
          ).get();
          final names = buddyCols.map((c) => c.read<String>('name')).toSet();
          if (names.contains('certification_level')) {
            await customStatement(
              'ALTER TABLE buddies DROP COLUMN certification_level',
            );
          }
          if (names.contains('certification_agency')) {
            await customStatement(
              'ALTER TABLE buddies DROP COLUMN certification_agency',
            );
          }
        }
        if (from < 110) await reportProgress();
        if (from < 111) {
          await _assertEquipmentSetDefaultAndGeofenceSchema();
        }
        if (from < 111) await reportProgress();
        if (from < 112) {
          await _assertEquipmentThicknessColumn();
        }
        if (from < 112) await reportProgress();
        if (from < 113) {
          await _assertCnsCalculationMethodColumn();
        }
        if (from < 113) await reportProgress();
        if (from < 114) {
          // Guarded like the beforeOpen backstops: minimal migration-test
          // fixtures may lack the table entirely.
          final peerCursorCols = await customSelect(
            "PRAGMA table_info('sync_peer_cursors')",
          ).get();
          final hasAck = peerCursorCols.any(
            (c) => c.read<String>('name') == 'applied_hlc_high',
          );
          if (peerCursorCols.isNotEmpty && !hasAck) {
            await m.addColumn(syncPeerCursors, syncPeerCursors.appliedHlcHigh);
          }
          await ensureDeletionLogIndex();
        }
        if (from < 114) await reportProgress();
        // v120: planner Subsurface-parity columns. Version claimed in-worktree
        // per the schema-ladder convention; reconcile numbering at merge time.
        if (from < 120) {
          await _assertPlannerParitySchema();
        }
        if (from < 120) await reportProgress();
        // v121: course requirement tracker (renumbered from v114 at merge
        // time; v114 became the tombstone-GC migration on main). Both tables
        // are new, no data migration. createTable is idempotent (IF NOT
        // EXISTS).
        if (from < 121) {
          await m.createTable(courseRequirements);
          await m.createTable(courseRequirementDives);
        }
        if (from < 121) await reportProgress();
        // v122: gear service ledger (renumbered from v115 as main advanced
        // past it at merge time). The legacy backfill runs here only, never in
        // beforeOpen, so user-deleted schedules are not resurrected.
        if (from < 122) {
          await _assertServiceLedgerSchema();
          await _backfillLegacyServiceSchedules();
        }
        if (from < 122) await reportProgress();
        // v123: post-dive safety review tables + diver safety settings columns
        // (renumbered from v115 as main advanced past it at merge time).
        if (from < 123) {
          await _assertSafetyReviewSchema();
        }
        if (from < 123) await reportProgress();
        // v124: equipment type-specific attributes (renumbered from v115/v123
        // as main advanced past it at merge time). The legacy-column copy runs
        // here only, never in beforeOpen, so user-cleared attributes are not
        // resurrected.
        if (from < 124) {
          await _assertEquipmentAttributesSchema();
          await _migrateLegacyEquipmentColumnsToAttributes();
        }
        if (from < 124) await reportProgress();
        // v125: diver_settings.no_fly_preset column (safety phase 2, no-fly
        // countdown). Renumbered from v117/v124 as main advanced past it at
        // merge time.
        if (from < 125) {
          await _assertNoFlySettingsColumn();
        }
        if (from < 125) await reportProgress();
        // v126: emergency_chambers table + emergency card settings columns
        // (renumbered from v118 as main advanced past it at merge time).
        if (from < 126) {
          await _assertEmergencyCardSchema();
        }
        if (from < 126) await reportProgress();
        // v127: incidents table (near-miss log, safety phase 4). Renumbered
        // from v119 as main advanced past it at merge time.
        if (from < 127) {
          await _assertIncidentsSchema();
        }
        if (from < 127) await reportProgress();
        // v128: pre-dive checklist tables + built-in template seeds
        // (renumbered from v117/v127 as main advanced past it at merge time).
        if (from < 128) {
          await _assertPreDiveChecklistSchema();
          await _seedBuiltInPreDiveTemplates();
        }
        if (from < 128) await reportProgress();
        // v129: quality_findings table for the Data Quality Assistant
        // (renumbered from v118 as main advanced past it at merge time).
        if (from < 129) {
          await _assertQualityFindingsSchema();
        }
        if (from < 129) await reportProgress();
        // v130: media_enrichment.hlc so a photo's depth/time association
        // replicates through sync (it was local-only before).
        if (from < 130) {
          await _assertMediaEnrichmentHlcColumn();
        }
        if (from < 130) await reportProgress();
        // v131: reconcile legacy service intervals edited after the v122
        // backfill into General service clocks (deletion-log guarded).
        if (from < 131) {
          await _reconcileLegacyServiceSchedules();
        }
        if (from < 131) await reportProgress();
        // v132: correct dives whose bottom_time was stored equal to runtime by
        // older imports (Subsurface/MacDive/CSV via the UDDF entity importer,
        // which seeded bottom_time from the total-time `duration`). onUpgrade
        // only -- a deterministic local recompute, never beforeOpen, so a
        // profile-less dive a user deliberately left with bottom_time==runtime
        // is not re-touched on every open.
        if (from < 132) {
          await _backfillBottomTimeFromProfile();
        }
        if (from < 132) await reportProgress();
        // v133: deco stop band columns on diver_settings (renumbered from v130
        // as main advanced past it at merge time).
        if (from < 133) {
          await _assertDecoStopSettingsColumns();
        }
        if (from < 133) await reportProgress();
        // v134: media compressed-rendition columns (adjustable upload quality
        // Phase A). Renumbered from v130 as main advanced past it at merge time.
        if (from < 134) {
          await _assertMediaCompressedRenditionColumns();
        }
        if (from < 134) await reportProgress();
      },
      beforeOpen: (details) async {
        // Enable foreign keys
        await customStatement('PRAGMA foreign_keys = ON');

        // v103 backstop: re-assert media store schema (the helper is
        // self-guarding when the media table is absent).
        await _assertMediaStoreSchema();

        // v130 backstop: re-assert the media_enrichment.hlc column.
        await _assertMediaEnrichmentHlcColumn();

        // v134 backstop: re-assert compressed-rendition columns.
        await _assertMediaCompressedRenditionColumns();

        // v106 backstop: re-assert connector-suggestion columns (the helper
        // is self-guarding when the suggestions table is absent).
        await _assertConnectorSuggestionColumns();

        // v107 backstop: re-assert connected accounts schema.
        await _assertConnectedAccountsSchema();

        // v108 backstop: re-assert media_subscriptions.hlc.
        await _assertMediaSubscriptionsHlc();

        // v109 backstop (issue #553): re-assert the certifications.buddy_id
        // column ONLY. The one-time inline-cert data copy lives in the v109
        // onUpgrade block, not here -- re-running it every open would
        // resurrect a user-deleted buddy cert from the still-present inline
        // column (dropped in v110).
        await _assertCertificationBuddyOwnerColumn();

        // v111 backstop: re-assert equipment_sets.is_default + the
        // equipment_set_geofences table (parallel-branch collision self-heal).
        await _assertEquipmentSetDefaultAndGeofenceSchema();

        // v112 backstop: re-assert equipment.thickness column.
        await _assertEquipmentThicknessColumn();

        // v113 backstop: re-assert diver_settings.cns_calculation_method.
        await _assertCnsCalculationMethodColumn();

        // v114 backstop: re-assert sync_peer_cursors.applied_hlc_high and the
        // deletion_log unique index.
        final peerCursorCols = await customSelect(
          "PRAGMA table_info('sync_peer_cursors')",
        ).get();
        final hasAppliedHlcHigh = peerCursorCols.any(
          (c) => c.read<String>('name') == 'applied_hlc_high',
        );
        if (peerCursorCols.isNotEmpty && !hasAppliedHlcHigh) {
          await customStatement(
            'ALTER TABLE sync_peer_cursors ADD COLUMN applied_hlc_high TEXT',
          );
        }
        await ensureDeletionLogIndex();

        // v120 backstop: re-assert planner Subsurface-parity columns.
        await _assertPlannerParitySchema();

        // v121 backstop: course requirement tables (parallel-branch
        // collision self-heal; createTable is idempotent).
        await createMigrator().createTable(courseRequirements);
        await createMigrator().createTable(courseRequirementDives);

        // v122 backstop: re-assert service ledger schema + built-in kinds.
        // The legacy backfill is NOT here (onUpgrade only) -- re-running it
        // would resurrect user-deleted schedules.
        await _assertServiceLedgerSchema();

        // v123 backstop: re-assert safety review tables + settings columns
        // (parallel-branch collision self-heal).
        await _assertSafetyReviewSchema();

        // v124 backstop: re-assert the equipment_attributes table (schema
        // only -- the legacy-column copy must NOT run here, it would
        // resurrect attribute rows the user has cleared).
        await _assertEquipmentAttributesSchema();

        // v125 backstop: re-assert diver_settings.no_fly_preset.
        await _assertNoFlySettingsColumn();

        // v126 backstop: re-assert emergency card schema.
        await _assertEmergencyCardSchema();

        // v127 backstop: re-assert incidents table.
        await _assertIncidentsSchema();

        // v128 backstop: re-assert the pre-dive checklist tables and their
        // built-in templates (same rationale as the dive-types re-seed).
        await _assertPreDiveChecklistSchema();
        await _seedBuiltInPreDiveTemplates();

        // v129 backstop: re-assert quality_findings schema.
        await _assertQualityFindingsSchema();

        // v133 backstop: re-assert the deco stop band settings columns.
        await _assertDecoStopSettingsColumns();

        // Built-in dive types are reference data: identical on every device and
        // undeletable through DiveTypeRepository. Nothing else restores them --
        // the seed runs only in onCreate and the one-shot v93 step -- yet a
        // replace-adopt clears dive_types and refills from a payload that omits
        // built-ins, and a library copied from an already-empty device carries
        // the hole with it. Re-assert on every open, mirroring the built-in
        // species seed. INSERT OR IGNORE is idempotent, and the stable slug ids
        // are exactly what dive_dive_types references, so orphaned junction
        // rows resolve again.
        final diveTypesTable = await customSelect(
          "SELECT name FROM sqlite_master WHERE type='table' AND name='dive_types'",
        ).get();
        if (diveTypesTable.isNotEmpty) {
          await customStatement(kSeedBuiltInDiveTypesSql);
        }

        // Backstop for schema-version collisions (issue #395; same disease
        // as the v77/v82/v83 sync-branch incidents): a parallel branch build
        // that claims the same schema version can advance user_version past
        // the v99 block without creating its objects, and no later migration
        // would ever repair that. All DDL here is idempotent (createTable is
        // IF NOT EXISTS; the ALTER is PRAGMA-guarded), so re-assert the v99
        // objects on every open.
        final certCols = await customSelect(
          "PRAGMA table_info('certifications')",
        ).get();
        final hasInstructorId = certCols.any(
          (c) => c.read<String>('name') == 'instructor_id',
        );
        if (certCols.isNotEmpty && !hasInstructorId) {
          await customStatement(
            'ALTER TABLE certifications ADD COLUMN instructor_id TEXT '
            'REFERENCES buddies (id) ON DELETE SET NULL',
          );
        }
        await createMigrator().createTable(buddyRoles);

        // v100 backstop: re-assert the dive plan tables (same collision
        // disease; createTable is idempotent). Their indexes
        // (idx_dive_plan_tanks_plan_id / idx_dive_plan_segments_plan_id) are
        // in the canonical performance-index set and created by
        // ensurePerformanceIndexes below, so they are not re-declared here.
        await createMigrator().createTable(divePlans);
        await createMigrator().createTable(divePlanTanks);
        await createMigrator().createTable(divePlanSegments);

        // v103 backstop: dive_roles table + built-in seed + dives.diver_role
        // column (same collision disease; all DDL idempotent). The seed is
        // guarded on the divers FK parent existing, which only matters for
        // minimal test-fixture databases.
        await createMigrator().createTable(diveRoles);
        final diversParent = await customSelect(
          "SELECT name FROM sqlite_master "
          "WHERE type='table' AND name='divers'",
        ).get();
        if (diversParent.isNotEmpty) {
          await customStatement(kSeedBuiltInDiveRolesSql);
        }
        final divesCols = await customSelect(
          "PRAGMA table_info('dives')",
        ).get();
        final hasDiverRoleCol = divesCols.any(
          (c) => c.read<String>('name') == 'diver_role',
        );
        if (divesCols.isNotEmpty && !hasDiverRoleCol) {
          await customStatement('ALTER TABLE dives ADD COLUMN diver_role TEXT');
        }

        // v104 backstop: weight prediction tables + columns (same collision
        // disease; all DDL idempotent). Indexes for the new tables are in the
        // canonical performance-index set below.
        await createMigrator().createTable(diverWeightEntries);
        await createMigrator().createTable(divePlanEquipment);
        Future<void> addColumnIfMissing(
          String table,
          String column,
          String type,
        ) async {
          final cols = await customSelect("PRAGMA table_info('$table')").get();
          final has = cols.any((c) => c.read<String>('name') == column);
          if (cols.isNotEmpty && !has) {
            await customStatement(
              'ALTER TABLE $table ADD COLUMN $column $type',
            );
          }
        }

        await addColumnIfMissing('dives', 'weighting_feedback', 'TEXT');
        await addColumnIfMissing('dives', 'weighting_feedback_kg', 'REAL');
        await addColumnIfMissing('equipment', 'buoyancy_kg', 'REAL');
        await addColumnIfMissing('equipment', 'weight_kg', 'REAL');
        await addColumnIfMissing('dive_plans', 'planned_weight_kg', 'REAL');
        await addColumnIfMissing(
          'dive_plans',
          'planned_weight_placement',
          'TEXT',
        );

        // v105 backstop: heading column on dive_profiles.
        final profilesCols = await customSelect(
          "PRAGMA table_info('dive_profiles')",
        ).get();
        final hasHeadingCol = profilesCols.any(
          (c) => c.read<String>('name') == 'heading',
        );
        if (profilesCols.isNotEmpty && !hasHeadingCol) {
          await customStatement(
            'ALTER TABLE dive_profiles ADD COLUMN heading REAL',
          );
        }

        // Performance indexes historically existed only in onUpgrade blocks,
        // so a database created fresh at a recent schema version -- or
        // arriving via restore or sync-adopt -- never got them, and per-dive
        // child lookups degraded to full scans of million-row tables.
        // Re-assert the canonical set on every open (IF NOT EXISTS: free
        // after the first heal). ANALYZE runs inside only when something was
        // actually created.
        final createdIndexes = await ensurePerformanceIndexes(this);
        assert(() {
          if (createdIndexes.isNotEmpty) {
            developer.log(
              'Healed ${createdIndexes.length} performance indexes: '
              '${createdIndexes.join(', ')}',
              name: 'AppDatabase',
            );
          }
          return true;
        }());

        // Data self-heal: backfill a primary dive_data_sources row for dives
        // that have profile samples but no source row (legacy file imports).
        // Without it, the 3D/spatial/compare views spin forever on those dives.
        // Idempotent and local-only (deterministic ids, no HLC bump). Runs
        // AFTER ensurePerformanceIndexes so its per-dive EXISTS/NOT EXISTS
        // subqueries hit idx_dive_profiles_dive_id / idx_dive_data_sources_dive_id
        // instead of full-scanning million-row tables on a fresh/restored DB.
        await _backfillMissingDataSources();
      },
    );
  }
}
