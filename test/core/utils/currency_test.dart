import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:submersion/core/utils/currency.dart';

void main() {
  // currencySymbol/formatMoney resolve against Intl.defaultLocale, a process
  // global the app sets from the diver's locale. Pin it so these assertions
  // do not ride on intl's implicit fallback (under some locales 'USD' renders
  // as 'US$' rather than '$'). Number symbols are statically bundled, so no
  // async initialization is needed here - unlike date formatting.
  late String? previousLocale;

  setUp(() {
    previousLocale = Intl.defaultLocale;
    Intl.defaultLocale = 'en_US';
  });

  tearDown(() {
    Intl.defaultLocale = previousLocale;
  });

  group('currencySymbol', () {
    test('maps common codes to their symbols', () {
      expect(currencySymbol('USD'), r'$');
      expect(currencySymbol('EUR'), '€');
      expect(currencySymbol('GBP'), '£');
    });

    test('is case-insensitive and trims whitespace', () {
      expect(currencySymbol(' eur '), '€');
    });

    test('blank code yields an empty symbol', () {
      expect(currencySymbol(''), '');
      expect(currencySymbol('   '), '');
    });

    test('unrecognised code falls back to the code itself', () {
      expect(currencySymbol('ZZZ'), 'ZZZ');
    });

    test('every preset code resolves to a non-empty symbol', () {
      for (final code in kCommonCurrencyCodes) {
        expect(
          currencySymbol(code),
          isNotEmpty,
          reason: '$code should have a symbol',
        );
      }
    });
  });

  group('formatMoney', () {
    test('includes the currency symbol', () {
      expect(formatMoney(12.5, 'EUR'), contains('€'));
      expect(formatMoney(12.5, 'USD'), contains(r'$'));
    });

    test('is case-insensitive and trims whitespace', () {
      expect(formatMoney(12.5, ' eur '), formatMoney(12.5, 'EUR'));
    });

    test('unrecognised code still shows the code and amount', () {
      final formatted = formatMoney(12.5, 'ZZZ');
      expect(formatted, contains('ZZZ'));
      expect(formatted, contains('12.5'));
    });

    test('a blank code still shows the amount', () {
      expect(formatMoney(12.5, ''), contains('12.5'));
    });

    test('formats zero and negative amounts', () {
      expect(formatMoney(0, 'USD'), contains('0'));
      expect(formatMoney(-5, 'USD'), contains('5'));
    });
  });

  group('locale data failures', () {
    // intl throws ArgumentError when Intl.defaultLocale names a locale it has
    // no number symbols for. These helpers are called from build methods, so
    // they degrade to a plain code+amount rather than taking the UI down.
    setUp(() {
      Intl.defaultLocale = 'xx_YY';
    });

    test('currencySymbol falls back to the code', () {
      expect(currencySymbol('EUR'), 'EUR');
    });

    test('formatMoney falls back to "CODE amount"', () {
      expect(formatMoney(12.5, 'EUR'), 'EUR 12.50');
    });

    test('formatMoney with a blank code omits the prefix', () {
      expect(formatMoney(12.5, ''), '12.50');
    });
  });

  group('currencyCodesWith', () {
    test('returns the presets unchanged for a preset code', () {
      expect(currencyCodesWith('EUR'), kCommonCurrencyCodes);
    });

    test('returns the presets unchanged for a blank or null code', () {
      expect(currencyCodesWith(''), kCommonCurrencyCodes);
      expect(currencyCodesWith('   '), kCommonCurrencyCodes);
      expect(currencyCodesWith(null), kCommonCurrencyCodes);
    });

    test('leads with a non-preset code so it stays selectable', () {
      final codes = currencyCodesWith('ISK');
      expect(codes.first, 'ISK');
      expect(codes.sublist(1), kCommonCurrencyCodes);
    });

    test('normalises case and whitespace before comparing', () {
      expect(currencyCodesWith(' eur '), kCommonCurrencyCodes);
      expect(currencyCodesWith(' isk ').first, 'ISK');
    });
  });

  group('sumByCurrency', () {
    // A minimal stand-in for a priced item. Results come back as records
    // rather than MapEntry, which has no value equality.
    List<(String, double)> sum(
      List<(double?, String)> items, {
      String fallback = 'USD',
    }) => sumByCurrency<(double?, String)>(
      items,
      amountOf: (i) => i.$1,
      currencyOf: (i) => i.$2,
      fallbackCode: fallback,
    ).map((e) => (e.key, e.value)).toList();

    test('sums items sharing one currency into a single entry', () {
      expect(sum([(10.0, 'EUR'), (5.5, 'EUR')]), [('EUR', 15.5)]);
    });

    test('keeps different currencies apart instead of adding them', () {
      expect(sum([(10.0, 'EUR'), (100.0, 'USD')]), [
        ('USD', 100.0),
        ('EUR', 10.0),
      ]);
    });

    test('orders by descending total, then by code for ties', () {
      final totals = sum([(10.0, 'GBP'), (10.0, 'EUR'), (99.0, 'JPY')]);
      expect(totals.map((e) => e.$1), ['JPY', 'EUR', 'GBP']);
    });

    test('skips items with no price', () {
      expect(sum([(null, 'EUR'), (7.0, 'EUR')]), [('EUR', 7.0)]);
    });

    test('normalises case and whitespace so codes do not fragment', () {
      expect(sum([(1.0, 'eur'), (2.0, ' EUR ')]), [('EUR', 3.0)]);
    });

    test('a blank code falls back to the supplied default', () {
      // Legacy rows can carry an empty currency; they belong with the
      // diver's default rather than in a nameless bucket of their own.
      expect(sum([(4.0, ''), (6.0, 'USD')], fallback: 'USD'), [('USD', 10.0)]);
    });

    test('an empty collection yields no entries', () {
      expect(sum(const []), isEmpty);
    });
  });

  test('kCommonCurrencyCodes covers the major currencies', () {
    expect(kCommonCurrencyCodes, containsAll(['USD', 'EUR', 'GBP', 'CHF']));
  });

  test('kCommonCurrencyCodes has no duplicates and is upper-case', () {
    expect(
      kCommonCurrencyCodes.toSet(),
      hasLength(kCommonCurrencyCodes.length),
    );
    for (final code in kCommonCurrencyCodes) {
      expect(code, code.toUpperCase());
    }
  });
}
