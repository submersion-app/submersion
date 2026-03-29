import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/features/trips/domain/entities/liveaboard_details.dart'
    as domain;

class LiveaboardDetailsRepository {
  AppDatabase get _db => DatabaseService.instance.database;
  final SyncRepository _syncRepository = SyncRepository();
  final _uuid = const Uuid();
  final _log = LoggerService.forClass(LiveaboardDetailsRepository);

  /// Get liveaboard details for a trip, or null if none exist.
  Future<domain.LiveaboardDetails?> getByTripId(String tripId) async {
    try {
      _log.info('Getting liveaboard details for trip: $tripId');
      final query = _db.select(_db.liveaboardDetailRecords)
        ..where((t) => t.tripId.equals(tripId));
      final row = await query.getSingleOrNull();
      final result = row != null ? _mapRow(row) : null;
      _log.info(
        'Liveaboard details for trip $tripId: ${result != null ? 'found' : 'not found'}',
      );
      return result;
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get liveaboard details for trip: $tripId',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Create or update liveaboard details for a trip.
  Future<domain.LiveaboardDetails> createOrUpdate(
    domain.LiveaboardDetails details,
  ) async {
    try {
      final now = DateTime.now();
      final existing = await getByTripId(details.tripId);

      if (existing != null) {
        // UPDATE: preserve createdAt, only change updatedAt
        _log.info('Updating liveaboard details for trip: ${details.tripId}');
        await (_db.update(
          _db.liveaboardDetailRecords,
        )..where((t) => t.id.equals(existing.id))).write(
          LiveaboardDetailRecordsCompanion(
            vesselName: Value(details.vesselName),
            operatorName: Value(details.operatorName),
            vesselType: Value(details.vesselType),
            cabinType: Value(details.cabinType),
            capacity: Value(details.capacity),
            embarkPort: Value(details.embarkPort),
            embarkLatitude: Value(details.embarkLatitude),
            embarkLongitude: Value(details.embarkLongitude),
            disembarkPort: Value(details.disembarkPort),
            disembarkLatitude: Value(details.disembarkLatitude),
            disembarkLongitude: Value(details.disembarkLongitude),
            updatedAt: Value(now.millisecondsSinceEpoch),
          ),
        );

        await _syncRepository.markRecordPending(
          entityType: 'liveaboardDetails',
          recordId: existing.id,
          localUpdatedAt: now.millisecondsSinceEpoch,
        );
        SyncEventBus.notifyLocalChange();

        _log.info('Updated liveaboard details for trip: ${details.tripId}');
        return details.copyWith(
          id: existing.id,
          createdAt: existing.createdAt,
          updatedAt: now,
        );
      } else {
        // INSERT: set both timestamps
        final id = details.id.isEmpty ? _uuid.v4() : details.id;
        _log.info('Creating liveaboard details for trip: ${details.tripId}');

        await _db
            .into(_db.liveaboardDetailRecords)
            .insert(
              LiveaboardDetailRecordsCompanion(
                id: Value(id),
                tripId: Value(details.tripId),
                vesselName: Value(details.vesselName),
                operatorName: Value(details.operatorName),
                vesselType: Value(details.vesselType),
                cabinType: Value(details.cabinType),
                capacity: Value(details.capacity),
                embarkPort: Value(details.embarkPort),
                embarkLatitude: Value(details.embarkLatitude),
                embarkLongitude: Value(details.embarkLongitude),
                disembarkPort: Value(details.disembarkPort),
                disembarkLatitude: Value(details.disembarkLatitude),
                disembarkLongitude: Value(details.disembarkLongitude),
                createdAt: Value(now.millisecondsSinceEpoch),
                updatedAt: Value(now.millisecondsSinceEpoch),
              ),
            );

        await _syncRepository.markRecordPending(
          entityType: 'liveaboardDetails',
          recordId: id,
          localUpdatedAt: now.millisecondsSinceEpoch,
        );
        SyncEventBus.notifyLocalChange();

        _log.info('Created liveaboard details for trip: ${details.tripId}');
        return details.copyWith(id: id, createdAt: now, updatedAt: now);
      }
    } catch (e, stackTrace) {
      _log.error(
        'Failed to create/update liveaboard details',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Delete liveaboard details for a trip. No-op if none exist.
  Future<void> deleteByTripId(String tripId) async {
    try {
      _log.info('Deleting liveaboard details for trip: $tripId');
      final existing = await getByTripId(tripId);
      if (existing == null) {
        _log.info(
          'No liveaboard details found for trip $tripId, skipping delete',
        );
        return;
      }

      await (_db.delete(
        _db.liveaboardDetailRecords,
      )..where((t) => t.tripId.equals(tripId))).go();
      await _syncRepository.logDeletion(
        entityType: 'liveaboardDetails',
        recordId: existing.id,
      );
      SyncEventBus.notifyLocalChange();
      _log.info('Deleted liveaboard details for trip: $tripId');
    } catch (e, stackTrace) {
      _log.error(
        'Failed to delete liveaboard details for trip: $tripId',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  domain.LiveaboardDetails _mapRow(LiveaboardDetailRecord row) {
    return domain.LiveaboardDetails(
      id: row.id,
      tripId: row.tripId,
      vesselName: row.vesselName,
      operatorName: row.operatorName,
      vesselType: row.vesselType,
      cabinType: row.cabinType,
      capacity: row.capacity,
      embarkPort: row.embarkPort,
      embarkLatitude: row.embarkLatitude,
      embarkLongitude: row.embarkLongitude,
      disembarkPort: row.disembarkPort,
      disembarkLatitude: row.disembarkLatitude,
      disembarkLongitude: row.disembarkLongitude,
      createdAt: DateTime.fromMillisecondsSinceEpoch(row.createdAt),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(row.updatedAt),
    );
  }
}
