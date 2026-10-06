# Auto Updater Windows Threading Fix Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix the platform channel threading violation in the `auto_updater_windows` plugin (#83) by vendoring the plugin and marshaling WinSparkle callbacks to the Flutter platform thread.

**Architecture:** Vendor `auto_updater_windows` into `packages/auto_updater_windows/` (same pattern as `libdivecomputer_plugin`). Replace the direct `event_sink_->Success()` calls in WinSparkle callbacks with a thread-safe queue + Win32 `PostMessage` pattern that drains events on the platform thread.

**Tech Stack:** C++ (Win32 API, Flutter plugin API), CMake, Flutter/Dart (pubspec dependency override)

---

### Task 1: Vendor the auto_updater_windows Plugin

**Files:**
- Create: `packages/auto_updater_windows/` (copy from pub cache)
- Modify: `pubspec.yaml` (add dependency override)

- [ ] **Step 1: Copy the plugin from the pub cache**

```bash
cp -r ~/.pub-cache/hosted/pub.dev/auto_updater_windows-1.0.0/ packages/auto_updater_windows/
```

- [ ] **Step 2: Clean up non-essential files from the vendored copy**

Remove files that are only needed for pub publishing, not for building:

```bash
rm -f packages/auto_updater_windows/CHANGELOG.md
rm -f packages/auto_updater_windows/README.md
rm -f packages/auto_updater_windows/LICENSE
rm -f packages/auto_updater_windows/analysis_options.yaml
rm -rf packages/auto_updater_windows/windows/test/
```

- [ ] **Step 3: Add the dependency override to pubspec.yaml**

In `pubspec.yaml`, add to the existing `dependency_overrides:` section:

```yaml
dependency_overrides:
  # Pin to 9.4.5 to avoid CNAuthorizationStatusLimited compile error
  # See: https://github.com/Baseflow/flutter-permission-handler/issues/1450
  permission_handler_apple: 9.4.5
  # fit_tool (3 years unmaintained) has stale deps; overrides are safe because:
  # - csv: fit_tool uses csv for optional CSV export, not core FIT binary parsing
  # - logger: fit_tool uses basic logging; logger 2.x is backward-compatible
  csv: ^6.0.0
  logger: ^2.0.0
  # Vendored with threading fix for #83 — WinSparkle callbacks were calling
  # event_sink_->Success() from background threads, violating Flutter's
  # platform channel threading requirement.
  auto_updater_windows:
    path: packages/auto_updater_windows
```

- [ ] **Step 4: Verify Flutter resolves the override**

```bash
flutter pub get
```

Expected: resolves successfully with no errors. The output should show
`auto_updater_windows` sourced from the local path instead of pub.dev.

- [ ] **Step 5: Commit the vendored plugin**

```bash
git add packages/auto_updater_windows/ pubspec.yaml
git commit -m "chore: vendor auto_updater_windows plugin for threading fix (#83)"
```

---

### Task 2: Fix the Threading in auto_updater.cpp

