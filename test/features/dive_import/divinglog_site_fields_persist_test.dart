import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/export/models/uddf_import_result.dart';
import 'package:submersion/features/buddies/data/repositories/buddy_repository.dart';
import 'package:submersion/features/certifications/data/repositories/certification_repository.dart';
import 'package:submersion/features/courses/data/repositories/course_repository.dart';
import 'package:submersion/features/dive_centers/data/repositories/dive_center_repository.dart';
import 'package:submersion/features/dive_import/data/services/uddf_entity_importer.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/repositories/tank_pressure_repository.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_types/data/repositories/dive_type_repository.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart'
    as domain;
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_set_repository_impl.dart';
import 'package:submersion/features/tags/data/repositories/tag_repository.dart';
import 'package:submersion/features/trips/data/repositories/trip_repository.dart';
import 'package:submersion/features/universal_import/data/services/divinglog_raw_types.dart';
import 'package:submersion/features/universal_import/data/services/divinglog_reference_mapper.dart';

import '../../helpers/test_database.dart';

ImportRepositories _repositories() => ImportRepositories(
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
);

/// The Diving Log mapper's site output, written through the real importer
/// and database, keeps every Place detail (#2271). The mapper tests stop at
/// the payload map; this proves a newly created site stores it, including
/// the water type and body of water that go out as a separate metadata
/// write after the site row is created.
void main() {
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  test('a new Diving Log site stores its Place details', () async {
    const diverId = 'diver-divinglog-site-fields';
    final now = DateTime.now();
    await DiverRepository().createDiver(
      domain.Diver(
        id: diverId,
        name: 'Test Diver',
        isDefault: true,
        createdAt: now,
        updatedAt: now,
      ),
    );

    // No coordinates, so the importer never reaches reverse geocoding.
    final sites = DivingLogReferenceMapper.sites(
      const DivingLogLogbook(
        dives: [DivingLogRawDive(id: 1, placeId: 10)],
        capabilities: DivingLogCapabilities(tables: {}, columns: {}),
        placesById: {
          10: DivingLogRawPlace(
            id: 10,
            place: 'Salt Pier',
            waterName: 'Caribbean Sea',
            difficulty: 'Novice',
            rating: 4,
            water: 3,
            altitude: 'Sea Level',
          ),
        },
      ),
    ).values.toList();
    final data = UddfImportResult(sites: sites);

    await UddfEntityImporter().import(
      data: data,
      selections: UddfImportSelections.selectAll(data),
      repositories: _repositories(),
      diverId: diverId,
    );

    final row = (await db.select(db.diveSites).get()).single;
    expect(row.name, 'Salt Pier');
    expect(row.waterType, 'brackish');
    expect(row.bodyOfWater, 'Caribbean Sea');
    expect(row.difficulty, 'beginner');
    expect(row.rating, 4.0);
    expect(row.altitude, 0.0);

    final site = (await SiteRepository().getSiteById(row.id))!;
    expect(site.waterType, WaterType.brackish);
    expect(site.bodyOfWater, 'Caribbean Sea');
    expect(site.difficulty, SiteDifficulty.beginner);
  });
}
