import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/cloud_storage/cloud_storage_provider.dart';

void main() {
  group('CloudStorageException.displayMessage', () {
    test('returns the bare message when there is no cause', () {
      const exception = CloudStorageException('Could not reach S3 endpoint');

      expect(exception.displayMessage, 'Could not reach S3 endpoint');
    });

    test('appends the underlying cause so transport detail is visible', () {
      const exception = CloudStorageException(
        'Could not reach S3 endpoint host.example.com',
        FormatException('CERTIFICATE_VERIFY_FAILED'),
      );

      expect(
        exception.displayMessage,
        contains('Could not reach S3 endpoint host.example.com'),
      );
      expect(exception.displayMessage, contains('CERTIFICATE_VERIFY_FAILED'));
    });

    test('does not throw when the cause has a throwing toString', () {
      // displayMessage feeds a UI surface, so it must never throw even if a
      // pathological cause's toString does.
      final exception = CloudStorageException('Upload failed', _Hostile());

      expect(() => exception.displayMessage, returnsNormally);
      expect(exception.displayMessage, contains('Upload failed'));
      expect(() => exception.toString(), returnsNormally);
    });
  });
}

/// A cause whose toString throws, to exercise the non-throwing fallback.
class _Hostile {
  @override
  String toString() => throw StateError('boom');
}
