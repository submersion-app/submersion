part of 'insights_repository.dart';

/// The diver's averages over a recent window, for the Home "latest dive
/// against average" panel. Null when no dive in the window has the value.
class HomeAverages {
  final double? maxDepth;

  /// Measured runtime, never bottom time.
  final int? runtimeSeconds;
  final int diveCount;

  const HomeAverages({
    required this.maxDepth,
    required this.runtimeSeconds,
    required this.diveCount,
  });
}

/// One species and how many of the counted dives it was seen on.
class SpeciesSighting {
  final String name;
  final int diveCount;

  const SpeciesSighting({required this.name, required this.diveCount});
}

/// The read queries behind the Home panels (issue #4824), kept beside the
/// repository so the main file does not grow further.
///
/// None takes a filter: Home shows the diver's whole log, whatever the
/// Insights page is filtered to. All apply the stats scope (no planned,
/// draft or excluded dives), as the year stats do.
extension InsightsRepositoryHome on InsightsRepository {
  /// Dives per calendar day from [from] to [to], both days included. Keys
  /// are local midnights; days with no dives are absent.
  ///
  /// `dive_date_time` is the wall clock flagged as UTC, so the bounds are the
  /// same wall clock flagged as UTC and `strftime` in UTC reads the diver's
  /// own date, as the calendar matrix does.
  Future<Map<DateTime, int>> getDailyDiveCounts({
    String? diverId,
    required DateTime from,
    required DateTime to,
  }) async {
    try {
      final startMs = DateTime.utc(
        from.year,
        from.month,
        from.day,
      ).millisecondsSinceEpoch;
      final endMs = DateTime.utc(
        to.year,
        to.month,
        to.day + 1,
      ).millisecondsSinceEpoch;
      final diverFilter = diverId != null ? 'AND diver_id = ?' : '';
      final rows = await _db
          .customSelect(
            '''
        SELECT
          strftime('%Y-%m-%d', dive_date_time / 1000, 'unixepoch') AS day,
          COUNT(*) AS count
        FROM dives
        WHERE dive_date_time >= ? AND dive_date_time < ?
        $diverFilter${DiveStatsScope.and(alias: 'dives')}
        GROUP BY day
        ''',
            variables: [
              Variable<int>(startMs),
              Variable<int>(endMs),
              if (diverId != null) Variable<String>(diverId),
            ],
          )
          .get();
      return {
        for (final row in rows)
          _localDay(row.read<String>('day')): row.read<int>('count'),
      };
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get daily dive counts',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// SAC for the newest [limit] dives that have one, oldest first. Litres a
  /// minute, or bar a minute when [pressure] is true, using the same
  /// definitions as the Insights SAC charts.
  ///
  /// The limit is applied in SQL by the Insights queries themselves, so the
  /// gas arithmetic stays in one place. The tail is trimmed again here only
  /// as a guard: a chosen dive can still compute no SAC.
  Future<List<TrendDataPoint>> getRecentSacPerDive({
    String? diverId,
    required int limit,
    bool pressure = false,
  }) async {
    final all = pressure
        ? await getSacPressurePerDive(diverId: diverId, limit: limit)
        : await getSacVolumePerDive(diverId: diverId, limit: limit);
    final sorted = [...all]..sort((a, b) => a.date.compareTo(b.date));
    return sorted.length <= limit
        ? sorted
        : sorted.sublist(sorted.length - limit);
  }

  /// Average maximum depth and measured runtime over dives on or after
  /// [since].
  Future<HomeAverages> getAveragesSince({
    String? diverId,
    required DateTime since,
  }) async {
    try {
      final startMs = DateTime.utc(
        since.year,
        since.month,
        since.day,
      ).millisecondsSinceEpoch;
      final diverFilter = diverId != null ? 'AND diver_id = ?' : '';
      final row = await _db
          .customSelect(
            '''
        SELECT
          COUNT(*) AS dive_count,
          AVG(max_depth) AS avg_max_depth,
          AVG(NULLIF(${measuredRuntimeSecondsSql('dives')}, 0)) AS avg_runtime
        FROM dives
        WHERE dive_date_time >= ?
        $diverFilter${DiveStatsScope.and(alias: 'dives')}
        ''',
            variables: [
              Variable<int>(startMs),
              if (diverId != null) Variable<String>(diverId),
            ],
          )
          .getSingle();
      final runtime = row.readNullable<double>('avg_runtime');
      return HomeAverages(
        maxDepth: row.readNullable<double>('avg_max_depth'),
        runtimeSeconds: runtime?.round(),
        diveCount: row.read<int>('dive_count'),
      );
    } catch (e, stackTrace) {
      _log.error('Failed to get averages', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// The diver's deepest dive in [year], with its site's name, or the dive's
  /// own name when it has no site: the Home deepest tile names that dive and
  /// opens it. Null when no dive that year has a depth. Ties go to the
  /// newest dive.
  Future<({String id, String? site})?> getDeepestDiveOfYear(
    int year, {
    String? diverId,
  }) async {
    try {
      // The same half-open, wall-clock-as-UTC range as getYearStats, so the
      // tile's dive is the one whose depth the year stats report.
      final startMs = DateTime.utc(year).millisecondsSinceEpoch;
      final endMs = DateTime.utc(year + 1).millisecondsSinceEpoch;
      final diverFilter = diverId != null ? 'AND d.diver_id = ?' : '';
      final row = await _db
          .customSelect(
            '''
        SELECT
          d.id AS id,
          COALESCE(NULLIF(TRIM(ds.name), ''), NULLIF(TRIM(d.name), '')) AS site
        FROM dives d
        LEFT JOIN dive_sites ds ON ds.id = d.site_id
        WHERE d.dive_date_time >= ? AND d.dive_date_time < ?
          AND d.max_depth IS NOT NULL
        $diverFilter${DiveStatsScope.and(alias: 'd')}
        ORDER BY d.max_depth DESC, d.dive_date_time DESC
        LIMIT 1
        ''',
            variables: [
              Variable<int>(startMs),
              Variable<int>(endMs),
              if (diverId != null) Variable<String>(diverId),
            ],
          )
          .getSingleOrNull();
      if (row == null) return null;
      return (
        id: row.read<String>('id'),
        site: row.readNullable<String>('site'),
      );
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get the deepest dive of the year',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// How many species the diver saw for the first time on or after [since].
  Future<int> getSpeciesFirstSeenSince({
    String? diverId,
    required DateTime since,
  }) async {
    try {
      final startMs = DateTime.utc(
        since.year,
        since.month,
        since.day,
      ).millisecondsSinceEpoch;
      final diverFilter = diverId != null ? 'AND d.diver_id = ?' : '';
      final row = await _db
          .customSelect(
            '''
        SELECT COUNT(*) AS count FROM (
          SELECT s.species_id, MIN(d.dive_date_time) AS first_seen
          FROM sightings s
          JOIN dives d ON d.id = s.dive_id
          WHERE 1 = 1 $diverFilter${DiveStatsScope.and(alias: 'd')}
          GROUP BY s.species_id
        )
        WHERE first_seen >= ?
        ''',
            variables: [
              if (diverId != null) Variable<String>(diverId),
              Variable<int>(startMs),
            ],
          )
          .getSingle();
      return row.read<int>('count');
    } catch (e, stackTrace) {
      _log.error(
        'Failed to count new species',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Species seen on the diver's newest [recentDives] dives, ranked by the
  /// number of those dives each was seen on, at most [limit].
  Future<List<SpeciesSighting>> getRecentSpeciesSightings({
    String? diverId,
    required int recentDives,
    required int limit,
  }) async {
    try {
      final diverFilter = diverId != null ? 'AND diver_id = ?' : '';
      final rows = await _db
          .customSelect(
            '''
        SELECT sp.common_name AS name, COUNT(DISTINCT s.dive_id) AS dives
        FROM sightings s
        JOIN species sp ON sp.id = s.species_id
        WHERE s.dive_id IN (
          SELECT id FROM dives
          WHERE 1 = 1 $diverFilter${DiveStatsScope.and(alias: 'dives')}
          ORDER BY dive_date_time DESC
          LIMIT ?
        )
        GROUP BY sp.id
        ORDER BY dives DESC, sp.common_name
        LIMIT ?
        ''',
            variables: [
              if (diverId != null) Variable<String>(diverId),
              Variable<int>(recentDives),
              Variable<int>(limit),
            ],
          )
          .get();
      return [
        for (final row in rows)
          SpeciesSighting(
            name: row.read<String>('name'),
            diveCount: row.read<int>('dives'),
          ),
      ];
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get recent species',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }
}

DateTime _localDay(String isoDay) {
  final parts = isoDay.split('-');
  return DateTime(
    int.parse(parts[0]),
    int.parse(parts[1]),
    int.parse(parts[2]),
  );
}
