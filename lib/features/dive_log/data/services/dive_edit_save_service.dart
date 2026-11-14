import 'package:submersion/core/database/database.dart' hide Dive;
import 'package:submersion/core/services/change_log/change_log_scope.dart';
import 'package:submersion/core/services/change_log/record_edit_label.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

/// Saves one editing sitting on a dive (issue #4527).
///
/// The diver's changes are applied to the dive as it is stored at the moment
/// of saving, not as it was when the sitting began, so a value changed
/// underneath meanwhile (a sync, a download) on a card the diver never
/// touched is not written back over. Everything is written in one database
/// transaction, so a failure leaves nothing half saved, and in one change
/// log operation, so the sitting is one History entry that reverts as a
/// unit.
class DiveEditSaveService {
  DiveEditSaveService(this._diveRepo);

  final DiveRepository _diveRepo;

  AppDatabase get _db => DatabaseService.instance.database;

  /// Applies [apply] to the dive as stored now and writes the result.
  ///
  /// [changedCardIds] names the cards the sitting changed, for its History
  /// label. Returns the dive before and after, or null when [apply] changed
  /// nothing. Throws [StateError] when the dive no longer exists.
  Future<({Dive before, Dive after})?> save({
    required String diveId,
    required Dive Function(Dive stored) apply,
    required Iterable<String> changedCardIds,
  }) {
    // The scope goes outside the transaction it covers, as its own contract
    // requires. An operation that ends with no events is removed when the
    // log settles, so returning early below leaves nothing behind.
    return ChangeLogScope.run(
      DatabaseService.instance.databaseOrNull,
      source: ChangeLogSource.manual,
      label: RecordEditLabel.encode(table: 'dives', cardIds: changedCardIds),
      body: () => _db.transaction(() async {
        final stored = await _diveRepo.getDiveById(diveId);
        if (stored == null) {
          throw StateError('Dive $diveId no longer exists');
        }
        final merged = apply(stored);
        if (merged == stored) return null;
        await _diveRepo.updateDive(merged);
        return (before: stored, after: merged);
      }),
    );
  }
}
