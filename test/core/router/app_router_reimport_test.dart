import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/router/app_router.dart'
    show parseForceFullQueryParam;

// This file tests the real `parseForceFullQueryParam` from app_router.dart
// (not a local mirror), so a drift in the router's parsing rule will break
// these assertions.

void main() {
  group('forceFull query param parsing', () {
    test('returns true for "true"', () {
      expect(parseForceFullQueryParam('true'), isTrue);
    });

    test('returns false for "false"', () {
      expect(parseForceFullQueryParam('false'), isFalse);
    });

    test('returns false for null (absent)', () {
      expect(parseForceFullQueryParam(null), isFalse);
    });

    test('returns false for empty string', () {
      expect(parseForceFullQueryParam(''), isFalse);
    });

    test('returns false for malformed values', () {
      expect(parseForceFullQueryParam('1'), isFalse);
      expect(parseForceFullQueryParam('TRUE'), isFalse);
      expect(parseForceFullQueryParam('yes'), isFalse);
    });
  });
}
