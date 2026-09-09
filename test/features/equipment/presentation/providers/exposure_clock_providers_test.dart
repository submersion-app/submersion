import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/data/repositories/service_schedule_repository.dart';
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
}
