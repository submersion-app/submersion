# Database Reset Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add a "Reset Database" option to Settings > Data > Database Storage that wipes all data and recreates a fresh empty database, with auto-backup and type-to-confirm safety.

**Architecture:** The reset operation lives in `DatabaseService.resetDatabase()` which auto-backs-up, closes the DB, deletes the file + journals, then reinitializes. The UI adds a Danger Zone section to `StorageSettingsPage` with a type-to-confirm dialog. Post-reset follows the same `RestoreCompletePage` pattern: full-screen completion page then `restartApp()`.

**Tech Stack:** Flutter, Drift ORM, Riverpod, dart:io for file deletion

---

### Task 1: Add Localization Strings

**Files:**

- Modify: `lib/l10n/arb/app_en.arb`
- Modify: `lib/l10n/arb/app_localizations.dart`
- Modify: `lib/l10n/arb/app_localizations_en.dart`

**Step 1: Add new keys to the English ARB source file**

Add these entries to `lib/l10n/arb/app_en.arb` in the `settings_storage_` section (after the existing `settings_storage_success_moved` entry around line 5326):

```json
  "settings_storage_dangerZone": "Danger Zone",
  "settings_storage_resetDatabase": "Reset Database",
  "settings_storage_resetDatabase_subtitle": "Delete all data and start fresh",
  "settings_storage_resetDialog_title": "Reset Database?",
  "settings_storage_resetDialog_body": "This will permanently delete all your data including dives, sites, gear, and settings. A backup will be created automatically before resetting.",
  "settings_storage_resetDialog_confirmHint": "Type \"Delete\" to confirm",
  "settings_storage_resetDialog_confirmButton": "Reset",
  "settings_storage_resetDialog_backupFailed": "Backup failed. Reset aborted to protect your data.",
  "settings_storage_resetDialog_resetFailed": "Reset failed: {error}",
  "settings_storage_resetComplete_title": "Database Reset",
  "settings_storage_resetComplete_description": "Your data has been cleared and a backup was saved. Tap continue to reload the app.",
```text
**Step 2: Add the corresponding abstract getters to `app_localizations.dart`**

Add the abstract getters in the appropriate alphabetical location within the `settings_storage_` section. Follow the existing pattern with `/// **'...'**` doc comments:

```dart
  /// In en, this message translates to:
  /// **'Danger Zone'**
  String get settings_storage_dangerZone;

  /// In en, this message translates to:
  /// **'Reset Database'**
  String get settings_storage_resetDatabase;

  /// In en, this message translates to:
  /// **'Delete all data and start fresh'**
  String get settings_storage_resetDatabase_subtitle;

  /// In en, this message translates to:
  /// **'Reset Database?'**
  String get settings_storage_resetDialog_title;

  /// In en, this message translates to:
  /// **'This will permanently delete all your data including dives, sites, gear, and settings. A backup will be created automatically before resetting.'**
  String get settings_storage_resetDialog_body;

  /// In en, this message translates to:
  /// **'Type "Delete" to confirm'**
  String get settings_storage_resetDialog_confirmHint;

  /// In en, this message translates to:
  /// **'Reset'**
  String get settings_storage_resetDialog_confirmButton;

  /// In en, this message translates to:
  /// **'Backup failed. Reset aborted to protect your data.'**
  String get settings_storage_resetDialog_backupFailed;

  String settings_storage_resetDialog_resetFailed(Object error);

  /// In en, this message translates to:
  /// **'Database Reset'**
  String get settings_storage_resetComplete_title;

  /// In en, this message translates to:
  /// **'Your data has been cleared and a backup was saved. Tap continue to reload the app.'**
  String get settings_storage_resetComplete_description;
```text
**Step 3: Add the English implementations to `app_localizations_en.dart`**

Add `@override` getters in the `settings_storage_` section:

```dart
  @override
  String get settings_storage_dangerZone => 'Danger Zone';

  @override
  String get settings_storage_resetDatabase => 'Reset Database';

  @override
  String get settings_storage_resetDatabase_subtitle => 'Delete all data and start fresh';

  @override
  String get settings_storage_resetDialog_title => 'Reset Database?';

  @override
  String get settings_storage_resetDialog_body => 'This will permanently delete all your data including dives, sites, gear, and settings. A backup will be created automatically before resetting.';

  @override
  String get settings_storage_resetDialog_confirmHint => 'Type "Delete" to confirm';

  @override
  String get settings_storage_resetDialog_confirmButton => 'Reset';

  @override
  String get settings_storage_resetDialog_backupFailed => 'Backup failed. Reset aborted to protect your data.';

  @override
  String settings_storage_resetDialog_resetFailed(Object error) {
    return 'Reset failed: $error';
  }

  @override
  String get settings_storage_resetComplete_title => 'Database Reset';

  @override
  String get settings_storage_resetComplete_description => 'Your data has been cleared and a backup was saved. Tap continue to reload the app.';
```text
**Step 4: Verify**

Run: `flutter analyze lib/l10n/`
Expected: No issues found

**Step 5: Commit**

```bash
git add lib/l10n/
git commit -m "feat: add localization strings for database reset feature"
```text
---

