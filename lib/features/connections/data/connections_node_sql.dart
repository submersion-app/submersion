import 'package:submersion/features/connections/domain/entities/connection_kind.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';

import 'package:submersion/features/connections/data/connections_membership_sql.dart';
import 'package:submersion/features/connections/data/connections_scope_sql.dart';

/// Where a kind's label and subtitle columns live.
class KindTable {
  const KindTable(this.table, this.labelColumn, [this.extraColumns = const []]);
  final String table;
  final String labelColumn;
  final List<String> extraColumns;
}

KindTable kindTable(ConnectionKind kind) => switch (kind) {
  ConnectionKind.buddy => const KindTable('buddies', 'name', ['photo']),
  ConnectionKind.site => const KindTable('dive_sites', 'name', [
    'region',
    'country',
  ]),
  ConnectionKind.trip => const KindTable('trips', 'name', [
    'start_date',
    'end_date',
  ]),
  ConnectionKind.diveCenter => const KindTable('dive_centers', 'name', [
    'country',
  ]),
  ConnectionKind.equipment => const KindTable('equipment', 'name', ['type']),
  ConnectionKind.species => const KindTable('species', 'common_name', [
    'scientific_name',
  ]),
  ConnectionKind.tag => const KindTable('tags', 'name', ['color']),
  ConnectionKind.diveType => const KindTable('dive_types', 'name'),
  ConnectionKind.diveComputer => const KindTable('dive_computers', 'name', [
    'manufacturer',
    'model',
  ]),
  ConnectionKind.course => const KindTable('courses', 'name'),
};

/// Every entity of [kind] with at least one dive in scope, with its own
/// distinct dive count and the columns its subtitle needs.
({String sql, List<Object?> params}) buildNodeSql({
  required ConnectionKind kind,
  required String? diverId,
  required DiveFilterState filter,
  Iterable<String>? onlyIds,
  String? labelLike,
  int? limit,
}) {
  final extraWhere = <String>[];
  final extraParams = <Object?>[];
  if (onlyIds != null) {
    final ids = onlyIds.toList();
    if (ids.isEmpty) {
      extraWhere.add('0 = 1');
    } else {
      extraWhere.add('m.entity_id IN (${placeholders(ids.length)})');
      extraParams.addAll(ids);
    }
  }
  // The scope is built beside the SQL that embeds it, so the census sees
  // both in one chunk.
  final scope = diveScopeSql(diverId: diverId, filter: filter);
  final where = [...scope.clauses, ...extraWhere];
  final params = [...scope.params, ...extraParams];
  final t = kindTable(kind);
  final extra = t.extraColumns.map((c) => ', t.$c AS $c').join();
  final outerWhere = labelLike == null
      ? ''
      : "\nWHERE t.${t.labelColumn} LIKE ? ESCAPE '\\'";
  final limitClause = limit == null ? '' : '\nLIMIT ?';
  final sql =
      '''
SELECT t.id AS id, t.${t.labelColumn} AS label$extra, c.dive_count AS dive_count
FROM (
  SELECT m.entity_id, COUNT(DISTINCT d.id) AS dive_count
  FROM (${membershipSql(kind)}) m
  JOIN dives d ON d.id = m.dive_id
  WHERE ${where.join(' AND ')}
  GROUP BY m.entity_id
) c
JOIN ${t.table} t ON t.id = c.entity_id$outerWhere
ORDER BY c.dive_count DESC, label ASC$limitClause''';
  return (sql: sql, params: [...params, ?labelLike, ?limit]);
}

/// One row per buddy in [buddyIds] whose dives in scope all carry the same
/// role: `id`, `role`.
({String sql, List<Object?> params}) buildBuddyRoleSql({
  required String? diverId,
  required DiveFilterState filter,
  required Iterable<String> buddyIds,
}) {
  final scope = diveScopeSql(diverId: diverId, filter: filter);
  final ids = buddyIds.toList();
  final where = [
    ...scope.clauses,
    'db.buddy_id IN (${placeholders(ids.length)})',
  ];
  final sql =
      '''
SELECT db.buddy_id AS id, MIN(db.role) AS role
FROM dive_buddies db
JOIN dives d ON d.id = db.dive_id
WHERE ${where.join(' AND ')}
GROUP BY db.buddy_id
HAVING COUNT(DISTINCT db.role) = 1''';
  return (sql: sql, params: [...scope.params, ...ids]);
}
