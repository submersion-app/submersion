import 'package:drift/drift.dart' hide isNull, isNotNull;
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

  test(
    'usage samples union dive_equipment and dive_tanks without doubles',
    () async {
      final tank = await makeTank();
      final now = DateTime.now().millisecondsSinceEpoch;

      Future<void> insertDive(String id, int? runtime, int? bottomTime) => db
          .into(db.dives)
          .insert(
            DivesCompanion.insert(
              id: id,
              diveDateTime: now,
              createdAt: now,
              updatedAt: now,
            ).copyWith(runtime: Value(runtime), bottomTime: Value(bottomTime)),
          );

      // Dive 1: linked via BOTH the junction and a dive_tanks row -> one
      // sample, duration from runtime.
      await insertDive('d1', 3600, 3000);
      await db
          .into(db.diveEquipment)
          .insert(
            DiveEquipmentCompanion.insert(diveId: 'd1', equipmentId: tank.id),
          );
      await db
          .into(db.diveTanks)
          .insert(
            DiveTanksCompanion.insert(
              id: 't1',
              diveId: 'd1',
            ).copyWith(equipmentId: Value(tank.id)),
          );

      // Dive 2: linked only via dive_tanks; no runtime -> bottom_time wins.
      await insertDive('d2', null, 1800);
      await db
          .into(db.diveTanks)
          .insert(
            DiveTanksCompanion.insert(
              id: 't2',
              diveId: 'd2',
            ).copyWith(equipmentId: Value(tank.id)),
          );

      // Dive 3: not linked to this equipment at all.
      await insertDive('d3', 999, null);

      final samples = await equipmentRepo.getUsageSamplesForEquipment(tank.id);
      expect(samples, hasLength(2));
      expect(samples.map((s) => s.durationSeconds).toSet(), {3600, 1800});
    },
  );

  test('getDueSoonWindowDays fallback chain', () async {
    // No diver id -> default.
    expect(await repo.getDueSoonWindowDays(), 30);
    // Unknown diver -> no settings row -> default.
    expect(await repo.getDueSoonWindowDays(diverId: 'nobody'), 30);

    // Row with malformed JSON -> default.
    await db.customStatement(
      "INSERT INTO divers (id, name, created_at, updated_at) "
      "VALUES ('d-bad', 'X', 0, 0)",
    );
    await db.customStatement(
      "INSERT INTO diver_settings "
      "(id, diver_id, service_reminder_days, created_at, updated_at) "
      "VALUES ('ds-bad', 'd-bad', 'not json', 0, 0)",
    );
    expect(await repo.getDueSoonWindowDays(diverId: 'd-bad'), 30);

    // Row with a valid list -> widest value.
    await db.customStatement(
      "UPDATE diver_settings SET service_reminder_days = '[3, 45, 7]' "
      "WHERE diver_id = 'd-bad'",
    );
    expect(await repo.getDueSoonWindowDays(diverId: 'd-bad'), 45);
  });

  test('usage samples honor the since filter', () async {
    final tank = await makeTank();
    final oldMs = DateTime(2020, 1, 1).millisecondsSinceEpoch;
    final newMs = DateTime(2026, 1, 1).millisecondsSinceEpoch;
    for (final (id, ms) in [('old', oldMs), ('new', newMs)]) {
      await db
          .into(db.dives)
          .insert(
            DivesCompanion.insert(
              id: id,
              diveDateTime: ms,
              createdAt: ms,
              updatedAt: ms,
            ).copyWith(bottomTime: const Value(600)),
          );
      await db
          .into(db.diveEquipment)
          .insert(
            DiveEquipmentCompanion.insert(diveId: id, equipmentId: tank.id),
          );
    }

    final all = await equipmentRepo.getUsageSamplesForEquipment(tank.id);
    expect(all, hasLength(2));
    final recent = await equipmentRepo.getUsageSamplesForEquipment(
      tank.id,
      since: DateTime(2025, 1, 1),
    );
    expect(recent, hasLength(1));
    expect(recent.single.date.year, 2026);
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
