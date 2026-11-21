import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart' hide Dive;
import 'package:submersion/core/services/sync/sync_coordinator.dart';
import 'package:submersion/features/agent_access/data/writes/writable_entity.dart';
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

  // A link damaged rather than dropped would be read as the annotation
  // removed, so the plan refuses it, as the dive page holds Save (#4815).
  group('a damaged link', () {
    test('a link that lost its closing parenthesis is refused, and the '
        'annotation stays', () async {
      final stored = await notes();
      final plan = await h.preview([
        updateOp('dives', 'd1', {
          'notes': stored.substring(0, stored.length - 1),
        }),
      ]);

      final block = plan.items.single.block;
      expect(block?.reason, BlockReason.invalidValue);
      expect(block?.detail, contains('notes'));
      expect(block?.detail, contains(turtle));
      expect(await event(turtle), isNotNull);
    });

    test('a link whose id was edited is refused', () async {
      final stored = await notes();
      final plan = await h.preview([
        updateOp('dives', 'd1', {
          'notes': stored.replaceFirst(turtle, turtle.substring(0, 8)),
        }),
      ]);

      expect(plan.items.single.block?.reason, BlockReason.invalidValue);
    });

    test('a link to an annotation the dive does not hold loses nothing and '
        'is planned', () async {
      final stored = await notes();
      final plan = await h.preview([
        updateOp('dives', 'd1', {
          'notes': '$stored\n\n[Shark](annotation:from-another-dive)',
        }),
      ]);

      expect(plan.items.single.block, isNull);
    });
  });
}
