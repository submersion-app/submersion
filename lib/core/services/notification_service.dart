import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import 'package:submersion/core/services/logger_service.dart';

/// Deterministic 32-bit notification id for [key].
///
/// [String.hashCode] is seeded with a per-launch random value (hash-flood
/// mitigation), so an id derived from it changes between app runs and can also
/// fall outside the positive int32 range Android notification ids require. This
/// FNV-1a hash is stable across launches and always fits 31 bits, so a reminder
/// scheduled in one run can be replaced or cancelled by id in the next.
int _stableNotificationId(String key) {
  var hash = 0x811c9dc5; // FNV-1a 32-bit offset basis
  for (final unit in key.codeUnits) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0xFFFFFFFF; // FNV prime, wrap to 32 bits
  }
  return hash & 0x7FFFFFFF; // positive, within int32
}

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
      settings: initSettings,
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

  /// Compose the body text for a service reminder notification.
  ///
  /// A reminder fires on or before the due date, so [daysBefore] == 0 means
  /// "due today" (never overdue), and 1 must read "tomorrow" rather than the
  /// ungrammatical "1 days". Any negative value degrades to "due today".
  @visibleForTesting
  static String serviceReminderBody({
    required String prefix,
    required String kindName,
    required int daysBefore,
  }) {
    if (daysBefore <= 0) return '$prefix: $kindName is due today';
    if (daysBefore == 1) return '$prefix: $kindName is due tomorrow';
    return '$prefix: $kindName is due in $daysBefore days';
  }

  /// Schedule a notification for one service clock.
  ///
  /// The platform id derives from [scheduleId], NOT the equipment id: two
  /// clocks on one item (hydro + VIP on a cylinder) must not collide, and
  /// flutter_local_notifications silently replaces on id collision.
  Future<int> scheduleServiceReminder({
    required String scheduleId,
    required String equipmentId,
    required String equipmentName,
    required String kindName,
    required String? brandModel,
    required DateTime scheduledDate,
    required int daysBefore,
  }) async {
    // Skip on desktop platforms
    if (!_isMobilePlatform) return 0;

    final notificationId = _stableNotificationId('$scheduleId#$daysBefore');

    final title = '$kindName due: $equipmentName';
    final body = serviceReminderBody(
      prefix: brandModel ?? equipmentName,
      kindName: kindName,
      daysBefore: daysBefore,
    );

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
      id: notificationId,
      title: title,
      body: body,
      scheduledDate: scheduledTz,
      notificationDetails: details,
      payload: equipmentId,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );

    _log.info(
      'Scheduled notification $notificationId for $equipmentName at $scheduledTz',
    );

    return notificationId;
  }

  /// Schedule the one-per-trip nag: gear needs service before the trip.
  /// Same channel as equipment reminders; the id derives from the trip id.
  Future<int> scheduleTripServiceReminder({
    required String tripId,
    required String tripName,
    required int itemCount,
    required DateTime scheduledDate,
  }) async {
    if (!_isMobilePlatform) return 0;

    final notificationId = _stableNotificationId('trip#$tripId');
    final title = 'Gear service before $tripName';
    final body = itemCount == 1
        ? '1 item needs service before this trip'
        : '$itemCount items need service before this trip';

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

    final scheduledTz = tz.TZDateTime.from(scheduledDate, tz.local);
    await _plugin.zonedSchedule(
      id: notificationId,
      title: title,
      body: body,
      scheduledDate: scheduledTz,
      notificationDetails: details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );

    _log.info(
      'Scheduled trip service notification $notificationId for $tripName '
      'at $scheduledTz',
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

    await _plugin.show(
      id: backupNotificationId,
      title: title,
      body: body,
      notificationDetails: details,
    );

    _log.info('Showed backup notification (success: $success)');
  }

  /// Cancel a specific notification
  Future<void> cancelNotification(int notificationId) async {
    if (!_isMobilePlatform) return;
    await _plugin.cancel(id: notificationId);
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
