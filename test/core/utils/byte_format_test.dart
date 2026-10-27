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

  group('in the active language', () {
    late String? previous;

    setUp(() => previous = Intl.defaultLocale);
    tearDown(() => Intl.defaultLocale = previous);

    test('French takes its decimal comma and its own unit symbols', () {
      Intl.defaultLocale = 'fr';

      expect(formatBytes(1536), '1,5 Ko');
      expect(formatBytes((2.5 * 1024 * 1024).round()), '2,5 Mo');
      expect(formatBytes(512), '512 o');
    });

    test('German takes its decimal comma and keeps MB', () {
      Intl.defaultLocale = 'de-DE';

      expect(formatBytes((2.5 * 1024 * 1024).round()), '2,5 MB');
    });

    test('a language the app does not have reads as English', () {
      Intl.defaultLocale = 'ja';

      expect(formatBytes(1536), '1.5 KB');
    });
  });
}
