import 'package:drift/drift.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/database/dive_stats_scope.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/util/wall_clock_utc.dart';
import 'package:submersion/core/utils/stream_debounce.dart';
import 'package:submersion/features/connections/data/connections_around_loader.dart';
import 'package:submersion/features/connections/data/connections_map_loader.dart';
import 'package:submersion/features/connections/data/connections_membership_sql.dart';
import 'package:submersion/features/connections/data/connections_reader.dart';
import 'package:submersion/features/connections/data/connections_scope_sql.dart';
import 'package:submersion/features/connections/domain/entities/connection_graph.dart';
import 'package:submersion/features/connections/domain/entities/connection_kind.dart';
import 'package:submersion/features/connections/domain/entities/connection_node.dart';
import 'package:submersion/features/connections/domain/entities/graph_selection.dart';
import 'package:submersion/features/connections/domain/entities/node_ref.dart';
import 'package:submersion/features/connections/domain/views/map_spec.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';

export 'package:submersion/features/connections/data/connections_reader.dart'
    show FocusNotFoundException;

/// Reads connection graphs. Every aggregate over `dives` goes through
/// [DiveStatsScope] via [diveScopeSql]; the diver's view filter is applied
/// only when an axis is active.
class ConnectionsRepository {
  AppDatabase get _db => DatabaseService.instance.database;

  Future<ConnectionGraph> loadMap(
    MapSpec spec, {
    required String? diverId,
    DiveFilterState filter = const DiveFilterState(),
    int nodeBudget = 80,
  }) {
    return _db.transaction(() async {
      return MapLoader(
        ConnectionsReader(_db),
      ).load(spec, diverId: diverId, filter: filter, nodeBudget: nodeBudget);
    });
  }

  Future<ConnectionGraph> loadAround({
    required NodeRef focus,
    required Set<ConnectionKind> kinds,
    required int hops,
    required String? diverId,
    DiveFilterState filter = const DiveFilterState(),
    int nodeBudget = 80,
  }) {
    return _db.transaction(() async {
      final graph = await AroundLoader(ConnectionsReader(_db)).load(
        focus: focus,
        kinds: kinds,
        hops: hops.clamp(1, 3),
        diverId: diverId,
        filter: filter,
        nodeBudget: nodeBudget,
      );
      return graph;
    });
  }

  /// The entities [refs] name, with their dive counts for [diverId]; an
  /// entity without a dive in scope is left out. Used for search hits found
  /// by a translated name rather than the stored one.
  Future<List<ConnectionNode>> nodesFor(
    Iterable<NodeRef> refs, {
    required String? diverId,
  }) async {
    final byKind = <ConnectionKind, Set<String>>{};
    for (final r in refs) {
      byKind.putIfAbsent(r.kind, () => {}).add(r.id);
    }
    final reader = ConnectionsReader(_db);
    return [
      for (final entry in byKind.entries)
        ...await reader.nodes(
          entry.key,
          diverId: diverId,
          filter: const DiveFilterState(),
          onlyIds: entry.value,
        ),
    ];
  }

  /// Entities of every kind whose label contains [text], limited to those
  /// with at least one dive in scope for [diverId], busiest first.
  Future<List<ConnectionNode>> searchEntities(
    String text, {
    required String? diverId,
    int perKind = 5,
    int limit = 20,
  }) async {
    final needle = text.trim();
    if (needle.isEmpty) return const [];
    final reader = ConnectionsReader(_db);
    final pattern = '%${escapeLike(needle)}%';
    final hits = <ConnectionNode>[
      for (final kind in ConnectionKind.values)
        ...await reader.nodes(
          kind,
          diverId: diverId,
          filter: const DiveFilterState(),
          labelLike: pattern,
          limit: perKind,
        ),
    ];
    hits.sort((a, b) {
      final byDives = b.diveCount.compareTo(a.diveCount);
      return byDives != 0 ? byDives : a.label.compareTo(b.label);
    });
    return hits.take(limit).toList();
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
    return (
      first: wallClockUtcFromMillis(first).year,
      last: wallClockUtcFromMillis(last).year,
    );
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
          // A buddy's role subtitle reads the role sets (#1221).
          TableUpdateQuery.onTable(_db.diveDiverRoles),
          TableUpdateQuery.onTable(_db.diveBuddyRoles),
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
}
