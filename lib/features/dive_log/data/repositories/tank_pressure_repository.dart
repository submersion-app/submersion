import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/database/database.dart';
import '../../../../core/services/database_service.dart';
import '../../domain/entities/dive.dart';

/// Repository for managing per-tank time-series pressure data
///
/// This repository handles storage and retrieval of pressure readings
/// from AI transmitters for multi-tank dives.
class TankPressureRepository {
  AppDatabase get _db => DatabaseService.instance.database;
  final _uuid = const Uuid();

  /// Get all tank pressure data for a dive, grouped by tank ID
  ///
  /// Returns a map where keys are tank IDs and values are lists of
  /// pressure points sorted by timestamp.
  Future<Map<String, List<TankPressurePoint>>> getTankPressuresForDive(
    String diveId,
  ) async {
    final rows =
        await (_db.select(_db.tankPressureProfiles)
              ..where((t) => t.diveId.equals(diveId))
              ..orderBy([(t) => OrderingTerm.asc(t.timestamp)]))
            .get();

    final result = <String, List<TankPressurePoint>>{};
    for (final row in rows) {
      result
          .putIfAbsent(row.tankId, () => [])
          .add(
            TankPressurePoint(
              id: row.id,
              tankId: row.tankId,
              timestamp: row.timestamp,
              pressure: row.pressure,
            ),
          );
    }

    return result;
  }

  /// Get pressure data for a specific tank
  Future<List<TankPressurePoint>> getPressuresForTank(
    String diveId,
    String tankId,
  ) async {
    final rows =
        await (_db.select(_db.tankPressureProfiles)
              ..where((t) => t.diveId.equals(diveId) & t.tankId.equals(tankId))
              ..orderBy([(t) => OrderingTerm.asc(t.timestamp)]))
            .get();

    return rows
        .map(
          (row) => TankPressurePoint(
            id: row.id,
            tankId: row.tankId,
            timestamp: row.timestamp,
            pressure: row.pressure,
          ),
        )
        .toList();
  }

  /// Bulk insert tank pressure data for a dive
  ///
  /// [pressuresByTank] maps tank IDs to lists of (timestamp, pressure) tuples
  Future<void> insertTankPressures(
    String diveId,
    Map<String, List<({int timestamp, double pressure})>> pressuresByTank,
  ) async {
    await _db.batch((batch) {
      for (final entry in pressuresByTank.entries) {
        final tankId = entry.key;
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
  }

  /// Delete all tank pressure data for a dive
  Future<void> deleteTankPressuresForDive(String diveId) async {
    await (_db.delete(
      _db.tankPressureProfiles,
    )..where((t) => t.diveId.equals(diveId))).go();
  }

  /// Replace all tank pressure data for a dive
  ///
  /// Deletes existing data and inserts new data in a single transaction.
  Future<void> replaceTankPressures(
    String diveId,
    Map<String, List<({int timestamp, double pressure})>> pressuresByTank,
  ) async {
    await _db.transaction(() async {
      await deleteTankPressuresForDive(diveId);
      await insertTankPressures(diveId, pressuresByTank);
    });
  }

  /// Check if a dive has any per-tank pressure data
  Future<bool> hasTankPressures(String diveId) async {
    final count =
        await (_db.selectOnly(_db.tankPressureProfiles)
              ..addColumns([_db.tankPressureProfiles.id.count()])
              ..where(_db.tankPressureProfiles.diveId.equals(diveId)))
            .map((row) => row.read(_db.tankPressureProfiles.id.count()))
            .getSingle();

    return (count ?? 0) > 0;
  }
}
