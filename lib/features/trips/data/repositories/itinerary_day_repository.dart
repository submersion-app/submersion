import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/trips/domain/entities/itinerary_day.dart'
    as domain;
import 'package:submersion/features/trips/domain/entities/trip.dart'
    show calendarDaysBetween;

class ItineraryDayRepository {
  AppDatabase get _db => DatabaseService.instance.database;
  final SyncRepository _syncRepository = SyncRepository();
  final _uuid = const Uuid();
  final _log = LoggerService.forClass(ItineraryDayRepository);

  /// Emits whenever the `trip_itinerary_days` table changes so the trip
  /// itinerary providers refresh after a sync or any other write that bypasses
  /// the notifiers.
  Stream<void> watchItineraryChanges() =>
      _db.tableUpdates(TableUpdateQuery.onTable(_db.tripItineraryDays));

  /// Get all itinerary days for a trip, ordered by dayNumber ascending.
  Future<List<domain.ItineraryDay>> getByTripId(String tripId) async {
    try {
      _log.info('Getting itinerary days for trip: $tripId');
      final query = _db.select(_db.tripItineraryDays)
        ..where((t) => t.tripId.equals(tripId))
        ..orderBy([(t) => OrderingTerm.asc(t.dayNumber)]);

      final rows = await query.get();
      final result = rows.map(_mapRow).toList();
      _log.info('Found ${result.length} itinerary days for trip: $tripId');
      return result;
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get itinerary days for trip: $tripId',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Bulk insert/update itinerary days. Generates UUID for any day with empty id.
  Future<void> saveAll(List<domain.ItineraryDay> days) async {
    try {
      _log.info('Saving ${days.length} itinerary days');
      final now = DateTime.now();

      // Resolve IDs once so both the batch insert and sync marking
      // reference the same UUID for days with empty ids.
      final resolvedDays = days.map((day) {
        final id = day.id.isEmpty ? _uuid.v4() : day.id;
        return (id: id, day: day);
      }).toList();

      await _db.batch((batch) {
        for (final entry in resolvedDays) {
          batch.insert(
            _db.tripItineraryDays,
            TripItineraryDaysCompanion(
              id: Value(entry.id),
              tripId: Value(entry.day.tripId),
              dayNumber: Value(entry.day.dayNumber),
              date: Value(entry.day.date.millisecondsSinceEpoch),
              dayType: Value(entry.day.dayType.name),
              portName: Value(entry.day.portName),
              latitude: Value(entry.day.latitude),
              longitude: Value(entry.day.longitude),
              notes: Value(entry.day.notes),
              plannedDives: Value(entry.day.plannedDives),
              createdAt: Value(now.millisecondsSinceEpoch),
              updatedAt: Value(now.millisecondsSinceEpoch),
            ),
            mode: InsertMode.insertOrReplace,
          );
        }
      });

      // Mark each day as sync pending
      for (final entry in resolvedDays) {
        await _syncRepository.markRecordPending(
          entityType: 'itineraryDays',
          recordId: entry.id,
          localUpdatedAt: now.millisecondsSinceEpoch,
        );
      }
      SyncEventBus.notifyLocalChange();

      _log.info('Saved ${days.length} itinerary days');
    } catch (e, stackTrace) {
      _log.error(
        'Failed to save itinerary days',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Update a single itinerary day by id. Only updates mutable fields
  /// (dayType, portName, latitude, longitude, notes, plannedDives, updatedAt).
  /// Preserves createdAt.
  Future<void> updateDay(domain.ItineraryDay day) async {
    try {
      _log.info('Updating itinerary day: ${day.id}');
      final now = DateTime.now().millisecondsSinceEpoch;

      await (_db.update(
        _db.tripItineraryDays,
      )..where((t) => t.id.equals(day.id))).write(
        TripItineraryDaysCompanion(
          dayType: Value(day.dayType.name),
          portName: Value(day.portName),
          latitude: Value(day.latitude),
          longitude: Value(day.longitude),
          notes: Value(day.notes),
          plannedDives: Value(day.plannedDives),
          updatedAt: Value(now),
        ),
      );

      await _syncRepository.markRecordPending(
        entityType: 'itineraryDays',
        recordId: day.id,
        localUpdatedAt: now,
      );
      SyncEventBus.notifyLocalChange();

      _log.info('Updated itinerary day: ${day.id}');
    } catch (e, stackTrace) {
      _log.error(
        'Failed to update itinerary day: ${day.id}',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Sets one day's planned dives for the fill forecast; null returns the
  /// day to the estimate. A day with no itinerary row gets one, typed dive
  /// day (decided 2026-09-29: a trip may plan single days without an
  /// itinerary); null on such a day writes nothing. The find and the insert
  /// share one transaction, and the table has no (trip, date) uniqueness,
  /// so two quick saves cannot insert the day twice.
  Future<void> setPlannedDives({
    required String tripId,
    required DateTime date,
    required int? plannedDives,
  }) async {
    final day = DateTime(date.year, date.month, date.day);
    final now = DateTime.now().millisecondsSinceEpoch;
    try {
      String? written;
      await _db.transaction(() async {
        final rows = await (_db.select(
          _db.tripItineraryDays,
        )..where((t) => t.tripId.equals(tripId))).get();
        final existing = rows.where((r) {
          final d = DateTime.fromMillisecondsSinceEpoch(r.date);
          return d.year == day.year && d.month == day.month && d.day == day.day;
        }).firstOrNull;
        if (existing != null) {
          await (_db.update(
            _db.tripItineraryDays,
          )..where((t) => t.id.equals(existing.id))).write(
            TripItineraryDaysCompanion(
              plannedDives: Value(plannedDives),
              updatedAt: Value(now),
            ),
          );
          written = existing.id;
        } else if (plannedDives != null) {
          final trip = await (_db.select(
            _db.trips,
          )..where((t) => t.id.equals(tripId))).getSingle();
          final start = DateTime.fromMillisecondsSinceEpoch(trip.startDate);
          final id = _uuid.v4();
          await _db
              .into(_db.tripItineraryDays)
              .insert(
                TripItineraryDaysCompanion.insert(
                  id: id,
                  tripId: tripId,
                  dayNumber: calendarDaysBetween(start, day) + 1,
                  date: day.millisecondsSinceEpoch,
                  plannedDives: Value(plannedDives),
                  createdAt: now,
                  updatedAt: now,
                ),
              );
          written = id;
        }
        if (written case final id?) {
          await _syncRepository.markRecordPending(
            entityType: 'itineraryDays',
            recordId: id,
            localUpdatedAt: now,
          );
        }
      });
      if (written != null) SyncEventBus.notifyLocalChange();
    } catch (e, stackTrace) {
      _log.error(
        'Failed to set planned dives for trip $tripId on $day',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Delete all itinerary days for a trip. Logs deletion for each day's id
  /// for sync.
  Future<void> deleteByTripId(String tripId) async {
    try {
      _log.info('Deleting itinerary days for trip: $tripId');
      final existing = await getByTripId(tripId);

      if (existing.isEmpty) {
        _log.info('No itinerary days found for trip $tripId, skipping delete');
        return;
      }

      await (_db.delete(
        _db.tripItineraryDays,
      )..where((t) => t.tripId.equals(tripId))).go();

      for (final day in existing) {
        await _syncRepository.logDeletion(
          entityType: 'itineraryDays',
          recordId: day.id,
        );
      }
      SyncEventBus.notifyLocalChange();

      _log.info('Deleted ${existing.length} itinerary days for trip: $tripId');
    } catch (e, stackTrace) {
      _log.error(
        'Failed to delete itinerary days for trip: $tripId',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Regenerate itinerary days when a trip's date range changes.
  ///
  /// 1. Loads existing days via getByTripId
  /// 2. Generates new days via ItineraryDay.generateForTrip
  /// 3. For each new day, checks if an old day exists with the same date --
  ///    if so, preserves the old day's dayType, portName, latitude, longitude,
  ///    and notes
  /// 4. Deletes old days
  /// 5. Saves merged days
  /// 6. Returns the new days
  Future<List<domain.ItineraryDay>> regenerateForTrip(
    String tripId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      _log.info('Regenerating itinerary days for trip: $tripId');

      // 1. Load existing days
      final existingDays = await getByTripId(tripId);

      // 2. Generate new days from the date range
      final newDays = domain.ItineraryDay.generateForTrip(
        tripId: tripId,
        startDate: startDate,
        endDate: endDate,
      );

      // 3. Build a lookup of existing days by date (year, month, day)
      final existingByDate = <String, domain.ItineraryDay>{};
      for (final day in existingDays) {
        final key = _dateKey(day.date);
        existingByDate[key] = day;
      }

      // Merge: preserve dayType, portName, latitude, longitude, notes,
      // plannedDives
      // from overlapping dates
      final mergedDays = newDays.map((newDay) {
        final key = _dateKey(newDay.date);
        final oldDay = existingByDate[key];
        if (oldDay != null) {
          return newDay.copyWith(
            dayType: oldDay.dayType,
            portName: oldDay.portName,
            latitude: oldDay.latitude,
            longitude: oldDay.longitude,
            notes: oldDay.notes,
            plannedDives: oldDay.plannedDives,
          );
        }
        return newDay;
      }).toList();

      // 4. Delete old days
      if (existingDays.isNotEmpty) {
        await deleteByTripId(tripId);
      }

      // 5. Save merged days
      await saveAll(mergedDays);

      _log.info(
        'Regenerated ${mergedDays.length} itinerary days for trip: $tripId',
      );

      // 6. Return the new days (re-fetch to get persisted timestamps)
      return await getByTripId(tripId);
    } catch (e, stackTrace) {
      _log.error(
        'Failed to regenerate itinerary days for trip: $tripId',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Create a date key for day-granularity comparison (year-month-day).
  String _dateKey(DateTime date) {
    return '${date.year}-${date.month}-${date.day}';
  }

  domain.ItineraryDay _mapRow(TripItineraryDay row) {
    return domain.ItineraryDay(
      id: row.id,
      tripId: row.tripId,
      dayNumber: row.dayNumber,
      date: DateTime.fromMillisecondsSinceEpoch(row.date),
      dayType: DayType.fromName(row.dayType),
      portName: row.portName,
      latitude: row.latitude,
      longitude: row.longitude,
      notes: row.notes,
      plannedDives: row.plannedDives,
      createdAt: DateTime.fromMillisecondsSinceEpoch(row.createdAt),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(row.updatedAt),
    );
  }
}
