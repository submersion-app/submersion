import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/utils/currency.dart';
import 'package:submersion/core/utils/currency_catalog.dart';

void main() {
  group('kIsoCurrencies', () {
    test('holds unique three-letter codes in code order', () {
      final codes = [for (final c in kIsoCurrencies) c.code];
      expect(codes.toSet(), hasLength(codes.length));
      expect(codes, [...codes]..sort());
      for (final code in codes) {
        expect(code, matches(RegExp(r'^[A-Z]{3}$')));
      }
    });

    test('names every currency', () {
      for (final currency in kIsoCurrencies) {
        expect(currency.name.trim(), isNotEmpty, reason: currency.code);
      }
    });

    test('covers the currencies divers asked for (issues #4711, #4997)', () {
      final codes = {for (final c in kIsoCurrencies) c.code};
      expect(codes, containsAll(['BRL', 'PLN']));
    });

    test('contains every default preferred code', () {
      final codes = {for (final c in kIsoCurrencies) c.code};
      expect(codes, containsAll(kDefaultPreferredCurrencyCodes));
    });

    test('leaves out funds, metals and testing codes', () {
      final codes = {for (final c in kIsoCurrencies) c.code};
      for (final code in ['XAU', 'XAG', 'XDR', 'XTS', 'XXX', 'BOV', 'USN']) {
        expect(codes, isNot(contains(code)));
      }
    });
  });

  group('isoCurrencyName', () {
    test('names a catalog code, ignoring case and whitespace', () {
      expect(isoCurrencyName('BRL'), 'Brazilian real');
      expect(isoCurrencyName(' brl '), 'Brazilian real');
    });

    test('is null for a code outside the catalog', () {
      expect(isoCurrencyName('ZZZ'), isNull);
      expect(isoCurrencyName(''), isNull);
    });
  });
}
