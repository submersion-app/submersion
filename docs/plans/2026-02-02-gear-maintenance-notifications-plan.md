# Gear Maintenance Notifications Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Implement local push notifications to remind users when dive equipment is due for service.

**Architecture:** Mobile-only (iOS/Android) local notifications using `flutter_local_notifications` with background refresh via `workmanager`. Settings stored in existing `diver_settings` table with per-equipment overrides in `equipment` table.

**Tech Stack:** flutter_local_notifications, workmanager, timezone, Drift ORM, Riverpod

---

## Task 1: Add Package Dependencies

**Files:**
- Modify: `pubspec.yaml`

**Step 1: Add dependencies**

Add to `dependencies` section of pubspec.yaml:

```yaml
  # Notifications
  flutter_local_notifications: ^18.0.1
  workmanager: ^0.5.2
  timezone: ^0.10.0
```

**Step 2: Run flutter pub get**

Run: `flutter pub get`
Expected: Dependencies resolve successfully

**Step 3: Commit**

```bash
git add pubspec.yaml pubspec.lock
git commit -m "feat: add notification dependencies"
```

---

## Task 2: Database Migration - DiverSettings Columns

**Files:**
- Modify: `lib/core/database/database.dart`

**Step 1: Add notification columns to DiverSettings table**

In the `DiverSettings` class (around line 487), add after the `showPressureThresholdMarkers` column:

```dart
  // Notification settings (v26)
  BoolColumn get notificationsEnabled =>
      boolean().withDefault(const Constant(true))();
  TextColumn get serviceReminderDays =>
      text().withDefault(const Constant('[7, 14, 30]'))(); // JSON array
  TextColumn get reminderTime =>
      text().withDefault(const Constant('09:00'))(); // HH:mm format
```

**Step 2: Increment schema version**

Change `schemaVersion => 25` to `schemaVersion => 26`

**Step 3: Add migration**

In the `onUpgrade` method, add after the `from < 25` block:

```dart
        if (from < 26) {
          // Notification settings for service reminders
          await customStatement(
            'ALTER TABLE diver_settings ADD COLUMN notifications_enabled INTEGER NOT NULL DEFAULT 1',
          );
          await customStatement(
            "ALTER TABLE diver_settings ADD COLUMN service_reminder_days TEXT NOT NULL DEFAULT '[7, 14, 30]'",
          );
          await customStatement(
            "ALTER TABLE diver_settings ADD COLUMN reminder_time TEXT NOT NULL DEFAULT '09:00'",
          );
        }
```

**Step 4: Run build_runner**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: database.g.dart regenerates successfully

**Step 5: Commit**

```bash
git add lib/core/database/database.dart lib/core/database/database.g.dart
git commit -m "feat: add notification columns to diver_settings (schema v26)"
```

---

## Task 3: Database Migration - Equipment Columns

**Files:**
- Modify: `lib/core/database/database.dart`

**Step 1: Add notification override columns to Equipment table**

In the `Equipment` class (around line 268), add after the `isActive` column:

```dart
  // Notification overrides (v27)
  BoolColumn get customReminderEnabled =>
      boolean().nullable()(); // NULL = use global, true = custom, false = disabled
  TextColumn get customReminderDays =>
      text().nullable()(); // JSON array override, e.g. "[7, 30]"
```

**Step 2: Increment schema version**

Change `schemaVersion => 26` to `schemaVersion => 27`

**Step 3: Add migration**

In the `onUpgrade` method, add after the `from < 26` block:

```dart
        if (from < 27) {
          // Per-equipment notification overrides
          await customStatement(
            'ALTER TABLE equipment ADD COLUMN custom_reminder_enabled INTEGER',
          );
          await customStatement(
            'ALTER TABLE equipment ADD COLUMN custom_reminder_days TEXT',
          );
        }
```

**Step 4: Run build_runner**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: database.g.dart regenerates successfully

**Step 5: Commit**

```bash
git add lib/core/database/database.dart lib/core/database/database.g.dart
git commit -m "feat: add notification override columns to equipment (schema v27)"
```

---

## Task 4: Database Migration - ScheduledNotifications Table

**Files:**
- Modify: `lib/core/database/database.dart`

**Step 1: Create ScheduledNotifications table class**

Add before the `@DriftDatabase` annotation (around line 940):

```dart
/// Tracks scheduled notifications to enable smart rescheduling
class ScheduledNotifications extends Table {
  TextColumn get id => text()();
  TextColumn get equipmentId =>
      text().references(Equipment, #id, onDelete: KeyAction.cascade)();
  IntColumn get scheduledDate => integer()(); // Unix timestamp
  IntColumn get reminderDaysBefore => integer()(); // 7, 14, or 30
  IntColumn get notificationId => integer()(); // Platform notification ID
  IntColumn get createdAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}
```

**Step 2: Add to tables list**

In the `@DriftDatabase` annotation tables list, add `ScheduledNotifications` after `CachedRegions`:

```dart
    // Maps & Visualization
    CachedRegions,
    // Notifications
    ScheduledNotifications,
```

**Step 3: Increment schema version**

Change `schemaVersion => 27` to `schemaVersion => 28`

