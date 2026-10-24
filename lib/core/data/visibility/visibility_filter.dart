import 'package:drift/drift.dart';

import 'package:submersion/core/data/visibility/shared_item_policy.dart';
import 'package:submersion/core/database/database.dart';

/// Applies owner-or-shared visibility predicates: an `is_shared` flag on
/// trips and dive_sites (nullable `diver_id`) or a share row naming the
/// profile (`trip_shares` / `site_shares`, issue #2151), minus the ones the
/// profile has hidden from itself (`trip_hides` / `site_hides`, issue #2594),
/// and
/// per-profile share rows for equipment (issue #2046). When `diverId` is
/// `null`, every entry point is a no-op so existing "all divers /
/// unfiltered" call sites keep working unchanged.
class VisibilityFilter {
  const VisibilityFilter._();

  /// Applies `(diver_id = diverId OR is_shared = true OR id IN (trips
  /// shared with diverId)) AND id NOT IN (diverId's hidden trips)` to a
  /// Drift select on the `trips` table (issues #2594, #2151).
  static void applyToTrips(
    AppDatabase db,
    SimpleSelectStatement<$TripsTable, Trip> query,
    String? diverId,
  ) {
    if (diverId == null) return;
    final hides = db.tripHides;
    final shares = db.tripShares;
    query.where(
      (t) =>
          (t.diverId.equals(diverId) |
              t.isShared.equals(true) |
              t.id.isInQuery(
                db.selectOnly(shares)
                  ..addColumns([shares.tripId])
                  ..where(shares.diverId.equals(diverId)),
              )) &
          t.id.isNotInQuery(
            db.selectOnly(hides)
              ..addColumns([hides.tripId])
              ..where(hides.diverId.equals(diverId)),
          ),
    );
  }

  /// As [applyToTrips], on the `dive_sites` table.
  static void applyToDiveSites(
    AppDatabase db,
    SimpleSelectStatement<$DiveSitesTable, DiveSite> query,
    String? diverId,
  ) {
    if (diverId == null) return;
    final hides = db.siteHides;
    final shares = db.siteShares;
    final memberships = db.sharedLibraryMemberships;
    query.where(
      (t) =>
          (t.diverId.equals(diverId) |
              t.isShared.equals(true) |
              // A share row counts only for a personal site: a shared site
              // library site follows its membership (issue #2151).
              (t.sharedLibraryId.isNull() &
                  t.id.isInQuery(
                    db.selectOnly(shares)
                      ..addColumns([shares.siteId])
                      ..where(shares.diverId.equals(diverId)),
                  )) |
              // A shared site library's sites, for its members (issue #2567).
              t.sharedLibraryId.isInQuery(
                db.selectOnly(memberships)
                  ..addColumns([memberships.libraryId])
                  ..where(memberships.diverId.equals(diverId)),
              )) &
          t.id.isNotInQuery(
            db.selectOnly(hides)
              ..addColumns([hides.siteId])
              ..where(hides.diverId.equals(diverId)),
          ),
    );
  }

  /// Owner-or-shared predicate for `equipment` (issue #2046): an item is
  /// visible to [diverId] when [diverId] owns it or holds an
  /// `equipment_shares` row for it. Unlike trips and sites there is no
  /// all-profiles flag; sharing is per profile. No-op for a null [diverId].
  static void applyToEquipment(
    AppDatabase db,
    SimpleSelectStatement<$EquipmentTable, EquipmentData> query,
    String? diverId,
  ) {
    if (diverId == null) return;
    query.where((t) => equipmentVisibleTo(db, t, diverId)!);
  }

  /// The [applyToEquipment] predicate over [equipment], for queries that are
  /// not a plain select on the table (a join through `equipment`). Null for a
  /// null [diverId], so the caller adds nothing.
  static Expression<bool>? equipmentVisibleTo(
    AppDatabase db,
    $EquipmentTable equipment,
    String? diverId,
  ) {
    if (diverId == null) return null;
    final shares = db.equipmentShares;
    return equipment.diverId.equals(diverId) |
        equipment.id.isInQuery(
          db.selectOnly(shares)
            ..addColumns([shares.equipmentId])
            ..where(shares.diverId.equals(diverId)),
        );
  }

