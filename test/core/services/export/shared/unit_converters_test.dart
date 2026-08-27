import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/services/export/shared/unit_converters.dart';

void main() {
  group('formatDateForExport', () {
    final date = DateTime(2024, 1, 15);

    test('renders the dot-separated DD.MM.YYYY format', () {
      expect(
        formatDateForExport(date, DateFormatPreference.ddmmyyyyDots),
        '15.01.2024',
      );
    });

    test('renders every date format preference without throwing', () {
      for (final format in DateFormatPreference.values) {
        expect(
          () => formatDateForExport(date, format),
          returnsNormally,
          reason: 'format $format should be handled by the export switch',
        );
      }
    });
  });
}
