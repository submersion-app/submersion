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

  // Issue #3111: a German phone showed the app in German but stored place
  // names in English, because nothing tied the default to the app language.
  group('forAppLocale', () {
    test('an explicit app language is used as it is', () {
      expect(PlaceNameLanguage.forAppLocale('de', const ['fr']), 'de');
    });

    test('system follows the first supported device language', () {
      expect(
        PlaceNameLanguage.forAppLocale('system', const ['pl', 'de']),
        'de',
      );
    });

    test('device language codes are compared case-insensitively', () {
      expect(PlaceNameLanguage.forAppLocale('system', const ['FR']), 'fr');
    });

    test('system with no supported device language falls back to English', () {
      expect(PlaceNameLanguage.forAppLocale('system', const ['pl', 'c']), 'en');
      expect(PlaceNameLanguage.forAppLocale('system', const []), 'en');
    });

    test('an unknown explicit app language falls back to English', () {
      expect(PlaceNameLanguage.forAppLocale('xx', const ['de']), 'en');
    });
  });
}
