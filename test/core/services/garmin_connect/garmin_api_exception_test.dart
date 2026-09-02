import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/garmin_connect/garmin_api_exception.dart';

void main() {
  group('GarminApiException', () {
    test('isAuthExpired is true for 401 and 403', () {
      expect(
        const GarminApiException('nope', statusCode: 401).isAuthExpired,
        isTrue,
      );
      expect(
        const GarminApiException('nope', statusCode: 403).isAuthExpired,
        isTrue,
      );
    });

    test('isAuthExpired is false for other status codes and no code', () {
      expect(
        const GarminApiException('nope', statusCode: 500).isAuthExpired,
        isFalse,
      );
      expect(const GarminApiException('nope').isAuthExpired, isFalse);
    });

    test('toString includes the class name and displayMessage', () {
      const withCause = GarminApiException('failed', cause: 'timeout');
      expect(withCause.toString(), 'GarminApiException: failed (timeout)');

      const withoutCause = GarminApiException('failed');
      expect(withoutCause.toString(), 'GarminApiException: failed');
    });
  });

  group('GarminChallengeException', () {
    test('is a GarminApiException carrying just a message', () {
      const exception = GarminChallengeException('CAPTCHA required');

      expect(exception, isA<GarminApiException>());
      expect(exception.displayMessage, 'CAPTCHA required');
      expect(exception.isAuthExpired, isFalse);
    });
  });
}
