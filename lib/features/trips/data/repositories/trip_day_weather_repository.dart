import 'package:collection/collection.dart';
import 'package:drift/drift.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/features/trips/domain/entities/trip_day_weather.dart'
    as domain;
import 'package:submersion/features/trips/domain/entities/trip_day_weather.dart'
    show tripDayDate, tripDayMillis, tripDayWeatherRowId;

/// Reads and writes stored per-day trip weather.
///
/// The day is the identity, not the row id: `upsert` replaces any existing
/// row for the same (trip, date), so two devices that both fetch the same day
/// converge on one row rather than accumulating duplicates.
class TripDayWeatherRepository {
  AppDatabase get _db => DatabaseService.instance.database;
  final SyncRepository _syncRepository = SyncRepository();
  final _log = LoggerService.forClass(TripDayWeatherRepository);

  /// The UTC-midnight day key for [date], as epoch milliseconds.
  ///
  /// The day is the identity, so normalizing here is what actually enforces
  /// the (trip, date) uniqueness intent. A caller that passes a DateTime with
  /// a time component would otherwise store a second row for the same
  /// calendar day, invisible to every midnight-keyed lookup and refetched on
  /// every view. Reads normalize too, because a row can also arrive through
  /// sync from a peer, bypassing this class entirely.
  static int _dayKey(DateTime date) => tripDayMillis(date);

  /// Emits whenever `trip_day_weather` changes, so the display provider
  /// refreshes after a backfill write or a sync import.
  Stream<void> watchWeatherChanges() =>
      _db.tableUpdates(TableUpdateQuery.onTable(_db.tripDayWeather));