**Step 4: Add migration**

In the `onUpgrade` method, add after the `from < 27` block:

```dart
        if (from < 28) {
          // Scheduled notifications tracking table
          await customStatement('''
            CREATE TABLE IF NOT EXISTS scheduled_notifications (
              id TEXT NOT NULL PRIMARY KEY,
              equipment_id TEXT NOT NULL REFERENCES equipment(id) ON DELETE CASCADE,
              scheduled_date INTEGER NOT NULL,
              reminder_days_before INTEGER NOT NULL,
              notification_id INTEGER NOT NULL,
              created_at INTEGER NOT NULL
            )
          ''');
          // Index for efficient lookup by equipment
          await customStatement('''
            CREATE INDEX IF NOT EXISTS idx_scheduled_notifications_equipment
            ON scheduled_notifications(equipment_id)
          ''');
        }
```

**Step 5: Run build_runner**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: database.g.dart regenerates successfully

**Step 6: Commit**

```bash
git add lib/core/database/database.dart lib/core/database/database.g.dart
git commit -m "feat: add scheduled_notifications table (schema v28)"
```

---

## Task 5: Update EquipmentItem Entity

**Files:**
- Modify: `lib/features/equipment/domain/entities/equipment_item.dart`

**Step 1: Add notification fields to EquipmentItem**

Add these fields after `isActive` in the class:

```dart
  // Notification overrides
  final bool? customReminderEnabled; // NULL = use global
  final List<int>? customReminderDays; // Override reminder days
```

**Step 2: Update constructor**

Add to constructor parameters:

```dart
    this.customReminderEnabled,
    this.customReminderDays,
```

**Step 3: Update copyWith method**

Add to copyWith parameters:

```dart
    bool? customReminderEnabled,
    List<int>? customReminderDays,
```

Add to return statement:

```dart
      customReminderEnabled: customReminderEnabled ?? this.customReminderEnabled,
      customReminderDays: customReminderDays ?? this.customReminderDays,
```

**Step 4: Update props list**

Add to props:

```dart
    customReminderEnabled,
    customReminderDays,
```

**Step 5: Commit**

```bash
git add lib/features/equipment/domain/entities/equipment_item.dart
git commit -m "feat: add notification override fields to EquipmentItem entity"
```

---

## Task 6: Update Equipment Repository

**Files:**
- Modify: `lib/features/equipment/data/repositories/equipment_repository_impl.dart`

**Step 1: Update _mapRowToEquipment method**

Add after `isActive: row.isActive,`:

```dart
      customReminderEnabled: row.customReminderEnabled,
      customReminderDays: row.customReminderDays != null
          ? (jsonDecode(row.customReminderDays!) as List<dynamic>)
              .cast<int>()
          : null,
```

**Step 2: Add import for dart:convert at top**

```dart
import 'dart:convert';
```

**Step 3: Update createEquipment method**

Add to EquipmentCompanion after `isActive`:

```dart
              customReminderEnabled: Value(equipment.customReminderEnabled),
              customReminderDays: Value(
                equipment.customReminderDays != null
                    ? jsonEncode(equipment.customReminderDays)
                    : null,
              ),
```

**Step 4: Update updateEquipment method**

Add to EquipmentCompanion:

```dart
          customReminderEnabled: Value(equipment.customReminderEnabled),
          customReminderDays: Value(
            equipment.customReminderDays != null
                ? jsonEncode(equipment.customReminderDays)
                : null,
          ),
```

**Step 5: Add method to get equipment needing service reminders**

Add this method to the class:

```dart
  /// Get all active equipment with service due dates for notification scheduling
  Future<List<EquipmentItem>> getEquipmentWithServiceDates({
    String? diverId,
  }) async {
    try {
      final query = _db.select(_db.equipment)
        ..where((t) => t.isActive.equals(true))
        ..where((t) => t.lastServiceDate.isNotNull())
        ..where((t) => t.serviceIntervalDays.isNotNull());

      if (diverId != null) {
        query.where((t) => t.diverId.equals(diverId));
      }

      final rows = await query.get();
      return rows.map(_mapRowToEquipment).toList();
    } catch (e, stackTrace) {
      _log.error('Failed to get equipment with service dates', e, stackTrace);
      rethrow;
    }
  }
```

**Step 6: Update searchEquipment to include new fields**

In the `searchEquipment` method's result mapping, add:

```dart
          customReminderEnabled: row.data['custom_reminder_enabled'] == 1
              ? true
              : row.data['custom_reminder_enabled'] == 0
                  ? false
                  : null,
          customReminderDays: row.data['custom_reminder_days'] != null
              ? (jsonDecode(row.data['custom_reminder_days'] as String)
                      as List<dynamic>)
                  .cast<int>()
              : null,
```

**Step 7: Commit**

```bash
git add lib/features/equipment/data/repositories/equipment_repository_impl.dart
git commit -m "feat: add notification fields to equipment repository"
```

---

## Task 7: Create NotificationSettings Entity

**Files:**
- Create: `lib/features/notifications/domain/entities/notification_settings.dart`

**Step 1: Create the file with content**

