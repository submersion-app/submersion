import 'dart:math' as math;

import 'package:drift/drift.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/util/wall_clock_utc.dart';
import 'package:submersion/features/trips/data/repositories/trip_row_mapper.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart' as domain;
import 'package:submersion/features/trips/domain/services/side_trips.dart';
import 'package:submersion/features/trips/domain/services/trip_date_stretch.dart';

/// One bound variable per id, well under SQLite's variable limit.
const _chunkSize = 500;

/// Stretches each trip the dives [diveIds] are on so it covers them, and
/// returns the trips that moved (issue #3351). A side trip that moves takes
/// its larger trip along, since the larger trip counts its dives; one whose
/// dates already cover the dives changes neither, so a side trip may sit past
/// the larger trip's end on purpose.
///
/// Opens no transaction and notifies nobody, like
/// `clearForeignTripCylinderLinks`: the caller owns both. Writes through
/// Drift's update, so every trip provider's `watchTripsChanges` refreshes.
Future<List<TripDateStretch>> stretchTripsToCoverDives(
  AppDatabase db,
  SyncRepository sync,
  Iterable<String> diveIds, {
  required int now,
}) async {
  final divesByTrip = await _diveDatesByTrip(db, diveIds.toSet().toList());
  if (divesByTrip.isEmpty) return const [];

  final trips = await _tripsById(db, divesByTrip.keys);
  final parents = await _tripsById(
    db,
    {
      for (final trip in trips.values) ?trip.parentTripId,
    }.where((id) => !trips.containsKey(id)),
  );
  final known = {...trips, ...parents};

  // The dates each trip must cover, with a moved side trip's handed up to
  // its larger trip, so a trip with both comes back as one stretch.
  final needed = {
    for (final e in divesByTrip.entries) e.key: [...e.value],
  };
  for (final trip in trips.values) {
    final dates = divesByTrip[trip.id]!;
    if (_cover(trip, dates) == null) continue;
    final parentId = effectiveParentId(trip, known);
    if (parentId != null) (needed[parentId] ??= []).addAll(dates);
  }

  final stretches = <TripDateStretch>[];
  for (final entry in needed.entries) {
    final trip = known[entry.key];
    if (trip == null) continue;
    final range = _cover(trip, entry.value);
    if (range == null) continue;
    await _writeDates(db, sync, trip.id, range, now: now);
    stretches.add(
      TripDateStretch(
        tripId: trip.id,
        tripName: trip.name,
        priorStart: trip.startDate,
        priorEnd: trip.endDate,
        start: range.start,
        end: range.end,
        isLargerTrip: !divesByTrip.containsKey(trip.id),
      ),
    );
  }
  return stretches;
}

/// Puts [stretches] back, bound by bound: a bound that no longer holds what
/// the stretch wrote was edited or stretched further since, and stays. A
/// trip deleted since is skipped. Opens no transaction and notifies nobody.
Future<void> restoreStretchedTripDates(
  AppDatabase db,
  SyncRepository sync,
  Iterable<TripDateStretch> stretches, {
  required int now,
}) async {
  for (final stretch in stretches) {
    final row = await (db.select(
      db.trips,
    )..where((t) => t.id.equals(stretch.tripId))).getSingleOrNull();
    if (row == null) continue;
    final startMoved = stretch.start != stretch.priorStart;
    final endMoved = stretch.end != stretch.priorEnd;
    final restoresStart =
        startMoved && row.startDate == stretch.start.millisecondsSinceEpoch;
    final restoresEnd =
        endMoved && row.endDate == stretch.end.millisecondsSinceEpoch;
    if (!restoresStart && !restoresEnd) continue;
    await _writeDates(db, sync, stretch.tripId, (
      start: restoresStart
          ? stretch.priorStart
          : DateTime.fromMillisecondsSinceEpoch(row.startDate),
      end: restoresEnd
          ? stretch.priorEnd
          : DateTime.fromMillisecondsSinceEpoch(row.endDate),
    ), now: now);
  }
}

TripDateRange? _cover(domain.Trip trip, Iterable<DateTime> dates) =>
    coveringRange(
      start: trip.startDate,
      end: trip.endDate,
      diveDateTimes: dates,
    );

Future<Map<String, List<DateTime>>> _diveDatesByTrip(
  AppDatabase db,
  List<String> diveIds,
) async {
  final byTrip = <String, List<DateTime>>{};
  for (var i = 0; i < diveIds.length; i += _chunkSize) {
    final chunk = diveIds.sublist(i, math.min(i + _chunkSize, diveIds.length));
    final dives = db.dives;
    final rows =
        await (db.selectOnly(dives)
              ..addColumns([dives.tripId, dives.diveDateTime])
              ..where(dives.id.isIn(chunk) & dives.tripId.isNotNull()))
            .get();
    for (final row in rows) {
      final String tripId = row.read(dives.tripId)!;
      (byTrip[tripId] ??= []).add(
        wallClockUtcFromMillis(row.read(dives.diveDateTime)!),
      );
    }
  }
  return byTrip;
}

Future<Map<String, domain.Trip>> _tripsById(
  AppDatabase db,
  Iterable<String> ids,
) async {
  final idList = ids.toList();
  if (idList.isEmpty) return const {};
  final rows = await (db.select(
    db.trips,
  )..where((t) => t.id.isIn(idList))).get();
  return {for (final row in rows) row.id: tripFromRow(row)};
}

Future<void> _writeDates(
  AppDatabase db,
  SyncRepository sync,
  String tripId,
  TripDateRange range, {
  required int now,
}) async {
  await (db.update(db.trips)..where((t) => t.id.equals(tripId))).write(
    TripsCompanion(
      startDate: Value(range.start.millisecondsSinceEpoch),
      endDate: Value(range.end.millisecondsSinceEpoch),
      updatedAt: Value(now),
    ),
  );
  await sync.markRecordPending(
    entityType: 'trips',
    recordId: tripId,
    localUpdatedAt: now,
  );
}
