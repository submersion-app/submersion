# Post-Restore Soft Restart Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** After restoring a database backup, automatically refresh all app state instead of requiring a manual app restart.

**Architecture:** A `ValueNotifier<Key>` above the `ProviderScope` in the widget tree enables a "soft restart" — changing the key destroys and recreates the entire ProviderScope, forcing all Riverpod providers to re-fetch from the restored database. A "Restore Complete" interstitial page gives the user a clear signal before the rebuild occurs.

**Tech Stack:** Flutter, Riverpod (ProviderScope key rebuild), root Navigator (bypassing GoRouter)

---

### Task 1: Add restart mechanism to main.dart

**Files:**

- Modify: `lib/main.dart:1-108`

**Step 1: Add the restart infrastructure**

Add a module-level `ValueNotifier<Key>` and a public `restartApp()` function. Wrap the existing `ProviderScope` in a `ValueListenableBuilder` keyed by the notifier.

Replace lines 102-107 of `lib/main.dart`:

```dart
// Before (current):
runApp(
  ProviderScope(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    child: const SubmersionApp(),
  ),
);

// After:
runApp(SubmersionRestart(prefs: prefs));
```typescript
Add the `SubmersionRestart` widget and `restartApp` function at the bottom of `main.dart`:

```dart
/// Global key notifier. Changing the value forces ProviderScope to rebuild,
/// disposing all providers and re-fetching from the current database.
final _restartKey = ValueNotifier<Key>(UniqueKey());

/// Trigger a soft restart by rebuilding the entire ProviderScope.
/// Call this after a database restore to refresh all cached data.
void restartApp() {
  _restartKey.value = UniqueKey();
}

class SubmersionRestart extends StatelessWidget {
  final SharedPreferences prefs;

  const SubmersionRestart({super.key, required this.prefs});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Key>(
      valueListenable: _restartKey,
      builder: (context, key, _) {
        return ProviderScope(
          key: key,
          overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
          child: const SubmersionApp(),
        );
      },
    );
  }
}
```text
**Step 2: Verify it compiles**

Run: `flutter analyze lib/main.dart`
Expected: No issues found

**Step 3: Commit**

```

feat: add soft restart mechanism to main.dart

```diff
---

### Task 2: Add localization strings for restore complete page

**Files:**

- Modify: `lib/l10n/arb/app_en.arb`
- Modify: all other locale `app_*.arb` files (ar, de, es, fr, he, hu, it, nl, pt)

**Step 1: Add English strings to app_en.arb**

Add these entries (alphabetically near other `backup_restore_` keys):

```json
"backup_restoreComplete_title": "Restore Complete",
"backup_restoreComplete_description": "Your data has been restored successfully. Tap continue to reload the app with your restored data.",
"backup_restoreComplete_continue": "Continue",
```text
**Step 2: Add translated strings to all other locale files**

Add the same three keys with appropriate translations to each `app_*.arb` file.

**Step 3: Run code generation**

Run: `flutter gen-l10n`
Expected: Completes without errors (existing untranslated message warnings are fine)

**Step 4: Commit**

```

feat: add restore complete page localization strings

```dart
---

### Task 3: Create RestoreCompletePage

**Files:**

- Create: `lib/features/backup/presentation/pages/restore_complete_page.dart`

**Step 1: Create the page**