```dart
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

/// Notification settings for service reminders
class NotificationSettings extends Equatable {
  final bool enabled;
  final List<int> reminderDays; // Days before due date to remind
  final TimeOfDay reminderTime; // Time of day to send reminders

  const NotificationSettings({
    this.enabled = true,
    this.reminderDays = const [7, 14, 30],
    this.reminderTime = const TimeOfDay(hour: 9, minute: 0),
  });

  /// Parse reminder days from JSON string
  static List<int> parseReminderDays(String json) {
    try {
      final List<dynamic> parsed = List<dynamic>.from(
        json.isNotEmpty ? _parseJsonArray(json) : [],
      );
      return parsed.cast<int>();
    } catch (_) {
      return const [7, 14, 30];
    }
  }

  static List<dynamic> _parseJsonArray(String json) {
    // Simple JSON array parser for "[7, 14, 30]" format
    final trimmed = json.trim();
    if (!trimmed.startsWith('[') || !trimmed.endsWith(']')) {
      return [];
    }
    final inner = trimmed.substring(1, trimmed.length - 1);
    if (inner.isEmpty) return [];
    return inner.split(',').map((s) => int.parse(s.trim())).toList();
  }

  /// Parse reminder time from "HH:mm" format
  static TimeOfDay parseReminderTime(String time) {
    try {
      final parts = time.split(':');
      return TimeOfDay(
        hour: int.parse(parts[0]),
        minute: int.parse(parts[1]),
      );
    } catch (_) {
      return const TimeOfDay(hour: 9, minute: 0);
    }
  }

  /// Convert to JSON string for storage
  String get reminderDaysJson => '[${reminderDays.join(', ')}]';

  /// Convert time to "HH:mm" format
  String get reminderTimeString =>
      '${reminderTime.hour.toString().padLeft(2, '0')}:${reminderTime.minute.toString().padLeft(2, '0')}';

  NotificationSettings copyWith({
    bool? enabled,
    List<int>? reminderDays,
    TimeOfDay? reminderTime,
  }) {
    return NotificationSettings(
      enabled: enabled ?? this.enabled,
      reminderDays: reminderDays ?? this.reminderDays,
      reminderTime: reminderTime ?? this.reminderTime,
    );
  }

  @override
  List<Object?> get props => [enabled, reminderDays, reminderTime];
}
```

**Step 2: Commit**

```bash
git add lib/features/notifications/domain/entities/notification_settings.dart
git commit -m "feat: create NotificationSettings entity"
```

---

## Task 8: Update AppSettings and Repository

**Files:**
- Modify: `lib/features/settings/presentation/providers/settings_providers.dart`
- Modify: `lib/features/settings/data/repositories/diver_settings_repository.dart`

**Step 1: Add notification fields to AppSettings class**

In `settings_providers.dart`, add these fields to `AppSettings` class after `showPressureThresholdMarkers`:

```dart
  // Notification settings
  final bool notificationsEnabled;
  final List<int> serviceReminderDays;
  final TimeOfDay reminderTime;
```

**Step 2: Update AppSettings constructor**

Add defaults:

```dart
    this.notificationsEnabled = true,
    this.serviceReminderDays = const [7, 14, 30],
    this.reminderTime = const TimeOfDay(hour: 9, minute: 0),
```

**Step 3: Update AppSettings copyWith**

Add parameters and mappings:

```dart
    bool? notificationsEnabled,
    List<int>? serviceReminderDays,
    TimeOfDay? reminderTime,
```

```dart
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      serviceReminderDays: serviceReminderDays ?? this.serviceReminderDays,
      reminderTime: reminderTime ?? this.reminderTime,
```

**Step 4: Update DiverSettingsRepository._mapRowToAppSettings**

In `diver_settings_repository.dart`, add:

```dart
      notificationsEnabled: row.notificationsEnabled,
      serviceReminderDays: _parseReminderDays(row.serviceReminderDays),
      reminderTime: _parseReminderTime(row.reminderTime),
```

**Step 5: Add parsing helper methods to DiverSettingsRepository**

```dart
  List<int> _parseReminderDays(String json) {
    try {
      final trimmed = json.trim();
      if (!trimmed.startsWith('[') || !trimmed.endsWith(']')) {
        return const [7, 14, 30];
      }
      final inner = trimmed.substring(1, trimmed.length - 1);
      if (inner.isEmpty) return const [7, 14, 30];
      return inner.split(',').map((s) => int.parse(s.trim())).toList();
    } catch (_) {
      return const [7, 14, 30];
    }
  }

  TimeOfDay _parseReminderTime(String time) {
    try {
      final parts = time.split(':');
      return TimeOfDay(
        hour: int.parse(parts[0]),
        minute: int.parse(parts[1]),
      );
    } catch (_) {
      return const TimeOfDay(hour: 9, minute: 0);
    }
  }

  String _formatReminderDays(List<int> days) => '[${days.join(', ')}]';

  String _formatReminderTime(TimeOfDay time) =>
      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
```

**Step 6: Update createSettingsForDiver**

Add to DiverSettingsCompanion:

