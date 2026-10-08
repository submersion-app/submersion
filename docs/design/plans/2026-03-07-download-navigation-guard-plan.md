# Download Navigation Guard Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Prevent users from accidentally navigating away during an active dive computer download by showing a confirmation dialog.

**Architecture:** Page-level guards using Flutter's `PopScope` for back/swipe, dialog interception on AppBar close buttons, and a download-state check in `MainScaffold` for bottom nav tab switches. All share a single reusable confirmation dialog function.

**Tech Stack:** Flutter `PopScope`, Riverpod (`downloadNotifierProvider`, `isDownloadingProvider`), `showDialog`, `ConsumerStatefulWidget`

---

### Task 1: Create Shared Confirmation Dialog

**Files:**
- Create: `lib/features/dive_computer/presentation/widgets/download_exit_dialog.dart`

**Step 1: Create the dialog utility file**

```dart
import 'package:flutter/material.dart';

/// Shows a confirmation dialog when the user tries to navigate away
/// during an active dive computer download.
///
/// Returns `true` if the user confirmed they want to leave (and cancel
/// the download), `false` if they chose to stay or dismissed the dialog.
Future<bool> showDownloadExitConfirmation(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Download in Progress'),
      content: const Text(
        'Leaving will cancel the current download from your dive computer. '
        'Are you sure?',
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Stay'),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('Leave'),
        ),
      ],
    ),
  );
  return result ?? false;
}
```

**Step 2: Verify no analysis errors**

Run: `dart analyze lib/features/dive_computer/presentation/widgets/download_exit_dialog.dart`
Expected: No issues found

**Step 3: Commit**

```bash
git add lib/features/dive_computer/presentation/widgets/download_exit_dialog.dart
git commit -m "feat: add shared download exit confirmation dialog"
```

---

### Task 2: Guard DeviceDownloadPage

**Files:**
- Modify: `lib/features/dive_computer/presentation/pages/device_download_page.dart`

**Step 1: Add the import for the dialog**

Add after the existing imports (line 16):

```dart
import 'package:submersion/features/dive_computer/presentation/widgets/download_exit_dialog.dart';
```

**Step 2: Add a helper method for handling exit with confirmation**

Add this method to `_DeviceDownloadPageState` (after `_startDownload()`, around line 187):

```dart
Future<void> _handleCloseWithConfirmation() async {
  final downloadState = ref.read(downloadNotifierProvider);
  if (downloadState.isDownloading) {
    final shouldLeave = await showDownloadExitConfirmation(context);
    if (!shouldLeave || !mounted) return;
    await ref.read(downloadNotifierProvider.notifier).cancelDownload();
  }
  if (mounted) context.pop();
}
```

**Step 3: Wrap the Scaffold in PopScope**

In the `build()` method (line 211), wrap the `Scaffold` return in a `PopScope`:

Replace:
```dart
    return Scaffold(
```

With:
```dart
    return PopScope(
      canPop: !downloadState.isDownloading,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _handleCloseWithConfirmation();
        }
      },
      child: Scaffold(
```

And add the matching closing parenthesis `)` after the `Scaffold`'s closing `)` on line 268 (before the semicolon).

**Step 4: Update AppBar close button to use the confirmation helper**

Replace the AppBar `leading` (lines 214-223):

```dart
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            if (downloadState.isDownloading) {
              ref.read(downloadNotifierProvider.notifier).cancelDownload();
            }
            context.pop();
          },
          tooltip: context.l10n.diveComputer_download_closeTooltip,
        ),
```

With:

```dart
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: _handleCloseWithConfirmation,
          tooltip: context.l10n.diveComputer_download_closeTooltip,
        ),
```

**Step 5: Verify no analysis errors**

Run: `dart analyze lib/features/dive_computer/presentation/pages/device_download_page.dart`
Expected: No issues found

**Step 6: Commit**

```bash
git add lib/features/dive_computer/presentation/pages/device_download_page.dart
git commit -m "feat: add navigation guard to DeviceDownloadPage"
```

---

### Task 3: Guard DeviceDiscoveryPage

**Files:**
- Modify: `lib/features/dive_computer/presentation/pages/device_discovery_page.dart`

**Step 1: Add imports**

Add after existing imports (line 13):

```dart
import 'package:submersion/features/dive_computer/presentation/providers/download_providers.dart';
import 'package:submersion/features/dive_computer/presentation/widgets/download_exit_dialog.dart';
```

**Step 2: Update PopScope canPop condition**

