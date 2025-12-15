import 'dart:developer' as developer;

/// Simple logging service for the application.
/// Uses Dart's developer.log for structured logging.
class LoggerService {
  final String _name;

  const LoggerService(this._name);

  /// Log a debug message
  void debug(String message, [Object? error, StackTrace? stackTrace]) {
    developer.log(
      message,
      name: _name,
      level: 500, // FINE level
      error: error,
      stackTrace: stackTrace,
    );
  }

  /// Log an info message
  void info(String message, [Object? error, StackTrace? stackTrace]) {
    developer.log(
      message,
      name: _name,
      level: 800, // INFO level
      error: error,
      stackTrace: stackTrace,
    );
  }

  /// Log a warning message
  void warning(String message, [Object? error, StackTrace? stackTrace]) {
    developer.log(
      message,
      name: _name,
      level: 900, // WARNING level
      error: error,
      stackTrace: stackTrace,
    );
  }

  /// Log an error message
  void error(String message, [Object? error, StackTrace? stackTrace]) {
    developer.log(
      message,
      name: _name,
      level: 1000, // SEVERE level
      error: error,
      stackTrace: stackTrace,
    );
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
