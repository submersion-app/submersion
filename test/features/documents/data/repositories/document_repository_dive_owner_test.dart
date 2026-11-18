import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart' show AppDatabase;
import 'package:submersion/features/documents/data/repositories/document_repository.dart';
import 'package:submersion/features/documents/domain/entities/document.dart';

import '../../../../helpers/test_database.dart';

/// Filing documents under a dive, and back to Personal, for a sitting on
/// the dive that holds the link until Save (issue #4527, plan 6).
void main() {
  late AppDatabase db;
  late DocumentRepository repo;

  Document personal() => Document(
    id: '',
    diverId: 'd1',
    owner: const DocumentOwner.personal(),
    type: DocumentType.other,
    title: 'Insurance',
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  setUp(() async {
    db = await setUpTestDatabase();
    repo = DocumentRepository();
    await db.customStatement(
      'INSERT INTO divers (id, name, created_at, updated_at) '
      "VALUES ('d1', 'Ana', 0, 0)",
    );
    await db.customStatement(
      'INSERT INTO dives (id, diver_id, dive_date_time, created_at, '
      "updated_at) VALUES ('dive-1', 'd1', 0, 0, 0)",
    );
  });
  tearDown(tearDownTestDatabase);

  test(
    'setDiveOwner files documents under a dive and back to Personal',
    () async {
      final doc = await repo.save(personal(), const []);
      await repo.setDiveOwner([doc.id], 'dive-1');
      expect(
        (await repo.getById(doc.id))!.owner,
        const DocumentOwner(DocumentOwnerKind.dive, 'dive-1'),
      );

      await repo.setDiveOwner([doc.id], null);
      expect(
        (await repo.getById(doc.id))!.owner,
        const DocumentOwner.personal(),
      );
    },
  );

  test('setOwner files documents under a site and back to Personal', () async {
    await db.customStatement(
      'INSERT INTO dive_sites (id, name, created_at, updated_at) '
      "VALUES ('site-1', 'Reef', 0, 0)",
    );
    final doc = await repo.save(personal(), const []);
    await repo.setDiveOwner([doc.id], 'dive-1');

    await repo.setOwner(DocumentOwnerKind.site, [doc.id], 'site-1');
    // One owner: filed under the site, it is no longer the dive's.
    expect(
      (await repo.getById(doc.id))!.owner,
      const DocumentOwner(DocumentOwnerKind.site, 'site-1'),
    );

    await repo.setOwner(DocumentOwnerKind.site, [doc.id], null);
    expect((await repo.getById(doc.id))!.owner, const DocumentOwner.personal());
  });

  test('no ids writes nothing', () async {
    await repo.setDiveOwner(const [], 'dive-1');
  });
}
