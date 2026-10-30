/// Saved dive plans.
library;

// Table classes are pure drift DSL. build_runner reads the column
// getter bodies to generate the `$<Table>Table` subclasses, whose
// fields override the getters, so the bodies never run and no test
// can cover them.
// coverage:ignore-file

import 'package:drift/drift.dart';

import 'package:submersion/core/database/tables/dive_tables.dart';
import 'package:submersion/core/database/tables/diver_tables.dart';
import 'package:submersion/core/database/tables/equipment_tables.dart';
import 'package:submersion/core/database/tables/site_tables.dart';

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

  /// Custom salinity in ppt. When set, deco uses this instead of [waterType].
  RealColumn get salinityPpt => real().nullable()();

  /// Null = use the diver's Settings default (issue #3552).
  IntColumn get gfLow => integer().nullable()();
  IntColumn get gfHigh => integer().nullable()();

  /// Null = use the diver's Settings default (issue #3552).
  RealColumn get descentRate => real().nullable()();

  /// Null = use the diver's Settings default (issue #3552).
  RealColumn get ascentRate => real().nullable()();

  /// Ascent rate between intermediate (deeper than 9 m) stops, m/min. Null =
  /// use the diver's Settings default (issue #3552).
  RealColumn get intermediateAscentRate => real().nullable()();

  /// Ascent rate between shallow (9 m and above) stops, m/min. Null = use
  /// the diver's Settings default (issue #3552).
  RealColumn get shallowAscentRate => real().nullable()();

  /// Ascent rate from the last stop to the surface, m/min. Null = use the
  /// diver's Settings default (issue #3552).
  RealColumn get finalAscentRate => real().nullable()();

  /// Null = use the diver's Settings default (issue #3552).
  RealColumn get lastStopDepth => real().nullable()();

  /// Null = use the diver's Settings default (issue #3552).
  IntColumn get gasSwitchStopSeconds => integer().nullable()();

  /// Air-break policy; both null and [airBreaksExplicitlyOff] false = use
  /// the diver's Settings default (issue #3552).
  IntColumn get airBreakO2Seconds => integer().nullable()();
  IntColumn get airBreakBreakSeconds => integer().nullable()();

  /// True = no air breaks for this plan regardless of the diver's Settings
  /// default (issue #3552).
  BoolColumn get airBreaksExplicitlyOff =>
      boolean().withDefault(const Constant(false))();

  /// Null = use the diver's Settings default (issue #3552).
  RealColumn get sacBottom => real().nullable()();

  /// Null = use the diver's Settings default (issue #3552).
  RealColumn get sacDeco => real().nullable()();

  /// Null = derive from sacBottom and the diver's Settings stressed-SAC
  /// factor (issue #3552).
  RealColumn get sacStressed => real().nullable()();

  /// Null = use the diver's Settings default (issue #3552).
  RealColumn get reservePressure => real().nullable()();
  IntColumn get surfaceIntervalSeconds => integer().nullable()();

  /// CCR setpoints (Phase 4 UI; persisted now to avoid a later migration).
  RealColumn get setpointLow => real().nullable()();
  RealColumn get setpointHigh => real().nullable()();
  RealColumn get setpointSwitchDepth => real().nullable()();

  /// Contingency config (Phase 5 UI). Null = use the diver's Settings
  /// default (issue #3552).
  RealColumn get deviationDepthDelta => real().nullable()();
  IntColumn get deviationTimeMinutes => integer().nullable()();

  /// TurnPressureRule enum name; null = use the diver's Settings default
  /// (issue #3552). `"off"` is the explicit "no tracking" choice.
  TextColumn get turnPressureRule => text().nullable()();
  RealColumn get turnPressureFraction => real().nullable()();

  /// Accepted weight prediction snapshot (v104). Placement is a JSON object
  /// keyed by WeightType.name -> kg.
  RealColumn get plannedWeightKg => real().nullable()();
  TextColumn get plannedWeightPlacement => text().nullable()();

  /// Diver-authored minimum stop hold times (replan-this-dive feature). JSON
  /// object keyed by whole-metre stop depth (string, JSON object keys must
  /// be strings) -> seconds; null = no minimums set.
  TextColumn get stopMinimumsJson => text().nullable()();

  /// Gas options (Subsurface parity). See [DivePlan.sacFactor] and siblings
  /// for the semantics of each field. Null = use the diver's Settings
  /// default (issue #3552).
  RealColumn get sacFactor => real().nullable()();
  IntColumn get problemSolvingMinutes => integer().nullable()();
  RealColumn get ppO2Bottom => real().nullable()();
  RealColumn get ppO2Deco => real().nullable()();

  /// Per-O2-band deco ppO2 ceilings for this plan (issue #3580, v319). Null
  /// = use the diver's Settings band. A non-null value is itself a Custom
  /// opt-in for this plan and takes effect even when the diver's Settings
  /// band toggle is off (issue #3580 follow-up, see
  /// `resolveDecoLayerEnabled`), unless [ppO2DecoBandsExplicitlyOff] forces
  /// band mode off for this plan regardless.
  RealColumn get ppO2DecoBand1 => real().nullable()();
  RealColumn get ppO2DecoBand2 => real().nullable()();
  RealColumn get ppO2DecoBand3 => real().nullable()();

  /// True = this plan never uses per-band deco ppO2 limits, regardless of
  /// the diver's Settings band toggle (issue #3580, v321).
  BoolColumn get ppO2DecoBandsExplicitlyOff =>
      boolean().withDefault(const Constant(false))();

  /// Explicit MOD for 100% O2 for this plan (issue #3580, v319). Null = use
  /// the diver's Settings value.
  RealColumn get maxO2DepthMeters => real().nullable()();

  /// True = this plan never uses an explicit MOD for 100% O2, regardless of
  /// the diver's Settings toggle (issue #3580, v321).
  BoolColumn get maxO2DepthExplicitlyOff =>
      boolean().withDefault(const Constant(false))();

  /// Hypercapnia-bailout overrides for this plan (issue #3743, v322). Null
  /// = derive from this plan's own base SAC and the diver's Settings
  /// hypercapnia factor/duration.
  RealColumn get hypercapniaAmv => real().nullable()();
  IntColumn get hypercapniaMinutes => integer().nullable()();

  /// True = this plan's OC bailout never uses a hypercapnia phase,
  /// regardless of the diver's Settings toggle (issue #3743, v322).
  BoolColumn get hypercapniaExplicitlyOff =>
      boolean().withDefault(const Constant(false))();
  RealColumn get bestMixEndMeters => real().nullable()();
  BoolColumn get o2Narcotic => boolean().nullable()();

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

  /// MOD set by hand in meters, for any role (issue #3567); null means the
  /// default for the cylinder's role and mix. The planner switches to the
  /// gas at its MOD. Subsurface per-cylinder "Deco switch at" (v120).
  RealColumn get decoSwitchDepth => real().nullable()();

  /// Whether this cylinder also doubles as travel gas, breathed on the
  /// descent before switching to its primary role's gas (v156).
  BoolColumn get isTravelGas => boolean().withDefault(const Constant(false))();
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

  /// Whether the profile chart and the deco computation split this segment
  /// into travel (at the plan's configured descent/ascent rate) followed by
  /// a hold at the target depth for whatever duration remains, instead of
  /// stretching the whole entered duration linearly across the depth change
  /// (v290, issue #3264). The segment itself is unchanged either way -- one
  /// row in the list, one authored duration; this only changes how that
  /// duration is read.
  BoolColumn get splitAtConfiguredRate =>
      boolean().withDefault(const Constant(false))();
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

