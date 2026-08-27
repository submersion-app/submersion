import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/place_name_language.dart';

void main() {
  test('English is the default', () {
    expect(PlaceNameLanguage.defaultCode, 'en');
  });

  test('every app language except system is supported', () {
    expect(PlaceNameLanguage.supportedCodes, [
      'en',
      'es',
      'fr',
      'de',
      'it',
      'nl',
      'pt',
      'hu',
      'ar',
      'he',
      'zh',
    ]);
  });

  test('normalize keeps a supported code', () {
    expect(PlaceNameLanguage.normalize('de'), 'de');
  });

  test('normalize tolerates case and whitespace', () {
    expect(PlaceNameLanguage.normalize(' DE '), 'de');
    expect(PlaceNameLanguage.normalize('Zh'), 'zh');
  });

  test('normalize falls back to English for unknown, null or blank', () {
    expect(PlaceNameLanguage.normalize('xx'), 'en');
    expect(PlaceNameLanguage.normalize(null), 'en');
    expect(PlaceNameLanguage.normalize(''), 'en');
    expect(PlaceNameLanguage.normalize('system'), 'en');
  });
}
