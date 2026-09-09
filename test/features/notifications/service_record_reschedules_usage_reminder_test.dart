import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/data/repositories/service_schedule_repository.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/service_record.dart'
    as domain;
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/notifications/data/repositories/scheduled_notification_repository.dart';
import 'package:submersion/features/notifications/data/services/notification_scheduler.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../helpers/test_database.dart';

/// Logging a service record through the notifier must clear a usage reminder
/// that the moved anchor no longer justifies, without waiting for the next
/// app start.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
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

  Future<void> linkDive(String id, String equipmentId, int daysAgo) async {
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

  Iterable<ScheduledNotification> usageRows(List<ScheduledNotification> rows) =>
      rows.where((r) => r.reminderDaysBefore == kUsageReminderDaysBefore);

  test('addRecord clears the armed usage reminder', () async {
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
      regService.copyWith(intervalDays: 3650, intervalDives: 2),
    );
    await linkDive('d1', reg.id, 2);
    await linkDive('d2', reg.id, 1);
    await NotificationScheduler().scheduleAll(settings: const AppSettings());
    expect(
      usageRows(await db.select(db.scheduledNotifications).get()),
      hasLength(1),
    );

    final notifier = container.read(
      serviceRecordNotifierProvider(reg.id).notifier,
    );
    final now = DateTime.now();
    await notifier.addRecord(
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

    expect(
      usageRows(await db.select(db.scheduledNotifications).get()),
      isEmpty,
    );
  });
}
