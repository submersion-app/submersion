import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/equipment/data/services/sensor_summary_worker.dart';
import 'package:submersion/features/equipment/domain/entities/dive_sensor_summary.dart';
import 'package:submersion/features/equipment/domain/services/dive_sensor_summary_service.dart';

/// Runs the worker. The default hops to an isolate through `compute`; tests
/// substitute a same-isolate runner to count invocations.
typedef SensorSummaryRunner =
    Future<DiveSensorSummary> Function(SensorSummaryWorkInput input);

Future<DiveSensorSummary> _computeOnIsolate(SensorSummaryWorkInput input) =>
    compute(computeSensorSummaryFromBlobs, input);

/// Owns `dive_sensor_summaries`: the device-local, per-dive cache of what
/// only a profile decode can produce. Never synced; a restore rebuilds it.
class DiveSensorSummaryRepository {
  final AppDatabase? _dbOverride;
  final SensorSummaryRunner _runner;

  DiveSensorSummaryRepository({AppDatabase? db, SensorSummaryRunner? runner})
    : _dbOverride = db,
      _runner = runner ?? _computeOnIsolate;

  AppDatabase get _db => _dbOverride ?? DatabaseService.instance.database;

  Future<DiveSensorSummary?> getSummary(String diveId) async {
    final row = await (_db.select(
      _db.diveSensorSummaries,
    )..where((t) => t.diveId.equals(diveId))).getSingleOrNull();
    return row == null ? null : _toDomain(row);
  }

  /// The stored rows for [diveIds], keyed by dive, in chunks that stay
  /// under SQLite's bound-variable cap. Dives without a row are absent;
  /// nothing is computed here (condition phase 3b, the engine's read).
  Future<Map<String, DiveSensorSummary>> getSummaries(
    List<String> diveIds,
  ) async {
    if (diveIds.isEmpty) return const {};
    final unique = diveIds.toSet().toList();
    const chunk = 500;
    final result = <String, DiveSensorSummary>{};
    for (var start = 0; start < unique.length; start += chunk) {
      final end = start + chunk < unique.length ? start + chunk : unique.length;
      final rows = await (_db.select(
        _db.diveSensorSummaries,
      )..where((t) => t.diveId.isIn(unique.sublist(start, end)))).get();
      for (final row in rows) {
        result[row.diveId] = _toDomain(row);
      }
    }
    return result;
  }

  /// The engine version and source stamp of each stored row among
  /// [diveIds], keyed by dive, without decoding the summaries: the
  /// condition review reads these on every visit, so it must stay cheap.
  /// Dives without a row are absent.
  Future<
    Map<String, ({int engineVersion, int sourceUpdatedAt, int computedAt})>
  >
  getSummaryStamps(List<String> diveIds) async {
    if (diveIds.isEmpty) return const {};
    final unique = diveIds.toSet().toList();
    const chunk = 500;
    final t = _db.diveSensorSummaries;
    final result =
        <String, ({int engineVersion, int sourceUpdatedAt, int computedAt})>{};
    for (var start = 0; start < unique.length; start += chunk) {
      final end = start + chunk < unique.length ? start + chunk : unique.length;
      final query = _db.selectOnly(t)
        ..addColumns([
          t.diveId,
          t.engineVersion,
          t.sourceUpdatedAt,
          t.computedAt,
        ])
        ..where(t.diveId.isIn(unique.sublist(start, end)));
      for (final row in await query.get()) {
        result[row.read(t.diveId)!] = (
          engineVersion: row.read(t.engineVersion)!,
          sourceUpdatedAt: row.read(t.sourceUpdatedAt)!,
          computedAt: row.read(t.computedAt)!,
        );
      }
    }
    return result;
  }

