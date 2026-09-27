import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/services/pdf_templates/pdf_date_formatter.dart';

/// #2252: [PdfDateFormatter.inLanguage] must never hand back a formatter that
/// throws. This file deliberately never calls `initializeDateFormatting`, so
/// intl's locale data is missing here the way it is outside the app, and a
/// failure intl defers to the first `format()` call would surface.
void main() {
  final formatter = PdfDateFormatter(
    dateFormat: DateFormatPreference.mmmDYYYY,
    timeFormat: TimeFormat.twelveHour,
  );
  final when = DateTime(2026, 8, 17, 14, 30);

  for (final code in ['en', 'fr', 'ar', 'zh', 'xx']) {
    test('$code without locale data still formats', () {
      final localized = formatter.inLanguage(code);

      expect(() => localized.date(when), returnsNormally);
      expect(() => localized.time(when), returnsNormally);
      expect(() => localized.dateTime(when), returnsNormally);
    });
  }
}
