import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/export/models/uddf_import_result.dart';
import 'package:submersion/features/buddies/data/repositories/buddy_repository.dart';
import 'package:submersion/features/certifications/data/repositories/certification_repository.dart';
import 'package:submersion/features/courses/data/repositories/course_repository.dart';
import 'package:submersion/features/dive_centers/data/repositories/dive_center_repository.dart';
import 'package:submersion/features/dive_computer/data/repositories/dive_computer_connection_repository.dart';
import 'package:submersion/features/dive_import/data/services/uddf_entity_importer.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_computer_repository_impl.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/repositories/tank_pressure_repository.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_types/data/repositories/dive_type_repository.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_set_repository_impl.dart';
import 'package:submersion/features/tags/data/repositories/tag_repository.dart';
import 'package:submersion/features/trips/data/repositories/trip_repository.dart';

import '../../../../helpers/test_database.dart';

/// Issue #5040: a dive reads its site's altitude and water type, and an
/// export writes them on the dive. Importing that file back must not turn
/// the site's values into values of the dive's own.
void main() {
  late AppDatabase db;
  late UddfEntityImporter importer;
  late ImportRepositories repos;
  const diverId = 'diver-1';

  setUp(() async {
    db = await setUpTestDatabase();
    importer = UddfEntityImporter();
    final now = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.divers)
        .insert(
          DiversCompanion(
            id: const Value(diverId),
            name: const Value('Test Diver'),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
    repos = ImportRepositories(
      tripRepository: TripRepository(),
      equipmentRepository: EquipmentRepository(),
      equipmentSetRepository: EquipmentSetRepository(),
      buddyRepository: BuddyRepository(),
      diveCenterRepository: DiveCenterRepository(),
      certificationRepository: CertificationRepository(),
      tagRepository: TagRepository(),
      diveTypeRepository: DiveTypeRepository(),
      siteRepository: SiteRepository(),
      diveRepository: DiveRepository(),
      tankPressureRepository: TankPressureRepository(),
      courseRepository: CourseRepository(),
      diveComputerRepository: DiveComputerRepository(),
      diveComputerConnectionRepository: DiveComputerConnectionRepository(),
    );
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  test("a dive value equal to its site's is read from the site", () async {
    final data = UddfImportResult(
      sites: [
        {
          'uddfId': 'lake',
          'name': 'Lake',
          'altitude': 450.0,
          'waterType': 'fresh',
        },
      ],
      dives: [
        {
          'dateTime': DateTime(2024, 3, 1, 10),
          'maxDepth': 20.0,
          'site': {'uddfId': 'lake'},
          'altitude': 450.0,
          'waterType': 'fresh',
        },
        {
          'dateTime': DateTime(2024, 3, 2, 10),
          'maxDepth': 20.0,
          'site': {'uddfId': 'lake'},
          'altitude': 1200.0,
          'waterType': 'salt',
        },
      ],
    );

    await importer.import(
      data: data,
      selections: const UddfImportSelections(dives: {0, 1}, sites: {0}),
      repositories: repos,
      diverId: diverId,
    );

    final rows = await (db.select(
      db.dives,
    )..orderBy([(t) => OrderingTerm(expression: t.diveDateTime)])).get();
    expect(rows.map((r) => (r.altitude, r.waterType)), [
      (null, null),
      (1200.0, 'salt'),
    ]);
  });
}
