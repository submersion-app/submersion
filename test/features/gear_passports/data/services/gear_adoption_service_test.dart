import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/cylinder_passports/data/repositories/cylinder_passport_repository.dart';
import 'package:submersion/features/equipment/data/repositories/service_schedule_repository.dart';
import 'package:submersion/features/gear_passports/data/services/gear_adoption_service.dart';
import 'package:submersion/features/gear_passports/domain/entities/gear_tag_payload.dart';

import '../../../../helpers/test_database.dart';

void main() {
  const id = '8f3a5c1e-1b2c-4d5e-8f90-1234567890ab';
  late AppDatabase db;
  late GearAdoptionService service;

  final tag = GearTagPayload(
    passportId: id,
    typeCode: 'regulator',
    writtenOn: DateTime(2026, 10, 1),
    name: 'Club reg 4',
    brand: 'Scubapro',
    model: 'MK25',
    serial: 'SP-4',
    lastService: DateTime(2026, 2, 14),
  );

  setUp(() async {
    db = await setUpTestDatabase();
    service = GearAdoptionService();
    final t = DateTime.now().millisecondsSinceEpoch;
    for (final d in ['d1', 'd2']) {
      await db
          .into(db.divers)
          .insert(
            DiversCompanion.insert(id: d, name: d, createdAt: t, updatedAt: t),
          );
    }
  });
  tearDown(tearDownTestDatabase);

  test('creates an item of the tag type with its fields and id', () async {
    final item = await service.adopt(tag, diverId: 'd1', fallbackName: 'Gear');
    expect(item.type, EquipmentType.regulator);
    expect(item.name, 'Club reg 4');
    expect(item.brand, 'Scubapro');
    expect(item.model, 'MK25');
    expect(item.serialNumber, 'SP-4');
    expect(item.diverId, 'd1');
    expect(await CylinderPassportRepository().getPassportId(item.id), id);
  });

  test('an unknown type becomes other, a missing name the fallback', () async {
    final item = await service.adopt(
      const GearTagPayload(passportId: id, typeCode: 'jetpack'),
      diverId: 'd1',
      fallbackName: 'Gear',
    );
    expect(item.type, EquipmentType.other);
    expect(item.name, 'Gear');
  });

  test(
    'the last service date becomes every schedule baseline, with no record',
    () async {
      final at = DateTime(2026, 10, 10, 12);
      final item = await service.adopt(
        tag,
        diverId: 'd1',
        fallbackName: 'Gear',
        now: at,
      );
      final schedules = await ServiceScheduleRepository()
          .getSchedulesForEquipment(item.id);
      expect(schedules, isNotEmpty, reason: 'a regulator gets default clocks');
      for (final s in schedules) {
        expect(s.anchorDate, DateTime(2026, 2, 14), reason: s.serviceKindId);
      }
      expect(await db.select(db.serviceRecords).get(), isEmpty);
    },
  );

  test('no last service date leaves the baselines alone', () async {
    final item = await service.adopt(
      tag.copyWith(clearLastService: true),
      diverId: 'd1',
      fallbackName: 'Gear',
    );
    final schedules = await ServiceScheduleRepository()
        .getSchedulesForEquipment(item.id);
    for (final s in schedules) {
      expect(s.anchorDate, isNull, reason: s.serviceKindId);
    }
  });

  test(
    'refuses, creating nothing, when an in-service item holds the id',
    () async {
      await service.adopt(tag, diverId: 'd1', fallbackName: 'Gear');
      await expectLater(
        service.adopt(tag, diverId: 'd2', fallbackName: 'Gear'),
        throwsA(isA<PassportIdInUse>()),
      );
      expect(await db.select(db.equipment).get(), hasLength(1));
    },
  );
}
