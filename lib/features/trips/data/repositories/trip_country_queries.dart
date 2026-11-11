import 'package:drift/drift.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/database/dive_stats_scope.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/trips/data/repositories/trip_country_tally.dart';
import 'package:submersion/features/trips/data/side_trip_sql.dart';
import 'package:submersion/features/trips/domain/entities/trip_country.dart';

/// The read behind the flags beside trips (issue #4426), kept out of
/// `TripRepository`, which is already past the file size limit.
class TripCountryQueries {
  AppDatabase get _db => DatabaseService.instance.database;
  final _log = LoggerService.forClass(TripCountryQueries);

  /// Each trip's countries, for the flags beside it (issue #4426), keyed by
  /// trip id. A trip with no recognisable country has no entry.
  ///
  /// Reads the dives `TripRepository.getAllTripsWithStats` counts: [diverId]'s own, in the
  /// statistics scope, with a larger trip counting its side trips' dives,
  /// so a trip's flags and its dive count always agree. One query for every
  /// trip, so a list of trips costs one read. Countries come most dived
  /// first, a tie going to the one dived earlier; site names that mean one
  /// country ("Mexico", "México") count as one.
  Future<Map<String, List<TripCountry>>> getTripCountries({
    String? diverId,
  }) async {
    try {
      final scope = DiveStatsScope.and(alias: 'd');
      final joinClause = tripDivesJoinSql(
        tripAlias: 't',
        diveAlias: 'd',
        joinKind: 'INNER',
        extraOn: diverId != null ? ' AND d.diver_id = ?$scope' : scope,
      );
      final rows = await _db
          .customSelect(
            '''
        SELECT
          t.id AS trip_id,
          s.country AS country,
          COUNT(DISTINCT d.id) AS dive_count,
          MIN(d.dive_date_time) AS first_dive
        FROM trips t
        $joinClause
        INNER JOIN dive_sites s ON s.id = d.site_id
        WHERE s.country IS NOT NULL AND TRIM(s.country) <> ''
        GROUP BY t.id, s.country
      ''',
            variables: [if (diverId != null) Variable.withString(diverId)],
          )
          .get();

      return tallyTripCountries(
        rows.map(
          (row) => (
            tripId: row.read<String>('trip_id'),
            name: row.read<String>('country').trim(),
            dives: row.read<int>('dive_count'),
            firstDive: row.read<int>('first_dive'),
          ),
        ),
      );
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get trip countries',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }
}