  /// The stored row when its engine version and source stamp match the
  /// dive, else a fresh computation, stored before it is returned. Null
  /// when [diveId] does not exist. [force] recomputes regardless.
  Future<DiveSensorSummary?> ensureCurrent(
    String diveId, {
    bool force = false,
  }) async {
    final dive = await (_db.select(
      _db.dives,
    )..where((t) => t.id.equals(diveId))).getSingleOrNull();
    if (dive == null) return null;

    if (!force) {
      final stored = await getSummary(diveId);
      if (stored != null &&
          stored.engineVersion >= DiveSensorSummaryService.version &&
          stored.sourceUpdatedAt == dive.updatedAt) {
        return stored;
      }
    }

    final primaryRows =
        await (_db.select(_db.diveProfileSeries)
              ..where((t) => t.diveId.equals(diveId) & t.isPrimary.equals(true))
              ..orderBy([
                (t) => OrderingTerm.asc(t.startTimestamp),
                (t) => OrderingTerm.asc(t.id),
              ]))
            .get();
    final tankRows = await (_db.select(
      _db.diveTanks,
    )..where((t) => t.diveId.equals(diveId))).get();
    final tankSeriesRows =
        await (_db.select(_db.tankPressureSeries)
              ..where((t) => t.diveId.equals(diveId))
              ..orderBy([(t) => OrderingTerm.asc(t.tankId)]))
            .get();
    final tanksById = {for (final t in tankRows) t.id: t};

    final summary = await _runner(
      SensorSummaryWorkInput(
        diveId: diveId,
        primaryBlobs: [for (final r in primaryRows) r.samples],
        tankBlobs: [
          for (final r in tankSeriesRows)
            TankSeriesBlob(
              tankId: r.tankId,
              transmitterSerial: tanksById[r.tankId]?.transmitterSerial,
              computerId: r.computerId ?? tanksById[r.tankId]?.computerId,
              samples: r.samples,
            ),
        ],
        diveMode: DiveMode.fromCode(dive.diveMode),
        runtimeSeconds: dive.runtime ?? dive.bottomTime,
        scrubberDurationMinutes: dive.scrubberDurationMinutes,
        scrubberRemainingMinutes: dive.scrubberRemainingMinutes,
        sourceUpdatedAt: dive.updatedAt,
        computedAtMs: DateTime.now().toUtc().millisecondsSinceEpoch,
      ),
    );
    await saveSummary(summary);
    return summary;
  }

  Future<void> saveSummary(DiveSensorSummary summary) => _db
      .into(_db.diveSensorSummaries)
      .insertOnConflictUpdate(
        DiveSensorSummariesCompanion.insert(
          diveId: summary.diveId,
          engineVersion: summary.engineVersion,
          sourceUpdatedAt: summary.sourceUpdatedAt,
          computedAt: summary.computedAt.millisecondsSinceEpoch,
          minTemperature: Value(summary.minTemperature),
          maxDepth: Value(summary.maxDepth),
          scrubberConsumedMinutes: Value(summary.scrubberConsumedMinutes),
          cellMetrics: Value(encodeCellMetrics(summary.cellMetrics)),
          transmitterGaps: Value(
            encodeTransmitterGaps(summary.transmitterGaps),
          ),
        ),
      );

  /// Dives with no row, a row from an older engine, or a row whose source
  /// stamp no longer matches the dive; oldest dive first so a sweep primes
  /// the same order the safety review uses.
  Future<List<String>> staleDiveIds({String? diverId}) async {
    final rows = await _db
        .customSelect(
          'SELECT d.id AS id FROM dives d '
          'LEFT JOIN dive_sensor_summaries s ON s.dive_id = d.id '
          'WHERE (s.dive_id IS NULL OR s.engine_version < ? '
          'OR s.source_updated_at != d.updated_at)'
          '${diverId == null ? '' : ' AND d.diver_id = ?'} '
          'ORDER BY d.dive_date_time ASC, d.id ASC',
          variables: [
            Variable.withInt(DiveSensorSummaryService.version),
            if (diverId != null) Variable.withString(diverId),
          ],
          readsFrom: {_db.dives, _db.diveSensorSummaries},
        )
        .get();
    return [for (final r in rows) r.read<String>('id')];
  }

  Future<int> countStale({String? diverId}) async =>
      (await staleDiveIds(diverId: diverId)).length;

  DiveSensorSummary _toDomain(DiveSensorSummaryRow row) => DiveSensorSummary(
    diveId: row.diveId,
    engineVersion: row.engineVersion,
    sourceUpdatedAt: row.sourceUpdatedAt,
    computedAt: DateTime.fromMillisecondsSinceEpoch(
      row.computedAt,
      isUtc: true,
    ),
    minTemperature: row.minTemperature,
    maxDepth: row.maxDepth,
    scrubberConsumedMinutes: row.scrubberConsumedMinutes,
    cellMetrics: decodeCellMetrics(row.cellMetrics),
    transmitterGaps: decodeTransmitterGaps(row.transmitterGaps),
  );
}
