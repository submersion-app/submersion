import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/signatures/data/services/signature_storage_service.dart';

import '../../../../helpers/test_database.dart';

void main() {
  group('SignatureStorageService error handling', () {
    late SignatureStorageService service;

    setUp(() async {
      await setUpTestDatabase();
      service = SignatureStorageService();
    });

    tearDown(() {
      DatabaseService.instance.resetForTesting();
    });

    test('write methods rethrow on database error', () async {
      await DatabaseService.instance.database.close();
      DatabaseService.instance.resetForTesting();

      final dummyBytes = Uint8List.fromList([0, 1, 2, 3]);

      await expectLater(
        service.saveSignature(
          diveId: 'x',
          imageBytes: dummyBytes,
          signerName: 'Test',
        ),
        throwsA(anything),
      );
    });

    test('saveBuddySignature rethrows on database error', () async {
      await DatabaseService.instance.database.close();
      DatabaseService.instance.resetForTesting();

      final dummyBytes = Uint8List.fromList([0, 1, 2, 3]);

      await expectLater(
        service.saveBuddySignature(
          diveId: 'x',
          imageBytes: dummyBytes,
          buddyId: 'b',
          buddyName: 'Buddy',
          role: 'buddy',
        ),
        throwsA(anything),
      );
    });

    test('read methods rethrow on database error', () async {
      await DatabaseService.instance.database.close();
      DatabaseService.instance.resetForTesting();

      await expectLater(service.getSignatureForDive('x'), throwsA(anything));
      await expectLater(service.getSignaturesForCourse('x'), throwsA(anything));
      await expectLater(service.deleteSignature('x'), throwsA(anything));
      await expectLater(service.hasSignature('x'), throwsA(anything));
      await expectLater(
        service.getBuddySignaturesForDive('x'),
        throwsA(anything),
      );
      await expectLater(
        service.getAllSignaturesForDive('x'),
        throwsA(anything),
      );
      await expectLater(service.hasBuddySigned('x', 'b'), throwsA(anything));
    });
  });
}
