import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/courses/data/repositories/course_requirement_repository.dart';
import 'package:submersion/features/courses/domain/entities/course_requirement.dart';
import 'package:submersion/features/courses/presentation/providers/course_requirement_providers.dart';

import '../../../../helpers/test_database.dart';

/// A completed course ranks its suggestions by its dates, so changing those
/// dates has to reach a provider that stays alive across navigation.
void main() {
  late AppDatabase db;

  int courseDate(int day) => DateTime(2020, 1, day).millisecondsSinceEpoch;
  int diveTime(int day) => DateTime.utc(2020, 1, day).millisecondsSinceEpoch;

  setUp(() async {
    db = await setUpTestDatabase();
    await db.customStatement(
      "INSERT INTO divers (id, name, created_at, updated_at) "
      "VALUES ('diver-1', 'Test Diver', 1000, 1000)",
    );
    await db.customStatement(
      "INSERT INTO courses (id, diver_id, name, agency, start_date, "
      "created_at, updated_at) VALUES "
      "('course-1', 'diver-1', 'AOW', 'padi', ${courseDate(50)}, 1000, 1000)",
    );
    for (final (id, day) in [('before', 49), ('after', 400)]) {
      await db.customStatement(
        "INSERT INTO dives (id, diver_id, dive_date_time, created_at, "
        "updated_at) VALUES ('$id', 'diver-1', ${diveTime(day)}, 1000, 1000)",
      );
    }
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  test('completing a course refreshes its suggestions', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final subscription = container.listen(
      suggestedDivesProvider('course-1'),
      (_, _) {},
    );
    addTearDown(subscription.close);

    final running = await container.read(
      suggestedDivesProvider('course-1').future,
    );
    expect(running.map((s) => s.diveId), ['after']);

    await (db.update(db.courses)..where((t) => t.id.equals('course-1'))).write(
      CoursesCompanion(completionDate: Value(courseDate(51))),
    );
    await pumpEventQueue();

    final completed = await container.read(
      suggestedDivesProvider('course-1').future,
    );
    expect(completed.map((s) => s.diveId), ['before', 'after']);
  });

  // A sync pull can credit a dive while the picker is open, and a stale row
  // here is a tap that does nothing.
  test('crediting a dive removes it from the creditable list', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final subscription = container.listen(
      creditableDivesProvider('course-1'),
      (_, _) {},
    );
    addTearDown(subscription.close);

    final before = await container.read(
      creditableDivesProvider('course-1').future,
    );
    expect(before.map((s) => s.diveId), ['after', 'before']);

    final repository = CourseRequirementRepository();
    final requirement = await repository.createRequirement(
      courseId: 'course-1',
      name: 'Deep adventure dive',
      kind: RequirementKind.dive,
    );
    await repository.linkDive(requirementId: requirement.id, diveId: 'after');
    await pumpEventQueue();

    final after = await container.read(
      creditableDivesProvider('course-1').future,
    );
    expect(after.map((s) => s.diveId), ['before']);
  });
}
