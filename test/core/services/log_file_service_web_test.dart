import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/models/log_entry.dart';
import 'package:submersion/core/services/log_file_service_web.dart';

/// The browser variant of the log file service, imported directly.
void main() {
  String line(int i) => LogEntry(
    timestamp: DateTime(2026, 11, 2, 9, 0, i),
    category: LogCategory.app,
    level: LogLevel.info,
    message: 'line $i',
  ).toLogLine();

  test('refuses to work before initialize', () {
    final service = LogFileService(logDirectory: '/opfs/support/logs');
    expect(() => service.writeLine('x'), throwsStateError);
    expect(service.readEntries, throwsStateError);
    expect(service.clearLog, throwsStateError);
  });

  test('keeps lines in memory and reads them back as entries', () async {
    final service = LogFileService(logDirectory: '/opfs/support/logs');
    await service.initialize();
    for (var i = 0; i < 3; i++) {
      await service.writeLine(line(i));
    }
    final entries = await service.readEntries();
    expect(entries.map((e) => e.message), ['line 0', 'line 1', 'line 2']);
    expect(service.logFilePath, 'memory://submersion.log');
  });

  test('drops the oldest half once the text passes the cap', () async {
    final sample = line(0);
    final cap = sample.length * 10;
    final service = LogFileService(
      logDirectory: '/opfs/support/logs',
      maxFileSizeBytes: cap,
    );
    await service.initialize();
    for (var i = 0; i < 10; i++) {
      await service.writeLine(line(i));
    }
    final entries = await service.readEntries();
    expect(entries.length, lessThan(10));
    expect(entries.length, greaterThanOrEqualTo(4));
    expect(entries.last.message, 'line 9');
    expect(entries.first.message, isNot('line 0'));
  });

  test('clearLog empties the store', () async {
    final service = LogFileService(logDirectory: '/opfs/support/logs');
    await service.initialize();
    await service.writeLine(line(0));
    await service.clearLog();
    expect(await service.readEntries(), isEmpty);
  });

  test('readLines hands back every stored line, oldest first', () async {
    final service = LogFileService(logDirectory: '/opfs/support/logs');
    await service.initialize();
    await service.writeLine('first');
    await service.writeLine('second');
    expect(await service.readLines(), ['first', 'second']);
  });
}
