import 'package:clock/clock.dart';

import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/domain/services/side_trips.dart';

/// What a new trip can learn from one selected dive (issue #3658).
class SelectionDiveFacts {
  const SelectionDiveFacts({
    required this.diveId,
    required this.diveDateTime,
    this.tripId,
    this.siteRegion,
    this.siteCountry,
    this.diveCenterName,
  });

  final String diveId;

  /// Wall clock in UTC components, as dives store it.
  final DateTime diveDateTime;
  final String? tripId;
  final String? siteRegion;
  final String? siteCountry;
  final String? diveCenterName;
}

/// A new trip prefilled from selected dives, and the dives it will take.
class TripDraft {
  const TripDraft({
    required this.trip,
    required this.diveIds,
    this.sourceTripIds = const {},
  });

  final Trip trip;
  final List<String> diveIds;

  /// The trips the dives are on now, whose figures change when they move.
  final Set<String> sourceTripIds;
}

/// Pure. The new trip [facts] suggest, every field a starting value the
/// diver reviews in the trip form:
///
/// * dates: the wall-clock days of the first and last dive;
/// * location: the region the sites share (with the country when that is
///   shared too), else the country they share; dives without a site do not
///   count;
/// * resort name: the dive center every dive shares;
/// * part of: the trip every dive is on, or that trip's larger trip when it
///   is a side trip itself, so nesting stays one level deep;
/// * name: [nameFor] the location and start date.
TripDraft buildTripDraft(
  List<SelectionDiveFacts> facts, {
  required Map<String, Trip> tripsById,
  required String Function(String? location, DateTime start) nameFor,
}) {
  if (facts.isEmpty) {
    throw ArgumentError.value(facts, 'facts', 'needs at least one dive');
  }
  final days = [
    for (final f in facts)
      () {
        final wall = f.diveDateTime.toUtc();
        return DateTime(wall.year, wall.month, wall.day);
      }(),
  ]..sort();
  final start = days.first;
  final end = days.last;
  final location = _sharedLocation(facts);
  final now = clock.now();
  return TripDraft(
    trip: Trip(
      id: '',
      name: nameFor(location, start),
      startDate: start,
      endDate: end,
      location: location,
      resortName: _shared(facts.map((f) => f.diveCenterName)),
      parentTripId: _sharedParent(facts, tripsById),
      createdAt: now,
      updatedAt: now,
    ),
    diveIds: [for (final f in facts) f.diveId],
    sourceTripIds: {for (final f in facts) ?f.tripId},
  );
}

String? _sharedLocation(List<SelectionDiveFacts> facts) {
  final sited = facts.where(
    (f) => _blank(f.siteRegion) != null || _blank(f.siteCountry) != null,
  );
  if (sited.isEmpty) return null;
  final region = _shared(sited.map((f) => f.siteRegion));
  final country = _shared(sited.map((f) => f.siteCountry));
  if (region != null) return country == null ? region : '$region, $country';
  return country;
}

String? _sharedParent(
  List<SelectionDiveFacts> facts,
  Map<String, Trip> tripsById,
) {
  final tripId = _shared(facts.map((f) => f.tripId));
  if (tripId == null) return null;
  final trip = tripsById[tripId];
  if (trip == null) return null;
  // A side trip offers its larger trip. One with any stored link offers
  // only that: when the link is broken, pointing at the trip itself would
  // write a link two levels deep, which every reader ignores.
  if (trip.parentTripId != null) return effectiveParentId(trip, tripsById);
  return tripId;
}

/// The one non-blank value every entry has, else null: a blank entry means
/// there is no shared value.
String? _shared(Iterable<String?> values) {
  String? found;
  for (final raw in values) {
    final value = _blank(raw);
    if (value == null) return null;
    if (found != null && found != value) return null;
    found = value;
  }
  return found;
}

String? _blank(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}