```dart
              notificationsEnabled: Value(s.notificationsEnabled),
              serviceReminderDays: Value(_formatReminderDays(s.serviceReminderDays)),
              reminderTime: Value(_formatReminderTime(s.reminderTime)),
```

**Step 7: Update updateSettingsForDiver**

Add to DiverSettingsCompanion:

```dart
          notificationsEnabled: Value(settings.notificationsEnabled),
          serviceReminderDays: Value(_formatReminderDays(settings.serviceReminderDays)),
          reminderTime: Value(_formatReminderTime(settings.reminderTime)),
```

**Step 8: Commit**

```bash
git add lib/features/settings/presentation/providers/settings_providers.dart lib/features/settings/data/repositories/diver_settings_repository.dart
git commit -m "feat: add notification settings to AppSettings and repository"
```

---

## Task 9: Add Settings Notifier Methods

**Files:**
- Modify: `lib/features/settings/presentation/providers/settings_providers.dart`

**Step 1: Add setter methods to SettingsNotifier class**

Add after `setShowPressureThresholdMarkers`:

```dart
  // Notification settings setters

  Future<void> setNotificationsEnabled(bool value) async {
    state = state.copyWith(notificationsEnabled: value);
    await _saveSettings();
  }

  Future<void> setServiceReminderDays(List<int> days) async {
    // Sort and deduplicate
    final sortedDays = days.toSet().toList()..sort((a, b) => b.compareTo(a));
    state = state.copyWith(serviceReminderDays: sortedDays);
    await _saveSettings();
  }

  Future<void> setReminderTime(TimeOfDay time) async {
    state = state.copyWith(reminderTime: time);
    await _saveSettings();
  }

  Future<void> toggleReminderDay(int days) async {
    final current = List<int>.from(state.serviceReminderDays);
    if (current.contains(days)) {
      // Don't allow removing the last day
      if (current.length > 1) {
        current.remove(days);
      }
    } else {
      current.add(days);
    }
    await setServiceReminderDays(current);
  }
```

**Step 2: Add convenience providers**

Add after other convenience providers:

```dart
/// Notification settings convenience providers
final notificationsEnabledProvider = Provider<bool>((ref) {
  return ref.watch(settingsProvider.select((s) => s.notificationsEnabled));
});

final serviceReminderDaysProvider = Provider<List<int>>((ref) {
  return ref.watch(settingsProvider.select((s) => s.serviceReminderDays));
});

final reminderTimeProvider = Provider<TimeOfDay>((ref) {
  return ref.watch(settingsProvider.select((s) => s.reminderTime));
});
```

**Step 3: Commit**

```bash
git add lib/features/settings/presentation/providers/settings_providers.dart
git commit -m "feat: add notification settings methods and providers"
```

---

## Task 10: Create NotificationService

**Files:**
- Create: `lib/core/services/notification_service.dart`

**Step 1: Create the notification service**

```dart
import 'dart:io';

import 'package:flutter/material.dart';
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

  /// Request notification permissions
  Future<bool> requestPermission() async {
    if (Platform.isIOS) {
      final result = await _plugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: true, sound: true);
      return result ?? false;
    } else if (Platform.isAndroid) {
      final impl = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      final result = await impl?.requestNotificationsPermission();
      return result ?? false;
    }
    return false;
  }

  /// Check if notifications are permitted
  Future<bool> isPermissionGranted() async {
    if (Platform.isIOS) {
      final impl = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      final settings = await impl?.checkPermissions();
      return settings?.isEnabled ?? false;
    } else if (Platform.isAndroid) {
      final impl = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
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
    final notificationId = equipmentId.hashCode + daysBefore;

    final title = 'Service Due: $equipmentName';
    final body = daysBefore > 0
        ? '${brandModel ?? equipmentName} service is due in $daysBefore days'
        : '${brandModel ?? equipmentName} service is overdue';

    final androidDetails = AndroidNotificationDetails(
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

    final details = NotificationDetails(
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
    );

    _log.info(
      'Scheduled notification $notificationId for $equipmentName at $scheduledTz',
    );

    return notificationId;
  }

  /// Cancel a specific notification
  Future<void> cancelNotification(int notificationId) async {
    await _plugin.cancel(notificationId);
    _log.info('Cancelled notification $notificationId');
  }

  /// Cancel all notifications for a specific equipment item
  Future<void> cancelNotificationsForEquipment(
    String equipmentId,
    List<int> daysBefore,
  ) async {
    for (final days in daysBefore) {
      final notificationId = equipmentId.hashCode + days;
      await cancelNotification(notificationId);
    }
  }

  /// Cancel all scheduled notifications
  Future<void> cancelAllNotifications() async {
    await _plugin.cancelAll();
    _log.info('Cancelled all notifications');
  }

  /// Get list of pending notifications
  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    return _plugin.pendingNotificationRequests();
  }
}
```

**Step 2: Commit**

```bash
git add lib/core/services/notification_service.dart
git commit -m "feat: create NotificationService for local notifications"
```

---

## Task 11: Create ScheduledNotificationRepository

**Files:**
- Create: `lib/features/notifications/data/repositories/scheduled_notification_repository.dart`

**Step 1: Create the repository**

