import 'package:drift/drift.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/features/dive_log/data/repositories/tank_pressure_series_repository.dart';
import 'package:submersion/features/dive_log/domain/codecs/tank_pressure_series_codec.dart'
    show TankPressureSample;
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_tank_pressure_export.dart';
import 'package:submersion/features/dive_log/domain/entities/profile_series.dart'
    as domain;
import 'package:submersion/features/dive_log/domain/services/profile_series_merge.dart';
import 'package:submersion/features/dive_log/domain/services/tank_source_index.dart';

/// Repository for managing per-tank time-series pressure data
///
/// This repository handles storage and retrieval of pressure readings
/// from AI transmitters for multi-tank dives.
class TankPressureRepository {
  /// [database] is optional so the zero-arg construction sites keep resolving
  /// through [DatabaseService]; services that own an [AppDatabase] (and wrap
  /// these writes in their own transaction) pass it so the injection is real.
  TankPressureRepository({AppDatabase? database})
    : _database = database,
      _syncRepository = SyncRepository(database: database),
      _tankSeries = TankPressureSeriesRepository(database: database);

  final AppDatabase? _database;
  AppDatabase get _db => _database ?? DatabaseService.instance.database;
  final SyncRepository _syncRepository;
  final TankPressureSeriesRepository _tankSeries;

  /// Get all tank pressure data for a dive, grouped by tank ID
  ///
  /// Returns a map where keys are tank IDs and values are lists of
  /// pressure points sorted by timestamp. The series tables are the only
  /// store: v183 dropped `tank_pressure_profiles`.
  ///
  /// Where two sources recorded the same stretch of a tank, only the primary
  /// source's series is read (see [selectTankSeriesPerSource], issue #2440):
  /// interleaving two recordings of one cylinder is no pressure curve.
  Future<Map<String, List<TankPressurePoint>>> getTankPressuresForDive(
    String diveId,
  ) async => _groupByTank(
    selectTankSeriesPerSource(
      await _tankSeries.getSeriesForDive(diveId),
      preferredSourceId: await _tankSeries.primarySourceId(diveId),
    ),
  );

  /// Every tank pressure series of many dives at once, keyed by dive id; a
  /// dive with no pressure data is absent. One statement per chunk of ids
  /// instead of one per dive (issue #1867).
  ///
  /// Unlike [getTankPressuresForDive] this keeps every source's series:
  /// its readers are the exports, and a backup must not drop a recording
  /// because another source covered the same stretch. Each series keeps
  /// its source, so a restore can file it under that source again (issue
  /// #2492).
  Future<Map<String, DiveTankPressureExport>> getTankPressuresForDives(
    List<String> diveIds,
  ) async {
    final seriesByDive = await _tankSeries.getSeriesForDives(diveIds);
    if (seriesByDive.isEmpty) return const {};
    final primaryByDive = await _tankSeries.primarySourceIdsForDives(
      seriesByDive.keys.toList(growable: false),
    );
    return {
      for (final entry in seriesByDive.entries)
        entry.key: DiveTankPressureExport(
          series: entry.value,
          primarySourceId: primaryByDive[entry.key],
        ),
    };
  }

  /// [getTankPressuresForDive] as one source saw the dive: on a tank that
  /// [computerId] logged, only its series; on any other tank, every series.
  /// See [selectTankSeriesForComputer] for why a consolidated dive needs
  /// this (two computers on one transmitter interleave on one tank). Series
  /// of two sources that still overlap, such as two file imports with no
  /// computer, are then narrowed to one, preferring [sourceId] (#2440).
  Future<Map<String, List<TankPressurePoint>>> getTankPressuresForComputer(
    String diveId,
    String? computerId, {
    String? sourceId,
  }) async => _groupByTank(
    selectTankSeriesPerSource(
      selectTankSeriesForComputer(
        await _tankSeries.getSeriesForDive(diveId),
        computerId,
      ),
      preferredSourceId: sourceId,
      preferredComputerId: computerId,
    ),
  );

