import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/app_sql_functions.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/data/repositories/service_schedule_repository.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/service_schedule.dart';
import 'package:submersion/features/notifications/data/services/notification_scheduler.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import 'helpers/recording_notification_service.dart';

/// A reminder run reads the locker's schedules and records once, not once
/// per item (issue #3830).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() {
    db = AppDatabase(
      NativeDatabase.memory(
        setup: registerAppSqlFunctions,
        logStatements: true,
      ),
    );
    DatabaseService.instance.setTestDatabase(db);
  });

  tearDown(() async {
    await db.close();
    DatabaseService.instance.resetForTesting();
  });

  Future<void> seedLocker(int size) => runZoned(() async {
    for (var i = 0; i < size; i++) {
      await EquipmentRepository().createEquipment(
        EquipmentItem(
          id: '',
          name: 'Item $i',
          type: i.isEven ? EquipmentType.tank : EquipmentType.fins,
          purchaseDate: DateTime(2015),
        ),
      );
    }
  }, zoneSpecification: ZoneSpecification(print: (_, _, _, _) {}));

  Future<int> clockReadsForRun() async {
    final logged = <String>[];
    await runZoned(
      () => NotificationScheduler(
        notificationService: RecordingNotificationService(),
      ).scheduleAll(settings: const AppSettings()),
      zoneSpecification: ZoneSpecification(
        print: (self, parent, zone, line) => logged.add(line),
      ),
    );
    return logged
        .where((l) => l.startsWith('Drift: Sent SELECT'))
        .where(
          (l) =>
              l.contains('FROM "service_schedules"') ||
              l.contains('FROM "service_records"'),
        )
        .length;
  }

  test(
    'a run reads schedules and records once, whatever the item count',
    () async {
      await seedLocker(1);
      expect(await clockReadsForRun(), 2);

      await seedLocker(39);
      expect(await clockReadsForRun(), 2);
    },
  );

  test(
    'one item still gets its reminders, and gear with no clock none',
    () async {
      final now = DateTime.now();
      final regulator = await EquipmentRepository().createEquipment(
        const EquipmentItem(id: '', name: 'Reg', type: EquipmentType.regulator),
      );
      // Due in 40 days, so the 30-day reminder is still ahead.
      await ServiceScheduleRepository().createSchedule(
        ServiceSchedule(
          id: 'sched',
          equipmentId: regulator.id,
          serviceKindId: 'regulator-service',
          intervalDays: 365,
          anchorDate: now.subtract(const Duration(days: 325)),
          createdAt: now,
          updatedAt: now,
        ),
      );
      final fins = await EquipmentRepository().createEquipment(
        const EquipmentItem(id: '', name: 'Fins', type: EquipmentType.fins),
      );
      final fake = RecordingNotificationService();
      final scheduler = NotificationScheduler(notificationService: fake);

      await scheduler.updateForEquipment(
        item: fins,
        globalSettings: const AppSettings(),
      );
      expect(fake.reminderKinds, isEmpty);

      await scheduler.updateForEquipment(
        item: regulator,
        globalSettings: const AppSettings(),
      );
      expect(fake.reminderKinds, contains('Regulator service'));
    },
  );
}
