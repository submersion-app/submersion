import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/equipment/domain/constants/focal_length.dart';

/// A lens's focal length as the diver writes it: a prime's single figure or
/// a zoom's range (issue #3050).
void main() {
  final enDash = String.fromCharCode(0x2013);
  final emDash = String.fromCharCode(0x2014);

  group('isValidFocalLength', () {
    test('accepts a prime and a zoom, with or without mm', () {
      for (final text in [
        '60',
        '60mm',
        '60 mm',
        '4.5',
        '4,5mm',
        '15-45',
        '15 - 45 mm',
        '15mm-45mm',
        '8 to 16mm',
        '8 TO 16 MM',
        '8${enDash}16',
        '8 $emDash 16',
        ' 12-60 ',
      ]) {
        expect(isValidFocalLength(text), isTrue, reason: text);
      }
    });

    test('accepts empty, because the field is optional', () {
      expect(isValidFocalLength(''), isTrue);
      expect(isValidFocalLength('   '), isTrue);
    });

    test('rejects anything that is not a figure or a range', () {
      for (final text in [
        'wide',
        '15-',
        '-45',
        '15-45-60',
        '15/45',
        'mm',
        '60 macro',
      ]) {
        expect(isValidFocalLength(text), isFalse, reason: text);
      }
    });
  });

  group('parseFocalLengthWideEnd', () {
    test('a prime is its own figure', () {
      expect(parseFocalLengthWideEnd('60'), 60);
      expect(parseFocalLengthWideEnd('60mm'), 60);
      expect(parseFocalLengthWideEnd('4,5 mm'), 4.5);
    });

    test('a zoom is its shorter, wider end', () {
      expect(parseFocalLengthWideEnd('15-45'), 15);
      expect(parseFocalLengthWideEnd('8 to 16mm'), 8);
      expect(parseFocalLengthWideEnd('8${enDash}16'), 8);
      // Written long end first, the wide end is still the smaller figure.
      expect(parseFocalLengthWideEnd('45-15'), 15);
    });

    test('is null for anything the validator rejects', () {
      expect(parseFocalLengthWideEnd(''), isNull);
      expect(parseFocalLengthWideEnd('wide'), isNull);
      expect(parseFocalLengthWideEnd('15-'), isNull);
    });
  });

  group('focalLengthEditText', () {
    test('is the text as the diver wrote it', () {
      expect(focalLengthEditText(valueText: '15-45', valueNum: 15), '15-45');
    });

    test('falls back to a lens saved as a single number', () {
      // Rows written before #3050 carry only the number.
      expect(focalLengthEditText(valueText: null, valueNum: 60), '60');
      expect(focalLengthEditText(valueText: null, valueNum: 4.5), '4.5');
      expect(focalLengthEditText(valueText: '  ', valueNum: 60), '60');
    });

    test('is empty when there is nothing stored', () {
      expect(focalLengthEditText(valueText: null, valueNum: null), '');
    });
  });

  group('formatFocalLength', () {
    test('appends mm exactly once', () {
      expect(formatFocalLength(valueText: '15-45', valueNum: 15), '15-45 mm');
      expect(formatFocalLength(valueText: '60mm', valueNum: 60), '60 mm');
      expect(
        formatFocalLength(valueText: '15mm-45mm', valueNum: 15),
        '15-45 mm',
      );
      expect(
        formatFocalLength(valueText: '8 to 16 MM', valueNum: 8),
        '8 to 16 mm',
      );
    });

    test('shows text that is not a focal length as written', () {
      // A CSV import keeps an unreadable value rather than dropping it.
      expect(formatFocalLength(valueText: 'wide', valueNum: null), 'wide');
      expect(
        formatFocalLength(valueText: '60 macro', valueNum: null),
        '60 macro',
      );
    });

    test('shows a lens saved as a single number', () {
      expect(formatFocalLength(valueText: null, valueNum: 60), '60 mm');
    });

    test('a non-finite number shows nothing instead of throwing', () {
      expect(formatFocalLength(valueText: null, valueNum: double.infinity), '');
      expect(formatFocalLength(valueText: null, valueNum: double.nan), '');
      expect(
        focalLengthEditText(valueText: null, valueNum: double.infinity),
        '',
      );
    });

    test('is empty when there is nothing stored', () {
      expect(formatFocalLength(valueText: null, valueNum: null), '');
      expect(formatFocalLength(valueText: 'mm', valueNum: null), '');
    });
  });
}
