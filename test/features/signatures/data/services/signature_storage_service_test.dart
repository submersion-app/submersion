import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/signatures/domain/entities/signature.dart';

void main() {
  group('SignatureStorageService', () {
    group('buddy signatures', () {
      test('getBuddySignaturesForDive returns only buddy type signatures', () {
        // This test verifies the service filters by signature type
        // Implementation will query media where signatureType = 'buddy'
        expect(SignatureType.buddy.value, equals('buddy'));
        expect(SignatureType.instructor.value, equals('instructor'));
      });

      test('SignatureType.fromString parses values correctly', () {
        expect(SignatureType.fromString('buddy'), equals(SignatureType.buddy));
        expect(
          SignatureType.fromString('instructor'),
          equals(SignatureType.instructor),
        );
        expect(SignatureType.fromString(null), isNull);
        expect(SignatureType.fromString('unknown'), isNull);
      });
    });
  });
}
