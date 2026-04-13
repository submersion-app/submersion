import 'package:flutter_test/flutter_test.dart';

void main() {
  group('forceFull query param parsing', () {
    bool parseForceFull(String? value) => value == 'true';

    test('returns true for "true"', () {
      expect(parseForceFull('true'), isTrue);
    });

    test('returns false for "false"', () {
      expect(parseForceFull('false'), isFalse);
    });

    test('returns false for null (absent)', () {
      expect(parseForceFull(null), isFalse);
    });

    test('returns false for empty string', () {
      expect(parseForceFull(''), isFalse);
    });

    test('returns false for malformed values', () {
      expect(parseForceFull('1'), isFalse);
      expect(parseForceFull('TRUE'), isFalse);
      expect(parseForceFull('yes'), isFalse);
    });
  });
}
