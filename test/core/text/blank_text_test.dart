import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/text/blank_text.dart';

void main() {
  group('trimmedOrNull', () {
    test('trims surrounding whitespace', () {
      expect(trimmedOrNull('  Bonaire Breeze '), 'Bonaire Breeze');
    });

    test('keeps inner whitespace', () {
      expect(trimmedOrNull('Mike  & Sons'), 'Mike  & Sons');
    });

    test('null, empty and whitespace-only are absent', () {
      expect(trimmedOrNull(null), isNull);
      expect(trimmedOrNull(''), isNull);
      expect(trimmedOrNull(' \t\n '), isNull);
    });
  });
}
