# Database Reset Feature Design

## Summary

Add a "Reset Database" option to Settings > Data > Database Storage that deletes all data and recreates a fresh empty database. The feature auto-backs-up before wiping and uses the same soft-restart pattern as database restore.

## Requirements

- Full wipe: all tables dropped (dives, sites, gear, divers, species, etc.)
- Auto-backup before deletion
- Type-to-confirm safety gate (user must type "Delete")
- Post-reset: show completion page, then soft-restart the app (same as restore flow)

## Approach

**Delete + Recreate File**: Close the database, delete the `.db` file and WAL/SHM journal files, then reinitialize via `DatabaseService`. Drift auto-creates all tables on first connection.

Chosen over DROP-all-tables (fragile, must maintain table list) and empty-template-overwrite (requires asset maintenance).

## UI Design

### Placement

New "Danger Zone" section at the bottom of `StorageSettingsPage`, styled with red/error color scheme. Contains a single `ListTile`:

```text
DANGER ZONE
[warning icon] Reset Database
  Delete all data and start fresh
```

### Confirmation Dialog

1. Warning icon + bold title: "Reset Database?"
2. Body: "This will permanently delete all your data including dives, sites, gear, and settings. A backup will be created automatically before resetting."
3. Text field with hint: `Type "Delete" to confirm`
4. Cancel button (always enabled) + Reset button (disabled until "Delete" is typed, case-insensitive)
5. Reset button styled as destructive (red)

### Post-Reset Flow

1. Auto-backup via existing `BackupService`
2. Close DB via `DatabaseService.close()`
3. Delete `.db`, `.db-wal`, `.db-shm` files
4. Reinitialize via `DatabaseService.reinitializeAtPath()`
5. Navigate to `ResetCompletePage` (full-screen, root navigator, clears all routes)
6. User taps "Continue" -> `restartApp()` rebuilds all providers from empty DB

## Components

### New Files

- `lib/features/settings/presentation/widgets/reset_database_dialog.dart` - Type-to-confirm dialog
- `lib/features/settings/presentation/pages/reset_complete_page.dart` - Post-reset completion page (mirrors `RestoreCompletePage`)

### Modified Files

- `lib/core/services/database_service.dart` - Add `resetDatabase()` method
- `lib/features/settings/presentation/pages/storage_settings_page.dart` - Add Danger Zone section with reset button
- `lib/l10n/arb/app_en.arb` + generated l10n files - New localization strings

### Service Layer

`DatabaseService.resetDatabase()`:

1. Resolve current DB path
2. Call `backup()` to auto-save
3. Call `close()` to release connection
4. Delete `.db`, `.db-wal`, `.db-shm` files
5. Call `reinitializeAtPath()` to create fresh DB

### Error Handling

- Backup fails: show error dialog, abort reset (don't delete anything)
- File deletion fails: show error, attempt recovery by reinitializing from existing file
- Reinitialize fails after deletion: show critical error suggesting app restart

## Localization Keys

- `settings_storage_dangerZone` - Section header
- `settings_storage_resetDatabase` - Action title
- `settings_storage_resetDatabase_subtitle` - Action description
- `settings_storage_resetDialog_title` - Dialog title
- `settings_storage_resetDialog_body` - Dialog body text
- `settings_storage_resetDialog_confirmHint` - Text field hint
- `settings_storage_resetDialog_confirmButton` - Destructive button label
- `settings_storage_resetComplete_title` - Completion page title
- `settings_storage_resetComplete_description` - Completion page body
