// Integration test for UddfEntityImporter's persistence of MacDive-style
// waypoint gas switches to the `gas_switches` table.
//
// MacDive marks gas changes via <switchmix ref="gas-UUID"/> inside individual
// <waypoint> samples (the ref points at a gas mix UUID, not a tank UUID).
// The parser emits these into `diveData['gasSwitches']` with a `gasMixRef`
// key; the importer resolves that back to the persisted tank row by matching
// against the tank's linked gas mix UUID (`tanksData[i]['uddfGasMixRef']`).
//
// This test exercises the full parser -> importer -> DB path and asserts that
// each waypoint <switchmix ref> lands in the gas_switches table with its
// tank_id pointing at the correct dive_tanks row.

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

/// MacDive-style UDDF with two tanks (each linked to a distinct gas mix) and
/// two profile waypoints that carry `<switchmix ref="..."/>` markers.
const _macDiveMultiTankUddf = '''<?xml version="1.0" encoding="UTF-8" ?>
<uddf xmlns="http://www.streit.cc/uddf/3.2/" version="3.2.1">
  <gasdefinitions>
    <mix id="mix-bottom"><o2>0.32</o2><he>0.0</he></mix>
    <mix id="mix-deco"><o2>0.80</o2><he>0.0</he></mix>
  </gasdefinitions>
  <profiledata>
    <repetitiongroup id="rg-1">
      <dive id="d-macdive-1">
        <informationbeforedive>
          <datetime>2024-06-01T09:00:00</datetime>
        </informationbeforedive>
        <informationafterdive>
          <greatestdepth>40.0</greatestdepth>
          <diveduration>3600.0</diveduration>
        </informationafterdive>
        <tankdata>
          <link ref="mix-bottom" />
          <tankvolume>0.012</tankvolume>
          <tankpressurebegin>20000000</tankpressurebegin>
          <tankpressureend>8000000</tankpressureend>
        </tankdata>
        <tankdata>
          <link ref="mix-deco" />
          <tankvolume>0.007</tankvolume>
          <tankpressurebegin>20000000</tankpressurebegin>
          <tankpressureend>12000000</tankpressureend>
        </tankdata>
        <samples>
          <waypoint><divetime>0</divetime><depth>0.0</depth><switchmix ref="mix-bottom"/></waypoint>
          <waypoint><divetime>120</divetime><depth>30.0</depth></waypoint>
          <waypoint><divetime>2400</divetime><depth>6.0</depth><switchmix ref="mix-deco"/></waypoint>
        </samples>
      </dive>
    </repetitiongroup>
  </profiledata>
</uddf>''';

ImportRepositories _buildRepositories() {
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

Future<String> _createTestDiver() async {
  final now = DateTime.now();
  const diverId = 'diver-macdive-gasswitches-test';
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

  group('UddfEntityImporter persists waypoint <switchmix ref> gas switches', () {
    test(
      'writes one gas_switches row per <switchmix ref>, tank_id resolved via gas mix UUID',
      () async {
        final diverId = await _createTestDiver();

        final parsed = await exportService.importAllDataFromUddf(
          _macDiveMultiTankUddf,
        );
        expect(parsed.dives, hasLength(1));

        // Sanity: parser emitted two gas-switch entries with gasMixRef.
        final parsedSwitches =
            (parsed.dives[0]['gasSwitches'] as List?)
                ?.cast<Map<String, dynamic>>() ??
            const <Map<String, dynamic>>[];
        expect(parsedSwitches, hasLength(2));
        expect(parsedSwitches[0]['gasMixRef'], 'mix-bottom');
        expect(parsedSwitches[1]['gasMixRef'], 'mix-deco');

        // Sanity: both tanks carry their UDDF gas-mix UUID so the importer
        // can resolve the switchmix refs back to tanks.
        final parsedTanks = (parsed.dives[0]['tanks'] as List)
            .cast<Map<String, dynamic>>();
        expect(parsedTanks, hasLength(2));
        expect(parsedTanks[0]['uddfGasMixRef'], 'mix-bottom');
        expect(parsedTanks[1]['uddfGasMixRef'], 'mix-deco');

        await importer.import(
          data: parsed,
          selections: const UddfImportSelections(dives: {0}),
          repositories: _buildRepositories(),
          diverId: diverId,
        );

        final diveTanks = await db.select(db.diveTanks).get();
        expect(
          diveTanks,
          hasLength(2),
          reason: 'expected two dive_tanks rows for the two UDDF tanks',
        );

        final switches = await db.select(db.gasSwitches).get();
        expect(
          switches,
          hasLength(2),
          reason: 'expected one gas_switches row per <switchmix ref>',
        );

        // Tanks are imported in UDDF order; tank[0] = bottom gas, tank[1] = deco.
        // Importer preserves tank order from the parsed `tanks` list.
        final bottomTankId = diveTanks[0].id;
        final decoTankId = diveTanks[1].id;

        final byTimestamp = {for (final gs in switches) gs.timestamp: gs};
        expect(byTimestamp.keys, containsAll(<int>[0, 2400]));
        expect(
          byTimestamp[0]!.tankId,
          bottomTankId,
          reason: 'waypoint 0s switch to mix-bottom should land on tank[0]',
        );
        expect(
          byTimestamp[2400]!.tankId,
          decoTankId,
          reason: 'waypoint 2400s switch to mix-deco should land on tank[1]',
        );
        expect(byTimestamp[2400]!.depth, 6.0);
      },
    );
  });
}
