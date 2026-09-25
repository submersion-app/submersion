import 'dart:typed_data';

import 'package:drift/drift.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/database/dive_stats_scope.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/utils/stream_debounce.dart';
import 'package:submersion/features/connections/data/connections_edge_sql.dart';
import 'package:submersion/features/connections/data/connections_membership_sql.dart';
import 'package:submersion/features/connections/data/connections_node_sql.dart';
import 'package:submersion/features/connections/data/connections_scope_sql.dart';
import 'package:submersion/features/connections/domain/entities/connection_edge.dart';
import 'package:submersion/features/connections/domain/entities/connection_graph.dart';
import 'package:submersion/features/connections/domain/entities/connection_kind.dart';
import 'package:submersion/features/connections/domain/entities/connection_node.dart';
import 'package:submersion/features/connections/domain/entities/connection_query.dart';
import 'package:submersion/features/connections/domain/entities/graph_selection.dart';
import 'package:submersion/features/connections/domain/entities/node_ref.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';

/// The focus of an ego query has no row in its label table.
class FocusNotFoundException implements Exception {
  const FocusNotFoundException(this.ref);
  final NodeRef ref;
  @override
  String toString() => 'FocusNotFoundException($ref)';
}

/// Reads connection graphs. Every aggregate over `dives` goes through
/// [DiveStatsScope] via [diveScopeSql]; the diver's view filter is applied
/// only when an axis is active.
class ConnectionsRepository {
  AppDatabase get _db => DatabaseService.instance.database;

  Future<ConnectionGraph> loadGraph(
    ConnectionQuery query, {
    required String? diverId,
  }) async {
    if (!query.focusIsValid) {
      throw ArgumentError.value(
        query.focus,
        'focus',
        'focus kind is not part of this query',
      );
    }
    final focus = query.focus;
    final graph = focus == null
        ? await _wholeWeb(query, diverId)
        : await _ego(query, focus, diverId);
    return graph.trimmed(query.nodeBudget, keep: focus);
  }

  Future<ConnectionGraph> _wholeWeb(ConnectionQuery q, String? diverId) async {
    final edges = await _edges(q.kindA, q.kindB, diverId, q.filter);
    final nodes = <ConnectionNode>[
      for (final kind in {q.kindA, q.kindB})
        ...await _nodes(kind, diverId, q.filter),
    ];
    return ConnectionGraph(nodes: nodes, edges: edges);
  }

  Future<ConnectionGraph> _ego(
    ConnectionQuery q,
    NodeRef focus,
    String? diverId,
  ) async {
    final other = q.neighbourKind!;
    final spokes = await _edges(
      focus.kind,
      other,
      diverId,
      q.filter,
      focus: focus,
    );
    final neighbourIds = spokes.map((e) => e.target.id).toSet();
    var focusNodes = await _nodes(
      focus.kind,
      diverId,
      q.filter,
      onlyIds: {focus.id},
    );
    if (focusNodes.isEmpty) {
      focusNodes = [await _labelOnly(focus)];
    }
    final neighbours = neighbourIds.isEmpty
        ? const <ConnectionNode>[]
        : await _nodes(other, diverId, q.filter, onlyIds: neighbourIds);
    var edges = spokes;
    if (q.isSelfJoin && neighbourIds.length > 1) {
      final chords = await _edges(
        other,
        other,
        diverId,
        q.filter,
        restrictTo: neighbourIds,
      );
      edges = [...spokes, ...chords];
    }
    return ConnectionGraph(nodes: [...focusNodes, ...neighbours], edges: edges);
  }

