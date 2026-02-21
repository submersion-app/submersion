import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart' as db;
import 'package:submersion/core/database/database.dart'
    show
        AppDatabase,
        DiveComputersCompanion,
        DiveProfilesCompanion,
        DiveProfileEventsCompanion,
        DivesCompanion,
        DiveTanksCompanion,
        DiveProfile,
        DiveProfileEvent,
        TankPressureProfilesCompanion;
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_computer.dart'
    as domain;

/// Repository for managing dive computers and multi-profile support.
class DiveComputerRepository {
  AppDatabase get _db => DatabaseService.instance.database;
  final SyncRepository _syncRepository = SyncRepository();
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
  Future<domain.DiveComputer> createComputer(
    domain.DiveComputer computer,
  ) async {
    try {
      _log.info('Creating dive computer: ${computer.name}');
      final id = computer.id.isEmpty ? _uuid.v4() : computer.id;
      final now = DateTime.now().millisecondsSinceEpoch;

      await _db
          .into(_db.diveComputers)
          .insert(
            DiveComputersCompanion(
              id: Value(id),
              diverId: Value(computer.diverId),
              name: Value(computer.name),
              manufacturer: Value(computer.manufacturer),
              model: Value(computer.model),
              serialNumber: Value(computer.serialNumber),
              firmwareVersion: Value(computer.firmwareVersion),
              connectionType: Value(computer.connectionType),
              bluetoothAddress: Value(computer.bluetoothAddress),
              lastDownloadTimestamp: Value(
                computer.lastDownload?.millisecondsSinceEpoch,
              ),
              diveCount: Value(computer.diveCount),
              isFavorite: Value(computer.isFavorite),
              notes: Value(computer.notes),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );

      await _syncRepository.markRecordPending(
        entityType: 'diveComputers',
        recordId: id,
        localUpdatedAt: now,
      );
      SyncEventBus.notifyLocalChange();

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

      await (_db.update(
        _db.diveComputers,
      )..where((t) => t.id.equals(computer.id))).write(
        DiveComputersCompanion(
          name: Value(computer.name),
          manufacturer: Value(computer.manufacturer),
          model: Value(computer.model),
          serialNumber: Value(computer.serialNumber),
          firmwareVersion: Value(computer.firmwareVersion),
          connectionType: Value(computer.connectionType),
          bluetoothAddress: Value(computer.bluetoothAddress),
          lastDownloadTimestamp: Value(
            computer.lastDownload?.millisecondsSinceEpoch,
          ),
          diveCount: Value(computer.diveCount),
          isFavorite: Value(computer.isFavorite),
          notes: Value(computer.notes),
          updatedAt: Value(now),
        ),
      );

      await _syncRepository.markRecordPending(
        entityType: 'diveComputers',
        recordId: computer.id,
        localUpdatedAt: now,
      );
      SyncEventBus.notifyLocalChange();

      _log.info('Updated dive computer: ${computer.id}');
    } catch (e, stackTrace) {
      _log.error(
        'Failed to update dive computer: ${computer.id}',
        e,
        stackTrace,
      );
      rethrow;
    }
  }

  /// Delete a dive computer
  Future<void> deleteComputer(String id) async {
    try {
      _log.info('Deleting dive computer: $id');
      await (_db.delete(_db.diveComputers)..where((t) => t.id.equals(id))).go();
      await _syncRepository.logDeletion(
        entityType: 'diveComputers',
        recordId: id,
      );
      SyncEventBus.notifyLocalChange();
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
      final now = DateTime.now().millisecondsSinceEpoch;

      // Clear all favorites for this diver (or all if no diverId)
      if (diverId != null) {
        await (_db.update(
          _db.diveComputers,
        )..where((t) => t.diverId.equals(diverId))).write(
          DiveComputersCompanion(
            isFavorite: const Value(false),
            updatedAt: Value(now),
          ),
        );
      } else {
        await (_db.update(_db.diveComputers)).write(
          DiveComputersCompanion(
            isFavorite: const Value(false),
            updatedAt: Value(now),
          ),
        );
      }

      // Set the new favorite
      await (_db.update(
        _db.diveComputers,
      )..where((t) => t.id.equals(id))).write(
        DiveComputersCompanion(
          isFavorite: const Value(true),
          updatedAt: Value(now),
        ),
      );

      final updated = await _db.select(_db.diveComputers).get();
      for (final row in updated) {
        await _syncRepository.markRecordPending(
          entityType: 'diveComputers',
          recordId: row.id,
          localUpdatedAt: now,
        );
      }
      SyncEventBus.notifyLocalChange();

      _log.info('Set favorite computer: $id');
    } catch (e, stackTrace) {
      _log.error('Failed to set favorite computer: $id', e, stackTrace);
      rethrow;
    }
  }

  /// Increment dive count for a computer
  Future<void> incrementDiveCount(String id, {int by = 1}) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      await _db.customStatement(
        '''
        UPDATE dive_computers
        SET dive_count = dive_count + ?,
            updated_at = ?
        WHERE id = ?
      ''',
        [by, now, id],
      );
      await _syncRepository.markRecordPending(
        entityType: 'diveComputers',
        recordId: id,
        localUpdatedAt: now,
      );
      SyncEventBus.notifyLocalChange();
    } catch (e, stackTrace) {
      _log.error('Failed to increment dive count for: $id', e, stackTrace);
      rethrow;
    }
  }

  /// Update last download timestamp
  Future<void> updateLastDownload(String id) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      await (_db.update(
        _db.diveComputers,
      )..where((t) => t.id.equals(id))).write(
        DiveComputersCompanion(
          lastDownloadTimestamp: Value(now),
          updatedAt: Value(now),
        ),
      );
      await _syncRepository.markRecordPending(
        entityType: 'diveComputers',
        recordId: id,
        localUpdatedAt: now,
      );
      SyncEventBus.notifyLocalChange();
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
      final result = await _db
          .customSelect(
            '''
        SELECT DISTINCT computer_id
        FROM dive_profiles
        WHERE dive_id = ? AND computer_id IS NOT NULL
      ''',
            variables: [Variable(diveId)],
          )
          .get();

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
      final result = await _db
          .customSelect(
            '''
        SELECT DISTINCT computer_id
        FROM dive_profiles
        WHERE dive_id = ? AND is_primary = 1 AND computer_id IS NOT NULL
        LIMIT 1
      ''',
            variables: [Variable(diveId)],
          )
          .getSingleOrNull();

      return result?.data['computer_id'] as String?;
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get primary computer for dive: $diveId',
        e,
        stackTrace,
      );
      return null;
    }
  }

  /// Set the primary profile for a dive (by computer ID)
  Future<void> setPrimaryProfile(String diveId, String computerId) async {
    try {
      _log.info(
        'Setting primary profile for dive $diveId to computer $computerId',
      );
      final now = DateTime.now().millisecondsSinceEpoch;

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

      final profiles = await (_db.select(
        _db.diveProfiles,
      )..where((t) => t.diveId.equals(diveId))).get();
      for (final profile in profiles) {
        await _syncRepository.markRecordPending(
          entityType: 'diveProfiles',
          recordId: profile.id,
          localUpdatedAt: now,
        );
      }

      await (_db.update(_db.dives)..where((t) => t.id.equals(diveId))).write(
        DivesCompanion(updatedAt: Value(now)),
      );
      await _syncRepository.markRecordPending(
        entityType: 'dives',
        recordId: diveId,
        localUpdatedAt: now,
      );
      SyncEventBus.notifyLocalChange();

      _log.info('Set primary profile for dive $diveId');
    } catch (e, stackTrace) {
      _log.error(
        'Failed to set primary profile for dive: $diveId',
        e,
        stackTrace,
      );
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
  /// [maxDepth] - Maximum depth to help with matching
  Future<String?> findMatchingDive({
    required DateTime profileStartTime,
    int toleranceMinutes = 5,
    int? durationSeconds,
    double? maxDepth,
  }) async {
    try {
      final match = await findMatchingDiveWithScore(
        profileStartTime: profileStartTime,
        toleranceMinutes: toleranceMinutes,
        durationSeconds: durationSeconds,
        maxDepth: maxDepth,
      );
      return match?.diveId;
    } catch (e, stackTrace) {
      _log.error('Failed to find matching dive for profile', e, stackTrace);
      return null;
    }
  }

  /// Find a dive that matches with detailed scoring information.
  /// Returns a [DiveMatchResult] with the match details, or null if no match.
  Future<DiveMatchResult?> findMatchingDiveWithScore({
    required DateTime profileStartTime,
    int toleranceMinutes = 5,
    int? durationSeconds,
    double? maxDepth,
    String? fingerprint,
  }) async {
    try {
      final startMs = profileStartTime.millisecondsSinceEpoch;
      final toleranceMs = toleranceMinutes * 60 * 1000;

      // Search for dives within the tolerance window
      final result = await _db
          .customSelect(
            '''
        SELECT id, dive_date_time, entry_time, duration, max_depth,
          COALESCE(entry_time, dive_date_time) as effective_time,
          ABS(COALESCE(entry_time, dive_date_time) - ?) as time_diff
        FROM dives
        WHERE ABS(COALESCE(entry_time, dive_date_time) - ?) <= ?
        ORDER BY time_diff ASC
        LIMIT 10
      ''',
            variables: [
              Variable(startMs),
              Variable(startMs),
              Variable(toleranceMs),
            ],
          )
          .get();

      if (result.isEmpty) return null;

      // Score each candidate and find the best match
      DiveMatchResult? bestMatch;
      double bestScore = 0.0;

      for (final row in result) {
        final diveId = row.data['id'] as String;
        final timeDiff = row.data['time_diff'] as int;
        final diveDuration = row.data['duration'] as int?;
        final diveMaxDepth = row.data['max_depth'] as double?;

        // Calculate component scores
        final timeScore = 1.0 - (timeDiff / toleranceMs).clamp(0.0, 1.0);
        var durationScore = 1.0;
        var depthScore = 1.0;
        int? durationDiff;
        double? depthDiff;

        // Duration comparison (if available)
        if (durationSeconds != null && diveDuration != null) {
          durationDiff = (diveDuration - durationSeconds).abs();
          // Score based on duration difference (within 5 min = 100%, 10 min = 0%)
          durationScore = 1.0 - (durationDiff / 600).clamp(0.0, 1.0);
        }

        // Depth comparison (if available)
        if (maxDepth != null && diveMaxDepth != null) {
          depthDiff = (diveMaxDepth - maxDepth).abs();
          // Score based on depth difference (within 0.5m = 100%, 5m = 0%)
          depthScore = 1.0 - (depthDiff / 5.0).clamp(0.0, 1.0);
        }

        // Weighted composite score
        // Time is most important (40%), then depth (35%), then duration (25%)
        final score =
            (timeScore * 0.40) + (depthScore * 0.35) + (durationScore * 0.25);

        if (score > bestScore) {
          bestScore = score;
          bestMatch = DiveMatchResult(
            diveId: diveId,
            score: score,
            timeDifferenceMs: timeDiff,
            durationDifferenceSeconds: durationDiff,
            depthDifferenceMeters: depthDiff,
          );
        }
      }

      // Only return a match if score meets minimum threshold
      if (bestMatch != null && bestMatch.score >= 0.5) {
        return bestMatch;
      }

      return null;
    } catch (e, stackTrace) {
      _log.error('Failed to find matching dive with score', e, stackTrace);
      return null;
    }
  }

  /// Get dive statistics for a specific computer.
  Future<DiveComputerStats> getComputerStats(String computerId) async {
    try {
      // Get dives that have profiles from this computer
      final statsResult = await _db
          .customSelect(
            '''
        SELECT
          COUNT(DISTINCT d.id) as dive_count,
          MIN(d.dive_date_time) as first_dive,
          MAX(d.dive_date_time) as last_dive,
          MAX(d.max_depth) as deepest,
          MAX(d.duration) as longest_duration,
          AVG(d.max_depth) as avg_depth,
          AVG(d.duration) as avg_duration,
          MIN(d.min_temperature) as coldest,
          MAX(d.max_temperature) as warmest,
          SUM(d.duration) as total_time
        FROM dives d
        INNER JOIN dive_profiles dp ON d.id = dp.dive_id
        WHERE dp.computer_id = ?
        GROUP BY dp.computer_id
      ''',
            variables: [Variable(computerId)],
          )
          .getSingleOrNull();

      if (statsResult == null) {
        return DiveComputerStats.empty();
      }

      final data = statsResult.data;
      return DiveComputerStats(
        diveCount: data['dive_count'] as int? ?? 0,
        firstDive: data['first_dive'] != null
            ? DateTime.fromMillisecondsSinceEpoch(data['first_dive'] as int)
            : null,
        lastDive: data['last_dive'] != null
            ? DateTime.fromMillisecondsSinceEpoch(data['last_dive'] as int)
            : null,
        deepestDive: data['deepest'] as double?,
        longestDuration: data['longest_duration'] as int?,
        avgDepth: data['avg_depth'] as double?,
        avgDuration: (data['avg_duration'] as num?)?.toDouble(),
        coldestTemp: data['coldest'] as double?,
        warmestTemp: data['warmest'] as double?,
        totalBottomTime: data['total_time'] as int?,
      );
    } catch (e, stackTrace) {
      _log.error('Failed to get computer stats: $computerId', e, stackTrace);
      return DiveComputerStats.empty();
    }
  }

  /// Get dive IDs that were imported from a specific computer.
  Future<List<String>> getDiveIdsForComputer(
    String computerId, {
    int? limit,
  }) async {
    try {
      final query =
          '''
        SELECT DISTINCT d.id, d.dive_date_time
        FROM dives d
        INNER JOIN dive_profiles dp ON d.id = dp.dive_id
        WHERE dp.computer_id = ?
        ORDER BY d.dive_date_time DESC
        ${limit != null ? 'LIMIT $limit' : ''}
      ''';

      final result = await _db
          .customSelect(query, variables: [Variable(computerId)])
          .get();

      return result.map((row) => row.data['id'] as String).toList();
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get dive ids for computer: $computerId',
        e,
        stackTrace,
      );
      return [];
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
    String? diverId,
    List<TankData>? tanks,
  }) async {
    try {
      _log.info('Importing profile from computer $computerId');
      final now = DateTime.now().millisecondsSinceEpoch;

      // Try to find an existing dive
      final matchedDiveId = await findMatchingDive(
        profileStartTime: profileStartTime,
        durationSeconds: durationSeconds,
      );

      final diveId = matchedDiveId ?? _uuid.v4();
      final isNewDive = matchedDiveId == null;

      if (isNewDive) {
        // Create a new dive for this profile
        _log.info('No matching dive found, creating new dive');

        // Calculate exit time from entry time + duration
        final entryTimeMs = profileStartTime.millisecondsSinceEpoch;
        final exitTimeMs = entryTimeMs + (durationSeconds * 1000);

        // Look up computer details to store on the dive record
        final computer = await getComputerById(computerId);

        await _db
            .into(_db.dives)
            .insert(
              DivesCompanion(
                id: Value(diveId),
                diverId: Value(diverId),
                diveDateTime: Value(entryTimeMs),
                entryTime: Value(entryTimeMs),
                exitTime: Value(exitTimeMs),
                duration: Value(durationSeconds),
                maxDepth: Value(maxDepth),
                diveComputerModel: Value(computer?.fullName),
                diveComputerSerial: Value(computer?.serialNumber),
                diveComputerFirmware: Value(computer?.firmwareVersion),
                createdAt: Value(now),
                updatedAt: Value(now),
              ),
            );

        await _syncRepository.markRecordPending(
          entityType: 'dives',
          recordId: diveId,
          localUpdatedAt: now,
        );

        isPrimary = true; // First profile is always primary
      }

      // Check if this computer already has a profile for this dive
      final existingProfiles = await _db
          .customSelect(
            '''
        SELECT COUNT(*) as count
        FROM dive_profiles
        WHERE dive_id = ? AND computer_id = ?
      ''',
            variables: [Variable(diveId), Variable(computerId)],
          )
          .getSingle();

      if ((existingProfiles.data['count'] as int) > 0) {
        _log.info('Profile from this computer already exists for dive $diveId');
        return diveId;
      }

      // If this dive has no profiles yet, make this one primary
      final hasProfiles = await _db
          .customSelect(
            'SELECT COUNT(*) as count FROM dive_profiles WHERE dive_id = ?',
            variables: [Variable(diveId)],
          )
          .getSingle();

      if ((hasProfiles.data['count'] as int) == 0) {
        isPrimary = true;
      }

      // Batch insert profile points for performance (~100x faster than individual)
      // No individual sync records needed - parent dive sync covers child data
      await _db.batch((batch) {
        for (final point in points) {
          batch.insert(
            _db.diveProfiles,
            DiveProfilesCompanion(
              id: Value(_uuid.v4()),
              diveId: Value(diveId),
              computerId: Value(computerId),
              timestamp: Value(point.timestamp),
              depth: Value(point.depth),
              // Store primary tank pressure for legacy compatibility
              pressure: Value(
                point.tankIndex == 0 || point.tankIndex == null
                    ? point.pressure
                    : null,
              ),
              temperature: Value(point.temperature),
              heartRate: Value(point.heartRate),
              isPrimary: Value(isPrimary),
            ),
          );
        }
      });

      // Map to track tank index → tank ID for pressure data
      final tankIdsByIndex = <int, String>{};

      // Insert tanks for new dives (batch insert for performance)
      if (isNewDive && tanks != null && tanks.isNotEmpty) {
        _log.info('Importing ${tanks.length} tanks for dive $diveId');
        await _db.batch((batch) {
          for (final tank in tanks) {
            final tankId = _uuid.v4();
            tankIdsByIndex[tank.index] = tankId;

            batch.insert(
              _db.diveTanks,
              DiveTanksCompanion(
                id: Value(tankId),
                diveId: Value(diveId),
                volume: Value(tank.volumeLiters),
                startPressure: Value(tank.startPressure?.round()),
                endPressure: Value(tank.endPressure?.round()),
                o2Percent: Value(tank.o2Percent),
                hePercent: Value(tank.hePercent),
                tankOrder: Value(tank.index),
                tankRole: const Value('backGas'),
              ),
            );
            _log.info(
              'Created tank ${tank.index}: '
              'O2=${tank.o2Percent}%, start=${tank.startPressure} bar, '
              'end=${tank.endPressure} bar',
            );
          }
        });
      } else if (!isNewDive) {
        // For existing dives, fetch tank IDs
        final existingTanks =
            await (_db.select(_db.diveTanks)
                  ..where((t) => t.diveId.equals(diveId))
                  ..orderBy([(t) => OrderingTerm.asc(t.tankOrder)]))
                .get();
        for (final tank in existingTanks) {
          tankIdsByIndex[tank.tankOrder] = tank.id;
        }
      }

      // Insert per-tank pressure time-series data (batch insert, no individual sync)
      if (tankIdsByIndex.isNotEmpty) {
        // Group pressure readings by tank index
        final pressuresByTank =
            <int, List<({int timestamp, double pressure})>>{};
        for (final point in points) {
          if (point.pressure != null) {
            final tankIdx = point.tankIndex ?? 0;
            pressuresByTank.putIfAbsent(tankIdx, () => []);
            pressuresByTank[tankIdx]!.add((
              timestamp: point.timestamp,
              pressure: point.pressure!,
            ));
          }
        }

        // Batch insert pressure data for each tank
        // No individual sync records - parent dive sync covers child data
        final insertEntries = pressuresByTank.entries
            .where((entry) => tankIdsByIndex.containsKey(entry.key))
            .toList();
        await _db.batch((batch) {
          for (final entry in insertEntries) {
            final tankId = tankIdsByIndex[entry.key]!;
            for (final point in entry.value) {
              batch.insert(
                _db.tankPressureProfiles,
                TankPressureProfilesCompanion.insert(
                  id: _uuid.v4(),
                  diveId: diveId,
                  tankId: tankId,
                  timestamp: point.timestamp,
                  pressure: point.pressure,
                ),
              );
            }
          }
        });
        for (final entry in insertEntries) {
          _log.info(
            'Imported ${entry.value.length} pressure points for tank ${entry.key}',
          );
        }
      }

      if (!isNewDive) {
        await (_db.update(_db.dives)..where((t) => t.id.equals(diveId))).write(
          DivesCompanion(updatedAt: Value(now)),
        );
        await _syncRepository.markRecordPending(
          entityType: 'dives',
          recordId: diveId,
          localUpdatedAt: now,
        );
      }

      // Note: Computer stats (incrementDiveCount, updateLastDownload) are
      // updated by the higher-level import workflow in DiveImportService/
      // DownloadNotifier, which correctly counts only actually imported dives

      SyncEventBus.notifyLocalChange();
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
      final now = DateTime.now().millisecondsSinceEpoch;
      final eventId = _uuid.v4();
      await _db
          .into(_db.diveProfileEvents)
          .insert(
            DiveProfileEventsCompanion(
              id: Value(eventId),
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
      await _syncRepository.markRecordPending(
        entityType: 'diveProfileEvents',
        recordId: eventId,
        localUpdatedAt: now,
      );
      await (_db.update(_db.dives)..where((t) => t.id.equals(diveId))).write(
        DivesCompanion(updatedAt: Value(now)),
      );
      await _syncRepository.markRecordPending(
        entityType: 'dives',
        recordId: diveId,
        localUpdatedAt: now,
      );
      SyncEventBus.notifyLocalChange();
    } catch (e, stackTrace) {
      _log.error('Failed to add profile event', e, stackTrace);
      rethrow;
    }
  }

  /// Delete all events for a dive
  Future<void> clearEventsForDive(String diveId) async {
    try {
      final existing = await (_db.select(
        _db.diveProfileEvents,
      )..where((t) => t.diveId.equals(diveId))).get();
      await (_db.delete(
        _db.diveProfileEvents,
      )..where((t) => t.diveId.equals(diveId))).go();
      for (final event in existing) {
        await _syncRepository.logDeletion(
          entityType: 'diveProfileEvents',
          recordId: event.id,
        );
      }
      final now = DateTime.now().millisecondsSinceEpoch;
      await (_db.update(_db.dives)..where((t) => t.id.equals(diveId))).write(
        DivesCompanion(updatedAt: Value(now)),
      );
      await _syncRepository.markRecordPending(
        entityType: 'dives',
        recordId: diveId,
        localUpdatedAt: now,
      );
      SyncEventBus.notifyLocalChange();
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
      firmwareVersion: row.firmwareVersion,
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

  /// Tank index for pressure (0-based), used for multi-tank pressure tracking
  final int? tankIndex;

  const ProfilePointData({
    required this.timestamp,
    required this.depth,
    this.pressure,
    this.temperature,
    this.heartRate,
    this.tankIndex,
  });
}

/// Data class for importing tank information
class TankData {
  final int index;
  final double o2Percent;
  final double hePercent;
  final double? startPressure;
  final double? endPressure;
  final double? volumeLiters;

  const TankData({
    required this.index,
    required this.o2Percent,
    this.hePercent = 0.0,
    this.startPressure,
    this.endPressure,
    this.volumeLiters,
  });
}

/// Result of duplicate dive matching with scoring.
class DiveMatchResult {
  /// ID of the matching dive
  final String diveId;

  /// Match score from 0.0 to 1.0
  final double score;

  /// Time difference in milliseconds
  final int timeDifferenceMs;

  /// Duration difference in seconds (if compared)
  final int? durationDifferenceSeconds;

  /// Depth difference in meters (if compared)
  final double? depthDifferenceMeters;

  const DiveMatchResult({
    required this.diveId,
    required this.score,
    required this.timeDifferenceMs,
    this.durationDifferenceSeconds,
    this.depthDifferenceMeters,
  });

  /// Time difference as Duration
  Duration get timeDifference => Duration(milliseconds: timeDifferenceMs);

  /// Whether this is a high-confidence match (score >= 0.8)
  bool get isHighConfidence => score >= 0.8;

  /// Whether this is a likely match (score >= 0.6)
  bool get isLikelyMatch => score >= 0.6;

  /// Human-readable confidence level
  String get confidenceLevel {
    if (score >= 0.9) return 'Exact';
    if (score >= 0.8) return 'Very Likely';
    if (score >= 0.6) return 'Likely';
    if (score >= 0.5) return 'Possible';
    return 'Unlikely';
  }
}

/// Statistics for dives imported from a specific dive computer.
class DiveComputerStats {
  /// Number of dives imported from this computer
  final int diveCount;

  /// Date of the first dive
  final DateTime? firstDive;

  /// Date of the last/most recent dive
  final DateTime? lastDive;

  /// Maximum depth across all dives (meters)
  final double? deepestDive;

  /// Longest dive duration (seconds)
  final int? longestDuration;

  /// Average maximum depth (meters)
  final double? avgDepth;

  /// Average dive duration (seconds)
  final double? avgDuration;

  /// Coldest water temperature (Celsius)
  final double? coldestTemp;

  /// Warmest water temperature (Celsius)
  final double? warmestTemp;

  /// Total bottom time across all dives (seconds)
  final int? totalBottomTime;

  const DiveComputerStats({
    required this.diveCount,
    this.firstDive,
    this.lastDive,
    this.deepestDive,
    this.longestDuration,
    this.avgDepth,
    this.avgDuration,
    this.coldestTemp,
    this.warmestTemp,
    this.totalBottomTime,
  });

  /// Empty stats for computers with no dives
  factory DiveComputerStats.empty() => const DiveComputerStats(diveCount: 0);

  /// Whether there are any stats to display
  bool get hasStats => diveCount > 0;

  /// Total bottom time as Duration
  Duration? get totalBottomTimeDuration =>
      totalBottomTime != null ? Duration(seconds: totalBottomTime!) : null;

  /// Longest duration as Duration
  Duration? get longestDurationDuration =>
      longestDuration != null ? Duration(seconds: longestDuration!) : null;

  /// Average duration as Duration
  Duration? get avgDurationDuration =>
      avgDuration != null ? Duration(seconds: avgDuration!.round()) : null;

  /// Format total bottom time as hours:minutes
  String get totalBottomTimeFormatted {
    if (totalBottomTime == null) return '--';
    final hours = totalBottomTime! ~/ 3600;
    final minutes = (totalBottomTime! % 3600) ~/ 60;
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }
}
