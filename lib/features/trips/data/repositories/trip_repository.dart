import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/database/database.dart';
import '../../../../core/services/database_service.dart';
import '../../../../core/services/logger_service.dart';
import '../../domain/entities/trip.dart' as domain;

class TripRepository {
  final AppDatabase _db = DatabaseService.instance.database;
  final _uuid = const Uuid();
  final _log = LoggerService.forClass(TripRepository);

  /// Get all trips ordered by start date (most recent first)
  Future<List<domain.Trip>> getAllTrips() async {
    try {
      final query = _db.select(_db.trips)
        ..orderBy([(t) => OrderingTerm.desc(t.startDate)]);

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
  Future<List<domain.Trip>> searchTrips(String query) async {
    final searchTerm = '%${query.toLowerCase()}%';

    final results = await _db.customSelect('''
      SELECT * FROM trips
      WHERE LOWER(name) LIKE ?
         OR LOWER(location) LIKE ?
         OR LOWER(resort_name) LIKE ?
         OR LOWER(liveaboard_name) LIKE ?
      ORDER BY start_date DESC
    ''', variables: [
      Variable.withString(searchTerm),
      Variable.withString(searchTerm),
      Variable.withString(searchTerm),
      Variable.withString(searchTerm),
    ]).get();

    return results.map((row) {
      return domain.Trip(
        id: row.data['id'] as String,
        name: row.data['name'] as String,
        startDate:
            DateTime.fromMillisecondsSinceEpoch(row.data['start_date'] as int),
        endDate:
            DateTime.fromMillisecondsSinceEpoch(row.data['end_date'] as int),
        location: row.data['location'] as String?,
        resortName: row.data['resort_name'] as String?,
        liveaboardName: row.data['liveaboard_name'] as String?,
        notes: (row.data['notes'] as String?) ?? '',
        createdAt:
            DateTime.fromMillisecondsSinceEpoch(row.data['created_at'] as int),
        updatedAt:
            DateTime.fromMillisecondsSinceEpoch(row.data['updated_at'] as int),
      );
    }).toList();
  }

  /// Create a new trip
  Future<domain.Trip> createTrip(domain.Trip trip) async {
    try {
      _log.info('Creating trip: ${trip.name}');
      final id = trip.id.isEmpty ? _uuid.v4() : trip.id;
      final now = DateTime.now();

      await _db.into(_db.trips).insert(TripsCompanion(
            id: Value(id),
            name: Value(trip.name),
            startDate: Value(trip.startDate.millisecondsSinceEpoch),
            endDate: Value(trip.endDate.millisecondsSinceEpoch),
            location: Value(trip.location),
            resortName: Value(trip.resortName),
            liveaboardName: Value(trip.liveaboardName),
            notes: Value(trip.notes),
            createdAt: Value(now.millisecondsSinceEpoch),
            updatedAt: Value(now.millisecondsSinceEpoch),
          ));

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
          updatedAt: Value(now),
        ),
      );
      _log.info('Updated trip: ${trip.id}');
    } catch (e, stackTrace) {
      _log.error('Failed to update trip: ${trip.id}', e, stackTrace);
      rethrow;
    }
  }

  /// Delete a trip (sets trip_id to null on associated dives)
  Future<void> deleteTrip(String id) async {
    try {
      _log.info('Deleting trip: $id');

      // First, remove trip association from dives
      await _db.customStatement('''
        UPDATE dives SET trip_id = NULL WHERE trip_id = ?
      ''', [Variable.withString(id)]);

      // Then delete the trip
      await (_db.delete(_db.trips)..where((t) => t.id.equals(id))).go();
      _log.info('Deleted trip: $id');
    } catch (e, stackTrace) {
      _log.error('Failed to delete trip: $id', e, stackTrace);
      rethrow;
    }
  }

  /// Get dives for a specific trip
  Future<List<String>> getDiveIdsForTrip(String tripId) async {
    final results = await _db.customSelect('''
      SELECT id FROM dives
      WHERE trip_id = ?
      ORDER BY dive_date_time DESC
    ''', variables: [Variable.withString(tripId)]).get();

    return results.map((row) => row.data['id'] as String).toList();
  }

  /// Get dive count for a trip
  Future<int> getDiveCountForTrip(String tripId) async {
    final result = await _db.customSelect('''
      SELECT COUNT(*) as count
      FROM dives
      WHERE trip_id = ?
    ''', variables: [Variable.withString(tripId)]).getSingle();

    return result.data['count'] as int? ?? 0;
  }

