import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart' hide Dive;
import 'package:submersion/core/services/sync/sync_coordinator.dart';
import 'package:submersion/features/agent_access/data/writes/writable_entity.dart';

import '../../../../helpers/test_database.dart';
import 'child_write_harness.dart';

/// Saved queries and saved connection maps, as the query bar and the
/// connections page save them.
void main() {
  late AppDatabase db;
  late ChildWriteHarness h;

  const reef = {
    'version': 1,
    'node': {
      't': 'text',
      'words': ['reef'],
    },
  };

  Future<String> make(String entity, Map<String, Object?> values) async =>
      (await h.run([createOp(entity, values)])).created.single.id;

  setUp(() async {
    db = await setUpTestDatabase();
    addTearDown(SyncCoordinator.reset);
    h = ChildWriteHarness(db);
    await h.seed();
  });
  tearDown(() => tearDownTestDatabase());

  test('a saved query is created, renamed, edited and deleted', () async {
    final id = await make('saved_queries', {
      'subject': 'dives',
      'name': ' Reef ',
      'query': reef,
    });
    final saved = (await h.one('saved_queries', id))!;
    expect([saved['name'], saved['query']], ['Reef', reef]);

    await h.run([
      updateOp('saved_queries', id, {
        'name': 'Reefs',
        'query': {
          'version': 1,
          'node': {
            't': 'text',
            'words': ['wall'],
          },
        },
      }),
    ]);
    expect((await h.one('saved_queries', id))!['name'], 'Reefs');

    await h.run([deleteOp('saved_queries', id)]);
    expect(await h.one('saved_queries', id), isNull);
  });

  test('a saved query that does not validate is refused', () async {
    final plan = await h.preview([
      createOp('saved_queries', {
        'subject': 'dives',
        'name': 'Bad',
        'query': {
          'version': 1,
          'node': {
            't': 'cond',
            'path': ['nothing_here'],
            'op': 'eq',
            'value': {'k': 'num', 'v': 1},
          },
        },
      }),
      createOp('saved_queries', {
        'subject': 'nowhere',
        'name': 'Bad',
        'query': reef,
      }),
    ]);

    for (final item in plan.items) {
      expect(item.block!.reason, BlockReason.invalidValue);
    }
  });

  test('a connection map\'s spec is clamped, listed', () async {
    final plan = await h.preview([
      createOp('connection_maps', {
        'name': 'Buddies',
        'spec': {
          'kinds': ['buddy'],
          'links': ['buddy-site'],
          'min': 50,
        },
      }),
    ]);
    final spec = plan.items.single.fields['spec']!.newValue! as Map;
    expect([spec['min'], spec['links']], [10, <String>[]]);
    final id = (await h.apply(plan)).created.single.id;

    await h.run([
      updateOp('connection_maps', id, {'name': 'Crew'}),
    ]);
    expect((await h.one('connection_maps', id))!['name'], 'Crew');

    final bad = await h.preview([
      createOp('connection_maps', {
        'name': 'Bad',
        'spec': {
          'kinds': ['dragons'],
          'links': <String>[],
        },
      }),
    ]);
    expect(bad.items.single.block!.reason, BlockReason.invalidValue);
  });
}
