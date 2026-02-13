import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import 'package:submersion/core/services/logger_service.dart';

/// Service for managing local notifications
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  static NotificationService get instance => _instance;

  NotificationService._internal();

  final _log = LoggerService.forClass(NotificationService);
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  String? _selectedEquipmentId;

  /// Callback when a notification is tapped
  void Function(String equipmentId)? onNotificationTapped;

  /// Get the equipment ID from the last tapped notification
  String? get selectedEquipmentId {
    final id = _selectedEquipmentId;
    _selectedEquipmentId = null; // Clear after reading
    return id;
  }

  /// Initialize the notification service
  Future<void> initialize() async {
    if (_initialized) return;

    // Notifications are mobile-only (iOS/Android)
    if (!Platform.isIOS && !Platform.isAndroid) {
      _log.info('Notification service skipped on desktop platform');
      _initialized = true;
      return;
    }

    _log.info('Initializing notification service');

    // Initialize timezone
    tz.initializeTimeZones();

    // Android settings
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );

    // iOS settings
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false, // Request later
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    _initialized = true;
    _log.info('Notification service initialized');
  }

  void _onNotificationTapped(NotificationResponse response) {
    _log.info('Notification tapped: ${response.payload}');
    if (response.payload != null) {
      _selectedEquipmentId = response.payload;
      onNotificationTapped?.call(response.payload!);
    }
  }

  /// Check if we're on a mobile platform that supports notifications
  bool get _isMobilePlatform => Platform.isIOS || Platform.isAndroid;

  /// Request notification permissions
  Future<bool> requestPermission() async {
    if (!_isMobilePlatform) return true; // Desktop doesn't need permission
    if (Platform.isIOS) {
      final result = await _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, badge: true, sound: true);
      return result ?? false;
    } else if (Platform.isAndroid) {
      final impl = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      final result = await impl?.requestNotificationsPermission();
      return result ?? false;
    }
    return false;
  }

  /// Check if notifications are permitted
  Future<bool> isPermissionGranted() async {
    if (!_isMobilePlatform) return true; // Desktop doesn't need permission
    if (Platform.isIOS) {
      final impl = _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      final settings = await impl?.checkPermissions();
      return settings?.isEnabled ?? false;
    } else if (Platform.isAndroid) {
      final impl = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      return await impl?.areNotificationsEnabled() ?? false;
    }
    return false;
  }

  /// Schedule a notification for equipment service
  Future<int> scheduleServiceReminder({
    required String equipmentId,
    required String equipmentName,
    required String? brandModel,
    required DateTime scheduledDate,
    required int daysBefore,
  }) async {
    // Skip on desktop platforms
    if (!_isMobilePlatform) return 0;

    final notificationId = equipmentId.hashCode + daysBefore;

    final title = 'Service Due: $equipmentName';
    final body = daysBefore > 0
        ? '${brandModel ?? equipmentName} service is due in $daysBefore days'
        : '${brandModel ?? equipmentName} service is overdue';

    const androidDetails = AndroidNotificationDetails(
      'equipment_service_reminders',
      'Equipment Service Reminders',
      channelDescription: 'Reminders for equipment service due dates',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      category: AndroidNotificationCategory.reminder,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    // Schedule at the specified date/time in local timezone
    final scheduledTz = tz.TZDateTime.from(scheduledDate, tz.local);

    await _plugin.zonedSchedule(
      notificationId,
      title,
      body,
      scheduledTz,
      details,
      payload: equipmentId,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );

    _log.info(
      'Scheduled notification $notificationId for $equipmentName at $scheduledTz',
    );

    return notificationId;
  }

  /// Show an immediate notification for backup results.
  ///
  /// Used by both foreground operations and background tasks.
  /// Uses a separate Android channel from equipment reminders.
  Future<void> showBackupNotification({
    required bool success,
    String? error,
  }) async {
    if (!_isMobilePlatform) return;

    const androidDetails = AndroidNotificationDetails(
      'backup_notifications',
      'Backup Notifications',
      channelDescription: 'Notifications for automatic backup status',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      category: AndroidNotificationCategory.status,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: false,
      presentSound: false,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final title = success ? 'Backup Complete' : 'Backup Failed';
    final body = success
        ? 'Your dive data has been backed up successfully.'
        : 'Automatic backup failed${error != null ? ': $error' : '. Please try a manual backup.'}';

    // Use a fixed ID so repeated backup notifications replace each other
    const backupNotificationId = 99000;

    await _plugin.show(backupNotificationId, title, body, details);

    _log.info('Showed backup notification (success: $success)');
  }

  /// Cancel a specific notification
  Future<void> cancelNotification(int notificationId) async {
    if (!_isMobilePlatform) return;
    await _plugin.cancel(notificationId);
    _log.info('Cancelled notification $notificationId');
  }

  /// Cancel all notifications for a specific equipment item
  Future<void> cancelNotificationsForEquipment(
    String equipmentId,
    List<int> daysBefore,
  ) async {
    if (!_isMobilePlatform) return;
    for (final days in daysBefore) {
      final notificationId = equipmentId.hashCode + days;
      await cancelNotification(notificationId);
    }
  }

  /// Cancel all scheduled notifications
  Future<void> cancelAllNotifications() async {
    if (!_isMobilePlatform) return;
    await _plugin.cancelAll();
    _log.info('Cancelled all notifications');
  }

  /// Get list of pending notifications
  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    if (!_isMobilePlatform) return [];
    return _plugin.pendingNotificationRequests();
  }
}