  /// [applyToEquipment] for raw SQL: `$conjunction (alias.diver_id = ? OR
  /// alias.id IN (items shared with ?))`. Empty for a null [diverId].
  static SqlFragment equipmentSqlFragment({
    required String tableAlias,
    required String? diverId,
    required String conjunction,
  }) {
    if (diverId == null) {
      return const SqlFragment(whereClause: '', variables: []);
    }
    return SqlFragment(
      whereClause:
          ' $conjunction ($tableAlias.diver_id = ? OR $tableAlias.id IN '
          '(SELECT equipment_id FROM equipment_shares WHERE diver_id = ?))',
      variables: [Variable.withString(diverId), Variable.withString(diverId)],
    );
  }

  /// The owner-or-shared half of [sqlFragment] for `trips`, with the viewer
  /// named by any SQL expression [viewer]: `?`, or a column such as a hide's
  /// `h.diver_id` (issue #2678). Shared means with everyone or by a share
  /// row naming the viewer (issue #2151). [viewer] appears twice, so a `?`
  /// placeholder needs two variables. Parenthesised, with no conjunction.
  static String ownerOrSharedSql(String tableAlias, String viewer) =>
      '($tableAlias.diver_id = $viewer OR $tableAlias.is_shared = 1 OR '
      '$tableAlias.id IN (SELECT trip_id FROM trip_shares WHERE '
      'diver_id = $viewer))';

  /// [ownerOrSharedSql] for `dive_sites`, which a shared site library's members
  /// also see (issue #2567); a share row counts only for a personal site. [viewer] appears three times, so a `?`
  /// placeholder needs three variables.
  static String ownerOrSharedOrLibrarySql(String tableAlias, String viewer) =>
      '($tableAlias.diver_id = $viewer OR $tableAlias.is_shared = 1 OR '
      '($tableAlias.shared_library_id IS NULL AND $tableAlias.id IN '
      '(SELECT site_id FROM site_shares WHERE diver_id = $viewer)) OR '
      '$tableAlias.shared_library_id IN (SELECT library_id FROM '
      'shared_library_memberships WHERE diver_id = $viewer))';

  /// Returns a SQL fragment and its variables for raw-SQL composition:
  /// owner-or-shared, minus the items [diverId] has hidden (issue #2594).
  ///
  /// * `tableAlias` qualifies the column names (e.g. `"t"` in
  ///   `FROM trips t`, or `"trips"` when the table is unaliased).
  /// * `conjunction` is `"AND"` when other WHERE clauses precede this
  ///   fragment, or `"WHERE"` when this is the first predicate.
  /// * `kind` names the hides table to exclude.
  ///
  /// When `diverId` is `null`, the fragment is empty (no text, no vars),
  /// so callers can concatenate unconditionally.
  static SqlFragment sqlFragment({
    required String tableAlias,
    required String? diverId,
    required String conjunction,
    required SharedItemKind kind,
  }) {
    if (diverId == null) {
      return const SqlFragment(whereClause: '', variables: []);
    }
    final (hides, column) = switch (kind) {
      SharedItemKind.trip => ('trip_hides', 'trip_id'),
      SharedItemKind.site => ('site_hides', 'site_id'),
    };
    final visible = switch (kind) {
      SharedItemKind.trip => ownerOrSharedSql(tableAlias, '?'),
      SharedItemKind.site => ownerOrSharedOrLibrarySql(tableAlias, '?'),
    };
    final clause =
        ' $conjunction $visible'
        ' AND $tableAlias.id NOT IN '
        '(SELECT $column FROM $hides WHERE diver_id = ?)';
    return SqlFragment(
      whereClause: clause,
      variables: [
        // The visible half names the viewer twice for a trip (owner, share
        // row) and three times for a site (and library); the hides once.
        Variable.withString(diverId),
        Variable.withString(diverId),
        if (kind == SharedItemKind.site) Variable.withString(diverId),
        Variable.withString(diverId),
      ],
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
