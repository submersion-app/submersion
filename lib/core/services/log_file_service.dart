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
