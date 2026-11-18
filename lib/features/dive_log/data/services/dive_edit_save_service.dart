import 'package:drift/drift.dart' show Variable;
import 'package:submersion/core/database/database.dart' hide Dive;
import 'package:submersion/core/services/change_log/record_sitting_writer.dart';
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
  /// nothing, unless [alsoWriteIsAChange]: the sitting's only change is a
  /// write of its own (a dismissed suggestion, a location added to the
  /// site), and the dive comes back as it was before and after.
  ///
  /// [writeFirst] makes the sitting's writes that need rows the dive's own
  /// write may delete (readings moved between two cylinders, one of which
  /// the sitting removes). It runs before the dive is written, in the same
  /// transaction and History entry, and counts as a change as [alsoWrite]
  /// does.
  Future<({Dive before, Dive after, List<TripDateStretch> tripDateStretches})?>
  save({
    required String diveId,
    required Dive Function(Dive stored) apply,
    required Iterable<String> changedCardIds,
    Future<void> Function()? writeFirst,
    Future<void> Function()? alsoWrite,
    bool alsoWriteIsAChange = false,
  }) {
    var stretches = const <TripDateStretch>[];
    final written = writeRecordSitting<Dive>(
      table: 'dives',
      recordId: diveId,
      changedCardIds: changedCardIds,
      read: () => _diveRepo.getDiveById(diveId),
      apply: apply,
      write: (stored, merged) async {
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
        if (touchesTrip) {
          stretches = await _tripRepo.stretchToCoverDives([diveId]);
        }
      },
      writeFirst: writeFirst,
      alsoWrite: alsoWrite,
      alsoWriteIsAChange: alsoWriteIsAChange,
    );
    return written.then(
      (result) => result == null
          ? null
          : (
              before: result.before,
              after: result.after,
              tripDateStretches: stretches,
            ),
    );
  }

  /// Creates [dive], the working copy of a new dive's sitting (issue #4527,
  /// plan 8), under its own id.
  ///
  /// In one transaction and one change log operation, as [save] writes an
  /// existing dive: the dive, its number when it has none and is neither
  /// planned nor a draft (as [PaginatedDiveListNotifier.addDive] numbers
  /// one), its trip's dates stretched to cover it, then [alsoWrite], the
  /// sitting's held writes, which all point at the dive. A dive with no
  /// diver goes to [activeDiverId], the diver active at Save, as addDive
  /// gives it one, so its numbering is that diver's. If any of them
  /// throws nothing is left. Returns the dive as stored at the end, with
  /// the trips whose dates moved. Throws [StateError] when [dive] has no id
  /// or one a stored dive already has.
  Future<({Dive after, List<TripDateStretch> tripDateStretches})> create({
    required Dive dive,
    required Iterable<String> changedCardIds,
    Future<void> Function()? alsoWrite,
    String? activeDiverId,
  }) {
    if (dive.id.isEmpty) {
      return Future.error(
        StateError('A new dive needs its id before it is created'),
      );
    }
    return runRecordSitting(
      table: 'dives',
      recordId: dive.id,
      changedCardIds: changedCardIds,
      body: () async {
        final taken = await _db
            .customSelect(
              'SELECT 1 FROM dives WHERE id = ?',
              variables: [Variable<String>(dive.id)],
            )
            .getSingleOrNull();
        if (taken != null) {
          throw StateError('Dive ${dive.id} already exists');
        }
        final created = await _diveRepo.createDive(
          dive.diverId == null && activeDiverId != null
              ? dive.copyWith(diverId: activeDiverId)
              : dive,
        );
        // A planned dive stays unnumbered until it is logged (issue #2002).
        if (dive.diveNumber == null && !dive.isPlanned && !dive.isDraft) {
          await _diveRepo.assignMissingDiveNumbers(diverId: created.diverId);
        }
        final stretches = (created.tripId ?? created.trip?.id) == null
            ? const <TripDateStretch>[]
            : await _tripRepo.stretchToCoverDives([created.id]);
        await alsoWrite?.call();
        // Read back rather than trusting the copy createDive returns: the
        // write drops what it cannot store (a slot of another trip) and the
        // numbering may have given it a number.
        final after = await _diveRepo.getDiveById(created.id);
        return (after: after ?? created, tripDateStretches: stretches);
      },
    );
  }
}
