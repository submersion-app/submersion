import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/trips/data/repositories/itinerary_day_repository.dart';
import 'package:submersion/features/trips/data/repositories/liveaboard_details_repository.dart';
import 'package:submersion/features/trips/domain/entities/dive_candidate.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart' as domain;

class TripRepository {
  AppDatabase get _db => DatabaseService.instance.database;
  final SyncRepository _syncRepository = SyncRepository();
  final _uuid = const Uuid();
  final _log = LoggerService.forClass(TripRepository);

  /// Get all trips ordered by start date (most recent first)
  Future<List<domain.Trip>> getAllTrips({String? diverId}) async {
    try {
      final query = _db.select(_db.trips)
        ..orderBy([(t) => OrderingTerm.desc(t.startDate)]);

      if (diverId != null) {
        query.where((t) => t.diverId.equals(diverId));
      }

      final rows = await query.get();
      return rows.map(_mapRowToTrip).toList();
    } catch (e, stackTrace) {
      _log.error('Failed to get all trips', e, stackTrace);
      rethrow;
    }
  }

  /// Get trip by ID
  Future<domain.Trip?> getTripById(String id) async {
    try {
      final query = _db.select(_db.trips)..where((t) => t.id.equals(id));

      final row = await query.getSingleOrNull();
      return row != null ? _mapRowToTrip(row) : null;
    } catch (e, stackTrace) {
      _log.error('Failed to get trip by id: $id', e, stackTrace);
      rethrow;
    }
  }

