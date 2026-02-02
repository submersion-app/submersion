# Gear Maintenance Notifications Design

**Date**: 2026-02-02
**Status**: Approved
**Feature**: Local notifications for equipment service due dates

## Overview

Implement local push notifications to remind users when their dive equipment is due for service. Notifications are scheduled based on configurable advance periods (7, 14, 30 days before due date) with support for multiple reminders per equipment item.

## Requirements

- **Platforms**: iOS and Android only
- **Trigger mechanism**: App launch (primary) + background refresh (backup)
- **Reminder periods**: Multiple selectable (7, 14, 30 days - user can select combinations)
- **Settings scope**: Global defaults with per-equipment override capability
- **Notification tap action**: Deep-link to equipment detail page

## Architecture

### Package Dependencies

```yaml
flutter_local_notifications: ^18.0.1  # Local notification scheduling
workmanager: ^0.5.2                   # Background task execution
timezone: ^0.10.0                     # Required for scheduled notifications
```

### File Structure

```
lib/
├── core/
│   └── services/
│       └── notification_service.dart          # Platform notification handling
├── features/
│   └── notifications/
│       ├── data/
│       │   └── repositories/
│       │       └── notification_repository.dart   # Schedule/cancel logic
│       ├── domain/
│       │   └── entities/
│       │       └── notification_settings.dart     # Settings model
│       └── presentation/
│           └── providers/
│               └── notification_providers.dart    # Riverpod providers
```

### Data Flow

1. App launch -> `NotificationService.initialize()`
2. Check equipment with service dates -> Query `EquipmentItem.nextServiceDue`
3. Apply notification settings (global + per-item overrides)
4. Schedule notifications for each reminder period selected
5. Store scheduled notification IDs to enable cancellation on settings change

## Data Model

### Database Changes

**Extend `diverSettings` table:**

```sql
notificationsEnabled          BOOLEAN DEFAULT true
serviceReminderDays           TEXT    -- JSON array: "[7, 14, 30]"
reminderTime                  TEXT    -- "09:00" (local time to send reminders)
```

**Extend `equipment` table:**

```sql
customReminderEnabled         BOOLEAN DEFAULT NULL  -- NULL = use global
customReminderDays            TEXT    DEFAULT NULL  -- JSON array override
```

When `customReminderEnabled` is:
- `NULL`: Use global settings
- `true`: Use `customReminderDays`
- `false`: Notifications disabled for this item

**New `scheduled_notifications` table:**

```sql
CREATE TABLE scheduled_notifications (
  id                TEXT PRIMARY KEY,
  equipmentId       TEXT NOT NULL,
  scheduledDate     INTEGER NOT NULL,  -- Unix timestamp
  reminderDaysBefore INTEGER NOT NULL, -- 7, 14, or 30
  notificationId    INTEGER NOT NULL,  -- Platform notification ID
  createdAt         INTEGER NOT NULL
);
```

## Notification Scheduling

### Algorithm

```
1. Query all active equipment with nextServiceDue dates
2. For each equipment item:
   a. Determine reminder days (custom override or global default)
   b. For each reminder period (e.g., 30, 14, 7 days):
      - Calculate notification date = nextServiceDue - reminderDays
      - Skip if date is in the past
      - Skip if already scheduled (check scheduled_notifications table)
      - Schedule notification with payload: { equipmentId, reminderDays }
      - Record in scheduled_notifications table
3. Clean up: Cancel notifications for equipment no longer needing service
```

### Trigger Points

Notifications get rescheduled when:
- App launches (primary mechanism)
- Background refresh runs (backup)
- User changes notification settings
- Equipment service date changes
- New service record is logged (updates nextServiceDue)

### Background Refresh

Using `workmanager` package:

- **iOS**: Background App Refresh (runs periodically when system allows)
- **Android**: WorkManager with periodic work request (minimum 15 minute intervals)

Background task responsibilities:
1. Re-check equipment service dates (in case data synced from another device)
2. Schedule any missing notifications
3. Cancel notifications for already-serviced equipment

## User Interface

### Settings Page Addition

```
Notifications
├── Service Reminders              [Toggle: ON/OFF]
├── Reminder Schedule              [Multi-select: 7, 14, 30 days]
└── Reminder Time                  [Time picker: 9:00 AM]
```

### Equipment Edit Page Addition

```
Notifications (Optional)
├── Use Custom Reminders           [Toggle: OFF by default]
│   └── (when ON, shows:)
│       └── Reminder Schedule      [Multi-select: 7, 14, 30 days]
├── Disable Reminders              [Toggle: OFF]
```

### Notification Content

- **Title**: `Service Due: {Equipment Name}`
- **Body**: `{Brand} {Model} service is due in {X} days`
- **Overdue**: `{Brand} {Model} service is overdue`

### Android Notification Channel

- **Channel**: "Equipment Service Reminders"
- **Importance**: Default (shows in shade, makes sound)

## Platform Configuration

### iOS (Info.plist)

```xml
<key>UIBackgroundModes</key>
<array>
  <string>fetch</string>
  <string>processing</string>
</array>
```

### Android (AndroidManifest.xml)

```xml
<uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM" />
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED" />
```

### Permission Flow

```
User enables "Service Reminders" toggle
    |
Check notification permission status
    |
If not granted -> Show explanation dialog -> Request permission
    |
If granted -> Schedule notifications
If denied -> Show settings deep-link to enable manually
```

## Implementation Phases

### Phase 1: Foundation
1. Add package dependencies
2. Create `NotificationService` with platform initialization
3. Add database migrations for new columns and table
4. Create `NotificationSettings` entity and extend `AppSettings`

### Phase 2: Core Scheduling
5. Create `NotificationRepository` with schedule/cancel logic
6. Implement equipment query for items needing notifications
7. Build scheduling algorithm (respecting global + per-item settings)
8. Add notification payload handling for deep-linking

### Phase 3: Background Refresh
9. Configure `workmanager` for iOS and Android
10. Implement background task to refresh notification schedule
11. Handle boot-completed receiver (Android)

### Phase 4: User Interface
12. Add notification settings section to Settings page
13. Add custom reminder override UI to Equipment Edit page
14. Implement permission request flow with explanation dialogs

### Phase 5: Integration & Testing
15. Wire up triggers (app launch, settings change, equipment update)
16. Add unit tests for scheduling logic
17. Manual testing on iOS and Android devices

## Estimated Scope

- **New files**: ~10-12
- **Modified files**: ~5-6
- **Total**: ~15-18 files
