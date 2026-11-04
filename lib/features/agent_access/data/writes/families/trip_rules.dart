import 'package:drift/drift.dart' show Variable;

import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/agent_access/data/records/record_repositories.dart';
import 'package:submersion/features/agent_access/data/writes/families/dive_link_rules.dart'
    show stretchCount;
import 'package:submersion/features/agent_access/data/writes/families/service_ledger_rules.dart';
import 'package:submersion/features/agent_access/data/writes/writable_entity.dart';
import 'package:submersion/features/trips/data/repositories/side_trip_links.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/domain/services/trip_dive_days.dart';

/// A block for [check]'s days or parent: a start not after the end, a day
/// trip one day long, days from 1950 to 2100, and a parent the repository
/// would keep (not itself, not a side trip, not when this trip has side
/// trips), as the edit page and `writableParentId` allow.
Future<PlanBlock?> tripProblem(WriteCheck check) async {
  for (final key in const ['start_date', 'end_date']) {
    if (dayRangeProblem(
          check,
          key,
          from: DateTime(1950),
          to: DateTime(2100, 12, 31),
        )
        case final block?) {
      return block;
    }
  }
  final start = calendarDay(
    check.values['start_date'] ?? check.document?['start_date'],
  );
  final end = calendarDay(
    check.values['end_date'] ?? check.document?['end_date'],
  );
  if (start != null && end != null && end.isBefore(start)) {
    return const PlanBlock(
      BlockReason.invalidValue,
      'end_date: a trip ends on or after its start.',
    );
  }
  final type = check.values['trip_type'] ?? check.document?['trip_type'];
  if (type == 'dayTrip' && start != null && end != null && end != start) {
    return const PlanBlock(
      BlockReason.invalidValue,
      'end_date: a day trip ends the day it starts.',
    );
  }
  final parent = check.values['parent_trip_id'];
  if (parent is String) {
    final kept = await writableParentId(
      DatabaseService.instance.database,
      tripId: check.id ?? '',
      parentId: parent,
    );
    if (kept == null) {
      return const PlanBlock(
        BlockReason.invalidValue,
        'parent_trip_id: a side trip hangs off a trip that is not itself a '
        'side trip, and a trip with side trips is not one.',
      );
    }
  }
  if (check.relations['dive_ids']?.remove.isNotEmpty ?? false) {
    return const PlanBlock(
      BlockReason.invalidValue,
      'dive_ids: take a dive off a trip by changing the dive\'s trip_id.',
    );
  }
  return null;
}

/// What assigning [diveIds] to [trip] rewrites beyond the links: the trip's
/// and its parent's days when the dives fall outside them, and the dives'
/// tank links to another trip's cylinders, as `assignDivesToTrip` clears.
Future<Map<String, int>> assignTouched(
  RecordRepositories r,
  Trip trip,
  Set<String> diveIds,
) async {
  if (diveIds.isEmpty) return const {};
  final times = [
    for (final id in diveIds) (await r.dives.getDiveById(id))?.dateTime,
  ].nonNulls.toList();
  final trips = await stretchCount(r, trip, times);
  final cleared = await foreignSlotLinks(diveIds, trip.id);
  return {
    if (trips > 0) 'trips': trips,
    if (cleared > 0) 'dive_tanks': cleared,
  };
}

/// The tanks of [diveIds] linked to a slot of a trip other than [tripId]
/// (any trip when null): the links the dives lose when they move, which
/// the repository clears.
Future<int> foreignSlotLinks(Set<String> diveIds, String? tripId) async {
  if (diveIds.isEmpty) return 0;
  final marks = List.filled(diveIds.length, '?').join(', ');
  final row = await DatabaseService.instance.database
      .customSelect(
        'SELECT COUNT(*) AS n FROM dive_tanks dt '
        'JOIN trip_cylinders tc ON tc.id = dt.trip_cylinder_id '
        'WHERE dt.dive_id IN ($marks)'
        '${tripId == null ? '' : ' AND tc.trip_id != ?'}',
        variables: [
          for (final id in diveIds) Variable.withString(id),
          if (tripId != null) Variable.withString(tripId),
        ],
      )
      .getSingle();
  return row.read<int>('n');
}

/// The itinerary days a date change of [trip] to [next] deletes: those
/// outside the new range that carry nothing but a plan.
Future<int> bareDaysOutside(
  RecordRepositories r,
  String tripId,
  Trip next,
) async {
  final first = tripDay(next.startDate);
  final last = tripDay(next.endDate);
  return (await r.itineraryDays.getByTripId(tripId)).where((d) {
    final day = tripDay(d.date);
    return (day.isBefore(first) || day.isAfter(last)) && isBarePlanDay(d);
  }).length;
}