  /// Assign a dive to a trip
  Future<void> assignDiveToTrip(String diveId, String tripId) async {
    try {
      _log.info('Assigning dive $diveId to trip $tripId');
      await _db.customStatement('''
        UPDATE dives SET trip_id = ? WHERE id = ?
      ''', [Variable.withString(tripId), Variable.withString(diveId)]);
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
      await _db.customStatement('''
        UPDATE dives SET trip_id = NULL WHERE id = ?
      ''', [Variable.withString(diveId)]);
      _log.info('Removed dive from trip');
    } catch (e, stackTrace) {
      _log.error('Failed to remove dive from trip', e, stackTrace);
      rethrow;
    }
  }

  /// Get trip statistics
  Future<domain.TripWithStats> getTripWithStats(String tripId) async {
    final trip = await getTripById(tripId);
    if (trip == null) {
      throw Exception('Trip not found');
    }

    final statsResult = await _db.customSelect('''
      SELECT
        COUNT(*) as dive_count,
        COALESCE(SUM(duration), 0) as total_bottom_time,
        MAX(max_depth) as max_depth,
        AVG(max_depth) as avg_depth
      FROM dives
      WHERE trip_id = ?
    ''', variables: [Variable.withString(tripId)]).getSingle();

    return domain.TripWithStats(
      trip: trip,
      diveCount: statsResult.data['dive_count'] as int? ?? 0,
      totalBottomTime: statsResult.data['total_bottom_time'] as int? ?? 0,
      maxDepth: statsResult.data['max_depth'] as double?,
      avgDepth: statsResult.data['avg_depth'] as double?,
    );
  }

  /// Find trip that contains a specific date
  Future<domain.Trip?> findTripForDate(DateTime date) async {
    final dateMs = date.millisecondsSinceEpoch;

    final result = await _db.customSelect('''
      SELECT * FROM trips
      WHERE start_date <= ? AND end_date >= ?
      ORDER BY start_date DESC
      LIMIT 1
    ''', variables: [
      Variable.withInt(dateMs),
      Variable.withInt(dateMs),
    ]).getSingleOrNull();

    if (result == null) return null;

    return domain.Trip(
      id: result.data['id'] as String,
      name: result.data['name'] as String,
      startDate:
          DateTime.fromMillisecondsSinceEpoch(result.data['start_date'] as int),
      endDate:
          DateTime.fromMillisecondsSinceEpoch(result.data['end_date'] as int),
      location: result.data['location'] as String?,
      resortName: result.data['resort_name'] as String?,
      liveaboardName: result.data['liveaboard_name'] as String?,
      notes: (result.data['notes'] as String?) ?? '',
      createdAt:
          DateTime.fromMillisecondsSinceEpoch(result.data['created_at'] as int),
      updatedAt:
          DateTime.fromMillisecondsSinceEpoch(result.data['updated_at'] as int),
    );
  }

  /// Get all trips with their statistics
  Future<List<domain.TripWithStats>> getAllTripsWithStats() async {
    // Example assumes statistics are: number of dives and total expenses per trip.
    // Adjust the JOINs and aggregations as needed for your schema.
    final rows = await _db.customSelect('''
      SELECT 
        t.*, 
        COUNT(DISTINCT d.id) AS dive_count,
        COALESCE(SUM(e.amount), 0) AS total_expenses
      FROM trips t
      LEFT JOIN dives d ON d.trip_id = t.id
      LEFT JOIN expenses e ON e.trip_id = t.id
      GROUP BY t.id
      ORDER BY t.start_date DESC
    ''').get();

    return rows.map((row) {
      final trip = domain.Trip(
        id: row.data['id'] as String,
        name: row.data['name'] as String,
        startDate: DateTime.fromMillisecondsSinceEpoch(row.data['start_date'] as int),
        endDate: DateTime.fromMillisecondsSinceEpoch(row.data['end_date'] as int),
        location: row.data['location'] as String?,
        resortName: row.data['resort_name'] as String?,
        liveaboardName: row.data['liveaboard_name'] as String?,
        notes: (row.data['notes'] as String?) ?? '',
        createdAt: DateTime.fromMillisecondsSinceEpoch(row.data['created_at'] as int),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(row.data['updated_at'] as int),
      );
      // Adjust the following according to your TripWithStats constructor
      return domain.TripWithStats(
        trip: trip,
        diveCount: row.data['dive_count'] as int,
        totalExpenses: (row.data['total_expenses'] as num).toDouble(),
      );
    }).toList();
  }

  domain.Trip _mapRowToTrip(Trip row) {
    return domain.Trip(
      id: row.id,
      name: row.name,
      startDate: DateTime.fromMillisecondsSinceEpoch(row.startDate),
      endDate: DateTime.fromMillisecondsSinceEpoch(row.endDate),
      location: row.location,
      resortName: row.resortName,
      liveaboardName: row.liveaboardName,
      notes: row.notes,
      createdAt: DateTime.fromMillisecondsSinceEpoch(row.createdAt),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(row.updatedAt),
    );
  }
}