### Task 2: Add `resetDatabase()` to DatabaseService

**Files:**

- Modify: `lib/core/services/database_service.dart` (add method after `restore()`, around line 192)

**Step 1: Add the `resetDatabase()` method**

Add this method to `DatabaseService` after the existing `restore()` method:

```dart
  /// Delete all data and recreate a fresh empty database.
  ///
  /// 1. Backs up the current database to [backupPath]
  /// 2. Closes the database connection
  /// 3. Deletes the .db, .db-wal, and .db-shm files
  /// 4. Reinitializes a fresh database at the same path
  ///
  /// Throws if the backup step fails (reset is aborted to protect data).
  /// If file deletion or reinitialize fails after backup succeeds,
  /// the error propagates and the caller should handle recovery.
  Future<void> resetDatabase({required String backupPath}) async {
    final dbPath = await databasePath;

    // Step 1: Backup first (throws on failure, aborting the reset)
    await backup(backupPath);

    // Step 2: Close the connection
    await close();

    // Step 3: Delete database files
    for (final suffix in ['', '-wal', '-shm']) {
      final file = File('$dbPath$suffix');
      if (await file.exists()) {
        await file.delete();
      }
    }

    // Step 4: Reinitialize fresh database (Drift auto-creates tables)
    await reinitializeAtPath(dbPath);
  }
```text
**Step 2: Verify**

Run: `flutter analyze lib/core/services/database_service.dart`
Expected: No issues found

**Step 3: Commit**

```bash
git add lib/core/services/database_service.dart
git commit -m "feat: add resetDatabase() method to DatabaseService"
```text
---

### Task 3: Create the Type-to-Confirm Reset Dialog

**Files:**

- Create: `lib/features/settings/presentation/widgets/reset_database_dialog.dart`

**Step 1: Create the dialog widget**

```dart
import 'package:flutter/material.dart';

import 'package:submersion/l10n/l10n_extension.dart';

/// Confirmation dialog for database reset with type-to-confirm safety gate.
///
/// The user must type "Delete" (case-insensitive) before the destructive
/// Reset button becomes enabled. Mirrors the pattern from
/// [RestoreConfirmationDialog] but adds the text confirmation step.
class ResetDatabaseDialog extends StatefulWidget {
  const ResetDatabaseDialog({super.key});

  /// Shows the dialog and returns true if the user confirms the reset.
  static Future<bool> show(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => const ResetDatabaseDialog(),
    );
    return result ?? false;
  }

  @override
  State<ResetDatabaseDialog> createState() => _ResetDatabaseDialogState();
}

class _ResetDatabaseDialogState extends State<ResetDatabaseDialog> {
  final _controller = TextEditingController();
  bool _isConfirmed = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final confirmed = _controller.text.trim().toLowerCase() == 'delete';
    if (confirmed != _isConfirmed) {
      setState(() => _isConfirmed = confirmed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: theme.colorScheme.error),
          const SizedBox(width: 8),
          Expanded(
            child: Text(context.l10n.settings_storage_resetDialog_title),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.settings_storage_resetDialog_body,
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            decoration: InputDecoration(
              hintText: context.l10n.settings_storage_resetDialog_confirmHint,
              border: const OutlineInputBorder(),
            ),
            autofocus: true,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(context.l10n.common_action_cancel),
        ),
        FilledButton(
          onPressed: _isConfirmed
              ? () => Navigator.of(context).pop(true)
              : null,
          style: FilledButton.styleFrom(
            backgroundColor: theme.colorScheme.error,
          ),
          child: Text(
            context.l10n.settings_storage_resetDialog_confirmButton,
          ),
        ),
      ],
    );
  }
}
```text
**Step 2: Verify**

Run: `dart format lib/features/settings/presentation/widgets/reset_database_dialog.dart && flutter analyze lib/features/settings/presentation/widgets/reset_database_dialog.dart`
Expected: No issues found

**Step 3: Commit**

```bash
git add lib/features/settings/presentation/widgets/reset_database_dialog.dart
git commit -m "feat: add type-to-confirm reset database dialog"
```text
---

### Task 4: Create the Reset Complete Page

**Files:**

- Create: `lib/features/settings/presentation/pages/reset_complete_page.dart`

**Step 1: Create the completion page**

Model after `lib/features/backup/presentation/pages/restore_complete_page.dart`:

```dart
import 'package:flutter/material.dart';

import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/main.dart' show restartApp;

/// Full-screen completion page shown after a database reset.
///
/// Uses the root Navigator (not GoRouter) and clears all routes so it
/// survives the ProviderScope rebuild triggered by [restartApp].
/// Mirrors the pattern from [RestoreCompletePage].
class ResetCompletePage extends StatelessWidget {
  const ResetCompletePage({super.key});

  /// Navigate to this page using the root Navigator (not GoRouter).
  /// This ensures the page survives the ProviderScope rebuild.
  static void show(BuildContext context) {
    Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const ResetCompletePage()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    size: 80,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    context.l10n.settings_storage_resetComplete_title,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    context.l10n.settings_storage_resetComplete_description,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 48),
                  FilledButton.icon(
                    onPressed: () => restartApp(),
                    icon: const Icon(Icons.refresh),
                    label: Text(
                      context.l10n.backup_restoreComplete_continue,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
```text
**Step 2: Verify**

