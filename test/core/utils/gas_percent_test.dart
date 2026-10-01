import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:submersion/core/utils/gas_percent.dart';

void main() {
  late String? previousLocale;

  setUp(() {
    // The separators resolve against Intl.defaultLocale, a process global.
    previousLocale = Intl.defaultLocale;
    addTearDown(() => Intl.defaultLocale = previousLocale);
  });

  group('formatGasPercent', () {
    test('a whole reading stays whole', () {
      Intl.defaultLocale = 'en_US';
      expect(formatGasPercent(32), '32%');
    });

    test('a fractional reading keeps one decimal in the locale', () {
      Intl.defaultLocale = 'en_US';
      expect(formatGasPercent(31.84), '31.8%');
      Intl.defaultLocale = 'de';
      expect(formatGasPercent(31.84), '31,8%');
    });
  });

  group('formatGasPercentValue', () {
    test('is formatGasPercent without the sign', () {
      Intl.defaultLocale = 'de';
      expect(formatGasPercentValue(18.5), '18,5');
      expect(formatGasPercentValue(45), '45');
    });

    test('a non-finite value renders instead of throwing', () {
      Intl.defaultLocale = 'en_US';
      expect(formatGasPercentValue(double.infinity), 'Infinity');
      expect(formatGasPercentValue(double.nan), 'NaN');
    });
  });
}
