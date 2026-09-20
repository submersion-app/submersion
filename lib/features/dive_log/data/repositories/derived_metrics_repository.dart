import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart' show compute;

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/dive_log/data/repositories/profile_series_repository.dart';
import 'package:submersion/features/dive_log/data/services/derived_metrics_worker.dart';
import 'package:submersion/features/dive_log/domain/entities/derived_metrics.dart';
import 'package:submersion/features/dive_log/domain/services/derived_metrics_service.dart';

typedef DerivedMetricsRunner =
    Future<DiveDerivedMetrics> Function(DerivedMetricsWorkInput input);

Future<DiveDerivedMetrics> _computeOnIsolate(DerivedMetricsWorkInput input) =>
    compute(computeDerivedMetricsFromBlobs, input);

/// Reads and writes the phase 2 derived metrics, computing them on a worker
/// isolate when the stored row is missing or stale.
///
/// Tests substitute a same-isolate [DerivedMetricsRunner] so they can count
/// invocations and stay deterministic.
class DerivedMetricsRepository {
  DerivedMetricsRepository({
    AppDatabase? database,
    DerivedMetricsRunner? runner,
  }) : _dbOverride = database,
       _runner = runner ?? _computeOnIsolate;

  final AppDatabase? _dbOverride;
  final DerivedMetricsRunner _runner;

  AppDatabase get _db => _dbOverride ?? DatabaseService.instance.database;

  ProfileSeriesRepository get _series =>
      ProfileSeriesRepository(database: _dbOverride);

  /// The stored metrics when they describe the dive as it is now, otherwise
  /// freshly computed and stored before they are returned. Null when the
  /// dive does not exist.
  ///
  /// [force] rebuilds a row that looks current, for a data-quality repair
  /// that rewrote a profile without touching the dive's `updated_at`.
  Future<DiveDerivedMetrics?> ensureCurrent(
    String diveId, {
    bool force = false,
  }) async {
    final dive = await (_db.select(
      _db.dives,
    )..where((t) => t.id.equals(diveId))).getSingleOrNull();
    if (dive == null) return null;

    if (!force) {
      final stored = await getMetrics(diveId);
      if (stored != null &&
          DerivedMetricsService.isCurrent(stored, dive.updatedAt)) {
        return stored;
      }
    }

    final seriesRows = await _series.getPrimaryRowsForDives([diveId]);
    final tankRows = await (_db.select(
      _db.diveTanks,
    )..where((t) => t.diveId.equals(diveId))).get();
    final pressureRows = await (_db.select(
      _db.tankPressureSeries,
    )..where((t) => t.diveId.equals(diveId))).get();

    final metrics = await _runner(
      DerivedMetricsWorkInput(
        diveId: diveId,
        primaryBlobs: [for (final r in seriesRows) r.samples],
        tankBlobs: [
          for (final t in tankRows)
            if (_richestSeriesFor(pressureRows, t.id) case final series?)
              TankPressureBlob(
                tankId: t.id,
                volumeLiters: t.volume,
                samples: series.samples,
              ),
        ],
        diveMode: DiveMode.fromCode(dive.diveMode),
        sourceUpdatedAt: dive.updatedAt,
        computedAtMs: DateTime.now().millisecondsSinceEpoch,
      ),
    );

    await saveMetrics(metrics);
    return metrics;
  }

  /// A tank can carry one series per computer that logged it. Pick the
  /// longest, breaking a tie on id, so the same database always produces
  /// the same metrics rather than whichever row the query happened to
  /// return first.
  TankPressureSeriesRow? _richestSeriesFor(
    List<TankPressureSeriesRow> rows,
    String tankId,
  ) {
    TankPressureSeriesRow? best;
    for (final row in rows) {
      if (row.tankId != tankId) continue;
      if (best == null ||
          row.sampleCount > best.sampleCount ||
          (row.sampleCount == best.sampleCount &&
              row.id.compareTo(best.id) < 0)) {
        best = row;
      }
    }
    return best;
  }

