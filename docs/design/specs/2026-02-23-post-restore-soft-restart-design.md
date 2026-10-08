# Post-Restore Soft Restart

## Problem

After restoring a database backup, the app displays "Restore completed. Please restart
the app." and relies on the user to manually kill and relaunch the app. This is necessary
because dozens of Riverpod providers still hold cached data from the pre-restore database.
The current partial invalidation in the export flow (6 providers) is incomplete and fragile.

## Solution

Key-based ProviderScope rebuild with a "Restore Complete" interstitial page.

## Architecture

A `ValueNotifier<Key>` lives above the `ProviderScope` in the widget tree. Changing the
key causes Flutter to unmount the entire ProviderScope subtree and rebuild it, disposing
all providers and recreating them from the freshly-restored database.

```dart
ValueNotifier<Key> _restartKey
  -> ValueListenableBuilder
    -> ProviderScope(key: _restartKey.value)
      -> SubmersionApp (GoRouter, all providers)
```

## Components

### 1. Root restart mechanism (main.dart)

- Add a `ValueNotifier<Key>` at module level
- Wrap `ProviderScope` in `ValueListenableBuilder<Key>` keyed by the notifier
- Expose a static `restartApp()` function that sets a new `UniqueKey()`

### 2. Restore Complete page (new file)

`lib/features/backup/presentation/pages/restore_complete_page.dart`

Full-screen page shown after successful restore:

- Success icon
- "Restore Complete" heading
- Brief description
- "Continue" button that calls `restartApp()`

This page uses the root Flutter `Navigator` (not GoRouter) because GoRouter will be
destroyed during the ProviderScope rebuild. Shown via `Navigator.of(context).pushAndRemoveUntil()`.

### 3. Restore flow changes

All three restore call sites navigate to RestoreCompletePage on success instead of
setting a text message:

- `BackupOperationNotifier.restoreFromBackup()` in backup_providers.dart
- `BackupOperationNotifier.restoreFromFilePath()` in backup_providers.dart
- `ExportImportNotifier.restoreFromFile()` in export_providers.dart

## Data Flow

```dart
User confirms restore
  -> DB close, file copy, DB reinitialize
  -> _syncActiveDiverAfterRestore()
  -> Navigate to RestoreCompletePage (root Navigator)
  -> User taps "Continue"
  -> restartApp() changes ValueNotifier key
  -> ProviderScope rebuilds (new key)
  -> All providers disposed + recreated
  -> GoRouter reinitializes at /dashboard
  -> FutureProviders fetch fresh data from restored DB
```

## Navigation Consideration

The Restore Complete page must live outside GoRouter's route tree. When the
ProviderScope rebuilds, GoRouter is destroyed and recreated. If the success page were
a GoRouter route, it would be destroyed mid-display. Using the root Navigator ensures
the page remains stable until the user taps "Continue", at which point the entire
subtree (including this page) is replaced by the fresh ProviderScope.

## Files to Create/Modify

| File | Change |
|------|--------|
| `lib/main.dart` | ValueNotifier + wrap ProviderScope + restartApp() |
| `lib/features/backup/presentation/pages/restore_complete_page.dart` | New page |
| `lib/features/backup/presentation/providers/backup_providers.dart` | Navigate on success |
| `lib/features/settings/presentation/providers/export_providers.dart` | Navigate on success |

## Error Handling

- Restore failure: existing error handling unchanged (error state on backup page)
- Restore Complete page only appears after successful restore
- _syncActiveDiverAfterRestore() failure: already non-fatal (caught silently)
- ProviderScope rebuild failure: not expected (standard Flutter mechanism)
