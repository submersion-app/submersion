# Check for Updates Menu Item - Design

## Overview

Add a native "Check for Updates..." menu item to the macOS application menu and
the Windows system menu. The menu item triggers the existing Sparkle/WinSparkle
interactive update check via a method channel bridge.

## Architecture

A method channel (`app.submersion/updates`) bridges native menu actions to the
existing Dart update system. Both platforms invoke `checkForUpdateInteractively`
through this channel.

```text
Native Menu Action
    |
    v
FlutterMethodChannel("app.submersion/updates")
    |
    v
Dart: UpdateStatusNotifier.checkForUpdateInteractively()
    |
    v
SparkleUpdateService.checkForUpdateInteractively()
    |
    v
Sparkle/WinSparkle native dialog
```

## macOS

- **MainMenu.xib**: Add `<menuItem title="Check for Updates...">` after
  "About APP_NAME", followed by a separator before "Preferences...".
- **AppDelegate.swift**: Add `@IBOutlet` for the menu item and an
  `@objc func checkForUpdates(_:)` action that sends
  `checkForUpdateInteractively` via `FlutterMethodChannel`.

## Windows

- **FlutterWindow::OnCreate()**: Append a separator and "Check for Updates..."
  to the window system menu via `GetSystemMenu` / `AppendMenu`.
- **FlutterWindow::MessageHandler()**: Handle `WM_SYSCOMMAND` for the custom
  command ID, invoking `checkForUpdateInteractively` via the Flutter engine
  method channel.

## Dart

- Register the `app.submersion/updates` method channel handler in
  `UpdateStatusNotifier` (or a dedicated initialization provider).
- On receiving `checkForUpdateInteractively`, call the existing notifier method.
- No new Dart UI; the native frameworks manage their own dialogs.

## Visibility

The menu item is defined in the XIB/resource but removed at runtime for App
Store builds. On macOS the `AppDelegate` checks for the App Store receipt
(`Bundle.main.appStoreReceiptURL`); when the receipt file exists (MAS and
TestFlight builds) the menu item and its trailing separator are removed before
the window is shown. Direct-distribution builds (DMG / GitHub) keep the menu
item.

## Files to modify

| File | Change |
|------|--------|
| `macos/Runner/Base.lproj/MainMenu.xib` | Add menu item + separator |
| `macos/Runner/AppDelegate.swift` | Add outlet + action + method channel |
| `windows/runner/flutter_window.h` | Add command ID constant |
| `windows/runner/flutter_window.cpp` | System menu + WM_SYSCOMMAND handler |
| `lib/features/auto_update/presentation/providers/update_providers.dart` | Register method channel handler |
