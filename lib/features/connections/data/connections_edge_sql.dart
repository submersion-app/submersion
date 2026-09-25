import 'package:submersion/features/connections/domain/entities/connection_kind.dart';
import 'package:submersion/features/connections/domain/entities/node_ref.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';

import 'connections_membership_sql.dart';
import 'connections_scope_sql.dart';

/// The co-occurrence query: one row per pair of entities that share at least
/// one dive in scope, with the distinct dive count and the first and last
/// shared dive time (epoch ms).
///
/// - `kindA == kindB` without a focus: undirected, `a.entity_id < b.entity_id`.
/// - With [focus]: side a is pinned to the focus id and, for a self-join,
///   side b excludes it, so the rows are the focus node's spokes.
/// - [restrictTo]: both ends limited to these ids (the chords among a focus
///   node's neighbours). An empty list yields a query that matches nothing.
({String sql, List<Object?> params}) buildEdgeSql({
  required ConnectionKind kindA,
  required ConnectionKind kindB,
  required String? diverId,
  required DiveFilterState filter,
  NodeRef? focus,
  Iterable<String>? restrictTo,
}) {
  final extraWhere = <String>[];
  final extraParams = <Object?>[];
  if (focus != null) {
    extraWhere.add('a.entity_id = ?');
    extraParams.add(focus.id);
    if (kindA == kindB) extraWhere.add('b.entity_id <> a.entity_id');
  } else if (kindA == kindB) {
    extraWhere.add('a.entity_id < b.entity_id');
  }
  if (restrictTo != null) {
    final ids = restrictTo.toList();
    if (ids.isEmpty) {
      extraWhere.add('0 = 1');
    } else {
      final ph = placeholders(ids.length);
      extraWhere.add('a.entity_id IN ($ph)');
      extraParams.addAll(ids);
      extraWhere.add('b.entity_id IN ($ph)');
      extraParams.addAll(ids);
    }
  }
  // The scope is built beside the SQL that embeds it, so the census sees
  // both in one chunk.
  final scope = diveScopeSql(diverId: diverId, filter: filter);
  final where = [...scope.clauses, ...extraWhere];
  final params = [...scope.params, ...extraParams];
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
GROUP BY a.entity_id, b.entity_id
ORDER BY weight DESC, source ASC, target ASC''';
  return (sql: sql, params: params);
}
