import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/trips/data/repositories/trip_repository.dart';
import 'package:submersion/features/trips/domain/entities/dive_candidate.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/presentation/editing/trip_card_ids.dart';
import 'package:submersion/features/trips/presentation/editing/trip_photos_sitting.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

/// The held change of the Dives card: the dives Scan for dives chose.
const String _scannedKey = 'trip.scannedDives';
const String _noteKey = 'trip.scannedDives.held';

/// The dives a scan chose in a trip's sitting, and the trips they were on.
typedef TripScannedDives = ({List<Dive> dives, Set<String> oldTripIds});

/// The dives Scan for dives added to the trip in [session], in the order
/// chosen; empty when none.
TripScannedDives scannedDivesOf(EditSession<Trip> session) =>
    (session.isDisposed ? null : session.recall<TripScannedDives>(_noteKey)) ??
    (dives: const <Dive>[], oldTripIds: const <String>{});

/// Holds [chosen] (of a scan's [candidates]) as dives the trip's Save
/// assigns to it through [trips], in its transaction and History entry
/// (issue #4527). A dive held already is not held twice.
void holdScannedDives(
  EditSession<Trip> session,
  TripRepository trips,
  List<DiveCandidate> candidates,
  List<String> chosen,
) {
  final held = scannedDivesOf(session);
  final have = {for (final d in held.dives) d.id};
  final picked = chosen.toSet();
  final added = [
    for (final c in candidates)
      if (picked.contains(c.dive.id) && have.add(c.dive.id)) c,
  ];
  _set(session, trips, (
    dives: [...held.dives, for (final c in added) c.dive],
    oldTripIds: {
      ...held.oldTripIds,
      for (final c in added)
        if (!c.isUnassigned) c.currentTripId!,
    },
  ));
}

/// Takes [diveId], a dive the scan added in this sitting, back off, with
/// the photos the sitting holds for it.
void takeOutScannedDive(
  EditSession<Trip> session,
  TripRepository trips,
  String diveId,
) {
  takeOutHeldPhotosOfDive(session, diveId);
  final held = scannedDivesOf(session);
  _set(session, trips, (
    dives: [
      for (final d in held.dives)
        if (d.id != diveId) d,
    ],
    oldTripIds: held.oldTripIds,
  ));
}

void _set(
  EditSession<Trip> session,
  TripRepository trips,
  TripScannedDives next,
) {
  if (session.isDisposed || session.isFrozen) return;
  if (next.dives.isEmpty) {
    session
      ..remember(_noteKey, null)
      ..releaseWrite(_scannedKey);
    return;
  }
  final ids = [for (final d in next.dives) d.id];
  final tripId = session.stored.id;
  session
    ..remember(_noteKey, next)
    ..holdChange(
      _scannedKey,
      cardId: TripCardId.dives.name,
      write: () => trips.assignDivesToTrip(ids, tripId),
    );
}
