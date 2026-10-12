import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/certifications/data/repositories/certification_repository.dart';
import 'package:submersion/features/courses/data/repositories/course_repository.dart';

import '../../../helpers/test_database.dart';

/// The certification side of a course link (issue #2515).
void main() {
  late AppDatabase db;
  late CertificationRepository certs;

  setUp(() async {
    db = await setUpTestDatabase();
    certs = CertificationRepository();
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
    await db
        .into(db.courses)
        .insert(
          const CoursesCompanion(
            id: Value('A'),
            diverId: Value('d'),
            name: Value('AN/DP'),
            agency: Value('tdi'),
            startDate: Value(0),
            createdAt: Value(0),
            updatedAt: Value(0),
          ),
        );
    for (final (id, issued) in [('k2', 2), ('k1', 1), ('k0', null)]) {
      await db
          .into(db.certifications)
          .insert(
            CertificationsCompanion(
              id: Value(id),
              diverId: const Value('d'),
              name: Value(id),
              agency: const Value('tdi'),
              issueDate: Value(issued),
              createdAt: const Value(0),
              updatedAt: const Value(0),
            ),
          );
    }
    await CourseRepository().setCourseCertifications('A', ['k2', 'k1', 'k0']);
  });

  tearDown(tearDownTestDatabase);

  test('lists a course certifications earliest first, undated last', () async {
    final list = await certs.getCertificationsForCourse('A');
    expect(list.map((c) => c.id), ['k1', 'k2', 'k0']);
  });

  test('a certification carries the course it came from', () async {
    final cert = await certs.getCertificationById('k1');
    expect(cert!.courseId, 'A');
  });

  test('deleting the representative moves it to the next one', () async {
    await certs.deleteCertification('k1');
    final course = await (db.select(
      db.courses,
    )..where((t) => t.id.equals('A'))).getSingle();
    expect(course.certificationId, 'k2');
  });

  test('updating a certification never rewrites its course link', () async {
    final cert = await certs.getCertificationById('k2');
    await db.customStatement(
      "UPDATE certifications SET course_id = NULL WHERE id = 'k2'",
    );
    await certs.updateCertification(cert!.copyWith(name: 'Renamed'));
    final row = await (db.select(
      db.certifications,
    )..where((t) => t.id.equals('k2'))).getSingle();
    expect(row.courseId, isNull);
  });

  test('an issue-date edit moves the course representative', () async {
    final k2 = await certs.getCertificationById('k2');
    await certs.updateCertification(
      k2!.copyWith(issueDate: DateTime.fromMillisecondsSinceEpoch(0)),
    );
    final course = await (db.select(
      db.courses,
    )..where((t) => t.id.equals('A'))).getSingle();
    expect(course.certificationId, 'k2');
  });
}
