import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/database/database.dart' as db;
import '../../../../core/database/database.dart' show AppDatabase, DiveComputersCompanion, DiveProfilesCompanion, DiveProfileEventsCompanion, DivesCompanion, DiveProfile, DiveProfileEvent;
import '../../../../core/services/database_service.dart';
import '../../../../core/services/logger_service.dart';
import '../../domain/entities/dive_computer.dart' as domain;

/// Repository for managing dive computers and multi-profile support.
class DiveComputerRepository {
  final AppDatabase _db = DatabaseService.instance.database;
  final _uuid = const Uuid();
  final _log = LoggerService.forClass(DiveComputerRepository);

  // ============================================================================
  // CRUD Operations for Dive Computers
  // ============================================================================

  /// Get all dive computers
  Future<List<domain.DiveComputer>> getAllComputers({String? diverId}) async {
    try {
      final query = _db.select(_db.diveComputers)
        ..orderBy([
          (t) => OrderingTerm.desc(t.isFavorite),
          (t) => OrderingTerm.asc(t.name),
        ]);

      if (diverId != null) {
        query.where((t) => t.diverId.equals(diverId));
      }

      final rows = await query.get();
      return rows.map((row) => _mapRowToComputer(row)).toList();
    } catch (e, stackTrace) {
      _log.error('Failed to get all dive computers', e, stackTrace);
      rethrow;
    }
  }

  /// Get a dive computer by ID
  Future<domain.DiveComputer?> getComputerById(String id) async {
    try {
      final query = _db.select(_db.diveComputers)
        ..where((t) => t.id.equals(id));

      final row = await query.getSingleOrNull();
      return row != null ? _mapRowToComputer(row) : null;
    } catch (e, stackTrace) {
      _log.error('Failed to get dive computer by id: $id', e, stackTrace);
      rethrow;
    }
  }

  /// Get the favorite (primary) dive computer
  Future<domain.DiveComputer?> getFavoriteComputer({String? diverId}) async {
    try {
      final query = _db.select(_db.diveComputers)
        ..where((t) => t.isFavorite.equals(true))
        ..limit(1);

      if (diverId != null) {
        query.where((t) => t.diverId.equals(diverId));
      }

      final row = await query.getSingleOrNull();
      return row != null ? _mapRowToComputer(row) : null;
    } catch (e, stackTrace) {
      _log.error('Failed to get favorite dive computer', e, stackTrace);
      rethrow;
    }
  }

