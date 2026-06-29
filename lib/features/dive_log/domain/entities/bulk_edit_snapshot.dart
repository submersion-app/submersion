import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart'
    show BuddyWithRole;

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
  final Map<String, List<String>>? priorEquipmentIds;
  final Map<String, List<BuddyWithRole>>? priorBuddies;
  final Map<String, List<DiveTank>>? priorTanks; // Drift DiveTanks rows
  final Map<String, List<DiveWeight>>? priorWeights; // Drift DiveWeights rows
  final Map<String, List<Sighting>>? priorSightings; // Drift Sightings rows

  const BulkEditSnapshot({
    required this.priorDiveRows,
    this.priorTagIds,
    this.priorDiveTypeIds,
    this.priorEquipmentIds,
    this.priorBuddies,
    this.priorTanks,
    this.priorWeights,
    this.priorSightings,
  });
}
