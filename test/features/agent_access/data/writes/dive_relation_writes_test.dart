import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart' hide Dive;
import 'package:submersion/core/services/sync/sync_coordinator.dart';
import 'package:submersion/features/agent_access/data/writes/writable_entity.dart';
import 'package:submersion/features/buddies/data/repositories/buddy_repository.dart';

import '../../../../helpers/test_database.dart';
import 'child_write_harness.dart';

/// A dive's buddies with their roles, and the trip it is on, as the dive
/// edit page saves them.
void main() {
  late AppDatabase db;
  late ChildWriteHarness h;

  Future<String> make(String entity, Map<String, Object?> values) async =>
      (await h.run([createOp(entity, values)])).created.single.id;

  Map<String, Object?> relate(String id, String relation, List<String> add) => {
    ...updateOp('dives', id, {}),
    'relations': {
      relation: {'add': add},
    },
  };

  setUp(() async {
    db = await setUpTestDatabase();
    addTearDown(SyncCoordinator.reset);
    h = ChildWriteHarness(db);
    await h.seed();
  });
  tearDown(() => tearDownTestDatabase());

  test('a dive\'s buddies are set with roles', () async {
    final rui = await make('buddies', {'name': 'Rui'});
    final ana = await make('buddies', {'name': 'Ana'});

    await h.run([
      updateOp('dives', 'd1', {
        'buddy_roles': {
          rui: ['instructor'],
          ana: <String>[],
        },
      }),
    ]);
    final on = {
      for (final b in await BuddyRepository().getBuddiesForDive('d1'))
        b.buddy.id: [for (final r in b.roles) r.id],
    };
    expect(on, {
      rui: ['instructor'],
      ana: ['buddy'],
    });

    final same = await h.preview([
      updateOp('dives', 'd1', {
        'buddy_roles': {
          ana: ['buddy'],
          rui: ['instructor'],
        },
      }),
    ]);
    expect(same.unchanged.single.id, 'd1');

    final refused = await h.preview([
      updateOp('dives', 'd1', {
        'buddy_roles': {
          rui: ['nobody'],
        },
      }),
    ]);
    expect(refused.items.single.block!.reason, BlockReason.unknownReference);
  });

  test('moving a dive to a trip stretches the trip, listed', () async {
    final trip = await make('trips', {
      'name': 'Trip',
      'start_date': '2024-03-10',
      'end_date': '2024-03-12',
    });

    final plan = await h.preview([
      relate('d1', 'trip', [trip]),
    ]);
    expect(plan.items.single.alsoChanges, {'trips': 1});
    await h.apply(plan);

    final dive = (await h.one('dives', 'd1'))!;
    expect((dive['trip']! as Map)['id'], trip);
    expect((await h.one('trips', trip))!['end_date'], '2024-03-14');
  });
}
