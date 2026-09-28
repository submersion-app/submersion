import 'package:drift/drift.dart';
import 'package:submersion/features/connections/data/connections_edge_sql.dart';
import 'package:submersion/features/connections/data/connections_node_sql.dart';
import 'package:submersion/features/connections/domain/entities/connection_edge.dart';
import 'package:submersion/features/connections/domain/entities/connection_kind.dart';
import 'package:submersion/features/connections/domain/entities/connection_node.dart';
import 'package:submersion/features/connections/domain/entities/node_ref.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';

/// The focus of an around view has no row in its label table.
class FocusNotFoundException implements Exception {
  const FocusNotFoundException(this.ref);
  final NodeRef ref;
  @override
  String toString() => 'FocusNotFoundException($ref)';
}

/// Row-level reads shared by the map and around loaders. Every query comes
/// from the scoped builders, so this file writes no SQL over `dives`.
class ConnectionsReader {
  const ConnectionsReader(this._db);

  final DatabaseConnectionUser _db;

  Future<List<ConnectionEdge>> edges(
    ConnectionKind kindA,
    ConnectionKind kindB, {
    required String? diverId,
    required DiveFilterState filter,
    Iterable<String>? restrictA,
    Iterable<String>? restrictB,
    Iterable<String>? excludeB,
    int minShared = 1,
  }) async {
    final q = buildEdgeSql(
      kindA: kindA,
      kindB: kindB,
      diverId: diverId,
      filter: filter,
      restrictA: restrictA,
      restrictB: restrictB,
      excludeB: excludeB,
      minShared: minShared,
    );
    final rows = await _db
        .customSelect(q.sql, variables: q.params.map(Variable.new).toList())
        .get();
    return [
      for (final r in rows)
        ConnectionEdge(
          source: NodeRef(kindA, r.read<String>('source')),
          target: NodeRef(kindB, r.read<String>('target')),
          weight: r.read<int>('weight'),
          firstDiveAt: _ms(r.read<int>('first_ms')),
          lastDiveAt: _ms(r.read<int>('last_ms')),
        ),
    ];
  }

  Future<List<ConnectionNode>> nodes(
    ConnectionKind kind, {
    required String? diverId,
    required DiveFilterState filter,
    Iterable<String>? onlyIds,
    String? labelLike,
    int? limit,
    bool byRank = false,
  }) async {
    final q = buildNodeSql(
      kind: kind,
      diverId: diverId,
      filter: filter,
      onlyIds: onlyIds,
      labelLike: labelLike,
      limit: limit,
      byRank: byRank,
    );
    final rows = await _db
        .customSelect(q.sql, variables: q.params.map(Variable.new).toList())
        .get();
    final nodes = [
      for (final r in rows)
        ConnectionNode(
          ref: NodeRef(kind, r.read<String>('id')),
          label: r.read<String>('label'),
          diveCount: r.read<int>('dive_count'),
          subtitle: _subtitle(kind, r),
          photo: kind == ConnectionKind.buddy
              ? r.readNullable<Uint8List>('photo')
              : null,
        ),
    ];
    if (kind != ConnectionKind.buddy || nodes.isEmpty) return nodes;
    final roles = await _unanimousRoles(
      diverId,
      filter,
      nodes.map((n) => n.ref.id),
    );
    return [
      for (final n in nodes)
        roles.containsKey(n.ref.id)
            ? n.copyWith(subtitle: RoleSubtitle(roles[n.ref.id]!))
            : n,
    ];
  }

  /// How many entities of [kind] have a dive in scope.
  Future<int> nodeCount(
    ConnectionKind kind, {
    required String? diverId,
    required DiveFilterState filter,
  }) async {
    final q = buildNodeCountSql(kind: kind, diverId: diverId, filter: filter);
    final row = await _db
        .customSelect(q.sql, variables: q.params.map(Variable.new).toList())
        .getSingle();
    return row.read<int>('n');
  }

  /// The focus when it has no dive in scope: label only, zero dives.
  ///
  /// Reads only what [diverId] can see (their own entities, ownerless ones,
  /// gear shared with them, and the species catalogue), so a link to another
  /// profile's entity is not found rather than labelled. With no active
  /// diver everything is visible, as before profiles existed.
  Future<ConnectionNode> labelOnly(
    NodeRef ref, {
    required String? diverId,
  }) async {
    final t = kindTable(ref.kind);
    final visible = _visibleTo(ref.kind, t.table, diverId);
    final rows = await _db
        .customSelect(
          'SELECT ${t.labelColumn} AS label FROM ${t.table} '
          'WHERE id = ?${visible.sql}',
          variables: [Variable(ref.id), ...visible.params.map(Variable.new)],
        )
        .get();
    if (rows.isEmpty) throw FocusNotFoundException(ref);
    return ConnectionNode(
      ref: ref,
      label: rows.single.read<String>('label'),
      diveCount: 0,
    );
  }

  /// The `AND ...` clause limiting [table] to what [diverId] can see.
  static ({String sql, List<Object?> params}) _visibleTo(
    ConnectionKind kind,
    String table,
    String? diverId,
  ) {
    if (diverId == null || kind == ConnectionKind.species) {
      return (sql: '', params: const []);
    }
    if (kind == ConnectionKind.equipment) {
      return (
        sql:
            ' AND (diver_id IS NULL OR diver_id = ? OR EXISTS ('
            'SELECT 1 FROM equipment_shares s '
            'WHERE s.equipment_id = $table.id AND s.diver_id = ?))',
        params: [diverId, diverId],
      );
    }
    return (sql: ' AND (diver_id IS NULL OR diver_id = ?)', params: [diverId]);
  }

  Future<Map<String, String>> _unanimousRoles(
    String? diverId,
    DiveFilterState filter,
    Iterable<String> buddyIds,
  ) async {
    final q = buildBuddyRoleSql(
      diverId: diverId,
      filter: filter,
      buddyIds: buddyIds,
    );
    final rows = await _db
        .customSelect(q.sql, variables: q.params.map(Variable.new).toList())
        .get();
    return {for (final r in rows) r.read<String>('id'): r.read<String>('role')};
  }
}

NodeSubtitle? _subtitle(ConnectionKind kind, QueryRow r) {
  String? text(String column) {
    final v = r.readNullable<String>(column);
    return (v == null || v.trim().isEmpty) ? null : v.trim();
  }

  switch (kind) {
    case ConnectionKind.site:
      final parts = [text('region'), text('country')].nonNulls.toList();
      return parts.isEmpty ? null : TextSubtitle(parts.join(', '));
    case ConnectionKind.trip:
      return DateRangeSubtitle(
        _ms(r.read<int>('start_date')),
        _ms(r.read<int>('end_date')),
      );
    case ConnectionKind.diveCenter:
      final c = text('country');
      return c == null ? null : TextSubtitle(c);
    case ConnectionKind.equipment:
      final t = text('type');
      return t == null ? null : TextSubtitle(t);
    case ConnectionKind.species:
      final s = text('scientific_name');
      return s == null ? null : TextSubtitle(s);
    case ConnectionKind.diveComputer:
      final parts = [text('manufacturer'), text('model')].nonNulls.toList();
      return parts.isEmpty ? null : TextSubtitle(parts.join(' '));
    case ConnectionKind.buddy:
    case ConnectionKind.tag:
    case ConnectionKind.diveType:
    case ConnectionKind.course:
      return null;
  }
}

DateTime _ms(int ms) => DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
