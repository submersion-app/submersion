# File-Based Backup & Restore

## Problem

The backup page (Settings > Data > Backup) only backs up to and restores from a
pre-determined internal location. There is no way to export a backup to an
arbitrary file, import from an arbitrary file, or choose where automatic backups
are stored.

## Goals

1. Export a backup to any user-chosen location (file picker or share sheet)
2. Restore from any `.sqlite` file on disk
3. Allow configuring the auto-backup storage location
4. Prune backup history based on actual file existence
5. Redesign the backup page to center on file-based actions

## Non-Goals

- Changing the backup file format (remains raw SQLite copy)
- Adding incremental/differential backups
- Cross-app sharing or UDDF export (separate feature)

## Design

### Page Layout (Action-First Card Layout)

The redesigned `BackupSettingsPage` has four sections, top to bottom:

**Section 1 -- Export Backup (Card)**

- Icon: `Icons.backup`
- Title: "Export Backup"
- Subtitle: "Save your dive data to a file"
- Tap opens a bottom sheet with two options:
  - "Save to File" -- `FilePicker.platform.saveFile()` with default filename
    `submersion_backup_YYYY-MM-dd.sqlite`
  - "Share" -- creates temp backup, opens `Share.shareXFiles()` from
    `share_plus`. Hidden on Windows/Linux (no share sheet).
- Success snackbar: "Backup saved to [path]"

**Section 2 -- Restore from File (Card)**

- Icon: `Icons.restore`
- Title: "Restore from File"
- Subtitle: "Import a backup from any location"
- Tap opens `FilePicker.platform.pickFiles()` filtered to `.sqlite`
- After selection, shows `RestoreConfirmationDialog` with file details
- Creates a safety backup before restoring (existing behavior)

**Section 3 -- Backup History (List)**

- Shows all known backup records
- On load, validates each record's `localPath` exists; removes stale entries
  where the file is gone and there is no cloud backup
- Each tile: timestamp, dive/site counts, file size, location icon
- Popup menu: "Restore", "Delete"

**Section 4 -- Automatic Backups (Collapsible)**

- `ExpansionTile` with on/off toggle in header
- When expanded:
  - Backup location: shows current path, tap to change via folder picker
  - Frequency dropdown (daily/weekly/monthly)
  - Retention count dropdown
  - Cloud sync toggle (if cloud provider available)

### Service Layer Changes

**`BackupService` -- new methods:**

- `exportBackupToPath(String destinationPath)` -- backup to user-specified
  path. Records in history with actual destination path.
- `exportBackupToTemp()` -- backup to temp dir, returns `File` for sharing.
  NOT recorded in history (ephemeral).
- `restoreFromFile(String filePath)` -- restore from arbitrary `.sqlite` file.
  Validates file first. Creates safety backup. Does not require `BackupRecord`.
- `validateBackupFile(String filePath)` -- checks file exists, is SQLite, and
  contains expected Submersion tables (`dives`, `dive_sites`).

**`BackupService` -- modified methods:**

- `performBackup()` -- uses configurable backup location from settings instead
  of hardcoded `_localBackupFolder`. Falls back to default if unset.
- `getBackupHistory()` -- validates file existence for each record. Removes
  stale entries where file no longer exists at `localPath` and has no cloud
  backup.

**`BackupSettings` additions:**

- New field: `String? backupLocation` -- user-chosen directory for auto-backups.
  `null` means default `Submersion/Backups` folder.

**`BackupPreferences` additions:**

- `getBackupLocation()` / `setBackupLocation(String?)` -- persist custom path.

### Provider Changes

**`BackupOperationNotifier` -- new methods:**

- `exportToFile()` -- opens save dialog, exports backup
- `exportAndShare()` -- creates temp backup, opens share sheet
- `restoreFromFile()` -- opens file picker, validates, restores

**`BackupSettingsNotifier` -- new method:**

- `setBackupLocation(String? path)` -- set custom auto-backup directory

**`backupHistoryProvider`** -- updated to call service's `getBackupHistory()`
which now prunes stale entries lazily on view.

### File Validation (Import)

Before restoring from an arbitrary file:

1. Check file exists and is readable
2. Check file extension is `.sqlite` (or `.db`)
3. Open as SQLite, run `SELECT 1` to verify valid database
4. Check for expected tables (`dives`, `dive_sites`) to confirm it is a
   Submersion backup
5. On failure: show "This file doesn't appear to be a valid Submersion backup"

### Platform Behavior

| Platform      | Save to File | Share     | Folder Picker |
|---------------|-------------|-----------|---------------|
| iOS           | Yes         | Yes       | Yes           |
| macOS         | Yes         | Yes       | Yes           |
| Android       | Yes (SAF)   | Yes       | Yes (SAF)     |
| Windows       | Yes         | Hidden    | Yes           |
| Linux         | Yes         | Hidden    | Yes           |

### Error Handling

- File picker cancelled: no-op, no error
- File not valid database: error dialog with clear message
- Restore failed (I/O): error message, safety backup intact
- Export to read-only location: error "Could not save to selected location"

### Localization

New l10n strings needed:

- Export card: title, subtitle, save/share options
- Import card: title, subtitle
- Backup location setting label and "Change" action
- Validation error messages
- Snackbar confirmations
- Bottom sheet title

### Dependencies

No new packages. Uses existing:

- `file_picker` (^10.3.9) -- file/folder selection
- `share_plus` (^12.0.1) -- share sheet
- `path_provider` -- temp/app directories

### Files to Modify

| File | Change |
|------|--------|
| `lib/features/backup/data/services/backup_service.dart` | Add export/import/validate methods, configurable location, history pruning |
| `lib/features/backup/presentation/pages/backup_settings_page.dart` | Full redesign with 4-section layout |
| `lib/features/backup/presentation/providers/backup_providers.dart` | Add new operations to notifiers |
| `lib/features/backup/domain/entities/backup_settings.dart` | Add `backupLocation` field |
| `lib/features/backup/data/repositories/backup_preferences.dart` | Add backup location persistence |
| `lib/l10n/arb/app_en.arb` + other locale files | New l10n strings |
| `test/features/backup/data/services/backup_service_test.dart` | Tests for new methods |

### New Files

| File | Purpose |
|------|---------|
| `lib/features/backup/presentation/widgets/export_bottom_sheet.dart` | Bottom sheet with Save/Share options |
