import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/export/uddf/uddf_import_parsers.dart';

void main() {
  group('UddfImportParsers.parseUddfInt', () {
    test('parses plain integers', () {
      expect(UddfImportParsers.parseUddfInt('15'), 15);
      expect(UddfImportParsers.parseUddfInt('0'), 0);
      expect(UddfImportParsers.parseUddfInt('1827'), 1827);
      expect(UddfImportParsers.parseUddfInt('-3'), -3);
    });

    test('parses float-formatted integers', () {
      // Oceanic Plus and MacDive serialize integer-semantics fields as
      // floats; int.tryParse rejects these outright.
      expect(UddfImportParsers.parseUddfInt('15.0'), 15);
      expect(UddfImportParsers.parseUddfInt('15.00'), 15);
      expect(UddfImportParsers.parseUddfInt('0.0'), 0);
      expect(UddfImportParsers.parseUddfInt('1827.0'), 1827);
      expect(UddfImportParsers.parseUddfInt('-3.0'), -3);
    });

    test('tolerates surrounding whitespace', () {
      expect(UddfImportParsers.parseUddfInt(' 15 '), 15);
      expect(UddfImportParsers.parseUddfInt('\n  15.0\t'), 15);
    });

    test('rounds genuinely fractional values to nearest', () {
      // Fractional divetime is out of spec, but rounding preserves more
      // signal than discarding the sample.
      expect(UddfImportParsers.parseUddfInt('15.5'), 16);
      expect(UddfImportParsers.parseUddfInt('15.4'), 15);
      expect(UddfImportParsers.parseUddfInt('-15.5'), -16);
    });

    test('parses exponent notation', () {
      expect(UddfImportParsers.parseUddfInt('1e3'), 1000);
      expect(UddfImportParsers.parseUddfInt('1.5e2'), 150);
    });

    test('returns null for null, empty, and non-numeric input', () {
      expect(UddfImportParsers.parseUddfInt(null), isNull);
      expect(UddfImportParsers.parseUddfInt(''), isNull);
      expect(UddfImportParsers.parseUddfInt('   '), isNull);
      expect(UddfImportParsers.parseUddfInt('abc'), isNull);
      expect(UddfImportParsers.parseUddfInt('12abc'), isNull);
    });

    test('returns null for non-finite values instead of throwing', () {
      // double.tryParse SUCCEEDS on these, and double.round() throws
      // UnsupportedError on NaN/Infinity. Without a finiteness guard a
      // single malformed element would abort the entire import.
      expect(UddfImportParsers.parseUddfInt('NaN'), isNull);
      expect(UddfImportParsers.parseUddfInt('Infinity'), isNull);
      expect(UddfImportParsers.parseUddfInt('-Infinity'), isNull);
    });

    test('handles values beyond 32-bit range', () {
      expect(UddfImportParsers.parseUddfInt('3000000000'), 3000000000);
      expect(UddfImportParsers.parseUddfInt('3000000000.0'), 3000000000);
    });

    test('float-formatted integers stay exact beyond 2^53', () {
      // A double cannot represent 2^53 + 1, so routing through
      // double.tryParse would silently return ...992. Dart ints hold it
      // exactly, so the zero fraction is stripped textually instead.
      const big = 9007199254740993; // 2^53 + 1
      expect(UddfImportParsers.parseUddfInt('9007199254740993'), big);
      expect(UddfImportParsers.parseUddfInt('9007199254740993.0'), big);
      expect(UddfImportParsers.parseUddfInt('9007199254740993.000'), big);
      expect(UddfImportParsers.parseUddfInt(' -9007199254740993.0 '), -big);
    });

    test('a real fractional part still rounds, at any magnitude', () {
      expect(UddfImportParsers.parseUddfInt('10.5'), 11);
      expect(UddfImportParsers.parseUddfInt('9007199254740993.5'), isNotNull);
    });
  });

  group('UddfImportParsers.parseUddfDouble', () {
    test('parses decimals, integers and exponent notation', () {
      expect(UddfImportParsers.parseUddfDouble('12.5'), closeTo(12.5, 1e-9));
      expect(UddfImportParsers.parseUddfDouble('12'), closeTo(12.0, 1e-9));
      expect(UddfImportParsers.parseUddfDouble('-3.25'), closeTo(-3.25, 1e-9));
      expect(UddfImportParsers.parseUddfDouble('2.2E7'), closeTo(2.2e7, 1e-3));
    });

    test('tolerates surrounding whitespace', () {
      expect(UddfImportParsers.parseUddfDouble(' 12.5 '), closeTo(12.5, 1e-9));
    });

    test('returns null for null, empty and non-numeric input', () {
      expect(UddfImportParsers.parseUddfDouble(null), isNull);
      expect(UddfImportParsers.parseUddfDouble(''), isNull);
      expect(UddfImportParsers.parseUddfDouble('   '), isNull);
      expect(UddfImportParsers.parseUddfDouble('abc'), isNull);
    });

    test('returns null for non-finite values', () {
      // double.tryParse succeeds on all three; NaN in particular compares
      // false against everything, so it corrupts downstream aggregates
      // rather than failing where it entered.
      expect(UddfImportParsers.parseUddfDouble('NaN'), isNull);
      expect(UddfImportParsers.parseUddfDouble('Infinity'), isNull);
      expect(UddfImportParsers.parseUddfDouble('-Infinity'), isNull);
    });
  });
}
