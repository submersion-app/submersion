import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/documents/data/repositories/document_repository.dart';
import 'package:submersion/features/documents/domain/entities/document.dart';
import 'package:submersion/features/tags/data/repositories/tag_link_repository.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart' as domain;

import '../../../../helpers/test_database.dart';
import 'document_repository_test.dart' show newDoc, page, tombstones;

/// A document's tags through DocumentRepository (issue #1970): saved in the
/// document's own transaction, tombstoned with it.
void main() {
  late AppDatabase db;
  late DocumentRepository repo;
  final links = TagLinkRepository(domain.TagScope.documents);

  Future<List<String>> tagIdsOf(String id) async =>
      (await links.getTagIdsByItem([id]))[id] ?? const [];

  setUp(() async {
    db = await setUpTestDatabase();
    repo = DocumentRepository();
    await db.customStatement(
      'INSERT INTO divers (id, name, created_at, updated_at) '
      "VALUES ('d1', 'Ana', 0, 0)",
    );
    await db.customStatement(
      'INSERT INTO trips (id, diver_id, name, start_date, end_date, '
      "created_at, updated_at) VALUES ('t1', 'd1', 'Bonaire', 0, 0, 0, 0)",
    );
    await db.customStatement(
      'INSERT INTO tags (id, diver_id, name, created_at, updated_at, '
      "applies_to_documents) VALUES ('travel', 'd1', 'Travel', 0, 0, 1), "
      "('club', 'd1', 'Club', 0, 0, 1)",
    );
  });
  tearDown(tearDownTestDatabase);

  test('save writes the tag set with a new document', () async {
    final saved = await repo.save(
      newDoc(),
      [
        page(0, [1]),
      ],
      tagIds: ['travel', 'club'],
    );

    expect(await tagIdsOf(saved.id), ['travel', 'club']);
  });

  test('save replaces the set, and null leaves it alone', () async {
    final saved = await repo.save(
      newDoc(),
      [
        page(0, [1]),
      ],
      tagIds: ['travel', 'club'],
    );

    await repo.save(saved, await repo.getPages(saved.id), tagIds: ['club']);
    expect(await tagIdsOf(saved.id), ['club']);
    expect(await tombstones(db, 'documentTags'), 1);

    await repo.save(saved, await repo.getPages(saved.id));
    expect(await tagIdsOf(saved.id), ['club']);
  });

  test('a failed save writes no tags', () async {
    await expectLater(
      repo.save(
        newDoc(),
        [
          page(0, [1]),
        ],
        tagIds: ['no-such-tag'],
      ),
      throwsA(anything),
    );
    expect(
      await db.customSelect('SELECT id FROM documents').get(),
      isEmpty,
      reason: 'the document and its links share one transaction',
    );
  });

  test('delete removes and tombstones the links', () async {
    final saved = await repo.save(
      newDoc(),
      [
        page(0, [1]),
      ],
      tagIds: ['travel'],
    );

    await repo.delete(saved.id);

    expect(await tagIdsOf(saved.id), isEmpty);
    expect(await tombstones(db, 'documentTags'), 1);
  });

  test('an owner delete tombstones its documents\' links', () async {
    final saved = await repo.save(
      newDoc(owner: const DocumentOwner(DocumentOwnerKind.trip, 't1')),
      [
        page(0, [1]),
      ],
      tagIds: ['travel', 'club'],
    );

    await db.transaction(
      () => repo.deleteForOwner(DocumentOwnerKind.trip, 't1'),
    );

    expect(await tagIdsOf(saved.id), isEmpty);
    expect(await tombstones(db, 'documentTags'), 2);
  });

  test('an undone owner delete brings the tags back', () async {
    final saved = await repo.save(
      newDoc(owner: const DocumentOwner(DocumentOwnerKind.trip, 't1')),
      [
        page(0, [1]),
      ],
      tagIds: ['travel', 'club'],
    );
    final snapshot = await repo.captureForOwners(DocumentOwnerKind.trip, [
      't1',
    ]);
    await db.transaction(
      () => repo.deleteForOwner(DocumentOwnerKind.trip, 't1'),
    );
    // A tag deleted between the delete and the undo is left out.
    await db.customStatement("DELETE FROM tags WHERE id = 'club'");

    await repo.restoreSnapshot(snapshot);

    expect(await tagIdsOf(saved.id), ['travel']);
  });
}