Run: `dart format lib/features/settings/presentation/pages/reset_complete_page.dart && flutter analyze lib/features/settings/presentation/pages/reset_complete_page.dart`
Expected: No issues found

**Step 3: Commit**

```bash
git add lib/features/settings/presentation/pages/reset_complete_page.dart
git commit -m "feat: add reset complete page (mirrors restore complete)"
```text
---

### Task 5: Add Danger Zone Section to StorageSettingsPage

**Files:**

- Modify: `lib/features/settings/presentation/pages/storage_settings_page.dart`

**Step 1: Add imports**

Add these imports at the top of the file:

```dart
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/settings/presentation/pages/reset_complete_page.dart';
import 'package:submersion/features/settings/presentation/widgets/reset_database_dialog.dart';
```dart
**Step 2: Add Danger Zone section to the ListView**

In the `build()` method, add before `const SizedBox(height: 32)` (around line 139, just before the final spacing):

```dart
                const Divider(),
                _buildSectionHeader(
                  context,
                  context.l10n.settings_storage_dangerZone,
                ),
                _buildResetDatabaseTile(context, theme),
```text
**Step 3: Style the Danger Zone section header**

The existing `_buildSectionHeader` uses `colorScheme.primary`. For Danger Zone, we need a red-styled variant. Add a new method:

```dart
  Widget _buildDangerZoneSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: Theme.of(context).colorScheme.error,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
```text
Then update the Danger Zone section to use it instead of `_buildSectionHeader`:

```dart
                _buildDangerZoneSectionHeader(
                  context,
                  context.l10n.settings_storage_dangerZone,
                ),
```text
**Step 4: Add the reset tile and handler**

Add these methods to `_StorageSettingsPageState`:

```dart
  Widget _buildResetDatabaseTile(BuildContext context, ThemeData theme) {
    return ListTile(
      leading: Icon(Icons.warning_amber_rounded, color: theme.colorScheme.error),
      title: Text(
        context.l10n.settings_storage_resetDatabase,
        style: TextStyle(color: theme.colorScheme.error),
      ),
      subtitle: Text(context.l10n.settings_storage_resetDatabase_subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => _handleResetDatabase(context),
    );
  }

  Future<void> _handleResetDatabase(BuildContext context) async {
    final confirmed = await ResetDatabaseDialog.show(context);
    if (!confirmed || !mounted) return;

    // Generate backup path
    final docsDir = await getApplicationDocumentsDirectory();
    final backupDir = p.join(docsDir.path, 'Submersion', 'Backups');
    await Directory(backupDir).create(recursive: true);
    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
    final backupPath = p.join(backupDir, 'pre_reset_$timestamp.db');

    try {
      await DatabaseService.instance.resetDatabase(backupPath: backupPath);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.l10n.settings_storage_resetDialog_resetFailed(e),
          ),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }

    if (!mounted) return;
    ResetCompletePage.show(context);
  }
```text
**Step 5: Format and verify**

Run: `dart format lib/features/settings/presentation/pages/storage_settings_page.dart && flutter analyze lib/features/settings/presentation/pages/storage_settings_page.dart`
Expected: No issues found

**Step 6: Commit**

```bash
git add lib/features/settings/presentation/pages/storage_settings_page.dart
git commit -m "feat: add Danger Zone reset database option to storage settings"
```typescript
---

### Task 6: Manual Testing

**Step 1: Run the app**

Run: `flutter run -d macos`

**Step 2: Navigate to Settings > Data > Database Storage**

Verify:

- Danger Zone section appears at the bottom with red header text
- "Reset Database" tile has warning icon, red title, subtitle, chevron

**Step 3: Test the confirmation dialog**

- Tap "Reset Database"
- Verify dialog shows: warning icon, title, body text, text field, Cancel + Reset buttons
- Verify Reset button is disabled initially
- Type "delete" (lowercase) -> Reset button becomes enabled
- Type "Delete" (mixed case) -> Reset button stays enabled
- Clear field -> Reset button disables
- Tap Cancel -> dialog closes, nothing happens

**Step 4: Test the full reset flow**

- Ensure you have some dives/sites in the database
- Tap "Reset Database" -> type "Delete" -> tap Reset
- Verify: ResetCompletePage appears with "Database Reset" title
- Tap Continue -> app restarts with empty database
- Verify: dive list is empty, sites are empty, gear is empty
- Verify: a backup file was created in the Submersion/Backups directory

**Step 5: Verify backup can be restored**

- Go to Settings > Backup & Restore
- Import the pre-reset backup file
- Verify data is restored

**Step 6: Run full test suite**

Run: `flutter test`
Expected: All existing tests pass

**Step 7: Format check**

Run: `dart format lib/`
Expected: No changes needed

**Step 8: Commit any fixes from testing**

```bash
git add -A
git commit -m "fix: address issues found during database reset testing"
```
