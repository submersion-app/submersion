import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart'
    show BuddyWithRole;
import 'package:submersion/features/equipment/domain/entities/gear_provenance.dart';

/// Captured prior state for undoing one bulk edit. All collections are keyed by
/// diveId. A null map means that collection was not touched and must not be
/// restored.
///
/// Note: `Dive`, `DiveTank`, `DiveWeight`, `Sighting` here are the Drift row
/// classes (from database.dart), not the identically-named domain entities.
class BulkEditSnapshot {
  final List<Dive> priorDiveRows; // scalar + notes undo via row.toCompanion
  final Map<String, List<String>>? priorTagIds;
  final Map<String, List<String>>? priorDiveTypeIds;

  /// Prior gear rows with their provenance, restored exactly rather than
  /// re-expanded (issue #1487).
  final Map<String, List<GearProvenance>>? priorGear;
  final Map<String, List<BuddyWithRole>>? priorBuddies;
  final Map<String, List<DiveTank>>? priorTanks; // Drift DiveTanks rows

  /// Prior tank rows captured for a `TankSpecsOp`. Restored in place by row id
  /// rather than through [priorTanks]' delete-and-reinsert path, so undoing a
  /// spec update cannot destroy the pressure profiles the update preserved.
  final List<DiveTank>? priorTankSpecRows;

  final Map<String, List<DiveWeight>>? priorWeights; // Drift DiveWeights rows
  final Map<String, List<Sighting>>? priorSightings; // Drift Sightings rows

  const BulkEditSnapshot({
    required this.priorDiveRows,
    this.priorTagIds,
    this.priorDiveTypeIds,
    this.priorGear,
    this.priorBuddies,
    this.priorTanks,
    this.priorTankSpecRows,
    this.priorWeights,
    this.priorSightings,
  });
}
