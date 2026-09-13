// End-to-end check that a CSV's tags and suit columns reach the database:
// real CsvImportParser output, converted the way the import wizard converts
// it, imported by the real UddfEntityImporter into an in-memory AppDatabase.

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
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
import 'package:submersion/features/dive_types/data/repositories/dive_type_repository.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart'
    as domain;
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_set_repository_impl.dart';
import 'package:submersion/features/tags/data/repositories/tag_repository.dart';
import 'package:submersion/features/trips/data/repositories/trip_repository.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/parsers/csv_import_parser.dart';

import '../../../../../helpers/test_database.dart';

/// A Subsurface dive list: dive 1 is tagged "reef, night" and worn with a
/// suit, dive 2 is tagged "reef" only.
const _csv =
    'dive number,date,time,duration [min],maxdepth [m],'
    'avgdepth [m],mode,airtemp [C],watertemp [C],'
    'cylinder size (1) [l],startpressure (1) [bar],'
    'endpressure (1) [bar],o2 (1) [%],he (1) [%],'
    'location,gps,divemaster,buddy,suit,rating,'
    'visibility,notes,weight [kg],tags,sac [l/min]\n'
    '1,2024-06-15,09:00,45,25.0,18.0,OC,28.0,27.0,'
    '12.0,200,50,21,0,Blue Hole,,,,7mm Wetsuit,5,good,'
    'Saw a turtle,2.0,"reef, night",14.5\n'
    '2,2024-06-16,10:00,50,30.0,22.0,OC,28.0,26.5,'
    '12.0,200,60,21,0,The Wall,,,,,4,good,'
    ',2.0,reef,15.0\n';

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

void main() {
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
  });

  tearDown(tearDownTestDatabase);

  test('a Subsurface CSV import tags each dive and keeps its suit', () async {
    const diverId = 'diver-csv-tags';
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

    final payload = await CsvImportParser().parse(
      Uint8List.fromList(utf8.encode(_csv)),
    );
    final data = UddfImportResult(
      dives: payload.entitiesOf(ImportEntityType.dives),
      sites: payload.entitiesOf(ImportEntityType.sites),
      buddies: payload.entitiesOf(ImportEntityType.buddies),
      tags: payload.entitiesOf(ImportEntityType.tags),
    );

    final result = await UddfEntityImporter().import(
      data: data,
      selections: UddfImportSelections.selectAll(data),
      repositories: _buildRepositories(),
      diverId: diverId,
    );
    expect(result.dives, 2);
    expect(result.tags, 2, reason: '"reef" is shared, not created twice');

    final dives = {
      for (final row in await db.select(db.dives).get()) row.diveNumber: row,
    };
    final tagRepository = TagRepository();
    Future<Set<String>> tagNamesOf(int diveNumber) async => {
      for (final tag in await tagRepository.getTagsForDive(
        dives[diveNumber]!.id,
      ))
        tag.name,
    };

    expect(await tagNamesOf(1), {'reef', 'night'});
    expect(await tagNamesOf(2), {'reef'});
    expect(dives[1]!.notes, 'Saw a turtle\nSuit: 7mm Wetsuit');
  });
}
