import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/models/log_entry.dart';

void main() {
  group('LogCategory', () {
    test('tag returns correct short tag', () {
      expect(LogCategory.app.tag, 'APP');
      expect(LogCategory.bluetooth.tag, 'BLE');
      expect(LogCategory.serial.tag, 'SER');
      expect(LogCategory.libdc.tag, 'LDC');
      expect(LogCategory.database.tag, 'DB');
    });

    test('fromTag parses known tags', () {
      expect(LogCategory.fromTag('APP'), LogCategory.app);
      expect(LogCategory.fromTag('BLE'), LogCategory.bluetooth);
      expect(LogCategory.fromTag('SER'), LogCategory.serial);
      expect(LogCategory.fromTag('LDC'), LogCategory.libdc);
      expect(LogCategory.fromTag('DB'), LogCategory.database);
    });

    test('fromTag returns null for unknown tags', () {
      expect(LogCategory.fromTag('UNKNOWN'), isNull);
      expect(LogCategory.fromTag(''), isNull);
    });
  });

  group('LogLevel', () {
    test('tag returns correct tag', () {
      expect(LogLevel.debug.tag, 'DEBUG');
      expect(LogLevel.info.tag, 'INFO');
      expect(LogLevel.warning.tag, 'WARN');
      expect(LogLevel.error.tag, 'ERROR');
    });

    test('fromTag parses known tags', () {
      expect(LogLevel.fromTag('DEBUG'), LogLevel.debug);
      expect(LogLevel.fromTag('INFO'), LogLevel.info);
      expect(LogLevel.fromTag('WARN'), LogLevel.warning);
      expect(LogLevel.fromTag('ERROR'), LogLevel.error);
    });

    test('fromTag returns null for unknown tags', () {
      expect(LogLevel.fromTag('TRACE'), isNull);
    });

    test('severity ordering', () {
      expect(LogLevel.debug.index < LogLevel.info.index, isTrue);
      expect(LogLevel.info.index < LogLevel.warning.index, isTrue);
      expect(LogLevel.warning.index < LogLevel.error.index, isTrue);
    });
  });

  group('LogEntry', () {
    test('formats to structured log line', () {
      final entry = LogEntry(
        timestamp: DateTime(2026, 3, 27, 14, 32, 1, 123),
        category: LogCategory.bluetooth,
        level: LogLevel.info,
        message: 'Connected to Shearwater Perdix',
      );

      expect(
        entry.toLogLine(),
        '[2026-03-27T14:32:01.123] [BLE] [INFO] Connected to Shearwater Perdix',
      );
    });

    test('parses valid log line', () {
      const line =
          '[2026-03-27T14:32:01.123] [BLE] [INFO] Connected to Shearwater Perdix';
      final entry = LogEntry.tryParse(line);

      expect(entry, isNotNull);
      expect(entry!.category, LogCategory.bluetooth);
      expect(entry.level, LogLevel.info);
      expect(entry.message, 'Connected to Shearwater Perdix');
      expect(entry.timestamp.year, 2026);
      expect(entry.timestamp.month, 3);
      expect(entry.timestamp.day, 27);
      expect(entry.timestamp.hour, 14);
      expect(entry.timestamp.minute, 32);
      expect(entry.timestamp.second, 1);
      expect(entry.timestamp.millisecond, 123);
    });

    test('parses log line with brackets in message', () {
      const line =
          '[2026-03-27T10:00:00.000] [APP] [ERROR] Failed [code=42] something';
      final entry = LogEntry.tryParse(line);

      expect(entry, isNotNull);
      expect(entry!.category, LogCategory.app);
      expect(entry.level, LogLevel.error);
      expect(entry.message, 'Failed [code=42] something');
    });

    test('returns null for malformed lines', () {
      expect(LogEntry.tryParse(''), isNull);
      expect(LogEntry.tryParse('not a log line'), isNull);
      expect(LogEntry.tryParse('[bad timestamp] [APP] [INFO] msg'), isNull);
    });

    test('returns null for unknown category', () {
      expect(
        LogEntry.tryParse('[2026-03-27T10:00:00.000] [XXX] [INFO] msg'),
        isNull,
      );
    });

    test('returns null for unknown level', () {
      expect(
        LogEntry.tryParse('[2026-03-27T10:00:00.000] [APP] [TRACE] msg'),
        isNull,
      );
    });

    test('two instances with identical fields compare as equal', () {
      final timestamp = DateTime(2026, 3, 27, 14, 32, 1, 123);
      final a = LogEntry(
        timestamp: timestamp,
        category: LogCategory.bluetooth,
        level: LogLevel.info,
        message: 'Connected to Shearwater Perdix',
      );
      final b = LogEntry(
        timestamp: timestamp,
        category: LogCategory.bluetooth,
        level: LogLevel.info,
        message: 'Connected to Shearwater Perdix',
      );

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('copyWith returns a new instance with the given fields replaced', () {
      final original = LogEntry(
        timestamp: DateTime(2026, 3, 27, 14, 32, 1, 123),
        category: LogCategory.bluetooth,
        level: LogLevel.info,
        message: 'Connected to Shearwater Perdix',
      );

      final updated = original.copyWith(
        level: LogLevel.error,
        message: 'Connection lost',
      );

      expect(updated.timestamp, original.timestamp);
      expect(updated.category, original.category);
      expect(updated.level, LogLevel.error);
      expect(updated.message, 'Connection lost');
      expect(updated, isNot(equals(original)));
    });
  });
}
