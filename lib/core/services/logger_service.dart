import 'dart:async';
import 'dart:collection';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:submersion/core/models/log_entry.dart';
import 'package:submersion/core/services/log_file_service.dart';
import 'package:submersion/core/services/log_redactor.dart';

/// Simple logging service for the application.
/// Uses Dart's developer.log for structured logging and writes to a
/// persistent log file via [LogFileService].
class LoggerService {
  final String _name;

  /// The shared LogFileService instance. Set during app initialization.
  static LogFileService? _fileService;
  static Future<void> _pendingWrite = Future<void>.value();

  /// Broadcast stream that emits every [LogEntry] as it is created.
  static final StreamController<LogEntry> _logStreamController =
      StreamController<LogEntry>.broadcast();

  /// Stream of log entries emitted in real time, persisted or not.
  static Stream<LogEntry> get logStream => _logStreamController.stream;

  static final StreamController<LogEntry> _persistedController =
      StreamController<LogEntry>.broadcast();

  /// Entries that have been written to the log file, emitted once the write
  /// completes. The debug log viewer re-reads the file on each, so it never
  /// races a write and never re-reads for a line the file will not hold.
  static Stream<LogEntry> get persistedLogStream => _persistedController.stream;

  /// Most lines [bufferUntilFileAttached] holds; the oldest are dropped.
  static const startupBufferLimit = 500;

  /// Lines logged before a file was attached, while startup buffering is on.
  static ListQueue<({LogEntry entry, bool alwaysPersist})>? _startupBuffer;

  /// Lowest severity written to the log file. Live listeners on [logStream]
  /// see every level regardless.
  static LogLevel _minimumFileLevel = LogLevel.debug;

  /// Set or clear the file logging backend.
  /// Pass `null` to disable file logging entirely.
  static void setFileService(LogFileService? fileService) {
    _fileService = fileService;
    _pendingWrite = Future<void>.value();
  }

  /// Lowest severity currently written to the log file.
  static LogLevel get minimumFileLevel => _minimumFileLevel;

  /// Set the lowest severity written to the log file.
  static void setMinimumFileLevel(LogLevel level) {
    _minimumFileLevel = level;
  }

  /// Attach [fileService] and choose how much of the log it keeps.
  ///
  /// Warnings and errors are always persisted, so a bug report can carry the
  /// failure that prompted it even when nobody had turned on debug mode
  /// beforehand (#1826). [verbose] (debug mode) adds the debug and info
  /// levels, which are too chatty to keep by default.
  static void configureFileLogging(
    LogFileService fileService, {
    required bool verbose,
  }) {
    if (!identical(_fileService, fileService)) {
      setFileService(fileService);
    }
    _minimumFileLevel = verbose ? LogLevel.debug : LogLevel.warning;

    // Replay what startup logged before the file existed, under the level
    // just chosen and redacted like any other persisted line.
    final buffered = _startupBuffer;
    _startupBuffer = null;
    for (final line
        in buffered ?? const <({LogEntry entry, bool alwaysPersist})>[]) {
      if (_persists(line.entry.level, line.alwaysPersist)) {
        final entry = line.entry.copyWith(
          message: redactSecrets(line.entry.message),
        );
        _enqueueWrite(fileService, Future.value(entry), 'LoggerService');
      }
    }
  }

  /// Hold log lines in memory until [configureFileLogging] attaches a file.
  ///
  /// Called first thing in `main`: the global error handlers are live from
  /// the start, but the log file cannot be attached until preferences, the
  /// Windows app-data migration and the app-support directory lookup are
  /// done, and a failure in any of those would otherwise be lost (#1826).
  /// Off by default so tests that log without a file never replay stale
  /// lines into a file a later test attaches.
  static void bufferUntilFileAttached() {
    _startupBuffer ??= ListQueue();
  }

  static bool _persists(LogLevel level, bool alwaysPersist) =>
      alwaysPersist || level.index >= _minimumFileLevel.index;

  /// Queue [entry] behind every earlier write, then announce it on
  /// [persistedLogStream].
  static void _enqueueWrite(
    LogFileService service,
    Future<LogEntry> entry,
    String loggerName,
  ) {
    _pendingWrite = _pendingWrite
        .then((_) async {
          final ready = await entry;
          await service.writeLine(ready.toLogLine());
          _persistedController.add(ready);
        })
        .catchError((Object e, StackTrace st) {
          developer.log(
            'Log write failed',
            name: loggerName,
            error: e,
            stackTrace: st,
          );
        });
  }

  static void _bufferForStartup(LogEntry entry, bool alwaysPersist) {
    final buffer = _startupBuffer;
    if (buffer == null) return;
    buffer.add((entry: entry, alwaysPersist: alwaysPersist));
    while (buffer.length > startupBufferLimit) {
      buffer.removeFirst();
    }
  }

