import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:submersion/core/utils/currency.dart';
import 'package:submersion/core/utils/currency_catalog.dart';

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

    test('every default preferred code resolves to a non-empty symbol', () {
      for (final code in kDefaultPreferredCurrencyCodes) {
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

  group('formatAmountOnly', () {
    test('formats the number without a currency symbol or code', () {
      expect(formatAmountOnly(1234.5, 'USD'), '1,234.50');
    });

    test('never differs between currencies that share a display symbol', () {
      // The whole point of formatAmountOnly: USD and CAD both render '$' via
      // formatMoney, so a caller that labels the currency separately must
      // not have that label contradicted by the amount.
      expect(formatAmountOnly(45, 'USD'), isNot(contains(r'$')));
      expect(formatAmountOnly(45, 'USD'), isNot(contains('USD')));
      expect(formatAmountOnly(45, 'CAD'), isNot(contains('CAD')));
    });

    test('formats zero and negative amounts', () {
      expect(formatAmountOnly(0, 'USD'), '0.00');
      expect(formatAmountOnly(-5, 'USD'), '-5.00');
    });

    test('uses the currency\'s own decimal precision, e.g. none for JPY', () {
      expect(formatAmountOnly(1234, 'JPY'), '1,234');
    });

    test('unrecognised code still formats with two decimal digits', () {
      expect(formatAmountOnly(12.5, 'ZZZ'), '12.50');
    });

    test(
      'falls back gracefully when intl has no number symbols for the locale',
      () {
        final previousLocale = Intl.defaultLocale;
        Intl.defaultLocale = 'xx_YY';
        try {
          expect(formatAmountOnly(12.5, 'EUR'), '12.50');
        } finally {
          Intl.defaultLocale = previousLocale;
        }
      },
    );
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
      expect(currencyCodesWith('EUR'), kDefaultPreferredCurrencyCodes);
    });

    test('returns the presets unchanged for a blank or null code', () {
      expect(currencyCodesWith(''), kDefaultPreferredCurrencyCodes);
      expect(currencyCodesWith('   '), kDefaultPreferredCurrencyCodes);
      expect(currencyCodesWith(null), kDefaultPreferredCurrencyCodes);
    });

    test('leads with a non-preset code so it stays selectable', () {
      final codes = currencyCodesWith('ISK');
      expect(codes.first, 'ISK');
      expect(codes.sublist(1), kDefaultPreferredCurrencyCodes);
    });

    test('normalises case and whitespace before comparing', () {
      expect(currencyCodesWith(' eur '), kDefaultPreferredCurrencyCodes);
      expect(currencyCodesWith(' isk ').first, 'ISK');
    });
  });

  group('currencyCodesWith with a preferred list', () {
    test('follows the given list instead of the defaults', () {
      expect(currencyCodesWith('BRL', preferred: const ['BRL', 'EUR']), [
        'BRL',
        'EUR',
      ]);
    });

    test('leads with a current code outside the preferred list', () {
      expect(currencyCodesWith('usd', preferred: const ['BRL']), [
        'USD',
        'BRL',
      ]);
    });

    test('an empty preferred list offers just the current code', () {
      expect(currencyCodesWith('EUR', preferred: const []), ['EUR']);
      expect(currencyCodesWith(null, preferred: const []), isEmpty);
    });
  });

  group('allCurrencyCodesWith', () {
    test('lists the preferred codes first, then the rest of the catalog', () {
      final codes = allCurrencyCodesWith(null, preferred: const ['BRL', 'EUR']);
      expect(codes.take(2), ['BRL', 'EUR']);
      expect(codes, hasLength(kIsoCurrencies.length));
      expect(codes.toSet(), hasLength(codes.length));
      final rest = codes.skip(2).toList();
      expect(rest, [...rest]..sort());
    });

    test('keeps a current code outside the catalog', () {
      final codes = allCurrencyCodesWith('xau', preferred: const ['EUR']);
      expect(codes.take(2), ['XAU', 'EUR']);
      expect(codes, hasLength(kIsoCurrencies.length + 1));
    });

    test('offers the Brazilian real with the defaults (issue #4997)', () {
      expect(allCurrencyCodesWith(null), contains('BRL'));
    });
  });

  group('normalizePreferredCurrencyCodes', () {
    test('trims, upper-cases and drops repeats, keeping first places', () {
      expect(normalizePreferredCurrencyCodes([' brl', 'EUR', 'brl ', 'usd']), [
        'BRL',
        'EUR',
        'USD',
      ]);
    });

    test('drops anything that is not a three-letter code', () {
      expect(
        normalizePreferredCurrencyCodes(['', 'EU', 'EURO', 'E1R', 'CHF']),
        ['CHF'],
      );
    });
  });

  group('currencyMatchesQuery', () {
    test('a blank query matches everything', () {
      expect(currencyMatchesQuery('BRL', ''), isTrue);
      expect(currencyMatchesQuery('ZZZ', '  '), isTrue);
    });

    test('matches the code, ignoring case', () {
      expect(currencyMatchesQuery('BRL', 'br'), isTrue);
      expect(currencyMatchesQuery('BRL', 'EU'), isFalse);
    });

    test('matches the English name, ignoring case', () {
      expect(currencyMatchesQuery('BRL', 'Real'), isTrue);
      expect(currencyMatchesQuery('PLN', 'złoty'), isTrue);
      expect(currencyMatchesQuery('BRL', 'peso'), isFalse);
    });

    test('ignores Latin accents in the name and in the query', () {
      expect(currencyMatchesQuery('PLN', 'zloty'), isTrue);
      expect(currencyMatchesQuery('CRC', 'colon'), isTrue);
      expect(currencyMatchesQuery('VND', 'dong'), isTrue);
      expect(currencyMatchesQuery('MNT', 'tugrug'), isFalse);
      expect(currencyMatchesQuery('MNT', 'togrog'), isTrue);
      expect(currencyMatchesQuery('TOP', 'paanga'), isTrue);
      expect(currencyMatchesQuery('TOP', "Pa'anga"), isTrue);
      expect(currencyMatchesQuery('ISK', 'KRÓNA'), isTrue);
      expect(currencyMatchesQuery('PLN', 'Złoty'), isTrue);
    });

    test('a code outside the catalog matches by code only', () {
      expect(currencyMatchesQuery('XAU', 'xa'), isTrue);
      expect(currencyMatchesQuery('XAU', 'gold'), isFalse);
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

  test('kDefaultPreferredCurrencyCodes covers the major currencies', () {
    expect(
      kDefaultPreferredCurrencyCodes,
      containsAll(['USD', 'EUR', 'GBP', 'CHF']),
    );
  });

  test('kDefaultPreferredCurrencyCodes offers the Polish zloty', () {
    expect(kDefaultPreferredCurrencyCodes, contains('PLN'));
  });

  test(
    'kDefaultPreferredCurrencyCodes has no duplicates and is upper-case',
    () {
      expect(
        kDefaultPreferredCurrencyCodes.toSet(),
        hasLength(kDefaultPreferredCurrencyCodes.length),
      );
      for (final code in kDefaultPreferredCurrencyCodes) {
        expect(code, code.toUpperCase());
      }
    },
  );
}
