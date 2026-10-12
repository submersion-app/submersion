import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/database/database.dart' as db;
import 'package:submersion/core/services/export/export_service.dart';
import 'package:submersion/core/services/export/uddf/uddf_full_export_service.dart';
import 'package:submersion/features/certifications/data/repositories/certification_repository.dart';
import 'package:submersion/features/courses/data/repositories/course_repository.dart';
import 'package:submersion/features/dive_import/data/services/uddf_entity_importer.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;

import '../../../../helpers/test_database.dart';
import 'uddf_raw_data_round_trip_test.dart'
    show buildRepositories, createTestDiver;

/// A dive in two courses and a course with two certifications survive a UDDF
/// export and import (issue #2515). Before, the import dropped the course's
/// certification link entirely, and a dive kept only its last course link.
void main() {
  setUp(() async => setUpTestDatabase());
  tearDown(() async => tearDownTestDatabase());

  Future<String> seedAndExport() async {
    final diverId = await createTestDiver();
    final database = DatabaseService.instance.database;
    for (final (id, name, day) in [
      ('an', 'TDI Advanced Nitrox', 1),
      ('dp', 'TDI Decompression Procedures', 2),
    ]) {
      await database
          .into(database.courses)
          .insert(
            db.CoursesCompanion(
              id: Value(id),
              diverId: Value(diverId),
              name: Value(name),
              agency: const Value('tdi'),
              startDate: Value(DateTime(2026, 9, day).millisecondsSinceEpoch),
              createdAt: const Value(0),
              updatedAt: const Value(0),
            ),
          );
    }
    for (final (id, name) in [
      ('k-an', 'Advanced Nitrox'),
      ('k-dp', 'Decompression Procedures'),
    ]) {
      await database
          .into(database.certifications)
          .insert(
            db.CertificationsCompanion(
              id: Value(id),
              diverId: Value(diverId),
              name: Value(name),
              agency: const Value('tdi'),
              createdAt: const Value(0),
              updatedAt: const Value(0),
            ),
          );
    }
    await CourseRepository().setCourseCertifications('an', ['k-an', 'k-dp']);
    final dives = DiveRepository();
    await dives.createDive(
      domain.Dive(
        id: 'd1',
        diverId: diverId,
        dateTime: DateTime(2026, 9, 3, 9),
        courseIds: const ['an', 'dp'],
      ),
    );
    return UddfFullExportService().generateAllDataXmlForTest(
      dives: await dives.getAllDives(),
      courses: await CourseRepository().getAllCourses(),
      certifications: await CertificationRepository().getAllCertifications(),
    );
  }

  Future<void> restore(String xml) async {
    final diverId = await createTestDiver();
    final parsed = await ExportService().importAllDataFromUddf(xml);
    await UddfEntityImporter().import(
      data: parsed,
      selections: UddfImportSelections.selectAll(parsed),
      repositories: buildRepositories(),
      diverId: diverId,
    );
  }

  test('the export writes one link per course and per certification', () async {
    final xml = await seedAndExport();
    expect(RegExp('ref="course_').allMatches(xml), hasLength(2));
    expect(RegExp('ref="cert_').allMatches(xml), hasLength(2));
  });

  test('a dive keeps both courses and a course both certifications', () async {
    final xml = await seedAndExport();
    await tearDownTestDatabase();
    await setUpTestDatabase();
    await restore(xml);

    final courses = {
      for (final c in await CourseRepository().getAllCourses()) c.name: c.id,
    };
    final dive = (await DiveRepository().getAllDives()).single;
    final full = await DiveRepository().getDiveById(dive.id);
    expect(full!.courseIds.toSet(), {
      courses['TDI Advanced Nitrox'],
      courses['TDI Decompression Procedures'],
    });
    final earned = await CertificationRepository().getCertificationsForCourse(
      courses['TDI Advanced Nitrox']!,
    );
    expect(earned.map((c) => c.name).toSet(), {
      'Advanced Nitrox',
      'Decompression Procedures',
    });
  });
}
