# Debug Log Viewer Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a hidden debug log viewer that captures application, BLE, serial, and libdivecomputer logs to a rolling file, with a full viewer UI accessible via an Easter egg in Settings.

**Architecture:** Enhance the existing `LoggerService` to write structured log lines to a rolling 5MB file. Native platform code (Kotlin/Swift) pipes logs back to Dart via a new Pigeon `onLogEvent` callback. A hidden debug mode (unlocked via long-press on app version) reveals a log viewer screen with category/severity filtering, search, and share/copy/save export options.

**Tech Stack:** Flutter, Riverpod, Pigeon (platform channels), Drift (SharedPreferences for debug mode), go_router, share_plus, file_picker, path_provider

**Spec:** `docs/superpowers/specs/2026-03-27-debug-log-viewer-design.md`

---

## File Structure

### New Files

| File | Responsibility |
| ---- | -------------- |
| `lib/core/models/log_entry.dart` | `LogCategory` enum, `LogLevel` enum, `LogEntry` data class with parsing |
| `lib/core/services/log_file_service.dart` | File I/O: write lines, rotation, read & parse log file |
| `lib/features/settings/presentation/providers/debug_mode_provider.dart` | Debug mode toggle backed by SharedPreferences |
| `lib/features/settings/presentation/providers/debug_log_providers.dart` | Log data loading, filtering state, export actions |
| `lib/features/settings/presentation/pages/debug_log_viewer_page.dart` | Full viewer screen with filter bar, log list, action bar |
| `lib/features/settings/presentation/widgets/log_filter_bar.dart` | Category chips + severity dropdown + search |
| `lib/features/settings/presentation/widgets/log_entry_tile.dart` | Single log entry row widget |
| `test/core/models/log_entry_test.dart` | Unit tests for LogEntry parsing |
| `test/core/services/log_file_service_test.dart` | Unit tests for LogFileService |
| `test/features/settings/presentation/providers/debug_mode_provider_test.dart` | Unit tests for debug mode provider |

### Modified Files

| File | Change |
| ---- | ------ |
| `lib/core/services/logger_service.dart` | Add `LogCategory` param, file writing via `LogFileService` |
| `lib/main.dart` | Initialize `LogFileService` at startup, pass to `LoggerService` |
| `lib/features/settings/presentation/pages/settings_page.dart` | Add Easter egg to `_AboutSectionContent`, add Debug section |
| `lib/features/settings/presentation/widgets/settings_list_content.dart` | Add debug section entry to settings list |
| `lib/core/router/app_router.dart` | Add `/settings/debug-logs` route |
| `packages/libdivecomputer_plugin/pigeons/dive_computer_api.dart` | Add `onLogEvent` to `DiveComputerFlutterApi` |
| `packages/libdivecomputer_plugin/lib/src/dive_computer_service.dart` | Implement `onLogEvent` callback, add log event stream |

---

## Task 1: LogEntry Data Model

**Files:**
- Create: `lib/core/models/log_entry.dart`
- Create: `test/core/models/log_entry_test.dart`

- [ ] **Step 1: Write failing tests for LogEntry parsing**

Create `test/core/models/log_entry_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/models/log_entry.dart';

void main() {
  group('LogCategory', () {
    test('tag returns correct short tag', () {
      expect(LogCategory.app.tag, 'APP');
      expect(LogCategory.bluetooth.tag, 'BLE');
      expect(LogCategory.serial.tag, 'SER');
      expect(LogCategory.libdc.tag, 'LDC');
      expect(LogCategory.database.tag, 'DB');
    });

    test('fromTag parses known tags', () {
      expect(LogCategory.fromTag('APP'), LogCategory.app);
      expect(LogCategory.fromTag('BLE'), LogCategory.bluetooth);
      expect(LogCategory.fromTag('SER'), LogCategory.serial);
      expect(LogCategory.fromTag('LDC'), LogCategory.libdc);
      expect(LogCategory.fromTag('DB'), LogCategory.database);
    });

    test('fromTag returns null for unknown tags', () {
      expect(LogCategory.fromTag('UNKNOWN'), isNull);
      expect(LogCategory.fromTag(''), isNull);
    });
  });

  group('LogLevel', () {
    test('tag returns correct tag', () {
      expect(LogLevel.debug.tag, 'DEBUG');
      expect(LogLevel.info.tag, 'INFO');
      expect(LogLevel.warning.tag, 'WARN');
      expect(LogLevel.error.tag, 'ERROR');
    });

    test('fromTag parses known tags', () {
      expect(LogLevel.fromTag('DEBUG'), LogLevel.debug);
      expect(LogLevel.fromTag('INFO'), LogLevel.info);
      expect(LogLevel.fromTag('WARN'), LogLevel.warning);
      expect(LogLevel.fromTag('ERROR'), LogLevel.error);
    });

    test('fromTag returns null for unknown tags', () {
      expect(LogLevel.fromTag('TRACE'), isNull);
    });

    test('severity ordering', () {
      expect(LogLevel.debug.index < LogLevel.info.index, isTrue);
      expect(LogLevel.info.index < LogLevel.warning.index, isTrue);
      expect(LogLevel.warning.index < LogLevel.error.index, isTrue);
    });
  });

  group('LogEntry', () {
    test('formats to structured log line', () {
      final entry = LogEntry(
        timestamp: DateTime(2026, 3, 27, 14, 32, 1, 123),
        category: LogCategory.bluetooth,
        level: LogLevel.info,
        message: 'Connected to Shearwater Perdix',
      );

      expect(
        entry.toLogLine(),
        '[2026-03-27T14:32:01.123] [BLE] [INFO] Connected to Shearwater Perdix',
      );
    });

    test('parses valid log line', () {
      const line =
          '[2026-03-27T14:32:01.123] [BLE] [INFO] Connected to Shearwater Perdix';
      final entry = LogEntry.tryParse(line);

      expect(entry, isNotNull);
      expect(entry!.category, LogCategory.bluetooth);
      expect(entry.level, LogLevel.info);
      expect(entry.message, 'Connected to Shearwater Perdix');
      expect(entry.timestamp.year, 2026);
      expect(entry.timestamp.month, 3);
      expect(entry.timestamp.day, 27);
      expect(entry.timestamp.hour, 14);
      expect(entry.timestamp.minute, 32);
      expect(entry.timestamp.second, 1);
      expect(entry.timestamp.millisecond, 123);
    });

    test('parses log line with brackets in message', () {
      const line =
          '[2026-03-27T10:00:00.000] [APP] [ERROR] Failed [code=42] something';
      final entry = LogEntry.tryParse(line);

      expect(entry, isNotNull);
      expect(entry!.category, LogCategory.app);
      expect(entry.level, LogLevel.error);
      expect(entry.message, 'Failed [code=42] something');
    });

    test('returns null for malformed lines', () {
      expect(LogEntry.tryParse(''), isNull);
      expect(LogEntry.tryParse('not a log line'), isNull);
      expect(LogEntry.tryParse('[bad timestamp] [APP] [INFO] msg'), isNull);
    });

    test('returns null for unknown category', () {
      expect(
        LogEntry.tryParse('[2026-03-27T10:00:00.000] [XXX] [INFO] msg'),
        isNull,
      );
    });

    test('returns null for unknown level', () {
      expect(
        LogEntry.tryParse('[2026-03-27T10:00:00.000] [APP] [TRACE] msg'),
        isNull,
      );
    });
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/core/models/log_entry_test.dart`
Expected: FAIL — `log_entry.dart` does not exist yet.

- [ ] **Step 3: Implement LogEntry, LogCategory, LogLevel**

Create `lib/core/models/log_entry.dart`:

