# Download Navigation Guard Design

## Problem

Users can navigate away from the download page while a dive computer download is in progress. This silently abandons the BLE connection and download without warning.

Three navigation vectors are unguarded:
1. System back button / swipe gesture (`DeviceDownloadPage` has no `PopScope`)
2. AppBar close button (cancels download immediately without confirmation)
3. Bottom navigation tabs (`MainScaffold._onDestinationSelected()` has no guards)

## Decision

**Approach:** Page-level guards with a shared confirmation dialog.

Chosen over GoRouter redirect (awkward with async dialogs) and modal overlay (too much UX change).

## Behavior

When the user attempts to navigate away during an active download (`DownloadState.isDownloading == true`):

1. A confirmation dialog appears: "Download in Progress -- Leaving will cancel the current download from your dive computer."
2. Actions: "Stay" (dismiss, remain on page) / "Leave" (cancel download, then navigate)
3. If user taps "Leave": `DownloadNotifier.cancelDownload()` is called, then navigation proceeds.

When no download is active (idle, complete, error, cancelled), navigation proceeds normally.

## Components

### 1. Shared Confirmation Dialog

**File:** `lib/features/dive_computer/presentation/widgets/download_exit_dialog.dart` (new)

```dart
Future<bool> showDownloadExitConfirmation(BuildContext context);
```

- Returns `true` if user confirmed "Leave", `false` if dismissed or tapped "Stay"
- Title: "Download in Progress"
- Body: "Leaving will cancel the current download from your dive computer. Are you sure?"
- Actions: "Stay" (primary) / "Leave" (destructive)

### 2. DeviceDownloadPage Guard

**File:** `device_download_page.dart` (modified)

- Wrap body in `PopScope(canPop: !isDownloading)`
- `onPopInvokedWithResult`: show confirmation dialog, cancel download if confirmed, then pop
- AppBar close button: show confirmation dialog when downloading, cancel+pop on confirm

### 3. DeviceDiscoveryPage Guard

**File:** `device_discovery_page.dart` (modified)

- Update existing `PopScope.canPop`: block when on download step AND downloading
- Update `_showExitConfirmation()`: when downloading, use the shared download confirmation dialog instead of the generic exit dialog

### 4. MainScaffold Bottom Nav Guard

**File:** `main_scaffold.dart` (modified)

- Convert to `ConsumerStatefulWidget` (or use inline `Consumer`) to access `downloadNotifierProvider`
- In `_onDestinationSelected()`: check `ref.read(downloadNotifierProvider).isDownloading`
- If downloading: show confirmation dialog, cancel download if confirmed, then `context.go(route)`
- If not downloading: proceed with `context.go(route)` as before

## Download State Reference

Guard triggers when `DownloadState.isDownloading` is `true`, which covers phases:
- `connecting`
- `enumerating`
- `downloading`

Guard does NOT trigger during:
- `initializing`, `processing`, `complete`, `error`, `cancelled`

## Files Changed

| File | Type | Description |
|------|------|-------------|
| `download_exit_dialog.dart` | New | Shared confirmation dialog function |
| `device_download_page.dart` | Modified | Add PopScope + update AppBar close |
| `device_discovery_page.dart` | Modified | Extend PopScope for download step |
| `main_scaffold.dart` | Modified | Guard tab switches during download |
