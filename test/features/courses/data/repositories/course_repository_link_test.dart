import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/database/dive_course_identity.dart';
import 'package:submersion/features/courses/data/repositories/course_repository.dart';
import 'package:submersion/features/courses/domain/entities/course.dart'
    as domain;

import '../../../../helpers/test_database.dart';

/// Happy-path tests for the course repository's linking and delete operations.
///
/// Regression guard for https://github.com/submersion-app/submersion/issues/157
/// — the prior implementation wrapped args to Drift's `customStatement` in
/// `Variable.withString(...)` / `Variable.withInt(...)`, which is only valid
/// for `customSelect`/`customUpdate` with the `variables:` parameter.
/// `customStatement` takes raw primitives. The bug produced runtime errors
/// about `Variable` instances not being allowed parameter types on every
/// delete/link.
void main() {
  late CourseRepository repository;
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
    repository = CourseRepository();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  Future<void> insertDiver(String id) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.divers)
        .insert(
          DiversCompanion(
            id: Value(id),
            name: Value('Diver $id'),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
  }

  Future<void> insertDive({
    required String id,
    required String diverId,
    String? courseId,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.dives)
        .insert(
          DivesCompanion(
            id: Value(id),
            diverId: Value(diverId),
            diveDateTime: Value(now),
            courseId: Value(courseId),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
  }

  Future<void> insertCertification({
    required String id,
    required String diverId,
    String? courseId,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.certifications)
        .insert(
          CertificationsCompanion(
            id: Value(id),
            diverId: Value(diverId),
            name: Value('Cert $id'),
            agency: Value(CertificationAgency.padi.name),
            issueDate: Value(now),
            courseId: Value(courseId),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
  }

  Future<domain.Course> insertCourse({
    required String id,
    required String diverId,
    String? certificationId,
  }) async {
    return repository.createCourse(
      domain.Course(
        id: id,
        diverId: diverId,
        name: 'Course $id',
        agency: CertificationAgency.padi.name,
        startDate: DateTime(2024, 1, 1),
        certificationId: certificationId,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );
  }

  Future<String?> diveCourseId(String diveId) async {
    final row = await (db.select(
      db.dives,
    )..where((t) => t.id.equals(diveId))).getSingleOrNull();
    return row?.courseId;
  }

  Future<String?> certificationCourseId(String certId) async {
    final row = await (db.select(
      db.certifications,
    )..where((t) => t.id.equals(certId))).getSingleOrNull();
    return row?.courseId;
  }

  Future<String?> courseCertificationId(String courseId) async {
    final row = await (db.select(
      db.courses,
    )..where((t) => t.id.equals(courseId))).getSingleOrNull();
    return row?.certificationId;
  }

  group('deleteCourse', () {
    test(
      'removes the course and clears links on dives and certifications',
      () async {
        await insertDiver('alice');
        await insertCourse(id: 'course-1', diverId: 'alice');
        await insertDive(id: 'dive-1', diverId: 'alice', courseId: 'course-1');
        await insertCertification(
          id: 'cert-1',
          diverId: 'alice',
          courseId: 'course-1',
        );

        await repository.deleteCourse('course-1');

        expect(await repository.getCourseById('course-1'), isNull);
        expect(await diveCourseId('dive-1'), isNull);
        expect(await certificationCourseId('cert-1'), isNull);
      },
    );

    test(
      'succeeds when no dives or certifications reference the course',
      () async {
        await insertDiver('alice');
        await insertCourse(id: 'course-2', diverId: 'alice');

        await repository.deleteCourse('course-2');

        expect(await repository.getCourseById('course-2'), isNull);
      },
    );
  });

  Future<Set<String>> diveCourses(String diveId) async => {
    for (final r in await (db.select(
      db.diveCourses,
    )..where((t) => t.diveId.equals(diveId))).get())
      r.courseId,
  };

  group('linkDiveToCourse / unlinkDiveFromCourse (#2515)', () {
    test('a dive can be linked to two courses', () async {
      await insertDiver('alice');
      await insertCourse(id: 'course-3', diverId: 'alice');
      await insertCourse(id: 'course-5', diverId: 'alice');
      await insertDive(id: 'dive-2', diverId: 'alice');

      await repository.linkDiveToCourse('dive-2', 'course-3');
      await repository.linkDiveToCourse('dive-2', 'course-5');

      expect(await diveCourses('dive-2'), {'course-3', 'course-5'});
      expect(
        (await repository.getCoursesForDive('dive-2')).map((c) => c.id),
        containsAll(['course-3', 'course-5']),
      );
    });

    test('unlinking one course keeps the other as representative', () async {
      await insertDiver('alice');
      await insertCourse(id: 'course-3', diverId: 'alice');
      await insertCourse(id: 'course-5', diverId: 'alice');
      await insertDive(id: 'dive-2', diverId: 'alice');
      await repository.linkDiveToCourse('dive-2', 'course-3');
      await repository.linkDiveToCourse('dive-2', 'course-5');

      await repository.unlinkDiveFromCourse('dive-2', 'course-3');

      expect(await diveCourses('dive-2'), {'course-5'});
      expect(await diveCourseId('dive-2'), 'course-5');
    });
  });

  group('deleteCourse with a multi-course dive (#2515)', () {
    test("keeps the dive's other course and tombstones the link", () async {
      await insertDiver('alice');
      await insertCourse(id: 'course-a', diverId: 'alice');
      await insertCourse(id: 'course-b', diverId: 'alice');
      await insertDive(id: 'dive-3', diverId: 'alice');
      await repository.linkDiveToCourse('dive-3', 'course-a');
      await repository.linkDiveToCourse('dive-3', 'course-b');
      final rep = await diveCourseId('dive-3');
      final other = rep == 'course-a' ? 'course-b' : 'course-a';

      await repository.deleteCourse(rep!);

      expect(await diveCourses('dive-3'), {other});
      expect(await diveCourseId('dive-3'), other);
      final tombstones = await (db.select(
        db.deletionLog,
      )..where((t) => t.entityType.equals('diveCourses'))).get();
      expect(tombstones.map((t) => t.recordId), [
        diveCourseLinkId('dive-3', rep),
      ]);
    });
  });

  group('certifications (#2515)', () {
    test('setCourseCertifications links several certifications', () async {
      await insertDiver('alice');
      await insertCourse(id: 'course-4', diverId: 'alice');
      await insertCertification(id: 'cert-2', diverId: 'alice');
      await insertCertification(id: 'cert-3', diverId: 'alice');

      await repository.setCourseCertifications('course-4', [
        'cert-2',
        'cert-3',
      ]);

      expect(await certificationCourseId('cert-2'), 'course-4');
      expect(await certificationCourseId('cert-3'), 'course-4');
      expect(await courseCertificationId('course-4'), isNotNull);
    });

    test('getCourseForCertification reads the certification side', () async {
      await insertDiver('alice');
      await insertCourse(id: 'course-6', diverId: 'alice');
      await insertCertification(
        id: 'cert-6',
        diverId: 'alice',
        courseId: 'course-6',
      );
      // A stale course-side pointer from an older app version is ignored.
      await insertCourse(
        id: 'course-7',
        diverId: 'alice',
        certificationId: 'cert-6',
      );

      final course = await repository.getCourseForCertification('cert-6');
      expect(course?.id, 'course-6');
    });

    test(
      'updateCourse never overwrites the derived certification_id',
      () async {
        await insertDiver('alice');
        final course = await insertCourse(id: 'course-8', diverId: 'alice');
        await insertCertification(id: 'cert-8', diverId: 'alice');
        await repository.setCourseCertifications('course-8', ['cert-8']);

        // The entity still carries the stale null it was loaded with.
        await repository.updateCourse(course.copyWith(name: 'Renamed'));

        expect(await courseCertificationId('course-8'), 'cert-8');
      },
    );
  });

  test('getCoursesForDive falls back to a representative-only link', () async {
    await insertDiver('alice');
    await insertCourse(id: 'course-9', diverId: 'alice');
    await insertDive(id: 'dive-9', diverId: 'alice', courseId: 'course-9');
    final courses = await repository.getCoursesForDive('dive-9');
    expect(courses.map((c) => c.id), ['course-9']);
  });

  test(
    "moving a course's start date refreshes its dives' representative",
    () async {
      await insertDiver('alice');
      await insertCourse(id: 'course-early', diverId: 'alice');
      final late = await repository.createCourse(
        domain.Course(
          id: 'course-late',
          diverId: 'alice',
          name: 'Later',
          agency: CertificationAgency.padi.name,
          startDate: DateTime(2025, 1, 1),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      await insertDive(id: 'dive-r', diverId: 'alice');
      await repository.linkDiveToCourse('dive-r', 'course-early');
      await repository.linkDiveToCourse('dive-r', 'course-late');
      expect(await diveCourseId('dive-r'), 'course-early');

      await repository.updateCourse(late.copyWith(startDate: DateTime(2020)));

      expect(await diveCourseId('dive-r'), 'course-late');
    },
  );
}
