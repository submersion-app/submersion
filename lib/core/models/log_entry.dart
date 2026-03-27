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
