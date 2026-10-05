import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/certifications/data/repositories/certification_repository.dart';
import 'package:submersion/features/certifications/domain/entities/certification.dart';
import 'package:submersion/features/courses/data/repositories/course_repository.dart';

import '../../../helpers/test_database.dart';

/// Issue #690: an agency or level id this build does not know (a custom row
/// not yet synced, or a newer build's built-in) used to parse as "Other" and
/// be lost on the next save.
void main() {
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
    await db.customStatement(
      "INSERT INTO divers (id, name, created_at, updated_at) "
      "VALUES ('a', 'A', 0, 0)",
    );
  });
  tearDown(tearDownTestDatabase);

  const unknownAgency = '2b1f7c3e-9d8a-4c55-8e21-0f6a1b2c3d4e';
  const unknownLevel = 'futureLevel';

  test('unknown stored ids survive load and save', () async {
    await db.customStatement(
      'INSERT INTO certifications (id, diver_id, name, agency, level, '
      'additional_credentials, created_at, updated_at) '
      'VALUES (?, ?, ?, ?, ?, ?, 0, 0)',
      [
        'c1',
        'a',
        'Card',
        unknownAgency,
        unknownLevel,
        '[{"agency":"$unknownAgency","level":"$unknownLevel"}]',
      ],
    );
    final repo = CertificationRepository();
    final cert = (await repo.getCertificationById('c1'))!;
    expect(cert.agency, unknownAgency);
    expect(cert.level, unknownLevel);
    expect(
      cert.additionalCredentials.single,
      const CertificationCredential(agency: unknownAgency, level: unknownLevel),
    );

    await repo.updateCertification(cert.copyWith(notes: 'edited'));
    final row = await (db.select(
      db.certifications,
    )..where((t) => t.id.equals('c1'))).getSingle();
    expect(row.agency, unknownAgency);
    expect(row.level, unknownLevel);
    expect(row.additionalCredentials, contains(unknownAgency));
    expect(row.additionalCredentials, contains(unknownLevel));
  });

  test('a credential with no agency reads as Other, not a crash', () {
    final c = CertificationCredential.fromJson(const {'level': 'openWater'});
    expect(c.agency, 'other');
    expect(c.level, 'openWater');
  });

  test('an unknown course agency survives load and save', () async {
    await db.customStatement(
      'INSERT INTO courses (id, diver_id, name, agency, start_date, '
      'created_at, updated_at) VALUES (?, ?, ?, ?, 0, 0, 0)',
      ['k1', 'a', 'Course', unknownAgency],
    );
    final repo = CourseRepository();
    final course = (await repo.getCourseById('k1'))!;
    expect(course.agency, unknownAgency);
    await repo.updateCourse(course.copyWith(name: 'Renamed'));
    final row = await (db.select(
      db.courses,
    )..where((t) => t.id.equals('k1'))).getSingle();
    expect(row.agency, unknownAgency);
  });
}
