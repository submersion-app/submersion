import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/connections/data/connections_map_loader.dart';
import 'package:submersion/features/connections/data/connections_reader.dart';
import 'package:submersion/features/connections/data/repositories/connections_repository.dart';
import 'package:submersion/features/connections/domain/entities/connection_graph.dart';
import 'package:submersion/features/connections/domain/entities/connection_kind.dart';
import 'package:submersion/features/connections/domain/entities/graph_selection.dart';
import 'package:submersion/features/connections/domain/entities/node_ref.dart';
import 'package:submersion/features/connections/domain/views/kind_link.dart';
import 'package:submersion/features/connections/domain/views/map_spec.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';

import '../../../helpers/test_database.dart';
import 'connections_loader_fixtures.dart';

final _buddyMap = MapSpec.of(
  {ConnectionKind.buddy},
  {KindLink(ConnectionKind.buddy, ConnectionKind.buddy)},
);

final _whereMap = MapSpec.of(
  {ConnectionKind.buddy, ConnectionKind.site},
  {KindLink(ConnectionKind.buddy, ConnectionKind.site)},
);

const _sitesNeedABuddy = {ConnectionKind.site: ConnectionKind.buddy};

Future<ConnectionGraph> _loadWhere(
  ConnectionsReader reader, {
  Map<ConnectionKind, ConnectionKind> sharedWith = const {},
  int budget = 80,
}) => MapLoader(reader).load(
  _whereMap,
  diverId: 'me',
  filter: const DiveFilterState(),
  nodeBudget: budget,
  sharedWith: sharedWith,
);

Future<ConnectionGraph> _load(ConnectionsReader reader, int budget) =>
    MapLoader(reader).load(
      _buddyMap,
      diverId: 'me',
      filter: const DiveFilterState(),
      nodeBudget: budget,
    );

void main() {
  setUp(setUpTestDatabase);
  tearDown(tearDownTestDatabase);

  test('edge queries run only among the entities the budget keeps', () async {
    final d = DatabaseService.instance.database;
    await seedStar(d, (i) => i, 10);
    final spy = SpyReader(d);
    final g = await _load(spy, 4);
    expect(g.nodes, hasLength(4));
    expect(g.hiddenNodeCount, 7, reason: '11 buddies, 4 shown');
    expect(spy.edgeCalls, isNotEmpty);
    for (final (a, b) in spy.edgeCalls) {
      expect(a, isNotNull, reason: 'no whole-log edge query');
      expect(b, isNotNull, reason: 'no whole-log edge query');
      expect(a, lessThanOrEqualTo(8));
      expect(b, lessThanOrEqualTo(8));
    }
  });

  test('the kept set matches trimming the whole map', () async {
    final d = DatabaseService.instance.database;
    await seedStar(d, (i) => i, 10);
    final reader = ConnectionsReader(d);
    final whole = await _load(reader, 1000);
    final expected = whole.trimmed(4).nodes.map((n) => n.ref).toSet();
    final shown = (await _load(reader, 4)).nodes.map((n) => n.ref).toSet();
    expect(shown, expected);
  });

  test('node reads stop at twice the budget per kind', () async {
    final d = DatabaseService.instance.database;
    await seedStar(d, (i) => i, 30);
    final spy = SpyReader(d);
    final g = await _load(spy, 4);
    for (final rows in spy.nodeRowCounts) {
      expect(rows, lessThanOrEqualTo(8), reason: 'no whole-log node read');
    }
    expect(g.nodes, hasLength(4));
    expect(g.hiddenNodeCount, 27, reason: '31 buddies, 4 shown');
    expect(g.hiddenByKind[ConnectionKind.buddy], 27);
  });

  test('a capped read keeps the same set when ties fill the cap', () async {
    final d = DatabaseService.instance.database;
    // Every buddy shares one dive with f: one tie class larger than the cap.
    await seedStar(d, (_) => 1, 20);
    final reader = ConnectionsReader(d);
    final whole = await _load(reader, 1000);
    final shown = await _load(reader, 4);
    expect(
      shown.nodes.map((n) => n.ref).toSet(),
      whole.trimmed(4).nodes.map((n) => n.ref).toSet(),
    );
    expect(shown.hiddenNodeCount, 17, reason: '21 buddies, 4 shown');
  });

  group('sharedWith', () {
    test(
      'keeps only sites dived with a buddy, counting all their dives',
      () async {
        final d = DatabaseService.instance.database;
        await seedSites(d);
        final g = await _loadWhere(
          ConnectionsReader(d),
          sharedWith: _sitesNeedABuddy,
        );
        expect(g.nodes.map((n) => n.ref.id).toSet(), {'b', 's1', 's2'});
        final s1 = g.nodes.firstWhere((n) => n.ref.id == 's1');
        // The count must match what Show dives lists for the site.
        final ids = await ConnectionsRepository().diveIdsFor(
          const NodeSelection(NodeRef(ConnectionKind.site, 's1')),
          diverId: 'me',
          filter: const DiveFilterState(),
        );
        expect(s1.diveCount, 2);
        expect(ids, hasLength(s1.diveCount));
        expect(g.edges, hasLength(2));
        expect(g.hiddenNodeCount, 0);
      },
    );

    test('without it the solo site stays as an island', () async {
      final d = DatabaseService.instance.database;
      await seedSites(d);
      final g = await _loadWhere(ConnectionsReader(d));
      expect(g.nodes.map((n) => n.ref.id), contains('s3'));
      expect(g.nodes.firstWhere((n) => n.ref.id == 's1').diveCount, 2);
    });

    test('a log with no buddies gives an empty map', () async {
      final d = DatabaseService.instance.database;
      await seedSites(d, withBuddy: false);
      final g = await _loadWhere(
        ConnectionsReader(d),
        sharedWith: _sitesNeedABuddy,
      );
      expect(g.isEmpty, isTrue);
    });

    test('the hidden count counts only shared sites', () async {
      final d = DatabaseService.instance.database;
      await seedSites(d);
      final reader = ConnectionsReader(d);
      expect(
        await reader.nodeCount(
          ConnectionKind.site,
          diverId: 'me',
          filter: const DiveFilterState(),
          sharedWith: ConnectionKind.buddy,
        ),
        2,
      );
      final g = await _loadWhere(
        reader,
        sharedWith: _sitesNeedABuddy,
        budget: 1,
      );
      expect(g.nodes.length + g.hiddenNodeCount, 3);
    });
  });
}