```dart
/// Log categories for classifying log entries by source.
enum LogCategory {
  app('APP', 'App'),
  bluetooth('BLE', 'Bluetooth'),
  serial('SER', 'Serial'),
  libdc('LDC', 'libdc'),
  database('DB', 'Database');

  final String tag;
  final String displayName;

  const LogCategory(this.tag, this.displayName);

  /// Parse a tag string back to a LogCategory, or null if unknown.
  static LogCategory? fromTag(String tag) {
    for (final category in values) {
      if (category.tag == tag) return category;
    }
    return null;
  }
}

/// Log severity levels, ordered from least to most severe.
enum LogLevel {
  debug('DEBUG'),
  info('INFO'),
  warning('WARN'),
  error('ERROR');

  final String tag;

  const LogLevel(this.tag);

  /// Parse a tag string back to a LogLevel, or null if unknown.
  static LogLevel? fromTag(String tag) {
    for (final level in values) {
      if (level.tag == tag) return level;
    }
    return null;
  }
}

/// A single parsed log entry from the log file.
class LogEntry {
  final DateTime timestamp;
  final LogCategory category;
  final LogLevel level;
  final String message;

  const LogEntry({
    required this.timestamp,
    required this.category,
    required this.level,
    required this.message,
  });

  /// Format: [2026-03-27T14:32:01.123] [BLE] [INFO] Connected to device
  static final _logLineRegExp = RegExp(
    r'^\[(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3})\] '
    r'\[([A-Z]+)\] '
    r'\[([A-Z]+)\] '
    r'(.+)$',
  );

  /// Format this entry as a structured log line for file output.
  String toLogLine() {
    final ts = timestamp.toIso8601String().substring(0, 23);
    return '[$ts] [${category.tag}] [${level.tag}] $message';
  }

  /// Try to parse a log line. Returns null if the line is malformed.
  static LogEntry? tryParse(String line) {
    final match = _logLineRegExp.firstMatch(line);
    if (match == null) return null;

    final timestamp = DateTime.tryParse(match.group(1)!);
    if (timestamp == null) return null;

    final category = LogCategory.fromTag(match.group(2)!);
    if (category == null) return null;

    final level = LogLevel.fromTag(match.group(3)!);
    if (level == null) return null;

    return LogEntry(
      timestamp: timestamp,
      category: category,
      level: level,
      message: match.group(4)!,
    );
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/core/models/log_entry_test.dart`
Expected: All tests PASS.

- [ ] **Step 5: Format and commit**

```bash
dart format lib/core/models/log_entry.dart test/core/models/log_entry_test.dart
git add lib/core/models/log_entry.dart test/core/models/log_entry_test.dart
git commit -m "feat: add LogEntry, LogCategory, LogLevel data models with parsing"
```

---

## Task 2: LogFileService — File I/O and Rotation

**Files:**
- Create: `lib/core/services/log_file_service.dart`
- Create: `test/core/services/log_file_service_test.dart`

**Context:** This service handles writing log lines to a file, rotating when the file exceeds 5MB, and reading/parsing the file back into `LogEntry` objects.

- [ ] **Step 1: Write failing tests for LogFileService**

Create `test/core/services/log_file_service_test.dart`:

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/models/log_entry.dart';
import 'package:submersion/core/services/log_file_service.dart';

