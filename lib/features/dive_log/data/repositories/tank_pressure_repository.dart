import 'package:drift/drift.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/features/dive_log/data/repositories/tank_pressure_series_repository.dart';
import 'package:submersion/features/dive_log/domain/codecs/tank_pressure_series_codec.dart'
    show TankPressureSample;
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/services/profile_series_merge.dart';

/// Repository for managing per-tank time-series pressure data
///
/// This repository handles storage and retrieval of pressure readings
/// from AI transmitters for multi-tank dives.
class TankPressureRepository {
  AppDatabase get _db => DatabaseService.instance.database;
  final SyncRepository _syncRepository = SyncRepository();
  final TankPressureSeriesRepository _tankSeries =
      TankPressureSeriesRepository();

  /// Get all tank pressure data for a dive, grouped by tank ID
  ///
  /// Returns a map where keys are tank IDs and values are lists of
  /// pressure points sorted by timestamp. The series tables are the only
  /// store: v183 dropped `tank_pressure_profiles`.
  Future<Map<String, List<TankPressurePoint>>> getTankPressuresForDive(
    String diveId,
  ) async {
    final series = await _tankSeries.getSeriesForDive(diveId);
    if (series.isEmpty) return const <String, List<TankPressurePoint>>{};
    final byTank = <String, List<dynamic>>{};
    for (final s in series) {
      byTank.putIfAbsent(s.tankId, () => []).add(s);
    }
    final result = <String, List<TankPressurePoint>>{};
    for (final entry in byTank.entries) {
      result[entry.key] = mergeTankSeriesPoints(entry.value.cast());
    }
    return result;
  }

  /// Get pressure data for a specific tank.
  ///
  /// This read gates on the TANK's series while [getTankPressuresForDive]
  /// gates on the dive's; the two can only disagree for a tank the packer
  /// skipped as an orphan (no `dive_tanks` parent), which nothing renders.
  Future<List<TankPressurePoint>> getPressuresForTank(
    String diveId,
    String tankId,
  ) async {
    final series = await _tankSeries.getSeriesForTank(diveId, tankId);
    if (series.isEmpty) return const <TankPressurePoint>[];
    return mergeTankSeriesPoints(series);
  }

  /// Bulk insert tank pressure data for a dive
  ///
  /// [pressuresByTank] maps tank IDs to lists of (timestamp, pressure) tuples.
  /// Each tank's samples become one series; the repository marks it pending
  /// and stamps it with an hlc, so no separate per-sample sync bookkeeping is
  /// needed here.
  Future<void> insertTankPressures(
    String diveId,
    Map<String, List<({int timestamp, double pressure})>> pressuresByTank,
  ) async {
    if (pressuresByTank.isEmpty) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    // One transaction for the whole pressure set. Each insertSeries commits
    // and marks itself pending on its own, so a tank that cannot be written
    // (an encode the codec refuses, a constraint) would otherwise leave the
    // tanks before it committed and pending, and half a dive's pressures
    // would publish to peers as if they were all of them. The legacy
    // row-per-sample write was one batch and had the same all-or-nothing
    // behaviour.
    await _db.transaction(() async {
      for (final entry in pressuresByTank.entries) {
        if (entry.value.isEmpty) continue;
        await _tankSeries.insertSeries(
          diveId: diveId,
          tankId: entry.key,
          samples: [
            for (final point in entry.value)
              TankPressureSample(
                timestamp: point.timestamp,
                pressure: point.pressure,
              ),
          ],
          now: now,
        );
      }
      // Only mark parent dive as pending - child data syncs with it
      await (_db.update(_db.dives)..where((t) => t.id.equals(diveId))).write(
        DivesCompanion(updatedAt: Value(now)),
      );
      await _syncRepository.markRecordPending(
        entityType: 'dives',
        recordId: diveId,
        localUpdatedAt: now,
      );
    });
    SyncEventBus.notifyLocalChange();
  }

  /// Delete all tank pressure data for a dive
  Future<void> deleteTankPressuresForDive(String diveId) async {
    await _tankSeries.deleteForDive(diveId);
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

  /// Move every pressure row of [fromTankId] onto [toTankId] (wrong-cylinder
  /// repair). No transaction/notify -- the repair executor owns those.
  Future<void> reassignTankPressureSeries({
    required String diveId,
    required String fromTankId,
    required String toTankId,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _tankSeries.reassignTank(diveId, fromTankId, toTankId, now: now);
    await _touchDive(diveId, now);
  }

  /// Exchange the pressure series of two tanks (swapped-transmitter repair).
  Future<void> swapTankPressureSeries({
    required String diveId,
    required String tankIdA,
    required String tankIdB,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _tankSeries.swapTanks(diveId, tankIdA, tankIdB, now: now);
    await _touchDive(diveId, now);
  }

  /// Child rows sync with the parent dive: bump + mark it pending.
  Future<void> _touchDive(String diveId, int now) async {
    await (_db.update(_db.dives)..where((t) => t.id.equals(diveId))).write(
      DivesCompanion(updatedAt: Value(now)),
    );
    await _syncRepository.markRecordPending(
      entityType: 'dives',
      recordId: diveId,
      localUpdatedAt: now,
    );
  }

  /// Check if a dive has any per-tank pressure data
  Future<bool> hasTankPressures(String diveId) =>
      _tankSeries.hasSeriesForDive(diveId);
}
