import 'package:drift/drift.dart';

import 'package:submersion/core/data/visibility/shared_item_policy.dart';
import 'package:submersion/core/data/visibility/visibility_filter.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/trips/data/repositories/trip_row_mapper.dart';
import 'package:submersion/features/trips/data/side_trip_sql.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart' as domain;

/// Reads the side-trip links between trips (issue #3658), by the rule of
/// `side_trip_sql.dart`, limited to the trips [diverId] can see when one is
/// given: a parent the profile cannot see is no parent for it.
class SideTripRepository {
  AppDatabase get _db => DatabaseService.instance.database;

  /// Fires when any trip row, hide or share changes.
  Stream<void> watchChanges() => _db.tableUpdates(
    TableUpdateQuery.allOf([
      TableUpdateQuery.onTable(_db.trips),
      TableUpdateQuery.onTable(_db.tripHides),
      TableUpdateQuery.onTable(_db.tripShares),
    ]),
  );

  /// [tripId]'s valid side trips, earliest first.
  Future<List<domain.Trip>> getSideTrips(
    String tripId, {
    String? diverId,
  }) async {
    final rows = await _visibleTrips(
      sideTripIdsSql('?'),
      tripId,
      diverId,
      orderBy: 'ORDER BY t.start_date ASC',
    );
    return rows.map(tripFromData).toList();
  }

  /// The larger trip [tripId] is a side trip of, or null.
  Future<domain.Trip?> getParentTrip(String tripId, {String? diverId}) async {
    final rows = await _visibleTrips(validParentIdSql('?'), tripId, diverId);
    return rows.isEmpty ? null : tripFromData(rows.single);
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