This is a plain `StatelessWidget` (no Riverpod needed — it's shown via root Navigator, outside the ProviderScope being rebuilt). It imports `restartApp` from main.dart.

```dart
import 'package:flutter/material.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/main.dart' show restartApp;

class RestoreCompletePage extends StatelessWidget {
  const RestoreCompletePage({super.key});

  /// Navigate to this page using the root Navigator (not GoRouter).
  /// This ensures the page survives the ProviderScope rebuild.
  static void show(BuildContext context) {
    Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const RestoreCompletePage()),
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
                    context.l10n.backup_restoreComplete_title,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    context.l10n.backup_restoreComplete_description,
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
**Step 2: Verify it compiles**

Run: `flutter analyze lib/features/backup/presentation/pages/restore_complete_page.dart`
Expected: No issues found

**Step 3: Commit**

```

feat: add RestoreCompletePage for post-restore soft restart

```dart
---

### Task 4: Wire up BackupOperationNotifier restore flows

**Files:**

- Modify: `lib/features/backup/presentation/pages/backup_settings_page.dart:220-228,340-348`
- Modify: `lib/features/backup/presentation/providers/backup_providers.dart:182-205,282-320`

The navigation must happen from the **UI layer** (which has `BuildContext`), not from the provider (which doesn't). The provider already sets `BackupOperationStatus.success` after a successful restore. The UI needs to **react** to that status by navigating to `RestoreCompletePage`.

**Step 1: Add a `restoreComplete` status to distinguish restore-success from other successes**

In `lib/features/backup/presentation/providers/backup_providers.dart`, add a new enum value:

```dart
// Line 84: Change from:
enum BackupOperationStatus { idle, inProgress, success, error }

// To:
enum BackupOperationStatus { idle, inProgress, success, restoreComplete, error }
```text
**Step 2: Use `restoreComplete` status in both restore methods**

In `restoreFromBackup()` (line 194), change:

```dart
// From:
state = const BackupOperationState(
  status: BackupOperationStatus.success,
  message: 'Restore completed. Please restart the app.',
);

// To:
state = const BackupOperationState(
  status: BackupOperationStatus.restoreComplete,
);
```text
In `restoreFromFilePath()` (line 309), make the same change:

```dart
// From:
state = const BackupOperationState(
  status: BackupOperationStatus.success,
  message: 'Restore completed. Please restart the app.',
);

// To:
state = const BackupOperationState(
  status: BackupOperationStatus.restoreComplete,
);
```dart
**Step 3: React to `restoreComplete` in the backup settings page**

In `lib/features/backup/presentation/pages/backup_settings_page.dart`, add a `ref.listen` call in the `build` method to navigate when the status changes to `restoreComplete`. Add this after the existing `ref.watch(backupOperationProvider)` on line 23:

```dart
ref.listen<BackupOperationState>(backupOperationProvider, (previous, next) {
  if (next.status == BackupOperationStatus.restoreComplete) {
    RestoreCompletePage.show(context);
  }
});
```typescript
Add the import at the top of the file:

```dart
import 'package:submersion/features/backup/presentation/pages/restore_complete_page.dart';
```text
**Step 4: Update `_buildStatusMessage` to handle restoreComplete**

In the switch statement in `_buildStatusMessage` (line 75-81), `restoreComplete` should use the green color like `success`:

```dart
case BackupOperationStatus.success:
case BackupOperationStatus.restoreComplete:
  color = Colors.green;
```text
**Step 5: Format and analyze**

Run: `dart format lib/features/backup/presentation/providers/backup_providers.dart lib/features/backup/presentation/pages/backup_settings_page.dart`
Run: `flutter analyze lib/features/backup/`
Expected: No issues found

**Step 6: Commit**

```

feat: navigate to RestoreCompletePage after backup restore

```text
---

### Task 5: Wire up ExportNotifier restore flow

**Files:**

- Modify: `lib/features/settings/presentation/providers/export_providers.dart:1301-1363`

The `ExportNotifier.restoreBackup()` method is currently not called from any UI (dead code), but it should still be updated for correctness and future use.

**Step 1: Add active diver sync and restoreComplete status**

Replace lines 1342-1356 in `export_providers.dart`:

```dart
// Before:
state = state.copyWith(message: 'Restoring from backup...');
await DatabaseService.instance.restore(filePath);

// Invalidate all providers to refresh data
_ref.invalidate(diveListNotifierProvider);
_ref.invalidate(paginatedDiveListProvider);
_ref.invalidate(sitesProvider);
_ref.invalidate(sitesWithCountsProvider);
_ref.invalidate(siteListNotifierProvider);
_ref.invalidate(allEquipmentProvider);

state = state.copyWith(
  status: ExportStatus.success,
  message: 'Backup restored successfully. Please restart the app.',
);

// After:
state = state.copyWith(message: 'Restoring from backup...');
await DatabaseService.instance.restore(filePath);

state = state.copyWith(
  status: ExportStatus.restoreComplete,
  message: 'Restore complete',
);
```text
**Step 2: Add `restoreComplete` to ExportStatus enum**

Find the `ExportStatus` enum (should be near the top of export_providers.dart) and add `restoreComplete`:

```dart
enum ExportStatus { idle, exporting, success, restoreComplete, error }
```dart
**Step 3: Remove the now-unnecessary individual provider invalidations**

The 6 `_ref.invalidate()` calls (lines 1346-1351) are no longer needed since the entire ProviderScope will be rebuilt. They were removed in Step 1 above.

**Step 4: Handle `restoreComplete` in any UI that watches ExportNotifier**

Check `lib/features/transfer/presentation/pages/transfer_page.dart` for status handling. Add a `ref.listen` for `restoreComplete` if the `ExportNotifier` restore is triggered from there. If `restoreBackup()` is never called from that page, no UI change is needed — but the enum value should still be handled in any switch statements to avoid analyzer warnings.

**Step 5: Format and analyze**

Run: `dart format lib/features/settings/presentation/providers/export_providers.dart`
Run: `flutter analyze lib/features/settings/presentation/providers/export_providers.dart`
Expected: No issues found

**Step 6: Commit**

```

feat: update ExportNotifier restore flow for soft restart

```text
---

### Task 6: Run full test suite and verify

**Files:**

- No new files; verification only

**Step 1: Format all modified files**

Run: `dart format lib/main.dart lib/features/backup/ lib/features/settings/presentation/providers/export_providers.dart`

**Step 2: Analyze**

Run: `flutter analyze`
Expected: No issues found

**Step 3: Run tests**

Run: `flutter test`
Expected: All tests pass (1379+)

If any tests reference `BackupOperationStatus` or `ExportStatus` enums in switch statements, update them to handle the new `restoreComplete` value.

**Step 4: Commit**

```text

test: verify all tests pass with soft restart changes

```

---

## Summary of Changes

| File | Type | Description |
|------|------|-------------|
| `lib/main.dart` | Modify | Add `restartApp()`, `SubmersionRestart` widget, `ValueNotifier<Key>` |
| `lib/l10n/arb/app_en.arb` | Modify | Add 3 restore complete strings |
| `lib/l10n/arb/app_*.arb` (9 files) | Modify | Add translated restore complete strings |
| `lib/features/backup/presentation/pages/restore_complete_page.dart` | Create | Success page with "Continue" button |
| `lib/features/backup/presentation/providers/backup_providers.dart` | Modify | Add `restoreComplete` enum, use in restore methods |
| `lib/features/backup/presentation/pages/backup_settings_page.dart` | Modify | Add `ref.listen` to navigate on `restoreComplete` |
| `lib/features/settings/presentation/providers/export_providers.dart` | Modify | Add `restoreComplete` enum, remove stale invalidations |
