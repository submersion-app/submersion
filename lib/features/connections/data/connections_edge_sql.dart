import 'package:submersion/features/connections/domain/entities/connection_kind.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';
import 'package:submersion/features/connections/data/connections_membership_sql.dart';
import 'package:submersion/features/connections/data/connections_scope_sql.dart';

/// The co-occurrence query: one row per pair of entities that share at least
/// [minShared] dives in scope, with the distinct dive count and the first and
/// last shared dive time (epoch ms).
///
/// - [restrictA] / [restrictB] limit either side to these ids; an empty list
///   matches nothing.
/// - [excludeB] drops these ids from side B (entities already placed).
/// - A same-kind pair is undirected (`a < b`) unless only side A is
///   restricted: then the rows are spokes from side A, and only self pairs
///   are dropped (`b <> a`).
({String sql, List<Object?> params}) buildEdgeSql({
  required ConnectionKind kindA,
  required ConnectionKind kindB,
  required String? diverId,
  required DiveFilterState filter,
  Iterable<String>? restrictA,
  Iterable<String>? restrictB,
  Iterable<String>? excludeB,
  int minShared = 1,
}) {
  final extraWhere = <String>[];
  final extraParams = <Object?>[];
  void restrict(String column, Iterable<String>? ids) {
    if (ids == null) return;
    final list = ids.toList();
    if (list.isEmpty) {
      extraWhere.add('0 = 1');
      return;
    }
    extraWhere.add('$column IN (${placeholders(list.length)})');
    extraParams.addAll(list);
  }

  restrict('a.entity_id', restrictA);
  restrict('b.entity_id', restrictB);
  final excluded = excludeB?.toList() ?? const <String>[];
  if (excluded.isNotEmpty) {
    extraWhere.add('b.entity_id NOT IN (${placeholders(excluded.length)})');
    extraParams.addAll(excluded);
  }
  if (kindA == kindB) {
    final spokes = restrictA != null && restrictB == null;
    extraWhere.add(
      spokes ? 'b.entity_id <> a.entity_id' : 'a.entity_id < b.entity_id',
    );
  }
  final having = minShared > 1 ? '\nHAVING COUNT(DISTINCT d.id) >= ?' : '';
  // The scope is built beside the SQL that embeds it, so the census sees
  // both in one chunk.
  final scope = diveScopeSql(diverId: diverId, filter: filter);
  final where = [...scope.clauses, ...extraWhere];
  final params = [
    ...scope.params,
    ...extraParams,
    if (minShared > 1) minShared,
  ];
  final sql =
      '''
SELECT a.entity_id AS source, b.entity_id AS target,
       COUNT(DISTINCT d.id) AS weight,
       MIN(d.dive_date_time) AS first_ms,
       MAX(d.dive_date_time) AS last_ms
FROM dives d
JOIN (${membershipSql(kindA)}) a ON a.dive_id = d.id
JOIN (${membershipSql(kindB)}) b ON b.dive_id = d.id
WHERE ${where.join(' AND ')}
GROUP BY a.entity_id, b.entity_id$having
ORDER BY weight DESC, source ASC, target ASC''';
  return (sql: sql, params: params);
}
