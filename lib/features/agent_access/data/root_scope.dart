import 'package:submersion/core/data/visibility/shared_item_policy.dart';
import 'package:submersion/core/data/visibility/visibility_filter.dart';
import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/core/query/registry/query_entity.dart';
import 'package:submersion/features/query/data/query_id_set_runner.dart';

/// The WHERE fragment that limits a query root to what [diverId] may see.
///
/// Dives, buddies, centers, certifications and courses belong to one diver.
/// Sites, trips and equipment are owner-or-shared, minus the items the diver
/// hid, exactly as the app's own lists filter them. Species are shared by
/// everyone and get no scope.
QueryScope? rootScopeFor(
  QueryEntity root,
  String diverId, {
  String alias = 'r0',
}) {
  switch (root.subject) {
    case QuerySubject.species:
      return null;
    case QuerySubject.sites:
      return _fromFragment(
        VisibilityFilter.sqlFragment(
          tableAlias: alias,
          diverId: diverId,
          conjunction: '',
          kind: SharedItemKind.site,
        ),
      );
    case QuerySubject.trips:
      return _fromFragment(
        VisibilityFilter.sqlFragment(
          tableAlias: alias,
          diverId: diverId,
          conjunction: '',
          kind: SharedItemKind.trip,
        ),
      );
    case QuerySubject.equipment:
      return _fromFragment(
        VisibilityFilter.equipmentSqlFragment(
          tableAlias: alias,
          diverId: diverId,
          conjunction: '',
        ),
      );
    default:
      final column = root.diverScopeColumn;
      if (column == null) return null;
      return (sql: '$alias.$column = ?', params: [diverId]);
  }
}

/// Adapts a [SqlFragment] (leading conjunction, Drift variables) to the
/// runner's [QueryScope] (bare predicate, raw parameters).
QueryScope _fromFragment(SqlFragment fragment) {
  return (
    sql: fragment.whereClause.trim(),
    params: [for (final v in fragment.variables) v.value as Object],
  );
}
