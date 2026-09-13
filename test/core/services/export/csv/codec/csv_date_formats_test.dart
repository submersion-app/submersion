import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/services/export/csv/codec/csv_date_formats.dart';

void main() {
  test('every date preference round trips through its header suffix', () {
    final date = DateTime.utc(2025, 3, 5);
    for (final f in DateFormatPreference.values) {
      expect(dateFormatForSuffix(f.displayName), f);
      final text = formatCsvDate(date, f);
      expect(parseCsvDate(text, f), date, reason: '${f.name}: $text');
    }
  });

  test('every time preference round trips through its header suffix', () {
    for (final f in TimeFormat.values) {
      expect(timeFormatForSuffix(f.displayName), f);
      final text = formatCsvTime(DateTime.utc(2025, 3, 5, 14, 7), f);
      expect(parseCsvTime(text, f), (hour: 14, minute: 7), reason: text);
    }
  });

  test('month names are English regardless of the default locale', () {
    expect(
      formatCsvDate(DateTime.utc(2025, 1, 9), DateFormatPreference.mmmDYYYY),
      'Jan 9, 2025',
    );
  });

  test('no suffix means ISO date and 24-hour time', () {
    expect(parseCsvDate('2025-03-05', null), DateTime.utc(2025, 3, 5));
    expect(parseCsvTime('09:05', null), (hour: 9, minute: 5));
  });

  test('unparseable text is null, not an exception', () {
    expect(parseCsvDate('05/03', DateFormatPreference.ddmmyyyy), isNull);
    expect(parseCsvTime('noon', null), isNull);
    expect(parseCsvDate('', null), isNull);
  });
}
