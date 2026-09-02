import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/media/data/repositories/media_library_repository.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/signatures/data/services/signature_storage_service.dart';
import 'package:submersion/features/signatures/domain/entities/signature.dart';

import '../../../../helpers/test_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SignatureStorageService save round trip', () {
    late AppDatabase db;
    late SignatureStorageService service;

    const diveId = 'dive-1';
    const buddyId = 'buddy-1';

    final imageBytes = Uint8List.fromList(const [1, 2, 3, 4]);

    setUp(() async {
      db = await setUpTestDatabase();
      service = SignatureStorageService();

      final at = DateTime.utc(2026, 1, 2, 3, 4).millisecondsSinceEpoch;
      await db
          .into(db.dives)
          .insert(
            DivesCompanion(
              id: const Value(diveId),
              diveDateTime: Value(at),
              createdAt: Value(at),
              updatedAt: Value(at),
            ),
          );
      await db
          .into(db.buddies)
          .insert(
            BuddiesCompanion(
              id: const Value(buddyId),
              name: const Value('Test Buddy'),
              createdAt: Value(at),
              updatedAt: Value(at),
            ),
          );
    });

    tearDown(tearDownTestDatabase);

    test(
      'saveBuddySignature persists a row readable by the dive query',
      () async {
        final saved = await service.saveBuddySignature(
          diveId: diveId,
          imageBytes: imageBytes,
          buddyId: buddyId,
          buddyName: 'Test Buddy',
          role: 'buddy',
        );

        expect(saved.signerId, buddyId);

        final signatures = await service.getBuddySignaturesForDive(diveId);
        expect(signatures, hasLength(1));
        expect(signatures.single.signerId, buddyId);
        expect(signatures.single.imageData, imageBytes);
        expect(signatures.single.type, SignatureType.buddy);

        expect(await service.hasBuddySigned(diveId, buddyId), isTrue);
      },
    );

    test('saveSignature persists an instructor signature', () async {
      await service.saveSignature(
        diveId: diveId,
        imageBytes: imageBytes,
        signerName: 'Instructor',
        signerId: buddyId,
      );

      final signature = await service.getSignatureForDive(diveId);
      expect(signature, isNotNull);
      expect(signature!.imageData, imageBytes);
      expect(await service.hasSignature(diveId), isTrue);
    });

    // media.file_path is NOT NULL and has no default, so an absent value is
    // what made every save throw in Drift's validateIntegrity (issue #1358).
    // The empty string is the schema's "no file behind this row" sentinel.
    test('signature rows carry an empty file path and the signature '
        'source type', () async {
      await service.saveBuddySignature(
        diveId: diveId,
        imageBytes: imageBytes,
        buddyId: buddyId,
        buddyName: 'Test Buddy',
        role: 'buddy',
      );
      await service.saveSignature(
        diveId: diveId,
        imageBytes: imageBytes,
        signerName: 'Instructor',
        signerId: buddyId,
      );

      final rows = await db.select(db.media).get();
      expect(rows, hasLength(2));
      for (final row in rows) {
        expect(row.filePath, '');
        expect(row.sourceType, 'signature');
      }
      expect(
        rows.map((r) => r.signatureType),
        containsAll(<String>['buddy', 'instructor']),
      );
    });

    // Signatures live in the media table but are not dive media. Buddy rows
    // were never written before the #1358 fix, so nothing had ever checked
    // that the library exclusion knows their file_type.
    test('signatures stay out of the media library', () async {
      await service.saveBuddySignature(
        diveId: diveId,
        imageBytes: imageBytes,
        buddyId: buddyId,
        buddyName: 'Test Buddy',
        role: 'buddy',
      );

      expect(await MediaRepository().hasAnyMedia(), isFalse);

      final page = await MediaLibraryRepository().getPage(diverId: null);
      expect(page.entries, isEmpty);
    });
  });
}
