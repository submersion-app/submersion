import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/annotation_repository.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

/// The annotation repository (#4109) writes the event row and the Notes link
/// together and keeps the two reconciled on every save.
void main() {
  late AppDatabase db;
  late AnnotationRepository repo;
  const diveId = 'd1';

  setUp(() async {
    db = await setUpTestDatabase();
    await DiveRepository().createDive(
      createTestDiveWithBottomTime(
        id: diveId,
        diveNumber: 1,
      ).copyWith(notes: 'x'),
    );
    repo = AnnotationRepository();
  });
  tearDown(() => tearDownTestDatabase());

  Future<Dive> dive() =>
      (db.select(db.dives)..where((t) => t.id.equals(diveId))).getSingle();

  Future<List<DiveProfileEvent>> rows() => (db.select(
    db.diveProfileEvents,
  )..orderBy([(t) => OrderingTerm.asc(t.timestamp)])).get();

  Future<Set<(String, String)>> pending() async => {
    for (final r in await db.select(db.syncRecords).get())
      if (r.syncStatus == 'pending') (r.entityType, r.recordId),
  };

  Future<List<(String, String)>> tombstones() async => [
    for (final t in await db.select(db.deletionLog).get())
      (t.entityType, t.recordId),
  ];

  Future<void> seedEvent({
    required String id,
    required String type,
    required String source,
    int timestamp = 0,
    String? description,
  }) => db.customStatement(
    'INSERT INTO dive_profile_events '
    '(id, dive_id, timestamp, event_type, source, description, created_at) '
    "VALUES (?, '$diveId', ?, ?, ?, ?, 1)",
    [id, timestamp, type, source, description],
  );

  test(
    'addAnnotation appends the link paragraph and inserts a user row',
    () async {
      final id = await repo.addAnnotation(
        diveId: diveId,
        timestamp: 1290,
        depth: 19.6,
        words: 'felt sick',
      );

      expect((await dive()).notes, 'x\n\n[felt sick](annotation:$id)');
      final row = (await rows()).single;
      expect(row.id, id);
      expect(
        (row.eventType, row.source, row.description, row.timestamp, row.depth),
        ('annotation', 'user', 'felt sick', 1290, 19.6),
      );
      expect(
        await pending(),
        containsAll({('dives', diveId), ('diveProfileEvents', id)}),
      );
    },
  );

  test('moveAnnotation changes the row and does not touch the dive', () async {
    final id = await repo.addAnnotation(
      diveId: diveId,
      timestamp: 100,
      depth: 5,
      words: 'w',
    );
    final before = await dive();
    await db.delete(db.syncRecords).go(); // forget the add's pending marks

    await repo.moveAnnotation(id: id, timestamp: 640, depth: 12.5);

    final row = (await rows()).single;
    expect((row.timestamp, row.depth), (640, 12.5));
    final after = await dive();
    expect(after.updatedAt, before.updatedAt);
    expect(after.notes, before.notes);
    expect(await pending(), {('diveProfileEvents', id)});
  });

  test('removeAnnotation unlinks the words and tombstones the row', () async {
    final id = await repo.addAnnotation(
      diveId: diveId,
      timestamp: 100,
      words: 'felt sick',
    );

    await repo.removeAnnotation(diveId: diveId, id: id);

    expect((await dive()).notes, 'x\n\nfelt sick');
    expect(await rows(), isEmpty);
    expect(await tombstones(), contains(('diveProfileEvents', id)));
  });

  test('moving an annotation that is gone writes nothing', () async {
    await db.delete(db.syncRecords).go();
    await repo.moveAnnotation(id: 'gone', timestamp: 5, depth: null);
    expect(await pending(), isEmpty);
  });

  test('removing an annotation twice logs one tombstone', () async {
    final id = await repo.addAnnotation(
      diveId: diveId,
      timestamp: 1,
      words: 'w',
    );
    await repo.removeAnnotation(diveId: diveId, id: id);
    await repo.removeAnnotation(diveId: diveId, id: id);
    expect(
      (await tombstones()).where((t) => t == ('diveProfileEvents', id)),
      hasLength(1),
    );
  });

  test(
    'removeAnnotation leaves the dive alone when no link names it',
    () async {
      await seedEvent(id: 'orphan', type: 'annotation', source: 'user');
      final before = await dive();
      await db.delete(db.syncRecords).go();

      await repo.removeAnnotation(diveId: diveId, id: 'orphan');

      expect(await rows(), isEmpty);
      expect((await dive()).updatedAt, before.updatedAt);
      expect(await pending(), isEmpty);
    },
  );

  test('reconcile creates pending annotations that are linked and ignores '
      'the rest', () async {
    const notes = 'I [felt sick](annotation:p1) today';
    await repo.reconcile(
      diveId: diveId,
      notes: notes,
      create: const [
        PendingAnnotation(id: 'p1', timestamp: 630, depth: 18),
        PendingAnnotation(id: 'p2', timestamp: 900, depth: 10),
      ],
    );

    final row = (await rows()).single;
    expect(
      (row.id, row.eventType, row.source, row.description, row.timestamp),
      ('p1', 'annotation', 'user', 'felt sick', 630),
    );
    expect(await pending(), contains(('diveProfileEvents', 'p1')));
    // reconcile never writes the dive's notes
    expect((await dive()).notes, 'x');
  });

  test('reconcile deletes an annotation whose link is gone and leaves computer '
      'events', () async {
    await seedEvent(
      id: 'a1',
      type: 'annotation',
      source: 'user',
      description: 'gone',
    );
    await seedEvent(id: 'g1', type: 'gasSwitch', source: 'imported');

    await repo.reconcile(diveId: diveId, notes: 'nothing linked');

    expect((await rows()).map((r) => r.id), ['g1']);
    expect(await tombstones(), [('diveProfileEvents', 'a1')]);
  });

  test('reconcile refreshes the cached words', () async {
    await seedEvent(
      id: 'a1',
      type: 'annotation',
      source: 'user',
      description: 'old words',
    );

    await repo.reconcile(diveId: diveId, notes: '[new words](annotation:a1)');

    expect((await rows()).single.description, 'new words');
    expect(await pending(), contains(('diveProfileEvents', 'a1')));
  });

  test(
    'annotationsForDive returns only annotation rows in time order',
    () async {
      await seedEvent(id: 'g1', type: 'gasSwitch', source: 'imported');
      await seedEvent(
        id: 'b',
        type: 'annotation',
        source: 'user',
        timestamp: 90,
      );
      await seedEvent(
        id: 'a',
        type: 'annotation',
        source: 'user',
        timestamp: 30,
      );

      final found = await repo.annotationsForDive(diveId);

      expect(found.map((e) => e.id), ['a', 'b']);
      expect(found.every((e) => e.isAnnotation), isTrue);
    },
  );
}
