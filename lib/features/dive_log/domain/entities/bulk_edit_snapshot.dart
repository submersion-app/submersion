import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart'
    show BuddyWithRole;
import 'package:submersion/features/equipment/domain/entities/gear_provenance.dart';

/// Captured prior state for undoing one bulk edit. The maps are keyed by
/// diveId; the tank fields are not, because a tank's undo matches on row id. A
/// null field means that collection was not touched and must not be restored.
///
/// Note: `Dive`, `DiveTank`, `DiveWeight`, `Sighting`, `GasSwitche` and
/// `TankPressureSeriesRow` here are the Drift row classes (from database.dart),
/// not the identically-named domain entities.
class BulkEditSnapshot {
  final List<Dive> priorDiveRows; // scalar + notes undo via row.toCompanion
  final Map<String, List<String>>? priorTagIds;
  final Map<String, List<String>>? priorDiveTypeIds;

  /// Each dive's courses before a `DiveCoursesOp` (#2515).
  final Map<String, List<String>>? priorCourseIds;

  /// Prior gear rows with their provenance, restored exactly rather than
  /// re-expanded (issue #1487).
  final Map<String, List<GearProvenance>>? priorGear;
  final Map<String, List<BuddyWithRole>>? priorBuddies;

  /// Each dive's resolved diver role set before a `DiverRolesOp` (#1221).
  final Map<String, List<String>>? priorDiverRoleIds;

  /// What undoing a `TanksOp` removes and puts back. Null when no `TanksOp`
  /// ran.
  final BulkTankUndo? tankUndo;

  /// Prior tank rows captured for a `TankSpecsOp`. Restored in place by row id,
  /// so undoing a spec update cannot touch the pressure profiles the update
  /// preserved.
  final List<DiveTank>? priorTankSpecRows;

  final Map<String, List<DiveWeight>>? priorWeights; // Drift DiveWeights rows
  final Map<String, List<Sighting>>? priorSightings; // Drift Sightings rows

  const BulkEditSnapshot({
    required this.priorDiveRows,
    this.priorTagIds,
    this.priorDiveTypeIds,
    this.priorCourseIds,
    this.priorGear,
    this.priorBuddies,
    this.priorDiverRoleIds,
    this.tankUndo,
    this.priorTankSpecRows,
    this.priorWeights,
    this.priorSightings,
  });
}

/// How to reverse a `TanksOp`, tank by tank rather than by rebuilding each
/// dive's list: rebuilding deletes the dive's tanks, and the foreign keys take
/// their recorded pressure series and gas switches with them (#3929).
class BulkTankUndo {
  /// The tanks the edit created, in any mode. Undo removes exactly these, so
  /// a tank that was already there or arrived later is left alone.
  final List<String> createdTankIds;

  /// The tanks a replace deleted. An add deletes nothing, so this and the two
  /// lists below stay empty for one.
  final List<DiveTank> replacedTanks;

  /// The series [replacedTanks]' delete cascaded away.
  final List<TankPressureSeriesRow> replacedPressureSeries;

  /// The gas switches [replacedTanks]' delete cascaded away.
  final List<GasSwitche> replacedGasSwitches;

  const BulkTankUndo({
    this.createdTankIds = const [],
    this.replacedTanks = const [],
    this.replacedPressureSeries = const [],
    this.replacedGasSwitches = const [],
  });

  BulkTankUndo copyWith({
    List<String>? createdTankIds,
    List<DiveTank>? replacedTanks,
    List<TankPressureSeriesRow>? replacedPressureSeries,
    List<GasSwitche>? replacedGasSwitches,
  }) => BulkTankUndo(
    createdTankIds: createdTankIds ?? this.createdTankIds,
    replacedTanks: replacedTanks ?? this.replacedTanks,
    replacedPressureSeries:
        replacedPressureSeries ?? this.replacedPressureSeries,
    replacedGasSwitches: replacedGasSwitches ?? this.replacedGasSwitches,
  );
}
