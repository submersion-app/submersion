# Auto Updater Windows Threading Fix

**Issue:** [#83](https://github.com/submersion-app/submersion/issues/83)
**Date:** 2026-03-28
**Status:** Draft

## Problem

On Windows, the `auto_updater_windows` plugin (v1.0.0, by leanflutter) triggers a
Flutter threading violation:

```
The 'dev.leanflutter.plugins/auto_updater_event' channel sent a message from
native to Flutter on a non-platform thread.
```

The plugin wraps WinSparkle (0.8.1), which fires all callbacks on background
threads. The plugin's C++ code calls `event_sink_->Success()` directly from
those callbacks without marshaling to the platform thread.

This is confirmed by WinSparkle's own documentation in `winsparkle.h`:

> There's no guarantee about the thread from which the callback is called,
> except that it certainly *won't* be called from the app's main thread.

## Approach

Vendor the `auto_updater_windows` plugin into the repository as a path
dependency and fix the threading issue in the native C++ code.

**Why vendor instead of forking?** The plugin is small (a thin C++ wrapper
around WinSparkle), `auto_updater` v1.0.0 shows low upstream maintenance
activity, and vendoring avoids git dependency headaches in CI. We keep full
control with no external coordination required.

## Design

### Threading Fix

Use the standard Win32 cross-thread communication pattern:

1. **Store the Flutter window HWND** during plugin registration via
   `registrar->GetView()->GetNativeWindow()`.

2. **Add a thread-safe event queue** in `AutoUpdater` using `std::mutex` and
   `std::queue<std::string>`. WinSparkle callbacks push event names onto this
   queue instead of calling `event_sink_->Success()` directly.

3. **Signal the platform thread** by calling `PostMessage(hwnd, WM_APP_SPARKLE_EVENT, 0, 0)`
   with a custom message ID after enqueuing. `PostMessage` is safe to call from
   any thread.

4. **Process the queue on the platform thread** in a window procedure delegate
   registered via `registrar->RegisterTopLevelWindowProcDelegate()`. When the
   custom message arrives, drain the queue and call `event_sink_->Success()`
   for each event. This runs on the platform thread, satisfying Flutter's
   requirement.

### File Layout

```
packages/
  auto_updater_windows/
    pubspec.yaml
    windows/
      CMakeLists.txt
      auto_updater.cpp              (modified: thread-safe queue + PostMessage)
      auto_updater_windows_plugin.cpp  (modified: HWND, window proc delegate, queue drain)
      auto_updater_windows_plugin.h    (modified: HWND + queue member fields)
      auto_updater_windows_plugin_c_api.cpp  (unchanged)
      include/
        auto_updater_windows/
          auto_updater_windows_plugin_c_api.h  (unchanged)
      WinSparkle-0.8.1/             (unchanged, vendored binaries)
        include/
          winsparkle.h
          winsparkle-version.h
        x64/Release/
          WinSparkle.dll
          WinSparkle.lib
          WinSparkle.pdb
        Release/
          WinSparkle.dll
          WinSparkle.lib
          WinSparkle.pdb
        ARM64/Release/
          WinSparkle.dll
          WinSparkle.lib
          WinSparkle.pdb
```

### Changes by File

**`auto_updater.cpp`** -- Core threading fix:
- Add `#include <mutex>` and `#include <queue>`
- Add `std::mutex event_mutex_` and `std::queue<std::string> event_queue_` to `AutoUpdater`
- Store the HWND passed in from the plugin during initialization
- Define `WM_APP_SPARKLE_EVENT` as a custom Windows message (`WM_APP + 1`)
- Change `OnWinSparkleEvent()` to lock the mutex, push the event name onto the
  queue, and call `PostMessage(hwnd_, WM_APP_SPARKLE_EVENT, 0, 0)`
- Add `DrainEvents()` method: locks mutex, drains queue, calls
  `event_sink_->Success()` for each event (called from the platform thread)

**`auto_updater_windows_plugin.h`** -- New members:
- Add `HWND window_handle_` field
- Add `int window_proc_delegate_id_` for cleanup

**`auto_updater_windows_plugin.cpp`** -- Platform thread integration:
- In `RegisterWithRegistrar()`: obtain HWND from registrar, pass to AutoUpdater
- Register a `TopLevelWindowProcDelegate` that handles `WM_APP_SPARKLE_EVENT`
  by calling `auto_updater.DrainEvents()`
- In destructor: unregister the window proc delegate

**`pubspec.yaml` (app root)** -- Dependency change:
- Replace `auto_updater: ^1.0.0` (which pulls in `auto_updater_windows`
  transitively) with an explicit path override:
  ```yaml
  dependency_overrides:
    auto_updater_windows:
      path: packages/auto_updater_windows
  ```

### What Does Not Change

- All Dart code: `SparkleUpdateService`, `update_providers.dart`, `UpdateBanner`
- WinSparkle 0.8.1 binaries
- macOS `auto_updater_macos` (not affected, stays as pub dependency)
- `auto_updater` platform interface package (stays as pub dependency)
- Linux/Android `GithubUpdateService` fallback path

## Testing

- **Manual:** Run debug build on Windows, trigger update check, verify no
  threading error in console output.
- **Regression:** Verify that WinSparkle events (update-available,
  update-not-available, error) still reach the Dart event listener.
- **macOS:** Confirm Sparkle-based updates still work (no code changes, but
  verify no regressions from the `dependency_overrides`).

## Risks and Mitigations

| Risk | Mitigation |
|------|------------|
| Missing upstream fixes | Plugin shows low maintenance activity; risk is minimal |
| WinSparkle binary compatibility | Vendored 0.8.1 is stable; no change to binaries |
| Queue memory growth if platform thread stalls | WinSparkle fires at most a few events per check; queue stays tiny |
| ARM64 Windows support | WinSparkle ARM64 binaries are included; CMakeLists.txt may need an arch check if ARM64 builds are added later |
