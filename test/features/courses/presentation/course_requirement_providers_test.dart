import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/courses/data/repositories/course_requirement_repository.dart';
import 'package:submersion/features/courses/domain/entities/course_requirement.dart';
import 'package:submersion/features/courses/presentation/providers/course_requirement_providers.dart';

import '../../../helpers/test_database.dart';

Future<void> _seed() async {
  final db = DatabaseService.instance.database;
  await db.customStatement(
    "INSERT INTO divers (id, name, created_at, updated_at) "
    "VALUES ('diver-1', 'Test Diver', 1000, 1000)",
  );
  await db.customStatement(
    "INSERT INTO courses (id, diver_id, name, agency, start_date, "
    "created_at, updated_at) "
    "VALUES ('course-1', 'diver-1', 'AOW', 'padi', 1000, 1000, 1000)",
  );
}

void main() {
  setUp(() async {
    await setUpTestDatabase();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  test('courseProgressProvider resolves progress and refreshes after a '
      'requirement write', () async {
    await _seed();
    final repository = CourseRequirementRepository();
    await repository.createRequirement(
      courseId: 'course-1',
      name: 'Deep adventure dive',
      kind: RequirementKind.dive,
    );

    final container = ProviderContainer();
    addTearDown(container.dispose);

    // Keep the provider actively listened: invalidateSelfWhen defers
    // refreshes while a provider is paused (no listeners), which is the
    // Riverpod 3 auto-pause state a bare container.read leaves it in.
    final subscription = container.listen(
      courseProgressProvider('course-1'),
      (_, _) {},
    );
    addTearDown(subscription.close);

    final progress = await container.read(
      courseProgressProvider('course-1').future,
    );
    expect(progress.totalCount, 1);
    expect(progress.satisfiedCount, 0);

    await repository.createRequirement(
      courseId: 'course-1',
      name: 'Knowledge development',
      kind: RequirementKind.checklist,
    );
    // invalidateSelfWhen listens to a table stream; give it a tick.
    await Future<void>.delayed(const Duration(milliseconds: 50));

    final refreshed = await container.read(
      courseProgressProvider('course-1').future,
    );
    expect(refreshed.totalCount, 2);
  });

  test('courseProgressProvider refreshes linked-dive summaries after a '
      'dive write', () async {
    await _seed();
    final db = DatabaseService.instance.database;
    await db.customStatement(
      "INSERT INTO dives (id, diver_id, dive_number, dive_date_time, "
      "created_at, updated_at) "
      "VALUES ('dive-1', 'diver-1', 10, 1000, 1000, 1000)",
    );

    final repository = CourseRequirementRepository();
    final requirement = await repository.createRequirement(
      courseId: 'course-1',
      name: 'Deep adventure dive',
      kind: RequirementKind.dive,
    );
    await repository.linkDive(requirementId: requirement.id, diveId: 'dive-1');

    final container = ProviderContainer();
    addTearDown(container.dispose);
    final subscription = container.listen(
      courseProgressProvider('course-1'),
      (_, _) {},
    );
    addTearDown(subscription.close);

    final progress = await container.read(
      courseProgressProvider('course-1').future,
    );
    expect(progress.requirements.single.linkedDives.single.diveNumber, 10);

    // Edit the credited dive's number. getCourseProgress joins the dives
    // table, so the linked-dive summary must refresh even though no
    // requirement/link row changed. A Drift-native update fires the dives
    // table-update tick that courseProgressProvider now watches.
    await (db.update(db.dives)..where((t) => t.id.equals('dive-1'))).write(
      const DivesCompanion(diveNumber: Value(20)),
    );
    // watchDivesChanges debounces 300ms; wait past it plus a tick.
    await Future<void>.delayed(const Duration(milliseconds: 400));

    final refreshed = await container.read(
      courseProgressProvider('course-1').future,
    );
    expect(refreshed.requirements.single.linkedDives.single.diveNumber, 20);
  });
}
