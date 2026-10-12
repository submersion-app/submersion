import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart' hide Dive;
import 'package:submersion/features/courses/data/dive_course_links.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/services/dive_consolidation_service.dart';
import 'package:submersion/features/dive_log/data/services/dive_merge_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

import '../../../../helpers/test_database.dart';

/// A dive's courses through merge and consolidation, and their undo (#2515).
void main() {
  late AppDatabase db;
  late DiveRepository diveRepo;

  setUp(() async {
    db = await setUpTestDatabase();
    diveRepo = DiveRepository();
    await db
        .into(db.divers)
        .insert(
          const DiversCompanion(
            id: Value('d'),
            name: Value('D'),
            createdAt: Value(0),
            updatedAt: Value(0),
          ),
        );
    for (final (id, start) in [('c1', 1), ('c2', 2)]) {
      await db
          .into(db.courses)
          .insert(
            CoursesCompanion(
              id: Value(id),
              diverId: const Value('d'),
              name: Value(id),
              agency: const Value('tdi'),
              startDate: Value(start),
              createdAt: const Value(0),
              updatedAt: const Value(0),
            ),
          );
    }
  });

  tearDown(tearDownTestDatabase);

  Future<void> dive(String id, int hour, List<String> courses) =>
      diveRepo.createDive(
        Dive(
          id: id,
          diverId: 'd',
          dateTime: DateTime(2026, 9, 3, hour),
          entryTime: DateTime(2026, 9, 3, hour),
          courseIds: courses,
        ),
      );

  Future<Set<String>> junction(String diveId) async => {
    for (final r in await (db.select(
      db.diveCourses,
    )..where((t) => t.diveId.equals(diveId))).get())
      r.courseId,
  };

  Future<List<String>?> courses(String diveId) async => (await DiveCourseLinks(
    db,
    SyncRepository(),
  ).courseIdsForDives([diveId]))[diveId];

  test('merge unions the courses and undo restores each dive', () async {
    await dive('a', 9, ['c1', 'c2']);
    await dive('b', 10, ['c2']);
    final service = DiveMergeService(diveRepo);

    final outcome = await service.apply(['a', 'b']);
    final mergedId = outcome.mergedDive.id;
    expect((await courses(mergedId))!.toSet(), {'c1', 'c2'});

    await service.undo(outcome.snapshot);
    expect(await junction('a'), {'c1', 'c2'});
    expect(await junction('b'), {'c2'});
  });

  test('consolidation adds the secondary courses; undo removes them', () async {
    await dive('t', 9, ['c1']);
    await dive('s', 9, ['c2']);
    final service = DiveConsolidationService(diveRepo);

    final outcome = await service.apply(
      targetDiveId: 't',
      secondaryDiveIds: ['s'],
    );
    expect((await courses('t'))!.toSet(), {'c1', 'c2'});
    final row = await (db.select(
      db.dives,
    )..where((x) => x.id.equals('t'))).getSingle();
    expect(row.courseId, 'c1');

    await service.undo(outcome.snapshot);
    expect(await junction('t'), {'c1'});
    expect(await junction('s'), {'c2'});
  });
}
