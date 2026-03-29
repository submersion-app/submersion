import 'dart:async';
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
  static Future<void> _pendingWrite = Future<void>.value();

  /// Broadcast stream that emits every [LogEntry] as it is created.
  /// Used by the debug log viewer to update in real time.
  static final StreamController<LogEntry> _logStreamController =
      StreamController<LogEntry>.broadcast();

  /// Stream of log entries emitted in real time.
  static Stream<LogEntry> get logStream => _logStreamController.stream;

  /// Set or clear the file logging backend.
  /// Pass `null` to disable file logging (e.g. when debug mode is off).
  static void setFileService(LogFileService? fileService) {
    _fileService = fileService;
    _pendingWrite = Future<void>.value();
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
  void info(
    String message, {
    LogCategory category = LogCategory.app,
    Object? error,
    StackTrace? stackTrace,
  }) {
    _log(
      message,
      category: category,
      level: LogLevel.info,
      developerLevel: 800,
      error: error,
      stackTrace: stackTrace,
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
    _pendingWrite =
        _fileService?.writeLine(entry.toLogLine()) ?? Future.value();

    // Notify live listeners (debug log viewer).
    _logStreamController.add(entry);
  }

  /// Create a logger for a specific class
  static LoggerService forClass(Type type) => LoggerService(type.toString());

  /// Wait for the most recently scheduled file write to complete.
  static Future<void> flushPendingWrites() => _pendingWrite;
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
