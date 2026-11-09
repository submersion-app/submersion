import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import 'package:submersion/core/platform/host_platform.dart';
import 'package:submersion/core/router/track_locations.dart';
import 'package:submersion/core/services/dive_mark_actions.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/util/time_zone_database.dart';
import 'package:submersion/features/documents/domain/document_reminder_plan.dart';
import 'package:submersion/l10n/l10n_extension.dart';

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

/// The payload prefix of a document reminder: `document:<id>`.
const String _documentPayloadPrefix = 'document:';

/// The route a tapped reminder opens: a document reminder (payload
/// `document:<id>`, issue #2613) opens the document, any other payload is
/// an equipment id. Null for an empty payload.
String? notificationPayloadRoute(String payload) {
  // The dive mark notification (issue #637) opens the GPS log.
  if (payload == kDiveMarkPayload) return kTracksLocation;
  if (payload.startsWith(_documentPayloadPrefix)) {
    final id = payload.substring(_documentPayloadPrefix.length);
    return id.isEmpty ? null : '/documents/$id';
  }
  return payload.isEmpty ? null : '/equipment/$payload';
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
    if (!HostPlatform.isIOS && !HostPlatform.isAndroid) {
      _log.info('Notification service skipped on desktop platform');
      _initialized = true;
      return;
    }

    _log.info('Initializing notification service');

    // Initialize timezone
    ensureTimeZoneDatabase();

    // Android settings
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );

    // iOS settings. The dive mark categories (issue #637) are registered
    // here, once, so their titles take the platform language.
    final l10n = l10nForLocaleTag('system');
    final iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false, // Request later
      requestBadgePermission: false,
      requestSoundPermission: false,
      notificationCategories: [
        _diveMarkCategory(
          kDiveMarkEnterCategory,
          DiveMarkAction.enteredWater,
          l10n.gpsLogger_enteredWater,
        ),
        _diveMarkCategory(
          kDiveMarkSurfaceCategory,
          DiveMarkAction.surfaced,
          l10n.gpsLogger_surfaced,
        ),
      ],
    );

    final initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // A dive mark action that launched the app arrives here, not through
    // the response callback.
    final launch = await _plugin.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp ?? false) {
      DiveMarkActions.instance.handle(launch!.notificationResponse?.actionId);
    }

    _initialized = true;
    _log.info('Notification service initialized');
  }

  static DarwinNotificationCategory _diveMarkCategory(
    String id,
    DiveMarkAction action,
    String title,
  ) => DarwinNotificationCategory(
    id,
    actions: [
      // Foreground: it opens the app, so the tap reaches it on every device
      // (issue #637).
      DarwinNotificationAction.plain(
        action.name,
        title,
        options: {DarwinNotificationActionOption.foreground},
      ),
    ],
  );

  void _onNotificationTapped(NotificationResponse response) {
    // An Entered water or Surfaced tap (issue #637) is the dive mark
    // listener's, not a route to open.
    if (DiveMarkActions.instance.handle(response.actionId)) return;
    _log.info('Notification tapped: ${response.payload}');
    if (response.payload != null) {
      // A document reminder carries `document:<id>`; the router maps every
      // payload to its route (notificationPayloadRoute).
      _selectedEquipmentId = response.payload;
      onNotificationTapped?.call(response.payload!);
    }
  }

  /// Check if we're on a mobile platform that supports notifications
  bool get _isMobilePlatform => HostPlatform.isIOS || HostPlatform.isAndroid;

  /// Request notification permissions
  Future<bool> requestPermission() async {
    if (!_isMobilePlatform) return true; // Desktop doesn't need permission
    if (HostPlatform.isIOS) {
      final result = await _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, badge: true, sound: true);
      return result ?? false;
    } else if (HostPlatform.isAndroid) {
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
    if (HostPlatform.isIOS) {
      final impl = _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      final settings = await impl?.checkPermissions();
      return settings?.isEnabled ?? false;
    } else if (HostPlatform.isAndroid) {
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

  /// Title for [showBackupNotification]. Pure, so the wording is testable
  /// without the platform channel (as with [serviceReminderBody]).
  static String backupNotificationTitle({
    required bool success,
    required bool cloudCopyMissing,
    bool extraCopyMissing = false,
  }) {
    if (!success) return 'Backup Failed';
    if (cloudCopyMissing) return 'Backup Complete (device only)';
    return extraCopyMissing
        ? 'Backup Complete (not every account)'
        : 'Backup Complete';
  }

  /// Body for [showBackupNotification].
  ///
  /// [cloudCopyMissing] means the user has cloud backup switched on but this
  /// run produced no cloud copy -- an unreachable provider, expired auth, or
  /// no network. The local backup is intact, so this is not a failure, but
  /// saying "backed up successfully" would tell the user their off-device
  /// copy is safe when it is not. [extraCopyMissing] means the main copy is
  /// off the device but an account it is also copied to (issue #3782) did
  /// not get one; a missing main copy says the stronger thing.
  static String backupNotificationBody({
    required bool success,
    required bool cloudCopyMissing,
    bool extraCopyMissing = false,
    String? error,
  }) {
    if (!success) {
      return 'Automatic backup failed'
          '${error != null ? ': $error' : '. Please try a manual backup.'}';
    }
    if (cloudCopyMissing) {
      return 'Your dive data was backed up on this device. The cloud copy could '
          'not be uploaded -- it will be retried at the next backup.';
    }
    return extraCopyMissing
        ? 'Your dive data was backed up, but the copy did not reach every '
              'account. It will be retried at the next backup.'
        : 'Your dive data has been backed up successfully.';
  }

  /// Shows, or updates, the notification that offers the next dive mark
  /// while a GPS track records (issue #637).
  Future<void> showDiveMarkActions({
    required DiveMarkAction action,
    required String actionLabel,
    required String title,
    required String body,
  }) async {
    if (!_isMobilePlatform) return;
    await _plugin.show(
      id: _diveMarkNotificationId,
      title: title,
      body: body,
      notificationDetails: diveMarkNotificationDetails(
        action: action,
        actionLabel: actionLabel,
      ),
      payload: kDiveMarkPayload,
    );
  }

  /// Removes the dive mark notification, when the recording stops.
  Future<void> cancelDiveMarkActions() async {
    if (!_isMobilePlatform) return;
    await _plugin.cancel(id: _diveMarkNotificationId);
  }

  static final _diveMarkNotificationId = _stableNotificationId('dive-marks');

  /// Show an immediate notification for backup results.
  ///
  /// Used by both foreground operations and background tasks.
  /// Uses a separate Android channel from equipment reminders.
  Future<void> showBackupNotification({
    required bool success,
    String? error,
    bool cloudCopyMissing = false,
    bool extraCopyMissing = false,
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

    // Use a fixed ID so repeated backup notifications replace each other
    const backupNotificationId = 99000;

    await _plugin.show(
      id: backupNotificationId,
      title: backupNotificationTitle(
        success: success,
        cloudCopyMissing: cloudCopyMissing,
        extraCopyMissing: extraCopyMissing,
      ),
      body: backupNotificationBody(
        success: success,
        cloudCopyMissing: cloudCopyMissing,
        extraCopyMissing: extraCopyMissing,
        error: error,
      ),
      notificationDetails: details,
    );

    _log.info('Showed backup notification (success: $success)');
  }

  /// One-shot document expiry reminder (issue #2613). The id is stable per
  /// document and stage, so rescheduling replaces rather than duplicates.
  /// [title] and [body] arrive localized from the scheduler.
  Future<int> scheduleDocumentReminder({
    required String documentId,
    required String title,
    required String body,
    required DocumentReminderStage stage,
    required DateTime scheduledDate,
  }) async {
    if (!_isMobilePlatform) return 0;
    final notificationId = _documentReminderId(documentId, stage);
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'document_expiry_reminders',
        'Document Expiry Reminders',
        channelDescription:
            'Reminders before insurance, medical clearance and other '
            'documents expire',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
        category: AndroidNotificationCategory.reminder,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );
    final scheduledTz = tz.TZDateTime.from(scheduledDate, tz.local);
    await _plugin.zonedSchedule(
      id: notificationId,
      title: title,
      body: body,
      scheduledDate: scheduledTz,
      notificationDetails: details,
      payload: '$_documentPayloadPrefix$documentId',
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
    _log.info(
      'Scheduled document notification $notificationId for $documentId '
      'at $scheduledTz',
    );
    return notificationId;
  }

  /// Cancels both of [documentId]'s reminders, scheduled or not.
  Future<void> cancelDocumentReminders(String documentId) async {
    for (final stage in DocumentReminderStage.values) {
      await cancelNotification(_documentReminderId(documentId, stage));
    }
  }

  /// The ids of documents with a reminder pending in the OS, read from the
  /// payloads, so a full schedule can cancel the ones whose document was
  /// deleted elsewhere (a sync, an owner delete) or no longer reminds.
  Future<Set<String>> pendingDocumentReminderIds() async {
    if (!_isMobilePlatform) return const {};
    final pending = await _plugin.pendingNotificationRequests();
    return {
      for (final p in pending)
        if (p.payload case final payload?
            when payload.startsWith(_documentPayloadPrefix))
          payload.substring(_documentPayloadPrefix.length),
    };
  }

  int _documentReminderId(String documentId, DocumentReminderStage stage) =>
      _stableNotificationId('document#$documentId#${stage.name}');

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

/// The dive mark notification's look (issue #637): quiet, kept until the
/// recording stops, with [action] as its only button. Both platforms open
/// the app on a tap, so the tap reaches it whatever the device allows.
NotificationDetails diveMarkNotificationDetails({
  required DiveMarkAction action,
  required String actionLabel,
}) => NotificationDetails(
  android: AndroidNotificationDetails(
    'dive_marks',
    'Dive Marks',
    channelDescription: 'Entered water and Surfaced while a GPS track records',
    importance: Importance.low,
    priority: Priority.low,
    ongoing: true,
    onlyAlertOnce: true,
    actions: [
      AndroidNotificationAction(
        action.name,
        actionLabel,
        showsUserInterface: true,
      ),
    ],
  ),
  iOS: DarwinNotificationDetails(
    presentAlert: true,
    presentSound: false,
    categoryIdentifier: action == DiveMarkAction.enteredWater
        ? kDiveMarkEnterCategory
        : kDiveMarkSurfaceCategory,
  ),
);
