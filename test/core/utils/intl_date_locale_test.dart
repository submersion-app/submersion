import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:submersion/core/utils/intl_date_locale.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('de');
    await initializeDateFormatting('de_CH');
  });

  test('keeps a locale intl holds date data for', () {
    expect(intlDateLocale('de_CH'), 'de_CH');
    expect(intlDateLocale('de-CH'), 'de_CH');
  });

  test('falls back to the language for a region without data', () {
    expect(intlDateLocale('de_LI'), 'de');
  });

  test("is null when intl holds neither, leaving intl's default", () {
    expect(intlDateLocale('xx_YY'), isNull);
  });
}
