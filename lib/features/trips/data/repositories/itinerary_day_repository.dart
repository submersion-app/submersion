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

class ItineraryDayRepository {
  AppDatabase get _db => DatabaseService.instance.database;
  final SyncRepository _syncRepository = SyncRepository();
  final _uuid = const Uuid();
  final _log = LoggerService.forClass(ItineraryDayRepository);

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
          entityType: 'tripItineraryDays',
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
  /// (dayType, portName, latitude, longitude, notes, updatedAt).
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
          updatedAt: Value(now),
        ),
      );

      await _syncRepository.markRecordPending(
        entityType: 'tripItineraryDays',
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
          entityType: 'tripItineraryDays',
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

      // Merge: preserve dayType, portName, latitude, longitude, notes
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
      return getByTripId(tripId);
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
      createdAt: DateTime.fromMillisecondsSinceEpoch(row.createdAt),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(row.updatedAt),
    );
  }
}
