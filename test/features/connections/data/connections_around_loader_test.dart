import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/connections/data/connections_around_loader.dart';
import 'package:submersion/features/connections/data/connections_reader.dart';
import 'package:submersion/features/connections/domain/entities/connection_graph.dart';
import 'package:submersion/features/connections/domain/entities/connection_kind.dart';
import 'package:submersion/features/connections/domain/entities/node_ref.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';

import '../../../helpers/test_database.dart';
import 'connections_loader_fixtures.dart';

const _focus = NodeRef(ConnectionKind.buddy, 'f');
NodeRef _b(String id) => NodeRef(ConnectionKind.buddy, id);

Future<ConnectionGraph> _load(
  ConnectionsReader reader, {
  required int budget,
  int hops = 1,
}) => AroundLoader(reader).load(
  focus: _focus,
  kinds: {ConnectionKind.buddy},
  hops: hops,
  diverId: 'me',
  filter: const DiveFilterState(),
  nodeBudget: budget,
);

void main() {
  setUp(setUpTestDatabase);
  tearDown(tearDownTestDatabase);

  test('chords run only among the entities the budget keeps', () async {
    final d = DatabaseService.instance.database;
    await seedStar(d, (i) => i, 10);
    final spy = SpyReader(d);
    final g = await _load(spy, budget: 4);
    expect(g.nodes, hasLength(4));
    expect(g.hiddenNodeCount, 7, reason: '11 discovered, 4 shown');
    expect(spy.restrictedCalls, isNotEmpty);
    for (final (a, b) in spy.restrictedCalls) {
      expect(a, lessThanOrEqualTo(4));
      expect(b, lessThanOrEqualTo(4));
    }
  });

  test('ties at the cutoff cannot widen the chord pass past twice the '
      'budget', () async {
    final d = DatabaseService.instance.database;
    // Every buddy shares exactly one dive with the focus: one tie class, the
    // common shape of hop-2 and hop-3 entities in a real log.
    await seedStar(d, (_) => 1, 20);
    final spy = SpyReader(d);
    final g = await _load(spy, budget: 4);
    expect(g.nodes, hasLength(4));
    expect(g.hiddenNodeCount, 17, reason: '21 discovered, 4 shown');
    for (final (a, b) in spy.restrictedCalls) {
      expect(a, lessThanOrEqualTo(8));
      expect(b, lessThanOrEqualTo(8));
    }
  });

  test('the kept set matches trimming the whole neighbourhood', () async {
    final d = DatabaseService.instance.database;
    await seedStar(d, (i) => i, 10);
    final reader = ConnectionsReader(d);
    final whole = await _load(reader, budget: 1000);
    final expected = whole
        .trimmed(4, keep: _focus)
        .nodes
        .map((n) => n.ref)
        .toSet();
    final shown = (await _load(
      reader,
      budget: 4,
    )).nodes.map((n) => n.ref).toSet();
    expect(shown, expected);
    expect(expected, containsAll([_focus, _b('b10')]));
  });

  test('three hops reach the end of a chain; two stop short', () async {
    final d = DatabaseService.instance.database;
    await seedChain(d);
    final reader = ConnectionsReader(d);
    final three = await _load(reader, budget: 80, hops: 3);
    expect(
      {for (final n in three.nodes) n.ref: n.hop},
      {_focus: 0, _b('c1'): 1, _b('c2'): 2, _b('c3'): 3},
    );
    expect(three.edges, hasLength(3));
    final two = await _load(reader, budget: 80, hops: 2);
    expect(two.nodes.map((n) => n.ref), isNot(contains(_b('c3'))));
  });
}
