import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/notification_service.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/data/repositories/service_kind_repository.dart';
import 'package:submersion/features/equipment/data/repositories/service_record_repository.dart';
import 'package:submersion/features/equipment/data/repositories/service_schedule_repository.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/service_clock_status.dart';
import 'package:submersion/features/equipment/domain/entities/service_kind.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/services/exposure_classifier.dart';
import 'package:submersion/features/equipment/domain/services/service_due_engine.dart';
import 'package:submersion/features/equipment/presentation/providers/exposure_thresholds_provider.dart';
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
      await _reconcileUsageReminders(item: item, statuses: statuses);
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
    final parentId = item.parentEquipmentId;
    final parent = parentId == null
        ? null
        : await _equipmentRepository.getEquipmentById(parentId);
    final children = await _equipmentRepository.getChildEquipment(item.id);
    final isRebreather =
        item.type == EquipmentType.rebreather ||
        parent?.type == EquipmentType.rebreather;
    final usage = await _equipmentRepository.getExposureSamplesForEquipment(
      item.id,
      parentEquipmentId: parentId,
      installedSince: item.installedDate,
      rebreatherContact: isRebreather,
    );
    final classifier = ExposureClassifier(
      thresholds: exposureThresholdsFromSettings(settings),
      loopTimeOnly: isRebreather,
      hasBatteryChild: children.any((c) => c.type == EquipmentType.battery),
    );
    final window = settings.serviceReminderDays.isEmpty
        ? 30
        : settings.serviceReminderDays.reduce((a, b) => a > b ? a : b);
    return const ServiceDueEngine().evaluate(
      schedules: schedules,
      kindsById: kindsById,
      records: records,
      usage: usage,
      classifier: classifier,
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
    // Usage triggers first: a clock that is due because of dives, hours or
    // an exposure unit gets its one-off reminder whether or not it also
    // carries a calendar trigger.
    if (_usageDue(status)) {
      await _scheduleUsageReminder(
        item: item,
        status: status,
        globalSettings: globalSettings,
      );
    }
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

  /// Cancel usage reminders that no longer belong to their clock's current
  /// anchor: the clock is no longer due (a service record moved the anchor,
  /// or the schedule was removed or paused), or the reminder was armed
  /// against a different anchor (the clock is still due, but a record moved
  /// the anchor in either direction). The platform notification is
  /// cancelled by its recorded id and the ledger row dropped, so
  /// [_scheduleUsageReminder] can arm exactly one against the current
  /// anchor.
  Future<void> _reconcileUsageReminders({
    required EquipmentItem item,
    required List<ServiceClockStatus> statuses,
  }) async {
    final recorded = await _scheduledNotificationRepository.getForEquipment(
      item.id,
    );
    final bySchedule = {for (final s in statuses) s.schedule.id: s};
    for (final row in recorded) {
      if (row.reminderDaysBefore != kUsageReminderDaysBefore) continue;
      final status = bySchedule[row.scheduleId];
      final current =
          status != null &&
          _usageDue(status) &&
          row.createdAt == status.anchor.millisecondsSinceEpoch;
      if (current) continue;
      await _notificationService.cancelNotification(row.notificationId);
      await _scheduledNotificationRepository.deleteById(row.id);
    }
  }

  /// Whether any usage unit is within its due-soon band or past it. Mirrors
  /// the engine's band: counts round the 10 percent band up, fractional
  /// units compare directly.
  bool _usageDue(ServiceClockStatus status) {
    for (final entry in status.usageByUnit.entries) {
      final u = entry.value;
      final band = entry.key.isFractional
          ? u.interval * 0.1
          : (u.interval * 0.1).ceilToDouble();
      if (u.remaining <= band) return true;
    }
    return false;
  }

  /// One local notification when a usage clock reaches due-soon or
  /// overdue, deduplicated per (schedule, anchor). Fires at the next
  /// reminder time. Rescheduling everything (settings change) re-arms it
  /// once, which is acceptable for a clock that is still due.
  Future<void> _scheduleUsageReminder({
    required EquipmentItem item,
    required ServiceClockStatus status,
    required AppSettings globalSettings,
  }) async {
    if (item.customReminderEnabled == false) return;
    final already = await _scheduledNotificationRepository.hasUsageReminder(
      scheduleId: status.schedule.id,
      anchor: status.anchor,
    );
    if (already) return;

    final now = DateTime.now();
    var fireAt = DateTime(
      now.year,
      now.month,
      now.day,
      globalSettings.reminderTime.hour,
      globalSettings.reminderTime.minute,
    );
    if (!fireAt.isAfter(now)) fireAt = fireAt.add(const Duration(days: 1));

    final brandModel = item.brand != null || item.model != null
        ? '${item.brand ?? ''} ${item.model ?? ''}'.trim()
        : null;
    final notificationId = await _notificationService.scheduleServiceReminder(
      scheduleId: status.schedule.id,
      equipmentId: item.id,
      equipmentName: item.name,
      kindName: status.kind.name,
      brandModel: brandModel,
      scheduledDate: fireAt,
      daysBefore: kUsageReminderDaysBefore,
    );
    await _scheduledNotificationRepository.recordScheduled(
      equipmentId: item.id,
      scheduledDate: fireAt,
      reminderDaysBefore: kUsageReminderDaysBefore,
      notificationId: notificationId,
      scheduleId: status.schedule.id,
      // The anchor this reminder was armed against, not the wall clock, so
      // a backdated record still reads as a different anchor.
      createdAt: status.anchor.millisecondsSinceEpoch,
    );
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