/// Junction: equipment attached to a saved dive plan (v104).
class DivePlanEquipment extends Table {
  TextColumn get planId =>
      text().references(DivePlans, #id, onDelete: KeyAction.cascade)();
  TextColumn get equipmentId =>
      text().references(Equipment, #id, onDelete: KeyAction.cascade)();

  /// Provenance (issue #1487): the immediate parent assembly this row was
  /// attached through, null for a top-level row. SET NULL on delete so the
  /// part stays on the plan as flat gear when its assembly is deleted.
  TextColumn get viaEquipmentId => text().nullable().references(
    Equipment,
    #id,
    onDelete: KeyAction.setNull,
  )();

  /// The equipment set that was applied, carried by every row of the
  /// expanded subtree; null when the row was added by hand.
  TextColumn get viaSetId => text().nullable().references(
    EquipmentSets,
    #id,
    onDelete: KeyAction.setNull,
  )();

  /// The sync merge's age signal for this link; see [DiveEquipment.updatedAt]
  /// for why the junctions need one (issue #1728).
  IntColumn get updatedAt => integer().nullable().clientDefault(
    () => DateTime.now().millisecondsSinceEpoch,
  )();

  @override
  Set<Column> get primaryKey => {planId, equipmentId};

  /// v210: this child's own clock, stamped when it is marked pending. The
  /// merge refuses a remote copy strictly older than the local one, so a
  /// stale full row from a peer cannot overwrite a newer local edit
  /// (SyncDataSerializer.parentGatedChildEntities).
  TextColumn get hlc => text().nullable()();
}
