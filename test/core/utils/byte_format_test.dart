import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:submersion/core/utils/byte_format.dart';

void main() {
  group('formatBytes', () {
    test('reports raw bytes below one kibibyte', () {
      expect(formatBytes(0), '0 B');
      expect(formatBytes(1023), '1023 B');
    });

    test('switches to KB at one kibibyte', () {
      expect(formatBytes(1024), '1.0 KB');
      expect(formatBytes(1536), '1.5 KB');
    });

    test('drops the decimal at ten units and above', () {
      expect(formatBytes(10 * 1024), '10 KB');
    });

    test('climbs through MB, GB and TB', () {
      expect(formatBytes(5 * 1024 * 1024), '5.0 MB');
      expect(formatBytes(3 * 1024 * 1024 * 1024), '3.0 GB');
      expect(formatBytes(2 * 1024 * 1024 * 1024 * 1024), '2.0 TB');
    });

    test('a negative count is clamped to zero rather than formatted', () {
      expect(formatBytes(-1), '0 B');
    });
  });

  group('formatBytesLocalized', () {
    String label(String number, String unit) => '$number|$unit';

    test('passes the number and unit key to the label', () {
      expect(formatBytesLocalized(12 * 1024 * 1024, label), '12|MB');
      expect(formatBytesLocalized(512, label), '512|B');
      expect(formatBytesLocalized(0, label), '0|B');
    });

    test('uses the active locale\'s decimal mark', () {
      final previous = Intl.defaultLocale;
      addTearDown(() => Intl.defaultLocale = previous);

      Intl.defaultLocale = 'fr';
      expect(
        formatBytesLocalized((2.5 * 1024 * 1024).round(), label),
        '2,5|MB',
      );
      expect(formatBytesLocalized(1536, label), '1,5|KB');

      Intl.defaultLocale = 'en';
      expect(formatBytesLocalized(1536, label), '1.5|KB');
    });
  });
}
