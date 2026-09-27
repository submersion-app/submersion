import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/connections/data/connections_map_loader.dart';
import 'package:submersion/features/connections/data/connections_reader.dart';
import 'package:submersion/features/connections/domain/entities/connection_graph.dart';
import 'package:submersion/features/connections/domain/entities/connection_kind.dart';
import 'package:submersion/features/connections/domain/views/kind_link.dart';
import 'package:submersion/features/connections/domain/views/map_spec.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';

import '../../../helpers/test_database.dart';
import 'connections_loader_fixtures.dart';

final _buddyMap = MapSpec.of(
  {ConnectionKind.buddy},
  {KindLink(ConnectionKind.buddy, ConnectionKind.buddy)},
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
}
