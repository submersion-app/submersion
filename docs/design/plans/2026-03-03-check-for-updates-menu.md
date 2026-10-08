# Check for Updates Menu Item - Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add a native "Check for Updates..." menu item to the macOS application menu and Windows system menu that triggers the existing Sparkle/WinSparkle interactive update check.

**Architecture:** A method channel (`app.submersion/updates`) bridges native menu actions to Dart. The macOS menu item is added to MainMenu.xib with an action in AppDelegate.swift. The Windows menu item is appended to the system menu with a WM_SYSCOMMAND handler. Both call `checkForUpdateInteractively` on the existing `UpdateStatusNotifier`.

**Tech Stack:** Swift (macOS), C++ / Win32 (Windows), Dart/Flutter method channels, existing auto_updater/Sparkle infrastructure.

---

### Task 1: Dart Method Channel Handler

Register a method channel listener that invokes the existing update check when called from native code.

**Files:**

- Create: `lib/features/auto_update/presentation/providers/update_menu_channel.dart`
- Modify: `lib/app.dart:21-27` (register channel in initState)

**Step 1: Create the method channel handler**

Create `lib/features/auto_update/presentation/providers/update_menu_channel.dart`:

```dart
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/features/auto_update/presentation/providers/update_providers.dart';

const _channel = MethodChannel('app.submersion/updates');

/// Registers a method channel handler that allows native menu items
/// to trigger an interactive update check.
void registerUpdateMenuChannel(WidgetRef ref) {
  _channel.setMethodCallHandler((call) async {
    if (call.method == 'checkForUpdateInteractively') {
      await ref
          .read(updateStatusProvider.notifier)
          .checkForUpdateInteractively();
    }
  });
}
```typescript
**Step 2: Register the channel in SubmersionApp.initState**

In `lib/app.dart`, add the import and call `registerUpdateMenuChannel(ref)` inside the existing `initState` method, after the `addPostFrameCallback` call:

```dart
import 'package:submersion/features/auto_update/presentation/providers/update_menu_channel.dart';
```text
In `initState`:

```dart
@override
void initState() {
  super.initState();
  WidgetsBinding.instance.addObserver(this);
  registerUpdateMenuChannel(ref);
  WidgetsBinding.instance.addPostFrameCallback((_) {
    _maybeSyncOnLaunch();
  });
}
```text
**Step 3: Run analyze to verify**

Run: `flutter analyze lib/features/auto_update/presentation/providers/update_menu_channel.dart lib/app.dart`
Expected: No issues found

**Step 4: Commit**

```bash
git add lib/features/auto_update/presentation/providers/update_menu_channel.dart lib/app.dart
git commit -m "feat: add method channel handler for native update menu"
```sql
---

### Task 2: macOS MainMenu.xib - Add Menu Item

Add the "Check for Updates..." menu item to the application menu in the XIB file.

**Files:**

- Modify: `macos/Runner/Base.lproj/MainMenu.xib:34-35`

**Step 1: Add the menu item after "About APP_NAME"**

In `MainMenu.xib`, insert the following XML after the "About APP_NAME" `</menuItem>` (after line 34, before the existing separator at line 35):

```xml
                            <menuItem title="Check for Updates…" id="kFl-7z-upc">
                                <modifierMask key="keyEquivalentModifierMask"/>
                                <connections>
                                    <action selector="checkForUpdates:" target="Voe-Tx-rLC" id="dLw-3K-9bX"/>
                                </connections>
                            </menuItem>
```typescript
Note: The `target="Voe-Tx-rLC"` is the AppDelegate's existing XIB object ID. The `id` values are arbitrary unique strings.

**Step 2: Verify XIB is valid XML**

Run: `python3 -c "import xml.etree.ElementTree as ET; ET.parse('macos/Runner/Base.lproj/MainMenu.xib'); print('Valid')"`
Expected: `Valid`

**Step 3: Commit**

```bash
git add macos/Runner/Base.lproj/MainMenu.xib
git commit -m "feat(macos): add 'Check for Updates' to application menu"
```diff
---

### Task 3: macOS AppDelegate - Add Action Handler

Wire the menu item action to the Flutter method channel.

**Files:**

- Modify: `macos/Runner/AppDelegate.swift:1-36`

**Step 1: Add the method channel and action**

Replace the full `AppDelegate.swift` with the following (adds FlutterMethodChannel import, a channel property, channel initialization in `applicationDidFinishLaunching`, and the `checkForUpdates:` action):

