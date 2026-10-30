import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/connections/data/connections_around_loader.dart';
import 'package:submersion/features/connections/data/connections_budget.dart';
import 'package:submersion/features/connections/data/connections_reader.dart';
import 'package:submersion/features/connections/domain/entities/connection_edge.dart';
import 'package:submersion/features/connections/domain/entities/connection_graph.dart';
import 'package:submersion/features/connections/domain/entities/connection_kind.dart';
import 'package:submersion/features/connections/domain/entities/connection_node.dart';
import 'package:submersion/features/connections/domain/entities/node_ref.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';

import '../../../helpers/test_database.dart';
import 'connections_loader_fixtures.dart';

/// The around load as it was before reads were bounded (#3833): every
/// neighbour discovered through the edge query and every one hydrated, then
/// cut to the budget. The bounded loader must answer exactly as this does.
Future<ConnectionGraph> _unboundedAround(
  ConnectionsReader reader, {
  required NodeRef focus,
  required Set<ConnectionKind> kinds,
  required int hops,
  required String? diverId,
  required DiveFilterState filter,
  required int nodeBudget,
}) async {
  final enabled = kinds.toList()..sort((a, b) => a.index.compareTo(b.index));
  final placed = <ConnectionKind, Set<String>>{
    focus.kind: {focus.id},
  };
  final hopOf = <NodeRef, int>{focus: 0};
  var frontier = <ConnectionKind, Set<String>>{
    focus.kind: {focus.id},
  };
  bool budgetFull() =>
      nodeBudget > 0 &&
      placed.values.fold(0, (n, ids) => n + ids.length) >= nodeBudget;
  for (
    var hop = 1;
    hop <= hops && frontier.isNotEmpty && !budgetFull();
    hop++
  ) {
    final next = <ConnectionKind, Set<String>>{};
    for (final entry in frontier.entries) {
      for (final kind in enabled) {
        final found = await reader.edges(
          entry.key,
          kind,
          diverId: diverId,
          filter: filter,
          restrictA: entry.value,
          excludeB: placed[kind] ?? const <String>{},
        );
        for (final e in found) {
          if (hopOf.containsKey(e.target)) continue;
          hopOf[e.target] = hop;
          placed.putIfAbsent(kind, () => {}).add(e.target.id);
          next.putIfAbsent(kind, () => {}).add(e.target.id);
        }
      }
    }
    frontier = next;
  }

  final nodes = <ConnectionNode>[];
  final placedKinds = placed.keys.toList()
    ..sort((a, b) => a.index.compareTo(b.index));
  for (final kind in placedKinds) {
    final rows = await reader.nodes(
      kind,
      diverId: diverId,
      filter: filter,
      onlyIds: placed[kind],
    );
    nodes.addAll(rows.map((n) => n.copyWith(hop: hopOf[n.ref])));
  }
  if (!nodes.any((n) => n.ref == focus)) {
    nodes.insert(
      0,
      (await reader.labelOnly(focus, diverId: diverId)).copyWith(hop: 0),
    );
  }

  final kept = nodesWithinBudget(nodes, nodeBudget);
  final keptIds = idsByKind(kept);
  final keptKinds = keptIds.keys.toList()
    ..sort((a, b) => a.index.compareTo(b.index));
  final edges = <ConnectionEdge>[];
  for (var i = 0; i < keptKinds.length; i++) {
    for (var j = i; j < keptKinds.length; j++) {
      edges.addAll(
        await reader.edges(
          keptKinds[i],
          keptKinds[j],
          diverId: diverId,
          filter: filter,
          restrictA: keptIds[keptKinds[i]],
          restrictB: keptIds[keptKinds[j]],
        ),
      );
    }
  }
  final graph = ConnectionGraph(
    nodes: kept,
    edges: edges,
  ).trimmed(nodeBudget, keep: focus);
  final totals = <ConnectionKind, int>{};
  for (final n in nodes) {
    totals[n.ref.kind] = (totals[n.ref.kind] ?? 0) + 1;
  }
  return withDroppedCounts(graph, totals, kept);
}

