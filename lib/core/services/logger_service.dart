import 'dart:async';
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
  /// Used by the debug log viewer to update in real time.
  static final StreamController<LogEntry> _logStreamController =
      StreamController<LogEntry>.broadcast();

  /// Stream of log entries emitted in real time.
  static Stream<LogEntry> get logStream => _logStreamController.stream;

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
    final persist =
        service != null &&
        (alwaysPersist || level.index >= _minimumFileLevel.index);

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
      final logLine = entry.toLogLine();
      _pendingWrite = _pendingWrite
          .then((_) => service.writeLine(logLine))
          .catchError((Object e, StackTrace st) {
            developer.log(
              'Log write failed',
              name: _name,
              error: e,
              stackTrace: st,
            );
          });
    }

    // Notify live listeners (debug log viewer).
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
