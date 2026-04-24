import 'package:drift/drift.dart';

import 'package:submersion/core/database/database.dart';

/// Applies the owner-or-shared visibility predicate to queries on tables
/// that have a nullable `diver_id` and an `is_shared` column (trips,
/// dive_sites). When `diverId` is `null`, every entry point is a no-op so
/// existing "all divers / unfiltered" call sites keep working unchanged.
class VisibilityFilter {
  const VisibilityFilter._();

  /// Applies `(diver_id = diverId OR is_shared = true)` to a Drift select
  /// on the `trips` table.
  static void applyToTrips(
    SimpleSelectStatement<$TripsTable, Trip> query,
    String? diverId,
  ) {
    if (diverId == null) return;
    query.where((t) => t.diverId.equals(diverId) | t.isShared.equals(true));
  }

  /// Applies `(diver_id = diverId OR is_shared = true)` to a Drift select
  /// on the `dive_sites` table.
  static void applyToDiveSites(
    SimpleSelectStatement<$DiveSitesTable, DiveSite> query,
    String? diverId,
  ) {
    if (diverId == null) return;
    query.where((t) => t.diverId.equals(diverId) | t.isShared.equals(true));
  }

  /// Returns a SQL fragment and its variables for raw-SQL composition.
  ///
  /// * `tableAlias` qualifies the column names (e.g. `"t"` in
  ///   `FROM trips t`, or `"trips"` when the table is unaliased).
  /// * `conjunction` is `"AND"` when other WHERE clauses precede this
  ///   fragment, or `"WHERE"` when this is the first predicate.
  ///
  /// When `diverId` is `null`, the fragment is empty (no text, no vars),
  /// so callers can concatenate unconditionally.
  static SqlFragment sqlFragment({
    required String tableAlias,
    required String? diverId,
    required String conjunction,
  }) {
    if (diverId == null) {
      return const SqlFragment(whereClause: '', variables: []);
    }
    final clause =
        ' $conjunction ($tableAlias.diver_id = ? OR $tableAlias.is_shared = 1)';
    return SqlFragment(
      whereClause: clause,
      variables: [Variable.withString(diverId)],
    );
  }
}

/// A WHERE-fragment plus its variables, returned by
/// [VisibilityFilter.sqlFragment].
class SqlFragment {
  final String whereClause;
  final List<Variable<Object>> variables;

  const SqlFragment({required this.whereClause, required this.variables});

  bool get isEmpty => whereClause.isEmpty;
}
