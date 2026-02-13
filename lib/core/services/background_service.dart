import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/notification_service.dart';
import 'package:submersion/features/backup/data/repositories/backup_preferences.dart';
import 'package:submersion/features/backup/data/services/backup_service.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/notifications/data/repositories/scheduled_notification_repository.dart';
import 'package:submersion/features/notifications/data/services/notification_scheduler.dart';
import 'package:submersion/features/settings/data/repositories/diver_settings_repository.dart';

const String kNotificationRefreshTask = 'com.submersion.notificationRefresh';
const String kBackupTask = 'com.submersion.backup';

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
      } else if (task == kBackupTask) {
        await _performScheduledBackup(log);
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

Future<void> _performScheduledBackup(LoggerService log) async {
  log.info('Checking if scheduled backup is due');

  final prefs = await SharedPreferences.getInstance();
  final preferences = BackupPreferences(prefs);
  final settings = preferences.getSettings();

  if (!settings.enabled) {
    log.info('Automatic backups disabled, skipping');
    return;
  }

  if (!settings.isBackupDue) {
    log.info('Backup not yet due, skipping');
    return;
  }

  log.info('Backup is due, starting automatic backup');

  // Background isolate cannot access cloud auth, so backup is local-only
  final dbAdapter = DefaultBackupDatabaseAdapter(DatabaseService.instance);
  final service = BackupService(dbAdapter: dbAdapter, preferences: preferences);

  try {
    final record = await service.performBackup(isAutomatic: true);
    log.info('Automatic backup completed: ${record.filename}');
    await NotificationService.instance.showBackupNotification(success: true);
  } catch (e, stack) {
    log.error('Automatic backup failed', e, stack);
    await NotificationService.instance.showBackupNotification(
      success: false,
      error: e.toString(),
    );
  }
}

/// Initialize background task registration
Future<void> initializeBackgroundService() async {
  // Background service is mobile-only (iOS/Android)
  if (!Platform.isIOS && !Platform.isAndroid) {
    return;
  }

  await Workmanager().initialize(callbackDispatcher);

  // Register periodic task for notification refresh
  await Workmanager().registerPeriodicTask(
    'notification-refresh',
    kNotificationRefreshTask,
    frequency: const Duration(hours: 6), // Refresh every 6 hours
    constraints: Constraints(
      networkType: NetworkType.notRequired,
      requiresBatteryNotLow: false,
      requiresCharging: false,
      requiresDeviceIdle: false,
      requiresStorageNotLow: false,
    ),
  );

  // Register periodic task for automatic backups
  // Checks every 12 hours; actual frequency managed by BackupSettings.isBackupDue
  await Workmanager().registerPeriodicTask(
    'backup-task',
    kBackupTask,
    frequency: const Duration(hours: 12),
    constraints: Constraints(
      networkType: NetworkType.notRequired,
      requiresBatteryNotLow: true,
      requiresCharging: false,
      requiresDeviceIdle: false,
      requiresStorageNotLow: true,
    ),
  );
}