```dart
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/logger_service.dart';

/// Repository for tracking scheduled notifications
class ScheduledNotificationRepository {
  AppDatabase get _db => DatabaseService.instance.database;
  final _uuid = const Uuid();
  final _log = LoggerService.forClass(ScheduledNotificationRepository);

  /// Get all scheduled notifications for an equipment item
  Future<List<ScheduledNotification>> getForEquipment(
    String equipmentId,
  ) async {
    try {
      final query = _db.select(_db.scheduledNotifications)
        ..where((t) => t.equipmentId.equals(equipmentId));
      return query.get();
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get scheduled notifications for equipment: $equipmentId',
        e,
        stackTrace,
      );
      rethrow;
    }
  }

  /// Check if a notification is already scheduled
  Future<bool> isScheduled({
    required String equipmentId,
    required int reminderDaysBefore,
    required DateTime scheduledDate,
  }) async {
    try {
      final query = _db.select(_db.scheduledNotifications)
        ..where((t) => t.equipmentId.equals(equipmentId))
        ..where((t) => t.reminderDaysBefore.equals(reminderDaysBefore))
        ..where(
          (t) => t.scheduledDate.equals(scheduledDate.millisecondsSinceEpoch),
        );
      final result = await query.getSingleOrNull();
      return result != null;
    } catch (e, stackTrace) {
      _log.error('Failed to check if notification is scheduled', e, stackTrace);
      return false;
    }
  }

  /// Record a scheduled notification
  Future<void> recordScheduled({
    required String equipmentId,
    required DateTime scheduledDate,
    required int reminderDaysBefore,
    required int notificationId,
  }) async {
    try {
      final id = _uuid.v4();
      final now = DateTime.now().millisecondsSinceEpoch;

      await _db.into(_db.scheduledNotifications).insert(
            ScheduledNotificationsCompanion(
              id: Value(id),
              equipmentId: Value(equipmentId),
              scheduledDate: Value(scheduledDate.millisecondsSinceEpoch),
              reminderDaysBefore: Value(reminderDaysBefore),
              notificationId: Value(notificationId),
              createdAt: Value(now),
            ),
          );

      _log.info(
        'Recorded scheduled notification for equipment $equipmentId, '
        '$reminderDaysBefore days before',
      );
    } catch (e, stackTrace) {
      _log.error('Failed to record scheduled notification', e, stackTrace);
      rethrow;
    }
  }

  /// Delete scheduled notification records for equipment
  Future<void> deleteForEquipment(String equipmentId) async {
    try {
      await (_db.delete(_db.scheduledNotifications)
            ..where((t) => t.equipmentId.equals(equipmentId)))
          .go();
      _log.info('Deleted scheduled notifications for equipment $equipmentId');
    } catch (e, stackTrace) {
      _log.error(
        'Failed to delete scheduled notifications for equipment',
        e,
        stackTrace,
      );
      rethrow;
    }
  }

  /// Delete all scheduled notification records
  Future<void> deleteAll() async {
    try {
      await _db.delete(_db.scheduledNotifications).go();
      _log.info('Deleted all scheduled notification records');
    } catch (e, stackTrace) {
      _log.error('Failed to delete all scheduled notifications', e, stackTrace);
      rethrow;
    }
  }

  /// Get all scheduled notifications
  Future<List<ScheduledNotification>> getAll() async {
    try {
      return _db.select(_db.scheduledNotifications).get();
    } catch (e, stackTrace) {
      _log.error('Failed to get all scheduled notifications', e, stackTrace);
      rethrow;
    }
  }

  /// Delete expired scheduled notification records
  Future<void> deleteExpired() async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      await (_db.delete(_db.scheduledNotifications)
            ..where((t) => t.scheduledDate.isSmallerThanValue(now)))
          .go();
      _log.info('Deleted expired scheduled notification records');
    } catch (e, stackTrace) {
      _log.error('Failed to delete expired notifications', e, stackTrace);
      rethrow;
    }
  }
}
```

**Step 2: Commit**

```bash
git add lib/features/notifications/data/repositories/scheduled_notification_repository.dart
git commit -m "feat: create ScheduledNotificationRepository"
```

---

## Task 12: Create NotificationScheduler

**Files:**
- Create: `lib/features/notifications/data/services/notification_scheduler.dart`

**Step 1: Create the scheduler service**

```dart
import 'package:flutter/material.dart';

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
  })  : _notificationService = notificationService ?? NotificationService.instance,
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
      await _scheduleForEquipment(
        item: item,
        globalSettings: settings,
      );
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
      final alreadyScheduled = await _scheduledNotificationRepository.isScheduled(
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
```

**Step 2: Commit**

```bash
git add lib/features/notifications/data/services/notification_scheduler.dart
git commit -m "feat: create NotificationScheduler service"
```

---

## Task 13: Create Notification Providers

**Files:**
- Create: `lib/features/notifications/presentation/providers/notification_providers.dart`

**Step 1: Create the providers file**

