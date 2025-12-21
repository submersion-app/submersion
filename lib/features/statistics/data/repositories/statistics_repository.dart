import 'package:drift/drift.dart';

import '../../../../core/database/database.dart';
import '../../../../core/services/database_service.dart';
import '../../../../core/services/logger_service.dart';

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

  RankingItem({
    required this.id,
    required this.name,
    required this.count,
    this.value,
    this.subtitle,
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
  final AppDatabase _db = DatabaseService.instance.database;
  final _log = LoggerService.forClass(StatisticsRepository);

  // ============================================================================
  // Gas Statistics
  // ============================================================================

  /// Get SAC rate trend by month (last 5 years)
  Future<List<TrendDataPoint>> getSacTrend({String? diverId}) async {
    try {
      final fiveYearsAgo = DateTime.now().subtract(const Duration(days: 365 * 5));
      final cutoff = fiveYearsAgo.millisecondsSinceEpoch;

      final diverFilter = diverId != null ? 'AND d.diver_id = ?' : '';
      final params = diverId != null ? [cutoff, diverId] : [cutoff];

      final results = await _db.customSelect(
        '''
        SELECT
          strftime('%Y', d.dive_date_time / 1000, 'unixepoch') AS year,
          strftime('%m', d.dive_date_time / 1000, 'unixepoch') AS month,
          AVG(
            CASE
              WHEN d.duration > 0 AND d.avg_depth > 0 AND t.start_pressure > t.end_pressure AND t.volume > 0 THEN
                ((t.start_pressure - t.end_pressure) * t.volume) / (d.duration / 60.0) / ((d.avg_depth / 10.0) + 1)
              ELSE NULL
            END
          ) AS avg_sac
        FROM dives d
        LEFT JOIN dive_tanks t ON t.dive_id = d.id
        WHERE d.dive_date_time >= ? $diverFilter
        GROUP BY year, month
        HAVING avg_sac IS NOT NULL
        ORDER BY year, month
        ''',
        variables: params.map((p) => Variable(p)).toList(),
      ).get();

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
      _log.error('Failed to get SAC trend', e, stackTrace);
      return [];
    }
  }

  /// Get gas mix distribution (Air, Nitrox, Trimix)
  Future<List<DistributionSegment>> getGasMixDistribution({String? diverId}) async {
    try {
      final diverFilter = diverId != null ? 'AND d.diver_id = ?' : '';
      final params = diverId != null ? [diverId] : <dynamic>[];

      final results = await _db.customSelect(
        '''
        SELECT
          CASE
            WHEN t.he_percent > 0 THEN 'Trimix'
            WHEN t.o2_percent > 21.5 THEN 'Nitrox'
            ELSE 'Air'
          END AS gas_type,
          COUNT(DISTINCT d.id) AS dive_count
        FROM dives d
        JOIN dive_tanks t ON t.dive_id = d.id
        WHERE 1=1 $diverFilter
        GROUP BY gas_type
        ORDER BY dive_count DESC
        ''',
        variables: params.map((p) => Variable(p)).toList(),
      ).get();

      final total = results.fold<int>(0, (sum, row) => sum + row.read<int>('dive_count'));
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
      _log.error('Failed to get gas mix distribution', e, stackTrace);
      return [];
    }
  }

  /// Get best and worst SAC dives
  Future<({RankingItem? best, RankingItem? worst})> getSacRecords({String? diverId}) async {
    try {
      final diverFilter = diverId != null ? 'AND d.diver_id = ?' : '';
      final params = diverId != null ? [diverId] : <dynamic>[];

      final results = await _db.customSelect(
        '''
        SELECT
          d.id,
          d.dive_number,
          ds.name AS site_name,
          d.dive_date_time,
          ((t.start_pressure - t.end_pressure) * t.volume) / (d.duration / 60.0) / ((d.avg_depth / 10.0) + 1) AS sac
        FROM dives d
        JOIN dive_tanks t ON t.dive_id = d.id
        LEFT JOIN dive_sites ds ON ds.id = d.site_id
        WHERE d.duration > 0 AND d.avg_depth > 0
          AND t.start_pressure > t.end_pressure
          AND t.volume > 0
          $diverFilter
        ORDER BY sac ASC
        ''',
        variables: params.map((p) => Variable(p)).toList(),
      ).get();

      if (results.isEmpty) return (best: null, worst: null);

      RankingItem mapRow(dynamic row) {
        final dateMs = row.read<int>('dive_date_time');
        final date = DateTime.fromMillisecondsSinceEpoch(dateMs);
        final diveNum = row.read<int?>('dive_number');
        final siteName = row.read<String?>('site_name');
        return RankingItem(
          id: row.read<String>('id'),
          name: siteName ?? 'Dive #${diveNum ?? "?"}',
          count: 0,
          value: row.read<double>('sac'),
          subtitle: '${date.day}/${date.month}/${date.year}',
        );
      }

      return (
        best: mapRow(results.first),
        worst: mapRow(results.last),
      );
    } catch (e, stackTrace) {
      _log.error('Failed to get SAC records', e, stackTrace);
      return (best: null, worst: null);
    }
  }

  // ============================================================================
  // Dive Progression Statistics
  // ============================================================================

  /// Get maximum depth progression by month (last 5 years)
  Future<List<TrendDataPoint>> getDepthProgressionTrend({String? diverId}) async {
    try {
      final fiveYearsAgo = DateTime.now().subtract(const Duration(days: 365 * 5));
      final cutoff = fiveYearsAgo.millisecondsSinceEpoch;

      final diverFilter = diverId != null ? 'AND diver_id = ?' : '';
      final params = diverId != null ? [cutoff, diverId] : [cutoff];

      final results = await _db.customSelect(
        '''
        SELECT
          strftime('%Y', dive_date_time / 1000, 'unixepoch') AS year,
          strftime('%m', dive_date_time / 1000, 'unixepoch') AS month,
          MAX(max_depth) AS max_depth
        FROM dives
        WHERE dive_date_time >= ? AND max_depth IS NOT NULL $diverFilter
        GROUP BY year, month
        ORDER BY year, month
        ''',
        variables: params.map((p) => Variable(p)).toList(),
      ).get();

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
      _log.error('Failed to get depth progression trend', e, stackTrace);
      return [];
    }
  }

  /// Get average bottom time trend by month (last 5 years)
  Future<List<TrendDataPoint>> getBottomTimeTrend({String? diverId}) async {
    try {
      final fiveYearsAgo = DateTime.now().subtract(const Duration(days: 365 * 5));
      final cutoff = fiveYearsAgo.millisecondsSinceEpoch;

      final diverFilter = diverId != null ? 'AND diver_id = ?' : '';
      final params = diverId != null ? [cutoff, diverId] : [cutoff];

      final results = await _db.customSelect(
        '''
        SELECT
          strftime('%Y', dive_date_time / 1000, 'unixepoch') AS year,
          strftime('%m', dive_date_time / 1000, 'unixepoch') AS month,
          AVG(duration / 60.0) AS avg_duration
        FROM dives
        WHERE dive_date_time >= ? AND duration IS NOT NULL $diverFilter
        GROUP BY year, month
        ORDER BY year, month
        ''',
        variables: params.map((p) => Variable(p)).toList(),
      ).get();

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
      _log.error('Failed to get bottom time trend', e, stackTrace);
      return [];
    }
  }

  /// Get dives per year
  Future<List<({int year, int count})>> getDivesPerYear({String? diverId}) async {
    try {
      final diverFilter = diverId != null ? 'WHERE diver_id = ?' : '';
      final params = diverId != null ? [diverId] : <dynamic>[];

      final results = await _db.customSelect(
        '''
        SELECT
          strftime('%Y', dive_date_time / 1000, 'unixepoch') AS year,
          COUNT(*) AS count
        FROM dives
        $diverFilter
        GROUP BY year
        ORDER BY year
        ''',
        variables: params.map((p) => Variable(p)).toList(),
      ).get();

      return results.map((row) {
        return (
          year: int.parse(row.read<String>('year')),
          count: row.read<int>('count'),
        );
      }).toList();
    } catch (e, stackTrace) {
      _log.error('Failed to get dives per year', e, stackTrace);
      return [];
    }
  }

  /// Get cumulative dive count over time
  Future<List<TrendDataPoint>> getCumulativeDiveCount({String? diverId}) async {
    try {
      final diverFilter = diverId != null ? 'WHERE diver_id = ?' : '';
      final params = diverId != null ? [diverId] : <dynamic>[];

      final results = await _db.customSelect(
        '''
        SELECT
          strftime('%Y', dive_date_time / 1000, 'unixepoch') AS year,
          strftime('%m', dive_date_time / 1000, 'unixepoch') AS month,
          COUNT(*) AS count
        FROM dives
        $diverFilter
        GROUP BY year, month
        ORDER BY year, month
        ''',
        variables: params.map((p) => Variable(p)).toList(),
      ).get();

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
      _log.error('Failed to get cumulative dive count', e, stackTrace);
      return [];
    }
  }

  // ============================================================================
  // Conditions & Environment Statistics
  // ============================================================================

  /// Get visibility distribution
  Future<List<DistributionSegment>> getVisibilityDistribution({String? diverId}) async {
    try {
      final diverFilter = diverId != null ? 'AND diver_id = ?' : '';
      final params = diverId != null ? [diverId] : <dynamic>[];

      final results = await _db.customSelect(
        '''
        SELECT
          visibility,
          COUNT(*) AS count
        FROM dives
        WHERE visibility IS NOT NULL AND visibility != '' $diverFilter
        GROUP BY visibility
        ORDER BY count DESC
        ''',
        variables: params.map((p) => Variable(p)).toList(),
      ).get();

      final total = results.fold<int>(0, (sum, row) => sum + row.read<int>('count'));
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
      _log.error('Failed to get visibility distribution', e, stackTrace);
      return [];
    }
  }

  /// Get water type distribution (salt/fresh)
  Future<List<DistributionSegment>> getWaterTypeDistribution({String? diverId}) async {
    try {
      final diverFilter = diverId != null ? 'AND diver_id = ?' : '';
      final params = diverId != null ? [diverId] : <dynamic>[];

      final results = await _db.customSelect(
        '''
        SELECT
          COALESCE(water_type, 'Unknown') AS water_type,
          COUNT(*) AS count
        FROM dives
        WHERE water_type IS NOT NULL AND water_type != '' $diverFilter
        GROUP BY water_type
        ORDER BY count DESC
        ''',
        variables: params.map((p) => Variable(p)).toList(),
      ).get();

      final total = results.fold<int>(0, (sum, row) => sum + row.read<int>('count'));
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
      _log.error('Failed to get water type distribution', e, stackTrace);
      return [];
    }
  }

  /// Get entry method distribution
  Future<List<DistributionSegment>> getEntryMethodDistribution({String? diverId}) async {
    try {
      final diverFilter = diverId != null ? 'AND diver_id = ?' : '';
      final params = diverId != null ? [diverId] : <dynamic>[];

      final results = await _db.customSelect(
        '''
        SELECT
          entry_method,
          COUNT(*) AS count
        FROM dives
        WHERE entry_method IS NOT NULL AND entry_method != '' $diverFilter
        GROUP BY entry_method
        ORDER BY count DESC
        ''',
        variables: params.map((p) => Variable(p)).toList(),
      ).get();

      final total = results.fold<int>(0, (sum, row) => sum + row.read<int>('count'));
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
      _log.error('Failed to get entry method distribution', e, stackTrace);
      return [];
    }
  }

  /// Get temperature by month (min/avg/max)
  Future<List<({int month, double? minTemp, double? avgTemp, double? maxTemp})>> getTemperatureByMonth({String? diverId}) async {
    try {
      final diverFilter = diverId != null ? 'AND diver_id = ?' : '';
      final params = diverId != null ? [diverId] : <dynamic>[];

      final results = await _db.customSelect(
        '''
        SELECT
          CAST(strftime('%m', dive_date_time / 1000, 'unixepoch') AS INTEGER) AS month,
          MIN(water_temp) AS min_temp,
          AVG(water_temp) AS avg_temp,
          MAX(water_temp) AS max_temp
        FROM dives
        WHERE water_temp IS NOT NULL $diverFilter
        GROUP BY month
        ORDER BY month
        ''',
        variables: params.map((p) => Variable(p)).toList(),
      ).get();

      return results.map((row) {
        return (
          month: row.read<int>('month'),
          minTemp: row.read<double?>('min_temp'),
          avgTemp: row.read<double?>('avg_temp'),
          maxTemp: row.read<double?>('max_temp'),
        );
      }).toList();
    } catch (e, stackTrace) {
      _log.error('Failed to get temperature by month', e, stackTrace);
      return [];
    }
  }

  // ============================================================================
  // Social & Buddies Statistics
  // ============================================================================

  /// Get top buddies by dive count
  Future<List<RankingItem>> getTopBuddies({String? diverId, int limit = 10}) async {
    try {
      final diverFilter = diverId != null ? 'AND d.diver_id = ?' : '';
      final params = diverId != null ? [diverId, limit] : [limit];

      final results = await _db.customSelect(
        '''
        SELECT
          b.id,
          b.name,
          COUNT(db.dive_id) AS dive_count
        FROM buddies b
        JOIN dive_buddies db ON db.buddy_id = b.id
        JOIN dives d ON d.id = db.dive_id
        WHERE 1=1 $diverFilter
        GROUP BY b.id
        ORDER BY dive_count DESC
        LIMIT ?
        ''',
        variables: params.map((p) => Variable(p)).toList(),
      ).get();

      return results.map((row) {
        return RankingItem(
          id: row.read<String>('id'),
          name: row.read<String>('name'),
          count: row.read<int>('dive_count'),
        );
      }).toList();
    } catch (e, stackTrace) {
      _log.error('Failed to get top buddies', e, stackTrace);
      return [];
    }
  }

  /// Get solo vs buddy dive percentage
  Future<({int solo, int buddy})> getSoloVsBuddyCount({String? diverId}) async {
    try {
      final diverFilter = diverId != null ? 'WHERE d.diver_id = ?' : '';
      final params = diverId != null ? [diverId] : <dynamic>[];

      final results = await _db.customSelect(
        '''
        SELECT
          SUM(CASE WHEN db.buddy_id IS NULL AND (d.buddy IS NULL OR d.buddy = '') THEN 1 ELSE 0 END) AS solo,
          SUM(CASE WHEN db.buddy_id IS NOT NULL OR (d.buddy IS NOT NULL AND d.buddy != '') THEN 1 ELSE 0 END) AS buddy
        FROM dives d
        LEFT JOIN dive_buddies db ON db.dive_id = d.id
        $diverFilter
        ''',
        variables: params.map((p) => Variable(p)).toList(),
      ).get();

      if (results.isEmpty) return (solo: 0, buddy: 0);
      return (
        solo: results.first.read<int?>('solo') ?? 0,
        buddy: results.first.read<int?>('buddy') ?? 0,
      );
    } catch (e, stackTrace) {
      _log.error('Failed to get solo vs buddy count', e, stackTrace);
      return (solo: 0, buddy: 0);
    }
  }

  /// Get top dive centers by dive count
  Future<List<RankingItem>> getTopDiveCenters({String? diverId, int limit = 10}) async {
    try {
      final diverFilter = diverId != null ? 'AND d.diver_id = ?' : '';
      final params = diverId != null ? [diverId, limit] : [limit];

      final results = await _db.customSelect(
        '''
        SELECT
          dc.id,
          dc.name,
          dc.location,
          COUNT(d.id) AS dive_count
        FROM dive_centers dc
        JOIN dives d ON d.dive_center_id = dc.id
        WHERE 1=1 $diverFilter
        GROUP BY dc.id
        ORDER BY dive_count DESC
        LIMIT ?
        ''',
        variables: params.map((p) => Variable(p)).toList(),
      ).get();

      return results.map((row) {
        return RankingItem(
          id: row.read<String>('id'),
          name: row.read<String>('name'),
          count: row.read<int>('dive_count'),
          subtitle: row.read<String?>('location'),
        );
      }).toList();
    } catch (e, stackTrace) {
      _log.error('Failed to get top dive centers', e, stackTrace);
      return [];
    }
  }

  // ============================================================================
  // Geographic Statistics
  // ============================================================================

  /// Get countries visited with dive counts
  Future<List<RankingItem>> getCountriesVisited({String? diverId, int limit = 10}) async {
    try {
      final diverFilter = diverId != null ? 'AND d.diver_id = ?' : '';
      final params = diverId != null ? [diverId, limit] : [limit];

      final results = await _db.customSelect(
        '''
        SELECT
          ds.country,
          COUNT(d.id) AS dive_count
        FROM dive_sites ds
        JOIN dives d ON d.site_id = ds.id
        WHERE ds.country IS NOT NULL AND ds.country != '' $diverFilter
        GROUP BY ds.country
        ORDER BY dive_count DESC
        LIMIT ?
        ''',
        variables: params.map((p) => Variable(p)).toList(),
      ).get();

      return results.map((row) {
        final country = row.read<String>('country');
        return RankingItem(
          id: country,
          name: country,
          count: row.read<int>('dive_count'),
        );
      }).toList();
    } catch (e, stackTrace) {
      _log.error('Failed to get countries visited', e, stackTrace);
      return [];
    }
  }

  /// Get regions explored with dive counts
  Future<List<RankingItem>> getRegionsExplored({String? diverId, int limit = 10}) async {
    try {
      final diverFilter = diverId != null ? 'AND d.diver_id = ?' : '';
      final params = diverId != null ? [diverId, limit] : [limit];

      final results = await _db.customSelect(
        '''
        SELECT
          ds.region,
          ds.country,
          COUNT(d.id) AS dive_count
        FROM dive_sites ds
        JOIN dives d ON d.site_id = ds.id
        WHERE ds.region IS NOT NULL AND ds.region != '' $diverFilter
        GROUP BY ds.region, ds.country
        ORDER BY dive_count DESC
        LIMIT ?
        ''',
        variables: params.map((p) => Variable(p)).toList(),
      ).get();

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
      _log.error('Failed to get regions explored', e, stackTrace);
      return [];
    }
  }

  /// Get dives per trip
  Future<List<RankingItem>> getDivesPerTrip({String? diverId, int limit = 10}) async {
    try {
      final diverFilter = diverId != null ? 'AND d.diver_id = ?' : '';
      final params = diverId != null ? [diverId, limit] : [limit];

      final results = await _db.customSelect(
        '''
        SELECT
          t.id,
          t.name,
          t.location,
          COUNT(d.id) AS dive_count
        FROM trips t
        JOIN dives d ON d.trip_id = t.id
        WHERE 1=1 $diverFilter
        GROUP BY t.id
        ORDER BY dive_count DESC
        LIMIT ?
        ''',
        variables: params.map((p) => Variable(p)).toList(),
      ).get();

      return results.map((row) {
        return RankingItem(
          id: row.read<String>('id'),
          name: row.read<String>('name'),
          count: row.read<int>('dive_count'),
          subtitle: row.read<String?>('location'),
        );
      }).toList();
    } catch (e, stackTrace) {
      _log.error('Failed to get dives per trip', e, stackTrace);
      return [];
    }
  }

  // ============================================================================
  // Marine Life Statistics
  // ============================================================================

  /// Get unique species count
  Future<int> getUniqueSpeciesCount({String? diverId}) async {
    try {
      final diverFilter = diverId != null ? 'AND d.diver_id = ?' : '';
      final params = diverId != null ? [diverId] : <dynamic>[];

      final results = await _db.customSelect(
        '''
        SELECT COUNT(DISTINCT s.species_id) AS count
        FROM sightings s
        JOIN dives d ON d.id = s.dive_id
        WHERE 1=1 $diverFilter
        ''',
        variables: params.map((p) => Variable(p)).toList(),
      ).get();

      return results.first.read<int>('count');
    } catch (e, stackTrace) {
      _log.error('Failed to get unique species count', e, stackTrace);
      return 0;
    }
  }

  /// Get most common sightings
  Future<List<RankingItem>> getMostCommonSightings({String? diverId, int limit = 10}) async {
    try {
      final diverFilter = diverId != null ? 'AND d.diver_id = ?' : '';
      final params = diverId != null ? [diverId, limit] : [limit];

      final results = await _db.customSelect(
        '''
        SELECT
          sp.id,
          sp.common_name,
          sp.category,
          SUM(s.count) AS total_count
        FROM sightings s
        JOIN species sp ON sp.id = s.species_id
        JOIN dives d ON d.id = s.dive_id
        WHERE 1=1 $diverFilter
        GROUP BY sp.id
        ORDER BY total_count DESC
        LIMIT ?
        ''',
        variables: params.map((p) => Variable(p)).toList(),
      ).get();

      return results.map((row) {
        return RankingItem(
          id: row.read<String>('id'),
          name: row.read<String>('common_name'),
          count: row.read<int>('total_count'),
          subtitle: row.read<String?>('category'),
        );
      }).toList();
    } catch (e, stackTrace) {
      _log.error('Failed to get most common sightings', e, stackTrace);
      return [];
    }
  }

  /// Get best sites for marine life (most species variety)
  Future<List<RankingItem>> getBestSitesForMarineLife({String? diverId, int limit = 10}) async {
    try {
      final diverFilter = diverId != null ? 'AND d.diver_id = ?' : '';
      final params = diverId != null ? [diverId, limit] : [limit];

      final results = await _db.customSelect(
        '''
        SELECT
          ds.id,
          ds.name,
          COUNT(DISTINCT s.species_id) AS species_count
        FROM dive_sites ds
        JOIN dives d ON d.site_id = ds.id
        JOIN sightings s ON s.dive_id = d.id
        WHERE 1=1 $diverFilter
        GROUP BY ds.id
        ORDER BY species_count DESC
        LIMIT ?
        ''',
        variables: params.map((p) => Variable(p)).toList(),
      ).get();

      return results.map((row) {
        return RankingItem(
          id: row.read<String>('id'),
          name: row.read<String>('name'),
          count: row.read<int>('species_count'),
        );
      }).toList();
    } catch (e, stackTrace) {
      _log.error('Failed to get best sites for marine life', e, stackTrace);
      return [];
    }
  }

  // ============================================================================
  // Time Pattern Statistics
  // ============================================================================

  /// Get dives by day of week
  Future<List<({int dayOfWeek, int count})>> getDivesByDayOfWeek({String? diverId}) async {
    try {
      final diverFilter = diverId != null ? 'WHERE diver_id = ?' : '';
      final params = diverId != null ? [diverId] : <dynamic>[];

      final results = await _db.customSelect(
        '''
        SELECT
          CAST(strftime('%w', dive_date_time / 1000, 'unixepoch') AS INTEGER) AS day_of_week,
          COUNT(*) AS count
        FROM dives
        $diverFilter
        GROUP BY day_of_week
        ORDER BY day_of_week
        ''',
        variables: params.map((p) => Variable(p)).toList(),
      ).get();

      return results.map((row) {
        return (
          dayOfWeek: row.read<int>('day_of_week'),
          count: row.read<int>('count'),
        );
      }).toList();
    } catch (e, stackTrace) {
      _log.error('Failed to get dives by day of week', e, stackTrace);
      return [];
    }
  }

  /// Get dives by time of day (morning, afternoon, evening, night)
  Future<List<DistributionSegment>> getDivesByTimeOfDay({String? diverId}) async {
    try {
      final diverFilter = diverId != null ? 'WHERE diver_id = ?' : '';
      final params = diverId != null ? [diverId] : <dynamic>[];

      final results = await _db.customSelect(
        '''
        SELECT
          CASE
            WHEN CAST(strftime('%H', COALESCE(entry_time, dive_date_time) / 1000, 'unixepoch') AS INTEGER) < 6 THEN 'Night'
            WHEN CAST(strftime('%H', COALESCE(entry_time, dive_date_time) / 1000, 'unixepoch') AS INTEGER) < 12 THEN 'Morning'
            WHEN CAST(strftime('%H', COALESCE(entry_time, dive_date_time) / 1000, 'unixepoch') AS INTEGER) < 18 THEN 'Afternoon'
            ELSE 'Evening'
          END AS time_of_day,
          COUNT(*) AS count
        FROM dives
        $diverFilter
        GROUP BY time_of_day
        ORDER BY
          CASE time_of_day
            WHEN 'Morning' THEN 1
            WHEN 'Afternoon' THEN 2
            WHEN 'Evening' THEN 3
            WHEN 'Night' THEN 4
          END
        ''',
        variables: params.map((p) => Variable(p)).toList(),
      ).get();

      final total = results.fold<int>(0, (sum, row) => sum + row.read<int>('count'));
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
      _log.error('Failed to get dives by time of day', e, stackTrace);
      return [];
    }
  }

  /// Get dives by month (seasonal patterns)
  Future<List<({int month, int count})>> getDivesBySeason({String? diverId}) async {
    try {
      final diverFilter = diverId != null ? 'WHERE diver_id = ?' : '';
      final params = diverId != null ? [diverId] : <dynamic>[];

      final results = await _db.customSelect(
        '''
        SELECT
          CAST(strftime('%m', dive_date_time / 1000, 'unixepoch') AS INTEGER) AS month,
          COUNT(*) AS count
        FROM dives
        $diverFilter
        GROUP BY month
        ORDER BY month
        ''',
        variables: params.map((p) => Variable(p)).toList(),
      ).get();

      return results.map((row) {
        return (
          month: row.read<int>('month'),
          count: row.read<int>('count'),
        );
      }).toList();
    } catch (e, stackTrace) {
      _log.error('Failed to get dives by season', e, stackTrace);
      return [];
    }
  }

  /// Get surface interval statistics
  Future<({double? avgMinutes, double? minMinutes, double? maxMinutes})> getSurfaceIntervalStats({String? diverId}) async {
    try {
      final diverFilter = diverId != null ? 'WHERE diver_id = ?' : '';
      final params = diverId != null ? [diverId] : <dynamic>[];

      final results = await _db.customSelect(
        '''
        SELECT
          AVG(surface_interval_seconds / 60.0) AS avg_si,
          MIN(surface_interval_seconds / 60.0) AS min_si,
          MAX(surface_interval_seconds / 60.0) AS max_si
        FROM dives
        $diverFilter
          ${diverFilter.isEmpty ? 'WHERE' : 'AND'} surface_interval_seconds IS NOT NULL
          AND surface_interval_seconds > 0
        ''',
        variables: params.map((p) => Variable(p)).toList(),
      ).get();

      if (results.isEmpty) return (avgMinutes: null, minMinutes: null, maxMinutes: null);
      return (
        avgMinutes: results.first.read<double?>('avg_si'),
        minMinutes: results.first.read<double?>('min_si'),
        maxMinutes: results.first.read<double?>('max_si'),
      );
    } catch (e, stackTrace) {
      _log.error('Failed to get surface interval stats', e, stackTrace);
      return (avgMinutes: null, minMinutes: null, maxMinutes: null);
    }
  }

  // ============================================================================
  // Equipment Statistics
  // ============================================================================

  /// Get most used gear
  Future<List<RankingItem>> getMostUsedGear({String? diverId, int limit = 10}) async {
    try {
      final diverFilter = diverId != null ? 'AND d.diver_id = ?' : '';
      final params = diverId != null ? [diverId, limit] : [limit];

      final results = await _db.customSelect(
        '''
        SELECT
          e.id,
          e.name,
          e.type,
          e.brand,
          COUNT(de.dive_id) AS use_count
        FROM equipment e
        JOIN dive_equipment de ON de.equipment_id = e.id
        JOIN dives d ON d.id = de.dive_id
        WHERE 1=1 $diverFilter
        GROUP BY e.id
        ORDER BY use_count DESC
        LIMIT ?
        ''',
        variables: params.map((p) => Variable(p)).toList(),
      ).get();

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
      _log.error('Failed to get most used gear', e, stackTrace);
      return [];
    }
  }

  /// Get weight trend by month
  Future<List<TrendDataPoint>> getWeightTrend({String? diverId}) async {
    try {
      final fiveYearsAgo = DateTime.now().subtract(const Duration(days: 365 * 5));
      final cutoff = fiveYearsAgo.millisecondsSinceEpoch;

      final diverFilter = diverId != null ? 'AND d.diver_id = ?' : '';
      final params = diverId != null ? [cutoff, diverId] : [cutoff];

      final results = await _db.customSelect(
        '''
        SELECT
          strftime('%Y', d.dive_date_time / 1000, 'unixepoch') AS year,
          strftime('%m', d.dive_date_time / 1000, 'unixepoch') AS month,
          AVG(dw.amount_kg) AS avg_weight
        FROM dives d
        JOIN dive_weights dw ON dw.dive_id = d.id
        WHERE d.dive_date_time >= ? $diverFilter
        GROUP BY year, month
        ORDER BY year, month
        ''',
        variables: params.map((p) => Variable(p)).toList(),
      ).get();

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
      _log.error('Failed to get weight trend', e, stackTrace);
      return [];
    }
  }

  // ============================================================================
  // Profile Analysis Statistics
  // ============================================================================

  /// Get average ascent/descent rates
  Future<({double? avgAscent, double? avgDescent})> getAscentDescentRates({String? diverId}) async {
    try {
      final diverFilter = diverId != null ? 'AND d.diver_id = ?' : '';
      final params = diverId != null ? [diverId] : <dynamic>[];

      final results = await _db.customSelect(
        '''
        SELECT
          AVG(CASE WHEN p.ascent_rate < 0 THEN ABS(p.ascent_rate) ELSE NULL END) AS avg_ascent,
          AVG(CASE WHEN p.ascent_rate > 0 THEN p.ascent_rate ELSE NULL END) AS avg_descent
        FROM dive_profiles p
        JOIN dives d ON d.id = p.dive_id
        WHERE p.ascent_rate IS NOT NULL $diverFilter
        ''',
        variables: params.map((p) => Variable(p)).toList(),
      ).get();

      if (results.isEmpty) return (avgAscent: null, avgDescent: null);
      return (
        avgAscent: results.first.read<double?>('avg_ascent'),
        avgDescent: results.first.read<double?>('avg_descent'),
      );
    } catch (e, stackTrace) {
      _log.error('Failed to get ascent/descent rates', e, stackTrace);
      return (avgAscent: null, avgDescent: null);
    }
  }

  /// Get time spent in depth ranges
  Future<List<({String range, int minutes})>> getTimeAtDepthRanges({String? diverId}) async {
    try {
      final diverFilter = diverId != null ? 'AND d.diver_id = ?' : '';
      final params = diverId != null ? [diverId] : <dynamic>[];

      final results = await _db.customSelect(
        '''
        SELECT
          CASE
            WHEN p.depth < 10 THEN '0-10m'
            WHEN p.depth < 20 THEN '10-20m'
            WHEN p.depth < 30 THEN '20-30m'
            WHEN p.depth < 40 THEN '30-40m'
            ELSE '40m+'
          END AS depth_range,
          COUNT(*) AS sample_count
        FROM dive_profiles p
        JOIN dives d ON d.id = p.dive_id
        WHERE 1=1 $diverFilter
        GROUP BY depth_range
        ORDER BY
          CASE depth_range
            WHEN '0-10m' THEN 1
            WHEN '10-20m' THEN 2
            WHEN '20-30m' THEN 3
            WHEN '30-40m' THEN 4
            ELSE 5
          END
        ''',
        variables: params.map((p) => Variable(p)).toList(),
      ).get();

      // Sample count approximates minutes (profiles are usually sampled every second or few seconds)
      // This is a rough approximation
      return results.map((row) {
        return (
          range: row.read<String>('depth_range'),
          minutes: (row.read<int>('sample_count') / 60).round(), // Rough estimate
        );
      }).toList();
    } catch (e, stackTrace) {
      _log.error('Failed to get time at depth ranges', e, stackTrace);
      return [];
    }
  }

  /// Get percentage of dives with decompression obligation
  Future<({int decoCount, int totalCount})> getDecoObligationStats({String? diverId}) async {
    try {
      final diverFilter = diverId != null ? 'WHERE d.diver_id = ?' : '';
      final params = diverId != null ? [diverId] : <dynamic>[];

      final results = await _db.customSelect(
        '''
        SELECT
          COUNT(DISTINCT CASE WHEN p.ceiling > 0 THEN d.id END) AS deco_count,
          COUNT(DISTINCT d.id) AS total_count
        FROM dives d
        LEFT JOIN dive_profiles p ON p.dive_id = d.id
        $diverFilter
        ''',
        variables: params.map((p) => Variable(p)).toList(),
      ).get();

      if (results.isEmpty) return (decoCount: 0, totalCount: 0);
      return (
        decoCount: results.first.read<int?>('deco_count') ?? 0,
        totalCount: results.first.read<int?>('total_count') ?? 0,
      );
    } catch (e, stackTrace) {
      _log.error('Failed to get deco obligation stats', e, stackTrace);
      return (decoCount: 0, totalCount: 0);
    }
  }

  // ============================================================================
  // Helpers
  // ============================================================================

  String _monthAbbr(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[month - 1];
  }
}
