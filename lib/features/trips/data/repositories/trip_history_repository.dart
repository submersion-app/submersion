import 'package:drift/drift.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';

/// The two history reads behind the scrubber margin estimates. Both take
/// [before] so a past trip reads the history the diver had at its start.
class TripHistoryRepository {
  final AppDatabase? _dbOverride;

  TripHistoryRepository({AppDatabase? db}) : _dbOverride = db;

  AppDatabase get _db => _dbOverride ?? DatabaseService.instance.database;

  /// Dives per dive day for the diver's most recent [limit] trips that
  /// ended before [before] and had at least one dive, newest first. A
  /// dive day is a distinct calendar date with a dive on it.
  Future<List<double>> divesPerDiveDay({
    String? diverId,
    required DateTime before,
    int limit = 3,
  }) async {
    final diverFilter = diverId != null ? 'AND t.diver_id = ?' : '';
    final rows = await _db
        .customSelect(
          '''
          SELECT
            COUNT(d.id) AS dives,
            COUNT(DISTINCT date(d.dive_date_time / 1000, 'unixepoch')) AS days
          FROM trips t
          JOIN dives d ON d.trip_id = t.id
          WHERE t.end_date < ? $diverFilter
          GROUP BY t.id
          ORDER BY t.end_date DESC
          LIMIT ?
          ''',
          variables: [
            Variable(before.millisecondsSinceEpoch),
            if (diverId != null) Variable(diverId),
            Variable(limit),
          ],
        )
        .get();
    return [
      for (final r in rows)
        if (r.read<int>('days') > 0) r.read<int>('dives') / r.read<int>('days'),
    ];
  }

  /// The diver's most recent [limit] CCR or SCR dives before [before],
  /// newest first: the summary's scrubber minutes when the dive has one,
  /// and the runtime in minutes.
  Future<List<({double? scrubberMinutes, double runtimeMinutes})>>
  recentCcrFigures({
    String? diverId,
    required DateTime before,
    int limit = 30,
  }) async {
    final diverFilter = diverId != null ? 'AND d.diver_id = ?' : '';
    final rows = await _db
        .customSelect(
          '''
          SELECT
            s.scrubber_consumed_minutes AS scrubber,
            d.runtime AS runtime
          FROM dives d
          LEFT JOIN dive_sensor_summaries s ON s.dive_id = d.id
          WHERE d.dive_mode IN ('ccr', 'scr')
            AND d.dive_date_time < ? $diverFilter
          ORDER BY d.dive_date_time DESC
          LIMIT ?
          ''',
          variables: [
            Variable(before.millisecondsSinceEpoch),
            if (diverId != null) Variable(diverId),
            Variable(limit),
          ],
        )
        .get();
    return [
      for (final r in rows)
        (
          scrubberMinutes: r.read<double?>('scrubber'),
          runtimeMinutes: (r.read<int?>('runtime') ?? 0) / 60.0,
        ),
    ];
  }
}