```dart
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/notification_service.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/notifications/data/repositories/scheduled_notification_repository.dart';
import 'package:submersion/features/notifications/data/services/notification_scheduler.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

/// Provider for the notification service singleton
final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService.instance;
});

/// Provider for the scheduled notification repository
final scheduledNotificationRepositoryProvider =
    Provider<ScheduledNotificationRepository>((ref) {
  return ScheduledNotificationRepository();
});

/// Provider for the notification scheduler
final notificationSchedulerProvider = Provider<NotificationScheduler>((ref) {
  return NotificationScheduler(
    notificationService: ref.watch(notificationServiceProvider),
    equipmentRepository: EquipmentRepository(),
    scheduledNotificationRepository:
        ref.watch(scheduledNotificationRepositoryProvider),
  );
});

/// Provider to check if notification permission is granted
final notificationPermissionProvider = FutureProvider<bool>((ref) async {
  final service = ref.watch(notificationServiceProvider);
  return service.isPermissionGranted();
});

/// Provider that schedules notifications when settings or equipment changes
final notificationSchedulingProvider = FutureProvider<void>((ref) async {
  final settings = ref.watch(settingsProvider);
  final diverId = ref.watch(currentDiverIdProvider);
  final scheduler = ref.watch(notificationSchedulerProvider);

  // Only schedule if notifications are enabled
  if (!settings.notificationsEnabled) return;

  await scheduler.scheduleAll(settings: settings, diverId: diverId);
});
```

**Step 2: Commit**

```bash
git add lib/features/notifications/presentation/providers/notification_providers.dart
git commit -m "feat: create notification providers"
```

---

## Task 14: iOS Platform Configuration

**Files:**
- Modify: `ios/Runner/Info.plist`
- Modify: `ios/Runner/AppDelegate.swift`

**Step 1: Add background modes to Info.plist**

Add before the closing `</dict>` tag:

```xml
	<key>UIBackgroundModes</key>
	<array>
		<string>fetch</string>
		<string>processing</string>
	</array>
```

**Step 2: Update AppDelegate.swift for workmanager**

Add import at top:

```swift
import workmanager
```

In `application(_:didFinishLaunchingWithOptions:)`, add after `GeneratedPluginRegistrant.register(with: self)`:

```swift
    WorkmanagerPlugin.setPluginRegistrantCallback { registry in
      GeneratedPluginRegistrant.register(with: registry)
    }
```

**Step 3: Commit**

```bash
git add ios/Runner/Info.plist ios/Runner/AppDelegate.swift
git commit -m "feat: configure iOS for background notifications"
```

---

## Task 15: Android Platform Configuration

**Files:**
- Modify: `android/app/src/main/AndroidManifest.xml`

**Step 1: Add permissions**

Add inside the `<manifest>` tag before `<application>`:

```xml
    <uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM" />
    <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED" />
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
```

**Step 2: Add boot receiver**

Add inside the `<application>` tag:

```xml
        <receiver android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver"
            android:exported="false">
            <intent-filter>
                <action android:name="android.intent.action.BOOT_COMPLETED" />
                <action android:name="android.intent.action.MY_PACKAGE_REPLACED" />
            </intent-filter>
        </receiver>
```

**Step 3: Commit**

```bash
git add android/app/src/main/AndroidManifest.xml
git commit -m "feat: configure Android for notifications and boot receiver"
```

---

## Task 16: Add Notifications Settings Section to UI

**Files:**
- Modify: `lib/features/settings/presentation/pages/settings_page.dart`
- Modify: `lib/features/settings/presentation/widgets/settings_list_content.dart`

**Step 1: Add notifications section to settingsSections list**

In `settings_list_content.dart`, add to the `settingsSections` list after the appearance section:

```dart
  SettingsSection(
    id: 'notifications',
    title: 'Notifications',
    subtitle: 'Service reminders',
    icon: Icons.notifications_outlined,
    color: Colors.orange,
  ),
```

**Step 2: Add notifications case to _buildSectionContent in settings_page.dart**

In the `_buildSectionContent` method switch statement, add:

```dart
      case 'notifications':
        return _NotificationsSectionContent(ref: ref);
```

**Step 3: Add notifications case to _SettingsSectionDetailPage._buildContent**

Add the same case:

```dart
      case 'notifications':
        return _NotificationsSectionContent(ref: ref);
```

**Step 4: Create _NotificationsSectionContent widget**

Add this widget class before the `_buildSectionHeader` helper:

