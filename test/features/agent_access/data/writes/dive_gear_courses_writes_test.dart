import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart' hide Dive;
import 'package:submersion/core/services/sync/sync_coordinator.dart';
import 'package:submersion/features/agent_access/data/writes/writable_entity.dart';
import 'package:submersion/features/agent_access/domain/agent_tool_error.dart';

import '../../../../helpers/test_database.dart';
import '../records/record_harness.dart';
import 'child_write_harness.dart';

/// Equipment and courses are links on a dive, written as the bulk editor
/// writes them: an assembly brings its active parts, and an item taken off
/// takes what is attached through it.
void main() {
  late AppDatabase db;
  late ChildWriteHarness h;

  Future<void> item(String id, {String owner = kDiverA, bool active = true}) =>
      db
          .into(db.equipment)
          .insert(
            EquipmentCompanion.insert(
              id: id,
              name: 'Gear $id',
              type: 'regulator',
              createdAt: kSeedTime,
              updatedAt: kSeedTime,
              diverId: Value(owner),
              isActive: Value(active),
            ),
          );

  Future<void> part(String parent, String child) => db
      .into(db.equipmentComponents)
      .insert(
        EquipmentComponentsCompanion.insert(
          id: '$parent-$child',
          parentEquipmentId: parent,
          componentEquipmentId: child,
          createdAt: kSeedTime,
          updatedAt: kSeedTime,
        ),
      );

  Future<void> course(String id, {String owner = kDiverA}) => db
      .into(db.courses)
      .insert(
        CoursesCompanion.insert(
          id: id,
          diverId: owner,
          name: 'Course $id',
          agency: 'padi',
          startDate: kSeedTime,
          createdAt: kSeedTime,
          updatedAt: kSeedTime,
        ),
      );

  Map<String, Object?> link(String relation, Map<String, Object?> change) => {
    'op': 'update',
    'entity': 'dives',
    'id': 'd1',
    'relations': {relation: change},
  };

  Future<Set<String>> gear() async => {
    for (final row in await (db.select(
      db.diveEquipment,
    )..where((r) => r.diveId.equals('d1'))).get())
      row.equipmentId,
  };

  setUp(() async {
    db = await setUpTestDatabase();
    addTearDown(SyncCoordinator.reset);
    h = ChildWriteHarness(db);
    await h.seed();
    // An assembly with an active part and a retired one.
    await item('rig');
    await item('first-stage');
    await item('old-hose', active: false);
    await part('rig', 'first-stage');
    await part('rig', 'old-hose');
  });
  tearDown(() => tearDownTestDatabase());

  test('an assembly lists the parts it brings, and brings them', () async {
    final change = link('gear', {
      'add': ['rig'],
    });
    final plan = await h.preview([change]);

    final item = plan.items.single;
    expect(item.relations['gear']!.add, {'rig'});
    expect(item.indirectRelations['gear'], {'first-stage'});
    expect(item.names['first-stage'], 'Gear first-stage');

    await h.apply(plan);

    expect(await gear(), {'rig', 'first-stage'});
  });

  test('an item taken off lists what goes with it', () async {
    await h.run([
      link('gear', {
        'add': ['rig'],
      }),
    ]);

    final plan = await h.preview([
      link('gear', {
        'remove': ['rig'],
      }),
    ]);

    expect(plan.items.single.indirectLost['gear'], {'first-stage'});
    expect(plan.items.single.toJson()['indirect_relations'], {
      'gear': {
        'remove': ['first-stage'],
      },
    });
    await h.apply(plan);
    expect(await gear(), isEmpty);
  });

  test('a part added to the assembly after the preview is stale', () async {
    final plan = await h.preview([
      link('gear', {
        'add': ['rig'],
      }),
    ]);
    await item('second-stage');
    await part('rig', 'second-stage');

    await expectLater(
      h.apply(plan),
      throwsA(
        isA<AgentToolException>().having(
          (e) => e.code,
          'code',
          AgentToolErrorCode.planStale,
        ),
      ),
    );
  });

  test('gear of another profile is blocked', () async {
    await item('theirs', owner: kDiverB);

    final plan = await h.preview([
      link('gear', {
        'add': ['theirs'],
      }),
    ]);

    expect(plan.items.single.block!.reason, BlockReason.otherProfileReference);
  });

  test('courses are added and removed', () async {
    await course('c1');
    await course('c2');

    await h.run([
      link('courses', {
        'add': ['c1', 'c2'],
      }),
    ]);
    expect(
      (await h.one('dives', 'd1'))!['course_ids'],
      unorderedEquals(['c1', 'c2']),
    );

    await h.run([
      link('courses', {
        'set': ['c2'],
      }),
    ]);
    expect((await h.one('dives', 'd1'))!['course_ids'], ['c2']);
    expect(h.refreshed.last, {'d1'});
  });

  test('a course of another profile is blocked', () async {
    await course('theirs', owner: kDiverB);

    final plan = await h.preview([
      link('courses', {
        'add': ['theirs'],
      }),
    ]);

    expect(plan.items.single.block!.reason, BlockReason.otherProfileReference);
  });
}
