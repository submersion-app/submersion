import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/database/dive_course_identity.dart';
import 'package:submersion/features/courses/data/dive_course_links.dart';

import '../../../helpers/test_database.dart';

/// A dive's courses (`dive_courses`, issue #2515) and the representative
/// `dives.course_id` kept in step with them.
void main() {
  late AppDatabase db;
  late DiveCourseLinks links;

  setUp(() async {
    db = await setUpTestDatabase();
    links = DiveCourseLinks(db, SyncRepository());
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
    // c2 and c1 share a start date, so the name breaks the tie ('A' < 'B');
    // c3 starts earliest.
    for (final (id, start, name) in [
      ('c1', 100, 'B'),
      ('c2', 100, 'A'),
      ('c3', 50, 'Z'),
    ]) {
      await db
          .into(db.courses)
          .insert(
            CoursesCompanion(
              id: Value(id),
              diverId: const Value('d'),
              name: Value(name),
              agency: const Value('tdi'),
              startDate: Value(start),
              createdAt: const Value(0),
              updatedAt: const Value(0),
            ),
          );
    }
    for (final id in ['v1', 'v2']) {
      await db
          .into(db.dives)
          .insert(
            DivesCompanion(
              id: Value(id),
              diverId: const Value('d'),
              diveDateTime: const Value(0),
              createdAt: const Value(0),
              updatedAt: const Value(0),
            ),
          );
    }
  });

  tearDown(tearDownTestDatabase);

  Future<String?> representative(String diveId) async => (await (db.select(
    db.dives,
  )..where((t) => t.id.equals(diveId))).getSingle()).courseId;

  test(
    'writeCourseSet writes deterministic rows and the representative',
    () async {
      await links.writeCourseSet('v1', ['c1', 'c2'], now: 1);
      final rows = await db.select(db.diveCourses).get();
      expect(
        {for (final r in rows) r.id},
        {diveCourseLinkId('v1', 'c1'), diveCourseLinkId('v1', 'c2')},
      );
      expect(await representative('v1'), 'c2');
    },
  );

  test('writeCourseSet diffs: an unchanged pair keeps its row', () async {
    await links.writeCourseSet('v1', ['c1', 'c2'], now: 1);
    await links.writeCourseSet('v1', ['c1', 'c3'], now: 2);
    final rows = await db.select(db.diveCourses).get();
    expect(rows.firstWhere((r) => r.courseId == 'c1').createdAt, 1);
    expect(rows.map((r) => r.courseId).toSet(), {'c1', 'c3'});
    final tombstones = await (db.select(
      db.deletionLog,
    )..where((t) => t.entityType.equals('diveCourses'))).get();
    expect(tombstones.map((t) => t.recordId), [diveCourseLinkId('v1', 'c2')]);
    expect(await representative('v1'), 'c3');
  });

  test('an empty set clears the representative', () async {
    await links.writeCourseSet('v1', ['c1'], now: 1);
    await links.writeCourseSet('v1', [], now: 2);
    expect(await representative('v1'), isNull);
    expect(await db.select(db.diveCourses).get(), isEmpty);
  });

  test('courseIdsForDives lists the representative first', () async {
    await links.writeCourseSet('v1', ['c1', 'c2', 'c3'], now: 1);
    expect((await links.courseIdsForDives(['v1']))['v1'], ['c3', 'c2', 'c1']);
  });

  test('a dive with only the legacy column hydrates from it', () async {
    await db.customStatement(
      "UPDATE dives SET course_id = 'c1' WHERE id = 'v1'",
    );
    expect((await links.courseIdsForDives(['v1']))['v1'], ['c1']);
  });

  test('a dive with no course is absent from the map', () async {
    expect(await links.courseIdsForDives(['v2']), isEmpty);
  });

  test('add and remove keep the other courses', () async {
    await links.writeCourseSet('v1', ['c1'], now: 1);
    await links.addCourses(['v1', 'v2'], ['c2'], now: 2);
    await links.removeCourses(['v1'], ['c1'], now: 3);
    final map = await links.courseIdsForDives(['v1', 'v2']);
    expect(map['v1'], ['c2']);
    expect(map['v2'], ['c2']);
  });

  test('counts how many dives are in each course', () async {
    await links.writeCourseSet('v1', ['c1', 'c2'], now: 1);
    await links.writeCourseSet('v2', ['c2'], now: 1);
    expect(await links.courseCountsForDives(['v1', 'v2']), {'c1': 1, 'c2': 2});
  });

  test(
    'refreshRepresentative with markPending stamps a changed dive',
    () async {
      await links.writeCourseSet('v1', ['c1'], now: 1);
      await db.customStatement(
        "DELETE FROM dive_courses WHERE dive_id = 'v1' AND course_id = 'c1'",
      );
      await links.refreshRepresentative('v1', now: 77, markPending: true);
      final dive = await (db.select(
        db.dives,
      )..where((t) => t.id.equals('v1'))).getSingle();
      expect(dive.courseId, isNull);
      expect(dive.updatedAt, 77);
    },
  );

  test('re-adding a removed link clears its tombstone', () async {
    await links.writeCourseSet('v1', ['c1'], now: 1);
    await links.writeCourseSet('v1', [], now: 2);
    await links.writeCourseSet('v1', ['c1'], now: 3);
    final tombstones = await (db.select(
      db.deletionLog,
    )..where((t) => t.entityType.equals('diveCourses'))).get();
    expect(tombstones, isEmpty);
  });
}
