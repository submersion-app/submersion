# Debug Log Viewer Design Spec

**Date:** 2026-03-27
**Status:** Draft

## Overview

Provide a hidden debug log viewer that allows users to access, browse, and
export application and dive computer transfer logs for developer debugging.
The feature is unlocked via an Easter egg gesture (long-press app version)
and provides a full log viewer with category/severity filtering, search, and
three export options (share, clipboard copy, save to file).

## Goals

- Enable users to send diagnostic logs to developers without requiring
  desktop tooling (logcat, Xcode Console, etc.)
- Capture bluetooth, serial, and libdivecomputer native logs alongside
  application-level logs in a single unified file
- Keep the feature hidden from casual users while easily discoverable by
  users following developer instructions
- Always-on logging so logs are available retroactively (no need to
  reproduce issues with logging enabled)

## Non-Goals

- Real-time log streaming to a remote server
- Crash reporting (handled separately by platform tooling)
- User-facing analytics or diagnostics dashboard

---

## Architecture

### Log Categories

| Category     | Enum Value   | Description                                          |
| ------------ | ------------ | ---------------------------------------------------- |
| App          | `app`        | General app lifecycle, navigation, errors             |
| Bluetooth    | `bluetooth`  | BLE scanning, connection, GATT operations, data transfer |
| Serial       | `serial`     | Serial device discovery and communication             |
| libdivecomputer | `libdc`   | Native library diagnostic output (parsing, protocols) |
| Database     | `database`   | Drift queries, migrations, storage operations         |

### Log Severity Levels

Debug, Info, Warning, Error (existing `LoggerService` levels).

---

## Section 1: LoggerService Enhancement

The existing `LoggerService` (`lib/core/services/logger_service.dart`) is
enhanced to write to a persistent rolling log file.

### File Location

`<appSupportDir>/logs/submersion.log` — uses `getApplicationSupportDirectory()`
so logs are in a platform-appropriate, non-user-facing location.

### Log Format

Each line follows this structured format:

```
[2026-03-27T14:32:01.123] [BLE] [INFO] Connected to Shearwater Perdix AI
```

Fields: ISO 8601 timestamp, category tag, severity level, message text.

### Rotation

Before each write, the file size is checked. When it exceeds 5MB, the file
is truncated by keeping the last ~2.5MB (read tail bytes, overwrite file).
This happens infrequently so performance impact is negligible.

### API Changes

The current `LoggerService` methods (`debug()`, `info()`, `warning()`,
`error()`) gain a required `category` parameter of type `LogCategory` enum.
Existing call sites are updated to use `LogCategory.app` as the default.

### Always-On

File logging is always active regardless of whether debug mode is unlocked
in the UI. The Easter egg controls only the visibility of the debug UI
section — logs are always being captured so they are available retroactively
when a user needs to report an issue.

---

## Section 2: Native Log Piping

Native platform code (Android/Kotlin and iOS-macOS/Swift) pipes log messages
back to Dart through the existing Pigeon platform channel infrastructure.

### Pigeon API Addition

A new method on the existing `DiveComputerFlutterApi`:

```dart
@FlutterApi()
abstract class DiveComputerFlutterApi {
  // ... existing methods ...
  void onLogEvent(String category, String level, String message);
}
```

### Android (Kotlin)

A lightweight `NativeLogger` object holds a reference to the `FlutterApi`
and provides simple logging methods. Existing `Log.d()`, `Log.e()`, and
`Log.w()` calls in `BleIoStream.kt`, `BleScanner.kt`, and
`DiveComputerHostApiImpl.kt` are replaced with calls through this logger.
The native logger also falls back to `Log.d()` so logs continue to appear
in logcat.

### iOS/macOS (Swift)

Same pattern — a `NativeLogger` class that forwards to the Flutter API.
Replaces `print()` calls in `BleIoStream.swift`, `SerialIoStream.swift`,
`BleScanner.swift`, `SerialScanner.swift`, and the libdc wrapper code.

### libdivecomputer Specifically

The C library supports `dc_context_set_loglevel()` and a log callback
mechanism. The native wrapper code sets this callback and routes
libdivecomputer's internal diagnostic output through the same
NativeLogger -> Flutter API -> LoggerService pipeline with category `libdc`.

### Dart Side

The `DiveComputerFlutterApi` implementation receives `onLogEvent` calls and
forwards them to `LoggerService.log()` with the appropriate `LogCategory`
and severity level.

---

## Section 3: Debug Mode Activation & Persistence

### Easter Egg Trigger

On the existing About section in Settings (`SettingsAboutContent`), the app
version text gets a `GestureDetector` with `onLongPress`. A counter
increments on each long-press. After 5 long-presses, debug mode activates
and a snackbar displays: "Debug mode enabled."

### Persistence

A `debugModeEnabled` boolean stored via `SharedPreferences`. Once unlocked,
it stays unlocked across app restarts until the user explicitly disables it
from the debug screen.

### Settings UI Integration

When `debugModeEnabled` is true, a new "Debug" section appears in the
settings list, positioned just above the "About" section (the last section).
It has a single entry point: "Debug Logs" which navigates to the log viewer
screen.

### Riverpod State

A `debugModeProvider` (`StateProvider<bool>`) reads from `SharedPreferences`
on init. The settings list widget watches this provider to conditionally
render the Debug section.

### Deactivation

