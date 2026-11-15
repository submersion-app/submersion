import 'package:drift/drift.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_times_sql.dart';
import 'package:submersion/features/trips/data/side_trip_sql.dart';

/// The read behind the trip day picker's dashed outlines, kept out of
/// `TripRepository`, which is already past the file size limit.
class TripUndivedPlanQueries {
  AppDatabase get _db => DatabaseService.instance.database;
  final _log = LoggerService.forClass(TripUndivedPlanQueries);

  /// Ids of the dives on [tripId], its side trips' included, that are plans
  /// nobody has dived.
  ///
  /// `is_planned` alone is not the test: a dive mirrored from a buddy's
  /// logged dive stays planned but happened ([diveUndivedSql], issue #3924).
  /// Logs and rethrows when the read fails. An empty set would be an answer,
  /// that no plan is undived, and the picker would draw every plan as a dive
  /// that happened; a failure leaves it not knowing, and plans undrawn.
  // stats-scope-exempt: names plans for the trip's day picker; plans are
  // outside the statistics scope by definition
  Future<Set<String>> undivedPlanIds(String tripId) async {
    try {
      final rows = await _db
          .customSelect(
            'SELECT id FROM dives '
            "WHERE ${tripDivesScopeSql('dives', '?1')} "
            "AND ${diveUndivedSql('dives')}",
            variables: [Variable.withString(tripId)],
          )
          .get();
      return {for (final row in rows) row.read<String>('id')};
    } catch (e, stackTrace) {
      _log.error(
        'Failed to read undived plans for trip: $tripId',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }
}