This is the core fix. Replace `OnWinSparkleEvent()` (which calls
`event_sink_->Success()` directly from WinSparkle's background threads) with a
thread-safe queue that defers event delivery to the platform thread.

**Files:**
- Modify: `packages/auto_updater_windows/windows/auto_updater.cpp`

- [ ] **Step 1: Replace auto_updater.cpp with the thread-safe version**

Replace the entire contents of
`packages/auto_updater_windows/windows/auto_updater.cpp` with:

```cpp
#include "WinSparkle-0.8.1/include/winsparkle.h"

#include <windows.h>

#include <flutter/event_channel.h>
#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

#include <memory>
#include <mutex>
#include <queue>
#include <sstream>
#include <string>

namespace {

// Custom Windows message used to signal the platform thread that events are
// waiting in the queue. WM_APP is the start of the application-private range.
constexpr UINT WM_APP_SPARKLE_EVENT = WM_APP + 1;

// Forward declarations for WinSparkle callbacks
void __onErrorCallback();
void __onShutdownRequestCallback();
void __onDidFindUpdateCallback();
void __onDidNotFindUpdateCallback();
void __onUpdateCancelledCallback();
void __onUpdateSkippedCallback();
void __onUpdatePostponedCallback();
void __onUpdateDismissedCallback();
void __onUserRunInstallerCallback();

class AutoUpdater {
 public:
  static AutoUpdater* GetInstance();

  AutoUpdater();

  virtual ~AutoUpdater();

  void SetFeedURL(std::string feedURL);
  void CheckForUpdates();
  void CheckForUpdatesWithoutUI();
  void SetScheduledCheckInterval(int interval);

  void RegisterEventSink(
      std::unique_ptr<flutter::EventSink<flutter::EncodableValue>> ptr);

  // Called from WinSparkle background threads. Enqueues the event and signals
  // the platform thread via PostMessage.
  void OnWinSparkleEvent(std::string eventName);

  // Called from the platform thread (window proc delegate) to drain the queue
  // and deliver events through the EventSink.
  void DrainEvents();

  // Store the HWND used for PostMessage signaling.
  void SetWindowHandle(HWND hwnd);

 private:
  static AutoUpdater* lazySingleton;
  std::unique_ptr<flutter::EventSink<flutter::EncodableValue>> event_sink_;

  // Thread-safe event queue. WinSparkle callbacks push event names here;
  // the platform thread drains them in DrainEvents().
  std::mutex event_mutex_;
  std::queue<std::string> event_queue_;
  HWND hwnd_ = nullptr;
};

AutoUpdater* AutoUpdater::lazySingleton = nullptr;

AutoUpdater* AutoUpdater::GetInstance() {
  return lazySingleton;
}

AutoUpdater::AutoUpdater() {
  if (lazySingleton != nullptr) {
    throw std::invalid_argument("AutoUpdater has already been initialized");
  }

  lazySingleton = this;
}

AutoUpdater::~AutoUpdater() {}

void AutoUpdater::SetWindowHandle(HWND hwnd) {
  hwnd_ = hwnd;
}

void AutoUpdater::SetFeedURL(std::string feedURL) {
  win_sparkle_set_appcast_url(feedURL.c_str());
  win_sparkle_init();

  win_sparkle_set_error_callback(__onErrorCallback);
  win_sparkle_set_shutdown_request_callback(__onShutdownRequestCallback);
  win_sparkle_set_did_find_update_callback(__onDidFindUpdateCallback);
  win_sparkle_set_did_not_find_update_callback(__onDidNotFindUpdateCallback);
  win_sparkle_set_update_cancelled_callback(__onUpdateCancelledCallback);
}

void AutoUpdater::CheckForUpdates() {
  win_sparkle_check_update_with_ui();
  OnWinSparkleEvent("checking-for-update");
}

void AutoUpdater::CheckForUpdatesWithoutUI() {
  win_sparkle_check_update_without_ui();
  OnWinSparkleEvent("checking-for-update");
}

void AutoUpdater::SetScheduledCheckInterval(int interval) {
  win_sparkle_set_update_check_interval(interval);
}

void AutoUpdater::RegisterEventSink(
    std::unique_ptr<flutter::EventSink<flutter::EncodableValue>> ptr) {
  event_sink_ = std::move(ptr);
}

void AutoUpdater::OnWinSparkleEvent(std::string eventName) {
  {
    std::lock_guard<std::mutex> lock(event_mutex_);
    event_queue_.push(std::move(eventName));
  }

  // Signal the platform thread. PostMessage is safe to call from any thread.
  if (hwnd_ != nullptr) {
    PostMessage(hwnd_, WM_APP_SPARKLE_EVENT, 0, 0);
  }
}

void AutoUpdater::DrainEvents() {
  // Swap the queue under the lock to minimize time spent holding the mutex.
  std::queue<std::string> local_queue;
  {
    std::lock_guard<std::mutex> lock(event_mutex_);
    std::swap(local_queue, event_queue_);
  }

  // Now deliver events outside the lock, on the platform thread.
  while (!local_queue.empty()) {
    std::string eventName = std::move(local_queue.front());
    local_queue.pop();

    if (event_sink_ == nullptr)
      continue;

    flutter::EncodableMap args = flutter::EncodableMap();
    args[flutter::EncodableValue("type")] = eventName;
    event_sink_->Success(flutter::EncodableValue(args));
  }
}

void __onErrorCallback() {
  AutoUpdater* autoUpdater = AutoUpdater::GetInstance();
  if (autoUpdater == nullptr)
    return;
  autoUpdater->OnWinSparkleEvent("error");
}

void __onShutdownRequestCallback() {
  AutoUpdater* autoUpdater = AutoUpdater::GetInstance();
  if (autoUpdater == nullptr)
    return;
  autoUpdater->OnWinSparkleEvent("before-quit-for-update");
}

void __onDidFindUpdateCallback() {
  AutoUpdater* autoUpdater = AutoUpdater::GetInstance();
  if (autoUpdater == nullptr)
    return;
  autoUpdater->OnWinSparkleEvent("update-available");
}

void __onDidNotFindUpdateCallback() {
  AutoUpdater* autoUpdater = AutoUpdater::GetInstance();
  if (autoUpdater == nullptr)
    return;
  autoUpdater->OnWinSparkleEvent("update-not-available");
}

void __onUpdateCancelledCallback() {
  AutoUpdater* autoUpdater = AutoUpdater::GetInstance();
  if (autoUpdater == nullptr)
    return;
  autoUpdater->OnWinSparkleEvent("updateCancelled");
}

void __onUpdateSkippedCallback() {
  AutoUpdater* autoUpdater = AutoUpdater::GetInstance();
  if (autoUpdater == nullptr)
    return;
  autoUpdater->OnWinSparkleEvent("updateSkipped");
}

void __onUpdatePostponedCallback() {
  AutoUpdater* autoUpdater = AutoUpdater::GetInstance();
  if (autoUpdater == nullptr)
    return;
  autoUpdater->OnWinSparkleEvent("updatePostponed");
}

void __onUpdateDismissedCallback() {
  AutoUpdater* autoUpdater = AutoUpdater::GetInstance();
  if (autoUpdater == nullptr)
    return;
  autoUpdater->OnWinSparkleEvent("updateDismissed");
}

void __onUserRunInstallerCallback() {
  AutoUpdater* autoUpdater = AutoUpdater::GetInstance();
  if (autoUpdater == nullptr)
    return;
  autoUpdater->OnWinSparkleEvent("userRunInstaller");
}
}  // namespace
```

Key changes from the original:
- Added `#include <windows.h>`, `<mutex>`, `<queue>`, `<string>`
- Added `WM_APP_SPARKLE_EVENT` constant
- Added `event_mutex_`, `event_queue_`, `hwnd_` members
- Added `SetWindowHandle()` and `DrainEvents()` methods
- `OnWinSparkleEvent()` now enqueues + PostMessage instead of calling event_sink_ directly
- `DrainEvents()` swaps the queue under the lock, then delivers events outside the lock
- Removed the commented-out TODO callbacks that referenced >0.8.0 (WinSparkle 0.8.1 is bundled, but the plugin never wired them up — keeping the dead code is confusing)

- [ ] **Step 2: Commit the threading fix**

```bash
git add packages/auto_updater_windows/windows/auto_updater.cpp
git commit -m "fix: thread-safe event queue in auto_updater.cpp (#83)

WinSparkle fires callbacks on background threads. Replace direct
event_sink_->Success() calls with a mutex-guarded queue + PostMessage
to defer delivery to the Flutter platform thread."
```

---

### Task 3: Wire Up the Platform Thread in the Plugin Shell

Connect the AutoUpdater's queue to the Flutter platform thread by obtaining the
HWND and registering a window procedure delegate that drains events.

**Files:**
- Modify: `packages/auto_updater_windows/windows/auto_updater_windows_plugin.h`
- Modify: `packages/auto_updater_windows/windows/auto_updater_windows_plugin.cpp`

- [ ] **Step 1: Update the plugin header with new members**

Replace the entire contents of
`packages/auto_updater_windows/windows/auto_updater_windows_plugin.h` with:

```cpp
#ifndef FLUTTER_PLUGIN_AUTO_UPDATER_WINDOWS_PLUGIN_H_
#define FLUTTER_PLUGIN_AUTO_UPDATER_WINDOWS_PLUGIN_H_

#include <windows.h>

#include <flutter/event_channel.h>
#include <flutter/event_stream_handler_functions.h>
#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>

#include <memory>

#include "auto_updater.cpp"

namespace auto_updater_windows {

class AutoUpdaterWindowsPlugin
    : public flutter::Plugin,
      flutter::StreamHandler<flutter::EncodableValue> {
 private:
  flutter::PluginRegistrarWindows* registrar_;
  std::unique_ptr<flutter::EventSink<flutter::EncodableValue>> event_sink_;
  AutoUpdater auto_updater = AutoUpdater();

  // Window procedure delegate ID for cleanup on destruction.
  int window_proc_delegate_id_ = 0;

 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows* registrar);

  AutoUpdaterWindowsPlugin(flutter::PluginRegistrarWindows* registrar);

  virtual ~AutoUpdaterWindowsPlugin();

  // Disallow copy and assign.
  AutoUpdaterWindowsPlugin(const AutoUpdaterWindowsPlugin&) = delete;
  AutoUpdaterWindowsPlugin& operator=(const AutoUpdaterWindowsPlugin&) = delete;

  // Called when a method is called on this plugin's channel from Dart.
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue>& method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  std::unique_ptr<flutter::StreamHandlerError<>> OnListenInternal(
      const flutter::EncodableValue* arguments,
      std::unique_ptr<flutter::EventSink<>>&& events) override;

  std::unique_ptr<flutter::StreamHandlerError<>> OnCancelInternal(
      const flutter::EncodableValue* arguments) override;
};

}  // namespace auto_updater_windows

#endif  // FLUTTER_PLUGIN_AUTO_UPDATER_WINDOWS_PLUGIN_H_
```

Changes from original:
- Added `#include <windows.h>`
- Added `int window_proc_delegate_id_` member

- [ ] **Step 2: Update the plugin implementation with HWND and window proc delegate**

Replace the entire contents of
`packages/auto_updater_windows/windows/auto_updater_windows_plugin.cpp` with:

```cpp
#include "auto_updater_windows_plugin.h"

// This must be included before many other Windows headers.
#include <windows.h>

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

#include <memory>
#include <sstream>

namespace auto_updater_windows {

// static
void AutoUpdaterWindowsPlugin::RegisterWithRegistrar(
    flutter::PluginRegistrarWindows* registrar) {
  auto channel =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          registrar->messenger(), "dev.leanflutter.plugins/auto_updater",
          &flutter::StandardMethodCodec::GetInstance());

  auto plugin = std::make_unique<AutoUpdaterWindowsPlugin>(registrar);

  channel->SetMethodCallHandler(
      [plugin_pointer = plugin.get()](const auto& call, auto result) {
        plugin_pointer->HandleMethodCall(call, std::move(result));
      });
  auto event_channel =
      std::make_unique<flutter::EventChannel<flutter::EncodableValue>>(
          registrar->messenger(), "dev.leanflutter.plugins/auto_updater_event",
          &flutter::StandardMethodCodec::GetInstance());
  auto streamHandler = std::make_unique<flutter::StreamHandlerFunctions<>>(
      [plugin_pointer = plugin.get()](
          const flutter::EncodableValue* arguments,
          std::unique_ptr<flutter::EventSink<>>&& events)
          -> std::unique_ptr<flutter::StreamHandlerError<>> {
        return plugin_pointer->OnListen(arguments, std::move(events));
      },
      [plugin_pointer = plugin.get()](const flutter::EncodableValue* arguments)
          -> std::unique_ptr<flutter::StreamHandlerError<>> {
        return plugin_pointer->OnCancel(arguments);
      });
  event_channel->SetStreamHandler(std::move(streamHandler));
  registrar->AddPlugin(std::move(plugin));
}

AutoUpdaterWindowsPlugin::AutoUpdaterWindowsPlugin(
    flutter::PluginRegistrarWindows* registrar) {
  registrar_ = registrar;

  // Obtain the Flutter window HWND and pass it to AutoUpdater so that
  // WinSparkle callbacks (which fire on background threads) can use
  // PostMessage to signal the platform thread.
  HWND hwnd = registrar_->GetView()->GetNativeWindow();
  auto_updater.SetWindowHandle(hwnd);

  // Register a window procedure delegate to handle WM_APP_SPARKLE_EVENT.
  // This runs on the platform thread, making event_sink_->Success() safe.
  window_proc_delegate_id_ =
      registrar_->RegisterTopLevelWindowProcDelegate(
          [this](HWND hwnd, UINT message, WPARAM wparam,
                 LPARAM lparam) -> std::optional<LRESULT> {
            if (message == WM_APP_SPARKLE_EVENT) {
              auto_updater.DrainEvents();
              return 0;
            }
            return std::nullopt;
          });
}

AutoUpdaterWindowsPlugin::~AutoUpdaterWindowsPlugin() {
  registrar_->UnregisterTopLevelWindowProcDelegate(window_proc_delegate_id_);
}

void AutoUpdaterWindowsPlugin::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue>& method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  std::string method_name = method_call.method_name();

  if (method_name.compare("setFeedURL") == 0) {
    const flutter::EncodableMap& args =
        std::get<flutter::EncodableMap>(*method_call.arguments());
    std::string feedURL =
        std::get<std::string>(args.at(flutter::EncodableValue("feedURL")));
    auto_updater.SetFeedURL(feedURL);
    auto_updater.RegisterEventSink(std::move(event_sink_));
    result->Success(flutter::EncodableValue(true));

  } else if (method_name.compare("checkForUpdates") == 0) {
    const flutter::EncodableMap& args =
        std::get<flutter::EncodableMap>(*method_call.arguments());
    bool inBackground =
        std::get<bool>(args.at(flutter::EncodableValue("inBackground")));
    if (inBackground) {
      auto_updater.CheckForUpdatesWithoutUI();
    } else {
      auto_updater.CheckForUpdates();
    }
    result->Success(flutter::EncodableValue(true));

  } else if (method_name.compare("setScheduledCheckInterval") == 0) {
    const flutter::EncodableMap& args =
        std::get<flutter::EncodableMap>(*method_call.arguments());
    int interval = std::get<int>(args.at(flutter::EncodableValue("interval")));
    auto_updater.SetScheduledCheckInterval(interval);
    result->Success(flutter::EncodableValue(true));

  } else {
    result->NotImplemented();
  }
}

std::unique_ptr<flutter::StreamHandlerError<flutter::EncodableValue>>
AutoUpdaterWindowsPlugin::OnListenInternal(
    const flutter::EncodableValue* arguments,
    std::unique_ptr<flutter::EventSink<flutter::EncodableValue>>&& events) {
  event_sink_ = std::move(events);
  return nullptr;
}

std::unique_ptr<flutter::StreamHandlerError<flutter::EncodableValue>>
AutoUpdaterWindowsPlugin::OnCancelInternal(
    const flutter::EncodableValue* arguments) {
  event_sink_ = nullptr;
  return nullptr;
}
}  // namespace auto_updater_windows
```

Changes from original:
- Constructor: gets HWND via `registrar_->GetView()->GetNativeWindow()`, calls `auto_updater.SetWindowHandle(hwnd)`, registers `TopLevelWindowProcDelegate` that calls `auto_updater.DrainEvents()` on `WM_APP_SPARKLE_EVENT`
- Destructor: calls `UnregisterTopLevelWindowProcDelegate()` for cleanup
- `WM_APP_SPARKLE_EVENT` is referenced from the anonymous namespace in `auto_updater.cpp` (which is `#include`-d directly into the header — the original plugin uses this unusual pattern)

- [ ] **Step 3: Commit the plugin shell changes**

```bash
git add packages/auto_updater_windows/windows/auto_updater_windows_plugin.h \
        packages/auto_updater_windows/windows/auto_updater_windows_plugin.cpp
git commit -m "fix: wire platform thread drain for WinSparkle events (#83)

Register a TopLevelWindowProcDelegate that handles the custom
WM_APP_SPARKLE_EVENT message and drains the event queue on the
platform thread."
```

---

### Task 4: Verify the Build and Run Tests

Since this is a native C++ change that can only compile on Windows, verification
is split into what can be checked on any platform and what requires Windows.

**Files:** None (verification only)

- [ ] **Step 1: Verify Flutter dependency resolution**

```bash
flutter pub get
```

Expected: resolves successfully. `auto_updater_windows` should come from the
local path.

- [ ] **Step 2: Run flutter analyze**

```bash
flutter analyze
```

Expected: no new warnings or errors. The Dart code is unchanged, so this
confirms the dependency override doesn't break analysis.

- [ ] **Step 3: Run existing tests**

```bash
flutter test
```

Expected: all tests pass. No Dart behavior changed, so this is a regression
check.

- [ ] **Step 4: Commit any formatting or analysis fixes (if needed)**

Only if the previous steps revealed issues:

```bash
dart format lib/ test/
git add -A
git commit -m "chore: fix formatting after auto_updater vendoring"
```

---

### Task 5: Manual Windows Verification

This task must be performed on a Windows machine. It validates that the
threading fix works end-to-end.

**Files:** None (manual testing only)

- [ ] **Step 1: Build and run on Windows**

```bash
flutter run -d windows
```

Expected: app launches without the threading error in the console.

- [ ] **Step 2: Trigger a background update check**

Wait 5 seconds after launch (the `UpdateStatusNotifier` auto-checks after a
5-second delay). Watch the debug console.

Expected: no `non-platform thread` error. If an update is available, WinSparkle
should show its native dialog.

- [ ] **Step 3: Trigger an interactive update check**

Navigate to Settings and tap "Check for Updates".

Expected: WinSparkle's native checking dialog appears. No threading error in
console.

- [ ] **Step 4: Verify macOS is unaffected (if available)**

```bash
flutter run -d macos
```

Expected: Sparkle-based updates work as before. The `dependency_overrides` only
affects the Windows platform package.
