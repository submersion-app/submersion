import 'package:drift/drift.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/utils/gas_compressibility.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';
import 'package:submersion/features/statistics/data/dive_filter_sql.dart';
import 'package:submersion/features/statistics/domain/entities/species_statistics.dart';

/// Data point for line chart trends
class TrendDataPoint {
  final DateTime date;
  final double value;
  final String label;

  TrendDataPoint({
    required this.date,
    required this.value,
    required this.label,
  });
}

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

  DistributionSegment({
    required this.label,
    required this.count,
    required this.percentage,
  });
}

/// Repository for all advanced statistics queries
class StatisticsRepository {
  AppDatabase get _db => DatabaseService.instance.database;
  final _log = LoggerService.forClass(StatisticsRepository);

  /// Builds the `AND <alias>.id IN (<subquery>)` fragment + raw params for a
  /// stats filter. Empty (no-op) when the filter has no active axes.
  ({String clause, List<Object?> params}) _diveFilter(
    DiveFilterState filter, {
    String alias = 'dives',
  }) {
    final f = buildFilteredDiveIdSubquery(filter);
    if (f.subquery.isEmpty) return (clause: '', params: const <Object?>[]);
    return (clause: 'AND $alias.id IN (${f.subquery})', params: f.params);
  }

  // ============================================================================
  // Gas Statistics
  // ============================================================================

