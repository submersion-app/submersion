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
import 'package:submersion/features/equipment/data/repositories/service_record_repository.dart';
import 'package:submersion/features/equipment/data/repositories/service_schedule_repository.dart';
import 'package:submersion/features/tags/data/repositories/tag_repository.dart';
import 'package:submersion/features/trips/data/repositories/trip_repository.dart';

import '../../../../helpers/test_database.dart';

/// Issue #3662: a backup written before v317 carries a tank's inspection
/// dates and clocks that never took them. Restoring its clocks must not
/// leave the tank counting from its purchase date.
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
    serviceRecordRepository: ServiceRecordRepository(),
  );

  final hydroDate = DateTime(2026, 9, 15);

  UddfImportResult backup({List<Map<String, dynamic>> records = const []}) =>
      UddfImportResult(
        equipment: [
          {
            'uddfId': 'equip_a',
            'name': 'AL80',
            'type': 'tank',
            'attributes': [
              {
                'key': 'last_hydro_test',
                'valueNum': hydroDate.millisecondsSinceEpoch,
              },
            ],
            'serviceSchedules': [
              {'kindRef': 'hydro', 'intervalDays': 1825},
            ],
          },
        ],
        serviceRecords: records,
      );

  Future<DateTime?> hydroAnchor() async {
    final item = (await EquipmentRepository().getAllEquipment(
      diverId: 'd1',
    )).single;
    return (await ServiceScheduleRepository().getSchedulesForEquipment(
      item.id,
    )).singleWhere((s) => s.serviceKindId == 'hydro').anchorDate;
  }

  test('the restored clock counts from the tank\'s hydro date', () async {
    await UddfEntityImporter().import(
      data: backup(),
      selections: const UddfImportSelections(equipment: {0}),
      repositories: repositories(),
      diverId: 'd1',
    );

    expect(await hydroAnchor(), hydroDate);
  });

  test('a restored clock with a hydro logged takes no baseline', () async {
    await UddfEntityImporter().import(
      data: backup(
        records: [
          {
            'equipmentRef': 'equip_a',
            'serviceDate': DateTime(2026, 1, 10),
            'serviceKindRef': 'hydro',
          },
        ],
      ),
      selections: const UddfImportSelections(equipment: {0}),
      repositories: repositories(),
      diverId: 'd1',
    );

    expect(await hydroAnchor(), isNull);
  });

  test('a clock that cannot be anchored does not fail the import', () async {
    await db.customStatement('''
      CREATE TRIGGER refuse_baseline
      BEFORE UPDATE ON service_schedules
      WHEN NEW.anchor_date IS NOT NULL
      BEGIN SELECT RAISE(ABORT, 'no baseline'); END
    ''');

    await UddfEntityImporter().import(
      data: backup(),
      selections: const UddfImportSelections(equipment: {0}),
      repositories: repositories(),
      diverId: 'd1',
    );

    expect(await hydroAnchor(), isNull);
  });
}