```dart
/// Notifications section content
class _NotificationsSectionContent extends ConsumerWidget {
  final WidgetRef ref;

  const _NotificationsSectionContent({required this.ref});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final permissionAsync = ref.watch(notificationPermissionProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(context, 'Service Reminders'),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Enable Service Reminders'),
                  subtitle: const Text(
                    'Get notified when equipment service is due',
                  ),
                  secondary: const Icon(Icons.notifications_active),
                  value: settings.notificationsEnabled,
                  onChanged: (value) async {
                    if (value) {
                      // Request permission when enabling
                      final granted = await NotificationService.instance
                          .requestPermission();
                      if (!granted && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Please enable notifications in system settings',
                            ),
                          ),
                        );
                        return;
                      }
                    }
                    ref
                        .read(settingsProvider.notifier)
                        .setNotificationsEnabled(value);
                  },
                ),
                if (settings.notificationsEnabled) ...[
                  const Divider(height: 1),
                  permissionAsync.when(
                    data: (granted) {
                      if (!granted) {
                        return ListTile(
                          leading: const Icon(
                            Icons.warning,
                            color: Colors.orange,
                          ),
                          title: const Text('Notifications Disabled'),
                          subtitle: const Text(
                            'Enable in system settings to receive reminders',
                          ),
                          trailing: TextButton(
                            onPressed: () async {
                              await NotificationService.instance
                                  .requestPermission();
                              ref.invalidate(notificationPermissionProvider);
                            },
                            child: const Text('Enable'),
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                ],
              ],
            ),
          ),
          if (settings.notificationsEnabled) ...[
            const SizedBox(height: 24),
            _buildSectionHeader(context, 'Reminder Schedule'),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Remind me before service is due:',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      children: [7, 14, 30].map((days) {
                        final isSelected =
                            settings.serviceReminderDays.contains(days);
                        return FilterChip(
                          label: Text('$days days'),
                          selected: isSelected,
                          onSelected: (_) {
                            ref
                                .read(settingsProvider.notifier)
                                .toggleReminderDay(days);
                          },
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: ListTile(
                leading: const Icon(Icons.access_time),
                title: const Text('Reminder Time'),
                subtitle: Text(
                  '${settings.reminderTime.hour.toString().padLeft(2, '0')}:${settings.reminderTime.minute.toString().padLeft(2, '0')}',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showTimePicker(context, ref, settings),
              ),
            ),
            const SizedBox(height: 16),
            _buildInfoCard(
              context,
              'How it works',
              'Notifications are scheduled when the app launches and refresh '
                  'periodically in the background. You can customize reminders '
                  'for individual equipment items in their edit screen.',
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _showTimePicker(
    BuildContext context,
    WidgetRef ref,
    AppSettings settings,
  ) async {
    final time = await showTimePicker(
      context: context,
      initialTime: settings.reminderTime,
    );
    if (time != null) {
      ref.read(settingsProvider.notifier).setReminderTime(time);
    }
  }
}
```

**Step 5: Add import for notification providers at top of settings_page.dart**

```dart
import 'package:submersion/core/services/notification_service.dart';
import 'package:submersion/features/notifications/presentation/providers/notification_providers.dart';
```

**Step 6: Commit**

```bash
git add lib/features/settings/presentation/pages/settings_page.dart lib/features/settings/presentation/widgets/settings_list_content.dart
git commit -m "feat: add notifications settings section to settings page"
```

---

## Task 17: Add Notification Override UI to Equipment Edit

**Files:**
- Modify: `lib/features/equipment/presentation/pages/equipment_edit_page.dart`

**Step 1: Add state variables for notification overrides**

Add after `bool _hasChanges = false;`:

```dart
  bool? _customReminderEnabled;
  List<int> _customReminderDays = [7, 14, 30];
```

**Step 2: Initialize from existing equipment**

In `_initializeFromEquipment`, add:

```dart
    _customReminderEnabled = equipment.customReminderEnabled;
    _customReminderDays = equipment.customReminderDays ?? const [7, 14, 30];
```

**Step 3: Add notification section to the form**

After the Notes TextFormField section and before the Save Button conditional, add:

```dart
          const SizedBox(height: 24),

          // Notification Overrides
          _buildNotificationSection(context),
```

**Step 4: Create _buildNotificationSection method**

Add this method to the class:

```dart
  Widget _buildNotificationSection(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.notifications, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Notifications (Optional)',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Override global notification settings for this item',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Use Custom Reminders'),
              subtitle: const Text('Set different reminder days for this item'),
              value: _customReminderEnabled == true,
              onChanged: (value) {
                setState(() {
                  _customReminderEnabled = value ? true : null;
                  _hasChanges = true;
                });
              },
              contentPadding: EdgeInsets.zero,
            ),
            if (_customReminderEnabled == true) ...[
              const SizedBox(height: 8),
              Text(
                'Remind me before service is due:',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [7, 14, 30].map((days) {
                  final isSelected = _customReminderDays.contains(days);
                  return FilterChip(
                    label: Text('$days days'),
                    selected: isSelected,
                    onSelected: (_) {
                      setState(() {
                        if (isSelected) {
                          if (_customReminderDays.length > 1) {
                            _customReminderDays = _customReminderDays
                                .where((d) => d != days)
                                .toList();
                          }
                        } else {
                          _customReminderDays = [..._customReminderDays, days];
                        }
                        _hasChanges = true;
                      });
                    },
                  );
                }).toList(),
              ),
            ],
            const Divider(height: 24),
            SwitchListTile(
              title: const Text('Disable Reminders'),
              subtitle:
                  const Text('Turn off all notifications for this item'),
              value: _customReminderEnabled == false,
              onChanged: (value) {
                setState(() {
                  _customReminderEnabled = value ? false : null;
                  _hasChanges = true;
                });
              },
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
    );
  }
```

**Step 5: Update _saveEquipment to include notification fields**

In the EquipmentItem constructor call, add:

```dart
        customReminderEnabled: _customReminderEnabled,
        customReminderDays:
            _customReminderEnabled == true ? _customReminderDays : null,
```

