import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/notification_service.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/data/repositories/service_schedule_repository.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/notifications/data/services/notification_scheduler.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/trips/data/repositories/trip_repository.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart' as domain;

import '../../helpers/test_database.dart';

/// Captures trip-reminder calls; every other member no-ops (desktop-style).
class _FakeNotificationService implements NotificationService {
  final tripReminders = <({String tripId, int itemCount, DateTime fireAt})>[];

  @override
  Future<int> scheduleTripServiceReminder({
    required String tripId,
    required String tripName,
    required int itemCount,
    required DateTime scheduledDate,
  }) async {
    tripReminders.add((
      tripId: tripId,
      itemCount: itemCount,
      fireAt: scheduledDate,
    ));
    return 1;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    final name = invocation.memberName.toString();
    if (name.contains('scheduleServiceReminder')) return Future.value(0);
    return Future.value();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late EquipmentRepository equipmentRepo;
  late ServiceScheduleRepository scheduleRepo;

  setUp(() async {
    db = await setUpTestDatabase();
    equipmentRepo = EquipmentRepository();
    scheduleRepo = ServiceScheduleRepository();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  test(
    'scheduleAll records per-clock reminders only for future reminder days',
    () async {
      final now = DateTime.now();
      final tank = await equipmentRepo.createEquipment(
        const EquipmentItem(id: '', name: 'AL80', type: EquipmentType.tank),
      );

      // hydro due in 20 days, vip due in 25 days: the 30-day reminder for
      // both is already past, so only 7 and 14 day reminders schedule.
      final schedules = await scheduleRepo.getSchedulesForEquipment(tank.id);
      final hydro = schedules.firstWhere((s) => s.serviceKindId == 'hydro');
      await scheduleRepo.updateSchedule(
        hydro.copyWith(anchorDate: now.add(const Duration(days: 20 - 1825))),
      );
      final vip = schedules.firstWhere((s) => s.serviceKindId == 'vip');
      await scheduleRepo.updateSchedule(
        vip.copyWith(anchorDate: now.add(const Duration(days: 25 - 365))),
      );

      await NotificationScheduler().scheduleAll(settings: const AppSettings());

      final rows = await db.select(db.scheduledNotifications).get();
      expect(rows, hasLength(4)); // 2 clocks x (7d, 14d)
      expect(rows.map((r) => r.reminderDaysBefore).toSet(), {7, 14});
      expect(rows.every((r) => r.equipmentId == tank.id), isTrue);

      // Every row is tagged with its clock, and the two clocks' rows are
      // distinct (on device the platform id derives from the schedule id,
      // so hydro and VIP reminders cannot overwrite each other).
      final scheduleIds = rows.map((r) => r.scheduleId).toSet();
      expect(scheduleIds, {hydro.id, vip.id});

      // Re-running is idempotent (already-scheduled check is per clock).
      await NotificationScheduler().scheduleAll(settings: const AppSettings());
      expect(await db.select(db.scheduledNotifications).get(), hasLength(4));
    },
  );

  test(
    'trip reminder fires once at start minus lead days for blocked gear',
    () async {
      final now = DateTime.now();
      final tank = await equipmentRepo.createEquipment(
        const EquipmentItem(id: '', name: 'AL80', type: EquipmentType.tank),
      );
      // BOTH clocks overdue on the same tank: the trip nag must still count
      // one ITEM, not two clocks.
      final schedules = await scheduleRepo.getSchedulesForEquipment(tank.id);
      final hydro = schedules.firstWhere((s) => s.serviceKindId == 'hydro');
      await scheduleRepo.updateSchedule(
        hydro.copyWith(anchorDate: now.subtract(const Duration(days: 2190))),
      );
      final vip = schedules.firstWhere((s) => s.serviceKindId == 'vip');
      await scheduleRepo.updateSchedule(
        vip.copyWith(anchorDate: now.subtract(const Duration(days: 400))),
      );

      final trip = await TripRepository().createTrip(
        domain.Trip(
          id: '',
          name: 'Bonaire',
          startDate: now.add(const Duration(days: 30)),
          endDate: now.add(const Duration(days: 37)),
          createdAt: now,
          updatedAt: now,
        ),
      );

      final fake = _FakeNotificationService();
      await NotificationScheduler(
        notificationService: fake,
      ).scheduleAll(settings: const AppSettings());

      expect(fake.tripReminders, hasLength(1));
      final reminder = fake.tripReminders.single;
      expect(reminder.tripId, trip.id);
      // One tank with hydro AND vip overdue is one item, not two.
      expect(reminder.itemCount, 1);
      // Fires tripServiceLeadDays (default 14) before the trip starts.
      final expectedDay = trip.startDate.subtract(const Duration(days: 14));
      expect(reminder.fireAt.day, expectedDay.day);
      expect(reminder.fireAt.isBefore(trip.startDate), isTrue);
    },
  );

  test(
    'per-item custom reminders disabled cancels instead of scheduling',
    () async {
      final now = DateTime.now();
      final tank = await equipmentRepo.createEquipment(
        const EquipmentItem(
          id: '',
          name: 'AL80',
          type: EquipmentType.tank,
          customReminderEnabled: false,
        ),
      );
      final schedules = await scheduleRepo.getSchedulesForEquipment(tank.id);
      final hydro = schedules.firstWhere((s) => s.serviceKindId == 'hydro');
      await scheduleRepo.updateSchedule(
        hydro.copyWith(anchorDate: now.add(const Duration(days: 20 - 1825))),
      );

      await NotificationScheduler().scheduleAll(settings: const AppSettings());

      expect(await db.select(db.scheduledNotifications).get(), isEmpty);
    },
  );

  test('updateForEquipment cancels recorded rows and reschedules', () async {
    final now = DateTime.now();
    final tank = await equipmentRepo.createEquipment(
      const EquipmentItem(id: '', name: 'AL80', type: EquipmentType.tank),
    );
    final schedules = await scheduleRepo.getSchedulesForEquipment(tank.id);
    final hydro = schedules.firstWhere((s) => s.serviceKindId == 'hydro');
    await scheduleRepo.updateSchedule(
      hydro.copyWith(anchorDate: now.add(const Duration(days: 20 - 1825))),
    );

    final scheduler = NotificationScheduler();
    await scheduler.scheduleAll(settings: const AppSettings());
    final before = await db.select(db.scheduledNotifications).get();
    expect(before, isNotEmpty);

    final item = (await equipmentRepo.getEquipmentById(tank.id))!;
    await scheduler.updateForEquipment(
      item: item,
      globalSettings: const AppSettings(),
    );

    // Old rows were cancelled+deleted, fresh rows recorded per clock --
    // same shape as before, no duplicates from the reschedule.
    final after = await db.select(db.scheduledNotifications).get();
    expect(after.length, before.length);
    expect(after.map((r) => r.scheduleId).toSet(), contains(hydro.id));
  });

  test('notifications disabled schedules nothing', () async {
    await equipmentRepo.createEquipment(
      const EquipmentItem(id: '', name: 'AL80', type: EquipmentType.tank),
    );
    await NotificationScheduler().scheduleAll(
      settings: const AppSettings(notificationsEnabled: false),
    );
    expect(await db.select(db.scheduledNotifications).get(), isEmpty);
  });
}
