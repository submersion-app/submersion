// Issue #4198: UDDF partial pressures are in Pascal, and a value Submersion
// writes comes back as the exact double it stored.
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/export/uddf/uddf_import_parsers.dart';
import 'package:submersion/core/services/export/uddf/uddf_partial_pressure.dart';

void main() {
  group('pascalText', () {
    test('moves the decimal point five places', () {
      expect(UddfPartialPressure.pascalText(1.01), '101000');
      expect(UddfPartialPressure.pascalText(0.7), '70000');
      expect(UddfPartialPressure.pascalText(1.3), '130000');
      expect(UddfPartialPressure.pascalText(1.27), '127000');
      expect(UddfPartialPressure.pascalText(0.849999964), '84999.9964');
      expect(UddfPartialPressure.pascalText(1.234567), '123456.7');
    });

    test('keeps every digit of a value with float noise', () {
      // 1.01 * 100000 prints as 101000.00000000001; the shift does not
      // multiply, so it adds no noise of its own.
      expect(UddfPartialPressure.pascalText(1.0 + 3 / 100), '103000');
      expect(
        UddfPartialPressure.pascalText(1.0100000000000002),
        '101000.00000000002',
      );
    });

    test('writes a value Dart prints in exponent form as a plain decimal', () {
      expect(UddfPartialPressure.pascalText(2e21), '2${'0' * 26}');
      expect(UddfPartialPressure.pascalText(1.5e22), '15${'0' * 26}');
    });

    test('writes nothing a reader would take for bar', () {
      // 100 Pa or less reads back as bar, so 0.0004 bar would return as
      // 40 bar. No plausible reading is that small.
      expect(UddfPartialPressure.pascalText(0.0004), isNull);
      expect(UddfPartialPressure.pascalText(0.001), isNull);
      expect(UddfPartialPressure.pascalText(0.0010001), '100.01');
      expect(UddfImportParsers.parsePartialPressureBar('100.01'), 0.0010001);
    });

    test('writes nothing for a value that is no reading', () {
      expect(UddfPartialPressure.pascalText(null), isNull);
      expect(UddfPartialPressure.pascalText(double.nan), isNull);
      expect(UddfPartialPressure.pascalText(double.infinity), isNull);
      expect(UddfPartialPressure.pascalText(0), isNull);
      expect(UddfPartialPressure.pascalText(-1.2), isNull);
    });
  });

  group('parsePartialPressureBar', () {
    test('reads Pascal in plain and exponent form', () {
      expect(UddfImportParsers.parsePartialPressureBar('101000'), 1.01);
      expect(UddfImportParsers.parsePartialPressureBar('1.27e5'), 1.27);
      expect(UddfImportParsers.parsePartialPressureBar('1.27E+5'), 1.27);
      expect(
        UddfImportParsers.parsePartialPressureBar(' 84999.9964 '),
        0.849999964,
      );
    });

    test('reads Pascal without a digit before or after the point', () {
      expect(UddfPartialPressure.barFromPascalText('.5e6'), 5);
      expect(UddfPartialPressure.barFromPascalText('130000.'), 1.3);
      expect(UddfPartialPressure.barFromPascalText('.'), isNull);
      expect(UddfPartialPressure.barFromPascalText('e5'), isNull);
      expect(UddfPartialPressure.barFromPascalText('abc'), isNull);
      expect(
        UddfPartialPressure.barFromPascalText('1e99999999999999999999'),
        isNull,
      );
    });

    test('still reads plain bar', () {
      expect(
        UddfImportParsers.parsePartialPressureBar('0.849999964'),
        0.849999964,
      );
      expect(UddfImportParsers.parsePartialPressureBar('1.3'), 1.3);
    });

    test('restores every value Submersion writes exactly', () {
      final random = Random(4198);
      final values = [
        1.01,
        1.0100000000000002,
        0.849999964,
        for (var i = 0; i < 10; i++) 1.0 + i / 100,
        for (var i = 0; i < 2000; i++) 0.05 + random.nextDouble() * 3,
      ];
      for (final bar in values) {
        final text = UddfPartialPressure.pascalText(bar)!;
        expect(
          UddfImportParsers.parsePartialPressureBar(text),
          bar,
          reason: '$bar written as $text',
        );
      }
    });
  });
}
