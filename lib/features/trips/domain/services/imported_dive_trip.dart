import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/domain/services/trip_for_dive_date.dart';

/// Pure. Whether a new imported dive joins the trip whose dates cover its
/// day (#2618), shared by the importers and the import review (#3022) so
/// the trip the review shows is the trip the dive is saved in. The caller
/// checks the dive has a date: an undated dive is never placed, since its
/// date would be the import clock.
///
/// A dive its source already put in a trip keeps it ([hasOwnTrip]). A
/// source that has trips leaves a dive out of them on purpose, so there
/// only a dive whose own trip was not imported ([hasTripRef] with no own
/// trip) is placed by date. A source with no trips at all, a dive computer
/// download or MacDive say, places every dated dive.
bool placesImportedDiveByDate({
  required bool hasOwnTrip,
  required bool hasTripRef,
  required bool sourceHasTrips,
}) => !hasOwnTrip && (hasTripRef || !sourceHasTrips);

/// Pure. The trip a new imported dive is saved in: [ownTrip] when its source
/// put it in one that is imported or linked, otherwise the trip among
/// [trips] covering [diveDateTime] when [placesImportedDiveByDate] allows,
/// otherwise none.
Trip? tripForImportedDive({
  Trip? ownTrip,
  bool hasTripRef = false,
  bool sourceHasTrips = false,
  required DateTime? diveDateTime,
  required Iterable<Trip> trips,
}) {
  if (ownTrip != null) return ownTrip;
  if (diveDateTime == null ||
      !placesImportedDiveByDate(
        hasOwnTrip: false,
        hasTripRef: hasTripRef,
        sourceHasTrips: sourceHasTrips,
      )) {
    return null;
  }
  return tripForDiveDate(diveDateTime, trips);
}
