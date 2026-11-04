import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart' hide Dive;
import 'package:submersion/core/services/sync/sync_coordinator.dart';
import 'package:submersion/features/agent_access/data/writes/families/tank_writes.dart';
import 'package:submersion/features/agent_access/data/writes/writable_entity.dart';
import 'package:submersion/features/agent_access/data/writes/write_catalog.dart';

import '../../../../helpers/test_database.dart';
import 'child_write_harness.dart';

/// A tank writer that records what the applier tells it after a commit,
/// says it touches its dive on a create and a delete, and fills a volume a
/// create leaves out.
class _Probe extends TankWrites {
  final batches = <List<AppliedChange>>[];

  List<AppliedChange> get seen => [for (final b in batches) ...b];

  @override
  Future<void> afterApply(List<AppliedChange> changes, ApplyRun run) async =>
      batches.add(changes);

  @override
  Future<Map<String, Object?>> createDefaults(
    String diverId,
    Map<String, Object?> values,
  ) async => {'volume_l': 10.0, 'not_a_field': 1};

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

  test('one set reaches each writer once, with all its changes', () async {
    await h.run([
      createOp('dive_tanks', {'dive_id': 'd1'}),
      createOp('dive_tanks', {'dive_id': 'd1'}),
    ]);

    expect([for (final b in probe.batches) b.length], [2]);
  });

  // The plan lists what the save fills in, and the apply writes what it lists.
  test('a value a create fills in is listed and written', () async {
    final plan = await h.preview([
      createOp('dive_tanks', {'dive_id': 'd1'}),
    ]);
    expect(plan.items.single.fields.containsKey('not_a_field'), isFalse);
    final volume = plan.items.single.fields['volume_l']!;
    expect([volume.newValue, volume.indirect], [10.0, true]);

    final id = (await h.apply(plan)).created.single.id;
    expect((await h.one('dive_tanks', id))!['volume_l'], 10.0);

    final named = await h.preview([
      createOp('dive_tanks', {'dive_id': 'd1', 'volume_l': 12.0}),
    ]);
    expect(named.items.single.fields['volume_l']!.newValue, 12.0);
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
