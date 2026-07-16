import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/data/repositories/service_schedule_repository.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/service_schedule.dart';

import '../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late ServiceScheduleRepository repo;
  late EquipmentRepository equipmentRepo;

  setUp(() async {
    db = await setUpTestDatabase();
    repo = ServiceScheduleRepository();
    equipmentRepo = EquipmentRepository();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  Future<EquipmentItem> makeTank() => equipmentRepo.createEquipment(
    const EquipmentItem(id: '', name: 'AL80', type: EquipmentType.tank),
  );

  test('auto-attach creates hydro and vip (not o2-clean) for a tank', () async {
    final tank = await makeTank();
    final schedules = await repo.getSchedulesForEquipment(tank.id);
    final kindIds = schedules.map((s) => s.serviceKindId).toSet();
    expect(kindIds, containsAll(['hydro', 'vip']));
    expect(kindIds, isNot(contains('o2-clean'))); // autoAttach = false
  });

  test('auto-attach is idempotent', () async {
    final tank = await makeTank();
    await repo.autoAttachForEquipment(
      equipmentId: tank.id,
      type: EquipmentType.tank,
    );
    final schedules = await repo.getSchedulesForEquipment(tank.id);
    expect(schedules.where((s) => s.serviceKindId == 'hydro'), hasLength(1));
  });

  test('CRUD round-trip with overrides', () async {
    final tank = await makeTank();
    final created = await repo.createSchedule(
      ServiceSchedule(
        id: '',
        equipmentId: tank.id,
        serviceKindId: 'o2-clean',
        intervalDays: 180,
        anchorDate: DateTime(2026, 3, 1),
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      ),
    );
    expect(created.id, isNotEmpty);
    await repo.updateSchedule(created.copyWith(enabled: false));
    final reloaded = await repo.getSchedulesForEquipment(tank.id);
    final o2 = reloaded.firstWhere((s) => s.serviceKindId == 'o2-clean');
    expect(o2.enabled, isFalse);
    expect(o2.intervalDays, 180);
    expect(o2.anchorDate, DateTime(2026, 3, 1));
  });

  test('deleting equipment tombstones its schedules', () async {
    final tank = await makeTank();
    final before = await repo.getSchedulesForEquipment(tank.id);
    expect(before, isNotEmpty);
    await equipmentRepo.deleteEquipment(tank.id);
    final tombstones = await db
        .customSelect(
          "SELECT record_id FROM deletion_log "
          "WHERE entity_type = 'serviceSchedules'",
        )
        .get();
    expect(
      tombstones.map((r) => r.data['record_id']),
      containsAll(before.map((s) => s.id)),
    );
  });
}
