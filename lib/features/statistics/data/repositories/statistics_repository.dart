import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart' show compute, visibleForTesting;

import 'package:submersion/core/constants/gas_model.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/database/dive_stats_scope.dart';
import 'package:submersion/core/domain/visibility/visibility_scale.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/utils/gas_compressibility.dart';
import 'package:submersion/core/utils/stream_debounce.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_times_sql.dart';
import 'package:submersion/features/dive_log/data/repositories/profile_series_repository.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';
import 'package:submersion/features/dive_sites/domain/entities/site_dive_statistics.dart';
import 'package:submersion/features/statistics/data/dive_filter_sql.dart';
import 'package:submersion/features/statistics/data/series_profile_aggregates.dart';
import 'package:submersion/features/statistics/domain/entities/species_statistics.dart';
import 'package:submersion/features/statistics/domain/trend_aggregation.dart';

export 'package:submersion/features/statistics/domain/trend_aggregation.dart'
    show TrendDataPoint;

/// Per-dive outcome of the recorded (non-computed) deco classification.
///
/// The four groups partition the filtered dive library. [needsCompute] maps
/// dive id to that dive's `dives.updated_at`, which the computed fallback
/// uses as the profile revision in its cache fingerprint; the lean `Dive`
/// hydration used by the analysis pipeline carries no `updatedAt`, so this
/// scan is the only place that value is cheaply available. [noProfile] holds
/// dives that can never be classified from stored data.
typedef DecoSignalScan = ({
  Set<String> recordedDeco,
  Set<String> recordedNoDeco,
  Map<String, int> needsCompute,
  Set<String> noProfile,
});

/// Ranking item for lists
class RankingItem {
  final String id;
  final String name;
  final int count;
  final double? value;
  final String? subtitle;
  final DateTime? date;

  RankingItem({
    required this.id,
    required this.name,
    required this.count,
    this.value,
    this.subtitle,
    this.date,
  });
}

/// Distribution segment for pie charts
class DistributionSegment {
  final String label;
  final int count;
  final double percentage;

  /// Summed dive duration (seconds) behind this segment.
  ///
  /// Only populated by distributions where a per-segment total makes sense
  /// (e.g. dive type); null for distributions like time-of-day where a
  /// summed duration would double count against other segments' overlapping
  /// dives or simply isn't meaningful.
  final int? totalDurationSeconds;

  DistributionSegment({
    required this.label,
    required this.count,
    required this.percentage,
    this.totalDurationSeconds,
  });
}

/// One observed (entry method, exit method) pairing and how often it occurs.
///
/// Both values are stored EntryMethod enum names; the presentation layer
/// translates them.
class EntryExitPairCount {
  const EntryExitPairCount({
    required this.entryMethod,
    required this.exitMethod,
    required this.count,
  });

  final String entryMethod;
  final String? exitMethod;
  final int count;
}

/// Repository for all advanced statistics queries
class StatisticsRepository {
  /// Equation of state used to convert cylinder pressure to gas volume.
  ///
  /// Injected from `gasModelProvider` so flipping the preference rebuilds this
  /// repository and refreshes every gas statistic (issue #828).
  final GasModel gasModel;

  StatisticsRepository({this.gasModel = GasModel.real});

  AppDatabase get _db => DatabaseService.instance.database;
  final _log = LoggerService.forClass(StatisticsRepository);
  final _profileSeries = ProfileSeriesRepository();

  /// How many dives' packed series the profile aggregates read at once.
  ///
  /// The aggregates run over the whole filtered library, and a packed series
  /// is a blob: reading them all in one query holds every blob of every dive
  /// in memory, and hands a copy of that to the worker isolate. Reading a
  /// chunk at a time bounds both. A stream never spans dives, so a chunk
  /// boundary cannot split one and the per-chunk totals combine exactly.
  static const int defaultSeriesDiveChunkSize = 500;

  /// Overridable so a test can force a chunk boundary without seeding a
  /// library large enough to reach one.
  @visibleForTesting
  static int seriesDiveChunkSize = defaultSeriesDiveChunkSize;

  static Iterable<List<String>> _diveChunks(List<String> ids) sync* {
    final size = seriesDiveChunkSize;
    for (var start = 0; start < ids.length; start += size) {
      final end = start + size < ids.length ? start + size : ids.length;
      yield ids.sublist(start, end);
    }
  }

  /// The primary series of one chunk of dives, as blobs for the worker.
  Future<List<SeriesBlob>> _primaryBlobs(List<String> diveIds) async {
    final rows = await _profileSeries.getPrimaryRowsForDives(diveIds);
    return [
      for (final r in rows)
        SeriesBlob(
          diveId: r.diveId,
          computerId: r.computerId,
          samples: r.samples,
        ),
    ];
  }

  /// Emits whenever any table the statistics queries read is written, so every
  /// statistics provider refreshes after a merge, a bulk delete, an import, or
  /// a sync pull -- none of which go through a notifier.
  ///
  /// Broader than [DiveRepository.watchDivesChanges] because the aggregate SQL
  /// joins well beyond the `dives` table: `dive_tanks` and
  /// `tank_pressure_series` carry all of the SAC math, `sightings`/`species`
  /// the marine-life stats, `dive_sites`/`dive_centers`/`trips` the geographic
  /// stats. Subscribing only to the dives tick would leave every SAC chart
  /// stale after a sync applied a tank-pressure-only changeset, which never
  /// touches the `dives` row.
  ///
  /// Narrower than [DiveRepository.watchDiveDetailChanges], which also fires on
  /// media, tide records, and safety findings that no statistic reads.
  ///
  /// Replaces `statisticsVersionProvider`, a counter incremented from exactly
  /// one line in the app (inside `PaginatedDiveListNotifier`), which merge,
  /// consolidate, import, and sync never reached (issue #974).
  ///
  /// [DiveRepository.changeTickDebounce]-debounced so a multi-changeset sync
  /// recomputes the charts once on the settled state rather than once per
  /// intermediate commit.
  Stream<void> watchStatisticsChanges() => _db
      .tableUpdates(
        TableUpdateQuery.allOf([
          TableUpdateQuery.onTable(_db.dives),
          TableUpdateQuery.onTable(_db.diveProfileSeries),
          TableUpdateQuery.onTable(_db.diveTanks),
          TableUpdateQuery.onTable(_db.tankPressureSeries),
          TableUpdateQuery.onTable(_db.diveEquipment),
          TableUpdateQuery.onTable(_db.equipment),
          TableUpdateQuery.onTable(_db.diveWeights),
          TableUpdateQuery.onTable(_db.diveDiveTypes),
          TableUpdateQuery.onTable(_db.diveBuddies),
          TableUpdateQuery.onTable(_db.buddies),
          TableUpdateQuery.onTable(_db.sightings),
          TableUpdateQuery.onTable(_db.species),
          TableUpdateQuery.onTable(_db.diveSites),
          TableUpdateQuery.onTable(_db.diveCenters),
          TableUpdateQuery.onTable(_db.trips),
        ]),
      )
      .debounce(DiveRepository.changeTickDebounce);

  /// Builds the always-on statistics scope plus, when the diver has active
  /// filter axes, the `AND <alias>.id IN (<subquery>)` fragment and its raw
  /// params.
  ///
  /// The scope is emitted unconditionally and the user filter conditionally.
  /// They are deliberately separate: [buildFilteredDiveIdSubquery] is the
  /// diver's transient view filter and no-ops when nothing is selected, while
  /// [DiveStatsScope] is a persistent property of the dive. Folding the scope
  /// into the subquery would make the exclusion evaporate for every diver who
  /// never opens the filter sheet.
  ///
  /// Pass `gas: true` for SAC/RMV and gas-mix aggregates, which additionally
  /// drop per-dive gas exclusions and gauge-mode dives.
  ({String clause, List<Object?> params}) _diveFilter(
    DiveFilterState filter, {
    String alias = 'dives',
    bool gas = false,
  }) {
    final scope = DiveStatsScope.and(alias: alias, gas: gas);
    final f = buildFilteredDiveIdSubquery(filter);
    if (f.subquery.isEmpty) {
      return (clause: scope, params: const <Object?>[]);
    }
    return (
      clause: '$scope AND $alias.id IN (${f.subquery})',
      params: f.params,
    );
  }

  // ============================================================================
  // Gas Statistics
  // ============================================================================

