import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/data/utils/url_validator.dart';

void main() {
  group('UrlValidator.parse', () {
    test('accepts https URL', () {
      final result = UrlValidator.parse('https://example.com/a.jpg');
      expect(result, isA<UrlValidationOk>());
      expect((result as UrlValidationOk).uri.host, 'example.com');
    });

    test('accepts http URL', () {
      expect(
        UrlValidator.parse('http://example.com/a.jpg'),
        isA<UrlValidationOk>(),
      );
    });

    test('returns empty for whitespace-only line', () {
      expect(UrlValidator.parse('   '), isA<UrlValidationEmpty>());
    });

    test('rejects non-http schemes', () {
      final result = UrlValidator.parse('file:///tmp/a.jpg');
      expect(result, isA<UrlValidationInvalid>());
    });

    test('rejects relative URLs', () {
      expect(UrlValidator.parse('/some/path.jpg'), isA<UrlValidationInvalid>());
    });

    test('rejects malformed URLs', () {
      expect(
        UrlValidator.parse('https://[::not-an-ip]/x'),
        isA<UrlValidationInvalid>(),
      );
    });

    test('rejects URL without host', () {
      expect(UrlValidator.parse('https:///foo'), isA<UrlValidationInvalid>());
    });

    test('trims trailing whitespace before parsing', () {
      expect(
        UrlValidator.parse('  https://example.com/a.jpg  '),
        isA<UrlValidationOk>(),
      );
    });
  });
}
