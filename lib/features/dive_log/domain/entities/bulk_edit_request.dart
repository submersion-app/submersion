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
///
/// [update] edits the rows a dive already has instead of inserting or deleting
/// any. Only tanks support it today (see [TankSpecsOp]); every other collection
/// rejects it, the same way owned collections reject [remove].
enum BulkCollectionMode { add, remove, replace, update }

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

class DiveTypesOp extends BulkCollectionOp {
  final BulkCollectionMode mode; // add | remove | replace
  final List<String> diveTypeIds;
  const DiveTypesOp({required this.mode, required this.diveTypeIds});
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

  /// Add mode only: whether each entry's role replaces the role on links that
  /// already exist. False for a membership-only add, where the user asked for
  /// the buddy on every dive but never touched their role (#893).
  final bool overwriteRole;

  const BuddiesOp({
    required this.mode,
    required this.buddies,
    this.overwriteRole = true,
  });
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

/// One editable attribute of a cylinder, used as a field mask by [TankSpecsOp].
///
/// Start and end pressure are deliberately absent: the whole point of an
/// in-place spec update is that measured pressure data survives it (#797).
/// [gasMix] covers the o2 and he columns together, since a mix is meaningless
/// split in half.
enum TankSpecField {
  preset,
  role,
  volume,
  workingPressure,
  material,
  gasMix,
  name,
}

/// Overwrite selected attributes of the tanks each dive already has, leaving
/// every other column (start/end pressure above all) as it was.
///
/// Unlike [TanksOp] this carries a field mask rather than a list of tanks:
/// [specs] is a template whose values are read only for the fields named in
/// [fields]. Dives with no tanks are skipped; nothing is inserted or deleted,
/// so tank_pressure_profiles and gas_switches keep their rows.
class TankSpecsOp extends BulkCollectionOp {
  final DiveTank specs;
  final Set<TankSpecField> fields;
  const TankSpecsOp({required this.specs, required this.fields});
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