  Future<DiveDerivedMetrics?> getMetrics(String diveId) async {
    final row = await (_db.select(
      _db.diveDerivedMetricsRows,
    )..where((t) => t.diveId.equals(diveId))).getSingleOrNull();
    if (row == null) return null;
    final buckets =
        await (_db.select(_db.diveSacBuckets)
              ..where((t) => t.diveId.equals(diveId))
              ..orderBy([(t) => OrderingTerm.asc(t.bucketIndex)]))
            .get();
    return DiveDerivedMetrics(
      diveId: row.diveId,
      engineVersion: row.engineVersion,
      sourceUpdatedAt: row.sourceUpdatedAt,
      computedAt: row.computedAt,
      finalStopKind: FinalStopKind.values.firstWhere(
        (k) => k.name == row.finalStopKind,
        orElse: () => FinalStopKind.none,
      ),
      finalStopStartSeconds: row.finalStopStartS,
      finalStopDurationSeconds: row.finalStopDurationS,
      finalStopDepthStdDevMeters: row.finalStopDepthStddevM,
      finalStopMaxExcursionMeters: row.finalStopMaxExcursionM,
      sacMeanBarPerMin: row.sacMeanBarMin,
      sacSlopeBarPerMinPerMin: row.sacSlopeBarMinPerMin,
      runtimeSeconds: row.runtimeS,
      unsupportedReason: row.unsupportedReason == null
          ? null
          : UnsupportedReason.values.firstWhere(
              (r) => r.name == row.unsupportedReason,
              orElse: () => UnsupportedReason.noProfile,
            ),
      sacBuckets: [
        for (final b in buckets)
          SacBucket(index: b.bucketIndex, sacBarPerMin: b.sacBarMin),
      ],
    );
  }

  Future<void> saveMetrics(DiveDerivedMetrics m) async {
    await _db.transaction(() async {
      await _db
          .into(_db.diveDerivedMetricsRows)
          .insertOnConflictUpdate(
            DiveDerivedMetricsRowsCompanion(
              diveId: Value(m.diveId),
              engineVersion: Value(m.engineVersion),
              sourceUpdatedAt: Value(m.sourceUpdatedAt),
              computedAt: Value(m.computedAt),
              finalStopKind: Value(m.finalStopKind.name),
              finalStopStartS: Value(m.finalStopStartSeconds),
              finalStopDurationS: Value(m.finalStopDurationSeconds),
              finalStopDepthStddevM: Value(m.finalStopDepthStdDevMeters),
              finalStopMaxExcursionM: Value(m.finalStopMaxExcursionMeters),
              sacMeanBarMin: Value(m.sacMeanBarPerMin),
              sacSlopeBarMinPerMin: Value(m.sacSlopeBarPerMinPerMin),
              runtimeS: Value(m.runtimeSeconds),
              unsupportedReason: Value(m.unsupportedReason?.name),
            ),
          );
      // Replace rather than merge: a rebuild can produce fewer buckets than
      // the previous run, and a stale tail would skew every later average.
      await (_db.delete(
        _db.diveSacBuckets,
      )..where((t) => t.diveId.equals(m.diveId))).go();
      if (m.sacBuckets.isNotEmpty) {
        await _db.batch((batch) {
          batch.insertAll(_db.diveSacBuckets, [
            for (final b in m.sacBuckets)
              DiveSacBucketsCompanion.insert(
                diveId: m.diveId,
                bucketIndex: b.index,
                sacBarMin: b.sacBarPerMin,
              ),
          ]);
        });
      }
    });
  }

  /// Dives whose row is missing, built by an older engine, or built from a
  /// different dive version. Oldest dive first, so a sweep makes the most
  /// recently viewed dives current last.
  // stats-scope-exempt: a work list, not an aggregate; an excluded dive
  // still needs its metrics for the filter to answer about it.
  Future<List<String>> staleDiveIds({String? diverId}) async {
    final diverFilter = diverId != null ? 'AND d.diver_id = ?' : '';
    final rows = await _db
        .customSelect(
          'SELECT d.id AS id FROM dives d '
          'LEFT JOIN dive_derived_metrics m ON m.dive_id = d.id '
          'WHERE (m.dive_id IS NULL OR m.engine_version < ? '
          'OR m.source_updated_at != d.updated_at) $diverFilter '
          'ORDER BY d.dive_date_time ASC, d.id ASC',
          variables: [
            const Variable(DerivedMetricsService.version),
            if (diverId != null) Variable(diverId),
          ],
          readsFrom: {_db.dives, _db.diveDerivedMetricsRows},
        )
        .get();
    return rows.map((r) => r.read<String>('id')).toList();
  }

  Stream<void> watchChanges() => _db.tableUpdates(
    TableUpdateQuery.allOf([
      TableUpdateQuery.onTable(_db.diveDerivedMetricsRows),
      TableUpdateQuery.onTable(_db.diveSacBuckets),
    ]),
  );
}