The debug log viewer screen includes a "Disable Debug Mode" option in its
app bar overflow menu, which clears the preference and hides the Debug
section.

---

## Section 4: Debug Log Viewer Screen

### Route

`/settings/debug-logs` — added to the existing settings navigation in
go_router.

### Layout

A full-screen page with three main parts:

#### App Bar

- Title: "Debug Logs"
- Overflow menu with: "Disable Debug Mode", "Clear Logs"

#### Filter Bar

Positioned below the app bar:

- **Category chips:** Horizontally scrollable `FilterChip` row — App,
  Bluetooth, Serial, libdc, Database. Multiple can be active simultaneously.
  All active by default.
- **Severity dropdown:** A `DropdownButton` with options: All, Debug, Info,
  Warning, Error. Selecting a level shows that level and above (e.g.,
  selecting "Warning" shows Warning + Error).
- **Search field:** A collapsible search bar (icon in app bar) for free-text
  search across log messages.

#### Log List

- `ListView.builder` displaying filtered log entries in reverse
  chronological order (newest first)
- Each entry shows: timestamp, category tag (color-coded), severity icon,
  and message text
- Monospaced font for readability
- Entries are parsed from the log file on screen open, held in memory, and
  filtered reactively

#### Bottom Action Bar

Three buttons in a row:

- **Share** — packages the full (unfiltered) log file and opens the system
  share sheet via `share_plus`
- **Copy** — copies the currently filtered view to clipboard (allows
  grabbing just BLE logs, for example)
- **Save** — opens file picker to save the full log file to a user-chosen
  location

### Performance

The log file is read once on screen open and parsed into a
`List<LogEntry>` in an isolate to avoid UI jank. The filtered view is a
computed subset of the in-memory list. At 5MB max file size, this is roughly
20-30k lines — manageable in memory.

---

## Data Model

### LogEntry (in-memory, parsed from file)

```dart
class LogEntry {
  final DateTime timestamp;
  final LogCategory category;
  final LogLevel level;
  final String message;
}
```

### LogCategory Enum

```dart
enum LogCategory {
  app,
  bluetooth,
  serial,
  libdc,
  database,
}
```

---

## Files to Create/Modify

### New Files

| File | Purpose |
| ---- | ------- |
| `lib/core/services/log_file_service.dart` | File I/O, rotation, parsing logic |
| `lib/core/models/log_entry.dart` | `LogEntry` class and `LogCategory` enum |
| `lib/features/settings/presentation/pages/debug_log_viewer_page.dart` | Main viewer screen |
| `lib/features/settings/presentation/widgets/log_filter_bar.dart` | Category chips, severity dropdown |
| `lib/features/settings/presentation/widgets/log_entry_tile.dart` | Individual log entry widget |
| `lib/features/settings/presentation/providers/debug_mode_provider.dart` | Debug mode state |
| `lib/features/settings/presentation/providers/debug_log_provider.dart` | Log data loading and filtering state |

### Modified Files

| File | Change |
| ---- | ------ |
| `lib/core/services/logger_service.dart` | Add file writing, category parameter |
| `packages/libdivecomputer_plugin/pigeons/dive_computer_api.dart` | Add `onLogEvent` to FlutterApi |
| `packages/libdivecomputer_plugin/android/.../DiveComputerHostApiImpl.kt` | NativeLogger, replace Log.d() calls |
| `packages/libdivecomputer_plugin/android/.../BleIoStream.kt` | Route logs through NativeLogger |
| `packages/libdivecomputer_plugin/android/.../BleScanner.kt` | Route logs through NativeLogger |
| `packages/libdivecomputer_plugin/ios/.../BleIoStream.swift` | Route logs through NativeLogger |
| `packages/libdivecomputer_plugin/ios/.../BleScanner.swift` | Route logs through NativeLogger |
| `packages/libdivecomputer_plugin/ios/.../SerialIoStream.swift` | Route logs through NativeLogger |
| `packages/libdivecomputer_plugin/ios/.../SerialScanner.swift` | Route logs through NativeLogger |
| `packages/libdivecomputer_plugin/macos/Classes/libdc_wrapper.c` | Add libdc log callback routing |
| `packages/libdivecomputer_plugin/macos/Classes/libdc_download.c` | Add logging to download operations |
| `packages/libdivecomputer_plugin/android/src/main/cpp/libdc_jni.cpp` | Add libdc log callback (Android JNI) |
| `lib/features/settings/presentation/widgets/settings_list_content.dart` | Add Debug section |
| `lib/features/settings/presentation/widgets/settings_about_content.dart` | Add Easter egg gesture |
| `lib/app.dart` (or router file) | Add `/settings/debug-logs` route |
| `lib/main.dart` | Initialize LogFileService on startup |

---

## Testing Strategy

### Unit Tests

- `LogFileService`: write, read, rotation at 5MB boundary, log line parsing
- `LogEntry` parsing: valid lines, malformed lines, edge cases
- `LogCategory` and severity filtering logic
- Debug mode provider: enable, disable, persistence

### Widget Tests

- Easter egg activation: verify 5 long-presses triggers debug mode
- Debug section visibility: shown when enabled, hidden when disabled
- Filter bar: category chip toggling, severity dropdown selection
- Log list: correct filtering, reverse chronological order
- Export buttons: verify share/copy/save actions are triggered

### Integration Tests

- Full flow: unlock debug mode -> view logs -> filter -> export
- Native log piping: verify native log events appear in the log file
