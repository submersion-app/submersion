import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/notification_service.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/data/repositories/service_kind_repository.dart';
import 'package:submersion/features/equipment/data/repositories/service_record_repository.dart';
import 'package:submersion/features/equipment/data/repositories/service_schedule_repository.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/service_clock_status.dart';
import 'package:submersion/features/equipment/domain/entities/service_kind.dart';
import 'package:submersion/features/equipment/domain/services/service_due_engine.dart';
import 'package:submersion/features/notifications/data/repositories/scheduled_notification_repository.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/trips/data/repositories/trip_repository.dart';

/// Schedules service-clock reminder notifications plus one pre-trip nag per
/// upcoming trip with gear due before the trip ends.
class NotificationScheduler {
  final NotificationService _notificationService;
  final EquipmentRepository _equipmentRepository;
  final ServiceScheduleRepository _serviceScheduleRepository;
  final ServiceKindRepository _serviceKindRepository;
  final ServiceRecordRepository _serviceRecordRepository;
  final TripRepository _tripRepository;
  final ScheduledNotificationRepository _scheduledNotificationRepository;
  final _log = LoggerService.forClass(NotificationScheduler);

  NotificationScheduler({
    NotificationService? notificationService,
    EquipmentRepository? equipmentRepository,
    ServiceScheduleRepository? serviceScheduleRepository,
    ServiceKindRepository? serviceKindRepository,
    ServiceRecordRepository? serviceRecordRepository,
    TripRepository? tripRepository,
    ScheduledNotificationRepository? scheduledNotificationRepository,
  }) : _notificationService =
           notificationService ?? NotificationService.instance,
       _equipmentRepository = equipmentRepository ?? EquipmentRepository(),
       _serviceScheduleRepository =
           serviceScheduleRepository ?? ServiceScheduleRepository(),
       _serviceKindRepository =
           serviceKindRepository ?? ServiceKindRepository(),
       _serviceRecordRepository =
           serviceRecordRepository ?? ServiceRecordRepository(),
       _tripRepository = tripRepository ?? TripRepository(),
       _scheduledNotificationRepository =
           scheduledNotificationRepository ?? ScheduledNotificationRepository();

  /// Schedule all notifications based on current settings
  Future<void> scheduleAll({
    required AppSettings settings,
    String? diverId,
  }) async {
    if (!settings.notificationsEnabled) {
      _log.info('Notifications disabled, skipping scheduling');
      return;
    }

    _log.info('Scheduling notifications for service clocks');

    final items = await _equipmentRepository.getActiveEquipment(
      diverId: diverId,
    );
    final kinds = await _serviceKindRepository.getAllKinds(diverId: diverId);
    final kindsById = {for (final k in kinds) k.id: k};

    // Clean up expired records first
    await _scheduledNotificationRepository.deleteExpired();

    final statusesByItem = <String, List<ServiceClockStatus>>{};
    for (final item in items) {
      final statuses = await _evaluateClocks(
        item: item,
        kindsById: kindsById,
        settings: settings,
      );
      statusesByItem[item.id] = statuses;
      for (final status in statuses) {
        await _scheduleForClock(
          item: item,
          status: status,
          globalSettings: settings,
        );
      }
    }

    await _scheduleTripReminders(
      items: items,
      statusesByItem: statusesByItem,
      settings: settings,
      diverId: diverId,
    );

    _log.info('Notification scheduling complete');
  }

  /// Evaluate an item's clocks with the shared engine.
  Future<List<ServiceClockStatus>> _evaluateClocks({
    required EquipmentItem item,
    required Map<String, ServiceKind> kindsById,
    required AppSettings settings,
  }) async {
    final schedules = await _serviceScheduleRepository.getSchedulesForEquipment(
      item.id,
    );
    if (schedules.isEmpty) return const [];
    final records = await _serviceRecordRepository.getRecordsForEquipment(
      item.id,
    );
    final usage = await _equipmentRepository.getUsageSamplesForEquipment(
      item.id,
    );
    final window = settings.serviceReminderDays.isEmpty
        ? 30
        : settings.serviceReminderDays.reduce((a, b) => a > b ? a : b);
    return const ServiceDueEngine().evaluate(
      schedules: schedules,
      kindsById: kindsById,
      records: records,
      usage: usage,
      purchaseDate: item.purchaseDate,
      equipmentCreatedAt: item.createdAt ?? DateTime.now(),
      dueSoonWindowDays: window,
      now: DateTime.now(),
    );
  }