  /// Get SAC rate trend by month in L/min (last 5 years)
  /// Requires tank volume data
  Future<List<TrendDataPoint>> getSacVolumeTrend({
    String? diverId,
    DiveFilterState filter = const DiveFilterState(),
  }) async {
    try {
      final fiveYearsAgo = DateTime.now().subtract(
        const Duration(days: 365 * 5),
      );
      final cutoff = fiveYearsAgo.millisecondsSinceEpoch;

      final diverFilter = diverId != null ? 'AND d.diver_id = ?' : '';
      final df = _diveFilter(filter, alias: 'd');
      final params = diverId != null
          ? [cutoff, diverId, ...df.params]
          : [cutoff, ...df.params];

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
        WHERE d.dive_date_time >= ? $diverFilter ${df.clause}
          AND COALESCE(d.runtime, d.bottom_time) > 0
          AND d.avg_depth > 0
          AND t.start_pressure > t.end_pressure
          AND t.volume > 0
        ORDER BY d.dive_date_time
        ''', variables: params.map((p) => Variable(p)).toList()).get();

      // Group by dive, compute SAC per dive, then average by month
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
            ) -
            gasVolume(
              tankSizeLiters: vol,
              pressureBar: endP,
              o2Percent: o2,
              hePercent: he,
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

      // Compute SAC per dive and group by month
      final Map<String, List<double>> monthSacs = {};
      for (final entry in diveSacs.entries) {
        final d = entry.value;
        final sac =
            d.gas / (d.durationSec / 60.0) / ((d.avgDepth / 10.0) + 1.0);
        if (sac <= 0) continue;

        final dt = d.dateTime;
        final key = '${dt.year}-${dt.month.toString().padLeft(2, '0')}';
        monthSacs.putIfAbsent(key, () => []).add(sac);
      }

      // Average per month
      final trend = <TrendDataPoint>[];
      for (final entry in monthSacs.entries) {
        final parts = entry.key.split('-');
        final year = int.parse(parts[0]);
        final month = int.parse(parts[1]);
        final avg = entry.value.reduce((a, b) => a + b) / entry.value.length;
        trend.add(
          TrendDataPoint(
            date: DateTime(year, month),
            value: avg,
            label: '${_monthAbbr(month)} $year',
          ),
        );
      }
      trend.sort((a, b) => a.date.compareTo(b.date));
      return trend;
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get SAC volume trend',
        error: e,
        stackTrace: stackTrace,
      );
      return [];
    }
  }

  /// Get SAC rate trend by month in pressure/min (last 5 years)
  /// Does not require tank volume - uses pressure drop normalized to surface
  Future<List<TrendDataPoint>> getSacPressureTrend({
    String? diverId,
    DiveFilterState filter = const DiveFilterState(),
  }) async {
    try {
      final fiveYearsAgo = DateTime.now().subtract(
        const Duration(days: 365 * 5),
      );
      final cutoff = fiveYearsAgo.millisecondsSinceEpoch;

      final diverFilter = diverId != null ? 'AND d.diver_id = ?' : '';
      final df = _diveFilter(filter, alias: 'd');
      final params = diverId != null
          ? [cutoff, diverId, ...df.params]
          : [cutoff, ...df.params];

      final results = await _db.customSelect('''
        SELECT
          strftime('%Y', d.dive_date_time / 1000, 'unixepoch') AS year,
          strftime('%m', d.dive_date_time / 1000, 'unixepoch') AS month,
          AVG(
            (t.start_pressure - t.end_pressure) / (COALESCE(d.runtime, d.bottom_time) / 60.0) / ((d.avg_depth / 10.0) + 1)
          ) AS avg_sac
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
        WHERE d.dive_date_time >= ? $diverFilter ${df.clause}
          AND COALESCE(d.runtime, d.bottom_time) > 0
          AND d.avg_depth > 0
        GROUP BY year, month
        HAVING avg_sac IS NOT NULL
        ORDER BY year, month
        ''', variables: params.map((p) => Variable(p)).toList()).get();

      return results.map((row) {
        final year = int.parse(row.read<String>('year'));
        final month = int.parse(row.read<String>('month'));
        return TrendDataPoint(
          date: DateTime(year, month),
          value: row.read<double>('avg_sac'),
          label: '${_monthAbbr(month)} $year',
        );
      }).toList();
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get SAC pressure trend',
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
      final df = _diveFilter(filter, alias: 'd');
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
      final df = _diveFilter(filter, alias: 'd');
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
            ) -
            gasVolume(
              tankSizeLiters: vol,
              pressureBar: row.read<double>('end_pressure'),
              o2Percent: o2,
              hePercent: he,
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
      final df = _diveFilter(filter, alias: 'd');
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
      final df = _diveFilter(filter, alias: 'd');
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
            ) -
            gasVolume(
              tankSizeLiters: vol,
              pressureBar: row.read<double>('end_pressure'),
              o2Percent: o2,
              hePercent: he,
            );
        if (used <= 0) continue;

        final durationMin = row.read<int>('duration_sec') / 60.0;
        final ambientAtm = (row.read<double>('avg_depth') / 10.0) + 1.0;
        final sac = used / durationMin / ambientAtm;
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
      final df = _diveFilter(filter, alias: 'd');
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

  /// Get dive type distribution (recreational, night, deep, wreck, etc.)
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
          COUNT(*) AS count
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
        final rawType = row.read<String>('dive_type');
        // Capitalize first letter for display
        final label = rawType.isNotEmpty
            ? '${rawType[0].toUpperCase()}${rawType.substring(1)}'
            : 'Unknown';
        return DistributionSegment(
          label: label,
          count: count,
          percentage: count / total * 100,
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

  /// Get maximum depth progression by month (last 5 years)
  Future<List<TrendDataPoint>> getDepthProgressionTrend({
    String? diverId,
    DiveFilterState filter = const DiveFilterState(),
  }) async {
    try {
      final fiveYearsAgo = DateTime.now().subtract(
        const Duration(days: 365 * 5),
      );
      final cutoff = fiveYearsAgo.millisecondsSinceEpoch;

      final diverFilter = diverId != null ? 'AND diver_id = ?' : '';
      final df = _diveFilter(filter, alias: 'dives');
      final params = diverId != null
          ? [cutoff, diverId, ...df.params]
          : [cutoff, ...df.params];

      final results = await _db.customSelect('''
        SELECT
          strftime('%Y', dive_date_time / 1000, 'unixepoch') AS year,
          strftime('%m', dive_date_time / 1000, 'unixepoch') AS month,
          MAX(max_depth) AS max_depth
        FROM dives
        WHERE dive_date_time >= ? AND max_depth IS NOT NULL $diverFilter ${df.clause}
        GROUP BY year, month
        ORDER BY year, month
        ''', variables: params.map((p) => Variable(p)).toList()).get();

      return results.map((row) {
        final year = int.parse(row.read<String>('year'));
        final month = int.parse(row.read<String>('month'));
        return TrendDataPoint(
          date: DateTime(year, month),
          value: row.read<double>('max_depth'),
          label: '${_monthAbbr(month)} $year',
        );
      }).toList();
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get depth progression trend',
        error: e,
        stackTrace: stackTrace,
      );
      return [];
    }
  }

  /// Get average bottom time trend by month (last 5 years)
  Future<List<TrendDataPoint>> getBottomTimeTrend({
    String? diverId,
    DiveFilterState filter = const DiveFilterState(),
  }) async {
    try {
      final fiveYearsAgo = DateTime.now().subtract(
        const Duration(days: 365 * 5),
      );
      final cutoff = fiveYearsAgo.millisecondsSinceEpoch;

      final diverFilter = diverId != null ? 'AND diver_id = ?' : '';
      final df = _diveFilter(filter, alias: 'dives');
      final params = diverId != null
          ? [cutoff, diverId, ...df.params]
          : [cutoff, ...df.params];

      final results = await _db.customSelect('''
        SELECT
          strftime('%Y', dive_date_time / 1000, 'unixepoch') AS year,
          strftime('%m', dive_date_time / 1000, 'unixepoch') AS month,
          AVG(bottom_time / 60.0) AS avg_duration
        FROM dives
        WHERE dive_date_time >= ? AND bottom_time IS NOT NULL $diverFilter ${df.clause}
        GROUP BY year, month
        ORDER BY year, month
        ''', variables: params.map((p) => Variable(p)).toList()).get();

      return results.map((row) {
        final year = int.parse(row.read<String>('year'));
        final month = int.parse(row.read<String>('month'));
        return TrendDataPoint(
          date: DateTime(year, month),
          value: row.read<double>('avg_duration'),
          label: '${_monthAbbr(month)} $year',
        );
      }).toList();
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get bottom time trend',
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

  /// Get cumulative dive count over time
  Future<List<TrendDataPoint>> getCumulativeDiveCount({
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
          strftime('%m', dive_date_time / 1000, 'unixepoch') AS month,
          COUNT(*) AS count
        FROM dives
        WHERE 1=1 $diverFilter ${df.clause}
        GROUP BY year, month
        ORDER BY year, month
        ''', variables: params.map((p) => Variable(p)).toList()).get();

      int runningTotal = 0;
      return results.map((row) {
        final year = int.parse(row.read<String>('year'));
        final month = int.parse(row.read<String>('month'));
        runningTotal += row.read<int>('count');
        return TrendDataPoint(
          date: DateTime(year, month),
          value: runningTotal.toDouble(),
          label: '${_monthAbbr(month)} $year',
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

  /// Get visibility distribution
  Future<List<DistributionSegment>> getVisibilityDistribution({
    String? diverId,
    DiveFilterState filter = const DiveFilterState(),
  }) async {
    try {
      final diverFilter = diverId != null ? 'AND diver_id = ?' : '';
      final df = _diveFilter(filter, alias: 'dives');
      final params = diverId != null ? [diverId, ...df.params] : [...df.params];

      final results = await _db.customSelect('''
        SELECT
          visibility,
          COUNT(*) AS count
        FROM dives
        WHERE visibility IS NOT NULL AND visibility != '' $diverFilter ${df.clause}
        GROUP BY visibility
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
          label: row.read<String>('visibility'),
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

  /// Get water type distribution (salt/fresh)
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
          COALESCE(water_type, 'Unknown') AS water_type,
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

  /// Get entry method distribution
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

  /// Get dives by time of day (morning, afternoon, evening, night)
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

  /// Get weight trend by month
  Future<List<TrendDataPoint>> getWeightTrend({
    String? diverId,
    DiveFilterState filter = const DiveFilterState(),
  }) async {
    try {
      final fiveYearsAgo = DateTime.now().subtract(
        const Duration(days: 365 * 5),
      );
      final cutoff = fiveYearsAgo.millisecondsSinceEpoch;

      final diverFilter = diverId != null ? 'AND d.diver_id = ?' : '';
      final df = _diveFilter(filter, alias: 'd');
      final params = diverId != null
          ? [cutoff, diverId, ...df.params]
          : [cutoff, ...df.params];

      final results = await _db.customSelect('''
        SELECT
          strftime('%Y', d.dive_date_time / 1000, 'unixepoch') AS year,
          strftime('%m', d.dive_date_time / 1000, 'unixepoch') AS month,
          AVG(dw.amount_kg) AS avg_weight
        FROM dives d
        JOIN dive_weights dw ON dw.dive_id = d.id
        WHERE d.dive_date_time >= ? $diverFilter ${df.clause}
        GROUP BY year, month
        ORDER BY year, month
        ''', variables: params.map((p) => Variable(p)).toList()).get();

      return results.map((row) {
        final year = int.parse(row.read<String>('year'));
        final month = int.parse(row.read<String>('month'));
        return TrendDataPoint(
          date: DateTime(year, month),
          value: row.read<double>('avg_weight'),
          label: '${_monthAbbr(month)} $year',
        );
      }).toList();
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get weight trend',
        error: e,
        stackTrace: stackTrace,
      );
      return [];
    }
  }

  // ============================================================================
  // Profile Analysis Statistics
  // ============================================================================

  /// Get average ascent/descent rates
  Future<({double? avgAscent, double? avgDescent})> getAscentDescentRates({
    String? diverId,
    DiveFilterState filter = const DiveFilterState(),
  }) async {
    try {
      final diverFilter = diverId != null ? 'AND d.diver_id = ?' : '';
      final df = _diveFilter(filter, alias: 'd');
      final params = diverId != null ? [diverId, ...df.params] : [...df.params];

      final results = await _db.customSelect('''
        SELECT
          AVG(CASE WHEN p.ascent_rate < 0 THEN ABS(p.ascent_rate) ELSE NULL END) AS avg_ascent,
          AVG(CASE WHEN p.ascent_rate > 0 THEN p.ascent_rate ELSE NULL END) AS avg_descent
        FROM dive_profiles p
        JOIN dives d ON d.id = p.dive_id
        WHERE p.ascent_rate IS NOT NULL $diverFilter ${df.clause}
        ''', variables: params.map((p) => Variable(p)).toList()).get();

      if (results.isEmpty) return (avgAscent: null, avgDescent: null);
      return (
        avgAscent: results.first.read<double?>('avg_ascent'),
        avgDescent: results.first.read<double?>('avg_descent'),
      );
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
  Future<List<({int lowerDepth, int? upperDepth, int minutes})>>
  getTimeAtDepthRanges({
    String? diverId,
    DiveFilterState filter = const DiveFilterState(),
  }) async {
    try {
      final diverFilter = diverId != null ? 'AND d.diver_id = ?' : '';
      final df = _diveFilter(filter, alias: 'd');
      final params = diverId != null ? [diverId, ...df.params] : [...df.params];

      final results = await _db.customSelect('''
        SELECT
          CASE
            WHEN p.depth < 10 THEN 0
            WHEN p.depth < 20 THEN 10
            WHEN p.depth < 30 THEN 20
            WHEN p.depth < 40 THEN 30
            ELSE 40
          END AS bucket_lo,
          COUNT(*) AS sample_count
        FROM dive_profiles p
        JOIN dives d ON d.id = p.dive_id
        WHERE 1=1 $diverFilter ${df.clause}
        GROUP BY bucket_lo
        ORDER BY bucket_lo
        ''', variables: params.map((p) => Variable(p)).toList()).get();

      // Sample count approximates minutes (profiles are usually sampled every
      // second or few seconds) — a rough estimate matching the original
      // implementation.
      return results.map((row) {
        final lo = row.read<int>('bucket_lo');
        return (
          lowerDepth: lo,
          upperDepth: lo >= 40 ? null : lo + 10,
          minutes: (row.read<int>('sample_count') / 60).round(),
        );
      }).toList();
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get time at depth ranges',
        error: e,
        stackTrace: stackTrace,
      );
      return [];
    }
  }

  /// Get percentage of dives with decompression obligation
  Future<({int decoCount, int totalCount})> getDecoObligationStats({
    String? diverId,
    DiveFilterState filter = const DiveFilterState(),
  }) async {
    try {
      final diverFilter = diverId != null ? 'AND d.diver_id = ?' : '';
      final df = _diveFilter(filter, alias: 'd');
      final params = diverId != null ? [diverId, ...df.params] : [...df.params];

      final results = await _db.customSelect('''
        SELECT
          COUNT(DISTINCT CASE WHEN p.ceiling > 0 THEN d.id END) AS deco_count,
          COUNT(DISTINCT d.id) AS total_count
        FROM dives d
        LEFT JOIN dive_profiles p ON p.dive_id = d.id
        WHERE 1=1 $diverFilter ${df.clause}
        ''', variables: params.map((p) => Variable(p)).toList()).get();

      if (results.isEmpty) return (decoCount: 0, totalCount: 0);
      return (
        decoCount: results.first.read<int?>('deco_count') ?? 0,
        totalCount: results.first.read<int?>('total_count') ?? 0,
      );
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get deco obligation stats',
        error: e,
        stackTrace: stackTrace,
      );
      return (decoCount: 0, totalCount: 0);
    }
  }

  // ============================================================================
  // Helpers
  // ============================================================================

  String _monthAbbr(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return months[month - 1];
  }
}
