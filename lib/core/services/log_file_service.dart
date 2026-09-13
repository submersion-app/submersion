import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:submersion/core/models/log_entry.dart';

/// Service for writing, reading, and rotating the application log file.
///
/// Writes structured log lines to `<logDirectory>/submersion.log`.
/// When the file exceeds [maxFileSizeBytes], it is rotated by keeping
/// the most recent ~50% of the content.
///
/// [initialize] must be called before any other method.
class LogFileService {
  final String logDirectory;
  final int maxFileSizeBytes;

  static const _logFileName = 'submersion.log';
  static const _defaultMaxSize = 5 * 1024 * 1024; // 5MB
  static const _newline = 0x0A;

  late final String _logFilePath;
  bool _isInitialized = false;

  /// Serializes writes so concurrent calls don't race with rotation.
  Future<void> _writeQueue = Future.value();

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
    _isInitialized = true;
  }

  /// Write a formatted log line to the file.
  ///
  /// Writes are serialized so concurrent calls don't race with rotation.
  /// Failures are silently swallowed to keep the application running.
  Future<void> writeLine(String line) {
    if (!_isInitialized) {
      throw StateError(
        'LogFileService.initialize() must be called before writeLine()',
      );
    }
    _writeQueue = _writeQueue.then((_) => _doWrite(line));
    return _writeQueue;
  }

  Future<void> _doWrite(String line) async {
    try {
      final file = File(_logFilePath);
      await file.writeAsString('$line\n', mode: FileMode.append);
      await _rotateIfNeeded();
    } on IOException catch (e) {
      developer.log(
        'LogFileService: failed to write log line: $e',
        name: 'LogFileService',
      );
    }
  }

  /// Read and parse all valid log entries from the file.
  Future<List<LogEntry>> readEntries() async {
    if (!_isInitialized) {
      throw StateError(
        'LogFileService.initialize() must be called before readEntries()',
      );
    }
    final file = File(_logFilePath);
    if (!file.existsSync()) return [];

    // Decoded leniently: a device name or native message can put a
    // malformed UTF-8 byte in the file, and a strict decode would throw and
    // hide every entry from the viewer.
    final text = utf8.decode(await file.readAsBytes(), allowMalformed: true);
    final lines = const LineSplitter().convert(text);
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
    if (!_isInitialized) {
      throw StateError(
        'LogFileService.initialize() must be called before clearLog()',
      );
    }
    final file = File(_logFilePath);
    if (file.existsSync()) {
      await file.delete();
    }
  }

  /// Check file size and rotate if it exceeds the max.
  /// Rotation keeps the last ~50% of the file content.
  ///
  /// Works on bytes, not decoded text: a strict UTF-8 decode throws on one
  /// malformed byte, which would stop rotation for good and let a file that
  /// is written for every user (#1826) grow without bound.
  Future<void> _rotateIfNeeded() async {
    final file = File(_logFilePath);
    if (!file.existsSync()) return;

    final size = await file.length();
    if (size <= maxFileSizeBytes) return;

    final bytes = await file.readAsBytes();

    // Find the next newline after the midpoint so we don't split a line
    final nextNewline = bytes.indexOf(_newline, bytes.length ~/ 2);
    if (nextNewline == -1) return;

    await file.writeAsBytes(bytes.sublist(nextNewline + 1));
  }
}