  /// Search trips by name or location
  Future<List<domain.Trip>> searchTrips(String query, {String? diverId}) async {
    final searchTerm = '%${query.toLowerCase()}%';
    final diverFilter = diverId != null ? 'AND diver_id = ?' : '';
    final variables = [
      Variable.withString(searchTerm),
      Variable.withString(searchTerm),
      Variable.withString(searchTerm),
      Variable.withString(searchTerm),
      if (diverId != null) Variable.withString(diverId),
    ];

    final results = await _db.customSelect('''
      SELECT * FROM trips
      WHERE (LOWER(name) LIKE ?
         OR LOWER(location) LIKE ?
         OR LOWER(resort_name) LIKE ?
         OR LOWER(liveaboard_name) LIKE ?)
      $diverFilter
      ORDER BY start_date DESC
    ''', variables: variables).get();

    return results.map((row) {
      return domain.Trip(
        id: row.data['id'] as String,
        diverId: row.data['diver_id'] as String?,
        name: row.data['name'] as String,
        startDate: DateTime.fromMillisecondsSinceEpoch(
          row.data['start_date'] as int,
        ),
        endDate: DateTime.fromMillisecondsSinceEpoch(
          row.data['end_date'] as int,
        ),
        location: row.data['location'] as String?,
        resortName: row.data['resort_name'] as String?,
        liveaboardName: row.data['liveaboard_name'] as String?,
        notes: (row.data['notes'] as String?) ?? '',
        tripType: TripType.fromName(
          (row.data['trip_type'] as String?) ?? 'shore',
        ),
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          row.data['created_at'] as int,
        ),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(
          row.data['updated_at'] as int,
        ),
      );
    }).toList();
  }

  /// Create a new trip
  Future<domain.Trip> createTrip(domain.Trip trip) async {
    try {
      _log.info('Creating trip: ${trip.name}');
      final id = trip.id.isEmpty ? _uuid.v4() : trip.id;
      final now = DateTime.now();

      await _db
          .into(_db.trips)
          .insert(
            TripsCompanion(
              id: Value(id),
              diverId: Value(trip.diverId),
              name: Value(trip.name),
              startDate: Value(trip.startDate.millisecondsSinceEpoch),
              endDate: Value(trip.endDate.millisecondsSinceEpoch),
              location: Value(trip.location),
              resortName: Value(trip.resortName),
              liveaboardName: Value(trip.liveaboardName),
              notes: Value(trip.notes),
              tripType: Value(trip.tripType.name),
              createdAt: Value(now.millisecondsSinceEpoch),
              updatedAt: Value(now.millisecondsSinceEpoch),
            ),
          );

      await _syncRepository.markRecordPending(
        entityType: 'trips',
        recordId: id,
        localUpdatedAt: now.millisecondsSinceEpoch,
      );
      SyncEventBus.notifyLocalChange();

      _log.info('Created trip with id: $id');
      return trip.copyWith(id: id, createdAt: now, updatedAt: now);
    } catch (e, stackTrace) {
      _log.error('Failed to create trip: ${trip.name}', e, stackTrace);
      rethrow;
    }
  }

  /// Update an existing trip
  Future<void> updateTrip(domain.Trip trip) async {
    try {
      _log.info('Updating trip: ${trip.id}');
      final now = DateTime.now().millisecondsSinceEpoch;

      await (_db.update(_db.trips)..where((t) => t.id.equals(trip.id))).write(
        TripsCompanion(
          name: Value(trip.name),
          startDate: Value(trip.startDate.millisecondsSinceEpoch),
          endDate: Value(trip.endDate.millisecondsSinceEpoch),
          location: Value(trip.location),
          resortName: Value(trip.resortName),
          liveaboardName: Value(trip.liveaboardName),
          notes: Value(trip.notes),
          tripType: Value(trip.tripType.name),
          updatedAt: Value(now),
        ),
      );
      await _syncRepository.markRecordPending(
        entityType: 'trips',
        recordId: trip.id,
        localUpdatedAt: now,
      );
      SyncEventBus.notifyLocalChange();
      _log.info('Updated trip: ${trip.id}');
    } catch (e, stackTrace) {
      _log.error('Failed to update trip: ${trip.id}', e, stackTrace);
      rethrow;
    }
  }

  /// Delete a trip and all associated child records.
  /// Removes liveaboard details, itinerary days, and dive associations
  /// before deleting the trip itself.
  Future<void> deleteTrip(String id) async {
    try {
      _log.info('Deleting trip: $id');

      // Delete child records with non-nullable FKs first
      await LiveaboardDetailsRepository().deleteByTripId(id);
      await ItineraryDayRepository().deleteByTripId(id);

      // Remove trip association from dives (nullable FK)
      await _db.customUpdate(
        'UPDATE dives SET trip_id = NULL WHERE trip_id = ?',
        variables: [Variable.withString(id)],
        updates: {_db.dives},
      );

      // Delete the trip
      await (_db.delete(_db.trips)..where((t) => t.id.equals(id))).go();
      await _syncRepository.logDeletion(entityType: 'trips', recordId: id);
      SyncEventBus.notifyLocalChange();
      _log.info('Deleted trip: $id');
    } catch (e, stackTrace) {
      _log.error('Failed to delete trip: $id', e, stackTrace);
      rethrow;
    }
  }

  /// Get dives for a specific trip
  Future<List<String>> getDiveIdsForTrip(String tripId) async {
    final results = await _db
        .customSelect(
          '''
      SELECT id FROM dives
      WHERE trip_id = ?
      ORDER BY dive_date_time DESC
    ''',
          variables: [Variable.withString(tripId)],
        )
        .get();

    return results.map((row) => row.data['id'] as String).toList();
  }

  /// Get dive count for a trip
  Future<int> getDiveCountForTrip(String tripId) async {
    final result = await _db
        .customSelect(
          '''
      SELECT COUNT(*) as count
      FROM dives
      WHERE trip_id = ?
    ''',
          variables: [Variable.withString(tripId)],
        )
        .getSingle();

    return result.data['count'] as int? ?? 0;
  }

  /// Assign a dive to a trip
  Future<void> assignDiveToTrip(String diveId, String tripId) async {
    try {
      _log.info('Assigning dive $diveId to trip $tripId');
      await _db.customUpdate(
        'UPDATE dives SET trip_id = ? WHERE id = ?',
        variables: [Variable.withString(tripId), Variable.withString(diveId)],
        updates: {_db.dives},
      );
      _log.info('Assigned dive to trip');
    } catch (e, stackTrace) {
      _log.error('Failed to assign dive to trip', e, stackTrace);
      rethrow;
    }
  }

  /// Remove a dive from a trip
  Future<void> removeDiveFromTrip(String diveId) async {
    try {
      _log.info('Removing dive $diveId from trip');
      await _db.customUpdate(
        'UPDATE dives SET trip_id = NULL WHERE id = ?',
        variables: [Variable.withString(diveId)],
        updates: {_db.dives},
      );
      _log.info('Removed dive from trip');
    } catch (e, stackTrace) {
      _log.error('Failed to remove dive from trip', e, stackTrace);
      rethrow;
    }
  }

  /// Find dives within a trip's date range that are either unassigned
  /// or assigned to a different trip (excludes dives already on this trip).
  Future<List<DiveCandidate>> findCandidateDivesForTrip({
    required String tripId,
    required DateTime startDate,
    required DateTime endDate,
    required String diverId,
  }) async {
    try {
      _log.info('Scanning for candidate dives: $startDate - $endDate');
      final startMs = startDate.millisecondsSinceEpoch;
      final endMs = endDate.millisecondsSinceEpoch;

      final rows = await _db
          .customSelect(
            '''
        SELECT d.id as dive_id, t.id as other_trip_id, t.name as other_trip_name
        FROM dives d
        LEFT JOIN trips t ON d.trip_id = t.id AND d.trip_id != ?
        WHERE d.dive_date_time >= ? AND d.dive_date_time <= ?
          AND d.diver_id = ?
          AND (d.trip_id IS NULL OR d.trip_id != ?)
        ORDER BY d.dive_date_time ASC
      ''',
            variables: [
              Variable.withString(tripId),
              Variable.withInt(startMs),
              Variable.withInt(endMs),
              Variable.withString(diverId),
              Variable.withString(tripId),
            ],
          )
          .get();

      if (rows.isEmpty) return [];

      // Load full dive objects
      final diveRepository = DiveRepository();
      final diveIds = rows.map((r) => r.data['dive_id'] as String).toList();
      final dives = await diveRepository.getDivesByIds(diveIds);

      // Build a map for quick lookup
      final diveMap = {for (final d in dives) d.id: d};

      // Build candidates, preserving order from query
      final candidates = <DiveCandidate>[];
      for (final row in rows) {
        final diveId = row.data['dive_id'] as String;
        final dive = diveMap[diveId];
        if (dive == null) continue;

        candidates.add(
          DiveCandidate(
            dive: dive,
            currentTripId: row.data['other_trip_id'] as String?,
            currentTripName: row.data['other_trip_name'] as String?,
          ),
        );
      }

      _log.info('Found ${candidates.length} candidate dives');
      return candidates;
    } catch (e, stackTrace) {
      _log.error('Failed to find candidate dives', e, stackTrace);
      rethrow;
    }
  }

  /// Batch assign multiple dives to a trip in a single transaction.
  Future<void> assignDivesToTrip(List<String> diveIds, String tripId) async {
    if (diveIds.isEmpty) return;

    try {
      _log.info('Batch assigning ${diveIds.length} dives to trip $tripId');
      final now = DateTime.now().millisecondsSinceEpoch;

      await _db.transaction(() async {
        for (final diveId in diveIds) {
          await _db.customUpdate(
            'UPDATE dives SET trip_id = ?, updated_at = ? WHERE id = ?',
            variables: [
              Variable.withString(tripId),
              Variable.withInt(now),
              Variable.withString(diveId),
            ],
            updates: {_db.dives},
          );
        }
      });

      // Mark dives as pending sync
      for (final diveId in diveIds) {
        await _syncRepository.markRecordPending(
          entityType: 'dives',
          recordId: diveId,
          localUpdatedAt: now,
        );
      }
      SyncEventBus.notifyLocalChange();

      _log.info('Batch assigned ${diveIds.length} dives to trip $tripId');
    } catch (e, stackTrace) {
      _log.error('Failed to batch assign dives to trip', e, stackTrace);
      rethrow;
    }
  }

  /// Get trip statistics
  Future<domain.TripWithStats> getTripWithStats(String tripId) async {
    final trip = await getTripById(tripId);
    if (trip == null) {
      throw Exception('Trip not found');
    }

    final statsResult = await _db
        .customSelect(
          '''
      SELECT
        COUNT(*) as dive_count,
        COALESCE(SUM(bottom_time), 0) as total_bottom_time,
        MAX(max_depth) as max_depth,
        AVG(max_depth) as avg_depth
      FROM dives
      WHERE trip_id = ?
    ''',
          variables: [Variable.withString(tripId)],
        )
        .getSingle();

    return domain.TripWithStats(
      trip: trip,
      diveCount: statsResult.data['dive_count'] as int? ?? 0,
      totalBottomTime: statsResult.data['total_bottom_time'] as int? ?? 0,
      maxDepth: statsResult.data['max_depth'] as double?,
      avgDepth: statsResult.data['avg_depth'] as double?,
    );
  }

  /// Find trip that contains a specific date
  Future<domain.Trip?> findTripForDate(DateTime date, {String? diverId}) async {
    final dateMs = date.millisecondsSinceEpoch;
    final diverFilter = diverId != null ? 'AND diver_id = ?' : '';
    final variables = [
      Variable.withInt(dateMs),
      Variable.withInt(dateMs),
      if (diverId != null) Variable.withString(diverId),
    ];

    final result = await _db.customSelect('''
      SELECT * FROM trips
      WHERE start_date <= ? AND end_date >= ?
      $diverFilter
      ORDER BY start_date DESC
      LIMIT 1
    ''', variables: variables).getSingleOrNull();

    if (result == null) return null;

    return domain.Trip(
      id: result.data['id'] as String,
      diverId: result.data['diver_id'] as String?,
      name: result.data['name'] as String,
      startDate: DateTime.fromMillisecondsSinceEpoch(
        result.data['start_date'] as int,
      ),
      endDate: DateTime.fromMillisecondsSinceEpoch(
        result.data['end_date'] as int,
      ),
      location: result.data['location'] as String?,
      resortName: result.data['resort_name'] as String?,
      liveaboardName: result.data['liveaboard_name'] as String?,
      notes: (result.data['notes'] as String?) ?? '',
      tripType: TripType.fromName(
        (result.data['trip_type'] as String?) ?? 'shore',
      ),
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        result.data['created_at'] as int,
      ),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        result.data['updated_at'] as int,
      ),
    );
  }

  /// Get all trips with their statistics
  Future<List<domain.TripWithStats>> getAllTripsWithStats({
    String? diverId,
  }) async {
    final diverFilter = diverId != null ? 'WHERE t.diver_id = ?' : '';
    final variables = diverId != null
        ? [Variable.withString(diverId)]
        : <Variable<Object>>[];

    final rows = await _db.customSelect('''
      SELECT
        t.*,
        COUNT(DISTINCT d.id) AS dive_count,
        COALESCE(SUM(d.bottom_time), 0) AS total_bottom_time,
        MAX(d.max_depth) AS max_depth,
        AVG(d.avg_depth) AS avg_depth
      FROM trips t
      LEFT JOIN dives d ON d.trip_id = t.id
      $diverFilter
      GROUP BY t.id
      ORDER BY t.start_date DESC
    ''', variables: variables).get();

    return rows.map((row) {
      final trip = domain.Trip(
        id: row.data['id'] as String,
        diverId: row.data['diver_id'] as String?,
        name: row.data['name'] as String,
        startDate: DateTime.fromMillisecondsSinceEpoch(
          row.data['start_date'] as int,
        ),
        endDate: DateTime.fromMillisecondsSinceEpoch(
          row.data['end_date'] as int,
        ),
        location: row.data['location'] as String?,
        resortName: row.data['resort_name'] as String?,
        liveaboardName: row.data['liveaboard_name'] as String?,
        notes: (row.data['notes'] as String?) ?? '',
        tripType: TripType.fromName(
          (row.data['trip_type'] as String?) ?? 'shore',
        ),
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          row.data['created_at'] as int,
        ),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(
          row.data['updated_at'] as int,
        ),
      );
      return domain.TripWithStats(
        trip: trip,
        diveCount: row.data['dive_count'] as int,
        totalBottomTime: row.data['total_bottom_time'] as int,
        maxDepth: row.data['max_depth'] as double?,
        avgDepth: row.data['avg_depth'] as double?,
      );
    }).toList();
  }

  domain.Trip _mapRowToTrip(Trip row) {
    return domain.Trip(
      id: row.id,
      diverId: row.diverId,
      name: row.name,
      startDate: DateTime.fromMillisecondsSinceEpoch(row.startDate),
      endDate: DateTime.fromMillisecondsSinceEpoch(row.endDate),
      location: row.location,
      resortName: row.resortName,
      liveaboardName: row.liveaboardName,
      notes: row.notes,
      tripType: TripType.fromName(row.tripType),
      createdAt: DateTime.fromMillisecondsSinceEpoch(row.createdAt),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(row.updatedAt),
    );
  }
}
