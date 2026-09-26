import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/cylinder_passports/data/repositories/cylinder_fill_repository.dart';
import 'package:submersion/features/cylinder_passports/data/repositories/cylinder_passport_repository.dart';
import 'package:submersion/features/cylinder_passports/data/services/passport_adoption_service.dart';
import 'package:submersion/features/cylinder_passports/domain/entities/cylinder_fill.dart';
import 'package:submersion/features/cylinder_passports/domain/entities/cylinder_passport_payload.dart';
import 'package:submersion/features/equipment/data/repositories/service_schedule_repository.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';

import '../../../../helpers/test_database.dart';

void main() {
  const id = '8f3a5c1e-1b2c-4d5e-8f90-1234567890ab';
  final now = DateTime(2026, 9, 26, 10);
  late AppDatabase db;
  late PassportAdoptionService service;

  final full = CylinderPassportPayload(
    passportId: id,
    writtenOn: DateTime(2026, 9, 1),
    name: 'Club 10',
    serial: 'AB12345',
    volumeL: 10,
    workingPressureBar: 300,
    material: TankMaterial.steel,
    valve: PassportValve.din,
    lastHydro: DateTime(2024, 6, 14),
    lastVip: DateTime(2026, 3, 2),
    o2Clean: true,
  );

  setUp(() async {
    db = await setUpTestDatabase();
    service = PassportAdoptionService();
    final t = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.divers)
        .insert(
          DiversCompanion.insert(
            id: 'd1',
            name: 'd1',
            createdAt: t,
            updatedAt: t,
          ),
        );
  });
  tearDown(tearDownTestDatabase);

  Future<int> tankCount() async => (await (db.select(
    db.equipment,
  )..where((e) => e.type.equals('tank'))).get()).length;

  test('creates a tank with the tag spec and its passport id', () async {
    final item = await service.adopt(
      full,
      diverId: 'd1',
      fallbackName: 'Cylinder',
      now: now,
    );
    expect(item.type, EquipmentType.tank);
    expect(item.name, 'Club 10');
    expect(item.serialNumber, 'AB12345');
    expect(item.diverId, 'd1');
    expect(item.volumeL, 10);
    expect(item.workingPressureBar, 300);
    expect(item.tankMaterial, TankMaterial.steel);
    expect(item.attrText('valve_type'), 'din');
    expect(await CylinderPassportRepository().getPassportId(item.id), id);
  });

  test('sets clock baselines from the tag, never service records', () async {
    final item = await service.adopt(
      full,
      diverId: 'd1',
      fallbackName: 'Cylinder',
      now: now,
    );
    final schedules = {
      for (final s
          in await ServiceScheduleRepository().getSchedulesForEquipment(
            item.id,
          ))
        s.serviceKindId: s,
    };
    expect(schedules['hydro']!.anchorDate, DateTime(2024, 6, 14));
    expect(schedules['hydro']!.anchorSetAt, now);
    expect(schedules['vip']!.anchorDate, DateTime(2026, 3, 2));
    expect(schedules['o2-clean']!.anchorDate, DateTime(2026, 9, 1));
    expect(await db.select(db.serviceRecords).get(), isEmpty);
  });

  test('fills already logged under the tag follow the new cylinder', () async {
    await CylinderFillRepository().create(
      CylinderFill(
        id: 'f1',
        passportId: id,
        filledAt: now,
        o2Percent: 32,
        createdAt: now,
        updatedAt: now,
      ),
    );
    final item = await service.adopt(
      full,
      diverId: 'd1',
      fallbackName: 'Cylinder',
      now: now,
    );
    expect(
      (await CylinderFillRepository().getById('f1'))!.equipmentId,
      item.id,
    );
  });

  test('an identity-only tag makes a named tank with open clocks', () async {
    final item = await service.adopt(
      const CylinderPassportPayload(passportId: id),
      diverId: 'd1',
      fallbackName: 'Cylinder',
      now: now,
    );
    expect(item.name, 'Cylinder');
    expect(item.volumeL, isNull);
    final schedules = await ServiceScheduleRepository()
        .getSchedulesForEquipment(item.id);
    expect(schedules.every((s) => s.anchorDate == null), isTrue);
    expect(schedules.any((s) => s.serviceKindId == 'o2-clean'), isFalse);
  });

  test('a held tag creates nothing', () async {
    final t = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.equipment)
        .insert(
          EquipmentCompanion.insert(
            id: 'eq-held',
            name: 'Dad 12',
            type: 'tank',
            createdAt: t,
            updatedAt: t,
            diverId: const Value('d1'),
          ),
        );
    await CylinderPassportRepository().assignPassportId(
      equipmentId: 'eq-held',
      passportId: id,
      diverId: 'd1',
    );
    final before = await tankCount();
    await expectLater(
      service.adopt(full, diverId: 'd1', fallbackName: 'Cylinder', now: now),
      throwsA(
        isA<PassportIdInUse>().having(
          (e) => e.equipmentId,
          'holder',
          'eq-held',
        ),
      ),
    );
    expect(await tankCount(), before);
    expect(
      (await db.select(db.equipmentAttributes).get()).where(
        (a) => a.attrKey == EquipmentAttrKeys.volumeL,
      ),
      isEmpty,
    );
  });
}
