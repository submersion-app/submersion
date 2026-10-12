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
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_set_repository_impl.dart';
import 'package:submersion/features/equipment/data/repositories/service_kind_repository.dart';
import 'package:submersion/features/equipment/data/repositories/service_schedule_repository.dart';
import 'package:submersion/features/tags/data/repositories/tag_repository.dart';
import 'package:submersion/features/trips/data/repositories/trip_repository.dart';

import '../../../../helpers/test_database.dart';

/// A backup's custom service kinds come in only with its gear (issue
/// #2651): a diver who imports just the dives gets no new service types.
void main() {
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
    final t = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.divers)
        .insert(
          DiversCompanion.insert(
            id: 'd1',
            name: 'D',
            createdAt: t,
            updatedAt: t,
          ),
        );
  });
  tearDown(tearDownTestDatabase);

  ImportRepositories repositories() => ImportRepositories(
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
    serviceKindRepository: ServiceKindRepository(),
    serviceScheduleRepository: ServiceScheduleRepository(),
  );

  Future<List<String>> customKindNames() async => [
    for (final k in await ServiceKindRepository().getAllKinds(diverId: 'd1'))
      if (!k.isBuiltIn) k.name,
  ];

  const data = UddfImportResult(
    serviceKinds: [
      {'id': 'k-burst', 'name': 'Burst disc'},
    ],
    equipment: [
      {
        'uddfId': 'equip_a',
        'name': 'AL80',
        'type': 'tank',
        'serviceSchedules': [
          {'kindRef': 'k-burst'},
        ],
      },
    ],
  );

  test('no gear selected: no service kinds are created', () async {
    await UddfEntityImporter().import(
      data: data,
      selections: const UddfImportSelections(),
      repositories: repositories(),
      diverId: 'd1',
    );
    expect(await customKindNames(), isEmpty);
  });

  test('gear selected: the kind comes with it', () async {
    await UddfEntityImporter().import(
      data: data,
      selections: const UddfImportSelections(equipment: {0}),
      repositories: repositories(),
      diverId: 'd1',
    );
    expect(await customKindNames(), ['Burst disc']);
  });

  test('without the kind repository, an item keeps its default '
      'clocks', () async {
    await UddfEntityImporter().import(
      data: const UddfImportResult(
        equipment: [
          {
            'uddfId': 'equip_a',
            'name': 'AL80',
            'type': 'tank',
            'serviceSchedules': [
              {'kindRef': 'hydro', 'intervalDays': 1095},
            ],
          },
        ],
      ),
      selections: const UddfImportSelections(equipment: {0}),
      repositories: ImportRepositories(
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
        serviceScheduleRepository: ServiceScheduleRepository(),
      ),
      diverId: 'd1',
    );
    final item = (await EquipmentRepository().getAllEquipment(
      diverId: 'd1',
    )).single;
    final kinds = {
      for (final s
          in await ServiceScheduleRepository().getSchedulesForEquipment(
            item.id,
          ))
        s.serviceKindId,
    };
    expect(kinds, containsAll(['hydro', 'vip']));
  });
}