```swift
import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  private var bookmarkHandler: SecurityScopedBookmarkHandler?
  private var icloudHandler: ICloudContainerHandler?
  private var metadataHandler: MetadataWriteHandler?
  private var updateChannel: FlutterMethodChannel?

  override func applicationDidFinishLaunching(_ notification: Notification) {
    NSLog("[AppDelegate] applicationDidFinishLaunching called")
    if let controller = mainFlutterWindow?.contentViewController as? FlutterViewController {
      NSLog("[AppDelegate] Got FlutterViewController, setting up handlers...")
      let messenger = controller.engine.binaryMessenger
      bookmarkHandler = SecurityScopedBookmarkHandler(messenger: messenger)
      icloudHandler = ICloudContainerHandler(messenger: messenger)
      metadataHandler = MetadataWriteHandler(messenger: messenger)
      updateChannel = FlutterMethodChannel(
        name: "app.submersion/updates",
        binaryMessenger: messenger
      )
      NSLog("[AppDelegate] All handlers initialized")
    } else {
      NSLog("[AppDelegate] ERROR: Could not get FlutterViewController!")
    }
  }

  @IBAction func checkForUpdates(_ sender: Any) {
    updateChannel?.invokeMethod("checkForUpdateInteractively", arguments: nil)
  }

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationWillTerminate(_ notification: Notification) {
    bookmarkHandler?.cleanup()
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
}
```text
**Step 2: Build macOS to verify compilation**

Run: `flutter build macos --debug 2>&1 | tail -5`
Expected: Build succeeds

**Step 3: Commit**

```bash
git add macos/Runner/AppDelegate.swift
git commit -m "feat(macos): wire 'Check for Updates' menu action to method channel"
```diff
---

### Task 4: Windows - Add System Menu Item

Append "Check for Updates..." to the window system menu and handle the command.

**Files:**

- Modify: `windows/runner/flutter_window.h:25-31`
- Modify: `windows/runner/flutter_window.cpp:12-71`

**Step 1: Add the command ID constant to flutter_window.h**

Add after line 30 (`std::unique_ptr<flutter::FlutterViewController> flutter_controller_;`) but before the closing `};`:

```cpp
  // Custom system menu command ID for "Check for Updates..."
  static constexpr UINT kCheckForUpdatesCmd = 0x0010;
```text
**Step 2: Modify FlutterWindow::OnCreate() to add the system menu item**

In `flutter_window.cpp`, add the following at the end of `OnCreate()`, just before `return true;` (after the `ForceRedraw` call):

```cpp
  // Add "Check for Updates..." to the window system menu
  HMENU sys_menu = GetSystemMenu(GetHandle(), FALSE);
  if (sys_menu) {
    AppendMenu(sys_menu, MF_SEPARATOR, 0, nullptr);
    AppendMenu(sys_menu, MF_STRING, kCheckForUpdatesCmd,
               L"Check for Updates...");
  }
```text
**Step 3: Handle WM_SYSCOMMAND in MessageHandler**

In `FlutterWindow::MessageHandler`, add a new case in the `switch (message)` block (after the `WM_FONTCHANGE` case, before the closing `}`):

```cpp
    case WM_SYSCOMMAND:
      if ((wparam & 0xFFF0) == kCheckForUpdatesCmd) {
        if (flutter_controller_) {
          flutter_controller_->engine()->ProcessMessages();
          auto channel = flutter::MethodChannel<flutter::EncodableValue>(
              flutter_controller_->engine()->messenger(),
              "app.submersion/updates",
              &flutter::StandardMethodCodec::GetInstance());
          channel.InvokeMethod("checkForUpdateInteractively", nullptr);
        }
        return 0;
      }
      break;
```text
Also add at the top of `flutter_window.cpp` (with the other includes):

```cpp
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>
```text
**Step 4: Build Windows to verify compilation (if on Windows, otherwise skip)**

Run: `flutter build windows --debug 2>&1 | tail -5`
Expected: Build succeeds (skip if not on Windows)

**Step 5: Commit**

```bash
git add windows/runner/flutter_window.h windows/runner/flutter_window.cpp
git commit -m "feat(windows): add 'Check for Updates' to system menu"
```text
---

### Task 5: Manual Testing & Format

**Step 1: Format all Dart code**

Run: `dart format lib/features/auto_update/presentation/providers/update_menu_channel.dart lib/app.dart`

**Step 2: Run analyze**

Run: `flutter analyze`
Expected: No issues found

**Step 3: Run tests**

Run: `flutter test`
Expected: All existing tests pass

**Step 4: Manual test on macOS**

Run: `flutter run -d macos`

Verify:

- The "Submersion" app menu shows "Check for Updates..." between "About Submersion" and the separator
- Clicking it triggers the Sparkle update check dialog (shows "checking..." then "up to date" or update prompt)

**Step 5: Commit any formatting changes**

```bash
git add -A
git commit -m "chore: format and verify check-for-updates menu"
```
