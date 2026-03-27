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

      final lines = await File('${tempDir.path}/submersion.log').readAsLines();
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
      expect(size, lessThan(200));

      // Should still contain the most recent entries
      final content = await logFile.readAsString();
      expect(content, contains('number 19'));
    });
  });
}
