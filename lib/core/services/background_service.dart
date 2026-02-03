import 'dart:io';

import 'package:workmanager/workmanager.dart';

import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/notification_service.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/notifications/data/repositories/scheduled_notification_repository.dart';
import 'package:submersion/features/notifications/data/services/notification_scheduler.dart';
import 'package:submersion/features/settings/data/repositories/diver_settings_repository.dart';

const String kNotificationRefreshTask = 'com.submersion.notificationRefresh';

/// Callback for Workmanager background tasks
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    const log = LoggerService('BackgroundService');
    log.info('Background task started: $task');

    try {
      // Initialize database
      await DatabaseService.instance.initialize();

      // Initialize notification service
      await NotificationService.instance.initialize();

      if (task == kNotificationRefreshTask) {
        await _refreshNotifications(log);
      }

      log.info('Background task completed: $task');
      return true;
    } catch (e, stackTrace) {
      log.error('Background task failed: $task', e, stackTrace);
      return false;
    }
  });
}

Future<void> _refreshNotifications(LoggerService log) async {
  log.info('Refreshing notification schedule');

  final settingsRepository = DiverSettingsRepository();
  final equipmentRepository = EquipmentRepository();
  final scheduledNotificationRepository = ScheduledNotificationRepository();

  // Get the default diver's settings
  // In background, we use the most recently active diver
  final settings = await settingsRepository.getSettingsForDiver('default');
  if (settings == null || !settings.notificationsEnabled) {
    log.info('Notifications disabled, skipping refresh');
    return;
  }

  final scheduler = NotificationScheduler(
    notificationService: NotificationService.instance,
    equipmentRepository: equipmentRepository,
    scheduledNotificationRepository: scheduledNotificationRepository,
  );

  await scheduler.scheduleAll(settings: settings);
}

/// Initialize background task registration
Future<void> initializeBackgroundService() async {
  // Background service is mobile-only (iOS/Android)
  if (!Platform.isIOS && !Platform.isAndroid) {
    return;
  }

  await Workmanager().initialize(callbackDispatcher, isInDebugMode: false);

  // Register periodic task for notification refresh
  await Workmanager().registerPeriodicTask(
    'notification-refresh',
    kNotificationRefreshTask,
    frequency: const Duration(hours: 6), // Refresh every 6 hours
    constraints: Constraints(
      networkType: NetworkType.not_required,
      requiresBatteryNotLow: false,
      requiresCharging: false,
      requiresDeviceIdle: false,
      requiresStorageNotLow: false,
    ),
  );
}