  Map<String, List<TankPressurePoint>> _groupByTank(
    List<domain.TankPressureSeries> series,
  ) {
    if (series.isEmpty) return const <String, List<TankPressurePoint>>{};
    final byTank = <String, List<domain.TankPressureSeries>>{};
    for (final s in series) {
      byTank.putIfAbsent(s.tankId, () => []).add(s);
    }
    return {
      for (final entry in byTank.entries)
        entry.key: mergeTankSeriesPoints(entry.value),
    };
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
    return mergeTankSeriesPoints(
      selectTankSeriesPerSource(
        series,
        preferredSourceId: await _tankSeries.primarySourceId(diveId),
      ),
    );
  }

  /// Bulk insert tank pressure data for a dive
  ///
  /// [pressuresByTank] maps tank IDs to lists of (timestamp, pressure) tuples.
  /// Each tank's samples become one series; the repository marks it pending
  /// and stamps it with an hlc, so no separate per-sample sync bookkeeping is
  /// needed here.
  /// [sourceId] names the data source the readings came from (issue #2440);
  /// null when it is not known yet.
  Future<void> insertTankPressures(
    String diveId,
    Map<String, List<({int timestamp, double pressure})>> pressuresByTank, {
    String? sourceId,
  }) => insertTankSeries(diveId, [
    for (final entry in pressuresByTank.entries)
      (
        tankId: entry.key,
        sourceId: sourceId,
        computerId: null,
        samples: entry.value,
      ),
  ]);