  /// Schedule per-reminder-day notifications for one clock's date trigger.
  /// Usage-only clocks get no push (there is no future date to anchor to);
  /// they surface via the in-app badges instead.
  Future<void> _scheduleForClock({
    required EquipmentItem item,
    required ServiceClockStatus status,
    required AppSettings globalSettings,
  }) async {
    final dueDate = status.dueDate;
    if (dueDate == null) return;

    // Determine which reminder days to use (per ITEM, matching the legacy
    // custom-reminder override semantics).
    List<int> reminderDays;
    if (item.customReminderEnabled == false) {
      // Notifications disabled for this item
      await _cancelForEquipment(item.id, globalSettings.serviceReminderDays);
      return;
    } else if (item.customReminderEnabled == true &&
        item.customReminderDays != null) {
      reminderDays = item.customReminderDays!;
    } else {
      reminderDays = globalSettings.serviceReminderDays;
    }

    final brandModel = item.brand != null || item.model != null
        ? '${item.brand ?? ''} ${item.model ?? ''}'.trim()
        : null;

    for (final daysBefore in reminderDays) {
      final scheduledDate = dueDate.subtract(Duration(days: daysBefore));

      // Add the reminder time
      final scheduledDateTime = DateTime(
        scheduledDate.year,
        scheduledDate.month,
        scheduledDate.day,
        globalSettings.reminderTime.hour,
        globalSettings.reminderTime.minute,
      );

      // Skip if in the past
      if (scheduledDateTime.isBefore(DateTime.now())) {
        continue;
      }

      // Check if already scheduled (per clock)
      final alreadyScheduled = await _scheduledNotificationRepository
          .isScheduled(
            equipmentId: item.id,
            reminderDaysBefore: daysBefore,
            scheduledDate: scheduledDateTime,
            scheduleId: status.schedule.id,
          );

      if (alreadyScheduled) {
        continue;
      }

      final notificationId = await _notificationService.scheduleServiceReminder(
        scheduleId: status.schedule.id,
        equipmentId: item.id,
        equipmentName: item.name,
        kindName: status.kind.name,
        brandModel: brandModel,
        scheduledDate: scheduledDateTime,
        daysBefore: daysBefore,
      );

      await _scheduledNotificationRepository.recordScheduled(
        equipmentId: item.id,
        scheduledDate: scheduledDateTime,
        reminderDaysBefore: daysBefore,
        notificationId: notificationId,
        scheduleId: status.schedule.id,
      );
    }
  }

  /// One notification per upcoming trip with service alerts, at trip start
  /// minus the configured lead time. Same alert rule as the trip banner:
  /// date trigger before trip end, or already overdue.
  Future<void> _scheduleTripReminders({
    required List<EquipmentItem> items,
    required Map<String, List<ServiceClockStatus>> statusesByItem,
    required AppSettings settings,
    String? diverId,
  }) async {
    final trips = await _tripRepository.getAllTrips(diverId: diverId);
    final now = DateTime.now();
    for (final trip in trips) {
      if (!trip.startDate.isAfter(now)) continue;

      // Count distinct ITEMS with any blocking clock -- the notification
      // says "N items", and one item with hydro + VIP both due is still one
      // thing to bring to the shop.
      final blockedItemIds = <String>{};
      for (final item in items) {
        for (final status in statusesByItem[item.id] ?? const []) {
          final blocks =
              status.severity == ServiceClockSeverity.overdue ||
              (status.dueDate != null &&
                  status.dueDate!.isBefore(trip.endDate));
          if (blocks) blockedItemIds.add(item.id);
        }
      }
      if (blockedItemIds.isEmpty) continue;

      final fireAt = DateTime(
        trip.startDate.year,
        trip.startDate.month,
        trip.startDate.day,
        settings.reminderTime.hour,
        settings.reminderTime.minute,
      ).subtract(Duration(days: settings.tripServiceLeadDays));
      if (fireAt.isBefore(now)) continue;

      await _notificationService.scheduleTripServiceReminder(
        tripId: trip.id,
        tripName: trip.name,
        itemCount: blockedItemIds.length,
        scheduledDate: fireAt,
      );
    }
  }

  /// Cancel notifications for an equipment item. Cancels by the RECORDED
  /// platform ids (v122 ids derive from schedule ids, so recomputing from
  /// the equipment id would miss them); the legacy equipment-hash ids are
  /// also cancelled for pre-ledger rows.
  Future<void> _cancelForEquipment(
    String equipmentId,
    List<int> daysBefore,
  ) async {
    final recorded = await _scheduledNotificationRepository.getForEquipment(
      equipmentId,
    );
    for (final row in recorded) {
      await _notificationService.cancelNotification(row.notificationId);
    }
    await _notificationService.cancelNotificationsForEquipment(
      equipmentId,
      daysBefore,
    );
    await _scheduledNotificationRepository.deleteForEquipment(equipmentId);
  }

  /// Reschedule all notifications (e.g., after settings change)
  Future<void> rescheduleAll({
    required AppSettings settings,
    String? diverId,
  }) async {
    _log.info('Rescheduling all notifications');

    // Cancel all existing notifications
    await _notificationService.cancelAllNotifications();
    await _scheduledNotificationRepository.deleteAll();

    // Schedule fresh
    await scheduleAll(settings: settings, diverId: diverId);
  }

  /// Update notifications for a specific equipment item
  Future<void> updateForEquipment({
    required EquipmentItem item,
    required AppSettings globalSettings,
  }) async {
    // Cancel existing notifications for this item
    await _cancelForEquipment(item.id, [7, 14, 30]); // Cancel all possible days

    // Reschedule based on current settings
    final kinds = await _serviceKindRepository.getAllKinds();
    final statuses = await _evaluateClocks(
      item: item,
      kindsById: {for (final k in kinds) k.id: k},
      settings: globalSettings,
    );
    for (final status in statuses) {
      await _scheduleForClock(
        item: item,
        status: status,
        globalSettings: globalSettings,
      );
    }
  }
}
