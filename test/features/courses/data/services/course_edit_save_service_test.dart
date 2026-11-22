import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/sync/sync_coordinator.dart';
import 'package:submersion/features/change_log/data/repositories/change_log_repository.dart';
import 'package:submersion/features/change_log/data/services/change_log_revert_service.dart';
import 'package:submersion/features/courses/data/repositories/course_repository.dart';
import 'package:submersion/features/courses/data/services/course_edit_save_service.dart';
import 'package:submersion/features/courses/domain/entities/course.dart'
    as domain;
import 'package:submersion/features/courses/presentation/editing/course_edit_fields.dart';
import 'package:submersion/shared/widgets/record_editing/edit_field.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

import '../../../../helpers/test_database.dart';

/// A course page's sitting is written as one History entry, and writes only
/// what it changed (issue #4527, phase 3).
void main() {
  late AppDatabase db;
  late CourseRepository courses;
  late CourseEditSaveService service;
  final changeLog = ChangeLogRepository();

  Future<domain.Course> stored([String id = 'k1']) async =>
      (await courses.getCourseById(id))!;

  Future<List<Map<String, Object?>>> operations() async {
    await changeLog.settleAll();
    final rows = await db
        .customSelect('SELECT id, source, label FROM change_log_operations')
        .get();
    return [for (final row in rows) row.data];
  }

  Future<({domain.Course before, domain.Course after})?> save(
    EditSession<domain.Course> session,
  ) => service.save(
    courseId: session.stored.id,
    apply: session.applyTo,
    changedCardIds: session.changedCardIds,
  );

  Future<String?> representativeOf(String diveId) async => (await (db.select(
    db.dives,
  )..where((t) => t.id.equals(diveId))).getSingle()).courseId;

  Future<void> insertCourse(String id, String name, DateTime start) => db
      .into(db.courses)
      .insert(
        CoursesCompanion(
          id: Value(id),
          diverId: const Value('d'),
          name: Value(name),
          agency: const Value('padi'),
          startDate: Value(start.millisecondsSinceEpoch),
          instructorId: id == 'k1' ? const Value('b1') : const Value.absent(),
          instructorName: id == 'k1'
              ? const Value('Sam')
              : const Value.absent(),
          location: id == 'k1' ? const Value('Reef') : const Value.absent(),
          notes: const Value('Calm'),
          createdAt: const Value(0),
          updatedAt: const Value(0),
        ),
      );

  Future<void> insertDive(String id) => db
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

  setUp(() async {
    db = await setUpTestDatabase();
    addTearDown(SyncCoordinator.reset);
    courses = CourseRepository();
    service = CourseEditSaveService(courses);
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
    await db.customStatement(
      "INSERT INTO buddies (id, name, created_at, updated_at) "
      "VALUES ('b1', 'Sam', 0, 0), ('b2', 'Alex', 0, 0)",
    );
    await insertCourse('k1', 'Rescue', DateTime(2026, 3, 1));
    await insertCourse('k0', 'Nitrox', DateTime(2026, 3, 5));
    await insertDive('v1');
    await insertDive('v2');
    await courses.linkDiveToCourse('v1', 'k1');
    await courses.linkDiveToCourse('v2', 'k1');
    await courses.linkDiveToCourse('v2', 'k0');
    // What setup wrote is not a sitting.
    await changeLog.settleAll();
    await db.customStatement('DELETE FROM change_log_operations');
  });

  tearDown(tearDownTestDatabase);

  test('writes a location change as one History entry', () async {
    final session = EditSession(await stored())
      ..set(courseLocationField, 'Blue Hole');

    final result = await save(session);

    expect((await stored()).location, 'Blue Hole');
    expect(result!.before.location, 'Reef');
    final ops = await operations();
    expect(ops, hasLength(1));
    expect(ops.single['source'], 'manual');
    expect(ops.single['label'], 'record_edit:courses:k1:details');
  });

  // One case per column the course's update writes: a value changed in
  // storage during the sitting, on a field the diver did not touch,
  // survives the Save.
  final census = <String, ({String sql, bool Function(domain.Course) kept})>{
    'name': (
      sql: "UPDATE courses SET name = 'Renamed'",
      kept: (c) => c.name == 'Renamed',
    ),
    'agency': (
      sql: "UPDATE courses SET agency = 'ssi'",
      kept: (c) => c.agency == 'ssi',
    ),
    'start date': (
      sql: 'UPDATE courses SET start_date = 5000',
      kept: (c) => c.startDate.millisecondsSinceEpoch == 5000,
    ),
    'completion date': (
      sql: 'UPDATE courses SET completion_date = 9000',
      kept: (c) => c.completionDate?.millisecondsSinceEpoch == 9000,
    ),
    'instructor id': (
      sql: "UPDATE courses SET instructor_id = 'b2'",
      kept: (c) => c.instructorId == 'b2',
    ),
    'instructor name': (
      sql: "UPDATE courses SET instructor_name = 'Alex'",
      kept: (c) => c.instructorName == 'Alex',
    ),
    'instructor number': (
      sql: "UPDATE courses SET instructor_number = '42'",
      kept: (c) => c.instructorNumber == '42',
    ),
    'location': (
      sql: "UPDATE courses SET location = 'Elsewhere'",
      kept: (c) => c.location == 'Elsewhere',
    ),
    'notes': (
      sql: "UPDATE courses SET notes = 'Newer'",
      kept: (c) => c.notes == 'Newer',
    ),
  };
  for (final MapEntry(key: column, value: change) in census.entries) {
    test('a $column changed underneath keeps its newer value', () async {
      // The sitting changes a field other than the one changed underneath.
      final EditField<domain.Course, String> touched = column == 'notes'
          ? courseNameField
          : courseNotesField;
      final session = EditSession(await stored())..set(touched, 'Edited');
      await db.customStatement('${change.sql} WHERE id = ?', ['k1']);

      await save(session);

      final after = await stored();
      expect(change.kept(after), isTrue, reason: column);
      expect(touched.read(after), 'Edited');
    });
  }

  test('the instructor picked is written', () async {
    final session = EditSession(await stored())
      ..set(courseInstructorField, (id: 'b2', name: 'Alex', number: '9'));

    await save(session);

    final after = await stored();
    expect(after.instructorId, 'b2');
    expect(after.instructorName, 'Alex');
    expect(after.instructorNumber, '9');
  });

  test('clearing the completion date stores null', () async {
    await db.customStatement(
      "UPDATE courses SET completion_date = 9000 WHERE id = 'k1'",
    );
    final session = EditSession(await stored())
      ..set(courseCompletionDateField, null);

    await save(session);

    expect((await stored()).completionDate, isNull);
  });

  test('a later start moves a dive to its other course, in the same entry, '
      'and reverting restores it', () async {
    expect(await representativeOf('v2'), 'k1');
    final session = EditSession(await stored())
      ..set(courseStartDateField, DateTime(2026, 4, 1));

    await save(session);

    expect(await representativeOf('v2'), 'k0');
    expect(await representativeOf('v1'), 'k1');
    final ops = await operations();
    expect(ops, hasLength(1));

    final revert = ChangeLogRevertService(afterDiveWrites: (_) {});
    await revert.execute(
      await revert.planOperation(ops.single['id']! as String),
    );

    expect(await representativeOf('v2'), 'k1');
    expect((await stored()).startDate, DateTime(2026, 3, 1));
  });

  test('unchanged returns null and writes nothing', () async {
    final result = await save(EditSession(await stored()));

    expect(result, isNull);
    expect(await operations(), isEmpty);
  });

  test('a course that has gone throws', () async {
    final session = EditSession(await stored())
      ..set(courseLocationField, 'Blue Hole');
    await db.customStatement("DELETE FROM courses WHERE id = 'k1'");

    await expectLater(save(session), throwsStateError);
  });

  /// A new course's sitting (issue #4527, phase 3, plan 11).
  group('create', () {
    domain.Course fresh({String id = 'n1'}) => domain.Course(
      id: id,
      diverId: 'd',
      name: 'Nitrox',
      agency: 'padi',
      startDate: DateTime(2026, 5, 1),
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

    test('creates the course with its id, as one History entry', () async {
      final created = await service.create(
        course: fresh(),
        changedCardIds: const ['status', 'details'],
      );

      expect(created.id, 'n1');
      expect((await stored('n1')).name, 'Nitrox');
      final ops = await operations();
      expect(ops, hasLength(1));
      expect(ops.single['source'], 'manual');
      expect(ops.single['label'], 'record_edit:courses:n1:details,status');
    });

    test('the instructor picked on a new course is written', () async {
      await service.create(
        course: fresh().copyWith(
          instructorId: 'b2',
          instructorName: 'Alex',
          instructorNumber: '9',
        ),
        changedCardIds: const ['status', 'instructor'],
      );

      final created = await stored('n1');
      expect(created.instructorId, 'b2');
      expect(created.instructorName, 'Alex');
      expect(created.instructorNumber, '9');
    });

    test('held writes run after the row, in the same entry', () async {
      domain.Course? seen;
      await service.create(
        course: fresh(),
        changedCardIds: const ['earnedCertifications'],
        alsoWrite: () async {
          seen = await courses.getCourseById('n1');
          await courses.setCourseCertifications('n1', const []);
        },
      );

      expect(seen?.name, 'Nitrox');
      expect(await operations(), hasLength(1));
    });

    test('a held write that throws leaves nothing', () async {
      await expectLater(
        service.create(
          course: fresh(),
          changedCardIds: const ['status'],
          alsoWrite: () async => throw StateError('refused'),
        ),
        throwsStateError,
      );

      expect(await courses.getCourseById('n1'), isNull);
      expect(await operations(), isEmpty);
    });

    test('an empty id or one already stored is refused', () async {
      await expectLater(
        service.create(
          course: fresh(id: ''),
          changedCardIds: const [],
        ),
        throwsStateError,
      );
      await expectLater(
        service.create(
          course: fresh(id: 'k1'),
          changedCardIds: const [],
        ),
        throwsStateError,
      );

      expect((await stored()).name, 'Rescue');
      expect(await operations(), isEmpty);
    });
  });
}