**Step 6: Commit**

```bash
git add lib/features/equipment/presentation/pages/equipment_edit_page.dart
git commit -m "feat: add notification override UI to equipment edit page"
```

---

## Task 18: Initialize Notifications on App Launch

**Files:**
- Modify: `lib/main.dart`

**Step 1: Add notification initialization**

Find the main initialization section and add after database initialization:

```dart
  // Initialize notification service
  await NotificationService.instance.initialize();
```

**Step 2: Add import**

```dart
import 'package:submersion/core/services/notification_service.dart';
```

**Step 3: Commit**

```bash
git add lib/main.dart
git commit -m "feat: initialize notification service on app launch"
```

---

## Task 19: Setup Background Refresh with Workmanager

**Files:**
- Create: `lib/core/services/background_service.dart`
- Modify: `lib/main.dart`

**Step 1: Create background service**

```dart
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
    final log = LoggerService.forClass('BackgroundService');
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
  await Workmanager().initialize(
    callbackDispatcher,
    isInDebugMode: false,
  );

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
```

**Step 2: Update main.dart to initialize background service**

After notification service initialization, add:

```dart
  // Initialize background service for periodic notification refresh
  await initializeBackgroundService();
```

Add import:

```dart
import 'package:submersion/core/services/background_service.dart';
```

**Step 3: Commit**

```bash
git add lib/core/services/background_service.dart lib/main.dart
git commit -m "feat: add background service for notification refresh"
```

---

## Task 20: Schedule Notifications After Settings Load

**Files:**
- Modify: `lib/features/settings/presentation/providers/settings_providers.dart`

**Step 1: Add notification scheduling after settings load**

In the `SettingsNotifier._loadSettings` method, add at the end of the try block (after `state = settings;`):

```dart
      // Schedule notifications with the loaded settings
      _scheduleNotificationsIfNeeded();
```

**Step 2: Add the scheduling helper method**

Add this method to SettingsNotifier:

```dart
  void _scheduleNotificationsIfNeeded() {
    // Use Future.microtask to avoid calling during build
    Future.microtask(() async {
      if (!state.notificationsEnabled) return;

      final diverId = _validatedDiverId;
      final scheduler = NotificationScheduler();

      try {
        await scheduler.scheduleAll(settings: state, diverId: diverId);
      } catch (e) {
        // Log but don't rethrow - notification scheduling shouldn't block settings
        LoggerService.forClass(SettingsNotifier).error(
          'Failed to schedule notifications',
          e,
          StackTrace.current,
        );
      }
    });
  }
```

**Step 3: Add imports**

```dart
import 'package:submersion/features/notifications/data/services/notification_scheduler.dart';
import 'package:submersion/core/services/logger_service.dart';
```

**Step 4: Commit**

```bash
git add lib/features/settings/presentation/providers/settings_providers.dart
git commit -m "feat: schedule notifications when settings are loaded"
```

---

## Task 21: Handle Deep Linking from Notifications

**Files:**
- Modify: `lib/app/router.dart` (or wherever your go_router is configured)

**Step 1: Add notification deep link handling**

In the router configuration, add a redirect handler that checks for pending notification equipment ID:

```dart
  redirect: (context, state) {
    // Check for notification deep link
    final equipmentId = NotificationService.instance.selectedEquipmentId;
    if (equipmentId != null) {
      return '/equipment/$equipmentId';
    }
    return null;
  },
```

**Step 2: Add import**

```dart
import 'package:submersion/core/services/notification_service.dart';
```

**Step 3: Commit**

```bash
git add lib/app/router.dart
git commit -m "feat: handle deep linking from notification taps"
```

---

## Task 22: Run Tests and Format Code

**Step 1: Format code**

Run: `dart format lib/`
Expected: All files formatted

**Step 2: Run analyzer**

Run: `flutter analyze`
Expected: No issues

**Step 3: Run tests**

Run: `flutter test`
Expected: All tests pass

**Step 4: Commit any formatting changes**

```bash
git add -A
git commit -m "chore: format code and fix lint issues"
```

---

## Task 23: Final Integration Test

**Step 1: Run the app on iOS simulator**

Run: `flutter run -d ios`
Expected: App launches successfully

**Step 2: Test notification flow**

1. Go to Settings > Notifications
2. Enable service reminders
3. Accept notification permission prompt
4. Select reminder days (7, 14, 30)
5. Go to Equipment and create an item with service interval
6. Verify notification is scheduled (check device notification settings)

**Step 3: Test equipment override**

1. Edit an equipment item
2. Enable custom reminders
3. Select different reminder days
4. Save and verify custom schedule applies

**Step 4: Final commit**

```bash
git add -A
git commit -m "feat: complete gear maintenance notifications implementation"
```

---

## Summary

This plan implements:
- Local notifications for equipment service reminders on iOS and Android
- Configurable reminder periods (7, 14, 30 days before due)
- Global notification settings in diver preferences
- Per-equipment notification overrides
- Background refresh for reliable notification delivery
- Deep linking to equipment detail from notification taps

Total estimated tasks: 23
Files created: ~8
Files modified: ~12
