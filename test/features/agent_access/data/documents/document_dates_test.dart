import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/agent_access/data/documents/document_dates.dart';

void main() {
  group('calendarDate', () {
    test('calendar dates never slip a day', () {
      expect(calendarDate(DateTime(2024, 3, 1)), '2024-03-01');
      expect(calendarDate(DateTime.utc(2024, 3, 1)), '2024-03-01');
      expect(calendarDate(DateTime(2024, 3, 1, 23, 59)), '2024-03-01');
    });

    test('pads a short year, month and day', () {
      expect(calendarDate(DateTime.utc(987, 1, 2)), '0987-01-02');
    });

    test('a null stays null', () {
      expect(calendarDate(null), isNull);
    });
  });

  group('instant', () {
    test('instant is always UTC', () {
      expect(
        instant(DateTime.fromMillisecondsSinceEpoch(0)),
        '1970-01-01T00:00:00.000Z',
      );
    });

    test('a null stays null', () {
      expect(instant(null), isNull);
    });
  });

  group('wallClock', () {
    test('wall clock keeps the value as held', () {
      expect(
        wallClock(DateTime.utc(2024, 5, 1, 10)),
        '2024-05-01T10:00:00.000Z',
      );
    });

    test('wallClockOrNull passes a null through', () {
      expect(wallClockOrNull(null), isNull);
      expect(
        wallClockOrNull(DateTime.utc(2024, 5, 1, 10)),
        '2024-05-01T10:00:00.000Z',
      );
    });
  });
}
