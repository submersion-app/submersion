import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart' hide Dive;
import 'package:submersion/core/services/sync/sync_coordinator.dart';
import 'package:submersion/features/agent_access/data/writes/families/tank_writes.dart';
import 'package:submersion/features/agent_access/data/writes/writable_entity.dart';
import 'package:submersion/features/agent_access/data/writes/write_catalog.dart';

import '../../../../helpers/test_database.dart';
import 'child_write_harness.dart';

/// A tank writer that records what the applier tells it after a commit, and
/// says it touches its dive on a create and a delete.
class _Probe extends TankWrites {
  final seen = <AppliedChange>[];

  @override
  Future<void> afterApply(AppliedChange change) async => seen.add(change);

  @override
  Future<Map<String, int>> createTouched(
    String diverId,
    Map<String, Object?> values,
  ) async => {'dives': 1};

  @override
  Future<DeleteReach> deleteReach(
    String id, {
    Map<String, Set<String>> alongside = const {},
  }) async => const DeleteReach(touched: {'dives': 1});
}

/// The hooks every change gets: work after the commit, and the rows of other
/// records a create or a delete rewrites, listed as an update's are.
void main() {
  late AppDatabase db;
  late ChildWriteHarness h;
  late _Probe probe;

  setUp(() async {
    db = await setUpTestDatabase();
    addTearDown(SyncCoordinator.reset);
    probe = _Probe();
    h = ChildWriteHarness(
      db,
      catalog: (repositories) => WriteCatalog.of([
        for (final entry in WriteCatalog(repositories).all)
          entry.name == 'dive_tanks' ? probe : entry,
      ]),
    );
    await h.seed();
  });
  tearDown(() => tearDownTestDatabase());

  test('a create, an update and a delete each run after the commit', () async {
    final created = (await h.run([
      createOp('dive_tanks', {'dive_id': 'd1'}),
    ])).created.single.id;
    await h.run([
      updateOp('dive_tanks', created, {'volume_l': 12.0}),
    ]);
    await h.run([deleteOp('dive_tanks', created)]);

    expect(
      [for (final c in probe.seen) (c.kind, c.id, c.parentId)],
      [
        (ChangeKind.create, created, 'd1'),
        (ChangeKind.update, created, 'd1'),
        (ChangeKind.delete, created, 'd1'),
      ],
    );
    expect(probe.seen[0].changed, contains('dive_id'));
    expect(probe.seen[1].changed, {'volume_l'});
    expect(probe.seen[2].changed, isEmpty);
  });

  test('a create and a delete list the rows they touch', () async {
    final create = await h.preview([
      createOp('dive_tanks', {'dive_id': 'd1'}),
    ]);
    expect(create.items.single.alsoChanges, {'dives': 1});
    final id = (await h.apply(create)).created.single.id;

    final delete = await h.preview([deleteOp('dive_tanks', id)]);
    expect(delete.items.single.alsoChanges, {'dives': 1});
  });
}
