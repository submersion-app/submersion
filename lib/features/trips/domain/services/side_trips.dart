import 'package:submersion/features/trips/domain/entities/trip.dart';

/// Pure. The larger trip [trip] is a side trip of, or null (issue #3658).
///
/// The same rule as `side_trip_sql.dart`: the link counts only when the
/// parent is in [tripsById], has no parent of its own, and is not [trip].
String? effectiveParentId(Trip trip, Map<String, Trip> tripsById) {
  final parentId = trip.parentTripId;
  if (parentId == null || parentId == trip.id) return null;
  final parent = tripsById[parentId];
  if (parent == null || parent.parentTripId != null) return null;
  return parentId;
}

/// Pure. Whether [candidate] may be offered as the larger trip of the trip
/// [forTripId] (null for a trip not saved yet): never the trip itself, and
/// never a trip that is a side trip, so nesting stays one level deep.
bool canChooseAsParent(Trip candidate, {required String? forTripId}) =>
    candidate.id != forTripId && candidate.parentTripId == null;