  /// Create a new dive computer
  Future<domain.DiveComputer> createComputer(domain.DiveComputer computer) async {
    try {
      _log.info('Creating dive computer: ${computer.name}');
      final id = computer.id.isEmpty ? _uuid.v4() : computer.id;
      final now = DateTime.now().millisecondsSinceEpoch;

      await _db.into(_db.diveComputers).insert(
            DiveComputersCompanion(
              id: Value(id),
              diverId: Value(computer.diverId),
              name: Value(computer.name),
              manufacturer: Value(computer.manufacturer),
              model: Value(computer.model),
              serialNumber: Value(computer.serialNumber),
              connectionType: Value(computer.connectionType),
              bluetoothAddress: Value(computer.bluetoothAddress),
              lastDownloadTimestamp:
                  Value(computer.lastDownload?.millisecondsSinceEpoch),
              diveCount: Value(computer.diveCount),
              isFavorite: Value(computer.isFavorite),
              notes: Value(computer.notes),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );

      _log.info('Created dive computer with id: $id');
      return computer.copyWith(
        id: id,
        createdAt: DateTime.fromMillisecondsSinceEpoch(now),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(now),
      );
    } catch (e, stackTrace) {
      _log.error('Failed to create dive computer', e, stackTrace);
      rethrow;
    }
  }

  /// Update an existing dive computer
  Future<void> updateComputer(domain.DiveComputer computer) async {
    try {
      _log.info('Updating dive computer: ${computer.id}');
      final now = DateTime.now().millisecondsSinceEpoch;

      await (_db.update(_db.diveComputers)
            ..where((t) => t.id.equals(computer.id)))
          .write(
        DiveComputersCompanion(
          name: Value(computer.name),
          manufacturer: Value(computer.manufacturer),
          model: Value(computer.model),
          serialNumber: Value(computer.serialNumber),
          connectionType: Value(computer.connectionType),
          bluetoothAddress: Value(computer.bluetoothAddress),
          lastDownloadTimestamp:
              Value(computer.lastDownload?.millisecondsSinceEpoch),
          diveCount: Value(computer.diveCount),
          isFavorite: Value(computer.isFavorite),
          notes: Value(computer.notes),
          updatedAt: Value(now),
        ),
      );

      _log.info('Updated dive computer: ${computer.id}');
    } catch (e, stackTrace) {
      _log.error('Failed to update dive computer: ${computer.id}', e, stackTrace);
      rethrow;
    }
  }

  /// Delete a dive computer
  Future<void> deleteComputer(String id) async {
    try {
      _log.info('Deleting dive computer: $id');
      await (_db.delete(_db.diveComputers)..where((t) => t.id.equals(id))).go();
      _log.info('Deleted dive computer: $id');
    } catch (e, stackTrace) {
      _log.error('Failed to delete dive computer: $id', e, stackTrace);
      rethrow;
    }
  }

  /// Set a computer as the favorite (clears other favorites first for the same diver)
  Future<void> setFavoriteComputer(String id, {String? diverId}) async {
    try {
      _log.info('Setting favorite computer: $id');

      // Clear all favorites for this diver (or all if no diverId)
      if (diverId != null) {
        await (_db.update(_db.diveComputers)..where((t) => t.diverId.equals(diverId))).write(
          const DiveComputersCompanion(isFavorite: Value(false)),
        );
      } else {
        await (_db.update(_db.diveComputers)).write(
          const DiveComputersCompanion(isFavorite: Value(false)),
        );
      }

      // Set the new favorite
      await (_db.update(_db.diveComputers)..where((t) => t.id.equals(id))).write(
        DiveComputersCompanion(
          isFavorite: const Value(true),
          updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
        ),
      );

      _log.info('Set favorite computer: $id');
    } catch (e, stackTrace) {
      _log.error('Failed to set favorite computer: $id', e, stackTrace);
      rethrow;
    }
  }

  /// Increment dive count for a computer
  Future<void> incrementDiveCount(String id, {int by = 1}) async {
    try {
      await _db.customStatement(
        '''
        UPDATE dive_computers
        SET dive_count = dive_count + ?,
            updated_at = ?
        WHERE id = ?
      ''',
        [by, DateTime.now().millisecondsSinceEpoch, id],
      );
    } catch (e, stackTrace) {
      _log.error('Failed to increment dive count for: $id', e, stackTrace);
      rethrow;
    }
  }

  /// Update last download timestamp
  Future<void> updateLastDownload(String id) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      await (_db.update(_db.diveComputers)..where((t) => t.id.equals(id))).write(
        DiveComputersCompanion(
          lastDownloadTimestamp: Value(now),
          updatedAt: Value(now),
        ),
      );
    } catch (e, stackTrace) {
      _log.error('Failed to update last download for: $id', e, stackTrace);
      rethrow;
    }
  }

  // ============================================================================
  // Multi-Profile Operations
  // ============================================================================

  /// Get all profile points for a dive, optionally filtered by computer
  Future<List<DiveProfile>> getProfilesForDive(
    String diveId, {
    String? computerId,
  }) async {
    try {
      final query = _db.select(_db.diveProfiles)
        ..where((t) => t.diveId.equals(diveId))
        ..orderBy([(t) => OrderingTerm.asc(t.timestamp)]);

      if (computerId != null) {
        query.where((t) => t.computerId.equals(computerId));
      }

      return await query.get();
    } catch (e, stackTrace) {
      _log.error('Failed to get profiles for dive: $diveId', e, stackTrace);
      rethrow;
    }
  }

  /// Get all computer IDs that have profiles for a given dive
  Future<List<String>> getComputerIdsForDive(String diveId) async {
    try {
      final result = await _db.customSelect(
        '''
        SELECT DISTINCT computer_id
        FROM dive_profiles
        WHERE dive_id = ? AND computer_id IS NOT NULL
      ''',
        variables: [Variable(diveId)],
      ).get();

      return result
          .map((row) => row.data['computer_id'] as String?)
          .whereType<String>()
          .toList();
    } catch (e, stackTrace) {
      _log.error('Failed to get computer ids for dive: $diveId', e, stackTrace);
      rethrow;
    }
  }

  /// Get computers with profiles for a given dive
  Future<List<domain.DiveComputer>> getComputersForDive(String diveId) async {
    try {
      final computerIds = await getComputerIdsForDive(diveId);
      if (computerIds.isEmpty) return [];

      final query = _db.select(_db.diveComputers)
        ..where((t) => t.id.isIn(computerIds));

      final rows = await query.get();
      return rows.map((row) => _mapRowToComputer(row)).toList();
    } catch (e, stackTrace) {
      _log.error('Failed to get computers for dive: $diveId', e, stackTrace);
      rethrow;
    }
  }

  /// Get the primary profile's computer for a dive
  Future<String?> getPrimaryComputerId(String diveId) async {
    try {
      final result = await _db.customSelect(
        '''
        SELECT DISTINCT computer_id
        FROM dive_profiles
        WHERE dive_id = ? AND is_primary = 1 AND computer_id IS NOT NULL
        LIMIT 1
      ''',
        variables: [Variable(diveId)],
      ).getSingleOrNull();

      return result?.data['computer_id'] as String?;
    } catch (e, stackTrace) {
      _log.error('Failed to get primary computer for dive: $diveId', e, stackTrace);
      return null;
    }
  }

  /// Set the primary profile for a dive (by computer ID)
  Future<void> setPrimaryProfile(String diveId, String computerId) async {
    try {
      _log.info('Setting primary profile for dive $diveId to computer $computerId');

      // Clear all primary flags for this dive
      await _db.customStatement(
        '''
        UPDATE dive_profiles
        SET is_primary = 0
        WHERE dive_id = ?
      ''',
        [diveId],
      );

      // Set the new primary
      await _db.customStatement(
        '''
        UPDATE dive_profiles
        SET is_primary = 1
        WHERE dive_id = ? AND computer_id = ?
      ''',
        [diveId, computerId],
      );

      _log.info('Set primary profile for dive $diveId');
    } catch (e, stackTrace) {
      _log.error('Failed to set primary profile for dive: $diveId', e, stackTrace);
      rethrow;
    }
  }

  // ============================================================================
  // Profile Import and Matching
  // ============================================================================

  /// Find a dive that matches a profile's timestamp within a tolerance window.
  /// Used during import to associate profiles with existing dives.
  ///
  /// [profileStartTime] - The start time of the profile being imported
  /// [toleranceMinutes] - Time window for matching (default 5 minutes)
  /// [durationSeconds] - Expected duration to help with matching
  Future<String?> findMatchingDive({
    required DateTime profileStartTime,
    int toleranceMinutes = 5,
    int? durationSeconds,
  }) async {
    try {
      final startMs = profileStartTime.millisecondsSinceEpoch;
      final toleranceMs = toleranceMinutes * 60 * 1000;

      // Search for dives within the tolerance window
      final result = await _db.customSelect(
        '''
        SELECT id, dive_date_time, entry_time, duration, ABS(
          COALESCE(entry_time, dive_date_time) - ?
        ) as time_diff
        FROM dives
        WHERE ABS(COALESCE(entry_time, dive_date_time) - ?) <= ?
        ORDER BY time_diff ASC
        LIMIT 5
      ''',
        variables: [
          Variable(startMs),
          Variable(startMs),
          Variable(toleranceMs),
        ],
      ).get();

      if (result.isEmpty) return null;

      // If we have duration info, prefer the dive with closest matching duration
      if (durationSeconds != null && result.length > 1) {
        for (final row in result) {
          final diveDuration = row.data['duration'] as int?;
          if (diveDuration != null) {
            final durationDiff = (diveDuration - durationSeconds).abs();
            // Within 2 minutes of expected duration
            if (durationDiff <= 120) {
              return row.data['id'] as String;
            }
          }
        }
      }

      // Return the closest time match
      return result.first.data['id'] as String;
    } catch (e, stackTrace) {
      _log.error('Failed to find matching dive for profile', e, stackTrace);
      return null;
    }
  }

  /// Import a profile and associate it with a dive (creating one if needed).
  ///
  /// Returns the dive ID the profile was associated with.
  Future<String> importProfile({
    required String computerId,
    required DateTime profileStartTime,
    required List<ProfilePointData> points,
    required int durationSeconds,
    double? maxDepth,
    bool isPrimary = false,
  }) async {
    try {
      _log.info('Importing profile from computer $computerId');

      // Try to find an existing dive
      String? diveId = await findMatchingDive(
        profileStartTime: profileStartTime,
        durationSeconds: durationSeconds,
      );

      if (diveId == null) {
        // Create a new dive for this profile
        _log.info('No matching dive found, creating new dive');
        diveId = _uuid.v4();
        final now = DateTime.now().millisecondsSinceEpoch;

        await _db.into(_db.dives).insert(
              DivesCompanion(
                id: Value(diveId),
                diveDateTime: Value(profileStartTime.millisecondsSinceEpoch),
                entryTime: Value(profileStartTime.millisecondsSinceEpoch),
                duration: Value(durationSeconds),
                maxDepth: Value(maxDepth),
                createdAt: Value(now),
                updatedAt: Value(now),
              ),
            );

        isPrimary = true; // First profile is always primary
      }

      // Check if this computer already has a profile for this dive
      final existingProfiles = await _db.customSelect(
        '''
        SELECT COUNT(*) as count
        FROM dive_profiles
        WHERE dive_id = ? AND computer_id = ?
      ''',
        variables: [Variable(diveId), Variable(computerId)],
      ).getSingle();

      if ((existingProfiles.data['count'] as int) > 0) {
        _log.info('Profile from this computer already exists for dive $diveId');
        return diveId;
      }

      // If this dive has no profiles yet, make this one primary
      final hasProfiles = await _db.customSelect(
        'SELECT COUNT(*) as count FROM dive_profiles WHERE dive_id = ?',
        variables: [Variable(diveId)],
      ).getSingle();

      if ((hasProfiles.data['count'] as int) == 0) {
        isPrimary = true;
      }

      // Insert profile points
      for (final point in points) {
        await _db.into(_db.diveProfiles).insert(
              DiveProfilesCompanion(
                id: Value(_uuid.v4()),
                diveId: Value(diveId),
                computerId: Value(computerId),
                timestamp: Value(point.timestamp),
                depth: Value(point.depth),
                pressure: Value(point.pressure),
                temperature: Value(point.temperature),
                heartRate: Value(point.heartRate),
                isPrimary: Value(isPrimary),
              ),
            );
      }

      // Update computer stats
      await incrementDiveCount(computerId);
      await updateLastDownload(computerId);

      _log.info('Imported ${points.length} profile points for dive $diveId');
      return diveId;
    } catch (e, stackTrace) {
      _log.error('Failed to import profile', e, stackTrace);
      rethrow;
    }
  }

  /// Find or create a dive computer by serial number and model
  Future<domain.DiveComputer> findOrCreateComputer({
    required String serialNumber,
    String? diverId,
    String? manufacturer,
    String? model,
    String? connectionType,
  }) async {
    try {
      // Try to find existing computer for this diver
      final query = _db.select(_db.diveComputers)
        ..where((t) => t.serialNumber.equals(serialNumber));

      if (diverId != null) {
        query.where((t) => t.diverId.equals(diverId));
      }

      final existing = await query.getSingleOrNull();
      if (existing != null) {
        return _mapRowToComputer(existing);
      }

      // Create new computer
      final now = DateTime.now();
      final name = model != null
          ? (manufacturer != null ? '$manufacturer $model' : model)
          : 'Dive Computer';

      final computer = domain.DiveComputer(
        id: _uuid.v4(),
        diverId: diverId,
        name: name,
        manufacturer: manufacturer,
        model: model,
        serialNumber: serialNumber,
        connectionType: connectionType,
        createdAt: now,
        updatedAt: now,
      );

      return await createComputer(computer);
    } catch (e, stackTrace) {
      _log.error('Failed to find or create computer', e, stackTrace);
      rethrow;
    }
  }

  // ============================================================================
  // Profile Event Operations
  // ============================================================================

  /// Get all events for a dive
  Future<List<DiveProfileEvent>> getEventsForDive(String diveId) async {
    try {
      final query = _db.select(_db.diveProfileEvents)
        ..where((t) => t.diveId.equals(diveId))
        ..orderBy([(t) => OrderingTerm.asc(t.timestamp)]);

      return await query.get();
    } catch (e, stackTrace) {
      _log.error('Failed to get events for dive: $diveId', e, stackTrace);
      rethrow;
    }
  }

  /// Add an event to a dive profile
  Future<void> addProfileEvent({
    required String diveId,
    required int timestamp,
    required String eventType,
    String severity = 'info',
    String? description,
    double? depth,
    double? value,
    String? tankId,
  }) async {
    try {
      await _db.into(_db.diveProfileEvents).insert(
            DiveProfileEventsCompanion(
              id: Value(_uuid.v4()),
              diveId: Value(diveId),
              timestamp: Value(timestamp),
              eventType: Value(eventType),
              severity: Value(severity),
              description: Value(description),
              depth: Value(depth),
              value: Value(value),
              tankId: Value(tankId),
            ),
          );
    } catch (e, stackTrace) {
      _log.error('Failed to add profile event', e, stackTrace);
      rethrow;
    }
  }

  /// Delete all events for a dive
  Future<void> clearEventsForDive(String diveId) async {
    try {
      await (_db.delete(_db.diveProfileEvents)
            ..where((t) => t.diveId.equals(diveId)))
          .go();
    } catch (e, stackTrace) {
      _log.error('Failed to clear events for dive: $diveId', e, stackTrace);
      rethrow;
    }
  }

  // ============================================================================
  // Mapping Helpers
  // ============================================================================

  domain.DiveComputer _mapRowToComputer(db.DiveComputer row) {
    return domain.DiveComputer(
      id: row.id,
      diverId: row.diverId,
      name: row.name,
      manufacturer: row.manufacturer,
      model: row.model,
      serialNumber: row.serialNumber,
      connectionType: row.connectionType,
      bluetoothAddress: row.bluetoothAddress,
      lastDownload: row.lastDownloadTimestamp != null
          ? DateTime.fromMillisecondsSinceEpoch(row.lastDownloadTimestamp!)
          : null,
      diveCount: row.diveCount,
      isFavorite: row.isFavorite,
      notes: row.notes,
      createdAt: DateTime.fromMillisecondsSinceEpoch(row.createdAt),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(row.updatedAt),
    );
  }
}

/// Data class for importing profile points
class ProfilePointData {
  final int timestamp;
  final double depth;
  final double? pressure;
  final double? temperature;
  final int? heartRate;

  const ProfilePointData({
    required this.timestamp,
    required this.depth,
    this.pressure,
    this.temperature,
    this.heartRate,
  });
}
