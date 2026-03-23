import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/export/csv/csv_import_service.dart';

void main() {
  final service = CsvImportService();

  // The legacy CsvImportService uses CsvToListConverter with default \r\n eol,
  // so test data must use \r\n line endings.

  group('importDivesFromCsv - UTC wall-time (issue #60)', () {
    test('date+time columns produce UTC DateTime', () async {
      const csv =
          'Date,Time,Max Depth,Duration\r\n'
          '2024-01-15,14:30,25.5,45\r\n';

      final dives = await service.importDivesFromCsv(csv);

      expect(dives, hasLength(1));
      final dateTime = dives.first['dateTime'] as DateTime;
      expect(
        dateTime.isUtc,
        isTrue,
        reason: 'Must produce UTC DateTime for wall-time storage',
      );
      expect(dateTime, DateTime.utc(2024, 1, 15, 14, 30));
    });

    test('date-only column produces UTC DateTime at midnight', () async {
      const csv =
          'Date,Max Depth\r\n'
          '1998-08-05,15\r\n';

      final dives = await service.importDivesFromCsv(csv);

      expect(dives, hasLength(1));
      final dateTime = dives.first['dateTime'] as DateTime;
      expect(dateTime.isUtc, isTrue);
      expect(dateTime, DateTime.utc(1998, 8, 5));
    });

    test('time is not shifted by local UTC offset (issue #60)', () async {
      const csv =
          'Date,Time,Duration\r\n'
          '1998-08-05,11:22,45\r\n';

      final dives = await service.importDivesFromCsv(csv);

      expect(dives, hasLength(1));
      final dateTime = dives.first['dateTime'] as DateTime;
      expect(dateTime.isUtc, isTrue);
      expect(
        dateTime.hour,
        11,
        reason: 'Time must not be shifted by UTC offset',
      );
      expect(dateTime.minute, 22);
    });

    test('all dives in multi-row CSV produce UTC DateTimes', () async {
      const csv =
          'Date,Time,Duration\r\n'
          '2024-01-15,08:00,45\r\n'
          '2024-01-15,14:30,50\r\n'
          '2024-01-16,09:45,35\r\n';

      final dives = await service.importDivesFromCsv(csv);

      expect(dives, hasLength(3));
      for (final dive in dives) {
        final dt = dive['dateTime'] as DateTime;
        expect(dt.isUtc, isTrue, reason: 'Every dive must have UTC dateTime');
      }
      expect((dives[0]['dateTime'] as DateTime).hour, 8);
      expect((dives[1]['dateTime'] as DateTime).hour, 14);
      expect((dives[2]['dateTime'] as DateTime).hour, 9);
    });

    test('MM/dd/yyyy date format produces UTC', () async {
      const csv =
          'Date,Time,Duration\r\n'
          '01/15/2024,10:00,45\r\n';

      final dives = await service.importDivesFromCsv(csv);

      expect(dives, hasLength(1));
      final dateTime = dives.first['dateTime'] as DateTime;
      expect(dateTime.isUtc, isTrue);
      expect(dateTime, DateTime.utc(2024, 1, 15, 10, 0));
    });

    test('midnight time is preserved as UTC', () async {
      const csv =
          'Date,Time,Duration\r\n'
          '2024-01-15,00:00,45\r\n';

      final dives = await service.importDivesFromCsv(csv);

      expect(dives, hasLength(1));
      final dateTime = dives.first['dateTime'] as DateTime;
      expect(dateTime.isUtc, isTrue);
      expect(dateTime.hour, 0);
      expect(dateTime.minute, 0);
    });

    test('ISO 8601 date falls through to DateTime.tryParse as UTC', () async {
      // ISO 8601 with time component doesn't match strict DateFormat patterns,
      // so it exercises the DateTime.tryParse fallback path.
      const csv =
          'Date,Duration\r\n'
          '2024-01-15T14:30:00,45\r\n';

      final dives = await service.importDivesFromCsv(csv);

      expect(dives, hasLength(1));
      final dateTime = dives.first['dateTime'] as DateTime;
      expect(dateTime.isUtc, isTrue);
      expect(dateTime.year, 2024);
      expect(dateTime.month, 1);
      expect(dateTime.day, 15);
      expect(dateTime.hour, 14);
      expect(dateTime.minute, 30);
    });

    test('ISO 8601 with Z suffix produces UTC', () async {
      const csv =
          'Date,Duration\r\n'
          '2024-01-15T10:30:00Z,45\r\n';

      final dives = await service.importDivesFromCsv(csv);

      expect(dives, hasLength(1));
      final dateTime = dives.first['dateTime'] as DateTime;
      expect(dateTime.isUtc, isTrue);
      expect(dateTime.hour, 10);
      expect(dateTime.minute, 30);
    });

    test('late evening time is preserved as UTC', () async {
      const csv =
          'Date,Time,Duration\r\n'
          '2024-01-15,23:30,45\r\n';

      final dives = await service.importDivesFromCsv(csv);

      expect(dives, hasLength(1));
      final dateTime = dives.first['dateTime'] as DateTime;
      expect(dateTime.isUtc, isTrue);
      expect(dateTime.hour, 23);
      expect(dateTime.minute, 30);
    });
  });
}
