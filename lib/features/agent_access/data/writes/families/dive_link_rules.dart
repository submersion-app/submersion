import 'dart:convert';

import 'package:drift/drift.dart' show Variable;

import 'package:submersion/features/agent_access/data/records/record_repositories.dart';
import 'package:submersion/features/agent_access/data/writes/writable_entity.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/dive_roles/domain/entities/dive_role.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/domain/services/trip_date_stretch.dart';

/// A dive's buddies and the roles each holds, by buddy id, as the dive edit
/// page shows them.
Future<Map<String, List<String>>> buddyRolesOf(
  RecordRepositories r,
  String diveId,
) async => {
  for (final b in await r.buddies.getBuddiesForDive(diveId))
    b.buddy.id: [for (final role in b.roles) role.id],
};

/// Why [parsed] cannot be a dive's buddy list for [ownerId], or null: each
/// buddy is one of the profile's, each role one it can use.
Future<PlanBlock?> buddyRolesProblem(
  RecordRepositories r,
  Object? parsed,
  String? ownerId,
) async {
  final byBuddy = _decoded(parsed);
  final roles = {
    for (final role in await r.diveRoles.getAllDiveRoles())
      if (role.diverId == null || role.diverId == ownerId) role.id,
  };
  for (final MapEntry(key: buddyId, value: ids) in byBuddy.entries) {
    final buddy = await r.buddies.getBuddyById(buddyId);
    if (buddy == null || (buddy.diverId != null && buddy.diverId != ownerId)) {
      return PlanBlock(
        BlockReason.unknownReference,
        'buddy_roles: no buddy $buddyId of this profile.',
      );
    }
    final unknown = ids.where((id) => !roles.contains(id)).toList();
    if (unknown.isNotEmpty) {
      return PlanBlock(
        BlockReason.unknownReference,
        'buddy_roles: no dive role ${unknown.join(', ')} for this profile.',
      );
    }
  }
  return null;
}

/// Makes [parsed] the dive's whole buddy list, as the dive edit page saves
/// it. An empty role list is Buddy.
Future<void> setBuddyRoles(
  RecordRepositories r,
  String diveId,
  Object? parsed,
) async {
  final roles = {
    for (final role in await r.diveRoles.getAllDiveRoles()) role.id: role,
  };
  final buddies = <BuddyWithRole>[];
  for (final MapEntry(key: buddyId, value: ids) in _decoded(parsed).entries) {
    final buddy = await r.buddies.getBuddyById(buddyId);
    if (buddy == null) continue;
    buddies.add(
      BuddyWithRole(
        buddy: buddy,
        roles: [
          for (final id in ids.isEmpty ? const [DiveRole.buddyId] : ids)
            ?roles[id],
        ],
      ),
    );
  }
  await r.buddies.setBuddiesForDive(diveId, buddies);
}

Map<String, List<String>> _decoded(Object? parsed) => parsed is String
    ? {
        for (final MapEntry(:key, :value)
            in (jsonDecode(parsed) as Map<String, Object?>).entries)
          key: [for (final id in value! as List) '$id'],
      }
    : const {};

/// How many trips a dive on [tripId] on [day] makes stretch to cover it:
/// the trip, and the larger trip a side trip sits in, as the dive edit
/// page's save stretches them.
Future<int> tripsStretched(
  RecordRepositories r,
  String tripId,
  DateTime day,
) async {
  final trip = await r.trips.getTripById(tripId);
  return trip == null
      ? 0
      : stretchCount(r, trip, [DateTime.utc(day.year, day.month, day.day)]);
}

/// How many trips dives at [diveDateTimes] (wall clocks) on [trip] make
/// stretch, by stretchTripsToCoverDives' rule: the trip when its days miss
/// one, and its larger trip only then, when the larger trip misses one too.
/// A side trip that already covers its dives may sit past its larger trip.
Future<int> stretchCount(
  RecordRepositories r,
  Trip trip,
  List<DateTime> diveDateTimes,
) async {
  bool misses(Trip t) =>
      coveringRange(
        start: t.startDate,
        end: t.endDate,
        diveDateTimes: diveDateTimes,
      ) !=
      null;
  if (diveDateTimes.isEmpty || !misses(trip)) return 0;
  final parentId = trip.parentTripId;
  final parent = parentId == null ? null : await r.trips.getTripById(parentId);
  return parent != null && misses(parent) ? 2 : 1;
}

/// The day of the dive [diveId] as its wall clock reads, or [moved] when
/// the change moves it.
Future<DateTime?> diveDay(
  RecordRepositories r,
  String diveId, {
  DateTime? moved,
}) async {
  if (moved != null) return DateTime(moved.year, moved.month, moved.day);
  final row = await r.db
      .customSelect(
        'SELECT dive_date_time FROM dives WHERE id = ?',
        variables: [Variable.withString(diveId)],
      )
      .getSingleOrNull();
  if (row == null) return null;
  final clock = DateTime.fromMillisecondsSinceEpoch(
    row.read<int>('dive_date_time'),
    isUtc: true,
  );
  return DateTime(clock.year, clock.month, clock.day);
}