  /// Log an info line whose text is still being produced, holding its place
  /// in the file: lines logged after this call are written after it.
  ///
  /// For the session marker, which waits on a platform lookup for the app
  /// version while startup carries on logging. The entry is stamped with the
  /// time of this call. Only the file keeps the order; the console and
  /// [logStream] see the line when its text is ready.
  void infoInOrder(
    Future<String> message, {
    LogCategory category = LogCategory.app,
    bool alwaysPersist = false,
  }) {
    final timestamp = DateTime.now();
    final service = _fileService;
    final persist = service != null && _persists(LogLevel.info, alwaysPersist);
    final entry = message.then((text) {
      developer.log(text, name: _name, level: 800);
      final ready = LogEntry(
        timestamp: timestamp,
        category: category,
        level: LogLevel.info,
        message: persist ? redactSecrets(text) : text,
      );
      _logStreamController.add(ready);
      return ready;
    });
    if (persist) {
      _enqueueWrite(service, entry, _name);
    } else {
      unawaited(
        entry.then<void>(
          (_) {},
          onError: (Object e, StackTrace st) => developer.log(
            'Deferred log line failed',
            name: _name,
            error: e,
            stackTrace: st,
          ),
        ),
      );
    }
  }

  const LoggerService(this._name);

  /// Log a debug message
  void debug(
    String message, {
    LogCategory category = LogCategory.app,
    Object? error,
    StackTrace? stackTrace,
  }) {
    _log(
      message,
      category: category,
      level: LogLevel.debug,
      developerLevel: 500,
      error: error,
      stackTrace: stackTrace,
    );
  }

  /// Log an info message
  ///
  /// [alwaysPersist] writes the line to the file even below
  /// [minimumFileLevel]. Reserved for rare, non-sensitive markers such as the
  /// once-per-launch session line, which attributes the warnings after it to
  /// the build that wrote them.
  void info(
    String message, {
    LogCategory category = LogCategory.app,
    Object? error,
    StackTrace? stackTrace,
    bool alwaysPersist = false,
  }) {
    _log(
      message,
      category: category,
      level: LogLevel.info,
      developerLevel: 800,
      error: error,
      stackTrace: stackTrace,
      alwaysPersist: alwaysPersist,
    );
  }

  /// Log a warning message
  void warning(
    String message, {
    LogCategory category = LogCategory.app,
    Object? error,
    StackTrace? stackTrace,
  }) {
    _log(
      message,
      category: category,
      level: LogLevel.warning,
      developerLevel: 900,
      error: error,
      stackTrace: stackTrace,
    );
  }

  /// Log an error message
  void error(
    String message, {
    LogCategory category = LogCategory.app,
    Object? error,
    StackTrace? stackTrace,
  }) {
    _log(
      message,
      category: category,
      level: LogLevel.error,
      developerLevel: 1000,
      error: error,
      stackTrace: stackTrace,
    );
  }

  void _log(
    String message, {
    required LogCategory category,
    required LogLevel level,
    required int developerLevel,
    Object? error,
    StackTrace? stackTrace,
    bool alwaysPersist = false,
  }) {
    // Console logging via dart:developer
    developer.log(
      message,
      name: _name,
      level: developerLevel,
      error: error,
      stackTrace: stackTrace,
    );

    // Capture the current file service so that later changes to
    // _fileService do not affect already-emitted log entries.
    final service = _fileService;
    final persist = service != null && _persists(level, alwaysPersist);

    // File logging. Redacted here rather than at each call site: the file is
    // what users attach to public bug reports, and an exception's toString()
    // can carry a request URL or response body nobody chose to log. Lines
    // that are not persisted skip the work; the live stream stays in memory.
    final text = error != null ? '$message | error: $error' : message;
    final entry = LogEntry(
      timestamp: DateTime.now(),
      category: category,
      level: level,
      message: persist ? redactSecrets(text) : text,
    );
    if (persist) {
      _enqueueWrite(service, Future.value(entry), _name);
    } else if (service == null) {
      _bufferForStartup(entry, alwaysPersist);
    }

    // Notify live listeners.
    _logStreamController.add(entry);
  }

  /// Create a logger for a specific class
  static LoggerService forClass(Type type) => LoggerService(type.toString());

  /// Wait for all currently pending file writes to complete.
  ///
  /// This method is primarily intended for tests that need deterministic
  /// synchronization with log file writes.
  @visibleForTesting
  static Future<void> flushPendingWrites() async {
    while (true) {
      final current = _pendingWrite;
      await current;
      // If no new write was scheduled while we were waiting, we're done.
      if (identical(current, _pendingWrite)) {
        break;
      }
    }
  }
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
