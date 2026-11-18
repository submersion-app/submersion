import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart' show AppDatabase;
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/documents/presentation/editing/record_document_links_sitting.dart';
import 'package:submersion/features/documents/data/repositories/document_repository.dart';
import 'package:submersion/features/documents/domain/entities/document.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

import '../../../../helpers/test_database.dart';

/// Documents attached to and detached from a dive in a sitting (issue
/// #4527, plan 6).
void main() {
  late AppDatabase db;
  late DocumentRepository repo;
  late ProviderContainer container;
  final dive = Dive(id: 'dive-1', dateTime: DateTime.utc(2026));

  Document doc(DocumentOwner owner) => Document(
    id: '',
    diverId: 'd1',
    owner: owner,
    type: DocumentType.other,
    title: 'Insurance',
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  setUp(() async {
    db = await setUpTestDatabase();
    repo = DocumentRepository();
    container = ProviderContainer();
    await db.customStatement(
      'INSERT INTO divers (id, name, created_at, updated_at) '
      "VALUES ('d1', 'Ana', 0, 0)",
    );
    await db.customStatement(
      'INSERT INTO dives (id, diver_id, dive_date_time, created_at, '
      "updated_at) VALUES ('dive-1', 'd1', 0, 0, 0)",
    );
  });
  tearDown(() async {
    container.dispose();
    await tearDownTestDatabase();
  });

  EditSession<Dive> started() {
    final session = EditSession<Dive>(dive);
    addTearDown(() {
      if (!session.isDisposed) session.dispose();
    });
    holdDocumentLinks(
      session,
      container.read,
      owner: DocumentOwner(DocumentOwnerKind.dive, session.stored.id),
      cardId: 'documents',
    );
    return session;
  }

  Future<DocumentOwner> ownerOf(String id) async =>
      (await repo.getById(id))!.owner;

  const onDive = DocumentOwner(DocumentOwnerKind.dive, 'dive-1');

  test(
    'a new document joins the dive at Save; Cancel leaves it Personal',
    () async {
      final created = await repo.save(doc(const DocumentOwner.personal()), []);
      final session = started();
      attachDocument(session, created);
      expect(session.changedCardIds, {'documents'});
      expect(await ownerOf(created.id), const DocumentOwner.personal());

      await session.runHeldWrites();
      expect(await ownerOf(created.id), onDive);

      final other = await repo.save(doc(const DocumentOwner.personal()), []);
      final cancelled = started();
      attachDocument(cancelled, other);
      cancelled.dispose();
      expect(await ownerOf(other.id), const DocumentOwner.personal());
    },
  );

  test('Remove detaches at Save; the document stays in the library', () async {
    final stored = await repo.save(doc(onDive), []);
    final session = started();
    detachDocument(session, stored.id);
    expect(session.isDirty, isTrue);

    await session.runHeldWrites();
    expect(await ownerOf(stored.id), const DocumentOwner.personal());
  });

  test('attached then removed in the same sitting: no change', () async {
    final created = await repo.save(doc(const DocumentOwner.personal()), []);
    final session = started();
    attachDocument(session, created);
    detachDocument(session, created.id);
    expect(session.isDirty, isFalse);
  });

  test(
    'documentsInSitting: stored ones not detached, then the attached',
    () async {
      final stored = await repo.save(doc(onDive), []);
      final created = await repo.save(doc(const DocumentOwner.personal()), []);
      final session = started();
      attachDocument(session, created);
      detachDocument(session, stored.id);
      expect(documentsInSitting(session, [stored]).map((d) => d.id), [
        created.id,
      ]);
    },
  );

  // Code review (#4527): a document sync filed under another dive while the
  // sitting was open is that dive's now.
  test('a document sync moved to another dive before Save stays there when '
      'the sitting removed it', () async {
    await db.customStatement(
      'INSERT INTO dives (id, diver_id, dive_date_time, created_at, '
      "updated_at) VALUES ('dive-2', 'd1', 0, 0, 0)",
    );
    final stored = await repo.save(doc(onDive), []);
    final session = started();
    detachDocument(session, stored.id);
    await db.customStatement(
      "UPDATE documents SET dive_id = 'dive-2' WHERE id = ?",
      [stored.id],
    );

    await session.runHeldWrites();
    expect(
      await ownerOf(stored.id),
      const DocumentOwner(DocumentOwnerKind.dive, 'dive-2'),
    );
  });
}