  /// Stored weather for a trip, keyed by `tripDayMillis(date)`: the calendar
  /// day at UTC midnight, not `date.millisecondsSinceEpoch`.
  ///
  /// The distinction is the contract. Local-midnight millis differ in every
  /// timezone, so a caller keying a lookup that way silently misses every
  /// stored row rather than failing.
  ///
  /// One entry per calendar day. Where more than one row lands on the same
  /// day, [_preferred] picks which one shows, and explains how a second row
  /// gets there in the first place.
  Future<Map<int, domain.TripDayWeather>> getForTrip(String tripId) async {
    try {
      final rows = await (_db.select(
        _db.tripDayWeather,
      )..where((t) => t.tripId.equals(tripId))).get();

      final winners = <int, TripDayWeatherData>{};
      for (final row in rows) {
        final day = _dayKey(tripDayDate(row.date));
        final held = winners[day];
        winners[day] = held == null
            ? row
            : _preferred(held, row, tripId: tripId, dayMillis: day);
      }

      return winners.map((day, row) => MapEntry(day, _mapRow(row)));
    } catch (e, stackTrace) {
      _log.error(
        'Failed to read weather for trip: $tripId',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Insert or replace one day's weather.
  Future<void> upsert(domain.TripDayWeather weather) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      final dateMillis = _dayKey(weather.date);

      // The id is derived from (trip, day), never taken from the caller, so
      // every device writing this day produces the same primary key and sync
      // merges by id instead of colliding on the unique index.
      final id = tripDayWeatherRowId(
        tripId: weather.tripId,
        dayMillis: dateMillis,
      );

      final sameDay = await _rowsForDay(
        tripId: weather.tripId,
        dayMillis: dateMillis,
      );
      // Only to preserve createdAt across an update; insertOnConflictUpdate
      // would otherwise overwrite it with this write's timestamp. A stray is
      // this day under an old id rather than a different record, so the day
      // keeps the age it already had when one is absorbed.
      final createdAt = sameDay.map((r) => r.createdAt).minOrNull;
      final strays = sameDay.where((r) => r.id != id).map((r) => r.id).toList();

      // Atomic, following the pattern the #553 review established in
      // BuddyRepository.deleteBuddy: the row change and its sync bookkeeping
      // commit together, and only the observable event is deferred to after
      // the commit. A tombstone written outside the transaction could be lost
      // while its delete stood, and nothing would ever repair that: the
      // backfill skips any day that already has a stored row, so once the
      // canonical row exists this day is never upserted again and a
      // resurrected stray would sit in the table for good.
      await _db.transaction(() async {
        // Strays go before the insert, not after. insertOnConflictUpdate
        // targets the primary key, so a stray sitting on this same
        // (trip_id, date) is not a conflict it can absorb: the insert misses
        // the ON CONFLICT target and hits the unique index instead, which
        // throws and fails the whole write.
        if (strays.isNotEmpty) {
          await (_db.delete(
            _db.tripDayWeather,
          )..where((t) => t.id.isIn(strays))).go();
        }

        await _db
            .into(_db.tripDayWeather)
            .insertOnConflictUpdate(
              TripDayWeatherCompanion(
                id: Value(id),
                tripId: Value(weather.tripId),
                date: Value(dateMillis),
                latitude: Value(weather.latitude),
                longitude: Value(weather.longitude),
                airTemp: Value(weather.airTemp),
                cloudCover: Value(weather.cloudCover?.name),
                precipitation: Value(weather.precipitation?.name),
                windSpeed: Value(weather.windSpeed),
                windDirection: Value(weather.windDirection?.name),
                humidity: Value(weather.humidity),
                surfacePressure: Value(weather.surfacePressure),
                weatherCode: Value(weather.weatherCode),
                weatherSource: Value(weather.weatherSource.name),
                fetchedAt: Value(weather.fetchedAt.millisecondsSinceEpoch),
                createdAt: Value(
                  createdAt ?? weather.createdAt.millisecondsSinceEpoch,
                ),
                updatedAt: Value(now),
              ),
            );

        // A stray is a synced record: dropping it without a tombstone lets
        // the peer that sent it hand it straight back on the next pull.
        for (final stray in strays) {
          await _syncRepository.logDeletion(
            entityType: 'tripDayWeather',
            recordId: stray,
          );
        }

        await _syncRepository.markRecordPending(
          entityType: 'tripDayWeather',
          recordId: id,
          localUpdatedAt: now,
        );
      });

      SyncEventBus.notifyLocalChange();
    } catch (e, stackTrace) {
      _log.error(
        'Failed to store weather for trip: ${weather.tripId}',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Delete every stored day for a trip, logging each id for sync.
  Future<void> deleteByTripId(String tripId) async {
    try {
      final existing = await (_db.select(
        _db.tripDayWeather,
      )..where((t) => t.tripId.equals(tripId))).get();
      if (existing.isEmpty) return;

      await (_db.delete(
        _db.tripDayWeather,
      )..where((t) => t.tripId.equals(tripId))).go();

      for (final row in existing) {
        await _syncRepository.logDeletion(
          entityType: 'tripDayWeather',
          recordId: row.id,
        );
      }
      SyncEventBus.notifyLocalChange();

      _log.info('Deleted ${existing.length} weather days for trip: $tripId');
    } catch (e, stackTrace) {
      _log.error(
        'Failed to delete weather for trip: $tripId',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Every stored row for this trip that falls on [dayMillis]'s calendar day.
  ///
  /// Filtered in Dart rather than SQL. It could be pushed down now that the
  /// key is UTC, since the day is plain integer arithmetic on the stored
  /// millis with no zone or DST to consult, but there is nothing to gain: a
  /// trip holds one row per day, so the scan is a few dozen rows, and keeping
  /// the rule in one Dart function is what stops it drifting from
  /// [tripDayMillis].
  Future<List<TripDayWeatherData>> _rowsForDay({
    required String tripId,
    required int dayMillis,
  }) async {
    final rows = await (_db.select(
      _db.tripDayWeather,
    )..where((t) => t.tripId.equals(tripId))).get();
    return rows
        .where((r) => _dayKey(tripDayDate(r.date)) == dayMillis)
        .toList();
  }

  /// Which of two rows for the same calendar day to show.
  ///
  /// Two rows reach one day only when [upsert] did not write one of them: a
  /// peer on a build that predates the derived id, or a database written
  /// before this class normalized. [upsert] clears them out, but a read can
  /// land between a sync import and the next write, and it cannot tidy up
  /// itself: a delete here would fire the table tick that the display
  /// provider subscribes to and invalidate the read in flight. So it chooses.
  ///
  /// The canonical row wins, so what shows now is what the next upsert keeps.
  /// Failing that the most recently updated wins, and an exact tie falls back
  /// to the id, so the answer never depends on the order SQLite returned the
  /// rows in.
  TripDayWeatherData _preferred(
    TripDayWeatherData a,
    TripDayWeatherData b, {
    required String tripId,
    required int dayMillis,
  }) {
    final canonicalId = tripDayWeatherRowId(
      tripId: tripId,
      dayMillis: dayMillis,
    );
    if (a.id == canonicalId) return a;
    if (b.id == canonicalId) return b;
    if (a.updatedAt != b.updatedAt) return a.updatedAt > b.updatedAt ? a : b;
    return a.id.compareTo(b.id) <= 0 ? a : b;
  }

  domain.TripDayWeather _mapRow(TripDayWeatherData row) {
    return domain.TripDayWeather(
      id: row.id,
      tripId: row.tripId,
      // Normalized, matching the map key getForTrip returns it under: a row
      // written by an older build or an out-of-date peer can still carry a
      // time component, and handing that back would put time-bearing dates
      // into downstream logic.
      date: tripDayDate(_dayKey(tripDayDate(row.date))),
      latitude: row.latitude,
      longitude: row.longitude,
      airTemp: row.airTemp,
      cloudCover: row.cloudCover == null
          ? null
          : CloudCover.values.byName(row.cloudCover!),
      precipitation: row.precipitation == null
          ? null
          : Precipitation.values.byName(row.precipitation!),
      windSpeed: row.windSpeed,
      windDirection: row.windDirection == null
          ? null
          : CurrentDirection.values.byName(row.windDirection!),
      humidity: row.humidity,
      surfacePressure: row.surfacePressure,
      weatherCode: row.weatherCode,
      weatherSource: WeatherSource.values.byName(row.weatherSource),
      fetchedAt: DateTime.fromMillisecondsSinceEpoch(row.fetchedAt),
      createdAt: DateTime.fromMillisecondsSinceEpoch(row.createdAt),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(row.updatedAt),
    );
  }
}
