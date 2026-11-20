import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/change_log/record_sitting_writer.dart';
import 'package:submersion/features/dive_centers/data/repositories/dive_center_repository.dart';
import 'package:submersion/features/dive_centers/domain/entities/dive_center.dart';
import 'package:submersion/features/dive_centers/presentation/providers/dive_center_providers.dart';

/// Writes a dive centre page's editing sitting (issue #4527, phase 3): the
/// centre's changed values and every held write, in one transaction and
/// one History entry labelled with the cards it changed.
class DiveCenterEditSaveService {
  DiveCenterEditSaveService(this._centers);

  final DiveCenterRepository _centers;

  /// Saves [apply] onto dive centre [centerId] as stored now, so a value
  /// changed underneath on a card the diver never touched is kept. The
  /// update writes neither when it was made nor whose it is. [alsoWrite]
  /// makes the held writes (rental notes, documents) after the row.
  /// Returns the centre before and after, or null when nothing changed.
  /// Throws [StateError] when the centre no longer exists.
  Future<({DiveCenter before, DiveCenter after})?> save({
    required String centerId,
    required DiveCenter Function(DiveCenter stored) apply,
    required Iterable<String> changedCardIds,
    Future<void> Function()? alsoWrite,
    bool alsoWriteIsAChange = false,
  }) => writeRecordSitting<DiveCenter>(
    table: 'dive_centers',
    recordId: centerId,
    changedCardIds: changedCardIds,
    read: () => _centers.getDiveCenterById(centerId),
    apply: apply,
    write: (_, merged) => _centers.updateDiveCenter(merged),
    alsoWrite: alsoWrite,
    alsoWriteIsAChange: alsoWriteIsAChange,
  );

  /// Creates [center], a new dive centre's sitting (issue #4527, phase 3,
  /// plan 11), keeping its id: the row, then [alsoWrite], the sitting's
  /// held writes (rental notes, documents), in one transaction and one
  /// History entry naming [changedCardIds]. If any of them throws nothing
  /// is left. Throws [StateError] when [center] has no id, or one a stored
  /// centre has.
  Future<DiveCenter> create({
    required DiveCenter center,
    required Iterable<String> changedCardIds,
    Future<void> Function()? alsoWrite,
  }) => createRecordSitting<DiveCenter>(
    table: 'dive_centers',
    recordId: center.id,
    changedCardIds: changedCardIds,
    isStored: () async => await _centers.getDiveCenterById(center.id) != null,
    insert: () => _centers.createDiveCenter(center),
    alsoWrite: alsoWrite,
    readBack: () => _centers.getDiveCenterById(center.id),
    created: center,
  );
}

final diveCenterEditSaveServiceProvider = Provider<DiveCenterEditSaveService>(
  (ref) => DiveCenterEditSaveService(ref.watch(diveCenterRepositoryProvider)),
);
