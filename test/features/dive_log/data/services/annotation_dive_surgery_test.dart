import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/annotation_repository.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/services/dive_consolidation_service.dart';
import 'package:submersion/features/dive_log/data/services/dive_merge_service.dart';
import 'package:submersion/features/dive_log/data/services/dive_uncombine_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;
import 'package:submersion/features/dive_log/domain/services/annotation_links.dart';

import '../../../../helpers/test_database.dart';

/// Combine, uncombine and consolidation copy events under fresh ids, and an
/// annotation is held together by its id (#4109): the Notes link has to
/// follow the row wherever it lands, or the marker and the pin both go.
void main() {
  late AppDatabase db;
  late DiveRepository diveRepo;
  late AnnotationRepository annotations;

  setUp(() async {
    db = await setUpTestDatabase();
    await db.customStatement('PRAGMA foreign_keys = OFF');
    diveRepo = DiveRepository();
    annotations = AnnotationRepository();
  });
  tearDown(() => tearDownTestDatabase());

  Future<void> seedDive(
    String id, {
    required DateTime entry,
    int runtimeMin = 30,
    double depth = 10,
    String notes = '',
    String? computerId,
  }) async {
    await diveRepo.createDive(
      domain.Dive(
        id: id,
        diverId: 'diver1',
        dateTime: entry,
        entryTime: entry,
        runtime: Duration(minutes: runtimeMin),
        maxDepth: depth,
        notes: notes,
        tanks: [domain.DiveTank(id: 'tank-$id', volume: 11.1)],
        profile: [
          const domain.DiveProfilePoint(timestamp: 0, depth: 0),
          domain.DiveProfilePoint(timestamp: runtimeMin * 30, depth: depth),
          domain.DiveProfilePoint(timestamp: runtimeMin * 60, depth: 0),
        ],
      ),
    );
    if (computerId != null) {
      await (db.update(db.dives)..where((t) => t.id.equals(id))).write(
        DivesCompanion(computerId: Value(computerId)),
      );
    }
    await db
        .into(db.diveDataSources)
        .insert(
          DiveDataSourcesCompanion.insert(
            id: 'src-$id',
            diveId: id,
            importedAt: DateTime.utc(2026, 7, 1),
            createdAt: DateTime.utc(2026, 7, 1),
          ).copyWith(
            isPrimary: const Value(true),
            computerId: Value(computerId),
            maxDepth: Value(depth),
            sourceFileName: Value('$id.uddf'),
          ),
        );
  }

  Future<List<DiveProfileEvent>> annotationRows(String diveId) =>
      (db.select(db.diveProfileEvents)..where(
            (t) => t.diveId.equals(diveId) & t.eventType.equals('annotation'),
          ))
          .get();

  Future<String> notesOf(String diveId) async => (await (db.select(
    db.dives,
  )..where((t) => t.id.equals(diveId))).getSingle()).notes;

  group('combine', () {
    Future<DiveMergeOutcome> combine() async {
      final service = DiveMergeService(diveRepo);
      await seedDive('a', entry: DateTime.utc(2026, 7, 1, 9), notes: 'Reef.');
      await seedDive('b', entry: DateTime.utc(2026, 7, 1, 10), runtimeMin: 20);
      await annotations.addAnnotation(
        diveId: 'a',
        timestamp: 60,
        words: 'felt sick',
      );
      await annotations.addAnnotation(
        diveId: 'b',
        timestamp: 120,
        words: 'lost buddy',
      );
      return service.apply(['a', 'b']);
    }

    test('every annotation keeps its link on the combined dive', () async {
      final outcome = await combine();
      final mergedId = outcome.mergedDive.id;

      final rows = await annotationRows(mergedId);
      final words = annotationWordsInNotes(await notesOf(mergedId));
      expect(rows, hasLength(2));
      expect({for (final r in rows) words[r.id]}, {'felt sick', 'lost buddy'});
      expect(
        annotationWordsInNotes(outcome.mergedDive.notes).keys.toSet(),
        words.keys.toSet(),
      );
    });

    test('an annotation lands at its place on the combined timeline', () async {
      final outcome = await combine();

      final rows = await annotationRows(outcome.mergedDive.id);
      final later = rows.firstWhere((r) => r.description == 'lost buddy');
      expect(later.timestamp, 3600 + 120);
    });

    test('undo brings the original rows and links back', () async {
      final service = DiveMergeService(diveRepo);
      final outcome = await combine();
      await service.undo(outcome.snapshot);

      final rows = await annotationRows('b');
      expect(annotationIdsInNotes(await notesOf('b')), {rows.single.id});
    });
  });

  group('uncombine', () {
    Future<(String kept, String restored)> combineThenSeparate() async {
      await seedDive('a', entry: DateTime.utc(2026, 7, 1, 9));
      await seedDive('b', entry: DateTime.utc(2026, 7, 1, 10), runtimeMin: 20);
      await annotations.addAnnotation(
        diveId: 'a',
        timestamp: 60,
        words: 'felt sick',
      );
      await annotations.addAnnotation(
        diveId: 'b',
        timestamp: 120,
        words: 'lost buddy',
      );
      final merged = await DiveMergeService(diveRepo).apply(['a', 'b']);
      final kept = merged.mergedDive.id;
      final restored = await DiveUncombineService(
        diveRepo,
      ).separate(diveId: kept);
      return (kept, restored.single);
    }

    test(
      'an annotation in a segment that leaves takes its words along',
      () async {
        final (_, restored) = await combineThenSeparate();

        final row = (await annotationRows(restored)).single;
        expect(row.description, 'lost buddy');
        expect(row.timestamp, 120);
        expect(annotationWordsInNotes(await notesOf(restored)), {
          row.id: 'lost buddy',
        });
      },
    );

    test('the kept dive keeps those words as plain text', () async {
      final (kept, _) = await combineThenSeparate();

      final notes = await notesOf(kept);
      final row = (await annotationRows(kept)).single;
      expect(row.description, 'felt sick');
      expect(annotationIdsInNotes(notes), {row.id});
      expect(notes, contains('lost buddy'));
    });
  });

  group('consolidate', () {
    final entry = DateTime.utc(2026, 7, 1, 9);

    Future<void> consolidate() => DiveConsolidationService(
      diveRepo,
    ).apply(targetDiveId: 't', secondaryDiveIds: ['s']);

    test('Notes filled in from a secondary keep their links', () async {
      await seedDive('t', entry: entry, computerId: 'comp-t');
      await seedDive('s', entry: entry, computerId: 'comp-s');
      await annotations.addAnnotation(
        diveId: 's',
        timestamp: 60,
        words: 'felt sick',
      );

      await consolidate();

      final row = (await annotationRows('t')).single;
      expect(annotationWordsInNotes(await notesOf('t')), {row.id: 'felt sick'});
    });

    test('the target\'s own annotation stays the diver\'s, not a computer\'s, '
        'so a later split cannot carry it away from its Notes', () async {
      await seedDive('t', entry: entry, computerId: 'comp-t', notes: 'Own.');
      await seedDive('s', entry: entry, computerId: 'comp-s');
      await annotations.addAnnotation(
        diveId: 't',
        timestamp: 60,
        words: 'felt sick',
      );

      await consolidate();

      expect((await annotationRows('t')).single.computerId, isNull);
    });

    test('a secondary\'s annotation stays the diver\'s too', () async {
      await seedDive('t', entry: entry, computerId: 'comp-t');
      await seedDive('s', entry: entry, computerId: 'comp-s');
      await annotations.addAnnotation(
        diveId: 's',
        timestamp: 60,
        words: 'felt sick',
      );

      await consolidate();

      expect((await annotationRows('t')).single.computerId, isNull);
    });
  });
}
