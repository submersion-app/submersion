import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/notification_service.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/notifications/data/repositories/scheduled_notification_repository.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

/// Service for scheduling equipment service reminder notifications
class NotificationScheduler {
  final NotificationService _notificationService;
  final EquipmentRepository _equipmentRepository;
  final ScheduledNotificationRepository _scheduledNotificationRepository;
  final _log = LoggerService.forClass(NotificationScheduler);

  NotificationScheduler({
    NotificationService? notificationService,
    EquipmentRepository? equipmentRepository,
    ScheduledNotificationRepository? scheduledNotificationRepository,
  }) : _notificationService =
           notificationService ?? NotificationService.instance,
       _equipmentRepository = equipmentRepository ?? EquipmentRepository(),
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

    _log.info('Scheduling notifications for equipment service reminders');

    // Get equipment with service dates
    final equipment = await _equipmentRepository.getEquipmentWithServiceDates(
      diverId: diverId,
    );

    _log.info('Found ${equipment.length} equipment items with service dates');

    // Clean up expired records first
    await _scheduledNotificationRepository.deleteExpired();

    for (final item in equipment) {
      await _scheduleForEquipment(item: item, globalSettings: settings);
    }

    _log.info('Notification scheduling complete');
  }

  /// Schedule notifications for a single equipment item
  Future<void> _scheduleForEquipment({
    required EquipmentItem item,
    required AppSettings globalSettings,
  }) async {
    final nextServiceDue = item.nextServiceDue;
    if (nextServiceDue == null) return;

    // Determine which reminder days to use
    List<int> reminderDays;
    if (item.customReminderEnabled == false) {
      // Notifications disabled for this item
      await _cancelForEquipment(item.id, globalSettings.serviceReminderDays);
      return;
    } else if (item.customReminderEnabled == true &&
        item.customReminderDays != null) {
      // Use custom reminder days
      reminderDays = item.customReminderDays!;
    } else {
      // Use global settings
      reminderDays = globalSettings.serviceReminderDays;
    }

    final brandModel = item.brand != null || item.model != null
        ? '${item.brand ?? ''} ${item.model ?? ''}'.trim()
        : null;

    for (final daysBefore in reminderDays) {
      final scheduledDate = nextServiceDue.subtract(Duration(days: daysBefore));

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

      // Check if already scheduled
      final alreadyScheduled = await _scheduledNotificationRepository
          .isScheduled(
            equipmentId: item.id,
            reminderDaysBefore: daysBefore,
            scheduledDate: scheduledDateTime,
          );

      if (alreadyScheduled) {
        continue;
      }

      // Schedule the notification
      final notificationId = await _notificationService.scheduleServiceReminder(
        equipmentId: item.id,
        equipmentName: item.name,
        brandModel: brandModel,
        scheduledDate: scheduledDateTime,
        daysBefore: daysBefore,
      );

      // Record the scheduled notification
      await _scheduledNotificationRepository.recordScheduled(
        equipmentId: item.id,
        scheduledDate: scheduledDateTime,
        reminderDaysBefore: daysBefore,
        notificationId: notificationId,
      );
    }
  }

  /// Cancel notifications for an equipment item
  Future<void> _cancelForEquipment(
    String equipmentId,
    List<int> daysBefore,
  ) async {
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
    await _scheduleForEquipment(item: item, globalSettings: globalSettings);
  }
}
