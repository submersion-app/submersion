import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart';
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
        agency: CertificationAgency.padi,
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

  group('linkDiveToCourse / unlinkDiveFromCourse', () {
    test('sets and clears the course_id on the dive', () async {
      await insertDiver('alice');
      await insertCourse(id: 'course-3', diverId: 'alice');
      await insertDive(id: 'dive-2', diverId: 'alice');

      await repository.linkDiveToCourse('dive-2', 'course-3');
      expect(await diveCourseId('dive-2'), 'course-3');

      await repository.unlinkDiveFromCourse('dive-2');
      expect(await diveCourseId('dive-2'), isNull);
    });
  });

  group('linkCourseToCertification', () {
    test('sets course_id and certification_id bidirectionally', () async {
      await insertDiver('alice');
      await insertCourse(id: 'course-4', diverId: 'alice');
      await insertCertification(id: 'cert-2', diverId: 'alice');

      await repository.linkCourseToCertification('course-4', 'cert-2');

      expect(await courseCertificationId('course-4'), 'cert-2');
      expect(await certificationCourseId('cert-2'), 'course-4');
    });
  });
}
