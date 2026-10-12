import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';

import '../../../../helpers/test_database.dart';

/// A dive's training courses through the repository (issue #2515).
void main() {
  late DiveRepository repository;
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
    repository = DiveRepository();
    await db
        .into(db.divers)
        .insert(
          const DiversCompanion(
            id: Value('diver-1'),
            name: Value('D'),
            createdAt: Value(0),
            updatedAt: Value(0),
          ),
        );
    for (final (id, start) in [('an', 1), ('dp', 2)]) {
      await db
          .into(db.courses)
          .insert(
            CoursesCompanion(
              id: Value(id),
              diverId: const Value('diver-1'),
              name: Value(id),
              agency: const Value('tdi'),
              startDate: Value(start),
              createdAt: const Value(0),
              updatedAt: const Value(0),
            ),
          );
    }
  });
  tearDown(() async => tearDownTestDatabase());

  domain.Dive dive(String id, List<String> courseIds) => domain.Dive(
    id: id,
    diverId: 'diver-1',
    dateTime: DateTime(2026, 9, 3),
    courseIds: courseIds,
  );

  Future<Set<String>> junction(String diveId) async => {
    for (final r in await (db.select(
      db.diveCourses,
    )..where((t) => t.diveId.equals(diveId))).get())
      r.courseId,
  };

  test('a dive saves and reloads with two courses', () async {
    await repository.createDive(dive('v1', ['dp', 'an']));
    final loaded = await repository.getDiveById('v1');
    expect(loaded!.courseIds, ['an', 'dp']); // representative (earliest) first
    expect(loaded.courseId, 'an');
    final row = await db.select(db.dives).getSingle();
    expect(row.courseId, 'an');
  });

  test('updating to one course drops the other', () async {
    final created = await repository.createDive(dive('v1', ['an', 'dp']));
    await repository.updateDive(created.copyWith(courseIds: ['dp']));
    expect(await junction('v1'), {'dp'});
    expect((await repository.getDiveById('v1'))!.courseId, 'dp');
  });

  test('clearing every course clears the representative', () async {
    final created = await repository.createDive(dive('v1', ['an']));
    await repository.updateDive(created.copyWith(courseIds: const []));
    expect(await junction('v1'), isEmpty);
    expect((await db.select(db.dives).getSingle()).courseId, isNull);
  });

  test('getDivesForCourse lists a dive under each of its courses', () async {
    await repository.createDive(dive('v1', ['an', 'dp']));
    await repository.createDive(dive('v2', ['dp']));
    expect((await repository.getDivesForCourse('an')).map((d) => d.id), ['v1']);
    expect(
      (await repository.getDivesForCourse('dp')).map((d) => d.id).toSet(),
      {'v1', 'v2'},
    );
  });

  test('getDivesByIds hydrates the course set', () async {
    await repository.createDive(dive('v1', ['an', 'dp']));
    final loaded = await repository.getDivesByIds(['v1']);
    expect(loaded.single.courseIds, ['an', 'dp']);
  });

  test('deleting the dive cascades its links', () async {
    await repository.createDive(dive('v1', ['an', 'dp']));
    await repository.deleteDive('v1');
    expect(await db.select(db.diveCourses).get(), isEmpty);
  });

  test('deleting the diver leaves no dive_courses rows behind', () async {
    await repository.createDive(dive('v1', ['an', 'dp']));
    await DiverRepository().deleteDiver('diver-1');
    expect(await db.select(db.diveCourses).get(), isEmpty);
  });
}
