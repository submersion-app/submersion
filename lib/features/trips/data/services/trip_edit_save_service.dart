import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/change_log/record_sitting_writer.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/trips/data/repositories/itinerary_day_repository.dart';
import 'package:submersion/features/trips/data/repositories/liveaboard_details_repository.dart';
import 'package:submersion/features/trips/data/repositories/trip_repository.dart';
import 'package:submersion/features/trips/domain/entities/itinerary_day.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/presentation/providers/liveaboard_providers.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';

const _log = LoggerService('TripEditSaveService');

/// Writes a trip page's editing sitting (issue #4527, phase 3): its changed
/// values and every held write, in one transaction and one History entry
/// labelled with the cards it changed.
class TripEditSaveService {
  TripEditSaveService(this._trips, this._days, this._vessels);

  final TripRepository _trips;
  final ItineraryDayRepository _days;
  final LiveaboardDetailsRepository _vessels;

  /// Saves [apply] onto trip [tripId] as stored now, so a value changed
  /// underneath on a card the diver never touched is kept.
  ///
  /// The trip's update checks the parent trip and drops foreign cylinder
  /// slot links when it changes; sharing changes only for the owner
  /// ([actingDiverId]). [alsoWrite] makes the held writes (sharing, the
  /// vessel, itinerary days, documents, dives assigned) after the row; with
  /// [alsoWriteIsAChange] they are written even when the row is unchanged.
  /// Then, in the same sitting, a trip that is no longer a liveaboard loses
  /// its vessel details, and the plan-only itinerary days outside its dates
  /// go, best effort, as the form's save dropped them.
  ///
  /// Returns the trip before and after, or null when nothing changed.
  /// Throws [StateError] when it no longer exists.
  Future<({Trip before, Trip after})?> save({
    required String tripId,
    required Trip Function(Trip stored) apply,
    required Iterable<String> changedCardIds,
    required String? actingDiverId,
    Future<void> Function()? alsoWrite,
    bool alsoWriteIsAChange = false,
  }) async {
    ({Trip stored, Trip merged})? written;
    final result = await writeRecordSitting<Trip>(
      table: 'trips',
      recordId: tripId,
      changedCardIds: changedCardIds,
      read: () => _trips.getTripById(tripId),
      apply: apply,
      write: (stored, merged) async {
        written = (stored: stored, merged: merged);
        await _trips.updateTrip(
          merged,
          actingDiverId: actingDiverId,
          dropBarePlanDays: false,
        );
      },
      alsoWrite: () async {
        await alsoWrite?.call();
        await _tidy(written, tripId);
      },
      alsoWriteIsAChange: alsoWriteIsAChange,
    );
    return result;
  }

  /// Creates [trip], a new trip's sitting (issue #4527, phase 3, plan 11),
  /// keeping its id: the row (its parent checked inside, as the form's
  /// create checks it), then [alsoWrite], the sitting's held writes
  /// (sharing, the vessel, itinerary days, documents, the dives chosen at
  /// Save), then the dives of a trip made from selected ones
  /// ([draftDiveIds]), then a liveaboard's days, generated as the form
  /// generated them when the sitting held none, over the dates the dives
  /// may have stretched it to, all in one transaction and one History
  /// entry naming [changedCardIds]. If any of them throws nothing is left,
  /// and the dives stay on their trips. Throws [StateError] when [trip] has
  /// no id, or one a stored trip has.
  Future<Trip> create({
    required Trip trip,
    required Iterable<String> changedCardIds,
    List<String> draftDiveIds = const [],
    Future<void> Function()? alsoWrite,
  }) => createRecordSitting<Trip>(
    table: 'trips',
    recordId: trip.id,
    changedCardIds: changedCardIds,
    isStored: () async => await _trips.getTripById(trip.id) != null,
    insert: () => _trips.createTrip(trip),
    alsoWrite: () async {
      await alsoWrite?.call();
      await _trips.assignDivesToTrip(draftDiveIds, trip.id);
      // From the dates as stored now: a dive assigned outside them has
      // stretched the trip to cover it.
      final stored = await _trips.getTripById(trip.id) ?? trip;
      if (stored.tripType == TripType.liveaboard &&
          (await _days.getByTripId(trip.id)).isEmpty) {
        await _days.saveAll(
          ItineraryDay.generateForTrip(
            tripId: trip.id,
            startDate: stored.startDate,
            endDate: stored.endDate,
          ),
        );
      }
    },
    readBack: () => _trips.getTripById(trip.id),
    created: trip,
  );

  /// What the trip's new values leave behind: the vessel of a liveaboard
  /// that is one no longer, and plan-only days outside its dates. [written]
  /// is null when the sitting left the trip's own row as it was.
  Future<void> _tidy(({Trip stored, Trip merged})? written, String id) async {
    final trip = written?.merged ?? await _trips.getTripById(id);
    if (trip == null) return;
    if (written != null &&
        written.stored.tripType == TripType.liveaboard &&
        trip.tripType != TripType.liveaboard) {
      await _vessels.deleteByTripId(trip.id);
    }
    try {
      await _days.deleteBarePlanDaysOutside(
        trip.id,
        trip.startDate,
        trip.endDate,
      );
    } catch (e, stackTrace) {
      // Cleanup only, as the form's save treated it: the trip is saved.
      _log.error(
        'Failed to drop plan-only itinerary days for trip: ${trip.id}',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }
}

final tripEditSaveServiceProvider = Provider<TripEditSaveService>(
  (ref) => TripEditSaveService(
    ref.watch(tripRepositoryProvider),
    ref.watch(itineraryDayRepositoryProvider),
    ref.watch(liveaboardDetailsRepositoryProvider),
  ),
);
