import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart' hide ServiceRecord;
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/data/repositories/service_record_repository.dart';
import 'package:submersion/features/equipment/data/repositories/service_schedule_repository.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/exposure_unit.dart';
import 'package:submersion/features/equipment/domain/entities/service_clock_status.dart';
import 'package:submersion/features/equipment/domain/entities/service_record.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/test_database.dart';

/// A clock's Baseline date is where it starts counting, even when a service
/// of the same kind was logged before the diver set it; logging a newer
/// service hands the clock back to the records.
void main() {
  late AppDatabase db;
  late ProviderContainer container;
  final now = DateTime.now();
  final yearAgo = DateTime(now.year - 1, now.month, now.day);

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

  Future<void> linkDive(String id, String equipmentId, int daysAgo) async {
    final ms = now.subtract(Duration(days: daysAgo)).millisecondsSinceEpoch;
    await db
        .into(db.dives)
        .insert(
          DivesCompanion.insert(
            id: id,
            diveDateTime: ms,
            createdAt: ms,
            updatedAt: ms,
          ).copyWith(runtime: const Value(3600)),
        );
    await db
        .into(db.diveEquipment)
        .insert(
          DiveEquipmentCompanion.insert(diveId: id, equipmentId: equipmentId),
        );
  }

  /// A regulator with three dives over the past 200 days.
  Future<EquipmentItem> regulatorWithDives() async {
    final reg = await EquipmentRepository().createEquipment(
      const EquipmentItem(id: '', name: 'Reg', type: EquipmentType.regulator),
    );
    await linkDive('d1', reg.id, 200);
    await linkDive('d2', reg.id, 100);
    await linkDive('d3', reg.id, 10);
    return reg;
  }

  ServiceRecord regService(String equipmentId, DateTime date) => ServiceRecord(
    id: '',
    equipmentId: equipmentId,
    serviceCategory: ServiceCategory.annual,
    serviceKindId: 'regulator-service',
    serviceDate: date,
    createdAt: now,
    updatedAt: now,
  );

  Future<void> setBaseline(String equipmentId, DateTime baseline) async {
    final repo = ServiceScheduleRepository();
    final schedule = (await repo.getSchedulesForEquipment(
      equipmentId,
    )).firstWhere((s) => s.serviceKindId == 'regulator-service');
    await repo.updateSchedule(
      schedule.withBaseline(baseline, now: DateTime.now()),
    );
  }

  /// The regulator clock as the page would read it. [fresh] forces a
  /// re-read; leave it off to prove a write refreshed the cached clock
  /// itself.
  Future<ServiceClockStatus> regClock(
    String equipmentId, {
    bool fresh = true,
  }) async {
    if (fresh) container.invalidate(serviceClockStatusesProvider(equipmentId));
    final statuses = await container.read(
      serviceClockStatusesProvider(equipmentId).future,
    );
    return statuses.firstWhere(
      (s) => s.schedule.serviceKindId == 'regulator-service',
    );
  }

  test('a baseline set after a service was logged counts from the '
      'baseline', () async {
    // The reported bug: a service logged yesterday silently outranked a
    // baseline set to a year ago, so the clock read 100 of 100 dives left.
    final reg = await regulatorWithDives();
    await ServiceRecordRepository().createRecord(
      regService(reg.id, now.subtract(const Duration(days: 1))),
    );
    await setBaseline(reg.id, yearAgo);

    final clock = await regClock(reg.id);
    expect(clock.anchor, yearAgo);
    expect(clock.usageByUnit[ExposureUnit.dives]!.since, 3);
  });

  test('logging a newer service clears the baseline and restarts the '
      'clock', () async {
    final reg = await regulatorWithDives();
    await setBaseline(reg.id, yearAgo);
    expect((await regClock(reg.id)).usageByUnit[ExposureUnit.dives]!.since, 3);

    final fiftyDaysAgo = now.subtract(const Duration(days: 50));
    final serviced = DateTime(
      fiftyDaysAgo.year,
      fiftyDaysAgo.month,
      fiftyDaysAgo.day,
    );
    await container
        .read(serviceRecordNotifierProvider(reg.id).notifier)
        .addRecord(regService(reg.id, serviced));

    final clock = await regClock(reg.id, fresh: false);
    expect(clock.schedule.anchorDate, isNull);
    expect(clock.anchor, serviced);
    expect(clock.usageByUnit[ExposureUnit.dives]!.since, 1);
  });

  test('logging a backdated service keeps the baseline', () async {
    final reg = await regulatorWithDives();
    await setBaseline(reg.id, yearAgo);

    await container
        .read(serviceRecordNotifierProvider(reg.id).notifier)
        .addRecord(regService(reg.id, DateTime(now.year - 3)));

    final clock = await regClock(reg.id, fresh: false);
    expect(clock.schedule.anchorDate, yearAgo);
    expect(clock.usageByUnit[ExposureUnit.dives]!.since, 3);
  });

  test('a newer service that never went through the notifier still takes '
      'the clock over', () async {
    // A service synced from another device, or logged on a build that
    // knows nothing of baselines, is written without clearing anything.
    // The clock must still restart from it.
    final reg = await regulatorWithDives();
    await setBaseline(reg.id, yearAgo);
    // Strictly after the baseline's set time, whatever the clock's
    // resolution on this machine.
    await Future<void>.delayed(const Duration(milliseconds: 5));

    final fiftyDaysAgo = now.subtract(const Duration(days: 50));
    final serviced = DateTime(
      fiftyDaysAgo.year,
      fiftyDaysAgo.month,
      fiftyDaysAgo.day,
    );
    await ServiceRecordRepository().createRecord(regService(reg.id, serviced));

    final clock = await regClock(reg.id);
    expect(clock.schedule.anchorDate, yearAgo);
    expect(clock.anchor, serviced);
    expect(clock.usageByUnit[ExposureUnit.dives]!.since, 1);
  });

  test('a baseline set before this rule keeps the old one: any service of '
      'the kind wins', () async {
    // No set time is how every pre-v211 baseline and legacy clock arrives,
    // on every device; those clocks must read as they always have.
    final reg = await regulatorWithDives();
    await ServiceRecordRepository().createRecord(
      regService(reg.id, DateTime(now.year - 3)),
    );
    final repo = ServiceScheduleRepository();
    final schedule = (await repo.getSchedulesForEquipment(
      reg.id,
    )).firstWhere((s) => s.serviceKindId == 'regulator-service');
    await repo.updateSchedule(schedule.copyWith(anchorDate: yearAgo));

    final clock = await regClock(reg.id);
    expect(clock.anchor, DateTime(now.year - 3));
  });
}
