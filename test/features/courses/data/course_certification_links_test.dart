import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/courses/data/course_certification_links.dart';

import '../../../helpers/test_database.dart';

/// A course's certifications (issue #2515): `certifications.course_id` is the
/// truth, `courses.certification_id` the representative.
void main() {
  late AppDatabase db;
  late CourseCertificationLinks links;

  setUp(() async {
    db = await setUpTestDatabase();
    links = CourseCertificationLinks(db, SyncRepository());
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
    for (final id in ['A', 'B']) {
      await db
          .into(db.courses)
          .insert(
            CoursesCompanion(
              id: Value(id),
              diverId: const Value('d'),
              name: Value(id),
              agency: const Value('tdi'),
              startDate: const Value(0),
              createdAt: const Value(0),
              updatedAt: const Value(0),
            ),
          );
    }
    for (final (id, issued) in [('k1', 1), ('k2', 2), ('k3', null)]) {
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
  });

  tearDown(tearDownTestDatabase);

  Future<String?> certCourse(String id) async => (await (db.select(
    db.certifications,
  )..where((t) => t.id.equals(id))).getSingle()).courseId;

  Future<String?> courseRep(String id) async => (await (db.select(
    db.courses,
  )..where((t) => t.id.equals(id))).getSingle()).certificationId;

  test(
    'a course earns several certifications, earliest is representative',
    () async {
      await links.setCourseCertifications('A', ['k2', 'k1'], now: 1);
      expect(await certCourse('k1'), 'A');
      expect(await certCourse('k2'), 'A');
      expect(await courseRep('A'), 'k1');
    },
  );

  test(
    'unticking clears the certification side and the representative',
    () async {
      await links.setCourseCertifications('A', ['k1'], now: 1);
      await links.setCourseCertifications('A', [], now: 2);
      expect(await certCourse('k1'), isNull);
      expect(await courseRep('A'), isNull);
    },
  );

  test('moving a certification recomputes the old course', () async {
    await links.setCourseCertifications('A', ['k1', 'k2'], now: 1);
    await links.setCourseCertifications('B', ['k1'], now: 2);
    expect(await certCourse('k1'), 'B');
    expect(await courseRep('A'), 'k2');
    expect(await courseRep('B'), 'k1');
  });

  test('an undated certification sorts last', () async {
    await links.setCourseCertifications('A', ['k3', 'k2'], now: 1);
    expect(await courseRep('A'), 'k2');
  });

  test('every touched row is marked pending', () async {
    await links.setCourseCertifications('A', ['k1'], now: 1);
    final pending = await db.select(db.syncRecords).get();
    final keys = {for (final r in pending) '${r.entityType}:${r.recordId}'};
    expect(keys, containsAll(['certifications:k1', 'courses:A']));
  });
}
