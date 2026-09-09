import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/data/repositories/service_record_repository.dart';
import 'package:submersion/features/equipment/data/repositories/service_schedule_repository.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/service_record.dart'
    as domain;
import 'package:submersion/features/notifications/data/repositories/scheduled_notification_repository.dart';
import 'package:submersion/features/notifications/data/services/notification_scheduler.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../helpers/test_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
  });
  tearDown(tearDownTestDatabase);

  Future<void> linkDive(
    String id,
    String equipmentId, {
    int daysAgo = 1,
  }) async {
    final ms = DateTime.now()
        .subtract(Duration(days: daysAgo))
        .millisecondsSinceEpoch;
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

  test('an overdue dives clock schedules one reminder per anchor', () async {
    final reg = await EquipmentRepository().createEquipment(
      EquipmentItem(
        id: '',
        name: 'Reg',
        type: EquipmentType.regulator,
        purchaseDate: DateTime(2025, 1, 1),
      ),
    );
    final scheduleRepo = ServiceScheduleRepository();
    final regService = (await scheduleRepo.getSchedulesForEquipment(
      reg.id,
    )).firstWhere((s) => s.serviceKindId == 'regulator-service');
    // Days trigger far away, dives trigger overdue.
    await scheduleRepo.updateSchedule(
      regService.copyWith(intervalDays: 3650, intervalDives: 1),
    );
    await linkDive('d1', reg.id);
    await linkDive('d2', reg.id);

    await NotificationScheduler().scheduleAll(settings: const AppSettings());
    var rows = await db.select(db.scheduledNotifications).get();
    final usage = rows.where(
      (r) => r.reminderDaysBefore == kUsageReminderDaysBefore,
    );
    expect(usage, hasLength(1));
    expect(usage.single.scheduleId, regService.id);
    // The row is tied to the anchor it was armed against (the purchase
    // date, with no record yet), not to the wall clock.
    expect(usage.single.createdAt, DateTime(2025, 1, 1).millisecondsSinceEpoch);

    // Idempotent across runs and across the expiry sweep.
    await NotificationScheduler().scheduleAll(settings: const AppSettings());
    await ScheduledNotificationRepository().deleteExpired();
    rows = await db.select(db.scheduledNotifications).get();
    expect(
      rows.where((r) => r.reminderDaysBefore == kUsageReminderDaysBefore),
      hasLength(1),
    );
  });

  test(
    'a service record logged before the reminder fires cancels it',
    () async {
      final reg = await EquipmentRepository().createEquipment(
        EquipmentItem(
          id: '',
          name: 'Reg',
          type: EquipmentType.regulator,
          purchaseDate: DateTime(2025, 1, 1),
        ),
      );
      final scheduleRepo = ServiceScheduleRepository();
      final regService = (await scheduleRepo.getSchedulesForEquipment(
        reg.id,
      )).firstWhere((s) => s.serviceKindId == 'regulator-service');
      // Two dives against a two-dive interval: overdue now, and after the
      // record the full interval remains, well outside the due-soon band.
      await scheduleRepo.updateSchedule(
        regService.copyWith(intervalDays: 3650, intervalDives: 2),
      );
      await linkDive('d1', reg.id);
      await linkDive('d2', reg.id);
      await NotificationScheduler().scheduleAll(settings: const AppSettings());
      expect(
        (await db.select(db.scheduledNotifications).get()).where(
          (r) => r.reminderDaysBefore == kUsageReminderDaysBefore,
        ),
        hasLength(1),
      );

      // Servicing the regulator today moves the anchor past the dive.
      final now = DateTime.now();
      await ServiceRecordRepository().createRecord(
        domain.ServiceRecord(
          id: '',
          equipmentId: reg.id,
          serviceCategory: ServiceCategory.annual,
          serviceKindId: 'regulator-service',
          serviceDate: now,
          createdAt: now,
          updatedAt: now,
        ),
      );
      await NotificationScheduler().scheduleAll(settings: const AppSettings());
      expect(
        (await db.select(db.scheduledNotifications).get()).where(
          (r) => r.reminderDaysBefore == kUsageReminderDaysBefore,
        ),
        isEmpty,
      );
    },
  );

  test(
    'a record that leaves the clock still due replaces the old reminder',
    () async {
      final reg = await EquipmentRepository().createEquipment(
        EquipmentItem(
          id: '',
          name: 'Reg',
          type: EquipmentType.regulator,
          purchaseDate: DateTime(2025, 1, 1),
        ),
      );
      final scheduleRepo = ServiceScheduleRepository();
      final regService = (await scheduleRepo.getSchedulesForEquipment(
        reg.id,
      )).firstWhere((s) => s.serviceKindId == 'regulator-service');
      await scheduleRepo.updateSchedule(
        regService.copyWith(intervalDays: 3650, intervalDives: 1),
      );
      await linkDive('d1', reg.id, daysAgo: 3);
      await NotificationScheduler().scheduleAll(settings: const AppSettings());
      final first = (await db.select(db.scheduledNotifications).get())
          .where((r) => r.reminderDaysBefore == kUsageReminderDaysBefore)
          .single;
      // The row carries the purchase-date anchor it was armed against.
      expect(first.createdAt, DateTime(2025, 1, 1).millisecondsSinceEpoch);

      // Today's record moves the anchor, and a dive after the record keeps
      // the one-dive clock overdue: the old reminder must go and exactly one
      // new one, tied to the new anchor, must stand.
      await linkDive('d2', reg.id, daysAgo: -1);
      final now = DateTime.now();
      await ServiceRecordRepository().createRecord(
        domain.ServiceRecord(
          id: '',
          equipmentId: reg.id,
          serviceCategory: ServiceCategory.annual,
          serviceKindId: 'regulator-service',
          serviceDate: now,
          createdAt: now,
          updatedAt: now,
        ),
      );
      await NotificationScheduler().scheduleAll(settings: const AppSettings());
      final rows = (await db.select(db.scheduledNotifications).get())
          .where((r) => r.reminderDaysBefore == kUsageReminderDaysBefore)
          .toList();
      expect(rows, hasLength(1));
      expect(rows.single.id, isNot(first.id));
      expect(rows.single.createdAt, now.millisecondsSinceEpoch);
    },
  );

  test('an ok usage clock schedules nothing', () async {
    final reg = await EquipmentRepository().createEquipment(
      EquipmentItem(
        id: '',
        name: 'Reg',
        type: EquipmentType.regulator,
        purchaseDate: DateTime(2025, 1, 1),
      ),
    );
    await linkDive('d1', reg.id);
    await NotificationScheduler().scheduleAll(settings: const AppSettings());
    final rows = await db.select(db.scheduledNotifications).get();
    expect(
      rows.where((r) => r.reminderDaysBefore == kUsageReminderDaysBefore),
      isEmpty,
    );
  });
}
