import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:submersion/core/utils/number_input.dart';

void main() {
  // parseUserDecimal/formatDecimalForInput resolve against Intl.defaultLocale,
  // a process global the app sets from the diver's locale (lib/app.dart). Pin
  // it per test so these assertions do not ride on intl's implicit fallback.
  // Number symbols are statically bundled, so no async initialization is
  // needed here - unlike date formatting.
  late String? previousLocale;

  setUp(() {
    previousLocale = Intl.defaultLocale;
  });

  tearDown(() {
    Intl.defaultLocale = previousLocale;
  });

  group('parseUserDecimal', () {
    test('reads a comma decimal separator under a comma locale (#1091)', () {
      Intl.defaultLocale = 'fr';
      expect(parseUserDecimal('12,50'), 12.5);
    });

    test('reads a dot decimal separator under a dot locale', () {
      Intl.defaultLocale = 'en_US';
      expect(parseUserDecimal('12.50'), 12.5);
    });

    test('reads a plain integer under every supported locale', () {
      for (final locale in ['en_US', 'fr', 'de', 'es', 'it', 'nl', 'pt']) {
        Intl.defaultLocale = locale;
        expect(parseUserDecimal('1250'), 1250.0, reason: 'locale $locale');
      }
    });

    test('ignores surrounding whitespace', () {
      Intl.defaultLocale = 'fr';
      expect(parseUserDecimal('  12,50  '), 12.5);
    });

    test('returns null for blank input', () {
      Intl.defaultLocale = 'fr';
      expect(parseUserDecimal(''), isNull);
      expect(parseUserDecimal('   '), isNull);
    });

    test('returns null rather than throwing on unparseable input', () {
      Intl.defaultLocale = 'fr';
      expect(parseUserDecimal('abc'), isNull);
      expect(parseUserDecimal('12,,50'), isNull);
    });

    test('rejects a separator sitting where no grouping could put it', () {
      // "6,4" is not a number in en_US: ',' groups thousands there, and
      // guessing it means 64 silently records a measurement the diver never
      // took. Ambiguous input is unknown, not a guess (#1091).
      Intl.defaultLocale = 'en_US';
      expect(parseUserDecimal('6,4'), isNull);
      expect(parseUserDecimal('1,25'), isNull);
      Intl.defaultLocale = 'de';
      expect(parseUserDecimal('6.4'), isNull);
    });

    test('accepts well-formed grouping', () {
      Intl.defaultLocale = 'en_US';
      expect(parseUserDecimal('1,250'), 1250);
      expect(parseUserDecimal('1,250,000'), 1250000);
      expect(parseUserDecimal('1,250.75'), 1250.75);
      Intl.defaultLocale = 'de';
      expect(parseUserDecimal('1.250'), 1250);
      expect(parseUserDecimal('1.250,75'), 1250.75);
      Intl.defaultLocale = 'fr';
      // A pasted French amount groups with a space.
      expect(parseUserDecimal('1 250,75'), 1250.75);
    });

    test('returns null for non-finite input', () {
      Intl.defaultLocale = 'en_US';
      expect(parseUserDecimal('NaN'), isNull);
      expect(parseUserDecimal('Infinity'), isNull);
    });
  });

  group('parseUserInt', () {
    test('reads a plain integer under every supported locale', () {
      for (final locale in ['en_US', 'fr', 'de', 'es', 'it', 'nl', 'pt']) {
        Intl.defaultLocale = locale;
        expect(parseUserInt('1250'), 1250, reason: 'locale $locale');
      }
    });

    test('reads a grouped integer using the locale grouping separator', () {
      Intl.defaultLocale = 'de';
      expect(parseUserInt('1.250'), 1250);
      Intl.defaultLocale = 'en_US';
      expect(parseUserInt('1,250'), 1250);
    });

    test('rejects a fractional value rather than rounding it', () {
      // Counts and durations are whole by definition; silently rounding a
      // diver's "12,5" would invent data they did not enter.
      Intl.defaultLocale = 'fr';
      expect(parseUserInt('12,5'), isNull);
      Intl.defaultLocale = 'en_US';
      expect(parseUserInt('12.5'), isNull);
    });

    test('returns null for blank and unreadable input', () {
      Intl.defaultLocale = 'fr';
      expect(parseUserInt(''), isNull);
      expect(parseUserInt('   '), isNull);
      expect(parseUserInt('abc'), isNull);
    });

    test('keeps a negative value', () {
      Intl.defaultLocale = 'fr';
      expect(parseUserInt('-3'), -3);
    });
  });

  group('formatDecimalForInput', () {
    test('uses the locale decimal separator', () {
      Intl.defaultLocale = 'fr';
      expect(formatDecimalForInput(12.5), '12,5');
      Intl.defaultLocale = 'en_US';
      expect(formatDecimalForInput(12.5), '12.5');
    });

    test('omits grouping separators so the text stays easy to edit', () {
      Intl.defaultLocale = 'de';
      expect(formatDecimalForInput(1250.5), '1250,5');
      Intl.defaultLocale = 'en_US';
      expect(formatDecimalForInput(1250.5), '1250.5');
    });

    test('renders a whole number without a trailing decimal separator', () {
      Intl.defaultLocale = 'en_US';
      expect(formatDecimalForInput(1250), '1250');
      Intl.defaultLocale = 'fr';
      expect(formatDecimalForInput(1250), '1250');
    });

    test('keeps cent precision', () {
      Intl.defaultLocale = 'en_US';
      expect(formatDecimalForInput(12.05), '12.05');
    });

    test('does not silently truncate precision', () {
      // NumberFormat.decimalPattern() caps fraction digits at 3 by default.
      // Seeding a field must not quietly round the diver's stored value:
      // callers that want fewer decimals round before calling.
      Intl.defaultLocale = 'en_US';
      expect(formatDecimalForInput(12.345678), '12.345678');
      expect(formatDecimalForInput(2.7215420), anyOf('2.721542', '2.72154200'));
    });
  });

  group('formatRoundedForInput', () {
    test('rounds to the requested precision and drops trailing zeros', () {
      Intl.defaultLocale = 'en_US';
      expect(formatRoundedForInput(12.44, 1), '12.4');
      expect(formatRoundedForInput(12.46, 1), '12.5');
      expect(formatRoundedForInput(12.0, 1), '12');
      expect(formatRoundedForInput(1250.6, 0), '1251');
    });

    test('rounds the double, not the decimal literal', () {
      // 12.45 is really 12.4499999999999993 as a double, so it rounds down.
      // Asserted rather than avoided: this matches the toStringAsFixed the
      // per-widget seed helpers already used, so seeds are unchanged.
      Intl.defaultLocale = 'en_US';
      expect(formatRoundedForInput(12.45, 1), '12.4');
    });

    test('uses the locale decimal separator', () {
      Intl.defaultLocale = 'fr';
      expect(formatRoundedForInput(12.46, 1), '12,5');
    });
  });

  group('formatFixedForInput', () {
    test('keeps exactly the requested decimals, trailing zeros included', () {
      // The dive log seeds weight and depth fields at a pinned precision, and
      // the displayed "2.0" is asserted by existing tests.
      Intl.defaultLocale = 'en_US';
      expect(formatFixedForInput(2, 1), '2.0');
      expect(formatFixedForInput(28.44, 1), '28.4');
      expect(formatFixedForInput(1250, 0), '1250');
    });

    test('uses the locale decimal separator', () {
      Intl.defaultLocale = 'de';
      expect(formatFixedForInput(2, 1), '2,0');
    });

    test('round trips back through parseUserDecimal', () {
      for (final locale in ['en_US', 'fr', 'de', 'es']) {
        Intl.defaultLocale = locale;
        expect(
          parseUserDecimal(formatFixedForInput(12.5, 1)),
          12.5,
          reason: 'locale $locale',
        );
      }
    });
  });

  group('locale cache', () {
    test('a locale change takes effect immediately', () {
      // The helpers cache their NumberFormat, and Intl.defaultLocale is a
      // mutable process global, so a stale cache would silently format and
      // parse against the previous diver's locale.
      Intl.defaultLocale = 'en_US';
      expect(formatDecimalForInput(12.5), '12.5');
      expect(parseUserDecimal('12.5'), 12.5);

      Intl.defaultLocale = 'fr';
      expect(formatDecimalForInput(12.5), '12,5');
      expect(parseUserDecimal('12,5'), 12.5);
      expect(parseUserDecimal('12.5'), isNull);

      Intl.defaultLocale = 'en_US';
      expect(formatDecimalForInput(12.5), '12.5');
      expect(parseUserDecimal('12,5'), isNull);
    });
  });

  group('round trip', () {
    // The regression guard for the trap that makes this bug dangerous to fix
    // naively: seeding a field with double.toString() ('12.5') and reading it
    // back with a locale-aware parser silently yields 125.0 under de/es/it,
    // where '.' is the GROUPING separator. Seeding and parsing must therefore
    // share one convention.
    test('survives format -> parse under every supported locale', () {
      const locales = [
        'en_US',
        'fr',
        'de',
        'es',
        'it',
        'nl',
        'pt',
        'zh',
        'hu',
        'ar',
        'he',
      ];
      const values = [
        12.5,
        1250.0,
        1250.75,
        0.5,
        0.05,
        99999.99,
        0.0,
        12.345678,
        -2.5,
        -1250.0,
      ];

      for (final locale in locales) {
        Intl.defaultLocale = locale;
        for (final value in values) {
          expect(
            parseUserDecimal(formatDecimalForInput(value)),
            value,
            reason: 'locale $locale, value $value',
          );
        }
      }
    });
  });
}