void main() {
  setUp(setUpTestDatabase);
  tearDown(tearDownTestDatabase);

  const seeded = {
    ConnectionKind.buddy,
    ConnectionKind.site,
    ConnectionKind.equipment,
    ConnectionKind.species,
    ConnectionKind.tag,
  };
  const focuses = [
    NodeRef(ConnectionKind.buddy, 'b0'),
    NodeRef(ConnectionKind.equipment, 'e0'),
    NodeRef(ConnectionKind.site, 's0'),
    NodeRef(ConnectionKind.tag, 't0'),
    NodeRef(ConnectionKind.buddy, 'lonely'),
  ];
  final filters = <String, DiveFilterState>{
    'no filter': const DiveFilterState(),
    'one tag': const DiveFilterState(tagIds: ['t0']),
    'date range': DiveFilterState(
      startDate: DateTime.utc(2023, 12),
      endDate: DateTime.utc(2024, 2),
    ),
  };
  final kindSets = <Set<ConnectionKind>>[
    {ConnectionKind.buddy},
    {ConnectionKind.site, ConnectionKind.species},
    seeded,
    ConnectionKind.values.toSet(),
  ];

  for (final seed in [1, 2]) {
    test('the around load answers as an unbounded read (seed $seed)', () async {
      final d = DatabaseService.instance.database;
      await seedMixedLog(d, seed);
      final reader = ConnectionsReader(d);
      var compared = 0;
      for (final focus in focuses) {
        for (final kinds in kindSets) {
          for (final hops in [1, 2, 3]) {
            for (final budget in [1, 4, 12, 40]) {
              for (final MapEntry(key: name, value: filter)
                  in filters.entries) {
                for (final diverId in ['me', null]) {
                  final bounded = await AroundLoader(reader).load(
                    focus: focus,
                    kinds: kinds,
                    hops: hops,
                    diverId: diverId,
                    filter: filter,
                    nodeBudget: budget,
                  );
                  final unbounded = await _unboundedAround(
                    reader,
                    focus: focus,
                    kinds: kinds,
                    hops: hops,
                    diverId: diverId,
                    filter: filter,
                    nodeBudget: budget,
                  );
                  expect(
                    bounded,
                    unbounded,
                    reason:
                        '$focus, ${kinds.length} kinds, $hops hops, '
                        'budget $budget, $name, diver $diverId',
                  );
                  compared++;
                }
              }
            }
          }
        }
      }
      expect(compared, greaterThan(1000));
    }, timeout: const Timeout(Duration(minutes: 2)));
  }

  test('degree breaks a tie only among the nodes the tie cap kept', () async {
    final d = DatabaseService.instance.database;
    await seedTiedStar(d);
    final reader = ConnectionsReader(d);
    const focus = NodeRef(ConnectionKind.buddy, 'f');
    final bounded = await AroundLoader(reader).load(
      focus: focus,
      kinds: {ConnectionKind.buddy},
      hops: 1,
      diverId: 'me',
      filter: const DiveFilterState(),
      nodeBudget: 3,
    );
    final unbounded = await _unboundedAround(
      reader,
      focus: focus,
      kinds: {ConnectionKind.buddy},
      hops: 1,
      diverId: 'me',
      filter: const DiveFilterState(),
      nodeBudget: 3,
    );
    expect(bounded, unbounded);
    // b03 and b04 win on degree. b19 and b20 have the same degree, but sit
    // past twice the budget in id order, so neither read ever kept them.
    expect(bounded.nodes.map((n) => n.ref.id), ['f', 'b03', 'b04']);
    expect(bounded.hiddenNodeCount, 18);
  });

  test('pairs among one kind match the self-join', () async {
    final d = DatabaseService.instance.database;
    await seedMixedLog(d, 3);
    final reader = ConnectionsReader(d);
    const ids = {
      ConnectionKind.buddy: ['b0', 'b1', 'b2', 'b3', 'b4', 'b5', 'b6'],
      ConnectionKind.equipment: ['e0', 'e1', 'e2', 'e3', 'e4', 'e9', 'e10'],
      // Sighted twice on a dive, so a pair must still count that dive once.
      ConnectionKind.species: ['sp0', 'sp1', 'sp2', 'sp3', 'sp4', 'sp5'],
      ConnectionKind.tag: ['t0', 't1', 't2'],
    };
    for (final MapEntry(key: kind, value: list) in ids.entries) {
      for (final minShared in [1, 2, 5]) {
        for (final filter in filters.values) {
          final amongOne = await reader.edgesAmong(
            kind,
            list,
            diverId: 'me',
            filter: filter,
            minShared: minShared,
          );
          final selfJoin = await reader.edges(
            kind,
            kind,
            diverId: 'me',
            filter: filter,
            restrictA: list,
            restrictB: list,
            minShared: minShared,
          );
          expect(amongOne, selfJoin, reason: '$kind, at least $minShared');
        }
      }
    }
    expect(
      await reader.edgesAmong(
        ConnectionKind.equipment,
        ids[ConnectionKind.equipment]!,
        diverId: 'me',
        filter: const DiveFilterState(),
      ),
      isNotEmpty,
      reason: 'the comparison must not pass on empty results',
    );
  });
}
