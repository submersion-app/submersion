import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/presentation/editing/trip_card_slots.dart';
import 'package:submersion/features/trips/presentation/pages/trip_cylinder_board_page.dart';
import 'package:submersion/shared/widgets/record_editing/record_satellite.dart';

/// Opens trip [tripId]'s cylinder board from [context], a place on the trip
/// page. On a page that edits in place (issue #4527) the board is pushed
/// as a satellite: joined to the page's sitting while it is unlocked, with
/// a lock of its own while it is locked. Otherwise by its address, as
/// always.
Future<void> openTripCylinderBoard(BuildContext context, String tripId) {
  if (TripCardSlotsScope.maybeOf(context) == null) {
    return context.push('/trips/$tripId/cylinders');
  }
  return pushRecordSatellite<Trip, void>(
    context,
    builder: (joined) => TripCylinderBoardPage(
      tripId: tripId,
      joined: joined,
      unlockEditing: true,
    ),
  );
}