  /// Inserts each of [series] as a series of its own, with its own source
  /// and computer, in one transaction like [insertTankPressures].
  ///
  /// A restore needs this (issue #2492): one source can record a tank in
  /// two stretches with another source's recording between them, and
  /// [selectTankSeriesPerSource] judges overlap series by series, so
  /// joining the two would make them span the other and hide it.
  Future<void> insertTankSeries(
    String diveId,
    List<
      ({
        String tankId,
        String? sourceId,
        String? computerId,
        List<({int timestamp, double pressure})> samples,
      })
    >
    series,
  ) async {
    if (series.isEmpty) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    // One transaction for the whole pressure set. Each insertSeries commits
    // and marks itself pending on its own, so a tank that cannot be written
    // (an encode the codec refuses, a constraint) would otherwise leave the
    // tanks before it committed and pending, and half a dive's pressures
    // would publish to peers as if they were all of them. The legacy
    // row-per-sample write was one batch and had the same all-or-nothing
    // behaviour.
    await _db.transaction(() async {
      for (final entry in series) {
        if (entry.samples.isEmpty) continue;
        await _tankSeries.insertSeries(
          diveId: diveId,
          tankId: entry.tankId,
          sourceId: entry.sourceId,
          computerId: entry.computerId,
          samples: [
            for (final point in entry.samples)
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

  /// Replace the pressure data of exactly [tankIds], leaving the series of
  /// every tank not named intact.
  ///
  /// A resync keeps a `dive_tanks` row the fresh parse no longer reports
  /// (#276: the cascade makes a wrong delete unrecoverable), so the pressure
  /// series recorded against that tank has to be kept with it. The dive-wide
  /// [replaceTankPressures] deletes it and tombstones it to every peer.
  Future<void> replaceTankPressuresForTanks(
    String diveId,
    Iterable<String> tankIds,
    Map<String, List<({int timestamp, double pressure})>> pressuresByTank, {
    String? sourceId,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.transaction(() async {
      for (final tankId in tankIds) {
        await _tankSeries.deleteForTank(diveId, tankId);
      }
      await insertTankPressures(diveId, pressuresByTank, sourceId: sourceId);
      await _touchDive(diveId, now);
    });
    SyncEventBus.notifyLocalChange();
  }

  /// Attributes the unattributed pressure series of [diveId] to [sourceId]
  /// (issue #2440). See [TankPressureSeriesRepository.stampSourceWhereNull].
  Future<int> stampSourceWhereNull(String diveId, String sourceId) =>
      _tankSeries.stampSourceWhereNull(diveId, sourceId);

  /// Move the pressure series of [fromTankId] onto [toTankId]. Since v200 this
  /// is an exchange: the target's previous bundle comes back to the source so
  /// nothing is orphaned and the operation is its own inverse. No
  /// transaction/notify -- the repair executor owns those.
  Future<void> reassignTankPressureSeries({
    required String diveId,
    required String fromTankId,
    required String toTankId,
  }) => exchangeTankSources(
    diveId: diveId,
    tankIdA: fromTankId,
    tankIdB: toTankId,
  );

  /// Exchange the pressure series of two tanks (swapped-transmitter repair).
  Future<void> swapTankPressureSeries({
    required String diveId,
    required String tankIdA,
    required String tankIdB,
  }) => exchangeTankSources(diveId: diveId, tankIdA: tankIdA, tankIdB: tankIdB);

  /// Exchange the computer-owned bundle of two tank rows on one dive: the
  /// parsed source index, transmitter serial, start and end pressure, and
  /// the packed pressure series. User-authored columns (name, role, size,
  /// gear, preset, gas mix) stay with their row.
  ///
  /// A row without an explicit source index is resolved first
  /// ([effectiveSourceTankIndex]) so that re-parse keeps honoring the result:
  /// a legacy row that had a series takes its order, one that had none takes
  /// [kNoSourceTankIndex]. The exchange is its own inverse.
  Future<void> exchangeTankSources({
    required String diveId,
    required String tankIdA,
    required String tankIdB,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    // Both rows must belong to [diveId]: a mismatched id fails here rather
    // than silently swapping fields across dives.
    final a =
        await (_db.select(_db.diveTanks)
              ..where((t) => t.id.equals(tankIdA) & t.diveId.equals(diveId)))
            .getSingle();
    final b =
        await (_db.select(_db.diveTanks)
              ..where((t) => t.id.equals(tankIdB) & t.diveId.equals(diveId)))
            .getSingle();
    final aHasSeries = await _hasSeries(diveId, tankIdA);
    final bHasSeries = await _hasSeries(diveId, tankIdB);
    final aIndex = effectiveSourceTankIndex(
      sourceTankIndex: a.sourceTankIndex,
      tankOrder: a.tankOrder,
      hasSeries: aHasSeries,
    );
    final bIndex = effectiveSourceTankIndex(
      sourceTankIndex: b.sourceTankIndex,
      tankOrder: b.tankOrder,
      hasSeries: bHasSeries,
    );

    await (_db.update(
      _db.diveTanks,
    )..where((t) => t.id.equals(tankIdA) & t.diveId.equals(diveId))).write(
      DiveTanksCompanion(
        sourceTankIndex: Value(bIndex),
        transmitterSerial: Value(b.transmitterSerial),
        startPressure: Value(b.startPressure),
        endPressure: Value(b.endPressure),
      ),
    );
    await (_db.update(
      _db.diveTanks,
    )..where((t) => t.id.equals(tankIdB) & t.diveId.equals(diveId))).write(
      DiveTanksCompanion(
        sourceTankIndex: Value(aIndex),
        transmitterSerial: Value(a.transmitterSerial),
        startPressure: Value(a.startPressure),
        endPressure: Value(a.endPressure),
      ),
    );
    await _tankSeries.swapTanks(diveId, tankIdA, tankIdB, now: now);
    await _syncRepository.markRecordPending(
      entityType: 'diveTanks',
      recordId: tankIdA,
      localUpdatedAt: now,
    );
    await _syncRepository.markRecordPending(
      entityType: 'diveTanks',
      recordId: tankIdB,
      localUpdatedAt: now,
    );
    await _touchDive(diveId, now);
  }

  Future<bool> _hasSeries(String diveId, String tankId) async {
    final count = _db.tankPressureSeries.id.count();
    final row =
        await (_db.selectOnly(_db.tankPressureSeries)
              ..addColumns([count])
              ..where(
                _db.tankPressureSeries.diveId.equals(diveId) &
                    _db.tankPressureSeries.tankId.equals(tankId),
              ))
            .getSingle();
    return (row.read(count) ?? 0) > 0;
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
