import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/data/repositories/service_schedule_repository.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_attribute.dart';
import 'package:submersion/features/equipment/domain/entities/service_schedule.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/exposure_unit.dart';
import 'package:submersion/features/equipment/domain/entities/service_clock_status.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late ProviderContainer container;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    db = await setUpTestDatabase();
    container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
  });
  tearDown(() async {
    container.dispose();
    await tearDownTestDatabase();
  });

  var diveIndex = 0;
  Future<void> coldDive(String id, String equipmentId, double temp) async {
    final ms = DateTime.utc(2026, 1, 1 + diveIndex++).millisecondsSinceEpoch;
    await db
        .into(db.dives)
        .insert(
          DivesCompanion.insert(
            id: id,
            diveDateTime: ms,
            createdAt: ms,
            updatedAt: ms,
          ).copyWith(runtime: const Value(3600), waterTemp: Value(temp)),
        );
    await db
        .into(db.diveEquipment)
        .insert(
          DiveEquipmentCompanion.insert(diveId: id, equipmentId: equipmentId),
        );
  }

  test('the built-in regulator clock counts cold dives', () async {
    // Purchased before the fixture dives so the clock anchor precedes them.
    final reg = await EquipmentRepository().createEquipment(
      EquipmentItem(
        id: '',
        name: 'Reg',
        type: EquipmentType.regulator,
        purchaseDate: DateTime(2025, 1, 1),
      ),
    );
    final scheduleRepo = ServiceScheduleRepository();
    final schedule = (await scheduleRepo.getSchedulesForEquipment(
      reg.id,
    )).firstWhere((s) => s.serviceKindId == 'regulator-service');
    await scheduleRepo.updateSchedule(
      schedule.copyWith(exposureIntervals: const {ExposureUnit.coldDives: 2}),
    );
    await coldDive('d1', reg.id, 4);
    await coldDive('d2', reg.id, 24);
    await coldDive('d3', reg.id, 9.5);

    final statuses = await container.read(
      serviceClockStatusesProvider(reg.id).future,
    );
    final status = statuses.firstWhere(
      (s) => s.schedule.serviceKindId == 'regulator-service',
    );
    expect(status.usageByUnit[ExposureUnit.coldDives]!.since, 2);
    expect(status.severity, ServiceClockSeverity.overdue);
  });

  test('a battery retired by status alone does not stop the parent cycles '
      'clock', () async {
    // A legacy row can be retired with isActive left true. The exposure
    // card already ignores it; the clock must too, or the card counts
    // cycles the clock it explains has switched off.
    final ccr = await EquipmentRepository().createEquipment(
      EquipmentItem(
        id: '',
        name: 'CCR',
        type: EquipmentType.rebreather,
        purchaseDate: DateTime(2025, 1, 1),
      ),
    );
    await db
        .into(db.equipment)
        .insert(
          EquipmentCompanion.insert(
            id: 'old-battery',
            name: 'Old battery',
            type: 'battery',
            createdAt: 1,
            updatedAt: 1,
          ).copyWith(
            parentEquipmentId: Value(ccr.id),
            status: const Value('retired'),
            isActive: const Value(true),
          ),
        );
    final scheduleRepo = ServiceScheduleRepository();
    final schedule = (await scheduleRepo.getSchedulesForEquipment(
      ccr.id,
    )).first;
    await scheduleRepo.updateSchedule(
      schedule.copyWith(exposureIntervals: const {ExposureUnit.cycles: 5}),
    );
    await coldDive('d1', ccr.id, 20);
    await (db.update(db.dives)..where((t) => t.id.equals('d1'))).write(
      const DivesCompanion(diveMode: Value('ccr')),
    );

    final statuses = await container.read(
      serviceClockStatusesProvider(ccr.id).future,
    );
    final status = statuses.firstWhere((s) => s.schedule.id == schedule.id);
    expect(status.usageByUnit[ExposureUnit.cycles]!.since, 1);
  });

  test(
    'an open clock follows a new dive link and an install-date edit',
    () async {
      // The exposure card refreshes on dive detail and attribute writes; the
      // clocks it explains must too, or the two cards disagree until some
      // unrelated equipment row changes.
      final ccr = await EquipmentRepository().createEquipment(
        EquipmentItem(
          id: '',
          name: 'CCR',
          type: EquipmentType.rebreather,
          purchaseDate: DateTime(2025, 1, 1),
        ),
      );
      final cell = await EquipmentRepository().createEquipment(
        EquipmentItem(
          id: '',
          name: 'Cell 1',
          type: EquipmentType.o2Cell,
          parentEquipmentId: ccr.id,
          purchaseDate: DateTime(2025, 1, 1),
        ),
      );
      await EquipmentRepository().saveAttributes(cell.id, [
        EquipmentAttribute.curated(
          equipmentId: cell.id,
          key: EquipmentAttrKeys.installedDate,
          valueNum: DateTime.utc(2026, 6).millisecondsSinceEpoch.toDouble(),
        ),
      ]);
      final scheduleRepo = ServiceScheduleRepository();
      final schedule = await scheduleRepo.createSchedule(
        ServiceSchedule(
          id: '',
          equipmentId: cell.id,
          serviceKindId: 'o2-cell-replacement',
          intervalDives: 50,
          createdAt: DateTime(2025),
          updatedAt: DateTime(2025),
        ),
      );
      await coldDive('d1', ccr.id, 20);

      final sub = container.listen(
        serviceClockStatusesProvider(cell.id),
        (_, _) {},
      );
      addTearDown(sub.close);
      Future<double> dives() async =>
          (await container.read(serviceClockStatusesProvider(cell.id).future))
              .firstWhere((s) => s.schedule.id == schedule.id)
              .usageByUnit[ExposureUnit.dives]!
              .since;
      Future<double> settle(double want) async {
        var got = await dives();
        for (var i = 0; i < 100 && got != want; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
          got = await dives();
        }
        return got;
      }

      // Installed in June: the January dive is not the cell's yet.
      expect(await dives(), 0);
      await EquipmentRepository().saveAttributes(cell.id, [
        EquipmentAttribute.curated(
          equipmentId: cell.id,
          key: EquipmentAttrKeys.installedDate,
          valueNum: DateTime.utc(2025, 6).millisecondsSinceEpoch.toDouble(),
        ),
      ]);
      expect(await settle(1), 1);

      // A second dive linked to the unit writes no equipment row.
      await coldDive('d2', ccr.id, 20);
      expect(await settle(2), 2);
    },
  );

  test('a replaced cell\'s clock stops at its successor', () async {
    // The exposure card stops a replaced part's history when the next part
    // of its type went into the same slot; its clocks (and the findings and
    // reminders built on the same samples) must stop there too.
    final repo = EquipmentRepository();
    final ccr = await repo.createEquipment(
      EquipmentItem(
        id: '',
        name: 'CCR',
        type: EquipmentType.rebreather,
        purchaseDate: DateTime(2025, 1, 1),
      ),
    );
    Future<EquipmentItem> cell(String name, DateTime installed, bool fitted) =>
        repo.createEquipment(
          EquipmentItem(
            id: '',
            name: name,
            type: EquipmentType.o2Cell,
            parentEquipmentId: ccr.id,
            purchaseDate: DateTime(2025, 1, 1),
            status: fitted ? EquipmentStatus.active : EquipmentStatus.retired,
            isActive: fitted,
            attributes: [
              EquipmentAttribute.curated(
                equipmentId: '',
                key: EquipmentAttrKeys.installedDate,
                valueNum: installed.millisecondsSinceEpoch.toDouble(),
              ),
              EquipmentAttribute.curated(
                equipmentId: '',
                key: EquipmentAttrKeys.cellSlot,
                valueNum: 1,
              ),
            ],
          ),
        );
    // Install dates as the date picker stores them: local midnight of the
    // chosen day (parentDivesFrom reads that day in the dive frame).
    final old = await cell('Old cell', DateTime(2025, 6), false);
    await cell('New cell', DateTime(2026, 1, 3), true);
    final schedule = await ServiceScheduleRepository().createSchedule(
      ServiceSchedule(
        id: '',
        equipmentId: old.id,
        serviceKindId: 'o2-cell-replacement',
        intervalDives: 50,
        createdAt: DateTime(2025),
        updatedAt: DateTime(2025),
      ),
    );
    // coldDive dates the dives 1, 2, 3 January 2026 from a counter shared
    // across this file; reset it so the first two are the old cell's and
    // the third its successor's whatever ran before.
    diveIndex = 0;
    await coldDive('d1', ccr.id, 20);
    await coldDive('d2', ccr.id, 20);
    await coldDive('d3', ccr.id, 20);

    final statuses = await container.read(
      serviceClockStatusesProvider(old.id).future,
    );
    final status = statuses.firstWhere((s) => s.schedule.id == schedule.id);
    expect(status.usageByUnit[ExposureUnit.dives]!.since, 2);
  });

  test(
    'changing the cold threshold changes the count on the next read',
    () async {
      final reg = await EquipmentRepository().createEquipment(
        EquipmentItem(
          id: '',
          name: 'Reg',
          type: EquipmentType.regulator,
          purchaseDate: DateTime(2025, 1, 1),
        ),
      );
      await coldDive('d1', reg.id, 12);
      // The notifier's initial load would overwrite a value set before it
      // completes, so wait for it before moving the line.
      final notifier = container.read(settingsProvider.notifier);
      await notifier.initialLoad;
      await notifier.setColdWaterThresholdC(15);
      expect(container.read(settingsProvider).coldWaterThresholdC, 15);
      container.invalidate(serviceClockStatusesProvider(reg.id));
      final statuses = await container.read(
        serviceClockStatusesProvider(reg.id).future,
      );
      final status = statuses.firstWhere(
        (s) => s.schedule.serviceKindId == 'regulator-service',
      );
      expect(status.usageByUnit[ExposureUnit.coldDives]!.since, 1);
    },
  );

  test('a registry edit reaches a transmitter\'s clock', () async {
    // A transmitter's dives are the tanks that carried its registered
    // serials; assigning a serial writes only the registry.
    final tx = await EquipmentRepository().createEquipment(
      EquipmentItem(
        id: '',
        name: 'Tx',
        type: EquipmentType.transmitter,
        purchaseDate: DateTime(2025, 1, 1),
      ),
    );
    final schedule = await ServiceScheduleRepository().createSchedule(
      ServiceSchedule(
        id: '',
        equipmentId: tx.id,
        serviceKindId: 'regulator-service',
        exposureIntervals: const {ExposureUnit.dives: 10},
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
    );
    final ms = DateTime.utc(2026, 1, 1).millisecondsSinceEpoch;
    await db
        .into(db.dives)
        .insert(
          DivesCompanion.insert(
            id: 'd1',
            diveDateTime: ms,
            createdAt: ms,
            updatedAt: ms,
          ).copyWith(runtime: const Value(3600)),
        );
    await db.customStatement(
      "INSERT INTO dive_tanks (id, dive_id, transmitter_serial) "
      "VALUES ('t1', 'd1', '555')",
    );
    final sub = container.listen(
      serviceClockStatusesProvider(tx.id),
      (_, _) {},
    );
    addTearDown(sub.close);
    Future<double?> since() async =>
        (await container.read(serviceClockStatusesProvider(tx.id).future))
            .firstWhere((s) => s.schedule.id == schedule.id)
            .usageByUnit[ExposureUnit.dives]
            ?.since;
    expect(await since(), 0);

    // Through drift, so the registry's change stream ticks as the app's
    // own writes do.
    await db
        .into(db.transmitters)
        .insert(
          TransmittersCompanion.insert(
            id: 'r1',
            label: 'Main',
            tankRole: 'backGas',
            createdAt: 1,
            updatedAt: 1,
          ).copyWith(
            transmitterSerial: const Value('555'),
            transmitterEquipmentId: Value(tx.id),
          ),
        );
    var now = await since();
    for (var i = 0; i < 50 && now != 1; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
      now = await since();
    }
    expect(now, 1);
  });
}