The existing `PopScope` is at line 63. Change:

```dart
      canPop: discoveryState.currentStep == DiscoveryStep.scan,
```

To:

```dart
      canPop: discoveryState.currentStep == DiscoveryStep.scan &&
          !ref.watch(downloadNotifierProvider).isDownloading,
```

This blocks the back button/swipe during the download step when download is active.

**Step 3: Update _showExitConfirmation to handle active download**

Replace the `_showExitConfirmation` method (lines 547-577) with:

```dart
  Future<void> _showExitConfirmation(BuildContext context) async {
    final state = ref.read(discoveryNotifierProvider);

    if (state.currentStep == DiscoveryStep.scan) {
      _discoveryNotifier.reset();
      context.pop();
      return;
    }

    // If download is actively in progress, show download-specific dialog
    final downloadState = ref.read(downloadNotifierProvider);
    if (downloadState.isDownloading) {
      final shouldLeave = await showDownloadExitConfirmation(context);
      if (!shouldLeave || !mounted) return;
      await ref.read(downloadNotifierProvider.notifier).cancelDownload();
      if (!mounted) return;
      ref.read(discoveryNotifierProvider.notifier).reset();
      this.context.pop();
      return;
    }

    // Otherwise show generic exit confirmation
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.diveComputer_discovery_exitDialogTitle),
        content: Text(context.l10n.diveComputer_discovery_exitDialogContent),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(context.l10n.diveComputer_discovery_exitDialogCancel),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              ref.read(discoveryNotifierProvider.notifier).reset();
              this.context.pop();
            },
            child:
                Text(context.l10n.diveComputer_discovery_exitDialogConfirm),
          ),
        ],
      ),
    );
  }
```

**Step 4: Verify no analysis errors**

Run: `dart analyze lib/features/dive_computer/presentation/pages/device_discovery_page.dart`
Expected: No issues found

**Step 5: Commit**

```bash
git add lib/features/dive_computer/presentation/pages/device_discovery_page.dart
git commit -m "feat: extend navigation guard to DeviceDiscoveryPage download step"
```

---

### Task 4: Guard MainScaffold Bottom Navigation

**Files:**
- Modify: `lib/shared/widgets/main_scaffold.dart`

**Step 1: Add imports**

Add after existing imports (line 5):

```dart
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_computer/presentation/providers/download_providers.dart';
import 'package:submersion/features/dive_computer/presentation/widgets/download_exit_dialog.dart';
```

**Step 2: Convert to ConsumerStatefulWidget**

Change line 7:
```dart
class MainScaffold extends StatefulWidget {
```
To:
```dart
class MainScaffold extends ConsumerStatefulWidget {
```

Change line 13:
```dart
  State<MainScaffold> createState() => _MainScaffoldState();
```
To:
```dart
  ConsumerState<MainScaffold> createState() => _MainScaffoldState();
```

Change line 16:
```dart
class _MainScaffoldState extends State<MainScaffold> {
```
To:
```dart
class _MainScaffoldState extends ConsumerState<MainScaffold> {
```

**Step 3: Make _onDestinationSelected async and add download guard**

Change the method signature (line 69):
```dart
  void _onDestinationSelected(
```
To:
```dart
  Future<void> _onDestinationSelected(
```

Add the download guard at the top of the method body (after line 73, before the `if (isWideScreen)` block):

```dart
    // Guard: if a download is in progress, confirm before navigating away
    final isDownloading = ref.read(downloadNotifierProvider).isDownloading;
    if (isDownloading) {
      final shouldLeave = await showDownloadExitConfirmation(context);
      if (!shouldLeave || !mounted) return;
      await ref.read(downloadNotifierProvider.notifier).cancelDownload();
      if (!mounted) return;
    }
```

**Step 4: Verify no analysis errors**

Run: `dart analyze lib/shared/widgets/main_scaffold.dart`
Expected: No issues found

**Step 5: Run full project analysis**

Run: `flutter analyze`
Expected: No issues found

**Step 6: Format code**

Run: `dart format lib/features/dive_computer/presentation/widgets/download_exit_dialog.dart lib/features/dive_computer/presentation/pages/device_download_page.dart lib/features/dive_computer/presentation/pages/device_discovery_page.dart lib/shared/widgets/main_scaffold.dart`
Expected: All files formatted

**Step 7: Commit**

```bash
git add lib/shared/widgets/main_scaffold.dart
git commit -m "feat: guard bottom navigation tabs during active download"
```
