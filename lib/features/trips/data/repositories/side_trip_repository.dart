import 'package:drift/drift.dart';

import 'package:submersion/core/data/visibility/shared_item_policy.dart';
import 'package:submersion/core/data/visibility/visibility_filter.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/trips/data/repositories/trip_row_mapper.dart';
import 'package:submersion/features/trips/data/side_trip_sql.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart' as domain;

/// Reads the side-trip links between trips (issue #3658), by the rule of
/// `side_trip_sql.dart`, limited to the trips [diverId] can see when one is
/// given: a parent the profile cannot see is no parent for it.
class SideTripRepository {
  AppDatabase get _db => DatabaseService.instance.database;
  final _log = LoggerService.forClass(SideTripRepository);

  /// [tripId]'s valid side trips, earliest first.
  Future<List<domain.Trip>> getSideTrips(
    String tripId, {
    String? diverId,
  }) async {
    try {
      final rows = await _visibleTrips(
        sideTripIdsSql('?'),
        tripId,
        diverId,
        orderBy: 'ORDER BY t.start_date ASC',
      );
      return rows.map(tripFromData).toList();
    } catch (e, stackTrace) {
      _log.error(
        'Failed to read side trips of trip: $tripId',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Whether any trip, whoever owns it, is a valid side trip of [tripId].
  Future<bool> hasSideTrips(String tripId) async {
    try {
      final row = await _db
          .customSelect(
            'SELECT EXISTS (${sideTripIdsSql('?')}) AS has_side_trips',
            variables: [Variable.withString(tripId)],
            readsFrom: {_db.trips},
          )
          .getSingle();
      return row.read<bool>('has_side_trips');
    } catch (e, stackTrace) {
      _log.error(
        'Failed to check side trips of trip: $tripId',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// The larger trip [tripId] is a side trip of, or null.
  Future<domain.Trip?> getParentTrip(String tripId, {String? diverId}) async {
    try {
      final rows = await _visibleTrips(validParentIdSql('?'), tripId, diverId);
      return rows.isEmpty ? null : tripFromData(rows.single);
    } catch (e, stackTrace) {
      _log.error(
        'Failed to read the larger trip of trip: $tripId',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Trip [tripId] when [diverId] can see it, else null.
  Future<domain.Trip?> getVisibleTrip(String tripId, {String? diverId}) async {
    try {
      final rows = await _visibleTrips('?', tripId, diverId);
      return rows.isEmpty ? null : tripFromData(rows.single);
    } catch (e, stackTrace) {
      _log.error(
        'Failed to read trip: $tripId',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  Future<List<Map<String, Object?>>> _visibleTrips(
    String idsSql,
    String tripId,
    String? diverId, {
    String orderBy = '',
  }) async {
    final vis = VisibilityFilter.sqlFragment(
      tableAlias: 't',
      diverId: diverId,
      conjunction: 'AND',
      kind: SharedItemKind.trip,
    );
    final rows = await _db
        .customSelect(
          'SELECT t.* FROM trips t WHERE t.id IN ($idsSql) '
          '${vis.whereClause} $orderBy',
          variables: [Variable.withString(tripId), ...vis.variables],
          readsFrom: {_db.trips, _db.tripHides, _db.tripShares},
        )
        .get();
    return [for (final r in rows) r.data];
  }
}
