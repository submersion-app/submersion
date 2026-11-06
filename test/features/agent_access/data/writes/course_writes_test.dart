import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart' hide Dive;
import 'package:submersion/core/services/sync/sync_coordinator.dart';
import 'package:submersion/features/agent_access/data/writes/writable_entity.dart';

import '../../../../helpers/test_database.dart';
import 'child_write_harness.dart';

/// Training courses and their requirements, as the course pages keep them.
void main() {
  late AppDatabase db;
  late ChildWriteHarness h;

  Future<String> make(String entity, Map<String, Object?> values) async =>
      (await h.run([createOp(entity, values)])).created.single.id;

  Future<String> course([String name = 'Rescue']) =>
      make('courses', {'name': name, 'start_date': '2024-03-01'});

  Map<String, Object?> link(String relation, List<String> add) => {
    'op': 'update',
    'relations': {
      relation: {'add': add},
    },
  };

  Future<String> requirement(String courseId, String kind) => make(
    'course_requirements',
    {'course_id': courseId, 'name': 'Req', 'kind': kind},
  );

  setUp(() async {
    db = await setUpTestDatabase();
    addTearDown(SyncCoordinator.reset);
    h = ChildWriteHarness(db);
    await h.seed();
  });
  tearDown(() => tearDownTestDatabase());

  test(
    'a course is created, edited and deleted with its reach listed',
    () async {
      final plan = await h.preview([
        createOp('courses', {
          'name': ' AOW ',
          'start_date': '2024-03-01',
          'from_template': 'advanced-open-water',
        }),
      ]);
      final create = plan.items.single;
      expect(create.fields['agency']!.newValue, 'padi');
      expect(create.alsoCreates, {'course_requirements': 4});
      final id = (await h.apply(plan)).created.single.id;
      expect((await h.one('courses', id))!['name'], 'AOW');

      await h.run([
        {
          ...updateOp('courses', id, {
            'location': ' Reef Shop ',
            'completion_date': '2024-03-04',
          }),
          ...link('dive_ids', ['d1']),
        },
      ]);
      final edited = (await h.one('courses', id))!;
      expect(
        [edited['location'], edited['completion_date']],
        ['Reef Shop', '2024-03-04'],
      );

      final again = await h.preview([
        updateOp('courses', id, {'from_template': 'rescue-diver'}),
      ]);
      expect(again.items.single.block!.reason, BlockReason.duplicateRecord);

      final drop = await h.preview([deleteOp('courses', id)]);
      final reach = drop.items.single.reach;
      expect(reach.parts['course_requirements'], 4);
      expect(drop.items.single.alsoChanges, {'dives': 1});
      await h.apply(drop);
      expect(await h.one('courses', id), isNull);
    },
  );

  test('completion before start is refused', () async {
    final id = await course();
    final plan = await h.preview([
      updateOp('courses', id, {'completion_date': '2024-02-01'}),
      createOp('courses', {
        'name': 'X',
        'start_date': '2024-03-01',
        'agency': 'nobody',
      }),
      createOp('courses', {'start_date': '2024-03-01'}),
    ]);

    expect(plan.items[0].block!.reason, BlockReason.invalidValue);
    expect(plan.items[1].block!.reason, BlockReason.invalidValue);
    expect(plan.items[2].block!.reason, BlockReason.missingField);
  });

  test('a requirement is added, credited a dive and ticked', () async {
    final id = await course();
    final dives = await requirement(id, 'dive');
    final tick = await requirement(id, 'checklist');

    await h.run([
      {
        ...updateOp('course_requirements', dives, {'target_count': 2}),
        ...link('dive_ids', ['d1']),
      },
      updateOp('course_requirements', tick, {
        'completed_at': '2024-03-02T10:00:00Z',
      }),
    ]);
    final credited = await db.select(db.courseRequirementDives).get();
    expect(
      [for (final l in credited) (l.requirementId, l.diveId)],
      [(dives, 'd1')],
    );
    expect(
      (await h.one('course_requirements', tick))!['completed_at'],
      isNotNull,
    );

    final plan = await h.preview([
      updateOp('course_requirements', tick, {'kind': 'dive'}),
    ]);
    final cleared = plan.items.single.fields['completed_at']!;
    expect([cleared.newValue, cleared.indirect], [null, true]);
    final count = await h.preview([
      updateOp('course_requirements', tick, {'target_count': 3}),
    ]);
    expect(count.items.single.block!.reason, BlockReason.invalidValue);

    await h.run([deleteOp('course_requirements', dives)]);
    expect(await h.one('course_requirements', dives), isNull);
  });

  test('a dive credits one requirement per course', () async {
    final id = await course();
    final first = await requirement(id, 'dive');
    final second = await requirement(id, 'dive');
    await h.run([
      {
        ...updateOp('course_requirements', first, {}),
        ...link('dive_ids', ['d1']),
      },
    ]);

    final plan = await h.preview([
      {
        ...updateOp('course_requirements', second, {}),
        ...link('dive_ids', ['d1']),
      },
    ]);

    expect(plan.items.single.block!.reason, BlockReason.duplicateRecord);
  });

  test('certifications moved off another course are listed', () async {
    final card = await make('certifications', {'level': 'rescue'});
    final first = await course('First');
    final second = await course('Second');
    await h.run([
      {
        ...updateOp('courses', first, {}),
        ...link('certification_ids', [card]),
      },
    ]);

    final plan = await h.preview([
      {
        ...updateOp('courses', second, {}),
        ...link('certification_ids', [card]),
      },
    ]);
    expect(plan.items.single.alsoChanges, {'courses': 1});
    await h.apply(plan);

    expect((await h.one('courses', second))!['certification_id'], card);
    expect((await h.one('courses', first))!['certification_id'], isNull);
  });
}