  Future<List<ConnectionEdge>> _edges(
    ConnectionKind kindA,
    ConnectionKind kindB,
    String? diverId,
    DiveFilterState filter, {
    NodeRef? focus,
    Iterable<String>? restrictTo,
  }) async {
    final q = buildEdgeSql(
      kindA: kindA,
      kindB: kindB,
      diverId: diverId,
      filter: filter,
      focus: focus,
      restrictTo: restrictTo,
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

  Future<List<ConnectionNode>> _nodes(
    ConnectionKind kind,
    String? diverId,
    DiveFilterState filter, {
    Iterable<String>? onlyIds,
  }) async {
    final q = buildNodeSql(
      kind: kind,
      diverId: diverId,
      filter: filter,
      onlyIds: onlyIds,
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

  /// The focus node when it has no dive in scope: label only, zero dives.
  Future<ConnectionNode> _labelOnly(NodeRef ref) async {
    final t = kindTable(ref.kind);
    final rows = await _db
        .customSelect(
          'SELECT ${t.labelColumn} AS label FROM ${t.table} WHERE id = ?',
          variables: [Variable(ref.id)],
        )
        .get();
    if (rows.isEmpty) throw FocusNotFoundException(ref);
    return ConnectionNode(
      ref: ref,
      label: rows.single.read<String>('label'),
      diveCount: 0,
    );
  }

  /// First and last calendar year of the dives in scope, or null when there
  /// are none. Drives the year slider.
  Future<({int first, int last})?> diveYearSpan({
    required String? diverId,
  }) async {
    final scope = diveScopeSql(
      diverId: diverId,
      filter: const DiveFilterState(),
    );
    final rows = await _db
        .customSelect(
          'SELECT MIN(d.dive_date_time) AS first_ms, '
          'MAX(d.dive_date_time) AS last_ms FROM dives d '
          'WHERE ${scope.clauses.join(' AND ')}',
          variables: scope.params.map(Variable.new).toList(),
        )
        .get();
    final first = rows.single.readNullable<int>('first_ms');
    final last = rows.single.readNullable<int>('last_ms');
    if (first == null || last == null) return null;
    return (first: _ms(first).year, last: _ms(last).year);
  }

  /// The dive ids behind a selected node or edge, newest first, under the
  /// same scope and filter as the graph.
  Future<List<String>> diveIdsFor(
    GraphSelection selection, {
    required String? diverId,
    required DiveFilterState filter,
  }) async {
    final scope = diveScopeSql(diverId: diverId, filter: filter);
    final String sql;
    final List<Object?> params;
    switch (selection) {
      case NodeSelection(:final ref):
        sql =
            'SELECT DISTINCT d.id AS id, d.dive_date_time FROM dives d '
            'JOIN (${membershipSql(ref.kind)}) m ON m.dive_id = d.id '
            'WHERE ${[...scope.clauses, 'm.entity_id = ?'].join(' AND ')} '
            'ORDER BY d.dive_date_time DESC';
        params = [...scope.params, ref.id];
      case EdgeSelection(:final a, :final b):
        sql =
            'SELECT DISTINCT d.id AS id, d.dive_date_time FROM dives d '
            'JOIN (${membershipSql(a.kind)}) ma ON ma.dive_id = d.id '
            'JOIN (${membershipSql(b.kind)}) mb ON mb.dive_id = d.id '
            'WHERE ${[...scope.clauses, 'ma.entity_id = ?', 'mb.entity_id = ?'].join(' AND ')} '
            'ORDER BY d.dive_date_time DESC';
        params = [...scope.params, a.id, b.id];
    }
    final rows = await _db
        .customSelect(sql, variables: params.map(Variable.new).toList())
        .get();
    return [for (final r in rows) r.read<String>('id')];
  }

  /// Debounced tick over every table a graph reads: dives, each junction
  /// table, and each label table.
  Stream<void> watchConnectionsChanges() => _db
      .tableUpdates(
        TableUpdateQuery.allOf([
          TableUpdateQuery.onTable(_db.dives),
          TableUpdateQuery.onTable(_db.diveBuddies),
          TableUpdateQuery.onTable(_db.buddies),
          TableUpdateQuery.onTable(_db.diveEquipment),
          TableUpdateQuery.onTable(_db.equipment),
          TableUpdateQuery.onTable(_db.sightings),
          TableUpdateQuery.onTable(_db.species),
          TableUpdateQuery.onTable(_db.diveTags),
          TableUpdateQuery.onTable(_db.tags),
          TableUpdateQuery.onTable(_db.diveDiveTypes),
          TableUpdateQuery.onTable(_db.diveTypes),
          TableUpdateQuery.onTable(_db.diveDataSources),
          TableUpdateQuery.onTable(_db.diveComputers),
          TableUpdateQuery.onTable(_db.diveSites),
          TableUpdateQuery.onTable(_db.trips),
          TableUpdateQuery.onTable(_db.diveCenters),
          TableUpdateQuery.onTable(_db.courses),
        ]),
      )
      .debounce(DiveRepository.changeTickDebounce);

  static DateTime _ms(int ms) =>
      DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
}
