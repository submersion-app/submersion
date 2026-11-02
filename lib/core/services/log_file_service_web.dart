import 'dart:collection';

import 'package:submersion/core/models/log_entry.dart';

/// Browser variant of the log file service: the most recent lines, in
/// memory, for the life of the page.
///
/// Mirrors the native file's contract: [initialize] before anything else,
/// and when the stored text passes [maxFileSizeBytes] the oldest half goes,
/// so the viewer keeps what it would keep on a device.
class LogFileService {
  LogFileService({
    required this.logDirectory,
    this.maxFileSizeBytes = _defaultMaxSize,
  });

  /// Kept for the shared constructor; nothing is written there.
  final String logDirectory;
  final int maxFileSizeBytes;

  static const _defaultMaxSize = 5 * 1024 * 1024;

  /// Where the lines would live if the browser had a file for them. The
  /// diagnostics card shows it, so it names the medium rather than a path.
  static const String memoryPath = 'memory://submersion.log';

  final ListQueue<String> _lines = ListQueue<String>();
  int _chars = 0;
  bool _isInitialized = false;

  String get logFilePath => memoryPath;

  /// Nothing to create; marks the service ready.
  Future<void> initialize() async {
    _isInitialized = true;
  }

  /// Keeps [line] and drops the oldest half once the text passes the cap.
  Future<void> writeLine(String line) async {
    _ensureInitialized('writeLine');
    _lines.addLast(line);
    _chars += line.length + 1;
    if (_chars > maxFileSizeBytes) _dropOldestHalf();
  }

  /// Every stored line that parses as a [LogEntry], oldest first.
  Future<List<LogEntry>> readEntries() async {
    _ensureInitialized('readEntries');
    return [for (final line in _lines) ?LogEntry.tryParse(line)];
  }

  /// Every stored line as written, oldest first.
  Future<List<String>> readLines() async {
    _ensureInitialized('readLines');
    return _lines.toList(growable: false);
  }

  /// Forgets every line.
  Future<void> clearLog() async {
    _ensureInitialized('clearLog');
    _lines.clear();
    _chars = 0;
  }

  void _dropOldestHalf() {
    final keep = maxFileSizeBytes ~/ 2;
    while (_lines.isNotEmpty && _chars > keep) {
      _chars -= _lines.removeFirst().length + 1;
    }
  }

  void _ensureInitialized(String method) {
    if (!_isInitialized) {
      throw StateError(
        'LogFileService.initialize() must be called before $method()',
      );
    }
  }
}
