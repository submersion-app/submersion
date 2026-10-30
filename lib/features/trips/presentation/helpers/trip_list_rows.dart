import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/domain/services/side_trips.dart';

/// One row of the trip list, with how it nests (issue #3658).
class TripListRow {
  const TripListRow({
    required this.item,
    this.isSideTrip = false,
    this.sideTripCount = 0,
    this.partOfName,
  });

  final TripWithStats item;

  /// Shown indented under its larger trip.
  final bool isSideTrip;

  /// The larger trip's side trips, for its "N side trips" note.
  final int sideTripCount;

  /// The larger trip's name, for a side trip listed on its own because its
  /// larger trip is not in the list (filtered or searched out).
  final String? partOfName;
}

/// Pure. [sorted] in its own order, each side trip moved under its larger
/// trip, earliest first. [allTripsById] holds every trip the profile can
/// see, so a larger trip outside [sorted] can still be named and counted.
List<TripListRow> nestTripRows(
  List<TripWithStats> sorted,
  Map<String, Trip> allTripsById,
) {
  final listed = {for (final t in sorted) t.trip.id};
  final childrenOf = <String, List<TripWithStats>>{};
  final sideTripCounts = <String, int>{};
  for (final trip in allTripsById.values) {
    final parentId = effectiveParentId(trip, allTripsById);
    if (parentId != null) {
      sideTripCounts[parentId] = (sideTripCounts[parentId] ?? 0) + 1;
    }
  }
  for (final item in sorted) {
    final parentId = effectiveParentId(item.trip, allTripsById);
    if (parentId != null && listed.contains(parentId)) {
      (childrenOf[parentId] ??= []).add(item);
    }
  }
  final rows = <TripListRow>[];
  for (final item in sorted) {
    final parentId = effectiveParentId(item.trip, allTripsById);
    if (parentId != null && listed.contains(parentId)) continue;
    rows.add(
      TripListRow(
        item: item,
        sideTripCount: sideTripCounts[item.trip.id] ?? 0,
        partOfName: parentId == null ? null : allTripsById[parentId]?.name,
      ),
    );
    final children = [...?childrenOf[item.trip.id]]
      ..sort((a, b) => a.trip.startDate.compareTo(b.trip.startDate));
    rows.addAll([
      for (final child in children) TripListRow(item: child, isSideTrip: true),
    ]);
  }
  return rows;
}

/// Pure. [rows] cut into runs, each a top-level row and its side trips, so
/// a side trip stays with its larger trip when the list is sectioned.
List<List<TripListRow>> tripRowGroups(List<TripListRow> rows) {
  final groups = <List<TripListRow>>[];
  for (final row in rows) {
    if (row.isSideTrip && groups.isNotEmpty) {
      groups.last.add(row);
    } else {
      groups.add([row]);
    }
  }
  return groups;
}
