import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/data/repositories/service_kind_repository.dart';
import 'package:submersion/features/equipment/data/repositories/service_schedule_repository.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_attribute.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/exposure_unit.dart';
import 'package:submersion/features/equipment/domain/entities/service_kind.dart';

import '../../../helpers/test_database.dart';

void main() {
  setUp(() async {
    await setUpTestDatabase();
  });
  tearDown(tearDownTestDatabase);

  test('a custom kind round-trips its exposure map', () async {
    final repo = ServiceKindRepository();
    final now = DateTime.now();
    final created = await repo.createKind(
      ServiceKind(
        id: '',
        name: 'Seal check',
        exposureIntervals: const {ExposureUnit.saltHours: 120},
        createdAt: now,
        updatedAt: now,
      ),
    );
    final loaded = await repo.getKindById(created.id);
    expect(loaded!.exposureIntervals, {ExposureUnit.saltHours: 120.0});

    await repo.updateKind(
      loaded.copyWith(exposureIntervals: const {ExposureUnit.coldDives: 10}),
    );
    final updated = await repo.getKindById(created.id);
    expect(updated!.exposureIntervals, {ExposureUnit.coldDives: 10.0});
  });

  test('built-in kinds surface their seeded defaults', () async {
    final reg = await ServiceKindRepository().getKindById('regulator-service');
    expect(reg!.exposureIntervals, {ExposureUnit.coldDives: 50.0});
    expect(reg.applicableTypes, [EquipmentType.regulator]);
    final o2 = await ServiceKindRepository().getKindById('o2-clean');
    expect(o2!.applicableTypes, [EquipmentType.tank, EquipmentType.regulator]);
  });

  test('a schedule round-trips its exposure map', () async {
    final equipmentRepo = EquipmentRepository();
    final reg = await equipmentRepo.createEquipment(
      const EquipmentItem(id: '', name: 'Reg', type: EquipmentType.regulator),
    );
    final scheduleRepo = ServiceScheduleRepository();
    final schedules = await scheduleRepo.getSchedulesForEquipment(reg.id);
    final regService = schedules.firstWhere(
      (s) => s.serviceKindId == 'regulator-service',
    );
    expect(regService.exposureIntervals, isEmpty);
    await scheduleRepo.updateSchedule(
      regService.copyWith(
        exposureIntervals: const {ExposureUnit.coldDives: 25},
      ),
    );
    final reloaded = await scheduleRepo.getSchedulesForEquipment(reg.id);
    expect(
      reloaded
          .firstWhere((s) => s.serviceKindId == 'regulator-service')
          .exposureIntervals,
      {ExposureUnit.coldDives: 25.0},
    );
  });

  test('a child item keeps its parent link and install date', () async {
    final repo = EquipmentRepository();
    final unit = await repo.createEquipment(
      const EquipmentItem(id: '', name: 'JJ', type: EquipmentType.rebreather),
    );
    final installed = DateTime(2026, 3, 1);
    final cell = await repo.createEquipment(
      EquipmentItem(
        id: '',
        name: 'Cell 1',
        type: EquipmentType.o2Cell,
        parentEquipmentId: unit.id,
        attributes: [
          EquipmentAttribute.curated(
            equipmentId: '',
            key: 'installed_date',
            valueNum: installed.millisecondsSinceEpoch.toDouble(),
          ),
        ],
      ),
    );
    final loaded = await repo.getEquipmentById(cell.id);
    expect(loaded!.parentEquipmentId, unit.id);
    expect(loaded.installedDate, installed);

    final children = await repo.getChildEquipment(unit.id);
    expect(children.map((c) => c.id), [cell.id]);

    await repo.updateEquipment(loaded.copyWith(clearParentEquipmentId: true));
    expect((await repo.getEquipmentById(cell.id))!.parentEquipmentId, isNull);
  });
}