  /// SAC rate of every dive in scope, in L/min at surface pressure, ordered by
  /// date. Requires tank volume data.
  ///
  /// Gas used is summed across a dive's tanks first, so a twinset or a stage
  /// dive yields one SAC value rather than one per cylinder.
  Future<List<TrendDataPoint>> getSacVolumePerDive({
    String? diverId,
    DiveFilterState filter = const DiveFilterState(),
  }) async {
    try {
      final diverFilter = diverId != null ? 'AND d.diver_id = ?' : '';
      final df = _diveFilter(filter, alias: 'd', gas: true);
      final params = diverId != null ? [diverId, ...df.params] : [...df.params];

      final results = await _db.customSelect('''
        SELECT
          d.id AS dive_id,
          d.dive_date_time,
          d.avg_depth,
          COALESCE(d.runtime, d.bottom_time) AS duration_sec,
          t.start_pressure,
          t.end_pressure,
          t.volume,
          t.o2_percent,
          t.he_percent
        FROM dives d
        JOIN dive_tanks t ON t.dive_id = d.id
        WHERE 1 = 1 $diverFilter ${df.clause}
          AND COALESCE(d.runtime, d.bottom_time) > 0
          AND d.avg_depth > 0
          AND t.start_pressure > t.end_pressure
          AND t.volume > 0
        ORDER BY d.dive_date_time
        ''', variables: params.map((p) => Variable(p)).toList()).get();

      // Sum gas across each dive's tanks before dividing, so a twinset is one
      // SAC value and not two.
      final Map<
        String,
        ({double gas, DateTime dateTime, int durationSec, double avgDepth})
      >
      diveSacs = {};

      for (final row in results) {
        final diveId = row.read<String>('dive_id');
        final startP = row.read<double>('start_pressure');
        final endP = row.read<double>('end_pressure');
        final vol = row.read<double>('volume');
        final o2 = row.read<double>('o2_percent');
        final he = row.read<double>('he_percent');
        final dateTimeMs = row.read<int>('dive_date_time');

        final gasUsed =
            gasVolume(
              tankSizeLiters: vol,
              pressureBar: startP,
              o2Percent: o2,
              hePercent: he,
              model: gasModel,
            ) -
            gasVolume(
              tankSizeLiters: vol,
              pressureBar: endP,
              o2Percent: o2,
              hePercent: he,
              model: gasModel,
            );
        if (gasUsed <= 0) continue;

        final existing = diveSacs[diveId];
        if (existing == null) {
          diveSacs[diveId] = (
            gas: gasUsed,
            dateTime: DateTime.fromMillisecondsSinceEpoch(
              dateTimeMs,
              isUtc: true,
            ),
            durationSec: row.read<int>('duration_sec'),
            avgDepth: row.read<double>('avg_depth'),
          );
        } else {
          diveSacs[diveId] = (
            gas: existing.gas + gasUsed,
            dateTime: existing.dateTime,
            durationSec: existing.durationSec,
            avgDepth: existing.avgDepth,
          );
        }
      }

      final points = <TrendDataPoint>[];
      for (final entry in diveSacs.entries) {
        final d = entry.value;
        final sac =
            d.gas / (d.durationSec / 60.0) / ((d.avgDepth / 10.0) + 1.0);
        if (sac <= 0) continue;
        points.add(
          TrendDataPoint(date: d.dateTime, value: sac, diveId: entry.key),
        );
      }
      points.sort((a, b) => a.date.compareTo(b.date));
      return points;
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get per-dive SAC volume',
        error: e,
        stackTrace: stackTrace,
      );
      return [];
    }
  }

  /// SAC rate of every dive in scope, in pressure per minute, ordered by date.
  ///
  /// Does not require tank volume: uses the pressure drop of the dive's single
  /// back-gas tank normalised to surface pressure.
  Future<List<TrendDataPoint>> getSacPressurePerDive({
    String? diverId,
    DiveFilterState filter = const DiveFilterState(),
  }) async {
    try {
      final diverFilter = diverId != null ? 'AND d.diver_id = ?' : '';
      final df = _diveFilter(filter, alias: 'd', gas: true);
      final params = diverId != null ? [diverId, ...df.params] : [...df.params];

      final results = await _db.customSelect('''
        SELECT
          d.id AS dive_id,
          d.dive_date_time AS dive_date_time,
          (t.start_pressure - t.end_pressure) / (COALESCE(d.runtime, d.bottom_time) / 60.0) / ((d.avg_depth / 10.0) + 1) AS sac
        FROM dives d
        JOIN dive_tanks t ON t.id = (
          SELECT t2.id FROM dive_tanks t2
          WHERE t2.dive_id = d.id
            AND t2.start_pressure > t2.end_pressure
            AND (
              t2.tank_role = 'backGas'
              OR NOT EXISTS (
                SELECT 1 FROM dive_tanks t3
                WHERE t3.dive_id = d.id AND t3.tank_role = 'backGas'
              )
            )
          ORDER BY t2.tank_order, t2.rowid
          LIMIT 1
        )
        WHERE 1 = 1 $diverFilter ${df.clause}
          AND COALESCE(d.runtime, d.bottom_time) > 0
          AND d.avg_depth > 0
        ORDER BY d.dive_date_time
        ''', variables: params.map((p) => Variable(p)).toList()).get();

      return results
          .map(
            (row) => TrendDataPoint(
              date: DateTime.fromMillisecondsSinceEpoch(
                row.read<int>('dive_date_time'),
                isUtc: true,
              ),
              value: row.read<double>('sac'),
              diveId: row.read<String>('dive_id'),
            ),
          )
          .toList();
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get per-dive SAC pressure',
        error: e,
        stackTrace: stackTrace,
      );
      return [];
    }
  }

  /// Get gas mix distribution (Air, Nitrox, Trimix)
  Future<List<DistributionSegment>> getGasMixDistribution({
    String? diverId,
    DiveFilterState filter = const DiveFilterState(),
  }) async {
    try {
      final diverFilter = diverId != null ? 'AND d.diver_id = ?' : '';
      final df = _diveFilter(filter, alias: 'd', gas: true);
      final params = diverId != null ? [diverId, ...df.params] : [...df.params];

      final results = await _db.customSelect('''
        SELECT
          CASE
            WHEN t.he_percent > 0 THEN 'Trimix'
            WHEN t.o2_percent > 21.5 THEN 'Nitrox'
            ELSE 'Air'
          END AS gas_type,
          COUNT(DISTINCT d.id) AS dive_count
        FROM dives d
        JOIN dive_tanks t ON t.dive_id = d.id
        WHERE 1=1 $diverFilter ${df.clause}
        GROUP BY gas_type
        ORDER BY dive_count DESC
        ''', variables: params.map((p) => Variable(p)).toList()).get();

      final total = results.fold<int>(
        0,
        (sum, row) => sum + row.read<int>('dive_count'),
      );
      if (total == 0) return [];

      return results.map((row) {
        final count = row.read<int>('dive_count');
        return DistributionSegment(
          label: row.read<String>('gas_type'),
          count: count,
          percentage: count / total * 100,
        );
      }).toList();
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get gas mix distribution',
        error: e,
        stackTrace: stackTrace,
      );
      return [];
    }
  }

  /// Get best and worst SAC dives in L/min (volume-based)
  /// Requires tank volume data
  Future<({RankingItem? best, RankingItem? worst})> getSacVolumeRecords({
    String? diverId,
    DiveFilterState filter = const DiveFilterState(),
  }) async {
    try {
      final diverFilter = diverId != null ? 'AND d.diver_id = ?' : '';
      final df = _diveFilter(filter, alias: 'd', gas: true);
      final params = diverId != null ? [diverId, ...df.params] : [...df.params];

      final results = await _db.customSelect('''
        SELECT
          d.id AS dive_id,
          d.dive_number,
          d.dive_date_time,
          d.avg_depth,
          COALESCE(d.runtime, d.bottom_time) AS duration_sec,
          ds.name AS site_name,
          t.start_pressure,
          t.end_pressure,
          t.volume,
          t.o2_percent,
          t.he_percent
        FROM dives d
        JOIN dive_tanks t ON t.dive_id = d.id
        LEFT JOIN dive_sites ds ON ds.id = d.site_id
        WHERE COALESCE(d.runtime, d.bottom_time) > 0
          AND d.avg_depth > 0
          AND t.start_pressure > t.end_pressure
          AND t.volume > 0
         
          $diverFilter ${df.clause}
        ORDER BY d.dive_date_time
        ''', variables: params.map((p) => Variable(p)).toList()).get();

      // Accumulate gas per dive, then compute SAC
      final Map<
        String,
        ({
          double gas,
          int durationSec,
          double avgDepth,
          int dateTimeMs,
          int? diveNum,
          String? siteName,
        })
      >
      dives = {};

      for (final row in results) {
        final diveId = row.read<String>('dive_id');
        final o2 = row.read<double>('o2_percent');
        final he = row.read<double>('he_percent');
        final vol = row.read<double>('volume');
        final used =
            gasVolume(
              tankSizeLiters: vol,
              pressureBar: row.read<double>('start_pressure'),
              o2Percent: o2,
              hePercent: he,
              model: gasModel,
            ) -
            gasVolume(
              tankSizeLiters: vol,
              pressureBar: row.read<double>('end_pressure'),
              o2Percent: o2,
              hePercent: he,
              model: gasModel,
            );
        if (used <= 0) continue;

        final existing = dives[diveId];
        if (existing == null) {
          dives[diveId] = (
            gas: used,
            durationSec: row.read<int>('duration_sec'),
            avgDepth: row.read<double>('avg_depth'),
            dateTimeMs: row.read<int>('dive_date_time'),
            diveNum: row.read<int?>('dive_number'),
            siteName: row.read<String?>('site_name'),
          );
        } else {
          dives[diveId] = (
            gas: existing.gas + used,
            durationSec: existing.durationSec,
            avgDepth: existing.avgDepth,
            dateTimeMs: existing.dateTimeMs,
            diveNum: existing.diveNum,
            siteName: existing.siteName,
          );
        }
      }

      // Compute SAC and find best/worst
      RankingItem? best;
      RankingItem? worst;

      for (final entry in dives.entries) {
        final d = entry.value;
        final sac =
            d.gas / (d.durationSec / 60.0) / ((d.avgDepth / 10.0) + 1.0);
        if (sac <= 0) continue;

        final item = RankingItem(
          id: entry.key,
          name: d.siteName ?? 'Dive #${d.diveNum ?? "?"}',
          count: 0,
          value: sac,
          date: DateTime.fromMillisecondsSinceEpoch(d.dateTimeMs, isUtc: true),
        );

        if (best == null || sac < best.value!) best = item;
        if (worst == null || sac > worst.value!) worst = item;
      }

      return (best: best, worst: worst);
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get SAC volume records',
        error: e,
        stackTrace: stackTrace,
      );
      return (best: null, worst: null);
    }
  }

  /// Get best and worst SAC dives in pressure/min (pressure-based)
  /// Does not require tank volume
  Future<({RankingItem? best, RankingItem? worst})> getSacPressureRecords({
    String? diverId,
    DiveFilterState filter = const DiveFilterState(),
  }) async {
    try {
      final diverFilter = diverId != null ? 'AND d.diver_id = ?' : '';
      final df = _diveFilter(filter, alias: 'd', gas: true);
      final params = diverId != null ? [diverId, ...df.params] : [...df.params];

      final results = await _db.customSelect('''
        SELECT
          d.id,
          d.dive_number,
          ds.name AS site_name,
          d.dive_date_time,
          (t.start_pressure - t.end_pressure) / (COALESCE(d.runtime, d.bottom_time) / 60.0) / ((d.avg_depth / 10.0) + 1) AS sac
        FROM dives d
        JOIN dive_tanks t ON t.id = (
          SELECT t2.id FROM dive_tanks t2
          WHERE t2.dive_id = d.id
            AND t2.start_pressure > t2.end_pressure
            AND (
              t2.tank_role = 'backGas'
              OR NOT EXISTS (
                SELECT 1 FROM dive_tanks t3
                WHERE t3.dive_id = d.id AND t3.tank_role = 'backGas'
              )
            )
          ORDER BY t2.tank_order, t2.rowid
          LIMIT 1
        )
        LEFT JOIN dive_sites ds ON ds.id = d.site_id
        WHERE COALESCE(d.runtime, d.bottom_time) > 0
          AND d.avg_depth > 0
         
          $diverFilter ${df.clause}
        ORDER BY sac ASC
        ''', variables: params.map((p) => Variable(p)).toList()).get();

      if (results.isEmpty) return (best: null, worst: null);

      RankingItem mapRow(dynamic row) {
        final dateMs = row.read<int>('dive_date_time');
        final date = DateTime.fromMillisecondsSinceEpoch(dateMs, isUtc: true);
        final diveNum = row.read<int?>('dive_number');
        final siteName = row.read<String?>('site_name');
        return RankingItem(
          id: row.read<String>('id'),
          name: siteName ?? 'Dive #${diveNum ?? "?"}',
          count: 0,
          value: row.read<double>('sac'),
          date: date,
        );
      }

      return (best: mapRow(results.first), worst: mapRow(results.last));
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get SAC pressure records',
        error: e,
        stackTrace: stackTrace,
      );
      return (best: null, worst: null);
    }
  }

  /// Get volume-based average SAC by tank role (back gas, stage, deco, etc.)
  ///
  /// Returns a map of tank role to average SAC in L/min.
  /// Requires tank volume data.
  Future<Map<String, double>> getSacVolumeByTankRole({
    String? diverId,
    DiveFilterState filter = const DiveFilterState(),
  }) async {
    try {
      final diverFilter = diverId != null ? 'AND d.diver_id = ?' : '';
      final df = _diveFilter(filter, alias: 'd', gas: true);
      final params = diverId != null ? [diverId, ...df.params] : [...df.params];

      final results = await _db.customSelect('''
        SELECT
          t.tank_role,
          t.start_pressure,
          t.end_pressure,
          t.volume,
          t.o2_percent,
          t.he_percent,
          d.avg_depth,
          COALESCE(d.runtime, d.bottom_time) AS duration_sec
        FROM dives d
        INNER JOIN dive_tanks t ON t.dive_id = d.id
        WHERE t.start_pressure IS NOT NULL
          AND t.end_pressure IS NOT NULL
          AND t.start_pressure > t.end_pressure
          AND COALESCE(d.runtime, d.bottom_time) > 0
          AND d.avg_depth > 0
          AND t.volume > 0
         
          $diverFilter ${df.clause}
        ''', variables: params.map((p) => Variable(p)).toList()).get();

      final Map<String, List<double>> sacsByRole = {};

      for (final row in results) {
        final role = row.read<String>('tank_role');
        final o2 = row.read<double>('o2_percent');
        final he = row.read<double>('he_percent');
        final vol = row.read<double>('volume');
        final used =
            gasVolume(
              tankSizeLiters: vol,
              pressureBar: row.read<double>('start_pressure'),
              o2Percent: o2,
              hePercent: he,
              model: gasModel,
            ) -
            gasVolume(
              tankSizeLiters: vol,
              pressureBar: row.read<double>('end_pressure'),
              o2Percent: o2,
              hePercent: he,
              model: gasModel,
            );
        if (used <= 0) continue;

        final durationMin = row.read<int>('duration_sec') / 60.0;
        final ambientBar = (row.read<double>('avg_depth') / 10.0) + 1.0;
        final sac = used / durationMin / ambientBar;
        if (sac > 0) {
          sacsByRole.putIfAbsent(role, () => []).add(sac);
        }
      }

      final Map<String, double> avgByRole = {};
      for (final entry in sacsByRole.entries) {
        avgByRole[entry.key] =
            entry.value.reduce((a, b) => a + b) / entry.value.length;
      }
      return avgByRole;
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get SAC in volume by tank role',
        error: e,
        stackTrace: stackTrace,
      );
      return {};
    }
  }

  /// Get pressure-based average SAC by tank role (back gas, stage, deco, etc.)
  ///
  /// Returns a map of tank role to average SAC in bar/min.
  /// Does not require tank volume.
  Future<Map<String, double>> getSacPressureByTankRole({
    String? diverId,
    DiveFilterState filter = const DiveFilterState(),
  }) async {
    try {
      final diverFilter = diverId != null ? 'AND d.diver_id = ?' : '';
      final df = _diveFilter(filter, alias: 'd', gas: true);
      final params = diverId != null ? [diverId, ...df.params] : [...df.params];

      final results = await _db.customSelect('''
        SELECT
          t.tank_role,
          AVG(
            CASE
              WHEN COALESCE(d.runtime, d.bottom_time) > 0 AND d.avg_depth > 0 AND t.start_pressure > t.end_pressure THEN
                (t.start_pressure - t.end_pressure) / (COALESCE(d.runtime, d.bottom_time) / 60.0) / ((d.avg_depth / 10.0) + 1)
              ELSE NULL
            END
          ) AS avg_sac
        FROM dives d
        INNER JOIN dive_tanks t ON t.dive_id = d.id
        WHERE t.start_pressure IS NOT NULL
          AND t.end_pressure IS NOT NULL
          AND COALESCE(d.runtime, d.bottom_time) > 0
          AND d.avg_depth > 0
         
          $diverFilter ${df.clause}
        GROUP BY t.tank_role
        HAVING avg_sac IS NOT NULL
        ORDER BY avg_sac ASC
        ''', variables: params.map((p) => Variable(p)).toList()).get();

      final Map<String, double> sacByRole = {};
      for (final row in results) {
        final role = row.read<String>('tank_role');
        final sac = row.read<double>('avg_sac');
        sacByRole[role] = sac;
      }

      return sacByRole;
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get SAC in pressure by tank role',
        error: e,
        stackTrace: stackTrace,
      );
      return {};
    }
  }

  /// Get dive type distribution (recreational, night, deep, wreck, etc.).
  ///
  /// Emits the dive-type id as a stable key, not display text: the
  /// presentation layer resolves it through the built-in translation table
  /// (see `diveTypeDistributionLabel`). Capitalizing the slug here is what
  /// left this chart English under every locale.
  ///
  /// A dive carrying several types counts once under each of them, so the
  /// per-type totals deliberately sum to more than the diver's career total.
  /// Each dive's contribution is its `Dive.effectiveRuntime`, resolved in SQL
  /// by [effectiveRuntimeSecondsSql] so a dive whose duration only exists in
  /// its profile is not reported as zero.
  Future<List<DistributionSegment>> getDiveTypeDistribution({
    String? diverId,
    DiveFilterState filter = const DiveFilterState(),
  }) async {
    try {
      final diverFilter = diverId != null ? 'AND diver_id = ?' : '';
      final df = _diveFilter(filter, alias: 'd');
      final params = diverId != null ? [diverId, ...df.params] : [...df.params];

      final results = await _db.customSelect('''
        SELECT
          ddt.dive_type_id AS dive_type,
          COUNT(*) AS count,
          SUM(${effectiveRuntimeSecondsSql('d')}) AS total_time
        FROM dive_dive_types ddt
        JOIN dives d ON d.id = ddt.dive_id
        WHERE 1=1 $diverFilter ${df.clause}
        GROUP BY ddt.dive_type_id
        ORDER BY count DESC
        ''', variables: params.map((p) => Variable(p)).toList()).get();

      final total = results.fold<int>(
        0,
        (sum, row) => sum + row.read<int>('count'),
      );
      if (total == 0) return [];

      return results.map((row) {
        final count = row.read<int>('count');
        final label = row.read<String>('dive_type');
        return DistributionSegment(
          label: label,
          count: count,
          percentage: count / total * 100,
          // NULL when no dive of this type carries a duration in any
          // form, which reads as no time logged.
          totalDurationSeconds: row.readNullable<int>('total_time') ?? 0,
        );
      }).toList();
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get dive type distribution',
        error: e,
        stackTrace: stackTrace,
      );
      return [];
    }
  }

  // ============================================================================
  // Dive Progression Statistics
  // ============================================================================

  /// Maximum depth of every dive in scope, ordered by date.
  ///
  /// One point per dive. Scope comes entirely from [filter]; there is
  /// deliberately no built-in window, because a hardcoded five-year cutoff
  /// used to make "lifetime" unreachable (issue #299).
  Future<List<TrendDataPoint>> getDepthPerDive({
    String? diverId,
    DiveFilterState filter = const DiveFilterState(),
  }) async {
    try {
      final diverFilter = diverId != null ? 'AND diver_id = ?' : '';
      final df = _diveFilter(filter, alias: 'dives');
      final params = diverId != null ? [diverId, ...df.params] : [...df.params];

      final results = await _db.customSelect('''
        SELECT id, dive_date_time, max_depth
        FROM dives
        WHERE max_depth IS NOT NULL $diverFilter ${df.clause}
        ORDER BY dive_date_time
        ''', variables: params.map((p) => Variable(p)).toList()).get();

      return results.map((row) {
        return TrendDataPoint(
          date: DateTime.fromMillisecondsSinceEpoch(
            row.read<int>('dive_date_time'),
            isUtc: true,
          ),
          value: row.read<double>('max_depth'),
          diveId: row.read<String>('id'),
        );
      }).toList();
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get per-dive max depth',
        error: e,
        stackTrace: stackTrace,
      );
      return [];
    }
  }

  /// Bottom time in minutes for every dive in scope, ordered by date.
  Future<List<TrendDataPoint>> getBottomTimePerDive({
    String? diverId,
    DiveFilterState filter = const DiveFilterState(),
  }) async {
    try {
      final diverFilter = diverId != null ? 'AND diver_id = ?' : '';
      final df = _diveFilter(filter, alias: 'dives');
      final params = diverId != null ? [diverId, ...df.params] : [...df.params];

      final results = await _db.customSelect('''
        SELECT id, dive_date_time, bottom_time / 60.0 AS minutes
        FROM dives
        WHERE bottom_time IS NOT NULL $diverFilter ${df.clause}
        ORDER BY dive_date_time
        ''', variables: params.map((p) => Variable(p)).toList()).get();

      return results.map((row) {
        return TrendDataPoint(
          date: DateTime.fromMillisecondsSinceEpoch(
            row.read<int>('dive_date_time'),
            isUtc: true,
          ),
          value: row.read<double>('minutes'),
          diveId: row.read<String>('id'),
        );
      }).toList();
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get per-dive bottom time',
        error: e,
        stackTrace: stackTrace,
      );
      return [];
    }
  }

  /// Get dives per year
  Future<List<({int year, int count})>> getDivesPerYear({
    String? diverId,
    DiveFilterState filter = const DiveFilterState(),
  }) async {
    try {
      final diverFilter = diverId != null ? 'AND diver_id = ?' : '';
      final df = _diveFilter(filter, alias: 'dives');
      final params = diverId != null ? [diverId, ...df.params] : [...df.params];

      final results = await _db.customSelect('''
        SELECT
          strftime('%Y', dive_date_time / 1000, 'unixepoch') AS year,
          COUNT(*) AS count
        FROM dives
        WHERE 1=1 $diverFilter ${df.clause}
        GROUP BY year
        ORDER BY year
        ''', variables: params.map((p) => Variable(p)).toList()).get();

      return results.map((row) {
        return (
          year: int.parse(row.read<String>('year')),
          count: row.read<int>('count'),
        );
      }).toList();
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get dives per year',
        error: e,
        stackTrace: stackTrace,
      );
      return [];
    }
  }

  /// Aggregates for a single calendar year (dashboard year-in-review).
  /// The duration sum mirrors getStatistics' total_time expression
  /// (COALESCE(runtime, bottom_time), seconds) so the card's hours agree
  /// with the hero header's lifetime hours.
  Future<YearStats> getYearStats(int year, {String? diverId}) async {
    try {
      // Half-open millisecond range [Jan 1, next Jan 1) rather than
      // strftime('%Y', ...): the range predicate lets SQLite use the
      // (diver_id, dive_date_time) index instead of scanning every row.
      // UTC boundaries match the wall-clock-as-UTC epoch-ms convention that
      // dive_date_time is stored in, so dives near the year edge aren't
      // shifted across the boundary by the local timezone offset.
      final startMs = DateTime.utc(year).millisecondsSinceEpoch;
      final endMs = DateTime.utc(year + 1).millisecondsSinceEpoch;
      final diverFilter = diverId != null ? 'AND diver_id = ?' : '';
      final results = await _db
          .customSelect(
            '''
        SELECT
          COUNT(*) AS dive_count,
          COALESCE(SUM(COALESCE(runtime, bottom_time)), 0) AS total_seconds,
          MAX(max_depth) AS max_depth
        FROM dives
        WHERE dive_date_time >= ? AND dive_date_time < ?
        $diverFilter${DiveStatsScope.and(alias: 'dives')}
        ''',
            variables: [
              Variable<int>(startMs),
              Variable<int>(endMs),
              if (diverId != null) Variable<String>(diverId),
            ],
          )
          .getSingle();

      return YearStats(
        diveCount: results.read<int>('dive_count'),
        totalSeconds: results.read<int>('total_seconds'),
        maxDepth: results.readNullable<double>('max_depth'),
      );
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get year stats for $year',
        error: e,
        stackTrace: stackTrace,
      );
      return const YearStats(diveCount: 0, totalSeconds: 0);
    }
  }

  /// Dives grouped by the primary thickness of linked exposure suits
  /// (wetsuit/drysuit). COUNT(DISTINCT) so a dive with two suits of the same
  /// thickness counts once per bucket.
  Future<List<({double mm, int count})>> getDivesBySuitThickness({
    String? diverId,
    DiveFilterState filter = const DiveFilterState(),
  }) async {
    try {
      final diverFilter = diverId != null ? 'AND d.diver_id = ?' : '';
      final df = _diveFilter(filter, alias: 'd');
      final params = diverId != null ? [diverId, ...df.params] : [...df.params];

      final results = await _db.customSelect('''
        SELECT ea.value_num AS mm, COUNT(DISTINCT d.id) AS count
        FROM dives d
        JOIN dive_equipment de ON de.dive_id = d.id
        JOIN equipment e ON e.id = de.equipment_id
          AND e.type IN ('wetsuit', 'drysuit')
        JOIN equipment_attributes ea ON ea.equipment_id = e.id
          AND ea.attr_key = 'thickness_mm'
          AND ea.is_custom = 0
          AND ea.value_num IS NOT NULL
        WHERE 1=1 $diverFilter ${df.clause}
        GROUP BY ea.value_num
        ORDER BY ea.value_num
        ''', variables: params.map((p) => Variable(p)).toList()).get();

      return results.map((row) {
        return (mm: row.read<double>('mm'), count: row.read<int>('count'));
      }).toList();
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get dives by suit thickness',
        error: e,
        stackTrace: stackTrace,
      );
      return [];
    }
  }

  /// Running dive count, stepping once per dive, ordered by date.
  ///
  /// Was bucketed by month in SQL, which collapsed a whole trip into a single
  /// step and left nothing to zoom into (issue #299).
  Future<List<TrendDataPoint>> getCumulativeDiveCount({
    String? diverId,
    DiveFilterState filter = const DiveFilterState(),
  }) async {
    try {
      final diverFilter = diverId != null ? 'AND diver_id = ?' : '';
      final df = _diveFilter(filter, alias: 'dives');
      final params = diverId != null ? [diverId, ...df.params] : [...df.params];

      final results = await _db.customSelect('''
        SELECT id, dive_date_time
        FROM dives
        WHERE 1 = 1 $diverFilter ${df.clause}
        ORDER BY dive_date_time
        ''', variables: params.map((p) => Variable(p)).toList()).get();

      var runningTotal = 0;
      return results.map((row) {
        runningTotal++;
        return TrendDataPoint(
          date: DateTime.fromMillisecondsSinceEpoch(
            row.read<int>('dive_date_time'),
            isUtc: true,
          ),
          value: runningTotal.toDouble(),
          diveId: row.read<String>('id'),
        );
      }).toList();
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get cumulative dive count',
        error: e,
        stackTrace: stackTrace,
      );
      return [];
    }
  }

  // ============================================================================
  // Conditions & Environment Statistics
  // ============================================================================

  /// Get visibility distribution, binned by the diver's calibration.
  ///
  /// The calibration thresholds are passed into SQL as variables, so SQLite
  /// still does the aggregation and only the handful of grouped rows cross
  /// into Dart. Changing the calibration re-bins the same dives, which is the
  /// whole point of storing a measurement rather than a judgment.
  ///
  /// Labels are stable keys, not display text: a measured dive yields the
  /// [VisibilityBand] name, and a pre-v144 dive yields `legacy_<bucket>`. The
  /// two never merge, because a bucket does not say where in its range the
  /// dive fell, so it cannot be assigned a calibrated adjective. The page
  /// turns these keys into localized text.
  Future<List<DistributionSegment>> getVisibilityDistribution({
    required VisibilityScale scale,
    String? diverId,
    DiveFilterState filter = const DiveFilterState(),
  }) async {
    try {
      final diverFilter = diverId != null ? 'AND diver_id = ?' : '';
      final df = _diveFilter(filter, alias: 'dives');
      // Threshold variables come first: they appear before the diver and
      // filter placeholders in the statement below, and Drift binds
      // positionally.
      final scaleParams = [
        scale.excellentAtOrAboveM,
        scale.goodAtOrAboveM,
        scale.moderateAtOrAboveM,
      ];
      final params = diverId != null
          ? [...scaleParams, diverId, ...df.params]
          : [...scaleParams, ...df.params];

      final results = await _db.customSelect('''
        SELECT bucket, COUNT(*) AS count FROM (
          SELECT CASE
            WHEN visibility_meters IS NOT NULL THEN
              CASE
                WHEN visibility_meters >= ? THEN 'excellent'
                WHEN visibility_meters >= ? THEN 'good'
                WHEN visibility_meters >= ? THEN 'moderate'
                ELSE 'poor'
              END
            ELSE 'legacy_' || visibility
          END AS bucket
          FROM dives
          WHERE (
            visibility_meters IS NOT NULL
            OR (visibility IS NOT NULL AND visibility != '')
          ) $diverFilter ${df.clause}
        )
        GROUP BY bucket
        ''', variables: params.map((p) => Variable(p)).toList()).get();

      final counts = <String, int>{
        for (final row in results)
          row.read<String>('bucket'): row.read<int>('count'),
      };

      final total = counts.values.fold<int>(0, (sum, c) => sum + c);
      if (total == 0) return [];

      // Calibrated bands first, best to worst, then whatever legacy buckets
      // remain. The legacy segments shrink naturally as old dives are edited.
      final ordered = <String>[
        ...[
          VisibilityBand.excellent,
          VisibilityBand.good,
          VisibilityBand.moderate,
          VisibilityBand.poor,
        ].map((b) => b.name).where(counts.containsKey),
        ...counts.keys.where((k) => k.startsWith('legacy_')).toList()..sort(),
      ];

      return ordered.map((key) {
        final count = counts[key]!;
        return DistributionSegment(
          label: key,
          count: count,
          percentage: count / total * 100,
        );
      }).toList();
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get visibility distribution',
        error: e,
        stackTrace: stackTrace,
      );
      return [];
    }
  }

  /// Get water type distribution (salt/fresh).
  ///
  /// Emits the stored WaterType enum name as a stable key; the presentation
  /// layer translates it (see `waterTypeDistributionLabel`).
  Future<List<DistributionSegment>> getWaterTypeDistribution({
    String? diverId,
    DiveFilterState filter = const DiveFilterState(),
  }) async {
    try {
      final diverFilter = diverId != null ? 'AND diver_id = ?' : '';
      final df = _diveFilter(filter, alias: 'dives');
      final params = diverId != null ? [diverId, ...df.params] : [...df.params];

      final results = await _db.customSelect('''
        SELECT
          water_type,
          COUNT(*) AS count
        FROM dives
        WHERE water_type IS NOT NULL AND water_type != '' $diverFilter ${df.clause}
        GROUP BY water_type
        ORDER BY count DESC
        ''', variables: params.map((p) => Variable(p)).toList()).get();

      final total = results.fold<int>(
        0,
        (sum, row) => sum + row.read<int>('count'),
      );
      if (total == 0) return [];

      return results.map((row) {
        final count = row.read<int>('count');
        return DistributionSegment(
          label: row.read<String>('water_type'),
          count: count,
          percentage: count / total * 100,
        );
      }).toList();
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get water type distribution',
        error: e,
        stackTrace: stackTrace,
      );
      return [];
    }
  }

  /// Get entry method distribution.
  ///
  /// Emits the stored EntryMethod enum name as a stable key; the
  /// presentation layer translates it (see `entryMethodDistributionLabel`).
  Future<List<DistributionSegment>> getEntryMethodDistribution({
    String? diverId,
    DiveFilterState filter = const DiveFilterState(),
  }) async {
    try {
      final diverFilter = diverId != null ? 'AND diver_id = ?' : '';
      final df = _diveFilter(filter, alias: 'dives');
      final params = diverId != null ? [diverId, ...df.params] : [...df.params];

      final results = await _db.customSelect('''
        SELECT
          entry_method,
          COUNT(*) AS count
        FROM dives
        WHERE entry_method IS NOT NULL AND entry_method != '' $diverFilter ${df.clause}
        GROUP BY entry_method
        ORDER BY count DESC
        ''', variables: params.map((p) => Variable(p)).toList()).get();

      final total = results.fold<int>(
        0,
        (sum, row) => sum + row.read<int>('count'),
      );
      if (total == 0) return [];

      return results.map((row) {
        final count = row.read<int>('count');
        return DistributionSegment(
          label: row.read<String>('entry_method'),
          count: count,
          percentage: count / total * 100,
        );
      }).toList();
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get entry method distribution',
        error: e,
        stackTrace: stackTrace,
      );
      return [];
    }
  }

  /// Observed entry/exit method pairings among a diver's dives at one site,
  /// most frequent first (issue #1104).
  ///
  /// Grouping on the pair is deliberate, not incidental. The dive form
  /// defaults exit method to mirror entry, so taking the most common
  /// exit_method independently would over-report "in and out the same way"
  /// for values the diver never actually set. Rows with no entry method carry
  /// no information and are excluded; a null exit method is meaningful and is
  /// carried through as null.
  Future<List<EntryExitPairCount>> getEntryExitMethodPairsForSite({
    required String siteId,
    String? diverId,
  }) async {
    try {
      final diverFilter = diverId != null ? 'AND diver_id = ?' : '';
      final params = diverId != null ? [siteId, diverId] : [siteId];

      final results = await _db.customSelect('''
        SELECT
          entry_method,
          exit_method,
          COUNT(*) AS count
        FROM dives
        WHERE site_id = ?
          AND entry_method IS NOT NULL AND entry_method != '' $diverFilter
          ${DiveStatsScope.and(alias: 'dives')}
        GROUP BY entry_method, exit_method
        ORDER BY count DESC
        ''', variables: params.map((p) => Variable(p)).toList()).get();

      return results.map((row) {
        final exit = row.read<String?>('exit_method');
        return EntryExitPairCount(
          entryMethod: row.read<String>('entry_method'),
          exitMethod: (exit == null || exit.isEmpty) ? null : exit,
          count: row.read<int>('count'),
        );
      }).toList();
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get entry/exit method pairs for site: $siteId',
        error: e,
        stackTrace: stackTrace,
      );
      return [];
    }
  }

  /// Auto-computed dive statistics for a single site (submersion-app/submersion#1018,
  /// #1038): dive count, depth range, duration range/average, and first/last
  /// dive dates, aggregated over the dives actually logged at [siteId].
  ///
  /// Duration is approximated as `COALESCE(runtime, bottom_time)`, a
  /// deliberate simplification of [Dive.effectiveRuntime]'s 4-step fallback
  /// chain: the entry/exit-time-difference and profile-derived steps cannot
  /// be expressed in SQL, so dives that only carry those will slightly
  /// undercount the duration stats.
  ///
  /// These are descriptive numbers, so [DiveStatsScope] applies: a dive the
  /// diver ticked "exclude from statistics" and a planner entry for a dive
  /// never made contribute to none of them, the count included.
  ///
  /// Returns [SiteDiveStatistics.empty] (diveCount 0, all other fields null)
  /// when the site has no matching dives, or on error.
  Future<SiteDiveStatistics> getSiteDiveStatistics({
    required String siteId,
    String? diverId,
  }) async {
    try {
      final diverFilter = diverId != null ? 'AND diver_id = ?' : '';
      final params = diverId != null ? [siteId, diverId] : [siteId];

      final result = await _db.customSelect('''
        SELECT
          COUNT(*) AS dive_count,
          MAX(max_depth) AS max_depth_reached,
          MIN(max_depth) AS min_depth_reached,
          MAX(COALESCE(runtime, bottom_time)) AS longest_dive_seconds,
          AVG(COALESCE(runtime, bottom_time)) AS average_duration_seconds,
          MIN(dive_date_time) AS first_dive_at,
          MAX(dive_date_time) AS last_dive_at
        FROM dives
        WHERE site_id = ? $diverFilter
          ${DiveStatsScope.and(alias: 'dives')}
        ''', variables: params.map((p) => Variable(p)).toList()).getSingle();

      final diveCount = result.read<int>('dive_count');
      if (diveCount == 0) return SiteDiveStatistics.empty;

      final firstDiveMs = result.read<int?>('first_dive_at');
      final lastDiveMs = result.read<int?>('last_dive_at');

      return SiteDiveStatistics(
        diveCount: diveCount,
        maxDepthReached: result.read<double?>('max_depth_reached'),
        minDepthReached: result.read<double?>('min_depth_reached'),
        longestDiveSeconds: result.read<int?>('longest_dive_seconds'),
        averageDurationSeconds: result.read<double?>(
          'average_duration_seconds',
        ),
        // `dive_date_time` is persisted as a wall clock flagged UTC, the same
        // convention `DiveRepositoryImpl` hydrates with. Reading it back as a
        // local `DateTime` would shift the displayed first/last dive date by
        // the device's UTC offset.
        firstDiveAt: firstDiveMs != null
            ? DateTime.fromMillisecondsSinceEpoch(firstDiveMs, isUtc: true)
            : null,
        lastDiveAt: lastDiveMs != null
            ? DateTime.fromMillisecondsSinceEpoch(lastDiveMs, isUtc: true)
            : null,
      );
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get dive statistics for site: $siteId',
        error: e,
        stackTrace: stackTrace,
      );
      return SiteDiveStatistics.empty;
    }
  }

  /// Get temperature by month (min/avg/max)
  Future<List<({int month, double? minTemp, double? avgTemp, double? maxTemp})>>
  getTemperatureByMonth({
    String? diverId,
    DiveFilterState filter = const DiveFilterState(),
  }) async {
    try {
      final diverFilter = diverId != null ? 'AND diver_id = ?' : '';
      final df = _diveFilter(filter, alias: 'dives');
      final params = diverId != null ? [diverId, ...df.params] : [...df.params];

      final results = await _db.customSelect('''
        SELECT
          CAST(strftime('%m', dive_date_time / 1000, 'unixepoch') AS INTEGER) AS month,
          MIN(water_temp) AS min_temp,
          AVG(water_temp) AS avg_temp,
          MAX(water_temp) AS max_temp
        FROM dives
        WHERE water_temp IS NOT NULL $diverFilter ${df.clause}
        GROUP BY month
        ORDER BY month
        ''', variables: params.map((p) => Variable(p)).toList()).get();

      return results.map((row) {
        return (
          month: row.read<int>('month'),
          minTemp: row.read<double?>('min_temp'),
          avgTemp: row.read<double?>('avg_temp'),
          maxTemp: row.read<double?>('max_temp'),
        );
      }).toList();
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get temperature by month',
        error: e,
        stackTrace: stackTrace,
      );
      return [];
    }
  }

  // ============================================================================
  // Social & Buddies Statistics
  // ============================================================================

  /// Get top buddies by dive count
  Future<List<RankingItem>> getTopBuddies({
    String? diverId,
    int limit = 10,
    DiveFilterState filter = const DiveFilterState(),
  }) async {
    try {
      final diverFilter = diverId != null ? 'AND d.diver_id = ?' : '';
      final df = _diveFilter(filter, alias: 'd');
      final params = diverId != null
          ? [diverId, ...df.params, limit]
          : [...df.params, limit];

      final results = await _db.customSelect('''
        SELECT
          b.id,
          b.name,
          COUNT(db.dive_id) AS dive_count
        FROM buddies b
        JOIN dive_buddies db ON db.buddy_id = b.id
        JOIN dives d ON d.id = db.dive_id
        WHERE 1=1 $diverFilter ${df.clause}
        GROUP BY b.id
        ORDER BY dive_count DESC
        LIMIT ?
        ''', variables: params.map((p) => Variable(p)).toList()).get();

      return results.map((row) {
        return RankingItem(
          id: row.read<String>('id'),
          name: row.read<String>('name'),
          count: row.read<int>('dive_count'),
        );
      }).toList();
    } catch (e, stackTrace) {
      _log.error('Failed to get top buddies', error: e, stackTrace: stackTrace);
      return [];
    }
  }

  /// Get solo vs buddy dive percentage
  Future<({int solo, int buddy})> getSoloVsBuddyCount({
    String? diverId,
    DiveFilterState filter = const DiveFilterState(),
  }) async {
    try {
      final diverFilter = diverId != null ? 'AND d.diver_id = ?' : '';
      final df = _diveFilter(filter, alias: 'd');
      final params = diverId != null ? [diverId, ...df.params] : [...df.params];

      final results = await _db.customSelect('''
        SELECT
          SUM(CASE WHEN db.buddy_id IS NULL AND (d.buddy IS NULL OR d.buddy = '') THEN 1 ELSE 0 END) AS solo,
          SUM(CASE WHEN db.buddy_id IS NOT NULL OR (d.buddy IS NOT NULL AND d.buddy != '') THEN 1 ELSE 0 END) AS buddy
        FROM dives d
        LEFT JOIN dive_buddies db ON db.dive_id = d.id
        WHERE 1=1 $diverFilter ${df.clause}
        ''', variables: params.map((p) => Variable(p)).toList()).get();

      if (results.isEmpty) return (solo: 0, buddy: 0);
      return (
        solo: results.first.read<int?>('solo') ?? 0,
        buddy: results.first.read<int?>('buddy') ?? 0,
      );
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get solo vs buddy count',
        error: e,
        stackTrace: stackTrace,
      );
      return (solo: 0, buddy: 0);
    }
  }

  /// Get top dive centers by dive count
  Future<List<RankingItem>> getTopDiveCenters({
    String? diverId,
    int limit = 10,
    DiveFilterState filter = const DiveFilterState(),
  }) async {
    try {
      final diverFilter = diverId != null ? 'AND d.diver_id = ?' : '';
      final df = _diveFilter(filter, alias: 'd');
      final params = diverId != null
          ? [diverId, ...df.params, limit]
          : [...df.params, limit];

      final results = await _db.customSelect('''
        WITH dc_clean AS (
          SELECT
            id,
            name,
            NULLIF(TRIM(city), '')           AS city,
            NULLIF(TRIM(state_province), '') AS state_province,
            NULLIF(TRIM(country), '')        AS country
          FROM dive_centers
        )
        SELECT
          dc.id,
          dc.name,
          CASE
            WHEN dc.city IS NOT NULL AND dc.state_province IS NOT NULL AND dc.country IS NOT NULL
              THEN dc.city || ', ' || dc.state_province || ', ' || dc.country
            WHEN dc.city IS NOT NULL AND dc.country IS NOT NULL
              THEN dc.city || ', ' || dc.country
            WHEN dc.city IS NOT NULL AND dc.state_province IS NOT NULL
              THEN dc.city || ', ' || dc.state_province
            WHEN dc.state_province IS NOT NULL AND dc.country IS NOT NULL
              THEN dc.state_province || ', ' || dc.country
            WHEN dc.city IS NOT NULL THEN dc.city
            WHEN dc.state_province IS NOT NULL THEN dc.state_province
            WHEN dc.country IS NOT NULL THEN dc.country
            ELSE NULL
          END AS location,
          COUNT(d.id) AS dive_count
        FROM dc_clean dc
        JOIN dives d ON d.dive_center_id = dc.id
        WHERE 1=1 $diverFilter ${df.clause}
        GROUP BY dc.id
        ORDER BY dive_count DESC
        LIMIT ?
        ''', variables: params.map((p) => Variable(p)).toList()).get();

      return results.map((row) {
        return RankingItem(
          id: row.read<String>('id'),
          name: row.read<String>('name'),
          count: row.read<int>('dive_count'),
          subtitle: row.read<String?>('location'),
        );
      }).toList();
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get top dive centers',
        error: e,
        stackTrace: stackTrace,
      );
      return [];
    }
  }

  // ============================================================================
  // Geographic Statistics
  // ============================================================================

  /// Get countries visited with dive counts
  Future<List<RankingItem>> getCountriesVisited({
    String? diverId,
    int limit = 10,
    DiveFilterState filter = const DiveFilterState(),
  }) async {
    try {
      final diverFilter = diverId != null ? 'AND d.diver_id = ?' : '';
      final df = _diveFilter(filter, alias: 'd');
      final params = diverId != null
          ? [diverId, ...df.params, limit]
          : [...df.params, limit];

      final results = await _db.customSelect('''
        SELECT
          ds.country,
          COUNT(d.id) AS dive_count
        FROM dive_sites ds
        JOIN dives d ON d.site_id = ds.id
        WHERE ds.country IS NOT NULL AND ds.country != '' $diverFilter ${df.clause}
        GROUP BY ds.country
        ORDER BY dive_count DESC
        LIMIT ?
        ''', variables: params.map((p) => Variable(p)).toList()).get();

      return results.map((row) {
        final country = row.read<String>('country');
        return RankingItem(
          id: country,
          name: country,
          count: row.read<int>('dive_count'),
        );
      }).toList();
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get countries visited',
        error: e,
        stackTrace: stackTrace,
      );
      return [];
    }
  }

  /// Get regions explored with dive counts
  Future<List<RankingItem>> getRegionsExplored({
    String? diverId,
    int limit = 10,
    DiveFilterState filter = const DiveFilterState(),
  }) async {
    try {
      final diverFilter = diverId != null ? 'AND d.diver_id = ?' : '';
      final df = _diveFilter(filter, alias: 'd');
      final params = diverId != null
          ? [diverId, ...df.params, limit]
          : [...df.params, limit];

      final results = await _db.customSelect('''
        SELECT
          ds.region,
          ds.country,
          COUNT(d.id) AS dive_count
        FROM dive_sites ds
        JOIN dives d ON d.site_id = ds.id
        WHERE ds.region IS NOT NULL AND ds.region != '' $diverFilter ${df.clause}
        GROUP BY ds.region, ds.country
        ORDER BY dive_count DESC
        LIMIT ?
        ''', variables: params.map((p) => Variable(p)).toList()).get();

      return results.map((row) {
        final region = row.read<String>('region');
        return RankingItem(
          id: region,
          name: region,
          count: row.read<int>('dive_count'),
          subtitle: row.read<String?>('country'),
        );
      }).toList();
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get regions explored',
        error: e,
        stackTrace: stackTrace,
      );
      return [];
    }
  }

  /// Get dives per trip
  Future<List<RankingItem>> getDivesPerTrip({
    String? diverId,
    int limit = 10,
    DiveFilterState filter = const DiveFilterState(),
  }) async {
    try {
      final diverFilter = diverId != null ? 'AND d.diver_id = ?' : '';
      final df = _diveFilter(filter, alias: 'd');
      final params = diverId != null
          ? [diverId, ...df.params, limit]
          : [...df.params, limit];

      final results = await _db.customSelect('''
        SELECT
          t.id,
          t.name,
          t.location,
          COUNT(d.id) AS dive_count
        FROM trips t
        JOIN dives d ON d.trip_id = t.id
        WHERE 1=1 $diverFilter ${df.clause}
        GROUP BY t.id
        ORDER BY dive_count DESC
        LIMIT ?
        ''', variables: params.map((p) => Variable(p)).toList()).get();

      return results.map((row) {
        return RankingItem(
          id: row.read<String>('id'),
          name: row.read<String>('name'),
          count: row.read<int>('dive_count'),
          subtitle: row.read<String?>('location'),
        );
      }).toList();
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get dives per trip',
        error: e,
        stackTrace: stackTrace,
      );
      return [];
    }
  }

  // ============================================================================
  // Marine Life Statistics
  // ============================================================================

  /// Get unique species count
  Future<int> getUniqueSpeciesCount({
    String? diverId,
    DiveFilterState filter = const DiveFilterState(),
  }) async {
    try {
      final diverFilter = diverId != null ? 'AND d.diver_id = ?' : '';
      final df = _diveFilter(filter, alias: 'd');
      final params = diverId != null ? [diverId, ...df.params] : [...df.params];

      final results = await _db.customSelect('''
        SELECT COUNT(DISTINCT s.species_id) AS count
        FROM sightings s
        JOIN dives d ON d.id = s.dive_id
        WHERE 1=1 $diverFilter ${df.clause}
        ''', variables: params.map((p) => Variable(p)).toList()).get();

      return results.first.read<int>('count');
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get unique species count',
        error: e,
        stackTrace: stackTrace,
      );
      return 0;
    }
  }

  /// Get most common sightings
  Future<List<RankingItem>> getMostCommonSightings({
    String? diverId,
    int limit = 10,
    DiveFilterState filter = const DiveFilterState(),
  }) async {
    try {
      final diverFilter = diverId != null ? 'AND d.diver_id = ?' : '';
      final df = _diveFilter(filter, alias: 'd');
      final params = diverId != null
          ? [diverId, ...df.params, limit]
          : [...df.params, limit];

      final results = await _db.customSelect('''
        SELECT
          sp.id,
          sp.common_name,
          sp.category,
          SUM(s.count) AS total_count
        FROM sightings s
        JOIN species sp ON sp.id = s.species_id
        JOIN dives d ON d.id = s.dive_id
        WHERE 1=1 $diverFilter ${df.clause}
        GROUP BY sp.id
        ORDER BY total_count DESC
        LIMIT ?
        ''', variables: params.map((p) => Variable(p)).toList()).get();

      return results.map((row) {
        return RankingItem(
          id: row.read<String>('id'),
          name: row.read<String>('common_name'),
          count: row.read<int>('total_count'),
          subtitle: row.read<String?>('category'),
        );
      }).toList();
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get most common sightings',
        error: e,
        stackTrace: stackTrace,
      );
      return [];
    }
  }

  /// Get best sites for marine life (most species variety)
  Future<List<RankingItem>> getBestSitesForMarineLife({
    String? diverId,
    int limit = 10,
    DiveFilterState filter = const DiveFilterState(),
  }) async {
    try {
      final diverFilter = diverId != null ? 'AND d.diver_id = ?' : '';
      final df = _diveFilter(filter, alias: 'd');
      final params = diverId != null
          ? [diverId, ...df.params, limit]
          : [...df.params, limit];

      final results = await _db.customSelect('''
        SELECT
          ds.id,
          ds.name,
          COUNT(DISTINCT s.species_id) AS species_count
        FROM dive_sites ds
        JOIN dives d ON d.site_id = ds.id
        JOIN sightings s ON s.dive_id = d.id
        WHERE 1=1 $diverFilter ${df.clause}
        GROUP BY ds.id
        ORDER BY species_count DESC
        LIMIT ?
        ''', variables: params.map((p) => Variable(p)).toList()).get();

      return results.map((row) {
        return RankingItem(
          id: row.read<String>('id'),
          name: row.read<String>('name'),
          count: row.read<int>('species_count'),
        );
      }).toList();
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get best sites for marine life',
        error: e,
        stackTrace: stackTrace,
      );
      return [];
    }
  }

  /// Get detailed statistics for a single species
  Future<SpeciesStatistics> getSpeciesStatistics({
    required String speciesId,
    String? diverId,
    DiveFilterState filter = const DiveFilterState(),
  }) async {
    try {
      final diverFilter = diverId != null ? 'AND d.diver_id = ?' : '';
      final df = _diveFilter(filter, alias: 'd');
      final baseParams = diverId != null
          ? [speciesId, diverId, ...df.params]
          : [speciesId, ...df.params];

      // Aggregate stats: total sightings, dive count, depth range, date range
      final statsResult = await _db.customSelect('''
        SELECT
          COALESCE(SUM(s.count), 0) AS total_sightings,
          COUNT(DISTINCT s.dive_id) AS dive_count,
          MIN(d.max_depth) AS min_depth,
          MAX(d.max_depth) AS max_depth,
          COUNT(DISTINCT d.site_id) AS site_count,
          MIN(d.dive_date_time) AS first_seen,
          MAX(d.dive_date_time) AS last_seen
        FROM sightings s
        JOIN dives d ON d.id = s.dive_id
        WHERE s.species_id = ? $diverFilter ${df.clause}
      ''', variables: baseParams.map((p) => Variable(p)).toList()).getSingle();

      final totalSightings = statsResult.read<int>('total_sightings');

      if (totalSightings == 0) {
        return SpeciesStatistics.empty;
      }

      // Top sites where this species was seen
      final sitesResult = await _db.customSelect('''
        SELECT
          ds.id,
          ds.name,
          SUM(s.count) AS sighting_count
        FROM sightings s
        JOIN dives d ON d.id = s.dive_id
        JOIN dive_sites ds ON ds.id = d.site_id
        WHERE s.species_id = ? $diverFilter ${df.clause}
          AND d.site_id IS NOT NULL
        GROUP BY ds.id
        ORDER BY sighting_count DESC
        LIMIT 5
      ''', variables: baseParams.map((p) => Variable(p)).toList()).get();

      final topSites = sitesResult.map((row) {
        return RankingItem(
          id: row.read<String>('id'),
          name: row.read<String>('name'),
          count: row.read<int>('sighting_count'),
        );
      }).toList();

      final firstSeenMs = statsResult.read<int?>('first_seen');
      final lastSeenMs = statsResult.read<int?>('last_seen');

      return SpeciesStatistics(
        totalSightings: totalSightings,
        diveCount: statsResult.read<int>('dive_count'),
        minDepthMeters: statsResult.read<double?>('min_depth'),
        maxDepthMeters: statsResult.read<double?>('max_depth'),
        siteCount: statsResult.read<int>('site_count'),
        topSites: topSites,
        firstSeen: firstSeenMs != null
            ? DateTime.fromMillisecondsSinceEpoch(firstSeenMs)
            : null,
        lastSeen: lastSeenMs != null
            ? DateTime.fromMillisecondsSinceEpoch(lastSeenMs)
            : null,
      );
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get species statistics',
        error: e,
        stackTrace: stackTrace,
      );
      return SpeciesStatistics.empty;
    }
  }

  // ============================================================================
  // Time Pattern Statistics
  // ============================================================================

  /// Get dives by day of week
  Future<List<({int dayOfWeek, int count})>> getDivesByDayOfWeek({
    String? diverId,
    DiveFilterState filter = const DiveFilterState(),
  }) async {
    try {
      final diverFilter = diverId != null ? 'AND diver_id = ?' : '';
      final df = _diveFilter(filter, alias: 'dives');
      final params = diverId != null ? [diverId, ...df.params] : [...df.params];

      final results = await _db.customSelect('''
        SELECT
          CAST(strftime('%w', dive_date_time / 1000, 'unixepoch') AS INTEGER) AS day_of_week,
          COUNT(*) AS count
        FROM dives
        WHERE 1=1 $diverFilter ${df.clause}
        GROUP BY day_of_week
        ORDER BY day_of_week
        ''', variables: params.map((p) => Variable(p)).toList()).get();

      return results.map((row) {
        return (
          dayOfWeek: row.read<int>('day_of_week'),
          count: row.read<int>('count'),
        );
      }).toList();
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get dives by day of week',
        error: e,
        stackTrace: stackTrace,
      );
      return [];
    }
  }

  /// Get dives by time of day (morning, afternoon, evening, night).
  ///
  /// The bucket names are stable keys, not display text: the same literals
  /// are the ORDER BY sort keys below, so translating them in SQL would
  /// reorder the chart per locale (and break the fixed colour order in the
  /// legend). The presentation layer translates them instead, through
  /// `timeOfDayDistributionLabel`.
  Future<List<DistributionSegment>> getDivesByTimeOfDay({
    String? diverId,
    DiveFilterState filter = const DiveFilterState(),
  }) async {
    try {
      final diverFilter = diverId != null ? 'AND diver_id = ?' : '';
      final df = _diveFilter(filter, alias: 'dives');
      final params = diverId != null ? [diverId, ...df.params] : [...df.params];

      final results = await _db.customSelect('''
        SELECT
          CASE
            WHEN CAST(strftime('%H', COALESCE(entry_time, dive_date_time) / 1000, 'unixepoch') AS INTEGER) < 6 THEN 'Night'
            WHEN CAST(strftime('%H', COALESCE(entry_time, dive_date_time) / 1000, 'unixepoch') AS INTEGER) < 12 THEN 'Morning'
            WHEN CAST(strftime('%H', COALESCE(entry_time, dive_date_time) / 1000, 'unixepoch') AS INTEGER) < 18 THEN 'Afternoon'
            ELSE 'Evening'
          END AS time_of_day,
          COUNT(*) AS count
        FROM dives
        WHERE 1=1 $diverFilter ${df.clause}
        GROUP BY time_of_day
        ORDER BY
          CASE time_of_day
            WHEN 'Morning' THEN 1
            WHEN 'Afternoon' THEN 2
            WHEN 'Evening' THEN 3
            WHEN 'Night' THEN 4
          END
        ''', variables: params.map((p) => Variable(p)).toList()).get();

      final total = results.fold<int>(
        0,
        (sum, row) => sum + row.read<int>('count'),
      );
      if (total == 0) return [];

      return results.map((row) {
        final count = row.read<int>('count');
        return DistributionSegment(
          label: row.read<String>('time_of_day'),
          count: count,
          percentage: count / total * 100,
        );
      }).toList();
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get dives by time of day',
        error: e,
        stackTrace: stackTrace,
      );
      return [];
    }
  }

  /// Get dives by month (seasonal patterns)
  Future<List<({int month, int count})>> getDivesBySeason({
    String? diverId,
    DiveFilterState filter = const DiveFilterState(),
  }) async {
    try {
      final diverFilter = diverId != null ? 'AND diver_id = ?' : '';
      final df = _diveFilter(filter, alias: 'dives');
      final params = diverId != null ? [diverId, ...df.params] : [...df.params];

      final results = await _db.customSelect('''
        SELECT
          CAST(strftime('%m', dive_date_time / 1000, 'unixepoch') AS INTEGER) AS month,
          COUNT(*) AS count
        FROM dives
        WHERE 1=1 $diverFilter ${df.clause}
        GROUP BY month
        ORDER BY month
        ''', variables: params.map((p) => Variable(p)).toList()).get();

      return results.map((row) {
        return (month: row.read<int>('month'), count: row.read<int>('count'));
      }).toList();
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get dives by season',
        error: e,
        stackTrace: stackTrace,
      );
      return [];
    }
  }

  /// Get surface interval statistics
  Future<({double? avgMinutes, double? minMinutes, double? maxMinutes})>
  getSurfaceIntervalStats({
    String? diverId,
    DiveFilterState filter = const DiveFilterState(),
  }) async {
    try {
      final diverFilter = diverId != null ? 'AND d.diver_id = ?' : '';
      final df = _diveFilter(filter, alias: 'd');
      final params = diverId != null ? [diverId, ...df.params] : [...df.params];

      final results = await _db.customSelect('''
        SELECT
          AVG(effective_si / 60.0) AS avg_si,
          MIN(effective_si / 60.0) AS min_si,
          MAX(effective_si / 60.0) AS max_si
        FROM (
          SELECT
            COALESCE(
              d.surface_interval_seconds,
              CASE
                WHEN d.entry_time IS NOT NULL
                THEN (
                  d.entry_time - (
                    SELECT MAX(d2.exit_time)
                    FROM dives d2
                    WHERE d2.diver_id = d.diver_id
                      AND d2.exit_time IS NOT NULL
                      AND d2.exit_time < d.entry_time
                      -- The scope applies to the preceding dive as well: a
                      -- surface interval measured from an excluded dive is
                      -- as wrong as one measured to it. The user filter has
                      -- never reached this inner alias.
                      ${DiveStatsScope.and(alias: 'd2')}
                  )
                ) / 1000.0
                ELSE NULL
              END
            ) AS effective_si
          FROM dives d
          WHERE 1=1 $diverFilter ${df.clause}
        )
        WHERE effective_si IS NOT NULL AND effective_si > 0
        ''', variables: params.map((p) => Variable(p)).toList()).get();

      if (results.isEmpty) {
        return (avgMinutes: null, minMinutes: null, maxMinutes: null);
      }
      return (
        avgMinutes: results.first.read<double?>('avg_si'),
        minMinutes: results.first.read<double?>('min_si'),
        maxMinutes: results.first.read<double?>('max_si'),
      );
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get surface interval stats',
        error: e,
        stackTrace: stackTrace,
      );
      return (avgMinutes: null, minMinutes: null, maxMinutes: null);
    }
  }

  // ============================================================================
  // Equipment Statistics
  // ============================================================================

  /// Get most used gear
  Future<List<RankingItem>> getMostUsedGear({
    String? diverId,
    int limit = 10,
    DiveFilterState filter = const DiveFilterState(),
  }) async {
    try {
      final diverFilter = diverId != null ? 'AND d.diver_id = ?' : '';
      final df = _diveFilter(filter, alias: 'd');
      final params = diverId != null
          ? [diverId, ...df.params, limit]
          : [...df.params, limit];

      final results = await _db.customSelect('''
        SELECT
          e.id,
          e.name,
          e.type,
          e.brand,
          COUNT(de.dive_id) AS use_count
        FROM equipment e
        JOIN dive_equipment de ON de.equipment_id = e.id
        JOIN dives d ON d.id = de.dive_id
        WHERE 1=1 $diverFilter ${df.clause}
        GROUP BY e.id
        ORDER BY use_count DESC
        LIMIT ?
        ''', variables: params.map((p) => Variable(p)).toList()).get();

      return results.map((row) {
        final brand = row.read<String?>('brand');
        final type = row.read<String>('type');
        return RankingItem(
          id: row.read<String>('id'),
          name: row.read<String>('name'),
          count: row.read<int>('use_count'),
          subtitle: brand != null ? '$brand • $type' : type,
        );
      }).toList();
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get most used gear',
        error: e,
        stackTrace: stackTrace,
      );
      return [];
    }
  }

  /// Total lead carried on every dive in scope, in kilograms, ordered by date.
  ///
  /// Sums the dive's weight rows. The monthly version this replaced averaged
  /// across rows, so a 4 kg belt plus 2 kg of trim weights was reported as
  /// 3 kg rather than the 6 kg actually carried.
  Future<List<TrendDataPoint>> getWeightPerDive({
    String? diverId,
    DiveFilterState filter = const DiveFilterState(),
  }) async {
    try {
      final diverFilter = diverId != null ? 'AND d.diver_id = ?' : '';
      final df = _diveFilter(filter, alias: 'd');
      final params = diverId != null ? [diverId, ...df.params] : [...df.params];

      final results = await _db.customSelect('''
        SELECT d.id AS dive_id,
               d.dive_date_time AS dive_date_time,
               SUM(dw.amount_kg) AS total_kg
        FROM dives d
        JOIN dive_weights dw ON dw.dive_id = d.id
        WHERE 1 = 1 $diverFilter ${df.clause}
        GROUP BY d.id
        HAVING total_kg IS NOT NULL
        ORDER BY d.dive_date_time
        ''', variables: params.map((p) => Variable(p)).toList()).get();

      return results.map((row) {
        return TrendDataPoint(
          date: DateTime.fromMillisecondsSinceEpoch(
            row.read<int>('dive_date_time'),
            isUtc: true,
          ),
          value: row.read<double>('total_kg'),
          diveId: row.read<String>('dive_id'),
        );
      }).toList();
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get per-dive weight',
        error: e,
        stackTrace: stackTrace,
      );
      return [];
    }
  }

  /// Water temperature of every dive in scope, in Celsius, ordered by date.
  ///
  /// Distinct from [getTemperatureByMonth], which collapses all years into
  /// twelve calendar buckets to show a season. This one is a time series.
  Future<List<TrendDataPoint>> getWaterTempPerDive({
    String? diverId,
    DiveFilterState filter = const DiveFilterState(),
  }) async {
    try {
      final diverFilter = diverId != null ? 'AND diver_id = ?' : '';
      final df = _diveFilter(filter, alias: 'dives');
      final params = diverId != null ? [diverId, ...df.params] : [...df.params];

      final results = await _db.customSelect('''
        SELECT id, dive_date_time, water_temp
        FROM dives
        WHERE water_temp IS NOT NULL $diverFilter ${df.clause}
        ORDER BY dive_date_time
        ''', variables: params.map((p) => Variable(p)).toList()).get();

      return results.map((row) {
        return TrendDataPoint(
          date: DateTime.fromMillisecondsSinceEpoch(
            row.read<int>('dive_date_time'),
            isUtc: true,
          ),
          value: row.read<double>('water_temp'),
          diveId: row.read<String>('id'),
        );
      }).toList();
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get per-dive water temperature',
        error: e,
        stackTrace: stackTrace,
      );
      return [];
    }
  }

  // ============================================================================
  // Profile Analysis Statistics
  // ============================================================================

  /// Get average ascent/descent rates in m/min, or null when the filtered
  /// dives hold no vertical movement to average.
  ///
  /// Rates are derived from the stored depth samples rather than read from a
  /// stored rate column. The retired `dive_profiles.ascent_rate` was never
  /// populated by any download or import path (libdivecomputer reports no
  /// ascent-rate sample type), so it was null for every row and averaging it
  /// always yielded an empty section.
  ///
  /// The aggregation runs in Dart, on a worker isolate, over decoded primary
  /// series (see [ascentDescentRates] and [ascentDescentRatesFromBlobs]),
  /// with the same windows and thresholds a SQL query over `dive_profiles`
  /// used before the packed-series migration. The derivation follows the same
  /// conventions as [AscentRateCalculator], which computes rates per-dive for
  /// the profile chart, but smooths by a different (cheaper, set-based)
  /// filter (see [rateWindowSeconds]):
  ///
  /// - Samples are averaged into fixed [rateWindowSeconds] buckets, which
  ///   makes the result independent of the computer's sample interval and keeps
  ///   depth-resolution noise from dominating (0.1 m between two 1 s samples is
  ///   already 6 m/min of pure quantisation noise).
  /// - The rate between two buckets uses their mean sample times, not the
  ///   bucket width, so uneven occupancy at the edges cannot distort the
  ///   interval.
  /// - Positive is ascending, matching [AscentRatePoint.rateMetersPerMin].
  /// - Buckets slower than [sustainedTransitThreshold] are excluded, so
  ///   working a multi-level profile does not read as ascending or descending.
  ///
  /// Only primary profile rows are considered, so a dive logged by two
  /// computers — or one whose original profile was demoted by an edit — is
  /// counted once rather than interleaving two sample streams.
  Future<({double? avgAscent, double? avgDescent})> getAscentDescentRates({
    String? diverId,
    DiveFilterState filter = const DiveFilterState(),
  }) async {
    try {
      final diverFilter = diverId != null ? 'AND d.diver_id = ?' : '';
      final df = _diveFilter(filter, alias: 'd');
      final params = diverId != null ? [diverId, ...df.params] : [...df.params];
      final scoped = await _db
          .customSelect(
            // Only dives that actually have a primary series: without this
            // the chunk loop pages over every filtered dive, most of which
            // return no blob at all on a library where profiles are the
            // exception rather than the rule.
            'SELECT d.id AS id FROM dives d WHERE 1=1 $diverFilter '
            '${df.clause} AND EXISTS (SELECT 1 FROM dive_profile_series s '
            'WHERE s.dive_id = d.id AND s.is_primary = 1)',
            variables: params.map((p) => Variable(p)).toList(),
            readsFrom: {_db.dives, _db.diveProfileSeries},
          )
          .get();
      final diveIds = [for (final r in scoped) r.read<String>('id')];
      if (diveIds.isEmpty) return (avgAscent: null, avgDescent: null);
      var totals = emptyRateTotals;
      for (final chunk in _diveChunks(diveIds)) {
        final blobs = await _primaryBlobs(chunk);
        if (blobs.isEmpty) continue;
        totals = combineRateTotals(
          totals,
          await compute(ascentDescentTotalsFromBlobs, blobs),
        );
      }
      return ratesFromTotals(totals);
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get ascent/descent rates',
        error: e,
        stackTrace: stackTrace,
      );
      return (avgAscent: null, avgDescent: null);
    }
  }

  /// Get time spent in depth ranges.
  ///
  /// Returns numeric bucket edges in meters (the canonical depth unit). The
  /// display layer converts to the user's preferred depth unit so the chart's
  /// axis label and bucket labels match the setting. The top bucket is
  /// open-ended ([upperDepth] is null).
  ///
  /// The aggregation runs in Dart, on a worker isolate, over decoded primary
  /// series (see [timeAtDepthRanges] and [timeAtDepthRangesFromBlobs]), with
  /// the same windows and thresholds a SQL query over `dive_profiles` used
  /// before the packed-series migration.
  ///
  /// Minutes come from the sample timestamps, not from a row count: the
  /// interval between one sample and the next is credited to the bucket the
  /// earlier sample sits in. Counting rows and calling each one a second, as
  /// this aggregation used to, is only right for a computer sampling at 1 Hz:
  /// for the many that record every 2, 4, 5, 10 or 20 seconds it divides every
  /// bucket by that interval. Differencing timestamps needs no
  /// assumption about the recording rate at all, and it makes duplicate
  /// samples from a repeated import harmless: the repeat adds a zero-length
  /// interval rather than a second helping of time.
  ///
  /// Each dive's intervals are capped at [maxSampleGapFactor] times that
  /// profile's own mean interval so a recording pause is not banked as bottom
  /// time. A profile's total therefore spans its first sample to its last: the
  /// last sample opens no interval, and whatever time the diver spent after it
  /// was never recorded and cannot be recovered here.
  ///
  /// Samples are ordered by `(timestamp, stored order)` rather than timestamp
  /// alone. Ties cannot lose time whichever way they fall, because every
  /// sample but the last of a tied group yields a zero-length interval and
  /// the last carries the whole step to the next timestamp. If tied samples
  /// sit in different buckets, though, the tie order decides which bucket
  /// that step lands in.
  ///
  /// Only primary profile rows are counted, matching [getAscentDescentRates]:
  /// a dive logged by two computers, or one whose original profile was demoted
  /// by an edit, otherwise contributes both sample streams and roughly doubles
  /// every bucket. Note that a dive left with no primary rows at all is
  /// skipped entirely -- see issue #1149, which tracks the promotion bug that
  /// can produce that state.
  Future<List<({int lowerDepth, int? upperDepth, int minutes})>>
  getTimeAtDepthRanges({
    String? diverId,
    DiveFilterState filter = const DiveFilterState(),
  }) async {
    try {
      final diverFilter = diverId != null ? 'AND d.diver_id = ?' : '';
      final df = _diveFilter(filter, alias: 'd');
      final params = diverId != null ? [diverId, ...df.params] : [...df.params];
      final scoped = await _db
          .customSelect(
            // Only dives that actually have a primary series: without this
            // the chunk loop pages over every filtered dive, most of which
            // return no blob at all on a library where profiles are the
            // exception rather than the rule.
            'SELECT d.id AS id FROM dives d WHERE 1=1 $diverFilter '
            '${df.clause} AND EXISTS (SELECT 1 FROM dive_profile_series s '
            'WHERE s.dive_id = d.id AND s.is_primary = 1)',
            variables: params.map((p) => Variable(p)).toList(),
            readsFrom: {_db.dives, _db.diveProfileSeries},
          )
          .get();
      final diveIds = [for (final r in scoped) r.read<String>('id')];
      if (diveIds.isEmpty) return [];
      var seconds = <int, double>{};
      for (final chunk in _diveChunks(diveIds)) {
        final blobs = await _primaryBlobs(chunk);
        if (blobs.isEmpty) continue;
        seconds = combineDepthSeconds(
          seconds,
          await compute(timeAtDepthSecondsFromBlobs, blobs),
        );
      }
      return bucketsFromSeconds(seconds);
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get time at depth ranges',
        error: e,
        stackTrace: stackTrace,
      );
      return [];
    }
  }

  /// Classifies each filtered dive's decompression obligation from recorded
  /// profile data alone.
  ///
  /// Resolution order, highest confidence first:
  ///
  /// 1. `deco_type = 2` (DC_DECO_DECOSTOP per libdc_wrapper.h) or a
  ///    `decoStopStart` profile event means deco. Types 1 and 3 are safety
  ///    and deep stops, which are not decompression obligations; the old
  ///    `ceiling > 0` test counted both, because both profile mappers write
  ///    `ceiling = decoDepth` for any non-zero deco type.
  /// 2. A profile that carries `deco_type` values, none of which is 2, means
  ///    no deco. The computer was recording obligations and reported none.
  /// 3. `ceiling > 0` on a profile with no `deco_type` at all means deco.
  ///    Subsurface XML, DAN DL7 and FIT write a stop depth without a type,
  ///    so this clause keeps them working without re-admitting safety stops.
  /// 4. Anything else with a profile needs the computed fallback: many
  ///    sources (MacDive, Shearwater Cloud, generic UDDF, CSV, OCR) record no
  ///    deco columns at all, and for those the app's own analysis is the only
  ///    evidence there is. It is also what the dive detail page displays.
  /// 5. A dive with no profile is unclassifiable and must not be counted as
  ///    no-deco.
  Future<DecoSignalScan> scanRecordedDecoSignals({
    String? diverId,
    DiveFilterState filter = const DiveFilterState(),
  }) async {
    try {
      final diverFilter = diverId != null ? 'AND d.diver_id = ?' : '';
      final df = _diveFilter(filter, alias: 'd');
      final params = diverId != null ? [diverId, ...df.params] : [...df.params];

      final results = await _db.customSelect('''
        WITH scoped AS (
          SELECT d.id AS dive_id
          FROM dives d
          WHERE 1=1 $diverFilter ${df.clause}
        ),
        signals AS (
          SELECT
            s.dive_id AS dive_id,
            MAX(CASE WHEN ps.id IS NOT NULL THEN 1 ELSE 0 END) AS has_profile,
            MAX(CASE WHEN ps.has_deco_type = 1 THEN 1 ELSE 0 END)
              AS has_deco_type,
            MAX(CASE WHEN ps.has_deco_stop = 1 THEN 1 ELSE 0 END) AS deco_stop,
            MAX(CASE WHEN ps.has_positive_ceiling = 1 THEN 1 ELSE 0 END)
              AS positive_ceiling
          FROM scoped s
          LEFT JOIN dive_profile_series ps ON ps.dive_id = s.dive_id
          GROUP BY s.dive_id
        ),
        stop_events AS (
          SELECT DISTINCT e.dive_id AS dive_id
          FROM dive_profile_events e
          JOIN scoped s ON s.dive_id = e.dive_id
          WHERE e.event_type = 'decoStopStart'
        )
        SELECT
          sig.dive_id AS dive_id,
          d.updated_at AS updated_at,
          CASE
            WHEN sig.deco_stop = 1 OR ev.dive_id IS NOT NULL THEN 'deco'
            WHEN sig.has_deco_type = 1 THEN 'no_deco'
            WHEN sig.positive_ceiling = 1 THEN 'deco'
            WHEN sig.has_profile = 1 THEN 'compute'
            ELSE 'no_profile'
          END AS classification
        FROM signals sig
        JOIN dives d ON d.id = sig.dive_id
        LEFT JOIN stop_events ev ON ev.dive_id = sig.dive_id
        ''', variables: params.map((p) => Variable(p)).toList()).get();

      final recordedDeco = <String>{};
      final recordedNoDeco = <String>{};
      final needsCompute = <String, int>{};
      final noProfile = <String>{};
      for (final row in results) {
        final id = row.read<String>('dive_id');
        switch (row.read<String>('classification')) {
          case 'deco':
            recordedDeco.add(id);
          case 'no_deco':
            recordedNoDeco.add(id);
          case 'compute':
            // Non-null read on purpose. `dives.updated_at` is a non-nullable
            // column and the query inner-joins dives, so a null here means the
            // schema or the query drifted. Defaulting to 0 would silently
            // collapse every dive onto one fingerprint component and stop
            // edits invalidating the computed classification cache, so fail
            // loudly instead.
            needsCompute[id] = row.read<int>('updated_at');
          default:
            noProfile.add(id);
        }
      }
      return (
        recordedDeco: recordedDeco,
        recordedNoDeco: recordedNoDeco,
        needsCompute: needsCompute,
        noProfile: noProfile,
      );
    } catch (e, stackTrace) {
      _log.error(
        'Failed to scan recorded deco signals',
        error: e,
        stackTrace: stackTrace,
      );
      return (
        recordedDeco: const <String>{},
        recordedNoDeco: const <String>{},
        needsCompute: const <String, int>{},
        noProfile: const <String>{},
      );
    }
  }

  /// Deco obligation counts from recorded data alone.
  ///
  /// Dives needing the computed fallback are reported as unknown here. The
  /// statistics provider composes this with the computed classification
  /// cache; this method is the recorded-only view, used by tests and by any
  /// caller that must not trigger analysis work.
  Future<({int decoCount, int noDecoCount, int unknownCount})>
  getDecoObligationStats({
    String? diverId,
    DiveFilterState filter = const DiveFilterState(),
  }) async {
    final scan = await scanRecordedDecoSignals(
      diverId: diverId,
      filter: filter,
    );
    return (
      decoCount: scan.recordedDeco.length,
      noDecoCount: scan.recordedNoDeco.length,
      unknownCount: scan.needsCompute.length + scan.noProfile.length,
    );
  }

  /// Aggregates of one diver's history at a site, matched by exact
  /// case-insensitive name (itinerary days have no site FK, so planned-day
  /// context pills resolve the site by its port name).
  Future<({int diveCount, double? avgWaterTemp, double? avgMaxDepth})>
  getSiteHistoryByName(String siteName, {required String diverId}) async {
    final row = await _db
        .customSelect(
          '''
      SELECT COUNT(d.id) AS dive_count,
             AVG(d.water_temp) AS avg_water_temp,
             AVG(d.max_depth) AS avg_max_depth
      FROM dives d
      JOIN dive_sites ds ON d.site_id = ds.id
      WHERE LOWER(ds.name) = LOWER(?) AND d.diver_id = ?
            ${DiveStatsScope.and(alias: 'd')}
    ''',
          variables: [
            Variable.withString(siteName),
            Variable.withString(diverId),
          ],
        )
        .getSingle();

    return (
      diveCount: row.read<int>('dive_count'),
      avgWaterTemp: row.read<double?>('avg_water_temp'),
      avgMaxDepth: row.read<double?>('avg_max_depth'),
    );
  }

  /// Counts the dives the diver has explicitly excluded from statistics, for
  /// the Overview footnote.
  ///
  /// Deliberately counts only `excluded_from_stats`, not the whole
  /// [DiveStatsScope]: this footnote exists to explain the diver's own choice
  /// back to them. A planned dive is not something they chose to exclude, so
  /// folding it in would make the number confusing rather than clarifying.
  // stats-scope-exempt: counts the excluded, by definition
  Future<int> countExcludedDives({String? diverId}) async {
    final diverFilter = diverId != null ? 'AND diver_id = ?' : '';
    final row = await _db
        .customSelect(
          'SELECT COUNT(*) AS c FROM dives '
          'WHERE excluded_from_stats = 1 $diverFilter',
          variables: diverId != null
              ? [Variable<String>(diverId)]
              : const <Variable<Object>>[],
          readsFrom: {_db.dives},
        )
        .getSingle();
    return row.read<int>('c');
  }

  // ============================================================================
  // Helpers
  // ============================================================================
}

/// Aggregates for one calendar year (dashboard year-in-review card).
class YearStats {
  final int diveCount;
  final int totalSeconds;
  final double? maxDepth;

  const YearStats({
    required this.diveCount,
    required this.totalSeconds,
    this.maxDepth,
  });
}
