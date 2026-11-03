import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart' hide Dive;
import 'package:submersion/core/services/sync/sync_coordinator.dart';
import 'package:submersion/features/agent_access/data/writes/writable_entity.dart';
import 'package:submersion/features/dive_log/data/repositories/annotation_repository.dart';

import '../../../../helpers/test_database.dart';
import 'child_write_harness.dart';

/// Annotations are the profile events a diver writes; their words live in
/// the dive's Notes.
void main() {
  late AppDatabase db;
  late ChildWriteHarness h;

  Future<String> notes() async => (await (db.select(
    db.dives,
  )..where((d) => d.id.equals('d1'))).getSingle()).notes;

  Future<DiveProfileEvent?> event(String id) => (db.select(
    db.diveProfileEvents,
  )..where((e) => e.id.equals(id))).getSingleOrNull();

  setUp(() async {
    db = await setUpTestDatabase();
    addTearDown(SyncCoordinator.reset);
    h = ChildWriteHarness(db);
    await h.seed();
    // A computer's ascent warning, which the app does not change.
    await db
        .into(db.diveProfileEvents)
        .insert(
          DiveProfileEventsCompanion.insert(
            id: 'warning',
            diveId: 'd1',
            timestamp: 300,
            eventType: 'ascentRateWarning',
            createdAt: 0,
          ),
        );
  });
  tearDown(() => tearDownTestDatabase());

  test('a new annotation links its words in the dive\'s Notes', () async {
    final result = await h.run([
      createOp('dive_events', {
        'dive_id': 'd1',
        't_s': 600,
        'depth_m': 18.0,
        'description': 'Turtle on the wreck',
      }),
    ]);

    final id = result.created.single.id;
    final row = (await event(id))!;
    expect(row.eventType, 'annotation');
    expect(row.timestamp, 600);
    expect(row.depth, 18.0);
    expect(await notes(), contains('(annotation:$id)'));
    expect(h.refreshed.single, {'d1'});
  });

  test('a move keeps the depth it does not name', () async {
    final id = await AnnotationRepository().addAnnotation(
      diveId: 'd1',
      timestamp: 600,
      depth: 18,
      words: 'Turtle',
    );

    await h.run([
      updateOp('dive_events', id, {'t_s': 660}),
    ]);

    final row = (await event(id))!;
    expect(row.timestamp, 660);
    expect(row.depth, 18.0);
  });

  test('a delete turns the link back into plain words', () async {
    final id = await AnnotationRepository().addAnnotation(
      diveId: 'd1',
      timestamp: 600,
      words: 'Turtle',
    );

    final result = await h.run([deleteOp('dive_events', id)]);

    expect(await event(id), isNull);
    expect(await notes(), contains('Turtle'));
    expect(await notes(), isNot(contains('annotation:')));

    await h.revert(result);
    expect(await event(id), isNotNull);
    expect(await notes(), contains('(annotation:$id)'));
  });

  test('an event a computer recorded is blocked', () async {
    final moved = await h.preview([
      updateOp('dive_events', 'warning', {'t_s': 320}),
    ]);
    final deleted = await h.preview([deleteOp('dive_events', 'warning')]);

    expect(moved.items.single.block!.reason, BlockReason.notPermitted);
    expect(deleted.items.single.block!.reason, BlockReason.notPermitted);
  });

  test('the words cannot change once written', () async {
    final id = await AnnotationRepository().addAnnotation(
      diveId: 'd1',
      timestamp: 600,
      words: 'Turtle',
    );

    final plan = await h.preview([
      updateOp('dive_events', id, {'description': 'Shark'}),
    ]);

    expect(plan.items.single.block!.reason, BlockReason.notPermitted);
  });

  test('a create beside an update of its dive is blocked', () async {
    final plan = await h.preview([
      updateOp('dives', 'd1', {'notes': 'Rewritten'}),
      createOp('dive_events', {
        'dive_id': 'd1',
        't_s': 600,
        'description': 'Turtle',
      }),
    ]);

    expect(plan.items.last.block!.reason, BlockReason.referenceChanged);
  });

  test('a create beside an update that leaves the Notes alone runs', () async {
    final plan = await h.preview([
      updateOp('dives', 'd1', {'boat_name': 'Marlin'}),
      createOp('dive_events', {
        'dive_id': 'd1',
        't_s': 600,
        'description': 'Turtle',
      }),
    ]);

    expect(plan.items.last.block, isNull);
    await h.apply(plan);
    expect(await notes(), contains('Turtle'));
  });
}
