// Integration test for UddfEntityImporter's persistence of MacDive-extended
// dive + site metadata introduced in schema v71.
//
// Exercises the importer path end-to-end against an in-memory AppDatabase
// to verify that the fields parsed out of MacDive UDDF land in the new DB
// columns (dives.boat_name / boat_captain / dive_operator / surface_conditions
// / weather_description and dive_sites.water_type / body_of_water /
// difficulty).

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/export/export_service.dart';
import 'package:submersion/features/buddies/data/repositories/buddy_repository.dart';
import 'package:submersion/features/certifications/data/repositories/certification_repository.dart';
import 'package:submersion/features/courses/data/repositories/course_repository.dart';
import 'package:submersion/features/dive_centers/data/repositories/dive_center_repository.dart';
import 'package:submersion/features/dive_import/data/services/uddf_entity_importer.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/repositories/tank_pressure_repository.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_types/data/repositories/dive_type_repository.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart'
    as domain;
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_set_repository_impl.dart';
import 'package:submersion/features/tags/data/repositories/tag_repository.dart';
import 'package:submersion/features/trips/data/repositories/trip_repository.dart';

import '../../helpers/test_database.dart';

/// MacDive UDDF that exercises every new metadata field.
const _macDiveRichUddf = '''<?xml version="1.0" encoding="UTF-8" ?>
<uddf xmlns="http://www.streit.cc/uddf/3.2/" version="3.2.1">
  <generator><name>MacDive</name></generator>
  <divesite>
    <site id="site-RICH-UUID">
      <name>Rich Site</name>
      <watertype>saltwater</watertype>
      <bodyofwater>Pacific Ocean</bodyofwater>
      <difficulty>advanced</difficulty>
      <geography><address><country>Mexico</country></address></geography>
    </site>
  </divesite>
  <profiledata><repetitiongroup id="rg-1">
    <dive id="d-RICH-UUID">
      <informationbeforedive>
        <link ref="site-RICH-UUID" />
        <datetime>2024-06-01T09:00:00</datetime>
        <divenumber>42</divenumber>
      </informationbeforedive>
      <informationafterdive>
        <greatestdepth>18</greatestdepth>
        <diveduration>2400</diveduration>
        <weather>Sunny</weather>
        <surfaceconditions>Calm</surfaceconditions>
        <boatname>MV Nautilus</boatname>
        <boatcaptain>Jane Smith</boatcaptain>
        <diveoperator>Nautilus Liveaboards</diveoperator>
      </informationafterdive>
      <samples><waypoint><divetime>0</divetime><depth>0</depth></waypoint></samples>
    </dive>
  </repetitiongroup></profiledata>
</uddf>''';

ImportRepositories buildRepositories() {
  return ImportRepositories(
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
}

Future<String> createTestDiver() async {
  final now = DateTime.now();
  const diverId = 'diver-macdive-fields-test';
  final diver = domain.Diver(
    id: diverId,
    name: 'Test Diver',
    isDefault: true,
    createdAt: now,
    updatedAt: now,
  );
  await DiverRepository().createDiver(diver);
  return diverId;
}

void main() {
  late AppDatabase db;
  final importer = UddfEntityImporter();
  final exportService = ExportService();

  setUp(() async {
    db = await setUpTestDatabase();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  group('UddfEntityImporter persists MacDive metadata', () {
    test('MacDive UDDF persists dive-level metadata to dives table', () async {
      final diverId = await createTestDiver();
      final parsed = await exportService.importAllDataFromUddf(
        _macDiveRichUddf,
      );
      expect(parsed.dives, hasLength(1));

      await importer.import(
        data: parsed,
        selections: UddfImportSelections.selectAll(parsed),
        repositories: buildRepositories(),
        diverId: diverId,
      );

      final diveRows = await db.select(db.dives).get();
      expect(diveRows, hasLength(1));
      final dive = diveRows.single;
      expect(dive.boatName, 'MV Nautilus');
      expect(dive.boatCaptain, 'Jane Smith');
      expect(dive.diveOperator, 'Nautilus Liveaboards');
      expect(dive.surfaceConditions, 'Calm');
      expect(
        dive.weatherDescription,
        'Sunny',
        reason: 'UDDF <weather> must land on weather_description column',
      );
    });

    test(
      'MacDive UDDF persists site-level metadata to dive_sites table',
      () async {
        final diverId = await createTestDiver();
        final parsed = await exportService.importAllDataFromUddf(
          _macDiveRichUddf,
        );
        expect(parsed.sites, hasLength(1));

        await importer.import(
          data: parsed,
          selections: UddfImportSelections.selectAll(parsed),
          repositories: buildRepositories(),
          diverId: diverId,
        );

        final siteRows = await db.select(db.diveSites).get();
        expect(siteRows, hasLength(1));
        final site = siteRows.single;
        expect(site.waterType, 'saltwater');
        expect(site.bodyOfWater, 'Pacific Ocean');
        expect(
          site.difficulty,
          'advanced',
          reason:
              'difficulty was already extracted by the parser; verify the '
              'importer persists it via the DiveSite entity path.',
        );
      },
    );
  });
}
