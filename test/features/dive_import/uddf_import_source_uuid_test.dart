// Integration test for UddfEntityImporter's persistence of the UDDF `<dive id>`
// attribute to `dive_data_sources.source_uuid`.
//
// This test exercises the importer path end-to-end against an in-memory
// AppDatabase, not just the parser. It verifies the one-line change at
// lib/features/dive_import/data/services/uddf_entity_importer.dart (around the
// `sourceUuid: Value(diveData['sourceUuid'] as String?)` line on the
// DiveDataSourcesCompanion) actually writes the value to the DB.

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

/// Builds a minimal MacDive-style UDDF string.
///
/// If [diveId] is provided, renders `<dive id="...">`; otherwise renders `<dive>`.
String buildMinimalUddf({String? diveId}) {
  final diveAttr = diveId == null ? '' : ' id="$diveId"';
  return '''<uddf version="3.2.1">
  <gasdefinitions>
    <mix id="mix1">
      <name>Air</name>
      <o2>0.21</o2>
      <he>0.00</he>
    </mix>
  </gasdefinitions>
  <profiledata>
    <repetitiongroup id="repgrp1">
      <dive$diveAttr>
        <informationbeforedive>
          <datetime>2024-01-15T10:00:00</datetime>
          <divenumber>1</divenumber>
        </informationbeforedive>
        <informationafterdive>
          <greatestdepth>30.0</greatestdepth>
          <diveduration>2400.0</diveduration>
          <lowesttemperature>280.15</lowesttemperature>
        </informationafterdive>
        <tankdata>
          <link ref="mix1"/>
          <tankvolume>12.0</tankvolume>
          <tankpressurebegin>20000000</tankpressurebegin>
          <tankpressureend>5000000</tankpressureend>
        </tankdata>
        <samples>
          <waypoint>
            <divetime>0.0</divetime>
            <depth>0.0</depth>
            <temperature>280.15</temperature>
          </waypoint>
          <waypoint>
            <divetime>60.0</divetime>
            <depth>5.0</depth>
            <temperature>280.15</temperature>
          </waypoint>
        </samples>
      </dive>
    </repetitiongroup>
  </profiledata>
</uddf>''';
}

/// Builds an [ImportRepositories] bundle using real repositories wired to the
/// in-memory AppDatabase set up via [setUpTestDatabase].
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

/// Creates a default diver in the DB and returns its id.
Future<String> createTestDiver() async {
  final now = DateTime.now();
  const diverId = 'diver-source-uuid-test';
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

  group('UddfEntityImporter persists sourceUuid to dive_data_sources', () {
    test('writes source_uuid when UDDF <dive> has id attribute', () async {
      final diverId = await createTestDiver();

      final parsed = await exportService.importAllDataFromUddf(
        buildMinimalUddf(diveId: 'DIVE-SOURCE-UUID-1'),
      );
      expect(parsed.dives, hasLength(1));
      expect(
        parsed.dives[0]['sourceUuid'],
        'DIVE-SOURCE-UUID-1',
        reason:
            'Sanity check: parser populates sourceUuid; the importer step '
            'below is what we actually want to test.',
      );

      await importer.import(
        data: parsed,
        selections: const UddfImportSelections(dives: {0}),
        repositories: buildRepositories(),
        diverId: diverId,
      );

      final rows = await db.select(db.diveDataSources).get();
      expect(
        rows,
        hasLength(1),
        reason: 'Importer should have written exactly one data source row',
      );
      expect(
        rows.single.sourceUuid,
        'DIVE-SOURCE-UUID-1',
        reason:
            'UddfEntityImporter must persist UDDF <dive id> into '
            'dive_data_sources.source_uuid',
      );
    });

    test(
      'writes null source_uuid when UDDF <dive> has no id attribute',
      () async {
        final diverId = await createTestDiver();

        final parsed = await exportService.importAllDataFromUddf(
          buildMinimalUddf(),
        );
        expect(parsed.dives, hasLength(1));
        expect(parsed.dives[0]['sourceUuid'], isNull);

        await importer.import(
          data: parsed,
          selections: const UddfImportSelections(dives: {0}),
          repositories: buildRepositories(),
          diverId: diverId,
        );

        final rows = await db.select(db.diveDataSources).get();
        expect(rows, hasLength(1));
        expect(
          rows.single.sourceUuid,
          isNull,
          reason:
              'With no <dive id> in source UDDF, source_uuid column should be '
              'null',
        );
      },
    );
  });
}
