import 'package:submersion/core/database/database.dart' hide Dive;
import 'package:submersion/core/services/change_log/change_log_scope.dart';
import 'package:submersion/core/services/change_log/record_edit_label.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/trips/data/repositories/trip_repository.dart';
import 'package:submersion/features/trips/domain/services/trip_date_stretch.dart';

/// Saves one editing sitting on a dive (issue #4527).
///
/// The diver's changes are applied to the dive as it is stored at the moment
/// of saving, not as it was when the sitting began, so a value changed
/// underneath meanwhile (a sync, a download) on a card the diver never
/// touched is not written back over. Everything is written in one database
/// transaction, so a failure leaves nothing half saved, and in one change
/// log operation, so the sitting is one History entry that reverts as a
/// unit.
///
/// A sitting that puts the dive on a trip, or moves it to another day on
/// one, stretches that trip's dates to cover it (issue #3351). That is
/// written with the sitting too, so the trip's dates move with the dive or
/// not at all.
class DiveEditSaveService {
  DiveEditSaveService(this._diveRepo, this._tripRepo);

  final DiveRepository _diveRepo;
  final TripRepository _tripRepo;

  AppDatabase get _db => DatabaseService.instance.database;

  /// Applies [apply] to the dive as stored now and writes the result.
  ///
  /// [changedCardIds] names the cards the sitting changed, for its History
  /// label. Returns the dive before and after, with the trips whose dates
  /// moved to cover it, or null when [apply] changed nothing. Throws
  /// [StateError] when the dive no longer exists.
  ///
  /// [alsoWrite] makes the sitting's writes to other records (an altitude
  /// copied back to the dive's site). It runs after the dive is written, in
  /// the same transaction and History entry, so if it throws the dive and
  /// its trip are left as they were. It is not called when [apply] changed
  /// nothing.
  Future<({Dive before, Dive after, List<TripDateStretch> tripDateStretches})?>
  save({
    required String diveId,
    required Dive Function(Dive stored) apply,
    required Iterable<String> changedCardIds,
    Future<void> Function()? alsoWrite,
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
        // Only a save that touched the trip moves its dates: a dive saved
        // for something else leaves a trip it sits outside of alone, so a
        // date the diver set by hand is never reopened.
        final touchesTrip = diveSaveTouchesTrip(
          tripId: merged.tripId ?? merged.trip?.id,
          previousTripId: stored.tripId ?? stored.trip?.id,
          date: merged.effectiveEntryTime,
          previousDate: stored.effectiveEntryTime,
        );
        final stretches = touchesTrip
            ? await _tripRepo.stretchToCoverDives([diveId])
            : const <TripDateStretch>[];
        await alsoWrite?.call();
        return (before: stored, after: merged, tripDateStretches: stretches);
      }),
    );
  }
}
