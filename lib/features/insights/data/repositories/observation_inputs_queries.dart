import 'package:drift/drift.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/database/dive_stats_scope.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/util/wall_clock_utc.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_times_sql.dart';
import 'package:submersion/features/insights/domain/observations/observation_inputs.dart';

/// Read-only SQL for the observation rules (#2381): one row per in-scope
/// dive with the columns the rules need, plus its buddies. Whole log: no
/// view filter, only DiveStatsScope.
class ObservationInputsQueries {
  AppDatabase get _db => DatabaseService.instance.database;
  final _log = LoggerService.forClass(ObservationInputsQueries);

  /// Every in-scope dive of [diverId] (every diver when null), oldest first.
  Future<List<ObservationDive>> dives({String? diverId}) async {
    try {
      final diverFilter = diverId != null ? 'AND d.diver_id = ?' : '';
      final variables = <Variable<Object>>[
        if (diverId != null) Variable<String>(diverId),
      ];
      final rows = await _db
          .customSelect(
            'SELECT d.id AS id, d.dive_date_time AS ms, '
            'd.max_depth AS max_depth, '
            '${effectiveRuntimeSecondsSql('d')} AS runtime_s, '
            '(SELECT SUM(w.amount_kg) FROM dive_weights w '
            'WHERE w.dive_id = d.id) AS weight_kg, '
            'd.site_id AS site_id, ds.name AS site_name, '
            'ds.country AS country, '
            'EXISTS (SELECT 1 FROM dive_profile_series s '
            'WHERE s.dive_id = d.id AND s.is_primary = 1) AS has_profile '
            'FROM dives d LEFT JOIN dive_sites ds ON ds.id = d.site_id '
            'WHERE 1=1 $diverFilter ${DiveStatsScope.and(alias: 'd')} '
            'ORDER BY d.dive_date_time, d.id',
            variables: variables,
            readsFrom: {
              _db.dives,
              _db.diveWeights,
              _db.diveSites,
              _db.diveProfileSeries,
            },
          )
          .get();
      final buddies = await _buddiesByDive(diverFilter, variables);
      return [
        for (final r in rows)
          ObservationDive(
            id: r.read<String>('id'),
            date: wallClockUtcFromMillis(r.read<int>('ms')),
            maxDepthM: (r.data['max_depth'] as num?)?.toDouble(),
            runtimeSeconds: (r.data['runtime_s'] as num?)?.round(),
            weightKg: (r.data['weight_kg'] as num?)?.toDouble(),
            siteId: r.data['site_id'] as String?,
            siteName: r.data['site_name'] as String?,
            country: r.data['country'] as String?,
            hasProfile: (r.data['has_profile'] as int? ?? 0) != 0,
            buddies: buddies[r.read<String>('id')] ?? const [],
          ),
      ];
    } catch (e, stackTrace) {
      _log.error(
        'Failed to load observation dives',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Each in-scope dive's linked buddies, once per buddy even when one
  /// buddy is linked to a dive under two roles.
  Future<Map<String, List<ObservationBuddy>>> _buddiesByDive(
    String diverFilter,
    List<Variable<Object>> variables,
  ) async {
    final rows = await _db
        .customSelect(
          'SELECT DISTINCT db.dive_id AS dive_id, b.id AS id, b.name AS name '
          'FROM dive_buddies db JOIN buddies b ON b.id = db.buddy_id '
          'JOIN dives d ON d.id = db.dive_id '
          'WHERE 1=1 $diverFilter ${DiveStatsScope.and(alias: 'd')} '
          'ORDER BY b.name, b.id',
          variables: variables,
          readsFrom: {_db.diveBuddies, _db.buddies, _db.dives},
        )
        .get();
    final out = <String, List<ObservationBuddy>>{};
    for (final r in rows) {
      out
          .putIfAbsent(r.read<String>('dive_id'), () => [])
          .add(
            ObservationBuddy(
              id: r.read<String>('id'),
              name: r.read<String>('name'),
            ),
          );
    }
    return out;
  }
}
