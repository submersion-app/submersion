import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/import_wizard/domain/models/import_cancellation_token.dart';

void main() {
  group('ImportCancellationToken', () {
    test('is not cancelled initially', () {
      final token = ImportCancellationToken();
      expect(token.isCancelled, isFalse);
    });

    test('becomes cancelled after cancel()', () {
      final token = ImportCancellationToken();
      token.cancel();
      expect(token.isCancelled, isTrue);
    });

    test('cancel() is idempotent', () {
      final token = ImportCancellationToken();
      token.cancel();
      token.cancel();
      expect(token.isCancelled, isTrue);
    });
  });
}