void main() {
  late Directory tempDir;
  late LogFileService service;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('log_file_service_test_');
    service = LogFileService(logDirectory: tempDir.path);
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  group('LogFileService', () {
    test('writeLine creates log file and appends line', () async {
      await service.initialize();

      final entry = LogEntry(
        timestamp: DateTime(2026, 3, 27, 14, 0, 0, 0),
        category: LogCategory.bluetooth,
        level: LogLevel.info,
        message: 'Test message',
      );
      await service.writeLine(entry.toLogLine());

      final logFile = File('${tempDir.path}/submersion.log');
      expect(logFile.existsSync(), isTrue);

      final content = await logFile.readAsString();
      expect(content, contains('[BLE] [INFO] Test message'));
    });

    test('writeLine appends multiple lines', () async {
      await service.initialize();

      await service.writeLine(
        LogEntry(
          timestamp: DateTime(2026, 3, 27, 14, 0, 0, 0),
          category: LogCategory.app,
          level: LogLevel.info,
          message: 'First',
        ).toLogLine(),
      );
      await service.writeLine(
        LogEntry(
          timestamp: DateTime(2026, 3, 27, 14, 0, 1, 0),
          category: LogCategory.app,
          level: LogLevel.debug,
          message: 'Second',
        ).toLogLine(),
      );

      final lines = await File(
        '${tempDir.path}/submersion.log',
      ).readAsLines();
      expect(lines.length, 2);
      expect(lines[0], contains('First'));
      expect(lines[1], contains('Second'));
    });

    test('readEntries parses all valid entries', () async {
      await service.initialize();

      await service.writeLine(
        LogEntry(
          timestamp: DateTime(2026, 3, 27, 14, 0, 0, 0),
          category: LogCategory.bluetooth,
          level: LogLevel.info,
          message: 'BLE message',
        ).toLogLine(),
      );
      await service.writeLine(
        LogEntry(
          timestamp: DateTime(2026, 3, 27, 14, 0, 1, 0),
          category: LogCategory.database,
          level: LogLevel.error,
          message: 'DB error',
        ).toLogLine(),
      );

      final entries = await service.readEntries();
      expect(entries.length, 2);
      expect(entries[0].category, LogCategory.bluetooth);
      expect(entries[1].category, LogCategory.database);
    });

    test('readEntries skips malformed lines', () async {
      await service.initialize();

      final logFile = File('${tempDir.path}/submersion.log');
      await logFile.writeAsString(
        '[2026-03-27T14:00:00.000] [BLE] [INFO] Good line\n'
        'this is garbage\n'
        '[2026-03-27T14:00:01.000] [APP] [WARN] Also good\n',
      );

      final entries = await service.readEntries();
      expect(entries.length, 2);
      expect(entries[0].message, 'Good line');
      expect(entries[1].message, 'Also good');
    });

    test('readEntries returns empty list when no log file', () async {
      await service.initialize();
      final entries = await service.readEntries();
      expect(entries, isEmpty);
    });

    test('clearLog deletes log file', () async {
      await service.initialize();

      await service.writeLine(
        LogEntry(
          timestamp: DateTime(2026, 3, 27, 14, 0, 0, 0),
          category: LogCategory.app,
          level: LogLevel.info,
          message: 'Test',
        ).toLogLine(),
      );

      await service.clearLog();

      final logFile = File('${tempDir.path}/submersion.log');
      expect(logFile.existsSync(), isFalse);
    });

    test('logFilePath returns correct path', () async {
      await service.initialize();
      expect(service.logFilePath, '${tempDir.path}/submersion.log');
    });

    test('rotates file when exceeding max size', () async {
      // Use a tiny max size for testing
      final smallService = LogFileService(
        logDirectory: tempDir.path,
        maxFileSizeBytes: 200,
      );
      await smallService.initialize();

      // Write enough to exceed 200 bytes
      for (var i = 0; i < 20; i++) {
        await smallService.writeLine(
          LogEntry(
            timestamp: DateTime(2026, 3, 27, 14, 0, i, 0),
            category: LogCategory.app,
            level: LogLevel.info,
            message: 'Log message number $i with some padding text',
          ).toLogLine(),
        );
      }

      final logFile = File('${tempDir.path}/submersion.log');
      final size = await logFile.length();

      // After rotation, file should be roughly half of max or less
      // (it keeps the tail ~50% of max)
      expect(size, lessThan(200));

      // Should still contain the most recent entries
      final content = await logFile.readAsString();
      expect(content, contains('number 19'));
    });
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/core/services/log_file_service_test.dart`
Expected: FAIL — `log_file_service.dart` does not exist yet.

- [ ] **Step 3: Implement LogFileService**

Create `lib/core/services/log_file_service.dart`:

```dart
import 'dart:io';

import 'package:submersion/core/models/log_entry.dart';

/// Service for writing, reading, and rotating the application log file.
///
/// Writes structured log lines to `<logDirectory>/submersion.log`.
/// When the file exceeds [maxFileSizeBytes], it is rotated by keeping
/// the most recent ~50% of the content.
class LogFileService {
  final String logDirectory;
  final int maxFileSizeBytes;

  static const _logFileName = 'submersion.log';
  static const _defaultMaxSize = 5 * 1024 * 1024; // 5MB

  late final String _logFilePath;
  IOSink? _sink;

  LogFileService({
    required this.logDirectory,
    this.maxFileSizeBytes = _defaultMaxSize,
  });

  String get logFilePath => _logFilePath;

  /// Initialize the service, creating the log directory if needed.
  Future<void> initialize() async {
    _logFilePath = '$logDirectory/$_logFileName';
    final dir = Directory(logDirectory);
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }
  }

  /// Write a formatted log line to the file.
  Future<void> writeLine(String line) async {
    final file = File(_logFilePath);
    await file.writeAsString('$line\n', mode: FileMode.append);
    await _rotateIfNeeded();
  }

  /// Read and parse all valid log entries from the file.
  Future<List<LogEntry>> readEntries() async {
    final file = File(_logFilePath);
    if (!file.existsSync()) return [];

    final lines = await file.readAsLines();
    final entries = <LogEntry>[];
    for (final line in lines) {
      final entry = LogEntry.tryParse(line);
      if (entry != null) {
        entries.add(entry);
      }
    }
    return entries;
  }

  /// Delete the log file.
  Future<void> clearLog() async {
    final file = File(_logFilePath);
    if (file.existsSync()) {
      await file.delete();
    }
  }

  /// Check file size and rotate if it exceeds the max.
  /// Rotation keeps the last ~50% of the file content.
  Future<void> _rotateIfNeeded() async {
    final file = File(_logFilePath);
    if (!file.existsSync()) return;

    final size = await file.length();
    if (size <= maxFileSizeBytes) return;

    final content = await file.readAsString();
    final keepFrom = content.length ~/ 2;

    // Find the next newline after the midpoint so we don't split a line
    final nextNewline = content.indexOf('\n', keepFrom);
    if (nextNewline == -1) return;

    final tail = content.substring(nextNewline + 1);
    await file.writeAsString(tail);
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/core/services/log_file_service_test.dart`
Expected: All tests PASS.

- [ ] **Step 5: Format and commit**

```bash
dart format lib/core/services/log_file_service.dart test/core/services/log_file_service_test.dart
git add lib/core/services/log_file_service.dart test/core/services/log_file_service_test.dart
git commit -m "feat: add LogFileService with file I/O and rotation"
```

---

## Task 3: Enhance LoggerService with File Writing

**Files:**
- Modify: `lib/core/services/logger_service.dart`

**Context:** The existing `LoggerService` is a simple wrapper around `dart:developer.log`. It currently takes a `_name` string at construction (e.g., `LoggerService.forClass(DiveRepository)`). We need to:
1. Add a `LogCategory` parameter to each log method
2. Write each log call to `LogFileService` in addition to `developer.log`
3. Keep the constructor simple — `LogFileService` is set as a static singleton after initialization

- [ ] **Step 1: Update LoggerService to accept category and write to file**

Replace the contents of `lib/core/services/logger_service.dart` with:

```dart
import 'dart:developer' as developer;

import 'package:submersion/core/models/log_entry.dart';
import 'package:submersion/core/services/log_file_service.dart';

/// Simple logging service for the application.
/// Uses Dart's developer.log for structured logging and writes to a
/// persistent log file via [LogFileService].
class LoggerService {
  final String _name;

  /// The shared LogFileService instance. Set during app initialization.
  static LogFileService? _fileService;

  /// Initialize the file logging backend. Call once at app startup.
  static void setFileService(LogFileService fileService) {
    _fileService = fileService;
  }

  const LoggerService(this._name);

  /// Log a debug message
  void debug(
    String message, {
    LogCategory category = LogCategory.app,
    Object? error,
    StackTrace? stackTrace,
  }) {
    _log(message, category: category, level: LogLevel.debug,
        developerLevel: 500, error: error, stackTrace: stackTrace);
  }

  /// Log an info message
  void info(
    String message, {
    LogCategory category = LogCategory.app,
    Object? error,
    StackTrace? stackTrace,
  }) {
    _log(message, category: category, level: LogLevel.info,
        developerLevel: 800, error: error, stackTrace: stackTrace);
  }

  /// Log a warning message
  void warning(
    String message, {
    LogCategory category = LogCategory.app,
    Object? error,
    StackTrace? stackTrace,
  }) {
    _log(message, category: category, level: LogLevel.warning,
        developerLevel: 900, error: error, stackTrace: stackTrace);
  }

  /// Log an error message
  void error(
    String message, {
    LogCategory category = LogCategory.app,
    Object? error,
    StackTrace? stackTrace,
  }) {
    _log(message, category: category, level: LogLevel.error,
        developerLevel: 1000, error: error, stackTrace: stackTrace);
  }

  void _log(
    String message, {
    required LogCategory category,
    required LogLevel level,
    required int developerLevel,
    Object? error,
    StackTrace? stackTrace,
  }) {
    // Console logging via dart:developer
    developer.log(
      message,
      name: _name,
      level: developerLevel,
      error: error,
      stackTrace: stackTrace,
    );

    // File logging
    final entry = LogEntry(
      timestamp: DateTime.now(),
      category: category,
      level: level,
      message: error != null ? '$message | error: $error' : message,
    );
    _fileService?.writeLine(entry.toLogLine());
  }

  /// Create a logger for a specific class
  static LoggerService forClass(Type type) => LoggerService(type.toString());
}

/// Custom exception for repository errors
class RepositoryException implements Exception {
  final String message;
  final String operation;
  final Object? originalError;
  final StackTrace? stackTrace;

  RepositoryException({
    required this.message,
    required this.operation,
    this.originalError,
    this.stackTrace,
  });

  @override
  String toString() => 'RepositoryException: $message (operation: $operation)';
}
```

**Key changes:**
- `debug()`, `info()`, `warning()`, `error()` now use named params: `category`, `error`, `stackTrace` instead of positional. The `category` param defaults to `LogCategory.app` so existing callers continue to compile.
- Static `_fileService` set once during startup.
- Each log call writes to both `developer.log` and the log file.

- [ ] **Step 2: Fix existing call sites that use positional error/stackTrace params**

The existing `LoggerService` accepted `error` and `stackTrace` as positional params. Now they are named. Search for callers and update them. The pattern to find is `_log.error('message', e, stack)` or `_log.warning('message', e)` — these become `_log.error('message', error: e, stackTrace: stack)` and `_log.warning('message', error: e)`.

Run: `grep -rn "_log\.\(debug\|info\|warning\|error\)('" lib/ --include="*.dart" | grep -v "category:" | head -40`

Update each call site. For example in a repository file:
- Before: `_log.error('Failed to fetch dives', e, stack);`
- After: `_log.error('Failed to fetch dives', error: e, stackTrace: stack);`

- [ ] **Step 3: Run full test suite to verify nothing is broken**

Run: `flutter test`
Expected: All existing tests PASS. The default `category: LogCategory.app` means no existing test needs to specify a category.

- [ ] **Step 4: Format and commit**

```bash
dart format lib/core/services/logger_service.dart
# Also format any call sites that were modified
dart format lib/
git add lib/core/services/logger_service.dart lib/
git commit -m "feat: enhance LoggerService with file writing and log categories"
```

---

## Task 4: Initialize LogFileService at App Startup

**Files:**
- Modify: `lib/main.dart`

**Context:** `LogFileService` needs to be initialized early in `main()` so that all log calls during startup are captured. It uses `getApplicationSupportDirectory()` from `path_provider` for the log directory.

- [ ] **Step 1: Add LogFileService initialization to main()**

In `lib/main.dart`, add the import and initialization right after `SharedPreferences.getInstance()` (line 24) and before any logging occurs:

Add import at the top:
```dart
import 'package:path_provider/path_provider.dart';
import 'package:submersion/core/services/log_file_service.dart';
import 'package:submersion/core/services/logger_service.dart';
```

After `final prefs = await SharedPreferences.getInstance();` (line 24), add:

```dart
  // Initialize log file service for persistent logging
  final appSupportDir = await getApplicationSupportDirectory();
  final logFileService = LogFileService(
    logDirectory: '${appSupportDir.path}/logs',
  );
  await logFileService.initialize();
  LoggerService.setFileService(logFileService);
```

- [ ] **Step 2: Run the app to verify startup works**

Run: `flutter run -d macos`
Expected: App starts normally. Check that `~/Library/Application Support/com.submersion.submersion/logs/submersion.log` gets created (exact path depends on your app bundle ID).

- [ ] **Step 3: Format and commit**

```bash
dart format lib/main.dart
git add lib/main.dart
git commit -m "feat: initialize LogFileService at app startup"
```

---

## Task 5: Debug Mode Provider

**Files:**
- Create: `lib/features/settings/presentation/providers/debug_mode_provider.dart`
- Create: `test/features/settings/presentation/providers/debug_mode_provider_test.dart`

- [ ] **Step 1: Write failing tests for debug mode provider**

Create `test/features/settings/presentation/providers/debug_mode_provider_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/features/settings/presentation/providers/debug_mode_provider.dart';

void main() {
  group('DebugModeNotifier', () {
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    test('initial state is false when no preference stored', () {
      final notifier = DebugModeNotifier(prefs);
      expect(notifier.state, isFalse);
    });

    test('initial state reads from SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({'debug_mode_enabled': true});
      prefs = await SharedPreferences.getInstance();
      final notifier = DebugModeNotifier(prefs);
      expect(notifier.state, isTrue);
    });

    test('enable() sets state to true and persists', () async {
      final notifier = DebugModeNotifier(prefs);
      await notifier.enable();
      expect(notifier.state, isTrue);
      expect(prefs.getBool('debug_mode_enabled'), isTrue);
    });

    test('disable() sets state to false and persists', () async {
      final notifier = DebugModeNotifier(prefs);
      await notifier.enable();
      await notifier.disable();
      expect(notifier.state, isFalse);
      expect(prefs.getBool('debug_mode_enabled'), isFalse);
    });
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/settings/presentation/providers/debug_mode_provider_test.dart`
Expected: FAIL — file does not exist.

- [ ] **Step 3: Implement DebugModeNotifier and provider**

Create `lib/features/settings/presentation/providers/debug_mode_provider.dart`:

```dart
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

const _kDebugModeKey = 'debug_mode_enabled';

/// Notifier that manages the debug mode toggle state.
/// Persists to SharedPreferences so debug mode survives app restarts.
class DebugModeNotifier extends StateNotifier<bool> {
  final SharedPreferences _prefs;

  DebugModeNotifier(this._prefs)
      : super(_prefs.getBool(_kDebugModeKey) ?? false);

  Future<void> enable() async {
    state = true;
    await _prefs.setBool(_kDebugModeKey, true);
  }

  Future<void> disable() async {
    state = false;
    await _prefs.setBool(_kDebugModeKey, false);
  }
}

/// Provider for the debug mode state.
final debugModeProvider =
    StateNotifierProvider<DebugModeNotifier, bool>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return DebugModeNotifier(prefs);
});
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/settings/presentation/providers/debug_mode_provider_test.dart`
Expected: All tests PASS.

- [ ] **Step 5: Format and commit**

```bash
dart format lib/features/settings/presentation/providers/debug_mode_provider.dart test/features/settings/presentation/providers/debug_mode_provider_test.dart
git add lib/features/settings/presentation/providers/debug_mode_provider.dart test/features/settings/presentation/providers/debug_mode_provider_test.dart
git commit -m "feat: add debug mode provider with SharedPreferences persistence"
```

---

## Task 6: Easter Egg in About Section

**Files:**
- Modify: `lib/features/settings/presentation/pages/settings_page.dart` (the `_AboutSectionContent` class, around line 2261)

**Context:** The `_AboutSectionContent` widget (line 2261 of `settings_page.dart`) is a `ConsumerWidget`. At the bottom of its `build()` method (around line 2327), it renders a centered column with the app icon and version string. We wrap the version `Text` widget in a `GestureDetector` with `onLongPress` to count long-presses. After 5 presses, it enables debug mode.

- [ ] **Step 1: Convert _AboutSectionContent from ConsumerWidget to ConsumerStatefulWidget**

This is needed to track the long-press counter. Change the class declaration and add state:

```dart
class _AboutSectionContent extends ConsumerStatefulWidget {
  const _AboutSectionContent();

  @override
  ConsumerState<_AboutSectionContent> createState() =>
      _AboutSectionContentState();
}

class _AboutSectionContentState extends ConsumerState<_AboutSectionContent> {
  int _longPressCount = 0;
```

Move the `build` method into `_AboutSectionContentState`, changing `Widget build(BuildContext context, WidgetRef ref)` to `Widget build(BuildContext context)`.

- [ ] **Step 2: Add Easter egg GestureDetector to the version text**

Find the version `Text` widget near line 2344 (the one that displays `versionString`). Wrap it in a `GestureDetector`:

```dart
GestureDetector(
  onLongPress: () {
    _longPressCount++;
    if (_longPressCount >= 5) {
      _longPressCount = 0;
      ref.read(debugModeProvider.notifier).enable();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Debug mode enabled'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  },
  child: Text(
    versionString,
    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    ),
  ),
),
```

Add the import at the top of the file:
```dart
import 'package:submersion/features/settings/presentation/providers/debug_mode_provider.dart';
```

- [ ] **Step 3: Run flutter analyze to check for issues**

Run: `flutter analyze lib/features/settings/presentation/pages/settings_page.dart`
Expected: No errors.

- [ ] **Step 4: Format and commit**

```bash
dart format lib/features/settings/presentation/pages/settings_page.dart
git add lib/features/settings/presentation/pages/settings_page.dart
git commit -m "feat: add Easter egg long-press on version to enable debug mode"
```

---

## Task 7: Debug Section in Settings List

**Files:**
- Modify: `lib/features/settings/presentation/widgets/settings_list_content.dart`
- Modify: `lib/features/settings/presentation/pages/settings_page.dart`

**Context:** The settings list is defined as a `const` list `settingsSections` in `settings_list_content.dart`. The `SettingsListContent` widget filters and renders them. We need to conditionally add a "Debug" section when debug mode is enabled. The settings_page.dart also has a switch/case for rendering section content — we need to add the debug case there too.

- [ ] **Step 1: Add debug section to settings_list_content.dart**

In `settings_list_content.dart`, the `SettingsListContent` widget's `build()` method filters `settingsSections` at line 106. Change the widget to a `ConsumerWidget` and conditionally add the debug section:

Add imports:
```dart
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/settings/presentation/providers/debug_mode_provider.dart';
```

Change `class SettingsListContent extends StatelessWidget` to `class SettingsListContent extends ConsumerWidget`.

Change `Widget build(BuildContext context)` to `Widget build(BuildContext context, WidgetRef ref)`.

After the existing filter (line 106-108), add the debug section conditionally:

```dart
    final debugEnabled = ref.watch(debugModeProvider);
    final sections = settingsSections
        .where((s) => s.id != 'dataSources' || Platform.isIOS)
        .toList();

    // Insert Debug section just before About when debug mode is enabled
    if (debugEnabled) {
      final aboutIndex = sections.indexWhere((s) => s.id == 'about');
      final insertIndex = aboutIndex >= 0 ? aboutIndex : sections.length;
      sections.insert(
        insertIndex,
        const SettingsSection(
          id: 'debug',
          icon: Icons.bug_report_outlined,
          title: 'Debug',
          subtitle: 'Logs & diagnostics',
          color: Colors.grey,
        ),
      );
    }
```

Also add localization cases for the debug section in `_getLocalizedTitle` and `_getLocalizedSubtitle`:

```dart
      case 'debug':
        return 'Debug';
```

```dart
      case 'debug':
        return 'Logs & diagnostics';
```

- [ ] **Step 2: Add debug section content in settings_page.dart**

In `settings_page.dart`, find the switch statement or mapping that maps section IDs to content widgets (search for `'about'` in a switch or map). Add:

```dart
case 'debug':
  return const DebugLogViewerPage();
```

Add the import (we will create this page in Task 9):
```dart
import 'package:submersion/features/settings/presentation/pages/debug_log_viewer_page.dart';
```

For now, create a placeholder so the app compiles. This will be replaced in Task 9.

- [ ] **Step 3: Run flutter analyze**

Run: `flutter analyze`
Expected: No errors (the debug log viewer page import may need a stub — see Task 9 step ordering).

- [ ] **Step 4: Format and commit**

```bash
dart format lib/features/settings/presentation/widgets/settings_list_content.dart lib/features/settings/presentation/pages/settings_page.dart
git add lib/features/settings/presentation/widgets/settings_list_content.dart lib/features/settings/presentation/pages/settings_page.dart
git commit -m "feat: add conditional Debug section to settings list"
```

---

## Task 8: Debug Log Providers

**Files:**
- Create: `lib/features/settings/presentation/providers/debug_log_providers.dart`

**Context:** These providers manage the log viewer state: loading entries from the file, filter state (selected categories, minimum severity, search query), and the filtered entry list.

- [ ] **Step 1: Create debug log providers**

Create `lib/features/settings/presentation/providers/debug_log_providers.dart`:

```dart
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:submersion/core/models/log_entry.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/log_file_service.dart';

/// Provider for the LogFileService singleton.
/// Must be overridden in ProviderScope with the initialized instance.
final logFileServiceProvider = Provider<LogFileService>((ref) {
  throw UnimplementedError(
    'LogFileService must be initialized before use',
  );
});

/// Provider that loads all log entries from the file.
final logEntriesProvider = FutureProvider<List<LogEntry>>((ref) async {
  final service = ref.watch(logFileServiceProvider);
  return service.readEntries();
});

/// Filter state for the log viewer.
class LogFilterState {
  final Set<LogCategory> activeCategories;
  final LogLevel minimumSeverity;
  final String searchQuery;

  const LogFilterState({
    this.activeCategories = const {
      LogCategory.app,
      LogCategory.bluetooth,
      LogCategory.serial,
      LogCategory.libdc,
      LogCategory.database,
    },
    this.minimumSeverity = LogLevel.debug,
    this.searchQuery = '',
  });

  LogFilterState copyWith({
    Set<LogCategory>? activeCategories,
    LogLevel? minimumSeverity,
    String? searchQuery,
  }) {
    return LogFilterState(
      activeCategories: activeCategories ?? this.activeCategories,
      minimumSeverity: minimumSeverity ?? this.minimumSeverity,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }
}

/// Provider for log filter state.
final logFilterProvider =
    StateNotifierProvider<LogFilterNotifier, LogFilterState>((ref) {
  return LogFilterNotifier();
});

class LogFilterNotifier extends StateNotifier<LogFilterState> {
  LogFilterNotifier() : super(const LogFilterState());

  void toggleCategory(LogCategory category) {
    final current = Set<LogCategory>.from(state.activeCategories);
    if (current.contains(category)) {
      // Don't allow deselecting all categories
      if (current.length > 1) {
        current.remove(category);
      }
    } else {
      current.add(category);
    }
    state = state.copyWith(activeCategories: current);
  }

  void setMinimumSeverity(LogLevel level) {
    state = state.copyWith(minimumSeverity: level);
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void resetFilters() {
    state = const LogFilterState();
  }
}

/// Provider for the filtered list of log entries (reverse chronological).
final filteredLogEntriesProvider = Provider<AsyncValue<List<LogEntry>>>((ref) {
  final entriesAsync = ref.watch(logEntriesProvider);
  final filter = ref.watch(logFilterProvider);

  return entriesAsync.whenData((entries) {
    final filtered = entries.where((entry) {
      if (!filter.activeCategories.contains(entry.category)) return false;
      if (entry.level.index < filter.minimumSeverity.index) return false;
      if (filter.searchQuery.isNotEmpty &&
          !entry.message
              .toLowerCase()
              .contains(filter.searchQuery.toLowerCase())) {
        return false;
      }
      return true;
    }).toList();

    // Reverse chronological order (newest first)
    return filtered.reversed.toList();
  });
});

/// Share the full log file via system share sheet.
Future<void> shareLogFile(LogFileService service) async {
  final path = service.logFilePath;
  final file = File(path);
  if (!file.existsSync()) return;

  await SharePlus.instance.share(
    ShareParams(
      files: [XFile(path, mimeType: 'text/plain')],
      subject: 'Submersion Debug Logs',
    ),
  );
}

/// Copy the filtered log entries to clipboard.
Future<void> copyFilteredLogs(List<LogEntry> entries) async {
  final text = entries.map((e) => e.toLogLine()).join('\n');
  await Clipboard.setData(ClipboardData(text: text));
}

/// Save the full log file to a user-chosen location.
Future<String?> saveLogFile(LogFileService service) async {
  final path = service.logFilePath;
  final file = File(path);
  if (!file.existsSync()) return null;

  final bytes = await file.readAsBytes();
  final result = await FilePicker.platform.saveFile(
    dialogTitle: 'Save Debug Logs',
    fileName: 'submersion-debug-logs.txt',
    type: FileType.custom,
    allowedExtensions: ['txt', 'log'],
    bytes: bytes,
  );

  if (result == null) return null;

  // On some platforms, saveFile returns a path but doesn't write
  if (!Platform.isAndroid) {
    final outFile = File(result);
    await outFile.writeAsBytes(bytes);
  }

  return result;
}
```

- [ ] **Step 2: Wire up logFileServiceProvider in main.dart**

In `lib/main.dart`, the `ProviderScope` overrides (line 213) already override `sharedPreferencesProvider`. Add the `logFileServiceProvider` override there too:

```dart
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            logFileServiceProvider.overrideWithValue(logFileService),
          ],
```

Add the import:
```dart
import 'package:submersion/features/settings/presentation/providers/debug_log_providers.dart';
```

- [ ] **Step 3: Run flutter analyze**

Run: `flutter analyze`
Expected: No errors.

- [ ] **Step 4: Format and commit**

```bash
dart format lib/features/settings/presentation/providers/debug_log_providers.dart lib/main.dart
git add lib/features/settings/presentation/providers/debug_log_providers.dart lib/main.dart
git commit -m "feat: add debug log providers with filtering and export actions"
```

---

## Task 9: Debug Log Viewer Page and Widgets

**Files:**
- Create: `lib/features/settings/presentation/pages/debug_log_viewer_page.dart`
- Create: `lib/features/settings/presentation/widgets/log_filter_bar.dart`
- Create: `lib/features/settings/presentation/widgets/log_entry_tile.dart`

- [ ] **Step 1: Create LogEntryTile widget**

Create `lib/features/settings/presentation/widgets/log_entry_tile.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:submersion/core/models/log_entry.dart';

/// A single log entry row in the debug log viewer.
class LogEntryTile extends StatelessWidget {
  final LogEntry entry;

  const LogEntryTile({super.key, required this.entry});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Severity icon
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(
              _severityIcon(entry.level),
              size: 14,
              color: _severityColor(entry.level, colorScheme),
            ),
          ),
          const SizedBox(width: 6),
          // Category tag
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: _categoryColor(entry.category).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(3),
            ),
            child: Text(
              entry.category.tag,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: _categoryColor(entry.category),
                fontFamily: 'monospace',
              ),
            ),
          ),
          const SizedBox(width: 6),
          // Timestamp
          Text(
            _formatTimestamp(entry.timestamp),
            style: TextStyle(
              fontSize: 11,
              color: colorScheme.onSurfaceVariant,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(width: 8),
          // Message
          Expanded(
            child: Text(
              entry.message,
              style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
            ),
          ),
        ],
      ),
    );
  }

  static String _formatTimestamp(DateTime ts) {
    return '${ts.hour.toString().padLeft(2, '0')}:'
        '${ts.minute.toString().padLeft(2, '0')}:'
        '${ts.second.toString().padLeft(2, '0')}.'
        '${ts.millisecond.toString().padLeft(3, '0')}';
  }

  static IconData _severityIcon(LogLevel level) {
    return switch (level) {
      LogLevel.debug => Icons.bug_report_outlined,
      LogLevel.info => Icons.info_outline,
      LogLevel.warning => Icons.warning_amber,
      LogLevel.error => Icons.error_outline,
    };
  }

  static Color _severityColor(LogLevel level, ColorScheme colorScheme) {
    return switch (level) {
      LogLevel.debug => colorScheme.onSurfaceVariant,
      LogLevel.info => Colors.blue,
      LogLevel.warning => Colors.orange,
      LogLevel.error => Colors.red,
    };
  }

  static Color _categoryColor(LogCategory category) {
    return switch (category) {
      LogCategory.app => Colors.blueGrey,
      LogCategory.bluetooth => Colors.indigo,
      LogCategory.serial => Colors.teal,
      LogCategory.libdc => Colors.deepPurple,
      LogCategory.database => Colors.green,
    };
  }
}
```

- [ ] **Step 2: Create LogFilterBar widget**

Create `lib/features/settings/presentation/widgets/log_filter_bar.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:submersion/core/models/log_entry.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/settings/presentation/providers/debug_log_providers.dart';

/// Filter bar with category chips, severity dropdown, displayed below the app bar.
class LogFilterBar extends ConsumerWidget {
  const LogFilterBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(logFilterProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Category filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: LogCategory.values.map((category) {
                final isActive =
                    filter.activeCategories.contains(category);
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: FilterChip(
                    label: Text(category.displayName),
                    selected: isActive,
                    onSelected: (_) {
                      ref
                          .read(logFilterProvider.notifier)
                          .toggleCategory(category);
                    },
                    visualDensity: VisualDensity.compact,
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),
          // Severity dropdown
          Row(
            children: [
              Text(
                'Min severity: ',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              DropdownButton<LogLevel>(
                value: filter.minimumSeverity,
                isDense: true,
                underline: const SizedBox.shrink(),
                items: LogLevel.values
                    .map(
                      (level) => DropdownMenuItem(
                        value: level,
                        child: Text(
                          level.tag,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (level) {
                  if (level != null) {
                    ref
                        .read(logFilterProvider.notifier)
                        .setMinimumSeverity(level);
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 3: Create DebugLogViewerPage**

Create `lib/features/settings/presentation/pages/debug_log_viewer_page.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:submersion/core/models/log_entry.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/settings/presentation/providers/debug_log_providers.dart';
import 'package:submersion/features/settings/presentation/providers/debug_mode_provider.dart';
import 'package:submersion/features/settings/presentation/widgets/log_entry_tile.dart';
import 'package:submersion/features/settings/presentation/widgets/log_filter_bar.dart';

/// Full-screen debug log viewer with filtering and export capabilities.
class DebugLogViewerPage extends ConsumerStatefulWidget {
  const DebugLogViewerPage({super.key});

  @override
  ConsumerState<DebugLogViewerPage> createState() =>
      _DebugLogViewerPageState();
}

class _DebugLogViewerPageState extends ConsumerState<DebugLogViewerPage> {
  bool _isSearching = false;
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filteredEntriesAsync = ref.watch(filteredLogEntriesProvider);

    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Search logs...',
                  border: InputBorder.none,
                ),
                onChanged: (query) {
                  ref
                      .read(logFilterProvider.notifier)
                      .setSearchQuery(query);
                },
              )
            : const Text('Debug Logs'),
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) {
                  _searchController.clear();
                  ref
                      .read(logFilterProvider.notifier)
                      .setSearchQuery('');
                }
              });
            },
          ),
          PopupMenuButton<String>(
            onSelected: (value) async {
              switch (value) {
                case 'disable':
                  ref.read(debugModeProvider.notifier).disable();
                  if (context.mounted) {
                    Navigator.of(context).pop();
                  }
                case 'clear':
                  await ref.read(logFileServiceProvider).clearLog();
                  ref.invalidate(logEntriesProvider);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'disable',
                child: Text('Disable Debug Mode'),
              ),
              const PopupMenuItem(
                value: 'clear',
                child: Text('Clear Logs'),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          const LogFilterBar(),
          const Divider(height: 1),
          Expanded(
            child: filteredEntriesAsync.when(
              data: (entries) {
                if (entries.isEmpty) {
                  return const Center(
                    child: Text('No log entries match the current filters'),
                  );
                }
                return ListView.builder(
                  itemCount: entries.length,
                  itemBuilder: (context, index) {
                    return LogEntryTile(entry: entries[index]);
                  },
                );
              },
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(
                child: Text('Error loading logs: $error'),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildActionBar(context, filteredEntriesAsync),
    );
  }

  Widget _buildActionBar(
    BuildContext context,
    AsyncValue<List<LogEntry>> filteredEntriesAsync,
  ) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () async {
                  final service = ref.read(logFileServiceProvider);
                  await shareLogFile(service);
                },
                icon: const Icon(Icons.share, size: 18),
                label: const Text('Share'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () async {
                  final entries = filteredEntriesAsync.valueOrNull;
                  if (entries != null && entries.isNotEmpty) {
                    await copyFilteredLogs(entries);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Filtered logs copied to clipboard'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    }
                  }
                },
                icon: const Icon(Icons.copy, size: 18),
                label: const Text('Copy'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () async {
                  final service = ref.read(logFileServiceProvider);
                  final path = await saveLogFile(service);
                  if (path != null && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Logs saved to $path'),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.save_alt, size: 18),
                label: const Text('Save'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run flutter analyze**

Run: `flutter analyze`
Expected: No errors.

- [ ] **Step 5: Format and commit**

```bash
dart format lib/features/settings/presentation/pages/debug_log_viewer_page.dart lib/features/settings/presentation/widgets/log_filter_bar.dart lib/features/settings/presentation/widgets/log_entry_tile.dart
git add lib/features/settings/presentation/pages/debug_log_viewer_page.dart lib/features/settings/presentation/widgets/log_filter_bar.dart lib/features/settings/presentation/widgets/log_entry_tile.dart
git commit -m "feat: add debug log viewer page with filter bar and log entry tiles"
```

---

## Task 10: Add Route for Debug Log Viewer

**Files:**
- Modify: `lib/core/router/app_router.dart`

**Context:** Settings child routes are defined starting at line 725 in `app_router.dart`. We add `/settings/debug-logs` as a new child route.

- [ ] **Step 1: Add debug-logs route**

In `lib/core/router/app_router.dart`, within the settings `routes: [...]` array (around line 725-811), add:

```dart
              GoRoute(
                path: 'debug-logs',
                name: 'debugLogs',
                builder: (context, state) => const DebugLogViewerPage(),
              ),
```

Add the import:
```dart
import 'package:submersion/features/settings/presentation/pages/debug_log_viewer_page.dart';
```

- [ ] **Step 2: Wire up navigation from settings list**

In `settings_page.dart`, the section content mapping needs to handle the `'debug'` section ID. Find where section IDs are mapped to content widgets and add the debug case. If navigation uses `context.go('/settings/debug-logs')`, add that to the `'debug'` section's `onTap` handler in the settings page.

Check how other sections navigate — some use direct widget rendering in a master-detail layout, others use `context.go()`. Follow the existing pattern.

- [ ] **Step 3: Run flutter analyze**

Run: `flutter analyze`
Expected: No errors.

- [ ] **Step 4: Format and commit**

```bash
dart format lib/core/router/app_router.dart lib/features/settings/presentation/pages/settings_page.dart
git add lib/core/router/app_router.dart lib/features/settings/presentation/pages/settings_page.dart
git commit -m "feat: add /settings/debug-logs route and wire up navigation"
```

---

## Task 11: Pigeon API — Add onLogEvent to FlutterApi

**Files:**
- Modify: `packages/libdivecomputer_plugin/pigeons/dive_computer_api.dart`
- Modify: `packages/libdivecomputer_plugin/lib/src/dive_computer_service.dart`

**Context:** The Pigeon definition at `pigeons/dive_computer_api.dart` defines the `DiveComputerFlutterApi` (line 209-222). After adding the new method, Pigeon codegen regenerates the platform channel bindings for Dart, Kotlin, and Swift.

- [ ] **Step 1: Add onLogEvent to the Pigeon definition**

In `packages/libdivecomputer_plugin/pigeons/dive_computer_api.dart`, add to `DiveComputerFlutterApi` (after `onPinCodeRequired`):

```dart
  void onLogEvent(String category, String level, String message);
```

- [ ] **Step 2: Run Pigeon codegen**

Run from the plugin directory:

```bash
cd packages/libdivecomputer_plugin && dart run pigeon --input pigeons/dive_computer_api.dart
```

This regenerates:
- `lib/src/generated/dive_computer_api.g.dart`
- `android/src/main/kotlin/.../DiveComputerApi.g.kt`
- `ios/Classes/DiveComputerApi.g.swift`
- `macos/Classes/DiveComputerApi.g.swift`

- [ ] **Step 3: Implement onLogEvent in DiveComputerService**

In `packages/libdivecomputer_plugin/lib/src/dive_computer_service.dart`, add:

A new stream controller and public stream:

```dart
  final _logEventsController =
      StreamController<({String category, String level, String message})>.broadcast();

  /// Stream of log events from native code.
  Stream<({String category, String level, String message})> get logEvents =>
      _logEventsController.stream;
```

The `onLogEvent` override:

```dart
  @override
  void onLogEvent(String category, String level, String message) {
    _logEventsController.add((
      category: category,
      level: level,
      message: message,
    ));
  }
```

Close the controller in `dispose()`:

```dart
    _logEventsController.close();
```

- [ ] **Step 4: Wire log events to LoggerService in the app**

In `lib/features/dive_computer/presentation/providers/discovery_providers.dart`, the `diveComputerServiceProvider` creates the service and calls `setUp`. After setUp, subscribe to `logEvents` and forward to `LoggerService`:

```dart
  service.logEvents.listen((event) {
    final category = LogCategory.fromTag(event.category);
    final level = LogLevel.fromTag(event.level);
    if (category != null && level != null) {
      const LoggerService('NativeLog')._log(
        event.message,
        category: category,
        level: level,
        developerLevel: 800,
      );
    }
  });
```

Note: Since `_log` is private, instead use the public methods. Create a simple helper or use the appropriate public method based on the level:

```dart
import 'package:submersion/core/models/log_entry.dart';
import 'package:submersion/core/services/logger_service.dart';

// In the provider:
  final nativeLog = const LoggerService('Native');
  service.logEvents.listen((event) {
    final category = LogCategory.fromTag(event.category);
    if (category == null) return;
    switch (event.level) {
      case 'DEBUG':
        nativeLog.debug(event.message, category: category);
      case 'INFO':
        nativeLog.info(event.message, category: category);
      case 'WARN':
        nativeLog.warning(event.message, category: category);
      case 'ERROR':
        nativeLog.error(event.message, category: category);
    }
  });
```

- [ ] **Step 5: Run flutter analyze**

Run: `flutter analyze`
Expected: No errors.

- [ ] **Step 6: Format and commit**

```bash
dart format packages/libdivecomputer_plugin/pigeons/dive_computer_api.dart packages/libdivecomputer_plugin/lib/src/dive_computer_service.dart lib/features/dive_computer/presentation/providers/discovery_providers.dart
git add packages/libdivecomputer_plugin/ lib/features/dive_computer/presentation/providers/discovery_providers.dart
git commit -m "feat: add onLogEvent Pigeon callback and wire native logs to LoggerService"
```

---

## Task 12: Android Native Logger

**Files:**
- Create: `packages/libdivecomputer_plugin/android/src/main/kotlin/com/submersion/libdivecomputer/NativeLogger.kt`
- Modify: `packages/libdivecomputer_plugin/android/src/main/kotlin/com/submersion/libdivecomputer/DiveComputerHostApiImpl.kt`
- Modify: `packages/libdivecomputer_plugin/android/src/main/kotlin/com/submersion/libdivecomputer/BleIoStream.kt`
- Modify: `packages/libdivecomputer_plugin/android/src/main/kotlin/com/submersion/libdivecomputer/BleScanner.kt`

**Context:** Replace Android `Log.d()` calls with a `NativeLogger` that both logs to logcat and sends the log event back to Flutter via the Pigeon `DiveComputerFlutterApi.onLogEvent()`.

- [ ] **Step 1: Create NativeLogger.kt**

Create `packages/libdivecomputer_plugin/android/src/main/kotlin/com/submersion/libdivecomputer/NativeLogger.kt`:

```kotlin
package com.submersion.libdivecomputer

import android.os.Handler
import android.os.Looper
import android.util.Log

/**
 * Centralized logger that sends log events back to Flutter via Pigeon
 * while also logging to Android logcat.
 */
object NativeLogger {
    private var flutterApi: DiveComputerFlutterApi? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    fun setFlutterApi(api: DiveComputerFlutterApi?) {
        flutterApi = api
    }

    fun d(tag: String, category: String, message: String) {
        Log.d(tag, message)
        sendToFlutter(category, "DEBUG", message)
    }

    fun i(tag: String, category: String, message: String) {
        Log.i(tag, message)
        sendToFlutter(category, "INFO", message)
    }

    fun w(tag: String, category: String, message: String) {
        Log.w(tag, message)
        sendToFlutter(category, "WARN", message)
    }

    fun e(tag: String, category: String, message: String) {
        Log.e(tag, message)
        sendToFlutter(category, "ERROR", message)
    }

    private fun sendToFlutter(category: String, level: String, message: String) {
        val api = flutterApi ?: return
        mainHandler.post {
            try {
                api.onLogEvent(category, level, message) {}
            } catch (_: Exception) {
                // Don't let logging failures crash the app
            }
        }
    }
}
```

- [ ] **Step 2: Initialize NativeLogger in DiveComputerHostApiImpl**

In `DiveComputerHostApiImpl.kt`, find where the `flutterApi` is stored (likely in the constructor or init block). After it is set, also set it on `NativeLogger`:

```kotlin
NativeLogger.setFlutterApi(flutterApi)
```

Then replace `Log.d(TAG, ...)` calls in `DiveComputerHostApiImpl.kt` with `NativeLogger.d(TAG, "BLE", ...)` or the appropriate category. Use `"LDC"` for libdivecomputer operations, `"BLE"` for bluetooth operations.

- [ ] **Step 3: Update BleIoStream.kt logging**

Replace `Log.d(TAG, ...)` calls in `BleIoStream.kt` with `NativeLogger.d(TAG, "BLE", ...)`. Replace `Log.e(TAG, ...)` with `NativeLogger.e(TAG, "BLE", ...)`.

- [ ] **Step 4: Update BleScanner.kt logging**

Replace `Log.d(TAG, ...)` calls in `BleScanner.kt` with `NativeLogger.d(TAG, "BLE", ...)`.

- [ ] **Step 5: Build Android to verify compilation**

Run: `flutter build apk --debug`
Expected: Build succeeds with no errors.

- [ ] **Step 6: Commit**

```bash
git add packages/libdivecomputer_plugin/android/
git commit -m "feat: add Android NativeLogger and route native logs to Flutter"
```

---

## Task 13: iOS/macOS Native Logger

**Files:**
- Create: `packages/libdivecomputer_plugin/macos/Classes/NativeLogger.swift`
- Modify: `packages/libdivecomputer_plugin/macos/Classes/BleIoStream.swift`
- Modify: `packages/libdivecomputer_plugin/macos/Classes/BleScanner.swift`
- Modify: `packages/libdivecomputer_plugin/macos/Classes/SerialIoStream.swift`
- Modify: `packages/libdivecomputer_plugin/macos/Classes/SerialScanner.swift`

**Context:** Same pattern as Android. Create a Swift `NativeLogger` class. The macOS Classes are shared with iOS via symlinks, so changes apply to both platforms.

- [ ] **Step 1: Create NativeLogger.swift**

Create `packages/libdivecomputer_plugin/macos/Classes/NativeLogger.swift`:

```swift
import Foundation

/// Centralized logger that sends log events back to Flutter via Pigeon
/// while also printing to the system console.
class NativeLogger {
    static var flutterApi: DiveComputerFlutterApi?

    static func d(_ tag: String, category: String, _ message: String) {
        print("[\(tag)] \(message)")
        sendToFlutter(category: category, level: "DEBUG", message: message)
    }

    static func i(_ tag: String, category: String, _ message: String) {
        print("[\(tag)] \(message)")
        sendToFlutter(category: category, level: "INFO", message: message)
    }

    static func w(_ tag: String, category: String, _ message: String) {
        print("[\(tag)] WARNING: \(message)")
        sendToFlutter(category: category, level: "WARN", message: message)
    }

    static func e(_ tag: String, category: String, _ message: String) {
        print("[\(tag)] ERROR: \(message)")
        sendToFlutter(category: category, level: "ERROR", message: message)
    }

    private static func sendToFlutter(category: String, level: String, message: String) {
        guard let api = flutterApi else { return }
        DispatchQueue.main.async {
            api.onLogEvent(category: category, level: level, message: message) { _ in
                // Ignore callback result - don't let logging failures crash the app
            }
        }
    }
}
```

- [ ] **Step 2: Initialize NativeLogger in the plugin registration**

Find where the Flutter API is set up in the Swift plugin registration (likely in the main plugin class). After the API is created, set:

```swift
NativeLogger.flutterApi = flutterApi
```

- [ ] **Step 3: Update BleIoStream.swift, BleScanner.swift, SerialIoStream.swift, SerialScanner.swift**

Replace `print(...)` calls with the appropriate `NativeLogger` calls:
- BLE-related prints: `NativeLogger.d("BleIoStream", category: "BLE", message)`
- Serial-related prints: `NativeLogger.d("SerialIoStream", category: "SER", message)`

- [ ] **Step 4: Ensure iOS symlinks point to the shared files**

The iOS plugin typically symlinks to the macOS Classes directory. Verify `NativeLogger.swift` is included in the iOS build. If the iOS plugin uses a separate source directory with symlinks, add the symlink:

```bash
ls -la packages/libdivecomputer_plugin/ios/Classes/
```

If symlinks are used, create one for NativeLogger.swift. If source files are listed in a podspec, update it.

- [ ] **Step 5: Build macOS to verify compilation**

Run: `flutter build macos --debug`
Expected: Build succeeds.

- [ ] **Step 6: Commit**

```bash
git add packages/libdivecomputer_plugin/macos/ packages/libdivecomputer_plugin/ios/
git commit -m "feat: add iOS/macOS NativeLogger and route native logs to Flutter"
```

---

## Task 14: libdivecomputer Log Callback

**Files:**
- Modify: `packages/libdivecomputer_plugin/macos/Classes/libdc_wrapper.c`
- Modify: `packages/libdivecomputer_plugin/macos/Classes/libdc_wrapper.h`
- Modify: `packages/libdivecomputer_plugin/android/src/main/cpp/libdc_jni.cpp`

**Context:** libdivecomputer supports a log function via `dc_context_set_logfunc()` and log level via `dc_context_set_loglevel()`. We need to:
1. Add a log callback function pointer to the wrapper's callback struct or as a standalone callback
2. Set it on the `dc_context` so libdivecomputer's internal logging flows through to the app

- [ ] **Step 1: Add log callback to libdc_wrapper.h**

Add a log callback typedef and a function to set it:

```c
typedef void (*libdc_log_callback_fn)(int level, const char *message, void *userdata);

int libdc_set_log_callback(void *context, libdc_log_callback_fn callback, void *userdata);
```

- [ ] **Step 2: Implement in libdc_wrapper.c**

Implement `libdc_set_log_callback` which calls `dc_context_set_logfunc()` with a wrapper that converts `dc_loglevel_t` to an int and forwards to the callback:

```c
static libdc_log_callback_fn g_log_callback = NULL;
static void *g_log_userdata = NULL;

static void libdc_log_func(dc_context_t *context, dc_loglevel_t loglevel, const char *file,
                            unsigned int line, const char *function, const char *msg, void *userdata) {
    (void)context; (void)file; (void)line; (void)function;
    if (g_log_callback) {
        g_log_callback((int)loglevel, msg, g_log_userdata);
    }
}

int libdc_set_log_callback(void *context, libdc_log_callback_fn callback, void *userdata) {
    g_log_callback = callback;
    g_log_userdata = userdata;
    dc_context_set_loglevel((dc_context_t *)context, DC_LOGLEVEL_ALL);
    dc_context_set_logfunc((dc_context_t *)context, libdc_log_func, userdata);
    return 0;
}
```

- [ ] **Step 3: Call the log callback from native wrappers**

In the Swift code that creates the `dc_context`, after creating it, call `libdc_set_log_callback` with a callback that routes through `NativeLogger`:

This will likely be done in the Swift wrapper that calls `libdc_download_start` or similar. The callback needs to bridge from C to Swift — use a `@convention(c)` closure or a static C function.

In the Android JNI (`libdc_jni.cpp`), do the same via JNI to call `NativeLogger`.

- [ ] **Step 4: Build to verify**

Run: `flutter build macos --debug`
Expected: Build succeeds.

- [ ] **Step 5: Commit**

```bash
git add packages/libdivecomputer_plugin/macos/Classes/ packages/libdivecomputer_plugin/android/src/main/cpp/
git commit -m "feat: add libdivecomputer log callback routing through NativeLogger"
```

---

## Task 15: Full Integration Test

**Files:**
- No new files — manual testing and existing test suite

- [ ] **Step 1: Run the full test suite**

Run: `flutter test`
Expected: All tests PASS.

- [ ] **Step 2: Run flutter analyze**

Run: `flutter analyze`
Expected: No issues.

- [ ] **Step 3: Format all Dart code**

Run: `dart format lib/ test/`
Expected: No formatting changes needed (already formatted at each step).

- [ ] **Step 4: Manual smoke test**

Run: `flutter run -d macos`

Test the following flow:
1. Open Settings > About
2. Long-press the version text 5 times — verify "Debug mode enabled" snackbar appears
3. Verify a "Debug" section appears in the settings list (above About)
4. Tap "Debug Logs" — verify the log viewer opens
5. Verify log entries are displayed (at minimum, app startup logs)
6. Test category chip filtering — toggle chips and verify entries filter
7. Test severity dropdown — set to Warning and verify only Warning/Error entries show
8. Test search — type a keyword and verify entries filter
9. Test Share button — verify system share sheet opens
10. Test Copy button — verify snackbar says "Filtered logs copied"
11. Test Save button — verify file picker opens
12. Test overflow menu > "Clear Logs" — verify entries are cleared
13. Test overflow menu > "Disable Debug Mode" — verify return to settings, Debug section gone

- [ ] **Step 5: Final commit if any fixes were needed**

```bash
git add -A
git commit -m "fix: integration test fixes for debug log viewer"
```
