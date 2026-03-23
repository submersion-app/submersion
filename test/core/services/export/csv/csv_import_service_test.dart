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
  });
}
