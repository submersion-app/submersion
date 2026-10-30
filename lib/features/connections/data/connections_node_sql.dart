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

/// One step outward from a focus: the entities that share an in-scope dive
/// with [frontier], leaving out [exclude] (those already placed).
class NeighboursOf {
  const NeighboursOf(this.frontier, {this.exclude = const {}});

  final Map<ConnectionKind, Set<String>> frontier;
  final Set<String> exclude;
}

/// The WHERE term limiting `m.entity_id` of [kind] to [neighbours], with its
/// params. The frontier's dives are one union, so an entity reached from two
/// kinds is still one row and the scope binds once however many kinds it has.
({String sql, List<Object?> params}) _neighbourTerm(
  ConnectionKind kind,
  NeighboursOf neighbours, {
  required String? diverId,
  required DiveFilterState filter,
}) {
  final frontierDives = [
    for (final MapEntry(key: from, value: ids) in neighbours.frontier.entries)
      'SELECT dive_id FROM (${membershipSql(from)}) '
          'WHERE entity_id IN (${placeholders(ids.length)})',
  ];
  if (frontierDives.isEmpty) return (sql: '0 = 1', params: const []);
  // The scope is built beside the SQL that embeds it, so the census sees
  // both in one chunk.
  final scope = diveScopeSql(diverId: diverId, filter: filter);
  final where = [
    ...scope.clauses,
    if (neighbours.exclude.isNotEmpty)
      'nb.entity_id NOT IN (${placeholders(neighbours.exclude.length)})',
  ];
  final sql =
      'm.entity_id IN (SELECT nb.entity_id FROM dives d '
      'JOIN (${frontierDives.join(' UNION ')}) na ON na.dive_id = d.id '
      'JOIN (${membershipSql(kind)}) nb ON nb.dive_id = d.id '
      'WHERE ${where.join(' AND ')})';
  return (
    sql: sql,
    params: [
      for (final ids in neighbours.frontier.values) ...ids,
      ...scope.params,
      ...neighbours.exclude,
    ],
  );
}

/// Every entity of [kind] with at least one dive in scope, with its own
/// distinct dive count and the columns its subtitle needs. With
/// [sharedWith], an entity is kept only if one of its dives also has an
/// entity of that kind; every one of its dives still counts, so the count
/// matches the dives Show dives lists. With [neighboursOf], only those
/// entities; their dive counts still cover all their dives in scope.
///
/// Rows come by dive count, then label. With [byRank] they come by dive
/// count, then id: the order the node budget ranks in (see
/// nodesWithinBudget), so a [limit] cuts exactly the rows the budget would.
/// Unless [labelLike] has to filter first, that limit runs before the label
/// table is joined, because SQLite's sorter carries every selected column
/// and a buddy's photo would be read just to be cut.
({String sql, List<Object?> params}) buildNodeSql({
  required ConnectionKind kind,
  required String? diverId,
  required DiveFilterState filter,
  Iterable<String>? onlyIds,
  String? labelLike,
  int? limit,
  bool byRank = false,
  ConnectionKind? sharedWith,
  NeighboursOf? neighboursOf,
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
  if (neighboursOf != null) {
    final term = _neighbourTerm(
      kind,
      neighboursOf,
      diverId: diverId,
      filter: filter,
    );
    extraWhere.add(term.sql);
    extraParams.addAll(term.params);
  }
  final t = kindTable(kind);
  final cutFirst = byRank && limit != null && labelLike == null;
  if (cutFirst) {
    // The outer join to the label table can no longer drop a link to a
    // missing entity once the rows are cut, so it must not take a slot.
    extraWhere.add(
      'EXISTS (SELECT 1 FROM ${t.table} k WHERE k.id = m.entity_id)',
    );
  }
  // The scope is built beside the SQL that embeds it, so the census sees
  // both in one chunk.
  final scope = diveScopeSql(diverId: diverId, filter: filter);
  final where = [...scope.clauses, ...extraWhere];
  final params = [...scope.params, ...extraParams];
  final extra = t.extraColumns.map((c) => ', t.$c AS $c').join();
  final outerWhere = labelLike == null
      ? ''
      : "\nWHERE unicode_lower(t.${t.labelColumn}) LIKE ? ESCAPE '\\'";
  final innerCut = cutFirst
      ? '\n  ORDER BY dive_count DESC, m.entity_id ASC\n  LIMIT ?'
      : '';
  final limitClause = limit == null || cutFirst ? '' : '\nLIMIT ?';
  final sql =
      '''
SELECT t.id AS id, t.${t.labelColumn} AS label$extra, c.dive_count AS dive_count, c.first_ms AS first_ms
FROM (
  SELECT m.entity_id, COUNT(DISTINCT d.id) AS dive_count, MIN(d.dive_date_time) AS first_ms
  FROM (${membershipSql(kind)}) m
  JOIN dives d ON d.id = m.dive_id
  WHERE ${where.join(' AND ')}
  GROUP BY m.entity_id${sharedWithHaving(sharedWith)}$innerCut
) c
JOIN ${t.table} t ON t.id = c.entity_id$outerWhere
ORDER BY c.dive_count DESC, ${byRank ? 't.id' : 'label'} ASC$limitClause''';
  return (
    sql: sql,
    params: [...params, if (cutFirst) limit, ?labelLike, if (!cutFirst) ?limit],
  );
}

/// The HAVING clause, for a query grouped by `m.entity_id` over dives `d`,
/// keeping an entity only if one of its dives also has an entity of
/// [kind]; empty when [kind] is null.
String sharedWithHaving(ConnectionKind? kind) => kind == null
    ? ''
    : '\n  HAVING MAX(EXISTS (SELECT 1 FROM (${membershipSql(kind)}) sw '
          'WHERE sw.dive_id = d.id)) = 1';

/// How many entities of [kind] have at least one dive in scope: the row
/// count [buildNodeSql] would return with no limit.
({String sql, List<Object?> params}) buildNodeCountSql({
  required ConnectionKind kind,
  required String? diverId,
  required DiveFilterState filter,
  ConnectionKind? sharedWith,
  NeighboursOf? neighboursOf,
}) {
  final term = neighboursOf == null
      ? null
      : _neighbourTerm(kind, neighboursOf, diverId: diverId, filter: filter);
  final scope = diveScopeSql(diverId: diverId, filter: filter);
  final t = kindTable(kind);
  final sql =
      '''
SELECT COUNT(*) AS n
FROM (
  SELECT m.entity_id
  FROM (${membershipSql(kind)}) m
  JOIN dives d ON d.id = m.dive_id
  WHERE ${[...scope.clauses, ?term?.sql].join(' AND ')}
  GROUP BY m.entity_id${sharedWithHaving(sharedWith)}
) c
JOIN ${t.table} t ON t.id = c.entity_id''';
  return (sql: sql, params: [...scope.params, ...?term?.params]);
}

/// Every in-scope link of the buddies in [buddyIds]: `id` (the buddy),
/// `dive_id` and the link's primary `role`. The reader resolves each link's
/// whole role set and keeps a subtitle only for a buddy who holds one role
/// on every one of their dives (issue #1221).
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
  final sql = '''
SELECT db.buddy_id AS id, db.dive_id AS dive_id, db.role AS role
FROM dive_buddies db
JOIN dives d ON d.id = db.dive_id
WHERE ${where.join(' AND ')}''';
  return (sql: sql, params: [...scope.params, ...ids]);
}
