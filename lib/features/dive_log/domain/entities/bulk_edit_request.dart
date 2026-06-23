import 'package:submersion/core/database/database.dart' show DivesCompanion;
import 'package:submersion/features/buddies/domain/entities/buddy.dart'
    show BuddyWithRole;
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    show DiveTank;
import 'package:submersion/features/dive_log/domain/entities/dive_weight.dart'
    show DiveWeight;
import 'package:submersion/features/marine_life/domain/entities/species.dart'
    show Sighting;

/// How a collection edit is applied across the selected dives.
enum BulkCollectionMode { add, remove, replace }

/// One collection mutation in a bulk edit. Sealed so the service can switch
/// over every variant exhaustively.
sealed class BulkCollectionOp {
  const BulkCollectionOp();
}

class TagsOp extends BulkCollectionOp {
  final BulkCollectionMode mode;
  final List<String> tagIds;
  const TagsOp({required this.mode, required this.tagIds});
}

class EquipmentOp extends BulkCollectionOp {
  final BulkCollectionMode mode;
  final List<String> equipmentIds;
  const EquipmentOp({required this.mode, required this.equipmentIds});
}

class BuddiesOp extends BulkCollectionOp {
  final BulkCollectionMode mode;
  // For remove, the buddy ids are read from each entry's .buddy.id.
  final List<BuddyWithRole> buddies;
  const BuddiesOp({required this.mode, required this.buddies});
}

class TanksOp extends BulkCollectionOp {
  final BulkCollectionMode mode; // add | replace
  final List<DiveTank> tanks;
  final bool onlyIfEmpty;
  const TanksOp({
    required this.mode,
    required this.tanks,
    this.onlyIfEmpty = false,
  });
}

class WeightsOp extends BulkCollectionOp {
  final BulkCollectionMode mode; // add | replace
  final List<DiveWeight> weights;
  const WeightsOp({required this.mode, required this.weights});
}

class SightingsOp extends BulkCollectionOp {
  final BulkCollectionMode mode; // add | replace
  final List<Sighting> sightings;
  const SightingsOp({required this.mode, required this.sightings});
}

/// A single bulk edit: a partial scalar companion (only enabled columns are
/// present), an optional notes-append, and zero or more collection ops.
class BulkEditRequest {
  final List<String> diveIds;
  final DivesCompanion scalars;
  final String? notesAppend;
  final List<BulkCollectionOp> ops;

  const BulkEditRequest({
    required this.diveIds,
    this.scalars = const DivesCompanion(),
    this.notesAppend,
    this.ops = const [],
  });

  /// True when at least one column of [scalars] is present (non-absent).
  bool get hasScalarChanges => scalars.toColumns(false).isNotEmpty;
}
