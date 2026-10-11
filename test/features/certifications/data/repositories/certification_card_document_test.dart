import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart' show AppDatabase;
import 'package:submersion/features/certifications/data/repositories/certification_repository.dart';
import 'package:submersion/features/certifications/domain/entities/certification.dart';
import 'package:submersion/features/documents/data/repositories/document_repository.dart';
import 'package:submersion/features/documents/domain/document_ids.dart';

import '../../../../helpers/test_database.dart';

/// A certification's card images live in its card document (issue #2613):
/// the repository writes them there and reads them back onto the entity,
/// so the wallet, detail page and PDF export keep reading
/// Certification.photoFront/photoBack.
void main() {
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
    await db.customStatement(
      'INSERT INTO divers (id, name, is_default, created_at, updated_at) '
      "VALUES ('d1', 'Ana', 1, 0, 0)",
    );
  });
  tearDown(tearDownTestDatabase);

  Certification cert({
    String id = 'c1',
    String? buddyId,
    Uint8List? front,
    Uint8List? back,
  }) => Certification(
    id: id,
    diverId: buddyId == null ? 'd1' : null,
    buddyId: buddyId,
    name: 'Open Water',
    agency: 'padi',
    photoFront: front,
    photoBack: back,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  Future<Object?> rawPhotoFront(String id) async =>
      (await db
              .customSelect(
                'SELECT photo_front AS v FROM certifications WHERE id = ?',
                variables: [Variable.withString(id)],
              )
              .getSingle())
          .data['v'];

  test('photos are stored in the card document, not on the row', () async {
    final repo = CertificationRepository();
    await repo.createCertification(
      cert(front: Uint8List.fromList([1]), back: Uint8List.fromList([2])),
    );
    expect(await rawPhotoFront('c1'), isNull);
    final images = await DocumentRepository().cardImagesFor(['c1']);
    expect(images['c1']!.front, [1]);
    final read = (await repo.getCertificationById('c1'))!;
    expect(read.photoFront, [1]);
    expect(read.photoBack, [2]);
    expect((await repo.getAllCertifications()).single.photoBack, [2]);
    expect((await repo.searchCertifications('open')).single.photoFront, [1]);
  });

  test('a stale photo on the row is never read', () async {
    final repo = CertificationRepository();
    await repo.createCertification(cert());
    await db.customStatement(
      "UPDATE certifications SET photo_front = X'09' WHERE id = 'c1'",
    );
    expect((await repo.getCertificationById('c1'))!.photoFront, isNull);
  });

  test('a rename leaves the card pages untouched', () async {
    final repo = CertificationRepository();
    await repo.createCertification(cert(front: Uint8List.fromList([1])));
    await db.customStatement('DELETE FROM sync_records');
    final current = (await repo.getCertificationById('c1'))!;
    await repo.updateCertification(current.copyWith(name: 'OW Diver'));
    final pending = await db
        .customSelect(
          'SELECT entity_type FROM sync_records '
          "WHERE entity_type IN ('documents', 'documentPages')",
        )
        .get();
    expect(pending, isEmpty);
  });

  test('a cert without photos creates no card document', () async {
    await CertificationRepository().createCertification(cert());
    expect(
      await DocumentRepository().getById(documentCertificationCardId('c1')),
      isNull,
    );
  });

  test('clearing both photos deletes the card document', () async {
    final repo = CertificationRepository();
    await repo.createCertification(cert(front: Uint8List.fromList([1])));
    final current = (await repo.getCertificationById('c1'))!;
    await repo.updateCertification(current.clearPhotos(clearFront: true));
    expect(
      await DocumentRepository().getById(documentCertificationCardId('c1')),
      isNull,
    );
  });

  test(
    'a buddy cert files its card under the diver who owns the buddy',
    () async {
      await db.customStatement(
        'INSERT INTO buddies (id, diver_id, name, created_at, updated_at) '
        "VALUES ('b1', 'd1', 'Bo', 0, 0)",
      );
      final repo = CertificationRepository();
      await repo.createCertification(
        cert(id: 'c2', buddyId: 'b1', front: Uint8List.fromList([5])),
      );
      final doc = await DocumentRepository().getById(
        documentCertificationCardId('c2'),
      );
      expect(doc!.diverId, 'd1');
      expect((await repo.getCertificationsByBuddy('b1')).single.photoFront, [
        5,
      ]);
    },
  );

  test('the certification tick fires when a card page changes', () async {
    final repo = CertificationRepository();
    await repo.createCertification(cert());
    final ticks = <void>[];
    final sub = repo.watchCertificationsChanges().listen(ticks.add);
    addTearDown(sub.cancel);
    await DocumentRepository().saveCardImages(
      certificationId: 'c1',
      diverId: 'd1',
      front: Uint8List.fromList([1]),
      back: null,
    );
    await pumpEventQueue();
    expect(ticks, isNotEmpty);
  });
}
