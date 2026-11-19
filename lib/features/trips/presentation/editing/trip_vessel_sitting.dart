import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/trips/data/repositories/liveaboard_details_repository.dart';
import 'package:submersion/features/trips/domain/entities/liveaboard_details.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/presentation/editing/trip_card_ids.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';
import 'package:submersion/shared/widgets/record_editing/sitting_list.dart';

/// A liveaboard's vessel details, held in the trip's sitting (issue #4527,
/// phase 3): none or one row, read from and written through [repository]
/// (the app's provider where there is one, so a test can stand in for it).
///
/// What the list holds lives in the sitting under its key, so every list
/// made by this function is the same list; the repository is only how it
/// reads and writes.
///
/// At Save the row is written while the trip is a liveaboard; a trip that
/// is one no longer loses its details in the trip's save service, whether
/// or not this list changed.
SittingList<Trip, LiveaboardDetails> tripVesselDetails([
  LiveaboardDetailsRepository? repository,
]) => _vesselList(repository ?? LiveaboardDetailsRepository());

SittingList<Trip, LiveaboardDetails> _vesselList(
  LiveaboardDetailsRepository repository,
) => SittingList<Trip, LiveaboardDetails>(
  key: 'trip.vessel',
  cardId: TripCardId.vessel.name,
  read: (trip) async {
    final details = await repository.getByTripId(trip.id);
    return [?details];
  },
  write: (trip, loaded, current) async {
    if (trip.tripType != TripType.liveaboard || current.isEmpty) return false;
    final row = current.single;
    if (loaded.isNotEmpty && loaded.single == row) return false;
    await repository.createOrUpdate(row);
    return true;
  },
);

/// The sitting's vessel, for what only reads it (the Vessel card's check,
/// the card itself while closed): what the list holds lives in the sitting,
/// so this copy sees what the page's holds, and it never reads or writes.
final tripVesselState = tripVesselDetails();

/// The details of a trip [tripId] that has none yet: an empty vessel name,
/// which the Vessel card asks for, and no id, so the repository gives it
/// one at Save.
LiveaboardDetails tripVesselDraft(String tripId, {DateTime? now}) {
  final at = now ?? DateTime.now();
  return LiveaboardDetails(
    id: '',
    tripId: tripId,
    vesselName: '',
    createdAt: at,
    updatedAt: at,
  );
}

/// The vessel the sitting holds for [session]'s trip: the diver's, else as
/// read; null before the read has answered or when there is none.
LiveaboardDetails? tripVesselInSitting(
  SittingList<Trip, LiveaboardDetails> list,
  EditSession<Trip> session,
) {
  final rows = list.current(session);
  return rows == null || rows.isEmpty ? null : rows.single;
}

/// Whether the trip in [session] can be saved as far as its vessel goes:
/// a liveaboard needs a vessel name, as the form required. A read that
/// failed refuses it, so a liveaboard is never saved past a vessel it could
/// not see (its card offers to read it again); one still running does not,
/// and the Save waits for it.
bool tripVesselValid(
  SittingList<Trip, LiveaboardDetails> list,
  EditSession<Trip> session,
) {
  if (session.working.tripType != TripType.liveaboard) return true;
  final rows = list.current(session);
  if (rows == null) return !list.failed(session);
  return rows.isNotEmpty && rows.single.vesselName.trim().isNotEmpty;
}
