import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart' hide Dive;
import 'package:submersion/core/services/sync/sync_coordinator.dart';
import 'package:submersion/features/dive_log/data/repositories/annotation_repository.dart';

import '../../../../helpers/test_database.dart';
import 'child_write_harness.dart';

/// An agent's Notes edit keeps annotations in step, as an editor save does.
void main() {
  late AppDatabase db;
  late ChildWriteHarness h;
  late String turtle;

  Future<DiveProfileEvent?> event(String id) => (db.select(
    db.diveProfileEvents,
  )..where((e) => e.id.equals(id))).getSingleOrNull();

  Future<String> notes() async => (await (db.select(
    db.dives,
  )..where((d) => d.id.equals('d1'))).getSingle()).notes;

  setUp(() async {
    db = await setUpTestDatabase();
    addTearDown(SyncCoordinator.reset);
    h = ChildWriteHarness(db);
    await h.seed();
    turtle = await AnnotationRepository().addAnnotation(
      diveId: 'd1',
      timestamp: 600,
      words: 'Turtle',
    );
  });
  tearDown(() => tearDownTestDatabase());

  test('Notes that drop a link delete its annotation, as planned', () async {
    final plan = await h.preview([
      updateOp('dives', 'd1', {'notes': 'Nothing pinned now.'}),
    ]);

    expect(plan.items.single.reach.parts, {'dive_profile_events': 1});
    await h.apply(plan);

    expect(await event(turtle), isNull);
  });

  test('a reworded link refreshes the words the annotation shows', () async {
    final linked = (await notes()).replaceFirst('[Turtle]', '[Green turtle]');

    final plan = await h.preview([
      updateOp('dives', 'd1', {'notes': linked}),
    ]);
    expect(plan.items.single.reach.parts, isEmpty);
    await h.apply(plan);

    expect((await event(turtle))!.description, 'Green turtle');
  });
}
