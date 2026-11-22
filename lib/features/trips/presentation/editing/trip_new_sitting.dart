import 'package:clock/clock.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/data/visibility/item_sharing.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/divers/presentation/providers/new_record_diver.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/domain/services/trip_draft.dart';
import 'package:submersion/features/trips/presentation/editing/trip_card_ids.dart';
import 'package:submersion/features/trips/presentation/editing/trip_edit_fields.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';
import 'package:submersion/shared/widgets/record_editing/record_creating.dart';

const _log = LoggerService('TripNewSitting');

/// A new trip's starting record under [id] (issue #4527, phase 3, plan 11,
/// call 4): the active diver's, a shore trip from now to seven days on, as
/// the form started one, shared as every new trip is. A diver or default
/// that cannot be read leaves none, as the form did.
Future<Trip> newTripSeed(RecordSeedRead read, {required String id}) async {
  final diverId = await newRecordDiverId(read, record: 'trip');
  var shared = false;
  try {
    shared = await read(shareByDefaultProvider.future);
  } catch (error, stackTrace) {
    _log.warning(
      'No sharing default for a new trip',
      error: error,
      stackTrace: stackTrace,
    );
  }
  // Read once, as the form read it: two reads could straddle midnight.
  final now = clock.now();
  return Trip(
    id: id,
    diverId: diverId,
    name: '',
    startDate: now,
    endDate: now.copyWith(day: now.day + 7),
    isShared: shared,
    createdAt: now,
    updatedAt: now,
  );
}

/// Who a new trip [seed] starts shared with: everyone or no one, as its
/// sharing default gave it.
ItemSharing newTripSharing(Trip seed) =>
    seed.isShared ? ItemSharing.all : ItemSharing.none;

/// The cards a new trip opens with: the header block and Notes, and a
/// liveaboard's Vessel.
List<String> newTripLaidOut(Trip working) => [
  TripCardId.header.name,
  if (working.tripType == TripType.liveaboard) TripCardId.vessel.name,
  TripCardId.notes.name,
];

/// Puts what a trip made from selected dives ([draft]) suggests on
/// [session], each through the header block's field, so each is a change:
/// its name, dates, location, resort and larger trip. The dives themselves
/// are assigned at Save (plan 11, Question 7).
void applyNewTripPrefill(EditSession<Trip> session, TripDraft? draft) {
  final trip = draft?.trip;
  if (trip == null || session.isDisposed || session.isFrozen) return;
  session
    ..set(tripNameField, trip.name)
    ..set(tripDatesField, (start: trip.startDate, end: trip.endDate))
    ..set(tripLocationField, trip.location)
    ..set(tripResortField, trip.resortName)
    ..set(tripParentField, trip.parentTripId);
}
